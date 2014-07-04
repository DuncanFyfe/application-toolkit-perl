package Csv::Error;

use strict;
use warnings FATAL => 'all';
use vars qw($Context);

our $VERSION = '1.0.0'; 

$Context = 3;
sub new {
    my $c = shift;
    $c = ref($c) || $c || __PACKAGE__;
    my $s = bless {}, $c;
    $s->init(@_) if @_;
    return $s;
}


sub init
{
        # Generate a nice error to help work out why CSV parsing has failed.
        my ($s,$csv) = (shift,shift);
        my @dia = $csv->error_diag();
        $s->{code} = $dia[0];
        $s->{msg} = $dia[1];
        $s->{position} = $dia[2];
        $s->{input} = $csv->error_input();
        $s->{status} = $csv->status();
        
    my $txt = $s->{error_input};
        # Generate a highlight of the problem area 
        my $hlow = $dia[2] - $Context;
        $hlow = 0 if ($hlow < 0);
        my $hhigh = $dia[2] + $Context;
        $hhigh = length($txt -1) if ( $hhigh >= length($txt) );
        my $diff = $hhigh - $hlow;
        $s->{highlight} = substr($txt, $hlow , $diff);
    return $s;
}

sub get_highlight {
    return $_[0]->{highlight};
}

sub get_code() {
    return $_[0]->{code};
}
sub get_msg() {
    return $_[0]->{msg};
}
sub get_position() {
    return $_[0]->{position};
}
sub get_input() {
    return $_[0]->{input};
}
sub get_status() {
    return $_[0]->{status};
}
1;

=head1 NAME

Csv::Error - Create a useful error object from a Text::CSV parsing failure.

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Wrap a Text::CSV error into an error object for use elsewhere. 

Perhaps a little code snippet.

    use Csv::Error;
    
    my $txtcsv = Text::CSV->new(...);
    my $altrecord = '...';
    my $csverr;
    my ($status,$fields,$error) = Csv::Reader->readrecord($altrecord);
    if ($error && $error->get_msg() =~ /EIQ - QUO character not allowed/) {
        my $quoerr;
        ($status,$fields,$quoerr) = Csv::Reader->EIQreadrecord($txtcsv, $error);
    }
    ...

=head1 SUBROUTINES/METHODS

=head2 new($txtcsv)

Construct an error object from a Text::CSV object.

=head2 get_highlight() 

Csv::Error tries to construct a helpful error string for logging with the problem position highlighted.
This returns that string.

=head2 get_code()

Get the Text::CSV error code.

#head2 get_msg()

Get the Text::CSV error message.

=head2 get_position()

Get the Text::CSV error position.

=head2 get_input()

Get the input line that caused the Text::CSV error.

=head2 get_status()

Get the Text::CSV status.

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Csv::Error


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

1; # End of Csv::Error
