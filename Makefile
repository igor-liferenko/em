all:
	tie -c all.ch em.w gvfs.ch sync.ch >/dev/null
	ctangle em all
	clang -g -o em em.c -lncursesw -D_XOPEN_SOURCE=600 -DPCRE2_CODE_UNIT_WIDTH=8 -lpcre2-8 -lssl -lcrypto
	cp em /usr/local/bin/

clean:
	@git clean -X -d -f

imgs:
	@mp em
