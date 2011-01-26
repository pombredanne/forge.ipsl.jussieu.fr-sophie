package Sophie::Scan::RpmParser::Docs;

use strict;
use warnings;
use base qw'Sophie::Scan::RpmParser';

use File::MMagic;
use Encode::Guess;
use Encode;

sub run {
    my ($self, $rpm, $pkgid, $added) = @_;
    my $scan = $self->base;

    if (!$added) { return 1}

    $rpm =~ /\.src\.rpm$/ and return 1;

    my %filelist;
    foreach ($scan->base->resultset('Files')->search(
            { pkgid => $pkgid, dirname => { LIKE => '/usr/share/doc/%' }, },
        )->all) {
        $filelist{$_->dirname . $_->basename} = $_;
    }
    keys(%filelist) or return 1; # Nothing to do 

    $self->traverse_cpio(
        $rpm,
        sub {
            my ($file) = @_;
            my $fname = $file->name;
            $fname =~ s/^\.\///;
            $fname =~ /^\// or $fname = '/' . $fname;
            $filelist{$fname} or return 1;
            if ($filelist{$fname}->size > 500 * 1024) {
                return 1;
            }
            my $rawcontent = $file->get_content;

            my $mm = new File::MMagic;
            my $mime = $mm->checktype_contents($rawcontent);
            $mime =~ /^application\// and return 1;
            my $content;
            if ($mime =~ /(plain)/) {
                foreach my $line (split("\n", $rawcontent)) {
                    my $enc = guess_encoding($line, qw/latin1/);
                    if ($enc && ref $enc) {
                        $content .= $enc->decode($line) . "\n";
                    } else {
                        $content .= $line . "\n";
                    }
                }
            } else {
                $content = $rawcontent
            }

            eval {
                $scan->base->storage->txn_do(
                    sub {
                        $scan->base->resultset('BinFiles')->find(
                            {  
                                count => $filelist{$fname}->count,
                                pkgid => $pkgid,
                            }
                        )->update(
                            {
                                contents => $content,
                                has_content => 1,
                            }
                        );
                    }
                );
            };
            return 1;
        }
    );
}

1;
