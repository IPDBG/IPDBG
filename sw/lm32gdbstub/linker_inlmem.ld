OUTPUT_FORMAT("elf32-lm32")
ENTRY(_start)

__DYNAMIC = 0;

MEMORY {
    imem : ORIGIN = 0x40000000, LENGTH = 0x00001000 /* 4k */
    dmem : ORIGIN = 0x50000000, LENGTH = 0x00000800 /* 2k */
}

SECTIONS
{
    .boot : { *(.boot) } > imem
	.text :
	{
     . = ALIGN(4);
		_ftext = .;
     _ftext_rom = LOADADDR(.text);
     . = . + 4;
     KEEP (*(.vector))
		*(.text .stub .text.* .gnu.linkonce.t.*)
     *(.gnu.warning)
     KEEP (*(.init))
     KEEP (*(.fini))


     /* Exception handlers */
     *(.eh_frame_hdr)
     KEEP (*(.eh_frame))
     *(.gcc_except_table)


     /* Constructors and destructors */
     KEEP (*crtbegin*.o(.ctors))
     KEEP (*(EXCLUDE_FILE (*crtend*.o ) .ctors))
     KEEP (*(SORT(.ctors.*)))
     KEEP (*(.ctors))
     KEEP (*crtbegin*.o(.dtors))
     KEEP (*(EXCLUDE_FILE (*crtend*.o ) .dtors))
     KEEP (*(SORT(.dtors.*)))
     KEEP (*(.dtors))
     KEEP (*(.jcr))
		_etext = .;
	} > imem /* rom */

  /* read-only data */
	.rodata :
	{
		. = ALIGN(4);
		_frodata = .;
     _frodata_rom = LOADADDR(.rodata);
     . = . + 4;
		*(.rodata .rodata.* .gnu.linkonce.r.*)
		*(.rodata1)
		_erodata = .;
	} > dmem /* rom */

  /* read/write data */
  .data :
  {
     . = ALIGN(4);
     _fdata = .;
     _fdata_rom = LOADADDR(.data);
     . = . + 4;
     *(.data .data.* .gnu.linkonce.d.*)
     *(.data1)
     SORT(CONSTRUCTORS)
     _gp = ALIGN(16) + 0x7ff0;
     *(.sdata .sdata.* .gnu.linkonce.s.*)
     *(.gcc_except_table.*)
     _edata = .;
  } > dmem



  /* bss */
	.bss :
	{
		. = ALIGN(4);
		_fbss = .;
		*(.dynsbss)
		*(.sbss .sbss.* .gnu.linkonce.sb.*)
		*(.scommon)
		*(.dynbss)
		*(.bss .bss.* .gnu.linkonce.b.*)
		*(COMMON)
		. = ALIGN(4);
		_ebss = .;
		_end = .;
	} > dmem /* ram */
}

PROVIDE(_debug_stack = ORIGIN(dmem) + LENGTH(dmem) - 4);
