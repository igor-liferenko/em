For some reason, the first fopen() fails on files like
  /var/run/user/1000/gvfs/smb-share:server=1.2.3.4,share=doc/file.txt
(i.e., samba share in "nautilus")
But the next fopen() succeeds, which results in erasing the file contents.
@x
if ((fp = fopen(b_fname, "r+")) == NULL) {
  if (errno != ENOENT) fatal(L"%m\n");
  if ((fp = fopen(b_fname, "w+")) == NULL) /* create file if it does not exist */
@y
if (strstr(b_fname, "/gvfs/")) exit(1);
if ((fp = fopen(b_fname, "r+")) == NULL) {
  if (errno != ENOENT) fatal(L"%m\n");
  if ((fp = fopen(b_fname, "w+")) == NULL) /* create file if it does not exist */
@z
