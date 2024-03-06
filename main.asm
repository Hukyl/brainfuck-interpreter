.model tiny


;;;;;;;;;;;;;;;;;;;;;;; Constants ;;;;;;;;;;;;;;;;;;;;;;;;;;;;
CODE_SIZE   EQU 10000
CELLS_SIZE  EQU 10000

TAIL_START  EQU 81h
TAIL_LENGTH EQU 127

CR          EQU 13
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.data?
    code        db CODE_SIZE      DUP(?)
    cells       dw CELLS_SIZE     DUP(?)
    ; TODO: investigate `mov cx, 10000` -> `cld` -> `rep stosb`
    ; Book: [8], page: 137

.code
    org 100h        ; Account for 255 bytes of PSP

main:
    mov bx, cs      ; IMPORTANT: do not change `ds` before `readCommandTail`
    mov es, bx      ; Since variables are stored in the code segment
clearUninitializedVariables:
    mov di, offset code
    mov cx, CODE_SIZE+CELLS_SIZE*2       ; length of uninitialized data
    ; assume ax=0
    rep stosb
;endp

prepareFilename:
    ; Make filename ASCIIZ
    mov dx, TAIL_START+1                    ; Account for first whitespace
    mov si, dx
    mov cl, byte ptr [ds:TAIL_START-1]
    add si, cx                              ; length of command tail
    mov byte ptr [si-1], 0
;endp

readCode:
    mov ax, 3D00h           ; ah = Open file DOS function, al = Read-only mode
    int 21h
    ; No error checking, since is guaranteed by requirements
    mov ds, bx              ; move CS to DS
    mov bx, ax              ; File handle
    mov ah, 3Fh             ; Read file DOS function
    mov cx, CODE_SIZE       ; Number of bytes to read
    mov dx, offset code     ; Where to store the code
    mov si, dx              ; Prepare si for decodeLoop
    int 21h
    mov ah, 3Eh             ; Close file DOS function
    ; bx is preset to file handle
    int 21h
; end of proc

    mov di, offset cells
; .data block, but with registers
    mov ah, 0       ; isHalted
    xor bp, bp      ; loopCounter
    mov cx, 1       ; direction OR number of bytes for I/O
; end .data

decodeLoop:
    mov al, byte [si-1]
    add si, cx
    ; lodsb   ; al <- [ds:si], si <- si + 1
    call decodeCommand
    cmp al, 0
    jne decodeLoop
    int 20h

decodeCommand PROC
    ; Input:
    ;   al - command char
    ;   si - command address
    ;   di - cell address
    ; Registers used:
    ;   bx - loop counter on start of halt OR file handle (when one is used, the other one is not)
    ;   bp - loop counter
    ;   ah - whether to execute next command (ignored for `[` and `]`)
    ;   cx - direction OR number of bytes for I/O
    ; Output:
    ;   None
    cmp al, '['
    je SHORT startLoop
    cmp al, ']'
    je SHORT endLoop

    cmp ah, 1       ; check if isHalted
    jne modifyingCommands
    ret

modifyingCommands:
    cmp al, '>'
    je SHORT incrementPointer
    cmp al, '<'
    je SHORT decrementPointer
    cmp al, '+'
    je SHORT incrementValue
    cmp al, '-'
    je SHORT decrementValue
    
    ; If we reached here, we know that isHalted=0
    mov dx, di
    cmp al, '.'
    je SHORT writeChar
    cmp al, ','
    je SHORT readChar
    ret

incrementPointer:
    add di, 2
    ret

decrementPointer:
    sub di, 2
    ret

incrementValue:
    inc word ptr [di]
    ret

decrementValue:
    dec word ptr [di]
    ret

writeChar:
    mov ah, 40h     ; Write to file DOS function
    mov bx, 1       ; Stdout     
    int 21h
    jmp SHORT _io_commands_exit

readChar:
    mov ah, 3Fh     ; Read from file DOS function        
    mov bx, 0       ; Stdin
    int 21h
    cmp byte ptr [di], CR
    jne _io_commands_exit
    mov word ptr [di], 0FFFFh

_io_commands_exit:
    mov ah, 0       ; Restore isHalted
    ret

startLoop:
    ; If execution is not halted
    ;   If cell == 0
    ;       halt execution
    ;       remember loop counter on halt
    ;       increment loop counter
    ;   else
    ;       increment loop counter
    ; else
    ;   if direction flag is set (moving backwards)
    ;       if loop counter == loop counter on halt
    ;           decrement loop counter
    ;           si += 1
    ;           clear direction flag
    ;           ret
    ;       else
    ;           decrement loop counter
    ;   else
    ;       increment loop counter
    cmp ah, 1       ; check if halted
    je SHORT _sl_halted

    ; If execution is not halted (other branch in _sl_halted)
    cmp word ptr [di], 0
    jne SHORT _incrementLoopCounter

    ; If cell == 0
    mov ah, 1       ; Halt execution
_rememberLoopCounter:
    mov bx, bp      ; Remember the loop count
    ret

_sl_halted:
    ; If execution is halted
    ; FIXME: check direction flag
    cmp cl, 1                   ; check if moving forward
    je SHORT _incrementLoopCounter
    
    ; If moving backwards
    cmp bx, bp                  ; check if met the same loop beginning
    jne SHORT _decrementLoopCounter

    ; If loop counter == loop counter on halt
    add si, 1                   ; to avoid reading the same bracket
    neg cx                      ; move forward
    mov ah, 0                   ; unhalt
    dec bp                      ; decrement loop counter for it to be incremented upon startLoop
    ret

endLoop:
    ; if execution is halted
    ;   if direction flag is set (moving backwards)
    ;       increment loop counter
    ;   else
    ;       if loop counter == loop counter on halt
    ;           decrement loop counter
    ;           unhalt execution
    ;           ret
    ;       else
    ;           decrement loop counter 
    ; else
    ;   set direction flag
    ;   halt execution
    ;   remember loop counter on halt
    ;   si -= 2
    cmp ah, 1       ; check whether is halted
    je SHORT _el_halted

    ; If not halted
    neg cx          ; move backwards
    mov ah, 1       ; halt
    sub si, 2       ; to avoid reading the same bracket
    jmp SHORT _rememberLoopCounter
_el_halted:
    ; If halted
    cmp cl, 1                   ; Check direction
    jne SHORT _incrementLoopCounter

    ; if moving forward
    cmp bx, bp                  ; If met the same loop
    jne SHORT _decrementLoopCounter

    ; Found end of loop
    mov ah, 0                   ; unhalt
    ret

    ; For 80386/486 processor (replace after `cmp`) (decrease by 1 instruction):
    ; setnz cl        ; unhalt if equal, else keep halting
    ; jne exitDecode
    ; dec sp
    ; ret

_incrementLoopCounter:
    inc bp
    ret

_decrementLoopCounter:
    dec bp
    ret

decodeCommand ENDP

END main