use strict;
$|++;

binmode(STDIN, ':utf8');
binmode(STDOUT, ':utf8');

my @keys = (
  { desc => "F1", bytes => "\eOP" },
  { desc => "F2", bytes => "\eOQ" },
  { desc => "up", bytes => "\e[A" },
  { desc => "down", bytes => "\e[B" },
  { desc => "right", bytes => "\e[C" },
  { desc => "left", bytes => "\e[D" }
);

my @buffer = ();
my $done = 0;
KEY:
while (!$done) {
  # if recorded bytes remain, return next recorded byte
  if (scalar @buffer) {
    my $b = shift @buffer;
    my $n = ord($b);
    if (($n >= 32 && $n < 127) || $n > 127) { print $b }
    elsif ( $n == 8 ) { print "BS" }
    elsif ( $n == 9 ) { print "TAB" }
    elsif ( $n == 13 ) { print "LF" }
    elsif ( $n == 26 ) { $done = 1 } # ^Z
    elsif ( $n == 27 ) { print "ESC" }
    else { print "NOT BOUND" }
    next KEY;
  }
  my $submatch;
  do {
    my $key = '';
    if (scalar @buffer) {
      eval {
        local $SIG{ALRM} = sub { die }; 
        alarm 1; # ualarm 300000; # 0.3 seconds
        read(STDIN, $key, 1);
        alarm 0; # ualarm 0;
      };
      next KEY if $@;
    }
    else { read(STDIN, $key, 1) }
    push @buffer, $key;
    $submatch = 0;           
    for (my $k = 0; $k <= $#keys; $k++) {
      my $i = 0;
      while (1) {
        last if $i > scalar(@buffer) || $i > length($keys[$k]{bytes});
        if ($i == scalar(@buffer) && $i == length($keys[$k]{bytes})) {
          @buffer = ();
          print "\e[2J";
          print "\e[1;1f";
          print $keys[$k]{desc};
          next KEY;
        }
        last if $i == scalar(@buffer) || $i == length($keys[$k]{bytes});
        last if $buffer[$i] ne substr($keys[$k]{bytes}, $i, 1);
        $i++;
      }
      $submatch = 1 if $i == scalar(@buffer) && $i != length($keys[$k]{bytes});
    }
  } while ($submatch);
}
