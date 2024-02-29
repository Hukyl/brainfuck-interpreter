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
    filename    db TAIL_LENGTH    DUP(?)
    code        db CODE_SIZE      DUP(?)
    cells       dw CELLS_SIZE     DUP(?)
    loopCounter dw 0
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

    xor cx, cx
    mov si, offset code
    mov di, offset cells
decodeLoop:
    lodsb   ; al <- [ds:si], si <- si + 1
    call decodeCommand
    cmp al, 0
    jne decodeLoop
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
    mov dx, offset filename
    mov ah, 03Dh        ; Open file DOS function
    mov al, 0           ; Read-only mode
    int 21h

    ; No error checking, since is guaranteed by requirements
    mov bx, ax              ; File handle
    mov ah, 3Fh             ; Read file DOS function
    mov cx, CODE_SIZE       ; Number of bytes to read
    mov dx, offset code     ; Where to store the code
    int 21h

    mov ah, 3Eh         ; Close file DOS function
    ; bx is preset to file handle
    int 21h
    ret
readCode ENDP


decodeCommand PROC NEAR
    ; Input:
    ;   [loopCount] - number of loops
    ;   si - command address
    ;   di - cell address
    ; Registers used:
    ;   see used procedures
    ; Output:
    ;   None

    cmp al, '>'
    je incrementPointer
    cmp al, '<'
    je decrementPointer
    cmp al, '+'
    je incrementValue
    cmp al, '-'
    je decrementValue
    cmp al, '.'
    je writeLabel
    cmp al, ','
    je readLabel
    cmp al, '['
    je start_loop
    cmp al, ']'
    je end_loop
    jmp exitDecode
incrementPointer:
    add di, 2
    jmp exitDecode
decrementPointer:
    sub di, 2
    jmp exitDecode
incrementValue:
    inc word ptr [di]
    jmp exitDecode
decrementValue:
    dec word ptr [di]
    jmp exitDecode
writeLabel:
    call writeChar
    jmp exitDecode
readLabel:
    call readChar
    jmp exitDecode
start_loop:
    inc [loopCounter]
    jmp exitDecode
end_loop:
    call endLoop
exitDecode:
    ret
decodeCommand ENDP


endLoop PROC NEAR
    ; endLoop tries to finish the loop, or jump to the beginning if counter != 0.
    ; Upon seeing inner loops:
    ;   1. Check if [loopCounter] == starting loop count
    ;   2. If not, continue moving to the left.
    ;   3. Else, finish
    ; Input:
    ;   di - cell address
    ;   si - command address
    ;   [loopCounter] - current loop count
    ; Registers used:
    ;   bx - storing starting loop count
    ; Output:
    ;   None

    cmp word ptr [di], 0
    je finishLoop
    dec word ptr [di]
    sub si, 2               ; As si points at char after ]
    mov bx, [loopCounter]   ; Storing counter to account for inner loops
    std                     ; Move si backwards on lodsb
findOpeningBracket:
    lodsb
    cmp al, ']'
    je metInnerLoop
    cmp al, '['
    jne findOpeningBracket
    ; If loopCounter == bx, we reached the start of required loop
    ; Else continue searching
    cmp bx, [loopCounter]
    je resetSI
    dec [loopCounter]
    jmp findOpeningBracket
metInnerLoop:
    ; If we met ending of an inner loop, we have to account for
    ; it by incrementing loopCounter
    inc [loopCounter]
    jmp findOpeningBracket
resetSI:
    cld         ; Move si forward on lodsb
    add si, 2   ; As si points at char before [
    jmp exitLoopProc
finishLoop:
    dec [loopCounter]
exitLoopProc:
    ret
endLoop ENDP


writeChar PROC NEAR
    ; Input:
    ;   di - cell address
    ;   dx - cell address 
    ; Registers used:
    ;   ax, bx, si
    ; Output:
    ;   None
    mov ah, 40h     ; Write to file DOS function
    mov bx, 1       ; Stdout
    mov cx, 1       ; 1 bytes
    mov dx, di
    int 21h
    ret
writeChar ENDP


readChar PROC NEAR
    ; Input:
    ;   di - cell address 
    ; Registers used:
    ;   ax, bx, si
    ; Output:
    ;   None
    ; TODO: DRY
    mov ah, 3Fh     ; Read from file DOS function        
    mov bx, 0       ; Stdin
    mov cx, 1       ; 1 bytes
    int 21h
    ret
readChar ENDP

END main
