
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
f010004b:	83 3d 00 3f 22 f0 00 	cmpl   $0x0,0xf0223f00
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 00 3f 22 f0    	mov    %esi,0xf0223f00

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 8f 5f 00 00       	call   f0105ff3 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 00 67 10 f0 	movl   $0xf0106700,(%esp)
f010007d:	e8 f7 40 00 00       	call   f0104179 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 b8 40 00 00       	call   f0104146 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 bb 6d 10 f0 	movl   $0xf0106dbb,(%esp)
f0100095:	e8 df 40 00 00       	call   f0104179 <cprintf>
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
f01000cc:	e8 88 58 00 00       	call   f0105959 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 09 06 00 00       	call   f01006df <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 6c 67 10 f0 	movl   $0xf010676c,(%esp)
f01000e5:	e8 8f 40 00 00       	call   f0104179 <cprintf>

	// Lab 2 memory management initialization functions
	cprintf("mem_init 1!\n", 6828);
f01000ea:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000f1:	00 
f01000f2:	c7 04 24 87 67 10 f0 	movl   $0xf0106787,(%esp)
f01000f9:	e8 7b 40 00 00       	call   f0104179 <cprintf>
	mem_init();
f01000fe:	e8 7a 13 00 00       	call   f010147d <mem_init>
	cprintf("mem_init 2!\n", 6828);
f0100103:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f010010a:	00 
f010010b:	c7 04 24 94 67 10 f0 	movl   $0xf0106794,(%esp)
f0100112:	e8 62 40 00 00       	call   f0104179 <cprintf>
	// Lab 3 user environment initialization functions
	env_init();
f0100117:	e8 76 37 00 00       	call   f0103892 <env_init>
	trap_init();
f010011c:	e8 dc 40 00 00       	call   f01041fd <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f0100121:	e8 b3 5b 00 00       	call   f0105cd9 <mp_init>
	lapic_init();
f0100126:	e8 e3 5e 00 00       	call   f010600e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f010012b:	90                   	nop
f010012c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100130:	e8 71 3f 00 00       	call   f01040a6 <pic_init>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100135:	83 3d 08 3f 22 f0 07 	cmpl   $0x7,0xf0223f08
f010013c:	77 24                	ja     f0100162 <i386_init+0xba>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010013e:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100145:	00 
f0100146:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f010014d:	f0 
f010014e:	c7 44 24 04 59 00 00 	movl   $0x59,0x4(%esp)
f0100155:	00 
f0100156:	c7 04 24 a1 67 10 f0 	movl   $0xf01067a1,(%esp)
f010015d:	e8 de fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100162:	b8 06 5c 10 f0       	mov    $0xf0105c06,%eax
f0100167:	2d 8c 5b 10 f0       	sub    $0xf0105b8c,%eax
f010016c:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100170:	c7 44 24 04 8c 5b 10 	movl   $0xf0105b8c,0x4(%esp)
f0100177:	f0 
f0100178:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f010017f:	e8 22 58 00 00       	call   f01059a6 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100184:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f010018b:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0100190:	3d 20 40 22 f0       	cmp    $0xf0224020,%eax
f0100195:	0f 86 a6 00 00 00    	jbe    f0100241 <i386_init+0x199>
f010019b:	bb 20 40 22 f0       	mov    $0xf0224020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f01001a0:	e8 4e 5e 00 00       	call   f0105ff3 <cpunum>
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
f01001ca:	a3 04 3f 22 f0       	mov    %eax,0xf0223f04
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001cf:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001d6:	00 
f01001d7:	0f b6 03             	movzbl (%ebx),%eax
f01001da:	89 04 24             	mov    %eax,(%esp)
f01001dd:	e8 64 5f 00 00       	call   f0106146 <lapic_startap>
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
f0100216:	e8 a9 38 00 00       	call   f0103ac4 <env_create>
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
f0100237:	e8 88 38 00 00       	call   f0103ac4 <env_create>
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f010023c:	e8 10 48 00 00       	call   f0104a51 <sched_yield>
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
f010024e:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100253:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100258:	77 20                	ja     f010027a <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010025a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010025e:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0100265:	f0 
f0100266:	c7 44 24 04 70 00 00 	movl   $0x70,0x4(%esp)
f010026d:	00 
f010026e:	c7 04 24 a1 67 10 f0 	movl   $0xf01067a1,(%esp)
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
f0100282:	e8 6c 5d 00 00       	call   f0105ff3 <cpunum>
f0100287:	89 44 24 04          	mov    %eax,0x4(%esp)
f010028b:	c7 04 24 ad 67 10 f0 	movl   $0xf01067ad,(%esp)
f0100292:	e8 e2 3e 00 00       	call   f0104179 <cprintf>

	lapic_init();
f0100297:	e8 72 5d 00 00       	call   f010600e <lapic_init>
	env_init_percpu();
f010029c:	e8 c7 35 00 00       	call   f0103868 <env_init_percpu>
	trap_init_percpu();
f01002a1:	e8 fa 3e 00 00       	call   f01041a0 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f01002a6:	e8 48 5d 00 00       	call   f0105ff3 <cpunum>
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
f01002d7:	c7 04 24 c3 67 10 f0 	movl   $0xf01067c3,(%esp)
f01002de:	e8 96 3e 00 00       	call   f0104179 <cprintf>
	vcprintf(fmt, ap);
f01002e3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002e7:	8b 45 10             	mov    0x10(%ebp),%eax
f01002ea:	89 04 24             	mov    %eax,(%esp)
f01002ed:	e8 54 3e 00 00       	call   f0104146 <vcprintf>
	cprintf("\n");
f01002f2:	c7 04 24 bb 6d 10 f0 	movl   $0xf0106dbb,(%esp)
f01002f9:	e8 7b 3e 00 00       	call   f0104179 <cprintf>
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
f01003b5:	0f b6 82 40 69 10 f0 	movzbl -0xfef96c0(%edx),%eax
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
f01003f2:	0f b6 82 40 69 10 f0 	movzbl -0xfef96c0(%edx),%eax
f01003f9:	0b 05 00 30 22 f0    	or     0xf0223000,%eax
	shift ^= togglecode[data];
f01003ff:	0f b6 8a 40 68 10 f0 	movzbl -0xfef97c0(%edx),%ecx
f0100406:	31 c8                	xor    %ecx,%eax
f0100408:	a3 00 30 22 f0       	mov    %eax,0xf0223000

	c = charcode[shift & (CTL | SHIFT)][data];
f010040d:	89 c1                	mov    %eax,%ecx
f010040f:	83 e1 03             	and    $0x3,%ecx
f0100412:	8b 0c 8d 20 68 10 f0 	mov    -0xfef97e0(,%ecx,4),%ecx
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
f0100452:	c7 04 24 dd 67 10 f0 	movl   $0xf01067dd,(%esp)
f0100459:	e8 1b 3d 00 00       	call   f0104179 <cprintf>
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
f0100609:	e8 98 53 00 00       	call   f01059a6 <memmove>
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
f0100777:	e8 bb 38 00 00       	call   f0104037 <irq_setmask_8259A>
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
f01007d9:	c7 04 24 e9 67 10 f0 	movl   $0xf01067e9,(%esp)
f01007e0:	e8 94 39 00 00       	call   f0104179 <cprintf>
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
f0100826:	c7 44 24 08 40 6a 10 	movl   $0xf0106a40,0x8(%esp)
f010082d:	f0 
f010082e:	c7 44 24 04 5e 6a 10 	movl   $0xf0106a5e,0x4(%esp)
f0100835:	f0 
f0100836:	c7 04 24 63 6a 10 f0 	movl   $0xf0106a63,(%esp)
f010083d:	e8 37 39 00 00       	call   f0104179 <cprintf>
f0100842:	c7 44 24 08 08 6b 10 	movl   $0xf0106b08,0x8(%esp)
f0100849:	f0 
f010084a:	c7 44 24 04 6c 6a 10 	movl   $0xf0106a6c,0x4(%esp)
f0100851:	f0 
f0100852:	c7 04 24 63 6a 10 f0 	movl   $0xf0106a63,(%esp)
f0100859:	e8 1b 39 00 00       	call   f0104179 <cprintf>
f010085e:	c7 44 24 08 75 6a 10 	movl   $0xf0106a75,0x8(%esp)
f0100865:	f0 
f0100866:	c7 44 24 04 93 6a 10 	movl   $0xf0106a93,0x4(%esp)
f010086d:	f0 
f010086e:	c7 04 24 63 6a 10 f0 	movl   $0xf0106a63,(%esp)
f0100875:	e8 ff 38 00 00       	call   f0104179 <cprintf>
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
f0100887:	c7 04 24 a1 6a 10 f0 	movl   $0xf0106aa1,(%esp)
f010088e:	e8 e6 38 00 00       	call   f0104179 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100893:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010089a:	00 
f010089b:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008a2:	f0 
f01008a3:	c7 04 24 30 6b 10 f0 	movl   $0xf0106b30,(%esp)
f01008aa:	e8 ca 38 00 00       	call   f0104179 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008af:	c7 44 24 08 e7 66 10 	movl   $0x1066e7,0x8(%esp)
f01008b6:	00 
f01008b7:	c7 44 24 04 e7 66 10 	movl   $0xf01066e7,0x4(%esp)
f01008be:	f0 
f01008bf:	c7 04 24 54 6b 10 f0 	movl   $0xf0106b54,(%esp)
f01008c6:	e8 ae 38 00 00       	call   f0104179 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008cb:	c7 44 24 08 88 21 22 	movl   $0x222188,0x8(%esp)
f01008d2:	00 
f01008d3:	c7 44 24 04 88 21 22 	movl   $0xf0222188,0x4(%esp)
f01008da:	f0 
f01008db:	c7 04 24 78 6b 10 f0 	movl   $0xf0106b78,(%esp)
f01008e2:	e8 92 38 00 00       	call   f0104179 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008e7:	c7 44 24 08 04 50 26 	movl   $0x265004,0x8(%esp)
f01008ee:	00 
f01008ef:	c7 44 24 04 04 50 26 	movl   $0xf0265004,0x4(%esp)
f01008f6:	f0 
f01008f7:	c7 04 24 9c 6b 10 f0 	movl   $0xf0106b9c,(%esp)
f01008fe:	e8 76 38 00 00       	call   f0104179 <cprintf>
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
f010091f:	c7 04 24 c0 6b 10 f0 	movl   $0xf0106bc0,(%esp)
f0100926:	e8 4e 38 00 00       	call   f0104179 <cprintf>
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
f010093b:	c7 04 24 ba 6a 10 f0 	movl   $0xf0106aba,(%esp)
f0100942:	e8 32 38 00 00       	call   f0104179 <cprintf>
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
f010098a:	c7 04 24 ec 6b 10 f0 	movl   $0xf0106bec,(%esp)
f0100991:	e8 e3 37 00 00       	call   f0104179 <cprintf>
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
f01009b0:	c7 04 24 20 6c 10 f0 	movl   $0xf0106c20,(%esp)
f01009b7:	e8 bd 37 00 00       	call   f0104179 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009bc:	c7 04 24 44 6c 10 f0 	movl   $0xf0106c44,(%esp)
f01009c3:	e8 b1 37 00 00       	call   f0104179 <cprintf>

	if (tf != NULL)
f01009c8:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009cc:	74 0b                	je     f01009d9 <monitor+0x32>
		print_trapframe(tf);
f01009ce:	8b 45 08             	mov    0x8(%ebp),%eax
f01009d1:	89 04 24             	mov    %eax,(%esp)
f01009d4:	e8 db 3b 00 00       	call   f01045b4 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009d9:	c7 04 24 cc 6a 10 f0 	movl   $0xf0106acc,(%esp)
f01009e0:	e8 9b 4c 00 00       	call   f0105680 <readline>
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
f0100a11:	c7 04 24 d0 6a 10 f0 	movl   $0xf0106ad0,(%esp)
f0100a18:	e8 dc 4e 00 00       	call   f01058f9 <strchr>
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
f0100a33:	c7 04 24 d5 6a 10 f0 	movl   $0xf0106ad5,(%esp)
f0100a3a:	e8 3a 37 00 00       	call   f0104179 <cprintf>
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
f0100a62:	c7 04 24 d0 6a 10 f0 	movl   $0xf0106ad0,(%esp)
f0100a69:	e8 8b 4e 00 00       	call   f01058f9 <strchr>
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
f0100a8c:	8b 04 85 80 6c 10 f0 	mov    -0xfef9380(,%eax,4),%eax
f0100a93:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a97:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100a9a:	89 04 24             	mov    %eax,(%esp)
f0100a9d:	e8 d3 4d 00 00       	call   f0105875 <strcmp>
f0100aa2:	85 c0                	test   %eax,%eax
f0100aa4:	75 24                	jne    f0100aca <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100aa6:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100aa9:	8b 55 08             	mov    0x8(%ebp),%edx
f0100aac:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100ab0:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ab3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100ab7:	89 34 24             	mov    %esi,(%esp)
f0100aba:	ff 14 85 88 6c 10 f0 	call   *-0xfef9378(,%eax,4)
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
f0100ad9:	c7 04 24 f2 6a 10 f0 	movl   $0xf0106af2,(%esp)
f0100ae0:	e8 94 36 00 00       	call   f0104179 <cprintf>
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
f0100b09:	c7 04 24 a4 6c 10 f0 	movl   $0xf0106ca4,(%esp)
f0100b10:	e8 64 36 00 00       	call   f0104179 <cprintf>
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
f0100b62:	3b 0d 08 3f 22 f0    	cmp    0xf0223f08,%ecx
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
f0100b74:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0100b7b:	f0 
f0100b7c:	c7 44 24 04 c1 03 00 	movl   $0x3c1,0x4(%esp)
f0100b83:	00 
f0100b84:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
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
f0100bc6:	c7 04 24 bd 6c 10 f0 	movl   $0xf0106cbd,(%esp)
f0100bcd:	e8 a7 35 00 00       	call   f0104179 <cprintf>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100bd2:	85 db                	test   %ebx,%ebx
f0100bd4:	0f 85 6a 03 00 00    	jne    f0100f44 <check_page_free_list+0x389>
f0100bda:	e9 77 03 00 00       	jmp    f0100f56 <check_page_free_list+0x39b>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100bdf:	c7 44 24 08 80 70 10 	movl   $0xf0107080,0x8(%esp)
f0100be6:	f0 
f0100be7:	c7 44 24 04 e4 02 00 	movl   $0x2e4,0x4(%esp)
f0100bee:	00 
f0100bef:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
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
f0100c09:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
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
f0100c51:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
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
f0100c6b:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f0100c71:	72 20                	jb     f0100c93 <check_page_free_list+0xd8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100c73:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100c77:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0100c7e:	f0 
f0100c7f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100c86:	00 
f0100c87:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0100c8e:	e8 ad f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100c93:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100c9a:	00 
f0100c9b:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ca2:	00 
	return (void *)(pa + KERNBASE);
f0100ca3:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100ca8:	89 04 24             	mov    %eax,(%esp)
f0100cab:	e8 a9 4c 00 00       	call   f0105959 <memset>
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
f0100cd1:	8b 3d 10 3f 22 f0    	mov    0xf0223f10,%edi
f0100cd7:	39 fa                	cmp    %edi,%edx
f0100cd9:	72 3f                	jb     f0100d1a <check_page_free_list+0x15f>
		assert(pp < pages + npages);
f0100cdb:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
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
f0100d1a:	c7 44 24 0c e0 6c 10 	movl   $0xf0106ce0,0xc(%esp)
f0100d21:	f0 
f0100d22:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100d29:	f0 
f0100d2a:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0100d31:	00 
f0100d32:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100d39:	e8 02 f3 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d3e:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100d41:	72 24                	jb     f0100d67 <check_page_free_list+0x1ac>
f0100d43:	c7 44 24 0c 01 6d 10 	movl   $0xf0106d01,0xc(%esp)
f0100d4a:	f0 
f0100d4b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100d52:	f0 
f0100d53:	c7 44 24 04 00 03 00 	movl   $0x300,0x4(%esp)
f0100d5a:	00 
f0100d5b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100d62:	e8 d9 f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d67:	89 d0                	mov    %edx,%eax
f0100d69:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100d6c:	a8 07                	test   $0x7,%al
f0100d6e:	74 24                	je     f0100d94 <check_page_free_list+0x1d9>
f0100d70:	c7 44 24 0c a4 70 10 	movl   $0xf01070a4,0xc(%esp)
f0100d77:	f0 
f0100d78:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100d7f:	f0 
f0100d80:	c7 44 24 04 01 03 00 	movl   $0x301,0x4(%esp)
f0100d87:	00 
f0100d88:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100d8f:	e8 ac f2 ff ff       	call   f0100040 <_panic>
f0100d94:	c1 f8 03             	sar    $0x3,%eax
f0100d97:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d9a:	85 c0                	test   %eax,%eax
f0100d9c:	75 24                	jne    f0100dc2 <check_page_free_list+0x207>
f0100d9e:	c7 44 24 0c 15 6d 10 	movl   $0xf0106d15,0xc(%esp)
f0100da5:	f0 
f0100da6:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100dad:	f0 
f0100dae:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
f0100db5:	00 
f0100db6:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100dbd:	e8 7e f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100dc2:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100dc7:	75 31                	jne    f0100dfa <check_page_free_list+0x23f>
f0100dc9:	c7 44 24 0c 26 6d 10 	movl   $0xf0106d26,0xc(%esp)
f0100dd0:	f0 
f0100dd1:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100dd8:	f0 
f0100dd9:	c7 44 24 04 05 03 00 	movl   $0x305,0x4(%esp)
f0100de0:	00 
f0100de1:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
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
f0100e01:	c7 44 24 0c d8 70 10 	movl   $0xf01070d8,0xc(%esp)
f0100e08:	f0 
f0100e09:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100e10:	f0 
f0100e11:	c7 44 24 04 06 03 00 	movl   $0x306,0x4(%esp)
f0100e18:	00 
f0100e19:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100e20:	e8 1b f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e25:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e2a:	75 24                	jne    f0100e50 <check_page_free_list+0x295>
f0100e2c:	c7 44 24 0c 3f 6d 10 	movl   $0xf0106d3f,0xc(%esp)
f0100e33:	f0 
f0100e34:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100e3b:	f0 
f0100e3c:	c7 44 24 04 07 03 00 	movl   $0x307,0x4(%esp)
f0100e43:	00 
f0100e44:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
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
f0100e6b:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0100e72:	f0 
f0100e73:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100e7a:	00 
f0100e7b:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0100e82:	e8 b9 f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100e87:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100e8d:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100e90:	0f 86 df 00 00 00    	jbe    f0100f75 <check_page_free_list+0x3ba>
f0100e96:	c7 44 24 0c fc 70 10 	movl   $0xf01070fc,0xc(%esp)
f0100e9d:	f0 
f0100e9e:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100ea5:	f0 
f0100ea6:	c7 44 24 04 08 03 00 	movl   $0x308,0x4(%esp)
f0100ead:	00 
f0100eae:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100eb5:	e8 86 f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100eba:	c7 44 24 0c 59 6d 10 	movl   $0xf0106d59,0xc(%esp)
f0100ec1:	f0 
f0100ec2:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100ec9:	f0 
f0100eca:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f0100ed1:	00 
f0100ed2:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
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
f0100ef8:	c7 44 24 0c 76 6d 10 	movl   $0xf0106d76,0xc(%esp)
f0100eff:	f0 
f0100f00:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100f07:	f0 
f0100f08:	c7 44 24 04 12 03 00 	movl   $0x312,0x4(%esp)
f0100f0f:	00 
f0100f10:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100f17:	e8 24 f1 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f1c:	85 db                	test   %ebx,%ebx
f0100f1e:	7f 75                	jg     f0100f95 <check_page_free_list+0x3da>
f0100f20:	c7 44 24 0c 88 6d 10 	movl   $0xf0106d88,0xc(%esp)
f0100f27:	f0 
f0100f28:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0100f2f:	f0 
f0100f30:	c7 44 24 04 13 03 00 	movl   $0x313,0x4(%esp)
f0100f37:	00 
f0100f38:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
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
//<<<<<<< HEAD
	cprintf("page_init\r\n");
f0100fa5:	c7 04 24 99 6d 10 f0 	movl   $0xf0106d99,(%esp)
f0100fac:	e8 c8 31 00 00       	call   f0104179 <cprintf>
//=======
	// LAB 4:
	// Change your code to mark the physical page at MPENTRY_PADDR
	// as in use
	size_t left_i = PGNUM(IOPHYSMEM);
        size_t right_i = PGNUM(PADDR(envs + NENV));
f0100fb1:	a1 48 32 22 f0       	mov    0xf0223248,%eax
f0100fb6:	8d 88 00 f0 01 00    	lea    0x1f000(%eax),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100fbc:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0100fc2:	77 20                	ja     f0100fe4 <page_init+0x47>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100fc4:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0100fc8:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0100fcf:	f0 
f0100fd0:	c7 44 24 04 50 01 00 	movl   $0x150,0x4(%esp)
f0100fd7:	00 
f0100fd8:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0100fdf:	e8 5c f0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100fe4:	81 c1 00 00 00 10    	add    $0x10000000,%ecx
f0100fea:	c1 e9 0c             	shr    $0xc,%ecx
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0100fed:	83 3d 08 3f 22 f0 00 	cmpl   $0x0,0xf0223f08
f0100ff4:	0f 84 e0 00 00 00    	je     f01010da <page_init+0x13d>
f0100ffa:	8b 35 40 32 22 f0    	mov    0xf0223240,%esi
f0101000:	b8 00 00 00 00       	mov    $0x0,%eax
	 if ((i < left_i || i > right_i) && i != PGNUM(MPENTRY_PADDR)) {
f0101005:	39 c8                	cmp    %ecx,%eax
f0101007:	77 07                	ja     f0101010 <page_init+0x73>
f0101009:	3d 9f 00 00 00       	cmp    $0x9f,%eax
f010100e:	77 24                	ja     f0101034 <page_init+0x97>
f0101010:	83 f8 07             	cmp    $0x7,%eax
f0101013:	74 1f                	je     f0101034 <page_init+0x97>
f0101015:	8d 14 c5 00 00 00 00 	lea    0x0(,%eax,8),%edx
		pages[i].pp_ref = 0;
f010101c:	89 d3                	mov    %edx,%ebx
f010101e:	03 1d 10 3f 22 f0    	add    0xf0223f10,%ebx
f0101024:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
		pages[i].pp_link = page_free_list;
f010102a:	89 33                	mov    %esi,(%ebx)
		page_free_list = &pages[i];
f010102c:	89 d6                	mov    %edx,%esi
f010102e:	03 35 10 3f 22 f0    	add    0xf0223f10,%esi
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i;
	for (i = 0; i < npages; i++) {
f0101034:	83 c0 01             	add    $0x1,%eax
f0101037:	8b 15 08 3f 22 f0    	mov    0xf0223f08,%edx
f010103d:	39 c2                	cmp    %eax,%edx
f010103f:	77 c4                	ja     f0101005 <page_init+0x68>
f0101041:	89 35 40 32 22 f0    	mov    %esi,0xf0223240
		page_free_list = &pages[i];
		}
	}
	//first page
	extern char end[];
	pages[1].pp_link=0;
f0101047:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
f010104c:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101053:	81 fa a0 00 00 00    	cmp    $0xa0,%edx
f0101059:	77 1c                	ja     f0101077 <page_init+0xda>
		panic("pa2page called with invalid pa");
f010105b:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0101062:	f0 
f0101063:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010106a:	00 
f010106b:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0101072:	e8 c9 ef ff ff       	call   f0100040 <_panic>
	//io hole and kernel and kern_pgdir and pages
	struct Page* pgstart=pa2page((physaddr_t)IOPHYSMEM);
	struct Page* pgend=pa2page((physaddr_t)(end-KERNBASE+PGSIZE+ROUNDUP(npages*sizeof(struct Page),PGSIZE)+ROUNDUP(NENV*sizeof(struct Env),PGSIZE)));
f0101077:	8d 0c d5 00 00 00 00 	lea    0x0(,%edx,8),%ecx
f010107e:	8d 99 ff 0f 00 00    	lea    0xfff(%ecx),%ebx
f0101084:	81 e3 ff 0f 00 00    	and    $0xfff,%ebx
f010108a:	29 d9                	sub    %ebx,%ecx
f010108c:	8d 89 03 60 28 00    	lea    0x286003(%ecx),%ecx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101092:	c1 e9 0c             	shr    $0xc,%ecx
f0101095:	39 ca                	cmp    %ecx,%edx
f0101097:	77 1c                	ja     f01010b5 <page_init+0x118>
		panic("pa2page called with invalid pa");
f0101099:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f01010a0:	f0 
f01010a1:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01010a8:	00 
f01010a9:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f01010b0:	e8 8b ef ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01010b5:	8d 1c c8             	lea    (%eax,%ecx,8),%ebx
	//cprintf("pgstart %x ,pgend %x \r\n",(int)pgstart,(int)pgend);
	pgend=pgend+1;
	pgstart=pgstart-1;
f01010b8:	8d b0 f8 04 00 00    	lea    0x4f8(%eax),%esi
	pages[1].pp_link=0;
	//io hole and kernel and kern_pgdir and pages
	struct Page* pgstart=pa2page((physaddr_t)IOPHYSMEM);
	struct Page* pgend=pa2page((physaddr_t)(end-KERNBASE+PGSIZE+ROUNDUP(npages*sizeof(struct Page),PGSIZE)+ROUNDUP(NENV*sizeof(struct Env),PGSIZE)));
	//cprintf("pgstart %x ,pgend %x \r\n",(int)pgstart,(int)pgend);
	pgend=pgend+1;
f01010be:	8d 43 08             	lea    0x8(%ebx),%eax
	pgstart=pgstart-1;
	cprintf("pgstart %x ,pgend %x \r\n",(int)pgstart,(int)pgend);
f01010c1:	89 44 24 08          	mov    %eax,0x8(%esp)
f01010c5:	89 74 24 04          	mov    %esi,0x4(%esp)
f01010c9:	c7 04 24 a5 6d 10 f0 	movl   $0xf0106da5,(%esp)
f01010d0:	e8 a4 30 00 00       	call   f0104179 <cprintf>
    pgend->pp_link=pgstart;
f01010d5:	89 73 08             	mov    %esi,0x8(%ebx)
f01010d8:	eb 11                	jmp    f01010eb <page_init+0x14e>
		page_free_list = &pages[i];
		}
	}
	//first page
	extern char end[];
	pages[1].pp_link=0;
f01010da:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
f01010df:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
f01010e6:	e9 70 ff ff ff       	jmp    f010105b <page_init+0xbe>
	//cprintf("pgstart %x ,pgend %x \r\n",(int)pgstart,(int)pgend);
	pgend=pgend+1;
	pgstart=pgstart-1;
	cprintf("pgstart %x ,pgend %x \r\n",(int)pgstart,(int)pgend);
    pgend->pp_link=pgstart;
}
f01010eb:	83 c4 10             	add    $0x10,%esp
f01010ee:	5b                   	pop    %ebx
f01010ef:	5e                   	pop    %esi
f01010f0:	5d                   	pop    %ebp
f01010f1:	c3                   	ret    

f01010f2 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f01010f2:	55                   	push   %ebp
f01010f3:	89 e5                	mov    %esp,%ebp
f01010f5:	53                   	push   %ebx
f01010f6:	83 ec 14             	sub    $0x14,%esp
	//cprintf("page_alloc\r\n");
	if(page_free_list==NULL)
f01010f9:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f01010ff:	85 db                	test   %ebx,%ebx
f0101101:	74 69                	je     f010116c <page_alloc+0x7a>
	{
		return NULL;
	}
	struct Page* result=page_free_list;
	page_free_list=page_free_list->pp_link;
f0101103:	8b 03                	mov    (%ebx),%eax
f0101105:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	if(alloc_flags & ALLOC_ZERO)
	{
	memset(page2kva(result),0,PGSIZE);
	}
	return result;
f010110a:	89 d8                	mov    %ebx,%eax
	{
		return NULL;
	}
	struct Page* result=page_free_list;
	page_free_list=page_free_list->pp_link;
	if(alloc_flags & ALLOC_ZERO)
f010110c:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f0101110:	74 5f                	je     f0101171 <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101112:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f0101118:	c1 f8 03             	sar    $0x3,%eax
f010111b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010111e:	89 c2                	mov    %eax,%edx
f0101120:	c1 ea 0c             	shr    $0xc,%edx
f0101123:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f0101129:	72 20                	jb     f010114b <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010112b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010112f:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0101136:	f0 
f0101137:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010113e:	00 
f010113f:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0101146:	e8 f5 ee ff ff       	call   f0100040 <_panic>
	{
	memset(page2kva(result),0,PGSIZE);
f010114b:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101152:	00 
f0101153:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010115a:	00 
	return (void *)(pa + KERNBASE);
f010115b:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101160:	89 04 24             	mov    %eax,(%esp)
f0101163:	e8 f1 47 00 00       	call   f0105959 <memset>
	}
	return result;
f0101168:	89 d8                	mov    %ebx,%eax
f010116a:	eb 05                	jmp    f0101171 <page_alloc+0x7f>
page_alloc(int alloc_flags)
{
	//cprintf("page_alloc\r\n");
	if(page_free_list==NULL)
	{
		return NULL;
f010116c:	b8 00 00 00 00       	mov    $0x0,%eax
	if(alloc_flags & ALLOC_ZERO)
	{
	memset(page2kva(result),0,PGSIZE);
	}
	return result;
}
f0101171:	83 c4 14             	add    $0x14,%esp
f0101174:	5b                   	pop    %ebx
f0101175:	5d                   	pop    %ebp
f0101176:	c3                   	ret    

f0101177 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0101177:	55                   	push   %ebp
f0101178:	89 e5                	mov    %esp,%ebp
f010117a:	8b 45 08             	mov    0x8(%ebp),%eax
	//cprintf("page_frees\r\n");
	pp->pp_ref=0;
f010117d:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
	pp->pp_link=page_free_list;
f0101183:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0101189:	89 10                	mov    %edx,(%eax)
	page_free_list=pp;
f010118b:	a3 40 32 22 f0       	mov    %eax,0xf0223240
}
f0101190:	5d                   	pop    %ebp
f0101191:	c3                   	ret    

f0101192 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0101192:	55                   	push   %ebp
f0101193:	89 e5                	mov    %esp,%ebp
f0101195:	83 ec 04             	sub    $0x4,%esp
f0101198:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f010119b:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f010119f:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011a2:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011a6:	66 85 d2             	test   %dx,%dx
f01011a9:	75 08                	jne    f01011b3 <page_decref+0x21>
		page_free(pp);
f01011ab:	89 04 24             	mov    %eax,(%esp)
f01011ae:	e8 c4 ff ff ff       	call   f0101177 <page_free>
}
f01011b3:	c9                   	leave  
f01011b4:	c3                   	ret    

f01011b5 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f01011b5:	55                   	push   %ebp
f01011b6:	89 e5                	mov    %esp,%ebp
f01011b8:	56                   	push   %esi
f01011b9:	53                   	push   %ebx
f01011ba:	83 ec 10             	sub    $0x10,%esp
f01011bd:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	//cprintf("pgdir_walk\r\n");
	// Fill this function in
	pte_t* result=NULL;
	if(pgdir[PDX(va)]==(pte_t)NULL)
f01011c0:	89 de                	mov    %ebx,%esi
f01011c2:	c1 ee 16             	shr    $0x16,%esi
f01011c5:	c1 e6 02             	shl    $0x2,%esi
f01011c8:	03 75 08             	add    0x8(%ebp),%esi
f01011cb:	8b 06                	mov    (%esi),%eax
f01011cd:	85 c0                	test   %eax,%eax
f01011cf:	75 76                	jne    f0101247 <pgdir_walk+0x92>
	{
		if(create==0)
f01011d1:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01011d5:	0f 84 d1 00 00 00    	je     f01012ac <pgdir_walk+0xf7>
		{
			return NULL;
		}
		else
		{
			struct Page* page=page_alloc(1);
f01011db:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01011e2:	e8 0b ff ff ff       	call   f01010f2 <page_alloc>
			if(page==NULL)
f01011e7:	85 c0                	test   %eax,%eax
f01011e9:	0f 84 c4 00 00 00    	je     f01012b3 <pgdir_walk+0xfe>
			{
				return NULL;
			}
			page->pp_ref++;
f01011ef:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01011f4:	89 c2                	mov    %eax,%edx
f01011f6:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f01011fc:	c1 fa 03             	sar    $0x3,%edx
f01011ff:	c1 e2 0c             	shl    $0xc,%edx
			pgdir[PDX(va)]=page2pa(page)|PTE_P|PTE_W|PTE_U;
f0101202:	83 ca 07             	or     $0x7,%edx
f0101205:	89 16                	mov    %edx,(%esi)
f0101207:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f010120d:	c1 f8 03             	sar    $0x3,%eax
f0101210:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101213:	89 c2                	mov    %eax,%edx
f0101215:	c1 ea 0c             	shr    $0xc,%edx
f0101218:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f010121e:	72 20                	jb     f0101240 <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101220:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101224:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f010122b:	f0 
f010122c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101233:	00 
f0101234:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f010123b:	e8 00 ee ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101240:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101245:	eb 58                	jmp    f010129f <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101247:	c1 e8 0c             	shr    $0xc,%eax
f010124a:	8b 15 08 3f 22 f0    	mov    0xf0223f08,%edx
f0101250:	39 d0                	cmp    %edx,%eax
f0101252:	72 1c                	jb     f0101270 <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f0101254:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f010125b:	f0 
f010125c:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101263:	00 
f0101264:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f010126b:	e8 d0 ed ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101270:	89 c1                	mov    %eax,%ecx
f0101272:	c1 e1 0c             	shl    $0xc,%ecx
f0101275:	39 d0                	cmp    %edx,%eax
f0101277:	72 20                	jb     f0101299 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101279:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010127d:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0101284:	f0 
f0101285:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010128c:	00 
f010128d:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0101294:	e8 a7 ed ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101299:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
	else
	{
		//cprintf("%u ",PGNUM(PTE_ADDR(pgdir[PDX(va)])));
		result=page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
	}
	pte_t* r=&result[PTX(va)];
f010129f:	c1 eb 0a             	shr    $0xa,%ebx
f01012a2:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
	pte_t pte=*r;

	return r;
f01012a8:	01 d8                	add    %ebx,%eax
f01012aa:	eb 0c                	jmp    f01012b8 <pgdir_walk+0x103>
	pte_t* result=NULL;
	if(pgdir[PDX(va)]==(pte_t)NULL)
	{
		if(create==0)
		{
			return NULL;
f01012ac:	b8 00 00 00 00       	mov    $0x0,%eax
f01012b1:	eb 05                	jmp    f01012b8 <pgdir_walk+0x103>
		else
		{
			struct Page* page=page_alloc(1);
			if(page==NULL)
			{
				return NULL;
f01012b3:	b8 00 00 00 00       	mov    $0x0,%eax
	pte_t pte=*r;

	return r;


}
f01012b8:	83 c4 10             	add    $0x10,%esp
f01012bb:	5b                   	pop    %ebx
f01012bc:	5e                   	pop    %esi
f01012bd:	5d                   	pop    %ebp
f01012be:	c3                   	ret    

f01012bf <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f01012bf:	55                   	push   %ebp
f01012c0:	89 e5                	mov    %esp,%ebp
f01012c2:	53                   	push   %ebx
f01012c3:	83 ec 14             	sub    $0x14,%esp
f01012c6:	8b 5d 10             	mov    0x10(%ebp),%ebx
	//cprintf("page_lookup\r\n");
	// Fill this function in
	pte_t* pte=pgdir_walk(pgdir,va,0);
f01012c9:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01012d0:	00 
f01012d1:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012d8:	8b 45 08             	mov    0x8(%ebp),%eax
f01012db:	89 04 24             	mov    %eax,(%esp)
f01012de:	e8 d2 fe ff ff       	call   f01011b5 <pgdir_walk>
	if(pte==NULL)
f01012e3:	85 c0                	test   %eax,%eax
f01012e5:	74 3e                	je     f0101325 <page_lookup+0x66>
	{
		return NULL;
	}
	if(pte_store!=0)
f01012e7:	85 db                	test   %ebx,%ebx
f01012e9:	74 02                	je     f01012ed <page_lookup+0x2e>
	{
		*pte_store=pte;
f01012eb:	89 03                	mov    %eax,(%ebx)
	}
    pte_t* unuse=pte;

	if(pte[0] !=(pte_t)NULL)
f01012ed:	8b 00                	mov    (%eax),%eax
f01012ef:	85 c0                	test   %eax,%eax
f01012f1:	74 39                	je     f010132c <page_lookup+0x6d>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01012f3:	c1 e8 0c             	shr    $0xc,%eax
f01012f6:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f01012fc:	72 1c                	jb     f010131a <page_lookup+0x5b>
		panic("pa2page called with invalid pa");
f01012fe:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0101305:	f0 
f0101306:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010130d:	00 
f010130e:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0101315:	e8 26 ed ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f010131a:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
f0101320:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	{

		return pa2page(PTE_ADDR(pte[0]));
f0101323:	eb 0c                	jmp    f0101331 <page_lookup+0x72>
	//cprintf("page_lookup\r\n");
	// Fill this function in
	pte_t* pte=pgdir_walk(pgdir,va,0);
	if(pte==NULL)
	{
		return NULL;
f0101325:	b8 00 00 00 00       	mov    $0x0,%eax
f010132a:	eb 05                	jmp    f0101331 <page_lookup+0x72>
		return pa2page(PTE_ADDR(pte[0]));

	}
	else
	{
		return NULL;
f010132c:	b8 00 00 00 00       	mov    $0x0,%eax
	}
}
f0101331:	83 c4 14             	add    $0x14,%esp
f0101334:	5b                   	pop    %ebx
f0101335:	5d                   	pop    %ebp
f0101336:	c3                   	ret    

f0101337 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0101337:	55                   	push   %ebp
f0101338:	89 e5                	mov    %esp,%ebp
f010133a:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f010133d:	e8 b1 4c 00 00       	call   f0105ff3 <cpunum>
f0101342:	6b c0 74             	imul   $0x74,%eax,%eax
f0101345:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f010134c:	74 16                	je     f0101364 <tlb_invalidate+0x2d>
f010134e:	e8 a0 4c 00 00       	call   f0105ff3 <cpunum>
f0101353:	6b c0 74             	imul   $0x74,%eax,%eax
f0101356:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010135c:	8b 55 08             	mov    0x8(%ebp),%edx
f010135f:	39 50 60             	cmp    %edx,0x60(%eax)
f0101362:	75 06                	jne    f010136a <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f0101364:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101367:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f010136a:	c9                   	leave  
f010136b:	c3                   	ret    

f010136c <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f010136c:	55                   	push   %ebp
f010136d:	89 e5                	mov    %esp,%ebp
f010136f:	56                   	push   %esi
f0101370:	53                   	push   %ebx
f0101371:	83 ec 20             	sub    $0x20,%esp
f0101374:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101377:	8b 75 0c             	mov    0xc(%ebp),%esi
	//cprintf("page_remove\r\n");
	pte_t* pte=0;
f010137a:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
	struct Page* page=page_lookup(pgdir,va,&pte);
f0101381:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0101384:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101388:	89 74 24 04          	mov    %esi,0x4(%esp)
f010138c:	89 1c 24             	mov    %ebx,(%esp)
f010138f:	e8 2b ff ff ff       	call   f01012bf <page_lookup>
	if(page!=NULL)
f0101394:	85 c0                	test   %eax,%eax
f0101396:	74 08                	je     f01013a0 <page_remove+0x34>
	{
		page_decref(page);
f0101398:	89 04 24             	mov    %eax,(%esp)
f010139b:	e8 f2 fd ff ff       	call   f0101192 <page_decref>
	}

	pte[0]=0;
f01013a0:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01013a3:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	tlb_invalidate(pgdir,va);
f01013a9:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013ad:	89 1c 24             	mov    %ebx,(%esp)
f01013b0:	e8 82 ff ff ff       	call   f0101337 <tlb_invalidate>
}
f01013b5:	83 c4 20             	add    $0x20,%esp
f01013b8:	5b                   	pop    %ebx
f01013b9:	5e                   	pop    %esi
f01013ba:	5d                   	pop    %ebp
f01013bb:	c3                   	ret    

f01013bc <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f01013bc:	55                   	push   %ebp
f01013bd:	89 e5                	mov    %esp,%ebp
f01013bf:	57                   	push   %edi
f01013c0:	56                   	push   %esi
f01013c1:	53                   	push   %ebx
f01013c2:	83 ec 1c             	sub    $0x1c,%esp
f01013c5:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01013c8:	8b 75 10             	mov    0x10(%ebp),%esi
	//cprintf("page_insert\r\n");
	// Fill this function in
	pte_t* pte;
	struct Page* pg=page_lookup(pgdir,va,NULL);
f01013cb:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01013d2:	00 
f01013d3:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013d7:	8b 45 08             	mov    0x8(%ebp),%eax
f01013da:	89 04 24             	mov    %eax,(%esp)
f01013dd:	e8 dd fe ff ff       	call   f01012bf <page_lookup>
f01013e2:	89 c7                	mov    %eax,%edi
	if(pg==pp)
f01013e4:	39 d8                	cmp    %ebx,%eax
f01013e6:	75 36                	jne    f010141e <page_insert+0x62>
	{
		pte=pgdir_walk(pgdir,va,1);
f01013e8:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01013ef:	00 
f01013f0:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013f4:	8b 45 08             	mov    0x8(%ebp),%eax
f01013f7:	89 04 24             	mov    %eax,(%esp)
f01013fa:	e8 b6 fd ff ff       	call   f01011b5 <pgdir_walk>
		pte[0]=page2pa(pp)|perm|PTE_P;
f01013ff:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101402:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101405:	2b 3d 10 3f 22 f0    	sub    0xf0223f10,%edi
f010140b:	c1 ff 03             	sar    $0x3,%edi
f010140e:	c1 e7 0c             	shl    $0xc,%edi
f0101411:	89 fa                	mov    %edi,%edx
f0101413:	09 ca                	or     %ecx,%edx
f0101415:	89 10                	mov    %edx,(%eax)
			return 0;
f0101417:	b8 00 00 00 00       	mov    $0x0,%eax
f010141c:	eb 57                	jmp    f0101475 <page_insert+0xb9>
	}
	else if(pg!=NULL )
f010141e:	85 c0                	test   %eax,%eax
f0101420:	74 0f                	je     f0101431 <page_insert+0x75>
	{
		page_remove(pgdir,va);
f0101422:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101426:	8b 45 08             	mov    0x8(%ebp),%eax
f0101429:	89 04 24             	mov    %eax,(%esp)
f010142c:	e8 3b ff ff ff       	call   f010136c <page_remove>
	}
	pte=pgdir_walk(pgdir,va,1);
f0101431:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101438:	00 
f0101439:	89 74 24 04          	mov    %esi,0x4(%esp)
f010143d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101440:	89 04 24             	mov    %eax,(%esp)
f0101443:	e8 6d fd ff ff       	call   f01011b5 <pgdir_walk>
	if(pte==NULL)
f0101448:	85 c0                	test   %eax,%eax
f010144a:	74 24                	je     f0101470 <page_insert+0xb4>
	{
		return -E_NO_MEM;
	}
	pte[0]=page2pa(pp)|perm|PTE_P;
f010144c:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010144f:	83 c9 01             	or     $0x1,%ecx
f0101452:	89 da                	mov    %ebx,%edx
f0101454:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f010145a:	c1 fa 03             	sar    $0x3,%edx
f010145d:	c1 e2 0c             	shl    $0xc,%edx
f0101460:	09 ca                	or     %ecx,%edx
f0101462:	89 10                	mov    %edx,(%eax)
	pp->pp_ref++;
f0101464:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)
	return 0;
f0101469:	b8 00 00 00 00       	mov    $0x0,%eax
f010146e:	eb 05                	jmp    f0101475 <page_insert+0xb9>
		page_remove(pgdir,va);
	}
	pte=pgdir_walk(pgdir,va,1);
	if(pte==NULL)
	{
		return -E_NO_MEM;
f0101470:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	}
	pte[0]=page2pa(pp)|perm|PTE_P;
	pp->pp_ref++;
	return 0;
}
f0101475:	83 c4 1c             	add    $0x1c,%esp
f0101478:	5b                   	pop    %ebx
f0101479:	5e                   	pop    %esi
f010147a:	5f                   	pop    %edi
f010147b:	5d                   	pop    %ebp
f010147c:	c3                   	ret    

f010147d <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f010147d:	55                   	push   %ebp
f010147e:	89 e5                	mov    %esp,%ebp
f0101480:	57                   	push   %edi
f0101481:	56                   	push   %esi
f0101482:	53                   	push   %ebx
f0101483:	83 ec 3c             	sub    $0x3c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101486:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f010148d:	e8 7b 2b 00 00       	call   f010400d <mc146818_read>
f0101492:	89 c3                	mov    %eax,%ebx
f0101494:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f010149b:	e8 6d 2b 00 00       	call   f010400d <mc146818_read>
f01014a0:	c1 e0 08             	shl    $0x8,%eax
f01014a3:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014a5:	89 d8                	mov    %ebx,%eax
f01014a7:	c1 e0 0a             	shl    $0xa,%eax
f01014aa:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014b0:	85 c0                	test   %eax,%eax
f01014b2:	0f 48 c2             	cmovs  %edx,%eax
f01014b5:	c1 f8 0c             	sar    $0xc,%eax
f01014b8:	a3 44 32 22 f0       	mov    %eax,0xf0223244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014bd:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01014c4:	e8 44 2b 00 00       	call   f010400d <mc146818_read>
f01014c9:	89 c3                	mov    %eax,%ebx
f01014cb:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01014d2:	e8 36 2b 00 00       	call   f010400d <mc146818_read>
f01014d7:	c1 e0 08             	shl    $0x8,%eax
f01014da:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f01014dc:	89 d8                	mov    %ebx,%eax
f01014de:	c1 e0 0a             	shl    $0xa,%eax
f01014e1:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014e7:	85 c0                	test   %eax,%eax
f01014e9:	0f 48 c2             	cmovs  %edx,%eax
f01014ec:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f01014ef:	85 c0                	test   %eax,%eax
f01014f1:	74 0e                	je     f0101501 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f01014f3:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f01014f9:	89 15 08 3f 22 f0    	mov    %edx,0xf0223f08
f01014ff:	eb 0c                	jmp    f010150d <mem_init+0x90>
	else
		npages = npages_basemem;
f0101501:	8b 15 44 32 22 f0    	mov    0xf0223244,%edx
f0101507:	89 15 08 3f 22 f0    	mov    %edx,0xf0223f08

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f010150d:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101510:	c1 e8 0a             	shr    $0xa,%eax
f0101513:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0101517:	a1 44 32 22 f0       	mov    0xf0223244,%eax
f010151c:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f010151f:	c1 e8 0a             	shr    $0xa,%eax
f0101522:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f0101526:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
f010152b:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f010152e:	c1 e8 0a             	shr    $0xa,%eax
f0101531:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101535:	c7 04 24 64 71 10 f0 	movl   $0xf0107164,(%esp)
f010153c:	e8 38 2c 00 00       	call   f0104179 <cprintf>
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
	cprintf("npages :%u",npages);
f0101541:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
f0101546:	89 44 24 04          	mov    %eax,0x4(%esp)
f010154a:	c7 04 24 bd 6d 10 f0 	movl   $0xf0106dbd,(%esp)
f0101551:	e8 23 2c 00 00       	call   f0104179 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f0101556:	b8 00 10 00 00       	mov    $0x1000,%eax
f010155b:	e8 a0 f5 ff ff       	call   f0100b00 <boot_alloc>
f0101560:	a3 0c 3f 22 f0       	mov    %eax,0xf0223f0c
	memset(kern_pgdir, 0, PGSIZE);
f0101565:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010156c:	00 
f010156d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101574:	00 
f0101575:	89 04 24             	mov    %eax,(%esp)
f0101578:	e8 dc 43 00 00       	call   f0105959 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f010157d:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0101582:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0101587:	77 20                	ja     f01015a9 <mem_init+0x12c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0101589:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010158d:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0101594:	f0 
f0101595:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f010159c:	00 
f010159d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01015a4:	e8 97 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01015a9:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015af:	83 ca 05             	or     $0x5,%edx
f01015b2:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate an array of npages 'struct Page's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:
	pages = (struct Page *) boot_alloc(npages*sizeof(struct Page));
f01015b8:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
f01015bd:	c1 e0 03             	shl    $0x3,%eax
f01015c0:	e8 3b f5 ff ff       	call   f0100b00 <boot_alloc>
f01015c5:	a3 10 3f 22 f0       	mov    %eax,0xf0223f10

	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs=(struct Env*)boot_alloc(NENV*sizeof(struct Env));
f01015ca:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f01015cf:	e8 2c f5 ff ff       	call   f0100b00 <boot_alloc>
f01015d4:	a3 48 32 22 f0       	mov    %eax,0xf0223248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f01015d9:	e8 bf f9 ff ff       	call   f0100f9d <page_init>

	check_page_free_list(1);
f01015de:	b8 01 00 00 00       	mov    $0x1,%eax
f01015e3:	e8 d3 f5 ff ff       	call   f0100bbb <check_page_free_list>
// and page_init()).
//
static void
check_page_alloc(void)
{
	cprintf("check_page_alloc");
f01015e8:	c7 04 24 c8 6d 10 f0 	movl   $0xf0106dc8,(%esp)
f01015ef:	e8 85 2b 00 00       	call   f0104179 <cprintf>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f01015f4:	83 3d 10 3f 22 f0 00 	cmpl   $0x0,0xf0223f10
f01015fb:	75 1c                	jne    f0101619 <mem_init+0x19c>
		panic("'pages' is a null pointer!");
f01015fd:	c7 44 24 08 d9 6d 10 	movl   $0xf0106dd9,0x8(%esp)
f0101604:	f0 
f0101605:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
f010160c:	00 
f010160d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101614:	e8 27 ea ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101619:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f010161e:	85 c0                	test   %eax,%eax
f0101620:	74 10                	je     f0101632 <mem_init+0x1b5>
f0101622:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101627:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f010162a:	8b 00                	mov    (%eax),%eax
f010162c:	85 c0                	test   %eax,%eax
f010162e:	75 f7                	jne    f0101627 <mem_init+0x1aa>
f0101630:	eb 05                	jmp    f0101637 <mem_init+0x1ba>
f0101632:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101637:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010163e:	e8 af fa ff ff       	call   f01010f2 <page_alloc>
f0101643:	89 c7                	mov    %eax,%edi
f0101645:	85 c0                	test   %eax,%eax
f0101647:	75 24                	jne    f010166d <mem_init+0x1f0>
f0101649:	c7 44 24 0c f4 6d 10 	movl   $0xf0106df4,0xc(%esp)
f0101650:	f0 
f0101651:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101658:	f0 
f0101659:	c7 44 24 04 2d 03 00 	movl   $0x32d,0x4(%esp)
f0101660:	00 
f0101661:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101668:	e8 d3 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010166d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101674:	e8 79 fa ff ff       	call   f01010f2 <page_alloc>
f0101679:	89 c6                	mov    %eax,%esi
f010167b:	85 c0                	test   %eax,%eax
f010167d:	75 24                	jne    f01016a3 <mem_init+0x226>
f010167f:	c7 44 24 0c 0a 6e 10 	movl   $0xf0106e0a,0xc(%esp)
f0101686:	f0 
f0101687:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010168e:	f0 
f010168f:	c7 44 24 04 2e 03 00 	movl   $0x32e,0x4(%esp)
f0101696:	00 
f0101697:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010169e:	e8 9d e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016a3:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016aa:	e8 43 fa ff ff       	call   f01010f2 <page_alloc>
f01016af:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016b2:	85 c0                	test   %eax,%eax
f01016b4:	75 24                	jne    f01016da <mem_init+0x25d>
f01016b6:	c7 44 24 0c 20 6e 10 	movl   $0xf0106e20,0xc(%esp)
f01016bd:	f0 
f01016be:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01016c5:	f0 
f01016c6:	c7 44 24 04 2f 03 00 	movl   $0x32f,0x4(%esp)
f01016cd:	00 
f01016ce:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01016d5:	e8 66 e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01016da:	39 f7                	cmp    %esi,%edi
f01016dc:	75 24                	jne    f0101702 <mem_init+0x285>
f01016de:	c7 44 24 0c 36 6e 10 	movl   $0xf0106e36,0xc(%esp)
f01016e5:	f0 
f01016e6:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01016ed:	f0 
f01016ee:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01016f5:	00 
f01016f6:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01016fd:	e8 3e e9 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101702:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101705:	39 c6                	cmp    %eax,%esi
f0101707:	74 04                	je     f010170d <mem_init+0x290>
f0101709:	39 c7                	cmp    %eax,%edi
f010170b:	75 24                	jne    f0101731 <mem_init+0x2b4>
f010170d:	c7 44 24 0c a0 71 10 	movl   $0xf01071a0,0xc(%esp)
f0101714:	f0 
f0101715:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010171c:	f0 
f010171d:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
f0101724:	00 
f0101725:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010172c:	e8 0f e9 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101731:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101737:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
f010173c:	c1 e0 0c             	shl    $0xc,%eax
f010173f:	89 f9                	mov    %edi,%ecx
f0101741:	29 d1                	sub    %edx,%ecx
f0101743:	c1 f9 03             	sar    $0x3,%ecx
f0101746:	c1 e1 0c             	shl    $0xc,%ecx
f0101749:	39 c1                	cmp    %eax,%ecx
f010174b:	72 24                	jb     f0101771 <mem_init+0x2f4>
f010174d:	c7 44 24 0c 48 6e 10 	movl   $0xf0106e48,0xc(%esp)
f0101754:	f0 
f0101755:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010175c:	f0 
f010175d:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
f0101764:	00 
f0101765:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010176c:	e8 cf e8 ff ff       	call   f0100040 <_panic>
f0101771:	89 f1                	mov    %esi,%ecx
f0101773:	29 d1                	sub    %edx,%ecx
f0101775:	c1 f9 03             	sar    $0x3,%ecx
f0101778:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f010177b:	39 c8                	cmp    %ecx,%eax
f010177d:	77 24                	ja     f01017a3 <mem_init+0x326>
f010177f:	c7 44 24 0c 65 6e 10 	movl   $0xf0106e65,0xc(%esp)
f0101786:	f0 
f0101787:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010178e:	f0 
f010178f:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f0101796:	00 
f0101797:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010179e:	e8 9d e8 ff ff       	call   f0100040 <_panic>
f01017a3:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017a6:	29 d1                	sub    %edx,%ecx
f01017a8:	89 ca                	mov    %ecx,%edx
f01017aa:	c1 fa 03             	sar    $0x3,%edx
f01017ad:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017b0:	39 d0                	cmp    %edx,%eax
f01017b2:	77 24                	ja     f01017d8 <mem_init+0x35b>
f01017b4:	c7 44 24 0c 82 6e 10 	movl   $0xf0106e82,0xc(%esp)
f01017bb:	f0 
f01017bc:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01017c3:	f0 
f01017c4:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f01017cb:	00 
f01017cc:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01017d3:	e8 68 e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f01017d8:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f01017dd:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f01017e0:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f01017e7:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f01017ea:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01017f1:	e8 fc f8 ff ff       	call   f01010f2 <page_alloc>
f01017f6:	85 c0                	test   %eax,%eax
f01017f8:	74 24                	je     f010181e <mem_init+0x3a1>
f01017fa:	c7 44 24 0c 9f 6e 10 	movl   $0xf0106e9f,0xc(%esp)
f0101801:	f0 
f0101802:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101809:	f0 
f010180a:	c7 44 24 04 3d 03 00 	movl   $0x33d,0x4(%esp)
f0101811:	00 
f0101812:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101819:	e8 22 e8 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f010181e:	89 3c 24             	mov    %edi,(%esp)
f0101821:	e8 51 f9 ff ff       	call   f0101177 <page_free>
	page_free(pp1);
f0101826:	89 34 24             	mov    %esi,(%esp)
f0101829:	e8 49 f9 ff ff       	call   f0101177 <page_free>
	page_free(pp2);
f010182e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101831:	89 04 24             	mov    %eax,(%esp)
f0101834:	e8 3e f9 ff ff       	call   f0101177 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101839:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101840:	e8 ad f8 ff ff       	call   f01010f2 <page_alloc>
f0101845:	89 c6                	mov    %eax,%esi
f0101847:	85 c0                	test   %eax,%eax
f0101849:	75 24                	jne    f010186f <mem_init+0x3f2>
f010184b:	c7 44 24 0c f4 6d 10 	movl   $0xf0106df4,0xc(%esp)
f0101852:	f0 
f0101853:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010185a:	f0 
f010185b:	c7 44 24 04 44 03 00 	movl   $0x344,0x4(%esp)
f0101862:	00 
f0101863:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010186a:	e8 d1 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010186f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101876:	e8 77 f8 ff ff       	call   f01010f2 <page_alloc>
f010187b:	89 c7                	mov    %eax,%edi
f010187d:	85 c0                	test   %eax,%eax
f010187f:	75 24                	jne    f01018a5 <mem_init+0x428>
f0101881:	c7 44 24 0c 0a 6e 10 	movl   $0xf0106e0a,0xc(%esp)
f0101888:	f0 
f0101889:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101890:	f0 
f0101891:	c7 44 24 04 45 03 00 	movl   $0x345,0x4(%esp)
f0101898:	00 
f0101899:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01018a0:	e8 9b e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018a5:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018ac:	e8 41 f8 ff ff       	call   f01010f2 <page_alloc>
f01018b1:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018b4:	85 c0                	test   %eax,%eax
f01018b6:	75 24                	jne    f01018dc <mem_init+0x45f>
f01018b8:	c7 44 24 0c 20 6e 10 	movl   $0xf0106e20,0xc(%esp)
f01018bf:	f0 
f01018c0:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01018c7:	f0 
f01018c8:	c7 44 24 04 46 03 00 	movl   $0x346,0x4(%esp)
f01018cf:	00 
f01018d0:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01018d7:	e8 64 e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018dc:	39 fe                	cmp    %edi,%esi
f01018de:	75 24                	jne    f0101904 <mem_init+0x487>
f01018e0:	c7 44 24 0c 36 6e 10 	movl   $0xf0106e36,0xc(%esp)
f01018e7:	f0 
f01018e8:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01018ef:	f0 
f01018f0:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f01018f7:	00 
f01018f8:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01018ff:	e8 3c e7 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101904:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101907:	39 c7                	cmp    %eax,%edi
f0101909:	74 04                	je     f010190f <mem_init+0x492>
f010190b:	39 c6                	cmp    %eax,%esi
f010190d:	75 24                	jne    f0101933 <mem_init+0x4b6>
f010190f:	c7 44 24 0c a0 71 10 	movl   $0xf01071a0,0xc(%esp)
f0101916:	f0 
f0101917:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010191e:	f0 
f010191f:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f0101926:	00 
f0101927:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010192e:	e8 0d e7 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f0101933:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010193a:	e8 b3 f7 ff ff       	call   f01010f2 <page_alloc>
f010193f:	85 c0                	test   %eax,%eax
f0101941:	74 24                	je     f0101967 <mem_init+0x4ea>
f0101943:	c7 44 24 0c 9f 6e 10 	movl   $0xf0106e9f,0xc(%esp)
f010194a:	f0 
f010194b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101952:	f0 
f0101953:	c7 44 24 04 4a 03 00 	movl   $0x34a,0x4(%esp)
f010195a:	00 
f010195b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101962:	e8 d9 e6 ff ff       	call   f0100040 <_panic>
f0101967:	89 f0                	mov    %esi,%eax
f0101969:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f010196f:	c1 f8 03             	sar    $0x3,%eax
f0101972:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101975:	89 c2                	mov    %eax,%edx
f0101977:	c1 ea 0c             	shr    $0xc,%edx
f010197a:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f0101980:	72 20                	jb     f01019a2 <mem_init+0x525>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101982:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0101986:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f010198d:	f0 
f010198e:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101995:	00 
f0101996:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f010199d:	e8 9e e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019a2:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019a9:	00 
f01019aa:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019b1:	00 
	return (void *)(pa + KERNBASE);
f01019b2:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01019b7:	89 04 24             	mov    %eax,(%esp)
f01019ba:	e8 9a 3f 00 00       	call   f0105959 <memset>
	page_free(pp0);
f01019bf:	89 34 24             	mov    %esi,(%esp)
f01019c2:	e8 b0 f7 ff ff       	call   f0101177 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01019c7:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01019ce:	e8 1f f7 ff ff       	call   f01010f2 <page_alloc>
f01019d3:	85 c0                	test   %eax,%eax
f01019d5:	75 24                	jne    f01019fb <mem_init+0x57e>
f01019d7:	c7 44 24 0c ae 6e 10 	movl   $0xf0106eae,0xc(%esp)
f01019de:	f0 
f01019df:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01019e6:	f0 
f01019e7:	c7 44 24 04 4f 03 00 	movl   $0x34f,0x4(%esp)
f01019ee:	00 
f01019ef:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01019f6:	e8 45 e6 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f01019fb:	39 c6                	cmp    %eax,%esi
f01019fd:	74 24                	je     f0101a23 <mem_init+0x5a6>
f01019ff:	c7 44 24 0c cc 6e 10 	movl   $0xf0106ecc,0xc(%esp)
f0101a06:	f0 
f0101a07:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101a0e:	f0 
f0101a0f:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0101a16:	00 
f0101a17:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101a1e:	e8 1d e6 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a23:	89 f2                	mov    %esi,%edx
f0101a25:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f0101a2b:	c1 fa 03             	sar    $0x3,%edx
f0101a2e:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a31:	89 d0                	mov    %edx,%eax
f0101a33:	c1 e8 0c             	shr    $0xc,%eax
f0101a36:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0101a3c:	72 20                	jb     f0101a5e <mem_init+0x5e1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a3e:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a42:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0101a49:	f0 
f0101a4a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a51:	00 
f0101a52:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0101a59:	e8 e2 e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101a5e:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101a65:	75 11                	jne    f0101a78 <mem_init+0x5fb>
f0101a67:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101a6d:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101a73:	80 38 00             	cmpb   $0x0,(%eax)
f0101a76:	74 24                	je     f0101a9c <mem_init+0x61f>
f0101a78:	c7 44 24 0c dc 6e 10 	movl   $0xf0106edc,0xc(%esp)
f0101a7f:	f0 
f0101a80:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101a87:	f0 
f0101a88:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f0101a8f:	00 
f0101a90:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101a97:	e8 a4 e5 ff ff       	call   f0100040 <_panic>
f0101a9c:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101a9f:	39 d0                	cmp    %edx,%eax
f0101aa1:	75 d0                	jne    f0101a73 <mem_init+0x5f6>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101aa3:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101aa6:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0101aab:	89 34 24             	mov    %esi,(%esp)
f0101aae:	e8 c4 f6 ff ff       	call   f0101177 <page_free>
	page_free(pp1);
f0101ab3:	89 3c 24             	mov    %edi,(%esp)
f0101ab6:	e8 bc f6 ff ff       	call   f0101177 <page_free>
	page_free(pp2);
f0101abb:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101abe:	89 04 24             	mov    %eax,(%esp)
f0101ac1:	e8 b1 f6 ff ff       	call   f0101177 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101ac6:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101acb:	85 c0                	test   %eax,%eax
f0101acd:	74 09                	je     f0101ad8 <mem_init+0x65b>
		--nfree;
f0101acf:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101ad2:	8b 00                	mov    (%eax),%eax
f0101ad4:	85 c0                	test   %eax,%eax
f0101ad6:	75 f7                	jne    f0101acf <mem_init+0x652>
		--nfree;
	assert(nfree == 0);
f0101ad8:	85 db                	test   %ebx,%ebx
f0101ada:	74 24                	je     f0101b00 <mem_init+0x683>
f0101adc:	c7 44 24 0c e6 6e 10 	movl   $0xf0106ee6,0xc(%esp)
f0101ae3:	f0 
f0101ae4:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101aeb:	f0 
f0101aec:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
f0101af3:	00 
f0101af4:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101afb:	e8 40 e5 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b00:	c7 04 24 c0 71 10 f0 	movl   $0xf01071c0,(%esp)
f0101b07:	e8 6d 26 00 00       	call   f0104179 <cprintf>

// check page_insert, page_remove, &c
static void
check_page(void)
{
	cprintf("check_page\r\n");
f0101b0c:	c7 04 24 f1 6e 10 f0 	movl   $0xf0106ef1,(%esp)
f0101b13:	e8 61 26 00 00       	call   f0104179 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b18:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b1f:	e8 ce f5 ff ff       	call   f01010f2 <page_alloc>
f0101b24:	89 c3                	mov    %eax,%ebx
f0101b26:	85 c0                	test   %eax,%eax
f0101b28:	75 24                	jne    f0101b4e <mem_init+0x6d1>
f0101b2a:	c7 44 24 0c f4 6d 10 	movl   $0xf0106df4,0xc(%esp)
f0101b31:	f0 
f0101b32:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101b39:	f0 
f0101b3a:	c7 44 24 04 d6 03 00 	movl   $0x3d6,0x4(%esp)
f0101b41:	00 
f0101b42:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101b49:	e8 f2 e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b4e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b55:	e8 98 f5 ff ff       	call   f01010f2 <page_alloc>
f0101b5a:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101b5d:	85 c0                	test   %eax,%eax
f0101b5f:	75 24                	jne    f0101b85 <mem_init+0x708>
f0101b61:	c7 44 24 0c 0a 6e 10 	movl   $0xf0106e0a,0xc(%esp)
f0101b68:	f0 
f0101b69:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101b70:	f0 
f0101b71:	c7 44 24 04 d7 03 00 	movl   $0x3d7,0x4(%esp)
f0101b78:	00 
f0101b79:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101b80:	e8 bb e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101b85:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b8c:	e8 61 f5 ff ff       	call   f01010f2 <page_alloc>
f0101b91:	89 c6                	mov    %eax,%esi
f0101b93:	85 c0                	test   %eax,%eax
f0101b95:	75 24                	jne    f0101bbb <mem_init+0x73e>
f0101b97:	c7 44 24 0c 20 6e 10 	movl   $0xf0106e20,0xc(%esp)
f0101b9e:	f0 
f0101b9f:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101ba6:	f0 
f0101ba7:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f0101bae:	00 
f0101baf:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101bb6:	e8 85 e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101bbb:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101bbe:	75 24                	jne    f0101be4 <mem_init+0x767>
f0101bc0:	c7 44 24 0c 36 6e 10 	movl   $0xf0106e36,0xc(%esp)
f0101bc7:	f0 
f0101bc8:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101bcf:	f0 
f0101bd0:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0101bd7:	00 
f0101bd8:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101bdf:	e8 5c e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101be4:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101be7:	74 04                	je     f0101bed <mem_init+0x770>
f0101be9:	39 c3                	cmp    %eax,%ebx
f0101beb:	75 24                	jne    f0101c11 <mem_init+0x794>
f0101bed:	c7 44 24 0c a0 71 10 	movl   $0xf01071a0,0xc(%esp)
f0101bf4:	f0 
f0101bf5:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101bfc:	f0 
f0101bfd:	c7 44 24 04 dc 03 00 	movl   $0x3dc,0x4(%esp)
f0101c04:	00 
f0101c05:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101c0c:	e8 2f e4 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c11:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101c16:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c19:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f0101c20:	00 00 00 
	cprintf("1");
f0101c23:	c7 04 24 1e 6f 10 f0 	movl   $0xf0106f1e,(%esp)
f0101c2a:	e8 4a 25 00 00       	call   f0104179 <cprintf>
	// should be no free memory
	assert(!page_alloc(0));
f0101c2f:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c36:	e8 b7 f4 ff ff       	call   f01010f2 <page_alloc>
f0101c3b:	85 c0                	test   %eax,%eax
f0101c3d:	74 24                	je     f0101c63 <mem_init+0x7e6>
f0101c3f:	c7 44 24 0c 9f 6e 10 	movl   $0xf0106e9f,0xc(%esp)
f0101c46:	f0 
f0101c47:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101c4e:	f0 
f0101c4f:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f0101c56:	00 
f0101c57:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101c5e:	e8 dd e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c63:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c66:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c6a:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101c71:	00 
f0101c72:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101c77:	89 04 24             	mov    %eax,(%esp)
f0101c7a:	e8 40 f6 ff ff       	call   f01012bf <page_lookup>
f0101c7f:	85 c0                	test   %eax,%eax
f0101c81:	74 24                	je     f0101ca7 <mem_init+0x82a>
f0101c83:	c7 44 24 0c e0 71 10 	movl   $0xf01071e0,0xc(%esp)
f0101c8a:	f0 
f0101c8b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101c92:	f0 
f0101c93:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f0101c9a:	00 
f0101c9b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101ca2:	e8 99 e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101ca7:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101cae:	00 
f0101caf:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101cb6:	00 
f0101cb7:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cba:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101cbe:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101cc3:	89 04 24             	mov    %eax,(%esp)
f0101cc6:	e8 f1 f6 ff ff       	call   f01013bc <page_insert>
f0101ccb:	85 c0                	test   %eax,%eax
f0101ccd:	78 24                	js     f0101cf3 <mem_init+0x876>
f0101ccf:	c7 44 24 0c 18 72 10 	movl   $0xf0107218,0xc(%esp)
f0101cd6:	f0 
f0101cd7:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101cde:	f0 
f0101cdf:	c7 44 24 04 e9 03 00 	movl   $0x3e9,0x4(%esp)
f0101ce6:	00 
f0101ce7:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101cee:	e8 4d e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101cf3:	89 1c 24             	mov    %ebx,(%esp)
f0101cf6:	e8 7c f4 ff ff       	call   f0101177 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101cfb:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d02:	00 
f0101d03:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d0a:	00 
f0101d0b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d0e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d12:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101d17:	89 04 24             	mov    %eax,(%esp)
f0101d1a:	e8 9d f6 ff ff       	call   f01013bc <page_insert>
f0101d1f:	85 c0                	test   %eax,%eax
f0101d21:	74 24                	je     f0101d47 <mem_init+0x8ca>
f0101d23:	c7 44 24 0c 48 72 10 	movl   $0xf0107248,0xc(%esp)
f0101d2a:	f0 
f0101d2b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101d32:	f0 
f0101d33:	c7 44 24 04 ed 03 00 	movl   $0x3ed,0x4(%esp)
f0101d3a:	00 
f0101d3b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101d42:	e8 f9 e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d47:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d4c:	8b 3d 10 3f 22 f0    	mov    0xf0223f10,%edi
f0101d52:	8b 08                	mov    (%eax),%ecx
f0101d54:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0101d5a:	89 da                	mov    %ebx,%edx
f0101d5c:	29 fa                	sub    %edi,%edx
f0101d5e:	c1 fa 03             	sar    $0x3,%edx
f0101d61:	c1 e2 0c             	shl    $0xc,%edx
f0101d64:	39 d1                	cmp    %edx,%ecx
f0101d66:	74 24                	je     f0101d8c <mem_init+0x90f>
f0101d68:	c7 44 24 0c 78 72 10 	movl   $0xf0107278,0xc(%esp)
f0101d6f:	f0 
f0101d70:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101d77:	f0 
f0101d78:	c7 44 24 04 ee 03 00 	movl   $0x3ee,0x4(%esp)
f0101d7f:	00 
f0101d80:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101d87:	e8 b4 e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101d8c:	ba 00 00 00 00       	mov    $0x0,%edx
f0101d91:	e8 b6 ed ff ff       	call   f0100b4c <check_va2pa>
f0101d96:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101d99:	29 fa                	sub    %edi,%edx
f0101d9b:	c1 fa 03             	sar    $0x3,%edx
f0101d9e:	c1 e2 0c             	shl    $0xc,%edx
f0101da1:	39 d0                	cmp    %edx,%eax
f0101da3:	74 24                	je     f0101dc9 <mem_init+0x94c>
f0101da5:	c7 44 24 0c a0 72 10 	movl   $0xf01072a0,0xc(%esp)
f0101dac:	f0 
f0101dad:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101db4:	f0 
f0101db5:	c7 44 24 04 ef 03 00 	movl   $0x3ef,0x4(%esp)
f0101dbc:	00 
f0101dbd:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101dc4:	e8 77 e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101dc9:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101dcc:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101dd1:	74 24                	je     f0101df7 <mem_init+0x97a>
f0101dd3:	c7 44 24 0c fe 6e 10 	movl   $0xf0106efe,0xc(%esp)
f0101dda:	f0 
f0101ddb:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101de2:	f0 
f0101de3:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0101dea:	00 
f0101deb:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101df2:	e8 49 e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101df7:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101dfc:	74 24                	je     f0101e22 <mem_init+0x9a5>
f0101dfe:	c7 44 24 0c 0f 6f 10 	movl   $0xf0106f0f,0xc(%esp)
f0101e05:	f0 
f0101e06:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101e0d:	f0 
f0101e0e:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
f0101e15:	00 
f0101e16:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101e1d:	e8 1e e2 ff ff       	call   f0100040 <_panic>
	cprintf("2");
f0101e22:	c7 04 24 5a 6f 10 f0 	movl   $0xf0106f5a,(%esp)
f0101e29:	e8 4b 23 00 00       	call   f0104179 <cprintf>
	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e2e:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e35:	00 
f0101e36:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e3d:	00 
f0101e3e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e42:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101e47:	89 04 24             	mov    %eax,(%esp)
f0101e4a:	e8 6d f5 ff ff       	call   f01013bc <page_insert>
f0101e4f:	85 c0                	test   %eax,%eax
f0101e51:	74 24                	je     f0101e77 <mem_init+0x9fa>
f0101e53:	c7 44 24 0c d0 72 10 	movl   $0xf01072d0,0xc(%esp)
f0101e5a:	f0 
f0101e5b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101e62:	f0 
f0101e63:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0101e6a:	00 
f0101e6b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101e72:	e8 c9 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e77:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e7c:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101e81:	e8 c6 ec ff ff       	call   f0100b4c <check_va2pa>
f0101e86:	89 f2                	mov    %esi,%edx
f0101e88:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f0101e8e:	c1 fa 03             	sar    $0x3,%edx
f0101e91:	c1 e2 0c             	shl    $0xc,%edx
f0101e94:	39 d0                	cmp    %edx,%eax
f0101e96:	74 24                	je     f0101ebc <mem_init+0xa3f>
f0101e98:	c7 44 24 0c 0c 73 10 	movl   $0xf010730c,0xc(%esp)
f0101e9f:	f0 
f0101ea0:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101ea7:	f0 
f0101ea8:	c7 44 24 04 f5 03 00 	movl   $0x3f5,0x4(%esp)
f0101eaf:	00 
f0101eb0:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101eb7:	e8 84 e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ebc:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101ec1:	74 24                	je     f0101ee7 <mem_init+0xa6a>
f0101ec3:	c7 44 24 0c 20 6f 10 	movl   $0xf0106f20,0xc(%esp)
f0101eca:	f0 
f0101ecb:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101ed2:	f0 
f0101ed3:	c7 44 24 04 f6 03 00 	movl   $0x3f6,0x4(%esp)
f0101eda:	00 
f0101edb:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101ee2:	e8 59 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101ee7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101eee:	e8 ff f1 ff ff       	call   f01010f2 <page_alloc>
f0101ef3:	85 c0                	test   %eax,%eax
f0101ef5:	74 24                	je     f0101f1b <mem_init+0xa9e>
f0101ef7:	c7 44 24 0c 9f 6e 10 	movl   $0xf0106e9f,0xc(%esp)
f0101efe:	f0 
f0101eff:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101f06:	f0 
f0101f07:	c7 44 24 04 f9 03 00 	movl   $0x3f9,0x4(%esp)
f0101f0e:	00 
f0101f0f:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101f16:	e8 25 e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f1b:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f22:	00 
f0101f23:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f2a:	00 
f0101f2b:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101f2f:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101f34:	89 04 24             	mov    %eax,(%esp)
f0101f37:	e8 80 f4 ff ff       	call   f01013bc <page_insert>
f0101f3c:	85 c0                	test   %eax,%eax
f0101f3e:	74 24                	je     f0101f64 <mem_init+0xae7>
f0101f40:	c7 44 24 0c d0 72 10 	movl   $0xf01072d0,0xc(%esp)
f0101f47:	f0 
f0101f48:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101f4f:	f0 
f0101f50:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f0101f57:	00 
f0101f58:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101f5f:	e8 dc e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f64:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f69:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0101f6e:	e8 d9 eb ff ff       	call   f0100b4c <check_va2pa>
f0101f73:	89 f2                	mov    %esi,%edx
f0101f75:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f0101f7b:	c1 fa 03             	sar    $0x3,%edx
f0101f7e:	c1 e2 0c             	shl    $0xc,%edx
f0101f81:	39 d0                	cmp    %edx,%eax
f0101f83:	74 24                	je     f0101fa9 <mem_init+0xb2c>
f0101f85:	c7 44 24 0c 0c 73 10 	movl   $0xf010730c,0xc(%esp)
f0101f8c:	f0 
f0101f8d:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101f94:	f0 
f0101f95:	c7 44 24 04 fd 03 00 	movl   $0x3fd,0x4(%esp)
f0101f9c:	00 
f0101f9d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101fa4:	e8 97 e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fa9:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101fae:	74 24                	je     f0101fd4 <mem_init+0xb57>
f0101fb0:	c7 44 24 0c 20 6f 10 	movl   $0xf0106f20,0xc(%esp)
f0101fb7:	f0 
f0101fb8:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101fbf:	f0 
f0101fc0:	c7 44 24 04 fe 03 00 	movl   $0x3fe,0x4(%esp)
f0101fc7:	00 
f0101fc8:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0101fcf:	e8 6c e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101fd4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101fdb:	e8 12 f1 ff ff       	call   f01010f2 <page_alloc>
f0101fe0:	85 c0                	test   %eax,%eax
f0101fe2:	74 24                	je     f0102008 <mem_init+0xb8b>
f0101fe4:	c7 44 24 0c 9f 6e 10 	movl   $0xf0106e9f,0xc(%esp)
f0101feb:	f0 
f0101fec:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0101ff3:	f0 
f0101ff4:	c7 44 24 04 02 04 00 	movl   $0x402,0x4(%esp)
f0101ffb:	00 
f0101ffc:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102003:	e8 38 e0 ff ff       	call   f0100040 <_panic>
	cprintf("3");
f0102008:	c7 04 24 31 6f 10 f0 	movl   $0xf0106f31,(%esp)
f010200f:	e8 65 21 00 00       	call   f0104179 <cprintf>
	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0102014:	8b 15 0c 3f 22 f0    	mov    0xf0223f0c,%edx
f010201a:	8b 02                	mov    (%edx),%eax
f010201c:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102021:	89 c1                	mov    %eax,%ecx
f0102023:	c1 e9 0c             	shr    $0xc,%ecx
f0102026:	3b 0d 08 3f 22 f0    	cmp    0xf0223f08,%ecx
f010202c:	72 20                	jb     f010204e <mem_init+0xbd1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010202e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102032:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0102039:	f0 
f010203a:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102041:	00 
f0102042:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102049:	e8 f2 df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010204e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102053:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0102056:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010205d:	00 
f010205e:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102065:	00 
f0102066:	89 14 24             	mov    %edx,(%esp)
f0102069:	e8 47 f1 ff ff       	call   f01011b5 <pgdir_walk>
f010206e:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0102071:	8d 57 04             	lea    0x4(%edi),%edx
f0102074:	39 d0                	cmp    %edx,%eax
f0102076:	74 24                	je     f010209c <mem_init+0xc1f>
f0102078:	c7 44 24 0c 3c 73 10 	movl   $0xf010733c,0xc(%esp)
f010207f:	f0 
f0102080:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102087:	f0 
f0102088:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f010208f:	00 
f0102090:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102097:	e8 a4 df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f010209c:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020a3:	00 
f01020a4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020ab:	00 
f01020ac:	89 74 24 04          	mov    %esi,0x4(%esp)
f01020b0:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01020b5:	89 04 24             	mov    %eax,(%esp)
f01020b8:	e8 ff f2 ff ff       	call   f01013bc <page_insert>
f01020bd:	85 c0                	test   %eax,%eax
f01020bf:	74 24                	je     f01020e5 <mem_init+0xc68>
f01020c1:	c7 44 24 0c 7c 73 10 	movl   $0xf010737c,0xc(%esp)
f01020c8:	f0 
f01020c9:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01020d0:	f0 
f01020d1:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01020d8:	00 
f01020d9:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01020e0:	e8 5b df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f01020e5:	8b 3d 0c 3f 22 f0    	mov    0xf0223f0c,%edi
f01020eb:	ba 00 10 00 00       	mov    $0x1000,%edx
f01020f0:	89 f8                	mov    %edi,%eax
f01020f2:	e8 55 ea ff ff       	call   f0100b4c <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01020f7:	89 f2                	mov    %esi,%edx
f01020f9:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f01020ff:	c1 fa 03             	sar    $0x3,%edx
f0102102:	c1 e2 0c             	shl    $0xc,%edx
f0102105:	39 d0                	cmp    %edx,%eax
f0102107:	74 24                	je     f010212d <mem_init+0xcb0>
f0102109:	c7 44 24 0c 0c 73 10 	movl   $0xf010730c,0xc(%esp)
f0102110:	f0 
f0102111:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102118:	f0 
f0102119:	c7 44 24 04 0a 04 00 	movl   $0x40a,0x4(%esp)
f0102120:	00 
f0102121:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102128:	e8 13 df ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010212d:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102132:	74 24                	je     f0102158 <mem_init+0xcdb>
f0102134:	c7 44 24 0c 20 6f 10 	movl   $0xf0106f20,0xc(%esp)
f010213b:	f0 
f010213c:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102143:	f0 
f0102144:	c7 44 24 04 0b 04 00 	movl   $0x40b,0x4(%esp)
f010214b:	00 
f010214c:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102153:	e8 e8 de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0102158:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010215f:	00 
f0102160:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102167:	00 
f0102168:	89 3c 24             	mov    %edi,(%esp)
f010216b:	e8 45 f0 ff ff       	call   f01011b5 <pgdir_walk>
f0102170:	f6 00 04             	testb  $0x4,(%eax)
f0102173:	75 24                	jne    f0102199 <mem_init+0xd1c>
f0102175:	c7 44 24 0c bc 73 10 	movl   $0xf01073bc,0xc(%esp)
f010217c:	f0 
f010217d:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102184:	f0 
f0102185:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f010218c:	00 
f010218d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102194:	e8 a7 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0102199:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f010219e:	f6 00 04             	testb  $0x4,(%eax)
f01021a1:	75 24                	jne    f01021c7 <mem_init+0xd4a>
f01021a3:	c7 44 24 0c 33 6f 10 	movl   $0xf0106f33,0xc(%esp)
f01021aa:	f0 
f01021ab:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01021b2:	f0 
f01021b3:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f01021ba:	00 
f01021bb:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01021c2:	e8 79 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021c7:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021ce:	00 
f01021cf:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021d6:	00 
f01021d7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01021db:	89 04 24             	mov    %eax,(%esp)
f01021de:	e8 d9 f1 ff ff       	call   f01013bc <page_insert>
f01021e3:	85 c0                	test   %eax,%eax
f01021e5:	78 24                	js     f010220b <mem_init+0xd8e>
f01021e7:	c7 44 24 0c f0 73 10 	movl   $0xf01073f0,0xc(%esp)
f01021ee:	f0 
f01021ef:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01021f6:	f0 
f01021f7:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f01021fe:	00 
f01021ff:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102206:	e8 35 de ff ff       	call   f0100040 <_panic>
	cprintf("4");
f010220b:	c7 04 24 49 6f 10 f0 	movl   $0xf0106f49,(%esp)
f0102212:	e8 62 1f 00 00       	call   f0104179 <cprintf>
	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102217:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010221e:	00 
f010221f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102226:	00 
f0102227:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010222a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010222e:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102233:	89 04 24             	mov    %eax,(%esp)
f0102236:	e8 81 f1 ff ff       	call   f01013bc <page_insert>
f010223b:	85 c0                	test   %eax,%eax
f010223d:	74 24                	je     f0102263 <mem_init+0xde6>
f010223f:	c7 44 24 0c 28 74 10 	movl   $0xf0107428,0xc(%esp)
f0102246:	f0 
f0102247:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010224e:	f0 
f010224f:	c7 44 24 04 13 04 00 	movl   $0x413,0x4(%esp)
f0102256:	00 
f0102257:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010225e:	e8 dd dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0102263:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010226a:	00 
f010226b:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102272:	00 
f0102273:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102278:	89 04 24             	mov    %eax,(%esp)
f010227b:	e8 35 ef ff ff       	call   f01011b5 <pgdir_walk>
f0102280:	f6 00 04             	testb  $0x4,(%eax)
f0102283:	74 24                	je     f01022a9 <mem_init+0xe2c>
f0102285:	c7 44 24 0c 64 74 10 	movl   $0xf0107464,0xc(%esp)
f010228c:	f0 
f010228d:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102294:	f0 
f0102295:	c7 44 24 04 14 04 00 	movl   $0x414,0x4(%esp)
f010229c:	00 
f010229d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01022a4:	e8 97 dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022a9:	8b 3d 0c 3f 22 f0    	mov    0xf0223f0c,%edi
f01022af:	ba 00 00 00 00       	mov    $0x0,%edx
f01022b4:	89 f8                	mov    %edi,%eax
f01022b6:	e8 91 e8 ff ff       	call   f0100b4c <check_va2pa>
f01022bb:	89 c1                	mov    %eax,%ecx
f01022bd:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022c0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022c3:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f01022c9:	c1 f8 03             	sar    $0x3,%eax
f01022cc:	c1 e0 0c             	shl    $0xc,%eax
f01022cf:	39 c1                	cmp    %eax,%ecx
f01022d1:	74 24                	je     f01022f7 <mem_init+0xe7a>
f01022d3:	c7 44 24 0c 9c 74 10 	movl   $0xf010749c,0xc(%esp)
f01022da:	f0 
f01022db:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01022e2:	f0 
f01022e3:	c7 44 24 04 17 04 00 	movl   $0x417,0x4(%esp)
f01022ea:	00 
f01022eb:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01022f2:	e8 49 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f01022f7:	ba 00 10 00 00       	mov    $0x1000,%edx
f01022fc:	89 f8                	mov    %edi,%eax
f01022fe:	e8 49 e8 ff ff       	call   f0100b4c <check_va2pa>
f0102303:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f0102306:	74 24                	je     f010232c <mem_init+0xeaf>
f0102308:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f010230f:	f0 
f0102310:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102317:	f0 
f0102318:	c7 44 24 04 18 04 00 	movl   $0x418,0x4(%esp)
f010231f:	00 
f0102320:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102327:	e8 14 dd ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f010232c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010232f:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f0102334:	74 24                	je     f010235a <mem_init+0xedd>
f0102336:	c7 44 24 0c 4b 6f 10 	movl   $0xf0106f4b,0xc(%esp)
f010233d:	f0 
f010233e:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102345:	f0 
f0102346:	c7 44 24 04 1a 04 00 	movl   $0x41a,0x4(%esp)
f010234d:	00 
f010234e:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102355:	e8 e6 dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010235a:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010235f:	74 24                	je     f0102385 <mem_init+0xf08>
f0102361:	c7 44 24 0c 5c 6f 10 	movl   $0xf0106f5c,0xc(%esp)
f0102368:	f0 
f0102369:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102370:	f0 
f0102371:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f0102378:	00 
f0102379:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102380:	e8 bb dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f0102385:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010238c:	e8 61 ed ff ff       	call   f01010f2 <page_alloc>
f0102391:	85 c0                	test   %eax,%eax
f0102393:	74 04                	je     f0102399 <mem_init+0xf1c>
f0102395:	39 c6                	cmp    %eax,%esi
f0102397:	74 24                	je     f01023bd <mem_init+0xf40>
f0102399:	c7 44 24 0c f8 74 10 	movl   $0xf01074f8,0xc(%esp)
f01023a0:	f0 
f01023a1:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01023a8:	f0 
f01023a9:	c7 44 24 04 1e 04 00 	movl   $0x41e,0x4(%esp)
f01023b0:	00 
f01023b1:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01023b8:	e8 83 dc ff ff       	call   f0100040 <_panic>
	cprintf("5");
f01023bd:	c7 04 24 6d 6f 10 f0 	movl   $0xf0106f6d,(%esp)
f01023c4:	e8 b0 1d 00 00       	call   f0104179 <cprintf>
	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023c9:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023d0:	00 
f01023d1:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01023d6:	89 04 24             	mov    %eax,(%esp)
f01023d9:	e8 8e ef ff ff       	call   f010136c <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01023de:	8b 3d 0c 3f 22 f0    	mov    0xf0223f0c,%edi
f01023e4:	ba 00 00 00 00       	mov    $0x0,%edx
f01023e9:	89 f8                	mov    %edi,%eax
f01023eb:	e8 5c e7 ff ff       	call   f0100b4c <check_va2pa>
f01023f0:	83 f8 ff             	cmp    $0xffffffff,%eax
f01023f3:	74 24                	je     f0102419 <mem_init+0xf9c>
f01023f5:	c7 44 24 0c 1c 75 10 	movl   $0xf010751c,0xc(%esp)
f01023fc:	f0 
f01023fd:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102404:	f0 
f0102405:	c7 44 24 04 22 04 00 	movl   $0x422,0x4(%esp)
f010240c:	00 
f010240d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102414:	e8 27 dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102419:	ba 00 10 00 00       	mov    $0x1000,%edx
f010241e:	89 f8                	mov    %edi,%eax
f0102420:	e8 27 e7 ff ff       	call   f0100b4c <check_va2pa>
f0102425:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102428:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f010242e:	c1 fa 03             	sar    $0x3,%edx
f0102431:	c1 e2 0c             	shl    $0xc,%edx
f0102434:	39 d0                	cmp    %edx,%eax
f0102436:	74 24                	je     f010245c <mem_init+0xfdf>
f0102438:	c7 44 24 0c c8 74 10 	movl   $0xf01074c8,0xc(%esp)
f010243f:	f0 
f0102440:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102447:	f0 
f0102448:	c7 44 24 04 23 04 00 	movl   $0x423,0x4(%esp)
f010244f:	00 
f0102450:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102457:	e8 e4 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f010245c:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010245f:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0102464:	74 24                	je     f010248a <mem_init+0x100d>
f0102466:	c7 44 24 0c fe 6e 10 	movl   $0xf0106efe,0xc(%esp)
f010246d:	f0 
f010246e:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102475:	f0 
f0102476:	c7 44 24 04 24 04 00 	movl   $0x424,0x4(%esp)
f010247d:	00 
f010247e:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102485:	e8 b6 db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010248a:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010248f:	74 24                	je     f01024b5 <mem_init+0x1038>
f0102491:	c7 44 24 0c 5c 6f 10 	movl   $0xf0106f5c,0xc(%esp)
f0102498:	f0 
f0102499:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01024a0:	f0 
f01024a1:	c7 44 24 04 25 04 00 	movl   $0x425,0x4(%esp)
f01024a8:	00 
f01024a9:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01024b0:	e8 8b db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024b5:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024bc:	00 
f01024bd:	89 3c 24             	mov    %edi,(%esp)
f01024c0:	e8 a7 ee ff ff       	call   f010136c <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024c5:	8b 3d 0c 3f 22 f0    	mov    0xf0223f0c,%edi
f01024cb:	ba 00 00 00 00       	mov    $0x0,%edx
f01024d0:	89 f8                	mov    %edi,%eax
f01024d2:	e8 75 e6 ff ff       	call   f0100b4c <check_va2pa>
f01024d7:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024da:	74 24                	je     f0102500 <mem_init+0x1083>
f01024dc:	c7 44 24 0c 1c 75 10 	movl   $0xf010751c,0xc(%esp)
f01024e3:	f0 
f01024e4:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01024eb:	f0 
f01024ec:	c7 44 24 04 29 04 00 	movl   $0x429,0x4(%esp)
f01024f3:	00 
f01024f4:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01024fb:	e8 40 db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102500:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102505:	89 f8                	mov    %edi,%eax
f0102507:	e8 40 e6 ff ff       	call   f0100b4c <check_va2pa>
f010250c:	83 f8 ff             	cmp    $0xffffffff,%eax
f010250f:	74 24                	je     f0102535 <mem_init+0x10b8>
f0102511:	c7 44 24 0c 40 75 10 	movl   $0xf0107540,0xc(%esp)
f0102518:	f0 
f0102519:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102520:	f0 
f0102521:	c7 44 24 04 2a 04 00 	movl   $0x42a,0x4(%esp)
f0102528:	00 
f0102529:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102530:	e8 0b db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0102535:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102538:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f010253d:	74 24                	je     f0102563 <mem_init+0x10e6>
f010253f:	c7 44 24 0c 6f 6f 10 	movl   $0xf0106f6f,0xc(%esp)
f0102546:	f0 
f0102547:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010254e:	f0 
f010254f:	c7 44 24 04 2b 04 00 	movl   $0x42b,0x4(%esp)
f0102556:	00 
f0102557:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010255e:	e8 dd da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102563:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102568:	74 24                	je     f010258e <mem_init+0x1111>
f010256a:	c7 44 24 0c 5c 6f 10 	movl   $0xf0106f5c,0xc(%esp)
f0102571:	f0 
f0102572:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102579:	f0 
f010257a:	c7 44 24 04 2c 04 00 	movl   $0x42c,0x4(%esp)
f0102581:	00 
f0102582:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102589:	e8 b2 da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f010258e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102595:	e8 58 eb ff ff       	call   f01010f2 <page_alloc>
f010259a:	85 c0                	test   %eax,%eax
f010259c:	74 05                	je     f01025a3 <mem_init+0x1126>
f010259e:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025a1:	74 24                	je     f01025c7 <mem_init+0x114a>
f01025a3:	c7 44 24 0c 68 75 10 	movl   $0xf0107568,0xc(%esp)
f01025aa:	f0 
f01025ab:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01025b2:	f0 
f01025b3:	c7 44 24 04 2f 04 00 	movl   $0x42f,0x4(%esp)
f01025ba:	00 
f01025bb:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01025c2:	e8 79 da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025c7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025ce:	e8 1f eb ff ff       	call   f01010f2 <page_alloc>
f01025d3:	85 c0                	test   %eax,%eax
f01025d5:	74 24                	je     f01025fb <mem_init+0x117e>
f01025d7:	c7 44 24 0c 9f 6e 10 	movl   $0xf0106e9f,0xc(%esp)
f01025de:	f0 
f01025df:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01025e6:	f0 
f01025e7:	c7 44 24 04 32 04 00 	movl   $0x432,0x4(%esp)
f01025ee:	00 
f01025ef:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01025f6:	e8 45 da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01025fb:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102600:	8b 08                	mov    (%eax),%ecx
f0102602:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102608:	89 da                	mov    %ebx,%edx
f010260a:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f0102610:	c1 fa 03             	sar    $0x3,%edx
f0102613:	c1 e2 0c             	shl    $0xc,%edx
f0102616:	39 d1                	cmp    %edx,%ecx
f0102618:	74 24                	je     f010263e <mem_init+0x11c1>
f010261a:	c7 44 24 0c 78 72 10 	movl   $0xf0107278,0xc(%esp)
f0102621:	f0 
f0102622:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102629:	f0 
f010262a:	c7 44 24 04 35 04 00 	movl   $0x435,0x4(%esp)
f0102631:	00 
f0102632:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102639:	e8 02 da ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f010263e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0102644:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102649:	74 24                	je     f010266f <mem_init+0x11f2>
f010264b:	c7 44 24 0c 0f 6f 10 	movl   $0xf0106f0f,0xc(%esp)
f0102652:	f0 
f0102653:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010265a:	f0 
f010265b:	c7 44 24 04 37 04 00 	movl   $0x437,0x4(%esp)
f0102662:	00 
f0102663:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010266a:	e8 d1 d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f010266f:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
	cprintf("6");
f0102675:	c7 04 24 80 6f 10 f0 	movl   $0xf0106f80,(%esp)
f010267c:	e8 f8 1a 00 00       	call   f0104179 <cprintf>
	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f0102681:	89 1c 24             	mov    %ebx,(%esp)
f0102684:	e8 ee ea ff ff       	call   f0101177 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102689:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102690:	00 
f0102691:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102698:	00 
f0102699:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f010269e:	89 04 24             	mov    %eax,(%esp)
f01026a1:	e8 0f eb ff ff       	call   f01011b5 <pgdir_walk>
f01026a6:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026a9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026ac:	8b 15 0c 3f 22 f0    	mov    0xf0223f0c,%edx
f01026b2:	8b 7a 04             	mov    0x4(%edx),%edi
f01026b5:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026bb:	8b 0d 08 3f 22 f0    	mov    0xf0223f08,%ecx
f01026c1:	89 f8                	mov    %edi,%eax
f01026c3:	c1 e8 0c             	shr    $0xc,%eax
f01026c6:	39 c8                	cmp    %ecx,%eax
f01026c8:	72 20                	jb     f01026ea <mem_init+0x126d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026ca:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01026ce:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f01026d5:	f0 
f01026d6:	c7 44 24 04 3e 04 00 	movl   $0x43e,0x4(%esp)
f01026dd:	00 
f01026de:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01026e5:	e8 56 d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f01026ea:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f01026f0:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f01026f3:	74 24                	je     f0102719 <mem_init+0x129c>
f01026f5:	c7 44 24 0c 82 6f 10 	movl   $0xf0106f82,0xc(%esp)
f01026fc:	f0 
f01026fd:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102704:	f0 
f0102705:	c7 44 24 04 3f 04 00 	movl   $0x43f,0x4(%esp)
f010270c:	00 
f010270d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102714:	e8 27 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102719:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f0102720:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102726:	89 d8                	mov    %ebx,%eax
f0102728:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f010272e:	c1 f8 03             	sar    $0x3,%eax
f0102731:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102734:	89 c2                	mov    %eax,%edx
f0102736:	c1 ea 0c             	shr    $0xc,%edx
f0102739:	39 d1                	cmp    %edx,%ecx
f010273b:	77 20                	ja     f010275d <mem_init+0x12e0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010273d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102741:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0102748:	f0 
f0102749:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102750:	00 
f0102751:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102758:	e8 e3 d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f010275d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102764:	00 
f0102765:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f010276c:	00 
	return (void *)(pa + KERNBASE);
f010276d:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102772:	89 04 24             	mov    %eax,(%esp)
f0102775:	e8 df 31 00 00       	call   f0105959 <memset>
	page_free(pp0);
f010277a:	89 1c 24             	mov    %ebx,(%esp)
f010277d:	e8 f5 e9 ff ff       	call   f0101177 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f0102782:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102789:	00 
f010278a:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0102791:	00 
f0102792:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102797:	89 04 24             	mov    %eax,(%esp)
f010279a:	e8 16 ea ff ff       	call   f01011b5 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010279f:	89 da                	mov    %ebx,%edx
f01027a1:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f01027a7:	c1 fa 03             	sar    $0x3,%edx
f01027aa:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027ad:	89 d0                	mov    %edx,%eax
f01027af:	c1 e8 0c             	shr    $0xc,%eax
f01027b2:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f01027b8:	72 20                	jb     f01027da <mem_init+0x135d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027ba:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027be:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f01027c5:	f0 
f01027c6:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027cd:	00 
f01027ce:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f01027d5:	e8 66 d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027da:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027e0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01027e3:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01027ea:	75 11                	jne    f01027fd <mem_init+0x1380>
f01027ec:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01027f2:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01027f8:	f6 00 01             	testb  $0x1,(%eax)
f01027fb:	74 24                	je     f0102821 <mem_init+0x13a4>
f01027fd:	c7 44 24 0c 9a 6f 10 	movl   $0xf0106f9a,0xc(%esp)
f0102804:	f0 
f0102805:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010280c:	f0 
f010280d:	c7 44 24 04 49 04 00 	movl   $0x449,0x4(%esp)
f0102814:	00 
f0102815:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010281c:	e8 1f d8 ff ff       	call   f0100040 <_panic>
f0102821:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f0102824:	39 d0                	cmp    %edx,%eax
f0102826:	75 d0                	jne    f01027f8 <mem_init+0x137b>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102828:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f010282d:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f0102833:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
	cprintf("7");
f0102839:	c7 04 24 b1 6f 10 f0 	movl   $0xf0106fb1,(%esp)
f0102840:	e8 34 19 00 00       	call   f0104179 <cprintf>
	// give free list back
	page_free_list = fl;
f0102845:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102848:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f010284d:	89 1c 24             	mov    %ebx,(%esp)
f0102850:	e8 22 e9 ff ff       	call   f0101177 <page_free>
	page_free(pp1);
f0102855:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102858:	89 04 24             	mov    %eax,(%esp)
f010285b:	e8 17 e9 ff ff       	call   f0101177 <page_free>
	page_free(pp2);
f0102860:	89 34 24             	mov    %esi,(%esp)
f0102863:	e8 0f e9 ff ff       	call   f0101177 <page_free>

	cprintf("check_page() succeeded!\n");
f0102868:	c7 04 24 b3 6f 10 f0 	movl   $0xf0106fb3,(%esp)
f010286f:	e8 05 19 00 00       	call   f0104179 <cprintf>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f0102874:	8b 0d 08 3f 22 f0    	mov    0xf0223f08,%ecx
f010287a:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102881:	89 c2                	mov    %eax,%edx
f0102883:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f0102889:	39 c2                	cmp    %eax,%edx
f010288b:	0f 84 ef 0b 00 00    	je     f0103480 <mem_init+0x2003>
	{

		page_insert(kern_pgdir, pa2page(PADDR(pages)+i),(void*) (UPAGES+i), PTE_U);
f0102891:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102896:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010289b:	76 21                	jbe    f01028be <mem_init+0x1441>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f010289d:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028a3:	c1 ea 0c             	shr    $0xc,%edx
f01028a6:	39 ca                	cmp    %ecx,%edx
f01028a8:	72 5e                	jb     f0102908 <mem_init+0x148b>
f01028aa:	eb 40                	jmp    f01028ec <mem_init+0x146f>
f01028ac:	8d b3 00 00 00 ef    	lea    -0x11000000(%ebx),%esi
f01028b2:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028b7:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028bc:	77 20                	ja     f01028de <mem_init+0x1461>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028be:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028c2:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f01028c9:	f0 
f01028ca:	c7 44 24 04 b7 00 00 	movl   $0xb7,0x4(%esp)
f01028d1:	00 
f01028d2:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01028d9:	e8 62 d7 ff ff       	call   f0100040 <_panic>
f01028de:	8d 94 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028e5:	c1 ea 0c             	shr    $0xc,%edx
f01028e8:	39 d1                	cmp    %edx,%ecx
f01028ea:	77 26                	ja     f0102912 <mem_init+0x1495>
		panic("pa2page called with invalid pa");
f01028ec:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f01028f3:	f0 
f01028f4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01028fb:	00 
f01028fc:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102903:	e8 38 d7 ff ff       	call   f0100040 <_panic>
f0102908:	be 00 00 00 ef       	mov    $0xef000000,%esi
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f010290d:	bb 00 00 00 00       	mov    $0x0,%ebx
	{

		page_insert(kern_pgdir, pa2page(PADDR(pages)+i),(void*) (UPAGES+i), PTE_U);
f0102912:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102919:	00 
f010291a:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f010291e:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f0102921:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102925:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f010292a:	89 04 24             	mov    %eax,(%esp)
f010292d:	e8 8a ea ff ff       	call   f01013bc <page_insert>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f0102932:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102938:	89 da                	mov    %ebx,%edx
f010293a:	8b 0d 08 3f 22 f0    	mov    0xf0223f08,%ecx
f0102940:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102947:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010294c:	39 c3                	cmp    %eax,%ebx
f010294e:	0f 82 58 ff ff ff    	jb     f01028ac <mem_init+0x142f>
f0102954:	e9 27 0b 00 00       	jmp    f0103480 <mem_init+0x2003>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102959:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010295e:	c1 e8 0c             	shr    $0xc,%eax
f0102961:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0102967:	0f 82 1d 0c 00 00    	jb     f010358a <mem_init+0x210d>
f010296d:	eb 44                	jmp    f01029b3 <mem_init+0x1536>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f010296f:	8d 8a 00 00 c0 ee    	lea    -0x11400000(%edx),%ecx
f0102975:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010297a:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010297f:	77 20                	ja     f01029a1 <mem_init+0x1524>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102981:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102985:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f010298c:	f0 
f010298d:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
f0102994:	00 
f0102995:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010299c:	e8 9f d6 ff ff       	call   f0100040 <_panic>
f01029a1:	8d 84 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01029a8:	c1 e8 0c             	shr    $0xc,%eax
f01029ab:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f01029b1:	72 1c                	jb     f01029cf <mem_init+0x1552>
		panic("pa2page called with invalid pa");
f01029b3:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f01029ba:	f0 
f01029bb:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01029c2:	00 
f01029c3:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f01029ca:	e8 71 d6 ff ff       	call   f0100040 <_panic>
f01029cf:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01029d6:	00 
f01029d7:	89 4c 24 08          	mov    %ecx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01029db:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
f01029e1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01029e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01029e8:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01029ed:	89 04 24             	mov    %eax,(%esp)
f01029f0:	e8 c7 e9 ff ff       	call   f01013bc <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01029f5:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01029fb:	89 da                	mov    %ebx,%edx
f01029fd:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f0102a03:	0f 85 66 ff ff ff    	jne    f010296f <mem_init+0x14f2>
f0102a09:	e9 ac 0a 00 00       	jmp    f01034ba <mem_init+0x203d>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102a0e:	b8 00 60 11 00       	mov    $0x116000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102a13:	c1 e8 0c             	shr    $0xc,%eax
f0102a16:	39 05 08 3f 22 f0    	cmp    %eax,0xf0223f08
f0102a1c:	0f 87 24 0b 00 00    	ja     f0103546 <mem_init+0x20c9>
f0102a22:	eb 36                	jmp    f0102a5a <mem_init+0x15dd>
f0102a24:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102a27:	89 d8                	mov    %ebx,%eax
f0102a29:	c1 e8 0c             	shr    $0xc,%eax
f0102a2c:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0102a32:	72 42                	jb     f0102a76 <mem_init+0x15f9>
f0102a34:	eb 24                	jmp    f0102a5a <mem_init+0x15dd>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a36:	c7 44 24 0c 00 60 11 	movl   $0xf0116000,0xc(%esp)
f0102a3d:	f0 
f0102a3e:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0102a45:	f0 
f0102a46:	c7 44 24 04 dc 00 00 	movl   $0xdc,0x4(%esp)
f0102a4d:	00 
f0102a4e:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102a55:	e8 e6 d5 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102a5a:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0102a61:	f0 
f0102a62:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a69:	00 
f0102a6a:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102a71:	e8 ca d5 ff ff       	call   f0100040 <_panic>
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
f0102a76:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102a7d:	00 
f0102a7e:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a82:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
f0102a88:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102a8b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a8f:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102a94:	89 04 24             	mov    %eax,(%esp)
f0102a97:	e8 20 e9 ff ff       	call   f01013bc <page_insert>
f0102a9c:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f0102aa2:	39 fb                	cmp    %edi,%ebx
f0102aa4:	0f 85 7a ff ff ff    	jne    f0102a24 <mem_init+0x15a7>
f0102aaa:	e9 20 0a 00 00       	jmp    f01034cf <mem_init+0x2052>
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
    {
    	if(i<npages*PGSIZE)
f0102aaf:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
f0102ab4:	89 c2                	mov    %eax,%edx
f0102ab6:	c1 e2 0c             	shl    $0xc,%edx
f0102ab9:	39 f2                	cmp    %esi,%edx
f0102abb:	0f 86 86 00 00 00    	jbe    f0102b47 <mem_init+0x16ca>
    	{
    		page_insert(kern_pgdir,pa2page(i),(void*)(KERNBASE+i),PTE_W);
f0102ac1:	8d 96 00 00 00 f0    	lea    -0x10000000(%esi),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ac7:	c1 ee 0c             	shr    $0xc,%esi
f0102aca:	39 f0                	cmp    %esi,%eax
f0102acc:	77 1c                	ja     f0102aea <mem_init+0x166d>
		panic("pa2page called with invalid pa");
f0102ace:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0102ad5:	f0 
f0102ad6:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102add:	00 
f0102ade:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102ae5:	e8 56 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102aea:	8d 3c f5 00 00 00 00 	lea    0x0(,%esi,8),%edi
f0102af1:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102af8:	00 
f0102af9:	89 54 24 08          	mov    %edx,0x8(%esp)
f0102afd:	89 f8                	mov    %edi,%eax
f0102aff:	03 05 10 3f 22 f0    	add    0xf0223f10,%eax
f0102b05:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102b09:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102b0e:	89 04 24             	mov    %eax,(%esp)
f0102b11:	e8 a6 e8 ff ff       	call   f01013bc <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b16:	3b 35 08 3f 22 f0    	cmp    0xf0223f08,%esi
f0102b1c:	72 1c                	jb     f0102b3a <mem_init+0x16bd>
		panic("pa2page called with invalid pa");
f0102b1e:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0102b25:	f0 
f0102b26:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b2d:	00 
f0102b2e:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102b35:	e8 06 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b3a:	03 3d 10 3f 22 f0    	add    0xf0223f10,%edi
    		pa2page(i)->pp_ref--;
f0102b40:	66 83 6f 04 01       	subw   $0x1,0x4(%edi)
f0102b45:	eb 77                	jmp    f0102bbe <mem_init+0x1741>
    	}
    	else
    	{
    		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
f0102b47:	81 ee 00 00 00 10    	sub    $0x10000000,%esi
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b4d:	85 c0                	test   %eax,%eax
f0102b4f:	75 1c                	jne    f0102b6d <mem_init+0x16f0>
		panic("pa2page called with invalid pa");
f0102b51:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0102b58:	f0 
f0102b59:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b60:	00 
f0102b61:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102b68:	e8 d3 d4 ff ff       	call   f0100040 <_panic>
f0102b6d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102b74:	00 
f0102b75:	89 74 24 08          	mov    %esi,0x8(%esp)
f0102b79:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
f0102b7e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102b82:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0102b87:	89 04 24             	mov    %eax,(%esp)
f0102b8a:	e8 2d e8 ff ff       	call   f01013bc <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b8f:	83 3d 08 3f 22 f0 00 	cmpl   $0x0,0xf0223f08
f0102b96:	75 1c                	jne    f0102bb4 <mem_init+0x1737>
		panic("pa2page called with invalid pa");
f0102b98:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0102b9f:	f0 
f0102ba0:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102ba7:	00 
f0102ba8:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0102baf:	e8 8c d4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102bb4:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
    		pa2page(0)->pp_ref--;
f0102bb9:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102bbe:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102bc4:	89 de                	mov    %ebx,%esi
f0102bc6:	81 fb 00 00 00 10    	cmp    $0x10000000,%ebx
f0102bcc:	0f 85 dd fe ff ff    	jne    f0102aaf <mem_init+0x1632>
f0102bd2:	e9 2c 09 00 00       	jmp    f0103503 <mem_init+0x2086>
{
	cprintf("boot_map_region\r\n");
	int i=0;
	for(;i<size/PGSIZE;i++)
	{
		pte_t* pte=pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
f0102bd7:	89 df                	mov    %ebx,%edi
f0102bd9:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102be0:	00 
f0102be1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102be5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102be8:	89 04 24             	mov    %eax,(%esp)
f0102beb:	e8 c5 e5 ff ff       	call   f01011b5 <pgdir_walk>
f0102bf0:	89 c6                	mov    %eax,%esi
		if(*pte==0)
f0102bf2:	83 38 00             	cmpl   $0x0,(%eax)
f0102bf5:	75 0c                	jne    f0102c03 <mem_init+0x1786>
		{
			struct Page* page=page_alloc(1);
f0102bf7:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0102bfe:	e8 ef e4 ff ff       	call   f01010f2 <page_alloc>
			*pte=page2pa(page);

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
f0102c03:	83 cf 03             	or     $0x3,%edi
f0102c06:	89 3e                	mov    %edi,(%esi)
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	cprintf("boot_map_region\r\n");
	int i=0;
	for(;i<size/PGSIZE;i++)
f0102c08:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102c0e:	75 c7                	jne    f0102bd7 <mem_init+0x175a>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102c10:	8b 3d 0c 3f 22 f0    	mov    0xf0223f0c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102c16:	a1 08 3f 22 f0       	mov    0xf0223f08,%eax
f0102c1b:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102c1e:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102c25:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102c2a:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102c2d:	75 30                	jne    f0102c5f <mem_init+0x17e2>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102c2f:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c35:	89 de                	mov    %ebx,%esi
f0102c37:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102c3c:	89 f8                	mov    %edi,%eax
f0102c3e:	e8 09 df ff ff       	call   f0100b4c <check_va2pa>
f0102c43:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102c49:	0f 86 94 00 00 00    	jbe    f0102ce3 <mem_init+0x1866>
f0102c4f:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102c54:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102c5a:	e9 a4 00 00 00       	jmp    f0102d03 <mem_init+0x1886>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102c5f:	8b 1d 10 3f 22 f0    	mov    0xf0223f10,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102c65:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102c6b:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102c70:	89 f8                	mov    %edi,%eax
f0102c72:	e8 d5 de ff ff       	call   f0100b4c <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c77:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102c7d:	77 20                	ja     f0102c9f <mem_init+0x1822>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c7f:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102c83:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0102c8a:	f0 
f0102c8b:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102c92:	00 
f0102c93:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102c9a:	e8 a1 d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102c9f:	ba 00 00 00 00       	mov    $0x0,%edx
f0102ca4:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102ca7:	39 c1                	cmp    %eax,%ecx
f0102ca9:	74 24                	je     f0102ccf <mem_init+0x1852>
f0102cab:	c7 44 24 0c 8c 75 10 	movl   $0xf010758c,0xc(%esp)
f0102cb2:	f0 
f0102cb3:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102cba:	f0 
f0102cbb:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102cc2:	00 
f0102cc3:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102cca:	e8 71 d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102ccf:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102cd5:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102cd8:	0f 87 0f 09 00 00    	ja     f01035ed <mem_init+0x2170>
f0102cde:	e9 4c ff ff ff       	jmp    f0102c2f <mem_init+0x17b2>
f0102ce3:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102ce7:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0102cee:	f0 
f0102cef:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0102cf6:	00 
f0102cf7:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102cfe:	e8 3d d3 ff ff       	call   f0100040 <_panic>
f0102d03:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102d06:	39 c2                	cmp    %eax,%edx
f0102d08:	74 24                	je     f0102d2e <mem_init+0x18b1>
f0102d0a:	c7 44 24 0c c0 75 10 	movl   $0xf01075c0,0xc(%esp)
f0102d11:	f0 
f0102d12:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102d19:	f0 
f0102d1a:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0102d21:	00 
f0102d22:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102d29:	e8 12 d3 ff ff       	call   f0100040 <_panic>
f0102d2e:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102d34:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102d3a:	0f 85 9f 08 00 00    	jne    f01035df <mem_init+0x2162>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102d40:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102d43:	c1 e6 0c             	shl    $0xc,%esi
f0102d46:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102d4b:	85 f6                	test   %esi,%esi
f0102d4d:	75 07                	jne    f0102d56 <mem_init+0x18d9>
f0102d4f:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102d54:	eb 41                	jmp    f0102d97 <mem_init+0x191a>
f0102d56:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
	{

		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102d5c:	89 f8                	mov    %edi,%eax
f0102d5e:	e8 e9 dd ff ff       	call   f0100b4c <check_va2pa>
f0102d63:	39 c3                	cmp    %eax,%ebx
f0102d65:	74 24                	je     f0102d8b <mem_init+0x190e>
f0102d67:	c7 44 24 0c f4 75 10 	movl   $0xf01075f4,0xc(%esp)
f0102d6e:	f0 
f0102d6f:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102d76:	f0 
f0102d77:	c7 44 24 04 83 03 00 	movl   $0x383,0x4(%esp)
f0102d7e:	00 
f0102d7f:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102d86:	e8 b5 d2 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102d8b:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102d91:	39 f3                	cmp    %esi,%ebx
f0102d93:	72 c1                	jb     f0102d56 <mem_init+0x18d9>
f0102d95:	eb b8                	jmp    f0102d4f <mem_init+0x18d2>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
	}

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102d97:	89 da                	mov    %ebx,%edx
f0102d99:	89 f8                	mov    %edi,%eax
f0102d9b:	e8 ac dd ff ff       	call   f0100b4c <check_va2pa>
f0102da0:	39 c3                	cmp    %eax,%ebx
f0102da2:	74 24                	je     f0102dc8 <mem_init+0x194b>
f0102da4:	c7 44 24 0c cc 6f 10 	movl   $0xf0106fcc,0xc(%esp)
f0102dab:	f0 
f0102dac:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102db3:	f0 
f0102db4:	c7 44 24 04 88 03 00 	movl   $0x388,0x4(%esp)
f0102dbb:	00 
f0102dbc:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102dc3:	e8 78 d2 ff ff       	call   f0100040 <_panic>

		assert(check_va2pa(pgdir, KERNBASE + i) == i);
	}

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102dc8:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102dce:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102dd4:	75 c1                	jne    f0102d97 <mem_init+0x191a>
	// check kernel stack
//<<<<<<< HEAD
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
	{

		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f0102dd6:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f0102ddb:	89 f8                	mov    %edi,%eax
f0102ddd:	e8 6a dd ff ff       	call   f0100b4c <check_va2pa>
f0102de2:	bb 00 80 bf ef       	mov    $0xefbf8000,%ebx
f0102de7:	be 00 60 11 f0       	mov    $0xf0116000,%esi
f0102dec:	81 c6 00 80 40 20    	add    $0x20408000,%esi
f0102df2:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102df5:	39 d0                	cmp    %edx,%eax
f0102df7:	74 24                	je     f0102e1d <mem_init+0x19a0>
f0102df9:	c7 44 24 0c 1c 76 10 	movl   $0xf010761c,0xc(%esp)
f0102e00:	f0 
f0102e01:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102e08:	f0 
f0102e09:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f0102e10:	00 
f0102e11:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102e18:	e8 23 d2 ff ff       	call   f0100040 <_panic>
f0102e1d:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
//<<<<<<< HEAD
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102e23:	81 fb 00 00 c0 ef    	cmp    $0xefc00000,%ebx
f0102e29:	0f 85 a2 07 00 00    	jne    f01035d1 <mem_init+0x2154>
	{

		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);

	}
			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
f0102e2f:	ba 00 00 80 ef       	mov    $0xef800000,%edx
f0102e34:	89 f8                	mov    %edi,%eax
f0102e36:	e8 11 dd ff ff       	call   f0100b4c <check_va2pa>
f0102e3b:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102e3e:	74 24                	je     f0102e64 <mem_init+0x19e7>
f0102e40:	c7 44 24 0c 64 76 10 	movl   $0xf0107664,0xc(%esp)
f0102e47:	f0 
f0102e48:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102e4f:	f0 
f0102e50:	c7 44 24 04 92 03 00 	movl   $0x392,0x4(%esp)
f0102e57:	00 
f0102e58:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102e5f:	e8 dc d1 ff ff       	call   f0100040 <_panic>
f0102e64:	c7 45 d0 00 50 22 f0 	movl   $0xf0225000,-0x30(%ebp)
f0102e6b:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102e72:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102e77:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102e7d:	89 45 d4             	mov    %eax,-0x2c(%ebp)
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102e80:	89 f2                	mov    %esi,%edx
f0102e82:	89 f8                	mov    %edi,%eax
f0102e84:	e8 c3 dc ff ff       	call   f0100b4c <check_va2pa>
f0102e89:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102e8c:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102e92:	77 20                	ja     f0102eb4 <mem_init+0x1a37>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102e94:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102e98:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0102e9f:	f0 
f0102ea0:	c7 44 24 04 99 03 00 	movl   $0x399,0x4(%esp)
f0102ea7:	00 
f0102ea8:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102eaf:	e8 8c d1 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102eb4:	89 f3                	mov    %esi,%ebx
f0102eb6:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0102eb9:	81 c1 00 d0 62 10    	add    $0x1062d000,%ecx
f0102ebf:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102ec2:	89 ce                	mov    %ecx,%esi
f0102ec4:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102ec7:	39 c2                	cmp    %eax,%edx
f0102ec9:	74 24                	je     f0102eef <mem_init+0x1a72>
f0102ecb:	c7 44 24 0c 94 76 10 	movl   $0xf0107694,0xc(%esp)
f0102ed2:	f0 
f0102ed3:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102eda:	f0 
f0102edb:	c7 44 24 04 99 03 00 	movl   $0x399,0x4(%esp)
f0102ee2:	00 
f0102ee3:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102eea:	e8 51 d1 ff ff       	call   f0100040 <_panic>
f0102eef:	81 c3 00 10 00 00    	add    $0x1000,%ebx
			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102ef5:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102ef8:	0f 85 c5 06 00 00    	jne    f01035c3 <mem_init+0x2146>
f0102efe:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102f01:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102f07:	89 da                	mov    %ebx,%edx
f0102f09:	89 f8                	mov    %edi,%eax
f0102f0b:	e8 3c dc ff ff       	call   f0100b4c <check_va2pa>
f0102f10:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102f13:	74 24                	je     f0102f39 <mem_init+0x1abc>
f0102f15:	c7 44 24 0c dc 76 10 	movl   $0xf01076dc,0xc(%esp)
f0102f1c:	f0 
f0102f1d:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102f24:	f0 
f0102f25:	c7 44 24 04 9b 03 00 	movl   $0x39b,0x4(%esp)
f0102f2c:	00 
f0102f2d:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102f34:	e8 07 d1 ff ff       	call   f0100040 <_panic>
f0102f39:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102f3f:	39 f3                	cmp    %esi,%ebx
f0102f41:	75 c4                	jne    f0102f07 <mem_init+0x1a8a>
f0102f43:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102f49:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102f50:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)

	}
			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102f57:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102f5d:	0f 85 14 ff ff ff    	jne    f0102e77 <mem_init+0x19fa>
f0102f63:	b8 00 00 00 00       	mov    $0x0,%eax
	}
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102f68:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102f6e:	83 fa 03             	cmp    $0x3,%edx
f0102f71:	77 2e                	ja     f0102fa1 <mem_init+0x1b24>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102f73:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102f77:	0f 85 aa 00 00 00    	jne    f0103027 <mem_init+0x1baa>
f0102f7d:	c7 44 24 0c e7 6f 10 	movl   $0xf0106fe7,0xc(%esp)
f0102f84:	f0 
f0102f85:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102f8c:	f0 
f0102f8d:	c7 44 24 04 a6 03 00 	movl   $0x3a6,0x4(%esp)
f0102f94:	00 
f0102f95:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102f9c:	e8 9f d0 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102fa1:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102fa6:	76 55                	jbe    f0102ffd <mem_init+0x1b80>
				assert(pgdir[i] & PTE_P);
f0102fa8:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102fab:	f6 c2 01             	test   $0x1,%dl
f0102fae:	75 24                	jne    f0102fd4 <mem_init+0x1b57>
f0102fb0:	c7 44 24 0c e7 6f 10 	movl   $0xf0106fe7,0xc(%esp)
f0102fb7:	f0 
f0102fb8:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102fbf:	f0 
f0102fc0:	c7 44 24 04 aa 03 00 	movl   $0x3aa,0x4(%esp)
f0102fc7:	00 
f0102fc8:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102fcf:	e8 6c d0 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102fd4:	f6 c2 02             	test   $0x2,%dl
f0102fd7:	75 4e                	jne    f0103027 <mem_init+0x1baa>
f0102fd9:	c7 44 24 0c f8 6f 10 	movl   $0xf0106ff8,0xc(%esp)
f0102fe0:	f0 
f0102fe1:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0102fe8:	f0 
f0102fe9:	c7 44 24 04 ab 03 00 	movl   $0x3ab,0x4(%esp)
f0102ff0:	00 
f0102ff1:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0102ff8:	e8 43 d0 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102ffd:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f0103001:	74 24                	je     f0103027 <mem_init+0x1baa>
f0103003:	c7 44 24 0c 09 70 10 	movl   $0xf0107009,0xc(%esp)
f010300a:	f0 
f010300b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0103012:	f0 
f0103013:	c7 44 24 04 ad 03 00 	movl   $0x3ad,0x4(%esp)
f010301a:	00 
f010301b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0103022:	e8 19 d0 ff ff       	call   f0100040 <_panic>
			assert(check_va2pa(pgdir, base + i) == ~0);
	}
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0103027:	83 c0 01             	add    $0x1,%eax
f010302a:	3d 00 04 00 00       	cmp    $0x400,%eax
f010302f:	0f 85 33 ff ff ff    	jne    f0102f68 <mem_init+0x1aeb>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0103035:	c7 04 24 00 77 10 f0 	movl   $0xf0107700,(%esp)
f010303c:	e8 38 11 00 00       	call   f0104179 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0103041:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0103046:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010304b:	77 20                	ja     f010306d <mem_init+0x1bf0>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010304d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103051:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0103058:	f0 
f0103059:	c7 44 24 04 0b 01 00 	movl   $0x10b,0x4(%esp)
f0103060:	00 
f0103061:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0103068:	e8 d3 cf ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010306d:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103072:	0f 22 d8             	mov    %eax,%cr3
	cprintf("env_id:%d\r\n",(((struct Env*)UENVS)[0]).env_id);
f0103075:	a1 48 00 c0 ee       	mov    0xeec00048,%eax
f010307a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010307e:	c7 04 24 17 70 10 f0 	movl   $0xf0107017,(%esp)
f0103085:	e8 ef 10 00 00       	call   f0104179 <cprintf>
	cprintf("%d\r\n",page_free_list->pp_ref);
f010308a:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f010308f:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f0103093:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103097:	c7 04 24 05 78 10 f0 	movl   $0xf0107805,(%esp)
f010309e:	e8 d6 10 00 00       	call   f0104179 <cprintf>
	check_page_free_list(0);
f01030a3:	b8 00 00 00 00       	mov    $0x0,%eax
f01030a8:	e8 0e db ff ff       	call   f0100bbb <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f01030ad:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f01030b0:	83 e0 f3             	and    $0xfffffff3,%eax
f01030b3:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f01030b8:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01030bb:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01030c2:	e8 2b e0 ff ff       	call   f01010f2 <page_alloc>
f01030c7:	89 c3                	mov    %eax,%ebx
f01030c9:	85 c0                	test   %eax,%eax
f01030cb:	75 24                	jne    f01030f1 <mem_init+0x1c74>
f01030cd:	c7 44 24 0c f4 6d 10 	movl   $0xf0106df4,0xc(%esp)
f01030d4:	f0 
f01030d5:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01030dc:	f0 
f01030dd:	c7 44 24 04 64 04 00 	movl   $0x464,0x4(%esp)
f01030e4:	00 
f01030e5:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01030ec:	e8 4f cf ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01030f1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01030f8:	e8 f5 df ff ff       	call   f01010f2 <page_alloc>
f01030fd:	89 c7                	mov    %eax,%edi
f01030ff:	85 c0                	test   %eax,%eax
f0103101:	75 24                	jne    f0103127 <mem_init+0x1caa>
f0103103:	c7 44 24 0c 0a 6e 10 	movl   $0xf0106e0a,0xc(%esp)
f010310a:	f0 
f010310b:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0103112:	f0 
f0103113:	c7 44 24 04 65 04 00 	movl   $0x465,0x4(%esp)
f010311a:	00 
f010311b:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0103122:	e8 19 cf ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0103127:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010312e:	e8 bf df ff ff       	call   f01010f2 <page_alloc>
f0103133:	89 c6                	mov    %eax,%esi
f0103135:	85 c0                	test   %eax,%eax
f0103137:	75 24                	jne    f010315d <mem_init+0x1ce0>
f0103139:	c7 44 24 0c 20 6e 10 	movl   $0xf0106e20,0xc(%esp)
f0103140:	f0 
f0103141:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0103148:	f0 
f0103149:	c7 44 24 04 66 04 00 	movl   $0x466,0x4(%esp)
f0103150:	00 
f0103151:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0103158:	e8 e3 ce ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f010315d:	89 1c 24             	mov    %ebx,(%esp)
f0103160:	e8 12 e0 ff ff       	call   f0101177 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103165:	89 f8                	mov    %edi,%eax
f0103167:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f010316d:	c1 f8 03             	sar    $0x3,%eax
f0103170:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103173:	89 c2                	mov    %eax,%edx
f0103175:	c1 ea 0c             	shr    $0xc,%edx
f0103178:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f010317e:	72 20                	jb     f01031a0 <mem_init+0x1d23>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103180:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103184:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f010318b:	f0 
f010318c:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103193:	00 
f0103194:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f010319b:	e8 a0 ce ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f01031a0:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01031a7:	00 
f01031a8:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01031af:	00 
	return (void *)(pa + KERNBASE);
f01031b0:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01031b5:	89 04 24             	mov    %eax,(%esp)
f01031b8:	e8 9c 27 00 00       	call   f0105959 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01031bd:	89 f0                	mov    %esi,%eax
f01031bf:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f01031c5:	c1 f8 03             	sar    $0x3,%eax
f01031c8:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01031cb:	89 c2                	mov    %eax,%edx
f01031cd:	c1 ea 0c             	shr    $0xc,%edx
f01031d0:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f01031d6:	72 20                	jb     f01031f8 <mem_init+0x1d7b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01031d8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01031dc:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f01031e3:	f0 
f01031e4:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01031eb:	00 
f01031ec:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f01031f3:	e8 48 ce ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f01031f8:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01031ff:	00 
f0103200:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0103207:	00 
	return (void *)(pa + KERNBASE);
f0103208:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010320d:	89 04 24             	mov    %eax,(%esp)
f0103210:	e8 44 27 00 00       	call   f0105959 <memset>

	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0103215:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010321c:	00 
f010321d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0103224:	00 
f0103225:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103229:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f010322e:	89 04 24             	mov    %eax,(%esp)
f0103231:	e8 86 e1 ff ff       	call   f01013bc <page_insert>

	assert(pp1->pp_ref == 1);
f0103236:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f010323b:	74 24                	je     f0103261 <mem_init+0x1de4>
f010323d:	c7 44 24 0c fe 6e 10 	movl   $0xf0106efe,0xc(%esp)
f0103244:	f0 
f0103245:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010324c:	f0 
f010324d:	c7 44 24 04 6d 04 00 	movl   $0x46d,0x4(%esp)
f0103254:	00 
f0103255:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010325c:	e8 df cd ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0103261:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0103268:	01 01 01 
f010326b:	74 24                	je     f0103291 <mem_init+0x1e14>
f010326d:	c7 44 24 0c 20 77 10 	movl   $0xf0107720,0xc(%esp)
f0103274:	f0 
f0103275:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010327c:	f0 
f010327d:	c7 44 24 04 6e 04 00 	movl   $0x46e,0x4(%esp)
f0103284:	00 
f0103285:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010328c:	e8 af cd ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0103291:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103298:	00 
f0103299:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01032a0:	00 
f01032a1:	89 74 24 04          	mov    %esi,0x4(%esp)
f01032a5:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01032aa:	89 04 24             	mov    %eax,(%esp)
f01032ad:	e8 0a e1 ff ff       	call   f01013bc <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f01032b2:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f01032b9:	02 02 02 
f01032bc:	74 24                	je     f01032e2 <mem_init+0x1e65>
f01032be:	c7 44 24 0c 44 77 10 	movl   $0xf0107744,0xc(%esp)
f01032c5:	f0 
f01032c6:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01032cd:	f0 
f01032ce:	c7 44 24 04 70 04 00 	movl   $0x470,0x4(%esp)
f01032d5:	00 
f01032d6:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01032dd:	e8 5e cd ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f01032e2:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f01032e7:	74 24                	je     f010330d <mem_init+0x1e90>
f01032e9:	c7 44 24 0c 20 6f 10 	movl   $0xf0106f20,0xc(%esp)
f01032f0:	f0 
f01032f1:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01032f8:	f0 
f01032f9:	c7 44 24 04 71 04 00 	movl   $0x471,0x4(%esp)
f0103300:	00 
f0103301:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0103308:	e8 33 cd ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f010330d:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f0103312:	74 24                	je     f0103338 <mem_init+0x1ebb>
f0103314:	c7 44 24 0c 6f 6f 10 	movl   $0xf0106f6f,0xc(%esp)
f010331b:	f0 
f010331c:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0103323:	f0 
f0103324:	c7 44 24 04 72 04 00 	movl   $0x472,0x4(%esp)
f010332b:	00 
f010332c:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f0103333:	e8 08 cd ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0103338:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f010333f:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103342:	89 f0                	mov    %esi,%eax
f0103344:	2b 05 10 3f 22 f0    	sub    0xf0223f10,%eax
f010334a:	c1 f8 03             	sar    $0x3,%eax
f010334d:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103350:	89 c2                	mov    %eax,%edx
f0103352:	c1 ea 0c             	shr    $0xc,%edx
f0103355:	3b 15 08 3f 22 f0    	cmp    0xf0223f08,%edx
f010335b:	72 20                	jb     f010337d <mem_init+0x1f00>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010335d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103361:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0103368:	f0 
f0103369:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103370:	00 
f0103371:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0103378:	e8 c3 cc ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f010337d:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f0103384:	03 03 03 
f0103387:	74 24                	je     f01033ad <mem_init+0x1f30>
f0103389:	c7 44 24 0c 68 77 10 	movl   $0xf0107768,0xc(%esp)
f0103390:	f0 
f0103391:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0103398:	f0 
f0103399:	c7 44 24 04 74 04 00 	movl   $0x474,0x4(%esp)
f01033a0:	00 
f01033a1:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01033a8:	e8 93 cc ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01033ad:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01033b4:	00 
f01033b5:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01033ba:	89 04 24             	mov    %eax,(%esp)
f01033bd:	e8 aa df ff ff       	call   f010136c <page_remove>
	assert(pp2->pp_ref == 0);
f01033c2:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01033c7:	74 24                	je     f01033ed <mem_init+0x1f70>
f01033c9:	c7 44 24 0c 5c 6f 10 	movl   $0xf0106f5c,0xc(%esp)
f01033d0:	f0 
f01033d1:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f01033d8:	f0 
f01033d9:	c7 44 24 04 76 04 00 	movl   $0x476,0x4(%esp)
f01033e0:	00 
f01033e1:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f01033e8:	e8 53 cc ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01033ed:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01033f2:	8b 08                	mov    (%eax),%ecx
f01033f4:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01033fa:	89 da                	mov    %ebx,%edx
f01033fc:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f0103402:	c1 fa 03             	sar    $0x3,%edx
f0103405:	c1 e2 0c             	shl    $0xc,%edx
f0103408:	39 d1                	cmp    %edx,%ecx
f010340a:	74 24                	je     f0103430 <mem_init+0x1fb3>
f010340c:	c7 44 24 0c 78 72 10 	movl   $0xf0107278,0xc(%esp)
f0103413:	f0 
f0103414:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010341b:	f0 
f010341c:	c7 44 24 04 79 04 00 	movl   $0x479,0x4(%esp)
f0103423:	00 
f0103424:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010342b:	e8 10 cc ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0103430:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103436:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f010343b:	74 24                	je     f0103461 <mem_init+0x1fe4>
f010343d:	c7 44 24 0c 0f 6f 10 	movl   $0xf0106f0f,0xc(%esp)
f0103444:	f0 
f0103445:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010344c:	f0 
f010344d:	c7 44 24 04 7b 04 00 	movl   $0x47b,0x4(%esp)
f0103454:	00 
f0103455:	c7 04 24 b1 6c 10 f0 	movl   $0xf0106cb1,(%esp)
f010345c:	e8 df cb ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0103461:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0103467:	89 1c 24             	mov    %ebx,(%esp)
f010346a:	e8 08 dd ff ff       	call   f0101177 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f010346f:	c7 04 24 94 77 10 f0 	movl   $0xf0107794,(%esp)
f0103476:	e8 fe 0c 00 00       	call   f0104179 <cprintf>
f010347b:	e9 81 01 00 00       	jmp    f0103601 <mem_init+0x2184>

	}



	cprintf("%d\r\n",page_free_list->pp_ref);
f0103480:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0103485:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f0103489:	89 44 24 04          	mov    %eax,0x4(%esp)
f010348d:	c7 04 24 05 78 10 f0 	movl   $0xf0107805,(%esp)
f0103494:	e8 e0 0c 00 00       	call   f0104179 <cprintf>
	cprintf("1\r\n");
f0103499:	c7 04 24 23 70 10 f0 	movl   $0xf0107023,(%esp)
f01034a0:	e8 d4 0c 00 00       	call   f0104179 <cprintf>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f01034a5:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01034aa:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01034af:	0f 87 a4 f4 ff ff    	ja     f0102959 <mem_init+0x14dc>
f01034b5:	e9 c7 f4 ff ff       	jmp    f0102981 <mem_init+0x1504>
f01034ba:	b8 00 60 11 f0       	mov    $0xf0116000,%eax
f01034bf:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01034c4:	0f 86 6c f5 ff ff    	jbe    f0102a36 <mem_init+0x15b9>
f01034ca:	e9 3f f5 ff ff       	jmp    f0102a0e <mem_init+0x1591>
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
	}
	cprintf("%d\r\n",page_free_list->pp_ref);
f01034cf:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f01034d4:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f01034d8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01034dc:	c7 04 24 05 78 10 f0 	movl   $0xf0107805,(%esp)
f01034e3:	e8 91 0c 00 00       	call   f0104179 <cprintf>
	cprintf("2\r\n");
f01034e8:	c7 04 24 27 70 10 f0 	movl   $0xf0107027,(%esp)
f01034ef:	e8 85 0c 00 00       	call   f0104179 <cprintf>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f01034f4:	be 00 00 00 00       	mov    $0x0,%esi
f01034f9:	bb 00 00 00 00       	mov    $0x0,%ebx
f01034fe:	e9 ac f5 ff ff       	jmp    f0102aaf <mem_init+0x1632>
    	{
    		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
    		pa2page(0)->pp_ref--;
    	}
    }
    cprintf("%d\r\n",page_free_list->pp_ref);
f0103503:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0103508:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f010350c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103510:	c7 04 24 05 78 10 f0 	movl   $0xf0107805,(%esp)
f0103517:	e8 5d 0c 00 00       	call   f0104179 <cprintf>
    cprintf("3\r\n");
f010351c:	c7 04 24 2b 70 10 f0 	movl   $0xf010702b,(%esp)
f0103523:	e8 51 0c 00 00       	call   f0104179 <cprintf>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f0103528:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f010352d:	89 45 d4             	mov    %eax,-0x2c(%ebp)
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	cprintf("boot_map_region\r\n");
f0103530:	c7 04 24 2f 70 10 f0 	movl   $0xf010702f,(%esp)
f0103537:	e8 3d 0c 00 00       	call   f0104179 <cprintf>
f010353c:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0103541:	e9 91 f6 ff ff       	jmp    f0102bd7 <mem_init+0x175a>
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
f0103546:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f010354d:	00 
f010354e:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f0103555:	ef 
static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f0103556:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
f010355c:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f010355f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103563:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f0103568:	89 04 24             	mov    %eax,(%esp)
f010356b:	e8 4c de ff ff       	call   f01013bc <page_insert>
f0103570:	bb 00 70 11 00       	mov    $0x117000,%ebx
f0103575:	bf 00 e0 11 00       	mov    $0x11e000,%edi
f010357a:	be 00 80 bf df       	mov    $0xdfbf8000,%esi
f010357f:	81 ee 00 60 11 f0    	sub    $0xf0116000,%esi
f0103585:	e9 9a f4 ff ff       	jmp    f0102a24 <mem_init+0x15a7>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f010358a:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0103591:	00 
f0103592:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f0103599:	ee 
f010359a:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
f01035a0:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01035a3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01035a7:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
f01035ac:	89 04 24             	mov    %eax,(%esp)
f01035af:	e8 08 de ff ff       	call   f01013bc <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f01035b4:	bb 00 10 00 00       	mov    $0x1000,%ebx
f01035b9:	ba 00 10 00 00       	mov    $0x1000,%edx
f01035be:	e9 ac f3 ff ff       	jmp    f010296f <mem_init+0x14f2>
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f01035c3:	89 da                	mov    %ebx,%edx
f01035c5:	89 f8                	mov    %edi,%eax
f01035c7:	e8 80 d5 ff ff       	call   f0100b4c <check_va2pa>
f01035cc:	e9 f3 f8 ff ff       	jmp    f0102ec4 <mem_init+0x1a47>
	// check kernel stack
//<<<<<<< HEAD
	for (i = 0; i < KSTKSIZE; i += PGSIZE)
	{

		assert(check_va2pa(pgdir, KSTACKTOP - KSTKSIZE + i) == PADDR(bootstack) + i);
f01035d1:	89 da                	mov    %ebx,%edx
f01035d3:	89 f8                	mov    %edi,%eax
f01035d5:	e8 72 d5 ff ff       	call   f0100b4c <check_va2pa>
f01035da:	e9 13 f8 ff ff       	jmp    f0102df2 <mem_init+0x1975>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f01035df:	89 da                	mov    %ebx,%edx
f01035e1:	89 f8                	mov    %edi,%eax
f01035e3:	e8 64 d5 ff ff       	call   f0100b4c <check_va2pa>
f01035e8:	e9 16 f7 ff ff       	jmp    f0102d03 <mem_init+0x1886>
f01035ed:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01035f3:	89 f8                	mov    %edi,%eax
f01035f5:	e8 52 d5 ff ff       	call   f0100b4c <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01035fa:	89 da                	mov    %ebx,%edx
f01035fc:	e9 a3 f6 ff ff       	jmp    f0102ca4 <mem_init+0x1827>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103601:	83 c4 3c             	add    $0x3c,%esp
f0103604:	5b                   	pop    %ebx
f0103605:	5e                   	pop    %esi
f0103606:	5f                   	pop    %edi
f0103607:	5d                   	pop    %ebp
f0103608:	c3                   	ret    

f0103609 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103609:	55                   	push   %ebp
f010360a:	89 e5                	mov    %esp,%ebp
f010360c:	57                   	push   %edi
f010360d:	56                   	push   %esi
f010360e:	53                   	push   %ebx
f010360f:	83 ec 3c             	sub    $0x3c,%esp
f0103612:	8b 7d 08             	mov    0x8(%ebp),%edi
f0103615:	8b 45 0c             	mov    0xc(%ebp),%eax
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
f0103618:	89 c2                	mov    %eax,%edx
f010361a:	03 55 10             	add    0x10(%ebp),%edx
f010361d:	89 55 d0             	mov    %edx,-0x30(%ebp)
f0103620:	39 d0                	cmp    %edx,%eax
f0103622:	0f 83 88 00 00 00    	jae    f01036b0 <user_mem_check+0xa7>
f0103628:	89 c3                	mov    %eax,%ebx
f010362a:	89 c6                	mov    %eax,%esi
			pte_t* store=0;
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
			if(store!=NULL)
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f010362c:	8b 45 14             	mov    0x14(%ebp),%eax
f010362f:	83 c8 01             	or     $0x1,%eax
f0103632:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
		{
			pte_t* store=0;
f0103635:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f010363c:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f010363f:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103643:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103647:	8b 47 60             	mov    0x60(%edi),%eax
f010364a:	89 04 24             	mov    %eax,(%esp)
f010364d:	e8 6d dc ff ff       	call   f01012bf <page_lookup>
			if(store!=NULL)
f0103652:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103655:	85 c0                	test   %eax,%eax
f0103657:	74 27                	je     f0103680 <user_mem_check+0x77>
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103659:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f010365c:	89 ca                	mov    %ecx,%edx
f010365e:	23 10                	and    (%eax),%edx
f0103660:	39 d1                	cmp    %edx,%ecx
f0103662:	75 08                	jne    f010366c <user_mem_check+0x63>
f0103664:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f010366a:	76 28                	jbe    f0103694 <user_mem_check+0x8b>
			   {
				cprintf("pte protect!\r\n");
f010366c:	c7 04 24 41 70 10 f0 	movl   $0xf0107041,(%esp)
f0103673:	e8 01 0b 00 00       	call   f0104179 <cprintf>
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0103678:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f010367e:	eb 29                	jmp    f01036a9 <user_mem_check+0xa0>
			   }
			}
			else
			{
				cprintf("no pte!\r\n");
f0103680:	c7 04 24 50 70 10 f0 	movl   $0xf0107050,(%esp)
f0103687:	e8 ed 0a 00 00       	call   f0104179 <cprintf>
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f010368c:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f0103692:	eb 15                	jmp    f01036a9 <user_mem_check+0xa0>
			}
		      i=ROUNDDOWN(i,PGSIZE);
f0103694:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
f010369a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01036a0:	89 de                	mov    %ebx,%esi
f01036a2:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f01036a5:	72 8e                	jb     f0103635 <user_mem_check+0x2c>
f01036a7:	eb 0e                	jmp    f01036b7 <user_mem_check+0xae>
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f01036a9:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f01036ae:	eb 0c                	jmp    f01036bc <user_mem_check+0xb3>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
f01036b0:	b8 00 00 00 00       	mov    $0x0,%eax
f01036b5:	eb 05                	jmp    f01036bc <user_mem_check+0xb3>
f01036b7:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		      i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f01036bc:	83 c4 3c             	add    $0x3c,%esp
f01036bf:	5b                   	pop    %ebx
f01036c0:	5e                   	pop    %esi
f01036c1:	5f                   	pop    %edi
f01036c2:	5d                   	pop    %ebp
f01036c3:	c3                   	ret    

f01036c4 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f01036c4:	55                   	push   %ebp
f01036c5:	89 e5                	mov    %esp,%ebp
f01036c7:	53                   	push   %ebx
f01036c8:	83 ec 14             	sub    $0x14,%esp
f01036cb:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("user_mem_assert\r\n");
f01036ce:	c7 04 24 5a 70 10 f0 	movl   $0xf010705a,(%esp)
f01036d5:	e8 9f 0a 00 00       	call   f0104179 <cprintf>
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f01036da:	8b 45 14             	mov    0x14(%ebp),%eax
f01036dd:	83 c8 04             	or     $0x4,%eax
f01036e0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01036e4:	8b 45 10             	mov    0x10(%ebp),%eax
f01036e7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01036eb:	8b 45 0c             	mov    0xc(%ebp),%eax
f01036ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036f2:	89 1c 24             	mov    %ebx,(%esp)
f01036f5:	e8 0f ff ff ff       	call   f0103609 <user_mem_check>
f01036fa:	85 c0                	test   %eax,%eax
f01036fc:	79 24                	jns    f0103722 <user_mem_assert+0x5e>
		cprintf("[%08x] user_mem_check assertion failure for "
f01036fe:	a1 3c 32 22 f0       	mov    0xf022323c,%eax
f0103703:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103707:	8b 43 48             	mov    0x48(%ebx),%eax
f010370a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010370e:	c7 04 24 c0 77 10 f0 	movl   $0xf01077c0,(%esp)
f0103715:	e8 5f 0a 00 00       	call   f0104179 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f010371a:	89 1c 24             	mov    %ebx,(%esp)
f010371d:	e8 a7 07 00 00       	call   f0103ec9 <env_destroy>
	}
	cprintf("assert success!!\r\n");
f0103722:	c7 04 24 6c 70 10 f0 	movl   $0xf010706c,(%esp)
f0103729:	e8 4b 0a 00 00       	call   f0104179 <cprintf>
}
f010372e:	83 c4 14             	add    $0x14,%esp
f0103731:	5b                   	pop    %ebx
f0103732:	5d                   	pop    %ebp
f0103733:	c3                   	ret    

f0103734 <region_alloc>:
// Pages should be writable by user and kernel.
// Panic if any allocation attempt fails.
//
static void
region_alloc(struct Env *e, void *va, size_t len)
{
f0103734:	55                   	push   %ebp
f0103735:	89 e5                	mov    %esp,%ebp
f0103737:	57                   	push   %edi
f0103738:	56                   	push   %esi
f0103739:	53                   	push   %ebx
f010373a:	83 ec 1c             	sub    $0x1c,%esp
f010373d:	89 c6                	mov    %eax,%esi
f010373f:	89 d3                	mov    %edx,%ebx
f0103741:	89 cf                	mov    %ecx,%edi
	// Hint: It is easier to use region_alloc if the caller can pass
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
f0103743:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0103747:	8b 40 60             	mov    0x60(%eax),%eax
f010374a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010374e:	c7 04 24 f5 77 10 f0 	movl   $0xf01077f5,(%esp)
f0103755:	e8 1f 0a 00 00       	call   f0104179 <cprintf>
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f010375a:	89 d8                	mov    %ebx,%eax
f010375c:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0103762:	8d bc 38 ff 0f 00 00 	lea    0xfff(%eax,%edi,1),%edi
f0103769:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
f010376f:	39 fb                	cmp    %edi,%ebx
f0103771:	73 51                	jae    f01037c4 <region_alloc+0x90>
	{
		struct Page* p=(struct Page*)page_alloc(1);
f0103773:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010377a:	e8 73 d9 ff ff       	call   f01010f2 <page_alloc>
		if(p==NULL)
f010377f:	85 c0                	test   %eax,%eax
f0103781:	75 1c                	jne    f010379f <region_alloc+0x6b>
			panic("Memory out!");
f0103783:	c7 44 24 08 0a 78 10 	movl   $0xf010780a,0x8(%esp)
f010378a:	f0 
f010378b:	c7 44 24 04 2f 01 00 	movl   $0x12f,0x4(%esp)
f0103792:	00 
f0103793:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f010379a:	e8 a1 c8 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f010379f:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01037a6:	00 
f01037a7:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01037ab:	89 44 24 04          	mov    %eax,0x4(%esp)
f01037af:	8b 46 60             	mov    0x60(%esi),%eax
f01037b2:	89 04 24             	mov    %eax,(%esp)
f01037b5:	e8 02 dc ff ff       	call   f01013bc <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f01037ba:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01037c0:	39 fb                	cmp    %edi,%ebx
f01037c2:	72 af                	jb     f0103773 <region_alloc+0x3f>
		if(p==NULL)
			panic("Memory out!");
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
	}

}
f01037c4:	83 c4 1c             	add    $0x1c,%esp
f01037c7:	5b                   	pop    %ebx
f01037c8:	5e                   	pop    %esi
f01037c9:	5f                   	pop    %edi
f01037ca:	5d                   	pop    %ebp
f01037cb:	c3                   	ret    

f01037cc <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f01037cc:	55                   	push   %ebp
f01037cd:	89 e5                	mov    %esp,%ebp
f01037cf:	56                   	push   %esi
f01037d0:	53                   	push   %ebx
f01037d1:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f01037d4:	85 c0                	test   %eax,%eax
f01037d6:	75 1a                	jne    f01037f2 <envid2env+0x26>
		*env_store = curenv;
f01037d8:	e8 16 28 00 00       	call   f0105ff3 <cpunum>
f01037dd:	6b c0 74             	imul   $0x74,%eax,%eax
f01037e0:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01037e6:	8b 55 0c             	mov    0xc(%ebp),%edx
f01037e9:	89 02                	mov    %eax,(%edx)
		return 0;
f01037eb:	b8 00 00 00 00       	mov    $0x0,%eax
f01037f0:	eb 72                	jmp    f0103864 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f01037f2:	89 c3                	mov    %eax,%ebx
f01037f4:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f01037fa:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f01037fd:	03 1d 48 32 22 f0    	add    0xf0223248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f0103803:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f0103807:	74 05                	je     f010380e <envid2env+0x42>
f0103809:	39 43 48             	cmp    %eax,0x48(%ebx)
f010380c:	74 10                	je     f010381e <envid2env+0x52>
		*env_store = 0;
f010380e:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103811:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103817:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f010381c:	eb 46                	jmp    f0103864 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f010381e:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0103822:	74 36                	je     f010385a <envid2env+0x8e>
f0103824:	e8 ca 27 00 00       	call   f0105ff3 <cpunum>
f0103829:	6b c0 74             	imul   $0x74,%eax,%eax
f010382c:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103832:	74 26                	je     f010385a <envid2env+0x8e>
f0103834:	8b 73 4c             	mov    0x4c(%ebx),%esi
f0103837:	e8 b7 27 00 00       	call   f0105ff3 <cpunum>
f010383c:	6b c0 74             	imul   $0x74,%eax,%eax
f010383f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103845:	3b 70 48             	cmp    0x48(%eax),%esi
f0103848:	74 10                	je     f010385a <envid2env+0x8e>
		*env_store = 0;
f010384a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010384d:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103853:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103858:	eb 0a                	jmp    f0103864 <envid2env+0x98>
	}

	*env_store = e;
f010385a:	8b 45 0c             	mov    0xc(%ebp),%eax
f010385d:	89 18                	mov    %ebx,(%eax)
	return 0;
f010385f:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103864:	5b                   	pop    %ebx
f0103865:	5e                   	pop    %esi
f0103866:	5d                   	pop    %ebp
f0103867:	c3                   	ret    

f0103868 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0103868:	55                   	push   %ebp
f0103869:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f010386b:	b8 00 03 12 f0       	mov    $0xf0120300,%eax
f0103870:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f0103873:	b8 23 00 00 00       	mov    $0x23,%eax
f0103878:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f010387a:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f010387c:	b0 10                	mov    $0x10,%al
f010387e:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0103880:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f0103882:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0103884:	ea 8b 38 10 f0 08 00 	ljmp   $0x8,$0xf010388b
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f010388b:	b0 00                	mov    $0x0,%al
f010388d:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103890:	5d                   	pop    %ebp
f0103891:	c3                   	ret    

f0103892 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f0103892:	55                   	push   %ebp
f0103893:	89 e5                	mov    %esp,%ebp
f0103895:	57                   	push   %edi
f0103896:	56                   	push   %esi
f0103897:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
    {
    	envs[i].env_id=0;
f0103898:	8b 0d 48 32 22 f0    	mov    0xf0223248,%ecx
f010389e:	c7 41 48 00 00 00 00 	movl   $0x0,0x48(%ecx)
f01038a5:	89 cf                	mov    %ecx,%edi
f01038a7:	8d 51 7c             	lea    0x7c(%ecx),%edx
f01038aa:	89 ce                	mov    %ecx,%esi
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f01038ac:	b8 00 00 00 00       	mov    $0x0,%eax
    {
    	envs[i].env_id=0;
f01038b1:	bb 00 00 00 00       	mov    $0x0,%ebx
f01038b6:	eb 02                	jmp    f01038ba <env_init+0x28>
f01038b8:	89 f9                	mov    %edi,%ecx
    	if(i!=NENV-1)
    	{
    	envs[i].env_link=&envs[i+1];
f01038ba:	83 c3 01             	add    $0x1,%ebx
f01038bd:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f01038c0:	01 d9                	add    %ebx,%ecx
f01038c2:	89 4e 44             	mov    %ecx,0x44(%esi)
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f01038c5:	83 c0 01             	add    $0x1,%eax
    {
    	envs[i].env_id=0;
f01038c8:	89 c3                	mov    %eax,%ebx
f01038ca:	89 d6                	mov    %edx,%esi
f01038cc:	c7 42 48 00 00 00 00 	movl   $0x0,0x48(%edx)
f01038d3:	83 c2 7c             	add    $0x7c,%edx
    	if(i!=NENV-1)
f01038d6:	3d ff 03 00 00       	cmp    $0x3ff,%eax
f01038db:	75 db                	jne    f01038b8 <env_init+0x26>
    	{
    	envs[i].env_link=&envs[i+1];
    	}
    }
    env_free_list=envs;
f01038dd:	a1 48 32 22 f0       	mov    0xf0223248,%eax
f01038e2:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	// Per-CPU part of the initialization
	env_init_percpu();
f01038e7:	e8 7c ff ff ff       	call   f0103868 <env_init_percpu>
}
f01038ec:	5b                   	pop    %ebx
f01038ed:	5e                   	pop    %esi
f01038ee:	5f                   	pop    %edi
f01038ef:	5d                   	pop    %ebp
f01038f0:	c3                   	ret    

f01038f1 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01038f1:	55                   	push   %ebp
f01038f2:	89 e5                	mov    %esp,%ebp
f01038f4:	56                   	push   %esi
f01038f5:	53                   	push   %ebx
f01038f6:	83 ec 10             	sub    $0x10,%esp
	cprintf("env_alloc");
f01038f9:	c7 04 24 21 78 10 f0 	movl   $0xf0107821,(%esp)
f0103900:	e8 74 08 00 00       	call   f0104179 <cprintf>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f0103905:	8b 1d 4c 32 22 f0    	mov    0xf022324c,%ebx
f010390b:	85 db                	test   %ebx,%ebx
f010390d:	0f 84 9e 01 00 00    	je     f0103ab1 <env_alloc+0x1c0>
static int
env_setup_vm(struct Env *e)
{
	int i;
	struct Page *p = NULL;
	cprintf("env_setup_vm\r\n");
f0103913:	c7 04 24 2b 78 10 f0 	movl   $0xf010782b,(%esp)
f010391a:	e8 5a 08 00 00       	call   f0104179 <cprintf>
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f010391f:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103926:	e8 c7 d7 ff ff       	call   f01010f2 <page_alloc>
f010392b:	85 c0                	test   %eax,%eax
f010392d:	0f 84 85 01 00 00    	je     f0103ab8 <env_alloc+0x1c7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103933:	89 c2                	mov    %eax,%edx
f0103935:	2b 15 10 3f 22 f0    	sub    0xf0223f10,%edx
f010393b:	c1 fa 03             	sar    $0x3,%edx
f010393e:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103941:	89 d1                	mov    %edx,%ecx
f0103943:	c1 e9 0c             	shr    $0xc,%ecx
f0103946:	3b 0d 08 3f 22 f0    	cmp    0xf0223f08,%ecx
f010394c:	72 20                	jb     f010396e <env_alloc+0x7d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010394e:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0103952:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0103959:	f0 
f010395a:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103961:	00 
f0103962:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0103969:	e8 d2 c6 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010396e:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f0103974:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
f0103977:	ba ec 0e 00 00       	mov    $0xeec,%edx
    for(i=PDX(UTOP);i<1024;i++)
    {
    	e->env_pgdir[i]=kern_pgdir[i];
f010397c:	8b 0d 0c 3f 22 f0    	mov    0xf0223f0c,%ecx
f0103982:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f0103985:	8b 4b 60             	mov    0x60(%ebx),%ecx
f0103988:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f010398b:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
    for(i=PDX(UTOP);i<1024;i++)
f010398e:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f0103994:	75 e6                	jne    f010397c <env_alloc+0x8b>
    {
    	e->env_pgdir[i]=kern_pgdir[i];
    }
    p->pp_ref++;
f0103996:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f010399b:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010399e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01039a3:	77 20                	ja     f01039c5 <env_alloc+0xd4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01039a5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039a9:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f01039b0:	f0 
f01039b1:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
f01039b8:	00 
f01039b9:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f01039c0:	e8 7b c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01039c5:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01039cb:	83 ca 05             	or     $0x5,%edx
f01039ce:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f01039d4:	8b 43 48             	mov    0x48(%ebx),%eax
f01039d7:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f01039dc:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f01039e1:	ba 00 10 00 00       	mov    $0x1000,%edx
f01039e6:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f01039e9:	89 da                	mov    %ebx,%edx
f01039eb:	2b 15 48 32 22 f0    	sub    0xf0223248,%edx
f01039f1:	c1 fa 02             	sar    $0x2,%edx
f01039f4:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01039fa:	09 d0                	or     %edx,%eax
f01039fc:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01039ff:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103a02:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0103a05:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103a0c:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f0103a13:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103a1a:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0103a21:	00 
f0103a22:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103a29:	00 
f0103a2a:	89 1c 24             	mov    %ebx,(%esp)
f0103a2d:	e8 27 1f 00 00       	call   f0105959 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f0103a32:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f0103a38:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f0103a3e:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f0103a44:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f0103a4b:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f0103a51:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f0103a58:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f0103a5f:	8b 43 44             	mov    0x44(%ebx),%eax
f0103a62:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	*newenv_store = e;
f0103a67:	8b 45 08             	mov    0x8(%ebp),%eax
f0103a6a:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103a6c:	8b 5b 48             	mov    0x48(%ebx),%ebx
f0103a6f:	e8 7f 25 00 00       	call   f0105ff3 <cpunum>
f0103a74:	6b d0 74             	imul   $0x74,%eax,%edx
f0103a77:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a7c:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103a83:	74 11                	je     f0103a96 <env_alloc+0x1a5>
f0103a85:	e8 69 25 00 00       	call   f0105ff3 <cpunum>
f0103a8a:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a8d:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103a93:	8b 40 48             	mov    0x48(%eax),%eax
f0103a96:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103a9a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103a9e:	c7 04 24 3a 78 10 f0 	movl   $0xf010783a,(%esp)
f0103aa5:	e8 cf 06 00 00       	call   f0104179 <cprintf>
	return 0;
f0103aaa:	b8 00 00 00 00       	mov    $0x0,%eax
f0103aaf:	eb 0c                	jmp    f0103abd <env_alloc+0x1cc>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0103ab1:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0103ab6:	eb 05                	jmp    f0103abd <env_alloc+0x1cc>
	int i;
	struct Page *p = NULL;
	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0103ab8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f0103abd:	83 c4 10             	add    $0x10,%esp
f0103ac0:	5b                   	pop    %ebx
f0103ac1:	5e                   	pop    %esi
f0103ac2:	5d                   	pop    %ebp
f0103ac3:	c3                   	ret    

f0103ac4 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f0103ac4:	55                   	push   %ebp
f0103ac5:	89 e5                	mov    %esp,%ebp
f0103ac7:	57                   	push   %edi
f0103ac8:	56                   	push   %esi
f0103ac9:	53                   	push   %ebx
f0103aca:	83 ec 3c             	sub    $0x3c,%esp
f0103acd:	8b 75 08             	mov    0x8(%ebp),%esi
	// LAB 3: Your code here.

	struct Env* env;

	if(env_alloc(&env,0)==0)
f0103ad0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103ad7:	00 
f0103ad8:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103adb:	89 04 24             	mov    %eax,(%esp)
f0103ade:	e8 0e fe ff ff       	call   f01038f1 <env_alloc>
f0103ae3:	85 c0                	test   %eax,%eax
f0103ae5:	0f 85 d1 01 00 00    	jne    f0103cbc <env_create+0x1f8>
	{
		env->env_type=type;
f0103aeb:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103aee:	89 c7                	mov    %eax,%edi
f0103af0:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0103af3:	8b 45 10             	mov    0x10(%ebp),%eax
f0103af6:	89 47 50             	mov    %eax,0x50(%edi)
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f0103af9:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103afc:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103b01:	77 20                	ja     f0103b23 <env_create+0x5f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103b03:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b07:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0103b0e:	f0 
f0103b0f:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
f0103b16:	00 
f0103b17:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103b1e:	e8 1d c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103b23:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103b28:	0f 22 d8             	mov    %eax,%cr3
	cprintf("load_icode\r\n");
f0103b2b:	c7 04 24 4f 78 10 f0 	movl   $0xf010784f,(%esp)
f0103b32:	e8 42 06 00 00       	call   f0104179 <cprintf>
	struct Elf * ELFHDR=(struct Elf *)binary;
	struct Proghdr *ph, *eph;
	int i;
	if (ELFHDR->e_magic != ELF_MAGIC)
f0103b37:	81 3e 7f 45 4c 46    	cmpl   $0x464c457f,(%esi)
f0103b3d:	74 1c                	je     f0103b5b <env_create+0x97>
			panic("Not a elf binary");
f0103b3f:	c7 44 24 08 5c 78 10 	movl   $0xf010785c,0x8(%esp)
f0103b46:	f0 
f0103b47:	c7 44 24 04 71 01 00 	movl   $0x171,0x4(%esp)
f0103b4e:	00 
f0103b4f:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103b56:	e8 e5 c4 ff ff       	call   f0100040 <_panic>


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0103b5b:	89 f3                	mov    %esi,%ebx
f0103b5d:	03 5e 1c             	add    0x1c(%esi),%ebx
		eph = ph + ELFHDR->e_phnum;
f0103b60:	0f b7 46 2c          	movzwl 0x2c(%esi),%eax
f0103b64:	c1 e0 05             	shl    $0x5,%eax
f0103b67:	01 d8                	add    %ebx,%eax
f0103b69:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		for (; ph < eph; ph++)
f0103b6c:	39 c3                	cmp    %eax,%ebx
f0103b6e:	73 5e                	jae    f0103bce <env_create+0x10a>
		{
			// p_pa is the load address of this segment (as well
			// as the physical address)
			if(ph->p_type==ELF_PROG_LOAD)
f0103b70:	83 3b 01             	cmpl   $0x1,(%ebx)
f0103b73:	75 51                	jne    f0103bc6 <env_create+0x102>
			{
			cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
f0103b75:	8b 43 08             	mov    0x8(%ebx),%eax
f0103b78:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103b7c:	8b 43 10             	mov    0x10(%ebx),%eax
f0103b7f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103b83:	c7 04 24 6d 78 10 f0 	movl   $0xf010786d,(%esp)
f0103b8a:	e8 ea 05 00 00       	call   f0104179 <cprintf>
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
f0103b8f:	8b 4b 10             	mov    0x10(%ebx),%ecx
f0103b92:	8b 53 08             	mov    0x8(%ebx),%edx
f0103b95:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103b98:	e8 97 fb ff ff       	call   f0103734 <region_alloc>
			char* va=(char*)ph->p_va;
f0103b9d:	8b 7b 08             	mov    0x8(%ebx),%edi
			for(i=0;i<ph->p_filesz;i++)
f0103ba0:	83 7b 10 00          	cmpl   $0x0,0x10(%ebx)
f0103ba4:	74 20                	je     f0103bc6 <env_create+0x102>
f0103ba6:	b8 00 00 00 00       	mov    $0x0,%eax
f0103bab:	ba 00 00 00 00       	mov    $0x0,%edx
			{

				va[i]=binary[ph->p_offset+i];
f0103bb0:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
f0103bb3:	03 4b 04             	add    0x4(%ebx),%ecx
f0103bb6:	0f b6 09             	movzbl (%ecx),%ecx
f0103bb9:	88 0c 17             	mov    %cl,(%edi,%edx,1)
			if(ph->p_type==ELF_PROG_LOAD)
			{
			cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
			char* va=(char*)ph->p_va;
			for(i=0;i<ph->p_filesz;i++)
f0103bbc:	83 c0 01             	add    $0x1,%eax
f0103bbf:	89 c2                	mov    %eax,%edx
f0103bc1:	3b 43 10             	cmp    0x10(%ebx),%eax
f0103bc4:	72 ea                	jb     f0103bb0 <env_create+0xec>
			panic("Not a elf binary");


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
		eph = ph + ELFHDR->e_phnum;
		for (; ph < eph; ph++)
f0103bc6:	83 c3 20             	add    $0x20,%ebx
f0103bc9:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0103bcc:	77 a2                	ja     f0103b70 <env_create+0xac>
			}

			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
f0103bce:	89 f3                	mov    %esi,%ebx
f0103bd0:	03 5e 20             	add    0x20(%esi),%ebx
		eshdr= shdr + ELFHDR->e_shnum;
f0103bd3:	0f b7 46 30          	movzwl 0x30(%esi),%eax
f0103bd7:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0103bda:	8d 3c c3             	lea    (%ebx,%eax,8),%edi
				for (; shdr < eshdr; shdr++)
f0103bdd:	39 fb                	cmp    %edi,%ebx
f0103bdf:	73 44                	jae    f0103c25 <env_create+0x161>
				{
					// p_pa is the load address of this segment (as well
					// as the physical address)
					if(shdr->sh_type==8)
f0103be1:	83 7b 04 08          	cmpl   $0x8,0x4(%ebx)
f0103be5:	75 37                	jne    f0103c1e <env_create+0x15a>
					{
					cprintf("section %08x %08x %08x %08x\r\n",shdr->sh_size,shdr->sh_addr,shdr->sh_offset,shdr->sh_type);
f0103be7:	c7 44 24 10 08 00 00 	movl   $0x8,0x10(%esp)
f0103bee:	00 
f0103bef:	8b 43 10             	mov    0x10(%ebx),%eax
f0103bf2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103bf6:	8b 43 0c             	mov    0xc(%ebx),%eax
f0103bf9:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103bfd:	8b 43 14             	mov    0x14(%ebx),%eax
f0103c00:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c04:	c7 04 24 84 78 10 f0 	movl   $0xf0107884,(%esp)
f0103c0b:	e8 69 05 00 00       	call   f0104179 <cprintf>
					region_alloc(e,(void*)shdr->sh_addr,shdr->sh_size);
f0103c10:	8b 4b 14             	mov    0x14(%ebx),%ecx
f0103c13:	8b 53 0c             	mov    0xc(%ebx),%edx
f0103c16:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103c19:	e8 16 fb ff ff       	call   f0103734 <region_alloc>
			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
		eshdr= shdr + ELFHDR->e_shnum;
				for (; shdr < eshdr; shdr++)
f0103c1e:	83 c3 28             	add    $0x28,%ebx
f0103c21:	39 df                	cmp    %ebx,%edi
f0103c23:	77 bc                	ja     f0103be1 <env_create+0x11d>


					}
				}

		e->env_tf.tf_eip=ELFHDR->e_entry;
f0103c25:	8b 46 18             	mov    0x18(%esi),%eax
f0103c28:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0103c2b:	89 46 30             	mov    %eax,0x30(%esi)

	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
		struct Page* p=(struct Page*)page_alloc(1);
f0103c2e:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103c35:	e8 b8 d4 ff ff       	call   f01010f2 <page_alloc>
     if(p==NULL)
f0103c3a:	85 c0                	test   %eax,%eax
f0103c3c:	75 1c                	jne    f0103c5a <env_create+0x196>
    	 panic("Not enough mem for user stack!");
f0103c3e:	c7 44 24 08 e4 78 10 	movl   $0xf01078e4,0x8(%esp)
f0103c45:	f0 
f0103c46:	c7 44 24 04 9f 01 00 	movl   $0x19f,0x4(%esp)
f0103c4d:	00 
f0103c4e:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103c55:	e8 e6 c3 ff ff       	call   f0100040 <_panic>
     page_insert(e->env_pgdir,p,(void*)(USTACKTOP-PGSIZE),PTE_W|PTE_U);
f0103c5a:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103c61:	00 
f0103c62:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0103c69:	ee 
f0103c6a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c6e:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103c71:	8b 40 60             	mov    0x60(%eax),%eax
f0103c74:	89 04 24             	mov    %eax,(%esp)
f0103c77:	e8 40 d7 ff ff       	call   f01013bc <page_insert>
     cprintf("load_icode finish!\r\n");
f0103c7c:	c7 04 24 a2 78 10 f0 	movl   $0xf01078a2,(%esp)
f0103c83:	e8 f1 04 00 00       	call   f0104179 <cprintf>
     lcr3(PADDR(kern_pgdir));
f0103c88:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103c8d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103c92:	77 20                	ja     f0103cb4 <env_create+0x1f0>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103c94:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103c98:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0103c9f:	f0 
f0103ca0:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
f0103ca7:	00 
f0103ca8:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103caf:	e8 8c c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103cb4:	05 00 00 00 10       	add    $0x10000000,%eax
f0103cb9:	0f 22 d8             	mov    %eax,%cr3
	{
		env->env_type=type;
		load_icode(env, binary,size);
	}

}
f0103cbc:	83 c4 3c             	add    $0x3c,%esp
f0103cbf:	5b                   	pop    %ebx
f0103cc0:	5e                   	pop    %esi
f0103cc1:	5f                   	pop    %edi
f0103cc2:	5d                   	pop    %ebp
f0103cc3:	c3                   	ret    

f0103cc4 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103cc4:	55                   	push   %ebp
f0103cc5:	89 e5                	mov    %esp,%ebp
f0103cc7:	57                   	push   %edi
f0103cc8:	56                   	push   %esi
f0103cc9:	53                   	push   %ebx
f0103cca:	83 ec 2c             	sub    $0x2c,%esp
f0103ccd:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103cd0:	e8 1e 23 00 00       	call   f0105ff3 <cpunum>
f0103cd5:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cd8:	39 b8 28 40 22 f0    	cmp    %edi,-0xfddbfd8(%eax)
f0103cde:	75 34                	jne    f0103d14 <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0103ce0:	a1 0c 3f 22 f0       	mov    0xf0223f0c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103ce5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103cea:	77 20                	ja     f0103d0c <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103cec:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103cf0:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0103cf7:	f0 
f0103cf8:	c7 44 24 04 c9 01 00 	movl   $0x1c9,0x4(%esp)
f0103cff:	00 
f0103d00:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103d07:	e8 34 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103d0c:	05 00 00 00 10       	add    $0x10000000,%eax
f0103d11:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103d14:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103d17:	e8 d7 22 00 00       	call   f0105ff3 <cpunum>
f0103d1c:	6b d0 74             	imul   $0x74,%eax,%edx
f0103d1f:	b8 00 00 00 00       	mov    $0x0,%eax
f0103d24:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103d2b:	74 11                	je     f0103d3e <env_free+0x7a>
f0103d2d:	e8 c1 22 00 00       	call   f0105ff3 <cpunum>
f0103d32:	6b c0 74             	imul   $0x74,%eax,%eax
f0103d35:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103d3b:	8b 40 48             	mov    0x48(%eax),%eax
f0103d3e:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103d42:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d46:	c7 04 24 b7 78 10 f0 	movl   $0xf01078b7,(%esp)
f0103d4d:	e8 27 04 00 00       	call   f0104179 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103d52:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103d59:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103d5c:	89 c8                	mov    %ecx,%eax
f0103d5e:	c1 e0 02             	shl    $0x2,%eax
f0103d61:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103d64:	8b 47 60             	mov    0x60(%edi),%eax
f0103d67:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103d6a:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103d70:	0f 84 b7 00 00 00    	je     f0103e2d <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103d76:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103d7c:	89 f0                	mov    %esi,%eax
f0103d7e:	c1 e8 0c             	shr    $0xc,%eax
f0103d81:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103d84:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0103d8a:	72 20                	jb     f0103dac <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103d8c:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103d90:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0103d97:	f0 
f0103d98:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
f0103d9f:	00 
f0103da0:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103da7:	e8 94 c2 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103dac:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103daf:	c1 e0 16             	shl    $0x16,%eax
f0103db2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103db5:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103dba:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103dc1:	01 
f0103dc2:	74 17                	je     f0103ddb <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103dc4:	89 d8                	mov    %ebx,%eax
f0103dc6:	c1 e0 0c             	shl    $0xc,%eax
f0103dc9:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103dcc:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103dd0:	8b 47 60             	mov    0x60(%edi),%eax
f0103dd3:	89 04 24             	mov    %eax,(%esp)
f0103dd6:	e8 91 d5 ff ff       	call   f010136c <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103ddb:	83 c3 01             	add    $0x1,%ebx
f0103dde:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103de4:	75 d4                	jne    f0103dba <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103de6:	8b 47 60             	mov    0x60(%edi),%eax
f0103de9:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103dec:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103df3:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103df6:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0103dfc:	72 1c                	jb     f0103e1a <env_free+0x156>
		panic("pa2page called with invalid pa");
f0103dfe:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0103e05:	f0 
f0103e06:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103e0d:	00 
f0103e0e:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0103e15:	e8 26 c2 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103e1a:	a1 10 3f 22 f0       	mov    0xf0223f10,%eax
f0103e1f:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103e22:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103e25:	89 04 24             	mov    %eax,(%esp)
f0103e28:	e8 65 d3 ff ff       	call   f0101192 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103e2d:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103e31:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103e38:	0f 85 1b ff ff ff    	jne    f0103d59 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103e3e:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103e41:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103e46:	77 20                	ja     f0103e68 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103e48:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103e4c:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0103e53:	f0 
f0103e54:	c7 44 24 04 e6 01 00 	movl   $0x1e6,0x4(%esp)
f0103e5b:	00 
f0103e5c:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103e63:	e8 d8 c1 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103e68:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103e6f:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103e74:	c1 e8 0c             	shr    $0xc,%eax
f0103e77:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0103e7d:	72 1c                	jb     f0103e9b <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0103e7f:	c7 44 24 08 44 71 10 	movl   $0xf0107144,0x8(%esp)
f0103e86:	f0 
f0103e87:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103e8e:	00 
f0103e8f:	c7 04 24 d2 6c 10 f0 	movl   $0xf0106cd2,(%esp)
f0103e96:	e8 a5 c1 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103e9b:	8b 15 10 3f 22 f0    	mov    0xf0223f10,%edx
f0103ea1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103ea4:	89 04 24             	mov    %eax,(%esp)
f0103ea7:	e8 e6 d2 ff ff       	call   f0101192 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103eac:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103eb3:	a1 4c 32 22 f0       	mov    0xf022324c,%eax
f0103eb8:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103ebb:	89 3d 4c 32 22 f0    	mov    %edi,0xf022324c
}
f0103ec1:	83 c4 2c             	add    $0x2c,%esp
f0103ec4:	5b                   	pop    %ebx
f0103ec5:	5e                   	pop    %esi
f0103ec6:	5f                   	pop    %edi
f0103ec7:	5d                   	pop    %ebp
f0103ec8:	c3                   	ret    

f0103ec9 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103ec9:	55                   	push   %ebp
f0103eca:	89 e5                	mov    %esp,%ebp
f0103ecc:	53                   	push   %ebx
f0103ecd:	83 ec 14             	sub    $0x14,%esp
f0103ed0:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103ed3:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103ed7:	75 19                	jne    f0103ef2 <env_destroy+0x29>
f0103ed9:	e8 15 21 00 00       	call   f0105ff3 <cpunum>
f0103ede:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ee1:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103ee7:	74 09                	je     f0103ef2 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103ee9:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103ef0:	eb 2f                	jmp    f0103f21 <env_destroy+0x58>
	}

	env_free(e);
f0103ef2:	89 1c 24             	mov    %ebx,(%esp)
f0103ef5:	e8 ca fd ff ff       	call   f0103cc4 <env_free>

	if (curenv == e) {
f0103efa:	e8 f4 20 00 00       	call   f0105ff3 <cpunum>
f0103eff:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f02:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103f08:	75 17                	jne    f0103f21 <env_destroy+0x58>
		curenv = NULL;
f0103f0a:	e8 e4 20 00 00       	call   f0105ff3 <cpunum>
f0103f0f:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f12:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f0103f19:	00 00 00 
		sched_yield();
f0103f1c:	e8 30 0b 00 00       	call   f0104a51 <sched_yield>
	}
}
f0103f21:	83 c4 14             	add    $0x14,%esp
f0103f24:	5b                   	pop    %ebx
f0103f25:	5d                   	pop    %ebp
f0103f26:	c3                   	ret    

f0103f27 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103f27:	55                   	push   %ebp
f0103f28:	89 e5                	mov    %esp,%ebp
f0103f2a:	53                   	push   %ebx
f0103f2b:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103f2e:	e8 c0 20 00 00       	call   f0105ff3 <cpunum>
f0103f33:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f36:	8b 98 28 40 22 f0    	mov    -0xfddbfd8(%eax),%ebx
f0103f3c:	e8 b2 20 00 00       	call   f0105ff3 <cpunum>
f0103f41:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103f44:	8b 65 08             	mov    0x8(%ebp),%esp
f0103f47:	61                   	popa   
f0103f48:	07                   	pop    %es
f0103f49:	1f                   	pop    %ds
f0103f4a:	83 c4 08             	add    $0x8,%esp
f0103f4d:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103f4e:	c7 44 24 08 cd 78 10 	movl   $0xf01078cd,0x8(%esp)
f0103f55:	f0 
f0103f56:	c7 44 24 04 1c 02 00 	movl   $0x21c,0x4(%esp)
f0103f5d:	00 
f0103f5e:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103f65:	e8 d6 c0 ff ff       	call   f0100040 <_panic>

f0103f6a <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103f6a:	55                   	push   %ebp
f0103f6b:	89 e5                	mov    %esp,%ebp
f0103f6d:	53                   	push   %ebx
f0103f6e:	83 ec 14             	sub    $0x14,%esp
f0103f71:	8b 5d 08             	mov    0x8(%ebp),%ebx
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.
	cprintf("Run env!\r\n");
f0103f74:	c7 04 24 d9 78 10 f0 	movl   $0xf01078d9,(%esp)
f0103f7b:	e8 f9 01 00 00       	call   f0104179 <cprintf>
    if(curenv!=NULL)
f0103f80:	e8 6e 20 00 00       	call   f0105ff3 <cpunum>
f0103f85:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f88:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0103f8f:	74 29                	je     f0103fba <env_run+0x50>
    {
    	if(curenv->env_status==ENV_RUNNING)
f0103f91:	e8 5d 20 00 00       	call   f0105ff3 <cpunum>
f0103f96:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f99:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103f9f:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103fa3:	75 15                	jne    f0103fba <env_run+0x50>
    	{
    		curenv->env_status=ENV_RUNNABLE;
f0103fa5:	e8 49 20 00 00       	call   f0105ff3 <cpunum>
f0103faa:	6b c0 74             	imul   $0x74,%eax,%eax
f0103fad:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103fb3:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
    	}
    }
    curenv=e;
f0103fba:	e8 34 20 00 00       	call   f0105ff3 <cpunum>
f0103fbf:	6b c0 74             	imul   $0x74,%eax,%eax
f0103fc2:	89 98 28 40 22 f0    	mov    %ebx,-0xfddbfd8(%eax)
    e->env_status=ENV_RUNNING;
f0103fc8:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
    e->env_runs++;
f0103fcf:	83 43 58 01          	addl   $0x1,0x58(%ebx)
    lcr3(PADDR(e->env_pgdir));
f0103fd3:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103fd6:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103fdb:	77 20                	ja     f0103ffd <env_run+0x93>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103fdd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103fe1:	c7 44 24 08 48 67 10 	movl   $0xf0106748,0x8(%esp)
f0103fe8:	f0 
f0103fe9:	c7 44 24 04 45 02 00 	movl   $0x245,0x4(%esp)
f0103ff0:	00 
f0103ff1:	c7 04 24 16 78 10 f0 	movl   $0xf0107816,(%esp)
f0103ff8:	e8 43 c0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103ffd:	05 00 00 00 10       	add    $0x10000000,%eax
f0104002:	0f 22 d8             	mov    %eax,%cr3
    env_pop_tf(&e->env_tf);
f0104005:	89 1c 24             	mov    %ebx,(%esp)
f0104008:	e8 1a ff ff ff       	call   f0103f27 <env_pop_tf>

f010400d <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f010400d:	55                   	push   %ebp
f010400e:	89 e5                	mov    %esp,%ebp
f0104010:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0104014:	ba 70 00 00 00       	mov    $0x70,%edx
f0104019:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010401a:	b2 71                	mov    $0x71,%dl
f010401c:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f010401d:	0f b6 c0             	movzbl %al,%eax
}
f0104020:	5d                   	pop    %ebp
f0104021:	c3                   	ret    

f0104022 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0104022:	55                   	push   %ebp
f0104023:	89 e5                	mov    %esp,%ebp
f0104025:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0104029:	ba 70 00 00 00       	mov    $0x70,%edx
f010402e:	ee                   	out    %al,(%dx)
f010402f:	b2 71                	mov    $0x71,%dl
f0104031:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104034:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0104035:	5d                   	pop    %ebp
f0104036:	c3                   	ret    

f0104037 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0104037:	55                   	push   %ebp
f0104038:	89 e5                	mov    %esp,%ebp
f010403a:	56                   	push   %esi
f010403b:	53                   	push   %ebx
f010403c:	83 ec 10             	sub    $0x10,%esp
f010403f:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0104042:	66 a3 88 03 12 f0    	mov    %ax,0xf0120388
	if (!didinit)
f0104048:	83 3d 50 32 22 f0 00 	cmpl   $0x0,0xf0223250
f010404f:	74 4e                	je     f010409f <irq_setmask_8259A+0x68>
f0104051:	89 c6                	mov    %eax,%esi
f0104053:	ba 21 00 00 00       	mov    $0x21,%edx
f0104058:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0104059:	66 c1 e8 08          	shr    $0x8,%ax
f010405d:	b2 a1                	mov    $0xa1,%dl
f010405f:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0104060:	c7 04 24 03 79 10 f0 	movl   $0xf0107903,(%esp)
f0104067:	e8 0d 01 00 00       	call   f0104179 <cprintf>
	for (i = 0; i < 16; i++)
f010406c:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0104071:	0f b7 f6             	movzwl %si,%esi
f0104074:	f7 d6                	not    %esi
f0104076:	0f a3 de             	bt     %ebx,%esi
f0104079:	73 10                	jae    f010408b <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f010407b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010407f:	c7 04 24 b9 7d 10 f0 	movl   $0xf0107db9,(%esp)
f0104086:	e8 ee 00 00 00       	call   f0104179 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f010408b:	83 c3 01             	add    $0x1,%ebx
f010408e:	83 fb 10             	cmp    $0x10,%ebx
f0104091:	75 e3                	jne    f0104076 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0104093:	c7 04 24 bb 6d 10 f0 	movl   $0xf0106dbb,(%esp)
f010409a:	e8 da 00 00 00       	call   f0104179 <cprintf>
}
f010409f:	83 c4 10             	add    $0x10,%esp
f01040a2:	5b                   	pop    %ebx
f01040a3:	5e                   	pop    %esi
f01040a4:	5d                   	pop    %ebp
f01040a5:	c3                   	ret    

f01040a6 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f01040a6:	c7 05 50 32 22 f0 01 	movl   $0x1,0xf0223250
f01040ad:	00 00 00 
f01040b0:	ba 21 00 00 00       	mov    $0x21,%edx
f01040b5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01040ba:	ee                   	out    %al,(%dx)
f01040bb:	b2 a1                	mov    $0xa1,%dl
f01040bd:	ee                   	out    %al,(%dx)
f01040be:	b2 20                	mov    $0x20,%dl
f01040c0:	b8 11 00 00 00       	mov    $0x11,%eax
f01040c5:	ee                   	out    %al,(%dx)
f01040c6:	b2 21                	mov    $0x21,%dl
f01040c8:	b8 20 00 00 00       	mov    $0x20,%eax
f01040cd:	ee                   	out    %al,(%dx)
f01040ce:	b8 04 00 00 00       	mov    $0x4,%eax
f01040d3:	ee                   	out    %al,(%dx)
f01040d4:	b8 03 00 00 00       	mov    $0x3,%eax
f01040d9:	ee                   	out    %al,(%dx)
f01040da:	b2 a0                	mov    $0xa0,%dl
f01040dc:	b8 11 00 00 00       	mov    $0x11,%eax
f01040e1:	ee                   	out    %al,(%dx)
f01040e2:	b2 a1                	mov    $0xa1,%dl
f01040e4:	b8 28 00 00 00       	mov    $0x28,%eax
f01040e9:	ee                   	out    %al,(%dx)
f01040ea:	b8 02 00 00 00       	mov    $0x2,%eax
f01040ef:	ee                   	out    %al,(%dx)
f01040f0:	b8 01 00 00 00       	mov    $0x1,%eax
f01040f5:	ee                   	out    %al,(%dx)
f01040f6:	b2 20                	mov    $0x20,%dl
f01040f8:	b8 68 00 00 00       	mov    $0x68,%eax
f01040fd:	ee                   	out    %al,(%dx)
f01040fe:	b8 0a 00 00 00       	mov    $0xa,%eax
f0104103:	ee                   	out    %al,(%dx)
f0104104:	b2 a0                	mov    $0xa0,%dl
f0104106:	b8 68 00 00 00       	mov    $0x68,%eax
f010410b:	ee                   	out    %al,(%dx)
f010410c:	b8 0a 00 00 00       	mov    $0xa,%eax
f0104111:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0104112:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f0104119:	66 83 f8 ff          	cmp    $0xffff,%ax
f010411d:	74 12                	je     f0104131 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f010411f:	55                   	push   %ebp
f0104120:	89 e5                	mov    %esp,%ebp
f0104122:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0104125:	0f b7 c0             	movzwl %ax,%eax
f0104128:	89 04 24             	mov    %eax,(%esp)
f010412b:	e8 07 ff ff ff       	call   f0104037 <irq_setmask_8259A>
}
f0104130:	c9                   	leave  
f0104131:	f3 c3                	repz ret 

f0104133 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0104133:	55                   	push   %ebp
f0104134:	89 e5                	mov    %esp,%ebp
f0104136:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0104139:	8b 45 08             	mov    0x8(%ebp),%eax
f010413c:	89 04 24             	mov    %eax,(%esp)
f010413f:	e8 a9 c6 ff ff       	call   f01007ed <cputchar>
	*cnt++;
}
f0104144:	c9                   	leave  
f0104145:	c3                   	ret    

f0104146 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0104146:	55                   	push   %ebp
f0104147:	89 e5                	mov    %esp,%ebp
f0104149:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f010414c:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0104153:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104156:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010415a:	8b 45 08             	mov    0x8(%ebp),%eax
f010415d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104161:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0104164:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104168:	c7 04 24 33 41 10 f0 	movl   $0xf0104133,(%esp)
f010416f:	e8 e6 0f 00 00       	call   f010515a <vprintfmt>
	return cnt;
}
f0104174:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104177:	c9                   	leave  
f0104178:	c3                   	ret    

f0104179 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0104179:	55                   	push   %ebp
f010417a:	89 e5                	mov    %esp,%ebp
f010417c:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f010417f:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0104182:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104186:	8b 45 08             	mov    0x8(%ebp),%eax
f0104189:	89 04 24             	mov    %eax,(%esp)
f010418c:	e8 b5 ff ff ff       	call   f0104146 <vcprintf>
	va_end(ap);

	return cnt;
}
f0104191:	c9                   	leave  
f0104192:	c3                   	ret    
f0104193:	66 90                	xchg   %ax,%ax
f0104195:	66 90                	xchg   %ax,%ax
f0104197:	66 90                	xchg   %ax,%ax
f0104199:	66 90                	xchg   %ax,%ax
f010419b:	66 90                	xchg   %ax,%ax
f010419d:	66 90                	xchg   %ax,%ax
f010419f:	90                   	nop

f01041a0 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f01041a0:	55                   	push   %ebp
f01041a1:	89 e5                	mov    %esp,%ebp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	ts.ts_esp0 = KSTACKTOP;
f01041a3:	c7 05 84 3a 22 f0 00 	movl   $0xefc00000,0xf0223a84
f01041aa:	00 c0 ef 
	ts.ts_ss0 = GD_KD;
f01041ad:	66 c7 05 88 3a 22 f0 	movw   $0x10,0xf0223a88
f01041b4:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[GD_TSS0 >> 3] = SEG16(STS_T32A, (uint32_t) (&ts),
f01041b6:	66 c7 05 48 03 12 f0 	movw   $0x68,0xf0120348
f01041bd:	68 00 
f01041bf:	b8 80 3a 22 f0       	mov    $0xf0223a80,%eax
f01041c4:	66 a3 4a 03 12 f0    	mov    %ax,0xf012034a
f01041ca:	89 c2                	mov    %eax,%edx
f01041cc:	c1 ea 10             	shr    $0x10,%edx
f01041cf:	88 15 4c 03 12 f0    	mov    %dl,0xf012034c
f01041d5:	c6 05 4e 03 12 f0 40 	movb   $0x40,0xf012034e
f01041dc:	c1 e8 18             	shr    $0x18,%eax
f01041df:	a2 4f 03 12 f0       	mov    %al,0xf012034f
					sizeof(struct Taskstate), 0);
	gdt[GD_TSS0 >> 3].sd_s = 0;
f01041e4:	c6 05 4d 03 12 f0 89 	movb   $0x89,0xf012034d
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f01041eb:	b8 28 00 00 00       	mov    $0x28,%eax
f01041f0:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f01041f3:	b8 8a 03 12 f0       	mov    $0xf012038a,%eax
f01041f8:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f01041fb:	5d                   	pop    %ebp
f01041fc:	c3                   	ret    

f01041fd <trap_init>:
}


void
trap_init(void)
{
f01041fd:	55                   	push   %ebp
f01041fe:	89 e5                	mov    %esp,%ebp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0104200:	b8 da 49 10 f0       	mov    $0xf01049da,%eax
f0104205:	66 a3 60 32 22 f0    	mov    %ax,0xf0223260
f010420b:	66 c7 05 62 32 22 f0 	movw   $0x8,0xf0223262
f0104212:	08 00 
f0104214:	c6 05 64 32 22 f0 00 	movb   $0x0,0xf0223264
f010421b:	c6 05 65 32 22 f0 8f 	movb   $0x8f,0xf0223265
f0104222:	c1 e8 10             	shr    $0x10,%eax
f0104225:	66 a3 66 32 22 f0    	mov    %ax,0xf0223266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f010422b:	b8 e0 49 10 f0       	mov    $0xf01049e0,%eax
f0104230:	66 a3 70 32 22 f0    	mov    %ax,0xf0223270
f0104236:	66 c7 05 72 32 22 f0 	movw   $0x8,0xf0223272
f010423d:	08 00 
f010423f:	c6 05 74 32 22 f0 00 	movb   $0x0,0xf0223274
f0104246:	c6 05 75 32 22 f0 8e 	movb   $0x8e,0xf0223275
f010424d:	c1 e8 10             	shr    $0x10,%eax
f0104250:	66 a3 76 32 22 f0    	mov    %ax,0xf0223276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0104256:	b8 e6 49 10 f0       	mov    $0xf01049e6,%eax
f010425b:	66 a3 78 32 22 f0    	mov    %ax,0xf0223278
f0104261:	66 c7 05 7a 32 22 f0 	movw   $0x8,0xf022327a
f0104268:	08 00 
f010426a:	c6 05 7c 32 22 f0 00 	movb   $0x0,0xf022327c
f0104271:	c6 05 7d 32 22 f0 ef 	movb   $0xef,0xf022327d
f0104278:	c1 e8 10             	shr    $0x10,%eax
f010427b:	66 a3 7e 32 22 f0    	mov    %ax,0xf022327e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0104281:	b8 ec 49 10 f0       	mov    $0xf01049ec,%eax
f0104286:	66 a3 80 32 22 f0    	mov    %ax,0xf0223280
f010428c:	66 c7 05 82 32 22 f0 	movw   $0x8,0xf0223282
f0104293:	08 00 
f0104295:	c6 05 84 32 22 f0 00 	movb   $0x0,0xf0223284
f010429c:	c6 05 85 32 22 f0 ef 	movb   $0xef,0xf0223285
f01042a3:	c1 e8 10             	shr    $0x10,%eax
f01042a6:	66 a3 86 32 22 f0    	mov    %ax,0xf0223286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f01042ac:	b8 f2 49 10 f0       	mov    $0xf01049f2,%eax
f01042b1:	66 a3 88 32 22 f0    	mov    %ax,0xf0223288
f01042b7:	66 c7 05 8a 32 22 f0 	movw   $0x8,0xf022328a
f01042be:	08 00 
f01042c0:	c6 05 8c 32 22 f0 00 	movb   $0x0,0xf022328c
f01042c7:	c6 05 8d 32 22 f0 ef 	movb   $0xef,0xf022328d
f01042ce:	c1 e8 10             	shr    $0x10,%eax
f01042d1:	66 a3 8e 32 22 f0    	mov    %ax,0xf022328e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f01042d7:	b8 f8 49 10 f0       	mov    $0xf01049f8,%eax
f01042dc:	66 a3 90 32 22 f0    	mov    %ax,0xf0223290
f01042e2:	66 c7 05 92 32 22 f0 	movw   $0x8,0xf0223292
f01042e9:	08 00 
f01042eb:	c6 05 94 32 22 f0 00 	movb   $0x0,0xf0223294
f01042f2:	c6 05 95 32 22 f0 8f 	movb   $0x8f,0xf0223295
f01042f9:	c1 e8 10             	shr    $0x10,%eax
f01042fc:	66 a3 96 32 22 f0    	mov    %ax,0xf0223296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104302:	b8 fe 49 10 f0       	mov    $0xf01049fe,%eax
f0104307:	66 a3 98 32 22 f0    	mov    %ax,0xf0223298
f010430d:	66 c7 05 9a 32 22 f0 	movw   $0x8,0xf022329a
f0104314:	08 00 
f0104316:	c6 05 9c 32 22 f0 00 	movb   $0x0,0xf022329c
f010431d:	c6 05 9d 32 22 f0 8f 	movb   $0x8f,0xf022329d
f0104324:	c1 e8 10             	shr    $0x10,%eax
f0104327:	66 a3 9e 32 22 f0    	mov    %ax,0xf022329e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010432d:	b8 04 4a 10 f0       	mov    $0xf0104a04,%eax
f0104332:	66 a3 a0 32 22 f0    	mov    %ax,0xf02232a0
f0104338:	66 c7 05 a2 32 22 f0 	movw   $0x8,0xf02232a2
f010433f:	08 00 
f0104341:	c6 05 a4 32 22 f0 00 	movb   $0x0,0xf02232a4
f0104348:	c6 05 a5 32 22 f0 8f 	movb   $0x8f,0xf02232a5
f010434f:	c1 e8 10             	shr    $0x10,%eax
f0104352:	66 a3 a6 32 22 f0    	mov    %ax,0xf02232a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104358:	b8 08 4a 10 f0       	mov    $0xf0104a08,%eax
f010435d:	66 a3 b0 32 22 f0    	mov    %ax,0xf02232b0
f0104363:	66 c7 05 b2 32 22 f0 	movw   $0x8,0xf02232b2
f010436a:	08 00 
f010436c:	c6 05 b4 32 22 f0 00 	movb   $0x0,0xf02232b4
f0104373:	c6 05 b5 32 22 f0 8f 	movb   $0x8f,0xf02232b5
f010437a:	c1 e8 10             	shr    $0x10,%eax
f010437d:	66 a3 b6 32 22 f0    	mov    %ax,0xf02232b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0104383:	b8 0c 4a 10 f0       	mov    $0xf0104a0c,%eax
f0104388:	66 a3 b8 32 22 f0    	mov    %ax,0xf02232b8
f010438e:	66 c7 05 ba 32 22 f0 	movw   $0x8,0xf02232ba
f0104395:	08 00 
f0104397:	c6 05 bc 32 22 f0 00 	movb   $0x0,0xf02232bc
f010439e:	c6 05 bd 32 22 f0 8f 	movb   $0x8f,0xf02232bd
f01043a5:	c1 e8 10             	shr    $0x10,%eax
f01043a8:	66 a3 be 32 22 f0    	mov    %ax,0xf02232be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01043ae:	b8 10 4a 10 f0       	mov    $0xf0104a10,%eax
f01043b3:	66 a3 c0 32 22 f0    	mov    %ax,0xf02232c0
f01043b9:	66 c7 05 c2 32 22 f0 	movw   $0x8,0xf02232c2
f01043c0:	08 00 
f01043c2:	c6 05 c4 32 22 f0 00 	movb   $0x0,0xf02232c4
f01043c9:	c6 05 c5 32 22 f0 8f 	movb   $0x8f,0xf02232c5
f01043d0:	c1 e8 10             	shr    $0x10,%eax
f01043d3:	66 a3 c6 32 22 f0    	mov    %ax,0xf02232c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01043d9:	b8 18 4a 10 f0       	mov    $0xf0104a18,%eax
f01043de:	66 a3 d0 32 22 f0    	mov    %ax,0xf02232d0
f01043e4:	66 c7 05 d2 32 22 f0 	movw   $0x8,0xf02232d2
f01043eb:	08 00 
f01043ed:	c6 05 d4 32 22 f0 00 	movb   $0x0,0xf02232d4
f01043f4:	c6 05 d5 32 22 f0 8f 	movb   $0x8f,0xf02232d5
f01043fb:	c1 e8 10             	shr    $0x10,%eax
f01043fe:	66 a3 d6 32 22 f0    	mov    %ax,0xf02232d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104404:	b8 14 4a 10 f0       	mov    $0xf0104a14,%eax
f0104409:	66 a3 c8 32 22 f0    	mov    %ax,0xf02232c8
f010440f:	66 c7 05 ca 32 22 f0 	movw   $0x8,0xf02232ca
f0104416:	08 00 
f0104418:	c6 05 cc 32 22 f0 00 	movb   $0x0,0xf02232cc
f010441f:	c6 05 cd 32 22 f0 8f 	movb   $0x8f,0xf02232cd
f0104426:	c1 e8 10             	shr    $0x10,%eax
f0104429:	66 a3 ce 32 22 f0    	mov    %ax,0xf02232ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010442f:	b8 1c 4a 10 f0       	mov    $0xf0104a1c,%eax
f0104434:	66 a3 e0 32 22 f0    	mov    %ax,0xf02232e0
f010443a:	66 c7 05 e2 32 22 f0 	movw   $0x8,0xf02232e2
f0104441:	08 00 
f0104443:	c6 05 e4 32 22 f0 00 	movb   $0x0,0xf02232e4
f010444a:	c6 05 e5 32 22 f0 8f 	movb   $0x8f,0xf02232e5
f0104451:	c1 e8 10             	shr    $0x10,%eax
f0104454:	66 a3 e6 32 22 f0    	mov    %ax,0xf02232e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f010445a:	b8 22 4a 10 f0       	mov    $0xf0104a22,%eax
f010445f:	66 a3 e8 32 22 f0    	mov    %ax,0xf02232e8
f0104465:	66 c7 05 ea 32 22 f0 	movw   $0x8,0xf02232ea
f010446c:	08 00 
f010446e:	c6 05 ec 32 22 f0 00 	movb   $0x0,0xf02232ec
f0104475:	c6 05 ed 32 22 f0 8f 	movb   $0x8f,0xf02232ed
f010447c:	c1 e8 10             	shr    $0x10,%eax
f010447f:	66 a3 ee 32 22 f0    	mov    %ax,0xf02232ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0104485:	b8 26 4a 10 f0       	mov    $0xf0104a26,%eax
f010448a:	66 a3 f0 32 22 f0    	mov    %ax,0xf02232f0
f0104490:	66 c7 05 f2 32 22 f0 	movw   $0x8,0xf02232f2
f0104497:	08 00 
f0104499:	c6 05 f4 32 22 f0 00 	movb   $0x0,0xf02232f4
f01044a0:	c6 05 f5 32 22 f0 8f 	movb   $0x8f,0xf02232f5
f01044a7:	c1 e8 10             	shr    $0x10,%eax
f01044aa:	66 a3 f6 32 22 f0    	mov    %ax,0xf02232f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01044b0:	b8 2c 4a 10 f0       	mov    $0xf0104a2c,%eax
f01044b5:	66 a3 f8 32 22 f0    	mov    %ax,0xf02232f8
f01044bb:	66 c7 05 fa 32 22 f0 	movw   $0x8,0xf02232fa
f01044c2:	08 00 
f01044c4:	c6 05 fc 32 22 f0 00 	movb   $0x0,0xf02232fc
f01044cb:	c6 05 fd 32 22 f0 8f 	movb   $0x8f,0xf02232fd
f01044d2:	c1 e8 10             	shr    $0x10,%eax
f01044d5:	66 a3 fe 32 22 f0    	mov    %ax,0xf02232fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01044db:	b8 32 4a 10 f0       	mov    $0xf0104a32,%eax
f01044e0:	66 a3 e0 33 22 f0    	mov    %ax,0xf02233e0
f01044e6:	66 c7 05 e2 33 22 f0 	movw   $0x8,0xf02233e2
f01044ed:	08 00 
f01044ef:	c6 05 e4 33 22 f0 00 	movb   $0x0,0xf02233e4
f01044f6:	c6 05 e5 33 22 f0 ee 	movb   $0xee,0xf02233e5
f01044fd:	c1 e8 10             	shr    $0x10,%eax
f0104500:	66 a3 e6 33 22 f0    	mov    %ax,0xf02233e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0104506:	e8 95 fc ff ff       	call   f01041a0 <trap_init_percpu>
}
f010450b:	5d                   	pop    %ebp
f010450c:	c3                   	ret    

f010450d <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010450d:	55                   	push   %ebp
f010450e:	89 e5                	mov    %esp,%ebp
f0104510:	53                   	push   %ebx
f0104511:	83 ec 14             	sub    $0x14,%esp
f0104514:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0104517:	8b 03                	mov    (%ebx),%eax
f0104519:	89 44 24 04          	mov    %eax,0x4(%esp)
f010451d:	c7 04 24 17 79 10 f0 	movl   $0xf0107917,(%esp)
f0104524:	e8 50 fc ff ff       	call   f0104179 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0104529:	8b 43 04             	mov    0x4(%ebx),%eax
f010452c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104530:	c7 04 24 26 79 10 f0 	movl   $0xf0107926,(%esp)
f0104537:	e8 3d fc ff ff       	call   f0104179 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010453c:	8b 43 08             	mov    0x8(%ebx),%eax
f010453f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104543:	c7 04 24 35 79 10 f0 	movl   $0xf0107935,(%esp)
f010454a:	e8 2a fc ff ff       	call   f0104179 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010454f:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104552:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104556:	c7 04 24 44 79 10 f0 	movl   $0xf0107944,(%esp)
f010455d:	e8 17 fc ff ff       	call   f0104179 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104562:	8b 43 10             	mov    0x10(%ebx),%eax
f0104565:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104569:	c7 04 24 53 79 10 f0 	movl   $0xf0107953,(%esp)
f0104570:	e8 04 fc ff ff       	call   f0104179 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104575:	8b 43 14             	mov    0x14(%ebx),%eax
f0104578:	89 44 24 04          	mov    %eax,0x4(%esp)
f010457c:	c7 04 24 62 79 10 f0 	movl   $0xf0107962,(%esp)
f0104583:	e8 f1 fb ff ff       	call   f0104179 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104588:	8b 43 18             	mov    0x18(%ebx),%eax
f010458b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010458f:	c7 04 24 71 79 10 f0 	movl   $0xf0107971,(%esp)
f0104596:	e8 de fb ff ff       	call   f0104179 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010459b:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010459e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045a2:	c7 04 24 80 79 10 f0 	movl   $0xf0107980,(%esp)
f01045a9:	e8 cb fb ff ff       	call   f0104179 <cprintf>
}
f01045ae:	83 c4 14             	add    $0x14,%esp
f01045b1:	5b                   	pop    %ebx
f01045b2:	5d                   	pop    %ebp
f01045b3:	c3                   	ret    

f01045b4 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f01045b4:	55                   	push   %ebp
f01045b5:	89 e5                	mov    %esp,%ebp
f01045b7:	56                   	push   %esi
f01045b8:	53                   	push   %ebx
f01045b9:	83 ec 10             	sub    $0x10,%esp
f01045bc:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f01045bf:	e8 2f 1a 00 00       	call   f0105ff3 <cpunum>
f01045c4:	89 44 24 08          	mov    %eax,0x8(%esp)
f01045c8:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01045cc:	c7 04 24 e4 79 10 f0 	movl   $0xf01079e4,(%esp)
f01045d3:	e8 a1 fb ff ff       	call   f0104179 <cprintf>
	print_regs(&tf->tf_regs);
f01045d8:	89 1c 24             	mov    %ebx,(%esp)
f01045db:	e8 2d ff ff ff       	call   f010450d <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01045e0:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01045e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045e8:	c7 04 24 02 7a 10 f0 	movl   $0xf0107a02,(%esp)
f01045ef:	e8 85 fb ff ff       	call   f0104179 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01045f4:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01045f8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045fc:	c7 04 24 15 7a 10 f0 	movl   $0xf0107a15,(%esp)
f0104603:	e8 71 fb ff ff       	call   f0104179 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104608:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010460b:	83 f8 13             	cmp    $0x13,%eax
f010460e:	77 09                	ja     f0104619 <print_trapframe+0x65>
		return excnames[trapno];
f0104610:	8b 14 85 c0 7c 10 f0 	mov    -0xfef8340(,%eax,4),%edx
f0104617:	eb 1f                	jmp    f0104638 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f0104619:	83 f8 30             	cmp    $0x30,%eax
f010461c:	74 15                	je     f0104633 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f010461e:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0104621:	83 fa 0f             	cmp    $0xf,%edx
f0104624:	ba 9b 79 10 f0       	mov    $0xf010799b,%edx
f0104629:	b9 ae 79 10 f0       	mov    $0xf01079ae,%ecx
f010462e:	0f 47 d1             	cmova  %ecx,%edx
f0104631:	eb 05                	jmp    f0104638 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104633:	ba 8f 79 10 f0       	mov    $0xf010798f,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104638:	89 54 24 08          	mov    %edx,0x8(%esp)
f010463c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104640:	c7 04 24 28 7a 10 f0 	movl   $0xf0107a28,(%esp)
f0104647:	e8 2d fb ff ff       	call   f0104179 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010464c:	3b 1d 60 3a 22 f0    	cmp    0xf0223a60,%ebx
f0104652:	75 19                	jne    f010466d <print_trapframe+0xb9>
f0104654:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104658:	75 13                	jne    f010466d <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010465a:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010465d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104661:	c7 04 24 3a 7a 10 f0 	movl   $0xf0107a3a,(%esp)
f0104668:	e8 0c fb ff ff       	call   f0104179 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010466d:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104670:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104674:	c7 04 24 49 7a 10 f0 	movl   $0xf0107a49,(%esp)
f010467b:	e8 f9 fa ff ff       	call   f0104179 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f0104680:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104684:	75 51                	jne    f01046d7 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104686:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104689:	89 c2                	mov    %eax,%edx
f010468b:	83 e2 01             	and    $0x1,%edx
f010468e:	ba bd 79 10 f0       	mov    $0xf01079bd,%edx
f0104693:	b9 c8 79 10 f0       	mov    $0xf01079c8,%ecx
f0104698:	0f 45 ca             	cmovne %edx,%ecx
f010469b:	89 c2                	mov    %eax,%edx
f010469d:	83 e2 02             	and    $0x2,%edx
f01046a0:	ba d4 79 10 f0       	mov    $0xf01079d4,%edx
f01046a5:	be da 79 10 f0       	mov    $0xf01079da,%esi
f01046aa:	0f 44 d6             	cmove  %esi,%edx
f01046ad:	83 e0 04             	and    $0x4,%eax
f01046b0:	b8 df 79 10 f0       	mov    $0xf01079df,%eax
f01046b5:	be 49 7b 10 f0       	mov    $0xf0107b49,%esi
f01046ba:	0f 44 c6             	cmove  %esi,%eax
f01046bd:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01046c1:	89 54 24 08          	mov    %edx,0x8(%esp)
f01046c5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046c9:	c7 04 24 57 7a 10 f0 	movl   $0xf0107a57,(%esp)
f01046d0:	e8 a4 fa ff ff       	call   f0104179 <cprintf>
f01046d5:	eb 0c                	jmp    f01046e3 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01046d7:	c7 04 24 bb 6d 10 f0 	movl   $0xf0106dbb,(%esp)
f01046de:	e8 96 fa ff ff       	call   f0104179 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01046e3:	8b 43 30             	mov    0x30(%ebx),%eax
f01046e6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046ea:	c7 04 24 66 7a 10 f0 	movl   $0xf0107a66,(%esp)
f01046f1:	e8 83 fa ff ff       	call   f0104179 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01046f6:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01046fa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046fe:	c7 04 24 75 7a 10 f0 	movl   $0xf0107a75,(%esp)
f0104705:	e8 6f fa ff ff       	call   f0104179 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f010470a:	8b 43 38             	mov    0x38(%ebx),%eax
f010470d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104711:	c7 04 24 88 7a 10 f0 	movl   $0xf0107a88,(%esp)
f0104718:	e8 5c fa ff ff       	call   f0104179 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010471d:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0104721:	74 27                	je     f010474a <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0104723:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104726:	89 44 24 04          	mov    %eax,0x4(%esp)
f010472a:	c7 04 24 97 7a 10 f0 	movl   $0xf0107a97,(%esp)
f0104731:	e8 43 fa ff ff       	call   f0104179 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104736:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f010473a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010473e:	c7 04 24 a6 7a 10 f0 	movl   $0xf0107aa6,(%esp)
f0104745:	e8 2f fa ff ff       	call   f0104179 <cprintf>
	}
}
f010474a:	83 c4 10             	add    $0x10,%esp
f010474d:	5b                   	pop    %ebx
f010474e:	5e                   	pop    %esi
f010474f:	5d                   	pop    %ebp
f0104750:	c3                   	ret    

f0104751 <break_point_handler>:
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}
void
break_point_handler(struct Trapframe *tf)
{
f0104751:	55                   	push   %ebp
f0104752:	89 e5                	mov    %esp,%ebp
f0104754:	83 ec 18             	sub    $0x18,%esp
	monitor(tf);
f0104757:	8b 45 08             	mov    0x8(%ebp),%eax
f010475a:	89 04 24             	mov    %eax,(%esp)
f010475d:	e8 45 c2 ff ff       	call   f01009a7 <monitor>
}
f0104762:	c9                   	leave  
f0104763:	c3                   	ret    

f0104764 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104764:	55                   	push   %ebp
f0104765:	89 e5                	mov    %esp,%ebp
f0104767:	56                   	push   %esi
f0104768:	53                   	push   %ebx
f0104769:	83 ec 10             	sub    $0x10,%esp
f010476c:	8b 45 08             	mov    0x8(%ebp),%eax
f010476f:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0)
f0104772:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0104776:	75 1c                	jne    f0104794 <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f0104778:	c7 44 24 08 b9 7a 10 	movl   $0xf0107ab9,0x8(%esp)
f010477f:	f0 
f0104780:	c7 44 24 04 4a 01 00 	movl   $0x14a,0x4(%esp)
f0104787:	00 
f0104788:	c7 04 24 d3 7a 10 f0 	movl   $0xf0107ad3,(%esp)
f010478f:	e8 ac b8 ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104794:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104797:	e8 57 18 00 00       	call   f0105ff3 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f010479c:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01047a0:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f01047a4:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f01047a7:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01047ad:	8b 40 48             	mov    0x48(%eax),%eax
f01047b0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047b4:	c7 04 24 94 7c 10 f0 	movl   $0xf0107c94,(%esp)
f01047bb:	e8 b9 f9 ff ff       	call   f0104179 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f01047c0:	e8 2e 18 00 00       	call   f0105ff3 <cpunum>
f01047c5:	6b c0 74             	imul   $0x74,%eax,%eax
f01047c8:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01047ce:	89 04 24             	mov    %eax,(%esp)
f01047d1:	e8 f3 f6 ff ff       	call   f0103ec9 <env_destroy>
}
f01047d6:	83 c4 10             	add    $0x10,%esp
f01047d9:	5b                   	pop    %ebx
f01047da:	5e                   	pop    %esi
f01047db:	5d                   	pop    %ebp
f01047dc:	c3                   	ret    

f01047dd <trap>:



void
trap(struct Trapframe *tf)
{
f01047dd:	55                   	push   %ebp
f01047de:	89 e5                	mov    %esp,%ebp
f01047e0:	57                   	push   %edi
f01047e1:	56                   	push   %esi
f01047e2:	83 ec 20             	sub    $0x20,%esp
f01047e5:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01047e8:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01047e9:	83 3d 00 3f 22 f0 00 	cmpl   $0x0,0xf0223f00
f01047f0:	74 01                	je     f01047f3 <trap+0x16>
		asm volatile("hlt");
f01047f2:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f01047f3:	9c                   	pushf  
f01047f4:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f01047f5:	f6 c4 02             	test   $0x2,%ah
f01047f8:	74 24                	je     f010481e <trap+0x41>
f01047fa:	c7 44 24 0c df 7a 10 	movl   $0xf0107adf,0xc(%esp)
f0104801:	f0 
f0104802:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f0104809:	f0 
f010480a:	c7 44 24 04 13 01 00 	movl   $0x113,0x4(%esp)
f0104811:	00 
f0104812:	c7 04 24 d3 7a 10 f0 	movl   $0xf0107ad3,(%esp)
f0104819:	e8 22 b8 ff ff       	call   f0100040 <_panic>
//<<<<<< HEAD
   // panic("trap called!");
	cprintf("Incoming TRAP frame at %p\n", tf);
f010481e:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104822:	c7 04 24 f8 7a 10 f0 	movl   $0xf0107af8,(%esp)
f0104829:	e8 4b f9 ff ff       	call   f0104179 <cprintf>
//=======
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	if ((tf->tf_cs & 3) == 3) {
f010482e:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f0104832:	83 e0 03             	and    $0x3,%eax
f0104835:	66 83 f8 03          	cmp    $0x3,%ax
f0104839:	0f 85 9b 00 00 00    	jne    f01048da <trap+0xfd>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		assert(curenv);
f010483f:	e8 af 17 00 00       	call   f0105ff3 <cpunum>
f0104844:	6b c0 74             	imul   $0x74,%eax,%eax
f0104847:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f010484e:	75 24                	jne    f0104874 <trap+0x97>
f0104850:	c7 44 24 0c 13 7b 10 	movl   $0xf0107b13,0xc(%esp)
f0104857:	f0 
f0104858:	c7 44 24 08 ec 6c 10 	movl   $0xf0106cec,0x8(%esp)
f010485f:	f0 
f0104860:	c7 44 24 04 1f 01 00 	movl   $0x11f,0x4(%esp)
f0104867:	00 
f0104868:	c7 04 24 d3 7a 10 f0 	movl   $0xf0107ad3,(%esp)
f010486f:	e8 cc b7 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0104874:	e8 7a 17 00 00       	call   f0105ff3 <cpunum>
f0104879:	6b c0 74             	imul   $0x74,%eax,%eax
f010487c:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104882:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104886:	75 2d                	jne    f01048b5 <trap+0xd8>
			env_free(curenv);
f0104888:	e8 66 17 00 00       	call   f0105ff3 <cpunum>
f010488d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104890:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104896:	89 04 24             	mov    %eax,(%esp)
f0104899:	e8 26 f4 ff ff       	call   f0103cc4 <env_free>
			curenv = NULL;
f010489e:	e8 50 17 00 00       	call   f0105ff3 <cpunum>
f01048a3:	6b c0 74             	imul   $0x74,%eax,%eax
f01048a6:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f01048ad:	00 00 00 
			sched_yield();
f01048b0:	e8 9c 01 00 00       	call   f0104a51 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f01048b5:	e8 39 17 00 00       	call   f0105ff3 <cpunum>
f01048ba:	6b c0 74             	imul   $0x74,%eax,%eax
f01048bd:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01048c3:	b9 11 00 00 00       	mov    $0x11,%ecx
f01048c8:	89 c7                	mov    %eax,%edi
f01048ca:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f01048cc:	e8 22 17 00 00       	call   f0105ff3 <cpunum>
f01048d1:	6b c0 74             	imul   $0x74,%eax,%eax
f01048d4:	8b b0 28 40 22 f0    	mov    -0xfddbfd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f01048da:	89 35 60 3a 22 f0    	mov    %esi,0xf0223a60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f01048e0:	89 34 24             	mov    %esi,(%esp)
f01048e3:	e8 cc fc ff ff       	call   f01045b4 <print_trapframe>
	// LAB 3: Your code here.
//<<<<<<< HEAD
	if(tf->tf_trapno==T_PGFLT)
f01048e8:	8b 46 28             	mov    0x28(%esi),%eax
f01048eb:	83 f8 0e             	cmp    $0xe,%eax
f01048ee:	75 0d                	jne    f01048fd <trap+0x120>
	{
		page_fault_handler(tf);
f01048f0:	89 34 24             	mov    %esi,(%esp)
f01048f3:	e8 6c fe ff ff       	call   f0104764 <page_fault_handler>
f01048f8:	e9 9d 00 00 00       	jmp    f010499a <trap+0x1bd>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01048fd:	83 f8 03             	cmp    $0x3,%eax
f0104900:	75 0d                	jne    f010490f <trap+0x132>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}
void
break_point_handler(struct Trapframe *tf)
{
	monitor(tf);
f0104902:	89 34 24             	mov    %esi,(%esp)
f0104905:	e8 9d c0 ff ff       	call   f01009a7 <monitor>
f010490a:	e9 8b 00 00 00       	jmp    f010499a <trap+0x1bd>
	if(tf->tf_trapno==T_BRKPT)
	{
		break_point_handler(tf);
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f010490f:	83 f8 30             	cmp    $0x30,%eax
f0104912:	75 32                	jne    f0104946 <trap+0x169>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f0104914:	8b 46 04             	mov    0x4(%esi),%eax
f0104917:	89 44 24 14          	mov    %eax,0x14(%esp)
f010491b:	8b 06                	mov    (%esi),%eax
f010491d:	89 44 24 10          	mov    %eax,0x10(%esp)
f0104921:	8b 46 10             	mov    0x10(%esi),%eax
f0104924:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104928:	8b 46 18             	mov    0x18(%esi),%eax
f010492b:	89 44 24 08          	mov    %eax,0x8(%esp)
f010492f:	8b 46 14             	mov    0x14(%esi),%eax
f0104932:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104936:	8b 46 1c             	mov    0x1c(%esi),%eax
f0104939:	89 04 24             	mov    %eax,(%esp)
f010493c:	e8 af 01 00 00       	call   f0104af0 <syscall>
f0104941:	89 46 1c             	mov    %eax,0x1c(%esi)
f0104944:	eb 54                	jmp    f010499a <trap+0x1bd>
//=======

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f0104946:	83 f8 27             	cmp    $0x27,%eax
f0104949:	75 16                	jne    f0104961 <trap+0x184>
		cprintf("Spurious interrupt on irq 7\n");
f010494b:	c7 04 24 1a 7b 10 f0 	movl   $0xf0107b1a,(%esp)
f0104952:	e8 22 f8 ff ff       	call   f0104179 <cprintf>
		print_trapframe(tf);
f0104957:	89 34 24             	mov    %esi,(%esp)
f010495a:	e8 55 fc ff ff       	call   f01045b4 <print_trapframe>
f010495f:	eb 39                	jmp    f010499a <trap+0x1bd>
	// LAB 4: Your code here.

//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f0104961:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104966:	75 1c                	jne    f0104984 <trap+0x1a7>
		panic("unhandled trap in kernel");
f0104968:	c7 44 24 08 37 7b 10 	movl   $0xf0107b37,0x8(%esp)
f010496f:	f0 
f0104970:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
f0104977:	00 
f0104978:	c7 04 24 d3 7a 10 f0 	movl   $0xf0107ad3,(%esp)
f010497f:	e8 bc b6 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104984:	e8 6a 16 00 00       	call   f0105ff3 <cpunum>
f0104989:	6b c0 74             	imul   $0x74,%eax,%eax
f010498c:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104992:	89 04 24             	mov    %eax,(%esp)
f0104995:	e8 2f f5 ff ff       	call   f0103ec9 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f010499a:	e8 54 16 00 00       	call   f0105ff3 <cpunum>
f010499f:	6b c0 74             	imul   $0x74,%eax,%eax
f01049a2:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f01049a9:	74 2a                	je     f01049d5 <trap+0x1f8>
f01049ab:	e8 43 16 00 00       	call   f0105ff3 <cpunum>
f01049b0:	6b c0 74             	imul   $0x74,%eax,%eax
f01049b3:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01049b9:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f01049bd:	75 16                	jne    f01049d5 <trap+0x1f8>
		env_run(curenv);
f01049bf:	e8 2f 16 00 00       	call   f0105ff3 <cpunum>
f01049c4:	6b c0 74             	imul   $0x74,%eax,%eax
f01049c7:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01049cd:	89 04 24             	mov    %eax,(%esp)
f01049d0:	e8 95 f5 ff ff       	call   f0103f6a <env_run>
	else
		sched_yield();
f01049d5:	e8 77 00 00 00       	call   f0104a51 <sched_yield>

f01049da <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01049da:	6a 00                	push   $0x0
f01049dc:	6a 00                	push   $0x0
f01049de:	eb 58                	jmp    f0104a38 <_alltraps>

f01049e0 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01049e0:	6a 00                	push   $0x0
f01049e2:	6a 02                	push   $0x2
f01049e4:	eb 52                	jmp    f0104a38 <_alltraps>

f01049e6 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01049e6:	6a 00                	push   $0x0
f01049e8:	6a 03                	push   $0x3
f01049ea:	eb 4c                	jmp    f0104a38 <_alltraps>

f01049ec <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01049ec:	6a 00                	push   $0x0
f01049ee:	6a 04                	push   $0x4
f01049f0:	eb 46                	jmp    f0104a38 <_alltraps>

f01049f2 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01049f2:	6a 00                	push   $0x0
f01049f4:	6a 05                	push   $0x5
f01049f6:	eb 40                	jmp    f0104a38 <_alltraps>

f01049f8 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01049f8:	6a 00                	push   $0x0
f01049fa:	6a 06                	push   $0x6
f01049fc:	eb 3a                	jmp    f0104a38 <_alltraps>

f01049fe <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01049fe:	6a 00                	push   $0x0
f0104a00:	6a 07                	push   $0x7
f0104a02:	eb 34                	jmp    f0104a38 <_alltraps>

f0104a04 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f0104a04:	6a 08                	push   $0x8
f0104a06:	eb 30                	jmp    f0104a38 <_alltraps>

f0104a08 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f0104a08:	6a 0a                	push   $0xa
f0104a0a:	eb 2c                	jmp    f0104a38 <_alltraps>

f0104a0c <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f0104a0c:	6a 0b                	push   $0xb
f0104a0e:	eb 28                	jmp    f0104a38 <_alltraps>

f0104a10 <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f0104a10:	6a 0c                	push   $0xc
f0104a12:	eb 24                	jmp    f0104a38 <_alltraps>

f0104a14 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f0104a14:	6a 0d                	push   $0xd
f0104a16:	eb 20                	jmp    f0104a38 <_alltraps>

f0104a18 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f0104a18:	6a 0e                	push   $0xe
f0104a1a:	eb 1c                	jmp    f0104a38 <_alltraps>

f0104a1c <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f0104a1c:	6a 00                	push   $0x0
f0104a1e:	6a 10                	push   $0x10
f0104a20:	eb 16                	jmp    f0104a38 <_alltraps>

f0104a22 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0104a22:	6a 11                	push   $0x11
f0104a24:	eb 12                	jmp    f0104a38 <_alltraps>

f0104a26 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0104a26:	6a 00                	push   $0x0
f0104a28:	6a 12                	push   $0x12
f0104a2a:	eb 0c                	jmp    f0104a38 <_alltraps>

f0104a2c <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f0104a2c:	6a 00                	push   $0x0
f0104a2e:	6a 13                	push   $0x13
f0104a30:	eb 06                	jmp    f0104a38 <_alltraps>

f0104a32 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104a32:	6a 00                	push   $0x0
f0104a34:	6a 30                	push   $0x30
f0104a36:	eb 00                	jmp    f0104a38 <_alltraps>

f0104a38 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
pushw $0
f0104a38:	66 6a 00             	pushw  $0x0
pushw %ds
f0104a3b:	66 1e                	pushw  %ds
pushw $0
f0104a3d:	66 6a 00             	pushw  $0x0
pushw %es
f0104a40:	66 06                	pushw  %es
pushal
f0104a42:	60                   	pusha  
pushl %esp
f0104a43:	54                   	push   %esp
movw $(GD_KD),%ax
f0104a44:	66 b8 10 00          	mov    $0x10,%ax
movw %ax,%ds
f0104a48:	8e d8                	mov    %eax,%ds
movw %ax,%es
f0104a4a:	8e c0                	mov    %eax,%es
call trap
f0104a4c:	e8 8c fd ff ff       	call   f01047dd <trap>

f0104a51 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104a51:	55                   	push   %ebp
f0104a52:	89 e5                	mov    %esp,%ebp
f0104a54:	53                   	push   %ebx
f0104a55:	83 ec 14             	sub    $0x14,%esp

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a58:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
f0104a5e:	89 d8                	mov    %ebx,%eax
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104a60:	ba 00 00 00 00       	mov    $0x0,%edx
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a65:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104a69:	74 0b                	je     f0104a76 <sched_yield+0x25>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104a6b:	8b 48 54             	mov    0x54(%eax),%ecx
f0104a6e:	83 e9 02             	sub    $0x2,%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a71:	83 f9 01             	cmp    $0x1,%ecx
f0104a74:	76 10                	jbe    f0104a86 <sched_yield+0x35>
	// LAB 4: Your code here.

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104a76:	83 c2 01             	add    $0x1,%edx
f0104a79:	83 c0 7c             	add    $0x7c,%eax
f0104a7c:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104a82:	75 e1                	jne    f0104a65 <sched_yield+0x14>
f0104a84:	eb 08                	jmp    f0104a8e <sched_yield+0x3d>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104a86:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104a8c:	75 1a                	jne    f0104aa8 <sched_yield+0x57>
		cprintf("No more runnable environments!\n");
f0104a8e:	c7 04 24 10 7d 10 f0 	movl   $0xf0107d10,(%esp)
f0104a95:	e8 df f6 ff ff       	call   f0104179 <cprintf>
		while (1)
			monitor(NULL);
f0104a9a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104aa1:	e8 01 bf ff ff       	call   f01009a7 <monitor>
f0104aa6:	eb f2                	jmp    f0104a9a <sched_yield+0x49>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104aa8:	e8 46 15 00 00       	call   f0105ff3 <cpunum>
f0104aad:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104ab0:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104ab2:	8b 43 54             	mov    0x54(%ebx),%eax
f0104ab5:	83 e8 02             	sub    $0x2,%eax
f0104ab8:	83 f8 01             	cmp    $0x1,%eax
f0104abb:	76 25                	jbe    f0104ae2 <sched_yield+0x91>
		panic("CPU %d: No idle environment!", cpunum());
f0104abd:	e8 31 15 00 00       	call   f0105ff3 <cpunum>
f0104ac2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104ac6:	c7 44 24 08 30 7d 10 	movl   $0xf0107d30,0x8(%esp)
f0104acd:	f0 
f0104ace:	c7 44 24 04 33 00 00 	movl   $0x33,0x4(%esp)
f0104ad5:	00 
f0104ad6:	c7 04 24 4d 7d 10 f0 	movl   $0xf0107d4d,(%esp)
f0104add:	e8 5e b5 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104ae2:	89 1c 24             	mov    %ebx,(%esp)
f0104ae5:	e8 80 f4 ff ff       	call   f0103f6a <env_run>
f0104aea:	66 90                	xchg   %ax,%ax
f0104aec:	66 90                	xchg   %ax,%ax
f0104aee:	66 90                	xchg   %ax,%ax

f0104af0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104af0:	55                   	push   %ebp
f0104af1:	89 e5                	mov    %esp,%ebp
f0104af3:	53                   	push   %ebx
f0104af4:	83 ec 24             	sub    $0x24,%esp
f0104af7:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
		
	int32_t r=0;		
	switch(syscallno){
f0104afa:	83 f8 01             	cmp    $0x1,%eax
f0104afd:	74 66                	je     f0104b65 <syscall+0x75>
f0104aff:	83 f8 01             	cmp    $0x1,%eax
f0104b02:	72 11                	jb     f0104b15 <syscall+0x25>
f0104b04:	83 f8 02             	cmp    $0x2,%eax
f0104b07:	74 66                	je     f0104b6f <syscall+0x7f>
f0104b09:	83 f8 03             	cmp    $0x3,%eax
f0104b0c:	74 78                	je     f0104b86 <syscall+0x96>
f0104b0e:	66 90                	xchg   %ax,%ax
f0104b10:	e9 ff 00 00 00       	jmp    f0104c14 <syscall+0x124>
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.

	// LAB 3: Your code here.
	user_mem_assert(curenv, s, len, 0);
f0104b15:	e8 d9 14 00 00       	call   f0105ff3 <cpunum>
f0104b1a:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104b21:	00 
f0104b22:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104b25:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104b29:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104b2c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104b30:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b33:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104b39:	89 04 24             	mov    %eax,(%esp)
f0104b3c:	e8 83 eb ff ff       	call   f01036c4 <user_mem_assert>
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104b41:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b44:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104b48:	8b 45 10             	mov    0x10(%ebp),%eax
f0104b4b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b4f:	c7 04 24 5a 7d 10 f0 	movl   $0xf0107d5a,(%esp)
f0104b56:	e8 1e f6 ff ff       	call   f0104179 <cprintf>
{
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
		
	int32_t r=0;		
f0104b5b:	b8 00 00 00 00       	mov    $0x0,%eax
f0104b60:	e9 b4 00 00 00       	jmp    f0104c19 <syscall+0x129>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104b65:	e8 2b bb ff ff       	call   f0100695 <cons_getc>
	int32_t r=0;		
	switch(syscallno){
	case SYS_cputs:sys_cputs((const char*)a1, (size_t)a2);
			break;
        case SYS_cgetc: r=sys_cgetc();
			break;
f0104b6a:	e9 aa 00 00 00       	jmp    f0104c19 <syscall+0x129>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104b6f:	90                   	nop
f0104b70:	e8 7e 14 00 00       	call   f0105ff3 <cpunum>
f0104b75:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b78:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104b7e:	8b 40 48             	mov    0x48(%eax),%eax
	case SYS_cputs:sys_cputs((const char*)a1, (size_t)a2);
			break;
        case SYS_cgetc: r=sys_cgetc();
			break;
	case SYS_getenvid: r=sys_getenvid();
			break;
f0104b81:	e9 93 00 00 00       	jmp    f0104c19 <syscall+0x129>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104b86:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104b8d:	00 
f0104b8e:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0104b91:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b95:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b98:	89 04 24             	mov    %eax,(%esp)
f0104b9b:	e8 2c ec ff ff       	call   f01037cc <envid2env>
f0104ba0:	85 c0                	test   %eax,%eax
f0104ba2:	78 75                	js     f0104c19 <syscall+0x129>
		return r;
	if (e == curenv)
f0104ba4:	e8 4a 14 00 00       	call   f0105ff3 <cpunum>
f0104ba9:	8b 55 f4             	mov    -0xc(%ebp),%edx
f0104bac:	6b c0 74             	imul   $0x74,%eax,%eax
f0104baf:	39 90 28 40 22 f0    	cmp    %edx,-0xfddbfd8(%eax)
f0104bb5:	75 23                	jne    f0104bda <syscall+0xea>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f0104bb7:	e8 37 14 00 00       	call   f0105ff3 <cpunum>
f0104bbc:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bbf:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104bc5:	8b 40 48             	mov    0x48(%eax),%eax
f0104bc8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bcc:	c7 04 24 5f 7d 10 f0 	movl   $0xf0107d5f,(%esp)
f0104bd3:	e8 a1 f5 ff ff       	call   f0104179 <cprintf>
f0104bd8:	eb 28                	jmp    f0104c02 <syscall+0x112>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f0104bda:	8b 5a 48             	mov    0x48(%edx),%ebx
f0104bdd:	e8 11 14 00 00       	call   f0105ff3 <cpunum>
f0104be2:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0104be6:	6b c0 74             	imul   $0x74,%eax,%eax
f0104be9:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104bef:	8b 40 48             	mov    0x48(%eax),%eax
f0104bf2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bf6:	c7 04 24 7a 7d 10 f0 	movl   $0xf0107d7a,(%esp)
f0104bfd:	e8 77 f5 ff ff       	call   f0104179 <cprintf>
	env_destroy(e);
f0104c02:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104c05:	89 04 24             	mov    %eax,(%esp)
f0104c08:	e8 bc f2 ff ff       	call   f0103ec9 <env_destroy>
	return 0;
f0104c0d:	b8 00 00 00 00       	mov    $0x0,%eax
        case SYS_cgetc: r=sys_cgetc();
			break;
	case SYS_getenvid: r=sys_getenvid();
			break;
	case SYS_env_destroy: r=sys_env_destroy((envid_t)a1);
			break;
f0104c12:	eb 05                	jmp    f0104c19 <syscall+0x129>
	default:
		r=-E_INVAL;
f0104c14:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}

	return r;
	
	panic("syscall not implemented");
}
f0104c19:	83 c4 24             	add    $0x24,%esp
f0104c1c:	5b                   	pop    %ebx
f0104c1d:	5d                   	pop    %ebp
f0104c1e:	c3                   	ret    
f0104c1f:	90                   	nop

f0104c20 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104c20:	55                   	push   %ebp
f0104c21:	89 e5                	mov    %esp,%ebp
f0104c23:	57                   	push   %edi
f0104c24:	56                   	push   %esi
f0104c25:	53                   	push   %ebx
f0104c26:	83 ec 14             	sub    $0x14,%esp
f0104c29:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104c2c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0104c2f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104c32:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104c35:	8b 1a                	mov    (%edx),%ebx
f0104c37:	8b 01                	mov    (%ecx),%eax
f0104c39:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f0104c3c:	39 c3                	cmp    %eax,%ebx
f0104c3e:	0f 8f 9a 00 00 00    	jg     f0104cde <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104c44:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104c4b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0104c4e:	01 d8                	add    %ebx,%eax
f0104c50:	89 c7                	mov    %eax,%edi
f0104c52:	c1 ef 1f             	shr    $0x1f,%edi
f0104c55:	01 c7                	add    %eax,%edi
f0104c57:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104c59:	39 df                	cmp    %ebx,%edi
f0104c5b:	0f 8c c4 00 00 00    	jl     f0104d25 <stab_binsearch+0x105>
f0104c61:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104c64:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104c67:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0104c6a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0104c6e:	39 f0                	cmp    %esi,%eax
f0104c70:	0f 84 b4 00 00 00    	je     f0104d2a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104c76:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104c78:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104c7b:	39 d8                	cmp    %ebx,%eax
f0104c7d:	0f 8c a2 00 00 00    	jl     f0104d25 <stab_binsearch+0x105>
f0104c83:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104c87:	83 ea 0c             	sub    $0xc,%edx
f0104c8a:	39 f1                	cmp    %esi,%ecx
f0104c8c:	75 ea                	jne    f0104c78 <stab_binsearch+0x58>
f0104c8e:	e9 99 00 00 00       	jmp    f0104d2c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104c93:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104c96:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104c98:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104c9b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104ca2:	eb 2b                	jmp    f0104ccf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0104ca4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104ca7:	76 14                	jbe    f0104cbd <stab_binsearch+0x9d>
			*region_right = m - 1;
f0104ca9:	83 e8 01             	sub    $0x1,%eax
f0104cac:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0104caf:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104cb2:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104cb4:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104cbb:	eb 12                	jmp    f0104ccf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0104cbd:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104cc0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0104cc2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0104cc6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104cc8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0104ccf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0104cd2:	0f 8e 73 ff ff ff    	jle    f0104c4b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0104cd8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0104cdc:	75 0f                	jne    f0104ced <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0104cde:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ce1:	8b 00                	mov    (%eax),%eax
f0104ce3:	83 e8 01             	sub    $0x1,%eax
f0104ce6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104ce9:	89 06                	mov    %eax,(%esi)
f0104ceb:	eb 57                	jmp    f0104d44 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104ced:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104cf0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0104cf2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104cf5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104cf7:	39 c8                	cmp    %ecx,%eax
f0104cf9:	7e 23                	jle    f0104d1e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104cfb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104cfe:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104d01:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104d04:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104d08:	39 f3                	cmp    %esi,%ebx
f0104d0a:	74 12                	je     f0104d1e <stab_binsearch+0xfe>
		     l--)
f0104d0c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104d0f:	39 c8                	cmp    %ecx,%eax
f0104d11:	7e 0b                	jle    f0104d1e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104d13:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104d17:	83 ea 0c             	sub    $0xc,%edx
f0104d1a:	39 f3                	cmp    %esi,%ebx
f0104d1c:	75 ee                	jne    f0104d0c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0104d1e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104d21:	89 06                	mov    %eax,(%esi)
f0104d23:	eb 1f                	jmp    f0104d44 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104d25:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104d28:	eb a5                	jmp    f0104ccf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104d2a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0104d2c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104d2f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104d32:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104d36:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104d39:	0f 82 54 ff ff ff    	jb     f0104c93 <stab_binsearch+0x73>
f0104d3f:	e9 60 ff ff ff       	jmp    f0104ca4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104d44:	83 c4 14             	add    $0x14,%esp
f0104d47:	5b                   	pop    %ebx
f0104d48:	5e                   	pop    %esi
f0104d49:	5f                   	pop    %edi
f0104d4a:	5d                   	pop    %ebp
f0104d4b:	c3                   	ret    

f0104d4c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0104d4c:	55                   	push   %ebp
f0104d4d:	89 e5                	mov    %esp,%ebp
f0104d4f:	57                   	push   %edi
f0104d50:	56                   	push   %esi
f0104d51:	53                   	push   %ebx
f0104d52:	83 ec 3c             	sub    $0x3c,%esp
f0104d55:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104d58:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0104d5b:	c7 06 92 7d 10 f0    	movl   $0xf0107d92,(%esi)
	info->eip_line = 0;
f0104d61:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104d68:	c7 46 08 92 7d 10 f0 	movl   $0xf0107d92,0x8(%esi)
	info->eip_fn_namelen = 9;
f0104d6f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104d76:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104d79:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104d80:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104d86:	0f 87 ca 00 00 00    	ja     f0104e56 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
f0104d8c:	e8 62 12 00 00       	call   f0105ff3 <cpunum>
f0104d91:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104d98:	00 
f0104d99:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0104da0:	00 
f0104da1:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0104da8:	00 
f0104da9:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dac:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104db2:	89 04 24             	mov    %eax,(%esp)
f0104db5:	e8 4f e8 ff ff       	call   f0103609 <user_mem_check>
f0104dba:	85 c0                	test   %eax,%eax
f0104dbc:	0f 88 12 02 00 00    	js     f0104fd4 <debuginfo_eip+0x288>
		{
		    return -1;
		}
		stabs = usd->stabs;
f0104dc2:	a1 00 00 20 00       	mov    0x200000,%eax
f0104dc7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104dca:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0104dd0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0104dd6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0104dd9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0104dde:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
f0104de1:	e8 0d 12 00 00       	call   f0105ff3 <cpunum>
f0104de6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104ded:	00 
f0104dee:	89 da                	mov    %ebx,%edx
f0104df0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104df3:	29 ca                	sub    %ecx,%edx
f0104df5:	c1 fa 02             	sar    $0x2,%edx
f0104df8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0104dfe:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104e02:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104e06:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e09:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104e0f:	89 04 24             	mov    %eax,(%esp)
f0104e12:	e8 f2 e7 ff ff       	call   f0103609 <user_mem_check>
f0104e17:	85 c0                	test   %eax,%eax
f0104e19:	0f 88 bc 01 00 00    	js     f0104fdb <debuginfo_eip+0x28f>
f0104e1f:	e8 cf 11 00 00       	call   f0105ff3 <cpunum>
f0104e24:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104e2b:	00 
f0104e2c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104e2f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0104e32:	29 ca                	sub    %ecx,%edx
f0104e34:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104e38:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104e3c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e3f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104e45:	89 04 24             	mov    %eax,(%esp)
f0104e48:	e8 bc e7 ff ff       	call   f0103609 <user_mem_check>
f0104e4d:	85 c0                	test   %eax,%eax
f0104e4f:	79 1f                	jns    f0104e70 <debuginfo_eip+0x124>
f0104e51:	e9 8c 01 00 00       	jmp    f0104fe2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0104e56:	c7 45 cc 12 58 11 f0 	movl   $0xf0115812,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0104e5d:	c7 45 d0 d9 23 11 f0 	movl   $0xf01123d9,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0104e64:	bb d8 23 11 f0       	mov    $0xf01123d8,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0104e69:	c7 45 d4 74 82 10 f0 	movl   $0xf0108274,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0104e70:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0104e73:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0104e76:	0f 83 6d 01 00 00    	jae    f0104fe9 <debuginfo_eip+0x29d>
f0104e7c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0104e80:	0f 85 6a 01 00 00    	jne    f0104ff0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0104e86:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0104e8d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0104e90:	c1 fb 02             	sar    $0x2,%ebx
f0104e93:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0104e99:	83 e8 01             	sub    $0x1,%eax
f0104e9c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0104e9f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ea3:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0104eaa:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104ead:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104eb0:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0104eb3:	89 d8                	mov    %ebx,%eax
f0104eb5:	e8 66 fd ff ff       	call   f0104c20 <stab_binsearch>
	if (lfile == 0)
f0104eba:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ebd:	85 c0                	test   %eax,%eax
f0104ebf:	0f 84 32 01 00 00    	je     f0104ff7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0104ec5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0104ec8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104ecb:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0104ece:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ed2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0104ed9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0104edc:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0104edf:	89 d8                	mov    %ebx,%eax
f0104ee1:	e8 3a fd ff ff       	call   f0104c20 <stab_binsearch>

	if (lfun <= rfun) {
f0104ee6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0104ee9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0104eec:	7f 23                	jg     f0104f11 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0104eee:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104ef1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104ef4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0104ef7:	8b 10                	mov    (%eax),%edx
f0104ef9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0104efc:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0104eff:	39 ca                	cmp    %ecx,%edx
f0104f01:	73 06                	jae    f0104f09 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0104f03:	03 55 d0             	add    -0x30(%ebp),%edx
f0104f06:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0104f09:	8b 40 08             	mov    0x8(%eax),%eax
f0104f0c:	89 46 10             	mov    %eax,0x10(%esi)
f0104f0f:	eb 06                	jmp    f0104f17 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0104f11:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0104f14:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0104f17:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104f1e:	00 
f0104f1f:	8b 46 08             	mov    0x8(%esi),%eax
f0104f22:	89 04 24             	mov    %eax,(%esp)
f0104f25:	e8 05 0a 00 00       	call   f010592f <strfind>
f0104f2a:	2b 46 08             	sub    0x8(%esi),%eax
f0104f2d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104f30:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104f33:	39 fb                	cmp    %edi,%ebx
f0104f35:	7c 5d                	jl     f0104f94 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104f37:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104f3a:	c1 e0 02             	shl    $0x2,%eax
f0104f3d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104f40:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104f43:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0104f46:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0104f4a:	80 fa 84             	cmp    $0x84,%dl
f0104f4d:	74 2d                	je     f0104f7c <debuginfo_eip+0x230>
f0104f4f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0104f53:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0104f56:	eb 15                	jmp    f0104f6d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0104f58:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104f5b:	39 fb                	cmp    %edi,%ebx
f0104f5d:	7c 35                	jl     f0104f94 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104f5f:	89 c1                	mov    %eax,%ecx
f0104f61:	83 e8 0c             	sub    $0xc,%eax
f0104f64:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0104f68:	80 fa 84             	cmp    $0x84,%dl
f0104f6b:	74 0f                	je     f0104f7c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0104f6d:	80 fa 64             	cmp    $0x64,%dl
f0104f70:	75 e6                	jne    f0104f58 <debuginfo_eip+0x20c>
f0104f72:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0104f76:	74 e0                	je     f0104f58 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0104f78:	39 df                	cmp    %ebx,%edi
f0104f7a:	7f 18                	jg     f0104f94 <debuginfo_eip+0x248>
f0104f7c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104f7f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104f82:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0104f85:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104f88:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0104f8b:	39 d0                	cmp    %edx,%eax
f0104f8d:	73 05                	jae    f0104f94 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0104f8f:	03 45 d0             	add    -0x30(%ebp),%eax
f0104f92:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104f94:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104f97:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104f9a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104f9f:	39 ca                	cmp    %ecx,%edx
f0104fa1:	7d 75                	jge    f0105018 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0104fa3:	8d 42 01             	lea    0x1(%edx),%eax
f0104fa6:	39 c1                	cmp    %eax,%ecx
f0104fa8:	7e 54                	jle    f0104ffe <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104faa:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104fad:	c1 e2 02             	shl    $0x2,%edx
f0104fb0:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104fb3:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0104fb8:	75 4b                	jne    f0105005 <debuginfo_eip+0x2b9>
f0104fba:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f0104fbe:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0104fc2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0104fc5:	39 c1                	cmp    %eax,%ecx
f0104fc7:	7e 43                	jle    f010500c <debuginfo_eip+0x2c0>
f0104fc9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104fcc:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0104fd0:	74 ec                	je     f0104fbe <debuginfo_eip+0x272>
f0104fd2:	eb 3f                	jmp    f0105013 <debuginfo_eip+0x2c7>
		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
		{
		    return -1;
f0104fd4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fd9:	eb 3d                	jmp    f0105018 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
		 {
		    return -1;
f0104fdb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fe0:	eb 36                	jmp    f0105018 <debuginfo_eip+0x2cc>
f0104fe2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fe7:	eb 2f                	jmp    f0105018 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0104fe9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104fee:	eb 28                	jmp    f0105018 <debuginfo_eip+0x2cc>
f0104ff0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104ff5:	eb 21                	jmp    f0105018 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0104ff7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104ffc:	eb 1a                	jmp    f0105018 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104ffe:	b8 00 00 00 00       	mov    $0x0,%eax
f0105003:	eb 13                	jmp    f0105018 <debuginfo_eip+0x2cc>
f0105005:	b8 00 00 00 00       	mov    $0x0,%eax
f010500a:	eb 0c                	jmp    f0105018 <debuginfo_eip+0x2cc>
f010500c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105011:	eb 05                	jmp    f0105018 <debuginfo_eip+0x2cc>
f0105013:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105018:	83 c4 3c             	add    $0x3c,%esp
f010501b:	5b                   	pop    %ebx
f010501c:	5e                   	pop    %esi
f010501d:	5f                   	pop    %edi
f010501e:	5d                   	pop    %ebp
f010501f:	c3                   	ret    

f0105020 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105020:	55                   	push   %ebp
f0105021:	89 e5                	mov    %esp,%ebp
f0105023:	57                   	push   %edi
f0105024:	56                   	push   %esi
f0105025:	53                   	push   %ebx
f0105026:	83 ec 3c             	sub    $0x3c,%esp
f0105029:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010502c:	89 d7                	mov    %edx,%edi
f010502e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105031:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105034:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105037:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010503a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010503d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105042:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105045:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105048:	39 f1                	cmp    %esi,%ecx
f010504a:	72 14                	jb     f0105060 <printnum+0x40>
f010504c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010504f:	76 0f                	jbe    f0105060 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105051:	8b 45 14             	mov    0x14(%ebp),%eax
f0105054:	8d 70 ff             	lea    -0x1(%eax),%esi
f0105057:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010505a:	85 f6                	test   %esi,%esi
f010505c:	7f 60                	jg     f01050be <printnum+0x9e>
f010505e:	eb 72                	jmp    f01050d2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105060:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105063:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105067:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010506a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010506d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105071:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105075:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105079:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010507d:	89 c3                	mov    %eax,%ebx
f010507f:	89 d6                	mov    %edx,%esi
f0105081:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105084:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105087:	89 54 24 08          	mov    %edx,0x8(%esp)
f010508b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010508f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105092:	89 04 24             	mov    %eax,(%esp)
f0105095:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105098:	89 44 24 04          	mov    %eax,0x4(%esp)
f010509c:	e8 bf 13 00 00       	call   f0106460 <__udivdi3>
f01050a1:	89 d9                	mov    %ebx,%ecx
f01050a3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01050a7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01050ab:	89 04 24             	mov    %eax,(%esp)
f01050ae:	89 54 24 04          	mov    %edx,0x4(%esp)
f01050b2:	89 fa                	mov    %edi,%edx
f01050b4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01050b7:	e8 64 ff ff ff       	call   f0105020 <printnum>
f01050bc:	eb 14                	jmp    f01050d2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f01050be:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050c2:	8b 45 18             	mov    0x18(%ebp),%eax
f01050c5:	89 04 24             	mov    %eax,(%esp)
f01050c8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01050ca:	83 ee 01             	sub    $0x1,%esi
f01050cd:	75 ef                	jne    f01050be <printnum+0x9e>
f01050cf:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f01050d2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050d6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01050da:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01050dd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01050e0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01050e4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01050e8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050eb:	89 04 24             	mov    %eax,(%esp)
f01050ee:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01050f1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01050f5:	e8 96 14 00 00       	call   f0106590 <__umoddi3>
f01050fa:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050fe:	0f be 80 9c 7d 10 f0 	movsbl -0xfef8264(%eax),%eax
f0105105:	89 04 24             	mov    %eax,(%esp)
f0105108:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010510b:	ff d0                	call   *%eax
}
f010510d:	83 c4 3c             	add    $0x3c,%esp
f0105110:	5b                   	pop    %ebx
f0105111:	5e                   	pop    %esi
f0105112:	5f                   	pop    %edi
f0105113:	5d                   	pop    %ebp
f0105114:	c3                   	ret    

f0105115 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0105115:	55                   	push   %ebp
f0105116:	89 e5                	mov    %esp,%ebp
f0105118:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f010511b:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f010511f:	8b 10                	mov    (%eax),%edx
f0105121:	3b 50 04             	cmp    0x4(%eax),%edx
f0105124:	73 0a                	jae    f0105130 <sprintputch+0x1b>
		*b->buf++ = ch;
f0105126:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105129:	89 08                	mov    %ecx,(%eax)
f010512b:	8b 45 08             	mov    0x8(%ebp),%eax
f010512e:	88 02                	mov    %al,(%edx)
}
f0105130:	5d                   	pop    %ebp
f0105131:	c3                   	ret    

f0105132 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0105132:	55                   	push   %ebp
f0105133:	89 e5                	mov    %esp,%ebp
f0105135:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0105138:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f010513b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010513f:	8b 45 10             	mov    0x10(%ebp),%eax
f0105142:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105146:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105149:	89 44 24 04          	mov    %eax,0x4(%esp)
f010514d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105150:	89 04 24             	mov    %eax,(%esp)
f0105153:	e8 02 00 00 00       	call   f010515a <vprintfmt>
	va_end(ap);
}
f0105158:	c9                   	leave  
f0105159:	c3                   	ret    

f010515a <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f010515a:	55                   	push   %ebp
f010515b:	89 e5                	mov    %esp,%ebp
f010515d:	57                   	push   %edi
f010515e:	56                   	push   %esi
f010515f:	53                   	push   %ebx
f0105160:	83 ec 3c             	sub    $0x3c,%esp
f0105163:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105166:	89 df                	mov    %ebx,%edi
f0105168:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010516b:	eb 03                	jmp    f0105170 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f010516d:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0105170:	8b 45 10             	mov    0x10(%ebp),%eax
f0105173:	8d 70 01             	lea    0x1(%eax),%esi
f0105176:	0f b6 00             	movzbl (%eax),%eax
f0105179:	83 f8 25             	cmp    $0x25,%eax
f010517c:	74 2d                	je     f01051ab <vprintfmt+0x51>
			if (ch == '\0')
f010517e:	85 c0                	test   %eax,%eax
f0105180:	75 14                	jne    f0105196 <vprintfmt+0x3c>
f0105182:	e9 6b 04 00 00       	jmp    f01055f2 <vprintfmt+0x498>
f0105187:	85 c0                	test   %eax,%eax
f0105189:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0105190:	0f 84 5c 04 00 00    	je     f01055f2 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0105196:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010519a:	89 04 24             	mov    %eax,(%esp)
f010519d:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f010519f:	83 c6 01             	add    $0x1,%esi
f01051a2:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f01051a6:	83 f8 25             	cmp    $0x25,%eax
f01051a9:	75 dc                	jne    f0105187 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f01051ab:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01051af:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f01051b6:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f01051bd:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f01051c4:	b9 00 00 00 00       	mov    $0x0,%ecx
f01051c9:	eb 1f                	jmp    f01051ea <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01051cb:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f01051ce:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f01051d2:	eb 16                	jmp    f01051ea <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01051d4:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f01051d7:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f01051db:	eb 0d                	jmp    f01051ea <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f01051dd:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01051e0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01051e3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01051ea:	8d 46 01             	lea    0x1(%esi),%eax
f01051ed:	89 45 10             	mov    %eax,0x10(%ebp)
f01051f0:	0f b6 06             	movzbl (%esi),%eax
f01051f3:	0f b6 d0             	movzbl %al,%edx
f01051f6:	83 e8 23             	sub    $0x23,%eax
f01051f9:	3c 55                	cmp    $0x55,%al
f01051fb:	0f 87 c4 03 00 00    	ja     f01055c5 <vprintfmt+0x46b>
f0105201:	0f b6 c0             	movzbl %al,%eax
f0105204:	ff 24 85 60 7e 10 f0 	jmp    *-0xfef81a0(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f010520b:	8d 42 d0             	lea    -0x30(%edx),%eax
f010520e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0105211:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0105215:	8d 50 d0             	lea    -0x30(%eax),%edx
f0105218:	83 fa 09             	cmp    $0x9,%edx
f010521b:	77 63                	ja     f0105280 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010521d:	8b 75 10             	mov    0x10(%ebp),%esi
f0105220:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f0105223:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0105226:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0105229:	8d 14 92             	lea    (%edx,%edx,4),%edx
f010522c:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f0105230:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105233:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0105236:	83 f9 09             	cmp    $0x9,%ecx
f0105239:	76 eb                	jbe    f0105226 <vprintfmt+0xcc>
f010523b:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f010523e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0105241:	eb 40                	jmp    f0105283 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105243:	8b 45 14             	mov    0x14(%ebp),%eax
f0105246:	8b 00                	mov    (%eax),%eax
f0105248:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010524b:	8b 45 14             	mov    0x14(%ebp),%eax
f010524e:	8d 40 04             	lea    0x4(%eax),%eax
f0105251:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105254:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105257:	eb 2a                	jmp    f0105283 <vprintfmt+0x129>
f0105259:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f010525c:	85 d2                	test   %edx,%edx
f010525e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105263:	0f 49 c2             	cmovns %edx,%eax
f0105266:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105269:	8b 75 10             	mov    0x10(%ebp),%esi
f010526c:	e9 79 ff ff ff       	jmp    f01051ea <vprintfmt+0x90>
f0105271:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0105274:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f010527b:	e9 6a ff ff ff       	jmp    f01051ea <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105280:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0105283:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105287:	0f 89 5d ff ff ff    	jns    f01051ea <vprintfmt+0x90>
f010528d:	e9 4b ff ff ff       	jmp    f01051dd <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0105292:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105295:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0105298:	e9 4d ff ff ff       	jmp    f01051ea <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f010529d:	8b 45 14             	mov    0x14(%ebp),%eax
f01052a0:	8d 70 04             	lea    0x4(%eax),%esi
f01052a3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01052a7:	8b 00                	mov    (%eax),%eax
f01052a9:	89 04 24             	mov    %eax,(%esp)
f01052ac:	ff d7                	call   *%edi
f01052ae:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f01052b1:	e9 ba fe ff ff       	jmp    f0105170 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f01052b6:	8b 45 14             	mov    0x14(%ebp),%eax
f01052b9:	8d 70 04             	lea    0x4(%eax),%esi
f01052bc:	8b 00                	mov    (%eax),%eax
f01052be:	99                   	cltd   
f01052bf:	31 d0                	xor    %edx,%eax
f01052c1:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01052c3:	83 f8 08             	cmp    $0x8,%eax
f01052c6:	7f 0b                	jg     f01052d3 <vprintfmt+0x179>
f01052c8:	8b 14 85 c0 7f 10 f0 	mov    -0xfef8040(,%eax,4),%edx
f01052cf:	85 d2                	test   %edx,%edx
f01052d1:	75 20                	jne    f01052f3 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f01052d3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01052d7:	c7 44 24 08 b4 7d 10 	movl   $0xf0107db4,0x8(%esp)
f01052de:	f0 
f01052df:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01052e3:	89 3c 24             	mov    %edi,(%esp)
f01052e6:	e8 47 fe ff ff       	call   f0105132 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f01052eb:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f01052ee:	e9 7d fe ff ff       	jmp    f0105170 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f01052f3:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01052f7:	c7 44 24 08 fe 6c 10 	movl   $0xf0106cfe,0x8(%esp)
f01052fe:	f0 
f01052ff:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105303:	89 3c 24             	mov    %edi,(%esp)
f0105306:	e8 27 fe ff ff       	call   f0105132 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f010530b:	89 75 14             	mov    %esi,0x14(%ebp)
f010530e:	e9 5d fe ff ff       	jmp    f0105170 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105313:	8b 45 14             	mov    0x14(%ebp),%eax
f0105316:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0105319:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f010531c:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f0105320:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0105322:	85 c0                	test   %eax,%eax
f0105324:	b9 ad 7d 10 f0       	mov    $0xf0107dad,%ecx
f0105329:	0f 45 c8             	cmovne %eax,%ecx
f010532c:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f010532f:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0105333:	74 04                	je     f0105339 <vprintfmt+0x1df>
f0105335:	85 f6                	test   %esi,%esi
f0105337:	7f 19                	jg     f0105352 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105339:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010533c:	8d 70 01             	lea    0x1(%eax),%esi
f010533f:	0f b6 10             	movzbl (%eax),%edx
f0105342:	0f be c2             	movsbl %dl,%eax
f0105345:	85 c0                	test   %eax,%eax
f0105347:	0f 85 9a 00 00 00    	jne    f01053e7 <vprintfmt+0x28d>
f010534d:	e9 87 00 00 00       	jmp    f01053d9 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105352:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105356:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105359:	89 04 24             	mov    %eax,(%esp)
f010535c:	e8 11 04 00 00       	call   f0105772 <strnlen>
f0105361:	29 c6                	sub    %eax,%esi
f0105363:	89 f0                	mov    %esi,%eax
f0105365:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105368:	85 f6                	test   %esi,%esi
f010536a:	7e cd                	jle    f0105339 <vprintfmt+0x1df>
					putch(padc, putdat);
f010536c:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105370:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0105373:	89 c3                	mov    %eax,%ebx
f0105375:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105378:	89 44 24 04          	mov    %eax,0x4(%esp)
f010537c:	89 34 24             	mov    %esi,(%esp)
f010537f:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105381:	83 eb 01             	sub    $0x1,%ebx
f0105384:	75 ef                	jne    f0105375 <vprintfmt+0x21b>
f0105386:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105389:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010538c:	eb ab                	jmp    f0105339 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f010538e:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0105392:	74 1e                	je     f01053b2 <vprintfmt+0x258>
f0105394:	0f be d2             	movsbl %dl,%edx
f0105397:	83 ea 20             	sub    $0x20,%edx
f010539a:	83 fa 5e             	cmp    $0x5e,%edx
f010539d:	76 13                	jbe    f01053b2 <vprintfmt+0x258>
					putch('?', putdat);
f010539f:	8b 45 0c             	mov    0xc(%ebp),%eax
f01053a2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01053a6:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01053ad:	ff 55 08             	call   *0x8(%ebp)
f01053b0:	eb 0d                	jmp    f01053bf <vprintfmt+0x265>
				else
					putch(ch, putdat);
f01053b2:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f01053b5:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01053b9:	89 04 24             	mov    %eax,(%esp)
f01053bc:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01053bf:	83 eb 01             	sub    $0x1,%ebx
f01053c2:	83 c6 01             	add    $0x1,%esi
f01053c5:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01053c9:	0f be c2             	movsbl %dl,%eax
f01053cc:	85 c0                	test   %eax,%eax
f01053ce:	75 23                	jne    f01053f3 <vprintfmt+0x299>
f01053d0:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01053d3:	8b 7d 08             	mov    0x8(%ebp),%edi
f01053d6:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01053d9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01053dc:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01053e0:	7f 25                	jg     f0105407 <vprintfmt+0x2ad>
f01053e2:	e9 89 fd ff ff       	jmp    f0105170 <vprintfmt+0x16>
f01053e7:	89 7d 08             	mov    %edi,0x8(%ebp)
f01053ea:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01053ed:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f01053f0:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01053f3:	85 ff                	test   %edi,%edi
f01053f5:	78 97                	js     f010538e <vprintfmt+0x234>
f01053f7:	83 ef 01             	sub    $0x1,%edi
f01053fa:	79 92                	jns    f010538e <vprintfmt+0x234>
f01053fc:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01053ff:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105402:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105405:	eb d2                	jmp    f01053d9 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105407:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010540b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0105412:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105414:	83 ee 01             	sub    $0x1,%esi
f0105417:	75 ee                	jne    f0105407 <vprintfmt+0x2ad>
f0105419:	e9 52 fd ff ff       	jmp    f0105170 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010541e:	83 f9 01             	cmp    $0x1,%ecx
f0105421:	7e 19                	jle    f010543c <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f0105423:	8b 45 14             	mov    0x14(%ebp),%eax
f0105426:	8b 50 04             	mov    0x4(%eax),%edx
f0105429:	8b 00                	mov    (%eax),%eax
f010542b:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010542e:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105431:	8b 45 14             	mov    0x14(%ebp),%eax
f0105434:	8d 40 08             	lea    0x8(%eax),%eax
f0105437:	89 45 14             	mov    %eax,0x14(%ebp)
f010543a:	eb 38                	jmp    f0105474 <vprintfmt+0x31a>
	else if (lflag)
f010543c:	85 c9                	test   %ecx,%ecx
f010543e:	74 1b                	je     f010545b <vprintfmt+0x301>
		return va_arg(*ap, long);
f0105440:	8b 45 14             	mov    0x14(%ebp),%eax
f0105443:	8b 30                	mov    (%eax),%esi
f0105445:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105448:	89 f0                	mov    %esi,%eax
f010544a:	c1 f8 1f             	sar    $0x1f,%eax
f010544d:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105450:	8b 45 14             	mov    0x14(%ebp),%eax
f0105453:	8d 40 04             	lea    0x4(%eax),%eax
f0105456:	89 45 14             	mov    %eax,0x14(%ebp)
f0105459:	eb 19                	jmp    f0105474 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f010545b:	8b 45 14             	mov    0x14(%ebp),%eax
f010545e:	8b 30                	mov    (%eax),%esi
f0105460:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105463:	89 f0                	mov    %esi,%eax
f0105465:	c1 f8 1f             	sar    $0x1f,%eax
f0105468:	89 45 dc             	mov    %eax,-0x24(%ebp)
f010546b:	8b 45 14             	mov    0x14(%ebp),%eax
f010546e:	8d 40 04             	lea    0x4(%eax),%eax
f0105471:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105474:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105477:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010547a:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f010547f:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105483:	0f 89 06 01 00 00    	jns    f010558f <vprintfmt+0x435>
				putch('-', putdat);
f0105489:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010548d:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105494:	ff d7                	call   *%edi
				num = -(long long) num;
f0105496:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105499:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010549c:	f7 da                	neg    %edx
f010549e:	83 d1 00             	adc    $0x0,%ecx
f01054a1:	f7 d9                	neg    %ecx
			}
			base = 10;
f01054a3:	b8 0a 00 00 00       	mov    $0xa,%eax
f01054a8:	e9 e2 00 00 00       	jmp    f010558f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01054ad:	83 f9 01             	cmp    $0x1,%ecx
f01054b0:	7e 10                	jle    f01054c2 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f01054b2:	8b 45 14             	mov    0x14(%ebp),%eax
f01054b5:	8b 10                	mov    (%eax),%edx
f01054b7:	8b 48 04             	mov    0x4(%eax),%ecx
f01054ba:	8d 40 08             	lea    0x8(%eax),%eax
f01054bd:	89 45 14             	mov    %eax,0x14(%ebp)
f01054c0:	eb 26                	jmp    f01054e8 <vprintfmt+0x38e>
	else if (lflag)
f01054c2:	85 c9                	test   %ecx,%ecx
f01054c4:	74 12                	je     f01054d8 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f01054c6:	8b 45 14             	mov    0x14(%ebp),%eax
f01054c9:	8b 10                	mov    (%eax),%edx
f01054cb:	b9 00 00 00 00       	mov    $0x0,%ecx
f01054d0:	8d 40 04             	lea    0x4(%eax),%eax
f01054d3:	89 45 14             	mov    %eax,0x14(%ebp)
f01054d6:	eb 10                	jmp    f01054e8 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f01054d8:	8b 45 14             	mov    0x14(%ebp),%eax
f01054db:	8b 10                	mov    (%eax),%edx
f01054dd:	b9 00 00 00 00       	mov    $0x0,%ecx
f01054e2:	8d 40 04             	lea    0x4(%eax),%eax
f01054e5:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f01054e8:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f01054ed:	e9 9d 00 00 00       	jmp    f010558f <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f01054f2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054f6:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01054fd:	ff d7                	call   *%edi
			putch('X', putdat);
f01054ff:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105503:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010550a:	ff d7                	call   *%edi
			putch('X', putdat);
f010550c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105510:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f0105517:	ff d7                	call   *%edi
			break;
f0105519:	e9 52 fc ff ff       	jmp    f0105170 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f010551e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105522:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105529:	ff d7                	call   *%edi
			putch('x', putdat);
f010552b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010552f:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105536:	ff d7                	call   *%edi
			num = (unsigned long long)
f0105538:	8b 45 14             	mov    0x14(%ebp),%eax
f010553b:	8b 10                	mov    (%eax),%edx
f010553d:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f0105542:	8d 40 04             	lea    0x4(%eax),%eax
f0105545:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0105548:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f010554d:	eb 40                	jmp    f010558f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010554f:	83 f9 01             	cmp    $0x1,%ecx
f0105552:	7e 10                	jle    f0105564 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f0105554:	8b 45 14             	mov    0x14(%ebp),%eax
f0105557:	8b 10                	mov    (%eax),%edx
f0105559:	8b 48 04             	mov    0x4(%eax),%ecx
f010555c:	8d 40 08             	lea    0x8(%eax),%eax
f010555f:	89 45 14             	mov    %eax,0x14(%ebp)
f0105562:	eb 26                	jmp    f010558a <vprintfmt+0x430>
	else if (lflag)
f0105564:	85 c9                	test   %ecx,%ecx
f0105566:	74 12                	je     f010557a <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f0105568:	8b 45 14             	mov    0x14(%ebp),%eax
f010556b:	8b 10                	mov    (%eax),%edx
f010556d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105572:	8d 40 04             	lea    0x4(%eax),%eax
f0105575:	89 45 14             	mov    %eax,0x14(%ebp)
f0105578:	eb 10                	jmp    f010558a <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f010557a:	8b 45 14             	mov    0x14(%ebp),%eax
f010557d:	8b 10                	mov    (%eax),%edx
f010557f:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105584:	8d 40 04             	lea    0x4(%eax),%eax
f0105587:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f010558a:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f010558f:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105593:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105597:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010559a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010559e:	89 44 24 08          	mov    %eax,0x8(%esp)
f01055a2:	89 14 24             	mov    %edx,(%esp)
f01055a5:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01055a9:	89 da                	mov    %ebx,%edx
f01055ab:	89 f8                	mov    %edi,%eax
f01055ad:	e8 6e fa ff ff       	call   f0105020 <printnum>
			break;
f01055b2:	e9 b9 fb ff ff       	jmp    f0105170 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f01055b7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01055bb:	89 14 24             	mov    %edx,(%esp)
f01055be:	ff d7                	call   *%edi
			break;
f01055c0:	e9 ab fb ff ff       	jmp    f0105170 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01055c5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01055c9:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01055d0:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f01055d2:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f01055d6:	0f 84 91 fb ff ff    	je     f010516d <vprintfmt+0x13>
f01055dc:	89 75 10             	mov    %esi,0x10(%ebp)
f01055df:	89 f0                	mov    %esi,%eax
f01055e1:	83 e8 01             	sub    $0x1,%eax
f01055e4:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f01055e8:	75 f7                	jne    f01055e1 <vprintfmt+0x487>
f01055ea:	89 45 10             	mov    %eax,0x10(%ebp)
f01055ed:	e9 7e fb ff ff       	jmp    f0105170 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f01055f2:	83 c4 3c             	add    $0x3c,%esp
f01055f5:	5b                   	pop    %ebx
f01055f6:	5e                   	pop    %esi
f01055f7:	5f                   	pop    %edi
f01055f8:	5d                   	pop    %ebp
f01055f9:	c3                   	ret    

f01055fa <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01055fa:	55                   	push   %ebp
f01055fb:	89 e5                	mov    %esp,%ebp
f01055fd:	83 ec 28             	sub    $0x28,%esp
f0105600:	8b 45 08             	mov    0x8(%ebp),%eax
f0105603:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105606:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105609:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010560d:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105610:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105617:	85 c0                	test   %eax,%eax
f0105619:	74 30                	je     f010564b <vsnprintf+0x51>
f010561b:	85 d2                	test   %edx,%edx
f010561d:	7e 2c                	jle    f010564b <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010561f:	8b 45 14             	mov    0x14(%ebp),%eax
f0105622:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105626:	8b 45 10             	mov    0x10(%ebp),%eax
f0105629:	89 44 24 08          	mov    %eax,0x8(%esp)
f010562d:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105630:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105634:	c7 04 24 15 51 10 f0 	movl   $0xf0105115,(%esp)
f010563b:	e8 1a fb ff ff       	call   f010515a <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105640:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105643:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105646:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105649:	eb 05                	jmp    f0105650 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f010564b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105650:	c9                   	leave  
f0105651:	c3                   	ret    

f0105652 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105652:	55                   	push   %ebp
f0105653:	89 e5                	mov    %esp,%ebp
f0105655:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105658:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f010565b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010565f:	8b 45 10             	mov    0x10(%ebp),%eax
f0105662:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105666:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105669:	89 44 24 04          	mov    %eax,0x4(%esp)
f010566d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105670:	89 04 24             	mov    %eax,(%esp)
f0105673:	e8 82 ff ff ff       	call   f01055fa <vsnprintf>
	va_end(ap);

	return rc;
}
f0105678:	c9                   	leave  
f0105679:	c3                   	ret    
f010567a:	66 90                	xchg   %ax,%ax
f010567c:	66 90                	xchg   %ax,%ax
f010567e:	66 90                	xchg   %ax,%ax

f0105680 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105680:	55                   	push   %ebp
f0105681:	89 e5                	mov    %esp,%ebp
f0105683:	57                   	push   %edi
f0105684:	56                   	push   %esi
f0105685:	53                   	push   %ebx
f0105686:	83 ec 1c             	sub    $0x1c,%esp
f0105689:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010568c:	85 c0                	test   %eax,%eax
f010568e:	74 10                	je     f01056a0 <readline+0x20>
		cprintf("%s", prompt);
f0105690:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105694:	c7 04 24 fe 6c 10 f0 	movl   $0xf0106cfe,(%esp)
f010569b:	e8 d9 ea ff ff       	call   f0104179 <cprintf>

	i = 0;
	echoing = iscons(0);
f01056a0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01056a7:	e8 62 b1 ff ff       	call   f010080e <iscons>
f01056ac:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01056ae:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f01056b3:	e8 45 b1 ff ff       	call   f01007fd <getchar>
f01056b8:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f01056ba:	85 c0                	test   %eax,%eax
f01056bc:	79 17                	jns    f01056d5 <readline+0x55>
			cprintf("read error: %e\n", c);
f01056be:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056c2:	c7 04 24 e4 7f 10 f0 	movl   $0xf0107fe4,(%esp)
f01056c9:	e8 ab ea ff ff       	call   f0104179 <cprintf>
			return NULL;
f01056ce:	b8 00 00 00 00       	mov    $0x0,%eax
f01056d3:	eb 6d                	jmp    f0105742 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01056d5:	83 f8 7f             	cmp    $0x7f,%eax
f01056d8:	74 05                	je     f01056df <readline+0x5f>
f01056da:	83 f8 08             	cmp    $0x8,%eax
f01056dd:	75 19                	jne    f01056f8 <readline+0x78>
f01056df:	85 f6                	test   %esi,%esi
f01056e1:	7e 15                	jle    f01056f8 <readline+0x78>
			if (echoing)
f01056e3:	85 ff                	test   %edi,%edi
f01056e5:	74 0c                	je     f01056f3 <readline+0x73>
				cputchar('\b');
f01056e7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01056ee:	e8 fa b0 ff ff       	call   f01007ed <cputchar>
			i--;
f01056f3:	83 ee 01             	sub    $0x1,%esi
f01056f6:	eb bb                	jmp    f01056b3 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01056f8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01056fe:	7f 1c                	jg     f010571c <readline+0x9c>
f0105700:	83 fb 1f             	cmp    $0x1f,%ebx
f0105703:	7e 17                	jle    f010571c <readline+0x9c>
			if (echoing)
f0105705:	85 ff                	test   %edi,%edi
f0105707:	74 08                	je     f0105711 <readline+0x91>
				cputchar(c);
f0105709:	89 1c 24             	mov    %ebx,(%esp)
f010570c:	e8 dc b0 ff ff       	call   f01007ed <cputchar>
			buf[i++] = c;
f0105711:	88 9e 00 3b 22 f0    	mov    %bl,-0xfddc500(%esi)
f0105717:	8d 76 01             	lea    0x1(%esi),%esi
f010571a:	eb 97                	jmp    f01056b3 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010571c:	83 fb 0d             	cmp    $0xd,%ebx
f010571f:	74 05                	je     f0105726 <readline+0xa6>
f0105721:	83 fb 0a             	cmp    $0xa,%ebx
f0105724:	75 8d                	jne    f01056b3 <readline+0x33>
			if (echoing)
f0105726:	85 ff                	test   %edi,%edi
f0105728:	74 0c                	je     f0105736 <readline+0xb6>
				cputchar('\n');
f010572a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105731:	e8 b7 b0 ff ff       	call   f01007ed <cputchar>
			buf[i] = 0;
f0105736:	c6 86 00 3b 22 f0 00 	movb   $0x0,-0xfddc500(%esi)
			return buf;
f010573d:	b8 00 3b 22 f0       	mov    $0xf0223b00,%eax
		}
	}
}
f0105742:	83 c4 1c             	add    $0x1c,%esp
f0105745:	5b                   	pop    %ebx
f0105746:	5e                   	pop    %esi
f0105747:	5f                   	pop    %edi
f0105748:	5d                   	pop    %ebp
f0105749:	c3                   	ret    
f010574a:	66 90                	xchg   %ax,%ax
f010574c:	66 90                	xchg   %ax,%ax
f010574e:	66 90                	xchg   %ax,%ax

f0105750 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105750:	55                   	push   %ebp
f0105751:	89 e5                	mov    %esp,%ebp
f0105753:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105756:	80 3a 00             	cmpb   $0x0,(%edx)
f0105759:	74 10                	je     f010576b <strlen+0x1b>
f010575b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105760:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105763:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105767:	75 f7                	jne    f0105760 <strlen+0x10>
f0105769:	eb 05                	jmp    f0105770 <strlen+0x20>
f010576b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105770:	5d                   	pop    %ebp
f0105771:	c3                   	ret    

f0105772 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105772:	55                   	push   %ebp
f0105773:	89 e5                	mov    %esp,%ebp
f0105775:	53                   	push   %ebx
f0105776:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105779:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010577c:	85 c9                	test   %ecx,%ecx
f010577e:	74 1c                	je     f010579c <strnlen+0x2a>
f0105780:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105783:	74 1e                	je     f01057a3 <strnlen+0x31>
f0105785:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010578a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010578c:	39 ca                	cmp    %ecx,%edx
f010578e:	74 18                	je     f01057a8 <strnlen+0x36>
f0105790:	83 c2 01             	add    $0x1,%edx
f0105793:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105798:	75 f0                	jne    f010578a <strnlen+0x18>
f010579a:	eb 0c                	jmp    f01057a8 <strnlen+0x36>
f010579c:	b8 00 00 00 00       	mov    $0x0,%eax
f01057a1:	eb 05                	jmp    f01057a8 <strnlen+0x36>
f01057a3:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01057a8:	5b                   	pop    %ebx
f01057a9:	5d                   	pop    %ebp
f01057aa:	c3                   	ret    

f01057ab <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01057ab:	55                   	push   %ebp
f01057ac:	89 e5                	mov    %esp,%ebp
f01057ae:	53                   	push   %ebx
f01057af:	8b 45 08             	mov    0x8(%ebp),%eax
f01057b2:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f01057b5:	89 c2                	mov    %eax,%edx
f01057b7:	83 c2 01             	add    $0x1,%edx
f01057ba:	83 c1 01             	add    $0x1,%ecx
f01057bd:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01057c1:	88 5a ff             	mov    %bl,-0x1(%edx)
f01057c4:	84 db                	test   %bl,%bl
f01057c6:	75 ef                	jne    f01057b7 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01057c8:	5b                   	pop    %ebx
f01057c9:	5d                   	pop    %ebp
f01057ca:	c3                   	ret    

f01057cb <strcat>:

char *
strcat(char *dst, const char *src)
{
f01057cb:	55                   	push   %ebp
f01057cc:	89 e5                	mov    %esp,%ebp
f01057ce:	53                   	push   %ebx
f01057cf:	83 ec 08             	sub    $0x8,%esp
f01057d2:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01057d5:	89 1c 24             	mov    %ebx,(%esp)
f01057d8:	e8 73 ff ff ff       	call   f0105750 <strlen>
	strcpy(dst + len, src);
f01057dd:	8b 55 0c             	mov    0xc(%ebp),%edx
f01057e0:	89 54 24 04          	mov    %edx,0x4(%esp)
f01057e4:	01 d8                	add    %ebx,%eax
f01057e6:	89 04 24             	mov    %eax,(%esp)
f01057e9:	e8 bd ff ff ff       	call   f01057ab <strcpy>
	return dst;
}
f01057ee:	89 d8                	mov    %ebx,%eax
f01057f0:	83 c4 08             	add    $0x8,%esp
f01057f3:	5b                   	pop    %ebx
f01057f4:	5d                   	pop    %ebp
f01057f5:	c3                   	ret    

f01057f6 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01057f6:	55                   	push   %ebp
f01057f7:	89 e5                	mov    %esp,%ebp
f01057f9:	56                   	push   %esi
f01057fa:	53                   	push   %ebx
f01057fb:	8b 75 08             	mov    0x8(%ebp),%esi
f01057fe:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105801:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105804:	85 db                	test   %ebx,%ebx
f0105806:	74 17                	je     f010581f <strncpy+0x29>
f0105808:	01 f3                	add    %esi,%ebx
f010580a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010580c:	83 c1 01             	add    $0x1,%ecx
f010580f:	0f b6 02             	movzbl (%edx),%eax
f0105812:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105815:	80 3a 01             	cmpb   $0x1,(%edx)
f0105818:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010581b:	39 d9                	cmp    %ebx,%ecx
f010581d:	75 ed                	jne    f010580c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010581f:	89 f0                	mov    %esi,%eax
f0105821:	5b                   	pop    %ebx
f0105822:	5e                   	pop    %esi
f0105823:	5d                   	pop    %ebp
f0105824:	c3                   	ret    

f0105825 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105825:	55                   	push   %ebp
f0105826:	89 e5                	mov    %esp,%ebp
f0105828:	57                   	push   %edi
f0105829:	56                   	push   %esi
f010582a:	53                   	push   %ebx
f010582b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010582e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105831:	8b 75 10             	mov    0x10(%ebp),%esi
f0105834:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105836:	85 f6                	test   %esi,%esi
f0105838:	74 34                	je     f010586e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010583a:	83 fe 01             	cmp    $0x1,%esi
f010583d:	74 26                	je     f0105865 <strlcpy+0x40>
f010583f:	0f b6 0b             	movzbl (%ebx),%ecx
f0105842:	84 c9                	test   %cl,%cl
f0105844:	74 23                	je     f0105869 <strlcpy+0x44>
f0105846:	83 ee 02             	sub    $0x2,%esi
f0105849:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f010584e:	83 c0 01             	add    $0x1,%eax
f0105851:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105854:	39 f2                	cmp    %esi,%edx
f0105856:	74 13                	je     f010586b <strlcpy+0x46>
f0105858:	83 c2 01             	add    $0x1,%edx
f010585b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f010585f:	84 c9                	test   %cl,%cl
f0105861:	75 eb                	jne    f010584e <strlcpy+0x29>
f0105863:	eb 06                	jmp    f010586b <strlcpy+0x46>
f0105865:	89 f8                	mov    %edi,%eax
f0105867:	eb 02                	jmp    f010586b <strlcpy+0x46>
f0105869:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f010586b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f010586e:	29 f8                	sub    %edi,%eax
}
f0105870:	5b                   	pop    %ebx
f0105871:	5e                   	pop    %esi
f0105872:	5f                   	pop    %edi
f0105873:	5d                   	pop    %ebp
f0105874:	c3                   	ret    

f0105875 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105875:	55                   	push   %ebp
f0105876:	89 e5                	mov    %esp,%ebp
f0105878:	8b 4d 08             	mov    0x8(%ebp),%ecx
f010587b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f010587e:	0f b6 01             	movzbl (%ecx),%eax
f0105881:	84 c0                	test   %al,%al
f0105883:	74 15                	je     f010589a <strcmp+0x25>
f0105885:	3a 02                	cmp    (%edx),%al
f0105887:	75 11                	jne    f010589a <strcmp+0x25>
		p++, q++;
f0105889:	83 c1 01             	add    $0x1,%ecx
f010588c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f010588f:	0f b6 01             	movzbl (%ecx),%eax
f0105892:	84 c0                	test   %al,%al
f0105894:	74 04                	je     f010589a <strcmp+0x25>
f0105896:	3a 02                	cmp    (%edx),%al
f0105898:	74 ef                	je     f0105889 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f010589a:	0f b6 c0             	movzbl %al,%eax
f010589d:	0f b6 12             	movzbl (%edx),%edx
f01058a0:	29 d0                	sub    %edx,%eax
}
f01058a2:	5d                   	pop    %ebp
f01058a3:	c3                   	ret    

f01058a4 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01058a4:	55                   	push   %ebp
f01058a5:	89 e5                	mov    %esp,%ebp
f01058a7:	56                   	push   %esi
f01058a8:	53                   	push   %ebx
f01058a9:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01058ac:	8b 55 0c             	mov    0xc(%ebp),%edx
f01058af:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f01058b2:	85 f6                	test   %esi,%esi
f01058b4:	74 29                	je     f01058df <strncmp+0x3b>
f01058b6:	0f b6 03             	movzbl (%ebx),%eax
f01058b9:	84 c0                	test   %al,%al
f01058bb:	74 30                	je     f01058ed <strncmp+0x49>
f01058bd:	3a 02                	cmp    (%edx),%al
f01058bf:	75 2c                	jne    f01058ed <strncmp+0x49>
f01058c1:	8d 43 01             	lea    0x1(%ebx),%eax
f01058c4:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f01058c6:	89 c3                	mov    %eax,%ebx
f01058c8:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f01058cb:	39 f0                	cmp    %esi,%eax
f01058cd:	74 17                	je     f01058e6 <strncmp+0x42>
f01058cf:	0f b6 08             	movzbl (%eax),%ecx
f01058d2:	84 c9                	test   %cl,%cl
f01058d4:	74 17                	je     f01058ed <strncmp+0x49>
f01058d6:	83 c0 01             	add    $0x1,%eax
f01058d9:	3a 0a                	cmp    (%edx),%cl
f01058db:	74 e9                	je     f01058c6 <strncmp+0x22>
f01058dd:	eb 0e                	jmp    f01058ed <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f01058df:	b8 00 00 00 00       	mov    $0x0,%eax
f01058e4:	eb 0f                	jmp    f01058f5 <strncmp+0x51>
f01058e6:	b8 00 00 00 00       	mov    $0x0,%eax
f01058eb:	eb 08                	jmp    f01058f5 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f01058ed:	0f b6 03             	movzbl (%ebx),%eax
f01058f0:	0f b6 12             	movzbl (%edx),%edx
f01058f3:	29 d0                	sub    %edx,%eax
}
f01058f5:	5b                   	pop    %ebx
f01058f6:	5e                   	pop    %esi
f01058f7:	5d                   	pop    %ebp
f01058f8:	c3                   	ret    

f01058f9 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f01058f9:	55                   	push   %ebp
f01058fa:	89 e5                	mov    %esp,%ebp
f01058fc:	53                   	push   %ebx
f01058fd:	8b 45 08             	mov    0x8(%ebp),%eax
f0105900:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105903:	0f b6 18             	movzbl (%eax),%ebx
f0105906:	84 db                	test   %bl,%bl
f0105908:	74 1d                	je     f0105927 <strchr+0x2e>
f010590a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010590c:	38 d3                	cmp    %dl,%bl
f010590e:	75 06                	jne    f0105916 <strchr+0x1d>
f0105910:	eb 1a                	jmp    f010592c <strchr+0x33>
f0105912:	38 ca                	cmp    %cl,%dl
f0105914:	74 16                	je     f010592c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105916:	83 c0 01             	add    $0x1,%eax
f0105919:	0f b6 10             	movzbl (%eax),%edx
f010591c:	84 d2                	test   %dl,%dl
f010591e:	75 f2                	jne    f0105912 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105920:	b8 00 00 00 00       	mov    $0x0,%eax
f0105925:	eb 05                	jmp    f010592c <strchr+0x33>
f0105927:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010592c:	5b                   	pop    %ebx
f010592d:	5d                   	pop    %ebp
f010592e:	c3                   	ret    

f010592f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010592f:	55                   	push   %ebp
f0105930:	89 e5                	mov    %esp,%ebp
f0105932:	53                   	push   %ebx
f0105933:	8b 45 08             	mov    0x8(%ebp),%eax
f0105936:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105939:	0f b6 18             	movzbl (%eax),%ebx
f010593c:	84 db                	test   %bl,%bl
f010593e:	74 16                	je     f0105956 <strfind+0x27>
f0105940:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105942:	38 d3                	cmp    %dl,%bl
f0105944:	75 06                	jne    f010594c <strfind+0x1d>
f0105946:	eb 0e                	jmp    f0105956 <strfind+0x27>
f0105948:	38 ca                	cmp    %cl,%dl
f010594a:	74 0a                	je     f0105956 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010594c:	83 c0 01             	add    $0x1,%eax
f010594f:	0f b6 10             	movzbl (%eax),%edx
f0105952:	84 d2                	test   %dl,%dl
f0105954:	75 f2                	jne    f0105948 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105956:	5b                   	pop    %ebx
f0105957:	5d                   	pop    %ebp
f0105958:	c3                   	ret    

f0105959 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105959:	55                   	push   %ebp
f010595a:	89 e5                	mov    %esp,%ebp
f010595c:	57                   	push   %edi
f010595d:	56                   	push   %esi
f010595e:	53                   	push   %ebx
f010595f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105962:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105965:	85 c9                	test   %ecx,%ecx
f0105967:	74 36                	je     f010599f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105969:	f7 c7 03 00 00 00    	test   $0x3,%edi
f010596f:	75 28                	jne    f0105999 <memset+0x40>
f0105971:	f6 c1 03             	test   $0x3,%cl
f0105974:	75 23                	jne    f0105999 <memset+0x40>
		c &= 0xFF;
f0105976:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f010597a:	89 d3                	mov    %edx,%ebx
f010597c:	c1 e3 08             	shl    $0x8,%ebx
f010597f:	89 d6                	mov    %edx,%esi
f0105981:	c1 e6 18             	shl    $0x18,%esi
f0105984:	89 d0                	mov    %edx,%eax
f0105986:	c1 e0 10             	shl    $0x10,%eax
f0105989:	09 f0                	or     %esi,%eax
f010598b:	09 c2                	or     %eax,%edx
f010598d:	89 d0                	mov    %edx,%eax
f010598f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105991:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105994:	fc                   	cld    
f0105995:	f3 ab                	rep stos %eax,%es:(%edi)
f0105997:	eb 06                	jmp    f010599f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105999:	8b 45 0c             	mov    0xc(%ebp),%eax
f010599c:	fc                   	cld    
f010599d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f010599f:	89 f8                	mov    %edi,%eax
f01059a1:	5b                   	pop    %ebx
f01059a2:	5e                   	pop    %esi
f01059a3:	5f                   	pop    %edi
f01059a4:	5d                   	pop    %ebp
f01059a5:	c3                   	ret    

f01059a6 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01059a6:	55                   	push   %ebp
f01059a7:	89 e5                	mov    %esp,%ebp
f01059a9:	57                   	push   %edi
f01059aa:	56                   	push   %esi
f01059ab:	8b 45 08             	mov    0x8(%ebp),%eax
f01059ae:	8b 75 0c             	mov    0xc(%ebp),%esi
f01059b1:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f01059b4:	39 c6                	cmp    %eax,%esi
f01059b6:	73 35                	jae    f01059ed <memmove+0x47>
f01059b8:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f01059bb:	39 d0                	cmp    %edx,%eax
f01059bd:	73 2e                	jae    f01059ed <memmove+0x47>
		s += n;
		d += n;
f01059bf:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f01059c2:	89 d6                	mov    %edx,%esi
f01059c4:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01059c6:	f7 c6 03 00 00 00    	test   $0x3,%esi
f01059cc:	75 13                	jne    f01059e1 <memmove+0x3b>
f01059ce:	f6 c1 03             	test   $0x3,%cl
f01059d1:	75 0e                	jne    f01059e1 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f01059d3:	83 ef 04             	sub    $0x4,%edi
f01059d6:	8d 72 fc             	lea    -0x4(%edx),%esi
f01059d9:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f01059dc:	fd                   	std    
f01059dd:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01059df:	eb 09                	jmp    f01059ea <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f01059e1:	83 ef 01             	sub    $0x1,%edi
f01059e4:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f01059e7:	fd                   	std    
f01059e8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f01059ea:	fc                   	cld    
f01059eb:	eb 1d                	jmp    f0105a0a <memmove+0x64>
f01059ed:	89 f2                	mov    %esi,%edx
f01059ef:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f01059f1:	f6 c2 03             	test   $0x3,%dl
f01059f4:	75 0f                	jne    f0105a05 <memmove+0x5f>
f01059f6:	f6 c1 03             	test   $0x3,%cl
f01059f9:	75 0a                	jne    f0105a05 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f01059fb:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f01059fe:	89 c7                	mov    %eax,%edi
f0105a00:	fc                   	cld    
f0105a01:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105a03:	eb 05                	jmp    f0105a0a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105a05:	89 c7                	mov    %eax,%edi
f0105a07:	fc                   	cld    
f0105a08:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105a0a:	5e                   	pop    %esi
f0105a0b:	5f                   	pop    %edi
f0105a0c:	5d                   	pop    %ebp
f0105a0d:	c3                   	ret    

f0105a0e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105a0e:	55                   	push   %ebp
f0105a0f:	89 e5                	mov    %esp,%ebp
f0105a11:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105a14:	8b 45 10             	mov    0x10(%ebp),%eax
f0105a17:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105a1b:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105a1e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105a22:	8b 45 08             	mov    0x8(%ebp),%eax
f0105a25:	89 04 24             	mov    %eax,(%esp)
f0105a28:	e8 79 ff ff ff       	call   f01059a6 <memmove>
}
f0105a2d:	c9                   	leave  
f0105a2e:	c3                   	ret    

f0105a2f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105a2f:	55                   	push   %ebp
f0105a30:	89 e5                	mov    %esp,%ebp
f0105a32:	57                   	push   %edi
f0105a33:	56                   	push   %esi
f0105a34:	53                   	push   %ebx
f0105a35:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105a38:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105a3b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105a3e:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105a41:	85 c0                	test   %eax,%eax
f0105a43:	74 36                	je     f0105a7b <memcmp+0x4c>
		if (*s1 != *s2)
f0105a45:	0f b6 03             	movzbl (%ebx),%eax
f0105a48:	0f b6 0e             	movzbl (%esi),%ecx
f0105a4b:	ba 00 00 00 00       	mov    $0x0,%edx
f0105a50:	38 c8                	cmp    %cl,%al
f0105a52:	74 1c                	je     f0105a70 <memcmp+0x41>
f0105a54:	eb 10                	jmp    f0105a66 <memcmp+0x37>
f0105a56:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105a5b:	83 c2 01             	add    $0x1,%edx
f0105a5e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0105a62:	38 c8                	cmp    %cl,%al
f0105a64:	74 0a                	je     f0105a70 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0105a66:	0f b6 c0             	movzbl %al,%eax
f0105a69:	0f b6 c9             	movzbl %cl,%ecx
f0105a6c:	29 c8                	sub    %ecx,%eax
f0105a6e:	eb 10                	jmp    f0105a80 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105a70:	39 fa                	cmp    %edi,%edx
f0105a72:	75 e2                	jne    f0105a56 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0105a74:	b8 00 00 00 00       	mov    $0x0,%eax
f0105a79:	eb 05                	jmp    f0105a80 <memcmp+0x51>
f0105a7b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105a80:	5b                   	pop    %ebx
f0105a81:	5e                   	pop    %esi
f0105a82:	5f                   	pop    %edi
f0105a83:	5d                   	pop    %ebp
f0105a84:	c3                   	ret    

f0105a85 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0105a85:	55                   	push   %ebp
f0105a86:	89 e5                	mov    %esp,%ebp
f0105a88:	53                   	push   %ebx
f0105a89:	8b 45 08             	mov    0x8(%ebp),%eax
f0105a8c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0105a8f:	89 c2                	mov    %eax,%edx
f0105a91:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105a94:	39 d0                	cmp    %edx,%eax
f0105a96:	73 13                	jae    f0105aab <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105a98:	89 d9                	mov    %ebx,%ecx
f0105a9a:	38 18                	cmp    %bl,(%eax)
f0105a9c:	75 06                	jne    f0105aa4 <memfind+0x1f>
f0105a9e:	eb 0b                	jmp    f0105aab <memfind+0x26>
f0105aa0:	38 08                	cmp    %cl,(%eax)
f0105aa2:	74 07                	je     f0105aab <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105aa4:	83 c0 01             	add    $0x1,%eax
f0105aa7:	39 d0                	cmp    %edx,%eax
f0105aa9:	75 f5                	jne    f0105aa0 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0105aab:	5b                   	pop    %ebx
f0105aac:	5d                   	pop    %ebp
f0105aad:	c3                   	ret    

f0105aae <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0105aae:	55                   	push   %ebp
f0105aaf:	89 e5                	mov    %esp,%ebp
f0105ab1:	57                   	push   %edi
f0105ab2:	56                   	push   %esi
f0105ab3:	53                   	push   %ebx
f0105ab4:	8b 55 08             	mov    0x8(%ebp),%edx
f0105ab7:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105aba:	0f b6 0a             	movzbl (%edx),%ecx
f0105abd:	80 f9 09             	cmp    $0x9,%cl
f0105ac0:	74 05                	je     f0105ac7 <strtol+0x19>
f0105ac2:	80 f9 20             	cmp    $0x20,%cl
f0105ac5:	75 10                	jne    f0105ad7 <strtol+0x29>
		s++;
f0105ac7:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105aca:	0f b6 0a             	movzbl (%edx),%ecx
f0105acd:	80 f9 09             	cmp    $0x9,%cl
f0105ad0:	74 f5                	je     f0105ac7 <strtol+0x19>
f0105ad2:	80 f9 20             	cmp    $0x20,%cl
f0105ad5:	74 f0                	je     f0105ac7 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105ad7:	80 f9 2b             	cmp    $0x2b,%cl
f0105ada:	75 0a                	jne    f0105ae6 <strtol+0x38>
		s++;
f0105adc:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0105adf:	bf 00 00 00 00       	mov    $0x0,%edi
f0105ae4:	eb 11                	jmp    f0105af7 <strtol+0x49>
f0105ae6:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0105aeb:	80 f9 2d             	cmp    $0x2d,%cl
f0105aee:	75 07                	jne    f0105af7 <strtol+0x49>
		s++, neg = 1;
f0105af0:	83 c2 01             	add    $0x1,%edx
f0105af3:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105af7:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0105afc:	75 15                	jne    f0105b13 <strtol+0x65>
f0105afe:	80 3a 30             	cmpb   $0x30,(%edx)
f0105b01:	75 10                	jne    f0105b13 <strtol+0x65>
f0105b03:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105b07:	75 0a                	jne    f0105b13 <strtol+0x65>
		s += 2, base = 16;
f0105b09:	83 c2 02             	add    $0x2,%edx
f0105b0c:	b8 10 00 00 00       	mov    $0x10,%eax
f0105b11:	eb 10                	jmp    f0105b23 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105b13:	85 c0                	test   %eax,%eax
f0105b15:	75 0c                	jne    f0105b23 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105b17:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105b19:	80 3a 30             	cmpb   $0x30,(%edx)
f0105b1c:	75 05                	jne    f0105b23 <strtol+0x75>
		s++, base = 8;
f0105b1e:	83 c2 01             	add    $0x1,%edx
f0105b21:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105b23:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105b28:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0105b2b:	0f b6 0a             	movzbl (%edx),%ecx
f0105b2e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0105b31:	89 f0                	mov    %esi,%eax
f0105b33:	3c 09                	cmp    $0x9,%al
f0105b35:	77 08                	ja     f0105b3f <strtol+0x91>
			dig = *s - '0';
f0105b37:	0f be c9             	movsbl %cl,%ecx
f0105b3a:	83 e9 30             	sub    $0x30,%ecx
f0105b3d:	eb 20                	jmp    f0105b5f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0105b3f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0105b42:	89 f0                	mov    %esi,%eax
f0105b44:	3c 19                	cmp    $0x19,%al
f0105b46:	77 08                	ja     f0105b50 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0105b48:	0f be c9             	movsbl %cl,%ecx
f0105b4b:	83 e9 57             	sub    $0x57,%ecx
f0105b4e:	eb 0f                	jmp    f0105b5f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0105b50:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0105b53:	89 f0                	mov    %esi,%eax
f0105b55:	3c 19                	cmp    $0x19,%al
f0105b57:	77 16                	ja     f0105b6f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0105b59:	0f be c9             	movsbl %cl,%ecx
f0105b5c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0105b5f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0105b62:	7d 0f                	jge    f0105b73 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0105b64:	83 c2 01             	add    $0x1,%edx
f0105b67:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0105b6b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0105b6d:	eb bc                	jmp    f0105b2b <strtol+0x7d>
f0105b6f:	89 d8                	mov    %ebx,%eax
f0105b71:	eb 02                	jmp    f0105b75 <strtol+0xc7>
f0105b73:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0105b75:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0105b79:	74 05                	je     f0105b80 <strtol+0xd2>
		*endptr = (char *) s;
f0105b7b:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105b7e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0105b80:	f7 d8                	neg    %eax
f0105b82:	85 ff                	test   %edi,%edi
f0105b84:	0f 44 c3             	cmove  %ebx,%eax
}
f0105b87:	5b                   	pop    %ebx
f0105b88:	5e                   	pop    %esi
f0105b89:	5f                   	pop    %edi
f0105b8a:	5d                   	pop    %ebp
f0105b8b:	c3                   	ret    

f0105b8c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f0105b8c:	fa                   	cli    

	xorw    %ax, %ax
f0105b8d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f0105b8f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105b91:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105b93:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0105b95:	0f 01 16             	lgdtl  (%esi)
f0105b98:	74 70                	je     f0105c0a <mpentry_end+0x4>
	movl    %cr0, %eax
f0105b9a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f0105b9d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0105ba1:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0105ba4:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f0105baa:	08 00                	or     %al,(%eax)

f0105bac <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f0105bac:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0105bb0:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105bb2:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105bb4:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0105bb6:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f0105bba:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f0105bbc:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f0105bbe:	b8 00 e0 11 00       	mov    $0x11e000,%eax
	movl    %eax, %cr3
f0105bc3:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0105bc6:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0105bc9:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f0105bce:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0105bd1:	8b 25 04 3f 22 f0    	mov    0xf0223f04,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0105bd7:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f0105bdc:	b8 48 02 10 f0       	mov    $0xf0100248,%eax
	call    *%eax
f0105be1:	ff d0                	call   *%eax

f0105be3 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0105be3:	eb fe                	jmp    f0105be3 <spin>
f0105be5:	8d 76 00             	lea    0x0(%esi),%esi

f0105be8 <gdt>:
	...
f0105bf0:	ff                   	(bad)  
f0105bf1:	ff 00                	incl   (%eax)
f0105bf3:	00 00                	add    %al,(%eax)
f0105bf5:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f0105bfc:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0105c00 <gdtdesc>:
f0105c00:	17                   	pop    %ss
f0105c01:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0105c06 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0105c06:	90                   	nop
f0105c07:	66 90                	xchg   %ax,%ax
f0105c09:	66 90                	xchg   %ax,%ax
f0105c0b:	66 90                	xchg   %ax,%ax
f0105c0d:	66 90                	xchg   %ax,%ax
f0105c0f:	90                   	nop

f0105c10 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0105c10:	55                   	push   %ebp
f0105c11:	89 e5                	mov    %esp,%ebp
f0105c13:	56                   	push   %esi
f0105c14:	53                   	push   %ebx
f0105c15:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105c18:	8b 0d 08 3f 22 f0    	mov    0xf0223f08,%ecx
f0105c1e:	89 c3                	mov    %eax,%ebx
f0105c20:	c1 eb 0c             	shr    $0xc,%ebx
f0105c23:	39 cb                	cmp    %ecx,%ebx
f0105c25:	72 20                	jb     f0105c47 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105c27:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105c2b:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0105c32:	f0 
f0105c33:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105c3a:	00 
f0105c3b:	c7 04 24 81 81 10 f0 	movl   $0xf0108181,(%esp)
f0105c42:	e8 f9 a3 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105c47:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f0105c4d:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105c4f:	89 c2                	mov    %eax,%edx
f0105c51:	c1 ea 0c             	shr    $0xc,%edx
f0105c54:	39 d1                	cmp    %edx,%ecx
f0105c56:	77 20                	ja     f0105c78 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105c58:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105c5c:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0105c63:	f0 
f0105c64:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105c6b:	00 
f0105c6c:	c7 04 24 81 81 10 f0 	movl   $0xf0108181,(%esp)
f0105c73:	e8 c8 a3 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105c78:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f0105c7e:	39 f3                	cmp    %esi,%ebx
f0105c80:	73 40                	jae    f0105cc2 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105c82:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105c89:	00 
f0105c8a:	c7 44 24 04 91 81 10 	movl   $0xf0108191,0x4(%esp)
f0105c91:	f0 
f0105c92:	89 1c 24             	mov    %ebx,(%esp)
f0105c95:	e8 95 fd ff ff       	call   f0105a2f <memcmp>
f0105c9a:	85 c0                	test   %eax,%eax
f0105c9c:	75 17                	jne    f0105cb5 <mpsearch1+0xa5>
f0105c9e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0105ca3:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0105ca7:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105ca9:	83 c0 01             	add    $0x1,%eax
f0105cac:	83 f8 10             	cmp    $0x10,%eax
f0105caf:	75 f2                	jne    f0105ca3 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105cb1:	84 d2                	test   %dl,%dl
f0105cb3:	74 14                	je     f0105cc9 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0105cb5:	83 c3 10             	add    $0x10,%ebx
f0105cb8:	39 f3                	cmp    %esi,%ebx
f0105cba:	72 c6                	jb     f0105c82 <mpsearch1+0x72>
f0105cbc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105cc0:	eb 0b                	jmp    f0105ccd <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0105cc2:	b8 00 00 00 00       	mov    $0x0,%eax
f0105cc7:	eb 09                	jmp    f0105cd2 <mpsearch1+0xc2>
f0105cc9:	89 d8                	mov    %ebx,%eax
f0105ccb:	eb 05                	jmp    f0105cd2 <mpsearch1+0xc2>
f0105ccd:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105cd2:	83 c4 10             	add    $0x10,%esp
f0105cd5:	5b                   	pop    %ebx
f0105cd6:	5e                   	pop    %esi
f0105cd7:	5d                   	pop    %ebp
f0105cd8:	c3                   	ret    

f0105cd9 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0105cd9:	55                   	push   %ebp
f0105cda:	89 e5                	mov    %esp,%ebp
f0105cdc:	57                   	push   %edi
f0105cdd:	56                   	push   %esi
f0105cde:	53                   	push   %ebx
f0105cdf:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0105ce2:	c7 05 c0 43 22 f0 20 	movl   $0xf0224020,0xf02243c0
f0105ce9:	40 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105cec:	83 3d 08 3f 22 f0 00 	cmpl   $0x0,0xf0223f08
f0105cf3:	75 24                	jne    f0105d19 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105cf5:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0105cfc:	00 
f0105cfd:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0105d04:	f0 
f0105d05:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0105d0c:	00 
f0105d0d:	c7 04 24 81 81 10 f0 	movl   $0xf0108181,(%esp)
f0105d14:	e8 27 a3 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0105d19:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0105d20:	85 c0                	test   %eax,%eax
f0105d22:	74 16                	je     f0105d3a <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0105d24:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0105d27:	ba 00 04 00 00       	mov    $0x400,%edx
f0105d2c:	e8 df fe ff ff       	call   f0105c10 <mpsearch1>
f0105d31:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105d34:	85 c0                	test   %eax,%eax
f0105d36:	75 3c                	jne    f0105d74 <mp_init+0x9b>
f0105d38:	eb 20                	jmp    f0105d5a <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0105d3a:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0105d41:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0105d44:	2d 00 04 00 00       	sub    $0x400,%eax
f0105d49:	ba 00 04 00 00       	mov    $0x400,%edx
f0105d4e:	e8 bd fe ff ff       	call   f0105c10 <mpsearch1>
f0105d53:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105d56:	85 c0                	test   %eax,%eax
f0105d58:	75 1a                	jne    f0105d74 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0105d5a:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105d5f:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0105d64:	e8 a7 fe ff ff       	call   f0105c10 <mpsearch1>
f0105d69:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0105d6c:	85 c0                	test   %eax,%eax
f0105d6e:	0f 84 5f 02 00 00    	je     f0105fd3 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0105d74:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105d77:	8b 70 04             	mov    0x4(%eax),%esi
f0105d7a:	85 f6                	test   %esi,%esi
f0105d7c:	74 06                	je     f0105d84 <mp_init+0xab>
f0105d7e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0105d82:	74 11                	je     f0105d95 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0105d84:	c7 04 24 f4 7f 10 f0 	movl   $0xf0107ff4,(%esp)
f0105d8b:	e8 e9 e3 ff ff       	call   f0104179 <cprintf>
f0105d90:	e9 3e 02 00 00       	jmp    f0105fd3 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105d95:	89 f0                	mov    %esi,%eax
f0105d97:	c1 e8 0c             	shr    $0xc,%eax
f0105d9a:	3b 05 08 3f 22 f0    	cmp    0xf0223f08,%eax
f0105da0:	72 20                	jb     f0105dc2 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105da2:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105da6:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f0105dad:	f0 
f0105dae:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0105db5:	00 
f0105db6:	c7 04 24 81 81 10 f0 	movl   $0xf0108181,(%esp)
f0105dbd:	e8 7e a2 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105dc2:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0105dc8:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105dcf:	00 
f0105dd0:	c7 44 24 04 96 81 10 	movl   $0xf0108196,0x4(%esp)
f0105dd7:	f0 
f0105dd8:	89 1c 24             	mov    %ebx,(%esp)
f0105ddb:	e8 4f fc ff ff       	call   f0105a2f <memcmp>
f0105de0:	85 c0                	test   %eax,%eax
f0105de2:	74 11                	je     f0105df5 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0105de4:	c7 04 24 24 80 10 f0 	movl   $0xf0108024,(%esp)
f0105deb:	e8 89 e3 ff ff       	call   f0104179 <cprintf>
f0105df0:	e9 de 01 00 00       	jmp    f0105fd3 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105df5:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0105df9:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0105dfd:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e00:	85 ff                	test   %edi,%edi
f0105e02:	7e 30                	jle    f0105e34 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105e04:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105e09:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105e0e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0105e15:	f0 
f0105e16:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e18:	83 c0 01             	add    $0x1,%eax
f0105e1b:	39 c7                	cmp    %eax,%edi
f0105e1d:	7f ef                	jg     f0105e0e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105e1f:	84 d2                	test   %dl,%dl
f0105e21:	74 11                	je     f0105e34 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0105e23:	c7 04 24 58 80 10 f0 	movl   $0xf0108058,(%esp)
f0105e2a:	e8 4a e3 ff ff       	call   f0104179 <cprintf>
f0105e2f:	e9 9f 01 00 00       	jmp    f0105fd3 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0105e34:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0105e38:	3c 04                	cmp    $0x4,%al
f0105e3a:	74 1e                	je     f0105e5a <mp_init+0x181>
f0105e3c:	3c 01                	cmp    $0x1,%al
f0105e3e:	66 90                	xchg   %ax,%ax
f0105e40:	74 18                	je     f0105e5a <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0105e42:	0f b6 c0             	movzbl %al,%eax
f0105e45:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105e49:	c7 04 24 7c 80 10 f0 	movl   $0xf010807c,(%esp)
f0105e50:	e8 24 e3 ff ff       	call   f0104179 <cprintf>
f0105e55:	e9 79 01 00 00       	jmp    f0105fd3 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105e5a:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0105e5e:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0105e62:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e64:	85 f6                	test   %esi,%esi
f0105e66:	7e 19                	jle    f0105e81 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105e68:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105e6d:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105e72:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0105e76:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e78:	83 c0 01             	add    $0x1,%eax
f0105e7b:	39 c6                	cmp    %eax,%esi
f0105e7d:	7f f3                	jg     f0105e72 <mp_init+0x199>
f0105e7f:	eb 05                	jmp    f0105e86 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105e81:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105e86:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0105e89:	74 11                	je     f0105e9c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0105e8b:	c7 04 24 9c 80 10 f0 	movl   $0xf010809c,(%esp)
f0105e92:	e8 e2 e2 ff ff       	call   f0104179 <cprintf>
f0105e97:	e9 37 01 00 00       	jmp    f0105fd3 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0105e9c:	85 db                	test   %ebx,%ebx
f0105e9e:	0f 84 2f 01 00 00    	je     f0105fd3 <mp_init+0x2fa>
		return;
	ismp = 1;
f0105ea4:	c7 05 00 40 22 f0 01 	movl   $0x1,0xf0224000
f0105eab:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0105eae:	8b 43 24             	mov    0x24(%ebx),%eax
f0105eb1:	a3 00 50 26 f0       	mov    %eax,0xf0265000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105eb6:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0105eb9:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0105ebe:	0f 84 94 00 00 00    	je     f0105f58 <mp_init+0x27f>
f0105ec4:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0105ec9:	0f b6 07             	movzbl (%edi),%eax
f0105ecc:	84 c0                	test   %al,%al
f0105ece:	74 06                	je     f0105ed6 <mp_init+0x1fd>
f0105ed0:	3c 04                	cmp    $0x4,%al
f0105ed2:	77 54                	ja     f0105f28 <mp_init+0x24f>
f0105ed4:	eb 4d                	jmp    f0105f23 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0105ed6:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0105eda:	74 11                	je     f0105eed <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0105edc:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f0105ee3:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0105ee8:	a3 c0 43 22 f0       	mov    %eax,0xf02243c0
			if (ncpu < NCPU) {
f0105eed:	a1 c4 43 22 f0       	mov    0xf02243c4,%eax
f0105ef2:	83 f8 07             	cmp    $0x7,%eax
f0105ef5:	7f 13                	jg     f0105f0a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0105ef7:	6b d0 74             	imul   $0x74,%eax,%edx
f0105efa:	88 82 20 40 22 f0    	mov    %al,-0xfddbfe0(%edx)
				ncpu++;
f0105f00:	83 c0 01             	add    $0x1,%eax
f0105f03:	a3 c4 43 22 f0       	mov    %eax,0xf02243c4
f0105f08:	eb 14                	jmp    f0105f1e <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0105f0a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0105f0e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105f12:	c7 04 24 cc 80 10 f0 	movl   $0xf01080cc,(%esp)
f0105f19:	e8 5b e2 ff ff       	call   f0104179 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0105f1e:	83 c7 14             	add    $0x14,%edi
			continue;
f0105f21:	eb 26                	jmp    f0105f49 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0105f23:	83 c7 08             	add    $0x8,%edi
			continue;
f0105f26:	eb 21                	jmp    f0105f49 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0105f28:	0f b6 c0             	movzbl %al,%eax
f0105f2b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105f2f:	c7 04 24 f4 80 10 f0 	movl   $0xf01080f4,(%esp)
f0105f36:	e8 3e e2 ff ff       	call   f0104179 <cprintf>
			ismp = 0;
f0105f3b:	c7 05 00 40 22 f0 00 	movl   $0x0,0xf0224000
f0105f42:	00 00 00 
			i = conf->entry;
f0105f45:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105f49:	83 c6 01             	add    $0x1,%esi
f0105f4c:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0105f50:	39 f0                	cmp    %esi,%eax
f0105f52:	0f 87 71 ff ff ff    	ja     f0105ec9 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0105f58:	a1 c0 43 22 f0       	mov    0xf02243c0,%eax
f0105f5d:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0105f64:	83 3d 00 40 22 f0 00 	cmpl   $0x0,0xf0224000
f0105f6b:	75 22                	jne    f0105f8f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0105f6d:	c7 05 c4 43 22 f0 01 	movl   $0x1,0xf02243c4
f0105f74:	00 00 00 
		lapic = NULL;
f0105f77:	c7 05 00 50 26 f0 00 	movl   $0x0,0xf0265000
f0105f7e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0105f81:	c7 04 24 14 81 10 f0 	movl   $0xf0108114,(%esp)
f0105f88:	e8 ec e1 ff ff       	call   f0104179 <cprintf>
		return;
f0105f8d:	eb 44                	jmp    f0105fd3 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0105f8f:	8b 15 c4 43 22 f0    	mov    0xf02243c4,%edx
f0105f95:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105f99:	0f b6 00             	movzbl (%eax),%eax
f0105f9c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105fa0:	c7 04 24 9b 81 10 f0 	movl   $0xf010819b,(%esp)
f0105fa7:	e8 cd e1 ff ff       	call   f0104179 <cprintf>

	if (mp->imcrp) {
f0105fac:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105faf:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0105fb3:	74 1e                	je     f0105fd3 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0105fb5:	c7 04 24 40 81 10 f0 	movl   $0xf0108140,(%esp)
f0105fbc:	e8 b8 e1 ff ff       	call   f0104179 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105fc1:	ba 22 00 00 00       	mov    $0x22,%edx
f0105fc6:	b8 70 00 00 00       	mov    $0x70,%eax
f0105fcb:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0105fcc:	b2 23                	mov    $0x23,%dl
f0105fce:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f0105fcf:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0105fd2:	ee                   	out    %al,(%dx)
	}
}
f0105fd3:	83 c4 2c             	add    $0x2c,%esp
f0105fd6:	5b                   	pop    %ebx
f0105fd7:	5e                   	pop    %esi
f0105fd8:	5f                   	pop    %edi
f0105fd9:	5d                   	pop    %ebp
f0105fda:	c3                   	ret    

f0105fdb <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f0105fdb:	55                   	push   %ebp
f0105fdc:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f0105fde:	8b 0d 00 50 26 f0    	mov    0xf0265000,%ecx
f0105fe4:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0105fe7:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0105fe9:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105fee:	8b 40 20             	mov    0x20(%eax),%eax
}
f0105ff1:	5d                   	pop    %ebp
f0105ff2:	c3                   	ret    

f0105ff3 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0105ff3:	55                   	push   %ebp
f0105ff4:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0105ff6:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0105ffb:	85 c0                	test   %eax,%eax
f0105ffd:	74 08                	je     f0106007 <cpunum+0x14>
		return lapic[ID] >> 24;
f0105fff:	8b 40 20             	mov    0x20(%eax),%eax
f0106002:	c1 e8 18             	shr    $0x18,%eax
f0106005:	eb 05                	jmp    f010600c <cpunum+0x19>
	return 0;
f0106007:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010600c:	5d                   	pop    %ebp
f010600d:	c3                   	ret    

f010600e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f010600e:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f0106015:	0f 84 0b 01 00 00    	je     f0106126 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f010601b:	55                   	push   %ebp
f010601c:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f010601e:	ba 27 01 00 00       	mov    $0x127,%edx
f0106023:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0106028:	e8 ae ff ff ff       	call   f0105fdb <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f010602d:	ba 0b 00 00 00       	mov    $0xb,%edx
f0106032:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0106037:	e8 9f ff ff ff       	call   f0105fdb <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f010603c:	ba 20 00 02 00       	mov    $0x20020,%edx
f0106041:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0106046:	e8 90 ff ff ff       	call   f0105fdb <lapicw>
	lapicw(TICR, 10000000); 
f010604b:	ba 80 96 98 00       	mov    $0x989680,%edx
f0106050:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0106055:	e8 81 ff ff ff       	call   f0105fdb <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f010605a:	e8 94 ff ff ff       	call   f0105ff3 <cpunum>
f010605f:	6b c0 74             	imul   $0x74,%eax,%eax
f0106062:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0106067:	39 05 c0 43 22 f0    	cmp    %eax,0xf02243c0
f010606d:	74 0f                	je     f010607e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f010606f:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106074:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106079:	e8 5d ff ff ff       	call   f0105fdb <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010607e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106083:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106088:	e8 4e ff ff ff       	call   f0105fdb <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010608d:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f0106092:	8b 40 30             	mov    0x30(%eax),%eax
f0106095:	c1 e8 10             	shr    $0x10,%eax
f0106098:	3c 03                	cmp    $0x3,%al
f010609a:	76 0f                	jbe    f01060ab <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010609c:	ba 00 00 01 00       	mov    $0x10000,%edx
f01060a1:	b8 d0 00 00 00       	mov    $0xd0,%eax
f01060a6:	e8 30 ff ff ff       	call   f0105fdb <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f01060ab:	ba 33 00 00 00       	mov    $0x33,%edx
f01060b0:	b8 dc 00 00 00       	mov    $0xdc,%eax
f01060b5:	e8 21 ff ff ff       	call   f0105fdb <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f01060ba:	ba 00 00 00 00       	mov    $0x0,%edx
f01060bf:	b8 a0 00 00 00       	mov    $0xa0,%eax
f01060c4:	e8 12 ff ff ff       	call   f0105fdb <lapicw>
	lapicw(ESR, 0);
f01060c9:	ba 00 00 00 00       	mov    $0x0,%edx
f01060ce:	b8 a0 00 00 00       	mov    $0xa0,%eax
f01060d3:	e8 03 ff ff ff       	call   f0105fdb <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f01060d8:	ba 00 00 00 00       	mov    $0x0,%edx
f01060dd:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01060e2:	e8 f4 fe ff ff       	call   f0105fdb <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f01060e7:	ba 00 00 00 00       	mov    $0x0,%edx
f01060ec:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01060f1:	e8 e5 fe ff ff       	call   f0105fdb <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f01060f6:	ba 00 85 08 00       	mov    $0x88500,%edx
f01060fb:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106100:	e8 d6 fe ff ff       	call   f0105fdb <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0106105:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f010610b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0106111:	f6 c4 10             	test   $0x10,%ah
f0106114:	75 f5                	jne    f010610b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f0106116:	ba 00 00 00 00       	mov    $0x0,%edx
f010611b:	b8 20 00 00 00       	mov    $0x20,%eax
f0106120:	e8 b6 fe ff ff       	call   f0105fdb <lapicw>
}
f0106125:	5d                   	pop    %ebp
f0106126:	f3 c3                	repz ret 

f0106128 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0106128:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f010612f:	74 13                	je     f0106144 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0106131:	55                   	push   %ebp
f0106132:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0106134:	ba 00 00 00 00       	mov    $0x0,%edx
f0106139:	b8 2c 00 00 00       	mov    $0x2c,%eax
f010613e:	e8 98 fe ff ff       	call   f0105fdb <lapicw>
}
f0106143:	5d                   	pop    %ebp
f0106144:	f3 c3                	repz ret 

f0106146 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0106146:	55                   	push   %ebp
f0106147:	89 e5                	mov    %esp,%ebp
f0106149:	56                   	push   %esi
f010614a:	53                   	push   %ebx
f010614b:	83 ec 10             	sub    $0x10,%esp
f010614e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0106151:	8b 75 0c             	mov    0xc(%ebp),%esi
f0106154:	ba 70 00 00 00       	mov    $0x70,%edx
f0106159:	b8 0f 00 00 00       	mov    $0xf,%eax
f010615e:	ee                   	out    %al,(%dx)
f010615f:	b2 71                	mov    $0x71,%dl
f0106161:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106166:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106167:	83 3d 08 3f 22 f0 00 	cmpl   $0x0,0xf0223f08
f010616e:	75 24                	jne    f0106194 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106170:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106177:	00 
f0106178:	c7 44 24 08 24 67 10 	movl   $0xf0106724,0x8(%esp)
f010617f:	f0 
f0106180:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106187:	00 
f0106188:	c7 04 24 b8 81 10 f0 	movl   $0xf01081b8,(%esp)
f010618f:	e8 ac 9e ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106194:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010619b:	00 00 
	wrv[1] = addr >> 4;
f010619d:	89 f0                	mov    %esi,%eax
f010619f:	c1 e8 04             	shr    $0x4,%eax
f01061a2:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f01061a8:	c1 e3 18             	shl    $0x18,%ebx
f01061ab:	89 da                	mov    %ebx,%edx
f01061ad:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01061b2:	e8 24 fe ff ff       	call   f0105fdb <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f01061b7:	ba 00 c5 00 00       	mov    $0xc500,%edx
f01061bc:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01061c1:	e8 15 fe ff ff       	call   f0105fdb <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f01061c6:	ba 00 85 00 00       	mov    $0x8500,%edx
f01061cb:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01061d0:	e8 06 fe ff ff       	call   f0105fdb <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01061d5:	c1 ee 0c             	shr    $0xc,%esi
f01061d8:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f01061de:	89 da                	mov    %ebx,%edx
f01061e0:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01061e5:	e8 f1 fd ff ff       	call   f0105fdb <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01061ea:	89 f2                	mov    %esi,%edx
f01061ec:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01061f1:	e8 e5 fd ff ff       	call   f0105fdb <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f01061f6:	89 da                	mov    %ebx,%edx
f01061f8:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01061fd:	e8 d9 fd ff ff       	call   f0105fdb <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106202:	89 f2                	mov    %esi,%edx
f0106204:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106209:	e8 cd fd ff ff       	call   f0105fdb <lapicw>
		microdelay(200);
	}
}
f010620e:	83 c4 10             	add    $0x10,%esp
f0106211:	5b                   	pop    %ebx
f0106212:	5e                   	pop    %esi
f0106213:	5d                   	pop    %ebp
f0106214:	c3                   	ret    

f0106215 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0106215:	55                   	push   %ebp
f0106216:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0106218:	8b 55 08             	mov    0x8(%ebp),%edx
f010621b:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0106221:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106226:	e8 b0 fd ff ff       	call   f0105fdb <lapicw>
	while (lapic[ICRLO] & DELIVS)
f010622b:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f0106231:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0106237:	f6 c4 10             	test   $0x10,%ah
f010623a:	75 f5                	jne    f0106231 <lapic_ipi+0x1c>
		;
}
f010623c:	5d                   	pop    %ebp
f010623d:	c3                   	ret    

f010623e <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f010623e:	55                   	push   %ebp
f010623f:	89 e5                	mov    %esp,%ebp
f0106241:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0106244:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f010624a:	8b 55 0c             	mov    0xc(%ebp),%edx
f010624d:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0106250:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0106257:	5d                   	pop    %ebp
f0106258:	c3                   	ret    

f0106259 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0106259:	55                   	push   %ebp
f010625a:	89 e5                	mov    %esp,%ebp
f010625c:	56                   	push   %esi
f010625d:	53                   	push   %ebx
f010625e:	83 ec 20             	sub    $0x20,%esp
f0106261:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106264:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106267:	74 14                	je     f010627d <spin_lock+0x24>
f0106269:	8b 73 08             	mov    0x8(%ebx),%esi
f010626c:	e8 82 fd ff ff       	call   f0105ff3 <cpunum>
f0106271:	6b c0 74             	imul   $0x74,%eax,%eax
f0106274:	05 20 40 22 f0       	add    $0xf0224020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106279:	39 c6                	cmp    %eax,%esi
f010627b:	74 15                	je     f0106292 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010627d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010627f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106284:	f0 87 03             	lock xchg %eax,(%ebx)
f0106287:	b9 01 00 00 00       	mov    $0x1,%ecx
f010628c:	85 c0                	test   %eax,%eax
f010628e:	75 2e                	jne    f01062be <spin_lock+0x65>
f0106290:	eb 37                	jmp    f01062c9 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106292:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106295:	e8 59 fd ff ff       	call   f0105ff3 <cpunum>
f010629a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010629e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01062a2:	c7 44 24 08 c8 81 10 	movl   $0xf01081c8,0x8(%esp)
f01062a9:	f0 
f01062aa:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f01062b1:	00 
f01062b2:	c7 04 24 2c 82 10 f0 	movl   $0xf010822c,(%esp)
f01062b9:	e8 82 9d ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f01062be:	f3 90                	pause  
f01062c0:	89 c8                	mov    %ecx,%eax
f01062c2:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f01062c5:	85 c0                	test   %eax,%eax
f01062c7:	75 f5                	jne    f01062be <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f01062c9:	e8 25 fd ff ff       	call   f0105ff3 <cpunum>
f01062ce:	6b c0 74             	imul   $0x74,%eax,%eax
f01062d1:	05 20 40 22 f0       	add    $0xf0224020,%eax
f01062d6:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f01062d9:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f01062dc:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f01062de:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01062e4:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f01062ea:	76 3a                	jbe    f0106326 <spin_lock+0xcd>
f01062ec:	eb 31                	jmp    f010631f <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f01062ee:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01062f4:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f01062fa:	77 12                	ja     f010630e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01062fc:	8b 5a 04             	mov    0x4(%edx),%ebx
f01062ff:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0106302:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0106304:	83 c0 01             	add    $0x1,%eax
f0106307:	83 f8 0a             	cmp    $0xa,%eax
f010630a:	75 e2                	jne    f01062ee <spin_lock+0x95>
f010630c:	eb 27                	jmp    f0106335 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f010630e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0106315:	83 c0 01             	add    $0x1,%eax
f0106318:	83 f8 09             	cmp    $0x9,%eax
f010631b:	7e f1                	jle    f010630e <spin_lock+0xb5>
f010631d:	eb 16                	jmp    f0106335 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010631f:	b8 00 00 00 00       	mov    $0x0,%eax
f0106324:	eb e8                	jmp    f010630e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0106326:	8b 50 04             	mov    0x4(%eax),%edx
f0106329:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f010632c:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010632e:	b8 01 00 00 00       	mov    $0x1,%eax
f0106333:	eb b9                	jmp    f01062ee <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0106335:	83 c4 20             	add    $0x20,%esp
f0106338:	5b                   	pop    %ebx
f0106339:	5e                   	pop    %esi
f010633a:	5d                   	pop    %ebp
f010633b:	c3                   	ret    

f010633c <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f010633c:	55                   	push   %ebp
f010633d:	89 e5                	mov    %esp,%ebp
f010633f:	57                   	push   %edi
f0106340:	56                   	push   %esi
f0106341:	53                   	push   %ebx
f0106342:	83 ec 6c             	sub    $0x6c,%esp
f0106345:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106348:	83 3b 00             	cmpl   $0x0,(%ebx)
f010634b:	74 18                	je     f0106365 <spin_unlock+0x29>
f010634d:	8b 73 08             	mov    0x8(%ebx),%esi
f0106350:	e8 9e fc ff ff       	call   f0105ff3 <cpunum>
f0106355:	6b c0 74             	imul   $0x74,%eax,%eax
f0106358:	05 20 40 22 f0       	add    $0xf0224020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f010635d:	39 c6                	cmp    %eax,%esi
f010635f:	0f 84 d4 00 00 00    	je     f0106439 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106365:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f010636c:	00 
f010636d:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106370:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106374:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106377:	89 04 24             	mov    %eax,(%esp)
f010637a:	e8 27 f6 ff ff       	call   f01059a6 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010637f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106382:	0f b6 30             	movzbl (%eax),%esi
f0106385:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106388:	e8 66 fc ff ff       	call   f0105ff3 <cpunum>
f010638d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106391:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106395:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106399:	c7 04 24 f4 81 10 f0 	movl   $0xf01081f4,(%esp)
f01063a0:	e8 d4 dd ff ff       	call   f0104179 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01063a5:	8b 45 c0             	mov    -0x40(%ebp),%eax
f01063a8:	85 c0                	test   %eax,%eax
f01063aa:	74 71                	je     f010641d <spin_unlock+0xe1>
f01063ac:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f01063af:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f01063b2:	8d 75 a8             	lea    -0x58(%ebp),%esi
f01063b5:	89 74 24 04          	mov    %esi,0x4(%esp)
f01063b9:	89 04 24             	mov    %eax,(%esp)
f01063bc:	e8 8b e9 ff ff       	call   f0104d4c <debuginfo_eip>
f01063c1:	85 c0                	test   %eax,%eax
f01063c3:	78 39                	js     f01063fe <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f01063c5:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f01063c7:	89 c2                	mov    %eax,%edx
f01063c9:	2b 55 b8             	sub    -0x48(%ebp),%edx
f01063cc:	89 54 24 18          	mov    %edx,0x18(%esp)
f01063d0:	8b 55 b0             	mov    -0x50(%ebp),%edx
f01063d3:	89 54 24 14          	mov    %edx,0x14(%esp)
f01063d7:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f01063da:	89 54 24 10          	mov    %edx,0x10(%esp)
f01063de:	8b 55 ac             	mov    -0x54(%ebp),%edx
f01063e1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01063e5:	8b 55 a8             	mov    -0x58(%ebp),%edx
f01063e8:	89 54 24 08          	mov    %edx,0x8(%esp)
f01063ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063f0:	c7 04 24 3c 82 10 f0 	movl   $0xf010823c,(%esp)
f01063f7:	e8 7d dd ff ff       	call   f0104179 <cprintf>
f01063fc:	eb 12                	jmp    f0106410 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f01063fe:	8b 03                	mov    (%ebx),%eax
f0106400:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106404:	c7 04 24 53 82 10 f0 	movl   $0xf0108253,(%esp)
f010640b:	e8 69 dd ff ff       	call   f0104179 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106410:	39 fb                	cmp    %edi,%ebx
f0106412:	74 09                	je     f010641d <spin_unlock+0xe1>
f0106414:	83 c3 04             	add    $0x4,%ebx
f0106417:	8b 03                	mov    (%ebx),%eax
f0106419:	85 c0                	test   %eax,%eax
f010641b:	75 98                	jne    f01063b5 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f010641d:	c7 44 24 08 5b 82 10 	movl   $0xf010825b,0x8(%esp)
f0106424:	f0 
f0106425:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f010642c:	00 
f010642d:	c7 04 24 2c 82 10 f0 	movl   $0xf010822c,(%esp)
f0106434:	e8 07 9c ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f0106439:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f0106440:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0106447:	b8 00 00 00 00       	mov    $0x0,%eax
f010644c:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f010644f:	83 c4 6c             	add    $0x6c,%esp
f0106452:	5b                   	pop    %ebx
f0106453:	5e                   	pop    %esi
f0106454:	5f                   	pop    %edi
f0106455:	5d                   	pop    %ebp
f0106456:	c3                   	ret    
f0106457:	66 90                	xchg   %ax,%ax
f0106459:	66 90                	xchg   %ax,%ax
f010645b:	66 90                	xchg   %ax,%ax
f010645d:	66 90                	xchg   %ax,%ax
f010645f:	90                   	nop

f0106460 <__udivdi3>:
f0106460:	55                   	push   %ebp
f0106461:	57                   	push   %edi
f0106462:	56                   	push   %esi
f0106463:	83 ec 0c             	sub    $0xc,%esp
f0106466:	8b 44 24 28          	mov    0x28(%esp),%eax
f010646a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010646e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106472:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106476:	85 c0                	test   %eax,%eax
f0106478:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010647c:	89 ea                	mov    %ebp,%edx
f010647e:	89 0c 24             	mov    %ecx,(%esp)
f0106481:	75 2d                	jne    f01064b0 <__udivdi3+0x50>
f0106483:	39 e9                	cmp    %ebp,%ecx
f0106485:	77 61                	ja     f01064e8 <__udivdi3+0x88>
f0106487:	85 c9                	test   %ecx,%ecx
f0106489:	89 ce                	mov    %ecx,%esi
f010648b:	75 0b                	jne    f0106498 <__udivdi3+0x38>
f010648d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106492:	31 d2                	xor    %edx,%edx
f0106494:	f7 f1                	div    %ecx
f0106496:	89 c6                	mov    %eax,%esi
f0106498:	31 d2                	xor    %edx,%edx
f010649a:	89 e8                	mov    %ebp,%eax
f010649c:	f7 f6                	div    %esi
f010649e:	89 c5                	mov    %eax,%ebp
f01064a0:	89 f8                	mov    %edi,%eax
f01064a2:	f7 f6                	div    %esi
f01064a4:	89 ea                	mov    %ebp,%edx
f01064a6:	83 c4 0c             	add    $0xc,%esp
f01064a9:	5e                   	pop    %esi
f01064aa:	5f                   	pop    %edi
f01064ab:	5d                   	pop    %ebp
f01064ac:	c3                   	ret    
f01064ad:	8d 76 00             	lea    0x0(%esi),%esi
f01064b0:	39 e8                	cmp    %ebp,%eax
f01064b2:	77 24                	ja     f01064d8 <__udivdi3+0x78>
f01064b4:	0f bd e8             	bsr    %eax,%ebp
f01064b7:	83 f5 1f             	xor    $0x1f,%ebp
f01064ba:	75 3c                	jne    f01064f8 <__udivdi3+0x98>
f01064bc:	8b 74 24 04          	mov    0x4(%esp),%esi
f01064c0:	39 34 24             	cmp    %esi,(%esp)
f01064c3:	0f 86 9f 00 00 00    	jbe    f0106568 <__udivdi3+0x108>
f01064c9:	39 d0                	cmp    %edx,%eax
f01064cb:	0f 82 97 00 00 00    	jb     f0106568 <__udivdi3+0x108>
f01064d1:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f01064d8:	31 d2                	xor    %edx,%edx
f01064da:	31 c0                	xor    %eax,%eax
f01064dc:	83 c4 0c             	add    $0xc,%esp
f01064df:	5e                   	pop    %esi
f01064e0:	5f                   	pop    %edi
f01064e1:	5d                   	pop    %ebp
f01064e2:	c3                   	ret    
f01064e3:	90                   	nop
f01064e4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01064e8:	89 f8                	mov    %edi,%eax
f01064ea:	f7 f1                	div    %ecx
f01064ec:	31 d2                	xor    %edx,%edx
f01064ee:	83 c4 0c             	add    $0xc,%esp
f01064f1:	5e                   	pop    %esi
f01064f2:	5f                   	pop    %edi
f01064f3:	5d                   	pop    %ebp
f01064f4:	c3                   	ret    
f01064f5:	8d 76 00             	lea    0x0(%esi),%esi
f01064f8:	89 e9                	mov    %ebp,%ecx
f01064fa:	8b 3c 24             	mov    (%esp),%edi
f01064fd:	d3 e0                	shl    %cl,%eax
f01064ff:	89 c6                	mov    %eax,%esi
f0106501:	b8 20 00 00 00       	mov    $0x20,%eax
f0106506:	29 e8                	sub    %ebp,%eax
f0106508:	89 c1                	mov    %eax,%ecx
f010650a:	d3 ef                	shr    %cl,%edi
f010650c:	89 e9                	mov    %ebp,%ecx
f010650e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106512:	8b 3c 24             	mov    (%esp),%edi
f0106515:	09 74 24 08          	or     %esi,0x8(%esp)
f0106519:	89 d6                	mov    %edx,%esi
f010651b:	d3 e7                	shl    %cl,%edi
f010651d:	89 c1                	mov    %eax,%ecx
f010651f:	89 3c 24             	mov    %edi,(%esp)
f0106522:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106526:	d3 ee                	shr    %cl,%esi
f0106528:	89 e9                	mov    %ebp,%ecx
f010652a:	d3 e2                	shl    %cl,%edx
f010652c:	89 c1                	mov    %eax,%ecx
f010652e:	d3 ef                	shr    %cl,%edi
f0106530:	09 d7                	or     %edx,%edi
f0106532:	89 f2                	mov    %esi,%edx
f0106534:	89 f8                	mov    %edi,%eax
f0106536:	f7 74 24 08          	divl   0x8(%esp)
f010653a:	89 d6                	mov    %edx,%esi
f010653c:	89 c7                	mov    %eax,%edi
f010653e:	f7 24 24             	mull   (%esp)
f0106541:	39 d6                	cmp    %edx,%esi
f0106543:	89 14 24             	mov    %edx,(%esp)
f0106546:	72 30                	jb     f0106578 <__udivdi3+0x118>
f0106548:	8b 54 24 04          	mov    0x4(%esp),%edx
f010654c:	89 e9                	mov    %ebp,%ecx
f010654e:	d3 e2                	shl    %cl,%edx
f0106550:	39 c2                	cmp    %eax,%edx
f0106552:	73 05                	jae    f0106559 <__udivdi3+0xf9>
f0106554:	3b 34 24             	cmp    (%esp),%esi
f0106557:	74 1f                	je     f0106578 <__udivdi3+0x118>
f0106559:	89 f8                	mov    %edi,%eax
f010655b:	31 d2                	xor    %edx,%edx
f010655d:	e9 7a ff ff ff       	jmp    f01064dc <__udivdi3+0x7c>
f0106562:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106568:	31 d2                	xor    %edx,%edx
f010656a:	b8 01 00 00 00       	mov    $0x1,%eax
f010656f:	e9 68 ff ff ff       	jmp    f01064dc <__udivdi3+0x7c>
f0106574:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106578:	8d 47 ff             	lea    -0x1(%edi),%eax
f010657b:	31 d2                	xor    %edx,%edx
f010657d:	83 c4 0c             	add    $0xc,%esp
f0106580:	5e                   	pop    %esi
f0106581:	5f                   	pop    %edi
f0106582:	5d                   	pop    %ebp
f0106583:	c3                   	ret    
f0106584:	66 90                	xchg   %ax,%ax
f0106586:	66 90                	xchg   %ax,%ax
f0106588:	66 90                	xchg   %ax,%ax
f010658a:	66 90                	xchg   %ax,%ax
f010658c:	66 90                	xchg   %ax,%ax
f010658e:	66 90                	xchg   %ax,%ax

f0106590 <__umoddi3>:
f0106590:	55                   	push   %ebp
f0106591:	57                   	push   %edi
f0106592:	56                   	push   %esi
f0106593:	83 ec 14             	sub    $0x14,%esp
f0106596:	8b 44 24 28          	mov    0x28(%esp),%eax
f010659a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010659e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f01065a2:	89 c7                	mov    %eax,%edi
f01065a4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01065a8:	8b 44 24 30          	mov    0x30(%esp),%eax
f01065ac:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f01065b0:	89 34 24             	mov    %esi,(%esp)
f01065b3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01065b7:	85 c0                	test   %eax,%eax
f01065b9:	89 c2                	mov    %eax,%edx
f01065bb:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01065bf:	75 17                	jne    f01065d8 <__umoddi3+0x48>
f01065c1:	39 fe                	cmp    %edi,%esi
f01065c3:	76 4b                	jbe    f0106610 <__umoddi3+0x80>
f01065c5:	89 c8                	mov    %ecx,%eax
f01065c7:	89 fa                	mov    %edi,%edx
f01065c9:	f7 f6                	div    %esi
f01065cb:	89 d0                	mov    %edx,%eax
f01065cd:	31 d2                	xor    %edx,%edx
f01065cf:	83 c4 14             	add    $0x14,%esp
f01065d2:	5e                   	pop    %esi
f01065d3:	5f                   	pop    %edi
f01065d4:	5d                   	pop    %ebp
f01065d5:	c3                   	ret    
f01065d6:	66 90                	xchg   %ax,%ax
f01065d8:	39 f8                	cmp    %edi,%eax
f01065da:	77 54                	ja     f0106630 <__umoddi3+0xa0>
f01065dc:	0f bd e8             	bsr    %eax,%ebp
f01065df:	83 f5 1f             	xor    $0x1f,%ebp
f01065e2:	75 5c                	jne    f0106640 <__umoddi3+0xb0>
f01065e4:	8b 7c 24 08          	mov    0x8(%esp),%edi
f01065e8:	39 3c 24             	cmp    %edi,(%esp)
f01065eb:	0f 87 e7 00 00 00    	ja     f01066d8 <__umoddi3+0x148>
f01065f1:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01065f5:	29 f1                	sub    %esi,%ecx
f01065f7:	19 c7                	sbb    %eax,%edi
f01065f9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01065fd:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106601:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106605:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106609:	83 c4 14             	add    $0x14,%esp
f010660c:	5e                   	pop    %esi
f010660d:	5f                   	pop    %edi
f010660e:	5d                   	pop    %ebp
f010660f:	c3                   	ret    
f0106610:	85 f6                	test   %esi,%esi
f0106612:	89 f5                	mov    %esi,%ebp
f0106614:	75 0b                	jne    f0106621 <__umoddi3+0x91>
f0106616:	b8 01 00 00 00       	mov    $0x1,%eax
f010661b:	31 d2                	xor    %edx,%edx
f010661d:	f7 f6                	div    %esi
f010661f:	89 c5                	mov    %eax,%ebp
f0106621:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106625:	31 d2                	xor    %edx,%edx
f0106627:	f7 f5                	div    %ebp
f0106629:	89 c8                	mov    %ecx,%eax
f010662b:	f7 f5                	div    %ebp
f010662d:	eb 9c                	jmp    f01065cb <__umoddi3+0x3b>
f010662f:	90                   	nop
f0106630:	89 c8                	mov    %ecx,%eax
f0106632:	89 fa                	mov    %edi,%edx
f0106634:	83 c4 14             	add    $0x14,%esp
f0106637:	5e                   	pop    %esi
f0106638:	5f                   	pop    %edi
f0106639:	5d                   	pop    %ebp
f010663a:	c3                   	ret    
f010663b:	90                   	nop
f010663c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106640:	8b 04 24             	mov    (%esp),%eax
f0106643:	be 20 00 00 00       	mov    $0x20,%esi
f0106648:	89 e9                	mov    %ebp,%ecx
f010664a:	29 ee                	sub    %ebp,%esi
f010664c:	d3 e2                	shl    %cl,%edx
f010664e:	89 f1                	mov    %esi,%ecx
f0106650:	d3 e8                	shr    %cl,%eax
f0106652:	89 e9                	mov    %ebp,%ecx
f0106654:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106658:	8b 04 24             	mov    (%esp),%eax
f010665b:	09 54 24 04          	or     %edx,0x4(%esp)
f010665f:	89 fa                	mov    %edi,%edx
f0106661:	d3 e0                	shl    %cl,%eax
f0106663:	89 f1                	mov    %esi,%ecx
f0106665:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106669:	8b 44 24 10          	mov    0x10(%esp),%eax
f010666d:	d3 ea                	shr    %cl,%edx
f010666f:	89 e9                	mov    %ebp,%ecx
f0106671:	d3 e7                	shl    %cl,%edi
f0106673:	89 f1                	mov    %esi,%ecx
f0106675:	d3 e8                	shr    %cl,%eax
f0106677:	89 e9                	mov    %ebp,%ecx
f0106679:	09 f8                	or     %edi,%eax
f010667b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f010667f:	f7 74 24 04          	divl   0x4(%esp)
f0106683:	d3 e7                	shl    %cl,%edi
f0106685:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106689:	89 d7                	mov    %edx,%edi
f010668b:	f7 64 24 08          	mull   0x8(%esp)
f010668f:	39 d7                	cmp    %edx,%edi
f0106691:	89 c1                	mov    %eax,%ecx
f0106693:	89 14 24             	mov    %edx,(%esp)
f0106696:	72 2c                	jb     f01066c4 <__umoddi3+0x134>
f0106698:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010669c:	72 22                	jb     f01066c0 <__umoddi3+0x130>
f010669e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f01066a2:	29 c8                	sub    %ecx,%eax
f01066a4:	19 d7                	sbb    %edx,%edi
f01066a6:	89 e9                	mov    %ebp,%ecx
f01066a8:	89 fa                	mov    %edi,%edx
f01066aa:	d3 e8                	shr    %cl,%eax
f01066ac:	89 f1                	mov    %esi,%ecx
f01066ae:	d3 e2                	shl    %cl,%edx
f01066b0:	89 e9                	mov    %ebp,%ecx
f01066b2:	d3 ef                	shr    %cl,%edi
f01066b4:	09 d0                	or     %edx,%eax
f01066b6:	89 fa                	mov    %edi,%edx
f01066b8:	83 c4 14             	add    $0x14,%esp
f01066bb:	5e                   	pop    %esi
f01066bc:	5f                   	pop    %edi
f01066bd:	5d                   	pop    %ebp
f01066be:	c3                   	ret    
f01066bf:	90                   	nop
f01066c0:	39 d7                	cmp    %edx,%edi
f01066c2:	75 da                	jne    f010669e <__umoddi3+0x10e>
f01066c4:	8b 14 24             	mov    (%esp),%edx
f01066c7:	89 c1                	mov    %eax,%ecx
f01066c9:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f01066cd:	1b 54 24 04          	sbb    0x4(%esp),%edx
f01066d1:	eb cb                	jmp    f010669e <__umoddi3+0x10e>
f01066d3:	90                   	nop
f01066d4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01066d8:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f01066dc:	0f 82 0f ff ff ff    	jb     f01065f1 <__umoddi3+0x61>
f01066e2:	e9 1a ff ff ff       	jmp    f0106601 <__umoddi3+0x71>
