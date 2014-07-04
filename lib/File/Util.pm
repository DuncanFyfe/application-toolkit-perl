package File::Util;

use strict;
use warnings FATAL => 'all';
our $VERSION = '1.0.0';
use Exec;
use vars qw($MAX_COMMAND_LENGTH);
$MAX_COMMAND_LENGTH=32768;

# Some commands like cp and mv can bomb out if the command length is too long. 
# In cases where the command may be too long here are some 'big' alternatives.
# Here the command is borken down into command lines of at most $MAX_COMMAND_LENGTH
# characters.
# eg. moving large product sub-sets from an intermediate to the final directory.

sub big_action
{
    my ($c,$act,@p) = @_;

    my $to = pop @p;
    my $cmdln = 0;
    # max length adjusted for the command and the destination.
    my $max = $MAX_COMMAND_LENGTH - length($act) - length($to) -1;
    my $num=0;
    while (@p)
    {
        my $cmdln = 0;
        my @cmd  = ($act);
        while (@p && $cmdln < $max)
        {
            my $src = shift(@p);
                        # Test for empty and undefined entries
            if ($src) {
                push @cmd, shift(@p);
                $cmdln += length($src);
                ++$cmdln; # add space length
            }            
        }
        # We may have had a list of undefineds
        if ($cmdln > 0) {
            push @cmd, $to;
            Exec->system(@cmd);
            ++$num;
        }
    }

    # Return the number of commands actually executed.
    return $num;
}

sub bigmv
{
    my $c = shift;
    return $c->big_action('mv', '-f',@_);
}

sub bigcp
{
    my $c = shift;
    return $c->big_action('cp' , '-f',@_);
}

=head1 NAME

File::Util - Utility methods for handling files.

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

File::Util provides common class utility methods I have used when handling files.

    use File::Util;

    #Principal methods:
    File::Util->bigmv(@filelist,$destination);
    # Move the given files and directories to the destination.
    
    File::Util->bigcp(@filelist,$destination);
    # Copy a large number of files to the destination.


=head1 SUBROUTINES/METHODS

=head2 bigmv(@filelist,$destination), bigcp(@filelist,$destination)

Some commands like cp and mv can bomb out if the command length is too long eg.
eg. moving large product sub-sets from an intermediate to the final directory. 
In cases where the command may be too long, bigmv and bigcp provide 'big' alternatives.
The copy or move is borken down into commands of at most $File::UtilMAX_COMMAND_LENGTH
characters.

The system command is used to execute the individual copy and move commands 
An exception is raised if any of the individual commands fails.

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Util


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

1;    # End of Util

