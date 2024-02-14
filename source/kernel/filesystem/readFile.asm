;
; ---------- [ FUNCTION FOR READING A FILE ] -----------
;

%ifndef FILESYSTEM_READFILE_ASM
%define FILESYSTEM_READFILE_ASM

; Searches for a file and loads it to memory at buffer 
; PARAMS
;   - 0) DS:DI     => file name, 11 bytes all capital
;   - 1) ES:BX  => buffer to store data in
; RETURNS
; 0 on success and 1 on failure.
readFile:
  push bp
  mov bp, sp

  sub sp, 12                ; allocate 8 bytes
  mov [bp - 2], di          ; store file name
  mov [bp - 4], bx          ; store buffer pointer offset
  mov [bp - 6], es          ; store buffer pointer segment
  mov [bp - 10], ds         ; Store file name segment

  mov bx, KERNEL_SEGMENT
  mov es, bx 

  sub sp, es:[bpb_bytesPerSector]    ; Allocate memory for 1 sector, for reading the root directory

  mov bx, [bp - 10]               ;
  mov es, bx                      ; File name segment

  mov di, [bp - 2]                ; ES:DI Points to file name string (file name in *(bp - 2))
  mov bx, ss                      ;
  mov ds, bx                      ; Set data segment to stack segment, because the root directory is in the stack segment
  mov si, sp                      ; DS:SI points to root directory location
  call searchInRootDir

  test bx, bx                     ; Check return status of searchInRootDir
  jnz readFile_error              ; If the return status of searchInRootDir is not 0 then return 1, otherwise continue

  mov bx, KERNEL_SEGMENT          ; Make segments point to where the kernel is
  mov ds, bx                      ;
  mov es, bx                      ;
  
  mov di, ax                      ; searchInRootDir returns pointer to the directory entry in AX
  mov di, ss:[di + 26]            ; Get the low 16 bits of the first cluster number, First agument for ReadClusterChain

  mov bx, [bp - 6]                ; ES:BX points to receiving data buffer, 
  mov es, bx                      ; set it to the buffer that was passed to this function.
  mov bx, [bp - 4]                ; Set buffer offset
  call ReadClusterChain           ; Process the cluster chain from the first cluster number (DI) and save data to buffer
  test ax, ax                     ; Check exit code of ReadClusterChain
  jnz readFile_end                ; If its not zero then return this error code.
  xor ax, ax                                  ; Read was successful, return 0
readFile_end:
  ; Set segments to original value
  mov dx, [bp - 6]                            ; ES segment original value
  mov es, dx                                  ;
  mov dx, [bp - 10]                           ; Data segment original value
  mov ds, dx                                  ;
  mov sp, bp
  pop bp
  ret

readFile_error:
  mov ax, 1                               ; Read has failed, return 1
  jmp readFile_end


%endif