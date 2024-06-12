#!/usr/bin/perl
#
# |ped| v0.7 Text Editor in Perl
# (C)2005 DaanSystems, Niek Albers
# License: PAL (Perl Artistic License)
# http://www.daansystems.com
# mailto:nieka@daansystems.com

use strict;

my @keys = (
  [ 'F1',       "\eOP"  ],
  [ 'Up',       "\e[A"  ],
  [ 'Down',     "\e[B"  ],
  [ 'Left',     "\e[D"  ],
  [ 'Right',    "\e[C"  ],
  [ 'Home',     "\e[H"  ],
  [ 'End',      "\e[F"  ],
  [ 'Insert',   "\e[2~" ],
  [ 'Delete',   "\e[3~" ],
  [ 'PageUp',   "\e[5~" ],
  [ 'PageDown', "\e[6~" ]
);

$| = 1;
$_ = '' for my (
    $x,           $y,           $topline,     $lastxsearch, $lastysearch, $ins,
    $forceupdate, $cols,        $rows,        $search,      $status,      $filename,
    $dos,         $center_line, $lasttopline, $lastnrlines, $searchx,     $stty
);

my @lines;

# catch terminal resize
$SIG{WINCH} = sub {
    get_terminal_size();
    $forceupdate = 1;
    draw();
};

init();
load();
run();

sub init {
    $lastxsearch = -1;
    $forceupdate = 1;
    $ins         = 1;
    $searchx     = 0;
}

sub get_terminal_size {
    ( $rows, $cols ) = split( /\s+/, `stty size` );
    $rows -= 2;
}

sub load {
    my $regexp = qr/\+(\d+)/;
    ($filename) = grep { $_ !~ $regexp } @ARGV;

    if ( !open( FILE, $filename ) ) {
        @lines = ('');
        return;
    }
    foreach my $line (<FILE>) {
        $dos = 1 if ( $line =~ m/\r\n$/ );
        $line =~ s/\r?\n$//;
        push( @lines, $line );
    }

    close(FILE);
    $dos = $dos;
    return 1;
}

sub save {
    my $savefilename = $filename || input('Filename');

    if ( !open( FILE, ">$savefilename" ) ) {
        $status = "Save failed $!";
        return;
    }
    my $count = 0;
    foreach my $line (@lines) {
        print FILE $line . ( $dos ? "\r\n" : "\n" );
        $count++;
    }
    close(FILE);

    $status = "Saved $count lines.";
    footer();
    $filename = $savefilename;
    return 1;
}

sub run {
    get_terminal_size();
    my $regexp = qr/\+(\d+)/;
    my ($center_line_arg) = grep { $_ =~ $regexp } @ARGV;
    my ($center_line) = $center_line_arg =~ $regexp;
    $topline = $center_line - ( $rows / 2 ) - 1;

    ReadMode(5);
    my $key;

    while (1) {
        $lasttopline = $topline;
        $lastnrlines = get_nrlines();
        last if ( !dokey($key) );
        draw();
        move();
        $key = ReadKey();
    }

    ReadMode(0);
    absmove( 1, $rows + 2 );
    print "\n";
}

sub get_nrlines {
    return scalar(@lines);
}

sub dokey {
    my ($key) = @_;
    my $ctrl = ord($key);
    if    ( $ctrl == 3 )  { return }                  # Ctrl+c
    elsif ( $ctrl == 4 )  { return if ( save() ) }    # Ctrl+d
    elsif ( $key eq 'Up' ) { moveup(1) }
    elsif ( $key eq 'Down' ) { movedown(1) }
    elsif ( $key eq 'PageUp' ) { moveup($rows) }
    elsif ( $key eq 'PageDown' ) { movedown($rows) }
    elsif ( $key eq 'Right' )  { moveright(1) }
    elsif ( $key eq 'Left' )  { moveleft(1) }
    elsif ( $key eq 'Delete' ) { delat() }
    elsif ( $key eq 'Home' ) { moveup( current_line_number() ) }
    elsif ( $key eq 'End' ) { movedown( get_nrlines() - current_line_number() ) }
    elsif ( $key eq 'Insert' ) { $ins = !$ins }
    elsif ( $key eq 'F1' ) { return 1 }
    elsif ( $ctrl == 8 || $ctrl == 127 ) {            # BACKSPACE
        backspaceat();
        moveleft(1);
    }
    elsif ( $ctrl == 13 || $ctrl == 10 ) {            # newline
        newlineat();
        movedown(1);
        $x = 0;
    }
    elsif ( $ctrl == 11 ) {                           # Ctrl+K
        delteol();
    }
    elsif ( $ctrl == 19 ) {                           # Ctrl+S
        save();
    }
    elsif ( $ctrl == 6 ) {                            # Ctrl+F
        search();
    }
    elsif ( $ctrl == 9 || ( $ctrl >= 32 && $ctrl != 127 ) ) {

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

sub search {
    $search = input('search') if ( !$search );
    my $found;
    for ( my $i = current_line_number() ; $i < get_nrlines() ; $i++ ) {
        $found = index( lc( $lines[$i] ), lc($search), $searchx );
        if ( $found != -1 ) {
            $x       = $found;
            $searchx = $found + 1;
            $y       = 0;
            $topline = $i;
            move();
            last;
        }
        else { $searchx = 0 }
    }
    if ( $found == -1 ) { movedown( get_nrlines() - current_line_number() ); $status = 'Reached end of file.'; $search = '' }
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
    my $end = substr( line(), $ins ? $x : $x + 1 );
    line( 0, $begin . $key . $end );
}

sub error {
    die "failed: @_";
}

sub clear {
    print "\e[2J";
}

sub header {
    absmove( 1, 1 );
    print inverse( ' ' x ( $cols - 1 ) );
    absmove( 1, 1 );

    print inverse( '|ped| ' . ( '+-------' x ( ( $cols - 7 ) / 8 ) ) );
}

sub footer {
    absmove( 1, $rows + 2 );
    print inverse( ' ' x ( $cols - 1 ) );
    absmove( 1, $rows + 2 );
    print inverse( '[' . ( $filename || 'Untitled' ) . ']' . ' ' . ( $status || '' ) );

    my $xy = 'HELP=F1 '
      . ( $dos ? 'DOS' : 'UNIX' ) . ' '
      . ( $ins ? 'INS' : '' ) . ' [ '
      . ( $x + 1 ) . '/'
      . ( length( line() ) + 1 ) . ':'
      . ( current_line_number() + 1 ) . '/'
      . get_nrlines() . ' ]';
    absmove( $cols - length2($xy), $rows + 2 );
    print inverse($xy);
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
        absmove( 1, $y + 2 );
        print "\e[K";
        drawline( current_line_number() );
    }
    else    # update screen
    {
        clear();
        header();
        absmove( 1, 2 );

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
    if ( $realx < $cols - 7 ) {
        $line = substr( $line, 0, $cols - 7 );
    }
    else {
        $line = substr( $line, $realx - ( $cols - 7 ), $cols - 7 );
    }

    my $posstring = sprintf( '%5d', $pos + 1 );
    print inverse($posstring) . ' ' . $line . "\r\n";
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
    print "\e[" . ( $y + 2 ) . ';' . ( $realx + 7 ) . 'f';
}

sub inverse {
    my ($text) = @_;
    return "\e[7m" . $text . "\e[m";
}

sub input {
    my ($text) = @_;
    absmove( 1, $rows + 2 );
    print inverse( ' ' x ( $cols - 1 ) );
    absmove( 1, $rows + 2 );
    print "\e[7m";
    print "$text: ";

    ReadMode(0);
    my $result = ReadLine();
    ReadMode(5);

    $result =~ s/\r?\n$//;

    print "\e[m";
    $forceupdate = 1;
    return $result;
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
    my $k = '';
    if (scalar(@buffer) == 1) { # to use ^[
      eval {
        local $SIG{ALRM} = sub { die };
        ualarm 300_000;
        read(STDIN, $k, 1);
        ualarm 0;
      };
      return shift @buffer if $@;
    }
    else { read(STDIN, $k, 1) }
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

sub ReadLine {
    return <STDIN>;
}

sub ReadMode {
    my ($mode) = @_;
    if ( $mode == 5 ) {
        $stty = `stty -g`;
        chomp($stty);
        system( 'stty', 'raw', '-echo' );
    }
    elsif ( $mode == 0 ) {
        system( 'stty', $stty );
    }
}
