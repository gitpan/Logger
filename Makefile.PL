use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

eval { require fields } or die <<FIELDS;
# --------------------------------------
This module requires the fileds pragma,
which is not available. Please upgrade.
# -------------------------------------
FIELDS
WriteMakefile(
    'NAME'		=> 'Logger::Logger',
    'VERSION_FROM'	=> 'Logger.pm', 
);
