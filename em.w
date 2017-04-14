\let\lheader\rheader
\datethis

@s delete normal
@s new normal

@* EMacs. Derived from Zep Emacs by Hugh Barney, 2017

@d MAX_FNAME       256
@d MSGLINE         (LINES-1)
@d B_MODIFIED	0x01		/* modified buffer */
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
@<Predeclarations of procedures for key bindings@>@;
@<Key bindings@>@;
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
	char w_top;	          /* origin (0 = top row of window) */
	char w_rows;              /* no. of rows of text in window */
	int b_row;                /* cursor row */
	int b_col;                /* cursor col */
	char b_fname[MAX_FNAME + 1]; /* filename */
	char b_flags;             /* buffer flags */
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
	bp->b_flags = 0;
	bp->b_buf = NULL;
	bp->b_ebuf = NULL;
	bp->b_gap = NULL;
	bp->b_egap = NULL;
	bp->b_fname[0] = '\0';
	bp->w_top = 0;	
	bp->w_rows = (char)(LINES - 2);
	return bp;
}

@ @<Procedures@>=
void fatal(wchar_t *msg, ...)
{
	va_list args;

	move(LINES-1, 0);
	refresh();
	noraw();
	endwin();

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

@ @<Predecl...@>=
void save(void);
@ @<Procedures@>=
void save(void)
{
	FILE *fp;
	point_t length;

	fp = fopen(curbp->b_fname, "w");
	if (fp == NULL) msg(L"Failed to open file \"%s\".", curbp->b_fname);
	movegap(curbp, (point_t) 0);
	length = (point_t) (curbp->b_ebuf - curbp->b_egap);
        @<Write file@>@;
	fclose(fp);
	curbp->b_flags &= ~B_MODIFIED;
	msg(L"File \"%s\" %ld chars saved.", curbp->b_fname, pos(curbp, curbp->b_ebuf));
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

Multibyte sequences from input stream are automatically converted
to wide characters by C standard library function |fgetwc|.

Number of bytes in the file is used as an estimate of the upper
bound for the memory buffer to allocate, using the fact that the
number of wide characters cannot be greater than the number of bytes
from which they were converted.

In the worst case (when file is ASCII-only) we will use
|sizeof(wchar_t)|-times
more memory than would be required for UTF-8 buffer.
In this implementation we opt to ease of implementation, so we use
wide-character buffer to support UTF-8.

Maybe it is possible to come up with code which will increment the
buffer in small chunks as we are reading the file, in order to use
less memory.

@s off_t int

@<Procedures@>=
int insert_file(char *fn, int modflag)
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
		msg(L"Failed to open file \"%s\".", fn);
		return (FALSE);
	}
	curbp->b_point = movegap(curbp, curbp->b_point);

        @<Read file and set number |len| of chars@>@;

	if (fclose(fp) != 0) {
		msg(L"Failed to close file \"%s\".", fn);
		return (FALSE);
	}
	curbp->b_flags = (char)(curbp->b_flags & (char)(modflag ? B_MODIFIED : ~B_MODIFIED));
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
|wchar_t|, and |c| contains ASCII codes. In our case |c| can only contain ASCII codes
(see |@<Key bindings@>|).

\xdef\asciisec{\secno} % remember the number of this section

@<Procedures@>=
wchar_t get_key(keymap_t **key_return)
{
	keymap_t *k;
	int submatch;
	static wchar_t buffer[K_BUFFER_LENGTH];
	static wchar_t *record = buffer;

	*key_return = NULL;

	if (*record != L'\0') { /* if recorded char(s) remain, return current char
          and advance pointer to the next */
		*key_return = NULL;
		return *record++;
	}
	record = buffer; /* reset record buffer */

	do {
		assert(K_BUFFER_LENGTH > record - buffer);
		if (get_wch((wint_t *) record)==ERR) fatal(L"Error reading key.\n"); /* read
                  and record one char. */
		*++record = L'\0';

		for (k = key_map, submatch = 0; k->key_bytes != NULL; k++) { /* if recorded
                  chars match any multi-byte sequence... */
			wchar_t *p;
                        char *q;

			for (p = buffer, q = k->key_bytes; isascii(*q) && *p == (wchar_t) *q; p++, q++) {
				if (*q == '\0' && *p == L'\0') { /* an exact match */
					*key_return = k;
					*buffer = L'\0'; /* clear record buffer */
					return
                                          L'\0'; /* not used */
				}
			}
			if (*p == L'\0' && *q != '\0') /* record bytes match part of
                          a command sequence */
				submatch = 1;
		}
	} while (submatch);
	record = buffer; /* if nothing matched, return the first recorded char
          and advance pointer to the next */
	return *record++;
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

@ @<Procedures@>=
/* Move up one screen line */
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

@ @<Procedures@>=
/* Move down one screen line */
point_t dndn(buffer_t *bp, point_t off)
{
	return (segnext(bp, lnstart(bp,off), off));
}

@ @<Procedures@>=
/* Return the offset of a column on the specified line */
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
void modeline(buffer_t *bp)
{
	int i;
	wchar_t mch;
	
	standout();
	move(bp->w_top + bp->w_rows, 0);
	mch = ((bp->b_flags & B_MODIFIED) ? L'*' : L'\u2500');
	swprintf(temp, ARRAY_SIZE(temp), L"\u2500%lc em \u2500\u2500 %s ", mch, bp->b_fname);
	addwstr(temp);

	for (i = (int)(wcslen(temp) + 1); i <= COLS; i++)
		addwstr(L"\u2500");
	standend();
}

@ @<Procedures@>=
void dispmsg()
{
	move(MSGLINE, 0);
	if (msgflag) {
		addwstr(msgline);
		msgflag = FALSE;
	}
	clrtoeol();
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
		/* Find end of screen plus one. */
		bp->b_page = dndn(bp, bp->b_point);
		/* if we scoll to EOF we show 1 blank line at bottom of screen */
		if (pos(bp, bp->b_ebuf) <= bp->b_page) {
			bp->b_page = pos(bp, bp->b_ebuf);
			i = bp->w_rows - 1;
		} else {
			i = bp->w_rows - 0;
		}
		/* Scan backwards the required number of lines. */
		while (0 < i--)
			bp->b_page = upup(bp, bp->b_page);
	}

	move(bp->w_top, 0); /* start from top of window */
	i = bp->w_top;
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
		if (bp->w_top + bp->w_rows <= i || bp->b_ebuf <= p) /* maxline */
			break;
		if (*p != L'\r') {
			if (iswprint((wint_t) *p) || *p == L'\t' || *p == L'\n') {
				j += *p == L'\t' ? 8-(j&7) : 1;
                                add_wch_hack[wctomb(add_wch_hack, *p)]='\0';
                                addstr(add_wch_hack);
			}
			else {
				cchar_t my_cchar;
				memset(&my_cchar, 0, sizeof(my_cchar));
				my_cchar.chars[0] = *p;
				my_cchar.chars[1] = L'\0';
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
	for (k=i; k < bp->w_top + bp->w_rows; k++) {
		move(k, j); /* clear from very last char not start of line */
		clrtoeol();
		j = 0; /* thereafter start of line */
	}

	modeline(bp);
	dispmsg();
	move(bp->b_row, bp->b_col); /* set cursor */
	refresh();
}

@ @<Predecl...@>=
void top(void);
void bottom(void);
void left(void);
void right(void);
void up(void);
void down(void);
void lnbegin(void);
void quit(void);

@ @<Procedures@>=
void top(void) {@+ curbp->b_point = 0; @+}
void bottom(void) {@+ curbp->b_epage = curbp->b_point = pos(curbp, curbp->b_ebuf); @+}
void left(void) {@+ if (0 < curbp->b_point) --curbp->b_point; @+}
void right(void) {@+ if (curbp->b_point < pos(curbp, curbp->b_ebuf)) ++curbp->b_point; @+}
void up(void) {@+ curbp->b_point = lncolumn(curbp, upup(curbp, curbp->b_point),curbp->b_col); @+}
void down(void) {@+ curbp->b_point = lncolumn(curbp, dndn(curbp, curbp->b_point),curbp->b_col); @+}
void lnbegin(void) {@+ curbp->b_point = segstart(curbp,
  lnstart(curbp,curbp->b_point), curbp->b_point); @+}
void quit(void) {@+ done = 1; @+}

@ @<Predecl...@>=
void lnend(void);
@ @<Procedures@>=
void lnend(void)
{
	curbp->b_point = dndn(curbp, curbp->b_point);
	left();
}

@ @<Predecl...@>=
void pgdown(void);
@ @<Procedures@>=
void pgdown(void)
{
	curbp->b_page = curbp->b_point = upup(curbp, curbp->b_epage);
	while (0 < curbp->b_row--)
		down();
	curbp->b_epage = pos(curbp, curbp->b_ebuf);
}

@ @<Predecl...@>=
void pgup(void);
@ @<Procedures@>=
void pgup(void)
{
	int i = curbp->w_rows;
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
	curbp->b_flags |= B_MODIFIED;
}

@ @<Predecl...@>=
void backsp(void);
@ @<Procedures@>=
void backsp(void)
{
	curbp->b_point = movegap(curbp, curbp->b_point);
	if (curbp->b_buf < curbp->b_gap) {
		--curbp->b_gap;
		curbp->b_flags |= B_MODIFIED;
	}
	curbp->b_point = pos(curbp, curbp->b_egap);
}

@ @<Predecl...@>=
void delete(void);
@ @<Procedures@>=
void delete(void)
{
	curbp->b_point = movegap(curbp, curbp->b_point);
	if (curbp->b_egap < curbp->b_ebuf) {
		curbp->b_point = pos(curbp, ++curbp->b_egap);
		curbp->b_flags |= B_MODIFIED;
	}
}

@ @<Predecl...@>=
void set_mark(void);
@ @<Procedures@>=
void set_mark(void)
{
	curbp->b_mark = (curbp->b_mark == curbp->b_point ? NOMARK : curbp->b_point);
	msg(L"Mark set");
}

@ @<Procedures@>=
void copy_cut(int cut)
{
	wchar_t *p;
	if (curbp->b_mark == NOMARK || curbp->b_point == curbp->b_mark) return;	/* if no
          mark or point == marker, do nothing */
	if (scrap != NULL) {
		free(scrap);
		scrap = NULL;
	}
	if (curbp->b_point < curbp->b_mark) {
		/* point above marker: move gap under point, region = marker - point */
		movegap(curbp, curbp->b_point);
		p = ptr(curbp, curbp->b_point);
		nscrap = curbp->b_mark - curbp->b_point;
	} else {
		/* if point below marker: move gap under marker, region = point - marker */
		movegap(curbp, curbp->b_mark);
		p = ptr(curbp, curbp->b_mark);
		nscrap = curbp->b_point - curbp->b_mark;
	}
	scrap = malloc((size_t) nscrap * sizeof(wchar_t));
	if (scrap == NULL)
		msg(L"No more memory available.");
	else {
		memcpy(scrap, p, (size_t) nscrap * sizeof (wchar_t));
		if (cut) {
			curbp->b_egap += nscrap; /* if cut expand gap down */
			curbp->b_point = pos(curbp, curbp->b_egap); /* set point to after region */
			curbp->b_flags |= B_MODIFIED;
			msg(L"%ld chars cut.", nscrap);
		} else {
			msg(L"%ld chars copied.", nscrap);
		}
		curbp->b_mark = NOMARK;  /* unmark */
	}
}

@ @<Predecl...@>=
void paste(void);
@ @<Procedures@>=
void paste(void)
{
	if (nscrap <= 0) {
		msg(L"Nothing to paste.");
	} else if (nscrap < curbp->b_egap - curbp->b_gap || growgap(curbp, nscrap)) {
		curbp->b_point = movegap(curbp, curbp->b_point);
		memcpy(curbp->b_gap, scrap, (size_t) nscrap * sizeof (wchar_t));
		curbp->b_gap += nscrap;
		curbp->b_point = pos(curbp, curbp->b_egap);
		curbp->b_flags |= B_MODIFIED;
	}
}

@ @<Predecl...@>=
void copy(void);
void cut(void);
@ @<Procedures@>=
void copy(void) { copy_cut(FALSE); }
void cut(void) { copy_cut(TRUE); }

@ @<Predecl...@>=
void killtoeol(void);
@ @<Procedures@>=
void killtoeol(void)
{
	/* point = start of empty line or last char in file */
	if (*(ptr(curbp, curbp->b_point)) == L'\n' ||
          (curbp->b_point + 1 ==
          ((curbp->b_ebuf - curbp->b_buf) - (curbp->b_egap - curbp->b_gap))) ) {
		delete();
	} else {
		curbp->b_mark = curbp->b_point;
		lnend();
		copy_cut(TRUE);
	}
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

@<Predecl...@>=
void search(void);
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
	  refresh();
	  if (get_wch((wint_t *) &c) == ERR) fatal(L"Error reading key.\n");
	  if (c < L' ' && c != L'\a' && c != L'\b' && c != (wchar_t)0x13
            && c != (wchar_t)0x12 && c != L'\e')
	    continue; /* ignore control keys other than C-g, backspace, C-s, C-r, ESC */

	  switch(c) {
	    case
              L'\e': /* esc */
			searchtext[cpos] = L'\0';
			flushinp(); /* discard any escape sequence without writing in buffer */
			return;
	    case
              L'\a': /* ctrl-g */
			curbp->b_point = o_point;
			return;
	    case (wchar_t)0x13: /* ctrl-s, do the search */
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
	    case (wchar_t)0x7f: /* del, erase */
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

@ @s keymap_t int
@<Typedef declarations@>=
typedef struct keymap_t {
	char *key_desc;                 /* name of bound function */
	char *key_bytes;		/* the string of bytes when this key is pressed */
	void (*func)(void);
} keymap_t;

@ @<Key bindings@>=
keymap_t key_map[] = {@|
	{"C-a beginning-of-line    ", "\x01", lnbegin },@|
	{"C-b                      ", "\x02", left },@|
	{"C-d forward-delete-char  ", "\x04", delete },@|
	{"C-e end-of-line          ", "\x05", lnend },@|
	{"C-f                      ", "\x06", right },@|
	{"C-n                      ", "\x0E", down },@|
	{"C-p                      ", "\x10", up },@|
	{"C-h backspace            ", "\x08", backsp },@|
	{"C-k kill-to-eol          ", "\x0B", killtoeol },@|
	{"C-s search               ", "\x13", search },@|
	{"C-v                      ", "\x16", pgdown },@|
	{"C-w kill-region          ", "\x17", cut},@|
	{"C-y yank                 ", "\x19", paste},@|
	{"C-space set-mark         ", "\x00", set_mark },@|
	{"esc @@ set-mark           ", "\x1B\x40", set_mark },@|
	{"esc k kill-region        ", "\x1B\x6B", cut },@|
	{"esc v                    ", "\x1B\x76", pgup },@|
	{"esc w copy-region        ", "\x1B\x77", copy},@|
	{"esc < beg-of-buf         ", "\x1B\x3C", top },@|
	{"esc > end-of-buf         ", "\x1B\x3E", bottom },@|
	{"up previous-line         ", "\x1B\x5B\x41", up },@|
	{"down next-line           ", "\x1B\x5B\x42", down },@|
	{"left backward-character  ", "\x1B\x5B\x44", left },@|
	{"right forward-character  ", "\x1B\x5B\x43", right },@|
	{"home beginning-of-line   ", "\x1B\x4F\x48", lnbegin },@|
	{"end end-of-line          ", "\x1B\x4F\x46", lnend },@|
	{"DEL forward-delete-char  ", "\x1B\x5B\x33\x7E", delete },@|
	{"backspace delete-left    ", "\x7f", backsp },@|
	{"PgUp                     ", "\x1B\x5B\x35\x7E",pgup },@|
	{"PgDn                     ", "\x1B\x5B\x36\x7E", pgdown },@|
	{"C-x C-s save-buffer      ", "\x18\x13", save },@|
	{"C-x C-c exit             ", "\x18\x03", quit },@|
	{"K_ERROR                  ", NULL, NULL }};

@ @<Main program@>=
int main(int argc, char **argv)
{
        wchar_t input;
        keymap_t *key_return;
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc != 2) fatal(L"usage: em filename\n");

	initscr();
	raw();
	noecho();

	curbp = new_buffer();
	insert_file(argv[1], FALSE);
	/* Save filename irregardless of load() success. */
	strncpy(curbp->b_fname, argv[1], MAX_FNAME);
	curbp->b_fname[MAX_FNAME] = '\0'; /* force truncation */

	if (!growgap(curbp, CHUNK)) fatal(L"Failed to allocate required memory.\n");

	while (!done) {
		display();
		input = get_key(&key_return);

		if (key_return != NULL) {
			(key_return->func)();
		} else {
			/* allow TAB and NEWLINE, any other control char is 'Not Bound' */
			if (input >= L' ' || input == L'\n' || input == L'\t')
				insert(input);
                        else {
				fflush(stdin);
				msg(L"Not bound");
			}
		}
	}

	if (scrap != NULL) free(scrap);
	if (curbp != NULL) free(curbp);

	move(MSGLINE, 0);
	refresh();
	noraw();
	endwin();
	return 0;
}

@ Utility macros.
@d ARRAY_SIZE(a) (sizeof(a) / sizeof(a[0]))

@ |add_wch| is buggy. So use workaround - convert wide character to multibyte
string with |wctomb| and then use |addstr|.

@<Global...@>=
char add_wch_hack[MB_LEN_MAX+1];

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
