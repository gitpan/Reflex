package Reflex::Trait::Observed;
BEGIN {
  $Reflex::Trait::Observed::VERSION = '0.072';
}
use Moose::Role;
use Scalar::Util qw(weaken);
use Reflex::Callbacks qw(cb_role);

has setup => (
	isa     => 'CodeRef|HashRef',
	is      => 'ro',
);

has trigger => (
	is => 'ro',
	default => sub {
		my $meta_self = shift;

		# $meta_self->name() is not set yet.
		# Weaken $meta_self so that the closure isn't fatal.
		# TODO - If we can get the name out here, then we save a name()
		# method call every trigger.
		weaken $meta_self;
		my $role;

		sub {
			my ($self, $value) = @_;

			# TODO - Ignore the object when we're set to undef.  Probably
			# part of a clearer method.  Currently we rely on the object
			# destructing on clear, which also triggers ignore().

			return unless defined $value;

			$self->watch(
				$value,
				cb_role(
					$self,
					$role ||=
					$self->meta->find_attribute_by_name($meta_self->name())->role()
				)
			);
		}
	}
);

# Initializer seems to catch the interest from default.  Nifty!

has initializer => (
	is => 'ro',
	default => sub {
		my $role;
		return sub {
			my ($self, $value, $callback, $attr) = @_;
			if (defined $value) {
				$self->watch(
					$value,
					cb_role(
						$self,
						$role ||=
						$self->meta->find_attribute_by_name($attr->name())->role()
					),
				);
			}
			else {
				# TODO - Ignore the object in the old value, if defined.
			}

			$callback->($value);
		}
	},
);

has role => (
	isa     => 'Str',
	is      => 'ro',
	default => sub {
		my $self = shift;
		return $self->name();
	},
);

has setup => (
	isa     => 'CodeRef|HashRef',
	is      => 'ro',
);

# TODO - Clearers don't invoke triggers, because clearing is different
# from setting.  I would love to support $self->clear_thingy() with
# the side-effect of ignoring the object, but I don't yet know how
# to set an "after" method for a clearer that (a) has a dynamic name,
# and (b) hasn't yet been defined.  I think I can do some meta magic
# for (a), but (b) remains tough.

#has clearer => (
#	isa     => 'Str',
#	is      => 'ro',
#	default => sub {
#		my $self = shift;
#		return "clear_" . $self->name();
#	},
#);

package Moose::Meta::Attribute::Custom::Trait::Reflex::Trait::Observed;
BEGIN {
  $Moose::Meta::Attribute::Custom::Trait::Reflex::Trait::Observed::VERSION = '0.072';
}
sub register_implementation { 'Reflex::Trait::Observed' }

1;

__END__

=head1 NAME

Reflex::Trait::Observed - Automatically watch Reflex objects.

=head1 VERSION

version 0.072

=head1 SYNOPSIS

# Not a complete program.  This example comes from Reflex's main
# L<synopsis|Reflex/SYNOPSIS>.

	has clock => (
		isa     => 'Reflex::Interval',
		is      => 'rw',
		traits  => [ 'Reflex::Trait::Observed' ],
		setup   => { interval => 1, auto_repeat => 1 },
	);

=head1 DESCRIPTION

Reflex::Trait::Observed modifies a member to automatically observe any
Reflex::Base object stored within it.  In the SYNOPSIS, storing a
Reflex::Interval in the clock() attribute allows the owner to watch the
timer's events.

This trait is a bit of Moose-based syntactic sugar for Reflex::Base's
more explict watch() and watch_role() methods.

=head2 setup

The "setup" option provides default constructor parameters for the
attribute.  In the above example, clock() will by default contain

	Reflex::Interval->new(interval => 1, auto_repeat => 1);

In other words, it will emit the Reflex::Interval event ("tick") once
per second until destroyed.

=head2 role

Attribute events are mapped to the owner's methods using Reflex's
role-based callback convention.  For example, Reflex will look for an
on_clock_tick() method to handle "tick" events from an object with the
'clock" role.

The "role" option allows roles to be set or overridden.  A watcher
attribute's name is its default role.

=head1 CAVEATS

The "setup" option is a work-around for unfortunate default timing.
It will be deprecated if default can be made to work instead.

=head1 SEE ALSO

L<Reflex>
L<Reflex::Trait::EmitsOnChange>

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