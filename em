#!/usr/bin/perl

use strict;

my @keys = (
    [ 'F1',       "\eOP"  ],
    [ 'F2',       "\eOQ"  ],
    [ 'Up',       "\e[A"  ],
    [ 'Down',     "\e[B"  ],
    [ 'Left',     "\e[D"  ],
    [ 'Right',    "\e[C"  ],
    [ 'Home',     "\e[H"  ],
    [ 'End',      "\e[F"  ],
    [ 'Delete',   "\e[3~" ],
    [ 'PageUp',   "\e[5~" ],
    [ 'PageDown', "\e[6~" ]
);

$| = 1;
$_ = '' for my (
    $x,           $y,           $topline,
    $cols,        $rows,        $filename,
    $center_line, $lasttopline, $lastnrlines, $forceupdate
);

my @lines;

$SIG{WINCH} = sub { close STDIN };

init();
load();
run();

sub init { $forceupdate = 1 }

sub get_terminal_size {
    ( $rows, $cols ) = split( /\s+/, `stty size` );
    $rows -= 1;
}

sub load {
    my $regexp = qr/\+([\d-]+)/;
    ($filename) = grep { $_ !~ $regexp } @ARGV;

    if ( !open( FILE, $filename ) ) {
        @lines = ('');
        return;
    }
    foreach my $line (<FILE>) {
        chomp $line;
        push( @lines, $line );
    }
    close(FILE);
}

sub save {
    open( FILE, ">$filename" );
    foreach my $line (@lines) {
        print FILE $line . "\n";
    }
    close(FILE);
}

sub run {
    get_terminal_size();
    my $regexp = qr/\+([\d-]+)/;
    my ($center_line_arg) = grep { $_ =~ $regexp } @ARGV;
    my ($center_line) = $center_line_arg =~ $regexp;
    if ( $center_line =~ /(.*)-(.*)-(.*)/ ) {
        $topline = $1; $x = $2; $y = $3;
    }
    elsif ($center_line) {
        $topline = $center_line - int( $rows / 2 ) - 1;
        $y = $topline < 0 ? $center_line - 1 : $center_line - $topline - 1;
    }

    my $key;

    while (1) {
        $lasttopline = $topline;
        $lastnrlines = scalar(@lines);
        last if ( !dokey($key) );
        draw();
        move();
        $key = ReadKey();
    }
}

sub dokey {
    my ($key) = @_;
    $key = chr(0x00ab) if $key eq 'F1';
    $key = chr(0x00bb) if $key eq 'F2';
    if ( $key eq chr(0x08) ) {
        backspaceat();
        moveleft(1);
    }
    elsif ( $key eq chr(0x0b) ) {
        delteol();
    }
    elsif ( $key eq chr(0x0d) ) {
        newlineat();
        movedown(1);
        $x = 0;
    }
    elsif ( $key eq chr(0x1a) )  {
        save();
        if ($ENV{db}) {
            open DB, ">>$ENV{db}";
            print DB "$ENV{abs} $topline-$x-$y ", `md5sum $filename | head -c32`, '-', `stty size | tr ' ' -`;
            close DB;
        }
        return;
    }
    elsif ( $key eq chr(0x1b) ) { moveup( current_line_number() + 1 ) }
    elsif ( $key eq chr(0x1d) ) { movedown( scalar(@lines) - current_line_number() ) }
    elsif ( $key eq 'Resize' ) {
        save();
        return;
    }
    elsif ( $key eq 'Up' ) { moveup(1) }
    elsif ( $key eq 'Down' ) { movedown(1) }
    elsif ( $key eq 'PageUp' ) { moveup($rows) }
    elsif ( $key eq 'PageDown' ) { movedown($rows) }
    elsif ( $key eq 'Right' )  { moveright(1) }
    elsif ( $key eq 'Left' )  { moveleft(1) }
    elsif ( $key eq 'Delete' ) { delat() }
    elsif ( $key eq 'Home' ) { $x = 0 }
    elsif ( $key eq 'End' ) { $x = length( line() ) }
    elsif ( $key eq chr(0x09) || ( ord($key) >= 32 && $key ne chr(0x7f) ) ) {
        setat($key);
        moveright(1);
    }
    return 1;
}

sub moveright {
    my ($amount) = @_;
    $x += $amount;
    if ( $x > length( line() ) ) {
        if ( current_line_number() < scalar(@lines) - 1 ) {
            $x = 0;
            movedown(1);
        }
    }
}

sub moveleft {
    my ($amount) = @_;
    $x -= $amount;
    if ( $x < 0 ) {
        if ( current_line_number() > 0 ) {
            $x = length2( line(-1) );
            moveup(1);
        }
        else { $x = 0 }
    }
}

sub moveup {
    my ($amount) = @_;
    $y -= $amount;
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
    my ($amount) = @_;
    my $tempy = $y + $amount;
    my $xx = 0;

    my $nrlines = scalar(@lines);
    if ( $topline + $tempy >= $nrlines ) {
        $topline = $nrlines - $rows;
        $topline = 0 if $topline < 0;
        $tempy = $nrlines - $topline - 1;
        $xx = 1;
    }
    elsif ( $tempy >= $rows ) {
        $topline += $tempy - $rows + 1;
        $tempy = $rows - 1;
        $xx = 1;
    }

    $y = $tempy;
    $x = length( line() ) if $xx || $x > length( line() );
}

sub delteol {
    line( 0, substr( line(), 0, $x ) );
    delat() if $x == 0;
}

sub newlineat {
    my $begin = substr( line(), 0, $x );
    my $end = substr( line(), $x );
    line( 0, $begin );
    splice( @lines, current_line_number() + 1, 0, $end );
}

sub delat {
    my $len = length2( line() );
    if ( $x < $len ) {
        my $begin = substr( line(), 0, $x );
        my $end = substr( line(), $x + 1 );
        line( 0, $begin . $end );
    }
    else {
        line( 0, line() . line(1) );
        splice( @lines, current_line_number() + 1, 1 );
    }
}

sub backspaceat {
    if ( $x == 0 ) {
        if ( current_line_number() > 0 ) {
            $x = length2( line(-1) ) + 1;
            line( -1, line(-1) . line() );
            splice( @lines, current_line_number(), 1 );
            if ( $y > 0 ) { $y-- }
            else { $topline-- }
        }
    }
    else {
        my $begin = substr( line(), 0, $x - 1 );
        my $end = substr( line(), $x );
        my $line = $begin . $end;
        line( 0, $line );
    }
}

sub line {
    my ( $offset, $text ) = @_;
    my $pos = current_line_number() + $offset;
    if ( defined($text) ) {
        $lines[$pos] = $text;
    }
    else {
        return $lines[$pos];
    }
}

sub setat {
    my ($key) = @_;
    my $begin = substr( line(), 0, $x );
    my $end = substr( line(), $x );
    line( 0, $begin . $key . $end );
}

sub current_line_number {
    return $topline + $y;
}

sub draw {
    if ( $lasttopline == $topline && $lastnrlines == scalar(@lines) && !$forceupdate ) {
        absmove( 1, $y + 1 );
        print "\e[K";
        drawline( current_line_number() );
    }
    else {
        print "\e[2J";
        absmove( 1, 1 );
        for ( my $pos = $topline; $pos < $topline + $rows && $pos < scalar(@lines); $pos++ ) {
            drawline($pos);
        }
        $forceupdate = 0;
    }
    absmove( 1, $rows + 1 );
    print inverse( ' ' x ( $cols - 1 ) );
    absmove( 1, $rows + 1 );
    print inverse($filename);
}

sub drawline {
    my ($pos) = @_;
    my $line = $lines[$pos];
    1 while $line =~ s/\t+/' ' x (length($&) * 8 - length($`) % 8)/e;

    my $realx = getrealx( $lines[$pos] );
    if ( $realx < $cols - 1 ) {
        $line = substr( $line, 0, $cols - 1 );
    }
    else {
        $line = substr( $line, $realx - ( $cols - 1 ), $cols - 1 );
    }

    $line .= "\e[41m \e[m" if length2( $lines[$pos] ) > $cols - 1;
    print $line . "\r\n";
}

sub absmove {
    my ( $x, $y ) = @_;
    print "\e[" . $y . ';' . $x . 'f';
}

sub getrealx {
    my ($line) = @_;
    return length2( substr( $line, 0, $x ) );
}

sub move {
    my $realx = getrealx( line() );
    print "\e[" . ( $y + 1 ) . ';' . ( $realx + 1 ) . 'f';
}

sub inverse {
    my ($text) = @_;
    return ( $ENV{edit} ? "\e[35m" : '' ) . "\e[7m" . $text . "\e[m";
}

sub length2 {
    my ($text) = @_;
    1 while $text =~ s/\t+/' ' x (length($&) * 8 - length($`) % 8)/e;
    return length($text);
}

use Time::HiRes 'ualarm';
my @buffer;
sub ReadKey {
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
                read(STDIN, $k, 1);
                ualarm 0;
            };
            return shift(@buffer) if $@;
        }
        else { return 'Resize' if !defined read(STDIN, $k, 1) }
        push( @buffer, $k );
        $submatch = 0;
        for my $key (@keys) {
            my $i = 0;
            while (1) {
                if ( $i == scalar(@buffer) && $i == length( $$key[1] ) ) {
                    @buffer = ();
                    return $$key[0];
                }
                last if $i == scalar(@buffer) || $i == length( $$key[1] );
                last if $buffer[$i] ne substr( $$key[1], $i, 1 );
                $i++;
            }
            $submatch = 1 if $i == scalar(@buffer) && $i < length( $$key[1] );
        }
    } while ($submatch);
    if ( scalar(@buffer) > 1 ) {
        $buffer[0] = '[';
        return '^';
    }
    return shift(@buffer);
}
