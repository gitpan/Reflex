package Reflex::Wakeup;
BEGIN {
  $Reflex::Wakeup::VERSION = '0.081';
}

use Moose;
extends 'Reflex::Base';

has when => ( isa => 'Num', is  => 'rw' );

with 'Reflex::Role::Wakeup' => {
	when          => "when",
	cb_wakeup     => "on_time",
	method_stop   => "stop",
	method_reset  => "reset",
};

1;

__END__

=head1 NAME

Reflex::Wakeup - A stand-alone single-shot callback at an absolute time

=head1 VERSION

version 0.081

=head1 SYNOPSIS

	#!/usr/bin/env perl

	use warnings;
	use strict;

	use Reflex::Wakeup;

	my @wakeups;
	my $ding = 0;

	for my $delay (1..5) {
		push @wakeups, Reflex::Wakeup->new(
			when    => time() + $delay,
			on_time => sub {
				print "got wakeup $delay\n";
				@wakeups = () if ++$ding >= @wakeups;
			},
		);
	}

	Reflex->run_all();
	exit;

=head1 DESCRIPTION

Reflex::Wakeup invokes a callback at a specific absolute UNIX epoch
time.  Wakeup timers may be stopped and reset.

=head2 Public Attributes

=head3 when

Implemented and documented by L<Reflex::Role::Wakeup/when>.

=head2 Public Callbacks

=head3 on_time

Implemented and documented by L<Reflex::Role::Wakeup/cb_wakeup>.

=head2 Public Methods

=head3 reset

Implemented and documented by L<Reflex::Role::Wakeup/method_reset>.

=head3 stop

Implemented and documented by L<Reflex::Role::Interval/method_stop>.

=head1 EXAMPLES

TODO - Many.  Link to them.

=head1 SEE ALSO

L<Reflex>
L<Reflex::Role>
L<Reflex::Role::Interval>
L<Reflex::Role::Timeout>
L<Reflex::Role::Wakeup>
L<Reflex::Interval>
L<Reflex::Timeout>

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