package File::Compression;

use strict;
use warnings FATAL => 'all';
our $VERSION = '1.0.0';

use File::MMagic;
use Exec;

use vars qw($Magic $Compress $GzipCompress $Bzip2Compress $XzCompress @DoNotCompress);
$Magic = File::MMagic->new();
$Magic->removeFileExts();

@DoNotCompress = qw(
  zip image/bmp image/gif image/jpeg image/png image/x-xbm audio/mpeg
);

$GzipCompress   = 'gzip';
$Bzip2Compress   = 'bzip2';
$XzCompress   = "xz";
$Compress   = $GzipCompress;

sub gzip_compress {
    my ( $s, $command ,@list) = @_;
    my @rtn;

    # Apply the gzip rsyncable flag if available.
    my $gzipv = Exec::run( $command . ' -V' );
    my @gzipv = $gzipv->[0] =~ /(\d+)(\D+(\d+)(\D+(\d+))?)?/;
    @gzipv = @gzipv[ 0, 2, 4 ];
    if (   $gzipv[0] > 1
        || ( $gzipv[0] == 1 && $gzipv[1] > 3 )
        || ( $gzipv[0] == 1 && $gzipv[1] == 3 && $gzipv[2] >= 5 ) )
    {
        $command .= ' --rsyncable';
    }
    my $zref = sub { Exec->system( $command, '-f', @_ ); };
    foreach my $f (@list) {
        if ( -f $f ) {
            my $m = $Magic->checktype_filename($f);
            my $ignore = grep { $m =~ /$_/ } @DoNotCompress;
            unless ($ignore) {
                my $err = Exec->eval( $zref, $f );

                my $altf  = "$f.gz";
                my $altfz = $altf;
                if ( $altf =~ /\.fits.gz$/ ) {
                    $altfz =~ s/\.fits.gz$/.ftz/g;
                }
                elsif ( $f =~ /\.FIT.gz$/ ) {
                    $altfz =~ s/\.FIT.gz$/.FTZ/g;
                }
                rename( $altf, $altfz ) if ( $altf ne $altfz );

                if ( -f $altfz ) {
                    push @rtn, $altfz;
                }
                elsif ( -f $altf ) {
                    push @rtn, $altf;
                }
                elsif ( -f $f ) {
                    push @rtn, $f;
                }
            }
            else {
                push @rtn, $f;
            }
        }
    }
    return @rtn;
}

sub bzip2_compress {
    my ( $s, $command ,@list) = @_;
    my @rtn;

    my $zref = sub { Exec->system( $command, '-f', @_ ); };
    foreach my $f (@list) {
        if ( -f $f ) {
            my $m = $Magic->checktype_filename($f);
            my $ignore = grep { $m =~ /$_/ } @DoNotCompress;
            unless ($ignore) {
                my $err = Exec->eval( $zref, $f );

                my $altf = "$f.bz2";
                if ( -f $altf ) {
                    push @rtn, $altf;
                }
                elsif ( -f $f ) {
                    push @rtn, $f;
                }
            }
            else {
                push @rtn, $f;
            }
        }
    }
    return @rtn;
}

sub xz_compress {
    my ( $s, $command ,@list) = @_;
    my @rtn;

    my $zref = sub { Exec->system( $command, '-z', @_ ); };
    foreach my $f (@list) {
        if ( -f $f ) {
            my $m = $Magic->checktype_filename($f);
            my $ignore = grep { $m =~ /$_/ } @DoNotCompress;
            unless ($ignore) {
                my $err = Exec->eval( $zref, $f );

                my $altf = "$f.xz";
                if ( -f $altf ) {
                    push @rtn, $altf;
                }
                elsif ( -f $f ) {
                    push @rtn, $f;
                }
            }
            else {
                push @rtn, $f;
            }
        }
    }
    return @rtn;
}

sub gzip_decompress {
    my ( $s, $command ,@list) = @_;
    my @rtn;

    my $zref = sub { Exec->system( $command, '-d', '-f', @_ ); };

    foreach my $f (@list) {
        if ( -f $f ) {

            # Work with FIT files.
            my $altfz = $f;
            if ( $f =~ /\.ftz$/ ) {
                $altfz =~ s/\.ftz$/.fits.gz/g;
            }
            elsif ( $f =~ /\.FTZ$/ ) {
                $altfz =~ s/\.FTZ$/.FIT.gz/g;
            }
            elsif ( $f !~ /\.gz$/ ) {
                $altfz .= '.gz';
            }
            rename( $f, $altfz ) if ( $f ne $altfz );
            my $err = Exec->eval( $zref, $altfz );
            if ( $err && $f ne $altfz ) {
                rename( $altfz, $f );
            }

            my $altf = $altfz;
            $altf =~ s/\.gz$//g;
            if ( -f $altf ) {
                push @rtn, $f;
            }
            elsif ( -f $altfz ) {
                push @rtn, $altfz;
            }
            elsif ( -f $f ) {
                push @rtn, $f;
            }
        }
    }
    return @rtn;
}

sub bzip2_decompress {
    my ( $s, $command ,@list) = @_;
    my @rtn;

    my $zref = sub { Exec->system( $command, '-d', '-f', @_ ); };

    foreach my $f (@list) {
        if ( -f $f ) {

            my $altfz = $f;
            if ( $f !~ /\.bz2$/ ) {
                $altfz .= '.bz2';
            }
            rename( $f, $altfz ) if ( $f ne $altfz );
            my $err = Exec->eval( $zref, $altfz );
            if ( $err && $f ne $altfz ) {
                rename( $altfz, $f );
            }

            my $altf = $altfz;
            $altf =~ s/\.bz2$//g;
            if ( -f $altf ) {
                push @rtn, $f;
            }
            elsif ( -f $altfz ) {
                push @rtn, $altfz;
            }
            elsif ( -f $f ) {
                push @rtn, $f;
            }
        }
    }
    return @rtn;
}

sub xz_decompress {
    my ( $s, $command ,@list) = @_;
    my @rtn;

    my $zref = sub { Exec->system( $command, '-d', '-f', @_ ); };

    foreach my $f (@list) {
        if ( -f $f ) {

            my $altfz = $f;
            if ( $f !~ /\.xz$/ ) {
                $altfz .= '.xz';
            }
            rename( $f, $altfz ) if ( $f ne $altfz );
            my $err = Exec->eval( $zref, $altfz );
            if ( $err && $f ne $altfz ) {
                rename( $altfz, $f );
            }

            my $altf = $altfz;
            $altf =~ s/\.xz$//g;
            if ( -f $altf ) {
                push @rtn, $f;
            }
            elsif ( -f $altfz ) {
                push @rtn, $altfz;
            }
            elsif ( -f $f ) {
                push @rtn, $f;
            }
        }
    }
    return @rtn;
}

sub compress {
    my ($s,$compress)   = (shift,shift);
    $compress ||= $Compress; 
    my @rtn = ();
    if (@_) {
        if ( $compress =~ /gzip/i ) {
            @rtn = $s->gzip_compress( $GzipCompress, @_ );
        }
        elsif ( $compress =~ /bzip/i ) {
            @rtn = $s->bzip2_compress( $Bzip2Compress, @_ );
        }
        elsif ( $compress =~ /xz/i ) {
            @rtn = $s->xz_compress( $XzCompress, @_ );
        }
        else {
            @rtn = @_;
        }
    }
    return @rtn;
}

sub decompress {
    my $c = shift;
    my @rtn;
    foreach my $f (@_) {
        my $m = $Magic->checktype_filename($f);
        if ( $m =~ /gzip/ ) {
            push @rtn, $c->gzip_decompress( $GzipCompress, $f );
        }
        elsif ( $m =~ /bzip2/ ) {
            push @rtn, $c->bzip2_decompress( $Bzip2Compress, $f );
        }
        elsif ( $m eq 'octet-stream' && $f =~ /\.xz$/ ) {
            push @rtn, $c->xz_decompress( $XzCompress, $f );
        }
        else {
            push @rtn, $f;
        }
    }
    return @rtn;
}
1;

=head1 NAME

File::Compression - Utility interface to system file compression and decompression.

=head1 VERSION

Version 1.0.0

=cut

=head1 SYNOPSIS

Class method interfaces to system file compression and decompression.
FIT files are renamed (FIT.gz to FTZ and .fits.gz to .ftz) so they will work with standard HEASOFT tools.

    use File::Compression;
    $File::Compression::Compress = 'gzip' # The default compression method.
    $File::Compression::GzipCompress = 'gzip' # The default gzip binary to call.
    $File::Compression::Bzip2Compress = 'bzip2' # The default bzip2 binary to call.
    $File::Compression::XzCompress = 'xz' # The default xz binary to call.
    @File::DoNotCompress = qw(zip image/bmp image/gif image/jpeg image/png image/x-xbm audio/mpeg);
    # patterns matching File::MMagic types you do not want to compress (eg. already comperssed file formats)

    
    my @newlist = File::Compression->compress(@filelist);
    # Apply the default compression method to the given @filelist and return a list of new (compressed) filenames.
    
    my @newlist = File::Compression->decompress(@filelist);
    # Test each file and if it looks compressed, try to decompress it.  Return a list of new (uncompressed) filenames.
    
    my @newlist = File::Compression->gzip_compress($command , @filelist);
    # Apply the given command (or the default $GzipCompress) to the given @filelist and return a list of new (compressed) filenames.
    
    my @newlist = File::Compression->gzip_decompress($command,@filelist);
    # Try to decompress each file in @filelist as if it were gzip compressed.  Return a list of new (uncompressed) filenames.

    my @newlist = File::Compression->bzip2_compress($command , @filelist);
    # Apply the given command (or the default $Bzip2Compress) to the given @filelist and return a list of new (compressed) filenames.
    
    my @newlist = File::Compression->bzip2_decompress($command,@filelist);
    # Try to decompress each file in @filelist as if it were bzip2 compressed.  Return a list of new (uncompressed) filenames.
    
        my @newlist = File::Compression->xz_compress($command , @filelist);
    # Apply the given command (or the default $XzCompress) to the given @filelist and return a list of new (compressed) filenames.
    
    my @newlist = File::Compression->xz_decompress($command,@filelist);
    # Try to decompress each file in @filelist as if it were xz compressed.  Return a list of new (uncompressed) filenames.    


=head1 AUTHOR

Duncan Fyfe, C<< <duncanfyfe at domenlas.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-application-toolkit-perl at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=application-toolkit-perl>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc File::Compression


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

1;    # End of File::Compression
