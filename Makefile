all:
	ctangle em
	gcc -o em em.c -lncursesw -D_XOPEN_SOURCE=600

eps:
	@inkscape --export-ps-level=2 --export-text-to-path --export-type=eps --export-filename=em.eps em.svg
	@#inkscape --export-ps-level=2 --export-text-to-path -E em.eps em.svg 2>/dev/null
