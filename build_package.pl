#! /usr/bin/perl

###############################################################
{
    use Getopt::Long;
    use File::Path qw(rmtree make_path);
    use File::Copy::Recursive qw(dircopy);
    use Cwd;

    GetOptions(
        'help',
        'all',
        'file:s',
        'clang',
        'clazy',
        'clean',
        'clone',
        'configure',
        'dist',
        'make',
        'install',
        'major',
        'minor',
        'mingw',
        'ninja',
        'no-increment',
        'prefix:s',
        'qt6',
        'release',
        'rpm',
        'shared',
        'update' );

    ###########################################
    # help
    if($opt_help)
    {
        usage();
        exit(0);
    }

    ###########################################
    # working directory
    my $workDir = getcwd;

    ############################################
    # log file
    $logfile = "$workDir/build_package.log";
    open(LOG, ">$logfile");

    # build type
    my $buildType = "RELWITHDEBINFO";
    # my $buildType = "RELEASE";

    # make command
    my $make;
    my $makeFlags;

    if( $opt_ninja )
    {
        print_and_log( "Using ninja" );
        $make="ninja";
        $makeFlags="";
    } elsif ( $opt_mingw ) {
        $make = "mingw32-make";
        $makeFlags = "-j4";
    } else {
        $make = "make";
        $makeFlags = "-j4";
    }

    # compiler setup
    if( $opt_clang )
    {
        print_and_log( "Using clang" );
        $ENV{CC} = "/usr/lib64/ccache/clang";
        $ENV{CXX} = "/usr/lib64/ccache/clang++";
        $ENV{LDFLAGS} = "-lstdc++ -lm";
    } elsif( $opt_clazy ) {
        print_and_log( "Using clazy" );
        # $ENV{CLAZY_CHECKS} = "fix-old-style-connect";
        $ENV{CLAZY_CHECKS} =
            "level0,level1,level2,".
            "no-non-pod-global-static,".
            "no-range-loop,".
            "no-ctor-missing-parent-argument,".
            "no-rule-of-three,".
            "no-rule-of-two-soft,".
            "no-qproperty-without-notify,".
            "no-copyable-polymorphic";
        # $ENV{CLAZY_EXPORT_FIXES} = "";
        $ENV{CXX} = "/usr/bin/clazy";
    }

    ###########################################
    # processing packages
    my %packages;
    if( $opt_file )
    {

        print_and_log( "build_package - opening $opt_file" );
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

    # shared lib package must be added up-front
    my $shared_lib_package = "shared-libraries";
    if( $packages{ $shared_lib_package } > 0 )
    {

        print( "build_package - adding package $shared_lib_package\n" );
        push @package_list, $shared_lib_package;
        $count++;

    }

    # add remaining packages
    foreach $package( sort keys (%packages) )
    {
        next if( $package eq $shared_lib_package );

        print( "build_package - adding package $package\n" );
        push @package_list, $package;
        $count++;
    }

    if( $count < 1 )
    {
        usage();
        goto END;
    }

    ###########################################
    # base packages
    # they are added to all directories wether they are configured or not
    # @base_packages = ("base","server","transparency","spellcheck");
    my @base_packages = (
        "base",
        "base-cmake",
        "base-help",
        "base-notifications",
        "base-pixmaps",
        "base-qt",
        "base-server",
        "base-ssh",
        "base-svg",
        "base-spellcheck",
        "base-transparency",
        "base-filesystem");

    ###########################################
    # directory

    # directory name
    my $source_dir = "$workDir/src";
    my $build_dir;
    my $build_dist_dir;

    if( $opt_qt6 )
    {
        if( $opt_shared )
        {
            $build_dir = "$workDir/build-shared-qt6";
        } else {
            $build_dir = "$workDir/build-static-qt6";
        }
    } else {
        if( $opt_shared )
        {
            $build_dir = "$workDir/build-shared";
        } else {
            $build_dir = "$workDir/build-static";
        }
    }
    $build_dist_dir = "$workDir/build-dist";

    if( $opt_clang )
    {

        $build_dir = $build_dir."-clang";
        $build_dist_dir = $build_dist_dir."-clang";

    } elsif( $opt_clazy ) {

        $build_dir = $build_dir."-clazy";
        $build_dist_dir = $build_dist_dir."-clazy";

    }

    my $install_dir;
    if( $opt_prefix ) { $install_dir = $opt_prefix; }
    elsif( $opt_qt6 )
    {
        if( $opt_shared ) { $install_dir = $workDir."/install-shared-qt6"; }
        else { $install_dir = $workDir."/install-static-qt6"; }
    } else {
        if( $opt_shared ) { $install_dir = $workDir."/install-shared"; }
        else { $install_dir = $workDir."/install-static"; }
    }
    
    my $source_dist_dir = "$workDir/src-dist";
    my $install_dist_dir = "$workDir/install-dist";

    # file lists
    my @tarball_files;
    my @rpm_files;

    # push directories to be created in list
    push @dirs, $source_dir;
    if( $opt_configure || $opt_make || $opt_install || $opt_dist || $opt_rpm || $opt_all )
    { push @dirs, $build_dir; }

    if( $opt_install ) { push @dirs, $install_dir; }

    if( $opt_dist || $opt_all ) { push @dirs, $source_dist_dir; }
    if( $opt_dist || $opt_all ) { push @dirs, $build_dist_dir; }

    # create needed directories
    print_and_log( "\ncreating directories");
    foreach $dir( @dirs ) { mkdir_and_echo( "$dir" ); }

    ###########################################
    # processing packages
    my $git_base_repository = "cern:";
    foreach $package( @package_list )
    {

        print_and_log( "\nprocessing package $package");
        my $package_source_dir = "$source_dir/$package";
        my $package_build_dir = "$build_dir/$package";

        # needed for release
        my $version = "";

        ###########################################
        if( $opt_clone )
        {

            if( ! -d $package_source_dir )
            {
                my $git_repository = "$git_base_repository/$package";
                chdir_and_echo( $source_dir );
                cmd_and_echo( "git clone $git_repository" );
            } else {
                print_and_log( "Skip cloning package $package because sources already exist");
            }

        } elsif( $opt_update ) {

            print_and_log( "\nchecking out sources for package $package");
            chdir_and_echo( $package_source_dir );
            cmd_and_echo( "git pull" );

        }

        if( ! -d $package_source_dir )
        {
            print_and_log( "skipping package $package because sources not found");
            next;
        }

        if( $opt_update || $opt_configure || $opt_make || $opt_install || $opt_all )
        {
            print_and_log( "\nsetting up links for package $package");

            # make soft link to base package
            chdir_and_echo( "$package_source_dir" );
            foreach $base_package( @base_packages )
            {
                if( ! -e $base_package )
                {
                    if( $opt_mingw )
                    {
                        dircopy( "$source_dir/shared-libraries/$base_package", "$package_source_dir/$base_package" );
                    } else {
                        cmd_and_echo( "ln -sf $source_dir/shared-libraries/$base_package $base_package" );
                    }
                }
            }
        }

        ###########################################
        # increment version number
        if( $opt_release )
        {
            print_and_log( "\nbumping release number for package $package");

            chdir_and_echo( "$package_source_dir" );
            $version = process_cmake_file( "$package_source_dir/CMakeLists.txt" );

            if( !$version )
            {
                print_and_log( "no version found. Aborting." );
                exit();
            }

            # process "pro" files
            chdir_and_echo( "$package_source_dir" );
            foreach $file( split( /\n/, `find -name "*.pro"` ) )
            { process_project_file( $file, $version ); }

        }

        ###########################################
        # store version number
        {
            print_and_log( "\nretrieving version for package $package");

            chdir_and_echo( "$package_source_dir" );
            $version = get_version( "$package_source_dir/CMakeLists.txt" );

        }


        ###########################################
        if( $opt_configure || $opt_all )
        {

            print_and_log( "\nconfiguring package $package");

            # create build dir
            chdir_and_echo( "$package_build_dir" );

            # options
            my $cmake_options = "-DCMAKE_INSTALL_PREFIX=$install_dir -DCMAKE_BUILD_TYPE=$buildType";
            $cmake_options = $cmake_options." -DCMAKE_CXX_FLAGS=\"-Wall -Wno-deprecated-declarations -Werror -Wextra -Wno-stringop-overflow\" ";
            if( $opt_clazy )
            {
                $cmake_options = $cmake_options." -DCMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES=/usr/include";
            }

            if( $opt_ninja ) { $cmake_options = $cmake_options." -GNinja"; }
            if( $opt_mingw ) { $cmake_options = $cmake_options." -G \"MinGW Makefiles\""; }
            if( $opt_shared ) { $cmake_options = $cmake_options." -DUSE_SHARED_LIBS=ON"; }
            if( $opt_qt6 ) {  $cmake_options = $cmake_options." -DUSE_QT6=ON"; }
            cmd_and_echo( "cmake $cmake_options $package_source_dir" );

        }

        ###########################################
        if( $opt_clean )
        {
            print_and_log( "\cleaning package $package");

            # create build dir
            chdir_and_echo( "$package_build_dir" );

            # clean
            cmd_and_echo( "$make clean" );
        }

        ###########################################
        if( $opt_make || $opt_install || $opt_all )
        {

            print_and_log( "\nbuilding package $package");

            # create build dir
            chdir_and_echo( "$package_build_dir" );

            # clean
            if( $opt_clean )
            { cmd_and_echo( "$make clean" ); }

            # compile
            cmd_and_echo( "$make $makeFlags" );

            # install
            if( $opt_install || $opt_all )
            {
                cmd_and_echo( "$make $makeFlags install" );
                # cmd_and_echo( "$make $makeFlags install/strip" );
            }

        }

        ###########################################
        # stop here for shared libs
        if( $package eq $shared_lib_package )
        {

            print_and_log( "\npackage $package succesfully built" );
            next;

        }

        ###########################################
        if( $opt_dist || $opt_all )
        {
            print_and_log( "\nsetting up distributed tarballs for package $package");

            my $dist_package = "$package-$version";
            chdir_and_echo( "$package_build_dir" );

            # make tarballs
            cmd_and_echo( "$make package_source" );

            # untar
            chdir_and_echo( "$source_dist_dir" );
            cmd_and_echo( "rm -rf $dist_package" );
            cmd_and_echo( "gtar -xzvf $package_build_dir/$dist_package.tar.gz" );

        }

        ###########################################
        if( $opt_dist || $opt_all )
        {
            print_and_log( "\nbuilding distributed tarballs for package $package");

            # create dist build dir
            my $dist_package = "$package-$version";
            my $dist_package_source_dir = "$source_dist_dir/$dist_package";
            my $dist_package_build_dir  = "$build_dist_dir/$package";
            cmd_and_echo( "rm -rf $dist_package_build_dir" );
            chdir_and_echo( "$dist_package_build_dir" );

            # configure, compile, and install
            my $cmake_options = "-DCMAKE_INSTALL_PREFIX=$install_dist_dir -DCMAKE_BUILD_TYPE=$buildType";
            if( $opt_ninja ) { $cmake_options = $cmake_options." -GNinja"; }

            cmd_and_echo( "cmake $cmake_options $dist_package_source_dir" );
            cmd_and_echo( "$make $makeFlags install/strip" );

            # store release file
            my $release_dist_file = $package_build_dir."/".$package."-".$version.".tar.gz";
            push( @tarball_files, $release_dist_file );

            # clean
            chdir_and_echo( "$dist_package_build_dir/.." );
            cmd_and_echo( "rm -rf $dist_package_build_dir" );

        }

        ###########################################
        if( $opt_rpm || $opt_all )
        {
            print_and_log( "\nbuilding rpm for package $package");

            # make dist
            my $package_build_dir = "$build_dir/$package";
            chdir_and_echo( "$package_build_dir" );
            cmd_and_echo( "$make package_source" );

            # run rpmbuild
            my $dist_package = "$package-$version";
            cmd_and_echo( "rpmbuild -ta $dist_package.tar.gz" );

            # store rpms in list of release files
            my $rpmbuild = `echo \$HOME/rpmbuild`;
            chomp( $rpmbuild );

            chdir_and_echo( "$rpmbuild" );
            my $command = "find -name \"$package-$version\*rpm\" | grep -v debug";
            my @rpm_files_local = split( /\n/, `$command` );

            foreach $file( @rpm_files_local )
            { push( @rpm_files, $file ); }

            # clean
            chdir_and_echo( "$rpmbuild" );
            cmd_and_echo( "rm -rf BUILD/$package-$version" );
        }

        print_and_log( "\npackage $package succesfully built" );

    }

    print_and_log( "\nall packages succesfully processed" );

    ###########################################
    # print generated tarballs
    my $tarball_count = @tarball_files;
    if( $tarball_count >= 1 )
    {
        print_and_log("");
        print_and_log( "Generated tarballs: " );
        foreach $file( @tarball_files )
        { print_and_log( "  lftp -u hugo.pereira,\@n\@rch1e ftpperso.free.fr -e 'cd software/tgz/; put $file; quit'" ); }
        print_and_log("");
    }

    ###########################################
    # print generated rpms
    my $rpm_count = @rpm_files;

    if( $rpm_count >= 1 )
    {
        # store rpms in list of release files
        my $rpmbuild = `echo \$HOME/rpmbuild`;
        chomp( $rpmbuild );

        print_and_log("");
        print_and_log( "Generated rpms: " );
        foreach $file( @rpm_files )
        { print_and_log( "  lftp -u hugo.pereira,\@n\@rch1e ftpperso.free.fr -e 'cd software/rpm/; put $rpmbuild/$file; quit'" ); }

        print_and_log("");
    }

    close(LOG);
}

###########################################
sub process_cmake_file
{
    my $file = $_[0];

    print_and_log( "process_cmake_file - file: $file" );

    my $major = -1;
    my $minor = -1;
    my $patch = -1;
    my $changed = 0;
    my @converted;
    foreach $line( split( /\n/, `more $file` ) )
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

        # increment version
        if( !$opt_no_increment )
        {

            if( $opt_major )
            {

                if( $type eq "MAJOR" ) { $changed = 1; $local_version++; }
                elsif( $type eq "MINOR" ) { $changed = 1; $local_version=0; }
                elsif( $type eq "PATCH" ) { $changed = 1; $local_version=0; }

            } elsif( $opt_minor ) {

                if( $type eq "MINOR" ) { $changed = 1; $local_version++; }
                elsif( $type eq "PATCH" ) { $changed = 1; $local_version=0; }

            } elsif( $type eq "PATCH" ) { $changed = 1; $local_version++; }

        }

        # update line
        if( $changed )
        { $line = "SET(".$package."_VERSION_".$type." ".$local_version.")"; }

        # and add
        push( @converted, $line );

        # store
        if( $type eq "MAJOR" )    { $major = $local_version; }
        elsif( $type eq "MINOR" ) { $minor = $local_version; }
        elsif( $type eq "PATCH" ) { $patch = $local_version; }

    }

    my $new_version;
    my $found = ($major>=0) && ($minor>=0) && ($patch>=0);
    if( !$found )
    {

        print_and_log( "process_cmake_file - unable to find version." );

    } else {

        # rewrite file
        if( $changed )
        {

            open(TMP, ">$file");
            foreach $line( @converted )
            { print TMP "$line\n"; }
            close( TMP );

        }

        # build new version
        $new_version = "$major.$minor.$patch";

    }

    return $new_version;

}

###########################################
sub process_project_file
{

    print_and_log( "process_project_file - file: $file" );

    my $file = $_[0];
    my $version = $_[1];

    # need to parse version because version 'prefix' are not recognized by qmake
    if( $version =~ /(\S+)(\d+\.\d+\.\d+)/ )
    { $version = $2; }

    my @lines = split( /\n/, `more $file` );
    my @converted;
    my $changed = 0;
    foreach $line( @lines )
    {

        # check for "AM_INIT_AUTOMAKE" string
        # template is: VERSION = 1.5
        if( !( $line =~ /^\s*VERSION\s*=\s*(\S+)\s*$/ ) )
        {
            push( @converted, $line );
            next;
        }

        my $old_version = $1;
        $changed = !( $version eq $old_version );
        if( $changed )
        {
            print_and_log( "process_project_file - file: $file, $old_version -> $version" );
            $line = "VERSION = $version";
        }

        push( @converted, $line );

    }

    if( $changed )
    {

        # rewrite file
        open(TMP, ">$file");

        foreach $line( @converted )
        { print TMP "$line\n"; }

        close( TMP );

    }

    return;

}

###########################################
sub get_version
{
    my $file = $_[0];

    print_and_log( "get_version - file: $file" );

    my $major = -1;
    my $minor = -1;
    my $patch = -1;
    foreach $line( split( /\n/, `more $file` ) )
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
        print_and_log( "get_version - version: $version" );
        return $version;

    }

}

###########################################
# usage
sub usage
{
    print( "usage: build_packages.pl [options] <package1> [<package2>] [<...>]\n");
    print( "where options are one or several of the following:\n");
    print( "  --file                specify file containing packages to be build\n" );
    print( "  --clang               use clang compiler\n");
    print( "  --clean               clean all compilation areas before make\n");
    print( "  --clone               clone repositories\n");
    print( "  --update              update package sources\n");
    print( "  --configure           runs cmake\n");
    print( "  --make                compile sources\n");
    print( "  --install             install sources\n");
    print( "  --prefix              installation prefix\n" );
    print( "  --all                 all of the above except clean\n" );
    print( "  --shared              build in shared library mode.\n");
    print( "  --release             Increment version number.\n");
    print( "  --major               In conjonction with --release, increment major version number.\n" );
    print( "  --minor               In conjonction with --release, increment minor version number.\n" );
    print( "  --no-increment        In conjonction with --release, do not increment version number.\n" );
    print( "  --dist                create a distribution tarball.\n" );
    print( "  --rpm                 create a rpm file.\n" );
    print( "  --help                display this help and exit\n");
    goto END;

}

###########################################
# print command to screen and log
sub print_and_log
{

    print "$_[0]\n";
    print LOG "$_[0]\n";

}

###########################################
# run command and log
sub cmd_and_echo
{
    print_and_log( "$_[0]" );
    goto END if &doSystemFail("$_[0]");
}

###########################################
# create directory and log
sub mkdir_and_echo
{
    my $dir =  $_[0];
    print_and_log( "mkdir -p $dir" );

    if( ! -d $dir ) { make_path( "$dir" ); }
}

###########################################
# change directory and log
sub chdir_and_echo
{
    mkdir_and_echo( "$_[0]" );
    print_and_log("cd $_[0]");
    chdir "$_[0]";
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
