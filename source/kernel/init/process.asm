;
; ---------- [ INITIALIZE SPACE FOR ALL PROCESSES ] ---------
;

; Initialize 65535 bytes for each process
%macro PROCESSES_INIT 0

  mov bx, KERNEL_SEGMENT
  mov es, bx
  mov gs, bx 
  mov di, kernelEnd + 0Fh
  call getNextSegOff

  lea si, processes

%%processesInit_nextSeg:
  mov gs:[si + PROCESS_DESC_SEG16], es

  mov bx, es
  add bx, 1000h
  jc %%processesInit_end

  mov es, bx
  add si, PROCESS_DESC_SIZEOF

  cmp bx, 9FC0h - 1000h
  jb %%processesInit_nextSeg

%%processesInit_end:

%endmacro