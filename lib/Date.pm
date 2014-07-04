package Date;

use strict;
use warnings FATAL => 'all';
use Date::Calc qw(Days_in_Month Day_of_Week);
our $VERSION = '1.0.0';

sub workdaysinmonth {

    # Given (year,month(1..12)) return the number of work days in the month.
    my ( $c, $year, $month ) = (@_);
    my $lastday = Days_in_Month( $year, $month );

    my $wd;
    foreach my $d ( 1 .. $lastday ) {
        $wd++ if ( Day_of_Week( $year, $month, $d ) < 6 );
    }
    return $wd;
}

sub _parseargs {
    my $c = shift;
    my @p;
    my @rtn;
    foreach my $p (@_) {
        push @p, ref($p) ? @$p : $p;
    }

    my $date;
    if (@p) {
        $date = join( '', ( split /[-:\/,_\s]+/, join( ',', @p ) ) );
    }
    my @date = $date =~ /(\d{2})+/;
    return @date;
}

sub dateDDMMCCYY {
    my $c    = shift;
    my @date = $c->_parseargs(@_);
    my @rtn;

    if (@date) {
        if ( @rtn && @rtn < 4 ) {

            # Get the current century + year
            my @d    = gmtime(time);
            my $year = 1900 + $d[5];
            my @y    = $year =~ /(\d{2})+/;
            push @rtn, @y;

        }
        @rtn = ( $rtn[2] . $rtn[3], $rtn[1], $rtn[0] );
    }

    # (CCYY , MM , DD)
    return @rtn;
}

sub dateCCYYMMDD {

    my $c    = shift;
    my @date = $c->_parseargs(@_);
    my @rtn;

    if (@date) {
        if ( @rtn && @rtn < 4 ) {

            # Get the current century + year
            my @d    = gmtime(time);
            my $year = 1900 + $d[5];
            my @y    = $year =~ /(\d{2})+/;
            @rtn = @rtn == 2 ? ( @y, @rtn ) : ( $y[0], @rtn );

        }
        @rtn = ( $rtn[0] . $rtn[1], $rtn[2], $rtn[3] );
    }

    # (CCYY , MM , DD)
    return @rtn;
}

sub getcurrentdate {
    my $c     = shift;
    my @d     = gmtime(time);
    my $year  = 1900 + $d[5];
    my $month = $d[4] + 1;
    my $day   = $d[3];
    return ( $year, $month, $day );
}

sub getlastmonth {
    my ( $c, @rtn ) = @_;
    if ( $rtn[1] == 1 ) {
        --$rtn[0];
        $rtn[1] = 12;
    }
    else {
        --$rtn[1];
    }
    my @end = $c->getendmonth(@rtn);
    if ( $end[0] < $rtn[0] )
    {
        @rtn = @end;
    }
    return @rtn;
}

sub getendmonth {
    my ( $c, @rtn ) = @_;
    $rtn[2] = Days_in_Month( $rtn[0], $rtn[1] );
    return @rtn;
}

sub getstartmonth {
    my ( $c, @rtn ) = @_;
    $rtn[2] = '01';
    return @rtn;
}

sub formatdate {
    my $c = shift;
    my $rtn;
    if ( @_ == 3 ) {
        $rtn = sprintf( "%04d-%02d-%02d", @_ );
    }
    elsif ( @_ == 5 ) {
        $rtn = sprintf( "%04d-%02d-%02dT%02d:%02d", @_ );
    }
    elsif ( @_ == 6 ) {
        $rtn = sprintf( "%04d-%02d-%02dT%02d:%02d:%02d", @_ );
    }
    elsif ( @_ >= 7 ) {

        # Assumes millisecond accuracy
        $rtn = sprintf( "%04d-%02d-%02dT%02d:%02d:%02d.%06d", @_ );
    }
    return $rtn;
}

sub compare {
    my ( $c, $d1, $d2 ) = @_;
    my $cmp = $d1->[0] <=> $d2->[0];
    if ( !$cmp ) {
        $cmp = $d1->[1] <=> $d2->[1];
        if ( !$cmp ) {
            $cmp = $d1->[2] <=> $d2->[2];
        }

    }
    return $cmp;
}

1;

=head1 NAME

Date - Class methods for standardized handling of dates and a few useful tools.

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Handling all of the possible miriad of user suppliable date formats is a nightmare.
This module expresses interfaces for the formats I'm willing to deal with.  these
translate those date formats into a standardized internal format (CC,YY,MM,DD) 
which can then be used to safely do useful things.

Perhaps a little code snippet.

    use Date;

    my @date = Date->dateDDMMCCYY($adate);  # Parse an input date in DDMMCCYY form.
    my @date = Date->dateCCYYMMDD($adate);  # Parse an input date in CCYYMMDD form.
    
    my $string = Date->formatdate(@date);   
    # Return @date as a CCYY-MM-DDTHH:MM:SS.ssssss string.  
    
    Date->compare(\@date1,\@date2);
    # Compare dates like cmp for sorting. 
    # Return 1 if @date1 comes before @date2, 0 if they are equal and -1 if \@date2 comes before \@date1 
      
    @newdate = Date->getendmonth(@date);    # Get a new date for the last day of the given month.
    @newdate = Date->getfirstmonth(@date);  # Get a new date for the first day of the given month.
    @newdate = Date->getlastmonth(@date);   # Get a new date for this day last month. No date validation is done.
    @newdate = Date->getcurrenttime();      # Get the current GMT date.
    $wd = Date->workdaysinmonth(@date);     # Return the number of working days (Mon-Fri) in the given month.

=head1 SUBROUTINES/METHODS

=head2 dateDDMMCCYY($adate)

Class method.  Assumes the supplied scalar is a date of form DDxMMxCCYY and returns a list (CCYY,MM,DD).
The x are separators which are matched are matched by regexp /[-:\/,_\s]+/.
 
=head2 dateDDMMCCYY($adate)

Class method.  Assumes the supplied scalar is a date of form CCYYxMMxDD and returns a list (CCYY,MM,DD).
The x are separators which are matched are matched by regexp /[-:\/,_\s]+/.

=head2 compare($dateref1,$dateref2)

Compare the two referenced (CCYY,MM,DD) dates for sort order.

=head2 getendmonth(@date)

Return a new date which is the last day of the month of the input date. 

=head2 getfirstmonth(@date)

Return a new date which is the first day of the month of the input date. 

=head2 getlastmonth(@date)

Return a new date which is the month before the given date.  
If going back one month would put the day number beyond then end of the month then the last
day of the new month is returned.  
For example:  getlastmonth(2010,03,31) == (2010,03,28)

=head2 getcurrenttime()

Return (CCYY,MM,DD) for the current (GMT) time.

=head2 workdaysinmonth(@date)

Return the number of working days (Mon-Fri) in the given month. Takes no account of local holidays.

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Date


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

1;    # End of Date
