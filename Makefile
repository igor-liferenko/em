ifeq ($(MAKECMDGOALS),)
all:
	@echo NoOp
else
em: em.c
	clang -g -o $@ $< -lncursesw -D_XOPEN_SOURCE=600
	cp $@ /usr/local/bin/
endif

.PHONY: $(wildcard *.eps)

buffer-gap.eps: buffer-gap.svg
	@inkscape $< -E $@ 2>/dev/null
	@imgsize $@
