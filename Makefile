zep: zep.c
	gcc -g -Wall -Wextra -Wconversion -Wsign-compare -Wsign-conversion -o zep zep.c -lncurses -D_XOPEN_SOURCE=600
