# $Id$

# T flip-flop.  Basically a D flip-flop with _q fed into d.

package Ttl::FlipFlop::T;
use Moose;
extends 'Reflex::Base';
use Ttl::FlipFlop::D;

use Reflex::Trait::Observed;
use Reflex::Trait::EmitsOnChange;

observes dff => (
	isa => 'Ttl::FlipFlop::D',
	handles => ['preset','clear','clock'],
);

emits q      => ( isa => 'Bool' );
emits not_q  => ( isa => 'Bool' );

sub on_dff_q {
	my ($self, $args) = @_;
	$self->q($args->{value});
}

sub on_dff_not_q {
	my ($self, $args) = @_;
	$self->not_q($args->{value});
	$self->dff->d($args->{value});
}

sub BUILD {
	my $self = shift;
	$self->dff( Ttl::FlipFlop::D->new() );
	$self->preset(1);
	$self->clear(1);
	$self->clock(0);
}

1;
