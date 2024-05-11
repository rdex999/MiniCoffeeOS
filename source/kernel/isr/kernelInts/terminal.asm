;
; ---------- [ TERMINAL RELATED INTERRUPTS ] ----------
;

%ifndef TRM_ASM
%define TRM_ASM

; Clear the screen
; Takes no parameters
; Doesnt return anything
ISR_trmClear:
  call clear                  ; Clear the screen
  jmp ISR_kernelInt_end       ; Return from the interrupt


; Get the current color of the terminal
; Doesnt take any parameters
; RETURNS
;   - 0) AX   => The color, lower 8 bits only (AL). 
;        The low 4 bits are the text color, and the high 4 bits are the background color
ISR_trmGetColor:
  push fs                       ; Push FS because changing it for a sec
  mov bx, KERNEL_SEGMENT        ; Set FS to the kernels segment so we can access the terminals color
  mov fs, bx                    ;

  mov al, fs:[trmColor]         ; Get the terminals color
  xor ah, ah                    ; Zero out high 8 bits
  pop fs                        ; Restore FS
  jmp ISR_kernelInt_end_restBX  ; Return from the interrupt
  


; Set the terminal color
; PARAMS
;   - 0) DI   => The color, low 4 bits are the text color and the high 4 bits are the background color
; Doesnt return anything
ISR_trmSetColor:
  push fs                     ; Save FS because changing it for a sec
  mov bx, KERNEL_SEGMENT      ; Set FS to the kernels segment so we can access the terminals color
  mov fs, bx                  ;

  mov ax, di                  ; Get the requested color in AL
  mov fs:[trmColor], al       ; Set the terminal color to the requested color
  pop fs                      ; Restore FS
  jmp ISR_kernelInt_end       ; Return from the interrupt


; Execute a system command
; PARAMETERS
;   - 0) ES:DI  => The command string
; RETURNS
;   - 0) AX     => The exit code of the command
ISR_system:
  call system
  jmp ISR_kernelInt_end_restBX


; Get the last exit code a command has returned
; Takes no parameters
; RETURNS
;   - 0) AX     => The exit c
ISR_getExitCode:
  push gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx

  mov al, gs:[cmdLastExitCode]
  xor ah, ah
  pop gs
  jmp ISR_kernelInt_end_restBX

%endif