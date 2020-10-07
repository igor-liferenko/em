Opening from samba share in Nautilus erases the file, because "fopen" returns NULL.
Just exit on such files.
@x
if ((fp = fopen(b_fname, "r+")) == NULL)
@y
if (strstr(b_fname, "/gvfs/")) fatal(L"");
if ((fp = fopen(b_fname, "r+")) == NULL)
@z
