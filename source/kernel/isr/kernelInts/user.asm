;
; ---------- [ USER RELATED INTERRUPTS ] ---------
;

%ifndef INT_USER_ASM
%define INT_USER_ASM


; Get the current directory that the user is at
; PARAMETERS
;   - 0) ES:DI  => A buffer to write the data into
; Doesnt return anything
ISR_getUserPath:
  push ds
  mov bx, KERNEL_SEGMENT
  mov ds, bx

  lea si, currentUserDirPath
  call strcpy

  pop ds

  jmp ISR_kernelInt_end

; Set the current directory that the user is at
; PARAMETERS
;   - 0) ES:DI  => The new user directory string
; RETURNS
;   - 0) AX     => Error code, 0 on success
ISR_setUserPath:
  push ds                                     ; Save used segments
  push es                                     ;
  
  push di                                     ; Save requested directory path pointer
  call strlen                                 ; Get its length
  pop di                                      ; Restore requested directory pointer
  cmp ax, MAX_PATH_FORMATTED_LENGTH           ; Check if its length is above the limit
  jb .lengthOk                                ; If its below the limit, dont return an error

  mov ax, ERR_PATH_PART_LIMIT                 ; If its above the limit, return with an error
  jmp .end                                    ; Return

.lengthOk:
  mov si, FILE_OPEN_ACCESS_READ               ; Need to read the directory to confirm its existence
  push ax                                     ; Save length of the requested directroy string
  push di                                     ; Save requested directory string pointer
  call fopen                                  ; Try to open the directory file
  pop di                                      ; Restore requested directory string pointer
  test ax, ax                                 ; Check if fopen has returned a null handle
  jnz .pathExists                             ; If its not null, dont return an error

  add sp, 2                                   ; If null, free some stack space
  mov ax, ERR_FILE_NOT_FOUND                  ; Set error code
  jmp .end                                    ; Return

.pathExists:
  push di                                     ; Save requested directory string pointer
  mov di, ax                                  ; Get file handle in DI
  call fclose                                 ; Close the directory file
  pop si                                      ; Restore requested directory string pointer at DS:SI

  mov bx, es                                  ; Set DS:SI = ES:DI
  mov ds, bx                                  ;

  mov bx, KERNEL_SEGMENT                      ; ES:DI = currentUserDirPath
  mov es, bx                                  ;
  lea di, currentUserDirPath                  ;

  cmp byte ds:[si], '/'                       ; Check if the requested directory string starts with '/'
  je .copy                                    ; If it is, then just copy it into currentUserDirPath without offseting

  push si                                     ; Save requested directory string
  call strlen                                 ; If it doesnt start with '/', get the length of currentUserDirPath
  pop si                                      ; Restore requested directory string
  
  lea di, currentUserDirPath                  ; Get a pointer to the current user directory
  add di, ax                                  ; Make the pointer point to the character after the last one

.copy:
  push si                                     ; Save requested directory string
  push di                                     ; Save offseted current user directory string
  call strcpy                                 ; Copy the requested directory string to the current user directory
  pop di                                      ; Restore offseted current user directory string
  pop si                                      ; Restore requested directory string

  pop ax                                      ; Restore the length of the requested directory string
  add di, ax                                  ; Offset the offseted current user directory, so it points to the character after the last one
  mov byte es:[di], 0                         ; Null terminate the string, in case it wasnt already
  cmp byte es:[di - 1], '/'                   ; Check if it ends with '/'
  je .success                                 ; If it does, then just return

  mov byte es:[di], '/'                       ; Set the last character of the current user directory to '/'
  mov byte es:[di + 1], 0                     ; Null terminate the string because adding a character to it

.success:
  xor ax, ax                                  ; Zero out error code

.end:
  pop es                                      ; Restore used segments
  pop ds                                      ;
  jmp ISR_kernelInt_end_restBX                ; Return

%endif