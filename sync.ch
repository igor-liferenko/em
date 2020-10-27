@x
@<Open file@>=
@y
@<Open file@>=
char cmd[1000];
if (strlen(b_fname) >= 4 && strcmp(".tex", b_fname+strlen(b_fname)-4) == 0) {
  int len = strlen(b_fname)-4;
  if (snprintf(cmd, sizeof cmd, "rm -f %.*s.dvi", len, b_fname) >= sizeof cmd)
  error
}
if (strlen(b_fname) >= 3 && strcmp(".mf", b_fname+strlen(b_fname)-3) == 0) {
  int len = strlen(b_fname)-3;
  snprintf(unlinkfname, "rm -f %.*s.tfm %.*s.dvi", (int)strlen(b_fname)-3, b_fname);
  unlink(unlinkfname);
  sprintf(unlinkfname, "rm -f %.*s.*gf", (int)strlen(b_fname)-3, b_fname);
  system(unlinkfname);
  sprintf(unlinkfname, "rm -f %.*s.*pk", (int)strlen(b_fname)-3, b_fname);
  system(unlinkfname);
}
fork
execl("/bin/sh", "sh", cmd, (char *) NULL);
waitpid
@z
