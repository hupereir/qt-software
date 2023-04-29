#! /usr/bin/perl
{
    # my @files = split( '\n', `find -iname "Qt*.prl"` );
    my @files = glob("Qt*.prl" );
    foreach $file( @files )
    {
        my $newfile=$file;
        $newfile =~ s/Qt5/libQt5/;
        $newfile =~ s/qt/libqt/;

        next if( $newfile eq $file );

        print( "fix_qt5_linking - file: $file, newfile: $newfile\n" );

        open my $handle, '<', $file;
        chomp(my @lines = <$handle>);
        close $handle;

        open( OUT, ">$newfile" );
        foreach $line (@lines )
        {
#            print( "line: $line\n" );
             $line =~ s/-luuid//g;
             $line =~ s/-ldxguid;//g;
             $line =~ s/-lwinspool;//g;
             print OUT ($line."\n");
        }
        close(OUT);
    }
}
