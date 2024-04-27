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

my $done = 0;

sub get_key()
{
  my @buffer = ();
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
      goto KEY if $@;
    }
    else { read(STDIN, $k, 1) }
    push @buffer, $k;
    $submatch = 0;           
    for my $key (@keys) {
      my $i = 0;
      while (1) {
        if ($i == scalar(@buffer) && $i == length($$key[1])) {
          return $$key[0];
        }
        last if $i == scalar(@buffer) || $i == length($$key[1]);
        last if $buffer[$i] ne substr($$key[1], $i, 1);
        $i++;
      }
      $submatch = 1 if $i == scalar(@buffer) && $i < length($$key[1]);
    }
  } while ($submatch);

KEY:
  if (scalar(@buffer) > 1) {
    return 'NOT BOUND';
  }
  else {
    my $k = shift @buffer;
    if (ord($k) == ord('A') - 0100) { return 'beginning_of_line' }
    elsif (ord($k) == ord('B') - 0100) { return 'left' }
    elsif (ord($k) == ord('D') - 0100) { return 'delete' }
    elsif (ord($k) == ord('E') - 0100) { return 'end_of_line' }
    elsif (ord($k) == ord('F') - 0100) { return 'right' }
    elsif ($k eq "\b") { return "BS" }
    elsif ($k eq "\t") { return "TAB" }
    elsif ($k eq "\r") { return "RETURN" }
    elsif (ord($k) == ord('N') - 0100) { return 'down' }
    elsif (ord($k) == ord('P') - 0100) { return 'up' }
    elsif (ord($k) == ord('V') - 0100) { return 'pgdown' }
    elsif (ord($k) == ord('Z') - 0100) { $done = 1 }
    elsif ($k eq "\e") { return "ESC" }
    elsif (ord($k) >= 32 && ord($k) != 127) { return $k }
    else { return 'NOT BOUND' }
  }
}

$|++;

while (1) {
  my $input = get_key();
  last if $done;
  print "\e[2J";
  print "\e[1;1f";
  print $input;
}
