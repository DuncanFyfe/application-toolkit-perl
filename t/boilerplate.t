#!perl -T
use 5.8;
use strict;
use warnings FATAL => 'all';
use Test::More;

plan tests => 18;

sub not_in_file_ok {
    my ($filename, %regex) = @_;
    open( my $fh, '<', $filename )
        or die "couldn't open $filename for reading: $!";

    my %violated;

    while (my $line = <$fh>) {
        while (my ($desc, $regex) = each %regex) {
            if ($line =~ $regex) {
                push @{$violated{$desc}||=[]}, $.;
            }
        }
    }

    if (%violated) {
        fail("$filename contains boilerplate text");
        diag "$_ appears on lines @{$violated{$_}}" for keys %violated;
    } else {
        pass("$filename contains no boilerplate text");
    }
}

sub module_boilerplate_ok {
    my ($module) = @_;
    not_in_file_ok($module =>
        'the great new $MODULENAME'   => qr/ - The great new /,
        'boilerplate description'     => qr/Quick summary of what the module/,
        'stub function definition'    => qr/function[12]/,
    );
}

TODO: {
  local $TODO = "Need to replace the boilerplate text";

  not_in_file_ok(README =>
    "The README is used..."       => qr/The README is used/,
    "'version information here'"  => qr/to provide version information/,
  );

  not_in_file_ok(Changes =>
    "placeholder date/time"       => qr(Date/time)
  );

  module_boilerplate_ok('lib/Exec.pm');
  module_boilerplate_ok('lib/Msg.pm');
  module_boilerplate_ok('lib/Msg/Parser.pm');
  module_boilerplate_ok('lib/Exception.pm');
  module_boilerplate_ok('lib/Timestamp.pm');
  module_boilerplate_ok('lib/AppConfig.pm');
  module_boilerplate_ok('lib/Date.pm');
  module_boilerplate_ok('lib/Serial.pm');
  module_boilerplate_ok('lib/Daemonize.pm');
  module_boilerplate_ok('lib/File/Util.pm');
  module_boilerplate_ok('lib/File/Lock.pm');
  module_boilerplate_ok('lib/File/Pid.pm');
  module_boilerplate_ok('lib/File/Finder.pm');
  module_boilerplate_ok('lib/Csv/Reader.pm');
  module_boilerplate_ok('lib/Csv/Writer.pm');
  module_boilerplate_ok('lib/Csv/Error.pm');


}

