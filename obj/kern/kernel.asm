
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
# bootloader to jump to the *physical* address of the entry point.
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# translates virtual addresses [KERNBASE, KERNBASE+4MB) to
	# physical addresses [0, 4MB).  This 4MB region will be suffice
	# until we set up our real page table in mem_init in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
f0100015:	b8 00 40 11 00       	mov    $0x114000,%eax
	movl	$(RELOC(entry_pgdir)), %eax
f010001a:	0f 22 d8             	mov    %eax,%cr3
	movl	%eax, %cr3
	# Turn on paging.
f010001d:	0f 20 c0             	mov    %cr0,%eax
	movl	%cr0, %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100025:	0f 22 c0             	mov    %eax,%cr0
	movl	%eax, %cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	mov	$relocated, %eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
	jmp	*%eax
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp
	movl	$0x0,%ebp			# nuke frame pointer

	# Set the stack pointer
f0100034:	bc 00 40 11 f0       	mov    $0xf0114000,%esp
	movl	$(bootstacktop),%esp

	# now to C code
f0100039:	e8 5f 00 00 00       	call   f010009d <i386_init>

f010003e <spin>:
	call	i386_init

	# Should never get here, but in case we do, just spin.
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <test_backtrace>:
#include <kern/console.h>
#include <kern/pmap.h>
#include <kern/kclock.h>
#include <kern/env.h>
#include <kern/trap.h>

f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	53                   	push   %ebx
f0100044:	83 ec 14             	sub    $0x14,%esp
f0100047:	8b 5d 08             	mov    0x8(%ebp),%ebx

f010004a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010004e:	c7 04 24 80 26 10 f0 	movl   $0xf0102680,(%esp)
f0100055:	e8 1c 11 00 00       	call   f0101176 <cprintf>
void
f010005a:	85 db                	test   %ebx,%ebx
f010005c:	7e 0d                	jle    f010006b <test_backtrace+0x2b>
i386_init(void)
f010005e:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0100061:	89 04 24             	mov    %eax,(%esp)
f0100064:	e8 d7 ff ff ff       	call   f0100040 <test_backtrace>
f0100069:	eb 1c                	jmp    f0100087 <test_backtrace+0x47>
{
	extern char edata[], end[];
f010006b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100072:	00 
f0100073:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010007a:	00 
f010007b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100082:	e8 1b 07 00 00       	call   f01007a2 <mon_backtrace>

f0100087:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010008b:	c7 04 24 9c 26 10 f0 	movl   $0xf010269c,(%esp)
f0100092:	e8 df 10 00 00       	call   f0101176 <cprintf>
	// Before doing anything else, complete the ELF loading process.
f0100097:	83 c4 14             	add    $0x14,%esp
f010009a:	5b                   	pop    %ebx
f010009b:	5d                   	pop    %ebp
f010009c:	c3                   	ret    

f010009d <i386_init>:
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);

f010009d:	55                   	push   %ebp
f010009e:	89 e5                	mov    %esp,%ebp
f01000a0:	83 ec 18             	sub    $0x18,%esp
	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();

	cprintf("6828 decimal is %o octal!\n", 6828);

f01000a3:	b8 ac 8e 17 f0       	mov    $0xf0178eac,%eax
f01000a8:	2d 69 7f 17 f0       	sub    $0xf0177f69,%eax
f01000ad:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000b1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000b8:	00 
f01000b9:	c7 04 24 69 7f 17 f0 	movl   $0xf0177f69,(%esp)
f01000c0:	e8 da 20 00 00       	call   f010219f <memset>
	// Lab 2 memory management initialization functions
	mem_init();

	// Lab 3 user environment initialization functions
f01000c5:	e8 a5 04 00 00       	call   f010056f <cons_init>
	env_init();
	trap_init();
f01000ca:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000d1:	00 
f01000d2:	c7 04 24 b7 26 10 f0 	movl   $0xf01026b7,(%esp)
f01000d9:	e8 98 10 00 00       	call   f0101176 <cprintf>

#if defined(TEST)
	// Don't touch -- used by grading script!
f01000de:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f01000e5:	e8 56 ff ff ff       	call   f0100040 <test_backtrace>
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	ENV_CREATE(user_hello, ENV_TYPE_USER);
f01000ea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000f1:	e8 21 07 00 00       	call   f0100817 <monitor>
f01000f6:	eb f2                	jmp    f01000ea <i386_init+0x4d>

f01000f8 <_panic>:
 */
const char *panicstr;

/*
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
f01000f8:	55                   	push   %ebp
f01000f9:	89 e5                	mov    %esp,%ebp
f01000fb:	56                   	push   %esi
f01000fc:	53                   	push   %ebx
f01000fd:	83 ec 10             	sub    $0x10,%esp
f0100100:	8b 75 10             	mov    0x10(%ebp),%esi
 */
void
_panic(const char *file, int line, const char *fmt,...)
f0100103:	83 3d 80 7f 17 f0 00 	cmpl   $0x0,0xf0177f80
f010010a:	75 3d                	jne    f0100149 <_panic+0x51>
{
	va_list ap;
f010010c:	89 35 80 7f 17 f0    	mov    %esi,0xf0177f80

	if (panicstr)
		goto dead;
f0100112:	fa                   	cli    
f0100113:	fc                   	cld    
	panicstr = fmt;

f0100114:	8d 5d 14             	lea    0x14(%ebp),%ebx
	// Be extra sure that the machine is in as reasonable state
f0100117:	8b 45 0c             	mov    0xc(%ebp),%eax
f010011a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010011e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100121:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100125:	c7 04 24 d2 26 10 f0 	movl   $0xf01026d2,(%esp)
f010012c:	e8 45 10 00 00       	call   f0101176 <cprintf>
	__asm __volatile("cli; cld");
f0100131:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100135:	89 34 24             	mov    %esi,(%esp)
f0100138:	e8 06 10 00 00       	call   f0101143 <vcprintf>

f010013d:	c7 04 24 0e 27 10 f0 	movl   $0xf010270e,(%esp)
f0100144:	e8 2d 10 00 00       	call   f0101176 <cprintf>
	va_start(ap, fmt);
	cprintf("kernel panic at %s:%d: ", file, line);
	vcprintf(fmt, ap);
	cprintf("\n");
	va_end(ap);

f0100149:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100150:	e8 c2 06 00 00       	call   f0100817 <monitor>
f0100155:	eb f2                	jmp    f0100149 <_panic+0x51>

f0100157 <_warn>:
dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
}

f0100157:	55                   	push   %ebp
f0100158:	89 e5                	mov    %esp,%ebp
f010015a:	53                   	push   %ebx
f010015b:	83 ec 14             	sub    $0x14,%esp
/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
f010015e:	8d 5d 14             	lea    0x14(%ebp),%ebx
{
f0100161:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100164:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100168:	8b 45 08             	mov    0x8(%ebp),%eax
f010016b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010016f:	c7 04 24 ea 26 10 f0 	movl   $0xf01026ea,(%esp)
f0100176:	e8 fb 0f 00 00       	call   f0101176 <cprintf>
	va_list ap;
f010017b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010017f:	8b 45 10             	mov    0x10(%ebp),%eax
f0100182:	89 04 24             	mov    %eax,(%esp)
f0100185:	e8 b9 0f 00 00       	call   f0101143 <vcprintf>

f010018a:	c7 04 24 0e 27 10 f0 	movl   $0xf010270e,(%esp)
f0100191:	e8 e0 0f 00 00       	call   f0101176 <cprintf>
	va_start(ap, fmt);
	cprintf("kernel warning at %s:%d: ", file, line);
f0100196:	83 c4 14             	add    $0x14,%esp
f0100199:	5b                   	pop    %ebx
f010019a:	5d                   	pop    %ebp
f010019b:	c3                   	ret    
f010019c:	66 90                	xchg   %ax,%ax
f010019e:	66 90                	xchg   %ax,%ax

f01001a0 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f01001a0:	55                   	push   %ebp
f01001a1:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01001a3:	ba fd 03 00 00       	mov    $0x3fd,%edx
f01001a8:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f01001a9:	a8 01                	test   $0x1,%al
f01001ab:	74 08                	je     f01001b5 <serial_proc_data+0x15>
f01001ad:	b2 f8                	mov    $0xf8,%dl
f01001af:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f01001b0:	0f b6 c0             	movzbl %al,%eax
f01001b3:	eb 05                	jmp    f01001ba <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f01001b5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f01001ba:	5d                   	pop    %ebp
f01001bb:	c3                   	ret    

f01001bc <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f01001bc:	55                   	push   %ebp
f01001bd:	89 e5                	mov    %esp,%ebp
f01001bf:	53                   	push   %ebx
f01001c0:	83 ec 04             	sub    $0x4,%esp
f01001c3:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f01001c5:	eb 2a                	jmp    f01001f1 <cons_intr+0x35>
		if (c == 0)
f01001c7:	85 d2                	test   %edx,%edx
f01001c9:	74 26                	je     f01001f1 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f01001cb:	a1 c4 81 17 f0       	mov    0xf01781c4,%eax
f01001d0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001d3:	89 0d c4 81 17 f0    	mov    %ecx,0xf01781c4
f01001d9:	88 90 c0 7f 17 f0    	mov    %dl,-0xfe88040(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001df:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001e5:	75 0a                	jne    f01001f1 <cons_intr+0x35>
			cons.wpos = 0;
f01001e7:	c7 05 c4 81 17 f0 00 	movl   $0x0,0xf01781c4
f01001ee:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f01001f1:	ff d3                	call   *%ebx
f01001f3:	89 c2                	mov    %eax,%edx
f01001f5:	83 f8 ff             	cmp    $0xffffffff,%eax
f01001f8:	75 cd                	jne    f01001c7 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f01001fa:	83 c4 04             	add    $0x4,%esp
f01001fd:	5b                   	pop    %ebx
f01001fe:	5d                   	pop    %ebp
f01001ff:	c3                   	ret    

f0100200 <kbd_proc_data>:
f0100200:	ba 64 00 00 00       	mov    $0x64,%edx
f0100205:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100206:	a8 01                	test   $0x1,%al
f0100208:	0f 84 ef 00 00 00    	je     f01002fd <kbd_proc_data+0xfd>
f010020e:	b2 60                	mov    $0x60,%dl
f0100210:	ec                   	in     (%dx),%al
f0100211:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100213:	3c e0                	cmp    $0xe0,%al
f0100215:	75 0d                	jne    f0100224 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100217:	83 0d a0 7f 17 f0 40 	orl    $0x40,0xf0177fa0
		return 0;
f010021e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100223:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100224:	55                   	push   %ebp
f0100225:	89 e5                	mov    %esp,%ebp
f0100227:	53                   	push   %ebx
f0100228:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010022b:	84 c0                	test   %al,%al
f010022d:	79 37                	jns    f0100266 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010022f:	8b 0d a0 7f 17 f0    	mov    0xf0177fa0,%ecx
f0100235:	89 cb                	mov    %ecx,%ebx
f0100237:	83 e3 40             	and    $0x40,%ebx
f010023a:	83 e0 7f             	and    $0x7f,%eax
f010023d:	85 db                	test   %ebx,%ebx
f010023f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100242:	0f b6 d2             	movzbl %dl,%edx
f0100245:	0f b6 82 60 28 10 f0 	movzbl -0xfefd7a0(%edx),%eax
f010024c:	83 c8 40             	or     $0x40,%eax
f010024f:	0f b6 c0             	movzbl %al,%eax
f0100252:	f7 d0                	not    %eax
f0100254:	21 c1                	and    %eax,%ecx
f0100256:	89 0d a0 7f 17 f0    	mov    %ecx,0xf0177fa0
		return 0;
f010025c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100261:	e9 9d 00 00 00       	jmp    f0100303 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100266:	8b 0d a0 7f 17 f0    	mov    0xf0177fa0,%ecx
f010026c:	f6 c1 40             	test   $0x40,%cl
f010026f:	74 0e                	je     f010027f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100271:	83 c8 80             	or     $0xffffff80,%eax
f0100274:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100276:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100279:	89 0d a0 7f 17 f0    	mov    %ecx,0xf0177fa0
	}

	shift |= shiftcode[data];
f010027f:	0f b6 d2             	movzbl %dl,%edx
f0100282:	0f b6 82 60 28 10 f0 	movzbl -0xfefd7a0(%edx),%eax
f0100289:	0b 05 a0 7f 17 f0    	or     0xf0177fa0,%eax
	shift ^= togglecode[data];
f010028f:	0f b6 8a 60 27 10 f0 	movzbl -0xfefd8a0(%edx),%ecx
f0100296:	31 c8                	xor    %ecx,%eax
f0100298:	a3 a0 7f 17 f0       	mov    %eax,0xf0177fa0

	c = charcode[shift & (CTL | SHIFT)][data];
f010029d:	89 c1                	mov    %eax,%ecx
f010029f:	83 e1 03             	and    $0x3,%ecx
f01002a2:	8b 0c 8d 40 27 10 f0 	mov    -0xfefd8c0(,%ecx,4),%ecx
f01002a9:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f01002ad:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f01002b0:	a8 08                	test   $0x8,%al
f01002b2:	74 1b                	je     f01002cf <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f01002b4:	89 da                	mov    %ebx,%edx
f01002b6:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f01002b9:	83 f9 19             	cmp    $0x19,%ecx
f01002bc:	77 05                	ja     f01002c3 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f01002be:	83 eb 20             	sub    $0x20,%ebx
f01002c1:	eb 0c                	jmp    f01002cf <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f01002c3:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f01002c6:	8d 4b 20             	lea    0x20(%ebx),%ecx
f01002c9:	83 fa 19             	cmp    $0x19,%edx
f01002cc:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002cf:	f7 d0                	not    %eax
f01002d1:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002d3:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002d5:	f6 c2 06             	test   $0x6,%dl
f01002d8:	75 29                	jne    f0100303 <kbd_proc_data+0x103>
f01002da:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f01002e0:	75 21                	jne    f0100303 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f01002e2:	c7 04 24 04 27 10 f0 	movl   $0xf0102704,(%esp)
f01002e9:	e8 88 0e 00 00       	call   f0101176 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002ee:	ba 92 00 00 00       	mov    $0x92,%edx
f01002f3:	b8 03 00 00 00       	mov    $0x3,%eax
f01002f8:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002f9:	89 d8                	mov    %ebx,%eax
f01002fb:	eb 06                	jmp    f0100303 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f01002fd:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100302:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100303:	83 c4 14             	add    $0x14,%esp
f0100306:	5b                   	pop    %ebx
f0100307:	5d                   	pop    %ebp
f0100308:	c3                   	ret    

f0100309 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100309:	55                   	push   %ebp
f010030a:	89 e5                	mov    %esp,%ebp
f010030c:	57                   	push   %edi
f010030d:	56                   	push   %esi
f010030e:	53                   	push   %ebx
f010030f:	83 ec 1c             	sub    $0x1c,%esp
f0100312:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100314:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100319:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010031a:	a8 20                	test   $0x20,%al
f010031c:	75 21                	jne    f010033f <cons_putc+0x36>
f010031e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100323:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100328:	be fd 03 00 00       	mov    $0x3fd,%esi
f010032d:	89 ca                	mov    %ecx,%edx
f010032f:	ec                   	in     (%dx),%al
f0100330:	ec                   	in     (%dx),%al
f0100331:	ec                   	in     (%dx),%al
f0100332:	ec                   	in     (%dx),%al
f0100333:	89 f2                	mov    %esi,%edx
f0100335:	ec                   	in     (%dx),%al
f0100336:	a8 20                	test   $0x20,%al
f0100338:	75 05                	jne    f010033f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010033a:	83 eb 01             	sub    $0x1,%ebx
f010033d:	75 ee                	jne    f010032d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010033f:	89 f8                	mov    %edi,%eax
f0100341:	0f b6 c0             	movzbl %al,%eax
f0100344:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100347:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010034c:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010034d:	b2 79                	mov    $0x79,%dl
f010034f:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100350:	84 c0                	test   %al,%al
f0100352:	78 21                	js     f0100375 <cons_putc+0x6c>
f0100354:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100359:	b9 84 00 00 00       	mov    $0x84,%ecx
f010035e:	be 79 03 00 00       	mov    $0x379,%esi
f0100363:	89 ca                	mov    %ecx,%edx
f0100365:	ec                   	in     (%dx),%al
f0100366:	ec                   	in     (%dx),%al
f0100367:	ec                   	in     (%dx),%al
f0100368:	ec                   	in     (%dx),%al
f0100369:	89 f2                	mov    %esi,%edx
f010036b:	ec                   	in     (%dx),%al
f010036c:	84 c0                	test   %al,%al
f010036e:	78 05                	js     f0100375 <cons_putc+0x6c>
f0100370:	83 eb 01             	sub    $0x1,%ebx
f0100373:	75 ee                	jne    f0100363 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100375:	ba 78 03 00 00       	mov    $0x378,%edx
f010037a:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010037e:	ee                   	out    %al,(%dx)
f010037f:	b2 7a                	mov    $0x7a,%dl
f0100381:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100386:	ee                   	out    %al,(%dx)
f0100387:	b8 08 00 00 00       	mov    $0x8,%eax
f010038c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010038d:	89 fa                	mov    %edi,%edx
f010038f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100395:	89 f8                	mov    %edi,%eax
f0100397:	80 cc 07             	or     $0x7,%ah
f010039a:	85 d2                	test   %edx,%edx
f010039c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010039f:	89 f8                	mov    %edi,%eax
f01003a1:	0f b6 c0             	movzbl %al,%eax
f01003a4:	83 f8 09             	cmp    $0x9,%eax
f01003a7:	74 79                	je     f0100422 <cons_putc+0x119>
f01003a9:	83 f8 09             	cmp    $0x9,%eax
f01003ac:	7f 0a                	jg     f01003b8 <cons_putc+0xaf>
f01003ae:	83 f8 08             	cmp    $0x8,%eax
f01003b1:	74 19                	je     f01003cc <cons_putc+0xc3>
f01003b3:	e9 9e 00 00 00       	jmp    f0100456 <cons_putc+0x14d>
f01003b8:	83 f8 0a             	cmp    $0xa,%eax
f01003bb:	90                   	nop
f01003bc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01003c0:	74 3a                	je     f01003fc <cons_putc+0xf3>
f01003c2:	83 f8 0d             	cmp    $0xd,%eax
f01003c5:	74 3d                	je     f0100404 <cons_putc+0xfb>
f01003c7:	e9 8a 00 00 00       	jmp    f0100456 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f01003cc:	0f b7 05 c8 81 17 f0 	movzwl 0xf01781c8,%eax
f01003d3:	66 85 c0             	test   %ax,%ax
f01003d6:	0f 84 e5 00 00 00    	je     f01004c1 <cons_putc+0x1b8>
			crt_pos--;
f01003dc:	83 e8 01             	sub    $0x1,%eax
f01003df:	66 a3 c8 81 17 f0    	mov    %ax,0xf01781c8
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003e5:	0f b7 c0             	movzwl %ax,%eax
f01003e8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003ed:	83 cf 20             	or     $0x20,%edi
f01003f0:	8b 15 cc 81 17 f0    	mov    0xf01781cc,%edx
f01003f6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003fa:	eb 78                	jmp    f0100474 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003fc:	66 83 05 c8 81 17 f0 	addw   $0x50,0xf01781c8
f0100403:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100404:	0f b7 05 c8 81 17 f0 	movzwl 0xf01781c8,%eax
f010040b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100411:	c1 e8 16             	shr    $0x16,%eax
f0100414:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100417:	c1 e0 04             	shl    $0x4,%eax
f010041a:	66 a3 c8 81 17 f0    	mov    %ax,0xf01781c8
f0100420:	eb 52                	jmp    f0100474 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100422:	b8 20 00 00 00       	mov    $0x20,%eax
f0100427:	e8 dd fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f010042c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100431:	e8 d3 fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f0100436:	b8 20 00 00 00       	mov    $0x20,%eax
f010043b:	e8 c9 fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f0100440:	b8 20 00 00 00       	mov    $0x20,%eax
f0100445:	e8 bf fe ff ff       	call   f0100309 <cons_putc>
		cons_putc(' ');
f010044a:	b8 20 00 00 00       	mov    $0x20,%eax
f010044f:	e8 b5 fe ff ff       	call   f0100309 <cons_putc>
f0100454:	eb 1e                	jmp    f0100474 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f0100456:	0f b7 05 c8 81 17 f0 	movzwl 0xf01781c8,%eax
f010045d:	8d 50 01             	lea    0x1(%eax),%edx
f0100460:	66 89 15 c8 81 17 f0 	mov    %dx,0xf01781c8
f0100467:	0f b7 c0             	movzwl %ax,%eax
f010046a:	8b 15 cc 81 17 f0    	mov    0xf01781cc,%edx
f0100470:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100474:	66 81 3d c8 81 17 f0 	cmpw   $0x7cf,0xf01781c8
f010047b:	cf 07 
f010047d:	76 42                	jbe    f01004c1 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010047f:	a1 cc 81 17 f0       	mov    0xf01781cc,%eax
f0100484:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010048b:	00 
f010048c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100492:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100496:	89 04 24             	mov    %eax,(%esp)
f0100499:	e8 4e 1d 00 00       	call   f01021ec <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010049e:	8b 15 cc 81 17 f0    	mov    0xf01781cc,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01004a4:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f01004a9:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f01004af:	83 c0 01             	add    $0x1,%eax
f01004b2:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f01004b7:	75 f0                	jne    f01004a9 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f01004b9:	66 83 2d c8 81 17 f0 	subw   $0x50,0xf01781c8
f01004c0:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f01004c1:	8b 0d d0 81 17 f0    	mov    0xf01781d0,%ecx
f01004c7:	b8 0e 00 00 00       	mov    $0xe,%eax
f01004cc:	89 ca                	mov    %ecx,%edx
f01004ce:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f01004cf:	0f b7 1d c8 81 17 f0 	movzwl 0xf01781c8,%ebx
f01004d6:	8d 71 01             	lea    0x1(%ecx),%esi
f01004d9:	89 d8                	mov    %ebx,%eax
f01004db:	66 c1 e8 08          	shr    $0x8,%ax
f01004df:	89 f2                	mov    %esi,%edx
f01004e1:	ee                   	out    %al,(%dx)
f01004e2:	b8 0f 00 00 00       	mov    $0xf,%eax
f01004e7:	89 ca                	mov    %ecx,%edx
f01004e9:	ee                   	out    %al,(%dx)
f01004ea:	89 d8                	mov    %ebx,%eax
f01004ec:	89 f2                	mov    %esi,%edx
f01004ee:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f01004ef:	83 c4 1c             	add    $0x1c,%esp
f01004f2:	5b                   	pop    %ebx
f01004f3:	5e                   	pop    %esi
f01004f4:	5f                   	pop    %edi
f01004f5:	5d                   	pop    %ebp
f01004f6:	c3                   	ret    

f01004f7 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f01004f7:	83 3d d4 81 17 f0 00 	cmpl   $0x0,0xf01781d4
f01004fe:	74 11                	je     f0100511 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100500:	55                   	push   %ebp
f0100501:	89 e5                	mov    %esp,%ebp
f0100503:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100506:	b8 a0 01 10 f0       	mov    $0xf01001a0,%eax
f010050b:	e8 ac fc ff ff       	call   f01001bc <cons_intr>
}
f0100510:	c9                   	leave  
f0100511:	f3 c3                	repz ret 

f0100513 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100513:	55                   	push   %ebp
f0100514:	89 e5                	mov    %esp,%ebp
f0100516:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100519:	b8 00 02 10 f0       	mov    $0xf0100200,%eax
f010051e:	e8 99 fc ff ff       	call   f01001bc <cons_intr>
}
f0100523:	c9                   	leave  
f0100524:	c3                   	ret    

f0100525 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100525:	55                   	push   %ebp
f0100526:	89 e5                	mov    %esp,%ebp
f0100528:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010052b:	e8 c7 ff ff ff       	call   f01004f7 <serial_intr>
	kbd_intr();
f0100530:	e8 de ff ff ff       	call   f0100513 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100535:	a1 c0 81 17 f0       	mov    0xf01781c0,%eax
f010053a:	3b 05 c4 81 17 f0    	cmp    0xf01781c4,%eax
f0100540:	74 26                	je     f0100568 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100542:	8d 50 01             	lea    0x1(%eax),%edx
f0100545:	89 15 c0 81 17 f0    	mov    %edx,0xf01781c0
f010054b:	0f b6 88 c0 7f 17 f0 	movzbl -0xfe88040(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f0100552:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f0100554:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f010055a:	75 11                	jne    f010056d <cons_getc+0x48>
			cons.rpos = 0;
f010055c:	c7 05 c0 81 17 f0 00 	movl   $0x0,0xf01781c0
f0100563:	00 00 00 
f0100566:	eb 05                	jmp    f010056d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100568:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010056d:	c9                   	leave  
f010056e:	c3                   	ret    

f010056f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010056f:	55                   	push   %ebp
f0100570:	89 e5                	mov    %esp,%ebp
f0100572:	57                   	push   %edi
f0100573:	56                   	push   %esi
f0100574:	53                   	push   %ebx
f0100575:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100578:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010057f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100586:	5a a5 
	if (*cp != 0xA55A) {
f0100588:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010058f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100593:	74 11                	je     f01005a6 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100595:	c7 05 d0 81 17 f0 b4 	movl   $0x3b4,0xf01781d0
f010059c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010059f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f01005a4:	eb 16                	jmp    f01005bc <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f01005a6:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f01005ad:	c7 05 d0 81 17 f0 d4 	movl   $0x3d4,0xf01781d0
f01005b4:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f01005b7:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f01005bc:	8b 0d d0 81 17 f0    	mov    0xf01781d0,%ecx
f01005c2:	b8 0e 00 00 00       	mov    $0xe,%eax
f01005c7:	89 ca                	mov    %ecx,%edx
f01005c9:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f01005ca:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005cd:	89 da                	mov    %ebx,%edx
f01005cf:	ec                   	in     (%dx),%al
f01005d0:	0f b6 f0             	movzbl %al,%esi
f01005d3:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005d6:	b8 0f 00 00 00       	mov    $0xf,%eax
f01005db:	89 ca                	mov    %ecx,%edx
f01005dd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005de:	89 da                	mov    %ebx,%edx
f01005e0:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f01005e1:	89 3d cc 81 17 f0    	mov    %edi,0xf01781cc
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005e7:	0f b6 d8             	movzbl %al,%ebx
f01005ea:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005ec:	66 89 35 c8 81 17 f0 	mov    %si,0xf01781c8
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005f3:	be fa 03 00 00       	mov    $0x3fa,%esi
f01005f8:	b8 00 00 00 00       	mov    $0x0,%eax
f01005fd:	89 f2                	mov    %esi,%edx
f01005ff:	ee                   	out    %al,(%dx)
f0100600:	b2 fb                	mov    $0xfb,%dl
f0100602:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100607:	ee                   	out    %al,(%dx)
f0100608:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f010060d:	b8 0c 00 00 00       	mov    $0xc,%eax
f0100612:	89 da                	mov    %ebx,%edx
f0100614:	ee                   	out    %al,(%dx)
f0100615:	b2 f9                	mov    $0xf9,%dl
f0100617:	b8 00 00 00 00       	mov    $0x0,%eax
f010061c:	ee                   	out    %al,(%dx)
f010061d:	b2 fb                	mov    $0xfb,%dl
f010061f:	b8 03 00 00 00       	mov    $0x3,%eax
f0100624:	ee                   	out    %al,(%dx)
f0100625:	b2 fc                	mov    $0xfc,%dl
f0100627:	b8 00 00 00 00       	mov    $0x0,%eax
f010062c:	ee                   	out    %al,(%dx)
f010062d:	b2 f9                	mov    $0xf9,%dl
f010062f:	b8 01 00 00 00       	mov    $0x1,%eax
f0100634:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100635:	b2 fd                	mov    $0xfd,%dl
f0100637:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f0100638:	3c ff                	cmp    $0xff,%al
f010063a:	0f 95 c1             	setne  %cl
f010063d:	0f b6 c9             	movzbl %cl,%ecx
f0100640:	89 0d d4 81 17 f0    	mov    %ecx,0xf01781d4
f0100646:	89 f2                	mov    %esi,%edx
f0100648:	ec                   	in     (%dx),%al
f0100649:	89 da                	mov    %ebx,%edx
f010064b:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f010064c:	85 c9                	test   %ecx,%ecx
f010064e:	75 0c                	jne    f010065c <cons_init+0xed>
		cprintf("Serial port does not exist!\n");
f0100650:	c7 04 24 10 27 10 f0 	movl   $0xf0102710,(%esp)
f0100657:	e8 1a 0b 00 00       	call   f0101176 <cprintf>
}
f010065c:	83 c4 1c             	add    $0x1c,%esp
f010065f:	5b                   	pop    %ebx
f0100660:	5e                   	pop    %esi
f0100661:	5f                   	pop    %edi
f0100662:	5d                   	pop    %ebp
f0100663:	c3                   	ret    

f0100664 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100664:	55                   	push   %ebp
f0100665:	89 e5                	mov    %esp,%ebp
f0100667:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f010066a:	8b 45 08             	mov    0x8(%ebp),%eax
f010066d:	e8 97 fc ff ff       	call   f0100309 <cons_putc>
}
f0100672:	c9                   	leave  
f0100673:	c3                   	ret    

f0100674 <getchar>:

int
getchar(void)
{
f0100674:	55                   	push   %ebp
f0100675:	89 e5                	mov    %esp,%ebp
f0100677:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010067a:	e8 a6 fe ff ff       	call   f0100525 <cons_getc>
f010067f:	85 c0                	test   %eax,%eax
f0100681:	74 f7                	je     f010067a <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100683:	c9                   	leave  
f0100684:	c3                   	ret    

f0100685 <iscons>:

int
iscons(int fdnum)
{
f0100685:	55                   	push   %ebp
f0100686:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100688:	b8 01 00 00 00       	mov    $0x1,%eax
f010068d:	5d                   	pop    %ebp
f010068e:	c3                   	ret    
f010068f:	90                   	nop

f0100690 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100690:	55                   	push   %ebp
f0100691:	89 e5                	mov    %esp,%ebp
f0100693:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100696:	c7 44 24 08 60 29 10 	movl   $0xf0102960,0x8(%esp)
f010069d:	f0 
f010069e:	c7 44 24 04 7e 29 10 	movl   $0xf010297e,0x4(%esp)
f01006a5:	f0 
f01006a6:	c7 04 24 83 29 10 f0 	movl   $0xf0102983,(%esp)
f01006ad:	e8 c4 0a 00 00       	call   f0101176 <cprintf>
f01006b2:	c7 44 24 08 28 2a 10 	movl   $0xf0102a28,0x8(%esp)
f01006b9:	f0 
f01006ba:	c7 44 24 04 8c 29 10 	movl   $0xf010298c,0x4(%esp)
f01006c1:	f0 
f01006c2:	c7 04 24 83 29 10 f0 	movl   $0xf0102983,(%esp)
f01006c9:	e8 a8 0a 00 00       	call   f0101176 <cprintf>
f01006ce:	c7 44 24 08 95 29 10 	movl   $0xf0102995,0x8(%esp)
f01006d5:	f0 
f01006d6:	c7 44 24 04 b3 29 10 	movl   $0xf01029b3,0x4(%esp)
f01006dd:	f0 
f01006de:	c7 04 24 83 29 10 f0 	movl   $0xf0102983,(%esp)
f01006e5:	e8 8c 0a 00 00       	call   f0101176 <cprintf>
	return 0;
}
f01006ea:	b8 00 00 00 00       	mov    $0x0,%eax
f01006ef:	c9                   	leave  
f01006f0:	c3                   	ret    

f01006f1 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01006f1:	55                   	push   %ebp
f01006f2:	89 e5                	mov    %esp,%ebp
f01006f4:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f01006f7:	c7 04 24 c1 29 10 f0 	movl   $0xf01029c1,(%esp)
f01006fe:	e8 73 0a 00 00       	call   f0101176 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100703:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010070a:	00 
f010070b:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f0100712:	f0 
f0100713:	c7 04 24 50 2a 10 f0 	movl   $0xf0102a50,(%esp)
f010071a:	e8 57 0a 00 00       	call   f0101176 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010071f:	c7 44 24 08 67 26 10 	movl   $0x102667,0x8(%esp)
f0100726:	00 
f0100727:	c7 44 24 04 67 26 10 	movl   $0xf0102667,0x4(%esp)
f010072e:	f0 
f010072f:	c7 04 24 74 2a 10 f0 	movl   $0xf0102a74,(%esp)
f0100736:	e8 3b 0a 00 00       	call   f0101176 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f010073b:	c7 44 24 08 69 7f 17 	movl   $0x177f69,0x8(%esp)
f0100742:	00 
f0100743:	c7 44 24 04 69 7f 17 	movl   $0xf0177f69,0x4(%esp)
f010074a:	f0 
f010074b:	c7 04 24 98 2a 10 f0 	movl   $0xf0102a98,(%esp)
f0100752:	e8 1f 0a 00 00       	call   f0101176 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f0100757:	c7 44 24 08 ac 8e 17 	movl   $0x178eac,0x8(%esp)
f010075e:	00 
f010075f:	c7 44 24 04 ac 8e 17 	movl   $0xf0178eac,0x4(%esp)
f0100766:	f0 
f0100767:	c7 04 24 bc 2a 10 f0 	movl   $0xf0102abc,(%esp)
f010076e:	e8 03 0a 00 00       	call   f0101176 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f0100773:	b8 ab 92 17 f0       	mov    $0xf01792ab,%eax
f0100778:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf("Special kernel symbols:\n");
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f010077d:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100783:	85 c0                	test   %eax,%eax
f0100785:	0f 48 c2             	cmovs  %edx,%eax
f0100788:	c1 f8 0a             	sar    $0xa,%eax
f010078b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010078f:	c7 04 24 e0 2a 10 f0 	movl   $0xf0102ae0,(%esp)
f0100796:	e8 db 09 00 00       	call   f0101176 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f010079b:	b8 00 00 00 00       	mov    $0x0,%eax
f01007a0:	c9                   	leave  
f01007a1:	c3                   	ret    

f01007a2 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f01007a2:	55                   	push   %ebp
f01007a3:	89 e5                	mov    %esp,%ebp
f01007a5:	53                   	push   %ebx
f01007a6:	83 ec 44             	sub    $0x44,%esp

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f01007a9:	89 eb                	mov    %ebp,%ebx
	unsigned int ebp;
	unsigned int eip;
	unsigned int args[5];
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
f01007ab:	c7 04 24 da 29 10 f0 	movl   $0xf01029da,(%esp)
f01007b2:	e8 bf 09 00 00       	call   f0101176 <cprintf>
	do{
           eip = *((unsigned int*)(ebp + 4));
f01007b7:	8b 4b 04             	mov    0x4(%ebx),%ecx
           for(i=0;i<5;i++)
f01007ba:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *((unsigned int*)(ebp+8+4*i));
f01007bf:	8b 54 83 08          	mov    0x8(%ebx,%eax,4),%edx
f01007c3:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
	do{
           eip = *((unsigned int*)(ebp + 4));
           for(i=0;i<5;i++)
f01007c7:	83 c0 01             	add    $0x1,%eax
f01007ca:	83 f8 05             	cmp    $0x5,%eax
f01007cd:	75 f0                	jne    f01007bf <mon_backtrace+0x1d>
		args[i] = *((unsigned int*)(ebp+8+4*i));
	cprintf(" ebp %08x eip %08x args %08x %08x %08x %08x %08x\n",
f01007cf:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01007d2:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f01007d6:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01007d9:	89 44 24 18          	mov    %eax,0x18(%esp)
f01007dd:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01007e0:	89 44 24 14          	mov    %eax,0x14(%esp)
f01007e4:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01007e7:	89 44 24 10          	mov    %eax,0x10(%esp)
f01007eb:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01007ee:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01007f2:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01007f6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01007fa:	c7 04 24 0c 2b 10 f0 	movl   $0xf0102b0c,(%esp)
f0100801:	e8 70 09 00 00       	call   f0101176 <cprintf>
		ebp,eip,args[0],args[1],args[2],args[3],args[4]);
	ebp =*((unsigned int*)ebp);
f0100806:	8b 1b                	mov    (%ebx),%ebx
	}while(ebp!=0);
f0100808:	85 db                	test   %ebx,%ebx
f010080a:	75 ab                	jne    f01007b7 <mon_backtrace+0x15>
	return 0;
}
f010080c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100811:	83 c4 44             	add    $0x44,%esp
f0100814:	5b                   	pop    %ebx
f0100815:	5d                   	pop    %ebp
f0100816:	c3                   	ret    

f0100817 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100817:	55                   	push   %ebp
f0100818:	89 e5                	mov    %esp,%ebp
f010081a:	57                   	push   %edi
f010081b:	56                   	push   %esi
f010081c:	53                   	push   %ebx
f010081d:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f0100820:	c7 04 24 40 2b 10 f0 	movl   $0xf0102b40,(%esp)
f0100827:	e8 4a 09 00 00       	call   f0101176 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010082c:	c7 04 24 64 2b 10 f0 	movl   $0xf0102b64,(%esp)
f0100833:	e8 3e 09 00 00       	call   f0101176 <cprintf>

	if (tf != NULL)
f0100838:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f010083c:	74 0b                	je     f0100849 <monitor+0x32>
		print_trapframe(tf);
f010083e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100841:	89 04 24             	mov    %eax,(%esp)
f0100844:	e8 55 0a 00 00       	call   f010129e <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100849:	c7 04 24 ec 29 10 f0 	movl   $0xf01029ec,(%esp)
f0100850:	e8 9b 16 00 00       	call   f0101ef0 <readline>
f0100855:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100857:	85 c0                	test   %eax,%eax
f0100859:	74 ee                	je     f0100849 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f010085b:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100862:	be 00 00 00 00       	mov    $0x0,%esi
f0100867:	eb 0a                	jmp    f0100873 <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100869:	c6 03 00             	movb   $0x0,(%ebx)
f010086c:	89 f7                	mov    %esi,%edi
f010086e:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100871:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100873:	0f b6 03             	movzbl (%ebx),%eax
f0100876:	84 c0                	test   %al,%al
f0100878:	74 6a                	je     f01008e4 <monitor+0xcd>
f010087a:	0f be c0             	movsbl %al,%eax
f010087d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100881:	c7 04 24 f0 29 10 f0 	movl   $0xf01029f0,(%esp)
f0100888:	e8 b1 18 00 00       	call   f010213e <strchr>
f010088d:	85 c0                	test   %eax,%eax
f010088f:	75 d8                	jne    f0100869 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100891:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100894:	74 4e                	je     f01008e4 <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100896:	83 fe 0f             	cmp    $0xf,%esi
f0100899:	75 16                	jne    f01008b1 <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f010089b:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f01008a2:	00 
f01008a3:	c7 04 24 f5 29 10 f0 	movl   $0xf01029f5,(%esp)
f01008aa:	e8 c7 08 00 00       	call   f0101176 <cprintf>
f01008af:	eb 98                	jmp    f0100849 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f01008b1:	8d 7e 01             	lea    0x1(%esi),%edi
f01008b4:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f01008b8:	0f b6 03             	movzbl (%ebx),%eax
f01008bb:	84 c0                	test   %al,%al
f01008bd:	75 0c                	jne    f01008cb <monitor+0xb4>
f01008bf:	eb b0                	jmp    f0100871 <monitor+0x5a>
			buf++;
f01008c1:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008c4:	0f b6 03             	movzbl (%ebx),%eax
f01008c7:	84 c0                	test   %al,%al
f01008c9:	74 a6                	je     f0100871 <monitor+0x5a>
f01008cb:	0f be c0             	movsbl %al,%eax
f01008ce:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008d2:	c7 04 24 f0 29 10 f0 	movl   $0xf01029f0,(%esp)
f01008d9:	e8 60 18 00 00       	call   f010213e <strchr>
f01008de:	85 c0                	test   %eax,%eax
f01008e0:	74 df                	je     f01008c1 <monitor+0xaa>
f01008e2:	eb 8d                	jmp    f0100871 <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f01008e4:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f01008eb:	00 

	// Lookup and invoke the command
	if (argc == 0)
f01008ec:	85 f6                	test   %esi,%esi
f01008ee:	0f 84 55 ff ff ff    	je     f0100849 <monitor+0x32>
f01008f4:	bb 00 00 00 00       	mov    $0x0,%ebx
f01008f9:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f01008fc:	8b 04 85 a0 2b 10 f0 	mov    -0xfefd460(,%eax,4),%eax
f0100903:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100907:	8b 45 a8             	mov    -0x58(%ebp),%eax
f010090a:	89 04 24             	mov    %eax,(%esp)
f010090d:	e8 a8 17 00 00       	call   f01020ba <strcmp>
f0100912:	85 c0                	test   %eax,%eax
f0100914:	75 24                	jne    f010093a <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100916:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100919:	8b 55 08             	mov    0x8(%ebp),%edx
f010091c:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100920:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100923:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100927:	89 34 24             	mov    %esi,(%esp)
f010092a:	ff 14 85 a8 2b 10 f0 	call   *-0xfefd458(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100931:	85 c0                	test   %eax,%eax
f0100933:	78 25                	js     f010095a <monitor+0x143>
f0100935:	e9 0f ff ff ff       	jmp    f0100849 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f010093a:	83 c3 01             	add    $0x1,%ebx
f010093d:	83 fb 03             	cmp    $0x3,%ebx
f0100940:	75 b7                	jne    f01008f9 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100942:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100945:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100949:	c7 04 24 12 2a 10 f0 	movl   $0xf0102a12,(%esp)
f0100950:	e8 21 08 00 00       	call   f0101176 <cprintf>
f0100955:	e9 ef fe ff ff       	jmp    f0100849 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f010095a:	83 c4 5c             	add    $0x5c,%esp
f010095d:	5b                   	pop    %ebx
f010095e:	5e                   	pop    %esi
f010095f:	5f                   	pop    %edi
f0100960:	5d                   	pop    %ebp
f0100961:	c3                   	ret    

f0100962 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100962:	55                   	push   %ebp
f0100963:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100965:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100968:	5d                   	pop    %ebp
f0100969:	c3                   	ret    

f010096a <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f010096a:	55                   	push   %ebp
f010096b:	89 e5                	mov    %esp,%ebp
f010096d:	53                   	push   %ebx
f010096e:	83 ec 14             	sub    $0x14,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0100971:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0100978:	e8 89 07 00 00       	call   f0101106 <mc146818_read>
f010097d:	89 c3                	mov    %eax,%ebx
f010097f:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f0100986:	e8 7b 07 00 00       	call   f0101106 <mc146818_read>
f010098b:	c1 e0 08             	shl    $0x8,%eax
f010098e:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0100990:	89 d8                	mov    %ebx,%eax
f0100992:	c1 e0 0a             	shl    $0xa,%eax
f0100995:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010099b:	85 c0                	test   %eax,%eax
f010099d:	0f 48 c2             	cmovs  %edx,%eax
f01009a0:	c1 f8 0c             	sar    $0xc,%eax
f01009a3:	a3 e0 81 17 f0       	mov    %eax,0xf01781e0
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01009a8:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01009af:	e8 52 07 00 00       	call   f0101106 <mc146818_read>
f01009b4:	89 c3                	mov    %eax,%ebx
f01009b6:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01009bd:	e8 44 07 00 00       	call   f0101106 <mc146818_read>
f01009c2:	c1 e0 08             	shl    $0x8,%eax
f01009c5:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f01009c7:	89 d8                	mov    %ebx,%eax
f01009c9:	c1 e0 0a             	shl    $0xa,%eax
f01009cc:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01009d2:	85 c0                	test   %eax,%eax
f01009d4:	0f 48 c2             	cmovs  %edx,%eax
f01009d7:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f01009da:	85 c0                	test   %eax,%eax
f01009dc:	74 0e                	je     f01009ec <mem_init+0x82>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f01009de:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f01009e4:	89 15 a0 8e 17 f0    	mov    %edx,0xf0178ea0
f01009ea:	eb 0c                	jmp    f01009f8 <mem_init+0x8e>
	else
		npages = npages_basemem;
f01009ec:	8b 15 e0 81 17 f0    	mov    0xf01781e0,%edx
f01009f2:	89 15 a0 8e 17 f0    	mov    %edx,0xf0178ea0

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f01009f8:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01009fb:	c1 e8 0a             	shr    $0xa,%eax
f01009fe:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0100a02:	a1 e0 81 17 f0       	mov    0xf01781e0,%eax
f0100a07:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100a0a:	c1 e8 0a             	shr    $0xa,%eax
f0100a0d:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0100a11:	a1 a0 8e 17 f0       	mov    0xf0178ea0,%eax
f0100a16:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0100a19:	c1 e8 0a             	shr    $0xa,%eax
f0100a1c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a20:	c7 04 24 c4 2b 10 f0 	movl   $0xf0102bc4,(%esp)
f0100a27:	e8 4a 07 00 00       	call   f0101176 <cprintf>

	// Find out how much memory the machine has (npages & npages_basemem).
	i386_detect_memory();

	// Remove this line when you're ready to test this function.
	panic("mem_init: This function is not finished\n");
f0100a2c:	c7 44 24 08 00 2c 10 	movl   $0xf0102c00,0x8(%esp)
f0100a33:	f0 
f0100a34:	c7 44 24 04 7d 00 00 	movl   $0x7d,0x4(%esp)
f0100a3b:	00 
f0100a3c:	c7 04 24 74 2c 10 f0 	movl   $0xf0102c74,(%esp)
f0100a43:	e8 b0 f6 ff ff       	call   f01000f8 <_panic>

f0100a48 <page_init>:
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	uint32_t pa;
  	page_free_list=NULL;
f0100a48:	c7 05 dc 81 17 f0 00 	movl   $0x0,0xf01781dc
f0100a4f:	00 00 00 
	for (i = 0; i < npages; i++) 
f0100a52:	83 3d a0 8e 17 f0 00 	cmpl   $0x0,0xf0178ea0
f0100a59:	0f 84 32 01 00 00    	je     f0100b91 <page_init+0x149>
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100a5f:	55                   	push   %ebp
f0100a60:	89 e5                	mov    %esp,%ebp
f0100a62:	57                   	push   %edi
f0100a63:	56                   	push   %esi
f0100a64:	53                   	push   %ebx
f0100a65:	83 ec 1c             	sub    $0x1c,%esp
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100a68:	bf ab 9e 17 f0       	mov    $0xf0179eab,%edi
f0100a6d:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
f0100a73:	be 00 00 00 00       	mov    $0x0,%esi
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	uint32_t pa;
  	page_free_list=NULL;
	for (i = 0; i < npages; i++) 
f0100a78:	bb 00 00 00 00       	mov    $0x0,%ebx
	{
		if(i == 0)
f0100a7d:	85 db                	test   %ebx,%ebx
f0100a7f:	75 16                	jne    f0100a97 <page_init+0x4f>
		{
		   pages[0].pp_ref =1;
f0100a81:	a1 a8 8e 17 f0       	mov    0xf0178ea8,%eax
f0100a86:	66 c7 40 04 01 00    	movw   $0x1,0x4(%eax)
		   pages[0].pp_link=NULL;
f0100a8c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
                   continue;
f0100a92:	e9 e1 00 00 00       	jmp    f0100b78 <page_init+0x130>
		}
		else if(i < npages_basemem)		
f0100a97:	39 1d e0 81 17 f0    	cmp    %ebx,0xf01781e0
f0100a9d:	76 25                	jbe    f0100ac4 <page_init+0x7c>
		{
		pages[i].pp_ref = 0;
f0100a9f:	89 f0                	mov    %esi,%eax
f0100aa1:	03 05 a8 8e 17 f0    	add    0xf0178ea8,%eax
f0100aa7:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
		pages[i].pp_link = page_free_list;
f0100aad:	8b 15 dc 81 17 f0    	mov    0xf01781dc,%edx
f0100ab3:	89 10                	mov    %edx,(%eax)
		page_free_list = &pages[i];
f0100ab5:	89 f0                	mov    %esi,%eax
f0100ab7:	03 05 a8 8e 17 f0    	add    0xf0178ea8,%eax
f0100abd:	a3 dc 81 17 f0       	mov    %eax,0xf01781dc
f0100ac2:	eb 60                	jmp    f0100b24 <page_init+0xdc>
		}
		else if (i<=(EXTPHYSMEM/PGSIZE) || i < (((uint32_t)boot_alloc(0) - KERNBASE) >> PGSHIFT) )
f0100ac4:	81 fb 00 01 00 00    	cmp    $0x100,%ebx
f0100aca:	76 20                	jbe    f0100aec <page_init+0xa4>
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100acc:	83 3d d8 81 17 f0 00 	cmpl   $0x0,0xf01781d8
f0100ad3:	75 06                	jne    f0100adb <page_init+0x93>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100ad5:	89 3d d8 81 17 f0    	mov    %edi,0xf01781d8
		{
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
		}
		else if (i<=(EXTPHYSMEM/PGSIZE) || i < (((uint32_t)boot_alloc(0) - KERNBASE) >> PGSHIFT) )
f0100adb:	a1 d8 81 17 f0       	mov    0xf01781d8,%eax
f0100ae0:	05 00 00 00 10       	add    $0x10000000,%eax
f0100ae5:	c1 e8 0c             	shr    $0xc,%eax
f0100ae8:	39 d8                	cmp    %ebx,%eax
f0100aea:	76 15                	jbe    f0100b01 <page_init+0xb9>
		{
			pages[i].pp_ref++;
f0100aec:	89 f0                	mov    %esi,%eax
f0100aee:	03 05 a8 8e 17 f0    	add    0xf0178ea8,%eax
f0100af4:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
			pages[i].pp_link=NULL;	
f0100af9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
f0100aff:	eb 23                	jmp    f0100b24 <page_init+0xdc>
		}else		
		{
		pages[i].pp_ref = 0;
f0100b01:	89 f0                	mov    %esi,%eax
f0100b03:	03 05 a8 8e 17 f0    	add    0xf0178ea8,%eax
f0100b09:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
		pages[i].pp_link = page_free_list;
f0100b0f:	8b 15 dc 81 17 f0    	mov    0xf01781dc,%edx
f0100b15:	89 10                	mov    %edx,(%eax)
		page_free_list = &pages[i];
f0100b17:	89 f0                	mov    %esi,%eax
f0100b19:	03 05 a8 8e 17 f0    	add    0xf0178ea8,%eax
f0100b1f:	a3 dc 81 17 f0       	mov    %eax,0xf01781dc
		}
		pa = page2pa (&pages[i]);
f0100b24:	89 f2                	mov    %esi,%edx
f0100b26:	03 15 a8 8e 17 f0    	add    0xf0178ea8,%edx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b2c:	89 f0                	mov    %esi,%eax
f0100b2e:	c1 f8 03             	sar    $0x3,%eax
f0100b31:	c1 e0 0c             	shl    $0xc,%eax
		if((pa==0||(pa>=IOPHYSMEM && pa <=((uint32_t)boot_alloc(0) - KERNBASE)>>PGSHIFT))&& (pages[i].pp_ref==0))
f0100b34:	85 c0                	test   %eax,%eax
f0100b36:	74 29                	je     f0100b61 <page_init+0x119>
f0100b38:	3d ff ff 09 00       	cmp    $0x9ffff,%eax
f0100b3d:	76 39                	jbe    f0100b78 <page_init+0x130>
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b3f:	83 3d d8 81 17 f0 00 	cmpl   $0x0,0xf01781d8
f0100b46:	75 06                	jne    f0100b4e <page_init+0x106>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b48:	89 3d d8 81 17 f0    	mov    %edi,0xf01781d8
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
		}
		pa = page2pa (&pages[i]);
		if((pa==0||(pa>=IOPHYSMEM && pa <=((uint32_t)boot_alloc(0) - KERNBASE)>>PGSHIFT))&& (pages[i].pp_ref==0))
f0100b4e:	8b 0d d8 81 17 f0    	mov    0xf01781d8,%ecx
f0100b54:	81 c1 00 00 00 10    	add    $0x10000000,%ecx
f0100b5a:	c1 e9 0c             	shr    $0xc,%ecx
f0100b5d:	39 c1                	cmp    %eax,%ecx
f0100b5f:	72 17                	jb     f0100b78 <page_init+0x130>
f0100b61:	66 83 7a 04 00       	cmpw   $0x0,0x4(%edx)
f0100b66:	75 10                	jne    f0100b78 <page_init+0x130>
		{
			cprintf("page error: i %d\n",i);
f0100b68:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100b6c:	c7 04 24 80 2c 10 f0 	movl   $0xf0102c80,(%esp)
f0100b73:	e8 fe 05 00 00       	call   f0101176 <cprintf>
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	uint32_t pa;
  	page_free_list=NULL;
	for (i = 0; i < npages; i++) 
f0100b78:	83 c3 01             	add    $0x1,%ebx
f0100b7b:	83 c6 08             	add    $0x8,%esi
f0100b7e:	39 1d a0 8e 17 f0    	cmp    %ebx,0xf0178ea0
f0100b84:	0f 87 f3 fe ff ff    	ja     f0100a7d <page_init+0x35>
		if((pa==0||(pa>=IOPHYSMEM && pa <=((uint32_t)boot_alloc(0) - KERNBASE)>>PGSHIFT))&& (pages[i].pp_ref==0))
		{
			cprintf("page error: i %d\n",i);
		}
	}
}
f0100b8a:	83 c4 1c             	add    $0x1c,%esp
f0100b8d:	5b                   	pop    %ebx
f0100b8e:	5e                   	pop    %esi
f0100b8f:	5f                   	pop    %edi
f0100b90:	5d                   	pop    %ebp
f0100b91:	f3 c3                	repz ret 

f0100b93 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0100b93:	55                   	push   %ebp
f0100b94:	89 e5                	mov    %esp,%ebp
f0100b96:	53                   	push   %ebx
f0100b97:	83 ec 14             	sub    $0x14,%esp
	// Fill this function in
    struct Page *pp =NULL;
    if(!page_free_list)
f0100b9a:	8b 1d dc 81 17 f0    	mov    0xf01781dc,%ebx
f0100ba0:	85 db                	test   %ebx,%ebx
f0100ba2:	74 69                	je     f0100c0d <page_alloc+0x7a>
    {
	return NULL;
    }	
    pp = page_free_list;
    page_free_list = page_free_list->pp_link;
f0100ba4:	8b 03                	mov    (%ebx),%eax
f0100ba6:	a3 dc 81 17 f0       	mov    %eax,0xf01781dc
    if (alloc_flags &ALLOC_ZERO)
   {
     memset(page2kva(pp),0,PGSIZE);
   }

return pp;
f0100bab:	89 d8                	mov    %ebx,%eax
    {
	return NULL;
    }	
    pp = page_free_list;
    page_free_list = page_free_list->pp_link;
    if (alloc_flags &ALLOC_ZERO)
f0100bad:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0100bb1:	74 5f                	je     f0100c12 <page_alloc+0x7f>
f0100bb3:	2b 05 a8 8e 17 f0    	sub    0xf0178ea8,%eax
f0100bb9:	c1 f8 03             	sar    $0x3,%eax
f0100bbc:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100bbf:	89 c2                	mov    %eax,%edx
f0100bc1:	c1 ea 0c             	shr    $0xc,%edx
f0100bc4:	3b 15 a0 8e 17 f0    	cmp    0xf0178ea0,%edx
f0100bca:	72 20                	jb     f0100bec <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100bcc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bd0:	c7 44 24 08 2c 2c 10 	movl   $0xf0102c2c,0x8(%esp)
f0100bd7:	f0 
f0100bd8:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100bdf:	00 
f0100be0:	c7 04 24 92 2c 10 f0 	movl   $0xf0102c92,(%esp)
f0100be7:	e8 0c f5 ff ff       	call   f01000f8 <_panic>
   {
     memset(page2kva(pp),0,PGSIZE);
f0100bec:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100bf3:	00 
f0100bf4:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100bfb:	00 
	return (void *)(pa + KERNBASE);
f0100bfc:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100c01:	89 04 24             	mov    %eax,(%esp)
f0100c04:	e8 96 15 00 00       	call   f010219f <memset>
   }

return pp;
f0100c09:	89 d8                	mov    %ebx,%eax
f0100c0b:	eb 05                	jmp    f0100c12 <page_alloc+0x7f>
{
	// Fill this function in
    struct Page *pp =NULL;
    if(!page_free_list)
    {
	return NULL;
f0100c0d:	b8 00 00 00 00       	mov    $0x0,%eax
   {
     memset(page2kva(pp),0,PGSIZE);
   }

return pp;
}
f0100c12:	83 c4 14             	add    $0x14,%esp
f0100c15:	5b                   	pop    %ebx
f0100c16:	5d                   	pop    %ebp
f0100c17:	c3                   	ret    

f0100c18 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0100c18:	55                   	push   %ebp
f0100c19:	89 e5                	mov    %esp,%ebp
f0100c1b:	83 ec 18             	sub    $0x18,%esp
f0100c1e:	8b 45 08             	mov    0x8(%ebp),%eax
	// Fill this function in
    assert( pp->pp_ref==0 || pp->pp_link ==NULL);
f0100c21:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0100c26:	74 29                	je     f0100c51 <page_free+0x39>
f0100c28:	83 38 00             	cmpl   $0x0,(%eax)
f0100c2b:	74 24                	je     f0100c51 <page_free+0x39>
f0100c2d:	c7 44 24 0c 50 2c 10 	movl   $0xf0102c50,0xc(%esp)
f0100c34:	f0 
f0100c35:	c7 44 24 08 a0 2c 10 	movl   $0xf0102ca0,0x8(%esp)
f0100c3c:	f0 
f0100c3d:	c7 44 24 04 4d 01 00 	movl   $0x14d,0x4(%esp)
f0100c44:	00 
f0100c45:	c7 04 24 74 2c 10 f0 	movl   $0xf0102c74,(%esp)
f0100c4c:	e8 a7 f4 ff ff       	call   f01000f8 <_panic>
    pp->pp_link = page_free_list;
f0100c51:	8b 15 dc 81 17 f0    	mov    0xf01781dc,%edx
f0100c57:	89 10                	mov    %edx,(%eax)
    page_free_list =pp;
f0100c59:	a3 dc 81 17 f0       	mov    %eax,0xf01781dc
}
f0100c5e:	c9                   	leave  
f0100c5f:	c3                   	ret    

f0100c60 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0100c60:	55                   	push   %ebp
f0100c61:	89 e5                	mov    %esp,%ebp
f0100c63:	83 ec 18             	sub    $0x18,%esp
f0100c66:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100c69:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f0100c6d:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100c70:	66 89 50 04          	mov    %dx,0x4(%eax)
f0100c74:	66 85 d2             	test   %dx,%dx
f0100c77:	75 08                	jne    f0100c81 <page_decref+0x21>
		page_free(pp);
f0100c79:	89 04 24             	mov    %eax,(%esp)
f0100c7c:	e8 97 ff ff ff       	call   f0100c18 <page_free>
}
f0100c81:	c9                   	leave  
f0100c82:	c3                   	ret    

f0100c83 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100c83:	55                   	push   %ebp
f0100c84:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100c86:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c8b:	5d                   	pop    %ebp
f0100c8c:	c3                   	ret    

f0100c8d <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f0100c8d:	55                   	push   %ebp
f0100c8e:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return 0;
}
f0100c90:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c95:	5d                   	pop    %ebp
f0100c96:	c3                   	ret    

f0100c97 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0100c97:	55                   	push   %ebp
f0100c98:	89 e5                	mov    %esp,%ebp
	// Fill this function in
	return NULL;
}
f0100c9a:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c9f:	5d                   	pop    %ebp
f0100ca0:	c3                   	ret    

f0100ca1 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0100ca1:	55                   	push   %ebp
f0100ca2:	89 e5                	mov    %esp,%ebp
	// Fill this function in
}
f0100ca4:	5d                   	pop    %ebp
f0100ca5:	c3                   	ret    

f0100ca6 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0100ca6:	55                   	push   %ebp
f0100ca7:	89 e5                	mov    %esp,%ebp
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0100ca9:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100cac:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0100caf:	5d                   	pop    %ebp
f0100cb0:	c3                   	ret    

f0100cb1 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0100cb1:	55                   	push   %ebp
f0100cb2:	89 e5                	mov    %esp,%ebp
	// LAB 3: Your code here.

	return 0;
}
f0100cb4:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cb9:	5d                   	pop    %ebp
f0100cba:	c3                   	ret    

f0100cbb <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0100cbb:	55                   	push   %ebp
f0100cbc:	89 e5                	mov    %esp,%ebp
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
		cprintf("[%08x] user_mem_check assertion failure for "
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
	}
}
f0100cbe:	5d                   	pop    %ebp
f0100cbf:	c3                   	ret    

f0100cc0 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0100cc0:	55                   	push   %ebp
f0100cc1:	89 e5                	mov    %esp,%ebp
f0100cc3:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0100cc6:	85 c0                	test   %eax,%eax
f0100cc8:	75 11                	jne    f0100cdb <envid2env+0x1b>
		*env_store = curenv;
f0100cca:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f0100ccf:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0100cd2:	89 01                	mov    %eax,(%ecx)
		return 0;
f0100cd4:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cd9:	eb 60                	jmp    f0100d3b <envid2env+0x7b>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f0100cdb:	89 c2                	mov    %eax,%edx
f0100cdd:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100ce3:	8d 14 52             	lea    (%edx,%edx,2),%edx
f0100ce6:	c1 e2 05             	shl    $0x5,%edx
f0100ce9:	03 15 e8 81 17 f0    	add    0xf01781e8,%edx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f0100cef:	83 7a 54 00          	cmpl   $0x0,0x54(%edx)
f0100cf3:	74 05                	je     f0100cfa <envid2env+0x3a>
f0100cf5:	39 42 48             	cmp    %eax,0x48(%edx)
f0100cf8:	74 10                	je     f0100d0a <envid2env+0x4a>
		*env_store = 0;
f0100cfa:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100cfd:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0100d03:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0100d08:	eb 31                	jmp    f0100d3b <envid2env+0x7b>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0100d0a:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0100d0e:	74 21                	je     f0100d31 <envid2env+0x71>
f0100d10:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f0100d15:	39 c2                	cmp    %eax,%edx
f0100d17:	74 18                	je     f0100d31 <envid2env+0x71>
f0100d19:	8b 40 48             	mov    0x48(%eax),%eax
f0100d1c:	39 42 4c             	cmp    %eax,0x4c(%edx)
f0100d1f:	74 10                	je     f0100d31 <envid2env+0x71>
		*env_store = 0;
f0100d21:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100d24:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0100d2a:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0100d2f:	eb 0a                	jmp    f0100d3b <envid2env+0x7b>
	}

	*env_store = e;
f0100d31:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100d34:	89 10                	mov    %edx,(%eax)
	return 0;
f0100d36:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100d3b:	5d                   	pop    %ebp
f0100d3c:	c3                   	ret    

f0100d3d <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0100d3d:	55                   	push   %ebp
f0100d3e:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0100d40:	b8 00 63 11 f0       	mov    $0xf0116300,%eax
f0100d45:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f0100d48:	b8 23 00 00 00       	mov    $0x23,%eax
f0100d4d:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0100d4f:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0100d51:	b0 10                	mov    $0x10,%al
f0100d53:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0100d55:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f0100d57:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0100d59:	ea 60 0d 10 f0 08 00 	ljmp   $0x8,$0xf0100d60
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0100d60:	b0 00                	mov    $0x0,%al
f0100d62:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0100d65:	5d                   	pop    %ebp
f0100d66:	c3                   	ret    

f0100d67 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f0100d67:	55                   	push   %ebp
f0100d68:	89 e5                	mov    %esp,%ebp
	// Set up envs array
	// LAB 3: Your code here.

	// Per-CPU part of the initialization
	env_init_percpu();
f0100d6a:	e8 ce ff ff ff       	call   f0100d3d <env_init_percpu>
}
f0100d6f:	5d                   	pop    %ebp
f0100d70:	c3                   	ret    

f0100d71 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0100d71:	55                   	push   %ebp
f0100d72:	89 e5                	mov    %esp,%ebp
f0100d74:	53                   	push   %ebx
f0100d75:	83 ec 14             	sub    $0x14,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f0100d78:	8b 1d ec 81 17 f0    	mov    0xf01781ec,%ebx
f0100d7e:	85 db                	test   %ebx,%ebx
f0100d80:	0f 84 08 01 00 00    	je     f0100e8e <env_alloc+0x11d>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f0100d86:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0100d8d:	e8 01 fe ff ff       	call   f0100b93 <page_alloc>
f0100d92:	85 c0                	test   %eax,%eax
f0100d94:	0f 84 fb 00 00 00    	je     f0100e95 <env_alloc+0x124>

	// LAB 3: Your code here.

	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0100d9a:	8b 43 5c             	mov    0x5c(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100d9d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100da2:	77 20                	ja     f0100dc4 <env_alloc+0x53>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100da4:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100da8:	c7 44 24 08 b8 2c 10 	movl   $0xf0102cb8,0x8(%esp)
f0100daf:	f0 
f0100db0:	c7 44 24 04 b9 00 00 	movl   $0xb9,0x4(%esp)
f0100db7:	00 
f0100db8:	c7 04 24 32 2d 10 f0 	movl   $0xf0102d32,(%esp)
f0100dbf:	e8 34 f3 ff ff       	call   f01000f8 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100dc4:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0100dca:	83 ca 05             	or     $0x5,%edx
f0100dcd:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f0100dd3:	8b 43 48             	mov    0x48(%ebx),%eax
f0100dd6:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0100ddb:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0100de0:	ba 00 10 00 00       	mov    $0x1000,%edx
f0100de5:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0100de8:	89 da                	mov    %ebx,%edx
f0100dea:	2b 15 e8 81 17 f0    	sub    0xf01781e8,%edx
f0100df0:	c1 fa 05             	sar    $0x5,%edx
f0100df3:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0100df9:	09 d0                	or     %edx,%eax
f0100dfb:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f0100dfe:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100e01:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0100e04:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0100e0b:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
	e->env_runs = 0;
f0100e12:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0100e19:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0100e20:	00 
f0100e21:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100e28:	00 
f0100e29:	89 1c 24             	mov    %ebx,(%esp)
f0100e2c:	e8 6e 13 00 00       	call   f010219f <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0100e31:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f0100e37:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0100e3d:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0100e43:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f0100e4a:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
f0100e50:	8b 43 44             	mov    0x44(%ebx),%eax
f0100e53:	a3 ec 81 17 f0       	mov    %eax,0xf01781ec
	*newenv_store = e;
f0100e58:	8b 45 08             	mov    0x8(%ebp),%eax
f0100e5b:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0100e5d:	8b 53 48             	mov    0x48(%ebx),%edx
f0100e60:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f0100e65:	85 c0                	test   %eax,%eax
f0100e67:	74 05                	je     f0100e6e <env_alloc+0xfd>
f0100e69:	8b 40 48             	mov    0x48(%eax),%eax
f0100e6c:	eb 05                	jmp    f0100e73 <env_alloc+0x102>
f0100e6e:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e73:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100e77:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100e7b:	c7 04 24 3d 2d 10 f0 	movl   $0xf0102d3d,(%esp)
f0100e82:	e8 ef 02 00 00       	call   f0101176 <cprintf>
	return 0;
f0100e87:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e8c:	eb 0c                	jmp    f0100e9a <env_alloc+0x129>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0100e8e:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0100e93:	eb 05                	jmp    f0100e9a <env_alloc+0x129>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0100e95:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f0100e9a:	83 c4 14             	add    $0x14,%esp
f0100e9d:	5b                   	pop    %ebx
f0100e9e:	5d                   	pop    %ebp
f0100e9f:	c3                   	ret    

f0100ea0 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f0100ea0:	55                   	push   %ebp
f0100ea1:	89 e5                	mov    %esp,%ebp
	// LAB 3: Your code here.
}
f0100ea3:	5d                   	pop    %ebp
f0100ea4:	c3                   	ret    

f0100ea5 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0100ea5:	55                   	push   %ebp
f0100ea6:	89 e5                	mov    %esp,%ebp
f0100ea8:	57                   	push   %edi
f0100ea9:	56                   	push   %esi
f0100eaa:	53                   	push   %ebx
f0100eab:	83 ec 2c             	sub    $0x2c,%esp
f0100eae:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0100eb1:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f0100eb6:	39 c7                	cmp    %eax,%edi
f0100eb8:	75 37                	jne    f0100ef1 <env_free+0x4c>
		lcr3(PADDR(kern_pgdir));
f0100eba:	8b 15 a4 8e 17 f0    	mov    0xf0178ea4,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100ec0:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f0100ec6:	77 20                	ja     f0100ee8 <env_free+0x43>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100ec8:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100ecc:	c7 44 24 08 b8 2c 10 	movl   $0xf0102cb8,0x8(%esp)
f0100ed3:	f0 
f0100ed4:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
f0100edb:	00 
f0100edc:	c7 04 24 32 2d 10 f0 	movl   $0xf0102d32,(%esp)
f0100ee3:	e8 10 f2 ff ff       	call   f01000f8 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100ee8:	81 c2 00 00 00 10    	add    $0x10000000,%edx
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0100eee:	0f 22 da             	mov    %edx,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0100ef1:	8b 57 48             	mov    0x48(%edi),%edx
f0100ef4:	85 c0                	test   %eax,%eax
f0100ef6:	74 05                	je     f0100efd <env_free+0x58>
f0100ef8:	8b 40 48             	mov    0x48(%eax),%eax
f0100efb:	eb 05                	jmp    f0100f02 <env_free+0x5d>
f0100efd:	b8 00 00 00 00       	mov    $0x0,%eax
f0100f02:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100f06:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100f0a:	c7 04 24 52 2d 10 f0 	movl   $0xf0102d52,(%esp)
f0100f11:	e8 60 02 00 00       	call   f0101176 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0100f16:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0100f1d:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0100f20:	89 c8                	mov    %ecx,%eax
f0100f22:	c1 e0 02             	shl    $0x2,%eax
f0100f25:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0100f28:	8b 47 5c             	mov    0x5c(%edi),%eax
f0100f2b:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0100f2e:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0100f34:	0f 84 b7 00 00 00    	je     f0100ff1 <env_free+0x14c>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0100f3a:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100f40:	89 f0                	mov    %esi,%eax
f0100f42:	c1 e8 0c             	shr    $0xc,%eax
f0100f45:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100f48:	3b 05 a0 8e 17 f0    	cmp    0xf0178ea0,%eax
f0100f4e:	72 20                	jb     f0100f70 <env_free+0xcb>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100f50:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100f54:	c7 44 24 08 2c 2c 10 	movl   $0xf0102c2c,0x8(%esp)
f0100f5b:	f0 
f0100f5c:	c7 44 24 04 77 01 00 	movl   $0x177,0x4(%esp)
f0100f63:	00 
f0100f64:	c7 04 24 32 2d 10 f0 	movl   $0xf0102d32,(%esp)
f0100f6b:	e8 88 f1 ff ff       	call   f01000f8 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0100f70:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100f73:	c1 e0 16             	shl    $0x16,%eax
f0100f76:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0100f79:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0100f7e:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0100f85:	01 
f0100f86:	74 17                	je     f0100f9f <env_free+0xfa>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0100f88:	89 d8                	mov    %ebx,%eax
f0100f8a:	c1 e0 0c             	shl    $0xc,%eax
f0100f8d:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0100f90:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100f94:	8b 47 5c             	mov    0x5c(%edi),%eax
f0100f97:	89 04 24             	mov    %eax,(%esp)
f0100f9a:	e8 02 fd ff ff       	call   f0100ca1 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0100f9f:	83 c3 01             	add    $0x1,%ebx
f0100fa2:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0100fa8:	75 d4                	jne    f0100f7e <env_free+0xd9>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0100faa:	8b 47 5c             	mov    0x5c(%edi),%eax
f0100fad:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100fb0:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fb7:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100fba:	3b 05 a0 8e 17 f0    	cmp    0xf0178ea0,%eax
f0100fc0:	72 1c                	jb     f0100fde <env_free+0x139>
		panic("pa2page called with invalid pa");
f0100fc2:	c7 44 24 08 dc 2c 10 	movl   $0xf0102cdc,0x8(%esp)
f0100fc9:	f0 
f0100fca:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100fd1:	00 
f0100fd2:	c7 04 24 92 2c 10 f0 	movl   $0xf0102c92,(%esp)
f0100fd9:	e8 1a f1 ff ff       	call   f01000f8 <_panic>
	return &pages[PGNUM(pa)];
f0100fde:	a1 a8 8e 17 f0       	mov    0xf0178ea8,%eax
f0100fe3:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100fe6:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0100fe9:	89 04 24             	mov    %eax,(%esp)
f0100fec:	e8 6f fc ff ff       	call   f0100c60 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0100ff1:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0100ff5:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0100ffc:	0f 85 1b ff ff ff    	jne    f0100f1d <env_free+0x78>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0101002:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101005:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010100a:	77 20                	ja     f010102c <env_free+0x187>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010100c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101010:	c7 44 24 08 b8 2c 10 	movl   $0xf0102cb8,0x8(%esp)
f0101017:	f0 
f0101018:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
f010101f:	00 
f0101020:	c7 04 24 32 2d 10 f0 	movl   $0xf0102d32,(%esp)
f0101027:	e8 cc f0 ff ff       	call   f01000f8 <_panic>
	e->env_pgdir = 0;
f010102c:	c7 47 5c 00 00 00 00 	movl   $0x0,0x5c(%edi)
	return (physaddr_t)kva - KERNBASE;
f0101033:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101038:	c1 e8 0c             	shr    $0xc,%eax
f010103b:	3b 05 a0 8e 17 f0    	cmp    0xf0178ea0,%eax
f0101041:	72 1c                	jb     f010105f <env_free+0x1ba>
		panic("pa2page called with invalid pa");
f0101043:	c7 44 24 08 dc 2c 10 	movl   $0xf0102cdc,0x8(%esp)
f010104a:	f0 
f010104b:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101052:	00 
f0101053:	c7 04 24 92 2c 10 f0 	movl   $0xf0102c92,(%esp)
f010105a:	e8 99 f0 ff ff       	call   f01000f8 <_panic>
	return &pages[PGNUM(pa)];
f010105f:	8b 15 a8 8e 17 f0    	mov    0xf0178ea8,%edx
f0101065:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0101068:	89 04 24             	mov    %eax,(%esp)
f010106b:	e8 f0 fb ff ff       	call   f0100c60 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0101070:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0101077:	a1 ec 81 17 f0       	mov    0xf01781ec,%eax
f010107c:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f010107f:	89 3d ec 81 17 f0    	mov    %edi,0xf01781ec
}
f0101085:	83 c4 2c             	add    $0x2c,%esp
f0101088:	5b                   	pop    %ebx
f0101089:	5e                   	pop    %esi
f010108a:	5f                   	pop    %edi
f010108b:	5d                   	pop    %ebp
f010108c:	c3                   	ret    

f010108d <env_destroy>:
//
// Frees environment e.
//
void
env_destroy(struct Env *e)
{
f010108d:	55                   	push   %ebp
f010108e:	89 e5                	mov    %esp,%ebp
f0101090:	83 ec 18             	sub    $0x18,%esp
	env_free(e);
f0101093:	8b 45 08             	mov    0x8(%ebp),%eax
f0101096:	89 04 24             	mov    %eax,(%esp)
f0101099:	e8 07 fe ff ff       	call   f0100ea5 <env_free>

	cprintf("Destroyed the only environment - nothing more to do!\n");
f010109e:	c7 04 24 fc 2c 10 f0 	movl   $0xf0102cfc,(%esp)
f01010a5:	e8 cc 00 00 00       	call   f0101176 <cprintf>
	while (1)
		monitor(NULL);
f01010aa:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01010b1:	e8 61 f7 ff ff       	call   f0100817 <monitor>
f01010b6:	eb f2                	jmp    f01010aa <env_destroy+0x1d>

f01010b8 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f01010b8:	55                   	push   %ebp
f01010b9:	89 e5                	mov    %esp,%ebp
f01010bb:	83 ec 18             	sub    $0x18,%esp
	__asm __volatile("movl %0,%%esp\n"
f01010be:	8b 65 08             	mov    0x8(%ebp),%esp
f01010c1:	61                   	popa   
f01010c2:	07                   	pop    %es
f01010c3:	1f                   	pop    %ds
f01010c4:	83 c4 08             	add    $0x8,%esp
f01010c7:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f01010c8:	c7 44 24 08 68 2d 10 	movl   $0xf0102d68,0x8(%esp)
f01010cf:	f0 
f01010d0:	c7 44 24 04 ad 01 00 	movl   $0x1ad,0x4(%esp)
f01010d7:	00 
f01010d8:	c7 04 24 32 2d 10 f0 	movl   $0xf0102d32,(%esp)
f01010df:	e8 14 f0 ff ff       	call   f01000f8 <_panic>

f01010e4 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f01010e4:	55                   	push   %ebp
f01010e5:	89 e5                	mov    %esp,%ebp
f01010e7:	83 ec 18             	sub    $0x18,%esp
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.

	panic("env_run not yet implemented");
f01010ea:	c7 44 24 08 74 2d 10 	movl   $0xf0102d74,0x8(%esp)
f01010f1:	f0 
f01010f2:	c7 44 24 04 cc 01 00 	movl   $0x1cc,0x4(%esp)
f01010f9:	00 
f01010fa:	c7 04 24 32 2d 10 f0 	movl   $0xf0102d32,(%esp)
f0101101:	e8 f2 ef ff ff       	call   f01000f8 <_panic>

f0101106 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0101106:	55                   	push   %ebp
f0101107:	89 e5                	mov    %esp,%ebp
f0101109:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010110d:	ba 70 00 00 00       	mov    $0x70,%edx
f0101112:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0101113:	b2 71                	mov    $0x71,%dl
f0101115:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0101116:	0f b6 c0             	movzbl %al,%eax
}
f0101119:	5d                   	pop    %ebp
f010111a:	c3                   	ret    

f010111b <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f010111b:	55                   	push   %ebp
f010111c:	89 e5                	mov    %esp,%ebp
f010111e:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0101122:	ba 70 00 00 00       	mov    $0x70,%edx
f0101127:	ee                   	out    %al,(%dx)
f0101128:	b2 71                	mov    $0x71,%dl
f010112a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010112d:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f010112e:	5d                   	pop    %ebp
f010112f:	c3                   	ret    

f0101130 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0101130:	55                   	push   %ebp
f0101131:	89 e5                	mov    %esp,%ebp
f0101133:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0101136:	8b 45 08             	mov    0x8(%ebp),%eax
f0101139:	89 04 24             	mov    %eax,(%esp)
f010113c:	e8 23 f5 ff ff       	call   f0100664 <cputchar>
	*cnt++;
}
f0101141:	c9                   	leave  
f0101142:	c3                   	ret    

f0101143 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0101143:	55                   	push   %ebp
f0101144:	89 e5                	mov    %esp,%ebp
f0101146:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0101149:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0101150:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101153:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101157:	8b 45 08             	mov    0x8(%ebp),%eax
f010115a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010115e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101161:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101165:	c7 04 24 30 11 10 f0 	movl   $0xf0101130,(%esp)
f010116c:	e8 59 08 00 00       	call   f01019ca <vprintfmt>
	return cnt;
}
f0101171:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101174:	c9                   	leave  
f0101175:	c3                   	ret    

f0101176 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0101176:	55                   	push   %ebp
f0101177:	89 e5                	mov    %esp,%ebp
f0101179:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f010117c:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f010117f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101183:	8b 45 08             	mov    0x8(%ebp),%eax
f0101186:	89 04 24             	mov    %eax,(%esp)
f0101189:	e8 b5 ff ff ff       	call   f0101143 <vcprintf>
	va_end(ap);

	return cnt;
}
f010118e:	c9                   	leave  
f010118f:	c3                   	ret    

f0101190 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0101190:	55                   	push   %ebp
f0101191:	89 e5                	mov    %esp,%ebp
	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f0101193:	c7 05 24 8a 17 f0 00 	movl   $0xefc00000,0xf0178a24
f010119a:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f010119d:	66 c7 05 28 8a 17 f0 	movw   $0x10,0xf0178a28
f01011a4:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f01011a6:	66 c7 05 48 63 11 f0 	movw   $0x68,0xf0116348
f01011ad:	68 00 
f01011af:	b8 20 8a 17 f0       	mov    $0xf0178a20,%eax
f01011b4:	66 a3 4a 63 11 f0    	mov    %ax,0xf011634a
f01011ba:	89 c2                	mov    %eax,%edx
f01011bc:	c1 ea 10             	shr    $0x10,%edx
f01011bf:	88 15 4c 63 11 f0    	mov    %dl,0xf011634c
f01011c5:	c6 05 4e 63 11 f0 40 	movb   $0x40,0xf011634e
f01011cc:	c1 e8 18             	shr    $0x18,%eax
f01011cf:	a2 4f 63 11 f0       	mov    %al,0xf011634f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f01011d4:	c6 05 4d 63 11 f0 89 	movb   $0x89,0xf011634d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f01011db:	b8 28 00 00 00       	mov    $0x28,%eax
f01011e0:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f01011e3:	b8 50 63 11 f0       	mov    $0xf0116350,%eax
f01011e8:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f01011eb:	5d                   	pop    %ebp
f01011ec:	c3                   	ret    

f01011ed <trap_init>:
}


void
trap_init(void)
{
f01011ed:	55                   	push   %ebp
f01011ee:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];

	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f01011f0:	e8 9b ff ff ff       	call   f0101190 <trap_init_percpu>
}
f01011f5:	5d                   	pop    %ebp
f01011f6:	c3                   	ret    

f01011f7 <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01011f7:	55                   	push   %ebp
f01011f8:	89 e5                	mov    %esp,%ebp
f01011fa:	53                   	push   %ebx
f01011fb:	83 ec 14             	sub    $0x14,%esp
f01011fe:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0101201:	8b 03                	mov    (%ebx),%eax
f0101203:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101207:	c7 04 24 90 2d 10 f0 	movl   $0xf0102d90,(%esp)
f010120e:	e8 63 ff ff ff       	call   f0101176 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0101213:	8b 43 04             	mov    0x4(%ebx),%eax
f0101216:	89 44 24 04          	mov    %eax,0x4(%esp)
f010121a:	c7 04 24 9f 2d 10 f0 	movl   $0xf0102d9f,(%esp)
f0101221:	e8 50 ff ff ff       	call   f0101176 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f0101226:	8b 43 08             	mov    0x8(%ebx),%eax
f0101229:	89 44 24 04          	mov    %eax,0x4(%esp)
f010122d:	c7 04 24 ae 2d 10 f0 	movl   $0xf0102dae,(%esp)
f0101234:	e8 3d ff ff ff       	call   f0101176 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f0101239:	8b 43 0c             	mov    0xc(%ebx),%eax
f010123c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101240:	c7 04 24 bd 2d 10 f0 	movl   $0xf0102dbd,(%esp)
f0101247:	e8 2a ff ff ff       	call   f0101176 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f010124c:	8b 43 10             	mov    0x10(%ebx),%eax
f010124f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101253:	c7 04 24 cc 2d 10 f0 	movl   $0xf0102dcc,(%esp)
f010125a:	e8 17 ff ff ff       	call   f0101176 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f010125f:	8b 43 14             	mov    0x14(%ebx),%eax
f0101262:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101266:	c7 04 24 db 2d 10 f0 	movl   $0xf0102ddb,(%esp)
f010126d:	e8 04 ff ff ff       	call   f0101176 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0101272:	8b 43 18             	mov    0x18(%ebx),%eax
f0101275:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101279:	c7 04 24 ea 2d 10 f0 	movl   $0xf0102dea,(%esp)
f0101280:	e8 f1 fe ff ff       	call   f0101176 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f0101285:	8b 43 1c             	mov    0x1c(%ebx),%eax
f0101288:	89 44 24 04          	mov    %eax,0x4(%esp)
f010128c:	c7 04 24 f9 2d 10 f0 	movl   $0xf0102df9,(%esp)
f0101293:	e8 de fe ff ff       	call   f0101176 <cprintf>
}
f0101298:	83 c4 14             	add    $0x14,%esp
f010129b:	5b                   	pop    %ebx
f010129c:	5d                   	pop    %ebp
f010129d:	c3                   	ret    

f010129e <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f010129e:	55                   	push   %ebp
f010129f:	89 e5                	mov    %esp,%ebp
f01012a1:	56                   	push   %esi
f01012a2:	53                   	push   %ebx
f01012a3:	83 ec 10             	sub    $0x10,%esp
f01012a6:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p\n", tf);
f01012a9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01012ad:	c7 04 24 2f 2f 10 f0 	movl   $0xf0102f2f,(%esp)
f01012b4:	e8 bd fe ff ff       	call   f0101176 <cprintf>
	print_regs(&tf->tf_regs);
f01012b9:	89 1c 24             	mov    %ebx,(%esp)
f01012bc:	e8 36 ff ff ff       	call   f01011f7 <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01012c1:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01012c5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012c9:	c7 04 24 4a 2e 10 f0 	movl   $0xf0102e4a,(%esp)
f01012d0:	e8 a1 fe ff ff       	call   f0101176 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01012d5:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01012d9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012dd:	c7 04 24 5d 2e 10 f0 	movl   $0xf0102e5d,(%esp)
f01012e4:	e8 8d fe ff ff       	call   f0101176 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01012e9:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01012ec:	83 f8 13             	cmp    $0x13,%eax
f01012ef:	77 09                	ja     f01012fa <print_trapframe+0x5c>
		return excnames[trapno];
f01012f1:	8b 14 85 00 31 10 f0 	mov    -0xfefcf00(,%eax,4),%edx
f01012f8:	eb 10                	jmp    f010130a <print_trapframe+0x6c>
	if (trapno == T_SYSCALL)
		return "System call";
f01012fa:	83 f8 30             	cmp    $0x30,%eax
f01012fd:	ba 08 2e 10 f0       	mov    $0xf0102e08,%edx
f0101302:	b9 14 2e 10 f0       	mov    $0xf0102e14,%ecx
f0101307:	0f 45 d1             	cmovne %ecx,%edx
{
	cprintf("TRAP frame at %p\n", tf);
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f010130a:	89 54 24 08          	mov    %edx,0x8(%esp)
f010130e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101312:	c7 04 24 70 2e 10 f0 	movl   $0xf0102e70,(%esp)
f0101319:	e8 58 fe ff ff       	call   f0101176 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010131e:	3b 1d 00 8a 17 f0    	cmp    0xf0178a00,%ebx
f0101324:	75 19                	jne    f010133f <print_trapframe+0xa1>
f0101326:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f010132a:	75 13                	jne    f010133f <print_trapframe+0xa1>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010132c:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010132f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101333:	c7 04 24 82 2e 10 f0 	movl   $0xf0102e82,(%esp)
f010133a:	e8 37 fe ff ff       	call   f0101176 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010133f:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0101342:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101346:	c7 04 24 91 2e 10 f0 	movl   $0xf0102e91,(%esp)
f010134d:	e8 24 fe ff ff       	call   f0101176 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0101352:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0101356:	75 51                	jne    f01013a9 <print_trapframe+0x10b>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0101358:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f010135b:	89 c2                	mov    %eax,%edx
f010135d:	83 e2 01             	and    $0x1,%edx
f0101360:	ba 23 2e 10 f0       	mov    $0xf0102e23,%edx
f0101365:	b9 2e 2e 10 f0       	mov    $0xf0102e2e,%ecx
f010136a:	0f 45 ca             	cmovne %edx,%ecx
f010136d:	89 c2                	mov    %eax,%edx
f010136f:	83 e2 02             	and    $0x2,%edx
f0101372:	ba 3a 2e 10 f0       	mov    $0xf0102e3a,%edx
f0101377:	be 40 2e 10 f0       	mov    $0xf0102e40,%esi
f010137c:	0f 44 d6             	cmove  %esi,%edx
f010137f:	83 e0 04             	and    $0x4,%eax
f0101382:	b8 45 2e 10 f0       	mov    $0xf0102e45,%eax
f0101387:	be 5a 2f 10 f0       	mov    $0xf0102f5a,%esi
f010138c:	0f 44 c6             	cmove  %esi,%eax
f010138f:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101393:	89 54 24 08          	mov    %edx,0x8(%esp)
f0101397:	89 44 24 04          	mov    %eax,0x4(%esp)
f010139b:	c7 04 24 9f 2e 10 f0 	movl   $0xf0102e9f,(%esp)
f01013a2:	e8 cf fd ff ff       	call   f0101176 <cprintf>
f01013a7:	eb 0c                	jmp    f01013b5 <print_trapframe+0x117>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01013a9:	c7 04 24 0e 27 10 f0 	movl   $0xf010270e,(%esp)
f01013b0:	e8 c1 fd ff ff       	call   f0101176 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01013b5:	8b 43 30             	mov    0x30(%ebx),%eax
f01013b8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01013bc:	c7 04 24 ae 2e 10 f0 	movl   $0xf0102eae,(%esp)
f01013c3:	e8 ae fd ff ff       	call   f0101176 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01013c8:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01013cc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01013d0:	c7 04 24 bd 2e 10 f0 	movl   $0xf0102ebd,(%esp)
f01013d7:	e8 9a fd ff ff       	call   f0101176 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01013dc:	8b 43 38             	mov    0x38(%ebx),%eax
f01013df:	89 44 24 04          	mov    %eax,0x4(%esp)
f01013e3:	c7 04 24 d0 2e 10 f0 	movl   $0xf0102ed0,(%esp)
f01013ea:	e8 87 fd ff ff       	call   f0101176 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01013ef:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01013f3:	74 27                	je     f010141c <print_trapframe+0x17e>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01013f5:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01013f8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01013fc:	c7 04 24 df 2e 10 f0 	movl   $0xf0102edf,(%esp)
f0101403:	e8 6e fd ff ff       	call   f0101176 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0101408:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010140c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101410:	c7 04 24 ee 2e 10 f0 	movl   $0xf0102eee,(%esp)
f0101417:	e8 5a fd ff ff       	call   f0101176 <cprintf>
	}
}
f010141c:	83 c4 10             	add    $0x10,%esp
f010141f:	5b                   	pop    %ebx
f0101420:	5e                   	pop    %esi
f0101421:	5d                   	pop    %ebp
f0101422:	c3                   	ret    

f0101423 <trap>:
	}
}

void
trap(struct Trapframe *tf)
{
f0101423:	55                   	push   %ebp
f0101424:	89 e5                	mov    %esp,%ebp
f0101426:	57                   	push   %edi
f0101427:	56                   	push   %esi
f0101428:	83 ec 10             	sub    $0x10,%esp
f010142b:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f010142e:	fc                   	cld    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f010142f:	9c                   	pushf  
f0101430:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f0101431:	f6 c4 02             	test   $0x2,%ah
f0101434:	74 24                	je     f010145a <trap+0x37>
f0101436:	c7 44 24 0c 01 2f 10 	movl   $0xf0102f01,0xc(%esp)
f010143d:	f0 
f010143e:	c7 44 24 08 a0 2c 10 	movl   $0xf0102ca0,0x8(%esp)
f0101445:	f0 
f0101446:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
f010144d:	00 
f010144e:	c7 04 24 1a 2f 10 f0 	movl   $0xf0102f1a,(%esp)
f0101455:	e8 9e ec ff ff       	call   f01000f8 <_panic>

	cprintf("Incoming TRAP frame at %p\n", tf);
f010145a:	89 74 24 04          	mov    %esi,0x4(%esp)
f010145e:	c7 04 24 26 2f 10 f0 	movl   $0xf0102f26,(%esp)
f0101465:	e8 0c fd ff ff       	call   f0101176 <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f010146a:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f010146e:	83 e0 03             	and    $0x3,%eax
f0101471:	66 83 f8 03          	cmp    $0x3,%ax
f0101475:	75 3c                	jne    f01014b3 <trap+0x90>
		// Trapped from user mode.
		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		assert(curenv);
f0101477:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f010147c:	85 c0                	test   %eax,%eax
f010147e:	75 24                	jne    f01014a4 <trap+0x81>
f0101480:	c7 44 24 0c 41 2f 10 	movl   $0xf0102f41,0xc(%esp)
f0101487:	f0 
f0101488:	c7 44 24 08 a0 2c 10 	movl   $0xf0102ca0,0x8(%esp)
f010148f:	f0 
f0101490:	c7 44 24 04 b0 00 00 	movl   $0xb0,0x4(%esp)
f0101497:	00 
f0101498:	c7 04 24 1a 2f 10 f0 	movl   $0xf0102f1a,(%esp)
f010149f:	e8 54 ec ff ff       	call   f01000f8 <_panic>
		curenv->env_tf = *tf;
f01014a4:	b9 11 00 00 00       	mov    $0x11,%ecx
f01014a9:	89 c7                	mov    %eax,%edi
f01014ab:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f01014ad:	8b 35 e4 81 17 f0    	mov    0xf01781e4,%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f01014b3:	89 35 00 8a 17 f0    	mov    %esi,0xf0178a00
{
	// Handle processor exceptions.
	// LAB 3: Your code here.

	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
f01014b9:	89 34 24             	mov    %esi,(%esp)
f01014bc:	e8 dd fd ff ff       	call   f010129e <print_trapframe>
	if (tf->tf_cs == GD_KT)
f01014c1:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f01014c6:	75 1c                	jne    f01014e4 <trap+0xc1>
		panic("unhandled trap in kernel");
f01014c8:	c7 44 24 08 48 2f 10 	movl   $0xf0102f48,0x8(%esp)
f01014cf:	f0 
f01014d0:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f01014d7:	00 
f01014d8:	c7 04 24 1a 2f 10 f0 	movl   $0xf0102f1a,(%esp)
f01014df:	e8 14 ec ff ff       	call   f01000f8 <_panic>
	else {
		env_destroy(curenv);
f01014e4:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f01014e9:	89 04 24             	mov    %eax,(%esp)
f01014ec:	e8 9c fb ff ff       	call   f010108d <env_destroy>

	// Dispatch based on what type of trap occurred
	trap_dispatch(tf);

	// Return to the current environment, which should be running.
	assert(curenv && curenv->env_status == ENV_RUNNING);
f01014f1:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f01014f6:	85 c0                	test   %eax,%eax
f01014f8:	74 06                	je     f0101500 <trap+0xdd>
f01014fa:	83 78 54 02          	cmpl   $0x2,0x54(%eax)
f01014fe:	74 24                	je     f0101524 <trap+0x101>
f0101500:	c7 44 24 0c a4 30 10 	movl   $0xf01030a4,0xc(%esp)
f0101507:	f0 
f0101508:	c7 44 24 08 a0 2c 10 	movl   $0xf0102ca0,0x8(%esp)
f010150f:	f0 
f0101510:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f0101517:	00 
f0101518:	c7 04 24 1a 2f 10 f0 	movl   $0xf0102f1a,(%esp)
f010151f:	e8 d4 eb ff ff       	call   f01000f8 <_panic>
	env_run(curenv);
f0101524:	89 04 24             	mov    %eax,(%esp)
f0101527:	e8 b8 fb ff ff       	call   f01010e4 <env_run>

f010152c <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f010152c:	55                   	push   %ebp
f010152d:	89 e5                	mov    %esp,%ebp
f010152f:	53                   	push   %ebx
f0101530:	83 ec 14             	sub    $0x14,%esp
f0101533:	8b 5d 08             	mov    0x8(%ebp),%ebx

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0101536:	0f 20 d0             	mov    %cr2,%eax

	// We've already handled kernel-mode exceptions, so if we get here,
	// the page fault happened in user mode.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0101539:	8b 53 30             	mov    0x30(%ebx),%edx
f010153c:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101540:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101544:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f0101549:	8b 40 48             	mov    0x48(%eax),%eax
f010154c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101550:	c7 04 24 d0 30 10 f0 	movl   $0xf01030d0,(%esp)
f0101557:	e8 1a fc ff ff       	call   f0101176 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
f010155c:	89 1c 24             	mov    %ebx,(%esp)
f010155f:	e8 3a fd ff ff       	call   f010129e <print_trapframe>
	env_destroy(curenv);
f0101564:	a1 e4 81 17 f0       	mov    0xf01781e4,%eax
f0101569:	89 04 24             	mov    %eax,(%esp)
f010156c:	e8 1c fb ff ff       	call   f010108d <env_destroy>
}
f0101571:	83 c4 14             	add    $0x14,%esp
f0101574:	5b                   	pop    %ebx
f0101575:	5d                   	pop    %ebp
f0101576:	c3                   	ret    

f0101577 <syscall>:
f0101577:	55                   	push   %ebp
f0101578:	89 e5                	mov    %esp,%ebp
f010157a:	83 ec 18             	sub    $0x18,%esp
f010157d:	c7 44 24 08 50 31 10 	movl   $0xf0103150,0x8(%esp)
f0101584:	f0 
f0101585:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
f010158c:	00 
f010158d:	c7 04 24 68 31 10 f0 	movl   $0xf0103168,(%esp)
f0101594:	e8 5f eb ff ff       	call   f01000f8 <_panic>
f0101599:	66 90                	xchg   %ax,%ax
f010159b:	66 90                	xchg   %ax,%ax
f010159d:	66 90                	xchg   %ax,%ax
f010159f:	90                   	nop

f01015a0 <stab_binsearch>:
//		13     SO     f0100040
//		117    SO     f0100176
//		118    SO     f0100178
//		555    SO     f0100652
//		556    SO     f0100654
//		657    SO     f0100849
f01015a0:	55                   	push   %ebp
f01015a1:	89 e5                	mov    %esp,%ebp
f01015a3:	57                   	push   %edi
f01015a4:	56                   	push   %esi
f01015a5:	53                   	push   %ebx
f01015a6:	83 ec 10             	sub    $0x10,%esp
f01015a9:	89 c6                	mov    %eax,%esi
f01015ab:	89 55 e8             	mov    %edx,-0x18(%ebp)
f01015ae:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f01015b1:	8b 7d 08             	mov    0x8(%ebp),%edi
//	this code:
f01015b4:	8b 1a                	mov    (%edx),%ebx
f01015b6:	8b 01                	mov    (%ecx),%eax
f01015b8:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01015bb:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
//		left = 0, right = 657;
//		stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
f01015c2:	eb 77                	jmp    f010163b <stab_binsearch+0x9b>
//	will exit setting left = 118, right = 554.
f01015c4:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01015c7:	01 d8                	add    %ebx,%eax
f01015c9:	b9 02 00 00 00       	mov    $0x2,%ecx
f01015ce:	99                   	cltd   
f01015cf:	f7 f9                	idiv   %ecx
f01015d1:	89 c1                	mov    %eax,%ecx
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
f01015d3:	eb 01                	jmp    f01015d6 <stab_binsearch+0x36>
	       int type, uintptr_t addr)
f01015d5:	49                   	dec    %ecx
//		left = 0, right = 657;
//		stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
f01015d6:	39 d9                	cmp    %ebx,%ecx
f01015d8:	7c 1d                	jl     f01015f7 <stab_binsearch+0x57>
f01015da:	6b d1 0c             	imul   $0xc,%ecx,%edx
f01015dd:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f01015e2:	39 fa                	cmp    %edi,%edx
f01015e4:	75 ef                	jne    f01015d5 <stab_binsearch+0x35>
f01015e6:	89 4d ec             	mov    %ecx,-0x14(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01015e9:	6b d1 0c             	imul   $0xc,%ecx,%edx
f01015ec:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f01015f0:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01015f3:	73 18                	jae    f010160d <stab_binsearch+0x6d>
f01015f5:	eb 05                	jmp    f01015fc <stab_binsearch+0x5c>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f01015f7:	8d 58 01             	lea    0x1(%eax),%ebx
	
f01015fa:	eb 3f                	jmp    f010163b <stab_binsearch+0x9b>
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f01015fc:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f01015ff:	89 0b                	mov    %ecx,(%ebx)
		if (m < l) {	// no match in [l, m]
f0101601:	8d 58 01             	lea    0x1(%eax),%ebx
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
f0101604:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f010160b:	eb 2e                	jmp    f010163b <stab_binsearch+0x9b>
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f010160d:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0101610:	73 15                	jae    f0101627 <stab_binsearch+0x87>
			continue;
f0101612:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0101615:	48                   	dec    %eax
f0101616:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0101619:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f010161c:	89 01                	mov    %eax,(%ecx)
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
f010161e:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0101625:	eb 14                	jmp    f010163b <stab_binsearch+0x9b>
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0101627:	8b 45 e8             	mov    -0x18(%ebp),%eax
f010162a:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f010162d:	89 18                	mov    %ebx,(%eax)
			*region_left = m;
			l = true_m + 1;
f010162f:	ff 45 0c             	incl   0xc(%ebp)
f0101632:	89 cb                	mov    %ecx,%ebx
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
f0101634:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
//		555    SO     f0100652
//		556    SO     f0100654
//		657    SO     f0100849
//	this code:
//		left = 0, right = 657;
//		stab_binsearch(stabs, &left, &right, N_SO, 0xf0100184);
f010163b:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f010163e:	7e 84                	jle    f01015c4 <stab_binsearch+0x24>
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
			*region_right = m - 1;
			r = m - 1;
		} else {
f0101640:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0101644:	75 0d                	jne    f0101653 <stab_binsearch+0xb3>
			// exact match for 'addr', but continue loop to find
f0101646:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0101649:	8b 00                	mov    (%eax),%eax
f010164b:	48                   	dec    %eax
f010164c:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010164f:	89 07                	mov    %eax,(%edi)
f0101651:	eb 22                	jmp    f0101675 <stab_binsearch+0xd5>
			// *region_right
			*region_left = m;
			l = m;
f0101653:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101656:	8b 00                	mov    (%eax),%eax
			addr++;
f0101658:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f010165b:	8b 0b                	mov    (%ebx),%ecx
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
			l = m;
f010165d:	eb 01                	jmp    f0101660 <stab_binsearch+0xc0>
			addr++;
		}
f010165f:	48                   	dec    %eax
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
			l = m;
f0101660:	39 c1                	cmp    %eax,%ecx
f0101662:	7d 0c                	jge    f0101670 <stab_binsearch+0xd0>
f0101664:	6b d0 0c             	imul   $0xc,%eax,%edx
			addr++;
f0101667:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f010166c:	39 fa                	cmp    %edi,%edx
f010166e:	75 ef                	jne    f010165f <stab_binsearch+0xbf>
		}
	}

f0101670:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0101673:	89 07                	mov    %eax,(%edi)
	if (!any_matches)
		*region_right = *region_left - 1;
f0101675:	83 c4 10             	add    $0x10,%esp
f0101678:	5b                   	pop    %ebx
f0101679:	5e                   	pop    %esi
f010167a:	5f                   	pop    %edi
f010167b:	5d                   	pop    %ebp
f010167c:	c3                   	ret    

f010167d <debuginfo_eip>:
		*region_left = l;
	}
}


// debuginfo_eip(addr, info)
f010167d:	55                   	push   %ebp
f010167e:	89 e5                	mov    %esp,%ebp
f0101680:	57                   	push   %edi
f0101681:	56                   	push   %esi
f0101682:	53                   	push   %ebx
f0101683:	83 ec 2c             	sub    $0x2c,%esp
f0101686:	8b 75 08             	mov    0x8(%ebp),%esi
f0101689:	8b 5d 0c             	mov    0xc(%ebp),%ebx
//
//	Fill in the 'info' structure with information about the specified
//	instruction address, 'addr'.  Returns 0 if information was found, and
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
f010168c:	c7 03 77 31 10 f0    	movl   $0xf0103177,(%ebx)
int
f0101692:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
f0101699:	c7 43 08 77 31 10 f0 	movl   $0xf0103177,0x8(%ebx)
{
f01016a0:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	const struct Stab *stabs, *stab_end;
f01016a7:	89 73 10             	mov    %esi,0x10(%ebx)
	const char *stabstr, *stabstr_end;
f01016aa:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
f01016b1:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f01016b7:	76 12                	jbe    f01016cb <debuginfo_eip+0x4e>
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f01016b9:	b8 c4 b7 10 f0       	mov    $0xf010b7c4,%eax
f01016be:	3d 19 8b 10 f0       	cmp    $0xf0108b19,%eax
f01016c3:	0f 86 8b 01 00 00    	jbe    f0101854 <debuginfo_eip+0x1d7>
f01016c9:	eb 1c                	jmp    f01016e7 <debuginfo_eip+0x6a>
	info->eip_line = 0;
	info->eip_fn_name = "<unknown>";
	info->eip_fn_namelen = 9;
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

f01016cb:	c7 44 24 08 81 31 10 	movl   $0xf0103181,0x8(%esp)
f01016d2:	f0 
f01016d3:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f01016da:	00 
f01016db:	c7 04 24 8e 31 10 f0 	movl   $0xf010318e,(%esp)
f01016e2:	e8 11 ea ff ff       	call   f01000f8 <_panic>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f01016e7:	80 3d c3 b7 10 f0 00 	cmpb   $0x0,0xf010b7c3
f01016ee:	0f 85 67 01 00 00    	jne    f010185b <debuginfo_eip+0x1de>
		// The user-application linker script, user/user.ld,
		// puts information about the application's stabs (equivalent
		// to __STAB_BEGIN__, __STAB_END__, __STABSTR_BEGIN__, and
		// __STABSTR_END__) in a structure located at virtual address
		// USTABDATA.
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;
f01016f4:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)

f01016fb:	b8 18 8b 10 f0       	mov    $0xf0108b18,%eax
f0101700:	2d ac 33 10 f0       	sub    $0xf01033ac,%eax
f0101705:	c1 f8 02             	sar    $0x2,%eax
f0101708:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f010170e:	83 e8 01             	sub    $0x1,%eax
f0101711:	89 45 e0             	mov    %eax,-0x20(%ebp)
		// Make sure this memory is valid.
f0101714:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101718:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f010171f:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0101722:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0101725:	b8 ac 33 10 f0       	mov    $0xf01033ac,%eax
f010172a:	e8 71 fe ff ff       	call   f01015a0 <stab_binsearch>
		// Return -1 if it is not.  Hint: Call user_mem_check.
f010172f:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101732:	85 c0                	test   %eax,%eax
f0101734:	0f 84 28 01 00 00    	je     f0101862 <debuginfo_eip+0x1e5>
		// LAB 3: Your code here.

		stabs = usd->stabs;
		stab_end = usd->stab_end;
		stabstr = usd->stabstr;
f010173a:	89 45 dc             	mov    %eax,-0x24(%ebp)
		stabstr_end = usd->stabstr_end;
f010173d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101740:	89 45 d8             	mov    %eax,-0x28(%ebp)

f0101743:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101747:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f010174e:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0101751:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0101754:	b8 ac 33 10 f0       	mov    $0xf01033ac,%eax
f0101759:	e8 42 fe ff ff       	call   f01015a0 <stab_binsearch>
		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
f010175e:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0101761:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0101764:	7f 2e                	jg     f0101794 <debuginfo_eip+0x117>
	}

	// String table validity checks
f0101766:	6b c7 0c             	imul   $0xc,%edi,%eax
f0101769:	8d 90 ac 33 10 f0    	lea    -0xfefcc54(%eax),%edx
f010176f:	8b 80 ac 33 10 f0    	mov    -0xfefcc54(%eax),%eax
f0101775:	b9 c4 b7 10 f0       	mov    $0xf010b7c4,%ecx
f010177a:	81 e9 19 8b 10 f0    	sub    $0xf0108b19,%ecx
f0101780:	39 c8                	cmp    %ecx,%eax
f0101782:	73 08                	jae    f010178c <debuginfo_eip+0x10f>
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0101784:	05 19 8b 10 f0       	add    $0xf0108b19,%eax
f0101789:	89 43 08             	mov    %eax,0x8(%ebx)
		return -1;
f010178c:	8b 42 08             	mov    0x8(%edx),%eax
f010178f:	89 43 10             	mov    %eax,0x10(%ebx)
f0101792:	eb 06                	jmp    f010179a <debuginfo_eip+0x11d>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0101794:	89 73 10             	mov    %esi,0x10(%ebx)
	rfile = (stab_end - stabs) - 1;
f0101797:	8b 7d e4             	mov    -0x1c(%ebp),%edi
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;

f010179a:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f01017a1:	00 
f01017a2:	8b 43 08             	mov    0x8(%ebx),%eax
f01017a5:	89 04 24             	mov    %eax,(%esp)
f01017a8:	e8 c7 09 00 00       	call   f0102174 <strfind>
f01017ad:	2b 43 08             	sub    0x8(%ebx),%eax
f01017b0:	89 43 0c             	mov    %eax,0xc(%ebx)
		// Search within the function definition for the line number.
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
f01017b3:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f01017b6:	39 cf                	cmp    %ecx,%edi
f01017b8:	7c 5c                	jl     f0101816 <debuginfo_eip+0x199>
		info->eip_fn_addr = addr;
f01017ba:	6b c7 0c             	imul   $0xc,%edi,%eax
f01017bd:	8d b0 ac 33 10 f0    	lea    -0xfefcc54(%eax),%esi
f01017c3:	0f b6 56 04          	movzbl 0x4(%esi),%edx
f01017c7:	80 fa 84             	cmp    $0x84,%dl
f01017ca:	74 2b                	je     f01017f7 <debuginfo_eip+0x17a>
f01017cc:	05 a0 33 10 f0       	add    $0xf01033a0,%eax
f01017d1:	eb 15                	jmp    f01017e8 <debuginfo_eip+0x16b>
		lline = lfile;
		rline = rfile;
f01017d3:	83 ef 01             	sub    $0x1,%edi
		// Search within the function definition for the line number.
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
f01017d6:	39 cf                	cmp    %ecx,%edi
f01017d8:	7c 3c                	jl     f0101816 <debuginfo_eip+0x199>
		info->eip_fn_addr = addr;
f01017da:	89 c6                	mov    %eax,%esi
f01017dc:	83 e8 0c             	sub    $0xc,%eax
f01017df:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f01017e3:	80 fa 84             	cmp    $0x84,%dl
f01017e6:	74 0f                	je     f01017f7 <debuginfo_eip+0x17a>
		lline = lfile;
f01017e8:	80 fa 64             	cmp    $0x64,%dl
f01017eb:	75 e6                	jne    f01017d3 <debuginfo_eip+0x156>
f01017ed:	83 7e 08 00          	cmpl   $0x0,0x8(%esi)
f01017f1:	74 e0                	je     f01017d3 <debuginfo_eip+0x156>
		rline = rfile;
	}
f01017f3:	39 f9                	cmp    %edi,%ecx
f01017f5:	7f 1f                	jg     f0101816 <debuginfo_eip+0x199>
f01017f7:	6b ff 0c             	imul   $0xc,%edi,%edi
f01017fa:	8b 87 ac 33 10 f0    	mov    -0xfefcc54(%edi),%eax
f0101800:	ba c4 b7 10 f0       	mov    $0xf010b7c4,%edx
f0101805:	81 ea 19 8b 10 f0    	sub    $0xf0108b19,%edx
f010180b:	39 d0                	cmp    %edx,%eax
f010180d:	73 07                	jae    f0101816 <debuginfo_eip+0x199>
	// Ignore stuff after the colon.
f010180f:	05 19 8b 10 f0       	add    $0xf0108b19,%eax
f0101814:	89 03                	mov    %eax,(%ebx)
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;

	
	// Search within [lline, rline] for the line number stab.
	// If found, set info->eip_line to the right line number.
f0101816:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0101819:	8b 4d d8             	mov    -0x28(%ebp),%ecx
	// If not found, return -1.
	//
	// Hint:
	//	There's a particular stabs type used for line numbers.
	//	Look at the STABS documentation and <inc/stab.h> to find
	//	which one.
f010181c:	b8 00 00 00 00       	mov    $0x0,%eax
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;

	
	// Search within [lline, rline] for the line number stab.
	// If found, set info->eip_line to the right line number.
f0101821:	39 ca                	cmp    %ecx,%edx
f0101823:	7d 5e                	jge    f0101883 <debuginfo_eip+0x206>
	// If not found, return -1.
f0101825:	8d 42 01             	lea    0x1(%edx),%eax
f0101828:	39 c1                	cmp    %eax,%ecx
f010182a:	7e 3d                	jle    f0101869 <debuginfo_eip+0x1ec>
	//
f010182c:	6b d0 0c             	imul   $0xc,%eax,%edx
f010182f:	80 ba b0 33 10 f0 a0 	cmpb   $0xa0,-0xfefcc50(%edx)
f0101836:	75 38                	jne    f0101870 <debuginfo_eip+0x1f3>
f0101838:	81 c2 a0 33 10 f0    	add    $0xf01033a0,%edx
	// Hint:
	//	There's a particular stabs type used for line numbers.
f010183e:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	
	// Search within [lline, rline] for the line number stab.
	// If found, set info->eip_line to the right line number.
	// If not found, return -1.
	//
	// Hint:
f0101842:	83 c0 01             	add    $0x1,%eax
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;

	
	// Search within [lline, rline] for the line number stab.
	// If found, set info->eip_line to the right line number.
	// If not found, return -1.
f0101845:	39 c1                	cmp    %eax,%ecx
f0101847:	7e 2e                	jle    f0101877 <debuginfo_eip+0x1fa>
f0101849:	83 c2 0c             	add    $0xc,%edx
	//
f010184c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0101850:	74 ec                	je     f010183e <debuginfo_eip+0x1c1>
f0101852:	eb 2a                	jmp    f010187e <debuginfo_eip+0x201>

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0101854:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0101859:	eb 28                	jmp    f0101883 <debuginfo_eip+0x206>
f010185b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0101860:	eb 21                	jmp    f0101883 <debuginfo_eip+0x206>
		// USTABDATA.
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
f0101862:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0101867:	eb 1a                	jmp    f0101883 <debuginfo_eip+0x206>
	// If not found, return -1.
	//
	// Hint:
	//	There's a particular stabs type used for line numbers.
	//	Look at the STABS documentation and <inc/stab.h> to find
	//	which one.
f0101869:	b8 00 00 00 00       	mov    $0x0,%eax
f010186e:	eb 13                	jmp    f0101883 <debuginfo_eip+0x206>
f0101870:	b8 00 00 00 00       	mov    $0x0,%eax
f0101875:	eb 0c                	jmp    f0101883 <debuginfo_eip+0x206>
f0101877:	b8 00 00 00 00       	mov    $0x0,%eax
f010187c:	eb 05                	jmp    f0101883 <debuginfo_eip+0x206>
f010187e:	b8 00 00 00 00       	mov    $0x0,%eax
	// Your code here.
f0101883:	83 c4 2c             	add    $0x2c,%esp
f0101886:	5b                   	pop    %ebx
f0101887:	5e                   	pop    %esi
f0101888:	5f                   	pop    %edi
f0101889:	5d                   	pop    %ebp
f010188a:	c3                   	ret    
f010188b:	66 90                	xchg   %ax,%ax
f010188d:	66 90                	xchg   %ax,%ax
f010188f:	90                   	nop

f0101890 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0101890:	55                   	push   %ebp
f0101891:	89 e5                	mov    %esp,%ebp
f0101893:	57                   	push   %edi
f0101894:	56                   	push   %esi
f0101895:	53                   	push   %ebx
f0101896:	83 ec 3c             	sub    $0x3c,%esp
f0101899:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010189c:	89 d7                	mov    %edx,%edi
f010189e:	8b 45 08             	mov    0x8(%ebp),%eax
f01018a1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01018a4:	8b 75 0c             	mov    0xc(%ebp),%esi
f01018a7:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f01018aa:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f01018ad:	b9 00 00 00 00       	mov    $0x0,%ecx
f01018b2:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01018b5:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f01018b8:	39 f1                	cmp    %esi,%ecx
f01018ba:	72 14                	jb     f01018d0 <printnum+0x40>
f01018bc:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f01018bf:	76 0f                	jbe    f01018d0 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01018c1:	8b 45 14             	mov    0x14(%ebp),%eax
f01018c4:	8d 70 ff             	lea    -0x1(%eax),%esi
f01018c7:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01018ca:	85 f6                	test   %esi,%esi
f01018cc:	7f 60                	jg     f010192e <printnum+0x9e>
f01018ce:	eb 72                	jmp    f0101942 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f01018d0:	8b 4d 18             	mov    0x18(%ebp),%ecx
f01018d3:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f01018d7:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01018da:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01018dd:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01018e1:	89 44 24 08          	mov    %eax,0x8(%esp)
f01018e5:	8b 44 24 08          	mov    0x8(%esp),%eax
f01018e9:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01018ed:	89 c3                	mov    %eax,%ebx
f01018ef:	89 d6                	mov    %edx,%esi
f01018f1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01018f4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01018f7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01018fb:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01018ff:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0101902:	89 04 24             	mov    %eax,(%esp)
f0101905:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101908:	89 44 24 04          	mov    %eax,0x4(%esp)
f010190c:	e8 cf 0a 00 00       	call   f01023e0 <__udivdi3>
f0101911:	89 d9                	mov    %ebx,%ecx
f0101913:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101917:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010191b:	89 04 24             	mov    %eax,(%esp)
f010191e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0101922:	89 fa                	mov    %edi,%edx
f0101924:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0101927:	e8 64 ff ff ff       	call   f0101890 <printnum>
f010192c:	eb 14                	jmp    f0101942 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f010192e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101932:	8b 45 18             	mov    0x18(%ebp),%eax
f0101935:	89 04 24             	mov    %eax,(%esp)
f0101938:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f010193a:	83 ee 01             	sub    $0x1,%esi
f010193d:	75 ef                	jne    f010192e <printnum+0x9e>
f010193f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0101942:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0101946:	8b 7c 24 04          	mov    0x4(%esp),%edi
f010194a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010194d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0101950:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101954:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101958:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010195b:	89 04 24             	mov    %eax,(%esp)
f010195e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101961:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101965:	e8 a6 0b 00 00       	call   f0102510 <__umoddi3>
f010196a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010196e:	0f be 80 9c 31 10 f0 	movsbl -0xfefce64(%eax),%eax
f0101975:	89 04 24             	mov    %eax,(%esp)
f0101978:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010197b:	ff d0                	call   *%eax
}
f010197d:	83 c4 3c             	add    $0x3c,%esp
f0101980:	5b                   	pop    %ebx
f0101981:	5e                   	pop    %esi
f0101982:	5f                   	pop    %edi
f0101983:	5d                   	pop    %ebp
f0101984:	c3                   	ret    

f0101985 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0101985:	55                   	push   %ebp
f0101986:	89 e5                	mov    %esp,%ebp
f0101988:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f010198b:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f010198f:	8b 10                	mov    (%eax),%edx
f0101991:	3b 50 04             	cmp    0x4(%eax),%edx
f0101994:	73 0a                	jae    f01019a0 <sprintputch+0x1b>
		*b->buf++ = ch;
f0101996:	8d 4a 01             	lea    0x1(%edx),%ecx
f0101999:	89 08                	mov    %ecx,(%eax)
f010199b:	8b 45 08             	mov    0x8(%ebp),%eax
f010199e:	88 02                	mov    %al,(%edx)
}
f01019a0:	5d                   	pop    %ebp
f01019a1:	c3                   	ret    

f01019a2 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f01019a2:	55                   	push   %ebp
f01019a3:	89 e5                	mov    %esp,%ebp
f01019a5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f01019a8:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f01019ab:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019af:	8b 45 10             	mov    0x10(%ebp),%eax
f01019b2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01019b6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01019b9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019bd:	8b 45 08             	mov    0x8(%ebp),%eax
f01019c0:	89 04 24             	mov    %eax,(%esp)
f01019c3:	e8 02 00 00 00       	call   f01019ca <vprintfmt>
	va_end(ap);
}
f01019c8:	c9                   	leave  
f01019c9:	c3                   	ret    

f01019ca <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01019ca:	55                   	push   %ebp
f01019cb:	89 e5                	mov    %esp,%ebp
f01019cd:	57                   	push   %edi
f01019ce:	56                   	push   %esi
f01019cf:	53                   	push   %ebx
f01019d0:	83 ec 3c             	sub    $0x3c,%esp
f01019d3:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01019d6:	89 df                	mov    %ebx,%edi
f01019d8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01019db:	eb 03                	jmp    f01019e0 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01019dd:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01019e0:	8b 45 10             	mov    0x10(%ebp),%eax
f01019e3:	8d 70 01             	lea    0x1(%eax),%esi
f01019e6:	0f b6 00             	movzbl (%eax),%eax
f01019e9:	83 f8 25             	cmp    $0x25,%eax
f01019ec:	74 2d                	je     f0101a1b <vprintfmt+0x51>
			if (ch == '\0')
f01019ee:	85 c0                	test   %eax,%eax
f01019f0:	75 14                	jne    f0101a06 <vprintfmt+0x3c>
f01019f2:	e9 6b 04 00 00       	jmp    f0101e62 <vprintfmt+0x498>
f01019f7:	85 c0                	test   %eax,%eax
f01019f9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101a00:	0f 84 5c 04 00 00    	je     f0101e62 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0101a06:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101a0a:	89 04 24             	mov    %eax,(%esp)
f0101a0d:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0101a0f:	83 c6 01             	add    $0x1,%esi
f0101a12:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f0101a16:	83 f8 25             	cmp    $0x25,%eax
f0101a19:	75 dc                	jne    f01019f7 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0101a1b:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0101a1f:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0101a26:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0101a2d:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0101a34:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101a39:	eb 1f                	jmp    f0101a5a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101a3b:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0101a3e:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0101a42:	eb 16                	jmp    f0101a5a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101a44:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0101a47:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0101a4b:	eb 0d                	jmp    f0101a5a <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0101a4d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101a50:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0101a53:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101a5a:	8d 46 01             	lea    0x1(%esi),%eax
f0101a5d:	89 45 10             	mov    %eax,0x10(%ebp)
f0101a60:	0f b6 06             	movzbl (%esi),%eax
f0101a63:	0f b6 d0             	movzbl %al,%edx
f0101a66:	83 e8 23             	sub    $0x23,%eax
f0101a69:	3c 55                	cmp    $0x55,%al
f0101a6b:	0f 87 c4 03 00 00    	ja     f0101e35 <vprintfmt+0x46b>
f0101a71:	0f b6 c0             	movzbl %al,%eax
f0101a74:	ff 24 85 28 32 10 f0 	jmp    *-0xfefcdd8(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0101a7b:	8d 42 d0             	lea    -0x30(%edx),%eax
f0101a7e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0101a81:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0101a85:	8d 50 d0             	lea    -0x30(%eax),%edx
f0101a88:	83 fa 09             	cmp    $0x9,%edx
f0101a8b:	77 63                	ja     f0101af0 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101a8d:	8b 75 10             	mov    0x10(%ebp),%esi
f0101a90:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f0101a93:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0101a96:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0101a99:	8d 14 92             	lea    (%edx,%edx,4),%edx
f0101a9c:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f0101aa0:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0101aa3:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0101aa6:	83 f9 09             	cmp    $0x9,%ecx
f0101aa9:	76 eb                	jbe    f0101a96 <vprintfmt+0xcc>
f0101aab:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0101aae:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0101ab1:	eb 40                	jmp    f0101af3 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0101ab3:	8b 45 14             	mov    0x14(%ebp),%eax
f0101ab6:	8b 00                	mov    (%eax),%eax
f0101ab8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101abb:	8b 45 14             	mov    0x14(%ebp),%eax
f0101abe:	8d 40 04             	lea    0x4(%eax),%eax
f0101ac1:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101ac4:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0101ac7:	eb 2a                	jmp    f0101af3 <vprintfmt+0x129>
f0101ac9:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0101acc:	85 d2                	test   %edx,%edx
f0101ace:	b8 00 00 00 00       	mov    $0x0,%eax
f0101ad3:	0f 49 c2             	cmovns %edx,%eax
f0101ad6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101ad9:	8b 75 10             	mov    0x10(%ebp),%esi
f0101adc:	e9 79 ff ff ff       	jmp    f0101a5a <vprintfmt+0x90>
f0101ae1:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0101ae4:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0101aeb:	e9 6a ff ff ff       	jmp    f0101a5a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101af0:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0101af3:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0101af7:	0f 89 5d ff ff ff    	jns    f0101a5a <vprintfmt+0x90>
f0101afd:	e9 4b ff ff ff       	jmp    f0101a4d <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0101b02:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101b05:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0101b08:	e9 4d ff ff ff       	jmp    f0101a5a <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0101b0d:	8b 45 14             	mov    0x14(%ebp),%eax
f0101b10:	8d 70 04             	lea    0x4(%eax),%esi
f0101b13:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101b17:	8b 00                	mov    (%eax),%eax
f0101b19:	89 04 24             	mov    %eax,(%esp)
f0101b1c:	ff d7                	call   *%edi
f0101b1e:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0101b21:	e9 ba fe ff ff       	jmp    f01019e0 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0101b26:	8b 45 14             	mov    0x14(%ebp),%eax
f0101b29:	8d 70 04             	lea    0x4(%eax),%esi
f0101b2c:	8b 00                	mov    (%eax),%eax
f0101b2e:	99                   	cltd   
f0101b2f:	31 d0                	xor    %edx,%eax
f0101b31:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0101b33:	83 f8 06             	cmp    $0x6,%eax
f0101b36:	7f 0b                	jg     f0101b43 <vprintfmt+0x179>
f0101b38:	8b 14 85 80 33 10 f0 	mov    -0xfefcc80(,%eax,4),%edx
f0101b3f:	85 d2                	test   %edx,%edx
f0101b41:	75 20                	jne    f0101b63 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f0101b43:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101b47:	c7 44 24 08 b4 31 10 	movl   $0xf01031b4,0x8(%esp)
f0101b4e:	f0 
f0101b4f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101b53:	89 3c 24             	mov    %edi,(%esp)
f0101b56:	e8 47 fe ff ff       	call   f01019a2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f0101b5b:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f0101b5e:	e9 7d fe ff ff       	jmp    f01019e0 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f0101b63:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101b67:	c7 44 24 08 b2 2c 10 	movl   $0xf0102cb2,0x8(%esp)
f0101b6e:	f0 
f0101b6f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101b73:	89 3c 24             	mov    %edi,(%esp)
f0101b76:	e8 27 fe ff ff       	call   f01019a2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f0101b7b:	89 75 14             	mov    %esi,0x14(%ebp)
f0101b7e:	e9 5d fe ff ff       	jmp    f01019e0 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0101b83:	8b 45 14             	mov    0x14(%ebp),%eax
f0101b86:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101b89:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0101b8c:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f0101b90:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0101b92:	85 c0                	test   %eax,%eax
f0101b94:	b9 ad 31 10 f0       	mov    $0xf01031ad,%ecx
f0101b99:	0f 45 c8             	cmovne %eax,%ecx
f0101b9c:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0101b9f:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0101ba3:	74 04                	je     f0101ba9 <vprintfmt+0x1df>
f0101ba5:	85 f6                	test   %esi,%esi
f0101ba7:	7f 19                	jg     f0101bc2 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101ba9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101bac:	8d 70 01             	lea    0x1(%eax),%esi
f0101baf:	0f b6 10             	movzbl (%eax),%edx
f0101bb2:	0f be c2             	movsbl %dl,%eax
f0101bb5:	85 c0                	test   %eax,%eax
f0101bb7:	0f 85 9a 00 00 00    	jne    f0101c57 <vprintfmt+0x28d>
f0101bbd:	e9 87 00 00 00       	jmp    f0101c49 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101bc2:	89 54 24 04          	mov    %edx,0x4(%esp)
f0101bc6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101bc9:	89 04 24             	mov    %eax,(%esp)
f0101bcc:	e8 11 04 00 00       	call   f0101fe2 <strnlen>
f0101bd1:	29 c6                	sub    %eax,%esi
f0101bd3:	89 f0                	mov    %esi,%eax
f0101bd5:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0101bd8:	85 f6                	test   %esi,%esi
f0101bda:	7e cd                	jle    f0101ba9 <vprintfmt+0x1df>
					putch(padc, putdat);
f0101bdc:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101be0:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0101be3:	89 c3                	mov    %eax,%ebx
f0101be5:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101be8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101bec:	89 34 24             	mov    %esi,(%esp)
f0101bef:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101bf1:	83 eb 01             	sub    $0x1,%ebx
f0101bf4:	75 ef                	jne    f0101be5 <vprintfmt+0x21b>
f0101bf6:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101bf9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101bfc:	eb ab                	jmp    f0101ba9 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0101bfe:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0101c02:	74 1e                	je     f0101c22 <vprintfmt+0x258>
f0101c04:	0f be d2             	movsbl %dl,%edx
f0101c07:	83 ea 20             	sub    $0x20,%edx
f0101c0a:	83 fa 5e             	cmp    $0x5e,%edx
f0101c0d:	76 13                	jbe    f0101c22 <vprintfmt+0x258>
					putch('?', putdat);
f0101c0f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101c12:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101c16:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0101c1d:	ff 55 08             	call   *0x8(%ebp)
f0101c20:	eb 0d                	jmp    f0101c2f <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0101c22:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0101c25:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0101c29:	89 04 24             	mov    %eax,(%esp)
f0101c2c:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101c2f:	83 eb 01             	sub    $0x1,%ebx
f0101c32:	83 c6 01             	add    $0x1,%esi
f0101c35:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0101c39:	0f be c2             	movsbl %dl,%eax
f0101c3c:	85 c0                	test   %eax,%eax
f0101c3e:	75 23                	jne    f0101c63 <vprintfmt+0x299>
f0101c40:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101c43:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101c46:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101c49:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0101c4c:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0101c50:	7f 25                	jg     f0101c77 <vprintfmt+0x2ad>
f0101c52:	e9 89 fd ff ff       	jmp    f01019e0 <vprintfmt+0x16>
f0101c57:	89 7d 08             	mov    %edi,0x8(%ebp)
f0101c5a:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0101c5d:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0101c60:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101c63:	85 ff                	test   %edi,%edi
f0101c65:	78 97                	js     f0101bfe <vprintfmt+0x234>
f0101c67:	83 ef 01             	sub    $0x1,%edi
f0101c6a:	79 92                	jns    f0101bfe <vprintfmt+0x234>
f0101c6c:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101c6f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101c72:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101c75:	eb d2                	jmp    f0101c49 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0101c77:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101c7b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0101c82:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0101c84:	83 ee 01             	sub    $0x1,%esi
f0101c87:	75 ee                	jne    f0101c77 <vprintfmt+0x2ad>
f0101c89:	e9 52 fd ff ff       	jmp    f01019e0 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0101c8e:	83 f9 01             	cmp    $0x1,%ecx
f0101c91:	7e 19                	jle    f0101cac <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f0101c93:	8b 45 14             	mov    0x14(%ebp),%eax
f0101c96:	8b 50 04             	mov    0x4(%eax),%edx
f0101c99:	8b 00                	mov    (%eax),%eax
f0101c9b:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0101c9e:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0101ca1:	8b 45 14             	mov    0x14(%ebp),%eax
f0101ca4:	8d 40 08             	lea    0x8(%eax),%eax
f0101ca7:	89 45 14             	mov    %eax,0x14(%ebp)
f0101caa:	eb 38                	jmp    f0101ce4 <vprintfmt+0x31a>
	else if (lflag)
f0101cac:	85 c9                	test   %ecx,%ecx
f0101cae:	74 1b                	je     f0101ccb <vprintfmt+0x301>
		return va_arg(*ap, long);
f0101cb0:	8b 45 14             	mov    0x14(%ebp),%eax
f0101cb3:	8b 30                	mov    (%eax),%esi
f0101cb5:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0101cb8:	89 f0                	mov    %esi,%eax
f0101cba:	c1 f8 1f             	sar    $0x1f,%eax
f0101cbd:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0101cc0:	8b 45 14             	mov    0x14(%ebp),%eax
f0101cc3:	8d 40 04             	lea    0x4(%eax),%eax
f0101cc6:	89 45 14             	mov    %eax,0x14(%ebp)
f0101cc9:	eb 19                	jmp    f0101ce4 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f0101ccb:	8b 45 14             	mov    0x14(%ebp),%eax
f0101cce:	8b 30                	mov    (%eax),%esi
f0101cd0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0101cd3:	89 f0                	mov    %esi,%eax
f0101cd5:	c1 f8 1f             	sar    $0x1f,%eax
f0101cd8:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0101cdb:	8b 45 14             	mov    0x14(%ebp),%eax
f0101cde:	8d 40 04             	lea    0x4(%eax),%eax
f0101ce1:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0101ce4:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101ce7:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f0101cea:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f0101cef:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0101cf3:	0f 89 06 01 00 00    	jns    f0101dff <vprintfmt+0x435>
				putch('-', putdat);
f0101cf9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101cfd:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0101d04:	ff d7                	call   *%edi
				num = -(long long) num;
f0101d06:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101d09:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0101d0c:	f7 da                	neg    %edx
f0101d0e:	83 d1 00             	adc    $0x0,%ecx
f0101d11:	f7 d9                	neg    %ecx
			}
			base = 10;
f0101d13:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101d18:	e9 e2 00 00 00       	jmp    f0101dff <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0101d1d:	83 f9 01             	cmp    $0x1,%ecx
f0101d20:	7e 10                	jle    f0101d32 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f0101d22:	8b 45 14             	mov    0x14(%ebp),%eax
f0101d25:	8b 10                	mov    (%eax),%edx
f0101d27:	8b 48 04             	mov    0x4(%eax),%ecx
f0101d2a:	8d 40 08             	lea    0x8(%eax),%eax
f0101d2d:	89 45 14             	mov    %eax,0x14(%ebp)
f0101d30:	eb 26                	jmp    f0101d58 <vprintfmt+0x38e>
	else if (lflag)
f0101d32:	85 c9                	test   %ecx,%ecx
f0101d34:	74 12                	je     f0101d48 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f0101d36:	8b 45 14             	mov    0x14(%ebp),%eax
f0101d39:	8b 10                	mov    (%eax),%edx
f0101d3b:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101d40:	8d 40 04             	lea    0x4(%eax),%eax
f0101d43:	89 45 14             	mov    %eax,0x14(%ebp)
f0101d46:	eb 10                	jmp    f0101d58 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f0101d48:	8b 45 14             	mov    0x14(%ebp),%eax
f0101d4b:	8b 10                	mov    (%eax),%edx
f0101d4d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101d52:	8d 40 04             	lea    0x4(%eax),%eax
f0101d55:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f0101d58:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f0101d5d:	e9 9d 00 00 00       	jmp    f0101dff <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f0101d62:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101d66:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f0101d6d:	ff d7                	call   *%edi
			putch('X', putdat);
f0101d6f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101d73:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f0101d7a:	ff d7                	call   *%edi
			putch('X', putdat);
f0101d7c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101d80:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f0101d87:	ff d7                	call   *%edi
			break;
f0101d89:	e9 52 fc ff ff       	jmp    f01019e0 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f0101d8e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101d92:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0101d99:	ff d7                	call   *%edi
			putch('x', putdat);
f0101d9b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101d9f:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0101da6:	ff d7                	call   *%edi
			num = (unsigned long long)
f0101da8:	8b 45 14             	mov    0x14(%ebp),%eax
f0101dab:	8b 10                	mov    (%eax),%edx
f0101dad:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f0101db2:	8d 40 04             	lea    0x4(%eax),%eax
f0101db5:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0101db8:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f0101dbd:	eb 40                	jmp    f0101dff <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f0101dbf:	83 f9 01             	cmp    $0x1,%ecx
f0101dc2:	7e 10                	jle    f0101dd4 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f0101dc4:	8b 45 14             	mov    0x14(%ebp),%eax
f0101dc7:	8b 10                	mov    (%eax),%edx
f0101dc9:	8b 48 04             	mov    0x4(%eax),%ecx
f0101dcc:	8d 40 08             	lea    0x8(%eax),%eax
f0101dcf:	89 45 14             	mov    %eax,0x14(%ebp)
f0101dd2:	eb 26                	jmp    f0101dfa <vprintfmt+0x430>
	else if (lflag)
f0101dd4:	85 c9                	test   %ecx,%ecx
f0101dd6:	74 12                	je     f0101dea <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f0101dd8:	8b 45 14             	mov    0x14(%ebp),%eax
f0101ddb:	8b 10                	mov    (%eax),%edx
f0101ddd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101de2:	8d 40 04             	lea    0x4(%eax),%eax
f0101de5:	89 45 14             	mov    %eax,0x14(%ebp)
f0101de8:	eb 10                	jmp    f0101dfa <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f0101dea:	8b 45 14             	mov    0x14(%ebp),%eax
f0101ded:	8b 10                	mov    (%eax),%edx
f0101def:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101df4:	8d 40 04             	lea    0x4(%eax),%eax
f0101df7:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f0101dfa:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f0101dff:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101e03:	89 74 24 10          	mov    %esi,0x10(%esp)
f0101e07:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0101e0a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0101e0e:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101e12:	89 14 24             	mov    %edx,(%esp)
f0101e15:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0101e19:	89 da                	mov    %ebx,%edx
f0101e1b:	89 f8                	mov    %edi,%eax
f0101e1d:	e8 6e fa ff ff       	call   f0101890 <printnum>
			break;
f0101e22:	e9 b9 fb ff ff       	jmp    f01019e0 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0101e27:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101e2b:	89 14 24             	mov    %edx,(%esp)
f0101e2e:	ff d7                	call   *%edi
			break;
f0101e30:	e9 ab fb ff ff       	jmp    f01019e0 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0101e35:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101e39:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0101e40:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f0101e42:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0101e46:	0f 84 91 fb ff ff    	je     f01019dd <vprintfmt+0x13>
f0101e4c:	89 75 10             	mov    %esi,0x10(%ebp)
f0101e4f:	89 f0                	mov    %esi,%eax
f0101e51:	83 e8 01             	sub    $0x1,%eax
f0101e54:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f0101e58:	75 f7                	jne    f0101e51 <vprintfmt+0x487>
f0101e5a:	89 45 10             	mov    %eax,0x10(%ebp)
f0101e5d:	e9 7e fb ff ff       	jmp    f01019e0 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f0101e62:	83 c4 3c             	add    $0x3c,%esp
f0101e65:	5b                   	pop    %ebx
f0101e66:	5e                   	pop    %esi
f0101e67:	5f                   	pop    %edi
f0101e68:	5d                   	pop    %ebp
f0101e69:	c3                   	ret    

f0101e6a <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0101e6a:	55                   	push   %ebp
f0101e6b:	89 e5                	mov    %esp,%ebp
f0101e6d:	83 ec 28             	sub    $0x28,%esp
f0101e70:	8b 45 08             	mov    0x8(%ebp),%eax
f0101e73:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0101e76:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101e79:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0101e7d:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0101e80:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0101e87:	85 c0                	test   %eax,%eax
f0101e89:	74 30                	je     f0101ebb <vsnprintf+0x51>
f0101e8b:	85 d2                	test   %edx,%edx
f0101e8d:	7e 2c                	jle    f0101ebb <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0101e8f:	8b 45 14             	mov    0x14(%ebp),%eax
f0101e92:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101e96:	8b 45 10             	mov    0x10(%ebp),%eax
f0101e99:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101e9d:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0101ea0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101ea4:	c7 04 24 85 19 10 f0 	movl   $0xf0101985,(%esp)
f0101eab:	e8 1a fb ff ff       	call   f01019ca <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0101eb0:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0101eb3:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0101eb6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101eb9:	eb 05                	jmp    f0101ec0 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0101ebb:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0101ec0:	c9                   	leave  
f0101ec1:	c3                   	ret    

f0101ec2 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0101ec2:	55                   	push   %ebp
f0101ec3:	89 e5                	mov    %esp,%ebp
f0101ec5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0101ec8:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0101ecb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101ecf:	8b 45 10             	mov    0x10(%ebp),%eax
f0101ed2:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101ed6:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101ed9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101edd:	8b 45 08             	mov    0x8(%ebp),%eax
f0101ee0:	89 04 24             	mov    %eax,(%esp)
f0101ee3:	e8 82 ff ff ff       	call   f0101e6a <vsnprintf>
	va_end(ap);

	return rc;
}
f0101ee8:	c9                   	leave  
f0101ee9:	c3                   	ret    
f0101eea:	66 90                	xchg   %ax,%ax
f0101eec:	66 90                	xchg   %ax,%ax
f0101eee:	66 90                	xchg   %ax,%ax

f0101ef0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0101ef0:	55                   	push   %ebp
f0101ef1:	89 e5                	mov    %esp,%ebp
f0101ef3:	57                   	push   %edi
f0101ef4:	56                   	push   %esi
f0101ef5:	53                   	push   %ebx
f0101ef6:	83 ec 1c             	sub    $0x1c,%esp
f0101ef9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0101efc:	85 c0                	test   %eax,%eax
f0101efe:	74 10                	je     f0101f10 <readline+0x20>
		cprintf("%s", prompt);
f0101f00:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f04:	c7 04 24 b2 2c 10 f0 	movl   $0xf0102cb2,(%esp)
f0101f0b:	e8 66 f2 ff ff       	call   f0101176 <cprintf>

	i = 0;
	echoing = iscons(0);
f0101f10:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f17:	e8 69 e7 ff ff       	call   f0100685 <iscons>
f0101f1c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0101f1e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0101f23:	e8 4c e7 ff ff       	call   f0100674 <getchar>
f0101f28:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0101f2a:	85 c0                	test   %eax,%eax
f0101f2c:	79 17                	jns    f0101f45 <readline+0x55>
			cprintf("read error: %e\n", c);
f0101f2e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f32:	c7 04 24 9c 33 10 f0 	movl   $0xf010339c,(%esp)
f0101f39:	e8 38 f2 ff ff       	call   f0101176 <cprintf>
			return NULL;
f0101f3e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101f43:	eb 6d                	jmp    f0101fb2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0101f45:	83 f8 7f             	cmp    $0x7f,%eax
f0101f48:	74 05                	je     f0101f4f <readline+0x5f>
f0101f4a:	83 f8 08             	cmp    $0x8,%eax
f0101f4d:	75 19                	jne    f0101f68 <readline+0x78>
f0101f4f:	85 f6                	test   %esi,%esi
f0101f51:	7e 15                	jle    f0101f68 <readline+0x78>
			if (echoing)
f0101f53:	85 ff                	test   %edi,%edi
f0101f55:	74 0c                	je     f0101f63 <readline+0x73>
				cputchar('\b');
f0101f57:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f0101f5e:	e8 01 e7 ff ff       	call   f0100664 <cputchar>
			i--;
f0101f63:	83 ee 01             	sub    $0x1,%esi
f0101f66:	eb bb                	jmp    f0101f23 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101f68:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f0101f6e:	7f 1c                	jg     f0101f8c <readline+0x9c>
f0101f70:	83 fb 1f             	cmp    $0x1f,%ebx
f0101f73:	7e 17                	jle    f0101f8c <readline+0x9c>
			if (echoing)
f0101f75:	85 ff                	test   %edi,%edi
f0101f77:	74 08                	je     f0101f81 <readline+0x91>
				cputchar(c);
f0101f79:	89 1c 24             	mov    %ebx,(%esp)
f0101f7c:	e8 e3 e6 ff ff       	call   f0100664 <cputchar>
			buf[i++] = c;
f0101f81:	88 9e a0 8a 17 f0    	mov    %bl,-0xfe87560(%esi)
f0101f87:	8d 76 01             	lea    0x1(%esi),%esi
f0101f8a:	eb 97                	jmp    f0101f23 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0101f8c:	83 fb 0d             	cmp    $0xd,%ebx
f0101f8f:	74 05                	je     f0101f96 <readline+0xa6>
f0101f91:	83 fb 0a             	cmp    $0xa,%ebx
f0101f94:	75 8d                	jne    f0101f23 <readline+0x33>
			if (echoing)
f0101f96:	85 ff                	test   %edi,%edi
f0101f98:	74 0c                	je     f0101fa6 <readline+0xb6>
				cputchar('\n');
f0101f9a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0101fa1:	e8 be e6 ff ff       	call   f0100664 <cputchar>
			buf[i] = 0;
f0101fa6:	c6 86 a0 8a 17 f0 00 	movb   $0x0,-0xfe87560(%esi)
			return buf;
f0101fad:	b8 a0 8a 17 f0       	mov    $0xf0178aa0,%eax
		}
	}
}
f0101fb2:	83 c4 1c             	add    $0x1c,%esp
f0101fb5:	5b                   	pop    %ebx
f0101fb6:	5e                   	pop    %esi
f0101fb7:	5f                   	pop    %edi
f0101fb8:	5d                   	pop    %ebp
f0101fb9:	c3                   	ret    
f0101fba:	66 90                	xchg   %ax,%ax
f0101fbc:	66 90                	xchg   %ax,%ax
f0101fbe:	66 90                	xchg   %ax,%ax

f0101fc0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0101fc0:	55                   	push   %ebp
f0101fc1:	89 e5                	mov    %esp,%ebp
f0101fc3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0101fc6:	80 3a 00             	cmpb   $0x0,(%edx)
f0101fc9:	74 10                	je     f0101fdb <strlen+0x1b>
f0101fcb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0101fd0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0101fd3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0101fd7:	75 f7                	jne    f0101fd0 <strlen+0x10>
f0101fd9:	eb 05                	jmp    f0101fe0 <strlen+0x20>
f0101fdb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0101fe0:	5d                   	pop    %ebp
f0101fe1:	c3                   	ret    

f0101fe2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101fe2:	55                   	push   %ebp
f0101fe3:	89 e5                	mov    %esp,%ebp
f0101fe5:	53                   	push   %ebx
f0101fe6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101fe9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101fec:	85 c9                	test   %ecx,%ecx
f0101fee:	74 1c                	je     f010200c <strnlen+0x2a>
f0101ff0:	80 3b 00             	cmpb   $0x0,(%ebx)
f0101ff3:	74 1e                	je     f0102013 <strnlen+0x31>
f0101ff5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0101ffa:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0101ffc:	39 ca                	cmp    %ecx,%edx
f0101ffe:	74 18                	je     f0102018 <strnlen+0x36>
f0102000:	83 c2 01             	add    $0x1,%edx
f0102003:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0102008:	75 f0                	jne    f0101ffa <strnlen+0x18>
f010200a:	eb 0c                	jmp    f0102018 <strnlen+0x36>
f010200c:	b8 00 00 00 00       	mov    $0x0,%eax
f0102011:	eb 05                	jmp    f0102018 <strnlen+0x36>
f0102013:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0102018:	5b                   	pop    %ebx
f0102019:	5d                   	pop    %ebp
f010201a:	c3                   	ret    

f010201b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010201b:	55                   	push   %ebp
f010201c:	89 e5                	mov    %esp,%ebp
f010201e:	53                   	push   %ebx
f010201f:	8b 45 08             	mov    0x8(%ebp),%eax
f0102022:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0102025:	89 c2                	mov    %eax,%edx
f0102027:	83 c2 01             	add    $0x1,%edx
f010202a:	83 c1 01             	add    $0x1,%ecx
f010202d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0102031:	88 5a ff             	mov    %bl,-0x1(%edx)
f0102034:	84 db                	test   %bl,%bl
f0102036:	75 ef                	jne    f0102027 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0102038:	5b                   	pop    %ebx
f0102039:	5d                   	pop    %ebp
f010203a:	c3                   	ret    

f010203b <strncpy>:

char *
strcat(char *dst, const char *src)
f010203b:	55                   	push   %ebp
f010203c:	89 e5                	mov    %esp,%ebp
f010203e:	56                   	push   %esi
f010203f:	53                   	push   %ebx
f0102040:	8b 75 08             	mov    0x8(%ebp),%esi
f0102043:	8b 55 0c             	mov    0xc(%ebp),%edx
f0102046:	8b 5d 10             	mov    0x10(%ebp),%ebx
{
	int len = strlen(dst);
	strcpy(dst + len, src);
	return dst;
}
f0102049:	85 db                	test   %ebx,%ebx
f010204b:	74 17                	je     f0102064 <strncpy+0x29>
f010204d:	01 f3                	add    %esi,%ebx
f010204f:	89 f1                	mov    %esi,%ecx

f0102051:	83 c1 01             	add    $0x1,%ecx
f0102054:	0f b6 02             	movzbl (%edx),%eax
f0102057:	88 41 ff             	mov    %al,-0x1(%ecx)
char *
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
f010205a:	80 3a 01             	cmpb   $0x1,(%edx)
f010205d:	83 da ff             	sbb    $0xffffffff,%edx
strcat(char *dst, const char *src)
{
	int len = strlen(dst);
	strcpy(dst + len, src);
	return dst;
}
f0102060:	39 d9                	cmp    %ebx,%ecx
f0102062:	75 ed                	jne    f0102051 <strncpy+0x16>
char *
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
f0102064:	89 f0                	mov    %esi,%eax
f0102066:	5b                   	pop    %ebx
f0102067:	5e                   	pop    %esi
f0102068:	5d                   	pop    %ebp
f0102069:	c3                   	ret    

f010206a <strlcpy>:
	for (i = 0; i < size; i++) {
		*dst++ = *src;
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
f010206a:	55                   	push   %ebp
f010206b:	89 e5                	mov    %esp,%ebp
f010206d:	57                   	push   %edi
f010206e:	56                   	push   %esi
f010206f:	53                   	push   %ebx
f0102070:	8b 7d 08             	mov    0x8(%ebp),%edi
f0102073:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0102076:	8b 75 10             	mov    0x10(%ebp),%esi
f0102079:	89 f8                	mov    %edi,%eax
			src++;
	}
	return ret;
}
f010207b:	85 f6                	test   %esi,%esi
f010207d:	74 34                	je     f01020b3 <strlcpy+0x49>

f010207f:	83 fe 01             	cmp    $0x1,%esi
f0102082:	74 26                	je     f01020aa <strlcpy+0x40>
f0102084:	0f b6 0b             	movzbl (%ebx),%ecx
f0102087:	84 c9                	test   %cl,%cl
f0102089:	74 23                	je     f01020ae <strlcpy+0x44>
f010208b:	83 ee 02             	sub    $0x2,%esi
f010208e:	ba 00 00 00 00       	mov    $0x0,%edx
size_t
f0102093:	83 c0 01             	add    $0x1,%eax
f0102096:	88 48 ff             	mov    %cl,-0x1(%eax)
		if (*src != '\0')
			src++;
	}
	return ret;
}

f0102099:	39 f2                	cmp    %esi,%edx
f010209b:	74 13                	je     f01020b0 <strlcpy+0x46>
f010209d:	83 c2 01             	add    $0x1,%edx
f01020a0:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01020a4:	84 c9                	test   %cl,%cl
f01020a6:	75 eb                	jne    f0102093 <strlcpy+0x29>
f01020a8:	eb 06                	jmp    f01020b0 <strlcpy+0x46>
f01020aa:	89 f8                	mov    %edi,%eax
f01020ac:	eb 02                	jmp    f01020b0 <strlcpy+0x46>
f01020ae:	89 f8                	mov    %edi,%eax
size_t
strlcpy(char *dst, const char *src, size_t size)
f01020b0:	c6 00 00             	movb   $0x0,(%eax)
{
	char *dst_in;
f01020b3:	29 f8                	sub    %edi,%eax

f01020b5:	5b                   	pop    %ebx
f01020b6:	5e                   	pop    %esi
f01020b7:	5f                   	pop    %edi
f01020b8:	5d                   	pop    %ebp
f01020b9:	c3                   	ret    

f01020ba <strcmp>:
	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
f01020ba:	55                   	push   %ebp
f01020bb:	89 e5                	mov    %esp,%ebp
f01020bd:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01020c0:	8b 55 0c             	mov    0xc(%ebp),%edx
		*dst = '\0';
f01020c3:	0f b6 01             	movzbl (%ecx),%eax
f01020c6:	84 c0                	test   %al,%al
f01020c8:	74 15                	je     f01020df <strcmp+0x25>
f01020ca:	3a 02                	cmp    (%edx),%al
f01020cc:	75 11                	jne    f01020df <strcmp+0x25>
	}
f01020ce:	83 c1 01             	add    $0x1,%ecx
f01020d1:	83 c2 01             	add    $0x1,%edx

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
			*dst++ = *src++;
		*dst = '\0';
f01020d4:	0f b6 01             	movzbl (%ecx),%eax
f01020d7:	84 c0                	test   %al,%al
f01020d9:	74 04                	je     f01020df <strcmp+0x25>
f01020db:	3a 02                	cmp    (%edx),%al
f01020dd:	74 ef                	je     f01020ce <strcmp+0x14>
	}
	return dst - dst_in;
f01020df:	0f b6 c0             	movzbl %al,%eax
f01020e2:	0f b6 12             	movzbl (%edx),%edx
f01020e5:	29 d0                	sub    %edx,%eax
}
f01020e7:	5d                   	pop    %ebp
f01020e8:	c3                   	ret    

f01020e9 <strncmp>:

int
strcmp(const char *p, const char *q)
{
f01020e9:	55                   	push   %ebp
f01020ea:	89 e5                	mov    %esp,%ebp
f01020ec:	56                   	push   %esi
f01020ed:	53                   	push   %ebx
f01020ee:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01020f1:	8b 55 0c             	mov    0xc(%ebp),%edx
f01020f4:	8b 75 10             	mov    0x10(%ebp),%esi
	while (*p && *p == *q)
f01020f7:	85 f6                	test   %esi,%esi
f01020f9:	74 29                	je     f0102124 <strncmp+0x3b>
f01020fb:	0f b6 03             	movzbl (%ebx),%eax
f01020fe:	84 c0                	test   %al,%al
f0102100:	74 30                	je     f0102132 <strncmp+0x49>
f0102102:	3a 02                	cmp    (%edx),%al
f0102104:	75 2c                	jne    f0102132 <strncmp+0x49>
f0102106:	8d 43 01             	lea    0x1(%ebx),%eax
f0102109:	01 de                	add    %ebx,%esi
		p++, q++;
f010210b:	89 c3                	mov    %eax,%ebx
f010210d:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0102110:	39 f0                	cmp    %esi,%eax
f0102112:	74 17                	je     f010212b <strncmp+0x42>
f0102114:	0f b6 08             	movzbl (%eax),%ecx
f0102117:	84 c9                	test   %cl,%cl
f0102119:	74 17                	je     f0102132 <strncmp+0x49>
f010211b:	83 c0 01             	add    $0x1,%eax
f010211e:	3a 0a                	cmp    (%edx),%cl
f0102120:	74 e9                	je     f010210b <strncmp+0x22>
f0102122:	eb 0e                	jmp    f0102132 <strncmp+0x49>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
}
f0102124:	b8 00 00 00 00       	mov    $0x0,%eax
f0102129:	eb 0f                	jmp    f010213a <strncmp+0x51>
f010212b:	b8 00 00 00 00       	mov    $0x0,%eax
f0102130:	eb 08                	jmp    f010213a <strncmp+0x51>

int
f0102132:	0f b6 03             	movzbl (%ebx),%eax
f0102135:	0f b6 12             	movzbl (%edx),%edx
f0102138:	29 d0                	sub    %edx,%eax
strncmp(const char *p, const char *q, size_t n)
f010213a:	5b                   	pop    %ebx
f010213b:	5e                   	pop    %esi
f010213c:	5d                   	pop    %ebp
f010213d:	c3                   	ret    

f010213e <strchr>:
{
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
f010213e:	55                   	push   %ebp
f010213f:	89 e5                	mov    %esp,%ebp
f0102141:	53                   	push   %ebx
f0102142:	8b 45 08             	mov    0x8(%ebp),%eax
f0102145:	8b 55 0c             	mov    0xc(%ebp),%edx
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0102148:	0f b6 18             	movzbl (%eax),%ebx
f010214b:	84 db                	test   %bl,%bl
f010214d:	74 1d                	je     f010216c <strchr+0x2e>
f010214f:	89 d1                	mov    %edx,%ecx
}
f0102151:	38 d3                	cmp    %dl,%bl
f0102153:	75 06                	jne    f010215b <strchr+0x1d>
f0102155:	eb 1a                	jmp    f0102171 <strchr+0x33>
f0102157:	38 ca                	cmp    %cl,%dl
f0102159:	74 16                	je     f0102171 <strchr+0x33>
	while (n > 0 && *p && *p == *q)
		n--, p++, q++;
	if (n == 0)
		return 0;
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010215b:	83 c0 01             	add    $0x1,%eax
f010215e:	0f b6 10             	movzbl (%eax),%edx
f0102161:	84 d2                	test   %dl,%dl
f0102163:	75 f2                	jne    f0102157 <strchr+0x19>
}

// Return a pointer to the first occurrence of 'c' in 's',
f0102165:	b8 00 00 00 00       	mov    $0x0,%eax
f010216a:	eb 05                	jmp    f0102171 <strchr+0x33>
f010216c:	b8 00 00 00 00       	mov    $0x0,%eax
// or a null pointer if the string has no 'c'.
f0102171:	5b                   	pop    %ebx
f0102172:	5d                   	pop    %ebp
f0102173:	c3                   	ret    

f0102174 <strfind>:
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
		if (*s == c)
			return (char *) s;
f0102174:	55                   	push   %ebp
f0102175:	89 e5                	mov    %esp,%ebp
f0102177:	53                   	push   %ebx
f0102178:	8b 45 08             	mov    0x8(%ebp),%eax
f010217b:	8b 55 0c             	mov    0xc(%ebp),%edx
	return 0;
f010217e:	0f b6 18             	movzbl (%eax),%ebx
f0102181:	84 db                	test   %bl,%bl
f0102183:	74 17                	je     f010219c <strfind+0x28>
f0102185:	89 d1                	mov    %edx,%ecx
}
f0102187:	38 d3                	cmp    %dl,%bl
f0102189:	75 07                	jne    f0102192 <strfind+0x1e>
f010218b:	eb 0f                	jmp    f010219c <strfind+0x28>
f010218d:	38 ca                	cmp    %cl,%dl
f010218f:	90                   	nop
f0102190:	74 0a                	je     f010219c <strfind+0x28>
strchr(const char *s, char c)
{
	for (; *s; s++)
		if (*s == c)
			return (char *) s;
	return 0;
f0102192:	83 c0 01             	add    $0x1,%eax
f0102195:	0f b6 10             	movzbl (%eax),%edx
f0102198:	84 d2                	test   %dl,%dl
f010219a:	75 f1                	jne    f010218d <strfind+0x19>
}

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
f010219c:	5b                   	pop    %ebx
f010219d:	5d                   	pop    %ebp
f010219e:	c3                   	ret    

f010219f <memset>:
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
		if (*s == c)
f010219f:	55                   	push   %ebp
f01021a0:	89 e5                	mov    %esp,%ebp
f01021a2:	57                   	push   %edi
f01021a3:	56                   	push   %esi
f01021a4:	53                   	push   %ebx
f01021a5:	8b 7d 08             	mov    0x8(%ebp),%edi
f01021a8:	8b 4d 10             	mov    0x10(%ebp),%ecx
			break;
	return (char *) s;
}
f01021ab:	85 c9                	test   %ecx,%ecx
f01021ad:	74 36                	je     f01021e5 <memset+0x46>

#if ASM
f01021af:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01021b5:	75 28                	jne    f01021df <memset+0x40>
f01021b7:	f6 c1 03             	test   $0x3,%cl
f01021ba:	75 23                	jne    f01021df <memset+0x40>
void *
f01021bc:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
memset(void *v, int c, size_t n)
f01021c0:	89 d3                	mov    %edx,%ebx
f01021c2:	c1 e3 08             	shl    $0x8,%ebx
f01021c5:	89 d6                	mov    %edx,%esi
f01021c7:	c1 e6 18             	shl    $0x18,%esi
f01021ca:	89 d0                	mov    %edx,%eax
f01021cc:	c1 e0 10             	shl    $0x10,%eax
f01021cf:	09 f0                	or     %esi,%eax
f01021d1:	09 c2                	or     %eax,%edx
f01021d3:	89 d0                	mov    %edx,%eax
f01021d5:	09 d8                	or     %ebx,%eax
{
	char *p;
f01021d7:	c1 e9 02             	shr    $0x2,%ecx
}

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01021da:	fc                   	cld    
f01021db:	f3 ab                	rep stos %eax,%es:(%edi)
f01021dd:	eb 06                	jmp    f01021e5 <memset+0x46>
	char *p;

	if (n == 0)
		return v;
f01021df:	8b 45 0c             	mov    0xc(%ebp),%eax
f01021e2:	fc                   	cld    
f01021e3:	f3 aa                	rep stos %al,%es:(%edi)
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01021e5:	89 f8                	mov    %edi,%eax
f01021e7:	5b                   	pop    %ebx
f01021e8:	5e                   	pop    %esi
f01021e9:	5f                   	pop    %edi
f01021ea:	5d                   	pop    %ebp
f01021eb:	c3                   	ret    

f01021ec <memmove>:
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01021ec:	55                   	push   %ebp
f01021ed:	89 e5                	mov    %esp,%ebp
f01021ef:	57                   	push   %edi
f01021f0:	56                   	push   %esi
f01021f1:	8b 45 08             	mov    0x8(%ebp),%eax
f01021f4:	8b 75 0c             	mov    0xc(%ebp),%esi
f01021f7:	8b 4d 10             	mov    0x10(%ebp),%ecx
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}

void *
f01021fa:	39 c6                	cmp    %eax,%esi
f01021fc:	73 35                	jae    f0102233 <memmove+0x47>
f01021fe:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0102201:	39 d0                	cmp    %edx,%eax
f0102203:	73 2e                	jae    f0102233 <memmove+0x47>
memmove(void *dst, const void *src, size_t n)
{
f0102205:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0102208:	89 d6                	mov    %edx,%esi
f010220a:	09 fe                	or     %edi,%esi
	const char *s;
f010220c:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0102212:	75 13                	jne    f0102227 <memmove+0x3b>
f0102214:	f6 c1 03             	test   $0x3,%cl
f0102217:	75 0e                	jne    f0102227 <memmove+0x3b>
	char *d;
	
f0102219:	83 ef 04             	sub    $0x4,%edi
f010221c:	8d 72 fc             	lea    -0x4(%edx),%esi
f010221f:	c1 e9 02             	shr    $0x2,%ecx

void *
memmove(void *dst, const void *src, size_t n)
{
	const char *s;
	char *d;
f0102222:	fd                   	std    
f0102223:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0102225:	eb 09                	jmp    f0102230 <memmove+0x44>
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0102227:	83 ef 01             	sub    $0x1,%edi
f010222a:	8d 72 ff             	lea    -0x1(%edx),%esi
{
	const char *s;
	char *d;
	
	s = src;
	d = dst;
f010222d:	fd                   	std    
f010222e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
	if (s < d && s + n > d) {
		s += n;
		d += n;
f0102230:	fc                   	cld    
f0102231:	eb 1d                	jmp    f0102250 <memmove+0x64>
f0102233:	89 f2                	mov    %esi,%edx
f0102235:	09 c2                	or     %eax,%edx
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0102237:	f6 c2 03             	test   $0x3,%dl
f010223a:	75 0f                	jne    f010224b <memmove+0x5f>
f010223c:	f6 c1 03             	test   $0x3,%cl
f010223f:	75 0a                	jne    f010224b <memmove+0x5f>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
f0102241:	c1 e9 02             	shr    $0x2,%ecx
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0102244:	89 c7                	mov    %eax,%edi
f0102246:	fc                   	cld    
f0102247:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0102249:	eb 05                	jmp    f0102250 <memmove+0x64>
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f010224b:	89 c7                	mov    %eax,%edi
f010224d:	fc                   	cld    
f010224e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0102250:	5e                   	pop    %esi
f0102251:	5f                   	pop    %edi
f0102252:	5d                   	pop    %ebp
f0102253:	c3                   	ret    

f0102254 <memcpy>:
			*--d = *--s;
	} else
		while (n-- > 0)
			*d++ = *s++;

	return dst;
f0102254:	55                   	push   %ebp
f0102255:	89 e5                	mov    %esp,%ebp
f0102257:	83 ec 0c             	sub    $0xc,%esp
}
f010225a:	8b 45 10             	mov    0x10(%ebp),%eax
f010225d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102261:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102264:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102268:	8b 45 08             	mov    0x8(%ebp),%eax
f010226b:	89 04 24             	mov    %eax,(%esp)
f010226e:	e8 79 ff ff ff       	call   f01021ec <memmove>
#endif
f0102273:	c9                   	leave  
f0102274:	c3                   	ret    

f0102275 <memcmp>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
f0102275:	55                   	push   %ebp
f0102276:	89 e5                	mov    %esp,%ebp
f0102278:	57                   	push   %edi
f0102279:	56                   	push   %esi
f010227a:	53                   	push   %ebx
f010227b:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010227e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0102281:	8b 45 10             	mov    0x10(%ebp),%eax
memcpy(void *dst, void *src, size_t n)
{
	return memmove(dst, src, n);
}
f0102284:	8d 78 ff             	lea    -0x1(%eax),%edi
f0102287:	85 c0                	test   %eax,%eax
f0102289:	74 36                	je     f01022c1 <memcmp+0x4c>

f010228b:	0f b6 03             	movzbl (%ebx),%eax
f010228e:	0f b6 0e             	movzbl (%esi),%ecx
f0102291:	ba 00 00 00 00       	mov    $0x0,%edx
f0102296:	38 c8                	cmp    %cl,%al
f0102298:	74 1c                	je     f01022b6 <memcmp+0x41>
f010229a:	eb 10                	jmp    f01022ac <memcmp+0x37>
f010229c:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f01022a1:	83 c2 01             	add    $0x1,%edx
f01022a4:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01022a8:	38 c8                	cmp    %cl,%al
f01022aa:	74 0a                	je     f01022b6 <memcmp+0x41>
int
f01022ac:	0f b6 c0             	movzbl %al,%eax
f01022af:	0f b6 c9             	movzbl %cl,%ecx
f01022b2:	29 c8                	sub    %ecx,%eax
f01022b4:	eb 10                	jmp    f01022c6 <memcmp+0x51>
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
	return memmove(dst, src, n);
}
f01022b6:	39 fa                	cmp    %edi,%edx
f01022b8:	75 e2                	jne    f010229c <memcmp+0x27>

int
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;
f01022ba:	b8 00 00 00 00       	mov    $0x0,%eax
f01022bf:	eb 05                	jmp    f01022c6 <memcmp+0x51>
f01022c1:	b8 00 00 00 00       	mov    $0x0,%eax

f01022c6:	5b                   	pop    %ebx
f01022c7:	5e                   	pop    %esi
f01022c8:	5f                   	pop    %edi
f01022c9:	5d                   	pop    %ebp
f01022ca:	c3                   	ret    

f01022cb <memfind>:
	while (n-- > 0) {
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
f01022cb:	55                   	push   %ebp
f01022cc:	89 e5                	mov    %esp,%ebp
f01022ce:	53                   	push   %ebx
f01022cf:	8b 45 08             	mov    0x8(%ebp),%eax
f01022d2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	}
f01022d5:	89 c2                	mov    %eax,%edx
f01022d7:	03 55 10             	add    0x10(%ebp),%edx

f01022da:	39 d0                	cmp    %edx,%eax
f01022dc:	73 14                	jae    f01022f2 <memfind+0x27>
	return 0;
f01022de:	89 d9                	mov    %ebx,%ecx
f01022e0:	38 18                	cmp    %bl,(%eax)
f01022e2:	75 06                	jne    f01022ea <memfind+0x1f>
f01022e4:	eb 0c                	jmp    f01022f2 <memfind+0x27>
f01022e6:	38 08                	cmp    %cl,(%eax)
f01022e8:	74 08                	je     f01022f2 <memfind+0x27>
	while (n-- > 0) {
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

f01022ea:	83 c0 01             	add    $0x1,%eax
f01022ed:	39 d0                	cmp    %edx,%eax
f01022ef:	90                   	nop
f01022f0:	75 f4                	jne    f01022e6 <memfind+0x1b>
	return 0;
}

void *
f01022f2:	5b                   	pop    %ebx
f01022f3:	5d                   	pop    %ebp
f01022f4:	c3                   	ret    

f01022f5 <strtol>:
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f01022f5:	55                   	push   %ebp
f01022f6:	89 e5                	mov    %esp,%ebp
f01022f8:	57                   	push   %edi
f01022f9:	56                   	push   %esi
f01022fa:	53                   	push   %ebx
f01022fb:	8b 55 08             	mov    0x8(%ebp),%edx
f01022fe:	8b 45 10             	mov    0x10(%ebp),%eax
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}

f0102301:	0f b6 0a             	movzbl (%edx),%ecx
f0102304:	80 f9 09             	cmp    $0x9,%cl
f0102307:	74 05                	je     f010230e <strtol+0x19>
f0102309:	80 f9 20             	cmp    $0x20,%cl
f010230c:	75 10                	jne    f010231e <strtol+0x29>
long
f010230e:	83 c2 01             	add    $0x1,%edx
	for (; s < ends; s++)
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}

f0102311:	0f b6 0a             	movzbl (%edx),%ecx
f0102314:	80 f9 09             	cmp    $0x9,%cl
f0102317:	74 f5                	je     f010230e <strtol+0x19>
f0102319:	80 f9 20             	cmp    $0x20,%cl
f010231c:	74 f0                	je     f010230e <strtol+0x19>
long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f010231e:	80 f9 2b             	cmp    $0x2b,%cl
f0102321:	75 0a                	jne    f010232d <strtol+0x38>
	long val = 0;
f0102323:	83 c2 01             	add    $0x1,%edx
void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
		if (*(const unsigned char *) s == (unsigned char) c)
f0102326:	bf 00 00 00 00       	mov    $0x0,%edi
f010232b:	eb 11                	jmp    f010233e <strtol+0x49>
f010232d:	bf 00 00 00 00       	mov    $0x0,%edi
long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
	long val = 0;

f0102332:	80 f9 2d             	cmp    $0x2d,%cl
f0102335:	75 07                	jne    f010233e <strtol+0x49>
	// gobble initial whitespace
f0102337:	83 c2 01             	add    $0x1,%edx
f010233a:	66 bf 01 00          	mov    $0x1,%di
	while (*s == ' ' || *s == '\t')
		s++;

f010233e:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0102343:	75 15                	jne    f010235a <strtol+0x65>
f0102345:	80 3a 30             	cmpb   $0x30,(%edx)
f0102348:	75 10                	jne    f010235a <strtol+0x65>
f010234a:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f010234e:	75 0a                	jne    f010235a <strtol+0x65>
	// plus/minus sign
f0102350:	83 c2 02             	add    $0x2,%edx
f0102353:	b8 10 00 00 00       	mov    $0x10,%eax
f0102358:	eb 10                	jmp    f010236a <strtol+0x75>
	if (*s == '+')
f010235a:	85 c0                	test   %eax,%eax
f010235c:	75 0c                	jne    f010236a <strtol+0x75>
		s++;
	else if (*s == '-')
		s++, neg = 1;
f010235e:	b0 0a                	mov    $0xa,%al
	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
		s++;

	// plus/minus sign
	if (*s == '+')
f0102360:	80 3a 30             	cmpb   $0x30,(%edx)
f0102363:	75 05                	jne    f010236a <strtol+0x75>
		s++;
f0102365:	83 c2 01             	add    $0x1,%edx
f0102368:	b0 08                	mov    $0x8,%al
	else if (*s == '-')
		s++, neg = 1;
f010236a:	bb 00 00 00 00       	mov    $0x0,%ebx
f010236f:	89 45 10             	mov    %eax,0x10(%ebp)

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
		s++, base = 8;
f0102372:	0f b6 0a             	movzbl (%edx),%ecx
f0102375:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0102378:	89 f0                	mov    %esi,%eax
f010237a:	3c 09                	cmp    $0x9,%al
f010237c:	77 08                	ja     f0102386 <strtol+0x91>
	else if (base == 0)
f010237e:	0f be c9             	movsbl %cl,%ecx
f0102381:	83 e9 30             	sub    $0x30,%ecx
f0102384:	eb 20                	jmp    f01023a6 <strtol+0xb1>
		base = 10;
f0102386:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0102389:	89 f0                	mov    %esi,%eax
f010238b:	3c 19                	cmp    $0x19,%al
f010238d:	77 08                	ja     f0102397 <strtol+0xa2>

f010238f:	0f be c9             	movsbl %cl,%ecx
f0102392:	83 e9 57             	sub    $0x57,%ecx
f0102395:	eb 0f                	jmp    f01023a6 <strtol+0xb1>
	// digits
f0102397:	8d 71 bf             	lea    -0x41(%ecx),%esi
f010239a:	89 f0                	mov    %esi,%eax
f010239c:	3c 19                	cmp    $0x19,%al
f010239e:	77 16                	ja     f01023b6 <strtol+0xc1>
	while (1) {
f01023a0:	0f be c9             	movsbl %cl,%ecx
f01023a3:	83 e9 37             	sub    $0x37,%ecx
		int dig;

		if (*s >= '0' && *s <= '9')
f01023a6:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01023a9:	7d 0f                	jge    f01023ba <strtol+0xc5>
			dig = *s - '0';
		else if (*s >= 'a' && *s <= 'z')
f01023ab:	83 c2 01             	add    $0x1,%edx
f01023ae:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01023b2:	01 cb                	add    %ecx,%ebx
			dig = *s - 'a' + 10;
		else if (*s >= 'A' && *s <= 'Z')
f01023b4:	eb bc                	jmp    f0102372 <strtol+0x7d>
f01023b6:	89 d8                	mov    %ebx,%eax
f01023b8:	eb 02                	jmp    f01023bc <strtol+0xc7>
f01023ba:	89 d8                	mov    %ebx,%eax
			dig = *s - 'A' + 10;
		else
f01023bc:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01023c0:	74 05                	je     f01023c7 <strtol+0xd2>
			break;
f01023c2:	8b 75 0c             	mov    0xc(%ebp),%esi
f01023c5:	89 16                	mov    %edx,(%esi)
		if (dig >= base)
f01023c7:	f7 d8                	neg    %eax
f01023c9:	85 ff                	test   %edi,%edi
f01023cb:	0f 44 c3             	cmove  %ebx,%eax
			break;
f01023ce:	5b                   	pop    %ebx
f01023cf:	5e                   	pop    %esi
f01023d0:	5f                   	pop    %edi
f01023d1:	5d                   	pop    %ebp
f01023d2:	c3                   	ret    
f01023d3:	66 90                	xchg   %ax,%ax
f01023d5:	66 90                	xchg   %ax,%ax
f01023d7:	66 90                	xchg   %ax,%ax
f01023d9:	66 90                	xchg   %ax,%ax
f01023db:	66 90                	xchg   %ax,%ax
f01023dd:	66 90                	xchg   %ax,%ax
f01023df:	90                   	nop

f01023e0 <__udivdi3>:
f01023e0:	55                   	push   %ebp
f01023e1:	57                   	push   %edi
f01023e2:	56                   	push   %esi
f01023e3:	83 ec 0c             	sub    $0xc,%esp
f01023e6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01023ea:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01023ee:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01023f2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01023f6:	85 c0                	test   %eax,%eax
f01023f8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01023fc:	89 ea                	mov    %ebp,%edx
f01023fe:	89 0c 24             	mov    %ecx,(%esp)
f0102401:	75 2d                	jne    f0102430 <__udivdi3+0x50>
f0102403:	39 e9                	cmp    %ebp,%ecx
f0102405:	77 61                	ja     f0102468 <__udivdi3+0x88>
f0102407:	85 c9                	test   %ecx,%ecx
f0102409:	89 ce                	mov    %ecx,%esi
f010240b:	75 0b                	jne    f0102418 <__udivdi3+0x38>
f010240d:	b8 01 00 00 00       	mov    $0x1,%eax
f0102412:	31 d2                	xor    %edx,%edx
f0102414:	f7 f1                	div    %ecx
f0102416:	89 c6                	mov    %eax,%esi
f0102418:	31 d2                	xor    %edx,%edx
f010241a:	89 e8                	mov    %ebp,%eax
f010241c:	f7 f6                	div    %esi
f010241e:	89 c5                	mov    %eax,%ebp
f0102420:	89 f8                	mov    %edi,%eax
f0102422:	f7 f6                	div    %esi
f0102424:	89 ea                	mov    %ebp,%edx
f0102426:	83 c4 0c             	add    $0xc,%esp
f0102429:	5e                   	pop    %esi
f010242a:	5f                   	pop    %edi
f010242b:	5d                   	pop    %ebp
f010242c:	c3                   	ret    
f010242d:	8d 76 00             	lea    0x0(%esi),%esi
f0102430:	39 e8                	cmp    %ebp,%eax
f0102432:	77 24                	ja     f0102458 <__udivdi3+0x78>
f0102434:	0f bd e8             	bsr    %eax,%ebp
f0102437:	83 f5 1f             	xor    $0x1f,%ebp
f010243a:	75 3c                	jne    f0102478 <__udivdi3+0x98>
f010243c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0102440:	39 34 24             	cmp    %esi,(%esp)
f0102443:	0f 86 9f 00 00 00    	jbe    f01024e8 <__udivdi3+0x108>
f0102449:	39 d0                	cmp    %edx,%eax
f010244b:	0f 82 97 00 00 00    	jb     f01024e8 <__udivdi3+0x108>
f0102451:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0102458:	31 d2                	xor    %edx,%edx
f010245a:	31 c0                	xor    %eax,%eax
f010245c:	83 c4 0c             	add    $0xc,%esp
f010245f:	5e                   	pop    %esi
f0102460:	5f                   	pop    %edi
f0102461:	5d                   	pop    %ebp
f0102462:	c3                   	ret    
f0102463:	90                   	nop
f0102464:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0102468:	89 f8                	mov    %edi,%eax
f010246a:	f7 f1                	div    %ecx
f010246c:	31 d2                	xor    %edx,%edx
f010246e:	83 c4 0c             	add    $0xc,%esp
f0102471:	5e                   	pop    %esi
f0102472:	5f                   	pop    %edi
f0102473:	5d                   	pop    %ebp
f0102474:	c3                   	ret    
f0102475:	8d 76 00             	lea    0x0(%esi),%esi
f0102478:	89 e9                	mov    %ebp,%ecx
f010247a:	8b 3c 24             	mov    (%esp),%edi
f010247d:	d3 e0                	shl    %cl,%eax
f010247f:	89 c6                	mov    %eax,%esi
f0102481:	b8 20 00 00 00       	mov    $0x20,%eax
f0102486:	29 e8                	sub    %ebp,%eax
f0102488:	89 c1                	mov    %eax,%ecx
f010248a:	d3 ef                	shr    %cl,%edi
f010248c:	89 e9                	mov    %ebp,%ecx
f010248e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0102492:	8b 3c 24             	mov    (%esp),%edi
f0102495:	09 74 24 08          	or     %esi,0x8(%esp)
f0102499:	89 d6                	mov    %edx,%esi
f010249b:	d3 e7                	shl    %cl,%edi
f010249d:	89 c1                	mov    %eax,%ecx
f010249f:	89 3c 24             	mov    %edi,(%esp)
f01024a2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01024a6:	d3 ee                	shr    %cl,%esi
f01024a8:	89 e9                	mov    %ebp,%ecx
f01024aa:	d3 e2                	shl    %cl,%edx
f01024ac:	89 c1                	mov    %eax,%ecx
f01024ae:	d3 ef                	shr    %cl,%edi
f01024b0:	09 d7                	or     %edx,%edi
f01024b2:	89 f2                	mov    %esi,%edx
f01024b4:	89 f8                	mov    %edi,%eax
f01024b6:	f7 74 24 08          	divl   0x8(%esp)
f01024ba:	89 d6                	mov    %edx,%esi
f01024bc:	89 c7                	mov    %eax,%edi
f01024be:	f7 24 24             	mull   (%esp)
f01024c1:	39 d6                	cmp    %edx,%esi
f01024c3:	89 14 24             	mov    %edx,(%esp)
f01024c6:	72 30                	jb     f01024f8 <__udivdi3+0x118>
f01024c8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01024cc:	89 e9                	mov    %ebp,%ecx
f01024ce:	d3 e2                	shl    %cl,%edx
f01024d0:	39 c2                	cmp    %eax,%edx
f01024d2:	73 05                	jae    f01024d9 <__udivdi3+0xf9>
f01024d4:	3b 34 24             	cmp    (%esp),%esi
f01024d7:	74 1f                	je     f01024f8 <__udivdi3+0x118>
f01024d9:	89 f8                	mov    %edi,%eax
f01024db:	31 d2                	xor    %edx,%edx
f01024dd:	e9 7a ff ff ff       	jmp    f010245c <__udivdi3+0x7c>
f01024e2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01024e8:	31 d2                	xor    %edx,%edx
f01024ea:	b8 01 00 00 00       	mov    $0x1,%eax
f01024ef:	e9 68 ff ff ff       	jmp    f010245c <__udivdi3+0x7c>
f01024f4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01024f8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01024fb:	31 d2                	xor    %edx,%edx
f01024fd:	83 c4 0c             	add    $0xc,%esp
f0102500:	5e                   	pop    %esi
f0102501:	5f                   	pop    %edi
f0102502:	5d                   	pop    %ebp
f0102503:	c3                   	ret    
f0102504:	66 90                	xchg   %ax,%ax
f0102506:	66 90                	xchg   %ax,%ax
f0102508:	66 90                	xchg   %ax,%ax
f010250a:	66 90                	xchg   %ax,%ax
f010250c:	66 90                	xchg   %ax,%ax
f010250e:	66 90                	xchg   %ax,%ax

f0102510 <__umoddi3>:
f0102510:	55                   	push   %ebp
f0102511:	57                   	push   %edi
f0102512:	56                   	push   %esi
f0102513:	83 ec 14             	sub    $0x14,%esp
f0102516:	8b 44 24 28          	mov    0x28(%esp),%eax
f010251a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010251e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0102522:	89 c7                	mov    %eax,%edi
f0102524:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102528:	8b 44 24 30          	mov    0x30(%esp),%eax
f010252c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0102530:	89 34 24             	mov    %esi,(%esp)
f0102533:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0102537:	85 c0                	test   %eax,%eax
f0102539:	89 c2                	mov    %eax,%edx
f010253b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010253f:	75 17                	jne    f0102558 <__umoddi3+0x48>
f0102541:	39 fe                	cmp    %edi,%esi
f0102543:	76 4b                	jbe    f0102590 <__umoddi3+0x80>
f0102545:	89 c8                	mov    %ecx,%eax
f0102547:	89 fa                	mov    %edi,%edx
f0102549:	f7 f6                	div    %esi
f010254b:	89 d0                	mov    %edx,%eax
f010254d:	31 d2                	xor    %edx,%edx
f010254f:	83 c4 14             	add    $0x14,%esp
f0102552:	5e                   	pop    %esi
f0102553:	5f                   	pop    %edi
f0102554:	5d                   	pop    %ebp
f0102555:	c3                   	ret    
f0102556:	66 90                	xchg   %ax,%ax
f0102558:	39 f8                	cmp    %edi,%eax
f010255a:	77 54                	ja     f01025b0 <__umoddi3+0xa0>
f010255c:	0f bd e8             	bsr    %eax,%ebp
f010255f:	83 f5 1f             	xor    $0x1f,%ebp
f0102562:	75 5c                	jne    f01025c0 <__umoddi3+0xb0>
f0102564:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0102568:	39 3c 24             	cmp    %edi,(%esp)
f010256b:	0f 87 e7 00 00 00    	ja     f0102658 <__umoddi3+0x148>
f0102571:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0102575:	29 f1                	sub    %esi,%ecx
f0102577:	19 c7                	sbb    %eax,%edi
f0102579:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010257d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0102581:	8b 44 24 08          	mov    0x8(%esp),%eax
f0102585:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0102589:	83 c4 14             	add    $0x14,%esp
f010258c:	5e                   	pop    %esi
f010258d:	5f                   	pop    %edi
f010258e:	5d                   	pop    %ebp
f010258f:	c3                   	ret    
f0102590:	85 f6                	test   %esi,%esi
f0102592:	89 f5                	mov    %esi,%ebp
f0102594:	75 0b                	jne    f01025a1 <__umoddi3+0x91>
f0102596:	b8 01 00 00 00       	mov    $0x1,%eax
f010259b:	31 d2                	xor    %edx,%edx
f010259d:	f7 f6                	div    %esi
f010259f:	89 c5                	mov    %eax,%ebp
f01025a1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01025a5:	31 d2                	xor    %edx,%edx
f01025a7:	f7 f5                	div    %ebp
f01025a9:	89 c8                	mov    %ecx,%eax
f01025ab:	f7 f5                	div    %ebp
f01025ad:	eb 9c                	jmp    f010254b <__umoddi3+0x3b>
f01025af:	90                   	nop
f01025b0:	89 c8                	mov    %ecx,%eax
f01025b2:	89 fa                	mov    %edi,%edx
f01025b4:	83 c4 14             	add    $0x14,%esp
f01025b7:	5e                   	pop    %esi
f01025b8:	5f                   	pop    %edi
f01025b9:	5d                   	pop    %ebp
f01025ba:	c3                   	ret    
f01025bb:	90                   	nop
f01025bc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01025c0:	8b 04 24             	mov    (%esp),%eax
f01025c3:	be 20 00 00 00       	mov    $0x20,%esi
f01025c8:	89 e9                	mov    %ebp,%ecx
f01025ca:	29 ee                	sub    %ebp,%esi
f01025cc:	d3 e2                	shl    %cl,%edx
f01025ce:	89 f1                	mov    %esi,%ecx
f01025d0:	d3 e8                	shr    %cl,%eax
f01025d2:	89 e9                	mov    %ebp,%ecx
f01025d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01025d8:	8b 04 24             	mov    (%esp),%eax
f01025db:	09 54 24 04          	or     %edx,0x4(%esp)
f01025df:	89 fa                	mov    %edi,%edx
f01025e1:	d3 e0                	shl    %cl,%eax
f01025e3:	89 f1                	mov    %esi,%ecx
f01025e5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01025e9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01025ed:	d3 ea                	shr    %cl,%edx
f01025ef:	89 e9                	mov    %ebp,%ecx
f01025f1:	d3 e7                	shl    %cl,%edi
f01025f3:	89 f1                	mov    %esi,%ecx
f01025f5:	d3 e8                	shr    %cl,%eax
f01025f7:	89 e9                	mov    %ebp,%ecx
f01025f9:	09 f8                	or     %edi,%eax
f01025fb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01025ff:	f7 74 24 04          	divl   0x4(%esp)
f0102603:	d3 e7                	shl    %cl,%edi
f0102605:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0102609:	89 d7                	mov    %edx,%edi
f010260b:	f7 64 24 08          	mull   0x8(%esp)
f010260f:	39 d7                	cmp    %edx,%edi
f0102611:	89 c1                	mov    %eax,%ecx
f0102613:	89 14 24             	mov    %edx,(%esp)
f0102616:	72 2c                	jb     f0102644 <__umoddi3+0x134>
f0102618:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010261c:	72 22                	jb     f0102640 <__umoddi3+0x130>
f010261e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0102622:	29 c8                	sub    %ecx,%eax
f0102624:	19 d7                	sbb    %edx,%edi
f0102626:	89 e9                	mov    %ebp,%ecx
f0102628:	89 fa                	mov    %edi,%edx
f010262a:	d3 e8                	shr    %cl,%eax
f010262c:	89 f1                	mov    %esi,%ecx
f010262e:	d3 e2                	shl    %cl,%edx
f0102630:	89 e9                	mov    %ebp,%ecx
f0102632:	d3 ef                	shr    %cl,%edi
f0102634:	09 d0                	or     %edx,%eax
f0102636:	89 fa                	mov    %edi,%edx
f0102638:	83 c4 14             	add    $0x14,%esp
f010263b:	5e                   	pop    %esi
f010263c:	5f                   	pop    %edi
f010263d:	5d                   	pop    %ebp
f010263e:	c3                   	ret    
f010263f:	90                   	nop
f0102640:	39 d7                	cmp    %edx,%edi
f0102642:	75 da                	jne    f010261e <__umoddi3+0x10e>
f0102644:	8b 14 24             	mov    (%esp),%edx
f0102647:	89 c1                	mov    %eax,%ecx
f0102649:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010264d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0102651:	eb cb                	jmp    f010261e <__umoddi3+0x10e>
f0102653:	90                   	nop
f0102654:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0102658:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010265c:	0f 82 0f ff ff ff    	jb     f0102571 <__umoddi3+0x61>
f0102662:	e9 1a ff ff ff       	jmp    f0102581 <__umoddi3+0x71>
