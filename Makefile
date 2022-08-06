all:
	ctangle em
	gcc -o em em.c -lncursesw -D_XOPEN_SOURCE=600

eps:
	@mpost -interaction batchmode em >/dev/null
