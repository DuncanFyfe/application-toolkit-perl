package File::Lock;
use strict;
use warnings FATAL => 'all';
use File::Basename;
use File::Spec;
use Fcntl qw(:DEFAULT :flock);
use Sys::Hostname;
use Exception;
use Msg;
use Data::Dumper;
 
use vars qw($Sep $Maxretry $Retrysleep $Maxsleep $Sleepunits);

#Separator of lock file fields.
our $VERSION = '1.0.0';
$Sep        = ',';
$Maxretry   = 5;
$Retrysleep = 10000;
$Maxsleep   = 5000000;
$Sleepunits = 1000000;    # microseconds

my @rchars = ( "A" .. "Z", "a" .. "z", "0" .. "9" );
my $rstringlength = 8;

sub get_rstring {

    # Construct random alpha numerical strings for use as lock file salt and
    # difficult to guess lockfile names.
    my $rtn;
    $rtn .=  $rchars[ rand @rchars ] for 1 .. $rstringlength;
    return $rtn;
}

sub parse_identity {
    my ( $c, $str ) = @_;
    my %rtn;
    if ( $str && $str =~ /^\d+,/ ) {
        @rtn{qw( pid hostname salt )} = $str ? split /$Sep/, $str : ();
    }
    return \%rtn;
}

sub make_identity {

    # Create an identity string for writing to lockfiles.
    # This consists of a PID, hostname and random string
    my ( $c, $h ) = @_;
    my ($pid,$hostname,$salt);
    if ($h && ref($h)) {
        $pid ||= $h->{pid};
        $hostname ||= $h->{hostname};
        $salt ||= $h->{salt};
    }
    if (ref($c)) {
        $pid ||= $c->{pid};
        $hostname ||= $c->{hostname};
        $salt ||= $c->{salt};
    }
    return join($Sep,$pid,$hostname,$salt);
}

sub make_lockfilename {

    # Turn a file or directory name into a lock name.
    my ( $c, $f ) = (@_);
    my ( $basename, $dirname, $suffix ) = File::Basename::fileparse($f);
    if ( !substr( $basename, 0, 1 ) eq '.' ) {
        $basename = ".$basename";
    }
    $basename .= '.lock';

    if ( -d $f ) {
        $dirname = $f;
    }

    return File::Spec->catfile( $dirname, $basename );
}

sub _read_lockfile {
    my $s = shift;
    my $rtn;
        my $z = defined($rtn) ? 'YES':'NO';

    my $lockfilename = $s->{lockfilename};

    if ( -f $lockfilename ) {
        my $pid;
        if ( sysopen( $pid, $lockfilename, O_RDONLY )
            && flock( $pid, LOCK_EX ) )
        {
            $rtn = <$pid>;
            close($pid);
            chomp($rtn);
        }
        else {
            $s->{lockerror} = $!;
        }
    }
    $z = defined($rtn) ? 'YES':'NO';
    
    Msg->debug('_read_lockfile identity=' => $rtn);
    my $x = defined($rtn) ? 'YES':'NO';
    return $rtn;
}

sub _write_lockfile {
    my $s = shift;
    my $rtn;
    my $lockfilename = $s->{lockfilename};
    my $thisid       = $s->make_identity($s);

    my $pid;

    if ( sysopen( $pid, $lockfilename, O_WRONLY | O_CREAT | O_TRUNC )
        && flock( $pid, LOCK_EX ) )
    {
        Msg->debug('_write_lockfile identity=' => $thisid);

        print $pid $thisid,"\n";
        close $pid;

        # Now reread.
        my $newid = $s->_read_lockfile();

        unless ( $s->{lockerror} ) {
            Msg->debug('newid=' , $newid);
            if ( $thisid ne $newid ) {
                $s->{lockerror} =
'Problem writing lock identity to lock file.  Just written does not equal reread.';
            }
            else {
                $rtn = 1;
            }
        }
    }
    else {
        $s->{lockerror} = $!;
    }
    return $rtn;
}

sub _islockstale {

# Return 0 if it is our PID, 1 if the local PID does not respond to a signal and -1 if
# the PID is not local and cannot be tested.
    my ( $s, $pid, $hostname ) = (@_);
    my $rtn     = 0;
    my $ismypid = $$ != $pid;
    my $ismyhost =
        !$hostname
      || $hostname =~ /^localhost/
      || '127.0.0.1' eq $hostname
      || $s->{hostname} eq $hostname;
    if ($ismyhost) {
        if ($ismypid) {

            # My pid on my host so it is my lock.
            $rtn = 0;
        }
        else {

            # Not my pid on my host test if process is active
            $rtn = 1 if ( kill 0 => $pid );
        }
    }
    else {

       # Not my host, unable to test pid assume it belongs to an active process.
        $rtn = -1;
    }
    return $rtn;
}

sub get_lockerror {
    return $_[0]->{lockerror};
}

sub clear_lockerror {
    $_[0]->{lockerror} = '';
}

sub _parseargs {
    my ( $s, $h ) = (@_);
    my $rtn = {};
    if ($h) {
        if ( !ref($h) ) {
            $rtn->{filename} = $h;
        }
        else {
            foreach my $k (qw(filename lockfilename hostname autoremove)) {
                $rtn->{$k} = $h->{$k};
            }
        }
    }
    return $rtn;
}

sub trylock {
    my $s            = shift;
    my $rtn          = 0;
    my $lockfilename = $s->{lockfilename};
    my $thisid       = $s->make_identity($s);
    my $lockid       = $s->_read_lockfile();
    unless ( $s->{lockerror} ) {
        if ( $lockid &&  $thisid eq $lockid ) {

            # Our lock, this is ok.
            $rtn = 1;
        }
        elsif ($lockid) {

            # Not our lock, test if it is stale.
            my $h = $s->parse_identity($lockid);
            my $islockstale = $s->_islockstale( $h->{pid}, $h->{hostname} );
            if ( $islockstale > 0 ) {

                # Take stale lock.
                $rtn = $s->_write_lockfile();
            }
            elsif ( $islockstale == 0 ) {

                # We already hold the lock.
                $rtn = 1;
            }
        }
        else {
            $rtn = $s->_write_lockfile();
        }
    }

    # Pick up error from any of the read/write actions.
    if ( $s->{lockerror} ) {
        Exception->error( { status => 'File::Lock', text => [$s->{lockerror}] , object => $s} );
    }
    return $rtn;
}

sub lock {
    my $s        = shift;
    my $maxretry = $Maxretry;
    my $rtn      = $s->trylock();
    while ( $maxretry-- > 0 && !$rtn ) {
        my $sleep = int( abs($Retrysleep) );
        if ($sleep) {
            if ( $sleep > $Maxsleep ) {
                $sleep = $Maxsleep;
            }
            
            if ( $INC{'Time::HiRes'} ) {
                $sleep = int( rand($sleep) ) + 1;
                Time::HiRes::usleep($sleep);
            }
            else {
                $sleep = int( rand($sleep/$Sleepunits) ) + 1;
                sleep($sleep);
            }
        }
        $rtn = $s->trylock();
    }

    if ( !$rtn ) {
        $s->{lockerror} =
          'Unable to take lock after ' . $Maxretry . 'attempts.';
    }
    return $rtn;
}

sub unlock {
    my $s            = shift;
    my $rtn          = 0;
    my $lockfilename = $s->{lockfilename};
    if ( -f $lockfilename ) {
        my $thisid = $s->make_identity($s);
        my $lockid = $s->_read_lockfile();
        if ( $s->{lockerror} ) {
            Exception->error( 'File::Lock',
                'Error checking lockfile before removal',
                $s->{lockerror} );
        }
        elsif ( $thisid eq $lockid ) {
            $rtn = unlink($lockfilename);
        }
    }
    else {
        $rtn = 1;
    }
    return $rtn;
}

sub new {
    my $c = shift;
    $c = ref($c) || $c || __PACKAGE__;

    my $args = $c->_parseargs(@_);

    my $s    = bless {
        hostname     => $args->{hostname},
        pid          => $$,
        salt         => $c->get_rstring(),
        resource     => $args->{resource} || $c->get_rstring(),
        lockfilename => $args->{lockfilename},
        autoremove   => $args->{autoremove} || 1,
        lockerror    => ''
    }, $c;


    unless ( $s->{hostname} ) {

        my $hostname;
        eval { $hostname = Sys::Hostname::hostname(); };
        my $exc =
          Exception->eval_warn( $@, 'Sys::Hostname::hostname() croaked.' );
        $hostname ||= 'localhost';
        $s->{hostname} = $hostname;

    }
    $s->{lockfilename} ||= $s->make_lockfilename( $s->{resource} );
    Msg->debug('lockfilename=',$s->{lockfilename});
    return $s;
}

sub get_autoremove {
    return $_[0]->{autoremove};
}

sub set_autoremove {
    my $s = shift;
    $s->{autoremove} = shift;
    return $s;
}

sub DESTROY {
    my $s = shift;
    if ( $s && $s->{autoremove} ) {
        $s->unlock();
    }
}

1;

=head1 NAME

File::Lock - Lockfiles to protect resources.

=head1 VERSION

Version 1.0.0

=head1 SYNOPSIS

Object based lock files to protect shared resources (files and directories) in paralell execution
environments.  The process ID (PID), hostname and a random salt are written to the lockfile on 
creation and tested on conflict.  The PID helps separate processes on the same host.
The hostname helps when resources are shared between hosts and the salt helps when locks might
conflict within the same process (eg. multi-threaded).  By default locks are removed by a DESTROY
block when the object is destroyed.

To override default values alternatives must be provided to the constructor.  There are no getters and setters for these values because changing them after a lock has been taken would be silly.  

    use File::Lock;
    
    $File::Lock::Maxretry = 5;    # Number of times lock will retry before giving up.
    $File::Lock::Retrysleep = 10000;  # Maximum random number of microseconds to sleep between retries.
    # NOTE: Miscrosecond resolution sleeps are only available if Time::HiRes has been loaded.
    # If Time::HiRes has not then sleeps are rounded up to the nearest second and the _minimum_ sleep is 1s.

    File::Lock->make_identity({ pid => $pid , hostname => $hostname , salt => $salt} );
    # Make an identity string to be written to the lock file.

    my $hash = File::Lock->parse_identity( $idstring );
    # Parse an identity string into { pid => $pid , hostname => $hostname , salt => $salt}
    
    my $lockfilename = File::Lock->make_lockfilename( $resource );
    # Create a default lockfile name from a given resource. 

    my $lock = File::Lock->new($resource);
    # Quick interface creates a locking object based on $resource with a default lockfile and hostname.
    my $lock = File::Lock->new({ resource => $resource, lockfilename => $lockfilename , hostname => $hostname, autoremove => $autoremove });
    # Specify all parameters leaving nothing to default.
    
    $lock->lock();
    # Try to take the lock with retries.  Retry $Maxrerty times before giving up.
    
    $lock->trylock();
    # Try to take the lock and return immediately.
    
    $lock->unlock();
    # Remove the lockfile if we own it.


=head1 SUBROUTINES/METHODS

=head2 new($resource) or ({ resource => $resource, lockfilename => $lockfilename , hostname => $hostname , autoremove => $autoremove })

The convenience and full object constructors.  When not specified resource defaults to a random string, lockfilename depends on resource and hostname to the system hostname or localhost.
If autoremove is false the lock will not be removed when the object is destroyed.  You need this in 
forking environments to stop the dying parent or child from removing the lock beneith the still 
running partner.

=head2 make_identity({ pid => $pid , hostname => $hostname , salt => $salt})

Class method which creates an identity string as written to the lockfile.
If absent pid defaults to $$, hostname to localhost and salt to a random string of letters.

=head2 parse_identity()

Class method to parse an identity string back into a hash.

=head2 make_lockfilename( $resource )

Class method which uses the value $resource to construct a default lockfilename. If resource points to a directory then the lockfilename is placed in that directory and the name is derived from the last element in the directory path prefixed with a '.' (unless the name already starts with a '.') and '.lock' appended.

Otherwise the the lockfile is placed in the same directory as the resource being locked and is named
after the resource prefixed with a '.' (unless the name already starts with a '.') and '.lock' appended.

For example:
    File::Lock->make_lockfilename( 'a/directory' ) == 'a/directory/.directory.lock'
    File::Lock->make_lockfilename( 'a/directory/file' ) == 'a/directory/.file.lock'
    File::Lock->make_lockfilename( 'a/directory/.secret' ) == 'a/directory/.secret.lock'
    File::Lock->make_lockfilename( 'a/directory/.lock' ) == 'a/directory/.lock.lock'

=head2 trylock()

An object method which tries to take the lockfile and immediately returns.

=head2 lock()

An object method which tries to take the lockfile and retries $Maxrerty times before giving up.
If $Retrysleep is true then the process will be slept for a random time between 1 and $Maxsleep microseconds
before each retry.  This can help avoid retry contention. 

=head2 unlock()

An object method which tests the lockfile and if it belongs to this object removes it.

=head2 set_autoremove( $v )

Set the autoremove value. A true value will cause the lock to be removed by the DESTROY block when the object goes out of scope.

=head2 get_autoremove()

Return the value of the autoremove state.

=head1 CAVEATS

=head2 Filename lengths

The default lockfilename is longer than the resource name. If the resource name is close to
the filesystem path length limit (often 255 characters) then this can cause an error when
the lockfilename is created. 

=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Lock


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

1;    # End of File::Lock
