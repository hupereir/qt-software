#! /usr/bin/perl
my $headerName = "base_transparency_export.h";
my $macroName = "BASE_TRANSPARENCY_EXPORT";

{
    my @files = split( '\n', `find -iname "*.h"` );

    foreach $file( @files )
    {

        # skip file if private header
        if( $file =~ /_p\.h$/ )
        {
            print( "skipping $file\n" );
            next;
        }

        # parse file to check header
        if( !needHeader( $file ) )
        {
            print( "Skipping $file.\n" );
            next;
        }

        # parse file to check header
        if( !( hasFriend( $file ) || hasClass( $file ) ) )
        {
            print( "skipping $file\n" );
            next;
        }

        my $newFile = $file.".new";
        open( OUT, ">$newFile" );

        my $headerAdded = 0;
        my @lines =  split( /\n/, `cat $file` );
        foreach $line (@lines )
        {

            # add header
            if( !$headerAdded &&
                ($line =~/^\s*\#include\s*"(\S+?)"/ ||
                $line =~/^\s*\#include\s*<(\S+?)>/) )
            {
                $headerAdded=1;
                print OUT ("#include \"$headerName\"\n");
            }

            # fix class declaration
            if( $line =~/^\s*class\s+(\S+?)(?:\s+|:|(?<!;)$)/ )
            {
                my $pattern = $1;
                $line =~ s/class\s+\Q$pattern\E/class $macroName $pattern/;
            }

            # fix friends declaration
            if( $line =~/^\s*friend\s+(\S+?)\s*(?:.*?);$/ )
            {
                my $pattern = $1;
                $line =~ s/friend\s+\Q$pattern\E/friend $macroName $pattern/;
            }

            print OUT ($line."\n");
        }

        close( OUT );

        if( !$headerAdded )
        { print( "warning header not added to $file\n" ); }

        print( "updated $file\n" );
        system("mv $newFile $file");

    }

}

###########################
sub needHeader
{
    my $file = $_[0];

    my @lines =  split( /\n/, `cat $file` );
    foreach $line (@lines )
    {

        if( $line =~/^\s*\#include\s*"(\S+?)"/ )
        {
            if( $1 eq $headerName )
            { return 0; }
        }

    }

    return 1;
}

###########################
sub hasClass
{
    my $file = $_[0];

    my @lines =  split( /\n/, `cat $file` );
    foreach $line (@lines )
    {
        if( $line =~/^\s*class\s+(\S+?)(?:\s+|:|(?<!;)$)/ )
        # if( $line =~/^\s*class\s+(\S+?)(?:\s+|:|$)/ )
        {
            if( $1 ne $macroName )
            {
                printf( "Found class in $file\n" );
                return 1;
            }
        }
    }

    return 0;
}


###########################
sub hasFriend
{
    my $file = $_[0];

    my @lines =  split( /\n/, `cat $file` );
    foreach $line (@lines )
    {
        if( $line =~/^\s*friend\s+(\S+?)\s*(?:.*?);$/ )
        {
            if( $1 ne $macroName && $1 ne "class"  )
            {
                printf( "Found friend in $file\n" );
                return 1;
            }
        }
    }

    return 0;
}
