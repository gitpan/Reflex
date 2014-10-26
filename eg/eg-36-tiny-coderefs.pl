#!/usr/bin/env perl

# This is pretty close to the final syntax.

use warnings;
use strict;

use lib qw(../lib);

use Reflex::Interval;
use ExampleHelpers qw(eg_say);

my $t = Reflex::Interval->new(
	interval    => 1,
	auto_repeat => 1,
	on_tick     => sub { eg_say("timer ticked") },
);

$t->run_all();
