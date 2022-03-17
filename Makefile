all:
	ctangle em
	gcc -o em em.c -lncursesw -D_XOPEN_SOURCE=600 -DDB_DIR=\"/tmp/\"

img:
	mpost em
