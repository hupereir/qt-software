#! /usr/bin/perl

{

    # find files
    my @files = split( '\n', `find -iname "*.cpp"` );
    push( @files, split( '\n', `find -iname "*.h"` ) );

    foreach $file( @files )
    {
        my $found = 0;
        my @lines =  split( /\n/, `cat $file` );

        my $newFile = $file.".new";
        open( OUT, ">$newFile" );

        # parse lines and replace
        my $found = 0;
        my $className;
        foreach $line (@lines )
        {

            # QRegularExpression
            # Debug
            # Counter
            while( ( $line =~ /QRegularExpression\s+\w+?\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /Debug::Throw\(\s*(?:\w+,\s*)?\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /Counter\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /^\s*(?:static\s+)?const\s+QString\s+(?:\w+::)*?\w+?\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /^\s*(?:static\s+)?const\s+QString\s+(?:\w+::)*?\w+?\s*=\s*\"(.+?)\"\s*;/ ) ||

                # options
                ( $line =~ /XmlOptions::get\(\).get<(?:\w+?)>\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /XmlOptions::get\(\).contains\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /XmlOptions::get\(\).raw\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /XmlOptions::get\(\).specialOptions\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /XmlOptions::get\(\).setRaw\(\s*\"(.+?)\"\s*,/ ) ||
                ( $line =~ /XmlOptions::get\(\).set<(?:\w+?)>\(\s*\"(.+?)\"\s*,/ ) ||
                ( $line =~ /XmlOptions::get\(\).keep\(\s*\"(.+?)\"\s*\)/ ) ||

                # misc
                ( $line =~ /setOptionName\(\s*\"(.+?)\"\s*\)/ ) ||
                ( $line =~ /CustomToolBar\(.+?,.+?,\s*\"(.+?)\"\s*\)\s*;$/ ) ||

                # Mpd::Command( Mpd::Command::Type::Pause, "pause 1" ) );
                ( $line =~ /Mpd::Command\(.+?,\s*\"(.+?)\"\s*\)/ )
                )
            {
                my $pattern = $1;
                print( "line: $line - pattern: $pattern\n" );

                $line =~ s/\"\Q$pattern\E\"/QStringLiteral\(\"$pattern\"\)/g;
                print( "new: $line\n" );

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
