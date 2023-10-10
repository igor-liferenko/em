all:
	ctangle em
	gcc -o em em.c -lncursesw -D_XOPEN_SOURCE=600

eps:
	@make --no-print-directory `grep -o '^\S*\.eps' Makefile`

.PHONY: $(wildcard *.eps)

INKSCAPE=inkscape --export-type=eps --export-ps-level=2 -T -o $@ 2>/dev/null

em.eps:
	@$(INKSCAPE) em.svg
