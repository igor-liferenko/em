all:
	@echo NoOp

em: em.c
	clang -g -o $@ $< -lncursesw -D_XOPEN_SOURCE=600
	cp $@ /usr/local/bin/

clean:
	@git clean -X -d -f

imgs:
	@mpost em
