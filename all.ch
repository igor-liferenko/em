@x
void quit(void)
{
  @<Save buffer@>@;
@y
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
int extlen;
#define pat(e) sprintf(pat, "^%.*s%s", (int)(strlen(b_fname)-extlen), b_fname, e)
int c1_ok;
unsigned char c1[MD5_DIGEST_LENGTH];
void quit(void)
{
  @<Save buffer@>@;
if (extlen) {
  int c2_ok = 0;
  unsigned char c2[MD5_DIGEST_LENGTH];
  FILE *inFile;
  MD5_CTX mdContext;
  int bytes;
  unsigned char data[1024];
  if ((inFile = fopen(b_fname, "r")) != NULL) {
    c2_ok = 1;
    MD5_Init(&mdContext);
    while ((bytes = fread(data, 1, 1024, inFile)) != 0)
        MD5_Update(&mdContext, data, bytes);
    MD5_Final(c2, &mdContext);
    fclose (inFile);
  }
  if (c1_ok && c2_ok && strncmp(c1, c2, MD5_DIGEST_LENGTH) != 0) {
    char pat[1000];
    DIR *d;
    struct dirent *dir;
    d = opendir(".");
    if (d) {
      while ((dir = readdir(d)) != NULL) {
        if (extlen == 4) {
          pat("\\.dvi$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
        }
        if (extlen == 3) {
          pat("\\.tfm$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
          pat("\\.\\d+gf$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
          pat("\\.\\d+pk$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
          pat("\\.dvi$"); if (match(dir->d_name, pat)) unlink(dir->d_name);
        }
      }
      closedir(d);
    }
  }
}
@z

@x
@<Open file@>=
@y
@<Open file@>=
if (match(b_fname, "\\.tex$")) extlen = 4;
if (match(b_fname, "\\.mf$")) extlen = 3;
if (extlen) {
  FILE *inFile;
  MD5_CTX mdContext;
  int bytes;
  unsigned char data[1024];
  if ((inFile = fopen(b_fname, "r")) != NULL) {
    c1_ok = 1;
    MD5_Init(&mdContext);
    while ((bytes = fread(data, 1, 1024, inFile)) != 0)
        MD5_Update(&mdContext, data, bytes);
    MD5_Final(c1, &mdContext);
    fclose (inFile);
  }
}
@z

@x
if ((fp = fopen(b_fname, "r+")) == NULL)
  if ((fp = fopen(b_fname, "w")) == NULL) /* create file if it does not exist */
@y
if (strstr(b_fname, "/gvfs/")) exit(1);
if ((fp = fopen(b_fname, "r+")) == NULL)
  if ((fp = fopen(b_fname, "w")) == NULL) /* create file if it does not exist */
@z

@x
@ @<Header files@>=
@y
@ @<Header files@>=
#include <openssl/md5.h>
#include <pcre2.h>
#include <dirent.h>
@z

