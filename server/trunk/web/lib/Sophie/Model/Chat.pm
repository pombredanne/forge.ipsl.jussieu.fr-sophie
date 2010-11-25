package Sophie::Model::Chat;
use Moose;
use namespace::autoclean;
use Getopt::Long;
use Text::ParseWords;

extends 'Catalyst::Model';

our $VERSION = (q$Revision 17 $ =~ /(\d+)/)[0];

=head1 NAME

Sophie::Model::Chat - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

my $cmds = {
    'me' => {
        code => sub { return 'Sophie Bot version: ' . $VERSION },
    },
    t => {
        code => sub { 
            my ($c, $context, @args) = @_;
            local @ARGV = @args;
            join(', ', @{ $_[0]->forward('/distrib/list', [ { 
                distribution => $args[0],
                release => $args[1],
                arch => $args[2],
                }, ]
            ) });;
        },
    },
};

sub process {
    my ( $self, $c, $context, $message) = @_;

    my ($cmd, @args) = Text::ParseWords::shellwords($message);

    my $msg;
    if ($cmd) {
        if (my $cmdr= $cmds->{$cmd}) {
            $msg = $cmdr->{code}->($c, $context, @args);
        } else {
            $msg = 'No such command';
        }
    } else {
        $msg = 'No command given';
    }

    return {
        msg => $msg,
    };
}


__PACKAGE__->meta->make_immutable;

1;
