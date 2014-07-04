package Daemonize;

use strict;
use warnings FATAL => 'all';
use Exception;
use POSIX qw(SIGINT SIG_BLOCK SIG_UNBLOCK);
use File::Pid;
use FindBin qw();

use vars qw($PID_FILE $DAEMON_ROOT);

sub safefork {
    ### block signal for fork
    my $sigset = POSIX::SigSet->new(SIGINT);
    POSIX::sigprocmask( SIG_BLOCK, $sigset )
      or Exception->error( 'SYSTEM', 'Unable to block SIGINT before fork.' );
    my $sigint = $SIG{INT};

    ### fork off a child
    my $pid = fork;
    unless ( defined $pid ) {
        Exception->error( 'SYSTEM', 'Unable to fork.' );
    }

    ### reenable SIGINT
    $SIG{INT} = $sigint || 'DEFAULT';

    ### put back to normal
    POSIX::sigprocmask( SIG_UNBLOCK, $sigset )
      or Exception->error( 'SYSTEM', 'Unable to unblock SIGINT after fork.' );

    return $pid;
}

sub isroot {
    my $c    = shift;
    my $user = shift || 'root';
    my $id   = $c->getuid($user);
    return ( !defined($id) || $< == $id || $> == $id );
}

sub getuid {
    my $c    = shift;
    my $user = shift;
    my $uid  = undef;

    if ( $user =~ /^\d+$/ ) {
        $uid = $user;
    }
    else {
        $uid = POSIX::getpwnam($user);
    }

    Exception->error( 'SYSTEM', 'Unable to find requested user.' )
      unless defined $uid;

    return $uid;
}

sub getgid {
    my $c = shift;

    my @gid = ();

    foreach my $group ( split( /[, ]+/, join( " ", @_ ) ) ) {
        if ( $group =~ /^\d+$/ ) {
            push @gid, $group;
        }
        else {
            my $id = POSIX::getgrnam($group);
            Exception->error( 'SYSTEM',
                'Attempted to resolve non-existant group.' )
              unless defined $id;
            push @gid, $id;
        }
    }

    return @gid;
}

sub setuid {
    my $c   = shift;
    my $uid = $c->getuid( shift() );
    $< = $> = $uid;

    Exception->error( 'SYSTEM', 'Unable to change (perl) uid.' )
      if ( $< != $uid );

    my $result = POSIX::setuid($uid);
    Exception->error( 'SYSTEM', 'Unable to change (POSIX) uid.' )
      unless ( defined($result) );

    return $uid;
}

sub setgid {
    my $c = shift;
    Exception->error( 'SYSTEM', 'Call to setgid without any groups.' )
      unless (@_);
    my @gids = $c->getgid(@_);
    my $gids = join( ' ', $c->getgid(@_) );

    $) = join( ' ', @gids );
    $( = $gids[0];

    my $gid0 = ( split( /\s+/, $( ) )[0];
    Exception->error( 'SYSTEM', 'Unable to change (perl) gid.' )
      unless ( $gid0 == $gids[0] );

    POSIX::setgid( $gids[0] )
      or Exception->error( 'SYSTEM', 'Unable to change (POSIX) gid.' );
    return $gids[0];

}

sub redirecthandles {
    my ( $c, $loghandle ) = (@_);

    # Redirect STDOUT/IN to/from /dev/null|$loghandle
    $loghandle ||= '/dev/null';
    open( STDIN, '<', '/dev/null' )
      or Exception->error( 'STDIN', 'Unable to redirect STDIN to /dev/null.' );
    open( STDOUT, '>>', $loghandle )
      or Exception->error( 'STDOUT',
        'Unable to redirect STDOUT to ' . $loghandle );
    open( STDERR, '>', '&STDOUT' )
      or Exception->error( 'STDERR', 'Unable to redirect STDERR to STDOUT.' );
    select STDOUT;

    return 1;
}

sub daemonize {
    my $c            = shift;
    my %h            = (@_);
    my $pid_filename = delete $h{pid_file} || $ENV{PID_FILE};
    $PID_FILE = File::Pid->new( pidfilename => $pid_filename );
    $DAEMON_ROOT = delete $h{daemon_root} || $ENV{DAEMON_ROOT} || '/';
    my $user  = delete $h{user};
    my $group = delete $h{group};

    # Take PID file fpr parent.
    my $locked = $PID_FILE->take_pidfile();
    if ($locked) {

        $c->redirecthandles();
        my ( $uid, $gid ) = ( $c->getuid($user), ( $c->getgid($group) )[0] );

        # Fork ourselves.
        my $pid = $c->safefork();
        if ($pid) {

            # Let the child juggling the PID files.
            $PID_FILE->set_autoremove(0);
            $pid && exit(0);
        }

        #
        # At this point the child does not know if the parent has exited or not.
        # The parent has been told to leave the PID file and the child can
        # use the PID_FILE object inherited from the parent to remove it and
        # reassert it for the child.
        my $chld_pid_file = File::Pid->new( pidfilename => $pid_filename );
        $PID_FILE->release_pidfile();
        $PID_FILE = $chld_pid_file;
        $locked   = $PID_FILE->take_pidfile();
        if ($locked) {
            chown( $uid, $gid, $PID_FILE );
            $c->setgid($gid)
              or Exception->error( 'SYSTEM', 'Unable to change group' );
            $c->setuid($uid)
              or Exception->error( 'SYSTEM', 'Unable to change user id' );

            chdir $DAEMON_ROOT
              or Exception->error( 'DAEMON',
                'Unable to change to daemon root directory.' );
            POSIX::setsid();
        }
        else {
            Exception->error( 'DAEMONIZE',
                'Unable to acquire PID file for daemon.  Exiting.' );
        }
    }
    return $locked;

}

=head1 NAME

Daemonize - Methods needed by a process that wants to fork itself into a daemon.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Quick summary of what the module does.

Perhaps a little code snippet.

    use Daemonize;

    my $foo = Daemonize->new();
    ...

=head1 EXPORT

A list of functions that can be exported.  You can delete this section
if you don't export anything, such as for a purely object-oriented module.

=head1 SUBROUTINES/METHODS

=head2 function1

=cut

sub function1 {
}

=head2 function2

=cut

sub function2 {
}

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Daemonize


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

1;    # End of Daemonize
