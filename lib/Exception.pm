package Exception;

use strict;
use warnings FATAL => 'all';
use Data::Dumper;
use Msg;

our $VERSION = 1.0;

use overload (
    '""'     => 'stringify',
    '0+'     => 'value',
    fallback => 1
);

# Don't trace back more than this many steps
use vars qw($TraceLimit @DumpLevels);

# Arbitrary limit to how far back traces using caller() can go.
$TraceLimit = 20;

# The exception levels which should dump data and object values to logs.
@DumpLevels = qw(error fatal critical alert emergency);

# Parse input arguments to construct the error message.
# Format the input list into a standardized hash:
# (status,text1,text2,...) =maps to=> (status => status , text => [text1,text2,...])
# ({status => 'x' , text => [...] , object => Object , data => Data }) use all relevant hash keys to populate user writable Exception fields.
sub _parsearguments {

    my ( $s, $h ) = ( shift, shift );

    if ( !UNIVERSAL::isa( $h, 'HASH' ) ) {
        $h = { status => $h };
        $h->{text} = [@_] if (@_);
    }
    return $h;
}

sub _addtrace {

    # Use caller to retrieve call history
    my $s = shift;
    my $c = 0;
    while ( ( $c++ < $TraceLimit ) && ( my @c = caller($c) ) ) {
        push @{ $s->{trace} }, [@c[0 .. 3]];
    }
}

sub _addargs {
    my $s = shift;
    my $h = $s->_parsearguments(@_);
    foreach my $k (qw(status returnvalue signal coredump text object data )) {
        if ( exists( $h->{$k} ) ) {
            $s->{$k} = $h->{$k};
        }
    }
}

sub _addhistory {
    my ( $s, @c ) = @_;
    push @{ $s->{history} }, [@c[ 0 .. 3 ]];
    if ( !$s->{package} ) {
        @$s{qw(package filename line subroutine)} = @c[ 0 .. 3 ];
        print STDERR "package = ",$s->{package},"\n";
        $s->{package_version} = UNIVERSAL::VERSION( $s->{package} );
    }
    return $s;
}

sub stringify {
    my $s = shift;

    # Does the Exception severity mean we need to dump references ?
    my $dump = grep { $s->{level} eq $_ } @DumpLevels;
    if ($dump) {

        # Drop parts of the exception object which are not defined.
        my @k = grep { defined( $s->{$_} ) } ( keys %$s );
        my $tmp;
        @$tmp{@k} = @$s{@k};

        local $Data::Dumper::Indent   = 1;
        local $Data::Dumper::Purity   = 1;
        local $Data::Dumper::Sortkeys = 1;

        # fudge bless so dumped object has the corrent package.
        return Data::Dumper->Dump( [ bless( $tmp, ref($s) ) ],
            [qw(Exception)] );

    }
    else {
        return
            $s->{status} . ' at '
          . $s->{filename}
          . ' line '
          . $s->{line}
          . ' (package '
          . $s->{package} . ")\n"
          . join( '', @{ $s->{text} } );
    }
}

sub new {
    my $c      = shift;
    my @caller = caller(0);
    $c = ref($c) || $c || __PACKAGE__;
    my $s = bless {
        level => 'error',
        ,
        status          => 'UNDEFINED',
        text            => ['An undefined exception has been raised.'],
        returnvalue     => undef,
        signal          => undef,
        codedump        => undef,
        trace           => [],
        history         => [],
        package         => undef,
        filename        => undef,
        line            => undef,
        subroutine      => undef,
        package_version => undef
    }, $c;

    if (@_) {
        $s->_addargs(@_);
    }

    return $s;
}

sub throw {
    my $s = shift;
    my $level = $s->{level} || 'error';
    no strict;
    $s->$level(@_);
}

for my $name (qw(warn error fatal critical alert emergency)) {
    no strict 'refs';
    *$name = sub {
        my @caller = caller(0);    # Get this info asap.
        my $c      = shift;

      # Transparent construction of an object if we are called in class context.
        my $s;
        if ( !ref($c) ) {
            $s = $c->new();
        }
        else {
            $s = $c;
        }
        $s->_addargs(@_);
        $s->_addhistory(@caller);
        $s->_addtrace();

        my $m = Msg->new();

        $m->$name( $s->stringify() );
        if ( $name eq 'warn' ) {

            # Issue warning as well so it can be caught by signal handler
            warn($s);
        }
        elsif ( $name eq 'error' ) {
            die($s);
        }
        elsif ( $name =~ /^(?:fatal|critical|alert|emergency)$/o ) {
            exit( $s->{returnvalue} || 1 );
        }

        return $s;
    };
}

# Some aliases.
*warning  = *warn;
*err   = *error;
*crit  = *critical;
*emerg = *emergency;

# Internal field getters and setters
sub get_status          { return $_[0]->{status}; }
sub set_status          { my $s = shift; $s->{status} = $_[0]; return $s; }
sub get_level           { return $_[0]->{level}; }
sub set_level           { my $s = shift; $s->{level} = $_[0]; return $s; }
sub get_returnvalue     { return $_[0]->{returnvalue}; }
sub set_returnvalue     { my $s = shift; $s->{returnvalue} = $_[0]; return $s; }
sub get_signal          { return $_[0]->{signal}; }
sub set_signal          { my $s = shift; $s->{signal} = $_[0]; return $s; }
sub get_coredump        { return $_[0]->{coredump}; }
sub set_coredump        { my $s = shift; $s->{coredump} = $_[0]; return $s; }
sub get_text            { return $_[0]->{text}; }
sub set_text            { my $s = shift; $s->{text} = $_[0]; return $s; }
sub get_filename        { return $_[0]->{filename}; }
sub set_filename        { my $s = shift; $s->{filename} = $_[0]; return $s; }
sub get_package         { return $_[0]->{package}; }
sub set_package         { my $s = shift; $s->{package} = $_[0]; return $s; }
sub get_package_version { return $_[0]->{package_version}; }

sub set_package_version {
    my $s = shift;
    $s->{package_version} = $_[0];
    return $s;
}
sub get_line       { return $_[0]->{line}; }
sub set_line       { my $s = shift; $s->{line} = $_[0]; return $s; }
sub get_trace      { return $_[0]->{trace}; }
sub set_trace      { my $s = shift; $s->{trace} = $_[0]; return $s; }
sub get_object     { return $_[0]->{object}; }
sub set_object     { my $s = shift; $s->{object} = $_[0]; return $s; }
sub get_data       { return $_[0]->{data}; }
sub set_data       { my $s = shift; $s->{data} = $_[0]; return $s; }
sub get_history    { return $_[0]->{history}; }
sub set_history    { my $s = shift; $s->{history} = $_[0]; return $s; }
sub get_subroutine { return $_[0]->{subroutine}; }
sub set_subroutine { my $s = shift; $s->{subroutine} = $_[0]; return $s; }

sub value {
    my $s = shift;
    return Msg->get_loglevelvalue($s->{level});    
}
# Convenience functions.
sub eval_error {

    # Pass in $@ after an eval to have it thrown as an error.
    # Throws the Exception as an error.
    my ( $c, $err, $msg ) = (@_);
    if ($err) {
        Msg->error($msg) if ($msg);
        if ( ref($err) ) {
            if ( UNIVERSAL::isa( $err, 'Exception' ) ) {
                $err->error();
            }
            else {
                Exception->error(
                    { status => 'EVALERROR', text => [$msg], object => $err } );
            }
        }
        else {
            Exception->error( 'EVALERROR', $msg, $err );
        }
    }
}

sub eval_warn {

    # Pass in $@ after and eval to have errors caught as warnings.
    # Throws the Exception as an warning and returns it.
    my ( $c, $err, $msg ) = (@_);
    my $rtn;
    if ($err) {
        Msg->warn($msg) if ($msg);
        if ( ref($err) ) {
            if ( UNIVERSAL::isa( $err, 'Exception' ) ) {
                $rtn = $err;
            }
            else {
                $rtn = Exception->warn(
                    { status => 'EVALWARN', text => [$msg], object => $err } );
            }
        }
        else {
            $rtn = Exception->warn( 'EVALWARN', $msg, $err );
        }
    }
    return $rtn;
}

1;

=head1 NAME

Exception - Use inbuilt perl functionality to give exceptional exception like properties.

=head1 VERSION

Version 1.0.0


=head1 SYNOPSIS

Exception uses the built in warn(reference), die(reference) and exit(reference) mechanism to
wrap different error reporting methods with a standard Exception mechanism.

    use Exception;

    @Exception::DumpLevels =  qw(error fatal critical alert emergency);
    # Exception levels for which object and data references will be Data::Dumper dumped to the logs. 
    
    my $exc = Exception->new($status,@error_message); 
    #   Construct an exception with the given status and error message and default error exception level.
    
    my $exc = Exception->new({ status => $status, text => [@error_message] , returnvalue => $value , signal => $signal , coredump => $coredump , object => $object ,  data => $data });
    #   Construct an exception with the given fields; all fields are optional.  
    #   The fields returnvalue, signal and coredump record aspects of external command failures.
    #   The object field is typically assigned problem object references.
    #   The data field is typically assigned a reference to problem input or output data.
    
    $exc->throw();  # Cause an existing exception to be thrown at the level of the exception.
    $exc->fatal();  # Calling an existing exception with a different exception level resets the exceptions level and causes it to be thrown at the new level.
    
    $exc->warn($status, @error_message)  # Construct an exception with the given status and error message then throw it at the warn level.
    $exc->emergency({ status => $status, text => [@error_message] , returnvalue => $value , signal => $signal , coredump => $coredump , object => $object ,  data => $data })  # Construct an exception with the given fields and throw it as an emergency exception.

    Exec->eval_error($err, @error_message);  
    # Convenience method to test $@ after an eval and throw convert $@ to an Exception->error() if necessary.
    
    Exec->eval_warn($err, @error_message);  
    # Convenience method to test $@ after an eval and throw convert $@ to an Exception->warn() if necessary. 

=head 1 DETAILED

This exception class is built ontop of perl's internal warn , die and exit functions.  If warn or die are passed an object reference rather than a string then the object is passed back rather than an error message.  This is a convenient way to pass arbitrary globs from the point of failure to a point where the failure might be acted upon.

Exception includes a caller() trace from the point of creation and maintains a history of where it has been thrown from.

In some circumstances one man's exception is another man's acceptable condition. Exceptions provide a broader scoped 'return'. Using eval {}; $@... we can catch an exception and act accordingly.   For example:

    my $err;
    eval{ $object->method2() }; # will catch the exception object in $@
    $err = $@    # $@ will be overwitten by the next failure so put it somewhere safe.
    if ($err) { ... }

This allows us to implement exceptions using standard perl functions which will also work for library methods some of which will use die(), others of which use Carp.

 The principal methods of the Exception class are new , throw and the log levels:  warn , error , fatal , critical , alert and emergency

The methods warn , error , fatal , critical , alert , emergency map onto Msg methods and determine different logging levels and actions.

Exception->warn(...) will construct an exception and 'throw' it using warn()
Exception->error(...)  will construct an exception and 'throw' it using die()
Exception->fatal(...) (and critical , alert , emergency) will construct an exception and 'throw' it via exit().
Exception->new(...) will contruct an exception object but not throw it.
$object->throw(...) will throw exception $obj according to it's exception level.

With the exception of throw, all of the above methods act as object constructors. If called on an existing object a log level method (eg. fatal()) will use the exception object and throw it at the specified level. For example:

    eval { some code };
    my $exc = $@;
    $exc->status() eq 'OUTOFMEMORY' ? $exc->emergency() : $exc->error();
    

For constructors there are two accepted arrangements of parameters.  Either the abreviated constructor call:
    Exception->new( 'status' , 'textline1' , 'textline2' , ... );
OR the full constructor call:
    Excpetion->new( { status => 'status' , text => [ 'textline1' , 'textline2' ] , object => objectref , data => dataref , ... } );

With the full constructor all fields are optional.  
    The fields returnvalue, signal and coredump record aspects of external command failures.
    The object field is typically assigned problem object references.
    The data field is typically assigned a reference to problem input or output data.

If either object or data fields are set and the log level is a member of the @DumplLevels list
then they will be logged using Data::Dumper.

See also the convenience methods eval_warn and eval_error at the end of this module.
These make code a littrle easier to read when you have a lot of successive calls which may throw
exceptions.
eval { somecode(); };
Exception->eval_error($@,'An extra error message');

Data serializing makes it trivial to pass complex objects from child to parent process or from remote commands (eg. run over SSH) back to a controller. Exception makes it trivial to pass serialized error information using these channels. 

=head1 SUBROUTINES/METHODS

=head2 new()

Construct but do not log or throw an exception.

=head2 throw()

Throw an existing exception at its own level.

=head2 warn()

Cause an exception to be thrown using the in built in warn($exception) function.

= head error()

Cause an exception to be thrown using the in built in die($exception) function.

= head fatal(),critical() alert() or emergency()

Cause an exception to be thrown using the in built in exit($exception) function.
The difference between these methods is in the logging of the messages.


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Exception


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

1;    # End of Exception
