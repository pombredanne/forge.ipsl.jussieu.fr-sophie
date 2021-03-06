package Sophie::Bot;

use 5.010000;
use strict;
use warnings;
use RPC::XML;
use base qw(RPC::XML::Client);
$RPC::XML::FORCE_STRING_ENCODING = 1;

our $VERSION = '0.03';

sub new {
    my ($class, %options) = @_;

    my $self = $class->SUPER::new(
        $options{server} || 'http://sophie.zarb.org/rpc'
    );
    if ($options{proxy}) {
        $self->useragent->proxy([ 'http' ], $options{proxy});
    } else {
        $self->useragent->env_proxy;
    }

    $self->{options} = { %options };


    if ($options{login}) {
        login($self) or die "Can't login at $options{server}";
    }

    my $realclass = $class . ($options{type} ? ('::' . $options{type}) : '');
    no strict qw(refs);
    eval "require $realclass;";
    if($@) {
        warn $@;
        return;
    }
    bless($self, $realclass);
}

sub login {
    my ($self) = @_;
    my %options = %{ $self->{options} };
    if ($options{login}) {
        my $res = $self->send_request('login',
            $options{login},
            $options{password});
        if ($res && ref $res) {
            $self->request->header('cookie', $$res);
            return 1;
        } else {
            warn "$res\n";
            return;
        }
    } else {
        my $res = $self->send_request('user.session');
        if (ref $res && !$res->is_fault) {
            $self->request->header('cookie', $$res);
            return 1;
        } else {
            warn "$res\n";
            return;
        }
    }
}

sub get_var {
    my ($self, $varname) = @_;
    my $resp = $self->send_request('user.fetchdata', $varname);
    if (ref $resp) {
        if ($resp->value) {
            return $resp->value;
        }
    } else {
        return {};
    }
}

sub set_var {
    my ($self, $varname, $data) = @_;

    my $resp = $self->send_request('user.update_data', $varname, $data);
    if (ref $resp) {
        return 1;
    } else {
        return;
    }
}

sub handle_message {
    my ($self, $heap, $context, $message) = @_;

    $self->login;
    eval {
        $self->submit_query($heap, $context, $message);
    }
}

sub submit_query {
    my ($self, $heap, $context, $message) = @_;

    my $resp = $self->send_request('chat.message', $context, $message);
    if (ref($resp)) {
        $self->show_reply($heap, $resp->value);
    } else {
        return;
    }

}

1;

__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Sophie::Client - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Sophie::Client;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Sophie::Client, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.


=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Olivier Thauvin, E<lt>olivier@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Olivier Thauvin

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.12.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
