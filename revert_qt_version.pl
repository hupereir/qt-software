#! /usr/bin/perl

{

    # find files
    my @headers = split( '\n', `find -iname "*.h"` );
    my @implementations = split( '\n', `find -iname "*.cpp"` );
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
            # print( "processing $line\n" );
            #if QT_VERSION < 0x050000
            if( $line =~ /QT_VERSION_CHECK\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/ )
            {

                my $major = $1;
                my $minor = $2;
                my $release = $3;

                my $majorString;
                if( $major < 10 ) { $majorString = "0$major"; }
                else { $majorString = "$major"; }

                my $minorString;
                if( $minor < 10 ) { $minorString = "0$minor"; }
                else { $minorString = "$minor"; }

                my $releaseString;
                if( $release < 10 ) { $releaseString = "0$release"; }
                else { $releaseString = "$release"; }

                my $versionString = "0x".$majorString.$minorString.$releaseString;

                $line =~ s/QT_VERSION_CHECK\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)\s*\)/$versionString/;

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
