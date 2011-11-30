#!/usr/bin/perl
# vim: ts=2 sw=2 noexpandtab

use warnings;
use strict;
use lib qw(../lib);

# Demonstrate how wheels may be encapsulated in thin,
# configuration-only subclasses.

{
	package Runner;
	use Moose;
	extends 'Reflex::Base';
	use Reflex::POE::Wheel::Run;
	use Reflex::Callbacks qw(cb_role);

	has wheel => (
		isa => 'Reflex::POE::Wheel::Run|Undef',
		is  => 'rw',
	);

	sub BUILD {
		my $self = shift;

		$self->wheel(
			Reflex::POE::Wheel::Run->new(
				Program => "$^X -wle 'print qq[pid(\$\$) moo(\$_)] for 1..10; exit'",
				cb_role($self, "child"),
			)
		);
	}

	sub on_child_stdin {
		print "stdin flushed\n";
	}

	sub on_child_stdout {
		my ($self, $stdout) = @_;
		print "stdout: ", $stdout->octets(), "\n";
	}

	sub on_child_stderr {
		my ($self, $stderr) = @_;
		print "stderr: ", $stderr->octets(), "\n";
	}

	sub on_child_error {
		my ($self, $error) = @_;
		return if $error->function() eq "read";
		print $error->formatted(), "\n";
	}

	sub on_child_close {
		my ($self, $args) = @_;
		print "child closed all output\n";
	}

	sub on_child_signal {
		my ($self, $args) = @_;
		print "child $args->{pid} exited: $args->{exit}\n";
		$self->wheel(undef);
	}
}

# Main.

# TODO - SIGCHLD isn't delivered properly.

my $runner_1 = Runner->new();
my $runner_2 = Runner->new();

Reflex->run_all();
exit;
