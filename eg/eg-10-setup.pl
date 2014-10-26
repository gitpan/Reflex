#!/usr/bin/env perl

use warnings;
use strict;
use lib qw(../lib);

# Exercise the new "setup" option for EmitsOnChange and Observed
# traits.

{
	package Counter;
	use Moose;
	extends 'Reflex::Base';
	use Reflex::Timer;
	use Reflex::Trait::Observed;
	use Reflex::Trait::EmitsOnChange;

	has count   => (
		traits    => ['Reflex::Trait::EmitsOnChange'],
		isa       => 'Int',
		is        => 'rw',
		default   => 0,
	);

	has ticker  => (
		traits    => ['Reflex::Trait::Observed'],
		isa       => 'Reflex::Timer',
		is        => 'rw',
		setup     => sub {
			Reflex::Timer->new( interval => 0.1, auto_repeat => 1 )
		},
	);

	sub on_ticker_tick {
		my $self = shift;
		$self->count($self->count() + 1);
	}
}

{
	package Watcher;
	use Moose;
	extends 'Reflex::Base';

	has counter => (
		traits  => ['Reflex::Trait::Observed'],
		isa     => 'Counter|Undef',
		is      => 'rw',
		setup   => sub { Counter->new() },
	);

	sub on_counter_count {
		my ($self, $args) = @_;
		warn "Watcher sees counter count: $args->{value}\n";

		$self->counter(undef) if $args->{value} >= 5;
	}
}

# Main.

my $w = Watcher->new();
Reflex->run_all();
exit;
