;
; ---------- [ MANAGE PROCESSES ] ---------
;

%ifndef PROCESS_ASM
%define PROCESS_ASM

; Create a new process from an executable
; PARAMS
;   - 0) ES:DI  => A path to the processes binary
;   - 1) DS:SI  => Argument list for the new process
;   - 2) DX     => Amount of arguments in the arguments list
;   - 3) CL     => Flags for the new process
;   - 4) BX     => The segment of each argument
; RETURNS
;   - 0) AX   => A handle to the new process, null on error
;   - 1) BX   => The error code
createProcess:
  push bp                                                         ; Save stack frame
  mov bp, sp                                                      ;
  sub sp, 16                                                      ; Allocate 10 bytes for local stuff

  mov [bp - 2], es                                                ; Save file name
  mov [bp - 4], di                                                ; Save offset
  mov [bp - 5], cl                                                ; Save flags
  mov [bp - 7], ds                                                ; Save argument list segment
  mov [bp - 12], si                                               ; Save argument list offset
  mov [bp - 14], dx                                               ; Save amount of arguments
  mov [bp - 16], bx                                               ; Save segment of each argument

  mov bx, KERNEL_SEGMENT                                          ; DS will be used as the kernels segment
  mov ds, bx                                                      ;
  lea si, processes                                               ; Get a pointer to the processes array
  mov cx, PROCESS_DESC_LEN                                        ; Get the length of the processes array
.searchEmpty:
  test byte ds:[si + PROCESS_DESC_FLAGS8], PROCESS_DESC_F_ALIVE   ; Check if the current process in the array is alive
  jz .foundEmpty                                                  ; If not, then the process is empty

  add si, PROCESS_DESC_SIZEOF                                     ; If the process is alive, make the process pointer point to the next process
  loop .searchEmpty                                               ; Continue until there are no more processes left to check

  jmp .err                                                        ; If there are no more processes to check, return null to indicate an error

.foundEmpty:
  mov [bp - 10], si                                               ; Save the pointer to the free process 
  mov [bp - 8], cl                                                ; Save the amount of processes left to check (will be used for calculating the index)
  mov es, [bp - 2]                                                ; Get a pointer to the files path
  mov di, [bp - 4]                                                ; Get offset
  mov si, FILE_OPEN_ACCESS_READ                                   ; We only need to read the file, so request read access for the file
  call fopen                                                      ; Open the file
  test ax, ax                                                     ; Check if the handle is null
  jnz .fileOpened                                                         ; If it is, return it (its already set to 0)

  mov bx, ERR_FILE_NOT_FOUND
  jmp .err

.fileOpened:
  push ax                                                         ; Save the files handle
  mov dx, ax                                                      ; Get the handle in DX, for the fread function
  mov si, [bp - 10]                                               ; Get a pointer to the free process descriptor
  mov es, ds:[si + PROCESS_DESC_REG_CS16]                         ; Get the segment of the free process
  mov di, PROCESS_LOAD_OFFSET                                     ; Set the buffer offset to the offset that processes are loaded in (100h for DOS)
  mov si, 0FFFFh - PROCESS_LOAD_OFFSET                            ; Set the amount of bytes to read to the maximum amount that we can fit
  call fread                                                      ; Read the file into the process space

  pop di                                                          ; Restore file handle
  push ax                                                         ; Save the amount of bytes read
  call fclose                                                     ; Close the file
  pop ax                                                          ; Restore amount of bytes read
  test ax, ax                                                     ; Check if it was 0
  jnz .fileRead                                                   ; If it was 0, return it (which is set to 0)

  mov bx, ERR_EMPTY_FILE
  jmp .err

.fileRead:
  cli
  mov si, [bp - 10]                                               ; Get a pointer to the free process descriptor
  mov al, [bp - 5]                                                ; Get the requested flags for the process
  or al, PROCESS_DESC_F_ALIVE                                     ; Set the processes ALIVE flag
  mov ds:[si + PROCESS_DESC_FLAGS8], al                           ; Write the flags to the process
  mov word ds:[si + PROCESS_DESC_REG_IP16], PROCESS_LOAD_OFFSET   ; Set the initial value of ip to the load offset
  mov word ds:[si + PROCESS_DESC_REG_SP16], PROCESS_LOAD_OFFSET   ; Set the initial value of sp to the load offset
  mov word ds:[si + PROCESS_DESC_SLEEP_MS16], 0                   ; Set the processes sleep time to 0 (its now asleep)

  mov ax, [bp - 7]                                                ; Get arguments array segment
  mov ds:[si + PROCESS_DESC_REG_AX16], ax                         ; Set processes AX register to the arguments array segment

  mov ax, [bp - 12]                                               ; Get arguments array offset
  mov ds:[si + PROCESS_DESC_REG_BX16], ax                         ; Set processes BX register to the arguments array offset

  mov ax, [bp - 14]                                               ; Get the amount of arguments in the argument array
  mov ds:[si + PROCESS_DESC_REG_CX16], ax                         ; Set the CX register to it

  mov ax, [bp - 16]                                               ; Get the segment of each argument offset
  mov ds:[si + PROCESS_DESC_REG_DX16], ax                         ; Set DX to it

  mov bl, [bp - 8]                                                ; Get the amount of processes left to check (from the search loop)
  mov al, PROCESS_DESC_LEN                                        ; Get the amount of processes in general
  sub al, bl                                                      ; Subtract the amount of processes left, from the amount of processes (to get the index)
  inc al                                                          ; Increase by 1, because handles start from 1
  sti                                                             ; Enable interrupts, because disabled it before

  xor bx, bx                                                      ; Zero out error code
.end:
  mov es, [bp - 2]                                                ; Restore used segments
  mov ds, [bp - 7]                                                ;
  mov sp, bp                                                      ; Restore stack frame
  pop bp                                                          ;
  ret

.err:
  xor ax, ax                                                      ; If there is an error, return 0
  jmp .end                                                        ; Return



; Stop a running process.
; PARAMETERS
;   - 0) DI     => The processes PID
;   - 1) SI     => Exit code
; RETURNS
;   - 0) The error code. (0 on success)
terminateProcess:
  push gs                                         ; Save GS, because were gonna change it
  mov bx, KERNEL_SEGMENT                          ; Set GS to the kernels segment, so we can access the processes array
  mov gs, bx                                      ;

  mov cx, si
  cmp di, 1                                       ; Check if the handle is one or 0, because 0 is invalid
  jbe .err                                        ; and 1 is the kernels PID. If its 1 or 0 then return an error

  cmp di, PROCESS_DESC_LEN                        ; Check if the PID exceeds the amount of processes
  ja .err                                         ; If it is, return an error

  mov ax, di                                      ; Get the PID in AX
  dec ax                                          ; Convert it into an index
  mov bx, PROCESS_DESC_SIZEOF                     ; We want to multiply by the size of a process descriptor
  mul bx                                          ; Get the offset into the processes array, for the current process (offset in AX)

  lea si, processes                               ; Get a pointer to the processes array
  add si, ax                                      ; Offset it into the current process

  mov byte gs:[si + PROCESS_DESC_FLAGS8], 0       ; Set the processes flags to 0
  mov word gs:[si + PROCESS_DESC_SLEEP_MS16], 0   ; Set its sleep time to 0
  mov gs:[si + PROCESS_DESC_EXIT_CODE8], cl

  mov ax, gs:[si + PROCESS_DESC_SEG16]
  mov gs:[si + PROCESS_DESC_REG_DS16], ax
  mov gs:[si + PROCESS_DESC_REG_ES16], ax
  mov gs:[si + PROCESS_DESC_REG_GS16], ax
  mov gs:[si + PROCESS_DESC_REG_FS16], ax
  mov gs:[si + PROCESS_DESC_REG_SS16], ax
  mov gs:[si + PROCESS_DESC_REG_CS16], ax


  xor ax, ax

.end:
  pop gs                                          ; Restore GS
  ret

.err:
  mov ax, ERR_INVALID_PID                         ; In this function, the only error thats possible is an invalid PID
  jmp .end                                        ; Return with the error code


; Terminate the currently running process
; PARAMETERS
;   - 0) DI   => The error code, lower 8 bits only
; RETURNS
;   - 0) AX   => The error code, 0 on success
terminateCurrentProcess:
  mov si, di
  push gs                                         ; Save current GS because were changing it
  mov bx, KERNEL_SEGMENT                          ; Set GS to the kernels segment so we can access the currently running process
  mov gs, bx                                      ;
  mov di, gs:[currentProcessIdx]                  ; Get the current process index
  inc di                                          ; Convert it into a PID
  and di, 0FFh                                    ; PID is only 8 bits
  pop gs                                          ; Restore GS

  call terminateProcess                           ; Terminate the process
  ret

%endif