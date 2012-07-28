package Sophie::Controller::Statistics::Chat;
use Moose;
use namespace::autoclean;

BEGIN {extends 'Catalyst::Controller'; }

=head1 NAME

Sophie::Controller::Statistics::Chat - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

}

sub command_graph : Local {
    my ($self, $c) = @_;

    my $graph = {
        type => 'lines',
        size => [ 640, 240 ],
    };

    my %data;
    my %cmd;
    foreach ($c->model('Base::ChatStat')->search(
            {},
            { order_by => [ qw(day cmd) ] })->all) {
        $cmd{$_->cmd} = 1;
        $data{$_->day}{$_->cmd} = $_->count;
    }

    my @days;
    my %cmd_count;
    foreach my $d (sort keys %data) {
        push(@days, $d);
        foreach (sort keys %cmd) {
            push(@{ $cmd_count{$_} }, $data{$d}{$_} || 0);
        }
    }

    $graph->{plot} = [
        \@days,
        map { $cmd_count{$_} } sort keys %cmd_count,
    ];
    $graph->{legend} = [ sort keys %cmd_count ];

    $c->stash->{xmlrpc} = {
        graph => $graph,
    };
}

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
