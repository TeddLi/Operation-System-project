
obj/kern/kernel:     file format elf32-i386


Disassembly of section .text:

f0100000 <_start+0xeffffff4>:
.globl		_start
_start = RELOC(entry)

.globl entry
entry:
	movw	$0x1234,0x472			# warm boot
f0100000:	02 b0 ad 1b 00 00    	add    0x1bad(%eax),%dh
f0100006:	00 00                	add    %al,(%eax)
f0100008:	fe 4f 52             	decb   0x52(%edi)
f010000b:	e4 66                	in     $0x66,%al

f010000c <entry>:
f010000c:	66 c7 05 72 04 00 00 	movw   $0x1234,0x472
f0100013:	34 12 
	# physical addresses [0, 4MB).  This 4MB region will be suffice
	# until we set up our real page table in mem_init in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 80 11 00       	mov    $0x118000,%eax
	movl	%eax, %cr3
f010001a:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl	%cr0, %eax
f010001d:	0f 20 c0             	mov    %cr0,%eax
	orl	$(CR0_PE|CR0_PG|CR0_WP), %eax
f0100020:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl	%eax, %cr0
f0100025:	0f 22 c0             	mov    %eax,%cr0

	# Now paging is enabled, but we're still running at a low EIP
	# (why is this okay?).  Jump up above KERNBASE before entering
	# C code.
	mov	$relocated, %eax
f0100028:	b8 2f 00 10 f0       	mov    $0xf010002f,%eax
	jmp	*%eax
f010002d:	ff e0                	jmp    *%eax

f010002f <relocated>:
relocated:

	# Clear the frame pointer register (EBP)
	# so that once we get into debugging C code,
	# stack backtraces will be terminated properly.
	movl	$0x0,%ebp			# nuke frame pointer
f010002f:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Set the stack pointer
	movl	$(bootstacktop),%esp
f0100034:	bc 00 80 11 f0       	mov    $0xf0118000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 02 00 00 00       	call   f0100040 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <i386_init>:
#include <kern/trap.h>


void
i386_init(void)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f0100046:	b8 90 ce 17 f0       	mov    $0xf017ce90,%eax
f010004b:	2d 69 bf 17 f0       	sub    $0xf017bf69,%eax
f0100050:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100054:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010005b:	00 
f010005c:	c7 04 24 69 bf 17 f0 	movl   $0xf017bf69,(%esp)
f0100063:	e8 11 45 00 00       	call   f0104579 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f0100068:	e8 f2 04 00 00       	call   f010055f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f010006d:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100074:	00 
f0100075:	c7 04 24 40 4a 10 f0 	movl   $0xf0104a40,(%esp)
f010007c:	e8 53 34 00 00       	call   f01034d4 <cprintf>

	// Lab 2 memory management initialization functions
	cprintf("mem_init 1!\n", 6828);
f0100081:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f0100088:	00 
f0100089:	c7 04 24 5b 4a 10 f0 	movl   $0xf0104a5b,(%esp)
f0100090:	e8 3f 34 00 00       	call   f01034d4 <cprintf>
	mem_init();
f0100095:	e8 8a 11 00 00       	call   f0101224 <mem_init>
	cprintf("mem_init 2!\n", 6828);
f010009a:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000a1:	00 
f01000a2:	c7 04 24 68 4a 10 f0 	movl   $0xf0104a68,(%esp)
f01000a9:	e8 26 34 00 00       	call   f01034d4 <cprintf>
	// Lab 3 user environment initialization functions
	env_init();
f01000ae:	e8 12 30 00 00       	call   f01030c5 <env_init>
	trap_init();
f01000b3:	e8 93 34 00 00       	call   f010354b <trap_init>

#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
f01000b8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01000bf:	00 
f01000c0:	c7 44 24 04 4a 78 00 	movl   $0x784a,0x4(%esp)
f01000c7:	00 
f01000c8:	c7 04 24 4d 0c 13 f0 	movl   $0xf0130c4d,(%esp)
f01000cf:	e8 2a 31 00 00       	call   f01031fe <env_create>
	// Touch all you want.
	ENV_CREATE(user_hello, ENV_TYPE_USER);
#endif // TEST*

	// We only have one user environment for now, so just run it.
	env_run(&envs[0]);
f01000d4:	a1 cc c1 17 f0       	mov    0xf017c1cc,%eax
f01000d9:	89 04 24             	mov    %eax,(%esp)
f01000dc:	e8 61 33 00 00       	call   f0103442 <env_run>

f01000e1 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f01000e1:	55                   	push   %ebp
f01000e2:	89 e5                	mov    %esp,%ebp
f01000e4:	56                   	push   %esi
f01000e5:	53                   	push   %ebx
f01000e6:	83 ec 10             	sub    $0x10,%esp
f01000e9:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f01000ec:	83 3d 80 ce 17 f0 00 	cmpl   $0x0,0xf017ce80
f01000f3:	75 3d                	jne    f0100132 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f01000f5:	89 35 80 ce 17 f0    	mov    %esi,0xf017ce80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f01000fb:	fa                   	cli    
f01000fc:	fc                   	cld    

	va_start(ap, fmt);
f01000fd:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f0100100:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100103:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100107:	8b 45 08             	mov    0x8(%ebp),%eax
f010010a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010010e:	c7 04 24 75 4a 10 f0 	movl   $0xf0104a75,(%esp)
f0100115:	e8 ba 33 00 00       	call   f01034d4 <cprintf>
	vcprintf(fmt, ap);
f010011a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010011e:	89 34 24             	mov    %esi,(%esp)
f0100121:	e8 7b 33 00 00       	call   f01034a1 <vcprintf>
	cprintf("\n");
f0100126:	c7 04 24 66 4a 10 f0 	movl   $0xf0104a66,(%esp)
f010012d:	e8 a2 33 00 00       	call   f01034d4 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f0100132:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100139:	e8 c9 06 00 00       	call   f0100807 <monitor>
f010013e:	eb f2                	jmp    f0100132 <_panic+0x51>

f0100140 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f0100140:	55                   	push   %ebp
f0100141:	89 e5                	mov    %esp,%ebp
f0100143:	53                   	push   %ebx
f0100144:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f0100147:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f010014a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	8b 45 08             	mov    0x8(%ebp),%eax
f0100154:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100158:	c7 04 24 8d 4a 10 f0 	movl   $0xf0104a8d,(%esp)
f010015f:	e8 70 33 00 00       	call   f01034d4 <cprintf>
	vcprintf(fmt, ap);
f0100164:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100168:	8b 45 10             	mov    0x10(%ebp),%eax
f010016b:	89 04 24             	mov    %eax,(%esp)
f010016e:	e8 2e 33 00 00       	call   f01034a1 <vcprintf>
	cprintf("\n");
f0100173:	c7 04 24 66 4a 10 f0 	movl   $0xf0104a66,(%esp)
f010017a:	e8 55 33 00 00       	call   f01034d4 <cprintf>
	va_end(ap);
}
f010017f:	83 c4 14             	add    $0x14,%esp
f0100182:	5b                   	pop    %ebx
f0100183:	5d                   	pop    %ebp
f0100184:	c3                   	ret    
f0100185:	66 90                	xchg   %ax,%ax
f0100187:	66 90                	xchg   %ax,%ax
f0100189:	66 90                	xchg   %ax,%ax
f010018b:	66 90                	xchg   %ax,%ax
f010018d:	66 90                	xchg   %ax,%ax
f010018f:	90                   	nop

f0100190 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100190:	55                   	push   %ebp
f0100191:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100193:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100198:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100199:	a8 01                	test   $0x1,%al
f010019b:	74 08                	je     f01001a5 <serial_proc_data+0x15>
f010019d:	b2 f8                	mov    $0xf8,%dl
f010019f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f01001a0:	0f b6 c0             	movzbl %al,%eax
f01001a3:	eb 05                	jmp    f01001aa <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f01001a5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f01001aa:	5d                   	pop    %ebp
f01001ab:	c3                   	ret    

f01001ac <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f01001ac:	55                   	push   %ebp
f01001ad:	89 e5                	mov    %esp,%ebp
f01001af:	53                   	push   %ebx
f01001b0:	83 ec 04             	sub    $0x4,%esp
f01001b3:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f01001b5:	eb 2a                	jmp    f01001e1 <cons_intr+0x35>
		if (c == 0)
f01001b7:	85 d2                	test   %edx,%edx
f01001b9:	74 26                	je     f01001e1 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f01001bb:	a1 a4 c1 17 f0       	mov    0xf017c1a4,%eax
f01001c0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001c3:	89 0d a4 c1 17 f0    	mov    %ecx,0xf017c1a4
f01001c9:	88 90 a0 bf 17 f0    	mov    %dl,-0xfe84060(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001cf:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001d5:	75 0a                	jne    f01001e1 <cons_intr+0x35>
			cons.wpos = 0;
f01001d7:	c7 05 a4 c1 17 f0 00 	movl   $0x0,0xf017c1a4
f01001de:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f01001e1:	ff d3                	call   *%ebx
f01001e3:	89 c2                	mov    %eax,%edx
f01001e5:	83 f8 ff             	cmp    $0xffffffff,%eax
f01001e8:	75 cd                	jne    f01001b7 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f01001ea:	83 c4 04             	add    $0x4,%esp
f01001ed:	5b                   	pop    %ebx
f01001ee:	5d                   	pop    %ebp
f01001ef:	c3                   	ret    

f01001f0 <kbd_proc_data>:
f01001f0:	ba 64 00 00 00       	mov    $0x64,%edx
f01001f5:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f01001f6:	a8 01                	test   $0x1,%al
f01001f8:	0f 84 ef 00 00 00    	je     f01002ed <kbd_proc_data+0xfd>
f01001fe:	b2 60                	mov    $0x60,%dl
f0100200:	ec                   	in     (%dx),%al
f0100201:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100203:	3c e0                	cmp    $0xe0,%al
f0100205:	75 0d                	jne    f0100214 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100207:	83 0d 80 bf 17 f0 40 	orl    $0x40,0xf017bf80
		return 0;
f010020e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100213:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100214:	55                   	push   %ebp
f0100215:	89 e5                	mov    %esp,%ebp
f0100217:	53                   	push   %ebx
f0100218:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010021b:	84 c0                	test   %al,%al
f010021d:	79 37                	jns    f0100256 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010021f:	8b 0d 80 bf 17 f0    	mov    0xf017bf80,%ecx
f0100225:	89 cb                	mov    %ecx,%ebx
f0100227:	83 e3 40             	and    $0x40,%ebx
f010022a:	83 e0 7f             	and    $0x7f,%eax
f010022d:	85 db                	test   %ebx,%ebx
f010022f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100232:	0f b6 d2             	movzbl %dl,%edx
f0100235:	0f b6 82 00 4c 10 f0 	movzbl -0xfefb400(%edx),%eax
f010023c:	83 c8 40             	or     $0x40,%eax
f010023f:	0f b6 c0             	movzbl %al,%eax
f0100242:	f7 d0                	not    %eax
f0100244:	21 c1                	and    %eax,%ecx
f0100246:	89 0d 80 bf 17 f0    	mov    %ecx,0xf017bf80
		return 0;
f010024c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100251:	e9 9d 00 00 00       	jmp    f01002f3 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100256:	8b 0d 80 bf 17 f0    	mov    0xf017bf80,%ecx
f010025c:	f6 c1 40             	test   $0x40,%cl
f010025f:	74 0e                	je     f010026f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100261:	83 c8 80             	or     $0xffffff80,%eax
f0100264:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100266:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100269:	89 0d 80 bf 17 f0    	mov    %ecx,0xf017bf80
	}

	shift |= shiftcode[data];
f010026f:	0f b6 d2             	movzbl %dl,%edx
f0100272:	0f b6 82 00 4c 10 f0 	movzbl -0xfefb400(%edx),%eax
f0100279:	0b 05 80 bf 17 f0    	or     0xf017bf80,%eax
	shift ^= togglecode[data];
f010027f:	0f b6 8a 00 4b 10 f0 	movzbl -0xfefb500(%edx),%ecx
f0100286:	31 c8                	xor    %ecx,%eax
f0100288:	a3 80 bf 17 f0       	mov    %eax,0xf017bf80

	c = charcode[shift & (CTL | SHIFT)][data];
f010028d:	89 c1                	mov    %eax,%ecx
f010028f:	83 e1 03             	and    $0x3,%ecx
f0100292:	8b 0c 8d e0 4a 10 f0 	mov    -0xfefb520(,%ecx,4),%ecx
f0100299:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010029d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f01002a0:	a8 08                	test   $0x8,%al
f01002a2:	74 1b                	je     f01002bf <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f01002a4:	89 da                	mov    %ebx,%edx
f01002a6:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f01002a9:	83 f9 19             	cmp    $0x19,%ecx
f01002ac:	77 05                	ja     f01002b3 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f01002ae:	83 eb 20             	sub    $0x20,%ebx
f01002b1:	eb 0c                	jmp    f01002bf <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f01002b3:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f01002b6:	8d 4b 20             	lea    0x20(%ebx),%ecx
f01002b9:	83 fa 19             	cmp    $0x19,%edx
f01002bc:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002bf:	f7 d0                	not    %eax
f01002c1:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002c3:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f01002c5:	f6 c2 06             	test   $0x6,%dl
f01002c8:	75 29                	jne    f01002f3 <kbd_proc_data+0x103>
f01002ca:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f01002d0:	75 21                	jne    f01002f3 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f01002d2:	c7 04 24 a7 4a 10 f0 	movl   $0xf0104aa7,(%esp)
f01002d9:	e8 f6 31 00 00       	call   f01034d4 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01002de:	ba 92 00 00 00       	mov    $0x92,%edx
f01002e3:	b8 03 00 00 00       	mov    $0x3,%eax
f01002e8:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f01002e9:	89 d8                	mov    %ebx,%eax
f01002eb:	eb 06                	jmp    f01002f3 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f01002ed:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01002f2:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01002f3:	83 c4 14             	add    $0x14,%esp
f01002f6:	5b                   	pop    %ebx
f01002f7:	5d                   	pop    %ebp
f01002f8:	c3                   	ret    

f01002f9 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f01002f9:	55                   	push   %ebp
f01002fa:	89 e5                	mov    %esp,%ebp
f01002fc:	57                   	push   %edi
f01002fd:	56                   	push   %esi
f01002fe:	53                   	push   %ebx
f01002ff:	83 ec 1c             	sub    $0x1c,%esp
f0100302:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100304:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100309:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010030a:	a8 20                	test   $0x20,%al
f010030c:	75 21                	jne    f010032f <cons_putc+0x36>
f010030e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100313:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100318:	be fd 03 00 00       	mov    $0x3fd,%esi
f010031d:	89 ca                	mov    %ecx,%edx
f010031f:	ec                   	in     (%dx),%al
f0100320:	ec                   	in     (%dx),%al
f0100321:	ec                   	in     (%dx),%al
f0100322:	ec                   	in     (%dx),%al
f0100323:	89 f2                	mov    %esi,%edx
f0100325:	ec                   	in     (%dx),%al
f0100326:	a8 20                	test   $0x20,%al
f0100328:	75 05                	jne    f010032f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010032a:	83 eb 01             	sub    $0x1,%ebx
f010032d:	75 ee                	jne    f010031d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010032f:	89 f8                	mov    %edi,%eax
f0100331:	0f b6 c0             	movzbl %al,%eax
f0100334:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100337:	ba f8 03 00 00       	mov    $0x3f8,%edx
f010033c:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010033d:	b2 79                	mov    $0x79,%dl
f010033f:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f0100340:	84 c0                	test   %al,%al
f0100342:	78 21                	js     f0100365 <cons_putc+0x6c>
f0100344:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100349:	b9 84 00 00 00       	mov    $0x84,%ecx
f010034e:	be 79 03 00 00       	mov    $0x379,%esi
f0100353:	89 ca                	mov    %ecx,%edx
f0100355:	ec                   	in     (%dx),%al
f0100356:	ec                   	in     (%dx),%al
f0100357:	ec                   	in     (%dx),%al
f0100358:	ec                   	in     (%dx),%al
f0100359:	89 f2                	mov    %esi,%edx
f010035b:	ec                   	in     (%dx),%al
f010035c:	84 c0                	test   %al,%al
f010035e:	78 05                	js     f0100365 <cons_putc+0x6c>
f0100360:	83 eb 01             	sub    $0x1,%ebx
f0100363:	75 ee                	jne    f0100353 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100365:	ba 78 03 00 00       	mov    $0x378,%edx
f010036a:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f010036e:	ee                   	out    %al,(%dx)
f010036f:	b2 7a                	mov    $0x7a,%dl
f0100371:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100376:	ee                   	out    %al,(%dx)
f0100377:	b8 08 00 00 00       	mov    $0x8,%eax
f010037c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010037d:	89 fa                	mov    %edi,%edx
f010037f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100385:	89 f8                	mov    %edi,%eax
f0100387:	80 cc 07             	or     $0x7,%ah
f010038a:	85 d2                	test   %edx,%edx
f010038c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010038f:	89 f8                	mov    %edi,%eax
f0100391:	0f b6 c0             	movzbl %al,%eax
f0100394:	83 f8 09             	cmp    $0x9,%eax
f0100397:	74 79                	je     f0100412 <cons_putc+0x119>
f0100399:	83 f8 09             	cmp    $0x9,%eax
f010039c:	7f 0a                	jg     f01003a8 <cons_putc+0xaf>
f010039e:	83 f8 08             	cmp    $0x8,%eax
f01003a1:	74 19                	je     f01003bc <cons_putc+0xc3>
f01003a3:	e9 9e 00 00 00       	jmp    f0100446 <cons_putc+0x14d>
f01003a8:	83 f8 0a             	cmp    $0xa,%eax
f01003ab:	90                   	nop
f01003ac:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01003b0:	74 3a                	je     f01003ec <cons_putc+0xf3>
f01003b2:	83 f8 0d             	cmp    $0xd,%eax
f01003b5:	74 3d                	je     f01003f4 <cons_putc+0xfb>
f01003b7:	e9 8a 00 00 00       	jmp    f0100446 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f01003bc:	0f b7 05 a8 c1 17 f0 	movzwl 0xf017c1a8,%eax
f01003c3:	66 85 c0             	test   %ax,%ax
f01003c6:	0f 84 e5 00 00 00    	je     f01004b1 <cons_putc+0x1b8>
			crt_pos--;
f01003cc:	83 e8 01             	sub    $0x1,%eax
f01003cf:	66 a3 a8 c1 17 f0    	mov    %ax,0xf017c1a8
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003d5:	0f b7 c0             	movzwl %ax,%eax
f01003d8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003dd:	83 cf 20             	or     $0x20,%edi
f01003e0:	8b 15 ac c1 17 f0    	mov    0xf017c1ac,%edx
f01003e6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003ea:	eb 78                	jmp    f0100464 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003ec:	66 83 05 a8 c1 17 f0 	addw   $0x50,0xf017c1a8
f01003f3:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f01003f4:	0f b7 05 a8 c1 17 f0 	movzwl 0xf017c1a8,%eax
f01003fb:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100401:	c1 e8 16             	shr    $0x16,%eax
f0100404:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100407:	c1 e0 04             	shl    $0x4,%eax
f010040a:	66 a3 a8 c1 17 f0    	mov    %ax,0xf017c1a8
f0100410:	eb 52                	jmp    f0100464 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100412:	b8 20 00 00 00       	mov    $0x20,%eax
f0100417:	e8 dd fe ff ff       	call   f01002f9 <cons_putc>
		cons_putc(' ');
f010041c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100421:	e8 d3 fe ff ff       	call   f01002f9 <cons_putc>
		cons_putc(' ');
f0100426:	b8 20 00 00 00       	mov    $0x20,%eax
f010042b:	e8 c9 fe ff ff       	call   f01002f9 <cons_putc>
		cons_putc(' ');
f0100430:	b8 20 00 00 00       	mov    $0x20,%eax
f0100435:	e8 bf fe ff ff       	call   f01002f9 <cons_putc>
		cons_putc(' ');
f010043a:	b8 20 00 00 00       	mov    $0x20,%eax
f010043f:	e8 b5 fe ff ff       	call   f01002f9 <cons_putc>
f0100444:	eb 1e                	jmp    f0100464 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f0100446:	0f b7 05 a8 c1 17 f0 	movzwl 0xf017c1a8,%eax
f010044d:	8d 50 01             	lea    0x1(%eax),%edx
f0100450:	66 89 15 a8 c1 17 f0 	mov    %dx,0xf017c1a8
f0100457:	0f b7 c0             	movzwl %ax,%eax
f010045a:	8b 15 ac c1 17 f0    	mov    0xf017c1ac,%edx
f0100460:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100464:	66 81 3d a8 c1 17 f0 	cmpw   $0x7cf,0xf017c1a8
f010046b:	cf 07 
f010046d:	76 42                	jbe    f01004b1 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010046f:	a1 ac c1 17 f0       	mov    0xf017c1ac,%eax
f0100474:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010047b:	00 
f010047c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100482:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100486:	89 04 24             	mov    %eax,(%esp)
f0100489:	e8 38 41 00 00       	call   f01045c6 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010048e:	8b 15 ac c1 17 f0    	mov    0xf017c1ac,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100494:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100499:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010049f:	83 c0 01             	add    $0x1,%eax
f01004a2:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f01004a7:	75 f0                	jne    f0100499 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f01004a9:	66 83 2d a8 c1 17 f0 	subw   $0x50,0xf017c1a8
f01004b0:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f01004b1:	8b 0d b0 c1 17 f0    	mov    0xf017c1b0,%ecx
f01004b7:	b8 0e 00 00 00       	mov    $0xe,%eax
f01004bc:	89 ca                	mov    %ecx,%edx
f01004be:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f01004bf:	0f b7 1d a8 c1 17 f0 	movzwl 0xf017c1a8,%ebx
f01004c6:	8d 71 01             	lea    0x1(%ecx),%esi
f01004c9:	89 d8                	mov    %ebx,%eax
f01004cb:	66 c1 e8 08          	shr    $0x8,%ax
f01004cf:	89 f2                	mov    %esi,%edx
f01004d1:	ee                   	out    %al,(%dx)
f01004d2:	b8 0f 00 00 00       	mov    $0xf,%eax
f01004d7:	89 ca                	mov    %ecx,%edx
f01004d9:	ee                   	out    %al,(%dx)
f01004da:	89 d8                	mov    %ebx,%eax
f01004dc:	89 f2                	mov    %esi,%edx
f01004de:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f01004df:	83 c4 1c             	add    $0x1c,%esp
f01004e2:	5b                   	pop    %ebx
f01004e3:	5e                   	pop    %esi
f01004e4:	5f                   	pop    %edi
f01004e5:	5d                   	pop    %ebp
f01004e6:	c3                   	ret    

f01004e7 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f01004e7:	83 3d b4 c1 17 f0 00 	cmpl   $0x0,0xf017c1b4
f01004ee:	74 11                	je     f0100501 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f01004f0:	55                   	push   %ebp
f01004f1:	89 e5                	mov    %esp,%ebp
f01004f3:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f01004f6:	b8 90 01 10 f0       	mov    $0xf0100190,%eax
f01004fb:	e8 ac fc ff ff       	call   f01001ac <cons_intr>
}
f0100500:	c9                   	leave  
f0100501:	f3 c3                	repz ret 

f0100503 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100503:	55                   	push   %ebp
f0100504:	89 e5                	mov    %esp,%ebp
f0100506:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100509:	b8 f0 01 10 f0       	mov    $0xf01001f0,%eax
f010050e:	e8 99 fc ff ff       	call   f01001ac <cons_intr>
}
f0100513:	c9                   	leave  
f0100514:	c3                   	ret    

f0100515 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100515:	55                   	push   %ebp
f0100516:	89 e5                	mov    %esp,%ebp
f0100518:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010051b:	e8 c7 ff ff ff       	call   f01004e7 <serial_intr>
	kbd_intr();
f0100520:	e8 de ff ff ff       	call   f0100503 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100525:	a1 a0 c1 17 f0       	mov    0xf017c1a0,%eax
f010052a:	3b 05 a4 c1 17 f0    	cmp    0xf017c1a4,%eax
f0100530:	74 26                	je     f0100558 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100532:	8d 50 01             	lea    0x1(%eax),%edx
f0100535:	89 15 a0 c1 17 f0    	mov    %edx,0xf017c1a0
f010053b:	0f b6 88 a0 bf 17 f0 	movzbl -0xfe84060(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f0100542:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f0100544:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f010054a:	75 11                	jne    f010055d <cons_getc+0x48>
			cons.rpos = 0;
f010054c:	c7 05 a0 c1 17 f0 00 	movl   $0x0,0xf017c1a0
f0100553:	00 00 00 
f0100556:	eb 05                	jmp    f010055d <cons_getc+0x48>
		return c;
	}
	return 0;
f0100558:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010055d:	c9                   	leave  
f010055e:	c3                   	ret    

f010055f <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f010055f:	55                   	push   %ebp
f0100560:	89 e5                	mov    %esp,%ebp
f0100562:	57                   	push   %edi
f0100563:	56                   	push   %esi
f0100564:	53                   	push   %ebx
f0100565:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f0100568:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f010056f:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100576:	5a a5 
	if (*cp != 0xA55A) {
f0100578:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010057f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100583:	74 11                	je     f0100596 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100585:	c7 05 b0 c1 17 f0 b4 	movl   $0x3b4,0xf017c1b0
f010058c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010058f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100594:	eb 16                	jmp    f01005ac <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100596:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010059d:	c7 05 b0 c1 17 f0 d4 	movl   $0x3d4,0xf017c1b0
f01005a4:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f01005a7:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f01005ac:	8b 0d b0 c1 17 f0    	mov    0xf017c1b0,%ecx
f01005b2:	b8 0e 00 00 00       	mov    $0xe,%eax
f01005b7:	89 ca                	mov    %ecx,%edx
f01005b9:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f01005ba:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005bd:	89 da                	mov    %ebx,%edx
f01005bf:	ec                   	in     (%dx),%al
f01005c0:	0f b6 f0             	movzbl %al,%esi
f01005c3:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005c6:	b8 0f 00 00 00       	mov    $0xf,%eax
f01005cb:	89 ca                	mov    %ecx,%edx
f01005cd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01005ce:	89 da                	mov    %ebx,%edx
f01005d0:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f01005d1:	89 3d ac c1 17 f0    	mov    %edi,0xf017c1ac
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005d7:	0f b6 d8             	movzbl %al,%ebx
f01005da:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005dc:	66 89 35 a8 c1 17 f0 	mov    %si,0xf017c1a8
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01005e3:	be fa 03 00 00       	mov    $0x3fa,%esi
f01005e8:	b8 00 00 00 00       	mov    $0x0,%eax
f01005ed:	89 f2                	mov    %esi,%edx
f01005ef:	ee                   	out    %al,(%dx)
f01005f0:	b2 fb                	mov    $0xfb,%dl
f01005f2:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01005f7:	ee                   	out    %al,(%dx)
f01005f8:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01005fd:	b8 0c 00 00 00       	mov    $0xc,%eax
f0100602:	89 da                	mov    %ebx,%edx
f0100604:	ee                   	out    %al,(%dx)
f0100605:	b2 f9                	mov    $0xf9,%dl
f0100607:	b8 00 00 00 00       	mov    $0x0,%eax
f010060c:	ee                   	out    %al,(%dx)
f010060d:	b2 fb                	mov    $0xfb,%dl
f010060f:	b8 03 00 00 00       	mov    $0x3,%eax
f0100614:	ee                   	out    %al,(%dx)
f0100615:	b2 fc                	mov    $0xfc,%dl
f0100617:	b8 00 00 00 00       	mov    $0x0,%eax
f010061c:	ee                   	out    %al,(%dx)
f010061d:	b2 f9                	mov    $0xf9,%dl
f010061f:	b8 01 00 00 00       	mov    $0x1,%eax
f0100624:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100625:	b2 fd                	mov    $0xfd,%dl
f0100627:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f0100628:	3c ff                	cmp    $0xff,%al
f010062a:	0f 95 c1             	setne  %cl
f010062d:	0f b6 c9             	movzbl %cl,%ecx
f0100630:	89 0d b4 c1 17 f0    	mov    %ecx,0xf017c1b4
f0100636:	89 f2                	mov    %esi,%edx
f0100638:	ec                   	in     (%dx),%al
f0100639:	89 da                	mov    %ebx,%edx
f010063b:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f010063c:	85 c9                	test   %ecx,%ecx
f010063e:	75 0c                	jne    f010064c <cons_init+0xed>
		cprintf("Serial port does not exist!\n");
f0100640:	c7 04 24 b3 4a 10 f0 	movl   $0xf0104ab3,(%esp)
f0100647:	e8 88 2e 00 00       	call   f01034d4 <cprintf>
}
f010064c:	83 c4 1c             	add    $0x1c,%esp
f010064f:	5b                   	pop    %ebx
f0100650:	5e                   	pop    %esi
f0100651:	5f                   	pop    %edi
f0100652:	5d                   	pop    %ebp
f0100653:	c3                   	ret    

f0100654 <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f0100654:	55                   	push   %ebp
f0100655:	89 e5                	mov    %esp,%ebp
f0100657:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f010065a:	8b 45 08             	mov    0x8(%ebp),%eax
f010065d:	e8 97 fc ff ff       	call   f01002f9 <cons_putc>
}
f0100662:	c9                   	leave  
f0100663:	c3                   	ret    

f0100664 <getchar>:

int
getchar(void)
{
f0100664:	55                   	push   %ebp
f0100665:	89 e5                	mov    %esp,%ebp
f0100667:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f010066a:	e8 a6 fe ff ff       	call   f0100515 <cons_getc>
f010066f:	85 c0                	test   %eax,%eax
f0100671:	74 f7                	je     f010066a <getchar+0x6>
		/* do nothing */;
	return c;
}
f0100673:	c9                   	leave  
f0100674:	c3                   	ret    

f0100675 <iscons>:

int
iscons(int fdnum)
{
f0100675:	55                   	push   %ebp
f0100676:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100678:	b8 01 00 00 00       	mov    $0x1,%eax
f010067d:	5d                   	pop    %ebp
f010067e:	c3                   	ret    
f010067f:	90                   	nop

f0100680 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100680:	55                   	push   %ebp
f0100681:	89 e5                	mov    %esp,%ebp
f0100683:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100686:	c7 44 24 08 00 4d 10 	movl   $0xf0104d00,0x8(%esp)
f010068d:	f0 
f010068e:	c7 44 24 04 1e 4d 10 	movl   $0xf0104d1e,0x4(%esp)
f0100695:	f0 
f0100696:	c7 04 24 23 4d 10 f0 	movl   $0xf0104d23,(%esp)
f010069d:	e8 32 2e 00 00       	call   f01034d4 <cprintf>
f01006a2:	c7 44 24 08 c8 4d 10 	movl   $0xf0104dc8,0x8(%esp)
f01006a9:	f0 
f01006aa:	c7 44 24 04 2c 4d 10 	movl   $0xf0104d2c,0x4(%esp)
f01006b1:	f0 
f01006b2:	c7 04 24 23 4d 10 f0 	movl   $0xf0104d23,(%esp)
f01006b9:	e8 16 2e 00 00       	call   f01034d4 <cprintf>
f01006be:	c7 44 24 08 35 4d 10 	movl   $0xf0104d35,0x8(%esp)
f01006c5:	f0 
f01006c6:	c7 44 24 04 53 4d 10 	movl   $0xf0104d53,0x4(%esp)
f01006cd:	f0 
f01006ce:	c7 04 24 23 4d 10 f0 	movl   $0xf0104d23,(%esp)
f01006d5:	e8 fa 2d 00 00       	call   f01034d4 <cprintf>
	return 0;
}
f01006da:	b8 00 00 00 00       	mov    $0x0,%eax
f01006df:	c9                   	leave  
f01006e0:	c3                   	ret    

f01006e1 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f01006e1:	55                   	push   %ebp
f01006e2:	89 e5                	mov    %esp,%ebp
f01006e4:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f01006e7:	c7 04 24 61 4d 10 f0 	movl   $0xf0104d61,(%esp)
f01006ee:	e8 e1 2d 00 00       	call   f01034d4 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f01006f3:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01006fa:	00 
f01006fb:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f0100702:	f0 
f0100703:	c7 04 24 f0 4d 10 f0 	movl   $0xf0104df0,(%esp)
f010070a:	e8 c5 2d 00 00       	call   f01034d4 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010070f:	c7 44 24 08 37 4a 10 	movl   $0x104a37,0x8(%esp)
f0100716:	00 
f0100717:	c7 44 24 04 37 4a 10 	movl   $0xf0104a37,0x4(%esp)
f010071e:	f0 
f010071f:	c7 04 24 14 4e 10 f0 	movl   $0xf0104e14,(%esp)
f0100726:	e8 a9 2d 00 00       	call   f01034d4 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f010072b:	c7 44 24 08 69 bf 17 	movl   $0x17bf69,0x8(%esp)
f0100732:	00 
f0100733:	c7 44 24 04 69 bf 17 	movl   $0xf017bf69,0x4(%esp)
f010073a:	f0 
f010073b:	c7 04 24 38 4e 10 f0 	movl   $0xf0104e38,(%esp)
f0100742:	e8 8d 2d 00 00       	call   f01034d4 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f0100747:	c7 44 24 08 90 ce 17 	movl   $0x17ce90,0x8(%esp)
f010074e:	00 
f010074f:	c7 44 24 04 90 ce 17 	movl   $0xf017ce90,0x4(%esp)
f0100756:	f0 
f0100757:	c7 04 24 5c 4e 10 f0 	movl   $0xf0104e5c,(%esp)
f010075e:	e8 71 2d 00 00       	call   f01034d4 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f0100763:	b8 8f d2 17 f0       	mov    $0xf017d28f,%eax
f0100768:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf("Special kernel symbols:\n");
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f010076d:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100773:	85 c0                	test   %eax,%eax
f0100775:	0f 48 c2             	cmovs  %edx,%eax
f0100778:	c1 f8 0a             	sar    $0xa,%eax
f010077b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010077f:	c7 04 24 80 4e 10 f0 	movl   $0xf0104e80,(%esp)
f0100786:	e8 49 2d 00 00       	call   f01034d4 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f010078b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100790:	c9                   	leave  
f0100791:	c3                   	ret    

f0100792 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f0100792:	55                   	push   %ebp
f0100793:	89 e5                	mov    %esp,%ebp
f0100795:	53                   	push   %ebx
f0100796:	83 ec 44             	sub    $0x44,%esp

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f0100799:	89 eb                	mov    %ebp,%ebx
	unsigned int ebp;
	unsigned int eip;
	unsigned int args[5];
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
f010079b:	c7 04 24 7a 4d 10 f0 	movl   $0xf0104d7a,(%esp)
f01007a2:	e8 2d 2d 00 00       	call   f01034d4 <cprintf>
	do{
           eip = *((unsigned int*)(ebp + 4));
f01007a7:	8b 4b 04             	mov    0x4(%ebx),%ecx
           for(i=0;i<5;i++)
f01007aa:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *((unsigned int*)(ebp+8+4*i));
f01007af:	8b 54 83 08          	mov    0x8(%ebx,%eax,4),%edx
f01007b3:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
	do{
           eip = *((unsigned int*)(ebp + 4));
           for(i=0;i<5;i++)
f01007b7:	83 c0 01             	add    $0x1,%eax
f01007ba:	83 f8 05             	cmp    $0x5,%eax
f01007bd:	75 f0                	jne    f01007af <mon_backtrace+0x1d>
		args[i] = *((unsigned int*)(ebp+8+4*i));
	cprintf(" ebp %08x eip %08x args %08x %08x %08x %08x %08x\n",
f01007bf:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01007c2:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f01007c6:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01007c9:	89 44 24 18          	mov    %eax,0x18(%esp)
f01007cd:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01007d0:	89 44 24 14          	mov    %eax,0x14(%esp)
f01007d4:	8b 45 e8             	mov    -0x18(%ebp),%eax
f01007d7:	89 44 24 10          	mov    %eax,0x10(%esp)
f01007db:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01007de:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01007e2:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01007e6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01007ea:	c7 04 24 ac 4e 10 f0 	movl   $0xf0104eac,(%esp)
f01007f1:	e8 de 2c 00 00       	call   f01034d4 <cprintf>
		ebp,eip,args[0],args[1],args[2],args[3],args[4]);
	ebp =*((unsigned int*)ebp);
f01007f6:	8b 1b                	mov    (%ebx),%ebx
	}while(ebp!=0);
f01007f8:	85 db                	test   %ebx,%ebx
f01007fa:	75 ab                	jne    f01007a7 <mon_backtrace+0x15>
	return 0;
}
f01007fc:	b8 00 00 00 00       	mov    $0x0,%eax
f0100801:	83 c4 44             	add    $0x44,%esp
f0100804:	5b                   	pop    %ebx
f0100805:	5d                   	pop    %ebp
f0100806:	c3                   	ret    

f0100807 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100807:	55                   	push   %ebp
f0100808:	89 e5                	mov    %esp,%ebp
f010080a:	57                   	push   %edi
f010080b:	56                   	push   %esi
f010080c:	53                   	push   %ebx
f010080d:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f0100810:	c7 04 24 e0 4e 10 f0 	movl   $0xf0104ee0,(%esp)
f0100817:	e8 b8 2c 00 00       	call   f01034d4 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010081c:	c7 04 24 04 4f 10 f0 	movl   $0xf0104f04,(%esp)
f0100823:	e8 ac 2c 00 00       	call   f01034d4 <cprintf>

	if (tf != NULL)
f0100828:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f010082c:	74 0b                	je     f0100839 <monitor+0x32>
		print_trapframe(tf);
f010082e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100831:	89 04 24             	mov    %eax,(%esp)
f0100834:	e8 c3 2d 00 00       	call   f01035fc <print_trapframe>

	while (1) {
		buf = readline("K> ");
f0100839:	c7 04 24 8c 4d 10 f0 	movl   $0xf0104d8c,(%esp)
f0100840:	e8 5b 3a 00 00       	call   f01042a0 <readline>
f0100845:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100847:	85 c0                	test   %eax,%eax
f0100849:	74 ee                	je     f0100839 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f010084b:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100852:	be 00 00 00 00       	mov    $0x0,%esi
f0100857:	eb 0a                	jmp    f0100863 <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100859:	c6 03 00             	movb   $0x0,(%ebx)
f010085c:	89 f7                	mov    %esi,%edi
f010085e:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100861:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100863:	0f b6 03             	movzbl (%ebx),%eax
f0100866:	84 c0                	test   %al,%al
f0100868:	74 6a                	je     f01008d4 <monitor+0xcd>
f010086a:	0f be c0             	movsbl %al,%eax
f010086d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100871:	c7 04 24 90 4d 10 f0 	movl   $0xf0104d90,(%esp)
f0100878:	e8 9c 3c 00 00       	call   f0104519 <strchr>
f010087d:	85 c0                	test   %eax,%eax
f010087f:	75 d8                	jne    f0100859 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100881:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100884:	74 4e                	je     f01008d4 <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100886:	83 fe 0f             	cmp    $0xf,%esi
f0100889:	75 16                	jne    f01008a1 <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f010088b:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100892:	00 
f0100893:	c7 04 24 95 4d 10 f0 	movl   $0xf0104d95,(%esp)
f010089a:	e8 35 2c 00 00       	call   f01034d4 <cprintf>
f010089f:	eb 98                	jmp    f0100839 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f01008a1:	8d 7e 01             	lea    0x1(%esi),%edi
f01008a4:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f01008a8:	0f b6 03             	movzbl (%ebx),%eax
f01008ab:	84 c0                	test   %al,%al
f01008ad:	75 0c                	jne    f01008bb <monitor+0xb4>
f01008af:	eb b0                	jmp    f0100861 <monitor+0x5a>
			buf++;
f01008b1:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008b4:	0f b6 03             	movzbl (%ebx),%eax
f01008b7:	84 c0                	test   %al,%al
f01008b9:	74 a6                	je     f0100861 <monitor+0x5a>
f01008bb:	0f be c0             	movsbl %al,%eax
f01008be:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008c2:	c7 04 24 90 4d 10 f0 	movl   $0xf0104d90,(%esp)
f01008c9:	e8 4b 3c 00 00       	call   f0104519 <strchr>
f01008ce:	85 c0                	test   %eax,%eax
f01008d0:	74 df                	je     f01008b1 <monitor+0xaa>
f01008d2:	eb 8d                	jmp    f0100861 <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f01008d4:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f01008db:	00 

	// Lookup and invoke the command
	if (argc == 0)
f01008dc:	85 f6                	test   %esi,%esi
f01008de:	0f 84 55 ff ff ff    	je     f0100839 <monitor+0x32>
f01008e4:	bb 00 00 00 00       	mov    $0x0,%ebx
f01008e9:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f01008ec:	8b 04 85 40 4f 10 f0 	mov    -0xfefb0c0(,%eax,4),%eax
f01008f3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008f7:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008fa:	89 04 24             	mov    %eax,(%esp)
f01008fd:	e8 93 3b 00 00       	call   f0104495 <strcmp>
f0100902:	85 c0                	test   %eax,%eax
f0100904:	75 24                	jne    f010092a <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100906:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100909:	8b 55 08             	mov    0x8(%ebp),%edx
f010090c:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100910:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100913:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100917:	89 34 24             	mov    %esi,(%esp)
f010091a:	ff 14 85 48 4f 10 f0 	call   *-0xfefb0b8(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100921:	85 c0                	test   %eax,%eax
f0100923:	78 25                	js     f010094a <monitor+0x143>
f0100925:	e9 0f ff ff ff       	jmp    f0100839 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f010092a:	83 c3 01             	add    $0x1,%ebx
f010092d:	83 fb 03             	cmp    $0x3,%ebx
f0100930:	75 b7                	jne    f01008e9 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100932:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100935:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100939:	c7 04 24 b2 4d 10 f0 	movl   $0xf0104db2,(%esp)
f0100940:	e8 8f 2b 00 00       	call   f01034d4 <cprintf>
f0100945:	e9 ef fe ff ff       	jmp    f0100839 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f010094a:	83 c4 5c             	add    $0x5c,%esp
f010094d:	5b                   	pop    %ebx
f010094e:	5e                   	pop    %esi
f010094f:	5f                   	pop    %edi
f0100950:	5d                   	pop    %ebp
f0100951:	c3                   	ret    

f0100952 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100952:	55                   	push   %ebp
f0100953:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100955:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100958:	5d                   	pop    %ebp
f0100959:	c3                   	ret    
f010095a:	66 90                	xchg   %ax,%ax
f010095c:	66 90                	xchg   %ax,%ax
f010095e:	66 90                	xchg   %ax,%ax

f0100960 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100960:	55                   	push   %ebp
f0100961:	89 e5                	mov    %esp,%ebp
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100963:	83 3d b8 c1 17 f0 00 	cmpl   $0x0,0xf017c1b8
f010096a:	75 11                	jne    f010097d <boot_alloc+0x1d>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f010096c:	ba 8f de 17 f0       	mov    $0xf017de8f,%edx
f0100971:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0100977:	89 15 b8 c1 17 f0    	mov    %edx,0xf017c1b8
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
    result=nextfree;  
f010097d:	8b 15 b8 c1 17 f0    	mov    0xf017c1b8,%edx
    nextfree+=ROUNDUP(n,PGSIZE);  
f0100983:	05 ff 0f 00 00       	add    $0xfff,%eax
f0100988:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010098d:	01 d0                	add    %edx,%eax
f010098f:	a3 b8 c1 17 f0       	mov    %eax,0xf017c1b8
    return result;  
}
f0100994:	89 d0                	mov    %edx,%eax
f0100996:	5d                   	pop    %ebp
f0100997:	c3                   	ret    

f0100998 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100998:	89 d1                	mov    %edx,%ecx
f010099a:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f010099d:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f01009a0:	a8 01                	test   $0x1,%al
f01009a2:	74 5d                	je     f0100a01 <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f01009a4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01009a9:	89 c1                	mov    %eax,%ecx
f01009ab:	c1 e9 0c             	shr    $0xc,%ecx
f01009ae:	3b 0d 84 ce 17 f0    	cmp    0xf017ce84,%ecx
f01009b4:	72 26                	jb     f01009dc <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f01009b6:	55                   	push   %ebp
f01009b7:	89 e5                	mov    %esp,%ebp
f01009b9:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01009bc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01009c0:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f01009c7:	f0 
f01009c8:	c7 44 24 04 64 03 00 	movl   $0x364,0x4(%esp)
f01009cf:	00 
f01009d0:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01009d7:	e8 05 f7 ff ff       	call   f01000e1 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f01009dc:	c1 ea 0c             	shr    $0xc,%edx
f01009df:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f01009e5:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f01009ec:	89 c2                	mov    %eax,%edx
f01009ee:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f01009f1:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01009f6:	85 d2                	test   %edx,%edx
f01009f8:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f01009fd:	0f 44 c2             	cmove  %edx,%eax
f0100a00:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100a01:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100a06:	c3                   	ret    

f0100a07 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100a07:	55                   	push   %ebp
f0100a08:	89 e5                	mov    %esp,%ebp
f0100a0a:	57                   	push   %edi
f0100a0b:	56                   	push   %esi
f0100a0c:	53                   	push   %ebx
f0100a0d:	83 ec 3c             	sub    $0x3c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100a10:	85 c0                	test   %eax,%eax
f0100a12:	0f 85 35 03 00 00    	jne    f0100d4d <check_page_free_list+0x346>
f0100a18:	e9 42 03 00 00       	jmp    f0100d5f <check_page_free_list+0x358>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100a1d:	c7 44 24 08 88 4f 10 	movl   $0xf0104f88,0x8(%esp)
f0100a24:	f0 
f0100a25:	c7 44 24 04 a2 02 00 	movl   $0x2a2,0x4(%esp)
f0100a2c:	00 
f0100a2d:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100a34:	e8 a8 f6 ff ff       	call   f01000e1 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100a39:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100a3c:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100a3f:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100a42:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100a45:	89 c2                	mov    %eax,%edx
f0100a47:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100a4d:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100a53:	0f 95 c2             	setne  %dl
f0100a56:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100a59:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100a5d:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100a5f:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100a63:	8b 00                	mov    (%eax),%eax
f0100a65:	85 c0                	test   %eax,%eax
f0100a67:	75 dc                	jne    f0100a45 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100a69:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100a6c:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100a72:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100a75:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100a78:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100a7a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100a7d:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100a82:	89 c3                	mov    %eax,%ebx
f0100a84:	85 c0                	test   %eax,%eax
f0100a86:	74 6c                	je     f0100af4 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100a88:	be 01 00 00 00       	mov    $0x1,%esi
f0100a8d:	89 d8                	mov    %ebx,%eax
f0100a8f:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f0100a95:	c1 f8 03             	sar    $0x3,%eax
f0100a98:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100a9b:	89 c2                	mov    %eax,%edx
f0100a9d:	c1 ea 16             	shr    $0x16,%edx
f0100aa0:	39 f2                	cmp    %esi,%edx
f0100aa2:	73 4a                	jae    f0100aee <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100aa4:	89 c2                	mov    %eax,%edx
f0100aa6:	c1 ea 0c             	shr    $0xc,%edx
f0100aa9:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f0100aaf:	72 20                	jb     f0100ad1 <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ab1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ab5:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0100abc:	f0 
f0100abd:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ac4:	00 
f0100ac5:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0100acc:	e8 10 f6 ff ff       	call   f01000e1 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100ad1:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100ad8:	00 
f0100ad9:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ae0:	00 
	return (void *)(pa + KERNBASE);
f0100ae1:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100ae6:	89 04 24             	mov    %eax,(%esp)
f0100ae9:	e8 8b 3a 00 00       	call   f0104579 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100aee:	8b 1b                	mov    (%ebx),%ebx
f0100af0:	85 db                	test   %ebx,%ebx
f0100af2:	75 99                	jne    f0100a8d <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100af4:	b8 00 00 00 00       	mov    $0x0,%eax
f0100af9:	e8 62 fe ff ff       	call   f0100960 <boot_alloc>
f0100afe:	89 45 cc             	mov    %eax,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100b01:	8b 15 c0 c1 17 f0    	mov    0xf017c1c0,%edx
f0100b07:	85 d2                	test   %edx,%edx
f0100b09:	0f 84 f2 01 00 00    	je     f0100d01 <check_page_free_list+0x2fa>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b0f:	8b 1d 8c ce 17 f0    	mov    0xf017ce8c,%ebx
f0100b15:	39 da                	cmp    %ebx,%edx
f0100b17:	72 3f                	jb     f0100b58 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100b19:	a1 84 ce 17 f0       	mov    0xf017ce84,%eax
f0100b1e:	89 45 c8             	mov    %eax,-0x38(%ebp)
f0100b21:	8d 04 c3             	lea    (%ebx,%eax,8),%eax
f0100b24:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100b27:	39 c2                	cmp    %eax,%edx
f0100b29:	73 56                	jae    f0100b81 <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100b2b:	89 5d d0             	mov    %ebx,-0x30(%ebp)
f0100b2e:	89 d0                	mov    %edx,%eax
f0100b30:	29 d8                	sub    %ebx,%eax
f0100b32:	a8 07                	test   $0x7,%al
f0100b34:	75 78                	jne    f0100bae <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b36:	c1 f8 03             	sar    $0x3,%eax
f0100b39:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100b3c:	85 c0                	test   %eax,%eax
f0100b3e:	0f 84 98 00 00 00    	je     f0100bdc <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100b44:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100b49:	0f 85 dc 00 00 00    	jne    f0100c2b <check_page_free_list+0x224>
f0100b4f:	e9 b3 00 00 00       	jmp    f0100c07 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100b54:	39 d3                	cmp    %edx,%ebx
f0100b56:	76 24                	jbe    f0100b7c <check_page_free_list+0x175>
f0100b58:	c7 44 24 0c c3 56 10 	movl   $0xf01056c3,0xc(%esp)
f0100b5f:	f0 
f0100b60:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100b67:	f0 
f0100b68:	c7 44 24 04 bc 02 00 	movl   $0x2bc,0x4(%esp)
f0100b6f:	00 
f0100b70:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100b77:	e8 65 f5 ff ff       	call   f01000e1 <_panic>
		assert(pp < pages + npages);
f0100b7c:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100b7f:	72 24                	jb     f0100ba5 <check_page_free_list+0x19e>
f0100b81:	c7 44 24 0c e4 56 10 	movl   $0xf01056e4,0xc(%esp)
f0100b88:	f0 
f0100b89:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100b90:	f0 
f0100b91:	c7 44 24 04 bd 02 00 	movl   $0x2bd,0x4(%esp)
f0100b98:	00 
f0100b99:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100ba0:	e8 3c f5 ff ff       	call   f01000e1 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100ba5:	89 d0                	mov    %edx,%eax
f0100ba7:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100baa:	a8 07                	test   $0x7,%al
f0100bac:	74 24                	je     f0100bd2 <check_page_free_list+0x1cb>
f0100bae:	c7 44 24 0c ac 4f 10 	movl   $0xf0104fac,0xc(%esp)
f0100bb5:	f0 
f0100bb6:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100bbd:	f0 
f0100bbe:	c7 44 24 04 be 02 00 	movl   $0x2be,0x4(%esp)
f0100bc5:	00 
f0100bc6:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100bcd:	e8 0f f5 ff ff       	call   f01000e1 <_panic>
f0100bd2:	c1 f8 03             	sar    $0x3,%eax
f0100bd5:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100bd8:	85 c0                	test   %eax,%eax
f0100bda:	75 24                	jne    f0100c00 <check_page_free_list+0x1f9>
f0100bdc:	c7 44 24 0c f8 56 10 	movl   $0xf01056f8,0xc(%esp)
f0100be3:	f0 
f0100be4:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100beb:	f0 
f0100bec:	c7 44 24 04 c1 02 00 	movl   $0x2c1,0x4(%esp)
f0100bf3:	00 
f0100bf4:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100bfb:	e8 e1 f4 ff ff       	call   f01000e1 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100c00:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100c05:	75 2e                	jne    f0100c35 <check_page_free_list+0x22e>
f0100c07:	c7 44 24 0c 09 57 10 	movl   $0xf0105709,0xc(%esp)
f0100c0e:	f0 
f0100c0f:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100c16:	f0 
f0100c17:	c7 44 24 04 c2 02 00 	movl   $0x2c2,0x4(%esp)
f0100c1e:	00 
f0100c1f:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100c26:	e8 b6 f4 ff ff       	call   f01000e1 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100c2b:	be 00 00 00 00       	mov    $0x0,%esi
f0100c30:	bf 00 00 00 00       	mov    $0x0,%edi
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100c35:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100c3a:	75 24                	jne    f0100c60 <check_page_free_list+0x259>
f0100c3c:	c7 44 24 0c e0 4f 10 	movl   $0xf0104fe0,0xc(%esp)
f0100c43:	f0 
f0100c44:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100c4b:	f0 
f0100c4c:	c7 44 24 04 c3 02 00 	movl   $0x2c3,0x4(%esp)
f0100c53:	00 
f0100c54:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100c5b:	e8 81 f4 ff ff       	call   f01000e1 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100c60:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100c65:	75 24                	jne    f0100c8b <check_page_free_list+0x284>
f0100c67:	c7 44 24 0c 22 57 10 	movl   $0xf0105722,0xc(%esp)
f0100c6e:	f0 
f0100c6f:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100c76:	f0 
f0100c77:	c7 44 24 04 c4 02 00 	movl   $0x2c4,0x4(%esp)
f0100c7e:	00 
f0100c7f:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100c86:	e8 56 f4 ff ff       	call   f01000e1 <_panic>
f0100c8b:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100c8d:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100c92:	76 57                	jbe    f0100ceb <check_page_free_list+0x2e4>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100c94:	c1 e8 0c             	shr    $0xc,%eax
f0100c97:	39 45 c8             	cmp    %eax,-0x38(%ebp)
f0100c9a:	77 20                	ja     f0100cbc <check_page_free_list+0x2b5>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100c9c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100ca0:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0100ca7:	f0 
f0100ca8:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100caf:	00 
f0100cb0:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0100cb7:	e8 25 f4 ff ff       	call   f01000e1 <_panic>
	return (void *)(pa + KERNBASE);
f0100cbc:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100cc2:	39 4d cc             	cmp    %ecx,-0x34(%ebp)
f0100cc5:	76 29                	jbe    f0100cf0 <check_page_free_list+0x2e9>
f0100cc7:	c7 44 24 0c 04 50 10 	movl   $0xf0105004,0xc(%esp)
f0100cce:	f0 
f0100ccf:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100cd6:	f0 
f0100cd7:	c7 44 24 04 c5 02 00 	movl   $0x2c5,0x4(%esp)
f0100cde:	00 
f0100cdf:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100ce6:	e8 f6 f3 ff ff       	call   f01000e1 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100ceb:	83 c7 01             	add    $0x1,%edi
f0100cee:	eb 03                	jmp    f0100cf3 <check_page_free_list+0x2ec>
		else
			++nfree_extmem;
f0100cf0:	83 c6 01             	add    $0x1,%esi
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100cf3:	8b 12                	mov    (%edx),%edx
f0100cf5:	85 d2                	test   %edx,%edx
f0100cf7:	0f 85 57 fe ff ff    	jne    f0100b54 <check_page_free_list+0x14d>
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100cfd:	85 ff                	test   %edi,%edi
f0100cff:	7f 24                	jg     f0100d25 <check_page_free_list+0x31e>
f0100d01:	c7 44 24 0c 3c 57 10 	movl   $0xf010573c,0xc(%esp)
f0100d08:	f0 
f0100d09:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100d10:	f0 
f0100d11:	c7 44 24 04 cd 02 00 	movl   $0x2cd,0x4(%esp)
f0100d18:	00 
f0100d19:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100d20:	e8 bc f3 ff ff       	call   f01000e1 <_panic>
	assert(nfree_extmem > 0);
f0100d25:	85 f6                	test   %esi,%esi
f0100d27:	7f 53                	jg     f0100d7c <check_page_free_list+0x375>
f0100d29:	c7 44 24 0c 4e 57 10 	movl   $0xf010574e,0xc(%esp)
f0100d30:	f0 
f0100d31:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100d38:	f0 
f0100d39:	c7 44 24 04 ce 02 00 	movl   $0x2ce,0x4(%esp)
f0100d40:	00 
f0100d41:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100d48:	e8 94 f3 ff ff       	call   f01000e1 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100d4d:	a1 c0 c1 17 f0       	mov    0xf017c1c0,%eax
f0100d52:	85 c0                	test   %eax,%eax
f0100d54:	0f 85 df fc ff ff    	jne    f0100a39 <check_page_free_list+0x32>
f0100d5a:	e9 be fc ff ff       	jmp    f0100a1d <check_page_free_list+0x16>
f0100d5f:	83 3d c0 c1 17 f0 00 	cmpl   $0x0,0xf017c1c0
f0100d66:	0f 84 b1 fc ff ff    	je     f0100a1d <check_page_free_list+0x16>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100d6c:	8b 1d c0 c1 17 f0    	mov    0xf017c1c0,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100d72:	be 00 04 00 00       	mov    $0x400,%esi
f0100d77:	e9 11 fd ff ff       	jmp    f0100a8d <check_page_free_list+0x86>
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100d7c:	83 c4 3c             	add    $0x3c,%esp
f0100d7f:	5b                   	pop    %ebx
f0100d80:	5e                   	pop    %esi
f0100d81:	5f                   	pop    %edi
f0100d82:	5d                   	pop    %ebp
f0100d83:	c3                   	ret    

f0100d84 <page_init>:
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
    uint32_t pa;
    page_free_list = NULL;
f0100d84:	c7 05 c0 c1 17 f0 00 	movl   $0x0,0xf017c1c0
f0100d8b:	00 00 00 

    for(i = 0; i<npages; i++)
f0100d8e:	83 3d 84 ce 17 f0 00 	cmpl   $0x0,0xf017ce84
f0100d95:	0f 84 0f 01 00 00    	je     f0100eaa <page_init+0x126>
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100d9b:	55                   	push   %ebp
f0100d9c:	89 e5                	mov    %esp,%ebp
f0100d9e:	57                   	push   %edi
f0100d9f:	56                   	push   %esi
f0100da0:	53                   	push   %ebx
f0100da1:	83 ec 1c             	sub    $0x1c,%esp
	// free pages!
	size_t i;
    uint32_t pa;
    page_free_list = NULL;

    for(i = 0; i<npages; i++)
f0100da4:	be 00 00 00 00       	mov    $0x0,%esi
f0100da9:	bb 00 00 00 00       	mov    $0x0,%ebx
    {
        if(i == 0)
f0100dae:	85 db                	test   %ebx,%ebx
f0100db0:	75 16                	jne    f0100dc8 <page_init+0x44>
        {
            pages[0].pp_ref = 1;
f0100db2:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
f0100db7:	66 c7 40 04 01 00    	movw   $0x1,0x4(%eax)
            pages[0].pp_link = NULL;
f0100dbd:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
            continue;
f0100dc3:	e9 c9 00 00 00       	jmp    f0100e91 <page_init+0x10d>
        }
        else if(i < npages_basemem)
f0100dc8:	39 1d c4 c1 17 f0    	cmp    %ebx,0xf017c1c4
f0100dce:	76 24                	jbe    f0100df4 <page_init+0x70>
        {
            // used for base memory
            pages[i].pp_ref = 0;
f0100dd0:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
f0100dd5:	66 c7 44 30 04 00 00 	movw   $0x0,0x4(%eax,%esi,1)
            pages[i].pp_link = page_free_list;
f0100ddc:	8b 15 c0 c1 17 f0    	mov    0xf017c1c0,%edx
f0100de2:	89 14 30             	mov    %edx,(%eax,%esi,1)
            page_free_list = &pages[i];
f0100de5:	89 f0                	mov    %esi,%eax
f0100de7:	03 05 8c ce 17 f0    	add    0xf017ce8c,%eax
f0100ded:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0
f0100df2:	eb 56                	jmp    f0100e4a <page_init+0xc6>
        }
        else if(i <= (EXTPHYSMEM/PGSIZE) || i < (((uint32_t)boot_alloc(0) - KERNBASE) >> PGSHIFT))
f0100df4:	81 fb 00 01 00 00    	cmp    $0x100,%ebx
f0100dfa:	76 16                	jbe    f0100e12 <page_init+0x8e>
f0100dfc:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e01:	e8 5a fb ff ff       	call   f0100960 <boot_alloc>
f0100e06:	05 00 00 00 10       	add    $0x10000000,%eax
f0100e0b:	c1 e8 0c             	shr    $0xc,%eax
f0100e0e:	39 d8                	cmp    %ebx,%eax
f0100e10:	76 15                	jbe    f0100e27 <page_init+0xa3>
        {
            //used for IO memory
            pages[i].pp_ref++;
f0100e12:	89 f0                	mov    %esi,%eax
f0100e14:	03 05 8c ce 17 f0    	add    0xf017ce8c,%eax
f0100e1a:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
            pages[i].pp_link = NULL;
f0100e1f:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
f0100e25:	eb 23                	jmp    f0100e4a <page_init+0xc6>
        }
        else
        {
            pages[i].pp_ref = 0;
f0100e27:	89 f0                	mov    %esi,%eax
f0100e29:	03 05 8c ce 17 f0    	add    0xf017ce8c,%eax
f0100e2f:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
            pages[i].pp_link = page_free_list;
f0100e35:	8b 15 c0 c1 17 f0    	mov    0xf017c1c0,%edx
f0100e3b:	89 10                	mov    %edx,(%eax)
            page_free_list = &pages[i];
f0100e3d:	89 f0                	mov    %esi,%eax
f0100e3f:	03 05 8c ce 17 f0    	add    0xf017ce8c,%eax
f0100e45:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100e4a:	89 f7                	mov    %esi,%edi
f0100e4c:	c1 ff 03             	sar    $0x3,%edi
f0100e4f:	c1 e7 0c             	shl    $0xc,%edi
        }

        pa = page2pa(&pages[i]);

        if((pa == 0 || (pa < IOPHYSMEM && pa <= ((uint32_t)boot_alloc(0) - KERNBASE) >> PGSHIFT)) && (pages[i].pp_ref == 0))
f0100e52:	85 ff                	test   %edi,%edi
f0100e54:	74 1e                	je     f0100e74 <page_init+0xf0>
f0100e56:	81 ff ff ff 09 00    	cmp    $0x9ffff,%edi
f0100e5c:	77 33                	ja     f0100e91 <page_init+0x10d>
f0100e5e:	b8 00 00 00 00       	mov    $0x0,%eax
f0100e63:	e8 f8 fa ff ff       	call   f0100960 <boot_alloc>
f0100e68:	05 00 00 00 10       	add    $0x10000000,%eax
f0100e6d:	c1 e8 0c             	shr    $0xc,%eax
f0100e70:	39 f8                	cmp    %edi,%eax
f0100e72:	72 1d                	jb     f0100e91 <page_init+0x10d>
f0100e74:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
f0100e79:	66 83 7c 30 04 00    	cmpw   $0x0,0x4(%eax,%esi,1)
f0100e7f:	75 10                	jne    f0100e91 <page_init+0x10d>
        {
            cprintf("page error : i %d\n",i);
f0100e81:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100e85:	c7 04 24 5f 57 10 f0 	movl   $0xf010575f,(%esp)
f0100e8c:	e8 43 26 00 00       	call   f01034d4 <cprintf>
	// free pages!
	size_t i;
    uint32_t pa;
    page_free_list = NULL;

    for(i = 0; i<npages; i++)
f0100e91:	83 c3 01             	add    $0x1,%ebx
f0100e94:	83 c6 08             	add    $0x8,%esi
f0100e97:	39 1d 84 ce 17 f0    	cmp    %ebx,0xf017ce84
f0100e9d:	0f 87 0b ff ff ff    	ja     f0100dae <page_init+0x2a>
        if((pa == 0 || (pa < IOPHYSMEM && pa <= ((uint32_t)boot_alloc(0) - KERNBASE) >> PGSHIFT)) && (pages[i].pp_ref == 0))
        {
            cprintf("page error : i %d\n",i);
        }
   }
}
f0100ea3:	83 c4 1c             	add    $0x1c,%esp
f0100ea6:	5b                   	pop    %ebx
f0100ea7:	5e                   	pop    %esi
f0100ea8:	5f                   	pop    %edi
f0100ea9:	5d                   	pop    %ebp
f0100eaa:	f3 c3                	repz ret 

f0100eac <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0100eac:	55                   	push   %ebp
f0100ead:	89 e5                	mov    %esp,%ebp
f0100eaf:	53                   	push   %ebx
f0100eb0:	83 ec 14             	sub    $0x14,%esp
	// Fill this function in
    struct Page *pp =NULL;
    if (!page_free_list)
f0100eb3:	8b 1d c0 c1 17 f0    	mov    0xf017c1c0,%ebx
f0100eb9:	85 db                	test   %ebx,%ebx
f0100ebb:	74 69                	je     f0100f26 <page_alloc+0x7a>
        return NULL;
    }

    pp = page_free_list;

    page_free_list = page_free_list->pp_link;
f0100ebd:	8b 03                	mov    (%ebx),%eax
f0100ebf:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0
    if(alloc_flags & ALLOC_ZERO)
    {
        memset(page2kva(pp), 0, PGSIZE);
    }

return pp;
f0100ec4:	89 d8                	mov    %ebx,%eax

    pp = page_free_list;

    page_free_list = page_free_list->pp_link;

    if(alloc_flags & ALLOC_ZERO)
f0100ec6:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0100eca:	74 5f                	je     f0100f2b <page_alloc+0x7f>
f0100ecc:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f0100ed2:	c1 f8 03             	sar    $0x3,%eax
f0100ed5:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ed8:	89 c2                	mov    %eax,%edx
f0100eda:	c1 ea 0c             	shr    $0xc,%edx
f0100edd:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f0100ee3:	72 20                	jb     f0100f05 <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ee5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ee9:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0100ef0:	f0 
f0100ef1:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ef8:	00 
f0100ef9:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0100f00:	e8 dc f1 ff ff       	call   f01000e1 <_panic>
    {
        memset(page2kva(pp), 0, PGSIZE);
f0100f05:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0100f0c:	00 
f0100f0d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0100f14:	00 
	return (void *)(pa + KERNBASE);
f0100f15:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100f1a:	89 04 24             	mov    %eax,(%esp)
f0100f1d:	e8 57 36 00 00       	call   f0104579 <memset>
    }

return pp;
f0100f22:	89 d8                	mov    %ebx,%eax
f0100f24:	eb 05                	jmp    f0100f2b <page_alloc+0x7f>
{
	// Fill this function in
    struct Page *pp =NULL;
    if (!page_free_list)
    {
        return NULL;
f0100f26:	b8 00 00 00 00       	mov    $0x0,%eax
    {
        memset(page2kva(pp), 0, PGSIZE);
    }

return pp;
}
f0100f2b:	83 c4 14             	add    $0x14,%esp
f0100f2e:	5b                   	pop    %ebx
f0100f2f:	5d                   	pop    %ebp
f0100f30:	c3                   	ret    

f0100f31 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0100f31:	55                   	push   %ebp
f0100f32:	89 e5                	mov    %esp,%ebp
f0100f34:	83 ec 18             	sub    $0x18,%esp
f0100f37:	8b 45 08             	mov    0x8(%ebp),%eax
	// Fill this function in
    assert(pp->pp_ref == 0 || pp->pp_link == NULL);
f0100f3a:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0100f3f:	74 29                	je     f0100f6a <page_free+0x39>
f0100f41:	83 38 00             	cmpl   $0x0,(%eax)
f0100f44:	74 24                	je     f0100f6a <page_free+0x39>
f0100f46:	c7 44 24 0c 4c 50 10 	movl   $0xf010504c,0xc(%esp)
f0100f4d:	f0 
f0100f4e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0100f55:	f0 
f0100f56:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
f0100f5d:	00 
f0100f5e:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0100f65:	e8 77 f1 ff ff       	call   f01000e1 <_panic>
    pp->pp_link = page_free_list;
f0100f6a:	8b 15 c0 c1 17 f0    	mov    0xf017c1c0,%edx
f0100f70:	89 10                	mov    %edx,(%eax)
    page_free_list = pp;
f0100f72:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0
}
f0100f77:	c9                   	leave  
f0100f78:	c3                   	ret    

f0100f79 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0100f79:	55                   	push   %ebp
f0100f7a:	89 e5                	mov    %esp,%ebp
f0100f7c:	83 ec 18             	sub    $0x18,%esp
f0100f7f:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f0100f82:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f0100f86:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100f89:	66 89 50 04          	mov    %dx,0x4(%eax)
f0100f8d:	66 85 d2             	test   %dx,%dx
f0100f90:	75 08                	jne    f0100f9a <page_decref+0x21>
		page_free(pp);
f0100f92:	89 04 24             	mov    %eax,(%esp)
f0100f95:	e8 97 ff ff ff       	call   f0100f31 <page_free>
}
f0100f9a:	c9                   	leave  
f0100f9b:	c3                   	ret    

f0100f9c <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0100f9c:	55                   	push   %ebp
f0100f9d:	89 e5                	mov    %esp,%ebp
f0100f9f:	56                   	push   %esi
f0100fa0:	53                   	push   %ebx
f0100fa1:	83 ec 10             	sub    $0x10,%esp
f0100fa4:	8b 5d 0c             	mov    0xc(%ebp),%ebx
       	// Fill this function in
	//cprintf("pgdir_walk\r\n");	
	pte_t* result =NULL;
	// 页目录的表项
	if(pgdir[PDX(va)]==(pte_t)NULL)
f0100fa7:	89 de                	mov    %ebx,%esi
f0100fa9:	c1 ee 16             	shr    $0x16,%esi
f0100fac:	c1 e6 02             	shl    $0x2,%esi
f0100faf:	03 75 08             	add    0x8(%ebp),%esi
f0100fb2:	8b 06                	mov    (%esi),%eax
f0100fb4:	85 c0                	test   %eax,%eax
f0100fb6:	75 76                	jne    f010102e <pgdir_walk+0x92>
	{
	   if(create==0)	
f0100fb8:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0100fbc:	0f 84 d1 00 00 00    	je     f0101093 <pgdir_walk+0xf7>
	    {
	    return NULL;
      	    }
	   else
           {
		struct Page *page=page_alloc(1);
f0100fc2:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0100fc9:	e8 de fe ff ff       	call   f0100eac <page_alloc>
		 if(page==NULL)	
f0100fce:	85 c0                	test   %eax,%eax
f0100fd0:	0f 84 c4 00 00 00    	je     f010109a <pgdir_walk+0xfe>
	   	 {
	   	 return NULL;
      	   	 }
		page->pp_ref++;
f0100fd6:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100fdb:	89 c2                	mov    %eax,%edx
f0100fdd:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0100fe3:	c1 fa 03             	sar    $0x3,%edx
f0100fe6:	c1 e2 0c             	shl    $0xc,%edx
		pgdir[PDX(va)]=page2pa(page)|PTE_P|PTE_W|PTE_U;
f0100fe9:	83 ca 07             	or     $0x7,%edx
f0100fec:	89 16                	mov    %edx,(%esi)
f0100fee:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f0100ff4:	c1 f8 03             	sar    $0x3,%eax
f0100ff7:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ffa:	89 c2                	mov    %eax,%edx
f0100ffc:	c1 ea 0c             	shr    $0xc,%edx
f0100fff:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f0101005:	72 20                	jb     f0101027 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101007:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010100b:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0101012:	f0 
f0101013:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010101a:	00 
f010101b:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0101022:	e8 ba f0 ff ff       	call   f01000e1 <_panic>
	return (void *)(pa + KERNBASE);
f0101027:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010102c:	eb 58                	jmp    f0101086 <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010102e:	c1 e8 0c             	shr    $0xc,%eax
f0101031:	8b 15 84 ce 17 f0    	mov    0xf017ce84,%edx
f0101037:	39 d0                	cmp    %edx,%eax
f0101039:	72 1c                	jb     f0101057 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f010103b:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f0101042:	f0 
f0101043:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010104a:	00 
f010104b:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0101052:	e8 8a f0 ff ff       	call   f01000e1 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101057:	89 c1                	mov    %eax,%ecx
f0101059:	c1 e1 0c             	shl    $0xc,%ecx
f010105c:	39 d0                	cmp    %edx,%eax
f010105e:	72 20                	jb     f0101080 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101060:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0101064:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f010106b:	f0 
f010106c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101073:	00 
f0101074:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f010107b:	e8 61 f0 ff ff       	call   f01000e1 <_panic>
	return (void *)(pa + KERNBASE);
f0101080:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
	else
	{
	    result=page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));	
	}	

	return &result[PTX(va)];
f0101086:	c1 eb 0a             	shr    $0xa,%ebx
f0101089:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f010108f:	01 d8                	add    %ebx,%eax
f0101091:	eb 0c                	jmp    f010109f <pgdir_walk+0x103>
	// 页目录的表项
	if(pgdir[PDX(va)]==(pte_t)NULL)
	{
	   if(create==0)	
	    {
	    return NULL;
f0101093:	b8 00 00 00 00       	mov    $0x0,%eax
f0101098:	eb 05                	jmp    f010109f <pgdir_walk+0x103>
	   else
           {
		struct Page *page=page_alloc(1);
		 if(page==NULL)	
	   	 {
	   	 return NULL;
f010109a:	b8 00 00 00 00       	mov    $0x0,%eax
	{
	    result=page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));	
	}	

	return &result[PTX(va)];
}
f010109f:	83 c4 10             	add    $0x10,%esp
f01010a2:	5b                   	pop    %ebx
f01010a3:	5e                   	pop    %esi
f01010a4:	5d                   	pop    %ebp
f01010a5:	c3                   	ret    

f01010a6 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
    struct Page *  
    page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)  
    {  
f01010a6:	55                   	push   %ebp
f01010a7:	89 e5                	mov    %esp,%ebp
f01010a9:	53                   	push   %ebx
f01010aa:	83 ec 14             	sub    $0x14,%esp
f01010ad:	8b 5d 10             	mov    0x10(%ebp),%ebx
       // cprintf("page_lookup\r\n");  
        // Fill this function in  
        pte_t* pte=pgdir_walk(pgdir,va,0);  
f01010b0:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01010b7:	00 
f01010b8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01010bb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01010bf:	8b 45 08             	mov    0x8(%ebp),%eax
f01010c2:	89 04 24             	mov    %eax,(%esp)
f01010c5:	e8 d2 fe ff ff       	call   f0100f9c <pgdir_walk>
        if(pte==NULL)  
f01010ca:	85 c0                	test   %eax,%eax
f01010cc:	74 3e                	je     f010110c <page_lookup+0x66>
        {  
            return NULL;  
        }  
        if(pte_store!=0)  
f01010ce:	85 db                	test   %ebx,%ebx
f01010d0:	74 02                	je     f01010d4 <page_lookup+0x2e>
        {  
            *pte_store=pte;  
f01010d2:	89 03                	mov    %eax,(%ebx)
        }  
      
        if(pte[0] !=(pte_t)NULL)  
f01010d4:	8b 00                	mov    (%eax),%eax
f01010d6:	85 c0                	test   %eax,%eax
f01010d8:	74 39                	je     f0101113 <page_lookup+0x6d>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010da:	c1 e8 0c             	shr    $0xc,%eax
f01010dd:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f01010e3:	72 1c                	jb     f0101101 <page_lookup+0x5b>
		panic("pa2page called with invalid pa");
f01010e5:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f01010ec:	f0 
f01010ed:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010f4:	00 
f01010f5:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f01010fc:	e8 e0 ef ff ff       	call   f01000e1 <_panic>
	return &pages[PGNUM(pa)];
f0101101:	8b 15 8c ce 17 f0    	mov    0xf017ce8c,%edx
f0101107:	8d 04 c2             	lea    (%edx,%eax,8),%eax
        {  
            //cprintf("%x \r\n",pte[PTX(va)]);  
            return pa2page(PTE_ADDR(pte[0]));  
f010110a:	eb 0c                	jmp    f0101118 <page_lookup+0x72>
       // cprintf("page_lookup\r\n");  
        // Fill this function in  
        pte_t* pte=pgdir_walk(pgdir,va,0);  
        if(pte==NULL)  
        {  
            return NULL;  
f010110c:	b8 00 00 00 00       	mov    $0x0,%eax
f0101111:	eb 05                	jmp    f0101118 <page_lookup+0x72>
            return pa2page(PTE_ADDR(pte[0]));  
      
        }  
        else  
        {  
            return NULL;  
f0101113:	b8 00 00 00 00       	mov    $0x0,%eax
        }  
    }  
f0101118:	83 c4 14             	add    $0x14,%esp
f010111b:	5b                   	pop    %ebx
f010111c:	5d                   	pop    %ebp
f010111d:	c3                   	ret    

f010111e <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
 void  
    page_remove(pde_t *pgdir, void *va)  
    {  
f010111e:	55                   	push   %ebp
f010111f:	89 e5                	mov    %esp,%ebp
f0101121:	53                   	push   %ebx
f0101122:	83 ec 24             	sub    $0x24,%esp
f0101125:	8b 5d 0c             	mov    0xc(%ebp),%ebx
      //  cprintf("page_remove\r\n");  
        pte_t* pte=0;  
f0101128:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
        struct Page* page=page_lookup(pgdir,va,&pte);  
f010112f:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101132:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101136:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010113a:	8b 45 08             	mov    0x8(%ebp),%eax
f010113d:	89 04 24             	mov    %eax,(%esp)
f0101140:	e8 61 ff ff ff       	call   f01010a6 <page_lookup>
        if(page!=NULL)  
f0101145:	85 c0                	test   %eax,%eax
f0101147:	74 08                	je     f0101151 <page_remove+0x33>
        {  
            page_decref(page);  
f0101149:	89 04 24             	mov    %eax,(%esp)
f010114c:	e8 28 fe ff ff       	call   f0100f79 <page_decref>
        }  
      
        pte[0]=0;  
f0101151:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101154:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f010115a:	0f 01 3b             	invlpg (%ebx)
        tlb_invalidate(pgdir,va);  
    }  
f010115d:	83 c4 24             	add    $0x24,%esp
f0101160:	5b                   	pop    %ebx
f0101161:	5d                   	pop    %ebp
f0101162:	c3                   	ret    

f0101163 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
    int  
    page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)  
    {  
f0101163:	55                   	push   %ebp
f0101164:	89 e5                	mov    %esp,%ebp
f0101166:	57                   	push   %edi
f0101167:	56                   	push   %esi
f0101168:	53                   	push   %ebx
f0101169:	83 ec 1c             	sub    $0x1c,%esp
f010116c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010116f:	8b 75 10             	mov    0x10(%ebp),%esi
       // cprintf("page_insert\r\n");  
        // Fill this function in  
        pte_t* pte;  
        struct Page* pg=page_lookup(pgdir,va,NULL);  
f0101172:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101179:	00 
f010117a:	89 74 24 04          	mov    %esi,0x4(%esp)
f010117e:	8b 45 08             	mov    0x8(%ebp),%eax
f0101181:	89 04 24             	mov    %eax,(%esp)
f0101184:	e8 1d ff ff ff       	call   f01010a6 <page_lookup>
f0101189:	89 c7                	mov    %eax,%edi
        if(pg==pp)  
f010118b:	39 d8                	cmp    %ebx,%eax
f010118d:	75 36                	jne    f01011c5 <page_insert+0x62>
        {  
            pte=pgdir_walk(pgdir,va,1);  
f010118f:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101196:	00 
f0101197:	89 74 24 04          	mov    %esi,0x4(%esp)
f010119b:	8b 45 08             	mov    0x8(%ebp),%eax
f010119e:	89 04 24             	mov    %eax,(%esp)
f01011a1:	e8 f6 fd ff ff       	call   f0100f9c <pgdir_walk>
            pte[0]=page2pa(pp)|perm|PTE_P;  
f01011a6:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01011a9:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01011ac:	2b 3d 8c ce 17 f0    	sub    0xf017ce8c,%edi
f01011b2:	c1 ff 03             	sar    $0x3,%edi
f01011b5:	c1 e7 0c             	shl    $0xc,%edi
f01011b8:	89 fa                	mov    %edi,%edx
f01011ba:	09 ca                	or     %ecx,%edx
f01011bc:	89 10                	mov    %edx,(%eax)
                return 0;  
f01011be:	b8 00 00 00 00       	mov    $0x0,%eax
f01011c3:	eb 57                	jmp    f010121c <page_insert+0xb9>
        }  
        else if(pg!=NULL )  
f01011c5:	85 c0                	test   %eax,%eax
f01011c7:	74 0f                	je     f01011d8 <page_insert+0x75>
        {  
            page_remove(pgdir,va);  
f01011c9:	89 74 24 04          	mov    %esi,0x4(%esp)
f01011cd:	8b 45 08             	mov    0x8(%ebp),%eax
f01011d0:	89 04 24             	mov    %eax,(%esp)
f01011d3:	e8 46 ff ff ff       	call   f010111e <page_remove>
        }  
        pte=pgdir_walk(pgdir,va,1);  
f01011d8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01011df:	00 
f01011e0:	89 74 24 04          	mov    %esi,0x4(%esp)
f01011e4:	8b 45 08             	mov    0x8(%ebp),%eax
f01011e7:	89 04 24             	mov    %eax,(%esp)
f01011ea:	e8 ad fd ff ff       	call   f0100f9c <pgdir_walk>
        if(pte==NULL)  
f01011ef:	85 c0                	test   %eax,%eax
f01011f1:	74 24                	je     f0101217 <page_insert+0xb4>
        {  
            return -E_NO_MEM;  
        }  
        pte[0]=page2pa(pp)|perm|PTE_P;  
f01011f3:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01011f6:	83 c9 01             	or     $0x1,%ecx
f01011f9:	89 da                	mov    %ebx,%edx
f01011fb:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0101201:	c1 fa 03             	sar    $0x3,%edx
f0101204:	c1 e2 0c             	shl    $0xc,%edx
f0101207:	09 ca                	or     %ecx,%edx
f0101209:	89 10                	mov    %edx,(%eax)
        pp->pp_ref++;  
f010120b:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)
        return 0;  
f0101210:	b8 00 00 00 00       	mov    $0x0,%eax
f0101215:	eb 05                	jmp    f010121c <page_insert+0xb9>
            page_remove(pgdir,va);  
        }  
        pte=pgdir_walk(pgdir,va,1);  
        if(pte==NULL)  
        {  
            return -E_NO_MEM;  
f0101217:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
        }  
        pte[0]=page2pa(pp)|perm|PTE_P;  
        pp->pp_ref++;  
        return 0;  
    }  
f010121c:	83 c4 1c             	add    $0x1c,%esp
f010121f:	5b                   	pop    %ebx
f0101220:	5e                   	pop    %esi
f0101221:	5f                   	pop    %edi
f0101222:	5d                   	pop    %ebp
f0101223:	c3                   	ret    

f0101224 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0101224:	55                   	push   %ebp
f0101225:	89 e5                	mov    %esp,%ebp
f0101227:	57                   	push   %edi
f0101228:	56                   	push   %esi
f0101229:	53                   	push   %ebx
f010122a:	83 ec 3c             	sub    $0x3c,%esp
	uint32_t cr0;
	size_t n;
	int i;
	cprintf("mem_init() succeeded!\n");
f010122d:	c7 04 24 72 57 10 f0 	movl   $0xf0105772,(%esp)
f0101234:	e8 9b 22 00 00       	call   f01034d4 <cprintf>
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101239:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f0101240:	e8 1f 22 00 00       	call   f0103464 <mc146818_read>
f0101245:	89 c3                	mov    %eax,%ebx
f0101247:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010124e:	e8 11 22 00 00       	call   f0103464 <mc146818_read>
f0101253:	c1 e0 08             	shl    $0x8,%eax
f0101256:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f0101258:	89 d8                	mov    %ebx,%eax
f010125a:	c1 e0 0a             	shl    $0xa,%eax
f010125d:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101263:	85 c0                	test   %eax,%eax
f0101265:	0f 48 c2             	cmovs  %edx,%eax
f0101268:	c1 f8 0c             	sar    $0xc,%eax
f010126b:	a3 c4 c1 17 f0       	mov    %eax,0xf017c1c4
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101270:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f0101277:	e8 e8 21 00 00       	call   f0103464 <mc146818_read>
f010127c:	89 c3                	mov    %eax,%ebx
f010127e:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f0101285:	e8 da 21 00 00       	call   f0103464 <mc146818_read>
f010128a:	c1 e0 08             	shl    $0x8,%eax
f010128d:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f010128f:	89 d8                	mov    %ebx,%eax
f0101291:	c1 e0 0a             	shl    $0xa,%eax
f0101294:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010129a:	85 c0                	test   %eax,%eax
f010129c:	0f 48 c2             	cmovs  %edx,%eax
f010129f:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f01012a2:	85 c0                	test   %eax,%eax
f01012a4:	74 0e                	je     f01012b4 <mem_init+0x90>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f01012a6:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f01012ac:	89 15 84 ce 17 f0    	mov    %edx,0xf017ce84
f01012b2:	eb 0c                	jmp    f01012c0 <mem_init+0x9c>
	else
		npages = npages_basemem;
f01012b4:	8b 15 c4 c1 17 f0    	mov    0xf017c1c4,%edx
f01012ba:	89 15 84 ce 17 f0    	mov    %edx,0xf017ce84

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f01012c0:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01012c3:	c1 e8 0a             	shr    $0xa,%eax
f01012c6:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f01012ca:	a1 c4 c1 17 f0       	mov    0xf017c1c4,%eax
f01012cf:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01012d2:	c1 e8 0a             	shr    $0xa,%eax
f01012d5:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f01012d9:	a1 84 ce 17 f0       	mov    0xf017ce84,%eax
f01012de:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f01012e1:	c1 e8 0a             	shr    $0xa,%eax
f01012e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012e8:	c7 04 24 94 50 10 f0 	movl   $0xf0105094,(%esp)
f01012ef:	e8 e0 21 00 00       	call   f01034d4 <cprintf>

	// Remove this line when you're ready to test this function

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f01012f4:	b8 00 10 00 00       	mov    $0x1000,%eax
f01012f9:	e8 62 f6 ff ff       	call   f0100960 <boot_alloc>
f01012fe:	a3 88 ce 17 f0       	mov    %eax,0xf017ce88
	memset(kern_pgdir, 0, PGSIZE);
f0101303:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010130a:	00 
f010130b:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101312:	00 
f0101313:	89 04 24             	mov    %eax,(%esp)
f0101316:	e8 5e 32 00 00       	call   f0104579 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f010131b:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101320:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101325:	77 20                	ja     f0101347 <mem_init+0x123>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101327:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010132b:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f0101332:	f0 
f0101333:	c7 44 24 04 8c 00 00 	movl   $0x8c,0x4(%esp)
f010133a:	00 
f010133b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101342:	e8 9a ed ff ff       	call   f01000e1 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0101347:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f010134d:	83 ca 05             	or     $0x5,%edx
f0101350:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate an array of npages 'struct Page's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:
	pages=(struct Page*)boot_alloc(npages*sizeof(struct Page));  
f0101356:	a1 84 ce 17 f0       	mov    0xf017ce84,%eax
f010135b:	c1 e0 03             	shl    $0x3,%eax
f010135e:	e8 fd f5 ff ff       	call   f0100960 <boot_alloc>
f0101363:	a3 8c ce 17 f0       	mov    %eax,0xf017ce8c
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101368:	e8 17 fa ff ff       	call   f0100d84 <page_init>
	cprintf("mem_init() succeeded!\n");
f010136d:	c7 04 24 72 57 10 f0 	movl   $0xf0105772,(%esp)
f0101374:	e8 5b 21 00 00       	call   f01034d4 <cprintf>
	check_page_free_list(1);
f0101379:	b8 01 00 00 00       	mov    $0x1,%eax
f010137e:	e8 84 f6 ff ff       	call   f0100a07 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f0101383:	83 3d 8c ce 17 f0 00 	cmpl   $0x0,0xf017ce8c
f010138a:	75 1c                	jne    f01013a8 <mem_init+0x184>
		panic("'pages' is a null pointer!");
f010138c:	c7 44 24 08 89 57 10 	movl   $0xf0105789,0x8(%esp)
f0101393:	f0 
f0101394:	c7 44 24 04 df 02 00 	movl   $0x2df,0x4(%esp)
f010139b:	00 
f010139c:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01013a3:	e8 39 ed ff ff       	call   f01000e1 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f01013a8:	a1 c0 c1 17 f0       	mov    0xf017c1c0,%eax
f01013ad:	85 c0                	test   %eax,%eax
f01013af:	74 10                	je     f01013c1 <mem_init+0x19d>
f01013b1:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f01013b6:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f01013b9:	8b 00                	mov    (%eax),%eax
f01013bb:	85 c0                	test   %eax,%eax
f01013bd:	75 f7                	jne    f01013b6 <mem_init+0x192>
f01013bf:	eb 05                	jmp    f01013c6 <mem_init+0x1a2>
f01013c1:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01013c6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01013cd:	e8 da fa ff ff       	call   f0100eac <page_alloc>
f01013d2:	89 c7                	mov    %eax,%edi
f01013d4:	85 c0                	test   %eax,%eax
f01013d6:	75 24                	jne    f01013fc <mem_init+0x1d8>
f01013d8:	c7 44 24 0c a4 57 10 	movl   $0xf01057a4,0xc(%esp)
f01013df:	f0 
f01013e0:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01013e7:	f0 
f01013e8:	c7 44 24 04 e7 02 00 	movl   $0x2e7,0x4(%esp)
f01013ef:	00 
f01013f0:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01013f7:	e8 e5 ec ff ff       	call   f01000e1 <_panic>
	assert((pp1 = page_alloc(0)));
f01013fc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101403:	e8 a4 fa ff ff       	call   f0100eac <page_alloc>
f0101408:	89 c6                	mov    %eax,%esi
f010140a:	85 c0                	test   %eax,%eax
f010140c:	75 24                	jne    f0101432 <mem_init+0x20e>
f010140e:	c7 44 24 0c ba 57 10 	movl   $0xf01057ba,0xc(%esp)
f0101415:	f0 
f0101416:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010141d:	f0 
f010141e:	c7 44 24 04 e8 02 00 	movl   $0x2e8,0x4(%esp)
f0101425:	00 
f0101426:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010142d:	e8 af ec ff ff       	call   f01000e1 <_panic>
	assert((pp2 = page_alloc(0)));
f0101432:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101439:	e8 6e fa ff ff       	call   f0100eac <page_alloc>
f010143e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101441:	85 c0                	test   %eax,%eax
f0101443:	75 24                	jne    f0101469 <mem_init+0x245>
f0101445:	c7 44 24 0c d0 57 10 	movl   $0xf01057d0,0xc(%esp)
f010144c:	f0 
f010144d:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101454:	f0 
f0101455:	c7 44 24 04 e9 02 00 	movl   $0x2e9,0x4(%esp)
f010145c:	00 
f010145d:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101464:	e8 78 ec ff ff       	call   f01000e1 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101469:	39 f7                	cmp    %esi,%edi
f010146b:	75 24                	jne    f0101491 <mem_init+0x26d>
f010146d:	c7 44 24 0c e6 57 10 	movl   $0xf01057e6,0xc(%esp)
f0101474:	f0 
f0101475:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010147c:	f0 
f010147d:	c7 44 24 04 ec 02 00 	movl   $0x2ec,0x4(%esp)
f0101484:	00 
f0101485:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010148c:	e8 50 ec ff ff       	call   f01000e1 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101491:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101494:	39 c6                	cmp    %eax,%esi
f0101496:	74 04                	je     f010149c <mem_init+0x278>
f0101498:	39 c7                	cmp    %eax,%edi
f010149a:	75 24                	jne    f01014c0 <mem_init+0x29c>
f010149c:	c7 44 24 0c f4 50 10 	movl   $0xf01050f4,0xc(%esp)
f01014a3:	f0 
f01014a4:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01014ab:	f0 
f01014ac:	c7 44 24 04 ed 02 00 	movl   $0x2ed,0x4(%esp)
f01014b3:	00 
f01014b4:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01014bb:	e8 21 ec ff ff       	call   f01000e1 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01014c0:	8b 15 8c ce 17 f0    	mov    0xf017ce8c,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f01014c6:	a1 84 ce 17 f0       	mov    0xf017ce84,%eax
f01014cb:	c1 e0 0c             	shl    $0xc,%eax
f01014ce:	89 f9                	mov    %edi,%ecx
f01014d0:	29 d1                	sub    %edx,%ecx
f01014d2:	c1 f9 03             	sar    $0x3,%ecx
f01014d5:	c1 e1 0c             	shl    $0xc,%ecx
f01014d8:	39 c1                	cmp    %eax,%ecx
f01014da:	72 24                	jb     f0101500 <mem_init+0x2dc>
f01014dc:	c7 44 24 0c f8 57 10 	movl   $0xf01057f8,0xc(%esp)
f01014e3:	f0 
f01014e4:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01014eb:	f0 
f01014ec:	c7 44 24 04 ee 02 00 	movl   $0x2ee,0x4(%esp)
f01014f3:	00 
f01014f4:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01014fb:	e8 e1 eb ff ff       	call   f01000e1 <_panic>
f0101500:	89 f1                	mov    %esi,%ecx
f0101502:	29 d1                	sub    %edx,%ecx
f0101504:	c1 f9 03             	sar    $0x3,%ecx
f0101507:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f010150a:	39 c8                	cmp    %ecx,%eax
f010150c:	77 24                	ja     f0101532 <mem_init+0x30e>
f010150e:	c7 44 24 0c 15 58 10 	movl   $0xf0105815,0xc(%esp)
f0101515:	f0 
f0101516:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010151d:	f0 
f010151e:	c7 44 24 04 ef 02 00 	movl   $0x2ef,0x4(%esp)
f0101525:	00 
f0101526:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010152d:	e8 af eb ff ff       	call   f01000e1 <_panic>
f0101532:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0101535:	29 d1                	sub    %edx,%ecx
f0101537:	89 ca                	mov    %ecx,%edx
f0101539:	c1 fa 03             	sar    $0x3,%edx
f010153c:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f010153f:	39 d0                	cmp    %edx,%eax
f0101541:	77 24                	ja     f0101567 <mem_init+0x343>
f0101543:	c7 44 24 0c 32 58 10 	movl   $0xf0105832,0xc(%esp)
f010154a:	f0 
f010154b:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101552:	f0 
f0101553:	c7 44 24 04 f0 02 00 	movl   $0x2f0,0x4(%esp)
f010155a:	00 
f010155b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101562:	e8 7a eb ff ff       	call   f01000e1 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101567:	a1 c0 c1 17 f0       	mov    0xf017c1c0,%eax
f010156c:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f010156f:	c7 05 c0 c1 17 f0 00 	movl   $0x0,0xf017c1c0
f0101576:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101579:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101580:	e8 27 f9 ff ff       	call   f0100eac <page_alloc>
f0101585:	85 c0                	test   %eax,%eax
f0101587:	74 24                	je     f01015ad <mem_init+0x389>
f0101589:	c7 44 24 0c 4f 58 10 	movl   $0xf010584f,0xc(%esp)
f0101590:	f0 
f0101591:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101598:	f0 
f0101599:	c7 44 24 04 f7 02 00 	movl   $0x2f7,0x4(%esp)
f01015a0:	00 
f01015a1:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01015a8:	e8 34 eb ff ff       	call   f01000e1 <_panic>

	// free and re-allocate?
	page_free(pp0);
f01015ad:	89 3c 24             	mov    %edi,(%esp)
f01015b0:	e8 7c f9 ff ff       	call   f0100f31 <page_free>
	page_free(pp1);
f01015b5:	89 34 24             	mov    %esi,(%esp)
f01015b8:	e8 74 f9 ff ff       	call   f0100f31 <page_free>
	page_free(pp2);
f01015bd:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01015c0:	89 04 24             	mov    %eax,(%esp)
f01015c3:	e8 69 f9 ff ff       	call   f0100f31 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01015c8:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01015cf:	e8 d8 f8 ff ff       	call   f0100eac <page_alloc>
f01015d4:	89 c6                	mov    %eax,%esi
f01015d6:	85 c0                	test   %eax,%eax
f01015d8:	75 24                	jne    f01015fe <mem_init+0x3da>
f01015da:	c7 44 24 0c a4 57 10 	movl   $0xf01057a4,0xc(%esp)
f01015e1:	f0 
f01015e2:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01015e9:	f0 
f01015ea:	c7 44 24 04 fe 02 00 	movl   $0x2fe,0x4(%esp)
f01015f1:	00 
f01015f2:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01015f9:	e8 e3 ea ff ff       	call   f01000e1 <_panic>
	assert((pp1 = page_alloc(0)));
f01015fe:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101605:	e8 a2 f8 ff ff       	call   f0100eac <page_alloc>
f010160a:	89 c7                	mov    %eax,%edi
f010160c:	85 c0                	test   %eax,%eax
f010160e:	75 24                	jne    f0101634 <mem_init+0x410>
f0101610:	c7 44 24 0c ba 57 10 	movl   $0xf01057ba,0xc(%esp)
f0101617:	f0 
f0101618:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010161f:	f0 
f0101620:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0101627:	00 
f0101628:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010162f:	e8 ad ea ff ff       	call   f01000e1 <_panic>
	assert((pp2 = page_alloc(0)));
f0101634:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010163b:	e8 6c f8 ff ff       	call   f0100eac <page_alloc>
f0101640:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101643:	85 c0                	test   %eax,%eax
f0101645:	75 24                	jne    f010166b <mem_init+0x447>
f0101647:	c7 44 24 0c d0 57 10 	movl   $0xf01057d0,0xc(%esp)
f010164e:	f0 
f010164f:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101656:	f0 
f0101657:	c7 44 24 04 00 03 00 	movl   $0x300,0x4(%esp)
f010165e:	00 
f010165f:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101666:	e8 76 ea ff ff       	call   f01000e1 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010166b:	39 fe                	cmp    %edi,%esi
f010166d:	75 24                	jne    f0101693 <mem_init+0x46f>
f010166f:	c7 44 24 0c e6 57 10 	movl   $0xf01057e6,0xc(%esp)
f0101676:	f0 
f0101677:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010167e:	f0 
f010167f:	c7 44 24 04 02 03 00 	movl   $0x302,0x4(%esp)
f0101686:	00 
f0101687:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010168e:	e8 4e ea ff ff       	call   f01000e1 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101693:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101696:	39 c7                	cmp    %eax,%edi
f0101698:	74 04                	je     f010169e <mem_init+0x47a>
f010169a:	39 c6                	cmp    %eax,%esi
f010169c:	75 24                	jne    f01016c2 <mem_init+0x49e>
f010169e:	c7 44 24 0c f4 50 10 	movl   $0xf01050f4,0xc(%esp)
f01016a5:	f0 
f01016a6:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01016ad:	f0 
f01016ae:	c7 44 24 04 03 03 00 	movl   $0x303,0x4(%esp)
f01016b5:	00 
f01016b6:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01016bd:	e8 1f ea ff ff       	call   f01000e1 <_panic>
	assert(!page_alloc(0));
f01016c2:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016c9:	e8 de f7 ff ff       	call   f0100eac <page_alloc>
f01016ce:	85 c0                	test   %eax,%eax
f01016d0:	74 24                	je     f01016f6 <mem_init+0x4d2>
f01016d2:	c7 44 24 0c 4f 58 10 	movl   $0xf010584f,0xc(%esp)
f01016d9:	f0 
f01016da:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01016e1:	f0 
f01016e2:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
f01016e9:	00 
f01016ea:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01016f1:	e8 eb e9 ff ff       	call   f01000e1 <_panic>
f01016f6:	89 f0                	mov    %esi,%eax
f01016f8:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f01016fe:	c1 f8 03             	sar    $0x3,%eax
f0101701:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101704:	89 c2                	mov    %eax,%edx
f0101706:	c1 ea 0c             	shr    $0xc,%edx
f0101709:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f010170f:	72 20                	jb     f0101731 <mem_init+0x50d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101711:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101715:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f010171c:	f0 
f010171d:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101724:	00 
f0101725:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f010172c:	e8 b0 e9 ff ff       	call   f01000e1 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f0101731:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101738:	00 
f0101739:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0101740:	00 
	return (void *)(pa + KERNBASE);
f0101741:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101746:	89 04 24             	mov    %eax,(%esp)
f0101749:	e8 2b 2e 00 00       	call   f0104579 <memset>
	page_free(pp0);
f010174e:	89 34 24             	mov    %esi,(%esp)
f0101751:	e8 db f7 ff ff       	call   f0100f31 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101756:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010175d:	e8 4a f7 ff ff       	call   f0100eac <page_alloc>
f0101762:	85 c0                	test   %eax,%eax
f0101764:	75 24                	jne    f010178a <mem_init+0x566>
f0101766:	c7 44 24 0c 5e 58 10 	movl   $0xf010585e,0xc(%esp)
f010176d:	f0 
f010176e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101775:	f0 
f0101776:	c7 44 24 04 09 03 00 	movl   $0x309,0x4(%esp)
f010177d:	00 
f010177e:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101785:	e8 57 e9 ff ff       	call   f01000e1 <_panic>
	assert(pp && pp0 == pp);
f010178a:	39 c6                	cmp    %eax,%esi
f010178c:	74 24                	je     f01017b2 <mem_init+0x58e>
f010178e:	c7 44 24 0c 7c 58 10 	movl   $0xf010587c,0xc(%esp)
f0101795:	f0 
f0101796:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010179d:	f0 
f010179e:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f01017a5:	00 
f01017a6:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01017ad:	e8 2f e9 ff ff       	call   f01000e1 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01017b2:	89 f2                	mov    %esi,%edx
f01017b4:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f01017ba:	c1 fa 03             	sar    $0x3,%edx
f01017bd:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01017c0:	89 d0                	mov    %edx,%eax
f01017c2:	c1 e8 0c             	shr    $0xc,%eax
f01017c5:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f01017cb:	72 20                	jb     f01017ed <mem_init+0x5c9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01017cd:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01017d1:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f01017d8:	f0 
f01017d9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01017e0:	00 
f01017e1:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f01017e8:	e8 f4 e8 ff ff       	call   f01000e1 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f01017ed:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f01017f4:	75 11                	jne    f0101807 <mem_init+0x5e3>
f01017f6:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f01017fc:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101802:	80 38 00             	cmpb   $0x0,(%eax)
f0101805:	74 24                	je     f010182b <mem_init+0x607>
f0101807:	c7 44 24 0c 8c 58 10 	movl   $0xf010588c,0xc(%esp)
f010180e:	f0 
f010180f:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101816:	f0 
f0101817:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f010181e:	00 
f010181f:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101826:	e8 b6 e8 ff ff       	call   f01000e1 <_panic>
f010182b:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f010182e:	39 d0                	cmp    %edx,%eax
f0101830:	75 d0                	jne    f0101802 <mem_init+0x5de>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101832:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101835:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0

	// free the pages we took
	page_free(pp0);
f010183a:	89 34 24             	mov    %esi,(%esp)
f010183d:	e8 ef f6 ff ff       	call   f0100f31 <page_free>
	page_free(pp1);
f0101842:	89 3c 24             	mov    %edi,(%esp)
f0101845:	e8 e7 f6 ff ff       	call   f0100f31 <page_free>
	page_free(pp2);
f010184a:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010184d:	89 04 24             	mov    %eax,(%esp)
f0101850:	e8 dc f6 ff ff       	call   f0100f31 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101855:	a1 c0 c1 17 f0       	mov    0xf017c1c0,%eax
f010185a:	85 c0                	test   %eax,%eax
f010185c:	74 09                	je     f0101867 <mem_init+0x643>
		--nfree;
f010185e:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101861:	8b 00                	mov    (%eax),%eax
f0101863:	85 c0                	test   %eax,%eax
f0101865:	75 f7                	jne    f010185e <mem_init+0x63a>
		--nfree;
	assert(nfree == 0);
f0101867:	85 db                	test   %ebx,%ebx
f0101869:	74 24                	je     f010188f <mem_init+0x66b>
f010186b:	c7 44 24 0c 96 58 10 	movl   $0xf0105896,0xc(%esp)
f0101872:	f0 
f0101873:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010187a:	f0 
f010187b:	c7 44 24 04 1a 03 00 	movl   $0x31a,0x4(%esp)
f0101882:	00 
f0101883:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010188a:	e8 52 e8 ff ff       	call   f01000e1 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f010188f:	c7 04 24 14 51 10 f0 	movl   $0xf0105114,(%esp)
f0101896:	e8 39 1c 00 00       	call   f01034d4 <cprintf>
	void *va;
	int i;
	extern pde_t entry_pgdir[];
	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f010189b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018a2:	e8 05 f6 ff ff       	call   f0100eac <page_alloc>
f01018a7:	89 c3                	mov    %eax,%ebx
f01018a9:	85 c0                	test   %eax,%eax
f01018ab:	75 24                	jne    f01018d1 <mem_init+0x6ad>
f01018ad:	c7 44 24 0c a4 57 10 	movl   $0xf01057a4,0xc(%esp)
f01018b4:	f0 
f01018b5:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01018bc:	f0 
f01018bd:	c7 44 24 04 77 03 00 	movl   $0x377,0x4(%esp)
f01018c4:	00 
f01018c5:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01018cc:	e8 10 e8 ff ff       	call   f01000e1 <_panic>
	assert((pp1 = page_alloc(0)));
f01018d1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018d8:	e8 cf f5 ff ff       	call   f0100eac <page_alloc>
f01018dd:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018e0:	85 c0                	test   %eax,%eax
f01018e2:	75 24                	jne    f0101908 <mem_init+0x6e4>
f01018e4:	c7 44 24 0c ba 57 10 	movl   $0xf01057ba,0xc(%esp)
f01018eb:	f0 
f01018ec:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01018f3:	f0 
f01018f4:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f01018fb:	00 
f01018fc:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101903:	e8 d9 e7 ff ff       	call   f01000e1 <_panic>
	assert((pp2 = page_alloc(0)));
f0101908:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010190f:	e8 98 f5 ff ff       	call   f0100eac <page_alloc>
f0101914:	89 c6                	mov    %eax,%esi
f0101916:	85 c0                	test   %eax,%eax
f0101918:	75 24                	jne    f010193e <mem_init+0x71a>
f010191a:	c7 44 24 0c d0 57 10 	movl   $0xf01057d0,0xc(%esp)
f0101921:	f0 
f0101922:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101929:	f0 
f010192a:	c7 44 24 04 79 03 00 	movl   $0x379,0x4(%esp)
f0101931:	00 
f0101932:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101939:	e8 a3 e7 ff ff       	call   f01000e1 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f010193e:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101941:	75 24                	jne    f0101967 <mem_init+0x743>
f0101943:	c7 44 24 0c e6 57 10 	movl   $0xf01057e6,0xc(%esp)
f010194a:	f0 
f010194b:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101952:	f0 
f0101953:	c7 44 24 04 7c 03 00 	movl   $0x37c,0x4(%esp)
f010195a:	00 
f010195b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101962:	e8 7a e7 ff ff       	call   f01000e1 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101967:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f010196a:	74 04                	je     f0101970 <mem_init+0x74c>
f010196c:	39 c3                	cmp    %eax,%ebx
f010196e:	75 24                	jne    f0101994 <mem_init+0x770>
f0101970:	c7 44 24 0c f4 50 10 	movl   $0xf01050f4,0xc(%esp)
f0101977:	f0 
f0101978:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010197f:	f0 
f0101980:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0101987:	00 
f0101988:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010198f:	e8 4d e7 ff ff       	call   f01000e1 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101994:	a1 c0 c1 17 f0       	mov    0xf017c1c0,%eax
f0101999:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f010199c:	c7 05 c0 c1 17 f0 00 	movl   $0x0,0xf017c1c0
f01019a3:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f01019a6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01019ad:	e8 fa f4 ff ff       	call   f0100eac <page_alloc>
f01019b2:	85 c0                	test   %eax,%eax
f01019b4:	74 24                	je     f01019da <mem_init+0x7b6>
f01019b6:	c7 44 24 0c 4f 58 10 	movl   $0xf010584f,0xc(%esp)
f01019bd:	f0 
f01019be:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01019c5:	f0 
f01019c6:	c7 44 24 04 84 03 00 	movl   $0x384,0x4(%esp)
f01019cd:	00 
f01019ce:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01019d5:	e8 07 e7 ff ff       	call   f01000e1 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f01019da:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01019dd:	89 44 24 08          	mov    %eax,0x8(%esp)
f01019e1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01019e8:	00 
f01019e9:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f01019ee:	89 04 24             	mov    %eax,(%esp)
f01019f1:	e8 b0 f6 ff ff       	call   f01010a6 <page_lookup>
f01019f6:	85 c0                	test   %eax,%eax
f01019f8:	74 24                	je     f0101a1e <mem_init+0x7fa>
f01019fa:	c7 44 24 0c 34 51 10 	movl   $0xf0105134,0xc(%esp)
f0101a01:	f0 
f0101a02:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101a09:	f0 
f0101a0a:	c7 44 24 04 87 03 00 	movl   $0x387,0x4(%esp)
f0101a11:	00 
f0101a12:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101a19:	e8 c3 e6 ff ff       	call   f01000e1 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101a1e:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101a25:	00 
f0101a26:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101a2d:	00 
f0101a2e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101a31:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101a35:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101a3a:	89 04 24             	mov    %eax,(%esp)
f0101a3d:	e8 21 f7 ff ff       	call   f0101163 <page_insert>
f0101a42:	85 c0                	test   %eax,%eax
f0101a44:	78 24                	js     f0101a6a <mem_init+0x846>
f0101a46:	c7 44 24 0c 6c 51 10 	movl   $0xf010516c,0xc(%esp)
f0101a4d:	f0 
f0101a4e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101a55:	f0 
f0101a56:	c7 44 24 04 8a 03 00 	movl   $0x38a,0x4(%esp)
f0101a5d:	00 
f0101a5e:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101a65:	e8 77 e6 ff ff       	call   f01000e1 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101a6a:	89 1c 24             	mov    %ebx,(%esp)
f0101a6d:	e8 bf f4 ff ff       	call   f0100f31 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101a72:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101a79:	00 
f0101a7a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101a81:	00 
f0101a82:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101a85:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101a89:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101a8e:	89 04 24             	mov    %eax,(%esp)
f0101a91:	e8 cd f6 ff ff       	call   f0101163 <page_insert>
f0101a96:	85 c0                	test   %eax,%eax
f0101a98:	74 24                	je     f0101abe <mem_init+0x89a>
f0101a9a:	c7 44 24 0c 9c 51 10 	movl   $0xf010519c,0xc(%esp)
f0101aa1:	f0 
f0101aa2:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101aa9:	f0 
f0101aaa:	c7 44 24 04 8e 03 00 	movl   $0x38e,0x4(%esp)
f0101ab1:	00 
f0101ab2:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101ab9:	e8 23 e6 ff ff       	call   f01000e1 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101abe:	8b 3d 88 ce 17 f0    	mov    0xf017ce88,%edi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101ac4:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
f0101ac9:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101acc:	8b 17                	mov    (%edi),%edx
f0101ace:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101ad4:	89 d9                	mov    %ebx,%ecx
f0101ad6:	29 c1                	sub    %eax,%ecx
f0101ad8:	89 c8                	mov    %ecx,%eax
f0101ada:	c1 f8 03             	sar    $0x3,%eax
f0101add:	c1 e0 0c             	shl    $0xc,%eax
f0101ae0:	39 c2                	cmp    %eax,%edx
f0101ae2:	74 24                	je     f0101b08 <mem_init+0x8e4>
f0101ae4:	c7 44 24 0c cc 51 10 	movl   $0xf01051cc,0xc(%esp)
f0101aeb:	f0 
f0101aec:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101af3:	f0 
f0101af4:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f0101afb:	00 
f0101afc:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101b03:	e8 d9 e5 ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101b08:	ba 00 00 00 00       	mov    $0x0,%edx
f0101b0d:	89 f8                	mov    %edi,%eax
f0101b0f:	e8 84 ee ff ff       	call   f0100998 <check_va2pa>
f0101b14:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101b17:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101b1a:	c1 fa 03             	sar    $0x3,%edx
f0101b1d:	c1 e2 0c             	shl    $0xc,%edx
f0101b20:	39 d0                	cmp    %edx,%eax
f0101b22:	74 24                	je     f0101b48 <mem_init+0x924>
f0101b24:	c7 44 24 0c f4 51 10 	movl   $0xf01051f4,0xc(%esp)
f0101b2b:	f0 
f0101b2c:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101b33:	f0 
f0101b34:	c7 44 24 04 90 03 00 	movl   $0x390,0x4(%esp)
f0101b3b:	00 
f0101b3c:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101b43:	e8 99 e5 ff ff       	call   f01000e1 <_panic>
	assert(pp1->pp_ref == 1);
f0101b48:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b4b:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101b50:	74 24                	je     f0101b76 <mem_init+0x952>
f0101b52:	c7 44 24 0c a1 58 10 	movl   $0xf01058a1,0xc(%esp)
f0101b59:	f0 
f0101b5a:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101b61:	f0 
f0101b62:	c7 44 24 04 91 03 00 	movl   $0x391,0x4(%esp)
f0101b69:	00 
f0101b6a:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101b71:	e8 6b e5 ff ff       	call   f01000e1 <_panic>
	assert(pp0->pp_ref == 1);
f0101b76:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101b7b:	74 24                	je     f0101ba1 <mem_init+0x97d>
f0101b7d:	c7 44 24 0c b2 58 10 	movl   $0xf01058b2,0xc(%esp)
f0101b84:	f0 
f0101b85:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101b8c:	f0 
f0101b8d:	c7 44 24 04 92 03 00 	movl   $0x392,0x4(%esp)
f0101b94:	00 
f0101b95:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101b9c:	e8 40 e5 ff ff       	call   f01000e1 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101ba1:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101ba8:	00 
f0101ba9:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101bb0:	00 
f0101bb1:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101bb5:	89 3c 24             	mov    %edi,(%esp)
f0101bb8:	e8 a6 f5 ff ff       	call   f0101163 <page_insert>
f0101bbd:	85 c0                	test   %eax,%eax
f0101bbf:	74 24                	je     f0101be5 <mem_init+0x9c1>
f0101bc1:	c7 44 24 0c 24 52 10 	movl   $0xf0105224,0xc(%esp)
f0101bc8:	f0 
f0101bc9:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101bd0:	f0 
f0101bd1:	c7 44 24 04 95 03 00 	movl   $0x395,0x4(%esp)
f0101bd8:	00 
f0101bd9:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101be0:	e8 fc e4 ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101be5:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101bea:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101bef:	e8 a4 ed ff ff       	call   f0100998 <check_va2pa>
f0101bf4:	89 f2                	mov    %esi,%edx
f0101bf6:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0101bfc:	c1 fa 03             	sar    $0x3,%edx
f0101bff:	c1 e2 0c             	shl    $0xc,%edx
f0101c02:	39 d0                	cmp    %edx,%eax
f0101c04:	74 24                	je     f0101c2a <mem_init+0xa06>
f0101c06:	c7 44 24 0c 60 52 10 	movl   $0xf0105260,0xc(%esp)
f0101c0d:	f0 
f0101c0e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101c15:	f0 
f0101c16:	c7 44 24 04 96 03 00 	movl   $0x396,0x4(%esp)
f0101c1d:	00 
f0101c1e:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101c25:	e8 b7 e4 ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 1);
f0101c2a:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101c2f:	74 24                	je     f0101c55 <mem_init+0xa31>
f0101c31:	c7 44 24 0c c3 58 10 	movl   $0xf01058c3,0xc(%esp)
f0101c38:	f0 
f0101c39:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101c40:	f0 
f0101c41:	c7 44 24 04 97 03 00 	movl   $0x397,0x4(%esp)
f0101c48:	00 
f0101c49:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101c50:	e8 8c e4 ff ff       	call   f01000e1 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101c55:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c5c:	e8 4b f2 ff ff       	call   f0100eac <page_alloc>
f0101c61:	85 c0                	test   %eax,%eax
f0101c63:	74 24                	je     f0101c89 <mem_init+0xa65>
f0101c65:	c7 44 24 0c 4f 58 10 	movl   $0xf010584f,0xc(%esp)
f0101c6c:	f0 
f0101c6d:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101c74:	f0 
f0101c75:	c7 44 24 04 9a 03 00 	movl   $0x39a,0x4(%esp)
f0101c7c:	00 
f0101c7d:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101c84:	e8 58 e4 ff ff       	call   f01000e1 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101c89:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101c90:	00 
f0101c91:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101c98:	00 
f0101c99:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101c9d:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101ca2:	89 04 24             	mov    %eax,(%esp)
f0101ca5:	e8 b9 f4 ff ff       	call   f0101163 <page_insert>
f0101caa:	85 c0                	test   %eax,%eax
f0101cac:	74 24                	je     f0101cd2 <mem_init+0xaae>
f0101cae:	c7 44 24 0c 24 52 10 	movl   $0xf0105224,0xc(%esp)
f0101cb5:	f0 
f0101cb6:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101cbd:	f0 
f0101cbe:	c7 44 24 04 9d 03 00 	movl   $0x39d,0x4(%esp)
f0101cc5:	00 
f0101cc6:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101ccd:	e8 0f e4 ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101cd2:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101cd7:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101cdc:	e8 b7 ec ff ff       	call   f0100998 <check_va2pa>
f0101ce1:	89 f2                	mov    %esi,%edx
f0101ce3:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0101ce9:	c1 fa 03             	sar    $0x3,%edx
f0101cec:	c1 e2 0c             	shl    $0xc,%edx
f0101cef:	39 d0                	cmp    %edx,%eax
f0101cf1:	74 24                	je     f0101d17 <mem_init+0xaf3>
f0101cf3:	c7 44 24 0c 60 52 10 	movl   $0xf0105260,0xc(%esp)
f0101cfa:	f0 
f0101cfb:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101d02:	f0 
f0101d03:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f0101d0a:	00 
f0101d0b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101d12:	e8 ca e3 ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 1);
f0101d17:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101d1c:	74 24                	je     f0101d42 <mem_init+0xb1e>
f0101d1e:	c7 44 24 0c c3 58 10 	movl   $0xf01058c3,0xc(%esp)
f0101d25:	f0 
f0101d26:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101d2d:	f0 
f0101d2e:	c7 44 24 04 9f 03 00 	movl   $0x39f,0x4(%esp)
f0101d35:	00 
f0101d36:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101d3d:	e8 9f e3 ff ff       	call   f01000e1 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101d42:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101d49:	e8 5e f1 ff ff       	call   f0100eac <page_alloc>
f0101d4e:	85 c0                	test   %eax,%eax
f0101d50:	74 24                	je     f0101d76 <mem_init+0xb52>
f0101d52:	c7 44 24 0c 4f 58 10 	movl   $0xf010584f,0xc(%esp)
f0101d59:	f0 
f0101d5a:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101d61:	f0 
f0101d62:	c7 44 24 04 a3 03 00 	movl   $0x3a3,0x4(%esp)
f0101d69:	00 
f0101d6a:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101d71:	e8 6b e3 ff ff       	call   f01000e1 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0101d76:	8b 15 88 ce 17 f0    	mov    0xf017ce88,%edx
f0101d7c:	8b 02                	mov    (%edx),%eax
f0101d7e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101d83:	89 c1                	mov    %eax,%ecx
f0101d85:	c1 e9 0c             	shr    $0xc,%ecx
f0101d88:	3b 0d 84 ce 17 f0    	cmp    0xf017ce84,%ecx
f0101d8e:	72 20                	jb     f0101db0 <mem_init+0xb8c>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101d90:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101d94:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0101d9b:	f0 
f0101d9c:	c7 44 24 04 a6 03 00 	movl   $0x3a6,0x4(%esp)
f0101da3:	00 
f0101da4:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101dab:	e8 31 e3 ff ff       	call   f01000e1 <_panic>
	return (void *)(pa + KERNBASE);
f0101db0:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101db5:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0101db8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101dbf:	00 
f0101dc0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101dc7:	00 
f0101dc8:	89 14 24             	mov    %edx,(%esp)
f0101dcb:	e8 cc f1 ff ff       	call   f0100f9c <pgdir_walk>
f0101dd0:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0101dd3:	8d 57 04             	lea    0x4(%edi),%edx
f0101dd6:	39 d0                	cmp    %edx,%eax
f0101dd8:	74 24                	je     f0101dfe <mem_init+0xbda>
f0101dda:	c7 44 24 0c 90 52 10 	movl   $0xf0105290,0xc(%esp)
f0101de1:	f0 
f0101de2:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101de9:	f0 
f0101dea:	c7 44 24 04 a7 03 00 	movl   $0x3a7,0x4(%esp)
f0101df1:	00 
f0101df2:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101df9:	e8 e3 e2 ff ff       	call   f01000e1 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f0101dfe:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0101e05:	00 
f0101e06:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e0d:	00 
f0101e0e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e12:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101e17:	89 04 24             	mov    %eax,(%esp)
f0101e1a:	e8 44 f3 ff ff       	call   f0101163 <page_insert>
f0101e1f:	85 c0                	test   %eax,%eax
f0101e21:	74 24                	je     f0101e47 <mem_init+0xc23>
f0101e23:	c7 44 24 0c d0 52 10 	movl   $0xf01052d0,0xc(%esp)
f0101e2a:	f0 
f0101e2b:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101e32:	f0 
f0101e33:	c7 44 24 04 aa 03 00 	movl   $0x3aa,0x4(%esp)
f0101e3a:	00 
f0101e3b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101e42:	e8 9a e2 ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e47:	8b 3d 88 ce 17 f0    	mov    0xf017ce88,%edi
f0101e4d:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e52:	89 f8                	mov    %edi,%eax
f0101e54:	e8 3f eb ff ff       	call   f0100998 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101e59:	89 f2                	mov    %esi,%edx
f0101e5b:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0101e61:	c1 fa 03             	sar    $0x3,%edx
f0101e64:	c1 e2 0c             	shl    $0xc,%edx
f0101e67:	39 d0                	cmp    %edx,%eax
f0101e69:	74 24                	je     f0101e8f <mem_init+0xc6b>
f0101e6b:	c7 44 24 0c 60 52 10 	movl   $0xf0105260,0xc(%esp)
f0101e72:	f0 
f0101e73:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101e7a:	f0 
f0101e7b:	c7 44 24 04 ab 03 00 	movl   $0x3ab,0x4(%esp)
f0101e82:	00 
f0101e83:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101e8a:	e8 52 e2 ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 1);
f0101e8f:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101e94:	74 24                	je     f0101eba <mem_init+0xc96>
f0101e96:	c7 44 24 0c c3 58 10 	movl   $0xf01058c3,0xc(%esp)
f0101e9d:	f0 
f0101e9e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101ea5:	f0 
f0101ea6:	c7 44 24 04 ac 03 00 	movl   $0x3ac,0x4(%esp)
f0101ead:	00 
f0101eae:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101eb5:	e8 27 e2 ff ff       	call   f01000e1 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0101eba:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101ec1:	00 
f0101ec2:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101ec9:	00 
f0101eca:	89 3c 24             	mov    %edi,(%esp)
f0101ecd:	e8 ca f0 ff ff       	call   f0100f9c <pgdir_walk>
f0101ed2:	f6 00 04             	testb  $0x4,(%eax)
f0101ed5:	75 24                	jne    f0101efb <mem_init+0xcd7>
f0101ed7:	c7 44 24 0c 10 53 10 	movl   $0xf0105310,0xc(%esp)
f0101ede:	f0 
f0101edf:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101ee6:	f0 
f0101ee7:	c7 44 24 04 ad 03 00 	movl   $0x3ad,0x4(%esp)
f0101eee:	00 
f0101eef:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101ef6:	e8 e6 e1 ff ff       	call   f01000e1 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0101efb:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101f00:	f6 00 04             	testb  $0x4,(%eax)
f0101f03:	75 24                	jne    f0101f29 <mem_init+0xd05>
f0101f05:	c7 44 24 0c d4 58 10 	movl   $0xf01058d4,0xc(%esp)
f0101f0c:	f0 
f0101f0d:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101f14:	f0 
f0101f15:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f0101f1c:	00 
f0101f1d:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101f24:	e8 b8 e1 ff ff       	call   f01000e1 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f0101f29:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f30:	00 
f0101f31:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f0101f38:	00 
f0101f39:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101f3d:	89 04 24             	mov    %eax,(%esp)
f0101f40:	e8 1e f2 ff ff       	call   f0101163 <page_insert>
f0101f45:	85 c0                	test   %eax,%eax
f0101f47:	78 24                	js     f0101f6d <mem_init+0xd49>
f0101f49:	c7 44 24 0c 44 53 10 	movl   $0xf0105344,0xc(%esp)
f0101f50:	f0 
f0101f51:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101f58:	f0 
f0101f59:	c7 44 24 04 b1 03 00 	movl   $0x3b1,0x4(%esp)
f0101f60:	00 
f0101f61:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101f68:	e8 74 e1 ff ff       	call   f01000e1 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0101f6d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f74:	00 
f0101f75:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f7c:	00 
f0101f7d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101f80:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101f84:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101f89:	89 04 24             	mov    %eax,(%esp)
f0101f8c:	e8 d2 f1 ff ff       	call   f0101163 <page_insert>
f0101f91:	85 c0                	test   %eax,%eax
f0101f93:	74 24                	je     f0101fb9 <mem_init+0xd95>
f0101f95:	c7 44 24 0c 7c 53 10 	movl   $0xf010537c,0xc(%esp)
f0101f9c:	f0 
f0101f9d:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101fa4:	f0 
f0101fa5:	c7 44 24 04 b4 03 00 	movl   $0x3b4,0x4(%esp)
f0101fac:	00 
f0101fad:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101fb4:	e8 28 e1 ff ff       	call   f01000e1 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0101fb9:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101fc0:	00 
f0101fc1:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0101fc8:	00 
f0101fc9:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0101fce:	89 04 24             	mov    %eax,(%esp)
f0101fd1:	e8 c6 ef ff ff       	call   f0100f9c <pgdir_walk>
f0101fd6:	f6 00 04             	testb  $0x4,(%eax)
f0101fd9:	74 24                	je     f0101fff <mem_init+0xddb>
f0101fdb:	c7 44 24 0c b8 53 10 	movl   $0xf01053b8,0xc(%esp)
f0101fe2:	f0 
f0101fe3:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0101fea:	f0 
f0101feb:	c7 44 24 04 b5 03 00 	movl   $0x3b5,0x4(%esp)
f0101ff2:	00 
f0101ff3:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0101ffa:	e8 e2 e0 ff ff       	call   f01000e1 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f0101fff:	8b 3d 88 ce 17 f0    	mov    0xf017ce88,%edi
f0102005:	ba 00 00 00 00       	mov    $0x0,%edx
f010200a:	89 f8                	mov    %edi,%eax
f010200c:	e8 87 e9 ff ff       	call   f0100998 <check_va2pa>
f0102011:	89 c1                	mov    %eax,%ecx
f0102013:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0102016:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102019:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f010201f:	c1 f8 03             	sar    $0x3,%eax
f0102022:	c1 e0 0c             	shl    $0xc,%eax
f0102025:	39 c1                	cmp    %eax,%ecx
f0102027:	74 24                	je     f010204d <mem_init+0xe29>
f0102029:	c7 44 24 0c f0 53 10 	movl   $0xf01053f0,0xc(%esp)
f0102030:	f0 
f0102031:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102038:	f0 
f0102039:	c7 44 24 04 b8 03 00 	movl   $0x3b8,0x4(%esp)
f0102040:	00 
f0102041:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102048:	e8 94 e0 ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010204d:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102052:	89 f8                	mov    %edi,%eax
f0102054:	e8 3f e9 ff ff       	call   f0100998 <check_va2pa>
f0102059:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f010205c:	74 24                	je     f0102082 <mem_init+0xe5e>
f010205e:	c7 44 24 0c 1c 54 10 	movl   $0xf010541c,0xc(%esp)
f0102065:	f0 
f0102066:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010206d:	f0 
f010206e:	c7 44 24 04 b9 03 00 	movl   $0x3b9,0x4(%esp)
f0102075:	00 
f0102076:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010207d:	e8 5f e0 ff ff       	call   f01000e1 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102082:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102085:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010208a:	74 24                	je     f01020b0 <mem_init+0xe8c>
f010208c:	c7 44 24 0c ea 58 10 	movl   $0xf01058ea,0xc(%esp)
f0102093:	f0 
f0102094:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010209b:	f0 
f010209c:	c7 44 24 04 bb 03 00 	movl   $0x3bb,0x4(%esp)
f01020a3:	00 
f01020a4:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01020ab:	e8 31 e0 ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 0);
f01020b0:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01020b5:	74 24                	je     f01020db <mem_init+0xeb7>
f01020b7:	c7 44 24 0c fb 58 10 	movl   $0xf01058fb,0xc(%esp)
f01020be:	f0 
f01020bf:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01020c6:	f0 
f01020c7:	c7 44 24 04 bc 03 00 	movl   $0x3bc,0x4(%esp)
f01020ce:	00 
f01020cf:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01020d6:	e8 06 e0 ff ff       	call   f01000e1 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f01020db:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01020e2:	e8 c5 ed ff ff       	call   f0100eac <page_alloc>
f01020e7:	85 c0                	test   %eax,%eax
f01020e9:	74 04                	je     f01020ef <mem_init+0xecb>
f01020eb:	39 c6                	cmp    %eax,%esi
f01020ed:	74 24                	je     f0102113 <mem_init+0xeef>
f01020ef:	c7 44 24 0c 4c 54 10 	movl   $0xf010544c,0xc(%esp)
f01020f6:	f0 
f01020f7:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01020fe:	f0 
f01020ff:	c7 44 24 04 bf 03 00 	movl   $0x3bf,0x4(%esp)
f0102106:	00 
f0102107:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010210e:	e8 ce df ff ff       	call   f01000e1 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f0102113:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010211a:	00 
f010211b:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102120:	89 04 24             	mov    %eax,(%esp)
f0102123:	e8 f6 ef ff ff       	call   f010111e <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f0102128:	8b 3d 88 ce 17 f0    	mov    0xf017ce88,%edi
f010212e:	ba 00 00 00 00       	mov    $0x0,%edx
f0102133:	89 f8                	mov    %edi,%eax
f0102135:	e8 5e e8 ff ff       	call   f0100998 <check_va2pa>
f010213a:	83 f8 ff             	cmp    $0xffffffff,%eax
f010213d:	74 24                	je     f0102163 <mem_init+0xf3f>
f010213f:	c7 44 24 0c 70 54 10 	movl   $0xf0105470,0xc(%esp)
f0102146:	f0 
f0102147:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010214e:	f0 
f010214f:	c7 44 24 04 c3 03 00 	movl   $0x3c3,0x4(%esp)
f0102156:	00 
f0102157:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010215e:	e8 7e df ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102163:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102168:	89 f8                	mov    %edi,%eax
f010216a:	e8 29 e8 ff ff       	call   f0100998 <check_va2pa>
f010216f:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102172:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0102178:	c1 fa 03             	sar    $0x3,%edx
f010217b:	c1 e2 0c             	shl    $0xc,%edx
f010217e:	39 d0                	cmp    %edx,%eax
f0102180:	74 24                	je     f01021a6 <mem_init+0xf82>
f0102182:	c7 44 24 0c 1c 54 10 	movl   $0xf010541c,0xc(%esp)
f0102189:	f0 
f010218a:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102191:	f0 
f0102192:	c7 44 24 04 c4 03 00 	movl   $0x3c4,0x4(%esp)
f0102199:	00 
f010219a:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01021a1:	e8 3b df ff ff       	call   f01000e1 <_panic>
	assert(pp1->pp_ref == 1);
f01021a6:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01021a9:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f01021ae:	74 24                	je     f01021d4 <mem_init+0xfb0>
f01021b0:	c7 44 24 0c a1 58 10 	movl   $0xf01058a1,0xc(%esp)
f01021b7:	f0 
f01021b8:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01021bf:	f0 
f01021c0:	c7 44 24 04 c5 03 00 	movl   $0x3c5,0x4(%esp)
f01021c7:	00 
f01021c8:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01021cf:	e8 0d df ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 0);
f01021d4:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01021d9:	74 24                	je     f01021ff <mem_init+0xfdb>
f01021db:	c7 44 24 0c fb 58 10 	movl   $0xf01058fb,0xc(%esp)
f01021e2:	f0 
f01021e3:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01021ea:	f0 
f01021eb:	c7 44 24 04 c6 03 00 	movl   $0x3c6,0x4(%esp)
f01021f2:	00 
f01021f3:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01021fa:	e8 e2 de ff ff       	call   f01000e1 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01021ff:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102206:	00 
f0102207:	89 3c 24             	mov    %edi,(%esp)
f010220a:	e8 0f ef ff ff       	call   f010111e <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f010220f:	8b 3d 88 ce 17 f0    	mov    0xf017ce88,%edi
f0102215:	ba 00 00 00 00       	mov    $0x0,%edx
f010221a:	89 f8                	mov    %edi,%eax
f010221c:	e8 77 e7 ff ff       	call   f0100998 <check_va2pa>
f0102221:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102224:	74 24                	je     f010224a <mem_init+0x1026>
f0102226:	c7 44 24 0c 70 54 10 	movl   $0xf0105470,0xc(%esp)
f010222d:	f0 
f010222e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102235:	f0 
f0102236:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f010223d:	00 
f010223e:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102245:	e8 97 de ff ff       	call   f01000e1 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f010224a:	ba 00 10 00 00       	mov    $0x1000,%edx
f010224f:	89 f8                	mov    %edi,%eax
f0102251:	e8 42 e7 ff ff       	call   f0100998 <check_va2pa>
f0102256:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102259:	74 24                	je     f010227f <mem_init+0x105b>
f010225b:	c7 44 24 0c 94 54 10 	movl   $0xf0105494,0xc(%esp)
f0102262:	f0 
f0102263:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010226a:	f0 
f010226b:	c7 44 24 04 cb 03 00 	movl   $0x3cb,0x4(%esp)
f0102272:	00 
f0102273:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010227a:	e8 62 de ff ff       	call   f01000e1 <_panic>
	assert(pp1->pp_ref == 0);
f010227f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102282:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102287:	74 24                	je     f01022ad <mem_init+0x1089>
f0102289:	c7 44 24 0c 0c 59 10 	movl   $0xf010590c,0xc(%esp)
f0102290:	f0 
f0102291:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102298:	f0 
f0102299:	c7 44 24 04 cc 03 00 	movl   $0x3cc,0x4(%esp)
f01022a0:	00 
f01022a1:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01022a8:	e8 34 de ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 0);
f01022ad:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01022b2:	74 24                	je     f01022d8 <mem_init+0x10b4>
f01022b4:	c7 44 24 0c fb 58 10 	movl   $0xf01058fb,0xc(%esp)
f01022bb:	f0 
f01022bc:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01022c3:	f0 
f01022c4:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f01022cb:	00 
f01022cc:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01022d3:	e8 09 de ff ff       	call   f01000e1 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01022d8:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01022df:	e8 c8 eb ff ff       	call   f0100eac <page_alloc>
f01022e4:	85 c0                	test   %eax,%eax
f01022e6:	74 05                	je     f01022ed <mem_init+0x10c9>
f01022e8:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01022eb:	74 24                	je     f0102311 <mem_init+0x10ed>
f01022ed:	c7 44 24 0c bc 54 10 	movl   $0xf01054bc,0xc(%esp)
f01022f4:	f0 
f01022f5:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01022fc:	f0 
f01022fd:	c7 44 24 04 d0 03 00 	movl   $0x3d0,0x4(%esp)
f0102304:	00 
f0102305:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010230c:	e8 d0 dd ff ff       	call   f01000e1 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0102311:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102318:	e8 8f eb ff ff       	call   f0100eac <page_alloc>
f010231d:	85 c0                	test   %eax,%eax
f010231f:	74 24                	je     f0102345 <mem_init+0x1121>
f0102321:	c7 44 24 0c 4f 58 10 	movl   $0xf010584f,0xc(%esp)
f0102328:	f0 
f0102329:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102330:	f0 
f0102331:	c7 44 24 04 d3 03 00 	movl   $0x3d3,0x4(%esp)
f0102338:	00 
f0102339:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102340:	e8 9c dd ff ff       	call   f01000e1 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102345:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f010234a:	8b 08                	mov    (%eax),%ecx
f010234c:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102352:	89 da                	mov    %ebx,%edx
f0102354:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f010235a:	c1 fa 03             	sar    $0x3,%edx
f010235d:	c1 e2 0c             	shl    $0xc,%edx
f0102360:	39 d1                	cmp    %edx,%ecx
f0102362:	74 24                	je     f0102388 <mem_init+0x1164>
f0102364:	c7 44 24 0c cc 51 10 	movl   $0xf01051cc,0xc(%esp)
f010236b:	f0 
f010236c:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102373:	f0 
f0102374:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f010237b:	00 
f010237c:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102383:	e8 59 dd ff ff       	call   f01000e1 <_panic>
	kern_pgdir[0] = 0;
f0102388:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010238e:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102393:	74 24                	je     f01023b9 <mem_init+0x1195>
f0102395:	c7 44 24 0c b2 58 10 	movl   $0xf01058b2,0xc(%esp)
f010239c:	f0 
f010239d:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01023a4:	f0 
f01023a5:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f01023ac:	00 
f01023ad:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01023b4:	e8 28 dd ff ff       	call   f01000e1 <_panic>
	pp0->pp_ref = 0;
f01023b9:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f01023bf:	89 1c 24             	mov    %ebx,(%esp)
f01023c2:	e8 6a eb ff ff       	call   f0100f31 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f01023c7:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01023ce:	00 
f01023cf:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01023d6:	00 
f01023d7:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f01023dc:	89 04 24             	mov    %eax,(%esp)
f01023df:	e8 b8 eb ff ff       	call   f0100f9c <pgdir_walk>
f01023e4:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01023e7:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01023ea:	8b 15 88 ce 17 f0    	mov    0xf017ce88,%edx
f01023f0:	8b 7a 04             	mov    0x4(%edx),%edi
f01023f3:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01023f9:	8b 0d 84 ce 17 f0    	mov    0xf017ce84,%ecx
f01023ff:	89 f8                	mov    %edi,%eax
f0102401:	c1 e8 0c             	shr    $0xc,%eax
f0102404:	39 c8                	cmp    %ecx,%eax
f0102406:	72 20                	jb     f0102428 <mem_init+0x1204>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102408:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010240c:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0102413:	f0 
f0102414:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f010241b:	00 
f010241c:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102423:	e8 b9 dc ff ff       	call   f01000e1 <_panic>
	assert(ptep == ptep1 + PTX(va));
f0102428:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f010242e:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f0102431:	74 24                	je     f0102457 <mem_init+0x1233>
f0102433:	c7 44 24 0c 1d 59 10 	movl   $0xf010591d,0xc(%esp)
f010243a:	f0 
f010243b:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102442:	f0 
f0102443:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
f010244a:	00 
f010244b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102452:	e8 8a dc ff ff       	call   f01000e1 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102457:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f010245e:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102464:	89 d8                	mov    %ebx,%eax
f0102466:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f010246c:	c1 f8 03             	sar    $0x3,%eax
f010246f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102472:	89 c2                	mov    %eax,%edx
f0102474:	c1 ea 0c             	shr    $0xc,%edx
f0102477:	39 d1                	cmp    %edx,%ecx
f0102479:	77 20                	ja     f010249b <mem_init+0x1277>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010247b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010247f:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0102486:	f0 
f0102487:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010248e:	00 
f010248f:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102496:	e8 46 dc ff ff       	call   f01000e1 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f010249b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01024a2:	00 
f01024a3:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f01024aa:	00 
	return (void *)(pa + KERNBASE);
f01024ab:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01024b0:	89 04 24             	mov    %eax,(%esp)
f01024b3:	e8 c1 20 00 00       	call   f0104579 <memset>
	page_free(pp0);
f01024b8:	89 1c 24             	mov    %ebx,(%esp)
f01024bb:	e8 71 ea ff ff       	call   f0100f31 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f01024c0:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01024c7:	00 
f01024c8:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01024cf:	00 
f01024d0:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f01024d5:	89 04 24             	mov    %eax,(%esp)
f01024d8:	e8 bf ea ff ff       	call   f0100f9c <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01024dd:	89 da                	mov    %ebx,%edx
f01024df:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f01024e5:	c1 fa 03             	sar    $0x3,%edx
f01024e8:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01024eb:	89 d0                	mov    %edx,%eax
f01024ed:	c1 e8 0c             	shr    $0xc,%eax
f01024f0:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f01024f6:	72 20                	jb     f0102518 <mem_init+0x12f4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01024f8:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01024fc:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0102503:	f0 
f0102504:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010250b:	00 
f010250c:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102513:	e8 c9 db ff ff       	call   f01000e1 <_panic>
	return (void *)(pa + KERNBASE);
f0102518:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f010251e:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f0102521:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f0102528:	75 11                	jne    f010253b <mem_init+0x1317>
f010252a:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f0102530:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0102536:	f6 00 01             	testb  $0x1,(%eax)
f0102539:	74 24                	je     f010255f <mem_init+0x133b>
f010253b:	c7 44 24 0c 35 59 10 	movl   $0xf0105935,0xc(%esp)
f0102542:	f0 
f0102543:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010254a:	f0 
f010254b:	c7 44 24 04 ea 03 00 	movl   $0x3ea,0x4(%esp)
f0102552:	00 
f0102553:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010255a:	e8 82 db ff ff       	call   f01000e1 <_panic>
f010255f:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f0102562:	39 d0                	cmp    %edx,%eax
f0102564:	75 d0                	jne    f0102536 <mem_init+0x1312>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102566:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f010256b:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102571:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102577:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010257a:	a3 c0 c1 17 f0       	mov    %eax,0xf017c1c0

	// free the pages we took
	page_free(pp0);
f010257f:	89 1c 24             	mov    %ebx,(%esp)
f0102582:	e8 aa e9 ff ff       	call   f0100f31 <page_free>
	page_free(pp1);
f0102587:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010258a:	89 04 24             	mov    %eax,(%esp)
f010258d:	e8 9f e9 ff ff       	call   f0100f31 <page_free>
	page_free(pp2);
f0102592:	89 34 24             	mov    %esi,(%esp)
f0102595:	e8 97 e9 ff ff       	call   f0100f31 <page_free>

	cprintf("check_page() succeeded!\n");
f010259a:	c7 04 24 4c 59 10 f0 	movl   $0xf010594c,(%esp)
f01025a1:	e8 2e 0f 00 00       	call   f01034d4 <cprintf>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for( i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f01025a6:	8b 0d 84 ce 17 f0    	mov    0xf017ce84,%ecx
f01025ac:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f01025b3:	89 c2                	mov    %eax,%edx
f01025b5:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f01025bb:	39 d0                	cmp    %edx,%eax
f01025bd:	0f 84 bd 08 00 00    	je     f0102e80 <mem_init+0x1c5c>
	{
		page_insert(kern_pgdir,pa2page(PADDR(pages)+i),(void*)(UPAGES+i),PTE_U);
f01025c3:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01025c8:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01025cd:	76 21                	jbe    f01025f0 <mem_init+0x13cc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01025cf:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01025d5:	c1 ea 0c             	shr    $0xc,%edx
f01025d8:	39 d1                	cmp    %edx,%ecx
f01025da:	77 5e                	ja     f010263a <mem_init+0x1416>
f01025dc:	eb 40                	jmp    f010261e <mem_init+0x13fa>
f01025de:	8d b3 00 00 00 ef    	lea    -0x11000000(%ebx),%esi
f01025e4:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01025e9:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01025ee:	77 20                	ja     f0102610 <mem_init+0x13ec>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01025f0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01025f4:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f01025fb:	f0 
f01025fc:	c7 44 24 04 b1 00 00 	movl   $0xb1,0x4(%esp)
f0102603:	00 
f0102604:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010260b:	e8 d1 da ff ff       	call   f01000e1 <_panic>
f0102610:	8d 94 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102617:	c1 ea 0c             	shr    $0xc,%edx
f010261a:	39 d1                	cmp    %edx,%ecx
f010261c:	77 26                	ja     f0102644 <mem_init+0x1420>
		panic("pa2page called with invalid pa");
f010261e:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f0102625:	f0 
f0102626:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010262d:	00 
f010262e:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102635:	e8 a7 da ff ff       	call   f01000e1 <_panic>
f010263a:	be 00 00 00 ef       	mov    $0xef000000,%esi
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for( i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f010263f:	bb 00 00 00 00       	mov    $0x0,%ebx
	{
		page_insert(kern_pgdir,pa2page(PADDR(pages)+i),(void*)(UPAGES+i),PTE_U);
f0102644:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f010264b:	00 
f010264c:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102650:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102653:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102657:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f010265c:	89 04 24             	mov    %eax,(%esp)
f010265f:	e8 ff ea ff ff       	call   f0101163 <page_insert>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for( i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f0102664:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010266a:	89 da                	mov    %ebx,%edx
f010266c:	8b 0d 84 ce 17 f0    	mov    0xf017ce84,%ecx
f0102672:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102679:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010267e:	39 c3                	cmp    %eax,%ebx
f0102680:	0f 82 58 ff ff ff    	jb     f01025de <mem_init+0x13ba>
f0102686:	e9 f5 07 00 00       	jmp    f0102e80 <mem_init+0x1c5c>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f010268b:	b8 00 00 11 00       	mov    $0x110000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102690:	c1 e8 0c             	shr    $0xc,%eax
f0102693:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f0102699:	0f 82 f6 07 00 00    	jb     f0102e95 <mem_init+0x1c71>
f010269f:	eb 36                	jmp    f01026d7 <mem_init+0x14b3>
f01026a1:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f01026a4:	89 d8                	mov    %ebx,%eax
f01026a6:	c1 e8 0c             	shr    $0xc,%eax
f01026a9:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f01026af:	72 42                	jb     f01026f3 <mem_init+0x14cf>
f01026b1:	eb 24                	jmp    f01026d7 <mem_init+0x14b3>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01026b3:	c7 44 24 0c 00 00 11 	movl   $0xf0110000,0xc(%esp)
f01026ba:	f0 
f01026bb:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f01026c2:	f0 
f01026c3:	c7 44 24 04 c9 00 00 	movl   $0xc9,0x4(%esp)
f01026ca:	00 
f01026cb:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01026d2:	e8 0a da ff ff       	call   f01000e1 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f01026d7:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f01026de:	f0 
f01026df:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01026e6:	00 
f01026e7:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f01026ee:	e8 ee d9 ff ff       	call   f01000e1 <_panic>
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);	
f01026f3:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01026fa:	00 
f01026fb:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01026ff:	8b 15 8c ce 17 f0    	mov    0xf017ce8c,%edx
f0102705:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102708:	89 44 24 04          	mov    %eax,0x4(%esp)
f010270c:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102711:	89 04 24             	mov    %eax,(%esp)
f0102714:	e8 4a ea ff ff       	call   f0101163 <page_insert>
f0102719:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f010271f:	39 fb                	cmp    %edi,%ebx
f0102721:	0f 85 7a ff ff ff    	jne    f01026a1 <mem_init+0x147d>
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102727:	be 00 00 00 00       	mov    $0x0,%esi
	//     * [KSTACKTOP-PTSIZE, KSTACKTOP-KSTKSIZE) -- not backed; so if
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f010272c:	bb 00 00 00 00       	mov    $0x0,%ebx
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
	{
	    if(i<npages*PGSIZE)
f0102731:	a1 84 ce 17 f0       	mov    0xf017ce84,%eax
f0102736:	89 c2                	mov    %eax,%edx
f0102738:	c1 e2 0c             	shl    $0xc,%edx
f010273b:	39 f2                	cmp    %esi,%edx
f010273d:	0f 86 86 00 00 00    	jbe    f01027c9 <mem_init+0x15a5>
	    {
	     page_insert(kern_pgdir,pa2page(i),(void*)(KERNBASE+i),PTE_W);
f0102743:	8d 96 00 00 00 f0    	lea    -0x10000000(%esi),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102749:	c1 ee 0c             	shr    $0xc,%esi
f010274c:	39 f0                	cmp    %esi,%eax
f010274e:	77 1c                	ja     f010276c <mem_init+0x1548>
		panic("pa2page called with invalid pa");
f0102750:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f0102757:	f0 
f0102758:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010275f:	00 
f0102760:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102767:	e8 75 d9 ff ff       	call   f01000e1 <_panic>
	return &pages[PGNUM(pa)];
f010276c:	8d 3c f5 00 00 00 00 	lea    0x0(,%esi,8),%edi
f0102773:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010277a:	00 
f010277b:	89 54 24 08          	mov    %edx,0x8(%esp)
f010277f:	89 f8                	mov    %edi,%eax
f0102781:	03 05 8c ce 17 f0    	add    0xf017ce8c,%eax
f0102787:	89 44 24 04          	mov    %eax,0x4(%esp)
f010278b:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102790:	89 04 24             	mov    %eax,(%esp)
f0102793:	e8 cb e9 ff ff       	call   f0101163 <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102798:	3b 35 84 ce 17 f0    	cmp    0xf017ce84,%esi
f010279e:	72 1c                	jb     f01027bc <mem_init+0x1598>
		panic("pa2page called with invalid pa");
f01027a0:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f01027a7:	f0 
f01027a8:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01027af:	00 
f01027b0:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f01027b7:	e8 25 d9 ff ff       	call   f01000e1 <_panic>
	return &pages[PGNUM(pa)];
f01027bc:	03 3d 8c ce 17 f0    	add    0xf017ce8c,%edi
		pa2page(i)->pp_ref--;
f01027c2:	66 83 6f 04 01       	subw   $0x1,0x4(%edi)
f01027c7:	eb 77                	jmp    f0102840 <mem_init+0x161c>
	    }
	    else
            {
		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
f01027c9:	81 ee 00 00 00 10    	sub    $0x10000000,%esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027cf:	85 c0                	test   %eax,%eax
f01027d1:	75 1c                	jne    f01027ef <mem_init+0x15cb>
		panic("pa2page called with invalid pa");
f01027d3:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f01027da:	f0 
f01027db:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01027e2:	00 
f01027e3:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f01027ea:	e8 f2 d8 ff ff       	call   f01000e1 <_panic>
f01027ef:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01027f6:	00 
f01027f7:	89 74 24 08          	mov    %esi,0x8(%esp)
f01027fb:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
f0102800:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102804:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102809:	89 04 24             	mov    %eax,(%esp)
f010280c:	e8 52 e9 ff ff       	call   f0101163 <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102811:	83 3d 84 ce 17 f0 00 	cmpl   $0x0,0xf017ce84
f0102818:	75 1c                	jne    f0102836 <mem_init+0x1612>
		panic("pa2page called with invalid pa");
f010281a:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f0102821:	f0 
f0102822:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102829:	00 
f010282a:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102831:	e8 ab d8 ff ff       	call   f01000e1 <_panic>
	return &pages[PGNUM(pa)];
f0102836:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
		pa2page(0)->pp_ref--;
f010283b:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
	//      the PA range [0, 2^32 - KERNBASE)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102840:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102846:	89 de                	mov    %ebx,%esi
f0102848:	81 fb 00 00 00 10    	cmp    $0x10000000,%ebx
f010284e:	0f 85 dd fe ff ff    	jne    f0102731 <mem_init+0x150d>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102854:	8b 35 88 ce 17 f0    	mov    0xf017ce88,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f010285a:	a1 84 ce 17 f0       	mov    0xf017ce84,%eax
f010285f:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102862:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102869:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010286e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102871:	74 7f                	je     f01028f2 <mem_init+0x16ce>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102873:	8b 1d 8c ce 17 f0    	mov    0xf017ce8c,%ebx
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102879:	8d bb 00 00 00 10    	lea    0x10000000(%ebx),%edi
f010287f:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102884:	89 f0                	mov    %esi,%eax
f0102886:	e8 0d e1 ff ff       	call   f0100998 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010288b:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102891:	77 20                	ja     f01028b3 <mem_init+0x168f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102893:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102897:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f010289e:	f0 
f010289f:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01028a6:	00 
f01028a7:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01028ae:	e8 2e d8 ff ff       	call   f01000e1 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01028b3:	ba 00 00 00 00       	mov    $0x0,%edx
f01028b8:	8d 0c 17             	lea    (%edi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01028bb:	39 c1                	cmp    %eax,%ecx
f01028bd:	74 24                	je     f01028e3 <mem_init+0x16bf>
f01028bf:	c7 44 24 0c e0 54 10 	movl   $0xf01054e0,0xc(%esp)
f01028c6:	f0 
f01028c7:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01028ce:	f0 
f01028cf:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01028d6:	00 
f01028d7:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01028de:	e8 fe d7 ff ff       	call   f01000e1 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01028e3:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f01028e9:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f01028ec:	0f 87 16 06 00 00    	ja     f0102f08 <mem_init+0x1ce4>
//	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
//	for (i = 0; i < n; i += PGSIZE)
//		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f01028f2:	8b 7d d0             	mov    -0x30(%ebp),%edi
f01028f5:	c1 e7 0c             	shl    $0xc,%edi
f01028f8:	85 ff                	test   %edi,%edi
f01028fa:	0f 84 e7 05 00 00    	je     f0102ee7 <mem_init+0x1cc3>
f0102900:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102905:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f010290b:	89 f0                	mov    %esi,%eax
f010290d:	e8 86 e0 ff ff       	call   f0100998 <check_va2pa>
f0102912:	39 c3                	cmp    %eax,%ebx
f0102914:	74 24                	je     f010293a <mem_init+0x1716>
f0102916:	c7 44 24 0c 14 55 10 	movl   $0xf0105514,0xc(%esp)
f010291d:	f0 
f010291e:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102925:	f0 
f0102926:	c7 44 24 04 3b 03 00 	movl   $0x33b,0x4(%esp)
f010292d:	00 
f010292e:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102935:	e8 a7 d7 ff ff       	call   f01000e1 <_panic>
//	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
//	for (i = 0; i < n; i += PGSIZE)
//		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f010293a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102940:	39 fb                	cmp    %edi,%ebx
f0102942:	72 c1                	jb     f0102905 <mem_init+0x16e1>
f0102944:	e9 9e 05 00 00       	jmp    f0102ee7 <mem_init+0x1cc3>
f0102949:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f010294c:	39 c2                	cmp    %eax,%edx
f010294e:	74 24                	je     f0102974 <mem_init+0x1750>
f0102950:	c7 44 24 0c 3c 55 10 	movl   $0xf010553c,0xc(%esp)
f0102957:	f0 
f0102958:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010295f:	f0 
f0102960:	c7 44 24 04 3f 03 00 	movl   $0x33f,0x4(%esp)
f0102967:	00 
f0102968:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f010296f:	e8 6d d7 ff ff       	call   f01000e1 <_panic>
f0102974:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f010297a:	81 fb 00 00 c0 ef    	cmp    $0xefc00000,%ebx
f0102980:	0f 85 53 05 00 00    	jne    f0102ed9 <mem_init+0x1cb5>
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
f0102986:	ba 00 00 80 ef       	mov    $0xef800000,%edx
f010298b:	89 f0                	mov    %esi,%eax
f010298d:	e8 06 e0 ff ff       	call   f0100998 <check_va2pa>
f0102992:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102995:	74 24                	je     f01029bb <mem_init+0x1797>
f0102997:	c7 44 24 0c 84 55 10 	movl   $0xf0105584,0xc(%esp)
f010299e:	f0 
f010299f:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01029a6:	f0 
f01029a7:	c7 44 24 04 40 03 00 	movl   $0x340,0x4(%esp)
f01029ae:	00 
f01029af:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01029b6:	e8 26 d7 ff ff       	call   f01000e1 <_panic>
f01029bb:	b8 00 00 00 00       	mov    $0x0,%eax

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f01029c0:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f01029c6:	83 fa 03             	cmp    $0x3,%edx
f01029c9:	0f 86 86 00 00 00    	jbe    f0102a55 <mem_init+0x1831>
		case PDX(UPAGES):
		case PDX(UENVS):
	//		assert(pgdir[i] & PTE_P);
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f01029cf:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f01029d4:	76 55                	jbe    f0102a2b <mem_init+0x1807>
				assert(pgdir[i] & PTE_P);
f01029d6:	8b 14 86             	mov    (%esi,%eax,4),%edx
f01029d9:	f6 c2 01             	test   $0x1,%dl
f01029dc:	75 24                	jne    f0102a02 <mem_init+0x17de>
f01029de:	c7 44 24 0c 65 59 10 	movl   $0xf0105965,0xc(%esp)
f01029e5:	f0 
f01029e6:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01029ed:	f0 
f01029ee:	c7 44 24 04 4d 03 00 	movl   $0x34d,0x4(%esp)
f01029f5:	00 
f01029f6:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f01029fd:	e8 df d6 ff ff       	call   f01000e1 <_panic>
				assert(pgdir[i] & PTE_W);
f0102a02:	f6 c2 02             	test   $0x2,%dl
f0102a05:	75 4e                	jne    f0102a55 <mem_init+0x1831>
f0102a07:	c7 44 24 0c 76 59 10 	movl   $0xf0105976,0xc(%esp)
f0102a0e:	f0 
f0102a0f:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102a16:	f0 
f0102a17:	c7 44 24 04 4e 03 00 	movl   $0x34e,0x4(%esp)
f0102a1e:	00 
f0102a1f:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102a26:	e8 b6 d6 ff ff       	call   f01000e1 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102a2b:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102a2f:	74 24                	je     f0102a55 <mem_init+0x1831>
f0102a31:	c7 44 24 0c 87 59 10 	movl   $0xf0105987,0xc(%esp)
f0102a38:	f0 
f0102a39:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102a40:	f0 
f0102a41:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0102a48:	00 
f0102a49:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102a50:	e8 8c d6 ff ff       	call   f01000e1 <_panic>
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
	assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102a55:	83 c0 01             	add    $0x1,%eax
f0102a58:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102a5d:	0f 85 5d ff ff ff    	jne    f01029c0 <mem_init+0x179c>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102a63:	c7 04 24 b4 55 10 f0 	movl   $0xf01055b4,(%esp)
f0102a6a:	e8 65 0a 00 00       	call   f01034d4 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102a6f:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102a74:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102a79:	77 20                	ja     f0102a9b <mem_init+0x1877>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a7b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102a7f:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f0102a86:	f0 
f0102a87:	c7 44 24 04 ed 00 00 	movl   $0xed,0x4(%esp)
f0102a8e:	00 
f0102a8f:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102a96:	e8 46 d6 ff ff       	call   f01000e1 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102a9b:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102aa0:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0102aa3:	b8 00 00 00 00       	mov    $0x0,%eax
f0102aa8:	e8 5a df ff ff       	call   f0100a07 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102aad:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102ab0:	83 e0 f3             	and    $0xfffffff3,%eax
f0102ab3:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102ab8:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102abb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102ac2:	e8 e5 e3 ff ff       	call   f0100eac <page_alloc>
f0102ac7:	89 c3                	mov    %eax,%ebx
f0102ac9:	85 c0                	test   %eax,%eax
f0102acb:	75 24                	jne    f0102af1 <mem_init+0x18cd>
f0102acd:	c7 44 24 0c a4 57 10 	movl   $0xf01057a4,0xc(%esp)
f0102ad4:	f0 
f0102ad5:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102adc:	f0 
f0102add:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102ae4:	00 
f0102ae5:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102aec:	e8 f0 d5 ff ff       	call   f01000e1 <_panic>
	assert((pp1 = page_alloc(0)));
f0102af1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102af8:	e8 af e3 ff ff       	call   f0100eac <page_alloc>
f0102afd:	89 c7                	mov    %eax,%edi
f0102aff:	85 c0                	test   %eax,%eax
f0102b01:	75 24                	jne    f0102b27 <mem_init+0x1903>
f0102b03:	c7 44 24 0c ba 57 10 	movl   $0xf01057ba,0xc(%esp)
f0102b0a:	f0 
f0102b0b:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102b12:	f0 
f0102b13:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f0102b1a:	00 
f0102b1b:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102b22:	e8 ba d5 ff ff       	call   f01000e1 <_panic>
	assert((pp2 = page_alloc(0)));
f0102b27:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102b2e:	e8 79 e3 ff ff       	call   f0100eac <page_alloc>
f0102b33:	89 c6                	mov    %eax,%esi
f0102b35:	85 c0                	test   %eax,%eax
f0102b37:	75 24                	jne    f0102b5d <mem_init+0x1939>
f0102b39:	c7 44 24 0c d0 57 10 	movl   $0xf01057d0,0xc(%esp)
f0102b40:	f0 
f0102b41:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102b48:	f0 
f0102b49:	c7 44 24 04 07 04 00 	movl   $0x407,0x4(%esp)
f0102b50:	00 
f0102b51:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102b58:	e8 84 d5 ff ff       	call   f01000e1 <_panic>
	page_free(pp0);
f0102b5d:	89 1c 24             	mov    %ebx,(%esp)
f0102b60:	e8 cc e3 ff ff       	call   f0100f31 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102b65:	89 f8                	mov    %edi,%eax
f0102b67:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f0102b6d:	c1 f8 03             	sar    $0x3,%eax
f0102b70:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b73:	89 c2                	mov    %eax,%edx
f0102b75:	c1 ea 0c             	shr    $0xc,%edx
f0102b78:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f0102b7e:	72 20                	jb     f0102ba0 <mem_init+0x197c>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102b80:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102b84:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0102b8b:	f0 
f0102b8c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102b93:	00 
f0102b94:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102b9b:	e8 41 d5 ff ff       	call   f01000e1 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f0102ba0:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102ba7:	00 
f0102ba8:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102baf:	00 
	return (void *)(pa + KERNBASE);
f0102bb0:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102bb5:	89 04 24             	mov    %eax,(%esp)
f0102bb8:	e8 bc 19 00 00       	call   f0104579 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102bbd:	89 f0                	mov    %esi,%eax
f0102bbf:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f0102bc5:	c1 f8 03             	sar    $0x3,%eax
f0102bc8:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102bcb:	89 c2                	mov    %eax,%edx
f0102bcd:	c1 ea 0c             	shr    $0xc,%edx
f0102bd0:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f0102bd6:	72 20                	jb     f0102bf8 <mem_init+0x19d4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102bd8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102bdc:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0102be3:	f0 
f0102be4:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102beb:	00 
f0102bec:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102bf3:	e8 e9 d4 ff ff       	call   f01000e1 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0102bf8:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102bff:	00 
f0102c00:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102c07:	00 
	return (void *)(pa + KERNBASE);
f0102c08:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102c0d:	89 04 24             	mov    %eax,(%esp)
f0102c10:	e8 64 19 00 00       	call   f0104579 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102c15:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102c1c:	00 
f0102c1d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102c24:	00 
f0102c25:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0102c29:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102c2e:	89 04 24             	mov    %eax,(%esp)
f0102c31:	e8 2d e5 ff ff       	call   f0101163 <page_insert>
	assert(pp1->pp_ref == 1);
f0102c36:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0102c3b:	74 24                	je     f0102c61 <mem_init+0x1a3d>
f0102c3d:	c7 44 24 0c a1 58 10 	movl   $0xf01058a1,0xc(%esp)
f0102c44:	f0 
f0102c45:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102c4c:	f0 
f0102c4d:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f0102c54:	00 
f0102c55:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102c5c:	e8 80 d4 ff ff       	call   f01000e1 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102c61:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102c68:	01 01 01 
f0102c6b:	74 24                	je     f0102c91 <mem_init+0x1a6d>
f0102c6d:	c7 44 24 0c d4 55 10 	movl   $0xf01055d4,0xc(%esp)
f0102c74:	f0 
f0102c75:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102c7c:	f0 
f0102c7d:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f0102c84:	00 
f0102c85:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102c8c:	e8 50 d4 ff ff       	call   f01000e1 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0102c91:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102c98:	00 
f0102c99:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102ca0:	00 
f0102ca1:	89 74 24 04          	mov    %esi,0x4(%esp)
f0102ca5:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102caa:	89 04 24             	mov    %eax,(%esp)
f0102cad:	e8 b1 e4 ff ff       	call   f0101163 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f0102cb2:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0102cb9:	02 02 02 
f0102cbc:	74 24                	je     f0102ce2 <mem_init+0x1abe>
f0102cbe:	c7 44 24 0c f8 55 10 	movl   $0xf01055f8,0xc(%esp)
f0102cc5:	f0 
f0102cc6:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102ccd:	f0 
f0102cce:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
f0102cd5:	00 
f0102cd6:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102cdd:	e8 ff d3 ff ff       	call   f01000e1 <_panic>
	assert(pp2->pp_ref == 1);
f0102ce2:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102ce7:	74 24                	je     f0102d0d <mem_init+0x1ae9>
f0102ce9:	c7 44 24 0c c3 58 10 	movl   $0xf01058c3,0xc(%esp)
f0102cf0:	f0 
f0102cf1:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102cf8:	f0 
f0102cf9:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f0102d00:	00 
f0102d01:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102d08:	e8 d4 d3 ff ff       	call   f01000e1 <_panic>
	assert(pp1->pp_ref == 0);
f0102d0d:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0102d12:	74 24                	je     f0102d38 <mem_init+0x1b14>
f0102d14:	c7 44 24 0c 0c 59 10 	movl   $0xf010590c,0xc(%esp)
f0102d1b:	f0 
f0102d1c:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102d23:	f0 
f0102d24:	c7 44 24 04 11 04 00 	movl   $0x411,0x4(%esp)
f0102d2b:	00 
f0102d2c:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102d33:	e8 a9 d3 ff ff       	call   f01000e1 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0102d38:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f0102d3f:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102d42:	89 f0                	mov    %esi,%eax
f0102d44:	2b 05 8c ce 17 f0    	sub    0xf017ce8c,%eax
f0102d4a:	c1 f8 03             	sar    $0x3,%eax
f0102d4d:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102d50:	89 c2                	mov    %eax,%edx
f0102d52:	c1 ea 0c             	shr    $0xc,%edx
f0102d55:	3b 15 84 ce 17 f0    	cmp    0xf017ce84,%edx
f0102d5b:	72 20                	jb     f0102d7d <mem_init+0x1b59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102d5d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102d61:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f0102d68:	f0 
f0102d69:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102d70:	00 
f0102d71:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0102d78:	e8 64 d3 ff ff       	call   f01000e1 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0102d7d:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0102d84:	03 03 03 
f0102d87:	74 24                	je     f0102dad <mem_init+0x1b89>
f0102d89:	c7 44 24 0c 1c 56 10 	movl   $0xf010561c,0xc(%esp)
f0102d90:	f0 
f0102d91:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102d98:	f0 
f0102d99:	c7 44 24 04 13 04 00 	movl   $0x413,0x4(%esp)
f0102da0:	00 
f0102da1:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102da8:	e8 34 d3 ff ff       	call   f01000e1 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f0102dad:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102db4:	00 
f0102db5:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102dba:	89 04 24             	mov    %eax,(%esp)
f0102dbd:	e8 5c e3 ff ff       	call   f010111e <page_remove>
	assert(pp2->pp_ref == 0);
f0102dc2:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102dc7:	74 24                	je     f0102ded <mem_init+0x1bc9>
f0102dc9:	c7 44 24 0c fb 58 10 	movl   $0xf01058fb,0xc(%esp)
f0102dd0:	f0 
f0102dd1:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102dd8:	f0 
f0102dd9:	c7 44 24 04 15 04 00 	movl   $0x415,0x4(%esp)
f0102de0:	00 
f0102de1:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102de8:	e8 f4 d2 ff ff       	call   f01000e1 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102ded:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102df2:	8b 08                	mov    (%eax),%ecx
f0102df4:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102dfa:	89 da                	mov    %ebx,%edx
f0102dfc:	2b 15 8c ce 17 f0    	sub    0xf017ce8c,%edx
f0102e02:	c1 fa 03             	sar    $0x3,%edx
f0102e05:	c1 e2 0c             	shl    $0xc,%edx
f0102e08:	39 d1                	cmp    %edx,%ecx
f0102e0a:	74 24                	je     f0102e30 <mem_init+0x1c0c>
f0102e0c:	c7 44 24 0c cc 51 10 	movl   $0xf01051cc,0xc(%esp)
f0102e13:	f0 
f0102e14:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102e1b:	f0 
f0102e1c:	c7 44 24 04 18 04 00 	movl   $0x418,0x4(%esp)
f0102e23:	00 
f0102e24:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102e2b:	e8 b1 d2 ff ff       	call   f01000e1 <_panic>
	kern_pgdir[0] = 0;
f0102e30:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102e36:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102e3b:	74 24                	je     f0102e61 <mem_init+0x1c3d>
f0102e3d:	c7 44 24 0c b2 58 10 	movl   $0xf01058b2,0xc(%esp)
f0102e44:	f0 
f0102e45:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f0102e4c:	f0 
f0102e4d:	c7 44 24 04 1a 04 00 	movl   $0x41a,0x4(%esp)
f0102e54:	00 
f0102e55:	c7 04 24 a9 56 10 f0 	movl   $0xf01056a9,(%esp)
f0102e5c:	e8 80 d2 ff ff       	call   f01000e1 <_panic>
	pp0->pp_ref = 0;
f0102e61:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0102e67:	89 1c 24             	mov    %ebx,(%esp)
f0102e6a:	e8 c2 e0 ff ff       	call   f0100f31 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0102e6f:	c7 04 24 48 56 10 f0 	movl   $0xf0105648,(%esp)
f0102e76:	e8 59 06 00 00       	call   f01034d4 <cprintf>
f0102e7b:	e9 9c 00 00 00       	jmp    f0102f1c <mem_init+0x1cf8>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102e80:	b8 00 00 11 f0       	mov    $0xf0110000,%eax
f0102e85:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102e8a:	0f 86 23 f8 ff ff    	jbe    f01026b3 <mem_init+0x148f>
f0102e90:	e9 f6 f7 ff ff       	jmp    f010268b <mem_init+0x1467>
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);	
f0102e95:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102e9c:	00 
f0102e9d:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f0102ea4:	ef 
static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f0102ea5:	8b 15 8c ce 17 f0    	mov    0xf017ce8c,%edx
f0102eab:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102eae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102eb2:	a1 88 ce 17 f0       	mov    0xf017ce88,%eax
f0102eb7:	89 04 24             	mov    %eax,(%esp)
f0102eba:	e8 a4 e2 ff ff       	call   f0101163 <page_insert>
f0102ebf:	bb 00 10 11 00       	mov    $0x111000,%ebx
f0102ec4:	bf 00 80 11 00       	mov    $0x118000,%edi
f0102ec9:	be 00 80 bf df       	mov    $0xdfbf8000,%esi
f0102ece:	81 ee 00 00 11 f0    	sub    $0xf0110000,%esi
f0102ed4:	e9 c8 f7 ff ff       	jmp    f01026a1 <mem_init+0x147d>
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check kernel stack
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f0102ed9:	89 da                	mov    %ebx,%edx
f0102edb:	89 f0                	mov    %esi,%eax
f0102edd:	e8 b6 da ff ff       	call   f0100998 <check_va2pa>
f0102ee2:	e9 62 fa ff ff       	jmp    f0102949 <mem_init+0x1725>
f0102ee7:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f0102eec:	89 f0                	mov    %esi,%eax
f0102eee:	e8 a5 da ff ff       	call   f0100998 <check_va2pa>
f0102ef3:	bb 00 80 bf ef       	mov    $0xefbf8000,%ebx
f0102ef8:	bf 00 00 11 f0       	mov    $0xf0110000,%edi
f0102efd:	81 c7 00 80 40 20    	add    $0x20408000,%edi
f0102f03:	e9 41 fa ff ff       	jmp    f0102949 <mem_init+0x1725>
f0102f08:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102f0e:	89 f0                	mov    %esi,%eax
f0102f10:	e8 83 da ff ff       	call   f0100998 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102f15:	89 da                	mov    %ebx,%edx
f0102f17:	e9 9c f9 ff ff       	jmp    f01028b8 <mem_init+0x1694>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0102f1c:	83 c4 3c             	add    $0x3c,%esp
f0102f1f:	5b                   	pop    %ebx
f0102f20:	5e                   	pop    %esi
f0102f21:	5f                   	pop    %edi
f0102f22:	5d                   	pop    %ebp
f0102f23:	c3                   	ret    

f0102f24 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0102f24:	55                   	push   %ebp
f0102f25:	89 e5                	mov    %esp,%ebp
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0102f27:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102f2a:	0f 01 38             	invlpg (%eax)
	// Flush the entry only if we're modifying the current address space.
	// For now, there is only one address space, so always invalidate.
	invlpg(va);
}
f0102f2d:	5d                   	pop    %ebp
f0102f2e:	c3                   	ret    

f0102f2f <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
    int  
    user_mem_check(struct Env *env, const void *va, size_t len, int perm)  
    {  
f0102f2f:	55                   	push   %ebp
f0102f30:	89 e5                	mov    %esp,%ebp
f0102f32:	57                   	push   %edi
f0102f33:	56                   	push   %esi
f0102f34:	53                   	push   %ebx
f0102f35:	83 ec 1c             	sub    $0x1c,%esp
f0102f38:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0102f3b:	8b 7d 14             	mov    0x14(%ebp),%edi
        //check ULIM  
        if ((uint32_t)va >= ULIM)  
f0102f3e:	81 fb ff ff 7f ef    	cmp    $0xef7fffff,%ebx
f0102f44:	76 0d                	jbe    f0102f53 <user_mem_check+0x24>
        {   user_mem_check_addr = (uintptr_t)va;  
f0102f46:	89 1d bc c1 17 f0    	mov    %ebx,0xf017c1bc
            return -E_FAULT;  
f0102f4c:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0102f51:	eb 6b                	jmp    f0102fbe <user_mem_check+0x8f>
        }  
        //check priority  
        const void *eva;  
        pte_t *ppte;  
        for (eva=va+len,ppte=NULL; va<eva; va=ROUNDDOWN(va,PGSIZE)+PGSIZE,ppte++)  
f0102f53:	89 de                	mov    %ebx,%esi
f0102f55:	03 75 10             	add    0x10(%ebp),%esi
f0102f58:	39 f3                	cmp    %esi,%ebx
f0102f5a:	73 56                	jae    f0102fb2 <user_mem_check+0x83>
f0102f5c:	b8 00 00 00 00       	mov    $0x0,%eax
        {  
            if(PGOFF(ppte)==0)//change page table?  
f0102f61:	a9 ff 0f 00 00       	test   $0xfff,%eax
f0102f66:	75 1a                	jne    f0102f82 <user_mem_check+0x53>
                ppte = pgdir_walk(env->env_pgdir, va, 0);  
f0102f68:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102f6f:	00 
f0102f70:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102f74:	8b 45 08             	mov    0x8(%ebp),%eax
f0102f77:	8b 40 5c             	mov    0x5c(%eax),%eax
f0102f7a:	89 04 24             	mov    %eax,(%esp)
f0102f7d:	e8 1a e0 ff ff       	call   f0100f9c <pgdir_walk>
            if((ppte == NULL) || ((*ppte|perm) != *ppte))  
f0102f82:	85 c0                	test   %eax,%eax
f0102f84:	74 0a                	je     f0102f90 <user_mem_check+0x61>
f0102f86:	8b 10                	mov    (%eax),%edx
f0102f88:	89 d1                	mov    %edx,%ecx
f0102f8a:	09 f9                	or     %edi,%ecx
f0102f8c:	39 ca                	cmp    %ecx,%edx
f0102f8e:	74 0d                	je     f0102f9d <user_mem_check+0x6e>
            {     
                user_mem_check_addr = (uintptr_t)va;  
f0102f90:	89 1d bc c1 17 f0    	mov    %ebx,0xf017c1bc
                return -E_FAULT;//no map or no priority   
f0102f96:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0102f9b:	eb 21                	jmp    f0102fbe <user_mem_check+0x8f>
            return -E_FAULT;  
        }  
        //check priority  
        const void *eva;  
        pte_t *ppte;  
        for (eva=va+len,ppte=NULL; va<eva; va=ROUNDDOWN(va,PGSIZE)+PGSIZE,ppte++)  
f0102f9d:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0102fa3:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102fa9:	83 c0 04             	add    $0x4,%eax
f0102fac:	39 de                	cmp    %ebx,%esi
f0102fae:	77 b1                	ja     f0102f61 <user_mem_check+0x32>
f0102fb0:	eb 07                	jmp    f0102fb9 <user_mem_check+0x8a>
            {     
                user_mem_check_addr = (uintptr_t)va;  
                return -E_FAULT;//no map or no priority   
            }  
        }  
        return 0;  
f0102fb2:	b8 00 00 00 00       	mov    $0x0,%eax
f0102fb7:	eb 05                	jmp    f0102fbe <user_mem_check+0x8f>
f0102fb9:	b8 00 00 00 00       	mov    $0x0,%eax
    }  
f0102fbe:	83 c4 1c             	add    $0x1c,%esp
f0102fc1:	5b                   	pop    %ebx
f0102fc2:	5e                   	pop    %esi
f0102fc3:	5f                   	pop    %edi
f0102fc4:	5d                   	pop    %ebp
f0102fc5:	c3                   	ret    

f0102fc6 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f0102fc6:	55                   	push   %ebp
f0102fc7:	89 e5                	mov    %esp,%ebp
f0102fc9:	53                   	push   %ebx
f0102fca:	83 ec 14             	sub    $0x14,%esp
f0102fcd:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f0102fd0:	8b 45 14             	mov    0x14(%ebp),%eax
f0102fd3:	83 c8 04             	or     $0x4,%eax
f0102fd6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102fda:	8b 45 10             	mov    0x10(%ebp),%eax
f0102fdd:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102fe1:	8b 45 0c             	mov    0xc(%ebp),%eax
f0102fe4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102fe8:	89 1c 24             	mov    %ebx,(%esp)
f0102feb:	e8 3f ff ff ff       	call   f0102f2f <user_mem_check>
f0102ff0:	85 c0                	test   %eax,%eax
f0102ff2:	79 24                	jns    f0103018 <user_mem_assert+0x52>
		cprintf("[%08x] user_mem_check assertion failure for "
f0102ff4:	a1 bc c1 17 f0       	mov    0xf017c1bc,%eax
f0102ff9:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102ffd:	8b 43 48             	mov    0x48(%ebx),%eax
f0103000:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103004:	c7 04 24 74 56 10 f0 	movl   $0xf0105674,(%esp)
f010300b:	e8 c4 04 00 00       	call   f01034d4 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f0103010:	89 1c 24             	mov    %ebx,(%esp)
f0103013:	e8 d3 03 00 00       	call   f01033eb <env_destroy>
	}
}
f0103018:	83 c4 14             	add    $0x14,%esp
f010301b:	5b                   	pop    %ebx
f010301c:	5d                   	pop    %ebp
f010301d:	c3                   	ret    

f010301e <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f010301e:	55                   	push   %ebp
f010301f:	89 e5                	mov    %esp,%ebp
f0103021:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103024:	85 c0                	test   %eax,%eax
f0103026:	75 11                	jne    f0103039 <envid2env+0x1b>
		*env_store = curenv;
f0103028:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f010302d:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0103030:	89 01                	mov    %eax,(%ecx)
		return 0;
f0103032:	b8 00 00 00 00       	mov    $0x0,%eax
f0103037:	eb 60                	jmp    f0103099 <envid2env+0x7b>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f0103039:	89 c2                	mov    %eax,%edx
f010303b:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0103041:	8d 14 52             	lea    (%edx,%edx,2),%edx
f0103044:	c1 e2 05             	shl    $0x5,%edx
f0103047:	03 15 cc c1 17 f0    	add    0xf017c1cc,%edx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f010304d:	83 7a 54 00          	cmpl   $0x0,0x54(%edx)
f0103051:	74 05                	je     f0103058 <envid2env+0x3a>
f0103053:	39 42 48             	cmp    %eax,0x48(%edx)
f0103056:	74 10                	je     f0103068 <envid2env+0x4a>
		*env_store = 0;
f0103058:	8b 45 0c             	mov    0xc(%ebp),%eax
f010305b:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103061:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103066:	eb 31                	jmp    f0103099 <envid2env+0x7b>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0103068:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f010306c:	74 21                	je     f010308f <envid2env+0x71>
f010306e:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f0103073:	39 c2                	cmp    %eax,%edx
f0103075:	74 18                	je     f010308f <envid2env+0x71>
f0103077:	8b 40 48             	mov    0x48(%eax),%eax
f010307a:	39 42 4c             	cmp    %eax,0x4c(%edx)
f010307d:	74 10                	je     f010308f <envid2env+0x71>
		*env_store = 0;
f010307f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103082:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103088:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f010308d:	eb 0a                	jmp    f0103099 <envid2env+0x7b>
	}

	*env_store = e;
f010308f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103092:	89 10                	mov    %edx,(%eax)
	return 0;
f0103094:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103099:	5d                   	pop    %ebp
f010309a:	c3                   	ret    

f010309b <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f010309b:	55                   	push   %ebp
f010309c:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f010309e:	b8 00 a3 11 f0       	mov    $0xf011a300,%eax
f01030a3:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f01030a6:	b8 23 00 00 00       	mov    $0x23,%eax
f01030ab:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f01030ad:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f01030af:	b0 10                	mov    $0x10,%al
f01030b1:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f01030b3:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f01030b5:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f01030b7:	ea be 30 10 f0 08 00 	ljmp   $0x8,$0xf01030be
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f01030be:	b0 00                	mov    $0x0,%al
f01030c0:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f01030c3:	5d                   	pop    %ebp
f01030c4:	c3                   	ret    

f01030c5 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f01030c5:	55                   	push   %ebp
f01030c6:	89 e5                	mov    %esp,%ebp
	// Set up envs array
	// LAB 3: Your code here.

	// Per-CPU part of the initialization
	env_init_percpu();
f01030c8:	e8 ce ff ff ff       	call   f010309b <env_init_percpu>
}
f01030cd:	5d                   	pop    %ebp
f01030ce:	c3                   	ret    

f01030cf <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01030cf:	55                   	push   %ebp
f01030d0:	89 e5                	mov    %esp,%ebp
f01030d2:	53                   	push   %ebx
f01030d3:	83 ec 14             	sub    $0x14,%esp
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f01030d6:	8b 1d d0 c1 17 f0    	mov    0xf017c1d0,%ebx
f01030dc:	85 db                	test   %ebx,%ebx
f01030de:	0f 84 08 01 00 00    	je     f01031ec <env_alloc+0x11d>
{
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f01030e4:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01030eb:	e8 bc dd ff ff       	call   f0100eac <page_alloc>
f01030f0:	85 c0                	test   %eax,%eax
f01030f2:	0f 84 fb 00 00 00    	je     f01031f3 <env_alloc+0x124>

	// LAB 3: Your code here.

	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f01030f8:	8b 43 5c             	mov    0x5c(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01030fb:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103100:	77 20                	ja     f0103122 <env_alloc+0x53>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103102:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103106:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f010310d:	f0 
f010310e:	c7 44 24 04 b9 00 00 	movl   $0xb9,0x4(%esp)
f0103115:	00 
f0103116:	c7 04 24 ce 59 10 f0 	movl   $0xf01059ce,(%esp)
f010311d:	e8 bf cf ff ff       	call   f01000e1 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103122:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103128:	83 ca 05             	or     $0x5,%edx
f010312b:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f0103131:	8b 43 48             	mov    0x48(%ebx),%eax
f0103134:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103139:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f010313e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103143:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103146:	89 da                	mov    %ebx,%edx
f0103148:	2b 15 cc c1 17 f0    	sub    0xf017c1cc,%edx
f010314e:	c1 fa 05             	sar    $0x5,%edx
f0103151:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0103157:	09 d0                	or     %edx,%eax
f0103159:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f010315c:	8b 45 0c             	mov    0xc(%ebp),%eax
f010315f:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0103162:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103169:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
	e->env_runs = 0;
f0103170:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103177:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f010317e:	00 
f010317f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103186:	00 
f0103187:	89 1c 24             	mov    %ebx,(%esp)
f010318a:	e8 ea 13 00 00       	call   f0104579 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f010318f:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f0103195:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f010319b:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f01031a1:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f01031a8:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
	// You will set e->env_tf.tf_eip later.

	// commit the allocation
	env_free_list = e->env_link;
f01031ae:	8b 43 44             	mov    0x44(%ebx),%eax
f01031b1:	a3 d0 c1 17 f0       	mov    %eax,0xf017c1d0
	*newenv_store = e;
f01031b6:	8b 45 08             	mov    0x8(%ebp),%eax
f01031b9:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f01031bb:	8b 53 48             	mov    0x48(%ebx),%edx
f01031be:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f01031c3:	85 c0                	test   %eax,%eax
f01031c5:	74 05                	je     f01031cc <env_alloc+0xfd>
f01031c7:	8b 40 48             	mov    0x48(%eax),%eax
f01031ca:	eb 05                	jmp    f01031d1 <env_alloc+0x102>
f01031cc:	b8 00 00 00 00       	mov    $0x0,%eax
f01031d1:	89 54 24 08          	mov    %edx,0x8(%esp)
f01031d5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01031d9:	c7 04 24 d9 59 10 f0 	movl   $0xf01059d9,(%esp)
f01031e0:	e8 ef 02 00 00       	call   f01034d4 <cprintf>
	return 0;
f01031e5:	b8 00 00 00 00       	mov    $0x0,%eax
f01031ea:	eb 0c                	jmp    f01031f8 <env_alloc+0x129>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f01031ec:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01031f1:	eb 05                	jmp    f01031f8 <env_alloc+0x129>
	int i;
	struct Page *p = NULL;

	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01031f3:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f01031f8:	83 c4 14             	add    $0x14,%esp
f01031fb:	5b                   	pop    %ebx
f01031fc:	5d                   	pop    %ebp
f01031fd:	c3                   	ret    

f01031fe <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01031fe:	55                   	push   %ebp
f01031ff:	89 e5                	mov    %esp,%ebp
	// LAB 3: Your code here.
}
f0103201:	5d                   	pop    %ebp
f0103202:	c3                   	ret    

f0103203 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103203:	55                   	push   %ebp
f0103204:	89 e5                	mov    %esp,%ebp
f0103206:	57                   	push   %edi
f0103207:	56                   	push   %esi
f0103208:	53                   	push   %ebx
f0103209:	83 ec 2c             	sub    $0x2c,%esp
f010320c:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f010320f:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f0103214:	39 c7                	cmp    %eax,%edi
f0103216:	75 37                	jne    f010324f <env_free+0x4c>
		lcr3(PADDR(kern_pgdir));
f0103218:	8b 15 88 ce 17 f0    	mov    0xf017ce88,%edx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010321e:	81 fa ff ff ff ef    	cmp    $0xefffffff,%edx
f0103224:	77 20                	ja     f0103246 <env_free+0x43>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103226:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010322a:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f0103231:	f0 
f0103232:	c7 44 24 04 68 01 00 	movl   $0x168,0x4(%esp)
f0103239:	00 
f010323a:	c7 04 24 ce 59 10 f0 	movl   $0xf01059ce,(%esp)
f0103241:	e8 9b ce ff ff       	call   f01000e1 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103246:	81 c2 00 00 00 10    	add    $0x10000000,%edx
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010324c:	0f 22 da             	mov    %edx,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f010324f:	8b 57 48             	mov    0x48(%edi),%edx
f0103252:	85 c0                	test   %eax,%eax
f0103254:	74 05                	je     f010325b <env_free+0x58>
f0103256:	8b 40 48             	mov    0x48(%eax),%eax
f0103259:	eb 05                	jmp    f0103260 <env_free+0x5d>
f010325b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103260:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103264:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103268:	c7 04 24 ee 59 10 f0 	movl   $0xf01059ee,(%esp)
f010326f:	e8 60 02 00 00       	call   f01034d4 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103274:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f010327b:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f010327e:	89 c8                	mov    %ecx,%eax
f0103280:	c1 e0 02             	shl    $0x2,%eax
f0103283:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103286:	8b 47 5c             	mov    0x5c(%edi),%eax
f0103289:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f010328c:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103292:	0f 84 b7 00 00 00    	je     f010334f <env_free+0x14c>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103298:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010329e:	89 f0                	mov    %esi,%eax
f01032a0:	c1 e8 0c             	shr    $0xc,%eax
f01032a3:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01032a6:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f01032ac:	72 20                	jb     f01032ce <env_free+0xcb>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01032ae:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01032b2:	c7 44 24 08 64 4f 10 	movl   $0xf0104f64,0x8(%esp)
f01032b9:	f0 
f01032ba:	c7 44 24 04 77 01 00 	movl   $0x177,0x4(%esp)
f01032c1:	00 
f01032c2:	c7 04 24 ce 59 10 f0 	movl   $0xf01059ce,(%esp)
f01032c9:	e8 13 ce ff ff       	call   f01000e1 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01032ce:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01032d1:	c1 e0 16             	shl    $0x16,%eax
f01032d4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f01032d7:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f01032dc:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f01032e3:	01 
f01032e4:	74 17                	je     f01032fd <env_free+0xfa>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01032e6:	89 d8                	mov    %ebx,%eax
f01032e8:	c1 e0 0c             	shl    $0xc,%eax
f01032eb:	0b 45 e4             	or     -0x1c(%ebp),%eax
f01032ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01032f2:	8b 47 5c             	mov    0x5c(%edi),%eax
f01032f5:	89 04 24             	mov    %eax,(%esp)
f01032f8:	e8 21 de ff ff       	call   f010111e <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f01032fd:	83 c3 01             	add    $0x1,%ebx
f0103300:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103306:	75 d4                	jne    f01032dc <env_free+0xd9>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103308:	8b 47 5c             	mov    0x5c(%edi),%eax
f010330b:	8b 55 dc             	mov    -0x24(%ebp),%edx
f010330e:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103315:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103318:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f010331e:	72 1c                	jb     f010333c <env_free+0x139>
		panic("pa2page called with invalid pa");
f0103320:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f0103327:	f0 
f0103328:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010332f:	00 
f0103330:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f0103337:	e8 a5 cd ff ff       	call   f01000e1 <_panic>
	return &pages[PGNUM(pa)];
f010333c:	a1 8c ce 17 f0       	mov    0xf017ce8c,%eax
f0103341:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103344:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103347:	89 04 24             	mov    %eax,(%esp)
f010334a:	e8 2a dc ff ff       	call   f0100f79 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f010334f:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103353:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f010335a:	0f 85 1b ff ff ff    	jne    f010327b <env_free+0x78>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103360:	8b 47 5c             	mov    0x5c(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103363:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103368:	77 20                	ja     f010338a <env_free+0x187>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010336a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010336e:	c7 44 24 08 d0 50 10 	movl   $0xf01050d0,0x8(%esp)
f0103375:	f0 
f0103376:	c7 44 24 04 85 01 00 	movl   $0x185,0x4(%esp)
f010337d:	00 
f010337e:	c7 04 24 ce 59 10 f0 	movl   $0xf01059ce,(%esp)
f0103385:	e8 57 cd ff ff       	call   f01000e1 <_panic>
	e->env_pgdir = 0;
f010338a:	c7 47 5c 00 00 00 00 	movl   $0x0,0x5c(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103391:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103396:	c1 e8 0c             	shr    $0xc,%eax
f0103399:	3b 05 84 ce 17 f0    	cmp    0xf017ce84,%eax
f010339f:	72 1c                	jb     f01033bd <env_free+0x1ba>
		panic("pa2page called with invalid pa");
f01033a1:	c7 44 24 08 74 50 10 	movl   $0xf0105074,0x8(%esp)
f01033a8:	f0 
f01033a9:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01033b0:	00 
f01033b1:	c7 04 24 b5 56 10 f0 	movl   $0xf01056b5,(%esp)
f01033b8:	e8 24 cd ff ff       	call   f01000e1 <_panic>
	return &pages[PGNUM(pa)];
f01033bd:	8b 15 8c ce 17 f0    	mov    0xf017ce8c,%edx
f01033c3:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f01033c6:	89 04 24             	mov    %eax,(%esp)
f01033c9:	e8 ab db ff ff       	call   f0100f79 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f01033ce:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f01033d5:	a1 d0 c1 17 f0       	mov    0xf017c1d0,%eax
f01033da:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f01033dd:	89 3d d0 c1 17 f0    	mov    %edi,0xf017c1d0
}
f01033e3:	83 c4 2c             	add    $0x2c,%esp
f01033e6:	5b                   	pop    %ebx
f01033e7:	5e                   	pop    %esi
f01033e8:	5f                   	pop    %edi
f01033e9:	5d                   	pop    %ebp
f01033ea:	c3                   	ret    

f01033eb <env_destroy>:
//
// Frees environment e.
//
void
env_destroy(struct Env *e)
{
f01033eb:	55                   	push   %ebp
f01033ec:	89 e5                	mov    %esp,%ebp
f01033ee:	83 ec 18             	sub    $0x18,%esp
	env_free(e);
f01033f1:	8b 45 08             	mov    0x8(%ebp),%eax
f01033f4:	89 04 24             	mov    %eax,(%esp)
f01033f7:	e8 07 fe ff ff       	call   f0103203 <env_free>

	cprintf("Destroyed the only environment - nothing more to do!\n");
f01033fc:	c7 04 24 98 59 10 f0 	movl   $0xf0105998,(%esp)
f0103403:	e8 cc 00 00 00       	call   f01034d4 <cprintf>
	while (1)
		monitor(NULL);
f0103408:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010340f:	e8 f3 d3 ff ff       	call   f0100807 <monitor>
f0103414:	eb f2                	jmp    f0103408 <env_destroy+0x1d>

f0103416 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103416:	55                   	push   %ebp
f0103417:	89 e5                	mov    %esp,%ebp
f0103419:	83 ec 18             	sub    $0x18,%esp
	__asm __volatile("movl %0,%%esp\n"
f010341c:	8b 65 08             	mov    0x8(%ebp),%esp
f010341f:	61                   	popa   
f0103420:	07                   	pop    %es
f0103421:	1f                   	pop    %ds
f0103422:	83 c4 08             	add    $0x8,%esp
f0103425:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103426:	c7 44 24 08 04 5a 10 	movl   $0xf0105a04,0x8(%esp)
f010342d:	f0 
f010342e:	c7 44 24 04 ad 01 00 	movl   $0x1ad,0x4(%esp)
f0103435:	00 
f0103436:	c7 04 24 ce 59 10 f0 	movl   $0xf01059ce,(%esp)
f010343d:	e8 9f cc ff ff       	call   f01000e1 <_panic>

f0103442 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103442:	55                   	push   %ebp
f0103443:	89 e5                	mov    %esp,%ebp
f0103445:	83 ec 18             	sub    $0x18,%esp
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.

	panic("env_run not yet implemented");
f0103448:	c7 44 24 08 10 5a 10 	movl   $0xf0105a10,0x8(%esp)
f010344f:	f0 
f0103450:	c7 44 24 04 cc 01 00 	movl   $0x1cc,0x4(%esp)
f0103457:	00 
f0103458:	c7 04 24 ce 59 10 f0 	movl   $0xf01059ce,(%esp)
f010345f:	e8 7d cc ff ff       	call   f01000e1 <_panic>

f0103464 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103464:	55                   	push   %ebp
f0103465:	89 e5                	mov    %esp,%ebp
f0103467:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010346b:	ba 70 00 00 00       	mov    $0x70,%edx
f0103470:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103471:	b2 71                	mov    $0x71,%dl
f0103473:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103474:	0f b6 c0             	movzbl %al,%eax
}
f0103477:	5d                   	pop    %ebp
f0103478:	c3                   	ret    

f0103479 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103479:	55                   	push   %ebp
f010347a:	89 e5                	mov    %esp,%ebp
f010347c:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103480:	ba 70 00 00 00       	mov    $0x70,%edx
f0103485:	ee                   	out    %al,(%dx)
f0103486:	b2 71                	mov    $0x71,%dl
f0103488:	8b 45 0c             	mov    0xc(%ebp),%eax
f010348b:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f010348c:	5d                   	pop    %ebp
f010348d:	c3                   	ret    

f010348e <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f010348e:	55                   	push   %ebp
f010348f:	89 e5                	mov    %esp,%ebp
f0103491:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103494:	8b 45 08             	mov    0x8(%ebp),%eax
f0103497:	89 04 24             	mov    %eax,(%esp)
f010349a:	e8 b5 d1 ff ff       	call   f0100654 <cputchar>
	*cnt++;
}
f010349f:	c9                   	leave  
f01034a0:	c3                   	ret    

f01034a1 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f01034a1:	55                   	push   %ebp
f01034a2:	89 e5                	mov    %esp,%ebp
f01034a4:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f01034a7:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f01034ae:	8b 45 0c             	mov    0xc(%ebp),%eax
f01034b1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01034b5:	8b 45 08             	mov    0x8(%ebp),%eax
f01034b8:	89 44 24 08          	mov    %eax,0x8(%esp)
f01034bc:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01034bf:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034c3:	c7 04 24 8e 34 10 f0 	movl   $0xf010348e,(%esp)
f01034ca:	e8 ab 08 00 00       	call   f0103d7a <vprintfmt>
	return cnt;
}
f01034cf:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01034d2:	c9                   	leave  
f01034d3:	c3                   	ret    

f01034d4 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f01034d4:	55                   	push   %ebp
f01034d5:	89 e5                	mov    %esp,%ebp
f01034d7:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f01034da:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f01034dd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034e1:	8b 45 08             	mov    0x8(%ebp),%eax
f01034e4:	89 04 24             	mov    %eax,(%esp)
f01034e7:	e8 b5 ff ff ff       	call   f01034a1 <vcprintf>
	va_end(ap);

	return cnt;
}
f01034ec:	c9                   	leave  
f01034ed:	c3                   	ret    

f01034ee <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f01034ee:	55                   	push   %ebp
f01034ef:	89 e5                	mov    %esp,%ebp
	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f01034f1:	c7 05 04 ca 17 f0 00 	movl   $0xefc00000,0xf017ca04
f01034f8:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f01034fb:	66 c7 05 08 ca 17 f0 	movw   $0x10,0xf017ca08
f0103502:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f0103504:	66 c7 05 48 a3 11 f0 	movw   $0x68,0xf011a348
f010350b:	68 00 
f010350d:	b8 00 ca 17 f0       	mov    $0xf017ca00,%eax
f0103512:	66 a3 4a a3 11 f0    	mov    %ax,0xf011a34a
f0103518:	89 c2                	mov    %eax,%edx
f010351a:	c1 ea 10             	shr    $0x10,%edx
f010351d:	88 15 4c a3 11 f0    	mov    %dl,0xf011a34c
f0103523:	c6 05 4e a3 11 f0 40 	movb   $0x40,0xf011a34e
f010352a:	c1 e8 18             	shr    $0x18,%eax
f010352d:	a2 4f a3 11 f0       	mov    %al,0xf011a34f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f0103532:	c6 05 4d a3 11 f0 89 	movb   $0x89,0xf011a34d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103539:	b8 28 00 00 00       	mov    $0x28,%eax
f010353e:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103541:	b8 50 a3 11 f0       	mov    $0xf011a350,%eax
f0103546:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f0103549:	5d                   	pop    %ebp
f010354a:	c3                   	ret    

f010354b <trap_init>:
}


void
trap_init(void)
{
f010354b:	55                   	push   %ebp
f010354c:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];

	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f010354e:	e8 9b ff ff ff       	call   f01034ee <trap_init_percpu>
}
f0103553:	5d                   	pop    %ebp
f0103554:	c3                   	ret    

f0103555 <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f0103555:	55                   	push   %ebp
f0103556:	89 e5                	mov    %esp,%ebp
f0103558:	53                   	push   %ebx
f0103559:	83 ec 14             	sub    $0x14,%esp
f010355c:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f010355f:	8b 03                	mov    (%ebx),%eax
f0103561:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103565:	c7 04 24 2c 5a 10 f0 	movl   $0xf0105a2c,(%esp)
f010356c:	e8 63 ff ff ff       	call   f01034d4 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0103571:	8b 43 04             	mov    0x4(%ebx),%eax
f0103574:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103578:	c7 04 24 3b 5a 10 f0 	movl   $0xf0105a3b,(%esp)
f010357f:	e8 50 ff ff ff       	call   f01034d4 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f0103584:	8b 43 08             	mov    0x8(%ebx),%eax
f0103587:	89 44 24 04          	mov    %eax,0x4(%esp)
f010358b:	c7 04 24 4a 5a 10 f0 	movl   $0xf0105a4a,(%esp)
f0103592:	e8 3d ff ff ff       	call   f01034d4 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f0103597:	8b 43 0c             	mov    0xc(%ebx),%eax
f010359a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010359e:	c7 04 24 59 5a 10 f0 	movl   $0xf0105a59,(%esp)
f01035a5:	e8 2a ff ff ff       	call   f01034d4 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f01035aa:	8b 43 10             	mov    0x10(%ebx),%eax
f01035ad:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035b1:	c7 04 24 68 5a 10 f0 	movl   $0xf0105a68,(%esp)
f01035b8:	e8 17 ff ff ff       	call   f01034d4 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f01035bd:	8b 43 14             	mov    0x14(%ebx),%eax
f01035c0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035c4:	c7 04 24 77 5a 10 f0 	movl   $0xf0105a77,(%esp)
f01035cb:	e8 04 ff ff ff       	call   f01034d4 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f01035d0:	8b 43 18             	mov    0x18(%ebx),%eax
f01035d3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035d7:	c7 04 24 86 5a 10 f0 	movl   $0xf0105a86,(%esp)
f01035de:	e8 f1 fe ff ff       	call   f01034d4 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f01035e3:	8b 43 1c             	mov    0x1c(%ebx),%eax
f01035e6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035ea:	c7 04 24 95 5a 10 f0 	movl   $0xf0105a95,(%esp)
f01035f1:	e8 de fe ff ff       	call   f01034d4 <cprintf>
}
f01035f6:	83 c4 14             	add    $0x14,%esp
f01035f9:	5b                   	pop    %ebx
f01035fa:	5d                   	pop    %ebp
f01035fb:	c3                   	ret    

f01035fc <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f01035fc:	55                   	push   %ebp
f01035fd:	89 e5                	mov    %esp,%ebp
f01035ff:	56                   	push   %esi
f0103600:	53                   	push   %ebx
f0103601:	83 ec 10             	sub    $0x10,%esp
f0103604:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p\n", tf);
f0103607:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010360b:	c7 04 24 cb 5b 10 f0 	movl   $0xf0105bcb,(%esp)
f0103612:	e8 bd fe ff ff       	call   f01034d4 <cprintf>
	print_regs(&tf->tf_regs);
f0103617:	89 1c 24             	mov    %ebx,(%esp)
f010361a:	e8 36 ff ff ff       	call   f0103555 <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f010361f:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0103623:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103627:	c7 04 24 e6 5a 10 f0 	movl   $0xf0105ae6,(%esp)
f010362e:	e8 a1 fe ff ff       	call   f01034d4 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0103633:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0103637:	89 44 24 04          	mov    %eax,0x4(%esp)
f010363b:	c7 04 24 f9 5a 10 f0 	movl   $0xf0105af9,(%esp)
f0103642:	e8 8d fe ff ff       	call   f01034d4 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0103647:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010364a:	83 f8 13             	cmp    $0x13,%eax
f010364d:	77 09                	ja     f0103658 <print_trapframe+0x5c>
		return excnames[trapno];
f010364f:	8b 14 85 a0 5d 10 f0 	mov    -0xfefa260(,%eax,4),%edx
f0103656:	eb 10                	jmp    f0103668 <print_trapframe+0x6c>
	if (trapno == T_SYSCALL)
		return "System call";
f0103658:	83 f8 30             	cmp    $0x30,%eax
f010365b:	ba a4 5a 10 f0       	mov    $0xf0105aa4,%edx
f0103660:	b9 b0 5a 10 f0       	mov    $0xf0105ab0,%ecx
f0103665:	0f 45 d1             	cmovne %ecx,%edx
{
	cprintf("TRAP frame at %p\n", tf);
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0103668:	89 54 24 08          	mov    %edx,0x8(%esp)
f010366c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103670:	c7 04 24 0c 5b 10 f0 	movl   $0xf0105b0c,(%esp)
f0103677:	e8 58 fe ff ff       	call   f01034d4 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010367c:	3b 1d e0 c9 17 f0    	cmp    0xf017c9e0,%ebx
f0103682:	75 19                	jne    f010369d <print_trapframe+0xa1>
f0103684:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0103688:	75 13                	jne    f010369d <print_trapframe+0xa1>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010368a:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010368d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103691:	c7 04 24 1e 5b 10 f0 	movl   $0xf0105b1e,(%esp)
f0103698:	e8 37 fe ff ff       	call   f01034d4 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010369d:	8b 43 2c             	mov    0x2c(%ebx),%eax
f01036a0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036a4:	c7 04 24 2d 5b 10 f0 	movl   $0xf0105b2d,(%esp)
f01036ab:	e8 24 fe ff ff       	call   f01034d4 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f01036b0:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01036b4:	75 51                	jne    f0103707 <print_trapframe+0x10b>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f01036b6:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f01036b9:	89 c2                	mov    %eax,%edx
f01036bb:	83 e2 01             	and    $0x1,%edx
f01036be:	ba bf 5a 10 f0       	mov    $0xf0105abf,%edx
f01036c3:	b9 ca 5a 10 f0       	mov    $0xf0105aca,%ecx
f01036c8:	0f 45 ca             	cmovne %edx,%ecx
f01036cb:	89 c2                	mov    %eax,%edx
f01036cd:	83 e2 02             	and    $0x2,%edx
f01036d0:	ba d6 5a 10 f0       	mov    $0xf0105ad6,%edx
f01036d5:	be dc 5a 10 f0       	mov    $0xf0105adc,%esi
f01036da:	0f 44 d6             	cmove  %esi,%edx
f01036dd:	83 e0 04             	and    $0x4,%eax
f01036e0:	b8 e1 5a 10 f0       	mov    $0xf0105ae1,%eax
f01036e5:	be f6 5b 10 f0       	mov    $0xf0105bf6,%esi
f01036ea:	0f 44 c6             	cmove  %esi,%eax
f01036ed:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01036f1:	89 54 24 08          	mov    %edx,0x8(%esp)
f01036f5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036f9:	c7 04 24 3b 5b 10 f0 	movl   $0xf0105b3b,(%esp)
f0103700:	e8 cf fd ff ff       	call   f01034d4 <cprintf>
f0103705:	eb 0c                	jmp    f0103713 <print_trapframe+0x117>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f0103707:	c7 04 24 66 4a 10 f0 	movl   $0xf0104a66,(%esp)
f010370e:	e8 c1 fd ff ff       	call   f01034d4 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0103713:	8b 43 30             	mov    0x30(%ebx),%eax
f0103716:	89 44 24 04          	mov    %eax,0x4(%esp)
f010371a:	c7 04 24 4a 5b 10 f0 	movl   $0xf0105b4a,(%esp)
f0103721:	e8 ae fd ff ff       	call   f01034d4 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0103726:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f010372a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010372e:	c7 04 24 59 5b 10 f0 	movl   $0xf0105b59,(%esp)
f0103735:	e8 9a fd ff ff       	call   f01034d4 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f010373a:	8b 43 38             	mov    0x38(%ebx),%eax
f010373d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103741:	c7 04 24 6c 5b 10 f0 	movl   $0xf0105b6c,(%esp)
f0103748:	e8 87 fd ff ff       	call   f01034d4 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010374d:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0103751:	74 27                	je     f010377a <print_trapframe+0x17e>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0103753:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0103756:	89 44 24 04          	mov    %eax,0x4(%esp)
f010375a:	c7 04 24 7b 5b 10 f0 	movl   $0xf0105b7b,(%esp)
f0103761:	e8 6e fd ff ff       	call   f01034d4 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0103766:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010376a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010376e:	c7 04 24 8a 5b 10 f0 	movl   $0xf0105b8a,(%esp)
f0103775:	e8 5a fd ff ff       	call   f01034d4 <cprintf>
	}
}
f010377a:	83 c4 10             	add    $0x10,%esp
f010377d:	5b                   	pop    %ebx
f010377e:	5e                   	pop    %esi
f010377f:	5d                   	pop    %ebp
f0103780:	c3                   	ret    

f0103781 <trap>:
	}
}

void
trap(struct Trapframe *tf)
{
f0103781:	55                   	push   %ebp
f0103782:	89 e5                	mov    %esp,%ebp
f0103784:	57                   	push   %edi
f0103785:	56                   	push   %esi
f0103786:	83 ec 10             	sub    $0x10,%esp
f0103789:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f010378c:	fc                   	cld    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f010378d:	9c                   	pushf  
f010378e:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f010378f:	f6 c4 02             	test   $0x2,%ah
f0103792:	74 24                	je     f01037b8 <trap+0x37>
f0103794:	c7 44 24 0c 9d 5b 10 	movl   $0xf0105b9d,0xc(%esp)
f010379b:	f0 
f010379c:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01037a3:	f0 
f01037a4:	c7 44 24 04 a7 00 00 	movl   $0xa7,0x4(%esp)
f01037ab:	00 
f01037ac:	c7 04 24 b6 5b 10 f0 	movl   $0xf0105bb6,(%esp)
f01037b3:	e8 29 c9 ff ff       	call   f01000e1 <_panic>

	cprintf("Incoming TRAP frame at %p\n", tf);
f01037b8:	89 74 24 04          	mov    %esi,0x4(%esp)
f01037bc:	c7 04 24 c2 5b 10 f0 	movl   $0xf0105bc2,(%esp)
f01037c3:	e8 0c fd ff ff       	call   f01034d4 <cprintf>

	if ((tf->tf_cs & 3) == 3) {
f01037c8:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01037cc:	83 e0 03             	and    $0x3,%eax
f01037cf:	66 83 f8 03          	cmp    $0x3,%ax
f01037d3:	75 3c                	jne    f0103811 <trap+0x90>
		// Trapped from user mode.
		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		assert(curenv);
f01037d5:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f01037da:	85 c0                	test   %eax,%eax
f01037dc:	75 24                	jne    f0103802 <trap+0x81>
f01037de:	c7 44 24 0c dd 5b 10 	movl   $0xf0105bdd,0xc(%esp)
f01037e5:	f0 
f01037e6:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f01037ed:	f0 
f01037ee:	c7 44 24 04 b0 00 00 	movl   $0xb0,0x4(%esp)
f01037f5:	00 
f01037f6:	c7 04 24 b6 5b 10 f0 	movl   $0xf0105bb6,(%esp)
f01037fd:	e8 df c8 ff ff       	call   f01000e1 <_panic>
		curenv->env_tf = *tf;
f0103802:	b9 11 00 00 00       	mov    $0x11,%ecx
f0103807:	89 c7                	mov    %eax,%edi
f0103809:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f010380b:	8b 35 c8 c1 17 f0    	mov    0xf017c1c8,%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0103811:	89 35 e0 c9 17 f0    	mov    %esi,0xf017c9e0
{
	// Handle processor exceptions.
	// LAB 3: Your code here.

	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
f0103817:	89 34 24             	mov    %esi,(%esp)
f010381a:	e8 dd fd ff ff       	call   f01035fc <print_trapframe>
	if (tf->tf_cs == GD_KT)
f010381f:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0103824:	75 1c                	jne    f0103842 <trap+0xc1>
		panic("unhandled trap in kernel");
f0103826:	c7 44 24 08 e4 5b 10 	movl   $0xf0105be4,0x8(%esp)
f010382d:	f0 
f010382e:	c7 44 24 04 96 00 00 	movl   $0x96,0x4(%esp)
f0103835:	00 
f0103836:	c7 04 24 b6 5b 10 f0 	movl   $0xf0105bb6,(%esp)
f010383d:	e8 9f c8 ff ff       	call   f01000e1 <_panic>
	else {
		env_destroy(curenv);
f0103842:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f0103847:	89 04 24             	mov    %eax,(%esp)
f010384a:	e8 9c fb ff ff       	call   f01033eb <env_destroy>

	// Dispatch based on what type of trap occurred
	trap_dispatch(tf);

	// Return to the current environment, which should be running.
	assert(curenv && curenv->env_status == ENV_RUNNING);
f010384f:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f0103854:	85 c0                	test   %eax,%eax
f0103856:	74 06                	je     f010385e <trap+0xdd>
f0103858:	83 78 54 02          	cmpl   $0x2,0x54(%eax)
f010385c:	74 24                	je     f0103882 <trap+0x101>
f010385e:	c7 44 24 0c 40 5d 10 	movl   $0xf0105d40,0xc(%esp)
f0103865:	f0 
f0103866:	c7 44 24 08 cf 56 10 	movl   $0xf01056cf,0x8(%esp)
f010386d:	f0 
f010386e:	c7 44 24 04 be 00 00 	movl   $0xbe,0x4(%esp)
f0103875:	00 
f0103876:	c7 04 24 b6 5b 10 f0 	movl   $0xf0105bb6,(%esp)
f010387d:	e8 5f c8 ff ff       	call   f01000e1 <_panic>
	env_run(curenv);
f0103882:	89 04 24             	mov    %eax,(%esp)
f0103885:	e8 b8 fb ff ff       	call   f0103442 <env_run>

f010388a <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f010388a:	55                   	push   %ebp
f010388b:	89 e5                	mov    %esp,%ebp
f010388d:	53                   	push   %ebx
f010388e:	83 ec 14             	sub    $0x14,%esp
f0103891:	8b 5d 08             	mov    0x8(%ebp),%ebx

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0103894:	0f 20 d0             	mov    %cr2,%eax

	// We've already handled kernel-mode exceptions, so if we get here,
	// the page fault happened in user mode.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0103897:	8b 53 30             	mov    0x30(%ebx),%edx
f010389a:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010389e:	89 44 24 08          	mov    %eax,0x8(%esp)
f01038a2:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f01038a7:	8b 40 48             	mov    0x48(%eax),%eax
f01038aa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01038ae:	c7 04 24 6c 5d 10 f0 	movl   $0xf0105d6c,(%esp)
f01038b5:	e8 1a fc ff ff       	call   f01034d4 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
f01038ba:	89 1c 24             	mov    %ebx,(%esp)
f01038bd:	e8 3a fd ff ff       	call   f01035fc <print_trapframe>
	env_destroy(curenv);
f01038c2:	a1 c8 c1 17 f0       	mov    0xf017c1c8,%eax
f01038c7:	89 04 24             	mov    %eax,(%esp)
f01038ca:	e8 1c fb ff ff       	call   f01033eb <env_destroy>
}
f01038cf:	83 c4 14             	add    $0x14,%esp
f01038d2:	5b                   	pop    %ebx
f01038d3:	5d                   	pop    %ebp
f01038d4:	c3                   	ret    

f01038d5 <syscall>:
f01038d5:	55                   	push   %ebp
f01038d6:	89 e5                	mov    %esp,%ebp
f01038d8:	83 ec 18             	sub    $0x18,%esp
f01038db:	c7 44 24 08 f0 5d 10 	movl   $0xf0105df0,0x8(%esp)
f01038e2:	f0 
f01038e3:	c7 44 24 04 49 00 00 	movl   $0x49,0x4(%esp)
f01038ea:	00 
f01038eb:	c7 04 24 08 5e 10 f0 	movl   $0xf0105e08,(%esp)
f01038f2:	e8 ea c7 ff ff       	call   f01000e1 <_panic>
f01038f7:	66 90                	xchg   %ax,%ax
f01038f9:	66 90                	xchg   %ax,%ax
f01038fb:	66 90                	xchg   %ax,%ax
f01038fd:	66 90                	xchg   %ax,%ax
f01038ff:	90                   	nop

f0103900 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0103900:	55                   	push   %ebp
f0103901:	89 e5                	mov    %esp,%ebp
f0103903:	57                   	push   %edi
f0103904:	56                   	push   %esi
f0103905:	53                   	push   %ebx
f0103906:	83 ec 14             	sub    $0x14,%esp
f0103909:	89 45 ec             	mov    %eax,-0x14(%ebp)
f010390c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f010390f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0103912:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0103915:	8b 1a                	mov    (%edx),%ebx
f0103917:	8b 01                	mov    (%ecx),%eax
f0103919:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f010391c:	39 c3                	cmp    %eax,%ebx
f010391e:	0f 8f 9a 00 00 00    	jg     f01039be <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0103924:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f010392b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f010392e:	01 d8                	add    %ebx,%eax
f0103930:	89 c7                	mov    %eax,%edi
f0103932:	c1 ef 1f             	shr    $0x1f,%edi
f0103935:	01 c7                	add    %eax,%edi
f0103937:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0103939:	39 df                	cmp    %ebx,%edi
f010393b:	0f 8c c4 00 00 00    	jl     f0103a05 <stab_binsearch+0x105>
f0103941:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0103944:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0103947:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010394a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010394e:	39 f0                	cmp    %esi,%eax
f0103950:	0f 84 b4 00 00 00    	je     f0103a0a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0103956:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0103958:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010395b:	39 d8                	cmp    %ebx,%eax
f010395d:	0f 8c a2 00 00 00    	jl     f0103a05 <stab_binsearch+0x105>
f0103963:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0103967:	83 ea 0c             	sub    $0xc,%edx
f010396a:	39 f1                	cmp    %esi,%ecx
f010396c:	75 ea                	jne    f0103958 <stab_binsearch+0x58>
f010396e:	e9 99 00 00 00       	jmp    f0103a0c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0103973:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0103976:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0103978:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f010397b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0103982:	eb 2b                	jmp    f01039af <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0103984:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0103987:	76 14                	jbe    f010399d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0103989:	83 e8 01             	sub    $0x1,%eax
f010398c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f010398f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0103992:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0103994:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f010399b:	eb 12                	jmp    f01039af <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f010399d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01039a0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f01039a2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f01039a6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f01039a8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f01039af:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f01039b2:	0f 8e 73 ff ff ff    	jle    f010392b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f01039b8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f01039bc:	75 0f                	jne    f01039cd <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f01039be:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01039c1:	8b 00                	mov    (%eax),%eax
f01039c3:	83 e8 01             	sub    $0x1,%eax
f01039c6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f01039c9:	89 06                	mov    %eax,(%esi)
f01039cb:	eb 57                	jmp    f0103a24 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01039cd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01039d0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f01039d2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01039d5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01039d7:	39 c8                	cmp    %ecx,%eax
f01039d9:	7e 23                	jle    f01039fe <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f01039db:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01039de:	8b 7d ec             	mov    -0x14(%ebp),%edi
f01039e1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f01039e4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f01039e8:	39 f3                	cmp    %esi,%ebx
f01039ea:	74 12                	je     f01039fe <stab_binsearch+0xfe>
		     l--)
f01039ec:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01039ef:	39 c8                	cmp    %ecx,%eax
f01039f1:	7e 0b                	jle    f01039fe <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f01039f3:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f01039f7:	83 ea 0c             	sub    $0xc,%edx
f01039fa:	39 f3                	cmp    %esi,%ebx
f01039fc:	75 ee                	jne    f01039ec <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f01039fe:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0103a01:	89 06                	mov    %eax,(%esi)
f0103a03:	eb 1f                	jmp    f0103a24 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0103a05:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0103a08:	eb a5                	jmp    f01039af <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0103a0a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0103a0c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0103a0f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0103a12:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0103a16:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0103a19:	0f 82 54 ff ff ff    	jb     f0103973 <stab_binsearch+0x73>
f0103a1f:	e9 60 ff ff ff       	jmp    f0103984 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0103a24:	83 c4 14             	add    $0x14,%esp
f0103a27:	5b                   	pop    %ebx
f0103a28:	5e                   	pop    %esi
f0103a29:	5f                   	pop    %edi
f0103a2a:	5d                   	pop    %ebp
f0103a2b:	c3                   	ret    

f0103a2c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0103a2c:	55                   	push   %ebp
f0103a2d:	89 e5                	mov    %esp,%ebp
f0103a2f:	57                   	push   %edi
f0103a30:	56                   	push   %esi
f0103a31:	53                   	push   %ebx
f0103a32:	83 ec 3c             	sub    $0x3c,%esp
f0103a35:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103a38:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0103a3b:	c7 06 17 5e 10 f0    	movl   $0xf0105e17,(%esi)
	info->eip_line = 0;
f0103a41:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0103a48:	c7 46 08 17 5e 10 f0 	movl   $0xf0105e17,0x8(%esi)
	info->eip_fn_namelen = 9;
f0103a4f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0103a56:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0103a59:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0103a60:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0103a66:	77 21                	ja     f0103a89 <debuginfo_eip+0x5d>

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.

		stabs = usd->stabs;
f0103a68:	a1 00 00 20 00       	mov    0x200000,%eax
f0103a6d:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0103a70:	a1 04 00 20 00       	mov    0x200004,%eax
		stabstr = usd->stabstr;
f0103a75:	8b 1d 08 00 20 00    	mov    0x200008,%ebx
f0103a7b:	89 5d d0             	mov    %ebx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0103a7e:	8b 1d 0c 00 20 00    	mov    0x20000c,%ebx
f0103a84:	89 5d cc             	mov    %ebx,-0x34(%ebp)
f0103a87:	eb 1a                	jmp    f0103aa3 <debuginfo_eip+0x77>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0103a89:	c7 45 cc de ff 10 f0 	movl   $0xf010ffde,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0103a90:	c7 45 d0 e1 d6 10 f0 	movl   $0xf010d6e1,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0103a97:	b8 e0 d6 10 f0       	mov    $0xf010d6e0,%eax
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0103a9c:	c7 45 d4 30 60 10 f0 	movl   $0xf0106030,-0x2c(%ebp)
		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0103aa3:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0103aa6:	39 4d d0             	cmp    %ecx,-0x30(%ebp)
f0103aa9:	0f 83 57 01 00 00    	jae    f0103c06 <debuginfo_eip+0x1da>
f0103aaf:	80 79 ff 00          	cmpb   $0x0,-0x1(%ecx)
f0103ab3:	0f 85 54 01 00 00    	jne    f0103c0d <debuginfo_eip+0x1e1>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0103ab9:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0103ac0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0103ac3:	29 d8                	sub    %ebx,%eax
f0103ac5:	c1 f8 02             	sar    $0x2,%eax
f0103ac8:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0103ace:	83 e8 01             	sub    $0x1,%eax
f0103ad1:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0103ad4:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103ad8:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0103adf:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0103ae2:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0103ae5:	89 d8                	mov    %ebx,%eax
f0103ae7:	e8 14 fe ff ff       	call   f0103900 <stab_binsearch>
	if (lfile == 0)
f0103aec:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103aef:	85 c0                	test   %eax,%eax
f0103af1:	0f 84 1d 01 00 00    	je     f0103c14 <debuginfo_eip+0x1e8>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0103af7:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0103afa:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103afd:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0103b00:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103b04:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0103b0b:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0103b0e:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0103b11:	89 d8                	mov    %ebx,%eax
f0103b13:	e8 e8 fd ff ff       	call   f0103900 <stab_binsearch>

	if (lfun <= rfun) {
f0103b18:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0103b1b:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0103b1e:	7f 23                	jg     f0103b43 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0103b20:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0103b23:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0103b26:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0103b29:	8b 10                	mov    (%eax),%edx
f0103b2b:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0103b2e:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0103b31:	39 ca                	cmp    %ecx,%edx
f0103b33:	73 06                	jae    f0103b3b <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0103b35:	03 55 d0             	add    -0x30(%ebp),%edx
f0103b38:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0103b3b:	8b 40 08             	mov    0x8(%eax),%eax
f0103b3e:	89 46 10             	mov    %eax,0x10(%esi)
f0103b41:	eb 06                	jmp    f0103b49 <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0103b43:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0103b46:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0103b49:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0103b50:	00 
f0103b51:	8b 46 08             	mov    0x8(%esi),%eax
f0103b54:	89 04 24             	mov    %eax,(%esp)
f0103b57:	e8 f3 09 00 00       	call   f010454f <strfind>
f0103b5c:	2b 46 08             	sub    0x8(%esi),%eax
f0103b5f:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0103b62:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0103b65:	39 fb                	cmp    %edi,%ebx
f0103b67:	7c 5d                	jl     f0103bc6 <debuginfo_eip+0x19a>
	       && stabs[lline].n_type != N_SOL
f0103b69:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0103b6c:	c1 e0 02             	shl    $0x2,%eax
f0103b6f:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103b72:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0103b75:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0103b78:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0103b7c:	80 fa 84             	cmp    $0x84,%dl
f0103b7f:	74 2d                	je     f0103bae <debuginfo_eip+0x182>
f0103b81:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0103b85:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0103b88:	eb 15                	jmp    f0103b9f <debuginfo_eip+0x173>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0103b8a:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0103b8d:	39 fb                	cmp    %edi,%ebx
f0103b8f:	7c 35                	jl     f0103bc6 <debuginfo_eip+0x19a>
	       && stabs[lline].n_type != N_SOL
f0103b91:	89 c1                	mov    %eax,%ecx
f0103b93:	83 e8 0c             	sub    $0xc,%eax
f0103b96:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0103b9a:	80 fa 84             	cmp    $0x84,%dl
f0103b9d:	74 0f                	je     f0103bae <debuginfo_eip+0x182>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0103b9f:	80 fa 64             	cmp    $0x64,%dl
f0103ba2:	75 e6                	jne    f0103b8a <debuginfo_eip+0x15e>
f0103ba4:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0103ba8:	74 e0                	je     f0103b8a <debuginfo_eip+0x15e>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0103baa:	39 df                	cmp    %ebx,%edi
f0103bac:	7f 18                	jg     f0103bc6 <debuginfo_eip+0x19a>
f0103bae:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0103bb1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0103bb4:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0103bb7:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0103bba:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0103bbd:	39 d0                	cmp    %edx,%eax
f0103bbf:	73 05                	jae    f0103bc6 <debuginfo_eip+0x19a>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0103bc1:	03 45 d0             	add    -0x30(%ebp),%eax
f0103bc4:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0103bc6:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103bc9:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0103bcc:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0103bd1:	39 ca                	cmp    %ecx,%edx
f0103bd3:	7d 60                	jge    f0103c35 <debuginfo_eip+0x209>
		for (lline = lfun + 1;
f0103bd5:	8d 42 01             	lea    0x1(%edx),%eax
f0103bd8:	39 c1                	cmp    %eax,%ecx
f0103bda:	7e 3f                	jle    f0103c1b <debuginfo_eip+0x1ef>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0103bdc:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0103bdf:	c1 e2 02             	shl    $0x2,%edx
f0103be2:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0103be5:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0103bea:	75 36                	jne    f0103c22 <debuginfo_eip+0x1f6>
f0103bec:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0103bf0:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0103bf4:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0103bf7:	39 c1                	cmp    %eax,%ecx
f0103bf9:	7e 2e                	jle    f0103c29 <debuginfo_eip+0x1fd>
f0103bfb:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0103bfe:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0103c02:	74 ec                	je     f0103bf0 <debuginfo_eip+0x1c4>
f0103c04:	eb 2a                	jmp    f0103c30 <debuginfo_eip+0x204>
		// LAB 3: Your code here.
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0103c06:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103c0b:	eb 28                	jmp    f0103c35 <debuginfo_eip+0x209>
f0103c0d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103c12:	eb 21                	jmp    f0103c35 <debuginfo_eip+0x209>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0103c14:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103c19:	eb 1a                	jmp    f0103c35 <debuginfo_eip+0x209>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0103c1b:	b8 00 00 00 00       	mov    $0x0,%eax
f0103c20:	eb 13                	jmp    f0103c35 <debuginfo_eip+0x209>
f0103c22:	b8 00 00 00 00       	mov    $0x0,%eax
f0103c27:	eb 0c                	jmp    f0103c35 <debuginfo_eip+0x209>
f0103c29:	b8 00 00 00 00       	mov    $0x0,%eax
f0103c2e:	eb 05                	jmp    f0103c35 <debuginfo_eip+0x209>
f0103c30:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103c35:	83 c4 3c             	add    $0x3c,%esp
f0103c38:	5b                   	pop    %ebx
f0103c39:	5e                   	pop    %esi
f0103c3a:	5f                   	pop    %edi
f0103c3b:	5d                   	pop    %ebp
f0103c3c:	c3                   	ret    
f0103c3d:	66 90                	xchg   %ax,%ax
f0103c3f:	90                   	nop

f0103c40 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0103c40:	55                   	push   %ebp
f0103c41:	89 e5                	mov    %esp,%ebp
f0103c43:	57                   	push   %edi
f0103c44:	56                   	push   %esi
f0103c45:	53                   	push   %ebx
f0103c46:	83 ec 3c             	sub    $0x3c,%esp
f0103c49:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103c4c:	89 d7                	mov    %edx,%edi
f0103c4e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103c51:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0103c54:	8b 75 0c             	mov    0xc(%ebp),%esi
f0103c57:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0103c5a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0103c5d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103c62:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103c65:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0103c68:	39 f1                	cmp    %esi,%ecx
f0103c6a:	72 14                	jb     f0103c80 <printnum+0x40>
f0103c6c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0103c6f:	76 0f                	jbe    f0103c80 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0103c71:	8b 45 14             	mov    0x14(%ebp),%eax
f0103c74:	8d 70 ff             	lea    -0x1(%eax),%esi
f0103c77:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0103c7a:	85 f6                	test   %esi,%esi
f0103c7c:	7f 60                	jg     f0103cde <printnum+0x9e>
f0103c7e:	eb 72                	jmp    f0103cf2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0103c80:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0103c83:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0103c87:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0103c8a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0103c8d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103c91:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103c95:	8b 44 24 08          	mov    0x8(%esp),%eax
f0103c99:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0103c9d:	89 c3                	mov    %eax,%ebx
f0103c9f:	89 d6                	mov    %edx,%esi
f0103ca1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103ca4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0103ca7:	89 54 24 08          	mov    %edx,0x8(%esp)
f0103cab:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0103caf:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103cb2:	89 04 24             	mov    %eax,(%esp)
f0103cb5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103cb8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103cbc:	e8 ef 0a 00 00       	call   f01047b0 <__udivdi3>
f0103cc1:	89 d9                	mov    %ebx,%ecx
f0103cc3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103cc7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103ccb:	89 04 24             	mov    %eax,(%esp)
f0103cce:	89 54 24 04          	mov    %edx,0x4(%esp)
f0103cd2:	89 fa                	mov    %edi,%edx
f0103cd4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103cd7:	e8 64 ff ff ff       	call   f0103c40 <printnum>
f0103cdc:	eb 14                	jmp    f0103cf2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0103cde:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103ce2:	8b 45 18             	mov    0x18(%ebp),%eax
f0103ce5:	89 04 24             	mov    %eax,(%esp)
f0103ce8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0103cea:	83 ee 01             	sub    $0x1,%esi
f0103ced:	75 ef                	jne    f0103cde <printnum+0x9e>
f0103cef:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0103cf2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103cf6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0103cfa:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103cfd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103d00:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103d04:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103d08:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103d0b:	89 04 24             	mov    %eax,(%esp)
f0103d0e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103d11:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d15:	e8 c6 0b 00 00       	call   f01048e0 <__umoddi3>
f0103d1a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103d1e:	0f be 80 21 5e 10 f0 	movsbl -0xfefa1df(%eax),%eax
f0103d25:	89 04 24             	mov    %eax,(%esp)
f0103d28:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103d2b:	ff d0                	call   *%eax
}
f0103d2d:	83 c4 3c             	add    $0x3c,%esp
f0103d30:	5b                   	pop    %ebx
f0103d31:	5e                   	pop    %esi
f0103d32:	5f                   	pop    %edi
f0103d33:	5d                   	pop    %ebp
f0103d34:	c3                   	ret    

f0103d35 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0103d35:	55                   	push   %ebp
f0103d36:	89 e5                	mov    %esp,%ebp
f0103d38:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0103d3b:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0103d3f:	8b 10                	mov    (%eax),%edx
f0103d41:	3b 50 04             	cmp    0x4(%eax),%edx
f0103d44:	73 0a                	jae    f0103d50 <sprintputch+0x1b>
		*b->buf++ = ch;
f0103d46:	8d 4a 01             	lea    0x1(%edx),%ecx
f0103d49:	89 08                	mov    %ecx,(%eax)
f0103d4b:	8b 45 08             	mov    0x8(%ebp),%eax
f0103d4e:	88 02                	mov    %al,(%edx)
}
f0103d50:	5d                   	pop    %ebp
f0103d51:	c3                   	ret    

f0103d52 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0103d52:	55                   	push   %ebp
f0103d53:	89 e5                	mov    %esp,%ebp
f0103d55:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0103d58:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0103d5b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103d5f:	8b 45 10             	mov    0x10(%ebp),%eax
f0103d62:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103d66:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103d69:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d6d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103d70:	89 04 24             	mov    %eax,(%esp)
f0103d73:	e8 02 00 00 00       	call   f0103d7a <vprintfmt>
	va_end(ap);
}
f0103d78:	c9                   	leave  
f0103d79:	c3                   	ret    

f0103d7a <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0103d7a:	55                   	push   %ebp
f0103d7b:	89 e5                	mov    %esp,%ebp
f0103d7d:	57                   	push   %edi
f0103d7e:	56                   	push   %esi
f0103d7f:	53                   	push   %ebx
f0103d80:	83 ec 3c             	sub    $0x3c,%esp
f0103d83:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0103d86:	89 df                	mov    %ebx,%edi
f0103d88:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0103d8b:	eb 03                	jmp    f0103d90 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0103d8d:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0103d90:	8b 45 10             	mov    0x10(%ebp),%eax
f0103d93:	8d 70 01             	lea    0x1(%eax),%esi
f0103d96:	0f b6 00             	movzbl (%eax),%eax
f0103d99:	83 f8 25             	cmp    $0x25,%eax
f0103d9c:	74 2d                	je     f0103dcb <vprintfmt+0x51>
			if (ch == '\0')
f0103d9e:	85 c0                	test   %eax,%eax
f0103da0:	75 14                	jne    f0103db6 <vprintfmt+0x3c>
f0103da2:	e9 6b 04 00 00       	jmp    f0104212 <vprintfmt+0x498>
f0103da7:	85 c0                	test   %eax,%eax
f0103da9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0103db0:	0f 84 5c 04 00 00    	je     f0104212 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0103db6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103dba:	89 04 24             	mov    %eax,(%esp)
f0103dbd:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0103dbf:	83 c6 01             	add    $0x1,%esi
f0103dc2:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f0103dc6:	83 f8 25             	cmp    $0x25,%eax
f0103dc9:	75 dc                	jne    f0103da7 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0103dcb:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0103dcf:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0103dd6:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0103ddd:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0103de4:	b9 00 00 00 00       	mov    $0x0,%ecx
f0103de9:	eb 1f                	jmp    f0103e0a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103deb:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0103dee:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0103df2:	eb 16                	jmp    f0103e0a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103df4:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0103df7:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0103dfb:	eb 0d                	jmp    f0103e0a <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0103dfd:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0103e00:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0103e03:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e0a:	8d 46 01             	lea    0x1(%esi),%eax
f0103e0d:	89 45 10             	mov    %eax,0x10(%ebp)
f0103e10:	0f b6 06             	movzbl (%esi),%eax
f0103e13:	0f b6 d0             	movzbl %al,%edx
f0103e16:	83 e8 23             	sub    $0x23,%eax
f0103e19:	3c 55                	cmp    $0x55,%al
f0103e1b:	0f 87 c4 03 00 00    	ja     f01041e5 <vprintfmt+0x46b>
f0103e21:	0f b6 c0             	movzbl %al,%eax
f0103e24:	ff 24 85 ac 5e 10 f0 	jmp    *-0xfefa154(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0103e2b:	8d 42 d0             	lea    -0x30(%edx),%eax
f0103e2e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0103e31:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0103e35:	8d 50 d0             	lea    -0x30(%eax),%edx
f0103e38:	83 fa 09             	cmp    $0x9,%edx
f0103e3b:	77 63                	ja     f0103ea0 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e3d:	8b 75 10             	mov    0x10(%ebp),%esi
f0103e40:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f0103e43:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0103e46:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0103e49:	8d 14 92             	lea    (%edx,%edx,4),%edx
f0103e4c:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f0103e50:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0103e53:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0103e56:	83 f9 09             	cmp    $0x9,%ecx
f0103e59:	76 eb                	jbe    f0103e46 <vprintfmt+0xcc>
f0103e5b:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0103e5e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0103e61:	eb 40                	jmp    f0103ea3 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0103e63:	8b 45 14             	mov    0x14(%ebp),%eax
f0103e66:	8b 00                	mov    (%eax),%eax
f0103e68:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0103e6b:	8b 45 14             	mov    0x14(%ebp),%eax
f0103e6e:	8d 40 04             	lea    0x4(%eax),%eax
f0103e71:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e74:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0103e77:	eb 2a                	jmp    f0103ea3 <vprintfmt+0x129>
f0103e79:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0103e7c:	85 d2                	test   %edx,%edx
f0103e7e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103e83:	0f 49 c2             	cmovns %edx,%eax
f0103e86:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103e89:	8b 75 10             	mov    0x10(%ebp),%esi
f0103e8c:	e9 79 ff ff ff       	jmp    f0103e0a <vprintfmt+0x90>
f0103e91:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0103e94:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0103e9b:	e9 6a ff ff ff       	jmp    f0103e0a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103ea0:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0103ea3:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0103ea7:	0f 89 5d ff ff ff    	jns    f0103e0a <vprintfmt+0x90>
f0103ead:	e9 4b ff ff ff       	jmp    f0103dfd <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0103eb2:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103eb5:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0103eb8:	e9 4d ff ff ff       	jmp    f0103e0a <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0103ebd:	8b 45 14             	mov    0x14(%ebp),%eax
f0103ec0:	8d 70 04             	lea    0x4(%eax),%esi
f0103ec3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103ec7:	8b 00                	mov    (%eax),%eax
f0103ec9:	89 04 24             	mov    %eax,(%esp)
f0103ecc:	ff d7                	call   *%edi
f0103ece:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0103ed1:	e9 ba fe ff ff       	jmp    f0103d90 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0103ed6:	8b 45 14             	mov    0x14(%ebp),%eax
f0103ed9:	8d 70 04             	lea    0x4(%eax),%esi
f0103edc:	8b 00                	mov    (%eax),%eax
f0103ede:	99                   	cltd   
f0103edf:	31 d0                	xor    %edx,%eax
f0103ee1:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0103ee3:	83 f8 06             	cmp    $0x6,%eax
f0103ee6:	7f 0b                	jg     f0103ef3 <vprintfmt+0x179>
f0103ee8:	8b 14 85 04 60 10 f0 	mov    -0xfef9ffc(,%eax,4),%edx
f0103eef:	85 d2                	test   %edx,%edx
f0103ef1:	75 20                	jne    f0103f13 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f0103ef3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ef7:	c7 44 24 08 39 5e 10 	movl   $0xf0105e39,0x8(%esp)
f0103efe:	f0 
f0103eff:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103f03:	89 3c 24             	mov    %edi,(%esp)
f0103f06:	e8 47 fe ff ff       	call   f0103d52 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f0103f0b:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f0103f0e:	e9 7d fe ff ff       	jmp    f0103d90 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f0103f13:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103f17:	c7 44 24 08 e1 56 10 	movl   $0xf01056e1,0x8(%esp)
f0103f1e:	f0 
f0103f1f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103f23:	89 3c 24             	mov    %edi,(%esp)
f0103f26:	e8 27 fe ff ff       	call   f0103d52 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f0103f2b:	89 75 14             	mov    %esi,0x14(%ebp)
f0103f2e:	e9 5d fe ff ff       	jmp    f0103d90 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0103f33:	8b 45 14             	mov    0x14(%ebp),%eax
f0103f36:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0103f39:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0103f3c:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f0103f40:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0103f42:	85 c0                	test   %eax,%eax
f0103f44:	b9 32 5e 10 f0       	mov    $0xf0105e32,%ecx
f0103f49:	0f 45 c8             	cmovne %eax,%ecx
f0103f4c:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0103f4f:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0103f53:	74 04                	je     f0103f59 <vprintfmt+0x1df>
f0103f55:	85 f6                	test   %esi,%esi
f0103f57:	7f 19                	jg     f0103f72 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103f59:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103f5c:	8d 70 01             	lea    0x1(%eax),%esi
f0103f5f:	0f b6 10             	movzbl (%eax),%edx
f0103f62:	0f be c2             	movsbl %dl,%eax
f0103f65:	85 c0                	test   %eax,%eax
f0103f67:	0f 85 9a 00 00 00    	jne    f0104007 <vprintfmt+0x28d>
f0103f6d:	e9 87 00 00 00       	jmp    f0103ff9 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103f72:	89 54 24 04          	mov    %edx,0x4(%esp)
f0103f76:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103f79:	89 04 24             	mov    %eax,(%esp)
f0103f7c:	e8 11 04 00 00       	call   f0104392 <strnlen>
f0103f81:	29 c6                	sub    %eax,%esi
f0103f83:	89 f0                	mov    %esi,%eax
f0103f85:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0103f88:	85 f6                	test   %esi,%esi
f0103f8a:	7e cd                	jle    f0103f59 <vprintfmt+0x1df>
					putch(padc, putdat);
f0103f8c:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0103f90:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0103f93:	89 c3                	mov    %eax,%ebx
f0103f95:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103f98:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103f9c:	89 34 24             	mov    %esi,(%esp)
f0103f9f:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0103fa1:	83 eb 01             	sub    $0x1,%ebx
f0103fa4:	75 ef                	jne    f0103f95 <vprintfmt+0x21b>
f0103fa6:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0103fa9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0103fac:	eb ab                	jmp    f0103f59 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f0103fae:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0103fb2:	74 1e                	je     f0103fd2 <vprintfmt+0x258>
f0103fb4:	0f be d2             	movsbl %dl,%edx
f0103fb7:	83 ea 20             	sub    $0x20,%edx
f0103fba:	83 fa 5e             	cmp    $0x5e,%edx
f0103fbd:	76 13                	jbe    f0103fd2 <vprintfmt+0x258>
					putch('?', putdat);
f0103fbf:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103fc2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103fc6:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f0103fcd:	ff 55 08             	call   *0x8(%ebp)
f0103fd0:	eb 0d                	jmp    f0103fdf <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0103fd2:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0103fd5:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0103fd9:	89 04 24             	mov    %eax,(%esp)
f0103fdc:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0103fdf:	83 eb 01             	sub    $0x1,%ebx
f0103fe2:	83 c6 01             	add    $0x1,%esi
f0103fe5:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0103fe9:	0f be c2             	movsbl %dl,%eax
f0103fec:	85 c0                	test   %eax,%eax
f0103fee:	75 23                	jne    f0104013 <vprintfmt+0x299>
f0103ff0:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0103ff3:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103ff6:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0103ff9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0103ffc:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0104000:	7f 25                	jg     f0104027 <vprintfmt+0x2ad>
f0104002:	e9 89 fd ff ff       	jmp    f0103d90 <vprintfmt+0x16>
f0104007:	89 7d 08             	mov    %edi,0x8(%ebp)
f010400a:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010400d:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0104010:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0104013:	85 ff                	test   %edi,%edi
f0104015:	78 97                	js     f0103fae <vprintfmt+0x234>
f0104017:	83 ef 01             	sub    $0x1,%edi
f010401a:	79 92                	jns    f0103fae <vprintfmt+0x234>
f010401c:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f010401f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104022:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104025:	eb d2                	jmp    f0103ff9 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0104027:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010402b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0104032:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0104034:	83 ee 01             	sub    $0x1,%esi
f0104037:	75 ee                	jne    f0104027 <vprintfmt+0x2ad>
f0104039:	e9 52 fd ff ff       	jmp    f0103d90 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010403e:	83 f9 01             	cmp    $0x1,%ecx
f0104041:	7e 19                	jle    f010405c <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f0104043:	8b 45 14             	mov    0x14(%ebp),%eax
f0104046:	8b 50 04             	mov    0x4(%eax),%edx
f0104049:	8b 00                	mov    (%eax),%eax
f010404b:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010404e:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0104051:	8b 45 14             	mov    0x14(%ebp),%eax
f0104054:	8d 40 08             	lea    0x8(%eax),%eax
f0104057:	89 45 14             	mov    %eax,0x14(%ebp)
f010405a:	eb 38                	jmp    f0104094 <vprintfmt+0x31a>
	else if (lflag)
f010405c:	85 c9                	test   %ecx,%ecx
f010405e:	74 1b                	je     f010407b <vprintfmt+0x301>
		return va_arg(*ap, long);
f0104060:	8b 45 14             	mov    0x14(%ebp),%eax
f0104063:	8b 30                	mov    (%eax),%esi
f0104065:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0104068:	89 f0                	mov    %esi,%eax
f010406a:	c1 f8 1f             	sar    $0x1f,%eax
f010406d:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0104070:	8b 45 14             	mov    0x14(%ebp),%eax
f0104073:	8d 40 04             	lea    0x4(%eax),%eax
f0104076:	89 45 14             	mov    %eax,0x14(%ebp)
f0104079:	eb 19                	jmp    f0104094 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f010407b:	8b 45 14             	mov    0x14(%ebp),%eax
f010407e:	8b 30                	mov    (%eax),%esi
f0104080:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0104083:	89 f0                	mov    %esi,%eax
f0104085:	c1 f8 1f             	sar    $0x1f,%eax
f0104088:	89 45 dc             	mov    %eax,-0x24(%ebp)
f010408b:	8b 45 14             	mov    0x14(%ebp),%eax
f010408e:	8d 40 04             	lea    0x4(%eax),%eax
f0104091:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0104094:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0104097:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010409a:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f010409f:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f01040a3:	0f 89 06 01 00 00    	jns    f01041af <vprintfmt+0x435>
				putch('-', putdat);
f01040a9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01040ad:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f01040b4:	ff d7                	call   *%edi
				num = -(long long) num;
f01040b6:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01040b9:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01040bc:	f7 da                	neg    %edx
f01040be:	83 d1 00             	adc    $0x0,%ecx
f01040c1:	f7 d9                	neg    %ecx
			}
			base = 10;
f01040c3:	b8 0a 00 00 00       	mov    $0xa,%eax
f01040c8:	e9 e2 00 00 00       	jmp    f01041af <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01040cd:	83 f9 01             	cmp    $0x1,%ecx
f01040d0:	7e 10                	jle    f01040e2 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f01040d2:	8b 45 14             	mov    0x14(%ebp),%eax
f01040d5:	8b 10                	mov    (%eax),%edx
f01040d7:	8b 48 04             	mov    0x4(%eax),%ecx
f01040da:	8d 40 08             	lea    0x8(%eax),%eax
f01040dd:	89 45 14             	mov    %eax,0x14(%ebp)
f01040e0:	eb 26                	jmp    f0104108 <vprintfmt+0x38e>
	else if (lflag)
f01040e2:	85 c9                	test   %ecx,%ecx
f01040e4:	74 12                	je     f01040f8 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f01040e6:	8b 45 14             	mov    0x14(%ebp),%eax
f01040e9:	8b 10                	mov    (%eax),%edx
f01040eb:	b9 00 00 00 00       	mov    $0x0,%ecx
f01040f0:	8d 40 04             	lea    0x4(%eax),%eax
f01040f3:	89 45 14             	mov    %eax,0x14(%ebp)
f01040f6:	eb 10                	jmp    f0104108 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f01040f8:	8b 45 14             	mov    0x14(%ebp),%eax
f01040fb:	8b 10                	mov    (%eax),%edx
f01040fd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0104102:	8d 40 04             	lea    0x4(%eax),%eax
f0104105:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f0104108:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f010410d:	e9 9d 00 00 00       	jmp    f01041af <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f0104112:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104116:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010411d:	ff d7                	call   *%edi
			putch('X', putdat);
f010411f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104123:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010412a:	ff d7                	call   *%edi
			putch('X', putdat);
f010412c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104130:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f0104137:	ff d7                	call   *%edi
			break;
f0104139:	e9 52 fc ff ff       	jmp    f0103d90 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f010413e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104142:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0104149:	ff d7                	call   *%edi
			putch('x', putdat);
f010414b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010414f:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0104156:	ff d7                	call   *%edi
			num = (unsigned long long)
f0104158:	8b 45 14             	mov    0x14(%ebp),%eax
f010415b:	8b 10                	mov    (%eax),%edx
f010415d:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f0104162:	8d 40 04             	lea    0x4(%eax),%eax
f0104165:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0104168:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f010416d:	eb 40                	jmp    f01041af <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010416f:	83 f9 01             	cmp    $0x1,%ecx
f0104172:	7e 10                	jle    f0104184 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f0104174:	8b 45 14             	mov    0x14(%ebp),%eax
f0104177:	8b 10                	mov    (%eax),%edx
f0104179:	8b 48 04             	mov    0x4(%eax),%ecx
f010417c:	8d 40 08             	lea    0x8(%eax),%eax
f010417f:	89 45 14             	mov    %eax,0x14(%ebp)
f0104182:	eb 26                	jmp    f01041aa <vprintfmt+0x430>
	else if (lflag)
f0104184:	85 c9                	test   %ecx,%ecx
f0104186:	74 12                	je     f010419a <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f0104188:	8b 45 14             	mov    0x14(%ebp),%eax
f010418b:	8b 10                	mov    (%eax),%edx
f010418d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0104192:	8d 40 04             	lea    0x4(%eax),%eax
f0104195:	89 45 14             	mov    %eax,0x14(%ebp)
f0104198:	eb 10                	jmp    f01041aa <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f010419a:	8b 45 14             	mov    0x14(%ebp),%eax
f010419d:	8b 10                	mov    (%eax),%edx
f010419f:	b9 00 00 00 00       	mov    $0x0,%ecx
f01041a4:	8d 40 04             	lea    0x4(%eax),%eax
f01041a7:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f01041aa:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f01041af:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01041b3:	89 74 24 10          	mov    %esi,0x10(%esp)
f01041b7:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01041ba:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01041be:	89 44 24 08          	mov    %eax,0x8(%esp)
f01041c2:	89 14 24             	mov    %edx,(%esp)
f01041c5:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01041c9:	89 da                	mov    %ebx,%edx
f01041cb:	89 f8                	mov    %edi,%eax
f01041cd:	e8 6e fa ff ff       	call   f0103c40 <printnum>
			break;
f01041d2:	e9 b9 fb ff ff       	jmp    f0103d90 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f01041d7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01041db:	89 14 24             	mov    %edx,(%esp)
f01041de:	ff d7                	call   *%edi
			break;
f01041e0:	e9 ab fb ff ff       	jmp    f0103d90 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01041e5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01041e9:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01041f0:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f01041f2:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f01041f6:	0f 84 91 fb ff ff    	je     f0103d8d <vprintfmt+0x13>
f01041fc:	89 75 10             	mov    %esi,0x10(%ebp)
f01041ff:	89 f0                	mov    %esi,%eax
f0104201:	83 e8 01             	sub    $0x1,%eax
f0104204:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f0104208:	75 f7                	jne    f0104201 <vprintfmt+0x487>
f010420a:	89 45 10             	mov    %eax,0x10(%ebp)
f010420d:	e9 7e fb ff ff       	jmp    f0103d90 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f0104212:	83 c4 3c             	add    $0x3c,%esp
f0104215:	5b                   	pop    %ebx
f0104216:	5e                   	pop    %esi
f0104217:	5f                   	pop    %edi
f0104218:	5d                   	pop    %ebp
f0104219:	c3                   	ret    

f010421a <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f010421a:	55                   	push   %ebp
f010421b:	89 e5                	mov    %esp,%ebp
f010421d:	83 ec 28             	sub    $0x28,%esp
f0104220:	8b 45 08             	mov    0x8(%ebp),%eax
f0104223:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0104226:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104229:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010422d:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0104230:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0104237:	85 c0                	test   %eax,%eax
f0104239:	74 30                	je     f010426b <vsnprintf+0x51>
f010423b:	85 d2                	test   %edx,%edx
f010423d:	7e 2c                	jle    f010426b <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010423f:	8b 45 14             	mov    0x14(%ebp),%eax
f0104242:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104246:	8b 45 10             	mov    0x10(%ebp),%eax
f0104249:	89 44 24 08          	mov    %eax,0x8(%esp)
f010424d:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0104250:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104254:	c7 04 24 35 3d 10 f0 	movl   $0xf0103d35,(%esp)
f010425b:	e8 1a fb ff ff       	call   f0103d7a <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0104260:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0104263:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0104266:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104269:	eb 05                	jmp    f0104270 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f010426b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0104270:	c9                   	leave  
f0104271:	c3                   	ret    

f0104272 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0104272:	55                   	push   %ebp
f0104273:	89 e5                	mov    %esp,%ebp
f0104275:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0104278:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f010427b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010427f:	8b 45 10             	mov    0x10(%ebp),%eax
f0104282:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104286:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104289:	89 44 24 04          	mov    %eax,0x4(%esp)
f010428d:	8b 45 08             	mov    0x8(%ebp),%eax
f0104290:	89 04 24             	mov    %eax,(%esp)
f0104293:	e8 82 ff ff ff       	call   f010421a <vsnprintf>
	va_end(ap);

	return rc;
}
f0104298:	c9                   	leave  
f0104299:	c3                   	ret    
f010429a:	66 90                	xchg   %ax,%ax
f010429c:	66 90                	xchg   %ax,%ax
f010429e:	66 90                	xchg   %ax,%ax

f01042a0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01042a0:	55                   	push   %ebp
f01042a1:	89 e5                	mov    %esp,%ebp
f01042a3:	57                   	push   %edi
f01042a4:	56                   	push   %esi
f01042a5:	53                   	push   %ebx
f01042a6:	83 ec 1c             	sub    $0x1c,%esp
f01042a9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01042ac:	85 c0                	test   %eax,%eax
f01042ae:	74 10                	je     f01042c0 <readline+0x20>
		cprintf("%s", prompt);
f01042b0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042b4:	c7 04 24 e1 56 10 f0 	movl   $0xf01056e1,(%esp)
f01042bb:	e8 14 f2 ff ff       	call   f01034d4 <cprintf>

	i = 0;
	echoing = iscons(0);
f01042c0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01042c7:	e8 a9 c3 ff ff       	call   f0100675 <iscons>
f01042cc:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01042ce:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f01042d3:	e8 8c c3 ff ff       	call   f0100664 <getchar>
f01042d8:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f01042da:	85 c0                	test   %eax,%eax
f01042dc:	79 17                	jns    f01042f5 <readline+0x55>
			cprintf("read error: %e\n", c);
f01042de:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042e2:	c7 04 24 20 60 10 f0 	movl   $0xf0106020,(%esp)
f01042e9:	e8 e6 f1 ff ff       	call   f01034d4 <cprintf>
			return NULL;
f01042ee:	b8 00 00 00 00       	mov    $0x0,%eax
f01042f3:	eb 6d                	jmp    f0104362 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01042f5:	83 f8 7f             	cmp    $0x7f,%eax
f01042f8:	74 05                	je     f01042ff <readline+0x5f>
f01042fa:	83 f8 08             	cmp    $0x8,%eax
f01042fd:	75 19                	jne    f0104318 <readline+0x78>
f01042ff:	85 f6                	test   %esi,%esi
f0104301:	7e 15                	jle    f0104318 <readline+0x78>
			if (echoing)
f0104303:	85 ff                	test   %edi,%edi
f0104305:	74 0c                	je     f0104313 <readline+0x73>
				cputchar('\b');
f0104307:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010430e:	e8 41 c3 ff ff       	call   f0100654 <cputchar>
			i--;
f0104313:	83 ee 01             	sub    $0x1,%esi
f0104316:	eb bb                	jmp    f01042d3 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0104318:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010431e:	7f 1c                	jg     f010433c <readline+0x9c>
f0104320:	83 fb 1f             	cmp    $0x1f,%ebx
f0104323:	7e 17                	jle    f010433c <readline+0x9c>
			if (echoing)
f0104325:	85 ff                	test   %edi,%edi
f0104327:	74 08                	je     f0104331 <readline+0x91>
				cputchar(c);
f0104329:	89 1c 24             	mov    %ebx,(%esp)
f010432c:	e8 23 c3 ff ff       	call   f0100654 <cputchar>
			buf[i++] = c;
f0104331:	88 9e 80 ca 17 f0    	mov    %bl,-0xfe83580(%esi)
f0104337:	8d 76 01             	lea    0x1(%esi),%esi
f010433a:	eb 97                	jmp    f01042d3 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010433c:	83 fb 0d             	cmp    $0xd,%ebx
f010433f:	74 05                	je     f0104346 <readline+0xa6>
f0104341:	83 fb 0a             	cmp    $0xa,%ebx
f0104344:	75 8d                	jne    f01042d3 <readline+0x33>
			if (echoing)
f0104346:	85 ff                	test   %edi,%edi
f0104348:	74 0c                	je     f0104356 <readline+0xb6>
				cputchar('\n');
f010434a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0104351:	e8 fe c2 ff ff       	call   f0100654 <cputchar>
			buf[i] = 0;
f0104356:	c6 86 80 ca 17 f0 00 	movb   $0x0,-0xfe83580(%esi)
			return buf;
f010435d:	b8 80 ca 17 f0       	mov    $0xf017ca80,%eax
		}
	}
}
f0104362:	83 c4 1c             	add    $0x1c,%esp
f0104365:	5b                   	pop    %ebx
f0104366:	5e                   	pop    %esi
f0104367:	5f                   	pop    %edi
f0104368:	5d                   	pop    %ebp
f0104369:	c3                   	ret    
f010436a:	66 90                	xchg   %ax,%ax
f010436c:	66 90                	xchg   %ax,%ax
f010436e:	66 90                	xchg   %ax,%ax

f0104370 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0104370:	55                   	push   %ebp
f0104371:	89 e5                	mov    %esp,%ebp
f0104373:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0104376:	80 3a 00             	cmpb   $0x0,(%edx)
f0104379:	74 10                	je     f010438b <strlen+0x1b>
f010437b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0104380:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0104383:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0104387:	75 f7                	jne    f0104380 <strlen+0x10>
f0104389:	eb 05                	jmp    f0104390 <strlen+0x20>
f010438b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0104390:	5d                   	pop    %ebp
f0104391:	c3                   	ret    

f0104392 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0104392:	55                   	push   %ebp
f0104393:	89 e5                	mov    %esp,%ebp
f0104395:	53                   	push   %ebx
f0104396:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104399:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010439c:	85 c9                	test   %ecx,%ecx
f010439e:	74 1c                	je     f01043bc <strnlen+0x2a>
f01043a0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01043a3:	74 1e                	je     f01043c3 <strnlen+0x31>
f01043a5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01043aa:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01043ac:	39 ca                	cmp    %ecx,%edx
f01043ae:	74 18                	je     f01043c8 <strnlen+0x36>
f01043b0:	83 c2 01             	add    $0x1,%edx
f01043b3:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f01043b8:	75 f0                	jne    f01043aa <strnlen+0x18>
f01043ba:	eb 0c                	jmp    f01043c8 <strnlen+0x36>
f01043bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01043c1:	eb 05                	jmp    f01043c8 <strnlen+0x36>
f01043c3:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01043c8:	5b                   	pop    %ebx
f01043c9:	5d                   	pop    %ebp
f01043ca:	c3                   	ret    

f01043cb <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01043cb:	55                   	push   %ebp
f01043cc:	89 e5                	mov    %esp,%ebp
f01043ce:	53                   	push   %ebx
f01043cf:	8b 45 08             	mov    0x8(%ebp),%eax
f01043d2:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01043d5:	89 c2                	mov    %eax,%edx
f01043d7:	83 c2 01             	add    $0x1,%edx
f01043da:	83 c1 01             	add    $0x1,%ecx
f01043dd:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01043e1:	88 5a ff             	mov    %bl,-0x1(%edx)
f01043e4:	84 db                	test   %bl,%bl
f01043e6:	75 ef                	jne    f01043d7 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01043e8:	5b                   	pop    %ebx
f01043e9:	5d                   	pop    %ebp
f01043ea:	c3                   	ret    

f01043eb <strcat>:

char *
strcat(char *dst, const char *src)
{
f01043eb:	55                   	push   %ebp
f01043ec:	89 e5                	mov    %esp,%ebp
f01043ee:	53                   	push   %ebx
f01043ef:	83 ec 08             	sub    $0x8,%esp
f01043f2:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01043f5:	89 1c 24             	mov    %ebx,(%esp)
f01043f8:	e8 73 ff ff ff       	call   f0104370 <strlen>
	strcpy(dst + len, src);
f01043fd:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104400:	89 54 24 04          	mov    %edx,0x4(%esp)
f0104404:	01 d8                	add    %ebx,%eax
f0104406:	89 04 24             	mov    %eax,(%esp)
f0104409:	e8 bd ff ff ff       	call   f01043cb <strcpy>
	return dst;
}
f010440e:	89 d8                	mov    %ebx,%eax
f0104410:	83 c4 08             	add    $0x8,%esp
f0104413:	5b                   	pop    %ebx
f0104414:	5d                   	pop    %ebp
f0104415:	c3                   	ret    

f0104416 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0104416:	55                   	push   %ebp
f0104417:	89 e5                	mov    %esp,%ebp
f0104419:	56                   	push   %esi
f010441a:	53                   	push   %ebx
f010441b:	8b 75 08             	mov    0x8(%ebp),%esi
f010441e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0104421:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0104424:	85 db                	test   %ebx,%ebx
f0104426:	74 17                	je     f010443f <strncpy+0x29>
f0104428:	01 f3                	add    %esi,%ebx
f010442a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010442c:	83 c1 01             	add    $0x1,%ecx
f010442f:	0f b6 02             	movzbl (%edx),%eax
f0104432:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0104435:	80 3a 01             	cmpb   $0x1,(%edx)
f0104438:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010443b:	39 d9                	cmp    %ebx,%ecx
f010443d:	75 ed                	jne    f010442c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010443f:	89 f0                	mov    %esi,%eax
f0104441:	5b                   	pop    %ebx
f0104442:	5e                   	pop    %esi
f0104443:	5d                   	pop    %ebp
f0104444:	c3                   	ret    

f0104445 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0104445:	55                   	push   %ebp
f0104446:	89 e5                	mov    %esp,%ebp
f0104448:	57                   	push   %edi
f0104449:	56                   	push   %esi
f010444a:	53                   	push   %ebx
f010444b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010444e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104451:	8b 75 10             	mov    0x10(%ebp),%esi
f0104454:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0104456:	85 f6                	test   %esi,%esi
f0104458:	74 34                	je     f010448e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010445a:	83 fe 01             	cmp    $0x1,%esi
f010445d:	74 26                	je     f0104485 <strlcpy+0x40>
f010445f:	0f b6 0b             	movzbl (%ebx),%ecx
f0104462:	84 c9                	test   %cl,%cl
f0104464:	74 23                	je     f0104489 <strlcpy+0x44>
f0104466:	83 ee 02             	sub    $0x2,%esi
f0104469:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f010446e:	83 c0 01             	add    $0x1,%eax
f0104471:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0104474:	39 f2                	cmp    %esi,%edx
f0104476:	74 13                	je     f010448b <strlcpy+0x46>
f0104478:	83 c2 01             	add    $0x1,%edx
f010447b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f010447f:	84 c9                	test   %cl,%cl
f0104481:	75 eb                	jne    f010446e <strlcpy+0x29>
f0104483:	eb 06                	jmp    f010448b <strlcpy+0x46>
f0104485:	89 f8                	mov    %edi,%eax
f0104487:	eb 02                	jmp    f010448b <strlcpy+0x46>
f0104489:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f010448b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f010448e:	29 f8                	sub    %edi,%eax
}
f0104490:	5b                   	pop    %ebx
f0104491:	5e                   	pop    %esi
f0104492:	5f                   	pop    %edi
f0104493:	5d                   	pop    %ebp
f0104494:	c3                   	ret    

f0104495 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0104495:	55                   	push   %ebp
f0104496:	89 e5                	mov    %esp,%ebp
f0104498:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010449b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f010449e:	0f b6 01             	movzbl (%ecx),%eax
f01044a1:	84 c0                	test   %al,%al
f01044a3:	74 15                	je     f01044ba <strcmp+0x25>
f01044a5:	3a 02                	cmp    (%edx),%al
f01044a7:	75 11                	jne    f01044ba <strcmp+0x25>
		p++, q++;
f01044a9:	83 c1 01             	add    $0x1,%ecx
f01044ac:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01044af:	0f b6 01             	movzbl (%ecx),%eax
f01044b2:	84 c0                	test   %al,%al
f01044b4:	74 04                	je     f01044ba <strcmp+0x25>
f01044b6:	3a 02                	cmp    (%edx),%al
f01044b8:	74 ef                	je     f01044a9 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01044ba:	0f b6 c0             	movzbl %al,%eax
f01044bd:	0f b6 12             	movzbl (%edx),%edx
f01044c0:	29 d0                	sub    %edx,%eax
}
f01044c2:	5d                   	pop    %ebp
f01044c3:	c3                   	ret    

f01044c4 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01044c4:	55                   	push   %ebp
f01044c5:	89 e5                	mov    %esp,%ebp
f01044c7:	56                   	push   %esi
f01044c8:	53                   	push   %ebx
f01044c9:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01044cc:	8b 55 0c             	mov    0xc(%ebp),%edx
f01044cf:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f01044d2:	85 f6                	test   %esi,%esi
f01044d4:	74 29                	je     f01044ff <strncmp+0x3b>
f01044d6:	0f b6 03             	movzbl (%ebx),%eax
f01044d9:	84 c0                	test   %al,%al
f01044db:	74 30                	je     f010450d <strncmp+0x49>
f01044dd:	3a 02                	cmp    (%edx),%al
f01044df:	75 2c                	jne    f010450d <strncmp+0x49>
f01044e1:	8d 43 01             	lea    0x1(%ebx),%eax
f01044e4:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f01044e6:	89 c3                	mov    %eax,%ebx
f01044e8:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f01044eb:	39 f0                	cmp    %esi,%eax
f01044ed:	74 17                	je     f0104506 <strncmp+0x42>
f01044ef:	0f b6 08             	movzbl (%eax),%ecx
f01044f2:	84 c9                	test   %cl,%cl
f01044f4:	74 17                	je     f010450d <strncmp+0x49>
f01044f6:	83 c0 01             	add    $0x1,%eax
f01044f9:	3a 0a                	cmp    (%edx),%cl
f01044fb:	74 e9                	je     f01044e6 <strncmp+0x22>
f01044fd:	eb 0e                	jmp    f010450d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f01044ff:	b8 00 00 00 00       	mov    $0x0,%eax
f0104504:	eb 0f                	jmp    f0104515 <strncmp+0x51>
f0104506:	b8 00 00 00 00       	mov    $0x0,%eax
f010450b:	eb 08                	jmp    f0104515 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010450d:	0f b6 03             	movzbl (%ebx),%eax
f0104510:	0f b6 12             	movzbl (%edx),%edx
f0104513:	29 d0                	sub    %edx,%eax
}
f0104515:	5b                   	pop    %ebx
f0104516:	5e                   	pop    %esi
f0104517:	5d                   	pop    %ebp
f0104518:	c3                   	ret    

f0104519 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0104519:	55                   	push   %ebp
f010451a:	89 e5                	mov    %esp,%ebp
f010451c:	53                   	push   %ebx
f010451d:	8b 45 08             	mov    0x8(%ebp),%eax
f0104520:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104523:	0f b6 18             	movzbl (%eax),%ebx
f0104526:	84 db                	test   %bl,%bl
f0104528:	74 1d                	je     f0104547 <strchr+0x2e>
f010452a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010452c:	38 d3                	cmp    %dl,%bl
f010452e:	75 06                	jne    f0104536 <strchr+0x1d>
f0104530:	eb 1a                	jmp    f010454c <strchr+0x33>
f0104532:	38 ca                	cmp    %cl,%dl
f0104534:	74 16                	je     f010454c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0104536:	83 c0 01             	add    $0x1,%eax
f0104539:	0f b6 10             	movzbl (%eax),%edx
f010453c:	84 d2                	test   %dl,%dl
f010453e:	75 f2                	jne    f0104532 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0104540:	b8 00 00 00 00       	mov    $0x0,%eax
f0104545:	eb 05                	jmp    f010454c <strchr+0x33>
f0104547:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010454c:	5b                   	pop    %ebx
f010454d:	5d                   	pop    %ebp
f010454e:	c3                   	ret    

f010454f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010454f:	55                   	push   %ebp
f0104550:	89 e5                	mov    %esp,%ebp
f0104552:	53                   	push   %ebx
f0104553:	8b 45 08             	mov    0x8(%ebp),%eax
f0104556:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0104559:	0f b6 18             	movzbl (%eax),%ebx
f010455c:	84 db                	test   %bl,%bl
f010455e:	74 16                	je     f0104576 <strfind+0x27>
f0104560:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0104562:	38 d3                	cmp    %dl,%bl
f0104564:	75 06                	jne    f010456c <strfind+0x1d>
f0104566:	eb 0e                	jmp    f0104576 <strfind+0x27>
f0104568:	38 ca                	cmp    %cl,%dl
f010456a:	74 0a                	je     f0104576 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010456c:	83 c0 01             	add    $0x1,%eax
f010456f:	0f b6 10             	movzbl (%eax),%edx
f0104572:	84 d2                	test   %dl,%dl
f0104574:	75 f2                	jne    f0104568 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0104576:	5b                   	pop    %ebx
f0104577:	5d                   	pop    %ebp
f0104578:	c3                   	ret    

f0104579 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0104579:	55                   	push   %ebp
f010457a:	89 e5                	mov    %esp,%ebp
f010457c:	57                   	push   %edi
f010457d:	56                   	push   %esi
f010457e:	53                   	push   %ebx
f010457f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104582:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0104585:	85 c9                	test   %ecx,%ecx
f0104587:	74 36                	je     f01045bf <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0104589:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010458f:	75 28                	jne    f01045b9 <memset+0x40>
f0104591:	f6 c1 03             	test   $0x3,%cl
f0104594:	75 23                	jne    f01045b9 <memset+0x40>
		c &= 0xFF;
f0104596:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f010459a:	89 d3                	mov    %edx,%ebx
f010459c:	c1 e3 08             	shl    $0x8,%ebx
f010459f:	89 d6                	mov    %edx,%esi
f01045a1:	c1 e6 18             	shl    $0x18,%esi
f01045a4:	89 d0                	mov    %edx,%eax
f01045a6:	c1 e0 10             	shl    $0x10,%eax
f01045a9:	09 f0                	or     %esi,%eax
f01045ab:	09 c2                	or     %eax,%edx
f01045ad:	89 d0                	mov    %edx,%eax
f01045af:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01045b1:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01045b4:	fc                   	cld    
f01045b5:	f3 ab                	rep stos %eax,%es:(%edi)
f01045b7:	eb 06                	jmp    f01045bf <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01045b9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01045bc:	fc                   	cld    
f01045bd:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01045bf:	89 f8                	mov    %edi,%eax
f01045c1:	5b                   	pop    %ebx
f01045c2:	5e                   	pop    %esi
f01045c3:	5f                   	pop    %edi
f01045c4:	5d                   	pop    %ebp
f01045c5:	c3                   	ret    

f01045c6 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01045c6:	55                   	push   %ebp
f01045c7:	89 e5                	mov    %esp,%ebp
f01045c9:	57                   	push   %edi
f01045ca:	56                   	push   %esi
f01045cb:	8b 45 08             	mov    0x8(%ebp),%eax
f01045ce:	8b 75 0c             	mov    0xc(%ebp),%esi
f01045d1:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f01045d4:	39 c6                	cmp    %eax,%esi
f01045d6:	73 35                	jae    f010460d <memmove+0x47>
f01045d8:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f01045db:	39 d0                	cmp    %edx,%eax
f01045dd:	73 2e                	jae    f010460d <memmove+0x47>
		s += n;
		d += n;
f01045df:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f01045e2:	89 d6                	mov    %edx,%esi
f01045e4:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01045e6:	f7 c6 03 00 00 00    	test   $0x3,%esi
f01045ec:	75 13                	jne    f0104601 <memmove+0x3b>
f01045ee:	f6 c1 03             	test   $0x3,%cl
f01045f1:	75 0e                	jne    f0104601 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f01045f3:	83 ef 04             	sub    $0x4,%edi
f01045f6:	8d 72 fc             	lea    -0x4(%edx),%esi
f01045f9:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f01045fc:	fd                   	std    
f01045fd:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01045ff:	eb 09                	jmp    f010460a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0104601:	83 ef 01             	sub    $0x1,%edi
f0104604:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0104607:	fd                   	std    
f0104608:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f010460a:	fc                   	cld    
f010460b:	eb 1d                	jmp    f010462a <memmove+0x64>
f010460d:	89 f2                	mov    %esi,%edx
f010460f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0104611:	f6 c2 03             	test   $0x3,%dl
f0104614:	75 0f                	jne    f0104625 <memmove+0x5f>
f0104616:	f6 c1 03             	test   $0x3,%cl
f0104619:	75 0a                	jne    f0104625 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f010461b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f010461e:	89 c7                	mov    %eax,%edi
f0104620:	fc                   	cld    
f0104621:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0104623:	eb 05                	jmp    f010462a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0104625:	89 c7                	mov    %eax,%edi
f0104627:	fc                   	cld    
f0104628:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f010462a:	5e                   	pop    %esi
f010462b:	5f                   	pop    %edi
f010462c:	5d                   	pop    %ebp
f010462d:	c3                   	ret    

f010462e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f010462e:	55                   	push   %ebp
f010462f:	89 e5                	mov    %esp,%ebp
f0104631:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0104634:	8b 45 10             	mov    0x10(%ebp),%eax
f0104637:	89 44 24 08          	mov    %eax,0x8(%esp)
f010463b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010463e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104642:	8b 45 08             	mov    0x8(%ebp),%eax
f0104645:	89 04 24             	mov    %eax,(%esp)
f0104648:	e8 79 ff ff ff       	call   f01045c6 <memmove>
}
f010464d:	c9                   	leave  
f010464e:	c3                   	ret    

f010464f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f010464f:	55                   	push   %ebp
f0104650:	89 e5                	mov    %esp,%ebp
f0104652:	57                   	push   %edi
f0104653:	56                   	push   %esi
f0104654:	53                   	push   %ebx
f0104655:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0104658:	8b 75 0c             	mov    0xc(%ebp),%esi
f010465b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f010465e:	8d 78 ff             	lea    -0x1(%eax),%edi
f0104661:	85 c0                	test   %eax,%eax
f0104663:	74 36                	je     f010469b <memcmp+0x4c>
		if (*s1 != *s2)
f0104665:	0f b6 03             	movzbl (%ebx),%eax
f0104668:	0f b6 0e             	movzbl (%esi),%ecx
f010466b:	ba 00 00 00 00       	mov    $0x0,%edx
f0104670:	38 c8                	cmp    %cl,%al
f0104672:	74 1c                	je     f0104690 <memcmp+0x41>
f0104674:	eb 10                	jmp    f0104686 <memcmp+0x37>
f0104676:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f010467b:	83 c2 01             	add    $0x1,%edx
f010467e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0104682:	38 c8                	cmp    %cl,%al
f0104684:	74 0a                	je     f0104690 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0104686:	0f b6 c0             	movzbl %al,%eax
f0104689:	0f b6 c9             	movzbl %cl,%ecx
f010468c:	29 c8                	sub    %ecx,%eax
f010468e:	eb 10                	jmp    f01046a0 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0104690:	39 fa                	cmp    %edi,%edx
f0104692:	75 e2                	jne    f0104676 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0104694:	b8 00 00 00 00       	mov    $0x0,%eax
f0104699:	eb 05                	jmp    f01046a0 <memcmp+0x51>
f010469b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01046a0:	5b                   	pop    %ebx
f01046a1:	5e                   	pop    %esi
f01046a2:	5f                   	pop    %edi
f01046a3:	5d                   	pop    %ebp
f01046a4:	c3                   	ret    

f01046a5 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01046a5:	55                   	push   %ebp
f01046a6:	89 e5                	mov    %esp,%ebp
f01046a8:	53                   	push   %ebx
f01046a9:	8b 45 08             	mov    0x8(%ebp),%eax
f01046ac:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f01046af:	89 c2                	mov    %eax,%edx
f01046b1:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01046b4:	39 d0                	cmp    %edx,%eax
f01046b6:	73 13                	jae    f01046cb <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f01046b8:	89 d9                	mov    %ebx,%ecx
f01046ba:	38 18                	cmp    %bl,(%eax)
f01046bc:	75 06                	jne    f01046c4 <memfind+0x1f>
f01046be:	eb 0b                	jmp    f01046cb <memfind+0x26>
f01046c0:	38 08                	cmp    %cl,(%eax)
f01046c2:	74 07                	je     f01046cb <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f01046c4:	83 c0 01             	add    $0x1,%eax
f01046c7:	39 d0                	cmp    %edx,%eax
f01046c9:	75 f5                	jne    f01046c0 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f01046cb:	5b                   	pop    %ebx
f01046cc:	5d                   	pop    %ebp
f01046cd:	c3                   	ret    

f01046ce <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f01046ce:	55                   	push   %ebp
f01046cf:	89 e5                	mov    %esp,%ebp
f01046d1:	57                   	push   %edi
f01046d2:	56                   	push   %esi
f01046d3:	53                   	push   %ebx
f01046d4:	8b 55 08             	mov    0x8(%ebp),%edx
f01046d7:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01046da:	0f b6 0a             	movzbl (%edx),%ecx
f01046dd:	80 f9 09             	cmp    $0x9,%cl
f01046e0:	74 05                	je     f01046e7 <strtol+0x19>
f01046e2:	80 f9 20             	cmp    $0x20,%cl
f01046e5:	75 10                	jne    f01046f7 <strtol+0x29>
		s++;
f01046e7:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f01046ea:	0f b6 0a             	movzbl (%edx),%ecx
f01046ed:	80 f9 09             	cmp    $0x9,%cl
f01046f0:	74 f5                	je     f01046e7 <strtol+0x19>
f01046f2:	80 f9 20             	cmp    $0x20,%cl
f01046f5:	74 f0                	je     f01046e7 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f01046f7:	80 f9 2b             	cmp    $0x2b,%cl
f01046fa:	75 0a                	jne    f0104706 <strtol+0x38>
		s++;
f01046fc:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f01046ff:	bf 00 00 00 00       	mov    $0x0,%edi
f0104704:	eb 11                	jmp    f0104717 <strtol+0x49>
f0104706:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f010470b:	80 f9 2d             	cmp    $0x2d,%cl
f010470e:	75 07                	jne    f0104717 <strtol+0x49>
		s++, neg = 1;
f0104710:	83 c2 01             	add    $0x1,%edx
f0104713:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0104717:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f010471c:	75 15                	jne    f0104733 <strtol+0x65>
f010471e:	80 3a 30             	cmpb   $0x30,(%edx)
f0104721:	75 10                	jne    f0104733 <strtol+0x65>
f0104723:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0104727:	75 0a                	jne    f0104733 <strtol+0x65>
		s += 2, base = 16;
f0104729:	83 c2 02             	add    $0x2,%edx
f010472c:	b8 10 00 00 00       	mov    $0x10,%eax
f0104731:	eb 10                	jmp    f0104743 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0104733:	85 c0                	test   %eax,%eax
f0104735:	75 0c                	jne    f0104743 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0104737:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0104739:	80 3a 30             	cmpb   $0x30,(%edx)
f010473c:	75 05                	jne    f0104743 <strtol+0x75>
		s++, base = 8;
f010473e:	83 c2 01             	add    $0x1,%edx
f0104741:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0104743:	bb 00 00 00 00       	mov    $0x0,%ebx
f0104748:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f010474b:	0f b6 0a             	movzbl (%edx),%ecx
f010474e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0104751:	89 f0                	mov    %esi,%eax
f0104753:	3c 09                	cmp    $0x9,%al
f0104755:	77 08                	ja     f010475f <strtol+0x91>
			dig = *s - '0';
f0104757:	0f be c9             	movsbl %cl,%ecx
f010475a:	83 e9 30             	sub    $0x30,%ecx
f010475d:	eb 20                	jmp    f010477f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f010475f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0104762:	89 f0                	mov    %esi,%eax
f0104764:	3c 19                	cmp    $0x19,%al
f0104766:	77 08                	ja     f0104770 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0104768:	0f be c9             	movsbl %cl,%ecx
f010476b:	83 e9 57             	sub    $0x57,%ecx
f010476e:	eb 0f                	jmp    f010477f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0104770:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0104773:	89 f0                	mov    %esi,%eax
f0104775:	3c 19                	cmp    $0x19,%al
f0104777:	77 16                	ja     f010478f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0104779:	0f be c9             	movsbl %cl,%ecx
f010477c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f010477f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0104782:	7d 0f                	jge    f0104793 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0104784:	83 c2 01             	add    $0x1,%edx
f0104787:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f010478b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f010478d:	eb bc                	jmp    f010474b <strtol+0x7d>
f010478f:	89 d8                	mov    %ebx,%eax
f0104791:	eb 02                	jmp    f0104795 <strtol+0xc7>
f0104793:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0104795:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0104799:	74 05                	je     f01047a0 <strtol+0xd2>
		*endptr = (char *) s;
f010479b:	8b 75 0c             	mov    0xc(%ebp),%esi
f010479e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01047a0:	f7 d8                	neg    %eax
f01047a2:	85 ff                	test   %edi,%edi
f01047a4:	0f 44 c3             	cmove  %ebx,%eax
}
f01047a7:	5b                   	pop    %ebx
f01047a8:	5e                   	pop    %esi
f01047a9:	5f                   	pop    %edi
f01047aa:	5d                   	pop    %ebp
f01047ab:	c3                   	ret    
f01047ac:	66 90                	xchg   %ax,%ax
f01047ae:	66 90                	xchg   %ax,%ax

f01047b0 <__udivdi3>:
f01047b0:	55                   	push   %ebp
f01047b1:	57                   	push   %edi
f01047b2:	56                   	push   %esi
f01047b3:	83 ec 0c             	sub    $0xc,%esp
f01047b6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01047ba:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01047be:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01047c2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01047c6:	85 c0                	test   %eax,%eax
f01047c8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01047cc:	89 ea                	mov    %ebp,%edx
f01047ce:	89 0c 24             	mov    %ecx,(%esp)
f01047d1:	75 2d                	jne    f0104800 <__udivdi3+0x50>
f01047d3:	39 e9                	cmp    %ebp,%ecx
f01047d5:	77 61                	ja     f0104838 <__udivdi3+0x88>
f01047d7:	85 c9                	test   %ecx,%ecx
f01047d9:	89 ce                	mov    %ecx,%esi
f01047db:	75 0b                	jne    f01047e8 <__udivdi3+0x38>
f01047dd:	b8 01 00 00 00       	mov    $0x1,%eax
f01047e2:	31 d2                	xor    %edx,%edx
f01047e4:	f7 f1                	div    %ecx
f01047e6:	89 c6                	mov    %eax,%esi
f01047e8:	31 d2                	xor    %edx,%edx
f01047ea:	89 e8                	mov    %ebp,%eax
f01047ec:	f7 f6                	div    %esi
f01047ee:	89 c5                	mov    %eax,%ebp
f01047f0:	89 f8                	mov    %edi,%eax
f01047f2:	f7 f6                	div    %esi
f01047f4:	89 ea                	mov    %ebp,%edx
f01047f6:	83 c4 0c             	add    $0xc,%esp
f01047f9:	5e                   	pop    %esi
f01047fa:	5f                   	pop    %edi
f01047fb:	5d                   	pop    %ebp
f01047fc:	c3                   	ret    
f01047fd:	8d 76 00             	lea    0x0(%esi),%esi
f0104800:	39 e8                	cmp    %ebp,%eax
f0104802:	77 24                	ja     f0104828 <__udivdi3+0x78>
f0104804:	0f bd e8             	bsr    %eax,%ebp
f0104807:	83 f5 1f             	xor    $0x1f,%ebp
f010480a:	75 3c                	jne    f0104848 <__udivdi3+0x98>
f010480c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0104810:	39 34 24             	cmp    %esi,(%esp)
f0104813:	0f 86 9f 00 00 00    	jbe    f01048b8 <__udivdi3+0x108>
f0104819:	39 d0                	cmp    %edx,%eax
f010481b:	0f 82 97 00 00 00    	jb     f01048b8 <__udivdi3+0x108>
f0104821:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0104828:	31 d2                	xor    %edx,%edx
f010482a:	31 c0                	xor    %eax,%eax
f010482c:	83 c4 0c             	add    $0xc,%esp
f010482f:	5e                   	pop    %esi
f0104830:	5f                   	pop    %edi
f0104831:	5d                   	pop    %ebp
f0104832:	c3                   	ret    
f0104833:	90                   	nop
f0104834:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104838:	89 f8                	mov    %edi,%eax
f010483a:	f7 f1                	div    %ecx
f010483c:	31 d2                	xor    %edx,%edx
f010483e:	83 c4 0c             	add    $0xc,%esp
f0104841:	5e                   	pop    %esi
f0104842:	5f                   	pop    %edi
f0104843:	5d                   	pop    %ebp
f0104844:	c3                   	ret    
f0104845:	8d 76 00             	lea    0x0(%esi),%esi
f0104848:	89 e9                	mov    %ebp,%ecx
f010484a:	8b 3c 24             	mov    (%esp),%edi
f010484d:	d3 e0                	shl    %cl,%eax
f010484f:	89 c6                	mov    %eax,%esi
f0104851:	b8 20 00 00 00       	mov    $0x20,%eax
f0104856:	29 e8                	sub    %ebp,%eax
f0104858:	89 c1                	mov    %eax,%ecx
f010485a:	d3 ef                	shr    %cl,%edi
f010485c:	89 e9                	mov    %ebp,%ecx
f010485e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104862:	8b 3c 24             	mov    (%esp),%edi
f0104865:	09 74 24 08          	or     %esi,0x8(%esp)
f0104869:	89 d6                	mov    %edx,%esi
f010486b:	d3 e7                	shl    %cl,%edi
f010486d:	89 c1                	mov    %eax,%ecx
f010486f:	89 3c 24             	mov    %edi,(%esp)
f0104872:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104876:	d3 ee                	shr    %cl,%esi
f0104878:	89 e9                	mov    %ebp,%ecx
f010487a:	d3 e2                	shl    %cl,%edx
f010487c:	89 c1                	mov    %eax,%ecx
f010487e:	d3 ef                	shr    %cl,%edi
f0104880:	09 d7                	or     %edx,%edi
f0104882:	89 f2                	mov    %esi,%edx
f0104884:	89 f8                	mov    %edi,%eax
f0104886:	f7 74 24 08          	divl   0x8(%esp)
f010488a:	89 d6                	mov    %edx,%esi
f010488c:	89 c7                	mov    %eax,%edi
f010488e:	f7 24 24             	mull   (%esp)
f0104891:	39 d6                	cmp    %edx,%esi
f0104893:	89 14 24             	mov    %edx,(%esp)
f0104896:	72 30                	jb     f01048c8 <__udivdi3+0x118>
f0104898:	8b 54 24 04          	mov    0x4(%esp),%edx
f010489c:	89 e9                	mov    %ebp,%ecx
f010489e:	d3 e2                	shl    %cl,%edx
f01048a0:	39 c2                	cmp    %eax,%edx
f01048a2:	73 05                	jae    f01048a9 <__udivdi3+0xf9>
f01048a4:	3b 34 24             	cmp    (%esp),%esi
f01048a7:	74 1f                	je     f01048c8 <__udivdi3+0x118>
f01048a9:	89 f8                	mov    %edi,%eax
f01048ab:	31 d2                	xor    %edx,%edx
f01048ad:	e9 7a ff ff ff       	jmp    f010482c <__udivdi3+0x7c>
f01048b2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01048b8:	31 d2                	xor    %edx,%edx
f01048ba:	b8 01 00 00 00       	mov    $0x1,%eax
f01048bf:	e9 68 ff ff ff       	jmp    f010482c <__udivdi3+0x7c>
f01048c4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01048c8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01048cb:	31 d2                	xor    %edx,%edx
f01048cd:	83 c4 0c             	add    $0xc,%esp
f01048d0:	5e                   	pop    %esi
f01048d1:	5f                   	pop    %edi
f01048d2:	5d                   	pop    %ebp
f01048d3:	c3                   	ret    
f01048d4:	66 90                	xchg   %ax,%ax
f01048d6:	66 90                	xchg   %ax,%ax
f01048d8:	66 90                	xchg   %ax,%ax
f01048da:	66 90                	xchg   %ax,%ax
f01048dc:	66 90                	xchg   %ax,%ax
f01048de:	66 90                	xchg   %ax,%ax

f01048e0 <__umoddi3>:
f01048e0:	55                   	push   %ebp
f01048e1:	57                   	push   %edi
f01048e2:	56                   	push   %esi
f01048e3:	83 ec 14             	sub    $0x14,%esp
f01048e6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01048ea:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01048ee:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f01048f2:	89 c7                	mov    %eax,%edi
f01048f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048f8:	8b 44 24 30          	mov    0x30(%esp),%eax
f01048fc:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0104900:	89 34 24             	mov    %esi,(%esp)
f0104903:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104907:	85 c0                	test   %eax,%eax
f0104909:	89 c2                	mov    %eax,%edx
f010490b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010490f:	75 17                	jne    f0104928 <__umoddi3+0x48>
f0104911:	39 fe                	cmp    %edi,%esi
f0104913:	76 4b                	jbe    f0104960 <__umoddi3+0x80>
f0104915:	89 c8                	mov    %ecx,%eax
f0104917:	89 fa                	mov    %edi,%edx
f0104919:	f7 f6                	div    %esi
f010491b:	89 d0                	mov    %edx,%eax
f010491d:	31 d2                	xor    %edx,%edx
f010491f:	83 c4 14             	add    $0x14,%esp
f0104922:	5e                   	pop    %esi
f0104923:	5f                   	pop    %edi
f0104924:	5d                   	pop    %ebp
f0104925:	c3                   	ret    
f0104926:	66 90                	xchg   %ax,%ax
f0104928:	39 f8                	cmp    %edi,%eax
f010492a:	77 54                	ja     f0104980 <__umoddi3+0xa0>
f010492c:	0f bd e8             	bsr    %eax,%ebp
f010492f:	83 f5 1f             	xor    $0x1f,%ebp
f0104932:	75 5c                	jne    f0104990 <__umoddi3+0xb0>
f0104934:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0104938:	39 3c 24             	cmp    %edi,(%esp)
f010493b:	0f 87 e7 00 00 00    	ja     f0104a28 <__umoddi3+0x148>
f0104941:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0104945:	29 f1                	sub    %esi,%ecx
f0104947:	19 c7                	sbb    %eax,%edi
f0104949:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010494d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0104951:	8b 44 24 08          	mov    0x8(%esp),%eax
f0104955:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0104959:	83 c4 14             	add    $0x14,%esp
f010495c:	5e                   	pop    %esi
f010495d:	5f                   	pop    %edi
f010495e:	5d                   	pop    %ebp
f010495f:	c3                   	ret    
f0104960:	85 f6                	test   %esi,%esi
f0104962:	89 f5                	mov    %esi,%ebp
f0104964:	75 0b                	jne    f0104971 <__umoddi3+0x91>
f0104966:	b8 01 00 00 00       	mov    $0x1,%eax
f010496b:	31 d2                	xor    %edx,%edx
f010496d:	f7 f6                	div    %esi
f010496f:	89 c5                	mov    %eax,%ebp
f0104971:	8b 44 24 04          	mov    0x4(%esp),%eax
f0104975:	31 d2                	xor    %edx,%edx
f0104977:	f7 f5                	div    %ebp
f0104979:	89 c8                	mov    %ecx,%eax
f010497b:	f7 f5                	div    %ebp
f010497d:	eb 9c                	jmp    f010491b <__umoddi3+0x3b>
f010497f:	90                   	nop
f0104980:	89 c8                	mov    %ecx,%eax
f0104982:	89 fa                	mov    %edi,%edx
f0104984:	83 c4 14             	add    $0x14,%esp
f0104987:	5e                   	pop    %esi
f0104988:	5f                   	pop    %edi
f0104989:	5d                   	pop    %ebp
f010498a:	c3                   	ret    
f010498b:	90                   	nop
f010498c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104990:	8b 04 24             	mov    (%esp),%eax
f0104993:	be 20 00 00 00       	mov    $0x20,%esi
f0104998:	89 e9                	mov    %ebp,%ecx
f010499a:	29 ee                	sub    %ebp,%esi
f010499c:	d3 e2                	shl    %cl,%edx
f010499e:	89 f1                	mov    %esi,%ecx
f01049a0:	d3 e8                	shr    %cl,%eax
f01049a2:	89 e9                	mov    %ebp,%ecx
f01049a4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01049a8:	8b 04 24             	mov    (%esp),%eax
f01049ab:	09 54 24 04          	or     %edx,0x4(%esp)
f01049af:	89 fa                	mov    %edi,%edx
f01049b1:	d3 e0                	shl    %cl,%eax
f01049b3:	89 f1                	mov    %esi,%ecx
f01049b5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01049b9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01049bd:	d3 ea                	shr    %cl,%edx
f01049bf:	89 e9                	mov    %ebp,%ecx
f01049c1:	d3 e7                	shl    %cl,%edi
f01049c3:	89 f1                	mov    %esi,%ecx
f01049c5:	d3 e8                	shr    %cl,%eax
f01049c7:	89 e9                	mov    %ebp,%ecx
f01049c9:	09 f8                	or     %edi,%eax
f01049cb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01049cf:	f7 74 24 04          	divl   0x4(%esp)
f01049d3:	d3 e7                	shl    %cl,%edi
f01049d5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01049d9:	89 d7                	mov    %edx,%edi
f01049db:	f7 64 24 08          	mull   0x8(%esp)
f01049df:	39 d7                	cmp    %edx,%edi
f01049e1:	89 c1                	mov    %eax,%ecx
f01049e3:	89 14 24             	mov    %edx,(%esp)
f01049e6:	72 2c                	jb     f0104a14 <__umoddi3+0x134>
f01049e8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f01049ec:	72 22                	jb     f0104a10 <__umoddi3+0x130>
f01049ee:	8b 44 24 0c          	mov    0xc(%esp),%eax
f01049f2:	29 c8                	sub    %ecx,%eax
f01049f4:	19 d7                	sbb    %edx,%edi
f01049f6:	89 e9                	mov    %ebp,%ecx
f01049f8:	89 fa                	mov    %edi,%edx
f01049fa:	d3 e8                	shr    %cl,%eax
f01049fc:	89 f1                	mov    %esi,%ecx
f01049fe:	d3 e2                	shl    %cl,%edx
f0104a00:	89 e9                	mov    %ebp,%ecx
f0104a02:	d3 ef                	shr    %cl,%edi
f0104a04:	09 d0                	or     %edx,%eax
f0104a06:	89 fa                	mov    %edi,%edx
f0104a08:	83 c4 14             	add    $0x14,%esp
f0104a0b:	5e                   	pop    %esi
f0104a0c:	5f                   	pop    %edi
f0104a0d:	5d                   	pop    %ebp
f0104a0e:	c3                   	ret    
f0104a0f:	90                   	nop
f0104a10:	39 d7                	cmp    %edx,%edi
f0104a12:	75 da                	jne    f01049ee <__umoddi3+0x10e>
f0104a14:	8b 14 24             	mov    (%esp),%edx
f0104a17:	89 c1                	mov    %eax,%ecx
f0104a19:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0104a1d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0104a21:	eb cb                	jmp    f01049ee <__umoddi3+0x10e>
f0104a23:	90                   	nop
f0104a24:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0104a28:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0104a2c:	0f 82 0f ff ff ff    	jb     f0104941 <__umoddi3+0x61>
f0104a32:	e9 1a ff ff ff       	jmp    f0104951 <__umoddi3+0x71>
