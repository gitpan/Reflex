# A self-managing collection of objects.  See
# Reflex::Role::Collectible for the other side of the
# Collectible/Collection contract.

package Reflex::Collection;
BEGIN {
  $Reflex::Collection::VERSION = '0.055';
}
use Moose;
use Reflex::Callbacks qw(cb_method);

extends 'Reflex::Base';

has objects => (
	is      => 'rw',
	isa     => 'HashRef[Reflex::Collectible]',
	default => sub { {} },
);

sub remember {
	my ($self, $object) = @_;
	$self->watch($object, stopped => cb_method($self, "cb_forget"));
	$self->objects()->{$object} = $object;
}

sub forget {
	my ($self, $object) = @_;
	delete $self->objects()->{$object};
}

sub cb_forget {
	my ($self, $args) = @_;
	delete $self->objects()->{$args->{_sender}};
}

1;

__END__

=head1 NAME

Reflex::Collection - Autmatically manage a collection of collectible objects

=head1 VERSION

version 0.055

=head1 SYNOPSIS

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

	1;

=head1 DESCRIPTION

Some object manage collections of collectible objects---ones that
consume Reflex::Role::Collectible.  For example, network servers must
track objects that represent client connections.  If not, those
objects would go out of scope, destruct, and disconnect their clients.

Reflex::Collection is a generic object collection manager.  It exposes
remember() and forget(), which may be mapped to other methods using
Moose's "handles" aspect.

Reflex::Collection goes beyond this simple hash-like interface.  It
will automatically forget() objects that emit "stopped" events,
triggering their destruction if nothing else refers to them.  This
eliminates a large amount of repetitive work.

Reflex::Role::Collectible provides a stopped() method that emits the
"stopped" event.  Calling C<<$self->stopped()>> in the collectible
class is sufficient to trigger the proper cleanup.

TODO - Reflex::Collection is an excellent place to manage pools of
objects.  Provide a callback interface for pulling new objects as
needed.

=head2 new

Create a new Reflex::Collection.  It takes no parameters.

=head2 remember

Remember an object.  Reflex::Collection works best if it contains the
only references to the objects it manages, so you may often see
objects remembered while they're constructed.  See the SYNOPSIS for
one such example.

remember() takes one parameter: the object to remember.

=head2 forget

Forget an object, returning its reference.  You've supplied the
reference, so the returned one is usually redundant.  forget() takes
one parameter: the object to forget.

=head1 SEE ALSO

L<Reflex>

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