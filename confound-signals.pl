#!perl

use strict;
use warnings;

use Reflex::POE::Wheel::Run;
use Reflex::Signal;

$|++;

sub fmt {
  my $timestamp = localtime;
  return "[$timestamp] @_\n";
}

my %w;
for my $id (1..3) {
  $w{$id} = Reflex::POE::Wheel::Run->new(
    Program => sub {
      warn "Starting $id\n";
      sleep 1000;
    },
    on_stdout => sub {
      my $args = pop;
      my $pid = $args->{_sender}->wheel->PID;
      print(fmt "($pid): $args->{output}");
    },
    on_stderr => sub {
      my $args = pop;
      my $pid = $args->{_sender}->wheel->PID;
      my $timestamp = localtime;
      print(fmt "($pid): $args->{output}");
    },
    on_signal => sub {
      my $args = pop;
      print fmt "child $args->{pid} exited: $args->{exit}";
      delete $w{$id};
    },
  );
}

my @sigs;
for my $sig (qw(INT TERM HUP)) {
  push @sigs, Reflex::Signal->new(
    signal => $sig,
    on_signal => sub {
      print fmt "supervisor: caught $sig";
      $_->kill($sig) for values %w;
    },
  );
}

print fmt "($$): supervisor starting";
Reflex->run_all;
