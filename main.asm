.model tiny

; Agreement on code comments:
;   [8] refers to Tom Swan's book "Mastering Turbo Assmbler, 2nd edition"

TAIL_BYTES EQU 80h
TAIL_START EQU 81h
TAIL_LENGTH EQU 127

.data?
    ; Define variables
    ;   Declaring uninitialized variables decrease the file size
    ;   [8], page 25
    filename  db TAIL_LENGTH DUP(?)
    code      db 10000 DUP(?)
    cells     db 10000 DUP(?)
    ; TODO: investigate `mov cx, 10000` -> `cld` -> `rep stosb`
    ; Book: [8], page: 137

.code
org 100h

main PROC
    mov ax, cs
    mov es, ax

    xor   bx, bx
    mov   bl, [0h:TAIL_BYTES]
    mov   al, '$'
    mov   byte [bx+TAIL_START], al
    
    call readCommandTail

    xor   ax, ax
    mov   ah, 9
    mov   dx, offset filename
    int   21h

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
    ;   [filename] string    
    cld                         ; clear direction (flag)
    mov si, TAIL_START          ; read from the tail start
    mov di, offset filename     ; write to variable
    mov cx, TAIL_LENGTH         ; set counter to length of tail
    rep movsb
    ret
readCommandTail ENDP


decodeCommand PROC NEAR
    xor ax, ax
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
