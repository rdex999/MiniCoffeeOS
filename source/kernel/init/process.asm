;
; ---------- [ INITIALIZE SPACE FOR ALL PROCESSES ] ---------
;

; Initialize 65535 bytes for each process
%macro PROCESSES_INIT 0

  push es                                         ; Save used segments
  mov bx, KERNEL_SEGMENT                          ; Set both ES and GS to the kernels segment
  mov es, bx                                      ; ES is set because were using it for the end of the kernels code
  mov di, kernelEnd + 0Fh                         ; and add 0Fh so we dont override the kernel (were ignoring the offset from getNextSegOff)
  call getNextSegOff                              ; Get the first free segment in ES

  mov bx, es                                      ; BX will be used as the segment
  lea si, processes + PROCESS_DESC_SIZEOF         ; Get a pointer to the processes array

  mov ax, KERNEL_SEGMENT                          ; Reset ES to the kernels segment
  mov es, ax                                      ;

  pushf
  mov di, sp
  mov dx, ss:[di]
  popf

%%processesInit_nextSeg:
  mov es:[si + PROCESS_DESC_REG_DS16], bx         ; Reset current process descriptor segments, to the current segment
  mov es:[si + PROCESS_DESC_REG_ES16], bx         ; 
  mov es:[si + PROCESS_DESC_REG_FS16], bx         ; 
  mov es:[si + PROCESS_DESC_REG_GS16], bx         ; 
  mov es:[si + PROCESS_DESC_REG_CS16], bx         ; 
  mov es:[si + PROCESS_DESC_REG_SS16], bx         ; 
  mov es:[si + PROCESS_DESC_REG_FLAGS16], dx
  mov word es:[si + PROCESS_DESC_REG_SP16], PROCESS_LOAD_OFFSET   ; Reset the stack pointer to the load offset, just before where the process is loaded
  mov byte es:[si + PROCESS_DESC_FLAGS8], 0                       ; Set process to dead

  add bx, 1000h                                   ; Get the next free segment

  add si, PROCESS_DESC_SIZEOF                     ; Make the processes descriptor pointer point to the next process descriptor

  cmp bx, 9FC0h - 1000h                           ; Check if the next segment is overlapping with the EBDA
  jb %%processesInit_nextSeg                      ; As long as it doesnt overlap it, continue setting processes descriptors

  mov word es:[processes + PROCESS_DESC_REG_DS16], KERNEL_SEGMENT
  mov word es:[processes + PROCESS_DESC_REG_ES16], KERNEL_SEGMENT
  mov word es:[processes + PROCESS_DESC_REG_FS16], KERNEL_SEGMENT
  mov word es:[processes + PROCESS_DESC_REG_GS16], KERNEL_SEGMENT
  mov word es:[processes + PROCESS_DESC_REG_CS16], cs
  mov word es:[processes + PROCESS_DESC_REG_FLAGS16], dx
  mov byte es:[processes + PROCESS_DESC_FLAGS8], PROCESS_DESC_F_ALIVE

%%processesInit_end:
  pop es                                          ; Restore ES

%endmacro