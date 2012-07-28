package Sophie::Template::Plugin::ObfuscateMail;

use strict;
use warnings;
use base qw( Template::Plugin::Filter );

sub init {
    my $self = shift;
    $self->install_filter('mobfu');
    return $self;
}

my %repl = ( '@' => ' at ', '.' => ' dot ' );

sub filter {
    my ($self, $email) = @_;
    $email ||= '';
    my ($bef, $mail, $aft, $all) = $email =~ /(?:([^<]*)(<[^>]*\@[^>]*>)(.*))|([^@]*\@.*)/;
    $mail ||= $all;

    if (!$mail) {
        return $email;
    }

    $mail =~ s/([@\.])/$repl{$1}/g;
    return sprintf('%s%s%s', $bef || '', $mail, $aft || '');

}

1;
