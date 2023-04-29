#! /usr/bin/perl
{

    if( $#ARGV < 0 )
    {
        usage();
        exit(0);
    }

    # TODO: if no sourceFile is given, parse all cpp files to
    # find the ones that contain a "main" and use these
    my $sourceFile = $ARGV[0];

    # get list of cpp and header files
    # they are global
    @cppFiles = split( /\n/, `find -L -name "*.cpp"` );
    @headerFiles = split( /\n/, `find -L -name "*.h"` );

    %strippedCppFiles;

    process( $sourceFile );

    foreach $file ( sort keys (%strippedCppFiles) )
    {
        next if( !( $file =~ /\.cpp$/ ) );
        print( "$file\n" );
    }

}

#############################################
sub process
{
    my $sourceFile = $_[0];
    if( ! -e $sourceFile ) { return; }


    $strippedCppFiles{$sourceFile}=1;

    foreach $line( split( /\n/, `cat $sourceFile` ) )
    {
        next if( !($line =~/\#include\s*\"(\S+)\"/) );
        my $headerFile = $1;
        my $foundHeaderFile;

        my $found = 0;
        foreach $file( @headerFiles )
        {
            if( $file =~ /\/$headerFile$/ )
            {
                $found = 1;
                $foundHeaderFile = $file;
                break;
            }

        }

        next if( !$found );

        # process header file
        # print( "process - adding $foundHeaderFile\n" );
        if( !$strippedCppFiles{$foundHeaderFile} )
        { process($foundHeaderFile); }

        # generate matching cpp file
        my $cppFile = $foundHeaderFile;
        $cppFile =~ s/\.h$/\.cpp/;

        # print( "process - adding $cppFile.\n" );
        if( !$strippedCppFiles{$cppFile} )
        { process($cppFile); }

    }

}

#############################################
sub usage
{
    print "usage: strip_sources.pl <file>\n";
}

