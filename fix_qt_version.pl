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
            if( $line =~ /QT_VERSION.*(0x\d{6,6})/ )
            {

                # parse version
                my $version = $1;
                $version =~ /0x(\d{2,2})(\d{2,2})(\d{2,2})/;

                # get capture and add 0 to convert to integers
                my $major = $1+0;
                my $minor = $2+0;
                my $release = $3+0;

                # replace
                $line =~ s/0x\d{6,6}/QT_VERSION_CHECK\( $major, $minor, $release \)/;
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
