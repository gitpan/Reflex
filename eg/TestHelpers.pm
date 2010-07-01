## Used in the examples to reduce LOC by declaring fucntions that are used
## over and over in this module

package TestHelpers;

use warnings;
use strict;

use POSIX qw(strftime);
use Exporter;
use base qw(Exporter);

our @EXPORT_OK = qw(test_diag test_object);

use constant VERBOSE => $ENV{REFLEX_VERBOSE} // 0;

#use constant VERBOSE => (
#	(exists $ENV{REFLEX_VERBOSE}) ? $ENV{REFLEX_VERBOSE} : 0
#);

sub test_diag {
	return unless VERBOSE;
	my $message = join("", @_);
	Test::More::diag(strftime("%F %T", localtime()), " - ", $message);
}

sub test_object {
	my $name = shift;
	return ExampleObject->new($name);
}

# An example object.

{
	package ExampleObject;

	use warnings;
	use strict;

	sub new {
		my ($class, $name) = @_;
		return bless {
			name => $name,
		}, $class;
	}

	sub handler_method {
		my $self = shift;
		ExampleHelpers::test_diag("$self->{name} handled an event");
	}
}

1;
