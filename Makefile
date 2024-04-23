all:
	ctangle em
	gcc -w -o em em.c -lncursesw -D_XOPEN_SOURCE=600

eps:
	@make --no-print-directory `grep -o '^\S*\.eps' Makefile`

.PHONY: $(wildcard *.eps)

em.eps:
	@$(inkscape) em.svg

inkscape=inkscape --export-type=eps --export-ps-level=2 -T -o $@ 2>/dev/null
