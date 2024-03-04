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

main PROC
    mov bx, cs      ; IMPORTANT: do not change `ds` before `readCommandTail`
    mov es, bx      ; Since variables are stored in the code segment
clearUninitializedVariables:
    mov di, offset code
    mov cx, CODE_SIZE+CELLS_SIZE*2       ; length of uninitialized data
    xor ax, ax
    rep stosb
;endp

prepareFilename:
    ; Make filename ASCIIZ
    mov dx, TAIL_START+1        ; Account for first whitespace
    mov si, dx
    mov cl, byte [si-3]
    dec cl
    add si, cx
    mov byte ptr [si], 0
;endp

readCode:
    mov ax, 3D00h           ; ax = Open file DOS function, al = Read-only mode
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
    mov cl, 0       ; isHalted OR number of bytes for I/O
    mov bp, 1       ; Direction
    mov sp, 0       ; loopCounter
    ; end .data

decodeLoop:
    mov al, byte [si-1]
    add si, bp
    ; lodsb   ; al <- [ds:si], si <- si + 1
    jmp decodeCommand
_afterDecode:
    cmp al, 0
    jne decodeLoop
    ; Possible replace to `int 20h`
    ; mov ax, 4C00h  ; Close and flish all open file handles.
    ; int 21h
    int 20h

decodeCommand:
    ; Input:
    ;   al - command char
    ;   si - command address
    ;   di - cell address
    ; Registers used:
    ;   bx - loop counter on start of halt OR file handle (when one is used, the other one is not)
    ;   sp - loop counter
    ;   cx - whether to execute next command (ignored for `[` and `]`)
    ;   bp - how much for si to move (direction)
    ; Output:
    ;   None
    cmp al, '['
    je SHORT startLoop
    cmp al, ']'
    je SHORT endLoop

    cmp cl, 1       ; check if isHalted
    je SHORT exitDecode

    cmp al, '>'
    je SHORT incrementPointer
    cmp al, '<'
    je SHORT decrementPointer
    cmp al, '+'
    je SHORT incrementValue
    cmp al, '-'
    je SHORT decrementValue
    
    ; If we reached here, we know that isHalted=0,
    ; so we can prepare for I/O
    mov cx, 1       
    mov dx, di
    cmp al, '.'
    je SHORT writeChar
    cmp al, ','
    je SHORT readChar
_io_commands:
    mov cl, 0       ; Restore isHalted to 0

    jmp exitDecode

incrementPointer:
    add di, 2
    jmp SHORT exitDecode

decrementPointer:
    sub di, 2
    jmp SHORT exitDecode

incrementValue:
    inc word ptr [di]
    jmp SHORT exitDecode

decrementValue:
    dec word ptr [di]
    jmp SHORT exitDecode

writeChar:
    mov ah, 40h     ; Write to file DOS function
    mov bx, 1       ; Stdout     
    int 21h
    jmp SHORT _io_commands

readChar:
    mov ah, 3Fh     ; Read from file DOS function        
    mov bx, 0       ; Stdin
    int 21h
    cmp byte ptr [di], CR
    jne _io_commands
    mov word ptr [di], 0FFFFh
    jmp _io_commands

exitDecode:             ; Short jump to exitDecode from all commands
    jmp _afterDecode    ; Long jump to end of decoding current command

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
    ;           si += 2
    ;           clear direction flag
    ;           jmp startLoop
    ;       else
    ;           decrement loop counter
    ;   else
    ;       increment loop counter
    cmp cl, 1       ; check if halted
    je SHORT _sl_halted

    ; If execution is not halted (other branch in _sl_halted)
    cmp word ptr [di], 0
    jne SHORT _incrementLoopCounter

    ; If cell == 0
    mov cl, 1       ; Halt execution
_rememberLoopCounter:
    mov bx, sp      ; Remember the loop count
    jmp SHORT exitDecode

endLoop:
    ; if execution is halted
    ;   if direction flag is set (moving backwards)
    ;       increment loop counter
    ;   else
    ;       if loop counter == loop counter on halt
    ;           decrement loop counter
    ;           unhalt execution
    ;           jmp exitDecode
    ;       else
    ;           decrement loop counter 
    ; else
    ;   set direction flag
    ;   halt execution
    ;   remember loop counter on halt
    ;   si -= 2
    cmp cl, 1       ; check whether is halted
    je SHORT _el_halted

    ; If not halted
    neg bp          ; move backwards
    mov cl, 1       ; halt
    sub si, 2       ; to avoid reading the same bracket
    jmp SHORT _rememberLoopCounter
_el_halted:
    ; If halted
    cmp bp, 1                   ; 
    jne SHORT _incrementLoopCounter

    ; if moving forward
    cmp bx, sp                  ; If met
    jne SHORT _decrementLoopCounter

    ; Found end of loop
    mov cl, 0
    jmp SHORT exitDecode

    ; For 80386/486 processor (replace after `cmp`) (decrease by 1 instruction):
    ; setnz cl        ; unhalt if equal, else keep halting
    ; jne exitDecode
    ; dec sp
    ; jmp exitDecode

_sl_halted:
    ; If execution is halted
    cmp bp, 1                   ; check if moving forward
    je SHORT _incrementLoopCounter
    
    ; If moving backwards
    cmp bx, sp                  ; check if met the same loop beginning
    jne SHORT _decrementLoopCounter

    ; If loop counter == loop counter on halt
    add si, 2                   ; to avoid reading the same bracket
    neg bp                      ; move forward
    mov cl, 0                   ; unhalt
    dec sp                      ; decrement loop counter for it to be incremented upon startLoop
    jmp SHORT startLoop

_incrementLoopCounter:
    inc sp
    jmp SHORT exitDecode

_decrementLoopCounter:
    dec sp
    jmp SHORT exitDecode

main ENDP

END main