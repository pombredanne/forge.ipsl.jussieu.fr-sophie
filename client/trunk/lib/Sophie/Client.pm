package Sophie::Client;

use 5.012002;
use strict;
use warnings;
use RPC::XML;
use base qw(RPC::XML::Client);
$RPC::XML::FORCE_STRING_ENCODING = 1;
use Term::ReadLine;

our $VERSION = '0.01';

{
    open (my $fh, "/dev/tty" )
        or eval 'sub Term::ReadLine::findConsole { ("&STDIN", "&STDERR")
    }';
    die $@ if $@;
    close ($fh);
}

sub new {
    my ($class, %options) = @_;

    my $self = $class->SUPER::new(
        $options{server} || 'http://sophie2.aero.jussieu.fr'
    );

    if ($options{login}) {
        my $res = $self->send_request('login',
            $options{login},
            $options{password});
        if (ref $res) {
            $self->request->header('cookie', $$res);
        } else {
            die "Can't login";
        }
    }

    bless($self, $class);
}

sub run {
    my ($self) = @_;

    my $term = Term::ReadLine->new('Sophie');
    $term->MinLine(99999);
    my $OUT = $term->OUT || \*STDOUT;

    while (1) {
        defined (my $line = $term->readline('Sophie > ')) or do {
            print $OUT "\n";
            return;
        };

        my $resp = $self->send_request('chat.message', [ 'chan', 'user' ], $line);
        if (ref($resp)) {
            my $res = $resp->value;
            print "$_\n" foreach (@{$res->{message}});
        }
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
