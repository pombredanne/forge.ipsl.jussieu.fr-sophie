package Sophie::Client::Term;

use 5.012002;
use strict;
use warnings;
use Term::ReadLine;
use base qw(Sophie::Client);

our $VERSION = '0.01';

{
    open (my $fh, "/dev/tty" )
        or eval 'sub Term::ReadLine::findConsole { ("&STDIN", "&STDERR") }';
    die $@ if $@;
    close ($fh);
}

sub show_reply {
    my ($self, $heap, $reply) = @_;
    print "$_\n" foreach (@{$reply->{message}});
}

sub user_config {
    my ($self, $heap, $var, $value) = @_;

    $self->set_var('client', { $var => $value });
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
        $self->handle_message(undef, [ 'client' ], $line);
        $term->addhistory($line);
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
