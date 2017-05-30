\let\lheader\rheader
\datethis

@s wint_t int @q this is an exception to make it work with original CWEB @>
@s ssize_t int @q this is an exception to make it work with original CWEB @>
@s delete normal @q this is an exception to make it work with original CWEB @>
@s new normal @q this is an exception to make it work with original CWEB @>
@s cchar_t int

@* Buffer-gap algorithm. EM is a text editor. It is implemented
using wide-character API and ncurses library. EM uses ``buffer-gap''
algorithm to represent file in memory. Following is the description
of how it works.

When a file is loaded it is loaded with the gap at the bottom.
{\tt\obeylines
ccccccc
ccccccc
cccc.....\par}
\noindent where |c| are the bytes in the file and \.{...} is the gap.
As long as we just move around the file we dont need to worry about the gap.
The current point is a long.  If we want the actual memory location we
use |pos| which converts to a memory pointer
and ensures that the gap is skipped at the right point.

When we need to insert chars or delete then the gap has to be moved to the
current position using |movegap|. SAY:
{\tt\obeylines
cccccccc
cccC.....c
cccccccc\par}

Now we decide to delete the character at the point (C) - we just made the gap
1 char bigger.  IE the gap pointer is decremented.
In effect nothing is thrown away.  The gap swallows up the deleted character.
{\tt\obeylines
cccccccc
ccc.......c
cccccccc\par}

Insertion works the opposite way.
{\tt\obeylines
cccccccc
cccY.....c
cccccccc\par}
\noindent Here we incremented the gap pointer on and put a Y in the new space when the gap
has just moved from.

When we paste we have to be a bit clever and make sure the GAP is big enough to take the
paste. This is where |growgap| comes into play.

----------------

Buffer gap is just one way to store a bunch of characters you wish to
edit.  (Another way is having a linked list of lines.)  Emacs uses the
buffer gap mechanism, and here is what a buffer looks like in emacs.

\.{<-----{ }first half{ }-----><-----{ }gap{ }-----><------{ }second half{ }------>}

An emacs buffer is just one huge array of characters, with a gap in the
middle.  There are no characters in the gap.  So at any given time the
buffer is described as the characters on the left side of the gap,
followed by the characters on the right side of the gap.

Why is there a gap?  Well if there isn't a gap and you want to insert one
character at the beginning of the buffer, you would have to copy all the
characters over to the right by one, and then stick in the character you
were inserting.  That's ridiculous, right?  Imagine editing a 100kbyte
file and inserting characters at the beginning.  The editor would be
spending the entire time copying characters over to the right one.
Delete would be done by copying characters to the left, just as slow.

With a buffer gap, editing operations are achieved by moving the gap to
the place in the buffer where you want to make the change, and then
either by shrinking the size of the gap for insertions, or increasing the
size of the gap for deletions.  In case it isn't obvious, this makes
insertion and deletion incredible simple to implement.  To insert a
character C at position POS in a buffer, you would do something like this:

	/* Move the gap to position POS.  That is, make the first half
	   be POS characters long. */
	BufferMoveGap(b, pos);
	b->data[b->firstHalf++] = c;
	b->gapSize -= 1;

There, done.  The gap is now one character smaller because we made the
first half bigger while sticking in the character we wished to insert.
Actually, at the beginning of the routine there should have been a check
to make sure that there is room in the gap for more characters.  When the
gapsize is 0, it is necessary to realloc the entire buffer.  Deletion is
even easier.  To delete N characters at POS, all you do is make the gap
bigger!  That is, by making the gap bigger, you take away from characters
that used to be part of the buffer.

	BufferMoveGap(b, pos);
	b->gapSize += n;

That is delete, folks.

Moving the gap is pretty trivial.  Just decide if you are moving it
forward or backward, and use bcopy.  bcopy is smart enough to handle
overlapping regions.

So, when emacs reads in a file it allocates enough memory for the entire
file, plus maybe 1024 bytes for the buffer gap.  Initially the buffer gap
is at the end of the file, so when you insert at the beginning of the
file right after reading it in, you will notice a longer delay than
usual, because it first has to move the gap to the beginning of the
file.  The gap only has to be moved when you are doing edit operations.

To examine the contents of a buffer, you can define a macro:

	BufferCharAt(b, pos)

All this does it check to see whether pos is in the first half or the
second half, and then index that one HUGE array of characters correctly.
It's surprisingly fast, actually.

Somebody mentioned that GNU search takes two strings to search in.  That
was Stallman's way of optimizing the hell out of the search.  The two
strings passed in represent the first half and the second half of the
buffer.  Now the search code does not have to use the BufferCharAt macro
to examine the buffer because it is guarunteed to have two contiguous
strings of valid data.  That's a good idea - I might have to adopt that
approach.

@* Gap Buffer Explained Again.

     The buffer gap method for storing data in an editor is not very
complicated.  The idea is to divide the file into two sections at the cursor
point, the location at which the next change will take place.  These sections
are placed at opposite ends of the buffer, with the "gap" in between them
representing the cursor point.  For example, here's a sixteen-character
buffer containing the words "The net", with the cursor on the letter 'n'.:

			The ---------net

(I'm using the '-' character to represent the spaces making up the gap.)

     Now, if you wanted to insert a character, all you must do is to add it
into one end or the other of the gap.  Conventional editors that move the
cursor left as you type would insert at the top edge of the gap.  For example,
if I wanted to change the word "net" to "Usenet", I would start by typing the
letter 'U', and the editor would change the buffer to look like this:

			The U--------net

     This represents the string "The Unet", with the cursor still on the 'n'.
Typing an 's' character would bring us to the following:

			The Us-------net

     And finally, the 'e' character brings us to this:

			The Use------net

     But now we decide that we want to completely change tack and change the
phrase from "The Usenet" to "The Usenix".  To do this, we will first have to
move our cursor to the right one spot, so we don't waste time retyping an
'n'.  To move the cursor point up and down through the file, we must move
letters "across" the gap.  In this case, we're moving the cursor toward the
end of the phrase, so we move the 'n' across the gap, to the top end.

			The Usen------et

     Now we're ready to delete the 'e' and the 't'.  To do this, we just
widen the gap at the bottom edge, wiping out the appropriate character.
After deleting the 'e', the buffer looks like this:

			The Usen-------t

     And after deleting the 't', the buffer looks like this:

			The Usen--------

     (Note that the gap now extends all the way to the edge of the buffer.
This means that the file now reads "The Usen", with the cursor at the very
end.)

     Backspacing works out to be something very similar to delete, with the
gap is widening at the top instead of the bottom.

     Now we add the letters 'i' and 'x', giving us the following buffer
snapshots after each key is pressed:

			The Useni-------

			The Usenix------

     Now we've made our changes.  Moving the cursor back to the top of the
file means moving the characters across the buffer in the other direction,
starting with the 'x', like this:

			The Useni------x

     Finally, after doing this once for each of the letters in the buffer,
we're at the top of the file, and the buffer looks like this:

			------The Usenix

     Of course, there are many details yet to consider.  Real buffers will be
much larger than this, probably starting at 64K and stopping at whatever size
is appropriate for the machine at hand.  In a real implementation, line breaks
have to be marked in some way.  My editor does this by simply inserting line
feed (\.{'\\n'}) characters into the buffer, but other approaches might be useful.
Moving the cursor up and down between lines can get complicated.  What about
virtual memory, so that we can fit the 21-letter phrase "The Usenix
Conference" in our 16-letter buffer? Then, of course, there's the question of
making the screen reflect the contents of the buffer, which is what my
original "Editor 102" post discussed.


     Hope this clears up the question of what a buffer gap is, and why it's
a convenient data structure to use in an editor.  There are, of course,
other ways to structure an editor's memory, with no clear victor.  All have
their strong points and weak points, so I picked the buffer gap for my
editor because of its simplicity and efficient use of memory.

@ This is the outline of our program.

@d B_MODIFIED 0x01 /* modified buffer */
@d CHUNK 8096L /* TODO: when it was 512 and I pasted from clipboard
  (or typed manually in one go) text of ~600 characters,
  program segfaulted; reproduce this again and determine the cause.
  HINT: make |CHUNK| 2 or 3 and use \.{gdb} */
@^TODO@>

@c
@<Header files@>@;
@<Typedef declarations@>@;
@<Global variables@>@;
@<Procedures@>@;
@<Main program@>@;

@ @<Typedef declarations@>=
typedef ssize_t point_t;

@ @<Global...@>=
point_t b_point = 0;          /* the point */
point_t b_page = 0;           /* start of page */
point_t b_epage = 0;          /* end of page */
wchar_t *b_buf = NULL;            /* start of buffer */
wchar_t *b_ebuf = NULL;           /* end of buffer */
wchar_t *b_gap = NULL;            /* start of gap */
wchar_t *b_egap = NULL;           /* end of gap */
int b_row;                /* cursor row */
int b_col;                /* cursor col */
char b_flags = 0;             /* buffer flags */

@ @<Global variables@>=
int done;

@ @<Procedures@>=
void fatal(wchar_t *msg, ...)
{
	va_list args;

	move(LINES-1, 0);
	refresh(); /* update the real screen */
	noraw();
	endwin(); /* end curses mode */

	va_start(args, msg);
	vwprintf(msg, args);
	va_end(args);
	exit(EXIT_FAILURE);
}

@ @d MSGBUF 512

@<Global variables@>=
wchar_t msgline[MSGBUF];
int msgflag;

@ Prepare |msgline| using format |msg|. In search mode
messages are treated specially.

@<Procedures@>=
#define search_msg(...) @,@,@, msg(__VA_ARGS__); @+ search_insert_mode(insert_mode);

void msg(wchar_t *msg, ...)
{
	va_list args;
	va_start(args, msg);
	vswprintf(msgline, ARRAY_SIZE(msgline), msg, args);
	va_end(args);
	msgflag = TRUE;
}

@ Search prompt is formatted in accordance with |insert_mode| (see
|@<Use Insert key as a switcher@>|).
If this mode is active, in search prompt all letters are uppercased.
If this mode is not active, in search prompt all letters are lowercased,
except first letters of words. The search prompt ends at the first occurrence
of character `\.:'.

@<Procedures@>=
void search_insert_mode(int insert_mode)
{
  for (wchar_t *k = msgline; *k != L':'; k++)
    if (insert_mode)
      *k = (wchar_t) towupper((wint_t) *k);
    else if (k != msgline && *(k-1) != L' ')
      *k = (wchar_t) towlower((wint_t) *k);
}

@ Given a buffer offset, convert it to a pointer into the buffer.

@<Procedures@>=
wchar_t *ptr(point_t offset)
{
	assert(offset >= 0);
/* TODO: use |size_t| typedef for |point_t| when you will find out why this |assert| fails
   sometimes; for this check all places where this function is called and see if wrong
   value can sneak in */
@^TODO@>
	return (b_buf+offset + (b_buf + offset < b_gap ? 0 : b_egap-b_gap));
}

@ Given a pointer into the buffer, convert it to a buffer offset.

@<Procedures@>=
point_t pos(wchar_t *cp)
{
	assert(b_buf <= cp && cp <= b_ebuf);
	assert(cp < b_gap || cp >= b_egap);
	return (cp - b_buf - (cp < b_egap ? 0 : b_egap - b_gap));
}

@ Enlarge gap by n chars, position of gap cannot change.
TODO: check that |(size_t)newlen*sizeof(wchar_t)| does not cause overflow.
@^TODO@>

$$\hbox to14.25cm{\vbox to2.75cm{\vss\special{
  psfile=buffer-gap.eps clip llx=0 lly=-1 urx=404 ury=77 rwi=4040}}\hss}$$

@<Procedures@>=
int growgap(point_t n)
{
	wchar_t *new;
	point_t buflen, newlen, xgap, xegap;
		
	assert(b_buf <= b_gap);
	assert(b_gap <= b_egap);
	assert(b_egap <= b_ebuf);

	xgap = b_gap - b_buf;
	xegap = b_egap - b_buf;
	buflen = b_ebuf - b_buf;
    
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
  new = malloc((size_t) newlen * sizeof(wchar_t));
else
  new = realloc(b_buf, (size_t) newlen * sizeof(wchar_t));
if (new == NULL) {
  msg(L"malloc: %s\n", strerror(errno));
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
b_buf = new;
b_gap = b_buf + xgap;
b_egap = b_buf + newlen;
while (xegap < buflen--)
	*--b_egap = *--b_ebuf;
b_ebuf = b_buf + newlen;
assert(b_buf <= b_gap);
assert(b_gap < b_egap);          /* gap must exist */
assert(b_egap <= b_ebuf);

@ @<Procedures@>=
void movegap(offset)
	point_t offset; /* number of characters before the gap */
{
	wchar_t *p = ptr(offset);
	assert(p <= b_ebuf);
	while (p < b_gap)
		*--b_egap = *--b_gap;
	while (b_egap < p)
		*b_gap++ = *b_egap++;
	assert(b_gap <= b_egap);
	assert(b_buf <= b_gap);
	assert(b_egap <= b_ebuf);
}

@ @<Procedures@>=
void quit(void)
{
  @<Save buffer@>@;
  @<Remove lock and save cursor@>@;
  done = 1;
}

@* File input/output.

@ Save file name into global variable |b_fname| in order that it will be
visible from procedures.

@<Global...@>=
char *b_fname;

@ @<Save file name@>=
b_fname=argv[1];

@ Get absolute name of opened file to use it in |DB_FILE|. For this we
use facilities provided by the OS---via |fopen| call. Then we use
|readlink| to get full path from \.{proc} filesystem by file descriptor.
@^system dependencies@>

@<Global...@>=
char b_absname[PATH_MAX+1];

@ @<Get absolute file name@>=
char tmpfname[PATH_MAX+1];
ssize_t r;
snprintf(tmpfname, ARRAY_SIZE(tmpfname), "/proc/self/fd/%d", fileno(fp));
if ((r=readlink(tmpfname, b_absname, ARRAY_SIZE(b_absname)-1))==-1)
  fatal(L"Could not get absolute path.\x0a");
b_absname[r]='\0';

@ TODO: if file does not exist, do not create it right away - create it only in
|@<Write file@>|.
@^TODO@>

@<Open file@>=
if ((fp = fopen(b_fname, "r")) == NULL)
  if ((fp = fopen(b_fname, "w")) == NULL) /* create file if it does not exist */
    fatal(L"Failed to open file \"%s\".\x0a", b_fname);

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
if ((fp = fopen(b_fname, "w")) != NULL) {
  if (fp == NULL) msg(L"Failed to open file \"%s\".", b_fname);
  @<Add trailing newline to non-empty buffer if it is not present@>@;
  movegap(0);
  length = (point_t) (b_ebuf - b_egap);
  @<Write file@>@;
  fclose(fp);
}

@ If necessary, insert trailing newline into editing buffer before writing it to the file.
If gap size is zero and no more memory can be allocated, do not append the
newline.

@<Add trailing newline to non-empty buffer...@>=
movegap(pos(b_ebuf));
if (b_buf < b_gap && *(b_gap-1) != L'\n')
  if (b_gap != b_egap || growgap(1)) /* if gap size is zero, grow gap */
    *b_gap++ = L'\n';

@ We write file character-by-character for similar reasons which are explained in
|@<Read file@>|.
TODO: before saving check if file was modified since it was read and ask
if owerwrite must be done (see git lg here how asking was implemented earlier)
@^TODO@>

@<Write file@>=
point_t n;
for (n = 0; n < length; n++)
  if (fputwc(*(b_egap + n), fp) == WEOF)
    break;
if (n != length)
  msg(L"Failed to write file \"%s\".", b_fname);

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

@ We read file byte-by-byte, instead of reading the entire file
into memory in one go (which is faster), because UTF-8 data must be
converted to wide-character representation. There is just no other
way to convert input data from UTF-8 than processing it byte-by-byte.
This is the necessary price to pay for using wide-character buffer.

@<Read file@>=
wint_t c;
int i = 0;
while (1) {
  buf_end = buf;
  while (buf_end - buf < CHUNK && (c = fgetwc(fp)) != WEOF)
    *buf_end++ = (wchar_t) c;
  if (buf_end == buf) break; /* end of file */
  @<Copy contents of |buf| to editing buffer@>@;
}
@<Add trailing newline to input from non-empty file if it is not present@>@;
b_flags = (char)~B_MODIFIED;

@ @<Copy contents of |buf|...@>=
if (b_egap - b_gap < buf_end-buf && !growgap(buf_end-buf)) { /* if gap size
    is not sufficient, grow gap */
  fclose(fp);
  @<Remove lock and save cursor@>@;
  fatal(L"Failed to allocate required memory.\n");
}
for (i = 0; i < buf_end-buf; i++)
  *b_gap++ = buf[i];

@ If necessary, append newline to editing buffer after reading the file.
If the file has zero length, newline is not appended.

@<Add trailing newline to input...@>=
if (i && buf[i-1] != L'\n') {
  *buf_end++ = L'\n';
  @<Copy contents of |buf|...@>@;
}

@*1 File locking. Locking file is necessary to indicate that this file is already
opened. Before we open a file, lock is created in |DB_FILE| in
|@<Restore cursor...@>| (which
in turn is executed right before the wanted file is opened). Upon exiting
the editor, lock is removed from |DB_FILE| in |@<Remove lock and save cursor@>|.

@ Reverse scan for beginning of real line containing offset.

@<Procedures@>=
point_t lnbegin(point_t off)
{
	assert(off >= 0);
	if (off == 0) return off;
	wchar_t *p;
	do
		p = ptr(--off);
	while (b_buf < p && *p != L'\x0A');
	return (b_buf < p ? ++off : 0);
}

@ Forward scan for end of real line containing offset.

@<Procedures@>=
point_t lnend(point_t off)
{
  if (off == pos(b_ebuf)) return off;
  wchar_t *p;
  do
    p = ptr(off++);
  while (b_ebuf > p && *p != L'\x0A');
  return (b_ebuf > p ? --off : pos(b_ebuf));
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
		if (b_ebuf <= p || COLS <= c)
			break;
		scan++;
		if (*p == L'\n')
			break;
		c += *p == L'\t' ? 8 - (c & 7) : 1;
	}
	return (p < b_ebuf ? scan : pos(b_ebuf));
}

@ Find the beginning of previous line.
In other words, move up one screen line.

@<Procedures@>=
point_t upup(point_t off)
{
	point_t curr = lnbegin(off);
	point_t seg = segstart(curr, off);
	if (curr < seg)
		off = segstart(curr, seg-1>=0?seg-1:0); /* previous line (is considered the
                  case that current line may be wrapped) */
	else
		off = segstart(lnbegin(curr-1>=0?curr-1:0), curr-1>=0?curr-1:0); /* previous
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
	while ((p = ptr(offset)) < b_ebuf && *p != L'\n' && c < column) {
		c += *p == L'\t' ? 8 - (c & 7) : 1;
		++offset;
	}
	return offset;
}

@ @<Procedures@>=
void modeline(void)
{
       standout();
       move(LINES - 1, 0);
       addstr(b_fname);
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
			if (*p == L'\x0A')
			  addwstr(L"<NL>");
			else {
                          cchar_t my_cchar;
                          memset(&my_cchar, 0, sizeof(my_cchar));
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
make so that |down| will be called if character |L'\x0A'| is inserted and |b_point|
equals to |b_epage| */
@^FIXME@>
	wchar_t *p;
	int i, j, k;

	/* find start of screen, handle scroll up off page or top of file  */
	/* point is always within |b_page| and |b_epage| */
	if (b_point < b_page)
		b_page = segstart(lnbegin(b_point), b_point);

	/* reframe when scrolled off bottom */
	if (b_epage <= b_point) {
		b_page = dndn(b_point); /* find end of screen plus one */
		if (pos(b_ebuf) <= b_page) { /* if we scoll to EOF we show 1
                  blank line at bottom of screen */
			b_page = pos(b_ebuf);
			i = LINES - 2;
		}
		else
			i = LINES - 1;
		while (0 < i--) /* scan backwards the required number of lines */
			b_page = upup(b_page);
	}

	move(0, 0); /* start from top of window */
	i = 0;
	j = 0;
	b_epage = b_page;
	
	/* paint screen from top of page until we hit maxline */ 
	while (1) {
		/* reached point - store the cursor position */
		if (b_point == b_epage) {
			b_row = i;
			b_col = j;
		}
                if (search_active && b_search_point!=b_point && b_point==b_epage)
		  b_point < b_search_point ? standout() : standend();
		if (search_active && b_search_point!=b_point && b_search_point==b_epage)
		  b_point < b_search_point ? standend() : standout();
		p = ptr(b_epage);
		if (LINES - 1 <= i || b_ebuf <= p) /* maxline */
			break;
		if (*p != L'\r') {
			cchar_t my_cchar;
			memset(&my_cchar, 0, sizeof(my_cchar));
			my_cchar.chars[0] = *p;
			my_cchar.chars[1] = L'\0';
			if (iswprint((wint_t) *p) || *p == L'\t' || *p == L'\n') {
				j += *p == L'\t' ? 8-(j&7) : 1;
                                add_wch(&my_cchar);
			}
			else {
				wchar_t *ctrl = wunctrl(&my_cchar);
				j += (int) wcslen(ctrl);
				addwstr(ctrl);
			}
		}
		if (*p == L'\n' || COLS <= j) {
			j -= COLS;
			if (j < 0)
				j = 0;
			i++;
		}
		b_epage++;
	}

	/* replacement for clrtobot() to bottom of window */
	for (k=i; k < LINES - 1; k++) {
		move(k, j); /* clear from very last char not start of line */
		clrtoeol();
		j = 0; /* thereafter start of line */
	}

	modeline();
	dispmsg();
        if (search_active) { /* override |b_row| and |b_col|, in order that cursor will be
                                put to msg line */
          b_row = LINES - 1;
          b_col = (int) wcslen(msgline);
        }
	move(b_row, b_col); /* set cursor */
	refresh(); /* update the real screen */
}

@ @<Procedures@>=
void top(void) {@+ b_point = 0; @+}
void bottom(void) {@+ b_epage = b_point = pos(b_ebuf); @+}
void left(void) {@+ if (0 < b_point) b_point--; @+}
void right(void) {@+ if (b_point < pos(b_ebuf)) b_point++; @+}
void up(void) {@+ b_point = lncolumn(upup(b_point), b_col); @+}
void down(void) {@+ b_point = lncolumn(dndn(b_point), b_col); @+}

@ @<Procedures@>=
void pgdown(void)
{
	b_page = b_point = upup(b_epage);
	while (0 < b_row--)
		down();
	b_epage = pos(b_ebuf);
}

@ @<Procedures@>=
void pgup(void)
{
	int i = LINES - 1;
	while (0 < --i) {
		b_page = upup(b_page);
		up();
	}
}

@ @<Procedures@>=
void insert(wchar_t c)
{
	assert(b_gap <= b_egap);
	if (b_gap == b_egap && !growgap(CHUNK)) return; /* if gap size is zero,
		grow gap */
	movegap(b_point);
	*b_gap++ = c;
	b_point++;
	b_flags = (char)B_MODIFIED;
}

@ @<Procedures@>=
void backsp(void)
{
	movegap(b_point);
	if (b_buf < b_gap)
		b_gap--;
	b_point = pos(b_egap);
	b_flags = (char)B_MODIFIED;
}

@ @<Procedures@>=
void delete(void)
{
	movegap(b_point);
	if (b_egap < b_ebuf)
		b_point = pos(++b_egap);
	b_flags = (char)B_MODIFIED;
}

@* Searching text.

@ Searching is wrapped. This works by simply resetting cursor position to the beginning of
buffer when search fails. Next time when search button is pressed, |b_point| will
hold value 0, thus search will start from the beginning of buffer. (Initially, |b_point|
holds current cursor position, so searching is started from this point.)

Besides, here we keep cursor position of last successful search in |search_point|---to
leave cursor there when we exit after failed search.

Also, if there are no occurrences of search text, we do not change cursor position from
which the search was started. To make this work, we save |b_point| only when we fail for the
first time. Use |search_failed| to track this.

And if the direction of search changes, |search_failed| must be reset.
If we did not handle this condition, there could appear, for example, this situation:
we start backward search at the beginning of buffer, get a
warning that backward search failed, then press forward search button with the same
search text (which we suppose does exist in the buffer), and immediately get a
warning that no occurrences were found.

On the other hand, if we already know that there are no occurrences, no need to
reset |search_failed| when direction is changed. Use |no_occurrences| to track this.

If |insert_mode| is active, search is case-sensitive, otherwise it is case-insensitive.
This is combined with |insert_mode| because case-sensivity works well in
conjunction with pasting from clipboard, and can be activated in manual search if the need arises
(by default search is case-insensitive).
For description of what is |insert_mode| see doc part of section
|@<Use Insert key as a switcher@>|.

@<Search forward@>=
if (direction==0&&!no_occurrences) search_failed=0; /* direction changed */
for (point_t p=b_point, @!end_p=pos(b_ebuf); p < end_p; p++) {
/* FIXME: if instead of |end_p| will be used |a| will it get into the index? */
@^FIXME@>
	point_t pp;
	wchar_t *s;
	for (s=searchtext, pp=p; (insert_mode ? *s == *ptr(pp) :
	  towlower((wint_t) *s) == towlower((wint_t) *ptr(pp))) &&
	  *s !=L'\0' && pp < end_p; s++, pp++) ;
	if (*s == L'\0') {
          b_point = pp;
          b_search_point = p;
          search_msg(L"Search Forward: %ls", searchtext);
          display();
          search_failed=0;
          goto search_forward;
	}
}
if (search_failed) {
  search_msg(L"No Occurrences: %ls", searchtext);
  no_occurrences=1;
}
else {
  search_msg(L"Failing Forward Search: %ls", searchtext);
  search_failed=1;
  search_point=b_point;
}
dispmsg();
b_point=0;
b_search_point=b_point;
@/@t\4@> search_forward:

@ The logic is analogous to |@<Search forward@>|.

@<Search backward@>=
if (direction==1&&!no_occurrences) search_failed=0; /* direction changed */
for (point_t p=b_point; p > 0;) {
	p--;
	point_t pp;
        wchar_t *s;
	for (s=searchtext, pp=p; (insert_mode ? *s == *ptr(pp) :
	  towlower((wint_t) *s) == towlower((wint_t) *ptr(pp))) &&
	  *s != L'\0' && pp >= 0; s++, pp++) ;
	if (*s == L'\0') {
          b_point = p;
          b_search_point = pp;
          search_msg(L"Search Backward: %ls", searchtext);
          display();
          search_failed=0;
          goto search_backward;
	}
}
if (search_failed) {
  search_msg(L"No Occurrences: %ls", searchtext);
  no_occurrences=1;
}
else {
  search_msg(L"Failing Backward Search: %ls", searchtext);
  search_failed=1;
  search_point=b_point;
}
dispmsg();
b_point=pos(b_ebuf);
b_search_point=b_point;
@/@t\4@> search_backward:

@ |search_active| is a flag, which is used in |dispmsg| for
special handling of msg line---when we are
typing search text, cursor must stay there until we exit search via C-g or C-m.
It is also used in |display| to make it possible to use |b_search_point!=b_point| check
is an indicator fi a match is found.

|b_search_point| is used to determine the other part of the word to highlight it,
and at the same time it is used as an indicator if a match was found, to determine
if highlighting must be done.

@d STRBUF_M 64

@<Global...@>=
wchar_t searchtext[STRBUF_M];
point_t b_search_point;
int search_active = 0;

@ FIXME: check what will be if we press C-s or C-r when there is no pre-existing search string
@^FIXME@>

FIXME: check what will be if we press C-m or C-g right after C-s or C-r, if there is
pre-existing search text
@^FIXME@>

@<Procedures@>=
void search(direction)
   int direction; /* 1 = forward; 0 = backward */
{
  int cpos = 0;
  wint_t c;
  point_t o_point = b_point;
  int search_failed = 0;
  point_t search_point;
  int no_occurrences = 0;
  int insert_mode = 0;

  search_active = 1;
  b_search_point = b_point;

  /* FIXME: check if |curs_set(0)| will work correctly in |KEY_RESIZE| event */
@^FIXME@>
  if (*searchtext == L'\0' || cpos != 0) {
    search_msg(L"Search %ls: ", direction==1?L"Forward":L"Backward");
  }
  else {
    search_msg(L"Search %ls: %ls", direction==1?L"Forward":L"Backward", searchtext);
    curs_set(0); /* make the ``real'' cursor invisible */
  }
  dispmsg();

  while (1) {
    refresh(); /* update the real screen */
    if (get_wch(&c) == KEY_CODE_YES) { /* the concept used here is explained in |@<Handle key@>| */
	switch (c) {
	  case KEY_RESIZE: /* integer promotion takes place in such cases */
		search_msg(L"Search %ls: %ls",
		  direction==1?L"Forward":L"Backward",searchtext);
		display();
		continue;
	  case KEY_BACKSPACE:
		@<BackSpace in search@>@;
		break;
	  case KEY_IC:
		@<Use Insert key as a switcher@>@;
		break;
/* TODO: implement |KEY_F(5)| and |KEY_F(6)| to search backward and forward */
@^TODO@>
	}
    }
    else {
	curs_set(1);
	switch (c) {
	    case
              L'\x0D': /* C-m */
			if (insert_mode) {
				c = L'\x0A'; /* integer promotion takes place in such cases */
				@<Add char to search text@>@;
				break;
			}
			if (search_failed) b_point = search_point;
			search_active = 0;
			return;
	    case
              L'\x07': /* C-g */
			b_point = o_point;
			search_active = 0;
			return;
	    case
		L'\x12': /* C-r */
			direction=0;
			cpos = (int) wcslen(searchtext); /* ``restore'' pre-existing search string */
			@<Search backward@>@;
			break;
	    case
		L'\x13': /* C-s */
			direction=1;
			cpos = (int) wcslen(searchtext); /* ``restore'' pre-existing search string */
			@<Search forward@>@;
			break;
	    case
		L'\x08': /* C-h */
		@<BackSpace in search@>@;
		break;
	    case
		L'\x0A': /* C-j */
                @<Add char to search text@>@;
                break;
	    default:
		if (iswcntrl(c)) break; /* ignore non-assigned control keys */
		@<Add char to search text@>@;
	}
    }
  }
}

@ @<BackSpace in search@>=
if (cpos == 0)
  continue;
searchtext[--cpos] = L'\0';
search_msg(L"Search %ls: %ls", direction==1?L"Forward":L"Backward",searchtext);
dispmsg();

@ @<Add char to search text@>=
if (cpos < STRBUF_M - 1) {
  searchtext[cpos++] = (wchar_t) c;
  searchtext[cpos] = L'\0';
  search_msg(L"Search %ls: %ls", direction==1?L"Forward":L"Backward",searchtext);
  dispmsg();
}

@ Normally, when you want to search newline, you press C-j in search
mode---this key sends code |0x0A|, which is duly inserted in search text.
When you want to paste searched text from clipboard, press Insert key
before the paste, and then after the paste---to restore normal behavior.
The matter is that code |0x0A| is automatically coverted to |0x0D| when text is
pasted from buffer. (This behavior is caused by window manager, or
gnome-terminal---I'm not sure exactly, and I don't know how to disable it;
maybe this may be even used as a feature---to type |0x0A| character in
search text the same way as you type it in ondinary text, i.e., by
pressing C-m key.) Insert key toggles the key which sends |L'\x0D'| between
adding |L'\x0A'| to search string and normal behavior, i.e., exiting the
search on the current spot.

The changes to search prompt made in |search_insert_mode|
are displayed immediately after Insert key is pressed.

@<Use Insert key as a switcher@>=
insert_mode =! insert_mode;
search_insert_mode(insert_mode);
msgflag = TRUE;
dispmsg();

@ @<Main program@>=
int main(int argc, char **argv)
{
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc == 1) fatal(L"TODO: create temporary file in tex_tmp (see file tmp in my bin)"
        "and upon exiting em, print the file contents to stdout, and remove file tmp in my bin\n");
/* HINT: take tmpfile stuff from mpxout.w from metapost source */
@^TODO@>

	int lineno;
	if (argc == 3) /* second argument is the line number to be shown when file is opened */
		if (sscanf (argv[2], "%d", &lineno) != 1)
		    fatal(L"error - line number not an integer\n");

	if (initscr() == NULL) exit(EXIT_FAILURE); /* start curses mode */

	FILE *fp;
	@<Save file name@>@;
	@<Open file@>@;
	@<Get absolute...@>@;
	@<Restore cursor from |DB_FILE|@>@;
	@<Read file@>@;
	@<Close file@>@;
	if (argc == 3) @<Move cursor to |lineno|@>@;
	else @<Ensure that restored position is inside buffer@>;
	@<Set |b_epage|...@>@;

        raw();
        noecho();
	nonl(); /* return proper value (|0x0d|) from |get_wch| for C-m and ENTER keys */
	@<Automatically interpret ANSI control sequences@>@;

	while (!done) {
		display();
		@<Handle key@>@;
	}

	move(LINES - 1, 0);
	refresh(); /* FIXME: why do we need this? Remove and check what will be. */
	noraw();
	endwin(); /* end curses mode */

	return 0;
}

@ Control sequences beginning with escape character (code |0x1b|) are generated by pressing
on certain buttons. Here are some examples of the identity between control code
sequences and keyboard buttons by which they are generated:
\medskip
{\bf Debian}, gnome-terminal (corresponding {\sl terminfo\/} capabilities are \.{home} and
\.{end}):
{\tt\obeylines\obeyspaces
|0x1B 0x5B 0x48 ==| Home
|0x1B 0x5B 0x46 ==| End
}
\smallskip
{\bf Ubuntu MATE}, mate-terminal (corresponding {\sl terminfo\/}
capabilities are \.{khome} and \.{kend}):
{\tt\obeylines\obeyspaces
|0x1B 0x4F 0x48 ==| Home
|0x1B 0x4F 0x46 ==| End
}
\medskip

On both of these systems \.{Home} and \.{End} keys are automatically translated into
``one-character'' codes |KEY_HOME| and
|KEY_END| respectively by {\sl ncurses}, which frees us from scanning input sequences manually
and looking them up in {\sl terminfo\/} database in the application (and also from
interpreting not very clear naming scheme in which \.{khome} is equivalent to \.{home},
etc.).
@^system dependencies@>

\.{Esc} key, like \.{F1}, is reserved for window manager and must not be used
in programs that I write. (Besides window manager, \.{Esc} key may be used in some
existing programs.)

TODO: run \.{showkey -a} and press \.{F10}, then find the generated sequence in the output
of \.{infocmp -1} to determine terminal capability, then find this capability in
\.{terminfo(5)} and by analogy see which capability must have \.{F13} and then find
the sequence for this capability in \.{infocmp -1} and bind this sequence to C-[
via xkb or something (ask on SO)
See this:
{\tt http://www.shallowsky.com/linux/noaltscreen.html} \hfil\break
{\tt http://collaboration.cmc.ec.gc.ca/science/rpn/biblio/ddj/Website/%
  \hfil\break\hbox to1em{}articles/SA/v04/i06/a3.htm} \hfil\break
{\tt http://www.ibb.net/~anne/keyboard.html}
@^TODO@>

@<Automatically interpret ANSI control sequences@>=
keypad(stdscr,TRUE);

@ DB file cannot have null char, so use |fgets|.
We will not use \\{fgetws} here, because the conversion
of file name from UTF-8 to unicode is not
necessary here and because it uses |char*|, not |char|, and |char*| is OK.

We use Linux, so just delete the file by |unlink| after we open it - then open a new file
with the same name and write the modified lines into the new file. We'll have two |FILE*|
variables.
@^system dependencies@>

@d DB_FILE "/tmp/em.db"
@d DB_LINE_SIZE 10000

@ @<Global...@>=
FILE *db_in, *db_out;
char db_line[DB_LINE_SIZE+1];

@ We do this before |@<Read file@>|, not after, because it is not necessary to free memory
before the call to |fatal|.

@<Restore cursor...@>=
if (getenv("SUDO_USER")!=NULL && getuid()!=0)
  fatal(L"DB_FILE must have ownership of default user, so it may be run under sudo only \
as root\x0A");
if ((db_in=fopen(DB_FILE,"a+"))==NULL) { /* |"a+"| creates empty file if it does not exist */
  fclose(fp);
  fatal(L"Could not open DB file in a+ mode: %s\n", strerror(errno));
}
unlink(DB_FILE);
if ((db_out=fopen(DB_FILE,"w"))==NULL) {
  fclose(fp);
  fclose(db_in);
  fatal(L"Could not open DB file for writing: %s\n", strerror(errno));
}
int file_is_locked = 0;
while (fgets(db_line, DB_LINE_SIZE+1, db_in) != NULL) {
  if (strncmp(db_line, b_absname, strlen(b_absname)) == 0) {
    /* FIXME: check that |strlen(b_absname)<DB_LINE_SIZE);| */
@^FIXME@>
      if (sscanf(db_line+strlen(b_absname), "%ld %ld", &b_point, &b_page) != 2)
        file_is_locked = 1;
    continue;
  }
  fprintf(db_out,"%s",db_line);
}
fclose(db_in);
fprintf(db_out,"%s lock\n",b_absname);
@<Assure correct ownership of |DB_FILE|@>@;
fclose(db_out);
if (file_is_locked)
  fatal(L"File is locked.\n");
/* FIXME: now this is printed when a directory is erroneously specified as the first
argument - make proper error message in such case */
@^FIXME@>

@ If the program is run under \.{sudo},
then after changing |DB_FILE| change its ownership back to the user who invoked \.{sudo}.

@<Assure...@>=
struct passwd *sudo;
if (getenv("SUDO_USER")!=NULL)
  if ((sudo=getpwnam(getenv("SUDO_USER")))!=NULL)
    fchown(fileno(db_out),sudo->pw_uid,sudo->pw_gid);

@ Consider this case: we open empty file, add string ``hello world'', then
exit without saving. The saved cursor position will be 11. Next time we open this
same empty file, |@<Restore cursor...@>| will set |b_point| past the end of buffer.

But this check can only be done after the file is read, in order that the buffer
is allocated.

TODO: instead of this check do this: if file is closed without saving and it was
changed after it was opened (|if (b_flags&(char)B_MODIFIED)|),
saved cursor position must be the same as it was read from |DB_FILE|.
@^TODO@>

@<Ensure that restored...@>=
if (b_point > pos(b_ebuf)) b_point = pos(b_ebuf);

@ Set |b_epage| to maximum value.
This must be set after the file has been read, in order that the buffer is
allocated.

@<Set |b_epage| for proper positioning of cursor on screen@>=
b_epage=pos(b_ebuf);

@ See |@<Restore cursor...@>| for the technique used here.

@<Remove lock and save cursor@>=
if ((db_in=fopen(DB_FILE,"r"))==NULL)
  fatal(L"Could not open DB file for reading: %s\n", strerror(errno));
unlink(DB_FILE);
if ((db_out=fopen(DB_FILE,"w"))==NULL) {
  fclose(db_in);
  fatal(L"Could not open DB file for writing: %s\n", strerror(errno));
}
while (fgets(db_line, DB_LINE_SIZE+1, db_in) != NULL) {
  if (strncmp(db_line, b_absname, strlen(b_absname)) == 0)
    continue;
  fprintf(db_out,"%s",db_line);
}
fclose(db_in);
if (strstr(b_absname,"COMMIT_EDITMSG")==NULL)
  fprintf(db_out,"%s %ld %ld\n",b_absname,b_point,b_page);
@<Assure...@>@;
fclose(db_out);

@ @<Move cursor to |lineno|@>= {
  for (b_point=0,lineno--; lineno>0; lineno--) {
    b_point = lnend(b_point);
    right();
  }
  @<Position cursor in the middle line of screen@>@;
}

@ @<Position cursor...@>=
b_page=b_point;
for (int i=(LINES-1)/2;i>0;i--)
  b_page=upup(b_page);

@ Here, besides reading user input, we handle resize event. We pass
reference to variable of type
|wint_t| to |get_wch| instead of type |wchar_t|, because |get_wch| takes
|wint_t *| argument. While this would have been possible to typecast
|wchar_t| to |wint_t|, this is impossible to typecast pointer. So, we
have to use the variable of type |wint_t|. Why ncurses authors decided to use |wint_t *|
instead of |wchar_t *| as the argument? Answer:
because |wchar_t| may be |typedef| for |char|, and we need to store the special code,
which will not fit into |wchar_t| in such case. So, |wint_t| is necassary.
For |get_wch| it was
decided not to use |wint_t| for return value to store the special code (like it is in \\{getch})
because each implementation has its own sizes for |wint_t| and |wchar_t|, so
it is impossible to have a constant to store the special code (except |WEOF|).
And it is good to keep the same values for |KEY_RESIZE| etc which are used for
\\{getch} anyway.
So, they decided to distinguish via the return value
if |get_wch| passed a special code or a char, for which |int| is good. The return value is
|KEY_CODE_YES| if a special code is passed in the argument.

@<Handle key@>=
wint_t c;
if (get_wch(&c) == KEY_CODE_YES) {
  switch (c) {
    case KEY_RESIZE: /* integer promotion takes place in such cases */
	continue;
    case KEY_LEFT:
        left();
        break;
    case KEY_RIGHT:
        right();
        break;
    case KEY_UP:
        up();
        break;
    case KEY_DOWN:
        down();
        break;
    case KEY_HOME:
        b_point = lnbegin(b_point);
        break;
    case KEY_END:
        b_point = lnend(b_point);
        break;
    case KEY_NPAGE:
        pgdown();
        break;
    case KEY_PPAGE:
        pgup();
        break;
    case KEY_DC:
        delete();
        break;
    case KEY_BACKSPACE:
        backsp();
        break;
    case KEY_F(1): /* TODO: find out how to disable this key in GNOME */
@^TODO@>
	top();
	break;
    case KEY_F(2):
	bottom();
	break;
    case KEY_F(5):
	search(0);
	break;
    case KEY_F(6):
	search(1);
	break;
    case KEY_F(11):
	/* TODO: check via cweb/ncurses-test.w if |KEY_F(13)| will match Ctrl+F1 and use those */
@^TODO@>
	break;
    case KEY_F(12):
	quit();
	break;
    default:
	msg(L"Not bound");
  }
}
else {
  switch (c) {
	case
		L'\x18': /* C-x */
#if 1==0
		@<Remove lock and save cursor@>@;
		done = 1; /* quit without saving */
#endif
		break;
	case
		L'\x12': /* C-r */
		search(0);
		break;
	case
		L'\x13': /* C-s */
		search(1);
		break;
	case
		L'\x10': /* C-p */
		up();
		break;
	case
		L'\x0e': /* C-n */
		down();
		break;
	case
		L'\x02': /* C-b */
		left();
		break;
	case
		L'\x06': /* C-f */
		right();
		break;
	case
		L'\x05': /* C-e */
		b_point = lnend(b_point);
		break;
	case
		L'\x01': /* C-a */
		b_point = lnbegin(b_point);
		break;
	case
		L'\x04': /* C-d */
		delete();
		break;
	case
		L'\x08': /* C-h */
		backsp();
		break;
	case
		L'\x1D': /* C-] */
		pgup();
		break;
	case
		L'\x16': /* C-v */
		pgdown();
		break;
	case
		L'\x1a': /* C-z */
		quit();
		break;
	case
		L'\x0d': /* C-m */
		insert(L'\x0a');
		break;
	default:
		insert((wchar_t) c);
  }
}

@ Utility macros.

@d ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))

@ @<Header files@>=
/* TODO: sort alphabetically */
@^TODO@>
#include <stdlib.h> /* |malloc|, |exit|, |EXIT_FAILURE|, |free|, |realloc|, |getenv| */
#include <stdarg.h> /* |va_end|, |va_start| */
#include <assert.h> /* |assert| */
#include <ncursesw/curses.h> /* |add_wch|, |addwstr|, |chars|, |clrtoeol|, |COLS|, |endwin|,
  |ERR|, |FALSE|, |get_wch|, |initscr|, |keypad|, |KEY_BACKSPACE|, |KEY_RESIZE|,
  |KEY_BACKSPACE|, |KEY_RESIZE|, |KEY_LEFT|, |KEY_RIGHT|, |KEY_UP|, |KEY_DOWN|, |KEY_HOME|,
  |KEY_END|, |KEY_NPAGE|, |KEY_PPAGE|, |KEY_DC|, |KEY_BACKSPACE|, |LINES|, |move|, |noecho|,
  |nonl|, |noraw|, |OK|, |raw|, |refresh|, |standend|, |standout|, |stdscr|, |TRUE|, |wunctrl|,
  |KEY_CODE_YES|, |cchar_t| */
#include <pwd.h> /* |struct passwd|, |pw_uid|, |pw_gid|, |getpwnam| */
#include <stdio.h> /* |fclose|, |fgets|, |fileno|, |snprintf|, |fopen|, |fprintf|, |sscanf| */
#include <locale.h> /* |LC_CTYPE|, |setlocale| */
#include <wchar.h> /* |fgetwc|, |fputwc|, |vswprintf|, |vwprintf|, |wcslen|, |WEOF| */
#include <wctype.h> /* |iswprint| */
#include <string.h> /* |strerror|, |strncmp|, |memset|, |strlen|, |strstr| */
#include <errno.h> /* |errno| */
#include <limits.h> /* |PATH_MAX| */
#include <unistd.h> /* |unlink|, |readlink|, |fchown|, |getuid| */

@* Index.
