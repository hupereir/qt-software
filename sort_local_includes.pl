#! /usr/bin/perl

{

    # find files
    my @headers = split( '\n', `find -iname "*.h"` );
    my @implementations = split( '\n', `find -iname "*.cpp"` );
    my @files = (@headers,@implementations);

    foreach $file( @files )
    {
        next if( !hasLocalInclude($file) );
        
        my $localIncludes = sortLocalIncludes($file);
        
        print( "processing $file.\n" );
        my $found = 0;
        my @lines =  split( /\n/, `cat $file` );

        my $newFile = $file.".new";
        open( OUT, ">$newFile" );

        my $includes_written = 0;
        
        # parse lines and replace
        foreach $line (@lines )
        {
            if( $line =~/^\s*\#include\s*"(\S+)\.h"/ )
            { 
                if( !$includes_written ) 
                {
                    print OUT ($localIncludes);
                    $includes_written = 1;
                }
                
                next;
            }
            print OUT ($line."\n");
        }

        close( OUT );

        print( "updated $file\n" );
        system("mv $newFile $file");

    }

}

###########################
sub hasLocalInclude
{
    my $file = $_[0];

    my @lines =  split( /\n/, `cat $file` );
    foreach $line (@lines )
    {
        if( $line =~/^\s*\#include\s*"(\S+.h)"/ )
        { return 1; }
    }

    return 0;
}

###########################
sub sortLocalIncludes
{
    my $file = $_[0];
    
    my $iscpp = 0;
    my $ownheader;
    
    # parse file to get relevant header
    if( $file =~/(\w+)\.cpp$/ )
    {
        $iscpp = 1;
        $ownheader = "$1.h";
    }
        
    my @lines =  split( /\n/, `cat $file` );
    my %includes;
    foreach $line (@lines )
    {
        if( $line =~/^\s*\#include\s*"(\S+.h)"/ )
        { $includes{$1}++; }
    }
    
    my $includeString;
    
    if( $iscpp ) 
    { $includeString = $includeString."#include \"$ownheader\"\n"; }
    
    foreach $include( sort keys (%includes) )
    {
        next if( $iscpp && $include eq $ownheader );
        $includeString = $includeString."#include \"$include\"\n"; 
    }
        
    return $includeString;
    
}    
