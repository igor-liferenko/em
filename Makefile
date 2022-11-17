all:
	ctangle em
	gcc -o em em.c -lncursesw -D_XOPEN_SOURCE=600

eps:
	@inkscape --export-type=eps --export-ps-level=2 --export-filename=em.eps --export-text-to-path em.svg 2>/dev/null || inkscape -E em.eps --export-ps-level=2 --export-text-to-path em.svg 2>/dev/null
