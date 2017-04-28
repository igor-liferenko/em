em: em.c
	make -C /usr/local/uniweb/ uniweb
	gcc -g -Wall -Wextra -Wconversion -Wsign-compare -Wsign-conversion -o em em.c -lncursesw -D_XOPEN_SOURCE=600 /usr/local/uniweb/uniweb.o

img:
	inkscape buffer-gap.svg -E buffer-gap.eps 2>/dev/null
