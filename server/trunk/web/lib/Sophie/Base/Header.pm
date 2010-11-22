package Sophie::Base::Header;

use strict;
use warnings;
use base qw(Sophie::Base);
use File::Temp;
use File::Copy;
use Archive::Cpio;
use Encode::Guess;
use Encode;

sub new {
    my ($class, $pkgid) = @_;

    bless(\$pkgid, $class);
}

sub rpm_path {
    my ($self) = @_;

    my $listrpm = $self->db->prepare_cached(
        q{
        select * from rpmfile join rpmspath
        on rpmfile.path = rpmspath.path
        where pkgid = ?
        }
    );
    $listrpm->execute($$self);

    return $listrpm->fetchall_hashref({});
}

sub addfiles_content {
    my ($self, $rpm) = @_;

    my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.cpio' );
    unlink($tmp->filename);
    my $ok = 0;
    foreach ($rpm ? ($rpm) : (@{ $self->rpm_path })) {
        if (open(my $cpioh, "rpm2cpio " . quotemeta($_->{path} . '/' .
                    $_->{filename}) . " |")) {
        File::Copy::copy($cpioh, $tmp);
        close($cpioh);
        $ok = 1;
        last;
        }
    }
    $ok or return;

    my $list_file = $self->db->prepare_cached(q{
        select (rpmqueryfiles(header)).* from rpms where pkgid = ?
    });
    $list_file->execute($$self);

    my $files = $list_file->fetchall_hashref([ 'dirname', 'basename' ]);

    my $add_content = $self->db->prepare_cached(
        q{
        UPDATE allfiles set contents = ? where pkgid = ? and count = ?
        }
    );
    seek($tmp, 0, 0);
    my $cpio = Archive::Cpio->new();
    eval {
        $cpio->read_with_handler(
            $tmp,
            sub {
                my ($file) = @_;
                my ($dirname, $basename) = $file->name =~ /^(?:\.(.*\/))?([^\/]+)$/;
                $dirname ||= '';
                my $entry = $files->{$dirname}{$basename};
                for (1) {
                    $entry->{size} > 1024 * 1024 and return 1;
                    # Spec files and patch
                    $entry->{flags} == 32 and last;
                    $dirname eq '' and last;
                    # Doc files
                    $entry->{flags} & (1 << 1) || $entry->{flags} & (1 << 8)
                        and last;
                    # Config file
                    $entry->{flags}  & (1 << 0) and last;
                    $basename =~ /\.h$/ and last;

                    return 1;
                }
                my $content = $file->get_content;
                my $enc = guess_encoding($content, qw/latin1/);
                if ($enc && ref $enc) {
                    $content = $enc->decode($content);

                    $self->db->pg_savepoint('FILECONTENT');
                    $add_content->execute(
                        $enc && ref $enc ? encode('utf8', $enc->decode($content)) : $content,
                        $$self,
                        $entry->{count}) or do {
                        $self->db->pg_rollback_to('FILECONTENT');
                    };
                } else {
                }
                1;
            }
        );
    };

    $tmp = undef;
    return 1;
}

1;
