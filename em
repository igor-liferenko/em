#!/bin/sh
printf '\e7'
printf '\e[?47h'
printf '\e[2J'
printf '\e[1;1f'
export save=`stty -g`
stty raw -echo
perl -w -Mstrict -CSDA -mTime::HiRes=ualarm ./keys.pl
stty $save
printf '\e[?47l'
printf '\e8'