sub prnt ($)
{
  print "\e[2J";
  print "\e[1;1f";
  print shift;
}

$|++;

my @keys = (
  [ "F1",                      "\eOP"  ],
  [ "F2",                      "\eOQ"  ],
  [ "up previous-line",        "\e[A"  ],
  [ "down next-line",          "\e[B"  ],
  [ "left backward-character", "\e[D"  ],
  [ "right forward-character", "\e[C"  ],
  [ "home beginning-of-line",  "\e[H"  ],
  [ "end end-of-line",         "\e[F"  ],
  [ "DEL forward-delete-char", "\e[3~" ],
  [ "PgUp",                    "\e[5~" ],
  [ "PgDn",                    "\e[6~" ]
);

my @buffer = ();
my $done = 0;
KEY:
while (!$done) {
  # if recorded bytes remain, handle next recorded byte
  if (scalar @buffer) {
    if (scalar(@buffer) > 1) {
      prnt 'NOT BOUND';
      @buffer = ();
    }
    else {
      my $k = shift @buffer;
      if (ord($k) == ord('A') - 0100) { prnt 'beginning_of_line' }
      elsif (ord($k) == ord('B') - 0100) { prnt 'left' }
      elsif (ord($k) == ord('D') - 0100) { prnt 'delete' }
      elsif (ord($k) == ord('E') - 0100) { prnt 'end_of_line' }
      elsif (ord($k) == ord('F') - 0100) { prnt 'right' }
      elsif ($k eq "\b") { prnt "BS" }
      elsif ($k eq "\t") { prnt "TAB" }
      elsif ($k eq "\r") { prnt "RETURN" }
      elsif (ord($k) == ord('N') - 0100) { prnt 'down' }
      elsif (ord($k) == ord('P') - 0100) { prnt 'up' }
      elsif (ord($k) == ord('V') - 0100) { prnt 'pgdown' }
      elsif (ord($k) == ord('Z') - 0100) { $done = 1 }
      elsif ($k eq "\e") { prnt "ESC" }
      elsif (ord($k) >= 32 && ord($k) != 127) { prnt $k }
      else { prnt 'NOT BOUND' }
    }
    next KEY;
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
      next KEY if $@;
    }
    else { read(STDIN, $k, 1) }
    push @buffer, $k;
    $submatch = 0;           
    for my $key (@keys) {
      my $i = 0;
      while (1) {
        if ($i == scalar(@buffer) && $i == length($$key[1])) {
          @buffer = ();
          prnt $$key[0];
          next KEY;
        }
        last if $i == scalar(@buffer) || $i == length($$key[1]);
        last if $buffer[$i] ne substr($$key[1], $i, 1);
        $i++;
      }
      $submatch = 1 if $i == scalar(@buffer) && $i < length($$key[1]);
    }
  } while ($submatch);
}
