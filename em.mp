%outputtemplate:="%j.eps"; prologues:=3;

beginfig(1)
u=1cm;
z1=(0,0);
label.bot(btex \font\x=cmss10 \x b\_buf etex, z1+down*.2u);
z2=(4u,0);
label.bot(btex \font\x=cmss10 \x b\_gap etex, z2+down*.2u);
z3=(7.75u,0);
label.bot(btex \font\x=cmss10 \x b\_egap etex, z3+down*.2u);
z4=(13.35u,0);
label.bot(btex \font\x=cmss10 \x b\_ebuf etex, z4+down*.2u);

% begin curly braces

pickup pencircle scaled .4pt;
pair a; pair b; pair c; pair d;

z5=(.5[x1,x2],.3u);
a:=(x1,.35u); b:=z5+down rotated -30 scaled .3u;
c:=b reflectedabout (z5,(x5,0));
d:=a reflectedabout (z5,(x5,0));
draw z1 .. controls a and b .. z5;
draw z5 .. controls c and d .. z2;
label.top("xgap" infont "cmss10", z5);

z6=(.5[x1,x3],.85u);
a:=(x1,1.2u); b:=z6+down rotated -30 scaled .5u;
c:=b reflectedabout (z6,(x6,0));
d:=a reflectedabout (z6,(x6,0));
draw z1 .. controls a and b .. z6;
draw z6 .. controls c and d .. z3;
label.top("xegap" infont "cmss10", z6);

z7=(.5[x1,x4],1.5u);
a:=(x1,2.1u); b:=z7+down rotated -30 scaled .7u;
c:=b reflectedabout (z7,(x7,0));
d:=a reflectedabout (z7,(x7,0));
draw z1 .. controls a and b .. z7;
draw z7 .. controls c and d .. z4;
label.top("buflen" infont "cmss10", z7);

% end curly braces

pickup pencircle scaled .8pt;
draw z1 .. z4;
pickup pencircle scaled 12pt;
drawdot z1;
drawdot z2;
drawdot z3;
drawdot z4;
endfig;
end
