#! /usr/bin/perl

{

    # find files
    my @headers = split( '\n', `find -iname "*.h"` );
    foreach $file( @headers )
    # my @implementations = split( '\n', `find -iname "*.cpp"` );
    # foreach $file( @implementations )
    {
        #print( "processing file $file\n" );
        my $found = 0;
        my @lines =  split( /\n/, `cat $file` );

        my $newFile = $file.".new";
        open( OUT, ">$newFile" );

        # parse lines and replace
        my $found = 0;
        my $className;
        foreach $line (@lines )
        {

            # look for class name
            if( $line =~ /^\s*class\s+(\w+)/ )
            {
                $className = $1;
                # print( "found class $className\n" );
            }

            if( $className && $line =~ /^(\s*)\s($className)\(/ )
            {
                $found = 1;
                my $spaces = $1;
                $line =~ s/^(\s*)($className)\(/$spaces explicit $className\(/;

            }

            print OUT ($line."\n");

        }

        close( OUT );
        if( $found )
        {
            print( "updated $file\n" );
            system("mv $newFile $file");
        } else {
            system( "rm $newFile" );
        }

    }

}
