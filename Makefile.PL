use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'Grutatxt',
    'dist'		=> { COMPRESS => gzip, SUFFIX => '.gz'},
    'VERSION_FROM'	=> 'Grutatxt.pm',
    'EXE_FILES' 	=> [ 'grutatxt' ],
    'INSTALLSCRIPT'	=> '/usr/local/bin',
);
