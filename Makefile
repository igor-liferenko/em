em: em.c
	gcc -g -Wall -Wextra -Wconversion -Wsign-compare -Wsign-conversion -o em em.c -lncursesw -D_XOPEN_SOURCE=600
