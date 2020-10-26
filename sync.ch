1) remove .tex and .c files if .w file is opened - this is to avoid confusion when ctangle is run instead of cweave and vice versa
2) remove .dvi file if .tex file is opened - this is to avoid waste of paper when last-minute changes are done to .tex file and then 'prt' is called and because TeX's output may be empty
3) remove .*gf and .*pk and .tfm files if .mf file is opened - this is to make bin/mf wrapper analogous to bin/tex wrapper

@x
@<Open file@>=
@y
@<Open file@>=
char unlinkfname[PATH_MAX+1];
if (strlen(b_fname) >= 2 && strcmp(".w", b_fname+strlen(b_fname)-2) == 0) {
  sprintf(unlinkfname, "%.*s.tex", (int)strlen(b_fname)-2, b_fname);
  unlink(unlinkfname);
  sprintf(unlinkfname, "%.*s.c", (int)strlen(b_fname)-2, b_fname);
  unlink(unlinkfname);
}
if (strlen(b_fname) >= 4 && strcmp(".tex", b_fname+strlen(b_fname)-4) == 0) {
  sprintf(unlinkfname, "%.*s.dvi", (int)strlen(b_fname)-4, b_fname);
  unlink(unlinkfname);
}
if (strlen(b_fname) >= 3 && strcmp(".mf", b_fname+strlen(b_fname)-3) == 0) {
  sprintf(unlinkfname, "%.*s.tfm", (int)strlen(b_fname)-3, b_fname);
  unlink(unlinkfname);
  sprintf(unlinkfname, "rm -f %.*s.*gf", (int)strlen(b_fname)-3, b_fname);
  system(unlinkfname);
  sprintf(unlinkfname, "rm -f %.*s.*pk", (int)strlen(b_fname)-3, b_fname);
  system(unlinkfname);
}
@z
