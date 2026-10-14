; ==============================================================================================
; BIOS of the Praktik PC, version 2.14-15 (2.14-15_dk/2.14-15_dk.rom, 16 KB, CRC32 8F2C3569)
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
; ## Version 2.14-15_dk: the 1990 factory BIOS
;
; The start of the main ROM (F000:E000) holds `00001 "МАГНИТ" 1990` ("MAGNIT" 1990), and the banner reads `ПЭВМ "Практик"` ("Praktik" PC). This is the earliest version available: the factory BIOS of the Kaniv Electromechanical Plant "Magnit" (Kaniv, Cherkasy Oblast). The overall architecture is the same as in 2.16-17: ports trapped through the NMI, peripherals emulated in software, chips in the F000:0000–0FFF window. The emulator design and the set of devices differ. Lines identical to 2.16-17 carry the same comments; the differences are described below and in the procedure headers.
;
; ## NMI handler
;
; - The NMI vector is F400:000A (`NMI_ENTRY`), which jumps to `NMI_HANDLER` at F400:006A. In 2.16-17 the vector points straight at the handler.
; - The handler saves 9 registers and sets DS = 0040h once for all port handlers. 2.16-17 saves 4 registers.
; - The port is looked up not in a 1024-byte table but with `repne scasw` over a list of 25 ports, `nmi_port_list` (F400:00C7). The handler address comes from `nmi_port_handlers` (F400:00F9). 3DAh comes first in the list and EOI (020h) last; the list is probably ordered by access frequency.
; - If the port is not in the list, OUT is ignored and IN returns FFh (F400:00AE).
; - F400:0000–0009 holds 5 words (05A7h, 000Ah, 0, 0069h, 0) that the BIOS code never reads. They are probably a header of the emulator module: the code length and two far pointers (the NMI entry and an empty `retf` procedure at F400:0069).
;
; ## Missing compared with 2.16-17
;
; - **8250 serial port emulation** (2F8–2FF, 3F8–3FF). A COM1 probe is built into POST (F000:E440), but port 3FAh is not emulated and reads as FFh, so COM1 is never found and INT 14h returns immediately. This is what the readme means by "no RS232 support".
; - **`detect_com_ports` and `beep` in segment F400.** The beep is a routine in the main ROM (F000:F73A). Because of it the keyboard layout tables are shifted by 1Eh (F791/F7CB/F805 instead of F773/F7AD/F7E7).
; - The emulator code ends at F400:05A8; everything from there up to the font (F400:1C00) is filled with FFh.
;
; ## Other differences
;
; - **INT 10h AH=0** programs the 6845 registers through ports 3D4/3D5 as IBM does, i.e. through the emulator. The emulator drops R0–R8, and the 3D8 port handler sets the timing from the tables at F400:0313. In 2.16-17 the BIOS writes to F000:0000/0002 directly. As a result all INT 10h functions in dk sit 4 bytes lower.
; - The video parameter table at F0A4 and the diskette parameters at EFC7 (first byte CFh, as in the IBM XT) differ from 2.16-17.
; - **Joystick (port 201h)** is simpler. IN returns 8255 port A as is; OUT pulses bit 4 of port B, probably triggering hardware one-shots. 2.16-17 simulates the axes in software.
; - **The special INT 0Fh exit** on a floppy interrupt during programmed transfer removes 12 bytes from the stack, not 22: the port 3F5 handler in dk saves nothing on the stack.
; - Return addresses for the stackless calls are at E04C/E04E instead of E06E/E070. The tape loader (INT 18h) is at F000:E48A.
; - Some POST register writes are word-sized instead of byte-sized: `mov word [601h]`, `mov word cs:[0A06h]`. They also hit the neighboring registers 0602h and 0A07h; 2.16-17 fixes this.
; - The last ROM byte (F000:FFFF = 47h) makes the byte sum of E000–FFFF zero.
;
; ## Sources
;
; - The BIOS files were taken from the post «Журнал восстановления Практика» ("Praktik restoration log") on the zxdesu site, 2016: https://zxdesu.byethost32.com/2016/07/28/%d0%b6%d1%83%d1%80%d0%bd%d0%b0%d0%bb-%d0%b2%d0%be%d1%81%d1%81%d1%82%d0%b0%d0%bd%d0%be%d0%b2%d0%bb%d0%b5%d0%bd%d0%b8%d1%8f-%d0%bf%d1%80%d0%b0%d0%ba%d1%82%d0%b8%d0%ba%d0%b0/
; - Description of the Praktik computer (PK8641) on retro-computer.ru: https://retro-computer.ru/item/PRAKTIK-PK8641.html


; ##############################################################################################
; SEGMENT F400 — first 8 KB of the ROM (phys. F4000-F5FFF, same as FC000-FDFFF / F000:C000-DFFF)
; ##############################################################################################

; ----------------------------------------------------------------------------------------------
; rom_header — 5 words at the start of the emulator segment (in my this is where port_index_table, 1 KB, lives).
; Probably a loadable module header: length 05A7h (= bytes 0002–05A8, all code after the length word),
; then two far "offset:segment" pointers with zero segment (filled in by the loader?):
; 000Ah:0 — NMI entry (NMI_ENTRY), 0069h:0 — empty far procedure (retf). BIOS code never reads these words.
; ----------------------------------------------------------------------------------------------
rom_header:
F400:0000  A705            dw     05A7h                       ; Probably module length: 05A7h bytes after this word (0002–05A8 — end of code, FFh beyond)
F400:0002  0A00            dw     000Ah                       ; NMI entry offset = 000Ah (NMI_ENTRY) — same value POST writes to the INT 2 vector (E197)
F400:0004  0000            dw     0000h                       ; Segment for offset 000Ah = 0 (probably patched at load time or unused)
F400:0006  6900            dw     0069h                       ; Offset of far stub retf F400:0069 (probably the module init entry — empty)
F400:0008  0000            dw     0000h                       ; Segment = 0 (as at F400:0004)

; ----------------------------------------------------------------------------------------------
; NMI_ENTRY — NMI entry point: INT 02h vector = F400:000A (set in POST, E197).
; Short jump to NMI_HANDLER F400:006A (in my the vector points directly to handler F400:046C).
; ----------------------------------------------------------------------------------------------
NMI_ENTRY:
F400:000A  EB5E            jmp    NMI_HANDLER                 ; NMI entry: jump to NMI_HANDLER (F400:006A)
F400:000C  90              db     90h                         ; NOP filler after the short jmp; INT0F_IRQ_DISPATCH starts at F400:000D

; ----------------------------------------------------------------------------------------------
; INT0F_IRQ_DISPATCH — common hardware interrupt handler (INT 0Fh vector = F400:000D), replaces the 8259.
; Reads request register F000:0200 (high byte): bit 15 — floppy (INT 0Eh), bit 14 — timer (INT 08h),
; bit 13 — keyboard (INT 09h), bit 12 — COM1 (INT 0Ch; in dk the INT 0Ch vector is an IRET stub, no RS-232).
; One source is serviced per entry, by priority. Special case: floppy IRQ during programmed-I/O
; FDC data transfer (0040:00B9 bit 3 = 0) — stack is unwound to the return address into NMI_HANDLER (F400:00AC).
; ----------------------------------------------------------------------------------------------
INT0F_IRQ_DISPATCH:
F400:000D  06              push   es                          ; Save ES of the interrupted program
F400:000E  1E              push   ds                          ; Save DS
F400:000F  50              push   ax                          ; Save AX
F400:0010  FC              cld                                ; Clear direction flag for string operations
F400:0011  B84000          mov    ax, 40h                     ; BIOS data area segment 0040h…
F400:0014  8ED8            mov    ds, ax                      ; …into DS
F400:0016  B800F0          mov    ax, 0F000h                  ; Hardware register segment F000h…
F400:0019  8EC0            mov    es, ax                      ; …into ES
F400:001B  26A10002        mov    ax, word es:[200h]          ; AX = interrupt request status register F000:0200 (AH = bits 15–8)
F400:001F  D0E4            shl    ah, 1                       ; Bit 15 → CF: request from floppy controller?
F400:0021  7316            jae    loc_0039                    ; No FDC request — check next source
F400:0023  A0B900          mov    al, byte [0B9h]             ; AL = 0040:00B9 — shadow copy of floppy control register F000:0601 (DOR)
F400:0026  A808            test   al, 8                       ; Bit 3 = 1 — no programmed FDC data transfer in progress?
F400:0028  750F            jne    loc_0039                    ; Yes — FDC IRQ not serviced here (polled in nmi_port_3F2/3F5), go to timer
F400:002A  83C40C          add    sp, 0Ch                     ; Drop 6 words (push es/ds/ax + interrupt IP/CS/FLAGS): top of stack is the return into NMI_HANDLER (00AC)
F400:002D  0C08            or     al, 8                       ; Restore bit 3 (leave programmed data transfer mode)
F400:002F  A2B900          mov    byte [0B9h], al             ; Update DOR shadow copy at 0040:00B9
F400:0032  26A20106        mov    byte es:[601h], al          ; …and write it to hardware floppy control register F000:0601
F400:0036  CD0E            int    0Eh                         ; Call floppy interrupt handler INT 0Eh (probably sets flag 0040:003E bit 7)
F400:0038  C3              ret                                ; Return directly to NMI_HANDLER (after call bx) — FDC operation complete

loc_0039:    ; xrefs: 0021 0028
F400:0039  D0E4            shl    ah, 1                       ; Bit 14 → CF: request from system timer (8253 channel 0)?
F400:003B  730A            jae    loc_0047                    ; No — check keyboard
F400:003D  26A00900        mov    al, byte es:[9]             ; Read F000:0009 — probably acknowledges/clears timer interrupt request
F400:0041  58              pop    ax                          ; Restore AX
F400:0042  1F              pop    ds                          ; Restore DS
F400:0043  07              pop    es                          ; Restore ES
F400:0044  CD08            int    8                           ; Call timer handler INT 08h (clock tick, 18.2 Hz)
F400:0046  CF              iret                               ; Return to interrupted program

loc_0047:    ; xrefs: 003B
F400:0047  D0E4            shl    ah, 1                       ; Bit 13 → CF: request from keyboard?
F400:0049  7314            jae    loc_005F                    ; No — check COM1
F400:004B  26A00300        mov    al, byte es:[3]             ; AL = F000:0003 — port B of the real 8255 (equivalent of port 61h)
F400:004F  0C20            or     al, 20h                     ; Set bit 5 — probably masks/acknowledges keyboard IRQ request
F400:0051  26A20300        mov    byte es:[3], al             ; Write to 8255 port B
F400:0055  CD09            int    9                           ; Call keyboard handler INT 09h (reads scan code from port 60h)
F400:0057  24DF            and    al, 0DFh                    ; Clear bit 5 (AL preserved by INT 09h; EOI to port 20h also clears this bit)
F400:0059  26A20300        mov    byte es:[3], al             ; Write 8255 port B back — enable next keyboard request
F400:005D  EB06            jmp    loc_0065                    ; To exit

loc_005F:    ; xrefs: 0049
F400:005F  D0E4            shl    ah, 1                       ; Bit 12 → CF: request from COM1 (8250)?
F400:0061  7302            jae    loc_0065                    ; No requests — exit
F400:0063  CD0C            int    0Ch                         ; Call INT 0Ch (COM1 IRQ); in dk the vector is the IRET stub F000:FF53

loc_0065:    ; xrefs: 005D 0061
F400:0065  58              pop    ax                          ; Restore AX
F400:0066  1F              pop    ds                          ; Restore DS
F400:0067  07              pop    es                          ; Restore ES
F400:0068  CF              iret                               ; Return from interrupt

; ----------------------------------------------------------------------------------------------
; Empty far procedure (retf). Unreachable from code (preceded by iret), referenced only from rom_header (word F400:0006).
; ----------------------------------------------------------------------------------------------
F400:0069  CB              db     0CBh                        ; retf — probably the module's empty far entry point (init), pointed to by F400:0006

; ----------------------------------------------------------------------------------------------
; NMI_HANDLER — NMI handler (via NMI_ENTRY F400:000A): software emulation of IBM PC I/O ports.
; F000:0200 — latch: bits 0–9 = port number, bit 10 = 1 on write (OUT), bit 11 = NMI caused by a port access.
; F000:0400/0401 — OUT data (even/odd bus byte). Port number is looked up with repne scasw in nmi_port_list
; (25 words, F400:00C7), handler address taken from nmi_port_handlers (F400:00F9); not found — "no device".
; Handler is called with ZF=1 on IN, ZF=0 on OUT; DS=0040, ES=F000, DX = latch, AX = port number, SI = handler
; address; 9 registers saved: [bp]=AX (IN result goes here), +2 BX, +4 CX, +6 DX, +8 SI, +0Ah DI, +0Ch BP, +0Eh DS, +10h ES.
; ----------------------------------------------------------------------------------------------
NMI_HANDLER:    ; xrefs: 000A
F400:006A  06              push   es                          ; Save ES (frame: [bp+10h])
F400:006B  1E              push   ds                          ; Save DS ([bp+0Eh]) — in dk DS=0040 is set here once for all handlers
F400:006C  55              push   bp                          ; Save BP ([bp+0Ch])
F400:006D  57              push   di                          ; Save DI ([bp+0Ah]) — needed for the nmi_port_list search
F400:006E  56              push   si                          ; Save SI ([bp+8]) — will hold the port handler address
F400:006F  52              push   dx                          ; Save DX ([bp+6]) — will hold a copy of the latch
F400:0070  51              push   cx                          ; Save CX ([bp+4]) — counter for repne scasw
F400:0071  53              push   bx                          ; Save BX ([bp+2])
F400:0072  50              push   ax                          ; Save interrupted program's AX ([bp+0] — handler writes IN result here)
F400:0073  8BEC            mov    bp, sp                      ; BP → saved register frame
F400:0075  B84000          mov    ax, 40h                     ; BIOS data area segment 0040h (emulator shadow registers 0040:009E–00BD)…
F400:0078  8ED8            mov    ds, ax                      ; …into DS — shared by all handlers (in my each handler set DS itself)
F400:007A  B800F0          mov    ax, 0F000h                  ; Hardware register segment F000h…
F400:007D  8EC0            mov    es, ax                      ; …into ES (ES stays F000 in all port handlers)
F400:007F  26A10002        mov    ax, word es:[200h]          ; AX = latch F000:0200: bits 0–9 — port, bit 10 — OUT, bit 11 — NMI from port access
F400:0083  F6C408          test   ah, 8                       ; Bit 11: NMI caused by an I/O port access?
F400:0086  7430            je     loc_00B8                    ; No (other NMI source) — just acknowledge and exit
F400:0088  8BD0            mov    dx, ax                      ; DX = full copy of the latch (DH bit 2 = OUT, bit 3 = port) — available to handlers
F400:008A  25FF03          and    ax, 3FFh                    ; AX = port number 000–3FFh
F400:008D  BFC700          mov    di, 0C7h                    ; DI → nmi_port_list (F400:00C7) — list of emulated ports
F400:0090  B91900          mov    cx, 19h                     ; CX = 25 (19h) ports in the list
F400:0093  FC              cld                                ; Search forward through the list
F400:0094  06              push   es                          ; Save ES = F000
F400:0095  8CCB            mov    bx, cs                      ; ES = CS = F400 — the list is in ROM…
F400:0097  8EC3            mov    es, bx                      ; …ES = F400 for scasw
F400:0099  F2AF            repne scasw ax, word es:[di]       ; Linear search for the port number in the list (in my — direct index into a 1024-byte table)
F400:009B  07              pop    es                          ; Restore ES
F400:009C  7510            jne    loc_00AE                    ; Port not in list — "no device" path
F400:009E  81EFC900        sub    di, 0C9h                    ; DI = 2*index of the found port (scasw left DI past the matching word: DI−00C9h)
F400:00A2  2E8BB5F900      mov    si, word cs:[di + 0F9h]     ; SI = handler address from nmi_port_handlers (F400:00F9 + 2*index)
F400:00A7  F6C604          test   dh, 4                       ; Latch bit 10 (OUT): ZF=1 — IN read, ZF=0 — OUT write; flag is passed to the handler
F400:00AA  FFD6            call   si                          ; Call the emulated port handler (DS=0040, ES=F000, DX=latch, BP→frame)
F400:00AC  EB0A            jmp    loc_00B8                    ; To NMI acknowledge and exit

; ----------------------------------------------------------------------------------------------
; Port not found in nmi_port_list (including all 8250 ports — dk has no COM emulation).
; ----------------------------------------------------------------------------------------------
loc_00AE:    ; xrefs: 009C
F400:00AE  F6C604          test   dh, 4                       ; Latch bit 10: write (OUT) or read (IN)?

; ----------------------------------------------------------------------------------------------
; "No device" path: writes are ignored, reads return FFh (like a floating ISA bus).
; ----------------------------------------------------------------------------------------------
F400:00B1  7505            jne    loc_00B8                    ; Write (OUT) — do nothing
F400:00B3  B0FF            mov    al, 0FFh                    ; Read: empty bus returns FFh
F400:00B5  884600          mov    byte [bp], al               ; IN result → program's AL (saved AX in frame)

loc_00B8:    ; xrefs: 0086 00AC 00B1
F400:00B8  268B160004      mov    dx, word es:[400h]          ; Read F000:0400 — probably acknowledges NMI/releases the trap latch (value unused)
F400:00BD  58              pop    ax                          ; Restore AX (AL holds the IN result if the handler wrote it to [bp])
F400:00BE  5B              pop    bx                          ; Restore BX
F400:00BF  59              pop    cx                          ; Restore CX
F400:00C0  5A              pop    dx                          ; Restore DX
F400:00C1  5E              pop    si                          ; Restore SI
F400:00C2  5F              pop    di                          ; restore DI
F400:00C3  5D              pop    bp                          ; Restore BP
F400:00C4  1F              pop    ds                          ; Restore DS
F400:00C5  07              pop    es                          ; Restore ES
F400:00C6  CF              iret                               ; Return from NMI to the interrupted program (to the instruction after IN/OUT)

; ----------------------------------------------------------------------------------------------
; nmi_port_list — 25 emulated port numbers (words) for repne scasw in NMI_HANDLER.
; Order probably by access frequency: 3DAh (retrace polling) first, EOI 020h last.
; No 8250 ports (2F8–2FF, 3F8–3FF) — RS-232 is not emulated in dk (my adds COM1 and COM2).
; ----------------------------------------------------------------------------------------------
nmi_port_list:
F400:00C7  DA03            dw     03DAh                       ; Port 3DAh — CGA status (handler #0)
F400:00C9  D403            dw     03D4h                       ; Port 3D4h — 6845 CRTC index register
F400:00CB  D503            dw     03D5h                       ; Port 3D5h — 6845 CRTC data register
F400:00CD  D803            dw     03D8h                       ; Port 3D8h — CGA mode register
F400:00CF  D903            dw     03D9h                       ; Port 3D9h — CGA color select register
F400:00D1  0400            dw     0004h                       ; Port 004h — 8237 DMA channel 2 address
F400:00D3  0500            dw     0005h                       ; Port 005h — 8237 DMA channel 2 count
F400:00D5  0B00            dw     000Bh                       ; Port 00Bh — 8237 DMA mode register
F400:00D7  4000            dw     0040h                       ; Port 040h — 8253 timer channel 0
F400:00D9  4100            dw     0041h                       ; Port 041h — 8253 timer channel 1
F400:00DB  4200            dw     0042h                       ; Port 042h — 8253 timer channel 2 (sound, cassette tape)
F400:00DD  4300            dw     0043h                       ; Port 043h — 8253 control word
F400:00DF  6000            dw     0060h                       ; Port 060h — 8255 port A (keyboard scan code)
F400:00E1  6100            dw     0061h                       ; Port 061h — 8255 port B (speaker, keyboard)
F400:00E3  6200            dw     0062h                       ; Port 062h — 8255 port C
F400:00E5  6300            dw     0063h                       ; Port 063h — 8255 control word
F400:00E7  8100            dw     0081h                       ; Port 081h — DMA channel 2 page register
F400:00E9  0102            dw     0201h                       ; Port 201h — game port (joystick)
F400:00EB  7803            dw     0378h                       ; Port 378h — LPT1 data
F400:00ED  7903            dw     0379h                       ; Port 379h — LPT1 status
F400:00EF  7A03            dw     037Ah                       ; Port 37Ah — LPT1 control
F400:00F1  F203            dw     03F2h                       ; Port 3F2h — floppy drive control register (DOR)
F400:00F3  F403            dw     03F4h                       ; Port 3F4h — 765 main status register (MSR)
F400:00F5  F503            dw     03F5h                       ; Port 3F5h — 765 data register
F400:00F7  2000            dw     0020h                       ; Port 020h — 8259 (EOI only); last in the list (#24)

; ----------------------------------------------------------------------------------------------
; nmi_port_handlers — 25 port handler addresses in the same order as nmi_port_list
; (table offset = 2*index of the found port).
; ----------------------------------------------------------------------------------------------
nmi_port_handlers:
F400:00F9  E703            dw     nmi_port_3DA                ; Port 3DAh handler — CGA status (fake retrace)
F400:00FB  3B03            dw     nmi_port_3D4                ; Port 3D4h handler — CRTC index
F400:00FD  4303            dw     nmi_port_3D5                ; Port 3D5h handler — CRTC data (filters R0–R9)
F400:00FF  8003            dw     nmi_port_3D8                ; Port 3D8h handler — CGA mode (reloads R0–R9)
F400:0101  D703            dw     nmi_port_3D9                ; Port 3D9h handler — CGA color
F400:0103  2B01            dw     nmi_port_004                ; Port 004h handler — DMA address
F400:0105  3D01            dw     nmi_port_005                ; Port 005h handler — DMA count
F400:0107  4F01            dw     nmi_port_00B                ; Port 00Bh handler — DMA mode
F400:0109  5701            dw     nmi_port_040                ; Port 040h handler — timer channel 0 (divisor rescaling)
F400:010B  C401            dw     nmi_port_041                ; Port 041h handler — timer channel 1
F400:010D  0B02            dw     nmi_port_042                ; Port 042h handler — timer channel 2
F400:010F  4602            dw     nmi_port_043                ; Port 043h handler — 8253 control word
F400:0111  6802            dw     nmi_port_060                ; Port 060h handler — 8255 port A
F400:0113  7902            dw     nmi_port_061                ; Port 061h handler — 8255 port B (bit 6 inverted)
F400:0115  8E02            dw     nmi_port_062                ; Port 062h handler — 8255 port C
F400:0117  A102            dw     nmi_port_063                ; Port 063h handler — 8255 control word
F400:0119  B202            dw     nmi_port_081                ; Port 081h handler — DMA page
F400:011B  BA02            dw     nmi_port_201                ; Port 201h handler — joystick
F400:011D  DD02            dw     nmi_port_378                ; Port 378h handler — LPT data
F400:011F  F002            dw     nmi_port_379                ; Port 379h handler — LPT status
F400:0121  FE02            dw     nmi_port_37A                ; Port 37Ah handler — LPT control
F400:0123  1104            dw     nmi_port_3F2                ; Port 3F2h handler — floppy DOR
F400:0125  6B04            dw     nmi_port_3F4                ; Port 3F4h handler — 765 MSR
F400:0127  7504            dw     nmi_port_3F5                ; Port 3F5h handler — 765 data (pseudo-DMA)
F400:0129  5502            dw     nmi_port_020                ; Port 020h handler — 8259 EOI

; ----------------------------------------------------------------------------------------------
; nmi_port_004 — 8237 DMA channel 2 address (write-only): bytes go to 0040:009E/009F
; per flip-flop 0040:00A0. Reads not handled (program's AL unchanged).
; ----------------------------------------------------------------------------------------------
nmi_port_004:    ; xrefs: 0103
F400:012B  26A00004        mov    al, byte es:[400h]          ; AL = address byte written (even port → F000:0400)
F400:012F  8B36A000        mov    si, word [0A0h]             ; SI = low/high byte flip-flop 0040:00A0 (DS=0040 already set in NMI_HANDLER)
F400:0133  88849E00        mov    byte [si + 9Eh], al         ; Store byte at 0040:009E+flip-flop — channel 2 address
F400:0137  8336A00001      xor    word [0A0h], 1              ; Toggle the flip-flop (like the 8237 flip-flop)
F400:013C  C3              ret                                ; Return to NMI_HANDLER

; ----------------------------------------------------------------------------------------------
; nmi_port_005 — DMA channel 2 count (write-only): bytes to 0040:00A2/00A3 per flip-flop 0040:00A4.
; ----------------------------------------------------------------------------------------------
nmi_port_005:    ; xrefs: 0105
F400:013D  26A00104        mov    al, byte es:[401h]          ; AL = count byte written (odd port → F000:0401)
F400:0141  8B36A400        mov    si, word [0A4h]             ; SI = low/high byte flip-flop 0040:00A4
F400:0145  8884A200        mov    byte [si + 0A2h], al        ; Store byte at 0040:00A2+flip-flop — channel 2 count
F400:0149  8336A40001      xor    word [0A4h], 1              ; Toggle flip-flop
F400:014E  C3              ret                                ; Return

nmi_port_00B:    ; xrefs: 0107
F400:014F  26A00104        mov    al, byte es:[401h]          ; AL = DMA mode written (odd port → F000:0401)
F400:0153  A2B200          mov    byte [0B2h], al             ; Remember DMA mode at 0040:00B2
F400:0156  C3              ret                                ; Return

nmi_port_040:    ; xrefs: 0109
F400:0157  7533            jne    loc_018C                    ; Write (OUT 40h) — go accumulate divisor
F400:0159  8B36A600        mov    si, word [0A6h]             ; Read: SI = byte flip-flop 0040:00A6
F400:015D  0BF6            or     si, si                      ; First (low) byte?
F400:015F  751E            jne    loc_017F                    ; No — return previously prepared high byte
F400:0161  26A0000A        mov    al, byte es:[0A00h]         ; Read low byte of current count of real 8253 channel 0 (F000:0A00)
F400:0165  A2A800          mov    byte [0A8h], al             ; …into 0040:00A8
F400:0168  26A0000A        mov    al, byte es:[0A00h]         ; Read high byte of count
F400:016C  A2A900          mov    byte [0A9h], al             ; …into 0040:00A9
F400:016F  BBBA98          mov    bx, 98BAh                   ; Factor 98BAh: 98BAh*2/65536 ≈ 1.19318 (convert to PC clocks)
F400:0172  A1A800          mov    ax, word [0A8h]             ; AX = 16-bit count read
F400:0175  F7E3            mul    bx                          ; DX:AX = count * 98BAh
F400:0177  D1D0            rcl    ax, 1                       ; Shift DX:AX left by 1 (×2) — AX high bit into CF…
F400:0179  D1D2            rcl    dx, 1                       ; …into DX: DX = count*1.19318 (in IBM 8253 units)
F400:017B  8916A800        mov    word [0A8h], dx             ; Rescaled count to 0040:00A8 — returned over two reads

loc_017F:    ; xrefs: 015F
F400:017F  8A84A800        mov    al, byte [si + 0A8h]        ; AL = next byte (low when SI=0, high when SI=1)
F400:0183  83F601          xor    si, 1                       ; Toggle flip-flop
F400:0186  8936A600        mov    word [0A6h], si             ; Store flip-flop at 0040:00A6
F400:018A  EB3E            jmp    loc_01CA                    ; To common exit: AL → IN result

loc_018C:    ; xrefs: 0157 01A4
F400:018C  26A00004        mov    al, byte es:[400h]          ; Write: AL = byte written (even port → F000:0400)
F400:0190  8B36A600        mov    si, word [0A6h]             ; SI = byte flip-flop 0040:00A6
F400:0194  8884A800        mov    byte [si + 0A8h], al        ; Store divisor byte at 0040:00A8+flip-flop
F400:0198  83F601          xor    si, 1                       ; Toggle flip-flop
F400:019B  8936A600        mov    word [0A6h], si             ; Save flip-flop
F400:019F  7406            je     loc_01A7                    ; Both bytes written — rescale and load into real timer
F400:01A1  F6C608          test   dh, 8                       ; Latch bit 11 (DH; always 1 here) — probably reserved for word OUT DX,AX
F400:01A4  74E6            je     loc_018C                    ; No repeat: wait for second byte in next NMI
F400:01A6  C3              ret                                ; Return

loc_01A7:    ; xrefs: 019F
F400:01A7  BB8DD6          mov    bx, 0D68Dh                  ; Factor D68Dh/65536 ≈ 0.83809 = 1/1.19318 (PC clocks → ~1 MHz clocks)
F400:01AA  A1A800          mov    ax, word [0A8h]             ; AX = divisor set by program (0 means 65536)
F400:01AD  48              dec    ax                          ; N-1: N=0 gives FFFFh, which together with +k yields 65536*k
F400:01AE  F7E3            mul    bx                          ; DX:AX = (N-1)*k
F400:01B0  03C3            add    ax, bx                      ; +k → DX:AX = N*k (with carry)
F400:01B2  7301            jae    loc_01B5                    ; No carry
F400:01B4  42              inc    dx                          ; Add carry into high word

loc_01B5:    ; xrefs: 01B2
F400:01B5  8916A800        mov    word [0A8h], dx             ; DX = N*0.83809 — divisor for real 8253; store at 0040:00A8
F400:01B9  268816000A      mov    byte es:[0A00h], dl         ; Load divisor low byte into channel 0 of real 8253 (F000:0A00)
F400:01BE  268836000A      mov    byte es:[0A00h], dh         ; Load divisor high byte
F400:01C3  C3              ret                                ; Return

nmi_port_041:    ; xrefs: 010B
F400:01C4  7508            jne    loc_01CE                    ; Write — go accumulate divisor
F400:01C6  26A0020A        mov    al, byte es:[0A02h]         ; Read: channel 1 count byte of real 8253 as is

loc_01CA:    ; xrefs: 018A 0211
F400:01CA  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:01CD  C3              ret                                ; Return

loc_01CE:    ; xrefs: 01C4 01E6
F400:01CE  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:01D2  8B36AA00        mov    si, word [0AAh]             ; SI = channel 1 byte flip-flop (0040:00AA)
F400:01D6  8884AC00        mov    byte [si + 0ACh], al        ; Store divisor byte at 0040:00AC+flip-flop
F400:01DA  83F601          xor    si, 1                       ; Toggle flip-flop
F400:01DD  8936AA00        mov    word [0AAh], si             ; Save flip-flop
F400:01E1  7406            je     loc_01E9                    ; Both bytes written — rescale
F400:01E3  F6C608          test   dh, 8                       ; Latch bit 11 (DH; always 1 here) — probably reserved for word OUT DX,AX
F400:01E6  74E6            je     loc_01CE                    ; No repeat
F400:01E8  C3              ret                                ; Return

loc_01E9:    ; xrefs: 01E1
F400:01E9  BB841F          mov    bx, 1F84h                   ; Multiplier 1F84h = 8068
F400:01EC  B91027          mov    cx, 2710h                   ; Divisor 2710h = 10000
F400:01EF  A1AC00          mov    ax, word [0ACh]             ; AX = channel 1 divisor set by program
F400:01F2  48              dec    ax                          ; N-1 (handles N=0 → 65536 correctly)
F400:01F3  F7E3            mul    bx                          ; DX:AX = (N-1)*8068
F400:01F5  03C3            add    ax, bx                      ; +8068 → N*8068
F400:01F7  7301            jae    loc_01FA                    ; No carry
F400:01F9  42              inc    dx                          ; Add carry

loc_01FA:    ; xrefs: 01F7
F400:01FA  F7F1            div    cx                          ; AX = N*8068/10000 ≈ 0.807*N
F400:01FC  40              inc    ax                          ; +1 (round up, avoid zero divisor)
F400:01FD  A3AC00          mov    word [0ACh], ax             ; Store rescaled divisor at 0040:00AC
F400:0200  26A2020A        mov    byte es:[0A02h], al         ; Low byte to channel 1 of real 8253 (F000:0A02)
F400:0204  90              nop                                ; Delay between 8253 accesses
F400:0205  268826020A      mov    byte es:[0A02h], ah         ; High byte to channel 1
F400:020A  C3              ret                                ; Return

nmi_port_042:    ; xrefs: 010D
F400:020B  7506            jne    loc_0213                    ; Write — go accumulate divisor
F400:020D  26A0040A        mov    al, byte es:[0A04h]         ; Read: channel 2 count byte of real 8253 as is
F400:0211  EBB7            jmp    loc_01CA                    ; To common exit (AL → IN result)

loc_0213:    ; xrefs: 020B 022B
F400:0213  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0217  8B36AE00        mov    si, word [0AEh]             ; SI = channel 2 byte flip-flop (0040:00AE)
F400:021B  8884B000        mov    byte [si + 0B0h], al        ; Store divisor byte at 0040:00B0+flip-flop
F400:021F  83F601          xor    si, 1                       ; Toggle flip-flop
F400:0222  8936AE00        mov    word [0AEh], si             ; Save flip-flop
F400:0226  7406            je     loc_022E                    ; Both bytes written — rescale
F400:0228  F6C608          test   dh, 8                       ; Latch bit 11 (DH; always 1 here) — probably reserved for word OUT DX,AX
F400:022B  74E6            je     loc_0213                    ; No repeat
F400:022D  C3              ret                                ; Return

loc_022E:    ; xrefs: 0226
F400:022E  BB8DD6          mov    bx, 0D68Dh                  ; Factor D68Dh/65536 ≈ 0.83809 (1.19318 MHz → ~1 MHz)
F400:0231  A1B000          mov    ax, word [0B0h]             ; AX = channel 2 divisor set by program
F400:0234  48              dec    ax                          ; N-1
F400:0235  F7E3            mul    bx                          ; DX = high word of (N-1)*0.83809
F400:0237  42              inc    dx                          ; +1…
F400:0238  42              inc    dx                          ; …+1: rounding compensation (probably a rough fix instead of an exact +k)
F400:0239  268816040A      mov    byte es:[0A04h], dl         ; Low byte to channel 2 of real 8253 (F000:0A04)
F400:023E  90              nop                                ; Delay
F400:023F  90              nop                                ; Delay
F400:0240  268836040A      mov    byte es:[0A04h], dh         ; High byte to channel 2
F400:0245  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_043 — 8253 control word: writes pass unchanged to the real 8253 (F000:0A06),
; reads return FFh (8253 control register is not readable). Emulator byte flip-flops are not reset.
; ----------------------------------------------------------------------------------------------
nmi_port_043:    ; xrefs: 010F
F400:0246  7504            jne    loc_024C                    ; Write — pass control word through
F400:0248  B0FF            mov    al, 0FFh                    ; Read: FFh
F400:024A  EB48            jmp    loc_0294                    ; To common exit (AL → IN result)

loc_024C:    ; xrefs: 0246
F400:024C  26A00104        mov    al, byte es:[401h]          ; AL = control word (odd port → F000:0401)
F400:0250  26A2060A        mov    byte es:[0A06h], al         ; Write to control register of real 8253 (F000:0A06)
F400:0254  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_020 — 8259 emulation: only non-specific EOI (20h) is recognized, which
; clears bit 5 of 8255 port B (F000:0003) — unblocks keyboard IRQ request. Reads not handled.
; ----------------------------------------------------------------------------------------------
nmi_port_020:    ; xrefs: 0129
F400:0255  26A00004        mov    al, byte es:[400h]          ; AL = command written (even port → F000:0400)
F400:0259  3C20            cmp    al, 20h                     ; Non-specific EOI (20h)?
F400:025B  750A            jne    loc_0267                    ; No — ignore (ICW/OCW/mask not emulated)
F400:025D  26A00300        mov    al, byte es:[3]             ; AL = port B of real 8255 (F000:0003)
F400:0261  24DF            and    al, 0DFh                    ; Clear bit 5 — end of keyboard interrupt service
F400:0263  26A20300        mov    byte es:[3], al             ; Write 8255 port B

loc_0267:    ; xrefs: 025B
F400:0267  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_060 — 8255 port A (keyboard scan code) — mapped directly to the real 8255
; at F000:0001.
; ----------------------------------------------------------------------------------------------
nmi_port_060:    ; xrefs: 0111
F400:0268  7506            jne    loc_0270                    ; Write — pass to real port A
F400:026A  26A00100        mov    al, byte es:[1]             ; Read: scan code / 8255 port A data (F000:0001)
F400:026E  EB24            jmp    loc_0294                    ; To common exit (AL → IN result)

loc_0270:    ; xrefs: 0268
F400:0270  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:0274  26A20100        mov    byte es:[1], al             ; Write to port A of real 8255 (input in mode 99h, write has no effect)
F400:0278  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_061 — 8255 port B (F000:0003). Bit 6 (keyboard clock hold) is inverted in "Praktik"
; hardware relative to IBM, so it is flipped on both read and write.
; ----------------------------------------------------------------------------------------------
nmi_port_061:    ; xrefs: 0113
F400:0279  7508            jne    loc_0283                    ; Write — go output to port B
F400:027B  26A00300        mov    al, byte es:[3]             ; Read: current value of real 8255 port B
F400:027F  3440            xor    al, 40h                     ; Invert bit 6 — convert to IBM PC logic
F400:0281  EB11            jmp    loc_0294                    ; To common exit (AL → IN result)

loc_0283:    ; xrefs: 0279
F400:0283  26A00104        mov    al, byte es:[401h]          ; AL = byte written (odd port → F000:0401)
F400:0287  3440            xor    al, 40h                     ; Invert bit 6 (keyboard clock) for "Praktik" hardware
F400:0289  26A20300        mov    byte es:[3], al             ; Write to port B of real 8255 (speaker, channel 2 gate, keyboard control)
F400:028D  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_062 — 8255 port C (F000:0005): direct mapping. Also holds common tail loc_06A8:
; AL → IN result.
; ----------------------------------------------------------------------------------------------
nmi_port_062:    ; xrefs: 0115
F400:028E  7508            jne    loc_0298                    ; Write — go output to port C
F400:0290  26A00500        mov    al, byte es:[5]             ; Read: port C of real 8255 (status/switches, channel 2 output)

loc_0294:    ; xrefs: 024A 026E 0281 02A7
F400:0294  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame
F400:0297  C3              ret                                ; Return

loc_0298:    ; xrefs: 028E
F400:0298  26A00004        mov    al, byte es:[400h]          ; AL = byte written (even port → F000:0400)
F400:029C  26A20500        mov    byte es:[5], al             ; Write to port C of real 8255
F400:02A0  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_063 — 8255 control register (F000:0007): direct mapping (POST writes 99h there,
; like IBM XT: A — input, B — output, C — input).
; ----------------------------------------------------------------------------------------------
nmi_port_063:    ; xrefs: 0117
F400:02A1  7506            jne    loc_02A9                    ; Write — go output control word
F400:02A3  26A00700        mov    al, byte es:[7]             ; Read: control register of real 8255
F400:02A7  EBEB            jmp    loc_0294                    ; To common exit (AL → IN result)

loc_02A9:    ; xrefs: 02A1
F400:02A9  26A00104        mov    al, byte es:[401h]          ; AL = control word (odd port → F000:0401)
F400:02AD  26A20700        mov    byte es:[7], al             ; Write to 8255 control register
F400:02B1  C3              ret                                ; Return

nmi_port_081:    ; xrefs: 0119
F400:02B2  26A00104        mov    al, byte es:[401h]          ; AL = DMA page number (odd port → F000:0401)
F400:02B6  A2B300          mov    byte [0B3h], al             ; Remember DMA channel 2 page at 0040:00B3
F400:02B9  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; nmi_port_201 — game port (dk variant, simpler than my). IN 201h: 8255 port A with port B bit 7 = 1
; returned as is, no software axis emulation. OUT 201h: pulse on port B bit 4 — probably triggers
; hardware one-shots/resets the joystick latch. In my — axes emulated with counters 0040:008C–008F.
; ----------------------------------------------------------------------------------------------
nmi_port_201:    ; xrefs: 011B
F400:02BA  7514            jne    loc_02D0                    ; Write (OUT 201h) — fire one-shots
F400:02BC  26800E030080    or     byte es:[3], 80h            ; Read: set 8255 port B bit 7 — switch port A to joystick lines
F400:02C2  26A00100        mov    al, byte es:[1]             ; AL = joystick state from 8255 port A
F400:02C6  26802603007F    and    byte es:[3], 7Fh            ; Clear port B bit 7 — port A returns keyboard scan codes again
F400:02CC  884600          mov    byte [bp], al               ; Put into IN result (bits 4–7 — buttons)
F400:02CF  C3              ret                                ; Return

loc_02D0:    ; xrefs: 02BA
F400:02D0  26800E030010    or     byte es:[3], 10h            ; OUT 201h: set 8255 port B bit 4 — probably the joystick one-shot trigger pulse
F400:02D6  2680260300EF    and    byte es:[3], 0EFh           ; …and clear bit 4 immediately (end of pulse)
F400:02DC  C3              ret                                ; Return

nmi_port_378:    ; xrefs: 011D
F400:02DD  7505            jne    loc_02E4                    ; Write — output data
F400:02DF  A0BC00          mov    al, byte [0BCh]             ; Read: last output byte from copy 0040:00BC
F400:02E2  EB16            jmp    loc_02FA                    ; To exit with result

loc_02E4:    ; xrefs: 02DD
F400:02E4  26A00004        mov    al, byte es:[400h]          ; AL = byte to output (even port → F000:0400)
F400:02E8  26A2010A        mov    byte es:[0A01h], al         ; Write to printer data register (F000:0A01)
F400:02EC  A2BC00          mov    byte [0BCh], al             ; Remember at 0040:00BC for later reads
F400:02EF  C3              ret                                ; Return

nmi_port_379:    ; xrefs: 011F
F400:02F0  750B            jne    loc_02FD                    ; Write to status port — ignore
F400:02F2  26A0010A        mov    al, byte es:[0A01h]         ; Read: printer line status from F000:0A01
F400:02F6  24A8            and    al, 0A8h                    ; Keep BUSY (7), PE (5), ERROR (3)
F400:02F8  34D0            xor    al, 0D0h                    ; Invert BUSY; ACK=1 and SELECT=1 always (printer always "selected")

loc_02FA:    ; xrefs: 02E2 0303
F400:02FA  884600          mov    byte [bp], al               ; IN result → program's AL in NMI frame

loc_02FD:    ; xrefs: 02F0
F400:02FD  C3              ret                                ; Return

nmi_port_37A:    ; xrefs: 0121
F400:02FE  7505            jne    loc_0305                    ; Write — output control byte
F400:0300  A0BD00          mov    al, byte [0BDh]             ; Read: last written value from 0040:00BD
F400:0303  EBF5            jmp    loc_02FA                    ; To exit with result

loc_0305:    ; xrefs: 02FE
F400:0305  26A00004        mov    al, byte es:[400h]          ; AL = control byte (even port → F000:0400)
F400:0309  A2BD00          mov    byte [0BDh], al             ; Save copy at 0040:00BD
F400:030C  3402            xor    al, 2                       ; Invert bit 1 (AUTO FEED) for hardware
F400:030E  26A20104        mov    byte es:[401h], al          ; Write to F000:0401 — probably printer STROBE/INIT/SLCTIN/AUTOFD register
F400:0312  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; 6845 parameter tables for emulating mode changes via port 3D8: 4 tables of 10 bytes (R0–R9;
; in my — 16 bytes each). 0313 — text 40x25, 031D — text 80x25, 0327 — graphics 320/640x200,
; 0331 — 80x25 "text" with R9=1 (160x100). Values match my but do NOT match dk F000:F0A4 (INT 1Dh).
; ----------------------------------------------------------------------------------------------
F400:0313  3F2831041F06…   db     3Fh,28h,31h,04h,1Fh,06h,19h,1Ch ; 40x25 text: R0 Htotal=3Fh, R1 Hdisp=28h(40), R2 Hsync=31h, R3 width=4, R4 Vtotal=1Fh, R5=6, R6 Vdisp=19h(25), R7 Vsync=1Ch
F400:031B  02077F506308…   db     02h,07h,7Fh,50h,63h,08h,1Fh,06h ; 40x25: R8=02h, R9=07h | 031D — 80x25: R0=7Fh, R1=50h (80), R2=63h, R3=08h, R4=1Fh, R5=06h
F400:0323  191C02073F28…   db     19h,1Ch,02h,07h,3Fh,28h,31h,04h ; 80x25: R6=19h (25), R7=1Ch, R8=02h, R9=07h | 0327 — graphics: R0=3Fh, R1=28h, R2=31h, R3=04h
F400:032B  7F0664700201…   db     7Fh,06h,64h,70h,02h,01h,7Fh,50h ; graphics: R4=7Fh, R5=06h, R6=64h (100 rows), R7=70h, R8=02h, R9=01h | 0331 — 160x100: R0=7Fh, R1=50h
F400:0333  63087F066470…   db     63h,08h,7Fh,06h,64h,70h,02h,01h ; 160x100 (80 character cells, R9=1): R2=63h, R3=08h, R4=7Fh, R5=06h, R6=64h, R7=70h, R8=02h, R9=01h

nmi_port_3D4:    ; xrefs: 00FB
F400:033B  26A00004        mov    al, byte es:[400h]          ; AL = 6845 register number written (even port → latch F000:0400)
F400:033F  A2B400          mov    byte [0B4h], al             ; 0040:00B4 — shadow CRTC index (emulated 6845 address register)
F400:0342  C3              ret                                ; return to NMI_HANDLER

nmi_port_3D5:    ; xrefs: 00FD
F400:0343  8A26B400        mov    ah, byte [0B4h]             ; AH = shadow CRTC index from 0040:00B4 (flags unchanged, ZF still from NMI_HANDLER)
F400:0347  750D            jne    loc_0356                    ; ZF=0 → write to 3D5
F400:0349  2688260000      mov    byte es:[0], ah             ; read: put index into real 6845 address register (F000:0000)
F400:034E  26A00200        mov    al, byte es:[2]             ; read selected 6845 register (F000:0002)
F400:0352  884600          mov    byte [bp], al               ; IN result → program's saved AL
F400:0355  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Write to 3D5: filter by register number
; ----------------------------------------------------------------------------------------------
loc_0356:    ; xrefs: 0347
F400:0356  80FC09          cmp    ah, 9                       ; compare index with 9 (R9 — max scan line)
F400:0359  7F17            jg     loc_0372                    ; R10 and up (cursor, start address) → pass to real 6845
F400:035B  7514            jne    loc_0371                    ; R0–R8 (timing, sync) — write ignored, protects the monitor
F400:035D  26A00104        mov    al, byte es:[401h]          ; R9: AL = value written (odd port → latch F000:0401)
F400:0361  A2B800          mov    byte [0B8h], al             ; remember R9 at 0040:00B8 (max scan line shadow copy)
F400:0364  3C01            cmp    al, 1                       ; R9=1? (trick for 160x100 16-color mode on CGA)
F400:0366  7509            jne    loc_0371                    ; otherwise do nothing
F400:0368  A0B500          mov    al, byte [0B5h]             ; AL = shadow mode register 3D8 (0040:00B5)
F400:036B  2403            and    al, 3                       ; bits 0–1: bit0 = 80 columns, bit1 = graphics
F400:036D  3C01            cmp    al, 1                       ; "80-column text" mode?
F400:036F  743C            je     loc_03AD                    ; yes → reprogram 6845 with the 160x100 table (F400:0331)

loc_0371:    ; xrefs: 035B 0366
F400:0371  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Write to R10 and up: pass directly to real 6845
; ----------------------------------------------------------------------------------------------
loc_0372:    ; xrefs: 0359
F400:0372  2688260000      mov    byte es:[0], ah             ; register number → 6845 address register (F000:0000)
F400:0377  26A00104        mov    al, byte es:[401h]          ; AL = value written (latch F000:0401, odd port)
F400:037B  26A20200        mov    byte es:[2], al             ; to 6845 data register (F000:0002)
F400:037F  C3              ret                                ; return

nmi_port_3D8:    ; xrefs: 00FF
F400:0380  268A260004      mov    ah, byte es:[400h]          ; AH = mode byte written (even port → latch F000:0400)
F400:0385  80CC08          or     ah, 8                       ; bit 3 (video enable) always on — screen blanking not emulated
F400:0388  A0B500          mov    al, byte [0B5h]             ; AL = old mode from shadow register 0040:00B5
F400:038B  8826B500        mov    byte [0B5h], ah             ; remember new mode at 0040:00B5
F400:038F  80E403          and    ah, 3                       ; new bits 0–1 (80 columns / graphics)
F400:0392  2403            and    al, 3                       ; old bits 0–1
F400:0394  3AC4            cmp    al, ah                      ; mode type unchanged?
F400:0396  7433            je     loc_03CB                    ; yes → just update hardware mode register, no 6845 reprogramming
F400:0398  0AE4            or     ah, ah                      ; check: 00 = 40x25 text?
F400:039A  BB1303          mov    bx, 313h                    ; BX → 40x25 table (F400:0313); flags from or ah,ah preserved
F400:039D  7416            je     loc_03B5                    ; 40x25 text → load
F400:039F  BB1D03          mov    bx, 31Dh                    ; BX → 80x25 table (F400:031D)
F400:03A2  FECC            dec    ah                          ; mode 01?
F400:03A4  750C            jne    loc_03B2                    ; 10 or 11 (graphics) → table F400:0327
F400:03A6  803EB80001      cmp    byte [0B8h], 1              ; 80x25 text: was R9=1 written earlier (0040:00B8)?
F400:03AB  7508            jne    loc_03B5                    ; no → normal 80x25

loc_03AD:    ; xrefs: 036F
F400:03AD  BB3103          mov    bx, 331h                    ; BX → 160x100 table (F400:0331): 80-column text + R9=1
F400:03B0  EB03            jmp    loc_03B5                    ; go load table

loc_03B2:    ; xrefs: 03A4
F400:03B2  BB2703          mov    bx, 327h                    ; BX → 320/640x200 graphics table (F400:0327)

; ----------------------------------------------------------------------------------------------
; Load R0–R9 of real 6845 from table CS:BX (10 bytes)
; ----------------------------------------------------------------------------------------------
loc_03B5:    ; xrefs: 039D 03AB 03B0
F400:03B5  33C0            xor    ax, ax                      ; AH = 6845 register number, starting at R0
F400:03B7  B90A00          mov    cx, 0Ah                     ; 10 registers R0–R9

loc_03BA:    ; xrefs: 03C9
F400:03BA  2688260000      mov    byte es:[0], ah             ; register number → 6845 address register (F000:0000)
F400:03BF  2E8A07          mov    al, byte cs:[bx]            ; value from ROM table
F400:03C2  26A20200        mov    byte es:[2], al             ; write to 6845 data register (F000:0002)
F400:03C6  FEC4            inc    ah                          ; next register
F400:03C8  43              inc    bx                          ; next table byte
F400:03C9  E2EF            loop   loc_03BA                    ; loop over 10 registers

; ----------------------------------------------------------------------------------------------
; Write shadow mode/color registers to video hardware: F000:0201 = mode (3D8), F000:0200 = color (3D9)
; ----------------------------------------------------------------------------------------------
loc_03CB:    ; xrefs: 0396
F400:03CB  8A26B500        mov    ah, byte [0B5h]             ; AH = mode register (0040:00B5)
F400:03CF  A0B600          mov    al, byte [0B6h]             ; AL = color select register (0040:00B6)
F400:03D2  26A30002        mov    word es:[200h], ax          ; write to hardware video mode register F000:0200 (low byte — color, high — mode)
F400:03D6  C3              ret                                ; return

nmi_port_3D9:    ; xrefs: 0101
F400:03D7  26A00104        mov    al, byte es:[401h]          ; AL = color byte written (odd port → latch F000:0401)
F400:03DB  A2B600          mov    byte [0B6h], al             ; shadow color register 0040:00B6
F400:03DE  8A26B500        mov    ah, byte [0B5h]             ; AH = shadow mode register 0040:00B5
F400:03E2  26A30002        mov    word es:[200h], ax          ; to hardware video register F000:0200 (AL=color, AH=mode)
F400:03E6  C3              ret                                ; return

nmi_port_3DA:    ; xrefs: 00F9
F400:03E7  8036B70009      xor    byte [0B7h], 9              ; 0040:00B7 — emulated 3DA status: toggle bits 0 and 3 on every read
F400:03EC  A0B700          mov    al, byte [0B7h]             ; AL = new status value
F400:03EF  884600          mov    byte [bp], al               ; IN result → saved AL (writes to 3DA are simply ignored)
F400:03F2  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; 765 floppy command emulation tables (used by nmi_port_3F5).
; 03F3: 15 765 command codes (low 5 bits of the first byte); 0402: 15 descriptor bytes for them:
; low nibble = command length in bytes, bit7 = has data phase (pseudo-DMA),
; bit6 = direction memory→floppy (write), bit5 = command generates no interrupt.
; ----------------------------------------------------------------------------------------------
F400:03F3  060C0509020A…   db     06h,0Ch,05h,09h,02h,0Ah,0Dh,11h ; codes: 06 read data, 0C read deleted, 05 write data, 09 write deleted, 02 read track, 0A read ID, 0D format, 11 scan equal
F400:03FB  191D07080304…   db     19h,1Dh,07h,08h,03h,04h,0Fh,89h ; codes: 19 scan low/eq, 1D scan high/eq, 07 recalibrate, 08 sense int, 03 specify, 04 sense drive, 0F seek; 0402: 89=read 9 bytes
F400:0403  89C9C98902C6…   db     89h,0C9h,0C9h,89h,02h,0C6h,0C9h,0C9h ; descr.: 89 read deleted, C9 write, C9 write deleted, 89 read track, 02 read ID, C6 format (6 bytes, write), C9 scan eq, C9 scan le
F400:040B  C90221230203    db     0C9h,02h,21h,23h,02h,03h    ; descr.: C9 scan he, 02 recalibrate, 21 sense int (1 byte, no IRQ), 23 specify (no IRQ), 02 sense drive, 03 seek

nmi_port_3F2:    ; xrefs: 0123
F400:0411  26A00004        mov    al, byte es:[400h]          ; AL = DOR byte written (even port → latch F000:0400)
F400:0415  8A26B900        mov    ah, byte [0B9h]             ; AH = previous DOR value (shadow register 0040:00B9)
F400:0419  F6C404          test   ah, 4                       ; controller already out of reset (bit 2 = /RESET)?
F400:041C  7536            jne    loc_0454                    ; yes → just update control register
F400:041E  A804            test   al, 4                       ; new value releases reset?
F400:0420  7432            je     loc_0454                    ; no (stay in reset) → just update register
F400:0422  8AC8            mov    cl, al                      ; reset→run transition: CL = drive number bit 0 (2 drives supported)
F400:0424  80E101          and    cl, 1                       ; bit 0 only
F400:0427  B401            mov    ah, 1                       ; AH = 1
F400:0429  D2E4            shl    ah, cl                      ; AH = 1 << drive → one-hot select code (01 or 02)
F400:042B  24FC            and    al, 0FCh                    ; clear drive select field
F400:042D  0AC4            or     al, ah                      ; insert one-hot select code
F400:042F  0C08            or     al, 8                       ; bit 3 — floppy interrupt enable (flag "no pseudo-DMA transfer")
F400:0431  A2B900          mov    byte [0B9h], al             ; remember in shadow DOR 0040:00B9
F400:0434  26A20106        mov    byte es:[601h], al          ; to hardware floppy control register F000:0601 (motors, select, reset)
F400:0438  C606BA0000      mov    byte [0BAh], 0              ; 0040:00BA — 765 command intake state: 0 = waiting for first byte of a new command

; ----------------------------------------------------------------------------------------------
; Wait for a 765 interrupt (after reset or command) and deliver it via INT 0Eh.
; Polls bit 15 of word F000:0200 (floppy IRQ request) about 2x65536 times; on timeout exits silently.
; ----------------------------------------------------------------------------------------------
loc_043D:    ; xrefs: 04E1 054E
F400:043D  FB              sti                                ; enable interrupts (inside NMI) — let timer/keyboard through
F400:043E  B302            mov    bl, 2                       ; BL = 2 — outer timeout counter
F400:0440  33C9            xor    cx, cx                      ; CX = 0 → 65536 inner loop iterations

loc_0442:    ; xrefs: 044A 044E
F400:0442  26A10002        mov    ax, word es:[200h]          ; read interrupt status word F000:0200
F400:0446  D0E4            shl    ah, 1                       ; bit 15 (floppy interrupt request) → CF
F400:0448  7207            jb     loc_0451                    ; 765 interrupt present → call handler
F400:044A  E2F6            loop   loc_0442                    ; poll with timeout
F400:044C  FECB            dec    bl                          ; outer counter
F400:044E  75F2            jne    loc_0442                    ; another round
F400:0450  C3              ret                                ; return to NMI_HANDLER

loc_0451:    ; xrefs: 0448
F400:0451  CD0E            int    0Eh                         ; emulate IRQ6: call floppy handler INT 0Eh (sets bit 7 at 0040:003E)
F400:0453  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Ordinary DOR write (no reset release): same drive select conversion, no interrupt wait
; ----------------------------------------------------------------------------------------------
loc_0454:    ; xrefs: 041C 0420
F400:0454  8AC8            mov    cl, al                      ; CL = drive number (bit 0)
F400:0456  80E101          and    cl, 1                       ; bit 0 only
F400:0459  B401            mov    ah, 1                       ; AH = 1
F400:045B  D2E4            shl    ah, cl                      ; one-hot drive select code
F400:045D  24FC            and    al, 0FCh                    ; clear bits 0–1
F400:045F  0AC4            or     al, ah                      ; insert select code
F400:0461  0C08            or     al, 8                       ; bit 3 — floppy IRQ enable
F400:0463  A2B900          mov    byte [0B9h], al             ; shadow DOR 0040:00B9
F400:0466  26A20106        mov    byte es:[601h], al          ; hardware floppy control register F000:0601
F400:046A  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; nmi_port_3F4 — read 765 main status register (MSR). Real 765: F000:0600 = MSR
; ----------------------------------------------------------------------------------------------
nmi_port_3F4:    ; xrefs: 0125
F400:046B  7507            jne    loc_0474                    ; write to 3F4 (not on XT) — ignore
F400:046D  26A00006        mov    al, byte es:[600h]          ; read MSR of real 765 (F000:0600)
F400:0471  884600          mov    byte [bp], al               ; IN result → saved AL

loc_0474:    ; xrefs: 046B
F400:0474  C3              ret                                ; return

nmi_port_3F5:    ; xrefs: 0127
F400:0475  7508            jne    loc_047F                    ; ZF=0 → write to 3F5
F400:0477  26A00206        mov    al, byte es:[602h]          ; read: result byte from real 765 data register (F000:0602)
F400:047B  884600          mov    byte [bp], al               ; IN result → saved AL
F400:047E  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Byte write to 765: determine whether it is the first command byte
; ----------------------------------------------------------------------------------------------
loc_047F:    ; xrefs: 0475
F400:047F  8A26BA00        mov    ah, byte [0BAh]             ; AH = command intake state (0040:00BA)
F400:0483  80E40F          and    ah, 0Fh                     ; low nibble = command bytes still expected
F400:0486  752E            jne    loc_04B6                    ; nonzero → parameter of current command
F400:0488  26A00104        mov    al, byte es:[401h]          ; first byte: AL = command code (odd port → latch F000:0401)
F400:048C  241F            and    al, 1Fh                     ; drop MT/MF/SK flags (bits 5–7)
F400:048E  BFF303          mov    di, 3F3h                    ; DI → 765 command code table (F400:03F3)
F400:0491  B90F00          mov    cx, 0Fh                     ; 15 codes
F400:0494  06              push   es                          ; save ES (=F000)
F400:0495  8CCB            mov    bx, cs                      ; ES = CS = F400 for table search
F400:0497  8EC3            mov    es, bx                      ; ES = F400
F400:0499  F2AE            repne scasb al, byte es:[di]       ; search table for command code
F400:049B  07              pop    es                          ; restore ES = F000
F400:049C  7512            jne    loc_04B0                    ; not found → treat as one-byte command
F400:049E  81EFF403        sub    di, 3F4h                    ; DI = index of the found code (scasb left DI past the match: DI−03F4h)
F400:04A2  2E8AA50204      mov    ah, byte cs:[di + 402h]     ; AH = command descriptor from table F400:0402 + index
F400:04A7  8826BA00        mov    byte [0BAh], ah             ; to 0040:00BA: length + flags (data/direction/no IRQ)
F400:04AB  80E40F          and    ah, 0Fh                     ; AH = number of command bytes
F400:04AE  EB06            jmp    loc_04B6                    ; go process byte

loc_04B0:    ; xrefs: 049C
F400:04B0  B401            mov    ah, 1                       ; unknown command: length 1 (765 will answer "invalid command")
F400:04B2  8826BA00        mov    byte [0BAh], ah             ; to 0040:00BA

; ----------------------------------------------------------------------------------------------
; Not the last command byte — just pass to 765
; ----------------------------------------------------------------------------------------------
loc_04B6:    ; xrefs: 0486 04AE
F400:04B6  80FC01          cmp    ah, 1                       ; last command byte?
F400:04B9  740D            je     loc_04C8                    ; yes → complete command
F400:04BB  FE0EBA00        dec    byte [0BAh]                 ; decrement remaining byte count
F400:04BF  26A00104        mov    al, byte es:[401h]          ; AL = byte written (latch F000:0401)
F400:04C3  26A20206        mov    byte es:[602h], al          ; to real 765 data register (F000:0602)
F400:04C7  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Last command byte: if there is a data phase — pseudo-DMA, otherwise pass the byte and
; (if the command raises an interrupt) wait for 765 IRQ → INT 0Eh
; ----------------------------------------------------------------------------------------------
loc_04C8:    ; xrefs: 04B9
F400:04C8  8A26BA00        mov    ah, byte [0BAh]             ; AH = command descriptor
F400:04CC  D0E4            shl    ah, 1                       ; bit 7 (has data phase) → CF
F400:04CE  7215            jb     loc_04E5                    ; command with data transfer → pseudo-DMA
F400:04D0  FE0EBA00        dec    byte [0BAh]                 ; counter → 0 (command accepted)
F400:04D4  26A00104        mov    al, byte es:[401h]          ; AL = last command byte
F400:04D8  26A20206        mov    byte es:[602h], al          ; pass to 765 (F000:0602) — command started
F400:04DC  F6C440          test   ah, 40h                     ; bit 5 of original descriptor (bit 6 after shift): command without interrupt?
F400:04DF  7503            jne    loc_04E4                    ; yes (sense interrupt, specify) → exit immediately
F400:04E1  E959FF          jmp    loc_043D                    ; otherwise wait for 765 interrupt and call INT 0Eh

loc_04E4:    ; xrefs: 04DF
F400:04E4  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Channel 2 pseudo-DMA (8237 emulation): buffer address = page (0040:00B3, port 081) : address (0040:009E,
; port 004), length = 0040:00A2 (port 005) + 1. Bytes move via F000:0800 (DACK cycle to 765),
; the last one via F000:0808 (DACK + TC). Each byte waits for ready via WAIT (probably TEST pin ← 765 DRQ).
; ----------------------------------------------------------------------------------------------
loc_04E5:    ; xrefs: 04CE
F400:04E5  33DB            xor    bx, bx                      ; BX = 0
F400:04E7  8A3EB300        mov    bh, byte [0B3h]             ; BH = DMA page (0040:00B3, written via port 081)
F400:04EB  B104            mov    cl, 4                       ; shift by 4
F400:04ED  D3E3            shl    bx, cl                      ; BX = page*1000h — buffer segment (bits A16–A19)
F400:04EF  8B3E9E00        mov    di, word [9Eh]              ; DI = DMA channel 2 base address (0040:009E, written via port 004)
F400:04F3  8B0EA200        mov    cx, word [0A2h]             ; CX = channel 2 count (0040:00A2, port 005)
F400:04F7  41              inc    cx                          ; as in 8237: count+1 bytes are transferred
F400:04F8  D0E4            shl    ah, 1                       ; descriptor bit 6 (direction memory→floppy) → CF
F400:04FA  726F            jb     loc_056B                    ; write/format command → output-to-765 branch

; ----------------------------------------------------------------------------------------------
; Disk read (floppy → memory) or verify
; ----------------------------------------------------------------------------------------------
F400:04FC  FE0EBA00        dec    byte [0BAh]                 ; command byte counter → 0
F400:0500  8A26B900        mov    ah, byte [0B9h]             ; AH = shadow DOR
F400:0504  80E4F7          and    ah, 0F7h                    ; clear bit 3: disable floppy IRQ during transfer (flag "pseudo-DMA in progress" for INT0F)
F400:0507  8826B900        mov    byte [0B9h], ah             ; to 0040:00B9
F400:050B  2688260106      mov    byte es:[601h], ah          ; to hardware register F000:0601
F400:0510  FB              sti                                ; enable interrupts (an early 765 IRQ aborts the transfer via INT0F)
F400:0511  803EB20042      cmp    byte [0B2h], 42h            ; DMA mode (0040:00B2, port 00B) = 42h — channel 2 verify?
F400:0516  7439            je     loc_0551                    ; yes → read without storing to memory
F400:0518  8CC2            mov    dx, es                      ; DX = F000 (register segment)
F400:051A  8EC3            mov    es, bx                      ; ES = buffer segment
F400:051C  8CDB            mov    bx, ds                      ; BX = 0040h (saved)
F400:051E  8EDA            mov    ds, dx                      ; DS = F000 — access to 765 registers
F400:0520  A00104          mov    al, byte [401h]             ; AL = last command byte (latch F000:0401)
F400:0523  A20206          mov    byte [602h], al             ; pass to 765 (F000:0602) — start command
F400:0526  EB04            jmp    loc_052C                    ; go wait for first byte

loc_0528:    ; xrefs: 052D
F400:0528  A00008          mov    al, byte [800h]             ; read data byte from 765 with DACK cycle (F000:0800)
F400:052B  AA              stosb  byte es:[di], al            ; store to buffer ES:DI, DI++

loc_052C:    ; xrefs: 0526
F400:052C  9B              wait                               ; WAIT — wait for byte ready (probably 765 DRQ on CPU TEST input)
F400:052D  E2F9            loop   loc_0528                    ; for all bytes except the last
F400:052F  EB00            jmp    loc_0531                    ; short jump as delay

loc_0531:    ; xrefs: 052F
F400:0531  FA              cli                                ; disable interrupts
F400:0532  A00808          mov    al, byte [808h]             ; read last byte via F000:0808 — DACK with TC (end of transfer for 765)
F400:0535  AA              stosb  byte es:[di], al            ; to buffer
F400:0536  8EDB            mov    ds, bx                      ; DS = 0040h
F400:0538  8EC2            mov    es, dx                      ; ES = F000
F400:053A  893E9E00        mov    word [9Eh], di              ; update DMA channel 2 current address (0040:009E), as the 8237 does
F400:053E  890EA200        mov    word [0A2h], cx             ; update channel count (0040:00A2)

; ----------------------------------------------------------------------------------------------
; Transfer complete: re-enable floppy IRQ and wait for command result interrupt
; ----------------------------------------------------------------------------------------------
loc_0542:    ; xrefs: 0569 05A7
F400:0542  A0B900          mov    al, byte [0B9h]             ; AL = shadow DOR
F400:0545  0C08            or     al, 8                       ; bit 3 — enable floppy IRQ
F400:0547  A2B900          mov    byte [0B9h], al             ; to 0040:00B9
F400:054A  26A20106        mov    byte es:[601h], al          ; to hardware register F000:0601
F400:054E  E9ECFE          jmp    loc_043D                    ; wait for 765 IRQ and call INT 0Eh

; ----------------------------------------------------------------------------------------------
; Verify (DMA mode 42h): bytes are read from 765 but not stored
; ----------------------------------------------------------------------------------------------
loc_0551:    ; xrefs: 0516
F400:0551  26A00104        mov    al, byte es:[401h]          ; AL = last command byte
F400:0555  26A20206        mov    byte es:[602h], al          ; to 765 (F000:0602) — start
F400:0559  EB04            jmp    loc_055F                    ; go wait

loc_055B:    ; xrefs: 0560
F400:055B  26A00008        mov    al, byte es:[800h]          ; read byte via DACK (F000:0800), result discarded

loc_055F:    ; xrefs: 0559
F400:055F  9B              wait                               ; WAIT — wait for next byte ready
F400:0560  E2F9            loop   loc_055B                    ; all bytes except the last
F400:0562  EB00            jmp    loc_0564                    ; delay

loc_0564:    ; xrefs: 0562
F400:0564  26A00808        mov    al, byte es:[808h]          ; last byte — DACK+TC (F000:0808)
F400:0568  FA              cli                                ; disable interrupts
F400:0569  EBD7            jmp    loc_0542                    ; go complete transfer

; ----------------------------------------------------------------------------------------------
; Disk write / format (memory → floppy)
; ----------------------------------------------------------------------------------------------
loc_056B:    ; xrefs: 04FA
F400:056B  FE0EBA00        dec    byte [0BAh]                 ; command byte counter → 0
F400:056F  8A26B900        mov    ah, byte [0B9h]             ; AH = shadow DOR
F400:0573  80E4F7          and    ah, 0F7h                    ; clear bit 3 — disable floppy IRQ during transfer
F400:0576  8826B900        mov    byte [0B9h], ah             ; to 0040:00B9
F400:057A  2688260106      mov    byte es:[601h], ah          ; to hardware register F000:0601
F400:057F  FB              sti                                ; enable interrupts
F400:0580  8CDA            mov    dx, ds                      ; DX = 0040h (saved)
F400:0582  8EDB            mov    ds, bx                      ; DS = buffer segment
F400:0584  8BF7            mov    si, di                      ; SI = buffer address
F400:0586  26A00104        mov    al, byte es:[401h]          ; AL = last command byte (ES=F000, latch F000:0401)
F400:058A  26A20206        mov    byte es:[602h], al          ; to 765 (F000:0602) — start
F400:058E  EB04            jmp    loc_0594                    ; go load first byte

loc_0590:    ; xrefs: 0596
F400:0590  26A20008        mov    byte es:[800h], al          ; write byte to 765 with DACK cycle (F000:0800)

loc_0594:    ; xrefs: 058E
F400:0594  AC              lodsb  al, byte [si]               ; AL = next byte from buffer DS:SI
F400:0595  9B              wait                               ; WAIT — wait for 765 data request
F400:0596  E2F8            loop   loc_0590                    ; all bytes except the last
F400:0598  FA              cli                                ; disable interrupts
F400:0599  26A20808        mov    byte es:[808h], al          ; last byte — DACK+TC (F000:0808)
F400:059D  8EDA            mov    ds, dx                      ; DS = 0040h
F400:059F  89369E00        mov    word [9Eh], si              ; update DMA channel 2 address (0040:009E)
F400:05A3  890EA200        mov    word [0A2h], cx             ; update count (0040:00A2)
F400:05A7  EB99            jmp    loc_0542                    ; go complete: enable IRQ and wait for interrupt

; ----------------------------------------------------------------------------------------------
; Unused ROM area F400:05A9–1BFF (5719 bytes), filled with FFh.
; In my this space is used (1 KB port table, COM1/COM2 handlers, detect_com_ports, beep), only 0C4F–1BFF free.
; ----------------------------------------------------------------------------------------------
F400:05A9  FF              db     5719 dup (FFh)              ; FFh filler (5719 bytes) — free space

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
; Start of the main 8 KB BIOS block (F000:E000): manufacturer signature and POST message strings (CP866).
; In my this holds «Bios» and the copyright «Computer & Soft Technol. 1992».
; ----------------------------------------------------------------------------------------------
F000:E000  303030303120…   db     '00001 "МАГНИТ" 1990'       ; «00001 "МАГНИТ" 1990» ("00001 "MAGNIT" 1990") — probably ROM version/serial number and manufacturer plant; not displayed

; ----------------------------------------------------------------------------------------------
; dat_E013 — POST banner (printed at E224 via sub_E6BC): «ПЭВМ \"Практик\"» ("PC \"Praktik\""), LF CR,
; then «Подождите пожалуйста...» ("Please wait...") up to the zero at E03C.
; ----------------------------------------------------------------------------------------------
dat_E013:    ; xrefs: E224
F000:E013  8F9D828C2022…   db     'ПЭВМ "Практик"'            ; «ПЭВМ "Практик"» ("PC "Praktik"") — machine name in the banner
F000:E021  0A0D            db     0Ah,0Dh                     ; line feed LF, CR
F000:E023  8FAEA4AEA6A4…   db     'Подождите пожалуйста...'   ; «Подождите пожалуйста...» ("Please wait...") — memory test in progress
F000:E03A  0A0D00          db     0Ah,0Dh,00h                 ; LF, CR, end of string (0)

; ----------------------------------------------------------------------------------------------
; dat_E03D — suffix for the tested-memory counter (printed at E34B)
; ----------------------------------------------------------------------------------------------
dat_E03D:    ; xrefs: E34B
F000:E03D  208AA120AFE0…   db     ' Кб проверено'             ; « Кб проверено» (" KB tested") — after the kilobyte count
F000:E04A  0D00            db     0Dh,00h                     ; CR (cursor to line start to update the counter), end of string

; ----------------------------------------------------------------------------------------------
; Return addresses for stackless subroutine calls (mov sp,addr + jmp trick; SS=F000):
; E04C → E0E0 (after ROM checksum), E04E → E129 (after first 16 KB test). In my — words E06E/E070.
; ----------------------------------------------------------------------------------------------
dat_E04C:    ; xrefs: E0DA
F000:E04C  E0              db     0E0h                        ; Low byte of return address E0E0 after ROM checksum (sp=E04C, jmp E63A)
F000:E04D  E0              db     0E0h                        ; High byte E0h of return address E0E0

dat_E04E:    ; xrefs: E123
F000:E04E  29              db     29h                         ; Low byte of return address E129 after the first 16 KB RAM test (sp=E04E, jmp E455)
F000:E04F  E1              db     0E1h                        ; High byte E1h of return address E129

; ----------------------------------------------------------------------------------------------
; dat_E050 — expansion ROM checksum error message (sub_E47A, E481)
; ----------------------------------------------------------------------------------------------
dat_E050:    ; xrefs: E481
F000:E050  208A91208F8793  db     ' КС ПЗУ'                   ; « КС ПЗУ» (" ROM CS") — "ROM checksum" (bad)
F000:E057  0A0D0000        db     0Ah,0Dh,00h,00h             ; LF, CR, end of string; second 00h — filler up to RESET (E05B)

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
F000:E067  7505            jne    loc_E06E                    ; no → normal POST
F000:E069  EA030000F6      jmp far 0F600h:3                   ; yes → transfer control to option ROM at F600:0003

; ----------------------------------------------------------------------------------------------
; 8088/8086 CPU test (as in the IBM PC): checks flags SF,ZF,AF,PF,CF,OF and
; conditional jumps. Any failure hangs at E0BF.
; ----------------------------------------------------------------------------------------------
loc_E06E:    ; xrefs: E067
F000:E06E  B4D5            mov    ah, 0D5h                    ; AH = D5h: SF, ZF, AF, PF, CF = 1
F000:E070  9E              sahf                               ; load into flags
F000:E071  734C            jae    loc_E0BF                    ; CF must be 1
F000:E073  754A            jne    loc_E0BF                    ; ZF must be 1
F000:E075  7B48            jnp    loc_E0BF                    ; PF must be 1
F000:E077  7946            jns    loc_E0BF                    ; SF must be 1
F000:E079  9F              lahf                               ; read flags back into AH
F000:E07A  B105            mov    cl, 5                       ; shift by 5
F000:E07C  D2EC            shr    ah, cl                      ; bit 4 (AF) → CF
F000:E07E  733F            jae    loc_E0BF                    ; AF must be 1
F000:E080  B040            mov    al, 40h                     ; AL = 40h
F000:E082  D0E0            shl    al, 1                       ; 40h<<1 = 80h → overflow, OF=1
F000:E084  7139            jno    loc_E0BF                    ; OF must be 1
F000:E086  32E4            xor    ah, ah                      ; AH = 0
F000:E088  9E              sahf                               ; clear all flags
F000:E089  7634            jbe    loc_E0BF                    ; CF and ZF must be 0
F000:E08B  7832            js     loc_E0BF                    ; SF must be 0
F000:E08D  7A30            jp     loc_E0BF                    ; PF must be 0
F000:E08F  9F              lahf                               ; flags → AH
F000:E090  B105            mov    cl, 5                       ; shift by 5
F000:E092  D2EC            shr    ah, cl                      ; AF → CF
F000:E094  7229            jb     loc_E0BF                    ; AF must be 0
F000:E096  D0E4            shl    ah, 1                       ; shifting zero — OF=0
F000:E098  7025            jo     loc_E0BF                    ; OF must be 0

; ----------------------------------------------------------------------------------------------
; Register test: FFFFh, then 0000h passed through all segment and general registers
; ----------------------------------------------------------------------------------------------
F000:E09A  B8FFFF          mov    ax, 0FFFFh                  ; first pass — pattern FFFFh
F000:E09D  F9              stc                                ; CF=1 — first pass marker

loc_E09E:    ; xrefs: E0B9
F000:E09E  8ED8            mov    ds, ax                      ; AX → DS
F000:E0A0  8CDB            mov    bx, ds                      ; DS → BX
F000:E0A2  8EC3            mov    es, bx                      ; BX → ES
F000:E0A4  8CC1            mov    cx, es                      ; ES → CX
F000:E0A6  8ED1            mov    ss, cx                      ; CX → SS
F000:E0A8  8CD2            mov    dx, ss                      ; SS → DX
F000:E0AA  8BE2            mov    sp, dx                      ; DX → SP
F000:E0AC  8BEC            mov    bp, sp                      ; SP → BP
F000:E0AE  8BF5            mov    si, bp                      ; BP → SI
F000:E0B0  8BFE            mov    di, si                      ; SI → DI
F000:E0B2  7307            jae    loc_E0BB                    ; second pass (CF=0) → check for zero
F000:E0B4  33C7            xor    ax, di                      ; first pass: DI must equal FFFFh (AX becomes 0)
F000:E0B6  7507            jne    loc_E0BF                    ; mismatch → CPU error
F000:E0B8  F8              clc                                ; CF=0 — second pass
F000:E0B9  EBE3            jmp    loc_E09E                    ; repeat with AX = 0

loc_E0BB:    ; xrefs: E0B2
F000:E0BB  0BC7            or     ax, di                      ; second pass: DI must be 0
F000:E0BD  7402            je     loc_E0C1                    ; all OK → continue POST

; ----------------------------------------------------------------------------------------------
; Halt on fatal CPU/ROM/RAM error (infinite loop)
; ----------------------------------------------------------------------------------------------
loc_E0BF:    ; xrefs: E071 E073 E075 E077 E07E E084 E089 E08B E08D E094 E098 E0B6 E0BF E0E0
F000:E0BF  EBFE            jmp    loc_E0BF                    ; hang: test failed

; ----------------------------------------------------------------------------------------------
; Initial hardware setup (DS=SS=F000 → writes to registers at F000:0xxx):
; video register, floppy controller, real 8255 (F000:0001/3/5/7), then ROM checksum.
; ----------------------------------------------------------------------------------------------
loc_E0C1:    ; xrefs: E0BD
F000:E0C1  8CCB            mov    bx, cs                      ; BX = CS = F000
F000:E0C3  8ED3            mov    ss, bx                      ; SS = F000 ("stack in ROM" for the mov sp+jmp trick)
F000:E0C5  8EDB            mov    ds, bx                      ; DS = F000 — access to hardware registers F000:0000–0FFF
F000:E0C7  A30002          mov    word [200h], ax             ; F000:0200 ← 0: video registers (color/mode) cleared
F000:E0CA  A30106          mov    word [601h], ax             ; F000:0601 ← 0 (motors off, 765 in reset); word write also hits F000:0602 (byte write in my)
F000:E0CD  C606070099      mov    byte [7], 99h               ; F000:0007 — real 8255 control word: 99h (PA in, PB out, PC in), as in XT
F000:E0D2  C606030080      mov    byte [3], 80h               ; F000:0003 — 8255 port B: bit 7 = 1 (keyboard reset/disable), speaker off
F000:E0D7  FC              cld                                ; string operations direction — forward
F000:E0D8  B7E0            mov    bh, 0E0h                    ; BX = E000h (BL=0 after register test) — start of block for checksum
F000:E0DA  BC4CE0          mov    sp, 0E04Ch                  ; SP → word E04C = return address E0E0 in ROM (no stack yet)
F000:E0DD  E95A05          jmp    loc_E63A                    ; checksum of 8 KB F000:E000–FFFF (ZF=1 — byte sum is 0)

; ----------------------------------------------------------------------------------------------
; Return after ROM checksum. Initialize real 6845 (F000:0000/0002) from first table F0A4 (40x25),
; clear video memory B800, then check warm boot flag 0040:0072.
; ----------------------------------------------------------------------------------------------
loc_E0E0:    ; xrefs: E0DA
F000:E0E0  75DD            jne    loc_E0BF                    ; ROM checksum bad → halt
F000:E0E2  B800B8          mov    ax, 0B800h                  ; video memory segment B800h
F000:E0E5  8EC0            mov    es, ax                      ; ES = B800
F000:E0E7  BEA4F0          mov    si, 0F0A4h                  ; SI = 6845 parameter table (F000:F0A4, first one — 40x25)
F000:E0EA  33C0            xor    ax, ax                      ; AX = 0 (AH = 6845 register number)
F000:E0EC  8BD8            mov    bx, ax                      ; BX = 0 → DS:BX = F000:0000 — real 6845 address register
F000:E0EE  B91000          mov    cx, 10h                     ; 16 registers R0–R15

loc_E0F1:    ; xrefs: E0F9
F000:E0F1  8827            mov    byte [bx], ah               ; register number → 6845 address register (F000:0000)
F000:E0F3  FEC4            inc    ah                          ; next register
F000:E0F5  AC              lodsb  al, byte [si]               ; value from table F0A4
F000:E0F6  884702          mov    byte [bx + 2], al           ; to 6845 data register (F000:0002)
F000:E0F9  E2F6            loop   loc_E0F1                    ; loop over 16 registers
F000:E0FB  B82007          mov    ax, 720h                    ; space with attribute 07h (gray on black)
F000:E0FE  33FF            xor    di, di                      ; DI = 0 — start of video memory
F000:E100  B520            mov    ch, 20h                     ; CX = 2000h (CL=0 after loop) words = 16 KB
F000:E102  F3AB            rep stosw word es:[di], ax         ; clear video memory B800:0000–3FFF
F000:E104  C70600023028    mov    word [200h], 2830h          ; F000:0200/0201: color 30h, mode 28h (40x25 text, video on, blink)
F000:E10A  8ED9            mov    ds, cx                      ; DS = 0 (CX=0 after rep)
F000:E10C  8B2E7204        mov    bp, word [472h]             ; BP = 0040:0072 — reset flag (1234h = Ctrl+Alt+Del warm boot)
F000:E110  8BF9            mov    di, cx                      ; DI = 0
F000:E112  8EC1            mov    es, cx                      ; ES = 0 — first 16 KB of RAM
F000:E114  B520            mov    ch, 20h                     ; CX = 2000h words = 16 KB
F000:E116  81FD3412        cmp    bp, 1234h                   ; warm boot?
F000:E11A  742A            je     loc_E146                    ; yes → just zero 16 KB without testing
F000:E11C  B8FFFF          mov    ax, 0FFFFh                  ; cold start: pattern FFFFh
F000:E11F  F3AB            rep stosw word es:[di], ax         ; fill 0000:0000–3FFF with pattern FFFFh
F000:E121  B520            mov    ch, 20h                     ; CX = 2000h — test size (in words)
F000:E123  BC4EE0          mov    sp, 0E04Eh                  ; SP → word E04E = return address E129 in ROM (no stack yet)
F000:E126  E92C03          jmp    sub_E455                    ; test of the first 16 KB of RAM (sub_E455): FFh→0 check forward and 0 backward; ZF=1 — good

; ----------------------------------------------------------------------------------------------
; POST: continuation after the first 16 KB RAM test (sub_E455, returns via ROM "stack" word E04E).
; Input: ZF=1 — 16 KB OK; ZF=0 — failure, DI = failing byte address, AL = failing bit mask, DS=ES=0.
; On failure — prints «Ошибка базовой памяти» ("Base memory error") directly to video RAM and loops forever accessing the bad location.
; ----------------------------------------------------------------------------------------------
loc_E129:    ; xrefs: E123
F000:E129  741F            je     loc_E14A                    ; ZF=1 → first 16 KB of RAM OK, proceed (memory size detection)
F000:E12B  BB00B8          mov    bx, 0B800h                  ; RAM failure: stack not usable yet, write message directly to CGA video memory
F000:E12E  8EC3            mov    es, bx                      ; ES = B800h — text video buffer segment
F000:E130  8BDF            mov    bx, di                      ; BX = failing byte address (DI after sub_E455) — saved for the loop below
F000:E132  33FF            xor    di, di                      ; DI = 0 — start of screen (top-left corner)
F000:E134  BE08E2          mov    si, 0E208h                  ; SI → «Ошибка базовой памяти» ("Base memory error") (dat_E208)
F000:E137  B91500          mov    cx, 15h                     ; CX = 21 characters in string

loc_E13A:    ; xrefs: E13E
F000:E13A  2EAC            lodsb  al, byte cs:[si]            ; Fetch next string character from ROM (CS:SI)
F000:E13C  AA              stosb  byte es:[di], al            ; Write character code to video memory
F000:E13D  47              inc    di                          ; Skip attribute byte (stays 07h, filled earlier)
F000:E13E  E2FA            loop   loc_E13A                    ; Repeat for all 21 characters

loc_E140:    ; xrefs: E144
F000:E140  8827            mov    byte [bx], ah               ; Endless loop: write AH to failing location DS:BX (DS=0)…
F000:E142  8A07            mov    al, byte [bx]               ; …and read it back — probably to locate the faulty chip with an oscilloscope
F000:E144  EBFA            jmp    loc_E140                    ; Loop forever (machine "hangs" on RAM error)

loc_E146:    ; xrefs: E11A
F000:E146  33C0            xor    ax, ax                      ; Warm restart (0:0472=1234h): no test needed, just zero the first 16 KB
F000:E148  F3AB            rep stosw word es:[di], ax         ; Zero-fill 2000h words from 0000:0000 (CX=2000h, ES:DI=0:0)

; ----------------------------------------------------------------------------------------------
; RAM size detection in 16 KB blocks (segments 0400h…9C00h, up to 640 KB).
; Each block found is filled with FFFFh — preparing for the subsequent sub_E455 test (expects FFh).
; Result: 0040:0013 = memory size in KB; then stack 0030:0100 and initial vector setup.
; ----------------------------------------------------------------------------------------------
loc_E14A:    ; xrefs: E129
F000:E14A  48              dec    ax                          ; AX = 0 → FFFFh: fill pattern for blocks being tested (for the test in sub_E455)
F000:E14B  892E7204        mov    word [472h], bp             ; Restore reset flag 0040:0072 (DS=0, address 0:0472) — wiped by clearing
F000:E14F  BA0004          mov    dx, 400h                    ; DX = 0400h — segment of the second 16 KB block (first already tested)
F000:E152  BB1000          mov    bx, 10h                     ; BX = 16 — RAM size counter in KB (first 16 KB already present)

loc_E155:    ; xrefs: E179
F000:E155  8EC2            mov    es, dx                      ; ES = segment of block under test
F000:E157  33FF            xor    di, di                      ; DI = 0 — start of block
F000:E159  26C705AA55      mov    word es:[di], 55AAh         ; Write probe word 55AAh at block start
F000:E15E  90              nop                                ; Delay for bus settling before read
F000:E15F  26803DAA        cmp    byte es:[di], 0AAh          ; Low byte read back as AAh? → memory present
F000:E163  7407            je     loc_E16C                    ; Yes — block present
F000:E165  26807D0155      cmp    byte es:[di + 1], 55h       ; Otherwise check high byte 55h
F000:E16A  750F            jne    loc_E17B                    ; Neither byte matched — end of RAM, exit

loc_E16C:    ; xrefs: E163
F000:E16C  B520            mov    ch, 20h                     ; CX = 2000h words (CL=0 after previous REP) = 16 KB
F000:E16E  F3AB            rep stosw word es:[di], ax         ; Fill block with FFFFh (test preparation)
F000:E170  80C604          add    dh, 4                       ; Next block: segment += 0400h (16 KB)
F000:E173  83C310          add    bx, 10h                     ; RAM size += 16 KB
F000:E176  80FEA0          cmp    dh, 0A0h                    ; Reached segment A000h (640 KB — video memory boundary)?
F000:E179  75DA            jne    loc_E155                    ; No — check next block

loc_E17B:    ; xrefs: E16A
F000:E17B  891E1304        mov    word [413h], bx             ; 0040:0013 = base memory size in KB (DS=0, address 0:0413)
F000:E17F  B83000          mov    ax, 30h                     ; Stack: SS = 0030h…
F000:E182  8ED0            mov    ss, ax                      ; …(standard IBM PC POST stack area, 0030:0100 = phys. 00400h)
F000:E184  BC0001          mov    sp, 100h                    ; SP = 0100h — top of stack
F000:E187  B92000          mov    cx, 20h                     ; CX = 32 — vectors INT 00h–1Fh
F000:E18A  2BFF            sub    di, di                      ; DI = 0 — start of interrupt vector table
F000:E18C  8EC7            mov    es, di                      ; ES = 0000h — vector table segment

loc_E18E:    ; xrefs: E195
F000:E18E  B8A1FE          mov    ax, 0FEA1h                  ; Offset of temporary handler F000:FEA1 («mov ah,1 / iret»)
F000:E191  AB              stosw  word es:[di], ax            ; Store vector offset
F000:E192  8CC8            mov    ax, cs                      ; Handler segment = CS = F000h
F000:E194  AB              stosw  word es:[di], ax            ; Store vector segment
F000:E195  E2F7            loop   loc_E18E                    ; All 32 vectors → temporary stub setting AH=1 (interrupt-occurred flag for tests)
F000:E197  C70608000A00    mov    word [8], 0Ah               ; NMI vector (INT 02h) offset = 000Ah — NMI_ENTRY (jmp to NMI_HANDLER F400:006A)…
F000:E19D  C7060A0000F4    mov    word [0Ah], 0F400h          ; …segment F400h: NMI_ENTRY F400:000A
F000:E1A3  C7063C000D00    mov    word [3Ch], 0Dh             ; INT 0Fh vector offset = 000Dh — common hardware interrupt dispatcher…
F000:E1A9  C7063E0000F4    mov    word [3Eh], 0F400h          ; …segment F400h: INT0F_IRQ_DISPATCH F400:000D (replaces 8259)
F000:E1AF  BF4000          mov    di, 40h                     ; DI = 40h — INT 10h vector
F000:E1B2  8CC8            mov    ax, cs                      ; DS = CS = F000h to read the table from ROM
F000:E1B4  8ED8            mov    ds, ax                      ; DS = F000h
F000:E1B6  BE03FF          mov    si, 0FF03h                  ; SI → table of INT 10h–1Fh handler offsets (F000:FF03)
F000:E1B9  B91000          mov    cx, 10h                     ; CX = 16 vectors (INT 10h–1Fh)

loc_E1BC:    ; xrefs: E1BF
F000:E1BC  A5              movsw  word es:[di], word [si]     ; Copy handler offset into vector
F000:E1BD  47              inc    di                          ; Skip segment word (already F000h)…
F000:E1BE  47              inc    di                          ; …
F000:E1BF  E2FB            loop   loc_E1BC                    ; Repeat for INT 10h–1Fh (INT 18h gets offset 0000h)
F000:E1C1  EB5A            jmp    loc_E21D                    ; Skip over message strings — to video init and keyboard test

dat_E1C3:    ; xrefs: E29A
F000:E1C3  91A1AEA920E2…   db     'Сбой таймера'              ; POST message «Сбой таймера» ("Timer failure") (CP866)
F000:E1CF  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E1D2:    ; xrefs: E380
F000:E1D2  2091A1AEA920…   db     ' Сбой памяти'              ; POST message « Сбой памяти» (" Memory failure") (after address and failing bit mask)
F000:E1DE  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E1E1:    ; xrefs: E25E
F000:E1E1  8EE8A8A1AAA0…   db     'Ошибка клавиатуры,'        ; POST message «Ошибка клавиатуры,» ("Keyboard error,") (keyboard reset response ≠ AAh)
F000:E1F3  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E1F6:    ; xrefs: E24A
F000:E1F6  8DA5E220AAAB…   db     'Нет клавиатуры!'           ; POST message «Нет клавиатуры!» ("No keyboard!") (no response to reset)
F000:E205  0A0D00          db     0Ah,0Dh,00h                 ; Line feed + end of string

dat_E208:    ; xrefs: E134
F000:E208  8EE8A8A1AAA0…   db     'Ошибка базовой памяти'     ; «Ошибка базовой памяти» ("Base memory error") — 21 characters, no terminator; written directly to video buffer

; ----------------------------------------------------------------------------------------------
; POST: set video mode, show banner, reset and test keyboard.
; Keyboard is attached via a real 8255 (F000:0001 = port A — scan code, F000:0003 = port B).
; Response is awaited on bit 13 of the interrupt status word F000:0200 (keyboard IRQ request).
; ----------------------------------------------------------------------------------------------
loc_E21D:    ; xrefs: E1C1
F000:E21D  B80300          mov    ax, 3                       ; AX = 0003h: INT 10h function 0 — set text mode 3 (80×25 color)
F000:E220  8AFC            mov    bh, ah                      ; BH = 0 — video page 0
F000:E222  CD10            int    10h                         ; Set video mode (clears screen)
F000:E224  BE13E0          mov    si, 0E013h                  ; SI → banner «ПЭВМ "Практик"» ("PC "Praktik"") + «Подождите пожалуйста...» ("Please wait...") (dat_E013)
F000:E227  E89204          call   sub_E6BC                    ; Print ASCIIZ string from ROM via teletype
F000:E22A  C606030040      mov    byte [3], 40h               ; 8255 port B (F000:0003) = 40h: bit 6 inverted relative to 61h → keyboard clock held low (reset)
F000:E22F  B95629          mov    cx, 2956h                   ; ~20 ms delay holding keyboard clock line

loc_E232:    ; xrefs: E233
F000:E232  90              nop                                ; No-op in delay loop
F000:E233  E2FD            loop   loc_E232                    ; Delay loop
F000:E235  C606030080      mov    byte [3], 80h               ; Port B = 80h (≡ 61h=C0h): clock released, bit 7 — clear keyboard shift register
F000:E23A  90              nop                                ; Short pause
F000:E23B  C606030000      mov    byte [3], 0                 ; Port B = 00h (≡ 61h=40h): keyboard enabled — wait for self-test code AAh

loc_E240:    ; xrefs: E248
F000:E240  F70600020020    test   word [200h], 2000h          ; Bit 13 of F000:0200 = keyboard interrupt request (scan code arrived)?
F000:E246  750A            jne    loc_E252                    ; Yes — read keyboard response
F000:E248  E2F6            loop   loc_E240                    ; Wait up to 65536 iterations (CX=0 after delay)
F000:E24A  BEF6E1          mov    si, 0E1F6h                  ; No response: SI → «Нет клавиатуры!» ("No keyboard!") (dat_E1F6)
F000:E24D  E86C04          call   sub_E6BC                    ; Print error message
F000:E250  EB12            jmp    loc_E264                    ; Continue POST without keyboard

loc_E252:    ; xrefs: E246
F000:E252  A00100          mov    al, byte [1]                ; Read scan code from 8255 port A (F000:0001, equivalent of port 60h)
F000:E255  C606030080      mov    byte [3], 80h               ; Port B = 80h: reset/acknowledge keyboard register (bit 7, like IBM 61h bit 7)
F000:E25A  3CAA            cmp    al, 0AAh                    ; Response AAh = keyboard passed self-test
F000:E25C  7406            je     loc_E264                    ; Yes — all OK
F000:E25E  BEE1E1          mov    si, 0E1E1h                  ; Otherwise SI → «Ошибка клавиатуры,» ("Keyboard error,") (dat_E1E1)
F000:E261  E85804          call   sub_E6BC                    ; Print message

; ----------------------------------------------------------------------------------------------
; POST: 8253 timer test (real chip, mapped at F000:0A00–0A06).
; Channel 0 in mode 0; its interrupt arrives via INT 0Fh → INT 08h → temporary stub FEA1, which sets AH=1.
; First a count of 22 must expire within ≤22 iterations (timer works), then a count of 255 must not expire within 12 (not too fast).
; ----------------------------------------------------------------------------------------------
loc_E264:    ; xrefs: E250 E25C
F000:E264  E8821C          call   sub_FEE9                    ; DS = 0040h (BIOS data area)
F000:E267  FB              sti                                ; Enable interrupts — needed to receive timer IRQ
F000:E268  2EC606010608    mov    byte cs:[601h], 8           ; F000:0601 = 08h: floppy controller control register; bit 3 probably masks the floppy IRQ
F000:E26E  2EC706060A1000  mov    word cs:[0A06h], 10h        ; 8253 (F000:0A06) = 10h: channel 0, low byte only, mode 0; word write (+00h to 0A07; byte write in my)
F000:E275  B91600          mov    cx, 16h                     ; CX = 22 wait iterations
F000:E278  8AE1            mov    ah, cl                      ; AH = 16h (≠1); interrupt stub will change AH to 1
F000:E27A  2E880E000A      mov    byte cs:[0A00h], cl         ; Channel 0 counter (F000:0A00) = 22 — start counting directly, bypassing the emulator

loc_E27F:    ; xrefs: E284
F000:E27F  80FC01          cmp    ah, 1                       ; Timer interrupt occurred (AH=1)?
F000:E282  7404            je     loc_E288                    ; Yes — timer works, go to second check
F000:E284  E2F9            loop   loc_E27F                    ; Wait at most 22 iterations
F000:E286  EB12            jmp    loc_E29A                    ; No interrupt — timer faulty/slow

loc_E288:    ; xrefs: E282
F000:E288  B10C            mov    cl, 0Ch                     ; CL = 12 iterations for second check
F000:E28A  B4FF            mov    ah, 0FFh                    ; AH = FFh (≠1)
F000:E28C  2E8826000A      mov    byte cs:[0A00h], ah         ; Channel 0 counter = 255 (restart count in mode 0)

loc_E291:    ; xrefs: E296
F000:E291  80FC01          cmp    ah, 1                       ; Interrupt came too early?
F000:E294  7404            je     loc_E29A                    ; Yes — timer too fast → error
F000:E296  E2F9            loop   loc_E291                    ; Check 12 iterations
F000:E298  EB09            jmp    loc_E2A3                    ; Timer OK — program operating mode

loc_E29A:    ; xrefs: E286 E294
F000:E29A  BEC3E1          mov    si, 0E1C3h                  ; SI → «Сбой таймера» ("Timer failure") (dat_E1C3)
F000:E29D  E81C04          call   sub_E6BC                    ; Print message
F000:E2A0  FA              cli                                ; Disable interrupts

loc_E2A1:    ; xrefs: E2A1
F000:E2A1  EBFE            jmp    loc_E2A1                    ; Halt: endless loop (fatal timer error)

; ----------------------------------------------------------------------------------------------
; POST: timer operating setup (18.2 Hz), set vectors INT 08h–0Fh, 05h, 18h,
; initialize BIOS data area: equipment, keyboard buffer; check warm reset flag.
; ----------------------------------------------------------------------------------------------
loc_E2A3:    ; xrefs: E298
F000:E2A3  2EC706060A3600  mov    word cs:[0A06h], 36h        ; 8253 (F000:0A06) = 36h: channel 0, low+high byte, mode 3 (square wave); word write again
F000:E2AA  2BC0            sub    ax, ax                      ; AX = 0 — divisor 65536
F000:E2AC  E640            out    40h, al                     ; OUT 40h via emulator (NMI): LSB; emulator rescales the divisor for the real 8253 clock
F000:E2AE  E640            out    40h, al                     ; MSB → resulting IRQ0 rate ≈ 18.2 Hz, as on IBM PC
F000:E2B0  FA              cli                                ; Disable interrupts while changing vectors
F000:E2B1  B90800          mov    cx, 8                       ; CX = 8 vectors (INT 08h–0Fh)
F000:E2B4  0E              push   cs                          ; DS = CS…
F000:E2B5  1F              pop    ds                          ; …= F000h
F000:E2B6  BEF3FE          mov    si, 0FEF3h                  ; SI → vector_table (F000:FEF3) — INT 08h–0Fh handler offsets
F000:E2B9  BF2000          mov    di, 20h                     ; DI = 20h — INT 08h vector (ES = 0)

loc_E2BC:    ; xrefs: E2BF
F000:E2BC  A5              movsw  word es:[di], word [si]     ; Copy handler offset
F000:E2BD  47              inc    di                          ; Skip segment (F000h for 08–0Eh; INT 0Fh keeps F400h)…
F000:E2BE  47              inc    di                          ; …
F000:E2BF  E2FB            loop   loc_E2BC                    ; Repeat for INT 08h–0Fh
F000:E2C1  26C706140054FF  mov    word es:[14h], 0FF54h       ; INT 05h vector (print screen) → F000:FF54
F000:E2C8  26C706620000F6  mov    word es:[62h], 0F600h       ; INT 18h vector segment = F600h (offset 0000h) — ROM BASIC at the IBM address
F000:E2CF  FB              sti                                ; Enable interrupts
F000:E2D0  2EC606030000    mov    byte cs:[3], 0              ; 8255 port B = 00h (≡ 61h=40h): keyboard enabled, speaker off
F000:E2D6  E8101C          call   sub_FEE9                    ; DS = 0040h — BIOS data area
F000:E2D9  1E              push   ds                          ; Save DS=0040h (restored at E3CA)
F000:E2DA  C70610002050    mov    word [10h], 5020h           ; 0040:0010 = 5020h: 1 LPT, game adapter, CGA 80×25; no floppy found yet (bit 0=0)
F000:E2E0  BE1E00          mov    si, 1Eh                     ; SI = 001Eh — start of keyboard ring buffer 0040:001E
F000:E2E3  89361A00        mov    word [1Ah], si              ; 0040:001A — keyboard buffer head pointer
F000:E2E7  89361C00        mov    word [1Ch], si              ; 0040:001C — tail pointer (buffer empty)
F000:E2EB  89368000        mov    word [80h], si              ; 0040:0080 — keyboard buffer start
F000:E2EF  83C620          add    si, 20h                     ; +32 bytes (16 words)
F000:E2F2  89368200        mov    word [82h], si              ; 0040:0082 — keyboard buffer end (003Eh)
F000:E2F6  813E72003412    cmp    word [72h], 1234h           ; 0040:0072 = 1234h — warm restart (Ctrl+Alt+Del)?
F000:E2FC  B81000          mov    ax, 10h                     ; AX = 16 — KB already tested (flags unchanged)
F000:E2FF  7530            jne    loc_E331                    ; Cold start — full RAM test with counter display
F000:E301  C70672000000    mov    word [72h], 0               ; Warm: clear flag 0040:0072…
F000:E307  E98000          jmp    loc_E38A                    ; …and skip memory test

; ----------------------------------------------------------------------------------------------
; POST: test of RAM above 16 KB in 16 KB blocks (blocks pre-filled with FFFFh at E16C).
; The screen shows «NNN Кб проверено» ("NNN KB tested") (carriage return without line feed).
; On failure: prints «сегмент:смещение маска Сбой памяти» ("segment:offset mask Memory failure"), 0040:0013 is truncated to the tested size, waits for a key.
; ----------------------------------------------------------------------------------------------
loc_E30A:    ; xrefs: E355
F000:E30A  8B1E1300        mov    bx, word [13h]              ; BX = RAM size in KB (0040:0013)
F000:E30E  2BD8            sub    bx, ax                      ; Minus 16 KB already tested
F000:E310  B104            mov    cl, 4                       ; Divide by 16…
F000:E312  D3EB            shr    bx, cl                      ; …= number of remaining 16 KB blocks
F000:E314  8BCB            mov    cx, bx                      ; CX = block counter
F000:E316  BB0004          mov    bx, 400h                    ; BX = 0400h — segment of first block to test

loc_E319:    ; xrefs: E35A
F000:E319  8EDB            mov    ds, bx                      ; DS = block segment (read source in sub_E455)
F000:E31B  8EC3            mov    es, bx                      ; ES = block segment (write destination)
F000:E31D  81C30004        add    bx, 400h                    ; BX → next block segment
F000:E321  52              push   dx                          ; Save DX
F000:E322  51              push   cx                          ; Save block counter
F000:E323  53              push   bx                          ; Save next block segment
F000:E324  50              push   ax                          ; Save tested-KB counter
F000:E325  B90020          mov    cx, 2000h                   ; CX = 2000h words = 16 KB
F000:E328  E82A01          call   sub_E455                    ; Block test: check FFh→write 00h forward, check 00h backward
F000:E32B  7536            jne    loc_E363                    ; ZF=0 → memory failure detected
F000:E32D  58              pop    ax                          ; AX = KB tested
F000:E32E  051000          add    ax, 10h                     ; +16 KB

loc_E331:    ; xrefs: E2FF
F000:E331  50              push   ax                          ; Save number of KB tested
F000:E332  BB0A00          mov    bx, 0Ah                     ; Divisor 10 — convert to decimal
F000:E335  B90300          mov    cx, 3                       ; 3 digits

loc_E338:    ; xrefs: E340
F000:E338  33D2            xor    dx, dx                      ; High part of dividend = 0
F000:E33A  F7F3            div    bx                          ; AX = AX/10, DX = remainder (next digit)
F000:E33C  80CA30          or     dl, 30h                     ; Digit → ASCII
F000:E33F  52              push   dx                          ; Push digits (least to most significant)
F000:E340  E2F6            loop   loc_E338                    ; All 3 digits
F000:E342  B90300          mov    cx, 3                       ; CX = 3 — print digits

loc_E345:    ; xrefs: E349
F000:E345  58              pop    ax                          ; Pop digit (most to least significant)
F000:E346  E85A03          call   sub_E6A3                    ; Print character via teletype (INT 10h, AH=0Eh)
F000:E349  E2FA            loop   loc_E345                    ; All 3 digits
F000:E34B  BE3DE0          mov    si, 0E03Dh                  ; SI → « Кб проверено» (" KB tested") (dat_E03D)
F000:E34E  E86B03          call   sub_E6BC                    ; Print string
F000:E351  58              pop    ax                          ; AX = KB tested
F000:E352  3D1000          cmp    ax, 10h                     ; First call (16 KB only, entered from E2FF)?
F000:E355  74B3            je     loc_E30A                    ; Yes — go to block loop
F000:E357  5B              pop    bx                          ; Restore next block segment
F000:E358  59              pop    cx                          ; Restore block counter
F000:E359  5A              pop    dx                          ; Restore DX
F000:E35A  E2BD            loop   loc_E319                    ; Next block
F000:E35C  B00A            mov    al, 0Ah                     ; Test complete: line feed
F000:E35E  E84203          call   sub_E6A3                    ; Print LF
F000:E361  EB27            jmp    loc_E38A                    ; On to option ROM scan

loc_E363:    ; xrefs: E32B
F000:E363  8AE8            mov    ch, al                      ; Failure: CH = failing bit mask (AL from sub_E455)
F000:E365  B00A            mov    al, 0Ah                     ; Line feed
F000:E367  E83903          call   sub_E6A3                    ; Print LF
F000:E36A  E81203          call   sub_E67F                    ; Print failure address «DS:DI» in hex
F000:E36D  B020            mov    al, 20h                     ; Space
F000:E36F  E83103          call   sub_E6A3                    ; Print space
F000:E372  58              pop    ax                          ; AX = size tested before the failing block, KB
F000:E373  83C406          add    sp, 6                       ; Pop saved BX, CX, DX from stack
F000:E376  1F              pop    ds                          ; DS = 0040h (saved at E2D9)
F000:E377  1E              push   ds                          ; Save again for E3CA
F000:E378  A31300          mov    word [13h], ax              ; 0040:0013 = size of good memory in KB (memory above the failure is not used)
F000:E37B  8AC5            mov    al, ch                      ; AL = failing bit mask
F000:E37D  E81203          call   sub_E692                    ; Print mask as two hex digits
F000:E380  BED2E1          mov    si, 0E1D2h                  ; SI → « Сбой памяти» (" Memory failure") (dat_E1D2)
F000:E383  E83603          call   sub_E6BC                    ; Print message
F000:E386  33C0            xor    ax, ax                      ; AH = 0: INT 16h — wait for keypress
F000:E388  CD16            int    16h                         ; Wait for a key so the user sees the error

; ----------------------------------------------------------------------------------------------
; Option ROM scan (C800:0000…EFFF:0000 in 2 KB steps, signature AA55h) and their initialization (sub_E647).
; Then check for ROM BASIC at F600:0000 (signature E9h 8Fh + 32 KB checksum); if absent INT 18h → tape loader F000:E48A.
; ----------------------------------------------------------------------------------------------
loc_E38A:    ; xrefs: E307 E361
F000:E38A  BA00C8          mov    dx, 0C800h                  ; DX = C800h — option ROM scan start segment

loc_E38D:    ; xrefs: E3A5
F000:E38D  8EDA            mov    ds, dx                      ; DS = segment under test
F000:E38F  2BDB            sub    bx, bx                      ; BX = 0
F000:E391  8B07            mov    ax, word [bx]               ; Read first 2 bytes
F000:E393  3D55AA          cmp    ax, 0AA55h                  ; Option ROM signature 55h,AAh?
F000:E396  7505            jne    loc_E39D                    ; No — next 2 KB
F000:E398  E8AC02          call   sub_E647                    ; Found: verify checksum and call init; DX += ROM size in paragraphs
F000:E39B  EB04            jmp    loc_E3A1                    ; On to end-of-range check

loc_E39D:    ; xrefs: E396
F000:E39D  81C28000        add    dx, 80h                     ; Scan step 80h paragraphs = 2 KB

loc_E3A1:    ; xrefs: E39B
F000:E3A1  81FA00F0        cmp    dx, 0F000h                  ; Reached F000h?
F000:E3A5  72E6            jb     loc_E38D                    ; No — continue scan
F000:E3A7  2BDB            sub    bx, bx                      ; BX = 0
F000:E3A9  BA00F6          mov    dx, 0F600h                  ; DX = F600h — ROM BASIC segment on IBM PC
F000:E3AC  8EDA            mov    ds, dx                      ; DS = F600h (on "Praktik" probably a mirror of its own ROM)
F000:E3AE  B90080          mov    cx, 8000h                   ; CX = 32 KB for checksum
F000:E3B1  813FE98F        cmp    word [bx], 8FE9h            ; First word = E9h 8Fh (JMP near — BASIC entry point)?
F000:E3B5  7505            jne    loc_E3BC                    ; No — BASIC absent
F000:E3B7  E88302          call   sub_E63D                    ; Checksum of 32 KB F600:0000…7FFF
F000:E3BA  740E            je     loc_E3CA                    ; Sum = 0 → BASIC present, INT 18h vector stays F600:0000

loc_E3BC:    ; xrefs: E3B5
F000:E3BC  33C0            xor    ax, ax                      ; No BASIC:
F000:E3BE  8ED8            mov    ds, ax                      ; DS = 0 — vector table
F000:E3C0  C70660008AE4    mov    word [60h], 0E48Ah          ; INT 18h vector offset = E48Ah — cassette tape boot monitor…
F000:E3C6  8C0E6200        mov    word [62h], cs              ; …segment = F000h

; ----------------------------------------------------------------------------------------------
; Floppy drive detection: reset FDC (INT 13h AH=0), motor on, seek to tracks 1 and 34.
; Drives found are flagged in 0040:0010 (bit 0 — floppy present, bits 6–7 — number of drives − 1).
; Then: LPT/COM timeouts, LPT1 address, beep, jump to INT 18h or INT 19h.
; ----------------------------------------------------------------------------------------------
loc_E3CA:    ; xrefs: E3BA
F000:E3CA  1F              pop    ds                          ; DS = 0040h
F000:E3CB  32E4            xor    ah, ah                      ; AH = 0 — "reset disk system" function
F000:E3CD  8AD4            mov    dl, ah                      ; DL = 0 — drive A:
F000:E3CF  CD13            int    13h                         ; Reset floppy controller (INT 13h)
F000:E3D1  F6C4FF          test   ah, 0FFh                    ; Reset error (AH≠0)?
F000:E3D4  7522            jne    loc_E3F8                    ; Yes — controller not responding, no floppy drives
F000:E3D6  B01C            mov    al, 1Ch                     ; AL = 1Ch — DOR 3F2h: motor A, DMA/IRQ enabled, reset released, drive 0 selected
F000:E3D8  33D2            xor    dx, dx                      ; DX = 0 (DL = drive number)
F000:E3DA  88163E00        mov    byte [3Eh], dl              ; 0040:003E = 0: all drives need recalibration

loc_E3DE:    ; xrefs: E40A
F000:E3DE  52              push   dx                          ; Save drive number
F000:E3DF  BAF203          mov    dx, 3F2h                    ; DX = 3F2h — digital output register (DOR)
F000:E3E2  EE              out    dx, al                      ; OUT 3F2h (emulated via NMI): motor on and drive select
F000:E3E3  5A              pop    dx                          ; Restore DL = drive
F000:E3E4  2BC9            sub    cx, cx                      ; CX = 0 (65536 iterations)

loc_E3E6:    ; xrefs: E3E6
F000:E3E6  E2FE            loop   loc_E3E6                    ; Motor spin-up delay, part 1

loc_E3E8:    ; xrefs: E3E8
F000:E3E8  E2FE            loop   loc_E3E8                    ; Motor spin-up delay, part 2
F000:E3EA  B501            mov    ch, 1                       ; CH = 1 — track 1
F000:E3EC  E8BB0A          call   sub_EEAA                    ; Recalibrate (if needed) and seek drive DL to track CH
F000:E3EF  7207            jb     loc_E3F8                    ; CF=1 — drive not responding
F000:E3F1  B522            mov    ch, 22h                     ; CH = 34 — track 34 (head positioner check, as in IBM XT)
F000:E3F3  E8B40A          call   sub_EEAA                    ; Seek to track 34
F000:E3F6  7302            jae    loc_E3FA                    ; Success → flag the drive

loc_E3F8:    ; xrefs: E3D4 E3EF
F000:E3F8  EB17            jmp    loc_E411                    ; Error — stop probing drives

loc_E3FA:    ; xrefs: E3F6
F000:E3FA  0AD2            or     dl, dl                      ; Was it drive 0?
F000:E3FC  750E            jne    loc_E40C                    ; No (drive 1) — flag second floppy drive
F000:E3FE  FE061000        inc    byte [10h]                  ; 0040:0010 bit 0 = 1: floppy drives installed
F000:E402  FEC2            inc    dl                          ; DL = 1 — check drive B:
F000:E404  32E4            xor    ah, ah                      ; AH = 0 — reset
F000:E406  CD13            int    13h                         ; Reset controller before probing second drive
F000:E408  B02D            mov    al, 2Dh                     ; AL = 2Dh — DOR: motor B, DMA/IRQ enabled, reset released, drive 1 selected
F000:E40A  EBD2            jmp    loc_E3DE                    ; Repeat check for drive 1

loc_E40C:    ; xrefs: E3FC
F000:E40C  800E100040      or     byte [10h], 40h             ; 0040:0010 bits 6–7 = 01: two floppy drives

loc_E411:    ; xrefs: E3F8
F000:E411  BAF203          mov    dx, 3F2h                    ; DX = 3F2h — DOR
F000:E414  B00C            mov    al, 0Ch                     ; AL = 0Ch — all motors off, controller active, DMA/IRQ enabled
F000:E416  EE              out    dx, al                      ; Turn motors off
F000:E417  BF7800          mov    di, 78h                     ; DI = 78h — 0040:0078, printer timeout table
F000:E41A  1E              push   ds                          ; ES = DS…
F000:E41B  07              pop    es                          ; …= 0040h
F000:E41C  B81414          mov    ax, 1414h                   ; Printer timeout = 20 (14h)
F000:E41F  AB              stosw  word es:[di], ax            ; 0040:0078–0079 — LPT1, LPT2
F000:E420  AB              stosw  word es:[di], ax            ; 0040:007A–007B — LPT3, LPT4
F000:E421  B80101          mov    ax, 101h                    ; Serial port timeout = 1
F000:E424  AB              stosw  word es:[di], ax            ; 0040:007C–007D — COM1, COM2
F000:E425  AB              stosw  word es:[di], ax            ; 0040:007E–007F — COM3, COM4
F000:E426  C70608007803    mov    word [8], 378h              ; 0040:0008 = 378h — LPT1 base address (port is emulated)
F000:E42C  BA0100          mov    dx, 1                       ; DH = 0 long, DL = 1 short beep
F000:E42F  E8E112          call   sub_F713                    ; "POST complete" beep
F000:E432  F606100001      test   byte [10h], 1               ; Floppy drive found (0040:0010 bit 0)?
F000:E437  7502            jne    loc_E43B                    ; Yes — boot from disk
F000:E439  CD18            int    18h                         ; No floppy: INT 18h — ROM BASIC or tape loader

loc_E43B:    ; xrefs: E437
F000:E43B  B80300          mov    ax, 3                       ; AX = 0003h — 80×25 color mode
F000:E43E  CD10            int    10h                         ; Set video mode (clears screen)

; ----------------------------------------------------------------------------------------------
; COM1 detection — built right into POST (in my moved to F400:0C04 detect_com_ports and extended to COM2).
; Reads IIR 3FAh: on an 8250 bits 3–7 are always 0. But in dk port 3FAh is not in nmi_port_list and the NMI handler
; returns FFh — so COM1 is never detected (probably groundwork for future RS-232 support).
; ----------------------------------------------------------------------------------------------
F000:E440  33DB            xor    bx, bx                      ; BX = 0 → DS:BX = 0040:0000 — COM1 base address slot (DS = 0040)
F000:E442  BAFA03          mov    dx, 3FAh                    ; DX = 3FAh — COM1 interrupt identification register (IIR)
F000:E445  EC              in     al, dx                      ; IN 3FAh → NMI; port not emulated — AL = FFh
F000:E446  A8F8            test   al, 0F8h                    ; On a real 8250 IIR bits 3–7 are 0
F000:E448  7509            jne    loc_E453                    ; Not an 8250 (always so in dk) → don't register COM1
F000:E44A  C707F803        mov    word [bx], 3F8h             ; 0040:0000 = 3F8h — COM1 base address
F000:E44E  800E110002      or     byte [11h], 2               ; 0040:0011 bit 1 (bit 9 of the equipment word) — COM port count = 1

loc_E453:    ; xrefs: E448
F000:E453  CD19            int    19h                         ; INT 19h — boot OS from floppy

; ----------------------------------------------------------------------------------------------
; sub_E455 — RAM block test (DS=ES=segment, CX = length in words). Expects the block filled with FFh.
; Pass 1 (forward): each byte must be FFh, 00h written; pass 2 (backward): each byte 00h.
; Output: ZF=1 — OK; ZF=0 — failure, AL = XOR (failing bit mask), DI = failing byte offset.
; Also called before the stack is set up (via mov sp,E04Eh / jmp) — then RET takes the address from ROM.
; ----------------------------------------------------------------------------------------------
sub_E455:    ; xrefs: E126 E328
F000:E455  FC              cld                                ; Direction — forward
F000:E456  2BFF            sub    di, di                      ; DI = 0 — start of block
F000:E458  8BF7            mov    si, di                      ; SI = 0
F000:E45A  8BD9            mov    bx, cx                      ; BX = length in words…
F000:E45C  D1E3            shl    bx, 1                       ; …×2 = length in bytes
F000:E45E  B4FF            mov    ah, 0FFh                    ; AH = FFh — expected value in first pass

loc_E460:    ; xrefs: E476
F000:E460  8BF7            mov    si, di                      ; SI = DI — read where we write
F000:E462  8BCB            mov    cx, bx                      ; CX = block length in bytes

loc_E464:    ; xrefs: E46C
F000:E464  AC              lodsb  al, byte [si]               ; Read byte
F000:E465  32C4            xor    al, ah                      ; Compare with expected (XOR yields mask of bad bits)
F000:E467  750F            jne    loc_E478                    ; Mismatch — exit with ZF=0
F000:E469  32C0            xor    al, al                      ; AL = 0 — new value
F000:E46B  AA              stosb  byte es:[di], al            ; Write 00h to the checked byte
F000:E46C  E2F6            loop   loc_E464                    ; Whole block
F000:E46E  22E4            and    ah, ah                      ; Was this the first pass (AH=FFh)?
F000:E470  7406            je     loc_E478                    ; Second pass done (AH=0) — exit with ZF=1
F000:E472  8AE0            mov    ah, al                      ; AH = 0 — expect zeros in second pass
F000:E474  4F              dec    di                          ; DI → last byte of block
F000:E475  FD              std                                ; Direction — backward
F000:E476  EBE8            jmp    loc_E460                    ; Second pass (end to start)

loc_E478:    ; xrefs: E467 E470
F000:E478  FC              cld                                ; Restore forward direction (CLD does not affect flags)
F000:E479  C3              ret                                ; Return; ZF = test result

; ----------------------------------------------------------------------------------------------
; sub_E47A — expansion ROM checksum error message: «SSSS КС ПЗУ» ("SSSS ROM checksum").
; Input: DS = ROM segment. Preserves AX, DX.
; ----------------------------------------------------------------------------------------------
sub_E47A:    ; xrefs: E665
F000:E47A  52              push   dx                          ; Save DX (current scan segment)
F000:E47B  50              push   ax                          ; Save AX
F000:E47C  8CD8            mov    ax, ds                      ; AX = segment of bad ROM
F000:E47E  E80A02          call   sub_E68B                    ; Print AX as four hex digits
F000:E481  BE50E0          mov    si, 0E050h                  ; SI → « КС ПЗУ» (" ROM checksum") (dat_E050)
F000:E484  E83502          call   sub_E6BC                    ; Print string
F000:E487  58              pop    ax                          ; Restore AX
F000:E488  5A              pop    dx                          ; Restore DX
F000:E489  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; INT18_TAPE_LOADER — cassette tape program loader monitor (INT 18h vector when BASIC is absent).
; 40×25 screen, name input (up to 8 chars) into 0050:0001; reads headers (256 bytes at 0050:0009) via INT 15h AH=2.
; Header: +0 = A5h, +1..8 = name, +0Ah = length, +0Ch = load segment, +0Eh = offset, +10h = entry offset.
; On name match — loads the body and jumps far to load_segment:entry_offset. Does not return.
; ----------------------------------------------------------------------------------------------
INT18_TAPE_LOADER:    ; xrefs: E4B0 E4D7
F000:E48A  B80100          mov    ax, 1                       ; AX = 0001h — text mode 1 (40×25 color)
F000:E48D  CD10            int    10h                         ; Set video mode
F000:E48F  8CC8            mov    ax, cs                      ; DS = CS…
F000:E491  8ED8            mov    ds, ax                      ; …= F000h
F000:E493  BE44E5          mov    si, 0E544h                  ; SI → «Загрузка с ленты» ("Loading from tape") / «Введите имя программы» ("Enter program name") (dat_E544)
F000:E496  E81102          call   sub_E6AA                    ; Print strings with positioning
F000:E499  BE70E5          mov    si, 0E570h                  ; SI → name input field frame (dat_E570)
F000:E49C  E80B02          call   sub_E6AA                    ; Print frame
F000:E49F  B90900          mov    cx, 9                       ; CX = 9 — at most 8 name characters (9th → overflow)
F000:E4A2  BA1006          mov    dx, 610h                    ; DH = 6, DL = 16 — input field position inside the frame
F000:E4A5  B85000          mov    ax, 50h                     ; ES = 0050h…
F000:E4A8  8EC0            mov    es, ax                      ; …name buffer in area 0050:xxxx
F000:E4AA  BF0100          mov    di, 1                       ; DI = 1 — name at 0050:0001–0008
F000:E4AD  E83C01          call   sub_E5EC                    ; Read name string from keyboard
F000:E4B0  72D8            jb     INT18_TAPE_LOADER           ; CF=1 — name too long, start over

loc_E4B2:    ; xrefs: E4DE E507
F000:E4B2  B520            mov    ch, 20h                     ; CH = 20h — bit 5: cursor invisible
F000:E4B4  B401            mov    ah, 1                       ; INT 10h AH=1 — set cursor shape (hide)
F000:E4B6  CD10            int    10h                         ; Hide cursor
F000:E4B8  8CC0            mov    ax, es                      ; DS = ES…
F000:E4BA  8ED8            mov    ds, ax                      ; …= 0050h
F000:E4BC  BB0900          mov    bx, 9                       ; BX = 9 — header is read into 0050:0009
F000:E4BF  B80002          mov    ax, 200h                    ; AH = 2 — INT 15h "read blocks from cassette"
F000:E4C2  B90001          mov    cx, 100h                    ; CX = 256 bytes — header size
F000:E4C5  CD15            int    15h                         ; Read header from tape
F000:E4C7  7310            jae    loc_E4D9                    ; No errors — parse header
F000:E4C9  8CC8            mov    ax, cs                      ; Error: DS = CS…
F000:E4CB  8ED8            mov    ds, ax                      ; …= F000h
F000:E4CD  BE89E5          mov    si, 0E589h                  ; SI → «Ошибка чтения с ленты» ("Tape read error") (dat_E589)
F000:E4D0  E8D701          call   sub_E6AA                    ; Print message

loc_E4D3:    ; xrefs: E533
F000:E4D3  32E4            xor    ah, ah                      ; AH = 0 — wait for key
F000:E4D5  CD16            int    16h                         ; Wait for keypress
F000:E4D7  EBB1            jmp    INT18_TAPE_LOADER           ; Start over

loc_E4D9:    ; xrefs: E4C7
F000:E4D9  803E0900A5      cmp    byte [9], 0A5h              ; First header byte (0050:0009) = A5h — header marker?
F000:E4DE  75D2            jne    loc_E4B2                    ; No — read next block
F000:E4E0  BE0100          mov    si, 1                       ; SI → entered name 0050:0001
F000:E4E3  BF0A00          mov    di, 0Ah                     ; DI → name from header 0050:000A
F000:E4E6  B90800          mov    cx, 8                       ; 8 characters
F000:E4E9  F3A6            repe cmpsb byte [si], byte es:[di] ; Compare names
F000:E4EB  741C            je     loc_E509                    ; Match — load program
F000:E4ED  8CC8            mov    ax, cs                      ; Wrong program: DS = CS…
F000:E4EF  8ED8            mov    ds, ax                      ; …= F000h
F000:E4F1  BEBDE5          mov    si, 0E5BDh                  ; SI → «Пропущена программа » ("Program skipped ") (dat_E5BD)
F000:E4F4  E8B301          call   sub_E6AA                    ; Print message
F000:E4F7  B85000          mov    ax, 50h                     ; DS = 0050h…
F000:E4FA  8ED8            mov    ds, ax                      ; …
F000:E4FC  BE0A00          mov    si, 0Ah                     ; SI → name from header (0050:000A)
F000:E4FF  C606120000      mov    byte [12h], 0               ; Byte 0050:0012 = 0 — terminator after the 8 name characters
F000:E504  E8B501          call   sub_E6BC                    ; Print name; probably a bug: sub_E6BC reads CS:[SI], i.e. F000:000A rather than 0050:000A
F000:E507  EBA9            jmp    loc_E4B2                    ; Look for next header

loc_E509:    ; xrefs: E4EB
F000:E509  1E              push   ds                          ; Save DS=0050h
F000:E50A  8CC8            mov    ax, cs                      ; DS = CS…
F000:E50C  8ED8            mov    ds, ax                      ; …= F000h
F000:E50E  BED4E5          mov    si, 0E5D4h                  ; SI → «Программа загружается» ("Program loading") (dat_E5D4)
F000:E511  E89601          call   sub_E6AA                    ; Print message
F000:E514  1F              pop    ds                          ; DS = 0050h
F000:E515  A11500          mov    ax, word [15h]              ; AX = load segment from header (0050:0015)
F000:E518  8EC0            mov    es, ax                      ; ES = load segment
F000:E51A  8B1E1700        mov    bx, word [17h]              ; BX = load offset (0050:0017)
F000:E51E  8B0E1300        mov    cx, word [13h]              ; CX = program length in bytes (0050:0013)
F000:E522  B80002          mov    ax, 200h                    ; AH = 2 — read from cassette
F000:E525  CD15            int    15h                         ; Read program body into ES:BX
F000:E527  730C            jae    loc_E535                    ; Success — run it
F000:E529  8CC8            mov    ax, cs                      ; Error: DS = CS…
F000:E52B  8ED8            mov    ds, ax                      ; …= F000h
F000:E52D  BEA1E5          mov    si, 0E5A1h                  ; SI → «Ошибка загрузки программы» ("Program load error") (dat_E5A1)
F000:E530  E87701          call   sub_E6AA                    ; Print message
F000:E533  EB9E            jmp    loc_E4D3                    ; Wait for key and start over

loc_E535:    ; xrefs: E527
F000:E535  B85000          mov    ax, 50h                     ; DS = 0050h…
F000:E538  8ED8            mov    ds, ax                      ; …
F000:E53A  A11500          mov    ax, word [15h]              ; AX = load segment
F000:E53D  A31B00          mov    word [1Bh], ax              ; 0050:001B = segment → far entry pointer 0050:0019 = segment:entry_offset
F000:E540  FF2E1900        jmp far [19h]                      ; Run loaded program (JMP FAR [0050:0019])

dat_E544:    ; xrefs: E493
F000:E544  0A02            db     0Ah,02h                     ; Cursor position: DL=0Ah (column 10), DH=02h (row 2)
F000:E546  202087A0A3E0…   db     '  Загрузка с ленты'        ; «  Загрузка с ленты» ("  Load from tape") — tape loader screen title
F000:E558  0101            db     01h,01h                     ; Two 01h codes — move cursor two rows down (same column)
F000:E55A  82A2A5A4A8E2…   db     'Введите имя программы'     ; «Введите имя программы» ("Enter program name") — prompt
F000:E56F  00              db     00h                         ; End of string

dat_E570:    ; xrefs: E499
F000:E570  0F05DAC4C4C4…   db     0Fh,05h,0DAh,0C4h,0C4h,0C4h,0C4h,0C4h ; Position (col 15, row 5); ┌ and horizontal lines ─ (CP866 DAh, C4h) — top of frame
F000:E578  C4C4C4BF0101…   db     0C4h,0C4h,0C4h,0BFh,01h,01h,0C0h,0C4h ; ─ ─ ─ ┐ (C4h, BFh); 01h,01h — two rows down; └ (C0h) ─
F000:E580  C4C4C4C4C4C4…   db     0C4h,0C4h,0C4h,0C4h,0C4h,0C4h,0C4h,0D9h ; ─ ×7 and ┘ (D9h) — bottom of name input frame
F000:E588  00              db     00h                         ; End of string (frame terminator)

dat_E589:    ; xrefs: E4CD
F000:E589  0A0A            db     0Ah,0Ah                     ; Cursor position: DL=0Ah, DH=0Ah (row 10, column 10)
F000:E58B  8EE8A8A1AAA0…   db     'Ошибка чтения с ленты'     ; «Ошибка чтения с ленты» ("Tape read error")
F000:E5A0  00              db     00h                         ; End of string

dat_E5A1:    ; xrefs: E52D
F000:E5A1  0A0A            db     0Ah,0Ah                     ; Cursor position: column 10, row 10
F000:E5A3  8EE8A8A1AAA0…   db     'Ошибка загрузки программы' ; «Ошибка загрузки программы» ("Program load error")
F000:E5BC  00              db     00h                         ; End of string

dat_E5BD:    ; xrefs: E4F1
F000:E5BD  0A0A            db     0Ah,0Ah                     ; Cursor position: column 10, row 10
F000:E5BF  8FE0AEAFE3E9…   db     'Пропущена программа '      ; «Пропущена программа » ("Skipped program ") (followed by the name of the program found on tape)
F000:E5D3  00              db     00h                         ; End of string

dat_E5D4:    ; xrefs: E50E
F000:E5D4  0A0A            db     0Ah,0Ah                     ; Cursor position: column 10, row 10
F000:E5D6  8FE0AEA3E0A0…   db     'Программа загружается'     ; «Программа загружается» ("Program loading")
F000:E5EB  00              db     00h                         ; End of string

; ----------------------------------------------------------------------------------------------
; sub_E5EC — keyboard line input with echo (program name for the tape loader).
; Input: ES:DI — buffer, CX — max characters + 1, DX — cursor position. Enter ends input, Backspace deletes.
; Output: CF=0 — input complete, rest of buffer space-filled; CF=1 — overflow.
; ----------------------------------------------------------------------------------------------
sub_E5EC:    ; xrefs: E4AD
F000:E5EC  BB0700          mov    bx, 7                       ; BH = 0 (page), BL = 07h (attribute: gray on black)
F000:E5EF  B402            mov    ah, 2                       ; AH = 2 — set cursor position
F000:E5F1  CD10            int    10h                         ; Place cursor at start of input field

loc_E5F3:    ; xrefs: E625 E636
F000:E5F3  51              push   cx                          ; Save remaining character counter

loc_E5F4:    ; xrefs: E60E
F000:E5F4  B400            mov    ah, 0                       ; AH = 0 — read key
F000:E5F6  CD16            int    16h                         ; Wait for key (AH = scan code, AL = ASCII)
F000:E5F8  80FC1C          cmp    ah, 1Ch                     ; Scan code 1Ch = Enter?
F000:E5FB  7508            jne    loc_E605                    ; No — check other keys
F000:E5FD  B020            mov    al, 20h                     ; AL = space
F000:E5FF  F3AA            rep stosb byte es:[di], al         ; Pad rest of buffer with spaces
F000:E601  59              pop    cx                          ; Pop counter from stack
F000:E602  F8              clc                                ; CF=0 — input successful
F000:E603  EB34            jmp    loc_E639                    ; To return

loc_E605:    ; xrefs: E5FB
F000:E605  80FC0E          cmp    ah, 0Eh                     ; Scan code 0Eh = Backspace?
F000:E608  751D            jne    loc_E627                    ; No — ordinary character
F000:E60A  81FF0100        cmp    di, 1                       ; Buffer empty (DI at start)?
F000:E60E  74E4            je     loc_E5F4                    ; Yes — ignore backspace, wait for next key
F000:E610  FECA            dec    dl                          ; Cursor column one left
F000:E612  B402            mov    ah, 2                       ; AH = 2 — set cursor
F000:E614  CD10            int    10h                         ; Move cursor
F000:E616  4F              dec    di                          ; Buffer pointer back
F000:E617  B020            mov    al, 20h                     ; AL = space
F000:E619  268805          mov    byte es:[di], al            ; Erase character in buffer
F000:E61C  B409            mov    ah, 9                       ; AH = 9 — write character with attribute without moving cursor
F000:E61E  B90100          mov    cx, 1                       ; One character
F000:E621  CD10            int    10h                         ; Erase character on screen
F000:E623  59              pop    cx                          ; Restore counter
F000:E624  41              inc    cx                          ; One slot freed
F000:E625  EBCC            jmp    loc_E5F3                    ; Next key

loc_E627:    ; xrefs: E608
F000:E627  AA              stosb  byte es:[di], al            ; Store character in buffer
F000:E628  B409            mov    ah, 9                       ; AH = 9 — write character with attribute
F000:E62A  B90100          mov    cx, 1                       ; One character
F000:E62D  CD10            int    10h                         ; Display character
F000:E62F  FEC2            inc    dl                          ; Cursor column +1
F000:E631  B402            mov    ah, 2                       ; AH = 2 — set cursor
F000:E633  CD10            int    10h                         ; Move cursor
F000:E635  59              pop    cx                          ; Restore counter
F000:E636  E2BB            loop   loc_E5F3                    ; Still room — next key
F000:E638  F9              stc                                ; CF=1 — name length exceeded

loc_E639:    ; xrefs: E603
F000:E639  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; POST entry: checksum of 8 KB main ROM (DS:BX = F000:E000), before stack setup.
; ----------------------------------------------------------------------------------------------
loc_E63A:    ; xrefs: E0DD
F000:E63A  B90020          mov    cx, 2000h                   ; CX = 8 KB — size of ROM area to check

; ----------------------------------------------------------------------------------------------
; sub_E63D — checksum: sum of CX bytes at DS:BX (mod 256).
; Output: ZF=1 — sum is 0 (ROM OK); BX advanced by CX.
; ----------------------------------------------------------------------------------------------
sub_E63D:    ; xrefs: E3B7 E660
F000:E63D  32C0            xor    al, al                      ; AL = 0 — sum accumulator

loc_E63F:    ; xrefs: E642
F000:E63F  0207            add    al, byte [bx]               ; Add next byte
F000:E641  43              inc    bx                          ; Next byte
F000:E642  E2FB            loop   loc_E63F                    ; CX bytes
F000:E644  0AC0            or     al, al                      ; ZF=1 if sum is 0
F000:E646  C3              ret                                ; Return (before stack setup — via address in ROM spret_E06E)

; ----------------------------------------------------------------------------------------------
; sub_E647 — check and initialize a found expansion ROM.
; Input: DS = ROM segment (signature AA55h), BX = 0, DX = same segment.
; Checksum over length [2]×512 bytes; on success — far call DS:0003; on error — «SSSS КС ПЗУ» ("SSSS ROM checksum").
; Output: DX += ROM size in paragraphs (scan continues past it).
; ----------------------------------------------------------------------------------------------
sub_E647:    ; xrefs: E398
F000:E647  B84000          mov    ax, 40h                     ; ES = 0040h…
F000:E64A  8EC0            mov    es, ax                      ; …BIOS data area (temporary pointer at 0040:0084)
F000:E64C  2AE4            sub    ah, ah                      ; AH = 0
F000:E64E  8A4702          mov    al, byte [bx + 2]           ; AL = ROM size in 512-byte blocks (header byte 2)
F000:E651  B109            mov    cl, 9                       ; ×512…
F000:E653  D3E0            shl    ax, cl                      ; …= size in bytes
F000:E655  8BC8            mov    cx, ax                      ; CX = length for checksum
F000:E657  51              push   cx                          ; Save length
F000:E658  B90400          mov    cx, 4                       ; /16…
F000:E65B  D3E8            shr    ax, cl                      ; …= size in paragraphs
F000:E65D  03D0            add    dx, ax                      ; DX = segment right after this ROM
F000:E65F  59              pop    cx                          ; Restore length
F000:E660  E8DAFF          call   sub_E63D                    ; ROM checksum
F000:E663  7406            je     loc_E66B                    ; Sum 0 — call ROM init
F000:E665  E812FE          call   sub_E47A                    ; Error: «SSSS КС ПЗУ» ("SSSS ROM CS")
F000:E668  EB14            jmp    loc_E67E                    ; To return
F000:E66A  90              db     90h                         ; Unused NOP byte (filler between instructions)

; ----------------------------------------------------------------------------------------------
; Tail of sub_E647 (expansion ROM scan): module checksum OK → call its init.
; The far call goes through a temporary pointer at 0040:0084/0086 (ES=0040h) to DS:0003 —
; the standard ROM module entry point (after the 55AA signature and length byte). IBM uses 0040:0067 for this.
; ----------------------------------------------------------------------------------------------
loc_E66B:    ; xrefs: E663
F000:E66B  52              push   dx                          ; save DX — segment where the scan for the next module resumes
F000:E66C  26C70684000300  mov    word es:[84h], 3            ; 0040:0084 ← offset 0003 = option ROM init entry point
F000:E673  268C1E8600      mov    word es:[86h], ds           ; 0040:0086 ← DS = segment of found module (seg:0003 pointer ready)
F000:E678  26FF1E8400      call far es:[84h]                  ; far call to option ROM init (module returns with RETF)
F000:E67D  5A              pop    dx                          ; restore DX — segment to continue scanning

loc_E67E:    ; xrefs: E668
F000:E67E  C3              ret                                ; return to option ROM scan loop (from both branches: OK and checksum error)

; ----------------------------------------------------------------------------------------------
; sub_E67F — print address DS:DI as «SSSS:OOOO» (hex) via INT 10h/0Eh.
; Used by the RAM test (E36A) to print the failing location. Clobbers AX, CL.
; ----------------------------------------------------------------------------------------------
sub_E67F:    ; xrefs: E36A
F000:E67F  8CD8            mov    ax, ds                      ; AX = DS — segment of failing memory block
F000:E681  E80700          call   sub_E68B                    ; print segment as 4 hex digits
F000:E684  B03A            mov    al, 3Ah                     ; AL = ':' — segment/offset separator
F000:E686  E81A00          call   sub_E6A3                    ; print ':' via teletype
F000:E689  8BC7            mov    ax, di                      ; AX = DI — failing byte offset; fall through to word print

; ----------------------------------------------------------------------------------------------
; sub_E68B — print AX as 4 hex digits (high byte first). Input: AX. Clobbers CL.
; ----------------------------------------------------------------------------------------------
sub_E68B:    ; xrefs: E47E E681
F000:E68B  50              push   ax                          ; save original word
F000:E68C  86E0            xchg   al, ah                      ; handle high byte first (AH → AL)
F000:E68E  E80100          call   sub_E692                    ; print high byte as two digits
F000:E691  58              pop    ax                          ; AX = original word; AL = low byte → fall through to byte print

; ----------------------------------------------------------------------------------------------
; sub_E692 — print AL as two hex digits. Input: AL. Clobbers CL, AH.
; ----------------------------------------------------------------------------------------------
sub_E692:    ; xrefs: E37D E68E
F000:E692  50              push   ax                          ; save byte
F000:E693  B104            mov    cl, 4                       ; CL = 4 — nibble shift
F000:E695  D2E8            shr    al, cl                      ; AL = high nibble
F000:E697  E80300          call   sub_E69D                    ; print high digit
F000:E69A  58              pop    ax                          ; restore byte
F000:E69B  240F            and    al, 0Fh                     ; AL = low nibble → fall through to digit print

; ----------------------------------------------------------------------------------------------
; sub_E69D — print one hex digit (AL = 0..0Fh) using the classic ADD 90h/DAA/ADC 40h/DAA trick.
; ----------------------------------------------------------------------------------------------
sub_E69D:    ; xrefs: E697
F000:E69D  0490            add    al, 90h                     ; DAA trick: 0..9 → 90..99, A..F → 00..05 with carry
F000:E69F  27              daa                                ; decimal adjust (CF=1 for A..F)
F000:E6A0  1440            adc    al, 40h                     ; +40h+CF: 0..9 → '0'..'9' after DAA, A..F → 'A'..'F'
F000:E6A2  27              daa                                ; AL = ASCII hex digit → fall through to character output

; ----------------------------------------------------------------------------------------------
; sub_E6A3 — teletype output of character AL (INT 10h, AH=0Eh, page 0).
; ----------------------------------------------------------------------------------------------
sub_E6A3:    ; xrefs: E346 E35E E367 E36F E686
F000:E6A3  B40E            mov    ah, 0Eh                     ; AH = 0Eh — INT 10h "teletype" function
F000:E6A5  B700            mov    bh, 0                       ; BH = 0 — video page 0
F000:E6A7  CD10            int    10h                         ; print character AL and advance cursor
F000:E6A9  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_E6AA — print a ROM message string with positioning.
; Format at CS:SI: word DX (DL = column, DH = row) — cursor position, then CP866 text;
; byte 01h — move to next screen row at the same column, 00h — end of string.
; ----------------------------------------------------------------------------------------------
sub_E6AA:    ; xrefs: E496 E49C E4D0 E4F4 E511 E530
F000:E6AA  2E8B14          mov    dx, word cs:[si]            ; DX = output start position (DL = column, DH = row) from string header
F000:E6AD  46              inc    si                          ; SI → second position byte (another inc below skips it)

loc_E6AE:    ; xrefs: E6C5
F000:E6AE  B402            mov    ah, 2                       ; AH = 2 — INT 10h "set cursor position" function
F000:E6B0  46              inc    si                          ; SI → first text character (or character after code 01h)
F000:E6B1  B700            mov    bh, 0                       ; BH = 0 — video page 0 (BH stays 0 for teletype below too)
F000:E6B3  CD10            int    10h                         ; set cursor to position DX
F000:E6B5  EB05            jmp    sub_E6BC                    ; go to character output loop

loc_E6B7:    ; xrefs: E6C9
F000:E6B7  B40E            mov    ah, 0Eh                     ; AH = 0Eh — INT 10h teletype (BH=0 left by caller/above)
F000:E6B9  CD10            int    10h                         ; print next character
F000:E6BB  46              inc    si                          ; to next string character

; ----------------------------------------------------------------------------------------------
; sub_E6BC — teletype output of an ASCIIZ string at CS:SI from the current cursor position.
; Code 01h — move to next screen row (DH+1, column DL), 00h — end. Expects BH=0.
; ----------------------------------------------------------------------------------------------
sub_E6BC:    ; xrefs: E227 E24D E261 E29D E34E E383 E484 E504 E6B5
F000:E6BC  2E8A04          mov    al, byte cs:[si]            ; AL = next string byte from ROM
F000:E6BF  3C01            cmp    al, 1                       ; code 01h — control "new row, same column"?
F000:E6C1  7504            jne    loc_E6C7                    ; no — check for end/ordinary character
F000:E6C3  FEC6            inc    dh                          ; next screen row (column DL kept)
F000:E6C5  EBE7            jmp    loc_E6AE                    ; reposition cursor and continue output

loc_E6C7:    ; xrefs: E6C1
F000:E6C7  0AC0            or     al, al                      ; byte 0 — end of string?
F000:E6C9  75EC            jne    loc_E6B7                    ; not 0 — print character
F000:E6CB  C3              ret                                ; string printed — return
F000:E6CC  00              db     20 dup (00h)                ; filler 00h (padding up to the standard INT 19h entry E6F2)

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
; Input: AH = function (0 init, 1 send, 2 receive, 3 status), AL = parameters/character, DX = port number.
; Base address from 0040:0000+2*DX. In dk 8250 ports are not emulated (IN returns FFh) and POST never finds COM1,
; so the address = 0 and INT 14h effectively returns at once. Output: AH = LSR, AL = MSR / character; AH bit 7 = timeout.
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
F000:E770  EE              out    dx, al                      ; LCR ← 80h (DLAB); in dk the 8250 port is not emulated — the OUT is lost
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
F000:E7C1  EE              out    dx, al                      ; send character (in dk an OUT to an 8250 port is ignored by the NMI handler)
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
F000:E7F7  EC              in     al, dx                      ; read 8250 status register (not emulated in dk — always FFh)
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
sub_E809:    ; xrefs: E851 EC05
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
dat_E86A:    ; xrefs: EAFC
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
dat_E8A4:    ; xrefs: EB06
F000:E8A4  5E5F60616263…   db     '^_`abcdefg'                ; Ctrl-F1..F10 → extended codes 5Eh..67h
F000:E8AE  FFFF77FF84FF…   db     0FFh,0FFh,77h,0FFh,84h,0FFh,73h,0FFh ; NumLock/Scroll→none, Home→77h, ↑→none, PgUp→84h, '-'→none, ←→73h, '5'→none
F000:E8B6  74FF75FF76FFFF  db     74h,0FFh,75h,0FFh,76h,0FFh,0FFh ; →→74h, '+'→none, End→75h, ↓→none, PgDn→76h, Ins→none, Del→none

dat_E8BD:    ; xrefs: EB2D
F000:E8BD  545556575859…   db     'TUVWXYZ[\]'                ; Shift-F1..F10 → extended codes 54h..5Dh

dat_E8C7:    ; xrefs: EAA8
F000:E8C7  68696A6B6C6D…   db     'hijklmnopq'                ; Alt-F1..F10 → extended codes 68h..71h

; ----------------------------------------------------------------------------------------------
; Main ASCII table (unshifted, Latin) for scan codes 01h–3Ah (index = scan−1); FFh = no character.
; ----------------------------------------------------------------------------------------------
dat_E8D1:    ; xrefs: EB80
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
F000:E92E  E9F102          jmp    loc_EC22                    ; yes — beep (as on buffer overflow)

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
F000:E94D  8036180004      xor    byte [18h], 4               ; toggle bit 2 of 0040:0018 — RUS/LAT mode (selects tables F791/F805/F7CB)

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
F000:E9AC  E9E201          jmp    loc_EB91                    ; to buffer

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
F000:E9CB  E9C301          jmp    loc_EB91                    ; to buffer

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
F000:E9EA  E9AD01          jmp    loc_EB9A                    ; put entered code (AH=0) into buffer

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
loc_EA09:    ; xrefs: E93A E97B E9BA E9C6 E9DB E9E8 E9F3 E9F7 EA02 EA7A EAA1 EBD3 EC14
F000:EA09  FA              cli                                ; disable interrupts until IRET

loc_EA0A:    ; xrefs: EAEF EB26 EC40
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
F000:EA5D  E93101          jmp    loc_EB91                    ; to buffer

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
F000:EA8A  E90401          jmp    loc_EB91                    ; to buffer

loc_EA8D:    ; xrefs: EA86
F000:EA8D  3C02            cmp    al, 2                       ; scan < 02h (Esc)?
F000:EA8F  720C            jb     loc_EA9D                    ; yes — continue
F000:EA91  3C0E            cmp    al, 0Eh                     ; scan ≥ 0Eh (past '=')?
F000:EA93  7308            jae    loc_EA9D                    ; yes — continue
F000:EA95  80C476          add    ah, 76h                     ; Alt+1..= : AH = scan+76h (78h..83h) — standard extended codes
F000:EA98  B000            mov    al, 0                       ; AL = 0
F000:EA9A  E9F400          jmp    loc_EB91                    ; to buffer

loc_EA9D:    ; xrefs: EA8F EA93
F000:EA9D  3C3B            cmp    al, 3Bh                     ; scan < 3Bh (not a function key)?
F000:EA9F  7303            jae    loc_EAA4                    ; no — check F-keys

loc_EAA1:    ; xrefs: EAA6
F000:EAA1  E965FF          jmp    loc_EA09                    ; other Alt combinations are ignored

loc_EAA4:    ; xrefs: EA9F
F000:EAA4  3C47            cmp    al, 47h                     ; scan ≥ 47h (keypad)?
F000:EAA6  73F9            jae    loc_EAA1                    ; yes — ignore
F000:EAA8  BBC7E8          mov    bx, 0E8C7h                  ; BX = Alt-F1..F10 table (E8C7)
F000:EAAB  E96901          jmp    loc_EC17                    ; extended code from table

; ----------------------------------------------------------------------------------------------
; Translation with Ctrl held (no Alt): Ctrl-Break, Ctrl-NumLock (pause), Ctrl-PrtSc, control codes.
; ----------------------------------------------------------------------------------------------
loc_EAAE:    ; xrefs: EA1A
F000:EAAE  F606170004      test   byte [17h], 4               ; Ctrl pressed (bit 2 of 0040:0017)?
F000:EAB3  7457            je     loc_EB0C                    ; no — Shift/unmodified branch
F000:EAB5  3C46            cmp    al, 46h                     ; ScrollLock (46h) — Ctrl-Break?
F000:EAB7  7518            jne    loc_EAD1                    ; no
F000:EAB9  8B1E8000        mov    bx, word [80h]              ; BX = buffer start (0040:0080)
F000:EABD  891E1A00        mov    word [1Ah], bx              ; flush buffer: head = start
F000:EAC1  891E1C00        mov    word [1Ch], bx              ; tail = start
F000:EAC5  C606710080      mov    byte [71h], 80h             ; 0040:0071 bit 7 — Ctrl-Break pressed flag
F000:EACA  CD1B            int    1Bh                         ; call user Ctrl-Break handler INT 1Bh
F000:EACC  2BC0            sub    ax, ax                      ; AX = 0000 — empty code is put into the buffer (as in IBM)
F000:EACE  E9C000          jmp    loc_EB91                    ; to buffer

loc_EAD1:    ; xrefs: EAB7
F000:EAD1  3C45            cmp    al, 45h                     ; NumLock (45h) — pause?
F000:EAD3  751D            jne    loc_EAF2                    ; no
F000:EAD5  800E180008      or     byte [18h], 8               ; enable pause: 0040:0018 bit 3
F000:EADA  803E490007      cmp    byte [49h], 7               ; video mode (0040:0049) = 7 (MDA)?
F000:EADF  7407            je     loc_EAE8                    ; yes — skip
F000:EAE1  BAD803          mov    dx, 3D8h                    ; DX = 3D8h — CGA mode register
F000:EAE4  A06500          mov    al, byte [65h]              ; AL = current mode register value (0040:0065)
F000:EAE7  EE              out    dx, al                      ; restore CGA mode (enable video) — emulated via NMI

loc_EAE8:    ; xrefs: EADF EAED
F000:EAE8  F606180008      test   byte [18h], 8               ; wait for next keypress to end pause (INT 09h clears bit 3)
F000:EAED  75F9            jne    loc_EAE8                    ; spin while paused
F000:EAEF  E918FF          jmp    loc_EA0A                    ; exit without producing a code

loc_EAF2:    ; xrefs: EAD3
F000:EAF2  3C37            cmp    al, 37h                     ; PrtSc/'*' (37h)?
F000:EAF4  7506            jne    loc_EAFC                    ; no
F000:EAF6  B80072          mov    ax, 7200h                   ; Ctrl-PrtSc: AX = 7200h
F000:EAF9  E99500          jmp    loc_EB91                    ; to buffer

loc_EAFC:    ; xrefs: EAF4
F000:EAFC  BB6AE8          mov    bx, 0E86Ah                  ; BX = Ctrl code table E86A
F000:EAFF  3C3B            cmp    al, 3Bh                     ; scan < 3Bh?
F000:EB01  7303            jae    loc_EB06                    ; no — function keys/keypad
F000:EB03  E98700          jmp    loc_EB8D                    ; ASCII from table E86A (index scan−1)

loc_EB06:    ; xrefs: EB01
F000:EB06  BBA4E8          mov    bx, 0E8A4h                  ; BX = Ctrl F-key/keypad table E8A4
F000:EB09  E90B01          jmp    loc_EC17                    ; extended code from table

; ----------------------------------------------------------------------------------------------
; Translation without Alt/Ctrl: Shift or unmodified. Honors RUS/LAT mode (bit 2 of 0040:0018).
; ----------------------------------------------------------------------------------------------
loc_EB0C:    ; xrefs: EAB3
F000:EB0C  3C47            cmp    al, 47h                     ; keypad (≥ 47h)?
F000:EB0E  7332            jae    loc_EB42                    ; yes — separate handling
F000:EB10  F606170003      test   byte [17h], 3               ; Shift pressed (bits 0,1 of 0040:0017)?
F000:EB15  7461            je     loc_EB78                    ; no — lowercase
F000:EB17  3C0F            cmp    al, 0Fh                     ; Tab (0Fh)?
F000:EB19  7505            jne    loc_EB20                    ; no
F000:EB1B  B8000F          mov    ax, 0F00h                   ; Shift-Tab: AX = 0F00h (BackTab)
F000:EB1E  EB71            jmp    loc_EB91                    ; to buffer

loc_EB20:    ; xrefs: EB19
F000:EB20  3C37            cmp    al, 37h                     ; PrtSc (37h)?
F000:EB22  7505            jne    loc_EB29                    ; no
F000:EB24  CD05            int    5                           ; Shift-PrtSc: print screen INT 05h
F000:EB26  E9E1FE          jmp    loc_EA0A                    ; exit

loc_EB29:    ; xrefs: EB22
F000:EB29  3C3B            cmp    al, 3Bh                     ; F-keys (≥ 3Bh)?
F000:EB2B  7206            jb     loc_EB33                    ; no — character keys
F000:EB2D  BBBDE8          mov    bx, 0E8BDh                  ; BX = Shift-F1..F10 table (E8BD)
F000:EB30  E9E400          jmp    loc_EC17                    ; extended code from table

loc_EB33:    ; xrefs: EB2B
F000:EB33  BB91F7          mov    bx, 0F791h                  ; BX = uppercase table, Latin (F791)
F000:EB36  F606180004      test   byte [18h], 4               ; RUS mode (bit 2 of 0040:0018)?
F000:EB3B  7450            je     loc_EB8D                    ; no — Latin
F000:EB3D  BB05F8          mov    bx, 0F805h                  ; BX = uppercase table, Cyrillic CP866 (F805)
F000:EB40  EB4B            jmp    loc_EB8D                    ; ASCII from table

; ----------------------------------------------------------------------------------------------
; INT 09 (continued): keypad keys (scan codes 47h–53h), no Alt/Ctrl.
; NumLock XOR Shift → digits/signs from keypad_table (FF23); otherwise cursor codes from table FF30 (AL=0, AH=scan).
; Gray "-" (4Ah) and "+" (4Eh) always produce characters. Input: AL=AH=make scan code.
; ----------------------------------------------------------------------------------------------
loc_EB42:    ; xrefs: EB0E
F000:EB42  F606170020      test   byte [17h], 20h             ; 0040:0017 bit 5 = NumLock on?
F000:EB47  7521            jne    loc_EB6A                    ; NumLock on → check Shift (Shift inverts NumLock)
F000:EB49  F606170003      test   byte [17h], 3               ; NumLock off: left/right Shift pressed (bits 0–1 of 0040:0017)?
F000:EB4E  7521            jne    loc_EB71                    ; Shift with NumLock off → numeric mode

; ----------------------------------------------------------------------------------------------
; Cursor control mode (NumLock off, or on together with Shift).
; ----------------------------------------------------------------------------------------------
loc_EB50:    ; xrefs: EB6F
F000:EB50  3C4A            cmp    al, 4Ah                     ; scan 4Ah — gray "-" on keypad?
F000:EB52  740C            je     loc_EB60                    ; yes → emit "-"
F000:EB54  3C4E            cmp    al, 4Eh                     ; scan 4Eh — gray "+"?
F000:EB56  740D            je     loc_EB65                    ; yes → emit "+"
F000:EB58  2C47            sub    al, 47h                     ; index = scan − 47h (Home=0 … Del=0Ch)
F000:EB5A  BB30FF          mov    bx, 0FF30h                  ; BX → cursor scan code table FF30 (FFh = key produces no code)
F000:EB5D  E9B900          jmp    loc_EC19                    ; xlat → AH = extended code, AL = 0, then store to buffer

loc_EB60:    ; xrefs: EB52
F000:EB60  B82D4A          mov    ax, 4A2Dh                   ; AX = 4A2Dh: scan 4Ah, ASCII "-"
F000:EB63  EB2C            jmp    loc_EB91                    ; to common check and buffer store

loc_EB65:    ; xrefs: EB56
F000:EB65  B82B4E          mov    ax, 4E2Bh                   ; AX = 4E2Bh: scan 4Eh, ASCII "+"
F000:EB68  EB27            jmp    loc_EB91                    ; to common check and buffer store

loc_EB6A:    ; xrefs: EB47
F000:EB6A  F606170003      test   byte [17h], 3               ; NumLock on: Shift pressed?
F000:EB6F  75DF            jne    loc_EB50                    ; NumLock+Shift → cursor mode

; ----------------------------------------------------------------------------------------------
; Numeric mode: character taken from keypad_table F000:FF23 ("789-456+1230.").
; ----------------------------------------------------------------------------------------------
loc_EB71:    ; xrefs: EB4E
F000:EB71  2C46            sub    al, 46h                     ; AL = scan − 46h (1..0Dh); after dec — index from 47h
F000:EB73  BB23FF          mov    bx, 0FF23h                  ; BX → keypad_table (ASCII of keypad digits and signs)
F000:EB76  EB15            jmp    loc_EB8D                    ; to common xlat (dec al / xlat) and buffer store

; ----------------------------------------------------------------------------------------------
; Regular key (scan < 47h) without Shift/Ctrl/Alt: F-keys or character from lowercase table.
; Table selected by 0040:0018 bit 2 — non-standard RUS/LAT mode flag (toggled by right Ctrl, E0 9D).
; ----------------------------------------------------------------------------------------------
loc_EB78:    ; xrefs: EB15
F000:EB78  3C3B            cmp    al, 3Bh                     ; scan ≥ 3Bh (F1–F10 etc.)?
F000:EB7A  7204            jb     loc_EB80                    ; no → regular character
F000:EB7C  B000            mov    al, 0                       ; F-key: AL = 0, AH = scan code (extended code)
F000:EB7E  EB11            jmp    loc_EB91                    ; to buffer store

loc_EB80:    ; xrefs: EB7A
F000:EB80  BBD1E8          mov    bx, 0E8D1h                  ; BX → lowercase table, Latin (E8D1: Esc,1..=,BS,Tab,q..)
F000:EB83  F606180004      test   byte [18h], 4               ; 0040:0018 bit 2 = RUS mode (non-standard use; SysReq in IBM)?
F000:EB88  7403            je     loc_EB8D                    ; LAT → keep Latin table
F000:EB8A  BBCBF7          mov    bx, 0F7CBh                  ; RUS → Cyrillic lowercase table F7CB (йцукен…, CP866)

; ----------------------------------------------------------------------------------------------
; Common translation: AL = scan code (1-based index), BX = table in CS → AL = ASCII; AH = scan.
; ----------------------------------------------------------------------------------------------
loc_EB8D:    ; xrefs: EB03 EB3B EB40 EB76 EB88
F000:EB8D  FEC8            dec    al                          ; scan codes start at 1 (Esc) → make index zero-based
F000:EB8F  2ED7            xlatb                              ; AL = cs:[BX+AL] — ASCII code from layout table

; ----------------------------------------------------------------------------------------------
; Common point: AX = (scan, ASCII) ready. FFh in AL or AH = "no code" → ignore.
; Next: CapsLock handling (incl. Cyrillic CP866) and store into ring buffer 0040:001E.
; ----------------------------------------------------------------------------------------------
loc_EB91:    ; xrefs: E9AC E9CB EA5D EA8A EA9A EACE EAF9 EB1E EB63 EB68 EB7E EC1F
F000:EB91  3CFF            cmp    al, 0FFh                    ; AL = FFh — key produces no character in this shift state?
F000:EB93  743E            je     loc_EBD3                    ; yes → exit handler without storing
F000:EB95  80FCFF          cmp    ah, 0FFh                    ; AH = FFh — no extended code (e.g. "5" in cursor mode)?
F000:EB98  7439            je     loc_EBD3                    ; yes → exit

; ----------------------------------------------------------------------------------------------
; CapsLock handling: when CapsLock is on, letter case is flipped (Shift inverts the effect).
; Latin: a–z ↔ A–Z. Cyrillic CP866: а–п(A0–AF)↔А–П(80–8F), р–я(E0–EF)↔Р–Я(90–9F), ё(F1)↔Ё(F0).
; The code entered via Alt+digits (from E9EA) also arrives here.
; ----------------------------------------------------------------------------------------------
loc_EB9A:    ; xrefs: E9EA
F000:EB9A  F606170040      test   byte [17h], 40h             ; 0040:0017 bit 6 = CapsLock on?
F000:EB9F  745E            je     loc_EBFF                    ; no → store character as is
F000:EBA1  F606170003      test   byte [17h], 3               ; CapsLock: Shift pressed?
F000:EBA6  742E            je     loc_EBD6                    ; no Shift → convert lowercase to uppercase (EBD6)
F000:EBA8  F606180004      test   byte [18h], 4               ; Caps+Shift → convert uppercase to lowercase; RUS mode (0040:0018 bit 2)?
F000:EBAD  7418            je     loc_EBC7                    ; LAT → A–Z only
F000:EBAF  3CF0            cmp    al, 0F0h                    ; F0h = "Ё" (CP866)?
F000:EBB1  7504            jne    loc_EBB7                    ; no → check А–Я range
F000:EBB3  FEC0            inc    al                          ; Ё → ё (F1h)
F000:EBB5  EB48            jmp    loc_EBFF                    ; to buffer store

loc_EBB7:    ; xrefs: EBB1
F000:EBB7  3C80            cmp    al, 80h                     ; below 80h — not Cyrillic
F000:EBB9  7244            jb     loc_EBFF                    ; leave unchanged
F000:EBBB  3C9F            cmp    al, 9Fh                     ; above 9Fh ("Я") — not uppercase Cyrillic
F000:EBBD  7740            ja     loc_EBFF                    ; leave unchanged
F000:EBBF  3C90            cmp    al, 90h                     ; А–П (80–8Fh) or Р–Я (90–9Fh)?
F000:EBC1  720C            jb     loc_EBCF                    ; А–П → +20h (а–п, A0–AFh)
F000:EBC3  0450            add    al, 50h                     ; Р–Я → +50h (р–я, E0–EFh)
F000:EBC5  EB38            jmp    loc_EBFF                    ; to buffer store

loc_EBC7:    ; xrefs: EBAD
F000:EBC7  3C41            cmp    al, 41h                     ; Latin: below "A"?
F000:EBC9  7234            jb     loc_EBFF                    ; not a letter → unchanged
F000:EBCB  3C5A            cmp    al, 5Ah                     ; above "Z"?
F000:EBCD  7730            ja     loc_EBFF                    ; not a letter → unchanged

loc_EBCF:    ; xrefs: EBC1
F000:EBCF  0420            add    al, 20h                     ; uppercase → lowercase (+20h)
F000:EBD1  EB2C            jmp    loc_EBFF                    ; to buffer store

loc_EBD3:    ; xrefs: EB93 EB98
F000:EBD3  E933FE          jmp    loc_EA09                    ; jump to common INT 09 exit (cli, restore registers, iret)

loc_EBD6:    ; xrefs: EBA6
F000:EBD6  F606180004      test   byte [18h], 4               ; CapsLock without Shift → to uppercase; RUS mode?
F000:EBDB  7418            je     loc_EBF5                    ; LAT → a–z only
F000:EBDD  3CF1            cmp    al, 0F1h                    ; F1h = "ё" (CP866)?
F000:EBDF  7504            jne    loc_EBE5                    ; no → check lowercase Cyrillic ranges
F000:EBE1  FEC8            dec    al                          ; ё → Ё (F0h)
F000:EBE3  EB1A            jmp    loc_EBFF                    ; to buffer store

loc_EBE5:    ; xrefs: EBDF
F000:EBE5  3CA0            cmp    al, 0A0h                    ; below A0h ("а") — not lowercase Cyrillic
F000:EBE7  7216            jb     loc_EBFF                    ; leave unchanged
F000:EBE9  3CEF            cmp    al, 0EFh                    ; above EFh ("я")?
F000:EBEB  7712            ja     loc_EBFF                    ; leave unchanged
F000:EBED  3CE0            cmp    al, 0E0h                    ; р–я (E0–EFh)? else A0–DFh (box-drawing B0–DF also lands here — a flaw)
F000:EBEF  720C            jb     loc_EBFD                    ; а–п (and B0–DFh) → −20h
F000:EBF1  2C50            sub    al, 50h                     ; р–я → −50h (Р–Я, 90–9Fh)
F000:EBF3  EB0A            jmp    loc_EBFF                    ; to buffer store

loc_EBF5:    ; xrefs: EBDB
F000:EBF5  3C61            cmp    al, 61h                     ; Latin: below "a"?
F000:EBF7  7206            jb     loc_EBFF                    ; not a letter → unchanged
F000:EBF9  3C7A            cmp    al, 7Ah                     ; above "z"?
F000:EBFB  7702            ja     loc_EBFF                    ; not a letter → unchanged

loc_EBFD:    ; xrefs: EBEF
F000:EBFD  2C20            sub    al, 20h                     ; lowercase → uppercase (−20h)

; ----------------------------------------------------------------------------------------------
; Store AX (AH=scan, AL=ASCII) into keyboard ring buffer.
; 0040:001C — tail, 0040:001A — head, bounds 0040:0080/0082. Overflow → beep.
; ----------------------------------------------------------------------------------------------
loc_EBFF:    ; xrefs: EB9F EBB5 EBB9 EBBD EBC5 EBC9 EBCD EBD1 EBE3 EBE7 EBEB EBF3 EBF7 EBFB
F000:EBFF  8B1E1C00        mov    bx, word [1Ch]              ; BX = buffer tail (0040:001C) — slot for the new word
F000:EC03  8BF3            mov    si, bx                      ; SI = store address
F000:EC05  E801FC          call   sub_E809                    ; sub_E809: BX += 2 with wrap past buffer end (0040:0082 → 0040:0080)
F000:EC08  3B1E1A00        cmp    bx, word [1Ah]              ; new tail caught up with head (0040:001A)?
F000:EC0C  7414            je     loc_EC22                    ; buffer full → beep (EC22)
F000:EC0E  8904            mov    word [si], ax               ; store key code in buffer
F000:EC10  891E1C00        mov    word [1Ch], bx              ; update tail 0040:001C
F000:EC14  E9F2FD          jmp    loc_EA09                    ; exit INT 09

; ----------------------------------------------------------------------------------------------
; Extended code from table: AL = scan − 3Bh (F1=0) → AH = code from table BX, AL = 0.
; Used for F-keys with Shift/Ctrl/Alt (tables E8BD, E8A4, E8C7) and cursor keys (FF30).
; ----------------------------------------------------------------------------------------------
loc_EC17:    ; xrefs: EAAB EB09 EB30
F000:EC17  2C3B            sub    al, 3Bh                     ; index relative to F1 (scan 3Bh)

loc_EC19:    ; xrefs: EB5D
F000:EC19  2ED7            xlatb                              ; AL = cs:[BX+AL] — extended scan code
F000:EC1B  8AE0            mov    ah, al                      ; AH = extended code
F000:EC1D  B000            mov    al, 0                       ; AL = 0 — extended key marker for INT 16h
F000:EC1F  E96FFF          jmp    loc_EB91                    ; to common FFh check and buffer store

; ----------------------------------------------------------------------------------------------
; Beep (buffer full or scan code FFh — keyboard overrun).
; 128 square-wave periods via bit 1 of port 61h (PPI 8255 port B, "speaker data"; emulated via NMI).
; Then restore 61h and exit INT 09 (without cli).
; ----------------------------------------------------------------------------------------------
loc_EC22:    ; xrefs: E92E EC0C
F000:EC22  BB8000          mov    bx, 80h                     ; BX = 128 tone periods
F000:EC25  E461            in     al, 61h                     ; read 8255 port B (61h) — emulated by the NMI handler
F000:EC27  50              push   ax                          ; save original state of port 61h

loc_EC28:    ; xrefs: EC3B
F000:EC28  24FC            and    al, 0FCh                    ; bit 0 (timer GATE2 input) and bit 1 (speaker) = 0
F000:EC2A  E661            out    61h, al                     ; speaker off ("0" half-period)
F000:EC2C  B94800          mov    cx, 48h                     ; half-period delay — 72 iterations

loc_EC2F:    ; xrefs: EC2F
F000:EC2F  E2FE            loop   loc_EC2F                    ; empty delay loop
F000:EC31  0C02            or     al, 2                       ; bit 1 = 1 — speaker on
F000:EC33  E661            out    61h, al                     ; "1" half-period
F000:EC35  B94800          mov    cx, 48h                     ; half-period delay

loc_EC38:    ; xrefs: EC38
F000:EC38  E2FE            loop   loc_EC38                    ; empty delay loop
F000:EC3A  4B              dec    bx                          ; next period
F000:EC3B  75EB            jne    loc_EC28                    ; repeat 128 times
F000:EC3D  58              pop    ax                          ; original port 61h value
F000:EC3E  E661            out    61h, al                     ; restore 8255 port B state
F000:EC40  E9C7FD          jmp    loc_EA0A                    ; exit INT 09 (pop es…ax, iret)
F000:EC43  00              db     22 dup (00h)                ; zero padding up to standard INT 13h entry point (F000:EC59)

; ----------------------------------------------------------------------------------------------
; INT 13h — floppy disk service (standard IBM entry point F000:EC59).
; Functions: 0 reset, 1 status, 2 read, 3 write, 4 verify, 5 format, 8 drive parameters.
; Input: AH=function, AL=sector count, CH=cylinder, CL=sector, DH=head, DL=drive (0–1), ES:BX=buffer.
; Output: AH=status (0040:0041), CF=1 on error, AL=sectors processed.
; 765 controller (ports 3F2/3F4/3F5) and 8237 DMA channel 2 (ports 04/05/0A/0B/0C/81) — emulated via NMI.
; Frame: [bp]=DX,[bp+2]=BP,[bp+4]=DI,[bp+6]=SI,[bp+8]=DS,[bp+0Ah]=CX,[bp+0Ch]=BX.
; ----------------------------------------------------------------------------------------------
INT13_DISKETTE:
F000:EC59  FB              sti                                ; enable interrupts (floppy IRQ needed → INT 0Eh via common handler F400:000D)
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
; Functions 03h/02h/04h/05h — set up DMA and select the 765 command code.
; sub_F75C programs 8237 channel 2 (mode in AL, address ES:BX, length DH sectors); CF=1 — 64K boundary crossed.
; ----------------------------------------------------------------------------------------------
loc_ED37:    ; xrefs: ECD3
F000:ED37  800E3F0080      or     byte [3Fh], 80h             ; write: 0040:003F bit 7 = write operation
F000:ED3C  B04A            mov    al, 4Ah                     ; DMA mode 4Ah: channel 2, memory read → device
F000:ED3E  E81B0A          call   sub_F75C                    ; set up 8237 DMA (ports 0B/0C/04/05/81/0A)
F000:ED41  B445            mov    ah, 45h                     ; 765 code: 45h — WRITE DATA (MFM)
F000:ED43  EB33            jmp    loc_ED78                    ; to common executor

loc_ED45:    ; xrefs: ECCF
F000:ED45  B046            mov    al, 46h                     ; read: DMA mode 46h — channel 2, device → memory

loc_ED47:    ; xrefs: ED50
F000:ED47  E8120A          call   sub_F75C                    ; set up 8237 DMA
F000:ED4A  B4E6            mov    ah, 0E6h                    ; 765 code: E6h — READ DATA (MT, MFM, SK)
F000:ED4C  EB2A            jmp    loc_ED78                    ; to common executor

loc_ED4E:    ; xrefs: ECD7
F000:ED4E  B042            mov    al, 42h                     ; verify: DMA mode 42h — channel 2, verify (no transfer)
F000:ED50  EBF5            jmp    loc_ED47                    ; then same as read (command E6h)

loc_ED52:    ; xrefs: ECDB
F000:ED52  800E3F0080      or     byte [3Fh], 80h             ; format: 0040:003F bit 7 = disk write
F000:ED57  B04A            mov    al, 4Ah                     ; DMA mode 4Ah: from memory (C,H,R,N field table) to controller
F000:ED59  E8000A          call   sub_F75C                    ; set up 8237 DMA
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
sub_EE6E:    ; xrefs: EC6C ED2D ED33 ED63 ED69 ED6F EDB8 EE04 EE0A EE10 EE16 EEFE EFB7 F788
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
; sub_EEAA — seek floppy drive DL head to cylinder CH.
; On first access (drive bit in 0040:003E = 0) — RECALIBRATE twice (probably to guarantee
; reaching track 0 on an 80-track drive: the 765 issues at most 77 steps). Then SEEK.
; For disks without the "80 tracks" flag (bits 4–5 of 0040:003E) the cylinder is doubled (double-step).
; Output: CF=1 on error. Also called from POST (E3EC/E3F3).
; ----------------------------------------------------------------------------------------------
sub_EEAA:    ; xrefs: E3EC E3F3 EDC9
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
; INT 0Eh — floppy drive interrupt (standard entry F000:EF57).
; Called from common handler F400:000D on a bit in F000:0200. Sets flag 0040:003E bit 7.
; Unlike IBM, no EOI is sent to port 20h — probably the common handler acknowledges it.
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
; diskette_params — diskette parameter table (INT 1Eh vector points here), 11 bytes as in IBM.
; In dk the first byte is CFh — as in IBM XT; in my changed to EFh (faster head step).
; ----------------------------------------------------------------------------------------------
diskette_params:    ; xrefs: E6FC
F000:EFC7  CF022502082A…   db     0CFh,02h,25h,02h,08h,2Ah,0FFh,50h ; DPT: CFh=SRT C/HUT F (as IBM XT); 02h=HLT 1, DMA mode; 25h=motor off; 02h=512 B; 08h=EOT; 2Ah=GAP; FFh=DTL; 50h=format GAP
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
F000:F047  BDF1            dw     int10_01_set_cursor_type    ; AH=01h — set cursor shape
F000:F049  DEF1            dw     int10_02_set_cursor_pos     ; AH=02h — set cursor position
F000:F04B  18F2            dw     int10_03_read_cursor_pos    ; AH=03h — read cursor position and shape
F000:F04D  B5F1            dw     int10_04_read_lightpen      ; AH=04h — light pen (not supported; common epilogue F1B5)
F000:F04F  F6F1            dw     int10_05_select_page        ; AH=05h — select active page
F000:F051  71F2            dw     int10_06_scroll_up          ; AH=06h — scroll window up
F000:F053  F4F2            dw     int10_07_scroll_down        ; AH=07h — scroll window down
F000:F055  30F3            dw     int10_08_read_char_attr     ; AH=08h — read character/attribute at cursor
F000:F057  63F3            dw     int10_09_write_char_attr    ; AH=09h — write character with attribute
F000:F059  81F3            dw     int10_0A_write_char         ; AH=0Ah — write character only
F000:F05B  2DF2            dw     int10_0B_set_palette        ; AH=0Bh — set palette/background color
F000:F05D  AFF3            dw     int10_0C_write_pixel        ; AH=0Ch — write pixel
F000:F05F  9EF3            dw     int10_0D_read_pixel         ; AH=0Dh — read pixel
F000:F061  97F6            dw     int10_0E_write_tty          ; AH=0Eh — teletype character output
F000:F063  4FF2            dw     int10_0F_get_mode           ; AH=0Fh — get current video mode

; ----------------------------------------------------------------------------------------------
; INT10_VIDEO — BIOS video service (standard IBM entry point F000:F065).
; Saves ES,DS,DX,CX,BX,SI,DI; AX is popped before jumping to the handler.
; On handler entry: DS=0040, ES=B800 (CGA video RAM), AL = original AL, AH = current mode (0040:0049),
; SI = 2*function. Functions ≥10h are ignored. All handlers exit via common epilogue F1B5.
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
F000:F07D  E93501          jmp    int10_04_read_lightpen      ; and exit doing nothing (unsupported function)

loc_F080:    ; xrefs: F07A
F000:F080  E8660E          call   sub_FEE9                    ; DS = 0040h — BIOS data area
F000:F083  B800B8          mov    ax, 0B800h                  ; AX = B800h — CGA video memory segment
F000:F086  8EC0            mov    es, ax                      ; ES = B800h (also used for mode 7)
F000:F088  58              pop    ax                          ; restore AX (AL — call parameter)
F000:F089  8A264900        mov    ah, byte [49h]              ; AH = 0040:0049 — current video mode
F000:F08D  2EFFA445F0      jmp    word cs:[si - 0FBBh]        ; jump via table: CS:[F045+SI] (−0FBBh ≡ +F045h)

; ----------------------------------------------------------------------------------------------
; sub_F092 — set 6845 hardware cursor to position AX (AH=row, AL=column).
; Address = (position offset + page start 0040:004E)/2 → CRTC registers 0Eh/0Fh via sub_F1C8.
; For the current video page. Clobbers AX, CX, DX.
; ----------------------------------------------------------------------------------------------
sub_F092:    ; xrefs: F1F1 F213
F000:F092  E8CB01          call   sub_F260                    ; AX = byte offset of position (row*columns+column)*2
F000:F095  8BC8            mov    cx, ax                      ; CX = position offset within page
F000:F097  030E4E00        add    cx, word [4Eh]              ; + 0040:004E — active page start offset in video memory
F000:F09B  D1F9            sar    cx, 1                       ; divide by 2 — character cell address for 6845 (char+attribute word)
F000:F09D  B40E            mov    ah, 0Eh                     ; AH = 0Eh — CRTC register "cursor location high" (then 0Fh)
F000:F09F  E82601          call   sub_F1C8                    ; write CX to 6845 registers 0Eh/0Fh
F000:F0A2  C3              ret                                ; Return
F000:F0A3  00              db     00h                         ; padding up to fixed address F000:F0A4

; ----------------------------------------------------------------------------------------------
; video_params — 6845 parameter table (INT 1Dh vector), 4 blocks of 16 bytes (R0–R15): 40x25, 80x25, graphics, block 4.
; Timing values in dk differ from IBM, from my, and from the emulator tables at F400:0313. In practice R0–R8 from here
; reach the 6845 only in POST (E0E7, direct write of the 40x25 block): INT 10h AH=0 in dk writes them via 3D4/3D5,
; and the emulator discards R0–R8 and takes timing from F400:0313 on mode change via 3D8.
; ----------------------------------------------------------------------------------------------
video_params:    ; xrefs: E0E7
F000:F0A4  3E282F052006…   db     3Eh,28h,2Fh,05h,20h,06h,19h,1Ch ; 40x25: R0=3Eh, R1=28h (40), R2=2Fh, R3=05h, R4=20h, R5=06h, R6=19h (25), R7=1Ch
F000:F0AC  020706070000…   db     02h,07h,06h,07h,00h,00h,00h,00h ; 40x25: R8=02h interlace, R9=07h (8 scan lines per char), R10/R11=06/07 cursor, R12–R15=0 (start, cursor position)
F000:F0B4  7E50600A1F05…   db     7Eh,50h,60h,0Ah,1Fh,05h,19h,1Ch ; 80x25: R0=7Eh, R1=50h (80), R2=60h, R3=0Ah, R4=1Fh, R5=05h, R6=19h, R7=1Ch
F000:F0BC  020706070000…   db     02h,07h,06h,07h,00h,00h,00h,00h ; 80x25: R8=02h, R9=07h, cursor 06–07, R12–R15=0
F000:F0C4  3E282F057F01…   db     3Eh,28h,2Fh,05h,7Fh,01h,64h,6Fh ; Graphics: R0=3Eh, R1=28h, R2=2Fh, R3=05h, R4=7Fh, R5=01h, R6=64h (100 rows), R7=6Fh
F000:F0CC  020106070000…   db     02h,01h,06h,07h,00h,00h,00h,00h ; Graphics: R8=02h, R9=01h (2 scan lines per row), cursor 06–07, R12–R15=0
F000:F0D4  7F505A087F06…   db     7Fh,50h,5Ah,08h,7Fh,06h,64h,70h ; Block 4 (mode 7 on IBM): R0=7Fh, R1=50h, R2=5Ah, R3=08h, R4=7Fh, R5=06h, R6=64h, R7=70h
F000:F0DC  02010B0C0000…   db     02h,01h,0Bh,0Ch,00h,00h,00h,00h ; Block 4: R8=02h, R9=01h, cursor 0Bh–0Ch (as IBM mono mode), R12–R15=0

; ----------------------------------------------------------------------------------------------
; dat_F0E4 — video page sizes in bytes indexed by (mode AND 0Eh) → 0040:004C (words).
; ----------------------------------------------------------------------------------------------
dat_F0E4:    ; xrefs: F190
F000:F0E4  00080010004000  db     00h,08h,00h,10h,00h,40h,00h ; Modes 0/1: 0800h (2 KB, 40x25); 2/3: 1000h (4 KB, 80x25); 4/5: 4000h (16 KB)…
F000:F0EB  40              db     40h                         ; …high byte of the word for modes 6/7: 4000h (16 KB)

; ----------------------------------------------------------------------------------------------
; dat_F0EC — text column count for modes 0–7 → 0040:004A
; ----------------------------------------------------------------------------------------------
dat_F0EC:    ; xrefs: F183
F000:F0EC  282850502828…   db     '((PP((PP'                  ; Columns: 40,40,80,80,40,40,80,80 (28h/50h) for modes 0..7

; ----------------------------------------------------------------------------------------------
; dat_F0F4 — CGA mode register values (port 3D8) for modes 0–7 → 0040:0065
; ----------------------------------------------------------------------------------------------
dat_F0F4:    ; xrefs: F17A
F000:F0F4  2C282D292A2E    db     ',(-)*.'                    ; Modes 0–5: 2Ch,28h,2Dh,29h,2Ah,2Eh (bit0 80 col, bit1 graphics, bit2 b/w, bit3 video on)
F000:F0FA  1E29            db     1Eh,29h                     ; Mode 6: 1Eh (640x200, bit4 high-res); mode 7: 29h (same as 80x25 color)

; ----------------------------------------------------------------------------------------------
; int10_00_set_mode — AH=00h, set video mode AL (0–7, no range check).
; Disables video (3D8←0), outputs 16 6845 registers from the INT 1Dh table via ports 3D4/3D5 (NMI emulation,
; R0–R8 discarded by the emulator), clears video RAM B800, fills 0040:0049–0066,
; enables the mode (3D8 — where the emulator reloads R0–R9) and palette (3D9). CRTC address is always 3D4.
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
; Load 16 6845 registers via ports 3D4/3D5, as IBM does (in dk — through NMI emulation): R0–R8 discarded,
; R9 saved in 0040:00B8, R10–R15 reach the 6845. In my replaced by direct writes to F000:0000/0002.
; ----------------------------------------------------------------------------------------------
loc_F135:    ; xrefs: F123 F12A F131
F000:F135  50              push   ax                          ; save mode
F000:F136  32E4            xor    ah, ah                      ; AH = 0 — CRTC register number

loc_F138:    ; xrefs: F143
F000:F138  8AC4            mov    al, ah                      ; AL = register number
F000:F13A  EE              out    dx, al                      ; OUT 3D4 (NMI → nmi_port_3D4): register number into shadow index 0040:00B4
F000:F13B  42              inc    dx                          ; DX = 3D5h — CRTC data register
F000:F13C  FEC4            inc    ah                          ; next register number
F000:F13E  8A07            mov    al, byte [bx]               ; AL = parameter value from table
F000:F140  EE              out    dx, al                      ; OUT 3D5 (NMI → nmi_port_3D5): R0–R8 discarded, R9 saved, R10+ → 6845
F000:F141  43              inc    bx                          ; next table byte
F000:F142  4A              dec    dx                          ; DX = 3D4h — back to the index register
F000:F143  E2F3            loop   loc_F138                    ; repeat for R0..R15
F000:F145  58              pop    ax                          ; AH = mode
F000:F146  1F              pop    ds                          ; DS = 0040h
F000:F147  33FF            xor    di, di                      ; DI = 0 — start of video memory
F000:F149  893E4E00        mov    word [4Eh], di              ; 0040:004E — active page start offset := 0
F000:F14D  C606620000      mov    byte [62h], 0               ; 0040:0062 — active page number := 0
F000:F152  B90020          mov    cx, 2000h                   ; CX = 2000h words = 16 KB — entire CGA video memory
F000:F155  80FC04          cmp    ah, 4                       ; text mode (< 4)?
F000:F158  720B            jb     loc_F165                    ; yes — fill with spaces
F000:F15A  80FC07          cmp    ah, 7                       ; mode 7?
F000:F15D  7404            je     loc_F163                    ; yes — special size
F000:F15F  33C0            xor    ax, ax                      ; graphics: fill value 0 (black pixels)
F000:F161  EB05            jmp    loc_F168                    ; to clearing

loc_F163:    ; xrefs: F15D
F000:F163  B508            mov    ch, 8                       ; mode 7: CX = 0800h words (4 KB)

loc_F165:    ; xrefs: F158
F000:F165  B82007          mov    ax, 720h                    ; text: AX = 0720h — space with attribute 07h (gray on black)

loc_F168:    ; xrefs: F161
F000:F168  F3AB            rep stosw word es:[di], ax         ; clear video memory ES:DI (B800:0000)
F000:F16A  C70660000706    mov    word [60h], 607h            ; 0040:0060 — cursor shape := 0607h (lines 6–7)
F000:F170  A04900          mov    al, byte [49h]              ; AL = mode
F000:F173  32E4            xor    ah, ah                      ; AX = mode
F000:F175  8BF0            mov    si, ax                      ; SI = mode index into tables
F000:F177  BAD803          mov    dx, 3D8h                    ; DX = 3D8h — CGA mode register
F000:F17A  2E8A84F4F0      mov    al, byte cs:[si - 0F0Ch]    ; AL = mode register value from dat_F0F4 (CS:[F0F4+SI])
F000:F17F  EE              out    dx, al                      ; enable mode and video (NMI emulation of 3D8; the emulator probably reloads R0–R9 from its own tables)
F000:F180  A26500          mov    byte [65h], al              ; 0040:0065 — CGA mode register copy
F000:F183  2E8A84ECF0      mov    al, byte cs:[si - 0F14h]    ; AL = column count from dat_F0EC
F000:F188  32E4            xor    ah, ah                      ; AX = columns
F000:F18A  A34A00          mov    word [4Ah], ax              ; 0040:004A — number of screen columns
F000:F18D  83E60E          and    si, 0Eh                     ; SI = (mode AND 0Eh) — word index into dat_F0E4
F000:F190  2E8B8CE4F0      mov    cx, word cs:[si - 0F1Ch]    ; CX = page size from dat_F0E4
F000:F195  890E4C00        mov    word [4Ch], cx              ; 0040:004C — video page size in bytes
F000:F199  B90800          mov    cx, 8                       ; CX = 8 — cursor positions for 8 pages
F000:F19C  BF5000          mov    di, 50h                     ; DI = 0050h — 0040:0050..005F, cursor positions of pages 0–7
F000:F19F  1E              push   ds                          ; ES = DS = 0040h
F000:F1A0  07              pop    es                          ; (ES = 0040)
F000:F1A1  33C0            xor    ax, ax                      ; AX = 0 — cursors at (0,0)
F000:F1A3  F3AB            rep stosw word es:[di], ax         ; clear cursor positions
F000:F1A5  42              inc    dx                          ; DX = 3D9h — CGA color select register
F000:F1A6  B030            mov    al, 30h                     ; AL = 30h — palette 1, background intensity, color 0
F000:F1A8  803E490006      cmp    byte [49h], 6               ; mode 6 (640x200)?
F000:F1AD  7502            jne    loc_F1B1                    ; no
F000:F1AF  B03F            mov    al, 3Fh                     ; mode 6: AL = 3Fh — foreground color white (15)

loc_F1B1:    ; xrefs: F1AD
F000:F1B1  EE              out    dx, al                      ; write color register (NMI emulation of 3D9)
F000:F1B2  A26600          mov    byte [66h], al              ; 0040:0066 — CGA palette register copy

; ----------------------------------------------------------------------------------------------
; int10_04_read_lightpen — AH=04h (light pen not supported) and also the common INT 10h epilogue.
; Restores DI,SI,BX,CX,DX,DS,ES; AX is returned as is (for AH=04h: AH = current mode,
; i.e. non-zero — probably a flaw: IBM returns AH=0 "pen not triggered").
; ----------------------------------------------------------------------------------------------
int10_04_read_lightpen:    ; xrefs: F04D F07D F1C6 F1F4 F216 F242 F2B6 F345 F37E F39B F3AC F3CB F467 F4C7 F547 F5A6 …
F000:F1B5  5F              pop    di                          ; restore DI
F000:F1B6  5E              pop    si                          ; Restore SI
F000:F1B7  5B              pop    bx                          ; Restore BX

; ----------------------------------------------------------------------------------------------
; epilogue tail (also used by AH=0Fh, which keeps BX)
; ----------------------------------------------------------------------------------------------
loc_F1B8:    ; xrefs: F25D
F000:F1B8  59              pop    cx                          ; Restore CX
F000:F1B9  5A              pop    dx                          ; Restore DX
F000:F1BA  1F              pop    ds                          ; Restore DS
F000:F1BB  07              pop    es                          ; Restore ES
F000:F1BC  CF              iret                               ; return from INT 10h

; ----------------------------------------------------------------------------------------------
; int10_01_set_cursor_type — AH=01h: CH = start, CL = end cursor scan line.
; Saves to 0040:0060 and writes 6845 registers R10/R11.
; ----------------------------------------------------------------------------------------------
int10_01_set_cursor_type:    ; xrefs: F047
F000:F1BD  B40A            mov    ah, 0Ah                     ; AH = 0Ah — CRTC register "cursor start line" (then 0Bh)
F000:F1BF  890E6000        mov    word [60h], cx              ; 0040:0060 — cursor shape := CX
F000:F1C3  E80200          call   sub_F1C8                    ; write CH→R10, CL→R11
F000:F1C6  EBED            jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; sub_F1C8 — write a 6845 register pair: AH → CH, AH+1 → CL.
; Via ports 0040:0063 (3D4) and 3D5 — i.e. through NMI CRTC emulation. Clobbers AL, DX.
; ----------------------------------------------------------------------------------------------
sub_F1C8:    ; xrefs: F09F F1C3 F20A
F000:F1C8  8B166300        mov    dx, word [63h]              ; DX = 0040:0063 — CRTC index port (3D4h)
F000:F1CC  8AC4            mov    al, ah                      ; AL = register number
F000:F1CE  EE              out    dx, al                      ; select 6845 register (NMI → emulator stores index at 0040:00B4)
F000:F1CF  42              inc    dx                          ; DX = 3D5h — CRTC data port
F000:F1D0  8AC5            mov    al, ch                      ; AL = high byte of value
F000:F1D2  EE              out    dx, al                      ; write register (NMI → emulator forwards it to F000:0002)
F000:F1D3  4A              dec    dx                          ; DX = 3D4h
F000:F1D4  8AC4            mov    al, ah                      ; AL = register number
F000:F1D6  FEC0            inc    al                          ; next register (AH+1)
F000:F1D8  EE              out    dx, al                      ; select it
F000:F1D9  42              inc    dx                          ; DX = 3D5h
F000:F1DA  8AC1            mov    al, cl                      ; AL = low byte of value
F000:F1DC  EE              out    dx, al                      ; write register
F000:F1DD  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; int10_02_set_cursor_pos — AH=02h: BH = page, DH/DL = row/column.
; Stores position at 0040:0050+2*BH; if the page is active, moves the hardware cursor.
; ----------------------------------------------------------------------------------------------
int10_02_set_cursor_pos:    ; xrefs: F049
F000:F1DE  8ACF            mov    cl, bh                      ; CL = page number
F000:F1E0  32ED            xor    ch, ch                      ; CX = page
F000:F1E2  D1E1            shl    cx, 1                       ; CX = page*2
F000:F1E4  8BF1            mov    si, cx                      ; SI = cursor position word index
F000:F1E6  895450          mov    word [si + 50h], dx         ; 0040:0050+2*page — page cursor position := DX
F000:F1E9  383E6200        cmp    byte [62h], bh              ; page = active page (0040:0062)?
F000:F1ED  7505            jne    loc_F1F4                    ; no — just stored it
F000:F1EF  8BC2            mov    ax, dx                      ; AX = position (AH row, AL column)
F000:F1F1  E89EFE          call   sub_F092                    ; move 6845 hardware cursor

loc_F1F4:    ; xrefs: F1ED
F000:F1F4  EBBF            jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; int10_05_select_page — AH=05h: AL = new active page.
; Computes page start (0040:004E), writes 6845 registers R12/R13 and sets that page's cursor.
; ----------------------------------------------------------------------------------------------
int10_05_select_page:    ; xrefs: F04F
F000:F1F6  A26200          mov    byte [62h], al              ; 0040:0062 — active page := AL
F000:F1F9  8B0E4C00        mov    cx, word [4Ch]              ; CX = 0040:004C — page size in bytes
F000:F1FD  98              cbw                                ; AX = page number (actually CBW, 98h; disassembler showed cwde)
F000:F1FE  50              push   ax                          ; save page number
F000:F1FF  F7E1            mul    cx                          ; AX = page*size — page start offset
F000:F201  A34E00          mov    word [4Eh], ax              ; 0040:004E — active page start := AX
F000:F204  8BC8            mov    cx, ax                      ; CX = start offset
F000:F206  D1F9            sar    cx, 1                       ; /2 — start address in character cells for 6845
F000:F208  B40C            mov    ah, 0Ch                     ; AH = 0Ch — CRTC register "start address high" (then 0Dh)
F000:F20A  E8BBFF          call   sub_F1C8                    ; write R12/R13 — switch displayed page
F000:F20D  5B              pop    bx                          ; BX = page number
F000:F20E  D1E3            shl    bx, 1                       ; BX = page*2
F000:F210  8B4750          mov    ax, word [bx + 50h]         ; AX = 0040:0050+2*page — this page's cursor position
F000:F213  E87CFE          call   sub_F092                    ; set hardware cursor
F000:F216  EB9D            jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; int10_03_read_cursor_pos — AH=03h: BH = page.
; Output: DX = position (DH row, DL column), CX = cursor shape (0040:0060). Own epilogue.
; ----------------------------------------------------------------------------------------------
int10_03_read_cursor_pos:    ; xrefs: F04B
F000:F218  8ADF            mov    bl, bh                      ; BL = page
F000:F21A  32FF            xor    bh, bh                      ; BX = page
F000:F21C  D1E3            shl    bx, 1                       ; BX = page*2
F000:F21E  8B5750          mov    dx, word [bx + 50h]         ; DX = 0040:0050+2*page — cursor position
F000:F221  8B0E6000        mov    cx, word [60h]              ; CX = 0040:0060 — cursor shape
F000:F225  5F              pop    di                          ; restore DI
F000:F226  5E              pop    si                          ; Restore SI
F000:F227  5B              pop    bx                          ; Restore BX
F000:F228  58              pop    ax                          ; discard saved CX (return the new one)
F000:F229  58              pop    ax                          ; discard saved DX (AX gets the old DX value, as in IBM)
F000:F22A  1F              pop    ds                          ; Restore DS
F000:F22B  07              pop    es                          ; Restore ES
F000:F22C  CF              iret                               ; return from INT 10h

; ----------------------------------------------------------------------------------------------
; int10_0B_set_palette — AH=0Bh: BH=0 — background/border color BL (bits 0–4); BH=1 — palette BL bit 0.
; Modifies copy at 0040:0066 and writes CGA color select register 3D9 (NMI emulation).
; ----------------------------------------------------------------------------------------------
int10_0B_set_palette:    ; xrefs: F05B
F000:F22D  BAD903          mov    dx, 3D9h                    ; DX = 3D9h — CGA color select register
F000:F230  A06600          mov    al, byte [66h]              ; AL = 0040:0066 — current palette register value
F000:F233  0AFF            or     bh, bh                      ; BH = 0 (background color)?
F000:F235  750E            jne    loc_F245                    ; no — palette select
F000:F237  24E0            and    al, 0E0h                    ; keep bits 5–7 (palette)
F000:F239  80E31F          and    bl, 1Fh                     ; BL = color (bits 0–3) + intensity (bit 4)
F000:F23C  0AC3            or     al, bl                      ; new background/border color

loc_F23E:    ; xrefs: F249 F24D
F000:F23E  EE              out    dx, al                      ; write register 3D9
F000:F23F  A26600          mov    byte [66h], al              ; update copy at 0040:0066
F000:F242  E970FF          jmp    int10_04_read_lightpen      ; exit

loc_F245:    ; xrefs: F235
F000:F245  24DF            and    al, 0DFh                    ; clear bit 5 — palette 0 (green/red/brown)
F000:F247  D0EB            shr    bl, 1                       ; BL bit 0 → CF
F000:F249  73F3            jae    loc_F23E                    ; palette 0 — write
F000:F24B  0C20            or     al, 20h                     ; palette 1 (cyan/magenta/white) — bit 5
F000:F24D  EBEF            jmp    loc_F23E                    ; write

; ----------------------------------------------------------------------------------------------
; int10_0F_get_mode — AH=0Fh: output AH = columns (0040:004A), AL = mode (0040:0049), BH = page (0040:0062).
; BX is not restored (BL keeps its input value).
; ----------------------------------------------------------------------------------------------
int10_0F_get_mode:    ; xrefs: F063
F000:F24F  8A264A00        mov    ah, byte [4Ah]              ; AH = 0040:004A — number of columns
F000:F253  A04900          mov    al, byte [49h]              ; AL = 0040:0049 — current mode
F000:F256  8A3E6200        mov    bh, byte [62h]              ; BH = 0040:0062 — active page
F000:F25A  5F              pop    di                          ; restore DI
F000:F25B  5E              pop    si                          ; Restore SI
F000:F25C  59              pop    cx                          ; pop saved BX into CX (will be overwritten) — BX is returned new
F000:F25D  E958FF          jmp    loc_F1B8                    ; rest of epilogue (CX, DX, DS, ES, IRET)

; ----------------------------------------------------------------------------------------------
; sub_F260 — byte offset of a character cell in the page: AX = (AH*columns + AL)*2.
; Input: AH = row, AL = column; columns — 0040:004A. BX preserved.
; ----------------------------------------------------------------------------------------------
sub_F260:    ; xrefs: F092 F2BD F35D
F000:F260  53              push   bx                          ; save BX
F000:F261  8BD8            mov    bx, ax                      ; BX = position (BL = column)
F000:F263  8AC4            mov    al, ah                      ; AL = row
F000:F265  F6264A00        mul    byte [4Ah]                  ; AX = row * 0040:004A (columns)
F000:F269  32FF            xor    bh, bh                      ; BX = column
F000:F26B  03C3            add    ax, bx                      ; + column
F000:F26D  D1E0            shl    ax, 1                       ; *2 — each character cell = char + attribute
F000:F26F  5B              pop    bx                          ; Restore BX
F000:F270  C3              ret                                ; return, AX = offset

; ----------------------------------------------------------------------------------------------
; int10_06_scroll_up — AH=06h: scroll window up.
; Input: AL = line count (0 — clear window), BH = fill attribute, CH/CL — upper left corner,
; DH/DL — lower right. AH (on handler entry) = mode; graphics modes → loc_F415.
; ----------------------------------------------------------------------------------------------
int10_06_scroll_up:    ; xrefs: F051
F000:F271  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F273  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F276  7208            jb     loc_F280                    ; yes
F000:F278  80FC07          cmp    ah, 7                       ; mode 7 (also text)?
F000:F27B  7403            je     loc_F280                    ; yes
F000:F27D  E99501          jmp    loc_F415                    ; graphics — graphics-mode scroll

loc_F280:    ; xrefs: F276 F27B
F000:F280  53              push   bx                          ; save BX (BH = attribute)
F000:F281  8BC1            mov    ax, cx                      ; AX = upper left corner
F000:F283  E83700          call   sub_F2BD                    ; setup: SI=DI=window start, DH/DL=size, BP=bytes per row, AX=offset of BL rows
F000:F286  7431            je     loc_F2B9                    ; AL=0 — just clear the whole window
F000:F288  03F0            add    si, ax                      ; SI = source BL rows below
F000:F28A  8AE6            mov    ah, dh                      ; AH = window height
F000:F28C  2AE3            sub    ah, bl                      ; AH = number of rows to move

loc_F28E:    ; xrefs: F297
F000:F28E  E85300          call   sub_F2E4                    ; copy one window row (DL words)
F000:F291  03F5            add    si, bp                      ; source — next screen row
F000:F293  03FD            add    di, bp                      ; destination — next screen row
F000:F295  FECC            dec    ah                          ; row counter
F000:F297  75F5            jne    loc_F28E                    ; until all rows are moved

; ----------------------------------------------------------------------------------------------
; fill vacated rows with spaces with attribute BH
; ----------------------------------------------------------------------------------------------
loc_F299:    ; xrefs: F2BB
F000:F299  58              pop    ax                          ; AX = saved BX → AH = fill attribute
F000:F29A  B020            mov    al, 20h                     ; AL = space

loc_F29C:    ; xrefs: F2A3
F000:F29C  E84E00          call   sub_F2ED                    ; fill window row
F000:F29F  03FD            add    di, bp                      ; next row
F000:F2A1  FECB            dec    bl                          ; cleared-row counter
F000:F2A3  75F7            jne    loc_F29C                    ; until all are cleared

; ----------------------------------------------------------------------------------------------
; common text scroll completion (up/down)
; ----------------------------------------------------------------------------------------------
loc_F2A5:    ; xrefs: F329
F000:F2A5  E8410C          call   sub_FEE9                    ; DS = 0040h (DS pointed to video memory during scroll)
F000:F2A8  803E490007      cmp    byte [49h], 7               ; mode 7?
F000:F2AD  7407            je     loc_F2B6                    ; yes — leave mode register alone
F000:F2AF  A06500          mov    al, byte [65h]              ; AL = 0040:0065 — CGA mode register copy
F000:F2B2  BAD803          mov    dx, 3D8h                    ; DX = 3D8h
F000:F2B5  EE              out    dx, al                      ; rewrite mode register (in IBM — re-enable video after "snow" blanking; there is no blanking here)

loc_F2B6:    ; xrefs: F2AD
F000:F2B6  E9FCFE          jmp    int10_04_read_lightpen      ; exit

loc_F2B9:    ; xrefs: F286
F000:F2B9  8ADE            mov    bl, dh                      ; clear whole window: row count = window height
F000:F2BB  EBDC            jmp    loc_F299                    ; to fill

; ----------------------------------------------------------------------------------------------
; sub_F2BD — set up text scrolling.
; Input: AX = window corner (row/column), CX = upper left, DX = lower right, BL = line count, ES=B800.
; Output: SI=DI = corner offset + page start; DH = window height, DL = width; CH=0;
; BP = bytes per screen row; AX = BL*BP; DS = ES; ZF=1 if BL=0.
; ----------------------------------------------------------------------------------------------
sub_F2BD:    ; xrefs: F283 F307
F000:F2BD  E8A0FF          call   sub_F260                    ; AX = corner offset within page
F000:F2C0  03064E00        add    ax, word [4Eh]              ; + 0040:004E — active page start
F000:F2C4  8BF8            mov    di, ax                      ; DI = destination address
F000:F2C6  8BF0            mov    si, ax                      ; SI = source address (adjusted by the caller)
F000:F2C8  2BD1            sub    dx, cx                      ; DX = lower right − upper left
F000:F2CA  FEC6            inc    dh                          ; DH = window height in rows
F000:F2CC  FEC2            inc    dl                          ; DL = window width in columns
F000:F2CE  32ED            xor    ch, ch                      ; CH = 0 (CL used as word counter)
F000:F2D0  8B2E4A00        mov    bp, word [4Ah]              ; BP = 0040:004A — columns (word read, high byte 004B = 0)
F000:F2D4  03ED            add    bp, bp                      ; BP = bytes per screen row
F000:F2D6  8AC3            mov    al, bl                      ; AL = scroll line count
F000:F2D8  F6264A00        mul    byte [4Ah]                  ; AX = rows * columns
F000:F2DC  03C0            add    ax, ax                      ; AX = offset of BL rows in bytes
F000:F2DE  06              push   es                          ; DS = ES = B800h — copy within video memory
F000:F2DF  1F              pop    ds                          ; (DS = B800)
F000:F2E0  80FB00          cmp    bl, 0                       ; ZF=1 if scrolling by 0 rows (clear window)
F000:F2E3  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; sub_F2E4 — copy one window row: DL words DS:SI → ES:DI (direction per DF). SI, DI preserved.
; ----------------------------------------------------------------------------------------------
sub_F2E4:    ; xrefs: F28E F312
F000:F2E4  8ACA            mov    cl, dl                      ; CX = window width (CH=0)
F000:F2E6  56              push   si                          ; Save SI
F000:F2E7  57              push   di                          ; save DI
F000:F2E8  F3A5            rep movsw word es:[di], word [si]  ; copy characters with attributes
F000:F2EA  5F              pop    di                          ; restore DI
F000:F2EB  5E              pop    si                          ; Restore SI
F000:F2EC  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; sub_F2ED — fill one window row: DL words of AX (char+attribute) at ES:DI. DI preserved.
; ----------------------------------------------------------------------------------------------
sub_F2ED:    ; xrefs: F29C F320
F000:F2ED  8ACA            mov    cl, dl                      ; CX = window width
F000:F2EF  57              push   di                          ; save DI
F000:F2F0  F3AB            rep stosw word es:[di], ax         ; fill row
F000:F2F2  5F              pop    di                          ; restore DI
F000:F2F3  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; int10_07_scroll_down — AH=07h: scroll window down (parameters as for AH=06h).
; Copies bottom-up (DF=1) from the lower right corner; graphics → loc_F46E.
; ----------------------------------------------------------------------------------------------
int10_07_scroll_down:    ; xrefs: F053
F000:F2F4  FD              std                                ; DF=1 — copy backwards
F000:F2F5  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F2F7  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F2FA  7208            jb     loc_F304                    ; yes
F000:F2FC  80FC07          cmp    ah, 7                       ; mode 7?
F000:F2FF  7403            je     loc_F304                    ; yes
F000:F301  E96A01          jmp    loc_F46E                    ; graphics — graphics-mode scroll down

loc_F304:    ; xrefs: F2FA F2FF
F000:F304  53              push   bx                          ; save BX (BH = attribute)
F000:F305  8BC2            mov    ax, dx                      ; AX = lower right corner — start from the bottom
F000:F307  E8B3FF          call   sub_F2BD                    ; scroll setup (SI=DI=lower right corner)
F000:F30A  7420            je     loc_F32C                    ; AL=0 — clear whole window
F000:F30C  2BF0            sub    si, ax                      ; SI = source BL rows above
F000:F30E  8AE6            mov    ah, dh                      ; AH = window height
F000:F310  2AE3            sub    ah, bl                      ; AH = number of rows to move

loc_F312:    ; xrefs: F31B
F000:F312  E8CFFF          call   sub_F2E4                    ; copy row (right to left)
F000:F315  2BF5            sub    si, bp                      ; source — row above
F000:F317  2BFD            sub    di, bp                      ; destination — row above
F000:F319  FECC            dec    ah                          ; row counter
F000:F31B  75F5            jne    loc_F312                    ; until all rows are moved

; ----------------------------------------------------------------------------------------------
; fill vacated top rows
; ----------------------------------------------------------------------------------------------
loc_F31D:    ; xrefs: F32E
F000:F31D  58              pop    ax                          ; AH = fill attribute (from saved BX)
F000:F31E  B020            mov    al, 20h                     ; AL = space

loc_F320:    ; xrefs: F327
F000:F320  E8CAFF          call   sub_F2ED                    ; fill row
F000:F323  2BFD            sub    di, bp                      ; row above
F000:F325  FECB            dec    bl                          ; counter
F000:F327  75F7            jne    loc_F320                    ; until all are cleared
F000:F329  E979FF          jmp    loc_F2A5                    ; common completion (DS=0040, mode register, exit)

loc_F32C:    ; xrefs: F30A
F000:F32C  8ADE            mov    bl, dh                      ; clear whole window: rows = height
F000:F32E  EBED            jmp    loc_F31D                    ; to fill

; ----------------------------------------------------------------------------------------------
; int10_08_read_char_attr — AH=08h: BH = page. Output: AL = character, AH = attribute at cursor.
; Graphics modes → loc_F5A9 (character recognition from pixels).
; ----------------------------------------------------------------------------------------------
int10_08_read_char_attr:    ; xrefs: F055
F000:F330  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F333  7208            jb     loc_F33D                    ; yes
F000:F335  80FC07          cmp    ah, 7                       ; mode 7?
F000:F338  7403            je     loc_F33D                    ; yes
F000:F33A  E96C02          jmp    loc_F5A9                    ; graphics — read character by matching its image in video memory

loc_F33D:    ; xrefs: F333 F338
F000:F33D  E80800          call   sub_F348                    ; BX = address of page BH cursor position in video memory
F000:F340  8BF3            mov    si, bx                      ; SI = that address
F000:F342  06              push   es                          ; DS = ES = B800h
F000:F343  1F              pop    ds                          ; (DS = B800)
F000:F344  AD              lodsw  ax, word [si]               ; AX = char/attribute word
F000:F345  E96DFE          jmp    int10_04_read_lightpen      ; exit with result in AX

; ----------------------------------------------------------------------------------------------
; sub_F348 — address of the character cell under page BH's cursor: BX = BH*page_size + position offset.
; Input: BH = page, DS=0040. Output: BX — offset in B800, AX — offset within page; clobbers CX, SI.
; ----------------------------------------------------------------------------------------------
sub_F348:    ; xrefs: F33D F374 F390
F000:F348  8ACF            mov    cl, bh                      ; CL = page
F000:F34A  32ED            xor    ch, ch                      ; CX = page
F000:F34C  8BF1            mov    si, cx                      ; SI = page
F000:F34E  D1E6            shl    si, 1                       ; SI = page*2
F000:F350  8B4450          mov    ax, word [si + 50h]         ; AX = 0040:0050+2*page — page cursor position
F000:F353  33DB            xor    bx, bx                      ; BX = 0 — page start accumulator
F000:F355  E306            jcxz   loc_F35D                    ; page 0 — start is 0

loc_F357:    ; xrefs: F35B
F000:F357  031E4C00        add    bx, word [4Ch]              ; BX += 0040:004C (page size) — multiply by repeated addition
F000:F35B  E2FA            loop   loc_F357                    ; CX times

loc_F35D:    ; xrefs: F355
F000:F35D  E800FF          call   sub_F260                    ; AX = position offset within page
F000:F360  03D8            add    bx, ax                      ; BX = page start + offset
F000:F362  C3              ret                                ; Return

; ----------------------------------------------------------------------------------------------
; int10_09_write_char_attr — AH=09h: AL = character, BL = attribute, BH = page, CX = repeat count.
; Writes at cursor position without moving it. Graphics → loc_F4F8.
; ----------------------------------------------------------------------------------------------
int10_09_write_char_attr:    ; xrefs: F057
F000:F363  80FC04          cmp    ah, 4                       ; text mode 0–3?
F000:F366  7208            jb     loc_F370                    ; yes
F000:F368  80FC07          cmp    ah, 7                       ; mode 7?
F000:F36B  7403            je     loc_F370                    ; yes
F000:F36D  E98801          jmp    loc_F4F8                    ; graphics — draw character from font

loc_F370:    ; xrefs: F366 F36B
F000:F370  8AE3            mov    ah, bl                      ; AH = attribute, AL = character
F000:F372  50              push   ax                          ; save char+attribute word
F000:F373  51              push   cx                          ; save repeat count
F000:F374  E8D1FF          call   sub_F348                    ; BX = address of page BH cursor position
F000:F377  8BFB            mov    di, bx                      ; DI = video memory address
F000:F379  59              pop    cx                          ; CX = repeat count
F000:F37A  58              pop    ax                          ; AX = char+attribute

loc_F37B:    ; xrefs: F37C
F000:F37B  AB              stosw  word es:[di], ax            ; write character cell to ES:DI (B800)
F000:F37C  E2FD            loop   loc_F37B                    ; CX times (CX=0 → 65536)
F000:F37E  E934FE          jmp    int10_04_read_lightpen      ; exit

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Ah — write character at cursor position without changing the attribute.
; Input (after dispatcher F080): AH=current video mode (0040:0049), AL=character, BH=page, BL=color (graphics), CX=repeat count;
; ES=B800 (video RAM), DS=0040. Text modes (0–3,7) handled here, graphics (4–6) jump to common graphics output F4F8.
; ----------------------------------------------------------------------------------------------
int10_0A_write_char:    ; xrefs: F059
F000:F381  80FC04          cmp    ah, 4                       ; AH = video mode: modes 0–3 are text
F000:F384  7208            jb     loc_F38E                    ; text mode → write to video buffer
F000:F386  80FC07          cmp    ah, 7                       ; mode 7 (monochrome text) is also handled as text
F000:F389  7403            je     loc_F38E                    ; mode 7 → write to video buffer
F000:F38B  E96A01          jmp    loc_F4F8                    ; graphics modes 4–6: character drawn from the font (code shared with AH=09h)

loc_F38E:    ; xrefs: F384 F389
F000:F38E  50              push   ax                          ; save character (AL)
F000:F38F  51              push   cx                          ; save repeat count
F000:F390  E8B5FF          call   sub_F348                    ; BX = offset of page BH cursor cell in video buffer
F000:F393  8BFB            mov    di, bx                      ; DI = cell address in B800
F000:F395  59              pop    cx                          ; restore repeat count CX
F000:F396  58              pop    ax                          ; restore character AL

; ----------------------------------------------------------------------------------------------
; Loop writing CX copies of the character: only the code byte is written, the attribute byte is skipped.
; ----------------------------------------------------------------------------------------------
loc_F397:    ; xrefs: F399
F000:F397  AA              stosb  byte es:[di], al            ; write character code to video buffer
F000:F398  47              inc    di                          ; skip attribute byte (attribute unchanged)
F000:F399  E2FC            loop   loc_F397                    ; repeat CX times
F000:F39B  E917FE          jmp    int10_04_read_lightpen      ; exit INT 10h (common register-restore and IRET point)

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Dh — read pixel (CGA graphics modes 4–6).
; In: DX=row (0–199), CX=column; AH=video mode. Out: AL=pixel color.
; ----------------------------------------------------------------------------------------------
int10_0D_read_pixel:    ; xrefs: F05F
F000:F39E  E83100          call   sub_F3D2                    ; SI=byte offset, AH=pixel mask, CL=pixel shift, DH=bits per pixel
F000:F3A1  268A04          mov    al, byte es:[si]            ; read video memory byte containing the pixel
F000:F3A4  22C4            and    al, ah                      ; keep only the pixel's bits
F000:F3A6  D2E0            shl    al, cl                      ; shift pixel bits into the high-order bits of the byte
F000:F3A8  8ACE            mov    cl, dh                      ; CL = bits per pixel (2 for 320x200, 1 for 640x200)
F000:F3AA  D2C0            rol    al, cl                      ; rotate high bits into low bits → AL = color number
F000:F3AC  E906FE          jmp    int10_04_read_lightpen      ; exit INT 10h

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Ch — write pixel (CGA graphics modes 4–6).
; In: DX=row, CX=column, AL=color (bit 7 = XOR with current contents). AX preserved.
; ----------------------------------------------------------------------------------------------
int10_0C_write_pixel:    ; xrefs: F05D
F000:F3AF  50              push   ax                          ; save AX for restore on exit
F000:F3B0  50              push   ax                          ; copy of AX: AL=color and XOR flag (to be picked up in BX)
F000:F3B1  E81E00          call   sub_F3D2                    ; SI=byte offset, AH=pixel mask, CL=shift, AL=color in high bits
F000:F3B4  D2E8            shr    al, cl                      ; shift color code to the pixel's position in the byte
F000:F3B6  22C4            and    al, ah                      ; mask color with pixel mask
F000:F3B8  268A0C          mov    cl, byte es:[si]            ; CL = current video memory byte
F000:F3BB  5B              pop    bx                          ; BL = original AL (color with XOR flag)
F000:F3BC  F6C380          test   bl, 80h                     ; color bit 7 — XOR mode?
F000:F3BF  750D            jne    loc_F3CE                    ; yes → XOR overlay
F000:F3C1  F6D4            not    ah                          ; inverted mask — all other pixels of the byte
F000:F3C3  22CC            and    cl, ah                      ; clear bits of the replaced pixel in the old byte
F000:F3C5  0AC1            or     al, cl                      ; insert new pixel color

loc_F3C7:    ; xrefs: F3D0
F000:F3C7  268804          mov    byte es:[si], al            ; write byte back to video memory
F000:F3CA  58              pop    ax                          ; restore caller's AX
F000:F3CB  E9E7FD          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F3CE:    ; xrefs: F3BF
F000:F3CE  32C1            xor    al, cl                      ; XOR new color with byte contents (AL bit 7 was set)
F000:F3D0  EBF5            jmp    loc_F3C7                    ; go write the byte

; ----------------------------------------------------------------------------------------------
; sub_F3D2 — compute pixel address in CGA video RAM (rows interleaved across banks 0000h/2000h).
; Input: DX=row, CX=column, AL=color, DS=0040. Output: SI=byte offset, AH=pixel mask (in position),
; CL=pixel shift from the high bits, DH=bits per pixel (2 or 1), AL=color rotated into the high bits; BX preserved.
; ----------------------------------------------------------------------------------------------
sub_F3D2:    ; xrefs: F39E F3B1
F000:F3D2  53              push   bx                          ; save BX
F000:F3D3  50              push   ax                          ; save AX (color)
F000:F3D4  B028            mov    al, 28h                     ; 80 bytes per raster line: 28h × (even row number) = 80 × (row/2)
F000:F3D6  52              push   dx                          ; save DX (row number)
F000:F3D7  80E2FE          and    dl, 0FEh                    ; round row down to even (row pair across the two banks)
F000:F3DA  F6E2            mul    dl                          ; AX = 40 × (row & ~1) = 80 × (row div 2)
F000:F3DC  5A              pop    dx                          ; restore row number
F000:F3DD  F6C201          test   dl, 1                       ; odd row?
F000:F3E0  7403            je     loc_F3E5                    ; even → bank 0 (B800:0000)
F000:F3E2  050020          add    ax, 2000h                   ; odd row → bank 1 (B800:2000)

loc_F3E5:    ; xrefs: F3E0
F000:F3E5  8BF0            mov    si, ax                      ; SI = raster line start offset
F000:F3E7  58              pop    ax                          ; AL = color (restored)
F000:F3E8  8BD1            mov    dx, cx                      ; DX = column
F000:F3EA  BBC002          mov    bx, 2C0h                    ; 320x200 mode: BH=2 bits per pixel, BL=C0h mask of the byte's leftmost pixel
F000:F3ED  B90203          mov    cx, 302h                    ; CH=3 (pixel-in-byte mask, 4 pixels), CL=2 (column/4 = byte)
F000:F3F0  803E490006      cmp    byte [49h], 6               ; 0040:0049 — current video mode; 6 = 640x200
F000:F3F5  7206            jb     loc_F3FD                    ; modes 4/5 → 320x200 parameters
F000:F3F7  BB8001          mov    bx, 180h                    ; mode 6: BH=1 bit per pixel, BL=80h mask
F000:F3FA  B90307          mov    cx, 703h                    ; CH=7 (8 pixels per byte), CL=3 (column/8 = byte)

loc_F3FD:    ; xrefs: F3F5
F000:F3FD  22EA            and    ch, dl                      ; CH = pixel number within the byte
F000:F3FF  D3EA            shr    dx, cl                      ; DX = byte number within the raster line
F000:F401  03F2            add    si, dx                      ; SI = offset of the byte containing the pixel
F000:F403  8AF7            mov    dh, bh                      ; DH = bits per pixel (returned to caller)
F000:F405  2AC9            sub    cl, cl                      ; CL = 0 — shift accumulator

loc_F407:    ; xrefs: F40D
F000:F407  D0C8            ror    al, 1                       ; rotate color right — low color bits move to the high bits
F000:F409  02CD            add    cl, ch                      ; CL += pixel number (result: CL = pixel number × bits per pixel)
F000:F40B  FECF            dec    bh                          ; repeat "bits per pixel" times
F000:F40D  75F8            jne    loc_F407                    ; loop over pixel bits
F000:F40F  8AE3            mov    ah, bl                      ; AH = mask of the leftmost pixel (C0h or 80h)
F000:F411  D2EC            shr    ah, cl                      ; shift mask to the target pixel position
F000:F413  5B              pop    bx                          ; restore BX
F000:F414  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Scroll window up in graphics modes 4–6 (continuation of INT 10h AH=06h).
; In: AL→BL=line count (0 = clear window), CX=upper-left corner (CH=row, CL=column),
; DX=lower-right corner, BH=fill byte. Text row = 8 raster lines = 4 pairs (bank 0/bank 1), 80-byte stride.
; ----------------------------------------------------------------------------------------------
loc_F415:    ; xrefs: F27D
F000:F415  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F417  8BC1            mov    ax, cx                      ; AX = window upper-left corner (row/column in characters)
F000:F419  E86802          call   sub_F684                    ; AX = offset of upper-left character cell (row×columns×4 + column)
F000:F41C  8BF8            mov    di, ax                      ; DI = destination address (top of window)
F000:F41E  2BD1            sub    dx, cx                      ; DX = window size minus 1 (rows/columns)
F000:F420  81C20101        add    dx, 101h                    ; DH = window height in characters, DL = width in characters
F000:F424  D0E6            shl    dh, 1                       ; window height × 2 ...
F000:F426  D0E6            shl    dh, 1                       ; ... × 4 = number of raster line pairs in the window
F000:F428  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200 (1 byte per character cell)
F000:F42D  7304            jae    loc_F433                    ; mode 6 → width in bytes = width in characters
F000:F42F  D0E2            shl    dl, 1                       ; modes 4/5: character cell = 2 bytes → width in bytes ×2
F000:F431  D1E7            shl    di, 1                       ; and window start offset ×2

loc_F433:    ; xrefs: F42D
F000:F433  06              push   es                          ; DS = ES = B800 — copy within video memory
F000:F434  1F              pop    ds                          ; (DS = video memory segment)
F000:F435  2AED            sub    ch, ch                      ; CH = 0 — CX used as byte-per-line counter
F000:F437  D0E3            shl    bl, 1                       ; scroll line count × 4 ...
F000:F439  D0E3            shl    bl, 1                       ; ... = number of raster line pairs to shift
F000:F43B  742D            je     loc_F46A                    ; 0 → clear entire window
F000:F43D  8AC3            mov    al, bl                      ; AL = number of line pairs to shift
F000:F43F  B450            mov    ah, 50h                     ; 80 bytes per raster line in a bank
F000:F441  F6E4            mul    ah                          ; AX = source offset relative to destination
F000:F443  8BF7            mov    si, di                      ; SI = DI ...
F000:F445  03F0            add    si, ax                      ; ... + shift: source is BL rows below
F000:F447  8AE6            mov    ah, dh                      ; AH = window height in line pairs
F000:F449  2AE3            sub    ah, bl                      ; minus shift = number of line pairs to copy

; ----------------------------------------------------------------------------------------------
; Copy window raster lines up (one line pair from both banks per iteration).
; ----------------------------------------------------------------------------------------------
loc_F44B:    ; xrefs: F458
F000:F44B  E88000          call   sub_F4CE                    ; copy DL bytes in bank 0 and bank 1; SI/DI returned +2000h
F000:F44E  81EEB01F        sub    si, 1FB0h                   ; source: −2000h + 50h → next line of bank 0
F000:F452  81EFB01F        sub    di, 1FB0h                   ; destination: next line of bank 0
F000:F456  FECC            dec    ah                          ; line pair counter
F000:F458  75F1            jne    loc_F44B                    ; continue copying

; ----------------------------------------------------------------------------------------------
; Fill vacated bottom lines with byte BH.
; ----------------------------------------------------------------------------------------------
loc_F45A:    ; xrefs: F46C
F000:F45A  8AC7            mov    al, bh                      ; AL = fill byte (BH)

loc_F45C:    ; xrefs: F465
F000:F45C  E88800          call   sub_F4E7                    ; fill a raster line pair (bank 0 and bank 1)
F000:F45F  81EFB01F        sub    di, 1FB0h                   ; next line: −2000h + 50h
F000:F463  FECB            dec    bl                          ; counter of line pairs to fill
F000:F465  75F5            jne    loc_F45C                    ; continue filling
F000:F467  E94BFD          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F46A:    ; xrefs: F43B
F000:F46A  8ADE            mov    bl, dh                      ; BL=0: whole window cleared — number of pairs to fill = window height
F000:F46C  EBEC            jmp    loc_F45A                    ; go fill

; ----------------------------------------------------------------------------------------------
; Scroll window down in graphics modes 4–6 (continuation of INT 10h AH=07h).
; Input as for AH=06h. Works from the end of the window (lower-right corner, DF=1, backward copy).
; ----------------------------------------------------------------------------------------------
loc_F46E:    ; xrefs: F301
F000:F46E  FD              std                                ; DF=1: string instructions go toward lower addresses
F000:F46F  8AD8            mov    bl, al                      ; BL = scroll line count
F000:F471  8BC2            mov    ax, dx                      ; AX = window lower-right corner
F000:F473  E80E02          call   sub_F684                    ; AX = offset of lower-right character cell
F000:F476  8BF8            mov    di, ax                      ; DI = destination address (bottom of window)
F000:F478  2BD1            sub    dx, cx                      ; DX = window size minus 1
F000:F47A  81C20101        add    dx, 101h                    ; DH = window height, DL = width in characters
F000:F47E  D0E6            shl    dh, 1                       ; height × 2 ...
F000:F480  D0E6            shl    dh, 1                       ; ... × 4 = number of raster line pairs
F000:F482  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200?
F000:F487  7305            jae    loc_F48E                    ; mode 6 → 1 byte per character cell
F000:F489  D0E2            shl    dl, 1                       ; modes 4/5: width in bytes ×2
F000:F48B  D1E7            shl    di, 1                       ; offset ×2 (2 bytes per character cell)
F000:F48D  47              inc    di                          ; +1 → right byte of the character cell (copying goes right to left)

loc_F48E:    ; xrefs: F487
F000:F48E  06              push   es                          ; DS = ES = B800
F000:F48F  1F              pop    ds                          ; (DS = video memory segment)
F000:F490  2AED            sub    ch, ch                      ; CH = 0 for counter CX
F000:F492  81C7F000        add    di, 0F0h                    ; +F0h = 3×80: last (4th) raster line pair of the character cell
F000:F496  D0E3            shl    bl, 1                       ; scroll line count × 4 ...
F000:F498  D0E3            shl    bl, 1                       ; ... = raster line pairs; 0 → clear window
F000:F49A  742E            je     loc_F4CA                    ; BL=0 → clear entire window
F000:F49C  8AC3            mov    al, bl                      ; AL = number of line pairs to shift
F000:F49E  B450            mov    ah, 50h                     ; 80 bytes per raster line
F000:F4A0  F6E4            mul    ah                          ; AX = source offset
F000:F4A2  8BF7            mov    si, di                      ; SI = DI ...
F000:F4A4  2BF0            sub    si, ax                      ; ... − shift: source is BL rows above
F000:F4A6  8AE6            mov    ah, dh                      ; AH = window height in line pairs
F000:F4A8  2AE3            sub    ah, bl                      ; minus shift = number of line pairs to copy

loc_F4AA:    ; xrefs: F4B7
F000:F4AA  E82100          call   sub_F4CE                    ; copy a line pair (bank 0 and bank 1) backward; SI/DI returned +2000h
F000:F4AD  81EE5020        sub    si, 2050h                   ; source: −2000h − 50h → previous line of bank 0
F000:F4B1  81EF5020        sub    di, 2050h                   ; destination: previous line of bank 0
F000:F4B5  FECC            dec    ah                          ; line pair counter
F000:F4B7  75F1            jne    loc_F4AA                    ; continue copying

loc_F4B9:    ; xrefs: F4CC
F000:F4B9  8AC7            mov    al, bh                      ; AL = fill byte (BH)

loc_F4BB:    ; xrefs: F4C4
F000:F4BB  E82900          call   sub_F4E7                    ; fill a raster line pair at the top of the window
F000:F4BE  81EF5020        sub    di, 2050h                   ; previous line: −2000h − 50h
F000:F4C2  FECB            dec    bl                          ; counter of line pairs to fill
F000:F4C4  75F5            jne    loc_F4BB                    ; continue filling
F000:F4C6  FC              cld                                ; restore DF=0
F000:F4C7  E9EBFC          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F4CA:    ; xrefs: F49A
F000:F4CA  8ADE            mov    bl, dh                      ; BL=0: entire window is filled
F000:F4CC  EBEB            jmp    loc_F4B9                    ; go fill

; ----------------------------------------------------------------------------------------------
; sub_F4CE — copy one window row in both CGA banks.
; Input: DS:SI → ES:DI, DL=length in bytes, CH=0, DF sets direction. Output: SI, DI advanced by 2000h (bank 1).
; ----------------------------------------------------------------------------------------------
sub_F4CE:    ; xrefs: F44B F4AA
F000:F4CE  8ACA            mov    cl, dl                      ; CX = window line length in bytes
F000:F4D0  56              push   si                          ; save source
F000:F4D1  57              push   di                          ; save destination
F000:F4D2  F3A4            rep movsb byte es:[di], byte [si]  ; copy bank 0 line (even raster lines)
F000:F4D4  5F              pop    di                          ; restore destination
F000:F4D5  5E              pop    si                          ; restore source
F000:F4D6  81C60020        add    si, 2000h                   ; source → same area in bank 1 (odd lines)
F000:F4DA  81C70020        add    di, 2000h                   ; destination → bank 1
F000:F4DE  56              push   si                          ; save source in bank 1
F000:F4DF  57              push   di                          ; save destination in bank 1
F000:F4E0  8ACA            mov    cl, dl                      ; CX = line length
F000:F4E2  F3A4            rep movsb byte es:[di], byte [si]  ; copy bank 1 line
F000:F4E4  5F              pop    di                          ; DI = line start in bank 1
F000:F4E5  5E              pop    si                          ; SI = line start in bank 1
F000:F4E6  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F4E7 — fill one window row with byte AL in both CGA banks.
; Input: ES:DI, DL=length, CH=0. Output: DI advanced by 2000h.
; ----------------------------------------------------------------------------------------------
sub_F4E7:    ; xrefs: F45C F4BB
F000:F4E7  8ACA            mov    cl, dl                      ; CX = line length in bytes
F000:F4E9  57              push   di                          ; save address
F000:F4EA  F3AA            rep stosb byte es:[di], al         ; fill bank 0 line
F000:F4EC  5F              pop    di                          ; restore address
F000:F4ED  81C70020        add    di, 2000h                   ; switch to bank 1
F000:F4F1  57              push   di                          ; save address in bank 1
F000:F4F2  8ACA            mov    cl, dl                      ; CX = length
F000:F4F4  F3AA            rep stosb byte es:[di], al         ; fill bank 1 line
F000:F4F6  5F              pop    di                          ; DI = line start in bank 1
F000:F4F7  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; Character output in graphics modes 4–6 (INT 10h AH=09h/0Ah for graphics).
; In: AL=character code, BL=color (bit 7 = XOR), CX=repeat count; position — page 0 cursor (0040:0050).
; Glyphs 00–7Fh come from ROM F000:FA6E, 80–FFh via the INT 1Fh vector (0000:007C), as in the IBM PC.
; ----------------------------------------------------------------------------------------------
loc_F4F8:    ; xrefs: F36D F38B
F000:F4F8  B400            mov    ah, 0                       ; AX = character code (AH cleared)
F000:F4FA  50              push   ax                          ; save character code
F000:F4FB  E88301          call   sub_F681                    ; AX = cursor character cell offset (page 0)
F000:F4FE  8BF8            mov    di, ax                      ; DI = character cell address in video memory
F000:F500  58              pop    ax                          ; restore character code
F000:F501  3C80            cmp    al, 80h                     ; character from upper half (80–FFh)?
F000:F503  7306            jae    loc_F50B                    ; yes → font via INT 1Fh vector
F000:F505  BE6EFA          mov    si, 0FA6Eh                  ; SI = F000:FA6E — 8x8 font for characters 00–7Fh in ROM
F000:F508  0E              push   cs                          ; font segment = CS (F000) — pushed for later pop ds
F000:F509  EB0F            jmp    loc_F51A                    ; go compute glyph address

loc_F50B:    ; xrefs: F503
F000:F50B  2C80            sub    al, 80h                     ; index into upper-half font table
F000:F50D  1E              push   ds                          ; save DS (0040)
F000:F50E  2BF6            sub    si, si                      ; SI = 0 ...
F000:F510  8EDE            mov    ds, si                      ; ... DS = 0 — interrupt vector table
F000:F512  C5367C00        lds    si, [7Ch]                   ; DS:SI = INT 1Fh vector (0000:007C) — glyph table 80–FFh (BIOS sets F400:1C00)
F000:F516  8CDA            mov    dx, ds                      ; DX = glyph table segment
F000:F518  1F              pop    ds                          ; restore DS = 0040
F000:F519  52              push   dx                          ; font segment pushed for later pop ds

loc_F51A:    ; xrefs: F509
F000:F51A  D1E0            shl    ax, 1                       ; code × 2 ...
F000:F51C  D1E0            shl    ax, 1                       ; ... × 4 ...
F000:F51E  D1E0            shl    ax, 1                       ; ... × 8 = glyph offset (8 bytes per character)
F000:F520  03F0            add    si, ax                      ; SI → character glyph
F000:F522  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200 (1 bit per pixel)
F000:F527  1F              pop    ds                          ; DS = font segment (compare flags preserved)
F000:F528  722C            jb     loc_F556                    ; modes 4/5 → output with 2 bits per pixel

; ----------------------------------------------------------------------------------------------
; Mode 6 (640x200): each glyph row is one byte; even rows in bank 0, odd rows in bank 1.
; ----------------------------------------------------------------------------------------------
loc_F52A:    ; xrefs: F545
F000:F52A  57              push   di                          ; save character cell address
F000:F52B  56              push   si                          ; save glyph address
F000:F52C  B604            mov    dh, 4                       ; DH = 4 glyph row pairs (8 rows)

loc_F52E:    ; xrefs: F540
F000:F52E  AC              lodsb  al, byte [si]               ; AL = even glyph row
F000:F52F  F6C380          test   bl, 80h                     ; color bit 7 — XOR mode?
F000:F532  7516            jne    loc_F54A                    ; yes → XOR overlay
F000:F534  AA              stosb  byte es:[di], al            ; write row to bank 0, DI+1
F000:F535  AC              lodsb  al, byte [si]               ; AL = odd glyph row

loc_F536:    ; xrefs: F554
F000:F536  268885FF1F      mov    byte es:[di + 1FFFh], al    ; write to bank 1 at the same offset (DI already +1, hence 1FFFh)
F000:F53B  83C74F          add    di, 4Fh                     ; +4Fh (with +1 from STOSB = 50h) → next bank line
F000:F53E  FECE            dec    dh                          ; line pair counter
F000:F540  75EC            jne    loc_F52E                    ; next glyph row pair
F000:F542  5E              pop    si                          ; SI = glyph start (for repeat)
F000:F543  5F              pop    di                          ; DI = current character cell address
F000:F544  47              inc    di                          ; next character cell (1 byte in mode 6)
F000:F545  E2E3            loop   loc_F52A                    ; repeat character CX times
F000:F547  E96BFC          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F54A:    ; xrefs: F532
F000:F54A  263205          xor    al, byte es:[di]            ; XOR glyph row with screen (bank 0)
F000:F54D  AA              stosb  byte es:[di], al            ; write, DI+1
F000:F54E  AC              lodsb  al, byte [si]               ; next glyph row
F000:F54F  263285FF1F      xor    al, byte es:[di + 1FFFh]    ; XOR with screen in bank 1
F000:F554  EBE0            jmp    loc_F536                    ; go write to bank 1

; ----------------------------------------------------------------------------------------------
; Modes 4/5 (320x200, 4 colors): each glyph bit is doubled into a 2-bit pixel,
; glyph row = word (2 bytes), colored with BL&3.
; ----------------------------------------------------------------------------------------------
loc_F556:    ; xrefs: F528
F000:F556  8AD3            mov    dl, bl                      ; DL = color with XOR flag (bit 7)
F000:F558  D1E7            shl    di, 1                       ; offset ×2 — 2 bytes per character cell
F000:F55A  E8D000          call   sub_F62D                    ; BX = color (0–3) replicated to all 8 pixel positions of the word

loc_F55D:    ; xrefs: F5A4
F000:F55D  57              push   di                          ; save character cell address
F000:F55E  56              push   si                          ; save glyph address
F000:F55F  B604            mov    dh, 4                       ; DH = 4 glyph row pairs

loc_F561:    ; xrefs: F59E
F000:F561  AC              lodsb  al, byte [si]               ; AL = even glyph row
F000:F562  E8DD00          call   sub_F642                    ; AX = row expanded to 2 bits per pixel
F000:F565  23C3            and    ax, bx                      ; color the pixels
F000:F567  F6C280          test   dl, 80h                     ; XOR mode?
F000:F56A  7407            je     loc_F573                    ; no → direct write
F000:F56C  263225          xor    ah, byte es:[di]            ; XOR high (left) byte with screen
F000:F56F  26324501        xor    al, byte es:[di + 1]        ; XOR low (right) byte with screen

loc_F573:    ; xrefs: F56A
F000:F573  268825          mov    byte es:[di], ah            ; left 4 pixels → bank 0
F000:F576  26884501        mov    byte es:[di + 1], al        ; right 4 pixels → bank 0
F000:F57A  AC              lodsb  al, byte [si]               ; AL = odd glyph row
F000:F57B  E8C400          call   sub_F642                    ; expand to 2 bits per pixel
F000:F57E  23C3            and    ax, bx                      ; apply color
F000:F580  F6C280          test   dl, 80h                     ; XOR mode?
F000:F583  740A            je     loc_F58F                    ; no → direct write
F000:F585  2632A50020      xor    ah, byte es:[di + 2000h]    ; XOR left byte with screen in bank 1
F000:F58A  2632850120      xor    al, byte es:[di + 2001h]    ; XOR right byte with screen in bank 1

loc_F58F:    ; xrefs: F583
F000:F58F  2688A50020      mov    byte es:[di + 2000h], ah    ; left 4 pixels → bank 1
F000:F594  2688850120      mov    byte es:[di + 2001h], al    ; right 4 pixels → bank 1
F000:F599  83C750          add    di, 50h                     ; next bank line (80 bytes)
F000:F59C  FECE            dec    dh                          ; line pair counter
F000:F59E  75C1            jne    loc_F561                    ; next glyph row pair
F000:F5A0  5E              pop    si                          ; SI = glyph start
F000:F5A1  5F              pop    di                          ; DI = character cell address
F000:F5A2  47              inc    di                          ; next character cell ...
F000:F5A3  47              inc    di                          ; ... (2 bytes)
F000:F5A4  E2B7            loop   loc_F55D                    ; repeat character CX times
F000:F5A6  E90CFC          jmp    int10_04_read_lightpen      ; exit INT 10h

; ----------------------------------------------------------------------------------------------
; Read character in graphics modes 4–6 (continuation of INT 10h AH=08h).
; The cell image under the cursor (page 0) is gathered into an 8-byte stack buffer (pixel ≠ background → bit 1)
; and compared with glyphs at F000:FA6E, then with the INT 1Fh table. Out: AL=character code (0 — not found).
; ----------------------------------------------------------------------------------------------
loc_F5A9:    ; xrefs: F33A
F000:F5A9  E8D500          call   sub_F681                    ; AX = cursor character cell offset (page 0)
F000:F5AC  8BF0            mov    si, ax                      ; SI = character cell address
F000:F5AE  83EC08          sub    sp, 8                       ; 8-byte stack buffer for the character image
F000:F5B1  8BEC            mov    bp, sp                      ; BP → buffer (addressed via SS)
F000:F5B3  803E490006      cmp    byte [49h], 6               ; 0040:0049 — video mode: 6 = 640x200?
F000:F5B8  06              push   es                          ; DS = B800 ...
F000:F5B9  1F              pop    ds                          ; ... video memory
F000:F5BA  721A            jb     loc_F5D6                    ; modes 4/5 → pack 2-bit pixels
F000:F5BC  B604            mov    dh, 4                       ; mode 6: 4 line pairs

loc_F5BE:    ; xrefs: F5D1
F000:F5BE  8A04            mov    al, byte [si]               ; line from bank 0
F000:F5C0  884600          mov    byte [bp], al               ; to buffer
F000:F5C3  45              inc    bp                          ; next buffer byte
F000:F5C4  8A840020        mov    al, byte [si + 2000h]       ; line from bank 1
F000:F5C8  884600          mov    byte [bp], al               ; to buffer
F000:F5CB  45              inc    bp                          ; next buffer byte
F000:F5CC  83C650          add    si, 50h                     ; next bank line (80 bytes)
F000:F5CF  FECE            dec    dh                          ; line pair counter
F000:F5D1  75EB            jne    loc_F5BE                    ; continue gathering the image
F000:F5D3  EB17            jmp    loc_F5EC                    ; go search for the glyph
F000:F5D5  90              db     90h                         ; filler (NOP) after short jump

loc_F5D6:    ; xrefs: F5BA
F000:F5D6  D1E6            shl    si, 1                       ; modes 4/5: 2 bytes per character cell → offset ×2
F000:F5D8  B604            mov    dh, 4                       ; 4 line pairs

loc_F5DA:    ; xrefs: F5EA
F000:F5DA  E88700          call   sub_F664                    ; pack bank 0 line (2 bytes → 8 bits) into buffer
F000:F5DD  81C60020        add    si, 2000h                   ; switch to bank 1
F000:F5E1  E88000          call   sub_F664                    ; pack bank 1 line into buffer
F000:F5E4  81EEB01F        sub    si, 1FB0h                   ; −2000h + 50h → next line of bank 0
F000:F5E8  FECE            dec    dh                          ; line pair counter
F000:F5EA  75EE            jne    loc_F5DA                    ; continue gathering the image

; ----------------------------------------------------------------------------------------------
; Search for the gathered image in the font tables: first 128 ROM glyphs, then 128 via the INT 1Fh vector.
; ----------------------------------------------------------------------------------------------
loc_F5EC:    ; xrefs: F5D3
F000:F5EC  BF6EFA          mov    di, 0FA6Eh                  ; DI = F000:FA6E — font for characters 00–7Fh
F000:F5EF  0E              push   cs                          ; ES = CS = F000 ...
F000:F5F0  07              pop    es                          ; ... font segment
F000:F5F1  83ED08          sub    bp, 8                       ; BP → start of image buffer
F000:F5F4  8BF5            mov    si, bp                      ; SI = buffer
F000:F5F6  FC              cld                                ; compare toward increasing addresses
F000:F5F7  B000            mov    al, 0                       ; AL = 0 — code of the first character checked

loc_F5F9:    ; xrefs: F625
F000:F5F9  16              push   ss                          ; DS = SS ...
F000:F5FA  1F              pop    ds                          ; ... image buffer on the stack
F000:F5FB  BA8000          mov    dx, 80h                     ; 128 glyphs in the table

loc_F5FE:    ; xrefs: F60F
F000:F5FE  56              push   si                          ; save image address
F000:F5FF  57              push   di                          ; save glyph address
F000:F600  B90800          mov    cx, 8                       ; 8 glyph bytes
F000:F603  F3A6            repe cmpsb byte [si], byte es:[di] ; compare image with glyph
F000:F605  5F              pop    di                          ; restore glyph address
F000:F606  5E              pop    si                          ; restore image address
F000:F607  741E            je     loc_F627                    ; match → AL = character code
F000:F609  FEC0            inc    al                          ; next character code
F000:F60B  83C708          add    di, 8                       ; next glyph
F000:F60E  4A              dec    dx                          ; table glyph counter
F000:F60F  75ED            jne    loc_F5FE                    ; continue searching
F000:F611  3C00            cmp    al, 0                       ; AL=0 after second table (80h+80h overflow) → not found
F000:F613  7412            je     loc_F627                    ; not found → exit with AL=0
F000:F615  2BC0            sub    ax, ax                      ; AX = 0 ...
F000:F617  8ED8            mov    ds, ax                      ; ... DS = 0 — vector table
F000:F619  C43E7C00        les    di, [7Ch]                   ; ES:DI = INT 1Fh vector (0000:007C) — glyph table 80–FFh
F000:F61D  8CC0            mov    ax, es                      ; vector zero?
F000:F61F  0BC7            or     ax, di                      ; (segment OR offset)
F000:F621  7404            je     loc_F627                    ; no table → exit (AL=80h, same as IBM BIOS)
F000:F623  B080            mov    al, 80h                     ; AL = 80h — first upper-half code
F000:F625  EBD2            jmp    loc_F5F9                    ; search the second table

loc_F627:    ; xrefs: F607 F613 F621
F000:F627  83C408          add    sp, 8                       ; release image buffer on the stack
F000:F62A  E988FB          jmp    int10_04_read_lightpen      ; exit INT 10h (AL = code found)

; ----------------------------------------------------------------------------------------------
; sub_F62D — replicate color across all pixels of a byte (320x200 mode).
; Input: BL=color (bits 0–1). Output: BL=BH=color repeated 4 times (e.g. 2 → AAh). CX preserved.
; ----------------------------------------------------------------------------------------------
sub_F62D:    ; xrefs: F55A
F000:F62D  80E303          and    bl, 3                       ; keep color number 0–3
F000:F630  8AC3            mov    al, bl                      ; AL = color
F000:F632  51              push   cx                          ; save CX (character repeat count)
F000:F633  B90300          mov    cx, 3                       ; 3 more copies of the color

loc_F636:    ; xrefs: F63C
F000:F636  D0E0            shl    al, 1                       ; shift color to the next pixel position ...
F000:F638  D0E0            shl    al, 1                       ; ... (2 bits)
F000:F63A  0AD8            or     bl, al                      ; add a copy of the color
F000:F63C  E2F8            loop   loc_F636                    ; loop over 3 pixels
F000:F63E  8AFB            mov    bh, bl                      ; BH = BL → color mask for a word (8 pixels)
F000:F640  59              pop    cx                          ; restore CX
F000:F641  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F642 — "stretch" a glyph byte: each bit of AL is doubled (bit k → bits 2k and 2k+1).
; Input: AL=glyph row. Output: AX=16-bit mask for 8 pixels of 2 bits. BX, CX, DX preserved.
; ----------------------------------------------------------------------------------------------
sub_F642:    ; xrefs: F562 F57B
F000:F642  52              push   dx                          ; save DX
F000:F643  51              push   cx                          ; save CX
F000:F644  53              push   bx                          ; save BX
F000:F645  2BD2            sub    dx, dx                      ; DX = 0 — result accumulator
F000:F647  B90100          mov    cx, 1                       ; CX = mask of the current result bit (starting with bit 0)

loc_F64A:    ; xrefs: F65C
F000:F64A  8BD8            mov    bx, ax                      ; BX = source bit k shifted to position 2k
F000:F64C  23D9            and    bx, cx                      ; (isolate it with the mask)
F000:F64E  0BD3            or     dx, bx                      ; add to result
F000:F650  D1E0            shl    ax, 1                       ; shift source value by 1 bit
F000:F652  D1E1            shl    cx, 1                       ; mask → position 2k+1
F000:F654  8BD8            mov    bx, ax                      ; same bit k, now at position 2k+1
F000:F656  23D9            and    bx, cx                      ; (isolate with mask)
F000:F658  0BD3            or     dx, bx                      ; add to result
F000:F65A  D1E1            shl    cx, 1                       ; mask → position 2(k+1)
F000:F65C  73EC            jae    loc_F64A                    ; until the mask goes past 16 bits (8 iterations)
F000:F65E  8BC2            mov    ax, dx                      ; AX = stretched row
F000:F660  5B              pop    bx                          ; restore BX
F000:F661  59              pop    cx                          ; restore CX
F000:F662  5A              pop    dx                          ; restore DX
F000:F663  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F664 — pack 8 2-bit pixels (2 video RAM bytes) into an 8-bit row image.
; Input: DS:SI → two bytes, SS:BP → buffer. A non-zero pixel yields bit 1. Output: byte at [BP], BP+1.
; ----------------------------------------------------------------------------------------------
sub_F664:    ; xrefs: F5DA F5E1
F000:F664  8A24            mov    ah, byte [si]               ; AH = left 4 pixels
F000:F666  8A4401          mov    al, byte [si + 1]           ; AL = right 4 pixels
F000:F669  B900C0          mov    cx, 0C000h                  ; CX = mask of the first (leftmost) pixel
F000:F66C  B200            mov    dl, 0                       ; DL = image bit accumulator

loc_F66E:    ; xrefs: F67A
F000:F66E  85C1            test   cx, ax                      ; non-zero color pixel?
F000:F670  F8              clc                                ; CF=0 — background pixel
F000:F671  7401            je     loc_F674                    ; background → bit 0
F000:F673  F9              stc                                ; CF=1 — foreground pixel

loc_F674:    ; xrefs: F671
F000:F674  D0D2            rcl    dl, 1                       ; shift bit into the image
F000:F676  D1E9            shr    cx, 1                       ; mask → next pixel ...
F000:F678  D1E9            shr    cx, 1                       ; ... (shift by 2 bits); CF=1 when the mask falls off
F000:F67A  73F2            jae    loc_F66E                    ; loop over 8 pixels
F000:F67C  885600          mov    byte [bp], dl               ; store image byte in buffer (SS segment)
F000:F67F  45              inc    bp                          ; next buffer byte
F000:F680  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F681 / sub_F684 — character cell offset in graphics video RAM (bank 0).
; sub_F685: position taken from 0040:0050 (page 0 cursor). sub_F688: AX=position (AH=row, AL=column).
; Output: AX = row × columns(0040:004A) × 4 + column (for 320x200 the caller multiplies by 2 again).
; ----------------------------------------------------------------------------------------------
sub_F681:    ; xrefs: F4FB F5A9
F000:F681  A15000          mov    ax, word [50h]              ; AX = 0040:0050 — page 0 cursor position (AH=row, AL=column)

sub_F684:    ; xrefs: F419 F473
F000:F684  53              push   bx                          ; save BX
F000:F685  8BD8            mov    bx, ax                      ; BX = position (BL = column)
F000:F687  8AC4            mov    al, ah                      ; AL = row
F000:F689  F6264A00        mul    byte [4Ah]                  ; × 0040:004A (number of screen columns)
F000:F68D  D1E0            shl    ax, 1                       ; ×4 — 4 lines of 80 bytes per bank per character cell ...
F000:F68F  D1E0            shl    ax, 1                       ; ... (i.e. 8 raster lines)
F000:F691  2AFF            sub    bh, bh                      ; BX = column
F000:F693  03C3            add    ax, bx                      ; + column
F000:F695  5B              pop    bx                          ; restore BX
F000:F696  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; INT 10h, AH=0Eh — teletype character output.
; In: AL=character, BL=color (graphics). Handles BS(08), CR(0D), LF(0A), BEL(07); on the active page 0040:0062.
; When moving past the last row (24) scrolls the screen up (AH=06h) using the attribute of the character under the cursor.
; ----------------------------------------------------------------------------------------------
int10_0E_write_tty:    ; xrefs: F061
F000:F697  50              push   ax                          ; save AX for exit
F000:F698  50              push   ax                          ; save character
F000:F699  B403            mov    ah, 3                       ; function 03h — read cursor position
F000:F69B  8A3E6200        mov    bh, byte [62h]              ; BH = 0040:0062 — active video page
F000:F69F  CD10            int    10h                         ; DX = cursor position (DH=row, DL=column)
F000:F6A1  58              pop    ax                          ; AL = character
F000:F6A2  3C08            cmp    al, 8                       ; BS (backspace)?
F000:F6A4  7452            je     loc_F6F8                    ; → cursor left
F000:F6A6  3C0D            cmp    al, 0Dh                     ; CR (carriage return)?
F000:F6A8  7457            je     loc_F701                    ; → to start of line
F000:F6AA  3C0A            cmp    al, 0Ah                     ; LF (line feed)?
F000:F6AC  7457            je     loc_F705                    ; → one line down
F000:F6AE  3C07            cmp    al, 7                       ; BEL (bell)?
F000:F6B0  745A            je     loc_F70C                    ; → beep
F000:F6B2  B40A            mov    ah, 0Ah                     ; function 0Ah — write character at cursor position
F000:F6B4  B90100          mov    cx, 1                       ; one character
F000:F6B7  CD10            int    10h                         ; output character (BL = color in graphics)
F000:F6B9  FEC2            inc    dl                          ; cursor right
F000:F6BB  3A164A00        cmp    dl, byte [4Ah]              ; reached end of line (0040:004A — number of columns)?
F000:F6BF  7533            jne    loc_F6F4                    ; no → set cursor
F000:F6C1  B200            mov    dl, 0                       ; wrap: column 0
F000:F6C3  80FE18          cmp    dh, 18h                     ; last screen row (24)?
F000:F6C6  752A            jne    loc_F6F2                    ; no → next row

; ----------------------------------------------------------------------------------------------
; Scroll the screen up one line (cursor on row 24).
; ----------------------------------------------------------------------------------------------
loc_F6C8:    ; xrefs: F70A
F000:F6C8  B402            mov    ah, 2                       ; function 02h — set cursor
F000:F6CA  CD10            int    10h                         ; set cursor (row 24)
F000:F6CC  A04900          mov    al, byte [49h]              ; AL = 0040:0049 — current video mode
F000:F6CF  3C04            cmp    al, 4                       ; text modes 0–3?
F000:F6D1  7206            jb     loc_F6D9                    ; yes → take attribute of the character under the cursor
F000:F6D3  3C07            cmp    al, 7                       ; mode 7 (mono text)?
F000:F6D5  B700            mov    bh, 0                       ; graphics: fill with zero (background)
F000:F6D7  7506            jne    loc_F6DF                    ; graphics (4–6) → scroll right away

loc_F6D9:    ; xrefs: F6D1
F000:F6D9  B408            mov    ah, 8                       ; function 08h — read character/attribute under cursor
F000:F6DB  CD10            int    10h                         ; AH = attribute
F000:F6DD  8AFC            mov    bh, ah                      ; BH = attribute for filling the new line

loc_F6DF:    ; xrefs: F6D7
F000:F6DF  B80106          mov    ax, 601h                    ; function 06h — scroll up 1 line
F000:F6E2  2BC9            sub    cx, cx                      ; window from (0,0)
F000:F6E4  B618            mov    dh, 18h                     ; to row 24 ...
F000:F6E6  8A164A00        mov    dl, byte [4Ah]              ; ... and the last column (0040:004A − 1)
F000:F6EA  FECA            dec    dl                          ; (columns − 1)

loc_F6EC:    ; xrefs: F6F6
F000:F6EC  CD10            int    10h                         ; call INT 10h (scroll or set cursor AH=02h)

loc_F6EE:    ; xrefs: F711
F000:F6EE  58              pop    ax                          ; restore AX
F000:F6EF  E9C3FA          jmp    int10_04_read_lightpen      ; exit INT 10h

loc_F6F2:    ; xrefs: F6C6 F708
F000:F6F2  FEC6            inc    dh                          ; next row

loc_F6F4:    ; xrefs: F6BF F6FB F6FF F703
F000:F6F4  B402            mov    ah, 2                       ; function 02h — set cursor to DX
F000:F6F6  EBF4            jmp    loc_F6EC                    ; call INT 10h and exit

loc_F6F8:    ; xrefs: F6A4
F000:F6F8  80FA00          cmp    dl, 0                       ; BS: cursor already at column 0?
F000:F6FB  74F7            je     loc_F6F4                    ; yes → leave in place
F000:F6FD  FECA            dec    dl                          ; cursor one column left
F000:F6FF  EBF3            jmp    loc_F6F4                    ; set cursor

loc_F701:    ; xrefs: F6A8
F000:F701  B200            mov    dl, 0                       ; CR: column 0
F000:F703  EBEF            jmp    loc_F6F4                    ; set cursor

loc_F705:    ; xrefs: F6AC
F000:F705  80FE18          cmp    dh, 18h                     ; LF: last row (24)?
F000:F708  75E8            jne    loc_F6F2                    ; no → next row
F000:F70A  EBBC            jmp    loc_F6C8                    ; yes → scroll screen

loc_F70C:    ; xrefs: F6B0
F000:F70C  B302            mov    bl, 2                       ; BEL: beep duration 2 (×64K cycles)
F000:F70E  E82900          call   sub_F73A                    ; beep: sub_F73A (BEEP, duration BL)
F000:F711  EBDB            jmp    loc_F6EE                    ; exit

; ----------------------------------------------------------------------------------------------
; sub_F713 — POST error/result beep signaling (counterpart of IBM ERR_BEEP).
; Input: DH=number of long beeps, DL=number of short ones. Called from POST (E42F, DX=1 — one short beep).
; Sound via sub_F73A (8253 channel 2 + port 61h, all through NMI port emulation). Flags and DS preserved.
; ----------------------------------------------------------------------------------------------
sub_F713:    ; xrefs: E42F
F000:F713  9C              pushf                              ; save flags (IF)
F000:F714  FA              cli                                ; disable interrupts while beeping
F000:F715  1E              push   ds                          ; save DS
F000:F716  E8D007          call   sub_FEE9                    ; DS = 0040 — BIOS data area
F000:F719  0AF6            or     dh, dh                      ; any long beeps?
F000:F71B  740B            je     loc_F728                    ; no → short ones

loc_F71D:    ; xrefs: F726
F000:F71D  B306            mov    bl, 6                       ; long beep duration = 6
F000:F71F  E81800          call   sub_F73A                    ; long beep (sub_F73A); CX=0 on exit

loc_F722:    ; xrefs: F722
F000:F722  E2FE            loop   loc_F722                    ; 64K-iteration pause between beeps
F000:F724  FECE            dec    dh                          ; long beep counter
F000:F726  75F5            jne    loc_F71D                    ; next long beep

loc_F728:    ; xrefs: F71B F731
F000:F728  B301            mov    bl, 1                       ; short beep duration = 1
F000:F72A  E80D00          call   sub_F73A                    ; short beep (sub_F73A)

loc_F72D:    ; xrefs: F72D
F000:F72D  E2FE            loop   loc_F72D                    ; 64K-iteration pause
F000:F72F  FECA            dec    dl                          ; short beep counter
F000:F731  75F5            jne    loc_F728                    ; next short beep

loc_F733:    ; xrefs: F733
F000:F733  E2FE            loop   loc_F733                    ; extra pause after the series ...

loc_F735:    ; xrefs: F735
F000:F735  E2FE            loop   loc_F735                    ; ... another 64K iterations
F000:F737  1F              pop    ds                          ; restore DS
F000:F738  9D              popf                               ; restore flags
F000:F739  C3              ret                                ; return from sub_F713

; ----------------------------------------------------------------------------------------------
; sub_F73A — BEEP (like IBM BEEP): 8253 channel 2 in mode 3 with divisor 0533h, speaker enabled by bits 0–1
; of port 61h for BL×65536 iterations, then 61h restored. All accesses via IN/OUT (42h/43h/61h emulated through NMI).
; Input: BL = duration. Clobbers AX, BL; CX=0 on exit. In my the same code moved to F400:0C2D (beep).
; ----------------------------------------------------------------------------------------------
sub_F73A:    ; xrefs: F70E F71F F72A
F000:F73A  B0B6            mov    al, 0B6h                    ; AL = B6h: channel 2, low+high byte, mode 3 (square wave), binary count
F000:F73C  E643            out    43h, al                     ; OUT 43h → nmi_port_043 → real 8253 control register (F000:0A06)
F000:F73E  B83305          mov    ax, 533h                    ; AX = 0533h (1331) — divisor ≈ 896 Hz at 1.19 MHz; the emulator rescales for ~1 MHz
F000:F741  E642            out    42h, al                     ; OUT 42h: low byte (emulator accumulates bytes in 0040:00B0)
F000:F743  8AC4            mov    al, ah                      ; AL = divisor high byte
F000:F745  E642            out    42h, al                     ; OUT 42h: high byte → rescale and load channel 2 (F000:0A04)
F000:F747  E461            in     al, 61h                     ; IN 61h → nmi_port_061: 8255 port B (bit 6 converted to IBM logic)
F000:F749  8AE0            mov    ah, al                      ; AH = original port 61h value
F000:F74B  0C03            or     al, 3                       ; Bit 0 — GATE2 (count enable), bit 1 — speaker data
F000:F74D  E661            out    61h, al                     ; OUT 61h: sound on
F000:F74F  2BC9            sub    cx, cx                      ; CX = 0 — 65536 inner loop iterations

loc_F751:    ; xrefs: F751 F755
F000:F751  E2FE            loop   loc_F751                    ; Sound duration delay
F000:F753  FECB            dec    bl                          ; Outer duration counter BL
F000:F755  75FA            jne    loc_F751                    ; Another 64K iterations
F000:F757  8AC4            mov    al, ah                      ; AL = original port 61h value
F000:F759  E661            out    61h, al                     ; OUT 61h: sound off
F000:F75B  C3              ret                                ; return

; ----------------------------------------------------------------------------------------------
; sub_F75C — program DMA (8237) channel 2 for floppy transfers (INT 13h).
; Input: AL=DMA mode (46h read, 4Ah write/format, 42h verify), ES:BX=buffer, DH=sector count.
; Writes to ports 0Ch/0Bh/04h/81h/05h/0Ah are trapped by NMI and emulated (see context.md).
; Continues at F000:FF3D. Output: CF=1 if the buffer crosses a 64 KB boundary, AX = end address.
; ----------------------------------------------------------------------------------------------
sub_F75C:    ; xrefs: ED3E ED47 ED59
F000:F75C  51              push   cx                          ; save CX
F000:F75D  E60C            out    0Ch, al                     ; port 0Ch — clear 8237 byte flip-flop (value irrelevant)
F000:F75F  E60B            out    0Bh, al                     ; port 0Bh — 8237 mode register: channel 2 mode (AL)
F000:F761  8CC0            mov    ax, es                      ; AX = buffer segment ES
F000:F763  B104            mov    cl, 4                       ; 4 bits
F000:F765  D3C0            rol    ax, cl                      ; rotate: segment high nibble → bits 0–3 (page number)
F000:F767  8AE8            mov    ch, al                      ; CH = bits 16–19 of the physical address (page)
F000:F769  24F0            and    al, 0F0h                    ; AL = low part of segment ×16
F000:F76B  03C3            add    ax, bx                      ; AX = low 16 bits of the physical address (segment×16 + BX)
F000:F76D  7302            jae    loc_F771                    ; no carry → page unchanged
F000:F76F  FEC5            inc    ch                          ; carry → page +1

loc_F771:    ; xrefs: F76D
F000:F771  50              push   ax                          ; save start address for the 64 KB boundary check
F000:F772  E604            out    4, al                       ; port 04h — DMA channel 2 address, low byte
F000:F774  8AC4            mov    al, ah                      ; address high byte
F000:F776  E604            out    4, al                       ; port 04h — channel 2 address, high byte
F000:F778  8AC5            mov    al, ch                      ; AL = page
F000:F77A  240F            and    al, 0Fh                     ; 4 page bits (1 MB address)
F000:F77C  E681            out    81h, al                     ; port 81h — DMA channel 2 page register
F000:F77E  8AE6            mov    ah, dh                      ; AH = sector count
F000:F780  2AC0            sub    al, al                      ; AL = 0 → AX = sectors × 256
F000:F782  D1E8            shr    ax, 1                       ; AX = sectors × 128 (sector size unit N=0)
F000:F784  50              push   ax                          ; save sectors×128
F000:F785  BB0600          mov    bx, 6                       ; BX=6 → byte 3 of the diskette parameter table (sector size code N)
F000:F788  E8E3F6          call   sub_EE6E                    ; AH = diskette parameter byte via INT 1Eh vector (0000:0078)
F000:F78B  8ACC            mov    cl, ah                      ; CL = N (2 → 512 bytes = 128 << 2)
F000:F78D  58              pop    ax                          ; AX = sectors × 128
F000:F78E  E9AC07          jmp    loc_FF3D                    ; continued: byte count and boundary check (F000:FF3D)

; ----------------------------------------------------------------------------------------------
; dat_F791 — scan code translation table 01h..3Ah for Latin with Shift (uppercase).
; Index = scan code-1 (xlat in INT 09h, F000:EB8F). FFh = key without ASCII code
; (modifiers), 00h = extended code. Selected at F000:EB33 when RUS is off (0040:0018 bit 2 = 0).
; ----------------------------------------------------------------------------------------------
dat_F791:    ; xrefs: EB33
F000:F791  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:F792  21402324255E…   db     '!@#$%^&*()_+'              ; scan 02h–0Dh with Shift: top row !@#$%^&*()_+
F000:F79E  0800            db     08h,00h                     ; scan 0Eh BackSpace → 08h; scan 0Fh Shift+Tab → 00h (extended code 0F00h)
F000:F7A0  515745525459…   db     'QWERTYUIOP{}'              ; scan 10h–1Bh with Shift: QWERTYUIOP{}
F000:F7AC  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh; scan 1Dh Ctrl → FFh (modifier, no character)
F000:F7AE  415344464748…   db     'ASDFGHJKL:"~'              ; scan 1Eh–29h with Shift: ASDFGHJKL:"~
F000:F7BA  FF              db     0FFh                        ; scan 2Ah left Shift → FFh (modifier)
F000:F7BB  7C5A58435642…   db     '|ZXCVBNM<>?'               ; scan 2Bh–35h with Shift: |ZXCVBNM<>?
F000:F7C6  FF00FF20FF      db     0FFh,00h,0FFh,20h,0FFh      ; scan 36h right Shift FFh, 37h PrtSc 00h, 38h Alt FFh, 39h space 20h, 3Ah CapsLock FFh

; ----------------------------------------------------------------------------------------------
; dat_F7CB — scan code table 01h..3Ah for Russian letters without Shift (lowercase, CP866).
; Selected at F000:EB8A when RUS mode is on (probably 0040:0018 bit 2 — toggled at F000:E94D).
; ЙЦУКЕН layout; letter ё on the «/» key (scan 35h).
; ----------------------------------------------------------------------------------------------
dat_F7CB:    ; xrefs: EB8A
F000:F7CB  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:F7CC  313233343536…   db     '1234567890-='              ; scan 02h–0Dh without Shift: digits 1234567890-=
F000:F7D8  0809            db     08h,09h                     ; scan 0Eh BackSpace → 08h; scan 0Fh Tab → 09h
F000:F7DA  A9E6E3AAA5AD…   db     'йцукенгшщзхъ'              ; scan 10h–1Bh: йцукенгшщзхъ (CP866 A9h,E6h,...)
F000:F7E6  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh; scan 1Dh Ctrl → FFh
F000:F7E8  E4EBA2A0AFE0…   db     'фывапролджэ`'              ; scan 1Eh–29h: фывапролджэ and ` (the ~ key left Latin)
F000:F7F4  FF              db     0FFh                        ; scan 2Ah left Shift → FFh
F000:F7F5  5CEFE7E1ACA8…   db     '\ячсмитьбюё'               ; scan 2Bh–35h: \ячсмитьбюё (ё instead of «/»)
F000:F800  FF2AFF20FF      db     0FFh,2Ah,0FFh,20h,0FFh      ; scan 36h right Shift FFh, 37h grey * → 2Ah, 38h Alt FFh, 39h space 20h, 3Ah CapsLock FFh

; ----------------------------------------------------------------------------------------------
; dat_F805 — scan code table 01h..3Ah for Russian letters with Shift (uppercase, CP866).
; Selected at F000:EB3D with Shift and RUS on (0040:0018 bit 2).
; ----------------------------------------------------------------------------------------------
dat_F805:    ; xrefs: EB3D
F000:F805  1B              db     1Bh                         ; scan 01h Esc → 1Bh
F000:F806  21402324255E…   db     '!@#$%^&*()_+'              ; scan 02h–0Dh with Shift: !@#$%^&*()_+
F000:F812  0800            db     08h,00h                     ; scan 0Eh BackSpace → 08h; scan 0Fh Shift+Tab → 00h (extended code)
F000:F814  8996938A858D…   db     'ЙЦУКЕНГШЩЗХЪ'              ; scan 10h–1Bh with Shift: ЙЦУКЕНГШЩЗХЪ (CP866 89h,96h,...)
F000:F820  0DFF            db     0Dh,0FFh                    ; scan 1Ch Enter → 0Dh; scan 1Dh Ctrl → FFh
F000:F822  949B82808F90…   db     'ФЫВАПРОЛДЖЭ~'              ; scan 1Eh–29h with Shift: ФЫВАПРОЛДЖЭ and ~
F000:F82E  FF              db     0FFh                        ; scan 2Ah left Shift → FFh
F000:F82F  7C9F97918C88…   db     '|ЯЧСМИТЬБЮЁ'               ; scan 2Bh–35h with Shift: |ЯЧСМИТЬБЮЁ
F000:F83A  FF00FF20FF0000  db     0FFh,00h,0FFh,20h,0FFh,00h,00h ; scan 36h right Shift FFh, 37h PrtSc 00h, 38h Alt FFh, 39h space 20h, 3Ah CapsLock FFh; 00h,00h — filler up to F841

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
font_lo:    ; xrefs: F505 F5EC
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
; dat_FEA1 — stub handler "mov ah,1 / iret": POST (F000:E18E) fills all interrupt vectors
; with it before installing the real ones; an unsupported interrupt returns AH=1.
; ----------------------------------------------------------------------------------------------
dat_FEA1:    ; xrefs: E18E
F000:FEA1  B401CF00        db     0B4h,01h,0CFh,00h           ; code: B4 01 = mov ah,1 ; CF = iret ; 00 — alignment

; ----------------------------------------------------------------------------------------------
; INT08_TIMER — INT 08h (IBM entry F000:FEA5), called from common handler F400:000D
; on bit 14 of F000:0200. Tick counter 0040:006C/6E, reset after 24 h (1800B0h ticks),
; floppy motor-off timeout 0040:0040, call to user INT 1Ch.
; No EOI sent — there is no 8259.
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
sub_FEE9:    ; xrefs: E264 E2D6 E746 E831 E914 EC63 EF5A EFD8 F080 F2A5 F716 F843 F84F F872 FE70 FEA9
F000:FEE9  50              push   ax                          ; save AX
F000:FEEA  B84000          mov    ax, 40h                     ; AX = 0040h
F000:FEED  8ED8            mov    ds, ax                      ; DS = BIOS data area segment
F000:FEEF  58              pop    ax                          ; restore AX
F000:FEF0  C3              ret                                ; return
F000:FEF1  0000            db     00h,00h                     ; padding up to the vector table F000:FEF3

; ----------------------------------------------------------------------------------------------
; vector_table — handler offsets for INT 08h..0Fh (segment F000, F400 for INT 0Fh),
; copied into the vector table in POST (F000:E2BC). Standard IBM address F000:FEF3.
; ----------------------------------------------------------------------------------------------
vector_table:    ; xrefs: E2B6
F000:FEF3  A5FE            dw     INT08_TIMER                 ; INT 08h — timer, F000:FEA5
F000:FEF5  87E9            dw     INT09_KEYBOARD              ; INT 09h — keyboard, F000:E987
F000:FEF7  53FF            dw     DUMMY_IRET                  ; INT 0Ah — IRET stub (8259 cascade on IBM)
F000:FEF9  53FF            dw     DUMMY_IRET                  ; INT 0Bh — IRET stub (COM2)
F000:FEFB  53FF            dw     DUMMY_IRET                  ; INT 0Ch — IRET stub (COM1; probably overridden by a driver)
F000:FEFD  53FF            dw     DUMMY_IRET                  ; INT 0Dh — IRET stub (IRQ5, hard disk on XT)
F000:FEFF  57EF            dw     INT0E_DISKETTE_IRQ          ; INT 0Eh — floppy drive interrupt, F000:EF57
F000:FF01  0D00            dw     000Dh                       ; INT 0Fh — common hardware interrupt handler F400:000D (segment F400 set at E1A9)

; ----------------------------------------------------------------------------------------------
; dat_FF03 — handler offsets for INT 10h..1Fh (segment F000), copied in POST (F000:E1BC).
; ----------------------------------------------------------------------------------------------
dat_FF03:    ; xrefs: E1B6
F000:FF03  65F0            dw     INT10_VIDEO                 ; INT 10h — video, F000:F065
F000:FF05  4DF8            dw     INT11_EQUIPMENT             ; INT 11h — equipment list, F000:F84D
F000:FF07  41F8            dw     INT12_MEMSIZE               ; INT 12h — memory size, F000:F841
F000:FF09  59EC            dw     INT13_DISKETTE              ; INT 13h — floppy drive, F000:EC59
F000:FF0B  39E7            dw     INT14_SERIAL                ; INT 14h — serial port, F000:E739
F000:FF0D  59F8            dw     INT15_CASSETTE              ; INT 15h — cassette, F000:F859
F000:FF0F  2EE8            dw     INT16_KEYBOARD              ; INT 16h — keyboard, F000:E82E
F000:FF11  D2EF            dw     INT17_PRINTER               ; INT 17h — printer, F000:EFD2
F000:FF13  0000            dw     0000h                       ; INT 18h — 0 (ROM BASIC on IBM); vector later set to the tape monitor F000:E48A
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
keypad_table:    ; xrefs: EB73
F000:FF23  3738392D3435…   db     '789-456+1230.'             ; scan 47h–53h: 7 8 9 - 4 5 6 + 1 2 3 0 .

; ----------------------------------------------------------------------------------------------
; dat_FF30 — extended codes (in AH, AL=0) of the numeric keypad without NumLock (Home, ↑, PgUp, ←, →, End...).
; Index = scan-47h; FFh — key without extended code (center 5 etc.).
; ----------------------------------------------------------------------------------------------
dat_FF30:    ; xrefs: EB5A
F000:FF30  474849FF4BFF…   db     47h,48h,49h,0FFh,4Bh,0FFh,4Dh,0FFh ; scan 47h Home, 48h ↑, 49h PgUp, 4Ah (grey -) FFh, 4Bh ←, 4Ch (5) FFh, 4Dh →, 4Eh (grey +) FFh
F000:FF38  4F50515253      db     'OPQRS'                     ; scan 4Fh End, 50h ↓, 51h PgDn, 52h Ins, 53h Del — extended codes = scan codes

; ----------------------------------------------------------------------------------------------
; loc_FF3D — end of DMA setup for INT 13h (continuation of sub_F75C, jumped to from F000:F78E).
; Input: AX = (sector count)·128, CL = sector size code N (byte 3 of the diskette parameter table);
; on stack: buffer address and caller's CX. Programs 8237 channel 2 count (port 05h, emulated),
; unmasks channel 2 (port 0Ah). Output: CF = 1 — buffer crosses a 64 KB boundary.
; ----------------------------------------------------------------------------------------------
loc_FF3D:    ; xrefs: F78E
F000:FF3D  D3E0            shl    ax, cl                      ; AX = transfer length in bytes = sectors·128·2^N
F000:FF3F  48              dec    ax                          ; 8237 is programmed with length-1
F000:FF40  50              push   ax                          ; save length-1
F000:FF41  E605            out    5, al                       ; DMA channel 2 count low byte (port 05h)
F000:FF43  8AC4            mov    al, ah                      ; AL = high byte of length-1
F000:FF45  E605            out    5, al                       ; DMA channel 2 count high byte (port 05h)
F000:FF47  59              pop    cx                          ; CX = length-1
F000:FF48  58              pop    ax                          ; AX = 16-bit buffer address (saved at F771)
F000:FF49  03C1            add    ax, cx                      ; address+length-1: CF=1 on crossing a 64 KB boundary (DMA error)
F000:FF4B  59              pop    cx                          ; restore caller's CX (pushed at F75C)
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
; Reads scan code from F000:0001 (8255 port A, like 60h) and acknowledges the keyboard by pulsing
; bits 7 and 5 in F000:0003 (8255 port B; bit 5 — clears keyboard interrupt request, cf. F400:004B).
; Output: AL = scan code, ZF = 1 if Esc pressed (scan 01h).
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
F000:FFFD  00FF47          db     00h,0FFh,47h                ; 00h; FFh — model ID (as IBM PC); 47h — checksum pad byte making E000–FFFF sum to 0 (CDh in my)
