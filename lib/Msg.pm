package Msg;

# The Exception class uses this class to output messages.
# This class MUST NOT raise Exceptions is MUST die instead.
use strict;
use warnings FATAL => 'all';
use base qw(Log::Dispatch);
use Data::Dumper;
use Timestamp;
use Text::Wrap;
our $VERSION = '1.0.0';

# Place to keep singleton instance object.
use vars qw($_Instance $MinLoglevel $LogtoStdErr $Default @LogLevels);
$_Instance   = undef;
$MinLoglevel = 'info';
$LogtoStdErr = 0;
@LogLevels =
  qw(debug        info        notice       warning       error       critical       alert       emergency);
$Default = {
    _default => [
        'Log::Dispatch::Screen',
        stderr => $ENV{MSG_LOGTO_STDERR} || $LogtoStdErr
    ]
};

sub set_Instance
{
    my ( $c, $v ) = @_;
    if ( $v && UNIVERSAL::isa( $v, 'Msg' ) )
    {
        $_Instance = $v;
    }
    return $_Instance;
}

sub get_Instance
{
    return $_Instance;
}
### Format for output
sub HeadTag
{
    my ( $s, $lvl ) = ( shift, shift );
    my $t = Timestamp->new()->iso8601();
    return '[' . uc($lvl) . '] [' . $t . '] ';
}

sub TailTag
{
    my ( $s, $lvl ) = ( shift, shift );
    return '# [' . uc($lvl) . '] [END]';
}

# Turn references into printable output.
sub Serialize
{
    my $s = shift;
    my @rtn;
    local $Data::Dumper::Terse      = 1;
    local $Data::Dumper::Purity     = 1;
    local $Data::Dumper::Indent     = 0;
    local $Data::Dumper::Sortkeys   = 1;
    local $Data::Dumper::Sparseseen = 1;
    foreach my $rtn (@_)
    {

        if ( !defined $rtn || ref($rtn) )
        {
            push @rtn, Data::Dumper::Dumper($rtn);
        } else
        {
            push @rtn, $rtn;
        }
    }
    return @rtn;
}

sub WrappedUncommented
{
    my ( $s, $lvl ) = ( shift, shift );
    local $Text::Wrap::columns  = $s->{'Text::Wrap::columns'}  || 132;
    local $Text::Wrap::unexpand = $s->{'Text::Wrap::unexpand'} || 0;
    local $Text::Wrap::tabstop  = $s->{'Text::Wrap::tabstop'}  || 4;
    local $Text::Wrap::huge     = $s->{'Text::Wrap::huge'}     || 'overflow';

    # Add a shell / wrapper to the end of all lines but the last
    local $Text::Wrap::separator = $s->{'Text::Wrap::separator'} || " \\\n";
    my @txt = ( Text::Wrap::fill( '', '',  $s->Serialize(@_) ) );
    chomp $txt[-1];
    if ( @txt > 1 )
    {
        push @txt,"\n",$s->TailTag($lvl);
    }
    unshift @txt,'# ',$s->HeadTag($lvl),"\n";
    return @txt,"\n";
}

sub WrappedCommented
{
    # message formatting for most messages.
    my ( $s, $lvl ) = ( shift, shift );

    # If passed just one line of white space (eg "\n")
    # then return "#\n" so we can add 'blank' lines
    # to space out the log file.

    my @tmp = ( $s->HeadTag($lvl), $s->Serialize(@_) );
    
    my $tail = local $Text::Wrap::columns = $s->{'Text::Wrap::columns'} || 130;
    local $Text::Wrap::unexpand  = $s->{'Text::Wrap::unexpand'}  || 0;
    local $Text::Wrap::tabstop   = $s->{'Text::Wrap::tabstop'}   || 4;
    local $Text::Wrap::huge      = $s->{'Text::Wrap::huge'}      || 'overflow';
    local $Text::Wrap::separator = $s->{'Text::Wrap::separator'} || " \\\n";

    # hdr already starts with a hash.
    @tmp = Text::Wrap::fill( '', '', @tmp );
    my @txt = $s->_comment(@tmp);

    if ( @txt > 1 )
    {
        push @txt, "\n", $s->TailTag($lvl);
    }
    return @txt,"\n";
}

sub _comment
{
    my ($s,@tmp) = @_;
    my @txt;
    while(my $txt = shift @tmp) {
        my $eol = chomp($txt);
        my @x = split /\n+/,$txt;
        foreach my $x (@x) {
            push @txt,'# '.$x."\n";
        }
    }
    chomp $txt[-1];
    return @txt;
}

sub UnwrappedCommented
{
    my ( $s, $lvl ) = ( shift, shift );
    my @txt;
    my @tmp;
    if ( @_ == 1 && !ref( $_[0] ) && $_[0] =~ /^\s+$/ )
    {
        @txt = ("#\n");
    } else
    {
        @tmp = $s->_comment( $s->Serialize(@_) );
        if ( @txt > 1 )
        {
            chomp $txt[-1];
            push @txt, "\n", $s->TailTag($lvl);
        }
        unshift @txt, '# ',$s->HeadTag($lvl), "\n";
    }
    return @txt,"\n";
}

sub UnwrappedUncommented
{
    my ( $s, $lvl ) = ( shift, shift );
    my @txt;
    if ( @_ == 1 && !ref( $_[0] ) && $_[0] =~ /^\s+$/ )
    {
        @txt = ("\n");
    } else
    {
        @txt = $s->Serialize(@_);
    }
    if ( @txt > 1 )
    {
        push @txt, $s->TailTag($lvl), "\n";
    }
    
    unshift @txt, '# ',$s->HeadTag($lvl), "\n";
    return @txt;
}
### overide base methods to allow different message formatting
foreach my $name (qw( debug info notice warning ))
{
    no strict 'refs';
    *$name = sub {
        my $s = shift;

        # Allow default object construction from class cold calling.
        $s = ref($s) ? $s : $s->new();
        my @txt = $s->WrappedCommented( uc($name), @_ );

        $s->log( level => $name, message => join( '', @txt ) );
    };
}
### as base methods but with added stack trace  so you can see how you
# got to where you are.
foreach my $name (qw( debug_trace info_trace notice_trace warning_trace ))
{
    no strict 'refs';
    *$name = sub {
        my $s = shift;

        # Allow default object construction from class cold calling.
        $s = ref($s) ? $s : $s->new();
        $s->_trace($name);
        my @txt = $s->WrappedCommented( uc($name), @_ );
        $s->log( level => $name, message => join( '', @txt ) );
    };
}
### overide base methods to allow different message formatting and add a stack trace.
foreach my $name (qw( error critical alert emergency ))
{
    no strict 'refs';
    *$name = sub {
        my $s = shift;

        # Allow default object construction from class cold calling.
        $s = ref($s) ? $s : $s->new();

        $s->log(
            level   => $name,
            message => join( '', $s->UnwrappedCommented( uc($name), @_ ) )
        );
    };
}

# Additional level "output" is used to log command output (see Exec.pm) in executable logs.
sub output
{
    my $s = shift;
    $s = ref($s) ? $s : $s->new();
    my $reallevel = 'info';
    my @txt = $s->WrappedCommented( 'OUTPUT', @_ );
    $s->log( level => $reallevel, message => join( '', @txt ) );
}

# Additional level "command" is used to log external commands (see Exec.pm) in executable logs.
sub command
{
    my $s = shift;
    $s = ref($s) ? $s : $s->new();
    my $reallevel = 'info';
    my @txt = $s->WrappedUncommented( 'COMMAND', @_ );
    $s->log( level => $reallevel, message => join( '', @txt ) );
}

sub _mark
{
    # This in the internal method that also takes a log level.
    # It marks the log only if the mark level would log.
    # It needs to be passed the caller details to get them right.
    my ( $s, $lvl, @c ) = @_;
    $s = ref($s) ? $s : $s->new();
    $s->log(
        level   => $lvl,
        message => join( '',
            $s->UnwrappedCommented( 'MARK', join( ':', @c[ 0 .. 3 ] ) ) )
    );
}

sub mark
{
    # This is a user method that adds a code position mark trace level.
    my $s = shift;
    $s = ref($s) ? $s : $s->new();
    $s->_mark( 'trace', caller(0) );
}

sub _trace
{
    # This in the internal method that also takes a log level.
    my ( $s, $lvl ) = ( shift, shift );
    $s = ref($s) ? $s : $s->new();
    if ( $s->would_log($lvl) )
    {
        my @trace    = ();
        my $c        = 0;
        my $maxlevel = 12;    # Arbitrary depth limit.
        while ( ( $c++ < $maxlevel ) && ( my @c = caller($c) ) )
        {
            push( @trace, join( ' : ', @c[ 0 .. 3 ] ) . "\n" );
        }
        $s->log(
            level   => $lvl,
            message => join( '', $s->UnwrappedCommented( 'TRACE', @trace, @_ ) )
        );
    }
}

sub trace
{
    # output a stack trace at trace level to the log files.
    my $s   = shift;
    my $lvl = 'trace';
    $s = ref($s) ? $s : $s->new();
    if ( $s->would_log($lvl) )
    {
        my @trace    = ();
        my $c        = 0;
        my $maxlevel = 12;    # Arbitrary depth limit.
        while ( ( $c++ < $maxlevel ) && ( my @c = caller($c) ) )
        {
            push( @trace, join( ' : ', @c[ 0 .. 3 ] ) . "\n" );
        }
        $s->log(
            level   => $lvl,
            message => join( '', $s->UnwrappedCommented( 'TRACE', @trace, @_ ) )
        );
    }
}

sub usage
{
    # Writing program usage statements without messing them up to much.
    my $s = shift;
    $s = ref($s) ? $s : $s->new();
    $s->log(
        level   => 'info',
        message => join( '', $s->UnwrappedCommented( "USAGE:", @_ ) )
    );
}

# Some aliases.
*warn  = *warning;
*err   = *error;
*crit  = *critical;
*emerg = *emergency;

# Reach inside Log::Dispatch and return a sorted list of the output
# names already defined
sub has_output
{
    my ( $s, $n ) = (@_);
    return exists( $s->{outputs}->{$n} );
}

sub outputs
{
    return sort keys %{ $_[0]->{outputs} };
}

sub adddispatchers
{
# Initialize a logger object with dispatchers
# $h = { name1 => [ 'Logger::Dispatch::Foo' , min_level => 'info' , fooname => 'bar' ]
#    ,   name2 => [ 'Logger::Dispatch::Bar' min_level => 'debug' , barname => 'baz' ]
#    , ...
# };
    my ( $s, $h ) = (@_);
    $s = ref($s) ? $s : $s->new();
    my %h = $h ? %$h : ();
    my $count = 0;
    while ( my ( $name, $defn ) = each %h )
    {
        my @defn  = @{$defn};
        my $class = shift(@defn);
        die(
            'NODISPATCHCLASS',
            'Dispatch class not provided',
            Data::Dumper::Dumper(
                { name => $name, class => $class, defn => $defn }, $h
            )
        ) unless ($class);
        my $classloaderror = 0;
        unless ( $INC{$class} )
        {
            no strict qw(refs);
            eval qq{
                    package _sandbox;
                    require $class;
            };
            if (
                Exception->eval_warn( $@, 'Unable to load library: ', $class ) )
            {
                $classloaderror = 1;
            }
        }
        unless ($classloaderror)
        {
            unless ( grep /min_level/, @defn )
            {
                push @defn, 'min_level', $MinLoglevel;
            }
            my $obj = $class->new( name => $name, @defn );

            #$s->SUPER::add( $obj );
            $s->add($obj);
            $count++;
        }
    }
    return $count;
}

sub removedispatchers
{
    my ( $c, @names ) = (@_);
    my $s = $c->new();
    my @rtn;
    foreach my $n (@names)
    {
        my $r = $s->remove($n);
        push @rtn, $r if $r;
    }
    return @rtn;
}

sub get_loglevelvalue
{
    my ( $c, $lvl ) = (@_);
    my ($rtn) = grep { $LogLevels[$_] eq $lvl } 0 .. $#LogLevels;
    return $rtn;
}

sub new
{
    my ( $c, $h ) = @_;
    $c = ref($c) || $c || __PACKAGE__;
    my $s;
    if ( !$_Instance )
    {
        $h ||= $Default;
        $_Instance = bless $c->SUPER::new(), $c;
    }
    $_Instance->adddispatchers($h) if $h;
    return $_Instance;
}

# Match Class::Singleton interface.
*instance = *new;

=head1 NAME

Msg - Extend Log::Dispatch with message formatting and some extra log methods.

=head1 VERSION

Version 1.0.0


=head1 SYNOPSIS

Msg provides a singleton front end to Log::Dispatch and provides some additional log and convenience methods. It also formats the output for writing to executabe logs.  All methods can be called from class or object context. Without parameters a default screen logger is created.

    use Msg;
    
    $Msg::MinLogLevel = 'info'; # Default min_level value passed to default log dispatcher.
    $Msg::$LogtoStdErr = 0;     # Default stderr value passed to default log dispatcher.
    $Msg::Default = { _default => { class => 'Log::Dispatch::Screen' , min_level => $ENV{MSG_MIN_LOGLEVEL} || $MinLoglevel , stderr => $ENV{MSG_LOGTO_STDERR} || $LogtoStdErr }};
    # The default dispatcher parameters if Msg is instantiated without parameters.
    
    my $foo = Msg->new({ name1 => [ 'Logger::Dispatch::Foo' , min_level => 'info' , fooname => 'bar' ]
        , name2 => [ 'Logger::Dispatch::Bar' min_level => 'debug' , barname => 'baz' ] ...});
    # Get a logger object and add the specified dispatchers, trying to load modules as necessary.
    
    Msg->adddispatchers(({ name1 => [ 'Logger::Dispatch::Foo' , min_level => 'info' , fooname => 'bar' ]
        , name2 => [ 'Logger::Dispatch::Bar' min_level => 'debug' , barname => 'baz' ] ...});
    # Try to load the specififed dispatch modules and add instances to the logger.
    
    Msg->outputs()                 # Return a list of dispatchers by name.
    Msg->removedispachers(@names)  # Remove dispatchers by name.
    Msg->has_output($name)         # Test for the presence of a dispatcher with the given name.  
    

    Msg->error(@text) # Format and log the text at error level.
    # Similarly for trace, info, warning|warn, err, critical|crit, alert nd emergency|emerg log levels.
    # Log levels error and above will have a caller backtrace added.
   
    # The next two methods are used when creating executable log files.    
    Msg->output(@output) format and log the output retrieved from an external command to an executable log file.
    Msg->command($command) format and log the command to an executable log file.
    
    # I have used the following during development and for debugging YMMV.    
    Msg->trace() use caller() to log a backtrace at trace log level.
    Msg->mark() use caller to mark code locations to the log file.
     
    Msg->usage(@usage) # convenient formatting of script usage (help) messages.


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Msg


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
1;    # End of Msg
