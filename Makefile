all:
	ctangle em gvfs
	clang -g -o em em.c -lncursesw -D_XOPEN_SOURCE=600
	cp em /usr/local/bin/

clean:
	@git clean -X -d -f

imgs:
	@mp em
