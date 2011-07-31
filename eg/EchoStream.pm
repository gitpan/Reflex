package EchoStream;
# vim: ts=2 sw=2 noexpandtab

use Moose;
extends 'Reflex::Stream';

sub on_data {
	my ($self, $args) = @_;
	$self->put($args->{data});
}

sub DEMOLISH {
	print "EchoStream demolished as it should.\n";
}

1;
