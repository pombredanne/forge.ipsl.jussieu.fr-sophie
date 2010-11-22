package Sophie;
use Moose;
use namespace::autoclean;
use Catalyst::Runtime 5.80;
use Sophie::Base;

# Set flags and add plugins for the application
#
#         -Debug: activates the debug mode for very useful log messages
#   ConfigLoader: will load the configuration from a Config::General file in the
#                 application's home directory
# Static::Simple: will serve static files from the application's root
#                 directory

use Catalyst qw/
    ConfigLoader
    Static::Simple
    Session
    Session::Store::DBI
    Session::State::Cookie
    Compress::Zlib
    Server
    Server::XMLRPC
    Authentication
/;

use RPC::XML;
$RPC::XML::FORCE_STRING_ENCODING = 1;

extends 'Catalyst';

our $VERSION = '0.01';
$VERSION = eval $VERSION;

# Configure the application.
#
# Note that settings in sophie.conf (or other external
# configuration file that you set up manually) take precedence
# over this when using ConfigLoader. Thus configuration
# details given here can function as a default configuration,
# with an external configuration file acting as an override for
# local deployment.

__PACKAGE__->config(
    name => 'Sophie',
    # Disable deprecated behavior needed by old applications
    disable_component_resolution_regex_fallback => 1,
    default_view => 'TT',
    xmlrpc => {
        xml_encoding => 'UTF-8',
    },

    'authentication' => {
        default_realm => 'members',
        realms => {
            members => {
                credential => {
                    class => 'Password',
                    password_field => 'password',
                    password_type => 'clear'
                },
                store => {
                    class => 'Minimal',
                    users => {
                        admin => {
                            password => 'toto',
                        }
                    }
                },
            },
        },
    },
);

__PACKAGE__->config->{session} = {
    expires   => 3600,
    dbi_dsn   => 'noo',
    dbi_table => 'sessions',
};

# Start the application
__PACKAGE__->setup();

# This is after because db config is in config file
__PACKAGE__->config->{session}{dbi_dsn} =
    'dbi:Pg:' . __PACKAGE__->config->{dbconnect};
__PACKAGE__->config->{session}{dbi_user} =
    __PACKAGE__->config->{dbuser};
__PACKAGE__->config->{session}{dbi_pass} =
    __PACKAGE__->config->{dbpassword};


=head1 NAME

Sophie - Catalyst based application

=head1 SYNOPSIS

    script/sophie_server.pl

=head1 DESCRIPTION

[enter your description here]

=head1 SEE ALSO

L<Sophie::Controller::Root>, L<Catalyst>

=head1 AUTHOR

Olivier Thauvin

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
