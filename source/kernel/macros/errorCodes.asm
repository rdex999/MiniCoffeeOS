;
; ---------- [ CONTAINES ERROR CODES FOR SYSTEM FUNCTIONS ] ----------
;

%ifndef MACROS_ERROR_CODES_ASM
%define MACROS_ERROR_CODES_ASM

%define ERR_BUFFER_LIMIT 1

; If a part of a path (like a files path) is more than 11 bytes.
; Part is for example: "dir/file.txt" "dir" is a part and "file.txt" is a part
%define ERR_PATH_PART_LIMIT 2
%define ERR_GET_FILE_ENTRY (ERR_PATH_PART_LIMIT + 1)
%define ERR_FILE_NOT_FOUND (ERR_GET_FILE_ENTRY + 1)
%define ERR_NOT_DIRECTORY (ERR_FILE_NOT_FOUND + 1)
%define ERR_READ_DISK (ERR_NOT_DIRECTORY + 1)
%define ERR_WRITE_DISK (ERR_READ_DISK + 1)
%define ERR_FILE_ALREDY_EXIST (ERR_WRITE_DISK + 1)

%endif