\let\lheader\rheader
\datethis

@s delete normal
@s new normal

@* EMacs editor. Derived from Zep Emacs by Hugh Barney, 2017

Em uses buffer-gap algorithm.

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

@ The number of lines in window |LINES| is automatically set by {\sl ncurses\/}
library. We maintain our own variable to be able to reduce number of lines if
a message is to be displayed.

@<Global...@>=
int rows;              /* no. of rows of text in window */

@ @s point_t int
@s buffer_t int

@<Typedef declarations@>=
typedef ssize_t point_t;

typedef struct buffer_t
{
	point_t b_mark;	     	  /* the mark */
	point_t b_point;          /* the point */
	point_t b_page;           /* start of page */
	point_t b_epage;          /* end of page */
	wchar_t *b_buf;            /* start of buffer */
	wchar_t *b_ebuf;           /* end of buffer */
	wchar_t *b_gap;            /* start of gap */
	wchar_t *b_egap;           /* end of gap */
	int b_row;                /* cursor row */
	int b_col;                /* cursor col */
	char b_fname[MAX_FNAME + 1]; /* filename */
} buffer_t;

@ @<Global variables@>=
int done;
int msgflag;
buffer_t *curbp;
point_t nscrap = 0;
wchar_t *scrap = NULL;

@ @<Procedures@>=
buffer_t* new_buffer()
{
	buffer_t *bp = malloc(sizeof(buffer_t));
	assert(bp != NULL);

	bp->b_point = 0;
	bp->b_page = 0;
	bp->b_epage = 0;
	bp->b_buf = NULL;
	bp->b_ebuf = NULL;
	bp->b_gap = NULL;
	bp->b_egap = NULL;
	bp->b_fname[0] = '\0';
	return bp;
}

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
wchar_t * ptr(buffer_t *bp, register point_t offset)
{
	if (offset < 0) return (bp->b_buf);
	return (bp->b_buf+offset + (bp->b_buf + offset < bp->b_gap ? 0 : bp->b_egap-bp->b_gap));
}

@ Given a pointer into the buffer, convert it to a buffer offset.

@<Procedures@>=
point_t pos(buffer_t *bp, register wchar_t *cp)
{
	assert(bp->b_buf <= cp && cp <= bp->b_ebuf);
	return (cp - bp->b_buf - (cp < bp->b_egap ? 0 : bp->b_egap - bp->b_gap));
}

@ Enlarge gap by n chars, position of gap cannot change.
TODO: check that |(size_t)newlen*sizeof(wchar_t)| does not cause overflow.
@^TODO@>

@<Procedures@>=
int growgap(buffer_t *bp, point_t n)
{
	wchar_t *new;
	point_t buflen, newlen, xgap, xegap;
		
	assert(bp->b_buf <= bp->b_gap);
	assert(bp->b_gap <= bp->b_egap);
	assert(bp->b_egap <= bp->b_ebuf);

	xgap = bp->b_gap - bp->b_buf;
	xegap = bp->b_egap - bp->b_buf;
	buflen = bp->b_ebuf - bp->b_buf;
    
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
		new = realloc(bp->b_buf, (size_t) newlen * sizeof(wchar_t));
		if (new == NULL) {
			msg(L"Failed to allocate required memory."); /* non-fatal */
			return (FALSE);
		}
	}

	@<Relocate pointers in new buffer and append the new
	  extension to the end of the gap@>@;

	assert(bp->b_buf < bp->b_ebuf);          /* buffer must exist */
	assert(bp->b_buf <= bp->b_gap);
	assert(bp->b_gap < bp->b_egap);          /* gap must grow only */
	assert(bp->b_egap <= bp->b_ebuf);
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
bp->b_buf = new;
bp->b_gap = bp->b_buf + xgap;
bp->b_ebuf = bp->b_buf + buflen;
bp->b_egap = bp->b_buf + newlen;
while (xegap < buflen--)
	*--bp->b_egap = *--bp->b_ebuf;
bp->b_ebuf = bp->b_buf + newlen;

@ @<Procedures@>=
point_t movegap(buffer_t *bp, point_t offset)
{
	wchar_t *p = ptr(bp, offset);
	while (p < bp->b_gap)
		*--bp->b_egap = *--bp->b_gap;
	while (bp->b_egap < p)
		*bp->b_gap++ = *bp->b_egap++;
	assert(bp->b_gap <= bp->b_egap);
	assert(bp->b_buf <= bp->b_gap);
	assert(bp->b_egap <= bp->b_ebuf);
	return (pos(bp, bp->b_egap));
}

@ @<Procedures@>=
void quit(void)
{
	FILE *fp;
	point_t length;

	fp = fopen(curbp->b_fname, "w");
	if (fp == NULL) msg(L"Failed to open file \"%s\".", curbp->b_fname);
	movegap(curbp, (point_t) 0);
	length = (point_t) (curbp->b_ebuf - curbp->b_egap);
        @<Write file@>@;
	fclose(fp);
	done = 1;
}

@ We write file character-by-character for similar reasons which are explained in
|@<Read file@>|.

@<Write file@>=
point_t n;
for (n = 0; n < length; n++)
  if (fputwc(*(curbp->b_egap + n), fp) == WEOF)
    break;
if (n != length)
  msg(L"Failed to write file \"%s\".", curbp->b_fname);

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
	fatal(L"Failed to open file \"%s\".\n", argv[1]);
@<Create lock file@>@;
@<Read file@>@;
fclose(fp);

@ We read file byte-by-byte, instead of reading the entire file
into memory in one go (which is faster), because UTF-8 data must be
converted to wide-character representation. There is just no other
way to convert input data from UTF-8 than processing it byte-by-byte.
This is the necessary price to pay for using wide-character buffer.

@<Read file@>=
wint_t c;
while (1) {
  buf_end = buf;
  while (buf_end - buf < MIN_GAP_EXPAND && (c = fgetwc(fp)) != WEOF)
    *buf_end++ = (wchar_t) c;
  if (buf_end == buf) break; /* end of file */
  @<Copy contents of |buf| to editing buffer@>@;
}

@ @<Copy contents of |buf|...@>=
if (curbp->b_egap - curbp->b_gap < buf_end-buf && !growgap(curbp, buf_end-buf))
  break;
curbp->b_point = movegap(curbp, curbp->b_point);
wcsncpy(curbp->b_gap, buf, (size_t)(buf_end-buf));
curbp->b_gap += (buf_end-buf);

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
		L'\u019a': /* resize */
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
		backsp();
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
		insert(input);
}

@ Reverse scan for start of logical line containing offset.

@<Procedures@>=
point_t lnstart(buffer_t *bp, register point_t off)
{
	register wchar_t *p;
	do
		p = ptr(bp, --off);
	while (bp->b_buf < p && *p != L'\n');
	return (bp->b_buf < p ? ++off : 0);
}

@ Forward scan for start of logical line segment containing `finish'.

@<Procedures@>=
point_t segstart(buffer_t *bp, point_t start, point_t finish)
{
	wchar_t *p;
	int c = 0;
	point_t scan = start;

	while (scan < finish) {
		p = ptr(bp, scan);
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
point_t segnext(buffer_t *bp, point_t start, point_t finish)
{
	wchar_t *p;
	int c = 0;

	point_t scan = segstart(bp, start, finish);
	for (;;) {
		p = ptr(bp, scan);
		if (bp->b_ebuf <= p || COLS <= c)
			break;
		++scan;
		if (*p == L'\n')
			break;
		c += *p == L'\t' ? 8 - (c & 7) : 1;
	}
	return (p < bp->b_ebuf ? scan : pos(bp, bp->b_ebuf));
}

@ Move up one screen line.

@<Procedures@>=
point_t upup(buffer_t *bp, point_t off)
{
	point_t curr = lnstart(bp, off);
	point_t seg = segstart(bp, curr, off);
	if (curr < seg)
		off = segstart(bp, curr, seg-1);
	else
		off = segstart(bp, lnstart(bp,curr-1), curr-1);
	return (off);
}

@ Move down one screen line.

@<Procedures@>=
point_t dndn(buffer_t *bp, point_t off)
{
	return (segnext(bp, lnstart(bp,off), off));
}

@ Return the offset of a column on the specified line.

@<Procedures@>=
point_t lncolumn(buffer_t *bp, point_t offset, int column)
{
	int c = 0;
	wchar_t *p;
	while ((p = ptr(bp, offset)) < bp->b_ebuf && *p != L'\n' && c < column) {
		c += *p == L'\t' ? 8 - (c & 7) : 1;
		++offset;
	}
	return (offset);
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
	buffer_t *bp = curbp;

	if (msgflag) rows = LINES - 1;
	else rows = LINES;
	
	/* find start of screen, handle scroll up off page or top of file  */
	/* point is always within |b_page| and |b_epage| */
	if (bp->b_point < bp->b_page)
		bp->b_page = segstart(bp, lnstart(bp,bp->b_point), bp->b_point);

	/* reframe when scrolled off bottom */
	if (bp->b_epage <= bp->b_point) {
		bp->b_page = dndn(bp, bp->b_point); /* find end of screen plus one */
		if (pos(bp, bp->b_ebuf) <= bp->b_page) { /* if we scoll to EOF we show 1
                  blank line at bottom of screen */
			bp->b_page = pos(bp, bp->b_ebuf);
			i = rows - 1;
		} else {
			i = rows - 0;
		}
		while (0 < i--) /* scan backwards the required number of lines */
			bp->b_page = upup(bp, bp->b_page);
	}

	move(0, 0); /* start from top of window */
	i = 0;
	j = 0;
	bp->b_epage = bp->b_page;
	
	/* paint screen from top of page until we hit maxline */ 
	while (1) {
		/* reached point - store the cursor position */
		if (bp->b_point == bp->b_epage) {
			bp->b_row = i;
			bp->b_col = j;
		}
		p = ptr(bp, bp->b_epage);
		if (rows <= i || bp->b_ebuf <= p) /* maxline */
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
			++i;
		}
		++bp->b_epage;
	}

	/* replacement for clrtobot() to bottom of window */
	for (k=i; k < rows; k++) {
		move(k, j); /* clear from very last char not start of line */
		clrtoeol();
		j = 0; /* thereafter start of line */
	}

	dispmsg();
	move(bp->b_row, bp->b_col); /* set cursor */
	refresh(); /* update the real screen */
}

@ @<Procedures@>=
void top(void) {@+ curbp->b_point = 0; @+}
void bottom(void) {@+ curbp->b_epage = curbp->b_point = pos(curbp, curbp->b_ebuf); @+}
void left(void) {@+ if (0 < curbp->b_point) --curbp->b_point; @+}
void right(void) {@+ if (curbp->b_point < pos(curbp, curbp->b_ebuf)) ++curbp->b_point; @+}
void up(void) {@+ curbp->b_point = lncolumn(curbp, upup(curbp, curbp->b_point),curbp->b_col); @+}
void down(void) {@+ curbp->b_point = lncolumn(curbp, dndn(curbp, curbp->b_point),curbp->b_col); @+}
void lnbegin(void) {@+ curbp->b_point = segstart(curbp,
  lnstart(curbp,curbp->b_point), curbp->b_point); @+}

@ @<Procedures@>=
void lnend(void)
{
	curbp->b_point = dndn(curbp, curbp->b_point);
	left();
}

@ @<Procedures@>=
void pgdown(void)
{
	curbp->b_page = curbp->b_point = upup(curbp, curbp->b_epage);
	while (0 < curbp->b_row--)
		down();
	curbp->b_epage = pos(curbp, curbp->b_ebuf);
}

@ @<Procedures@>=
void pgup(void)
{
	int i = rows;
	while (0 < --i) {
		curbp->b_page = upup(curbp, curbp->b_page);
		up();
	}
}

@ @<Procedures@>=
void insert(wchar_t input)
{
	assert(curbp->b_gap <= curbp->b_egap);
	if (curbp->b_gap == curbp->b_egap && !growgap(curbp, CHUNK)) return;
	curbp->b_point = movegap(curbp, curbp->b_point);
	*curbp->b_gap++ = input == L'\r' ? L'\n' : input;
	curbp->b_point = pos(curbp, curbp->b_egap);
}

@ @<Procedures@>=
void backsp(void)
{
	curbp->b_point = movegap(curbp, curbp->b_point);
	if (curbp->b_buf < curbp->b_gap)
		--curbp->b_gap;
	curbp->b_point = pos(curbp, curbp->b_egap);
}

@ @<Procedures@>=
void delete(void)
{
	curbp->b_point = movegap(curbp, curbp->b_point);
	if (curbp->b_egap < curbp->b_ebuf)
		curbp->b_point = pos(curbp, ++curbp->b_egap);
}

@ @<Procedures@>=
void open_line(void)
{
  msg(L"open_line() not implemented yet");
}

@ @<Procedures@>=
point_t search_forward(buffer_t *bp, point_t start_p, wchar_t *stext)
{
	point_t end_p = pos(bp, bp->b_ebuf);
	point_t p,pp;
	wchar_t *s;

	if (0 == wcslen(stext))
		return start_p;

	for (p=start_p; p < end_p; p++) {
		for (s=stext, pp=p; *s == *ptr(bp, pp) && *s !=L'\0' && pp < end_p; s++, pp++)
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
	wchar_t c;
	point_t o_point = curbp->b_point;
	point_t found;

	searchtext[0] = L'\0';
	msg(L"Search: ");
	dispmsg();
	cpos = (int) wcslen(searchtext);

	for (;;) {
	  refresh(); /* update the real screen */
	  get_wch((wint_t *) &c);
	  if (c < L' ' && c != L'\x07' && c != L'\x08' && c != L'\x13'
            && c != L'\x12' && c != L'\x0a')
	    continue; /* ignore control keys other than in |switch| below */

	  switch(c) {
	    case
              L'\x0a': /* ctrl-m */
			searchtext[cpos] = L'\0';
			flushinp(); /* discard any escape sequence without writing in buffer */
			return;
	    case
              L'\x07': /* ctrl-g */
			curbp->b_point = o_point;
			return;
	    case
		L'\x13': /* ctrl-s, do the search */
			found = search_forward(curbp, curbp->b_point, searchtext);
			if (found != -1 ) {
				curbp->b_point = found;
				msg(L"Search: %ls", searchtext);
				display();
			}
			else {
				msg(L"Failing Search: %ls", searchtext);
				dispmsg();
				curbp->b_point = 0;
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
				searchtext[cpos++] = c;
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
        wchar_t input;
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc != 2) fatal(L"usage: em filename\n");

	initscr(); /* start curses mode */
	raw();
	noecho();

	rows = LINES - 1;

	curbp = new_buffer();

	@<Insert file@>@;
	/* Save filename irregardless of load() success. */
	strncpy(curbp->b_fname, argv[1], MAX_FNAME);
	curbp->b_fname[MAX_FNAME] = '\0'; /* force truncation */
	if (!growgap(curbp, CHUNK)) fatal(L"Failed to allocate required memory.\n");

	while (!done) {
		display();
		get_wch((wint_t *) &input); /* read and record one char */
		@<Get key@>@;
	}

	if (scrap != NULL) free(scrap);
	if (curbp != NULL) free(curbp);

	move(MSGLINE, 0);
	refresh(); /* update the real screen */
	noraw();
	endwin(); /* end curses mode */

        @<Remove lock file@>@;

	return 0;
}

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

@* References.

\noindent \.{[1] Perfect Emacs - https://github.com/hughbarney/pEmacs} \par
\noindent \.{[2] Anthony's Editor - https://github.com/hughbarney/Anthony-s-Editor} \par
\noindent \.{[3] MG - https://github.com/rzalamena/mg} \par
\noindent \.{[4] Jonathan Payne, Buffer-Gap: http://ned.rubyforge.org/doc/buffer-gap.txt} \par
\noindent \.{[5] Anthony Howe,  http://ned.rubyforge.org/doc/editor-101.txt} \par
\noindent \.{[6] Anthony Howe, http://ned.rubyforge.org/doc/editor-102.txt} \par

@* Index.
