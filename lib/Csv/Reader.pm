package Csv::Reader;

use strict;
use warnings FATAL => 'all';
use Text::CSV;
use Csv::Error;

our $VERSION = '1.0.0';

my @rchars = ( "A" .. "Z", "a" .. "z", "0" .. "9" );
my $rstringlength = 3;

sub get_rstring {

    # Construct random alpha numerical strings for use as lock file salt and
    # difficult to guess lockfile names.
    return $rchars[ rand @rchars ] for 1 .. $rstringlength;
}

sub readrecord
{
    my ($c,$csv,$line) = @_;
    my $status = $csv->parse($line);
    my @fields;
    my $error;
    if ($status) {
        @fields = $csv->fields();
    } else {
        $error = Csv::Error->new($csv);
    }
    return ($status , \@fields , $error);
}



sub EIQreadrecord {
    # Try to read a line which has given an 'EIQ - QUO character not allowed'
    # Error.  The Mantis CSV contains lines with bad quotes for a CSV file eg:
    # ...,Request,10-06-24,none,,,,public,10-06-25,"lib" directory under SVN,resolved,won\'t fix,,0000000,...
        #                                                  ^ This is the problem
    my ($c , $csv , $line , $pos)  = @_;
    if (UNIVERSAL::isa($line,'Csv::Error')) {
        my $obj = $line;
        $line = $obj->get_input(); 
        $pos ||= $obj->get_position();
    }
    my $origline = $line;
    my $nfound;
    my $esc = $csv->escape_char();
    my $qt = $csv->quote_char();
    my $sep = $csv->sep_char();
    
    my $count=99;
    # Generate a randon string that does not exist in the input line.
    # Misplaced quotes will be replaced with this then back again after reparsing.
    my $rep= '::'.&get_rstring().'::';
    while( ($line =~ /$rep/  || $line=~/$qt/ || $line=~ /$sep/ || $line=~/$esc/) && $count) {
        --$count;
        $rep= '::'.&get_rstring().'::';
    }

    # Get the character before the failure position. 
    # We expect the problem to be a quote character in a field.  
    my $char = substr($line,$pos--,1);
    while($pos > -1 &&  $char ne $sep )
    {
        # Get a character.
        $char = substr($line,$pos,1);
        # Is it a quote ?
        if ($char eq $qt) {
            # Replace the quote with $rep 
            $char = substr($line,$pos,1,$rep);
        }
        --$pos;
    }
    # Try reparsing the 
    my ($status,$fields,$error) = $c->readrecord($csv,$line);
    if ($fields) {
        for(my $i=0; $i < @$fields; ++$i ) 
        {
            $fields->[$i] =~ s/$rep/$qt/g;
        }
    }
    return ($status,$fields,$error);
}
1;


=head1 NAME

Csv::Reader - Some utility methods when reading Text::CSV files.

=head1 VERSION

Version 1.0.0


=head1 SYNOPSIS

Some utility meathods to make life with Text::CSV easier.

    my $csvobj = Text::CSV->new();
    
    my Csv::Reader->readrecord($csvobj,$csvline);
    # Parse the given $csvline parse with the given $csvobject.

    my Csv::Reader->EIQreadrecord($csvobj,$csvline,$pos);
    # Try to fix and reparse a line which fails to parse with an 'EIQ - QUO character not allowed' error.

=head1 SUBROUTINES/METHODS

=head2 Csv::Reader->readrecord($csvobj,$csvline)

    Parse the given $csvline with the given $csvobject. That means the headers
    from the $csvobject are assumed.     Return a Csv::Error object if parsing fails.

=head2 Csv::Reader->EIQreadrecord($csvobj,$csvline,$pos)

=head2 Csv::Reader->EIQreadrecord($csvobj,$csverr)

    If a previous CSV parsing fails with an 'EIQ - QUO character not allowed' error then
    this method can be used to try and fix the parsing.  $csvobj must be the parser that failed,
    $csvline the line the parsing failed on or the returned Csv::Error object.
    If a line is given the a position for the failure must also be given. 
    

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Csv::Reader


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

1; # End of Csv::Reader
