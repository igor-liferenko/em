For some reason, fopen() on files like
  /var/run/user/1000/gvfs/smb-share:server=1.2.3.4,share=doc/file.txt
(i.e., samba share in "nautilus")
But the next fopen() call succeeds, which results to erasing the file contents.
To prevent that, just bail out on such files.
@x
if ((fp = fopen(b_fname, "r+")) == NULL)
@y
if (strstr(b_fname, "/gvfs/")) fatal(L"");
if ((fp = fopen(b_fname, "r+")) == NULL)
@z
