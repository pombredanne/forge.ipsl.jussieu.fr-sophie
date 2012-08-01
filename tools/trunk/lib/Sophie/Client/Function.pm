package Sophie::Client::Function;

use strict;
use warnings;

sub new {
    my ($class, $sc) = @_;

    bless( { _sc => $sc }, $class );
}

sub sc { $_[0]->{_sc} }

1;
