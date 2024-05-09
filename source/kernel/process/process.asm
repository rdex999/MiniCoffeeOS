;
; ---------- [ MANAGE PROCESSES ] ---------
;

%ifndef PROCESS_ASM
%define PROCESS_ASM

; Create a new process from an executable
; PARAMS
;   - 0) ES:DI  => A path to the processes binary
;   - 1) SI     => Flags for the new process
; RETURNS
;   - 0) AX   => A handle to the new process, null on error
createProcess:
  push bp                                                         ; Save stack frame
  mov bp, sp                                                      ;
  sub sp, 10                                                      ; Allocate 10 bytes for local stuff

  mov [bp - 2], es                                                ; Save file name
  mov [bp - 4], di                                                ; Save offset
  mov ax, si                                                      ; Get the flags in AL
  mov [bp - 5], al                                                ; Save flags
  mov [bp - 7], ds                                                ; Save used DS segment

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
  jz .end                                                         ; If it is, return it (its already set to 0)

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
  jz .end                                                         ; If it was 0, return it (which is set to 0)

  mov si, [bp - 10]                                               ; Get a pointer to the free process descriptor
  mov al, [bp - 5]                                                ; Get the requested flags for the process
  or al, PROCESS_DESC_F_ALIVE                                     ; Set the processes ALIVE flag
  mov ds:[si + PROCESS_DESC_FLAGS8], al                           ; Write the flags to the process
  mov word ds:[si + PROCESS_DESC_REG_IP16], PROCESS_LOAD_OFFSET   ; Set the initial value of ip to the load offset
  mov word ds:[si + PROCESS_DESC_REG_SP16], PROCESS_LOAD_OFFSET   ; Set the initial value of sp to the load offset
  mov word ds:[si + PROCESS_DESC_SLEEP_MS16], 0                   ; Set the processes sleep time to 0 (its now asleep)
  mov bl, [bp - 8]                                                ; Get the amount of processes left to check (from the search loop)
  mov al, PROCESS_DESC_LEN                                        ; Get the amount of processes in general
  sub al, bl                                                      ; Subtract the amount of processes left, from the amount of processes (to get the index)
  inc al                                                          ; Increase by 1, because handles start from 1

.end:
  mov es, [bp - 2]                                                ; Restore used segments
  mov ds, [bp - 7]                                                ;
  mov sp, bp                                                      ; Restore stack frame
  pop bp                                                          ;
  ret

.err:
  xor ax, ax                                                      ; If there is an error, return 0
  jmp .end                                                        ; Return


%endif