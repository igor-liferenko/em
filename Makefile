em: em.c
	$(CC) -g -o em em.c -lncursesw -D_XOPEN_SOURCE=600
	cp em /usr/local/bin/

.PHONY: $(wildcard *.eps)

buffer-gap.eps: buffer-gap.svg
	@inkscape $< -E $@ 2>/dev/null
	@imgsize $@
