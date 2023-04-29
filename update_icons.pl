#! /usr/bin/perl
{
    use File::Basename;

    $workdir = `pwd`;
    chomp $workdir;
    my @notFoundFiles;

    my @packages = split( '\n', `cat packages` );
    foreach $package( @packages )
    {
        chomp( $package );
        push( @notFoundFiles, processPackage( $package ) );
    }

    foreach $file( @notFoundFiles )
    { print( "File not found: $file\n" ); }

}

sub processPackage()
{

    my $package = $_[0];
    print( "processing package $package\n" );
    my $basepath = "$workdir/$package";
    chdir "$basepath";

    doSystem( "git checkout -b master-icons" );
    doSystem( "git reset --hard HEAD" );

    # find files
    my @icons = split( '\n', `find -iname "*.png"` );
    my @extensions = ( ".png", ".svg" );

    my $searchPath = "/usr/share/icons/breeze/";
    my $searchExtension = ".svg";

    my @notFoundFiles;
    my %notFoundBaseFiles;

    foreach $file( @icons )
    {
        # get path
        my $path = dirname($file);

        # check
        next if( !( $path =~ /pixmaps/ ) );

        my $basename = basename($file, @extensions);
        my $newFile = $basename.$searchExtension;
        my @output = split( '\n', `find $searchPath -name "$newFile"` );

        my $bestResult;
        my $bestSize = 0;
        my $searchSize = 32;
        foreach $result (@output)
        {
            # parse output to get icon size
            next if( !($result =~ /(\d+)\/$basename/) );
            my $size = $1;
            if( $size == $searchSize )
            {
                $bestSize = $size;
                $bestResult = $result;
                break;
            } elsif( $size < $searchSize && $size > $bestSize  ) {

                $bestSize = $size;
                $bestResult = $result;

            }

        }

        if( !$bestSize )
        {
            push @notFoundFiles, "$basepath/$file";
            $notFoundBaseFiles{basename($file)} = 1;
            next;
        }

        print( "input: $file output: $bestResult - size: $bestSize\n" );
        system( "git mv $file $path/$newFile\n" );
        system( "cp $bestResult $path/$newFile\n" );
    }

    # update qrc file
    my @qrcFiles = split( '\n', `find -iname "*.qrc"` );
    foreach $qrcFile( @qrcFiles )
    {

        my $modified = 0;

        # get all lines from current file
        my @lines = split( '\n', `cat $qrcFile` );

        # overwrite file
        my $newQrcFile = $qrcFile.".new";
        open( OUT, ">$newQrcFile" );

        foreach $line (@lines )
        {
            if( $line =~ /\/(\S+\.png)\"/ )
            {
                my $file = basename( $1 );
                if( !exists( $notFoundBaseFiles{$file} ) )
                {
                    $modified = 1;
                    $line =~ s/\.png/\.svg/g;
                }
            }
            print OUT ($line."\n");
        }

        close( OUT );
        if( $modified )
        {
            print( "updated $qrcFile\n" );
            system("mv $newQrcFile $qrcFile");
        } else {
            system( "rm $newQrcFile" );
        }

    }

    return @notFoundFiles;

}

###########################################
# run command and check command return
sub doSystem
{
    my $arg = shift(@_) . " 2>&1";
    my $status = system($arg);
    return $status;
}
