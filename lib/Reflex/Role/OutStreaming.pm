package Reflex::Role::OutStreaming;
BEGIN {
  $Reflex::Role::OutStreaming::VERSION = '0.088';
}
use Reflex::Role;

attribute_parameter handle      => "handle";

callback_parameter  cb_error    => qw( on handle error );

callback_parameter  ev_error    => qw( ev handle error );

method_parameter    method_put  => qw( put handle _ );
method_parameter    method_stop => qw( stop handle _ );

role {
	my $p = shift;

	my $h           = $p->handle();
	my $cb_error    = $p->cb_error();
	my $method_put  = $p->method_put();

	my $method_writable = "_on_${h}_writable";
	my $internal_flush  = "_do_${h}_flush";
	my $internal_put    = "_do_${h}_put";
	my $pause_writable  = "_pause_${h}_writable";
	my $resume_writable = "_resume_${h}_writable";

	with 'Reflex::Role::Collectible';

	method_emit_and_stop $cb_error => $p->ev_error();

	with 'Reflex::Role::Writing' => {
		handle      => $h,
		cb_error    => $cb_error,
		method_put  => $internal_put,
	};

	method $method_writable => sub {
		my ($self, $arg) = @_;

		my $octets_left = $self->$internal_flush();
		return if $octets_left;

		$self->$pause_writable($arg);
	};

	with 'Reflex::Role::Writable' => {
		handle      => $h,
		cb_ready    => $method_writable,
		method_pause => $pause_writable,
	};

	method $method_put => sub {
		my ($self, $arg) = @_;
		my $flush_status = $self->$internal_put($arg);
		return unless $flush_status;
		$self->$resume_writable(), return if $flush_status == 1;
	};
};

1;

__END__

=head1 NAME

Reflex::Role::OutStreaming - add streaming input behavior to a class

=head1 VERSION

version 0.088

=head1 SYNOPSIS

	use Moose;

	has socket => ( is => 'rw', isa => 'FileHandle', required => 1 );

	with 'Reflex::Role::OutStreaming' => {
		handle     => 'socket',
		method_put => 'put',
	};

=head1 DESCRIPTION

Reflex::Role::OutStreaming is a Moose parameterized role that adds
non-blocking output behavior to Reflex-based classes.  It comprises
Reflex::Role::Collectible for dynamic composition,
Reflex::Role::Writable for asynchronous output callbacks, and
Reflex::Role::Writing to buffer and flush output when it can.

See Reflex::Stream if you prefer runtime composition with objects, or
you just find Moose syntax difficult to handle.

=head2 Required Role Parameters

=head3 handle

The C<handle> parameter must contain the name of the attribute that
holds a filehandle from which data will be read.  The name indirection
allows the role to generate methods that are unique to the handle.
For example, a handle named "XYZ" would generate these methods by
default:

	cb_closed   => "on_XYZ_closed",
	cb_error    => "on_XYZ_error",
	method_put  => "put_XYZ",

This naming convention allows the role to be used for more than one
handle in the same class.  Each handle will have its own name, and the
mixed in methods associated with them will also be unique.

=head2 Optional Role Parameters

=head3 cb_error

Please see L<Reflex::Role::Writing/cb_error>.
Reflex::Role::Writing's "cb_error" defines this callback.

=head3 method_put

Please see L<Reflex::Role::Writing/method_put>.
Reflex::Role::Writing's "method_put" defines this method.

=head1 EXAMPLES

See eg/RunnerRole.pm in the distribution.

=head1 SEE ALSO

L<Reflex>
L<Reflex::Role::Writable>
L<Reflex::Role::Writing>
L<Reflex::Stream>

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