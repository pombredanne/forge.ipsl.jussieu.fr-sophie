package Sophie::Scan::RpmParser;

use strict;
use warnings;
use File::Temp;
use File::Copy;
use Archive::Cpio;

sub new {
    my ($class, $base) = @_;

    bless { _base => $base }, $class;
}

sub base { $_[0]->{_base} }

sub traverse_cpio {
    my ($self, $rpm, $sub) = @_;
    my $scan = $self->base;

    my $tmp = File::Temp->new( UNLINK => 1, SUFFIX => '.cpio' );
    unlink($tmp->filename);
    if (open(my $cpioh, "rpm2cpio " . quotemeta($rpm) . " |")) {
        File::Copy::copy($cpioh, $tmp);
        close($cpioh);
    } else {
        warn $!;
        return 0;
    }
    
    seek($tmp, 0, 0);
    my $cpio = Archive::Cpio->new();
    eval {
        $cpio->read_with_handler($tmp, $sub);
    };
    $tmp = undef;
}

1;
