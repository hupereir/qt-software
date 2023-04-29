#! /usr/bin/perl

{

    # find files
    my @headers = split( '\n', `find -iname "*.h"` );
    # my @implementations = split( '\n', `find -iname "*.cpp"` );
    my @implementations = split( '\n', `find -iname "*.cc"` );
    my @files = (@headers,@implementations);

    foreach $file( @files )
    {
        my $found = 0;
        my @lines =  split( /\n/, `cat $file` );

        my $newFile = $file.".new";
        open( OUT, ">$newFile" );

         # parse lines and replace
        foreach $line (@lines )
        {
            if( $line =~ /\(\s*void\s*\)/ )
            {
                $line =~ s/\(\s*void\s*\)/()/;
                $found = 1;
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
