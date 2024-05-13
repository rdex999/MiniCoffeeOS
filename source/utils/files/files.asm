;
; --------- [ LIST FILE/DIRECTORIES ON A DIRECTORY ] ---------
;

%ifndef FILES_ASM
%define FILES_ASM

%include "shared/process.asm"
%include "shared/interrupts.asm"
%include "shared/filesystem.asm"
%include "shared/print.asm"
%include "shared/ascii.asm"

%define ERR_TOO_MANY_ARGS 1

org PROCESS_LOAD_OFFSET

main:
  mov bp, sp
  sub sp, 6

  mov [bp - 2], ax
  mov [bp - 4], bx
  mov [bp - 6], dx

  cmp cx, 2
  jbe .argCntOk

  PUTS_INT 100h, errTooManyArgs
  mov di, ERR_TOO_MANY_ARGS
  jmp main_end

.argCntOk:
  cmp cx, 2
  je .pathParameter

  lea di, userDir
  mov ax, INT_N_GET_USER_PATH
  int INT_F_KERNEL

  lea di, userDir
  jmp .afterGetPath

.pathParameter:

  mov gs, [bp - 2]
  mov si, [bp - 4]
  add si, 2

  mov es, [bp - 6]
  mov di, gs:[si]

.afterGetPath:
  push di
  PUTS_INT 100h, listFilesOnDirMsg
  pop di

  mov bx, es
  mov ds, bx
  PUTS_INT 100h, di 

  mov bx, fs
  mov es, bx
  mov ds, bx





  xor di, di
main_end:
  mov sp, bp
  mov ax, INT_N_EXIT
  int INT_F_KERNEL


;
; ---------- [ DATA SECTION ] ----------
;

errTooManyArgs:       db "[ - files] Error, too many arguments.", NEWLINE, 0

listFilesOnDirMsg:    db "[ * files] Listing files on ", 0

userDir:              times MAX_PATH_FORMATTED_LENGTH db 0


%endif