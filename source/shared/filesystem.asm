%ifndef SHARED_FILESYSTEM_ASM
%define SHARED_FILESYSTEM_ASM

; Open for reading, file must exist
%define FILE_OPEN_ACCESS_READ 0
; Open for writing. If already exists then delete all content and write
%define FILE_OPEN_ACCESS_WRITE (FILE_OPEN_ACCESS_READ + 1)
; Open for appending to the end of the file. Created if doesnt exist
%define FILE_OPEN_ACCESS_APPEND (FILE_OPEN_ACCESS_WRITE + 1)
; Open for reading and writing, file must exist
%define FILE_OPEN_ACCESS_READ_PLUS (FILE_OPEN_ACCESS_APPEND + 1)
; Create file for reading and writing
%define FILE_OPEN_ACCESS_WRITE_PLUS (FILE_OPEN_ACCESS_READ_PLUS + 1)
; Open file for reading and appending
%define FILE_OPEN_ACCESS_APPEND_PLUS (FILE_OPEN_ACCESS_WRITE_PLUS + 1)

%define MAX_PATH_FORMATTED_LENGTH 256

%endif