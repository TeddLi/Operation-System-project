
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
f0100015:	b8 00 e0 11 00       	mov    $0x11e000,%eax
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
f0100034:	bc 00 e0 11 f0       	mov    $0xf011e000,%esp

	# now to C code
	call	i386_init
f0100039:	e8 6a 00 00 00       	call   f01000a8 <i386_init>

f010003e <spin>:

	# Should never get here, but in case we do, just spin.
spin:	jmp	spin
f010003e:	eb fe                	jmp    f010003e <spin>

f0100040 <_panic>:
 * Panic is called on unresolvable fatal errors.
 * It prints "panic: mesg", and then enters the kernel monitor.
 */
void
_panic(const char *file, int line, const char *fmt,...)
{
f0100040:	55                   	push   %ebp
f0100041:	89 e5                	mov    %esp,%ebp
f0100043:	56                   	push   %esi
f0100044:	53                   	push   %ebx
f0100045:	83 ec 10             	sub    $0x10,%esp
f0100048:	8b 75 10             	mov    0x10(%ebp),%esi
	va_list ap;

	if (panicstr)
f010004b:	83 3d 80 3e 22 f0 00 	cmpl   $0x0,0xf0223e80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 3e 22 f0    	mov    %esi,0xf0223e80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 4f 5f 00 00       	call   f0105fb3 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 c0 66 10 f0 	movl   $0xf01066c0,(%esp)
f010007d:	e8 af 40 00 00       	call   f0104131 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 70 40 00 00       	call   f01040fe <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 b2 77 10 f0 	movl   $0xf01077b2,(%esp)
f0100095:	e8 97 40 00 00       	call   f0104131 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 01 09 00 00       	call   f01009a7 <monitor>
f01000a6:	eb f2                	jmp    f010009a <_panic+0x5a>

f01000a8 <i386_init>:
static void boot_aps(void);


void
i386_init(void)
{
f01000a8:	55                   	push   %ebp
f01000a9:	89 e5                	mov    %esp,%ebp
f01000ab:	53                   	push   %ebx
f01000ac:	83 ec 14             	sub    $0x14,%esp
	extern char edata[], end[];

	// Before doing anything else, complete the ELF loading process.
	// Clear the uninitialized global data (BSS) section of our program.
	// This ensures that all static/global variables start out zero.
	memset(edata, 0, end - edata);
f01000af:	b8 04 50 26 f0       	mov    $0xf0265004,%eax
f01000b4:	2d 88 21 22 f0       	sub    $0xf0222188,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 88 21 22 f0 	movl   $0xf0222188,(%esp)
f01000cc:	e8 48 58 00 00       	call   f0105919 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 09 06 00 00       	call   f01006df <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 2c 67 10 f0 	movl   $0xf010672c,(%esp)
f01000e5:	e8 47 40 00 00       	call   f0104131 <cprintf>

	// Lab 2 memory management initialization functions
	cprintf("mem_init 1!\n", 6828);
f01000ea:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000f1:	00 
f01000f2:	c7 04 24 47 67 10 f0 	movl   $0xf0106747,(%esp)
f01000f9:	e8 33 40 00 00       	call   f0104131 <cprintf>
	mem_init();
f01000fe:	e8 a3 13 00 00       	call   f01014a6 <mem_init>
	cprintf("mem_init 2!\n", 6828);
f0100103:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f010010a:	00 
f010010b:	c7 04 24 54 67 10 f0 	movl   $0xf0106754,(%esp)
f0100112:	e8 1a 40 00 00       	call   f0104131 <cprintf>
	// Lab 3 user environment initialization functions
	env_init();
f0100117:	e8 2e 37 00 00       	call   f010384a <env_init>
	trap_init();
f010011c:	e8 fa 40 00 00       	call   f010421b <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f0100121:	e8 73 5b 00 00       	call   f0105c99 <mp_init>
	lapic_init();
f0100126:	e8 a3 5e 00 00       	call   f0105fce <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f010012b:	90                   	nop
f010012c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100130:	e8 29 3f 00 00       	call   f010405e <pic_init>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100135:	83 3d 88 3e 22 f0 07 	cmpl   $0x7,0xf0223e88
f010013c:	77 24                	ja     f0100162 <i386_init+0xba>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010013e:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100145:	00 
f0100146:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f010014d:	f0 
f010014e:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f0100155:	00 
f0100156:	c7 04 24 61 67 10 f0 	movl   $0xf0106761,(%esp)
f010015d:	e8 de fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100162:	b8 c6 5b 10 f0       	mov    $0xf0105bc6,%eax
f0100167:	2d 4c 5b 10 f0       	sub    $0xf0105b4c,%eax
f010016c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100170:	c7 44 24 04 4c 5b 10 	movl   $0xf0105b4c,0x4(%esp)
f0100177:	f0 
f0100178:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f010017f:	e8 e2 57 00 00       	call   f0105966 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100184:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f010018b:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0100190:	3d 20 40 22 f0       	cmp    $0xf0224020,%eax
f0100195:	0f 86 a6 00 00 00    	jbe    f0100241 <i386_init+0x199>
f010019b:	bb 20 40 22 f0       	mov    $0xf0224020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f01001a0:	e8 0e 5e 00 00       	call   f0105fb3 <cpunum>
f01001a5:	6b c0 74             	imul   $0x74,%eax,%eax
f01001a8:	05 20 40 22 f0       	add    $0xf0224020,%eax
f01001ad:	39 c3                	cmp    %eax,%ebx
f01001af:	74 39                	je     f01001ea <i386_init+0x142>
f01001b1:	89 d8                	mov    %ebx,%eax
f01001b3:	2d 20 40 22 f0       	sub    $0xf0224020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f01001b8:	c1 f8 02             	sar    $0x2,%eax
f01001bb:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001c1:	c1 e0 0f             	shl    $0xf,%eax
f01001c4:	8d 80 00 d0 22 f0    	lea    -0xfdd3000(%eax),%eax
f01001ca:	a3 84 3e 22 f0       	mov    %eax,0xf0223e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001cf:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001d6:	00 
f01001d7:	0f b6 03             	movzbl (%ebx),%eax
f01001da:	89 04 24             	mov    %eax,(%esp)
f01001dd:	e8 24 5f 00 00       	call   f0106106 <lapic_startap>
		// Wait for the CPU to finish some basic setup in mp_main()
		while(c->cpu_status != CPU_STARTED)
f01001e2:	8b 43 04             	mov    0x4(%ebx),%eax
f01001e5:	83 f8 01             	cmp    $0x1,%eax
f01001e8:	75 f8                	jne    f01001e2 <i386_init+0x13a>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f01001ea:	83 c3 74             	add    $0x74,%ebx
f01001ed:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f01001f4:	05 20 40 22 f0       	add    $0xf0224020,%eax
f01001f9:	39 c3                	cmp    %eax,%ebx
f01001fb:	72 a3                	jb     f01001a0 <i386_init+0xf8>
f01001fd:	eb 42                	jmp    f0100241 <i386_init+0x199>
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001ff:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0100206:	00 
f0100207:	c7 44 24 04 46 89 00 	movl   $0x8946,0x4(%esp)
f010020e:	00 
f010020f:	c7 04 24 f4 fc 18 f0 	movl   $0xf018fcf4,(%esp)
f0100216:	e8 61 38 00 00       	call   f0103a7c <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
f010021b:	83 eb 01             	sub    $0x1,%ebx
f010021e:	75 df                	jne    f01001ff <i386_init+0x157>
#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	ENV_CREATE(user_primes, ENV_TYPE_USER);
f0100220:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100227:	00 
f0100228:	c7 44 24 04 09 8a 00 	movl   $0x8a09,0x4(%esp)
f010022f:	00 
f0100230:	c7 04 24 7f 97 21 f0 	movl   $0xf021977f,(%esp)
f0100237:	e8 40 38 00 00       	call   f0103a7c <env_create>
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f010023c:	e8 d4 47 00 00       	call   f0104a15 <sched_yield>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100241:	bb 08 00 00 00       	mov    $0x8,%ebx
f0100246:	eb b7                	jmp    f01001ff <i386_init+0x157>

f0100248 <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f0100248:	55                   	push   %ebp
f0100249:	89 e5                	mov    %esp,%ebp
f010024b:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f010024e:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100253:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100258:	77 20                	ja     f010027a <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010025a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010025e:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0100265:	f0 
f0100266:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
f010026d:	00 
f010026e:	c7 04 24 61 67 10 f0 	movl   $0xf0106761,(%esp)
f0100275:	e8 c6 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010027a:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010027f:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100282:	e8 2c 5d 00 00       	call   f0105fb3 <cpunum>
f0100287:	89 44 24 04          	mov    %eax,0x4(%esp)
f010028b:	c7 04 24 6d 67 10 f0 	movl   $0xf010676d,(%esp)
f0100292:	e8 9a 3e 00 00       	call   f0104131 <cprintf>

	lapic_init();
f0100297:	e8 32 5d 00 00       	call   f0105fce <lapic_init>
	env_init_percpu();
f010029c:	e8 7f 35 00 00       	call   f0103820 <env_init_percpu>
	trap_init_percpu();
f01002a1:	e8 a5 3e 00 00       	call   f010414b <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f01002a6:	e8 08 5d 00 00       	call   f0105fb3 <cpunum>
f01002ab:	6b d0 74             	imul   $0x74,%eax,%edx
f01002ae:	81 c2 20 40 22 f0    	add    $0xf0224020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01002b4:	b8 01 00 00 00       	mov    $0x1,%eax
f01002b9:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f01002bd:	eb fe                	jmp    f01002bd <mp_main+0x75>

f01002bf <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002bf:	55                   	push   %ebp
f01002c0:	89 e5                	mov    %esp,%ebp
f01002c2:	53                   	push   %ebx
f01002c3:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002c6:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002c9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002cc:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002d0:	8b 45 08             	mov    0x8(%ebp),%eax
f01002d3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002d7:	c7 04 24 83 67 10 f0 	movl   $0xf0106783,(%esp)
f01002de:	e8 4e 3e 00 00       	call   f0104131 <cprintf>
	vcprintf(fmt, ap);
f01002e3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002e7:	8b 45 10             	mov    0x10(%ebp),%eax
f01002ea:	89 04 24             	mov    %eax,(%esp)
f01002ed:	e8 0c 3e 00 00       	call   f01040fe <vcprintf>
	cprintf("\n");
f01002f2:	c7 04 24 b2 77 10 f0 	movl   $0xf01077b2,(%esp)
f01002f9:	e8 33 3e 00 00       	call   f0104131 <cprintf>
	va_end(ap);
}
f01002fe:	83 c4 14             	add    $0x14,%esp
f0100301:	5b                   	pop    %ebx
f0100302:	5d                   	pop    %ebp
f0100303:	c3                   	ret    
f0100304:	66 90                	xchg   %ax,%ax
f0100306:	66 90                	xchg   %ax,%ax
f0100308:	66 90                	xchg   %ax,%ax
f010030a:	66 90                	xchg   %ax,%ax
f010030c:	66 90                	xchg   %ax,%ax
f010030e:	66 90                	xchg   %ax,%ax

f0100310 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100310:	55                   	push   %ebp
f0100311:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100313:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100318:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100319:	a8 01                	test   $0x1,%al
f010031b:	74 08                	je     f0100325 <serial_proc_data+0x15>
f010031d:	b2 f8                	mov    $0xf8,%dl
f010031f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100320:	0f b6 c0             	movzbl %al,%eax
f0100323:	eb 05                	jmp    f010032a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100325:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010032a:	5d                   	pop    %ebp
f010032b:	c3                   	ret    

f010032c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010032c:	55                   	push   %ebp
f010032d:	89 e5                	mov    %esp,%ebp
f010032f:	53                   	push   %ebx
f0100330:	83 ec 04             	sub    $0x4,%esp
f0100333:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100335:	eb 2a                	jmp    f0100361 <cons_intr+0x35>
		if (c == 0)
f0100337:	85 d2                	test   %edx,%edx
f0100339:	74 26                	je     f0100361 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010033b:	a1 24 32 22 f0       	mov    0xf0223224,%eax
f0100340:	8d 48 01             	lea    0x1(%eax),%ecx
f0100343:	89 0d 24 32 22 f0    	mov    %ecx,0xf0223224
f0100349:	88 90 20 30 22 f0    	mov    %dl,-0xfddcfe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010034f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100355:	75 0a                	jne    f0100361 <cons_intr+0x35>
			cons.wpos = 0;
f0100357:	c7 05 24 32 22 f0 00 	movl   $0x0,0xf0223224
f010035e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100361:	ff d3                	call   *%ebx
f0100363:	89 c2                	mov    %eax,%edx
f0100365:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100368:	75 cd                	jne    f0100337 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010036a:	83 c4 04             	add    $0x4,%esp
f010036d:	5b                   	pop    %ebx
f010036e:	5d                   	pop    %ebp
f010036f:	c3                   	ret    

f0100370 <kbd_proc_data>:
f0100370:	ba 64 00 00 00       	mov    $0x64,%edx
f0100375:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100376:	a8 01                	test   $0x1,%al
f0100378:	0f 84 ef 00 00 00    	je     f010046d <kbd_proc_data+0xfd>
f010037e:	b2 60                	mov    $0x60,%dl
f0100380:	ec                   	in     (%dx),%al
f0100381:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100383:	3c e0                	cmp    $0xe0,%al
f0100385:	75 0d                	jne    f0100394 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100387:	83 0d 00 30 22 f0 40 	orl    $0x40,0xf0223000
		return 0;
f010038e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100393:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100394:	55                   	push   %ebp
f0100395:	89 e5                	mov    %esp,%ebp
f0100397:	53                   	push   %ebx
f0100398:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010039b:	84 c0                	test   %al,%al
f010039d:	79 37                	jns    f01003d6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010039f:	8b 0d 00 30 22 f0    	mov    0xf0223000,%ecx
f01003a5:	89 cb                	mov    %ecx,%ebx
f01003a7:	83 e3 40             	and    $0x40,%ebx
f01003aa:	83 e0 7f             	and    $0x7f,%eax
f01003ad:	85 db                	test   %ebx,%ebx
f01003af:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003b2:	0f b6 d2             	movzbl %dl,%edx
f01003b5:	0f b6 82 00 69 10 f0 	movzbl -0xfef9700(%edx),%eax
f01003bc:	83 c8 40             	or     $0x40,%eax
f01003bf:	0f b6 c0             	movzbl %al,%eax
f01003c2:	f7 d0                	not    %eax
f01003c4:	21 c1                	and    %eax,%ecx
f01003c6:	89 0d 00 30 22 f0    	mov    %ecx,0xf0223000
		return 0;
f01003cc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003d1:	e9 9d 00 00 00       	jmp    f0100473 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003d6:	8b 0d 00 30 22 f0    	mov    0xf0223000,%ecx
f01003dc:	f6 c1 40             	test   $0x40,%cl
f01003df:	74 0e                	je     f01003ef <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003e1:	83 c8 80             	or     $0xffffff80,%eax
f01003e4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003e6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003e9:	89 0d 00 30 22 f0    	mov    %ecx,0xf0223000
	}

	shift |= shiftcode[data];
f01003ef:	0f b6 d2             	movzbl %dl,%edx
f01003f2:	0f b6 82 00 69 10 f0 	movzbl -0xfef9700(%edx),%eax
f01003f9:	0b 05 00 30 22 f0    	or     0xf0223000,%eax
	shift ^= togglecode[data];
f01003ff:	0f b6 8a 00 68 10 f0 	movzbl -0xfef9800(%edx),%ecx
f0100406:	31 c8                	xor    %ecx,%eax
f0100408:	a3 00 30 22 f0       	mov    %eax,0xf0223000

	c = charcode[shift & (CTL | SHIFT)][data];
f010040d:	89 c1                	mov    %eax,%ecx
f010040f:	83 e1 03             	and    $0x3,%ecx
f0100412:	8b 0c 8d e0 67 10 f0 	mov    -0xfef9820(,%ecx,4),%ecx
f0100419:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010041d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100420:	a8 08                	test   $0x8,%al
f0100422:	74 1b                	je     f010043f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100424:	89 da                	mov    %ebx,%edx
f0100426:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100429:	83 f9 19             	cmp    $0x19,%ecx
f010042c:	77 05                	ja     f0100433 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010042e:	83 eb 20             	sub    $0x20,%ebx
f0100431:	eb 0c                	jmp    f010043f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100433:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100436:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100439:	83 fa 19             	cmp    $0x19,%edx
f010043c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010043f:	f7 d0                	not    %eax
f0100441:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100443:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100445:	f6 c2 06             	test   $0x6,%dl
f0100448:	75 29                	jne    f0100473 <kbd_proc_data+0x103>
f010044a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100450:	75 21                	jne    f0100473 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100452:	c7 04 24 9d 67 10 f0 	movl   $0xf010679d,(%esp)
f0100459:	e8 d3 3c 00 00       	call   f0104131 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010045e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100463:	b8 03 00 00 00       	mov    $0x3,%eax
f0100468:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100469:	89 d8                	mov    %ebx,%eax
f010046b:	eb 06                	jmp    f0100473 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010046d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100472:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100473:	83 c4 14             	add    $0x14,%esp
f0100476:	5b                   	pop    %ebx
f0100477:	5d                   	pop    %ebp
f0100478:	c3                   	ret    

f0100479 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100479:	55                   	push   %ebp
f010047a:	89 e5                	mov    %esp,%ebp
f010047c:	57                   	push   %edi
f010047d:	56                   	push   %esi
f010047e:	53                   	push   %ebx
f010047f:	83 ec 1c             	sub    $0x1c,%esp
f0100482:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100484:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100489:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010048a:	a8 20                	test   $0x20,%al
f010048c:	75 21                	jne    f01004af <cons_putc+0x36>
f010048e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100493:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100498:	be fd 03 00 00       	mov    $0x3fd,%esi
f010049d:	89 ca                	mov    %ecx,%edx
f010049f:	ec                   	in     (%dx),%al
f01004a0:	ec                   	in     (%dx),%al
f01004a1:	ec                   	in     (%dx),%al
f01004a2:	ec                   	in     (%dx),%al
f01004a3:	89 f2                	mov    %esi,%edx
f01004a5:	ec                   	in     (%dx),%al
f01004a6:	a8 20                	test   $0x20,%al
f01004a8:	75 05                	jne    f01004af <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01004aa:	83 eb 01             	sub    $0x1,%ebx
f01004ad:	75 ee                	jne    f010049d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f01004af:	89 f8                	mov    %edi,%eax
f01004b1:	0f b6 c0             	movzbl %al,%eax
f01004b4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004b7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004bc:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004bd:	b2 79                	mov    $0x79,%dl
f01004bf:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004c0:	84 c0                	test   %al,%al
f01004c2:	78 21                	js     f01004e5 <cons_putc+0x6c>
f01004c4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004c9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004ce:	be 79 03 00 00       	mov    $0x379,%esi
f01004d3:	89 ca                	mov    %ecx,%edx
f01004d5:	ec                   	in     (%dx),%al
f01004d6:	ec                   	in     (%dx),%al
f01004d7:	ec                   	in     (%dx),%al
f01004d8:	ec                   	in     (%dx),%al
f01004d9:	89 f2                	mov    %esi,%edx
f01004db:	ec                   	in     (%dx),%al
f01004dc:	84 c0                	test   %al,%al
f01004de:	78 05                	js     f01004e5 <cons_putc+0x6c>
f01004e0:	83 eb 01             	sub    $0x1,%ebx
f01004e3:	75 ee                	jne    f01004d3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004e5:	ba 78 03 00 00       	mov    $0x378,%edx
f01004ea:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004ee:	ee                   	out    %al,(%dx)
f01004ef:	b2 7a                	mov    $0x7a,%dl
f01004f1:	b8 0d 00 00 00       	mov    $0xd,%eax
f01004f6:	ee                   	out    %al,(%dx)
f01004f7:	b8 08 00 00 00       	mov    $0x8,%eax
f01004fc:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f01004fd:	89 fa                	mov    %edi,%edx
f01004ff:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100505:	89 f8                	mov    %edi,%eax
f0100507:	80 cc 07             	or     $0x7,%ah
f010050a:	85 d2                	test   %edx,%edx
f010050c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010050f:	89 f8                	mov    %edi,%eax
f0100511:	0f b6 c0             	movzbl %al,%eax
f0100514:	83 f8 09             	cmp    $0x9,%eax
f0100517:	74 79                	je     f0100592 <cons_putc+0x119>
f0100519:	83 f8 09             	cmp    $0x9,%eax
f010051c:	7f 0a                	jg     f0100528 <cons_putc+0xaf>
f010051e:	83 f8 08             	cmp    $0x8,%eax
f0100521:	74 19                	je     f010053c <cons_putc+0xc3>
f0100523:	e9 9e 00 00 00       	jmp    f01005c6 <cons_putc+0x14d>
f0100528:	83 f8 0a             	cmp    $0xa,%eax
f010052b:	90                   	nop
f010052c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100530:	74 3a                	je     f010056c <cons_putc+0xf3>
f0100532:	83 f8 0d             	cmp    $0xd,%eax
f0100535:	74 3d                	je     f0100574 <cons_putc+0xfb>
f0100537:	e9 8a 00 00 00       	jmp    f01005c6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010053c:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f0100543:	66 85 c0             	test   %ax,%ax
f0100546:	0f 84 e5 00 00 00    	je     f0100631 <cons_putc+0x1b8>
			crt_pos--;
f010054c:	83 e8 01             	sub    $0x1,%eax
f010054f:	66 a3 28 32 22 f0    	mov    %ax,0xf0223228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100555:	0f b7 c0             	movzwl %ax,%eax
f0100558:	66 81 e7 00 ff       	and    $0xff00,%di
f010055d:	83 cf 20             	or     $0x20,%edi
f0100560:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
f0100566:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010056a:	eb 78                	jmp    f01005e4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010056c:	66 83 05 28 32 22 f0 	addw   $0x50,0xf0223228
f0100573:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100574:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f010057b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100581:	c1 e8 16             	shr    $0x16,%eax
f0100584:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100587:	c1 e0 04             	shl    $0x4,%eax
f010058a:	66 a3 28 32 22 f0    	mov    %ax,0xf0223228
f0100590:	eb 52                	jmp    f01005e4 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100592:	b8 20 00 00 00       	mov    $0x20,%eax
f0100597:	e8 dd fe ff ff       	call   f0100479 <cons_putc>
		cons_putc(' ');
f010059c:	b8 20 00 00 00       	mov    $0x20,%eax
f01005a1:	e8 d3 fe ff ff       	call   f0100479 <cons_putc>
		cons_putc(' ');
f01005a6:	b8 20 00 00 00       	mov    $0x20,%eax
f01005ab:	e8 c9 fe ff ff       	call   f0100479 <cons_putc>
		cons_putc(' ');
f01005b0:	b8 20 00 00 00       	mov    $0x20,%eax
f01005b5:	e8 bf fe ff ff       	call   f0100479 <cons_putc>
		cons_putc(' ');
f01005ba:	b8 20 00 00 00       	mov    $0x20,%eax
f01005bf:	e8 b5 fe ff ff       	call   f0100479 <cons_putc>
f01005c4:	eb 1e                	jmp    f01005e4 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005c6:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f01005cd:	8d 50 01             	lea    0x1(%eax),%edx
f01005d0:	66 89 15 28 32 22 f0 	mov    %dx,0xf0223228
f01005d7:	0f b7 c0             	movzwl %ax,%eax
f01005da:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
f01005e0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005e4:	66 81 3d 28 32 22 f0 	cmpw   $0x7cf,0xf0223228
f01005eb:	cf 07 
f01005ed:	76 42                	jbe    f0100631 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005ef:	a1 2c 32 22 f0       	mov    0xf022322c,%eax
f01005f4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005fb:	00 
f01005fc:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100602:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100606:	89 04 24             	mov    %eax,(%esp)
f0100609:	e8 58 53 00 00       	call   f0105966 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010060e:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100614:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100619:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010061f:	83 c0 01             	add    $0x1,%eax
f0100622:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100627:	75 f0                	jne    f0100619 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100629:	66 83 2d 28 32 22 f0 	subw   $0x50,0xf0223228
f0100630:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100631:	8b 0d 30 32 22 f0    	mov    0xf0223230,%ecx
f0100637:	b8 0e 00 00 00       	mov    $0xe,%eax
f010063c:	89 ca                	mov    %ecx,%edx
f010063e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010063f:	0f b7 1d 28 32 22 f0 	movzwl 0xf0223228,%ebx
f0100646:	8d 71 01             	lea    0x1(%ecx),%esi
f0100649:	89 d8                	mov    %ebx,%eax
f010064b:	66 c1 e8 08          	shr    $0x8,%ax
f010064f:	89 f2                	mov    %esi,%edx
f0100651:	ee                   	out    %al,(%dx)
f0100652:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100657:	89 ca                	mov    %ecx,%edx
f0100659:	ee                   	out    %al,(%dx)
f010065a:	89 d8                	mov    %ebx,%eax
f010065c:	89 f2                	mov    %esi,%edx
f010065e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010065f:	83 c4 1c             	add    $0x1c,%esp
f0100662:	5b                   	pop    %ebx
f0100663:	5e                   	pop    %esi
f0100664:	5f                   	pop    %edi
f0100665:	5d                   	pop    %ebp
f0100666:	c3                   	ret    

f0100667 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100667:	83 3d 34 32 22 f0 00 	cmpl   $0x0,0xf0223234
f010066e:	74 11                	je     f0100681 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100670:	55                   	push   %ebp
f0100671:	89 e5                	mov    %esp,%ebp
f0100673:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100676:	b8 10 03 10 f0       	mov    $0xf0100310,%eax
f010067b:	e8 ac fc ff ff       	call   f010032c <cons_intr>
}
f0100680:	c9                   	leave  
f0100681:	f3 c3                	repz ret 

f0100683 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100683:	55                   	push   %ebp
f0100684:	89 e5                	mov    %esp,%ebp
f0100686:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100689:	b8 70 03 10 f0       	mov    $0xf0100370,%eax
f010068e:	e8 99 fc ff ff       	call   f010032c <cons_intr>
}
f0100693:	c9                   	leave  
f0100694:	c3                   	ret    

f0100695 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100695:	55                   	push   %ebp
f0100696:	89 e5                	mov    %esp,%ebp
f0100698:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010069b:	e8 c7 ff ff ff       	call   f0100667 <serial_intr>
	kbd_intr();
f01006a0:	e8 de ff ff ff       	call   f0100683 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01006a5:	a1 20 32 22 f0       	mov    0xf0223220,%eax
f01006aa:	3b 05 24 32 22 f0    	cmp    0xf0223224,%eax
f01006b0:	74 26                	je     f01006d8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006b2:	8d 50 01             	lea    0x1(%eax),%edx
f01006b5:	89 15 20 32 22 f0    	mov    %edx,0xf0223220
f01006bb:	0f b6 88 20 30 22 f0 	movzbl -0xfddcfe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006c2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006c4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006ca:	75 11                	jne    f01006dd <cons_getc+0x48>
			cons.rpos = 0;
f01006cc:	c7 05 20 32 22 f0 00 	movl   $0x0,0xf0223220
f01006d3:	00 00 00 
f01006d6:	eb 05                	jmp    f01006dd <cons_getc+0x48>
		return c;
	}
	return 0;
f01006d8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006dd:	c9                   	leave  
f01006de:	c3                   	ret    

f01006df <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006df:	55                   	push   %ebp
f01006e0:	89 e5                	mov    %esp,%ebp
f01006e2:	57                   	push   %edi
f01006e3:	56                   	push   %esi
f01006e4:	53                   	push   %ebx
f01006e5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006e8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006ef:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f01006f6:	5a a5 
	if (*cp != 0xA55A) {
f01006f8:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f01006ff:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100703:	74 11                	je     f0100716 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100705:	c7 05 30 32 22 f0 b4 	movl   $0x3b4,0xf0223230
f010070c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010070f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100714:	eb 16                	jmp    f010072c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100716:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010071d:	c7 05 30 32 22 f0 d4 	movl   $0x3d4,0xf0223230
f0100724:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100727:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010072c:	8b 0d 30 32 22 f0    	mov    0xf0223230,%ecx
f0100732:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100737:	89 ca                	mov    %ecx,%edx
f0100739:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010073a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010073d:	89 da                	mov    %ebx,%edx
f010073f:	ec                   	in     (%dx),%al
f0100740:	0f b6 f0             	movzbl %al,%esi
f0100743:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100746:	b8 0f 00 00 00       	mov    $0xf,%eax
f010074b:	89 ca                	mov    %ecx,%edx
f010074d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010074e:	89 da                	mov    %ebx,%edx
f0100750:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100751:	89 3d 2c 32 22 f0    	mov    %edi,0xf022322c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100757:	0f b6 d8             	movzbl %al,%ebx
f010075a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010075c:	66 89 35 28 32 22 f0 	mov    %si,0xf0223228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100763:	e8 1b ff ff ff       	call   f0100683 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100768:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f010076f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100774:	89 04 24             	mov    %eax,(%esp)
f0100777:	e8 73 38 00 00       	call   f0103fef <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010077c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100781:	b8 00 00 00 00       	mov    $0x0,%eax
f0100786:	89 f2                	mov    %esi,%edx
f0100788:	ee                   	out    %al,(%dx)
f0100789:	b2 fb                	mov    $0xfb,%dl
f010078b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100790:	ee                   	out    %al,(%dx)
f0100791:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f0100796:	b8 0c 00 00 00       	mov    $0xc,%eax
f010079b:	89 da                	mov    %ebx,%edx
f010079d:	ee                   	out    %al,(%dx)
f010079e:	b2 f9                	mov    $0xf9,%dl
f01007a0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007a5:	ee                   	out    %al,(%dx)
f01007a6:	b2 fb                	mov    $0xfb,%dl
f01007a8:	b8 03 00 00 00       	mov    $0x3,%eax
f01007ad:	ee                   	out    %al,(%dx)
f01007ae:	b2 fc                	mov    $0xfc,%dl
f01007b0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007b5:	ee                   	out    %al,(%dx)
f01007b6:	b2 f9                	mov    $0xf9,%dl
f01007b8:	b8 01 00 00 00       	mov    $0x1,%eax
f01007bd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01007be:	b2 fd                	mov    $0xfd,%dl
f01007c0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007c1:	3c ff                	cmp    $0xff,%al
f01007c3:	0f 95 c1             	setne  %cl
f01007c6:	0f b6 c9             	movzbl %cl,%ecx
f01007c9:	89 0d 34 32 22 f0    	mov    %ecx,0xf0223234
f01007cf:	89 f2                	mov    %esi,%edx
f01007d1:	ec                   	in     (%dx),%al
f01007d2:	89 da                	mov    %ebx,%edx
f01007d4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007d5:	85 c9                	test   %ecx,%ecx
f01007d7:	75 0c                	jne    f01007e5 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007d9:	c7 04 24 a9 67 10 f0 	movl   $0xf01067a9,(%esp)
f01007e0:	e8 4c 39 00 00       	call   f0104131 <cprintf>
}
f01007e5:	83 c4 1c             	add    $0x1c,%esp
f01007e8:	5b                   	pop    %ebx
f01007e9:	5e                   	pop    %esi
f01007ea:	5f                   	pop    %edi
f01007eb:	5d                   	pop    %ebp
f01007ec:	c3                   	ret    

f01007ed <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007ed:	55                   	push   %ebp
f01007ee:	89 e5                	mov    %esp,%ebp
f01007f0:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f01007f3:	8b 45 08             	mov    0x8(%ebp),%eax
f01007f6:	e8 7e fc ff ff       	call   f0100479 <cons_putc>
}
f01007fb:	c9                   	leave  
f01007fc:	c3                   	ret    

f01007fd <getchar>:

int
getchar(void)
{
f01007fd:	55                   	push   %ebp
f01007fe:	89 e5                	mov    %esp,%ebp
f0100800:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100803:	e8 8d fe ff ff       	call   f0100695 <cons_getc>
f0100808:	85 c0                	test   %eax,%eax
f010080a:	74 f7                	je     f0100803 <getchar+0x6>
		/* do nothing */;
	return c;
}
f010080c:	c9                   	leave  
f010080d:	c3                   	ret    

f010080e <iscons>:

int
iscons(int fdnum)
{
f010080e:	55                   	push   %ebp
f010080f:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100811:	b8 01 00 00 00       	mov    $0x1,%eax
f0100816:	5d                   	pop    %ebp
f0100817:	c3                   	ret    
f0100818:	66 90                	xchg   %ax,%ax
f010081a:	66 90                	xchg   %ax,%ax
f010081c:	66 90                	xchg   %ax,%ax
f010081e:	66 90                	xchg   %ax,%ax

f0100820 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100820:	55                   	push   %ebp
f0100821:	89 e5                	mov    %esp,%ebp
f0100823:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100826:	c7 44 24 08 00 6a 10 	movl   $0xf0106a00,0x8(%esp)
f010082d:	f0 
f010082e:	c7 44 24 04 1e 6a 10 	movl   $0xf0106a1e,0x4(%esp)
f0100835:	f0 
f0100836:	c7 04 24 23 6a 10 f0 	movl   $0xf0106a23,(%esp)
f010083d:	e8 ef 38 00 00       	call   f0104131 <cprintf>
f0100842:	c7 44 24 08 c8 6a 10 	movl   $0xf0106ac8,0x8(%esp)
f0100849:	f0 
f010084a:	c7 44 24 04 2c 6a 10 	movl   $0xf0106a2c,0x4(%esp)
f0100851:	f0 
f0100852:	c7 04 24 23 6a 10 f0 	movl   $0xf0106a23,(%esp)
f0100859:	e8 d3 38 00 00       	call   f0104131 <cprintf>
f010085e:	c7 44 24 08 35 6a 10 	movl   $0xf0106a35,0x8(%esp)
f0100865:	f0 
f0100866:	c7 44 24 04 53 6a 10 	movl   $0xf0106a53,0x4(%esp)
f010086d:	f0 
f010086e:	c7 04 24 23 6a 10 f0 	movl   $0xf0106a23,(%esp)
f0100875:	e8 b7 38 00 00       	call   f0104131 <cprintf>
	return 0;
}
f010087a:	b8 00 00 00 00       	mov    $0x0,%eax
f010087f:	c9                   	leave  
f0100880:	c3                   	ret    

f0100881 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100881:	55                   	push   %ebp
f0100882:	89 e5                	mov    %esp,%ebp
f0100884:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100887:	c7 04 24 61 6a 10 f0 	movl   $0xf0106a61,(%esp)
f010088e:	e8 9e 38 00 00       	call   f0104131 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100893:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010089a:	00 
f010089b:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008a2:	f0 
f01008a3:	c7 04 24 f0 6a 10 f0 	movl   $0xf0106af0,(%esp)
f01008aa:	e8 82 38 00 00       	call   f0104131 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008af:	c7 44 24 08 a7 66 10 	movl   $0x1066a7,0x8(%esp)
f01008b6:	00 
f01008b7:	c7 44 24 04 a7 66 10 	movl   $0xf01066a7,0x4(%esp)
f01008be:	f0 
f01008bf:	c7 04 24 14 6b 10 f0 	movl   $0xf0106b14,(%esp)
f01008c6:	e8 66 38 00 00       	call   f0104131 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008cb:	c7 44 24 08 88 21 22 	movl   $0x222188,0x8(%esp)
f01008d2:	00 
f01008d3:	c7 44 24 04 88 21 22 	movl   $0xf0222188,0x4(%esp)
f01008da:	f0 
f01008db:	c7 04 24 38 6b 10 f0 	movl   $0xf0106b38,(%esp)
f01008e2:	e8 4a 38 00 00       	call   f0104131 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008e7:	c7 44 24 08 04 50 26 	movl   $0x265004,0x8(%esp)
f01008ee:	00 
f01008ef:	c7 44 24 04 04 50 26 	movl   $0xf0265004,0x4(%esp)
f01008f6:	f0 
f01008f7:	c7 04 24 5c 6b 10 f0 	movl   $0xf0106b5c,(%esp)
f01008fe:	e8 2e 38 00 00       	call   f0104131 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f0100903:	b8 03 54 26 f0       	mov    $0xf0265403,%eax
f0100908:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf("Special kernel symbols:\n");
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f010090d:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100913:	85 c0                	test   %eax,%eax
f0100915:	0f 48 c2             	cmovs  %edx,%eax
f0100918:	c1 f8 0a             	sar    $0xa,%eax
f010091b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010091f:	c7 04 24 80 6b 10 f0 	movl   $0xf0106b80,(%esp)
f0100926:	e8 06 38 00 00       	call   f0104131 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f010092b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100930:	c9                   	leave  
f0100931:	c3                   	ret    

f0100932 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f0100932:	55                   	push   %ebp
f0100933:	89 e5                	mov    %esp,%ebp
f0100935:	53                   	push   %ebx
f0100936:	83 ec 44             	sub    $0x44,%esp

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f0100939:	89 eb                	mov    %ebp,%ebx
	unsigned int ebp;
	unsigned int eip;
	unsigned int args[5];
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
f010093b:	c7 04 24 7a 6a 10 f0 	movl   $0xf0106a7a,(%esp)
f0100942:	e8 ea 37 00 00       	call   f0104131 <cprintf>
	do{
           eip = *((unsigned int*)(ebp + 4));
f0100947:	8b 4b 04             	mov    0x4(%ebx),%ecx
           for(i=0;i<5;i++)
f010094a:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *((unsigned int*)(ebp+8+4*i));
f010094f:	8b 54 83 08          	mov    0x8(%ebx,%eax,4),%edx
f0100953:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
	do{
           eip = *((unsigned int*)(ebp + 4));
           for(i=0;i<5;i++)
f0100957:	83 c0 01             	add    $0x1,%eax
f010095a:	83 f8 05             	cmp    $0x5,%eax
f010095d:	75 f0                	jne    f010094f <mon_backtrace+0x1d>
		args[i] = *((unsigned int*)(ebp+8+4*i));
	cprintf(" ebp %08x eip %08x args %08x %08x %08x %08x %08x\n",
f010095f:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100962:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f0100966:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100969:	89 44 24 18          	mov    %eax,0x18(%esp)
f010096d:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100970:	89 44 24 14          	mov    %eax,0x14(%esp)
f0100974:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100977:	89 44 24 10          	mov    %eax,0x10(%esp)
f010097b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010097e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100982:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100986:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010098a:	c7 04 24 ac 6b 10 f0 	movl   $0xf0106bac,(%esp)
f0100991:	e8 9b 37 00 00       	call   f0104131 <cprintf>
		ebp,eip,args[0],args[1],args[2],args[3],args[4]);
	ebp =*((unsigned int*)ebp);
f0100996:	8b 1b                	mov    (%ebx),%ebx
	}while(ebp!=0);
f0100998:	85 db                	test   %ebx,%ebx
f010099a:	75 ab                	jne    f0100947 <mon_backtrace+0x15>
	return 0;
}
f010099c:	b8 00 00 00 00       	mov    $0x0,%eax
f01009a1:	83 c4 44             	add    $0x44,%esp
f01009a4:	5b                   	pop    %ebx
f01009a5:	5d                   	pop    %ebp
f01009a6:	c3                   	ret    

f01009a7 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f01009a7:	55                   	push   %ebp
f01009a8:	89 e5                	mov    %esp,%ebp
f01009aa:	57                   	push   %edi
f01009ab:	56                   	push   %esi
f01009ac:	53                   	push   %ebx
f01009ad:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01009b0:	c7 04 24 e0 6b 10 f0 	movl   $0xf0106be0,(%esp)
f01009b7:	e8 75 37 00 00       	call   f0104131 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009bc:	c7 04 24 04 6c 10 f0 	movl   $0xf0106c04,(%esp)
f01009c3:	e8 69 37 00 00       	call   f0104131 <cprintf>

	if (tf != NULL)
f01009c8:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009cc:	74 0b                	je     f01009d9 <monitor+0x32>
		print_trapframe(tf);
f01009ce:	8b 45 08             	mov    0x8(%ebp),%eax
f01009d1:	89 04 24             	mov    %eax,(%esp)
f01009d4:	e8 fc 3b 00 00       	call   f01045d5 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009d9:	c7 04 24 8c 6a 10 f0 	movl   $0xf0106a8c,(%esp)
f01009e0:	e8 5b 4c 00 00       	call   f0105640 <readline>
f01009e5:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f01009e7:	85 c0                	test   %eax,%eax
f01009e9:	74 ee                	je     f01009d9 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f01009eb:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f01009f2:	be 00 00 00 00       	mov    $0x0,%esi
f01009f7:	eb 0a                	jmp    f0100a03 <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f01009f9:	c6 03 00             	movb   $0x0,(%ebx)
f01009fc:	89 f7                	mov    %esi,%edi
f01009fe:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a01:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a03:	0f b6 03             	movzbl (%ebx),%eax
f0100a06:	84 c0                	test   %al,%al
f0100a08:	74 6a                	je     f0100a74 <monitor+0xcd>
f0100a0a:	0f be c0             	movsbl %al,%eax
f0100a0d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a11:	c7 04 24 90 6a 10 f0 	movl   $0xf0106a90,(%esp)
f0100a18:	e8 9c 4e 00 00       	call   f01058b9 <strchr>
f0100a1d:	85 c0                	test   %eax,%eax
f0100a1f:	75 d8                	jne    f01009f9 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a21:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a24:	74 4e                	je     f0100a74 <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a26:	83 fe 0f             	cmp    $0xf,%esi
f0100a29:	75 16                	jne    f0100a41 <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a2b:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a32:	00 
f0100a33:	c7 04 24 95 6a 10 f0 	movl   $0xf0106a95,(%esp)
f0100a3a:	e8 f2 36 00 00       	call   f0104131 <cprintf>
f0100a3f:	eb 98                	jmp    f01009d9 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a41:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a44:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a48:	0f b6 03             	movzbl (%ebx),%eax
f0100a4b:	84 c0                	test   %al,%al
f0100a4d:	75 0c                	jne    f0100a5b <monitor+0xb4>
f0100a4f:	eb b0                	jmp    f0100a01 <monitor+0x5a>
			buf++;
f0100a51:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a54:	0f b6 03             	movzbl (%ebx),%eax
f0100a57:	84 c0                	test   %al,%al
f0100a59:	74 a6                	je     f0100a01 <monitor+0x5a>
f0100a5b:	0f be c0             	movsbl %al,%eax
f0100a5e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a62:	c7 04 24 90 6a 10 f0 	movl   $0xf0106a90,(%esp)
f0100a69:	e8 4b 4e 00 00       	call   f01058b9 <strchr>
f0100a6e:	85 c0                	test   %eax,%eax
f0100a70:	74 df                	je     f0100a51 <monitor+0xaa>
f0100a72:	eb 8d                	jmp    f0100a01 <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100a74:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100a7b:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100a7c:	85 f6                	test   %esi,%esi
f0100a7e:	0f 84 55 ff ff ff    	je     f01009d9 <monitor+0x32>
f0100a84:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100a89:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100a8c:	8b 04 85 40 6c 10 f0 	mov    -0xfef93c0(,%eax,4),%eax
f0100a93:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a97:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100a9a:	89 04 24             	mov    %eax,(%esp)
f0100a9d:	e8 93 4d 00 00       	call   f0105835 <strcmp>
f0100aa2:	85 c0                	test   %eax,%eax
f0100aa4:	75 24                	jne    f0100aca <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100aa6:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100aa9:	8b 55 08             	mov    0x8(%ebp),%edx
f0100aac:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100ab0:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ab3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100ab7:	89 34 24             	mov    %esi,(%esp)
f0100aba:	ff 14 85 48 6c 10 f0 	call   *-0xfef93b8(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100ac1:	85 c0                	test   %eax,%eax
f0100ac3:	78 25                	js     f0100aea <monitor+0x143>
f0100ac5:	e9 0f ff ff ff       	jmp    f01009d9 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100aca:	83 c3 01             	add    $0x1,%ebx
f0100acd:	83 fb 03             	cmp    $0x3,%ebx
f0100ad0:	75 b7                	jne    f0100a89 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100ad2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ad5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ad9:	c7 04 24 b2 6a 10 f0 	movl   $0xf0106ab2,(%esp)
f0100ae0:	e8 4c 36 00 00       	call   f0104131 <cprintf>
f0100ae5:	e9 ef fe ff ff       	jmp    f01009d9 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100aea:	83 c4 5c             	add    $0x5c,%esp
f0100aed:	5b                   	pop    %ebx
f0100aee:	5e                   	pop    %esi
f0100aef:	5f                   	pop    %edi
f0100af0:	5d                   	pop    %ebp
f0100af1:	c3                   	ret    

f0100af2 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100af2:	55                   	push   %ebp
f0100af3:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100af5:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100af8:	5d                   	pop    %ebp
f0100af9:	c3                   	ret    
f0100afa:	66 90                	xchg   %ax,%ax
f0100afc:	66 90                	xchg   %ax,%ax
f0100afe:	66 90                	xchg   %ax,%ax

f0100b00 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b00:	55                   	push   %ebp
f0100b01:	89 e5                	mov    %esp,%ebp
f0100b03:	53                   	push   %ebx
f0100b04:	83 ec 14             	sub    $0x14,%esp
f0100b07:	89 c3                	mov    %eax,%ebx
	cprintf("boot_alloc\r\n");
f0100b09:	c7 04 24 64 6c 10 f0 	movl   $0xf0106c64,(%esp)
f0100b10:	e8 1c 36 00 00       	call   f0104131 <cprintf>
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b15:	83 3d 38 32 22 f0 00 	cmpl   $0x0,0xf0223238
f0100b1c:	75 0f                	jne    f0100b2d <boot_alloc+0x2d>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b1e:	b8 03 60 26 f0       	mov    $0xf0266003,%eax
f0100b23:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b28:	a3 38 32 22 f0       	mov    %eax,0xf0223238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	result=nextfree;
f0100b2d:	a1 38 32 22 f0       	mov    0xf0223238,%eax
	nextfree+=ROUNDUP(n,PGSIZE);
f0100b32:	81 c3 ff 0f 00 00    	add    $0xfff,%ebx
f0100b38:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0100b3e:	01 c3                	add    %eax,%ebx
f0100b40:	89 1d 38 32 22 f0    	mov    %ebx,0xf0223238
	return result;
}
f0100b46:	83 c4 14             	add    $0x14,%esp
f0100b49:	5b                   	pop    %ebx
f0100b4a:	5d                   	pop    %ebp
f0100b4b:	c3                   	ret    

f0100b4c <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100b4c:	89 d1                	mov    %edx,%ecx
f0100b4e:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100b51:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100b54:	a8 01                	test   $0x1,%al
f0100b56:	74 5d                	je     f0100bb5 <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100b58:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b5d:	89 c1                	mov    %eax,%ecx
f0100b5f:	c1 e9 0c             	shr    $0xc,%ecx
f0100b62:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0100b68:	72 26                	jb     f0100b90 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100b6a:	55                   	push   %ebp
f0100b6b:	89 e5                	mov    %esp,%ebp
f0100b6d:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b70:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b74:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0100b7b:	f0 
f0100b7c:	c7 44 24 04 c4 03 00 	movl   $0x3c4,0x4(%esp)
f0100b83:	00 
f0100b84:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100b8b:	e8 b0 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100b90:	c1 ea 0c             	shr    $0xc,%edx
f0100b93:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100b99:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100ba0:	89 c2                	mov    %eax,%edx
f0100ba2:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100ba5:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100baa:	85 d2                	test   %edx,%edx
f0100bac:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100bb1:	0f 44 c2             	cmove  %edx,%eax
f0100bb4:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100bb5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100bba:	c3                   	ret    

f0100bbb <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100bbb:	55                   	push   %ebp
f0100bbc:	89 e5                	mov    %esp,%ebp
f0100bbe:	57                   	push   %edi
f0100bbf:	56                   	push   %esi
f0100bc0:	53                   	push   %ebx
f0100bc1:	83 ec 4c             	sub    $0x4c,%esp
f0100bc4:	89 c3                	mov    %eax,%ebx
	cprintf("check_page_free_list");
f0100bc6:	c7 04 24 7d 6c 10 f0 	movl   $0xf0106c7d,(%esp)
f0100bcd:	e8 5f 35 00 00       	call   f0104131 <cprintf>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100bd2:	85 db                	test   %ebx,%ebx
f0100bd4:	0f 85 6a 03 00 00    	jne    f0100f44 <check_page_free_list+0x389>
f0100bda:	e9 77 03 00 00       	jmp    f0100f56 <check_page_free_list+0x39b>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100bdf:	c7 44 24 08 28 70 10 	movl   $0xf0107028,0x8(%esp)
f0100be6:	f0 
f0100be7:	c7 44 24 04 e7 02 00 	movl   $0x2e7,0x4(%esp)
f0100bee:	00 
f0100bef:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100bf6:	e8 45 f4 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100bfb:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100bfe:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c01:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c04:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c07:	89 c2                	mov    %eax,%edx
f0100c09:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c0f:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c15:	0f 95 c2             	setne  %dl
f0100c18:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c1b:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c1f:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c21:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c25:	8b 00                	mov    (%eax),%eax
f0100c27:	85 c0                	test   %eax,%eax
f0100c29:	75 dc                	jne    f0100c07 <check_page_free_list+0x4c>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c2b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c2e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c34:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c37:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c3a:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100c3c:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100c3f:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c44:	89 c3                	mov    %eax,%ebx
f0100c46:	85 c0                	test   %eax,%eax
f0100c48:	74 6c                	je     f0100cb6 <check_page_free_list+0xfb>
static void
check_page_free_list(bool only_low_memory)
{
	cprintf("check_page_free_list");
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c4a:	be 01 00 00 00       	mov    $0x1,%esi
f0100c4f:	89 d8                	mov    %ebx,%eax
f0100c51:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0100c57:	c1 f8 03             	sar    $0x3,%eax
f0100c5a:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100c5d:	89 c2                	mov    %eax,%edx
f0100c5f:	c1 ea 16             	shr    $0x16,%edx
f0100c62:	39 f2                	cmp    %esi,%edx
f0100c64:	73 4a                	jae    f0100cb0 <check_page_free_list+0xf5>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100c66:	89 c2                	mov    %eax,%edx
f0100c68:	c1 ea 0c             	shr    $0xc,%edx
f0100c6b:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0100c71:	72 20                	jb     f0100c93 <check_page_free_list+0xd8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100c73:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100c77:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0100c7e:	f0 
f0100c7f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100c86:	00 
f0100c87:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0100c8e:	e8 ad f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100c93:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100c9a:	00 
f0100c9b:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ca2:	00 
	return (void *)(pa + KERNBASE);
f0100ca3:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100ca8:	89 04 24             	mov    %eax,(%esp)
f0100cab:	e8 69 4c 00 00       	call   f0105919 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100cb0:	8b 1b                	mov    (%ebx),%ebx
f0100cb2:	85 db                	test   %ebx,%ebx
f0100cb4:	75 99                	jne    f0100c4f <check_page_free_list+0x94>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100cb6:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cbb:	e8 40 fe ff ff       	call   f0100b00 <boot_alloc>
f0100cc0:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100cc3:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0100cc9:	85 d2                	test   %edx,%edx
f0100ccb:	0f 84 27 02 00 00    	je     f0100ef8 <check_page_free_list+0x33d>
		// check that we didn't corrupt the free list itself
		//cprintf("%d",pp->pp_ref);
		assert(pp >= pages);
f0100cd1:	8b 3d 90 3e 22 f0    	mov    0xf0223e90,%edi
f0100cd7:	39 fa                	cmp    %edi,%edx
f0100cd9:	72 3f                	jb     f0100d1a <check_page_free_list+0x15f>
		assert(pp < pages + npages);
f0100cdb:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0100ce0:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100ce3:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100ce6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100ce9:	39 c2                	cmp    %eax,%edx
f0100ceb:	73 56                	jae    f0100d43 <check_page_free_list+0x188>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100ced:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100cf0:	89 d0                	mov    %edx,%eax
f0100cf2:	29 f8                	sub    %edi,%eax
f0100cf4:	a8 07                	test   $0x7,%al
f0100cf6:	75 78                	jne    f0100d70 <check_page_free_list+0x1b5>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100cf8:	c1 f8 03             	sar    $0x3,%eax
f0100cfb:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100cfe:	85 c0                	test   %eax,%eax
f0100d00:	0f 84 98 00 00 00    	je     f0100d9e <check_page_free_list+0x1e3>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d06:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d0b:	0f 85 dc 00 00 00    	jne    f0100ded <check_page_free_list+0x232>
f0100d11:	e9 b3 00 00 00       	jmp    f0100dc9 <check_page_free_list+0x20e>

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		//cprintf("%d",pp->pp_ref);
		assert(pp >= pages);
f0100d16:	39 d7                	cmp    %edx,%edi
f0100d18:	76 24                	jbe    f0100d3e <check_page_free_list+0x183>
f0100d1a:	c7 44 24 0c a0 6c 10 	movl   $0xf0106ca0,0xc(%esp)
f0100d21:	f0 
f0100d22:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100d29:	f0 
f0100d2a:	c7 44 24 04 02 03 00 	movl   $0x302,0x4(%esp)
f0100d31:	00 
f0100d32:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100d39:	e8 02 f3 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d3e:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100d41:	72 24                	jb     f0100d67 <check_page_free_list+0x1ac>
f0100d43:	c7 44 24 0c c1 6c 10 	movl   $0xf0106cc1,0xc(%esp)
f0100d4a:	f0 
f0100d4b:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100d52:	f0 
f0100d53:	c7 44 24 04 03 03 00 	movl   $0x303,0x4(%esp)
f0100d5a:	00 
f0100d5b:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100d62:	e8 d9 f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d67:	89 d0                	mov    %edx,%eax
f0100d69:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100d6c:	a8 07                	test   $0x7,%al
f0100d6e:	74 24                	je     f0100d94 <check_page_free_list+0x1d9>
f0100d70:	c7 44 24 0c 4c 70 10 	movl   $0xf010704c,0xc(%esp)
f0100d77:	f0 
f0100d78:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100d7f:	f0 
f0100d80:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
f0100d87:	00 
f0100d88:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100d8f:	e8 ac f2 ff ff       	call   f0100040 <_panic>
f0100d94:	c1 f8 03             	sar    $0x3,%eax
f0100d97:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d9a:	85 c0                	test   %eax,%eax
f0100d9c:	75 24                	jne    f0100dc2 <check_page_free_list+0x207>
f0100d9e:	c7 44 24 0c d5 6c 10 	movl   $0xf0106cd5,0xc(%esp)
f0100da5:	f0 
f0100da6:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100dad:	f0 
f0100dae:	c7 44 24 04 07 03 00 	movl   $0x307,0x4(%esp)
f0100db5:	00 
f0100db6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100dbd:	e8 7e f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100dc2:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100dc7:	75 31                	jne    f0100dfa <check_page_free_list+0x23f>
f0100dc9:	c7 44 24 0c e6 6c 10 	movl   $0xf0106ce6,0xc(%esp)
f0100dd0:	f0 
f0100dd1:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100dd8:	f0 
f0100dd9:	c7 44 24 04 08 03 00 	movl   $0x308,0x4(%esp)
f0100de0:	00 
f0100de1:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100de8:	e8 53 f2 ff ff       	call   f0100040 <_panic>
check_page_free_list(bool only_low_memory)
{
	cprintf("check_page_free_list");
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100ded:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100df2:	be 00 00 00 00       	mov    $0x0,%esi
f0100df7:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100dfa:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100dff:	75 24                	jne    f0100e25 <check_page_free_list+0x26a>
f0100e01:	c7 44 24 0c 80 70 10 	movl   $0xf0107080,0xc(%esp)
f0100e08:	f0 
f0100e09:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100e10:	f0 
f0100e11:	c7 44 24 04 09 03 00 	movl   $0x309,0x4(%esp)
f0100e18:	00 
f0100e19:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100e20:	e8 1b f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e25:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e2a:	75 24                	jne    f0100e50 <check_page_free_list+0x295>
f0100e2c:	c7 44 24 0c ff 6c 10 	movl   $0xf0106cff,0xc(%esp)
f0100e33:	f0 
f0100e34:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100e3b:	f0 
f0100e3c:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f0100e43:	00 
f0100e44:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100e4b:	e8 f0 f1 ff ff       	call   f0100040 <_panic>
f0100e50:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100e52:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100e57:	0f 86 08 01 00 00    	jbe    f0100f65 <check_page_free_list+0x3aa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e5d:	89 c3                	mov    %eax,%ebx
f0100e5f:	c1 eb 0c             	shr    $0xc,%ebx
f0100e62:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100e65:	77 20                	ja     f0100e87 <check_page_free_list+0x2cc>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100e67:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100e6b:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0100e72:	f0 
f0100e73:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100e7a:	00 
f0100e7b:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0100e82:	e8 b9 f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100e87:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100e8d:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100e90:	0f 86 df 00 00 00    	jbe    f0100f75 <check_page_free_list+0x3ba>
f0100e96:	c7 44 24 0c a4 70 10 	movl   $0xf01070a4,0xc(%esp)
f0100e9d:	f0 
f0100e9e:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100ea5:	f0 
f0100ea6:	c7 44 24 04 0b 03 00 	movl   $0x30b,0x4(%esp)
f0100ead:	00 
f0100eae:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100eb5:	e8 86 f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100eba:	c7 44 24 0c 19 6d 10 	movl   $0xf0106d19,0xc(%esp)
f0100ec1:	f0 
f0100ec2:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100ec9:	f0 
f0100eca:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f0100ed1:	00 
f0100ed2:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100ed9:	e8 62 f1 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100ede:	83 c6 01             	add    $0x1,%esi
f0100ee1:	eb 04                	jmp    f0100ee7 <check_page_free_list+0x32c>
		else
			++nfree_extmem;
f0100ee3:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100ee7:	8b 12                	mov    (%edx),%edx
f0100ee9:	85 d2                	test   %edx,%edx
f0100eeb:	0f 85 25 fe ff ff    	jne    f0100d16 <check_page_free_list+0x15b>
f0100ef1:	8b 5d cc             	mov    -0x34(%ebp),%ebx
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100ef4:	85 f6                	test   %esi,%esi
f0100ef6:	7f 24                	jg     f0100f1c <check_page_free_list+0x361>
f0100ef8:	c7 44 24 0c 36 6d 10 	movl   $0xf0106d36,0xc(%esp)
f0100eff:	f0 
f0100f00:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100f07:	f0 
f0100f08:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
f0100f0f:	00 
f0100f10:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100f17:	e8 24 f1 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f1c:	85 db                	test   %ebx,%ebx
f0100f1e:	7f 75                	jg     f0100f95 <check_page_free_list+0x3da>
f0100f20:	c7 44 24 0c 48 6d 10 	movl   $0xf0106d48,0xc(%esp)
f0100f27:	f0 
f0100f28:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0100f2f:	f0 
f0100f30:	c7 44 24 04 16 03 00 	movl   $0x316,0x4(%esp)
f0100f37:	00 
f0100f38:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0100f3f:	e8 fc f0 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100f44:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0100f49:	85 c0                	test   %eax,%eax
f0100f4b:	0f 85 aa fc ff ff    	jne    f0100bfb <check_page_free_list+0x40>
f0100f51:	e9 89 fc ff ff       	jmp    f0100bdf <check_page_free_list+0x24>
f0100f56:	83 3d 40 32 22 f0 00 	cmpl   $0x0,0xf0223240
f0100f5d:	75 26                	jne    f0100f85 <check_page_free_list+0x3ca>
f0100f5f:	90                   	nop
f0100f60:	e9 7a fc ff ff       	jmp    f0100bdf <check_page_free_list+0x24>
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f65:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100f6a:	0f 85 6e ff ff ff    	jne    f0100ede <check_page_free_list+0x323>
f0100f70:	e9 45 ff ff ff       	jmp    f0100eba <check_page_free_list+0x2ff>
f0100f75:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100f7a:	0f 85 63 ff ff ff    	jne    f0100ee3 <check_page_free_list+0x328>
f0100f80:	e9 35 ff ff ff       	jmp    f0100eba <check_page_free_list+0x2ff>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100f85:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
static void
check_page_free_list(bool only_low_memory)
{
	cprintf("check_page_free_list");
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100f8b:	be 00 04 00 00       	mov    $0x400,%esi
f0100f90:	e9 ba fc ff ff       	jmp    f0100c4f <check_page_free_list+0x94>
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100f95:	83 c4 4c             	add    $0x4c,%esp
f0100f98:	5b                   	pop    %ebx
f0100f99:	5e                   	pop    %esi
f0100f9a:	5f                   	pop    %edi
f0100f9b:	5d                   	pop    %ebp
f0100f9c:	c3                   	ret    

f0100f9d <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100f9d:	55                   	push   %ebp
f0100f9e:	89 e5                	mov    %esp,%ebp
f0100fa0:	56                   	push   %esi
f0100fa1:	53                   	push   %ebx
f0100fa2:	83 ec 10             	sub    $0x10,%esp
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100fa5:	83 3d 88 3e 22 f0 07 	cmpl   $0x7,0xf0223e88
f0100fac:	77 1c                	ja     f0100fca <page_init+0x2d>
		panic("pa2page called with invalid pa");
f0100fae:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0100fb5:	f0 
f0100fb6:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100fbd:	00 
f0100fbe:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0100fc5:	e8 76 f0 ff ff       	call   f0100040 <_panic>
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
f0100fca:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0100fcf:	8d 70 38             	lea    0x38(%eax),%esi
	for (i; i < npages_basemem; i++) {
f0100fd2:	83 3d 44 32 22 f0 01 	cmpl   $0x1,0xf0223244
f0100fd9:	76 4b                	jbe    f0101026 <page_init+0x89>
	//     page tables and other data structures?
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
f0100fdb:	bb 01 00 00 00       	mov    $0x1,%ebx
f0100fe0:	8d 14 dd 00 00 00 00 	lea    0x0(,%ebx,8),%edx
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
		if(pages + i == page_mpentry) 
f0100fe7:	89 d0                	mov    %edx,%eax
f0100fe9:	03 05 90 3e 22 f0    	add    0xf0223e90,%eax
f0100fef:	39 f0                	cmp    %esi,%eax
f0100ff1:	75 0e                	jne    f0101001 <page_init+0x64>
		{
			cprintf("MPENTRY detected!\n");
f0100ff3:	c7 04 24 59 6d 10 f0 	movl   $0xf0106d59,(%esp)
f0100ffa:	e8 32 31 00 00       	call   f0104131 <cprintf>
			continue;
f0100fff:	eb 1a                	jmp    f010101b <page_init+0x7e>
		}
		pages[i].pp_ref = 0;
f0101001:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
		pages[i].pp_link = page_free_list;
f0101007:	8b 0d 40 32 22 f0    	mov    0xf0223240,%ecx
f010100d:	89 08                	mov    %ecx,(%eax)
		page_free_list = &pages[i];
f010100f:	03 15 90 3e 22 f0    	add    0xf0223e90,%edx
f0101015:	89 15 40 32 22 f0    	mov    %edx,0xf0223240
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
f010101b:	83 c3 01             	add    $0x1,%ebx
f010101e:	39 1d 44 32 22 f0    	cmp    %ebx,0xf0223244
f0101024:	77 ba                	ja     f0100fe0 <page_init+0x43>
		page_free_list = &pages[i];
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0101026:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f010102c:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0101031:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0101038:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010103d:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101043:	85 c0                	test   %eax,%eax
f0101045:	0f 48 c2             	cmovs  %edx,%eax
f0101048:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f010104b:	89 c2                	mov    %eax,%edx
f010104d:	39 c1                	cmp    %eax,%ecx
f010104f:	76 39                	jbe    f010108a <page_init+0xed>
f0101051:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f0101057:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f010105a:	89 c1                	mov    %eax,%ecx
f010105c:	03 0d 90 3e 22 f0    	add    0xf0223e90,%ecx
f0101062:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101068:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f010106a:	89 c1                	mov    %eax,%ecx
f010106c:	03 0d 90 3e 22 f0    	add    0xf0223e90,%ecx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0101072:	83 c2 01             	add    $0x1,%edx
f0101075:	83 c0 08             	add    $0x8,%eax
f0101078:	39 15 88 3e 22 f0    	cmp    %edx,0xf0223e88
f010107e:	76 04                	jbe    f0101084 <page_init+0xe7>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0101080:	89 cb                	mov    %ecx,%ebx
f0101082:	eb d6                	jmp    f010105a <page_init+0xbd>
f0101084:	89 0d 40 32 22 f0    	mov    %ecx,0xf0223240
	}

}
f010108a:	83 c4 10             	add    $0x10,%esp
f010108d:	5b                   	pop    %ebx
f010108e:	5e                   	pop    %esi
f010108f:	5d                   	pop    %ebp
f0101090:	c3                   	ret    

f0101091 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0101091:	55                   	push   %ebp
f0101092:	89 e5                	mov    %esp,%ebp
f0101094:	53                   	push   %ebx
f0101095:	83 ec 14             	sub    $0x14,%esp
	//cprintf("page_alloc\r\n");
	if(page_free_list==NULL)
f0101098:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f010109e:	85 db                	test   %ebx,%ebx
f01010a0:	74 69                	je     f010110b <page_alloc+0x7a>
	{
		return NULL;
	}
	struct Page* result=page_free_list;
	page_free_list=page_free_list->pp_link;
f01010a2:	8b 03                	mov    (%ebx),%eax
f01010a4:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	if(alloc_flags & ALLOC_ZERO)
	{
	memset(page2kva(result),0,PGSIZE);
	}
	return result;
f01010a9:	89 d8                	mov    %ebx,%eax
	{
		return NULL;
	}
	struct Page* result=page_free_list;
	page_free_list=page_free_list->pp_link;
	if(alloc_flags & ALLOC_ZERO)
f01010ab:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f01010af:	74 5f                	je     f0101110 <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01010b1:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01010b7:	c1 f8 03             	sar    $0x3,%eax
f01010ba:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010bd:	89 c2                	mov    %eax,%edx
f01010bf:	c1 ea 0c             	shr    $0xc,%edx
f01010c2:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01010c8:	72 20                	jb     f01010ea <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01010ca:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01010ce:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f01010d5:	f0 
f01010d6:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01010dd:	00 
f01010de:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01010e5:	e8 56 ef ff ff       	call   f0100040 <_panic>
	{
	memset(page2kva(result),0,PGSIZE);
f01010ea:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01010f1:	00 
f01010f2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01010f9:	00 
	return (void *)(pa + KERNBASE);
f01010fa:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01010ff:	89 04 24             	mov    %eax,(%esp)
f0101102:	e8 12 48 00 00       	call   f0105919 <memset>
	}
	return result;
f0101107:	89 d8                	mov    %ebx,%eax
f0101109:	eb 05                	jmp    f0101110 <page_alloc+0x7f>
page_alloc(int alloc_flags)
{
	//cprintf("page_alloc\r\n");
	if(page_free_list==NULL)
	{
		return NULL;
f010110b:	b8 00 00 00 00       	mov    $0x0,%eax
	if(alloc_flags & ALLOC_ZERO)
	{
	memset(page2kva(result),0,PGSIZE);
	}
	return result;
}
f0101110:	83 c4 14             	add    $0x14,%esp
f0101113:	5b                   	pop    %ebx
f0101114:	5d                   	pop    %ebp
f0101115:	c3                   	ret    

f0101116 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0101116:	55                   	push   %ebp
f0101117:	89 e5                	mov    %esp,%ebp
f0101119:	8b 45 08             	mov    0x8(%ebp),%eax
	//cprintf("page_frees\r\n");
	pp->pp_ref=0;
f010111c:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
	pp->pp_link=page_free_list;
f0101122:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0101128:	89 10                	mov    %edx,(%eax)
	page_free_list=pp;
f010112a:	a3 40 32 22 f0       	mov    %eax,0xf0223240
}
f010112f:	5d                   	pop    %ebp
f0101130:	c3                   	ret    

f0101131 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0101131:	55                   	push   %ebp
f0101132:	89 e5                	mov    %esp,%ebp
f0101134:	83 ec 04             	sub    $0x4,%esp
f0101137:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f010113a:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f010113e:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0101141:	66 89 50 04          	mov    %dx,0x4(%eax)
f0101145:	66 85 d2             	test   %dx,%dx
f0101148:	75 08                	jne    f0101152 <page_decref+0x21>
		page_free(pp);
f010114a:	89 04 24             	mov    %eax,(%esp)
f010114d:	e8 c4 ff ff ff       	call   f0101116 <page_free>
}
f0101152:	c9                   	leave  
f0101153:	c3                   	ret    

f0101154 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0101154:	55                   	push   %ebp
f0101155:	89 e5                	mov    %esp,%ebp
f0101157:	56                   	push   %esi
f0101158:	53                   	push   %ebx
f0101159:	83 ec 10             	sub    $0x10,%esp
f010115c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	//cprintf("pgdir_walk\r\n");
	// Fill this function in
	pte_t* result=NULL;
	if(pgdir[PDX(va)]==(pte_t)NULL)
f010115f:	89 de                	mov    %ebx,%esi
f0101161:	c1 ee 16             	shr    $0x16,%esi
f0101164:	c1 e6 02             	shl    $0x2,%esi
f0101167:	03 75 08             	add    0x8(%ebp),%esi
f010116a:	8b 06                	mov    (%esi),%eax
f010116c:	85 c0                	test   %eax,%eax
f010116e:	75 76                	jne    f01011e6 <pgdir_walk+0x92>
	{
		if(create==0)
f0101170:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0101174:	0f 84 d1 00 00 00    	je     f010124b <pgdir_walk+0xf7>
		{
			return NULL;
		}
		else
		{
			struct Page* page=page_alloc(1);
f010117a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101181:	e8 0b ff ff ff       	call   f0101091 <page_alloc>
			if(page==NULL)
f0101186:	85 c0                	test   %eax,%eax
f0101188:	0f 84 c4 00 00 00    	je     f0101252 <pgdir_walk+0xfe>
			{
				return NULL;
			}
			page->pp_ref++;
f010118e:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101193:	89 c2                	mov    %eax,%edx
f0101195:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f010119b:	c1 fa 03             	sar    $0x3,%edx
f010119e:	c1 e2 0c             	shl    $0xc,%edx
			pgdir[PDX(va)]=page2pa(page)|PTE_P|PTE_W|PTE_U;
f01011a1:	83 ca 07             	or     $0x7,%edx
f01011a4:	89 16                	mov    %edx,(%esi)
f01011a6:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01011ac:	c1 f8 03             	sar    $0x3,%eax
f01011af:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011b2:	89 c2                	mov    %eax,%edx
f01011b4:	c1 ea 0c             	shr    $0xc,%edx
f01011b7:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01011bd:	72 20                	jb     f01011df <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01011bf:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01011c3:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f01011ca:	f0 
f01011cb:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01011d2:	00 
f01011d3:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01011da:	e8 61 ee ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01011df:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01011e4:	eb 58                	jmp    f010123e <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011e6:	c1 e8 0c             	shr    $0xc,%eax
f01011e9:	8b 15 88 3e 22 f0    	mov    0xf0223e88,%edx
f01011ef:	39 d0                	cmp    %edx,%eax
f01011f1:	72 1c                	jb     f010120f <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f01011f3:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f01011fa:	f0 
f01011fb:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101202:	00 
f0101203:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f010120a:	e8 31 ee ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010120f:	89 c1                	mov    %eax,%ecx
f0101211:	c1 e1 0c             	shl    $0xc,%ecx
f0101214:	39 d0                	cmp    %edx,%eax
f0101216:	72 20                	jb     f0101238 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101218:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010121c:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0101223:	f0 
f0101224:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010122b:	00 
f010122c:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0101233:	e8 08 ee ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101238:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
	else
	{
		//cprintf("%u ",PGNUM(PTE_ADDR(pgdir[PDX(va)])));
		result=page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
	}
	pte_t* r=&result[PTX(va)];
f010123e:	c1 eb 0a             	shr    $0xa,%ebx
f0101241:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
	pte_t pte=*r;

	return r;
f0101247:	01 d8                	add    %ebx,%eax
f0101249:	eb 0c                	jmp    f0101257 <pgdir_walk+0x103>
	pte_t* result=NULL;
	if(pgdir[PDX(va)]==(pte_t)NULL)
	{
		if(create==0)
		{
			return NULL;
f010124b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101250:	eb 05                	jmp    f0101257 <pgdir_walk+0x103>
		else
		{
			struct Page* page=page_alloc(1);
			if(page==NULL)
			{
				return NULL;
f0101252:	b8 00 00 00 00       	mov    $0x0,%eax
	pte_t pte=*r;

	return r;


}
f0101257:	83 c4 10             	add    $0x10,%esp
f010125a:	5b                   	pop    %ebx
f010125b:	5e                   	pop    %esi
f010125c:	5d                   	pop    %ebp
f010125d:	c3                   	ret    

f010125e <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f010125e:	55                   	push   %ebp
f010125f:	89 e5                	mov    %esp,%ebp
f0101261:	57                   	push   %edi
f0101262:	56                   	push   %esi
f0101263:	53                   	push   %ebx
f0101264:	83 ec 2c             	sub    $0x2c,%esp
f0101267:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010126a:	89 d7                	mov    %edx,%edi
f010126c:	89 cb                	mov    %ecx,%ebx
	cprintf("boot_map_region\r\n");
f010126e:	c7 04 24 6c 6d 10 f0 	movl   $0xf0106d6c,(%esp)
f0101275:	e8 b7 2e 00 00       	call   f0104131 <cprintf>
	int i=0;
	for(;i<size/PGSIZE;i++)
f010127a:	89 d9                	mov    %ebx,%ecx
f010127c:	c1 e9 0c             	shr    $0xc,%ecx
f010127f:	85 c9                	test   %ecx,%ecx
f0101281:	74 5d                	je     f01012e0 <boot_map_region+0x82>
f0101283:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0101286:	89 fb                	mov    %edi,%ebx
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	cprintf("boot_map_region\r\n");
	int i=0;
f0101288:	be 00 00 00 00       	mov    $0x0,%esi
			struct Page* page=page_alloc(1);
			*pte=page2pa(page);

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
f010128d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101290:	83 c8 01             	or     $0x1,%eax
f0101293:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0101296:	8b 45 08             	mov    0x8(%ebp),%eax
f0101299:	29 f8                	sub    %edi,%eax
f010129b:	89 45 d8             	mov    %eax,-0x28(%ebp)
{
	cprintf("boot_map_region\r\n");
	int i=0;
	for(;i<size/PGSIZE;i++)
	{
		pte_t* pte=pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
f010129e:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01012a5:	00 
f01012a6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01012aa:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01012ad:	89 04 24             	mov    %eax,(%esp)
f01012b0:	e8 9f fe ff ff       	call   f0101154 <pgdir_walk>
f01012b5:	89 c7                	mov    %eax,%edi
		if(*pte==0)
f01012b7:	83 38 00             	cmpl   $0x0,(%eax)
f01012ba:	75 0c                	jne    f01012c8 <boot_map_region+0x6a>
		{
			struct Page* page=page_alloc(1);
f01012bc:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01012c3:	e8 c9 fd ff ff       	call   f0101091 <page_alloc>
f01012c8:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01012cb:	01 d8                	add    %ebx,%eax
			*pte=page2pa(page);

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
f01012cd:	0b 45 dc             	or     -0x24(%ebp),%eax
f01012d0:	89 07                	mov    %eax,(%edi)
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	cprintf("boot_map_region\r\n");
	int i=0;
	for(;i<size/PGSIZE;i++)
f01012d2:	83 c6 01             	add    $0x1,%esi
f01012d5:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01012db:	3b 75 e0             	cmp    -0x20(%ebp),%esi
f01012de:	75 be                	jne    f010129e <boot_map_region+0x40>

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
	}
}
f01012e0:	83 c4 2c             	add    $0x2c,%esp
f01012e3:	5b                   	pop    %ebx
f01012e4:	5e                   	pop    %esi
f01012e5:	5f                   	pop    %edi
f01012e6:	5d                   	pop    %ebp
f01012e7:	c3                   	ret    

f01012e8 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f01012e8:	55                   	push   %ebp
f01012e9:	89 e5                	mov    %esp,%ebp
f01012eb:	53                   	push   %ebx
f01012ec:	83 ec 14             	sub    $0x14,%esp
f01012ef:	8b 5d 10             	mov    0x10(%ebp),%ebx
	//cprintf("page_lookup\r\n");
	// Fill this function in
	pte_t* pte=pgdir_walk(pgdir,va,0);
f01012f2:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01012f9:	00 
f01012fa:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012fd:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101301:	8b 45 08             	mov    0x8(%ebp),%eax
f0101304:	89 04 24             	mov    %eax,(%esp)
f0101307:	e8 48 fe ff ff       	call   f0101154 <pgdir_walk>
	if(pte==NULL)
f010130c:	85 c0                	test   %eax,%eax
f010130e:	74 3e                	je     f010134e <page_lookup+0x66>
	{
		return NULL;
	}
	if(pte_store!=0)
f0101310:	85 db                	test   %ebx,%ebx
f0101312:	74 02                	je     f0101316 <page_lookup+0x2e>
	{
		*pte_store=pte;
f0101314:	89 03                	mov    %eax,(%ebx)
	}
    pte_t* unuse=pte;

	if(pte[0] !=(pte_t)NULL)
f0101316:	8b 00                	mov    (%eax),%eax
f0101318:	85 c0                	test   %eax,%eax
f010131a:	74 39                	je     f0101355 <page_lookup+0x6d>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010131c:	c1 e8 0c             	shr    $0xc,%eax
f010131f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0101325:	72 1c                	jb     f0101343 <page_lookup+0x5b>
		panic("pa2page called with invalid pa");
f0101327:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f010132e:	f0 
f010132f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101336:	00 
f0101337:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f010133e:	e8 fd ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101343:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0101349:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	{

		return pa2page(PTE_ADDR(pte[0]));
f010134c:	eb 0c                	jmp    f010135a <page_lookup+0x72>
	//cprintf("page_lookup\r\n");
	// Fill this function in
	pte_t* pte=pgdir_walk(pgdir,va,0);
	if(pte==NULL)
	{
		return NULL;
f010134e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101353:	eb 05                	jmp    f010135a <page_lookup+0x72>
		return pa2page(PTE_ADDR(pte[0]));

	}
	else
	{
		return NULL;
f0101355:	b8 00 00 00 00       	mov    $0x0,%eax
	}
}
f010135a:	83 c4 14             	add    $0x14,%esp
f010135d:	5b                   	pop    %ebx
f010135e:	5d                   	pop    %ebp
f010135f:	c3                   	ret    

f0101360 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0101360:	55                   	push   %ebp
f0101361:	89 e5                	mov    %esp,%ebp
f0101363:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f0101366:	e8 48 4c 00 00       	call   f0105fb3 <cpunum>
f010136b:	6b c0 74             	imul   $0x74,%eax,%eax
f010136e:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0101375:	74 16                	je     f010138d <tlb_invalidate+0x2d>
f0101377:	e8 37 4c 00 00       	call   f0105fb3 <cpunum>
f010137c:	6b c0 74             	imul   $0x74,%eax,%eax
f010137f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0101385:	8b 55 08             	mov    0x8(%ebp),%edx
f0101388:	39 50 60             	cmp    %edx,0x60(%eax)
f010138b:	75 06                	jne    f0101393 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f010138d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101390:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f0101393:	c9                   	leave  
f0101394:	c3                   	ret    

f0101395 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0101395:	55                   	push   %ebp
f0101396:	89 e5                	mov    %esp,%ebp
f0101398:	56                   	push   %esi
f0101399:	53                   	push   %ebx
f010139a:	83 ec 20             	sub    $0x20,%esp
f010139d:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013a0:	8b 75 0c             	mov    0xc(%ebp),%esi
	//cprintf("page_remove\r\n");
	pte_t* pte=0;
f01013a3:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
	struct Page* page=page_lookup(pgdir,va,&pte);
f01013aa:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01013ad:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013b1:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013b5:	89 1c 24             	mov    %ebx,(%esp)
f01013b8:	e8 2b ff ff ff       	call   f01012e8 <page_lookup>
	if(page!=NULL)
f01013bd:	85 c0                	test   %eax,%eax
f01013bf:	74 08                	je     f01013c9 <page_remove+0x34>
	{
		page_decref(page);
f01013c1:	89 04 24             	mov    %eax,(%esp)
f01013c4:	e8 68 fd ff ff       	call   f0101131 <page_decref>
	}

	pte[0]=0;
f01013c9:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01013cc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	tlb_invalidate(pgdir,va);
f01013d2:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013d6:	89 1c 24             	mov    %ebx,(%esp)
f01013d9:	e8 82 ff ff ff       	call   f0101360 <tlb_invalidate>
}
f01013de:	83 c4 20             	add    $0x20,%esp
f01013e1:	5b                   	pop    %ebx
f01013e2:	5e                   	pop    %esi
f01013e3:	5d                   	pop    %ebp
f01013e4:	c3                   	ret    

f01013e5 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f01013e5:	55                   	push   %ebp
f01013e6:	89 e5                	mov    %esp,%ebp
f01013e8:	57                   	push   %edi
f01013e9:	56                   	push   %esi
f01013ea:	53                   	push   %ebx
f01013eb:	83 ec 1c             	sub    $0x1c,%esp
f01013ee:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01013f1:	8b 75 10             	mov    0x10(%ebp),%esi
	//cprintf("page_insert\r\n");
	// Fill this function in
	pte_t* pte;
	struct Page* pg=page_lookup(pgdir,va,NULL);
f01013f4:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01013fb:	00 
f01013fc:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101400:	8b 45 08             	mov    0x8(%ebp),%eax
f0101403:	89 04 24             	mov    %eax,(%esp)
f0101406:	e8 dd fe ff ff       	call   f01012e8 <page_lookup>
f010140b:	89 c7                	mov    %eax,%edi
	if(pg==pp)
f010140d:	39 d8                	cmp    %ebx,%eax
f010140f:	75 36                	jne    f0101447 <page_insert+0x62>
	{
		pte=pgdir_walk(pgdir,va,1);
f0101411:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101418:	00 
f0101419:	89 74 24 04          	mov    %esi,0x4(%esp)
f010141d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101420:	89 04 24             	mov    %eax,(%esp)
f0101423:	e8 2c fd ff ff       	call   f0101154 <pgdir_walk>
		pte[0]=page2pa(pp)|perm|PTE_P;
f0101428:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010142b:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010142e:	2b 3d 90 3e 22 f0    	sub    0xf0223e90,%edi
f0101434:	c1 ff 03             	sar    $0x3,%edi
f0101437:	c1 e7 0c             	shl    $0xc,%edi
f010143a:	89 fa                	mov    %edi,%edx
f010143c:	09 ca                	or     %ecx,%edx
f010143e:	89 10                	mov    %edx,(%eax)
			return 0;
f0101440:	b8 00 00 00 00       	mov    $0x0,%eax
f0101445:	eb 57                	jmp    f010149e <page_insert+0xb9>
	}
	else if(pg!=NULL )
f0101447:	85 c0                	test   %eax,%eax
f0101449:	74 0f                	je     f010145a <page_insert+0x75>
	{
		page_remove(pgdir,va);
f010144b:	89 74 24 04          	mov    %esi,0x4(%esp)
f010144f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101452:	89 04 24             	mov    %eax,(%esp)
f0101455:	e8 3b ff ff ff       	call   f0101395 <page_remove>
	}
	pte=pgdir_walk(pgdir,va,1);
f010145a:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101461:	00 
f0101462:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101466:	8b 45 08             	mov    0x8(%ebp),%eax
f0101469:	89 04 24             	mov    %eax,(%esp)
f010146c:	e8 e3 fc ff ff       	call   f0101154 <pgdir_walk>
	if(pte==NULL)
f0101471:	85 c0                	test   %eax,%eax
f0101473:	74 24                	je     f0101499 <page_insert+0xb4>
	{
		return -E_NO_MEM;
	}
	pte[0]=page2pa(pp)|perm|PTE_P;
f0101475:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101478:	83 c9 01             	or     $0x1,%ecx
f010147b:	89 da                	mov    %ebx,%edx
f010147d:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101483:	c1 fa 03             	sar    $0x3,%edx
f0101486:	c1 e2 0c             	shl    $0xc,%edx
f0101489:	09 ca                	or     %ecx,%edx
f010148b:	89 10                	mov    %edx,(%eax)
	pp->pp_ref++;
f010148d:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)
	return 0;
f0101492:	b8 00 00 00 00       	mov    $0x0,%eax
f0101497:	eb 05                	jmp    f010149e <page_insert+0xb9>
		page_remove(pgdir,va);
	}
	pte=pgdir_walk(pgdir,va,1);
	if(pte==NULL)
	{
		return -E_NO_MEM;
f0101499:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	}
	pte[0]=page2pa(pp)|perm|PTE_P;
	pp->pp_ref++;
	return 0;
}
f010149e:	83 c4 1c             	add    $0x1c,%esp
f01014a1:	5b                   	pop    %ebx
f01014a2:	5e                   	pop    %esi
f01014a3:	5f                   	pop    %edi
f01014a4:	5d                   	pop    %ebp
f01014a5:	c3                   	ret    

f01014a6 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01014a6:	55                   	push   %ebp
f01014a7:	89 e5                	mov    %esp,%ebp
f01014a9:	57                   	push   %edi
f01014aa:	56                   	push   %esi
f01014ab:	53                   	push   %ebx
f01014ac:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014af:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01014b6:	e8 0a 2b 00 00       	call   f0103fc5 <mc146818_read>
f01014bb:	89 c3                	mov    %eax,%ebx
f01014bd:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01014c4:	e8 fc 2a 00 00       	call   f0103fc5 <mc146818_read>
f01014c9:	c1 e0 08             	shl    $0x8,%eax
f01014cc:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014ce:	89 d8                	mov    %ebx,%eax
f01014d0:	c1 e0 0a             	shl    $0xa,%eax
f01014d3:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014d9:	85 c0                	test   %eax,%eax
f01014db:	0f 48 c2             	cmovs  %edx,%eax
f01014de:	c1 f8 0c             	sar    $0xc,%eax
f01014e1:	a3 44 32 22 f0       	mov    %eax,0xf0223244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014e6:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01014ed:	e8 d3 2a 00 00       	call   f0103fc5 <mc146818_read>
f01014f2:	89 c3                	mov    %eax,%ebx
f01014f4:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01014fb:	e8 c5 2a 00 00       	call   f0103fc5 <mc146818_read>
f0101500:	c1 e0 08             	shl    $0x8,%eax
f0101503:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0101505:	89 d8                	mov    %ebx,%eax
f0101507:	c1 e0 0a             	shl    $0xa,%eax
f010150a:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101510:	85 c0                	test   %eax,%eax
f0101512:	0f 48 c2             	cmovs  %edx,%eax
f0101515:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101518:	85 c0                	test   %eax,%eax
f010151a:	74 0e                	je     f010152a <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f010151c:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0101522:	89 15 88 3e 22 f0    	mov    %edx,0xf0223e88
f0101528:	eb 0c                	jmp    f0101536 <mem_init+0x90>
	else
		npages = npages_basemem;
f010152a:	8b 15 44 32 22 f0    	mov    0xf0223244,%edx
f0101530:	89 15 88 3e 22 f0    	mov    %edx,0xf0223e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101536:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101539:	c1 e8 0a             	shr    $0xa,%eax
f010153c:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0101540:	a1 44 32 22 f0       	mov    0xf0223244,%eax
f0101545:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101548:	c1 e8 0a             	shr    $0xa,%eax
f010154b:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f010154f:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0101554:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101557:	c1 e8 0a             	shr    $0xa,%eax
f010155a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010155e:	c7 04 24 0c 71 10 f0 	movl   $0xf010710c,(%esp)
f0101565:	e8 c7 2b 00 00       	call   f0104131 <cprintf>
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
	cprintf("npages :%u",npages);
f010156a:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f010156f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101573:	c7 04 24 7e 6d 10 f0 	movl   $0xf0106d7e,(%esp)
f010157a:	e8 b2 2b 00 00       	call   f0104131 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f010157f:	b8 00 10 00 00       	mov    $0x1000,%eax
f0101584:	e8 77 f5 ff ff       	call   f0100b00 <boot_alloc>
f0101589:	a3 8c 3e 22 f0       	mov    %eax,0xf0223e8c
	memset(kern_pgdir, 0, PGSIZE);
f010158e:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101595:	00 
f0101596:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010159d:	00 
f010159e:	89 04 24             	mov    %eax,(%esp)
f01015a1:	e8 73 43 00 00       	call   f0105919 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015a6:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01015ab:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01015b0:	77 20                	ja     f01015d2 <mem_init+0x12c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01015b2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015b6:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f01015bd:	f0 
f01015be:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f01015c5:	00 
f01015c6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01015cd:	e8 6e ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01015d2:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015d8:	83 ca 05             	or     $0x5,%edx
f01015db:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate an array of npages 'struct Page's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:
	pages = (struct Page *) boot_alloc(npages*sizeof(struct Page));
f01015e1:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f01015e6:	c1 e0 03             	shl    $0x3,%eax
f01015e9:	e8 12 f5 ff ff       	call   f0100b00 <boot_alloc>
f01015ee:	a3 90 3e 22 f0       	mov    %eax,0xf0223e90

	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs=(struct Env*)boot_alloc(NENV*sizeof(struct Env));
f01015f3:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f01015f8:	e8 03 f5 ff ff       	call   f0100b00 <boot_alloc>
f01015fd:	a3 48 32 22 f0       	mov    %eax,0xf0223248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101602:	e8 96 f9 ff ff       	call   f0100f9d <page_init>

	check_page_free_list(1);
f0101607:	b8 01 00 00 00       	mov    $0x1,%eax
f010160c:	e8 aa f5 ff ff       	call   f0100bbb <check_page_free_list>
// and page_init()).
//
static void
check_page_alloc(void)
{
	cprintf("check_page_alloc");
f0101611:	c7 04 24 89 6d 10 f0 	movl   $0xf0106d89,(%esp)
f0101618:	e8 14 2b 00 00       	call   f0104131 <cprintf>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f010161d:	83 3d 90 3e 22 f0 00 	cmpl   $0x0,0xf0223e90
f0101624:	75 1c                	jne    f0101642 <mem_init+0x19c>
		panic("'pages' is a null pointer!");
f0101626:	c7 44 24 08 9a 6d 10 	movl   $0xf0106d9a,0x8(%esp)
f010162d:	f0 
f010162e:	c7 44 24 04 28 03 00 	movl   $0x328,0x4(%esp)
f0101635:	00 
f0101636:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010163d:	e8 fe e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101642:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101647:	85 c0                	test   %eax,%eax
f0101649:	74 10                	je     f010165b <mem_init+0x1b5>
f010164b:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101650:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101653:	8b 00                	mov    (%eax),%eax
f0101655:	85 c0                	test   %eax,%eax
f0101657:	75 f7                	jne    f0101650 <mem_init+0x1aa>
f0101659:	eb 05                	jmp    f0101660 <mem_init+0x1ba>
f010165b:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101660:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101667:	e8 25 fa ff ff       	call   f0101091 <page_alloc>
f010166c:	89 c7                	mov    %eax,%edi
f010166e:	85 c0                	test   %eax,%eax
f0101670:	75 24                	jne    f0101696 <mem_init+0x1f0>
f0101672:	c7 44 24 0c b5 6d 10 	movl   $0xf0106db5,0xc(%esp)
f0101679:	f0 
f010167a:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101681:	f0 
f0101682:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f0101689:	00 
f010168a:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101691:	e8 aa e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101696:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010169d:	e8 ef f9 ff ff       	call   f0101091 <page_alloc>
f01016a2:	89 c6                	mov    %eax,%esi
f01016a4:	85 c0                	test   %eax,%eax
f01016a6:	75 24                	jne    f01016cc <mem_init+0x226>
f01016a8:	c7 44 24 0c cb 6d 10 	movl   $0xf0106dcb,0xc(%esp)
f01016af:	f0 
f01016b0:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01016b7:	f0 
f01016b8:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
f01016bf:	00 
f01016c0:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01016c7:	e8 74 e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016cc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016d3:	e8 b9 f9 ff ff       	call   f0101091 <page_alloc>
f01016d8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016db:	85 c0                	test   %eax,%eax
f01016dd:	75 24                	jne    f0101703 <mem_init+0x25d>
f01016df:	c7 44 24 0c e1 6d 10 	movl   $0xf0106de1,0xc(%esp)
f01016e6:	f0 
f01016e7:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01016ee:	f0 
f01016ef:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01016f6:	00 
f01016f7:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01016fe:	e8 3d e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101703:	39 f7                	cmp    %esi,%edi
f0101705:	75 24                	jne    f010172b <mem_init+0x285>
f0101707:	c7 44 24 0c f7 6d 10 	movl   $0xf0106df7,0xc(%esp)
f010170e:	f0 
f010170f:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101716:	f0 
f0101717:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f010171e:	00 
f010171f:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101726:	e8 15 e9 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010172b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010172e:	39 c6                	cmp    %eax,%esi
f0101730:	74 04                	je     f0101736 <mem_init+0x290>
f0101732:	39 c7                	cmp    %eax,%edi
f0101734:	75 24                	jne    f010175a <mem_init+0x2b4>
f0101736:	c7 44 24 0c 48 71 10 	movl   $0xf0107148,0xc(%esp)
f010173d:	f0 
f010173e:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101745:	f0 
f0101746:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f010174d:	00 
f010174e:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101755:	e8 e6 e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010175a:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101760:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0101765:	c1 e0 0c             	shl    $0xc,%eax
f0101768:	89 f9                	mov    %edi,%ecx
f010176a:	29 d1                	sub    %edx,%ecx
f010176c:	c1 f9 03             	sar    $0x3,%ecx
f010176f:	c1 e1 0c             	shl    $0xc,%ecx
f0101772:	39 c1                	cmp    %eax,%ecx
f0101774:	72 24                	jb     f010179a <mem_init+0x2f4>
f0101776:	c7 44 24 0c 09 6e 10 	movl   $0xf0106e09,0xc(%esp)
f010177d:	f0 
f010177e:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101785:	f0 
f0101786:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
f010178d:	00 
f010178e:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101795:	e8 a6 e8 ff ff       	call   f0100040 <_panic>
f010179a:	89 f1                	mov    %esi,%ecx
f010179c:	29 d1                	sub    %edx,%ecx
f010179e:	c1 f9 03             	sar    $0x3,%ecx
f01017a1:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01017a4:	39 c8                	cmp    %ecx,%eax
f01017a6:	77 24                	ja     f01017cc <mem_init+0x326>
f01017a8:	c7 44 24 0c 26 6e 10 	movl   $0xf0106e26,0xc(%esp)
f01017af:	f0 
f01017b0:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01017b7:	f0 
f01017b8:	c7 44 24 04 38 03 00 	movl   $0x338,0x4(%esp)
f01017bf:	00 
f01017c0:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01017c7:	e8 74 e8 ff ff       	call   f0100040 <_panic>
f01017cc:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017cf:	29 d1                	sub    %edx,%ecx
f01017d1:	89 ca                	mov    %ecx,%edx
f01017d3:	c1 fa 03             	sar    $0x3,%edx
f01017d6:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017d9:	39 d0                	cmp    %edx,%eax
f01017db:	77 24                	ja     f0101801 <mem_init+0x35b>
f01017dd:	c7 44 24 0c 43 6e 10 	movl   $0xf0106e43,0xc(%esp)
f01017e4:	f0 
f01017e5:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01017ec:	f0 
f01017ed:	c7 44 24 04 39 03 00 	movl   $0x339,0x4(%esp)
f01017f4:	00 
f01017f5:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01017fc:	e8 3f e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101801:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101806:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101809:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f0101810:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101813:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010181a:	e8 72 f8 ff ff       	call   f0101091 <page_alloc>
f010181f:	85 c0                	test   %eax,%eax
f0101821:	74 24                	je     f0101847 <mem_init+0x3a1>
f0101823:	c7 44 24 0c 60 6e 10 	movl   $0xf0106e60,0xc(%esp)
f010182a:	f0 
f010182b:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101832:	f0 
f0101833:	c7 44 24 04 40 03 00 	movl   $0x340,0x4(%esp)
f010183a:	00 
f010183b:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101842:	e8 f9 e7 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101847:	89 3c 24             	mov    %edi,(%esp)
f010184a:	e8 c7 f8 ff ff       	call   f0101116 <page_free>
	page_free(pp1);
f010184f:	89 34 24             	mov    %esi,(%esp)
f0101852:	e8 bf f8 ff ff       	call   f0101116 <page_free>
	page_free(pp2);
f0101857:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010185a:	89 04 24             	mov    %eax,(%esp)
f010185d:	e8 b4 f8 ff ff       	call   f0101116 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101862:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101869:	e8 23 f8 ff ff       	call   f0101091 <page_alloc>
f010186e:	89 c6                	mov    %eax,%esi
f0101870:	85 c0                	test   %eax,%eax
f0101872:	75 24                	jne    f0101898 <mem_init+0x3f2>
f0101874:	c7 44 24 0c b5 6d 10 	movl   $0xf0106db5,0xc(%esp)
f010187b:	f0 
f010187c:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101883:	f0 
f0101884:	c7 44 24 04 47 03 00 	movl   $0x347,0x4(%esp)
f010188b:	00 
f010188c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101893:	e8 a8 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101898:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010189f:	e8 ed f7 ff ff       	call   f0101091 <page_alloc>
f01018a4:	89 c7                	mov    %eax,%edi
f01018a6:	85 c0                	test   %eax,%eax
f01018a8:	75 24                	jne    f01018ce <mem_init+0x428>
f01018aa:	c7 44 24 0c cb 6d 10 	movl   $0xf0106dcb,0xc(%esp)
f01018b1:	f0 
f01018b2:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01018b9:	f0 
f01018ba:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f01018c1:	00 
f01018c2:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01018c9:	e8 72 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018ce:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018d5:	e8 b7 f7 ff ff       	call   f0101091 <page_alloc>
f01018da:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018dd:	85 c0                	test   %eax,%eax
f01018df:	75 24                	jne    f0101905 <mem_init+0x45f>
f01018e1:	c7 44 24 0c e1 6d 10 	movl   $0xf0106de1,0xc(%esp)
f01018e8:	f0 
f01018e9:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01018f0:	f0 
f01018f1:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f01018f8:	00 
f01018f9:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101900:	e8 3b e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101905:	39 fe                	cmp    %edi,%esi
f0101907:	75 24                	jne    f010192d <mem_init+0x487>
f0101909:	c7 44 24 0c f7 6d 10 	movl   $0xf0106df7,0xc(%esp)
f0101910:	f0 
f0101911:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101918:	f0 
f0101919:	c7 44 24 04 4b 03 00 	movl   $0x34b,0x4(%esp)
f0101920:	00 
f0101921:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101928:	e8 13 e7 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010192d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101930:	39 c7                	cmp    %eax,%edi
f0101932:	74 04                	je     f0101938 <mem_init+0x492>
f0101934:	39 c6                	cmp    %eax,%esi
f0101936:	75 24                	jne    f010195c <mem_init+0x4b6>
f0101938:	c7 44 24 0c 48 71 10 	movl   $0xf0107148,0xc(%esp)
f010193f:	f0 
f0101940:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101947:	f0 
f0101948:	c7 44 24 04 4c 03 00 	movl   $0x34c,0x4(%esp)
f010194f:	00 
f0101950:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101957:	e8 e4 e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f010195c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101963:	e8 29 f7 ff ff       	call   f0101091 <page_alloc>
f0101968:	85 c0                	test   %eax,%eax
f010196a:	74 24                	je     f0101990 <mem_init+0x4ea>
f010196c:	c7 44 24 0c 60 6e 10 	movl   $0xf0106e60,0xc(%esp)
f0101973:	f0 
f0101974:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010197b:	f0 
f010197c:	c7 44 24 04 4d 03 00 	movl   $0x34d,0x4(%esp)
f0101983:	00 
f0101984:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010198b:	e8 b0 e6 ff ff       	call   f0100040 <_panic>
f0101990:	89 f0                	mov    %esi,%eax
f0101992:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0101998:	c1 f8 03             	sar    $0x3,%eax
f010199b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010199e:	89 c2                	mov    %eax,%edx
f01019a0:	c1 ea 0c             	shr    $0xc,%edx
f01019a3:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01019a9:	72 20                	jb     f01019cb <mem_init+0x525>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019ab:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019af:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f01019b6:	f0 
f01019b7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01019be:	00 
f01019bf:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01019c6:	e8 75 e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019cb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019d2:	00 
f01019d3:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019da:	00 
	return (void *)(pa + KERNBASE);
f01019db:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01019e0:	89 04 24             	mov    %eax,(%esp)
f01019e3:	e8 31 3f 00 00       	call   f0105919 <memset>
	page_free(pp0);
f01019e8:	89 34 24             	mov    %esi,(%esp)
f01019eb:	e8 26 f7 ff ff       	call   f0101116 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01019f0:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01019f7:	e8 95 f6 ff ff       	call   f0101091 <page_alloc>
f01019fc:	85 c0                	test   %eax,%eax
f01019fe:	75 24                	jne    f0101a24 <mem_init+0x57e>
f0101a00:	c7 44 24 0c 6f 6e 10 	movl   $0xf0106e6f,0xc(%esp)
f0101a07:	f0 
f0101a08:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101a0f:	f0 
f0101a10:	c7 44 24 04 52 03 00 	movl   $0x352,0x4(%esp)
f0101a17:	00 
f0101a18:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101a1f:	e8 1c e6 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a24:	39 c6                	cmp    %eax,%esi
f0101a26:	74 24                	je     f0101a4c <mem_init+0x5a6>
f0101a28:	c7 44 24 0c 8d 6e 10 	movl   $0xf0106e8d,0xc(%esp)
f0101a2f:	f0 
f0101a30:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101a37:	f0 
f0101a38:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f0101a3f:	00 
f0101a40:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101a47:	e8 f4 e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a4c:	89 f2                	mov    %esi,%edx
f0101a4e:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101a54:	c1 fa 03             	sar    $0x3,%edx
f0101a57:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a5a:	89 d0                	mov    %edx,%eax
f0101a5c:	c1 e8 0c             	shr    $0xc,%eax
f0101a5f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0101a65:	72 20                	jb     f0101a87 <mem_init+0x5e1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a67:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a6b:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0101a72:	f0 
f0101a73:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a7a:	00 
f0101a7b:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0101a82:	e8 b9 e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101a87:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101a8e:	75 11                	jne    f0101aa1 <mem_init+0x5fb>
f0101a90:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101a96:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101a9c:	80 38 00             	cmpb   $0x0,(%eax)
f0101a9f:	74 24                	je     f0101ac5 <mem_init+0x61f>
f0101aa1:	c7 44 24 0c 9d 6e 10 	movl   $0xf0106e9d,0xc(%esp)
f0101aa8:	f0 
f0101aa9:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101ab0:	f0 
f0101ab1:	c7 44 24 04 56 03 00 	movl   $0x356,0x4(%esp)
f0101ab8:	00 
f0101ab9:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101ac0:	e8 7b e5 ff ff       	call   f0100040 <_panic>
f0101ac5:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101ac8:	39 d0                	cmp    %edx,%eax
f0101aca:	75 d0                	jne    f0101a9c <mem_init+0x5f6>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101acc:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101acf:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0101ad4:	89 34 24             	mov    %esi,(%esp)
f0101ad7:	e8 3a f6 ff ff       	call   f0101116 <page_free>
	page_free(pp1);
f0101adc:	89 3c 24             	mov    %edi,(%esp)
f0101adf:	e8 32 f6 ff ff       	call   f0101116 <page_free>
	page_free(pp2);
f0101ae4:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ae7:	89 04 24             	mov    %eax,(%esp)
f0101aea:	e8 27 f6 ff ff       	call   f0101116 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101aef:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101af4:	85 c0                	test   %eax,%eax
f0101af6:	74 09                	je     f0101b01 <mem_init+0x65b>
		--nfree;
f0101af8:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101afb:	8b 00                	mov    (%eax),%eax
f0101afd:	85 c0                	test   %eax,%eax
f0101aff:	75 f7                	jne    f0101af8 <mem_init+0x652>
		--nfree;
	assert(nfree == 0);
f0101b01:	85 db                	test   %ebx,%ebx
f0101b03:	74 24                	je     f0101b29 <mem_init+0x683>
f0101b05:	c7 44 24 0c a7 6e 10 	movl   $0xf0106ea7,0xc(%esp)
f0101b0c:	f0 
f0101b0d:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101b14:	f0 
f0101b15:	c7 44 24 04 63 03 00 	movl   $0x363,0x4(%esp)
f0101b1c:	00 
f0101b1d:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101b24:	e8 17 e5 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b29:	c7 04 24 68 71 10 f0 	movl   $0xf0107168,(%esp)
f0101b30:	e8 fc 25 00 00       	call   f0104131 <cprintf>

// check page_insert, page_remove, &c
static void
check_page(void)
{
	cprintf("check_page\r\n");
f0101b35:	c7 04 24 b2 6e 10 f0 	movl   $0xf0106eb2,(%esp)
f0101b3c:	e8 f0 25 00 00       	call   f0104131 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b41:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b48:	e8 44 f5 ff ff       	call   f0101091 <page_alloc>
f0101b4d:	89 c3                	mov    %eax,%ebx
f0101b4f:	85 c0                	test   %eax,%eax
f0101b51:	75 24                	jne    f0101b77 <mem_init+0x6d1>
f0101b53:	c7 44 24 0c b5 6d 10 	movl   $0xf0106db5,0xc(%esp)
f0101b5a:	f0 
f0101b5b:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101b62:	f0 
f0101b63:	c7 44 24 04 d9 03 00 	movl   $0x3d9,0x4(%esp)
f0101b6a:	00 
f0101b6b:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101b72:	e8 c9 e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b77:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b7e:	e8 0e f5 ff ff       	call   f0101091 <page_alloc>
f0101b83:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101b86:	85 c0                	test   %eax,%eax
f0101b88:	75 24                	jne    f0101bae <mem_init+0x708>
f0101b8a:	c7 44 24 0c cb 6d 10 	movl   $0xf0106dcb,0xc(%esp)
f0101b91:	f0 
f0101b92:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101b99:	f0 
f0101b9a:	c7 44 24 04 da 03 00 	movl   $0x3da,0x4(%esp)
f0101ba1:	00 
f0101ba2:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101ba9:	e8 92 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101bae:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bb5:	e8 d7 f4 ff ff       	call   f0101091 <page_alloc>
f0101bba:	89 c6                	mov    %eax,%esi
f0101bbc:	85 c0                	test   %eax,%eax
f0101bbe:	75 24                	jne    f0101be4 <mem_init+0x73e>
f0101bc0:	c7 44 24 0c e1 6d 10 	movl   $0xf0106de1,0xc(%esp)
f0101bc7:	f0 
f0101bc8:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101bcf:	f0 
f0101bd0:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0101bd7:	00 
f0101bd8:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101bdf:	e8 5c e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101be4:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101be7:	75 24                	jne    f0101c0d <mem_init+0x767>
f0101be9:	c7 44 24 0c f7 6d 10 	movl   $0xf0106df7,0xc(%esp)
f0101bf0:	f0 
f0101bf1:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101bf8:	f0 
f0101bf9:	c7 44 24 04 de 03 00 	movl   $0x3de,0x4(%esp)
f0101c00:	00 
f0101c01:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101c08:	e8 33 e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101c0d:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c10:	74 04                	je     f0101c16 <mem_init+0x770>
f0101c12:	39 c3                	cmp    %eax,%ebx
f0101c14:	75 24                	jne    f0101c3a <mem_init+0x794>
f0101c16:	c7 44 24 0c 48 71 10 	movl   $0xf0107148,0xc(%esp)
f0101c1d:	f0 
f0101c1e:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101c25:	f0 
f0101c26:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f0101c2d:	00 
f0101c2e:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101c35:	e8 06 e4 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c3a:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101c3f:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c42:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f0101c49:	00 00 00 
	cprintf("1");
f0101c4c:	c7 04 24 df 6e 10 f0 	movl   $0xf0106edf,(%esp)
f0101c53:	e8 d9 24 00 00       	call   f0104131 <cprintf>
	// should be no free memory
	assert(!page_alloc(0));
f0101c58:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c5f:	e8 2d f4 ff ff       	call   f0101091 <page_alloc>
f0101c64:	85 c0                	test   %eax,%eax
f0101c66:	74 24                	je     f0101c8c <mem_init+0x7e6>
f0101c68:	c7 44 24 0c 60 6e 10 	movl   $0xf0106e60,0xc(%esp)
f0101c6f:	f0 
f0101c70:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101c77:	f0 
f0101c78:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f0101c7f:	00 
f0101c80:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101c87:	e8 b4 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c8c:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c8f:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c93:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101c9a:	00 
f0101c9b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101ca0:	89 04 24             	mov    %eax,(%esp)
f0101ca3:	e8 40 f6 ff ff       	call   f01012e8 <page_lookup>
f0101ca8:	85 c0                	test   %eax,%eax
f0101caa:	74 24                	je     f0101cd0 <mem_init+0x82a>
f0101cac:	c7 44 24 0c 88 71 10 	movl   $0xf0107188,0xc(%esp)
f0101cb3:	f0 
f0101cb4:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101cbb:	f0 
f0101cbc:	c7 44 24 04 e9 03 00 	movl   $0x3e9,0x4(%esp)
f0101cc3:	00 
f0101cc4:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101ccb:	e8 70 e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101cd0:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101cd7:	00 
f0101cd8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101cdf:	00 
f0101ce0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ce3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101ce7:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101cec:	89 04 24             	mov    %eax,(%esp)
f0101cef:	e8 f1 f6 ff ff       	call   f01013e5 <page_insert>
f0101cf4:	85 c0                	test   %eax,%eax
f0101cf6:	78 24                	js     f0101d1c <mem_init+0x876>
f0101cf8:	c7 44 24 0c c0 71 10 	movl   $0xf01071c0,0xc(%esp)
f0101cff:	f0 
f0101d00:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101d07:	f0 
f0101d08:	c7 44 24 04 ec 03 00 	movl   $0x3ec,0x4(%esp)
f0101d0f:	00 
f0101d10:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101d17:	e8 24 e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d1c:	89 1c 24             	mov    %ebx,(%esp)
f0101d1f:	e8 f2 f3 ff ff       	call   f0101116 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d24:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d2b:	00 
f0101d2c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d33:	00 
f0101d34:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d37:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d3b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101d40:	89 04 24             	mov    %eax,(%esp)
f0101d43:	e8 9d f6 ff ff       	call   f01013e5 <page_insert>
f0101d48:	85 c0                	test   %eax,%eax
f0101d4a:	74 24                	je     f0101d70 <mem_init+0x8ca>
f0101d4c:	c7 44 24 0c f0 71 10 	movl   $0xf01071f0,0xc(%esp)
f0101d53:	f0 
f0101d54:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101d5b:	f0 
f0101d5c:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0101d63:	00 
f0101d64:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101d6b:	e8 d0 e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d70:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d75:	8b 3d 90 3e 22 f0    	mov    0xf0223e90,%edi
f0101d7b:	8b 08                	mov    (%eax),%ecx
f0101d7d:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0101d83:	89 da                	mov    %ebx,%edx
f0101d85:	29 fa                	sub    %edi,%edx
f0101d87:	c1 fa 03             	sar    $0x3,%edx
f0101d8a:	c1 e2 0c             	shl    $0xc,%edx
f0101d8d:	39 d1                	cmp    %edx,%ecx
f0101d8f:	74 24                	je     f0101db5 <mem_init+0x90f>
f0101d91:	c7 44 24 0c 20 72 10 	movl   $0xf0107220,0xc(%esp)
f0101d98:	f0 
f0101d99:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101da0:	f0 
f0101da1:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
f0101da8:	00 
f0101da9:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101db0:	e8 8b e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101db5:	ba 00 00 00 00       	mov    $0x0,%edx
f0101dba:	e8 8d ed ff ff       	call   f0100b4c <check_va2pa>
f0101dbf:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101dc2:	29 fa                	sub    %edi,%edx
f0101dc4:	c1 fa 03             	sar    $0x3,%edx
f0101dc7:	c1 e2 0c             	shl    $0xc,%edx
f0101dca:	39 d0                	cmp    %edx,%eax
f0101dcc:	74 24                	je     f0101df2 <mem_init+0x94c>
f0101dce:	c7 44 24 0c 48 72 10 	movl   $0xf0107248,0xc(%esp)
f0101dd5:	f0 
f0101dd6:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101ddd:	f0 
f0101dde:	c7 44 24 04 f2 03 00 	movl   $0x3f2,0x4(%esp)
f0101de5:	00 
f0101de6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101ded:	e8 4e e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101df2:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101df5:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101dfa:	74 24                	je     f0101e20 <mem_init+0x97a>
f0101dfc:	c7 44 24 0c bf 6e 10 	movl   $0xf0106ebf,0xc(%esp)
f0101e03:	f0 
f0101e04:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101e0b:	f0 
f0101e0c:	c7 44 24 04 f3 03 00 	movl   $0x3f3,0x4(%esp)
f0101e13:	00 
f0101e14:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101e1b:	e8 20 e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e20:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e25:	74 24                	je     f0101e4b <mem_init+0x9a5>
f0101e27:	c7 44 24 0c d0 6e 10 	movl   $0xf0106ed0,0xc(%esp)
f0101e2e:	f0 
f0101e2f:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101e36:	f0 
f0101e37:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0101e3e:	00 
f0101e3f:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101e46:	e8 f5 e1 ff ff       	call   f0100040 <_panic>
	cprintf("2");
f0101e4b:	c7 04 24 1b 6f 10 f0 	movl   $0xf0106f1b,(%esp)
f0101e52:	e8 da 22 00 00       	call   f0104131 <cprintf>
	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e57:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e5e:	00 
f0101e5f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e66:	00 
f0101e67:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e6b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101e70:	89 04 24             	mov    %eax,(%esp)
f0101e73:	e8 6d f5 ff ff       	call   f01013e5 <page_insert>
f0101e78:	85 c0                	test   %eax,%eax
f0101e7a:	74 24                	je     f0101ea0 <mem_init+0x9fa>
f0101e7c:	c7 44 24 0c 78 72 10 	movl   $0xf0107278,0xc(%esp)
f0101e83:	f0 
f0101e84:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101e8b:	f0 
f0101e8c:	c7 44 24 04 f7 03 00 	movl   $0x3f7,0x4(%esp)
f0101e93:	00 
f0101e94:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101e9b:	e8 a0 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101ea0:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101ea5:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101eaa:	e8 9d ec ff ff       	call   f0100b4c <check_va2pa>
f0101eaf:	89 f2                	mov    %esi,%edx
f0101eb1:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101eb7:	c1 fa 03             	sar    $0x3,%edx
f0101eba:	c1 e2 0c             	shl    $0xc,%edx
f0101ebd:	39 d0                	cmp    %edx,%eax
f0101ebf:	74 24                	je     f0101ee5 <mem_init+0xa3f>
f0101ec1:	c7 44 24 0c b4 72 10 	movl   $0xf01072b4,0xc(%esp)
f0101ec8:	f0 
f0101ec9:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101ed0:	f0 
f0101ed1:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f0101ed8:	00 
f0101ed9:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101ee0:	e8 5b e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ee5:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101eea:	74 24                	je     f0101f10 <mem_init+0xa6a>
f0101eec:	c7 44 24 0c e1 6e 10 	movl   $0xf0106ee1,0xc(%esp)
f0101ef3:	f0 
f0101ef4:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101efb:	f0 
f0101efc:	c7 44 24 04 f9 03 00 	movl   $0x3f9,0x4(%esp)
f0101f03:	00 
f0101f04:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101f0b:	e8 30 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101f10:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f17:	e8 75 f1 ff ff       	call   f0101091 <page_alloc>
f0101f1c:	85 c0                	test   %eax,%eax
f0101f1e:	74 24                	je     f0101f44 <mem_init+0xa9e>
f0101f20:	c7 44 24 0c 60 6e 10 	movl   $0xf0106e60,0xc(%esp)
f0101f27:	f0 
f0101f28:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101f2f:	f0 
f0101f30:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f0101f37:	00 
f0101f38:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101f3f:	e8 fc e0 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f44:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f4b:	00 
f0101f4c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f53:	00 
f0101f54:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101f58:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101f5d:	89 04 24             	mov    %eax,(%esp)
f0101f60:	e8 80 f4 ff ff       	call   f01013e5 <page_insert>
f0101f65:	85 c0                	test   %eax,%eax
f0101f67:	74 24                	je     f0101f8d <mem_init+0xae7>
f0101f69:	c7 44 24 0c 78 72 10 	movl   $0xf0107278,0xc(%esp)
f0101f70:	f0 
f0101f71:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101f78:	f0 
f0101f79:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f0101f80:	00 
f0101f81:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101f88:	e8 b3 e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f8d:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f92:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101f97:	e8 b0 eb ff ff       	call   f0100b4c <check_va2pa>
f0101f9c:	89 f2                	mov    %esi,%edx
f0101f9e:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101fa4:	c1 fa 03             	sar    $0x3,%edx
f0101fa7:	c1 e2 0c             	shl    $0xc,%edx
f0101faa:	39 d0                	cmp    %edx,%eax
f0101fac:	74 24                	je     f0101fd2 <mem_init+0xb2c>
f0101fae:	c7 44 24 0c b4 72 10 	movl   $0xf01072b4,0xc(%esp)
f0101fb5:	f0 
f0101fb6:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101fbd:	f0 
f0101fbe:	c7 44 24 04 00 04 00 	movl   $0x400,0x4(%esp)
f0101fc5:	00 
f0101fc6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101fcd:	e8 6e e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fd2:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101fd7:	74 24                	je     f0101ffd <mem_init+0xb57>
f0101fd9:	c7 44 24 0c e1 6e 10 	movl   $0xf0106ee1,0xc(%esp)
f0101fe0:	f0 
f0101fe1:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0101fe8:	f0 
f0101fe9:	c7 44 24 04 01 04 00 	movl   $0x401,0x4(%esp)
f0101ff0:	00 
f0101ff1:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0101ff8:	e8 43 e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101ffd:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102004:	e8 88 f0 ff ff       	call   f0101091 <page_alloc>
f0102009:	85 c0                	test   %eax,%eax
f010200b:	74 24                	je     f0102031 <mem_init+0xb8b>
f010200d:	c7 44 24 0c 60 6e 10 	movl   $0xf0106e60,0xc(%esp)
f0102014:	f0 
f0102015:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010201c:	f0 
f010201d:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102024:	00 
f0102025:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010202c:	e8 0f e0 ff ff       	call   f0100040 <_panic>
	cprintf("3");
f0102031:	c7 04 24 f2 6e 10 f0 	movl   $0xf0106ef2,(%esp)
f0102038:	e8 f4 20 00 00       	call   f0104131 <cprintf>
	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f010203d:	8b 15 8c 3e 22 f0    	mov    0xf0223e8c,%edx
f0102043:	8b 02                	mov    (%edx),%eax
f0102045:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010204a:	89 c1                	mov    %eax,%ecx
f010204c:	c1 e9 0c             	shr    $0xc,%ecx
f010204f:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0102055:	72 20                	jb     f0102077 <mem_init+0xbd1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102057:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010205b:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0102062:	f0 
f0102063:	c7 44 24 04 08 04 00 	movl   $0x408,0x4(%esp)
f010206a:	00 
f010206b:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102072:	e8 c9 df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102077:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010207c:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f010207f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102086:	00 
f0102087:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010208e:	00 
f010208f:	89 14 24             	mov    %edx,(%esp)
f0102092:	e8 bd f0 ff ff       	call   f0101154 <pgdir_walk>
f0102097:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010209a:	8d 57 04             	lea    0x4(%edi),%edx
f010209d:	39 d0                	cmp    %edx,%eax
f010209f:	74 24                	je     f01020c5 <mem_init+0xc1f>
f01020a1:	c7 44 24 0c e4 72 10 	movl   $0xf01072e4,0xc(%esp)
f01020a8:	f0 
f01020a9:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01020b0:	f0 
f01020b1:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01020b8:	00 
f01020b9:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01020c0:	e8 7b df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f01020c5:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020cc:	00 
f01020cd:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020d4:	00 
f01020d5:	89 74 24 04          	mov    %esi,0x4(%esp)
f01020d9:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01020de:	89 04 24             	mov    %eax,(%esp)
f01020e1:	e8 ff f2 ff ff       	call   f01013e5 <page_insert>
f01020e6:	85 c0                	test   %eax,%eax
f01020e8:	74 24                	je     f010210e <mem_init+0xc68>
f01020ea:	c7 44 24 0c 24 73 10 	movl   $0xf0107324,0xc(%esp)
f01020f1:	f0 
f01020f2:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01020f9:	f0 
f01020fa:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f0102101:	00 
f0102102:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102109:	e8 32 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f010210e:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f0102114:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102119:	89 f8                	mov    %edi,%eax
f010211b:	e8 2c ea ff ff       	call   f0100b4c <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102120:	89 f2                	mov    %esi,%edx
f0102122:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102128:	c1 fa 03             	sar    $0x3,%edx
f010212b:	c1 e2 0c             	shl    $0xc,%edx
f010212e:	39 d0                	cmp    %edx,%eax
f0102130:	74 24                	je     f0102156 <mem_init+0xcb0>
f0102132:	c7 44 24 0c b4 72 10 	movl   $0xf01072b4,0xc(%esp)
f0102139:	f0 
f010213a:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102141:	f0 
f0102142:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f0102149:	00 
f010214a:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102151:	e8 ea de ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102156:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f010215b:	74 24                	je     f0102181 <mem_init+0xcdb>
f010215d:	c7 44 24 0c e1 6e 10 	movl   $0xf0106ee1,0xc(%esp)
f0102164:	f0 
f0102165:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010216c:	f0 
f010216d:	c7 44 24 04 0e 04 00 	movl   $0x40e,0x4(%esp)
f0102174:	00 
f0102175:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010217c:	e8 bf de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0102181:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102188:	00 
f0102189:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102190:	00 
f0102191:	89 3c 24             	mov    %edi,(%esp)
f0102194:	e8 bb ef ff ff       	call   f0101154 <pgdir_walk>
f0102199:	f6 00 04             	testb  $0x4,(%eax)
f010219c:	75 24                	jne    f01021c2 <mem_init+0xd1c>
f010219e:	c7 44 24 0c 64 73 10 	movl   $0xf0107364,0xc(%esp)
f01021a5:	f0 
f01021a6:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01021ad:	f0 
f01021ae:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
f01021b5:	00 
f01021b6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01021bd:	e8 7e de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021c2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01021c7:	f6 00 04             	testb  $0x4,(%eax)
f01021ca:	75 24                	jne    f01021f0 <mem_init+0xd4a>
f01021cc:	c7 44 24 0c f4 6e 10 	movl   $0xf0106ef4,0xc(%esp)
f01021d3:	f0 
f01021d4:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01021db:	f0 
f01021dc:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f01021e3:	00 
f01021e4:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01021eb:	e8 50 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021f0:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021f7:	00 
f01021f8:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021ff:	00 
f0102200:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102204:	89 04 24             	mov    %eax,(%esp)
f0102207:	e8 d9 f1 ff ff       	call   f01013e5 <page_insert>
f010220c:	85 c0                	test   %eax,%eax
f010220e:	78 24                	js     f0102234 <mem_init+0xd8e>
f0102210:	c7 44 24 0c 98 73 10 	movl   $0xf0107398,0xc(%esp)
f0102217:	f0 
f0102218:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010221f:	f0 
f0102220:	c7 44 24 04 13 04 00 	movl   $0x413,0x4(%esp)
f0102227:	00 
f0102228:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010222f:	e8 0c de ff ff       	call   f0100040 <_panic>
	cprintf("4");
f0102234:	c7 04 24 0a 6f 10 f0 	movl   $0xf0106f0a,(%esp)
f010223b:	e8 f1 1e 00 00       	call   f0104131 <cprintf>
	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102240:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102247:	00 
f0102248:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010224f:	00 
f0102250:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102253:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102257:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010225c:	89 04 24             	mov    %eax,(%esp)
f010225f:	e8 81 f1 ff ff       	call   f01013e5 <page_insert>
f0102264:	85 c0                	test   %eax,%eax
f0102266:	74 24                	je     f010228c <mem_init+0xde6>
f0102268:	c7 44 24 0c d0 73 10 	movl   $0xf01073d0,0xc(%esp)
f010226f:	f0 
f0102270:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102277:	f0 
f0102278:	c7 44 24 04 16 04 00 	movl   $0x416,0x4(%esp)
f010227f:	00 
f0102280:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102287:	e8 b4 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f010228c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102293:	00 
f0102294:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010229b:	00 
f010229c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01022a1:	89 04 24             	mov    %eax,(%esp)
f01022a4:	e8 ab ee ff ff       	call   f0101154 <pgdir_walk>
f01022a9:	f6 00 04             	testb  $0x4,(%eax)
f01022ac:	74 24                	je     f01022d2 <mem_init+0xe2c>
f01022ae:	c7 44 24 0c 0c 74 10 	movl   $0xf010740c,0xc(%esp)
f01022b5:	f0 
f01022b6:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01022bd:	f0 
f01022be:	c7 44 24 04 17 04 00 	movl   $0x417,0x4(%esp)
f01022c5:	00 
f01022c6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01022cd:	e8 6e dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022d2:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f01022d8:	ba 00 00 00 00       	mov    $0x0,%edx
f01022dd:	89 f8                	mov    %edi,%eax
f01022df:	e8 68 e8 ff ff       	call   f0100b4c <check_va2pa>
f01022e4:	89 c1                	mov    %eax,%ecx
f01022e6:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022e9:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022ec:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01022f2:	c1 f8 03             	sar    $0x3,%eax
f01022f5:	c1 e0 0c             	shl    $0xc,%eax
f01022f8:	39 c1                	cmp    %eax,%ecx
f01022fa:	74 24                	je     f0102320 <mem_init+0xe7a>
f01022fc:	c7 44 24 0c 44 74 10 	movl   $0xf0107444,0xc(%esp)
f0102303:	f0 
f0102304:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010230b:	f0 
f010230c:	c7 44 24 04 1a 04 00 	movl   $0x41a,0x4(%esp)
f0102313:	00 
f0102314:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010231b:	e8 20 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102320:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102325:	89 f8                	mov    %edi,%eax
f0102327:	e8 20 e8 ff ff       	call   f0100b4c <check_va2pa>
f010232c:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f010232f:	74 24                	je     f0102355 <mem_init+0xeaf>
f0102331:	c7 44 24 0c 70 74 10 	movl   $0xf0107470,0xc(%esp)
f0102338:	f0 
f0102339:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102340:	f0 
f0102341:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f0102348:	00 
f0102349:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102350:	e8 eb dc ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102355:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102358:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010235d:	74 24                	je     f0102383 <mem_init+0xedd>
f010235f:	c7 44 24 0c 0c 6f 10 	movl   $0xf0106f0c,0xc(%esp)
f0102366:	f0 
f0102367:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010236e:	f0 
f010236f:	c7 44 24 04 1d 04 00 	movl   $0x41d,0x4(%esp)
f0102376:	00 
f0102377:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010237e:	e8 bd dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102383:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102388:	74 24                	je     f01023ae <mem_init+0xf08>
f010238a:	c7 44 24 0c 1d 6f 10 	movl   $0xf0106f1d,0xc(%esp)
f0102391:	f0 
f0102392:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102399:	f0 
f010239a:	c7 44 24 04 1e 04 00 	movl   $0x41e,0x4(%esp)
f01023a1:	00 
f01023a2:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01023a9:	e8 92 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f01023ae:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01023b5:	e8 d7 ec ff ff       	call   f0101091 <page_alloc>
f01023ba:	85 c0                	test   %eax,%eax
f01023bc:	74 04                	je     f01023c2 <mem_init+0xf1c>
f01023be:	39 c6                	cmp    %eax,%esi
f01023c0:	74 24                	je     f01023e6 <mem_init+0xf40>
f01023c2:	c7 44 24 0c a0 74 10 	movl   $0xf01074a0,0xc(%esp)
f01023c9:	f0 
f01023ca:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01023d1:	f0 
f01023d2:	c7 44 24 04 21 04 00 	movl   $0x421,0x4(%esp)
f01023d9:	00 
f01023da:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01023e1:	e8 5a dc ff ff       	call   f0100040 <_panic>
	cprintf("5");
f01023e6:	c7 04 24 2e 6f 10 f0 	movl   $0xf0106f2e,(%esp)
f01023ed:	e8 3f 1d 00 00       	call   f0104131 <cprintf>
	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023f2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023f9:	00 
f01023fa:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01023ff:	89 04 24             	mov    %eax,(%esp)
f0102402:	e8 8e ef ff ff       	call   f0101395 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f0102407:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f010240d:	ba 00 00 00 00       	mov    $0x0,%edx
f0102412:	89 f8                	mov    %edi,%eax
f0102414:	e8 33 e7 ff ff       	call   f0100b4c <check_va2pa>
f0102419:	83 f8 ff             	cmp    $0xffffffff,%eax
f010241c:	74 24                	je     f0102442 <mem_init+0xf9c>
f010241e:	c7 44 24 0c c4 74 10 	movl   $0xf01074c4,0xc(%esp)
f0102425:	f0 
f0102426:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010242d:	f0 
f010242e:	c7 44 24 04 25 04 00 	movl   $0x425,0x4(%esp)
f0102435:	00 
f0102436:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010243d:	e8 fe db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102442:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102447:	89 f8                	mov    %edi,%eax
f0102449:	e8 fe e6 ff ff       	call   f0100b4c <check_va2pa>
f010244e:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102451:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102457:	c1 fa 03             	sar    $0x3,%edx
f010245a:	c1 e2 0c             	shl    $0xc,%edx
f010245d:	39 d0                	cmp    %edx,%eax
f010245f:	74 24                	je     f0102485 <mem_init+0xfdf>
f0102461:	c7 44 24 0c 70 74 10 	movl   $0xf0107470,0xc(%esp)
f0102468:	f0 
f0102469:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102470:	f0 
f0102471:	c7 44 24 04 26 04 00 	movl   $0x426,0x4(%esp)
f0102478:	00 
f0102479:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102480:	e8 bb db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102485:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102488:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010248d:	74 24                	je     f01024b3 <mem_init+0x100d>
f010248f:	c7 44 24 0c bf 6e 10 	movl   $0xf0106ebf,0xc(%esp)
f0102496:	f0 
f0102497:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010249e:	f0 
f010249f:	c7 44 24 04 27 04 00 	movl   $0x427,0x4(%esp)
f01024a6:	00 
f01024a7:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01024ae:	e8 8d db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f01024b3:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01024b8:	74 24                	je     f01024de <mem_init+0x1038>
f01024ba:	c7 44 24 0c 1d 6f 10 	movl   $0xf0106f1d,0xc(%esp)
f01024c1:	f0 
f01024c2:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01024c9:	f0 
f01024ca:	c7 44 24 04 28 04 00 	movl   $0x428,0x4(%esp)
f01024d1:	00 
f01024d2:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01024d9:	e8 62 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024de:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024e5:	00 
f01024e6:	89 3c 24             	mov    %edi,(%esp)
f01024e9:	e8 a7 ee ff ff       	call   f0101395 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024ee:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f01024f4:	ba 00 00 00 00       	mov    $0x0,%edx
f01024f9:	89 f8                	mov    %edi,%eax
f01024fb:	e8 4c e6 ff ff       	call   f0100b4c <check_va2pa>
f0102500:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102503:	74 24                	je     f0102529 <mem_init+0x1083>
f0102505:	c7 44 24 0c c4 74 10 	movl   $0xf01074c4,0xc(%esp)
f010250c:	f0 
f010250d:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102514:	f0 
f0102515:	c7 44 24 04 2c 04 00 	movl   $0x42c,0x4(%esp)
f010251c:	00 
f010251d:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102524:	e8 17 db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102529:	ba 00 10 00 00       	mov    $0x1000,%edx
f010252e:	89 f8                	mov    %edi,%eax
f0102530:	e8 17 e6 ff ff       	call   f0100b4c <check_va2pa>
f0102535:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102538:	74 24                	je     f010255e <mem_init+0x10b8>
f010253a:	c7 44 24 0c e8 74 10 	movl   $0xf01074e8,0xc(%esp)
f0102541:	f0 
f0102542:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102549:	f0 
f010254a:	c7 44 24 04 2d 04 00 	movl   $0x42d,0x4(%esp)
f0102551:	00 
f0102552:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102559:	e8 e2 da ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f010255e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102561:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102566:	74 24                	je     f010258c <mem_init+0x10e6>
f0102568:	c7 44 24 0c 30 6f 10 	movl   $0xf0106f30,0xc(%esp)
f010256f:	f0 
f0102570:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102577:	f0 
f0102578:	c7 44 24 04 2e 04 00 	movl   $0x42e,0x4(%esp)
f010257f:	00 
f0102580:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102587:	e8 b4 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010258c:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102591:	74 24                	je     f01025b7 <mem_init+0x1111>
f0102593:	c7 44 24 0c 1d 6f 10 	movl   $0xf0106f1d,0xc(%esp)
f010259a:	f0 
f010259b:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01025a2:	f0 
f01025a3:	c7 44 24 04 2f 04 00 	movl   $0x42f,0x4(%esp)
f01025aa:	00 
f01025ab:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01025b2:	e8 89 da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01025b7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025be:	e8 ce ea ff ff       	call   f0101091 <page_alloc>
f01025c3:	85 c0                	test   %eax,%eax
f01025c5:	74 05                	je     f01025cc <mem_init+0x1126>
f01025c7:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025ca:	74 24                	je     f01025f0 <mem_init+0x114a>
f01025cc:	c7 44 24 0c 10 75 10 	movl   $0xf0107510,0xc(%esp)
f01025d3:	f0 
f01025d4:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01025db:	f0 
f01025dc:	c7 44 24 04 32 04 00 	movl   $0x432,0x4(%esp)
f01025e3:	00 
f01025e4:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01025eb:	e8 50 da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025f0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025f7:	e8 95 ea ff ff       	call   f0101091 <page_alloc>
f01025fc:	85 c0                	test   %eax,%eax
f01025fe:	74 24                	je     f0102624 <mem_init+0x117e>
f0102600:	c7 44 24 0c 60 6e 10 	movl   $0xf0106e60,0xc(%esp)
f0102607:	f0 
f0102608:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010260f:	f0 
f0102610:	c7 44 24 04 35 04 00 	movl   $0x435,0x4(%esp)
f0102617:	00 
f0102618:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010261f:	e8 1c da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102624:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102629:	8b 08                	mov    (%eax),%ecx
f010262b:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102631:	89 da                	mov    %ebx,%edx
f0102633:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102639:	c1 fa 03             	sar    $0x3,%edx
f010263c:	c1 e2 0c             	shl    $0xc,%edx
f010263f:	39 d1                	cmp    %edx,%ecx
f0102641:	74 24                	je     f0102667 <mem_init+0x11c1>
f0102643:	c7 44 24 0c 20 72 10 	movl   $0xf0107220,0xc(%esp)
f010264a:	f0 
f010264b:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102652:	f0 
f0102653:	c7 44 24 04 38 04 00 	movl   $0x438,0x4(%esp)
f010265a:	00 
f010265b:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102662:	e8 d9 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102667:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010266d:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102672:	74 24                	je     f0102698 <mem_init+0x11f2>
f0102674:	c7 44 24 0c d0 6e 10 	movl   $0xf0106ed0,0xc(%esp)
f010267b:	f0 
f010267c:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102683:	f0 
f0102684:	c7 44 24 04 3a 04 00 	movl   $0x43a,0x4(%esp)
f010268b:	00 
f010268c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102693:	e8 a8 d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0102698:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
	cprintf("6");
f010269e:	c7 04 24 41 6f 10 f0 	movl   $0xf0106f41,(%esp)
f01026a5:	e8 87 1a 00 00       	call   f0104131 <cprintf>
	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f01026aa:	89 1c 24             	mov    %ebx,(%esp)
f01026ad:	e8 64 ea ff ff       	call   f0101116 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f01026b2:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01026b9:	00 
f01026ba:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01026c1:	00 
f01026c2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01026c7:	89 04 24             	mov    %eax,(%esp)
f01026ca:	e8 85 ea ff ff       	call   f0101154 <pgdir_walk>
f01026cf:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026d2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026d5:	8b 15 8c 3e 22 f0    	mov    0xf0223e8c,%edx
f01026db:	8b 7a 04             	mov    0x4(%edx),%edi
f01026de:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026e4:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f01026ea:	89 f8                	mov    %edi,%eax
f01026ec:	c1 e8 0c             	shr    $0xc,%eax
f01026ef:	39 c8                	cmp    %ecx,%eax
f01026f1:	72 20                	jb     f0102713 <mem_init+0x126d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026f3:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01026f7:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f01026fe:	f0 
f01026ff:	c7 44 24 04 41 04 00 	movl   $0x441,0x4(%esp)
f0102706:	00 
f0102707:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010270e:	e8 2d d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f0102713:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f0102719:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f010271c:	74 24                	je     f0102742 <mem_init+0x129c>
f010271e:	c7 44 24 0c 43 6f 10 	movl   $0xf0106f43,0xc(%esp)
f0102725:	f0 
f0102726:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010272d:	f0 
f010272e:	c7 44 24 04 42 04 00 	movl   $0x442,0x4(%esp)
f0102735:	00 
f0102736:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010273d:	e8 fe d8 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102742:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f0102749:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010274f:	89 d8                	mov    %ebx,%eax
f0102751:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0102757:	c1 f8 03             	sar    $0x3,%eax
f010275a:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010275d:	89 c2                	mov    %eax,%edx
f010275f:	c1 ea 0c             	shr    $0xc,%edx
f0102762:	39 d1                	cmp    %edx,%ecx
f0102764:	77 20                	ja     f0102786 <mem_init+0x12e0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102766:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010276a:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0102771:	f0 
f0102772:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102779:	00 
f010277a:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0102781:	e8 ba d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102786:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010278d:	00 
f010278e:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102795:	00 
	return (void *)(pa + KERNBASE);
f0102796:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010279b:	89 04 24             	mov    %eax,(%esp)
f010279e:	e8 76 31 00 00       	call   f0105919 <memset>
	page_free(pp0);
f01027a3:	89 1c 24             	mov    %ebx,(%esp)
f01027a6:	e8 6b e9 ff ff       	call   f0101116 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f01027ab:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01027b2:	00 
f01027b3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01027ba:	00 
f01027bb:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01027c0:	89 04 24             	mov    %eax,(%esp)
f01027c3:	e8 8c e9 ff ff       	call   f0101154 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01027c8:	89 da                	mov    %ebx,%edx
f01027ca:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01027d0:	c1 fa 03             	sar    $0x3,%edx
f01027d3:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027d6:	89 d0                	mov    %edx,%eax
f01027d8:	c1 e8 0c             	shr    $0xc,%eax
f01027db:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01027e1:	72 20                	jb     f0102803 <mem_init+0x135d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027e3:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027e7:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f01027ee:	f0 
f01027ef:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027f6:	00 
f01027f7:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01027fe:	e8 3d d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102803:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f0102809:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f010280c:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f0102813:	75 11                	jne    f0102826 <mem_init+0x1380>
f0102815:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f010281b:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0102821:	f6 00 01             	testb  $0x1,(%eax)
f0102824:	74 24                	je     f010284a <mem_init+0x13a4>
f0102826:	c7 44 24 0c 5b 6f 10 	movl   $0xf0106f5b,0xc(%esp)
f010282d:	f0 
f010282e:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102835:	f0 
f0102836:	c7 44 24 04 4c 04 00 	movl   $0x44c,0x4(%esp)
f010283d:	00 
f010283e:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102845:	e8 f6 d7 ff ff       	call   f0100040 <_panic>
f010284a:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f010284d:	39 d0                	cmp    %edx,%eax
f010284f:	75 d0                	jne    f0102821 <mem_init+0x137b>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102851:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102856:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010285c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
	cprintf("7");
f0102862:	c7 04 24 72 6f 10 f0 	movl   $0xf0106f72,(%esp)
f0102869:	e8 c3 18 00 00       	call   f0104131 <cprintf>
	// give free list back
	page_free_list = fl;
f010286e:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102871:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0102876:	89 1c 24             	mov    %ebx,(%esp)
f0102879:	e8 98 e8 ff ff       	call   f0101116 <page_free>
	page_free(pp1);
f010287e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102881:	89 04 24             	mov    %eax,(%esp)
f0102884:	e8 8d e8 ff ff       	call   f0101116 <page_free>
	page_free(pp2);
f0102889:	89 34 24             	mov    %esi,(%esp)
f010288c:	e8 85 e8 ff ff       	call   f0101116 <page_free>

	cprintf("check_page() succeeded!\n");
f0102891:	c7 04 24 74 6f 10 f0 	movl   $0xf0106f74,(%esp)
f0102898:	e8 94 18 00 00       	call   f0104131 <cprintf>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f010289d:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f01028a3:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f01028aa:	89 c2                	mov    %eax,%edx
f01028ac:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f01028b2:	39 d0                	cmp    %edx,%eax
f01028b4:	0f 84 f1 0b 00 00    	je     f01034ab <mem_init+0x2005>
	{

		page_insert(kern_pgdir, pa2page(PADDR(pages)+i),(void*) (UPAGES+i), PTE_U);
f01028ba:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028bf:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028c4:	76 21                	jbe    f01028e7 <mem_init+0x1441>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01028c6:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028cc:	c1 ea 0c             	shr    $0xc,%edx
f01028cf:	39 d1                	cmp    %edx,%ecx
f01028d1:	77 5e                	ja     f0102931 <mem_init+0x148b>
f01028d3:	eb 40                	jmp    f0102915 <mem_init+0x146f>
f01028d5:	8d b3 00 00 00 ef    	lea    -0x11000000(%ebx),%esi
f01028db:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028e0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028e5:	77 20                	ja     f0102907 <mem_init+0x1461>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028e7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028eb:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f01028f2:	f0 
f01028f3:	c7 44 24 04 b7 00 00 	movl   $0xb7,0x4(%esp)
f01028fa:	00 
f01028fb:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102902:	e8 39 d7 ff ff       	call   f0100040 <_panic>
f0102907:	8d 94 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010290e:	c1 ea 0c             	shr    $0xc,%edx
f0102911:	39 d1                	cmp    %edx,%ecx
f0102913:	77 26                	ja     f010293b <mem_init+0x1495>
		panic("pa2page called with invalid pa");
f0102915:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f010291c:	f0 
f010291d:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102924:	00 
f0102925:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f010292c:	e8 0f d7 ff ff       	call   f0100040 <_panic>
f0102931:	be 00 00 00 ef       	mov    $0xef000000,%esi
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f0102936:	bb 00 00 00 00       	mov    $0x0,%ebx
	{

		page_insert(kern_pgdir, pa2page(PADDR(pages)+i),(void*) (UPAGES+i), PTE_U);
f010293b:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102942:	00 
f0102943:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102947:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010294a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010294e:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102953:	89 04 24             	mov    %eax,(%esp)
f0102956:	e8 8a ea ff ff       	call   f01013e5 <page_insert>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f010295b:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102961:	89 da                	mov    %ebx,%edx
f0102963:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0102969:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102970:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102975:	39 c3                	cmp    %eax,%ebx
f0102977:	0f 82 58 ff ff ff    	jb     f01028d5 <mem_init+0x142f>
f010297d:	e9 29 0b 00 00       	jmp    f01034ab <mem_init+0x2005>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102982:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102987:	c1 e8 0c             	shr    $0xc,%eax
f010298a:	39 05 88 3e 22 f0    	cmp    %eax,0xf0223e88
f0102990:	0f 87 b9 0b 00 00    	ja     f010354f <mem_init+0x20a9>
f0102996:	eb 44                	jmp    f01029dc <mem_init+0x1536>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f0102998:	8d 8a 00 00 c0 ee    	lea    -0x11400000(%edx),%ecx
f010299e:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01029a3:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01029a8:	77 20                	ja     f01029ca <mem_init+0x1524>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01029aa:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01029ae:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f01029b5:	f0 
f01029b6:	c7 44 24 04 c7 00 00 	movl   $0xc7,0x4(%esp)
f01029bd:	00 
f01029be:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01029c5:	e8 76 d6 ff ff       	call   f0100040 <_panic>
f01029ca:	8d 84 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01029d1:	c1 e8 0c             	shr    $0xc,%eax
f01029d4:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01029da:	72 1c                	jb     f01029f8 <mem_init+0x1552>
		panic("pa2page called with invalid pa");
f01029dc:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f01029e3:	f0 
f01029e4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01029eb:	00 
f01029ec:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01029f3:	e8 48 d6 ff ff       	call   f0100040 <_panic>
f01029f8:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01029ff:	00 
f0102a00:	89 4c 24 08          	mov    %ecx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a04:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0102a0a:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a0d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a11:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102a16:	89 04 24             	mov    %eax,(%esp)
f0102a19:	e8 c7 e9 ff ff       	call   f01013e5 <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0102a1e:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102a24:	89 da                	mov    %ebx,%edx
f0102a26:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f0102a2c:	0f 85 66 ff ff ff    	jne    f0102998 <mem_init+0x14f2>
f0102a32:	e9 89 0a 00 00       	jmp    f01034c0 <mem_init+0x201a>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102a37:	b8 00 60 11 00       	mov    $0x116000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102a3c:	c1 e8 0c             	shr    $0xc,%eax
f0102a3f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0102a45:	0f 82 c2 0a 00 00    	jb     f010350d <mem_init+0x2067>
f0102a4b:	eb 36                	jmp    f0102a83 <mem_init+0x15dd>
f0102a4d:	8d 14 33             	lea    (%ebx,%esi,1),%edx
f0102a50:	89 f0                	mov    %esi,%eax
f0102a52:	c1 e8 0c             	shr    $0xc,%eax
f0102a55:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0102a5b:	72 42                	jb     f0102a9f <mem_init+0x15f9>
f0102a5d:	eb 24                	jmp    f0102a83 <mem_init+0x15dd>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a5f:	c7 44 24 0c 00 60 11 	movl   $0xf0116000,0xc(%esp)
f0102a66:	f0 
f0102a67:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0102a6e:	f0 
f0102a6f:	c7 44 24 04 d9 00 00 	movl   $0xd9,0x4(%esp)
f0102a76:	00 
f0102a77:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102a7e:	e8 bd d5 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102a83:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0102a8a:	f0 
f0102a8b:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a92:	00 
f0102a93:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0102a9a:	e8 a1 d5 ff ff       	call   f0100040 <_panic>
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
f0102a9f:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102aa6:	00 
f0102aa7:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102aab:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0102ab1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102ab4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102ab8:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102abd:	89 04 24             	mov    %eax,(%esp)
f0102ac0:	e8 20 e9 ff ff       	call   f01013e5 <page_insert>
f0102ac5:	81 c6 00 10 00 00    	add    $0x1000,%esi
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f0102acb:	39 fe                	cmp    %edi,%esi
f0102acd:	0f 85 7a ff ff ff    	jne    f0102a4d <mem_init+0x15a7>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102ad3:	b8 00 00 00 00       	mov    $0x0,%eax
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f0102ad8:	bb 00 00 00 00       	mov    $0x0,%ebx
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
    {
    	if(i<npages*PGSIZE)
f0102add:	8b 15 88 3e 22 f0    	mov    0xf0223e88,%edx
f0102ae3:	89 d1                	mov    %edx,%ecx
f0102ae5:	c1 e1 0c             	shl    $0xc,%ecx
f0102ae8:	39 c1                	cmp    %eax,%ecx
f0102aea:	0f 86 88 00 00 00    	jbe    f0102b78 <mem_init+0x16d2>
    	{
    		page_insert(kern_pgdir,pa2page(i),(void*)(KERNBASE+i),PTE_W);
f0102af0:	8d 88 00 00 00 f0    	lea    -0x10000000(%eax),%ecx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102af6:	c1 e8 0c             	shr    $0xc,%eax
f0102af9:	89 c6                	mov    %eax,%esi
f0102afb:	39 c2                	cmp    %eax,%edx
f0102afd:	77 1c                	ja     f0102b1b <mem_init+0x1675>
		panic("pa2page called with invalid pa");
f0102aff:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0102b06:	f0 
f0102b07:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b0e:	00 
f0102b0f:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0102b16:	e8 25 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b1b:	8d 3c c5 00 00 00 00 	lea    0x0(,%eax,8),%edi
f0102b22:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102b29:	00 
f0102b2a:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0102b2e:	89 f8                	mov    %edi,%eax
f0102b30:	03 05 90 3e 22 f0    	add    0xf0223e90,%eax
f0102b36:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102b3a:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102b3f:	89 04 24             	mov    %eax,(%esp)
f0102b42:	e8 9e e8 ff ff       	call   f01013e5 <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b47:	3b 35 88 3e 22 f0    	cmp    0xf0223e88,%esi
f0102b4d:	72 1c                	jb     f0102b6b <mem_init+0x16c5>
		panic("pa2page called with invalid pa");
f0102b4f:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0102b56:	f0 
f0102b57:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b5e:	00 
f0102b5f:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0102b66:	e8 d5 d4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b6b:	03 3d 90 3e 22 f0    	add    0xf0223e90,%edi
    		pa2page(i)->pp_ref--;
f0102b71:	66 83 6f 04 01       	subw   $0x1,0x4(%edi)
f0102b76:	eb 76                	jmp    f0102bee <mem_init+0x1748>
    	}
    	else
    	{
    		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
f0102b78:	2d 00 00 00 10       	sub    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b7d:	85 d2                	test   %edx,%edx
f0102b7f:	75 1c                	jne    f0102b9d <mem_init+0x16f7>
		panic("pa2page called with invalid pa");
f0102b81:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0102b88:	f0 
f0102b89:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b90:	00 
f0102b91:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0102b98:	e8 a3 d4 ff ff       	call   f0100040 <_panic>
f0102b9d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102ba4:	00 
f0102ba5:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102ba9:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0102bae:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102bb2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102bb7:	89 04 24             	mov    %eax,(%esp)
f0102bba:	e8 26 e8 ff ff       	call   f01013e5 <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102bbf:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f0102bc6:	75 1c                	jne    f0102be4 <mem_init+0x173e>
		panic("pa2page called with invalid pa");
f0102bc8:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0102bcf:	f0 
f0102bd0:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102bd7:	00 
f0102bd8:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0102bdf:	e8 5c d4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102be4:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
    		pa2page(0)->pp_ref--;
f0102be9:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102bee:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102bf4:	89 d8                	mov    %ebx,%eax
f0102bf6:	81 fb 00 00 00 10    	cmp    $0x10000000,%ebx
f0102bfc:	0f 85 db fe ff ff    	jne    f0102add <mem_init+0x1637>
    	{
    		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
    		pa2page(0)->pp_ref--;
    	}
    }
    cprintf("%d\r\n",page_free_list->pp_ref);
f0102c02:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0102c07:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f0102c0b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102c0f:	c7 04 24 35 77 10 f0 	movl   $0xf0107735,(%esp)
f0102c16:	e8 16 15 00 00       	call   f0104131 <cprintf>
    cprintf("3\r\n");
f0102c1b:	c7 04 24 8d 6f 10 f0 	movl   $0xf0106f8d,(%esp)
f0102c22:	e8 0a 15 00 00       	call   f0104131 <cprintf>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f0102c27:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102c2e:	00 
f0102c2f:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f0102c36:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f0102c3b:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f0102c40:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102c45:	e8 14 e6 ff ff       	call   f010125e <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c4a:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
f0102c4f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102c54:	0f 87 7c 08 00 00    	ja     f01034d6 <mem_init+0x2030>
f0102c5a:	eb 0c                	jmp    f0102c68 <mem_init+0x17c2>
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
f0102c5c:	89 d8                	mov    %ebx,%eax
f0102c5e:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102c64:	77 27                	ja     f0102c8d <mem_init+0x17e7>
f0102c66:	eb 05                	jmp    f0102c6d <mem_init+0x17c7>
f0102c68:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c6d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102c71:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0102c78:	f0 
f0102c79:	c7 44 24 04 3a 01 00 	movl   $0x13a,0x4(%esp)
f0102c80:	00 
f0102c81:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102c88:	e8 b3 d3 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f0102c8d:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102c94:	00 
f0102c95:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102c9b:	89 04 24             	mov    %eax,(%esp)
f0102c9e:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102ca3:	89 f2                	mov    %esi,%edx
f0102ca5:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102caa:	e8 af e5 ff ff       	call   f010125e <boot_map_region>
f0102caf:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102cb5:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	//
	// LAB 4: Your code here:
	   	int cpu_i;
	uintptr_t stk_i;
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
f0102cbb:	39 fb                	cmp    %edi,%ebx
f0102cbd:	75 9d                	jne    f0102c5c <mem_init+0x17b6>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102cbf:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102cc5:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0102cca:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102ccd:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102cd4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102cd9:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102cdc:	75 30                	jne    f0102d0e <mem_init+0x1868>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102cde:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102ce4:	89 de                	mov    %ebx,%esi
f0102ce6:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102ceb:	89 f8                	mov    %edi,%eax
f0102ced:	e8 5a de ff ff       	call   f0100b4c <check_va2pa>
f0102cf2:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102cf8:	0f 86 94 00 00 00    	jbe    f0102d92 <mem_init+0x18ec>
f0102cfe:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102d03:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102d09:	e9 a4 00 00 00       	jmp    f0102db2 <mem_init+0x190c>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102d0e:	8b 1d 90 3e 22 f0    	mov    0xf0223e90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102d14:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102d1a:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102d1f:	89 f8                	mov    %edi,%eax
f0102d21:	e8 26 de ff ff       	call   f0100b4c <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102d26:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102d2c:	77 20                	ja     f0102d4e <mem_init+0x18a8>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102d2e:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102d32:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0102d39:	f0 
f0102d3a:	c7 44 24 04 7b 03 00 	movl   $0x37b,0x4(%esp)
f0102d41:	00 
f0102d42:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102d49:	e8 f2 d2 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102d4e:	ba 00 00 00 00       	mov    $0x0,%edx
f0102d53:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102d56:	39 c8                	cmp    %ecx,%eax
f0102d58:	74 24                	je     f0102d7e <mem_init+0x18d8>
f0102d5a:	c7 44 24 0c 34 75 10 	movl   $0xf0107534,0xc(%esp)
f0102d61:	f0 
f0102d62:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102d69:	f0 
f0102d6a:	c7 44 24 04 7b 03 00 	movl   $0x37b,0x4(%esp)
f0102d71:	00 
f0102d72:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102d79:	e8 c2 d2 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102d7e:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102d84:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102d87:	0f 87 18 08 00 00    	ja     f01035a5 <mem_init+0x20ff>
f0102d8d:	e9 4c ff ff ff       	jmp    f0102cde <mem_init+0x1838>
f0102d92:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102d96:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0102d9d:	f0 
f0102d9e:	c7 44 24 04 80 03 00 	movl   $0x380,0x4(%esp)
f0102da5:	00 
f0102da6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102dad:	e8 8e d2 ff ff       	call   f0100040 <_panic>
f0102db2:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102db5:	39 c2                	cmp    %eax,%edx
f0102db7:	74 24                	je     f0102ddd <mem_init+0x1937>
f0102db9:	c7 44 24 0c 68 75 10 	movl   $0xf0107568,0xc(%esp)
f0102dc0:	f0 
f0102dc1:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102dc8:	f0 
f0102dc9:	c7 44 24 04 80 03 00 	movl   $0x380,0x4(%esp)
f0102dd0:	00 
f0102dd1:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102dd8:	e8 63 d2 ff ff       	call   f0100040 <_panic>
f0102ddd:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102de3:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102de9:	0f 85 a7 07 00 00    	jne    f0103596 <mem_init+0x20f0>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102def:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102df2:	c1 e6 0c             	shl    $0xc,%esi
f0102df5:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102dfa:	85 f6                	test   %esi,%esi
f0102dfc:	75 07                	jne    f0102e05 <mem_init+0x195f>
f0102dfe:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102e03:	eb 41                	jmp    f0102e46 <mem_init+0x19a0>
f0102e05:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
	{

		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102e0b:	89 f8                	mov    %edi,%eax
f0102e0d:	e8 3a dd ff ff       	call   f0100b4c <check_va2pa>
f0102e12:	39 c3                	cmp    %eax,%ebx
f0102e14:	74 24                	je     f0102e3a <mem_init+0x1994>
f0102e16:	c7 44 24 0c 9c 75 10 	movl   $0xf010759c,0xc(%esp)
f0102e1d:	f0 
f0102e1e:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102e25:	f0 
f0102e26:	c7 44 24 04 86 03 00 	movl   $0x386,0x4(%esp)
f0102e2d:	00 
f0102e2e:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102e35:	e8 06 d2 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102e3a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102e40:	39 de                	cmp    %ebx,%esi
f0102e42:	77 c1                	ja     f0102e05 <mem_init+0x195f>
f0102e44:	eb b8                	jmp    f0102dfe <mem_init+0x1958>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
	}

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102e46:	89 da                	mov    %ebx,%edx
f0102e48:	89 f8                	mov    %edi,%eax
f0102e4a:	e8 fd dc ff ff       	call   f0100b4c <check_va2pa>
f0102e4f:	39 c3                	cmp    %eax,%ebx
f0102e51:	74 24                	je     f0102e77 <mem_init+0x19d1>
f0102e53:	c7 44 24 0c 91 6f 10 	movl   $0xf0106f91,0xc(%esp)
f0102e5a:	f0 
f0102e5b:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102e62:	f0 
f0102e63:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f0102e6a:	00 
f0102e6b:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102e72:	e8 c9 d1 ff ff       	call   f0100040 <_panic>

		assert(check_va2pa(pgdir, KERNBASE + i) == i);
	}

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102e77:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102e7d:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102e83:	75 c1                	jne    f0102e46 <mem_init+0x19a0>
f0102e85:	c7 45 d0 00 50 22 f0 	movl   $0xf0225000,-0x30(%ebp)
f0102e8c:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102e93:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102e98:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
f0102e9d:	05 00 80 40 20       	add    $0x20408000,%eax
f0102ea2:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102ea5:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102eab:	89 45 d4             	mov    %eax,-0x2c(%ebp)
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102eae:	89 f2                	mov    %esi,%edx
f0102eb0:	89 f8                	mov    %edi,%eax
f0102eb2:	e8 95 dc ff ff       	call   f0100b4c <check_va2pa>
f0102eb7:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102eba:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102ec0:	77 20                	ja     f0102ee2 <mem_init+0x1a3c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102ec2:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102ec6:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0102ecd:	f0 
f0102ece:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
f0102ed5:	00 
f0102ed6:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102edd:	e8 5e d1 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102ee2:	89 f3                	mov    %esi,%ebx
f0102ee4:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f0102ee7:	03 4d cc             	add    -0x34(%ebp),%ecx
f0102eea:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102eed:	89 ce                	mov    %ecx,%esi
f0102eef:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102ef2:	39 d0                	cmp    %edx,%eax
f0102ef4:	74 24                	je     f0102f1a <mem_init+0x1a74>
f0102ef6:	c7 44 24 0c c4 75 10 	movl   $0xf01075c4,0xc(%esp)
f0102efd:	f0 
f0102efe:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102f05:	f0 
f0102f06:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
f0102f0d:	00 
f0102f0e:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102f15:	e8 26 d1 ff ff       	call   f0100040 <_panic>
f0102f1a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
//			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102f20:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102f23:	0f 85 5f 06 00 00    	jne    f0103588 <mem_init+0x20e2>
f0102f29:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102f2c:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102f32:	89 da                	mov    %ebx,%edx
f0102f34:	89 f8                	mov    %edi,%eax
f0102f36:	e8 11 dc ff ff       	call   f0100b4c <check_va2pa>
f0102f3b:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102f3e:	74 24                	je     f0102f64 <mem_init+0x1abe>
f0102f40:	c7 44 24 0c 0c 76 10 	movl   $0xf010760c,0xc(%esp)
f0102f47:	f0 
f0102f48:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102f4f:	f0 
f0102f50:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f0102f57:	00 
f0102f58:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102f5f:	e8 dc d0 ff ff       	call   f0100040 <_panic>
f0102f64:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102f6a:	39 f3                	cmp    %esi,%ebx
f0102f6c:	75 c4                	jne    f0102f32 <mem_init+0x1a8c>
f0102f6e:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102f74:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102f7b:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
//
//	}
//			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102f82:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102f88:	0f 85 17 ff ff ff    	jne    f0102ea5 <mem_init+0x19ff>
f0102f8e:	b8 00 00 00 00       	mov    $0x0,%eax
	}
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102f93:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102f99:	83 fa 03             	cmp    $0x3,%edx
f0102f9c:	77 2e                	ja     f0102fcc <mem_init+0x1b26>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102f9e:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102fa2:	0f 85 aa 00 00 00    	jne    f0103052 <mem_init+0x1bac>
f0102fa8:	c7 44 24 0c ac 6f 10 	movl   $0xf0106fac,0xc(%esp)
f0102faf:	f0 
f0102fb0:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102fb7:	f0 
f0102fb8:	c7 44 24 04 a9 03 00 	movl   $0x3a9,0x4(%esp)
f0102fbf:	00 
f0102fc0:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102fc7:	e8 74 d0 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102fcc:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102fd1:	76 55                	jbe    f0103028 <mem_init+0x1b82>
				assert(pgdir[i] & PTE_P);
f0102fd3:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102fd6:	f6 c2 01             	test   $0x1,%dl
f0102fd9:	75 24                	jne    f0102fff <mem_init+0x1b59>
f0102fdb:	c7 44 24 0c ac 6f 10 	movl   $0xf0106fac,0xc(%esp)
f0102fe2:	f0 
f0102fe3:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0102fea:	f0 
f0102feb:	c7 44 24 04 ad 03 00 	movl   $0x3ad,0x4(%esp)
f0102ff2:	00 
f0102ff3:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0102ffa:	e8 41 d0 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102fff:	f6 c2 02             	test   $0x2,%dl
f0103002:	75 4e                	jne    f0103052 <mem_init+0x1bac>
f0103004:	c7 44 24 0c bd 6f 10 	movl   $0xf0106fbd,0xc(%esp)
f010300b:	f0 
f010300c:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103013:	f0 
f0103014:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f010301b:	00 
f010301c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103023:	e8 18 d0 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0103028:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f010302c:	74 24                	je     f0103052 <mem_init+0x1bac>
f010302e:	c7 44 24 0c ce 6f 10 	movl   $0xf0106fce,0xc(%esp)
f0103035:	f0 
f0103036:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010303d:	f0 
f010303e:	c7 44 24 04 b0 03 00 	movl   $0x3b0,0x4(%esp)
f0103045:	00 
f0103046:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010304d:	e8 ee cf ff ff       	call   f0100040 <_panic>
			assert(check_va2pa(pgdir, base + i) == ~0);
	}
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0103052:	83 c0 01             	add    $0x1,%eax
f0103055:	3d 00 04 00 00       	cmp    $0x400,%eax
f010305a:	0f 85 33 ff ff ff    	jne    f0102f93 <mem_init+0x1aed>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0103060:	c7 04 24 30 76 10 f0 	movl   $0xf0107630,(%esp)
f0103067:	e8 c5 10 00 00       	call   f0104131 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f010306c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0103071:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103076:	77 20                	ja     f0103098 <mem_init+0x1bf2>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103078:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010307c:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103083:	f0 
f0103084:	c7 44 24 04 07 01 00 	movl   $0x107,0x4(%esp)
f010308b:	00 
f010308c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103093:	e8 a8 cf ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103098:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010309d:	0f 22 d8             	mov    %eax,%cr3
	cprintf("env_id:%d\r\n",(((struct Env*)UENVS)[0]).env_id);
f01030a0:	a1 48 00 c0 ee       	mov    0xeec00048,%eax
f01030a5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01030a9:	c7 04 24 dc 6f 10 f0 	movl   $0xf0106fdc,(%esp)
f01030b0:	e8 7c 10 00 00       	call   f0104131 <cprintf>
	cprintf("%d\r\n",page_free_list->pp_ref);
f01030b5:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f01030ba:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f01030be:	89 44 24 04          	mov    %eax,0x4(%esp)
f01030c2:	c7 04 24 35 77 10 f0 	movl   $0xf0107735,(%esp)
f01030c9:	e8 63 10 00 00       	call   f0104131 <cprintf>
	check_page_free_list(0);
f01030ce:	b8 00 00 00 00       	mov    $0x0,%eax
f01030d3:	e8 e3 da ff ff       	call   f0100bbb <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f01030d8:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f01030db:	83 e0 f3             	and    $0xfffffff3,%eax
f01030de:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f01030e3:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01030e6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01030ed:	e8 9f df ff ff       	call   f0101091 <page_alloc>
f01030f2:	89 c3                	mov    %eax,%ebx
f01030f4:	85 c0                	test   %eax,%eax
f01030f6:	75 24                	jne    f010311c <mem_init+0x1c76>
f01030f8:	c7 44 24 0c b5 6d 10 	movl   $0xf0106db5,0xc(%esp)
f01030ff:	f0 
f0103100:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103107:	f0 
f0103108:	c7 44 24 04 67 04 00 	movl   $0x467,0x4(%esp)
f010310f:	00 
f0103110:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103117:	e8 24 cf ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010311c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103123:	e8 69 df ff ff       	call   f0101091 <page_alloc>
f0103128:	89 c7                	mov    %eax,%edi
f010312a:	85 c0                	test   %eax,%eax
f010312c:	75 24                	jne    f0103152 <mem_init+0x1cac>
f010312e:	c7 44 24 0c cb 6d 10 	movl   $0xf0106dcb,0xc(%esp)
f0103135:	f0 
f0103136:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010313d:	f0 
f010313e:	c7 44 24 04 68 04 00 	movl   $0x468,0x4(%esp)
f0103145:	00 
f0103146:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010314d:	e8 ee ce ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0103152:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103159:	e8 33 df ff ff       	call   f0101091 <page_alloc>
f010315e:	89 c6                	mov    %eax,%esi
f0103160:	85 c0                	test   %eax,%eax
f0103162:	75 24                	jne    f0103188 <mem_init+0x1ce2>
f0103164:	c7 44 24 0c e1 6d 10 	movl   $0xf0106de1,0xc(%esp)
f010316b:	f0 
f010316c:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103173:	f0 
f0103174:	c7 44 24 04 69 04 00 	movl   $0x469,0x4(%esp)
f010317b:	00 
f010317c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103183:	e8 b8 ce ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0103188:	89 1c 24             	mov    %ebx,(%esp)
f010318b:	e8 86 df ff ff       	call   f0101116 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103190:	89 f8                	mov    %edi,%eax
f0103192:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0103198:	c1 f8 03             	sar    $0x3,%eax
f010319b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010319e:	89 c2                	mov    %eax,%edx
f01031a0:	c1 ea 0c             	shr    $0xc,%edx
f01031a3:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01031a9:	72 20                	jb     f01031cb <mem_init+0x1d25>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01031ab:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01031af:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f01031b6:	f0 
f01031b7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01031be:	00 
f01031bf:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01031c6:	e8 75 ce ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f01031cb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01031d2:	00 
f01031d3:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01031da:	00 
	return (void *)(pa + KERNBASE);
f01031db:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01031e0:	89 04 24             	mov    %eax,(%esp)
f01031e3:	e8 31 27 00 00       	call   f0105919 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01031e8:	89 f0                	mov    %esi,%eax
f01031ea:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01031f0:	c1 f8 03             	sar    $0x3,%eax
f01031f3:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01031f6:	89 c2                	mov    %eax,%edx
f01031f8:	c1 ea 0c             	shr    $0xc,%edx
f01031fb:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0103201:	72 20                	jb     f0103223 <mem_init+0x1d7d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103203:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103207:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f010320e:	f0 
f010320f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103216:	00 
f0103217:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f010321e:	e8 1d ce ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0103223:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010322a:	00 
f010322b:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0103232:	00 
	return (void *)(pa + KERNBASE);
f0103233:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103238:	89 04 24             	mov    %eax,(%esp)
f010323b:	e8 d9 26 00 00       	call   f0105919 <memset>

	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0103240:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103247:	00 
f0103248:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010324f:	00 
f0103250:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103254:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0103259:	89 04 24             	mov    %eax,(%esp)
f010325c:	e8 84 e1 ff ff       	call   f01013e5 <page_insert>

	assert(pp1->pp_ref == 1);
f0103261:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0103266:	74 24                	je     f010328c <mem_init+0x1de6>
f0103268:	c7 44 24 0c bf 6e 10 	movl   $0xf0106ebf,0xc(%esp)
f010326f:	f0 
f0103270:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103277:	f0 
f0103278:	c7 44 24 04 70 04 00 	movl   $0x470,0x4(%esp)
f010327f:	00 
f0103280:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103287:	e8 b4 cd ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f010328c:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0103293:	01 01 01 
f0103296:	74 24                	je     f01032bc <mem_init+0x1e16>
f0103298:	c7 44 24 0c 50 76 10 	movl   $0xf0107650,0xc(%esp)
f010329f:	f0 
f01032a0:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01032a7:	f0 
f01032a8:	c7 44 24 04 71 04 00 	movl   $0x471,0x4(%esp)
f01032af:	00 
f01032b0:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01032b7:	e8 84 cd ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f01032bc:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01032c3:	00 
f01032c4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01032cb:	00 
f01032cc:	89 74 24 04          	mov    %esi,0x4(%esp)
f01032d0:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01032d5:	89 04 24             	mov    %eax,(%esp)
f01032d8:	e8 08 e1 ff ff       	call   f01013e5 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f01032dd:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f01032e4:	02 02 02 
f01032e7:	74 24                	je     f010330d <mem_init+0x1e67>
f01032e9:	c7 44 24 0c 74 76 10 	movl   $0xf0107674,0xc(%esp)
f01032f0:	f0 
f01032f1:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01032f8:	f0 
f01032f9:	c7 44 24 04 73 04 00 	movl   $0x473,0x4(%esp)
f0103300:	00 
f0103301:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103308:	e8 33 cd ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010330d:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0103312:	74 24                	je     f0103338 <mem_init+0x1e92>
f0103314:	c7 44 24 0c e1 6e 10 	movl   $0xf0106ee1,0xc(%esp)
f010331b:	f0 
f010331c:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103323:	f0 
f0103324:	c7 44 24 04 74 04 00 	movl   $0x474,0x4(%esp)
f010332b:	00 
f010332c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103333:	e8 08 cd ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103338:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f010333d:	74 24                	je     f0103363 <mem_init+0x1ebd>
f010333f:	c7 44 24 0c 30 6f 10 	movl   $0xf0106f30,0xc(%esp)
f0103346:	f0 
f0103347:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f010334e:	f0 
f010334f:	c7 44 24 04 75 04 00 	movl   $0x475,0x4(%esp)
f0103356:	00 
f0103357:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f010335e:	e8 dd cc ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0103363:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f010336a:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010336d:	89 f0                	mov    %esi,%eax
f010336f:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0103375:	c1 f8 03             	sar    $0x3,%eax
f0103378:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010337b:	89 c2                	mov    %eax,%edx
f010337d:	c1 ea 0c             	shr    $0xc,%edx
f0103380:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0103386:	72 20                	jb     f01033a8 <mem_init+0x1f02>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103388:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010338c:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0103393:	f0 
f0103394:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010339b:	00 
f010339c:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f01033a3:	e8 98 cc ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f01033a8:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f01033af:	03 03 03 
f01033b2:	74 24                	je     f01033d8 <mem_init+0x1f32>
f01033b4:	c7 44 24 0c 98 76 10 	movl   $0xf0107698,0xc(%esp)
f01033bb:	f0 
f01033bc:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01033c3:	f0 
f01033c4:	c7 44 24 04 77 04 00 	movl   $0x477,0x4(%esp)
f01033cb:	00 
f01033cc:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f01033d3:	e8 68 cc ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01033d8:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01033df:	00 
f01033e0:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01033e5:	89 04 24             	mov    %eax,(%esp)
f01033e8:	e8 a8 df ff ff       	call   f0101395 <page_remove>
	assert(pp2->pp_ref == 0);
f01033ed:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01033f2:	74 24                	je     f0103418 <mem_init+0x1f72>
f01033f4:	c7 44 24 0c 1d 6f 10 	movl   $0xf0106f1d,0xc(%esp)
f01033fb:	f0 
f01033fc:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103403:	f0 
f0103404:	c7 44 24 04 79 04 00 	movl   $0x479,0x4(%esp)
f010340b:	00 
f010340c:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103413:	e8 28 cc ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0103418:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010341d:	8b 08                	mov    (%eax),%ecx
f010341f:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103425:	89 da                	mov    %ebx,%edx
f0103427:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f010342d:	c1 fa 03             	sar    $0x3,%edx
f0103430:	c1 e2 0c             	shl    $0xc,%edx
f0103433:	39 d1                	cmp    %edx,%ecx
f0103435:	74 24                	je     f010345b <mem_init+0x1fb5>
f0103437:	c7 44 24 0c 20 72 10 	movl   $0xf0107220,0xc(%esp)
f010343e:	f0 
f010343f:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103446:	f0 
f0103447:	c7 44 24 04 7c 04 00 	movl   $0x47c,0x4(%esp)
f010344e:	00 
f010344f:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103456:	e8 e5 cb ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f010345b:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103461:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0103466:	74 24                	je     f010348c <mem_init+0x1fe6>
f0103468:	c7 44 24 0c d0 6e 10 	movl   $0xf0106ed0,0xc(%esp)
f010346f:	f0 
f0103470:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0103477:	f0 
f0103478:	c7 44 24 04 7e 04 00 	movl   $0x47e,0x4(%esp)
f010347f:	00 
f0103480:	c7 04 24 71 6c 10 f0 	movl   $0xf0106c71,(%esp)
f0103487:	e8 b4 cb ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f010348c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0103492:	89 1c 24             	mov    %ebx,(%esp)
f0103495:	e8 7c dc ff ff       	call   f0101116 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f010349a:	c7 04 24 c4 76 10 f0 	movl   $0xf01076c4,(%esp)
f01034a1:	e8 8b 0c 00 00       	call   f0104131 <cprintf>
f01034a6:	e9 0e 01 00 00       	jmp    f01035b9 <mem_init+0x2113>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f01034ab:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01034b0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01034b5:	0f 87 c7 f4 ff ff    	ja     f0102982 <mem_init+0x14dc>
f01034bb:	e9 ea f4 ff ff       	jmp    f01029aa <mem_init+0x1504>
f01034c0:	bb 00 60 11 f0       	mov    $0xf0116000,%ebx
f01034c5:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01034cb:	0f 86 8e f5 ff ff    	jbe    f0102a5f <mem_init+0x15b9>
f01034d1:	e9 61 f5 ff ff       	jmp    f0102a37 <mem_init+0x1591>
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f01034d6:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01034dd:	00 
f01034de:	c7 04 24 00 50 22 00 	movl   $0x225000,(%esp)
f01034e5:	b9 00 80 00 00       	mov    $0x8000,%ecx
f01034ea:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f01034ef:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01034f4:	e8 65 dd ff ff       	call   f010125e <boot_map_region>
f01034f9:	bb 00 d0 22 f0       	mov    $0xf022d000,%ebx
f01034fe:	bf 00 50 26 f0       	mov    $0xf0265000,%edi
f0103503:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f0103508:	e9 4f f7 ff ff       	jmp    f0102c5c <mem_init+0x17b6>
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
f010350d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103514:	00 
f0103515:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f010351c:	ef 
static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f010351d:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103523:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103526:	89 44 24 04          	mov    %eax,0x4(%esp)
f010352a:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010352f:	89 04 24             	mov    %eax,(%esp)
f0103532:	e8 ae de ff ff       	call   f01013e5 <page_insert>
f0103537:	be 00 70 11 00       	mov    $0x117000,%esi
f010353c:	bf 00 e0 11 00       	mov    $0x11e000,%edi
f0103541:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0103546:	29 d8                	sub    %ebx,%eax
f0103548:	89 c3                	mov    %eax,%ebx
f010354a:	e9 fe f4 ff ff       	jmp    f0102a4d <mem_init+0x15a7>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f010354f:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0103556:	00 
f0103557:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f010355e:	ee 
f010355f:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103565:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103568:	89 44 24 04          	mov    %eax,0x4(%esp)
f010356c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0103571:	89 04 24             	mov    %eax,(%esp)
f0103574:	e8 6c de ff ff       	call   f01013e5 <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0103579:	bb 00 10 00 00       	mov    $0x1000,%ebx
f010357e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103583:	e9 10 f4 ff ff       	jmp    f0102998 <mem_init+0x14f2>
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0103588:	89 da                	mov    %ebx,%edx
f010358a:	89 f8                	mov    %edi,%eax
f010358c:	e8 bb d5 ff ff       	call   f0100b4c <check_va2pa>
f0103591:	e9 59 f9 ff ff       	jmp    f0102eef <mem_init+0x1a49>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103596:	89 da                	mov    %ebx,%edx
f0103598:	89 f8                	mov    %edi,%eax
f010359a:	e8 ad d5 ff ff       	call   f0100b4c <check_va2pa>
f010359f:	90                   	nop
f01035a0:	e9 0d f8 ff ff       	jmp    f0102db2 <mem_init+0x190c>
f01035a5:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01035ab:	89 f8                	mov    %edi,%eax
f01035ad:	e8 9a d5 ff ff       	call   f0100b4c <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01035b2:	89 da                	mov    %ebx,%edx
f01035b4:	e9 9a f7 ff ff       	jmp    f0102d53 <mem_init+0x18ad>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f01035b9:	83 c4 4c             	add    $0x4c,%esp
f01035bc:	5b                   	pop    %ebx
f01035bd:	5e                   	pop    %esi
f01035be:	5f                   	pop    %edi
f01035bf:	5d                   	pop    %ebp
f01035c0:	c3                   	ret    

f01035c1 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01035c1:	55                   	push   %ebp
f01035c2:	89 e5                	mov    %esp,%ebp
f01035c4:	57                   	push   %edi
f01035c5:	56                   	push   %esi
f01035c6:	53                   	push   %ebx
f01035c7:	83 ec 3c             	sub    $0x3c,%esp
f01035ca:	8b 7d 08             	mov    0x8(%ebp),%edi
f01035cd:	8b 45 0c             	mov    0xc(%ebp),%eax
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
f01035d0:	89 c2                	mov    %eax,%edx
f01035d2:	03 55 10             	add    0x10(%ebp),%edx
f01035d5:	89 55 d0             	mov    %edx,-0x30(%ebp)
f01035d8:	39 d0                	cmp    %edx,%eax
f01035da:	0f 83 88 00 00 00    	jae    f0103668 <user_mem_check+0xa7>
f01035e0:	89 c3                	mov    %eax,%ebx
f01035e2:	89 c6                	mov    %eax,%esi
			pte_t* store=0;
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
			if(store!=NULL)
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f01035e4:	8b 45 14             	mov    0x14(%ebp),%eax
f01035e7:	83 c8 01             	or     $0x1,%eax
f01035ea:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
		{
			pte_t* store=0;
f01035ed:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f01035f4:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01035f7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01035fb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01035ff:	8b 47 60             	mov    0x60(%edi),%eax
f0103602:	89 04 24             	mov    %eax,(%esp)
f0103605:	e8 de dc ff ff       	call   f01012e8 <page_lookup>
			if(store!=NULL)
f010360a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010360d:	85 c0                	test   %eax,%eax
f010360f:	74 27                	je     f0103638 <user_mem_check+0x77>
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103611:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103614:	89 ca                	mov    %ecx,%edx
f0103616:	23 10                	and    (%eax),%edx
f0103618:	39 d1                	cmp    %edx,%ecx
f010361a:	75 08                	jne    f0103624 <user_mem_check+0x63>
f010361c:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f0103622:	76 28                	jbe    f010364c <user_mem_check+0x8b>
			   {
				cprintf("pte protect!\r\n");
f0103624:	c7 04 24 e8 6f 10 f0 	movl   $0xf0106fe8,(%esp)
f010362b:	e8 01 0b 00 00       	call   f0104131 <cprintf>
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0103630:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f0103636:	eb 29                	jmp    f0103661 <user_mem_check+0xa0>
			   }
			}
			else
			{
				cprintf("no pte!\r\n");
f0103638:	c7 04 24 f7 6f 10 f0 	movl   $0xf0106ff7,(%esp)
f010363f:	e8 ed 0a 00 00       	call   f0104131 <cprintf>
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0103644:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f010364a:	eb 15                	jmp    f0103661 <user_mem_check+0xa0>
			}
		      i=ROUNDDOWN(i,PGSIZE);
f010364c:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
f0103652:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103658:	89 de                	mov    %ebx,%esi
f010365a:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f010365d:	72 8e                	jb     f01035ed <user_mem_check+0x2c>
f010365f:	eb 0e                	jmp    f010366f <user_mem_check+0xae>
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f0103661:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103666:	eb 0c                	jmp    f0103674 <user_mem_check+0xb3>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
f0103668:	b8 00 00 00 00       	mov    $0x0,%eax
f010366d:	eb 05                	jmp    f0103674 <user_mem_check+0xb3>
f010366f:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		      i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f0103674:	83 c4 3c             	add    $0x3c,%esp
f0103677:	5b                   	pop    %ebx
f0103678:	5e                   	pop    %esi
f0103679:	5f                   	pop    %edi
f010367a:	5d                   	pop    %ebp
f010367b:	c3                   	ret    

f010367c <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f010367c:	55                   	push   %ebp
f010367d:	89 e5                	mov    %esp,%ebp
f010367f:	53                   	push   %ebx
f0103680:	83 ec 14             	sub    $0x14,%esp
f0103683:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("user_mem_assert\r\n");
f0103686:	c7 04 24 01 70 10 f0 	movl   $0xf0107001,(%esp)
f010368d:	e8 9f 0a 00 00       	call   f0104131 <cprintf>
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f0103692:	8b 45 14             	mov    0x14(%ebp),%eax
f0103695:	83 c8 04             	or     $0x4,%eax
f0103698:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010369c:	8b 45 10             	mov    0x10(%ebp),%eax
f010369f:	89 44 24 08          	mov    %eax,0x8(%esp)
f01036a3:	8b 45 0c             	mov    0xc(%ebp),%eax
f01036a6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036aa:	89 1c 24             	mov    %ebx,(%esp)
f01036ad:	e8 0f ff ff ff       	call   f01035c1 <user_mem_check>
f01036b2:	85 c0                	test   %eax,%eax
f01036b4:	79 24                	jns    f01036da <user_mem_assert+0x5e>
		cprintf("[%08x] user_mem_check assertion failure for "
f01036b6:	a1 3c 32 22 f0       	mov    0xf022323c,%eax
f01036bb:	89 44 24 08          	mov    %eax,0x8(%esp)
f01036bf:	8b 43 48             	mov    0x48(%ebx),%eax
f01036c2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036c6:	c7 04 24 f0 76 10 f0 	movl   $0xf01076f0,(%esp)
f01036cd:	e8 5f 0a 00 00       	call   f0104131 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f01036d2:	89 1c 24             	mov    %ebx,(%esp)
f01036d5:	e8 a7 07 00 00       	call   f0103e81 <env_destroy>
	}
	cprintf("assert success!!\r\n");
f01036da:	c7 04 24 13 70 10 f0 	movl   $0xf0107013,(%esp)
f01036e1:	e8 4b 0a 00 00       	call   f0104131 <cprintf>
}
f01036e6:	83 c4 14             	add    $0x14,%esp
f01036e9:	5b                   	pop    %ebx
f01036ea:	5d                   	pop    %ebp
f01036eb:	c3                   	ret    

f01036ec <region_alloc>:
// Pages should be writable by user and kernel.
// Panic if any allocation attempt fails.
//
static void
region_alloc(struct Env *e, void *va, size_t len)
{
f01036ec:	55                   	push   %ebp
f01036ed:	89 e5                	mov    %esp,%ebp
f01036ef:	57                   	push   %edi
f01036f0:	56                   	push   %esi
f01036f1:	53                   	push   %ebx
f01036f2:	83 ec 1c             	sub    $0x1c,%esp
f01036f5:	89 c6                	mov    %eax,%esi
f01036f7:	89 d3                	mov    %edx,%ebx
f01036f9:	89 cf                	mov    %ecx,%edi
	// Hint: It is easier to use region_alloc if the caller can pass
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
f01036fb:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01036ff:	8b 40 60             	mov    0x60(%eax),%eax
f0103702:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103706:	c7 04 24 25 77 10 f0 	movl   $0xf0107725,(%esp)
f010370d:	e8 1f 0a 00 00       	call   f0104131 <cprintf>
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f0103712:	89 d8                	mov    %ebx,%eax
f0103714:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f010371a:	8d bc 38 ff 0f 00 00 	lea    0xfff(%eax,%edi,1),%edi
f0103721:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
f0103727:	39 fb                	cmp    %edi,%ebx
f0103729:	73 51                	jae    f010377c <region_alloc+0x90>
	{
		struct Page* p=(struct Page*)page_alloc(1);
f010372b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103732:	e8 5a d9 ff ff       	call   f0101091 <page_alloc>
		if(p==NULL)
f0103737:	85 c0                	test   %eax,%eax
f0103739:	75 1c                	jne    f0103757 <region_alloc+0x6b>
			panic("Memory out!");
f010373b:	c7 44 24 08 3a 77 10 	movl   $0xf010773a,0x8(%esp)
f0103742:	f0 
f0103743:	c7 44 24 04 2f 01 00 	movl   $0x12f,0x4(%esp)
f010374a:	00 
f010374b:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103752:	e8 e9 c8 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f0103757:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f010375e:	00 
f010375f:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103763:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103767:	8b 46 60             	mov    0x60(%esi),%eax
f010376a:	89 04 24             	mov    %eax,(%esp)
f010376d:	e8 73 dc ff ff       	call   f01013e5 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f0103772:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103778:	39 fb                	cmp    %edi,%ebx
f010377a:	72 af                	jb     f010372b <region_alloc+0x3f>
		if(p==NULL)
			panic("Memory out!");
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
	}

}
f010377c:	83 c4 1c             	add    $0x1c,%esp
f010377f:	5b                   	pop    %ebx
f0103780:	5e                   	pop    %esi
f0103781:	5f                   	pop    %edi
f0103782:	5d                   	pop    %ebp
f0103783:	c3                   	ret    

f0103784 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103784:	55                   	push   %ebp
f0103785:	89 e5                	mov    %esp,%ebp
f0103787:	56                   	push   %esi
f0103788:	53                   	push   %ebx
f0103789:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f010378c:	85 c0                	test   %eax,%eax
f010378e:	75 1a                	jne    f01037aa <envid2env+0x26>
		*env_store = curenv;
f0103790:	e8 1e 28 00 00       	call   f0105fb3 <cpunum>
f0103795:	6b c0 74             	imul   $0x74,%eax,%eax
f0103798:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010379e:	8b 55 0c             	mov    0xc(%ebp),%edx
f01037a1:	89 02                	mov    %eax,(%edx)
		return 0;
f01037a3:	b8 00 00 00 00       	mov    $0x0,%eax
f01037a8:	eb 72                	jmp    f010381c <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f01037aa:	89 c3                	mov    %eax,%ebx
f01037ac:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f01037b2:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f01037b5:	03 1d 48 32 22 f0    	add    0xf0223248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f01037bb:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f01037bf:	74 05                	je     f01037c6 <envid2env+0x42>
f01037c1:	39 43 48             	cmp    %eax,0x48(%ebx)
f01037c4:	74 10                	je     f01037d6 <envid2env+0x52>
		*env_store = 0;
f01037c6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01037c9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01037cf:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01037d4:	eb 46                	jmp    f010381c <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01037d6:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01037da:	74 36                	je     f0103812 <envid2env+0x8e>
f01037dc:	e8 d2 27 00 00       	call   f0105fb3 <cpunum>
f01037e1:	6b c0 74             	imul   $0x74,%eax,%eax
f01037e4:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f01037ea:	74 26                	je     f0103812 <envid2env+0x8e>
f01037ec:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01037ef:	e8 bf 27 00 00       	call   f0105fb3 <cpunum>
f01037f4:	6b c0 74             	imul   $0x74,%eax,%eax
f01037f7:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01037fd:	3b 70 48             	cmp    0x48(%eax),%esi
f0103800:	74 10                	je     f0103812 <envid2env+0x8e>
		*env_store = 0;
f0103802:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103805:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f010380b:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103810:	eb 0a                	jmp    f010381c <envid2env+0x98>
	}

	*env_store = e;
f0103812:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103815:	89 18                	mov    %ebx,(%eax)
	return 0;
f0103817:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010381c:	5b                   	pop    %ebx
f010381d:	5e                   	pop    %esi
f010381e:	5d                   	pop    %ebp
f010381f:	c3                   	ret    

f0103820 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0103820:	55                   	push   %ebp
f0103821:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0103823:	b8 00 03 12 f0       	mov    $0xf0120300,%eax
f0103828:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f010382b:	b8 23 00 00 00       	mov    $0x23,%eax
f0103830:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0103832:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103834:	b0 10                	mov    $0x10,%al
f0103836:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0103838:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010383a:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f010383c:	ea 43 38 10 f0 08 00 	ljmp   $0x8,$0xf0103843
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103843:	b0 00                	mov    $0x0,%al
f0103845:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103848:	5d                   	pop    %ebp
f0103849:	c3                   	ret    

f010384a <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010384a:	55                   	push   %ebp
f010384b:	89 e5                	mov    %esp,%ebp
f010384d:	57                   	push   %edi
f010384e:	56                   	push   %esi
f010384f:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
    {
    	envs[i].env_id=0;
f0103850:	8b 0d 48 32 22 f0    	mov    0xf0223248,%ecx
f0103856:	c7 41 48 00 00 00 00 	movl   $0x0,0x48(%ecx)
f010385d:	89 cf                	mov    %ecx,%edi
f010385f:	8d 51 7c             	lea    0x7c(%ecx),%edx
f0103862:	89 ce                	mov    %ecx,%esi
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f0103864:	b8 00 00 00 00       	mov    $0x0,%eax
    {
    	envs[i].env_id=0;
f0103869:	bb 00 00 00 00       	mov    $0x0,%ebx
f010386e:	eb 02                	jmp    f0103872 <env_init+0x28>
f0103870:	89 f9                	mov    %edi,%ecx
    	if(i!=NENV-1)
    	{
    	envs[i].env_link=&envs[i+1];
f0103872:	83 c3 01             	add    $0x1,%ebx
f0103875:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103878:	01 d9                	add    %ebx,%ecx
f010387a:	89 4e 44             	mov    %ecx,0x44(%esi)
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f010387d:	83 c0 01             	add    $0x1,%eax
    {
    	envs[i].env_id=0;
f0103880:	89 c3                	mov    %eax,%ebx
f0103882:	89 d6                	mov    %edx,%esi
f0103884:	c7 42 48 00 00 00 00 	movl   $0x0,0x48(%edx)
f010388b:	83 c2 7c             	add    $0x7c,%edx
    	if(i!=NENV-1)
f010388e:	3d ff 03 00 00       	cmp    $0x3ff,%eax
f0103893:	75 db                	jne    f0103870 <env_init+0x26>
    	{
    	envs[i].env_link=&envs[i+1];
    	}
    }
    env_free_list=envs;
f0103895:	a1 48 32 22 f0       	mov    0xf0223248,%eax
f010389a:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	// Per-CPU part of the initialization
	env_init_percpu();
f010389f:	e8 7c ff ff ff       	call   f0103820 <env_init_percpu>
}
f01038a4:	5b                   	pop    %ebx
f01038a5:	5e                   	pop    %esi
f01038a6:	5f                   	pop    %edi
f01038a7:	5d                   	pop    %ebp
f01038a8:	c3                   	ret    

f01038a9 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01038a9:	55                   	push   %ebp
f01038aa:	89 e5                	mov    %esp,%ebp
f01038ac:	56                   	push   %esi
f01038ad:	53                   	push   %ebx
f01038ae:	83 ec 10             	sub    $0x10,%esp
	cprintf("env_alloc");
f01038b1:	c7 04 24 51 77 10 f0 	movl   $0xf0107751,(%esp)
f01038b8:	e8 74 08 00 00       	call   f0104131 <cprintf>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f01038bd:	8b 1d 4c 32 22 f0    	mov    0xf022324c,%ebx
f01038c3:	85 db                	test   %ebx,%ebx
f01038c5:	0f 84 9e 01 00 00    	je     f0103a69 <env_alloc+0x1c0>
static int
env_setup_vm(struct Env *e)
{
	int i;
	struct Page *p = NULL;
	cprintf("env_setup_vm\r\n");
f01038cb:	c7 04 24 5b 77 10 f0 	movl   $0xf010775b,(%esp)
f01038d2:	e8 5a 08 00 00       	call   f0104131 <cprintf>
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f01038d7:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01038de:	e8 ae d7 ff ff       	call   f0101091 <page_alloc>
f01038e3:	85 c0                	test   %eax,%eax
f01038e5:	0f 84 85 01 00 00    	je     f0103a70 <env_alloc+0x1c7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01038eb:	89 c2                	mov    %eax,%edx
f01038ed:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01038f3:	c1 fa 03             	sar    $0x3,%edx
f01038f6:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01038f9:	89 d1                	mov    %edx,%ecx
f01038fb:	c1 e9 0c             	shr    $0xc,%ecx
f01038fe:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0103904:	72 20                	jb     f0103926 <env_alloc+0x7d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103906:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010390a:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0103911:	f0 
f0103912:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103919:	00 
f010391a:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0103921:	e8 1a c7 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103926:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f010392c:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
f010392f:	ba ec 0e 00 00       	mov    $0xeec,%edx
    for(i=PDX(UTOP);i<1024;i++)
    {
    	e->env_pgdir[i]=kern_pgdir[i];
f0103934:	8b 0d 8c 3e 22 f0    	mov    0xf0223e8c,%ecx
f010393a:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f010393d:	8b 4b 60             	mov    0x60(%ebx),%ecx
f0103940:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f0103943:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
    for(i=PDX(UTOP);i<1024;i++)
f0103946:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f010394c:	75 e6                	jne    f0103934 <env_alloc+0x8b>
    {
    	e->env_pgdir[i]=kern_pgdir[i];
    }
    p->pp_ref++;
f010394e:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0103953:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103956:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010395b:	77 20                	ja     f010397d <env_alloc+0xd4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010395d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103961:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103968:	f0 
f0103969:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
f0103970:	00 
f0103971:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103978:	e8 c3 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010397d:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103983:	83 ca 05             	or     $0x5,%edx
f0103986:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010398c:	8b 43 48             	mov    0x48(%ebx),%eax
f010398f:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103994:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103999:	ba 00 10 00 00       	mov    $0x1000,%edx
f010399e:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f01039a1:	89 da                	mov    %ebx,%edx
f01039a3:	2b 15 48 32 22 f0    	sub    0xf0223248,%edx
f01039a9:	c1 fa 02             	sar    $0x2,%edx
f01039ac:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01039b2:	09 d0                	or     %edx,%eax
f01039b4:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01039b7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01039ba:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f01039bd:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f01039c4:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f01039cb:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f01039d2:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f01039d9:	00 
f01039da:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01039e1:	00 
f01039e2:	89 1c 24             	mov    %ebx,(%esp)
f01039e5:	e8 2f 1f 00 00       	call   f0105919 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f01039ea:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f01039f0:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f01039f6:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f01039fc:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f0103a03:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f0103a09:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f0103a10:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f0103a17:	8b 43 44             	mov    0x44(%ebx),%eax
f0103a1a:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	*newenv_store = e;
f0103a1f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103a22:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103a24:	8b 5b 48             	mov    0x48(%ebx),%ebx
f0103a27:	e8 87 25 00 00       	call   f0105fb3 <cpunum>
f0103a2c:	6b d0 74             	imul   $0x74,%eax,%edx
f0103a2f:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a34:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103a3b:	74 11                	je     f0103a4e <env_alloc+0x1a5>
f0103a3d:	e8 71 25 00 00       	call   f0105fb3 <cpunum>
f0103a42:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a45:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103a4b:	8b 40 48             	mov    0x48(%eax),%eax
f0103a4e:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103a52:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103a56:	c7 04 24 6a 77 10 f0 	movl   $0xf010776a,(%esp)
f0103a5d:	e8 cf 06 00 00       	call   f0104131 <cprintf>
	return 0;
f0103a62:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a67:	eb 0c                	jmp    f0103a75 <env_alloc+0x1cc>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0103a69:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0103a6e:	eb 05                	jmp    f0103a75 <env_alloc+0x1cc>
	int i;
	struct Page *p = NULL;
	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0103a70:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f0103a75:	83 c4 10             	add    $0x10,%esp
f0103a78:	5b                   	pop    %ebx
f0103a79:	5e                   	pop    %esi
f0103a7a:	5d                   	pop    %ebp
f0103a7b:	c3                   	ret    

f0103a7c <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f0103a7c:	55                   	push   %ebp
f0103a7d:	89 e5                	mov    %esp,%ebp
f0103a7f:	57                   	push   %edi
f0103a80:	56                   	push   %esi
f0103a81:	53                   	push   %ebx
f0103a82:	83 ec 3c             	sub    $0x3c,%esp
f0103a85:	8b 75 08             	mov    0x8(%ebp),%esi
	// LAB 3: Your code here.

	struct Env* env;

	if(env_alloc(&env,0)==0)
f0103a88:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103a8f:	00 
f0103a90:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103a93:	89 04 24             	mov    %eax,(%esp)
f0103a96:	e8 0e fe ff ff       	call   f01038a9 <env_alloc>
f0103a9b:	85 c0                	test   %eax,%eax
f0103a9d:	0f 85 d1 01 00 00    	jne    f0103c74 <env_create+0x1f8>
	{
		env->env_type=type;
f0103aa3:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103aa6:	89 c7                	mov    %eax,%edi
f0103aa8:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0103aab:	8b 45 10             	mov    0x10(%ebp),%eax
f0103aae:	89 47 50             	mov    %eax,0x50(%edi)
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f0103ab1:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103ab4:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103ab9:	77 20                	ja     f0103adb <env_create+0x5f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103abb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103abf:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103ac6:	f0 
f0103ac7:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
f0103ace:	00 
f0103acf:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103ad6:	e8 65 c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103adb:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103ae0:	0f 22 d8             	mov    %eax,%cr3
	cprintf("load_icode\r\n");
f0103ae3:	c7 04 24 7f 77 10 f0 	movl   $0xf010777f,(%esp)
f0103aea:	e8 42 06 00 00       	call   f0104131 <cprintf>
	struct Elf * ELFHDR=(struct Elf *)binary;
	struct Proghdr *ph, *eph;
	int i;
	if (ELFHDR->e_magic != ELF_MAGIC)
f0103aef:	81 3e 7f 45 4c 46    	cmpl   $0x464c457f,(%esi)
f0103af5:	74 1c                	je     f0103b13 <env_create+0x97>
			panic("Not a elf binary");
f0103af7:	c7 44 24 08 8c 77 10 	movl   $0xf010778c,0x8(%esp)
f0103afe:	f0 
f0103aff:	c7 44 24 04 71 01 00 	movl   $0x171,0x4(%esp)
f0103b06:	00 
f0103b07:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103b0e:	e8 2d c5 ff ff       	call   f0100040 <_panic>


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0103b13:	89 f3                	mov    %esi,%ebx
f0103b15:	03 5e 1c             	add    0x1c(%esi),%ebx
		eph = ph + ELFHDR->e_phnum;
f0103b18:	0f b7 46 2c          	movzwl 0x2c(%esi),%eax
f0103b1c:	c1 e0 05             	shl    $0x5,%eax
f0103b1f:	01 d8                	add    %ebx,%eax
f0103b21:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		for (; ph < eph; ph++)
f0103b24:	39 c3                	cmp    %eax,%ebx
f0103b26:	73 5e                	jae    f0103b86 <env_create+0x10a>
		{
			// p_pa is the load address of this segment (as well
			// as the physical address)
			if(ph->p_type==ELF_PROG_LOAD)
f0103b28:	83 3b 01             	cmpl   $0x1,(%ebx)
f0103b2b:	75 51                	jne    f0103b7e <env_create+0x102>
			{
			cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
f0103b2d:	8b 43 08             	mov    0x8(%ebx),%eax
f0103b30:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103b34:	8b 43 10             	mov    0x10(%ebx),%eax
f0103b37:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103b3b:	c7 04 24 9d 77 10 f0 	movl   $0xf010779d,(%esp)
f0103b42:	e8 ea 05 00 00       	call   f0104131 <cprintf>
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
f0103b47:	8b 4b 10             	mov    0x10(%ebx),%ecx
f0103b4a:	8b 53 08             	mov    0x8(%ebx),%edx
f0103b4d:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103b50:	e8 97 fb ff ff       	call   f01036ec <region_alloc>
			char* va=(char*)ph->p_va;
f0103b55:	8b 7b 08             	mov    0x8(%ebx),%edi
			for(i=0;i<ph->p_filesz;i++)
f0103b58:	83 7b 10 00          	cmpl   $0x0,0x10(%ebx)
f0103b5c:	74 20                	je     f0103b7e <env_create+0x102>
f0103b5e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103b63:	ba 00 00 00 00       	mov    $0x0,%edx
			{

				va[i]=binary[ph->p_offset+i];
f0103b68:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
f0103b6b:	03 4b 04             	add    0x4(%ebx),%ecx
f0103b6e:	0f b6 09             	movzbl (%ecx),%ecx
f0103b71:	88 0c 17             	mov    %cl,(%edi,%edx,1)
			if(ph->p_type==ELF_PROG_LOAD)
			{
			cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
			char* va=(char*)ph->p_va;
			for(i=0;i<ph->p_filesz;i++)
f0103b74:	83 c0 01             	add    $0x1,%eax
f0103b77:	89 c2                	mov    %eax,%edx
f0103b79:	3b 43 10             	cmp    0x10(%ebx),%eax
f0103b7c:	72 ea                	jb     f0103b68 <env_create+0xec>
			panic("Not a elf binary");


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
		eph = ph + ELFHDR->e_phnum;
		for (; ph < eph; ph++)
f0103b7e:	83 c3 20             	add    $0x20,%ebx
f0103b81:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0103b84:	77 a2                	ja     f0103b28 <env_create+0xac>
			}

			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
f0103b86:	89 f3                	mov    %esi,%ebx
f0103b88:	03 5e 20             	add    0x20(%esi),%ebx
		eshdr= shdr + ELFHDR->e_shnum;
f0103b8b:	0f b7 46 30          	movzwl 0x30(%esi),%eax
f0103b8f:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0103b92:	8d 3c c3             	lea    (%ebx,%eax,8),%edi
				for (; shdr < eshdr; shdr++)
f0103b95:	39 fb                	cmp    %edi,%ebx
f0103b97:	73 44                	jae    f0103bdd <env_create+0x161>
				{
					// p_pa is the load address of this segment (as well
					// as the physical address)
					if(shdr->sh_type==8)
f0103b99:	83 7b 04 08          	cmpl   $0x8,0x4(%ebx)
f0103b9d:	75 37                	jne    f0103bd6 <env_create+0x15a>
					{
					cprintf("section %08x %08x %08x %08x\r\n",shdr->sh_size,shdr->sh_addr,shdr->sh_offset,shdr->sh_type);
f0103b9f:	c7 44 24 10 08 00 00 	movl   $0x8,0x10(%esp)
f0103ba6:	00 
f0103ba7:	8b 43 10             	mov    0x10(%ebx),%eax
f0103baa:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103bae:	8b 43 0c             	mov    0xc(%ebx),%eax
f0103bb1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103bb5:	8b 43 14             	mov    0x14(%ebx),%eax
f0103bb8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103bbc:	c7 04 24 b4 77 10 f0 	movl   $0xf01077b4,(%esp)
f0103bc3:	e8 69 05 00 00       	call   f0104131 <cprintf>
					region_alloc(e,(void*)shdr->sh_addr,shdr->sh_size);
f0103bc8:	8b 4b 14             	mov    0x14(%ebx),%ecx
f0103bcb:	8b 53 0c             	mov    0xc(%ebx),%edx
f0103bce:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103bd1:	e8 16 fb ff ff       	call   f01036ec <region_alloc>
			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
		eshdr= shdr + ELFHDR->e_shnum;
				for (; shdr < eshdr; shdr++)
f0103bd6:	83 c3 28             	add    $0x28,%ebx
f0103bd9:	39 df                	cmp    %ebx,%edi
f0103bdb:	77 bc                	ja     f0103b99 <env_create+0x11d>


					}
				}

		e->env_tf.tf_eip=ELFHDR->e_entry;
f0103bdd:	8b 46 18             	mov    0x18(%esi),%eax
f0103be0:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0103be3:	89 46 30             	mov    %eax,0x30(%esi)

	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
		struct Page* p=(struct Page*)page_alloc(1);
f0103be6:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103bed:	e8 9f d4 ff ff       	call   f0101091 <page_alloc>
     if(p==NULL)
f0103bf2:	85 c0                	test   %eax,%eax
f0103bf4:	75 1c                	jne    f0103c12 <env_create+0x196>
    	 panic("Not enough mem for user stack!");
f0103bf6:	c7 44 24 08 14 78 10 	movl   $0xf0107814,0x8(%esp)
f0103bfd:	f0 
f0103bfe:	c7 44 24 04 9f 01 00 	movl   $0x19f,0x4(%esp)
f0103c05:	00 
f0103c06:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103c0d:	e8 2e c4 ff ff       	call   f0100040 <_panic>
     page_insert(e->env_pgdir,p,(void*)(USTACKTOP-PGSIZE),PTE_W|PTE_U);
f0103c12:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103c19:	00 
f0103c1a:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0103c21:	ee 
f0103c22:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c26:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103c29:	8b 40 60             	mov    0x60(%eax),%eax
f0103c2c:	89 04 24             	mov    %eax,(%esp)
f0103c2f:	e8 b1 d7 ff ff       	call   f01013e5 <page_insert>
     cprintf("load_icode finish!\r\n");
f0103c34:	c7 04 24 d2 77 10 f0 	movl   $0xf01077d2,(%esp)
f0103c3b:	e8 f1 04 00 00       	call   f0104131 <cprintf>
     lcr3(PADDR(kern_pgdir));
f0103c40:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103c45:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103c4a:	77 20                	ja     f0103c6c <env_create+0x1f0>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103c4c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103c50:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103c57:	f0 
f0103c58:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
f0103c5f:	00 
f0103c60:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103c67:	e8 d4 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103c6c:	05 00 00 00 10       	add    $0x10000000,%eax
f0103c71:	0f 22 d8             	mov    %eax,%cr3
	{
		env->env_type=type;
		load_icode(env, binary,size);
	}

}
f0103c74:	83 c4 3c             	add    $0x3c,%esp
f0103c77:	5b                   	pop    %ebx
f0103c78:	5e                   	pop    %esi
f0103c79:	5f                   	pop    %edi
f0103c7a:	5d                   	pop    %ebp
f0103c7b:	c3                   	ret    

f0103c7c <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103c7c:	55                   	push   %ebp
f0103c7d:	89 e5                	mov    %esp,%ebp
f0103c7f:	57                   	push   %edi
f0103c80:	56                   	push   %esi
f0103c81:	53                   	push   %ebx
f0103c82:	83 ec 2c             	sub    $0x2c,%esp
f0103c85:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103c88:	e8 26 23 00 00       	call   f0105fb3 <cpunum>
f0103c8d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c90:	39 b8 28 40 22 f0    	cmp    %edi,-0xfddbfd8(%eax)
f0103c96:	75 34                	jne    f0103ccc <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0103c98:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103c9d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103ca2:	77 20                	ja     f0103cc4 <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103ca4:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ca8:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103caf:	f0 
f0103cb0:	c7 44 24 04 c9 01 00 	movl   $0x1c9,0x4(%esp)
f0103cb7:	00 
f0103cb8:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103cbf:	e8 7c c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103cc4:	05 00 00 00 10       	add    $0x10000000,%eax
f0103cc9:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103ccc:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103ccf:	e8 df 22 00 00       	call   f0105fb3 <cpunum>
f0103cd4:	6b d0 74             	imul   $0x74,%eax,%edx
f0103cd7:	b8 00 00 00 00       	mov    $0x0,%eax
f0103cdc:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103ce3:	74 11                	je     f0103cf6 <env_free+0x7a>
f0103ce5:	e8 c9 22 00 00       	call   f0105fb3 <cpunum>
f0103cea:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ced:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103cf3:	8b 40 48             	mov    0x48(%eax),%eax
f0103cf6:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103cfa:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103cfe:	c7 04 24 e7 77 10 f0 	movl   $0xf01077e7,(%esp)
f0103d05:	e8 27 04 00 00       	call   f0104131 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103d0a:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103d11:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103d14:	89 c8                	mov    %ecx,%eax
f0103d16:	c1 e0 02             	shl    $0x2,%eax
f0103d19:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103d1c:	8b 47 60             	mov    0x60(%edi),%eax
f0103d1f:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103d22:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103d28:	0f 84 b7 00 00 00    	je     f0103de5 <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103d2e:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103d34:	89 f0                	mov    %esi,%eax
f0103d36:	c1 e8 0c             	shr    $0xc,%eax
f0103d39:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103d3c:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103d42:	72 20                	jb     f0103d64 <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103d44:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103d48:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0103d4f:	f0 
f0103d50:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
f0103d57:	00 
f0103d58:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103d5f:	e8 dc c2 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103d64:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103d67:	c1 e0 16             	shl    $0x16,%eax
f0103d6a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103d6d:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103d72:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103d79:	01 
f0103d7a:	74 17                	je     f0103d93 <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103d7c:	89 d8                	mov    %ebx,%eax
f0103d7e:	c1 e0 0c             	shl    $0xc,%eax
f0103d81:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103d84:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d88:	8b 47 60             	mov    0x60(%edi),%eax
f0103d8b:	89 04 24             	mov    %eax,(%esp)
f0103d8e:	e8 02 d6 ff ff       	call   f0101395 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103d93:	83 c3 01             	add    $0x1,%ebx
f0103d96:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103d9c:	75 d4                	jne    f0103d72 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103d9e:	8b 47 60             	mov    0x60(%edi),%eax
f0103da1:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103da4:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103dab:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103dae:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103db4:	72 1c                	jb     f0103dd2 <env_free+0x156>
		panic("pa2page called with invalid pa");
f0103db6:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0103dbd:	f0 
f0103dbe:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103dc5:	00 
f0103dc6:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0103dcd:	e8 6e c2 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103dd2:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0103dd7:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103dda:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103ddd:	89 04 24             	mov    %eax,(%esp)
f0103de0:	e8 4c d3 ff ff       	call   f0101131 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103de5:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103de9:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103df0:	0f 85 1b ff ff ff    	jne    f0103d11 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103df6:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103df9:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103dfe:	77 20                	ja     f0103e20 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103e00:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e04:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103e0b:	f0 
f0103e0c:	c7 44 24 04 e6 01 00 	movl   $0x1e6,0x4(%esp)
f0103e13:	00 
f0103e14:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103e1b:	e8 20 c2 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103e20:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103e27:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103e2c:	c1 e8 0c             	shr    $0xc,%eax
f0103e2f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103e35:	72 1c                	jb     f0103e53 <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0103e37:	c7 44 24 08 ec 70 10 	movl   $0xf01070ec,0x8(%esp)
f0103e3e:	f0 
f0103e3f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103e46:	00 
f0103e47:	c7 04 24 92 6c 10 f0 	movl   $0xf0106c92,(%esp)
f0103e4e:	e8 ed c1 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103e53:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103e59:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103e5c:	89 04 24             	mov    %eax,(%esp)
f0103e5f:	e8 cd d2 ff ff       	call   f0101131 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103e64:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103e6b:	a1 4c 32 22 f0       	mov    0xf022324c,%eax
f0103e70:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103e73:	89 3d 4c 32 22 f0    	mov    %edi,0xf022324c
}
f0103e79:	83 c4 2c             	add    $0x2c,%esp
f0103e7c:	5b                   	pop    %ebx
f0103e7d:	5e                   	pop    %esi
f0103e7e:	5f                   	pop    %edi
f0103e7f:	5d                   	pop    %ebp
f0103e80:	c3                   	ret    

f0103e81 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103e81:	55                   	push   %ebp
f0103e82:	89 e5                	mov    %esp,%ebp
f0103e84:	53                   	push   %ebx
f0103e85:	83 ec 14             	sub    $0x14,%esp
f0103e88:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103e8b:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103e8f:	75 19                	jne    f0103eaa <env_destroy+0x29>
f0103e91:	e8 1d 21 00 00       	call   f0105fb3 <cpunum>
f0103e96:	6b c0 74             	imul   $0x74,%eax,%eax
f0103e99:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103e9f:	74 09                	je     f0103eaa <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103ea1:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103ea8:	eb 2f                	jmp    f0103ed9 <env_destroy+0x58>
	}

	env_free(e);
f0103eaa:	89 1c 24             	mov    %ebx,(%esp)
f0103ead:	e8 ca fd ff ff       	call   f0103c7c <env_free>

	if (curenv == e) {
f0103eb2:	e8 fc 20 00 00       	call   f0105fb3 <cpunum>
f0103eb7:	6b c0 74             	imul   $0x74,%eax,%eax
f0103eba:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103ec0:	75 17                	jne    f0103ed9 <env_destroy+0x58>
		curenv = NULL;
f0103ec2:	e8 ec 20 00 00       	call   f0105fb3 <cpunum>
f0103ec7:	6b c0 74             	imul   $0x74,%eax,%eax
f0103eca:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f0103ed1:	00 00 00 
		sched_yield();
f0103ed4:	e8 3c 0b 00 00       	call   f0104a15 <sched_yield>
	}
}
f0103ed9:	83 c4 14             	add    $0x14,%esp
f0103edc:	5b                   	pop    %ebx
f0103edd:	5d                   	pop    %ebp
f0103ede:	c3                   	ret    

f0103edf <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103edf:	55                   	push   %ebp
f0103ee0:	89 e5                	mov    %esp,%ebp
f0103ee2:	53                   	push   %ebx
f0103ee3:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103ee6:	e8 c8 20 00 00       	call   f0105fb3 <cpunum>
f0103eeb:	6b c0 74             	imul   $0x74,%eax,%eax
f0103eee:	8b 98 28 40 22 f0    	mov    -0xfddbfd8(%eax),%ebx
f0103ef4:	e8 ba 20 00 00       	call   f0105fb3 <cpunum>
f0103ef9:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103efc:	8b 65 08             	mov    0x8(%ebp),%esp
f0103eff:	61                   	popa   
f0103f00:	07                   	pop    %es
f0103f01:	1f                   	pop    %ds
f0103f02:	83 c4 08             	add    $0x8,%esp
f0103f05:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103f06:	c7 44 24 08 fd 77 10 	movl   $0xf01077fd,0x8(%esp)
f0103f0d:	f0 
f0103f0e:	c7 44 24 04 1c 02 00 	movl   $0x21c,0x4(%esp)
f0103f15:	00 
f0103f16:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103f1d:	e8 1e c1 ff ff       	call   f0100040 <_panic>

f0103f22 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103f22:	55                   	push   %ebp
f0103f23:	89 e5                	mov    %esp,%ebp
f0103f25:	53                   	push   %ebx
f0103f26:	83 ec 14             	sub    $0x14,%esp
f0103f29:	8b 5d 08             	mov    0x8(%ebp),%ebx
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.
	cprintf("Run env!\r\n");
f0103f2c:	c7 04 24 09 78 10 f0 	movl   $0xf0107809,(%esp)
f0103f33:	e8 f9 01 00 00       	call   f0104131 <cprintf>
    if(curenv!=NULL)
f0103f38:	e8 76 20 00 00       	call   f0105fb3 <cpunum>
f0103f3d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f40:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0103f47:	74 29                	je     f0103f72 <env_run+0x50>
    {
    	if(curenv->env_status==ENV_RUNNING)
f0103f49:	e8 65 20 00 00       	call   f0105fb3 <cpunum>
f0103f4e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f51:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103f57:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103f5b:	75 15                	jne    f0103f72 <env_run+0x50>
    	{
    		curenv->env_status=ENV_RUNNABLE;
f0103f5d:	e8 51 20 00 00       	call   f0105fb3 <cpunum>
f0103f62:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f65:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103f6b:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
    	}
    }
    curenv=e;
f0103f72:	e8 3c 20 00 00       	call   f0105fb3 <cpunum>
f0103f77:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f7a:	89 98 28 40 22 f0    	mov    %ebx,-0xfddbfd8(%eax)
    e->env_status=ENV_RUNNING;
f0103f80:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
    e->env_runs++;
f0103f87:	83 43 58 01          	addl   $0x1,0x58(%ebx)
    lcr3(PADDR(e->env_pgdir));
f0103f8b:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103f8e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103f93:	77 20                	ja     f0103fb5 <env_run+0x93>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103f95:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103f99:	c7 44 24 08 08 67 10 	movl   $0xf0106708,0x8(%esp)
f0103fa0:	f0 
f0103fa1:	c7 44 24 04 45 02 00 	movl   $0x245,0x4(%esp)
f0103fa8:	00 
f0103fa9:	c7 04 24 46 77 10 f0 	movl   $0xf0107746,(%esp)
f0103fb0:	e8 8b c0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103fb5:	05 00 00 00 10       	add    $0x10000000,%eax
f0103fba:	0f 22 d8             	mov    %eax,%cr3
    env_pop_tf(&e->env_tf);
f0103fbd:	89 1c 24             	mov    %ebx,(%esp)
f0103fc0:	e8 1a ff ff ff       	call   f0103edf <env_pop_tf>

f0103fc5 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103fc5:	55                   	push   %ebp
f0103fc6:	89 e5                	mov    %esp,%ebp
f0103fc8:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103fcc:	ba 70 00 00 00       	mov    $0x70,%edx
f0103fd1:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103fd2:	b2 71                	mov    $0x71,%dl
f0103fd4:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103fd5:	0f b6 c0             	movzbl %al,%eax
}
f0103fd8:	5d                   	pop    %ebp
f0103fd9:	c3                   	ret    

f0103fda <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103fda:	55                   	push   %ebp
f0103fdb:	89 e5                	mov    %esp,%ebp
f0103fdd:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103fe1:	ba 70 00 00 00       	mov    $0x70,%edx
f0103fe6:	ee                   	out    %al,(%dx)
f0103fe7:	b2 71                	mov    $0x71,%dl
f0103fe9:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103fec:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103fed:	5d                   	pop    %ebp
f0103fee:	c3                   	ret    

f0103fef <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103fef:	55                   	push   %ebp
f0103ff0:	89 e5                	mov    %esp,%ebp
f0103ff2:	56                   	push   %esi
f0103ff3:	53                   	push   %ebx
f0103ff4:	83 ec 10             	sub    $0x10,%esp
f0103ff7:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103ffa:	66 a3 88 03 12 f0    	mov    %ax,0xf0120388
	if (!didinit)
f0104000:	83 3d 50 32 22 f0 00 	cmpl   $0x0,0xf0223250
f0104007:	74 4e                	je     f0104057 <irq_setmask_8259A+0x68>
f0104009:	89 c6                	mov    %eax,%esi
f010400b:	ba 21 00 00 00       	mov    $0x21,%edx
f0104010:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0104011:	66 c1 e8 08          	shr    $0x8,%ax
f0104015:	b2 a1                	mov    $0xa1,%dl
f0104017:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0104018:	c7 04 24 33 78 10 f0 	movl   $0xf0107833,(%esp)
f010401f:	e8 0d 01 00 00       	call   f0104131 <cprintf>
	for (i = 0; i < 16; i++)
f0104024:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0104029:	0f b7 f6             	movzwl %si,%esi
f010402c:	f7 d6                	not    %esi
f010402e:	0f a3 de             	bt     %ebx,%esi
f0104031:	73 10                	jae    f0104043 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0104033:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104037:	c7 04 24 f9 7c 10 f0 	movl   $0xf0107cf9,(%esp)
f010403e:	e8 ee 00 00 00       	call   f0104131 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0104043:	83 c3 01             	add    $0x1,%ebx
f0104046:	83 fb 10             	cmp    $0x10,%ebx
f0104049:	75 e3                	jne    f010402e <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f010404b:	c7 04 24 b2 77 10 f0 	movl   $0xf01077b2,(%esp)
f0104052:	e8 da 00 00 00       	call   f0104131 <cprintf>
}
f0104057:	83 c4 10             	add    $0x10,%esp
f010405a:	5b                   	pop    %ebx
f010405b:	5e                   	pop    %esi
f010405c:	5d                   	pop    %ebp
f010405d:	c3                   	ret    

f010405e <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f010405e:	c7 05 50 32 22 f0 01 	movl   $0x1,0xf0223250
f0104065:	00 00 00 
f0104068:	ba 21 00 00 00       	mov    $0x21,%edx
f010406d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104072:	ee                   	out    %al,(%dx)
f0104073:	b2 a1                	mov    $0xa1,%dl
f0104075:	ee                   	out    %al,(%dx)
f0104076:	b2 20                	mov    $0x20,%dl
f0104078:	b8 11 00 00 00       	mov    $0x11,%eax
f010407d:	ee                   	out    %al,(%dx)
f010407e:	b2 21                	mov    $0x21,%dl
f0104080:	b8 20 00 00 00       	mov    $0x20,%eax
f0104085:	ee                   	out    %al,(%dx)
f0104086:	b8 04 00 00 00       	mov    $0x4,%eax
f010408b:	ee                   	out    %al,(%dx)
f010408c:	b8 03 00 00 00       	mov    $0x3,%eax
f0104091:	ee                   	out    %al,(%dx)
f0104092:	b2 a0                	mov    $0xa0,%dl
f0104094:	b8 11 00 00 00       	mov    $0x11,%eax
f0104099:	ee                   	out    %al,(%dx)
f010409a:	b2 a1                	mov    $0xa1,%dl
f010409c:	b8 28 00 00 00       	mov    $0x28,%eax
f01040a1:	ee                   	out    %al,(%dx)
f01040a2:	b8 02 00 00 00       	mov    $0x2,%eax
f01040a7:	ee                   	out    %al,(%dx)
f01040a8:	b8 01 00 00 00       	mov    $0x1,%eax
f01040ad:	ee                   	out    %al,(%dx)
f01040ae:	b2 20                	mov    $0x20,%dl
f01040b0:	b8 68 00 00 00       	mov    $0x68,%eax
f01040b5:	ee                   	out    %al,(%dx)
f01040b6:	b8 0a 00 00 00       	mov    $0xa,%eax
f01040bb:	ee                   	out    %al,(%dx)
f01040bc:	b2 a0                	mov    $0xa0,%dl
f01040be:	b8 68 00 00 00       	mov    $0x68,%eax
f01040c3:	ee                   	out    %al,(%dx)
f01040c4:	b8 0a 00 00 00       	mov    $0xa,%eax
f01040c9:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f01040ca:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f01040d1:	66 83 f8 ff          	cmp    $0xffff,%ax
f01040d5:	74 12                	je     f01040e9 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f01040d7:	55                   	push   %ebp
f01040d8:	89 e5                	mov    %esp,%ebp
f01040da:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f01040dd:	0f b7 c0             	movzwl %ax,%eax
f01040e0:	89 04 24             	mov    %eax,(%esp)
f01040e3:	e8 07 ff ff ff       	call   f0103fef <irq_setmask_8259A>
}
f01040e8:	c9                   	leave  
f01040e9:	f3 c3                	repz ret 

f01040eb <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f01040eb:	55                   	push   %ebp
f01040ec:	89 e5                	mov    %esp,%ebp
f01040ee:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f01040f1:	8b 45 08             	mov    0x8(%ebp),%eax
f01040f4:	89 04 24             	mov    %eax,(%esp)
f01040f7:	e8 f1 c6 ff ff       	call   f01007ed <cputchar>
	*cnt++;
}
f01040fc:	c9                   	leave  
f01040fd:	c3                   	ret    

f01040fe <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f01040fe:	55                   	push   %ebp
f01040ff:	89 e5                	mov    %esp,%ebp
f0104101:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0104104:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f010410b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010410e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104112:	8b 45 08             	mov    0x8(%ebp),%eax
f0104115:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104119:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010411c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104120:	c7 04 24 eb 40 10 f0 	movl   $0xf01040eb,(%esp)
f0104127:	e8 ee 0f 00 00       	call   f010511a <vprintfmt>
	return cnt;
}
f010412c:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010412f:	c9                   	leave  
f0104130:	c3                   	ret    

f0104131 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0104131:	55                   	push   %ebp
f0104132:	89 e5                	mov    %esp,%ebp
f0104134:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0104137:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f010413a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010413e:	8b 45 08             	mov    0x8(%ebp),%eax
f0104141:	89 04 24             	mov    %eax,(%esp)
f0104144:	e8 b5 ff ff ff       	call   f01040fe <vcprintf>
	va_end(ap);

	return cnt;
}
f0104149:	c9                   	leave  
f010414a:	c3                   	ret    

f010414b <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f010414b:	55                   	push   %ebp
f010414c:	89 e5                	mov    %esp,%ebp
f010414e:	57                   	push   %edi
f010414f:	56                   	push   %esi
f0104150:	53                   	push   %ebx
f0104151:	83 ec 0c             	sub    $0xc,%esp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	thiscpu->cpu_ts.ts_esp0 = KSTACKTOP - cpunum() * (KSTKGAP + KSTKSIZE);
f0104154:	e8 5a 1e 00 00       	call   f0105fb3 <cpunum>
f0104159:	89 c3                	mov    %eax,%ebx
f010415b:	e8 53 1e 00 00       	call   f0105fb3 <cpunum>
f0104160:	6b db 74             	imul   $0x74,%ebx,%ebx
f0104163:	f7 d8                	neg    %eax
f0104165:	c1 e0 10             	shl    $0x10,%eax
f0104168:	2d 00 00 40 10       	sub    $0x10400000,%eax
f010416d:	89 83 30 40 22 f0    	mov    %eax,-0xfddbfd0(%ebx)
    thiscpu->cpu_ts.ts_ss0 = GD_KD;
f0104173:	e8 3b 1e 00 00       	call   f0105fb3 <cpunum>
f0104178:	6b c0 74             	imul   $0x74,%eax,%eax
f010417b:	66 c7 80 34 40 22 f0 	movw   $0x10,-0xfddbfcc(%eax)
f0104182:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[(GD_TSS0 >> 3) + cpunum()] = SEG16(STS_T32A, (uint32_t) (&thiscpu->cpu_ts), sizeof(struct Taskstate) - 1, 0);
f0104184:	e8 2a 1e 00 00       	call   f0105fb3 <cpunum>
f0104189:	8d 58 05             	lea    0x5(%eax),%ebx
f010418c:	e8 22 1e 00 00       	call   f0105fb3 <cpunum>
f0104191:	89 c7                	mov    %eax,%edi
f0104193:	e8 1b 1e 00 00       	call   f0105fb3 <cpunum>
f0104198:	89 c6                	mov    %eax,%esi
f010419a:	e8 14 1e 00 00       	call   f0105fb3 <cpunum>
f010419f:	66 c7 04 dd 20 03 12 	movw   $0x67,-0xfedfce0(,%ebx,8)
f01041a6:	f0 67 00 
f01041a9:	6b ff 74             	imul   $0x74,%edi,%edi
f01041ac:	81 c7 2c 40 22 f0    	add    $0xf022402c,%edi
f01041b2:	66 89 3c dd 22 03 12 	mov    %di,-0xfedfcde(,%ebx,8)
f01041b9:	f0 
f01041ba:	6b d6 74             	imul   $0x74,%esi,%edx
f01041bd:	81 c2 2c 40 22 f0    	add    $0xf022402c,%edx
f01041c3:	c1 ea 10             	shr    $0x10,%edx
f01041c6:	88 14 dd 24 03 12 f0 	mov    %dl,-0xfedfcdc(,%ebx,8)
f01041cd:	c6 04 dd 25 03 12 f0 	movb   $0x99,-0xfedfcdb(,%ebx,8)
f01041d4:	99 
f01041d5:	c6 04 dd 26 03 12 f0 	movb   $0x40,-0xfedfcda(,%ebx,8)
f01041dc:	40 
f01041dd:	6b c0 74             	imul   $0x74,%eax,%eax
f01041e0:	05 2c 40 22 f0       	add    $0xf022402c,%eax
f01041e5:	c1 e8 18             	shr    $0x18,%eax
f01041e8:	88 04 dd 27 03 12 f0 	mov    %al,-0xfedfcd9(,%ebx,8)
    gdt[(GD_TSS0 >> 3) + cpunum()].sd_s = 0;
f01041ef:	e8 bf 1d 00 00       	call   f0105fb3 <cpunum>
f01041f4:	80 24 c5 4d 03 12 f0 	andb   $0xef,-0xfedfcb3(,%eax,8)
f01041fb:	ef 

	// Load the TSS selector (like other segment selectors, the
	// bottom three bits are special; we leave them 0)
	 ltr(GD_TSS0 + sizeof(struct Segdesc) * cpunum());
f01041fc:	e8 b2 1d 00 00       	call   f0105fb3 <cpunum>
f0104201:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0104208:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f010420b:	b8 8a 03 12 f0       	mov    $0xf012038a,%eax
f0104210:	0f 01 18             	lidtl  (%eax)


	// Load the IDT
	lidt(&idt_pd);
}
f0104213:	83 c4 0c             	add    $0xc,%esp
f0104216:	5b                   	pop    %ebx
f0104217:	5e                   	pop    %esi
f0104218:	5f                   	pop    %edi
f0104219:	5d                   	pop    %ebp
f010421a:	c3                   	ret    

f010421b <trap_init>:
}


void
trap_init(void)
{
f010421b:	55                   	push   %ebp
f010421c:	89 e5                	mov    %esp,%ebp
f010421e:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0104221:	b8 9e 49 10 f0       	mov    $0xf010499e,%eax
f0104226:	66 a3 60 32 22 f0    	mov    %ax,0xf0223260
f010422c:	66 c7 05 62 32 22 f0 	movw   $0x8,0xf0223262
f0104233:	08 00 
f0104235:	c6 05 64 32 22 f0 00 	movb   $0x0,0xf0223264
f010423c:	c6 05 65 32 22 f0 8f 	movb   $0x8f,0xf0223265
f0104243:	c1 e8 10             	shr    $0x10,%eax
f0104246:	66 a3 66 32 22 f0    	mov    %ax,0xf0223266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f010424c:	b8 a4 49 10 f0       	mov    $0xf01049a4,%eax
f0104251:	66 a3 70 32 22 f0    	mov    %ax,0xf0223270
f0104257:	66 c7 05 72 32 22 f0 	movw   $0x8,0xf0223272
f010425e:	08 00 
f0104260:	c6 05 74 32 22 f0 00 	movb   $0x0,0xf0223274
f0104267:	c6 05 75 32 22 f0 8e 	movb   $0x8e,0xf0223275
f010426e:	c1 e8 10             	shr    $0x10,%eax
f0104271:	66 a3 76 32 22 f0    	mov    %ax,0xf0223276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0104277:	b8 aa 49 10 f0       	mov    $0xf01049aa,%eax
f010427c:	66 a3 78 32 22 f0    	mov    %ax,0xf0223278
f0104282:	66 c7 05 7a 32 22 f0 	movw   $0x8,0xf022327a
f0104289:	08 00 
f010428b:	c6 05 7c 32 22 f0 00 	movb   $0x0,0xf022327c
f0104292:	c6 05 7d 32 22 f0 ef 	movb   $0xef,0xf022327d
f0104299:	c1 e8 10             	shr    $0x10,%eax
f010429c:	66 a3 7e 32 22 f0    	mov    %ax,0xf022327e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f01042a2:	b8 b0 49 10 f0       	mov    $0xf01049b0,%eax
f01042a7:	66 a3 80 32 22 f0    	mov    %ax,0xf0223280
f01042ad:	66 c7 05 82 32 22 f0 	movw   $0x8,0xf0223282
f01042b4:	08 00 
f01042b6:	c6 05 84 32 22 f0 00 	movb   $0x0,0xf0223284
f01042bd:	c6 05 85 32 22 f0 ef 	movb   $0xef,0xf0223285
f01042c4:	c1 e8 10             	shr    $0x10,%eax
f01042c7:	66 a3 86 32 22 f0    	mov    %ax,0xf0223286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f01042cd:	b8 b6 49 10 f0       	mov    $0xf01049b6,%eax
f01042d2:	66 a3 88 32 22 f0    	mov    %ax,0xf0223288
f01042d8:	66 c7 05 8a 32 22 f0 	movw   $0x8,0xf022328a
f01042df:	08 00 
f01042e1:	c6 05 8c 32 22 f0 00 	movb   $0x0,0xf022328c
f01042e8:	c6 05 8d 32 22 f0 ef 	movb   $0xef,0xf022328d
f01042ef:	c1 e8 10             	shr    $0x10,%eax
f01042f2:	66 a3 8e 32 22 f0    	mov    %ax,0xf022328e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f01042f8:	b8 bc 49 10 f0       	mov    $0xf01049bc,%eax
f01042fd:	66 a3 90 32 22 f0    	mov    %ax,0xf0223290
f0104303:	66 c7 05 92 32 22 f0 	movw   $0x8,0xf0223292
f010430a:	08 00 
f010430c:	c6 05 94 32 22 f0 00 	movb   $0x0,0xf0223294
f0104313:	c6 05 95 32 22 f0 8f 	movb   $0x8f,0xf0223295
f010431a:	c1 e8 10             	shr    $0x10,%eax
f010431d:	66 a3 96 32 22 f0    	mov    %ax,0xf0223296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104323:	b8 c2 49 10 f0       	mov    $0xf01049c2,%eax
f0104328:	66 a3 98 32 22 f0    	mov    %ax,0xf0223298
f010432e:	66 c7 05 9a 32 22 f0 	movw   $0x8,0xf022329a
f0104335:	08 00 
f0104337:	c6 05 9c 32 22 f0 00 	movb   $0x0,0xf022329c
f010433e:	c6 05 9d 32 22 f0 8f 	movb   $0x8f,0xf022329d
f0104345:	c1 e8 10             	shr    $0x10,%eax
f0104348:	66 a3 9e 32 22 f0    	mov    %ax,0xf022329e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010434e:	b8 c8 49 10 f0       	mov    $0xf01049c8,%eax
f0104353:	66 a3 a0 32 22 f0    	mov    %ax,0xf02232a0
f0104359:	66 c7 05 a2 32 22 f0 	movw   $0x8,0xf02232a2
f0104360:	08 00 
f0104362:	c6 05 a4 32 22 f0 00 	movb   $0x0,0xf02232a4
f0104369:	c6 05 a5 32 22 f0 8f 	movb   $0x8f,0xf02232a5
f0104370:	c1 e8 10             	shr    $0x10,%eax
f0104373:	66 a3 a6 32 22 f0    	mov    %ax,0xf02232a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104379:	b8 cc 49 10 f0       	mov    $0xf01049cc,%eax
f010437e:	66 a3 b0 32 22 f0    	mov    %ax,0xf02232b0
f0104384:	66 c7 05 b2 32 22 f0 	movw   $0x8,0xf02232b2
f010438b:	08 00 
f010438d:	c6 05 b4 32 22 f0 00 	movb   $0x0,0xf02232b4
f0104394:	c6 05 b5 32 22 f0 8f 	movb   $0x8f,0xf02232b5
f010439b:	c1 e8 10             	shr    $0x10,%eax
f010439e:	66 a3 b6 32 22 f0    	mov    %ax,0xf02232b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f01043a4:	b8 d0 49 10 f0       	mov    $0xf01049d0,%eax
f01043a9:	66 a3 b8 32 22 f0    	mov    %ax,0xf02232b8
f01043af:	66 c7 05 ba 32 22 f0 	movw   $0x8,0xf02232ba
f01043b6:	08 00 
f01043b8:	c6 05 bc 32 22 f0 00 	movb   $0x0,0xf02232bc
f01043bf:	c6 05 bd 32 22 f0 8f 	movb   $0x8f,0xf02232bd
f01043c6:	c1 e8 10             	shr    $0x10,%eax
f01043c9:	66 a3 be 32 22 f0    	mov    %ax,0xf02232be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01043cf:	b8 d4 49 10 f0       	mov    $0xf01049d4,%eax
f01043d4:	66 a3 c0 32 22 f0    	mov    %ax,0xf02232c0
f01043da:	66 c7 05 c2 32 22 f0 	movw   $0x8,0xf02232c2
f01043e1:	08 00 
f01043e3:	c6 05 c4 32 22 f0 00 	movb   $0x0,0xf02232c4
f01043ea:	c6 05 c5 32 22 f0 8f 	movb   $0x8f,0xf02232c5
f01043f1:	c1 e8 10             	shr    $0x10,%eax
f01043f4:	66 a3 c6 32 22 f0    	mov    %ax,0xf02232c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01043fa:	b8 dc 49 10 f0       	mov    $0xf01049dc,%eax
f01043ff:	66 a3 d0 32 22 f0    	mov    %ax,0xf02232d0
f0104405:	66 c7 05 d2 32 22 f0 	movw   $0x8,0xf02232d2
f010440c:	08 00 
f010440e:	c6 05 d4 32 22 f0 00 	movb   $0x0,0xf02232d4
f0104415:	c6 05 d5 32 22 f0 8f 	movb   $0x8f,0xf02232d5
f010441c:	c1 e8 10             	shr    $0x10,%eax
f010441f:	66 a3 d6 32 22 f0    	mov    %ax,0xf02232d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104425:	b8 d8 49 10 f0       	mov    $0xf01049d8,%eax
f010442a:	66 a3 c8 32 22 f0    	mov    %ax,0xf02232c8
f0104430:	66 c7 05 ca 32 22 f0 	movw   $0x8,0xf02232ca
f0104437:	08 00 
f0104439:	c6 05 cc 32 22 f0 00 	movb   $0x0,0xf02232cc
f0104440:	c6 05 cd 32 22 f0 8f 	movb   $0x8f,0xf02232cd
f0104447:	c1 e8 10             	shr    $0x10,%eax
f010444a:	66 a3 ce 32 22 f0    	mov    %ax,0xf02232ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f0104450:	b8 e0 49 10 f0       	mov    $0xf01049e0,%eax
f0104455:	66 a3 e0 32 22 f0    	mov    %ax,0xf02232e0
f010445b:	66 c7 05 e2 32 22 f0 	movw   $0x8,0xf02232e2
f0104462:	08 00 
f0104464:	c6 05 e4 32 22 f0 00 	movb   $0x0,0xf02232e4
f010446b:	c6 05 e5 32 22 f0 8f 	movb   $0x8f,0xf02232e5
f0104472:	c1 e8 10             	shr    $0x10,%eax
f0104475:	66 a3 e6 32 22 f0    	mov    %ax,0xf02232e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f010447b:	b8 e6 49 10 f0       	mov    $0xf01049e6,%eax
f0104480:	66 a3 e8 32 22 f0    	mov    %ax,0xf02232e8
f0104486:	66 c7 05 ea 32 22 f0 	movw   $0x8,0xf02232ea
f010448d:	08 00 
f010448f:	c6 05 ec 32 22 f0 00 	movb   $0x0,0xf02232ec
f0104496:	c6 05 ed 32 22 f0 8f 	movb   $0x8f,0xf02232ed
f010449d:	c1 e8 10             	shr    $0x10,%eax
f01044a0:	66 a3 ee 32 22 f0    	mov    %ax,0xf02232ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f01044a6:	b8 ea 49 10 f0       	mov    $0xf01049ea,%eax
f01044ab:	66 a3 f0 32 22 f0    	mov    %ax,0xf02232f0
f01044b1:	66 c7 05 f2 32 22 f0 	movw   $0x8,0xf02232f2
f01044b8:	08 00 
f01044ba:	c6 05 f4 32 22 f0 00 	movb   $0x0,0xf02232f4
f01044c1:	c6 05 f5 32 22 f0 8f 	movb   $0x8f,0xf02232f5
f01044c8:	c1 e8 10             	shr    $0x10,%eax
f01044cb:	66 a3 f6 32 22 f0    	mov    %ax,0xf02232f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01044d1:	b8 f0 49 10 f0       	mov    $0xf01049f0,%eax
f01044d6:	66 a3 f8 32 22 f0    	mov    %ax,0xf02232f8
f01044dc:	66 c7 05 fa 32 22 f0 	movw   $0x8,0xf02232fa
f01044e3:	08 00 
f01044e5:	c6 05 fc 32 22 f0 00 	movb   $0x0,0xf02232fc
f01044ec:	c6 05 fd 32 22 f0 8f 	movb   $0x8f,0xf02232fd
f01044f3:	c1 e8 10             	shr    $0x10,%eax
f01044f6:	66 a3 fe 32 22 f0    	mov    %ax,0xf02232fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01044fc:	b8 f6 49 10 f0       	mov    $0xf01049f6,%eax
f0104501:	66 a3 e0 33 22 f0    	mov    %ax,0xf02233e0
f0104507:	66 c7 05 e2 33 22 f0 	movw   $0x8,0xf02233e2
f010450e:	08 00 
f0104510:	c6 05 e4 33 22 f0 00 	movb   $0x0,0xf02233e4
f0104517:	c6 05 e5 33 22 f0 ee 	movb   $0xee,0xf02233e5
f010451e:	c1 e8 10             	shr    $0x10,%eax
f0104521:	66 a3 e6 33 22 f0    	mov    %ax,0xf02233e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0104527:	e8 1f fc ff ff       	call   f010414b <trap_init_percpu>
}
f010452c:	c9                   	leave  
f010452d:	c3                   	ret    

f010452e <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010452e:	55                   	push   %ebp
f010452f:	89 e5                	mov    %esp,%ebp
f0104531:	53                   	push   %ebx
f0104532:	83 ec 14             	sub    $0x14,%esp
f0104535:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0104538:	8b 03                	mov    (%ebx),%eax
f010453a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010453e:	c7 04 24 47 78 10 f0 	movl   $0xf0107847,(%esp)
f0104545:	e8 e7 fb ff ff       	call   f0104131 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f010454a:	8b 43 04             	mov    0x4(%ebx),%eax
f010454d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104551:	c7 04 24 56 78 10 f0 	movl   $0xf0107856,(%esp)
f0104558:	e8 d4 fb ff ff       	call   f0104131 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010455d:	8b 43 08             	mov    0x8(%ebx),%eax
f0104560:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104564:	c7 04 24 65 78 10 f0 	movl   $0xf0107865,(%esp)
f010456b:	e8 c1 fb ff ff       	call   f0104131 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f0104570:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104573:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104577:	c7 04 24 74 78 10 f0 	movl   $0xf0107874,(%esp)
f010457e:	e8 ae fb ff ff       	call   f0104131 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104583:	8b 43 10             	mov    0x10(%ebx),%eax
f0104586:	89 44 24 04          	mov    %eax,0x4(%esp)
f010458a:	c7 04 24 83 78 10 f0 	movl   $0xf0107883,(%esp)
f0104591:	e8 9b fb ff ff       	call   f0104131 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104596:	8b 43 14             	mov    0x14(%ebx),%eax
f0104599:	89 44 24 04          	mov    %eax,0x4(%esp)
f010459d:	c7 04 24 92 78 10 f0 	movl   $0xf0107892,(%esp)
f01045a4:	e8 88 fb ff ff       	call   f0104131 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f01045a9:	8b 43 18             	mov    0x18(%ebx),%eax
f01045ac:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045b0:	c7 04 24 a1 78 10 f0 	movl   $0xf01078a1,(%esp)
f01045b7:	e8 75 fb ff ff       	call   f0104131 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f01045bc:	8b 43 1c             	mov    0x1c(%ebx),%eax
f01045bf:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045c3:	c7 04 24 b0 78 10 f0 	movl   $0xf01078b0,(%esp)
f01045ca:	e8 62 fb ff ff       	call   f0104131 <cprintf>
}
f01045cf:	83 c4 14             	add    $0x14,%esp
f01045d2:	5b                   	pop    %ebx
f01045d3:	5d                   	pop    %ebp
f01045d4:	c3                   	ret    

f01045d5 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f01045d5:	55                   	push   %ebp
f01045d6:	89 e5                	mov    %esp,%ebp
f01045d8:	56                   	push   %esi
f01045d9:	53                   	push   %ebx
f01045da:	83 ec 10             	sub    $0x10,%esp
f01045dd:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f01045e0:	e8 ce 19 00 00       	call   f0105fb3 <cpunum>
f01045e5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01045e9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01045ed:	c7 04 24 14 79 10 f0 	movl   $0xf0107914,(%esp)
f01045f4:	e8 38 fb ff ff       	call   f0104131 <cprintf>
	print_regs(&tf->tf_regs);
f01045f9:	89 1c 24             	mov    %ebx,(%esp)
f01045fc:	e8 2d ff ff ff       	call   f010452e <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f0104601:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0104605:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104609:	c7 04 24 32 79 10 f0 	movl   $0xf0107932,(%esp)
f0104610:	e8 1c fb ff ff       	call   f0104131 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0104615:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0104619:	89 44 24 04          	mov    %eax,0x4(%esp)
f010461d:	c7 04 24 45 79 10 f0 	movl   $0xf0107945,(%esp)
f0104624:	e8 08 fb ff ff       	call   f0104131 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104629:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010462c:	83 f8 13             	cmp    $0x13,%eax
f010462f:	77 09                	ja     f010463a <print_trapframe+0x65>
		return excnames[trapno];
f0104631:	8b 14 85 00 7c 10 f0 	mov    -0xfef8400(,%eax,4),%edx
f0104638:	eb 1f                	jmp    f0104659 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f010463a:	83 f8 30             	cmp    $0x30,%eax
f010463d:	74 15                	je     f0104654 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f010463f:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0104642:	83 fa 0f             	cmp    $0xf,%edx
f0104645:	ba cb 78 10 f0       	mov    $0xf01078cb,%edx
f010464a:	b9 de 78 10 f0       	mov    $0xf01078de,%ecx
f010464f:	0f 47 d1             	cmova  %ecx,%edx
f0104652:	eb 05                	jmp    f0104659 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104654:	ba bf 78 10 f0       	mov    $0xf01078bf,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104659:	89 54 24 08          	mov    %edx,0x8(%esp)
f010465d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104661:	c7 04 24 58 79 10 f0 	movl   $0xf0107958,(%esp)
f0104668:	e8 c4 fa ff ff       	call   f0104131 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010466d:	3b 1d 60 3a 22 f0    	cmp    0xf0223a60,%ebx
f0104673:	75 19                	jne    f010468e <print_trapframe+0xb9>
f0104675:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104679:	75 13                	jne    f010468e <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010467b:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010467e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104682:	c7 04 24 6a 79 10 f0 	movl   $0xf010796a,(%esp)
f0104689:	e8 a3 fa ff ff       	call   f0104131 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010468e:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104691:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104695:	c7 04 24 79 79 10 f0 	movl   $0xf0107979,(%esp)
f010469c:	e8 90 fa ff ff       	call   f0104131 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f01046a1:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01046a5:	75 51                	jne    f01046f8 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f01046a7:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f01046aa:	89 c2                	mov    %eax,%edx
f01046ac:	83 e2 01             	and    $0x1,%edx
f01046af:	ba ed 78 10 f0       	mov    $0xf01078ed,%edx
f01046b4:	b9 f8 78 10 f0       	mov    $0xf01078f8,%ecx
f01046b9:	0f 45 ca             	cmovne %edx,%ecx
f01046bc:	89 c2                	mov    %eax,%edx
f01046be:	83 e2 02             	and    $0x2,%edx
f01046c1:	ba 04 79 10 f0       	mov    $0xf0107904,%edx
f01046c6:	be 0a 79 10 f0       	mov    $0xf010790a,%esi
f01046cb:	0f 44 d6             	cmove  %esi,%edx
f01046ce:	83 e0 04             	and    $0x4,%eax
f01046d1:	b8 0f 79 10 f0       	mov    $0xf010790f,%eax
f01046d6:	be 5f 7a 10 f0       	mov    $0xf0107a5f,%esi
f01046db:	0f 44 c6             	cmove  %esi,%eax
f01046de:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01046e2:	89 54 24 08          	mov    %edx,0x8(%esp)
f01046e6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046ea:	c7 04 24 87 79 10 f0 	movl   $0xf0107987,(%esp)
f01046f1:	e8 3b fa ff ff       	call   f0104131 <cprintf>
f01046f6:	eb 0c                	jmp    f0104704 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01046f8:	c7 04 24 b2 77 10 f0 	movl   $0xf01077b2,(%esp)
f01046ff:	e8 2d fa ff ff       	call   f0104131 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0104704:	8b 43 30             	mov    0x30(%ebx),%eax
f0104707:	89 44 24 04          	mov    %eax,0x4(%esp)
f010470b:	c7 04 24 96 79 10 f0 	movl   $0xf0107996,(%esp)
f0104712:	e8 1a fa ff ff       	call   f0104131 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0104717:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f010471b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010471f:	c7 04 24 a5 79 10 f0 	movl   $0xf01079a5,(%esp)
f0104726:	e8 06 fa ff ff       	call   f0104131 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f010472b:	8b 43 38             	mov    0x38(%ebx),%eax
f010472e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104732:	c7 04 24 b8 79 10 f0 	movl   $0xf01079b8,(%esp)
f0104739:	e8 f3 f9 ff ff       	call   f0104131 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010473e:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0104742:	74 27                	je     f010476b <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0104744:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104747:	89 44 24 04          	mov    %eax,0x4(%esp)
f010474b:	c7 04 24 c7 79 10 f0 	movl   $0xf01079c7,(%esp)
f0104752:	e8 da f9 ff ff       	call   f0104131 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104757:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010475b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010475f:	c7 04 24 d6 79 10 f0 	movl   $0xf01079d6,(%esp)
f0104766:	e8 c6 f9 ff ff       	call   f0104131 <cprintf>
	}
}
f010476b:	83 c4 10             	add    $0x10,%esp
f010476e:	5b                   	pop    %ebx
f010476f:	5e                   	pop    %esi
f0104770:	5d                   	pop    %ebp
f0104771:	c3                   	ret    

f0104772 <break_point_handler>:
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}
void
break_point_handler(struct Trapframe *tf)
{
f0104772:	55                   	push   %ebp
f0104773:	89 e5                	mov    %esp,%ebp
f0104775:	83 ec 18             	sub    $0x18,%esp
	monitor(tf);
f0104778:	8b 45 08             	mov    0x8(%ebp),%eax
f010477b:	89 04 24             	mov    %eax,(%esp)
f010477e:	e8 24 c2 ff ff       	call   f01009a7 <monitor>
}
f0104783:	c9                   	leave  
f0104784:	c3                   	ret    

f0104785 <trap>:



void
trap(struct Trapframe *tf)
{
f0104785:	55                   	push   %ebp
f0104786:	89 e5                	mov    %esp,%ebp
f0104788:	57                   	push   %edi
f0104789:	56                   	push   %esi
f010478a:	83 ec 10             	sub    $0x10,%esp
f010478d:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f0104790:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f0104791:	83 3d 80 3e 22 f0 00 	cmpl   $0x0,0xf0223e80
f0104798:	74 01                	je     f010479b <trap+0x16>
		asm volatile("hlt");
f010479a:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f010479b:	9c                   	pushf  
f010479c:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f010479d:	f6 c4 02             	test   $0x2,%ah
f01047a0:	74 24                	je     f01047c6 <trap+0x41>
f01047a2:	c7 44 24 0c e9 79 10 	movl   $0xf01079e9,0xc(%esp)
f01047a9:	f0 
f01047aa:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f01047b1:	f0 
f01047b2:	c7 44 24 04 13 01 00 	movl   $0x113,0x4(%esp)
f01047b9:	00 
f01047ba:	c7 04 24 02 7a 10 f0 	movl   $0xf0107a02,(%esp)
f01047c1:	e8 7a b8 ff ff       	call   f0100040 <_panic>
//<<<<<< HEAD
   // panic("trap called!");
	cprintf("Incoming TRAP frame at %p\n", tf);
f01047c6:	89 74 24 04          	mov    %esi,0x4(%esp)
f01047ca:	c7 04 24 0e 7a 10 f0 	movl   $0xf0107a0e,(%esp)
f01047d1:	e8 5b f9 ff ff       	call   f0104131 <cprintf>
//=======
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	if ((tf->tf_cs & 3) == 3) {
f01047d6:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01047da:	83 e0 03             	and    $0x3,%eax
f01047dd:	66 83 f8 03          	cmp    $0x3,%ax
f01047e1:	0f 85 9b 00 00 00    	jne    f0104882 <trap+0xfd>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		assert(curenv);
f01047e7:	e8 c7 17 00 00       	call   f0105fb3 <cpunum>
f01047ec:	6b c0 74             	imul   $0x74,%eax,%eax
f01047ef:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f01047f6:	75 24                	jne    f010481c <trap+0x97>
f01047f8:	c7 44 24 0c 29 7a 10 	movl   $0xf0107a29,0xc(%esp)
f01047ff:	f0 
f0104800:	c7 44 24 08 ac 6c 10 	movl   $0xf0106cac,0x8(%esp)
f0104807:	f0 
f0104808:	c7 44 24 04 1f 01 00 	movl   $0x11f,0x4(%esp)
f010480f:	00 
f0104810:	c7 04 24 02 7a 10 f0 	movl   $0xf0107a02,(%esp)
f0104817:	e8 24 b8 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f010481c:	e8 92 17 00 00       	call   f0105fb3 <cpunum>
f0104821:	6b c0 74             	imul   $0x74,%eax,%eax
f0104824:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010482a:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f010482e:	75 2d                	jne    f010485d <trap+0xd8>
			env_free(curenv);
f0104830:	e8 7e 17 00 00       	call   f0105fb3 <cpunum>
f0104835:	6b c0 74             	imul   $0x74,%eax,%eax
f0104838:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010483e:	89 04 24             	mov    %eax,(%esp)
f0104841:	e8 36 f4 ff ff       	call   f0103c7c <env_free>
			curenv = NULL;
f0104846:	e8 68 17 00 00       	call   f0105fb3 <cpunum>
f010484b:	6b c0 74             	imul   $0x74,%eax,%eax
f010484e:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f0104855:	00 00 00 
			sched_yield();
f0104858:	e8 b8 01 00 00       	call   f0104a15 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f010485d:	e8 51 17 00 00       	call   f0105fb3 <cpunum>
f0104862:	6b c0 74             	imul   $0x74,%eax,%eax
f0104865:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010486b:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104870:	89 c7                	mov    %eax,%edi
f0104872:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104874:	e8 3a 17 00 00       	call   f0105fb3 <cpunum>
f0104879:	6b c0 74             	imul   $0x74,%eax,%eax
f010487c:	8b b0 28 40 22 f0    	mov    -0xfddbfd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0104882:	89 35 60 3a 22 f0    	mov    %esi,0xf0223a60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f0104888:	89 34 24             	mov    %esi,(%esp)
f010488b:	e8 45 fd ff ff       	call   f01045d5 <print_trapframe>
//=======

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f0104890:	83 7e 28 27          	cmpl   $0x27,0x28(%esi)
f0104894:	75 16                	jne    f01048ac <trap+0x127>
		cprintf("Spurious interrupt on irq 7\n");
f0104896:	c7 04 24 30 7a 10 f0 	movl   $0xf0107a30,(%esp)
f010489d:	e8 8f f8 ff ff       	call   f0104131 <cprintf>
		print_trapframe(tf);
f01048a2:	89 34 24             	mov    %esi,(%esp)
f01048a5:	e8 2b fd ff ff       	call   f01045d5 <print_trapframe>
f01048aa:	eb 39                	jmp    f01048e5 <trap+0x160>
	// LAB 4: Your code here.

//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f01048ac:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f01048b1:	75 1c                	jne    f01048cf <trap+0x14a>
		panic("unhandled trap in kernel");
f01048b3:	c7 44 24 08 4d 7a 10 	movl   $0xf0107a4d,0x8(%esp)
f01048ba:	f0 
f01048bb:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
f01048c2:	00 
f01048c3:	c7 04 24 02 7a 10 f0 	movl   $0xf0107a02,(%esp)
f01048ca:	e8 71 b7 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f01048cf:	e8 df 16 00 00       	call   f0105fb3 <cpunum>
f01048d4:	6b c0 74             	imul   $0x74,%eax,%eax
f01048d7:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01048dd:	89 04 24             	mov    %eax,(%esp)
f01048e0:	e8 9c f5 ff ff       	call   f0103e81 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f01048e5:	e8 c9 16 00 00       	call   f0105fb3 <cpunum>
f01048ea:	6b c0 74             	imul   $0x74,%eax,%eax
f01048ed:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f01048f4:	74 2a                	je     f0104920 <trap+0x19b>
f01048f6:	e8 b8 16 00 00       	call   f0105fb3 <cpunum>
f01048fb:	6b c0 74             	imul   $0x74,%eax,%eax
f01048fe:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104904:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104908:	75 16                	jne    f0104920 <trap+0x19b>
		env_run(curenv);
f010490a:	e8 a4 16 00 00       	call   f0105fb3 <cpunum>
f010490f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104912:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104918:	89 04 24             	mov    %eax,(%esp)
f010491b:	e8 02 f6 ff ff       	call   f0103f22 <env_run>
	else
		sched_yield();
f0104920:	e8 f0 00 00 00       	call   f0104a15 <sched_yield>

f0104925 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104925:	55                   	push   %ebp
f0104926:	89 e5                	mov    %esp,%ebp
f0104928:	56                   	push   %esi
f0104929:	53                   	push   %ebx
f010492a:	83 ec 10             	sub    $0x10,%esp
f010492d:	8b 45 08             	mov    0x8(%ebp),%eax

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0104930:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0)
f0104933:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0104937:	75 1c                	jne    f0104955 <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f0104939:	c7 44 24 08 66 7a 10 	movl   $0xf0107a66,0x8(%esp)
f0104940:	f0 
f0104941:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
f0104948:	00 
f0104949:	c7 04 24 02 7a 10 f0 	movl   $0xf0107a02,(%esp)
f0104950:	e8 eb b6 ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104955:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104958:	e8 56 16 00 00       	call   f0105fb3 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f010495d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104961:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104965:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104968:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010496e:	8b 40 48             	mov    0x48(%eax),%eax
f0104971:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104975:	c7 04 24 c4 7b 10 f0 	movl   $0xf0107bc4,(%esp)
f010497c:	e8 b0 f7 ff ff       	call   f0104131 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f0104981:	e8 2d 16 00 00       	call   f0105fb3 <cpunum>
f0104986:	6b c0 74             	imul   $0x74,%eax,%eax
f0104989:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010498f:	89 04 24             	mov    %eax,(%esp)
f0104992:	e8 ea f4 ff ff       	call   f0103e81 <env_destroy>
}
f0104997:	83 c4 10             	add    $0x10,%esp
f010499a:	5b                   	pop    %ebx
f010499b:	5e                   	pop    %esi
f010499c:	5d                   	pop    %ebp
f010499d:	c3                   	ret    

f010499e <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f010499e:	6a 00                	push   $0x0
f01049a0:	6a 00                	push   $0x0
f01049a2:	eb 58                	jmp    f01049fc <_alltraps>

f01049a4 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01049a4:	6a 00                	push   $0x0
f01049a6:	6a 02                	push   $0x2
f01049a8:	eb 52                	jmp    f01049fc <_alltraps>

f01049aa <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01049aa:	6a 00                	push   $0x0
f01049ac:	6a 03                	push   $0x3
f01049ae:	eb 4c                	jmp    f01049fc <_alltraps>

f01049b0 <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01049b0:	6a 00                	push   $0x0
f01049b2:	6a 04                	push   $0x4
f01049b4:	eb 46                	jmp    f01049fc <_alltraps>

f01049b6 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01049b6:	6a 00                	push   $0x0
f01049b8:	6a 05                	push   $0x5
f01049ba:	eb 40                	jmp    f01049fc <_alltraps>

f01049bc <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01049bc:	6a 00                	push   $0x0
f01049be:	6a 06                	push   $0x6
f01049c0:	eb 3a                	jmp    f01049fc <_alltraps>

f01049c2 <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01049c2:	6a 00                	push   $0x0
f01049c4:	6a 07                	push   $0x7
f01049c6:	eb 34                	jmp    f01049fc <_alltraps>

f01049c8 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01049c8:	6a 08                	push   $0x8
f01049ca:	eb 30                	jmp    f01049fc <_alltraps>

f01049cc <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01049cc:	6a 0a                	push   $0xa
f01049ce:	eb 2c                	jmp    f01049fc <_alltraps>

f01049d0 <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01049d0:	6a 0b                	push   $0xb
f01049d2:	eb 28                	jmp    f01049fc <_alltraps>

f01049d4 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f01049d4:	6a 0c                	push   $0xc
f01049d6:	eb 24                	jmp    f01049fc <_alltraps>

f01049d8 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01049d8:	6a 0d                	push   $0xd
f01049da:	eb 20                	jmp    f01049fc <_alltraps>

f01049dc <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01049dc:	6a 0e                	push   $0xe
f01049de:	eb 1c                	jmp    f01049fc <_alltraps>

f01049e0 <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01049e0:	6a 00                	push   $0x0
f01049e2:	6a 10                	push   $0x10
f01049e4:	eb 16                	jmp    f01049fc <_alltraps>

f01049e6 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f01049e6:	6a 11                	push   $0x11
f01049e8:	eb 12                	jmp    f01049fc <_alltraps>

f01049ea <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f01049ea:	6a 00                	push   $0x0
f01049ec:	6a 12                	push   $0x12
f01049ee:	eb 0c                	jmp    f01049fc <_alltraps>

f01049f0 <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f01049f0:	6a 00                	push   $0x0
f01049f2:	6a 13                	push   $0x13
f01049f4:	eb 06                	jmp    f01049fc <_alltraps>

f01049f6 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f01049f6:	6a 00                	push   $0x0
f01049f8:	6a 30                	push   $0x30
f01049fa:	eb 00                	jmp    f01049fc <_alltraps>

f01049fc <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
pushw $0
f01049fc:	66 6a 00             	pushw  $0x0
pushw %ds
f01049ff:	66 1e                	pushw  %ds
pushw $0
f0104a01:	66 6a 00             	pushw  $0x0
pushw %es
f0104a04:	66 06                	pushw  %es
pushal
f0104a06:	60                   	pusha  
pushl %esp
f0104a07:	54                   	push   %esp
movw $(GD_KD),%ax
f0104a08:	66 b8 10 00          	mov    $0x10,%ax
movw %ax,%ds
f0104a0c:	8e d8                	mov    %eax,%ds
movw %ax,%es
f0104a0e:	8e c0                	mov    %eax,%es
call trap
f0104a10:	e8 70 fd ff ff       	call   f0104785 <trap>

f0104a15 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104a15:	55                   	push   %ebp
f0104a16:	89 e5                	mov    %esp,%ebp
f0104a18:	53                   	push   %ebx
f0104a19:	83 ec 14             	sub    $0x14,%esp

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a1c:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
f0104a22:	89 d8                	mov    %ebx,%eax
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104a24:	ba 00 00 00 00       	mov    $0x0,%edx
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a29:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104a2d:	74 0b                	je     f0104a3a <sched_yield+0x25>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104a2f:	8b 48 54             	mov    0x54(%eax),%ecx
f0104a32:	83 e9 02             	sub    $0x2,%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a35:	83 f9 01             	cmp    $0x1,%ecx
f0104a38:	76 10                	jbe    f0104a4a <sched_yield+0x35>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104a3a:	83 c2 01             	add    $0x1,%edx
f0104a3d:	83 c0 7c             	add    $0x7c,%eax
f0104a40:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104a46:	75 e1                	jne    f0104a29 <sched_yield+0x14>
f0104a48:	eb 08                	jmp    f0104a52 <sched_yield+0x3d>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104a4a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104a50:	75 1a                	jne    f0104a6c <sched_yield+0x57>
		cprintf("No more runnable environments!\n");
f0104a52:	c7 04 24 50 7c 10 f0 	movl   $0xf0107c50,(%esp)
f0104a59:	e8 d3 f6 ff ff       	call   f0104131 <cprintf>
		while (1)
			monitor(NULL);
f0104a5e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104a65:	e8 3d bf ff ff       	call   f01009a7 <monitor>
f0104a6a:	eb f2                	jmp    f0104a5e <sched_yield+0x49>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104a6c:	e8 42 15 00 00       	call   f0105fb3 <cpunum>
f0104a71:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104a74:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104a76:	8b 43 54             	mov    0x54(%ebx),%eax
f0104a79:	83 e8 02             	sub    $0x2,%eax
f0104a7c:	83 f8 01             	cmp    $0x1,%eax
f0104a7f:	76 25                	jbe    f0104aa6 <sched_yield+0x91>
		panic("CPU %d: No idle environment!", cpunum());
f0104a81:	e8 2d 15 00 00       	call   f0105fb3 <cpunum>
f0104a86:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104a8a:	c7 44 24 08 70 7c 10 	movl   $0xf0107c70,0x8(%esp)
f0104a91:	f0 
f0104a92:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
f0104a99:	00 
f0104a9a:	c7 04 24 8d 7c 10 f0 	movl   $0xf0107c8d,(%esp)
f0104aa1:	e8 9a b5 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104aa6:	89 1c 24             	mov    %ebx,(%esp)
f0104aa9:	e8 74 f4 ff ff       	call   f0103f22 <env_run>
f0104aae:	66 90                	xchg   %ax,%ax

f0104ab0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104ab0:	55                   	push   %ebp
f0104ab1:	89 e5                	mov    %esp,%ebp
f0104ab3:	53                   	push   %ebx
f0104ab4:	83 ec 24             	sub    $0x24,%esp
f0104ab7:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
		
	int32_t r=0;		
	switch(syscallno){
f0104aba:	83 f8 01             	cmp    $0x1,%eax
f0104abd:	74 66                	je     f0104b25 <syscall+0x75>
f0104abf:	83 f8 01             	cmp    $0x1,%eax
f0104ac2:	72 11                	jb     f0104ad5 <syscall+0x25>
f0104ac4:	83 f8 02             	cmp    $0x2,%eax
f0104ac7:	74 66                	je     f0104b2f <syscall+0x7f>
f0104ac9:	83 f8 03             	cmp    $0x3,%eax
f0104acc:	74 78                	je     f0104b46 <syscall+0x96>
f0104ace:	66 90                	xchg   %ax,%ax
f0104ad0:	e9 ff 00 00 00       	jmp    f0104bd4 <syscall+0x124>
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.

	// LAB 3: Your code here.
	user_mem_assert(curenv, s, len, 0);
f0104ad5:	e8 d9 14 00 00       	call   f0105fb3 <cpunum>
f0104ada:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104ae1:	00 
f0104ae2:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104ae5:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104ae9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104aec:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104af0:	6b c0 74             	imul   $0x74,%eax,%eax
f0104af3:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104af9:	89 04 24             	mov    %eax,(%esp)
f0104afc:	e8 7b eb ff ff       	call   f010367c <user_mem_assert>
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104b01:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b04:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104b08:	8b 45 10             	mov    0x10(%ebp),%eax
f0104b0b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b0f:	c7 04 24 9a 7c 10 f0 	movl   $0xf0107c9a,(%esp)
f0104b16:	e8 16 f6 ff ff       	call   f0104131 <cprintf>
{
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
		
	int32_t r=0;		
f0104b1b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104b20:	e9 b4 00 00 00       	jmp    f0104bd9 <syscall+0x129>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104b25:	e8 6b bb ff ff       	call   f0100695 <cons_getc>
	int32_t r=0;		
	switch(syscallno){
	case SYS_cputs:sys_cputs((const char*)a1, (size_t)a2);
			break;
        case SYS_cgetc: r=sys_cgetc();
			break;
f0104b2a:	e9 aa 00 00 00       	jmp    f0104bd9 <syscall+0x129>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104b2f:	90                   	nop
f0104b30:	e8 7e 14 00 00       	call   f0105fb3 <cpunum>
f0104b35:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b38:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104b3e:	8b 40 48             	mov    0x48(%eax),%eax
	case SYS_cputs:sys_cputs((const char*)a1, (size_t)a2);
			break;
        case SYS_cgetc: r=sys_cgetc();
			break;
	case SYS_getenvid: r=sys_getenvid();
			break;
f0104b41:	e9 93 00 00 00       	jmp    f0104bd9 <syscall+0x129>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104b46:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104b4d:	00 
f0104b4e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0104b51:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b55:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b58:	89 04 24             	mov    %eax,(%esp)
f0104b5b:	e8 24 ec ff ff       	call   f0103784 <envid2env>
f0104b60:	85 c0                	test   %eax,%eax
f0104b62:	78 75                	js     f0104bd9 <syscall+0x129>
		return r;
	if (e == curenv)
f0104b64:	e8 4a 14 00 00       	call   f0105fb3 <cpunum>
f0104b69:	8b 55 f4             	mov    -0xc(%ebp),%edx
f0104b6c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b6f:	39 90 28 40 22 f0    	cmp    %edx,-0xfddbfd8(%eax)
f0104b75:	75 23                	jne    f0104b9a <syscall+0xea>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f0104b77:	e8 37 14 00 00       	call   f0105fb3 <cpunum>
f0104b7c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b7f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104b85:	8b 40 48             	mov    0x48(%eax),%eax
f0104b88:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b8c:	c7 04 24 9f 7c 10 f0 	movl   $0xf0107c9f,(%esp)
f0104b93:	e8 99 f5 ff ff       	call   f0104131 <cprintf>
f0104b98:	eb 28                	jmp    f0104bc2 <syscall+0x112>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f0104b9a:	8b 5a 48             	mov    0x48(%edx),%ebx
f0104b9d:	e8 11 14 00 00       	call   f0105fb3 <cpunum>
f0104ba2:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0104ba6:	6b c0 74             	imul   $0x74,%eax,%eax
f0104ba9:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104baf:	8b 40 48             	mov    0x48(%eax),%eax
f0104bb2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bb6:	c7 04 24 ba 7c 10 f0 	movl   $0xf0107cba,(%esp)
f0104bbd:	e8 6f f5 ff ff       	call   f0104131 <cprintf>
	env_destroy(e);
f0104bc2:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104bc5:	89 04 24             	mov    %eax,(%esp)
f0104bc8:	e8 b4 f2 ff ff       	call   f0103e81 <env_destroy>
	return 0;
f0104bcd:	b8 00 00 00 00       	mov    $0x0,%eax
        case SYS_cgetc: r=sys_cgetc();
			break;
	case SYS_getenvid: r=sys_getenvid();
			break;
	case SYS_env_destroy: r=sys_env_destroy((envid_t)a1);
			break;
f0104bd2:	eb 05                	jmp    f0104bd9 <syscall+0x129>
	default:
		r=-E_INVAL;
f0104bd4:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}

	return r;
	
	panic("syscall not implemented");
}
f0104bd9:	83 c4 24             	add    $0x24,%esp
f0104bdc:	5b                   	pop    %ebx
f0104bdd:	5d                   	pop    %ebp
f0104bde:	c3                   	ret    
f0104bdf:	90                   	nop

f0104be0 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104be0:	55                   	push   %ebp
f0104be1:	89 e5                	mov    %esp,%ebp
f0104be3:	57                   	push   %edi
f0104be4:	56                   	push   %esi
f0104be5:	53                   	push   %ebx
f0104be6:	83 ec 14             	sub    $0x14,%esp
f0104be9:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104bec:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0104bef:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104bf2:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104bf5:	8b 1a                	mov    (%edx),%ebx
f0104bf7:	8b 01                	mov    (%ecx),%eax
f0104bf9:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f0104bfc:	39 c3                	cmp    %eax,%ebx
f0104bfe:	0f 8f 9a 00 00 00    	jg     f0104c9e <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104c04:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104c0b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0104c0e:	01 d8                	add    %ebx,%eax
f0104c10:	89 c7                	mov    %eax,%edi
f0104c12:	c1 ef 1f             	shr    $0x1f,%edi
f0104c15:	01 c7                	add    %eax,%edi
f0104c17:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104c19:	39 df                	cmp    %ebx,%edi
f0104c1b:	0f 8c c4 00 00 00    	jl     f0104ce5 <stab_binsearch+0x105>
f0104c21:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104c24:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104c27:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0104c2a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0104c2e:	39 f0                	cmp    %esi,%eax
f0104c30:	0f 84 b4 00 00 00    	je     f0104cea <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104c36:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104c38:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104c3b:	39 d8                	cmp    %ebx,%eax
f0104c3d:	0f 8c a2 00 00 00    	jl     f0104ce5 <stab_binsearch+0x105>
f0104c43:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104c47:	83 ea 0c             	sub    $0xc,%edx
f0104c4a:	39 f1                	cmp    %esi,%ecx
f0104c4c:	75 ea                	jne    f0104c38 <stab_binsearch+0x58>
f0104c4e:	e9 99 00 00 00       	jmp    f0104cec <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104c53:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104c56:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104c58:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104c5b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104c62:	eb 2b                	jmp    f0104c8f <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0104c64:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104c67:	76 14                	jbe    f0104c7d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0104c69:	83 e8 01             	sub    $0x1,%eax
f0104c6c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0104c6f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104c72:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104c74:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104c7b:	eb 12                	jmp    f0104c8f <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0104c7d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104c80:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0104c82:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0104c86:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104c88:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0104c8f:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0104c92:	0f 8e 73 ff ff ff    	jle    f0104c0b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0104c98:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0104c9c:	75 0f                	jne    f0104cad <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0104c9e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ca1:	8b 00                	mov    (%eax),%eax
f0104ca3:	83 e8 01             	sub    $0x1,%eax
f0104ca6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104ca9:	89 06                	mov    %eax,(%esi)
f0104cab:	eb 57                	jmp    f0104d04 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104cad:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104cb0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0104cb2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104cb5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104cb7:	39 c8                	cmp    %ecx,%eax
f0104cb9:	7e 23                	jle    f0104cde <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104cbb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104cbe:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104cc1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104cc4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104cc8:	39 f3                	cmp    %esi,%ebx
f0104cca:	74 12                	je     f0104cde <stab_binsearch+0xfe>
		     l--)
f0104ccc:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104ccf:	39 c8                	cmp    %ecx,%eax
f0104cd1:	7e 0b                	jle    f0104cde <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104cd3:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104cd7:	83 ea 0c             	sub    $0xc,%edx
f0104cda:	39 f3                	cmp    %esi,%ebx
f0104cdc:	75 ee                	jne    f0104ccc <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0104cde:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104ce1:	89 06                	mov    %eax,(%esi)
f0104ce3:	eb 1f                	jmp    f0104d04 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104ce5:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104ce8:	eb a5                	jmp    f0104c8f <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104cea:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0104cec:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104cef:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104cf2:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104cf6:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104cf9:	0f 82 54 ff ff ff    	jb     f0104c53 <stab_binsearch+0x73>
f0104cff:	e9 60 ff ff ff       	jmp    f0104c64 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104d04:	83 c4 14             	add    $0x14,%esp
f0104d07:	5b                   	pop    %ebx
f0104d08:	5e                   	pop    %esi
f0104d09:	5f                   	pop    %edi
f0104d0a:	5d                   	pop    %ebp
f0104d0b:	c3                   	ret    

f0104d0c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0104d0c:	55                   	push   %ebp
f0104d0d:	89 e5                	mov    %esp,%ebp
f0104d0f:	57                   	push   %edi
f0104d10:	56                   	push   %esi
f0104d11:	53                   	push   %ebx
f0104d12:	83 ec 3c             	sub    $0x3c,%esp
f0104d15:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104d18:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0104d1b:	c7 06 d2 7c 10 f0    	movl   $0xf0107cd2,(%esi)
	info->eip_line = 0;
f0104d21:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104d28:	c7 46 08 d2 7c 10 f0 	movl   $0xf0107cd2,0x8(%esi)
	info->eip_fn_namelen = 9;
f0104d2f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104d36:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104d39:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104d40:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104d46:	0f 87 ca 00 00 00    	ja     f0104e16 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
f0104d4c:	e8 62 12 00 00       	call   f0105fb3 <cpunum>
f0104d51:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104d58:	00 
f0104d59:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0104d60:	00 
f0104d61:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0104d68:	00 
f0104d69:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d6c:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104d72:	89 04 24             	mov    %eax,(%esp)
f0104d75:	e8 47 e8 ff ff       	call   f01035c1 <user_mem_check>
f0104d7a:	85 c0                	test   %eax,%eax
f0104d7c:	0f 88 12 02 00 00    	js     f0104f94 <debuginfo_eip+0x288>
		{
		    return -1;
		}
		stabs = usd->stabs;
f0104d82:	a1 00 00 20 00       	mov    0x200000,%eax
f0104d87:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104d8a:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0104d90:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0104d96:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0104d99:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0104d9e:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
f0104da1:	e8 0d 12 00 00       	call   f0105fb3 <cpunum>
f0104da6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104dad:	00 
f0104dae:	89 da                	mov    %ebx,%edx
f0104db0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104db3:	29 ca                	sub    %ecx,%edx
f0104db5:	c1 fa 02             	sar    $0x2,%edx
f0104db8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0104dbe:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104dc2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104dc6:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dc9:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104dcf:	89 04 24             	mov    %eax,(%esp)
f0104dd2:	e8 ea e7 ff ff       	call   f01035c1 <user_mem_check>
f0104dd7:	85 c0                	test   %eax,%eax
f0104dd9:	0f 88 bc 01 00 00    	js     f0104f9b <debuginfo_eip+0x28f>
f0104ddf:	e8 cf 11 00 00       	call   f0105fb3 <cpunum>
f0104de4:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104deb:	00 
f0104dec:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104def:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0104df2:	29 ca                	sub    %ecx,%edx
f0104df4:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104df8:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104dfc:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dff:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104e05:	89 04 24             	mov    %eax,(%esp)
f0104e08:	e8 b4 e7 ff ff       	call   f01035c1 <user_mem_check>
f0104e0d:	85 c0                	test   %eax,%eax
f0104e0f:	79 1f                	jns    f0104e30 <debuginfo_eip+0x124>
f0104e11:	e9 8c 01 00 00       	jmp    f0104fa2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0104e16:	c7 45 cc ab 57 11 f0 	movl   $0xf01157ab,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0104e1d:	c7 45 d0 61 23 11 f0 	movl   $0xf0112361,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0104e24:	bb 60 23 11 f0       	mov    $0xf0112360,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0104e29:	c7 45 d4 b4 81 10 f0 	movl   $0xf01081b4,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0104e30:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0104e33:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0104e36:	0f 83 6d 01 00 00    	jae    f0104fa9 <debuginfo_eip+0x29d>
f0104e3c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0104e40:	0f 85 6a 01 00 00    	jne    f0104fb0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0104e46:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0104e4d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0104e50:	c1 fb 02             	sar    $0x2,%ebx
f0104e53:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0104e59:	83 e8 01             	sub    $0x1,%eax
f0104e5c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0104e5f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104e63:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0104e6a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104e6d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104e70:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0104e73:	89 d8                	mov    %ebx,%eax
f0104e75:	e8 66 fd ff ff       	call   f0104be0 <stab_binsearch>
	if (lfile == 0)
f0104e7a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104e7d:	85 c0                	test   %eax,%eax
f0104e7f:	0f 84 32 01 00 00    	je     f0104fb7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0104e85:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0104e88:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104e8b:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0104e8e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104e92:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0104e99:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0104e9c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0104e9f:	89 d8                	mov    %ebx,%eax
f0104ea1:	e8 3a fd ff ff       	call   f0104be0 <stab_binsearch>

	if (lfun <= rfun) {
f0104ea6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0104ea9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0104eac:	7f 23                	jg     f0104ed1 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0104eae:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104eb1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104eb4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0104eb7:	8b 10                	mov    (%eax),%edx
f0104eb9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0104ebc:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0104ebf:	39 ca                	cmp    %ecx,%edx
f0104ec1:	73 06                	jae    f0104ec9 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0104ec3:	03 55 d0             	add    -0x30(%ebp),%edx
f0104ec6:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0104ec9:	8b 40 08             	mov    0x8(%eax),%eax
f0104ecc:	89 46 10             	mov    %eax,0x10(%esi)
f0104ecf:	eb 06                	jmp    f0104ed7 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0104ed1:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0104ed4:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0104ed7:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104ede:	00 
f0104edf:	8b 46 08             	mov    0x8(%esi),%eax
f0104ee2:	89 04 24             	mov    %eax,(%esp)
f0104ee5:	e8 05 0a 00 00       	call   f01058ef <strfind>
f0104eea:	2b 46 08             	sub    0x8(%esi),%eax
f0104eed:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104ef0:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104ef3:	39 fb                	cmp    %edi,%ebx
f0104ef5:	7c 5d                	jl     f0104f54 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104ef7:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104efa:	c1 e0 02             	shl    $0x2,%eax
f0104efd:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104f00:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104f03:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0104f06:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0104f0a:	80 fa 84             	cmp    $0x84,%dl
f0104f0d:	74 2d                	je     f0104f3c <debuginfo_eip+0x230>
f0104f0f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0104f13:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0104f16:	eb 15                	jmp    f0104f2d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0104f18:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104f1b:	39 fb                	cmp    %edi,%ebx
f0104f1d:	7c 35                	jl     f0104f54 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104f1f:	89 c1                	mov    %eax,%ecx
f0104f21:	83 e8 0c             	sub    $0xc,%eax
f0104f24:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0104f28:	80 fa 84             	cmp    $0x84,%dl
f0104f2b:	74 0f                	je     f0104f3c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0104f2d:	80 fa 64             	cmp    $0x64,%dl
f0104f30:	75 e6                	jne    f0104f18 <debuginfo_eip+0x20c>
f0104f32:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0104f36:	74 e0                	je     f0104f18 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0104f38:	39 df                	cmp    %ebx,%edi
f0104f3a:	7f 18                	jg     f0104f54 <debuginfo_eip+0x248>
f0104f3c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104f3f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104f42:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0104f45:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104f48:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0104f4b:	39 d0                	cmp    %edx,%eax
f0104f4d:	73 05                	jae    f0104f54 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0104f4f:	03 45 d0             	add    -0x30(%ebp),%eax
f0104f52:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104f54:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104f57:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104f5a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104f5f:	39 ca                	cmp    %ecx,%edx
f0104f61:	7d 75                	jge    f0104fd8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0104f63:	8d 42 01             	lea    0x1(%edx),%eax
f0104f66:	39 c1                	cmp    %eax,%ecx
f0104f68:	7e 54                	jle    f0104fbe <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104f6a:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104f6d:	c1 e2 02             	shl    $0x2,%edx
f0104f70:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104f73:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0104f78:	75 4b                	jne    f0104fc5 <debuginfo_eip+0x2b9>
f0104f7a:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0104f7e:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0104f82:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0104f85:	39 c1                	cmp    %eax,%ecx
f0104f87:	7e 43                	jle    f0104fcc <debuginfo_eip+0x2c0>
f0104f89:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104f8c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0104f90:	74 ec                	je     f0104f7e <debuginfo_eip+0x272>
f0104f92:	eb 3f                	jmp    f0104fd3 <debuginfo_eip+0x2c7>
		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
		{
		    return -1;
f0104f94:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104f99:	eb 3d                	jmp    f0104fd8 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
		 {
		    return -1;
f0104f9b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fa0:	eb 36                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
f0104fa2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fa7:	eb 2f                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0104fa9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fae:	eb 28                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
f0104fb0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fb5:	eb 21                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0104fb7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fbc:	eb 1a                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104fbe:	b8 00 00 00 00       	mov    $0x0,%eax
f0104fc3:	eb 13                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
f0104fc5:	b8 00 00 00 00       	mov    $0x0,%eax
f0104fca:	eb 0c                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
f0104fcc:	b8 00 00 00 00       	mov    $0x0,%eax
f0104fd1:	eb 05                	jmp    f0104fd8 <debuginfo_eip+0x2cc>
f0104fd3:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0104fd8:	83 c4 3c             	add    $0x3c,%esp
f0104fdb:	5b                   	pop    %ebx
f0104fdc:	5e                   	pop    %esi
f0104fdd:	5f                   	pop    %edi
f0104fde:	5d                   	pop    %ebp
f0104fdf:	c3                   	ret    

f0104fe0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0104fe0:	55                   	push   %ebp
f0104fe1:	89 e5                	mov    %esp,%ebp
f0104fe3:	57                   	push   %edi
f0104fe4:	56                   	push   %esi
f0104fe5:	53                   	push   %ebx
f0104fe6:	83 ec 3c             	sub    $0x3c,%esp
f0104fe9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0104fec:	89 d7                	mov    %edx,%edi
f0104fee:	8b 45 08             	mov    0x8(%ebp),%eax
f0104ff1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0104ff4:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104ff7:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f0104ffa:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f0104ffd:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105002:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105005:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105008:	39 f1                	cmp    %esi,%ecx
f010500a:	72 14                	jb     f0105020 <printnum+0x40>
f010500c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010500f:	76 0f                	jbe    f0105020 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105011:	8b 45 14             	mov    0x14(%ebp),%eax
f0105014:	8d 70 ff             	lea    -0x1(%eax),%esi
f0105017:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010501a:	85 f6                	test   %esi,%esi
f010501c:	7f 60                	jg     f010507e <printnum+0x9e>
f010501e:	eb 72                	jmp    f0105092 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105020:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105023:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105027:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010502a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010502d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105031:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105035:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105039:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010503d:	89 c3                	mov    %eax,%ebx
f010503f:	89 d6                	mov    %edx,%esi
f0105041:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105044:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105047:	89 54 24 08          	mov    %edx,0x8(%esp)
f010504b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010504f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105052:	89 04 24             	mov    %eax,(%esp)
f0105055:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105058:	89 44 24 04          	mov    %eax,0x4(%esp)
f010505c:	e8 bf 13 00 00       	call   f0106420 <__udivdi3>
f0105061:	89 d9                	mov    %ebx,%ecx
f0105063:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105067:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010506b:	89 04 24             	mov    %eax,(%esp)
f010506e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105072:	89 fa                	mov    %edi,%edx
f0105074:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105077:	e8 64 ff ff ff       	call   f0104fe0 <printnum>
f010507c:	eb 14                	jmp    f0105092 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f010507e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105082:	8b 45 18             	mov    0x18(%ebp),%eax
f0105085:	89 04 24             	mov    %eax,(%esp)
f0105088:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f010508a:	83 ee 01             	sub    $0x1,%esi
f010508d:	75 ef                	jne    f010507e <printnum+0x9e>
f010508f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0105092:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105096:	8b 7c 24 04          	mov    0x4(%esp),%edi
f010509a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010509d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01050a0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01050a4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01050a8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050ab:	89 04 24             	mov    %eax,(%esp)
f01050ae:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01050b1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01050b5:	e8 96 14 00 00       	call   f0106550 <__umoddi3>
f01050ba:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050be:	0f be 80 dc 7c 10 f0 	movsbl -0xfef8324(%eax),%eax
f01050c5:	89 04 24             	mov    %eax,(%esp)
f01050c8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01050cb:	ff d0                	call   *%eax
}
f01050cd:	83 c4 3c             	add    $0x3c,%esp
f01050d0:	5b                   	pop    %ebx
f01050d1:	5e                   	pop    %esi
f01050d2:	5f                   	pop    %edi
f01050d3:	5d                   	pop    %ebp
f01050d4:	c3                   	ret    

f01050d5 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f01050d5:	55                   	push   %ebp
f01050d6:	89 e5                	mov    %esp,%ebp
f01050d8:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f01050db:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f01050df:	8b 10                	mov    (%eax),%edx
f01050e1:	3b 50 04             	cmp    0x4(%eax),%edx
f01050e4:	73 0a                	jae    f01050f0 <sprintputch+0x1b>
		*b->buf++ = ch;
f01050e6:	8d 4a 01             	lea    0x1(%edx),%ecx
f01050e9:	89 08                	mov    %ecx,(%eax)
f01050eb:	8b 45 08             	mov    0x8(%ebp),%eax
f01050ee:	88 02                	mov    %al,(%edx)
}
f01050f0:	5d                   	pop    %ebp
f01050f1:	c3                   	ret    

f01050f2 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f01050f2:	55                   	push   %ebp
f01050f3:	89 e5                	mov    %esp,%ebp
f01050f5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f01050f8:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f01050fb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01050ff:	8b 45 10             	mov    0x10(%ebp),%eax
f0105102:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105106:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105109:	89 44 24 04          	mov    %eax,0x4(%esp)
f010510d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105110:	89 04 24             	mov    %eax,(%esp)
f0105113:	e8 02 00 00 00       	call   f010511a <vprintfmt>
	va_end(ap);
}
f0105118:	c9                   	leave  
f0105119:	c3                   	ret    

f010511a <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f010511a:	55                   	push   %ebp
f010511b:	89 e5                	mov    %esp,%ebp
f010511d:	57                   	push   %edi
f010511e:	56                   	push   %esi
f010511f:	53                   	push   %ebx
f0105120:	83 ec 3c             	sub    $0x3c,%esp
f0105123:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105126:	89 df                	mov    %ebx,%edi
f0105128:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010512b:	eb 03                	jmp    f0105130 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f010512d:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0105130:	8b 45 10             	mov    0x10(%ebp),%eax
f0105133:	8d 70 01             	lea    0x1(%eax),%esi
f0105136:	0f b6 00             	movzbl (%eax),%eax
f0105139:	83 f8 25             	cmp    $0x25,%eax
f010513c:	74 2d                	je     f010516b <vprintfmt+0x51>
			if (ch == '\0')
f010513e:	85 c0                	test   %eax,%eax
f0105140:	75 14                	jne    f0105156 <vprintfmt+0x3c>
f0105142:	e9 6b 04 00 00       	jmp    f01055b2 <vprintfmt+0x498>
f0105147:	85 c0                	test   %eax,%eax
f0105149:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0105150:	0f 84 5c 04 00 00    	je     f01055b2 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0105156:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010515a:	89 04 24             	mov    %eax,(%esp)
f010515d:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f010515f:	83 c6 01             	add    $0x1,%esi
f0105162:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f0105166:	83 f8 25             	cmp    $0x25,%eax
f0105169:	75 dc                	jne    f0105147 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010516b:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f010516f:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0105176:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010517d:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0105184:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105189:	eb 1f                	jmp    f01051aa <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010518b:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f010518e:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0105192:	eb 16                	jmp    f01051aa <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105194:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105197:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f010519b:	eb 0d                	jmp    f01051aa <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f010519d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01051a0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01051a3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01051aa:	8d 46 01             	lea    0x1(%esi),%eax
f01051ad:	89 45 10             	mov    %eax,0x10(%ebp)
f01051b0:	0f b6 06             	movzbl (%esi),%eax
f01051b3:	0f b6 d0             	movzbl %al,%edx
f01051b6:	83 e8 23             	sub    $0x23,%eax
f01051b9:	3c 55                	cmp    $0x55,%al
f01051bb:	0f 87 c4 03 00 00    	ja     f0105585 <vprintfmt+0x46b>
f01051c1:	0f b6 c0             	movzbl %al,%eax
f01051c4:	ff 24 85 a0 7d 10 f0 	jmp    *-0xfef8260(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f01051cb:	8d 42 d0             	lea    -0x30(%edx),%eax
f01051ce:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f01051d1:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f01051d5:	8d 50 d0             	lea    -0x30(%eax),%edx
f01051d8:	83 fa 09             	cmp    $0x9,%edx
f01051db:	77 63                	ja     f0105240 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01051dd:	8b 75 10             	mov    0x10(%ebp),%esi
f01051e0:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f01051e3:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f01051e6:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f01051e9:	8d 14 92             	lea    (%edx,%edx,4),%edx
f01051ec:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f01051f0:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f01051f3:	8d 48 d0             	lea    -0x30(%eax),%ecx
f01051f6:	83 f9 09             	cmp    $0x9,%ecx
f01051f9:	76 eb                	jbe    f01051e6 <vprintfmt+0xcc>
f01051fb:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f01051fe:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0105201:	eb 40                	jmp    f0105243 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105203:	8b 45 14             	mov    0x14(%ebp),%eax
f0105206:	8b 00                	mov    (%eax),%eax
f0105208:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010520b:	8b 45 14             	mov    0x14(%ebp),%eax
f010520e:	8d 40 04             	lea    0x4(%eax),%eax
f0105211:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105214:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105217:	eb 2a                	jmp    f0105243 <vprintfmt+0x129>
f0105219:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f010521c:	85 d2                	test   %edx,%edx
f010521e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105223:	0f 49 c2             	cmovns %edx,%eax
f0105226:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105229:	8b 75 10             	mov    0x10(%ebp),%esi
f010522c:	e9 79 ff ff ff       	jmp    f01051aa <vprintfmt+0x90>
f0105231:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0105234:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f010523b:	e9 6a ff ff ff       	jmp    f01051aa <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105240:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0105243:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105247:	0f 89 5d ff ff ff    	jns    f01051aa <vprintfmt+0x90>
f010524d:	e9 4b ff ff ff       	jmp    f010519d <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0105252:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105255:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0105258:	e9 4d ff ff ff       	jmp    f01051aa <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f010525d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105260:	8d 70 04             	lea    0x4(%eax),%esi
f0105263:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105267:	8b 00                	mov    (%eax),%eax
f0105269:	89 04 24             	mov    %eax,(%esp)
f010526c:	ff d7                	call   *%edi
f010526e:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0105271:	e9 ba fe ff ff       	jmp    f0105130 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0105276:	8b 45 14             	mov    0x14(%ebp),%eax
f0105279:	8d 70 04             	lea    0x4(%eax),%esi
f010527c:	8b 00                	mov    (%eax),%eax
f010527e:	99                   	cltd   
f010527f:	31 d0                	xor    %edx,%eax
f0105281:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0105283:	83 f8 08             	cmp    $0x8,%eax
f0105286:	7f 0b                	jg     f0105293 <vprintfmt+0x179>
f0105288:	8b 14 85 00 7f 10 f0 	mov    -0xfef8100(,%eax,4),%edx
f010528f:	85 d2                	test   %edx,%edx
f0105291:	75 20                	jne    f01052b3 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f0105293:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105297:	c7 44 24 08 f4 7c 10 	movl   $0xf0107cf4,0x8(%esp)
f010529e:	f0 
f010529f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01052a3:	89 3c 24             	mov    %edi,(%esp)
f01052a6:	e8 47 fe ff ff       	call   f01050f2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f01052ab:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f01052ae:	e9 7d fe ff ff       	jmp    f0105130 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f01052b3:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01052b7:	c7 44 24 08 be 6c 10 	movl   $0xf0106cbe,0x8(%esp)
f01052be:	f0 
f01052bf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01052c3:	89 3c 24             	mov    %edi,(%esp)
f01052c6:	e8 27 fe ff ff       	call   f01050f2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f01052cb:	89 75 14             	mov    %esi,0x14(%ebp)
f01052ce:	e9 5d fe ff ff       	jmp    f0105130 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01052d3:	8b 45 14             	mov    0x14(%ebp),%eax
f01052d6:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f01052d9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f01052dc:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f01052e0:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f01052e2:	85 c0                	test   %eax,%eax
f01052e4:	b9 ed 7c 10 f0       	mov    $0xf0107ced,%ecx
f01052e9:	0f 45 c8             	cmovne %eax,%ecx
f01052ec:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f01052ef:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f01052f3:	74 04                	je     f01052f9 <vprintfmt+0x1df>
f01052f5:	85 f6                	test   %esi,%esi
f01052f7:	7f 19                	jg     f0105312 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01052f9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01052fc:	8d 70 01             	lea    0x1(%eax),%esi
f01052ff:	0f b6 10             	movzbl (%eax),%edx
f0105302:	0f be c2             	movsbl %dl,%eax
f0105305:	85 c0                	test   %eax,%eax
f0105307:	0f 85 9a 00 00 00    	jne    f01053a7 <vprintfmt+0x28d>
f010530d:	e9 87 00 00 00       	jmp    f0105399 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105312:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105316:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105319:	89 04 24             	mov    %eax,(%esp)
f010531c:	e8 11 04 00 00       	call   f0105732 <strnlen>
f0105321:	29 c6                	sub    %eax,%esi
f0105323:	89 f0                	mov    %esi,%eax
f0105325:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105328:	85 f6                	test   %esi,%esi
f010532a:	7e cd                	jle    f01052f9 <vprintfmt+0x1df>
					putch(padc, putdat);
f010532c:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105330:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0105333:	89 c3                	mov    %eax,%ebx
f0105335:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105338:	89 44 24 04          	mov    %eax,0x4(%esp)
f010533c:	89 34 24             	mov    %esi,(%esp)
f010533f:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105341:	83 eb 01             	sub    $0x1,%ebx
f0105344:	75 ef                	jne    f0105335 <vprintfmt+0x21b>
f0105346:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105349:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010534c:	eb ab                	jmp    f01052f9 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f010534e:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0105352:	74 1e                	je     f0105372 <vprintfmt+0x258>
f0105354:	0f be d2             	movsbl %dl,%edx
f0105357:	83 ea 20             	sub    $0x20,%edx
f010535a:	83 fa 5e             	cmp    $0x5e,%edx
f010535d:	76 13                	jbe    f0105372 <vprintfmt+0x258>
					putch('?', putdat);
f010535f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105362:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105366:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f010536d:	ff 55 08             	call   *0x8(%ebp)
f0105370:	eb 0d                	jmp    f010537f <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0105372:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0105375:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105379:	89 04 24             	mov    %eax,(%esp)
f010537c:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f010537f:	83 eb 01             	sub    $0x1,%ebx
f0105382:	83 c6 01             	add    $0x1,%esi
f0105385:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0105389:	0f be c2             	movsbl %dl,%eax
f010538c:	85 c0                	test   %eax,%eax
f010538e:	75 23                	jne    f01053b3 <vprintfmt+0x299>
f0105390:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105393:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105396:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105399:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f010539c:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01053a0:	7f 25                	jg     f01053c7 <vprintfmt+0x2ad>
f01053a2:	e9 89 fd ff ff       	jmp    f0105130 <vprintfmt+0x16>
f01053a7:	89 7d 08             	mov    %edi,0x8(%ebp)
f01053aa:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01053ad:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f01053b0:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01053b3:	85 ff                	test   %edi,%edi
f01053b5:	78 97                	js     f010534e <vprintfmt+0x234>
f01053b7:	83 ef 01             	sub    $0x1,%edi
f01053ba:	79 92                	jns    f010534e <vprintfmt+0x234>
f01053bc:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01053bf:	8b 7d 08             	mov    0x8(%ebp),%edi
f01053c2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01053c5:	eb d2                	jmp    f0105399 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01053c7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01053cb:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01053d2:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01053d4:	83 ee 01             	sub    $0x1,%esi
f01053d7:	75 ee                	jne    f01053c7 <vprintfmt+0x2ad>
f01053d9:	e9 52 fd ff ff       	jmp    f0105130 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01053de:	83 f9 01             	cmp    $0x1,%ecx
f01053e1:	7e 19                	jle    f01053fc <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f01053e3:	8b 45 14             	mov    0x14(%ebp),%eax
f01053e6:	8b 50 04             	mov    0x4(%eax),%edx
f01053e9:	8b 00                	mov    (%eax),%eax
f01053eb:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01053ee:	89 55 dc             	mov    %edx,-0x24(%ebp)
f01053f1:	8b 45 14             	mov    0x14(%ebp),%eax
f01053f4:	8d 40 08             	lea    0x8(%eax),%eax
f01053f7:	89 45 14             	mov    %eax,0x14(%ebp)
f01053fa:	eb 38                	jmp    f0105434 <vprintfmt+0x31a>
	else if (lflag)
f01053fc:	85 c9                	test   %ecx,%ecx
f01053fe:	74 1b                	je     f010541b <vprintfmt+0x301>
		return va_arg(*ap, long);
f0105400:	8b 45 14             	mov    0x14(%ebp),%eax
f0105403:	8b 30                	mov    (%eax),%esi
f0105405:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105408:	89 f0                	mov    %esi,%eax
f010540a:	c1 f8 1f             	sar    $0x1f,%eax
f010540d:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105410:	8b 45 14             	mov    0x14(%ebp),%eax
f0105413:	8d 40 04             	lea    0x4(%eax),%eax
f0105416:	89 45 14             	mov    %eax,0x14(%ebp)
f0105419:	eb 19                	jmp    f0105434 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f010541b:	8b 45 14             	mov    0x14(%ebp),%eax
f010541e:	8b 30                	mov    (%eax),%esi
f0105420:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105423:	89 f0                	mov    %esi,%eax
f0105425:	c1 f8 1f             	sar    $0x1f,%eax
f0105428:	89 45 dc             	mov    %eax,-0x24(%ebp)
f010542b:	8b 45 14             	mov    0x14(%ebp),%eax
f010542e:	8d 40 04             	lea    0x4(%eax),%eax
f0105431:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105434:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105437:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010543a:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f010543f:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105443:	0f 89 06 01 00 00    	jns    f010554f <vprintfmt+0x435>
				putch('-', putdat);
f0105449:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010544d:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105454:	ff d7                	call   *%edi
				num = -(long long) num;
f0105456:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105459:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010545c:	f7 da                	neg    %edx
f010545e:	83 d1 00             	adc    $0x0,%ecx
f0105461:	f7 d9                	neg    %ecx
			}
			base = 10;
f0105463:	b8 0a 00 00 00       	mov    $0xa,%eax
f0105468:	e9 e2 00 00 00       	jmp    f010554f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010546d:	83 f9 01             	cmp    $0x1,%ecx
f0105470:	7e 10                	jle    f0105482 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f0105472:	8b 45 14             	mov    0x14(%ebp),%eax
f0105475:	8b 10                	mov    (%eax),%edx
f0105477:	8b 48 04             	mov    0x4(%eax),%ecx
f010547a:	8d 40 08             	lea    0x8(%eax),%eax
f010547d:	89 45 14             	mov    %eax,0x14(%ebp)
f0105480:	eb 26                	jmp    f01054a8 <vprintfmt+0x38e>
	else if (lflag)
f0105482:	85 c9                	test   %ecx,%ecx
f0105484:	74 12                	je     f0105498 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f0105486:	8b 45 14             	mov    0x14(%ebp),%eax
f0105489:	8b 10                	mov    (%eax),%edx
f010548b:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105490:	8d 40 04             	lea    0x4(%eax),%eax
f0105493:	89 45 14             	mov    %eax,0x14(%ebp)
f0105496:	eb 10                	jmp    f01054a8 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f0105498:	8b 45 14             	mov    0x14(%ebp),%eax
f010549b:	8b 10                	mov    (%eax),%edx
f010549d:	b9 00 00 00 00       	mov    $0x0,%ecx
f01054a2:	8d 40 04             	lea    0x4(%eax),%eax
f01054a5:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f01054a8:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f01054ad:	e9 9d 00 00 00       	jmp    f010554f <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f01054b2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054b6:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01054bd:	ff d7                	call   *%edi
			putch('X', putdat);
f01054bf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054c3:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01054ca:	ff d7                	call   *%edi
			putch('X', putdat);
f01054cc:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054d0:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01054d7:	ff d7                	call   *%edi
			break;
f01054d9:	e9 52 fc ff ff       	jmp    f0105130 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f01054de:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054e2:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01054e9:	ff d7                	call   *%edi
			putch('x', putdat);
f01054eb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054ef:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01054f6:	ff d7                	call   *%edi
			num = (unsigned long long)
f01054f8:	8b 45 14             	mov    0x14(%ebp),%eax
f01054fb:	8b 10                	mov    (%eax),%edx
f01054fd:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f0105502:	8d 40 04             	lea    0x4(%eax),%eax
f0105505:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0105508:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f010550d:	eb 40                	jmp    f010554f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010550f:	83 f9 01             	cmp    $0x1,%ecx
f0105512:	7e 10                	jle    f0105524 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f0105514:	8b 45 14             	mov    0x14(%ebp),%eax
f0105517:	8b 10                	mov    (%eax),%edx
f0105519:	8b 48 04             	mov    0x4(%eax),%ecx
f010551c:	8d 40 08             	lea    0x8(%eax),%eax
f010551f:	89 45 14             	mov    %eax,0x14(%ebp)
f0105522:	eb 26                	jmp    f010554a <vprintfmt+0x430>
	else if (lflag)
f0105524:	85 c9                	test   %ecx,%ecx
f0105526:	74 12                	je     f010553a <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f0105528:	8b 45 14             	mov    0x14(%ebp),%eax
f010552b:	8b 10                	mov    (%eax),%edx
f010552d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105532:	8d 40 04             	lea    0x4(%eax),%eax
f0105535:	89 45 14             	mov    %eax,0x14(%ebp)
f0105538:	eb 10                	jmp    f010554a <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f010553a:	8b 45 14             	mov    0x14(%ebp),%eax
f010553d:	8b 10                	mov    (%eax),%edx
f010553f:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105544:	8d 40 04             	lea    0x4(%eax),%eax
f0105547:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f010554a:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f010554f:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105553:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105557:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010555a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010555e:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105562:	89 14 24             	mov    %edx,(%esp)
f0105565:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105569:	89 da                	mov    %ebx,%edx
f010556b:	89 f8                	mov    %edi,%eax
f010556d:	e8 6e fa ff ff       	call   f0104fe0 <printnum>
			break;
f0105572:	e9 b9 fb ff ff       	jmp    f0105130 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105577:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010557b:	89 14 24             	mov    %edx,(%esp)
f010557e:	ff d7                	call   *%edi
			break;
f0105580:	e9 ab fb ff ff       	jmp    f0105130 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105585:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105589:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105590:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105592:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0105596:	0f 84 91 fb ff ff    	je     f010512d <vprintfmt+0x13>
f010559c:	89 75 10             	mov    %esi,0x10(%ebp)
f010559f:	89 f0                	mov    %esi,%eax
f01055a1:	83 e8 01             	sub    $0x1,%eax
f01055a4:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f01055a8:	75 f7                	jne    f01055a1 <vprintfmt+0x487>
f01055aa:	89 45 10             	mov    %eax,0x10(%ebp)
f01055ad:	e9 7e fb ff ff       	jmp    f0105130 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f01055b2:	83 c4 3c             	add    $0x3c,%esp
f01055b5:	5b                   	pop    %ebx
f01055b6:	5e                   	pop    %esi
f01055b7:	5f                   	pop    %edi
f01055b8:	5d                   	pop    %ebp
f01055b9:	c3                   	ret    

f01055ba <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01055ba:	55                   	push   %ebp
f01055bb:	89 e5                	mov    %esp,%ebp
f01055bd:	83 ec 28             	sub    $0x28,%esp
f01055c0:	8b 45 08             	mov    0x8(%ebp),%eax
f01055c3:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f01055c6:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01055c9:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f01055cd:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01055d0:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01055d7:	85 c0                	test   %eax,%eax
f01055d9:	74 30                	je     f010560b <vsnprintf+0x51>
f01055db:	85 d2                	test   %edx,%edx
f01055dd:	7e 2c                	jle    f010560b <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01055df:	8b 45 14             	mov    0x14(%ebp),%eax
f01055e2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01055e6:	8b 45 10             	mov    0x10(%ebp),%eax
f01055e9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01055ed:	8d 45 ec             	lea    -0x14(%ebp),%eax
f01055f0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01055f4:	c7 04 24 d5 50 10 f0 	movl   $0xf01050d5,(%esp)
f01055fb:	e8 1a fb ff ff       	call   f010511a <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105600:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105603:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105606:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105609:	eb 05                	jmp    f0105610 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f010560b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105610:	c9                   	leave  
f0105611:	c3                   	ret    

f0105612 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105612:	55                   	push   %ebp
f0105613:	89 e5                	mov    %esp,%ebp
f0105615:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105618:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f010561b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010561f:	8b 45 10             	mov    0x10(%ebp),%eax
f0105622:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105626:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105629:	89 44 24 04          	mov    %eax,0x4(%esp)
f010562d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105630:	89 04 24             	mov    %eax,(%esp)
f0105633:	e8 82 ff ff ff       	call   f01055ba <vsnprintf>
	va_end(ap);

	return rc;
}
f0105638:	c9                   	leave  
f0105639:	c3                   	ret    
f010563a:	66 90                	xchg   %ax,%ax
f010563c:	66 90                	xchg   %ax,%ax
f010563e:	66 90                	xchg   %ax,%ax

f0105640 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105640:	55                   	push   %ebp
f0105641:	89 e5                	mov    %esp,%ebp
f0105643:	57                   	push   %edi
f0105644:	56                   	push   %esi
f0105645:	53                   	push   %ebx
f0105646:	83 ec 1c             	sub    $0x1c,%esp
f0105649:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010564c:	85 c0                	test   %eax,%eax
f010564e:	74 10                	je     f0105660 <readline+0x20>
		cprintf("%s", prompt);
f0105650:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105654:	c7 04 24 be 6c 10 f0 	movl   $0xf0106cbe,(%esp)
f010565b:	e8 d1 ea ff ff       	call   f0104131 <cprintf>

	i = 0;
	echoing = iscons(0);
f0105660:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105667:	e8 a2 b1 ff ff       	call   f010080e <iscons>
f010566c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010566e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105673:	e8 85 b1 ff ff       	call   f01007fd <getchar>
f0105678:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010567a:	85 c0                	test   %eax,%eax
f010567c:	79 17                	jns    f0105695 <readline+0x55>
			cprintf("read error: %e\n", c);
f010567e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105682:	c7 04 24 24 7f 10 f0 	movl   $0xf0107f24,(%esp)
f0105689:	e8 a3 ea ff ff       	call   f0104131 <cprintf>
			return NULL;
f010568e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105693:	eb 6d                	jmp    f0105702 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105695:	83 f8 7f             	cmp    $0x7f,%eax
f0105698:	74 05                	je     f010569f <readline+0x5f>
f010569a:	83 f8 08             	cmp    $0x8,%eax
f010569d:	75 19                	jne    f01056b8 <readline+0x78>
f010569f:	85 f6                	test   %esi,%esi
f01056a1:	7e 15                	jle    f01056b8 <readline+0x78>
			if (echoing)
f01056a3:	85 ff                	test   %edi,%edi
f01056a5:	74 0c                	je     f01056b3 <readline+0x73>
				cputchar('\b');
f01056a7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01056ae:	e8 3a b1 ff ff       	call   f01007ed <cputchar>
			i--;
f01056b3:	83 ee 01             	sub    $0x1,%esi
f01056b6:	eb bb                	jmp    f0105673 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01056b8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01056be:	7f 1c                	jg     f01056dc <readline+0x9c>
f01056c0:	83 fb 1f             	cmp    $0x1f,%ebx
f01056c3:	7e 17                	jle    f01056dc <readline+0x9c>
			if (echoing)
f01056c5:	85 ff                	test   %edi,%edi
f01056c7:	74 08                	je     f01056d1 <readline+0x91>
				cputchar(c);
f01056c9:	89 1c 24             	mov    %ebx,(%esp)
f01056cc:	e8 1c b1 ff ff       	call   f01007ed <cputchar>
			buf[i++] = c;
f01056d1:	88 9e 80 3a 22 f0    	mov    %bl,-0xfddc580(%esi)
f01056d7:	8d 76 01             	lea    0x1(%esi),%esi
f01056da:	eb 97                	jmp    f0105673 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f01056dc:	83 fb 0d             	cmp    $0xd,%ebx
f01056df:	74 05                	je     f01056e6 <readline+0xa6>
f01056e1:	83 fb 0a             	cmp    $0xa,%ebx
f01056e4:	75 8d                	jne    f0105673 <readline+0x33>
			if (echoing)
f01056e6:	85 ff                	test   %edi,%edi
f01056e8:	74 0c                	je     f01056f6 <readline+0xb6>
				cputchar('\n');
f01056ea:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f01056f1:	e8 f7 b0 ff ff       	call   f01007ed <cputchar>
			buf[i] = 0;
f01056f6:	c6 86 80 3a 22 f0 00 	movb   $0x0,-0xfddc580(%esi)
			return buf;
f01056fd:	b8 80 3a 22 f0       	mov    $0xf0223a80,%eax
		}
	}
}
f0105702:	83 c4 1c             	add    $0x1c,%esp
f0105705:	5b                   	pop    %ebx
f0105706:	5e                   	pop    %esi
f0105707:	5f                   	pop    %edi
f0105708:	5d                   	pop    %ebp
f0105709:	c3                   	ret    
f010570a:	66 90                	xchg   %ax,%ax
f010570c:	66 90                	xchg   %ax,%ax
f010570e:	66 90                	xchg   %ax,%ax

f0105710 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105710:	55                   	push   %ebp
f0105711:	89 e5                	mov    %esp,%ebp
f0105713:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105716:	80 3a 00             	cmpb   $0x0,(%edx)
f0105719:	74 10                	je     f010572b <strlen+0x1b>
f010571b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105720:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105723:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105727:	75 f7                	jne    f0105720 <strlen+0x10>
f0105729:	eb 05                	jmp    f0105730 <strlen+0x20>
f010572b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105730:	5d                   	pop    %ebp
f0105731:	c3                   	ret    

f0105732 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105732:	55                   	push   %ebp
f0105733:	89 e5                	mov    %esp,%ebp
f0105735:	53                   	push   %ebx
f0105736:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105739:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010573c:	85 c9                	test   %ecx,%ecx
f010573e:	74 1c                	je     f010575c <strnlen+0x2a>
f0105740:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105743:	74 1e                	je     f0105763 <strnlen+0x31>
f0105745:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010574a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010574c:	39 ca                	cmp    %ecx,%edx
f010574e:	74 18                	je     f0105768 <strnlen+0x36>
f0105750:	83 c2 01             	add    $0x1,%edx
f0105753:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105758:	75 f0                	jne    f010574a <strnlen+0x18>
f010575a:	eb 0c                	jmp    f0105768 <strnlen+0x36>
f010575c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105761:	eb 05                	jmp    f0105768 <strnlen+0x36>
f0105763:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105768:	5b                   	pop    %ebx
f0105769:	5d                   	pop    %ebp
f010576a:	c3                   	ret    

f010576b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010576b:	55                   	push   %ebp
f010576c:	89 e5                	mov    %esp,%ebp
f010576e:	53                   	push   %ebx
f010576f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105772:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105775:	89 c2                	mov    %eax,%edx
f0105777:	83 c2 01             	add    $0x1,%edx
f010577a:	83 c1 01             	add    $0x1,%ecx
f010577d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105781:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105784:	84 db                	test   %bl,%bl
f0105786:	75 ef                	jne    f0105777 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105788:	5b                   	pop    %ebx
f0105789:	5d                   	pop    %ebp
f010578a:	c3                   	ret    

f010578b <strcat>:

char *
strcat(char *dst, const char *src)
{
f010578b:	55                   	push   %ebp
f010578c:	89 e5                	mov    %esp,%ebp
f010578e:	53                   	push   %ebx
f010578f:	83 ec 08             	sub    $0x8,%esp
f0105792:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105795:	89 1c 24             	mov    %ebx,(%esp)
f0105798:	e8 73 ff ff ff       	call   f0105710 <strlen>
	strcpy(dst + len, src);
f010579d:	8b 55 0c             	mov    0xc(%ebp),%edx
f01057a0:	89 54 24 04          	mov    %edx,0x4(%esp)
f01057a4:	01 d8                	add    %ebx,%eax
f01057a6:	89 04 24             	mov    %eax,(%esp)
f01057a9:	e8 bd ff ff ff       	call   f010576b <strcpy>
	return dst;
}
f01057ae:	89 d8                	mov    %ebx,%eax
f01057b0:	83 c4 08             	add    $0x8,%esp
f01057b3:	5b                   	pop    %ebx
f01057b4:	5d                   	pop    %ebp
f01057b5:	c3                   	ret    

f01057b6 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01057b6:	55                   	push   %ebp
f01057b7:	89 e5                	mov    %esp,%ebp
f01057b9:	56                   	push   %esi
f01057ba:	53                   	push   %ebx
f01057bb:	8b 75 08             	mov    0x8(%ebp),%esi
f01057be:	8b 55 0c             	mov    0xc(%ebp),%edx
f01057c1:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01057c4:	85 db                	test   %ebx,%ebx
f01057c6:	74 17                	je     f01057df <strncpy+0x29>
f01057c8:	01 f3                	add    %esi,%ebx
f01057ca:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f01057cc:	83 c1 01             	add    $0x1,%ecx
f01057cf:	0f b6 02             	movzbl (%edx),%eax
f01057d2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01057d5:	80 3a 01             	cmpb   $0x1,(%edx)
f01057d8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01057db:	39 d9                	cmp    %ebx,%ecx
f01057dd:	75 ed                	jne    f01057cc <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f01057df:	89 f0                	mov    %esi,%eax
f01057e1:	5b                   	pop    %ebx
f01057e2:	5e                   	pop    %esi
f01057e3:	5d                   	pop    %ebp
f01057e4:	c3                   	ret    

f01057e5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f01057e5:	55                   	push   %ebp
f01057e6:	89 e5                	mov    %esp,%ebp
f01057e8:	57                   	push   %edi
f01057e9:	56                   	push   %esi
f01057ea:	53                   	push   %ebx
f01057eb:	8b 7d 08             	mov    0x8(%ebp),%edi
f01057ee:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01057f1:	8b 75 10             	mov    0x10(%ebp),%esi
f01057f4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f01057f6:	85 f6                	test   %esi,%esi
f01057f8:	74 34                	je     f010582e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f01057fa:	83 fe 01             	cmp    $0x1,%esi
f01057fd:	74 26                	je     f0105825 <strlcpy+0x40>
f01057ff:	0f b6 0b             	movzbl (%ebx),%ecx
f0105802:	84 c9                	test   %cl,%cl
f0105804:	74 23                	je     f0105829 <strlcpy+0x44>
f0105806:	83 ee 02             	sub    $0x2,%esi
f0105809:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f010580e:	83 c0 01             	add    $0x1,%eax
f0105811:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105814:	39 f2                	cmp    %esi,%edx
f0105816:	74 13                	je     f010582b <strlcpy+0x46>
f0105818:	83 c2 01             	add    $0x1,%edx
f010581b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f010581f:	84 c9                	test   %cl,%cl
f0105821:	75 eb                	jne    f010580e <strlcpy+0x29>
f0105823:	eb 06                	jmp    f010582b <strlcpy+0x46>
f0105825:	89 f8                	mov    %edi,%eax
f0105827:	eb 02                	jmp    f010582b <strlcpy+0x46>
f0105829:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f010582b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f010582e:	29 f8                	sub    %edi,%eax
}
f0105830:	5b                   	pop    %ebx
f0105831:	5e                   	pop    %esi
f0105832:	5f                   	pop    %edi
f0105833:	5d                   	pop    %ebp
f0105834:	c3                   	ret    

f0105835 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105835:	55                   	push   %ebp
f0105836:	89 e5                	mov    %esp,%ebp
f0105838:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010583b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f010583e:	0f b6 01             	movzbl (%ecx),%eax
f0105841:	84 c0                	test   %al,%al
f0105843:	74 15                	je     f010585a <strcmp+0x25>
f0105845:	3a 02                	cmp    (%edx),%al
f0105847:	75 11                	jne    f010585a <strcmp+0x25>
		p++, q++;
f0105849:	83 c1 01             	add    $0x1,%ecx
f010584c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010584f:	0f b6 01             	movzbl (%ecx),%eax
f0105852:	84 c0                	test   %al,%al
f0105854:	74 04                	je     f010585a <strcmp+0x25>
f0105856:	3a 02                	cmp    (%edx),%al
f0105858:	74 ef                	je     f0105849 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010585a:	0f b6 c0             	movzbl %al,%eax
f010585d:	0f b6 12             	movzbl (%edx),%edx
f0105860:	29 d0                	sub    %edx,%eax
}
f0105862:	5d                   	pop    %ebp
f0105863:	c3                   	ret    

f0105864 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105864:	55                   	push   %ebp
f0105865:	89 e5                	mov    %esp,%ebp
f0105867:	56                   	push   %esi
f0105868:	53                   	push   %ebx
f0105869:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010586c:	8b 55 0c             	mov    0xc(%ebp),%edx
f010586f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105872:	85 f6                	test   %esi,%esi
f0105874:	74 29                	je     f010589f <strncmp+0x3b>
f0105876:	0f b6 03             	movzbl (%ebx),%eax
f0105879:	84 c0                	test   %al,%al
f010587b:	74 30                	je     f01058ad <strncmp+0x49>
f010587d:	3a 02                	cmp    (%edx),%al
f010587f:	75 2c                	jne    f01058ad <strncmp+0x49>
f0105881:	8d 43 01             	lea    0x1(%ebx),%eax
f0105884:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105886:	89 c3                	mov    %eax,%ebx
f0105888:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f010588b:	39 f0                	cmp    %esi,%eax
f010588d:	74 17                	je     f01058a6 <strncmp+0x42>
f010588f:	0f b6 08             	movzbl (%eax),%ecx
f0105892:	84 c9                	test   %cl,%cl
f0105894:	74 17                	je     f01058ad <strncmp+0x49>
f0105896:	83 c0 01             	add    $0x1,%eax
f0105899:	3a 0a                	cmp    (%edx),%cl
f010589b:	74 e9                	je     f0105886 <strncmp+0x22>
f010589d:	eb 0e                	jmp    f01058ad <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f010589f:	b8 00 00 00 00       	mov    $0x0,%eax
f01058a4:	eb 0f                	jmp    f01058b5 <strncmp+0x51>
f01058a6:	b8 00 00 00 00       	mov    $0x0,%eax
f01058ab:	eb 08                	jmp    f01058b5 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f01058ad:	0f b6 03             	movzbl (%ebx),%eax
f01058b0:	0f b6 12             	movzbl (%edx),%edx
f01058b3:	29 d0                	sub    %edx,%eax
}
f01058b5:	5b                   	pop    %ebx
f01058b6:	5e                   	pop    %esi
f01058b7:	5d                   	pop    %ebp
f01058b8:	c3                   	ret    

f01058b9 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01058b9:	55                   	push   %ebp
f01058ba:	89 e5                	mov    %esp,%ebp
f01058bc:	53                   	push   %ebx
f01058bd:	8b 45 08             	mov    0x8(%ebp),%eax
f01058c0:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f01058c3:	0f b6 18             	movzbl (%eax),%ebx
f01058c6:	84 db                	test   %bl,%bl
f01058c8:	74 1d                	je     f01058e7 <strchr+0x2e>
f01058ca:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f01058cc:	38 d3                	cmp    %dl,%bl
f01058ce:	75 06                	jne    f01058d6 <strchr+0x1d>
f01058d0:	eb 1a                	jmp    f01058ec <strchr+0x33>
f01058d2:	38 ca                	cmp    %cl,%dl
f01058d4:	74 16                	je     f01058ec <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f01058d6:	83 c0 01             	add    $0x1,%eax
f01058d9:	0f b6 10             	movzbl (%eax),%edx
f01058dc:	84 d2                	test   %dl,%dl
f01058de:	75 f2                	jne    f01058d2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f01058e0:	b8 00 00 00 00       	mov    $0x0,%eax
f01058e5:	eb 05                	jmp    f01058ec <strchr+0x33>
f01058e7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01058ec:	5b                   	pop    %ebx
f01058ed:	5d                   	pop    %ebp
f01058ee:	c3                   	ret    

f01058ef <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f01058ef:	55                   	push   %ebp
f01058f0:	89 e5                	mov    %esp,%ebp
f01058f2:	53                   	push   %ebx
f01058f3:	8b 45 08             	mov    0x8(%ebp),%eax
f01058f6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f01058f9:	0f b6 18             	movzbl (%eax),%ebx
f01058fc:	84 db                	test   %bl,%bl
f01058fe:	74 16                	je     f0105916 <strfind+0x27>
f0105900:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105902:	38 d3                	cmp    %dl,%bl
f0105904:	75 06                	jne    f010590c <strfind+0x1d>
f0105906:	eb 0e                	jmp    f0105916 <strfind+0x27>
f0105908:	38 ca                	cmp    %cl,%dl
f010590a:	74 0a                	je     f0105916 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010590c:	83 c0 01             	add    $0x1,%eax
f010590f:	0f b6 10             	movzbl (%eax),%edx
f0105912:	84 d2                	test   %dl,%dl
f0105914:	75 f2                	jne    f0105908 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105916:	5b                   	pop    %ebx
f0105917:	5d                   	pop    %ebp
f0105918:	c3                   	ret    

f0105919 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105919:	55                   	push   %ebp
f010591a:	89 e5                	mov    %esp,%ebp
f010591c:	57                   	push   %edi
f010591d:	56                   	push   %esi
f010591e:	53                   	push   %ebx
f010591f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105922:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105925:	85 c9                	test   %ecx,%ecx
f0105927:	74 36                	je     f010595f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105929:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010592f:	75 28                	jne    f0105959 <memset+0x40>
f0105931:	f6 c1 03             	test   $0x3,%cl
f0105934:	75 23                	jne    f0105959 <memset+0x40>
		c &= 0xFF;
f0105936:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f010593a:	89 d3                	mov    %edx,%ebx
f010593c:	c1 e3 08             	shl    $0x8,%ebx
f010593f:	89 d6                	mov    %edx,%esi
f0105941:	c1 e6 18             	shl    $0x18,%esi
f0105944:	89 d0                	mov    %edx,%eax
f0105946:	c1 e0 10             	shl    $0x10,%eax
f0105949:	09 f0                	or     %esi,%eax
f010594b:	09 c2                	or     %eax,%edx
f010594d:	89 d0                	mov    %edx,%eax
f010594f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105951:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105954:	fc                   	cld    
f0105955:	f3 ab                	rep stos %eax,%es:(%edi)
f0105957:	eb 06                	jmp    f010595f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105959:	8b 45 0c             	mov    0xc(%ebp),%eax
f010595c:	fc                   	cld    
f010595d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010595f:	89 f8                	mov    %edi,%eax
f0105961:	5b                   	pop    %ebx
f0105962:	5e                   	pop    %esi
f0105963:	5f                   	pop    %edi
f0105964:	5d                   	pop    %ebp
f0105965:	c3                   	ret    

f0105966 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105966:	55                   	push   %ebp
f0105967:	89 e5                	mov    %esp,%ebp
f0105969:	57                   	push   %edi
f010596a:	56                   	push   %esi
f010596b:	8b 45 08             	mov    0x8(%ebp),%eax
f010596e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105971:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105974:	39 c6                	cmp    %eax,%esi
f0105976:	73 35                	jae    f01059ad <memmove+0x47>
f0105978:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f010597b:	39 d0                	cmp    %edx,%eax
f010597d:	73 2e                	jae    f01059ad <memmove+0x47>
		s += n;
		d += n;
f010597f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105982:	89 d6                	mov    %edx,%esi
f0105984:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105986:	f7 c6 03 00 00 00    	test   $0x3,%esi
f010598c:	75 13                	jne    f01059a1 <memmove+0x3b>
f010598e:	f6 c1 03             	test   $0x3,%cl
f0105991:	75 0e                	jne    f01059a1 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105993:	83 ef 04             	sub    $0x4,%edi
f0105996:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105999:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f010599c:	fd                   	std    
f010599d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f010599f:	eb 09                	jmp    f01059aa <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f01059a1:	83 ef 01             	sub    $0x1,%edi
f01059a4:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f01059a7:	fd                   	std    
f01059a8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f01059aa:	fc                   	cld    
f01059ab:	eb 1d                	jmp    f01059ca <memmove+0x64>
f01059ad:	89 f2                	mov    %esi,%edx
f01059af:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01059b1:	f6 c2 03             	test   $0x3,%dl
f01059b4:	75 0f                	jne    f01059c5 <memmove+0x5f>
f01059b6:	f6 c1 03             	test   $0x3,%cl
f01059b9:	75 0a                	jne    f01059c5 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f01059bb:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f01059be:	89 c7                	mov    %eax,%edi
f01059c0:	fc                   	cld    
f01059c1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01059c3:	eb 05                	jmp    f01059ca <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f01059c5:	89 c7                	mov    %eax,%edi
f01059c7:	fc                   	cld    
f01059c8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f01059ca:	5e                   	pop    %esi
f01059cb:	5f                   	pop    %edi
f01059cc:	5d                   	pop    %ebp
f01059cd:	c3                   	ret    

f01059ce <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f01059ce:	55                   	push   %ebp
f01059cf:	89 e5                	mov    %esp,%ebp
f01059d1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f01059d4:	8b 45 10             	mov    0x10(%ebp),%eax
f01059d7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01059db:	8b 45 0c             	mov    0xc(%ebp),%eax
f01059de:	89 44 24 04          	mov    %eax,0x4(%esp)
f01059e2:	8b 45 08             	mov    0x8(%ebp),%eax
f01059e5:	89 04 24             	mov    %eax,(%esp)
f01059e8:	e8 79 ff ff ff       	call   f0105966 <memmove>
}
f01059ed:	c9                   	leave  
f01059ee:	c3                   	ret    

f01059ef <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f01059ef:	55                   	push   %ebp
f01059f0:	89 e5                	mov    %esp,%ebp
f01059f2:	57                   	push   %edi
f01059f3:	56                   	push   %esi
f01059f4:	53                   	push   %ebx
f01059f5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01059f8:	8b 75 0c             	mov    0xc(%ebp),%esi
f01059fb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f01059fe:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105a01:	85 c0                	test   %eax,%eax
f0105a03:	74 36                	je     f0105a3b <memcmp+0x4c>
		if (*s1 != *s2)
f0105a05:	0f b6 03             	movzbl (%ebx),%eax
f0105a08:	0f b6 0e             	movzbl (%esi),%ecx
f0105a0b:	ba 00 00 00 00       	mov    $0x0,%edx
f0105a10:	38 c8                	cmp    %cl,%al
f0105a12:	74 1c                	je     f0105a30 <memcmp+0x41>
f0105a14:	eb 10                	jmp    f0105a26 <memcmp+0x37>
f0105a16:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105a1b:	83 c2 01             	add    $0x1,%edx
f0105a1e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0105a22:	38 c8                	cmp    %cl,%al
f0105a24:	74 0a                	je     f0105a30 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0105a26:	0f b6 c0             	movzbl %al,%eax
f0105a29:	0f b6 c9             	movzbl %cl,%ecx
f0105a2c:	29 c8                	sub    %ecx,%eax
f0105a2e:	eb 10                	jmp    f0105a40 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105a30:	39 fa                	cmp    %edi,%edx
f0105a32:	75 e2                	jne    f0105a16 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0105a34:	b8 00 00 00 00       	mov    $0x0,%eax
f0105a39:	eb 05                	jmp    f0105a40 <memcmp+0x51>
f0105a3b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105a40:	5b                   	pop    %ebx
f0105a41:	5e                   	pop    %esi
f0105a42:	5f                   	pop    %edi
f0105a43:	5d                   	pop    %ebp
f0105a44:	c3                   	ret    

f0105a45 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0105a45:	55                   	push   %ebp
f0105a46:	89 e5                	mov    %esp,%ebp
f0105a48:	53                   	push   %ebx
f0105a49:	8b 45 08             	mov    0x8(%ebp),%eax
f0105a4c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0105a4f:	89 c2                	mov    %eax,%edx
f0105a51:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105a54:	39 d0                	cmp    %edx,%eax
f0105a56:	73 13                	jae    f0105a6b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105a58:	89 d9                	mov    %ebx,%ecx
f0105a5a:	38 18                	cmp    %bl,(%eax)
f0105a5c:	75 06                	jne    f0105a64 <memfind+0x1f>
f0105a5e:	eb 0b                	jmp    f0105a6b <memfind+0x26>
f0105a60:	38 08                	cmp    %cl,(%eax)
f0105a62:	74 07                	je     f0105a6b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105a64:	83 c0 01             	add    $0x1,%eax
f0105a67:	39 d0                	cmp    %edx,%eax
f0105a69:	75 f5                	jne    f0105a60 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0105a6b:	5b                   	pop    %ebx
f0105a6c:	5d                   	pop    %ebp
f0105a6d:	c3                   	ret    

f0105a6e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0105a6e:	55                   	push   %ebp
f0105a6f:	89 e5                	mov    %esp,%ebp
f0105a71:	57                   	push   %edi
f0105a72:	56                   	push   %esi
f0105a73:	53                   	push   %ebx
f0105a74:	8b 55 08             	mov    0x8(%ebp),%edx
f0105a77:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105a7a:	0f b6 0a             	movzbl (%edx),%ecx
f0105a7d:	80 f9 09             	cmp    $0x9,%cl
f0105a80:	74 05                	je     f0105a87 <strtol+0x19>
f0105a82:	80 f9 20             	cmp    $0x20,%cl
f0105a85:	75 10                	jne    f0105a97 <strtol+0x29>
		s++;
f0105a87:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105a8a:	0f b6 0a             	movzbl (%edx),%ecx
f0105a8d:	80 f9 09             	cmp    $0x9,%cl
f0105a90:	74 f5                	je     f0105a87 <strtol+0x19>
f0105a92:	80 f9 20             	cmp    $0x20,%cl
f0105a95:	74 f0                	je     f0105a87 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105a97:	80 f9 2b             	cmp    $0x2b,%cl
f0105a9a:	75 0a                	jne    f0105aa6 <strtol+0x38>
		s++;
f0105a9c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0105a9f:	bf 00 00 00 00       	mov    $0x0,%edi
f0105aa4:	eb 11                	jmp    f0105ab7 <strtol+0x49>
f0105aa6:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0105aab:	80 f9 2d             	cmp    $0x2d,%cl
f0105aae:	75 07                	jne    f0105ab7 <strtol+0x49>
		s++, neg = 1;
f0105ab0:	83 c2 01             	add    $0x1,%edx
f0105ab3:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105ab7:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0105abc:	75 15                	jne    f0105ad3 <strtol+0x65>
f0105abe:	80 3a 30             	cmpb   $0x30,(%edx)
f0105ac1:	75 10                	jne    f0105ad3 <strtol+0x65>
f0105ac3:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105ac7:	75 0a                	jne    f0105ad3 <strtol+0x65>
		s += 2, base = 16;
f0105ac9:	83 c2 02             	add    $0x2,%edx
f0105acc:	b8 10 00 00 00       	mov    $0x10,%eax
f0105ad1:	eb 10                	jmp    f0105ae3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105ad3:	85 c0                	test   %eax,%eax
f0105ad5:	75 0c                	jne    f0105ae3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105ad7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105ad9:	80 3a 30             	cmpb   $0x30,(%edx)
f0105adc:	75 05                	jne    f0105ae3 <strtol+0x75>
		s++, base = 8;
f0105ade:	83 c2 01             	add    $0x1,%edx
f0105ae1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105ae3:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105ae8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0105aeb:	0f b6 0a             	movzbl (%edx),%ecx
f0105aee:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0105af1:	89 f0                	mov    %esi,%eax
f0105af3:	3c 09                	cmp    $0x9,%al
f0105af5:	77 08                	ja     f0105aff <strtol+0x91>
			dig = *s - '0';
f0105af7:	0f be c9             	movsbl %cl,%ecx
f0105afa:	83 e9 30             	sub    $0x30,%ecx
f0105afd:	eb 20                	jmp    f0105b1f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0105aff:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0105b02:	89 f0                	mov    %esi,%eax
f0105b04:	3c 19                	cmp    $0x19,%al
f0105b06:	77 08                	ja     f0105b10 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0105b08:	0f be c9             	movsbl %cl,%ecx
f0105b0b:	83 e9 57             	sub    $0x57,%ecx
f0105b0e:	eb 0f                	jmp    f0105b1f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0105b10:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0105b13:	89 f0                	mov    %esi,%eax
f0105b15:	3c 19                	cmp    $0x19,%al
f0105b17:	77 16                	ja     f0105b2f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0105b19:	0f be c9             	movsbl %cl,%ecx
f0105b1c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0105b1f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0105b22:	7d 0f                	jge    f0105b33 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0105b24:	83 c2 01             	add    $0x1,%edx
f0105b27:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0105b2b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0105b2d:	eb bc                	jmp    f0105aeb <strtol+0x7d>
f0105b2f:	89 d8                	mov    %ebx,%eax
f0105b31:	eb 02                	jmp    f0105b35 <strtol+0xc7>
f0105b33:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0105b35:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0105b39:	74 05                	je     f0105b40 <strtol+0xd2>
		*endptr = (char *) s;
f0105b3b:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105b3e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0105b40:	f7 d8                	neg    %eax
f0105b42:	85 ff                	test   %edi,%edi
f0105b44:	0f 44 c3             	cmove  %ebx,%eax
}
f0105b47:	5b                   	pop    %ebx
f0105b48:	5e                   	pop    %esi
f0105b49:	5f                   	pop    %edi
f0105b4a:	5d                   	pop    %ebp
f0105b4b:	c3                   	ret    

f0105b4c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f0105b4c:	fa                   	cli    

	xorw    %ax, %ax
f0105b4d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f0105b4f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105b51:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105b53:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0105b55:	0f 01 16             	lgdtl  (%esi)
f0105b58:	74 70                	je     f0105bca <mpentry_end+0x4>
	movl    %cr0, %eax
f0105b5a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f0105b5d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0105b61:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0105b64:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f0105b6a:	08 00                	or     %al,(%eax)

f0105b6c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f0105b6c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0105b70:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105b72:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105b74:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0105b76:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f0105b7a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f0105b7c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f0105b7e:	b8 00 e0 11 00       	mov    $0x11e000,%eax
	movl    %eax, %cr3
f0105b83:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0105b86:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0105b89:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f0105b8e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0105b91:	8b 25 84 3e 22 f0    	mov    0xf0223e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0105b97:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f0105b9c:	b8 48 02 10 f0       	mov    $0xf0100248,%eax
	call    *%eax
f0105ba1:	ff d0                	call   *%eax

f0105ba3 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0105ba3:	eb fe                	jmp    f0105ba3 <spin>
f0105ba5:	8d 76 00             	lea    0x0(%esi),%esi

f0105ba8 <gdt>:
	...
f0105bb0:	ff                   	(bad)  
f0105bb1:	ff 00                	incl   (%eax)
f0105bb3:	00 00                	add    %al,(%eax)
f0105bb5:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f0105bbc:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0105bc0 <gdtdesc>:
f0105bc0:	17                   	pop    %ss
f0105bc1:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0105bc6 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0105bc6:	90                   	nop
f0105bc7:	66 90                	xchg   %ax,%ax
f0105bc9:	66 90                	xchg   %ax,%ax
f0105bcb:	66 90                	xchg   %ax,%ax
f0105bcd:	66 90                	xchg   %ax,%ax
f0105bcf:	90                   	nop

f0105bd0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0105bd0:	55                   	push   %ebp
f0105bd1:	89 e5                	mov    %esp,%ebp
f0105bd3:	56                   	push   %esi
f0105bd4:	53                   	push   %ebx
f0105bd5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105bd8:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0105bde:	89 c3                	mov    %eax,%ebx
f0105be0:	c1 eb 0c             	shr    $0xc,%ebx
f0105be3:	39 cb                	cmp    %ecx,%ebx
f0105be5:	72 20                	jb     f0105c07 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105be7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105beb:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0105bf2:	f0 
f0105bf3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105bfa:	00 
f0105bfb:	c7 04 24 c1 80 10 f0 	movl   $0xf01080c1,(%esp)
f0105c02:	e8 39 a4 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105c07:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f0105c0d:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105c0f:	89 c2                	mov    %eax,%edx
f0105c11:	c1 ea 0c             	shr    $0xc,%edx
f0105c14:	39 d1                	cmp    %edx,%ecx
f0105c16:	77 20                	ja     f0105c38 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105c18:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105c1c:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0105c23:	f0 
f0105c24:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105c2b:	00 
f0105c2c:	c7 04 24 c1 80 10 f0 	movl   $0xf01080c1,(%esp)
f0105c33:	e8 08 a4 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105c38:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f0105c3e:	39 f3                	cmp    %esi,%ebx
f0105c40:	73 40                	jae    f0105c82 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105c42:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105c49:	00 
f0105c4a:	c7 44 24 04 d1 80 10 	movl   $0xf01080d1,0x4(%esp)
f0105c51:	f0 
f0105c52:	89 1c 24             	mov    %ebx,(%esp)
f0105c55:	e8 95 fd ff ff       	call   f01059ef <memcmp>
f0105c5a:	85 c0                	test   %eax,%eax
f0105c5c:	75 17                	jne    f0105c75 <mpsearch1+0xa5>
f0105c5e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0105c63:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0105c67:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105c69:	83 c0 01             	add    $0x1,%eax
f0105c6c:	83 f8 10             	cmp    $0x10,%eax
f0105c6f:	75 f2                	jne    f0105c63 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105c71:	84 d2                	test   %dl,%dl
f0105c73:	74 14                	je     f0105c89 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0105c75:	83 c3 10             	add    $0x10,%ebx
f0105c78:	39 f3                	cmp    %esi,%ebx
f0105c7a:	72 c6                	jb     f0105c42 <mpsearch1+0x72>
f0105c7c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105c80:	eb 0b                	jmp    f0105c8d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0105c82:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c87:	eb 09                	jmp    f0105c92 <mpsearch1+0xc2>
f0105c89:	89 d8                	mov    %ebx,%eax
f0105c8b:	eb 05                	jmp    f0105c92 <mpsearch1+0xc2>
f0105c8d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105c92:	83 c4 10             	add    $0x10,%esp
f0105c95:	5b                   	pop    %ebx
f0105c96:	5e                   	pop    %esi
f0105c97:	5d                   	pop    %ebp
f0105c98:	c3                   	ret    

f0105c99 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0105c99:	55                   	push   %ebp
f0105c9a:	89 e5                	mov    %esp,%ebp
f0105c9c:	57                   	push   %edi
f0105c9d:	56                   	push   %esi
f0105c9e:	53                   	push   %ebx
f0105c9f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0105ca2:	c7 05 c0 43 22 f0 20 	movl   $0xf0224020,0xf02243c0
f0105ca9:	40 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105cac:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f0105cb3:	75 24                	jne    f0105cd9 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105cb5:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0105cbc:	00 
f0105cbd:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0105cc4:	f0 
f0105cc5:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0105ccc:	00 
f0105ccd:	c7 04 24 c1 80 10 f0 	movl   $0xf01080c1,(%esp)
f0105cd4:	e8 67 a3 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0105cd9:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0105ce0:	85 c0                	test   %eax,%eax
f0105ce2:	74 16                	je     f0105cfa <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0105ce4:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0105ce7:	ba 00 04 00 00       	mov    $0x400,%edx
f0105cec:	e8 df fe ff ff       	call   f0105bd0 <mpsearch1>
f0105cf1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105cf4:	85 c0                	test   %eax,%eax
f0105cf6:	75 3c                	jne    f0105d34 <mp_init+0x9b>
f0105cf8:	eb 20                	jmp    f0105d1a <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0105cfa:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0105d01:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0105d04:	2d 00 04 00 00       	sub    $0x400,%eax
f0105d09:	ba 00 04 00 00       	mov    $0x400,%edx
f0105d0e:	e8 bd fe ff ff       	call   f0105bd0 <mpsearch1>
f0105d13:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105d16:	85 c0                	test   %eax,%eax
f0105d18:	75 1a                	jne    f0105d34 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0105d1a:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105d1f:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0105d24:	e8 a7 fe ff ff       	call   f0105bd0 <mpsearch1>
f0105d29:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0105d2c:	85 c0                	test   %eax,%eax
f0105d2e:	0f 84 5f 02 00 00    	je     f0105f93 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0105d34:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105d37:	8b 70 04             	mov    0x4(%eax),%esi
f0105d3a:	85 f6                	test   %esi,%esi
f0105d3c:	74 06                	je     f0105d44 <mp_init+0xab>
f0105d3e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0105d42:	74 11                	je     f0105d55 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0105d44:	c7 04 24 34 7f 10 f0 	movl   $0xf0107f34,(%esp)
f0105d4b:	e8 e1 e3 ff ff       	call   f0104131 <cprintf>
f0105d50:	e9 3e 02 00 00       	jmp    f0105f93 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105d55:	89 f0                	mov    %esi,%eax
f0105d57:	c1 e8 0c             	shr    $0xc,%eax
f0105d5a:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0105d60:	72 20                	jb     f0105d82 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105d62:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105d66:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f0105d6d:	f0 
f0105d6e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0105d75:	00 
f0105d76:	c7 04 24 c1 80 10 f0 	movl   $0xf01080c1,(%esp)
f0105d7d:	e8 be a2 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105d82:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0105d88:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105d8f:	00 
f0105d90:	c7 44 24 04 d6 80 10 	movl   $0xf01080d6,0x4(%esp)
f0105d97:	f0 
f0105d98:	89 1c 24             	mov    %ebx,(%esp)
f0105d9b:	e8 4f fc ff ff       	call   f01059ef <memcmp>
f0105da0:	85 c0                	test   %eax,%eax
f0105da2:	74 11                	je     f0105db5 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0105da4:	c7 04 24 64 7f 10 f0 	movl   $0xf0107f64,(%esp)
f0105dab:	e8 81 e3 ff ff       	call   f0104131 <cprintf>
f0105db0:	e9 de 01 00 00       	jmp    f0105f93 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105db5:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0105db9:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0105dbd:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105dc0:	85 ff                	test   %edi,%edi
f0105dc2:	7e 30                	jle    f0105df4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105dc4:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105dc9:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105dce:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0105dd5:	f0 
f0105dd6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105dd8:	83 c0 01             	add    $0x1,%eax
f0105ddb:	39 c7                	cmp    %eax,%edi
f0105ddd:	7f ef                	jg     f0105dce <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105ddf:	84 d2                	test   %dl,%dl
f0105de1:	74 11                	je     f0105df4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0105de3:	c7 04 24 98 7f 10 f0 	movl   $0xf0107f98,(%esp)
f0105dea:	e8 42 e3 ff ff       	call   f0104131 <cprintf>
f0105def:	e9 9f 01 00 00       	jmp    f0105f93 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0105df4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0105df8:	3c 04                	cmp    $0x4,%al
f0105dfa:	74 1e                	je     f0105e1a <mp_init+0x181>
f0105dfc:	3c 01                	cmp    $0x1,%al
f0105dfe:	66 90                	xchg   %ax,%ax
f0105e00:	74 18                	je     f0105e1a <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0105e02:	0f b6 c0             	movzbl %al,%eax
f0105e05:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105e09:	c7 04 24 bc 7f 10 f0 	movl   $0xf0107fbc,(%esp)
f0105e10:	e8 1c e3 ff ff       	call   f0104131 <cprintf>
f0105e15:	e9 79 01 00 00       	jmp    f0105f93 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105e1a:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0105e1e:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0105e22:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e24:	85 f6                	test   %esi,%esi
f0105e26:	7e 19                	jle    f0105e41 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105e28:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105e2d:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105e32:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0105e36:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e38:	83 c0 01             	add    $0x1,%eax
f0105e3b:	39 c6                	cmp    %eax,%esi
f0105e3d:	7f f3                	jg     f0105e32 <mp_init+0x199>
f0105e3f:	eb 05                	jmp    f0105e46 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105e41:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105e46:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0105e49:	74 11                	je     f0105e5c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0105e4b:	c7 04 24 dc 7f 10 f0 	movl   $0xf0107fdc,(%esp)
f0105e52:	e8 da e2 ff ff       	call   f0104131 <cprintf>
f0105e57:	e9 37 01 00 00       	jmp    f0105f93 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0105e5c:	85 db                	test   %ebx,%ebx
f0105e5e:	0f 84 2f 01 00 00    	je     f0105f93 <mp_init+0x2fa>
		return;
	ismp = 1;
f0105e64:	c7 05 00 40 22 f0 01 	movl   $0x1,0xf0224000
f0105e6b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0105e6e:	8b 43 24             	mov    0x24(%ebx),%eax
f0105e71:	a3 00 50 26 f0       	mov    %eax,0xf0265000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105e76:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0105e79:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0105e7e:	0f 84 94 00 00 00    	je     f0105f18 <mp_init+0x27f>
f0105e84:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0105e89:	0f b6 07             	movzbl (%edi),%eax
f0105e8c:	84 c0                	test   %al,%al
f0105e8e:	74 06                	je     f0105e96 <mp_init+0x1fd>
f0105e90:	3c 04                	cmp    $0x4,%al
f0105e92:	77 54                	ja     f0105ee8 <mp_init+0x24f>
f0105e94:	eb 4d                	jmp    f0105ee3 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0105e96:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0105e9a:	74 11                	je     f0105ead <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0105e9c:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f0105ea3:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0105ea8:	a3 c0 43 22 f0       	mov    %eax,0xf02243c0
			if (ncpu < NCPU) {
f0105ead:	a1 c4 43 22 f0       	mov    0xf02243c4,%eax
f0105eb2:	83 f8 07             	cmp    $0x7,%eax
f0105eb5:	7f 13                	jg     f0105eca <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0105eb7:	6b d0 74             	imul   $0x74,%eax,%edx
f0105eba:	88 82 20 40 22 f0    	mov    %al,-0xfddbfe0(%edx)
				ncpu++;
f0105ec0:	83 c0 01             	add    $0x1,%eax
f0105ec3:	a3 c4 43 22 f0       	mov    %eax,0xf02243c4
f0105ec8:	eb 14                	jmp    f0105ede <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0105eca:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0105ece:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ed2:	c7 04 24 0c 80 10 f0 	movl   $0xf010800c,(%esp)
f0105ed9:	e8 53 e2 ff ff       	call   f0104131 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0105ede:	83 c7 14             	add    $0x14,%edi
			continue;
f0105ee1:	eb 26                	jmp    f0105f09 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0105ee3:	83 c7 08             	add    $0x8,%edi
			continue;
f0105ee6:	eb 21                	jmp    f0105f09 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0105ee8:	0f b6 c0             	movzbl %al,%eax
f0105eeb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105eef:	c7 04 24 34 80 10 f0 	movl   $0xf0108034,(%esp)
f0105ef6:	e8 36 e2 ff ff       	call   f0104131 <cprintf>
			ismp = 0;
f0105efb:	c7 05 00 40 22 f0 00 	movl   $0x0,0xf0224000
f0105f02:	00 00 00 
			i = conf->entry;
f0105f05:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105f09:	83 c6 01             	add    $0x1,%esi
f0105f0c:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0105f10:	39 f0                	cmp    %esi,%eax
f0105f12:	0f 87 71 ff ff ff    	ja     f0105e89 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0105f18:	a1 c0 43 22 f0       	mov    0xf02243c0,%eax
f0105f1d:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0105f24:	83 3d 00 40 22 f0 00 	cmpl   $0x0,0xf0224000
f0105f2b:	75 22                	jne    f0105f4f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0105f2d:	c7 05 c4 43 22 f0 01 	movl   $0x1,0xf02243c4
f0105f34:	00 00 00 
		lapic = NULL;
f0105f37:	c7 05 00 50 26 f0 00 	movl   $0x0,0xf0265000
f0105f3e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0105f41:	c7 04 24 54 80 10 f0 	movl   $0xf0108054,(%esp)
f0105f48:	e8 e4 e1 ff ff       	call   f0104131 <cprintf>
		return;
f0105f4d:	eb 44                	jmp    f0105f93 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0105f4f:	8b 15 c4 43 22 f0    	mov    0xf02243c4,%edx
f0105f55:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105f59:	0f b6 00             	movzbl (%eax),%eax
f0105f5c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105f60:	c7 04 24 db 80 10 f0 	movl   $0xf01080db,(%esp)
f0105f67:	e8 c5 e1 ff ff       	call   f0104131 <cprintf>

	if (mp->imcrp) {
f0105f6c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105f6f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0105f73:	74 1e                	je     f0105f93 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0105f75:	c7 04 24 80 80 10 f0 	movl   $0xf0108080,(%esp)
f0105f7c:	e8 b0 e1 ff ff       	call   f0104131 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105f81:	ba 22 00 00 00       	mov    $0x22,%edx
f0105f86:	b8 70 00 00 00       	mov    $0x70,%eax
f0105f8b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0105f8c:	b2 23                	mov    $0x23,%dl
f0105f8e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0105f8f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105f92:	ee                   	out    %al,(%dx)
	}
}
f0105f93:	83 c4 2c             	add    $0x2c,%esp
f0105f96:	5b                   	pop    %ebx
f0105f97:	5e                   	pop    %esi
f0105f98:	5f                   	pop    %edi
f0105f99:	5d                   	pop    %ebp
f0105f9a:	c3                   	ret    

f0105f9b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f0105f9b:	55                   	push   %ebp
f0105f9c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0105f9e:	8b 0d 00 50 26 f0    	mov    0xf0265000,%ecx
f0105fa4:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0105fa7:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0105fa9:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105fae:	8b 40 20             	mov    0x20(%eax),%eax
}
f0105fb1:	5d                   	pop    %ebp
f0105fb2:	c3                   	ret    

f0105fb3 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0105fb3:	55                   	push   %ebp
f0105fb4:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0105fb6:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105fbb:	85 c0                	test   %eax,%eax
f0105fbd:	74 08                	je     f0105fc7 <cpunum+0x14>
		return lapic[ID] >> 24;
f0105fbf:	8b 40 20             	mov    0x20(%eax),%eax
f0105fc2:	c1 e8 18             	shr    $0x18,%eax
f0105fc5:	eb 05                	jmp    f0105fcc <cpunum+0x19>
	return 0;
f0105fc7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105fcc:	5d                   	pop    %ebp
f0105fcd:	c3                   	ret    

f0105fce <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f0105fce:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f0105fd5:	0f 84 0b 01 00 00    	je     f01060e6 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f0105fdb:	55                   	push   %ebp
f0105fdc:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f0105fde:	ba 27 01 00 00       	mov    $0x127,%edx
f0105fe3:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0105fe8:	e8 ae ff ff ff       	call   f0105f9b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f0105fed:	ba 0b 00 00 00       	mov    $0xb,%edx
f0105ff2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0105ff7:	e8 9f ff ff ff       	call   f0105f9b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f0105ffc:	ba 20 00 02 00       	mov    $0x20020,%edx
f0106001:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0106006:	e8 90 ff ff ff       	call   f0105f9b <lapicw>
	lapicw(TICR, 10000000); 
f010600b:	ba 80 96 98 00       	mov    $0x989680,%edx
f0106010:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0106015:	e8 81 ff ff ff       	call   f0105f9b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f010601a:	e8 94 ff ff ff       	call   f0105fb3 <cpunum>
f010601f:	6b c0 74             	imul   $0x74,%eax,%eax
f0106022:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0106027:	39 05 c0 43 22 f0    	cmp    %eax,0xf02243c0
f010602d:	74 0f                	je     f010603e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f010602f:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106034:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106039:	e8 5d ff ff ff       	call   f0105f9b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010603e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106043:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106048:	e8 4e ff ff ff       	call   f0105f9b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010604d:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0106052:	8b 40 30             	mov    0x30(%eax),%eax
f0106055:	c1 e8 10             	shr    $0x10,%eax
f0106058:	3c 03                	cmp    $0x3,%al
f010605a:	76 0f                	jbe    f010606b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010605c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106061:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106066:	e8 30 ff ff ff       	call   f0105f9b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f010606b:	ba 33 00 00 00       	mov    $0x33,%edx
f0106070:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106075:	e8 21 ff ff ff       	call   f0105f9b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010607a:	ba 00 00 00 00       	mov    $0x0,%edx
f010607f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106084:	e8 12 ff ff ff       	call   f0105f9b <lapicw>
	lapicw(ESR, 0);
f0106089:	ba 00 00 00 00       	mov    $0x0,%edx
f010608e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106093:	e8 03 ff ff ff       	call   f0105f9b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106098:	ba 00 00 00 00       	mov    $0x0,%edx
f010609d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01060a2:	e8 f4 fe ff ff       	call   f0105f9b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f01060a7:	ba 00 00 00 00       	mov    $0x0,%edx
f01060ac:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01060b1:	e8 e5 fe ff ff       	call   f0105f9b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f01060b6:	ba 00 85 08 00       	mov    $0x88500,%edx
f01060bb:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01060c0:	e8 d6 fe ff ff       	call   f0105f9b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f01060c5:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f01060cb:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01060d1:	f6 c4 10             	test   $0x10,%ah
f01060d4:	75 f5                	jne    f01060cb <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01060d6:	ba 00 00 00 00       	mov    $0x0,%edx
f01060db:	b8 20 00 00 00       	mov    $0x20,%eax
f01060e0:	e8 b6 fe ff ff       	call   f0105f9b <lapicw>
}
f01060e5:	5d                   	pop    %ebp
f01060e6:	f3 c3                	repz ret 

f01060e8 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f01060e8:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f01060ef:	74 13                	je     f0106104 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f01060f1:	55                   	push   %ebp
f01060f2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f01060f4:	ba 00 00 00 00       	mov    $0x0,%edx
f01060f9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01060fe:	e8 98 fe ff ff       	call   f0105f9b <lapicw>
}
f0106103:	5d                   	pop    %ebp
f0106104:	f3 c3                	repz ret 

f0106106 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0106106:	55                   	push   %ebp
f0106107:	89 e5                	mov    %esp,%ebp
f0106109:	56                   	push   %esi
f010610a:	53                   	push   %ebx
f010610b:	83 ec 10             	sub    $0x10,%esp
f010610e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0106111:	8b 75 0c             	mov    0xc(%ebp),%esi
f0106114:	ba 70 00 00 00       	mov    $0x70,%edx
f0106119:	b8 0f 00 00 00       	mov    $0xf,%eax
f010611e:	ee                   	out    %al,(%dx)
f010611f:	b2 71                	mov    $0x71,%dl
f0106121:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106126:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106127:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f010612e:	75 24                	jne    f0106154 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106130:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106137:	00 
f0106138:	c7 44 24 08 e4 66 10 	movl   $0xf01066e4,0x8(%esp)
f010613f:	f0 
f0106140:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106147:	00 
f0106148:	c7 04 24 f8 80 10 f0 	movl   $0xf01080f8,(%esp)
f010614f:	e8 ec 9e ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106154:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010615b:	00 00 
	wrv[1] = addr >> 4;
f010615d:	89 f0                	mov    %esi,%eax
f010615f:	c1 e8 04             	shr    $0x4,%eax
f0106162:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106168:	c1 e3 18             	shl    $0x18,%ebx
f010616b:	89 da                	mov    %ebx,%edx
f010616d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106172:	e8 24 fe ff ff       	call   f0105f9b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106177:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010617c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106181:	e8 15 fe ff ff       	call   f0105f9b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106186:	ba 00 85 00 00       	mov    $0x8500,%edx
f010618b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106190:	e8 06 fe ff ff       	call   f0105f9b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106195:	c1 ee 0c             	shr    $0xc,%esi
f0106198:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010619e:	89 da                	mov    %ebx,%edx
f01061a0:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01061a5:	e8 f1 fd ff ff       	call   f0105f9b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01061aa:	89 f2                	mov    %esi,%edx
f01061ac:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01061b1:	e8 e5 fd ff ff       	call   f0105f9b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f01061b6:	89 da                	mov    %ebx,%edx
f01061b8:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01061bd:	e8 d9 fd ff ff       	call   f0105f9b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01061c2:	89 f2                	mov    %esi,%edx
f01061c4:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01061c9:	e8 cd fd ff ff       	call   f0105f9b <lapicw>
		microdelay(200);
	}
}
f01061ce:	83 c4 10             	add    $0x10,%esp
f01061d1:	5b                   	pop    %ebx
f01061d2:	5e                   	pop    %esi
f01061d3:	5d                   	pop    %ebp
f01061d4:	c3                   	ret    

f01061d5 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f01061d5:	55                   	push   %ebp
f01061d6:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f01061d8:	8b 55 08             	mov    0x8(%ebp),%edx
f01061db:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f01061e1:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01061e6:	e8 b0 fd ff ff       	call   f0105f9b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f01061eb:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f01061f1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01061f7:	f6 c4 10             	test   $0x10,%ah
f01061fa:	75 f5                	jne    f01061f1 <lapic_ipi+0x1c>
		;
}
f01061fc:	5d                   	pop    %ebp
f01061fd:	c3                   	ret    

f01061fe <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f01061fe:	55                   	push   %ebp
f01061ff:	89 e5                	mov    %esp,%ebp
f0106201:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0106204:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f010620a:	8b 55 0c             	mov    0xc(%ebp),%edx
f010620d:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0106210:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0106217:	5d                   	pop    %ebp
f0106218:	c3                   	ret    

f0106219 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0106219:	55                   	push   %ebp
f010621a:	89 e5                	mov    %esp,%ebp
f010621c:	56                   	push   %esi
f010621d:	53                   	push   %ebx
f010621e:	83 ec 20             	sub    $0x20,%esp
f0106221:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106224:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106227:	74 14                	je     f010623d <spin_lock+0x24>
f0106229:	8b 73 08             	mov    0x8(%ebx),%esi
f010622c:	e8 82 fd ff ff       	call   f0105fb3 <cpunum>
f0106231:	6b c0 74             	imul   $0x74,%eax,%eax
f0106234:	05 20 40 22 f0       	add    $0xf0224020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106239:	39 c6                	cmp    %eax,%esi
f010623b:	74 15                	je     f0106252 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010623d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010623f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106244:	f0 87 03             	lock xchg %eax,(%ebx)
f0106247:	b9 01 00 00 00       	mov    $0x1,%ecx
f010624c:	85 c0                	test   %eax,%eax
f010624e:	75 2e                	jne    f010627e <spin_lock+0x65>
f0106250:	eb 37                	jmp    f0106289 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106252:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106255:	e8 59 fd ff ff       	call   f0105fb3 <cpunum>
f010625a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010625e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106262:	c7 44 24 08 08 81 10 	movl   $0xf0108108,0x8(%esp)
f0106269:	f0 
f010626a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106271:	00 
f0106272:	c7 04 24 6c 81 10 f0 	movl   $0xf010816c,(%esp)
f0106279:	e8 c2 9d ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010627e:	f3 90                	pause  
f0106280:	89 c8                	mov    %ecx,%eax
f0106282:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106285:	85 c0                	test   %eax,%eax
f0106287:	75 f5                	jne    f010627e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106289:	e8 25 fd ff ff       	call   f0105fb3 <cpunum>
f010628e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106291:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0106296:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106299:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010629c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010629e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01062a4:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f01062aa:	76 3a                	jbe    f01062e6 <spin_lock+0xcd>
f01062ac:	eb 31                	jmp    f01062df <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f01062ae:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01062b4:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f01062ba:	77 12                	ja     f01062ce <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01062bc:	8b 5a 04             	mov    0x4(%edx),%ebx
f01062bf:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01062c2:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01062c4:	83 c0 01             	add    $0x1,%eax
f01062c7:	83 f8 0a             	cmp    $0xa,%eax
f01062ca:	75 e2                	jne    f01062ae <spin_lock+0x95>
f01062cc:	eb 27                	jmp    f01062f5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f01062ce:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f01062d5:	83 c0 01             	add    $0x1,%eax
f01062d8:	83 f8 09             	cmp    $0x9,%eax
f01062db:	7e f1                	jle    f01062ce <spin_lock+0xb5>
f01062dd:	eb 16                	jmp    f01062f5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01062df:	b8 00 00 00 00       	mov    $0x0,%eax
f01062e4:	eb e8                	jmp    f01062ce <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01062e6:	8b 50 04             	mov    0x4(%eax),%edx
f01062e9:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01062ec:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01062ee:	b8 01 00 00 00       	mov    $0x1,%eax
f01062f3:	eb b9                	jmp    f01062ae <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f01062f5:	83 c4 20             	add    $0x20,%esp
f01062f8:	5b                   	pop    %ebx
f01062f9:	5e                   	pop    %esi
f01062fa:	5d                   	pop    %ebp
f01062fb:	c3                   	ret    

f01062fc <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f01062fc:	55                   	push   %ebp
f01062fd:	89 e5                	mov    %esp,%ebp
f01062ff:	57                   	push   %edi
f0106300:	56                   	push   %esi
f0106301:	53                   	push   %ebx
f0106302:	83 ec 6c             	sub    $0x6c,%esp
f0106305:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106308:	83 3b 00             	cmpl   $0x0,(%ebx)
f010630b:	74 18                	je     f0106325 <spin_unlock+0x29>
f010630d:	8b 73 08             	mov    0x8(%ebx),%esi
f0106310:	e8 9e fc ff ff       	call   f0105fb3 <cpunum>
f0106315:	6b c0 74             	imul   $0x74,%eax,%eax
f0106318:	05 20 40 22 f0       	add    $0xf0224020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f010631d:	39 c6                	cmp    %eax,%esi
f010631f:	0f 84 d4 00 00 00    	je     f01063f9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106325:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f010632c:	00 
f010632d:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106330:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106334:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106337:	89 04 24             	mov    %eax,(%esp)
f010633a:	e8 27 f6 ff ff       	call   f0105966 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010633f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106342:	0f b6 30             	movzbl (%eax),%esi
f0106345:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106348:	e8 66 fc ff ff       	call   f0105fb3 <cpunum>
f010634d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106351:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106355:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106359:	c7 04 24 34 81 10 f0 	movl   $0xf0108134,(%esp)
f0106360:	e8 cc dd ff ff       	call   f0104131 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106365:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106368:	85 c0                	test   %eax,%eax
f010636a:	74 71                	je     f01063dd <spin_unlock+0xe1>
f010636c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010636f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106372:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106375:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106379:	89 04 24             	mov    %eax,(%esp)
f010637c:	e8 8b e9 ff ff       	call   f0104d0c <debuginfo_eip>
f0106381:	85 c0                	test   %eax,%eax
f0106383:	78 39                	js     f01063be <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106385:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106387:	89 c2                	mov    %eax,%edx
f0106389:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010638c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106390:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106393:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106397:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010639a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010639e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f01063a1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01063a5:	8b 55 a8             	mov    -0x58(%ebp),%edx
f01063a8:	89 54 24 08          	mov    %edx,0x8(%esp)
f01063ac:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063b0:	c7 04 24 7c 81 10 f0 	movl   $0xf010817c,(%esp)
f01063b7:	e8 75 dd ff ff       	call   f0104131 <cprintf>
f01063bc:	eb 12                	jmp    f01063d0 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f01063be:	8b 03                	mov    (%ebx),%eax
f01063c0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063c4:	c7 04 24 93 81 10 f0 	movl   $0xf0108193,(%esp)
f01063cb:	e8 61 dd ff ff       	call   f0104131 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01063d0:	39 fb                	cmp    %edi,%ebx
f01063d2:	74 09                	je     f01063dd <spin_unlock+0xe1>
f01063d4:	83 c3 04             	add    $0x4,%ebx
f01063d7:	8b 03                	mov    (%ebx),%eax
f01063d9:	85 c0                	test   %eax,%eax
f01063db:	75 98                	jne    f0106375 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f01063dd:	c7 44 24 08 9b 81 10 	movl   $0xf010819b,0x8(%esp)
f01063e4:	f0 
f01063e5:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f01063ec:	00 
f01063ed:	c7 04 24 6c 81 10 f0 	movl   $0xf010816c,(%esp)
f01063f4:	e8 47 9c ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f01063f9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f0106400:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0106407:	b8 00 00 00 00       	mov    $0x0,%eax
f010640c:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f010640f:	83 c4 6c             	add    $0x6c,%esp
f0106412:	5b                   	pop    %ebx
f0106413:	5e                   	pop    %esi
f0106414:	5f                   	pop    %edi
f0106415:	5d                   	pop    %ebp
f0106416:	c3                   	ret    
f0106417:	66 90                	xchg   %ax,%ax
f0106419:	66 90                	xchg   %ax,%ax
f010641b:	66 90                	xchg   %ax,%ax
f010641d:	66 90                	xchg   %ax,%ax
f010641f:	90                   	nop

f0106420 <__udivdi3>:
f0106420:	55                   	push   %ebp
f0106421:	57                   	push   %edi
f0106422:	56                   	push   %esi
f0106423:	83 ec 0c             	sub    $0xc,%esp
f0106426:	8b 44 24 28          	mov    0x28(%esp),%eax
f010642a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010642e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106432:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106436:	85 c0                	test   %eax,%eax
f0106438:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010643c:	89 ea                	mov    %ebp,%edx
f010643e:	89 0c 24             	mov    %ecx,(%esp)
f0106441:	75 2d                	jne    f0106470 <__udivdi3+0x50>
f0106443:	39 e9                	cmp    %ebp,%ecx
f0106445:	77 61                	ja     f01064a8 <__udivdi3+0x88>
f0106447:	85 c9                	test   %ecx,%ecx
f0106449:	89 ce                	mov    %ecx,%esi
f010644b:	75 0b                	jne    f0106458 <__udivdi3+0x38>
f010644d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106452:	31 d2                	xor    %edx,%edx
f0106454:	f7 f1                	div    %ecx
f0106456:	89 c6                	mov    %eax,%esi
f0106458:	31 d2                	xor    %edx,%edx
f010645a:	89 e8                	mov    %ebp,%eax
f010645c:	f7 f6                	div    %esi
f010645e:	89 c5                	mov    %eax,%ebp
f0106460:	89 f8                	mov    %edi,%eax
f0106462:	f7 f6                	div    %esi
f0106464:	89 ea                	mov    %ebp,%edx
f0106466:	83 c4 0c             	add    $0xc,%esp
f0106469:	5e                   	pop    %esi
f010646a:	5f                   	pop    %edi
f010646b:	5d                   	pop    %ebp
f010646c:	c3                   	ret    
f010646d:	8d 76 00             	lea    0x0(%esi),%esi
f0106470:	39 e8                	cmp    %ebp,%eax
f0106472:	77 24                	ja     f0106498 <__udivdi3+0x78>
f0106474:	0f bd e8             	bsr    %eax,%ebp
f0106477:	83 f5 1f             	xor    $0x1f,%ebp
f010647a:	75 3c                	jne    f01064b8 <__udivdi3+0x98>
f010647c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106480:	39 34 24             	cmp    %esi,(%esp)
f0106483:	0f 86 9f 00 00 00    	jbe    f0106528 <__udivdi3+0x108>
f0106489:	39 d0                	cmp    %edx,%eax
f010648b:	0f 82 97 00 00 00    	jb     f0106528 <__udivdi3+0x108>
f0106491:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106498:	31 d2                	xor    %edx,%edx
f010649a:	31 c0                	xor    %eax,%eax
f010649c:	83 c4 0c             	add    $0xc,%esp
f010649f:	5e                   	pop    %esi
f01064a0:	5f                   	pop    %edi
f01064a1:	5d                   	pop    %ebp
f01064a2:	c3                   	ret    
f01064a3:	90                   	nop
f01064a4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01064a8:	89 f8                	mov    %edi,%eax
f01064aa:	f7 f1                	div    %ecx
f01064ac:	31 d2                	xor    %edx,%edx
f01064ae:	83 c4 0c             	add    $0xc,%esp
f01064b1:	5e                   	pop    %esi
f01064b2:	5f                   	pop    %edi
f01064b3:	5d                   	pop    %ebp
f01064b4:	c3                   	ret    
f01064b5:	8d 76 00             	lea    0x0(%esi),%esi
f01064b8:	89 e9                	mov    %ebp,%ecx
f01064ba:	8b 3c 24             	mov    (%esp),%edi
f01064bd:	d3 e0                	shl    %cl,%eax
f01064bf:	89 c6                	mov    %eax,%esi
f01064c1:	b8 20 00 00 00       	mov    $0x20,%eax
f01064c6:	29 e8                	sub    %ebp,%eax
f01064c8:	89 c1                	mov    %eax,%ecx
f01064ca:	d3 ef                	shr    %cl,%edi
f01064cc:	89 e9                	mov    %ebp,%ecx
f01064ce:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01064d2:	8b 3c 24             	mov    (%esp),%edi
f01064d5:	09 74 24 08          	or     %esi,0x8(%esp)
f01064d9:	89 d6                	mov    %edx,%esi
f01064db:	d3 e7                	shl    %cl,%edi
f01064dd:	89 c1                	mov    %eax,%ecx
f01064df:	89 3c 24             	mov    %edi,(%esp)
f01064e2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01064e6:	d3 ee                	shr    %cl,%esi
f01064e8:	89 e9                	mov    %ebp,%ecx
f01064ea:	d3 e2                	shl    %cl,%edx
f01064ec:	89 c1                	mov    %eax,%ecx
f01064ee:	d3 ef                	shr    %cl,%edi
f01064f0:	09 d7                	or     %edx,%edi
f01064f2:	89 f2                	mov    %esi,%edx
f01064f4:	89 f8                	mov    %edi,%eax
f01064f6:	f7 74 24 08          	divl   0x8(%esp)
f01064fa:	89 d6                	mov    %edx,%esi
f01064fc:	89 c7                	mov    %eax,%edi
f01064fe:	f7 24 24             	mull   (%esp)
f0106501:	39 d6                	cmp    %edx,%esi
f0106503:	89 14 24             	mov    %edx,(%esp)
f0106506:	72 30                	jb     f0106538 <__udivdi3+0x118>
f0106508:	8b 54 24 04          	mov    0x4(%esp),%edx
f010650c:	89 e9                	mov    %ebp,%ecx
f010650e:	d3 e2                	shl    %cl,%edx
f0106510:	39 c2                	cmp    %eax,%edx
f0106512:	73 05                	jae    f0106519 <__udivdi3+0xf9>
f0106514:	3b 34 24             	cmp    (%esp),%esi
f0106517:	74 1f                	je     f0106538 <__udivdi3+0x118>
f0106519:	89 f8                	mov    %edi,%eax
f010651b:	31 d2                	xor    %edx,%edx
f010651d:	e9 7a ff ff ff       	jmp    f010649c <__udivdi3+0x7c>
f0106522:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106528:	31 d2                	xor    %edx,%edx
f010652a:	b8 01 00 00 00       	mov    $0x1,%eax
f010652f:	e9 68 ff ff ff       	jmp    f010649c <__udivdi3+0x7c>
f0106534:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106538:	8d 47 ff             	lea    -0x1(%edi),%eax
f010653b:	31 d2                	xor    %edx,%edx
f010653d:	83 c4 0c             	add    $0xc,%esp
f0106540:	5e                   	pop    %esi
f0106541:	5f                   	pop    %edi
f0106542:	5d                   	pop    %ebp
f0106543:	c3                   	ret    
f0106544:	66 90                	xchg   %ax,%ax
f0106546:	66 90                	xchg   %ax,%ax
f0106548:	66 90                	xchg   %ax,%ax
f010654a:	66 90                	xchg   %ax,%ax
f010654c:	66 90                	xchg   %ax,%ax
f010654e:	66 90                	xchg   %ax,%ax

f0106550 <__umoddi3>:
f0106550:	55                   	push   %ebp
f0106551:	57                   	push   %edi
f0106552:	56                   	push   %esi
f0106553:	83 ec 14             	sub    $0x14,%esp
f0106556:	8b 44 24 28          	mov    0x28(%esp),%eax
f010655a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010655e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106562:	89 c7                	mov    %eax,%edi
f0106564:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106568:	8b 44 24 30          	mov    0x30(%esp),%eax
f010656c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106570:	89 34 24             	mov    %esi,(%esp)
f0106573:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106577:	85 c0                	test   %eax,%eax
f0106579:	89 c2                	mov    %eax,%edx
f010657b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010657f:	75 17                	jne    f0106598 <__umoddi3+0x48>
f0106581:	39 fe                	cmp    %edi,%esi
f0106583:	76 4b                	jbe    f01065d0 <__umoddi3+0x80>
f0106585:	89 c8                	mov    %ecx,%eax
f0106587:	89 fa                	mov    %edi,%edx
f0106589:	f7 f6                	div    %esi
f010658b:	89 d0                	mov    %edx,%eax
f010658d:	31 d2                	xor    %edx,%edx
f010658f:	83 c4 14             	add    $0x14,%esp
f0106592:	5e                   	pop    %esi
f0106593:	5f                   	pop    %edi
f0106594:	5d                   	pop    %ebp
f0106595:	c3                   	ret    
f0106596:	66 90                	xchg   %ax,%ax
f0106598:	39 f8                	cmp    %edi,%eax
f010659a:	77 54                	ja     f01065f0 <__umoddi3+0xa0>
f010659c:	0f bd e8             	bsr    %eax,%ebp
f010659f:	83 f5 1f             	xor    $0x1f,%ebp
f01065a2:	75 5c                	jne    f0106600 <__umoddi3+0xb0>
f01065a4:	8b 7c 24 08          	mov    0x8(%esp),%edi
f01065a8:	39 3c 24             	cmp    %edi,(%esp)
f01065ab:	0f 87 e7 00 00 00    	ja     f0106698 <__umoddi3+0x148>
f01065b1:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01065b5:	29 f1                	sub    %esi,%ecx
f01065b7:	19 c7                	sbb    %eax,%edi
f01065b9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01065bd:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01065c1:	8b 44 24 08          	mov    0x8(%esp),%eax
f01065c5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01065c9:	83 c4 14             	add    $0x14,%esp
f01065cc:	5e                   	pop    %esi
f01065cd:	5f                   	pop    %edi
f01065ce:	5d                   	pop    %ebp
f01065cf:	c3                   	ret    
f01065d0:	85 f6                	test   %esi,%esi
f01065d2:	89 f5                	mov    %esi,%ebp
f01065d4:	75 0b                	jne    f01065e1 <__umoddi3+0x91>
f01065d6:	b8 01 00 00 00       	mov    $0x1,%eax
f01065db:	31 d2                	xor    %edx,%edx
f01065dd:	f7 f6                	div    %esi
f01065df:	89 c5                	mov    %eax,%ebp
f01065e1:	8b 44 24 04          	mov    0x4(%esp),%eax
f01065e5:	31 d2                	xor    %edx,%edx
f01065e7:	f7 f5                	div    %ebp
f01065e9:	89 c8                	mov    %ecx,%eax
f01065eb:	f7 f5                	div    %ebp
f01065ed:	eb 9c                	jmp    f010658b <__umoddi3+0x3b>
f01065ef:	90                   	nop
f01065f0:	89 c8                	mov    %ecx,%eax
f01065f2:	89 fa                	mov    %edi,%edx
f01065f4:	83 c4 14             	add    $0x14,%esp
f01065f7:	5e                   	pop    %esi
f01065f8:	5f                   	pop    %edi
f01065f9:	5d                   	pop    %ebp
f01065fa:	c3                   	ret    
f01065fb:	90                   	nop
f01065fc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106600:	8b 04 24             	mov    (%esp),%eax
f0106603:	be 20 00 00 00       	mov    $0x20,%esi
f0106608:	89 e9                	mov    %ebp,%ecx
f010660a:	29 ee                	sub    %ebp,%esi
f010660c:	d3 e2                	shl    %cl,%edx
f010660e:	89 f1                	mov    %esi,%ecx
f0106610:	d3 e8                	shr    %cl,%eax
f0106612:	89 e9                	mov    %ebp,%ecx
f0106614:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106618:	8b 04 24             	mov    (%esp),%eax
f010661b:	09 54 24 04          	or     %edx,0x4(%esp)
f010661f:	89 fa                	mov    %edi,%edx
f0106621:	d3 e0                	shl    %cl,%eax
f0106623:	89 f1                	mov    %esi,%ecx
f0106625:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106629:	8b 44 24 10          	mov    0x10(%esp),%eax
f010662d:	d3 ea                	shr    %cl,%edx
f010662f:	89 e9                	mov    %ebp,%ecx
f0106631:	d3 e7                	shl    %cl,%edi
f0106633:	89 f1                	mov    %esi,%ecx
f0106635:	d3 e8                	shr    %cl,%eax
f0106637:	89 e9                	mov    %ebp,%ecx
f0106639:	09 f8                	or     %edi,%eax
f010663b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f010663f:	f7 74 24 04          	divl   0x4(%esp)
f0106643:	d3 e7                	shl    %cl,%edi
f0106645:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106649:	89 d7                	mov    %edx,%edi
f010664b:	f7 64 24 08          	mull   0x8(%esp)
f010664f:	39 d7                	cmp    %edx,%edi
f0106651:	89 c1                	mov    %eax,%ecx
f0106653:	89 14 24             	mov    %edx,(%esp)
f0106656:	72 2c                	jb     f0106684 <__umoddi3+0x134>
f0106658:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010665c:	72 22                	jb     f0106680 <__umoddi3+0x130>
f010665e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106662:	29 c8                	sub    %ecx,%eax
f0106664:	19 d7                	sbb    %edx,%edi
f0106666:	89 e9                	mov    %ebp,%ecx
f0106668:	89 fa                	mov    %edi,%edx
f010666a:	d3 e8                	shr    %cl,%eax
f010666c:	89 f1                	mov    %esi,%ecx
f010666e:	d3 e2                	shl    %cl,%edx
f0106670:	89 e9                	mov    %ebp,%ecx
f0106672:	d3 ef                	shr    %cl,%edi
f0106674:	09 d0                	or     %edx,%eax
f0106676:	89 fa                	mov    %edi,%edx
f0106678:	83 c4 14             	add    $0x14,%esp
f010667b:	5e                   	pop    %esi
f010667c:	5f                   	pop    %edi
f010667d:	5d                   	pop    %ebp
f010667e:	c3                   	ret    
f010667f:	90                   	nop
f0106680:	39 d7                	cmp    %edx,%edi
f0106682:	75 da                	jne    f010665e <__umoddi3+0x10e>
f0106684:	8b 14 24             	mov    (%esp),%edx
f0106687:	89 c1                	mov    %eax,%ecx
f0106689:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010668d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106691:	eb cb                	jmp    f010665e <__umoddi3+0x10e>
f0106693:	90                   	nop
f0106694:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106698:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010669c:	0f 82 0f ff ff ff    	jb     f01065b1 <__umoddi3+0x61>
f01066a2:	e9 1a ff ff ff       	jmp    f01065c1 <__umoddi3+0x71>
