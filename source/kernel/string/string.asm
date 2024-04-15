;
; ---------- [ BASIC STRING FUNCTIONS ] ----------
;

%ifndef STRING_ASM
%define STRING_ASM

; compares two strings (zero terminated)
; PARAMS
; 0) const char* (ES:DI) => string
; 1) const char* (DS:SI) => string
; RETURNS
; int16 => 0 if no difference was found, and 1 if there was a difference.
strcmp:
strcmp_loop:
  mov al, es:[di]
  cmp al, ds:[si]
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
; 0) const char* (ES:DI) => string
; RETURNS
; int16 => the length of the string
strlen:
  mov si, di  ; store copy of original pointer in SI
strlen_loop:
  inc di
  cmp byte es:[di], 0  ; check for null character
  jne strlen_loop

  mov ax, di
  sub ax, si
  ret


; Calculates how many times a letter exists in a string
; PARAMS
;   - 0) ES:DI    => The string, null terminated
;   - 1) SI       => The letter (lower 8 bits)
; RETURNS
;   - In AX, the amount of times the letter was found in the string
strFindLetterCount:
  xor ax, ax                    ; Zero out counter.
  mov bx, si                    ; Set BX to the letter, because then we can use the lower 8 bits of it. (which is the letter)
strFindLetterCount_loop:
  inc di                        ; Increase string pointer to point to the next character
  cmp byte es:[di - 1], 0       ; Check for the end of the string (null character)
  je strFindLetterCount_end     ; If null then stop searching and return

  cmp byte es:[di - 1], bl      ; Check the current letter in the string to the character
  jne strFindLetterCount_loop   ; If not equal then continue searching, otherwise increase character counter and then continue

  inc ax                        ; Increase character coutner
  jmp strFindLetterCount_loop   ; Continue looping

strFindLetterCount_end:
  ret


; Finds the first occurrence of a character in a string
; PARAMS
;   - 0) ES:DI null terminated string.
;   - 1) SI    only lower 8 bits, the character to search for
; RETURNS
;   - In AX, a pointer to the character. If not found then returns NULL.
strchr:
  mov bx, si                    ; As BL has a low part
strchr_loop:
  cmp es:[di], bl               ; Check for the character
  je strchr_found               ; If the current character is equal to the character we need to find then return a pointer to it
  
  cmp byte es:[di], 0           ; Check for null character
  je strchr_notFound            ; If NULL then return NULL

  inc di                        ; Increase string pointer to point to next character in the string
  jmp strchr_loop               ; Continue searching for characters

strchr_notFound:
  xor ax, ax                    ; If not found then return NULL
  ret

strchr_found:
  mov ax, di                    ; If found then return a pointer to the character
  ret

%endif