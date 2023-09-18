#! /usr/bin/perl
{
    foreach $directory( split( /\n/, `ls -d */` ) )
    {
        chop( $directory );
        my $archive = $directory.'.cbz';
        my $command = "zip -9 -r '$archive' '$directory'";
        system( $command );
        
        $command = "rm -r '$directory'";
        system( $command );
    }
}
        
