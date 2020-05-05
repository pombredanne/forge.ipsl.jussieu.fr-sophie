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
    XMLRPC
    Authentication
    Authorization::Roles
    Prototype
/;

use RPC::XML;
$RPC::XML::FORCE_STRING_ENCODING = 1;

extends 'Catalyst';

our $VERSION = '0.06';
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
        show_errors => 1,
    },
    'View::GD' => {
        gd_image_type         => 'png',        # defaults to 'gif'
        gd_image_content_type => 'images/png', # defaults to 'image/$gd_image_type'
        gd_image_render_args  => [ 5 ],        # defaults to []
    },

    'authentication' => {
        default_realm => 'members',
        realms => {
            members => {
                credential => {
                    class => 'Password',
                    password_field => 'password',
                    password_type => 'crypted'
                },
                store => {
                    class => 'DBIx::Class',
                    user_model => 'Base::Users',
                    role_relation => 'Roles',
                    role_field => 'rolename',
                    id_field => 'mail',
                    # use_userdata_from_session => 1,
                },
            },
        },
    },
    'View::Email' => {
        default => {
            charset => 'utf-8',
            content_type => 'text/plain',
        },
        sender => {
            mailer => 'SMTP',
            mailer_args => {
                host => 'localhost',
            },
        },
    }
);

__PACKAGE__->config->{session} = {
    expires   => 3600 * 24, # one day
    dbi_dbh   => 'Session',
    dbi_table => 'sessions',
};

# Start the application
__PACKAGE__->setup();

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
