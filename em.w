\let\lheader\rheader
\datethis

@s delete normal
@s new normal

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

|<----- first half -----><----- gap -----><------ second half ------>|

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

@d MSGLINE         (LINES-1)
@d TEMPBUF         512
@d CHUNK  512
@d STRBUF_M        64

@c
@<Header files@>@;
@<Typedef declarations@>@;
@<Global variables@>@;
@<Procedures@>@;
@<Main program@>@;

@ @s point_t int
@s buffer_t int

@<Typedef declarations@>=
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

@ @<Global variables@>=
int done;
int msgflag;
point_t nscrap = 0;
wchar_t *scrap = NULL;

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

@ @<Global variables@>=
wchar_t msgline[TEMPBUF];

@ @<Procedures@>=
void msg(wchar_t *msg, ...)
{
	va_list args;
	va_start(args, msg);
	vswprintf(msgline, ARRAY_SIZE(msgline), msg, args);
	va_end(args);
	msgflag = TRUE;
}

@ Given a buffer offset, convert it to a pointer into the buffer.

FIXME: for what is |register|?
@^FIXME@>

@<Procedures@>=
wchar_t *ptr(register point_t offset)
{
	assert(offset >= 0);
/* TODO: use |size_t| typedef for |point_t| if this |assert| will not fail - some testing is
needed */
@^TODO@>
	return (b_buf+offset + (b_buf + offset < b_gap ? 0 : b_egap-b_gap));
}

@ Given a pointer into the buffer, convert it to a buffer offset.

@<Procedures@>=
point_t pos(register wchar_t *cp)
{
	assert(b_buf <= cp && cp <= b_ebuf);
	assert(cp < b_gap || cp >= b_egap);
	return (cp - b_buf - (cp < b_egap ? 0 : b_egap - b_gap));
}

@ Enlarge gap by n chars, position of gap cannot change.
TODO: check that |(size_t)newlen*sizeof(wchar_t)| does not cause overflow.
@^TODO@>
\medskip
\centerline{\hbox to14.225cm{\vbox to2.7cm{\vss\special{psfile=buffer-gap.eps}}\hss}}
\medskip

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

@ @<Header files@>=
#include <stdlib.h> /* |malloc| */
#include <string.h> /* |strerror| */
#include <errno.h> /* |errno| */

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

@<Header files@>=
#include <stdio.h> /* |snprintf|, |fopen|, |fclose|, |fileno| */
#include <limits.h> /* |PATH_MAX| */
#include <unistd.h> /* |readlink| */

@ @<Global...@>=
char b_absname[PATH_MAX+1];

@ @<Get absolute file name@>=
char tmpfname[PATH_MAX+1];
ssize_t r;
snprintf(tmpfname, ARRAY_SIZE(tmpfname), "/proc/self/fd/%d", fileno(fp));
if ((r=readlink(tmpfname, b_absname, ARRAY_SIZE(b_absname)-1))==-1)
  fatal(L"Could not get absolute path.\x0a");
b_absname[r]='\0';

@ @<Open file@>=
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
opened. Before we open a file, lock is created in |BD_FILE| in
|@<Restore cursor@>| (which
in turn is executed right before the wanted file is opened). Upon exiting
the editor, lock is removed from |DB_FILE| in |@<Remove lock and save cursor@>|.

@ Reverse scan for start of logical line containing offset.

@<Procedures@>=
point_t lnstart(register point_t off)
{
	assert(off >= 0);
	if (off == 0) return 0;
	register wchar_t *p;
	do
		p = ptr(--off);
	while (b_buf < p && *p != L'\n');
	return (b_buf < p ? ++off : 0);
}

@ Forward scan for start of logical line segment containing `finish'.

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

@<Procedures@>=
point_t segnext(point_t start, point_t finish)
{
	wchar_t *p;
	int c = 0;

	point_t scan = segstart(start, finish);
	for (;;) {
		p = ptr(scan);
		if (b_ebuf <= p || COLS <= c)
			break;
		++scan;
		if (*p == L'\n')
			break;
		c += *p == L'\t' ? 8 - (c & 7) : 1;
	}
	return (p < b_ebuf ? scan : pos(b_ebuf));
}

@ Move up one screen line.

@<Procedures@>=
point_t upup(point_t off)
{
	point_t curr = lnstart(off);
	point_t seg = segstart(curr, off);
	if (curr < seg)
		off = segstart(curr, seg-1);
	else
		off = segstart(lnstart(curr-1>=0?curr-1:0), curr-1);
	return off;
}

@ Move down one screen line.

@<Procedures@>=
point_t dndn(point_t off)
{
	return segnext(lnstart(off), off);
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

@ @<Global variables@>=
wchar_t temp[TEMPBUF];

@ @<Procedures@>=
void dispmsg()
{
	if (msgflag) {
		standout();
		move(MSGLINE, 0);
		for(wchar_t *k=msgline; *k!=L'\0'; k++) {
                        cchar_t my_cchar;
                        memset(&my_cchar, 0, sizeof(my_cchar));
                        my_cchar.chars[0] = *k;
                        my_cchar.chars[1] = L'\0';
                        if (iswprint((wint_t) *k))
                                add_wch(&my_cchar);
                        else {
                                wchar_t *ctrl = wunctrl(&my_cchar);
                                addwstr(ctrl);
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

@s cchar_t int

@<Procedures@>=
void display()
{
	wchar_t *p;
	int i, j, k;

	@<Set number of rows@>@;
	
	/* find start of screen, handle scroll up off page or top of file  */
	/* point is always within |b_page| and |b_epage| */
	if (b_point < b_page)
		b_page = segstart(lnstart(b_point), b_point);

	/* reframe when scrolled off bottom */
	if (b_epage <= b_point) {
		b_page = dndn(b_point); /* find end of screen plus one */
		if (pos(b_ebuf) <= b_page) { /* if we scoll to EOF we show 1
                  blank line at bottom of screen */
			b_page = pos(b_ebuf);
			i = rows - 1;
		}
		else
			i = rows - 0;
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
		p = ptr(b_epage);
		if (rows <= i || b_ebuf <= p) /* maxline */
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
	for (k=i; k < rows; k++) {
		move(k, j); /* clear from very last char not start of line */
		clrtoeol();
		j = 0; /* thereafter start of line */
	}

	dispmsg();
	move(b_row, b_col); /* set cursor */
	refresh(); /* update the real screen */
}

@ The number of lines in window |LINES| is automatically set by {\sl ncurses\/}
library. We maintain our own variable to be able to reduce number of lines if
a message is to be displayed.

@<Set number of rows@>=
int rows;
if (msgflag) rows = LINES - 1;
else rows = LINES;

@ @<Procedures@>=
void top(void) {@+ b_point = 0; @+}
void bottom(void) {@+ b_epage = b_point = pos(b_ebuf); @+}
void left(void) {@+ if (0 < b_point) b_point--; @+}
void right(void) {@+ if (b_point < pos(b_ebuf)) b_point++; @+}
void up(void) {@+ b_point = lncolumn(upup(b_point), b_col); @+}
void down(void) {@+ b_point = lncolumn(dndn(b_point), b_col); @+}
void lnbegin(void) {@+ b_point = segstart(lnstart(b_point), b_point); @+}

@ @<Procedures@>=
void lnend(void)
{
	b_point = dndn(b_point);
	left();
}

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
void insert(wchar_t input)
{
	assert(b_gap <= b_egap);
	if (b_gap == b_egap && !growgap(CHUNK)) return; /* if gap size is zero,
		grow gap */
	movegap(b_point);
	*b_gap++ = input;
	b_point++;
}

@ @<Procedures@>=
void backsp(void)
{
	movegap(b_point);
	if (b_buf < b_gap)
		b_gap--;
	b_point = pos(b_egap);
}

@ @<Procedures@>=
void delete(void)
{
	movegap(b_point);
	if (b_egap < b_ebuf)
		b_point = pos(++b_egap);
}

@ @<Procedures@>=
void open_line(void)
{
  msg(L"open_line() not implemented yet");
}

@ @<Search forward@>=
if (!search_failed) search_point=b_point; /* do not save point on further attempts to search
  if they will fail again */
search_failed=0;
for (point_t p=b_point, end_p=pos(b_ebuf); p < end_p; p++) {
	point_t pp;
	wchar_t *s;
	for (s=searchtext, pp=p; *s == *ptr(pp) && *s !=L'\0' && pp < end_p; s++, pp++) ;
	if (*s == L'\0') {
          b_point = pp;
          msg(L"Search: %ls", searchtext);
          display();
          goto forward_search;
	}
}
msg(L"Failing Forward Search: %ls", searchtext);
dispmsg();
search_failed=1;
b_point=0;
@/@t\4@> forward_search:

@ @<Search backward@>=
if (!search_failed) search_point=b_point; /* do not save point on further attempts to search
  if they will fail again */
search_failed=0;
for (point_t p=b_point; p > 0;) {
	p--;
	point_t pp;
        wchar_t *s;
	for (s=searchtext, pp=p; *s == *ptr(pp) && *s != L'\0' && pp >= 0; s++, pp++) ;
	if (*s == L'\0') {
          b_point = p;
          msg(L"Search: %ls", searchtext);
          display();
          goto backward_search;
	}
}
msg(L"Failing Backward Search: %ls", searchtext);
dispmsg();
search_failed=1;
b_point=pos(b_ebuf);
@/@t\4@> backward_search:

@ @<Global variables@>=
wchar_t searchtext[STRBUF_M];

@ Variable |search_failed| is a flag to leave cursor on last successful search
position when we press C-m right after failed search. And |search_point| is
the variable to hold that position.

/* TODO: make search case-insensitive */
@^TODO@>

@<Procedures@>=
void search(void)
{
	int cpos = 0;	
	wint_t c;
	point_t o_point = b_point;
	int search_failed = 0;
	point_t search_point;

	searchtext[0] = L'\0';
	msg(L"Search: ");
	dispmsg();
	cpos = (int) wcslen(searchtext);

	while (1) {
	  refresh(); /* update the real screen */
	  get_wch(&c);

	  switch(c) {
	    case
              L'\x0d': /* C-m */
			if (search_failed) b_point = search_point;
			return;
	    case
              L'\x07': /* C-g */
			b_point = o_point;
			return;
	    case
		L'\x12': /* C-r */
			@<Search backward@>@;
			break;
	    case
		L'\x13': /* C-s */
			@<Search forward@>@;
			break;
	    case
                L'\x7f': /* BackSpace */
	    @t\4@>
	    case
		L'\x08': /* C-h */
			if (cpos == 0)
				continue;
			searchtext[--cpos] = L'\0';
			msg(L"Search: %ls", searchtext);
			dispmsg();
			break;
	    default:
			if (cpos < STRBUF_M - 1) {
				searchtext[cpos++] = (wchar_t) c;
				searchtext[cpos] = L'\0';
				msg(L"Search: %ls", searchtext);
				dispmsg();
			}
	}
    }
}

@ @<Main program@>=
int main(int argc, char **argv)
{
        wint_t input;
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc != 2) fatal(L"usage: em filename\n");
	/* TODO: if no arg specified, create temporary file in
	/tex\_tmp/ (like it is done in "bin/tmp") and upon exiting em,
	print the file name to stdout,
	and remove "bin/tmp" */
@^TODO@>

	/* TODO: make second argument to be the line number to be shown when file is opened */
@^TODO@>
	FILE *fp;
	@<Save file name@>@;
	@<Open file@>@;
	@<Get absolute...@>@;
	@<Restore cursor@>@;
	@<Read file@>@;
	@<Close file@>@;
	@<Ensure that restored position is inside buffer@>@;

        initscr(); /* start curses mode */
        raw();
        noecho();
	nonl(); /* pass proper value (|0x0d|) for C-m and ENTER keypresses from |get_wch| */
	keypad(stdscr,TRUE);

	while (!done) {
		display();
		@<Get key@>@;
	}

	if (scrap != NULL) free(scrap);

	move(MSGLINE, 0);
	refresh(); /* update the real screen */
	noraw();
	endwin(); /* end curses mode */

	return 0;
}

@ @<Header files@>=
#include <stdio.h> /* |fgets|, |rewind| */
#include <unistd.h> /* |unlink| */
#include <stdlib.h> /* |strtol| */
#include <string.h> /* |strncmp| */

@ DB file cannot have null char, so use |fgets|.
We will not use |fgetws| here, because the conversionon
of file name from UTF-8 to unicode is not
necessary here and because it uses char*, not char, and char* is OK.

We use Linux, so just delete the file by |unlink| after we open it - then open a new file
with the same name and write the modified lines into the new file. We'll have two |FILE *|
variables.

@d DB_FILE "/tmp/em.db"
@d DB_LINE_SIZE 10000

@ @<Global...@>=
FILE *db_in, *db_out;
char db_line[DB_LINE_SIZE+1];

@ We do this before |@<Read file@>|, not after, because it is not necessary to free memory
before the call to |fatal|.

@<Restore cursor@>=
if ((db_in=fopen(DB_FILE,"a+"))==NULL) { /* |"a+"| creates empty file if it does not exist */
  fclose(fp);
  fatal(L"Could not open DB file for reading: %s\n", strerror(errno));
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
      if (sscanf(db_line+strlen(b_absname), "%ld", &b_point) != 1)
        file_is_locked = 1;
    continue;
  }
  fprintf(db_out,"%s",db_line);
}
fclose(db_in);
fprintf(db_out,"%s lock\n",b_absname);
fclose(db_out);
if (file_is_locked)
  fatal(L"File is locked.\n");

@ Consider this case: we open empty file, add string ``hello world'', then
exit without saving. The saved cursor position will be 11. Next time we open this
same empty file, |@<Restore cursor@>| will set |b_point| past the end of buffer.

But this check can only be done after the file is read, in order that the buffer
is allocated.

TODO: instead of this check do this: if file is closed without saving and it was
changed after it was opened,
saved cursor position must be the same as it was read from |DB_FILE|.
For this, revert removing |B_MODIFIED| (see \.{git lg em.w}).
@^TODO@>

@<Ensure that restored...@>=
if (b_point > pos(b_ebuf)) b_point = pos(b_ebuf);

@ See |@<Restore cursor@>| for the technique used here.

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
if (strstr(b_absname,"COMMIT_EDITMSG")==NULL) fprintf(db_out,"%s %ld\n",b_absname,b_point);
fclose(db_out);

@ Here, besides reading user input, we handle resize event. We pass
reference to variable of type
|wint_t| to |get_wch| instead of type |wchar_t|, because |get_wch| takes
|wint_t *| argument. While this would have been possible to typecast
|wchar_t| to |wint_t|, this is impossible to typecast pointer. So, we
have to use the variable of type |wint_t|. Why ncurses authors decided to use |wint_t *|
instead of |wchar_t *| as the argument? Answer: for uniformity. Although |get_wch| only
sets |wchar_t| values to its argument (no |wint_t|), |wint_t| type is used because this
same variable which is passed to |get_wch| may be used for reading
the file, where |wint_t| type is necessary, because of WEOF.
For |get_wch| it was
decided not to use |wint_t| to store the signal (contrary to |getch|)
because each implementation has its own sizes for |wint_t| and |wchar_t|, so
it is impossible to have a constant to store the signal.
And it is good to keep the same values for |KEY_RESIZE| etc which are used for
|getch| anyway.
So, they decided to distinguish via the return value
if |get_wch| passed a signal or a char. The return value is
|KEY_CODE_YES| if a signal is passed in the argument, |OK| if a char is passed, and
|ERR| otherwise.
In our case, only one signal is used---|KEY_RESIZE|.
So, we do not check |input| for this; we just do resize by default if a signal is passed.

@<Get key@>=
if (get_wch(&input) == KEY_CODE_YES) {
  switch(input) {
    case KEY_RESIZE:
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
        lnbegin();
        break;
    case KEY_END:
        lnend();
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
  }
}
else {
switch(input) {
	case
		L'\x0f': /* C-o */
		open_line();
		break;
	case
		L'\x18': /* C-x */
		@<Remove lock and save cursor@>@;
		done = 1; /* quit without saving */
		break;
	case
		L'\x12': /* C-r */
	@t\4@>
	case
		L'\x13': /* C-s */
		search();
		break;
	case
		L'\x1d': /* C-] */
		bottom();
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
		lnend();
		break;
	case
		L'\x01': /* C-a */
		lnbegin();
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
		L'\x1e': /* C-6 */
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
		insert((wchar_t) input);
}
}

@ Utility macros.

@d ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))

@ @<Header files@>=
#include <stdlib.h>
#include <stdarg.h>
#include <assert.h>
#include <ncursesw/curses.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/ioctl.h>
#include <ctype.h>
#include <limits.h>
#include <string.h>
#include <unistd.h>
#include <termios.h>
#include <locale.h>
#include <wchar.h>
#include <errno.h>

@* Index.
