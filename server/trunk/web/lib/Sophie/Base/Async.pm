package Sophie::Base::Async;

use strict;
use warnings;
use DBD::Pg qw(:async);
use Time::HiRes qw(sleep);

sub new {
    my ($class, $rs, %options) = @_;

    my $query = $options{build}
        ? $options{build}->($rs)->as_query
        : $rs->as_query;
    my ($sql, @bind) = @{ $$query };
    my $sth = $rs->storage->dbh->prepare(
        $sql,
        { pg_async => PG_ASYNC } 
    ) or return;

    my $time = time;
    $sth->execute(map { $_->[1] } @bind);

    bless {
        rs => $rs,
        sth => $sth,
        start => $time,
        timeout => $options{timeout} || 10,
    }, $class;
}

sub DESTROY {
    my ($self) = @_;
    $self->cancel;
}

sub cancel {
    my ($self) = @_;
    if ($self->{sth}) {
        $self->{sth}->pg_cancel;
        $self->{sth} = undef;
        return 1;
    } else {
        return;
    }
}

sub result {
    my ($self) = @_;
    if (!$self->{sth}) {
        return;
    }
    if ($self->{rs}->storage->dbh->pg_ready) {
        my $sth = $self->{sth};
        $self->{sth} = undef;
        $sth->pg_result;
        return $sth;
    } else {
        return undef;
    }
}

sub wait_result {
    my ($self) = @_;

    while (1) {
        if (my $res = $self->result) {
            return $res;
        }
        if (time > $self->{start} + $self->{timeout}) {
            $self->cancel;
            return;
        }
        sleep(0.25);
    }
}

1;
