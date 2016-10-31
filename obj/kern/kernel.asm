
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
	# until we set up our real page table in i386_vm_init in lab 2.

	# Load the physical address of entry_pgdir into cr3.  entry_pgdir
	# is defined in entrypgdir.c.
	movl	$(RELOC(entry_pgdir)), %eax
f0100015:	b8 00 00 11 00       	mov    $0x110000,%eax
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
f0100034:	bc 00 00 11 f0       	mov    $0xf0110000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 5f 00 00 00       	call   f010009d <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <test_backtrace>:
#include <kern/console.h>

// Test the stack backtrace function (lab 1 only)
void
test_backtrace(int x)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	53                   	push   %ebx
f0100044:	83 ec 14             	sub    $0x14,%esp
f0100047:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("entering test_backtrace %d\n", x);
f010004a:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010004e:	c7 04 24 a0 1a 10 f0 	movl   $0xf0101aa0,(%esp)
f0100055:	e8 46 09 00 00       	call   f01009a0 <cprintf>
	if (x > 0)
f010005a:	85 db                	test   %ebx,%ebx
f010005c:	7e 0d                	jle    f010006b <test_backtrace+0x2b>
		test_backtrace(x-1);
f010005e:	8d 43 ff             	lea    -0x1(%ebx),%eax
f0100061:	89 04 24             	mov    %eax,(%esp)
f0100064:	e8 d7 ff ff ff       	call   f0100040 <test_backtrace>
f0100069:	eb 1c                	jmp    f0100087 <test_backtrace+0x47>
	else
		mon_backtrace(0, 0, 0);
f010006b:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100072:	00 
f0100073:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010007a:	00 
f010007b:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100082:	e8 1b 07 00 00       	call   f01007a2 <mon_backtrace>
	cprintf("leaving test_backtrace %d\n", x);
f0100087:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010008b:	c7 04 24 bc 1a 10 f0 	movl   $0xf0101abc,(%esp)
f0100092:	e8 09 09 00 00       	call   f01009a0 <cprintf>
}
f0100097:	83 c4 14             	add    $0x14,%esp
f010009a:	5b                   	pop    %ebx
f010009b:	5d                   	pop    %ebp
f010009c:	c3                   	ret    

f010009d <i386_init>:

void
i386_init(void)
{
f010009d:	55                   	push   %ebp
f010009e:	89 e5                	mov    %esp,%ebp
f01000a0:	83 ec 18             	sub    $0x18,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000a3:	b8 60 29 11 f0       	mov    $0xf0112960,%eax
f01000a8:	2d 00 23 11 f0       	sub    $0xf0112300,%eax
f01000ad:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000b1:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000b8:	00 
f01000b9:	c7 04 24 00 23 11 f0 	movl   $0xf0112300,(%esp)
f01000c0:	e8 fa 14 00 00       	call   f01015bf <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000c5:	e8 a5 04 00 00       	call   f010056f <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000ca:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000d1:	00 
f01000d2:	c7 04 24 d7 1a 10 f0 	movl   $0xf0101ad7,(%esp)
f01000d9:	e8 c2 08 00 00       	call   f01009a0 <cprintf>

	// Test the stack backtrace function (lab 1 only)
	test_backtrace(5);
f01000de:	c7 04 24 05 00 00 00 	movl   $0x5,(%esp)
f01000e5:	e8 56 ff ff ff       	call   f0100040 <test_backtrace>

	// Drop into the kernel monitor.
	while (1)
		monitor(NULL);
f01000ea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000f1:	e8 21 07 00 00       	call   f0100817 <monitor>
f01000f6:	eb f2                	jmp    f01000ea <i386_init+0x4d>

f01000f8 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f01000f8:	55                   	push   %ebp
f01000f9:	89 e5                	mov    %esp,%ebp
f01000fb:	56                   	push   %esi
f01000fc:	53                   	push   %ebx
f01000fd:	83 ec 10             	sub    $0x10,%esp
f0100100:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f0100103:	83 3d 00 23 11 f0 00 	cmpl   $0x0,0xf0112300
f010010a:	75 3d                	jne    f0100149 <_panic+0x51>
		goto dead;
	panicstr = fmt;
f010010c:	89 35 00 23 11 f0    	mov    %esi,0xf0112300

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f0100112:	fa                   	cli    
f0100113:	fc                   	cld    

	va_start(ap, fmt);
f0100114:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic at %s:%d: ", file, line);
f0100117:	8b 45 0c             	mov    0xc(%ebp),%eax
f010011a:	89 44 24 08          	mov    %eax,0x8(%esp)
f010011e:	8b 45 08             	mov    0x8(%ebp),%eax
f0100121:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100125:	c7 04 24 f2 1a 10 f0 	movl   $0xf0101af2,(%esp)
f010012c:	e8 6f 08 00 00       	call   f01009a0 <cprintf>
	vcprintf(fmt, ap);
f0100131:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100135:	89 34 24             	mov    %esi,(%esp)
f0100138:	e8 30 08 00 00       	call   f010096d <vcprintf>
	cprintf("\n");
f010013d:	c7 04 24 2e 1b 10 f0 	movl   $0xf0101b2e,(%esp)
f0100144:	e8 57 08 00 00       	call   f01009a0 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f0100149:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0100150:	e8 c2 06 00 00       	call   f0100817 <monitor>
f0100155:	eb f2                	jmp    f0100149 <_panic+0x51>

f0100157 <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f0100157:	55                   	push   %ebp
f0100158:	89 e5                	mov    %esp,%ebp
f010015a:	53                   	push   %ebx
f010015b:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f010015e:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f0100161:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100164:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100168:	8b 45 08             	mov    0x8(%ebp),%eax
f010016b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010016f:	c7 04 24 0a 1b 10 f0 	movl   $0xf0101b0a,(%esp)
f0100176:	e8 25 08 00 00       	call   f01009a0 <cprintf>
	vcprintf(fmt, ap);
f010017b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010017f:	8b 45 10             	mov    0x10(%ebp),%eax
f0100182:	89 04 24             	mov    %eax,(%esp)
f0100185:	e8 e3 07 00 00       	call   f010096d <vcprintf>
	cprintf("\n");
f010018a:	c7 04 24 2e 1b 10 f0 	movl   $0xf0101b2e,(%esp)
f0100191:	e8 0a 08 00 00       	call   f01009a0 <cprintf>
	va_end(ap);
}
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
f01001cb:	a1 44 25 11 f0       	mov    0xf0112544,%eax
f01001d0:	8d 48 01             	lea    0x1(%eax),%ecx
f01001d3:	89 0d 44 25 11 f0    	mov    %ecx,0xf0112544
f01001d9:	88 90 40 23 11 f0    	mov    %dl,-0xfeedcc0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f01001df:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f01001e5:	75 0a                	jne    f01001f1 <cons_intr+0x35>
			cons.wpos = 0;
f01001e7:	c7 05 44 25 11 f0 00 	movl   $0x0,0xf0112544
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
f0100217:	83 0d 20 23 11 f0 40 	orl    $0x40,0xf0112320
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
f010022f:	8b 0d 20 23 11 f0    	mov    0xf0112320,%ecx
f0100235:	89 cb                	mov    %ecx,%ebx
f0100237:	83 e3 40             	and    $0x40,%ebx
f010023a:	83 e0 7f             	and    $0x7f,%eax
f010023d:	85 db                	test   %ebx,%ebx
f010023f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f0100242:	0f b6 d2             	movzbl %dl,%edx
f0100245:	0f b6 82 80 1c 10 f0 	movzbl -0xfefe380(%edx),%eax
f010024c:	83 c8 40             	or     $0x40,%eax
f010024f:	0f b6 c0             	movzbl %al,%eax
f0100252:	f7 d0                	not    %eax
f0100254:	21 c1                	and    %eax,%ecx
f0100256:	89 0d 20 23 11 f0    	mov    %ecx,0xf0112320
		return 0;
f010025c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100261:	e9 9d 00 00 00       	jmp    f0100303 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f0100266:	8b 0d 20 23 11 f0    	mov    0xf0112320,%ecx
f010026c:	f6 c1 40             	test   $0x40,%cl
f010026f:	74 0e                	je     f010027f <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f0100271:	83 c8 80             	or     $0xffffff80,%eax
f0100274:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f0100276:	83 e1 bf             	and    $0xffffffbf,%ecx
f0100279:	89 0d 20 23 11 f0    	mov    %ecx,0xf0112320
	}

	shift |= shiftcode[data];
f010027f:	0f b6 d2             	movzbl %dl,%edx
f0100282:	0f b6 82 80 1c 10 f0 	movzbl -0xfefe380(%edx),%eax
f0100289:	0b 05 20 23 11 f0    	or     0xf0112320,%eax
	shift ^= togglecode[data];
f010028f:	0f b6 8a 80 1b 10 f0 	movzbl -0xfefe480(%edx),%ecx
f0100296:	31 c8                	xor    %ecx,%eax
f0100298:	a3 20 23 11 f0       	mov    %eax,0xf0112320

	c = charcode[shift & (CTL | SHIFT)][data];
f010029d:	89 c1                	mov    %eax,%ecx
f010029f:	83 e1 03             	and    $0x3,%ecx
f01002a2:	8b 0c 8d 60 1b 10 f0 	mov    -0xfefe4a0(,%ecx,4),%ecx
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
f01002e2:	c7 04 24 24 1b 10 f0 	movl   $0xf0101b24,(%esp)
f01002e9:	e8 b2 06 00 00       	call   f01009a0 <cprintf>
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
f01003cc:	0f b7 05 48 25 11 f0 	movzwl 0xf0112548,%eax
f01003d3:	66 85 c0             	test   %ax,%ax
f01003d6:	0f 84 e5 00 00 00    	je     f01004c1 <cons_putc+0x1b8>
			crt_pos--;
f01003dc:	83 e8 01             	sub    $0x1,%eax
f01003df:	66 a3 48 25 11 f0    	mov    %ax,0xf0112548
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f01003e5:	0f b7 c0             	movzwl %ax,%eax
f01003e8:	66 81 e7 00 ff       	and    $0xff00,%di
f01003ed:	83 cf 20             	or     $0x20,%edi
f01003f0:	8b 15 4c 25 11 f0    	mov    0xf011254c,%edx
f01003f6:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f01003fa:	eb 78                	jmp    f0100474 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f01003fc:	66 83 05 48 25 11 f0 	addw   $0x50,0xf0112548
f0100403:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100404:	0f b7 05 48 25 11 f0 	movzwl 0xf0112548,%eax
f010040b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100411:	c1 e8 16             	shr    $0x16,%eax
f0100414:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100417:	c1 e0 04             	shl    $0x4,%eax
f010041a:	66 a3 48 25 11 f0    	mov    %ax,0xf0112548
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
f0100456:	0f b7 05 48 25 11 f0 	movzwl 0xf0112548,%eax
f010045d:	8d 50 01             	lea    0x1(%eax),%edx
f0100460:	66 89 15 48 25 11 f0 	mov    %dx,0xf0112548
f0100467:	0f b7 c0             	movzwl %ax,%eax
f010046a:	8b 15 4c 25 11 f0    	mov    0xf011254c,%edx
f0100470:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f0100474:	66 81 3d 48 25 11 f0 	cmpw   $0x7cf,0xf0112548
f010047b:	cf 07 
f010047d:	76 42                	jbe    f01004c1 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f010047f:	a1 4c 25 11 f0       	mov    0xf011254c,%eax
f0100484:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010048b:	00 
f010048c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100492:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100496:	89 04 24             	mov    %eax,(%esp)
f0100499:	e8 6e 11 00 00       	call   f010160c <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010049e:	8b 15 4c 25 11 f0    	mov    0xf011254c,%edx
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
f01004b9:	66 83 2d 48 25 11 f0 	subw   $0x50,0xf0112548
f01004c0:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f01004c1:	8b 0d 50 25 11 f0    	mov    0xf0112550,%ecx
f01004c7:	b8 0e 00 00 00       	mov    $0xe,%eax
f01004cc:	89 ca                	mov    %ecx,%edx
f01004ce:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f01004cf:	0f b7 1d 48 25 11 f0 	movzwl 0xf0112548,%ebx
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
f01004f7:	83 3d 54 25 11 f0 00 	cmpl   $0x0,0xf0112554
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
f0100535:	a1 40 25 11 f0       	mov    0xf0112540,%eax
f010053a:	3b 05 44 25 11 f0    	cmp    0xf0112544,%eax
f0100540:	74 26                	je     f0100568 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f0100542:	8d 50 01             	lea    0x1(%eax),%edx
f0100545:	89 15 40 25 11 f0    	mov    %edx,0xf0112540
f010054b:	0f b6 88 40 23 11 f0 	movzbl -0xfeedcc0(%eax),%ecx
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
f010055c:	c7 05 40 25 11 f0 00 	movl   $0x0,0xf0112540
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
f0100595:	c7 05 50 25 11 f0 b4 	movl   $0x3b4,0xf0112550
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
f01005ad:	c7 05 50 25 11 f0 d4 	movl   $0x3d4,0xf0112550
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
f01005bc:	8b 0d 50 25 11 f0    	mov    0xf0112550,%ecx
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
f01005e1:	89 3d 4c 25 11 f0    	mov    %edi,0xf011254c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f01005e7:	0f b6 d8             	movzbl %al,%ebx
f01005ea:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f01005ec:	66 89 35 48 25 11 f0 	mov    %si,0xf0112548
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
f0100640:	89 0d 54 25 11 f0    	mov    %ecx,0xf0112554
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
f0100650:	c7 04 24 30 1b 10 f0 	movl   $0xf0101b30,(%esp)
f0100657:	e8 44 03 00 00       	call   f01009a0 <cprintf>
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
f0100696:	c7 44 24 08 80 1d 10 	movl   $0xf0101d80,0x8(%esp)
f010069d:	f0 
f010069e:	c7 44 24 04 9e 1d 10 	movl   $0xf0101d9e,0x4(%esp)
f01006a5:	f0 
f01006a6:	c7 04 24 a3 1d 10 f0 	movl   $0xf0101da3,(%esp)
f01006ad:	e8 ee 02 00 00       	call   f01009a0 <cprintf>
f01006b2:	c7 44 24 08 48 1e 10 	movl   $0xf0101e48,0x8(%esp)
f01006b9:	f0 
f01006ba:	c7 44 24 04 ac 1d 10 	movl   $0xf0101dac,0x4(%esp)
f01006c1:	f0 
f01006c2:	c7 04 24 a3 1d 10 f0 	movl   $0xf0101da3,(%esp)
f01006c9:	e8 d2 02 00 00       	call   f01009a0 <cprintf>
f01006ce:	c7 44 24 08 b5 1d 10 	movl   $0xf0101db5,0x8(%esp)
f01006d5:	f0 
f01006d6:	c7 44 24 04 d3 1d 10 	movl   $0xf0101dd3,0x4(%esp)
f01006dd:	f0 
f01006de:	c7 04 24 a3 1d 10 f0 	movl   $0xf0101da3,(%esp)
f01006e5:	e8 b6 02 00 00       	call   f01009a0 <cprintf>
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
f01006f7:	c7 04 24 e1 1d 10 f0 	movl   $0xf0101de1,(%esp)
f01006fe:	e8 9d 02 00 00       	call   f01009a0 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100703:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010070a:	00 
f010070b:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f0100712:	f0 
f0100713:	c7 04 24 70 1e 10 f0 	movl   $0xf0101e70,(%esp)
f010071a:	e8 81 02 00 00       	call   f01009a0 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010071f:	c7 44 24 08 87 1a 10 	movl   $0x101a87,0x8(%esp)
f0100726:	00 
f0100727:	c7 44 24 04 87 1a 10 	movl   $0xf0101a87,0x4(%esp)
f010072e:	f0 
f010072f:	c7 04 24 94 1e 10 f0 	movl   $0xf0101e94,(%esp)
f0100736:	e8 65 02 00 00       	call   f01009a0 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f010073b:	c7 44 24 08 00 23 11 	movl   $0x112300,0x8(%esp)
f0100742:	00 
f0100743:	c7 44 24 04 00 23 11 	movl   $0xf0112300,0x4(%esp)
f010074a:	f0 
f010074b:	c7 04 24 b8 1e 10 f0 	movl   $0xf0101eb8,(%esp)
f0100752:	e8 49 02 00 00       	call   f01009a0 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f0100757:	c7 44 24 08 60 29 11 	movl   $0x112960,0x8(%esp)
f010075e:	00 
f010075f:	c7 44 24 04 60 29 11 	movl   $0xf0112960,0x4(%esp)
f0100766:	f0 
f0100767:	c7 04 24 dc 1e 10 f0 	movl   $0xf0101edc,(%esp)
f010076e:	e8 2d 02 00 00       	call   f01009a0 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f0100773:	b8 5f 2d 11 f0       	mov    $0xf0112d5f,%eax
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
f010078f:	c7 04 24 00 1f 10 f0 	movl   $0xf0101f00,(%esp)
f0100796:	e8 05 02 00 00       	call   f01009a0 <cprintf>
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
f01007ab:	c7 04 24 fa 1d 10 f0 	movl   $0xf0101dfa,(%esp)
f01007b2:	e8 e9 01 00 00       	call   f01009a0 <cprintf>
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
f01007fa:	c7 04 24 2c 1f 10 f0 	movl   $0xf0101f2c,(%esp)
f0100801:	e8 9a 01 00 00       	call   f01009a0 <cprintf>
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
f0100820:	c7 04 24 60 1f 10 f0 	movl   $0xf0101f60,(%esp)
f0100827:	e8 74 01 00 00       	call   f01009a0 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f010082c:	c7 04 24 84 1f 10 f0 	movl   $0xf0101f84,(%esp)
f0100833:	e8 68 01 00 00       	call   f01009a0 <cprintf>


	while (1) {
		buf = readline("K> ");
f0100838:	c7 04 24 0c 1e 10 f0 	movl   $0xf0101e0c,(%esp)
f010083f:	e8 cc 0a 00 00       	call   f0101310 <readline>
f0100844:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f0100846:	85 c0                	test   %eax,%eax
f0100848:	74 ee                	je     f0100838 <monitor+0x21>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f010084a:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100851:	be 00 00 00 00       	mov    $0x0,%esi
f0100856:	eb 0a                	jmp    f0100862 <monitor+0x4b>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100858:	c6 03 00             	movb   $0x0,(%ebx)
f010085b:	89 f7                	mov    %esi,%edi
f010085d:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100860:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100862:	0f b6 03             	movzbl (%ebx),%eax
f0100865:	84 c0                	test   %al,%al
f0100867:	74 6a                	je     f01008d3 <monitor+0xbc>
f0100869:	0f be c0             	movsbl %al,%eax
f010086c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100870:	c7 04 24 10 1e 10 f0 	movl   $0xf0101e10,(%esp)
f0100877:	e8 e2 0c 00 00       	call   f010155e <strchr>
f010087c:	85 c0                	test   %eax,%eax
f010087e:	75 d8                	jne    f0100858 <monitor+0x41>
			*buf++ = 0;
		if (*buf == 0)
f0100880:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100883:	74 4e                	je     f01008d3 <monitor+0xbc>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100885:	83 fe 0f             	cmp    $0xf,%esi
f0100888:	75 16                	jne    f01008a0 <monitor+0x89>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f010088a:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100891:	00 
f0100892:	c7 04 24 15 1e 10 f0 	movl   $0xf0101e15,(%esp)
f0100899:	e8 02 01 00 00       	call   f01009a0 <cprintf>
f010089e:	eb 98                	jmp    f0100838 <monitor+0x21>
			return 0;
		}
		argv[argc++] = buf;
f01008a0:	8d 7e 01             	lea    0x1(%esi),%edi
f01008a3:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f01008a7:	0f b6 03             	movzbl (%ebx),%eax
f01008aa:	84 c0                	test   %al,%al
f01008ac:	75 0c                	jne    f01008ba <monitor+0xa3>
f01008ae:	eb b0                	jmp    f0100860 <monitor+0x49>
			buf++;
f01008b0:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f01008b3:	0f b6 03             	movzbl (%ebx),%eax
f01008b6:	84 c0                	test   %al,%al
f01008b8:	74 a6                	je     f0100860 <monitor+0x49>
f01008ba:	0f be c0             	movsbl %al,%eax
f01008bd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008c1:	c7 04 24 10 1e 10 f0 	movl   $0xf0101e10,(%esp)
f01008c8:	e8 91 0c 00 00       	call   f010155e <strchr>
f01008cd:	85 c0                	test   %eax,%eax
f01008cf:	74 df                	je     f01008b0 <monitor+0x99>
f01008d1:	eb 8d                	jmp    f0100860 <monitor+0x49>
			buf++;
	}
	argv[argc] = 0;
f01008d3:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f01008da:	00 

	// Lookup and invoke the command
	if (argc == 0)
f01008db:	85 f6                	test   %esi,%esi
f01008dd:	0f 84 55 ff ff ff    	je     f0100838 <monitor+0x21>
f01008e3:	bb 00 00 00 00       	mov    $0x0,%ebx
f01008e8:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f01008eb:	8b 04 85 c0 1f 10 f0 	mov    -0xfefe040(,%eax,4),%eax
f01008f2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01008f6:	8b 45 a8             	mov    -0x58(%ebp),%eax
f01008f9:	89 04 24             	mov    %eax,(%esp)
f01008fc:	e8 d9 0b 00 00       	call   f01014da <strcmp>
f0100901:	85 c0                	test   %eax,%eax
f0100903:	75 24                	jne    f0100929 <monitor+0x112>
			return commands[i].func(argc, argv, tf);
f0100905:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100908:	8b 55 08             	mov    0x8(%ebp),%edx
f010090b:	89 54 24 08          	mov    %edx,0x8(%esp)
f010090f:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100912:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100916:	89 34 24             	mov    %esi,(%esp)
f0100919:	ff 14 85 c8 1f 10 f0 	call   *-0xfefe038(,%eax,4)


	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100920:	85 c0                	test   %eax,%eax
f0100922:	78 26                	js     f010094a <monitor+0x133>
f0100924:	e9 0f ff ff ff       	jmp    f0100838 <monitor+0x21>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100929:	83 c3 01             	add    $0x1,%ebx
f010092c:	83 fb 03             	cmp    $0x3,%ebx
f010092f:	90                   	nop
f0100930:	75 b6                	jne    f01008e8 <monitor+0xd1>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100932:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100935:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100939:	c7 04 24 32 1e 10 f0 	movl   $0xf0101e32,(%esp)
f0100940:	e8 5b 00 00 00       	call   f01009a0 <cprintf>
f0100945:	e9 ee fe ff ff       	jmp    f0100838 <monitor+0x21>
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

f010095a <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f010095a:	55                   	push   %ebp
f010095b:	89 e5                	mov    %esp,%ebp
f010095d:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0100960:	8b 45 08             	mov    0x8(%ebp),%eax
f0100963:	89 04 24             	mov    %eax,(%esp)
f0100966:	e8 f9 fc ff ff       	call   f0100664 <cputchar>
	*cnt++;
}
f010096b:	c9                   	leave  
f010096c:	c3                   	ret    

f010096d <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f010096d:	55                   	push   %ebp
f010096e:	89 e5                	mov    %esp,%ebp
f0100970:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0100973:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f010097a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010097d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100981:	8b 45 08             	mov    0x8(%ebp),%eax
f0100984:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100988:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010098b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010098f:	c7 04 24 5a 09 10 f0 	movl   $0xf010095a,(%esp)
f0100996:	e8 4f 04 00 00       	call   f0100dea <vprintfmt>
	return cnt;
}
f010099b:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010099e:	c9                   	leave  
f010099f:	c3                   	ret    

f01009a0 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f01009a0:	55                   	push   %ebp
f01009a1:	89 e5                	mov    %esp,%ebp
f01009a3:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f01009a6:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f01009a9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01009ad:	8b 45 08             	mov    0x8(%ebp),%eax
f01009b0:	89 04 24             	mov    %eax,(%esp)
f01009b3:	e8 b5 ff ff ff       	call   f010096d <vcprintf>
	va_end(ap);

	return cnt;
}
f01009b8:	c9                   	leave  
f01009b9:	c3                   	ret    
f01009ba:	66 90                	xchg   %ax,%ax
f01009bc:	66 90                	xchg   %ax,%ax
f01009be:	66 90                	xchg   %ax,%ax

f01009c0 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f01009c0:	55                   	push   %ebp
f01009c1:	89 e5                	mov    %esp,%ebp
f01009c3:	57                   	push   %edi
f01009c4:	56                   	push   %esi
f01009c5:	53                   	push   %ebx
f01009c6:	83 ec 10             	sub    $0x10,%esp
f01009c9:	89 c6                	mov    %eax,%esi
f01009cb:	89 55 e8             	mov    %edx,-0x18(%ebp)
f01009ce:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
f01009d1:	8b 7d 08             	mov    0x8(%ebp),%edi
	int l = *region_left, r = *region_right, any_matches = 0;
f01009d4:	8b 1a                	mov    (%edx),%ebx
f01009d6:	8b 01                	mov    (%ecx),%eax
f01009d8:	89 45 f0             	mov    %eax,-0x10(%ebp)
f01009db:	c7 45 ec 00 00 00 00 	movl   $0x0,-0x14(%ebp)
	
	while (l <= r) {
f01009e2:	eb 77                	jmp    f0100a5b <stab_binsearch+0x9b>
		int true_m = (l + r) / 2, m = true_m;
f01009e4:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01009e7:	01 d8                	add    %ebx,%eax
f01009e9:	b9 02 00 00 00       	mov    $0x2,%ecx
f01009ee:	99                   	cltd   
f01009ef:	f7 f9                	idiv   %ecx
f01009f1:	89 c1                	mov    %eax,%ecx
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009f3:	eb 01                	jmp    f01009f6 <stab_binsearch+0x36>
			m--;
f01009f5:	49                   	dec    %ecx
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01009f6:	39 d9                	cmp    %ebx,%ecx
f01009f8:	7c 1d                	jl     f0100a17 <stab_binsearch+0x57>
f01009fa:	6b d1 0c             	imul   $0xc,%ecx,%edx
f01009fd:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100a02:	39 fa                	cmp    %edi,%edx
f0100a04:	75 ef                	jne    f01009f5 <stab_binsearch+0x35>
f0100a06:	89 4d ec             	mov    %ecx,-0x14(%ebp)
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0100a09:	6b d1 0c             	imul   $0xc,%ecx,%edx
f0100a0c:	8b 54 16 08          	mov    0x8(%esi,%edx,1),%edx
f0100a10:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0100a13:	73 18                	jae    f0100a2d <stab_binsearch+0x6d>
f0100a15:	eb 05                	jmp    f0100a1c <stab_binsearch+0x5c>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0100a17:	8d 58 01             	lea    0x1(%eax),%ebx
			continue;
f0100a1a:	eb 3f                	jmp    f0100a5b <stab_binsearch+0x9b>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0100a1c:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100a1f:	89 0b                	mov    %ecx,(%ebx)
			l = true_m + 1;
f0100a21:	8d 58 01             	lea    0x1(%eax),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a24:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100a2b:	eb 2e                	jmp    f0100a5b <stab_binsearch+0x9b>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0100a2d:	39 55 0c             	cmp    %edx,0xc(%ebp)
f0100a30:	73 15                	jae    f0100a47 <stab_binsearch+0x87>
			*region_right = m - 1;
f0100a32:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100a35:	48                   	dec    %eax
f0100a36:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0100a39:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100a3c:	89 01                	mov    %eax,(%ecx)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a3e:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
f0100a45:	eb 14                	jmp    f0100a5b <stab_binsearch+0x9b>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0100a47:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100a4a:	8b 5d ec             	mov    -0x14(%ebp),%ebx
f0100a4d:	89 18                	mov    %ebx,(%eax)
			l = m;
			addr++;
f0100a4f:	ff 45 0c             	incl   0xc(%ebp)
f0100a52:	89 cb                	mov    %ecx,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0100a54:	c7 45 ec 01 00 00 00 	movl   $0x1,-0x14(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0100a5b:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0100a5e:	7e 84                	jle    f01009e4 <stab_binsearch+0x24>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0100a60:	83 7d ec 00          	cmpl   $0x0,-0x14(%ebp)
f0100a64:	75 0d                	jne    f0100a73 <stab_binsearch+0xb3>
		*region_right = *region_left - 1;
f0100a66:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100a69:	8b 00                	mov    (%eax),%eax
f0100a6b:	48                   	dec    %eax
f0100a6c:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0100a6f:	89 07                	mov    %eax,(%edi)
f0100a71:	eb 22                	jmp    f0100a95 <stab_binsearch+0xd5>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a73:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100a76:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0100a78:	8b 5d e8             	mov    -0x18(%ebp),%ebx
f0100a7b:	8b 0b                	mov    (%ebx),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a7d:	eb 01                	jmp    f0100a80 <stab_binsearch+0xc0>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
f0100a7f:	48                   	dec    %eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0100a80:	39 c1                	cmp    %eax,%ecx
f0100a82:	7d 0c                	jge    f0100a90 <stab_binsearch+0xd0>
f0100a84:	6b d0 0c             	imul   $0xc,%eax,%edx
		     l > *region_left && stabs[l].n_type != type;
f0100a87:	0f b6 54 16 04       	movzbl 0x4(%esi,%edx,1),%edx
f0100a8c:	39 fa                	cmp    %edi,%edx
f0100a8e:	75 ef                	jne    f0100a7f <stab_binsearch+0xbf>
		     l--)
			/* do nothing */;
		*region_left = l;
f0100a90:	8b 7d e8             	mov    -0x18(%ebp),%edi
f0100a93:	89 07                	mov    %eax,(%edi)
	}
}
f0100a95:	83 c4 10             	add    $0x10,%esp
f0100a98:	5b                   	pop    %ebx
f0100a99:	5e                   	pop    %esi
f0100a9a:	5f                   	pop    %edi
f0100a9b:	5d                   	pop    %ebp
f0100a9c:	c3                   	ret    

f0100a9d <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0100a9d:	55                   	push   %ebp
f0100a9e:	89 e5                	mov    %esp,%ebp
f0100aa0:	57                   	push   %edi
f0100aa1:	56                   	push   %esi
f0100aa2:	53                   	push   %ebx
f0100aa3:	83 ec 2c             	sub    $0x2c,%esp
f0100aa6:	8b 75 08             	mov    0x8(%ebp),%esi
f0100aa9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0100aac:	c7 03 e4 1f 10 f0    	movl   $0xf0101fe4,(%ebx)
	info->eip_line = 0;
f0100ab2:	c7 43 04 00 00 00 00 	movl   $0x0,0x4(%ebx)
	info->eip_fn_name = "<unknown>";
f0100ab9:	c7 43 08 e4 1f 10 f0 	movl   $0xf0101fe4,0x8(%ebx)
	info->eip_fn_namelen = 9;
f0100ac0:	c7 43 0c 09 00 00 00 	movl   $0x9,0xc(%ebx)
	info->eip_fn_addr = addr;
f0100ac7:	89 73 10             	mov    %esi,0x10(%ebx)
	info->eip_fn_narg = 0;
f0100aca:	c7 43 14 00 00 00 00 	movl   $0x0,0x14(%ebx)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0100ad1:	81 fe ff ff 7f ef    	cmp    $0xef7fffff,%esi
f0100ad7:	76 12                	jbe    f0100aeb <debuginfo_eip+0x4e>
		// Can't search for user-level addresses yet!
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100ad9:	b8 d7 74 10 f0       	mov    $0xf01074d7,%eax
f0100ade:	3d 71 5b 10 f0       	cmp    $0xf0105b71,%eax
f0100ae3:	0f 86 8b 01 00 00    	jbe    f0100c74 <debuginfo_eip+0x1d7>
f0100ae9:	eb 1c                	jmp    f0100b07 <debuginfo_eip+0x6a>
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
	} else {
		// Can't search for user-level addresses yet!
  	        panic("User address");
f0100aeb:	c7 44 24 08 ee 1f 10 	movl   $0xf0101fee,0x8(%esp)
f0100af2:	f0 
f0100af3:	c7 44 24 04 7f 00 00 	movl   $0x7f,0x4(%esp)
f0100afa:	00 
f0100afb:	c7 04 24 fb 1f 10 f0 	movl   $0xf0101ffb,(%esp)
f0100b02:	e8 f1 f5 ff ff       	call   f01000f8 <_panic>
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0100b07:	80 3d d6 74 10 f0 00 	cmpb   $0x0,0xf01074d6
f0100b0e:	0f 85 67 01 00 00    	jne    f0100c7b <debuginfo_eip+0x1de>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0100b14:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0100b1b:	b8 70 5b 10 f0       	mov    $0xf0105b70,%eax
f0100b20:	2d 1c 22 10 f0       	sub    $0xf010221c,%eax
f0100b25:	c1 f8 02             	sar    $0x2,%eax
f0100b28:	69 c0 ab aa aa aa    	imul   $0xaaaaaaab,%eax,%eax
f0100b2e:	83 e8 01             	sub    $0x1,%eax
f0100b31:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0100b34:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100b38:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0100b3f:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0100b42:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0100b45:	b8 1c 22 10 f0       	mov    $0xf010221c,%eax
f0100b4a:	e8 71 fe ff ff       	call   f01009c0 <stab_binsearch>
	if (lfile == 0)
f0100b4f:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100b52:	85 c0                	test   %eax,%eax
f0100b54:	0f 84 28 01 00 00    	je     f0100c82 <debuginfo_eip+0x1e5>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0100b5a:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0100b5d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100b60:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0100b63:	89 74 24 04          	mov    %esi,0x4(%esp)
f0100b67:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0100b6e:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0100b71:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100b74:	b8 1c 22 10 f0       	mov    $0xf010221c,%eax
f0100b79:	e8 42 fe ff ff       	call   f01009c0 <stab_binsearch>

	if (lfun <= rfun) {
f0100b7e:	8b 7d dc             	mov    -0x24(%ebp),%edi
f0100b81:	3b 7d d8             	cmp    -0x28(%ebp),%edi
f0100b84:	7f 2e                	jg     f0100bb4 <debuginfo_eip+0x117>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0100b86:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100b89:	8d 90 1c 22 10 f0    	lea    -0xfefdde4(%eax),%edx
f0100b8f:	8b 80 1c 22 10 f0    	mov    -0xfefdde4(%eax),%eax
f0100b95:	b9 d7 74 10 f0       	mov    $0xf01074d7,%ecx
f0100b9a:	81 e9 71 5b 10 f0    	sub    $0xf0105b71,%ecx
f0100ba0:	39 c8                	cmp    %ecx,%eax
f0100ba2:	73 08                	jae    f0100bac <debuginfo_eip+0x10f>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0100ba4:	05 71 5b 10 f0       	add    $0xf0105b71,%eax
f0100ba9:	89 43 08             	mov    %eax,0x8(%ebx)
		info->eip_fn_addr = stabs[lfun].n_value;
f0100bac:	8b 42 08             	mov    0x8(%edx),%eax
f0100baf:	89 43 10             	mov    %eax,0x10(%ebx)
f0100bb2:	eb 06                	jmp    f0100bba <debuginfo_eip+0x11d>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0100bb4:	89 73 10             	mov    %esi,0x10(%ebx)
		lline = lfile;
f0100bb7:	8b 7d e4             	mov    -0x1c(%ebp),%edi
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0100bba:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0100bc1:	00 
f0100bc2:	8b 43 08             	mov    0x8(%ebx),%eax
f0100bc5:	89 04 24             	mov    %eax,(%esp)
f0100bc8:	e8 c7 09 00 00       	call   f0101594 <strfind>
f0100bcd:	2b 43 08             	sub    0x8(%ebx),%eax
f0100bd0:	89 43 0c             	mov    %eax,0xc(%ebx)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100bd3:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f0100bd6:	39 cf                	cmp    %ecx,%edi
f0100bd8:	7c 5c                	jl     f0100c36 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f0100bda:	6b c7 0c             	imul   $0xc,%edi,%eax
f0100bdd:	8d b0 1c 22 10 f0    	lea    -0xfefdde4(%eax),%esi
f0100be3:	0f b6 56 04          	movzbl 0x4(%esi),%edx
f0100be7:	80 fa 84             	cmp    $0x84,%dl
f0100bea:	74 2b                	je     f0100c17 <debuginfo_eip+0x17a>
f0100bec:	05 10 22 10 f0       	add    $0xf0102210,%eax
f0100bf1:	eb 15                	jmp    f0100c08 <debuginfo_eip+0x16b>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0100bf3:	83 ef 01             	sub    $0x1,%edi
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0100bf6:	39 cf                	cmp    %ecx,%edi
f0100bf8:	7c 3c                	jl     f0100c36 <debuginfo_eip+0x199>
	       && stabs[lline].n_type != N_SOL
f0100bfa:	89 c6                	mov    %eax,%esi
f0100bfc:	83 e8 0c             	sub    $0xc,%eax
f0100bff:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0100c03:	80 fa 84             	cmp    $0x84,%dl
f0100c06:	74 0f                	je     f0100c17 <debuginfo_eip+0x17a>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0100c08:	80 fa 64             	cmp    $0x64,%dl
f0100c0b:	75 e6                	jne    f0100bf3 <debuginfo_eip+0x156>
f0100c0d:	83 7e 08 00          	cmpl   $0x0,0x8(%esi)
f0100c11:	74 e0                	je     f0100bf3 <debuginfo_eip+0x156>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0100c13:	39 f9                	cmp    %edi,%ecx
f0100c15:	7f 1f                	jg     f0100c36 <debuginfo_eip+0x199>
f0100c17:	6b ff 0c             	imul   $0xc,%edi,%edi
f0100c1a:	8b 87 1c 22 10 f0    	mov    -0xfefdde4(%edi),%eax
f0100c20:	ba d7 74 10 f0       	mov    $0xf01074d7,%edx
f0100c25:	81 ea 71 5b 10 f0    	sub    $0xf0105b71,%edx
f0100c2b:	39 d0                	cmp    %edx,%eax
f0100c2d:	73 07                	jae    f0100c36 <debuginfo_eip+0x199>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0100c2f:	05 71 5b 10 f0       	add    $0xf0105b71,%eax
f0100c34:	89 03                	mov    %eax,(%ebx)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100c36:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c39:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0100c3c:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0100c41:	39 ca                	cmp    %ecx,%edx
f0100c43:	7d 5e                	jge    f0100ca3 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
f0100c45:	8d 42 01             	lea    0x1(%edx),%eax
f0100c48:	39 c1                	cmp    %eax,%ecx
f0100c4a:	7e 3d                	jle    f0100c89 <debuginfo_eip+0x1ec>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100c4c:	6b d0 0c             	imul   $0xc,%eax,%edx
f0100c4f:	80 ba 20 22 10 f0 a0 	cmpb   $0xa0,-0xfefdde0(%edx)
f0100c56:	75 38                	jne    f0100c90 <debuginfo_eip+0x1f3>
f0100c58:	81 c2 10 22 10 f0    	add    $0xf0102210,%edx
		     lline++)
			info->eip_fn_narg++;
f0100c5e:	83 43 14 01          	addl   $0x1,0x14(%ebx)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0100c62:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0100c65:	39 c1                	cmp    %eax,%ecx
f0100c67:	7e 2e                	jle    f0100c97 <debuginfo_eip+0x1fa>
f0100c69:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0100c6c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0100c70:	74 ec                	je     f0100c5e <debuginfo_eip+0x1c1>
f0100c72:	eb 2a                	jmp    f0100c9e <debuginfo_eip+0x201>
  	        panic("User address");
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0100c74:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c79:	eb 28                	jmp    f0100ca3 <debuginfo_eip+0x206>
f0100c7b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c80:	eb 21                	jmp    f0100ca3 <debuginfo_eip+0x206>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0100c82:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100c87:	eb 1a                	jmp    f0100ca3 <debuginfo_eip+0x206>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0100c89:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c8e:	eb 13                	jmp    f0100ca3 <debuginfo_eip+0x206>
f0100c90:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c95:	eb 0c                	jmp    f0100ca3 <debuginfo_eip+0x206>
f0100c97:	b8 00 00 00 00       	mov    $0x0,%eax
f0100c9c:	eb 05                	jmp    f0100ca3 <debuginfo_eip+0x206>
f0100c9e:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0100ca3:	83 c4 2c             	add    $0x2c,%esp
f0100ca6:	5b                   	pop    %ebx
f0100ca7:	5e                   	pop    %esi
f0100ca8:	5f                   	pop    %edi
f0100ca9:	5d                   	pop    %ebp
f0100caa:	c3                   	ret    
f0100cab:	66 90                	xchg   %ax,%ax
f0100cad:	66 90                	xchg   %ax,%ax
f0100caf:	90                   	nop

f0100cb0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0100cb0:	55                   	push   %ebp
f0100cb1:	89 e5                	mov    %esp,%ebp
f0100cb3:	57                   	push   %edi
f0100cb4:	56                   	push   %esi
f0100cb5:	53                   	push   %ebx
f0100cb6:	83 ec 3c             	sub    $0x3c,%esp
f0100cb9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100cbc:	89 d7                	mov    %edx,%edi
f0100cbe:	8b 45 08             	mov    0x8(%ebp),%eax
f0100cc1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0100cc4:	8b 75 0c             	mov    0xc(%ebp),%esi
f0100cc7:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0100cca:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0100ccd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100cd2:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0100cd5:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0100cd8:	39 f1                	cmp    %esi,%ecx
f0100cda:	72 14                	jb     f0100cf0 <printnum+0x40>
f0100cdc:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f0100cdf:	76 0f                	jbe    f0100cf0 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100ce1:	8b 45 14             	mov    0x14(%ebp),%eax
f0100ce4:	8d 70 ff             	lea    -0x1(%eax),%esi
f0100ce7:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0100cea:	85 f6                	test   %esi,%esi
f0100cec:	7f 60                	jg     f0100d4e <printnum+0x9e>
f0100cee:	eb 72                	jmp    f0100d62 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0100cf0:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0100cf3:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0100cf7:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0100cfa:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0100cfd:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100d01:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100d05:	8b 44 24 08          	mov    0x8(%esp),%eax
f0100d09:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0100d0d:	89 c3                	mov    %eax,%ebx
f0100d0f:	89 d6                	mov    %edx,%esi
f0100d11:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0100d14:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0100d17:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100d1b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100d1f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d22:	89 04 24             	mov    %eax,(%esp)
f0100d25:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100d28:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d2c:	e8 cf 0a 00 00       	call   f0101800 <__udivdi3>
f0100d31:	89 d9                	mov    %ebx,%ecx
f0100d33:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100d37:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0100d3b:	89 04 24             	mov    %eax,(%esp)
f0100d3e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100d42:	89 fa                	mov    %edi,%edx
f0100d44:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d47:	e8 64 ff ff ff       	call   f0100cb0 <printnum>
f0100d4c:	eb 14                	jmp    f0100d62 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f0100d4e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d52:	8b 45 18             	mov    0x18(%ebp),%eax
f0100d55:	89 04 24             	mov    %eax,(%esp)
f0100d58:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0100d5a:	83 ee 01             	sub    $0x1,%esi
f0100d5d:	75 ef                	jne    f0100d4e <printnum+0x9e>
f0100d5f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0100d62:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d66:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0100d6a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100d6d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100d70:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100d74:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100d78:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100d7b:	89 04 24             	mov    %eax,(%esp)
f0100d7e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100d81:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100d85:	e8 a6 0b 00 00       	call   f0101930 <__umoddi3>
f0100d8a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0100d8e:	0f be 80 09 20 10 f0 	movsbl -0xfefdff7(%eax),%eax
f0100d95:	89 04 24             	mov    %eax,(%esp)
f0100d98:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100d9b:	ff d0                	call   *%eax
}
f0100d9d:	83 c4 3c             	add    $0x3c,%esp
f0100da0:	5b                   	pop    %ebx
f0100da1:	5e                   	pop    %esi
f0100da2:	5f                   	pop    %edi
f0100da3:	5d                   	pop    %ebp
f0100da4:	c3                   	ret    

f0100da5 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0100da5:	55                   	push   %ebp
f0100da6:	89 e5                	mov    %esp,%ebp
f0100da8:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f0100dab:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f0100daf:	8b 10                	mov    (%eax),%edx
f0100db1:	3b 50 04             	cmp    0x4(%eax),%edx
f0100db4:	73 0a                	jae    f0100dc0 <sprintputch+0x1b>
		*b->buf++ = ch;
f0100db6:	8d 4a 01             	lea    0x1(%edx),%ecx
f0100db9:	89 08                	mov    %ecx,(%eax)
f0100dbb:	8b 45 08             	mov    0x8(%ebp),%eax
f0100dbe:	88 02                	mov    %al,(%edx)
}
f0100dc0:	5d                   	pop    %ebp
f0100dc1:	c3                   	ret    

f0100dc2 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0100dc2:	55                   	push   %ebp
f0100dc3:	89 e5                	mov    %esp,%ebp
f0100dc5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0100dc8:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f0100dcb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100dcf:	8b 45 10             	mov    0x10(%ebp),%eax
f0100dd2:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100dd6:	8b 45 0c             	mov    0xc(%ebp),%eax
f0100dd9:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ddd:	8b 45 08             	mov    0x8(%ebp),%eax
f0100de0:	89 04 24             	mov    %eax,(%esp)
f0100de3:	e8 02 00 00 00       	call   f0100dea <vprintfmt>
	va_end(ap);
}
f0100de8:	c9                   	leave  
f0100de9:	c3                   	ret    

f0100dea <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f0100dea:	55                   	push   %ebp
f0100deb:	89 e5                	mov    %esp,%ebp
f0100ded:	57                   	push   %edi
f0100dee:	56                   	push   %esi
f0100def:	53                   	push   %ebx
f0100df0:	83 ec 3c             	sub    $0x3c,%esp
f0100df3:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0100df6:	89 df                	mov    %ebx,%edi
f0100df8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0100dfb:	eb 03                	jmp    f0100e00 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f0100dfd:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100e00:	8b 45 10             	mov    0x10(%ebp),%eax
f0100e03:	8d 70 01             	lea    0x1(%eax),%esi
f0100e06:	0f b6 00             	movzbl (%eax),%eax
f0100e09:	83 f8 25             	cmp    $0x25,%eax
f0100e0c:	74 2d                	je     f0100e3b <vprintfmt+0x51>
			if (ch == '\0')
f0100e0e:	85 c0                	test   %eax,%eax
f0100e10:	75 14                	jne    f0100e26 <vprintfmt+0x3c>
f0100e12:	e9 6b 04 00 00       	jmp    f0101282 <vprintfmt+0x498>
f0100e17:	85 c0                	test   %eax,%eax
f0100e19:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0100e20:	0f 84 5c 04 00 00    	je     f0101282 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0100e26:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100e2a:	89 04 24             	mov    %eax,(%esp)
f0100e2d:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0100e2f:	83 c6 01             	add    $0x1,%esi
f0100e32:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f0100e36:	83 f8 25             	cmp    $0x25,%eax
f0100e39:	75 dc                	jne    f0100e17 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0100e3b:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f0100e3f:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0100e46:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f0100e4d:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0100e54:	b9 00 00 00 00       	mov    $0x0,%ecx
f0100e59:	eb 1f                	jmp    f0100e7a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e5b:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f0100e5e:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0100e62:	eb 16                	jmp    f0100e7a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e64:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0100e67:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f0100e6b:	eb 0d                	jmp    f0100e7a <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f0100e6d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0100e70:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0100e73:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100e7a:	8d 46 01             	lea    0x1(%esi),%eax
f0100e7d:	89 45 10             	mov    %eax,0x10(%ebp)
f0100e80:	0f b6 06             	movzbl (%esi),%eax
f0100e83:	0f b6 d0             	movzbl %al,%edx
f0100e86:	83 e8 23             	sub    $0x23,%eax
f0100e89:	3c 55                	cmp    $0x55,%al
f0100e8b:	0f 87 c4 03 00 00    	ja     f0101255 <vprintfmt+0x46b>
f0100e91:	0f b6 c0             	movzbl %al,%eax
f0100e94:	ff 24 85 98 20 10 f0 	jmp    *-0xfefdf68(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f0100e9b:	8d 42 d0             	lea    -0x30(%edx),%eax
f0100e9e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0100ea1:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0100ea5:	8d 50 d0             	lea    -0x30(%eax),%edx
f0100ea8:	83 fa 09             	cmp    $0x9,%edx
f0100eab:	77 63                	ja     f0100f10 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ead:	8b 75 10             	mov    0x10(%ebp),%esi
f0100eb0:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f0100eb3:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0100eb6:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0100eb9:	8d 14 92             	lea    (%edx,%edx,4),%edx
f0100ebc:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f0100ec0:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0100ec3:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0100ec6:	83 f9 09             	cmp    $0x9,%ecx
f0100ec9:	76 eb                	jbe    f0100eb6 <vprintfmt+0xcc>
f0100ecb:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0100ece:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0100ed1:	eb 40                	jmp    f0100f13 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0100ed3:	8b 45 14             	mov    0x14(%ebp),%eax
f0100ed6:	8b 00                	mov    (%eax),%eax
f0100ed8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100edb:	8b 45 14             	mov    0x14(%ebp),%eax
f0100ede:	8d 40 04             	lea    0x4(%eax),%eax
f0100ee1:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ee4:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0100ee7:	eb 2a                	jmp    f0100f13 <vprintfmt+0x129>
f0100ee9:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0100eec:	85 d2                	test   %edx,%edx
f0100eee:	b8 00 00 00 00       	mov    $0x0,%eax
f0100ef3:	0f 49 c2             	cmovns %edx,%eax
f0100ef6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100ef9:	8b 75 10             	mov    0x10(%ebp),%esi
f0100efc:	e9 79 ff ff ff       	jmp    f0100e7a <vprintfmt+0x90>
f0100f01:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0100f04:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f0100f0b:	e9 6a ff ff ff       	jmp    f0100e7a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f10:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0100f13:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0100f17:	0f 89 5d ff ff ff    	jns    f0100e7a <vprintfmt+0x90>
f0100f1d:	e9 4b ff ff ff       	jmp    f0100e6d <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0100f22:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100f25:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0100f28:	e9 4d ff ff ff       	jmp    f0100e7a <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f0100f2d:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f30:	8d 70 04             	lea    0x4(%eax),%esi
f0100f33:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100f37:	8b 00                	mov    (%eax),%eax
f0100f39:	89 04 24             	mov    %eax,(%esp)
f0100f3c:	ff d7                	call   *%edi
f0100f3e:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0100f41:	e9 ba fe ff ff       	jmp    f0100e00 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0100f46:	8b 45 14             	mov    0x14(%ebp),%eax
f0100f49:	8d 70 04             	lea    0x4(%eax),%esi
f0100f4c:	8b 00                	mov    (%eax),%eax
f0100f4e:	99                   	cltd   
f0100f4f:	31 d0                	xor    %edx,%eax
f0100f51:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0100f53:	83 f8 06             	cmp    $0x6,%eax
f0100f56:	7f 0b                	jg     f0100f63 <vprintfmt+0x179>
f0100f58:	8b 14 85 f0 21 10 f0 	mov    -0xfefde10(,%eax,4),%edx
f0100f5f:	85 d2                	test   %edx,%edx
f0100f61:	75 20                	jne    f0100f83 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f0100f63:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100f67:	c7 44 24 08 21 20 10 	movl   $0xf0102021,0x8(%esp)
f0100f6e:	f0 
f0100f6f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100f73:	89 3c 24             	mov    %edi,(%esp)
f0100f76:	e8 47 fe ff ff       	call   f0100dc2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f0100f7b:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f0100f7e:	e9 7d fe ff ff       	jmp    f0100e00 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f0100f83:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0100f87:	c7 44 24 08 2a 20 10 	movl   $0xf010202a,0x8(%esp)
f0100f8e:	f0 
f0100f8f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100f93:	89 3c 24             	mov    %edi,(%esp)
f0100f96:	e8 27 fe ff ff       	call   f0100dc2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f0100f9b:	89 75 14             	mov    %esi,0x14(%ebp)
f0100f9e:	e9 5d fe ff ff       	jmp    f0100e00 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0100fa3:	8b 45 14             	mov    0x14(%ebp),%eax
f0100fa6:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0100fa9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f0100fac:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f0100fb0:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0100fb2:	85 c0                	test   %eax,%eax
f0100fb4:	b9 1a 20 10 f0       	mov    $0xf010201a,%ecx
f0100fb9:	0f 45 c8             	cmovne %eax,%ecx
f0100fbc:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f0100fbf:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0100fc3:	74 04                	je     f0100fc9 <vprintfmt+0x1df>
f0100fc5:	85 f6                	test   %esi,%esi
f0100fc7:	7f 19                	jg     f0100fe2 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0100fc9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0100fcc:	8d 70 01             	lea    0x1(%eax),%esi
f0100fcf:	0f b6 10             	movzbl (%eax),%edx
f0100fd2:	0f be c2             	movsbl %dl,%eax
f0100fd5:	85 c0                	test   %eax,%eax
f0100fd7:	0f 85 9a 00 00 00    	jne    f0101077 <vprintfmt+0x28d>
f0100fdd:	e9 87 00 00 00       	jmp    f0101069 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0100fe2:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100fe6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0100fe9:	89 04 24             	mov    %eax,(%esp)
f0100fec:	e8 11 04 00 00       	call   f0101402 <strnlen>
f0100ff1:	29 c6                	sub    %eax,%esi
f0100ff3:	89 f0                	mov    %esi,%eax
f0100ff5:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0100ff8:	85 f6                	test   %esi,%esi
f0100ffa:	7e cd                	jle    f0100fc9 <vprintfmt+0x1df>
					putch(padc, putdat);
f0100ffc:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101000:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0101003:	89 c3                	mov    %eax,%ebx
f0101005:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101008:	89 44 24 04          	mov    %eax,0x4(%esp)
f010100c:	89 34 24             	mov    %esi,(%esp)
f010100f:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0101011:	83 eb 01             	sub    $0x1,%ebx
f0101014:	75 ef                	jne    f0101005 <vprintfmt+0x21b>
f0101016:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101019:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010101c:	eb ab                	jmp    f0100fc9 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f010101e:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0101022:	74 1e                	je     f0101042 <vprintfmt+0x258>
f0101024:	0f be d2             	movsbl %dl,%edx
f0101027:	83 ea 20             	sub    $0x20,%edx
f010102a:	83 fa 5e             	cmp    $0x5e,%edx
f010102d:	76 13                	jbe    f0101042 <vprintfmt+0x258>
					putch('?', putdat);
f010102f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101032:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101036:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f010103d:	ff 55 08             	call   *0x8(%ebp)
f0101040:	eb 0d                	jmp    f010104f <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0101042:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0101045:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0101049:	89 04 24             	mov    %eax,(%esp)
f010104c:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f010104f:	83 eb 01             	sub    $0x1,%ebx
f0101052:	83 c6 01             	add    $0x1,%esi
f0101055:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0101059:	0f be c2             	movsbl %dl,%eax
f010105c:	85 c0                	test   %eax,%eax
f010105e:	75 23                	jne    f0101083 <vprintfmt+0x299>
f0101060:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0101063:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101066:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101069:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f010106c:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0101070:	7f 25                	jg     f0101097 <vprintfmt+0x2ad>
f0101072:	e9 89 fd ff ff       	jmp    f0100e00 <vprintfmt+0x16>
f0101077:	89 7d 08             	mov    %edi,0x8(%ebp)
f010107a:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010107d:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0101080:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0101083:	85 ff                	test   %edi,%edi
f0101085:	78 97                	js     f010101e <vprintfmt+0x234>
f0101087:	83 ef 01             	sub    $0x1,%edi
f010108a:	79 92                	jns    f010101e <vprintfmt+0x234>
f010108c:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f010108f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101092:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101095:	eb d2                	jmp    f0101069 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0101097:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010109b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01010a2:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01010a4:	83 ee 01             	sub    $0x1,%esi
f01010a7:	75 ee                	jne    f0101097 <vprintfmt+0x2ad>
f01010a9:	e9 52 fd ff ff       	jmp    f0100e00 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01010ae:	83 f9 01             	cmp    $0x1,%ecx
f01010b1:	7e 19                	jle    f01010cc <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f01010b3:	8b 45 14             	mov    0x14(%ebp),%eax
f01010b6:	8b 50 04             	mov    0x4(%eax),%edx
f01010b9:	8b 00                	mov    (%eax),%eax
f01010bb:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01010be:	89 55 dc             	mov    %edx,-0x24(%ebp)
f01010c1:	8b 45 14             	mov    0x14(%ebp),%eax
f01010c4:	8d 40 08             	lea    0x8(%eax),%eax
f01010c7:	89 45 14             	mov    %eax,0x14(%ebp)
f01010ca:	eb 38                	jmp    f0101104 <vprintfmt+0x31a>
	else if (lflag)
f01010cc:	85 c9                	test   %ecx,%ecx
f01010ce:	74 1b                	je     f01010eb <vprintfmt+0x301>
		return va_arg(*ap, long);
f01010d0:	8b 45 14             	mov    0x14(%ebp),%eax
f01010d3:	8b 30                	mov    (%eax),%esi
f01010d5:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01010d8:	89 f0                	mov    %esi,%eax
f01010da:	c1 f8 1f             	sar    $0x1f,%eax
f01010dd:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01010e0:	8b 45 14             	mov    0x14(%ebp),%eax
f01010e3:	8d 40 04             	lea    0x4(%eax),%eax
f01010e6:	89 45 14             	mov    %eax,0x14(%ebp)
f01010e9:	eb 19                	jmp    f0101104 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f01010eb:	8b 45 14             	mov    0x14(%ebp),%eax
f01010ee:	8b 30                	mov    (%eax),%esi
f01010f0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01010f3:	89 f0                	mov    %esi,%eax
f01010f5:	c1 f8 1f             	sar    $0x1f,%eax
f01010f8:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01010fb:	8b 45 14             	mov    0x14(%ebp),%eax
f01010fe:	8d 40 04             	lea    0x4(%eax),%eax
f0101101:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0101104:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101107:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010110a:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f010110f:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0101113:	0f 89 06 01 00 00    	jns    f010121f <vprintfmt+0x435>
				putch('-', putdat);
f0101119:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010111d:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0101124:	ff d7                	call   *%edi
				num = -(long long) num;
f0101126:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0101129:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010112c:	f7 da                	neg    %edx
f010112e:	83 d1 00             	adc    $0x0,%ecx
f0101131:	f7 d9                	neg    %ecx
			}
			base = 10;
f0101133:	b8 0a 00 00 00       	mov    $0xa,%eax
f0101138:	e9 e2 00 00 00       	jmp    f010121f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010113d:	83 f9 01             	cmp    $0x1,%ecx
f0101140:	7e 10                	jle    f0101152 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f0101142:	8b 45 14             	mov    0x14(%ebp),%eax
f0101145:	8b 10                	mov    (%eax),%edx
f0101147:	8b 48 04             	mov    0x4(%eax),%ecx
f010114a:	8d 40 08             	lea    0x8(%eax),%eax
f010114d:	89 45 14             	mov    %eax,0x14(%ebp)
f0101150:	eb 26                	jmp    f0101178 <vprintfmt+0x38e>
	else if (lflag)
f0101152:	85 c9                	test   %ecx,%ecx
f0101154:	74 12                	je     f0101168 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f0101156:	8b 45 14             	mov    0x14(%ebp),%eax
f0101159:	8b 10                	mov    (%eax),%edx
f010115b:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101160:	8d 40 04             	lea    0x4(%eax),%eax
f0101163:	89 45 14             	mov    %eax,0x14(%ebp)
f0101166:	eb 10                	jmp    f0101178 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f0101168:	8b 45 14             	mov    0x14(%ebp),%eax
f010116b:	8b 10                	mov    (%eax),%edx
f010116d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101172:	8d 40 04             	lea    0x4(%eax),%eax
f0101175:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f0101178:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f010117d:	e9 9d 00 00 00       	jmp    f010121f <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f0101182:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101186:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010118d:	ff d7                	call   *%edi
			putch('X', putdat);
f010118f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101193:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010119a:	ff d7                	call   *%edi
			putch('X', putdat);
f010119c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01011a0:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01011a7:	ff d7                	call   *%edi
			break;
f01011a9:	e9 52 fc ff ff       	jmp    f0100e00 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f01011ae:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01011b2:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01011b9:	ff d7                	call   *%edi
			putch('x', putdat);
f01011bb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01011bf:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01011c6:	ff d7                	call   *%edi
			num = (unsigned long long)
f01011c8:	8b 45 14             	mov    0x14(%ebp),%eax
f01011cb:	8b 10                	mov    (%eax),%edx
f01011cd:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f01011d2:	8d 40 04             	lea    0x4(%eax),%eax
f01011d5:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f01011d8:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f01011dd:	eb 40                	jmp    f010121f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01011df:	83 f9 01             	cmp    $0x1,%ecx
f01011e2:	7e 10                	jle    f01011f4 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f01011e4:	8b 45 14             	mov    0x14(%ebp),%eax
f01011e7:	8b 10                	mov    (%eax),%edx
f01011e9:	8b 48 04             	mov    0x4(%eax),%ecx
f01011ec:	8d 40 08             	lea    0x8(%eax),%eax
f01011ef:	89 45 14             	mov    %eax,0x14(%ebp)
f01011f2:	eb 26                	jmp    f010121a <vprintfmt+0x430>
	else if (lflag)
f01011f4:	85 c9                	test   %ecx,%ecx
f01011f6:	74 12                	je     f010120a <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f01011f8:	8b 45 14             	mov    0x14(%ebp),%eax
f01011fb:	8b 10                	mov    (%eax),%edx
f01011fd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101202:	8d 40 04             	lea    0x4(%eax),%eax
f0101205:	89 45 14             	mov    %eax,0x14(%ebp)
f0101208:	eb 10                	jmp    f010121a <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f010120a:	8b 45 14             	mov    0x14(%ebp),%eax
f010120d:	8b 10                	mov    (%eax),%edx
f010120f:	b9 00 00 00 00       	mov    $0x0,%ecx
f0101214:	8d 40 04             	lea    0x4(%eax),%eax
f0101217:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f010121a:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f010121f:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0101223:	89 74 24 10          	mov    %esi,0x10(%esp)
f0101227:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010122a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010122e:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101232:	89 14 24             	mov    %edx,(%esp)
f0101235:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0101239:	89 da                	mov    %ebx,%edx
f010123b:	89 f8                	mov    %edi,%eax
f010123d:	e8 6e fa ff ff       	call   f0100cb0 <printnum>
			break;
f0101242:	e9 b9 fb ff ff       	jmp    f0100e00 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0101247:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010124b:	89 14 24             	mov    %edx,(%esp)
f010124e:	ff d7                	call   *%edi
			break;
f0101250:	e9 ab fb ff ff       	jmp    f0100e00 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0101255:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101259:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0101260:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f0101262:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0101266:	0f 84 91 fb ff ff    	je     f0100dfd <vprintfmt+0x13>
f010126c:	89 75 10             	mov    %esi,0x10(%ebp)
f010126f:	89 f0                	mov    %esi,%eax
f0101271:	83 e8 01             	sub    $0x1,%eax
f0101274:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f0101278:	75 f7                	jne    f0101271 <vprintfmt+0x487>
f010127a:	89 45 10             	mov    %eax,0x10(%ebp)
f010127d:	e9 7e fb ff ff       	jmp    f0100e00 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f0101282:	83 c4 3c             	add    $0x3c,%esp
f0101285:	5b                   	pop    %ebx
f0101286:	5e                   	pop    %esi
f0101287:	5f                   	pop    %edi
f0101288:	5d                   	pop    %ebp
f0101289:	c3                   	ret    

f010128a <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f010128a:	55                   	push   %ebp
f010128b:	89 e5                	mov    %esp,%ebp
f010128d:	83 ec 28             	sub    $0x28,%esp
f0101290:	8b 45 08             	mov    0x8(%ebp),%eax
f0101293:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0101296:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0101299:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010129d:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01012a0:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01012a7:	85 c0                	test   %eax,%eax
f01012a9:	74 30                	je     f01012db <vsnprintf+0x51>
f01012ab:	85 d2                	test   %edx,%edx
f01012ad:	7e 2c                	jle    f01012db <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01012af:	8b 45 14             	mov    0x14(%ebp),%eax
f01012b2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012b6:	8b 45 10             	mov    0x10(%ebp),%eax
f01012b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01012bd:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01012c0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012c4:	c7 04 24 a5 0d 10 f0 	movl   $0xf0100da5,(%esp)
f01012cb:	e8 1a fb ff ff       	call   f0100dea <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f01012d0:	8b 45 ec             	mov    -0x14(%ebp),%eax
f01012d3:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f01012d6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01012d9:	eb 05                	jmp    f01012e0 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f01012db:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01012e0:	c9                   	leave  
f01012e1:	c3                   	ret    

f01012e2 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01012e2:	55                   	push   %ebp
f01012e3:	89 e5                	mov    %esp,%ebp
f01012e5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01012e8:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01012eb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01012ef:	8b 45 10             	mov    0x10(%ebp),%eax
f01012f2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01012f6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012f9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012fd:	8b 45 08             	mov    0x8(%ebp),%eax
f0101300:	89 04 24             	mov    %eax,(%esp)
f0101303:	e8 82 ff ff ff       	call   f010128a <vsnprintf>
	va_end(ap);

	return rc;
}
f0101308:	c9                   	leave  
f0101309:	c3                   	ret    
f010130a:	66 90                	xchg   %ax,%ax
f010130c:	66 90                	xchg   %ax,%ax
f010130e:	66 90                	xchg   %ax,%ax

f0101310 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0101310:	55                   	push   %ebp
f0101311:	89 e5                	mov    %esp,%ebp
f0101313:	57                   	push   %edi
f0101314:	56                   	push   %esi
f0101315:	53                   	push   %ebx
f0101316:	83 ec 1c             	sub    $0x1c,%esp
f0101319:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010131c:	85 c0                	test   %eax,%eax
f010131e:	74 10                	je     f0101330 <readline+0x20>
		cprintf("%s", prompt);
f0101320:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101324:	c7 04 24 2a 20 10 f0 	movl   $0xf010202a,(%esp)
f010132b:	e8 70 f6 ff ff       	call   f01009a0 <cprintf>

	i = 0;
	echoing = iscons(0);
f0101330:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101337:	e8 49 f3 ff ff       	call   f0100685 <iscons>
f010133c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010133e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0101343:	e8 2c f3 ff ff       	call   f0100674 <getchar>
f0101348:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010134a:	85 c0                	test   %eax,%eax
f010134c:	79 17                	jns    f0101365 <readline+0x55>
			cprintf("read error: %e\n", c);
f010134e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101352:	c7 04 24 0c 22 10 f0 	movl   $0xf010220c,(%esp)
f0101359:	e8 42 f6 ff ff       	call   f01009a0 <cprintf>
			return NULL;
f010135e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101363:	eb 6d                	jmp    f01013d2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0101365:	83 f8 7f             	cmp    $0x7f,%eax
f0101368:	74 05                	je     f010136f <readline+0x5f>
f010136a:	83 f8 08             	cmp    $0x8,%eax
f010136d:	75 19                	jne    f0101388 <readline+0x78>
f010136f:	85 f6                	test   %esi,%esi
f0101371:	7e 15                	jle    f0101388 <readline+0x78>
			if (echoing)
f0101373:	85 ff                	test   %edi,%edi
f0101375:	74 0c                	je     f0101383 <readline+0x73>
				cputchar('\b');
f0101377:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010137e:	e8 e1 f2 ff ff       	call   f0100664 <cputchar>
			i--;
f0101383:	83 ee 01             	sub    $0x1,%esi
f0101386:	eb bb                	jmp    f0101343 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0101388:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010138e:	7f 1c                	jg     f01013ac <readline+0x9c>
f0101390:	83 fb 1f             	cmp    $0x1f,%ebx
f0101393:	7e 17                	jle    f01013ac <readline+0x9c>
			if (echoing)
f0101395:	85 ff                	test   %edi,%edi
f0101397:	74 08                	je     f01013a1 <readline+0x91>
				cputchar(c);
f0101399:	89 1c 24             	mov    %ebx,(%esp)
f010139c:	e8 c3 f2 ff ff       	call   f0100664 <cputchar>
			buf[i++] = c;
f01013a1:	88 9e 60 25 11 f0    	mov    %bl,-0xfeedaa0(%esi)
f01013a7:	8d 76 01             	lea    0x1(%esi),%esi
f01013aa:	eb 97                	jmp    f0101343 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f01013ac:	83 fb 0d             	cmp    $0xd,%ebx
f01013af:	74 05                	je     f01013b6 <readline+0xa6>
f01013b1:	83 fb 0a             	cmp    $0xa,%ebx
f01013b4:	75 8d                	jne    f0101343 <readline+0x33>
			if (echoing)
f01013b6:	85 ff                	test   %edi,%edi
f01013b8:	74 0c                	je     f01013c6 <readline+0xb6>
				cputchar('\n');
f01013ba:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01013c1:	e8 9e f2 ff ff       	call   f0100664 <cputchar>
			buf[i] = 0;
f01013c6:	c6 86 60 25 11 f0 00 	movb   $0x0,-0xfeedaa0(%esi)
			return buf;
f01013cd:	b8 60 25 11 f0       	mov    $0xf0112560,%eax
		}
	}
}
f01013d2:	83 c4 1c             	add    $0x1c,%esp
f01013d5:	5b                   	pop    %ebx
f01013d6:	5e                   	pop    %esi
f01013d7:	5f                   	pop    %edi
f01013d8:	5d                   	pop    %ebp
f01013d9:	c3                   	ret    
f01013da:	66 90                	xchg   %ax,%ax
f01013dc:	66 90                	xchg   %ax,%ax
f01013de:	66 90                	xchg   %ax,%ax

f01013e0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01013e0:	55                   	push   %ebp
f01013e1:	89 e5                	mov    %esp,%ebp
f01013e3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01013e6:	80 3a 00             	cmpb   $0x0,(%edx)
f01013e9:	74 10                	je     f01013fb <strlen+0x1b>
f01013eb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01013f0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01013f3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01013f7:	75 f7                	jne    f01013f0 <strlen+0x10>
f01013f9:	eb 05                	jmp    f0101400 <strlen+0x20>
f01013fb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0101400:	5d                   	pop    %ebp
f0101401:	c3                   	ret    

f0101402 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0101402:	55                   	push   %ebp
f0101403:	89 e5                	mov    %esp,%ebp
f0101405:	53                   	push   %ebx
f0101406:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101409:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010140c:	85 c9                	test   %ecx,%ecx
f010140e:	74 1c                	je     f010142c <strnlen+0x2a>
f0101410:	80 3b 00             	cmpb   $0x0,(%ebx)
f0101413:	74 1e                	je     f0101433 <strnlen+0x31>
f0101415:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010141a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010141c:	39 ca                	cmp    %ecx,%edx
f010141e:	74 18                	je     f0101438 <strnlen+0x36>
f0101420:	83 c2 01             	add    $0x1,%edx
f0101423:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0101428:	75 f0                	jne    f010141a <strnlen+0x18>
f010142a:	eb 0c                	jmp    f0101438 <strnlen+0x36>
f010142c:	b8 00 00 00 00       	mov    $0x0,%eax
f0101431:	eb 05                	jmp    f0101438 <strnlen+0x36>
f0101433:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0101438:	5b                   	pop    %ebx
f0101439:	5d                   	pop    %ebp
f010143a:	c3                   	ret    

f010143b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010143b:	55                   	push   %ebp
f010143c:	89 e5                	mov    %esp,%ebp
f010143e:	53                   	push   %ebx
f010143f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101442:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0101445:	89 c2                	mov    %eax,%edx
f0101447:	83 c2 01             	add    $0x1,%edx
f010144a:	83 c1 01             	add    $0x1,%ecx
f010144d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0101451:	88 5a ff             	mov    %bl,-0x1(%edx)
f0101454:	84 db                	test   %bl,%bl
f0101456:	75 ef                	jne    f0101447 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0101458:	5b                   	pop    %ebx
f0101459:	5d                   	pop    %ebp
f010145a:	c3                   	ret    

f010145b <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f010145b:	55                   	push   %ebp
f010145c:	89 e5                	mov    %esp,%ebp
f010145e:	56                   	push   %esi
f010145f:	53                   	push   %ebx
f0101460:	8b 75 08             	mov    0x8(%ebp),%esi
f0101463:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101466:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101469:	85 db                	test   %ebx,%ebx
f010146b:	74 17                	je     f0101484 <strncpy+0x29>
f010146d:	01 f3                	add    %esi,%ebx
f010146f:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0101471:	83 c1 01             	add    $0x1,%ecx
f0101474:	0f b6 02             	movzbl (%edx),%eax
f0101477:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f010147a:	80 3a 01             	cmpb   $0x1,(%edx)
f010147d:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0101480:	39 d9                	cmp    %ebx,%ecx
f0101482:	75 ed                	jne    f0101471 <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0101484:	89 f0                	mov    %esi,%eax
f0101486:	5b                   	pop    %ebx
f0101487:	5e                   	pop    %esi
f0101488:	5d                   	pop    %ebp
f0101489:	c3                   	ret    

f010148a <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f010148a:	55                   	push   %ebp
f010148b:	89 e5                	mov    %esp,%ebp
f010148d:	57                   	push   %edi
f010148e:	56                   	push   %esi
f010148f:	53                   	push   %ebx
f0101490:	8b 7d 08             	mov    0x8(%ebp),%edi
f0101493:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0101496:	8b 75 10             	mov    0x10(%ebp),%esi
f0101499:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f010149b:	85 f6                	test   %esi,%esi
f010149d:	74 34                	je     f01014d3 <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010149f:	83 fe 01             	cmp    $0x1,%esi
f01014a2:	74 26                	je     f01014ca <strlcpy+0x40>
f01014a4:	0f b6 0b             	movzbl (%ebx),%ecx
f01014a7:	84 c9                	test   %cl,%cl
f01014a9:	74 23                	je     f01014ce <strlcpy+0x44>
f01014ab:	83 ee 02             	sub    $0x2,%esi
f01014ae:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f01014b3:	83 c0 01             	add    $0x1,%eax
f01014b6:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f01014b9:	39 f2                	cmp    %esi,%edx
f01014bb:	74 13                	je     f01014d0 <strlcpy+0x46>
f01014bd:	83 c2 01             	add    $0x1,%edx
f01014c0:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01014c4:	84 c9                	test   %cl,%cl
f01014c6:	75 eb                	jne    f01014b3 <strlcpy+0x29>
f01014c8:	eb 06                	jmp    f01014d0 <strlcpy+0x46>
f01014ca:	89 f8                	mov    %edi,%eax
f01014cc:	eb 02                	jmp    f01014d0 <strlcpy+0x46>
f01014ce:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01014d0:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01014d3:	29 f8                	sub    %edi,%eax
}
f01014d5:	5b                   	pop    %ebx
f01014d6:	5e                   	pop    %esi
f01014d7:	5f                   	pop    %edi
f01014d8:	5d                   	pop    %ebp
f01014d9:	c3                   	ret    

f01014da <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01014da:	55                   	push   %ebp
f01014db:	89 e5                	mov    %esp,%ebp
f01014dd:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01014e0:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01014e3:	0f b6 01             	movzbl (%ecx),%eax
f01014e6:	84 c0                	test   %al,%al
f01014e8:	74 15                	je     f01014ff <strcmp+0x25>
f01014ea:	3a 02                	cmp    (%edx),%al
f01014ec:	75 11                	jne    f01014ff <strcmp+0x25>
		p++, q++;
f01014ee:	83 c1 01             	add    $0x1,%ecx
f01014f1:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01014f4:	0f b6 01             	movzbl (%ecx),%eax
f01014f7:	84 c0                	test   %al,%al
f01014f9:	74 04                	je     f01014ff <strcmp+0x25>
f01014fb:	3a 02                	cmp    (%edx),%al
f01014fd:	74 ef                	je     f01014ee <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01014ff:	0f b6 c0             	movzbl %al,%eax
f0101502:	0f b6 12             	movzbl (%edx),%edx
f0101505:	29 d0                	sub    %edx,%eax
}
f0101507:	5d                   	pop    %ebp
f0101508:	c3                   	ret    

f0101509 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0101509:	55                   	push   %ebp
f010150a:	89 e5                	mov    %esp,%ebp
f010150c:	56                   	push   %esi
f010150d:	53                   	push   %ebx
f010150e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101511:	8b 55 0c             	mov    0xc(%ebp),%edx
f0101514:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0101517:	85 f6                	test   %esi,%esi
f0101519:	74 29                	je     f0101544 <strncmp+0x3b>
f010151b:	0f b6 03             	movzbl (%ebx),%eax
f010151e:	84 c0                	test   %al,%al
f0101520:	74 30                	je     f0101552 <strncmp+0x49>
f0101522:	3a 02                	cmp    (%edx),%al
f0101524:	75 2c                	jne    f0101552 <strncmp+0x49>
f0101526:	8d 43 01             	lea    0x1(%ebx),%eax
f0101529:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f010152b:	89 c3                	mov    %eax,%ebx
f010152d:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0101530:	39 f0                	cmp    %esi,%eax
f0101532:	74 17                	je     f010154b <strncmp+0x42>
f0101534:	0f b6 08             	movzbl (%eax),%ecx
f0101537:	84 c9                	test   %cl,%cl
f0101539:	74 17                	je     f0101552 <strncmp+0x49>
f010153b:	83 c0 01             	add    $0x1,%eax
f010153e:	3a 0a                	cmp    (%edx),%cl
f0101540:	74 e9                	je     f010152b <strncmp+0x22>
f0101542:	eb 0e                	jmp    f0101552 <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0101544:	b8 00 00 00 00       	mov    $0x0,%eax
f0101549:	eb 0f                	jmp    f010155a <strncmp+0x51>
f010154b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101550:	eb 08                	jmp    f010155a <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0101552:	0f b6 03             	movzbl (%ebx),%eax
f0101555:	0f b6 12             	movzbl (%edx),%edx
f0101558:	29 d0                	sub    %edx,%eax
}
f010155a:	5b                   	pop    %ebx
f010155b:	5e                   	pop    %esi
f010155c:	5d                   	pop    %ebp
f010155d:	c3                   	ret    

f010155e <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f010155e:	55                   	push   %ebp
f010155f:	89 e5                	mov    %esp,%ebp
f0101561:	53                   	push   %ebx
f0101562:	8b 45 08             	mov    0x8(%ebp),%eax
f0101565:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0101568:	0f b6 18             	movzbl (%eax),%ebx
f010156b:	84 db                	test   %bl,%bl
f010156d:	74 1d                	je     f010158c <strchr+0x2e>
f010156f:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0101571:	38 d3                	cmp    %dl,%bl
f0101573:	75 06                	jne    f010157b <strchr+0x1d>
f0101575:	eb 1a                	jmp    f0101591 <strchr+0x33>
f0101577:	38 ca                	cmp    %cl,%dl
f0101579:	74 16                	je     f0101591 <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f010157b:	83 c0 01             	add    $0x1,%eax
f010157e:	0f b6 10             	movzbl (%eax),%edx
f0101581:	84 d2                	test   %dl,%dl
f0101583:	75 f2                	jne    f0101577 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0101585:	b8 00 00 00 00       	mov    $0x0,%eax
f010158a:	eb 05                	jmp    f0101591 <strchr+0x33>
f010158c:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0101591:	5b                   	pop    %ebx
f0101592:	5d                   	pop    %ebp
f0101593:	c3                   	ret    

f0101594 <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0101594:	55                   	push   %ebp
f0101595:	89 e5                	mov    %esp,%ebp
f0101597:	53                   	push   %ebx
f0101598:	8b 45 08             	mov    0x8(%ebp),%eax
f010159b:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f010159e:	0f b6 18             	movzbl (%eax),%ebx
f01015a1:	84 db                	test   %bl,%bl
f01015a3:	74 17                	je     f01015bc <strfind+0x28>
f01015a5:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01015a7:	38 d3                	cmp    %dl,%bl
f01015a9:	75 07                	jne    f01015b2 <strfind+0x1e>
f01015ab:	eb 0f                	jmp    f01015bc <strfind+0x28>
f01015ad:	38 ca                	cmp    %cl,%dl
f01015af:	90                   	nop
f01015b0:	74 0a                	je     f01015bc <strfind+0x28>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f01015b2:	83 c0 01             	add    $0x1,%eax
f01015b5:	0f b6 10             	movzbl (%eax),%edx
f01015b8:	84 d2                	test   %dl,%dl
f01015ba:	75 f1                	jne    f01015ad <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f01015bc:	5b                   	pop    %ebx
f01015bd:	5d                   	pop    %ebp
f01015be:	c3                   	ret    

f01015bf <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01015bf:	55                   	push   %ebp
f01015c0:	89 e5                	mov    %esp,%ebp
f01015c2:	57                   	push   %edi
f01015c3:	56                   	push   %esi
f01015c4:	53                   	push   %ebx
f01015c5:	8b 7d 08             	mov    0x8(%ebp),%edi
f01015c8:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01015cb:	85 c9                	test   %ecx,%ecx
f01015cd:	74 36                	je     f0101605 <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01015cf:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01015d5:	75 28                	jne    f01015ff <memset+0x40>
f01015d7:	f6 c1 03             	test   $0x3,%cl
f01015da:	75 23                	jne    f01015ff <memset+0x40>
		c &= 0xFF;
f01015dc:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01015e0:	89 d3                	mov    %edx,%ebx
f01015e2:	c1 e3 08             	shl    $0x8,%ebx
f01015e5:	89 d6                	mov    %edx,%esi
f01015e7:	c1 e6 18             	shl    $0x18,%esi
f01015ea:	89 d0                	mov    %edx,%eax
f01015ec:	c1 e0 10             	shl    $0x10,%eax
f01015ef:	09 f0                	or     %esi,%eax
f01015f1:	09 c2                	or     %eax,%edx
f01015f3:	89 d0                	mov    %edx,%eax
f01015f5:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01015f7:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01015fa:	fc                   	cld    
f01015fb:	f3 ab                	rep stos %eax,%es:(%edi)
f01015fd:	eb 06                	jmp    f0101605 <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01015ff:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101602:	fc                   	cld    
f0101603:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0101605:	89 f8                	mov    %edi,%eax
f0101607:	5b                   	pop    %ebx
f0101608:	5e                   	pop    %esi
f0101609:	5f                   	pop    %edi
f010160a:	5d                   	pop    %ebp
f010160b:	c3                   	ret    

f010160c <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f010160c:	55                   	push   %ebp
f010160d:	89 e5                	mov    %esp,%ebp
f010160f:	57                   	push   %edi
f0101610:	56                   	push   %esi
f0101611:	8b 45 08             	mov    0x8(%ebp),%eax
f0101614:	8b 75 0c             	mov    0xc(%ebp),%esi
f0101617:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f010161a:	39 c6                	cmp    %eax,%esi
f010161c:	73 35                	jae    f0101653 <memmove+0x47>
f010161e:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0101621:	39 d0                	cmp    %edx,%eax
f0101623:	73 2e                	jae    f0101653 <memmove+0x47>
		s += n;
		d += n;
f0101625:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0101628:	89 d6                	mov    %edx,%esi
f010162a:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f010162c:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0101632:	75 13                	jne    f0101647 <memmove+0x3b>
f0101634:	f6 c1 03             	test   $0x3,%cl
f0101637:	75 0e                	jne    f0101647 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0101639:	83 ef 04             	sub    $0x4,%edi
f010163c:	8d 72 fc             	lea    -0x4(%edx),%esi
f010163f:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0101642:	fd                   	std    
f0101643:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101645:	eb 09                	jmp    f0101650 <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0101647:	83 ef 01             	sub    $0x1,%edi
f010164a:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f010164d:	fd                   	std    
f010164e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0101650:	fc                   	cld    
f0101651:	eb 1d                	jmp    f0101670 <memmove+0x64>
f0101653:	89 f2                	mov    %esi,%edx
f0101655:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0101657:	f6 c2 03             	test   $0x3,%dl
f010165a:	75 0f                	jne    f010166b <memmove+0x5f>
f010165c:	f6 c1 03             	test   $0x3,%cl
f010165f:	75 0a                	jne    f010166b <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0101661:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0101664:	89 c7                	mov    %eax,%edi
f0101666:	fc                   	cld    
f0101667:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0101669:	eb 05                	jmp    f0101670 <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f010166b:	89 c7                	mov    %eax,%edi
f010166d:	fc                   	cld    
f010166e:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0101670:	5e                   	pop    %esi
f0101671:	5f                   	pop    %edi
f0101672:	5d                   	pop    %ebp
f0101673:	c3                   	ret    

f0101674 <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0101674:	55                   	push   %ebp
f0101675:	89 e5                	mov    %esp,%ebp
f0101677:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f010167a:	8b 45 10             	mov    0x10(%ebp),%eax
f010167d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101681:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101684:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101688:	8b 45 08             	mov    0x8(%ebp),%eax
f010168b:	89 04 24             	mov    %eax,(%esp)
f010168e:	e8 79 ff ff ff       	call   f010160c <memmove>
}
f0101693:	c9                   	leave  
f0101694:	c3                   	ret    

f0101695 <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0101695:	55                   	push   %ebp
f0101696:	89 e5                	mov    %esp,%ebp
f0101698:	57                   	push   %edi
f0101699:	56                   	push   %esi
f010169a:	53                   	push   %ebx
f010169b:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010169e:	8b 75 0c             	mov    0xc(%ebp),%esi
f01016a1:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01016a4:	8d 78 ff             	lea    -0x1(%eax),%edi
f01016a7:	85 c0                	test   %eax,%eax
f01016a9:	74 36                	je     f01016e1 <memcmp+0x4c>
		if (*s1 != *s2)
f01016ab:	0f b6 03             	movzbl (%ebx),%eax
f01016ae:	0f b6 0e             	movzbl (%esi),%ecx
f01016b1:	ba 00 00 00 00       	mov    $0x0,%edx
f01016b6:	38 c8                	cmp    %cl,%al
f01016b8:	74 1c                	je     f01016d6 <memcmp+0x41>
f01016ba:	eb 10                	jmp    f01016cc <memcmp+0x37>
f01016bc:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f01016c1:	83 c2 01             	add    $0x1,%edx
f01016c4:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f01016c8:	38 c8                	cmp    %cl,%al
f01016ca:	74 0a                	je     f01016d6 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f01016cc:	0f b6 c0             	movzbl %al,%eax
f01016cf:	0f b6 c9             	movzbl %cl,%ecx
f01016d2:	29 c8                	sub    %ecx,%eax
f01016d4:	eb 10                	jmp    f01016e6 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01016d6:	39 fa                	cmp    %edi,%edx
f01016d8:	75 e2                	jne    f01016bc <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f01016da:	b8 00 00 00 00       	mov    $0x0,%eax
f01016df:	eb 05                	jmp    f01016e6 <memcmp+0x51>
f01016e1:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01016e6:	5b                   	pop    %ebx
f01016e7:	5e                   	pop    %esi
f01016e8:	5f                   	pop    %edi
f01016e9:	5d                   	pop    %ebp
f01016ea:	c3                   	ret    

f01016eb <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f01016eb:	55                   	push   %ebp
f01016ec:	89 e5                	mov    %esp,%ebp
f01016ee:	53                   	push   %ebx
f01016ef:	8b 45 08             	mov    0x8(%ebp),%eax
f01016f2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f01016f5:	89 c2                	mov    %eax,%edx
f01016f7:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f01016fa:	39 d0                	cmp    %edx,%eax
f01016fc:	73 14                	jae    f0101712 <memfind+0x27>
		if (*(const unsigned char *) s == (unsigned char) c)
f01016fe:	89 d9                	mov    %ebx,%ecx
f0101700:	38 18                	cmp    %bl,(%eax)
f0101702:	75 06                	jne    f010170a <memfind+0x1f>
f0101704:	eb 0c                	jmp    f0101712 <memfind+0x27>
f0101706:	38 08                	cmp    %cl,(%eax)
f0101708:	74 08                	je     f0101712 <memfind+0x27>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f010170a:	83 c0 01             	add    $0x1,%eax
f010170d:	39 d0                	cmp    %edx,%eax
f010170f:	90                   	nop
f0101710:	75 f4                	jne    f0101706 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0101712:	5b                   	pop    %ebx
f0101713:	5d                   	pop    %ebp
f0101714:	c3                   	ret    

f0101715 <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0101715:	55                   	push   %ebp
f0101716:	89 e5                	mov    %esp,%ebp
f0101718:	57                   	push   %edi
f0101719:	56                   	push   %esi
f010171a:	53                   	push   %ebx
f010171b:	8b 55 08             	mov    0x8(%ebp),%edx
f010171e:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101721:	0f b6 0a             	movzbl (%edx),%ecx
f0101724:	80 f9 09             	cmp    $0x9,%cl
f0101727:	74 05                	je     f010172e <strtol+0x19>
f0101729:	80 f9 20             	cmp    $0x20,%cl
f010172c:	75 10                	jne    f010173e <strtol+0x29>
		s++;
f010172e:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0101731:	0f b6 0a             	movzbl (%edx),%ecx
f0101734:	80 f9 09             	cmp    $0x9,%cl
f0101737:	74 f5                	je     f010172e <strtol+0x19>
f0101739:	80 f9 20             	cmp    $0x20,%cl
f010173c:	74 f0                	je     f010172e <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f010173e:	80 f9 2b             	cmp    $0x2b,%cl
f0101741:	75 0a                	jne    f010174d <strtol+0x38>
		s++;
f0101743:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0101746:	bf 00 00 00 00       	mov    $0x0,%edi
f010174b:	eb 11                	jmp    f010175e <strtol+0x49>
f010174d:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0101752:	80 f9 2d             	cmp    $0x2d,%cl
f0101755:	75 07                	jne    f010175e <strtol+0x49>
		s++, neg = 1;
f0101757:	83 c2 01             	add    $0x1,%edx
f010175a:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f010175e:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0101763:	75 15                	jne    f010177a <strtol+0x65>
f0101765:	80 3a 30             	cmpb   $0x30,(%edx)
f0101768:	75 10                	jne    f010177a <strtol+0x65>
f010176a:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f010176e:	75 0a                	jne    f010177a <strtol+0x65>
		s += 2, base = 16;
f0101770:	83 c2 02             	add    $0x2,%edx
f0101773:	b8 10 00 00 00       	mov    $0x10,%eax
f0101778:	eb 10                	jmp    f010178a <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f010177a:	85 c0                	test   %eax,%eax
f010177c:	75 0c                	jne    f010178a <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f010177e:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0101780:	80 3a 30             	cmpb   $0x30,(%edx)
f0101783:	75 05                	jne    f010178a <strtol+0x75>
		s++, base = 8;
f0101785:	83 c2 01             	add    $0x1,%edx
f0101788:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f010178a:	bb 00 00 00 00       	mov    $0x0,%ebx
f010178f:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0101792:	0f b6 0a             	movzbl (%edx),%ecx
f0101795:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0101798:	89 f0                	mov    %esi,%eax
f010179a:	3c 09                	cmp    $0x9,%al
f010179c:	77 08                	ja     f01017a6 <strtol+0x91>
			dig = *s - '0';
f010179e:	0f be c9             	movsbl %cl,%ecx
f01017a1:	83 e9 30             	sub    $0x30,%ecx
f01017a4:	eb 20                	jmp    f01017c6 <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f01017a6:	8d 71 9f             	lea    -0x61(%ecx),%esi
f01017a9:	89 f0                	mov    %esi,%eax
f01017ab:	3c 19                	cmp    $0x19,%al
f01017ad:	77 08                	ja     f01017b7 <strtol+0xa2>
			dig = *s - 'a' + 10;
f01017af:	0f be c9             	movsbl %cl,%ecx
f01017b2:	83 e9 57             	sub    $0x57,%ecx
f01017b5:	eb 0f                	jmp    f01017c6 <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f01017b7:	8d 71 bf             	lea    -0x41(%ecx),%esi
f01017ba:	89 f0                	mov    %esi,%eax
f01017bc:	3c 19                	cmp    $0x19,%al
f01017be:	77 16                	ja     f01017d6 <strtol+0xc1>
			dig = *s - 'A' + 10;
f01017c0:	0f be c9             	movsbl %cl,%ecx
f01017c3:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f01017c6:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f01017c9:	7d 0f                	jge    f01017da <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f01017cb:	83 c2 01             	add    $0x1,%edx
f01017ce:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f01017d2:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f01017d4:	eb bc                	jmp    f0101792 <strtol+0x7d>
f01017d6:	89 d8                	mov    %ebx,%eax
f01017d8:	eb 02                	jmp    f01017dc <strtol+0xc7>
f01017da:	89 d8                	mov    %ebx,%eax

	if (endptr)
f01017dc:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f01017e0:	74 05                	je     f01017e7 <strtol+0xd2>
		*endptr = (char *) s;
f01017e2:	8b 75 0c             	mov    0xc(%ebp),%esi
f01017e5:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f01017e7:	f7 d8                	neg    %eax
f01017e9:	85 ff                	test   %edi,%edi
f01017eb:	0f 44 c3             	cmove  %ebx,%eax
}
f01017ee:	5b                   	pop    %ebx
f01017ef:	5e                   	pop    %esi
f01017f0:	5f                   	pop    %edi
f01017f1:	5d                   	pop    %ebp
f01017f2:	c3                   	ret    
f01017f3:	66 90                	xchg   %ax,%ax
f01017f5:	66 90                	xchg   %ax,%ax
f01017f7:	66 90                	xchg   %ax,%ax
f01017f9:	66 90                	xchg   %ax,%ax
f01017fb:	66 90                	xchg   %ax,%ax
f01017fd:	66 90                	xchg   %ax,%ax
f01017ff:	90                   	nop

f0101800 <__udivdi3>:
f0101800:	55                   	push   %ebp
f0101801:	57                   	push   %edi
f0101802:	56                   	push   %esi
f0101803:	83 ec 0c             	sub    $0xc,%esp
f0101806:	8b 44 24 28          	mov    0x28(%esp),%eax
f010180a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010180e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0101812:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0101816:	85 c0                	test   %eax,%eax
f0101818:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010181c:	89 ea                	mov    %ebp,%edx
f010181e:	89 0c 24             	mov    %ecx,(%esp)
f0101821:	75 2d                	jne    f0101850 <__udivdi3+0x50>
f0101823:	39 e9                	cmp    %ebp,%ecx
f0101825:	77 61                	ja     f0101888 <__udivdi3+0x88>
f0101827:	85 c9                	test   %ecx,%ecx
f0101829:	89 ce                	mov    %ecx,%esi
f010182b:	75 0b                	jne    f0101838 <__udivdi3+0x38>
f010182d:	b8 01 00 00 00       	mov    $0x1,%eax
f0101832:	31 d2                	xor    %edx,%edx
f0101834:	f7 f1                	div    %ecx
f0101836:	89 c6                	mov    %eax,%esi
f0101838:	31 d2                	xor    %edx,%edx
f010183a:	89 e8                	mov    %ebp,%eax
f010183c:	f7 f6                	div    %esi
f010183e:	89 c5                	mov    %eax,%ebp
f0101840:	89 f8                	mov    %edi,%eax
f0101842:	f7 f6                	div    %esi
f0101844:	89 ea                	mov    %ebp,%edx
f0101846:	83 c4 0c             	add    $0xc,%esp
f0101849:	5e                   	pop    %esi
f010184a:	5f                   	pop    %edi
f010184b:	5d                   	pop    %ebp
f010184c:	c3                   	ret    
f010184d:	8d 76 00             	lea    0x0(%esi),%esi
f0101850:	39 e8                	cmp    %ebp,%eax
f0101852:	77 24                	ja     f0101878 <__udivdi3+0x78>
f0101854:	0f bd e8             	bsr    %eax,%ebp
f0101857:	83 f5 1f             	xor    $0x1f,%ebp
f010185a:	75 3c                	jne    f0101898 <__udivdi3+0x98>
f010185c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0101860:	39 34 24             	cmp    %esi,(%esp)
f0101863:	0f 86 9f 00 00 00    	jbe    f0101908 <__udivdi3+0x108>
f0101869:	39 d0                	cmp    %edx,%eax
f010186b:	0f 82 97 00 00 00    	jb     f0101908 <__udivdi3+0x108>
f0101871:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0101878:	31 d2                	xor    %edx,%edx
f010187a:	31 c0                	xor    %eax,%eax
f010187c:	83 c4 0c             	add    $0xc,%esp
f010187f:	5e                   	pop    %esi
f0101880:	5f                   	pop    %edi
f0101881:	5d                   	pop    %ebp
f0101882:	c3                   	ret    
f0101883:	90                   	nop
f0101884:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101888:	89 f8                	mov    %edi,%eax
f010188a:	f7 f1                	div    %ecx
f010188c:	31 d2                	xor    %edx,%edx
f010188e:	83 c4 0c             	add    $0xc,%esp
f0101891:	5e                   	pop    %esi
f0101892:	5f                   	pop    %edi
f0101893:	5d                   	pop    %ebp
f0101894:	c3                   	ret    
f0101895:	8d 76 00             	lea    0x0(%esi),%esi
f0101898:	89 e9                	mov    %ebp,%ecx
f010189a:	8b 3c 24             	mov    (%esp),%edi
f010189d:	d3 e0                	shl    %cl,%eax
f010189f:	89 c6                	mov    %eax,%esi
f01018a1:	b8 20 00 00 00       	mov    $0x20,%eax
f01018a6:	29 e8                	sub    %ebp,%eax
f01018a8:	89 c1                	mov    %eax,%ecx
f01018aa:	d3 ef                	shr    %cl,%edi
f01018ac:	89 e9                	mov    %ebp,%ecx
f01018ae:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01018b2:	8b 3c 24             	mov    (%esp),%edi
f01018b5:	09 74 24 08          	or     %esi,0x8(%esp)
f01018b9:	89 d6                	mov    %edx,%esi
f01018bb:	d3 e7                	shl    %cl,%edi
f01018bd:	89 c1                	mov    %eax,%ecx
f01018bf:	89 3c 24             	mov    %edi,(%esp)
f01018c2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01018c6:	d3 ee                	shr    %cl,%esi
f01018c8:	89 e9                	mov    %ebp,%ecx
f01018ca:	d3 e2                	shl    %cl,%edx
f01018cc:	89 c1                	mov    %eax,%ecx
f01018ce:	d3 ef                	shr    %cl,%edi
f01018d0:	09 d7                	or     %edx,%edi
f01018d2:	89 f2                	mov    %esi,%edx
f01018d4:	89 f8                	mov    %edi,%eax
f01018d6:	f7 74 24 08          	divl   0x8(%esp)
f01018da:	89 d6                	mov    %edx,%esi
f01018dc:	89 c7                	mov    %eax,%edi
f01018de:	f7 24 24             	mull   (%esp)
f01018e1:	39 d6                	cmp    %edx,%esi
f01018e3:	89 14 24             	mov    %edx,(%esp)
f01018e6:	72 30                	jb     f0101918 <__udivdi3+0x118>
f01018e8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01018ec:	89 e9                	mov    %ebp,%ecx
f01018ee:	d3 e2                	shl    %cl,%edx
f01018f0:	39 c2                	cmp    %eax,%edx
f01018f2:	73 05                	jae    f01018f9 <__udivdi3+0xf9>
f01018f4:	3b 34 24             	cmp    (%esp),%esi
f01018f7:	74 1f                	je     f0101918 <__udivdi3+0x118>
f01018f9:	89 f8                	mov    %edi,%eax
f01018fb:	31 d2                	xor    %edx,%edx
f01018fd:	e9 7a ff ff ff       	jmp    f010187c <__udivdi3+0x7c>
f0101902:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0101908:	31 d2                	xor    %edx,%edx
f010190a:	b8 01 00 00 00       	mov    $0x1,%eax
f010190f:	e9 68 ff ff ff       	jmp    f010187c <__udivdi3+0x7c>
f0101914:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101918:	8d 47 ff             	lea    -0x1(%edi),%eax
f010191b:	31 d2                	xor    %edx,%edx
f010191d:	83 c4 0c             	add    $0xc,%esp
f0101920:	5e                   	pop    %esi
f0101921:	5f                   	pop    %edi
f0101922:	5d                   	pop    %ebp
f0101923:	c3                   	ret    
f0101924:	66 90                	xchg   %ax,%ax
f0101926:	66 90                	xchg   %ax,%ax
f0101928:	66 90                	xchg   %ax,%ax
f010192a:	66 90                	xchg   %ax,%ax
f010192c:	66 90                	xchg   %ax,%ax
f010192e:	66 90                	xchg   %ax,%ax

f0101930 <__umoddi3>:
f0101930:	55                   	push   %ebp
f0101931:	57                   	push   %edi
f0101932:	56                   	push   %esi
f0101933:	83 ec 14             	sub    $0x14,%esp
f0101936:	8b 44 24 28          	mov    0x28(%esp),%eax
f010193a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010193e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0101942:	89 c7                	mov    %eax,%edi
f0101944:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101948:	8b 44 24 30          	mov    0x30(%esp),%eax
f010194c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0101950:	89 34 24             	mov    %esi,(%esp)
f0101953:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0101957:	85 c0                	test   %eax,%eax
f0101959:	89 c2                	mov    %eax,%edx
f010195b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010195f:	75 17                	jne    f0101978 <__umoddi3+0x48>
f0101961:	39 fe                	cmp    %edi,%esi
f0101963:	76 4b                	jbe    f01019b0 <__umoddi3+0x80>
f0101965:	89 c8                	mov    %ecx,%eax
f0101967:	89 fa                	mov    %edi,%edx
f0101969:	f7 f6                	div    %esi
f010196b:	89 d0                	mov    %edx,%eax
f010196d:	31 d2                	xor    %edx,%edx
f010196f:	83 c4 14             	add    $0x14,%esp
f0101972:	5e                   	pop    %esi
f0101973:	5f                   	pop    %edi
f0101974:	5d                   	pop    %ebp
f0101975:	c3                   	ret    
f0101976:	66 90                	xchg   %ax,%ax
f0101978:	39 f8                	cmp    %edi,%eax
f010197a:	77 54                	ja     f01019d0 <__umoddi3+0xa0>
f010197c:	0f bd e8             	bsr    %eax,%ebp
f010197f:	83 f5 1f             	xor    $0x1f,%ebp
f0101982:	75 5c                	jne    f01019e0 <__umoddi3+0xb0>
f0101984:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0101988:	39 3c 24             	cmp    %edi,(%esp)
f010198b:	0f 87 e7 00 00 00    	ja     f0101a78 <__umoddi3+0x148>
f0101991:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0101995:	29 f1                	sub    %esi,%ecx
f0101997:	19 c7                	sbb    %eax,%edi
f0101999:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010199d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01019a1:	8b 44 24 08          	mov    0x8(%esp),%eax
f01019a5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01019a9:	83 c4 14             	add    $0x14,%esp
f01019ac:	5e                   	pop    %esi
f01019ad:	5f                   	pop    %edi
f01019ae:	5d                   	pop    %ebp
f01019af:	c3                   	ret    
f01019b0:	85 f6                	test   %esi,%esi
f01019b2:	89 f5                	mov    %esi,%ebp
f01019b4:	75 0b                	jne    f01019c1 <__umoddi3+0x91>
f01019b6:	b8 01 00 00 00       	mov    $0x1,%eax
f01019bb:	31 d2                	xor    %edx,%edx
f01019bd:	f7 f6                	div    %esi
f01019bf:	89 c5                	mov    %eax,%ebp
f01019c1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01019c5:	31 d2                	xor    %edx,%edx
f01019c7:	f7 f5                	div    %ebp
f01019c9:	89 c8                	mov    %ecx,%eax
f01019cb:	f7 f5                	div    %ebp
f01019cd:	eb 9c                	jmp    f010196b <__umoddi3+0x3b>
f01019cf:	90                   	nop
f01019d0:	89 c8                	mov    %ecx,%eax
f01019d2:	89 fa                	mov    %edi,%edx
f01019d4:	83 c4 14             	add    $0x14,%esp
f01019d7:	5e                   	pop    %esi
f01019d8:	5f                   	pop    %edi
f01019d9:	5d                   	pop    %ebp
f01019da:	c3                   	ret    
f01019db:	90                   	nop
f01019dc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01019e0:	8b 04 24             	mov    (%esp),%eax
f01019e3:	be 20 00 00 00       	mov    $0x20,%esi
f01019e8:	89 e9                	mov    %ebp,%ecx
f01019ea:	29 ee                	sub    %ebp,%esi
f01019ec:	d3 e2                	shl    %cl,%edx
f01019ee:	89 f1                	mov    %esi,%ecx
f01019f0:	d3 e8                	shr    %cl,%eax
f01019f2:	89 e9                	mov    %ebp,%ecx
f01019f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01019f8:	8b 04 24             	mov    (%esp),%eax
f01019fb:	09 54 24 04          	or     %edx,0x4(%esp)
f01019ff:	89 fa                	mov    %edi,%edx
f0101a01:	d3 e0                	shl    %cl,%eax
f0101a03:	89 f1                	mov    %esi,%ecx
f0101a05:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101a09:	8b 44 24 10          	mov    0x10(%esp),%eax
f0101a0d:	d3 ea                	shr    %cl,%edx
f0101a0f:	89 e9                	mov    %ebp,%ecx
f0101a11:	d3 e7                	shl    %cl,%edi
f0101a13:	89 f1                	mov    %esi,%ecx
f0101a15:	d3 e8                	shr    %cl,%eax
f0101a17:	89 e9                	mov    %ebp,%ecx
f0101a19:	09 f8                	or     %edi,%eax
f0101a1b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0101a1f:	f7 74 24 04          	divl   0x4(%esp)
f0101a23:	d3 e7                	shl    %cl,%edi
f0101a25:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0101a29:	89 d7                	mov    %edx,%edi
f0101a2b:	f7 64 24 08          	mull   0x8(%esp)
f0101a2f:	39 d7                	cmp    %edx,%edi
f0101a31:	89 c1                	mov    %eax,%ecx
f0101a33:	89 14 24             	mov    %edx,(%esp)
f0101a36:	72 2c                	jb     f0101a64 <__umoddi3+0x134>
f0101a38:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0101a3c:	72 22                	jb     f0101a60 <__umoddi3+0x130>
f0101a3e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0101a42:	29 c8                	sub    %ecx,%eax
f0101a44:	19 d7                	sbb    %edx,%edi
f0101a46:	89 e9                	mov    %ebp,%ecx
f0101a48:	89 fa                	mov    %edi,%edx
f0101a4a:	d3 e8                	shr    %cl,%eax
f0101a4c:	89 f1                	mov    %esi,%ecx
f0101a4e:	d3 e2                	shl    %cl,%edx
f0101a50:	89 e9                	mov    %ebp,%ecx
f0101a52:	d3 ef                	shr    %cl,%edi
f0101a54:	09 d0                	or     %edx,%eax
f0101a56:	89 fa                	mov    %edi,%edx
f0101a58:	83 c4 14             	add    $0x14,%esp
f0101a5b:	5e                   	pop    %esi
f0101a5c:	5f                   	pop    %edi
f0101a5d:	5d                   	pop    %ebp
f0101a5e:	c3                   	ret    
f0101a5f:	90                   	nop
f0101a60:	39 d7                	cmp    %edx,%edi
f0101a62:	75 da                	jne    f0101a3e <__umoddi3+0x10e>
f0101a64:	8b 14 24             	mov    (%esp),%edx
f0101a67:	89 c1                	mov    %eax,%ecx
f0101a69:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0101a6d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0101a71:	eb cb                	jmp    f0101a3e <__umoddi3+0x10e>
f0101a73:	90                   	nop
f0101a74:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0101a78:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0101a7c:	0f 82 0f ff ff ff    	jb     f0101991 <__umoddi3+0x61>
f0101a82:	e9 1a ff ff ff       	jmp    f01019a1 <__umoddi3+0x71>
