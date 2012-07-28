package Sophie::Maint::Mandriva;

use strict;
use warnings;
use LWP::UserAgent;

sub new {
    my ($class, $ref) = @_;

    bless({ ref => $ref }, $class);
}

sub fetch {
    my ($self) = @_;

    my $ua = LWP::UserAgent->new;
    $ua->timeout(30);

    my $res = $ua->get($self->{ref}->url);

    if ($res->is_success) {
        my @maintlist;
        foreach (split(/\n/, $res->content)) {
            chomp($_);
            m/(\S*)\s+(.*)/;
            $2 or next;
            push(@maintlist, { rpm => $1, owner => $2 });
        }
        return \@maintlist;
    } else {
        return;
    }
}

1;
