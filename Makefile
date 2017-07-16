em: em.c
	cc -g -o em em.c -lncursesw -D_XOPEN_SOURCE=600 # TODO: selectively disable unnecessary warnings
	cp em /usr/local/bin/

.PHONY: $(wildcard *.eps)

buffer-gap.eps: buffer-gap.svg
	@inkscape $< -E $@ 2>/dev/null
	@imgsize $@
