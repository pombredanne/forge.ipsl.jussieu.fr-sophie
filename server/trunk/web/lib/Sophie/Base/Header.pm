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
    my ($class, $pkgid, $db) = @_;

    bless({ key => $pkgid, db => $db }, $class);
}

sub key { $_[0]->{key} }
sub db  {
    $_[0]->{db}->storage->dbh
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
    $listrpm->execute($self->key);

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
    $list_file->execute($self->key);

    my $files = $list_file->fetchall_hashref([ 'dirname', 'basename' ]);

    my $add_content = $self->db->prepare_cached(
        q{
        UPDATE allfiles set contents = ?, has_content = ? where pkgid = ? and count = ?
        }
    );
    seek($tmp, 0, 0);
    my $cpio = Archive::Cpio->new();
    eval {
        $cpio->read_with_handler(
            $tmp,
            sub {
                my ($file) = @_;
                my $fname = $file->name;
                $fname =~ s/^\.\///;
                my ($dirname, $basename) = $fname =~ /^(.*\/)?([^\/]+)$/;
                $dirname = $rpm =~ /src.rpm$/
                    ? ''
                    : $dirname ? "/$dirname" : '' ;
                my $entry = $files->{$dirname}{$basename} or do {
                    warn "unknown $dirname, $basename";
                    return 1;
                };
                for (1) {
                    $entry->{flags} == 32 and last;
                    my $maxsize = $dirname eq '' ? 2 * 1024 : 50;
                    $entry->{size} > $maxsize * 1024 and return 1;
                    $basename =~ /\.gz$/ and return;
                    # Spec files and patch
                    $dirname eq '' and last;
                    # Doc files
                    $entry->{flags} & (1 << 1) || $entry->{flags} & (1 << 8)
                        and last;
                    # Config file
                    $entry->{flags}  & (1 << 0) and last;
                    $basename =~ /\.h$/ and last;

                    return 1;
                }
                my $rawcontent = $file->get_content;
                my $enc = guess_encoding($rawcontent, qw/latin1/);
                if ($enc && ref $enc) {
                    my $content = $enc->decode($rawcontent);

                    $self->db->pg_savepoint('FILECONTENT');
                    $add_content->execute(
                        $enc && ref $enc ? encode('utf8', $content) : $rawcontent,
                        1,
                        $self->key,
                        $entry->{count}) or do {
                            $self->db->pg_rollback_to('FILECONTENT');
                        };
                    }
                1;
            }
        );
    };

    $tmp = undef;
    return 1;
}

1;
