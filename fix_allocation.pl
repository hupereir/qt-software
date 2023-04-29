#! /usr/bin/perl

{

    # find files
    my @files = split( '\n', `find -iname "*.cpp"` );
    foreach $file( @files )
    {
        # print( "processing file $file\n" );
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
            if( $line =~ /new\s+(\w+)\s*\(\)/ )
            {
                $className = $1;
                print( "found constructor of class $className\n" );
                print( "line:          $line\n" );

                $line =~ s/($className)\(\)/$className/;
                print( "replaced with: $line\n" );

                $found = true;

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
