% https://unix.stackexchange.com/questions/55423/ - how to change terminfo
\datethis
\input epsf

@s cchar_t int
@s delete normal @q unreserve a C++ keyword @>
@s new normal @q unreserve a C++ keyword @>

\font\emfont=manfnt
\def\EM/{{\emfont EM}}

@* Program.
EM is a text editor. It is implemented
using wide-character API and ncurses library.
This is the outline of the program.

@c
@<Header files@>@;
@<Typedef declarations@>@;
@<Global variables@>@;
@<Procedures@>@;
int main(int argc, char **argv)
{
  @<Initialize@>@;
  while (1) {
    @<Wait user input@>@;
    if (done) break;
    @<Update screen@>@;
  }
  @<Cleanup@>@;
  return 0;
}

@ @<Initialize@>=
  assert(argc == 1);

  setlocale(LC_CTYPE, "C.UTF-8");

  FILE *fp;
  @<Open file@>@;
  @<Read file@>@;
  @<Close file@>@;

  @<Ensure that restored position is inside buffer@>@;
  @<Set |eop| for proper positioning of cursor on screen@>@;

  assert(initscr() != NULL);
  nonl();
  raw();
  noecho();
  keypad(stdscr, TRUE);

  int lineno = atoi(getenv("line"));
  @<Move cursor to |lineno|@>@;

display();

@ @<Wait user input@>=
wchar_t c;
int ret = get_wch(&c);
if (ret == KEY_CODE_YES && c == KEY_RESIZE) ; /* TODO: if |point| (and hence the cursor) becomes
out of visible area, move it minimal distance that it becomes visible again; HINT: debug
|display| by using stty -F ... rows <decrease and increase by one to see the effect> */
@<\vb{Ctrl}+\vb{M}, \vb{ Enter }@>@;
@<\vb{Ctrl}+\vb{H}, \vb{ BackSpace }@>@;
@<\vb{Ctrl}+\vb{P}, \vb{ \char'13 \space}@>@;
@<\vb{Ctrl}+\vb{N}, \vb{ \char'1 \space}@>@;
@<\vb{Ctrl}+\vb{B}, \vb{ \char'30 \space}@>@;
@<\vb{Ctrl}+\vb{F}, \vb{ \char'31 \space}@>@;
@<\vb{Ctrl}+\vb{A}, \vb{ Home }@>@;
@<\vb{Ctrl}+\vb{E}, \vb{ End }@>@;
@<\vb{Ctrl}+\vb{D}, \vb{ Delete }@>@;
@<\vb{Ctrl}+\vb{I}, \vb{ Tab }@>@;
@<\vb{Ctrl}+\vb{Z}@>@;
if (ret == KEY_CODE_YES && c == KEY_F(1)) insert(L'\u00AB');
if (ret == KEY_CODE_YES && c == KEY_F(2)) insert(L'\u00BB');
if (ret == KEY_CODE_YES && c == KEY_F(12)) insert(L'\u2010');
if (ret == OK && c >= ' ') insert(c);

@ Update screen if user changed window size (including changing font
size) or the data or moved cursor.
@<Update screen@>=
display();

@ @<Cleanup@>=
endwin();

@* Buffer-gap algorithm. EM uses ``buffer-gap''
algorithm to represent a file in memory.

With a buffer gap, editing operations are achieved by moving the gap to
the place in the buffer where you want to make the change, and then
either by shrinking the size of the gap for insertions, or increasing the
size of the gap for deletions.  

When a file is loaded it is loaded with the gap at the bottom.
{\tt\obeylines
cccccccc
cccccccc
cccc....\par}
\noindent where |c| is a byte from the file and \.{.} is a byte in the gap.
As long as we just move around the memory we dont need to worry about the gap.
The current point is a long.  If we want the actual memory location we
use |pos| which converts to a memory pointer
and ensures that the gap is skipped at the right point.

When we need to insert chars or delete then the gap has to be moved to the
current position using |movegap|.
{\tt\obeylines
cccccccc
ccc....c
cccccccc\par}

Now we decide to delete the character at the current position, we just made the gap
1 char bigger, i.e., the gap pointer is decremented.
In effect nothing is thrown away.  The gap swallows up the deleted character.
{\tt\obeylines
cccccccc
cc.....c
cccccccc\par}

Insertion works the opposite way.
{\tt\obeylines
cccccccc
ccc....c
cccccccc\par}
\noindent Here we incremented the gap pointer on and put a byte in the new space where the gap
has just moved from.

When we insert we have to be a bit clever and make sure the gap is big enough to take the
paste. This is where |growgap| comes into play.

Actually, at the beginning of the insert routine there is a check
to make sure that there is room in the gap for more characters.  When the
gapsize is 0, it is necessary to realloc the entire buffer.
When we read in a file, we allocate enough memory for the entire
file, plus a chunk for the buffer gap.

@d CHUNK 8096L /* TODO: when it was 512 and I pasted from clipboard
  (or typed manually in one go) text of ~600 characters,
  program segfaulted; reproduce this again and determine the cause.
  HINT: make |CHUNK| 2 or 3 and use \.{gdb} */
@^TODO@>

@ @<Typedef declarations@>=
typedef long point_t;

@ @<Global...@>=
point_t point = 0;
point_t bop = 0;           /* beginning of page */
point_t eop = 0;          /* end of page */
wchar_t *bob = NULL;            /* beginning of buffer */
wchar_t *eob = NULL;           /* end of buffer */
wchar_t *bog = NULL;            /* beginning of gap */
wchar_t *eog = NULL;           /* end of gap */
int row;                /* cursor row */
int col;                /* cursor col */
bool buffer_modified = 0;

@ @<Global variables@>=
FILE *db; /* save cursor */
int done;

@ @d MSGBUF 512

@<Global variables@>=
wchar_t msgline[MSGBUF];
int msgflag;

@ Prepare |msgline| using format |msg|. In search mode
messages are treated specially.

@<Procedures@>=
void msg(wchar_t *msg, ...)
{
 va_list args;
 va_start(args, msg);
 vswprintf(msgline, sizeof msgline / sizeof (wchar_t), msg, args);
 va_end(args);
 msgflag = TRUE;
}

@ Search prompt is formatted in accordance with |case_sensitive_search_flag|.
If this flag is active, in search prompt all letters are uppercased.
If this flag is not active, in search prompt all letters are lowercased,
except first letters of words. The search prompt ends at the first occurrence
of character `\.:'.

@<Procedures@>=
void case_sensitive_search(int case_sensitive_search_flag)
{
  for (wchar_t *k = msgline; *k != L':'; k++)
    if (case_sensitive_search_flag)
      *k = towupper(*k);
    else if (k != msgline && *(k-1) != L' ')
      *k = towlower(*k);
}

@ Given a buffer offset, convert it to a pointer into the buffer.

@<Procedures@>=
wchar_t *ptr(point_t offset)
{
 return (bob+offset + (bob + offset < bog ? 0 : eog-bog));
}

@ Given a pointer into the buffer, convert it to a buffer offset.

@<Procedures@>=
point_t pos(wchar_t *cp)
{
 assert(bob <= cp && cp <= eob);
 assert(cp < bog || cp >= eog);
 if (cp < eog) assert(cp - bob >= 0);
 else assert(cp - bob - (eog - bog) >= 0);
 return (point_t) (cp - bob - (cp < eog ? 0 : eog - bog));
}

@ Enlarge gap by n chars, position of gap cannot change.
TODO: check that |(size_t)newlen*sizeof (wchar_t)| does not cause overflow.
@^TODO@>

$$\epsfbox{em.eps}$$

@<Procedures@>=
int growgap(point_t n)
{
 wchar_t *new;
 point_t buflen, newlen, xgap, xegap;
  
 assert(bob <= bog);
 assert(bog <= eog);
 assert(eog <= eob);

 xgap = (point_t) (bog - bob);
 xegap = (point_t) (eog - bob);
 buflen = (point_t) (eob - bob);
    
 @<Calculate new length |newlen| of gap@>@;
 @<Allocate memory for editing buffer@>@;
 @<Relocate pointers in new buffer and append the new
   extension to the end of the gap@>@;

 return TRUE;
}

@ Reduce number of reallocs by growing by a minimum amount.
TODO: check that |buflen + n| does not cause overflow.
@^TODO@>

@<Calculate new length...@>=
n = (n < CHUNK ? CHUNK : n);
newlen = buflen + n;

@ @<Allocate memory for editing buffer@>=
assert(newlen >= 0);
if (buflen == 0) /* if buffer is empty */
  new = malloc((size_t) newlen * sizeof (wchar_t));
else
  new = realloc(bob, (size_t) newlen * sizeof (wchar_t));
if (new == NULL) {
  msg(L"malloc: %m\n");
  return FALSE;
}

@ Below we consider the fact that the buffer-gap can only grow, i.e., |newlen|
is always greater than |buflen|.
In the |while| loop we move along the rightmost part of the ``old'' buffer, from right to
left, and move each element to the ``new'' buffer, also from right
to left. This can be regarded as ``shifting'' the rightmost part of the ``old'' buffer
to the right side of the ``new'' buffer.

@<Relocate pointers in new buffer and append the new
    extension to the end of the gap@>=
bob = new;
bog = bob + xgap;
eog = bob + newlen;
while (xegap < buflen--)
 *--eog = *--eob;
eob = bob + newlen;
assert(bob <= bog);
assert(bog < eog);          /* gap must exist */
assert(eog <= eob);

@ @<Procedures@>=
void movegap(offset)
 point_t offset; /* number of characters before the gap */
{
 wchar_t *p = ptr(offset);
 assert(p <= eob);
 while (p < bog)
  *--eog = *--bog;
 while (eog < p)
  *bog++ = *eog++;
 assert(bog <= eog);
 assert(bob <= bog);
 assert(eog <= eob);
}

@* File input/output.

@ @<Open file@>=
if ((fp = fopen(getenv("file"), "r+")) == NULL) printf("%m\n"), exit(EXIT_FAILURE);

@ @<Close file@>=
fclose(fp);

@*1 Saving buffer into file.

If the file is read-only, it is not written to.

TODO: if the file is not writable, create temporary file, write to it, and print its name
to stdout on exit.
@^TODO@>

We do |movegap(0)| before writing to file, so we only need to write data to the right of
the gap.

@<Save buffer@>=
FILE *fp;
point_t length;
if ((fp = fopen(getenv("file"), "w")) != NULL) {
  @<Add trailing newline to non-empty buffer if it is not present@>@;
  movegap(0);
  length = (point_t) (eob - eog);
  @<Write file@>@;
  fclose(fp);
}

@ If necessary, insert trailing newline into editing buffer before writing it to the file.
If gap size is zero and no more memory can be allocated, do not append the
newline.

@<Add trailing newline to non-empty buffer...@>=
movegap(pos(eob));
if (bob < bog && *(bog-1) != L'\n')
  if (bog != eog || growgap(1)) /* if gap size is zero, grow gap */
    *bog++ = L'\n';

@ We write file character-by-character for similar reasons which are explained in
|@<Read file@>|.
TODO: before saving check if file was modified since it was read and ask
if owerwrite must be done (see git lg here how asking was implemented earlier)
@^TODO@>

TODO: always remove file completely before saving and create it again with the same attributes.
This is necessary to be able to edit running scripts, debugging sessions, etc..;
this will do no harm in other cases, so do it always.
Use \.{a.sh} and \.{b.sh} check at \.{https://stackoverflow.com/questions/3398258/}
And do that if file was unchanged, just quit without doing anything to the file.
@^TODO@>

@<Write file@>=
for (point_t n = 0; n < length; n++) {
  fputwc(*(eog + n), fp);
  if (ferror(fp)) {
    msg(L"Failed to write file \"%s\".", getenv("file"));
    break;
  }
}

@*1 Reading file into buffer.

In this program we use wide-character editing buffer.
UTF-8 sequences from input file stream are automatically converted
to wide characters by C standard library function |fgetwc|.

To allocate memory for editing buffer, we need to know how many
chars are in input file. But this is impossible to know until
you read the whole file. So, we will use an estimate.

One way to estimate the required amount of memory for editing buffer
is to use the fact that the number of chars cannot be
greater than the number of bytes from which they were converted.
Using such an estimate, memory is wasted if the input file contains
multibyte sequence(s).

To waste less memory, we will allocate memory for editing buffer
chunk-by-chunk as we are reading the file. The chunk of chars
from input file is stored in buffer |buf| before being copied
to editing buffer.

@ @<Global...@>=
wchar_t buf[CHUNK]; /* we read the input into this array */
wchar_t *buf_end; /* where the next char goes */

@ @<Read file@>=
wchar_t c;
int i = 0;
while (1) {
  buf_end = buf;
  while (buf_end - buf < CHUNK) {
    c = fgetwc(fp);
    if (ferror(fp)) printf("File is not UTF-8\n"), exit(EXIT_FAILURE);
    if (feof(fp)) break;
    *buf_end++ = c;
  }
  if (buf_end == buf) break; /* end of file */
  @<Copy contents of |buf| to editing buffer@>@;
}
@<Add trailing newline to input from non-empty file if it is not present@>@;

@ @<Copy contents of |buf|...@>=
if (eog - bog < buf_end-buf && !growgap((point_t) (buf_end-buf))) { /* if gap size
    is not sufficient, grow gap */
  fclose(fp);
  printf("Failed to allocate required memory.\n"), exit(EXIT_FAILURE);
}
for (i = 0; i < buf_end-buf; i++)
  *bog++ = buf[i];

@ If necessary, append newline to editing buffer after reading the file.
If the file has zero length, newline is not appended.

@<Add trailing newline to input...@>=
if (i && buf[i-1] != L'\n') {
  *buf_end++ = L'\n';
  @<Copy contents of |buf|...@>@;
}

@*1 Procedures.

@ Reverse scan for beginning of real line containing offset.

@<Procedures@>=
point_t lnbegin(point_t off)
{
 if (off == 0) return off;
 do
   off--;
 while (0 < off && *ptr(off) != L'\n');
 return (0 < off ? ++off : 0);
}

@ Forward scan for end of real line containing offset.

@<Procedures@>=
point_t lnend(point_t off)
{
  if (off == pos(eob)) return off;
  wchar_t *p;
  do
    p = ptr(off++);
  while (eob > p && *p != L'\n');
  return (eob > p ? --off : pos(eob));
}

@ Forward scan for start of logical line segment containing `finish'.
In other words, forward scan for start of part of line in intervals of |COLS|,
which contains the point `finish'.

@<Procedures@>=
point_t segstart(point_t start, point_t finish)
{
 wchar_t *p;
 int c = 0;
 point_t scan = start;

 while (scan < finish) {
  p = ptr(scan);
  if (*p == '\n') {
   c = 0;
   start = scan+1;
  } else if (COLS <= c) {
   c = 0;
   start = scan;
  }
  ++scan;
  c += *p == '\t' ? 8 - (c & 7) : 1;
 }
 return (c < COLS ? start : finish);
}

@ Forward scan for start of logical line segment following `finish'.
In other words, forward scan for start of part of line in intervals of |COLS|,
which goes right
after that part of line, which contains the point `finish'.

@<Procedures@>=
point_t segnext(point_t start, point_t finish)
{
 wchar_t *p;
 int c = 0;

 point_t scan = segstart(start, finish);
 while (1) {
  p = ptr(scan);
  if (eob <= p || COLS <= c)
   break;
  scan++;
  if (*p == L'\n')
   break;
  c += *p == L'\t' ? 8 - (c & 7) : 1;
 }
 return (p < eob ? scan : pos(eob));
}

@ Find the beginning of previous line.
In other words, move up one screen line.

@<Procedures@>=
point_t upup(point_t off)
{
 point_t curr = lnbegin(off);
 point_t seg = segstart(curr, off);
 if (curr < seg)
  off = segstart(curr, seg>0?seg-1:0); /* previous line (is considered the
                  case that current line may be wrapped) */
 else
  off = segstart(lnbegin(curr>0?curr-1:0), curr>0?curr-1:0); /* previous
                  line (is considered the case that previous line may be wrapped) */
 return off;
}

@ Find the beginning of next line.
In other words, move down one screen line.

@<Procedures@>=
point_t dndn(point_t off)
{
 return segnext(lnbegin(off), off);
}

@ Return the offset of a column on the specified line.

@<Procedures@>=
point_t lncolumn(point_t offset, int column)
{
 int c = 0;
 wchar_t *p;
 while ((p = ptr(offset)) < eob && *p != L'\n' && c < column) {
  c += *p == L'\t' ? 8 - (c & 7) : 1;
  ++offset;
 }
 return offset;
}

@ FIXME: find out if using `addstr' in combination with `addwstr' can
be dangerous and use \hfil\break `addstr(getenv("file"));' between \\{move}
and \\{standend} instead of the `for' loop
(mixing addstr and addwstr may be dangerous --- like printf and wprintf)

@<Procedures@>=
void modeline(void)
{
  standout();
  move(LINES - 1, 0);
  for (int k = 0, @!len; k < strlen(getenv("file")); k += len) {
    wchar_t wc;
    len = mbtowc(&wc, getenv("file")+k, MB_CUR_MAX);
    cchar_t my_cchar;
    memset(&my_cchar, 0, sizeof my_cchar);
    my_cchar.chars[0] = wc;
    my_cchar.chars[1] = L'\0';
    add_wch(&my_cchar);
  }
  standend();
  clrtoeol();
}

@ There is indication of pre-existing search, which is done by hiding the cursor.

I decided to hide the cursor, because this way previous search text imitates ordinary
cursor\footnote*{it is supposed that ordinary cursor is not blinking}
% NOTE: disable cursor blinking in terminal which I will write
(with the distinction that
the ``new'' cursor may occupy more than one cell). This way it makes the intentions clear:
the search text can be entered as usual (i.e., as
if search was started without pre-existing search string), unless
C-s or C-r is pressed.

@<Procedures@>=
void dispmsg(void)
{
 if (msgflag) {
  move(LINES - 1, 0);
  standout();
  for(wchar_t *p=msgline; *p!=L'\0'; p++) {
   if (*p == L'\n')
     addwstr(L"<NL>");
   else if (*p == L'\x09')
     addwstr(L"<TAB>");
   else {
                          cchar_t my_cchar;
                          memset(&my_cchar, 0, sizeof my_cchar);
                          my_cchar.chars[0] = *p;
                          my_cchar.chars[1] = L'\0';
                          add_wch(&my_cchar);
   }
  }
  standend();
  clrtoeol();
  msgflag = FALSE;
 }
}

@* Redisplay algorithm. Here's how buffer gap redisplay algorithm works.

You need a new data structure to associate with a text object (e.g., an
emacs buffer).  Call it a span.  It's just like an emacs mark, except in
addition to a position, it has a (positive) length and a modified flag
associated with it.  When text is inserted or deleted in a buffer, all
the spans are updated accordingly.  That is, if the change occurs before
the span, the spans position is updated, but the length is left
unchanged.  If the change occurs AFTER the span (> pos + length) then the
span is unchanged.  If, however, a change occurs in the middle of a span,
that span is marked as dirty and the length is adjusted.  There are a few
other conditions, but that's the general idea.


First, a simple redisplay algorithm.  This doesn't do insert/delete line,
but it does handle wrapping lines at character or word bounderies.

The redisplay algorithm maintains one of those spans for each line in the
window.  Each line in the window is layed out and redrawn iff

 1) The span we used to represent this line has its modified flag
    set.

 2) The buffer position we have reached is different from what it
    was the last time we displayed this line, OR

1) happens when an insertion or deletion happened in that line, and 2)
happens when a change in a previous line causes a ripple through into
lower lines.  Most of the time, the redisplay only updates one line, the
one line that has the modified flag set.  But sometimes, that will ripple
down into other lines.  For instance, when a line first wraps the rest of
the screen will be redrawn because of 2) above.

Laying out a line basically means scanning through the buffer, one
character at a time, expanding tabs and Control characters until either a
Newline character is reached, or it's time to wrap the line.  Then it
sets the pos and length of the span representing that line, and returns
the buffer position that should be used for laying out the next line.  In
word wrap mode, it backs up to the last space character and returns the
first character after that.  In normal character wrapping mode, it just
returns the next character.

 [This is different from emacs fill mode, which inserts newlines
  into the document.  This new way doesn't insert newlines.  This
  is nice because the entire paragraph is always filled.  It's
  easy to make it so when you're typing in the middle of a HUGE
  word which wraps, and then type a space, the left half of the
  word might just pop up to the previous line if there is room.]

What's the overhead?  It's maintaining these spans.  It turns out editors
tend to maintain spans or marks for other reasons, so this isn't all that
big a deal.  And, maintaining them is pretty simple, compared to the
alternatives.  It's just a few integer comparisons and adjustments, and
it's a small drop in the bucket compared to lots of other things going on
in the editor.

So this gives you a nice redisplay algorithm, very snappy, not too smart
in that it won't do terminal insert/delete line kinds of things.  But,
that's not all that hard, now.  Remember, the hard part was figuring out
how to compare one line to another quickly.  In GNU and Gosling's
emacses, comparing lines is done by hashing on the contents and then using
the hash values.  In this new scheme, comparisons are done by buffer
positions, namely the position of the spans represented in each line.

This changes the above redisplay algorithm.  There now has to be a layout
phase, followed by a movelines phase, followed by a redraw phase.  The
layout phase re-layouts a line for reasons 1) and 2) above, then the the
movelines phase looks for ways to move lines around instead of redrawing
them.  And then the redraw phase goes through and redraws any lines that
didn't get fixed up by being moved around.

There are certain optimizations you can do in the layout phase, to cut
down on the amount of laying out you do.  For instance, if you find
yourself laying out a line because the position is different, you can do
a quick scan down the list of lines from the previous redisplay looking
for a line which began with that position after the last redisplay.  When
that's the case, you can just copy that layout info into the new line,
instead of recalculating it.

@<Procedures@>=
void display(void)
{
/* FIXME: when cursor is on bottom line (except when it is in the end of this line)
and C-m is pressed, the cursor goes
to new line but the page is not scrolled one line up as it should be;
make so that |down| will be called if character |L'\n'| is inserted and |point|
equals to |eop| */
@^FIXME@>
 wchar_t *p;
 int i, j, k;

 /* find start of screen, handle scroll up off page or top of file  */
 /* point is always within |bop| and |eop| */
 if (point < bop)
  bop = segstart(lnbegin(point), point);

 /* reframe when scrolled off bottom */
 if (eop <= point) {
  bop = dndn(point); /* find end of screen plus one */
  if (pos(eob) <= bop) { /* if we scoll to EOF we show 1
                  blank line at bottom of screen */
   bop = pos(eob);
   i = LINES - 2;
  }
  else
   i = LINES - 1;
  while (0 < i--) /* scan backwards the required number of lines */
   bop = upup(bop);
 }

 move(0, 0); /* start from top of window */
 i = 0;
 j = 0;
 eop = bop;
 
 /* paint screen from top of page until we hit maxline */ 
 while (1) {
  /* reached point - store the cursor position */
  if (point == eop) {
   row = i;
   col = j;
  }
  p = ptr(eop);
  if (LINES - 1 <= i || eob <= p) /* maxline */
   break;
  cchar_t my_cchar;
  memset(&my_cchar, 0, sizeof my_cchar);
  my_cchar.chars[0] = *p;
  my_cchar.chars[1] = L'\0';
  if (iswprint(*p) || *p == L'\t' || *p == L'\n') {
   j += *p == L'\t' ? 8-(j&7) : 1;
   add_wch(&my_cchar);
  }
  else {
   wchar_t *ctrl = wunctrl(&my_cchar);
   j += (int) wcslen(ctrl);
   addwstr(ctrl);
  }
  if (*p == L'\n' || COLS <= j) {
   j -= COLS;
   if (j < 0)
    j = 0;
   i++;
  }
  eop++;
 }

 /* replacement for clrtobot() to bottom of window */
 for (k=i; k < LINES - 1; k++) {
  move(k, j); /* clear from very last char not start of line */
  clrtoeol();
  j = 0; /* thereafter start of line */
 }

 modeline();
 dispmsg();
 move(row, col); /* set cursor */
 refresh(); /* update the real screen */
}

@ @<Procedures@>=
void left(void) @+ {@+ if (0 < point) point--; @+}
void right(void) @+ {@+ if (point < pos(eob)) point++; @+}
void up(void) @+ {@+ point = lncolumn(upup(point), col); @+}
void down(void) @+ {@+ point = lncolumn(dndn(point), col); @+}

@ @<Procedures@>=
void insert(wchar_t c)
{
 assert(bog <= eog);
 if (bog == eog && !growgap(CHUNK)) return; /* if gap size is zero,
          grow gap */
 movegap(point);
 *bog++ = c;
 point++;
 buffer_modified = 1;
}

@ @<Procedures@>=
void backsp(void)
{
 movegap(point);
 if (bob < bog)
  bog--;
 point = pos(eog);
 buffer_modified = 1;
}

@ @<Procedures@>=
void delete(void)
{
 movegap(point);
 if (eog < eob)
  point = pos(++eog);
 buffer_modified = 1;
}

@ We do this check because |point| may be set past the end of buffer if file is changed
externally.

But this check can only be done after the file is read, in order that the buffer
is allocated.

@<Ensure that restored...@>=
if (point > pos(eob)) point = pos(eob);

@ Set |eop| to maximum value.
This must be set after the file has been read, in order that the buffer is
allocated.

@<Set |eop| for proper positioning of cursor on screen@>=
eop=pos(eob);

@ This must be done after |initscr| in order that |COLS| will be initialized.

@<Move cursor to |lineno|@>= {
  for (point=0,lineno--; lineno>0; lineno--) {
    point = lnend(point);
    right();
  }
  @<Position cursor in the middle line of screen@>@;
}

@ @<Position cursor...@>=
bop=point;
for (int i=(LINES-1)/2;i>0;i--)
  bop=upup(bop);

@ @<\vb{Ctrl}+\vb{M}...@>=
if ((ret == OK && c == '\r') || (ret == KEY_CODE_YES && c == KEY_ENTER)) insert(L'\n');

@ @<\vb{Ctrl}+\vb{H}...@>=
if (ret == OK && c == 0x08) backsp();

@ @<\vb{Ctrl}+\vb{P}...@>=
if ((ret == OK && c == 0x10) || (ret == KEY_CODE_YES && c == KEY_UP)) up();

@ @<\vb{Ctrl}+\vb{N}...@>=
if ((ret == OK && c == 0x0e) || (ret == KEY_CODE_YES && c == KEY_DOWN)) down();

@ @<\vb{Ctrl}+\vb{B}...@>=
if ((ret == OK && c == 0x02) || (ret == KEY_CODE_YES && c == KEY_LEFT)) left();

@ @<\vb{Ctrl}+\vb{F}...@>=
if ((ret == OK && c == 0x06) || (ret == KEY_CODE_YES && c == KEY_RIGHT)) right();

@ @<\vb{Ctrl}+\vb{A}...@>=
if ((ret == OK && c == 0x01) || (ret == KEY_CODE_YES && c == KEY_HOME)) point = lnbegin(point);

@ @<\vb{Ctrl}+\vb{E}...@>=
if ((ret == OK && c == 0x05) || (ret == KEY_CODE_YES && c == KEY_END)) point = lnend(point);

@ @<\vb{Ctrl}+\vb{D}...@>=
if ((ret == OK && c == 0x04) || (ret == KEY_CODE_YES && c == KEY_DC)) delete();

@ @<\vb{Ctrl}+\vb{I}, \vb{ Tab }@>=
if (ret == OK && c == '\t') insert(L'\t');

@ Save and quit.
@<\vb{Ctrl}+\vb{Z}@>=
if (ret == OK && c == 0x1a) {
  @<Save buffer@>@;
  done = 1;
}

@ @<Header files@>=
#include <assert.h>
#include <errno.h>
#include <locale.h>
#include <ncursesw/curses.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <wchar.h>
#include <wctype.h>
