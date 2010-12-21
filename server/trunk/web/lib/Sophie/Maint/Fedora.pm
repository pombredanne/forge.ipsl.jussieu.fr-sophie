package Sophie::Maint::Fedora;

use strict;
use warnings;
use LWP::UserAgent;
use JSON;

sub new {
    my ($class, $ref) = @_;

    bless({ ref => $ref }, $class);
}

sub fetch {
    my ($self) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30);

    warn $self->{ref}->url;
    my $res = $ua->get($self->{ref}->url);

    if ($res->is_success) {
        my @maintlist;
        my $ref = JSON->new->decode($res->content);
        foreach (keys %{ $ref->{bugzillaAcls}{Fedora} }) {
            my $obj = $ref->{bugzillaAcls}{Fedora}{$_};
            push(@maintlist, { rpm => $_, owner => $obj->{owner} });
        }
        return \@maintlist;
    } else {
        return;
    }
}

0;
