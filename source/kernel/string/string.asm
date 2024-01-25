;
; ---------- [ BASIC STRING FUNCTIONS ] ----------
;

%ifndef STRING_ASM
%define STRING_ASM

; compares two strings and if equal then jump to given lable
%macro STRCMP_JUMP_EQUAL 3

  lea di, %1
  lea si, %2
  call strcmp
  test ax, ax
  jz %3

%endmacro


; compares two strings (zero terminated)
; PARAMS
; 0) const char* (DI) => string
; 1) const char* (SI) => string
; RETURNS
; int16 => 0 if no difference was found, and 1 if there was a difference.
strcmp:
strcmp_loop:
  mov al, [di]
  cmp al, [si]
  jne strcmp_notEqual

  inc si
  inc di
  test al, al        ; check for null character
  jnz strcmp_loop     ; if not null then continue looping (if null then strings are equal and return 0)

  xor ax, ax
  ret         

strcmp_notEqual:
  mov ax, 1
  ret


; calculates the length of a string (zero terminated)
; PARAMS
; 0) const char* (DI) => string
; RETURNS
; int16 => the length of the string
strlen:
  mov si, di  ; store copy of original pointer in SI
strlen_loop:
  inc di
  cmp byte [di], 0  ; check for null character
  jne strlen_loop

  mov ax, di
  sub ax, si
  ret

%endif