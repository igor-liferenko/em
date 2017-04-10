\let\lheader\rheader
\datethis

@s delete normal
@s new normal

@* Zep Emacs.
   Derived from: Anthony's Editor January 93 and Hugh Barney 2017

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
@<Procedures@>@;
@<Key bindings@>@;
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
keymap_t *key_map;
buffer_t *curbp;
point_t nscrap = 0;
wchar_t *scrap = NULL;

@ Some compilers define |size_t| as a unsigned 16 bit number while
|point_t| and |off_t| might be defined as a signed 32 bit number.
malloc(), realloc(), fread(), and fwrite() take |size_t| parameters,
which means there will be some size limits because |size_t| is too
small of a type.

@d MAX_SIZE_T      ((point_t) (size_t) ~0)

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

@ @d E_NAME          L"zep"
@d E_VERSION       L"v1.2"

@<Procedures@>=
void fatal(wchar_t *msg)
{
	move(LINES-1, 0);
	refresh();
	endwin();
	noraw();
	wprintf(L"\n" E_NAME L" " E_VERSION L": %ls\n", msg);
	exit(EXIT_FAILURE);
}

@ @<Global variables@>=
wchar_t msgline[TEMPBUF];

@ @<Procedures@>=
void msg(wchar_t *msg, ...)
{
	va_list args;
	va_start(args, msg);
	vswprintf(msgline, sizeof(msgline), msg, args);
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
    
	/* reduce number of reallocs by growing by a minimum amount */
	n = (n < MIN_GAP_EXPAND ? MIN_GAP_EXPAND : n);
	newlen = buflen + n;

	if (buflen == 0) {
		if (newlen < 0 || MAX_SIZE_T < newlen) fatal(L"Failed to allocate required memory.\n");
		new = malloc((size_t) newlen);
		if (new == NULL) fatal(L"Failed to allocate required memory.\n");
	} else {
		if (newlen < 0 || MAX_SIZE_T < newlen) {
			msg(L"Failed to allocate required memory");
			return (FALSE);
		}
		new = realloc(bp->b_buf, (size_t) newlen);
		if (new == NULL) {
			msg(L"Failed to allocate required memory");    /* Report non-fatal error. */
			return (FALSE);
		}
	}

	/* Relocate pointers in new buffer and append the new
	 * extension to the end of the gap.
	 */
	bp->b_buf = new;
	bp->b_gap = bp->b_buf + xgap;      
	bp->b_ebuf = bp->b_buf + buflen;
	bp->b_egap = bp->b_buf + newlen;
	while (xegap < buflen--)
		*--bp->b_egap = *--bp->b_ebuf;
	bp->b_ebuf = bp->b_buf + newlen;

	assert(bp->b_buf < bp->b_ebuf);          /* Buffer must exist. */
	assert(bp->b_buf <= bp->b_gap);
	assert(bp->b_gap < bp->b_egap);          /* Gap must grow only. */
	assert(bp->b_egap <= bp->b_ebuf);
	return (TRUE);
}

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
void save(void)
{
	FILE *fp;
	point_t length;

	fp = fopen(curbp->b_fname, "w");
	if (fp == NULL) msg("Failed to open file \"%s\".", curbp->b_fname);
	(void) movegap(curbp, (point_t) 0);
	length = (point_t) (curbp->b_ebuf - curbp->b_egap);
	if (fputws(curbp->b_egap, fp) < 0)
		msg(L"Failed to write file \"%s\".", curbp->b_fname);
	fclose(fp);
	curbp->b_flags &= ~B_MODIFIED;
	msg(L"File \"%s\" %ld bytes saved.", curbp->b_fname, pos(curbp, curbp->b_ebuf));
}

@ Reads file into buffer at point.

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
	if (MAX_SIZE_T < sb.st_size) {
		msg(L"File \"%s\" is too big to load.", fn);
		return (FALSE);
	}
	if (curbp->b_egap - curbp->b_gap < sb.st_size * (off_t) sizeof (wchar_t) &&
          !growgap(curbp, sb.st_size))
		return (FALSE);
	if ((fp = fopen(fn, "r")) == NULL) {
		msg(L"Failed to open file \"%s\".", fn);
		return (FALSE);
	}
	curbp->b_point = movegap(curbp, curbp->b_point);

        @<Read file@>@;

	if (fclose(fp) != 0) {
		msg(L"Failed to close file \"%s\".", fn);
		return (FALSE);
	}
	curbp->b_flags = (char)(curbp->b_flags & (char)(modflag ? B_MODIFIED : ~B_MODIFIED));
	msg(L"File \"%s\" %ld bytes read.", fn, len);
	return (TRUE);
}

@ @<Read file@>=
        wint_t c;
        for (len = 0; len < (size_t) sb.st_size; len++) { 
          if ((c = fgetwc(fp)) == WEOF)
            break;
          if (c == L'\0') fatal(L"File contains zero character");
          *(curbp->b_gap + len) = (wchar_t) c;
        }
        if (c==WEOF && !feof(fp)) fatal(L"Error reading file");
        *(curbp->b_gap + len) = L'\0';
	curbp->b_gap += len;

@ UTF-8 is valid encoding for Unicode. The requirement of UTF-8 is that it is equal to
ASCII in |\000|--|\177| range. According to the structure of UTF-8 (first bit is zero
for ASCII), it follows that all ASCII codes are Unicode values (and vice versa).
In other words, the following transformation is always valid:
|wc = (wchar_t)c|, where |c| is of type |char| and |wc| is of type
|wchar_t|, and |c| contains ASCII codes. In our case |c| can only contain ASCII codes
(see |@<Keymap definition@>|).

@<Procedures@>=
wchar_t *get_key(keymap_t **key_return)
{
	keymap_t *k;
	int submatch;
	static wchar_t buffer[K_BUFFER_LENGTH];
	static wchar_t *record = buffer;

	*key_return = NULL;

	if (*record != L'\0') { /* if recorded bytes remain, return next recorded byte. */
		*key_return = NULL;
		return record++;
	}
	record = buffer; /* reset record buffer. */

	do {
		assert(K_BUFFER_LENGTH > record - buffer);
		if (get_wch(record)==ERR) fatal(L"Error reading input"); /* read and record
                  one code-point. */
		*(++record) = L'\0'; /* FIXME: try to put ++ to |get_wch| from here after
                  you will finish everything */

		for (k = key_map, submatch = 0; k->key_bytes != NULL; k++) { /* if recorded
                  code-points match any multi-byte sequence... */
			wchar_t *p;
                        char *q;

			for (p = buffer, q = k->key_bytes; *p == (wchar_t) *q; p++, q++) {
				if (*q == '\0' && *p == L'\0') { /* an exact match */
	    				record = buffer;
					*record = L'\0';
					*key_return = k;
					return record; /* empty string */
				}
			}
			if (*p == L'\0' && *q != '\0') /* record bytes match part of
                          a command sequence */
				submatch = 1;
		}
	} while (submatch);
	record = buffer; /* nothing matched, return recorded bytes. */
	return (record++); /* FIXME: why ++ ? */
}

@ Reverse scan for start of logical line containing offset.

@<Procedures@>=
point_t lnstart(buffer_t *bp, register point_t off)
{
	register char_t *p;
	do
		p = ptr(bp, --off);
	while (bp->b_buf < p && *p != '\n');
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

@ @<Procedures@>=
/* Forward scan for start of logical line segment following 'finish' */
point_t segnext(buffer_t *bp, point_t start, point_t finish)
{
	char_t *p;
	int c = 0;

	point_t scan = segstart(bp, start, finish);
	for (;;) {
		p = ptr(bp, scan);
		if (bp->b_ebuf <= p || COLS <= c)
			break;
		++scan;
		if (*p == '\n')
			break;
		c += *p == '\t' ? 8 - (c & 7) : 1;
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
	char_t *p;
	while ((p = ptr(bp, offset)) < bp->b_ebuf && *p != '\n' && c < column) {
		c += *p == '\t' ? 8 - (c & 7) : 1;
		++offset;
	}
	return (offset);
}

@ @<Global variables@>=
wchar_t temp[TEMPBUF];

@ @d E_LABEL         "Zep:"

@<Procedures@>=
void modeline(buffer_t *bp)
{
	int i;
	char mch;
	
	standout();
	move(bp->w_top + bp->w_rows, 0);
	mch = ((bp->b_flags & B_MODIFIED) ? '*' : '=');
	swprintf(temp, sizeof(temp), "=%c " E_LABEL " == %s ", mch, bp->b_fname);
	addwstr(temp);

	for (i = (int)(wcslen(temp) + 1); i <= COLS; i++)
		add_wch(L'=');
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

@ @<Procedures@>=
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
			if (iswprint(*p) || *p == L'\t' || *p == L'\n') {
				j += *p == L'\t' ? 8-(j&7) : 1;
				add_wch(*p);
			} else {
				const wchar_t *ctrl = wunctrl((cchar_t)p);
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

@ @<Procedures@>=
void top() { curbp->b_point = 0; }
void bottom() {	curbp->b_epage = curbp->b_point = pos(curbp, curbp->b_ebuf); }
void left() { if (0 < curbp->b_point) --curbp->b_point; }
void right() { if (curbp->b_point < pos(curbp, curbp->b_ebuf)) ++curbp->b_point; }
void up() { curbp->b_point = lncolumn(curbp, upup(curbp, curbp->b_point),curbp->b_col); }
void down() { curbp->b_point = lncolumn(curbp, dndn(curbp, curbp->b_point),curbp->b_col); }
void lnbegin() { curbp->b_point = segstart(curbp, lnstart(curbp,curbp->b_point), curbp->b_point); }
void quit() { done = 1; }

@ @<Procedures@>=
void lnend()
{
	curbp->b_point = dndn(curbp, curbp->b_point);
	left();
}

@ @<Procedures@>=
void pgdown()
{
	curbp->b_page = curbp->b_point = upup(curbp, curbp->b_epage);
	while (0 < curbp->b_row--)
		down();
	curbp->b_epage = pos(curbp, curbp->b_ebuf);
}

@ @<Procedures@>=
void pgup()
{
	int i = curbp->w_rows;
	while (0 < --i) {
		curbp->b_page = upup(curbp, curbp->b_page);
		up();
	}
}

@ @<Procedures@>=
void insert()
{
	assert(curbp->b_gap <= curbp->b_egap);
	if (curbp->b_gap == curbp->b_egap && !growgap(curbp, CHUNK)) return;
	curbp->b_point = movegap(curbp, curbp->b_point);
	*curbp->b_gap++ = *input == L'\r' ? L'\n' : *input;
	curbp->b_point = pos(curbp, curbp->b_egap);
	curbp->b_flags |= B_MODIFIED;
}

@ @<Procedures@>=
void backsp()
{
	curbp->b_point = movegap(curbp, curbp->b_point);
	if (curbp->b_buf < curbp->b_gap) {
		--curbp->b_gap;
		curbp->b_flags |= B_MODIFIED;
	}
	curbp->b_point = pos(curbp, curbp->b_egap);
}

@ @<Procedures@>=
void delete()
{
	curbp->b_point = movegap(curbp, curbp->b_point);
	if (curbp->b_egap < curbp->b_ebuf) {
		curbp->b_point = pos(curbp, ++curbp->b_egap);
		curbp->b_flags |= B_MODIFIED;
	}
}

@ @<Procedures@>=
void set_mark()
{
	curbp->b_mark = (curbp->b_mark == curbp->b_point ? NOMARK : curbp->b_point);
	msg(L"Mark set");
}

@ @<Procedures@>=
void copy_cut(int cut)
{
	wchar_t *p;
	/* if no mark or point == marker, nothing doing */
	if (curbp->b_mark == NOMARK || curbp->b_point == curbp->b_mark) return;
	if (scrap != NULL) {
		free(scrap);
		scrap = NULL;
	}
	if (curbp->b_point < curbp->b_mark) {
		/* point above marker: move gap under point, region = marker - point */
		(void)movegap(curbp, curbp->b_point);
		p = ptr(curbp, curbp->b_point);
		nscrap = curbp->b_mark - curbp->b_point;
	} else {
		/* if point below marker: move gap under marker, region = point - marker */
		(void)movegap(curbp, curbp->b_mark);
		p = ptr(curbp, curbp->b_mark);
		nscrap = curbp->b_point - curbp->b_mark;
	}
	if ((scrap = (char_t *) malloc((size_t) nscrap)) == NULL) {
		msg("No more memory available.");
	} else {
		(void)memcpy(scrap, p, (size_t) nscrap * sizeof (char_t));
		if (cut) {
			curbp->b_egap += nscrap; /* if cut expand gap down */
			curbp->b_point = pos(curbp, curbp->b_egap); /* set point to after region */
			curbp->b_flags |= B_MODIFIED;
			msg("%ld bytes cut.", nscrap);
		} else {
			msg("%ld bytes copied.", nscrap);
		}
		curbp->b_mark = NOMARK;  /* unmark */
	}
}

@ @<Procedures@>=
void paste()
{
	if (nscrap <= 0) {
		msg("Nothing to paste.");
	} else if (nscrap < curbp->b_egap - curbp->b_gap || growgap(curbp, nscrap)) {
		curbp->b_point = movegap(curbp, curbp->b_point);
		memcpy(curbp->b_gap, scrap, (size_t) nscrap * sizeof (char_t));
		curbp->b_gap += nscrap;
		curbp->b_point = pos(curbp, curbp->b_egap);
		curbp->b_flags |= B_MODIFIED;
	}
}

@ @<Procedures@>=
void copy() { copy_cut(FALSE); }
void cut() { copy_cut(TRUE); }

@ @<Procedures@>=
void killtoeol()
{
	/* point = start of empty line or last char in file */
	if (*(ptr(curbp, curbp->b_point)) == 0xa ||
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
point_t search_forward(buffer_t *bp, point_t start_p, char *stext)
{
	point_t end_p = pos(bp, bp->b_ebuf);
	point_t p,pp;
	char* s;

	if (0 == strlen(stext))
		return start_p;

	for (p=start_p; p < end_p; p++) {
		for (s=stext, pp=p; *s == *(ptr(bp, pp)) && *s !='\0' && pp < end_p; s++, pp++)
			;

		if (*s == '\0')
			return pp;
	}

	return -1;
}

@ @<Global variables@>=
wchar_t searchtext[STRBUF_M];

@ @<Procedures@>=
void search()
{
	int cpos = 0;	
	int c;
	point_t o_point = curbp->b_point;
	point_t found;

	searchtext[0] = '\0';
	msg("Search: %s", searchtext);
	dispmsg();
	cpos = (int) strlen(searchtext);

	for (;;) {
		refresh();
		c = getch();
		/* ignore control keys other than C-g, backspace, CR,  C-s, C-R, ESC */
		if (c < 32 && c != 07 && c != 0x08 && c != 0x13 && c != 0x12 && c != 0x1b)
			continue;

		switch(c) {
		case 0x1b: /* esc */
			searchtext[cpos] = '\0';
			flushinp(); /* discard any escape sequence without writing in buffer */
			return;
		case 0x07: /* ctrl-g */
			curbp->b_point = o_point;
			return;
		case 0x13: /* ctrl-s, do the search */
			found = search_forward(curbp, curbp->b_point, searchtext);
			if (found != -1 ) {
				curbp->b_point = found;
				msg("Search: %s", searchtext);
				display();
			} else {
				msg("Failing Search: %s", searchtext);
				dispmsg();
				curbp->b_point = 0;
			}
			break;
		case 0x7f: /* del, erase */
		case 0x08: /* backspace */
			if (cpos == 0)
				continue;
			searchtext[--cpos] = '\0';
			msg("Search: %s", searchtext);
			dispmsg();
			break;
		default:	
			if (cpos < STRBUF_M - 1) {
				searchtext[cpos++] = (char) c;
				searchtext[cpos] = '\0';
				msg("Search: %s", searchtext);
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
        wchar_t *input;
        keymap_t *key_return;
	setlocale(LC_CTYPE, "C.UTF-8");
	if (argc != 2) fatal("usage: " E_NAME " filename\n");

	initscr();
	raw();
	noecho();

	curbp = new_buffer();
	(void)insert_file(argv[1], FALSE);
	/* Save filename irregardless of load() success. */
	strncpy(curbp->b_fname, argv[1], MAX_FNAME);
	curbp->b_fname[MAX_FNAME] = '\0'; /* force truncation */

	if (!growgap(curbp, CHUNK)) fatal("Failed to allocate required memory.\n");

	key_map = keymap;

	while (!done) {
		display();
		input = get_key(key_map, &key_return);

		if (key_return != NULL) {
			(key_return->func)();
		} else {
			/* allow TAB and NEWLINE, any other control char is 'Not Bound' */
			if (*input > 31 || *input == 10 || *input == 9)
				insert();
                        else {
				fflush(stdin);
				msg("Not bound");
			}
		}
	}

	move(MSGLINE, 0);
	refresh();
	noraw();
	endwin();
	return 0;
}

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
