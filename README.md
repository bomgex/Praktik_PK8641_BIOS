# Praktik PK8641 BIOS

**English** | [Українська](README.uk.md)

BIOS ROM dumps and a fully commented disassembly of the **Praktik** (PK8641), a Soviet IBM PC/XT-compatible personal computer made by the "Magnit" plant in 1990, with later BIOS versions by C.S.T. (Computer & Soft Technol.), 1992.

> [!WARNING]
> **The Praktik motherboard power connector looks like the standard IBM PC 5.25-inch floppy drive power connector, BUT(!) its pinout does not match the standard one.** Connecting a standard IBM PC power supply burns out the chips on the motherboard. Check the pinout before applying power.

## BIOS versions

| Folder | Version | CRC32 (16 KB image) | Notes |
|---|---|---|---|
| `2.14-15_dk/` | 2.14-15, "MAGNIT" 1990 | `8F2C3569` | Factory BIOS, the earliest available. Peripheral emulator with a 25-port list, no COM port emulation, cassette tape loader on INT 18h. |
| `2.16-17_my/` | 2.16-17, C.S.T. 1992 | `187319F5` | Reworked by C.S.T.: 1024-entry port table, COM1/COM2 emulation, direct 6845 programming. Main reference version. |
| `2.18-19_bios_new/` | 2.18-19, C.S.T. 1992 | `EBCC250C` | 2.16-17 with the LANcom Network Remote Loader 1.2 instead of the tape loader. |

Each folder contains the full 16 KB image and the two 8 KB ROM chips it is made of. The chips hold the even and odd bytes respectively; their names (2.14/2.15, 2.16/2.17, 2.18/2.19) are the chip reference designators on the board.

`2.16-17_my/pr_fnt.bin` is the 8×8 font (256 CP866 characters) extracted from the ROM. It is the same in all three versions.

## How the machine works

The Praktik has no 8259 interrupt controller and no 8237 DMA controller. Its other chips (8255, 8253, 6845, 765 and two 8250s) are not on the standard IBM PC I/O ports but in a memory window at `F000:0000–0FFF`. When a program accesses a standard IBM PC port, the hardware traps the access and raises an NMI. The NMI handler in ROM performs the access in software: it forwards it to the real chip, rescales the values, or emulates a missing device entirely. This is how unmodified IBM PC software runs on different hardware.

The 16 KB ROM is visible at `FC000–FFFFF` and mirrored at `F4000–F7FFF`:

- the first 8 KB run as segment `F400`: the peripheral emulator, the common hardware interrupt handler (INT 0Fh) and the upper half of the font;
- the second 8 KB at `F000:E000–FFFF` are an ordinary BIOS with entry points at exactly the IBM PC/XT addresses.

The 2.18-19 network loader uses the second 8250 (COM2) on a shared half-duplex line as the network, fetches `\\SERVER\RLOAD\NETBOOT.@@@` over SMB and boots it as a RAM disk A:.

## Documentation

The `disasm/` folder holds a commented disassembly of every version: a comment on every line, a header for every procedure, cross-references, a hardware register map and a list of emulated ports.

| | English | Ukrainian |
|---|---|---|
| Index: version history, differences, files | [`index_en.html`](disasm/index_en.html) | [`index.html`](disasm/index.html) |
| 2.14-15_dk | [`.html`](disasm/praktik_bios_2.14-15_dk_en.html) · [`.asm`](disasm/praktik_bios_2.14-15_dk_en.asm) | [`.html`](disasm/praktik_bios_2.14-15_dk.html) · [`.asm`](disasm/praktik_bios_2.14-15_dk.asm) |
| 2.16-17 (architecture overview) | [`.html`](disasm/praktik_bios_2.16-17_en.html) · [`.asm`](disasm/praktik_bios_2.16-17_en.asm) | [`.html`](disasm/praktik_bios_2.16-17.html) · [`.asm`](disasm/praktik_bios_2.16-17.asm) |
| 2.18-19_new | [`.html`](disasm/praktik_bios_2.18-19_new_en.html) · [`.asm`](disasm/praktik_bios_2.18-19_new_en.asm) | [`.html`](disasm/praktik_bios_2.18-19_new.html) · [`.asm`](disasm/praktik_bios_2.18-19_new.asm) |

The HTML documentation is published on GitHub Pages: <https://bomgex.github.io/Praktik_PK8641_BIOS/index_en.html> (English) and <https://bomgex.github.io/Praktik_PK8641_BIOS/> (Ukrainian). It is rebuilt from `disasm/` on every push by `.github/workflows/pages.yml`. You can also clone the repository and open `disasm/index_en.html` locally. The `.asm` files are plain text and read fine on GitHub.

In the comments, "probably" marks a conclusion drawn from the code that is not confirmed by documentation. On-screen BIOS messages are quoted in the original Russian with a translation.

## Font viewer

`2.16-17_my/show_font.py` renders an 8×8 font to PNG using only the Python standard library. Without arguments it renders `pr_fnt.bin` to `font.png` next to the script:

```
python 2.16-17_my/show_font.py [font_file] [output.png] [scale]
```

## Sources

- The BIOS files were taken from the post «Журнал восстановления Практика» ("Praktik restoration log") on the zxdesu site, 2016: <https://zxdesu.byethost32.com/2016/07/28/%d0%b6%d1%83%d1%80%d0%bd%d0%b0%d0%bb-%d0%b2%d0%be%d1%81%d1%81%d1%82%d0%b0%d0%bd%d0%be%d0%b2%d0%bb%d0%b5%d0%bd%d0%b8%d1%8f-%d0%bf%d1%80%d0%b0%d0%ba%d1%82%d0%b8%d0%ba%d0%b0/>
- Description of the Praktik computer (PK8641) on retro-computer.ru: <https://retro-computer.ru/item/PRAKTIK-PK8641.html>
