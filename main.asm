.model tiny

; Agreement on code comments:
;   [8] refers to Tom Swan's book "Mastering Turbo Assmbler, 2nd edition"


;;;;;;;;;;;;;;;;;;;;;;; Constants ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CODE_SIZE   EQU 10000
CELLS_SIZE  EQU 10000

TAIL_BYTES  EQU 80h
TAIL_START  EQU 81h
TAIL_LENGTH EQU 127

CR          EQU 13
LF          EQU 10
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


.data?
    ; Define variables
    ;   Declaring uninitialized variables decrease the file size
    ;   [8], page 25
    filename  db TAIL_LENGTH    DUP(?)
    code      db CODE_SIZE      DUP(?)
    cells     dw CELLS_SIZE     DUP(?)
    ; TODO: investigate `mov cx, 10000` -> `cld` -> `rep stosb`
    ; Book: [8], page: 137


.code
org 100h

main PROC
    mov ax, cs      ; IMPORTANT: do not change `ds` before `readCommandTail`
    mov es, ax      ; Since variables are stored in the code segment
    
    call readCommandTail

    mov ds, ax

    call readCode

    ; Possible replace to `int 20h`
    ; mov ax, 4C00h  ; Close and flish all open file handles.
    ; int 21h
    ret
main ENDP


readCommandTail PROC
    ; Input: 
    ;   none
    ; Registers used:
    ;   si, di, cx
    ; Output: 
    ;   [filename] ASCIIZ string
    cld                         ; clear direction (flag)
    mov si, TAIL_START+1        ; read from tail start (ignore leading whitespace)
    mov di, offset filename     ; write to variable
    mov cl, byte [si-3]         ; number of bytes to read (ignore ^Z and whitespace char)
    dec cx
    rep movsb
    ret
readCommandTail ENDP


readCode PROC
    ; Input: 
    ;   [filename] string
    ; Registers used:
    ;   ax, dx, bx, cx
    ; Output: 
    ;   [code] ASCIIZ string
    lea dx, filename
    mov ah, 03Dh        ; Open file DOS function
    mov al, 0           ; Read-only mode
    int 21h

    ; No error checking, since is guaranteed by requirements
    mov bx, ax          ; File handle
    mov ah, 3Fh         ; Read file DOS function
    mov cx, CODE_SIZE   ; Number of bytes to read
    lea dx, code        ; Where to store the code
    int 21h

    mov ah, 3Eh         ; Close file DOS function
    ; bx is preset to file handle
    int 21h
    ret
readCode ENDP


decodeCommand PROC NEAR
    ; Input:
    ;   [code] ASCIIZ string
    ; Registers used:
    ;   ax, bx - temporary registers
    ;   cx - command index
    ;   dx - cell index
    ;   si, di - string I/O
    ; Output:
    ;   None
    mov cl, code
    mov dx, cells

decodeCommand ENDP


increment PROC NEAR
    xor ax, ax
increment ENDP


decrement PROC NEAR
    xor ax, ax
decrement ENDP


incrementPointer PROC NEAR
    xor ax, ax
incrementPointer ENDP


decrementPointer PROC NEAR
    xor ax, ax
decrementPointer ENDP


startLoop PROC NEAR
    xor ax, ax
startLoop ENDP


endLoop PROC NEAR
    xor ax, ax
endLoop ENDP


writeChar PROC NEAR
    xor ax, ax
writeChar ENDP


readChar PROC NEAR
    xor ax, ax
readChar ENDP


exit PROC NEAR
    xor ax, ax
exit ENDP


END main
