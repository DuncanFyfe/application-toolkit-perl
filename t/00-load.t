#!perl -T
use 5.8;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 16;

BEGIN {
    use_ok( 'Exec' ) || print "Bail out!\n";
    use_ok( 'Msg' ) || print "Bail out!\n";
    use_ok( 'Msg::Parser' ) || print "Bail out!\n";
    use_ok( 'Exception' ) || print "Bail out!\n";
    use_ok( 'Timestamp' ) || print "Bail out!\n";
    use_ok( 'AppConfig' ) || print "Bail out!\n";
    use_ok( 'Date' ) || print "Bail out!\n";
    use_ok( 'Serial' ) || print "Bail out!\n";
    use_ok( 'Daemonize' ) || print "Bail out!\n";
    use_ok( 'File::Util' ) || print "Bail out!\n";
    use_ok( 'File::Lock' ) || print "Bail out!\n";
    use_ok( 'File::Pid' ) || print "Bail out!\n";
    use_ok( 'File::Finder' ) || print "Bail out!\n";
    use_ok( 'Csv::Reader' ) || print "Bail out!\n";
    use_ok( 'Csv::Writer' ) || print "Bail out!\n";
    use_ok( 'Csv::Error' ) || print "Bail out!\n";
}

diag( "Testing Exec $Exec::VERSION, Perl $], $^X" );
