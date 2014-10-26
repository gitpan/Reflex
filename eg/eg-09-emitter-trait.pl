#!/usr/bin/perl

use warnings;
use strict;
use lib qw(../lib);

# Objects may emit events when their members are changed.

{
	package Counter;
	use Moose;
	extends 'Reflex::Base';
	use Reflex::Interval;
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
		isa       => 'Maybe[Reflex::Interval]',
		is        => 'rw',
	);

	sub BUILD {
		my $self = shift;

		$self->ticker(
			Reflex::Interval->new(
				interval    => 0.1,
				auto_repeat => 1,
			)
		);
	}

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
		isa     => 'Counter',
		is      => 'rw',
	);

	sub BUILD {
		my $self = shift;
		$self->counter(Counter->new());
	}

	sub on_counter_count {
		my ($self, $args) = @_;
		warn "Watcher sees counter count: $args->{value}\n";
	}
}

# Main.

my $w = Watcher->new();
Reflex->run_all();
exit;
