;
; ---------- [ OPEN A FILE FOR A REQUESTED MODE ] ----------
;

; Open a file from the filesystem in a specific mode.
; FILE ACCESS
;   0 Read ("r")
;   1 Write ("w")
;   2 Append ("a")
;   3 Read Write, must exist ("r+")
;   4 Read Write ("w+")
;   5 Append Read ("a+")
; PARAMETERS
;   - 0) ES:DI    => The path to the file, doesnt have to be formatted. Null terminated string.
;   - 1) SI       => Access for the file.
; RETURNS
;   - 0) In AX, the file handle. BX is the error code.(0 on no error)
fopen:
  push gs
  mov bx, KERNEL_SEGMENT
  mov gs, bx




.end:
  pop gs
  ret