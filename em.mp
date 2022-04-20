prologues:=3;

verbatimtex \font\tenss=cmss10 \tenss etex

beginfig(1);
z1=(0,0);
label.bot(btex b\_buf etex, z1+down*6pt);
z2=(4cm,0);
label.bot(btex b\_gap etex, z2+down*6pt);
z3=(7.75cm,0);
label.bot(btex b\_egap etex, z3+down*6pt);
z4=(13.35cm,0);
label.bot(btex b\_ebuf etex, z4+down*6pt);

% begin curly braces

pickup pencircle scaled .4pt;
pair a; pair b; pair c; pair d;

z5=(.5[x1,x2],9pt);
a:=(x1,10pt); b:=z5+down rotated -30 scaled 9pt;
c:=b reflectedabout (z5,(x5,0));
d:=a reflectedabout (z5,(x5,0));
draw z1 .. controls a and b .. z5;
draw z5 .. controls c and d .. z2;
label.top(btex xgap etex, z5);

z6=(.5[x1,x3],27pt);
a:=(x1,34pt); b:=z6+down rotated -30 scaled 14pt;
c:=b reflectedabout (z6,(x6,0));
d:=a reflectedabout (z6,(x6,0));
draw z1 .. controls a and b .. z6;
draw z6 .. controls c and d .. z3;
label.top(btex xegap etex, z6);

z7=(.5[x1,x4],47pt);
a:=(x1,62pt); b:=z7+down rotated -30 scaled 20pt;
c:=b reflectedabout (z7,(x7,0));
d:=a reflectedabout (z7,(x7,0));
draw z1 .. controls a and b .. z7;
draw z7 .. controls c and d .. z4;
label.top(btex buflen etex, z7);

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
