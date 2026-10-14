; ==============================================================================================
; BIOS of the Praktik PC, version 2.16-17 (2.16-17_my/pr_bios.rom, 16 KB, CRC32 187319F5)
; Disassembled and commented automatically, with key places checked by hand.
; Line format: SEGMENT:OFFSET  bytes  instruction  ; comment
; ROM image: phys. FC000-FFFFF (mirrored at F4000-F7FFF).
;   The first 8 KB are shown as segment F400 (NMI peripheral emulator, INT 0Fh, font 80-FFh).
;   The second 8 KB are shown as F000:E000-FFFF (main BIOS, IBM PC/XT entry points).
; "probably" marks a hypothesis inferred from the code, not from documentation.
; On-screen messages are quoted in the original Russian (CP866) with an English translation.
; ==============================================================================================
;
; IMPORTANT. The Praktik motherboard power connector looks like the standard IBM PC 5.25-inch floppy
;   drive power connector, BUT(!) its pinout does not match the standard one. Connecting a standard
;   IBM PC power supply burns out the chips on the motherboard. Check the pinout before applying power.
;
; ==============================================================================================
;
; ## How this BIOS works
;
; The Praktik lacks some of the standard IBM PC chips: there is no 8259 interrupt controller and no 8237 DMA controller. The other chips (8255, 8253, 6845, 765, two 8250s) are present, but they sit in a memory window at F000:0000–0FFF instead of on the standard I/O ports. When a program accesses a standard IBM PC port, the hardware traps the access and raises an NMI. The NMI handler in ROM works out which port was accessed and performs the access in software: it forwards it to the real chip, converts the values, or emulates the device entirely. That is why ordinary IBM PC software runs even though the hardware is different.
;
; The BIOS consists of two 8 KB halves:
; - **First half (segment F400)** is the peripheral emulator: the NMI handler with its port table, the common hardware interrupt handler INT 0Fh, the port handlers, programmed-I/O floppy data transfer, and the upper half of the font (characters 80–FFh).
; - **Second half (F000:E000–FFFF)** is an ordinary BIOS with entry points at exactly the IBM PC/XT addresses: POST, INT 09h–1Ah, bootstrap, and the font for characters 00–7Fh.
;
; The CPU sees the ROM twice: at FC000–FFFFF and in a mirror at F4000–F7FFF. Through the mirror the main BIOS calls code in the first half with near calls (for example `call beep` at F000:4C2D). The INT 1Fh vector F000:5C00 also points through the mirror to the upper half of the font.
;
; ## Hardware register map (F000:0000–0FFF)
;
; | Address | Device | Purpose |
; |---|---|---|
; | F000:0000 / 0002 | CRTC 6845 | Index and data registers. INT 10h AH=0 writes to them directly. |
; | F000:0001 / 0003 / 0005 / 0007 | 8255 | Port A (scan code), port B (like 61h, bit 6 inverted), port C (tape, OUT2), control word (99h). |
; | F000:0009 | — | Read before INT 08h. Probably clears the timer interrupt request. |
; | F000:0200 | NMI latch / IRQ requests; video mode | Read — bits 0–9: port number; bit 10: 1 = OUT; bit 11: NMI caused by a port access; bits 12–15: IRQ from COM1, keyboard, timer, floppy. A word write sets the video mode: low byte — color (like 3D9), high byte — mode (like 3D8). |
; | F000:0400 / 0401 | OUT data | The byte written by the trapped OUT: 0400 for an even port, 0401 for an odd one. Reading 0400 acknowledges the NMI. |
; | F000:0600 / 0601 / 0602 | FDC 765 | 0600 — MSR, 0602 — data. 0601 — DOR equivalent (copy in 0040:00B9): bits 0–1 drive select, bit 2 /RESET, bit 3 IRQ enable, bits 4–7 motors. |
; | F000:0800 / 0808 | Floppy | DACK cycle for transferring one byte to/from the 765 without DMA; 0808 — the same with TC (last byte). The CPU executes WAIT before each byte: DRQ is probably wired to the TEST pin. |
; | F000:0A00–0A06 (even) | 8253 | Channels 0–2 and the control word. Clocked at about 1 MHz, so the emulator rescales the divisors. |
; | F000:0A01 | LPT | Write — printer data, read — status lines. |
; | F000:0DF0–0DFE | 8250 COM2 | Registers 2F8–2FF, stride 2. |
; | F000:0E10–0E1E | 8250 COM1 | Registers 3F8–3FF, stride 2. |
;
; ## Ports trapped by the NMI
;
; | Ports | What is emulated |
; |---|---|
; | 004, 005, 00B, 081 | 8237 DMA, channel 2. Address, count, mode and page are stored in the BIOS data area 0040:009E–00B3 and used by the programmed-I/O floppy transfer. |
; | 020 | 8259. Only EOI is recognized; it clears bit 5 of 8255 port B. |
; | 040–043 | 8253, with divisors rescaled for the ~1 MHz clock. |
; | 060–063 | 8255, forwarded directly (bit 6 of port 61h inverted). |
; | 201 | Game port. An analog joystick is simulated from a digital one. |
; | 2F8–2FF, 3F8–3FF | COM2 and COM1, forwarded to the real 8250s. |
; | 378–37A | LPT1. |
; | 3D4, 3D5, 3D8, 3D9, 3DA | CGA. Writes to 6845 registers are filtered; the 3D8 mode register reloads R0–R9 from the emulator's own tables. |
; | 3F2, 3F4, 3F5 | Floppy. Sector data are transferred by the CPU, without DMA. |
; | all others | "No device" handler: OUT is ignored, IN returns FFh. |
;
; ## Differences from the IBM PC/XT
;
; - **Interrupts.** Instead of an 8259 there is a single request line and the INT 0Fh vector. The handler at F400:0400 reads bits 12–15 of F000:0200 and calls INT 0Eh, 08h, 09h or 0Ch. The INT 08h and 09h handlers send no EOI.
; - **Keyboard.** Bit 2 of 0040:0018 is the RUS/LAT switch (code E0 9Dh, right Ctrl release). There are ЙЦУКЕН (Russian JCUKEN) tables in CP866 and CapsLock for Cyrillic.
; - **Floppy drives.** The drives are 80-track. Bits 4–5 of 0040:003E mark a 720 KB disk. For 360 KB disks double stepping is used. INT 19h sets the flag from the BPB of the boot sector.
; - **Video.** There is no monochrome mode: video memory is always at B800 and the CRTC always at 3D4. The 6845 timing registers (R0–R8) are protected from program writes. Writing R9=1 in 80×25 mode enables a 160×100 graphics mode. The 3DA status is fake: the retrace bits toggle on every read.
; - **Font.** Characters 80–FFh are CP866, but F2h–FBh are replaced: rounded frame corners, arrows, ÷ and ±.
; - **INT 18h.** Instead of ROM BASIC there is a cassette program loader: enter a name, then search for the header on tape. INT 15h follows the IBM PC cassette algorithm.
; - **POST.** The memory test prints «NNN Кб проверено» ("NNN KB tested"). Error messages are in Russian. The checksum covers the 8 KB main ROM.
;
; ## How to read the listing
;
; Each line shows the address (segment:offset), the bytes, the instruction and a comment. Procedures are preceded by headers describing their purpose and input/output registers. Labels `sub_XXXX` are subroutines, `loc_XXXX` jump targets, `dat_XXXX` data referenced by code. Next to each label are the addresses that reference it. "Probably" marks a conclusion drawn from the code that is not confirmed by documentation. On-screen messages are quoted in the original Russian with an English translation.
;
; ## Sources
;
; - The BIOS files were taken from the post «Журнал восстановления Практика» ("Praktik restoration log") on the zxdesu site, 2016: https://zxdesu.byethost32.com/2016/07/28/%d0%b6%d1%83%d1%80%d0%bd%d0%b0%d0%bb-%d0%b2%d0%be%d1%81%d1%81%d1%82%d0%b0%d0%bd%d0%be%d0%b2%d0%bb%d0%b5%d0%bd%d0%b8%d1%8f-%d0%bf%d1%80%d0%b0%d0%ba%d1%82%d0%b8%d0%ba%d0%b0/
; - Description of the Praktik computer (PK8641) on retro-computer.ru: https://retro-computer.ru/item/PRAKTIK-PK8641.html


; ##############################################################################################
; SEGMENT F400 — first 8 KB of the ROM (phys. F4000-F5FFF, same as FC000-FDFFF / F000:C000-DFFF)
; ##############################################################################################

; ----------------------------------------------------------------------------------------------
; port_index_table — maps port number (000–3FF) to an offset into the NMI handler table.
; Index = bits 0–9 of latch F000:0200; byte = 2*handler number in nmi_port_handlers (F400:049F).
; Value 52h (handler #41 nmi_port_unused) — port not emulated: writes ignored, reads return FFh.
; NMI_HANDLER reads word cs:[bx] from here and clears the high byte, i.e. only this byte is used.
; ----------------------------------------------------------------------------------------------
port_index_table:
F400:0000  52              db     4 dup (52h)                 ; Ports 000–003 (DMA 8237: address/count, channels 0–1) — not emulated
F400:0004  0A              db     0Ah                         ; Port 004 (8237: channel 2 address) → nmi_port_004, handler #5
F400:0005  0C              db     0Ch                         ; Port 005 (8237: channel 2 count) → nmi_port_005, handler #6
F400:0006  52              db     5 dup (52h)                 ; Ports 006–00A (8237: channel 3, command, request, mask) — not emulated
F400:000B  0E              db     0Eh                         ; Port 00B (8237: mode register) → nmi_port_00B, handler #7
F400:000C  52              db     20 dup (52h)                ; Ports 00C–01F (8237 flip-flop clear, master clear, etc.) — not emulated
F400:0020  50              db     50h                         ; Port 020 (8259: OCW commands incl. EOI) → nmi_port_020, handler #40
F400:0021  52              db     31 dup (52h)                ; Ports 021–03F (8259 IMR mask etc.) — not emulated (read returns FFh)
F400:0040  10              db     10h                         ; Port 040 (8253: channel 0 count, system timer) → nmi_port_040, #8
F400:0041  12              db     12h                         ; Port 041 (8253: channel 1 count, RAM refresh) → nmi_port_041, #9
F400:0042  14              db     14h                         ; Port 042 (8253: channel 2 count, speaker) → nmi_port_042, #10
F400:0043  16              db     16h                         ; Port 043 (8253: control word register) → nmi_port_043, #11
F400:0044  52              db     28 dup (52h)                ; Ports 044–05F — not emulated
F400:0060  18              db     18h                         ; Port 060 (8255 port A: keyboard scan code) → nmi_port_060, #12
F400:0061  1A              db     1Ah                         ; Port 061 (8255 port B: speaker, keyboard control) → nmi_port_061, #13
F400:0062  1C              db     1Ch                         ; Port 062 (8255 port C: switches/status) → nmi_port_062, #14
F400:0063  1E              db     1Eh                         ; Port 063 (8255 control word) → nmi_port_063, #15
F400:0064  52              db     29 dup (52h)                ; Ports 064–080 — not emulated (incl. DMA pages 080, 082–083)
F400:0081  20              db     20h                         ; Port 081 (DMA channel 2 page register) → nmi_port_081, #16
F400:0082  52              db     383 dup (52h)               ; Ports 082–200 — not emulated
F400:0201  22              db     22h                         ; Port 201 (game adapter/joystick) → nmi_port_201, #17
F400:0202  52              db     246 dup (52h)               ; Ports 202–2F7 — not emulated
F400:02F8  24              db     24h                         ; Port 2F8 (COM2 8250: RBR/THR or DLL) → nmi_port_2F8, #18
F400:02F9  26              db     26h                         ; Port 2F9 (COM2 8250: IER or DLM) → nmi_port_2F9, #19
F400:02FA  28              db     28h                         ; Port 2FA (COM2 8250: IIR) → nmi_port_2FA, #20
F400:02FB  2A              db     2Ah                         ; Port 2FB (COM2 8250: LCR) → nmi_port_2FB, #21
F400:02FC  2C              db     2Ch                         ; Port 2FC (COM2 8250: MCR) → nmi_port_2FC, #22
F400:02FD  2E              db     2Eh                         ; Port 2FD (COM2 8250: LSR) → nmi_port_2FD, #23
F400:02FE  30              db     30h                         ; Port 2FE (COM2 8250: MSR) → nmi_port_2FE, #24
F400:02FF  32              db     32h                         ; Port 2FF (COM2 8250: SCR) → nmi_port_2FF, #25
F400:0300  52              db     120 dup (52h)               ; Ports 300–377 — not emulated
F400:0378  34              db     34h                         ; Port 378 (LPT1: data register) → nmi_port_378, #26
F400:0379  36              db     36h                         ; Port 379 (LPT1: status register) → nmi_port_379, #27
F400:037A  38              db     38h                         ; Port 37A (LPT1: control register) → nmi_port_37A, #28
F400:037B  52              db     89 dup (52h)                ; Ports 37B–3D3 (incl. MDA 3B0–3BF, LPT 3BC) — not emulated
F400:03D4  00              db     00h                         ; Port 3D4 (CGA 6845: index register) → nmi_port_3D4, #0
F400:03D5  02              db     02h                         ; Port 3D5 (CGA 6845: data register) → nmi_port_3D5, #1
F400:03D6  52              db     2 dup (52h)                 ; Ports 3D6–3D7 — not emulated
F400:03D8  04              db     04h                         ; Port 3D8 (CGA: mode register) → nmi_port_3D8, #2
F400:03D9  06              db     06h                         ; Port 3D9 (CGA: color select/palette register) → nmi_port_3D9, #3
F400:03DA  08              db     08h                         ; Port 3DA (CGA: status register, retrace) → nmi_port_3DA, #4
F400:03DB  52              db     23 dup (52h)                ; Ports 3DB–3F1 — not emulated
F400:03F2  3A              db     3Ah                         ; Port 3F2 (FDC: digital output register DOR) → nmi_port_3F2, #29
F400:03F3  52              db     1 dup (52h)                 ; Port 3F3 — not emulated
F400:03F4  3C              db     3Ch                         ; Port 3F4 (FDC 765: main status register MSR) → nmi_port_3F4, #30
F400:03F5  3E              db     3Eh                         ; Port 3F5 (FDC 765: data register) → nmi_port_3F5, #31
F400:03F6  52              db     2 dup (52h)                 ; Ports 3F6–3F7 — not emulated
F400:03F8  40              db     40h                         ; Port 3F8 (COM1 8250: RBR/THR or DLL) → nmi_port_3F8, #32
F400:03F9  42              db     42h                         ; Port 3F9 (COM1 8250: IER or DLM) → nmi_port_3F9, #33
F400:03FA  44              db     44h                         ; Port 3FA (COM1 8250: IIR) → nmi_port_3FA, #34
F400:03FB  46              db     46h                         ; Port 3FB (COM1 8250: LCR) → nmi_port_3FB, #35
F400:03FC  48              db     48h                         ; Port 3FC (COM1 8250: MCR) → nmi_port_3FC, #36
F400:03FD  4A              db     4Ah                         ; Port 3FD (COM1 8250: LSR) → nmi_port_3FD, #37
F400:03FE  4C              db     4Ch                         ; Port 3FE (COM1 8250: MSR) → nmi_port_3FE, #38
F400:03FF  4E              db     4Eh                         ; Port 3FF (COM1 8250: SCR) → nmi_port_3FF, #39

; ----------------------------------------------------------------------------------------------
; INT0F_IRQ_DISPATCH — common hardware interrupt handler (vector INT 0Fh), replaces the 8259.
; Reads the request register F000:0200 (high byte): bit 15 — floppy (INT 0Eh), bit 14 — timer (INT 08h),
; bit 13 — keyboard (INT 09h), bit 12 — COM1 (INT 0Ch). One source is serviced per entry, by priority.
; Special case: floppy IRQ during programmed FDC data transfer (0040:00B9 bit 3 = 0) — the stack
; is cut back to the return address into NMI_HANDLER, i.e. the transfer loop in nmi_port_3F5 is aborted.
; ----------------------------------------------------------------------------------------------
INT0F_IRQ_DISPATCH:
F400:0400  06              push   es                          ; Save ES of the interrupted program
F400:0401  1E              push   ds                          ; Save DS
F400:0402  50              push   ax                          ; Save AX
F400:0403  FC              cld                                ; Clear direction flag for string operations
F400:0404  B84000          mov    ax, 40h                     ; BIOS data area segment 0040h…
F400:0407  8ED8            mov    ds, ax                      ; …into DS
F400:0409  B800F0          mov    ax, 0F000h                  ; Hardware register segment F000h…
F400:040C  8EC0            mov    es, ax                      ; …into ES
F400:040E  26A10002        mov    ax, word es:[200h]          ; AX = interrupt request status register F000:0200 (AH = bits 15–8)
F400:0412  D0E4            shl    ah, 1                       ; Bit 15 → CF: request from floppy controller?
F400:0414  7316            jae    loc_042C                    ; No FDC request — check next source
F400:0416  A0B900          mov    al, byte [0B9h]             ; AL = 0040:00B9 — shadow copy of floppy control register F000:0601 (DOR)
F400:0419  A808            test   al, 8                       ; Bit 3 = 1 — no programmed FDC data transfer in progress?
F400:041B  750F            jne    loc_042C                    ; Yes — FDC IRQ not serviced here (polled in nmi_port_3F2/3F5), go to timer
F400:041D  83C416          add    sp, 16h                     ; IRQ arrived during transfer in nmi_port_3F5: drop 22 stack bytes (INT0F frames + 5 registers)
F400:0420  0C08            or     al, 8                       ; Restore bit 3 (leave programmed data transfer mode)
F400:0422  A2B900          mov    byte [0B9h], al             ; Update DOR shadow copy at 0040:00B9
F400:0425  26A20106        mov    byte es:[601h], al          ; …and write it to hardware floppy control register F000:0601
F400:0429  CD0E            int    0Eh                         ; Call floppy interrupt handler INT 0Eh (probably sets flag 0040:003E bit 7)
F400:042B  C3              ret                                ; Return directly to NMI_HANDLER (after call bx) — FDC operation complete

loc_042C:    ; xrefs: 0414 041B
F400:042C  D0E4            shl    ah, 1                       ; Bit 14 → CF: request from system timer (8253 channel 0)?
F400:042E  730A            jae    loc_043A                    ; No — check keyboard
F400:0430  26A00900        mov    al, byte es:[9]             ; Read F000:0009 — probably acknowledges/clears timer interrupt request
F400:0434  58              pop    ax                          ; Restore AX
F400:0435  1F              pop    ds                          ; Restore DS
F400:0436  07              pop    es                          ; Restore ES
F400:0437  CD08            int    8                           ; Call timer handler INT 08h (clock tick, 18.2 Hz)
F400:0439  CF              iret                               ; Return to interrupted program

loc_043A:    ; xrefs: 042E
F400:043A  D0E4            shl    ah, 1                       ; Bit 13 → CF: request from keyboard?
F400:043C  7314            jae    loc_0452                    ; No — check COM1
F400:043E  26A00300        mov    al, byte es:[3]             ; AL = F000:0003 — port B of the real 8255 (equivalent of port 61h)
F400:0442  0C20            or     al, 20h                     ; Set bit 5 — probably masks/acknowledges keyboard IRQ request
F400:0444  26A20300        mov    byte es:[3], al             ; Write to 8255 port B
F400:0448  CD09            int    9                           ; Call keyboard handler INT 09h (reads scan code from port 60h)
F400:044A  24DF            and    al, 0DFh                    ; Clear bit 5 (AL preserved by INT 09h; EOI to port 20h also clears this bit)
F400:044C  26A20300        mov    byte es:[3], al             ; Write 8255 port B back — enable next keyboard request
F400:0450  EB16            jmp    loc_0468                    ; To exit

loc_0452:    ; xrefs: 043C
F400:0452  D0E4            shl    ah, 1                       ; Bit 12 → CF: request from COM1 (8250)?
F400:0454  7312            jae    loc_0468                    ; No requests — exit
F400:0456  26A0180E        mov    al, byte es:[0E18h]         ; AL = F000:0E18 — MCR of the real 8250 COM1 (port 3FCh)
F400:045A  24F7            and    al, 0F7h                    ; Clear bit 3 (OUT2) — temporarily disable UART interrupt output
F400:045C  26A2180E        mov    byte es:[0E18h], al         ; Write MCR
F400:0460  CD0C            int    0Ch                         ; Call COM1 handler INT 0Ch
F400:0462  0C08            or     al, 8                       ; Set OUT2 again — re-enable IRQ (generates a new edge if requests are pending)
F400:0464  26A2180E        mov    byte es:[0E18h], al         ; Write MCR

loc_0468:    ; xrefs: 0450 0454
F400:0468  58              pop    ax                          ; Restore AX
F400:0469  1F              pop    ds                          ; Restore DS
F400:046A  07              pop    es                          ; Restore ES
F400:046B  CF              iret                               ; Return from interrupt

; ----------------------------------------------------------------------------------------------
; NMI_HANDLER — NMI handler (vector INT 2): software emulation of IBM PC I/O ports.
; Hardware traps IN/OUT and raises NMI. F000:0200 — latch: bits 0–9 = port number,
; bit 10 = 1 on write (OUT), 0 on read (IN); bit 11 = NMI caused by port access.
; F000:0400/0401 — OUT data (even/odd bus byte). Handler is called with ZF=1 on IN,
; ZF=0 on OUT, AX = latch, ES = F000, BP → frame: [bp]=program's AX (IN result goes here).
; ----------------------------------------------------------------------------------------------
NMI_HANDLER:
F400:046C  06              push   es                          ; Save ES (frame: [bp+6])
F400:046D  55              push   bp                          ; Save BP ([bp+4])
F400:046E  53              push   bx                          ; Save BX ([bp+2])
F400:046F  50              push   ax                          ; Save interrupted program's AX ([bp+0] — handler writes IN result here)
F400:0470  8BEC            mov    bp, sp                      ; BP → saved register frame
F400:0472  B800F0          mov    ax, 0F000h                  ; Hardware register segment F000h…
F400:0475  8EC0            mov    es, ax                      ; …into ES (ES stays F000 in all port handlers)
F400:0477  268B1E0002      mov    bx, word es:[200h]          ; BX = latch F000:0200: port number and access flags
F400:047C  F6C708          test   bh, 8                       ; Bit 11: NMI caused by I/O port trap?
F400:047F  7415            je     loc_0496                    ; No (other NMI source) — just acknowledge and exit
F400:0481  8BC3            mov    ax, bx                      ; AX = copy of latch (handlers test bits 10/11 in AH)
F400:0483  81E3FF03        and    bx, 3FFh                    ; Keep bits 0–9 — port number 000–3FF
F400:0487  2E8B1F          mov    bx, word cs:[bx]            ; Fetch byte from port_index_table (F400:0000+port)
F400:048A  32FF            xor    bh, bh                      ; High byte unused: BX = offset into handler table (2*N)
F400:048C  2E8B9F9F04      mov    bx, word cs:[bx + 49Fh]     ; BX = port handler address from nmi_port_handlers
F400:0491  F6C404          test   ah, 4                       ; Bit 10 (write): ZF=1 — IN read, ZF=0 — OUT write; flag passed to handler
F400:0494  FFD3            call   bx                          ; Call emulated port handler

loc_0496:    ; xrefs: 047F
F400:0496  26A10004        mov    ax, word es:[400h]          ; Read F000:0400 — probably acknowledges NMI/releases trap latch
F400:049A  58              pop    ax                          ; Restore AX (on IN — already holding result in AL)
F400:049B  5B              pop    bx                          ; Restore BX
F400:049C  5D              pop    bp                          ; Restore BP
F400:049D  07              pop    es                          ; Restore ES
F400:049E  CF              iret                               ; Return to program that executed IN/OUT

; ----------------------------------------------------------------------------------------------
; nmi_port_handlers — address table of emulated port handlers (42 words, index = byte/2
; from port_index_table). Entry: ZF=1 — read, ZF=0 — write; ES=F000; AX = latch; BP → NMI frame.
; ----------------------------------------------------------------------------------------------
nmi_port_handlers:
F400:049F  3D09            dw     nmi_port_3D4                ; #0: 3D4h — 6845 index (CGA)
F400:04A1  4C09            dw     nmi_port_3D5                ; #1: 3D5h — 6845 data (CGA)
F400:04A3  9209            dw     nmi_port_3D8                ; #2: 3D8h — CGA mode register
F400:04A5  F209            dw     nmi_port_3D9                ; #3: 3D9h — CGA color register
F400:04A7  090A            dw     nmi_port_3DA                ; #4: 3DAh — CGA status
F400:04A9  FB04            dw     nmi_port_004                ; #5: 004h — DMA channel 2 address
F400:04AB  1405            dw     nmi_port_005                ; #6: 005h — DMA channel 2 count
F400:04AD  2D05            dw     nmi_port_00B                ; #7: 00Bh — DMA mode
F400:04AF  3C05            dw     nmi_port_040                ; #8: 040h — 8253 channel 0
F400:04B1  B705            dw     nmi_port_041                ; #9: 041h — 8253 channel 1
F400:04B3  1106            dw     nmi_port_042                ; #10: 042h — 8253 channel 2
F400:04B5  5A06            dw     nmi_port_043                ; #11: 043h — 8253 control word
F400:04B7  7C06            dw     nmi_port_060                ; #12: 060h — 8255 port A (keyboard)
F400:04B9  8D06            dw     nmi_port_061                ; #13: 061h — 8255 port B
F400:04BB  A206            dw     nmi_port_062                ; #14: 062h — 8255 port C
F400:04BD  B506            dw     nmi_port_063                ; #15: 063h — 8255 control
F400:04BF  C606            dw     nmi_port_081                ; #16: 081h — DMA channel 2 page
F400:04C1  D506            dw     nmi_port_201                ; #17: 201h — joystick
F400:04C3  CD07            dw     nmi_port_2F8                ; #18: 2F8h — COM2 THR/RBR/DLL
F400:04C5  E007            dw     nmi_port_2F9                ; #19: 2F9h — COM2 IER/DLM
F400:04C7  F307            dw     nmi_port_2FA                ; #20: 2FAh — COM2 IIR
F400:04C9  0608            dw     nmi_port_2FB                ; #21: 2FBh — COM2 LCR
F400:04CB  1908            dw     nmi_port_2FC                ; #22: 2FCh — COM2 MCR
F400:04CD  2C08            dw     nmi_port_2FD                ; #23: 2FDh — COM2 LSR
F400:04CF  3F08            dw     nmi_port_2FE                ; #24: 2FEh — COM2 MSR
F400:04D1  5208            dw     nmi_port_2FF                ; #25: 2FFh — COM2 SCR
F400:04D3  8207            dw     nmi_port_378                ; #26: 378h — LPT1 data
F400:04D5  9C07            dw     nmi_port_379                ; #27: 379h — LPT1 status
F400:04D7  B107            dw     nmi_port_37A                ; #28: 37Ah — LPT1 control
F400:04D9  3A0A            dw     nmi_port_3F2                ; #29: 3F2h — floppy DOR
F400:04DB  AD0A            dw     nmi_port_3F4                ; #30: 3F4h — FDC 765 MSR
F400:04DD  B70A            dw     nmi_port_3F5                ; #31: 3F5h — FDC 765 data
F400:04DF  6508            dw     nmi_port_3F8                ; #32: 3F8h — COM1 THR/RBR/DLL
F400:04E1  7808            dw     nmi_port_3F9                ; #33: 3F9h — COM1 IER/DLM
F400:04E3  8B08            dw     nmi_port_3FA                ; #34: 3FAh — COM1 IIR
F400:04E5  9E08            dw     nmi_port_3FB                ; #35: 3FBh — COM1 LCR
F400:04E7  B108            dw     nmi_port_3FC                ; #36: 3FCh — COM1 MCR
F400:04E9  C408            dw     nmi_port_3FD                ; #37: 3FDh — COM1 LSR
F400:04EB  D708            dw     nmi_port_3FE                ; #38: 3FEh — COM1 MSR
F400:04ED  EA08            dw     nmi_port_3FF                ; #39: 3FFh — COM1 SCR
F400:04EF  6906            dw     nmi_port_020                ; #40: 020h — 8259 commands (EOI)
F400:04F1  F304            dw     nmi_port_unused             ; #41: all other ports — "no device"

; ----------------------------------------------------------------------------------------------
; nmi_port_unused — port with no device: writes ignored, reads return FFh
; (like a floating ISA bus).
; ----------------------------------------------------------------------------------------------
nmi_port_unused:    ; xrefs: 04F1
F400:04F3  7505            jne    loc_04FA                    ; Write (OUT) — do nothing
F400:04F5  B0FF            mov    al, 0FFh                    ; Read: empty bus returns FFh
F400:04F7  884600          mov    byte [bp], al               ; IN result → program's AL (saved AX in frame)

loc_04FA:    ; xrefs: 04F3
F400:04FA  C3              ret                                ; Return to NMI_HANDLER

; ----------------------------------------------------------------------------------------------
; nmi_port_004 — 8237, channel 2 address (write-only). Bytes accumulate in 0040:009E/009F
; alternately via flip-flop 0040:00A0 (low, then high). Used by programmed FDC transfer.
; ZF not checked: an IN from the port also "writes" garbage and toggles the flip-flop (simplification).
; ----------------------------------------------------------------------------------------------
nmi_port_004:    ; xrefs: 04A9
F400:04FB  1E              push   ds                          ; Save DS
F400:04FC  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:04FF  8EDB            mov    ds, bx                      ; …into DS
F400:0501  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0505  8B1EA000        mov    bx, word [0A0h]             ; BX = low/high byte flip-flop 0040:00A0 (0 or 1)
F400:0509  88879E00        mov    byte [bx + 9Eh], al         ; Store DMA channel 2 address byte at 0040:009E+flip-flop
F400:050D  8336A00001      xor    word [0A0h], 1              ; Toggle flip-flop (emulates internal 8237 flip-flop)
F400:0512  1F              pop    ds                          ; Restore DS
F400:0513  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_005 — 8237, channel 2 count (write-only). Bytes in 0040:00A2/00A3 via flip-flop 0040:00A4.
; The count (N-1) is used by nmi_port_3F5 as the programmed transfer length.
; ----------------------------------------------------------------------------------------------
nmi_port_005:    ; xrefs: 04AB
F400:0514  1E              push   ds                          ; Save DS
F400:0515  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:0518  8EDB            mov    ds, bx                      ; …into DS
F400:051A  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:051E  8B1EA400        mov    bx, word [0A4h]             ; BX = count low/high byte flip-flop 0040:00A4
F400:0522  8887A200        mov    byte [bx + 0A2h], al        ; Store DMA channel 2 count byte at 0040:00A2+flip-flop
F400:0526  8336A40001      xor    word [0A4h], 1              ; Toggle flip-flop
F400:052B  1F              pop    ds                          ; Restore DS
F400:052C  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_00B — 8237, mode register (write-only): value stored at 0040:00B2.
; nmi_port_3F5 uses it to tell mode 42h (verify) from read/write (46h/4Ah).
; ----------------------------------------------------------------------------------------------
nmi_port_00B:    ; xrefs: 04AD
F400:052D  1E              push   ds                          ; Save DS
F400:052E  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:0531  8EDB            mov    ds, bx                      ; …into DS
F400:0533  26A00104        mov    al, byte es:[401h]          ; AL = DMA mode written (odd port → F000:0401)
F400:0537  A2B200          mov    byte [0B2h], al             ; Remember DMA mode at 0040:00B2
F400:053A  1F              pop    ds                          ; Restore DS
F400:053B  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_040 — 8253 channel 0 (system timer). The real 8253 at F000:0A00–0A06 is clocked at
; ~1 MHz (probably) rather than 1.19318 MHz, so values are rescaled: read ×1.19318 (98BAh/8000h),
; write ×0.83809 (D68Dh/10000h). Low/high byte flip-flop — 0040:00A6, word buffer — 0040:00A8/00A9.
; ----------------------------------------------------------------------------------------------
nmi_port_040:    ; xrefs: 04AF
F400:053C  52              push   dx                          ; Save DX (clobbered by MUL)
F400:053D  56              push   si                          ; Save SI
F400:053E  1E              push   ds                          ; Save DS
F400:053F  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:0542  8EDB            mov    ds, bx                      ; …into DS (flags unchanged — ZF from NMI_HANDLER preserved)
F400:0544  7533            jne    loc_0579                    ; Write (OUT 40h) — go accumulate divisor
F400:0546  8B36A600        mov    si, word [0A6h]             ; Read: SI = byte flip-flop 0040:00A6
F400:054A  0BF6            or     si, si                      ; First (low) byte?
F400:054C  751E            jne    loc_056C                    ; No — return previously prepared high byte
F400:054E  26A0000A        mov    al, byte es:[0A00h]         ; Read low byte of current count of real 8253 channel 0 (F000:0A00)
F400:0552  A2A800          mov    byte [0A8h], al             ; …into 0040:00A8
F400:0555  26A0000A        mov    al, byte es:[0A00h]         ; Read high byte of count
F400:0559  A2A900          mov    byte [0A9h], al             ; …into 0040:00A9
F400:055C  BBBA98          mov    bx, 98BAh                   ; Factor 98BAh: 98BAh*2/65536 ≈ 1.19318 (convert to PC clocks)
F400:055F  A1A800          mov    ax, word [0A8h]             ; AX = 16-bit count read
F400:0562  F7E3            mul    bx                          ; DX:AX = count * 98BAh
F400:0564  D1D0            rcl    ax, 1                       ; Shift DX:AX left by 1 (×2) — AX high bit into CF…
F400:0566  D1D2            rcl    dx, 1                       ; …into DX: DX = count*1.19318 (in IBM 8253 units)
F400:0568  8916A800        mov    word [0A8h], dx             ; Rescaled count to 0040:00A8 — returned over two reads

loc_056C:    ; xrefs: 054C
F400:056C  8A84A800        mov    al, byte [si + 0A8h]        ; AL = next byte (low when SI=0, high when SI=1)
F400:0570  83F601          xor    si, 1                       ; Toggle flip-flop
F400:0573  8936A600        mov    word [0A6h], si             ; Store flip-flop at 0040:00A6
F400:0577  EB4C            jmp    loc_05C5                    ; To common exit: AL → IN result

loc_0579:    ; xrefs: 0544 0591
F400:0579  26A00004        mov    al, byte es:[400h]          ; Write: AL = byte written (even port → F000:0400)
F400:057D  8B36A600        mov    si, word [0A6h]             ; SI = byte flip-flop 0040:00A6
F400:0581  8884A800        mov    byte [si + 0A8h], al        ; Store divisor byte at 0040:00A8+flip-flop
F400:0585  83F601          xor    si, 1                       ; Toggle flip-flop
F400:0588  8936A600        mov    word [0A6h], si             ; Save flip-flop
F400:058C  7409            je     loc_0597                    ; Both bytes written — rescale and load into real timer
F400:058E  F6C408          test   ah, 8                       ; Latch bit 11 (always 1 here) — probably reserved for word write OUT DX,AX
F400:0591  74E6            je     loc_0579                    ; No repeat: wait for second byte in next NMI
F400:0593  1F              pop    ds                          ; Restore DS
F400:0594  5E              pop    si                          ; Restore SI
F400:0595  5A              pop    dx                          ; Restore DX
F400:0596  C3              ret                                ; Return

loc_0597:    ; xrefs: 058C
F400:0597  BB8DD6          mov    bx, 0D68Dh                  ; Factor D68Dh/65536 ≈ 0.83809 = 1/1.19318 (PC clocks → ~1 MHz clocks)
F400:059A  A1A800          mov    ax, word [0A8h]             ; AX = divisor set by program (0 means 65536)
F400:059D  48              dec    ax                          ; N-1: N=0 gives FFFFh, which together with +k yields 65536*k
F400:059E  F7E3            mul    bx                          ; DX:AX = (N-1)*k
F400:05A0  03C3            add    ax, bx                      ; +k → DX:AX = N*k (with carry)
F400:05A2  7301            jae    loc_05A5                    ; No carry
F400:05A4  42              inc    dx                          ; Add carry into high word

loc_05A5:    ; xrefs: 05A2
F400:05A5  8916A800        mov    word [0A8h], dx             ; DX = N*0.83809 — divisor for real 8253; store at 0040:00A8
F400:05A9  268816000A      mov    byte es:[0A00h], dl         ; Load divisor low byte into channel 0 of real 8253 (F000:0A00)
F400:05AE  268836000A      mov    byte es:[0A00h], dh         ; Load divisor high byte
F400:05B3  1F              pop    ds                          ; Restore DS
F400:05B4  5E              pop    si                          ; Restore SI
F400:05B5  5A              pop    dx                          ; Restore DX
F400:05B6  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_041 — 8253 channel 1 (RAM refresh on PC). Read — raw byte of real counter
; F000:0A02 (no rescaling or flip-flop). Write — divisor accumulates in 0040:00AC/00AD via flip-flop 0040:00AA,
; then N*8068/10000+1 (≈0.807*N) — probably a tuned factor for different channel 1 clocking.
; Also holds common tail loc_05C5: AL → IN result and exit (used by channels 0–2).
; ----------------------------------------------------------------------------------------------
nmi_port_041:    ; xrefs: 04B1
F400:05B7  52              push   dx                          ; Save DX
F400:05B8  56              push   si                          ; Save SI
F400:05B9  1E              push   ds                          ; Save DS
F400:05BA  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:05BD  8EDB            mov    ds, bx                      ; …into DS
F400:05BF  750B            jne    loc_05CC                    ; Write — go accumulate divisor
F400:05C1  26A0020A        mov    al, byte es:[0A02h]         ; Read: channel 1 count byte of real 8253 as is

loc_05C5:    ; xrefs: 0577 061F
F400:05C5  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:05C8  1F              pop    ds                          ; Restore DS
F400:05C9  5E              pop    si                          ; Restore SI
F400:05CA  5A              pop    dx                          ; Restore DX
F400:05CB  C3              ret                                ; Return

loc_05CC:    ; xrefs: 05BF 05E4
F400:05CC  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:05D0  8B36AA00        mov    si, word [0AAh]             ; SI = channel 1 byte flip-flop (0040:00AA)
F400:05D4  8884AC00        mov    byte [si + 0ACh], al        ; Store divisor byte at 0040:00AC+flip-flop
F400:05D8  83F601          xor    si, 1                       ; Toggle flip-flop
F400:05DB  8936AA00        mov    word [0AAh], si             ; Save flip-flop
F400:05DF  7409            je     loc_05EA                    ; Both bytes written — rescale
F400:05E1  F6C408          test   ah, 8                       ; Latch bit 11 (always 1) — probably reserved for word write
F400:05E4  74E6            je     loc_05CC                    ; No repeat
F400:05E6  1F              pop    ds                          ; Restore DS
F400:05E7  5E              pop    si                          ; Restore SI
F400:05E8  5A              pop    dx                          ; Restore DX
F400:05E9  C3              ret                                ; Return

loc_05EA:    ; xrefs: 05DF
F400:05EA  BB841F          mov    bx, 1F84h                   ; Multiplier 1F84h = 8068
F400:05ED  51              push   cx                          ; Save CX
F400:05EE  B91027          mov    cx, 2710h                   ; Divisor 2710h = 10000
F400:05F1  A1AC00          mov    ax, word [0ACh]             ; AX = channel 1 divisor set by program
F400:05F4  48              dec    ax                          ; N-1 (handles N=0 → 65536 correctly)
F400:05F5  F7E3            mul    bx                          ; DX:AX = (N-1)*8068
F400:05F7  03C3            add    ax, bx                      ; +8068 → N*8068
F400:05F9  7301            jae    loc_05FC                    ; No carry
F400:05FB  42              inc    dx                          ; Add carry

loc_05FC:    ; xrefs: 05F9
F400:05FC  F7F1            div    cx                          ; AX = N*8068/10000 ≈ 0.807*N
F400:05FE  40              inc    ax                          ; +1 (round up, avoid zero divisor)
F400:05FF  59              pop    cx                          ; Restore CX
F400:0600  A3AC00          mov    word [0ACh], ax             ; Store rescaled divisor at 0040:00AC
F400:0603  26A2020A        mov    byte es:[0A02h], al         ; Low byte to channel 1 of real 8253 (F000:0A02)
F400:0607  90              nop                                ; Delay between 8253 accesses
F400:0608  268826020A      mov    byte es:[0A02h], ah         ; High byte to channel 1
F400:060D  1F              pop    ds                          ; Restore DS
F400:060E  5E              pop    si                          ; Restore SI
F400:060F  5A              pop    dx                          ; Restore DX
F400:0610  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_042 — 8253 channel 2 (speaker tone). Read — raw count byte F000:0A04.
; Write — divisor accumulates in 0040:00B0/00B1 via flip-flop 0040:00AE, rescaled ≈ N*0.838+2
; and loaded into real channel 2 (preserves tone frequency with ~1 MHz clocking).
; ----------------------------------------------------------------------------------------------
nmi_port_042:    ; xrefs: 04B3
F400:0611  52              push   dx                          ; Save DX
F400:0612  56              push   si                          ; Save SI
F400:0613  1E              push   ds                          ; Save DS
F400:0614  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:0617  8EDB            mov    ds, bx                      ; …into DS
F400:0619  7506            jne    loc_0621                    ; Write — go accumulate divisor
F400:061B  26A0040A        mov    al, byte es:[0A04h]         ; Read: channel 2 count byte of real 8253 as is
F400:061F  EBA4            jmp    loc_05C5                    ; To common exit (AL → IN result)

loc_0621:    ; xrefs: 0619 0639
F400:0621  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0625  8B36AE00        mov    si, word [0AEh]             ; SI = channel 2 byte flip-flop (0040:00AE)
F400:0629  8884B000        mov    byte [si + 0B0h], al        ; Store divisor byte at 0040:00B0+flip-flop
F400:062D  83F601          xor    si, 1                       ; Toggle flip-flop
F400:0630  8936AE00        mov    word [0AEh], si             ; Save flip-flop
F400:0634  7409            je     loc_063F                    ; Both bytes written — rescale
F400:0636  F6C408          test   ah, 8                       ; Latch bit 11 (always 1) — probably reserved for word write
F400:0639  74E6            je     loc_0621                    ; No repeat
F400:063B  1F              pop    ds                          ; Restore DS
F400:063C  5E              pop    si                          ; Restore SI
F400:063D  5A              pop    dx                          ; Restore DX
F400:063E  C3              ret                                ; Return

loc_063F:    ; xrefs: 0634
F400:063F  BB8DD6          mov    bx, 0D68Dh                  ; Factor D68Dh/65536 ≈ 0.83809 (1.19318 MHz → ~1 MHz)
F400:0642  A1B000          mov    ax, word [0B0h]             ; AX = channel 2 divisor set by program
F400:0645  48              dec    ax                          ; N-1
F400:0646  F7E3            mul    bx                          ; DX = high word of (N-1)*0.83809
F400:0648  42              inc    dx                          ; +1…
F400:0649  42              inc    dx                          ; …+1: rounding compensation (probably a rough fix instead of an exact +k)
F400:064A  268816040A      mov    byte es:[0A04h], dl         ; Low byte to channel 2 of real 8253 (F000:0A04)
F400:064F  90              nop                                ; Delay
F400:0650  90              nop                                ; Delay
F400:0651  268836040A      mov    byte es:[0A04h], dh         ; High byte to channel 2
F400:0656  1F              pop    ds                          ; Restore DS
F400:0657  5E              pop    si                          ; Restore SI
F400:0658  5A              pop    dx                          ; Restore DX
F400:0659  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_043 — 8253 control word: writes pass unchanged to the real 8253 (F000:0A06),
; reads return FFh (8253 control register is not readable). Emulator byte flip-flops are not reset.
; ----------------------------------------------------------------------------------------------
nmi_port_043:    ; xrefs: 04B5
F400:065A  7504            jne    loc_0660                    ; Write — pass control word through
F400:065C  B0FF            mov    al, 0FFh                    ; Read: FFh
F400:065E  EB48            jmp    loc_06A8                    ; To common exit (AL → IN result)

loc_0660:    ; xrefs: 065A
F400:0660  26A00104        mov    al, byte es:[401h]          ; AL = control word (odd port → F000:0401)
F400:0664  26A2060A        mov    byte es:[0A06h], al         ; Write to control register of real 8253 (F000:0A06)
F400:0668  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_020 — 8259 emulation: only non-specific EOI (20h) is recognized, which
; clears bit 5 of 8255 port B (F000:0003) — unblocks keyboard IRQ request. Reads not handled.
; ----------------------------------------------------------------------------------------------
nmi_port_020:    ; xrefs: 04EF
F400:0669  26A00004        mov    al, byte es:[400h]          ; AL = command written (even port → F000:0400)
F400:066D  3C20            cmp    al, 20h                     ; Non-specific EOI (20h)?
F400:066F  750A            jne    loc_067B                    ; No — ignore (ICW/OCW/mask not emulated)
F400:0671  26A00300        mov    al, byte es:[3]             ; AL = port B of real 8255 (F000:0003)
F400:0675  24DF            and    al, 0DFh                    ; Clear bit 5 — end of keyboard interrupt service
F400:0677  26A20300        mov    byte es:[3], al             ; Write 8255 port B

loc_067B:    ; xrefs: 066F
F400:067B  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_060 — 8255 port A (keyboard scan code) — mapped directly to the real 8255
; at F000:0001.
; ----------------------------------------------------------------------------------------------
nmi_port_060:    ; xrefs: 04B7
F400:067C  7506            jne    loc_0684                    ; Write — pass to real port A
F400:067E  26A00100        mov    al, byte es:[1]             ; Read: scan code / 8255 port A data (F000:0001)
F400:0682  EB24            jmp    loc_06A8                    ; To common exit (AL → IN result)

loc_0684:    ; xrefs: 067C
F400:0684  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0688  26A20100        mov    byte es:[1], al             ; Write to port A of real 8255 (input in mode 99h, write has no effect)
F400:068C  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_061 — 8255 port B (F000:0003). Bit 6 (keyboard clock hold) is inverted in "Praktik"
; hardware relative to IBM, so it is flipped on both read and write.
; ----------------------------------------------------------------------------------------------
nmi_port_061:    ; xrefs: 04B9
F400:068D  7508            jne    loc_0697                    ; Write — go output to port B
F400:068F  26A00300        mov    al, byte es:[3]             ; Read: current value of real 8255 port B
F400:0693  3440            xor    al, 40h                     ; Invert bit 6 — convert to IBM PC logic
F400:0695  EB11            jmp    loc_06A8                    ; To common exit (AL → IN result)

loc_0697:    ; xrefs: 068D
F400:0697  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:069B  3440            xor    al, 40h                     ; Invert bit 6 (keyboard clock) for "Praktik" hardware
F400:069D  26A20300        mov    byte es:[3], al             ; Write to port B of real 8255 (speaker, channel 2 gate, keyboard control)
F400:06A1  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_062 — 8255 port C (F000:0005): direct mapping. Also holds common tail loc_06A8:
; AL → IN result.
; ----------------------------------------------------------------------------------------------
nmi_port_062:    ; xrefs: 04BB
F400:06A2  7508            jne    loc_06AC                    ; Write — go output to port C
F400:06A4  26A00500        mov    al, byte es:[5]             ; Read: port C of real 8255 (status/switches, channel 2 output)

loc_06A8:    ; xrefs: 065E 0682 0695 06BB
F400:06A8  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:06AB  C3              ret                                ; Return

loc_06AC:    ; xrefs: 06A2
F400:06AC  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:06B0  26A20500        mov    byte es:[5], al             ; Write to port C of real 8255
F400:06B4  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_063 — 8255 control register (F000:0007): direct mapping (POST writes 99h there,
; like IBM XT: A — input, B — output, C — input).
; ----------------------------------------------------------------------------------------------
nmi_port_063:    ; xrefs: 04BD
F400:06B5  7506            jne    loc_06BD                    ; Write — go output control word
F400:06B7  26A00700        mov    al, byte es:[7]             ; Read: control register of real 8255
F400:06BB  EBEB            jmp    loc_06A8                    ; To common exit (AL → IN result)

loc_06BD:    ; xrefs: 06B5
F400:06BD  26A00104        mov    al, byte es:[401h]          ; AL = control word (odd port → F000:0401)
F400:06C1  26A20700        mov    byte es:[7], al             ; Write to 8255 control register
F400:06C5  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_081 — DMA channel 2 page register (write-only): value (address bits 16–19)
; stored at 0040:00B3 and used by programmed FDC transfer as buffer segment.
; ----------------------------------------------------------------------------------------------
nmi_port_081:    ; xrefs: 04BF
F400:06C6  1E              push   ds                          ; Save DS
F400:06C7  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:06CA  8EDB            mov    ds, bx                      ; …into DS
F400:06CC  26A00104        mov    al, byte es:[401h]          ; AL = DMA page number (odd port → F000:0401)
F400:06D0  A2B300          mov    byte [0B3h], al             ; Remember DMA channel 2 page at 0040:00B3
F400:06D3  1F              pop    ds                          ; Restore DS
F400:06D4  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_201 — game adapter (joystick) emulation. The real joystick is digital: with 8255 port B
; bit 7 = 1, port A (F000:0001) returns directions (bits 0–3, active low) and buttons (bits 4–7).
; OUT 201h fires the "one-shots": counters stored at 0040:008C–008F (5 — min, 0Ah — center, 0Fh — max);
; IN 201h decrements them, and an axis bit stays 1 until its counter reaches zero (mimics RC timing).
; ----------------------------------------------------------------------------------------------
nmi_port_201:    ; xrefs: 04C1
F400:06D5  1E              push   ds                          ; Save DS
F400:06D6  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:06D9  8EDB            mov    ds, bx                      ; …into DS
F400:06DB  755B            jne    loc_0738                    ; Write (OUT 201h) — fire one-shots
F400:06DD  26800E030080    or     byte es:[3], 80h            ; Read: set 8255 port B bit 7 — switch port A to joystick lines
F400:06E3  26A00100        mov    al, byte es:[1]             ; AL = joystick state from 8255 port A
F400:06E7  884600          mov    byte [bp], al               ; Put into IN result (bits 4–7 — buttons)
F400:06EA  804E000F        or     byte [bp], 0Fh              ; Bits 0–3 (axes) initially = 1: "one-shots not yet expired"
F400:06EE  A18E00          mov    ax, word [8Eh]              ; AL = joystick A Y-axis counter (0040:008E), AH = X-axis counter (0040:008F)
F400:06F1  0AE4            or     ah, ah                      ; X-axis counter exhausted?
F400:06F3  7506            jne    loc_06FB                    ; No — decrement it
F400:06F5  806600FE        and    byte [bp], 0FEh             ; Yes: bit 0 (joystick A X axis) = 0
F400:06F9  EB04            jmp    loc_06FF                    ; Continue

loc_06FB:    ; xrefs: 06F3
F400:06FB  FE0E8F00        dec    byte [8Fh]                  ; Decrement X-axis counter (0040:008F)

loc_06FF:    ; xrefs: 06F9
F400:06FF  0AC0            or     al, al                      ; Y-axis counter exhausted?
F400:0701  7506            jne    loc_0709                    ; No — decrement it
F400:0703  806600FD        and    byte [bp], 0FDh             ; Yes: bit 1 (joystick A Y axis) = 0
F400:0707  EB04            jmp    loc_070D                    ; Continue

loc_0709:    ; xrefs: 0701
F400:0709  FE0E8E00        dec    byte [8Eh]                  ; Decrement Y-axis counter (0040:008E)

loc_070D:    ; xrefs: 0707
F400:070D  A18C00          mov    ax, word [8Ch]              ; AL = counter 0040:008C, AH = 0040:008D (joystick B axes, always centered)
F400:0710  0AE4            or     ah, ah                      ; Counter 0040:008D exhausted?
F400:0712  7506            jne    loc_071A                    ; No — decrement
F400:0714  806600FB        and    byte [bp], 0FBh             ; Yes: bit 2 (joystick B X axis) = 0
F400:0718  EB04            jmp    loc_071E                    ; Continue

loc_071A:    ; xrefs: 0712
F400:071A  FE0E8D00        dec    byte [8Dh]                  ; Decrement counter 0040:008D

loc_071E:    ; xrefs: 0718
F400:071E  0AC0            or     al, al                      ; Counter 0040:008C exhausted?
F400:0720  7507            jne    loc_0729                    ; No — decrement
F400:0722  806600F7        and    byte [bp], 0F7h             ; Yes: bit 3 (joystick B Y axis) = 0
F400:0726  EB05            jmp    loc_072D                    ; Continue
F400:0728  90              db     90h                         ; NOP filler byte (alignment after short jmp)

loc_0729:    ; xrefs: 0720
F400:0729  FE0E8C00        dec    byte [8Ch]                  ; Decrement counter 0040:008C

loc_072D:    ; xrefs: 0726
F400:072D  26802603007F    and    byte es:[3], 7Fh            ; Clear 8255 port B bit 7 — port A returns keyboard scan codes again
F400:0733  8A4600          mov    al, byte [bp]               ; AL = final IN 201h value
F400:0736  1F              pop    ds                          ; Restore DS
F400:0737  C3              ret                                ; Return

loc_0738:    ; xrefs: 06DB
F400:0738  26800E030080    or     byte es:[3], 80h            ; Write: set port B bit 7 — port A to joystick lines
F400:073E  26A00100        mov    al, byte es:[1]             ; AL = joystick direction state (active low)
F400:0742  26802603007F    and    byte es:[3], 7Fh            ; Switch port A back to keyboard
F400:0748  C6068C000A      mov    byte [8Ch], 0Ah             ; Counter 0040:008C (joystick B) = 0Ah — center
F400:074D  C6068D000A      mov    byte [8Dh], 0Ah             ; Counter 0040:008D (joystick B) = 0Ah — center
F400:0752  C6068E000A      mov    byte [8Eh], 0Ah             ; Joystick A Y-axis counter (0040:008E) = 0Ah — center
F400:0757  C6068F000A      mov    byte [8Fh], 0Ah             ; Joystick A X-axis counter (0040:008F) = 0Ah — center
F400:075C  A801            test   al, 1                       ; Bit 0 line (probably "left") active?
F400:075E  7505            jne    loc_0765                    ; No — leave as is
F400:0760  C6068F0005      mov    byte [8Fh], 5               ; Pressed: X axis = 5 (minimum)

loc_0765:    ; xrefs: 075E
F400:0765  A802            test   al, 2                       ; Bit 1 line (probably "right") active?
F400:0767  7505            jne    loc_076E                    ; No — leave as is
F400:0769  C6068F000F      mov    byte [8Fh], 0Fh             ; Pressed: X axis = 0Fh (maximum)

loc_076E:    ; xrefs: 0767
F400:076E  A804            test   al, 4                       ; Bit 2 line (probably "up") active?
F400:0770  7505            jne    loc_0777                    ; No — leave as is
F400:0772  C6068E0005      mov    byte [8Eh], 5               ; Pressed: Y axis = 5 (minimum)

loc_0777:    ; xrefs: 0770
F400:0777  A808            test   al, 8                       ; Bit 3 line (probably "down") active?
F400:0779  7505            jne    loc_0780                    ; No — leave as is
F400:077B  C6068E000F      mov    byte [8Eh], 0Fh             ; Pressed: Y axis = 0Fh (maximum)

loc_0780:    ; xrefs: 0779
F400:0780  1F              pop    ds                          ; Restore DS
F400:0781  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_378 — LPT1 data register. Write — to printer output register F000:0A01 and copy
; 0040:00BC; read returns the copy (real data register is not readable).
; ----------------------------------------------------------------------------------------------
nmi_port_378:    ; xrefs: 04D3
F400:0782  1E              push   ds                          ; Save DS
F400:0783  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:0786  8EDB            mov    ds, bx                      ; …into DS
F400:0788  7505            jne    loc_078F                    ; Write — output data
F400:078A  A0BC00          mov    al, byte [0BCh]             ; Read: last output byte from copy 0040:00BC
F400:078D  EB1D            jmp    loc_07AC                    ; To exit with result

loc_078F:    ; xrefs: 0788
F400:078F  26A00004        mov    al, byte es:[400h]          ; AL = byte to output (even port → F000:0400)
F400:0793  26A2010A        mov    byte es:[0A01h], al         ; Write to printer data register (F000:0A01)
F400:0797  A2BC00          mov    byte [0BCh], al             ; Remember at 0040:00BC for later reads
F400:079A  1F              pop    ds                          ; Restore DS
F400:079B  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_379 — LPT1 status register (read-only). Bits 3 (ERROR), 5 (PE), 7 (BUSY, inverted)
; are taken from real F000:0A01; bit 6 (ACK) and bit 4 (SELECT) are always 1.
; Also holds common tail loc_07AC (AL → IN result, exit) for ports 378–37A.
; ----------------------------------------------------------------------------------------------
nmi_port_379:    ; xrefs: 04D5
F400:079C  1E              push   ds                          ; Save DS
F400:079D  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:07A0  8EDB            mov    ds, bx                      ; …into DS
F400:07A2  750B            jne    loc_07AF                    ; Write to status port — ignore
F400:07A4  26A0010A        mov    al, byte es:[0A01h]         ; Read: printer line status from F000:0A01
F400:07A8  24A8            and    al, 0A8h                    ; Keep BUSY (7), PE (5), ERROR (3)
F400:07AA  34D0            xor    al, 0D0h                    ; Invert BUSY; ACK=1 and SELECT=1 always (printer always "selected")

loc_07AC:    ; xrefs: 078D 07BC
F400:07AC  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame

loc_07AF:    ; xrefs: 07A2
F400:07AF  1F              pop    ds                          ; Restore DS
F400:07B0  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_37A — LPT1 control register. Write is stored at 0040:00BD and output to F000:0401
; (probably the printer control output register) with bit 1 (AUTOFEED) inverted; read — from the copy.
; ----------------------------------------------------------------------------------------------
nmi_port_37A:    ; xrefs: 04D7
F400:07B1  1E              push   ds                          ; Save DS
F400:07B2  BB4000          mov    bx, 40h                     ; BIOS data area segment…
F400:07B5  8EDB            mov    ds, bx                      ; …into DS
F400:07B7  7505            jne    loc_07BE                    ; Write — output control byte
F400:07B9  A0BD00          mov    al, byte [0BDh]             ; Read: last written value from 0040:00BD
F400:07BC  EBEE            jmp    loc_07AC                    ; To exit with result

loc_07BE:    ; xrefs: 07B7
F400:07BE  26A00004        mov    al, byte es:[400h]          ; AL = control byte (even port → F000:0400)
F400:07C2  A2BD00          mov    byte [0BDh], al             ; Save copy at 0040:00BD
F400:07C5  3402            xor    al, 2                       ; Invert bit 1 (AUTO FEED) for hardware
F400:07C7  26A20104        mov    byte es:[401h], al          ; Write to F000:0401 — probably printer STROBE/INIT/SLCTIN/AUTOFD register
F400:07CB  1F              pop    ds                          ; Restore DS
F400:07CC  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2F8 — COM2 8250, RBR/THR register (DLL when DLAB=1) (receiver/transmitter or baud divisor low byte). Real UART mapped at F000:0DF0:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2F8:    ; xrefs: 04C3
F400:07CD  7508            jne    loc_07D7                    ; Write (OUT 2F8h) — pass to real 8250
F400:07CF  26A0F00D        mov    al, byte es:[0DF0h]         ; Read: COM2 RBR/THR from real UART (F000:0DF0)
F400:07D3  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:07D6  C3              ret                                ; Return

loc_07D7:    ; xrefs: 07CD
F400:07D7  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:07DB  26A2F00D        mov    byte es:[0DF0h], al         ; Write to COM2 RBR/THR (F000:0DF0)
F400:07DF  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2F9 — COM2 8250, IER register (DLM when DLAB=1) (interrupt enable or divisor high byte). Real UART mapped at F000:0DF2:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2F9:    ; xrefs: 04C5
F400:07E0  7508            jne    loc_07EA                    ; Write (OUT 2F9h) — pass to real 8250
F400:07E2  26A0F20D        mov    al, byte es:[0DF2h]         ; Read: COM2 IER from real UART (F000:0DF2)
F400:07E6  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:07E9  C3              ret                                ; Return

loc_07EA:    ; xrefs: 07E0
F400:07EA  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:07EE  26A2F20D        mov    byte es:[0DF2h], al         ; Write to COM2 IER (F000:0DF2)
F400:07F2  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2FA — COM2 8250, IIR register (interrupt identification). Real UART mapped at F000:0DF4:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2FA:    ; xrefs: 04C7
F400:07F3  7508            jne    loc_07FD                    ; Write (OUT 2FAh) — pass to real 8250
F400:07F5  26A0F40D        mov    al, byte es:[0DF4h]         ; Read: COM2 IIR from real UART (F000:0DF4)
F400:07F9  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:07FC  C3              ret                                ; Return

loc_07FD:    ; xrefs: 07F3
F400:07FD  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0801  26A2F40D        mov    byte es:[0DF4h], al         ; Write to COM2 IIR (F000:0DF4)
F400:0805  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2FB — COM2 8250, LCR register (frame format, bit 7 DLAB). Real UART mapped at F000:0DF6:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2FB:    ; xrefs: 04C9
F400:0806  7508            jne    loc_0810                    ; Write (OUT 2FBh) — pass to real 8250
F400:0808  26A0F60D        mov    al, byte es:[0DF6h]         ; Read: COM2 LCR from real UART (F000:0DF6)
F400:080C  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:080F  C3              ret                                ; Return

loc_0810:    ; xrefs: 0806
F400:0810  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:0814  26A2F60D        mov    byte es:[0DF6h], al         ; Write to COM2 LCR (F000:0DF6)
F400:0818  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2FC — COM2 8250, MCR register (DTR/RTS/OUT1/OUT2/loopback). Real UART mapped at F000:0DF8:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2FC:    ; xrefs: 04CB
F400:0819  7508            jne    loc_0823                    ; Write (OUT 2FCh) — pass to real 8250
F400:081B  26A0F80D        mov    al, byte es:[0DF8h]         ; Read: COM2 MCR from real UART (F000:0DF8)
F400:081F  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:0822  C3              ret                                ; Return

loc_0823:    ; xrefs: 0819
F400:0823  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0827  26A2F80D        mov    byte es:[0DF8h], al         ; Write to COM2 MCR (F000:0DF8)
F400:082B  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2FD — COM2 8250, LSR register (line status). Real UART mapped at F000:0DFA:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2FD:    ; xrefs: 04CD
F400:082C  7508            jne    loc_0836                    ; Write (OUT 2FDh) — pass to real 8250
F400:082E  26A0FA0D        mov    al, byte es:[0DFAh]         ; Read: COM2 LSR from real UART (F000:0DFA)
F400:0832  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:0835  C3              ret                                ; Return

loc_0836:    ; xrefs: 082C
F400:0836  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:083A  26A2FA0D        mov    byte es:[0DFAh], al         ; Write to COM2 LSR (F000:0DFA)
F400:083E  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2FE — COM2 8250, MSR register (modem status). Real UART mapped at F000:0DFC:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2FE:    ; xrefs: 04CF
F400:083F  7508            jne    loc_0849                    ; Write (OUT 2FEh) — pass to real 8250
F400:0841  26A0FC0D        mov    al, byte es:[0DFCh]         ; Read: COM2 MSR from real UART (F000:0DFC)
F400:0845  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:0848  C3              ret                                ; Return

loc_0849:    ; xrefs: 083F
F400:0849  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:084D  26A2FC0D        mov    byte es:[0DFCh], al         ; Write to COM2 MSR (F000:0DFC)
F400:0851  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_2FF — COM2 8250, SCR register (scratch register). Real UART mapped at F000:0DFE:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_2FF:    ; xrefs: 04D1
F400:0852  7508            jne    loc_085C                    ; Write (OUT 2FFh) — pass to real 8250
F400:0854  26A0FE0D        mov    al, byte es:[0DFEh]         ; Read: COM2 SCR from real UART (F000:0DFE)
F400:0858  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:085B  C3              ret                                ; Return

loc_085C:    ; xrefs: 0852
F400:085C  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:0860  26A2FE0D        mov    byte es:[0DFEh], al         ; Write to COM2 SCR (F000:0DFE)
F400:0864  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_3F8 — COM1 8250, RBR/THR register (DLL when DLAB=1) (receiver/transmitter or baud divisor low byte). Real UART mapped at F000:0E10:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_3F8:    ; xrefs: 04DF
F400:0865  7508            jne    loc_086F                    ; Write (OUT 3F8h) — pass to real 8250
F400:0867  26A0100E        mov    al, byte es:[0E10h]         ; Read: COM1 RBR/THR from real UART (F000:0E10)
F400:086B  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:086E  C3              ret                                ; Return

loc_086F:    ; xrefs: 0865
F400:086F  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0873  26A2100E        mov    byte es:[0E10h], al         ; Write to COM1 RBR/THR (F000:0E10)
F400:0877  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_3F9 — COM1 8250, IER register (DLM when DLAB=1) (interrupt enable or divisor high byte). Real UART mapped at F000:0E12:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_3F9:    ; xrefs: 04E1
F400:0878  7508            jne    loc_0882                    ; Write (OUT 3F9h) — pass to real 8250
F400:087A  26A0120E        mov    al, byte es:[0E12h]         ; Read: COM1 IER from real UART (F000:0E12)
F400:087E  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:0881  C3              ret                                ; Return

loc_0882:    ; xrefs: 0878
F400:0882  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:0886  26A2120E        mov    byte es:[0E12h], al         ; Write to COM1 IER (F000:0E12)
F400:088A  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_3FA — COM1 8250, IIR register (interrupt identification). Real UART mapped at F000:0E14:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_3FA:    ; xrefs: 04E3
F400:088B  7508            jne    loc_0895                    ; Write (OUT 3FAh) — pass to real 8250
F400:088D  26A0140E        mov    al, byte es:[0E14h]         ; Read: COM1 IIR from real UART (F000:0E14)
F400:0891  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:0894  C3              ret                                ; Return

loc_0895:    ; xrefs: 088B
F400:0895  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0899  26A2140E        mov    byte es:[0E14h], al         ; Write to COM1 IIR (F000:0E14)
F400:089D  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_3FB — COM1 8250, LCR register (frame format, bit 7 DLAB). Real UART mapped at F000:0E16:
; reads and writes pass straight through, the port is only redirected.
; ----------------------------------------------------------------------------------------------
nmi_port_3FB:    ; xrefs: 04E5
F400:089E  7508            jne    loc_08A8                    ; Write (OUT 3FBh) — pass to real 8250
F400:08A0  26A0160E        mov    al, byte es:[0E16h]         ; Read: COM1 LCR from real UART (F000:0E16)
F400:08A4  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:08A7  C3              ret                                ; Return

loc_08A8:    ; xrefs: 089E
F400:08A8  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:08AC  26A2160E        mov    byte es:[0E16h], al         ; Write to COM1 LCR (F000:0E16)
F400:08B0  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_3FC — COM1 8250, MCR register (DTR/RTS/OUT1/OUT2/loopback). Real UART mapped at F000:0E18:
; reads and writes pass straight through, the port is only redirected.
; OUT2 (MCR bit 3) is also used by INT0F_IRQ_DISPATCH to re-enable COM1 IRQ.
; ----------------------------------------------------------------------------------------------
nmi_port_3FC:    ; xrefs: 04E7
F400:08B1  7508            jne    loc_08BB                    ; Write (OUT 3FCh) — pass to real 8250
F400:08B3  26A0180E        mov    al, byte es:[0E18h]         ; Read: COM1 MCR from real UART (F000:0E18)
F400:08B7  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:08BA  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; Write to 3FC (8250 COM1 MCR): pass byte to real MCR register (F000:0E18)
; ----------------------------------------------------------------------------------------------
loc_08BB:    ; xrefs: 08B1
F400:08BB  26A00004        mov    al, byte es:[400h]          ; AL = byte written by program (even port → low data bus, latch F000:0400)
F400:08BF  26A2180E        mov    byte es:[0E18h], al         ; store into MCR of real 8250 COM1 (F000:0E18; bit 3 = OUT2 — IRQ enable)
F400:08C3  C3              ret                                ; return to NMI_HANDLER

; ----------------------------------------------------------------------------------------------
; nmi_port_3FD — COM1 port 3FD: 8250 LSR (line status register).
; Entry: ZF=1 — read (IN), ZF=0 — write (OUT). Real 8250 COM1 is mapped at F000:0E10–0E1E, stride 2.
; Read: value goes into the interrupted program's saved AL ([bp+0]).
; ----------------------------------------------------------------------------------------------
nmi_port_3FD:    ; xrefs: 04E9
F400:08C4  7508            jne    loc_08CE                    ; ZF=0 → write (OUT 3FD), take write branch
F400:08C6  26A01A0E        mov    al, byte es:[0E1Ah]         ; read: fetch LSR from real 8250 (F000:0E1A)
F400:08CA  884600          mov    byte [bp], al               ; put result into interrupted program's saved AL — IN result
F400:08CD  C3              ret                                ; return to NMI_HANDLER

; ----------------------------------------------------------------------------------------------
; Write to 3FD (LSR, normally not written) — forward to register F000:0E1A
; ----------------------------------------------------------------------------------------------
loc_08CE:    ; xrefs: 08C4
F400:08CE  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → high data bus, latch F000:0401)
F400:08D2  26A21A0E        mov    byte es:[0E1Ah], al         ; write to LSR of real 8250 (F000:0E1A)
F400:08D6  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3FE — COM1 port 3FE: 8250 MSR (modem status). ZF=1 read, ZF=0 write
; ----------------------------------------------------------------------------------------------
nmi_port_3FE:    ; xrefs: 04EB
F400:08D7  7508            jne    loc_08E1                    ; ZF=0 → port write
F400:08D9  26A01C0E        mov    al, byte es:[0E1Ch]         ; read MSR of real 8250 (F000:0E1C)
F400:08DD  884600          mov    byte [bp], al               ; return to program in AL
F400:08E0  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Write to 3FE (MSR) — forward to F000:0E1C
; ----------------------------------------------------------------------------------------------
loc_08E1:    ; xrefs: 08D7
F400:08E1  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → latch F000:0400)
F400:08E5  26A21C0E        mov    byte es:[0E1Ch], al         ; to MSR of real 8250 (F000:0E1C)
F400:08E9  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3FF — COM1 port 3FF: 8250 SCR (scratch register). ZF=1 read, ZF=0 write
; ----------------------------------------------------------------------------------------------
nmi_port_3FF:    ; xrefs: 04ED
F400:08EA  7508            jne    loc_08F4                    ; ZF=0 → write
F400:08EC  26A01E0E        mov    al, byte es:[0E1Eh]         ; read SCR of real 8250 (F000:0E1E)
F400:08F0  884600          mov    byte [bp], al               ; IN result → saved AL
F400:08F3  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Write to 3FF (SCR) — forward to F000:0E1E
; ----------------------------------------------------------------------------------------------
loc_08F4:    ; xrefs: 08EA
F400:08F4  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → latch F000:0401)
F400:08F8  26A21E0E        mov    byte es:[0E1Eh], al         ; to SCR of real 8250 (F000:0E1E)
F400:08FC  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; 6845 video controller parameter tables for emulating mode changes via port 3D8.
; 4 tables of 16 bytes (R0–R15), only R0–R9 (10 bytes) are loaded. Same values as at F000:F0A4.
; 08FD — 40x25 text, 090D — 80x25 text, 091D — 320/640x200 graphics, 092D — 80x25 "text" with R9=1 (160x100, 100 rows)
; ----------------------------------------------------------------------------------------------
F400:08FD  3F2831041F06…   db     3Fh,28h,31h,04h,1Fh,06h,19h,1Ch ; 40x25 text: R0 Htotal=3Fh, R1 Hdisp=28h(40), R2 Hsync=31h, R3 width=4, R4 Vtotal=1Fh, R5=6, R6 Vdisp=19h(25), R7 Vsync=1Ch
F400:0905  020706070000…   db     02h,07h,06h,07h,00h,00h,00h,00h ; R8 interlace=2, R9 max scan line=7 (8 lines); R10/R11 cursor 6–7, R12–R15=0 (not loaded)
F400:090D  7F5063081F06…   db     7Fh,50h,63h,08h,1Fh,06h,19h,1Ch ; 80x25 text: R0=7Fh, R1=50h(80), R2=63h, R3=8, R4=1Fh, R5=6, R6=19h(25), R7=1Ch
F400:0915  020706070000…   db     02h,07h,06h,07h,00h,00h,00h,00h ; R8=2, R9=7 (8-line character); cursor 6–7, start/cursor addresses 0
F400:091D  3F2831047F06…   db     3Fh,28h,31h,04h,7Fh,06h,64h,70h ; 320x200 / 640x200 graphics: R0=3Fh, R1=28h, R2=31h, R3=4, R4=7Fh, R5=6, R6=64h(100), R7=70h
F400:0925  020106070000…   db     02h,01h,06h,07h,00h,00h,00h,00h ; R8=2, R9=1 (2 scan lines per "character"); R10–R15 unused
F400:092D  7F5063087F06…   db     7Fh,50h,63h,08h,7Fh,06h,64h,70h ; 80x25 with R9=1 → 160x100 (100 rows of 2 scan lines): R0=7Fh,R1=50h,R2=63h,R3=8,R4=7Fh,R5=6,R6=64h,R7=70h
F400:0935  020106070000…   db     02h,01h,06h,07h,00h,00h,00h,00h ; R8=2, R9=1; cursor 6–7, rest 0

; ----------------------------------------------------------------------------------------------
; nmi_port_3D4 — write to 6845 index register (CRTC address).
; Index is only remembered at 0040:00B4 (shadow copy), not passed to the real 6845 until 3D5 is accessed.
; ----------------------------------------------------------------------------------------------
nmi_port_3D4:    ; xrefs: 049F
F400:093D  1E              push   ds                          ; save interrupted program's DS
F400:093E  BB4000          mov    bx, 40h                     ; BIOS data area segment 0040h
F400:0941  8EDB            mov    ds, bx                      ; DS = 0040h
F400:0943  26A00004        mov    al, byte es:[400h]          ; AL = 6845 register number written (even port → latch F000:0400)
F400:0947  A2B400          mov    byte [0B4h], al             ; 0040:00B4 — shadow CRTC index (emulated 6845 address register)
F400:094A  1F              pop    ds                          ; restore DS
F400:094B  C3              ret                                ; return to NMI_HANDLER

; ----------------------------------------------------------------------------------------------
; nmi_port_3D5 — 6845 data register. Real 6845 is mapped: F000:0000 = address, F000:0002 = data.
; Read: select register by shadow index and read. Write: R0–R8 ignored (sync timing protected),
; R9 only remembered at 0040:00B8 (R9=1 in 80-column mode → 160x100 mode), R10–R17 written to the 6845.
; ----------------------------------------------------------------------------------------------
nmi_port_3D5:    ; xrefs: 04A1
F400:094C  1E              push   ds                          ; save DS
F400:094D  BB4000          mov    bx, 40h                     ; segment 0040h
F400:0950  8EDB            mov    ds, bx                      ; DS = BIOS data area
F400:0952  8A26B400        mov    ah, byte [0B4h]             ; AH = shadow CRTC index from 0040:00B4 (flags unchanged, ZF still from NMI_HANDLER)
F400:0956  750E            jne    loc_0966                    ; ZF=0 → write to 3D5
F400:0958  2688260000      mov    byte es:[0], ah             ; read: put index into real 6845 address register (F000:0000)
F400:095D  26A00200        mov    al, byte es:[2]             ; read selected 6845 register (F000:0002)
F400:0961  884600          mov    byte [bp], al               ; IN result → program's saved AL
F400:0964  1F              pop    ds                          ; restore DS
F400:0965  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Write to 3D5: filter by register number
; ----------------------------------------------------------------------------------------------
loc_0966:    ; xrefs: 0956
F400:0966  80FC09          cmp    ah, 9                       ; compare index with 9 (R9 — max scan line)
F400:0969  7F18            jg     loc_0983                    ; R10 and up (cursor, start address) → pass to real 6845
F400:096B  7514            jne    loc_0981                    ; R0–R8 (timing, sync) — write ignored, protects the monitor
F400:096D  26A00104        mov    al, byte es:[401h]          ; R9: AL = value written (odd port → latch F000:0401)
F400:0971  A2B800          mov    byte [0B8h], al             ; remember R9 at 0040:00B8 (max scan line shadow copy)
F400:0974  3C01            cmp    al, 1                       ; R9=1? (trick for 160x100 16-color mode on CGA)
F400:0976  7509            jne    loc_0981                    ; otherwise do nothing
F400:0978  A0B500          mov    al, byte [0B5h]             ; AL = shadow mode register 3D8 (0040:00B5)
F400:097B  2403            and    al, 3                       ; bits 0–1: bit0 = 80 columns, bit1 = graphics
F400:097D  3C01            cmp    al, 1                       ; "80-column text" mode?
F400:097F  7444            je     loc_09C5                    ; yes → reprogram 6845 with 160x100 table (092D)

loc_0981:    ; xrefs: 096B 0976
F400:0981  1F              pop    ds                          ; restore DS
F400:0982  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Write to R10 and up: pass directly to real 6845
; ----------------------------------------------------------------------------------------------
loc_0983:    ; xrefs: 0969
F400:0983  2688260000      mov    byte es:[0], ah             ; register number → 6845 address register (F000:0000)
F400:0988  26A00104        mov    al, byte es:[401h]          ; AL = value written (latch F000:0401, odd port)
F400:098C  26A20200        mov    byte es:[2], al             ; to 6845 data register (F000:0002)
F400:0990  1F              pop    ds                          ; restore DS
F400:0991  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3D8 — write to CGA mode register (Mode Control).
; The new value (with bit 3 forced on — video enabled) is stored at 0040:00B5.
; When the mode type (bits 0–1) changes, the real 6845 is reprogrammed from table 08FD/090D/091D/092D;
; then the pair (color 3D9, mode 3D8) is written to hardware register F000:0200/0201.
; ----------------------------------------------------------------------------------------------
nmi_port_3D8:    ; xrefs: 04A3
F400:0992  1E              push   ds                          ; save DS
F400:0993  BB4000          mov    bx, 40h                     ; segment 0040h
F400:0996  8EDB            mov    ds, bx                      ; DS = BIOS data area
F400:0998  268A260004      mov    ah, byte es:[400h]          ; AH = mode byte written (even port → latch F000:0400)
F400:099D  80CC08          or     ah, 8                       ; bit 3 (video enable) always on — screen blanking not emulated
F400:09A0  A0B500          mov    al, byte [0B5h]             ; AL = old mode from shadow register 0040:00B5
F400:09A3  8826B500        mov    byte [0B5h], ah             ; remember new mode at 0040:00B5
F400:09A7  80E403          and    ah, 3                       ; new bits 0–1 (80 columns / graphics)
F400:09AA  2403            and    al, 3                       ; old bits 0–1
F400:09AC  3AC4            cmp    al, ah                      ; mode type unchanged?
F400:09AE  7435            je     loc_09E5                    ; yes → just update hardware mode register, no 6845 reprogramming
F400:09B0  0AE4            or     ah, ah                      ; check: 00 = 40x25 text?
F400:09B2  BBFD08          mov    bx, 8FDh                    ; BX = 6845 table for 40x25 (F400:08FD)
F400:09B5  7416            je     loc_09CD                    ; 40x25 text → load
F400:09B7  BB0D09          mov    bx, 90Dh                    ; BX = table for 80x25 (F400:090D)
F400:09BA  FECC            dec    ah                          ; mode 01?
F400:09BC  750C            jne    loc_09CA                    ; 10 or 11 (graphics) → table 091D
F400:09BE  803EB80001      cmp    byte [0B8h], 1              ; 80x25 text: was R9=1 written earlier (0040:00B8)?
F400:09C3  7508            jne    loc_09CD                    ; no → normal 80x25

loc_09C5:    ; xrefs: 097F
F400:09C5  BB2D09          mov    bx, 92Dh                    ; yes → BX = 160x100 table (F400:092D); also entered from 3D5 when R9=1 is written
F400:09C8  EB03            jmp    loc_09CD                    ; go load table

loc_09CA:    ; xrefs: 09BC
F400:09CA  BB1D09          mov    bx, 91Dh                    ; graphics modes → table F400:091D

; ----------------------------------------------------------------------------------------------
; Load R0–R9 of real 6845 from table CS:BX (10 bytes)
; ----------------------------------------------------------------------------------------------
loc_09CD:    ; xrefs: 09B5 09C3 09C8
F400:09CD  33C0            xor    ax, ax                      ; AH = 6845 register number, starting at R0
F400:09CF  51              push   cx                          ; save interrupted program's CX
F400:09D0  B90A00          mov    cx, 0Ah                     ; 10 registers R0–R9

loc_09D3:    ; xrefs: 09E2
F400:09D3  2688260000      mov    byte es:[0], ah             ; register number → 6845 address register (F000:0000)
F400:09D8  2E8A07          mov    al, byte cs:[bx]            ; value from ROM table
F400:09DB  26A20200        mov    byte es:[2], al             ; write to 6845 data register (F000:0002)
F400:09DF  FEC4            inc    ah                          ; next register
F400:09E1  43              inc    bx                          ; next table byte
F400:09E2  E2EF            loop   loc_09D3                    ; loop over 10 registers
F400:09E4  59              pop    cx                          ; restore CX

; ----------------------------------------------------------------------------------------------
; Write shadow mode/color registers to video hardware: F000:0201 = mode (3D8), F000:0200 = color (3D9)
; ----------------------------------------------------------------------------------------------
loc_09E5:    ; xrefs: 09AE
F400:09E5  8A26B500        mov    ah, byte [0B5h]             ; AH = mode register (0040:00B5)
F400:09E9  A0B600          mov    al, byte [0B6h]             ; AL = color select register (0040:00B6)
F400:09EC  26A30002        mov    word es:[200h], ax          ; write to hardware video mode register F000:0200 (low byte — color, high — mode)
F400:09F0  1F              pop    ds                          ; restore DS
F400:09F1  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3D9 — write to CGA color select register (Color Select).
; Stored at 0040:00B6 and written together with the mode register to hardware register F000:0200.
; ----------------------------------------------------------------------------------------------
nmi_port_3D9:    ; xrefs: 04A5
F400:09F2  1E              push   ds                          ; save DS
F400:09F3  BB4000          mov    bx, 40h                     ; segment 0040h
F400:09F6  8EDB            mov    ds, bx                      ; DS = BIOS data area
F400:09F8  26A00104        mov    al, byte es:[401h]          ; AL = color byte written (odd port → latch F000:0401)
F400:09FC  A2B600          mov    byte [0B6h], al             ; shadow color register 0040:00B6
F400:09FF  8A26B500        mov    ah, byte [0B5h]             ; AH = shadow mode register 0040:00B5
F400:0A03  26A30002        mov    word es:[200h], ax          ; to hardware video register F000:0200 (AL=color, AH=mode)
F400:0A07  1F              pop    ds                          ; restore DS
F400:0A08  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3DA — read CGA status register (Status).
; There is no real retrace signal: on every read bits 0 (display enable/horizontal retrace) and
; 3 (vertical retrace) are toggled so programs waiting for retrace do not hang.
; ----------------------------------------------------------------------------------------------
nmi_port_3DA:    ; xrefs: 04A7
F400:0A09  1E              push   ds                          ; save DS
F400:0A0A  BB4000          mov    bx, 40h                     ; segment 0040h
F400:0A0D  8EDB            mov    ds, bx                      ; DS = BIOS data area
F400:0A0F  8036B70009      xor    byte [0B7h], 9              ; 0040:00B7 — emulated 3DA status: toggle bits 0 and 3 on every read
F400:0A14  A0B700          mov    al, byte [0B7h]             ; AL = new status value
F400:0A17  884600          mov    byte [bp], al               ; IN result → saved AL (writes to 3DA are simply ignored)
F400:0A1A  1F              pop    ds                          ; restore DS
F400:0A1B  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; 765 floppy command emulation tables (used by nmi_port_3F5).
; 0A1C: 15 765 command codes (low 5 bits of first byte); 0A2B: 15 matching descriptor bytes:
; low nibble = command length in bytes, bit7 = has data phase (pseudo-DMA),
; bit6 = direction memory→floppy (write), bit5 = command raises no interrupt.
; ----------------------------------------------------------------------------------------------
F400:0A1C  060C0509020A…   db     06h,0Ch,05h,09h,02h,0Ah,0Dh,11h ; codes: 06 read data, 0C read deleted, 05 write data, 09 write deleted, 02 read track, 0A read ID, 0D format, 11 scan equal
F400:0A24  191D07080304…   db     19h,1Dh,07h,08h,03h,04h,0Fh,89h ; codes: 19 scan low/eq, 1D scan high/eq, 07 recalibrate, 08 sense int, 03 specify, 04 sense drive, 0F seek; 0A2B: 89=read, 9 bytes
F400:0A2C  89C9C98902C6…   db     89h,0C9h,0C9h,89h,02h,0C6h,0C9h,0C9h ; descr.: 89 read deleted, C9 write, C9 write deleted, 89 read track, 02 read ID, C6 format (6 bytes, write), C9 scan eq, C9 scan le
F400:0A34  C90221230203    db     0C9h,02h,21h,23h,02h,03h    ; descr.: C9 scan he, 02 recalibrate, 21 sense int (1 byte, no IRQ), 23 specify (no IRQ), 02 sense drive, 03 seek

; ----------------------------------------------------------------------------------------------
; nmi_port_3F2 — write to floppy drive control register (DOR, Digital Output Register).
; Drive select bits 0–1 are converted to a one-hot code (drive 0 → bit0, 1 → bit1), bit 3
; (IRQ/DMA enable) is forced on; result goes to 0040:00B9 and hardware register F000:0601.
; On reset release (bit 2: 0→1) the post-reset 765 interrupt is emulated: wait for floppy IRQ and call INT 0Eh.
; ----------------------------------------------------------------------------------------------
nmi_port_3F2:    ; xrefs: 04D9
F400:0A3A  51              push   cx                          ; save interrupted program's registers used below
F400:0A3B  52              push   dx                          ; save DX
F400:0A3C  57              push   di                          ; save DI
F400:0A3D  56              push   si                          ; save SI
F400:0A3E  1E              push   ds                          ; save DS
F400:0A3F  BB4000          mov    bx, 40h                     ; segment 0040h
F400:0A42  8EDB            mov    ds, bx                      ; DS = BIOS data area
F400:0A44  26A00004        mov    al, byte es:[400h]          ; AL = DOR byte written (even port → latch F000:0400)
F400:0A48  8A26B900        mov    ah, byte [0B9h]             ; AH = previous DOR value (shadow register 0040:00B9)
F400:0A4C  F6C404          test   ah, 4                       ; controller already out of reset (bit 2 = /RESET)?
F400:0A4F  7540            jne    loc_0A91                    ; yes → just update control register
F400:0A51  A804            test   al, 4                       ; new value releases reset?
F400:0A53  743C            je     loc_0A91                    ; no (stay in reset) → just update register
F400:0A55  8AC8            mov    cl, al                      ; reset→run transition: CL = drive number bit 0 (2 drives supported)
F400:0A57  80E101          and    cl, 1                       ; bit 0 only
F400:0A5A  B401            mov    ah, 1                       ; AH = 1
F400:0A5C  D2E4            shl    ah, cl                      ; AH = 1 << drive → one-hot select code (01 or 02)
F400:0A5E  24FC            and    al, 0FCh                    ; clear drive select field
F400:0A60  0AC4            or     al, ah                      ; insert one-hot select code
F400:0A62  0C08            or     al, 8                       ; bit 3 — floppy interrupt enable (flag "no pseudo-DMA transfer")
F400:0A64  A2B900          mov    byte [0B9h], al             ; remember in shadow DOR 0040:00B9
F400:0A67  26A20106        mov    byte es:[601h], al          ; to hardware floppy control register F000:0601 (motors, select, reset)
F400:0A6B  C606BA0000      mov    byte [0BAh], 0              ; 0040:00BA — 765 command intake state: 0 = waiting for first byte of a new command

; ----------------------------------------------------------------------------------------------
; Wait for a 765 interrupt (after reset or command) and deliver it via INT 0Eh.
; Polls bit 15 of word F000:0200 (floppy IRQ request) about 2x65536 times; on timeout exits silently.
; ----------------------------------------------------------------------------------------------
loc_0A70:    ; xrefs: 0B37 0BA9
F400:0A70  FB              sti                                ; enable interrupts (inside NMI) — let timer/keyboard through
F400:0A71  B302            mov    bl, 2                       ; BL = 2 — outer timeout counter
F400:0A73  33C9            xor    cx, cx                      ; CX = 0 → 65536 inner loop iterations

loc_0A75:    ; xrefs: 0A7D 0A81
F400:0A75  26A10002        mov    ax, word es:[200h]          ; read interrupt status word F000:0200
F400:0A79  D0E4            shl    ah, 1                       ; bit 15 (floppy interrupt request) → CF
F400:0A7B  720C            jb     loc_0A89                    ; 765 interrupt present → call handler
F400:0A7D  E2F6            loop   loc_0A75                    ; poll with timeout
F400:0A7F  FECB            dec    bl                          ; outer counter
F400:0A81  75F2            jne    loc_0A75                    ; another round
F400:0A83  1F              pop    ds                          ; timeout: no interrupt — restore registers and exit
F400:0A84  5E              pop    si                          ; restore SI
F400:0A85  5F              pop    di                          ; restore DI
F400:0A86  5A              pop    dx                          ; restore DX
F400:0A87  59              pop    cx                          ; restore CX
F400:0A88  C3              ret                                ; return to NMI_HANDLER

loc_0A89:    ; xrefs: 0A7B
F400:0A89  CD0E            int    0Eh                         ; emulate IRQ6: call floppy handler INT 0Eh (sets bit 7 at 0040:003E)
F400:0A8B  1F              pop    ds                          ; restore DS
F400:0A8C  5E              pop    si                          ; restore SI
F400:0A8D  5F              pop    di                          ; restore DI
F400:0A8E  5A              pop    dx                          ; restore DX
F400:0A8F  59              pop    cx                          ; restore CX
F400:0A90  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Ordinary DOR write (no reset release): same drive select conversion, no interrupt wait
; ----------------------------------------------------------------------------------------------
loc_0A91:    ; xrefs: 0A4F 0A53
F400:0A91  8AC8            mov    cl, al                      ; CL = drive number (bit 0)
F400:0A93  80E101          and    cl, 1                       ; bit 0 only
F400:0A96  B401            mov    ah, 1                       ; AH = 1
F400:0A98  D2E4            shl    ah, cl                      ; one-hot drive select code
F400:0A9A  24FC            and    al, 0FCh                    ; clear bits 0–1
F400:0A9C  0AC4            or     al, ah                      ; insert select code
F400:0A9E  0C08            or     al, 8                       ; bit 3 — floppy IRQ enable
F400:0AA0  A2B900          mov    byte [0B9h], al             ; shadow DOR 0040:00B9
F400:0AA3  26A20106        mov    byte es:[601h], al          ; hardware floppy control register F000:0601
F400:0AA7  1F              pop    ds                          ; restore DS
F400:0AA8  5E              pop    si                          ; restore SI
F400:0AA9  5F              pop    di                          ; restore DI
F400:0AAA  5A              pop    dx                          ; restore DX
F400:0AAB  59              pop    cx                          ; restore CX
F400:0AAC  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3F4 — read 765 main status register (MSR). Real 765: F000:0600 = MSR
; ----------------------------------------------------------------------------------------------
nmi_port_3F4:    ; xrefs: 04DB
F400:0AAD  7507            jne    loc_0AB6                    ; write to 3F4 (not on XT) — ignore
F400:0AAF  26A00006        mov    al, byte es:[600h]          ; read MSR of real 765 (F000:0600)
F400:0AB3  884600          mov    byte [bp], al               ; IN result → saved AL

loc_0AB6:    ; xrefs: 0AAD
F400:0AB6  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3F5 — 765 data register. Read — straight from F000:0602.
; Write — command/parameter byte; command bytes are counted via 0040:00BA (tables 0A1C/0A2B).
; On the last byte of a command with a data phase, software "DMA" runs (instead of the 8237): transfer
; to/from the buffer at the address/count previously written to ports 004/005/081, synchronized with WAIT.
; ----------------------------------------------------------------------------------------------
nmi_port_3F5:    ; xrefs: 04DD
F400:0AB7  51              push   cx                          ; save CX
F400:0AB8  52              push   dx                          ; save DX
F400:0AB9  57              push   di                          ; save DI
F400:0ABA  56              push   si                          ; save SI
F400:0ABB  1E              push   ds                          ; save DS (5 words in all — accounted for in INT0F: add sp,16h)
F400:0ABC  BB4000          mov    bx, 40h                     ; segment 0040h
F400:0ABF  8EDB            mov    ds, bx                      ; DS = BIOS data area
F400:0AC1  750D            jne    loc_0AD0                    ; ZF=0 → write to 3F5
F400:0AC3  26A00206        mov    al, byte es:[602h]          ; read: result byte from real 765 data register (F000:0602)
F400:0AC7  884600          mov    byte [bp], al               ; IN result → saved AL
F400:0ACA  1F              pop    ds                          ; restore DS
F400:0ACB  5E              pop    si                          ; restore SI
F400:0ACC  5F              pop    di                          ; restore DI
F400:0ACD  5A              pop    dx                          ; restore DX
F400:0ACE  59              pop    cx                          ; restore CX
F400:0ACF  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Byte write to 765: determine whether it is the first command byte
; ----------------------------------------------------------------------------------------------
loc_0AD0:    ; xrefs: 0AC1
F400:0AD0  8A26BA00        mov    ah, byte [0BAh]             ; AH = command intake state (0040:00BA)
F400:0AD4  80E40F          and    ah, 0Fh                     ; low nibble = command bytes still expected
F400:0AD7  752E            jne    loc_0B07                    ; nonzero → parameter of current command
F400:0AD9  26A00104        mov    al, byte es:[401h]          ; first byte: AL = command code (odd port → latch F000:0401)
F400:0ADD  241F            and    al, 1Fh                     ; drop MT/MF/SK flags (bits 5–7)
F400:0ADF  BF1C0A          mov    di, 0A1Ch                   ; DI = 765 command code table (F400:0A1C)
F400:0AE2  B90F00          mov    cx, 0Fh                     ; 15 codes
F400:0AE5  06              push   es                          ; save ES (=F000)
F400:0AE6  8CCB            mov    bx, cs                      ; ES = CS = F400 for table search
F400:0AE8  8EC3            mov    es, bx                      ; ES = F400
F400:0AEA  F2AE            repne scasb al, byte es:[di]       ; search table for command code
F400:0AEC  07              pop    es                          ; restore ES = F000
F400:0AED  7512            jne    loc_0B01                    ; not found → treat as one-byte command
F400:0AEF  81EF1D0A        sub    di, 0A1Dh                   ; DI = index of found command (0..14)
F400:0AF3  2E8AA52B0A      mov    ah, byte cs:[di + 0A2Bh]    ; AH = command descriptor from table F400:0A2B
F400:0AF8  8826BA00        mov    byte [0BAh], ah             ; to 0040:00BA: length + flags (data/direction/no IRQ)
F400:0AFC  80E40F          and    ah, 0Fh                     ; AH = number of command bytes
F400:0AFF  EB06            jmp    loc_0B07                    ; go process byte

loc_0B01:    ; xrefs: 0AED
F400:0B01  B401            mov    ah, 1                       ; unknown command: length 1 (765 will answer "invalid command")
F400:0B03  8826BA00        mov    byte [0BAh], ah             ; to 0040:00BA

; ----------------------------------------------------------------------------------------------
; Not the last command byte — just pass to 765
; ----------------------------------------------------------------------------------------------
loc_0B07:    ; xrefs: 0AD7 0AFF
F400:0B07  80FC01          cmp    ah, 1                       ; last command byte?
F400:0B0A  7412            je     loc_0B1E                    ; yes → complete command
F400:0B0C  FE0EBA00        dec    byte [0BAh]                 ; decrement remaining byte count
F400:0B10  26A00104        mov    al, byte es:[401h]          ; AL = byte written (latch F000:0401)
F400:0B14  26A20206        mov    byte es:[602h], al          ; to real 765 data register (F000:0602)
F400:0B18  1F              pop    ds                          ; restore DS
F400:0B19  5E              pop    si                          ; restore SI
F400:0B1A  5F              pop    di                          ; restore DI
F400:0B1B  5A              pop    dx                          ; restore DX
F400:0B1C  59              pop    cx                          ; restore CX
F400:0B1D  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Last command byte: if there is a data phase — pseudo-DMA, otherwise pass the byte and
; (if the command raises an interrupt) wait for 765 IRQ → INT 0Eh
; ----------------------------------------------------------------------------------------------
loc_0B1E:    ; xrefs: 0B0A
F400:0B1E  8A26BA00        mov    ah, byte [0BAh]             ; AH = command descriptor
F400:0B22  D0E4            shl    ah, 1                       ; bit 7 (has data phase) → CF
F400:0B24  721A            jb     loc_0B40                    ; command with data transfer → pseudo-DMA
F400:0B26  FE0EBA00        dec    byte [0BAh]                 ; counter → 0 (command accepted)
F400:0B2A  26A00104        mov    al, byte es:[401h]          ; AL = last command byte
F400:0B2E  26A20206        mov    byte es:[602h], al          ; pass to 765 (F000:0602) — command started
F400:0B32  F6C440          test   ah, 40h                     ; bit 5 of original descriptor (bit 6 after shift): command without interrupt?
F400:0B35  7503            jne    loc_0B3A                    ; yes (sense interrupt, specify) → exit immediately
F400:0B37  E936FF          jmp    loc_0A70                    ; otherwise wait for 765 interrupt and call INT 0Eh

loc_0B3A:    ; xrefs: 0B35
F400:0B3A  1F              pop    ds                          ; restore DS
F400:0B3B  5E              pop    si                          ; restore SI
F400:0B3C  5F              pop    di                          ; restore DI
F400:0B3D  5A              pop    dx                          ; restore DX
F400:0B3E  59              pop    cx                          ; restore CX
F400:0B3F  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Channel 2 pseudo-DMA (8237 emulation): buffer address = page (0040:00B3, port 081) : address (0040:009E,
; port 004), length = 0040:00A2 (port 005) + 1. Bytes move via F000:0800 (DACK cycle to 765),
; the last one via F000:0808 (DACK + TC). Each byte waits for ready via WAIT (probably TEST pin ← 765 DRQ).
; ----------------------------------------------------------------------------------------------
loc_0B40:    ; xrefs: 0B24
F400:0B40  33DB            xor    bx, bx                      ; BX = 0
F400:0B42  8A3EB300        mov    bh, byte [0B3h]             ; BH = DMA page (0040:00B3, written via port 081)
F400:0B46  B104            mov    cl, 4                       ; shift by 4
F400:0B48  D3E3            shl    bx, cl                      ; BX = page*1000h — buffer segment (bits A16–A19)
F400:0B4A  8B3E9E00        mov    di, word [9Eh]              ; DI = DMA channel 2 base address (0040:009E, written via port 004)
F400:0B4E  8B0EA200        mov    cx, word [0A2h]             ; CX = channel 2 count (0040:00A2, port 005)
F400:0B52  41              inc    cx                          ; as in 8237: count+1 bytes are transferred
F400:0B53  D0E4            shl    ah, 1                       ; descriptor bit 6 (direction memory→floppy) → CF
F400:0B55  726F            jb     loc_0BC6                    ; write/format command → output-to-765 branch

; ----------------------------------------------------------------------------------------------
; Disk read (floppy → memory) or verify
; ----------------------------------------------------------------------------------------------
F400:0B57  FE0EBA00        dec    byte [0BAh]                 ; command byte counter → 0
F400:0B5B  8A26B900        mov    ah, byte [0B9h]             ; AH = shadow DOR
F400:0B5F  80E4F7          and    ah, 0F7h                    ; clear bit 3: disable floppy IRQ during transfer (flag "pseudo-DMA in progress" for INT0F)
F400:0B62  8826B900        mov    byte [0B9h], ah             ; to 0040:00B9
F400:0B66  2688260106      mov    byte es:[601h], ah          ; to hardware register F000:0601
F400:0B6B  FB              sti                                ; enable interrupts (an early 765 IRQ aborts the transfer via INT0F)
F400:0B6C  803EB20042      cmp    byte [0B2h], 42h            ; DMA mode (0040:00B2, port 00B) = 42h — channel 2 verify?
F400:0B71  7439            je     loc_0BAC                    ; yes → read without storing to memory
F400:0B73  8CC2            mov    dx, es                      ; DX = F000 (register segment)
F400:0B75  8EC3            mov    es, bx                      ; ES = buffer segment
F400:0B77  8CDB            mov    bx, ds                      ; BX = 0040h (saved)
F400:0B79  8EDA            mov    ds, dx                      ; DS = F000 — access to 765 registers
F400:0B7B  A00104          mov    al, byte [401h]             ; AL = last command byte (latch F000:0401)
F400:0B7E  A20206          mov    byte [602h], al             ; pass to 765 (F000:0602) — start command
F400:0B81  EB04            jmp    loc_0B87                    ; go wait for first byte

loc_0B83:    ; xrefs: 0B88
F400:0B83  A00008          mov    al, byte [800h]             ; read data byte from 765 with DACK cycle (F000:0800)
F400:0B86  AA              stosb  byte es:[di], al            ; store to buffer ES:DI, DI++

loc_0B87:    ; xrefs: 0B81
F400:0B87  9B              wait                               ; WAIT — wait for byte ready (probably 765 DRQ on CPU TEST input)
F400:0B88  E2F9            loop   loc_0B83                    ; for all bytes except the last
F400:0B8A  EB00            jmp    loc_0B8C                    ; short jump as delay

loc_0B8C:    ; xrefs: 0B8A
F400:0B8C  FA              cli                                ; disable interrupts
F400:0B8D  A00808          mov    al, byte [808h]             ; read last byte via F000:0808 — DACK with TC (end of transfer for 765)
F400:0B90  AA              stosb  byte es:[di], al            ; to buffer
F400:0B91  8EDB            mov    ds, bx                      ; DS = 0040h
F400:0B93  8EC2            mov    es, dx                      ; ES = F000
F400:0B95  893E9E00        mov    word [9Eh], di              ; update DMA channel 2 current address (0040:009E), as the 8237 does
F400:0B99  890EA200        mov    word [0A2h], cx             ; update channel count (0040:00A2)

; ----------------------------------------------------------------------------------------------
; Transfer complete: re-enable floppy IRQ and wait for command result interrupt
; ----------------------------------------------------------------------------------------------
loc_0B9D:    ; xrefs: 0BC4 0C02
F400:0B9D  A0B900          mov    al, byte [0B9h]             ; AL = shadow DOR
F400:0BA0  0C08            or     al, 8                       ; bit 3 — enable floppy IRQ
F400:0BA2  A2B900          mov    byte [0B9h], al             ; to 0040:00B9
F400:0BA5  26A20106        mov    byte es:[601h], al          ; to hardware register F000:0601
F400:0BA9  E9C4FE          jmp    loc_0A70                    ; wait for 765 IRQ and call INT 0Eh

; ----------------------------------------------------------------------------------------------
; Verify (DMA mode 42h): bytes are read from 765 but not stored
; ----------------------------------------------------------------------------------------------
loc_0BAC:    ; xrefs: 0B71
F400:0BAC  26A00104        mov    al, byte es:[401h]          ; AL = last command byte
F400:0BB0  26A20206        mov    byte es:[602h], al          ; to 765 (F000:0602) — start
F400:0BB4  EB04            jmp    loc_0BBA                    ; go wait

loc_0BB6:    ; xrefs: 0BBB
F400:0BB6  26A00008        mov    al, byte es:[800h]          ; read byte via DACK (F000:0800), result discarded

loc_0BBA:    ; xrefs: 0BB4
F400:0BBA  9B              wait                               ; WAIT — wait for next byte ready
F400:0BBB  E2F9            loop   loc_0BB6                    ; all bytes except the last
F400:0BBD  EB00            jmp    loc_0BBF                    ; delay

loc_0BBF:    ; xrefs: 0BBD
F400:0BBF  26A00808        mov    al, byte es:[808h]          ; last byte — DACK+TC (F000:0808)
F400:0BC3  FA              cli                                ; disable interrupts
F400:0BC4  EBD7            jmp    loc_0B9D                    ; go complete transfer

; ----------------------------------------------------------------------------------------------
; Disk write / format (memory → floppy)
; ----------------------------------------------------------------------------------------------
loc_0BC6:    ; xrefs: 0B55
F400:0BC6  FE0EBA00        dec    byte [0BAh]                 ; command byte counter → 0
F400:0BCA  8A26B900        mov    ah, byte [0B9h]             ; AH = shadow DOR
F400:0BCE  80E4F7          and    ah, 0F7h                    ; clear bit 3 — disable floppy IRQ during transfer
F400:0BD1  8826B900        mov    byte [0B9h], ah             ; to 0040:00B9
F400:0BD5  2688260106      mov    byte es:[601h], ah          ; to hardware register F000:0601
F400:0BDA  FB              sti                                ; enable interrupts
F400:0BDB  8CDA            mov    dx, ds                      ; DX = 0040h (saved)
F400:0BDD  8EDB            mov    ds, bx                      ; DS = buffer segment
F400:0BDF  8BF7            mov    si, di                      ; SI = buffer address
F400:0BE1  26A00104        mov    al, byte es:[401h]          ; AL = last command byte (ES=F000, latch 0401)
F400:0BE5  26A20206        mov    byte es:[602h], al          ; to 765 (F000:0602) — start
F400:0BE9  EB04            jmp    loc_0BEF                    ; go load first byte

loc_0BEB:    ; xrefs: 0BF1
F400:0BEB  26A20008        mov    byte es:[800h], al          ; write byte to 765 with DACK cycle (F000:0800)

loc_0BEF:    ; xrefs: 0BE9
F400:0BEF  AC              lodsb  al, byte [si]               ; AL = next byte from buffer DS:SI
F400:0BF0  9B              wait                               ; WAIT — wait for 765 data request
F400:0BF1  E2F8            loop   loc_0BEB                    ; all bytes except the last
F400:0BF3  FA              cli                                ; disable interrupts
F400:0BF4  26A20808        mov    byte es:[808h], al          ; last byte — DACK+TC (F000:0808)
F400:0BF8  8EDA            mov    ds, dx                      ; DS = 0040h
F400:0BFA  89369E00        mov    word [9Eh], si              ; update DMA channel 2 address (0040:009E)
F400:0BFE  890EA200        mov    word [0A2h], cx             ; update count (0040:00A2)
F400:0C02  EB99            jmp    loc_0B9D                    ; go complete: enable IRQ and wait for interrupt

; ----------------------------------------------------------------------------------------------
; detect_com_ports — COM port detection at end of POST. Called from F000:E442 (call 4C04 via ROM mirror, phys. F4C04),
; i.e. runs with CS=F000, offset 4C04. Entry: DS=0040h, BX=0 — COM address table 0040:0000, DI — segment for field 0011h.
; IN 3FA/2FA are trapped by NMI and handled by the 8250 emulator.
; For 3F8/2F8: if the top 5 IIR bits = 0, the port exists and its address goes into the table; port count → equipment.
; ----------------------------------------------------------------------------------------------
detect_com_ports:
F400:0C04  33DB            xor    bx, bx                      ; BX = 0 — offset in COM port address table
F400:0C06  BAFA03          mov    dx, 3FAh                    ; COM1 IIR
F400:0C09  EC              in     al, dx                      ; IN → NMI → nmi_port_3FA (real 8250, F000:0E14); read 8250 interrupt identification register
F400:0C0A  A8F8            test   al, 0F8h                    ; a genuine 8250 has IIR bits 3–7 = 0
F400:0C0C  7508            jne    loc_0C16                    ; no → COM1 absent
F400:0C0E  C7870000F803    mov    word [bx], 3F8h             ; store base address 3F8h in table
F400:0C14  43              inc    bx                          ; next entry
F400:0C15  43              inc    bx                          ; BX += 2

loc_0C16:    ; xrefs: 0C0C
F400:0C16  BAFA02          mov    dx, 2FAh                    ; COM2 IIR
F400:0C19  EC              in     al, dx                      ; read IIR
F400:0C1A  A8F8            test   al, 0F8h                    ; check bits 3–7
F400:0C1C  7508            jne    loc_0C26                    ; no → COM2 absent
F400:0C1E  C7870000F802    mov    word [bx], 2F8h             ; base address 2F8h to table
F400:0C24  43              inc    bx                          ; next entry
F400:0C25  43              inc    bx                          ; BX = 2*port count

loc_0C26:    ; xrefs: 0C1C
F400:0C26  8EDF            mov    ds, di                      ; DS = DI (data area segment, probably 0040h)
F400:0C28  081E1100        or     byte [11h], bl              ; 0040:0011 — equipment high byte: bits 1–3 = COM port count
F400:0C2C  C3              ret                                ; return to POST (F000:E445 → INT 19h)

; ----------------------------------------------------------------------------------------------
; beep — beep via 8253 timer channel 2 + port 61h (ports emulated via NMI).
; Called via ROM mirror (phys. F4C2D) with CS=F000, offset 4C2D: from F000:F712 (BEL in INT 10h AH=0Eh teletype, BL=2)
; and from F000:F723/F72E (POST beeps, sub_F717).
; Entry: BL — duration (BL*65536 iterations). Frequency 1193180/0533h ≈ 896 Hz.
; ----------------------------------------------------------------------------------------------
beep:
F400:0C2D  B0B6            mov    al, 0B6h                    ; 8253 control word: channel 2, LSB+MSB, mode 3 (square wave)
F400:0C2F  E643            out    43h, al                     ; to timer control register
F400:0C31  B83305          mov    ax, 533h                    ; divisor 0533h ≈ 896 Hz
F400:0C34  E642            out    42h, al                     ; divisor low byte to channel 2
F400:0C36  8AC4            mov    al, ah                      ; high byte
F400:0C38  E642            out    42h, al                     ; to channel 2
F400:0C3A  E461            in     al, 61h                     ; read 8255 port B (61h)
F400:0C3C  8AE0            mov    ah, al                      ; save original value
F400:0C3E  0C03            or     al, 3                       ; bit 0 — timer GATE2, bit 1 — speaker data
F400:0C40  E661            out    61h, al                     ; speaker on
F400:0C42  2BC9            sub    cx, cx                      ; CX = 0 → 65536 iterations

loc_0C44:    ; xrefs: 0C44 0C48
F400:0C44  E2FE            loop   loc_0C44                    ; delay
F400:0C46  FECB            dec    bl                          ; outer duration counter
F400:0C48  75FA            jne    loc_0C44                    ; repeat
F400:0C4A  8AC4            mov    al, ah                      ; original port 61h value
F400:0C4C  E661            out    61h, al                     ; speaker off
F400:0C4E  C3              ret                                ; return (near, into segment F000)

; ----------------------------------------------------------------------------------------------
; Unused ROM area F400:0C4F–1BFF, filled with FFh (erased ROM)
; ----------------------------------------------------------------------------------------------
F400:0C4F  FF              db     4017 dup (FFh)              ; FFh filler (4017 bytes) — free space

; ----------------------------------------------------------------------------------------------
; font_hi — 8x8 font for characters 80h–FFh (alternative encoding, CP866), 8 bytes per character,
; rows top to bottom, bit 7 — leftmost pixel. Used for software text rendering in graphics modes and as the
; INT 1Fh table (probably). Characters F2h–FBh differ from standard CP866.
; ----------------------------------------------------------------------------------------------
font_hi:
F400:1C00  070F1B337F63…   db     07h,0Fh,1Bh,33h,7Fh,63h,63h,00h ; glyph 80h: uppercase «А»
F400:1C08  7E60607E6363…   db     7Eh,60h,60h,7Eh,63h,63h,7Eh,00h ; glyph 81h: uppercase «Б»
F400:1C10  7C66667E6363…   db     7Ch,66h,66h,7Eh,63h,63h,7Eh,00h ; glyph 82h: uppercase «В»
F400:1C18  7E6060606060…   db     7Eh,60h,60h,60h,60h,60h,60h,00h ; glyph 83h: uppercase «Г»
F400:1C20  3E3636363636…   db     3Eh,36h,36h,36h,36h,36h,7Fh,63h ; glyph 84h: uppercase «Д» (with descenders)
F400:1C28  7E60607C6060…   db     7Eh,60h,60h,7Ch,60h,60h,7Fh,00h ; glyph 85h: uppercase «Е»
F400:1C30  6B6B3E083E6B…   db     6Bh,6Bh,3Eh,08h,3Eh,6Bh,6Bh,00h ; glyph 86h: uppercase «Ж»
F400:1C38  1E33031E0363…   db     1Eh,33h,03h,1Eh,03h,63h,3Eh,00h ; glyph 87h: uppercase «З»
F400:1C40  6363676F7B73…   db     63h,63h,67h,6Fh,7Bh,73h,63h,00h ; glyph 88h: uppercase «И»
F400:1C48  6B63676F7B73…   db     6Bh,63h,67h,6Fh,7Bh,73h,63h,00h ; glyph 89h: uppercase «Й»
F400:1C50  63666C7C6663…   db     63h,66h,6Ch,7Ch,66h,63h,63h,00h ; glyph 8Ah: uppercase «К»
F400:1C58  03070F1B3363…   db     03h,07h,0Fh,1Bh,33h,63h,63h,00h ; glyph 8Bh: uppercase «Л»
F400:1C60  63777F6B6363…   db     63h,77h,7Fh,6Bh,63h,63h,63h,00h ; glyph 8Ch: uppercase «М»
F400:1C68  6363637F6363…   db     63h,63h,63h,7Fh,63h,63h,63h,00h ; glyph 8Dh: uppercase «Н»
F400:1C70  3E6363636363…   db     3Eh,63h,63h,63h,63h,63h,3Eh,00h ; glyph 8Eh: uppercase «О»
F400:1C78  7F6363636363…   db     7Fh,63h,63h,63h,63h,63h,63h,00h ; glyph 8Fh: uppercase «П»
F400:1C80  7E63637E6060…   db     7Eh,63h,63h,7Eh,60h,60h,60h,00h ; glyph 90h: uppercase «Р»
F400:1C88  3E6360606063…   db     3Eh,63h,60h,60h,60h,63h,3Eh,00h ; glyph 91h: uppercase «С»
F400:1C90  7E1818181818…   db     7Eh,18h,18h,18h,18h,18h,18h,00h ; glyph 92h: uppercase «Т»
F400:1C98  6363633F0363…   db     63h,63h,63h,3Fh,03h,63h,3Eh,00h ; glyph 93h: uppercase «У»
F400:1CA0  083E6B6B6B3E…   db     08h,3Eh,6Bh,6Bh,6Bh,3Eh,08h,00h ; glyph 94h: uppercase «Ф»
F400:1CA8  63361C081C36…   db     63h,36h,1Ch,08h,1Ch,36h,63h,00h ; glyph 95h: uppercase «Х»
F400:1CB0  666666666666…   db     66h,66h,66h,66h,66h,66h,7Fh,03h ; glyph 96h: uppercase «Ц» (tail in last row)
F400:1CB8  6363633F0303…   db     63h,63h,63h,3Fh,03h,03h,03h,00h ; glyph 97h: uppercase «Ч»
F400:1CC0  6B6B6B6B6B6B…   db     6Bh,6Bh,6Bh,6Bh,6Bh,6Bh,7Fh,00h ; glyph 98h: uppercase «Ш»
F400:1CC8  6B6B6B6B6B6B…   db     6Bh,6Bh,6Bh,6Bh,6Bh,6Bh,7Fh,01h ; glyph 99h: uppercase «Щ» (tail in last row)
F400:1CD0  7818181E1B1B…   db     78h,18h,18h,1Eh,1Bh,1Bh,1Eh,00h ; glyph 9Ah: uppercase «Ъ»
F400:1CD8  616161796D6D…   db     61h,61h,61h,79h,6Dh,6Dh,79h,00h ; glyph 9Bh: uppercase «Ы»
F400:1CE0  6060607E6363…   db     60h,60h,60h,7Eh,63h,63h,7Eh,00h ; glyph 9Ch: uppercase «Ь»
F400:1CE8  3E63030F0363…   db     3Eh,63h,03h,0Fh,03h,63h,3Eh,00h ; glyph 9Dh: uppercase «Э»
F400:1CF0  4E5B5B7B5B5B…   db     4Eh,5Bh,5Bh,7Bh,5Bh,5Bh,4Eh,00h ; glyph 9Eh: uppercase «Ю»
F400:1CF8  3F63633F1B33…   db     3Fh,63h,63h,3Fh,1Bh,33h,63h,00h ; glyph 9Fh: uppercase «Я»
F400:1D00  00003C063E66…   db     00h,00h,3Ch,06h,3Eh,66h,3Fh,00h ; glyph A0h: lowercase «а»
F400:1D08  023C607C6666…   db     02h,3Ch,60h,7Ch,66h,66h,3Ch,00h ; glyph A1h: lowercase «б»
F400:1D10  00007C667C63…   db     00h,00h,7Ch,66h,7Ch,63h,7Eh,00h ; glyph A2h: lowercase «в»
F400:1D18  00007E606060…   db     00h,00h,7Eh,60h,60h,60h,60h,00h ; glyph A3h: lowercase «г»
F400:1D20  00003E363636…   db     00h,00h,3Eh,36h,36h,36h,7Fh,63h ; glyph A4h: lowercase «д»
F400:1D28  00003C667E60…   db     00h,00h,3Ch,66h,7Eh,60h,3Eh,00h ; glyph A5h: lowercase «е»
F400:1D30  00006B3E083E…   db     00h,00h,6Bh,3Eh,08h,3Eh,6Bh,00h ; glyph A6h: lowercase «ж»
F400:1D38  00003C660C66…   db     00h,00h,3Ch,66h,0Ch,66h,3Ch,00h ; glyph A7h: lowercase «з»
F400:1D40  000066666E76…   db     00h,00h,66h,66h,6Eh,76h,66h,00h ; glyph A8h: lowercase «и»
F400:1D48  180066666E76…   db     18h,00h,66h,66h,6Eh,76h,66h,00h ; glyph A9h: lowercase «й»
F400:1D50  0000666C7866…   db     00h,00h,66h,6Ch,78h,66h,66h,00h ; glyph AAh: lowercase «к»
F400:1D58  0000070F1B33…   db     00h,00h,07h,0Fh,1Bh,33h,63h,00h ; glyph ABh: lowercase «л»
F400:1D60  000063776B63…   db     00h,00h,63h,77h,6Bh,63h,63h,00h ; glyph ACh: lowercase «м»
F400:1D68  000066667E66…   db     00h,00h,66h,66h,7Eh,66h,66h,00h ; glyph ADh: lowercase «н»
F400:1D70  00003C666666…   db     00h,00h,3Ch,66h,66h,66h,3Ch,00h ; glyph AEh: lowercase «о»
F400:1D78  00007E666666…   db     00h,00h,7Eh,66h,66h,66h,66h,00h ; glyph AFh: lowercase «п»
F400:1D80  228822882288…   db     22h,88h,22h,88h,22h,88h,22h,88h ; glyph B0h: box drawing ░ light shade (25%)
F400:1D88  55AA55AA55AA…   db     55h,0AAh,55h,0AAh,55h,0AAh,55h,0AAh ; glyph B1h: box drawing ▒ medium shade (50%)
F400:1D90  DB77DBEEDB77…   db     0DBh,77h,0DBh,0EEh,0DBh,77h,0DBh,0EEh ; glyph B2h: box drawing ▓ dark shade (75%)
F400:1D98  181818181818…   db     18h,18h,18h,18h,18h,18h,18h,18h ; glyph B3h: box drawing │
F400:1DA0  10101010F010…   db     10h,10h,10h,10h,0F0h,10h,10h,10h ; glyph B4h: box drawing ┤
F400:1DA8  1010F010F010…   db     10h,10h,0F0h,10h,0F0h,10h,10h,10h ; glyph B5h: box drawing ╡
F400:1DB0  14141414F414…   db     14h,14h,14h,14h,0F4h,14h,14h,14h ; glyph B6h: box drawing ╢
F400:1DB8  00000000FC14…   db     00h,00h,00h,00h,0FCh,14h,14h,14h ; glyph B7h: box drawing ╖
F400:1DC0  0000F010F010…   db     00h,00h,0F0h,10h,0F0h,10h,10h,10h ; glyph B8h: box drawing ╕
F400:1DC8  1414F404F414…   db     14h,14h,0F4h,04h,0F4h,14h,14h,14h ; glyph B9h: box drawing ╣
F400:1DD0  363636363636…   db     36h,36h,36h,36h,36h,36h,36h,36h ; glyph BAh: box drawing ║
F400:1DD8  0000FE06F636…   db     00h,00h,0FEh,06h,0F6h,36h,36h,36h ; glyph BBh: box drawing ╗
F400:1DE0  3636F606FE00…   db     36h,36h,0F6h,06h,0FEh,00h,00h,00h ; glyph BCh: box drawing ╝
F400:1DE8  14141414FC00…   db     14h,14h,14h,14h,0FCh,00h,00h,00h ; glyph BDh: box drawing ╜
F400:1DF0  1010F010F000…   db     10h,10h,0F0h,10h,0F0h,00h,00h,00h ; glyph BEh: box drawing ╛
F400:1DF8  00000000F818…   db     00h,00h,00h,00h,0F8h,18h,18h,18h ; glyph BFh: box drawing ┐
F400:1E00  181818181F00…   db     18h,18h,18h,18h,1Fh,00h,00h,00h ; glyph C0h: box drawing └
F400:1E08  18181818FF00…   db     18h,18h,18h,18h,0FFh,00h,00h,00h ; glyph C1h: box drawing ┴
F400:1E10  00000000FF18…   db     00h,00h,00h,00h,0FFh,18h,18h,18h ; glyph C2h: box drawing ┬
F400:1E18  181818181F18…   db     18h,18h,18h,18h,1Fh,18h,18h,18h ; glyph C3h: box drawing ├
F400:1E20  00000000FF00…   db     00h,00h,00h,00h,0FFh,00h,00h,00h ; glyph C4h: box drawing ─
F400:1E28  18181818FF18…   db     18h,18h,18h,18h,0FFh,18h,18h,18h ; glyph C5h: box drawing ┼
F400:1E30  10101F101F10…   db     10h,10h,1Fh,10h,1Fh,10h,10h,10h ; glyph C6h: box drawing ╞
F400:1E38  141414141714…   db     14h,14h,14h,14h,17h,14h,14h,14h ; glyph C7h: box drawing ╟
F400:1E40  363637303F00…   db     36h,36h,37h,30h,3Fh,00h,00h,00h ; glyph C8h: box drawing ╚
F400:1E48  00003F303736…   db     00h,00h,3Fh,30h,37h,36h,36h,36h ; glyph C9h: box drawing ╔
F400:1E50  3636F700FF00…   db     36h,36h,0F7h,00h,0FFh,00h,00h,00h ; glyph CAh: box drawing ╩
F400:1E58  0000FF00F736…   db     00h,00h,0FFh,00h,0F7h,36h,36h,36h ; glyph CBh: box drawing ╦
F400:1E60  363637303736…   db     36h,36h,37h,30h,37h,36h,36h,36h ; glyph CCh: box drawing ╠
F400:1E68  0000FF00FF00…   db     00h,00h,0FFh,00h,0FFh,00h,00h,00h ; glyph CDh: box drawing ═
F400:1E70  3636F700F736…   db     36h,36h,0F7h,00h,0F7h,36h,36h,36h ; glyph CEh: box drawing ╬
F400:1E78  1010FF00FF00…   db     10h,10h,0FFh,00h,0FFh,00h,00h,00h ; glyph CFh: box drawing ╧
F400:1E80  14141414FF00…   db     14h,14h,14h,14h,0FFh,00h,00h,00h ; glyph D0h: box drawing ╨
F400:1E88  0000FF00FF10…   db     00h,00h,0FFh,00h,0FFh,10h,10h,10h ; glyph D1h: box drawing ╤
F400:1E90  00000000FF14…   db     00h,00h,00h,00h,0FFh,14h,14h,14h ; glyph D2h: box drawing ╥
F400:1E98  141414141F00…   db     14h,14h,14h,14h,1Fh,00h,00h,00h ; glyph D3h: box drawing ╙
F400:1EA0  10101F101F00…   db     10h,10h,1Fh,10h,1Fh,00h,00h,00h ; glyph D4h: box drawing ╘
F400:1EA8  00001F101F10…   db     00h,00h,1Fh,10h,1Fh,10h,10h,10h ; glyph D5h: box drawing ╒
F400:1EB0  000000001F14…   db     00h,00h,00h,00h,1Fh,14h,14h,14h ; glyph D6h: box drawing ╓
F400:1EB8  14141414FF14…   db     14h,14h,14h,14h,0FFh,14h,14h,14h ; glyph D7h: box drawing ╫
F400:1EC0  1010FF10FF10…   db     10h,10h,0FFh,10h,0FFh,10h,10h,10h ; glyph D8h: box drawing ╪
F400:1EC8  18181818F800…   db     18h,18h,18h,18h,0F8h,00h,00h,00h ; glyph D9h: box drawing ┘
F400:1ED0  000000001F18…   db     00h,00h,00h,00h,1Fh,18h,18h,18h ; glyph DAh: box drawing ┌
F400:1ED8  FFFFFFFFFFFF…   db     0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ; glyph DBh: box drawing █ full block
F400:1EE0  00000000FFFF…   db     00h,00h,00h,00h,0FFh,0FFh,0FFh,0FFh ; glyph DCh: box drawing ▄ lower half
F400:1EE8  F0F0F0F0F0F0…   db     0F0h,0F0h,0F0h,0F0h,0F0h,0F0h,0F0h,0F0h ; glyph DDh: box drawing ▌ left half
F400:1EF0  0F0F0F0F0F0F…   db     0Fh,0Fh,0Fh,0Fh,0Fh,0Fh,0Fh,0Fh ; glyph DEh: box drawing ▐ right half
F400:1EF8  FFFFFFFF0000…   db     0FFh,0FFh,0FFh,0FFh,00h,00h,00h,00h ; glyph DFh: box drawing ▀ upper half
F400:1F00  00007C66667C…   db     00h,00h,7Ch,66h,66h,7Ch,60h,60h ; glyph E0h: lowercase «р»
F400:1F08  00003C666066…   db     00h,00h,3Ch,66h,60h,66h,3Ch,00h ; glyph E1h: lowercase «с»
F400:1F10  00007E181818…   db     00h,00h,7Eh,18h,18h,18h,18h,00h ; glyph E2h: lowercase «т»
F400:1F18  000066663E06…   db     00h,00h,66h,66h,3Eh,06h,66h,3Ch ; glyph E3h: lowercase «у»
F400:1F20  00083E6B6B3E…   db     00h,08h,3Eh,6Bh,6Bh,3Eh,08h,08h ; glyph E4h: lowercase «ф»
F400:1F28  000063361C36…   db     00h,00h,63h,36h,1Ch,36h,63h,00h ; glyph E5h: lowercase «х»
F400:1F30  000066666666…   db     00h,00h,66h,66h,66h,66h,7Fh,03h ; glyph E6h: lowercase «ц»
F400:1F38  000066663E06…   db     00h,00h,66h,66h,3Eh,06h,06h,00h ; glyph E7h: lowercase «ч»
F400:1F40  00006B6B6B6B…   db     00h,00h,6Bh,6Bh,6Bh,6Bh,7Fh,00h ; glyph E8h: lowercase «ш»
F400:1F48  00006B6B6B6B…   db     00h,00h,6Bh,6Bh,6Bh,6Bh,7Fh,01h ; glyph E9h: lowercase «щ»
F400:1F50  000078181E1B…   db     00h,00h,78h,18h,1Eh,1Bh,1Eh,00h ; glyph EAh: lowercase «ъ»
F400:1F58  00006161796D…   db     00h,00h,61h,61h,79h,6Dh,79h,00h ; glyph EBh: lowercase «ы»
F400:1F60  000060607C66…   db     00h,00h,60h,60h,7Ch,66h,7Ch,00h ; glyph ECh: lowercase «ь»
F400:1F68  00003E630F63…   db     00h,00h,3Eh,63h,0Fh,63h,3Eh,00h ; glyph EDh: lowercase «э»
F400:1F70  00004E5B7B5B…   db     00h,00h,4Eh,5Bh,7Bh,5Bh,4Eh,00h ; glyph EEh: lowercase «ю»
F400:1F78  00003E663E36…   db     00h,00h,3Eh,66h,3Eh,36h,66h,00h ; glyph EFh: lowercase «я»
F400:1F80  147E607C6060…   db     14h,7Eh,60h,7Ch,60h,60h,7Fh,00h ; glyph F0h: uppercase «Ё»
F400:1F88  14003C667E60…   db     14h,00h,3Ch,66h,7Eh,60h,3Eh,00h ; glyph F1h: lowercase «ё»
F400:1F90  000000000103…   db     00h,00h,00h,00h,01h,03h,06h,0Ch ; glyph F2h: rounded corner ╭ (instead of CP866 «Є»)
F400:1F98  000000006030…   db     00h,00h,00h,00h,60h,30h,18h,0Ch ; glyph F3h: rounded corner ╮ (instead of «є»)
F400:1FA0  0C1830600000…   db     0Ch,18h,30h,60h,00h,00h,00h,00h ; glyph F4h: rounded corner ╯ (instead of «Ї»)
F400:1FA8  0C0603010000…   db     0Ch,06h,03h,01h,00h,00h,00h,00h ; glyph F5h: rounded corner ╰ (instead of «ї»)
F400:1FB0  0006037F0306…   db     00h,06h,03h,7Fh,03h,06h,00h,00h ; glyph F6h: arrow → (instead of «Ў»)
F400:1FB8  0018307F3018…   db     00h,18h,30h,7Fh,30h,18h,00h,00h ; glyph F7h: arrow ← (instead of «ў»)
F400:1FC0  0C0C0C0C3F1E…   db     0Ch,0Ch,0Ch,0Ch,3Fh,1Eh,0Ch,00h ; glyph F8h: arrow ↓ (instead of «°»)
F400:1FC8  000C1E3F0C0C…   db     00h,0Ch,1Eh,3Fh,0Ch,0Ch,0Ch,0Ch ; glyph F9h: arrow ↑ (instead of «∙»)
F400:1FD0  0C0C003F000C…   db     0Ch,0Ch,00h,3Fh,00h,0Ch,0Ch,00h ; glyph FAh: division sign ÷ (instead of «·»)
F400:1FD8  18187E181800…   db     18h,18h,7Eh,18h,18h,00h,7Eh,00h ; glyph FBh: sign ± (instead of «√»)
F400:1FE0  4564544C4444…   db     45h,64h,54h,4Ch,44h,44h,44h,00h ; glyph FCh: sign «№»
F400:1FE8  00611E33331E…   db     00h,61h,1Eh,33h,33h,1Eh,61h,00h ; glyph FDh: currency sign ¤
F400:1FF0  00001E1E1E1E…   db     00h,00h,1Eh,1Eh,1Eh,1Eh,00h,00h ; glyph FEh: small square ■
F400:1FF8  000000000000…   db     00h,00h,00h,00h,00h,00h,00h,00h ; glyph FFh: blank character (non-breaking space)

; ##############################################################################################
; SEGMENT F000, offsets E000-FFFF — main BIOS (phys. FE000-FFFFF)
; ##############################################################################################

; ----------------------------------------------------------------------------------------------
; Start of the main 8 KB BIOS block (F000:E000). Signature, POST message strings (CP866)
; ----------------------------------------------------------------------------------------------
F000:E000  42696F73        db     'Bios'                      ; signature «Bios» at block start (included in the E000–FFFF checksum)

; ----------------------------------------------------------------------------------------------
; dat_E004 — banner shown at startup (F000:E228 via sub_E6AE)
; ----------------------------------------------------------------------------------------------
dat_E004:    ; xrefs: E228
F000:E004  42494F532043…   db     'BIOS Computer & Soft Technol. 1992' ; «BIOS Computer & Soft Technol. 1992» — copyright of the company that modified the BIOS
F000:E026  0A0D            db     0Ah,0Dh                     ; line feed LF, CR
F000:E028  8FAEA4AEA6A4…   db     'Подождите пожалуйста...'   ; «Подождите пожалуйста...» ("Please wait...") — memory test in progress
F000:E03F  0A0D00          db     0Ah,0Dh,00h                 ; LF, CR, end of string (0)

; ----------------------------------------------------------------------------------------------
; dat_E042 — suffix for the tested-memory counter (printed at E34D)
; ----------------------------------------------------------------------------------------------
dat_E042:    ; xrefs: E34D
F000:E042  208AA120AFE0…   db     ' Кб проверено'             ; « Кб проверено» (" KB tested") — after the kilobyte count
F000:E04F  0D00            db     0Dh,00h                     ; CR (cursor to line start to update the counter), end of string

; ----------------------------------------------------------------------------------------------
; dat_E051 — option ROM checksum error message (sub_E46C, E473)
; ----------------------------------------------------------------------------------------------
dat_E051:    ; xrefs: E473
F000:E051  208A91208F8793  db     ' КС ПЗУ'                   ; « КС ПЗУ» (" ROM CS") — "ROM checksum" (bad)
F000:E058  0A0D00          db     0Ah,0Dh,00h                 ; LF, CR, end of string

; ----------------------------------------------------------------------------------------------
; RESET — reset entry point (jump from F000:FFF0, standard IBM address E05B).
; If signature AA55h is present at F600:0000 (probably an external option ROM/alternate
; loader), control is passed to it at F600:0003. Otherwise — CPU test and POST.
; ----------------------------------------------------------------------------------------------
RESET:    ; xrefs: EA2E FFF0
F000:E05B  FA              cli                                ; disable maskable interrupts
F000:E05C  B800F6          mov    ax, 0F600h                  ; segment F600h (phys. F6000)
F000:E05F  8ED8            mov    ds, ax                      ; DS = F600
F000:E061  813E000055AA    cmp    word [0], 0AA55h            ; option ROM signature 55h,AAh present?
F000:E067  7509            jne    loc_E072                    ; no → normal POST
F000:E069  EA030000F6      jmp far 0F600h:3                   ; yes → transfer control to option ROM at F600:0003

; ----------------------------------------------------------------------------------------------
; Return addresses for stackless subroutine calls (mov sp,addr + jmp trick)
; ----------------------------------------------------------------------------------------------
spret_E06E:    ; xrefs: E0DE
F000:E06E  E4E0            dw     loc_E0E4                    ; return address E0E4 after ROM checksum (sp=E06E, jmp E62C)

spret_E070:    ; xrefs: E127
F000:E070  2DE1            dw     loc_E12D                    ; return address E12D after testing the first 16 KB of RAM (sp=E070, jmp E447)

; ----------------------------------------------------------------------------------------------
; 8088/8086 CPU test (as in IBM PC): checks flags SF,ZF,AF,PF,CF,OF and
; conditional jumps. Any error hangs at E0C3.
; ----------------------------------------------------------------------------------------------
loc_E072:    ; xrefs: E067
F000:E072  B4D5            mov    ah, 0D5h                    ; AH = D5h: SF, ZF, AF, PF, CF = 1
F000:E074  9E              sahf                               ; load into flags
F000:E075  734C            jae    loc_E0C3                    ; CF must be 1
F000:E077  754A            jne    loc_E0C3                    ; ZF must be 1
F000:E079  7B48            jnp    loc_E0C3                    ; PF must be 1
F000:E07B  7946            jns    loc_E0C3                    ; SF must be 1
F000:E07D  9F              lahf                               ; read flags back into AH
F000:E07E  B105            mov    cl, 5                       ; shift by 5
F000:E080  D2EC            shr    ah, cl                      ; bit 4 (AF) → CF
F000:E082  733F            jae    loc_E0C3                    ; AF must be 1
F000:E084  B040            mov    al, 40h                     ; AL = 40h
F000:E086  D0E0            shl    al, 1                       ; 40h<<1 = 80h → overflow, OF=1
F000:E088  7139            jno    loc_E0C3                    ; OF must be 1
F000:E08A  32E4            xor    ah, ah                      ; AH = 0
F000:E08C  9E              sahf                               ; clear all flags
F000:E08D  7634            jbe    loc_E0C3                    ; CF and ZF must be 0
F000:E08F  7832            js     loc_E0C3                    ; SF must be 0
F000:E091  7A30            jp     loc_E0C3                    ; PF must be 0
F000:E093  9F              lahf                               ; flags → AH
F000:E094  B105            mov    cl, 5                       ; shift by 5
F000:E096  D2EC            shr    ah, cl                      ; AF → CF
F000:E098  7229            jb     loc_E0C3                    ; AF must be 0
F000:E09A  D0E4            shl    ah, 1                       ; shifting zero — OF=0
F000:E09C  7025            jo     loc_E0C3                    ; OF must be 0

; ----------------------------------------------------------------------------------------------
; Register test: FFFFh, then 0000h passed through all segment and general registers
; ----------------------------------------------------------------------------------------------
F000:E09E  B8FFFF          mov    ax, 0FFFFh                  ; first pass — pattern FFFFh
F000:E0A1  F9              stc                                ; CF=1 — first pass marker

loc_E0A2:    ; xrefs: E0BD
F000:E0A2  8ED8            mov    ds, ax                      ; AX → DS
F000:E0A4  8CDB            mov    bx, ds                      ; DS → BX
F000:E0A6  8EC3            mov    es, bx                      ; BX → ES
F000:E0A8  8CC1            mov    cx, es                      ; ES → CX
F000:E0AA  8ED1            mov    ss, cx                      ; CX → SS
F000:E0AC  8CD2            mov    dx, ss                      ; SS → DX
F000:E0AE  8BE2            mov    sp, dx                      ; DX → SP
F000:E0B0  8BEC            mov    bp, sp                      ; SP → BP
F000:E0B2  8BF5            mov    si, bp                      ; BP → SI
F000:E0B4  8BFE            mov    di, si                      ; SI → DI
F000:E0B6  7307            jae    loc_E0BF                    ; second pass (CF=0) → check for zero
F000:E0B8  33C7            xor    ax, di                      ; first pass: DI must equal FFFFh (AX becomes 0)
F000:E0BA  7507            jne    loc_E0C3                    ; mismatch → CPU error
F000:E0BC  F8              clc                                ; CF=0 — second pass
F000:E0BD  EBE3            jmp    loc_E0A2                    ; repeat with AX = 0

loc_E0BF:    ; xrefs: E0B6
F000:E0BF  0BC7            or     ax, di                      ; second pass: DI must be 0
F000:E0C1  7402            je     loc_E0C5                    ; all OK → continue POST

; ----------------------------------------------------------------------------------------------
; Halt on fatal CPU/ROM/RAM error (infinite loop)
; ----------------------------------------------------------------------------------------------
loc_E0C3:    ; xrefs: E075 E077 E079 E07B E082 E088 E08D E08F E091 E098 E09C E0BA E0C3 E0E4
F000:E0C3  EBFE            jmp    loc_E0C3                    ; hang: test failed

; ----------------------------------------------------------------------------------------------
; Initial hardware setup (DS=SS=F000 → writes to registers at F000:0xxx):
; video register, floppy controller, real 8255 (F000:0001/3/5/7), then ROM checksum.
; ----------------------------------------------------------------------------------------------
loc_E0C5:    ; xrefs: E0C1
F000:E0C5  8CCB            mov    bx, cs                      ; BX = CS = F000
F000:E0C7  8ED3            mov    ss, bx                      ; SS = F000 ("stack in ROM" for the mov sp+jmp trick)
F000:E0C9  8EDB            mov    ds, bx                      ; DS = F000 — access to hardware registers F000:0000–0FFF
F000:E0CB  A30002          mov    word [200h], ax             ; F000:0200 ← 0: video registers (color/mode) cleared
F000:E0CE  A20106          mov    byte [601h], al             ; F000:0601 ← 0: floppy control register — motors off, 765 held in reset
F000:E0D1  C606070099      mov    byte [7], 99h               ; F000:0007 — real 8255 control word: 99h (PA in, PB out, PC in), as in XT
F000:E0D6  C606030080      mov    byte [3], 80h               ; F000:0003 — 8255 port B: bit 7 = 1 (keyboard reset/disable), speaker off
F000:E0DB  FC              cld                                ; string operations direction — forward
F000:E0DC  B7E0            mov    bh, 0E0h                    ; BX = E000h (BL=0 after register test) — start of block for checksum
F000:E0DE  BC6EE0          mov    sp, 0E06Eh                  ; SP → return address word E0E4 in ROM (no stack yet)
F000:E0E1  E94805          jmp    loc_E62C                    ; checksum of 8 KB F000:E000–FFFF (ZF=1 — byte sum is 0)

; ----------------------------------------------------------------------------------------------
; Return after ROM checksum. Initialize real 6845 (F000:0000/0002) from first table F0A4 (40x25),
; clear video memory B800, then check warm boot flag 0040:0072.
; ----------------------------------------------------------------------------------------------
loc_E0E4:    ; xrefs: E0DE
F000:E0E4  75DD            jne    loc_E0C3                    ; ROM checksum bad → halt
F000:E0E6  B800B8          mov    ax, 0B800h                  ; video memory segment B800h
F000:E0E9  8EC0            mov    es, ax                      ; ES = B800
F000:E0EB  BEA4F0          mov    si, 0F0A4h                  ; SI = 6845 parameter table (F000:F0A4, first one — 40x25)
F000:E0EE  33C0            xor    ax, ax                      ; AX = 0 (AH = 6845 register number)
F000:E0F0  8BD8            mov    bx, ax                      ; BX = 0 → DS:BX = F000:0000 — real 6845 address register
F000:E0F2  B91000          mov    cx, 10h                     ; 16 registers R0–R15

loc_E0F5:    ; xrefs: E0FD
F000:E0F5  8827            mov    byte [bx], ah               ; register number → 6845 address register (F000:0000)
F000:E0F7  FEC4            inc    ah                          ; next register
F000:E0F9  AC              lodsb  al, byte [si]               ; value from table F0A4
F000:E0FA  884702          mov    byte [bx + 2], al           ; to 6845 data register (F000:0002)
F000:E0FD  E2F6            loop   loc_E0F5                    ; loop over 16 registers
F000:E0FF  B82007          mov    ax, 720h                    ; space with attribute 07h (gray on black)
F000:E102  33FF            xor    di, di                      ; DI = 0 — start of video memory
F000:E104  B520            mov    ch, 20h                     ; CX = 2000h (CL=0 after loop) words = 16 KB
F000:E106  F3AB            rep stosw word es:[di], ax         ; clear video memory B800:0000–3FFF
F000:E108  C70600023028    mov    word [200h], 2830h          ; F000:0200/0201: color 30h, mode 28h (40x25 text, video on, blink)
F000:E10E  8ED9            mov    ds, cx                      ; DS = 0 (CX=0 after rep)
F000:E110  8B2E7204        mov    bp, word [472h]             ; BP = 0040:0072 — reset flag (1234h = Ctrl+Alt+Del warm boot)
F000:E114  8BF9            mov    di, cx                      ; DI = 0
F000:E116  8EC1            mov    es, cx                      ; ES = 0 — first 16 KB of RAM
F000:E118  B520            mov    ch, 20h                     ; CX = 2000h words = 16 KB
F000:E11A  81FD3412        cmp    bp, 1234h                   ; warm boot?
F000:E11E  742A            je     loc_E14A                    ; yes → just zero 16 KB without testing
F000:E120  B8FFFF          mov    ax, 0FFFFh                  ; cold start: pattern FFFFh
F000:E123  F3AB            rep stosw word es:[di], ax         ; fill 0000:0000–3FFF with pattern FFFFh
F000:E125  B520            mov    ch, 20h                     ; CX = 2000h — test size (in words)
F000:E127  BC70E0          mov    sp, 0E070h                  ; SP → return address word E12D in ROM
F000:E12A  E91A03          jmp    sub_E447                    ; test first 16 KB of RAM (sub_E447): check FFh→0 forward and 0 backward; ZF=1 — OK

; ----------------------------------------------------------------------------------------------
; POST: continues after testing the first 16 KB of RAM (sub_E447, return via ROM "stack" spret_E070).
; In: ZF=1 — 16 KB OK; ZF=0 — failure, DI = failing byte address, AL = failing bit mask, DS=ES=0.
; On failure — prints «Ошибка базовой памяти» ("Base memory error") directly to video memory and loops forever accessing the failing location.
; ----------------------------------------------------------------------------------------------
loc_E12D:    ; xrefs: E127
F000:E12D  741F            je     loc_E14E                    ; ZF=1 → first 16 KB of RAM OK, proceed (memory size detection)
F000:E12F  BB00B8          mov    bx, 0B800h                  ; RAM failure: stack not usable yet, write message directly to CGA video memory
F000:E132  8EC3            mov    es, bx                      ; ES = B800h — text video buffer segment
F000:E134  8BDF            mov    bx, di                      ; BX = failing byte address (DI after sub_E447) — saved for the loop below
F000:E136  33FF            xor    di, di                      ; DI = 0 — start of screen (top-left corner)
F000:E138  BE0CE2          mov    si, 0E20Ch                  ; SI → string «Ошибка базовой памяти» ("Base memory error") (F000:E20C)
F000:E13B  B91500          mov    cx, 15h                     ; CX = 21 characters in string

loc_E13E:    ; xrefs: E142
F000:E13E  2EAC            lodsb  al, byte cs:[si]            ; Fetch next string character from ROM (CS:SI)
F000:E140  AA              stosb  byte es:[di], al            ; Write character code to video memory
F000:E141  47              inc    di                          ; Skip attribute byte (stays 07h, filled earlier)
F000:E142  E2FA            loop   loc_E13E                    ; Repeat for all 21 characters

loc_E144:    ; xrefs: E148
F000:E144  8827            mov    byte [bx], ah               ; Endless loop: write AH to failing location DS:BX (DS=0)…
F000:E146  8A07            mov    al, byte [bx]               ; …and read it back — probably to locate the faulty chip with an oscilloscope
F000:E148  EBFA            jmp    loc_E144                    ; Loop forever (machine "hangs" on RAM error)

loc_E14A:    ; xrefs: E11E
F000:E14A  33C0            xor    ax, ax                      ; Warm restart (0:0472=1234h): no test needed, just zero the first 16 KB
F000:E14C  F3AB            rep stosw word es:[di], ax         ; Zero-fill 2000h words from 0000:0000 (CX=2000h, ES:DI=0:0)

; ----------------------------------------------------------------------------------------------
; RAM size detection in 16 KB blocks (segments 0400h…9C00h, up to 640 KB).
; Each block found is filled with FFFFh — preparation for the later sub_E447 test (expects FFh).
; Result: 0040:0013 = memory size in KB; then stack 0030:0100 and initial vector setup.
; ----------------------------------------------------------------------------------------------
loc_E14E:    ; xrefs: E12D
F000:E14E  48              dec    ax                          ; AX = 0 → FFFFh: fill pattern for blocks under test (for the sub_E447 test)
F000:E14F  892E7204        mov    word [472h], bp             ; Restore reset flag 0040:0072 (DS=0, address 0:0472) — wiped by clearing
F000:E153  BA0004          mov    dx, 400h                    ; DX = 0400h — segment of the second 16 KB block (first already tested)
F000:E156  BB1000          mov    bx, 10h                     ; BX = 16 — RAM size counter in KB (first 16 KB already present)

loc_E159:    ; xrefs: E17D
F000:E159  8EC2            mov    es, dx                      ; ES = segment of block under test
F000:E15B  33FF            xor    di, di                      ; DI = 0 — start of block
F000:E15D  26C705AA55      mov    word es:[di], 55AAh         ; Write probe word 55AAh at block start
F000:E162  90              nop                                ; Delay for bus settling before read
F000:E163  26803DAA        cmp    byte es:[di], 0AAh          ; Low byte read back as AAh? → memory present
F000:E167  7407            je     loc_E170                    ; Yes — block present
F000:E169  26807D0155      cmp    byte es:[di + 1], 55h       ; Otherwise check high byte 55h
F000:E16E  750F            jne    loc_E17F                    ; Neither byte matched — end of RAM, exit

loc_E170:    ; xrefs: E167
F000:E170  B520            mov    ch, 20h                     ; CX = 2000h words (CL=0 after previous REP) = 16 KB
F000:E172  F3AB            rep stosw word es:[di], ax         ; Fill block with FFFFh (test preparation)
F000:E174  80C604          add    dh, 4                       ; Next block: segment += 0400h (16 KB)
F000:E177  83C310          add    bx, 10h                     ; RAM size += 16 KB
F000:E17A  80FEA0          cmp    dh, 0A0h                    ; Reached segment A000h (640 KB — video memory boundary)?
F000:E17D  75DA            jne    loc_E159                    ; No — check next block

loc_E17F:    ; xrefs: E16E
F000:E17F  891E1304        mov    word [413h], bx             ; 0040:0013 = base memory size in KB (DS=0, address 0:0413)
F000:E183  B83000          mov    ax, 30h                     ; Stack: SS = 0030h…
F000:E186  8ED0            mov    ss, ax                      ; …(standard IBM PC POST stack area, 0030:0100 = phys. 00400h)
F000:E188  BC0001          mov    sp, 100h                    ; SP = 0100h — top of stack
F000:E18B  B92000          mov    cx, 20h                     ; CX = 32 — vectors INT 00h–1Fh
F000:E18E  2BFF            sub    di, di                      ; DI = 0 — start of interrupt vector table
F000:E190  8EC7            mov    es, di                      ; ES = 0000h — vector table segment

loc_E192:    ; xrefs: E199
F000:E192  B8A1FE          mov    ax, 0FEA1h                  ; Offset of temporary handler F000:FEA1 («mov ah,1 / iret»)
F000:E195  AB              stosw  word es:[di], ax            ; Store vector offset
F000:E196  8CC8            mov    ax, cs                      ; Handler segment = CS = F000h
F000:E198  AB              stosw  word es:[di], ax            ; Store vector segment
F000:E199  E2F7            loop   loc_E192                    ; All 32 vectors → temporary stub setting AH=1 (interrupt-occurred flag for tests)
F000:E19B  C70608006C04    mov    word [8], 46Ch              ; NMI vector (INT 02h) offset = 046Ch — port emulator handler…
F000:E1A1  C7060A0000F4    mov    word [0Ah], 0F400h          ; …segment F400h: NMI_HANDLER F400:046C
F000:E1A7  C7063C000004    mov    word [3Ch], 400h            ; INT 0Fh vector offset = 0400h — common hardware interrupt dispatcher…
F000:E1AD  C7063E0000F4    mov    word [3Eh], 0F400h          ; …segment F400h: INT0F_IRQ_DISPATCH F400:0400 (8259 replacement)
F000:E1B3  BF4000          mov    di, 40h                     ; DI = 40h — INT 10h vector
F000:E1B6  8CC8            mov    ax, cs                      ; DS = CS = F000h to read the table from ROM
F000:E1B8  8ED8            mov    ds, ax                      ; DS = F000h
F000:E1BA  BE03FF          mov    si, 0FF03h                  ; SI → table of INT 10h–1Fh handler offsets (F000:FF03)
F000:E1BD  B91000          mov    cx, 10h                     ; CX = 16 vectors (INT 10h–1Fh)

loc_E1C0:    ; xrefs: E1C3
F000:E1C0  A5              movsw  word es:[di], word [si]     ; Copy handler offset into vector
F000:E1C1  47              inc    di                          ; Skip segment word (already F000h)…
F000:E1C2  47              inc    di                          ; …
F000:E1C3  E2FB            loop   loc_E1C0                    ; Repeat for INT 10h–1Fh (INT 18h gets offset 0000h)
F000:E1C5  EB5A            jmp    loc_E221                    ; Skip over message strings — to video init and keyboard test

dat_E1C7:    ; xrefs: E29D
F000:E1C7  91A1AEA920E2…   db     'Сбой таймера'              ; POST message «Сбой таймера» ("Timer failure") (CP866)
F000:E1D3  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E1D6:    ; xrefs: E382
F000:E1D6  2091A1AEA920…   db     ' Сбой памяти'              ; POST message « Сбой памяти» (" Memory failure") (after address and failing bit mask)
F000:E1E2  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E1E5:    ; xrefs: E262
F000:E1E5  8EE8A8A1AAA0…   db     'Ошибка клавиатуры,'        ; POST message «Ошибка клавиатуры,» ("Keyboard error,") (keyboard reset response ≠ AAh)
F000:E1F7  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E1FA:    ; xrefs: E24E
F000:E1FA  8DA5E220AAAB…   db     'Нет клавиатуры!'           ; POST message «Нет клавиатуры!» ("No keyboard!") (no response to reset)
F000:E209  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E20C:    ; xrefs: E138
F000:E20C  8EE8A8A1AAA0…   db     'Ошибка базовой памяти'     ; «Ошибка базовой памяти» ("Base memory error") — 21 characters, no terminator; written directly to video buffer

; ----------------------------------------------------------------------------------------------
; POST: set video mode, show banner, reset and test keyboard.
; Keyboard is attached via a real 8255 (F000:0001 = port A — scan code, F000:0003 = port B).
; Response is awaited on bit 13 of the interrupt status word F000:0200 (keyboard IRQ request).
; ----------------------------------------------------------------------------------------------
loc_E221:    ; xrefs: E1C5
F000:E221  B80300          mov    ax, 3                       ; AX = 0003h: INT 10h function 0 — set text mode 3 (80×25 color)
F000:E224  8AFC            mov    bh, ah                      ; BH = 0 — video page 0
F000:E226  CD10            int    10h                         ; Set video mode (clears screen)
F000:E228  BE04E0          mov    si, 0E004h                  ; SI → banner «BIOS Computer & Soft Technol. 1992 / Подождите пожалуйста...» ("Please wait...")
F000:E22B  E88004          call   sub_E6AE                    ; Print ASCIIZ string from ROM via teletype
F000:E22E  C606030040      mov    byte [3], 40h               ; 8255 port B (F000:0003) = 40h: bit 6 inverted relative to 61h → keyboard clock held low (reset)
F000:E233  B95629          mov    cx, 2956h                   ; ~20 ms delay holding keyboard clock line

loc_E236:    ; xrefs: E237
F000:E236  90              nop                                ; No-op in delay loop
F000:E237  E2FD            loop   loc_E236                    ; Delay loop
F000:E239  C606030080      mov    byte [3], 80h               ; Port B = 80h (≡ 61h=C0h): clock released, bit 7 — clear keyboard shift register
F000:E23E  90              nop                                ; Short pause
F000:E23F  C606030000      mov    byte [3], 0                 ; Port B = 00h (≡ 61h=40h): keyboard enabled — wait for self-test code AAh

loc_E244:    ; xrefs: E24C
F000:E244  F70600020020    test   word [200h], 2000h          ; Bit 13 of F000:0200 = keyboard interrupt request (scan code arrived)?
F000:E24A  750A            jne    loc_E256                    ; Yes — read keyboard response
F000:E24C  E2F6            loop   loc_E244                    ; Wait up to 65536 iterations (CX=0 after delay)
F000:E24E  BEFAE1          mov    si, 0E1FAh                  ; Timeout: SI → «Нет клавиатуры!» ("No keyboard!")
F000:E251  E85A04          call   sub_E6AE                    ; Print error message
F000:E254  EB12            jmp    loc_E268                    ; Continue POST without keyboard

loc_E256:    ; xrefs: E24A
F000:E256  A00100          mov    al, byte [1]                ; Read scan code from 8255 port A (F000:0001, equivalent of port 60h)
F000:E259  C606030080      mov    byte [3], 80h               ; Port B = 80h: reset/acknowledge keyboard register (bit 7, like IBM 61h bit 7)
F000:E25E  3CAA            cmp    al, 0AAh                    ; Response AAh = keyboard passed self-test
F000:E260  7406            je     loc_E268                    ; Yes — all OK
F000:E262  BEE5E1          mov    si, 0E1E5h                  ; Otherwise SI → «Ошибка клавиатуры,» ("Keyboard error,")
F000:E265  E84604          call   sub_E6AE                    ; Print message

; ----------------------------------------------------------------------------------------------
; POST: 8253 timer test (real chip, mapped at F000:0A00–0A06).
; Channel 0 in mode 0; its interrupt arrives via INT 0Fh → INT 08h → temporary stub FEA1, which sets AH=1.
; First a count of 22 must expire within ≤22 iterations (timer works), then a count of 255 must not expire within 12 (not too fast).
; ----------------------------------------------------------------------------------------------
loc_E268:    ; xrefs: E254 E260
F000:E268  E87E1C          call   sub_FEE9                    ; DS = 0040h (BIOS data area)
F000:E26B  FB              sti                                ; Enable interrupts — needed to receive timer IRQ
F000:E26C  2EC606010608    mov    byte cs:[601h], 8           ; F000:0601 = 08h: floppy controller control register; bit 3 probably masks the floppy IRQ
F000:E272  2EC606060A10    mov    byte cs:[0A06h], 10h        ; 8253 control word (F000:0A06) = 10h: channel 0, LSB only, mode 0
F000:E278  B91600          mov    cx, 16h                     ; CX = 22 wait iterations
F000:E27B  8AE1            mov    ah, cl                      ; AH = 16h (≠1); interrupt stub will change AH to 1
F000:E27D  2E880E000A      mov    byte cs:[0A00h], cl         ; Channel 0 counter (F000:0A00) = 22 — start counting directly, bypassing the emulator

loc_E282:    ; xrefs: E287
F000:E282  80FC01          cmp    ah, 1                       ; Timer interrupt occurred (AH=1)?
F000:E285  7404            je     loc_E28B                    ; Yes — timer works, go to second check
F000:E287  E2F9            loop   loc_E282                    ; Wait at most 22 iterations
F000:E289  EB12            jmp    loc_E29D                    ; No interrupt — timer faulty/slow

loc_E28B:    ; xrefs: E285
F000:E28B  B10C            mov    cl, 0Ch                     ; CL = 12 iterations for second check
F000:E28D  B4FF            mov    ah, 0FFh                    ; AH = FFh (≠1)
F000:E28F  2E8826000A      mov    byte cs:[0A00h], ah         ; Channel 0 counter = 255 (restart count in mode 0)

loc_E294:    ; xrefs: E299
F000:E294  80FC01          cmp    ah, 1                       ; Interrupt came too early?
F000:E297  7404            je     loc_E29D                    ; Yes — timer too fast → error
F000:E299  E2F9            loop   loc_E294                    ; Check 12 iterations
F000:E29B  EB09            jmp    loc_E2A6                    ; Timer OK — program operating mode

loc_E29D:    ; xrefs: E289 E297
F000:E29D  BEC7E1          mov    si, 0E1C7h                  ; SI → «Сбой таймера» ("Timer failure")
F000:E2A0  E80B04          call   sub_E6AE                    ; Print message
F000:E2A3  FA              cli                                ; Disable interrupts

loc_E2A4:    ; xrefs: E2A4
F000:E2A4  EBFE            jmp    loc_E2A4                    ; Halt: endless loop (fatal timer error)

; ----------------------------------------------------------------------------------------------
; POST: timer operating setup (18.2 Hz), set vectors INT 08h–0Fh, 05h, 18h,
; initialize BIOS data area: equipment, keyboard buffer; check warm reset flag.
; ----------------------------------------------------------------------------------------------
loc_E2A6:    ; xrefs: E29B
F000:E2A6  2EC606060A36    mov    byte cs:[0A06h], 36h        ; 8253 (F000:0A06) = 36h: channel 0, LSB+MSB, mode 3 (square wave), binary count
F000:E2AC  2BC0            sub    ax, ax                      ; AX = 0 — divisor 65536
F000:E2AE  E640            out    40h, al                     ; OUT 40h via emulator (NMI): LSB; emulator rescales the divisor for the real 8253 clock
F000:E2B0  E640            out    40h, al                     ; MSB → resulting IRQ0 rate ≈ 18.2 Hz, as on IBM PC
F000:E2B2  FA              cli                                ; Disable interrupts while changing vectors
F000:E2B3  B90800          mov    cx, 8                       ; CX = 8 vectors (INT 08h–0Fh)
F000:E2B6  0E              push   cs                          ; DS = CS…
F000:E2B7  1F              pop    ds                          ; …= F000h
F000:E2B8  BEF3FE          mov    si, 0FEF3h                  ; SI → vector_table (F000:FEF3) — INT 08h–0Fh handler offsets
F000:E2BB  BF2000          mov    di, 20h                     ; DI = 20h — INT 08h vector (ES = 0)

loc_E2BE:    ; xrefs: E2C1
F000:E2BE  A5              movsw  word es:[di], word [si]     ; Copy handler offset
F000:E2BF  47              inc    di                          ; Skip segment (F000h for 08–0Eh; INT 0Fh keeps F400h)…
F000:E2C0  47              inc    di                          ; …
F000:E2C1  E2FB            loop   loc_E2BE                    ; Repeat for INT 08h–0Fh
F000:E2C3  26C706140054FF  mov    word es:[14h], 0FF54h       ; INT 05h vector (print screen) → F000:FF54
F000:E2CA  26C706620000F6  mov    word es:[62h], 0F600h       ; INT 18h vector segment = F600h (offset 0000h) — ROM BASIC at the IBM address
F000:E2D1  FB              sti                                ; Enable interrupts
F000:E2D2  2EC606030000    mov    byte cs:[3], 0              ; 8255 port B = 00h (≡ 61h=40h): keyboard enabled, speaker off
F000:E2D8  E80E1C          call   sub_FEE9                    ; DS = 0040h — BIOS data area
F000:E2DB  1E              push   ds                          ; Save DS=0040h (restored at E3CC)
F000:E2DC  C70610002050    mov    word [10h], 5020h           ; 0040:0010 = 5020h: 1 LPT, game adapter, CGA 80×25; no floppy found yet (bit 0=0)
F000:E2E2  BE1E00          mov    si, 1Eh                     ; SI = 001Eh — start of keyboard ring buffer 0040:001E
F000:E2E5  89361A00        mov    word [1Ah], si              ; 0040:001A — keyboard buffer head pointer
F000:E2E9  89361C00        mov    word [1Ch], si              ; 0040:001C — tail pointer (buffer empty)
F000:E2ED  89368000        mov    word [80h], si              ; 0040:0080 — keyboard buffer start
F000:E2F1  83C620          add    si, 20h                     ; +32 bytes (16 words)
F000:E2F4  89368200        mov    word [82h], si              ; 0040:0082 — keyboard buffer end (003Eh)
F000:E2F8  813E72003412    cmp    word [72h], 1234h           ; 0040:0072 = 1234h — warm restart (Ctrl+Alt+Del)?
F000:E2FE  B81000          mov    ax, 10h                     ; AX = 16 — KB already tested (flags unchanged)
F000:E301  7530            jne    loc_E333                    ; Cold start — full RAM test with counter display
F000:E303  C70672000000    mov    word [72h], 0               ; Warm: clear flag 0040:0072…
F000:E309  E98000          jmp    loc_E38C                    ; …and skip memory test

; ----------------------------------------------------------------------------------------------
; POST: test RAM above 16 KB in 16 KB blocks (blocks pre-filled with FFFFh at E170).
; Screen shows «NNN Кб проверено» ("NNN KB tested") (carriage return without line feed).
; On failure: prints «сегмент:смещение маска Сбой памяти» ("segment:offset mask Memory failure"), 0040:0013 is truncated to the tested size, waits for a key.
; ----------------------------------------------------------------------------------------------
loc_E30C:    ; xrefs: E357
F000:E30C  8B1E1300        mov    bx, word [13h]              ; BX = RAM size in KB (0040:0013)
F000:E310  2BD8            sub    bx, ax                      ; Minus 16 KB already tested
F000:E312  B104            mov    cl, 4                       ; Divide by 16…
F000:E314  D3EB            shr    bx, cl                      ; …= number of remaining 16 KB blocks
F000:E316  8BCB            mov    cx, bx                      ; CX = block counter
F000:E318  BB0004          mov    bx, 400h                    ; BX = 0400h — segment of first block to test

loc_E31B:    ; xrefs: E35C
F000:E31B  8EDB            mov    ds, bx                      ; DS = block segment (read source in sub_E447)
F000:E31D  8EC3            mov    es, bx                      ; ES = block segment (write destination)
F000:E31F  81C30004        add    bx, 400h                    ; BX → next block segment
F000:E323  52              push   dx                          ; Save DX
F000:E324  51              push   cx                          ; Save block counter
F000:E325  53              push   bx                          ; Save next block segment
F000:E326  50              push   ax                          ; Save tested-KB counter
F000:E327  B90020          mov    cx, 2000h                   ; CX = 2000h words = 16 KB
F000:E32A  E81A01          call   sub_E447                    ; Block test: check FFh→write 00h forward, check 00h backward
F000:E32D  7536            jne    loc_E365                    ; ZF=0 → memory failure detected
F000:E32F  58              pop    ax                          ; AX = KB tested
F000:E330  051000          add    ax, 10h                     ; +16 KB

loc_E333:    ; xrefs: E301
F000:E333  50              push   ax                          ; Save number of KB tested
F000:E334  BB0A00          mov    bx, 0Ah                     ; Divisor 10 — convert to decimal
F000:E337  B90300          mov    cx, 3                       ; 3 digits

loc_E33A:    ; xrefs: E342
F000:E33A  33D2            xor    dx, dx                      ; High part of dividend = 0
F000:E33C  F7F3            div    bx                          ; AX = AX/10, DX = remainder (next digit)
F000:E33E  80CA30          or     dl, 30h                     ; Digit → ASCII
F000:E341  52              push   dx                          ; Push digits (least to most significant)
F000:E342  E2F6            loop   loc_E33A                    ; All 3 digits
F000:E344  B90300          mov    cx, 3                       ; CX = 3 — print digits

loc_E347:    ; xrefs: E34B
F000:E347  58              pop    ax                          ; Pop digit (most to least significant)
F000:E348  E84A03          call   sub_E695                    ; Print character via teletype (INT 10h, AH=0Eh)
F000:E34B  E2FA            loop   loc_E347                    ; All 3 digits
F000:E34D  BE42E0          mov    si, 0E042h                  ; SI → « Кб проверено» (" KB tested") + CR (cursor to line start)
F000:E350  E85B03          call   sub_E6AE                    ; Print string
F000:E353  58              pop    ax                          ; AX = KB tested
F000:E354  3D1000          cmp    ax, 10h                     ; First call (16 KB only, entered from E301)?
F000:E357  74B3            je     loc_E30C                    ; Yes — go to block loop
F000:E359  5B              pop    bx                          ; Restore next block segment
F000:E35A  59              pop    cx                          ; Restore block counter
F000:E35B  5A              pop    dx                          ; Restore DX
F000:E35C  E2BD            loop   loc_E31B                    ; Next block
F000:E35E  B00A            mov    al, 0Ah                     ; Test complete: line feed
F000:E360  E83203          call   sub_E695                    ; Print LF
F000:E363  EB27            jmp    loc_E38C                    ; On to option ROM scan

loc_E365:    ; xrefs: E32D
F000:E365  8AE8            mov    ch, al                      ; Failure: CH = failing bit mask (AL from sub_E447)
F000:E367  B00A            mov    al, 0Ah                     ; Line feed
F000:E369  E82903          call   sub_E695                    ; Print LF
F000:E36C  E80203          call   sub_E671                    ; Print failure address «DS:DI» in hex
F000:E36F  B020            mov    al, 20h                     ; Space
F000:E371  E82103          call   sub_E695                    ; Print space
F000:E374  58              pop    ax                          ; AX = size tested before the failing block, KB
F000:E375  83C406          add    sp, 6                       ; Pop saved BX, CX, DX from stack
F000:E378  1F              pop    ds                          ; DS = 0040h (saved at E2DB)
F000:E379  1E              push   ds                          ; Save again for E3CC
F000:E37A  A31300          mov    word [13h], ax              ; 0040:0013 = size of good memory in KB (memory above the failure is not used)
F000:E37D  8AC5            mov    al, ch                      ; AL = failing bit mask
F000:E37F  E80203          call   sub_E684                    ; Print mask as two hex digits
F000:E382  BED6E1          mov    si, 0E1D6h                  ; SI → « Сбой памяти» (" Memory failure")
F000:E385  E82603          call   sub_E6AE                    ; Print message
F000:E388  33C0            xor    ax, ax                      ; AH = 0: INT 16h — wait for keypress
F000:E38A  CD16            int    16h                         ; Wait for a key so the user sees the error

; ----------------------------------------------------------------------------------------------
; Option ROM scan (C800:0000…EFFF:0000 in 2 KB steps, signature AA55h) and init (sub_E639).
; Then check for ROM BASIC at F600:0000 (signature E9h 8Fh + 32 KB checksum); if absent, INT 18h → tape loader F000:E47C.
; ----------------------------------------------------------------------------------------------
loc_E38C:    ; xrefs: E309 E363
F000:E38C  BA00C8          mov    dx, 0C800h                  ; DX = C800h — option ROM scan start segment

loc_E38F:    ; xrefs: E3A7
F000:E38F  8EDA            mov    ds, dx                      ; DS = segment under test
F000:E391  2BDB            sub    bx, bx                      ; BX = 0
F000:E393  8B07            mov    ax, word [bx]               ; Read first 2 bytes
F000:E395  3D55AA          cmp    ax, 0AA55h                  ; Option ROM signature 55h,AAh?
F000:E398  7505            jne    loc_E39F                    ; No — next 2 KB
F000:E39A  E89C02          call   sub_E639                    ; Found: verify checksum and call init; DX += ROM size in paragraphs
F000:E39D  EB04            jmp    loc_E3A3                    ; On to end-of-range check

loc_E39F:    ; xrefs: E398
F000:E39F  81C28000        add    dx, 80h                     ; Scan step 80h paragraphs = 2 KB

loc_E3A3:    ; xrefs: E39D
F000:E3A3  81FA00F0        cmp    dx, 0F000h                  ; Reached F000h?
F000:E3A7  72E6            jb     loc_E38F                    ; No — continue scan
F000:E3A9  2BDB            sub    bx, bx                      ; BX = 0
F000:E3AB  BA00F6          mov    dx, 0F600h                  ; DX = F600h — ROM BASIC segment on IBM PC
F000:E3AE  8EDA            mov    ds, dx                      ; DS = F600h (on "Praktik" probably a mirror of its own ROM)
F000:E3B0  B90080          mov    cx, 8000h                   ; CX = 32 KB for checksum
F000:E3B3  813FE98F        cmp    word [bx], 8FE9h            ; First word = E9h 8Fh (JMP near — BASIC entry point)?
F000:E3B7  7505            jne    loc_E3BE                    ; No — BASIC absent
F000:E3B9  E87302          call   sub_E62F                    ; Checksum of 32 KB F600:0000…7FFF
F000:E3BC  740E            je     loc_E3CC                    ; Sum = 0 → BASIC present, INT 18h vector stays F600:0000

loc_E3BE:    ; xrefs: E3B7
F000:E3BE  33C0            xor    ax, ax                      ; No BASIC:
F000:E3C0  8ED8            mov    ds, ax                      ; DS = 0 — vector table
F000:E3C2  C70660007CE4    mov    word [60h], 0E47Ch          ; INT 18h vector offset = E47Ch — cassette tape boot monitor…
F000:E3C8  8C0E6200        mov    word [62h], cs              ; …segment = F000h

; ----------------------------------------------------------------------------------------------
; Floppy drive detection: reset FDC (INT 13h AH=0), motor on, seek to tracks 1 and 34.
; Drives found are flagged in 0040:0010 (bit 0 — floppy present, bits 6–7 — number of drives − 1).
; Then: LPT/COM timeouts, LPT1 address, beep, jump to INT 18h or INT 19h.
; ----------------------------------------------------------------------------------------------
loc_E3CC:    ; xrefs: E3BC
F000:E3CC  1F              pop    ds                          ; DS = 0040h
F000:E3CD  32E4            xor    ah, ah                      ; AH = 0 — "reset disk system" function
F000:E3CF  8AD4            mov    dl, ah                      ; DL = 0 — drive A:
F000:E3D1  CD13            int    13h                         ; Reset floppy controller (INT 13h)
F000:E3D3  F6C4FF          test   ah, 0FFh                    ; Reset error (AH≠0)?
F000:E3D6  7522            jne    loc_E3FA                    ; Yes — controller not responding, no floppy drives
F000:E3D8  B01C            mov    al, 1Ch                     ; AL = 1Ch — DOR 3F2h: motor A, DMA/IRQ enabled, reset released, drive 0 selected
F000:E3DA  33D2            xor    dx, dx                      ; DX = 0 (DL = drive number)
F000:E3DC  88163E00        mov    byte [3Eh], dl              ; 0040:003E = 0: all drives need recalibration

loc_E3E0:    ; xrefs: E40C
F000:E3E0  52              push   dx                          ; Save drive number
F000:E3E1  BAF203          mov    dx, 3F2h                    ; DX = 3F2h — digital output register (DOR)
F000:E3E4  EE              out    dx, al                      ; OUT 3F2h (emulated via NMI): motor on and drive select
F000:E3E5  5A              pop    dx                          ; Restore DL = drive
F000:E3E6  2BC9            sub    cx, cx                      ; CX = 0 (65536 iterations)

loc_E3E8:    ; xrefs: E3E8
F000:E3E8  E2FE            loop   loc_E3E8                    ; Motor spin-up delay, part 1

loc_E3EA:    ; xrefs: E3EA
F000:E3EA  E2FE            loop   loc_E3EA                    ; Motor spin-up delay, part 2
F000:E3EC  B501            mov    ch, 1                       ; CH = 1 — track 1
F000:E3EE  E8B90A          call   sub_EEAA                    ; Recalibrate (if needed) and seek drive DL to track CH
F000:E3F1  7207            jb     loc_E3FA                    ; CF=1 — drive not responding
F000:E3F3  B522            mov    ch, 22h                     ; CH = 34 — track 34 (head positioner check, as in IBM XT)
F000:E3F5  E8B20A          call   sub_EEAA                    ; Seek to track 34
F000:E3F8  7302            jae    loc_E3FC                    ; Success → flag the drive

loc_E3FA:    ; xrefs: E3D6 E3F1
F000:E3FA  EB17            jmp    loc_E413                    ; Error — stop probing drives

loc_E3FC:    ; xrefs: E3F8
F000:E3FC  0AD2            or     dl, dl                      ; Was it drive 0?
F000:E3FE  750E            jne    loc_E40E                    ; No (drive 1) — flag second floppy drive
F000:E400  FE061000        inc    byte [10h]                  ; 0040:0010 bit 0 = 1: floppy drives installed
F000:E404  FEC2            inc    dl                          ; DL = 1 — check drive B:
F000:E406  32E4            xor    ah, ah                      ; AH = 0 — reset
F000:E408  CD13            int    13h                         ; Reset controller before probing second drive
F000:E40A  B02D            mov    al, 2Dh                     ; AL = 2Dh — DOR: motor B, DMA/IRQ enabled, reset released, drive 1 selected
F000:E40C  EBD2            jmp    loc_E3E0                    ; Repeat check for drive 1

loc_E40E:    ; xrefs: E3FE
F000:E40E  800E100040      or     byte [10h], 40h             ; 0040:0010 bits 6–7 = 01: two floppy drives

loc_E413:    ; xrefs: E3FA
F000:E413  BAF203          mov    dx, 3F2h                    ; DX = 3F2h — DOR
F000:E416  B00C            mov    al, 0Ch                     ; AL = 0Ch — all motors off, controller active, DMA/IRQ enabled
F000:E418  EE              out    dx, al                      ; Turn motors off
F000:E419  BF7800          mov    di, 78h                     ; DI = 78h — 0040:0078, printer timeout table
F000:E41C  1E              push   ds                          ; ES = DS…
F000:E41D  07              pop    es                          ; …= 0040h
F000:E41E  B81414          mov    ax, 1414h                   ; Printer timeout = 20 (14h)
F000:E421  AB              stosw  word es:[di], ax            ; 0040:0078–0079 — LPT1, LPT2
F000:E422  AB              stosw  word es:[di], ax            ; 0040:007A–007B — LPT3, LPT4
F000:E423  B80101          mov    ax, 101h                    ; Serial port timeout = 1
F000:E426  AB              stosw  word es:[di], ax            ; 0040:007C–007D — COM1, COM2
F000:E427  AB              stosw  word es:[di], ax            ; 0040:007E–007F — COM3, COM4
F000:E428  C70608007803    mov    word [8], 378h              ; 0040:0008 = 378h — LPT1 base address (port is emulated)
F000:E42E  BA0100          mov    dx, 1                       ; DH = 0 long, DL = 1 short beep
F000:E431  E8E312          call   sub_F717                    ; "POST complete" beep
F000:E434  F606100001      test   byte [10h], 1               ; Floppy drive found (0040:0010 bit 0)?
F000:E439  7502            jne    loc_E43D                    ; Yes — boot from disk
F000:E43B  CD18            int    18h                         ; No floppy: INT 18h — ROM BASIC or tape loader

loc_E43D:    ; xrefs: E439
F000:E43D  B80300          mov    ax, 3                       ; AX = 0003h — 80×25 color mode
F000:E440  CD10            int    10h                         ; Set video mode (clears screen)
F000:E442  E8BF67          call   detect_com_ports            ; F000:4C04 ≡ F400:0C04 (ROM mirror): detect_com_ports — detect COM1/COM2
F000:E445  CD19            int    19h                         ; INT 19h — boot OS from floppy

; ----------------------------------------------------------------------------------------------
; sub_E447 — RAM block test (DS=ES=segment, CX = length in words). Expects the block filled with FFh.
; Pass 1 (forward): each byte must be FFh, 00h is written; pass 2 (backward): each byte 00h.
; Out: ZF=1 — OK; ZF=0 — failure, AL = XOR (failing bit mask), DI = failing byte offset.
; Also called before the stack is set up (via mov sp,E070h / jmp) — then RET takes the address from ROM.
; ----------------------------------------------------------------------------------------------
sub_E447:    ; xrefs: E12A E32A
F000:E447  FC              cld                                ; Direction — forward
F000:E448  2BFF            sub    di, di                      ; DI = 0 — start of block
F000:E44A  8BF7            mov    si, di                      ; SI = 0
F000:E44C  8BD9            mov    bx, cx                      ; BX = length in words…
F000:E44E  D1E3            shl    bx, 1                       ; …×2 = length in bytes
F000:E450  B4FF            mov    ah, 0FFh                    ; AH = FFh — expected value in first pass

loc_E452:    ; xrefs: E468
F000:E452  8BF7            mov    si, di                      ; SI = DI — read where we write
F000:E454  8BCB            mov    cx, bx                      ; CX = block length in bytes

loc_E456:    ; xrefs: E45E
F000:E456  AC              lodsb  al, byte [si]               ; Read byte
F000:E457  32C4            xor    al, ah                      ; Compare with expected (XOR yields mask of bad bits)
F000:E459  750F            jne    loc_E46A                    ; Mismatch — exit with ZF=0
F000:E45B  32C0            xor    al, al                      ; AL = 0 — new value
F000:E45D  AA              stosb  byte es:[di], al            ; Write 00h to the checked byte
F000:E45E  E2F6            loop   loc_E456                    ; Whole block
F000:E460  22E4            and    ah, ah                      ; Was this the first pass (AH=FFh)?
F000:E462  7406            je     loc_E46A                    ; Second pass done (AH=0) — exit with ZF=1
F000:E464  8AE0            mov    ah, al                      ; AH = 0 — expect zeros in second pass
F000:E466  4F              dec    di                          ; DI → last byte of block
F000:E467  FD              std                                ; Direction — backward
F000:E468  EBE8            jmp    loc_E452                    ; Second pass (end to start)

loc_E46A:    ; xrefs: E459 E462
F000:E46A  FC              cld                                ; Restore forward direction (CLD does not affect flags)
F000:E46B  C3              ret                                ; Return; ZF = test result

; ----------------------------------------------------------------------------------------------
; sub_E46C — option ROM checksum error message: «SSSS КС ПЗУ» ("SSSS ROM CS").
; In: DS = ROM segment. Preserves AX, DX.
; ----------------------------------------------------------------------------------------------
sub_E46C:    ; xrefs: E657
F000:E46C  52              push   dx                          ; Save DX (current scan segment)
F000:E46D  50              push   ax                          ; Save AX
F000:E46E  8CD8            mov    ax, ds                      ; AX = segment of bad ROM
F000:E470  E80A02          call   sub_E67D                    ; Print AX as four hex digits
F000:E473  BE51E0          mov    si, 0E051h                  ; SI → « КС ПЗУ» (" ROM CS") (ROM checksum error)
F000:E476  E83502          call   sub_E6AE                    ; Print string
F000:E479  58              pop    ax                          ; Restore AX
F000:E47A  5A              pop    dx                          ; Restore DX
F000:E47B  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; INT18_TAPE_LOADER — cassette tape program loader monitor (INT 18h vector when BASIC is absent).
; 40×25 screen, name input (up to 8 chars) into 0050:0001; reads headers (256 bytes at 0050:0009) via INT 15h AH=2.
; Header: +0 = A5h, +1..8 = name, +0Ah = length, +0Ch = load segment, +0Eh = offset, +10h = entry offset.
; On name match — loads the body and jumps far to load_segment:entry_offset. Does not return.
; ----------------------------------------------------------------------------------------------
INT18_TAPE_LOADER:    ; xrefs: E4A2 E4C9
F000:E47C  B80100          mov    ax, 1                       ; AX = 0001h — text mode 1 (40×25 color)
F000:E47F  CD10            int    10h                         ; Set video mode
F000:E481  8CC8            mov    ax, cs                      ; DS = CS…
F000:E483  8ED8            mov    ds, ax                      ; …= F000h
F000:E485  BE36E5          mov    si, 0E536h                  ; SI → «Загрузка с ленты / Введите имя программы» ("Load from tape / Enter program name") (with cursor position)
F000:E488  E81102          call   sub_E69C                    ; Print strings with positioning
F000:E48B  BE62E5          mov    si, 0E562h                  ; SI → frame for the name input field
F000:E48E  E80B02          call   sub_E69C                    ; Print frame
F000:E491  B90900          mov    cx, 9                       ; CX = 9 — at most 8 name characters (9th → overflow)
F000:E494  BA1006          mov    dx, 610h                    ; DH = 6, DL = 16 — input field position inside the frame
F000:E497  B85000          mov    ax, 50h                     ; ES = 0050h…
F000:E49A  8EC0            mov    es, ax                      ; …name buffer in area 0050:xxxx
F000:E49C  BF0100          mov    di, 1                       ; DI = 1 — name at 0050:0001–0008
F000:E49F  E83C01          call   sub_E5DE                    ; Read name string from keyboard
F000:E4A2  72D8            jb     INT18_TAPE_LOADER           ; CF=1 — name too long, start over

loc_E4A4:    ; xrefs: E4D0 E4F9
F000:E4A4  B520            mov    ch, 20h                     ; CH = 20h — bit 5: cursor invisible
F000:E4A6  B401            mov    ah, 1                       ; INT 10h AH=1 — set cursor shape (hide)
F000:E4A8  CD10            int    10h                         ; Hide cursor
F000:E4AA  8CC0            mov    ax, es                      ; DS = ES…
F000:E4AC  8ED8            mov    ds, ax                      ; …= 0050h
F000:E4AE  BB0900          mov    bx, 9                       ; BX = 9 — header is read into 0050:0009
F000:E4B1  B80002          mov    ax, 200h                    ; AH = 2 — INT 15h "read blocks from cassette"
F000:E4B4  B90001          mov    cx, 100h                    ; CX = 256 bytes — header size
F000:E4B7  CD15            int    15h                         ; Read header from tape
F000:E4B9  7310            jae    loc_E4CB                    ; No errors — parse header
F000:E4BB  8CC8            mov    ax, cs                      ; Error: DS = CS…
F000:E4BD  8ED8            mov    ds, ax                      ; …= F000h
F000:E4BF  BE7BE5          mov    si, 0E57Bh                  ; SI → «Ошибка чтения с ленты» ("Tape read error")
F000:E4C2  E8D701          call   sub_E69C                    ; Print message

loc_E4C5:    ; xrefs: E525
F000:E4C5  32E4            xor    ah, ah                      ; AH = 0 — wait for key
F000:E4C7  CD16            int    16h                         ; Wait for keypress
F000:E4C9  EBB1            jmp    INT18_TAPE_LOADER           ; Start over

loc_E4CB:    ; xrefs: E4B9
F000:E4CB  803E0900A5      cmp    byte [9], 0A5h              ; First header byte (0050:0009) = A5h — header marker?
F000:E4D0  75D2            jne    loc_E4A4                    ; No — read next block
F000:E4D2  BE0100          mov    si, 1                       ; SI → entered name 0050:0001
F000:E4D5  BF0A00          mov    di, 0Ah                     ; DI → name from header 0050:000A
F000:E4D8  B90800          mov    cx, 8                       ; 8 characters
F000:E4DB  F3A6            repe cmpsb byte [si], byte es:[di] ; Compare names
F000:E4DD  741C            je     loc_E4FB                    ; Match — load program
F000:E4DF  8CC8            mov    ax, cs                      ; Wrong program: DS = CS…
F000:E4E1  8ED8            mov    ds, ax                      ; …= F000h
F000:E4E3  BEAFE5          mov    si, 0E5AFh                  ; SI → «Пропущена программа » ("Skipped program ")
F000:E4E6  E8B301          call   sub_E69C                    ; Print message
F000:E4E9  B85000          mov    ax, 50h                     ; DS = 0050h…
F000:E4EC  8ED8            mov    ds, ax                      ; …
F000:E4EE  BE0A00          mov    si, 0Ah                     ; SI → name from header (0050:000A)
F000:E4F1  C606120000      mov    byte [12h], 0               ; Byte 0050:0012 = 0 — terminator after the 8 name characters
F000:E4F6  E8B501          call   sub_E6AE                    ; Print name; probably a bug: sub_E6AE reads CS:[SI], i.e. F000:000A, not 0050:000A
F000:E4F9  EBA9            jmp    loc_E4A4                    ; Look for next header

loc_E4FB:    ; xrefs: E4DD
F000:E4FB  1E              push   ds                          ; Save DS=0050h
F000:E4FC  8CC8            mov    ax, cs                      ; DS = CS…
F000:E4FE  8ED8            mov    ds, ax                      ; …= F000h
F000:E500  BEC6E5          mov    si, 0E5C6h                  ; SI → «Программа загружается» ("Program loading")
F000:E503  E89601          call   sub_E69C                    ; Print message
F000:E506  1F              pop    ds                          ; DS = 0050h
F000:E507  A11500          mov    ax, word [15h]              ; AX = load segment from header (0050:0015)
F000:E50A  8EC0            mov    es, ax                      ; ES = load segment
F000:E50C  8B1E1700        mov    bx, word [17h]              ; BX = load offset (0050:0017)
F000:E510  8B0E1300        mov    cx, word [13h]              ; CX = program length in bytes (0050:0013)
F000:E514  B80002          mov    ax, 200h                    ; AH = 2 — read from cassette
F000:E517  CD15            int    15h                         ; Read program body into ES:BX
F000:E519  730C            jae    loc_E527                    ; Success — run it
F000:E51B  8CC8            mov    ax, cs                      ; Error: DS = CS…
F000:E51D  8ED8            mov    ds, ax                      ; …= F000h
F000:E51F  BE93E5          mov    si, 0E593h                  ; SI → «Ошибка загрузки программы» ("Program load error")
F000:E522  E87701          call   sub_E69C                    ; Print message
F000:E525  EB9E            jmp    loc_E4C5                    ; Wait for key and start over

loc_E527:    ; xrefs: E519
F000:E527  B85000          mov    ax, 50h                     ; DS = 0050h…
F000:E52A  8ED8            mov    ds, ax                      ; …
F000:E52C  A11500          mov    ax, word [15h]              ; AX = load segment
F000:E52F  A31B00          mov    word [1Bh], ax              ; 0050:001B = segment → far entry pointer 0050:0019 = segment:entry_offset
F000:E532  FF2E1900        jmp far [19h]                      ; Run loaded program (JMP FAR [0050:0019])

dat_E536:    ; xrefs: E485
F000:E536  0A02            db     0Ah,02h                     ; Cursor position: DL=0Ah (column 10), DH=02h (row 2)
F000:E538  202087A0A3E0…   db     '  Загрузка с ленты'        ; «  Загрузка с ленты» ("  Load from tape") — tape loader screen title
F000:E54A  0101            db     01h,01h                     ; Two 01h codes — move cursor two rows down (same column)
F000:E54C  82A2A5A4A8E2…   db     'Введите имя программы'     ; «Введите имя программы» ("Enter program name") — prompt
F000:E561  00              db     00h                         ; End of string

dat_E562:    ; xrefs: E48B
F000:E562  0F05DAC4C4C4…   db     0Fh,05h,0DAh,0C4h,0C4h,0C4h,0C4h,0C4h ; Position (col 15, row 5); ┌ and horizontal lines ─ (CP866 DAh, C4h) — top of frame
F000:E56A  C4C4C4BF0101…   db     0C4h,0C4h,0C4h,0BFh,01h,01h,0C0h,0C4h ; ─ ─ ─ ┐ (C4h, BFh); 01h,01h — two rows down; └ (C0h) ─
F000:E572  C4C4C4C4C4C4…   db     0C4h,0C4h,0C4h,0C4h,0C4h,0C4h,0C4h,0D9h ; ─ ×7 and ┘ (D9h) — bottom of name input frame
F000:E57A  00              db     00h                         ; End of string (frame terminator)

dat_E57B:    ; xrefs: E4BF
F000:E57B  0A0A            db     0Ah,0Ah                     ; Cursor position: DL=0Ah, DH=0Ah (row 10, column 10)
F000:E57D  8EE8A8A1AAA0…   db     'Ошибка чтения с ленты'     ; «Ошибка чтения с ленты» ("Tape read error")
F000:E592  00              db     00h                         ; End of string

dat_E593:    ; xrefs: E51F
F000:E593  0A0A            db     0Ah,0Ah                     ; Cursor position: column 10, row 10
F000:E595  8EE8A8A1AAA0…   db     'Ошибка загрузки программы' ; «Ошибка загрузки программы» ("Program load error")
F000:E5AE  00              db     00h                         ; End of string

dat_E5AF:    ; xrefs: E4E3
F000:E5AF  0A0A            db     0Ah,0Ah                     ; Cursor position: column 10, row 10
F000:E5B1  8FE0AEAFE3E9…   db     'Пропущена программа '      ; «Пропущена программа » ("Skipped program ") (followed by the name of the program found on tape)
F000:E5C5  00              db     00h                         ; End of string

dat_E5C6:    ; xrefs: E500
F000:E5C6  0A0A            db     0Ah,0Ah                     ; Cursor position: column 10, row 10
F000:E5C8  8FE0AEA3E0A0…   db     'Программа загружается'     ; «Программа загружается» ("Program loading")
F000:E5DD  00              db     00h                         ; End of string

; ----------------------------------------------------------------------------------------------
; sub_E5DE — keyboard line input with echo (program name for the tape loader).
; In: ES:DI — buffer, CX — max characters + 1, DX — cursor position. Enter ends input, Backspace deletes.
; Out: CF=0 — input done, rest of buffer padded with spaces; CF=1 — overflow.
; ----------------------------------------------------------------------------------------------
sub_E5DE:    ; xrefs: E49F
F000:E5DE  BB0700          mov    bx, 7                       ; BH = 0 (page), BL = 07h (attribute: gray on black)
F000:E5E1  B402            mov    ah, 2                       ; AH = 2 — set cursor position
F000:E5E3  CD10            int    10h                         ; Place cursor at start of input field

loc_E5E5:    ; xrefs: E617 E628
F000:E5E5  51              push   cx                          ; Save remaining character counter

loc_E5E6:    ; xrefs: E600
F000:E5E6  B400            mov    ah, 0                       ; AH = 0 — read key
F000:E5E8  CD16            int    16h                         ; Wait for key (AH = scan code, AL = ASCII)
F000:E5EA  80FC1C          cmp    ah, 1Ch                     ; Scan code 1Ch = Enter?
F000:E5ED  7508            jne    loc_E5F7                    ; No — check other keys
F000:E5EF  B020            mov    al, 20h                     ; AL = space
F000:E5F1  F3AA            rep stosb byte es:[di], al         ; Pad rest of buffer with spaces
F000:E5F3  59              pop    cx                          ; Pop counter from stack
F000:E5F4  F8              clc                                ; CF=0 — input successful
F000:E5F5  EB34            jmp    loc_E62B                    ; To return

loc_E5F7:    ; xrefs: E5ED
F000:E5F7  80FC0E          cmp    ah, 0Eh                     ; Scan code 0Eh = Backspace?
F000:E5FA  751D            jne    loc_E619                    ; No — ordinary character
F000:E5FC  81FF0100        cmp    di, 1                       ; Buffer empty (DI at start)?
F000:E600  74E4            je     loc_E5E6                    ; Yes — ignore backspace, wait for next key
F000:E602  FECA            dec    dl                          ; Cursor column one left
F000:E604  B402            mov    ah, 2                       ; AH = 2 — set cursor
F000:E606  CD10            int    10h                         ; Move cursor
F000:E608  4F              dec    di                          ; Buffer pointer back
F000:E609  B020            mov    al, 20h                     ; AL = space
F000:E60B  268805          mov    byte es:[di], al            ; Erase character in buffer
F000:E60E  B409            mov    ah, 9                       ; AH = 9 — write character with attribute without moving cursor
F000:E610  B90100          mov    cx, 1                       ; One character
F000:E613  CD10            int    10h                         ; Erase character on screen
F000:E615  59              pop    cx                          ; Restore counter
F000:E616  41              inc    cx                          ; One slot freed
F000:E617  EBCC            jmp    loc_E5E5                    ; Next key

loc_E619:    ; xrefs: E5FA
F000:E619  AA              stosb  byte es:[di], al            ; Store character in buffer
F000:E61A  B409            mov    ah, 9                       ; AH = 9 — write character with attribute
F000:E61C  B90100          mov    cx, 1                       ; One character
F000:E61F  CD10            int    10h                         ; Display character
F000:E621  FEC2            inc    dl                          ; Cursor column +1
F000:E623  B402            mov    ah, 2                       ; AH = 2 — set cursor
F000:E625  CD10            int    10h                         ; Move cursor
F000:E627  59              pop    cx                          ; Restore counter
F000:E628  E2BB            loop   loc_E5E5                    ; Still room — next key
F000:E62A  F9              stc                                ; CF=1 — name length exceeded

loc_E62B:    ; xrefs: E5F5
F000:E62B  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; POST entry: checksum of 8 KB main ROM (DS:BX = F000:E000), before stack setup.
; ----------------------------------------------------------------------------------------------
loc_E62C:    ; xrefs: E0E1
F000:E62C  B90020          mov    cx, 2000h                   ; CX = 8 KB — size of ROM area to check

; ----------------------------------------------------------------------------------------------
; sub_E62F — checksum: sum of CX bytes at DS:BX (mod 256).
; Out: ZF=1 — sum is 0 (ROM OK); BX advanced by CX.
; ----------------------------------------------------------------------------------------------
sub_E62F:    ; xrefs: E3B9 E652
F000:E62F  32C0            xor    al, al                      ; AL = 0 — sum accumulator

loc_E631:    ; xrefs: E634
F000:E631  0207            add    al, byte [bx]               ; Add next byte
F000:E633  43              inc    bx                          ; Next byte
F000:E634  E2FB            loop   loc_E631                    ; CX bytes
F000:E636  0AC0            or     al, al                      ; ZF=1 if sum is 0
F000:E638  C3              ret                                ; Return (before stack setup — via address in ROM spret_E06E)

; ----------------------------------------------------------------------------------------------
; sub_E639 — verify and initialize a found option ROM.
; In: DS = ROM segment (signature AA55h), BX = 0, DX = same segment.
; Checksum over [2]×512 bytes; on success — far call DS:0003; on error — «SSSS КС ПЗУ» ("SSSS ROM CS").
; Out: DX += ROM size in paragraphs (scan continues past it).
; ----------------------------------------------------------------------------------------------
sub_E639:    ; xrefs: E39A
F000:E639  B84000          mov    ax, 40h                     ; ES = 0040h…
F000:E63C  8EC0            mov    es, ax                      ; …BIOS data area (temporary pointer at 0040:0084)
F000:E63E  2AE4            sub    ah, ah                      ; AH = 0
F000:E640  8A4702          mov    al, byte [bx + 2]           ; AL = ROM size in 512-byte blocks (header byte 2)
F000:E643  B109            mov    cl, 9                       ; ×512…
F000:E645  D3E0            shl    ax, cl                      ; …= size in bytes
F000:E647  8BC8            mov    cx, ax                      ; CX = length for checksum
F000:E649  51              push   cx                          ; Save length
F000:E64A  B90400          mov    cx, 4                       ; /16…
F000:E64D  D3E8            shr    ax, cl                      ; …= size in paragraphs
F000:E64F  03D0            add    dx, ax                      ; DX = segment right after this ROM
F000:E651  59              pop    cx                          ; Restore length
F000:E652  E8DAFF          call   sub_E62F                    ; ROM checksum
F000:E655  7406            je     loc_E65D                    ; Sum 0 — call ROM init
F000:E657  E812FE          call   sub_E46C                    ; Error: «SSSS КС ПЗУ» ("SSSS ROM CS")
F000:E65A  EB14            jmp    loc_E670                    ; To return
F000:E65C  90              db     90h                         ; Unused NOP byte (filler between instructions)

; ----------------------------------------------------------------------------------------------
; Tail of sub_E639 (option ROM scan): module checksum OK → call its init.
; The far call goes through a temporary pointer at 0040:0084/0086 (ES=0040h) to DS:0003 —
; the standard ROM module entry point (after the 55AA signature and length byte). IBM uses 0040:0067 for this.
; ----------------------------------------------------------------------------------------------
loc_E65D:    ; xrefs: E655
F000:E65D  52              push   dx                          ; save DX — segment where the scan for the next module resumes
F000:E65E  26C70684000300  mov    word es:[84h], 3            ; 0040:0084 ← offset 0003 = option ROM init entry point
F000:E665  268C1E8600      mov    word es:[86h], ds           ; 0040:0086 ← DS = segment of found module (seg:0003 pointer ready)
F000:E66A  26FF1E8400      call far es:[84h]                  ; far call to option ROM init (module returns with RETF)
F000:E66F  5A              pop    dx                          ; restore DX — segment to continue scanning

loc_E670:    ; xrefs: E65A
F000:E670  C3              ret                                ; return to option ROM scan loop (from both branches: OK and checksum error)

; ----------------------------------------------------------------------------------------------
; sub_E671 — print address DS:DI as «SSSS:OOOO» (hex) via INT 10h/0Eh.
; Used in RAM test (E36C) to print the failing location address. Clobbers AX, CL.
; ----------------------------------------------------------------------------------------------
sub_E671:    ; xrefs: E36C
F000:E671  8CD8            mov    ax, ds                      ; AX = DS — segment of failing memory block
F000:E673  E80700          call   sub_E67D                    ; print segment as 4 hex digits
F000:E676  B03A            mov    al, 3Ah                     ; AL = ':' — segment/offset separator
F000:E678  E81A00          call   sub_E695                    ; print ':' via teletype
F000:E67B  8BC7            mov    ax, di                      ; AX = DI — failing byte offset; fall through to word print

; ----------------------------------------------------------------------------------------------
; sub_E67D — print AX as 4 hex digits (high byte first). In: AX. Clobbers CL.
; ----------------------------------------------------------------------------------------------
sub_E67D:    ; xrefs: E470 E673
F000:E67D  50              push   ax                          ; save original word
F000:E67E  86E0            xchg   al, ah                      ; handle high byte first (AH → AL)
F000:E680  E80100          call   sub_E684                    ; print high byte as two digits
F000:E683  58              pop    ax                          ; AX = original word; AL = low byte → fall through to byte print

; ----------------------------------------------------------------------------------------------
; sub_E684 — print AL as two hex digits. In: AL. Clobbers CL, AH.
; ----------------------------------------------------------------------------------------------
sub_E684:    ; xrefs: E37F E680
F000:E684  50              push   ax                          ; save byte
F000:E685  B104            mov    cl, 4                       ; CL = 4 — nibble shift
F000:E687  D2E8            shr    al, cl                      ; AL = high nibble
F000:E689  E80300          call   sub_E68F                    ; print high digit
F000:E68C  58              pop    ax                          ; restore byte
F000:E68D  240F            and    al, 0Fh                     ; AL = low nibble → fall through to digit print

; ----------------------------------------------------------------------------------------------
; sub_E68F — print one hex digit (AL = 0..0Fh) using the classic ADD 90h/DAA/ADC 40h/DAA trick.
; ----------------------------------------------------------------------------------------------
sub_E68F:    ; xrefs: E689
F000:E68F  0490            add    al, 90h                     ; DAA trick: 0..9 → 90..99, A..F → 00..05 with carry
F000:E691  27              daa                                ; decimal adjust (CF=1 for A..F)
F000:E692  1440            adc    al, 40h                     ; +40h+CF: 0..9 → '0'..'9' after DAA, A..F → 'A'..'F'
F000:E694  27              daa                                ; AL = ASCII hex digit → fall through to character output

; ----------------------------------------------------------------------------------------------
; sub_E695 — print character AL via teletype (INT 10h, AH=0Eh, page 0).
; ----------------------------------------------------------------------------------------------
sub_E695:    ; xrefs: E348 E360 E369 E371 E678
F000:E695  B40E            mov    ah, 0Eh                     ; AH = 0Eh — INT 10h "teletype" function
F000:E697  B700            mov    bh, 0                       ; BH = 0 — video page 0
F000:E699  CD10            int    10h                         ; print character AL and advance cursor
F000:E69B  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_E69C — print a ROM message string with positioning.
; Format at CS:SI: word DX (DL = column, DH = row) — cursor position, then CP866 text;
; byte 01h — move to next screen row at the same column, 00h — end of string.
; ----------------------------------------------------------------------------------------------
sub_E69C:    ; xrefs: E488 E48E E4C2 E4E6 E503 E522
F000:E69C  2E8B14          mov    dx, word cs:[si]            ; DX = output start position (DL = column, DH = row) from string header
F000:E69F  46              inc    si                          ; SI → second position byte (another inc below skips it)

loc_E6A0:    ; xrefs: E6B7
F000:E6A0  B402            mov    ah, 2                       ; AH = 2 — INT 10h "set cursor position" function
F000:E6A2  46              inc    si                          ; SI → first text character (or character after code 01h)
F000:E6A3  B700            mov    bh, 0                       ; BH = 0 — video page 0 (BH stays 0 for teletype below too)
F000:E6A5  CD10            int    10h                         ; set cursor to position DX
F000:E6A7  EB05            jmp    sub_E6AE                    ; go to character output loop

loc_E6A9:    ; xrefs: E6BB
F000:E6A9  B40E            mov    ah, 0Eh                     ; AH = 0Eh — INT 10h teletype (BH=0 left by caller/above)
F000:E6AB  CD10            int    10h                         ; print next character
F000:E6AD  46              inc    si                          ; to next string character

; ----------------------------------------------------------------------------------------------
; sub_E6AE — print ASCIIZ string from CS:SI via teletype from current cursor position.
; Code 01h — move to next screen row (DH+1, column DL), 00h — end. Expects BH=0.
; ----------------------------------------------------------------------------------------------
sub_E6AE:    ; xrefs: E22B E251 E265 E2A0 E350 E385 E476 E4F6 E6A7
F000:E6AE  2E8A04          mov    al, byte cs:[si]            ; AL = next string byte from ROM
F000:E6B1  3C01            cmp    al, 1                       ; code 01h — control "new row, same column"?
F000:E6B3  7504            jne    loc_E6B9                    ; no — check for end/ordinary character
F000:E6B5  FEC6            inc    dh                          ; next screen row (column DL kept)
F000:E6B7  EBE7            jmp    loc_E6A0                    ; reposition cursor and continue output

loc_E6B9:    ; xrefs: E6B3
F000:E6B9  0AC0            or     al, al                      ; byte 0 — end of string?
F000:E6BB  75EC            jne    loc_E6A9                    ; not 0 — print character
F000:E6BD  C3              ret                                ; string printed — return
F000:E6BE  00              db     34 dup (00h)                ; filler 00h (padding up to the standard INT 19h entry E6F2)

; ----------------------------------------------------------------------------------------------
; Boot sector read OK: determine diskette type from BPB and transfer control to 0000:7C00.
; ----------------------------------------------------------------------------------------------
loc_E6E0:    ; xrefs: E720
F000:E6E0  813E137CA005    cmp    word [7C13h], 5A0h          ; BPB: total sectors (word 0000:7C13) ≥ 1440 (720 KB) — 80-track diskette?
F000:E6E6  7205            jb     loc_E6ED                    ; less — 40-track (360 KB), leave flags alone
F000:E6E8  800E3E0430      or     byte [43Eh], 30h            ; 0040:003E bits 4,5 = "80 tracks" for drives 0/1 (no double-stepping); one flag shared by both drives

loc_E6ED:    ; xrefs: E6E6
F000:E6ED  EA007C0000      jmp far 0:7C00h                    ; transfer control to boot loader at 0000:7C00

; ----------------------------------------------------------------------------------------------
; INT 19h — bootstrap (standard IBM address F000:E6F2).
; Up to 4 attempts: reset floppy (INT 13h/00) and read sector 0/0/1 of drive A: into 0000:7C00.
; Failure → INT 18h (here — cassette tape loader). Points INT 1Eh vector to parameter table EFC7.
; ----------------------------------------------------------------------------------------------
INT19_BOOT:
F000:E6F2  FB              sti                                ; enable interrupts (needed for INT 13h)
F000:E6F3  2BC0            sub    ax, ax                      ; AX = 0
F000:E6F5  8ED8            mov    ds, ax                      ; DS = 0000 — address vector table and data area as 0000:04xx
F000:E6F7  80263E04CF      and    byte [43Eh], 0CFh           ; 0040:003E: clear bits 4,5 (80-track media flag) before boot
F000:E6FC  C7067800C7EF    mov    word [78h], 0EFC7h          ; INT 1Eh vector (0000:0078) ← offset EFC7 of floppy parameter table
F000:E702  8C0E7A00        mov    word [7Ah], cs              ; INT 1Eh segment ← CS (F000)
F000:E706  B90400          mov    cx, 4                       ; CX = 4 — number of boot attempts

loc_E709:    ; xrefs: E722
F000:E709  51              push   cx                          ; save attempt counter (INT 13h clobbers CX)
F000:E70A  B400            mov    ah, 0                       ; AH = 0 — reset floppy controller
F000:E70C  CD13            int    13h                         ; INT 13h: reset (emulated 765 FDC)
F000:E70E  720F            jb     loc_E71F                    ; reset error — next attempt
F000:E710  B80102          mov    ax, 201h                    ; AH = 2 (read), AL = 1 sector
F000:E713  2BD2            sub    dx, dx                      ; DX = 0: head 0, drive 0 (A:)
F000:E715  8EC2            mov    es, dx                      ; ES = 0000 — buffer in segment zero
F000:E717  BB007C          mov    bx, 7C00h                   ; BX = 7C00h — standard boot sector address
F000:E71A  B90100          mov    cx, 1                       ; CX = 1: track 0, sector 1
F000:E71D  CD13            int    13h                         ; read boot sector

loc_E71F:    ; xrefs: E70E
F000:E71F  59              pop    cx                          ; restore attempt counter
F000:E720  73BE            jae    loc_E6E0                    ; CF=0 — sector read → check BPB and start
F000:E722  E2E5            loop   loc_E709                    ; retry while attempts remain
F000:E724  CD18            int    18h                         ; floppy boot failed → INT 18h (cassette tape boot monitor instead of ROM BASIC)
F000:E726  000000          db     00h,00h,00h                 ; 00h padding up to the fixed IBM address E729 (COM baud rate table)

; ----------------------------------------------------------------------------------------------
; baud_table — 8250 divisors for INT 14h AH=0 (1.8432 MHz / 16 / divisor)
; Index — bits 7–5 of AL at port init; the word is written to DLL/DLM with DLAB=1.
; ----------------------------------------------------------------------------------------------
baud_table:    ; xrefs: E77A
F000:E729  1704            dw     0417h                       ; 110 baud: divisor 0417h (1047)
F000:E72B  0003            dw     0300h                       ; 150 baud: divisor 0300h (768)
F000:E72D  8001            dw     0180h                       ; 300 baud: divisor 0180h (384)
F000:E72F  C000            dw     00C0h                       ; 600 baud: divisor 00C0h (192)
F000:E731  6000            dw     0060h                       ; 1200 baud: divisor 0060h (96)
F000:E733  3000            dw     0030h                       ; 2400 baud: divisor 0030h (48)
F000:E735  1800            dw     0018h                       ; 4800 baud: divisor 0018h (24)
F000:E737  0C00            dw     000Ch                       ; 9600 baud: divisor 000Ch (12)

; ----------------------------------------------------------------------------------------------
; INT 14h — serial port (standard IBM address E739, code identical to IBM XT BIOS).
; In: AH = function (0 init, 1 send, 2 receive, 3 status), AL = parameters/character, DX = port number.
; Base address taken from 0040:0000+2*DX; accesses to 8250 ports (3F8–3FF/2F8–2FF) are trapped by NMI and emulated.
; Out: AH = line status (LSR), AL = MSR / received character; AH bit 7 = timeout.
; ----------------------------------------------------------------------------------------------
INT14_SERIAL:
F000:E739  FB              sti                                ; enable interrupts
F000:E73A  1E              push   ds                          ; save DS
F000:E73B  52              push   dx                          ; save DX (port number)
F000:E73C  56              push   si                          ; save SI
F000:E73D  57              push   di                          ; save DI
F000:E73E  51              push   cx                          ; save CX
F000:E73F  53              push   bx                          ; save BX
F000:E740  8BF2            mov    si, dx                      ; SI = COM port number
F000:E742  8BFA            mov    di, dx                      ; DI = port number — index into timeout table 0040:007C
F000:E744  D1E6            shl    si, 1                       ; SI = 2*number — offset into COM base address table 0040:0000
F000:E746  E8A017          call   sub_FEE9                    ; DS = 0040h (BIOS data area)
F000:E749  8B14            mov    dx, word [si]               ; DX = COMn base address from 0040:0000+2n
F000:E74B  0BD2            or     dx, dx                      ; port installed?
F000:E74D  7413            je     loc_E762                    ; address 0 — no port, exit unchanged
F000:E74F  0AE4            or     ah, ah                      ; AH = 0?
F000:E751  7416            je     loc_E769                    ; → port init
F000:E753  FECC            dec    ah                          ; AH = 1?
F000:E755  7444            je     loc_E79B                    ; → send character
F000:E757  FECC            dec    ah                          ; AH = 2?
F000:E759  7469            je     loc_E7C4                    ; → receive character
F000:E75B  FECC            dec    ah                          ; AH = 3?
F000:E75D  7503            jne    loc_E762                    ; unknown function — exit
F000:E75F  E98200          jmp    loc_E7E4                    ; → read status

; ----------------------------------------------------------------------------------------------
; Common INT 14h exit: restore registers and IRET.
; ----------------------------------------------------------------------------------------------
loc_E762:    ; xrefs: E74D E75D E7B1 E7C2 E7E1 E7EE
F000:E762  5B              pop    bx                          ; restore BX
F000:E763  59              pop    cx                          ; restore CX
F000:E764  5F              pop    di                          ; restore DI
F000:E765  5E              pop    si                          ; restore SI
F000:E766  5A              pop    dx                          ; restore DX
F000:E767  1F              pop    ds                          ; restore DS
F000:E768  CF              iret                               ; return from INT 14h

; ----------------------------------------------------------------------------------------------
; INT 14h, AH=0 — init: AL = bits 7-5 baud rate, 4-3 parity, 2 stop bits, 1-0 word length.
; ----------------------------------------------------------------------------------------------
loc_E769:    ; xrefs: E751
F000:E769  8AE0            mov    ah, al                      ; AH = init parameters
F000:E76B  83C203          add    dx, 3                       ; DX = base+3 — line control register LCR (8250)
F000:E76E  B080            mov    al, 80h                     ; AL = 80h — DLAB bit: access to divisor latch registers
F000:E770  EE              out    dx, al                      ; LCR ← 80h (8250 emulator switches base+0/+1 to divisor)
F000:E771  8AD4            mov    dl, ah                      ; DL = parameters
F000:E773  B104            mov    cl, 4                       ; CL = 4
F000:E775  D2C2            rol    dl, cl                      ; baud bits 7-5 → bits 3-1
F000:E777  83E20E          and    dx, 0Eh                     ; DX = baud index * 2 — offset into divisor table
F000:E77A  BF29E7          mov    di, 0E729h                  ; DI = baud divisor table E729
F000:E77D  03FA            add    di, dx                      ; DI → divisor for selected baud rate
F000:E77F  8B14            mov    dx, word [si]               ; DX = port base address
F000:E781  42              inc    dx                          ; DX = base+1 — divisor high byte (DLM with DLAB=1)
F000:E782  2E8A4501        mov    al, byte cs:[di + 1]        ; AL = divisor high byte
F000:E786  EE              out    dx, al                      ; write DLM
F000:E787  4A              dec    dx                          ; DX = base+0 — divisor low byte (DLL)
F000:E788  2E8A05          mov    al, byte cs:[di]            ; AL = divisor low byte
F000:E78B  EE              out    dx, al                      ; write DLL
F000:E78C  83C203          add    dx, 3                       ; DX = base+3 — LCR
F000:E78F  8AC4            mov    al, ah                      ; AL = parameters
F000:E791  241F            and    al, 1Fh                     ; keep bits 4-0: parity, stop bits, word length (DLAB=0)
F000:E793  EE              out    dx, al                      ; LCR ← frame format, DLAB cleared
F000:E794  4A              dec    dx                          ; DX = base+2
F000:E795  4A              dec    dx                          ; DX = base+1 — interrupt enable register IER
F000:E796  B000            mov    al, 0                       ; AL = 0 — all 8250 interrupts disabled
F000:E798  EE              out    dx, al                      ; IER ← 0
F000:E799  EB49            jmp    loc_E7E4                    ; return port status (as AH=3)

; ----------------------------------------------------------------------------------------------
; INT 14h, AH=1 — send character AL: DTR+RTS, wait for DSR+CTS and empty THR, write to base+0.
; Timeout → AH bit 7 = 1.
; ----------------------------------------------------------------------------------------------
loc_E79B:    ; xrefs: E755
F000:E79B  50              push   ax                          ; save character to send
F000:E79C  83C204          add    dx, 4                       ; DX = base+4 — modem control register MCR
F000:E79F  B003            mov    al, 3                       ; AL = 3 — DTR and RTS
F000:E7A1  EE              out    dx, al                      ; MCR ← DTR|RTS
F000:E7A2  42              inc    dx                          ; DX = base+5
F000:E7A3  42              inc    dx                          ; DX = base+6 — modem status register MSR
F000:E7A4  B730            mov    bh, 30h                     ; BH = 30h — wait for DSR (5) and CTS (4) bits
F000:E7A6  E84800          call   sub_E7F1                    ; wait with timeout
F000:E7A9  7408            je     loc_E7B3                    ; ZF=1 — modem ready, wait for transmit buffer

loc_E7AB:    ; xrefs: E7B9
F000:E7AB  59              pop    cx                          ; timeout: CX = saved character
F000:E7AC  8AC1            mov    al, cl                      ; AL = character (returned to caller)

loc_E7AE:    ; xrefs: E7D1 E7D9
F000:E7AE  80CC80          or     ah, 80h                     ; AH bit 7 = 1 — timeout flag
F000:E7B1  EBAF            jmp    loc_E762                    ; exit

loc_E7B3:    ; xrefs: E7A9
F000:E7B3  4A              dec    dx                          ; DX = base+5 — line status register LSR
F000:E7B4  B720            mov    bh, 20h                     ; BH = 20h — THRE bit "transmitter holding register empty"
F000:E7B6  E83800          call   sub_E7F1                    ; wait for transmitter to free up
F000:E7B9  75F0            jne    loc_E7AB                    ; timeout → error
F000:E7BB  83EA05          sub    dx, 5                       ; DX = base+0 — transmitter holding register THR
F000:E7BE  59              pop    cx                          ; CX = character
F000:E7BF  8AC1            mov    al, cl                      ; AL = character
F000:E7C1  EE              out    dx, al                      ; send character (8250 emulator via NMI)
F000:E7C2  EB9E            jmp    loc_E762                    ; exit, AH = LSR

; ----------------------------------------------------------------------------------------------
; INT 14h, AH=2 — receive character: DTR, wait for DSR and "data ready", read base+0. AH = LSR error bits.
; ----------------------------------------------------------------------------------------------
loc_E7C4:    ; xrefs: E759
F000:E7C4  83C204          add    dx, 4                       ; DX = base+4 — MCR
F000:E7C7  B001            mov    al, 1                       ; AL = 1 — DTR only
F000:E7C9  EE              out    dx, al                      ; MCR ← DTR
F000:E7CA  42              inc    dx                          ; DX = base+5
F000:E7CB  42              inc    dx                          ; DX = base+6 — MSR
F000:E7CC  B720            mov    bh, 20h                     ; BH = 20h — wait for DSR
F000:E7CE  E82000          call   sub_E7F1                    ; wait with timeout
F000:E7D1  75DB            jne    loc_E7AE                    ; timeout → error
F000:E7D3  4A              dec    dx                          ; DX = base+5 — LSR
F000:E7D4  B701            mov    bh, 1                       ; BH = 01h — DR bit "byte received"
F000:E7D6  E81800          call   sub_E7F1                    ; wait for receive
F000:E7D9  75D3            jne    loc_E7AE                    ; timeout → error
F000:E7DB  80E41E          and    ah, 1Eh                     ; keep LSR error bits: overrun, parity, framing, break
F000:E7DE  8B14            mov    dx, word [si]               ; DX = base+0 — receiver buffer register RBR
F000:E7E0  EC              in     al, dx                      ; AL = received character
F000:E7E1  E97EFF          jmp    loc_E762                    ; exit

; ----------------------------------------------------------------------------------------------
; INT 14h, AH=3 — status: AH = LSR (base+5), AL = MSR (base+6).
; ----------------------------------------------------------------------------------------------
loc_E7E4:    ; xrefs: E75F E799
F000:E7E4  8B14            mov    dx, word [si]               ; DX = port base address
F000:E7E6  83C205          add    dx, 5                       ; DX = base+5 — LSR
F000:E7E9  EC              in     al, dx                      ; read line status
F000:E7EA  8AE0            mov    ah, al                      ; AH = LSR
F000:E7EC  42              inc    dx                          ; DX = base+6 — MSR
F000:E7ED  EC              in     al, dx                      ; AL = modem status
F000:E7EE  E971FF          jmp    loc_E762                    ; exit

; ----------------------------------------------------------------------------------------------
; sub_E7F1 — wait for bits BH to be set in port DX, with timeout.
; Number of outer loops (65536 polls each) — from 0040:007C+DI (COM port timeout).
; Out: ZF=1 — bits set; ZF=0 — timeout. AH = last status read.
; ----------------------------------------------------------------------------------------------
sub_E7F1:    ; xrefs: E7A6 E7B6 E7CE E7D6
F000:E7F1  8A9D7C00        mov    bl, byte [di + 7Ch]         ; BL = port timeout from 0040:007C+n

loc_E7F5:    ; xrefs: E804
F000:E7F5  2BC9            sub    cx, cx                      ; CX = 0 → 65536 polls in inner loop

loc_E7F7:    ; xrefs: E800
F000:E7F7  EC              in     al, dx                      ; read 8250 status register (emulated)
F000:E7F8  8AE0            mov    ah, al                      ; AH = status
F000:E7FA  22C7            and    al, bh                      ; mask expected bits
F000:E7FC  3AC7            cmp    al, bh                      ; all expected bits set?
F000:E7FE  7408            je     loc_E808                    ; yes — exit with ZF=1
F000:E800  E2F5            loop   loc_E7F7                    ; keep polling
F000:E802  FECB            dec    bl                          ; decrement outer loop counter
F000:E804  75EF            jne    loc_E7F5                    ; not expired yet — repeat
F000:E806  0AFF            or     bh, bh                      ; timeout: BH≠0 → ZF=0

loc_E808:    ; xrefs: E7FE
F000:E808  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_E809 — advance pointer BX through the keyboard ring buffer (by a word) with wrap
; from the end (0040:0082) to the start (0040:0080). DS = 0040h.
; ----------------------------------------------------------------------------------------------
sub_E809:    ; xrefs: E851 EC09
F000:E809  43              inc    bx                          ; BX += 2 — next buffer cell (scan code + ASCII)
F000:E80A  43              inc    bx                          ; (second increment)
F000:E80B  3B1E8200        cmp    bx, word [82h]              ; reached end of buffer (0040:0082)?
F000:E80F  7504            jne    loc_E815                    ; no — return
F000:E811  8B1E8000        mov    bx, word [80h]              ; yes — wrap to buffer start (0040:0080)

loc_E815:    ; xrefs: E80F
F000:E815  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; INT 16h, AH=1 — check for key: ZF=1 buffer empty, else ZF=0 and AX = code (not removed).
; RETF 2 return preserves ZF for the caller.
; ----------------------------------------------------------------------------------------------
loc_E816:    ; xrefs: E83A
F000:E816  FA              cli                                ; disable interrupts while comparing pointers
F000:E817  8B1E1A00        mov    bx, word [1Ah]              ; BX = buffer head (0040:001A)
F000:E81B  3B1E1C00        cmp    bx, word [1Ch]              ; compare with tail (0040:001C): ZF=1 — buffer empty
F000:E81F  8B07            mov    ax, word [bx]               ; AX = key code at head (flags unchanged)
F000:E821  FB              sti                                ; enable interrupts
F000:E822  5B              pop    bx                          ; restore BX
F000:E823  1F              pop    ds                          ; restore DS
F000:E824  CA0200          retf   2                           ; return with current flags (ZF), discarding old FLAGS from stack

loc_E827:    ; xrefs: E83E
F000:E827  A01700          mov    al, byte [17h]              ; INT 16h, AH=2: AL = keyboard flags 0040:0017 (Shift/Ctrl/Alt/modes)

loc_E82A:    ; xrefs: E840 E858
F000:E82A  5B              pop    bx                          ; restore BX
F000:E82B  1F              pop    ds                          ; restore DS
F000:E82C  CF              iret                               ; return from INT 16h
F000:E82D  00              db     00h                         ; filler 00h (padding to E82E)

; ----------------------------------------------------------------------------------------------
; INT 16h — keyboard (standard IBM address E82E). AH=0 read with wait, 1 check, 2 flags.
; Ring buffer at 0040:0080..0082, head 001A, tail 001C.
; ----------------------------------------------------------------------------------------------
INT16_KEYBOARD:
F000:E82E  FB              sti                                ; enable interrupts
F000:E82F  1E              push   ds                          ; save DS
F000:E830  53              push   bx                          ; save BX
F000:E831  E8B516          call   sub_FEE9                    ; DS = 0040h
F000:E834  0AE4            or     ah, ah                      ; AH = 0?
F000:E836  740A            je     loc_E842                    ; → read with wait
F000:E838  FECC            dec    ah                          ; AH = 1?
F000:E83A  74DA            je     loc_E816                    ; → check for key
F000:E83C  FECC            dec    ah                          ; AH = 2?
F000:E83E  74E7            je     loc_E827                    ; → keyboard flags
F000:E840  EBE8            jmp    loc_E82A                    ; other functions not supported — exit

loc_E842:    ; xrefs: E836 E84D
F000:E842  FB              sti                                ; INT 16h, AH=0: interrupt window (INT 09h may store a code)
F000:E843  90              nop                                ; pause to service pending interrupt
F000:E844  FA              cli                                ; disable interrupts during check
F000:E845  8B1E1A00        mov    bx, word [1Ah]              ; BX = buffer head (0040:001A)
F000:E849  3B1E1C00        cmp    bx, word [1Ch]              ; compare with tail (0040:001C)
F000:E84D  74F3            je     loc_E842                    ; buffer empty — keep waiting
F000:E84F  8B07            mov    ax, word [bx]               ; AX = scan code (AH) and ASCII (AL)
F000:E851  E8B5FF          call   sub_E809                    ; advance head with wrap
F000:E854  891E1A00        mov    word [1Ah], bx              ; store new head — code removed
F000:E858  EBD0            jmp    loc_E82A                    ; exit

; ----------------------------------------------------------------------------------------------
; INT 09h tables: scan codes of shift/toggle keys and their masks in flags 0040:0017/0018.
; ----------------------------------------------------------------------------------------------
dat_E85A:    ; xrefs: E956
F000:E85A  52              db     52h                         ; 52h — Ins scan code (mask 80h)

dat_E85B:    ; xrefs: E965
F000:E85B  3A454638        db     ':EF8'                      ; 3Ah CapsLock (40h), 45h NumLock (20h), 46h ScrollLock (10h), 38h Alt (08h)
F000:E85F  1D              db     1Dh                         ; 1Dh — Ctrl scan code (mask 04h)
F000:E860  2A              db     2Ah                         ; 2Ah — left Shift scan code (mask 02h)
F000:E861  36              db     36h                         ; 36h — right Shift scan code (mask 01h)

dat_E862:    ; xrefs: E969
F000:E862  804020100804…   db     80h,40h,20h,10h,08h,04h,02h,01h ; 0040:0017 bit masks: Ins, Caps, Num, Scroll, Alt, Ctrl, LShift, RShift

; ----------------------------------------------------------------------------------------------
; Ctrl code table for scan codes 01h–3Ah (index = scan code−1); FFh = no code.
; ----------------------------------------------------------------------------------------------
dat_E86A:    ; xrefs: EB00
F000:E86A  1BFF00FFFFFF…   db     1Bh,0FFh,00h,0FFh,0FFh,0FFh,1Eh,0FFh ; Esc→1Bh, 1→none, 2→00h (Ctrl-@), 3/4/5→none, 6→1Eh (Ctrl-^), 7→none
F000:E872  FFFFFF1FFF7F…   db     0FFh,0FFh,0FFh,1Fh,0FFh,7Fh,0FFh,11h ; 8,9,0→none, '-'→1Fh, '='→none, BS→7Fh, Tab→none, Q→11h
F000:E87A  170512141915…   db     17h,05h,12h,14h,19h,15h,09h,0Fh ; W→17h, E→05h, R→12h, T→14h, Y→19h, U→15h, I→09h, O→0Fh
F000:E882  101B1D0AFF01…   db     10h,1Bh,1Dh,0Ah,0FFh,01h,13h,04h ; P→10h, [→1Bh, ]→1Dh, Enter→0Ah, Ctrl→none, A→01h, S→13h, D→04h
F000:E88A  0607080A0B0C…   db     06h,07h,08h,0Ah,0Bh,0Ch,0FFh,0FFh ; F→06h, G→07h, H→08h, J→0Ah, K→0Bh, L→0Ch, ';'→none, '''→none
F000:E892  FFFF1C1A1803…   db     0FFh,0FFh,1Ch,1Ah,18h,03h,16h,02h ; '`'→none, LShift→none, '\'→1Ch, Z→1Ah, X→18h, C→03h, V→16h, B→02h
F000:E89A  0E0DFFFFFFFF…   db     0Eh,0Dh,0FFh,0FFh,0FFh,0FFh,0FFh,0FFh ; N→0Eh, M→0Dh, ','/'.'/'/'→none, RShift→none, '*'→none, Alt→none
F000:E8A2  20FF            db     20h,0FFh                    ; Space→20h, CapsLock→none

; ----------------------------------------------------------------------------------------------
; Ctrl extended code table (AH) for scan codes 3Bh–53h (index = scan−3Bh): Ctrl-F1..F10 and Ctrl+keypad.
; ----------------------------------------------------------------------------------------------
dat_E8A4:    ; xrefs: EB0A
F000:E8A4  5E5F60616263…   db     '^_`abcdefg'                ; Ctrl-F1..F10 → extended codes 5Eh..67h
F000:E8AE  FFFF77FF84FF…   db     0FFh,0FFh,77h,0FFh,84h,0FFh,73h,0FFh ; NumLock/Scroll→none, Home→77h, ↑→none, PgUp→84h, '-'→none, ←→73h, '5'→none
F000:E8B6  74FF75FF76FFFF  db     74h,0FFh,75h,0FFh,76h,0FFh,0FFh ; →→74h, '+'→none, End→75h, ↓→none, PgDn→76h, Ins→none, Del→none

dat_E8BD:    ; xrefs: EB31
F000:E8BD  545556575859…   db     'TUVWXYZ[\]'                ; Shift-F1..F10 → extended codes 54h..5Dh

dat_E8C7:    ; xrefs: EAA8
F000:E8C7  68696A6B6C6D…   db     'hijklmnopq'                ; Alt-F1..F10 → extended codes 68h..71h

; ----------------------------------------------------------------------------------------------
; Main ASCII table (unshifted, Latin) for scan codes 01h–3Ah (index = scan−1); FFh = no character.
; ----------------------------------------------------------------------------------------------
dat_E8D1:    ; xrefs: EB84
F000:E8D1  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:E8D2  313233343536…   db     '1234567890-='              ; scan 02h–0Dh: digits and '-', '='
F000:E8DE  0809            db     08h,09h                     ; scan 0Eh Backspace → 08h, 0Fh Tab → 09h
F000:E8E0  717765727479…   db     'qwertyuiop[]'              ; scan 10h–1Bh: top letter row
F000:E8EC  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh, 1Dh Ctrl → none
F000:E8EE  617364666768…   db     'asdfghjkl;'`'              ; scan 1Eh–29h: middle row, ';', ''', '`'
F000:E8FA  FF              db     0FFh                        ; scan 2Ah left Shift → none
F000:E8FB  5C7A78637662…   db     '\zxcvbnm,./'               ; scan 2Bh–35h: '\' and bottom row
F000:E906  FF2AFF20FF      db     0FFh,2Ah,0FFh,20h,0FFh      ; 36h RShift→none, 37h '*' (PrtSc), 38h Alt→none, 39h space, 3Ah Caps→none

; ----------------------------------------------------------------------------------------------
; INT 09h — keyboard handler (entered at standard E987 → jmp here).
; Called from the common INT 0Fh handler on a status bit in F000:0200. Scan code is read from the emulated
; port 60h, acknowledged by pulsing bit 7 of port 61h (as with the XT 8255 PPI). Beyond the standard IBM functions:
; prefix E0h → bit 1 of 0040:0018; right Ctrl (E0 9D) toggles RUS/LAT (bit 2 of 0040:0018).
; ----------------------------------------------------------------------------------------------
loc_E90B:    ; xrefs: E987
F000:E90B  50              push   ax                          ; save AX
F000:E90C  53              push   bx                          ; save BX
F000:E90D  51              push   cx                          ; save CX
F000:E90E  52              push   dx                          ; save DX
F000:E90F  56              push   si                          ; save SI
F000:E910  57              push   di                          ; save DI
F000:E911  1E              push   ds                          ; save DS
F000:E912  06              push   es                          ; save ES
F000:E913  FC              cld                                ; string operations — forward
F000:E914  E8D215          call   sub_FEE9                    ; DS = 0040h
F000:E917  E460            in     al, 60h                     ; read scan code from port 60h (emulated 8255 port A)
F000:E919  50              push   ax                          ; save scan code
F000:E91A  E461            in     al, 61h                     ; read 8255 port B (61h)
F000:E91C  8AE0            mov    ah, al                      ; AH = original port 61h value
F000:E91E  0C80            or     al, 80h                     ; bit 7 = 1 — keyboard reset/acknowledge
F000:E920  E661            out    61h, al                     ; issue acknowledge pulse
F000:E922  86E0            xchg   al, ah                      ; AL = original value
F000:E924  E661            out    61h, al                     ; restore port 61h — keyboard ready for next code
F000:E926  FB              sti                                ; enable interrupts
F000:E927  58              pop    ax                          ; AL = scan code
F000:E928  8AE0            mov    ah, al                      ; AH = scan code (copy)
F000:E92A  3CFF            cmp    al, 0FFh                    ; FFh — keyboard overrun/error?
F000:E92C  7503            jne    loc_E931                    ; no — normal processing
F000:E92E  E9F502          jmp    loc_EC26                    ; yes — beep (as on buffer overflow)

loc_E931:    ; xrefs: E92C
F000:E931  3CE0            cmp    al, 0E0h                    ; E0h — extended key prefix (AT/101-key keyboard)?
F000:E933  7508            jne    loc_E93D                    ; no
F000:E935  800E180002      or     byte [18h], 2               ; remember E0 prefix in bit 1 of 0040:0018 (non-standard use)
F000:E93A  E9CC00          jmp    loc_EA09                    ; exit, wait for next byte

loc_E93D:    ; xrefs: E933
F000:E93D  F606180002      test   byte [18h], 2               ; was previous byte an E0 prefix?
F000:E942  740E            je     loc_E952                    ; no
F000:E944  80261800FD      and    byte [18h], 0FDh            ; clear prefix flag
F000:E949  3C9D            cmp    al, 9Dh                     ; E0 9Dh — right Ctrl release?
F000:E94B  7505            jne    loc_E952                    ; no — handle as ordinary key
F000:E94D  8036180004      xor    byte [18h], 4               ; toggle bit 2 of 0040:0018 — RUS/LAT mode (selects tables F773/F7E7/F7AD)

loc_E952:    ; xrefs: E942 E94B
F000:E952  247F            and    al, 7Fh                     ; AL = scan code without release bit
F000:E954  0E              push   cs                          ; ES = CS for table search in ROM
F000:E955  07              pop    es                          ; (ES = F000)
F000:E956  BF5AE8          mov    di, 0E85Ah                  ; DI = modifier scan code table E85A
F000:E959  B90800          mov    cx, 8                       ; CX = 8 entries
F000:E95C  F2AE            repne scasb al, byte es:[di]       ; search scan code among Ins/Caps/Num/Scroll/Alt/Ctrl/Shift
F000:E95E  8AC4            mov    al, ah                      ; AL = original scan code (with release bit)
F000:E960  7403            je     loc_E965                    ; found — handle modifier
F000:E962  E99000          jmp    loc_E9F5                    ; ordinary key

loc_E965:    ; xrefs: E960
F000:E965  81EF5BE8        sub    di, 0E85Bh                  ; DI = index of found modifier (0..7)
F000:E969  2E8AA562E8      mov    ah, byte cs:[di - 179Eh]    ; AH = bit mask from table E862 (address E862+index)
F000:E96E  A880            test   al, 80h                     ; scan code bit 7 — release?
F000:E970  755C            jne    loc_E9CE                    ; yes — handle release
F000:E972  80FC10          cmp    ah, 10h                     ; mask ≥ 10h — toggle key (Ins/Caps/Num/Scroll)?
F000:E975  7312            jae    loc_E989                    ; yes — handle toggle
F000:E977  08261700        or     byte [17h], ah              ; Shift/Ctrl/Alt pressed: set bit in 0040:0017
F000:E97B  E98B00          jmp    loc_EA09                    ; exit

; ----------------------------------------------------------------------------------------------
; Fragment printing CR on printer 0 (AH=0, AL=0Dh, DX set by caller). Called from sub_FFCB (INT 05h, print screen).
; ----------------------------------------------------------------------------------------------
loc_E97E:    ; xrefs: FFD2
F000:E97E  B80D00          mov    ax, 0Dh                     ; AH = 0 (print character), AL = 0Dh (CR)
F000:E981  CD17            int    17h                         ; print CR via INT 17h (emulated LPT)
F000:E983  C3              ret                                ; return
F000:E984  000000          db     00h,00h,00h                 ; filler 00h (padding to standard entry E987)

INT09_KEYBOARD:
F000:E987  EB82            jmp    loc_E90B                    ; INT 09h — standard IBM entry point; jumps to handler body E90B

; ----------------------------------------------------------------------------------------------
; Toggle key press (Ins/CapsLock/NumLock/ScrollLock), AH = its mask.
; ----------------------------------------------------------------------------------------------
loc_E989:    ; xrefs: E975
F000:E989  F606170004      test   byte [17h], 4               ; Ctrl held (0040:0017 bit 2)?
F000:E98E  7565            jne    loc_E9F5                    ; yes — toggle not applied, handled as ordinary key
F000:E990  3C52            cmp    al, 52h                     ; is it Ins (52h)?
F000:E992  7522            jne    loc_E9B6                    ; no — toggle the mode
F000:E994  F606170008      test   byte [17h], 8               ; Alt held (bit 3)?
F000:E999  755A            jne    loc_E9F5                    ; yes — Ins as digit 0 for Alt+keypad
F000:E99B  F606170020      test   byte [17h], 20h             ; NumLock on (bit 5)?
F000:E9A0  750D            jne    loc_E9AF                    ; yes
F000:E9A2  F606170003      test   byte [17h], 3               ; NumLock off: Shift held (bits 0,1)?
F000:E9A7  740D            je     loc_E9B6                    ; no — Ins acts as insert toggle

loc_E9A9:    ; xrefs: E9B4
F000:E9A9  B83052          mov    ax, 5230h                   ; AX = 5230h — keypad '0' character
F000:E9AC  E9E601          jmp    loc_EB95                    ; to buffer

loc_E9AF:    ; xrefs: E9A0
F000:E9AF  F606170003      test   byte [17h], 3               ; NumLock on: Shift held?
F000:E9B4  74F3            je     loc_E9A9                    ; no — '0'; with Shift — insert toggle

loc_E9B6:    ; xrefs: E992 E9A7
F000:E9B6  84261800        test   byte [18h], ah              ; key already held (0040:0018)? — ignore toggle autorepeat
F000:E9BA  754D            jne    loc_EA09                    ; yes — exit
F000:E9BC  08261800        or     byte [18h], ah              ; mark key as held in 0040:0018
F000:E9C0  30261700        xor    byte [17h], ah              ; toggle mode in 0040:0017 (Ins/Caps/Num/Scroll)
F000:E9C4  3C52            cmp    al, 52h                     ; is it Ins?
F000:E9C6  7541            jne    loc_EA09                    ; no — exit
F000:E9C8  B80052          mov    ax, 5200h                   ; AX = 5200h — Insert code into buffer
F000:E9CB  E9C701          jmp    loc_EB95                    ; to buffer

; ----------------------------------------------------------------------------------------------
; Modifier/toggle key release (AL = scan code with bit 7, AH = mask).
; ----------------------------------------------------------------------------------------------
loc_E9CE:    ; xrefs: E970
F000:E9CE  80FC10          cmp    ah, 10h                     ; toggle (mask ≥ 10h)?
F000:E9D1  731A            jae    loc_E9ED                    ; yes — clear held flag
F000:E9D3  F6D4            not    ah                          ; AH = inverted mask
F000:E9D5  20261700        and    byte [17h], ah              ; clear Shift/Ctrl/Alt bit in 0040:0017
F000:E9D9  3CB8            cmp    al, 0B8h                    ; Alt released (B8h)?
F000:E9DB  752C            jne    loc_EA09                    ; no — exit
F000:E9DD  A01900          mov    al, byte [19h]              ; AL = code entered via Alt+digits (0040:0019)
F000:E9E0  B400            mov    ah, 0                       ; AH = 0
F000:E9E2  88261900        mov    byte [19h], ah              ; clear accumulator 0040:0019
F000:E9E6  3C00            cmp    al, 0                       ; code entered?
F000:E9E8  741F            je     loc_EA09                    ; no — exit
F000:E9EA  E9B101          jmp    loc_EB9E                    ; put entered code (AH=0) into buffer

loc_E9ED:    ; xrefs: E9D1
F000:E9ED  F6D4            not    ah                          ; AH = inverted toggle mask
F000:E9EF  20261800        and    byte [18h], ah              ; clear held flag in 0040:0018
F000:E9F3  EB14            jmp    loc_EA09                    ; exit

; ----------------------------------------------------------------------------------------------
; Ordinary key (not a modifier). Pause handling (Ctrl-NumLock) and jump to translation.
; ----------------------------------------------------------------------------------------------
loc_E9F5:    ; xrefs: E962 E98E E999
F000:E9F5  3C80            cmp    al, 80h                     ; release code (≥80h)?
F000:E9F7  7310            jae    loc_EA09                    ; yes — ignored for ordinary keys
F000:E9F9  F606180008      test   byte [18h], 8               ; system paused (0040:0018 bit 3)?
F000:E9FE  7413            je     loc_EA13                    ; no — translate code
F000:EA00  3C45            cmp    al, 45h                     ; NumLock does not end pause (repeated Ctrl-NumLock)
F000:EA02  7405            je     loc_EA09                    ; it is NumLock — exit, pause continues
F000:EA04  80261800F7      and    byte [18h], 0F7h            ; any other key ends pause (clear bit 3 of 0040:0018); the key itself is swallowed

; ----------------------------------------------------------------------------------------------
; INT 09h exit: restore registers, IRET.
; ----------------------------------------------------------------------------------------------
loc_EA09:    ; xrefs: E93A E97B E9BA E9C6 E9DB E9E8 E9F3 E9F7 EA02 EA7A EAA1 EBD7 EC18
F000:EA09  FA              cli                                ; disable interrupts until IRET

loc_EA0A:    ; xrefs: EAF3 EB2A EC44
F000:EA0A  07              pop    es                          ; restore ES
F000:EA0B  1F              pop    ds                          ; restore DS
F000:EA0C  5F              pop    di                          ; restore DI
F000:EA0D  5E              pop    si                          ; restore SI
F000:EA0E  5A              pop    dx                          ; restore DX
F000:EA0F  59              pop    cx                          ; restore CX
F000:EA10  5B              pop    bx                          ; restore BX
F000:EA11  58              pop    ax                          ; restore AX
F000:EA12  CF              iret                               ; return from INT 09h (no EOI needed — there is no 8259, state reset is done by INT 0Fh)

; ----------------------------------------------------------------------------------------------
; Translation with Alt held: Ctrl+Alt+Del, Alt+Space, Alt+digits (code entry), Alt+letters/digits/F-keys.
; ----------------------------------------------------------------------------------------------
loc_EA13:    ; xrefs: E9FE
F000:EA13  F606170008      test   byte [17h], 8               ; Alt pressed (bit 3 of 0040:0017)?
F000:EA18  7503            jne    loc_EA1D                    ; yes
F000:EA1A  E99100          jmp    loc_EAAE                    ; no — go to Ctrl/Shift/plain branch

loc_EA1D:    ; xrefs: EA18
F000:EA1D  F606170004      test   byte [17h], 4               ; Ctrl pressed too?
F000:EA22  7433            je     loc_EA57                    ; no
F000:EA24  3C53            cmp    al, 53h                     ; Del (53h)?
F000:EA26  752F            jne    loc_EA57                    ; no
F000:EA28  C70672003412    mov    word [72h], 1234h           ; Ctrl+Alt+Del: 0040:0072 = 1234h — "warm" reboot flag (skip memory test)
F000:EA2E  EA5BE000F0      jmp    far RESET                   ; jump to RESET (F000:E05B)

; ----------------------------------------------------------------------------------------------
; Alt table: keypad digit scan codes (index = digit 0..9), then 26 letter scan codes
; for Alt+letter (code = 00h/scan).
; ----------------------------------------------------------------------------------------------
dat_EA33:    ; xrefs: EA60
F000:EA33  52              db     52h                         ; 52h — keypad '0' (Ins)

dat_EA34:    ; xrefs: EA6A
F000:EA34  4F50514B4C4D…   db     'OPQKLMGHI'                 ; 4Fh '1', 50h '2', 51h '3', 4Bh '4', 4Ch '5', 4Dh '6', 47h '7', 48h '8', 49h '9'
F000:EA3D  101112131415…   db     10h,11h,12h,13h,14h,15h,16h,17h ; scan codes Q W E R T Y U I O P (10h–19h) — for Alt+letter
F000:EA45  18191E1F        db     18h,19h,1Eh,1Fh             ; scan codes A S (1Eh,1Fh)
F000:EA49  202122232425…   db     ' !"#$%&,-./012'            ; scan codes D F G H J K L (20h–26h), Z X C V B N M (2Ch–32h)

loc_EA57:    ; xrefs: EA22 EA26
F000:EA57  3C39            cmp    al, 39h                     ; Alt+Space (39h)?
F000:EA59  7505            jne    loc_EA60                    ; no
F000:EA5B  B020            mov    al, 20h                     ; AL = 20h (space), AH = 39h
F000:EA5D  E93501          jmp    loc_EB95                    ; to buffer

loc_EA60:    ; xrefs: EA59
F000:EA60  BF33EA          mov    di, 0EA33h                  ; DI = digit table EA33
F000:EA63  B90A00          mov    cx, 0Ah                     ; CX = 10 digits
F000:EA66  F2AE            repne scasb al, byte es:[di]       ; look up scan code among keypad digits
F000:EA68  7512            jne    loc_EA7C                    ; not a digit — check letters
F000:EA6A  81EF34EA        sub    di, 0EA34h                  ; DI = digit value 0..9
F000:EA6E  A01900          mov    al, byte [19h]              ; AL = accumulated code (0040:0019)
F000:EA71  B40A            mov    ah, 0Ah                     ; AH = 10
F000:EA73  F6E4            mul    ah                          ; AX = code*10
F000:EA75  03C7            add    ax, di                      ; + digit
F000:EA77  A21900          mov    byte [19h], al              ; store accumulated code (emitted on Alt release)
F000:EA7A  EB8D            jmp    loc_EA09                    ; exit

loc_EA7C:    ; xrefs: EA68
F000:EA7C  C606190000      mov    byte [19h], 0               ; any other key resets the Alt+digits accumulator
F000:EA81  B91A00          mov    cx, 1Ah                     ; CX = 26 letter scan codes (DI continues from EA3D)
F000:EA84  F2AE            repne scasb al, byte es:[di]       ; look up letter
F000:EA86  7505            jne    loc_EA8D                    ; not a letter
F000:EA88  B000            mov    al, 0                       ; Alt+letter: AL = 0, AH = scan code
F000:EA8A  E90801          jmp    loc_EB95                    ; to buffer

loc_EA8D:    ; xrefs: EA86
F000:EA8D  3C02            cmp    al, 2                       ; scan < 02h (Esc)?
F000:EA8F  720C            jb     loc_EA9D                    ; yes — continue
F000:EA91  3C0E            cmp    al, 0Eh                     ; scan ≥ 0Eh (past '=')?
F000:EA93  7308            jae    loc_EA9D                    ; yes — continue
F000:EA95  80C476          add    ah, 76h                     ; Alt+1..= : AH = scan+76h (78h..83h) — standard extended codes
F000:EA98  B000            mov    al, 0                       ; AL = 0
F000:EA9A  E9F800          jmp    loc_EB95                    ; to buffer

loc_EA9D:    ; xrefs: EA8F EA93
F000:EA9D  3C3B            cmp    al, 3Bh                     ; scan < 3Bh (not a function key)?
F000:EA9F  7303            jae    loc_EAA4                    ; no — check F-keys

loc_EAA1:    ; xrefs: EAA6
F000:EAA1  E965FF          jmp    loc_EA09                    ; other Alt combinations are ignored

loc_EAA4:    ; xrefs: EA9F
F000:EAA4  3C47            cmp    al, 47h                     ; scan ≥ 47h (keypad)?
F000:EAA6  73F9            jae    loc_EAA1                    ; yes — ignore
F000:EAA8  BBC7E8          mov    bx, 0E8C7h                  ; BX = Alt-F1..F10 table (E8C7)
F000:EAAB  E96D01          jmp    loc_EC1B                    ; extended code from table

; ----------------------------------------------------------------------------------------------
; Translation with Ctrl held (no Alt): Ctrl-Break, Ctrl-NumLock (pause), Ctrl-PrtSc, control codes.
; ----------------------------------------------------------------------------------------------
loc_EAAE:    ; xrefs: EA1A
F000:EAAE  F606170004      test   byte [17h], 4               ; Ctrl pressed (bit 2 of 0040:0017)?
F000:EAB3  745B            je     loc_EB10                    ; no — Shift/unmodified branch
F000:EAB5  3C46            cmp    al, 46h                     ; ScrollLock (46h) — Ctrl-Break?
F000:EAB7  7518            jne    loc_EAD1                    ; no
F000:EAB9  8B1E8000        mov    bx, word [80h]              ; BX = buffer start (0040:0080)
F000:EABD  891E1A00        mov    word [1Ah], bx              ; flush buffer: head = start
F000:EAC1  891E1C00        mov    word [1Ch], bx              ; tail = start
F000:EAC5  C606710080      mov    byte [71h], 80h             ; 0040:0071 bit 7 — Ctrl-Break pressed flag
F000:EACA  CD1B            int    1Bh                         ; call user Ctrl-Break handler INT 1Bh
F000:EACC  2BC0            sub    ax, ax                      ; AX = 0000 — empty code is put into the buffer (as in IBM)
F000:EACE  E9C400          jmp    loc_EB95                    ; to buffer

loc_EAD1:    ; xrefs: EAB7
F000:EAD1  3C45            cmp    al, 45h                     ; NumLock (45h) — pause?
F000:EAD3  7521            jne    loc_EAF6                    ; no
F000:EAD5  800E180008      or     byte [18h], 8               ; enable pause: 0040:0018 bit 3
F000:EADA  B020            mov    al, 20h                     ; AL = 20h — EOI command
F000:EADC  E620            out    20h, al                     ; EOI to port 20h (emulated 8259; enables next keyboard interrupt)
F000:EADE  803E490007      cmp    byte [49h], 7               ; video mode (0040:0049) = 7 (MDA)?
F000:EAE3  7407            je     loc_EAEC                    ; yes — skip
F000:EAE5  BAD803          mov    dx, 3D8h                    ; DX = 3D8h — CGA mode register
F000:EAE8  A06500          mov    al, byte [65h]              ; AL = current mode register value (0040:0065)
F000:EAEB  EE              out    dx, al                      ; restore CGA mode (enable video) — emulated via NMI

loc_EAEC:    ; xrefs: EAE3 EAF1
F000:EAEC  F606180008      test   byte [18h], 8               ; wait for next keypress to end pause (INT 09h clears bit 3)
F000:EAF1  75F9            jne    loc_EAEC                    ; spin while paused
F000:EAF3  E914FF          jmp    loc_EA0A                    ; exit without producing a code

loc_EAF6:    ; xrefs: EAD3
F000:EAF6  3C37            cmp    al, 37h                     ; PrtSc/'*' (37h)?
F000:EAF8  7506            jne    loc_EB00                    ; no
F000:EAFA  B80072          mov    ax, 7200h                   ; Ctrl-PrtSc: AX = 7200h
F000:EAFD  E99500          jmp    loc_EB95                    ; to buffer

loc_EB00:    ; xrefs: EAF8
F000:EB00  BB6AE8          mov    bx, 0E86Ah                  ; BX = Ctrl code table E86A
F000:EB03  3C3B            cmp    al, 3Bh                     ; scan < 3Bh?
F000:EB05  7303            jae    loc_EB0A                    ; no — function keys/keypad
F000:EB07  E98700          jmp    loc_EB91                    ; ASCII from table E86A (index scan−1)

loc_EB0A:    ; xrefs: EB05
F000:EB0A  BBA4E8          mov    bx, 0E8A4h                  ; BX = Ctrl F-key/keypad table E8A4
F000:EB0D  E90B01          jmp    loc_EC1B                    ; extended code from table

; ----------------------------------------------------------------------------------------------
; Translation without Alt/Ctrl: Shift or unmodified. Honors RUS/LAT mode (bit 2 of 0040:0018).
; ----------------------------------------------------------------------------------------------
loc_EB10:    ; xrefs: EAB3
F000:EB10  3C47            cmp    al, 47h                     ; keypad (≥ 47h)?
F000:EB12  7332            jae    loc_EB46                    ; yes — separate handling
F000:EB14  F606170003      test   byte [17h], 3               ; Shift pressed (bits 0,1 of 0040:0017)?
F000:EB19  7461            je     loc_EB7C                    ; no — lowercase
F000:EB1B  3C0F            cmp    al, 0Fh                     ; Tab (0Fh)?
F000:EB1D  7505            jne    loc_EB24                    ; no
F000:EB1F  B8000F          mov    ax, 0F00h                   ; Shift-Tab: AX = 0F00h (BackTab)
F000:EB22  EB71            jmp    loc_EB95                    ; to buffer

loc_EB24:    ; xrefs: EB1D
F000:EB24  3C37            cmp    al, 37h                     ; PrtSc (37h)?
F000:EB26  7505            jne    loc_EB2D                    ; no
F000:EB28  CD05            int    5                           ; Shift-PrtSc: print screen INT 05h
F000:EB2A  E9DDFE          jmp    loc_EA0A                    ; exit

loc_EB2D:    ; xrefs: EB26
F000:EB2D  3C3B            cmp    al, 3Bh                     ; F-keys (≥ 3Bh)?
F000:EB2F  7206            jb     loc_EB37                    ; no — character keys
F000:EB31  BBBDE8          mov    bx, 0E8BDh                  ; BX = Shift-F1..F10 table (E8BD)
F000:EB34  E9E400          jmp    loc_EC1B                    ; extended code from table

loc_EB37:    ; xrefs: EB2F
F000:EB37  BB73F7          mov    bx, 0F773h                  ; BX = uppercase table, Latin (F773)
F000:EB3A  F606180004      test   byte [18h], 4               ; RUS mode (bit 2 of 0040:0018)?
F000:EB3F  7450            je     loc_EB91                    ; no — Latin
F000:EB41  BBE7F7          mov    bx, 0F7E7h                  ; BX = uppercase table, Cyrillic CP866 (F7E7)
F000:EB44  EB4B            jmp    loc_EB91                    ; ASCII from table

; ----------------------------------------------------------------------------------------------
; INT 09 (continued): keypad keys (scan codes 47h–53h), no Alt/Ctrl.
; NumLock XOR Shift → digits/signs from keypad_table (FF23); otherwise cursor codes from table FF30 (AL=0, AH=scan).
; Gray "-" (4Ah) and "+" (4Eh) always produce characters. Input: AL=AH=make scan code.
; ----------------------------------------------------------------------------------------------
loc_EB46:    ; xrefs: EB12
F000:EB46  F606170020      test   byte [17h], 20h             ; 0040:0017 bit 5 = NumLock on?
F000:EB4B  7521            jne    loc_EB6E                    ; NumLock on → check Shift (Shift inverts NumLock)
F000:EB4D  F606170003      test   byte [17h], 3               ; NumLock off: left/right Shift pressed (bits 0–1 of 0040:0017)?
F000:EB52  7521            jne    loc_EB75                    ; Shift with NumLock off → numeric mode

; ----------------------------------------------------------------------------------------------
; Cursor control mode (NumLock off, or on together with Shift).
; ----------------------------------------------------------------------------------------------
loc_EB54:    ; xrefs: EB73
F000:EB54  3C4A            cmp    al, 4Ah                     ; scan 4Ah — gray "-" on keypad?
F000:EB56  740C            je     loc_EB64                    ; yes → emit "-"
F000:EB58  3C4E            cmp    al, 4Eh                     ; scan 4Eh — gray "+"?
F000:EB5A  740D            je     loc_EB69                    ; yes → emit "+"
F000:EB5C  2C47            sub    al, 47h                     ; index = scan − 47h (Home=0 … Del=0Ch)
F000:EB5E  BB30FF          mov    bx, 0FF30h                  ; BX → cursor scan code table FF30 (FFh = key produces no code)
F000:EB61  E9B900          jmp    loc_EC1D                    ; xlat → AH = extended code, AL = 0, then store to buffer

loc_EB64:    ; xrefs: EB56
F000:EB64  B82D4A          mov    ax, 4A2Dh                   ; AX = 4A2Dh: scan 4Ah, ASCII "-"
F000:EB67  EB2C            jmp    loc_EB95                    ; to common check and buffer store

loc_EB69:    ; xrefs: EB5A
F000:EB69  B82B4E          mov    ax, 4E2Bh                   ; AX = 4E2Bh: scan 4Eh, ASCII "+"
F000:EB6C  EB27            jmp    loc_EB95                    ; to common check and buffer store

loc_EB6E:    ; xrefs: EB4B
F000:EB6E  F606170003      test   byte [17h], 3               ; NumLock on: Shift pressed?
F000:EB73  75DF            jne    loc_EB54                    ; NumLock+Shift → cursor mode

; ----------------------------------------------------------------------------------------------
; Numeric mode: character taken from keypad_table F000:FF23 ("789-456+1230.").
; ----------------------------------------------------------------------------------------------
loc_EB75:    ; xrefs: EB52
F000:EB75  2C46            sub    al, 46h                     ; AL = scan − 46h (1..0Dh); after dec — index from 47h
F000:EB77  BB23FF          mov    bx, 0FF23h                  ; BX → keypad_table (ASCII of keypad digits and signs)
F000:EB7A  EB15            jmp    loc_EB91                    ; to common xlat (dec al / xlat) and buffer store

; ----------------------------------------------------------------------------------------------
; Regular key (scan < 47h) without Shift/Ctrl/Alt: F-keys or character from lowercase table.
; Table selected by 0040:0018 bit 2 — non-standard RUS/LAT mode flag (toggled by right Ctrl, E0 9D).
; ----------------------------------------------------------------------------------------------
loc_EB7C:    ; xrefs: EB19
F000:EB7C  3C3B            cmp    al, 3Bh                     ; scan ≥ 3Bh (F1–F10 etc.)?
F000:EB7E  7204            jb     loc_EB84                    ; no → regular character
F000:EB80  B000            mov    al, 0                       ; F-key: AL = 0, AH = scan code (extended code)
F000:EB82  EB11            jmp    loc_EB95                    ; to buffer store

loc_EB84:    ; xrefs: EB7E
F000:EB84  BBD1E8          mov    bx, 0E8D1h                  ; BX → lowercase table, Latin (E8D1: Esc,1..=,BS,Tab,q..)
F000:EB87  F606180004      test   byte [18h], 4               ; 0040:0018 bit 2 = RUS mode (non-standard use; SysReq in IBM)?
F000:EB8C  7403            je     loc_EB91                    ; LAT → keep Latin table
F000:EB8E  BBADF7          mov    bx, 0F7ADh                  ; RUS → Cyrillic lowercase table F7AD (йцукен…, CP866)

; ----------------------------------------------------------------------------------------------
; Common translation: AL = scan code (1-based index), BX = table in CS → AL = ASCII; AH = scan.
; ----------------------------------------------------------------------------------------------
loc_EB91:    ; xrefs: EB07 EB3F EB44 EB7A EB8C
F000:EB91  FEC8            dec    al                          ; scan codes start at 1 (Esc) → make index zero-based
F000:EB93  2ED7            xlatb                              ; AL = cs:[BX+AL] — ASCII code from layout table

; ----------------------------------------------------------------------------------------------
; Common point: AX = (scan, ASCII) ready. FFh in AL or AH = "no code" → ignore.
; Next: CapsLock handling (incl. Cyrillic CP866) and store into ring buffer 0040:001E.
; ----------------------------------------------------------------------------------------------
loc_EB95:    ; xrefs: E9AC E9CB EA5D EA8A EA9A EACE EAFD EB22 EB67 EB6C EB82 EC23
F000:EB95  3CFF            cmp    al, 0FFh                    ; AL = FFh — key produces no character in this shift state?
F000:EB97  743E            je     loc_EBD7                    ; yes → exit handler without storing
F000:EB99  80FCFF          cmp    ah, 0FFh                    ; AH = FFh — no extended code (e.g. "5" in cursor mode)?
F000:EB9C  7439            je     loc_EBD7                    ; yes → exit

; ----------------------------------------------------------------------------------------------
; CapsLock handling: when CapsLock is on, letter case is flipped (Shift inverts the effect).
; Latin: a–z ↔ A–Z. Cyrillic CP866: а–п(A0–AF)↔А–П(80–8F), р–я(E0–EF)↔Р–Я(90–9F), ё(F1)↔Ё(F0).
; The code entered via Alt+digits (from E9EA) also arrives here.
; ----------------------------------------------------------------------------------------------
loc_EB9E:    ; xrefs: E9EA
F000:EB9E  F606170040      test   byte [17h], 40h             ; 0040:0017 bit 6 = CapsLock on?
F000:EBA3  745E            je     loc_EC03                    ; no → store character as is
F000:EBA5  F606170003      test   byte [17h], 3               ; CapsLock: Shift pressed?
F000:EBAA  742E            je     loc_EBDA                    ; no Shift → convert lowercase to uppercase (EBDA)
F000:EBAC  F606180004      test   byte [18h], 4               ; Caps+Shift → convert uppercase to lowercase; RUS mode (0040:0018 bit 2)?
F000:EBB1  7418            je     loc_EBCB                    ; LAT → A–Z only
F000:EBB3  3CF0            cmp    al, 0F0h                    ; F0h = "Ё" (CP866)?
F000:EBB5  7504            jne    loc_EBBB                    ; no → check А–Я range
F000:EBB7  FEC0            inc    al                          ; Ё → ё (F1h)
F000:EBB9  EB48            jmp    loc_EC03                    ; to buffer store

loc_EBBB:    ; xrefs: EBB5
F000:EBBB  3C80            cmp    al, 80h                     ; below 80h — not Cyrillic
F000:EBBD  7244            jb     loc_EC03                    ; leave unchanged
F000:EBBF  3C9F            cmp    al, 9Fh                     ; above 9Fh ("Я") — not uppercase Cyrillic
F000:EBC1  7740            ja     loc_EC03                    ; leave unchanged
F000:EBC3  3C90            cmp    al, 90h                     ; А–П (80–8Fh) or Р–Я (90–9Fh)?
F000:EBC5  720C            jb     loc_EBD3                    ; А–П → +20h (а–п, A0–AFh)
F000:EBC7  0450            add    al, 50h                     ; Р–Я → +50h (р–я, E0–EFh)
F000:EBC9  EB38            jmp    loc_EC03                    ; to buffer store

loc_EBCB:    ; xrefs: EBB1
F000:EBCB  3C41            cmp    al, 41h                     ; Latin: below "A"?
F000:EBCD  7234            jb     loc_EC03                    ; not a letter → unchanged
F000:EBCF  3C5A            cmp    al, 5Ah                     ; above "Z"?
F000:EBD1  7730            ja     loc_EC03                    ; not a letter → unchanged

loc_EBD3:    ; xrefs: EBC5
F000:EBD3  0420            add    al, 20h                     ; uppercase → lowercase (+20h)
F000:EBD5  EB2C            jmp    loc_EC03                    ; to buffer store

loc_EBD7:    ; xrefs: EB97 EB9C
F000:EBD7  E92FFE          jmp    loc_EA09                    ; jump to common INT 09 exit (cli, restore registers, iret)

loc_EBDA:    ; xrefs: EBAA
F000:EBDA  F606180004      test   byte [18h], 4               ; CapsLock without Shift → to uppercase; RUS mode?
F000:EBDF  7418            je     loc_EBF9                    ; LAT → a–z only
F000:EBE1  3CF1            cmp    al, 0F1h                    ; F1h = "ё" (CP866)?
F000:EBE3  7504            jne    loc_EBE9                    ; no → check lowercase Cyrillic ranges
F000:EBE5  FEC8            dec    al                          ; ё → Ё (F0h)
F000:EBE7  EB1A            jmp    loc_EC03                    ; to buffer store

loc_EBE9:    ; xrefs: EBE3
F000:EBE9  3CA0            cmp    al, 0A0h                    ; below A0h ("а") — not lowercase Cyrillic
F000:EBEB  7216            jb     loc_EC03                    ; leave unchanged
F000:EBED  3CEF            cmp    al, 0EFh                    ; above EFh ("я")?
F000:EBEF  7712            ja     loc_EC03                    ; leave unchanged
F000:EBF1  3CE0            cmp    al, 0E0h                    ; р–я (E0–EFh)? else A0–DFh (box-drawing B0–DF also lands here — a flaw)
F000:EBF3  720C            jb     loc_EC01                    ; а–п (and B0–DFh) → −20h
F000:EBF5  2C50            sub    al, 50h                     ; р–я → −50h (Р–Я, 90–9Fh)
F000:EBF7  EB0A            jmp    loc_EC03                    ; to buffer store

loc_EBF9:    ; xrefs: EBDF
F000:EBF9  3C61            cmp    al, 61h                     ; Latin: below "a"?
F000:EBFB  7206            jb     loc_EC03                    ; not a letter → unchanged
F000:EBFD  3C7A            cmp    al, 7Ah                     ; above "z"?
F000:EBFF  7702            ja     loc_EC03                    ; not a letter → unchanged

loc_EC01:    ; xrefs: EBF3
F000:EC01  2C20            sub    al, 20h                     ; lowercase → uppercase (−20h)

; ----------------------------------------------------------------------------------------------
; Store AX (AH=scan, AL=ASCII) into keyboard ring buffer.
; 0040:001C — tail, 0040:001A — head, bounds 0040:0080/0082. Overflow → beep.
; ----------------------------------------------------------------------------------------------
loc_EC03:    ; xrefs: EBA3 EBB9 EBBD EBC1 EBC9 EBCD EBD1 EBD5 EBE7 EBEB EBEF EBF7 EBFB EBFF
F000:EC03  8B1E1C00        mov    bx, word [1Ch]              ; BX = buffer tail (0040:001C) — slot for the new word
F000:EC07  8BF3            mov    si, bx                      ; SI = store address
F000:EC09  E8FDFB          call   sub_E809                    ; sub_E809: BX += 2 with wrap past buffer end (0040:0082 → 0040:0080)
F000:EC0C  3B1E1A00        cmp    bx, word [1Ah]              ; new tail caught up with head (0040:001A)?
F000:EC10  7414            je     loc_EC26                    ; buffer full → beep (EC26)
F000:EC12  8904            mov    word [si], ax               ; store key code in buffer
F000:EC14  891E1C00        mov    word [1Ch], bx              ; update tail 0040:001C
F000:EC18  E9EEFD          jmp    loc_EA09                    ; exit INT 09

; ----------------------------------------------------------------------------------------------
; Extended code from table: AL = scan − 3Bh (F1=0) → AH = code from table BX, AL = 0.
; Used for F-keys with Shift/Ctrl/Alt (tables E8BD, E8A4, E8C7) and cursor keys (FF30).
; ----------------------------------------------------------------------------------------------
loc_EC1B:    ; xrefs: EAAB EB0D EB34
F000:EC1B  2C3B            sub    al, 3Bh                     ; index relative to F1 (scan 3Bh)

loc_EC1D:    ; xrefs: EB61
F000:EC1D  2ED7            xlatb                              ; AL = cs:[BX+AL] — extended scan code
F000:EC1F  8AE0            mov    ah, al                      ; AH = extended code
F000:EC21  B000            mov    al, 0                       ; AL = 0 — extended key marker for INT 16h
F000:EC23  E96FFF          jmp    loc_EB95                    ; to common FFh check and buffer store

; ----------------------------------------------------------------------------------------------
; Beep (buffer full or scan code FFh — keyboard overrun).
; 128 square-wave periods via bit 1 of port 61h (PPI 8255 port B, "speaker data"; emulated via NMI).
; Then restore 61h and exit INT 09 (without cli).
; ----------------------------------------------------------------------------------------------
loc_EC26:    ; xrefs: E92E EC10
F000:EC26  BB8000          mov    bx, 80h                     ; BX = 128 tone periods
F000:EC29  E461            in     al, 61h                     ; read 8255 port B (61h) — emulated by the NMI handler
F000:EC2B  50              push   ax                          ; save original state of port 61h

loc_EC2C:    ; xrefs: EC3F
F000:EC2C  24FC            and    al, 0FCh                    ; bit 0 (timer GATE2 input) and bit 1 (speaker) = 0
F000:EC2E  E661            out    61h, al                     ; speaker off ("0" half-period)
F000:EC30  B94800          mov    cx, 48h                     ; half-period delay — 72 iterations

loc_EC33:    ; xrefs: EC33
F000:EC33  E2FE            loop   loc_EC33                    ; empty delay loop
F000:EC35  0C02            or     al, 2                       ; bit 1 = 1 — speaker on
F000:EC37  E661            out    61h, al                     ; "1" half-period
F000:EC39  B94800          mov    cx, 48h                     ; half-period delay

loc_EC3C:    ; xrefs: EC3C
F000:EC3C  E2FE            loop   loc_EC3C                    ; empty delay loop
F000:EC3E  4B              dec    bx                          ; next period
F000:EC3F  75EB            jne    loc_EC2C                    ; repeat 128 times
F000:EC41  58              pop    ax                          ; original port 61h value
F000:EC42  E661            out    61h, al                     ; restore 8255 port B state
F000:EC44  E9C3FD          jmp    loc_EA0A                    ; exit INT 09 (pop es…ax, iret)
F000:EC47  00              db     18 dup (00h)                ; zero padding up to standard INT 13h entry point (F000:EC59)

; ----------------------------------------------------------------------------------------------
; INT 13h — floppy disk service (standard IBM entry point F000:EC59).
; Functions: 0 reset, 1 status, 2 read, 3 write, 4 verify, 5 format, 8 drive parameters.
; Input: AH=function, AL=sector count, CH=cylinder, CL=sector, DH=head, DL=drive (0–1), ES:BX=buffer.
; Output: AH=status (0040:0041), CF=1 on error, AL=sectors processed.
; 765 controller (ports 3F2/3F4/3F5) and 8237 DMA channel 2 (ports 04/05/0A/0B/0C/81) — emulated via NMI.
; Frame: [bp]=DX,[bp+2]=BP,[bp+4]=DI,[bp+6]=SI,[bp+8]=DS,[bp+0Ah]=CX,[bp+0Ch]=BX.
; ----------------------------------------------------------------------------------------------
INT13_DISKETTE:
F000:EC59  FB              sti                                ; enable interrupts (floppy IRQ needed → INT 0Eh via common handler F400:0400)
F000:EC5A  53              push   bx                          ; save BX (may be returned modified — function 8)
F000:EC5B  51              push   cx                          ; save CX (function 8 returns cylinders/sectors in it)
F000:EC5C  1E              push   ds                          ; save DS
F000:EC5D  56              push   si                          ; save SI
F000:EC5E  57              push   di                          ; save DI (function 8 returns parameter table offset)
F000:EC5F  55              push   bp                          ; save BP
F000:EC60  52              push   dx                          ; save DX ([bp+1] = head number)
F000:EC61  8BEC            mov    bp, sp                      ; BP — base of saved-register frame
F000:EC63  E88312          call   sub_FEE9                    ; DS = 0040h (BIOS data area)
F000:EC66  E84600          call   sub_ECAF                    ; execute function AH (dispatcher)
F000:EC69  BB0400          mov    bx, 4                       ; BX=4 → parameter table byte 2 (motor-off delay), not sent to 765
F000:EC6C  E8FF01          call   sub_EE6E                    ; AH = motor run-on time in timer ticks
F000:EC6F  88264000        mov    byte [40h], ah              ; 0040:0040 — motor-off countdown (decremented in INT 08)
F000:EC73  8A264100        mov    ah, byte [41h]              ; AH = operation status 0040:0041
F000:EC77  80FC01          cmp    ah, 1                       ; CF=1 if status is 0 …
F000:EC7A  F5              cmc                                ; … inverted: CF=1 on non-zero status (error)
F000:EC7B  5A              pop    dx                          ; restore DX
F000:EC7C  5D              pop    bp                          ; restore BP
F000:EC7D  5F              pop    di                          ; restore DI (for function 8 — already replaced in frame)
F000:EC7E  5E              pop    si                          ; restore SI
F000:EC7F  1F              pop    ds                          ; restore DS
F000:EC80  59              pop    cx                          ; restore CX
F000:EC81  5B              pop    bx                          ; restore BX
F000:EC82  CA0200          retf   2                           ; return discarding old FLAGS — CF is passed to the caller

; ----------------------------------------------------------------------------------------------
; Function 08h — drive parameters (reduced implementation).
; Type is given by bit (10h << DL) in 0040:003E (non-standard: 80-track disk/drive flag, 720K).
; Output: CX = max cylinder/sectors, BL = type (1=360K, 3=720K), ES:DI = parameter table (vector 1Eh).
; DH/DL (heads/drive count) are not filled in.
; ----------------------------------------------------------------------------------------------
loc_EC85:    ; xrefs: ECCB
F000:EC85  1E              push   ds                          ; save DS (=0040h)
F000:EC86  B010            mov    al, 10h                     ; "80 tracks" bit mask for drive 0 …
F000:EC88  8ACA            mov    cl, dl                      ; CL = drive number
F000:EC8A  D2C0            rol    al, cl                      ; … shift by drive number: bit 4/5 in 0040:003E
F000:EC8C  BB0100          mov    bx, 1                       ; BX = 1 — 360 KB type (40 tracks)
F000:EC8F  B90927          mov    cx, 2709h                   ; CH = 39 (last cylinder), CL = 9 sectors per track
F000:EC92  84063E00        test   byte [3Eh], al              ; drive marked as 80-track?
F000:EC96  7404            je     loc_EC9C                    ; no → keep 360K parameters
F000:EC98  B303            mov    bl, 3                       ; BL = 3 — 720 KB type
F000:EC9A  B54F            mov    ch, 4Fh                     ; CH = 79 (last cylinder of an 80-track disk)

loc_EC9C:    ; xrefs: EC96
F000:EC9C  33C0            xor    ax, ax                      ; AX = 0 (AH=0 — no error; status 0040:0041 already cleared)
F000:EC9E  894E0A          mov    word [bp + 0Ah], cx         ; return CX via stack frame
F000:ECA1  895E0C          mov    word [bp + 0Ch], bx         ; return BX via stack frame
F000:ECA4  8ED8            mov    ds, ax                      ; DS = 0 to read the vector table
F000:ECA6  C43E7800        les    di, [78h]                   ; ES:DI = INT 1Eh vector (0000:0078) — floppy parameter table; ES is returned as is
F000:ECAA  897E04          mov    word [bp + 4], di           ; return DI via stack frame
F000:ECAD  1F              pop    ds                          ; restore DS = 0040h
F000:ECAE  C3              ret                                ; return to INT 13h

; ----------------------------------------------------------------------------------------------
; sub_ECAF — INT 13h function dispatcher.
; Input: AH=function, AL=sector count (saved in DH), DL=drive. DS=0040h.
; Writes status to 0040:0041, clears write flag (0040:003F bit 7).
; ----------------------------------------------------------------------------------------------
sub_ECAF:    ; xrefs: EC66
F000:ECAF  8AF0            mov    dh, al                      ; DH = sector count (head available as [bp+1])
F000:ECB1  80263F007F      and    byte [3Fh], 7Fh             ; 0040:003F bit 7 (write in progress) = 0
F000:ECB6  0AE4            or     ah, ah                      ; AH=0?
F000:ECB8  742D            je     loc_ECE7                    ; → controller reset
F000:ECBA  FECC            dec    ah                          ; AH=1?
F000:ECBC  7425            je     loc_ECE3                    ; → read status of last operation
F000:ECBE  C606410000      mov    byte [41h], 0               ; clear status 0040:0041
F000:ECC3  80FA02          cmp    dl, 2                       ; only drives 0 and 1 are supported
F000:ECC6  7315            jae    loc_ECDD                    ; DL ≥ 2 → "bad command" error (1)
F000:ECC8  80FC07          cmp    ah, 7                       ; original AH=8?
F000:ECCB  74B8            je     loc_EC85                    ; → drive parameters
F000:ECCD  FECC            dec    ah                          ; AH=2?
F000:ECCF  7474            je     loc_ED45                    ; → read
F000:ECD1  FECC            dec    ah                          ; AH=3?
F000:ECD3  7462            je     loc_ED37                    ; → write
F000:ECD5  FECC            dec    ah                          ; AH=4?
F000:ECD7  7475            je     loc_ED4E                    ; → verify
F000:ECD9  FECC            dec    ah                          ; AH=5?
F000:ECDB  7475            je     loc_ED52                    ; → format track

loc_ECDD:    ; xrefs: ECC6
F000:ECDD  C606410001      mov    byte [41h], 1               ; unknown function/drive: status 1 — bad command
F000:ECE2  C3              ret                                ; return

loc_ECE3:    ; xrefs: ECBC
F000:ECE3  A04100          mov    al, byte [41h]              ; function 1: AL = last operation status (0040:0041; AH will get the same status)
F000:ECE6  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Function 00h — reset 765 floppy controller via DOR (3F2h).
; Keeps running motors, reset pulse (bit 2=0 → 1), waits for IRQ and Sense Interrupt,
; then SPECIFY command (03h) with bytes 0–1 of the parameter table.
; ----------------------------------------------------------------------------------------------
loc_ECE7:    ; xrefs: ECB8
F000:ECE7  BAF203          mov    dx, 3F2h                    ; DX = 3F2h — Digital Output Register (emulated by NMI handler)
F000:ECEA  FA              cli                                ; disable interrupts during reset
F000:ECEB  A03F00          mov    al, byte [3Fh]              ; AL = 0040:003F — bits 0–3: running drive motors
F000:ECEE  B104            mov    cl, 4                       ; shift by 4 …
F000:ECF0  D2E0            shl    al, cl                      ; … motor bits into positions 4–7 of DOR
F000:ECF2  A820            test   al, 20h                     ; drive 1 motor on?
F000:ECF4  750C            jne    loc_ED02                    ; → select drive 1
F000:ECF6  A840            test   al, 40h                     ; drive 2 motor?
F000:ECF8  7506            jne    loc_ED00                    ; → select drive 2
F000:ECFA  A880            test   al, 80h                     ; drive 3 motor?
F000:ECFC  7406            je     loc_ED04                    ; no → drive 0 selected
F000:ECFE  FEC0            inc    al                          ; drive number +1 (3 in total)

loc_ED00:    ; xrefs: ECF8
F000:ED00  FEC0            inc    al                          ; drive number +1

loc_ED02:    ; xrefs: ECF4
F000:ED02  FEC0            inc    al                          ; drive number +1

loc_ED04:    ; xrefs: ECFC
F000:ED04  0C08            or     al, 8                       ; DOR bit 3 — enable DMA and IRQ; bit 2 = 0 — 765 reset asserted
F000:ED06  EE              out    dx, al                      ; write DOR: controller held in reset
F000:ED07  80263E0030      and    byte [3Eh], 30h             ; 0040:003E: clear recalibrate and interrupt flags, keep bits 4–5 (80 tracks)
F000:ED0C  C606410000      mov    byte [41h], 0               ; status = 0
F000:ED11  0C04            or     al, 4                       ; bit 2 = 1 — release reset
F000:ED13  EE              out    dx, al                      ; write DOR: controller running
F000:ED14  FB              sti                                ; enable interrupts to receive IRQ after reset
F000:ED15  E81E02          call   sub_EF36                    ; wait for interrupt and issue SENSE INTERRUPT STATUS
F000:ED18  A04200          mov    al, byte [42h]              ; AL = ST0 from results (0040:0042)
F000:ED1B  3CC0            cmp    al, 0C0h                    ; C0h expected — "ready change" after reset
F000:ED1D  7406            je     loc_ED25                    ; yes → continue setup
F000:ED1F  800E410020      or     byte [41h], 20h             ; otherwise status 20h — controller failure
F000:ED24  C3              ret                                ; return

loc_ED25:    ; xrefs: ED1D
F000:ED25  B403            mov    ah, 3                       ; command 03h SPECIFY
F000:ED27  E85501          call   sub_EE7F                    ; send to 765
F000:ED2A  BB0100          mov    bx, 1                       ; BX=1 → table byte 0 (SRT/HUT), sent to 765
F000:ED2D  E83E01          call   sub_EE6E                    ; send 1st SPECIFY byte
F000:ED30  BB0300          mov    bx, 3                       ; BX=3 → table byte 1 (HLT/ND), sent to 765
F000:ED33  E83801          call   sub_EE6E                    ; send 2nd SPECIFY byte
F000:ED36  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Functions 03h/02h/04h/05h — DMA setup and 765 command code selection.
; sub_F73E programs 8237 channel 2 (mode in AL, address ES:BX, length DH sectors); CF=1 — 64K boundary crossed.
; ----------------------------------------------------------------------------------------------
loc_ED37:    ; xrefs: ECD3
F000:ED37  800E3F0080      or     byte [3Fh], 80h             ; write: 0040:003F bit 7 = write operation
F000:ED3C  B04A            mov    al, 4Ah                     ; DMA mode 4Ah: channel 2, memory read → device
F000:ED3E  E8FD09          call   sub_F73E                    ; set up 8237 DMA (ports 0B/0C/04/05/81/0A)
F000:ED41  B445            mov    ah, 45h                     ; 765 code: 45h — WRITE DATA (MFM)
F000:ED43  EB33            jmp    loc_ED78                    ; to common executor

loc_ED45:    ; xrefs: ECCF
F000:ED45  B046            mov    al, 46h                     ; read: DMA mode 46h — channel 2, device → memory

loc_ED47:    ; xrefs: ED50
F000:ED47  E8F409          call   sub_F73E                    ; set up 8237 DMA
F000:ED4A  B4E6            mov    ah, 0E6h                    ; 765 code: E6h — READ DATA (MT, MFM, SK)
F000:ED4C  EB2A            jmp    loc_ED78                    ; to common executor

loc_ED4E:    ; xrefs: ECD7
F000:ED4E  B042            mov    al, 42h                     ; verify: DMA mode 42h — channel 2, verify (no transfer)
F000:ED50  EBF5            jmp    loc_ED47                    ; then same as read (command E6h)

loc_ED52:    ; xrefs: ECDB
F000:ED52  800E3F0080      or     byte [3Fh], 80h             ; format: 0040:003F bit 7 = disk write
F000:ED57  B04A            mov    al, 4Ah                     ; DMA mode 4Ah: from memory (C,H,R,N field table) to controller
F000:ED59  E8E209          call   sub_F73E                    ; set up 8237 DMA
F000:ED5C  B44D            mov    ah, 4Dh                     ; 765 code: 4Dh — FORMAT TRACK (MFM)
F000:ED5E  EB18            jmp    loc_ED78                    ; to common executor

; ----------------------------------------------------------------------------------------------
; FORMAT TRACK command tail: N, SC, GPL, D from parameter table (bytes 3,4,7,8).
; ----------------------------------------------------------------------------------------------
loc_ED60:    ; xrefs: EDEE
F000:ED60  BB0700          mov    bx, 7                       ; BX=7 → byte 3 (N, sector size), sent to 765
F000:ED63  E80801          call   sub_EE6E                    ; send N
F000:ED66  BB0900          mov    bx, 9                       ; BX=9 → byte 4 (sectors per track)
F000:ED69  E80201          call   sub_EE6E                    ; send SC
F000:ED6C  BB0F00          mov    bx, 0Fh                     ; BX=0Fh → byte 7 (GAP3 length for format)
F000:ED6F  E8FC00          call   sub_EE6E                    ; send GPL
F000:ED72  BB1100          mov    bx, 11h                     ; BX=11h → byte 8 (fill byte)
F000:ED75  E99E00          jmp    loc_EE16                    ; send D and wait for completion (common part)

; ----------------------------------------------------------------------------------------------
; Common read/write/verify/format executor.
; Input: CF from DMA setup, AH = 765 command code, DH = sector count, CH/CL/[bp+1]/DL = C/R/H/drive.
; Turns on motor (DOR), seeks head, sends 9 command bytes, waits for IRQ, decodes ST0–ST2.
; ----------------------------------------------------------------------------------------------
loc_ED78:    ; xrefs: ED43 ED4C ED5E
F000:ED78  7308            jae    loc_ED82                    ; DMA does not cross 64K boundary → proceed
F000:ED7A  C606410009      mov    byte [41h], 9               ; status 9 — DMA crossed 64K boundary
F000:ED7F  2AC0            sub    al, al                      ; AL = 0 sectors transferred
F000:ED81  C3              ret                                ; return

loc_ED82:    ; xrefs: ED78
F000:ED82  50              push   ax                          ; save AX (AH = 765 command)
F000:ED83  51              push   cx                          ; save CX (cylinder/sector)
F000:ED84  8ACA            mov    cl, dl                      ; CL = drive number
F000:ED86  B001            mov    al, 1                       ; motor bit mask …
F000:ED88  D2E0            shl    al, cl                      ; … 1 << drive
F000:ED8A  FA              cli                                ; disable interrupts — INT 08 must not turn off the motor
F000:ED8B  C6064000FF      mov    byte [40h], 0FFh            ; 0040:0040 = FFh — maximum motor run-on during operation
F000:ED90  84063F00        test   byte [3Fh], al              ; this drive's motor already on (0040:003F)?
F000:ED94  7531            jne    loc_EDC7                    ; yes → no spin-up delay
F000:ED96  80263F00F0      and    byte [3Fh], 0F0h            ; clear motor bits in 0040:003F (bit 7 "write" preserved)
F000:ED9B  08063F00        or     byte [3Fh], al              ; mark motor as running
F000:ED9F  FB              sti                                ; enable interrupts
F000:EDA0  B010            mov    al, 10h                     ; motor bit in DOR …
F000:EDA2  D2E0            shl    al, cl                      ; … 10h << drive
F000:EDA4  0AC2            or     al, dl                      ; + drive select (bits 0–1)
F000:EDA6  0C0C            or     al, 0Ch                     ; + bit 3 (DMA/IRQ) and bit 2 (no reset)
F000:EDA8  52              push   dx                          ; save DX
F000:EDA9  BAF203          mov    dx, 3F2h                    ; DX = 3F2h — floppy controller DOR
F000:EDAC  EE              out    dx, al                      ; turn on motor and select drive
F000:EDAD  5A              pop    dx                          ; restore DX
F000:EDAE  F6063F0080      test   byte [3Fh], 80h             ; spin-up wait only for write/format (0040:003F bit 7)
F000:EDB3  7412            je     loc_EDC7                    ; read → proceed immediately
F000:EDB5  BB1400          mov    bx, 14h                     ; BX=14h → table byte 10: motor spin-up time (in 1/8 s), not sent to 765
F000:EDB8  E8B300          call   sub_EE6E                    ; AH = spin-up time
F000:EDBB  0AE4            or     ah, ah                      ; zero?

loc_EDBD:    ; xrefs: EDC5
F000:EDBD  7408            je     loc_EDC7                    ; countdown done → proceed
F000:EDBF  2BC9            sub    cx, cx                      ; CX = 0 → 65536 iterations

loc_EDC1:    ; xrefs: EDC1
F000:EDC1  E2FE            loop   loc_EDC1                    ; empty loop ≈ 1/8 s (at "Praktik" clock rate)
F000:EDC3  FECC            dec    ah                          ; next delay unit
F000:EDC5  EBF6            jmp    loc_EDBD                    ; repeat

loc_EDC7:    ; xrefs: ED94 EDB3 EDBD
F000:EDC7  FB              sti                                ; enable interrupts
F000:EDC8  59              pop    cx                          ; restore CX (CH = cylinder, CL = sector)
F000:EDC9  E8DE00          call   sub_EEAA                    ; recalibrate if needed and SEEK to cylinder CH
F000:EDCC  58              pop    ax                          ; AH = 765 command code
F000:EDCD  8AFC            mov    bh, ah                      ; BH = command code (for FORMAT check)
F000:EDCF  B600            mov    dh, 0                       ; DH = 0 (probably a leftover of IBM logic; sector count already accounted for in DMA)
F000:EDD1  724A            jb     loc_EE1D                    ; seek error → decode results
F000:EDD3  BE1DEE          mov    si, 0EE1Dh                  ; emergency return address EE1D …
F000:EDD6  56              push   si                          ; … onto stack: on timeout sub_EE7F drops its own address and returns there
F000:EDD7  E8A500          call   sub_EE7F                    ; send command code to 765
F000:EDDA  8A6601          mov    ah, byte [bp + 1]           ; AH = head number (high byte of saved DX)
F000:EDDD  D0E4            shl    ah, 1                       ; head → bit 2 …
F000:EDDF  D0E4            shl    ah, 1                       ; … (765 HDS/US byte format)
F000:EDE1  80E404          and    ah, 4                       ; keep only head bit
F000:EDE4  0AE2            or     ah, dl                      ; + drive number (US0–US1)
F000:EDE6  E89600          call   sub_EE7F                    ; send 2nd command byte
F000:EDE9  80FF4D          cmp    bh, 4Dh                     ; FORMAT TRACK command?
F000:EDEC  7503            jne    loc_EDF1                    ; no → read/write
F000:EDEE  E96FFF          jmp    loc_ED60                    ; yes → format parameters

loc_EDF1:    ; xrefs: EDEC
F000:EDF1  8AE5            mov    ah, ch                      ; C — cylinder (logical; double-step is not reflected to 765)
F000:EDF3  E88900          call   sub_EE7F                    ; send C
F000:EDF6  8A6601          mov    ah, byte [bp + 1]           ; H — head
F000:EDF9  E88300          call   sub_EE7F                    ; send H
F000:EDFC  8AE1            mov    ah, cl                      ; R — starting sector number
F000:EDFE  E87E00          call   sub_EE7F                    ; send R
F000:EE01  BB0700          mov    bx, 7                       ; BX=7 → table byte 3: N (sector size)
F000:EE04  E86700          call   sub_EE6E                    ; send N
F000:EE07  BB0900          mov    bx, 9                       ; BX=9 → byte 4: EOT (last sector on track)
F000:EE0A  E86100          call   sub_EE6E                    ; send EOT
F000:EE0D  BB0B00          mov    bx, 0Bh                     ; BX=0Bh → byte 5: GPL (gap length)
F000:EE10  E85B00          call   sub_EE6E                    ; send GPL
F000:EE13  BB0D00          mov    bx, 0Dh                     ; BX=0Dh → byte 6: DTL (data length)

loc_EE16:    ; xrefs: ED75
F000:EE16  E85500          call   sub_EE6E                    ; send last command byte (DTL or format D)
F000:EE19  5E              pop    si                          ; remove emergency return address — command sent
F000:EE1A  E8F500          call   sub_EF12                    ; wait for operation-complete IRQ (flag 0040:003E bit 7)

; ----------------------------------------------------------------------------------------------
; Decode 765 results (7 bytes at 0040:0042–0048: ST0,ST1,ST2,C,H,R,N) → BIOS error code.
; ----------------------------------------------------------------------------------------------
loc_EE1D:    ; xrefs: EDD1
F000:EE1D  7245            jb     loc_EE64                    ; error occurred (timeout/seek) → just read results
F000:EE1F  E84301          call   sub_EF65                    ; read 765 result phase into 0040:0042…
F000:EE22  723F            jb     loc_EE63                    ; error reading results → exit
F000:EE24  FC              cld                                ; string operations forward
F000:EE25  BE4200          mov    si, 42h                     ; SI → ST0 (0040:0042)
F000:EE28  AC              lodsb  al, byte [si]               ; AL = ST0
F000:EE29  24C0            and    al, 0C0h                    ; ST0 bits 7–6 — completion code (IC)
F000:EE2B  743B            je     loc_EE68                    ; 00 — normal termination
F000:EE2D  3C40            cmp    al, 40h                     ; 01 — abnormal command termination?
F000:EE2F  7529            jne    loc_EE5A                    ; otherwise (10/11) — controller failure
F000:EE31  AC              lodsb  al, byte [si]               ; AL = ST1
F000:EE32  D0E0            shl    al, 1                       ; ST1 bit 7 — EN (end of cylinder)
F000:EE34  B404            mov    ah, 4                       ; status 4 — sector not found
F000:EE36  7224            jb     loc_EE5C                    ; EN → status 4
F000:EE38  D0E0            shl    al, 1                       ; skip bit 6 (unused)
F000:EE3A  D0E0            shl    al, 1                       ; ST1 bit 5 — DE (CRC error)
F000:EE3C  B410            mov    ah, 10h                     ; status 10h — CRC error
F000:EE3E  721C            jb     loc_EE5C                    ; DE → 10h
F000:EE40  D0E0            shl    al, 1                       ; ST1 bit 4 — OR (DMA overrun/underrun)
F000:EE42  B408            mov    ah, 8                       ; status 8 — DMA overrun
F000:EE44  7216            jb     loc_EE5C                    ; OR → 8
F000:EE46  D0E0            shl    al, 1                       ; skip bit 3
F000:EE48  D0E0            shl    al, 1                       ; ST1 bit 2 — ND (no data/sector not found)
F000:EE4A  B404            mov    ah, 4                       ; status 4
F000:EE4C  720E            jb     loc_EE5C                    ; ND → 4
F000:EE4E  D0E0            shl    al, 1                       ; ST1 bit 1 — NW (write protected)
F000:EE50  B403            mov    ah, 3                       ; status 3 — disk write-protected
F000:EE52  7208            jb     loc_EE5C                    ; NW → 3
F000:EE54  D0E0            shl    al, 1                       ; ST1 bit 0 — MA (missing address mark)
F000:EE56  B402            mov    ah, 2                       ; status 2 — address mark not found
F000:EE58  7202            jb     loc_EE5C                    ; MA → 2

loc_EE5A:    ; xrefs: EE2F
F000:EE5A  B420            mov    ah, 20h                     ; cause not recognized → status 20h (controller failure)

loc_EE5C:    ; xrefs: EE36 EE3E EE44 EE4C EE52 EE58
F000:EE5C  08264100        or     byte [41h], ah              ; OR error code into status 0040:0041
F000:EE60  E84701          call   sub_EFAA                    ; AL = sectors processed

loc_EE63:    ; xrefs: EE22
F000:EE63  C3              ret                                ; return

loc_EE64:    ; xrefs: EE1D
F000:EE64  E8FE00          call   sub_EF65                    ; after an error still fetch results from 765 (flush its result phase)
F000:EE67  C3              ret                                ; return

loc_EE68:    ; xrefs: EE2B
F000:EE68  E83F01          call   sub_EFAA                    ; success: AL = sectors processed
F000:EE6B  32E4            xor    ah, ah                      ; AH = 0
F000:EE6D  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_EE6E — fetch floppy parameter table byte (INT 1Eh vector, 0000:0078).
; Input: BX = index*2 + flag; low bit = 1 → byte is also sent to 765 (tail jump into sub_EE7F).
; Output: AH = parameter byte. Clobbers AX, SI.
; ----------------------------------------------------------------------------------------------
sub_EE6E:    ; xrefs: EC6C ED2D ED33 ED63 ED69 ED6F EDB8 EE04 EE0A EE10 EE16 EEFE EFB7 F76A
F000:EE6E  1E              push   ds                          ; save DS
F000:EE6F  2BC0            sub    ax, ax                      ; AX = 0 …
F000:EE71  8ED8            mov    ds, ax                      ; … DS = 0 (vector table)
F000:EE73  C5367800        lds    si, [78h]                   ; DS:SI = INT 1Eh pointer — floppy parameter table
F000:EE77  D1EB            shr    bx, 1                       ; BX = byte index, CF = "send to controller" flag
F000:EE79  8A20            mov    ah, byte [bx + si]          ; AH = parameter
F000:EE7B  1F              pop    ds                          ; restore DS = 0040h
F000:EE7C  7201            jb     sub_EE7F                    ; flag set → send AH to 765
F000:EE7E  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_EE7F — send byte AH to 765 data register (3F5h).
; Waits in MSR (3F4h) for DIO=0 (bit 6) and RQM=1 (bit 7). Ports are emulated by the NMI handler (FDC 765).
; Timeout: status 80h, drops its own return address and returns one level up with CF=1.
; ----------------------------------------------------------------------------------------------
sub_EE7F:    ; xrefs: ED27 EDD7 EDE6 EDF3 EDF9 EDFE EE7C EEBE EEC3 EECB EED0 EEDA EEDF EEF4 EF3D
F000:EE7F  52              push   dx                          ; save DX
F000:EE80  51              push   cx                          ; save CX
F000:EE81  BAF403          mov    dx, 3F4h                    ; DX = 3F4h — 765 main status register (MSR)
F000:EE84  33C9            xor    cx, cx                      ; timeout 65536 polls

loc_EE86:    ; xrefs: EE8B
F000:EE86  EC              in     al, dx                      ; read MSR
F000:EE87  A840            test   al, 40h                     ; bit 6 DIO: 0 = direction CPU → controller
F000:EE89  740C            je     loc_EE97                    ; ready to accept → wait for RQM
F000:EE8B  E2F9            loop   loc_EE86                    ; wait

loc_EE8D:    ; xrefs: EEA0
F000:EE8D  800E410080      or     byte [41h], 80h             ; timeout: status 80h — drive not responding
F000:EE92  59              pop    cx                          ; restore CX
F000:EE93  5A              pop    dx                          ; restore DX
F000:EE94  58              pop    ax                          ; drop return address — return straight to the caller one level up
F000:EE95  F9              stc                                ; CF = 1 — error
F000:EE96  C3              ret                                ; return (to emergency address, e.g. EE1D)

loc_EE97:    ; xrefs: EE89
F000:EE97  33C9            xor    cx, cx                      ; timeout 65536 polls

loc_EE99:    ; xrefs: EE9E
F000:EE99  EC              in     al, dx                      ; read MSR
F000:EE9A  A880            test   al, 80h                     ; bit 7 RQM — data register ready
F000:EE9C  7504            jne    loc_EEA2                    ; ready → send byte
F000:EE9E  E2F9            loop   loc_EE99                    ; wait
F000:EEA0  EBEB            jmp    loc_EE8D                    ; timeout

loc_EEA2:    ; xrefs: EE9C
F000:EEA2  8AC4            mov    al, ah                      ; AL = byte to send
F000:EEA4  B2F5            mov    dl, 0F5h                    ; DX = 3F5h — 765 data register
F000:EEA6  EE              out    dx, al                      ; write command/parameter byte to 765
F000:EEA7  59              pop    cx                          ; restore CX
F000:EEA8  5A              pop    dx                          ; restore DX
F000:EEA9  C3              ret                                ; return, CF=0

; ----------------------------------------------------------------------------------------------
; sub_EEAA — seek drive DL head to cylinder CH.
; On first access (drive bit in 0040:003E = 0) — RECALIBRATE twice (probably to make sure
; track 0 is reached on an 80-track drive: 765 issues at most 77 steps). Then SEEK.
; For disks without the "80 tracks" flag (bits 4–5 of 0040:003E) the cylinder is doubled (double-step).
; Output: CF=1 on error. Also called from POST (E3EE/E3F5).
; ----------------------------------------------------------------------------------------------
sub_EEAA:    ; xrefs: E3EE E3F5 EDC9
F000:EEAA  B001            mov    al, 1                       ; "calibrated" bit mask …
F000:EEAC  51              push   cx                          ; save CX
F000:EEAD  8ACA            mov    cl, dl                      ; CL = drive
F000:EEAF  D2C0            rol    al, cl                      ; … 1 << drive
F000:EEB1  59              pop    cx                          ; restore CX
F000:EEB2  84063E00        test   byte [3Eh], al              ; drive already recalibrated (0040:003E bits 0–1)?
F000:EEB6  7520            jne    loc_EED8                    ; yes → SEEK right away
F000:EEB8  08063E00        or     byte [3Eh], al              ; mark as recalibrated
F000:EEBC  B407            mov    ah, 7                       ; command 07h RECALIBRATE
F000:EEBE  E8BEFF          call   sub_EE7F                    ; send to 765
F000:EEC1  8AE2            mov    ah, dl                      ; drive number
F000:EEC3  E8B9FF          call   sub_EE7F                    ; send
F000:EEC6  E86D00          call   sub_EF36                    ; wait for IRQ and SENSE INTERRUPT (result ignored — repeated below)
F000:EEC9  B407            mov    ah, 7                       ; second RECALIBRATE (07h)
F000:EECB  E8B1FF          call   sub_EE7F                    ; send to 765
F000:EECE  8AE2            mov    ah, dl                      ; drive number
F000:EED0  E8ACFF          call   sub_EE7F                    ; send
F000:EED3  E86000          call   sub_EF36                    ; wait for IRQ and check result
F000:EED6  7239            jb     loc_EF11                    ; recalibrate error → exit with CF=1

loc_EED8:    ; xrefs: EEB6
F000:EED8  B40F            mov    ah, 0Fh                     ; command 0Fh SEEK
F000:EEDA  E8A2FF          call   sub_EE7F                    ; send to 765
F000:EEDD  8AE2            mov    ah, dl                      ; drive number (head 0)
F000:EEDF  E89DFF          call   sub_EE7F                    ; send
F000:EEE2  B010            mov    al, 10h                     ; "80 tracks" mask …
F000:EEE4  51              push   cx                          ; save CX
F000:EEE5  8ACA            mov    cl, dl                      ; CL = drive
F000:EEE7  D2C0            rol    al, cl                      ; … 10h << drive
F000:EEE9  59              pop    cx                          ; restore CX
F000:EEEA  84063E00        test   byte [3Eh], al              ; 80-track mode (0040:003E bit 4/5)?
F000:EEEE  8AE5            mov    ah, ch                      ; AH = cylinder
F000:EEF0  7502            jne    loc_EEF4                    ; yes → physical track = cylinder
F000:EEF2  02E4            add    ah, ah                      ; no → double-step: physical track = 2*cylinder (40-track disk in 80-track drive)

loc_EEF4:    ; xrefs: EEF0
F000:EEF4  E888FF          call   sub_EE7F                    ; send track number
F000:EEF7  E83C00          call   sub_EF36                    ; wait for IRQ and SENSE INTERRUPT; CF = seek error
F000:EEFA  9C              pushf                              ; save result CF
F000:EEFB  BB1200          mov    bx, 12h                     ; BX=12h → table byte 9: head settle time (ms), not sent
F000:EEFE  E86DFF          call   sub_EE6E                    ; AH = settle time
F000:EF01  51              push   cx                          ; save CX

loc_EF02:    ; xrefs: EF0D
F000:EF02  B92602          mov    cx, 226h                    ; ≈ 1 ms delay (550 iterations)
F000:EF05  0AE4            or     ah, ah                      ; countdown done?
F000:EF07  7406            je     loc_EF0F                    ; yes → exit

loc_EF09:    ; xrefs: EF09
F000:EF09  E2FE            loop   loc_EF09                    ; empty loop ≈ 1 ms
F000:EF0B  FECC            dec    ah                          ; next millisecond
F000:EF0D  EBF3            jmp    loc_EF02                    ; repeat

loc_EF0F:    ; xrefs: EF07
F000:EF0F  59              pop    cx                          ; restore CX
F000:EF10  9D              popf                               ; restore SEEK result CF

loc_EF11:    ; xrefs: EED6
F000:EF11  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_EF12 — wait for floppy interrupt: poll flag 0040:003E bit 7 (set by INT 0Eh).
; Timeout ~2*65536 polls → status 80h, CF=1. Flag is cleared.
; ----------------------------------------------------------------------------------------------
sub_EF12:    ; xrefs: EE1A EF36
F000:EF12  FB              sti                                ; enable interrupts (otherwise IRQ never arrives)
F000:EF13  53              push   bx                          ; save BX
F000:EF14  51              push   cx                          ; save CX
F000:EF15  B302            mov    bl, 2                       ; BL = 2 outer loops
F000:EF17  33C9            xor    cx, cx                      ; CX = 65536 polls

loc_EF19:    ; xrefs: EF20 EF24
F000:EF19  F6063E0080      test   byte [3Eh], 80h             ; "floppy interrupt occurred" flag (0040:003E bit 7)?
F000:EF1E  750C            jne    loc_EF2C                    ; yes → exit with CF=0
F000:EF20  E2F7            loop   loc_EF19                    ; wait
F000:EF22  FECB            dec    bl                          ; outer counter
F000:EF24  75F3            jne    loc_EF19                    ; repeat
F000:EF26  800E410080      or     byte [41h], 80h             ; timeout: status 80h
F000:EF2B  F9              stc                                ; CF = 1

loc_EF2C:    ; xrefs: EF1E
F000:EF2C  9C              pushf                              ; save CF
F000:EF2D  80263E007F      and    byte [3Eh], 7Fh             ; clear interrupt flag 0040:003E bit 7
F000:EF32  9D              popf                               ; restore CF
F000:EF33  59              pop    cx                          ; restore CX
F000:EF34  5B              pop    bx                          ; restore BX
F000:EF35  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_EF36 — wait for IRQ + SENSE INTERRUPT STATUS (08h) and check ST0.
; ST0 bits 5–6 = 11 (SEEK END + abnormal termination) → status 40h "seek error", CF=1.
; ----------------------------------------------------------------------------------------------
sub_EF36:    ; xrefs: ED15 EEC6 EED3 EEF7
F000:EF36  E8D9FF          call   sub_EF12                    ; wait for floppy interrupt
F000:EF39  7214            jb     loc_EF4F                    ; timeout → CF=1
F000:EF3B  B408            mov    ah, 8                       ; command 08h SENSE INTERRUPT STATUS
F000:EF3D  E83FFF          call   sub_EE7F                    ; send to 765
F000:EF40  E82200          call   sub_EF65                    ; read ST0 and PCN into 0040:0042…
F000:EF43  720A            jb     loc_EF4F                    ; error → CF=1
F000:EF45  A04200          mov    al, byte [42h]              ; AL = ST0
F000:EF48  2460            and    al, 60h                     ; bits 6 (abnormal termination) and 5 (SEEK END)
F000:EF4A  3C60            cmp    al, 60h                     ; both set — seek failed?
F000:EF4C  7402            je     loc_EF50                    ; yes → status 40h
F000:EF4E  F8              clc                                ; CF = 0 — success

loc_EF4F:    ; xrefs: EF39 EF43
F000:EF4F  C3              ret                                ; return

loc_EF50:    ; xrefs: EF4C
F000:EF50  800E410040      or     byte [41h], 40h             ; status 40h — seek error
F000:EF55  F9              stc                                ; CF = 1
F000:EF56  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; INT 0Eh — floppy interrupt (standard entry point F000:EF57).
; Called from common handler F400:0400 by a bit in F000:0200. Sets flag 0040:003E bit 7.
; Unlike IBM, no EOI is sent to port 20h — the common handler probably does the acknowledge.
; ----------------------------------------------------------------------------------------------
INT0E_DISKETTE_IRQ:
F000:EF57  FB              sti                                ; enable interrupts
F000:EF58  1E              push   ds                          ; save DS
F000:EF59  50              push   ax                          ; save AX
F000:EF5A  E88C0F          call   sub_FEE9                    ; DS = 0040h
F000:EF5D  800E3E0080      or     byte [3Eh], 80h             ; 0040:003E bit 7 = "floppy interrupt received" (awaited by sub_EF12)
F000:EF62  58              pop    ax                          ; restore AX
F000:EF63  1F              pop    ds                          ; restore DS
F000:EF64  CF              iret                               ; return from interrupt

; ----------------------------------------------------------------------------------------------
; sub_EF65 — receive result bytes from floppy controller (NEC 765 result phase).
; Reads up to 7 bytes from data port 3F5 into 0040:0042–0048 (ST0,ST1,ST2,C,H,R,N), polling MSR (3F4).
; Output: CF=0 — success; CF=1 — error, 0040:0041 gets bit 80h (timeout) or 20h (controller failure).
; Preserves CX, DX, BX; DS=0040. Ports 3F4/3F5 are emulated via NMI (765 emulation).
; Called after read/write operations (EE1F, EE64) and after Sense Interrupt Status (EF40).
; ----------------------------------------------------------------------------------------------
sub_EF65:    ; xrefs: EE1F EE64 EF40
F000:EF65  FC              cld                                ; string operations forward
F000:EF66  BF4200          mov    di, 42h                     ; DI → 0040:0042 — floppy controller status byte buffer (NEC_STATUS)
F000:EF69  51              push   cx                          ; Save CX
F000:EF6A  52              push   dx                          ; Save DX
F000:EF6B  53              push   bx                          ; save BX
F000:EF6C  B307            mov    bl, 7                       ; BL = 7 — maximum number of 765 result bytes

; ----------------------------------------------------------------------------------------------
; loop receiving next result byte
; ----------------------------------------------------------------------------------------------
loc_EF6E:    ; xrefs: EFA2
F000:EF6E  33C9            xor    cx, cx                      ; CX = 0 → wait counter of 65536 polls
F000:EF70  BAF403          mov    dx, 3F4h                    ; DX = 3F4h — 765 main status register (MSR)

loc_EF73:    ; xrefs: EF78
F000:EF73  EC              in     al, dx                      ; read MSR (access to 3F4 is trapped by NMI and emulated)
F000:EF74  A880            test   al, 80h                     ; MSR bit 7 = RQM: controller ready for data transfer?
F000:EF76  750C            jne    loc_EF84                    ; ready — go check direction
F000:EF78  E2F9            loop   loc_EF73                    ; not ready — keep polling until CX runs out
F000:EF7A  800E410080      or     byte [41h], 80h             ; 0040:0041 (DISKETTE_STATUS) |= 80h — "timeout, drive not responding" error

; ----------------------------------------------------------------------------------------------
; error exit: CF=1, restore registers
; ----------------------------------------------------------------------------------------------
loc_EF7F:    ; xrefs: EF8E
F000:EF7F  F9              stc                                ; CF=1 — error flag for the caller
F000:EF80  5B              pop    bx                          ; Restore BX
F000:EF81  5A              pop    dx                          ; Restore DX
F000:EF82  59              pop    cx                          ; Restore CX
F000:EF83  C3              ret                                ; return with CF=1

loc_EF84:    ; xrefs: EF76
F000:EF84  EC              in     al, dx                      ; read MSR again
F000:EF85  A840            test   al, 40h                     ; MSR bit 6 = DIO: 1 — data flows controller → CPU
F000:EF87  7507            jne    loc_EF90                    ; direction correct — read result byte

loc_EF89:    ; xrefs: EFA4
F000:EF89  800E410020      or     byte [41h], 20h             ; 0040:0041 |= 20h — "floppy controller failure" (wrong direction/extra bytes)
F000:EF8E  EBEF            jmp    loc_EF7F                    ; go to exit with CF=1

loc_EF90:    ; xrefs: EF87
F000:EF90  42              inc    dx                          ; DX = 3F5h — 765 data register
F000:EF91  EC              in     al, dx                      ; read next result byte (ST0/ST1/ST2/C/H/R/N)
F000:EF92  8805            mov    byte [di], al               ; store it at 0040:0042+n
F000:EF94  47              inc    di                          ; next status buffer slot
F000:EF95  B90A00          mov    cx, 0Ah                     ; short pause ~10 iterations — let the controller update MSR

loc_EF98:    ; xrefs: EF98
F000:EF98  E2FE            loop   loc_EF98                    ; Delay loop
F000:EF9A  4A              dec    dx                          ; DX = 3F4h — MSR again
F000:EF9B  EC              in     al, dx                      ; read MSR
F000:EF9C  A810            test   al, 10h                     ; MSR bit 4 = CB (controller busy): 0 — result phase finished
F000:EF9E  7406            je     loc_EFA6                    ; all bytes read — successful exit (CF=0 after test)
F000:EFA0  FECB            dec    bl                          ; decrement allowed byte count
F000:EFA2  75CA            jne    loc_EF6E                    ; more allowed — receive next byte
F000:EFA4  EBE3            jmp    loc_EF89                    ; more than 7 bytes — controller misbehaving → error 20h

; ----------------------------------------------------------------------------------------------
; successful exit: CF=0
; ----------------------------------------------------------------------------------------------
loc_EFA6:    ; xrefs: EF9E
F000:EFA6  5B              pop    bx                          ; Restore BX
F000:EFA7  5A              pop    dx                          ; Restore DX
F000:EFA8  59              pop    cx                          ; Restore CX
F000:EFA9  C3              ret                                ; return, CF=0

; ----------------------------------------------------------------------------------------------
; sub_EFAA — count sectors actually transferred after an INT 13h operation.
; Input: CH = requested cylinder, CL = starting sector; DS=0040, result bytes at 0040:0042–0048.
; If the controller stayed on the same cylinder: AL = R(next sector) − CL;
; otherwise (ran past end of track): AL = EOT+1 − CL (EOT from INT 1Eh parameter table).
; Output: AL = sector count; clobbers AH, BX.
; ----------------------------------------------------------------------------------------------
sub_EFAA:    ; xrefs: EE60 EE68
F000:EFAA  A04500          mov    al, byte [45h]              ; AL = 0040:0045 — cylinder (C) from 765 result bytes
F000:EFAD  3AC5            cmp    al, ch                      ; matches requested cylinder CH?
F000:EFAF  A04700          mov    al, byte [47h]              ; AL = 0040:0047 — sector number (R) where the controller stopped
F000:EFB2  740A            je     loc_EFBE                    ; same cylinder — count from R
F000:EFB4  BB0800          mov    bx, 8                       ; BX = 8 → floppy parameter table byte 4 (EOT, sectors per track), not sent to FDC
F000:EFB7  E8B4FE          call   sub_EE6E                    ; AH = parameter from INT 1Eh table (sub_EE6E)
F000:EFBA  8AC4            mov    al, ah                      ; AL = last sector of track (EOT)
F000:EFBC  FEC0            inc    al                          ; AL = EOT+1 — "next" after the last

loc_EFBE:    ; xrefs: EFB2
F000:EFBE  2AC1            sub    al, cl                      ; AL = next sector number − starting sector = sectors transferred
F000:EFC0  C3              ret                                ; Return
F000:EFC1  000000000000    db     00h,00h,00h,00h,00h,00h     ; zero padding up to fixed table address F000:EFC7 (as in IBM PC/XT)

; ----------------------------------------------------------------------------------------------
; diskette_params — floppy parameter table (INT 1Eh vector points here), 11 bytes as in IBM.
; ----------------------------------------------------------------------------------------------
diskette_params:    ; xrefs: E6FC
F000:EFC7  EF022502082A…   db     0EFh,02h,25h,02h,08h,2Ah,0FFh,50h ; DPT: EFh=SRT E/HUT F; 02h=HLT 1, DMA mode; 25h=motor-off delay (ticks); 02h=512 B/sector; 08h=EOT 8 sect/track; 2Ah=GAP; FFh=DTL; 50h=format GAP
F000:EFCF  F60504          db     0F6h,05h,04h                ; DPT: F6h=format fill byte; 05h=head settle (ms); 04h=motor spin-up (1/8 s)

; ----------------------------------------------------------------------------------------------
; INT17_PRINTER — printer service (standard IBM entry point F000:EFD2).
; Input: AH=0 — print character AL, AH=1 — initialize, AH=2 — read status; DX = printer number (0–2).
; Output: AH = printer status (bits as in IBM: 80h not busy, 40h ACK, 20h out of paper, 10h selected, 08h error, 01h timeout).
; Base port taken from 0040:0008+2*DX, timeout from 0040:0078+DX. Ports 378–37A are emulated via NMI (LPT emulation).
; ----------------------------------------------------------------------------------------------
INT17_PRINTER:
F000:EFD2  FB              sti                                ; Enable interrupts
F000:EFD3  1E              push   ds                          ; Save DS
F000:EFD4  52              push   dx                          ; Save DX
F000:EFD5  56              push   si                          ; Save SI
F000:EFD6  51              push   cx                          ; Save CX
F000:EFD7  53              push   bx                          ; save BX
F000:EFD8  E80E0F          call   sub_FEE9                    ; DS = 0040h — BIOS data area
F000:EFDB  8BF2            mov    si, dx                      ; SI = printer number
F000:EFDD  8A5C78          mov    bl, byte [si + 78h]         ; BL = 0040:0078+n — timeout counter for printer n (outer loops of 65536)
F000:EFE0  D1E6            shl    si, 1                       ; SI = n*2 — index into LPT address word table
F000:EFE2  8B5408          mov    dx, word [si + 8]           ; DX = 0040:0008+2n — LPTn base port (usually 378h)
F000:EFE5  0BD2            or     dx, dx                      ; port address zero?
F000:EFE7  740C            je     loc_EFF5                    ; no printer — exit, AH unchanged
F000:EFE9  0AE4            or     ah, ah                      ; AH = 0?
F000:EFEB  740E            je     loc_EFFB                    ; function 0 — output character
F000:EFED  FECC            dec    ah                          ; AH−1
F000:EFEF  743F            je     loc_F030                    ; function 1 — initialize printer
F000:EFF1  FECC            dec    ah                          ; AH−1
F000:EFF3  7428            je     loc_F01D                    ; function 2 — read status

; ----------------------------------------------------------------------------------------------
; common INT 17h exit (also for invalid function)
; ----------------------------------------------------------------------------------------------
loc_EFF5:    ; xrefs: EFE7 F02E
F000:EFF5  5B              pop    bx                          ; Restore BX
F000:EFF6  59              pop    cx                          ; Restore CX
F000:EFF7  5E              pop    si                          ; Restore SI
F000:EFF8  5A              pop    dx                          ; Restore DX
F000:EFF9  1F              pop    ds                          ; Restore DS
F000:EFFA  CF              iret                               ; return from INT 17h

; ----------------------------------------------------------------------------------------------
; AH=0: output character AL to data port and wait for ready (BUSY#)
; ----------------------------------------------------------------------------------------------
loc_EFFB:    ; xrefs: EFEB
F000:EFFB  50              push   ax                          ; save AX (character needed to return in AL)
F000:EFFC  EE              out    dx, al                      ; output character to LPT data register (378h)
F000:EFFD  42              inc    dx                          ; DX = base+1 — LPT status register (379h)

loc_EFFE:    ; xrefs: F00B
F000:EFFE  2BC9            sub    cx, cx                      ; CX = 0 → 65536 polls in inner loop

loc_F000:    ; xrefs: F007
F000:F000  EC              in     al, dx                      ; read printer status register
F000:F001  8AE0            mov    ah, al                      ; AH = copy of status (returned on timeout)
F000:F003  A880            test   al, 80h                     ; bit 7 = BUSY# (1 — printer not busy)
F000:F005  750E            jne    loc_F015                    ; not busy — issue strobe
F000:F007  E2F7            loop   loc_F000                    ; inner wait loop
F000:F009  FECB            dec    bl                          ; outer timeout counter from 0040:0078
F000:F00B  75F1            jne    loc_EFFE                    ; not exhausted yet — keep waiting
F000:F00D  80CC01          or     ah, 1                       ; timeout: set status bit 0
F000:F010  80E4F9          and    ah, 0F9h                    ; clear unused bits 1–2
F000:F013  EB13            jmp    loc_F028                    ; to result formatting

; ----------------------------------------------------------------------------------------------
; strobe: pulse bit 0 of control register (37Ah)
; ----------------------------------------------------------------------------------------------
loc_F015:    ; xrefs: F005
F000:F015  B00D            mov    al, 0Dh                     ; AL = 0Dh: STROBE=1, INIT#=1, SELECT IN=1
F000:F017  42              inc    dx                          ; DX = base+2 — LPT control register (37Ah)
F000:F018  EE              out    dx, al                      ; raise strobe
F000:F019  B00C            mov    al, 0Ch                     ; AL = 0Ch: STROBE=0, INIT#=1, SELECT IN=1 (idle state)
F000:F01B  EE              out    dx, al                      ; drop strobe — character sent
F000:F01C  58              pop    ax                          ; restore AX (character), then read status

; ----------------------------------------------------------------------------------------------
; AH=2: read printer status
; ----------------------------------------------------------------------------------------------
loc_F01D:    ; xrefs: EFF3
F000:F01D  50              push   ax                          ; save AX (AL returned unchanged)

loc_F01E:    ; xrefs: F03F
F000:F01E  8B5408          mov    dx, word [si + 8]           ; DX = LPTn base port
F000:F021  42              inc    dx                          ; DX = status register (379h)
F000:F022  EC              in     al, dx                      ; read printer status
F000:F023  8AE0            mov    ah, al                      ; AH = status
F000:F025  80E4F8          and    ah, 0F8h                    ; keep only significant bits 3–7

; ----------------------------------------------------------------------------------------------
; build returned status code
; ----------------------------------------------------------------------------------------------
loc_F028:    ; xrefs: F013
F000:F028  5A              pop    dx                          ; DX = saved AX (DL = original AL)
F000:F029  8AC2            mov    al, dl                      ; AL = caller's original character/AL
F000:F02B  80F448          xor    ah, 48h                     ; invert bits 6 (ACK) and 3 (ERROR) — match IBM BIOS logic
F000:F02E  EBC5            jmp    loc_EFF5                    ; to common exit

; ----------------------------------------------------------------------------------------------
; AH=1: initialize printer — INIT# pulse on control register
; ----------------------------------------------------------------------------------------------
loc_F030:    ; xrefs: EFEF
F000:F030  50              push   ax                          ; Save AX
F000:F031  42              inc    dx                          ; DX = base+1
F000:F032  42              inc    dx                          ; DX = base+2 — control register (37Ah)
F000:F033  B008            mov    al, 8                       ; AL = 08h: SELECT IN=1, INIT#=0 — printer reset
F000:F035  EE              out    dx, al                      ; assert INIT#
F000:F036  B8E803          mov    ax, 3E8h                    ; delay counter 1000 iterations (reset pulse width)

loc_F039:    ; xrefs: F03A
F000:F039  48              dec    ax                          ; Delay loop
F000:F03A  75FD            jne    loc_F039                    ; wait
F000:F03C  B00C            mov    al, 0Ch                     ; AL = 0Ch: deassert INIT#, SELECT IN=1
F000:F03E  EE              out    dx, al                      ; end reset pulse
F000:F03F  EBDD            jmp    loc_F01E                    ; read and return printer status
F000:F041  00000000        db     00h,00h,00h,00h             ; zero padding up to fixed address F000:F045

; ----------------------------------------------------------------------------------------------
; int10_func_table — INT 10h function handler address table (AH=00h..0Fh), 16 words.
; ----------------------------------------------------------------------------------------------
int10_func_table:    ; xrefs: F08D
F000:F045  FCF0            dw     int10_00_set_mode           ; AH=00h — set video mode
F000:F047  C1F1            dw     int10_01_set_cursor_type    ; AH=01h — set cursor shape
F000:F049  E2F1            dw     int10_02_set_cursor_pos     ; AH=02h — set cursor position
F000:F04B  1CF2            dw     int10_03_read_cursor_pos    ; AH=03h — read cursor position and shape
F000:F04D  B9F1            dw     int10_04_read_lightpen      ; AH=04h — light pen (not supported, returns immediately)
F000:F04F  FAF1            dw     int10_05_select_page        ; AH=05h — select active display page
F000:F051  75F2            dw     int10_06_scroll_up          ; AH=06h — scroll window up
F000:F053  F8F2            dw     int10_07_scroll_down        ; AH=07h — scroll window down
F000:F055  34F3            dw     int10_08_read_char_attr     ; AH=08h — read character and attribute at cursor
F000:F057  67F3            dw     int10_09_write_char_attr    ; AH=09h — write character with attribute
F000:F059  85F3            dw     int10_0A_write_char         ; AH=0Ah — write character only
F000:F05B  31F2            dw     int10_0B_set_palette        ; AH=0Bh — set palette/background color
F000:F05D  B3F3            dw     int10_0C_write_pixel        ; AH=0Ch — write pixel
F000:F05F  A2F3            dw     int10_0D_read_pixel         ; AH=0Dh — read pixel
F000:F061  9BF6            dw     int10_0E_write_tty          ; AH=0Eh — teletype output
F000:F063  53F2            dw     int10_0F_get_mode           ; AH=0Fh — get current video mode

; ----------------------------------------------------------------------------------------------
; INT10_VIDEO — BIOS video service (standard IBM entry point F000:F065).
; Saves ES,DS,DX,CX,BX,SI,DI; AX is popped before jumping to the handler.
; On handler entry: DS=0040, ES=B800 (CGA video memory), AL = original AL, AH = current mode (0040:0049),
; SI = 2*function. Functions ≥10h are ignored. All handlers exit via common epilogue F1B9.
; ----------------------------------------------------------------------------------------------
INT10_VIDEO:
F000:F065  FB              sti                                ; Enable interrupts
F000:F066  FC              cld                                ; string operations forward
F000:F067  06              push   es                          ; save ES
F000:F068  1E              push   ds                          ; Save DS
F000:F069  52              push   dx                          ; Save DX
F000:F06A  51              push   cx                          ; Save CX
F000:F06B  53              push   bx                          ; save BX
F000:F06C  56              push   si                          ; Save SI
F000:F06D  57              push   di                          ; save DI
F000:F06E  50              push   ax                          ; temporarily save AX
F000:F06F  8AC4            mov    al, ah                      ; AL = function number (AH)
F000:F071  32E4            xor    ah, ah                      ; AX = function number
F000:F073  D1E0            shl    ax, 1                       ; AX = function*2 — word table offset
F000:F075  8BF0            mov    si, ax                      ; SI = index into int10_func_table
F000:F077  3D2000          cmp    ax, 20h                     ; function < 10h?
F000:F07A  7204            jb     loc_F080                    ; yes — execute
F000:F07C  58              pop    ax                          ; no — restore AX
F000:F07D  E93901          jmp    int10_04_read_lightpen      ; and exit doing nothing (unsupported function)

loc_F080:    ; xrefs: F07A
F000:F080  E8660E          call   sub_FEE9                    ; DS = 0040h — BIOS data area
F000:F083  B800B8          mov    ax, 0B800h                  ; AX = B800h — CGA video memory segment
F000:F086  8EC0            mov    es, ax                      ; ES = B800h (also used for mode 7)
F000:F088  58              pop    ax                          ; restore AX (AL — call parameter)
F000:F089  8A264900        mov    ah, byte [49h]              ; AH = 0040:0049 — current video mode
F000:F08D  2EFFA445F0      jmp    word cs:[si - 0FBBh]        ; jump via table: CS:[F045+SI] (−0FBBh ≡ +F045h)

; ----------------------------------------------------------------------------------------------
; sub_F092 — set 6845 hardware cursor to position AX (AH=row, AL=column).
; Address = (position offset + page start 0040:004E)/2 → CRTC registers 0Eh/0Fh via sub_F1CC.
; For the current display page. Clobbers AX, CX, DX.
; ----------------------------------------------------------------------------------------------
sub_F092:    ; xrefs: F1F5 F217
F000:F092  E8CF01          call   sub_F264                    ; AX = byte offset of position (row*columns+column)*2
F000:F095  8BC8            mov    cx, ax                      ; CX = position offset within page
F000:F097  030E4E00        add    cx, word [4Eh]              ; + 0040:004E — active page start offset in video memory
F000:F09B  D1F9            sar    cx, 1                       ; divide by 2 — character cell address for 6845 (char+attribute word)
F000:F09D  B40E            mov    ah, 0Eh                     ; AH = 0Eh — CRTC register "cursor location high" (then 0Fh)
F000:F09F  E82A01          call   sub_F1CC                    ; write CX to 6845 registers 0Eh/0Fh
F000:F0A2  C3              ret                                ; Return
F000:F0A3  00              db     00h                         ; padding up to fixed address F000:F0A4

; ----------------------------------------------------------------------------------------------
; video_params — 6845 video controller parameter table (INT 1Dh vector), 4 blocks of 16 bytes (R0–R15).
; Order as in IBM: 40x25, 80x25, graphics, (mono/mode 7). Horizontal timing values (R0,R2,R3)
; differ from IBM CGA (38/2D/0A, 71/5A/0A) — probably tuned to the "Praktik" scan timing.
; ----------------------------------------------------------------------------------------------
video_params:    ; xrefs: E0EB
F000:F0A4  3F2831041F06…   db     3Fh,28h,31h,04h,1Fh,06h,19h,1Ch ; 40x25 text: R0=3Fh horiz. total, R1=28h (40 displayed), R2=31h sync, R3=04h, R4=1Fh vert. total, R5=06h, R6=19h (25 rows), R7=1Ch
F000:F0AC  020706070000…   db     02h,07h,06h,07h,00h,00h,00h,00h ; 40x25: R8=02h interlace, R9=07h (8 scan lines per char), R10/R11=06/07 cursor, R12–R15=0 (start, cursor position)
F000:F0B4  7F5063081F06…   db     7Fh,50h,63h,08h,1Fh,06h,19h,1Ch ; 80x25 text: R0=7Fh, R1=50h (80 displayed), R2=63h, R3=08h, R4=1Fh, R5=06h, R6=19h, R7=1Ch
F000:F0BC  020706070000…   db     02h,07h,06h,07h,00h,00h,00h,00h ; 80x25: R8=02h, R9=07h, cursor 06–07, R12–R15=0
F000:F0C4  3F2831047F06…   db     3Fh,28h,31h,04h,7Fh,06h,64h,70h ; 320x200 graphics: R0=3Fh, R1=28h, R2=31h, R3=04h, R4=7Fh, R5=06h, R6=64h (100 rows), R7=70h
F000:F0CC  020106070000…   db     02h,01h,06h,07h,00h,00h,00h,00h ; Graphics: R8=02h, R9=01h (2 scan lines per row), cursor 06–07, R12–R15=0
F000:F0D4  7F5063087F06…   db     7Fh,50h,63h,08h,7Fh,06h,64h,70h ; Block 4 (mode 7 in IBM; here graphics parameters for 80 character cells): R0=7Fh, R1=50h, R2=63h, R3=08h, R4=7Fh, R6=64h, R7=70h
F000:F0DC  020106070000…   db     02h,01h,06h,07h,00h,00h,00h,00h ; Block 4: R8=02h, R9=01h, cursor 06–07, R12–R15=0

; ----------------------------------------------------------------------------------------------
; dat_F0E4 — video page sizes in bytes indexed by (mode AND 0Eh) → 0040:004C (words).
; ----------------------------------------------------------------------------------------------
dat_F0E4:    ; xrefs: F194
F000:F0E4  00080010004000  db     00h,08h,00h,10h,00h,40h,00h ; Modes 0/1: 0800h (2 KB, 40x25); 2/3: 1000h (4 KB, 80x25); 4/5: 4000h (16 KB)…
F000:F0EB  40              db     40h                         ; …high byte of the word for modes 6/7: 4000h (16 KB)

; ----------------------------------------------------------------------------------------------
; dat_F0EC — text column count for modes 0–7 → 0040:004A
; ----------------------------------------------------------------------------------------------
dat_F0EC:    ; xrefs: F187
F000:F0EC  282850502828…   db     '((PP((PP'                  ; Columns: 40,40,80,80,40,40,80,80 (28h/50h) for modes 0..7

; ----------------------------------------------------------------------------------------------
; dat_F0F4 — CGA mode register values (port 3D8) for modes 0–7 → 0040:0065
; ----------------------------------------------------------------------------------------------
dat_F0F4:    ; xrefs: F17E
F000:F0F4  2C282D292A2E    db     ',(-)*.'                    ; Modes 0–5: 2Ch,28h,2Dh,29h,2Ah,2Eh (bit0 80 col, bit1 graphics, bit2 b/w, bit3 video on)
F000:F0FA  1E29            db     1Eh,29h                     ; Mode 6: 1Eh (640x200, bit4 high-res); mode 7: 29h (same as 80x25 color)

; ----------------------------------------------------------------------------------------------
; int10_00_set_mode — AH=00h, set video mode AL (0–7, no range check).
; Disables video (3D8←0), programs the 16 6845 registers DIRECTLY via hardware registers F000:0000 (index)
; and F000:0002 (data) from the INT 1Dh table, clears video memory B800, fills 0040:0049–0066,
; enables mode (3D8) and palette (3D9). CRTC address is always 3D4 (no mono adapter).
; ----------------------------------------------------------------------------------------------
int10_00_set_mode:    ; xrefs: F045
F000:F0FC  BAD403          mov    dx, 3D4h                    ; DX = 3D4h — 6845 index register (CRTC address is always color)
F000:F0FF  B300            mov    bl, 0                       ; BL = 0 — mode register value "video off"
F000:F101  8AE0            mov    ah, al                      ; AH = mode number
F000:F103  A24900          mov    byte [49h], al              ; 0040:0049 — current video mode := AL
F000:F106  89166300        mov    word [63h], dx              ; 0040:0063 — CRTC base port := 3D4h
F000:F10A  1E              push   ds                          ; save DS (=0040)
F000:F10B  50              push   ax                          ; save AX (mode)
F000:F10C  52              push   dx                          ; Save DX
F000:F10D  83C204          add    dx, 4                       ; DX = 3D8h — CGA mode register
F000:F110  8AC3            mov    al, bl                      ; AL = 0
F000:F112  EE              out    dx, al                      ; turn off video during reprogramming (NMI emulation of port 3D8)
F000:F113  5A              pop    dx                          ; DX = 3D4h
F000:F114  2BC0            sub    ax, ax                      ; AX = 0
F000:F116  8ED8            mov    ds, ax                      ; DS = 0 — vector table
F000:F118  C51E7400        lds    bx, [74h]                   ; DS:BX = INT 1Dh vector (0000:0074) — 6845 parameter table
F000:F11C  58              pop    ax                          ; AX = mode (in AH)
F000:F11D  B91000          mov    cx, 10h                     ; CX = 16 — parameter block length (R0–R15)
F000:F120  80FC02          cmp    ah, 2                       ; mode < 2 (40x25)?
F000:F123  7210            jb     loc_F135                    ; yes — block 0
F000:F125  03D9            add    bx, cx                      ; otherwise next block (80x25)
F000:F127  80FC04          cmp    ah, 4                       ; mode < 4?
F000:F12A  7209            jb     loc_F135                    ; yes — block 1
F000:F12C  03D9            add    bx, cx                      ; otherwise block 2 (graphics)
F000:F12E  80FC07          cmp    ah, 7                       ; mode < 7?
F000:F131  7202            jb     loc_F135                    ; yes — block 2
F000:F133  03D9            add    bx, cx                      ; mode 7 — block 3

; ----------------------------------------------------------------------------------------------
; load 16 6845 registers via hardware registers F000:0000/0002 (bypassing NMI emulation of 3D4/3D5)
; ----------------------------------------------------------------------------------------------
loc_F135:    ; xrefs: F123 F12A F131
F000:F135  50              push   ax                          ; save mode
F000:F136  32E4            xor    ah, ah                      ; AH = 0 — CRTC register number

loc_F138:    ; xrefs: F147
F000:F138  8AC4            mov    al, ah                      ; AL = register number
F000:F13A  2EA20000        mov    byte cs:[0], al             ; F000:0000 — 6845 hardware index register (CS=F000) := register number
F000:F13E  FEC4            inc    ah                          ; next register number
F000:F140  8A07            mov    al, byte [bx]               ; AL = parameter value from table
F000:F142  2EA20200        mov    byte cs:[2], al             ; F000:0002 — 6845 hardware data register := value
F000:F146  43              inc    bx                          ; next table byte
F000:F147  E2EF            loop   loc_F138                    ; repeat for R0..R15
F000:F149  58              pop    ax                          ; AH = mode
F000:F14A  1F              pop    ds                          ; DS = 0040h
F000:F14B  33FF            xor    di, di                      ; DI = 0 — start of video memory
F000:F14D  893E4E00        mov    word [4Eh], di              ; 0040:004E — active page start offset := 0
F000:F151  C606620000      mov    byte [62h], 0               ; 0040:0062 — active page number := 0
F000:F156  B90020          mov    cx, 2000h                   ; CX = 2000h words = 16 KB — entire CGA video memory
F000:F159  80FC04          cmp    ah, 4                       ; text mode (< 4)?
F000:F15C  720B            jb     loc_F169                    ; yes — fill with spaces
F000:F15E  80FC07          cmp    ah, 7                       ; mode 7?
F000:F161  7404            je     loc_F167                    ; yes — special size
F000:F163  33C0            xor    ax, ax                      ; graphics: fill value 0 (black pixels)
F000:F165  EB05            jmp    loc_F16C                    ; to clearing

loc_F167:    ; xrefs: F161
F000:F167  B508            mov    ch, 8                       ; mode 7: CX = 0800h words (4 KB)

loc_F169:    ; xrefs: F15C
F000:F169  B82007          mov    ax, 720h                    ; text: AX = 0720h — space with attribute 07h (gray on black)

loc_F16C:    ; xrefs: F165
F000:F16C  F3AB            rep stosw word es:[di], ax         ; clear video memory ES:DI (B800:0000)
F000:F16E  C70660000706    mov    word [60h], 607h            ; 0040:0060 — cursor shape := 0607h (lines 6–7)
F000:F174  A04900          mov    al, byte [49h]              ; AL = mode
F000:F177  32E4            xor    ah, ah                      ; AX = mode
F000:F179  8BF0            mov    si, ax                      ; SI = mode index into tables
F000:F17B  BAD803          mov    dx, 3D8h                    ; DX = 3D8h — CGA mode register
F000:F17E  2E8A84F4F0      mov    al, byte cs:[si - 0F0Ch]    ; AL = mode register value from dat_F0F4 (CS:[F0F4+SI])
F000:F183  EE              out    dx, al                      ; enable mode and video (NMI emulation of 3D8; the emulator probably reloads R0–R9 from its own tables)
F000:F184  A26500          mov    byte [65h], al              ; 0040:0065 — CGA mode register copy
F000:F187  2E8A84ECF0      mov    al, byte cs:[si - 0F14h]    ; AL = column count from dat_F0EC
F000:F18C  32E4            xor    ah, ah                      ; AX = columns
F000:F18E  A34A00          mov    word [4Ah], ax              ; 0040:004A — number of screen columns
F000:F191  83E60E          and    si, 0Eh                     ; SI = (mode AND 0Eh) — word index into dat_F0E4
F000:F194  2E8B8CE4F0      mov    cx, word cs:[si - 0F1Ch]    ; CX = page size from dat_F0E4
F000:F199  890E4C00        mov    word [4Ch], cx              ; 0040:004C — video page size in bytes
F000:F19D  B90800          mov    cx, 8                       ; CX = 8 — cursor positions for 8 pages
F000:F1A0  BF5000          mov    di, 50h                     ; DI = 0050h — 0040:0050..005F, cursor positions of pages 0–7
F000:F1A3  1E              push   ds                          ; ES = DS = 0040h
F000:F1A4  07              pop    es                          ; (ES = 0040)
F000:F1A5  33C0            xor    ax, ax                      ; AX = 0 — cursors at (0,0)
F000:F1A7  F3AB            rep stosw word es:[di], ax         ; clear cursor positions
F000:F1A9  42              inc    dx                          ; DX = 3D9h — CGA color select register
F000:F1AA  B030            mov    al, 30h                     ; AL = 30h — palette 1, background intensity, color 0
F000:F1AC  803E490006      cmp    byte [49h], 6               ; mode 6 (640x200)?
F000:F1B1  7502            jne    loc_F1B5                    ; no
F000:F1B3  B03F            mov    al, 3Fh                     ; mode 6: AL = 3Fh — foreground color white (15)

loc_F1B5:    ; xrefs: F1B1
F000:F1B5  EE              out    dx, al                      ; write color register (NMI emulation of 3D9)
F000:F1B6  A26600          mov    byte [66h], al              ; 0040:0066 — CGA palette register copy

; ----------------------------------------------------------------------------------------------
; int10_04_read_lightpen — AH=04h (light pen not supported) and also the common INT 10h epilogue.
; Restores DI,SI,BX,CX,DX,DS,ES; AX is returned as is (for AH=04h: AH = current mode,
; i.e. non-zero — probably a flaw: IBM returns AH=0 "pen not triggered").
; ----------------------------------------------------------------------------------------------
int10_04_read_lightpen:    ; xrefs: F04D F07D F1CA F1F8 F21A F246 F2BA F349 F382 F39F F3B0 F3CF F46B F4CB F54B F5AA …
F000:F1B9  5F              pop    di                          ; restore DI
F000:F1BA  5E              pop    si                          ; Restore SI
F000:F1BB  5B              pop    bx                          ; Restore BX

; ----------------------------------------------------------------------------------------------
; epilogue tail (also used by AH=0Fh, which keeps BX)
; ----------------------------------------------------------------------------------------------
loc_F1BC:    ; xrefs: F261
F000:F1BC  59              pop    cx                          ; Restore CX
F000:F1BD  5A              pop    dx                          ; Restore DX
F000:F1BE  1F              pop    ds                          ; Restore DS
F000:F1BF  07              pop    es                          ; Restore ES
F000:F1C0  CF              iret                               ; return from INT 10h

; ----------------------------------------------------------------------------------------------
; int10_01_set_cursor_type — AH=01h: CH = start, CL = end cursor scan line.
; Saves to 0040:0060 and writes 6845 registers R10/R11.
; ----------------------------------------------------------------------------------------------
int10_01_set_cursor_type:    ; xrefs: F047
F000:F1C1  B40A            mov    ah, 0Ah                     ; AH = 0Ah — CRTC register "cursor start line" (then 0Bh)
F000:F1C3  890E6000        mov    word [60h], cx              ; 0040:0060 — cursor shape := CX
F000:F1C7  E80200          call   sub_F1CC                    ; write CH→R10, CL→R11
F000:F1CA  EBED            jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; sub_F1CC — write a 6845 register pair: AH → CH, AH+1 → CL.
; Via ports 0040:0063 (3D4) and 3D5 — i.e. through NMI CRTC emulation. Clobbers AL, DX.
; ----------------------------------------------------------------------------------------------
sub_F1CC:    ; xrefs: F09F F1C7 F20E
F000:F1CC  8B166300        mov    dx, word [63h]              ; DX = 0040:0063 — CRTC index port (3D4h)
F000:F1D0  8AC4            mov    al, ah                      ; AL = register number
F000:F1D2  EE              out    dx, al                      ; select 6845 register (NMI → emulator stores index at 0040:00B4)
F000:F1D3  42              inc    dx                          ; DX = 3D5h — CRTC data port
F000:F1D4  8AC5            mov    al, ch                      ; AL = high byte of value
F000:F1D6  EE              out    dx, al                      ; write register (NMI → emulator forwards it to F000:0002)
F000:F1D7  4A              dec    dx                          ; DX = 3D4h
F000:F1D8  8AC4            mov    al, ah                      ; AL = register number
F000:F1DA  FEC0            inc    al                          ; next register (AH+1)
F000:F1DC  EE              out    dx, al                      ; select it
F000:F1DD  42              inc    dx                          ; DX = 3D5h
F000:F1DE  8AC1            mov    al, cl                      ; AL = low byte of value
F000:F1E0  EE              out    dx, al                      ; write register
F000:F1E1  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; int10_02_set_cursor_pos — AH=02h: BH = page, DH/DL = row/column.
; Stores position at 0040:0050+2*BH; if the page is active, moves the hardware cursor.
; ----------------------------------------------------------------------------------------------
int10_02_set_cursor_pos:    ; xrefs: F049
F000:F1E2  8ACF            mov    cl, bh                      ; CL = page number
F000:F1E4  32ED            xor    ch, ch                      ; CX = page
F000:F1E6  D1E1            shl    cx, 1                       ; CX = page*2
F000:F1E8  8BF1            mov    si, cx                      ; SI = cursor position word index
F000:F1EA  895450          mov    word [si + 50h], dx         ; 0040:0050+2*page — page cursor position := DX
F000:F1ED  383E6200        cmp    byte [62h], bh              ; page = active page (0040:0062)?
F000:F1F1  7505            jne    loc_F1F8                    ; no — just stored it
F000:F1F3  8BC2            mov    ax, dx                      ; AX = position (AH row, AL column)
F000:F1F5  E89AFE          call   sub_F092                    ; move 6845 hardware cursor

loc_F1F8:    ; xrefs: F1F1
F000:F1F8  EBBF            jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; int10_05_select_page — AH=05h: AL = new active page.
; Computes page start (0040:004E), writes 6845 registers R12/R13 and sets that page's cursor.
; ----------------------------------------------------------------------------------------------
int10_05_select_page:    ; xrefs: F04F
F000:F1FA  A26200          mov    byte [62h], al              ; 0040:0062 — active page := AL
F000:F1FD  8B0E4C00        mov    cx, word [4Ch]              ; CX = 0040:004C — page size in bytes
F000:F201  98              cbw                                ; AX = page number (CBW: extend AL to AX)
F000:F202  50              push   ax                          ; save page number
F000:F203  F7E1            mul    cx                          ; AX = page*size — page start offset
F000:F205  A34E00          mov    word [4Eh], ax              ; 0040:004E — active page start := AX
F000:F208  8BC8            mov    cx, ax                      ; CX = start offset
F000:F20A  D1F9            sar    cx, 1                       ; /2 — start address in character cells for 6845
F000:F20C  B40C            mov    ah, 0Ch                     ; AH = 0Ch — CRTC register "start address high" (then 0Dh)
F000:F20E  E8BBFF          call   sub_F1CC                    ; write R12/R13 — switch displayed page
F000:F211  5B              pop    bx                          ; BX = page number
F000:F212  D1E3            shl    bx, 1                       ; BX = page*2
F000:F214  8B4750          mov    ax, word [bx + 50h]         ; AX = 0040:0050+2*page — this page's cursor position
F000:F217  E878FE          call   sub_F092                    ; set hardware cursor
F000:F21A  EB9D            jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; int10_03_read_cursor_pos — AH=03h: BH = page.
; Output: DX = position (DH row, DL column), CX = cursor shape (0040:0060). Own epilogue.
; ----------------------------------------------------------------------------------------------
int10_03_read_cursor_pos:    ; xrefs: F04B
F000:F21C  8ADF            mov    bl, bh                      ; BL = page
F000:F21E  32FF            xor    bh, bh                      ; BX = page
F000:F220  D1E3            shl    bx, 1                       ; BX = page*2
F000:F222  8B5750          mov    dx, word [bx + 50h]         ; DX = 0040:0050+2*page — cursor position
F000:F225  8B0E6000        mov    cx, word [60h]              ; CX = 0040:0060 — cursor shape
F000:F229  5F              pop    di                          ; restore DI
F000:F22A  5E              pop    si                          ; Restore SI
F000:F22B  5B              pop    bx                          ; Restore BX
F000:F22C  58              pop    ax                          ; discard saved CX (return the new one)
F000:F22D  58              pop    ax                          ; discard saved DX (AX gets the old DX value, as in IBM)
F000:F22E  1F              pop    ds                          ; Restore DS
F000:F22F  07              pop    es                          ; Restore ES
F000:F230  CF              iret                               ; return from INT 10h

; ----------------------------------------------------------------------------------------------
; int10_0B_set_palette — AH=0Bh: BH=0 — background/border color BL (bits 0–4); BH=1 — palette BL bit 0.
; Modifies copy at 0040:0066 and writes CGA color select register 3D9 (NMI emulation).
; ----------------------------------------------------------------------------------------------
int10_0B_set_palette:    ; xrefs: F05B
F000:F231  BAD903          mov    dx, 3D9h                    ; DX = 3D9h — CGA color select register
F000:F234  A06600          mov    al, byte [66h]              ; AL = 0040:0066 — current palette register value
F000:F237  0AFF            or     bh, bh                      ; BH = 0 (background color)?
F000:F239  750E            jne    loc_F249                    ; no — palette select
F000:F23B  24E0            and    al, 0E0h                    ; keep bits 5–7 (palette)
F000:F23D  80E31F          and    bl, 1Fh                     ; BL = color (bits 0–3) + intensity (bit 4)
F000:F240  0AC3            or     al, bl                      ; new background/border color

loc_F242:    ; xrefs: F24D F251
F000:F242  EE              out    dx, al                      ; write register 3D9
F000:F243  A26600          mov    byte [66h], al              ; update copy at 0040:0066
F000:F246  E970FF          jmp    int10_04_read_lightpen      ; exit

loc_F249:    ; xrefs: F239
F000:F249  24DF            and    al, 0DFh                    ; clear bit 5 — palette 0 (green/red/brown)
F000:F24B  D0EB            shr    bl, 1                       ; BL bit 0 → CF
F000:F24D  73F3            jae    loc_F242                    ; palette 0 — write
F000:F24F  0C20            or     al, 20h                     ; palette 1 (cyan/magenta/white) — bit 5
F000:F251  EBEF            jmp    loc_F242                    ; write

; ----------------------------------------------------------------------------------------------
; int10_0F_get_mode — AH=0Fh: output AH = columns (0040:004A), AL = mode (0040:0049), BH = page (0040:0062).
; BX is not restored (BL keeps its input value).
; ----------------------------------------------------------------------------------------------
int10_0F_get_mode:    ; xrefs: F063
F000:F253  8A264A00        mov    ah, byte [4Ah]              ; AH = 0040:004A — number of columns
F000:F257  A04900          mov    al, byte [49h]              ; AL = 0040:0049 — current mode
F000:F25A  8A3E6200        mov    bh, byte [62h]              ; BH = 0040:0062 — active page
F000:F25E  5F              pop    di                          ; restore DI
F000:F25F  5E              pop    si                          ; Restore SI
F000:F260  59              pop    cx                          ; pop saved BX into CX (will be overwritten) — BX is returned new
F000:F261  E958FF          jmp    loc_F1BC                    ; rest of epilogue (CX, DX, DS, ES, IRET)

; ----------------------------------------------------------------------------------------------
; sub_F264 — byte offset of character cell within page: AX = (AH*columns + AL)*2.
; Input: AH = row, AL = column; columns — 0040:004A. BX preserved.
; ----------------------------------------------------------------------------------------------
sub_F264:    ; xrefs: F092 F2C1 F361
F000:F264  53              push   bx                          ; save BX
F000:F265  8BD8            mov    bx, ax                      ; BX = position (BL = column)
F000:F267  8AC4            mov    al, ah                      ; AL = row
F000:F269  F6264A00        mul    byte [4Ah]                  ; AX = row * 0040:004A (columns)
F000:F26D  32FF            xor    bh, bh                      ; BX = column
F000:F26F  03C3            add    ax, bx                      ; + column
F000:F271  D1E0            shl    ax, 1                       ; *2 — each character cell = char + attribute
F000:F273  5B              pop    bx                          ; Restore BX
F000:F274  C3              ret                                ; return, AX = offset

; ----------------------------------------------------------------------------------------------
; int10_06_scroll_up — AH=06h: scroll window up.
; Input: AL = line count (0 — clear window), BH = fill attribute, CH/CL — upper left corner,
; DH/DL — lower right. AH (on handler entry) = mode; graphics modes go to loc_F419.
; ----------------------------------------------------------------------------------------------
int10_06_scroll_up:    ; xrefs: F051
F000:F275  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F277  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F27A  7208            jb     loc_F284                    ; yes
F000:F27C  80FC07          cmp    ah, 7                       ; mode 7 (also text)?
F000:F27F  7403            je     loc_F284                    ; yes
F000:F281  E99501          jmp    loc_F419                    ; graphics — graphics-mode scroll

loc_F284:    ; xrefs: F27A F27F
F000:F284  53              push   bx                          ; save BX (BH = attribute)
F000:F285  8BC1            mov    ax, cx                      ; AX = upper left corner
F000:F287  E83700          call   sub_F2C1                    ; setup: SI=DI=window start, DH/DL=size, BP=bytes per row, AX=offset of BL rows
F000:F28A  7431            je     loc_F2BD                    ; AL=0 — just clear the whole window
F000:F28C  03F0            add    si, ax                      ; SI = source BL rows below
F000:F28E  8AE6            mov    ah, dh                      ; AH = window height
F000:F290  2AE3            sub    ah, bl                      ; AH = number of rows to move

loc_F292:    ; xrefs: F29B
F000:F292  E85300          call   sub_F2E8                    ; copy one window row (DL words)
F000:F295  03F5            add    si, bp                      ; source — next screen row
F000:F297  03FD            add    di, bp                      ; destination — next screen row
F000:F299  FECC            dec    ah                          ; row counter
F000:F29B  75F5            jne    loc_F292                    ; until all rows are moved

; ----------------------------------------------------------------------------------------------
; fill vacated rows with spaces with attribute BH
; ----------------------------------------------------------------------------------------------
loc_F29D:    ; xrefs: F2BF
F000:F29D  58              pop    ax                          ; AX = saved BX → AH = fill attribute
F000:F29E  B020            mov    al, 20h                     ; AL = space

loc_F2A0:    ; xrefs: F2A7
F000:F2A0  E84E00          call   sub_F2F1                    ; fill window row
F000:F2A3  03FD            add    di, bp                      ; next row
F000:F2A5  FECB            dec    bl                          ; cleared-row counter
F000:F2A7  75F7            jne    loc_F2A0                    ; until all are cleared

; ----------------------------------------------------------------------------------------------
; common text scroll completion (up/down)
; ----------------------------------------------------------------------------------------------
loc_F2A9:    ; xrefs: F32D
F000:F2A9  E83D0C          call   sub_FEE9                    ; DS = 0040h (DS pointed to video memory during scroll)
F000:F2AC  803E490007      cmp    byte [49h], 7               ; mode 7?
F000:F2B1  7407            je     loc_F2BA                    ; yes — leave mode register alone
F000:F2B3  A06500          mov    al, byte [65h]              ; AL = 0040:0065 — CGA mode register copy
F000:F2B6  BAD803          mov    dx, 3D8h                    ; DX = 3D8h
F000:F2B9  EE              out    dx, al                      ; rewrite mode register (in IBM — re-enable video after "snow" blanking; there is no blanking here)

loc_F2BA:    ; xrefs: F2B1
F000:F2BA  E9FCFE          jmp    int10_04_read_lightpen      ; exit

loc_F2BD:    ; xrefs: F28A
F000:F2BD  8ADE            mov    bl, dh                      ; clear whole window: row count = window height
F000:F2BF  EBDC            jmp    loc_F29D                    ; to fill

; ----------------------------------------------------------------------------------------------
; sub_F2C1 — text scroll setup.
; Input: AX = window corner (row/column), CX = upper left, DX = lower right, BL = line count, ES=B800.
; Output: SI=DI = corner offset + page start; DH = height, DL = window width; CH=0;
; BP = bytes per screen row; AX = BL*BP; DS = ES; ZF=1 if BL=0.
; ----------------------------------------------------------------------------------------------
sub_F2C1:    ; xrefs: F287 F30B
F000:F2C1  E8A0FF          call   sub_F264                    ; AX = corner offset within page
F000:F2C4  03064E00        add    ax, word [4Eh]              ; + 0040:004E — active page start
F000:F2C8  8BF8            mov    di, ax                      ; DI = destination address
F000:F2CA  8BF0            mov    si, ax                      ; SI = source address (adjusted by the caller)
F000:F2CC  2BD1            sub    dx, cx                      ; DX = lower right − upper left
F000:F2CE  FEC6            inc    dh                          ; DH = window height in rows
F000:F2D0  FEC2            inc    dl                          ; DL = window width in columns
F000:F2D2  32ED            xor    ch, ch                      ; CH = 0 (CL used as word counter)
F000:F2D4  8B2E4A00        mov    bp, word [4Ah]              ; BP = 0040:004A — columns (word read, high byte 004B = 0)
F000:F2D8  03ED            add    bp, bp                      ; BP = bytes per screen row
F000:F2DA  8AC3            mov    al, bl                      ; AL = scroll line count
F000:F2DC  F6264A00        mul    byte [4Ah]                  ; AX = rows * columns
F000:F2E0  03C0            add    ax, ax                      ; AX = offset of BL rows in bytes
F000:F2E2  06              push   es                          ; DS = ES = B800h — copy within video memory
F000:F2E3  1F              pop    ds                          ; (DS = B800)
F000:F2E4  80FB00          cmp    bl, 0                       ; ZF=1 if scrolling by 0 rows (clear window)
F000:F2E7  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; sub_F2E8 — copy one window row: DL words DS:SI → ES:DI (direction per DF). SI, DI preserved.
; ----------------------------------------------------------------------------------------------
sub_F2E8:    ; xrefs: F292 F316
F000:F2E8  8ACA            mov    cl, dl                      ; CX = window width (CH=0)
F000:F2EA  56              push   si                          ; Save SI
F000:F2EB  57              push   di                          ; save DI
F000:F2EC  F3A5            rep movsw word es:[di], word [si]  ; copy characters with attributes
F000:F2EE  5F              pop    di                          ; restore DI
F000:F2EF  5E              pop    si                          ; Restore SI
F000:F2F0  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; sub_F2F1 — fill one window row: DL words of AX (char+attribute) at ES:DI. DI preserved.
; ----------------------------------------------------------------------------------------------
sub_F2F1:    ; xrefs: F2A0 F324
F000:F2F1  8ACA            mov    cl, dl                      ; CX = window width
F000:F2F3  57              push   di                          ; save DI
F000:F2F4  F3AB            rep stosw word es:[di], ax         ; fill row
F000:F2F6  5F              pop    di                          ; restore DI
F000:F2F7  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; int10_07_scroll_down — AH=07h: scroll window down (parameters as for AH=06h).
; Copies bottom-up (DF=1) from the lower right corner; graphics — loc_F472.
; ----------------------------------------------------------------------------------------------
int10_07_scroll_down:    ; xrefs: F053
F000:F2F8  FD              std                                ; DF=1 — copy backwards
F000:F2F9  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F2FB  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F2FE  7208            jb     loc_F308                    ; yes
F000:F300  80FC07          cmp    ah, 7                       ; mode 7?
F000:F303  7403            je     loc_F308                    ; yes
F000:F305  E96A01          jmp    loc_F472                    ; graphics — graphics-mode scroll down

loc_F308:    ; xrefs: F2FE F303
F000:F308  53              push   bx                          ; save BX (BH = attribute)
F000:F309  8BC2            mov    ax, dx                      ; AX = lower right corner — start from the bottom
F000:F30B  E8B3FF          call   sub_F2C1                    ; scroll setup (SI=DI=lower right corner)
F000:F30E  7420            je     loc_F330                    ; AL=0 — clear whole window
F000:F310  2BF0            sub    si, ax                      ; SI = source BL rows above
F000:F312  8AE6            mov    ah, dh                      ; AH = window height
F000:F314  2AE3            sub    ah, bl                      ; AH = number of rows to move

loc_F316:    ; xrefs: F31F
F000:F316  E8CFFF          call   sub_F2E8                    ; copy row (right to left)
F000:F319  2BF5            sub    si, bp                      ; source — row above
F000:F31B  2BFD            sub    di, bp                      ; destination — row above
F000:F31D  FECC            dec    ah                          ; row counter
F000:F31F  75F5            jne    loc_F316                    ; until all rows are moved

; ----------------------------------------------------------------------------------------------
; fill vacated top rows
; ----------------------------------------------------------------------------------------------
loc_F321:    ; xrefs: F332
F000:F321  58              pop    ax                          ; AH = fill attribute (from saved BX)
F000:F322  B020            mov    al, 20h                     ; AL = space

loc_F324:    ; xrefs: F32B
F000:F324  E8CAFF          call   sub_F2F1                    ; fill row
F000:F327  2BFD            sub    di, bp                      ; row above
F000:F329  FECB            dec    bl                          ; counter
F000:F32B  75F7            jne    loc_F324                    ; until all are cleared
F000:F32D  E979FF          jmp    loc_F2A9                    ; common completion (DS=0040, mode register, exit)

loc_F330:    ; xrefs: F30E
F000:F330  8ADE            mov    bl, dh                      ; clear whole window: rows = height
F000:F332  EBED            jmp    loc_F321                    ; to fill

; ----------------------------------------------------------------------------------------------
; int10_08_read_char_attr — AH=08h: BH = page. Output: AL = character, AH = attribute at cursor.
; Graphics modes — loc_F5AD (character recognition from pixels).
; ----------------------------------------------------------------------------------------------
int10_08_read_char_attr:    ; xrefs: F055
F000:F334  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F337  7208            jb     loc_F341                    ; yes
F000:F339  80FC07          cmp    ah, 7                       ; mode 7?
F000:F33C  7403            je     loc_F341                    ; yes
F000:F33E  E96C02          jmp    loc_F5AD                    ; graphics — read character by matching its image in video memory

loc_F341:    ; xrefs: F337 F33C
F000:F341  E80800          call   sub_F34C                    ; BX = address of page BH cursor position in video memory
F000:F344  8BF3            mov    si, bx                      ; SI = that address
F000:F346  06              push   es                          ; DS = ES = B800h
F000:F347  1F              pop    ds                          ; (DS = B800)
F000:F348  AD              lodsw  ax, word [si]               ; AX = char/attribute word
F000:F349  E96DFE          jmp    int10_04_read_lightpen      ; exit with result in AX

; ----------------------------------------------------------------------------------------------
; sub_F34C — character cell address at page BH cursor: BX = BH*page_size + position offset.
; Input: BH = page, DS=0040. Output: BX — offset in B800, AX — offset within page; clobbers CX, SI.
; ----------------------------------------------------------------------------------------------
sub_F34C:    ; xrefs: F341 F378 F394
F000:F34C  8ACF            mov    cl, bh                      ; CL = page
F000:F34E  32ED            xor    ch, ch                      ; CX = page
F000:F350  8BF1            mov    si, cx                      ; SI = page
F000:F352  D1E6            shl    si, 1                       ; SI = page*2
F000:F354  8B4450          mov    ax, word [si + 50h]         ; AX = 0040:0050+2*page — page cursor position
F000:F357  33DB            xor    bx, bx                      ; BX = 0 — page start accumulator
F000:F359  E306            jcxz   loc_F361                    ; page 0 — start is 0

loc_F35B:    ; xrefs: F35F
F000:F35B  031E4C00        add    bx, word [4Ch]              ; BX += 0040:004C (page size) — multiply by repeated addition
F000:F35F  E2FA            loop   loc_F35B                    ; CX times

loc_F361:    ; xrefs: F359
F000:F361  E800FF          call   sub_F264                    ; AX = position offset within page
F000:F364  03D8            add    bx, ax                      ; BX = page start + offset
F000:F366  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; int10_09_write_char_attr — AH=09h: AL = character, BL = attribute, BH = page, CX = repeat count.
; Writes at cursor position without moving it. Graphics — loc_F4FC.
; ----------------------------------------------------------------------------------------------
int10_09_write_char_attr:    ; xrefs: F057
F000:F367  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F36A  7208            jb     loc_F374                    ; yes
F000:F36C  80FC07          cmp    ah, 7                       ; mode 7?
F000:F36F  7403            je     loc_F374                    ; yes
F000:F371  E98801          jmp    loc_F4FC                    ; graphics — draw character from font

loc_F374:    ; xrefs: F36A F36F
F000:F374  8AE3            mov    ah, bl                      ; AH = attribute, AL = character
F000:F376  50              push   ax                          ; save char+attribute word
F000:F377  51              push   cx                          ; save repeat count
F000:F378  E8D1FF          call   sub_F34C                    ; BX = address of page BH cursor position
F000:F37B  8BFB            mov    di, bx                      ; DI = video memory address
F000:F37D  59              pop    cx                          ; CX = repeat count
F000:F37E  58              pop    ax                          ; AX = char+attribute

loc_F37F:    ; xrefs: F380
F000:F37F  AB              stosw  word es:[di], ax            ; write character cell to ES:DI (B800)
F000:F380  E2FD            loop   loc_F37F                    ; CX times (CX=0 → 65536)
F000:F382  E934FE          jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Ah — write character at cursor position without changing the attribute.
; Input (after dispatcher F080): AH=current video mode (0040:0049), AL=character, BH=page, BL=color (graphics), CX=repeat count;
; ES=B800 (video memory), DS=0040. Text modes (0–3,7) handled here, graphics (4–6) jump to common graphics output F4FC.
; ----------------------------------------------------------------------------------------------
int10_0A_write_char:    ; xrefs: F059
F000:F385  80FC04          cmp    ah, 4                       ; AH = video mode: modes 0–3 are text
F000:F388  7208            jb     loc_F392                    ; text mode → write to video buffer
F000:F38A  80FC07          cmp    ah, 7                       ; mode 7 (monochrome text) is also handled as text
F000:F38D  7403            je     loc_F392                    ; mode 7 → write to video buffer
F000:F38F  E96A01          jmp    loc_F4FC                    ; graphics modes 4–6: character drawn from the font (code shared with AH=09h)

loc_F392:    ; xrefs: F388 F38D
F000:F392  50              push   ax                          ; save character (AL)
F000:F393  51              push   cx                          ; save repeat count
F000:F394  E8B5FF          call   sub_F34C                    ; BX = offset of page BH cursor cell in video buffer
F000:F397  8BFB            mov    di, bx                      ; DI = cell address in B800
F000:F399  59              pop    cx                          ; restore repeat count CX
F000:F39A  58              pop    ax                          ; restore character AL

; ----------------------------------------------------------------------------------------------
; Loop writing CX copies of the character: only the code byte is written, the attribute byte is skipped.
; ----------------------------------------------------------------------------------------------
loc_F39B:    ; xrefs: F39D
F000:F39B  AA              stosb  byte es:[di], al            ; write character code to video buffer
F000:F39C  47              inc    di                          ; skip attribute byte (attribute unchanged)
F000:F39D  E2FC            loop   loc_F39B                    ; repeat CX times
F000:F39F  E917FE          jmp    int10_04_read_lightpen      ; exit INT 10h (common register-restore and IRET point)

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Dh — read pixel (CGA graphics modes 4–6).
; In: DX=row (0–199), CX=column; AH=video mode. Out: AL=pixel color.
; ----------------------------------------------------------------------------------------------
int10_0D_read_pixel:    ; xrefs: F05F
F000:F3A2  E83100          call   sub_F3D6                    ; SI=byte offset, AH=pixel mask, CL=pixel shift, DH=bits per pixel
F000:F3A5  268A04          mov    al, byte es:[si]            ; read video memory byte containing the pixel
F000:F3A8  22C4            and    al, ah                      ; keep only the pixel's bits
F000:F3AA  D2E0            shl    al, cl                      ; shift pixel bits into the high-order bits of the byte
F000:F3AC  8ACE            mov    cl, dh                      ; CL = bits per pixel (2 for 320x200, 1 for 640x200)
F000:F3AE  D2C0            rol    al, cl                      ; rotate high bits into low bits → AL = color number
F000:F3B0  E906FE          jmp    int10_04_read_lightpen      ; exit INT 10h

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Ch — write pixel (CGA graphics modes 4–6).
; In: DX=row, CX=column, AL=color (bit 7 = XOR with current contents). AX preserved.
; ----------------------------------------------------------------------------------------------
int10_0C_write_pixel:    ; xrefs: F05D
F000:F3B3  50              push   ax                          ; save AX for restore on exit
F000:F3B4  50              push   ax                          ; copy of AX: AL=color and XOR flag (to be picked up in BX)
F000:F3B5  E81E00          call   sub_F3D6                    ; SI=byte offset, AH=pixel mask, CL=shift, AL=color in high bits
F000:F3B8  D2E8            shr    al, cl                      ; shift color code to the pixel's position in the byte
F000:F3BA  22C4            and    al, ah                      ; mask color with pixel mask
F000:F3BC  268A0C          mov    cl, byte es:[si]            ; CL = current video memory byte
F000:F3BF  5B              pop    bx                          ; BL = original AL (color with XOR flag)
F000:F3C0  F6C380          test   bl, 80h                     ; color bit 7 — XOR mode?
F000:F3C3  750D            jne    loc_F3D2                    ; yes → XOR overlay
F000:F3C5  F6D4            not    ah                          ; inverted mask — all other pixels of the byte
F000:F3C7  22CC            and    cl, ah                      ; clear bits of the replaced pixel in the old byte
F000:F3C9  0AC1            or     al, cl                      ; insert new pixel color

loc_F3CB:    ; xrefs: F3D4
F000:F3CB  268804          mov    byte es:[si], al            ; write byte back to video memory
F000:F3CE  58              pop    ax                          ; restore caller's AX
F000:F3CF  E9E7FD          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F3D2:    ; xrefs: F3C3
F000:F3D2  32C1            xor    al, cl                      ; XOR new color with byte contents (AL bit 7 was set)
F000:F3D4  EBF5            jmp    loc_F3CB                    ; go write the byte

; ----------------------------------------------------------------------------------------------
; sub_F3D6 — compute pixel address in CGA video memory (rows interleaved across banks 0000h/2000h).
; In: DX=row, CX=column, AL=color, DS=0040. Out: SI=byte offset, AH=pixel mask (in position),
; CL=pixel shift from high bits, DH=bits per pixel (2 or 1), AL=color rotated into high bits; BX preserved.
; ----------------------------------------------------------------------------------------------
sub_F3D6:    ; xrefs: F3A2 F3B5
F000:F3D6  53              push   bx                          ; save BX
F000:F3D7  50              push   ax                          ; save AX (color)
F000:F3D8  B028            mov    al, 28h                     ; 80 bytes per raster line: 28h × (even row number) = 80 × (row/2)
F000:F3DA  52              push   dx                          ; save DX (row number)
F000:F3DB  80E2FE          and    dl, 0FEh                    ; round row down to even (row pair across the two banks)
F000:F3DE  F6E2            mul    dl                          ; AX = 40 × (row & ~1) = 80 × (row div 2)
F000:F3E0  5A              pop    dx                          ; restore row number
F000:F3E1  F6C201          test   dl, 1                       ; odd row?
F000:F3E4  7403            je     loc_F3E9                    ; even → bank 0 (B800:0000)
F000:F3E6  050020          add    ax, 2000h                   ; odd row → bank 1 (B800:2000)

loc_F3E9:    ; xrefs: F3E4
F000:F3E9  8BF0            mov    si, ax                      ; SI = raster line start offset
F000:F3EB  58              pop    ax                          ; AL = color (restored)
F000:F3EC  8BD1            mov    dx, cx                      ; DX = column
F000:F3EE  BBC002          mov    bx, 2C0h                    ; 320x200 mode: BH=2 bits per pixel, BL=C0h mask of the byte's leftmost pixel
F000:F3F1  B90203          mov    cx, 302h                    ; CH=3 (pixel-in-byte mask, 4 pixels), CL=2 (column/4 = byte)
F000:F3F4  803E490006      cmp    byte [49h], 6               ; 0040:0049 — current video mode; 6 = 640x200
F000:F3F9  7206            jb     loc_F401                    ; modes 4/5 → 320x200 parameters
F000:F3FB  BB8001          mov    bx, 180h                    ; mode 6: BH=1 bit per pixel, BL=80h mask
F000:F3FE  B90307          mov    cx, 703h                    ; CH=7 (8 pixels per byte), CL=3 (column/8 = byte)

loc_F401:    ; xrefs: F3F9
F000:F401  22EA            and    ch, dl                      ; CH = pixel number within the byte
F000:F403  D3EA            shr    dx, cl                      ; DX = byte number within the raster line
F000:F405  03F2            add    si, dx                      ; SI = offset of the byte containing the pixel
F000:F407  8AF7            mov    dh, bh                      ; DH = bits per pixel (returned to caller)
F000:F409  2AC9            sub    cl, cl                      ; CL = 0 — shift accumulator

loc_F40B:    ; xrefs: F411
F000:F40B  D0C8            ror    al, 1                       ; rotate color right — low color bits move to the high bits
F000:F40D  02CD            add    cl, ch                      ; CL += pixel number (result: CL = pixel number × bits per pixel)
F000:F40F  FECF            dec    bh                          ; repeat "bits per pixel" times
F000:F411  75F8            jne    loc_F40B                    ; loop over pixel bits
F000:F413  8AE3            mov    ah, bl                      ; AH = mask of the leftmost pixel (C0h or 80h)
F000:F415  D2EC            shr    ah, cl                      ; shift mask to the target pixel position
F000:F417  5B              pop    bx                          ; restore BX
F000:F418  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Scroll window up in graphics modes 4–6 (continuation of INT 10h AH=06h).
; In: AL→BL=line count (0 = clear window), CX=upper-left corner (CH=row, CL=column),
; DX=lower-right corner, BH=fill byte. Text row = 8 raster lines = 4 pairs (bank 0/bank 1), 80-byte stride.
; ----------------------------------------------------------------------------------------------
loc_F419:    ; xrefs: F281
F000:F419  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F41B  8BC1            mov    ax, cx                      ; AX = window upper-left corner (row/column in characters)
F000:F41D  E86802          call   sub_F688                    ; AX = offset of upper-left character cell (row×columns×4 + column)
F000:F420  8BF8            mov    di, ax                      ; DI = destination address (top of window)
F000:F422  2BD1            sub    dx, cx                      ; DX = window size minus 1 (rows/columns)
F000:F424  81C20101        add    dx, 101h                    ; DH = window height in characters, DL = width in characters
F000:F428  D0E6            shl    dh, 1                       ; window height × 2 ...
F000:F42A  D0E6            shl    dh, 1                       ; ... × 4 = number of raster line pairs in the window
F000:F42C  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200 (1 byte per character cell)
F000:F431  7304            jae    loc_F437                    ; mode 6 → width in bytes = width in characters
F000:F433  D0E2            shl    dl, 1                       ; modes 4/5: character cell = 2 bytes → width in bytes ×2
F000:F435  D1E7            shl    di, 1                       ; and window start offset ×2

loc_F437:    ; xrefs: F431
F000:F437  06              push   es                          ; DS = ES = B800 — copy within video memory
F000:F438  1F              pop    ds                          ; (DS = video memory segment)
F000:F439  2AED            sub    ch, ch                      ; CH = 0 — CX used as byte-per-line counter
F000:F43B  D0E3            shl    bl, 1                       ; scroll line count × 4 ...
F000:F43D  D0E3            shl    bl, 1                       ; ... = number of raster line pairs to shift
F000:F43F  742D            je     loc_F46E                    ; 0 → clear entire window
F000:F441  8AC3            mov    al, bl                      ; AL = number of line pairs to shift
F000:F443  B450            mov    ah, 50h                     ; 80 bytes per raster line in a bank
F000:F445  F6E4            mul    ah                          ; AX = source offset relative to destination
F000:F447  8BF7            mov    si, di                      ; SI = DI ...
F000:F449  03F0            add    si, ax                      ; ... + shift: source is BL rows below
F000:F44B  8AE6            mov    ah, dh                      ; AH = window height in line pairs
F000:F44D  2AE3            sub    ah, bl                      ; minus shift = number of line pairs to copy

; ----------------------------------------------------------------------------------------------
; Copy window raster lines up (one line pair from both banks per iteration).
; ----------------------------------------------------------------------------------------------
loc_F44F:    ; xrefs: F45C
F000:F44F  E88000          call   sub_F4D2                    ; copy DL bytes in bank 0 and bank 1; SI/DI returned +2000h
F000:F452  81EEB01F        sub    si, 1FB0h                   ; source: −2000h + 50h → next line of bank 0
F000:F456  81EFB01F        sub    di, 1FB0h                   ; destination: next line of bank 0
F000:F45A  FECC            dec    ah                          ; line pair counter
F000:F45C  75F1            jne    loc_F44F                    ; continue copying

; ----------------------------------------------------------------------------------------------
; Fill vacated bottom lines with byte BH.
; ----------------------------------------------------------------------------------------------
loc_F45E:    ; xrefs: F470
F000:F45E  8AC7            mov    al, bh                      ; AL = fill byte (BH)

loc_F460:    ; xrefs: F469
F000:F460  E88800          call   sub_F4EB                    ; fill a raster line pair (bank 0 and bank 1)
F000:F463  81EFB01F        sub    di, 1FB0h                   ; next line: −2000h + 50h
F000:F467  FECB            dec    bl                          ; counter of line pairs to fill
F000:F469  75F5            jne    loc_F460                    ; continue filling
F000:F46B  E94BFD          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F46E:    ; xrefs: F43F
F000:F46E  8ADE            mov    bl, dh                      ; BL=0: whole window cleared — number of pairs to fill = window height
F000:F470  EBEC            jmp    loc_F45E                    ; go fill

; ----------------------------------------------------------------------------------------------
; Scroll window down in graphics modes 4–6 (continuation of INT 10h AH=07h).
; Input as for AH=06h. Works from the end of the window (lower-right corner, DF=1, backward copy).
; ----------------------------------------------------------------------------------------------
loc_F472:    ; xrefs: F305
F000:F472  FD              std                                ; DF=1: string instructions go toward lower addresses
F000:F473  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F475  8BC2            mov    ax, dx                      ; AX = window lower-right corner
F000:F477  E80E02          call   sub_F688                    ; AX = offset of lower-right character cell
F000:F47A  8BF8            mov    di, ax                      ; DI = destination address (bottom of window)
F000:F47C  2BD1            sub    dx, cx                      ; DX = window size minus 1
F000:F47E  81C20101        add    dx, 101h                    ; DH = window height, DL = width in characters
F000:F482  D0E6            shl    dh, 1                       ; height × 2 ...
F000:F484  D0E6            shl    dh, 1                       ; ... × 4 = number of raster line pairs
F000:F486  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200?
F000:F48B  7305            jae    loc_F492                    ; mode 6 → 1 byte per character cell
F000:F48D  D0E2            shl    dl, 1                       ; modes 4/5: width in bytes ×2
F000:F48F  D1E7            shl    di, 1                       ; offset ×2 (2 bytes per character cell)
F000:F491  47              inc    di                          ; +1 → right byte of the character cell (copying goes right to left)

loc_F492:    ; xrefs: F48B
F000:F492  06              push   es                          ; DS = ES = B800
F000:F493  1F              pop    ds                          ; (DS = video memory segment)
F000:F494  2AED            sub    ch, ch                      ; CH = 0 for counter CX
F000:F496  81C7F000        add    di, 0F0h                    ; +F0h = 3×80: last (4th) raster line pair of the character cell
F000:F49A  D0E3            shl    bl, 1                       ; scroll line count × 4 ...
F000:F49C  D0E3            shl    bl, 1                       ; ... = raster line pairs; 0 → clear window
F000:F49E  742E            je     loc_F4CE                    ; BL=0 → clear entire window
F000:F4A0  8AC3            mov    al, bl                      ; AL = number of line pairs to shift
F000:F4A2  B450            mov    ah, 50h                     ; 80 bytes per raster line
F000:F4A4  F6E4            mul    ah                          ; AX = source offset
F000:F4A6  8BF7            mov    si, di                      ; SI = DI ...
F000:F4A8  2BF0            sub    si, ax                      ; ... − shift: source is BL rows above
F000:F4AA  8AE6            mov    ah, dh                      ; AH = window height in line pairs
F000:F4AC  2AE3            sub    ah, bl                      ; minus shift = number of line pairs to copy

loc_F4AE:    ; xrefs: F4BB
F000:F4AE  E82100          call   sub_F4D2                    ; copy a line pair (bank 0 and bank 1) backward; SI/DI returned +2000h
F000:F4B1  81EE5020        sub    si, 2050h                   ; source: −2000h − 50h → previous line of bank 0
F000:F4B5  81EF5020        sub    di, 2050h                   ; destination: previous line of bank 0
F000:F4B9  FECC            dec    ah                          ; line pair counter
F000:F4BB  75F1            jne    loc_F4AE                    ; continue copying

loc_F4BD:    ; xrefs: F4D0
F000:F4BD  8AC7            mov    al, bh                      ; AL = fill byte (BH)

loc_F4BF:    ; xrefs: F4C8
F000:F4BF  E82900          call   sub_F4EB                    ; fill a raster line pair at the top of the window
F000:F4C2  81EF5020        sub    di, 2050h                   ; previous line: −2000h − 50h
F000:F4C6  FECB            dec    bl                          ; counter of line pairs to fill
F000:F4C8  75F5            jne    loc_F4BF                    ; continue filling
F000:F4CA  FC              cld                                ; restore DF=0
F000:F4CB  E9EBFC          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F4CE:    ; xrefs: F49E
F000:F4CE  8ADE            mov    bl, dh                      ; BL=0: entire window is filled
F000:F4D0  EBEB            jmp    loc_F4BD                    ; go fill

; ----------------------------------------------------------------------------------------------
; sub_F4D2 — copy one window line in both CGA banks.
; In: DS:SI → ES:DI, DL=length in bytes, CH=0, DF sets direction. Out: SI, DI increased by 2000h (bank 1).
; ----------------------------------------------------------------------------------------------
sub_F4D2:    ; xrefs: F44F F4AE
F000:F4D2  8ACA            mov    cl, dl                      ; CX = window line length in bytes
F000:F4D4  56              push   si                          ; save source
F000:F4D5  57              push   di                          ; save destination
F000:F4D6  F3A4            rep movsb byte es:[di], byte [si]  ; copy bank 0 line (even raster lines)
F000:F4D8  5F              pop    di                          ; restore destination
F000:F4D9  5E              pop    si                          ; restore source
F000:F4DA  81C60020        add    si, 2000h                   ; source → same area in bank 1 (odd lines)
F000:F4DE  81C70020        add    di, 2000h                   ; destination → bank 1
F000:F4E2  56              push   si                          ; save source in bank 1
F000:F4E3  57              push   di                          ; save destination in bank 1
F000:F4E4  8ACA            mov    cl, dl                      ; CX = line length
F000:F4E6  F3A4            rep movsb byte es:[di], byte [si]  ; copy bank 1 line
F000:F4E8  5F              pop    di                          ; DI = line start in bank 1
F000:F4E9  5E              pop    si                          ; SI = line start in bank 1
F000:F4EA  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F4EB — fill one window line with byte AL in both CGA banks.
; In: ES:DI, DL=length, CH=0. Out: DI increased by 2000h.
; ----------------------------------------------------------------------------------------------
sub_F4EB:    ; xrefs: F460 F4BF
F000:F4EB  8ACA            mov    cl, dl                      ; CX = line length in bytes
F000:F4ED  57              push   di                          ; save address
F000:F4EE  F3AA            rep stosb byte es:[di], al         ; fill bank 0 line
F000:F4F0  5F              pop    di                          ; restore address
F000:F4F1  81C70020        add    di, 2000h                   ; switch to bank 1
F000:F4F5  57              push   di                          ; save address in bank 1
F000:F4F6  8ACA            mov    cl, dl                      ; CX = length
F000:F4F8  F3AA            rep stosb byte es:[di], al         ; fill bank 1 line
F000:F4FA  5F              pop    di                          ; DI = line start in bank 1
F000:F4FB  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Character output in graphics modes 4–6 (INT 10h AH=09h/0Ah for graphics).
; In: AL=character code, BL=color (bit 7 = XOR), CX=repeat count; position — page 0 cursor (0040:0050).
; Glyphs 00–7Fh come from ROM F000:FA6E, 80–FFh via the INT 1Fh vector (0000:007C), as in the IBM PC.
; ----------------------------------------------------------------------------------------------
loc_F4FC:    ; xrefs: F371 F38F
F000:F4FC  B400            mov    ah, 0                       ; AX = character code (AH cleared)
F000:F4FE  50              push   ax                          ; save character code
F000:F4FF  E88301          call   sub_F685                    ; AX = cursor character cell offset (page 0)
F000:F502  8BF8            mov    di, ax                      ; DI = character cell address in video memory
F000:F504  58              pop    ax                          ; restore character code
F000:F505  3C80            cmp    al, 80h                     ; character from upper half (80–FFh)?
F000:F507  7306            jae    loc_F50F                    ; yes → font via INT 1Fh vector
F000:F509  BE6EFA          mov    si, 0FA6Eh                  ; SI = F000:FA6E — 8x8 font for characters 00–7Fh in ROM
F000:F50C  0E              push   cs                          ; font segment = CS (F000) — pushed for later pop ds
F000:F50D  EB0F            jmp    loc_F51E                    ; go compute glyph address

loc_F50F:    ; xrefs: F507
F000:F50F  2C80            sub    al, 80h                     ; index into upper-half font table
F000:F511  1E              push   ds                          ; save DS (0040)
F000:F512  2BF6            sub    si, si                      ; SI = 0 ...
F000:F514  8EDE            mov    ds, si                      ; ... DS = 0 — interrupt vector table
F000:F516  C5367C00        lds    si, [7Ch]                   ; DS:SI = INT 1Fh vector (0000:007C) — glyph table 80–FFh (BIOS sets F400:1C00)
F000:F51A  8CDA            mov    dx, ds                      ; DX = glyph table segment
F000:F51C  1F              pop    ds                          ; restore DS = 0040
F000:F51D  52              push   dx                          ; font segment pushed for later pop ds

loc_F51E:    ; xrefs: F50D
F000:F51E  D1E0            shl    ax, 1                       ; code × 2 ...
F000:F520  D1E0            shl    ax, 1                       ; ... × 4 ...
F000:F522  D1E0            shl    ax, 1                       ; ... × 8 = glyph offset (8 bytes per character)
F000:F524  03F0            add    si, ax                      ; SI → character glyph
F000:F526  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200 (1 bit per pixel)
F000:F52B  1F              pop    ds                          ; DS = font segment (compare flags preserved)
F000:F52C  722C            jb     loc_F55A                    ; modes 4/5 → output with 2 bits per pixel

; ----------------------------------------------------------------------------------------------
; Mode 6 (640x200): each glyph row is one byte; even rows in bank 0, odd rows in bank 1.
; ----------------------------------------------------------------------------------------------
loc_F52E:    ; xrefs: F549
F000:F52E  57              push   di                          ; save character cell address
F000:F52F  56              push   si                          ; save glyph address
F000:F530  B604            mov    dh, 4                       ; DH = 4 glyph row pairs (8 rows)

loc_F532:    ; xrefs: F544
F000:F532  AC              lodsb  al, byte [si]               ; AL = even glyph row
F000:F533  F6C380          test   bl, 80h                     ; color bit 7 — XOR mode?
F000:F536  7516            jne    loc_F54E                    ; yes → XOR overlay
F000:F538  AA              stosb  byte es:[di], al            ; write row to bank 0, DI+1
F000:F539  AC              lodsb  al, byte [si]               ; AL = odd glyph row

loc_F53A:    ; xrefs: F558
F000:F53A  268885FF1F      mov    byte es:[di + 1FFFh], al    ; write to bank 1 at the same offset (DI already +1, hence 1FFFh)
F000:F53F  83C74F          add    di, 4Fh                     ; +4Fh (with +1 from STOSB = 50h) → next bank line
F000:F542  FECE            dec    dh                          ; line pair counter
F000:F544  75EC            jne    loc_F532                    ; next glyph row pair
F000:F546  5E              pop    si                          ; SI = glyph start (for repeat)
F000:F547  5F              pop    di                          ; DI = current character cell address
F000:F548  47              inc    di                          ; next character cell (1 byte in mode 6)
F000:F549  E2E3            loop   loc_F52E                    ; repeat character CX times
F000:F54B  E96BFC          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F54E:    ; xrefs: F536
F000:F54E  263205          xor    al, byte es:[di]            ; XOR glyph row with screen (bank 0)
F000:F551  AA              stosb  byte es:[di], al            ; write, DI+1
F000:F552  AC              lodsb  al, byte [si]               ; next glyph row
F000:F553  263285FF1F      xor    al, byte es:[di + 1FFFh]    ; XOR with screen in bank 1
F000:F558  EBE0            jmp    loc_F53A                    ; go write to bank 1

; ----------------------------------------------------------------------------------------------
; Modes 4/5 (320x200, 4 colors): each glyph bit is doubled into a 2-bit pixel,
; glyph row = word (2 bytes), colored with BL&3.
; ----------------------------------------------------------------------------------------------
loc_F55A:    ; xrefs: F52C
F000:F55A  8AD3            mov    dl, bl                      ; DL = color with XOR flag (bit 7)
F000:F55C  D1E7            shl    di, 1                       ; offset ×2 — 2 bytes per character cell
F000:F55E  E8D000          call   sub_F631                    ; BX = color (0–3) replicated to all 8 pixel positions of the word

loc_F561:    ; xrefs: F5A8
F000:F561  57              push   di                          ; save character cell address
F000:F562  56              push   si                          ; save glyph address
F000:F563  B604            mov    dh, 4                       ; DH = 4 glyph row pairs

loc_F565:    ; xrefs: F5A2
F000:F565  AC              lodsb  al, byte [si]               ; AL = even glyph row
F000:F566  E8DD00          call   sub_F646                    ; AX = row expanded to 2 bits per pixel
F000:F569  23C3            and    ax, bx                      ; color the pixels
F000:F56B  F6C280          test   dl, 80h                     ; XOR mode?
F000:F56E  7407            je     loc_F577                    ; no → direct write
F000:F570  263225          xor    ah, byte es:[di]            ; XOR high (left) byte with screen
F000:F573  26324501        xor    al, byte es:[di + 1]        ; XOR low (right) byte with screen

loc_F577:    ; xrefs: F56E
F000:F577  268825          mov    byte es:[di], ah            ; left 4 pixels → bank 0
F000:F57A  26884501        mov    byte es:[di + 1], al        ; right 4 pixels → bank 0
F000:F57E  AC              lodsb  al, byte [si]               ; AL = odd glyph row
F000:F57F  E8C400          call   sub_F646                    ; expand to 2 bits per pixel
F000:F582  23C3            and    ax, bx                      ; apply color
F000:F584  F6C280          test   dl, 80h                     ; XOR mode?
F000:F587  740A            je     loc_F593                    ; no → direct write
F000:F589  2632A50020      xor    ah, byte es:[di + 2000h]    ; XOR left byte with screen in bank 1
F000:F58E  2632850120      xor    al, byte es:[di + 2001h]    ; XOR right byte with screen in bank 1

loc_F593:    ; xrefs: F587
F000:F593  2688A50020      mov    byte es:[di + 2000h], ah    ; left 4 pixels → bank 1
F000:F598  2688850120      mov    byte es:[di + 2001h], al    ; right 4 pixels → bank 1
F000:F59D  83C750          add    di, 50h                     ; next bank line (80 bytes)
F000:F5A0  FECE            dec    dh                          ; line pair counter
F000:F5A2  75C1            jne    loc_F565                    ; next glyph row pair
F000:F5A4  5E              pop    si                          ; SI = glyph start
F000:F5A5  5F              pop    di                          ; DI = character cell address
F000:F5A6  47              inc    di                          ; next character cell ...
F000:F5A7  47              inc    di                          ; ... (2 bytes)
F000:F5A8  E2B7            loop   loc_F561                    ; repeat character CX times
F000:F5AA  E90CFC          jmp    int10_04_read_lightpen      ; exit INT 10h

; ----------------------------------------------------------------------------------------------
; Read character in graphics modes 4–6 (continuation of INT 10h AH=08h).
; The cell image under the cursor (page 0) is gathered into an 8-byte stack buffer (pixel ≠ background → bit 1)
; and compared with glyphs at F000:FA6E, then with the INT 1Fh table. Out: AL=character code (0 — not found).
; ----------------------------------------------------------------------------------------------
loc_F5AD:    ; xrefs: F33E
F000:F5AD  E8D500          call   sub_F685                    ; AX = cursor character cell offset (page 0)
F000:F5B0  8BF0            mov    si, ax                      ; SI = character cell address
F000:F5B2  83EC08          sub    sp, 8                       ; 8-byte stack buffer for the character image
F000:F5B5  8BEC            mov    bp, sp                      ; BP → buffer (addressed via SS)
F000:F5B7  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200?
F000:F5BC  06              push   es                          ; DS = B800 ...
F000:F5BD  1F              pop    ds                          ; ... video memory
F000:F5BE  721A            jb     loc_F5DA                    ; modes 4/5 → pack 2-bit pixels
F000:F5C0  B604            mov    dh, 4                       ; mode 6: 4 line pairs

loc_F5C2:    ; xrefs: F5D5
F000:F5C2  8A04            mov    al, byte [si]               ; line from bank 0
F000:F5C4  884600          mov    byte [bp], al               ; to buffer
F000:F5C7  45              inc    bp                          ; next buffer byte
F000:F5C8  8A840020        mov    al, byte [si + 2000h]       ; line from bank 1
F000:F5CC  884600          mov    byte [bp], al               ; to buffer
F000:F5CF  45              inc    bp                          ; next buffer byte
F000:F5D0  83C650          add    si, 50h                     ; next bank line (80 bytes)
F000:F5D3  FECE            dec    dh                          ; line pair counter
F000:F5D5  75EB            jne    loc_F5C2                    ; continue gathering the image
F000:F5D7  EB17            jmp    loc_F5F0                    ; go search for the glyph
F000:F5D9  90              db     90h                         ; filler (NOP) after short jump

loc_F5DA:    ; xrefs: F5BE
F000:F5DA  D1E6            shl    si, 1                       ; modes 4/5: 2 bytes per character cell → offset ×2
F000:F5DC  B604            mov    dh, 4                       ; 4 line pairs

loc_F5DE:    ; xrefs: F5EE
F000:F5DE  E88700          call   sub_F668                    ; pack bank 0 line (2 bytes → 8 bits) into buffer
F000:F5E1  81C60020        add    si, 2000h                   ; switch to bank 1
F000:F5E5  E88000          call   sub_F668                    ; pack bank 1 line into buffer
F000:F5E8  81EEB01F        sub    si, 1FB0h                   ; −2000h + 50h → next line of bank 0
F000:F5EC  FECE            dec    dh                          ; line pair counter
F000:F5EE  75EE            jne    loc_F5DE                    ; continue gathering the image

; ----------------------------------------------------------------------------------------------
; Search for the gathered image in the font tables: first 128 ROM glyphs, then 128 via the INT 1Fh vector.
; ----------------------------------------------------------------------------------------------
loc_F5F0:    ; xrefs: F5D7
F000:F5F0  BF6EFA          mov    di, 0FA6Eh                  ; DI = F000:FA6E — font for characters 00–7Fh
F000:F5F3  0E              push   cs                          ; ES = CS = F000 ...
F000:F5F4  07              pop    es                          ; ... font segment
F000:F5F5  83ED08          sub    bp, 8                       ; BP → start of image buffer
F000:F5F8  8BF5            mov    si, bp                      ; SI = buffer
F000:F5FA  FC              cld                                ; compare toward increasing addresses
F000:F5FB  B000            mov    al, 0                       ; AL = 0 — code of the first character checked

loc_F5FD:    ; xrefs: F629
F000:F5FD  16              push   ss                          ; DS = SS ...
F000:F5FE  1F              pop    ds                          ; ... image buffer on the stack
F000:F5FF  BA8000          mov    dx, 80h                     ; 128 glyphs in the table

loc_F602:    ; xrefs: F613
F000:F602  56              push   si                          ; save image address
F000:F603  57              push   di                          ; save glyph address
F000:F604  B90800          mov    cx, 8                       ; 8 glyph bytes
F000:F607  F3A6            repe cmpsb byte [si], byte es:[di] ; compare image with glyph
F000:F609  5F              pop    di                          ; restore glyph address
F000:F60A  5E              pop    si                          ; restore image address
F000:F60B  741E            je     loc_F62B                    ; match → AL = character code
F000:F60D  FEC0            inc    al                          ; next character code
F000:F60F  83C708          add    di, 8                       ; next glyph
F000:F612  4A              dec    dx                          ; table glyph counter
F000:F613  75ED            jne    loc_F602                    ; continue searching
F000:F615  3C00            cmp    al, 0                       ; AL=0 after second table (80h+80h overflow) → not found
F000:F617  7412            je     loc_F62B                    ; not found → exit with AL=0
F000:F619  2BC0            sub    ax, ax                      ; AX = 0 ...
F000:F61B  8ED8            mov    ds, ax                      ; ... DS = 0 — vector table
F000:F61D  C43E7C00        les    di, [7Ch]                   ; ES:DI = INT 1Fh vector (0000:007C) — glyph table 80–FFh
F000:F621  8CC0            mov    ax, es                      ; vector zero?
F000:F623  0BC7            or     ax, di                      ; (segment OR offset)
F000:F625  7404            je     loc_F62B                    ; no table → exit (AL=80h, same as IBM BIOS)
F000:F627  B080            mov    al, 80h                     ; AL = 80h — first upper-half code
F000:F629  EBD2            jmp    loc_F5FD                    ; search the second table

loc_F62B:    ; xrefs: F60B F617 F625
F000:F62B  83C408          add    sp, 8                       ; release image buffer on the stack
F000:F62E  E988FB          jmp    int10_04_read_lightpen      ; exit INT 10h (AL = code found)

; ----------------------------------------------------------------------------------------------
; sub_F631 — replicate color to all pixels of a byte (320x200 mode).
; In: BL=color (bits 0–1). Out: BL=BH=color repeated 4 times (e.g. 2 → AAh). CX preserved.
; ----------------------------------------------------------------------------------------------
sub_F631:    ; xrefs: F55E
F000:F631  80E303          and    bl, 3                       ; keep color number 0–3
F000:F634  8AC3            mov    al, bl                      ; AL = color
F000:F636  51              push   cx                          ; save CX (character repeat count)
F000:F637  B90300          mov    cx, 3                       ; 3 more copies of the color

loc_F63A:    ; xrefs: F640
F000:F63A  D0E0            shl    al, 1                       ; shift color to the next pixel position ...
F000:F63C  D0E0            shl    al, 1                       ; ... (2 bits)
F000:F63E  0AD8            or     bl, al                      ; add a copy of the color
F000:F640  E2F8            loop   loc_F63A                    ; loop over 3 pixels
F000:F642  8AFB            mov    bh, bl                      ; BH = BL → color mask for a word (8 pixels)
F000:F644  59              pop    cx                          ; restore CX
F000:F645  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F646 — "stretch" a glyph byte: each bit of AL is doubled (bit k → bits 2k and 2k+1).
; In: AL=glyph row. Out: AX=16-bit mask for 8 pixels of 2 bits each. BX, CX, DX preserved.
; ----------------------------------------------------------------------------------------------
sub_F646:    ; xrefs: F566 F57F
F000:F646  52              push   dx                          ; save DX
F000:F647  51              push   cx                          ; save CX
F000:F648  53              push   bx                          ; save BX
F000:F649  2BD2            sub    dx, dx                      ; DX = 0 — result accumulator
F000:F64B  B90100          mov    cx, 1                       ; CX = mask of the current result bit (starting with bit 0)

loc_F64E:    ; xrefs: F660
F000:F64E  8BD8            mov    bx, ax                      ; BX = source bit k shifted to position 2k
F000:F650  23D9            and    bx, cx                      ; (isolate it with the mask)
F000:F652  0BD3            or     dx, bx                      ; add to result
F000:F654  D1E0            shl    ax, 1                       ; shift source value by 1 bit
F000:F656  D1E1            shl    cx, 1                       ; mask → position 2k+1
F000:F658  8BD8            mov    bx, ax                      ; same bit k, now at position 2k+1
F000:F65A  23D9            and    bx, cx                      ; (isolate with mask)
F000:F65C  0BD3            or     dx, bx                      ; add to result
F000:F65E  D1E1            shl    cx, 1                       ; mask → position 2(k+1)
F000:F660  73EC            jae    loc_F64E                    ; until the mask goes past 16 bits (8 iterations)
F000:F662  8BC2            mov    ax, dx                      ; AX = stretched row
F000:F664  5B              pop    bx                          ; restore BX
F000:F665  59              pop    cx                          ; restore CX
F000:F666  5A              pop    dx                          ; restore DX
F000:F667  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F668 — pack 8 pixels of 2 bits (2 video memory bytes) into an 8-bit row image.
; In: DS:SI → two bytes, SS:BP → buffer. A non-zero color pixel yields bit 1. Out: byte at [BP], BP+1.
; ----------------------------------------------------------------------------------------------
sub_F668:    ; xrefs: F5DE F5E5
F000:F668  8A24            mov    ah, byte [si]               ; AH = left 4 pixels
F000:F66A  8A4401          mov    al, byte [si + 1]           ; AL = right 4 pixels
F000:F66D  B900C0          mov    cx, 0C000h                  ; CX = mask of the first (leftmost) pixel
F000:F670  B200            mov    dl, 0                       ; DL = image bit accumulator

loc_F672:    ; xrefs: F67E
F000:F672  85C1            test   cx, ax                      ; non-zero color pixel?
F000:F674  F8              clc                                ; CF=0 — background pixel
F000:F675  7401            je     loc_F678                    ; background → bit 0
F000:F677  F9              stc                                ; CF=1 — foreground pixel

loc_F678:    ; xrefs: F675
F000:F678  D0D2            rcl    dl, 1                       ; shift bit into the image
F000:F67A  D1E9            shr    cx, 1                       ; mask → next pixel ...
F000:F67C  D1E9            shr    cx, 1                       ; ... (shift by 2 bits); CF=1 when the mask falls off
F000:F67E  73F2            jae    loc_F672                    ; loop over 8 pixels
F000:F680  885600          mov    byte [bp], dl               ; store image byte in buffer (SS segment)
F000:F683  45              inc    bp                          ; next buffer byte
F000:F684  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F685 / sub_F688 — character cell offset in graphics video memory (bank 0).
; sub_F685: position taken from 0040:0050 (page 0 cursor). sub_F688: AX=position (AH=row, AL=column).
; Out: AX = row × columns(0040:004A) × 4 + column (for 320x200 the caller multiplies by 2 again).
; ----------------------------------------------------------------------------------------------
sub_F685:    ; xrefs: F4FF F5AD
F000:F685  A15000          mov    ax, word [50h]              ; AX = 0040:0050 — page 0 cursor position (AH=row, AL=column)

sub_F688:    ; xrefs: F41D F477
F000:F688  53              push   bx                          ; save BX
F000:F689  8BD8            mov    bx, ax                      ; BX = position (BL = column)
F000:F68B  8AC4            mov    al, ah                      ; AL = row
F000:F68D  F6264A00        mul    byte [4Ah]                  ; × 0040:004A (number of screen columns)
F000:F691  D1E0            shl    ax, 1                       ; ×4 — 4 lines of 80 bytes per bank per character cell ...
F000:F693  D1E0            shl    ax, 1                       ; ... (i.e. 8 raster lines)
F000:F695  2AFF            sub    bh, bh                      ; BX = column
F000:F697  03C3            add    ax, bx                      ; + column
F000:F699  5B              pop    bx                          ; restore BX
F000:F69A  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Eh — teletype character output.
; In: AL=character, BL=color (graphics). Handles BS(08), CR(0D), LF(0A), BEL(07); on the active page 0040:0062.
; When moving past the last row (24) scrolls the screen up (AH=06h) using the attribute of the character under the cursor.
; ----------------------------------------------------------------------------------------------
int10_0E_write_tty:    ; xrefs: F061
F000:F69B  50              push   ax                          ; save AX for exit
F000:F69C  50              push   ax                          ; save character
F000:F69D  B403            mov    ah, 3                       ; function 03h — read cursor position
F000:F69F  8A3E6200        mov    bh, byte [62h]              ; BH = 0040:0062 — active video page
F000:F6A3  CD10            int    10h                         ; DX = cursor position (DH=row, DL=column)
F000:F6A5  58              pop    ax                          ; AL = character
F000:F6A6  3C08            cmp    al, 8                       ; BS (backspace)?
F000:F6A8  7452            je     loc_F6FC                    ; → cursor left
F000:F6AA  3C0D            cmp    al, 0Dh                     ; CR (carriage return)?
F000:F6AC  7457            je     loc_F705                    ; → to start of line
F000:F6AE  3C0A            cmp    al, 0Ah                     ; LF (line feed)?
F000:F6B0  7457            je     loc_F709                    ; → one line down
F000:F6B2  3C07            cmp    al, 7                       ; BEL (bell)?
F000:F6B4  745A            je     loc_F710                    ; → beep
F000:F6B6  B40A            mov    ah, 0Ah                     ; function 0Ah — write character at cursor position
F000:F6B8  B90100          mov    cx, 1                       ; one character
F000:F6BB  CD10            int    10h                         ; output character (BL = color in graphics)
F000:F6BD  FEC2            inc    dl                          ; cursor right
F000:F6BF  3A164A00        cmp    dl, byte [4Ah]              ; reached end of line (0040:004A — number of columns)?
F000:F6C3  7533            jne    loc_F6F8                    ; no → set cursor
F000:F6C5  B200            mov    dl, 0                       ; wrap: column 0
F000:F6C7  80FE18          cmp    dh, 18h                     ; last screen row (24)?
F000:F6CA  752A            jne    loc_F6F6                    ; no → next row

; ----------------------------------------------------------------------------------------------
; Scroll the screen up one line (cursor on row 24).
; ----------------------------------------------------------------------------------------------
loc_F6CC:    ; xrefs: F70E
F000:F6CC  B402            mov    ah, 2                       ; function 02h — set cursor
F000:F6CE  CD10            int    10h                         ; set cursor (row 24)
F000:F6D0  A04900          mov    al, byte [49h]              ; AL = 0040:0049 — current video mode
F000:F6D3  3C04            cmp    al, 4                       ; text modes 0–3?
F000:F6D5  7206            jb     loc_F6DD                    ; yes → take attribute of the character under the cursor
F000:F6D7  3C07            cmp    al, 7                       ; mode 7 (mono text)?
F000:F6D9  B700            mov    bh, 0                       ; graphics: fill with zero (background)
F000:F6DB  7506            jne    loc_F6E3                    ; graphics (4–6) → scroll right away

loc_F6DD:    ; xrefs: F6D5
F000:F6DD  B408            mov    ah, 8                       ; function 08h — read character/attribute under cursor
F000:F6DF  CD10            int    10h                         ; AH = attribute
F000:F6E1  8AFC            mov    bh, ah                      ; BH = attribute for filling the new line

loc_F6E3:    ; xrefs: F6DB
F000:F6E3  B80106          mov    ax, 601h                    ; function 06h — scroll up 1 line
F000:F6E6  2BC9            sub    cx, cx                      ; window from (0,0)
F000:F6E8  B618            mov    dh, 18h                     ; to row 24 ...
F000:F6EA  8A164A00        mov    dl, byte [4Ah]              ; ... and the last column (0040:004A − 1)
F000:F6EE  FECA            dec    dl                          ; (columns − 1)

loc_F6F0:    ; xrefs: F6FA
F000:F6F0  CD10            int    10h                         ; call INT 10h (scroll or set cursor AH=02h)

loc_F6F2:    ; xrefs: F715
F000:F6F2  58              pop    ax                          ; restore AX
F000:F6F3  E9C3FA          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F6F6:    ; xrefs: F6CA F70C
F000:F6F6  FEC6            inc    dh                          ; next row

loc_F6F8:    ; xrefs: F6C3 F6FF F703 F707
F000:F6F8  B402            mov    ah, 2                       ; function 02h — set cursor to DX
F000:F6FA  EBF4            jmp    loc_F6F0                    ; call INT 10h and exit

loc_F6FC:    ; xrefs: F6A8
F000:F6FC  80FA00          cmp    dl, 0                       ; BS: cursor already at column 0?
F000:F6FF  74F7            je     loc_F6F8                    ; yes → leave in place
F000:F701  FECA            dec    dl                          ; cursor one column left
F000:F703  EBF3            jmp    loc_F6F8                    ; set cursor

loc_F705:    ; xrefs: F6AC
F000:F705  B200            mov    dl, 0                       ; CR: column 0
F000:F707  EBEF            jmp    loc_F6F8                    ; set cursor

loc_F709:    ; xrefs: F6B0
F000:F709  80FE18          cmp    dh, 18h                     ; LF: last row (24)?
F000:F70C  75E8            jne    loc_F6F6                    ; no → next row
F000:F70E  EBBC            jmp    loc_F6CC                    ; yes → scroll screen

loc_F710:    ; xrefs: F6B4
F000:F710  B302            mov    bl, 2                       ; BEL: beep duration 2 (×64K cycles)
F000:F712  E81855          call   beep                        ; beep: F000:4C2D ≡ F400:0C2D (beep, ROM mirror at F4000)
F000:F715  EBDB            jmp    loc_F6F2                    ; exit

; ----------------------------------------------------------------------------------------------
; sub_F717 — POST error/result beep signalling (analog of IBM ERR_BEEP).
; In: DH=number of long beeps, DL=number of short beeps. Called from POST (E431, DX=1 — one short beep).
; Sound via beep F400:0C2D (mirror of F000:4C2D): 8253 channel 2 + port 61h. Flags and DS preserved.
; ----------------------------------------------------------------------------------------------
sub_F717:    ; xrefs: E431
F000:F717  9C              pushf                              ; save flags (IF)
F000:F718  FA              cli                                ; disable interrupts while beeping
F000:F719  1E              push   ds                          ; save DS
F000:F71A  E8CC07          call   sub_FEE9                    ; DS = 0040 — BIOS data area
F000:F71D  0AF6            or     dh, dh                      ; any long beeps?
F000:F71F  740B            je     loc_F72C                    ; no → short ones

loc_F721:    ; xrefs: F72A
F000:F721  B306            mov    bl, 6                       ; long beep duration = 6
F000:F723  E80755          call   beep                        ; beep (F000:4C2D ≡ F400:0C2D beep); CX=0 on exit

loc_F726:    ; xrefs: F726
F000:F726  E2FE            loop   loc_F726                    ; 64K-iteration pause between beeps
F000:F728  FECE            dec    dh                          ; long beep counter
F000:F72A  75F5            jne    loc_F721                    ; next long beep

loc_F72C:    ; xrefs: F71F F735
F000:F72C  B301            mov    bl, 1                       ; short beep duration = 1
F000:F72E  E8FC54          call   beep                        ; beep (beep F400:0C2D)

loc_F731:    ; xrefs: F731
F000:F731  E2FE            loop   loc_F731                    ; 64K-iteration pause
F000:F733  FECA            dec    dl                          ; short beep counter
F000:F735  75F5            jne    loc_F72C                    ; next short beep

loc_F737:    ; xrefs: F737
F000:F737  E2FE            loop   loc_F737                    ; extra pause after the series ...

loc_F739:    ; xrefs: F739
F000:F739  E2FE            loop   loc_F739                    ; ... another 64K iterations
F000:F73B  1F              pop    ds                          ; restore DS
F000:F73C  9D              popf                               ; restore flags
F000:F73D  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F73E — program DMA (8237) channel 2 for floppy drive transfer (INT 13h).
; In: AL=DMA mode (46h read, 4Ah write/format, 42h verify), ES:BX=buffer, DH=sector count.
; Writes to ports 0Ch/0Bh/04h/81h/05h/0Ah are trapped by NMI and emulated (see context.md).
; Continued at F000:FF3D. Out: CF=1 if the buffer crosses a 64 KB boundary, AX = end address.
; ----------------------------------------------------------------------------------------------
sub_F73E:    ; xrefs: ED3E ED47 ED59
F000:F73E  51              push   cx                          ; save CX
F000:F73F  E60C            out    0Ch, al                     ; port 0Ch — clear 8237 byte flip-flop (value irrelevant)
F000:F741  E60B            out    0Bh, al                     ; port 0Bh — 8237 mode register: channel 2 mode (AL)
F000:F743  8CC0            mov    ax, es                      ; AX = buffer segment ES
F000:F745  B104            mov    cl, 4                       ; 4 bits
F000:F747  D3C0            rol    ax, cl                      ; rotate: segment high nibble → bits 0–3 (page number)
F000:F749  8AE8            mov    ch, al                      ; CH = bits 16–19 of the physical address (page)
F000:F74B  24F0            and    al, 0F0h                    ; AL = low part of segment ×16
F000:F74D  03C3            add    ax, bx                      ; AX = low 16 bits of the physical address (segment×16 + BX)
F000:F74F  7302            jae    loc_F753                    ; no carry → page unchanged
F000:F751  FEC5            inc    ch                          ; carry → page +1

loc_F753:    ; xrefs: F74F
F000:F753  50              push   ax                          ; save start address for the 64 KB boundary check
F000:F754  E604            out    4, al                       ; port 04h — DMA channel 2 address, low byte
F000:F756  8AC4            mov    al, ah                      ; address high byte
F000:F758  E604            out    4, al                       ; port 04h — channel 2 address, high byte
F000:F75A  8AC5            mov    al, ch                      ; AL = page
F000:F75C  240F            and    al, 0Fh                     ; 4 page bits (1 MB address)
F000:F75E  E681            out    81h, al                     ; port 81h — DMA channel 2 page register
F000:F760  8AE6            mov    ah, dh                      ; AH = sector count
F000:F762  2AC0            sub    al, al                      ; AL = 0 → AX = sectors × 256
F000:F764  D1E8            shr    ax, 1                       ; AX = sectors × 128 (sector size unit N=0)
F000:F766  50              push   ax                          ; save sectors×128
F000:F767  BB0600          mov    bx, 6                       ; BX=6 → byte 3 of the diskette parameter table (sector size code N)
F000:F76A  E801F7          call   sub_EE6E                    ; AH = diskette parameter byte via INT 1Eh vector (0000:0078)
F000:F76D  8ACC            mov    cl, ah                      ; CL = N (2 → 512 bytes = 128 << 2)
F000:F76F  58              pop    ax                          ; AX = sectors × 128
F000:F770  E9CA07          jmp    loc_FF3D                    ; continued: byte count and boundary check (F000:FF3D)

; ----------------------------------------------------------------------------------------------
; dat_F773 — scan code translation table 01h..3Ah for Latin with Shift (upper case).
; Index = scan code-1 (xlat in INT 09h, F000:EB91). FFh = key without ASCII code
; (modifiers), 00h = extended code. Selected at F000:EB37 when RUS is off (0040:0018 bit 2 = 0).
; ----------------------------------------------------------------------------------------------
dat_F773:    ; xrefs: EB37
F000:F773  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:F774  21402324255E…   db     '!@#$%^&*()_+'              ; scan 02h–0Dh with Shift: top row !@#$%^&*()_+
F000:F780  0800            db     08h,00h                     ; scan 0Eh BackSpace → 08h; scan 0Fh Shift+Tab → 00h (extended code 0F00h)
F000:F782  515745525459…   db     'QWERTYUIOP{}'              ; scan 10h–1Bh with Shift: QWERTYUIOP{}
F000:F78E  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh; scan 1Dh Ctrl → FFh (modifier, no character)
F000:F790  415344464748…   db     'ASDFGHJKL:"~'              ; scan 1Eh–29h with Shift: ASDFGHJKL:"~
F000:F79C  FF              db     0FFh                        ; scan 2Ah left Shift → FFh (modifier)
F000:F79D  7C5A58435642…   db     '|ZXCVBNM<>?'               ; scan 2Bh–35h with Shift: |ZXCVBNM<>?
F000:F7A8  FF00FF20FF      db     0FFh,00h,0FFh,20h,0FFh      ; scan 36h right Shift FFh, 37h PrtSc 00h, 38h Alt FFh, 39h space 20h, 3Ah CapsLock FFh

; ----------------------------------------------------------------------------------------------
; dat_F7AD — scan code table 01h..3Ah for Russian letters without Shift (lower case, CP866).
; Selected at F000:EB8E when RUS mode is on (probably 0040:0018 bit 2 — toggled at F000:E94D).
; ЙЦУКЕН layout; letter ё in place of the «/» key (scan 35h).
; ----------------------------------------------------------------------------------------------
dat_F7AD:    ; xrefs: EB8E
F000:F7AD  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:F7AE  313233343536…   db     '1234567890-='              ; scan 02h–0Dh without Shift: digits 1234567890-=
F000:F7BA  0809            db     08h,09h                     ; scan 0Eh BackSpace → 08h; scan 0Fh Tab → 09h
F000:F7BC  A9E6E3AAA5AD…   db     'йцукенгшщзхъ'              ; scan 10h–1Bh: йцукенгшщзхъ (CP866 A9h,E6h,...)
F000:F7C8  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh; scan 1Dh Ctrl → FFh
F000:F7CA  E4EBA2A0AFE0…   db     'фывапролджэ`'              ; scan 1Eh–29h: фывапролджэ and ` (the ~ key left Latin)
F000:F7D6  FF              db     0FFh                        ; scan 2Ah left Shift → FFh
F000:F7D7  5CEFE7E1ACA8…   db     '\ячсмитьбюё'               ; scan 2Bh–35h: \ячсмитьбюё (ё instead of «/»)
F000:F7E2  FF2AFF20FF      db     0FFh,2Ah,0FFh,20h,0FFh      ; scan 36h right Shift FFh, 37h grey * → 2Ah, 38h Alt FFh, 39h space 20h, 3Ah CapsLock FFh

; ----------------------------------------------------------------------------------------------
; dat_F7E7 — scan code table 01h..3Ah for Russian letters with Shift (upper case, CP866).
; Selected at F000:EB41 with Shift and RUS on (0040:0018 bit 2).
; ----------------------------------------------------------------------------------------------
dat_F7E7:    ; xrefs: EB41
F000:F7E7  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:F7E8  21402324255E…   db     '!@#$%^&*()_+'              ; scan 02h–0Dh with Shift: !@#$%^&*()_+
F000:F7F4  0800            db     08h,00h                     ; scan 0Eh BackSpace → 08h; scan 0Fh Shift+Tab → 00h (extended code)
F000:F7F6  8996938A858D…   db     'ЙЦУКЕНГШЩЗХЪ'              ; scan 10h–1Bh with Shift: ЙЦУКЕНГШЩЗХЪ (CP866 89h,96h,...)
F000:F802  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh; scan 1Dh Ctrl → FFh
F000:F804  949B82808F90…   db     'ФЫВАПРОЛДЖЭ~'              ; scan 1Eh–29h with Shift: ФЫВАПРОЛДЖЭ and ~
F000:F810  FF              db     0FFh                        ; scan 2Ah left Shift → FFh
F000:F811  7C9F97918C88…   db     '|ЯЧСМИТЬБЮЁ'               ; scan 2Bh–35h with Shift: |ЯЧСМИТЬБЮЁ
F000:F81C  FF00FF20FF00…   db     0FFh,00h,0FFh,20h,0FFh,00h,00h,00h ; scan 36h–3Ah: FFh,00h,FFh,20h,FFh (as in the Latin Shift table); then 3 filler bytes 00h
F000:F824  00              db     29 dup (00h)                ; zero padding up to the standard INT 12h entry point (F000:F841)

; ----------------------------------------------------------------------------------------------
; INT12_MEMSIZE — INT 12h (standard IBM entry point F000:F841): RAM size.
; Out: AX = memory size in KB from 0040:0013.
; ----------------------------------------------------------------------------------------------
INT12_MEMSIZE:
F000:F841  FB              sti                                ; enable interrupts
F000:F842  1E              push   ds                          ; save caller's DS
F000:F843  E8A306          call   sub_FEE9                    ; DS = 0040h (BIOS data area)
F000:F846  A11300          mov    ax, word [13h]              ; AX = 0040:0013 — base memory size in KB (determined in POST)
F000:F849  1F              pop    ds                          ; restore DS
F000:F84A  CF              iret                               ; return from interrupt
F000:F84B  0000            db     00h,00h                     ; padding up to the INT 11h entry point (F000:F84D)

; ----------------------------------------------------------------------------------------------
; INT11_EQUIPMENT — INT 11h (IBM entry point F000:F84D): equipment list.
; Out: AX = configuration word 0040:0010.
; ----------------------------------------------------------------------------------------------
INT11_EQUIPMENT:
F000:F84D  FB              sti                                ; enable interrupts
F000:F84E  1E              push   ds                          ; save DS
F000:F84F  E89706          call   sub_FEE9                    ; DS = 0040h
F000:F852  A11000          mov    ax, word [10h]              ; AX = 0040:0010 — equipment word (floppy drives, video mode, COM/LPT)
F000:F855  1F              pop    ds                          ; restore DS
F000:F856  CF              iret                               ; return from interrupt
F000:F857  0000            db     00h,00h                     ; padding up to the INT 15h entry point (F000:F859)

; ----------------------------------------------------------------------------------------------
; INT15_CASSETTE — INT 15h (IBM entry point F000:F859): cassette tape interface, algorithm as in the IBM PC.
; AH=0/1 motor on/off (stubs here), 2 — read blocks into ES:BX (CX bytes),
; 3 — write blocks from ES:BX. Out: CF=1 error, AH = code (1 CRC, 2 data lost, 4 no data, 80h invalid function).
; Interval measurement/generation via channel 2 of the real 8253 mapped at F000:0A00..0A06 (channel 2 = F000:0A04).
; Exit via retf 2 discards the saved FLAGS to return the result CF.
; ----------------------------------------------------------------------------------------------
INT15_CASSETTE:
F000:F859  FA              cli                                ; disable interrupts while setting up the timer
F000:F85A  1E              push   ds                          ; save DS
F000:F85B  50              push   ax                          ; save AX (AH = function number)
F000:F85C  E461            in     al, 61h                     ; read port 61h (8255 port B emulated via NMI → F000:0003)
F000:F85E  24FD            and    al, 0FDh                    ; bit 1 = 0: speaker output off
F000:F860  0C01            or     al, 1                       ; bit 0 = 1: enable GATE2 of timer channel 2
F000:F862  E661            out    61h, al                     ; write port 61h
F000:F864  B0B6            mov    al, 0B6h                    ; 8253 control word: channel 2, LSB+MSB, mode 3 (square wave), binary count
F000:F866  E643            out    43h, al                     ; to port 43h (emulated → 8253 control register F000:0A06)
F000:F868  33C0            xor    ax, ax                      ; AX = 0 — initial count 0 = 65536
F000:F86A  2EA2040A        mov    byte cs:[0A04h], al         ; channel 2 count LSB directly to 8253 F000:0A04 (no NMI emulation)
F000:F86E  2EA2040A        mov    byte cs:[0A04h], al         ; channel 2 count MSB → timer free-runs with period 65536
F000:F872  E87406          call   sub_FEE9                    ; DS = 0040h
F000:F875  58              pop    ax                          ; restore AX (AH = function)
F000:F876  E81100          call   sub_F88A                    ; execute INT 15h function; result in AH/CF, DX = bytes read
F000:F879  50              push   ax                          ; save result AX
F000:F87A  B0B0            mov    al, 0B0h                    ; 8253 control word: channel 2, LSB+MSB, mode 0 — quiet the sound channel
F000:F87C  E643            out    43h, al                     ; to port 43h (8253 emulation)
F000:F87E  B80100          mov    ax, 1                       ; count = 1 for channel 2
F000:F881  E8CA01          call   sub_FA4E                    ; write 1 to F000:0A04 (LSB, MSB)
F000:F884  58              pop    ax                          ; restore result AX
F000:F885  1F              pop    ds                          ; restore DS
F000:F886  FB              sti                                ; enable interrupts
F000:F887  CA0200          retf   2                           ; far return discarding FLAGS from the stack — result CF preserved

; ----------------------------------------------------------------------------------------------
; sub_F88A — INT 15h function dispatcher.
; In: AH = function (0/1 — motor on/off, 2 — read, 3 — write), ES:BX buffer, CX count.
; The cassette motor is not software-controlled — functions 0/1 just return AH=0.
; ----------------------------------------------------------------------------------------------
sub_F88A:    ; xrefs: F876
F000:F88A  0AE4            or     ah, ah                      ; AH = 0? (motor on)
F000:F88C  7413            je     loc_F8A1                    ; yes — success, no action
F000:F88E  FECC            dec    ah                          ; AH = 1? (motor off)
F000:F890  740F            je     loc_F8A1                    ; yes — also a stub
F000:F892  FECC            dec    ah                          ; AH = 2? (read from tape)
F000:F894  740E            je     loc_F8A4                    ; yes — go read blocks
F000:F896  FECC            dec    ah                          ; AH = 3? (write to tape)
F000:F898  7503            jne    loc_F89D                    ; no — unknown function
F000:F89A  E92D01          jmp    loc_F9CA                    ; AH=3 — go write blocks

loc_F89D:    ; xrefs: F898
F000:F89D  B480            mov    ah, 80h                     ; error code 80h — invalid command
F000:F89F  F9              stc                                ; CF = 1 — error
F000:F8A0  C3              ret                                ; return

loc_F8A1:    ; xrefs: F88C F890
F000:F8A1  2AE4            sub    ah, ah                      ; AH = 0 — success (motor control functions)
F000:F8A3  C3              ret                                ; return (CF=0 after sub)

; ----------------------------------------------------------------------------------------------
; Tape read (AH=2): search for leader tone, sync byte 16h and receive 256-byte blocks with CRC.
; In: ES:BX — buffer, CX — bytes to read. Out: DX = bytes read, AH = code,
; CF = 1 on error. Up to 7 attempts to find the header (SI). Esc on the keyboard aborts the read.
; ----------------------------------------------------------------------------------------------
loc_F8A4:    ; xrefs: F894
F000:F8A4  53              push   bx                          ; save BX (buffer address)
F000:F8A5  51              push   cx                          ; save CX (length)
F000:F8A6  56              push   si                          ; save SI
F000:F8A7  BE0700          mov    si, 7                       ; SI = 7 — number of sync search attempts

loc_F8AA:    ; xrefs: F8F0 F8F8 F95E
F000:F8AA  2EA00500        mov    al, byte cs:[5]             ; read F000:0005 — real 8255 port C (analog of port 62h)
F000:F8AE  2410            and    al, 10h                     ; bit 4 = cassette data input
F000:F8B0  A26B00          mov    byte [6Bh], al              ; 0040:006B — last tape input state (standard IBM field)
F000:F8B3  BA7A3F          mov    dx, 3F7Ah                   ; DX = 3F7Ah — leader tone wait timeout (attempt count)

loc_F8B6:    ; xrefs: F8D0
F000:F8B6  2EF70600020020  test   word cs:[200h], 2000h       ; F000:0200 bit 13 — keyboard interrupt request (status flag instead of 8259)?
F000:F8BD  7408            je     loc_F8C7                    ; no keystrokes — keep waiting
F000:F8BF  E81307          call   sub_FFD5                    ; scan code present — read and acknowledge keyboard; ZF=1 if it is Esc (scan 01h)
F000:F8C2  7503            jne    loc_F8C7                    ; not Esc — continue
F000:F8C4  E99A00          jmp    loc_F961                    ; Esc — abort read with error 4

loc_F8C7:    ; xrefs: F8BD F8C2
F000:F8C7  4A              dec    dx                          ; decrement search timeout
F000:F8C8  7503            jne    loc_F8CD                    ; not expired yet — continue
F000:F8CA  E99400          jmp    loc_F961                    ; timeout — exit with error 4 (no data)

loc_F8CD:    ; xrefs: F8C8
F000:F8CD  E8CD00          call   sub_F99D                    ; wait for an edge on the tape input; BX = half-period length, CX=0 — no edge
F000:F8D0  E3E4            jcxz   loc_F8B6                    ; no edge — check keyboard and timeout again
F000:F8D2  BAEE02          mov    dx, 2EEh                    ; DX = 2EEh — threshold: shorter half-period = leader tone "one"
F000:F8D5  B90002          mov    cx, 200h                    ; CX = 200h — 512 consecutive leader tone half-periods required

loc_F8D8:    ; xrefs: F8FA F8FC
F000:F8D8  2EF70600020020  test   word cs:[200h], 2000h       ; F000:0200 bit 13 — scan code arrived from keyboard?
F000:F8DF  7408            je     loc_F8E9                    ; no — go on
F000:F8E1  E8F106          call   sub_FFD5                    ; read scan code, acknowledge; ZF=1 if Esc
F000:F8E4  7503            jne    loc_F8E9                    ; not Esc — continue
F000:F8E6  EB79            jmp    loc_F961                    ; Esc — abort read
F000:F8E8  90              db     90h                         ; nop — alignment after short jmp

loc_F8E9:    ; xrefs: F8DF F8E4
F000:F8E9  51              push   cx                          ; save leader tone half-period counter
F000:F8EA  E8B000          call   sub_F99D                    ; measure next half-period (BX)
F000:F8ED  0BC9            or     cx, cx                      ; CX = 0 — edge timed out?
F000:F8EF  59              pop    cx                          ; restore counter
F000:F8F0  74B8            je     loc_F8AA                    ; edge lost — restart search
F000:F8F2  3BD3            cmp    dx, bx                      ; compare threshold 2EEh with half-period length
F000:F8F4  E306            jcxz   loc_F8FC                    ; 512 short half-periods collected — leader tone found
F000:F8F6  7202            jb     loc_F8FA                    ; short half-period (leader tone bit 1) — keep counting
F000:F8F8  EBB0            jmp    loc_F8AA                    ; long half-period inside leader tone — glitch, search again

loc_F8FA:    ; xrefs: F8F6
F000:F8FA  E2DC            loop   loc_F8D8                    ; count 512 leader tone half-periods

loc_F8FC:    ; xrefs: F8F4
F000:F8FC  72DA            jb     loc_F8D8                    ; after leader tone wait for a long half-period (sync bit 0); continue while short
F000:F8FE  E89C00          call   sub_F99D                    ; skip second half of the sync bit
F000:F901  E86B00          call   sub_F96F                    ; read byte from tape into AL
F000:F904  3C16            cmp    al, 16h                     ; sync byte 16h?
F000:F906  7553            jne    loc_F95B                    ; no — next attempt
F000:F908  5E              pop    si                          ; synchronized: restore SI
F000:F909  59              pop    cx                          ; CX = requested length
F000:F90A  5B              pop    bx                          ; BX = buffer address
F000:F90B  51              push   cx                          ; remember original length to compute bytes read

loc_F90C:    ; xrefs: F947
F000:F90C  C7066900FFFF    mov    word [69h], 0FFFFh          ; 0040:0069 — CRC register = FFFFh (CRC-CCITT initial value)
F000:F912  BA0001          mov    dx, 100h                    ; DX = 256 — bytes per block

loc_F915:    ; xrefs: F933
F000:F915  2EF70600020020  test   word cs:[200h], 2000h       ; F000:0200 bit 13 — key pressed?
F000:F91C  7408            je     loc_F926                    ; no — continue reading
F000:F91E  E8B406          call   sub_FFD5                    ; read scan code; ZF=1 if Esc
F000:F921  7503            jne    loc_F926                    ; not Esc — continue
F000:F923  EB24            jmp    loc_F949                    ; Esc — abort as data loss (AH=2)
F000:F925  90              db     90h                         ; nop — alignment

loc_F926:    ; xrefs: F91C F921
F000:F926  E84600          call   sub_F96F                    ; read byte from tape (CRC updated in sub_FA58)
F000:F929  721E            jb     loc_F949                    ; CF=1 — signal lost, error
F000:F92B  E305            jcxz   loc_F932                    ; buffer already full — byte not stored but included in CRC
F000:F92D  268807          mov    byte es:[bx], al            ; store byte into buffer ES:BX
F000:F930  43              inc    bx                          ; next buffer address
F000:F931  49              dec    cx                          ; decrement remaining count

loc_F932:    ; xrefs: F92B
F000:F932  4A              dec    dx                          ; block byte counter
F000:F933  7FE0            jg     loc_F915                    ; until all 256 block bytes are read
F000:F935  E83700          call   sub_F96F                    ; read block CRC high byte
F000:F938  E83400          call   sub_F96F                    ; read block CRC low byte
F000:F93B  2AE4            sub    ah, ah                      ; AH = 0 (assume success)
F000:F93D  813E69000F1D    cmp    word [69h], 1D0Fh           ; CRC residue 1D0Fh indicates a valid block (CRC-CCITT with inverted checksum)
F000:F943  7506            jne    loc_F94B                    ; mismatch — CRC error (AH becomes 1)
F000:F945  E306            jcxz   loc_F94D                    ; all bytes read — finish
F000:F947  EBC3            jmp    loc_F90C                    ; read next block

loc_F949:    ; xrefs: F923 F929
F000:F949  B401            mov    ah, 1                       ; AH = 1 → becomes 2 after inc — data/signal lost

loc_F94B:    ; xrefs: F943
F000:F94B  FEC4            inc    ah                          ; AH = 1 (CRC error) or 2 (data lost)

loc_F94D:    ; xrefs: F945
F000:F94D  5A              pop    dx                          ; DX = original length
F000:F94E  2BD1            sub    dx, cx                      ; DX = bytes read = original length - remainder
F000:F950  50              push   ax                          ; save result code
F000:F951  F6C403          test   ah, 3                       ; error occurred (AH=1/2)?
F000:F954  7513            jne    loc_F969                    ; yes — exit immediately
F000:F956  E81600          call   sub_F96F                    ; success: read one more trailer byte (as in IBM BIOS)
F000:F959  EB0E            jmp    loc_F969                    ; go to common exit

loc_F95B:    ; xrefs: F906
F000:F95B  4E              dec    si                          ; sync byte not found — try again
F000:F95C  7403            je     loc_F961                    ; attempts exhausted — error
F000:F95E  E949FF          jmp    loc_F8AA                    ; search for leader tone again

loc_F961:    ; xrefs: F8C4 F8CA F8E6 F95C
F000:F961  5E              pop    si                          ; restore SI
F000:F962  59              pop    cx                          ; restore CX
F000:F963  5B              pop    bx                          ; restore BX
F000:F964  2BD2            sub    dx, dx                      ; DX = 0 bytes read
F000:F966  B404            mov    ah, 4                       ; AH = 4 — data not found (or aborted by Esc)
F000:F968  50              push   ax                          ; push result for common exit

loc_F969:    ; xrefs: F954 F959
F000:F969  58              pop    ax                          ; AX = result
F000:F96A  80FC01          cmp    ah, 1                       ; CF = (AH < 1)…
F000:F96D  F5              cmc                                ; …invert: CF = 1 when AH ≠ 0 (error)
F000:F96E  C3              ret                                ; return to INT 15h

; ----------------------------------------------------------------------------------------------
; sub_F96F — read a byte from tape.
; Each bit = two half-periods; sum > 5DCh ticks → bit 1, otherwise 0 (MSB first). CRC updated.
; Out: AL = byte, CF=1 — no edge (signal dropout). BX, CX preserved.
; ----------------------------------------------------------------------------------------------
sub_F96F:    ; xrefs: F901 F926 F935 F938 F956
F000:F96F  53              push   bx                          ; save BX
F000:F970  51              push   cx                          ; save CX
F000:F971  B108            mov    cl, 8                       ; CL = 8 bits

loc_F973:    ; xrefs: F991
F000:F973  51              push   cx                          ; save bit counter and byte being assembled (CH)
F000:F974  E82600          call   sub_F99D                    ; first half-period of the bit → BX
F000:F977  E320            jcxz   loc_F999                    ; no edge — error
F000:F979  53              push   bx                          ; remember first half-period length
F000:F97A  E82000          call   sub_F99D                    ; second half-period of the bit → BX
F000:F97D  58              pop    ax                          ; AX = first half-period
F000:F97E  E319            jcxz   loc_F999                    ; no edge — error
F000:F980  03D8            add    bx, ax                      ; BX = whole bit length (in 8253 ticks)
F000:F982  81FBDC05        cmp    bx, 5DCh                    ; threshold 5DCh (1500 ticks) between bits 0 and 1
F000:F986  F5              cmc                                ; CF = 1 if the bit is long (one)
F000:F987  9F              lahf                               ; save CF in AH
F000:F988  59              pop    cx                          ; restore counter and byte
F000:F989  D0D5            rcl    ch, 1                       ; shift bit into CH (MSB first)
F000:F98B  9E              sahf                               ; CF = bit value for CRC
F000:F98C  E8C900          call   sub_FA58                    ; update CRC 0040:0069 with this bit
F000:F98F  FEC9            dec    cl                          ; next bit
F000:F991  75E0            jne    loc_F973                    ; until 8 bits
F000:F993  8AC5            mov    al, ch                      ; AL = received byte
F000:F995  F8              clc                                ; CF = 0 — success

loc_F996:    ; xrefs: F99B
F000:F996  59              pop    cx                          ; restore CX
F000:F997  5B              pop    bx                          ; restore BX
F000:F998  C3              ret                                ; return

loc_F999:    ; xrefs: F977 F97E
F000:F999  59              pop    cx                          ; discard saved bit CX
F000:F99A  F9              stc                                ; CF = 1 — read error
F000:F99B  EBF9            jmp    loc_F996                    ; go to common exit

; ----------------------------------------------------------------------------------------------
; sub_F99D — measure a half-period of the tape signal.
; Waits for bit 4 of F000:0005 to change (cassette input, like bit 4 of IBM port 62h), then
; latches channel 2 of the real 8253 (F000:0A06 ← 80h) and reads the count from F000:0A04.
; Out: BX = elapsed time (previous - current count), 0040:0067 = current count; CX=0 — timeout.
; ----------------------------------------------------------------------------------------------
sub_F99D:    ; xrefs: F8CD F8EA F8FE F974 F97A
F000:F99D  B96400          mov    cx, 64h                     ; CX = 100 — edge wait timeout
F000:F9A0  8A266B00        mov    ah, byte [6Bh]              ; AH = previous input state (0040:006B)

loc_F9A4:    ; xrefs: F9AC
F000:F9A4  2EA00500        mov    al, byte cs:[5]             ; F000:0005 — 8255 port C (cassette input)
F000:F9A8  2410            and    al, 10h                     ; isolate bit 4 — tape data
F000:F9AA  3AC4            cmp    al, ah                      ; compare with previous state
F000:F9AC  E1F6            loope  loc_F9A4                    ; wait for a level change (edge), at most CX iterations
F000:F9AE  A26B00          mov    byte [6Bh], al              ; store new input state in 0040:006B
F000:F9B1  2EC606060A80    mov    byte cs:[0A06h], 80h        ; 8253 F000:0A06 ← 80h: channel 2 counter latch command
F000:F9B7  2EA0040A        mov    al, byte cs:[0A04h]         ; latched channel 2 count LSB
F000:F9BB  2E8A26040A      mov    ah, byte cs:[0A04h]         ; latched count MSB
F000:F9C0  8B1E6700        mov    bx, word [67h]              ; BX = count at the previous edge (0040:0067)
F000:F9C4  2BD8            sub    bx, ax                      ; BX = half-period length (counter counts down)
F000:F9C6  A36700          mov    word [67h], ax              ; 0040:0067 = current count for the next measurement
F000:F9C9  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Tape write (AH=3): leader tone of 2048 ones, sync bit 0, sync byte 16h,
; 256-byte blocks from ES:BX (CX bytes; last block padded) with inverted CRC,
; then a trailer of 32 ones. Signal generated by OUT2 of timer channel 2 (F000:0A04).
; ----------------------------------------------------------------------------------------------
loc_F9CA:    ; xrefs: F89A
F000:F9CA  53              push   bx                          ; save BX (buffer)
F000:F9CB  51              push   cx                          ; save CX (length)
F000:F9CC  B8E803          mov    ax, 3E8h                    ; initial channel 2 count = 3E8h (bit 1 period)
F000:F9CF  E87C00          call   sub_FA4E                    ; load count into 8253 F000:0A04
F000:F9D2  B90008          mov    cx, 800h                    ; CX = 800h — 2048 leader tone bits

loc_F9D5:    ; xrefs: F9D9
F000:F9D5  F9              stc                                ; bit 1
F000:F9D6  E85B00          call   sub_FA34                    ; output bit
F000:F9D9  E2FA            loop   loc_F9D5                    ; whole leader tone
F000:F9DB  F8              clc                                ; bit 0 — sync bit
F000:F9DC  E85500          call   sub_FA34                    ; output sync bit
F000:F9DF  59              pop    cx                          ; restore CX (length)
F000:F9E0  5B              pop    bx                          ; restore BX (buffer)
F000:F9E1  B016            mov    al, 16h                     ; sync byte 16h
F000:F9E3  E83700          call   sub_FA1D                    ; write sync byte

loc_F9E6:    ; xrefs: FA0D
F000:F9E6  C7066900FFFF    mov    word [69h], 0FFFFh          ; 0040:0069 — CRC = FFFFh at the start of each block
F000:F9EC  BA0001          mov    dx, 100h                    ; DX = 256 bytes per block

loc_F9EF:    ; xrefs: F9FA
F000:F9EF  268A07          mov    al, byte es:[bx]            ; next byte from buffer ES:BX
F000:F9F2  E82800          call   sub_FA1D                    ; write byte (updating CRC)
F000:F9F5  E302            jcxz   loc_F9F9                    ; data exhausted — repeat last byte to end of block
F000:F9F7  43              inc    bx                          ; next buffer byte
F000:F9F8  49              dec    cx                          ; decrement remaining count

loc_F9F9:    ; xrefs: F9F5
F000:F9F9  4A              dec    dx                          ; block byte counter
F000:F9FA  7FF3            jg     loc_F9EF                    ; until 256
F000:F9FC  A16900          mov    ax, word [69h]              ; AX = accumulated CRC
F000:F9FF  F7D0            not    ax                          ; invert CRC (hence residue = 1D0Fh on read)
F000:FA01  50              push   ax                          ; save CRC
F000:FA02  86E0            xchg   al, ah                      ; high byte first
F000:FA04  E81600          call   sub_FA1D                    ; write CRC high byte
F000:FA07  58              pop    ax                          ; AX = CRC
F000:FA08  E81200          call   sub_FA1D                    ; write CRC low byte
F000:FA0B  0BC9            or     cx, cx                      ; data remaining?
F000:FA0D  75D7            jne    loc_F9E6                    ; yes — next block
F000:FA0F  51              push   cx                          ; save CX (=0)
F000:FA10  B92000          mov    cx, 20h                     ; CX = 32 trailer bits

loc_FA13:    ; xrefs: FA17
F000:FA13  F9              stc                                ; bit 1
F000:FA14  E81D00          call   sub_FA34                    ; output trailer bit
F000:FA17  E2FA            loop   loc_FA13                    ; all 32
F000:FA19  59              pop    cx                          ; restore CX
F000:FA1A  2BC0            sub    ax, ax                      ; AX = 0, CF = 0 — success
F000:FA1C  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_FA1D — write byte AL to tape (MSB first), updating CRC 0040:0069.
; Preserves AX, CX.
; ----------------------------------------------------------------------------------------------
sub_FA1D:    ; xrefs: F9E3 F9F2 FA04 FA08
F000:FA1D  51              push   cx                          ; save CX
F000:FA1E  50              push   ax                          ; save AX
F000:FA1F  8AE8            mov    ch, al                      ; CH = byte to write
F000:FA21  B108            mov    cl, 8                       ; CL = 8 bits

loc_FA23:    ; xrefs: FA2F
F000:FA23  D0C5            rol    ch, 1                       ; next (high) bit → CF
F000:FA25  9C              pushf                              ; save CF for CRC
F000:FA26  E80B00          call   sub_FA34                    ; output bit CF to tape
F000:FA29  9D              popf                               ; CF = bit again
F000:FA2A  E82B00          call   sub_FA58                    ; update CRC with this bit
F000:FA2D  FEC9            dec    cl                          ; next bit
F000:FA2F  75F2            jne    loc_FA23                    ; until 8
F000:FA31  58              pop    ax                          ; restore AX
F000:FA32  59              pop    cx                          ; restore CX
F000:FA33  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_FA34 — write one bit to tape. In: CF = bit.
; Period: 1 → 3E8h ticks, 0 → 1F4h. Waits for the current OUT2 period of channel 2 to end
; (bit 5 of F000:0005, like bit 5 of IBM port 62h) and loads the new count into F000:0A04 (falls through to sub_FA4E).
; ----------------------------------------------------------------------------------------------
sub_FA34:    ; xrefs: F9D6 F9DC FA14 FA26
F000:FA34  B8E803          mov    ax, 3E8h                    ; count for bit 1 (3E8h)
F000:FA37  7203            jb     loc_FA3C                    ; CF=1 — bit 1
F000:FA39  B8F401          mov    ax, 1F4h                    ; count for bit 0 (1F4h)

loc_FA3C:    ; xrefs: FA37
F000:FA3C  50              push   ax                          ; save count

loc_FA3D:    ; xrefs: FA43
F000:FA3D  2EA00500        mov    al, byte cs:[5]             ; F000:0005 — 8255 port C
F000:FA41  2420            and    al, 20h                     ; bit 5 — timer channel 2 OUT2 output
F000:FA43  74F8            je     loc_FA3D                    ; wait for OUT2 high

loc_FA45:    ; xrefs: FA4B
F000:FA45  2EA00500        mov    al, byte cs:[5]             ; F000:0005 — 8255 port C
F000:FA49  2420            and    al, 20h                     ; bit 5 — OUT2
F000:FA4B  75F8            jne    loc_FA45                    ; wait for OUT2 falling edge (end of period)
F000:FA4D  58              pop    ax                          ; AX = count for the next bit

; ----------------------------------------------------------------------------------------------
; sub_FA4E — load count AX into channel 2 of the real 8253 (F000:0A04): LSB, then MSB.
; ----------------------------------------------------------------------------------------------
sub_FA4E:    ; xrefs: F881 F9CF
F000:FA4E  2EA2040A        mov    byte cs:[0A04h], al         ; channel 2 count LSB → F000:0A04
F000:FA52  2E8826040A      mov    byte cs:[0A04h], ah         ; channel 2 count MSB → F000:0A04
F000:FA57  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_FA58 — update CRC-CCITT (polynomial 1021h) at 0040:0069 with one bit.
; In: CF = data bit. Clobbers AX and flags.
; ----------------------------------------------------------------------------------------------
sub_FA58:    ; xrefs: F98C FA2A
F000:FA58  A16900          mov    ax, word [69h]              ; AX = current CRC (0040:0069)
F000:FA5B  D1D8            rcr    ax, 1                       ; data bit → AX bit 15, former bit 0 → CF
F000:FA5D  D1D0            rcl    ax, 1                       ; restore AX; OF = data bit XOR CRC high bit
F000:FA5F  F8              clc                                ; CF = 0 (default bit shifted in)
F000:FA60  7104            jno    loc_FA66                    ; bits equal — no XOR
F000:FA62  351008          xor    ax, 810h                    ; XOR 0810h + 1 shifted in = XOR with polynomial 1021h
F000:FA65  F9              stc                                ; CF = 1 → low bit = 1 after rcl

loc_FA66:    ; xrefs: FA60
F000:FA66  D1D0            rcl    ax, 1                       ; shift CRC left
F000:FA68  A36900          mov    word [69h], ax              ; store CRC in 0040:0069
F000:FA6B  C3              ret                                ; return
F000:FA6C  0000            db     00h,00h                     ; padding up to the font at the standard address F000:FA6E

; ----------------------------------------------------------------------------------------------
; font_lo — 8×8 font for characters 00h–7Fh at the standard IBM address F000:FA6E (8 bytes per character, top to bottom,
; high bit = leftmost pixel). Used by software text rendering (F400:0509/05F0);
; characters 80h–FFh (CP866) are in font_hi F400:1C00, pointed to by the INT 1Fh vector.
; ----------------------------------------------------------------------------------------------
font_lo:    ; xrefs: F509 F5F0
F000:FA6E  000000000000…   db     00h,00h,00h,00h,00h,00h,00h,00h ; glyph 00h: blank character (NUL)
F000:FA76  7E81A581BD99…   db     7Eh,81h,0A5h,81h,0BDh,99h,81h,7Eh ; glyph 01h: ☺ white face
F000:FA7E  7EFFDBFFC3E7…   db     7Eh,0FFh,0DBh,0FFh,0C3h,0E7h,0FFh,7Eh ; glyph 02h: ☻ black face
F000:FA86  6CFEFEFE7C38…   db     6Ch,0FEh,0FEh,0FEh,7Ch,38h,10h,00h ; glyph 03h: ♥ hearts
F000:FA8E  10387CFE7C38…   db     10h,38h,7Ch,0FEh,7Ch,38h,10h,08h ; glyph 04h: ♦ diamonds (last byte 08h — stray pixel, IBM has 00h)
F000:FA96  387C38FEFE7C…   db     38h,7Ch,38h,0FEh,0FEh,7Ch,38h,7Ch ; glyph 05h: ♣ clubs
F000:FA9E  1010387CFE7C…   db     10h,10h,38h,7Ch,0FEh,7Ch,38h,7Ch ; glyph 06h: ♠ spades
F000:FAA6  0000183C3C18…   db     00h,00h,18h,3Ch,3Ch,18h,00h,00h ; glyph 07h: • bullet
F000:FAAE  FFFFE7C3C3E7…   db     0FFh,0FFh,0E7h,0C3h,0C3h,0E7h,0FFh,0FFh ; glyph 08h: ◘ inverse bullet
F000:FAB6  003C66424266…   db     00h,3Ch,66h,42h,42h,66h,3Ch,00h ; glyph 09h: ○ circle
F000:FABE  FFC399BDBD99…   db     0FFh,0C3h,99h,0BDh,0BDh,99h,0C3h,0FFh ; glyph 0Ah: ◙ inverse circle
F000:FAC6  0F070F7DCCCC…   db     0Fh,07h,0Fh,7Dh,0CCh,0CCh,0CCh,78h ; glyph 0Bh: ♂ male sign
F000:FACE  3C6666663C18…   db     3Ch,66h,66h,66h,3Ch,18h,7Eh,18h ; glyph 0Ch: ♀ female sign
F000:FAD6  3F333F303070…   db     3Fh,33h,3Fh,30h,30h,70h,0F0h,0E0h ; glyph 0Dh: ♪ note
F000:FADE  7F637F636367…   db     7Fh,63h,7Fh,63h,63h,67h,0E6h,0C0h ; glyph 0Eh: ♫ double note
F000:FAE6  995A3CE7E73C…   db     99h,5Ah,3Ch,0E7h,0E7h,3Ch,5Ah,99h ; glyph 0Fh: ☼ sun
F000:FAEE  80E0F8FEF8E0…   db     80h,0E0h,0F8h,0FEh,0F8h,0E0h,80h,00h ; glyph 10h: ► right triangle
F000:FAF6  020E3EFE3E0E…   db     02h,0Eh,3Eh,0FEh,3Eh,0Eh,02h,00h ; glyph 11h: ◄ left triangle
F000:FAFE  183C7E18187E…   db     18h,3Ch,7Eh,18h,18h,7Eh,3Ch,18h ; glyph 12h: ↕ up-down arrow
F000:FB06  666666666600…   db     66h,66h,66h,66h,66h,00h,66h,00h ; glyph 13h: ‼ double exclamation
F000:FB0E  7FDBDB7B1B1B…   db     7Fh,0DBh,0DBh,7Bh,1Bh,1Bh,1Bh,00h ; glyph 14h: ¶ pilcrow
F000:FB16  3E63386C6C38…   db     3Eh,63h,38h,6Ch,6Ch,38h,0CCh,78h ; glyph 15h: § section sign
F000:FB1E  000000007E7E…   db     00h,00h,00h,00h,7Eh,7Eh,7Eh,00h ; glyph 16h: ▬ thick bar
F000:FB26  183C7E187E3C…   db     18h,3Ch,7Eh,18h,7Eh,3Ch,18h,0FFh ; glyph 17h: ↨ up-down arrow with base
F000:FB2E  183C7E181818…   db     18h,3Ch,7Eh,18h,18h,18h,18h,00h ; glyph 18h: ↑ up arrow
F000:FB36  181818187E3C…   db     18h,18h,18h,18h,7Eh,3Ch,18h,00h ; glyph 19h: ↓ down arrow
F000:FB3E  00180CFE0C18…   db     00h,18h,0Ch,0FEh,0Ch,18h,00h,00h ; glyph 1Ah: → right arrow
F000:FB46  003060FE6030…   db     00h,30h,60h,0FEh,60h,30h,00h,00h ; glyph 1Bh: ← left arrow
F000:FB4E  0000C0C0C0FE…   db     00h,00h,0C0h,0C0h,0C0h,0FEh,00h,00h ; glyph 1Ch: ∟ right angle
F000:FB56  002466FF6624…   db     00h,24h,66h,0FFh,66h,24h,00h,00h ; glyph 1Dh: ↔ left-right arrow
F000:FB5E  00183C7EFFFF…   db     00h,18h,3Ch,7Eh,0FFh,0FFh,00h,00h ; glyph 1Eh: ▲ up triangle
F000:FB66  00FFFF7E3C18…   db     00h,0FFh,0FFh,7Eh,3Ch,18h,00h,00h ; glyph 1Fh: ▼ down triangle
F000:FB6E  000000000000…   db     00h,00h,00h,00h,00h,00h,00h,00h ; glyph 20h: space
F000:FB76  307878303000…   db     30h,78h,78h,30h,30h,00h,30h,00h ; glyph 21h: «!»
F000:FB7E  6C6C6C000000…   db     6Ch,6Ch,6Ch,00h,00h,00h,00h,00h ; glyph 22h: «"»
F000:FB86  6C6CFE6CFE6C…   db     6Ch,6Ch,0FEh,6Ch,0FEh,6Ch,6Ch,00h ; glyph 23h: «#»
F000:FB8E  307CC0780CF8…   db     30h,7Ch,0C0h,78h,0Ch,0F8h,30h,00h ; glyph 24h: «$»
F000:FB96  00C6CC183066…   db     00h,0C6h,0CCh,18h,30h,66h,0C6h,00h ; glyph 25h: «%»
F000:FB9E  386C3876DCCC…   db     38h,6Ch,38h,76h,0DCh,0CCh,76h,00h ; glyph 26h: «&»
F000:FBA6  6060C0000000…   db     60h,60h,0C0h,00h,00h,00h,00h,00h ; glyph 27h: «'»
F000:FBAE  183060606030…   db     18h,30h,60h,60h,60h,30h,18h,00h ; glyph 28h: «(»
F000:FBB6  603018181830…   db     60h,30h,18h,18h,18h,30h,60h,00h ; glyph 29h: «)»
F000:FBBE  00663CFF3C66…   db     00h,66h,3Ch,0FFh,3Ch,66h,00h,00h ; glyph 2Ah: «*»
F000:FBC6  003030FC3030…   db     00h,30h,30h,0FCh,30h,30h,00h,00h ; glyph 2Bh: «+»
F000:FBCE  000000000030…   db     00h,00h,00h,00h,00h,30h,30h,60h ; glyph 2Ch: «,»
F000:FBD6  000000FC0000…   db     00h,00h,00h,0FCh,00h,00h,00h,00h ; glyph 2Dh: «-»
F000:FBDE  000000000030…   db     00h,00h,00h,00h,00h,30h,30h,00h ; glyph 2Eh: «.»
F000:FBE6  060C183060C0…   db     06h,0Ch,18h,30h,60h,0C0h,80h,00h ; glyph 2Fh: «/»
F000:FBEE  7CC6CEDEF6E6…   db     7Ch,0C6h,0CEh,0DEh,0F6h,0E6h,7Ch,00h ; glyph 30h: «0»
F000:FBF6  307030303030…   db     30h,70h,30h,30h,30h,30h,0FCh,00h ; glyph 31h: «1»
F000:FBFE  78CC0C3860CC…   db     78h,0CCh,0Ch,38h,60h,0CCh,0FCh,00h ; glyph 32h: «2»
F000:FC06  78CC0C380CCC…   db     78h,0CCh,0Ch,38h,0Ch,0CCh,78h,00h ; glyph 33h: «3»
F000:FC0E  1C3C6CCCFE0C…   db     1Ch,3Ch,6Ch,0CCh,0FEh,0Ch,1Eh,00h ; glyph 34h: «4»
F000:FC16  FCC0F80C0CCC…   db     0FCh,0C0h,0F8h,0Ch,0Ch,0CCh,78h,00h ; glyph 35h: «5»
F000:FC1E  3860C0F8CCCC…   db     38h,60h,0C0h,0F8h,0CCh,0CCh,78h,00h ; glyph 36h: «6»
F000:FC26  FCCC0C183030…   db     0FCh,0CCh,0Ch,18h,30h,30h,30h,00h ; glyph 37h: «7»
F000:FC2E  78CCCC78CCCC…   db     78h,0CCh,0CCh,78h,0CCh,0CCh,78h,00h ; glyph 38h: «8»
F000:FC36  78CCCC7C0C18…   db     78h,0CCh,0CCh,7Ch,0Ch,18h,70h,00h ; glyph 39h: «9»
F000:FC3E  003030000030…   db     00h,30h,30h,00h,00h,30h,30h,00h ; glyph 3Ah: «:»
F000:FC46  003030000030…   db     00h,30h,30h,00h,00h,30h,30h,60h ; glyph 3Bh: «;»
F000:FC4E  183060C06030…   db     18h,30h,60h,0C0h,60h,30h,18h,00h ; glyph 3Ch: «<»
F000:FC56  0000FC0000FC…   db     00h,00h,0FCh,00h,00h,0FCh,00h,00h ; glyph 3Dh: «=»
F000:FC5E  6030180C1830…   db     60h,30h,18h,0Ch,18h,30h,60h,00h ; glyph 3Eh: «>»
F000:FC66  78CC0C183000…   db     78h,0CCh,0Ch,18h,30h,00h,30h,00h ; glyph 3Fh: «?»
F000:FC6E  7CC6DEDEDEC0…   db     7Ch,0C6h,0DEh,0DEh,0DEh,0C0h,78h,00h ; glyph 40h: «@»
F000:FC76  3078CCCCFCCC…   db     30h,78h,0CCh,0CCh,0FCh,0CCh,0CCh,00h ; glyph 41h: «A»
F000:FC7E  FC66667C6666…   db     0FCh,66h,66h,7Ch,66h,66h,0FCh,00h ; glyph 42h: «B»
F000:FC86  3C66C0C0C066…   db     3Ch,66h,0C0h,0C0h,0C0h,66h,3Ch,00h ; glyph 43h: «C»
F000:FC8E  F86C6666666C…   db     0F8h,6Ch,66h,66h,66h,6Ch,0F8h,00h ; glyph 44h: «D»
F000:FC96  FE6268786862…   db     0FEh,62h,68h,78h,68h,62h,0FEh,00h ; glyph 45h: «E»
F000:FC9E  FE6268786860…   db     0FEh,62h,68h,78h,68h,60h,0F0h,00h ; glyph 46h: «F»
F000:FCA6  3C66C0C0CE66…   db     3Ch,66h,0C0h,0C0h,0CEh,66h,3Eh,00h ; glyph 47h: «G»
F000:FCAE  CCCCCCFCCCCC…   db     0CCh,0CCh,0CCh,0FCh,0CCh,0CCh,0CCh,00h ; glyph 48h: «H»
F000:FCB6  783030303030…   db     78h,30h,30h,30h,30h,30h,78h,00h ; glyph 49h: «I»
F000:FCBE  1E0C0C0C0CCC…   db     1Eh,0Ch,0Ch,0Ch,0Ch,0CCh,78h,00h ; glyph 4Ah: «J»
F000:FCC6  E6666C786C66…   db     0E6h,66h,6Ch,78h,6Ch,66h,0E6h,00h ; glyph 4Bh: «K»
F000:FCCE  F06060606266…   db     0F0h,60h,60h,60h,62h,66h,0FEh,00h ; glyph 4Ch: «L»
F000:FCD6  C6EEFEFED6C6…   db     0C6h,0EEh,0FEh,0FEh,0D6h,0C6h,0C6h,00h ; glyph 4Dh: «M»
F000:FCDE  C6E6F6DECEC6…   db     0C6h,0E6h,0F6h,0DEh,0CEh,0C6h,0C6h,00h ; glyph 4Eh: «N»
F000:FCE6  386CC6C6C66C…   db     38h,6Ch,0C6h,0C6h,0C6h,6Ch,38h,00h ; glyph 4Fh: «O»
F000:FCEE  FC66667C6060…   db     0FCh,66h,66h,7Ch,60h,60h,0F0h,00h ; glyph 50h: «P»
F000:FCF6  78CCCCCCDC78…   db     78h,0CCh,0CCh,0CCh,0DCh,78h,1Ch,00h ; glyph 51h: «Q»
F000:FCFE  FC66667C6C66…   db     0FCh,66h,66h,7Ch,6Ch,66h,0E6h,00h ; glyph 52h: «R»
F000:FD06  78CCE0701CCC…   db     78h,0CCh,0E0h,70h,1Ch,0CCh,78h,00h ; glyph 53h: «S»
F000:FD0E  FCB430303030…   db     0FCh,0B4h,30h,30h,30h,30h,78h,00h ; glyph 54h: «T»
F000:FD16  CCCCCCCCCCCC…   db     0CCh,0CCh,0CCh,0CCh,0CCh,0CCh,0FCh,00h ; glyph 55h: «U»
F000:FD1E  CCCCCCCCCC78…   db     0CCh,0CCh,0CCh,0CCh,0CCh,78h,30h,00h ; glyph 56h: «V»
F000:FD26  C6C6C6D6FEEE…   db     0C6h,0C6h,0C6h,0D6h,0FEh,0EEh,0C6h,00h ; glyph 57h: «W»
F000:FD2E  C6C66C38386C…   db     0C6h,0C6h,6Ch,38h,38h,6Ch,0C6h,00h ; glyph 58h: «X»
F000:FD36  CCCCCC783030…   db     0CCh,0CCh,0CCh,78h,30h,30h,78h,00h ; glyph 59h: «Y»
F000:FD3E  FEC68C183266…   db     0FEh,0C6h,8Ch,18h,32h,66h,0FEh,00h ; glyph 5Ah: «Z»
F000:FD46  786060606060…   db     78h,60h,60h,60h,60h,60h,78h,00h ; glyph 5Bh: «[»
F000:FD4E  C06030180C06…   db     0C0h,60h,30h,18h,0Ch,06h,02h,00h ; glyph 5Ch: «\»
F000:FD56  781818181818…   db     78h,18h,18h,18h,18h,18h,78h,00h ; glyph 5Dh: «]»
F000:FD5E  10386CC60000…   db     10h,38h,6Ch,0C6h,00h,00h,00h,00h ; glyph 5Eh: «^»
F000:FD66  000000000000…   db     00h,00h,00h,00h,00h,00h,00h,0FFh ; glyph 5Fh: «_»
F000:FD6E  303018000000…   db     30h,30h,18h,00h,00h,00h,00h,00h ; glyph 60h: «`»
F000:FD76  0000780C7CCC…   db     00h,00h,78h,0Ch,7Ch,0CCh,76h,00h ; glyph 61h: «a»
F000:FD7E  E060607C6666…   db     0E0h,60h,60h,7Ch,66h,66h,0DCh,00h ; glyph 62h: «b»
F000:FD86  000078CCC0CC…   db     00h,00h,78h,0CCh,0C0h,0CCh,78h,00h ; glyph 63h: «c»
F000:FD8E  1C0C0C7CCCCC…   db     1Ch,0Ch,0Ch,7Ch,0CCh,0CCh,76h,00h ; glyph 64h: «d»
F000:FD96  000078CCFCC0…   db     00h,00h,78h,0CCh,0FCh,0C0h,78h,00h ; glyph 65h: «e»
F000:FD9E  386C60F06060…   db     38h,6Ch,60h,0F0h,60h,60h,0F0h,00h ; glyph 66h: «f»
F000:FDA6  000076CCCC7C…   db     00h,00h,76h,0CCh,0CCh,7Ch,0Ch,0F8h ; glyph 67h: «g»
F000:FDAE  E0606C766666…   db     0E0h,60h,6Ch,76h,66h,66h,0E6h,00h ; glyph 68h: «h»
F000:FDB6  300070303030…   db     30h,00h,70h,30h,30h,30h,78h,00h ; glyph 69h: «i»
F000:FDBE  0C000C0C0CCC…   db     0Ch,00h,0Ch,0Ch,0Ch,0CCh,0CCh,78h ; glyph 6Ah: «j»
F000:FDC6  E060666C786C…   db     0E0h,60h,66h,6Ch,78h,6Ch,0E6h,00h ; glyph 6Bh: «k»
F000:FDCE  703030303030…   db     70h,30h,30h,30h,30h,30h,78h,00h ; glyph 6Ch: «l»
F000:FDD6  0000CCFEFED6…   db     00h,00h,0CCh,0FEh,0FEh,0D6h,0C6h,00h ; glyph 6Dh: «m»
F000:FDDE  0000F8CCCCCC…   db     00h,00h,0F8h,0CCh,0CCh,0CCh,0CCh,00h ; glyph 6Eh: «n»
F000:FDE6  000078CCCCCC…   db     00h,00h,78h,0CCh,0CCh,0CCh,78h,00h ; glyph 6Fh: «o»
F000:FDEE  0000DC66667C…   db     00h,00h,0DCh,66h,66h,7Ch,60h,0F0h ; glyph 70h: «p»
F000:FDF6  000076CCCC7C…   db     00h,00h,76h,0CCh,0CCh,7Ch,0Ch,1Eh ; glyph 71h: «q»
F000:FDFE  0000DC766660…   db     00h,00h,0DCh,76h,66h,60h,0F0h,00h ; glyph 72h: «r»
F000:FE06  00007CC0780C…   db     00h,00h,7Ch,0C0h,78h,0Ch,0F8h,00h ; glyph 73h: «s»
F000:FE0E  10307C303034…   db     10h,30h,7Ch,30h,30h,34h,18h,00h ; glyph 74h: «t»
F000:FE16  0000CCCCCCCC…   db     00h,00h,0CCh,0CCh,0CCh,0CCh,76h,00h ; glyph 75h: «u»
F000:FE1E  0000CCCCCC78…   db     00h,00h,0CCh,0CCh,0CCh,78h,30h,00h ; glyph 76h: «v»
F000:FE26  0000C6D6FEFE…   db     00h,00h,0C6h,0D6h,0FEh,0FEh,6Ch,00h ; glyph 77h: «w»
F000:FE2E  0000C66C386C…   db     00h,00h,0C6h,6Ch,38h,6Ch,0C6h,00h ; glyph 78h: «x»
F000:FE36  0000CCCCCC7C…   db     00h,00h,0CCh,0CCh,0CCh,7Ch,0Ch,0F8h ; glyph 79h: «y»
F000:FE3E  0000FC983064…   db     00h,00h,0FCh,98h,30h,64h,0FCh,00h ; glyph 7Ah: «z»
F000:FE46  1C3030E03030…   db     1Ch,30h,30h,0E0h,30h,30h,1Ch,00h ; glyph 7Bh: «{»
F000:FE4E  181818001818…   db     18h,18h,18h,00h,18h,18h,18h,00h ; glyph 7Ch: «|»
F000:FE56  E030301C3030…   db     0E0h,30h,30h,1Ch,30h,30h,0E0h,00h ; glyph 7Dh: «}»
F000:FE5E  76DC00000000…   db     76h,0DCh,00h,00h,00h,00h,00h,00h ; glyph 7Eh: «~»
F000:FE66  0010386CC6C6…   db     00h,10h,38h,6Ch,0C6h,0C6h,0FEh,00h ; glyph 7Fh: ⌂ house (DEL)

; ----------------------------------------------------------------------------------------------
; INT1A_TIME — INT 1Ah (IBM entry point F000:FE6E): system tick-count clock.
; AH=0: CX:DX = 0040:006E:006C, AL = midnight rollover flag 0040:0070 (cleared);
; AH=1: set counter from CX:DX. Other functions ignored.
; ----------------------------------------------------------------------------------------------
INT1A_TIME:
F000:FE6E  FB              sti                                ; enable interrupts
F000:FE6F  1E              push   ds                          ; save DS
F000:FE70  E87600          call   sub_FEE9                    ; DS = 0040h
F000:FE73  0AE4            or     ah, ah                      ; AH = 0 — read time?
F000:FE75  7407            je     loc_FE7E                    ; yes
F000:FE77  FECC            dec    ah                          ; AH = 1 — set time?
F000:FE79  7416            je     loc_FE91                    ; yes

loc_FE7B:    ; xrefs: FE8F FE9F
F000:FE7B  FB              sti                                ; enable interrupts
F000:FE7C  1F              pop    ds                          ; restore DS
F000:FE7D  CF              iret                               ; return

loc_FE7E:    ; xrefs: FE75
F000:FE7E  FA              cli                                ; disable interrupts for an atomic counter read
F000:FE7F  A07000          mov    al, byte [70h]              ; AL = 0040:0070 — "day elapsed" flag
F000:FE82  C606700000      mov    byte [70h], 0               ; clear day flag
F000:FE87  8B0E6E00        mov    cx, word [6Eh]              ; CX = 0040:006E — tick counter high word
F000:FE8B  8B166C00        mov    dx, word [6Ch]              ; DX = 0040:006C — tick counter low word
F000:FE8F  EBEA            jmp    loc_FE7B                    ; go to exit

loc_FE91:    ; xrefs: FE79
F000:FE91  FA              cli                                ; disable interrupts
F000:FE92  89166C00        mov    word [6Ch], dx              ; 0040:006C = DX (low word)
F000:FE96  890E6E00        mov    word [6Eh], cx              ; 0040:006E = CX (high word)
F000:FE9A  C606700000      mov    byte [70h], 0               ; clear day flag 0040:0070
F000:FE9F  EBDA            jmp    loc_FE7B                    ; go to exit

; ----------------------------------------------------------------------------------------------
; dat_FEA1 — stub handler "mov ah,1 / iret": POST (F000:E192) fills all interrupt vectors with it
; before installing the real ones; an unsupported interrupt returns AH=1.
; ----------------------------------------------------------------------------------------------
dat_FEA1:    ; xrefs: E192
F000:FEA1  B401CF00        db     0B4h,01h,0CFh,00h           ; code: B4 01 = mov ah,1 ; CF = iret ; 00 — alignment

; ----------------------------------------------------------------------------------------------
; INT08_TIMER — INT 08h (IBM entry point F000:FEA5), called from the common handler F400:0400
; on bit 14 of F000:0200. Tick counter 0040:006C/6E, reset after 24 hours (1800B0h ticks),
; floppy motor-off timeout 0040:0040, call to user INT 1Ch.
; No EOI is sent — there is no 8259.
; ----------------------------------------------------------------------------------------------
INT08_TIMER:
F000:FEA5  FB              sti                                ; enable interrupts
F000:FEA6  1E              push   ds                          ; save DS
F000:FEA7  50              push   ax                          ; save AX
F000:FEA8  52              push   dx                          ; save DX
F000:FEA9  E83D00          call   sub_FEE9                    ; DS = 0040h
F000:FEAC  FF066C00        inc    word [6Ch]                  ; increment tick counter low word 0040:006C
F000:FEB0  7504            jne    loc_FEB6                    ; no carry — go on
F000:FEB2  FF066E00        inc    word [6Eh]                  ; carry into high word 0040:006E

loc_FEB6:    ; xrefs: FEB0
F000:FEB6  833E6E0018      cmp    word [6Eh], 18h             ; high word = 18h? (24 hours = 1800B0h ticks at 18.2 Hz)
F000:FEBB  7515            jne    loc_FED2                    ; no — not midnight
F000:FEBD  813E6C00B000    cmp    word [6Ch], 0B0h            ; low word = 0B0h?
F000:FEC3  750D            jne    loc_FED2                    ; no
F000:FEC5  2BC0            sub    ax, ax                      ; AX = 0
F000:FEC7  A36E00          mov    word [6Eh], ax              ; zero counter high word
F000:FECA  A36C00          mov    word [6Ch], ax              ; zero counter low word
F000:FECD  C606700001      mov    byte [70h], 1               ; 0040:0070 = 1 — midnight rollover flag

loc_FED2:    ; xrefs: FEBB FEC3
F000:FED2  FE0E4000        dec    byte [40h]                  ; 0040:0040 — ticks until floppy motor off
F000:FED6  750B            jne    loc_FEE3                    ; not expired yet
F000:FED8  80263F00F0      and    byte [3Fh], 0F0h            ; 0040:003F — clear "motor on" bits for drives 0–3
F000:FEDD  B00C            mov    al, 0Ch                     ; DOR = 0Ch: DMA/IRQ enabled, controller not in reset, motors off
F000:FEDF  BAF203          mov    dx, 3F2h                    ; port 3F2h — FDC digital output register (emulated via NMI)
F000:FEE2  EE              out    dx, al                      ; turn floppy motors off

loc_FEE3:    ; xrefs: FED6
F000:FEE3  CD1C            int    1Ch                         ; call user tick handler INT 1Ch
F000:FEE5  5A              pop    dx                          ; restore DX
F000:FEE6  58              pop    ax                          ; restore AX
F000:FEE7  1F              pop    ds                          ; restore DS
F000:FEE8  CF              iret                               ; return (no EOI — there is no interrupt controller)

; ----------------------------------------------------------------------------------------------
; sub_FEE9 — DS = 0040h (BIOS data area segment). AX preserved.
; ----------------------------------------------------------------------------------------------
sub_FEE9:    ; xrefs: E268 E2D8 E746 E831 E914 EC63 EF5A EFD8 F080 F2A9 F71A F843 F84F F872 FE70 FEA9
F000:FEE9  50              push   ax                          ; save AX
F000:FEEA  B84000          mov    ax, 40h                     ; AX = 0040h
F000:FEED  8ED8            mov    ds, ax                      ; DS = BIOS data area segment
F000:FEEF  58              pop    ax                          ; restore AX
F000:FEF0  C3              ret                                ; return
F000:FEF1  0000            db     00h,00h                     ; padding up to the vector table F000:FEF3

; ----------------------------------------------------------------------------------------------
; vector_table — handler offsets for INT 08h..0Fh (segment F000, F400 for INT 0Fh),
; copied into the vector table in POST (F000:E2B8). Standard IBM address F000:FEF3.
; ----------------------------------------------------------------------------------------------
vector_table:    ; xrefs: E2B8
F000:FEF3  A5FE            dw     INT08_TIMER                 ; INT 08h — timer, F000:FEA5
F000:FEF5  87E9            dw     INT09_KEYBOARD              ; INT 09h — keyboard, F000:E987
F000:FEF7  53FF            dw     DUMMY_IRET                  ; INT 0Ah — IRET stub (8259 cascade on IBM)
F000:FEF9  53FF            dw     DUMMY_IRET                  ; INT 0Bh — IRET stub (COM2)
F000:FEFB  53FF            dw     DUMMY_IRET                  ; INT 0Ch — IRET stub (COM1; probably overridden by a driver)
F000:FEFD  53FF            dw     DUMMY_IRET                  ; INT 0Dh — IRET stub (IRQ5, hard disk on XT)
F000:FEFF  57EF            dw     INT0E_DISKETTE_IRQ          ; INT 0Eh — floppy drive interrupt, F000:EF57
F000:FF01  0004            dw     0400h                       ; INT 0Fh — common hardware interrupt handler F400:0400 (segment F400 set at E1AD)

; ----------------------------------------------------------------------------------------------
; dat_FF03 — handler offsets for INT 10h..1Fh (segment F000), copied in POST (F000:E1BA).
; ----------------------------------------------------------------------------------------------
dat_FF03:    ; xrefs: E1BA
F000:FF03  65F0            dw     INT10_VIDEO                 ; INT 10h — video, F000:F065
F000:FF05  4DF8            dw     INT11_EQUIPMENT             ; INT 11h — equipment list, F000:F84D
F000:FF07  41F8            dw     INT12_MEMSIZE               ; INT 12h — memory size, F000:F841
F000:FF09  59EC            dw     INT13_DISKETTE              ; INT 13h — floppy drive, F000:EC59
F000:FF0B  39E7            dw     INT14_SERIAL                ; INT 14h — serial port, F000:E739
F000:FF0D  59F8            dw     INT15_CASSETTE              ; INT 15h — cassette, F000:F859
F000:FF0F  2EE8            dw     INT16_KEYBOARD              ; INT 16h — keyboard, F000:E82E
F000:FF11  D2EF            dw     INT17_PRINTER               ; INT 17h — printer, F000:EFD2
F000:FF13  0000            dw     0000h                       ; INT 18h — 0 (ROM BASIC on IBM); vector later set to the tape monitor F000:E47C
F000:FF15  F2E6            dw     INT19_BOOT                  ; INT 19h — OS bootstrap, F000:E6F2
F000:FF17  6EFE            dw     INT1A_TIME                  ; INT 1Ah — clock, F000:FE6E
F000:FF19  53FF            dw     DUMMY_IRET                  ; INT 1Bh — Ctrl-Break, IRET stub
F000:FF1B  53FF            dw     DUMMY_IRET                  ; INT 1Ch — user timer tick, IRET stub
F000:FF1D  A4F0            dw     video_params                ; INT 1Dh — pointer to 6845 video parameters F000:F0A4
F000:FF1F  C7EF            dw     diskette_params             ; INT 1Eh — pointer to diskette parameters F000:EFC7
F000:FF21  005C            dw     5C00h                       ; INT 1Fh — font for characters 80h–FFh: F000:5C00 = phys. F5C00 = font_hi F400:1C00 (CP866)

; ----------------------------------------------------------------------------------------------
; keypad_table — ASCII codes of the numeric keypad (scan 47h..53h) with NumLock/Shift; index = scan-46h-1.
; ----------------------------------------------------------------------------------------------
keypad_table:    ; xrefs: EB77
F000:FF23  3738392D3435…   db     '789-456+1230.'             ; scan 47h–53h: 7 8 9 - 4 5 6 + 1 2 3 0 .

; ----------------------------------------------------------------------------------------------
; dat_FF30 — extended codes (in AH, AL=0) of the numeric keypad without NumLock (Home, ↑, PgUp, ←, →, End...).
; Index = scan-47h; FFh — key without extended code (center 5 etc.).
; ----------------------------------------------------------------------------------------------
dat_FF30:    ; xrefs: EB5E
F000:FF30  474849FF4BFF…   db     47h,48h,49h,0FFh,4Bh,0FFh,4Dh,0FFh ; scan 47h Home, 48h ↑, 49h PgUp, 4Ah (grey -) FFh, 4Bh ←, 4Ch (5) FFh, 4Dh →, 4Eh (grey +) FFh
F000:FF38  4F50515253      db     'OPQRS'                     ; scan 4Fh End, 50h ↓, 51h PgDn, 52h Ins, 53h Del — extended codes = scan codes

; ----------------------------------------------------------------------------------------------
; loc_FF3D — end of DMA setup for INT 13h (continuation of sub_F73E, jumped to from F000:F770).
; In: AX = (sector count)·128, CL = sector size code N (byte 3 of the diskette parameter table);
; on the stack: buffer address and caller's CX. Programs the 8237 channel 2 count (port 05h, emulated),
; unmasks channel 2 (port 0Ah). Out: CF = 1 — buffer crosses a 64 KB boundary.
; ----------------------------------------------------------------------------------------------
loc_FF3D:    ; xrefs: F770
F000:FF3D  D3E0            shl    ax, cl                      ; AX = transfer length in bytes = sectors·128·2^N
F000:FF3F  48              dec    ax                          ; 8237 is programmed with length-1
F000:FF40  50              push   ax                          ; save length-1
F000:FF41  E605            out    5, al                       ; DMA channel 2 count low byte (port 05h)
F000:FF43  8AC4            mov    al, ah                      ; AL = high byte of length-1
F000:FF45  E605            out    5, al                       ; DMA channel 2 count high byte (port 05h)
F000:FF47  59              pop    cx                          ; CX = length-1
F000:FF48  58              pop    ax                          ; AX = 16-bit buffer address (saved at F753)
F000:FF49  03C1            add    ax, cx                      ; address+length-1: CF=1 on crossing a 64 KB boundary (DMA error)
F000:FF4B  59              pop    cx                          ; restore caller's CX (pushed at F73E)
F000:FF4C  B002            mov    al, 2                       ; mask command: unmask channel 2 (floppy drive)
F000:FF4E  E60A            out    0Ah, al                     ; port 0Ah — 8237 single mask register (emulated); flags unchanged
F000:FF50  C3              ret                                ; return with CF = 64 KB boundary crossing flag
F000:FF51  0000            db     00h,00h                     ; padding up to F000:FF53

; ----------------------------------------------------------------------------------------------
; DUMMY_IRET — empty interrupt handler (standard IBM address F000:FF53).
; ----------------------------------------------------------------------------------------------
DUMMY_IRET:
F000:FF53  CF              iret                               ; return from interrupt immediately

; ----------------------------------------------------------------------------------------------
; INT05_PRTSCR — INT 05h (IBM entry point F000:FF54): print screen to printer (INT 17h, LPT1).
; Status at 0050:0000: 1 — printing in progress, 0 — success, FFh — error.
; Characters are read via INT 10h AH=8 (25 rows × column count), cursor is restored.
; ----------------------------------------------------------------------------------------------
INT05_PRTSCR:
F000:FF54  FB              sti                                ; enable interrupts
F000:FF55  1E              push   ds                          ; save DS
F000:FF56  50              push   ax                          ; save AX
F000:FF57  53              push   bx                          ; save BX
F000:FF58  51              push   cx                          ; save CX
F000:FF59  52              push   dx                          ; save DX
F000:FF5A  B85000          mov    ax, 50h                     ; AX = 0050h
F000:FF5D  8ED8            mov    ds, ax                      ; DS = 0050h (print screen status byte 0050:0000)
F000:FF5F  803E000001      cmp    byte [0], 1                 ; print screen already in progress?
F000:FF64  745F            je     loc_FFC5                    ; yes — reentry not allowed, exit
F000:FF66  C606000001      mov    byte [0], 1                 ; status = 1 — printing in progress
F000:FF6B  B40F            mov    ah, 0Fh                     ; INT 10h AH=0Fh — get video mode
F000:FF6D  CD10            int    10h                         ; AH = column count, BH = active page
F000:FF6F  8ACC            mov    cl, ah                      ; CL = column count
F000:FF71  B519            mov    ch, 19h                     ; CH = 25 rows
F000:FF73  E85500          call   sub_FFCB                    ; line feed on printer before the copy
F000:FF76  51              push   cx                          ; save screen dimensions
F000:FF77  B403            mov    ah, 3                       ; INT 10h AH=3 — read cursor position
F000:FF79  CD10            int    10h                         ; DX = current cursor position
F000:FF7B  59              pop    cx                          ; restore CX (dimensions)
F000:FF7C  52              push   dx                          ; save cursor position for restore
F000:FF7D  33D2            xor    dx, dx                      ; start at position (0,0)

loc_FF7F:    ; xrefs: FF9E FFAD
F000:FF7F  B402            mov    ah, 2                       ; INT 10h AH=2 — set cursor to DH:DL
F000:FF81  CD10            int    10h                         ; set cursor
F000:FF83  B408            mov    ah, 8                       ; INT 10h AH=8 — read character/attribute under cursor
F000:FF85  CD10            int    10h                         ; AL = character (in graphics with software rendering — recognized by font)
F000:FF87  0AC0            or     al, al                      ; character 0 (not recognized)?
F000:FF89  7502            jne    loc_FF8D                    ; no — print as is
F000:FF8B  B020            mov    al, 20h                     ; replace 0 with space

loc_FF8D:    ; xrefs: FF89
F000:FF8D  52              push   dx                          ; save position
F000:FF8E  33D2            xor    dx, dx                      ; DX = 0 — printer LPT1
F000:FF90  32E4            xor    ah, ah                      ; INT 17h AH=0 — print character
F000:FF92  CD17            int    17h                         ; print character AL
F000:FF94  5A              pop    dx                          ; restore position
F000:FF95  F6C425          test   ah, 25h                     ; printer status: bit 0 timeout, bit 2 (reserved), bit 5 out of paper
F000:FF98  7521            jne    loc_FFBB                    ; printer error — abort
F000:FF9A  FEC2            inc    dl                          ; next column
F000:FF9C  3ACA            cmp    cl, dl                      ; end of line?
F000:FF9E  75DF            jne    loc_FF7F                    ; no — next character
F000:FFA0  32D2            xor    dl, dl                      ; column 0
F000:FFA2  8AE2            mov    ah, dl                      ; AH = 0 (probably a redundant instruction — sub_FFCB clobbers AX anyway)
F000:FFA4  52              push   dx                          ; save position
F000:FFA5  E82300          call   sub_FFCB                    ; line feed on printer
F000:FFA8  5A              pop    dx                          ; restore position
F000:FFA9  FEC6            inc    dh                          ; next screen row
F000:FFAB  3AEE            cmp    ch, dh                      ; all 25 rows?
F000:FFAD  75D0            jne    loc_FF7F                    ; no — continue
F000:FFAF  5A              pop    dx                          ; DX = original cursor position
F000:FFB0  B402            mov    ah, 2                       ; INT 10h AH=2
F000:FFB2  CD10            int    10h                         ; restore cursor
F000:FFB4  C606000000      mov    byte [0], 0                 ; status 0 — printing completed successfully
F000:FFB9  EB0A            jmp    loc_FFC5                    ; go to exit

loc_FFBB:    ; xrefs: FF98
F000:FFBB  5A              pop    dx                          ; DX = original cursor position
F000:FFBC  B402            mov    ah, 2                       ; INT 10h AH=2
F000:FFBE  CD10            int    10h                         ; restore cursor
F000:FFC0  C6060000FF      mov    byte [0], 0FFh              ; status FFh — print error

loc_FFC5:    ; xrefs: FF64 FFB9
F000:FFC5  5A              pop    dx                          ; restore DX
F000:FFC6  59              pop    cx                          ; restore CX
F000:FFC7  5B              pop    bx                          ; restore BX
F000:FFC8  58              pop    ax                          ; restore AX
F000:FFC9  1F              pop    ds                          ; restore DS
F000:FFCA  CF              iret                               ; return from interrupt

; ----------------------------------------------------------------------------------------------
; sub_FFCB — line feed on printer LPT1: outputs LF (0Ah), then CR (0Dh) via INT 17h
; (CR is printed by the tail at F000:E97E, which does the ret). Clobbers AX, DX=0.
; ----------------------------------------------------------------------------------------------
sub_FFCB:    ; xrefs: FF73 FFA5
F000:FFCB  33D2            xor    dx, dx                      ; DX = 0 — printer LPT1
F000:FFCD  B80A00          mov    ax, 0Ah                     ; AH = 0 (print), AL = 0Ah — LF
F000:FFD0  CD17            int    17h                         ; print LF
F000:FFD2  E9A9E9          jmp    loc_E97E                    ; tail at E97E: print CR (0Dh) and ret

; ----------------------------------------------------------------------------------------------
; sub_FFD5 — keyboard poll during tape operations.
; Reads the scan code from F000:0001 (8255 port A, analog of 60h) and acknowledges the keyboard by pulsing
; bits 7 and 5 in F000:0003 (8255 port B; bit 5 — clears keyboard interrupt request, cf. F400:043E).
; Out: AL = scan code, ZF = 1 if Esc pressed (scan 01h).
; ----------------------------------------------------------------------------------------------
sub_FFD5:    ; xrefs: F8BF F8E1 F91E
F000:FFD5  2EA00100        mov    al, byte cs:[1]             ; AL = scan code from F000:0001 (8255 port A)
F000:FFD9  50              push   ax                          ; save scan code
F000:FFDA  2EA00300        mov    al, byte cs:[3]             ; AL = current value of F000:0003 (8255 port B)
F000:FFDE  8AE0            mov    ah, al                      ; AH = original port B value
F000:FFE0  0CA0            or     al, 0A0h                    ; bits 7 (keyboard reset) and 5 (clear interrupt request) = 1
F000:FFE2  2EA20300        mov    byte cs:[3], al             ; assert acknowledge pulse
F000:FFE6  2E88260300      mov    byte cs:[3], ah             ; restore original port B value
F000:FFEB  58              pop    ax                          ; AL = scan code
F000:FFEC  3C01            cmp    al, 1                       ; Esc (scan 01h)? → ZF
F000:FFEE  C3              ret                                ; return
F000:FFEF  00              db     00h                         ; padding up to the reset vector F000:FFF0

; ----------------------------------------------------------------------------------------------
; POWER_ON — CPU reset vector (FFFF:0000 = F000:FFF0): jump to RESET F000:E05B.
; Followed by the ROM version date and the model type byte.
; ----------------------------------------------------------------------------------------------
POWER_ON:
F000:FFF0  EA5BE000F0      jmp    far RESET                   ; far jump to POST start F000:E05B
F000:FFF5  30312F30312F…   db     '01/01/91'                  ; ROM date «01/01/91» (standard IBM location F000:FFF5)
F000:FFFD  00FFCD          db     00h,0FFh,0CDh               ; 00h; FFh — model ID (as IBM PC); CDh — probably the checksum adjustment byte
