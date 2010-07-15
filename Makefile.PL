
use strict;
use warnings;



use ExtUtils::MakeMaker 6.31;



my %WriteMakefileArgs = (
                       'test' => {
                                   'TESTS' => 't/*.t'
                                 },
                       'NAME' => 'Reflex',
                       'DISTNAME' => 'Reflex',
                       'CONFIGURE_REQUIRES' => {
                                                 'ExtUtils::MakeMaker' => '6.31'
                                               },
                       'AUTHOR' => 'Rocco Caputo <rcaputo@cpan.org>',
                       'BUILD_REQUIRES' => {},
                       'ABSTRACT' => 'Class library for flexible, reactive programs.',
                       'EXE_FILES' => [],
                       'VERSION' => '0.060',
                       'PREREQ_PM' => {
                                        'Scalar::Util' => '1.21',
                                        'Test::More' => '0.94',
                                        'POE' => '1.268',
                                        'Moose' => '0.92'
                                      },
                       'LICENSE' => 'perl'
                     );


delete $WriteMakefileArgs{BUILD_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.56) };

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);



