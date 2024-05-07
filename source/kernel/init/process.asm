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
  lea si, processes                               ; Get a pointer to the processes array

  mov ax, KERNEL_SEGMENT                          ; Reset ES to the kernels segment
  mov es, ax                                      ;

%%processesInit_nextSeg:
  mov es:[si + PROCESS_DESC_SEG16], bx            ; Set the current process descriptor segment to the free segment
  mov byte es:[si + PROCESS_DESC_FLAGS8], 0

  add bx, 1000h                                   ; Get the next free segment

  add si, PROCESS_DESC_SIZEOF                     ; Make the processes descriptor pointer point to the next process descriptor

  cmp bx, 9FC0h - 1000h                           ; Check if the next segment is overlapping with the EBDA
  jb %%processesInit_nextSeg                      ; As long as it doesnt overlap it, continue setting processes descriptors

%%processesInit_end:
  pop es                                          ; Restore ES

%endmacro