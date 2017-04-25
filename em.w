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

When we paste we have to be a bigger clever and make sure the GAP is big enough to take the
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

@d MAX_FNAME       256
@d MSGLINE         (LINES-1)
@d CHUNK           8096L
@d K_BUFFER_LENGTH 256
@d TEMPBUF         512
@d MIN_GAP_EXPAND  512
@d NOMARK          -1
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
char b_fname[MAX_FNAME + 1] = {'\0'}; /* filename */

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

@<Procedures@>=
wchar_t * ptr(register point_t offset)
{
	if (offset < 0) return b_buf;
	return (b_buf+offset + (b_buf + offset < b_gap ? 0 : b_egap-b_gap));
}

@ Given a pointer into the buffer, convert it to a buffer offset.

@<Procedures@>=
point_t pos(register wchar_t *cp)
{
	assert(b_buf <= cp && cp <= b_ebuf);
	return (cp - b_buf - (cp < b_egap ? 0 : b_egap - b_gap));
}

@ Enlarge gap by n chars, position of gap cannot change.
TODO: check that |(size_t)newlen*sizeof(wchar_t)| does not cause overflow.
@^TODO@>

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

	if (buflen == 0) {
		if (newlen < 0)
                  fatal(L"Why this happened?\n"); /* fatal */
		new = malloc((size_t) newlen * sizeof(wchar_t));
		if (new == NULL)
		  fatal(L"Failed to allocate required memory.\n"); /* fatal */
	}
        else {
		if (newlen < 0) {
			msg(L"Why this happened?"); /* non-fatal */
			return (FALSE);
		}
		new = realloc(b_buf, (size_t) newlen * sizeof(wchar_t));
		if (new == NULL) {
			msg(L"Failed to allocate required memory."); /* non-fatal */
			return (FALSE);
		}
	}

	@<Relocate pointers in new buffer and append the new
	  extension to the end of the gap@>@;

	assert(b_buf < b_ebuf);          /* buffer must exist */
	assert(b_buf <= b_gap);
	assert(b_gap < b_egap);          /* gap must grow only */
	assert(b_egap <= b_ebuf);
	return (TRUE);
}

@ Reduce number of reallocs by growing by a minimum amount.
TODO: check that |buflen + n| does not cause overflow.
@^TODO@>

@<Calculate new length...@>=
n = (n < MIN_GAP_EXPAND ? MIN_GAP_EXPAND : n);
newlen = buflen + n;

@ @<Relocate pointers in new buffer and append the new
    extension to the end of the gap@>=
b_buf = new;
b_gap = b_buf + xgap;
b_ebuf = b_buf + buflen;
b_egap = b_buf + newlen;
while (xegap < buflen--)
	*--b_egap = *--b_ebuf;
b_ebuf = b_buf + newlen;

@ \xdef\fixmesec{\secno}

@<Procedures@>=
point_t movegap(point_t offset)
{
	wchar_t *p = ptr(offset);
	while (p < b_gap)
		*--b_egap = *--b_gap;
	while (b_egap < p)
		*b_gap++ = *b_egap++;
	assert(b_gap <= b_egap);
	assert(b_buf <= b_gap);
	assert(b_egap <= b_ebuf);
	point_t x = pos(b_egap); /* FIXME: do we need to return value? (see related
          FIXME in the declaration of |insert|) */
	if (x!=offset) fatal(L"gotcha\n");
@^FIXME@>
	return (pos(b_egap));
}

@ @<Procedures@>=
void quit(void)
{
	FILE *fp;
	point_t length;

	fp = fopen(b_fname, "w");
	if (fp == NULL) msg(L"Failed to open file \"%s\".", b_fname);
	@<Add trailing newline to non-empty buffer if it is not present@>@;
	movegap(0);
	length = (point_t) (b_ebuf - b_egap);
        @<Write file@>@;
	fclose(fp);
	done = 1;
}

@ @<Add trailing newline to non-empty buffer...@>=
movegap(pos(b_ebuf));
if (b_buf < b_gap && *(b_gap-1) != L'\n')
  if (b_gap != b_egap || growgap(1)) /* if gap size is zero, grow gap */
    *b_gap++ = L'\n';

@ We write file character-by-character for similar reasons which are explained in
|@<Read file@>|.
Writing files is done in two chunks, the data to the left of
	  the gap and then the data to the right.(FIXME: is it true? it was taken from
references on page about ZEP)
@^FIXME@>

@<Write file@>=
point_t n;
for (n = 0; n < length; n++)
  if (fputwc(*(b_egap + n), fp) == WEOF)
    break;
if (n != length)
  msg(L"Failed to write file \"%s\".", b_fname);

@* Reading file into buffer at point.

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
wchar_t buf[MIN_GAP_EXPAND]; /* we read the input into this array */
wchar_t *buf_end; /* where the next char goes */

@ @<Insert file@>=
FILE *fp;
if ((fp = fopen(argv[1], "r")) == NULL)
  if ((fp = fopen(argv[1], "w")) == NULL)
    fatal(L"Failed to open file \"%s\".\n", argv[1]);
@<Create lock file@>@;
/* FIXME: if file is read-only, or we do not have writing ownership, do not create lock file */
@^FIXME@>
@<Read file@>@;
fclose(fp);

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
  while (buf_end - buf < MIN_GAP_EXPAND && (c = fgetwc(fp)) != WEOF)
    *buf_end++ = (wchar_t) c;
  if (buf_end == buf) break; /* end of file */
  @<Copy contents of |buf| to editing buffer@>@;
}
@<Add trailing newline to input from non-empty file if it is not present@>@;

@ @<Copy contents of |buf|...@>=
if (b_egap - b_gap < buf_end-buf && !growgap(buf_end-buf)) { /* if gap size
    is not sufficient, grow gap */
  fclose(fp);
  @<Remove lock file@>@;
  fatal(L"Failed to allocate required memory.\n");
}
for (i = 0; i < buf_end-buf; i++)
  *b_gap++ = buf[i];

@ @<Add trailing newline to input...@>=
if (i && buf[i-1] != L'\n') {
  *buf_end++ = L'\n';
  @<Copy contents of |buf|...@>@;
}

@ @<Get key@>=
switch(input) {
	case
		L'\x0f': /* C-o */
		open_line();
		break;
	case
		L'\x18': /* C-x */
		done = 1; /* quit without saving */
		break;
	case
		L'\x13': /* C-s */
		search();
		break;
	case
		L'\x1b': /* C-[ */
		top();
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
		L'\x7f': /* BackSpace */
		insert(L'\u2190'); /* leftwards arrow */
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
	default:
		insert((wchar_t) input);
}

@ Reverse scan for start of logical line containing offset.

@<Procedures@>=
point_t lnstart(register point_t off)
{
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
		off = segstart(lnstart(curr-1), curr-1);
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
		addwstr(msgline);
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
	if (b_gap == b_egap && !growgap(MIN_GAP_EXPAND)) return; /* if gap size is zero,
		grow gap */
	b_point = movegap(b_point); /* FIXME: does the assignment change anything? (see related
          FIXME in section~\fixmesec) */
@^FIXME@>
	*b_gap++ = input == L'\r' ? L'\n' : input;
	b_point = pos(b_egap); /* FIXME: is it needed? */
@^FIXME@>
}

@ @<Procedures@>=
void backsp(void)
{
	b_point = movegap(b_point);
	if (b_buf < b_gap)
		b_gap--;
	b_point = pos(b_egap);
}

@ @<Procedures@>=
void delete(void)
{
	b_point = movegap(b_point);
	if (b_egap < b_ebuf)
		b_point = pos(++b_egap);
}

@ @<Procedures@>=
void open_line(void)
{
  msg(L"open_line() not implemented yet");
}

@ @<Procedures@>=
point_t search_forward(point_t start_p, wchar_t *stext)
{
	point_t end_p = pos(b_ebuf);
	point_t p,pp;
	wchar_t *s;

	if (0 == wcslen(stext))
		return start_p;

	for (p=start_p; p < end_p; p++) {
		for (s=stext, pp=p; *s == *ptr(pp) && *s !=L'\0' && pp < end_p; s++, pp++)
			;

		if (*s == L'\0')
			return pp;
	}

	return -1;
}

@ @<Global variables@>=
wchar_t searchtext[STRBUF_M];

@ @<Procedures@>=
void search(void)
{
	int cpos = 0;	
	wint_t c;
	point_t o_point = b_point;
	point_t found;

	searchtext[0] = L'\0';
	msg(L"Search: ");
	dispmsg();
	cpos = (int) wcslen(searchtext);

	for (;;) {
	  refresh(); /* update the real screen */
	  get_wch(&c);
	  if (c < L' ' && c != L'\x07' && c != L'\x08' && c != L'\x13'
            && c != L'\x12' && c != L'\x0a')
	    continue; /* ignore control keys other than in |switch| below */
/* FIXME: do this via |iswctrl| in |default| below */

	  switch(c) {
	    case
              L'\x0a': /* ctrl-m */
			searchtext[cpos] = L'\0';
			flushinp(); /* discard any escape sequence without writing in buffer */
			return;
	    case
              L'\x07': /* ctrl-g */
			b_point = o_point;
			return;
	    case
		L'\x13': /* ctrl-s, do the search */
			found = search_forward(b_point, searchtext);
			if (found != -1 ) {
				b_point = found;
				msg(L"Search: %ls", searchtext);
				display();
			}
			else {
				msg(L"Failing Search: %ls", searchtext);
				dispmsg();
				b_point = 0;
			}
			break;
	    case
		L'\x7f': /* del, erase */
	    case
              L'\x08': /* backspace */
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
			break;
		}
	}
}

@ @<Main program@>=
int main(int argc, char **argv)
{
        wint_t input;
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc != 2) fatal(L"usage: em filename\n");

	initscr(); /* start curses mode */
	raw();
	noecho();

	@<Insert file@>@;
	strncpy(b_fname, argv[1], MAX_FNAME); /* save filename */
	b_fname[MAX_FNAME] = '\0'; /* force truncation */

	while (!done) {
		display();
		@<Read and record one char@>@;
		@<Get key@>@;
	}

	if (scrap != NULL) free(scrap);

	move(MSGLINE, 0);
	refresh(); /* update the real screen */
	noraw();
	endwin(); /* end curses mode */

        @<Remove lock file@>@;

	return 0;
}

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

@<Read and record one char@>=
if (get_wch(&input) == KEY_CODE_YES)
	continue;

@ Utility macros.

@d ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))

@* Lock file. Lock file is necessary to indicate that this file is already
opened. For the name of the lock file we use the same name as opened file,
and add |LOCK_EXT|. When we open a file, lock file is created. When we
finish editing the file, lock file is removed.

@d LOCK_EXT ".lock~"

@<Global...@>=
char lockfn[MAX_FNAME+sizeof(LOCK_EXT)+1];

@ @<Header files@>=
#include <stdio.h> /* |fopen|, |fclose| */
#include <unistd.h> /* |unlink| */

@ @<Create lock file@>=
FILE *lockfp;
strncpy(lockfn, argv[1], MAX_FNAME);
lockfn[MAX_FNAME]='\0';
strcat(lockfn, LOCK_EXT);
if ((lockfp=fopen(lockfn, "r"))!=NULL) {
  fclose(lockfp);
  fatal(L"Lock file exists.\n");
}
if ((lockfp = fopen(lockfn, "w"))==NULL)
  fatal(L"Cannot create lock file.\n");
fclose(lockfp);

@ @<Remove lock file@>=
unlink(lockfn);

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
