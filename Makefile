em: em.c
	gcc -g -Wall -Wextra -Wconversion -Wsign-compare -Wsign-conversion -o em em.c -lncursesw -D_XOPEN_SOURCE=600

img:
	@inkscape buffer-gap.svg -E buffer-gap.eps 2>/dev/null
	@imgsize buffer-gap
