package Sophie::Template::Plugin::GuessEncode;

use strict;
use warnings;
use base qw( Template::Plugin::Filter );
use Encode::Guess;
use Encode;

sub init {
    my $self = shift;
    $self->install_filter('guessencode');
    return $self;
}

sub filter {
    my ($self, $text) = @_;
    my $enc = guess_encoding($text, qw/latin1/);
    if ($enc && ref($enc)) {
        return(encode('utf8', $enc->decode($text)));
    } else {
        return($text);
    }
}

1;
