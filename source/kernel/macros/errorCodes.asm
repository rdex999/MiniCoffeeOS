;
; ---------- [ CONTAINES ERROR CODES FOR SYSTEM FUNCTIONS ] ----------
;

%ifndef MACROS_ERROR_CODES_ASM
%define MACROS_ERROR_CODES_ASM

%define ERR_BUFFER_LIMIT 1

; If a part of a path (like a files path) is more than 11 bytes.
; Part is for example: "dir/file.txt" "dir" is a part and "file.txt" is a part
%define ERR_PATH_PART_LIMIT 2
%define ERR_GET_FILE_ENTRY 3
%define ERR_FILE_NOT_FOUND 4
%define ERR_NOT_DIRECTORY 5

%endif