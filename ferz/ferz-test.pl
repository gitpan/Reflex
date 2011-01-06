package Basket::Box;
use Modern::Perl;
use Moose;
use DateTime;
use Data::Dumper;

use Moose::Util::TypeConstraints;
use MooseX::Types::DateTime qw(DateTime);
use MooseX::ClassAttribute;

extends 'Reflex::Base';

# coerce 'DateTime'
#      => from 'Str'
#          => via { 'DateTime'->from_epoch(epoch=>parsedate( $_ )) };

class_has 'seq' => (is => 'rw', isa => 'Int', default => 0);

has 'id' => (
  is      => 'ro',
  isa     => 'Int',
  default => sub {
    my ($self) = @_;
    return $self->seq($self->seq + 1);
  }
);

has 'value'     => (is => 'rw', isa => 'Num');
has 'starttime' => (is => 'rw', isa => 'DateTime', coerce => 1);
has 'duedate'   => (is => 'rw', isa => 'DateTime', coerce => 1);
has 'last_10' => (is => 'ro', isa => 'ArrayRef', default => sub { return [] });
has 'finished' => (is => 'rw', isa => 'Bool', default => 0);
has 'timeout_handle' => (is => 'rw');
has 'last_wisher' => (is => 'rw', isa => 'Num');

has when => (
  isa     => 'Num',
  is      => 'rw',
  lazy    => 1,
  default => sub {
    my ($self) = @_;
    $DB::single = 1;
    return $self->duedate->epoch;
  }
);

with 'Reflex::Role::Wakeup' => {
  when        => "when",       # when wakeup in seconds
  cb_wakeup   => "on_time",    # callback on wakeup
  method_stop => "stop",       # callback when it's cancelled

#  method_reset  => "reset",    # callback to change wakeup time
};

sub on_time {
  my ($self) = @_;
  $self->finished(1);
  say "wakeup on " . time();

  #say Dumper($self);
  say "------";
}

sub new_wish {
  my ($self, $wisher, $timestamp) = @_;
  return undef if ($self->finished);
  my $dt = $timestamp || 'DateTime'->now;
  $self->last_wisher($wisher);
  unshift(
    @{$self->last_10},
    {last_value => $self->value, wisher => $wisher, when => $dt}
  );
  $self->duedate($self->duedate->add(seconds => 20));
  $DB::single = 1;
  $self->reset_when({when => $self->duedate->epoch});

  if (@{$self->last_10} > 10) {
    pop(@{$self->last_10});
  }
  return $self;
}

sub until_wakeup {
  my ($self) = @_;
  my $dt = 'DateTime'->now;
  return $self->duedate->subtract_datetime($dt);
}

sub status {
  my ($self) = @_;
  return {
    duedate => $self->duedate,
    wisher  => $self->last_wisher,
    value   => $self->value,
    last    => $self->last_10,
  };
}

#####
#####  main
#####

package main;

use Moose;
use Data::Dumper;
use Time::ParseDate qw( parsedate );

my $duedate1 = parsedate('+20 sec');

my $box = Basket::Box->new(
  {
    starttime => 'now',
    duedate   => $duedate1,
  }
);

$box->new_wish(42);    # + 20sec
$box->new_wish(43);    # + 20sec, should be 60 secs in total

my $duedate2 = parsedate('+20 sec');

my $box2 = Basket::Box->new(
  {
    starttime => 'now',
    duedate   => $duedate2,
  }
);

$box2->new_wish(43);    # = 40 sec

while ($box->next()) {
  $box2->next();
  sleep(1);
}

1;

