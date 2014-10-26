package Reflex::Role::Object;
BEGIN {
  $Reflex::Role::Object::VERSION = '0.004';
}

use Moose::Role;

use Scalar::Util qw(weaken blessed);
use Carp qw(croak);

END {
	#warn join "; ", keys %observers;
	#warn join "; ", keys %observations;
}

our @CARP_NOT = (__PACKAGE__);

# Singleton POE::Session.
# TODO - Extract the POE bits into another role.

# TODO - How to prevent this from being redefined?
#sub POE::Kernel::ASSERT_DEFAULT () { 1 }

use POE;
use Reflex::POE::Session;

# Disable a warning.
POE::Kernel->run();

my %session_object_count;

my $singleton_session_id = POE::Session->create(
	inline_states => {
		# Make the session conveniently accessible.
		# Although we're using the $singleton_session_id, so why bother?

		_start => sub {
			# No-op to satisfy assertions.
			undef;
		},
		_stop => sub {
			# No-op to satisfy assertions.
			undef;
		},

		### Timer manipulators and callbacks.

		timer_due => sub {
			my $envelope = $_[ARG0];
			$envelope->[0]->_deliver();
		},

		### I/O manipulators and callbacks.

		select_ready => sub {
			my ($handle, $envelope, $mode) = @_[ARG0, ARG2, ARG3];
			$envelope->[0]->_deliver($handle, $mode);
		},

		### Signals.

		signal_happened => sub {
			Reflex::Signal->_deliver(@_[ARG0..$#_]);
		},

		### Cross-session emit() is converted into these events.

		deliver_callback => sub {
			my ($callback, $args) = @_[ARG0, ARG1];
			$callback->deliver($args);
		},

		# call_gate() uses this to call methods in the right session.

		call_gate_method => sub {
			my ($object, $method, @args) = @_[ARG0..$#_];
			return $object->$method(@args);
		},

		call_gate_coderef => sub {
			my ($coderef, @args) = @_[ARG0..$#_];
			return $coderef->(@args);
		},

		# Catch dynamic events.

		_default => sub {
			my ($event, $args) = @_[ARG0, ARG1];

			return $event->deliver($args) if (
				"$event" =~ /^Reflex::POE::Event(?:::|=)/
			);

			return if Reflex::POE::Session->deliver($_[SENDER]->ID, $event, $args);

			# Unhandled event.
			# TODO - Anything special?
		},

		### Support POE::Wheel classes.

		# Deliver to wheels based on the wheel ID.  Different wheels pass
		# their IDs in different ARGn offsets, so we need a few of these.
		wheel_event_0 => sub {
			$_[CALLER_FILE] =~ m{/([^/.]+)\.pm};
			"Reflex::POE::Wheel:\:$1"->_deliver(0, @_[ARG0..$#_]);
		},
		wheel_event_1 => sub {
			$_[CALLER_FILE] =~ m{/([^/.]+)\.pm};
			"Reflex::POE::Wheel:\:$1"->_deliver(1, @_[ARG0..$#_]);
		},
		wheel_event_2 => sub {
			$_[CALLER_FILE] =~ m{/([^/.]+)\.pm};
			"Reflex::POE::Wheel:\:$1"->_deliver(2, @_[ARG0..$#_]);
		},
		wheel_event_3 => sub {
			$_[CALLER_FILE] =~ m{/([^/.]+)\.pm};
			"Reflex::POE::Wheel:\:$1"->_deliver(3, @_[ARG0..$#_]);
		},
		wheel_event_4 => sub {
			$_[CALLER_FILE] =~ m{/([^/.]+)\.pm};
			"Reflex::POE::Wheel:\:$1"->_deliver(4, @_[ARG0..$#_]);
		},
	},
)->ID();

has session_id => (
	isa     => 'Str',
	is      => 'ro',
	default => $singleton_session_id,
);

# What's watching me.
# watchers()->{$observer} = \@callbacks
has watchers => (
	isa     => 'HashRef',
	is      => 'rw',
	default => sub { {} },
);

# What's watching me.
# watchers_by_event()->{$event}->{$observer} = \@callbacks
has watchers_by_event => (
	isa     => 'HashRef',
	is      => 'rw',
	default => sub { {} },
);

# What I'm watching.
# watched_objects()->{$observed}->{$event} = \@observations
has watched_object_events => (
	isa     => 'HashRef',
	is      => 'rw',
	default => sub { {} },
);

has watched_objects => (
	isa     => 'HashRef',
	is      => 'rw',
	default => sub { {} },
);

# TODO - Needs to be class, not object based!
#has role => (
#	is      => 'ro',
#	isa     => 'Str',
#	default => sub {
#		my $self = shift;
#		my $role = ref($self);
#		$role =~ s/^Reflex:://;
#		$role =~ tr[a-zA-Z0-9][_]cs;
#		return lc $role;
#	},
#);

has observers => (
	isa     => 'ArrayRef',
	is      => 'rw',
	default => sub { [] },
);

has promise => (
	is => 'rw',
	isa => 'Reflex::Callback::Promise',
);

has emits_seen => (
	is      => 'rw',
	isa     => 'HashRef[Str]',
	default => sub { {} },
);

# Base class.

sub BUILD {
	my ($self, $args) = @_;

	# Set up all emitters and observers.

	foreach my $setup (
		grep {
			$_->does('Reflex::Trait::Emitter') || $_->does('Reflex::Trait::Observer')
		}
		$self->meta()->get_all_attributes()
	) {
		my $callback = $setup->setup();
		next unless defined $callback;

		# TODO - Better way to detect CodeRef?
		if (ref($callback) eq "CODE") {
			my $member = $setup->name();
			$self->$member( $callback->($self) ); # TODO - Proper parameters!
			next;
		}

		# TODO - Better way to detect HashRef?
		if (ref($callback) eq "HASH") {
			my $member = $setup->name();

			my @types = (
				grep { $_ ne "Undef" }
				split /\s*\|\s*/,
				$setup->type_constraint()
			);

			croak "Hashref 'setup' can't determine the class from 'isa'" if (
				@types < 1
			);

			croak "Hashref 'setup' can't set up more than one class from 'isa'" if (
				@types > 1
			);

			my $type = $types[0];
			$self->$member( $type->new($callback) );
			next;
		}

		croak "Unknown 'setup' value: $callback";
	}

	# Known observers.

	foreach my $observer (@{$self->observers()}) {
		my $watcher = shift @$observer;
		$watcher->observe($self, @$observer);
	}

	# Discrete callbacks.

	CALLBACK: while (my ($param, $value) = each %$args) {
		next unless $param =~ /^on_(\S+)/;

		# There is an object, so we have a watcher.
		if ($value->object()) {
			$value->object()->observe($self, $1 => $value);
			next CALLBACK;
		}

		# TODO - Who is the watcher?
		$self->observe($self, $1 => $value);
		next CALLBACK;
	}

	# Clear observers; we're done with them.
	# TODO - Moose probably has a better way of validating parameters.
	$self->observers([]);

	# The session has an object.
	$session_object_count{$self->session_id()}++;
}

# TODO - Does Moose have sugar for passing named parameters?

# Self is being observed.  Register the observation with self.
sub observe {
	my ($self, $observed, %args) = @_;

	while (my ($event, $callback) = each %args) {
		$event =~ s/^on_//;

		my $observation = {
			callback  => $callback,
			event     => $event,
			observed  => $observed,
		};

		weaken $observation->{observed};
		unless (exists $self->watched_objects()->{$observed}) {
			$self->watched_objects()->{$observed} = $observed;
			weaken $self->watched_objects()->{$observed};

			# Keep this object's session alive.
			$POE::Kernel::poe_kernel->refcount_increment($self->session_id, "in_use");
		}

		push @{$self->watched_object_events()->{$observed}->{$event}}, $observation;

		# Tell what I'm watching that it's being observed.

		$observed->is_observed($self, $event, $callback);
	}

	undef;
}

# Self is no longer being observed.  Remove observations from self.
sub stop_observers {
	my ($self, $observer, $events) = @_;

	my @events = @{$events || []};

	unless (@events) {
		my %events = (
			map { $_->{event} => $_->{event} }
			map { @$_ }
			values %{$self->watchers()}
		);
		@events = keys %events;
	}

	foreach my $event (@events) {
		delete $self->watchers_by_event()->{$event}->{$observer};
		delete $self->watchers_by_event()->{$event} unless (
			scalar keys %{$self->watchers_by_event()->{$event}}
		);
		pop @{$self->watchers()->{$observer}};
	}

	delete $self->watchers()->{$observer} unless (
		@{$self->watchers()->{$observer}}
	);
}

sub is_observed {
	my ($self, $observer, $event, $callback) = @_;

	my $observation = {
		callback  => $callback,
		event     => $event,
		observer  => $observer,
	};
	weaken $observation->{observer};

	push @{$self->watchers_by_event()->{$event}->{$observer}}, $observation;
	push @{$self->watchers()->{$observer}}, $observation;
}

sub emit {
	my ($self, @args) = @_;

	# TODO - Checking arguments is tedious, but _check_args() method
	# calls add up.

	my $args = $self->_check_args(
		\@args,
		[ 'event' ],
		[ 'args' ],
	);

	my $event         = $args->{event};
	my $callback_args = $args->{args} || {};

	# TODO - Needs consideration:
	# TODO - Weaken?
	# TODO - Underscores for Reflex parameters?
	# TODO - Must be a hash reference.  Would be nice if non-hashref
	# errors were pushed to the caller.
	$callback_args->{_sender} = $self;

	# Look for self-handling of the event.
	# TODO - can() calls are also candidates for caching.
	# (AKA: Cache as cache can()?)

	my $caller_role = caller();
	$caller_role =~ s/^Reflex::(?:Role::)?//;
	$caller_role =~ tr[a-zA-Z0-9][_]cs;

	my $self_method = "on_" . lc($caller_role) . "_" . $event;
	#warn $self_method;
	if ($self->can($self_method)) {
		# Already seen this; we're recursing!  Break it up!
		if ($self->emits_seen()->{"$self -> $self_method"}) {
			$self->emits_seen({});
			$poe_kernel->post(
				$self->session_id(), 'call_gate_method',
				$self, $self_method, $callback_args
			);
			return;
		}

		# Not recursing yet.  Give it a try!
		$self->emits_seen()->{"$self -> $self_method"} = 1;
		$self->$self_method($callback_args);
		return;
	}

	# This event isn't observed.

	my $deliver_event = $event;
	unless (exists $self->watchers_by_event()->{$deliver_event}) {
		if ($self->promise()) {
			$self->promise()->deliver($event, $callback_args);
			return;
		}

		$deliver_event = "promise";
		return unless exists $self->watchers_by_event()->{$deliver_event};
		# Fall through.
	}

	# This event is observed.  Broadcast it to observers.
	# TODO - Accessor calls are expensive.  Optimize them away.

	while (
		my ($observer, $callbacks) = each %{
			$self->watchers_by_event()->{$deliver_event}
		}
	) {
		CALLBACK: foreach my $callback_rec (@$callbacks) {
			my $callback = $callback_rec->{callback};

			# Same session.  Just deliver it.
			# TODO - Break recursive callbacks?
			if (
				$callback_rec->{observer}->session_id() eq
				$POE::Kernel::poe_kernel->get_active_session()->ID
			) {
				$callback->deliver($event, $callback_args);
				next CALLBACK;
			}

			# Different session.  Post it through.
			$poe_kernel->post(
				$callback_rec->{observer}->session_id(), 'deliver_callback',
				$callback, $callback_args,
				$callback_rec->{observer}, $self, # keep objects alive a bit
			);
		}
	}
}

sub _deliver {
	die "@_";
}

sub _check_args {
	my ($self, $args, $required, $optional) = @_;

	if (ref($args) eq 'ARRAY') {
		croak "constructor parameters must be key/value pairs" if @$args % 2;
		$args = { @$args };
	}

	unless (ref($args) eq 'HASH') {
		croak "constructor parameters are an unknown type";
	}

	my @error;

	my @missing = grep { !exists($args->{$_}) } @$required;
	push @error, "required parameters are missing: @missing" if @missing;

	my %all = map { $_ => 1 } @$required, @$optional;
	my @excess = grep { !exists($all{$_}) } keys %$args;
	push @error, "unknown parameters: @excess" if @excess;

	return $args unless @error;
	croak join "; ", @error;
}

# An object is demolished.
# The filehash should destroy everything it observes.
# All observations of this object must be manually demolished.

sub shutdown {
	my $self = shift;

	# Anything that was watching us, no longer is.

	my %observers = (
		map { $_->{observer} => $_->{observer} }
		map { @$_ }
		values %{$self->watchers()}
	);

	foreach my $observer (values %observers) {
		$observer->ignore(observed => $self);
	}

	# Anything we were observing, no longer is being.

	foreach my $observed (values %{$self->watched_objects()}) {
		$self->ignore(observed => $observed);
	}
}

sub DEMOLISH {
	my $self = shift;
	$self->shutdown();
}

sub ignore {
	my ($self, @args) = @_;

	my $args = $self->_check_args(
		\@args,
		[ 'observed' ],
		[ 'events' ],
	);

	my $observed = $args->{observed};
	my @events   = @{$args->{events} || []};

	if (@events) {
		delete @{$self->watched_object_events()->{$observed}}{@events};
		unless (scalar keys %{$self->watched_object_events()->{$observed}}) {
			delete $self->watched_object_events()->{$observed};
			delete $self->watched_objects()->{$observed};

			# Decrement the session's use count.
			$POE::Kernel::poe_kernel->refcount_decrement($self->session_id, "in_use");
		}
		$observed->stop_observers($self, \@events);
	}
	else {
		use Carp qw(cluck); cluck "whaaaa" unless defined $observed;
		delete $self->watched_object_events()->{$observed};
		delete $self->watched_objects()->{$observed};
		$observed->stop_observers($self);

		# Decrement the session's use count.
		$POE::Kernel::poe_kernel->refcount_decrement($self->session_id, "in_use");
	}
}

# http://en.wikipedia.org/wiki/Call_gate

sub call_gate {
	my ($self, $method) = @_;

	return 1 if (
		$self->session_id() eq $POE::Kernel::poe_kernel->get_active_session()->ID()
	);

	$POE::Kernel::poe_kernel->call(
		$self->session_id(), "call_gate_method", $self, $method, @_[2..$#_]
	);
	return 0;
}

sub run_within_session {
	my ($self, $method) = @_;

	if (
		$self->session_id() eq $POE::Kernel::poe_kernel->get_active_session()->ID()
	) {
		if (ref($method) =~ /^CODE/) {
			return $method->(@_[2..$#_]);
		}
		return $self->$method(@_[2..$#_]);
	}

	if (ref($method) =~ /^CODE/) {
		return $POE::Kernel::poe_kernel->call(
			$self->session_id(), "call_gate_coderef", $method, @_[2..$#_]
		);
	}

	return $POE::Kernel::poe_kernel->call(
		$self->session_id(), "call_gate_method", $self, $method, @_[2..$#_]
	);
}

sub run_all {
	POE::Kernel->run();
}

sub wait {
	my $self = shift;

	$self->promise() || $self->promise(Reflex::Callback::Promise->new());
	return $self->promise()->wait();
}

1;
# TODO - Document.

__END__

=head1 NAME

Reflex::Role::Object - Give an object reflexive roles.

=head1 VERSION

version 0.004

=head1 SYNOPSIS

	{
		package Object;
		use Moose;
		with 'Reflex::Role::Object';
		...;
	}

=head1 DESCRIPTION

Reflex::Role::Object provides the implementation of Reflex::Object as
a role.

TODO - Complete the documentation, including examples for all methods.

=head2 observe

Observe events emitted by another object.  See L</emit>.

=head2 stop_observers

Stop all observers watching this object.  It's used during shutdown
and destruction to detach a departing object from its observers.

=head2 is_observed

The object is being observed.  A helper method for observe().

TODO - Consider making private?

=head2 emit

The object emits an event, and all observers will be notified.

=head2 shutdown

The object is being shut down.  It will ignore() all objects that it
is observing, and all objects observing it will ignore() it as well.

=head2 ignore

Stop watching an object, or specific events emitted by the object.

=head2 call_gate

POE helper method that ensures a method is called within the object's
associated POE session context.  Returns 1 if the method is already
being executed in the proper context.  Returns 0 if it's not, and
re-invokes the method within the proper session.

=head2 run_within_session

POE helper method that invokes a method or coderef within the Reflex
object's associated POE session context.  Primarily used during BUILD
methods for event watchers, which are invoked in the caller's context.

=head2 run_all

Run all Reflex objects until they destruct.

=head1 GETTING HELP

L<Reflex/GETTING HELP>

=head1 ACKNOWLEDGEMENTS

L<Reflex/ACKNOWLEDGEMENTS>

=head1 SEE ALSO

L<Reflex> and L<Reflex/SEE ALSO>

=head1 BUGS

L<Reflex/BUGS>

=head1 CORE AUTHORS

L<Reflex/CORE AUTHORS>

=head1 OTHER CONTRIBUTORS

L<Reflex/OTHER CONTRIBUTORS>

=head1 COPYRIGHT AND LICENSE

L<Reflex/COPYRIGHT AND LICENSE>

=cut