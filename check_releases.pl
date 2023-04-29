#! /usr/bin/perl

###############################################################
{

    use Getopt::Long;
    GetOptions(
        'help',
        'file:s',
    );

    ###########################################
    # help
    if($opt_help)
    {
        usage();
        exit(0);
    }

    ###########################################
    # working directory
    my $workDir = `pwd`;
    chop($workDir);

    # log file
    $logfile = "$workDir/check_releases.log";
    open(LOG, ">$logfile");

    ###########################################
    # build list of packages
    my %packages;
    if( $opt_file )
    {
        print_and_log( "check_releases - opening $opt_file" );
        my @lines = split( /\n/, `more $opt_file` );
        foreach $line( @lines )
        {
            next if ( $line =~ /^#/ );
            next if ( $line =~ /^\s*$/ );
            $packages{ $line }++;
        }
    }

    foreach $argnum (0 .. $#ARGV)
    {
        $package  = $ARGV[$argnum];
        $packages{ $package }++;
    }

    my $count = 0;
    my @package_list;
    foreach $package( sort keys (%packages) )
    {
        print( "check_releases - adding package $package\n" );
        push @package_list, $package;
        $count++;
    }

    if( $count < 1 )
    {
        usage();
        goto END;
    }

    ###########################################
    # check releases for each package in list
    foreach $package( @package_list )
    { check_package_releases( $workDir.'/'.$package ); }

    close(LOG);

}

##############################################"
sub check_package_releases
{

    # get package
    my $sourceDir = $_[0];
    chdir_and_echo( $sourceDir );

    # get list of commits for CMakeLists.txt
    my $file = "CMakeLists.txt";
    my @commits = get_commits( $file );

    # get list of tags
    my %tags = get_tags();

    # add remaining packages
    my $current_version = get_version( $file );
    my $lastVersion = $current_version;
    my $lastCommit;

    # loop over commits
    foreach $commit( @commits )
    {
        #print_and_log( "check_releases - found commit: $commit");
        my @content=split( /\n/, `git show $commit:$file` );
        my $version=get_version_from_content(\@content);
        if( $version ne $lastVersion)
        {

            print_and_log( "lastCommit with version $lastVersion: $lastCommit" );

            if( $lastVersion )
            {
                # see if there is a tag that matches stored version
                my $tag='v'.$lastVersion;
                if( !$tags{"v$lastVersion"} )
                {
                    print_and_log( "adding tag $tag" );
                    cmd_and_echo( "git tag -a -m 'tagging version $tag' $tag $lastCommit" );
                    cmd_and_echo( "git push origin $tag" );
                }
            }

            # store version for future comparison
            $lastVersion = $version;

        }

        $lastCommit = $commit;

    }

}

###########################################
sub get_commits
{
    my $file = $_[0];
    my @commits;
    my @lines = split( /\n/, `git log $file |& grep commit` );
    foreach $line( @lines )
    {
        next if( !($line =~/^commit\s+(\S+)/) );
        my $commit = $1;
        push @commits, $commit;
    }
    return @commits;
}

###########################################
sub get_tags
{
    # make sure all tags are fetch
    # cmd_and_echo( "git fetch -t" );

    my %tags;
    my @lines = split( /\n/, `git tag -l` );
    foreach $line( @lines )
    { $tags{$line}++; }

    return %tags;
}

###########################################
sub get_version
{
    my $file = $_[0];
    print_and_log( "get_version - file: $file" );
    my @lines = split( /\n/, `more $file` );
    return get_version_from_content( \@lines );
}

###########################################
sub get_version_from_content
{
    my @lines = @{$_[0]};
    my $major = -1;
    my $minor = -1;
    my $patch = -1;
    foreach $line( @lines )
    {

        # prototypes
        if( ! ($line =~ /(?:set|SET)\s*\(\s*(\S*)_VERSION_(MAJOR|MINOR|PATCH)\s+(\d+)\s*\)/ ) )
        {
            push( @converted, $line );
            next;
        }

        my $package = $1;
        my $type = $2;
        my $local_version = $3;

        # store
        if( $type eq "MAJOR" )    { $major = $local_version; }
        elsif( $type eq "MINOR" ) { $minor = $local_version; }
        elsif( $type eq "PATCH" ) { $patch = $local_version; }

    }

    my $found = ($major>=0) && ($minor>=0) && ($patch>=0);
    if( !$found )
    {

        print_and_log( "get_version - unable to find version." );
        return;

    } else {

        $version = "$major.$minor.$patch";
        # print_and_log( "get_version - version: $version" );
        return $version;

    }

}

###########################################
# usage
sub usage
{
    print( "usage: check_releases.pl [options] <package1> [<package2>] [<...>]\n");
    print( "where options are one or several of the following:\n");
    print( "  --file                specify file containing packages to be checked\n" );
    print( "  --help                display this help and exit\n");
    goto END;
}

###########################################
# run command and log
sub cmd_and_echo
{
    print_and_log( "$_[0]" );
    goto END if &doSystemFail("$_[0]");
}

###########################################
# change directory and log
sub chdir_and_echo
{
    print_and_log("cd $_[0]");
    chdir "$_[0]";
}

###########################################
# print command to screen and log
sub print_and_log
{

    print "$_[0]\n";
    print LOG "$_[0]\n";

}

###########################################
# run command and check command return
sub doSystemFail
{
    close(LOG);
    my $arg = shift(@_) . ">> $logfile 2>&1";
    my $status = system($arg);
    open(LOG, ">>$logfile");
    if ($status)
    { print_and_log( "system $arg failed: $?" ); }
    return $status;
}

END: {}
