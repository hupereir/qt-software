#! /usr/bin/perl

{

    # find files
    my @headers = split( '\n', `find -iname "*.h"` );
    my @implementations = split( '\n', `find -iname "*.cpp"` );
    my @files = (@headers,@implementations);

    foreach $file( @files )
    {
        next if( !needsFix($file) );
        
        my $hasInclude = findInclude( $file );
        my $sortedIncludes = sortLocalIncludes( $file );
        my $includesAdded = 0;
        
        print( "processing $file - hasInclude: $hasInclude\n" );

        if( !$hasInclude ) 
        { print( "sortedIncludes: $sortedIncludes\n" ); }
        
        my $found = 0;
        my @lines =  split( /\n/, `cat $file` );

        my $newFile = $file.".new";
        open( OUT, ">$newFile" );

         # parse lines and replace
        foreach $line (@lines )
        {
            
            if( !$hasInclude && $line =~/^\s*\#include\s*"(\S+)"/ )
            {
                if( !$includesAdded ) 
                {
                    print OUT ($sortedIncludes);
                    $includesAdded = 1;
                }
                
                next;
            }
            
            if( $line =~ /((\w+(?:\(\))?)->setMargin\(\s*(\d+)\s*\))/ )
            { 
                my $pattern = $1;
                print( "found: $pattern\n" );
                my $object = $2;
                my $value = $3;
                my $replacement = "QtUtil::setMargin($object, $value)";
                $line =~ s/\Q$pattern\E/$replacement/;
                $found = 1;
            }

            if( $line =~ /((\w+(?:\(\))?)\.setMargin\(\s*(\d+)\s*\))/ )
            { 
                my $pattern = $1;
                print( "found: $pattern\n" );
                my $object = $2;
                my $value = $3;
                my $replacement = "QtUtil::setMargin(&$object, $value)";
                $line =~ s/\Q$pattern\E/$replacement/;
                $found = 1;
            }
            
            if( $line =~ /(((?:\w+->|\.)+)QtUtil::setMargin\(\s*)/ )
            { 
                my $pattern = $1;
                print( "found: $pattern\n" );
                my $object = $2;
                my $replacement = "QtUtil::setMargin($object";
                $line =~ s/\Q$pattern\E/$replacement/;
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

###########################
sub needsFix
{
    my $file = $_[0];

    my @lines =  split( /\n/, `cat $file` );
    foreach $line (@lines )
    {
        if( $line =~ /((\w+(?:\(\))?)(?:->|\.)setMargin\(\s*(\d+)\s*\))/ )
        { return 1; }
        
        
        if( $line =~ /(((?:\w+->|\.)+)QtUtil::setMargin\(\s*)/ )
        { return 1; }
    }

    return 0;
}

###########################
sub findInclude
{
    my $file = $_[0];

    my @lines =  split( /\n/, `cat $file` );
    foreach $line (@lines )
    {
        if( $line =~/\#include\s*"QtUtil.h"/ )
        { return 1; }
    }
    return 0;
}

###########################
sub sortLocalIncludes
{
    my $file = $_[0];
    my @lines =  split( /\n/, `cat $file` );
    my %includes;
    
    $includes{"QtUtil.h"}++;
    foreach $line (@lines )
    {
        if( $line =~/^\s*\#include\s*"(\S+)"/ )
        { $includes{$1}++; }
    }
    
    my $includeString;
    foreach $include( sort keys (%includes) )
    { $includeString = $includeString."#include \"$include\"\n"; }
        
    return $includeString;
    
}
