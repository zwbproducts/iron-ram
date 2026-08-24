; secure_wipe.asm — Secure backward stack wipe (16-bit real-mode port)
; void *secure_wipe16(void *stack_dest, size_t wipe_count)
;
; Port of libmem/secure_wipe_stack_rev.asm.
;
; DSE-Prevention Architecture (mirrored from libmem):
;
;   ┌─────────────────────┐    extern memset_rev16    ┌─────────────────────┐
;   │  secure_wipe16      │ ─────────────────────────→│  memset_rev16       │
;   │  (separate label,    │    (black-box call the     │  (forward/backward   │
;   │   opaque boundary)   │     compiler can't see)    │   fill routine)      │
;   └─────────────────────┘                            └─────────────────────┘
;
; Because memset_rev16 is declared  extern  (an unresolved symbol the
; assembler/linker treats as opaque), Dead-Store Elimination cannot
; strip the wipe even when the caller has no further use of the buffer.
;
; Register convention: DI=dest  CX=count   (AL set to 0 internally)

global secure_wipe16
extern memset_rev16

secure_wipe16:
    push ax
    xor  al, al                ; c = 0
    call memset_rev16          ; memset_rev(dest, 0, count) — opaque call
    pop  ax
    ret
