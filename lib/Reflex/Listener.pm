# A listen/accept server.

package Reflex::Listener;
BEGIN {
  $Reflex::Listener::VERSION = '0.050';
}
use Moose;
extends 'Reflex::Handle';

has '+rd' => ( default => 1 );

sub on_handle_readable {
	my ($self, $args) = @_;

	my $peer = accept(my ($socket), $args->{handle});
	if ($peer) {
		$self->emit(
			event => "accepted",
			args  => {
				peer    => $peer,
				socket  => $socket,
			}
		);
		return;
	}

	$self->emit(
		event => "failure",
		args  => {
			peer    => undef,
			socket  => undef,
			errnum  => ($!+0),
			errstr  => "$!",
			errfun  => "accept",
		},
	);
}

1;

__END__

=head1 NAME

Reflex::Listener - Generate connected client sockets from a listening server socket.

=head1 VERSION

version 0.050

=head1 SYNOPSIS

	# This is an incomplete excerpt from eg/eg-34-tcp-server-echo.pl.

	package TcpEchoServer;

	use Moose;
	extends 'Reflex::Listener';
	use Reflex::Collection;
	use EchoStream;

	has clients => (
		is      => 'rw',
		isa     => 'Reflex::Collection',
		default => sub { Reflex::Collection->new() },
		handles => { remember_client => "remember" },
	);

	sub on_listener_accepted {
		my ($self, $args) = @_;
		$self->remember_client(
			EchoStream->new(
				handle => $args->{socket},
				rd     => 1,
			)
		);
	}

	sub on_listener_failure {
		my ($self, $args) = @_;
		warn "$args->{errfun} error $args->{errnum}: $args->{errstr}\n";
	}

=head1 DESCRIPTION

Reflex::Listener is scheduled for substantial changes.  Its base
class, Reflex::Handle, will be deprecated in favor of
Reflex::Role::Readable and Reflex::Role::Writable.  Hopefully
Reflex::Listener's interfaces won't change much as a result, but
there are no guarantees.
Your ideas and feedback for Reflex::Listener's future implementation
are welcome.

Reflex::Listener extends Reflex::Handle.  It watches listening server
sockets for new client connections.  When they arrive, it accept()s
them and emits them in "accepted" events.

=head2 Attributes

Reflex::Listener inherits its attributes from Reflex::Handle.  It sets
the rd() attribute to true by default---so listeners start up ready to
accept connections.

=head2 Methods

Reflex::Listener inherits its methods from Reflex::Handle.  It doesn't
add new methods at this time.

=head2 EXAMPLES

eg/eg-34-tcp-server-echo.pl in Reflex's distribution implements a
simple TCP server using Reflex::Listener.  The SYNOPSIS for this
module is an excerpt from that example.

=head1 SEE ALSO

L<Reflex>
L<Reflex::Handle>

L<Reflex/ACKNOWLEDGEMENTS>
L<Reflex/ASSISTANCE>
L<Reflex/AUTHORS>
L<Reflex/BUGS>
L<Reflex/BUGS>
L<Reflex/CONTRIBUTORS>
L<Reflex/COPYRIGHT>
L<Reflex/LICENSE>
L<Reflex/TODO>

=cut