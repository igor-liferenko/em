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
    $forceupdate, $cols,        $rows,
    $center_line, $lasttopline, $lastnrlines, $filename
);

my @lines;

$SIG{WINCH} = sub { close STDIN };

init();
load();
run();

sub init {
    $forceupdate = 1;
}

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
    return 1;
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
    elsif ( $center_line ) {
      $topline = $center_line - int( $rows / 2 ) - 1;
      $y = $topline < 0 ? $center_line - 1 : $center_line - $topline - 1;
    }

    my $key;

    while (1) {
        $lasttopline = $topline;
        $lastnrlines = get_nrlines();
        last if ( !dokey($key) );
        draw();
        move();
        $key = ReadKey();
    }
}

sub get_nrlines {
    return scalar(@lines);
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
    elsif ( $key eq chr(0x1b) ) { moveup( current_line_number() ) }
    elsif ( $key eq chr(0x1d) ) { movedown( get_nrlines() - current_line_number() ) }
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
        if ( current_line_number() < get_nrlines() - 1 ) {
            $x = 0;
            movedown(1);
        }
    }
}

sub moveleft {
    my ($amount) = @_;
    $x -= $amount;

    if ( $x < 0 ) {
        $x = length2( line(-1) );
        moveup(1);
    }
}

sub moveup {
    my ($amount) = @_;
    $y -= $amount;

    # check for topline, move up
    if ( $y < 0 ) {
        $topline += $y;
        $y = 0;
    }
}

sub movedown {
    my ($amount) = @_;
    my $tempy = $y + $amount;

    my $nrlines = get_nrlines();

    # move down
    if ( ( $topline + $tempy ) >= $nrlines ) {
        $topline = $nrlines - $rows;
        $topline = 0 if ( $topline < 0 );
        $tempy   = $nrlines - $topline - 1;
    }
    elsif ( $tempy >= $rows ) {
        $topline += ( $tempy - $rows + 1 );
        $tempy = $rows - 1;
    }

    # check for corsormovement beyond line length2
    $y = $tempy;
}

sub delteol {
    line( 0, substr( line(), 0, $x ) );
    delat() if ( $x == 0 );
}

sub newlineat {
    my $begin = substr( line(), 0, $x );
    my $end   = substr( line(), $x );

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
    if ( $x <= 0 && $y > 0 ) {
        $x = length2( line(-1) ) + 1;
        line( -1, line(-1) . line() );
        splice( @lines, current_line_number(), 1 );
        moveup(1);
    }
    else {
        my $begin = substr( line(), 0, $x ? $x - 1 : 0 );
        my $end   = substr( line(), $x );
        my $line  = $begin . $end;
        line( 0, $line );
    }
}

sub line {
    my ( $offset, $text ) = @_;
    $offset ||= 0;
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

sub clear {
    print "\e[2J";
}

sub footer {
    absmove( 1, $rows + 1 );
    print inverse( ' ' x ( $cols - 1 ) );
    absmove( 1, $rows + 1 );
    print inverse( $filename );
}

sub current_line_number {
    return $topline + $y;
}

sub draw {
    my $len = length( line() );
    $x = $len if ( $x > $len );
    if ( $topline < 0 ) {
        $topline = 0;
        $x       = 0;
    }

    # update only current line
    if (   $lasttopline == $topline
        && $lastnrlines == get_nrlines()
        && !$forceupdate )
    {
        absmove( 1, $y + 1 );
        print "\e[K";
        drawline( current_line_number() );
    }
    else    # update screen
    {
        clear();
        absmove( 1, 1 );

        for ( my $pos = $topline ; $pos < $topline + $rows && $pos < get_nrlines() ; $pos++ ) {
            drawline($pos);
        }
        $forceupdate = 0;
    }
    footer();
}

sub drawline {
    my ($pos) = @_;
    my $line = $lines[$pos];

    # expand tabs

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
    # calculate length with tabs expanded
    my ($text) = @_;
    1 while $text =~ s/\t+/' ' x (length($&) * 8 - length($`) % 8)/e;
    return length($text);
}

use Time::HiRes 'ualarm';
my @buffer;
sub ReadKey {
  # if recorded bytes remain, handle next recorded byte
  if (scalar @buffer) {
    return shift @buffer;
  }
  my $submatch;
  do {
    my $k;
    if (scalar(@buffer) == 1) { # to use ^[
      eval {
        local $SIG{ALRM} = sub { die };
        ualarm 300_000;
        read(STDIN, $k, 1);
        ualarm 0;
      };
      return shift @buffer if $@;
    }
    else { return 'Resize' if !defined read(STDIN, $k, 1) }
    push @buffer, $k;
    $submatch = 0;
    for my $key (@keys) {
      my $i = 0;
      while (1) {
        if ($i == scalar(@buffer) && $i == length($$key[1])) {
          @buffer = ();
          return $$key[0];
        }
        last if $i == scalar(@buffer) || $i == length($$key[1]);
        last if $buffer[$i] ne substr($$key[1], $i, 1);
        $i++;
      }
      $submatch = 1 if $i == scalar(@buffer) && $i < length($$key[1]);
    }
  } while ($submatch);
  if (scalar(@buffer) > 1) {
    $buffer[0] = '[';
    return '^';
  }
  return shift @buffer;
}
