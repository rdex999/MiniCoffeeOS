;
; ---------- [ ADD CLUSTERS TO A CLUSTER CHAIN ] ----------
;

%ifndef ADD_CLUSTERS_ASM
%define ADD_CLUSTERS_ASM

; Add N clusters to a cluster chain
; PARAMS
;   - 0) DI   => First cluster of the chain (or any cluster in the chain)
;   - 1) SI   => The amount of clusters to add
; RETURNS
;   - 0) In AX, the first cluster that was added. Will return 0 on error.
addClusters:
  push bp                           ; Save stack frame
  mov bp, sp                        ;
  sub sp, 6                         ; Allocate space for local stuff

  mov [bp - 2], di                  ; Save first cluster (will be used as the last cluster in the addClusters loop)
  mov [bp - 4], si                  ; Save amount of clusters to add
  mov word [bp - 6], 0              ; Initialize first added cluster to 0

  cmp di, 2                         ; Check if the given cluster is valid
  jb .err                           ; If not, return 0 (as an error)

  test si, si                       ; Check if the amount of clusters to add is 0
  jz .err                           ; If it is, return 0

  cmp di, FAT_CLUSTER_INVALID       ; Check if the given cluster is the end of a cluster chain
  jae .err                          ; If it is then return 0 (as an error)

.getLastLoop:
  ; In this loop we get the last cluster in the chain (which will be stored at *(bp - 2))
  call getNextCluster               ; Get the next cluster. When getting here the current cluster must be in DI
  test bx, bx                       ; Check error code
  jnz .err                          ; If there was an error, return with it

  cmp ax, FAT_CLUSTER_INVALID       ; If there was no error, check if the next cluster is the end of the chain
  jae .addClusters                  ; If it is, exit out of the loop

  mov [bp - 2], ax                  ; If its not the end of the chain, save the next cluster as the current cluster
  mov di, ax                        ; Get it also in DI, as the parameter for getNextCluster
  jmp .getLastLoop                  ; Continue as long as its not the end of the chain

  ; When getting here, the last cluster number is stored at *(bp - 2)
.addClusters:
  mov di, FAT_CLUSTER_END           ; The value to set the next cluster, for the free one we will get
  call getFreeCluster               ; Get a free cluster in AX, and set the next one for it to the value in DI
  test ax, ax                       ; Check is the free cluster is valid
  jz .err                           ; If not, return 0 as an error

  cmp word [bp - 6], 0              ; Check if the first cluster that was added is 0
  jnz .setCluster                   ; If not, then skip setting it (that way *(bp - 6) will store the first cluster that was added)

  mov [bp - 6], ax                  ; If it is unset, then set it

.setCluster:
  mov di, [bp - 2]                  ; Get the current cluster (not the free one) as a parameter for setCluster
  mov [bp - 2], ax                  ; Set the current cluster to the free one
  mov si, ax                        ; The new value for the current cluster, the free one
  call setCluster                   ; Make the current cluster point to the free one, which points to FAT_CLUSTER_END
  test ax, ax                       ; Check error code of setCluster
  jnz .err                          ; If there was an error, return 0

  dec word [bp - 4]                 ; Decrement the amount of clusters to add
  jnz .addClusters                  ; As long as its not 0, continue adding clusters

  mov ax, [bp - 6]                  ; Get the first cluster that was added, as the return value

.end:
  mov sp, bp                        ; Restore stack frame
  pop bp                            ;
  ret

.err:
  xor ax, ax                        ; If there was an error, return 0
  jmp .end

%endif