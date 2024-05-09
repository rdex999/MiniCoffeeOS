%include "shared/interrupts.asm"

%define FPS 30

org 100h

main:
  ; Dont realy need this, but its good practice
  push bp                                         ; Save stack frame
  mov bp, sp                                      ;

  ;;;;; DEBUG
  mov ax, INT_N_GET_LOW_TIME
  int INT_F_KERNEL
  mov [secCntTime], ax

  ; This loop runs on 30 FPS
shellFPSloop:

  ;;;;;; DEBUG 
  mov di, 12
  xor si, si
  mov ax, INT_N_SET_CURSOR_LOCATION
  int INT_F_KERNEL 
  
  ; Get the start time of the current iteration
  mov ax, INT_N_GET_LOW_TIME                      ; Interrupt number for the current MS
  int INT_F_KERNEL                                ; Get the current MS (seconds * 1000 + milliseconds)
  mov [prevStartTime], ax                         ; Store it

  inc word [fpsCnt]

  ; ;;;;;; DEBUG
  sub ax, [secCntTime]
  jz shellFPSloop_delay
  cmp ax, 1000
  jb shellFPSloop_delay

  push word [fpsCnt] 
  push word fpsStr
  mov ax, INT_N_PRINTF
  int INT_F_KERNEL
  add sp, 4

  mov byte [fpsCnt], 0
  mov ax, INT_N_GET_LOW_TIME
  int INT_F_KERNEL
  mov [secCntTime], ax

shellFPSloop_delay:
  ; To calculate the amount of delay to put between each frame: delay = (currentTime - prevTime) - (1000 / FPS)
  mov ax, INT_N_GET_LOW_TIME                      ; Interrupt number for getting the current time
  int INT_F_KERNEL                                ; Get the current time (seconds * 1000 + milliseconds) in AX

  sub ax, [prevStartTime]                         ; Subtract from it the previous time (the time when starting the loop)
  mov di, 1000 / FPS                              ; Get the milliseconds delay between each frame on FPS fps
  sub di, ax                                      ; Subtract from it the time that we were it the loop
  mov ax, INT_N_SLEEP                             ; Interrupt number for pausing the process
  int INT_F_KERNEL                                ; Pause the process for the delay we just calculated
  jmp shellFPSloop                                ; Continue drawing frames and stuff

main_end:
  mov sp, bp                                      ; Restore stack frame (dont realy need this but good practice)
  pop bp                                          ;
  mov ax, INT_N_EXIT                              ; Interrupt number for terminating the process
  int INT_F_KERNEL                                ; Exit out of the process

;
; ---------- [ DATA SECTION ] ---------
;

timeAndDate:                db "20%u-%u-%u   %u:%u:%u  ", 0
prevStartTime:              dw 0
secCntTime: dw 0
fpsCnt: dw 0
fpsStr: db "shell fps: %u", 0Ah, 0