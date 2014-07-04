package File::Pid;

use strict;
use warnings FATAL => 'all';
use File::Basename;
use base qw(File::Lock);

our $VERSION = '0.01';

sub take_pidfile() {
    return $_[0]->lock();
}

sub try_pidfile() {
    return $_[0]->trylock();
}

sub release_pidfile() {
    return $_[0]->unlock();
}
sub _parseargs {
    my ( $s, $h ) = (@_);
    my $rtn = {};
    if ($h) {
        if ( !ref($h) ) {
            $rtn->{lockfilename} = $h;
        }
        else {
            foreach my $k (qw(resource lockfilename name pidfilename hostname)) {
                $rtn->{$k} = $h->{$k};
            }
            $rtn->{resource} ||= $rtn->{name};
            $rtn->{lockfilename} ||= $rtn->{pidfilename};
        }
    }
    $rtn->{lockfilename} ||= File::Basename::basename($0).'.pid';
    return $rtn;
}

sub new {
    my $c = shift;
    $c = ref($c) || $c || __PACKAGE__;
    my $args = $c->_parseargs(@_);
    my $s = bless $c->SUPER::new($args), $c;

    unless ( $s->{hostname} ) {
        my $hostname;
        eval { $hostname = Sys::Hostname::hostname(); };
        my $exc =
          Exeception->eval_warn( $@, 'Sys::Hostname::hostname() croaked.' );
        $hostname ||= 'localhost';
        $s->{hostname} = $hostname;
    }
    $s->{filename} ||= File::Basename::basename($0);
    $s->{lockfilename} ||= $s->make_lockfilename( $s->{filename} );
    return $s;
}


=head1 NAME

File::Pid - Specialise File::Lock to provide PID files for running processes.  
=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Specialise File::Lock module to provide PID files for running processes. These can be used to 
ensure only one instance of a process (eg. a daemon) is runningat any time.

    use File::Pid;

    my $pidfile = File::Pid->new();
    # Create a default pidfile object.
    
    my $pidfile = File::Lock->new({ name => $name, pidfilename => $pidfilename , hostname => $hostname });
    # Specify all parameters leaving nothing to default.
    
    $pidfile->take_pidfile();
    # Try to get the pid file (uses File::Lock->lock())
 
    $pidfile->try_pidfile();
    # Try to get the pid file (uses File::Lock->trylock())
       
    $pidfile->release_pidfile();
    # Release the pid file if it is ours (uses File::Lock->unlock())


=head1 SUBROUTINES/METHODS

=head2 new($pidfilename) or new({ name => $name, pidfilename => $pidfilename , hostname => $hostname })

The convenience and full object constructors.  When not specified name defaults to File::Basename::basename($0), lockfilename depends on resource and hostname to the system hostname or localhost. 

=head2 take_pidfile()

An object method which tries to take the pidfile with retries.  See File::Lock::lock
for more details.

=head2 try_pidfile()

An object method which tries to take the pidfile with retries.  See File::Lock::lock
for more details.

=head2 take_pidfile()

An object method which tries to take the pidfile with retries.  See File::Lock::lock
for more details.


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Pid


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

1; # End of File::Pid
