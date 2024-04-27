;
; --------- [ WRITE A DATA BUFFER INTO A CLUSTER CHAIN ] ----------
;

%ifndef WRITE_CLUSTER_BYTES_ASM
%define WRITE_CLUSTER_BYTES_ASM

; Write a data buffer to a cluster chain on a given offset
; PARAMETERS
;   - 0) DI     => The files first cluster number
;   - 1) DS:SI  => The data buffer
;   - 2) DX     => The offset to write the data on the file (in bytes)
;   - 3) CX     => The amount of bytes to write to the file, from the buffer
writeClusterBytes:
  


.end:
  ret


%endif