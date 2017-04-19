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

@ @s point_t int
@s buffer_t int

@<Typedef declarations@>=
typedef long point_t;

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

@ Some compilers define |size_t| as a unsigned 16 bit number while
|point_t| and |off_t| might be defined as a signed 32 bit number.
|malloc| and |realloc| take |size_t| parameters,
which means there will be some size limits.

@d MAX_SIZE_T      (size_t)((size_t)~0 / (sizeof(wchar_t)))

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

@ @<Procedures@>=
/* Enlarge gap by n chars, position of gap cannot change */
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
		if (newlen < 0 || (point_t)~MAX_SIZE_T & newlen)
                  fatal(L"Failed to allocate required memory.\n");
		new = malloc((size_t) newlen * sizeof(wchar_t));
		if (new == NULL)
		  fatal(L"Failed to allocate required memory.\n");
	}
        else {
		if (newlen < 0 || (point_t)~MAX_SIZE_T & newlen) {
			msg(L"Failed to allocate required memory."); /* report non-fatal error */
			return (FALSE);
		}
		new = realloc(bp->b_buf, (size_t) newlen * sizeof(wchar_t));
		if (new == NULL) {
			msg(L"Failed to allocate required memory."); /* report non-fatal error */
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
|@<Read file...@>|.

@<Write file@>=
point_t n;
for (n = 0; n < length; n++)
  if (fputwc(*(curbp->b_egap + n), fp) == WEOF)
    break;
if (n != length)
  msg(L"Failed to write file \"%s\".", curbp->b_fname);

@ Reads file into buffer at point.

In this program we use wide-character editing buffer.
UTF-8 sequences from input file stream are automatically converted
to wide characters by C standard library function |fgetwc|.

Number of bytes in the file is used as an estimate of the upper
bound for the memory buffer to allocate, using the fact that the
number of wide characters cannot be greater than the number of bytes
from which they were converted. Using such an estimate,
in the best case (when file is ASCII-only) we will use
|sizeof(wchar_t)|-times more memory than would be required
for non-wide-character buffer.

@s off_t int

@<Procedures@>=
int insert_file(char *fn)
{
	FILE *fp;
	size_t len;
	struct stat sb;

	if (stat(fn, &sb) < 0) {
		msg(L"Failed to find file \"%s\".", fn);
		return (FALSE);
	}
	if ((off_t)~MAX_SIZE_T & sb.st_size) {
		msg(L"File \"%s\" is too big to load.", fn);
		return (FALSE);
	}
	if (curbp->b_egap - curbp->b_gap < sb.st_size && !growgap(curbp, sb.st_size))
		return (FALSE);
	if ((fp = fopen(fn, "r")) == NULL) {
		fatal(L"Failed to open file \"%s\".", fn);
		return (FALSE);
	}

	curbp->b_point = movegap(curbp, curbp->b_point);

        @<Read file and set number |len| of chars@>@;

	if (fclose(fp) != 0) {
		msg(L"Failed to close file \"%s\".", fn);
		return (FALSE);
	}
	msg(L"File \"%s\" %ld chars read.", fn, len);
	return (TRUE);
}

@ We read file byte-by-byte, instead of reading the entire file
into memory in one go (which is faster), because UTF-8 data must be
converted to wide-character representation. There is just no other
way to convert input data from UTF-8 than processing it byte-by-byte.
This is the necessary price to pay for using wide-character buffer.

@<Read file...@>=
wint_t c;
for (len=0; (c=fgetwc(fp)) != WEOF; len++)
  *(curbp->b_gap + len) = (wchar_t) c;
if (!feof(fp))
  fatal(L"Error reading file: %s.\n", strerror(errno));
curbp->b_gap += len;

@ UTF-8 is valid encoding for Unicode. The requirement of UTF-8 is that it is equal to
ASCII in |0000|--|0177| range. According to the structure of UTF-8 (first bit is zero
for ASCII), it follows that all ASCII codes are Unicode values (and vice versa).
In other words, the following transformation is always valid:
|wc = (wchar_t)c|, where |c| is of type |char| and |wc| is of type
|wchar_t|, and |c| contains ASCII codes. In our case |c| can only contain ASCII codes.

\xdef\asciisec{\secno} % remember the number of this section

@<Get key@>=
                switch(input) {
                        case (wchar_t) 0x13: /* C-s */
                                search();
                                break;
                        case (wchar_t) 0x1b: /* C-[ */
                                top();
                                break;
                        case (wchar_t) 0x1d: /* C-] */
                                bottom();
                                break;
                        case (wchar_t) 0x10: /* C-p */
                                up();
                                break;
                        case (wchar_t) 0x0e: /* C-n */
                                down();
                                break;
                        case (wchar_t) 0x02: /* C-b */
                                left();
                                break;
                        case (wchar_t) 0x06: /* C-f */
                                right();
                                break;
                        case (wchar_t) 0x05: /* C-e */
                                lnend();
                                break;
                        case (wchar_t) 0x01: /* C-a */
                                lnbegin();
                                break;
                        case (wchar_t) 0x04: /* C-d */
                                delete();
                                break;
                        case (wchar_t) 0x7f: /* BackSpace */
                                backsp();
                                break;
                        case (wchar_t) 0x08: /* C-h */
                                backsp();
                                break;
                        case (wchar_t) 0x1e: /* C-6 */
                                pgup();
                                break;
                        case (wchar_t) 0x16: /* C-v */
                                pgdown();
                                break;
                        case (wchar_t) 0x1a: /* C-z */
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
	standout();
	move(MSGLINE, 0);
	for (int i = 1; i <= COLS; i++)
		addwstr(L" ");
	move(MSGLINE, 0);
	if (msgflag) {
		addwstr(msgline);
		msgflag = FALSE;
	}
	standend();
}

@ @s cchar_t int

@<Procedures@>=
void display()
{
	wchar_t *p;
	int i, j, k;
	buffer_t *bp = curbp;
	
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
			i = LINES - 2;
		}
		else
			i = LINES - 1;

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
		if (LINES - 1 <= i || bp->b_ebuf <= p) /* maxline */
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
	for (k=i; k < LINES - 1; k++) {
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
	int i = LINES - 1;
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

@ Here is used the concept which is explained in section~\asciisec.

@<Procedures@>=
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
	  if (c < L' ' && c != L'\a' && c != L'\b' && c != (wchar_t)0x13
            && c != (wchar_t)0x12 && c != L'\n')
	    continue; /* ignore control keys other than in |switch| below */

	  switch(c) {
	    case
              L'\n': /* ctrl-m */
			searchtext[cpos] = L'\0';
			flushinp(); /* discard any escape sequence without writing in buffer */
			return;
	    case
              L'\a': /* ctrl-g */
			curbp->b_point = o_point;
			return;
	    case (wchar_t) 0x13: /* ctrl-s, do the search */
			found = search_forward(curbp, curbp->b_point, searchtext);
			if (found != -1 ) {
				curbp->b_point = found;
				msg(L"Search: %ls", searchtext);
				display();
			} else {
				msg(L"Failing Search: %ls", searchtext);
				dispmsg();
				curbp->b_point = 0;
			}
			break;
	    case (wchar_t) 0x7f: /* del, erase */
	    case
              L'\b': /* backspace */
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
        wchar_t input;
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc != 2) fatal(L"usage: em filename\n");

        @<Create lock file@>@;

	initscr(); /* start curses mode */
	raw();
	noecho();

	curbp = new_buffer();
	insert_file(argv[1]);
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

@ FIXME: is it the right place to create lock file?
@^FIXME@>

@<Create lock file@>=
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
#include <sys/stat.h>
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
