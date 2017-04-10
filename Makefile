zep: zep.c
	gcc -g -Wall -Wextra -Wconversion -Wsign-compare -Wsign-conversion -o zep zep.c -lncursesw -D_XOPEN_SOURCE=600
