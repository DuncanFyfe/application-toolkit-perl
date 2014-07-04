package Timestamp;

# NOTE: This package is used by Msg to generate timestamps.
# It cannot therefore use Msg itself
use strict;
use warnings FATAL => 'all';
our $VERSION = 1.0.0;

sub iso8601
{
    # Spit out an iso8601 formatted date.
    my $c = shift;
    my $rtn;
    my $t = $c->get_timestamp();

    #    0     1     2      3      4     5      6      7      8
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime( int($t) );
    if ( $c->is_timehires_loaded() )
    {
        my $usec = int( 1000000 * ( $t - int($t) ) );
        $rtn = sprintf(
            '%04d-%02d-%02dT%02d_%02d_%02d.%06d',
            $year + 1900,
            $mon + 1, $mday, $hour, $min, $sec, $usec
        );
    } else
    {
        $rtn = sprintf(
            '%04d-%02d-%02dT%02d_%02d_%02d',
            $year + 1900,
            $mon + 1, $mday, $hour, $min, $sec
        );
    }
    return $rtn;
}

sub is_timehires_loaded()
{
    return exists( $INC{'Time::HiRes'} );
}

sub set_timestamp
{
    # Change the timestamp
    # Either (time) (seconds,useconds) or (Timestamp_ref))
    # Parameters, if given, are assumed to be epoch time and millisecond.
    # Uses current time if no parameters are given.
    my $s = shift;
    my $t = shift;
    if (@_)
    {
        # Assume seconds + microseconds
        my $u = shift;
        $t = $s->_add_microseconds( $t, $u );
    } elsif ( ref($t) )
    {
        $t = $t->[0];
    } elsif ( !defined($t) )
    {
        $t = $s->get_timenow();
    }
    $s->[0] = $t;
    return $s;
}

sub _add_microseconds
{
    my ( $c, $sec, $usec ) = @_;
    if ( $usec > 0 ) { $usec /= 1000000; }
    return int($sec) + $usec;
}

sub get_timenow()
{
    my $c = shift;
    my $rtn;
    if ( $c->is_timehires_loaded() )
    {
        $rtn
         = $c->_add_microseconds( ( Time::HiRes::gettimeofday() ) );
    } else
    {
        $rtn = time();
    }
    return $rtn;
}

sub get_timestamp
{
    my $c = shift;
    my $rtn;
    if ( ref($c) )
    {
        $rtn = $c->[0];
    } else
    {
        $rtn = $c->get_timenow();
    }
    return $rtn;
}

sub get_date
{
    my $s = shift;

    #    0     1     2      3      4     5      6      7      8
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime( int( $s->get_timestamp() ) );
    return ( 1900 + $year, $mon, $mday );
}

sub get_time
{
    my $s = shift;
    my $t = $s->get_timestamp();

    #    0     1     2      3      4     5      6      7      8
    my ( $sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst ) =
      gmtime( int($t) );
    my $usec = int( 1000000 * ( $t - int($t) ) );
    return ( $hour, $min, $sec, $usec );
}

sub new
{
    my $c = shift;
    $c = ( ref $c ) || $c || __PACKAGE__;
    my $s = bless [], $c;
    return $s->set_timestamp(@_);
}


sub stringify { return $_[0]->iso8601(); }
#
sub numify { return $_[0]->get_timestamp(); }

=head1 NAME

Timestamp - A class for creating processing timestamp objects.

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Timestamp is focussed on processing time within an application, for example adding
timestamps to log messages.  Use classes like Date or Date::Calc for user supplied times.
Timestamp uses overload to return an iso8601 formatted timestamp in string context and
epoch time in numerical context.


    use Timestamp;

    $Timestamp::UseHiRes = 0 or 1    # Default to seconds (0) or microsecond (1) accuracy.
    my $foo = Timestamp->new();
    # Creates a timestamp object representing current time.
 
     my $foo = Timestamp->new($seconds.useconds);   
    my $foo = Timestamp->new($seconds, $useconds);
    # Create a timestamp representing the given number of seconds and microseconds 
    # and setting for use of Hi resolution or not. 

    $foo->set_timestamp($seconds, $useconds);  # Change the time of this timestamp
    $foo->set_epochtime($seconds);             # Change the epoch time of the timestamp
    $foo->set_microseconds($microseconds);     # Change the microseconds fraction of the timestamp
        
    $epochseconds.useconds = $foo->get_timestamp();       # Get the time.
    $epochseconds.useconds = Timestamp->get_timestamp();  # Get the time now.
    $epochseconds = $foo->get_epochtime($seconds);  # Return the epoch time of the timestamp
    $microseconds = $foo->get_microseconds();       # Return the microseconds time of the timestamp
    
    @date = $foo->get_date();   # Return the date portion of the timestamp as a (CCYY,MM,DD) list.
    @time = $foo->get_time();   # Return the time portion of the timestamp as a (HH,MM,SS,usecs) list.
    
    $string = $foo->iso8601();  # Return an ISO8601 formatted date string based on the timestamp.

=head SUBROUTINES / METHODS

=head2 new() or new($seconds.useconds) or new($seconds, $useconds) or new($timestamp_object)

Class constructor.  The given time is used.  Where no time is given the current epoch time is used.
If Time::HiRes has been loaded the a microseconds resolution epoch time will be used.


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Timestamp


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
1;    # End of Timestamp
