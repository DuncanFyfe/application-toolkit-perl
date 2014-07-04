package Exec;

use strict;
use warnings FATAL => 'all';
use strict;
use Msg;
use Exception;
our $VERSION = '1.00';

use vars qw($LogLevel);
$LogLevel = 'INFO';

sub rvtoexception {
    my ( $c, $rv ) = ( shift, shift );
    my $rtn;
    if ( $rv == -1 ) {
        $rtn = Exception->new(
            {
                id   => 'ExecSysFail',
                text => ['Opening external command failed.']
            }
        );
    }
    elsif ( $rv & 127 ) {
        $rtn = Exception->new(
            {
                id   => 'DeathbySignal',
                text => [
                    sprintf(
                        "Received signal signal %d, %s coredump",
                        ( $rv & 127 ),
                        ( $rv & 128 )
                        ? 'with'
                        : 'without'
                    )
                ],
                signal      => ( $rv & 127 ),
                coredump    => ( $rv & 128 ),
                returnvalue => $rv
            }
        );
    }
    elsif ( $rv >> 8 ) {
        $rtn = Exception->error(
            {
                id          => 'ExecAbend',
                text        => [ sprintf( "Exited with value %d", $rv >> 8 ) ],
                returnvalue => $rv >> 8
            }
        );
    }
    return $rtn;
}

sub system {

    # Wrapper for system commands with added Exception throwing
    # system( @_ )
    my $c = shift;
    Msg->command(@_);
    my $rv = system(@_);
    Msg->info( 'System RV : ', $rv ) if ($rv);
    if ($rv) {
        my $ex = $c->rvtoexception($rv);
        if ($ex) {
            $ex->error();
        }
    }
    return $rv;
}

sub run {

    # Wrapper for using open to run commands with added Exception throwing.
    # If @_ contains something then this is passed to the command on STDIN.
    # Otherwise the output from the command is retrieved from STDOUT.

    my ( $c, $cmd, @in ) = @_;
    my @out;
    my $pipe;
    my $mode;
    my $rv;
    Msg->command($cmd);
    if (@in) {
        $mode = '|-';

        open( $pipe, $mode, $cmd )
          or
          Exception->error( 'RUNWITHSTDIN', 'Error opening external command : ',
            $cmd );
        print $pipe @_;
        close $pipe;
        $rv = $?;
    }
    else {
        $mode = '-|';

        open( $pipe, $mode, $cmd .' 2>&1')
          or Exception->error( 'RUNWITHSTDOUT',
            'Error opening external command : ', $cmd );
        @out = <$pipe>;
        close $pipe;
        $rv = $?;
        Msg->output(@out);
    }

    if ($rv) {
        my $ex = $c->rvtoexception($rv);
        if ($ex) {
            if (@in) {
                $ex->set_data( [ 'STDIN', \@in ] );
            }
            elsif (@out) {
                $ex->set_data( [ 'STDOUT', \@out ] );
            }
            $ex->error();
        }
    }

    return \@out;
}

sub forksub {

# forksub( sub reference , sub parameters)
# forksub runs the function in a forked copy of ourselves and passes any output to STDOUT
# back to us.
# This was originally implemented to wrap an external function (Data::Serializer) which had a memory leak.
# You can also do fun things by returning perl data structures using Storable::freeze.
    my $c = shift;
    my $cpid = open my $pipe, '-|';
    if ($cpid) {
        local $/ unless wantarray;
        my @out = (<$pipe>);
        close $pipe;
        return @out;
    }
    elsif ( defined $cpid ) {
        my $fnref = shift;
        $fnref->(@_);
        exit;
    }
    else {
        Exception->error( 'BENTFORK', 'Unable to fork new process.' );
    }
}

sub eval {

    # eval some perl and transform an error into an exception.
    # This one does not throw exceptions because it must be able to
    # catch and hand back exceptions caused by other Exec methods
    # eg. Exec->eval( sub { $out = Exec->run('acommand'); } );
    my $c = shift;
    my $rtn;
    my $subref = shift;
    if ( $subref && UNIVERSAL::isa( $subref, 'CODE' ) ) {
        local $@;
        eval { $subref->(@_) };
        $rtn = $@;
    }
    return $rtn;
}

#
# Useful utility functions for cleaning up, sanitizing and quoting parameters
# before passing to the shell.
#

sub quoteval {
    my ( $c, $val ) = (@_);

# Make sure a value is properly quoted and escaped if it has any jfunky characters.

    $val =~ s/^\s+|\s+$//g;

    # If already quoted assume escaping is correct.

    unless ( $val =~ /^"/ && $val =~ /"$/
        || $val =~ /^'/ && $val =~ /'$/ )
    {
        $val =~ s/(["\$\\`])/\\$1/g;    # Escape shell specials
        $val = '"' . $val . '"';        # Wrap in quotes
    }
    return $val;
}

sub sanitizesingle {

   # Sanitize a single parameter value for passing onto the shell for execution.
    my ( $c, $val ) = (@_);
    $val = &quoteval($val) if ( $val =~ /[\s!'"@;><\(\)\[\]\$]/ );
    return $val;
}

sub sanitizelist {

    #Given a separator and a list of values make sure they are individually
    # sanitized and sanitized as a group.
    # return a string of joined characters for passing to the shell.
    my ( $c, $sep, @val ) = @_;

    my $rtn;
    if ( @val == 1 ) {
        $rtn = &sanitizesingle(@val);
    }
    else {
        my $ctrl = grep { $_ =~ /[\s!'"@;><\(\)\[\]\$]/ } @val;

        if ($ctrl) {
            foreach my $v (@val) {
                $v = &quoteval($v);    # Sanitize individual values.
                $v =~ s/^"|"$/\\"/g
                  ; # Now add an extra escape to the quotes so we can safely quote the whole group below.
            }

        }

        # Quote the group as a string.
        $rtn = '"' . join( $sep, @val ) . '"';
    }
    return $rtn;
}

=head1 NAME

Exec - Wrap various ways of executing other code and turn errors into Exception
objects.

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Exec provides class methods which wrap various methods of executing code.

    use Exec;

    #Principal methods:
    Exec-E<gt>system(external command);
        Wraps perl system command. 
    Exec->run(external command , list to be piped to STDIN , ...);
        Uses open to run an external command and pipe to STDIN I<OR> collect from STDOUT.
    Exec->forksub($subref , sub parameters...);
        Fork the process, run a subroutine in the child and pipe the return value(s) back to the parent.
    Exec->eval(list to be passed to eval, ...);  
        Wrap the perl eval command.
    
    #Bonus methods:
    Exec->rvtoexception( $returnvalue )
    Exec->quoteval( $value )
    Exec->sanitizesingle( $value )
    Exec->sanitizelist( @list )
    ...


=head1 SUBROUTINES/METHODS

=head2 system(I<command>)

The given scalar is executed using the perl C<system(command)>.  The system return value
is checked and any error is thrown as an Exception object.  

=head2 run(I<command> , I<anything to be passed to STDIN> , ...)

Without I<passed to STDIN> the external command is executed with C<open>, STDOUT from the command is collected and returned as an anonymous list reference.

With I<passed to STDIN> the external command is executed with C<open> and the list is piped to it via STDIN. In this case no output is recorded.

In either case, problems opening the command are thrown as an Exception object.

=head2 forksub($subref , sub parameters...)

Use open to fork this process and execute the given subref in the child.  Output from the
child is piped back to the parent and returned as an anonymous list reference.

This sub was originally written to get round a (hundreds of MB) memory leak in an external module.
Lots of fun can be had if the subref returns a Storable::freeze() scalar.  The
parent can then Storable::thaw() this back to whatever complex perl data structure
you need.

=head2 eval(I<stuff passed to eval>, ...)

The input list is passed straight to eval { @_ }.  The result is checked and converted
to an Exception if the eval failed.

=head2 rvtoexception( $returnvalue )

Test the given return value and if it is off convert it into an Exception object.

=head2 quoteval( $value )

=head2 sanitizesingle( $value )

=head2 sanitizelist( @list )

Some external commands (see HEASOFT and the XMM-Newton SAS in particular) have I<interesting> 
command line argument conventions.  These three bonus methods can be used to build the command
line arguments for such I<interesting> commands so they can passed to Exec->run().
  
=head3 quoteval( $returnvalue )

If the input scalar is quoted ('foo' or "foo") then it just returns it.  If it is unquoted
then it prefixes shell-special characters with a backslash and returns a double-quotes quoted string.

For example
    my $arg = "quirky`$";
    Exec->quoteval($arg);
    returns I<"quirky\`\$"> (including the ")

=head3 sanitizesingle( $value )

Calls quoteval($value) on the input if it contains any special characters.  Returns it
as is if not.

=head3 sanitizelist( $separator @values )

Construct a single command line argument from a list of input values.  Each individual item
is sanitized then joined together (with $separator) before the combined string is sanetized
and returned quoted.

For example
    my @list = qw(1 2 3 -q `$ -v );
    Exec->sanitizelist(@list);
    returns I<"\"1\" \"3\" \"3\" \"-q\" \"\`\$\" \"-v\""> (including the ")

If you don't understand why this is necessary, then it probably isn't.


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Exec


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

1;    # End of Exec
