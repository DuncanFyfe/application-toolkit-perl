package File::Serial;

# Package implements class for persistent (file backed) serial integers
# I use this for sequence ids, error ids etc
# Locking is used to access the persistent storage so it will work over NFS.
use strict;
use warnings FATAL => 'all';

use Msg;
use Exception;
use File::Lock;
use Fcntl qw(:DEFAULT :flock);
our $VERSION = '1.0.0';

sub _read {
    my $s        = shift;
    my $filename = $s->{filename};
    my $rtn;

    my $fh;
    if ( sysopen( $fh, $filename, O_RDONLY )
        && flock( $fh, LOCK_EX ) )
    {
        my $rtn = <$fh>;
        close($fh);
        chomp($rtn);
    }
    return $rtn;
}

sub _write {
    my ( $s, $v ) = ( shift, shift );
    my $filename = $s->{filename};
    my $rtn;

    my $fh;
    if ( sysopen( $fh, $filename, O_WRONLY | O_TRUNC | O_CREAT )
        && flock( $fh, LOCK_EX ) )
    {

        printf $fh ( "%d\n", $v );
        close $fh;
        $rtn = $s->_read();
    }
    else {
        Exception->error(
            {
                id   => 'FILEHANDLE',
                text => [ 'Can\'t access persistent storage : ', $filename, $! ]
            }
        );
    }

    return $rtn;
}

sub _next {
    my ( $s, $incr ) = ( shift, shift );
    my $filename = $s->{filename};
    my $rtn;

    my $fh;
    if ( sysopen( $fh, $filename, O_RDWR | O_CREAT )
        && flock( $fh, LOCK_EX ) )
    {
        $rtn = <$fh>;
        $rtn ||= 0;
        chomp $rtn;
        $rtn += $incr;

        if ( seek( $fh, 0, 0 ) && truncate( $fh, 0 ) ) {
            printf $fh ( "%d\n", $rtn );
        }
        close $fh;
        $rtn = $s->_read();
    }
    else {
        Exception->error(
            {
                id   => 'FILEHANDLE',
                text => [ 'Can\'t access persistent storage : ', $filename, $! ]
            }
        );
    }
    return $rtn;
}

sub read {
    my $s        = shift;
    my $lockfile = $s->{lockfile};
    my $rtn;
    if ( $lockfile->lock() ) {
        my $rtn = $s->_read();
        $lockfile->unlock();
    }
    else {
        Exception->error(
            'File::Serial',
            'Unable to lock persistent storage before serial file read.',
            $lockfile->get_lockerror()
        );
    }
    return $rtn;
}

sub write {
    my ( $s, $v ) = ( shift, shift );
    $v ||= $s->{init} || 0;
    my $rtn;
    my $lockfile = $s->{lockfile};
    if ( $lockfile->lock() ) {
        $rtn = $s->_write($v);
        $lockfile->unlock();
    }
    else {
        Exception->error(
            'File::Serial',
            'Unable to lock persistent storage before serial file write.',
            $lockfile->get_lockerror()
        );
    }
    return $rtn;
}

sub current {
    return $_[0]->read();
}

sub last {
    return $_[0]->{init};
}

sub reset {
    my ( $s, $v ) = (@_);
    my $cur = $s->current();
    return $v if ( $v == $cur );

    # Only reset if we were the last one to update the value.
    my $lockfile = $s->{lockfile};
    if ( $lockfile->lock() ) {
        my $act = $s->_read();
        my $exp = $s->{init};
        if ( $act == $exp ) {
            $s->{init} = $s->_write($v);
        }
        $lockfile->unlock();
    }
    else {
        Exception->error(
            'File::Serial',
            'Unable to lock persistent storage before next value taken.',
            $lockfile->get_lockerror()
        );
    }
    return $s->{init};
}

sub next {

    my $s        = shift;
    my $lockfile = $s->{lockfile};
    if ( $lockfile->lock() ) {
        $s->{init} = $s->_next($s->{incr});
        $lockfile->unlock();
    }
    else {
        Exception->error(
            'File::Serial',
            'Unable to lock persistent storage before next value taken.',
            $lockfile->get_lockerror()
        );
    }
    return $s->{init};
}

sub init {

    # Create the persistant store and write the initial value to it.
    # Do nothing if the persistent store already exists.
    my $s        = shift;
    my $v        = $s->{init} || 0;
    my $filename = $s->{filename};
    if ( !-f $filename ) {
        $s->write($v);
    }
    else {
        $s->{init} = $s->read();
    }
}

sub _parseargs {
    my ( $c, $h ) = (@_);
    my $rtn = {};
    if ($h) {
        if ( !ref($h) ) {
            $rtn->{filename} = $h;
        }
        else {
            foreach my $k (qw(filename lockfile init incr)) {
                $rtn->{$k} = $h->{$k};
            }
        }
    }
    return $rtn;
}

sub new {

# __PACKAGE__->new( { filename => filewithpath , init => initialvalue , incr => increment } );
    my ( $c, $h ) = ( shift, shift );
    $c = ref($c) || $c || __PACKAGE__;
    $h = $c->_parseargs($h);
    Exception->error( 'BADPARAMETER',
'Cannot instantiate a Serial object without a filename for persistent storage parameter'
    ) unless ( ref($h) && $h->{filename} );
    my $s = bless {
        init => $h->{init} || 0,
        incr => $h->{incr} || 1,
        filename => $h->{filename},
        lockfile => $h->{lockfile}
          || File::Lock->new( { filename => $h->{filename} } )
    }, $c;
    $s->init();
    return $s;
}

=head1 NAME

File::Serial - Serial integers backed by persistent file storage.

=head1 VERSION

Version 1.0.0

=cut

=head1 SYNOPSIS

Objects which provide a serial integer (eg. sequence numbers) which is backed by
persistent storage across multiple runs of related applications. The storage is
protected using locks (File::Lock and flock) during read and write operations.

    use File::Serial;

    my $seq = File::Serial->new({ filename => $filename , init => $initialvalue , incr => $increment , lockfile => $filelockobject} );
    # Fully parameterised instantiation of a serial object.  

    my $seq = File::Serial->new($filename);
    # Convenience instantiation of a serial object.     
    
    $seq->next();
    # Get the next value of the series.
    
    $seq->last();
    # Return the last value issued to the object $seq. 

    $seq->current();
    # Return the curret value of the series from storage.
    
    $seq->reset($value);
    # Reset the serial the given value.
    

=head1 SUBROUTINES/METHODS

=head2 new({ filename => $filename , init => $initialvalue , incr => $increment , lockfile => $filelockobject} )

=head2 new($filename)

Create a new lock object. I<filename> will be used as persistant storage and is a mandatory parameter.
I<init> the initial value if one does not exist, defaults to 0.
I<incr> the increment to be applied when next() is called, defaults to 1.
I<lockfile> a File::Lock object used to lock I<filename> during read, write and update operation.
A default  File::Lock based on I<filename> is created if one is not supplied.

=head2 next()

Generate the next number in the series, update the storage and return it.  
Since a series may be accessed from multiple processes the returned value is not necessarily the last value plus increment.

=head2 last()

Object method that returns the last value issued to this object.  

=head2 current()

Object method that returns the current value held in storage.

=head2 reset($value)

Reset the series current value.  Before a reset is performed the last and current
series object values are compared.  Only if they are the same do we assume this object
has authority to reset the value (ie. it was the last one to update it).

If the values are not the same there is another user and this object is not in sync
with the series so no update is performed.


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Serial


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

1;    # End of Serial
