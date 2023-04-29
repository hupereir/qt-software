#! /usr/bin/perl

###############################################################
{
    use Getopt::Long;
    use File::Path qw(rmtree);
    use File::Copy::Recursive qw(dircopy);
    use Cwd;

    GetOptions(
        'help',
        'all',
        'update',
        'copy'
    );


    ###########################################
    # help
    if($opt_help)
    {
        usage();
        exit(0);
    }

    # working directory
    my $workDir = getcwd;

    # modules
    my @modules = get_modules();

    # update
    if( $opt_update || $opt_all )
    {
        foreach $module (@modules)
        {
            my $modulePath = $workDir."/".$module;
            chdir_and_echo( $modulePath );
            command_and_echo( "git pull" );
        }
    }

    # copy
    if( $opt_copy || $opt_all )
    {

        # get shared-libraries subdirectories
        my $module = "shared-libraries";
        my $modulePath = $workDir."/".$module;
        chdir_and_echo( $modulePath );

        my @lines = glob("base*" );
        my @submodules;
        foreach $line (@lines)
        {
            next if( ! -d $modulePath."/".$line );
            print( "adding $line\n" );
            push @submodules, $line;
        }

        my $sourceModulePath = $workDir."/".$module;

        foreach $module (@modules)
        {
            next if( $module eq "shared-libraries" );
            print( "processing $module\n" );

            my $modulePath = $workDir."/".$module;
            foreach $submodule (@submodules)
            {
                rmtree( "$modulePath/$submodule" );
                dircopy( "$sourceModulePath/$submodule", "$modulePath/$submodule" );
            }

        }

    }

}


###########################################
sub get_modules
{

    # working directory
    my $workDir = getcwd;

    my $file = ".gitmodules";
    open my $handle, '<', $file;
    chomp(my @lines = <$handle>);
    close $handle;

    my @modules;
    foreach $line( @lines )
    {
        next if( ! ($line =~ /path\s+=\s+(\S+)/) );
        my $module = $1;

        next if( ! -d $workDir."/".$module );
        push @modules, $module;
    }

    return @modules;
}

###########################################
# change directory and log
sub chdir_and_echo
{
    print("cd $_[0]\n");
    chdir "$_[0]";
}

###########################################
# run command and log
sub command_and_echo
{
    print( "$_[0]\n" );
    goto END if &doSystemFail("$_[0]");
}

###########################################
# run command and log
sub command
{ goto END if &doSystemFail("$_[0]"); }

###########################################
# run command and check command return
sub doSystemFail
{
    close(LOG);
    my $arg = shift(@_) . ">&1";
    my $status = system($arg);
    if ($status)
    { print( "system $arg failed: $?\n" ); }
    return $status;
}

###########################################
# usage
sub usage
{
    print( "usage: update_modules_win32.pl [options] <package1> [<package2>] [<...>]\n");
    print( "where options are one or several of the following:\n");
    print( "  --update              make a git pull in all submodules.\n" );
    print( "  --copy                make a hard copy of shared-libraries in all submodules.\n" );
    print( "  --all                 all of the above.\n" );
    print( "  --help                display this help and exit\n");
    goto END;
}

END: {}
