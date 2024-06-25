#!/usr/bin/perl

use strict;

my @keys = (
    [ "\eOP",   chr(0x00ab) ],
    [ "\eOQ",   chr(0x00bb) ],
    [ "\eOR",   '\nopagenumbers' ],
    [ "\e[23~", 'Top' ],
    [ "\e[24~", 'Bottom' ],
    [ "\e[5~",  'PageUp' ],
    [ "\e[6~",  'PageDown' ],
    [ "\e[A",   'Up' ],
    [ "\e[B",   'Down' ],
    [ "\e[H",   'Home' ],
    [ "\e[F",   'End' ],
    [ "\e[D",   'Left' ],
    [ "\e[C",   'Right' ],
    [ "\e[2~",  'KillToEOL' ],
    [ "\e[3~",  'Delete' ]
);

$| = 1;

$SIG{WINCH} = sub { close STDIN };

my @lines;
my $filename = $ARGV[0];
open( FILE, $filename );
for my $line (<FILE>) {
    chomp($line);
    push( @lines, $line );
}
close(FILE);

my ( $rows, $cols ) = split( / /, `stty size` );
$rows -= 1;

my ( $topline, $x, $y );
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
    last if defined($key) && !dokey($key);
    if ($fullupdate) {
        $fullupdate = 0;
        print "\e[H";
        print "\e[J";
        for ( my $pos = $topline; $pos < $topline + $rows && $pos < scalar(@lines); $pos++ ) {
            drawline($pos);
        }
        print "\e[", $rows + 1, ';1f';
        print "\e[35m" if $ENV{edit};
        print "\e[7m", $filename, ' ' x ( $cols - 1 - length($filename) ), "\e[m";
    }
    else {
        print "\e[", $y + 1, ';1f';
        print "\e[K";
        drawline( current_line_number() );
    }
    print "\e[", $y + 1, ';', ( $x < $cols ? $x + 1 : $cols ), 'f';
    $key = readkey();
}

sub dokey
{
    my ($key) = @_;
    if ( $key eq chr(0x08) ) {
        if ( $x == 0 ) {
            if ( current_line_number() > 0 ) {
                $x = length( line(-1) ) + 1;
                line( -1, line(-1) . line() );
                splice( @lines, current_line_number(), 1 );
                if ( $y > 0 ) {
                    $y--;
                    $fullupdate = 1;
                }
                else { $topline-- }
            }
        }
        else {
            my $begin = substr( line(), 0, $x - 1 );
            my $end = substr( line(), $x );
            my $line = $begin . $end;
            line( 0, $line );
        }
        moveleft(1);
    }
    elsif ( $key eq chr(0x0d) ) {
        my $begin = substr( line(), 0, $x );
        my $end = substr( line(), $x );
        line( 0, $begin );
        splice( @lines, current_line_number() + 1, 0, $end );
        $fullupdate = 1;
        movedown(1);
        $x = 0;
    }
    elsif ( $key eq chr(0x1b) )  {
        save();
        if ( $ENV{db} ) {
            open DB, ">>$ENV{db}";
            print DB "$ENV{abs} $topline-$x-$y ", `md5sum $filename | head -c32`, '-', `stty size | tr ' ' -`;
            close DB;
        }
        return;
    }
    elsif ( $key eq 'Resize' ) {
        save();
        return;
    }
    elsif ( $key eq 'Top' ) { moveup( current_line_number() + 1 ) }
    elsif ( $key eq 'Bottom' ) { movedown( scalar(@lines) - current_line_number() ) }
    elsif ( $key eq 'PageUp' ) { moveup($rows) }
    elsif ( $key eq 'PageDown' ) { movedown($rows) }
    elsif ( $key eq 'Up' ) { moveup(1) }
    elsif ( $key eq 'Down' ) { movedown(1) }
    elsif ( $key eq 'Home' ) { $x = 0 }
    elsif ( $key eq 'End' ) { $x = length( line() ) }
    elsif ( $key eq 'Left' )  { moveleft(1) }
    elsif ( $key eq 'Right' )  { moveright(1) }
    elsif ( $key eq 'KillToEOL' ) {
        line( 0, substr( line(), 0, $x ) );
        delat() if $x == 0;
    }
    elsif ( $key eq 'Delete' ) { delat() }
    elsif ( !grep( $key eq $_, map( chr, 0 .. 8, 10 .. 31 ), chr(0x7f) ) ) {
        my $begin = substr( line(), 0, $x );
        my $end = substr( line(), $x );
        line( 0, $begin . $key . $end );
        moveright( length($key) );
    }
    return 1;
}

sub save
{
    open( FILE, ">$filename" );
    for my $line (@lines) {
        print FILE $line, "\n";
    }
    close(FILE);
}

sub moveright
{
    $x += shift;
    if ( $x > length( line() ) ) {
        if ( current_line_number() < scalar(@lines) - 1 ) {
            $x = 0;
            movedown(1);
        }
    }
}

sub moveleft
{
    $x -= shift;
    if ( $x < 0 ) {
        if ( current_line_number() > 0 ) {
            $x = length( line(-1) );
            moveup(1);
        }
        else { $x = 0 }
    }
}

sub moveup
{
    $y -= shift;
    if ( $y < 0 ) {
        $fullupdate = 1 if $topline > 0;
        $topline += $y;
        $y = 0;
    }
    if ( $topline < 0 ) {
        $topline = 0;
        $x = 0;
    }
    $x = length( line() ) if $x > length( line() );
}

sub movedown
{
    my $tempy = $y + shift;

    my $nrlines = scalar(@lines);
    if ( $topline + $tempy >= $nrlines ) {
        $topline = $nrlines - $rows;
        $topline = 0 if $topline < 0;
        $tempy = $nrlines - $topline - 1;
        $x = length( $lines[ $topline + $tempy ] );
        $fullupdate = 1 if $rows < $nrlines;
    }
    elsif ( $tempy >= $rows ) {
        $topline += $tempy - $rows + 1;
        $tempy = $rows - 1;
        $fullupdate = 1;
    }

    $y = $tempy;
    $x = length( line() ) if $x > length( line() );
}

sub delat
{
    my $len = length( line() );
    if ( $x < $len ) {
        my $begin = substr( line(), 0, $x );
        my $end = substr( line(), $x + 1 );
        line( 0, $begin . $end );
    }
    else {
        line( 0, line() . line(1) );
        splice( @lines, current_line_number() + 1, 1 );
        $fullupdate = 1;
    }
}

sub line
{
    my ( $offset, $text ) = @_;
    my $pos = current_line_number() + $offset;
    if ( defined($text) ) { $lines[$pos] = $text }
    else { return $lines[$pos] }
}

sub current_line_number
{
    return $topline + $y;
}

sub drawline
{
    my ($pos) = @_;
    my $line = $lines[$pos];

    if ( $x < $cols - 1 ) {
        $line = substr( $line, 0, $cols - 1 );
    }
    else {
        $line = substr( $line, $x - ( $cols - 1 ), $cols - 1 );
    }

    $line .= "\e[41m \e[m" if length( $lines[$pos] ) > $cols - 1;
    1 while $line =~ s/\t+/"\e[1m\e[33m" . chr(0x2588) x length($&) . "\e[m"/e;
    print $line, "\r\n";
}

use Time::HiRes 'ualarm';
my @buffer;
sub readkey
{
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
        for my $key (@keys) {
            my $i = 0;
            while (1) {
                if ( $i == scalar(@buffer) && $i == length( $$key[0] ) ) {
                    @buffer = ();
                    return $$key[1];
                }
                last if $i == scalar(@buffer) || $i == length( $$key[0] );
                last if $buffer[$i] ne substr( $$key[0], $i, 1 );
                $i++;
            }
            $submatch = 1 if $i == scalar(@buffer) && $i < length( $$key[0] );
        }
    } while ($submatch);
    if ( scalar(@buffer) > 1 ) {
        $buffer[0] = '[';
        return '^';
    }
    return shift(@buffer);
}
