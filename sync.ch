TODO: check md5sum of file before opening and after closing and if differ, remove after closing,
not before opening as now

@x
@<Open file@>=
@y
@d pat(n, e) sprintf(pat, "^%.*s%s", (int)(strlen(b_fname)-n), b_fname, e);
@<Open file@>=
char pat[1000];
  DIR *d;
  struct dirent *dir;
  d = opendir(".");
  if (d) {
    while ((dir = readdir(d)) != NULL) {
      if (match(b_fname, "\\.tex$")) {
        pat(4, "\\.dvi$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
      }
      if (match(b_fname, "\\.mf$")) {
        pat(3, "\\.tfm$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
        pat(3, "\\.\\d+gf$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
        pat(3, "\\.\\d+pk$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
        pat(3, "\\.dvi$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
      }
    }
    closedir(d);
  }
@z

@x
@<Procedures@>=
@y
@<Procedures@>=
int match(char *str, char *pattern)
{
        pcre2_code *re;
        pcre2_match_data *match_data;
        int errornumber;
        size_t erroroffset;
        int retval = -1;

        re = pcre2_compile(
                pattern,
                PCRE2_ZERO_TERMINATED,
                0,
                &errornumber,
                &erroroffset,
                NULL);
  if (re != NULL) {
        match_data = pcre2_match_data_create_from_pattern(re, NULL);
        if (match_data != NULL) {
                retval = pcre2_match(
                        re,
                        str,
                        PCRE2_ZERO_TERMINATED,
                        0,
                        0,
                        match_data,
                        NULL);
                pcre2_match_data_free(match_data);
        }
        pcre2_code_free(re);
  }
  return retval >= 0;
}
@z

@x
@ @<Header files@>=
@y
@ @<Header files@>=
#include <dirent.h>
#include <pcre2.h>
