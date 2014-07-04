package AppConfig;
use strict;
use warnings FATAL => 'all';
use Msg;
use Config::IniFiles;
use Getopt::Long;
use Storable;
use File::Basename;
use File::Spec;
use FindBin;
use Exception;
our $VERSION = '1.00';

# %Opt holds the unprocessed Getopt::Long options.
use vars qw(@Usage %Opt $DefaultConffilename $Defaultsection $Fallbacksection);

# Default  Section of configuration file to use for default values
$DefaultConffilename = File::Basename::basename($0) . ".conf";
$Defaultsection      = 'default';
$Fallbacksection     = $Defaultsection;

sub get_configoptpaths
{
    return $_[0]->{configoptpaths};
}

sub set_configoptpaths
{
    my $s = shift;
    @{ $s->{configoptpaths} } = (@_);
}
sub get_config { my $s = shift; return $s->{config}; }

sub get_configfile
{
    return $_[0]->{_read_configfile} || $_[0]->{configfile};
}

sub set_configfile
{
    my $s = shift;
    $s->{configfile} = shift;
    return $s;
}

sub new
{
    my ( $c, $h ) = (@_);
    $c = ref($c) || $c || __PACKAGE__;
    my $s = bless {
        usage  => ["Usage: $FindBin::Script"],
        config => undef,
        configfile => $DefaultConffilename   # The configuration file with path.
        ,
        configoptpaths => [
          ] # Optional configuration file paths if the configfile isn't found directly.
        ,
        default  => $h->{default}  || $Defaultsection,
        fallback => $h->{fallback} || $Fallbacksection,
        _defn    => {},
        _value   => {},
        _optlong => [],
        _getcommandline     => 0,
        _read_configfile    => undef,
        _resolve_priorities => 0
    }, $c;
    return $s;
}

sub make_commandline
{
# $obj->makecommandline(%defn);
# %defn = (
#    optionname => { t => '' , d=> [] , m => '' , u => ''}
#    -description => []
# )
# optioname => --optionname
# t == GetOpt::Long type eg. =s@
# d == default value
# m == a modifier to call with the value (a subref or a name)
# u == usage message
# c == Configuration section this parameter can be read from.  If c is undefined then this option will not be read from the configuration file.
# -description => an array ref of text lines added to the usage message.
    my ( $s, %defn ) = (@_);

    # Extract a descption record
    my $disc = delete $defn{-description} || [];
    push @{ $s->{usage} }, @{$disc};

    # Extra options added as a matter of course.
    $defn{help} ||= { t => '|usage', d => 0, u => 'Print usage information.' };

    # %tmp will collect the length of usage strings so we can format them nicely
    my %length;
    my %opt;
    my %cline;
    my %cfile;
    my %usage;
    my @opt;
    my $maxlen = 0;
    foreach my $k ( sort keys %defn )
    {
        $opt{$k}   = undef;
        $cline{$k} = undef;
        $cfile{$k} = undef;
        push( @opt, $k . $defn{$k}{t} );
        $length{$k} = length($k) + length( $defn{$k}{t} );
        $maxlen = $length{$k} if ( $length{$k} > $maxlen );
        $usage{$k} = '    --' . $k . $defn{$k}{t} . '__SPACE__' . $defn{$k}{u};
    }
    $s->{_value}       = \%opt;
    $s->{_commandline} = \%cline;
    $s->{_configfile}  = \%cfile;
    $s->{_optlong}     = \@opt;
    $s->{_defn}        = Storable::dclone( {%defn} );
    foreach my $k ( sort keys %usage )
    {
        my $nspc = $maxlen - $length{$k} + 4;
        my $spc  = ' ' x $nspc;
        $usage{$k} =~ s/__SPACE__/$spc/;
        push( @{ $s->{usage} }, $usage{$k} );
    }
}

sub _processinput
{
    my ( $s, $source, %args ) = @_;
    my $vals = $s->{$source};
    foreach my $k ( sort( keys( %{$vals} ) ) )
    {
        if ( exists( $args{$k} ) )
        {
            $vals->{$k} = $args{$k};
        }
    }
}

sub _read_commandline
{
    my $s = shift;
    if ( !$s->{_getcommandline} )
    {
        GetOptions( \%Opt, @{ $s->{_optlong} } );
        $s->_processinput( '_commandline', %Opt );
        $s->{_getcommandline} = 1;
    }
    if ( $Opt{help} )
    {
        $s->usage();
    }
    return $s;
}

sub _find_configfile
{
    my $s = shift;
    my $rtn;
    my $fname = $s->{_commandline}{configfile} || $s->{configfile};
    if ( -f $fname )
    {
        $rtn = $fname;
    } else
    {
        my $basename = File::Basename::basename($fname);
        foreach my $dirname ( @{ $s->{configoptpaths} } )
        {
            my $fname = File::Spec->catfile( $dirname, $basename );
            if ( -f $fname )
            {
                $rtn = $fname;
                last;
            }
        }
    }
    return $rtn;
}

sub _read_configfile
{
    my $s     = shift;
    my $fname = $s->_find_configfile();
    if ( !$s->{_read_configfile} && $fname )
    {
        $s->{_read_configfile} = $fname;
        my %h;
        my %later;
        my $section = $s->{default};

        # Only supply default and fallback options if they have been specified.
        my %c;
        foreach my $k (qw(default fallback))
        {
            if ( $s->{$k} )
            {
                $c{"-$k"} = $s->{$k};
            }
        }
        my $config = Config::IniFiles->new(
            -file   => $fname,
            -nocase => 1,
            %c
        );
        if ( !$config )
        {
            Exception->error(
                {
                    status => 'Config::IniFiles',
                    text   => [@Config::IniFiles::errors],
                    object => \%c
                }
            );
        }
        $s->{config} = $config;
        foreach my $k ( keys %{ $s->{_defn} } )
        {
            my $ckey = $s->{_defn}{$k}{c};
            if ( defined($ckey)
                && $config->SectionExists($ckey) )
            {
                my $islist =
                  $s->{_defn}{$k}{t} && ( $s->{_defn}{$k}{t} =~ /\@/ );
                if ($islist)
                {
                    $h{$k} = [ $config->val( $ckey, $k ) ];
                } else
                {
                    $h{$k} = $config->val( $ckey, $k );
                }
            }
        }
        $s->_processinput( '_configfile', %h );
    }
    return $s;
}

sub _resolve_priorities
{
    my $s = shift;
    if ( !$s->{_resolve_priorities} )
    {
        my $vals = $s->{_value};
        my $cl   = $s->{_commandline};
        my $cf   = $s->{_configfile};
        foreach my $k ( sort( keys( %{$vals} ) ) )
        {
            my $clv     = $cl->{$k};
            my $cfv     = $cf->{$k};
            my $def     = $s->{_defn}{$k}{d};
            my $ckey    = $s->{_defn}{$k}{c};
            my $mod     = $s->{_defn}{$k}{m};
            my $isarray = $s->{defn}{$k}{t} && $s->{defn}{$k}{t} =~ /\@/;
            if ($clv)
            {
                $vals->{$k} = $clv;
            } elsif ($ckey)
            {
                $vals->{$k} = $cfv;
            } else
            {
                $vals->{$k} = $def;
            }
            if ($mod)
            {
                no strict;
                my $v;
                eval { $v = $mod->( $vals->{$k} ); };
                my $w = Exception->eval_warn( $!,
                    "Calling $mod to process configuration option $k failed." );
                unless ($w)
                {
                    $vals->{$k} = $v;
                }
            }
            if ($ckey)
            {
                $s->{config}->setval( $ckey, $k, $vals->{$k} );
            }
        }
        $s->{_resolve_priorities} = 1;
        delete $s->{_commandline};
        delete $s->{_configfile};
    }
}

sub get_configvalue
{
    my ( $s, $sect, $name, $default ) = @_;
    my $config = $s->{config};
    if ($config->SectionExists($sect)) {
        my $isarray = exists( $s->{_defn}{$name} ) 
        && $s->{_defn}{$name}{t} =~ /\@/
        && $s->{_defn}{$name}{c}
        && ( $s->{_defn}{$name}{c} eq $sect || $s->{_defn}{$name}{c} eq $Defaultsection );
        
        if ($isarray) {
            return [ $config->val($sect,$name,$default) ];
            
        } else {
            return $config->val($sect,$name,$default) ;
        }
        
    } else {
        Exception->error('BADCONFIG','Requested configuration section does not exists: ' , $sect);
    }
}

sub get_options
{
    my $s = shift;
    $s->_read_commandline();
    $s->_read_configfile();
    $s->_resolve_priorities();
    my $h = Storable::dclone( $s->{_value} );
    return %$h;
}

sub resplitlist
{
    my @args;
    foreach my $arg (@_)
    {
        push @args, ref($arg) ? @$arg : $arg;
    }
    my @rtn = split /[\],\s]/, join( ']', @args );
    my $w = wantarray;
    if ($w)
    {
        return @rtn;
    } elsif ( defined($w) )
    {
        return \@rtn;
    }
}

sub usage
{
    my $s = shift;
    Msg->usage( @{ $s->{usage} } );
    Msg->usage( '@ARGV => ', @ARGV, '<= @ARGV' );
    Msg->usage(@_);
    exit(1);
}
1;

=head1 NAME

AppConfig - A module which allows command line and configuration file options ]to be defined in a consistent way. 

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

A module which brings together Getopt::Long and Config::IniFiles to provide 
common command line and configuration file definition and handling.

    use AppConfig;
    
    
    my %defn = (
        optionname1 => { t => '=s@' , d=> [] , m => Magic , u => 'A list of values', c => ''},
        optionname2 => { t => '=i' , d=> 7 , m => '' , u => 'An integer value', c => 'Numbers'},
        optionname3 => { t => '|opt3' , d=> 0 , m => '' , u => 'A boolean option', c => ''}
        -description = [ ' A brief description ' , 'of the application' ]
    );
    my $configfile ='/an/ini/file';
    my $foo = AppConfig->new();
    $foo->make_commandline(%defn);
    $foo->setconfigoptpaths('path1','path2'...)
    $foo->set_configfile($file);
    my %config = $foo->get_options();
    
    if ($config{help}) {
        AppConfig->usage();
    }

= head1 DETAIL

AppConfig unifies the command line and configuration file definition into a single hash
and provides the methods necessary to read configuration files then override the
options with command line values and return the whole thing in a single hash.

It also allows input values to be specified as using a modifier (eg for parsing or validation)
supplied as a subref or named routine.

The defining hash specifies the command line and the value we expect to get from the configuration file.
It also allows an application description to be supplied using the '-description key'.

The definition hash keys are:
    optioname becomes --optionname on the command line. 
    t => T sets the type of optionname using GetOpt::Long types eg. =s@.
    d => D sets a default value for this type if none is given.
    m => M sets a modifier (subref or name) which I<if> present has the value passed to it and the return value assigned to this key.
    u => U sets a brief usage message.
    c == Configuration section this parameter can be read from.  If c is undefined then this option will not be read from the configuration file.  If it is defined then that section will be searched for a value given by the I<optioname>.

AppConfig gives special treatment to the option I<configfile>.  If it is defined and the appears on the command line 
then that file and only that file will be read as the configuration file.  If it is not specified then the
default configuration file is looked for either where specified then along the paths specified.  

AppConfig constructs a usage method from the -description and options -u values.
Calling AppConfig->usage() causes this message to be written to Msg and the application to exit.  

NOTE: AppConfig uses Getop::Long to parse the command line options.  Getopt::Long and perhaps other modules
eat @ARGV as they process it so take care if you want to combine AppConfig and other command line processing.

=head1 SUBROUTINES/METHODS

=head2 new() | new (%defn)

Construct a new AppConfig object.  Calling it with a defining hash is the same as calling
new() followed by make_commandline(%defn) on the returned object.

=head2 make_commandline(%defn)

Build an command line using the provided definition.

=head2 setconfigoptpaths('path1','path2'...)

Set alternative locations for the configuration file.  These are checked in order
if the configuration file is not found at the specified location

=head2 set_configfile('/path/filename')

Set the configuration file to read.

=head2 get_configvalue($section,$name,$default)

Retrieve the configuration option value for the given section and name.
If the option was declared part of the command line then command line supplied 
values will override those in the configuration file.

=head2 get_options()

Read the command line and configuration file.  Command line values override 
configuration options where both are specified.

=head2 get_config()

Get the configuration object so you can get access to the rest of the configuration file.


=head2 usage()

Write out an application usage method and exit.

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AppConfig


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=application-toolkit-perl>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/application-toolkit-perl>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/application-toolkit-perl>

=item * Search CPAN

L<http://search.cpan.org/dist/application-toolkit-perl/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2014 Duncan Fyfe.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut
1;    # End of AppConfig
