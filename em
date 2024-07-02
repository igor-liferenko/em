#!/usr/bin/perl

use strict;

my @keys = (
    [ "\eOP",   'F1'       ],
    [ "\eOQ",   'F2'       ],
    [ "\eOR",   'F3'       ],
    [ "\eOS",   'F4'       ],
    [ "\e[15~", 'F5'       ],
    [ "\e[17~", 'F6'       ],
    [ "\e[18~", 'F7'       ],
    [ "\e[19~", 'F8'       ],
    [ "\e[20~", 'F9'       ],
    [ "\e[21~", 'F10'      ],
    [ "\e[23~", 'F11'      ],
    [ "\e[24~", 'F12'      ],
    [ "\e[5~",  'PageUp'   ],
    [ "\e[6~",  'PageDown' ],
    [ "\e[A",   'Up'       ],
    [ "\e[B",   'Down'     ],
    [ "\e[H",   'Home'     ],
    [ "\e[F",   'End'      ],
    [ "\e[D",   'Left'     ],
    [ "\e[C",   'Right'    ],
    [ "\e[2~",  'Insert'   ],
    [ "\e[3~",  'Delete'   ]
);

$| = 1;

$SIG{WINCH} = sub { close STDIN };

my $filename = $ARGV[0];
open( FILE, $filename );
chomp( my @lines = <FILE> );
close(FILE);

my ( $rows, $cols ) = split( /[ \n]/, `stty size` );
$rows -= 1;

my ( $topline, $x, $y ) = (0) x 3;
if ( $ARGV[1] =~ /(.*)-(.*)-(.*)/ ) {
    $topline = $1; $x = $2; $y = $3;
}
elsif ( $ARGV[1] ) {
    $topline = $ARGV[1] - int( $rows / 2 ) - 1;
    $y = $topline < 0 ? $ARGV[1] - 1 : $ARGV[1] - $topline - 1;
}

my $fullupdate = 1;

my $key;

while (1) {
    my $lasttopline = $topline;
    my $lastnrlines = scalar(@lines);
    last if defined($key) && !dokey();
    $fullupdate = 1 if $lasttopline != $topline || $lastnrlines != scalar(@lines);
    if ($fullupdate) {
        $fullupdate = 0;
        print( "\e[H" );
        print( "\e[J" );
        my $n = $topline;
        drawline($n++) while $n < $topline + $rows && $n < scalar(@lines);
        print( "\e[", $rows + 1, ';1f' );
        print( "\e[34m" ) if $ENV{edit};
        print( "\e[7m", $filename, ' ' x ( $cols - 1 - length($filename) ), "\e[m" );
    }
    else {
        print( "\e[", $y + 1, ';1f' );
        print( "\e[K" );
        drawline( curlinenr() );
    }
    print( "\e[", $y + 1, ';', $x + 1, 'f' );
    $key = readkey();
}

sub dokey {
    if ( $key eq 'F1' ) { $key = chr(0x00ab) }
    if ( $key eq 'F2' ) { $key = chr(0x00bb) }
    if ( $key eq 'F3' ) { $key = '\nopagenumbers' }
    if ( $key eq 'F4' ) { $key = '\nointerlineskip' }
    if ( $key eq 'F5' ) { $key = '\offinterlineskip' }
    if ( $key eq 'F6' ) { $key = '\pdfpagewidth' }
    if ( $key eq 'F7' ) { $key = '\pdfpageheight' }
    if ( $key eq 'F8' ) { $key = '\pdfhorigin' }
    if ( $key eq 'F9' ) { $key = '\pdfvorigin' }
    if ( $key eq 'F10' ) { $key = '\advance' }
    if ( $key eq 'F11' ) { moveup( curlinenr() + 1 ) }
    elsif ( $key eq 'F12' ) { movedown( scalar(@lines) - curlinenr() ) }
    elsif ( $key eq 'PageUp' ) { moveup($rows) }
    elsif ( $key eq 'PageDown' ) { movedown($rows) }
    elsif ( $key eq 'Up' ) { moveup(1) }
    elsif ( $key eq 'Down' ) { movedown(1) }
    elsif ( $key eq 'Home' ) { $x = 0 }
    elsif ( $key eq 'End' ) { $x = length( line() ) }
    elsif ( $key eq 'Left' )  { moveleft(1) }
    elsif ( $key eq 'Right' )  { moveright(1) }
    elsif ( $key eq 'Insert' ) { delteol() }
    elsif ( $key eq 'Delete' ) { delat() }
    elsif ( $key eq "\cH" ) { backspaceat(), moveleft(1) }
    elsif ( $key eq "\r" ) { newlineat(), movedown(1), $x = 0 }
    elsif ( $key eq "\e" ) { savefile(), savecursor(), return 0 }
    elsif ( $key eq 'Resize' )  { savefile(), return 0 }
    else {
        grep( $key eq $_, map( chr, 0 .. 8, 10 .. 31, 127 ) ) and
            $key = '^' . ( ord($key) < 64 ? chr( ord($key) + 64 ) : '?' );
        setat(), moveright( length($key) ) if $x < $cols - 1 || length( line() ) < $cols;
    }
    $x = $cols - 1 if $x >= $cols;
    return 1;
}

sub savefile {
    open( FILE, ">$filename" );
    print( FILE "$_\n" ) for @lines;
    close(FILE);
}

sub savecursor {
    return unless $ENV{db};
    open( DB, ">>$ENV{db}" );
    print( DB "$ENV{abs} $topline-$x-$y" );
    printf( DB " %s%.0s-%s-%s", map( split(/ +/), `md5sum $filename`, `stty size` ) );
    close(DB);
}

sub moveright {
    $x += $_[0];
    if ( $x > length( line() ) ) {
        if ( curlinenr() < scalar(@lines) - 1 ) {
            $x = 0;
            movedown(1);
        }
        else { $x = length( line() ) }
    }
}

sub moveleft {
    $x -= $_[0];
    if ( $x < 0 ) {
        if ( curlinenr() > 0 ) {
            $x = length( line(-1) );
            moveup(1);
        }
        else { $x = 0 }
    }
}

sub moveup {
    $y -= $_[0];
    if ( $y < 0 ) {
        $topline += $y;
        $y = 0;
    }
    if ( $topline < 0 ) {
        $topline = 0;
        $x = 0;
    }
    $x = length( line() ) if $x > length( line() );
}

sub movedown {
    my $tempy = $y + $_[0];

    my $nrlines = scalar(@lines);
    if ( $topline + $tempy >= $nrlines ) {
        $topline = $nrlines - $rows;
        $topline = 0 if $topline < 0;
        $tempy = $nrlines - $topline - 1;
        $x = length( $lines[ $topline + $tempy ] );
    }
    elsif ( $tempy >= $rows ) {
        $topline += $tempy - $rows + 1;
        $tempy = $rows - 1;
    }

    $y = $tempy;
    $x = length( line() ) if $x > length( line() );
}

sub delteol {
    line() = substr( line(), 0, $x );
    delat() if $x == 0;
}

sub newlineat {
    splice( @lines, curlinenr() + 1, 0, substr( line(), $x ) );
    line() = substr( line(), 0, $x );
}

sub delat {
    if ( $x < length( line() ) ) {
        line() = substr( line(), 0, $x ) . substr( line(), $x + 1 );
    }
    else {
        line() = line() . line(1);
        splice( @lines, curlinenr() + 1, 1 );
    }
}

sub backspaceat {
    if ( $x == 0 ) {
        if ( curlinenr() > 0 ) {
            $x = length( line(-1) ) + 1;
            line(-1) = line(-1) . line();
            splice( @lines, curlinenr(), 1 );
            if ( $y > 0 ) { $y-- }
            else { $topline-- }
        }
    }
    else {
        line() = substr( line(), 0, $x - 1 ) . substr( line(), $x );
    }
}

sub line : lvalue {
    $lines[ curlinenr() + $_[0] ];
}

sub setat {
    line() = substr( line(), 0, $x ) . $key . substr( line(), $x );
}

sub curlinenr {
    $topline + $y;
}

sub drawline {
    my $line = $lines[ $_[0] ];
    my $ln = substr( $line, 0, $cols - 1 );
    $ln =~ s/\t/\e[43m\e[1m\e[33m\x{2588}\e[m/g;
    $ln .= "\e[41m\e[1m\e[31m\x{2588}\e[m" if length($line) > $cols - 1;
    print( $ln, "\r\n" );
}

use Time::HiRes 'ualarm';
my @buffer;
sub readkey {
    # if recorded bytes remain, handle next recorded byte
    if ( scalar(@buffer) ) {
        return shift(@buffer);
    }
    my $submatch;
    do {
        my $k;
        if ( scalar(@buffer) == 1 ) { # to use ^[ / ESC
            eval {
                local $SIG{ALRM} = sub { die };
                ualarm 300_000;
                read( STDIN, $k, 1 );
                ualarm 0;
            };
            return shift(@buffer) if $@;
        }
        else { return 'Resize' if !defined( read( STDIN, $k, 1 ) ) }
        push( @buffer, $k );
        $submatch = 0;
        for (@keys) {
            my $i = 0;
            while (1) {
                if ( $i == scalar(@buffer) && $i == length( $$_[0] ) ) {
                    @buffer = ();
                    return $$_[1];
                }
                last if $i == scalar(@buffer) || $i == length( $$_[0] );
                last if $buffer[$i] ne substr( $$_[0], $i, 1 );
                $i++;
            }
            $submatch = 1 if $i == scalar(@buffer) && $i < length( $$_[0] );
        }
    } while ($submatch);
    if ( scalar(@buffer) > 1 ) {
        $buffer[0] = '[';
        return '^';
    }
    return shift(@buffer);
}
