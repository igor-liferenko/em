outputtemplate:="%j.eps"; prologues:=3;
fontmapline "+lhr10 <lhr10.pfb";

beginfig(1)
u=1cm;
z1=(0,0);
label.bot(btex b\_buf etex, z1-(0,.2u));
z2=(4u,0);
label.bot(btex b\_gap etex, z2-(0,.2u));
z3=(8u,0);
label.bot(btex b\_egap etex, z3-(0,.2u));
z4=(12u,0);
label.bot(btex b\_ebuf etex, z4-(0,.2u));
z5=(.5[x1,x2],.5u);
z6=(.5[x1,x3],1.2u);
z7=(.5[x1,x4],1.85u);
label.top("xgap", z5);
label.top("xegap", z6);
label.top("buflen", z7);
pickup pencircle scaled .4pt;
draw z1 .. controls (x1+.2u,.6u) and (x5-.5u,y5-.3u) .. z5;
draw z5 .. controls (x5+.5u,y5-.3u) and (x2-.2u,.6u) .. z2;
draw z1 .. controls (x1+.1u,1.5u) and (x6-.5u,y6-.5u) .. z6;
draw z6 .. controls (x6+.5u,y6-.5u) and (x3-.1u,1.5u) .. z3;
draw z1 .. controls (x1+.1u,2.4u) and (x7-.5u,y7-.5u) .. z7;
draw z7 .. controls (x7+.5u,y7-.5u) and (x4-.1u,2.4u) .. z4;
pickup pencircle scaled .8pt;
draw z1 .. z4;
pickup pencircle scaled 12pt;
drawdot z1;
drawdot z2;
drawdot z3;
drawdot z4;
endfig;
end
