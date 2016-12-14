
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
f010004b:	83 3d 80 6e 22 f0 00 	cmpl   $0x0,0xf0226e80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 6e 22 f0    	mov    %esi,0xf0226e80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 6f 61 00 00       	call   f01061d3 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 e0 68 10 f0 	movl   $0xf01068e0,(%esp)
f010007d:	e8 57 3c 00 00       	call   f0103cd9 <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 18 3c 00 00       	call   f0103ca6 <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 67 71 10 f0 	movl   $0xf0107167,(%esp)
f0100095:	e8 3f 3c 00 00       	call   f0103cd9 <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 f1 08 00 00       	call   f0100997 <monitor>
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
f01000af:	b8 04 80 26 f0       	mov    $0xf0268004,%eax
f01000b4:	2d 92 55 22 f0       	sub    $0xf0225592,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 92 55 22 f0 	movl   $0xf0225592,(%esp)
f01000cc:	e8 68 5a 00 00       	call   f0105b39 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 f9 05 00 00       	call   f01006cf <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 4c 69 10 f0 	movl   $0xf010694c,(%esp)
f01000e5:	e8 ef 3b 00 00       	call   f0103cd9 <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 c6 13 00 00       	call   f01014b5 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 6f 33 00 00       	call   f0103463 <env_init>
	trap_init();
f01000f4:	e8 90 3c 00 00       	call   f0103d89 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 bb 5d 00 00       	call   f0105eb9 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 e9 60 00 00       	call   f01061ee <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 fc 3a 00 00       	call   f0103c06 <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f0100111:	e8 23 63 00 00       	call   f0106439 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100116:	83 3d 88 6e 22 f0 07 	cmpl   $0x7,0xf0226e88
f010011d:	77 24                	ja     f0100143 <i386_init+0x9b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010011f:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100126:	00 
f0100127:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 60 00 00 	movl   $0x60,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 67 69 10 f0 	movl   $0xf0106967,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 e6 5d 10 f0       	mov    $0xf0105de6,%eax
f0100148:	2d 6c 5d 10 f0       	sub    $0xf0105d6c,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 6c 5d 10 	movl   $0xf0105d6c,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 21 5a 00 00       	call   f0105b86 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 73 22 f0 74 	imul   $0x74,0xf02273c4,%eax
f010016c:	05 20 70 22 f0       	add    $0xf0227020,%eax
f0100171:	3d 20 70 22 f0       	cmp    $0xf0227020,%eax
f0100176:	0f 86 a6 00 00 00    	jbe    f0100222 <i386_init+0x17a>
f010017c:	bb 20 70 22 f0       	mov    $0xf0227020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100181:	e8 4d 60 00 00       	call   f01061d3 <cpunum>
f0100186:	6b c0 74             	imul   $0x74,%eax,%eax
f0100189:	05 20 70 22 f0       	add    $0xf0227020,%eax
f010018e:	39 c3                	cmp    %eax,%ebx
f0100190:	74 39                	je     f01001cb <i386_init+0x123>
f0100192:	89 d8                	mov    %ebx,%eax
f0100194:	2d 20 70 22 f0       	sub    $0xf0227020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f0100199:	c1 f8 02             	sar    $0x2,%eax
f010019c:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001a2:	c1 e0 0f             	shl    $0xf,%eax
f01001a5:	8d 80 00 00 23 f0    	lea    -0xfdd0000(%eax),%eax
f01001ab:	a3 84 6e 22 f0       	mov    %eax,0xf0226e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001b0:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001b7:	00 
f01001b8:	0f b6 03             	movzbl (%ebx),%eax
f01001bb:	89 04 24             	mov    %eax,(%esp)
f01001be:	e8 63 61 00 00       	call   f0106326 <lapic_startap>
		// Wait for the CPU to finish some basic setup in mp_main()
		while(c->cpu_status != CPU_STARTED)
f01001c3:	8b 43 04             	mov    0x4(%ebx),%eax
f01001c6:	83 f8 01             	cmp    $0x1,%eax
f01001c9:	75 f8                	jne    f01001c3 <i386_init+0x11b>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f01001cb:	83 c3 74             	add    $0x74,%ebx
f01001ce:	6b 05 c4 73 22 f0 74 	imul   $0x74,0xf02273c4,%eax
f01001d5:	05 20 70 22 f0       	add    $0xf0227020,%eax
f01001da:	39 c3                	cmp    %eax,%ebx
f01001dc:	72 a3                	jb     f0100181 <i386_init+0xd9>
f01001de:	eb 42                	jmp    f0100222 <i386_init+0x17a>
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001e0:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001e7:	00 
f01001e8:	c7 44 24 04 46 89 00 	movl   $0x8946,0x4(%esp)
f01001ef:	00 
f01001f0:	c7 04 24 f4 fc 18 f0 	movl   $0xf018fcf4,(%esp)
f01001f7:	e8 81 34 00 00       	call   f010367d <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
f01001fc:	83 eb 01             	sub    $0x1,%ebx
f01001ff:	75 df                	jne    f01001e0 <i386_init+0x138>
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);


#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
f0100201:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100208:	00 
f0100209:	c7 44 24 04 a0 9a 00 	movl   $0x9aa0,0x4(%esp)
f0100210:	00 
f0100211:	c7 04 24 f2 ba 21 f0 	movl   $0xf021baf2,(%esp)
f0100218:	e8 60 34 00 00       	call   f010367d <env_create>
	ENV_CREATE(user_yield, ENV_TYPE_USER);
	ENV_CREATE(user_yield, ENV_TYPE_USER);
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f010021d:	e8 de 44 00 00       	call   f0104700 <sched_yield>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100222:	bb 08 00 00 00       	mov    $0x8,%ebx
f0100227:	eb b7                	jmp    f01001e0 <i386_init+0x138>

f0100229 <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f0100229:	55                   	push   %ebp
f010022a:	89 e5                	mov    %esp,%ebp
f010022c:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f010022f:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100234:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100239:	77 20                	ja     f010025b <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010023b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010023f:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0100246:	f0 
f0100247:	c7 44 24 04 77 00 00 	movl   $0x77,0x4(%esp)
f010024e:	00 
f010024f:	c7 04 24 67 69 10 f0 	movl   $0xf0106967,(%esp)
f0100256:	e8 e5 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010025b:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0100260:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f0100263:	e8 6b 5f 00 00       	call   f01061d3 <cpunum>
f0100268:	89 44 24 04          	mov    %eax,0x4(%esp)
f010026c:	c7 04 24 73 69 10 f0 	movl   $0xf0106973,(%esp)
f0100273:	e8 61 3a 00 00       	call   f0103cd9 <cprintf>

	lapic_init();
f0100278:	e8 71 5f 00 00       	call   f01061ee <lapic_init>
	env_init_percpu();
f010027d:	e8 b7 31 00 00       	call   f0103439 <env_init_percpu>
	trap_init_percpu();
f0100282:	e8 79 3a 00 00       	call   f0103d00 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f0100287:	e8 47 5f 00 00       	call   f01061d3 <cpunum>
f010028c:	6b d0 74             	imul   $0x74,%eax,%edx
f010028f:	81 c2 20 70 22 f0    	add    $0xf0227020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0100295:	b8 01 00 00 00       	mov    $0x1,%eax
f010029a:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f010029e:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f01002a5:	e8 8f 61 00 00       	call   f0106439 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002aa:	e8 51 44 00 00       	call   f0104700 <sched_yield>

f01002af <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002af:	55                   	push   %ebp
f01002b0:	89 e5                	mov    %esp,%ebp
f01002b2:	53                   	push   %ebx
f01002b3:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002b6:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002b9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002bc:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002c0:	8b 45 08             	mov    0x8(%ebp),%eax
f01002c3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002c7:	c7 04 24 89 69 10 f0 	movl   $0xf0106989,(%esp)
f01002ce:	e8 06 3a 00 00       	call   f0103cd9 <cprintf>
	vcprintf(fmt, ap);
f01002d3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002d7:	8b 45 10             	mov    0x10(%ebp),%eax
f01002da:	89 04 24             	mov    %eax,(%esp)
f01002dd:	e8 c4 39 00 00       	call   f0103ca6 <vcprintf>
	cprintf("\n");
f01002e2:	c7 04 24 67 71 10 f0 	movl   $0xf0107167,(%esp)
f01002e9:	e8 eb 39 00 00       	call   f0103cd9 <cprintf>
	va_end(ap);
}
f01002ee:	83 c4 14             	add    $0x14,%esp
f01002f1:	5b                   	pop    %ebx
f01002f2:	5d                   	pop    %ebp
f01002f3:	c3                   	ret    
f01002f4:	66 90                	xchg   %ax,%ax
f01002f6:	66 90                	xchg   %ax,%ax
f01002f8:	66 90                	xchg   %ax,%ax
f01002fa:	66 90                	xchg   %ax,%ax
f01002fc:	66 90                	xchg   %ax,%ax
f01002fe:	66 90                	xchg   %ax,%ax

f0100300 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100300:	55                   	push   %ebp
f0100301:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100303:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100308:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100309:	a8 01                	test   $0x1,%al
f010030b:	74 08                	je     f0100315 <serial_proc_data+0x15>
f010030d:	b2 f8                	mov    $0xf8,%dl
f010030f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100310:	0f b6 c0             	movzbl %al,%eax
f0100313:	eb 05                	jmp    f010031a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100315:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010031a:	5d                   	pop    %ebp
f010031b:	c3                   	ret    

f010031c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010031c:	55                   	push   %ebp
f010031d:	89 e5                	mov    %esp,%ebp
f010031f:	53                   	push   %ebx
f0100320:	83 ec 04             	sub    $0x4,%esp
f0100323:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100325:	eb 2a                	jmp    f0100351 <cons_intr+0x35>
		if (c == 0)
f0100327:	85 d2                	test   %edx,%edx
f0100329:	74 26                	je     f0100351 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010032b:	a1 24 62 22 f0       	mov    0xf0226224,%eax
f0100330:	8d 48 01             	lea    0x1(%eax),%ecx
f0100333:	89 0d 24 62 22 f0    	mov    %ecx,0xf0226224
f0100339:	88 90 20 60 22 f0    	mov    %dl,-0xfdd9fe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010033f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100345:	75 0a                	jne    f0100351 <cons_intr+0x35>
			cons.wpos = 0;
f0100347:	c7 05 24 62 22 f0 00 	movl   $0x0,0xf0226224
f010034e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100351:	ff d3                	call   *%ebx
f0100353:	89 c2                	mov    %eax,%edx
f0100355:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100358:	75 cd                	jne    f0100327 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010035a:	83 c4 04             	add    $0x4,%esp
f010035d:	5b                   	pop    %ebx
f010035e:	5d                   	pop    %ebp
f010035f:	c3                   	ret    

f0100360 <kbd_proc_data>:
f0100360:	ba 64 00 00 00       	mov    $0x64,%edx
f0100365:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100366:	a8 01                	test   $0x1,%al
f0100368:	0f 84 ef 00 00 00    	je     f010045d <kbd_proc_data+0xfd>
f010036e:	b2 60                	mov    $0x60,%dl
f0100370:	ec                   	in     (%dx),%al
f0100371:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100373:	3c e0                	cmp    $0xe0,%al
f0100375:	75 0d                	jne    f0100384 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100377:	83 0d 00 60 22 f0 40 	orl    $0x40,0xf0226000
		return 0;
f010037e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100383:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f0100384:	55                   	push   %ebp
f0100385:	89 e5                	mov    %esp,%ebp
f0100387:	53                   	push   %ebx
f0100388:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f010038b:	84 c0                	test   %al,%al
f010038d:	79 37                	jns    f01003c6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f010038f:	8b 0d 00 60 22 f0    	mov    0xf0226000,%ecx
f0100395:	89 cb                	mov    %ecx,%ebx
f0100397:	83 e3 40             	and    $0x40,%ebx
f010039a:	83 e0 7f             	and    $0x7f,%eax
f010039d:	85 db                	test   %ebx,%ebx
f010039f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003a2:	0f b6 d2             	movzbl %dl,%edx
f01003a5:	0f b6 82 00 6b 10 f0 	movzbl -0xfef9500(%edx),%eax
f01003ac:	83 c8 40             	or     $0x40,%eax
f01003af:	0f b6 c0             	movzbl %al,%eax
f01003b2:	f7 d0                	not    %eax
f01003b4:	21 c1                	and    %eax,%ecx
f01003b6:	89 0d 00 60 22 f0    	mov    %ecx,0xf0226000
		return 0;
f01003bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003c1:	e9 9d 00 00 00       	jmp    f0100463 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003c6:	8b 0d 00 60 22 f0    	mov    0xf0226000,%ecx
f01003cc:	f6 c1 40             	test   $0x40,%cl
f01003cf:	74 0e                	je     f01003df <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003d1:	83 c8 80             	or     $0xffffff80,%eax
f01003d4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003d6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003d9:	89 0d 00 60 22 f0    	mov    %ecx,0xf0226000
	}

	shift |= shiftcode[data];
f01003df:	0f b6 d2             	movzbl %dl,%edx
f01003e2:	0f b6 82 00 6b 10 f0 	movzbl -0xfef9500(%edx),%eax
f01003e9:	0b 05 00 60 22 f0    	or     0xf0226000,%eax
	shift ^= togglecode[data];
f01003ef:	0f b6 8a 00 6a 10 f0 	movzbl -0xfef9600(%edx),%ecx
f01003f6:	31 c8                	xor    %ecx,%eax
f01003f8:	a3 00 60 22 f0       	mov    %eax,0xf0226000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003fd:	89 c1                	mov    %eax,%ecx
f01003ff:	83 e1 03             	and    $0x3,%ecx
f0100402:	8b 0c 8d e0 69 10 f0 	mov    -0xfef9620(,%ecx,4),%ecx
f0100409:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010040d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100410:	a8 08                	test   $0x8,%al
f0100412:	74 1b                	je     f010042f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100414:	89 da                	mov    %ebx,%edx
f0100416:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100419:	83 f9 19             	cmp    $0x19,%ecx
f010041c:	77 05                	ja     f0100423 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010041e:	83 eb 20             	sub    $0x20,%ebx
f0100421:	eb 0c                	jmp    f010042f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100423:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100426:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100429:	83 fa 19             	cmp    $0x19,%edx
f010042c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010042f:	f7 d0                	not    %eax
f0100431:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100433:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100435:	f6 c2 06             	test   $0x6,%dl
f0100438:	75 29                	jne    f0100463 <kbd_proc_data+0x103>
f010043a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100440:	75 21                	jne    f0100463 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100442:	c7 04 24 a3 69 10 f0 	movl   $0xf01069a3,(%esp)
f0100449:	e8 8b 38 00 00       	call   f0103cd9 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010044e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100453:	b8 03 00 00 00       	mov    $0x3,%eax
f0100458:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100459:	89 d8                	mov    %ebx,%eax
f010045b:	eb 06                	jmp    f0100463 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010045d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100462:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100463:	83 c4 14             	add    $0x14,%esp
f0100466:	5b                   	pop    %ebx
f0100467:	5d                   	pop    %ebp
f0100468:	c3                   	ret    

f0100469 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100469:	55                   	push   %ebp
f010046a:	89 e5                	mov    %esp,%ebp
f010046c:	57                   	push   %edi
f010046d:	56                   	push   %esi
f010046e:	53                   	push   %ebx
f010046f:	83 ec 1c             	sub    $0x1c,%esp
f0100472:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100474:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100479:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010047a:	a8 20                	test   $0x20,%al
f010047c:	75 21                	jne    f010049f <cons_putc+0x36>
f010047e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f0100483:	b9 84 00 00 00       	mov    $0x84,%ecx
f0100488:	be fd 03 00 00       	mov    $0x3fd,%esi
f010048d:	89 ca                	mov    %ecx,%edx
f010048f:	ec                   	in     (%dx),%al
f0100490:	ec                   	in     (%dx),%al
f0100491:	ec                   	in     (%dx),%al
f0100492:	ec                   	in     (%dx),%al
f0100493:	89 f2                	mov    %esi,%edx
f0100495:	ec                   	in     (%dx),%al
f0100496:	a8 20                	test   $0x20,%al
f0100498:	75 05                	jne    f010049f <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f010049a:	83 eb 01             	sub    $0x1,%ebx
f010049d:	75 ee                	jne    f010048d <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f010049f:	89 f8                	mov    %edi,%eax
f01004a1:	0f b6 c0             	movzbl %al,%eax
f01004a4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004a7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004ac:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004ad:	b2 79                	mov    $0x79,%dl
f01004af:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004b0:	84 c0                	test   %al,%al
f01004b2:	78 21                	js     f01004d5 <cons_putc+0x6c>
f01004b4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004b9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004be:	be 79 03 00 00       	mov    $0x379,%esi
f01004c3:	89 ca                	mov    %ecx,%edx
f01004c5:	ec                   	in     (%dx),%al
f01004c6:	ec                   	in     (%dx),%al
f01004c7:	ec                   	in     (%dx),%al
f01004c8:	ec                   	in     (%dx),%al
f01004c9:	89 f2                	mov    %esi,%edx
f01004cb:	ec                   	in     (%dx),%al
f01004cc:	84 c0                	test   %al,%al
f01004ce:	78 05                	js     f01004d5 <cons_putc+0x6c>
f01004d0:	83 eb 01             	sub    $0x1,%ebx
f01004d3:	75 ee                	jne    f01004c3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004d5:	ba 78 03 00 00       	mov    $0x378,%edx
f01004da:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004de:	ee                   	out    %al,(%dx)
f01004df:	b2 7a                	mov    $0x7a,%dl
f01004e1:	b8 0d 00 00 00       	mov    $0xd,%eax
f01004e6:	ee                   	out    %al,(%dx)
f01004e7:	b8 08 00 00 00       	mov    $0x8,%eax
f01004ec:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f01004ed:	89 fa                	mov    %edi,%edx
f01004ef:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f01004f5:	89 f8                	mov    %edi,%eax
f01004f7:	80 cc 07             	or     $0x7,%ah
f01004fa:	85 d2                	test   %edx,%edx
f01004fc:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f01004ff:	89 f8                	mov    %edi,%eax
f0100501:	0f b6 c0             	movzbl %al,%eax
f0100504:	83 f8 09             	cmp    $0x9,%eax
f0100507:	74 79                	je     f0100582 <cons_putc+0x119>
f0100509:	83 f8 09             	cmp    $0x9,%eax
f010050c:	7f 0a                	jg     f0100518 <cons_putc+0xaf>
f010050e:	83 f8 08             	cmp    $0x8,%eax
f0100511:	74 19                	je     f010052c <cons_putc+0xc3>
f0100513:	e9 9e 00 00 00       	jmp    f01005b6 <cons_putc+0x14d>
f0100518:	83 f8 0a             	cmp    $0xa,%eax
f010051b:	90                   	nop
f010051c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100520:	74 3a                	je     f010055c <cons_putc+0xf3>
f0100522:	83 f8 0d             	cmp    $0xd,%eax
f0100525:	74 3d                	je     f0100564 <cons_putc+0xfb>
f0100527:	e9 8a 00 00 00       	jmp    f01005b6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010052c:	0f b7 05 28 62 22 f0 	movzwl 0xf0226228,%eax
f0100533:	66 85 c0             	test   %ax,%ax
f0100536:	0f 84 e5 00 00 00    	je     f0100621 <cons_putc+0x1b8>
			crt_pos--;
f010053c:	83 e8 01             	sub    $0x1,%eax
f010053f:	66 a3 28 62 22 f0    	mov    %ax,0xf0226228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100545:	0f b7 c0             	movzwl %ax,%eax
f0100548:	66 81 e7 00 ff       	and    $0xff00,%di
f010054d:	83 cf 20             	or     $0x20,%edi
f0100550:	8b 15 2c 62 22 f0    	mov    0xf022622c,%edx
f0100556:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010055a:	eb 78                	jmp    f01005d4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010055c:	66 83 05 28 62 22 f0 	addw   $0x50,0xf0226228
f0100563:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100564:	0f b7 05 28 62 22 f0 	movzwl 0xf0226228,%eax
f010056b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100571:	c1 e8 16             	shr    $0x16,%eax
f0100574:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100577:	c1 e0 04             	shl    $0x4,%eax
f010057a:	66 a3 28 62 22 f0    	mov    %ax,0xf0226228
f0100580:	eb 52                	jmp    f01005d4 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f0100582:	b8 20 00 00 00       	mov    $0x20,%eax
f0100587:	e8 dd fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f010058c:	b8 20 00 00 00       	mov    $0x20,%eax
f0100591:	e8 d3 fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f0100596:	b8 20 00 00 00       	mov    $0x20,%eax
f010059b:	e8 c9 fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f01005a0:	b8 20 00 00 00       	mov    $0x20,%eax
f01005a5:	e8 bf fe ff ff       	call   f0100469 <cons_putc>
		cons_putc(' ');
f01005aa:	b8 20 00 00 00       	mov    $0x20,%eax
f01005af:	e8 b5 fe ff ff       	call   f0100469 <cons_putc>
f01005b4:	eb 1e                	jmp    f01005d4 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005b6:	0f b7 05 28 62 22 f0 	movzwl 0xf0226228,%eax
f01005bd:	8d 50 01             	lea    0x1(%eax),%edx
f01005c0:	66 89 15 28 62 22 f0 	mov    %dx,0xf0226228
f01005c7:	0f b7 c0             	movzwl %ax,%eax
f01005ca:	8b 15 2c 62 22 f0    	mov    0xf022622c,%edx
f01005d0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005d4:	66 81 3d 28 62 22 f0 	cmpw   $0x7cf,0xf0226228
f01005db:	cf 07 
f01005dd:	76 42                	jbe    f0100621 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005df:	a1 2c 62 22 f0       	mov    0xf022622c,%eax
f01005e4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005eb:	00 
f01005ec:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01005f2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01005f6:	89 04 24             	mov    %eax,(%esp)
f01005f9:	e8 88 55 00 00       	call   f0105b86 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f01005fe:	8b 15 2c 62 22 f0    	mov    0xf022622c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100604:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100609:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010060f:	83 c0 01             	add    $0x1,%eax
f0100612:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100617:	75 f0                	jne    f0100609 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100619:	66 83 2d 28 62 22 f0 	subw   $0x50,0xf0226228
f0100620:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100621:	8b 0d 30 62 22 f0    	mov    0xf0226230,%ecx
f0100627:	b8 0e 00 00 00       	mov    $0xe,%eax
f010062c:	89 ca                	mov    %ecx,%edx
f010062e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010062f:	0f b7 1d 28 62 22 f0 	movzwl 0xf0226228,%ebx
f0100636:	8d 71 01             	lea    0x1(%ecx),%esi
f0100639:	89 d8                	mov    %ebx,%eax
f010063b:	66 c1 e8 08          	shr    $0x8,%ax
f010063f:	89 f2                	mov    %esi,%edx
f0100641:	ee                   	out    %al,(%dx)
f0100642:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100647:	89 ca                	mov    %ecx,%edx
f0100649:	ee                   	out    %al,(%dx)
f010064a:	89 d8                	mov    %ebx,%eax
f010064c:	89 f2                	mov    %esi,%edx
f010064e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010064f:	83 c4 1c             	add    $0x1c,%esp
f0100652:	5b                   	pop    %ebx
f0100653:	5e                   	pop    %esi
f0100654:	5f                   	pop    %edi
f0100655:	5d                   	pop    %ebp
f0100656:	c3                   	ret    

f0100657 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100657:	83 3d 34 62 22 f0 00 	cmpl   $0x0,0xf0226234
f010065e:	74 11                	je     f0100671 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100660:	55                   	push   %ebp
f0100661:	89 e5                	mov    %esp,%ebp
f0100663:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100666:	b8 00 03 10 f0       	mov    $0xf0100300,%eax
f010066b:	e8 ac fc ff ff       	call   f010031c <cons_intr>
}
f0100670:	c9                   	leave  
f0100671:	f3 c3                	repz ret 

f0100673 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100673:	55                   	push   %ebp
f0100674:	89 e5                	mov    %esp,%ebp
f0100676:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100679:	b8 60 03 10 f0       	mov    $0xf0100360,%eax
f010067e:	e8 99 fc ff ff       	call   f010031c <cons_intr>
}
f0100683:	c9                   	leave  
f0100684:	c3                   	ret    

f0100685 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f0100685:	55                   	push   %ebp
f0100686:	89 e5                	mov    %esp,%ebp
f0100688:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f010068b:	e8 c7 ff ff ff       	call   f0100657 <serial_intr>
	kbd_intr();
f0100690:	e8 de ff ff ff       	call   f0100673 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f0100695:	a1 20 62 22 f0       	mov    0xf0226220,%eax
f010069a:	3b 05 24 62 22 f0    	cmp    0xf0226224,%eax
f01006a0:	74 26                	je     f01006c8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006a2:	8d 50 01             	lea    0x1(%eax),%edx
f01006a5:	89 15 20 62 22 f0    	mov    %edx,0xf0226220
f01006ab:	0f b6 88 20 60 22 f0 	movzbl -0xfdd9fe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006b2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006b4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006ba:	75 11                	jne    f01006cd <cons_getc+0x48>
			cons.rpos = 0;
f01006bc:	c7 05 20 62 22 f0 00 	movl   $0x0,0xf0226220
f01006c3:	00 00 00 
f01006c6:	eb 05                	jmp    f01006cd <cons_getc+0x48>
		return c;
	}
	return 0;
f01006c8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006cd:	c9                   	leave  
f01006ce:	c3                   	ret    

f01006cf <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006cf:	55                   	push   %ebp
f01006d0:	89 e5                	mov    %esp,%ebp
f01006d2:	57                   	push   %edi
f01006d3:	56                   	push   %esi
f01006d4:	53                   	push   %ebx
f01006d5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006d8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006df:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f01006e6:	5a a5 
	if (*cp != 0xA55A) {
f01006e8:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f01006ef:	66 3d 5a a5          	cmp    $0xa55a,%ax
f01006f3:	74 11                	je     f0100706 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f01006f5:	c7 05 30 62 22 f0 b4 	movl   $0x3b4,0xf0226230
f01006fc:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f01006ff:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100704:	eb 16                	jmp    f010071c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100706:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010070d:	c7 05 30 62 22 f0 d4 	movl   $0x3d4,0xf0226230
f0100714:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100717:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010071c:	8b 0d 30 62 22 f0    	mov    0xf0226230,%ecx
f0100722:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100727:	89 ca                	mov    %ecx,%edx
f0100729:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010072a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010072d:	89 da                	mov    %ebx,%edx
f010072f:	ec                   	in     (%dx),%al
f0100730:	0f b6 f0             	movzbl %al,%esi
f0100733:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100736:	b8 0f 00 00 00       	mov    $0xf,%eax
f010073b:	89 ca                	mov    %ecx,%edx
f010073d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010073e:	89 da                	mov    %ebx,%edx
f0100740:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100741:	89 3d 2c 62 22 f0    	mov    %edi,0xf022622c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100747:	0f b6 d8             	movzbl %al,%ebx
f010074a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010074c:	66 89 35 28 62 22 f0 	mov    %si,0xf0226228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100753:	e8 1b ff ff ff       	call   f0100673 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100758:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f010075f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100764:	89 04 24             	mov    %eax,(%esp)
f0100767:	e8 2b 34 00 00       	call   f0103b97 <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010076c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100771:	b8 00 00 00 00       	mov    $0x0,%eax
f0100776:	89 f2                	mov    %esi,%edx
f0100778:	ee                   	out    %al,(%dx)
f0100779:	b2 fb                	mov    $0xfb,%dl
f010077b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f0100780:	ee                   	out    %al,(%dx)
f0100781:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f0100786:	b8 0c 00 00 00       	mov    $0xc,%eax
f010078b:	89 da                	mov    %ebx,%edx
f010078d:	ee                   	out    %al,(%dx)
f010078e:	b2 f9                	mov    $0xf9,%dl
f0100790:	b8 00 00 00 00       	mov    $0x0,%eax
f0100795:	ee                   	out    %al,(%dx)
f0100796:	b2 fb                	mov    $0xfb,%dl
f0100798:	b8 03 00 00 00       	mov    $0x3,%eax
f010079d:	ee                   	out    %al,(%dx)
f010079e:	b2 fc                	mov    $0xfc,%dl
f01007a0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007a5:	ee                   	out    %al,(%dx)
f01007a6:	b2 f9                	mov    $0xf9,%dl
f01007a8:	b8 01 00 00 00       	mov    $0x1,%eax
f01007ad:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01007ae:	b2 fd                	mov    $0xfd,%dl
f01007b0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007b1:	3c ff                	cmp    $0xff,%al
f01007b3:	0f 95 c1             	setne  %cl
f01007b6:	0f b6 c9             	movzbl %cl,%ecx
f01007b9:	89 0d 34 62 22 f0    	mov    %ecx,0xf0226234
f01007bf:	89 f2                	mov    %esi,%edx
f01007c1:	ec                   	in     (%dx),%al
f01007c2:	89 da                	mov    %ebx,%edx
f01007c4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007c5:	85 c9                	test   %ecx,%ecx
f01007c7:	75 0c                	jne    f01007d5 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007c9:	c7 04 24 af 69 10 f0 	movl   $0xf01069af,(%esp)
f01007d0:	e8 04 35 00 00       	call   f0103cd9 <cprintf>
}
f01007d5:	83 c4 1c             	add    $0x1c,%esp
f01007d8:	5b                   	pop    %ebx
f01007d9:	5e                   	pop    %esi
f01007da:	5f                   	pop    %edi
f01007db:	5d                   	pop    %ebp
f01007dc:	c3                   	ret    

f01007dd <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007dd:	55                   	push   %ebp
f01007de:	89 e5                	mov    %esp,%ebp
f01007e0:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f01007e3:	8b 45 08             	mov    0x8(%ebp),%eax
f01007e6:	e8 7e fc ff ff       	call   f0100469 <cons_putc>
}
f01007eb:	c9                   	leave  
f01007ec:	c3                   	ret    

f01007ed <getchar>:

int
getchar(void)
{
f01007ed:	55                   	push   %ebp
f01007ee:	89 e5                	mov    %esp,%ebp
f01007f0:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f01007f3:	e8 8d fe ff ff       	call   f0100685 <cons_getc>
f01007f8:	85 c0                	test   %eax,%eax
f01007fa:	74 f7                	je     f01007f3 <getchar+0x6>
		/* do nothing */;
	return c;
}
f01007fc:	c9                   	leave  
f01007fd:	c3                   	ret    

f01007fe <iscons>:

int
iscons(int fdnum)
{
f01007fe:	55                   	push   %ebp
f01007ff:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100801:	b8 01 00 00 00       	mov    $0x1,%eax
f0100806:	5d                   	pop    %ebp
f0100807:	c3                   	ret    
f0100808:	66 90                	xchg   %ax,%ax
f010080a:	66 90                	xchg   %ax,%ax
f010080c:	66 90                	xchg   %ax,%ax
f010080e:	66 90                	xchg   %ax,%ax

f0100810 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100810:	55                   	push   %ebp
f0100811:	89 e5                	mov    %esp,%ebp
f0100813:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100816:	c7 44 24 08 00 6c 10 	movl   $0xf0106c00,0x8(%esp)
f010081d:	f0 
f010081e:	c7 44 24 04 1e 6c 10 	movl   $0xf0106c1e,0x4(%esp)
f0100825:	f0 
f0100826:	c7 04 24 23 6c 10 f0 	movl   $0xf0106c23,(%esp)
f010082d:	e8 a7 34 00 00       	call   f0103cd9 <cprintf>
f0100832:	c7 44 24 08 c8 6c 10 	movl   $0xf0106cc8,0x8(%esp)
f0100839:	f0 
f010083a:	c7 44 24 04 2c 6c 10 	movl   $0xf0106c2c,0x4(%esp)
f0100841:	f0 
f0100842:	c7 04 24 23 6c 10 f0 	movl   $0xf0106c23,(%esp)
f0100849:	e8 8b 34 00 00       	call   f0103cd9 <cprintf>
f010084e:	c7 44 24 08 35 6c 10 	movl   $0xf0106c35,0x8(%esp)
f0100855:	f0 
f0100856:	c7 44 24 04 53 6c 10 	movl   $0xf0106c53,0x4(%esp)
f010085d:	f0 
f010085e:	c7 04 24 23 6c 10 f0 	movl   $0xf0106c23,(%esp)
f0100865:	e8 6f 34 00 00       	call   f0103cd9 <cprintf>
	return 0;
}
f010086a:	b8 00 00 00 00       	mov    $0x0,%eax
f010086f:	c9                   	leave  
f0100870:	c3                   	ret    

f0100871 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100871:	55                   	push   %ebp
f0100872:	89 e5                	mov    %esp,%ebp
f0100874:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100877:	c7 04 24 61 6c 10 f0 	movl   $0xf0106c61,(%esp)
f010087e:	e8 56 34 00 00       	call   f0103cd9 <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100883:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010088a:	00 
f010088b:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f0100892:	f0 
f0100893:	c7 04 24 f0 6c 10 f0 	movl   $0xf0106cf0,(%esp)
f010089a:	e8 3a 34 00 00       	call   f0103cd9 <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010089f:	c7 44 24 08 c7 68 10 	movl   $0x1068c7,0x8(%esp)
f01008a6:	00 
f01008a7:	c7 44 24 04 c7 68 10 	movl   $0xf01068c7,0x4(%esp)
f01008ae:	f0 
f01008af:	c7 04 24 14 6d 10 f0 	movl   $0xf0106d14,(%esp)
f01008b6:	e8 1e 34 00 00       	call   f0103cd9 <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008bb:	c7 44 24 08 92 55 22 	movl   $0x225592,0x8(%esp)
f01008c2:	00 
f01008c3:	c7 44 24 04 92 55 22 	movl   $0xf0225592,0x4(%esp)
f01008ca:	f0 
f01008cb:	c7 04 24 38 6d 10 f0 	movl   $0xf0106d38,(%esp)
f01008d2:	e8 02 34 00 00       	call   f0103cd9 <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008d7:	c7 44 24 08 04 80 26 	movl   $0x268004,0x8(%esp)
f01008de:	00 
f01008df:	c7 44 24 04 04 80 26 	movl   $0xf0268004,0x4(%esp)
f01008e6:	f0 
f01008e7:	c7 04 24 5c 6d 10 f0 	movl   $0xf0106d5c,(%esp)
f01008ee:	e8 e6 33 00 00       	call   f0103cd9 <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f01008f3:	b8 03 84 26 f0       	mov    $0xf0268403,%eax
f01008f8:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf("Special kernel symbols:\n");
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f01008fd:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100903:	85 c0                	test   %eax,%eax
f0100905:	0f 48 c2             	cmovs  %edx,%eax
f0100908:	c1 f8 0a             	sar    $0xa,%eax
f010090b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010090f:	c7 04 24 80 6d 10 f0 	movl   $0xf0106d80,(%esp)
f0100916:	e8 be 33 00 00       	call   f0103cd9 <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f010091b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100920:	c9                   	leave  
f0100921:	c3                   	ret    

f0100922 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f0100922:	55                   	push   %ebp
f0100923:	89 e5                	mov    %esp,%ebp
f0100925:	53                   	push   %ebx
f0100926:	83 ec 44             	sub    $0x44,%esp

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f0100929:	89 eb                	mov    %ebp,%ebx
	unsigned int ebp;
	unsigned int eip;
	unsigned int args[5];
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
f010092b:	c7 04 24 7a 6c 10 f0 	movl   $0xf0106c7a,(%esp)
f0100932:	e8 a2 33 00 00       	call   f0103cd9 <cprintf>
	do{
           eip = *((unsigned int*)(ebp + 4));
f0100937:	8b 4b 04             	mov    0x4(%ebx),%ecx
           for(i=0;i<5;i++)
f010093a:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *((unsigned int*)(ebp+8+4*i));
f010093f:	8b 54 83 08          	mov    0x8(%ebx,%eax,4),%edx
f0100943:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
	do{
           eip = *((unsigned int*)(ebp + 4));
           for(i=0;i<5;i++)
f0100947:	83 c0 01             	add    $0x1,%eax
f010094a:	83 f8 05             	cmp    $0x5,%eax
f010094d:	75 f0                	jne    f010093f <mon_backtrace+0x1d>
		args[i] = *((unsigned int*)(ebp+8+4*i));
	cprintf(" ebp %08x eip %08x args %08x %08x %08x %08x %08x\n",
f010094f:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100952:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f0100956:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100959:	89 44 24 18          	mov    %eax,0x18(%esp)
f010095d:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100960:	89 44 24 14          	mov    %eax,0x14(%esp)
f0100964:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100967:	89 44 24 10          	mov    %eax,0x10(%esp)
f010096b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010096e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100972:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100976:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010097a:	c7 04 24 ac 6d 10 f0 	movl   $0xf0106dac,(%esp)
f0100981:	e8 53 33 00 00       	call   f0103cd9 <cprintf>
		ebp,eip,args[0],args[1],args[2],args[3],args[4]);
	ebp =*((unsigned int*)ebp);
f0100986:	8b 1b                	mov    (%ebx),%ebx
	}while(ebp!=0);
f0100988:	85 db                	test   %ebx,%ebx
f010098a:	75 ab                	jne    f0100937 <mon_backtrace+0x15>
	return 0;
}
f010098c:	b8 00 00 00 00       	mov    $0x0,%eax
f0100991:	83 c4 44             	add    $0x44,%esp
f0100994:	5b                   	pop    %ebx
f0100995:	5d                   	pop    %ebp
f0100996:	c3                   	ret    

f0100997 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f0100997:	55                   	push   %ebp
f0100998:	89 e5                	mov    %esp,%ebp
f010099a:	57                   	push   %edi
f010099b:	56                   	push   %esi
f010099c:	53                   	push   %ebx
f010099d:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01009a0:	c7 04 24 e0 6d 10 f0 	movl   $0xf0106de0,(%esp)
f01009a7:	e8 2d 33 00 00       	call   f0103cd9 <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009ac:	c7 04 24 04 6e 10 f0 	movl   $0xf0106e04,(%esp)
f01009b3:	e8 21 33 00 00       	call   f0103cd9 <cprintf>

	if (tf != NULL)
f01009b8:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009bc:	74 0b                	je     f01009c9 <monitor+0x32>
		print_trapframe(tf);
f01009be:	8b 45 08             	mov    0x8(%ebp),%eax
f01009c1:	89 04 24             	mov    %eax,(%esp)
f01009c4:	e8 7a 37 00 00       	call   f0104143 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009c9:	c7 04 24 8c 6c 10 f0 	movl   $0xf0106c8c,(%esp)
f01009d0:	e8 8b 4e 00 00       	call   f0105860 <readline>
f01009d5:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f01009d7:	85 c0                	test   %eax,%eax
f01009d9:	74 ee                	je     f01009c9 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f01009db:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f01009e2:	be 00 00 00 00       	mov    $0x0,%esi
f01009e7:	eb 0a                	jmp    f01009f3 <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f01009e9:	c6 03 00             	movb   $0x0,(%ebx)
f01009ec:	89 f7                	mov    %esi,%edi
f01009ee:	8d 5b 01             	lea    0x1(%ebx),%ebx
f01009f1:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f01009f3:	0f b6 03             	movzbl (%ebx),%eax
f01009f6:	84 c0                	test   %al,%al
f01009f8:	74 6a                	je     f0100a64 <monitor+0xcd>
f01009fa:	0f be c0             	movsbl %al,%eax
f01009fd:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a01:	c7 04 24 90 6c 10 f0 	movl   $0xf0106c90,(%esp)
f0100a08:	e8 cc 50 00 00       	call   f0105ad9 <strchr>
f0100a0d:	85 c0                	test   %eax,%eax
f0100a0f:	75 d8                	jne    f01009e9 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a11:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a14:	74 4e                	je     f0100a64 <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a16:	83 fe 0f             	cmp    $0xf,%esi
f0100a19:	75 16                	jne    f0100a31 <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a1b:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a22:	00 
f0100a23:	c7 04 24 95 6c 10 f0 	movl   $0xf0106c95,(%esp)
f0100a2a:	e8 aa 32 00 00       	call   f0103cd9 <cprintf>
f0100a2f:	eb 98                	jmp    f01009c9 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a31:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a34:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a38:	0f b6 03             	movzbl (%ebx),%eax
f0100a3b:	84 c0                	test   %al,%al
f0100a3d:	75 0c                	jne    f0100a4b <monitor+0xb4>
f0100a3f:	eb b0                	jmp    f01009f1 <monitor+0x5a>
			buf++;
f0100a41:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a44:	0f b6 03             	movzbl (%ebx),%eax
f0100a47:	84 c0                	test   %al,%al
f0100a49:	74 a6                	je     f01009f1 <monitor+0x5a>
f0100a4b:	0f be c0             	movsbl %al,%eax
f0100a4e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a52:	c7 04 24 90 6c 10 f0 	movl   $0xf0106c90,(%esp)
f0100a59:	e8 7b 50 00 00       	call   f0105ad9 <strchr>
f0100a5e:	85 c0                	test   %eax,%eax
f0100a60:	74 df                	je     f0100a41 <monitor+0xaa>
f0100a62:	eb 8d                	jmp    f01009f1 <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100a64:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100a6b:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100a6c:	85 f6                	test   %esi,%esi
f0100a6e:	0f 84 55 ff ff ff    	je     f01009c9 <monitor+0x32>
f0100a74:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100a79:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100a7c:	8b 04 85 40 6e 10 f0 	mov    -0xfef91c0(,%eax,4),%eax
f0100a83:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a87:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100a8a:	89 04 24             	mov    %eax,(%esp)
f0100a8d:	e8 c3 4f 00 00       	call   f0105a55 <strcmp>
f0100a92:	85 c0                	test   %eax,%eax
f0100a94:	75 24                	jne    f0100aba <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100a96:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100a99:	8b 55 08             	mov    0x8(%ebp),%edx
f0100a9c:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100aa0:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100aa3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100aa7:	89 34 24             	mov    %esi,(%esp)
f0100aaa:	ff 14 85 48 6e 10 f0 	call   *-0xfef91b8(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100ab1:	85 c0                	test   %eax,%eax
f0100ab3:	78 25                	js     f0100ada <monitor+0x143>
f0100ab5:	e9 0f ff ff ff       	jmp    f01009c9 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100aba:	83 c3 01             	add    $0x1,%ebx
f0100abd:	83 fb 03             	cmp    $0x3,%ebx
f0100ac0:	75 b7                	jne    f0100a79 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100ac2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ac5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ac9:	c7 04 24 b2 6c 10 f0 	movl   $0xf0106cb2,(%esp)
f0100ad0:	e8 04 32 00 00       	call   f0103cd9 <cprintf>
f0100ad5:	e9 ef fe ff ff       	jmp    f01009c9 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100ada:	83 c4 5c             	add    $0x5c,%esp
f0100add:	5b                   	pop    %ebx
f0100ade:	5e                   	pop    %esi
f0100adf:	5f                   	pop    %edi
f0100ae0:	5d                   	pop    %ebp
f0100ae1:	c3                   	ret    

f0100ae2 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100ae2:	55                   	push   %ebp
f0100ae3:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100ae5:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100ae8:	5d                   	pop    %ebp
f0100ae9:	c3                   	ret    
f0100aea:	66 90                	xchg   %ax,%ax
f0100aec:	66 90                	xchg   %ax,%ax
f0100aee:	66 90                	xchg   %ax,%ax

f0100af0 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100af0:	55                   	push   %ebp
f0100af1:	89 e5                	mov    %esp,%ebp
f0100af3:	56                   	push   %esi
f0100af4:	53                   	push   %ebx
f0100af5:	83 ec 10             	sub    $0x10,%esp
f0100af8:	89 c3                	mov    %eax,%ebx
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100afa:	83 3d 38 62 22 f0 00 	cmpl   $0x0,0xf0226238
f0100b01:	75 0f                	jne    f0100b12 <boot_alloc+0x22>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b03:	b8 03 90 26 f0       	mov    $0xf0269003,%eax
f0100b08:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b0d:	a3 38 62 22 f0       	mov    %eax,0xf0226238
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.

	// Assuming
	cprintf("boot_alloc @: %p\n", nextfree);
f0100b12:	a1 38 62 22 f0       	mov    0xf0226238,%eax
f0100b17:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b1b:	c7 04 24 64 6e 10 f0 	movl   $0xf0106e64,(%esp)
f0100b22:	e8 b2 31 00 00       	call   f0103cd9 <cprintf>
	if(n == 0) return nextfree;
f0100b27:	a1 38 62 22 f0       	mov    0xf0226238,%eax
f0100b2c:	85 db                	test   %ebx,%ebx
f0100b2e:	74 29                	je     f0100b59 <boot_alloc+0x69>
	void* first_address = nextfree;
f0100b30:	8b 35 38 62 22 f0    	mov    0xf0226238,%esi
	nextfree += n;
	nextfree = ROUNDUP(nextfree, PGSIZE);
f0100b36:	8d 84 1e ff 0f 00 00 	lea    0xfff(%esi,%ebx,1),%eax
f0100b3d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b42:	a3 38 62 22 f0       	mov    %eax,0xf0226238
	cprintf("after boot_alloc, nextfree @: %p\n", nextfree);
f0100b47:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b4b:	c7 04 24 fc 71 10 f0 	movl   $0xf01071fc,(%esp)
f0100b52:	e8 82 31 00 00       	call   f0103cd9 <cprintf>

	return first_address;
f0100b57:	89 f0                	mov    %esi,%eax
}
f0100b59:	83 c4 10             	add    $0x10,%esp
f0100b5c:	5b                   	pop    %ebx
f0100b5d:	5e                   	pop    %esi
f0100b5e:	5d                   	pop    %ebp
f0100b5f:	c3                   	ret    

f0100b60 <page2kva>:
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b60:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f0100b66:	c1 f8 03             	sar    $0x3,%eax
f0100b69:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b6c:	89 c2                	mov    %eax,%edx
f0100b6e:	c1 ea 0c             	shr    $0xc,%edx
f0100b71:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f0100b77:	72 26                	jb     f0100b9f <page2kva+0x3f>
	return &pages[PGNUM(pa)];
}

static inline void*
page2kva(struct Page *pp)
{
f0100b79:	55                   	push   %ebp
f0100b7a:	89 e5                	mov    %esp,%ebp
f0100b7c:	83 ec 18             	sub    $0x18,%esp

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b7f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b83:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0100b8a:	f0 
f0100b8b:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100b92:	00 
f0100b93:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0100b9a:	e8 a1 f4 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100b9f:	2d 00 00 00 10       	sub    $0x10000000,%eax

static inline void*
page2kva(struct Page *pp)
{
	return KADDR(page2pa(pp));
}
f0100ba4:	c3                   	ret    

f0100ba5 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100ba5:	89 d1                	mov    %edx,%ecx
f0100ba7:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100baa:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100bad:	a8 01                	test   $0x1,%al
f0100baf:	74 5d                	je     f0100c0e <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100bb1:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100bb6:	89 c1                	mov    %eax,%ecx
f0100bb8:	c1 e9 0c             	shr    $0xc,%ecx
f0100bbb:	3b 0d 88 6e 22 f0    	cmp    0xf0226e88,%ecx
f0100bc1:	72 26                	jb     f0100be9 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100bc3:	55                   	push   %ebp
f0100bc4:	89 e5                	mov    %esp,%ebp
f0100bc6:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100bc9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bcd:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0100bd4:	f0 
f0100bd5:	c7 44 24 04 b4 03 00 	movl   $0x3b4,0x4(%esp)
f0100bdc:	00 
f0100bdd:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100be4:	e8 57 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100be9:	c1 ea 0c             	shr    $0xc,%edx
f0100bec:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100bf2:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100bf9:	89 c2                	mov    %eax,%edx
f0100bfb:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100bfe:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100c03:	85 d2                	test   %edx,%edx
f0100c05:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100c0a:	0f 44 c2             	cmove  %edx,%eax
f0100c0d:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100c0e:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100c13:	c3                   	ret    

f0100c14 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100c14:	55                   	push   %ebp
f0100c15:	89 e5                	mov    %esp,%ebp
f0100c17:	57                   	push   %edi
f0100c18:	56                   	push   %esi
f0100c19:	53                   	push   %ebx
f0100c1a:	83 ec 4c             	sub    $0x4c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c1d:	85 c0                	test   %eax,%eax
f0100c1f:	0f 85 78 03 00 00    	jne    f0100f9d <check_page_free_list+0x389>
f0100c25:	e9 85 03 00 00       	jmp    f0100faf <check_page_free_list+0x39b>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c2a:	c7 44 24 08 20 72 10 	movl   $0xf0107220,0x8(%esp)
f0100c31:	f0 
f0100c32:	c7 44 24 04 e5 02 00 	movl   $0x2e5,0x4(%esp)
f0100c39:	00 
f0100c3a:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100c41:	e8 fa f3 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100c46:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c49:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c4c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c4f:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c52:	89 c2                	mov    %eax,%edx
f0100c54:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c5a:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c60:	0f 95 c2             	setne  %dl
f0100c63:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c66:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c6a:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c6c:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c70:	8b 00                	mov    (%eax),%eax
f0100c72:	85 c0                	test   %eax,%eax
f0100c74:	75 dc                	jne    f0100c52 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c76:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c79:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c7f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c82:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c85:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100c87:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100c8a:	a3 40 62 22 f0       	mov    %eax,0xf0226240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c8f:	89 c3                	mov    %eax,%ebx
f0100c91:	85 c0                	test   %eax,%eax
f0100c93:	74 6c                	je     f0100d01 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c95:	be 01 00 00 00       	mov    $0x1,%esi
f0100c9a:	89 d8                	mov    %ebx,%eax
f0100c9c:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f0100ca2:	c1 f8 03             	sar    $0x3,%eax
f0100ca5:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100ca8:	89 c2                	mov    %eax,%edx
f0100caa:	c1 ea 16             	shr    $0x16,%edx
f0100cad:	39 f2                	cmp    %esi,%edx
f0100caf:	73 4a                	jae    f0100cfb <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cb1:	89 c2                	mov    %eax,%edx
f0100cb3:	c1 ea 0c             	shr    $0xc,%edx
f0100cb6:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f0100cbc:	72 20                	jb     f0100cde <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cbe:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100cc2:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0100cc9:	f0 
f0100cca:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100cd1:	00 
f0100cd2:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0100cd9:	e8 62 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100cde:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100ce5:	00 
f0100ce6:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100ced:	00 
	return (void *)(pa + KERNBASE);
f0100cee:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100cf3:	89 04 24             	mov    %eax,(%esp)
f0100cf6:	e8 3e 4e 00 00       	call   f0105b39 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100cfb:	8b 1b                	mov    (%ebx),%ebx
f0100cfd:	85 db                	test   %ebx,%ebx
f0100cff:	75 99                	jne    f0100c9a <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100d01:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d06:	e8 e5 fd ff ff       	call   f0100af0 <boot_alloc>
f0100d0b:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d0e:	8b 15 40 62 22 f0    	mov    0xf0226240,%edx
f0100d14:	85 d2                	test   %edx,%edx
f0100d16:	0f 84 27 02 00 00    	je     f0100f43 <check_page_free_list+0x32f>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d1c:	8b 3d 90 6e 22 f0    	mov    0xf0226e90,%edi
f0100d22:	39 fa                	cmp    %edi,%edx
f0100d24:	72 3f                	jb     f0100d65 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100d26:	a1 88 6e 22 f0       	mov    0xf0226e88,%eax
f0100d2b:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100d2e:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100d31:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100d34:	39 c2                	cmp    %eax,%edx
f0100d36:	73 56                	jae    f0100d8e <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d38:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100d3b:	89 d0                	mov    %edx,%eax
f0100d3d:	29 f8                	sub    %edi,%eax
f0100d3f:	a8 07                	test   $0x7,%al
f0100d41:	75 78                	jne    f0100dbb <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d43:	c1 f8 03             	sar    $0x3,%eax
f0100d46:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d49:	85 c0                	test   %eax,%eax
f0100d4b:	0f 84 98 00 00 00    	je     f0100de9 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d51:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d56:	0f 85 dc 00 00 00    	jne    f0100e38 <check_page_free_list+0x224>
f0100d5c:	e9 b3 00 00 00       	jmp    f0100e14 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d61:	39 d7                	cmp    %edx,%edi
f0100d63:	76 24                	jbe    f0100d89 <check_page_free_list+0x175>
f0100d65:	c7 44 24 0c 90 6e 10 	movl   $0xf0106e90,0xc(%esp)
f0100d6c:	f0 
f0100d6d:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100d74:	f0 
f0100d75:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0100d7c:	00 
f0100d7d:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100d84:	e8 b7 f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d89:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100d8c:	72 24                	jb     f0100db2 <check_page_free_list+0x19e>
f0100d8e:	c7 44 24 0c b1 6e 10 	movl   $0xf0106eb1,0xc(%esp)
f0100d95:	f0 
f0100d96:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100d9d:	f0 
f0100d9e:	c7 44 24 04 00 03 00 	movl   $0x300,0x4(%esp)
f0100da5:	00 
f0100da6:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100dad:	e8 8e f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100db2:	89 d0                	mov    %edx,%eax
f0100db4:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100db7:	a8 07                	test   $0x7,%al
f0100db9:	74 24                	je     f0100ddf <check_page_free_list+0x1cb>
f0100dbb:	c7 44 24 0c 44 72 10 	movl   $0xf0107244,0xc(%esp)
f0100dc2:	f0 
f0100dc3:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100dca:	f0 
f0100dcb:	c7 44 24 04 01 03 00 	movl   $0x301,0x4(%esp)
f0100dd2:	00 
f0100dd3:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100dda:	e8 61 f2 ff ff       	call   f0100040 <_panic>
f0100ddf:	c1 f8 03             	sar    $0x3,%eax
f0100de2:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100de5:	85 c0                	test   %eax,%eax
f0100de7:	75 24                	jne    f0100e0d <check_page_free_list+0x1f9>
f0100de9:	c7 44 24 0c c5 6e 10 	movl   $0xf0106ec5,0xc(%esp)
f0100df0:	f0 
f0100df1:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100df8:	f0 
f0100df9:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
f0100e00:	00 
f0100e01:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100e08:	e8 33 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100e0d:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100e12:	75 31                	jne    f0100e45 <check_page_free_list+0x231>
f0100e14:	c7 44 24 0c d6 6e 10 	movl   $0xf0106ed6,0xc(%esp)
f0100e1b:	f0 
f0100e1c:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100e23:	f0 
f0100e24:	c7 44 24 04 05 03 00 	movl   $0x305,0x4(%esp)
f0100e2b:	00 
f0100e2c:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100e33:	e8 08 f2 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e38:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100e3d:	be 00 00 00 00       	mov    $0x0,%esi
f0100e42:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e45:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e4a:	75 24                	jne    f0100e70 <check_page_free_list+0x25c>
f0100e4c:	c7 44 24 0c 78 72 10 	movl   $0xf0107278,0xc(%esp)
f0100e53:	f0 
f0100e54:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100e5b:	f0 
f0100e5c:	c7 44 24 04 06 03 00 	movl   $0x306,0x4(%esp)
f0100e63:	00 
f0100e64:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100e6b:	e8 d0 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e70:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e75:	75 24                	jne    f0100e9b <check_page_free_list+0x287>
f0100e77:	c7 44 24 0c ef 6e 10 	movl   $0xf0106eef,0xc(%esp)
f0100e7e:	f0 
f0100e7f:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100e86:	f0 
f0100e87:	c7 44 24 04 07 03 00 	movl   $0x307,0x4(%esp)
f0100e8e:	00 
f0100e8f:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100e96:	e8 a5 f1 ff ff       	call   f0100040 <_panic>
f0100e9b:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100e9d:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100ea2:	0f 86 15 01 00 00    	jbe    f0100fbd <check_page_free_list+0x3a9>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ea8:	89 c3                	mov    %eax,%ebx
f0100eaa:	c1 eb 0c             	shr    $0xc,%ebx
f0100ead:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100eb0:	77 20                	ja     f0100ed2 <check_page_free_list+0x2be>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100eb2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100eb6:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0100ebd:	f0 
f0100ebe:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ec5:	00 
f0100ec6:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0100ecd:	e8 6e f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ed2:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100ed8:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100edb:	0f 86 ec 00 00 00    	jbe    f0100fcd <check_page_free_list+0x3b9>
f0100ee1:	c7 44 24 0c 9c 72 10 	movl   $0xf010729c,0xc(%esp)
f0100ee8:	f0 
f0100ee9:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100ef0:	f0 
f0100ef1:	c7 44 24 04 08 03 00 	movl   $0x308,0x4(%esp)
f0100ef8:	00 
f0100ef9:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100f00:	e8 3b f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f05:	c7 44 24 0c 09 6f 10 	movl   $0xf0106f09,0xc(%esp)
f0100f0c:	f0 
f0100f0d:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100f14:	f0 
f0100f15:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f0100f1c:	00 
f0100f1d:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100f24:	e8 17 f1 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f29:	83 c6 01             	add    $0x1,%esi
f0100f2c:	eb 04                	jmp    f0100f32 <check_page_free_list+0x31e>
		else
			++nfree_extmem;
f0100f2e:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f32:	8b 12                	mov    (%edx),%edx
f0100f34:	85 d2                	test   %edx,%edx
f0100f36:	0f 85 25 fe ff ff    	jne    f0100d61 <check_page_free_list+0x14d>
f0100f3c:	8b 5d cc             	mov    -0x34(%ebp),%ebx
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100f3f:	85 f6                	test   %esi,%esi
f0100f41:	7f 24                	jg     f0100f67 <check_page_free_list+0x353>
f0100f43:	c7 44 24 0c 26 6f 10 	movl   $0xf0106f26,0xc(%esp)
f0100f4a:	f0 
f0100f4b:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100f52:	f0 
f0100f53:	c7 44 24 04 12 03 00 	movl   $0x312,0x4(%esp)
f0100f5a:	00 
f0100f5b:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100f62:	e8 d9 f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f67:	85 db                	test   %ebx,%ebx
f0100f69:	7f 24                	jg     f0100f8f <check_page_free_list+0x37b>
f0100f6b:	c7 44 24 0c 38 6f 10 	movl   $0xf0106f38,0xc(%esp)
f0100f72:	f0 
f0100f73:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0100f7a:	f0 
f0100f7b:	c7 44 24 04 13 03 00 	movl   $0x313,0x4(%esp)
f0100f82:	00 
f0100f83:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0100f8a:	e8 b1 f0 ff ff       	call   f0100040 <_panic>
	cprintf("check_page_free_list_done\n");
f0100f8f:	c7 04 24 49 6f 10 f0 	movl   $0xf0106f49,(%esp)
f0100f96:	e8 3e 2d 00 00       	call   f0103cd9 <cprintf>
f0100f9b:	eb 50                	jmp    f0100fed <check_page_free_list+0x3d9>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100f9d:	a1 40 62 22 f0       	mov    0xf0226240,%eax
f0100fa2:	85 c0                	test   %eax,%eax
f0100fa4:	0f 85 9c fc ff ff    	jne    f0100c46 <check_page_free_list+0x32>
f0100faa:	e9 7b fc ff ff       	jmp    f0100c2a <check_page_free_list+0x16>
f0100faf:	83 3d 40 62 22 f0 00 	cmpl   $0x0,0xf0226240
f0100fb6:	75 25                	jne    f0100fdd <check_page_free_list+0x3c9>
f0100fb8:	e9 6d fc ff ff       	jmp    f0100c2a <check_page_free_list+0x16>
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100fbd:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fc2:	0f 85 61 ff ff ff    	jne    f0100f29 <check_page_free_list+0x315>
f0100fc8:	e9 38 ff ff ff       	jmp    f0100f05 <check_page_free_list+0x2f1>
f0100fcd:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fd2:	0f 85 56 ff ff ff    	jne    f0100f2e <check_page_free_list+0x31a>
f0100fd8:	e9 28 ff ff ff       	jmp    f0100f05 <check_page_free_list+0x2f1>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100fdd:	8b 1d 40 62 22 f0    	mov    0xf0226240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100fe3:	be 00 04 00 00       	mov    $0x400,%esi
f0100fe8:	e9 ad fc ff ff       	jmp    f0100c9a <check_page_free_list+0x86>
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
	cprintf("check_page_free_list_done\n");
}
f0100fed:	83 c4 4c             	add    $0x4c,%esp
f0100ff0:	5b                   	pop    %ebx
f0100ff1:	5e                   	pop    %esi
f0100ff2:	5f                   	pop    %edi
f0100ff3:	5d                   	pop    %ebp
f0100ff4:	c3                   	ret    

f0100ff5 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100ff5:	55                   	push   %ebp
f0100ff6:	89 e5                	mov    %esp,%ebp
f0100ff8:	56                   	push   %esi
f0100ff9:	53                   	push   %ebx
f0100ffa:	83 ec 10             	sub    $0x10,%esp
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ffd:	83 3d 88 6e 22 f0 07 	cmpl   $0x7,0xf0226e88
f0101004:	77 1c                	ja     f0101022 <page_init+0x2d>
		panic("pa2page called with invalid pa");
f0101006:	c7 44 24 08 e4 72 10 	movl   $0xf01072e4,0x8(%esp)
f010100d:	f0 
f010100e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101015:	00 
f0101016:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f010101d:	e8 1e f0 ff ff       	call   f0100040 <_panic>
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
f0101022:	a1 90 6e 22 f0       	mov    0xf0226e90,%eax
f0101027:	8d 70 38             	lea    0x38(%eax),%esi
	for (i; i < npages_basemem; i++) {
f010102a:	83 3d 44 62 22 f0 01 	cmpl   $0x1,0xf0226244
f0101031:	76 4b                	jbe    f010107e <page_init+0x89>
	//     page tables and other data structures?
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
f0101033:	bb 01 00 00 00       	mov    $0x1,%ebx
f0101038:	8d 14 dd 00 00 00 00 	lea    0x0(,%ebx,8),%edx
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
		if(pages + i == page_mpentry) 
f010103f:	89 d0                	mov    %edx,%eax
f0101041:	03 05 90 6e 22 f0    	add    0xf0226e90,%eax
f0101047:	39 f0                	cmp    %esi,%eax
f0101049:	75 0e                	jne    f0101059 <page_init+0x64>
		{
			cprintf("MPENTRY detected!\n");
f010104b:	c7 04 24 64 6f 10 f0 	movl   $0xf0106f64,(%esp)
f0101052:	e8 82 2c 00 00       	call   f0103cd9 <cprintf>
			continue;
f0101057:	eb 1a                	jmp    f0101073 <page_init+0x7e>
		}
		pages[i].pp_ref = 0;
f0101059:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
		pages[i].pp_link = page_free_list;
f010105f:	8b 0d 40 62 22 f0    	mov    0xf0226240,%ecx
f0101065:	89 08                	mov    %ecx,(%eax)
		page_free_list = &pages[i];
f0101067:	03 15 90 6e 22 f0    	add    0xf0226e90,%edx
f010106d:	89 15 40 62 22 f0    	mov    %edx,0xf0226240
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
f0101073:	83 c3 01             	add    $0x1,%ebx
f0101076:	39 1d 44 62 22 f0    	cmp    %ebx,0xf0226244
f010107c:	77 ba                	ja     f0101038 <page_init+0x43>
		page_free_list = &pages[i];
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f010107e:	8b 0d 88 6e 22 f0    	mov    0xf0226e88,%ecx
f0101084:	a1 90 6e 22 f0       	mov    0xf0226e90,%eax
f0101089:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0101090:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0101095:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010109b:	85 c0                	test   %eax,%eax
f010109d:	0f 48 c2             	cmovs  %edx,%eax
f01010a0:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f01010a3:	89 c2                	mov    %eax,%edx
f01010a5:	39 c1                	cmp    %eax,%ecx
f01010a7:	76 39                	jbe    f01010e2 <page_init+0xed>
f01010a9:	8b 1d 40 62 22 f0    	mov    0xf0226240,%ebx
f01010af:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f01010b2:	89 c1                	mov    %eax,%ecx
f01010b4:	03 0d 90 6e 22 f0    	add    0xf0226e90,%ecx
f01010ba:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f01010c0:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f01010c2:	89 c1                	mov    %eax,%ecx
f01010c4:	03 0d 90 6e 22 f0    	add    0xf0226e90,%ecx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f01010ca:	83 c2 01             	add    $0x1,%edx
f01010cd:	83 c0 08             	add    $0x8,%eax
f01010d0:	39 15 88 6e 22 f0    	cmp    %edx,0xf0226e88
f01010d6:	76 04                	jbe    f01010dc <page_init+0xe7>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f01010d8:	89 cb                	mov    %ecx,%ebx
f01010da:	eb d6                	jmp    f01010b2 <page_init+0xbd>
f01010dc:	89 0d 40 62 22 f0    	mov    %ecx,0xf0226240
	}

}
f01010e2:	83 c4 10             	add    $0x10,%esp
f01010e5:	5b                   	pop    %ebx
f01010e6:	5e                   	pop    %esi
f01010e7:	5d                   	pop    %ebp
f01010e8:	c3                   	ret    

f01010e9 <page_alloc>:
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
	// Fill this function in
	if(page_free_list == NULL) return NULL;
f01010e9:	a1 40 62 22 f0       	mov    0xf0226240,%eax
f01010ee:	85 c0                	test   %eax,%eax
f01010f0:	74 71                	je     f0101163 <page_alloc+0x7a>
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f01010f2:	55                   	push   %ebp
f01010f3:	89 e5                	mov    %esp,%ebp
f01010f5:	83 ec 18             	sub    $0x18,%esp
	// Fill this function in
	if(page_free_list == NULL) return NULL;
	if(alloc_flags & ALLOC_ZERO)
f01010f8:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f01010fc:	74 56                	je     f0101154 <page_alloc+0x6b>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01010fe:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f0101104:	c1 f8 03             	sar    $0x3,%eax
f0101107:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010110a:	89 c2                	mov    %eax,%edx
f010110c:	c1 ea 0c             	shr    $0xc,%edx
f010110f:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f0101115:	72 20                	jb     f0101137 <page_alloc+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101117:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010111b:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0101122:	f0 
f0101123:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010112a:	00 
f010112b:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0101132:	e8 09 ef ff ff       	call   f0100040 <_panic>
		memset(page2kva(page_free_list), 0, PGSIZE);
f0101137:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010113e:	00 
f010113f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101146:	00 
	return (void *)(pa + KERNBASE);
f0101147:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010114c:	89 04 24             	mov    %eax,(%esp)
f010114f:	e8 e5 49 00 00       	call   f0105b39 <memset>
	struct Page* allocated = page_free_list;
f0101154:	a1 40 62 22 f0       	mov    0xf0226240,%eax
	//cprintf("--- page_alloc: Allocating new page at va: %x, pa: %x\n", page2kva(page_free_list), page2pa(page_free_list));
	page_free_list = page_free_list->pp_link;
f0101159:	8b 10                	mov    (%eax),%edx
f010115b:	89 15 40 62 22 f0    	mov    %edx,0xf0226240

	return allocated;
f0101161:	eb 06                	jmp    f0101169 <page_alloc+0x80>
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
	// Fill this function in
	if(page_free_list == NULL) return NULL;
f0101163:	b8 00 00 00 00       	mov    $0x0,%eax
f0101168:	c3                   	ret    
	struct Page* allocated = page_free_list;
	//cprintf("--- page_alloc: Allocating new page at va: %x, pa: %x\n", page2kva(page_free_list), page2pa(page_free_list));
	page_free_list = page_free_list->pp_link;

	return allocated;
}
f0101169:	c9                   	leave  
f010116a:	c3                   	ret    

f010116b <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f010116b:	55                   	push   %ebp
f010116c:	89 e5                	mov    %esp,%ebp
f010116e:	83 ec 18             	sub    $0x18,%esp
f0101171:	8b 45 08             	mov    0x8(%ebp),%eax
	// Fill this function in
	if(pp == NULL) panic("page_free: page point equals to zero\n");
f0101174:	85 c0                	test   %eax,%eax
f0101176:	75 1c                	jne    f0101194 <page_free+0x29>
f0101178:	c7 44 24 08 04 73 10 	movl   $0xf0107304,0x8(%esp)
f010117f:	f0 
f0101180:	c7 44 24 04 a7 01 00 	movl   $0x1a7,0x4(%esp)
f0101187:	00 
f0101188:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010118f:	e8 ac ee ff ff       	call   f0100040 <_panic>
	pp->pp_link = page_free_list;
f0101194:	8b 15 40 62 22 f0    	mov    0xf0226240,%edx
f010119a:	89 10                	mov    %edx,(%eax)
	page_free_list = pp;
f010119c:	a3 40 62 22 f0       	mov    %eax,0xf0226240
}
f01011a1:	c9                   	leave  
f01011a2:	c3                   	ret    

f01011a3 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f01011a3:	55                   	push   %ebp
f01011a4:	89 e5                	mov    %esp,%ebp
f01011a6:	83 ec 18             	sub    $0x18,%esp
f01011a9:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f01011ac:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f01011b0:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011b3:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011b7:	66 85 d2             	test   %dx,%dx
f01011ba:	75 08                	jne    f01011c4 <page_decref+0x21>
		page_free(pp);
f01011bc:	89 04 24             	mov    %eax,(%esp)
f01011bf:	e8 a7 ff ff ff       	call   f010116b <page_free>
}
f01011c4:	c9                   	leave  
f01011c5:	c3                   	ret    

f01011c6 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f01011c6:	55                   	push   %ebp
f01011c7:	89 e5                	mov    %esp,%ebp
f01011c9:	56                   	push   %esi
f01011ca:	53                   	push   %ebx
f01011cb:	83 ec 10             	sub    $0x10,%esp
f01011ce:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in

	// Walking in page directory table
	pde_t* page_directory_entry = &pgdir[PDX(va)];
f01011d1:	89 de                	mov    %ebx,%esi
f01011d3:	c1 ee 16             	shr    $0x16,%esi
f01011d6:	c1 e6 02             	shl    $0x2,%esi
f01011d9:	03 75 08             	add    0x8(%ebp),%esi
	//cprintf("pgdir_walk at va=%x, with create=%d\n", va, create);
	if(!((*page_directory_entry) & PTE_P))
f01011dc:	8b 06                	mov    (%esi),%eax
f01011de:	a8 01                	test   $0x1,%al
f01011e0:	75 76                	jne    f0101258 <pgdir_walk+0x92>
	{
		//cprintf("Given page is not exist, allocating new pages\n");
		if(!create) return NULL;
f01011e2:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01011e6:	0f 84 b0 00 00 00    	je     f010129c <pgdir_walk+0xd6>
		// Allocate Page for Page table;
		struct Page* page = page_alloc(ALLOC_ZERO);
f01011ec:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01011f3:	e8 f1 fe ff ff       	call   f01010e9 <page_alloc>
		if(page == NULL)
f01011f8:	85 c0                	test   %eax,%eax
f01011fa:	0f 84 a3 00 00 00    	je     f01012a3 <pgdir_walk+0xdd>
		{
			//cprintf("page_alloc failed, maybe not enough free space.\n");
			return NULL;
		}
		// Increment count reference
		page->pp_ref = 1;
f0101200:	66 c7 40 04 01 00    	movw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101206:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f010120c:	c1 f8 03             	sar    $0x3,%eax
f010120f:	c1 e0 0c             	shl    $0xc,%eax
		// Install page into page directory
		physaddr_t page_addr = page2pa(page);
		*page_directory_entry = 0;
		(*page_directory_entry) |= PTE_U | PTE_W | PTE_P;
		(*page_directory_entry) |= PTE_ADDR(page_addr);
f0101212:	89 c2                	mov    %eax,%edx
f0101214:	83 ca 07             	or     $0x7,%edx
f0101217:	89 16                	mov    %edx,(%esi)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101219:	89 c2                	mov    %eax,%edx
f010121b:	c1 ea 0c             	shr    $0xc,%edx
f010121e:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f0101224:	72 20                	jb     f0101246 <pgdir_walk+0x80>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101226:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010122a:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0101231:	f0 
f0101232:	c7 44 24 04 e7 01 00 	movl   $0x1e7,0x4(%esp)
f0101239:	00 
f010123a:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101241:	e8 fa ed ff ff       	call   f0100040 <_panic>
		return (pte_t*)KADDR(page_addr) + PTX(va);
f0101246:	c1 eb 0a             	shr    $0xa,%ebx
f0101249:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f010124f:	8d 84 18 00 00 00 f0 	lea    -0x10000000(%eax,%ebx,1),%eax
f0101256:	eb 50                	jmp    f01012a8 <pgdir_walk+0xe2>
	}
	pte_t* page_table = KADDR(PTE_ADDR(*page_directory_entry));
f0101258:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010125d:	89 c2                	mov    %eax,%edx
f010125f:	c1 ea 0c             	shr    $0xc,%edx
f0101262:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f0101268:	72 20                	jb     f010128a <pgdir_walk+0xc4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010126a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010126e:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0101275:	f0 
f0101276:	c7 44 24 04 e9 01 00 	movl   $0x1e9,0x4(%esp)
f010127d:	00 
f010127e:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101285:	e8 b6 ed ff ff       	call   f0100040 <_panic>
	return  &page_table[PTX(va)];
f010128a:	c1 eb 0a             	shr    $0xa,%ebx
f010128d:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f0101293:	8d 84 18 00 00 00 f0 	lea    -0x10000000(%eax,%ebx,1),%eax
f010129a:	eb 0c                	jmp    f01012a8 <pgdir_walk+0xe2>
	pde_t* page_directory_entry = &pgdir[PDX(va)];
	//cprintf("pgdir_walk at va=%x, with create=%d\n", va, create);
	if(!((*page_directory_entry) & PTE_P))
	{
		//cprintf("Given page is not exist, allocating new pages\n");
		if(!create) return NULL;
f010129c:	b8 00 00 00 00       	mov    $0x0,%eax
f01012a1:	eb 05                	jmp    f01012a8 <pgdir_walk+0xe2>
		// Allocate Page for Page table;
		struct Page* page = page_alloc(ALLOC_ZERO);
		if(page == NULL)
		{
			//cprintf("page_alloc failed, maybe not enough free space.\n");
			return NULL;
f01012a3:	b8 00 00 00 00       	mov    $0x0,%eax
		(*page_directory_entry) |= PTE_ADDR(page_addr);
		return (pte_t*)KADDR(page_addr) + PTX(va);
	}
	pte_t* page_table = KADDR(PTE_ADDR(*page_directory_entry));
	return  &page_table[PTX(va)];
}
f01012a8:	83 c4 10             	add    $0x10,%esp
f01012ab:	5b                   	pop    %ebx
f01012ac:	5e                   	pop    %esi
f01012ad:	5d                   	pop    %ebp
f01012ae:	c3                   	ret    

f01012af <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f01012af:	55                   	push   %ebp
f01012b0:	89 e5                	mov    %esp,%ebp
f01012b2:	57                   	push   %edi
f01012b3:	56                   	push   %esi
f01012b4:	53                   	push   %ebx
f01012b5:	83 ec 2c             	sub    $0x2c,%esp
	// Fill this function in
	size_t page_count = size / PGSIZE;
f01012b8:	c1 e9 0c             	shr    $0xc,%ecx
f01012bb:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
	size_t i;
	for(i = 0; i < page_count; i++)
f01012be:	85 c9                	test   %ecx,%ecx
f01012c0:	74 4d                	je     f010130f <boot_map_region+0x60>
f01012c2:	89 c7                	mov    %eax,%edi
f01012c4:	89 d3                	mov    %edx,%ebx
f01012c6:	be 00 00 00 00       	mov    $0x0,%esi
	{
		pte_t* page_entry = pgdir_walk(pgdir, (void*)(va + PGSIZE * i), 1);
		(*page_entry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f01012cb:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012ce:	83 c8 01             	or     $0x1,%eax
f01012d1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01012d4:	8b 45 08             	mov    0x8(%ebp),%eax
f01012d7:	29 d0                	sub    %edx,%eax
f01012d9:	89 45 dc             	mov    %eax,-0x24(%ebp)
	// Fill this function in
	size_t page_count = size / PGSIZE;
	size_t i;
	for(i = 0; i < page_count; i++)
	{
		pte_t* page_entry = pgdir_walk(pgdir, (void*)(va + PGSIZE * i), 1);
f01012dc:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01012e3:	00 
f01012e4:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01012e8:	89 3c 24             	mov    %edi,(%esp)
f01012eb:	e8 d6 fe ff ff       	call   f01011c6 <pgdir_walk>
f01012f0:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01012f3:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
		(*page_entry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f01012f6:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f01012fc:	0b 55 e0             	or     -0x20(%ebp),%edx
f01012ff:	89 10                	mov    %edx,(%eax)
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	// Fill this function in
	size_t page_count = size / PGSIZE;
	size_t i;
	for(i = 0; i < page_count; i++)
f0101301:	83 c6 01             	add    $0x1,%esi
f0101304:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010130a:	3b 75 e4             	cmp    -0x1c(%ebp),%esi
f010130d:	75 cd                	jne    f01012dc <boot_map_region+0x2d>
	{
		pte_t* page_entry = pgdir_walk(pgdir, (void*)(va + PGSIZE * i), 1);
		(*page_entry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
		//(*page_entry) |= PTE_ADDR(pa + PGSIZE * i);
	}
}
f010130f:	83 c4 2c             	add    $0x2c,%esp
f0101312:	5b                   	pop    %ebx
f0101313:	5e                   	pop    %esi
f0101314:	5f                   	pop    %edi
f0101315:	5d                   	pop    %ebp
f0101316:	c3                   	ret    

f0101317 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101317:	55                   	push   %ebp
f0101318:	89 e5                	mov    %esp,%ebp
f010131a:	83 ec 18             	sub    $0x18,%esp
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 0);
f010131d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101324:	00 
f0101325:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101328:	89 44 24 04          	mov    %eax,0x4(%esp)
f010132c:	8b 45 08             	mov    0x8(%ebp),%eax
f010132f:	89 04 24             	mov    %eax,(%esp)
f0101332:	e8 8f fe ff ff       	call   f01011c6 <pgdir_walk>
	if(page_table_entry == NULL) return NULL;
f0101337:	85 c0                	test   %eax,%eax
f0101339:	74 39                	je     f0101374 <page_lookup+0x5d>
	*pte_store = page_table_entry;
f010133b:	8b 55 10             	mov    0x10(%ebp),%edx
f010133e:	89 02                	mov    %eax,(%edx)
	return pa2page(PTE_ADDR(*page_table_entry));
f0101340:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101342:	c1 e8 0c             	shr    $0xc,%eax
f0101345:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f010134b:	72 1c                	jb     f0101369 <page_lookup+0x52>
		panic("pa2page called with invalid pa");
f010134d:	c7 44 24 08 e4 72 10 	movl   $0xf01072e4,0x8(%esp)
f0101354:	f0 
f0101355:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010135c:	00 
f010135d:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0101364:	e8 d7 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101369:	8b 15 90 6e 22 f0    	mov    0xf0226e90,%edx
f010136f:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0101372:	eb 05                	jmp    f0101379 <page_lookup+0x62>
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 0);
	if(page_table_entry == NULL) return NULL;
f0101374:	b8 00 00 00 00       	mov    $0x0,%eax
	*pte_store = page_table_entry;
	return pa2page(PTE_ADDR(*page_table_entry));
}
f0101379:	c9                   	leave  
f010137a:	c3                   	ret    

f010137b <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f010137b:	55                   	push   %ebp
f010137c:	89 e5                	mov    %esp,%ebp
f010137e:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f0101381:	e8 4d 4e 00 00       	call   f01061d3 <cpunum>
f0101386:	6b c0 74             	imul   $0x74,%eax,%eax
f0101389:	83 b8 28 70 22 f0 00 	cmpl   $0x0,-0xfdd8fd8(%eax)
f0101390:	74 16                	je     f01013a8 <tlb_invalidate+0x2d>
f0101392:	e8 3c 4e 00 00       	call   f01061d3 <cpunum>
f0101397:	6b c0 74             	imul   $0x74,%eax,%eax
f010139a:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f01013a0:	8b 55 08             	mov    0x8(%ebp),%edx
f01013a3:	39 50 60             	cmp    %edx,0x60(%eax)
f01013a6:	75 06                	jne    f01013ae <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01013a8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01013ab:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f01013ae:	c9                   	leave  
f01013af:	c3                   	ret    

f01013b0 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01013b0:	55                   	push   %ebp
f01013b1:	89 e5                	mov    %esp,%ebp
f01013b3:	56                   	push   %esi
f01013b4:	53                   	push   %ebx
f01013b5:	83 ec 20             	sub    $0x20,%esp
f01013b8:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013bb:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//cprintf("Now unmapping page that mapped to @%x\n", va);
	pte_t* page_table_entry = NULL;
f01013be:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
	struct Page* page = page_lookup(pgdir, va, &page_table_entry);
f01013c5:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01013c8:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013cc:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013d0:	89 1c 24             	mov    %ebx,(%esp)
f01013d3:	e8 3f ff ff ff       	call   f0101317 <page_lookup>
	// va is not mapped
	if(page_table_entry == NULL) return;
f01013d8:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
f01013dc:	74 1d                	je     f01013fb <page_remove+0x4b>

	//decrease pp_ref
	page_decref(page);
f01013de:	89 04 24             	mov    %eax,(%esp)
f01013e1:	e8 bd fd ff ff       	call   f01011a3 <page_decref>

	// remove that entry in page table
	*page_table_entry = 0;
f01013e6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01013e9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

	// refresh tlb
	tlb_invalidate(pgdir, va);
f01013ef:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013f3:	89 1c 24             	mov    %ebx,(%esp)
f01013f6:	e8 80 ff ff ff       	call   f010137b <tlb_invalidate>


}
f01013fb:	83 c4 20             	add    $0x20,%esp
f01013fe:	5b                   	pop    %ebx
f01013ff:	5e                   	pop    %esi
f0101400:	5d                   	pop    %ebp
f0101401:	c3                   	ret    

f0101402 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f0101402:	55                   	push   %ebp
f0101403:	89 e5                	mov    %esp,%ebp
f0101405:	57                   	push   %edi
f0101406:	56                   	push   %esi
f0101407:	53                   	push   %ebx
f0101408:	83 ec 2c             	sub    $0x2c,%esp
f010140b:	8b 75 08             	mov    0x8(%ebp),%esi
f010140e:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101411:	8b 5d 10             	mov    0x10(%ebp),%ebx
	//cprintf("--- page_insert(): called to map page @%x to va %x.\n", page2pa(pp), va);
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 1);
f0101414:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010141b:	00 
f010141c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101420:	89 34 24             	mov    %esi,(%esp)
f0101423:	e8 9e fd ff ff       	call   f01011c6 <pgdir_walk>
	// Out of memory
	if(page_table_entry == NULL) return -E_NO_MEM;
f0101428:	85 c0                	test   %eax,%eax
f010142a:	74 7c                	je     f01014a8 <page_insert+0xa6>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010142c:	89 f8                	mov    %edi,%eax
f010142e:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f0101434:	c1 f8 03             	sar    $0x3,%eax
f0101437:	c1 e0 0c             	shl    $0xc,%eax
f010143a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	// if the map is originally not existe
	/*
	if(((*page_table_entry) & PTE_P) == 0)
		(*page_table_entry) = page_pa | perm | PTE_P;
	*/
	pp->pp_ref += 1;
f010143d:	66 83 47 04 01       	addw   $0x1,0x4(%edi)
	page_remove(pgdir, va);
f0101442:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101446:	89 34 24             	mov    %esi,(%esp)
f0101449:	e8 62 ff ff ff       	call   f01013b0 <page_remove>
	pde_t* page_dir_entry = &pgdir[PDX(va)];
f010144e:	89 d8                	mov    %ebx,%eax
f0101450:	c1 e8 16             	shr    $0x16,%eax
	pte_t* page_table = KADDR(PTE_ADDR(*page_dir_entry));
f0101453:	8b 04 86             	mov    (%esi,%eax,4),%eax
f0101456:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010145b:	89 c2                	mov    %eax,%edx
f010145d:	c1 ea 0c             	shr    $0xc,%edx
f0101460:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f0101466:	72 20                	jb     f0101488 <page_insert+0x86>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101468:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010146c:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0101473:	f0 
f0101474:	c7 44 24 04 34 02 00 	movl   $0x234,0x4(%esp)
f010147b:	00 
f010147c:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101483:	e8 b8 eb ff ff       	call   f0100040 <_panic>
	 page_table_entry = &page_table[PTX(va)];
f0101488:	c1 eb 0c             	shr    $0xc,%ebx
f010148b:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
	*(page_table_entry) = page_pa | perm | PTE_P;
f0101491:	8b 55 14             	mov    0x14(%ebp),%edx
f0101494:	83 ca 01             	or     $0x1,%edx
f0101497:	0b 55 e4             	or     -0x1c(%ebp),%edx
f010149a:	89 94 98 00 00 00 f0 	mov    %edx,-0x10000000(%eax,%ebx,4)

	return 0;
f01014a1:	b8 00 00 00 00       	mov    $0x0,%eax
f01014a6:	eb 05                	jmp    f01014ad <page_insert+0xab>
{
	//cprintf("--- page_insert(): called to map page @%x to va %x.\n", page2pa(pp), va);
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 1);
	// Out of memory
	if(page_table_entry == NULL) return -E_NO_MEM;
f01014a8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	pte_t* page_table = KADDR(PTE_ADDR(*page_dir_entry));
	 page_table_entry = &page_table[PTX(va)];
	*(page_table_entry) = page_pa | perm | PTE_P;

	return 0;
}
f01014ad:	83 c4 2c             	add    $0x2c,%esp
f01014b0:	5b                   	pop    %ebx
f01014b1:	5e                   	pop    %esi
f01014b2:	5f                   	pop    %edi
f01014b3:	5d                   	pop    %ebp
f01014b4:	c3                   	ret    

f01014b5 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01014b5:	55                   	push   %ebp
f01014b6:	89 e5                	mov    %esp,%ebp
f01014b8:	57                   	push   %edi
f01014b9:	56                   	push   %esi
f01014ba:	53                   	push   %ebx
f01014bb:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014be:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01014c5:	e8 a3 26 00 00       	call   f0103b6d <mc146818_read>
f01014ca:	89 c3                	mov    %eax,%ebx
f01014cc:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01014d3:	e8 95 26 00 00       	call   f0103b6d <mc146818_read>
f01014d8:	c1 e0 08             	shl    $0x8,%eax
f01014db:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014dd:	89 d8                	mov    %ebx,%eax
f01014df:	c1 e0 0a             	shl    $0xa,%eax
f01014e2:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014e8:	85 c0                	test   %eax,%eax
f01014ea:	0f 48 c2             	cmovs  %edx,%eax
f01014ed:	c1 f8 0c             	sar    $0xc,%eax
f01014f0:	a3 44 62 22 f0       	mov    %eax,0xf0226244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014f5:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01014fc:	e8 6c 26 00 00       	call   f0103b6d <mc146818_read>
f0101501:	89 c3                	mov    %eax,%ebx
f0101503:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f010150a:	e8 5e 26 00 00       	call   f0103b6d <mc146818_read>
f010150f:	c1 e0 08             	shl    $0x8,%eax
f0101512:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0101514:	89 d8                	mov    %ebx,%eax
f0101516:	c1 e0 0a             	shl    $0xa,%eax
f0101519:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010151f:	85 c0                	test   %eax,%eax
f0101521:	0f 48 c2             	cmovs  %edx,%eax
f0101524:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101527:	85 c0                	test   %eax,%eax
f0101529:	74 0e                	je     f0101539 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f010152b:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0101531:	89 15 88 6e 22 f0    	mov    %edx,0xf0226e88
f0101537:	eb 0c                	jmp    f0101545 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101539:	8b 15 44 62 22 f0    	mov    0xf0226244,%edx
f010153f:	89 15 88 6e 22 f0    	mov    %edx,0xf0226e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101545:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101548:	c1 e8 0a             	shr    $0xa,%eax
f010154b:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f010154f:	a1 44 62 22 f0       	mov    0xf0226244,%eax
f0101554:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101557:	c1 e8 0a             	shr    $0xa,%eax
f010155a:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f010155e:	a1 88 6e 22 f0       	mov    0xf0226e88,%eax
f0101563:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101566:	c1 e8 0a             	shr    $0xa,%eax
f0101569:	89 44 24 04          	mov    %eax,0x4(%esp)
f010156d:	c7 04 24 2c 73 10 f0 	movl   $0xf010732c,(%esp)
f0101574:	e8 60 27 00 00       	call   f0103cd9 <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f0101579:	b8 00 10 00 00       	mov    $0x1000,%eax
f010157e:	e8 6d f5 ff ff       	call   f0100af0 <boot_alloc>
f0101583:	a3 8c 6e 22 f0       	mov    %eax,0xf0226e8c
	memset(kern_pgdir, 0, PGSIZE);
f0101588:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010158f:	00 
f0101590:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101597:	00 
f0101598:	89 04 24             	mov    %eax,(%esp)
f010159b:	e8 99 45 00 00       	call   f0105b39 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015a0:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01015a5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01015aa:	77 20                	ja     f01015cc <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01015ac:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015b0:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f01015b7:	f0 
f01015b8:	c7 44 24 04 95 00 00 	movl   $0x95,0x4(%esp)
f01015bf:	00 
f01015c0:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01015c7:	e8 74 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01015cc:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015d2:	83 ca 05             	or     $0x5,%edx
f01015d5:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate an array of npages 'struct Page's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:
	pages = (struct Page *) boot_alloc(npages * sizeof(struct Page));
f01015db:	a1 88 6e 22 f0       	mov    0xf0226e88,%eax
f01015e0:	c1 e0 03             	shl    $0x3,%eax
f01015e3:	e8 08 f5 ff ff       	call   f0100af0 <boot_alloc>
f01015e8:	a3 90 6e 22 f0       	mov    %eax,0xf0226e90
	cprintf("struct Page size = %d", sizeof(struct Page));
f01015ed:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
f01015f4:	00 
f01015f5:	c7 04 24 77 6f 10 f0 	movl   $0xf0106f77,(%esp)
f01015fc:	e8 d8 26 00 00       	call   f0103cd9 <cprintf>


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs = (struct Env *) boot_alloc(NENV * sizeof(struct Env));
f0101601:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f0101606:	e8 e5 f4 ff ff       	call   f0100af0 <boot_alloc>
f010160b:	a3 48 62 22 f0       	mov    %eax,0xf0226248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101610:	e8 e0 f9 ff ff       	call   f0100ff5 <page_init>

	check_page_free_list(1);
f0101615:	b8 01 00 00 00       	mov    $0x1,%eax
f010161a:	e8 f5 f5 ff ff       	call   f0100c14 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f010161f:	83 3d 90 6e 22 f0 00 	cmpl   $0x0,0xf0226e90
f0101626:	75 1c                	jne    f0101644 <mem_init+0x18f>
		panic("'pages' is a null pointer!");
f0101628:	c7 44 24 08 8d 6f 10 	movl   $0xf0106f8d,0x8(%esp)
f010162f:	f0 
f0101630:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
f0101637:	00 
f0101638:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010163f:	e8 fc e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101644:	a1 40 62 22 f0       	mov    0xf0226240,%eax
f0101649:	85 c0                	test   %eax,%eax
f010164b:	74 10                	je     f010165d <mem_init+0x1a8>
f010164d:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101652:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101655:	8b 00                	mov    (%eax),%eax
f0101657:	85 c0                	test   %eax,%eax
f0101659:	75 f7                	jne    f0101652 <mem_init+0x19d>
f010165b:	eb 05                	jmp    f0101662 <mem_init+0x1ad>
f010165d:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101662:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101669:	e8 7b fa ff ff       	call   f01010e9 <page_alloc>
f010166e:	89 c7                	mov    %eax,%edi
f0101670:	85 c0                	test   %eax,%eax
f0101672:	75 24                	jne    f0101698 <mem_init+0x1e3>
f0101674:	c7 44 24 0c a8 6f 10 	movl   $0xf0106fa8,0xc(%esp)
f010167b:	f0 
f010167c:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101683:	f0 
f0101684:	c7 44 24 04 2d 03 00 	movl   $0x32d,0x4(%esp)
f010168b:	00 
f010168c:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101693:	e8 a8 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101698:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010169f:	e8 45 fa ff ff       	call   f01010e9 <page_alloc>
f01016a4:	89 c6                	mov    %eax,%esi
f01016a6:	85 c0                	test   %eax,%eax
f01016a8:	75 24                	jne    f01016ce <mem_init+0x219>
f01016aa:	c7 44 24 0c be 6f 10 	movl   $0xf0106fbe,0xc(%esp)
f01016b1:	f0 
f01016b2:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01016b9:	f0 
f01016ba:	c7 44 24 04 2e 03 00 	movl   $0x32e,0x4(%esp)
f01016c1:	00 
f01016c2:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01016c9:	e8 72 e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016ce:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016d5:	e8 0f fa ff ff       	call   f01010e9 <page_alloc>
f01016da:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016dd:	85 c0                	test   %eax,%eax
f01016df:	75 24                	jne    f0101705 <mem_init+0x250>
f01016e1:	c7 44 24 0c d4 6f 10 	movl   $0xf0106fd4,0xc(%esp)
f01016e8:	f0 
f01016e9:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01016f0:	f0 
f01016f1:	c7 44 24 04 2f 03 00 	movl   $0x32f,0x4(%esp)
f01016f8:	00 
f01016f9:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101700:	e8 3b e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101705:	39 f7                	cmp    %esi,%edi
f0101707:	75 24                	jne    f010172d <mem_init+0x278>
f0101709:	c7 44 24 0c ea 6f 10 	movl   $0xf0106fea,0xc(%esp)
f0101710:	f0 
f0101711:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101718:	f0 
f0101719:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f0101720:	00 
f0101721:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101728:	e8 13 e9 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010172d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101730:	39 c6                	cmp    %eax,%esi
f0101732:	74 04                	je     f0101738 <mem_init+0x283>
f0101734:	39 c7                	cmp    %eax,%edi
f0101736:	75 24                	jne    f010175c <mem_init+0x2a7>
f0101738:	c7 44 24 0c 68 73 10 	movl   $0xf0107368,0xc(%esp)
f010173f:	f0 
f0101740:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101747:	f0 
f0101748:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
f010174f:	00 
f0101750:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101757:	e8 e4 e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010175c:	8b 15 90 6e 22 f0    	mov    0xf0226e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101762:	a1 88 6e 22 f0       	mov    0xf0226e88,%eax
f0101767:	c1 e0 0c             	shl    $0xc,%eax
f010176a:	89 f9                	mov    %edi,%ecx
f010176c:	29 d1                	sub    %edx,%ecx
f010176e:	c1 f9 03             	sar    $0x3,%ecx
f0101771:	c1 e1 0c             	shl    $0xc,%ecx
f0101774:	39 c1                	cmp    %eax,%ecx
f0101776:	72 24                	jb     f010179c <mem_init+0x2e7>
f0101778:	c7 44 24 0c fc 6f 10 	movl   $0xf0106ffc,0xc(%esp)
f010177f:	f0 
f0101780:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101787:	f0 
f0101788:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
f010178f:	00 
f0101790:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101797:	e8 a4 e8 ff ff       	call   f0100040 <_panic>
f010179c:	89 f1                	mov    %esi,%ecx
f010179e:	29 d1                	sub    %edx,%ecx
f01017a0:	c1 f9 03             	sar    $0x3,%ecx
f01017a3:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01017a6:	39 c8                	cmp    %ecx,%eax
f01017a8:	77 24                	ja     f01017ce <mem_init+0x319>
f01017aa:	c7 44 24 0c 19 70 10 	movl   $0xf0107019,0xc(%esp)
f01017b1:	f0 
f01017b2:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01017b9:	f0 
f01017ba:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f01017c1:	00 
f01017c2:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01017c9:	e8 72 e8 ff ff       	call   f0100040 <_panic>
f01017ce:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017d1:	29 d1                	sub    %edx,%ecx
f01017d3:	89 ca                	mov    %ecx,%edx
f01017d5:	c1 fa 03             	sar    $0x3,%edx
f01017d8:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017db:	39 d0                	cmp    %edx,%eax
f01017dd:	77 24                	ja     f0101803 <mem_init+0x34e>
f01017df:	c7 44 24 0c 36 70 10 	movl   $0xf0107036,0xc(%esp)
f01017e6:	f0 
f01017e7:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01017ee:	f0 
f01017ef:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f01017f6:	00 
f01017f7:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01017fe:	e8 3d e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101803:	a1 40 62 22 f0       	mov    0xf0226240,%eax
f0101808:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f010180b:	c7 05 40 62 22 f0 00 	movl   $0x0,0xf0226240
f0101812:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101815:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010181c:	e8 c8 f8 ff ff       	call   f01010e9 <page_alloc>
f0101821:	85 c0                	test   %eax,%eax
f0101823:	74 24                	je     f0101849 <mem_init+0x394>
f0101825:	c7 44 24 0c 53 70 10 	movl   $0xf0107053,0xc(%esp)
f010182c:	f0 
f010182d:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101834:	f0 
f0101835:	c7 44 24 04 3d 03 00 	movl   $0x33d,0x4(%esp)
f010183c:	00 
f010183d:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101844:	e8 f7 e7 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101849:	89 3c 24             	mov    %edi,(%esp)
f010184c:	e8 1a f9 ff ff       	call   f010116b <page_free>
	page_free(pp1);
f0101851:	89 34 24             	mov    %esi,(%esp)
f0101854:	e8 12 f9 ff ff       	call   f010116b <page_free>
	page_free(pp2);
f0101859:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010185c:	89 04 24             	mov    %eax,(%esp)
f010185f:	e8 07 f9 ff ff       	call   f010116b <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101864:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010186b:	e8 79 f8 ff ff       	call   f01010e9 <page_alloc>
f0101870:	89 c6                	mov    %eax,%esi
f0101872:	85 c0                	test   %eax,%eax
f0101874:	75 24                	jne    f010189a <mem_init+0x3e5>
f0101876:	c7 44 24 0c a8 6f 10 	movl   $0xf0106fa8,0xc(%esp)
f010187d:	f0 
f010187e:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101885:	f0 
f0101886:	c7 44 24 04 44 03 00 	movl   $0x344,0x4(%esp)
f010188d:	00 
f010188e:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101895:	e8 a6 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010189a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018a1:	e8 43 f8 ff ff       	call   f01010e9 <page_alloc>
f01018a6:	89 c7                	mov    %eax,%edi
f01018a8:	85 c0                	test   %eax,%eax
f01018aa:	75 24                	jne    f01018d0 <mem_init+0x41b>
f01018ac:	c7 44 24 0c be 6f 10 	movl   $0xf0106fbe,0xc(%esp)
f01018b3:	f0 
f01018b4:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01018bb:	f0 
f01018bc:	c7 44 24 04 45 03 00 	movl   $0x345,0x4(%esp)
f01018c3:	00 
f01018c4:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01018cb:	e8 70 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018d0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018d7:	e8 0d f8 ff ff       	call   f01010e9 <page_alloc>
f01018dc:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018df:	85 c0                	test   %eax,%eax
f01018e1:	75 24                	jne    f0101907 <mem_init+0x452>
f01018e3:	c7 44 24 0c d4 6f 10 	movl   $0xf0106fd4,0xc(%esp)
f01018ea:	f0 
f01018eb:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01018f2:	f0 
f01018f3:	c7 44 24 04 46 03 00 	movl   $0x346,0x4(%esp)
f01018fa:	00 
f01018fb:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101902:	e8 39 e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101907:	39 fe                	cmp    %edi,%esi
f0101909:	75 24                	jne    f010192f <mem_init+0x47a>
f010190b:	c7 44 24 0c ea 6f 10 	movl   $0xf0106fea,0xc(%esp)
f0101912:	f0 
f0101913:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010191a:	f0 
f010191b:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0101922:	00 
f0101923:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010192a:	e8 11 e7 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010192f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101932:	39 c7                	cmp    %eax,%edi
f0101934:	74 04                	je     f010193a <mem_init+0x485>
f0101936:	39 c6                	cmp    %eax,%esi
f0101938:	75 24                	jne    f010195e <mem_init+0x4a9>
f010193a:	c7 44 24 0c 68 73 10 	movl   $0xf0107368,0xc(%esp)
f0101941:	f0 
f0101942:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101949:	f0 
f010194a:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f0101951:	00 
f0101952:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101959:	e8 e2 e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f010195e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101965:	e8 7f f7 ff ff       	call   f01010e9 <page_alloc>
f010196a:	85 c0                	test   %eax,%eax
f010196c:	74 24                	je     f0101992 <mem_init+0x4dd>
f010196e:	c7 44 24 0c 53 70 10 	movl   $0xf0107053,0xc(%esp)
f0101975:	f0 
f0101976:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010197d:	f0 
f010197e:	c7 44 24 04 4a 03 00 	movl   $0x34a,0x4(%esp)
f0101985:	00 
f0101986:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010198d:	e8 ae e6 ff ff       	call   f0100040 <_panic>
f0101992:	89 f0                	mov    %esi,%eax
f0101994:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f010199a:	c1 f8 03             	sar    $0x3,%eax
f010199d:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01019a0:	89 c2                	mov    %eax,%edx
f01019a2:	c1 ea 0c             	shr    $0xc,%edx
f01019a5:	3b 15 88 6e 22 f0    	cmp    0xf0226e88,%edx
f01019ab:	72 20                	jb     f01019cd <mem_init+0x518>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019ad:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019b1:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f01019b8:	f0 
f01019b9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01019c0:	00 
f01019c1:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f01019c8:	e8 73 e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019cd:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019d4:	00 
f01019d5:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019dc:	00 
	return (void *)(pa + KERNBASE);
f01019dd:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01019e2:	89 04 24             	mov    %eax,(%esp)
f01019e5:	e8 4f 41 00 00       	call   f0105b39 <memset>
	page_free(pp0);
f01019ea:	89 34 24             	mov    %esi,(%esp)
f01019ed:	e8 79 f7 ff ff       	call   f010116b <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01019f2:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01019f9:	e8 eb f6 ff ff       	call   f01010e9 <page_alloc>
f01019fe:	85 c0                	test   %eax,%eax
f0101a00:	75 24                	jne    f0101a26 <mem_init+0x571>
f0101a02:	c7 44 24 0c 62 70 10 	movl   $0xf0107062,0xc(%esp)
f0101a09:	f0 
f0101a0a:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101a11:	f0 
f0101a12:	c7 44 24 04 4f 03 00 	movl   $0x34f,0x4(%esp)
f0101a19:	00 
f0101a1a:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101a21:	e8 1a e6 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a26:	39 c6                	cmp    %eax,%esi
f0101a28:	74 24                	je     f0101a4e <mem_init+0x599>
f0101a2a:	c7 44 24 0c 80 70 10 	movl   $0xf0107080,0xc(%esp)
f0101a31:	f0 
f0101a32:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101a39:	f0 
f0101a3a:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0101a41:	00 
f0101a42:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101a49:	e8 f2 e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a4e:	89 f2                	mov    %esi,%edx
f0101a50:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f0101a56:	c1 fa 03             	sar    $0x3,%edx
f0101a59:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a5c:	89 d0                	mov    %edx,%eax
f0101a5e:	c1 e8 0c             	shr    $0xc,%eax
f0101a61:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f0101a67:	72 20                	jb     f0101a89 <mem_init+0x5d4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a69:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a6d:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0101a74:	f0 
f0101a75:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a7c:	00 
f0101a7d:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0101a84:	e8 b7 e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101a89:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101a90:	75 11                	jne    f0101aa3 <mem_init+0x5ee>
f0101a92:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101a98:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101a9e:	80 38 00             	cmpb   $0x0,(%eax)
f0101aa1:	74 24                	je     f0101ac7 <mem_init+0x612>
f0101aa3:	c7 44 24 0c 90 70 10 	movl   $0xf0107090,0xc(%esp)
f0101aaa:	f0 
f0101aab:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101ab2:	f0 
f0101ab3:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f0101aba:	00 
f0101abb:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101ac2:	e8 79 e5 ff ff       	call   f0100040 <_panic>
f0101ac7:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101aca:	39 d0                	cmp    %edx,%eax
f0101acc:	75 d0                	jne    f0101a9e <mem_init+0x5e9>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101ace:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101ad1:	a3 40 62 22 f0       	mov    %eax,0xf0226240

	// free the pages we took
	page_free(pp0);
f0101ad6:	89 34 24             	mov    %esi,(%esp)
f0101ad9:	e8 8d f6 ff ff       	call   f010116b <page_free>
	page_free(pp1);
f0101ade:	89 3c 24             	mov    %edi,(%esp)
f0101ae1:	e8 85 f6 ff ff       	call   f010116b <page_free>
	page_free(pp2);
f0101ae6:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ae9:	89 04 24             	mov    %eax,(%esp)
f0101aec:	e8 7a f6 ff ff       	call   f010116b <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101af1:	a1 40 62 22 f0       	mov    0xf0226240,%eax
f0101af6:	85 c0                	test   %eax,%eax
f0101af8:	74 09                	je     f0101b03 <mem_init+0x64e>
		--nfree;
f0101afa:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101afd:	8b 00                	mov    (%eax),%eax
f0101aff:	85 c0                	test   %eax,%eax
f0101b01:	75 f7                	jne    f0101afa <mem_init+0x645>
		--nfree;
	assert(nfree == 0);
f0101b03:	85 db                	test   %ebx,%ebx
f0101b05:	74 24                	je     f0101b2b <mem_init+0x676>
f0101b07:	c7 44 24 0c 9a 70 10 	movl   $0xf010709a,0xc(%esp)
f0101b0e:	f0 
f0101b0f:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101b16:	f0 
f0101b17:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
f0101b1e:	00 
f0101b1f:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101b26:	e8 15 e5 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b2b:	c7 04 24 88 73 10 f0 	movl   $0xf0107388,(%esp)
f0101b32:	e8 a2 21 00 00       	call   f0103cd9 <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b37:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b3e:	e8 a6 f5 ff ff       	call   f01010e9 <page_alloc>
f0101b43:	89 c3                	mov    %eax,%ebx
f0101b45:	85 c0                	test   %eax,%eax
f0101b47:	75 24                	jne    f0101b6d <mem_init+0x6b8>
f0101b49:	c7 44 24 0c a8 6f 10 	movl   $0xf0106fa8,0xc(%esp)
f0101b50:	f0 
f0101b51:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101b58:	f0 
f0101b59:	c7 44 24 04 c8 03 00 	movl   $0x3c8,0x4(%esp)
f0101b60:	00 
f0101b61:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101b68:	e8 d3 e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b6d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b74:	e8 70 f5 ff ff       	call   f01010e9 <page_alloc>
f0101b79:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101b7c:	85 c0                	test   %eax,%eax
f0101b7e:	75 24                	jne    f0101ba4 <mem_init+0x6ef>
f0101b80:	c7 44 24 0c be 6f 10 	movl   $0xf0106fbe,0xc(%esp)
f0101b87:	f0 
f0101b88:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101b8f:	f0 
f0101b90:	c7 44 24 04 c9 03 00 	movl   $0x3c9,0x4(%esp)
f0101b97:	00 
f0101b98:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101b9f:	e8 9c e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101ba4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bab:	e8 39 f5 ff ff       	call   f01010e9 <page_alloc>
f0101bb0:	89 c6                	mov    %eax,%esi
f0101bb2:	85 c0                	test   %eax,%eax
f0101bb4:	75 24                	jne    f0101bda <mem_init+0x725>
f0101bb6:	c7 44 24 0c d4 6f 10 	movl   $0xf0106fd4,0xc(%esp)
f0101bbd:	f0 
f0101bbe:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101bc5:	f0 
f0101bc6:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f0101bcd:	00 
f0101bce:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101bd5:	e8 66 e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101bda:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101bdd:	75 24                	jne    f0101c03 <mem_init+0x74e>
f0101bdf:	c7 44 24 0c ea 6f 10 	movl   $0xf0106fea,0xc(%esp)
f0101be6:	f0 
f0101be7:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101bee:	f0 
f0101bef:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f0101bf6:	00 
f0101bf7:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101bfe:	e8 3d e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101c03:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c06:	74 04                	je     f0101c0c <mem_init+0x757>
f0101c08:	39 c3                	cmp    %eax,%ebx
f0101c0a:	75 24                	jne    f0101c30 <mem_init+0x77b>
f0101c0c:	c7 44 24 0c 68 73 10 	movl   $0xf0107368,0xc(%esp)
f0101c13:	f0 
f0101c14:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101c1b:	f0 
f0101c1c:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0101c23:	00 
f0101c24:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101c2b:	e8 10 e4 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c30:	a1 40 62 22 f0       	mov    0xf0226240,%eax
f0101c35:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c38:	c7 05 40 62 22 f0 00 	movl   $0x0,0xf0226240
f0101c3f:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c42:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c49:	e8 9b f4 ff ff       	call   f01010e9 <page_alloc>
f0101c4e:	85 c0                	test   %eax,%eax
f0101c50:	74 24                	je     f0101c76 <mem_init+0x7c1>
f0101c52:	c7 44 24 0c 53 70 10 	movl   $0xf0107053,0xc(%esp)
f0101c59:	f0 
f0101c5a:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101c61:	f0 
f0101c62:	c7 44 24 04 d5 03 00 	movl   $0x3d5,0x4(%esp)
f0101c69:	00 
f0101c6a:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101c71:	e8 ca e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c76:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c79:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c7d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101c84:	00 
f0101c85:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0101c8a:	89 04 24             	mov    %eax,(%esp)
f0101c8d:	e8 85 f6 ff ff       	call   f0101317 <page_lookup>
f0101c92:	85 c0                	test   %eax,%eax
f0101c94:	74 24                	je     f0101cba <mem_init+0x805>
f0101c96:	c7 44 24 0c a8 73 10 	movl   $0xf01073a8,0xc(%esp)
f0101c9d:	f0 
f0101c9e:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101ca5:	f0 
f0101ca6:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f0101cad:	00 
f0101cae:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101cb5:	e8 86 e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101cba:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101cc1:	00 
f0101cc2:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101cc9:	00 
f0101cca:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ccd:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101cd1:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0101cd6:	89 04 24             	mov    %eax,(%esp)
f0101cd9:	e8 24 f7 ff ff       	call   f0101402 <page_insert>
f0101cde:	85 c0                	test   %eax,%eax
f0101ce0:	78 24                	js     f0101d06 <mem_init+0x851>
f0101ce2:	c7 44 24 0c e0 73 10 	movl   $0xf01073e0,0xc(%esp)
f0101ce9:	f0 
f0101cea:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101cf1:	f0 
f0101cf2:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0101cf9:	00 
f0101cfa:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101d01:	e8 3a e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d06:	89 1c 24             	mov    %ebx,(%esp)
f0101d09:	e8 5d f4 ff ff       	call   f010116b <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d0e:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d15:	00 
f0101d16:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d1d:	00 
f0101d1e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d21:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d25:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0101d2a:	89 04 24             	mov    %eax,(%esp)
f0101d2d:	e8 d0 f6 ff ff       	call   f0101402 <page_insert>
f0101d32:	85 c0                	test   %eax,%eax
f0101d34:	74 24                	je     f0101d5a <mem_init+0x8a5>
f0101d36:	c7 44 24 0c 10 74 10 	movl   $0xf0107410,0xc(%esp)
f0101d3d:	f0 
f0101d3e:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101d45:	f0 
f0101d46:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f0101d4d:	00 
f0101d4e:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101d55:	e8 e6 e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d5a:	8b 3d 8c 6e 22 f0    	mov    0xf0226e8c,%edi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d60:	a1 90 6e 22 f0       	mov    0xf0226e90,%eax
f0101d65:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101d68:	8b 17                	mov    (%edi),%edx
f0101d6a:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101d70:	89 d9                	mov    %ebx,%ecx
f0101d72:	29 c1                	sub    %eax,%ecx
f0101d74:	89 c8                	mov    %ecx,%eax
f0101d76:	c1 f8 03             	sar    $0x3,%eax
f0101d79:	c1 e0 0c             	shl    $0xc,%eax
f0101d7c:	39 c2                	cmp    %eax,%edx
f0101d7e:	74 24                	je     f0101da4 <mem_init+0x8ef>
f0101d80:	c7 44 24 0c 40 74 10 	movl   $0xf0107440,0xc(%esp)
f0101d87:	f0 
f0101d88:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101d8f:	f0 
f0101d90:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
f0101d97:	00 
f0101d98:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101d9f:	e8 9c e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101da4:	ba 00 00 00 00       	mov    $0x0,%edx
f0101da9:	89 f8                	mov    %edi,%eax
f0101dab:	e8 f5 ed ff ff       	call   f0100ba5 <check_va2pa>
f0101db0:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101db3:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101db6:	c1 fa 03             	sar    $0x3,%edx
f0101db9:	c1 e2 0c             	shl    $0xc,%edx
f0101dbc:	39 d0                	cmp    %edx,%eax
f0101dbe:	74 24                	je     f0101de4 <mem_init+0x92f>
f0101dc0:	c7 44 24 0c 68 74 10 	movl   $0xf0107468,0xc(%esp)
f0101dc7:	f0 
f0101dc8:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101dcf:	f0 
f0101dd0:	c7 44 24 04 e1 03 00 	movl   $0x3e1,0x4(%esp)
f0101dd7:	00 
f0101dd8:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101ddf:	e8 5c e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101de4:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101de7:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101dec:	74 24                	je     f0101e12 <mem_init+0x95d>
f0101dee:	c7 44 24 0c a5 70 10 	movl   $0xf01070a5,0xc(%esp)
f0101df5:	f0 
f0101df6:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101dfd:	f0 
f0101dfe:	c7 44 24 04 e2 03 00 	movl   $0x3e2,0x4(%esp)
f0101e05:	00 
f0101e06:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101e0d:	e8 2e e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e12:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e17:	74 24                	je     f0101e3d <mem_init+0x988>
f0101e19:	c7 44 24 0c b6 70 10 	movl   $0xf01070b6,0xc(%esp)
f0101e20:	f0 
f0101e21:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101e28:	f0 
f0101e29:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f0101e30:	00 
f0101e31:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101e38:	e8 03 e2 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e3d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e44:	00 
f0101e45:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e4c:	00 
f0101e4d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e51:	89 3c 24             	mov    %edi,(%esp)
f0101e54:	e8 a9 f5 ff ff       	call   f0101402 <page_insert>
f0101e59:	85 c0                	test   %eax,%eax
f0101e5b:	74 24                	je     f0101e81 <mem_init+0x9cc>
f0101e5d:	c7 44 24 0c 98 74 10 	movl   $0xf0107498,0xc(%esp)
f0101e64:	f0 
f0101e65:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101e6c:	f0 
f0101e6d:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f0101e74:	00 
f0101e75:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101e7c:	e8 bf e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e81:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e86:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0101e8b:	e8 15 ed ff ff       	call   f0100ba5 <check_va2pa>
f0101e90:	89 f2                	mov    %esi,%edx
f0101e92:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f0101e98:	c1 fa 03             	sar    $0x3,%edx
f0101e9b:	c1 e2 0c             	shl    $0xc,%edx
f0101e9e:	39 d0                	cmp    %edx,%eax
f0101ea0:	74 24                	je     f0101ec6 <mem_init+0xa11>
f0101ea2:	c7 44 24 0c d4 74 10 	movl   $0xf01074d4,0xc(%esp)
f0101ea9:	f0 
f0101eaa:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101eb1:	f0 
f0101eb2:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f0101eb9:	00 
f0101eba:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101ec1:	e8 7a e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ec6:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101ecb:	74 24                	je     f0101ef1 <mem_init+0xa3c>
f0101ecd:	c7 44 24 0c c7 70 10 	movl   $0xf01070c7,0xc(%esp)
f0101ed4:	f0 
f0101ed5:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101edc:	f0 
f0101edd:	c7 44 24 04 e8 03 00 	movl   $0x3e8,0x4(%esp)
f0101ee4:	00 
f0101ee5:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101eec:	e8 4f e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101ef1:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ef8:	e8 ec f1 ff ff       	call   f01010e9 <page_alloc>
f0101efd:	85 c0                	test   %eax,%eax
f0101eff:	74 24                	je     f0101f25 <mem_init+0xa70>
f0101f01:	c7 44 24 0c 53 70 10 	movl   $0xf0107053,0xc(%esp)
f0101f08:	f0 
f0101f09:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101f10:	f0 
f0101f11:	c7 44 24 04 eb 03 00 	movl   $0x3eb,0x4(%esp)
f0101f18:	00 
f0101f19:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101f20:	e8 1b e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f25:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f2c:	00 
f0101f2d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f34:	00 
f0101f35:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101f39:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0101f3e:	89 04 24             	mov    %eax,(%esp)
f0101f41:	e8 bc f4 ff ff       	call   f0101402 <page_insert>
f0101f46:	85 c0                	test   %eax,%eax
f0101f48:	74 24                	je     f0101f6e <mem_init+0xab9>
f0101f4a:	c7 44 24 0c 98 74 10 	movl   $0xf0107498,0xc(%esp)
f0101f51:	f0 
f0101f52:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101f59:	f0 
f0101f5a:	c7 44 24 04 ee 03 00 	movl   $0x3ee,0x4(%esp)
f0101f61:	00 
f0101f62:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101f69:	e8 d2 e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f6e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f73:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0101f78:	e8 28 ec ff ff       	call   f0100ba5 <check_va2pa>
f0101f7d:	89 f2                	mov    %esi,%edx
f0101f7f:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f0101f85:	c1 fa 03             	sar    $0x3,%edx
f0101f88:	c1 e2 0c             	shl    $0xc,%edx
f0101f8b:	39 d0                	cmp    %edx,%eax
f0101f8d:	74 24                	je     f0101fb3 <mem_init+0xafe>
f0101f8f:	c7 44 24 0c d4 74 10 	movl   $0xf01074d4,0xc(%esp)
f0101f96:	f0 
f0101f97:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101f9e:	f0 
f0101f9f:	c7 44 24 04 ef 03 00 	movl   $0x3ef,0x4(%esp)
f0101fa6:	00 
f0101fa7:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101fae:	e8 8d e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fb3:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101fb8:	74 24                	je     f0101fde <mem_init+0xb29>
f0101fba:	c7 44 24 0c c7 70 10 	movl   $0xf01070c7,0xc(%esp)
f0101fc1:	f0 
f0101fc2:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101fc9:	f0 
f0101fca:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0101fd1:	00 
f0101fd2:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0101fd9:	e8 62 e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101fde:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101fe5:	e8 ff f0 ff ff       	call   f01010e9 <page_alloc>
f0101fea:	85 c0                	test   %eax,%eax
f0101fec:	74 24                	je     f0102012 <mem_init+0xb5d>
f0101fee:	c7 44 24 0c 53 70 10 	movl   $0xf0107053,0xc(%esp)
f0101ff5:	f0 
f0101ff6:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0101ffd:	f0 
f0101ffe:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0102005:	00 
f0102006:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010200d:	e8 2e e0 ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0102012:	8b 15 8c 6e 22 f0    	mov    0xf0226e8c,%edx
f0102018:	8b 02                	mov    (%edx),%eax
f010201a:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010201f:	89 c1                	mov    %eax,%ecx
f0102021:	c1 e9 0c             	shr    $0xc,%ecx
f0102024:	3b 0d 88 6e 22 f0    	cmp    0xf0226e88,%ecx
f010202a:	72 20                	jb     f010204c <mem_init+0xb97>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010202c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102030:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0102037:	f0 
f0102038:	c7 44 24 04 f7 03 00 	movl   $0x3f7,0x4(%esp)
f010203f:	00 
f0102040:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102047:	e8 f4 df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010204c:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102051:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0102054:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010205b:	00 
f010205c:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102063:	00 
f0102064:	89 14 24             	mov    %edx,(%esp)
f0102067:	e8 5a f1 ff ff       	call   f01011c6 <pgdir_walk>
f010206c:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010206f:	8d 57 04             	lea    0x4(%edi),%edx
f0102072:	39 d0                	cmp    %edx,%eax
f0102074:	74 24                	je     f010209a <mem_init+0xbe5>
f0102076:	c7 44 24 0c 04 75 10 	movl   $0xf0107504,0xc(%esp)
f010207d:	f0 
f010207e:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102085:	f0 
f0102086:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f010208d:	00 
f010208e:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102095:	e8 a6 df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f010209a:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020a1:	00 
f01020a2:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020a9:	00 
f01020aa:	89 74 24 04          	mov    %esi,0x4(%esp)
f01020ae:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01020b3:	89 04 24             	mov    %eax,(%esp)
f01020b6:	e8 47 f3 ff ff       	call   f0101402 <page_insert>
f01020bb:	85 c0                	test   %eax,%eax
f01020bd:	74 24                	je     f01020e3 <mem_init+0xc2e>
f01020bf:	c7 44 24 0c 44 75 10 	movl   $0xf0107544,0xc(%esp)
f01020c6:	f0 
f01020c7:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01020ce:	f0 
f01020cf:	c7 44 24 04 fb 03 00 	movl   $0x3fb,0x4(%esp)
f01020d6:	00 
f01020d7:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01020de:	e8 5d df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f01020e3:	8b 3d 8c 6e 22 f0    	mov    0xf0226e8c,%edi
f01020e9:	ba 00 10 00 00       	mov    $0x1000,%edx
f01020ee:	89 f8                	mov    %edi,%eax
f01020f0:	e8 b0 ea ff ff       	call   f0100ba5 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01020f5:	89 f2                	mov    %esi,%edx
f01020f7:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f01020fd:	c1 fa 03             	sar    $0x3,%edx
f0102100:	c1 e2 0c             	shl    $0xc,%edx
f0102103:	39 d0                	cmp    %edx,%eax
f0102105:	74 24                	je     f010212b <mem_init+0xc76>
f0102107:	c7 44 24 0c d4 74 10 	movl   $0xf01074d4,0xc(%esp)
f010210e:	f0 
f010210f:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102116:	f0 
f0102117:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f010211e:	00 
f010211f:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102126:	e8 15 df ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010212b:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102130:	74 24                	je     f0102156 <mem_init+0xca1>
f0102132:	c7 44 24 0c c7 70 10 	movl   $0xf01070c7,0xc(%esp)
f0102139:	f0 
f010213a:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102141:	f0 
f0102142:	c7 44 24 04 fd 03 00 	movl   $0x3fd,0x4(%esp)
f0102149:	00 
f010214a:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102151:	e8 ea de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0102156:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010215d:	00 
f010215e:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102165:	00 
f0102166:	89 3c 24             	mov    %edi,(%esp)
f0102169:	e8 58 f0 ff ff       	call   f01011c6 <pgdir_walk>
f010216e:	f6 00 04             	testb  $0x4,(%eax)
f0102171:	75 24                	jne    f0102197 <mem_init+0xce2>
f0102173:	c7 44 24 0c 84 75 10 	movl   $0xf0107584,0xc(%esp)
f010217a:	f0 
f010217b:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102182:	f0 
f0102183:	c7 44 24 04 fe 03 00 	movl   $0x3fe,0x4(%esp)
f010218a:	00 
f010218b:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102192:	e8 a9 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f0102197:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f010219c:	f6 00 04             	testb  $0x4,(%eax)
f010219f:	75 24                	jne    f01021c5 <mem_init+0xd10>
f01021a1:	c7 44 24 0c d8 70 10 	movl   $0xf01070d8,0xc(%esp)
f01021a8:	f0 
f01021a9:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01021b0:	f0 
f01021b1:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f01021b8:	00 
f01021b9:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01021c0:	e8 7b de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021c5:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021cc:	00 
f01021cd:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021d4:	00 
f01021d5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01021d9:	89 04 24             	mov    %eax,(%esp)
f01021dc:	e8 21 f2 ff ff       	call   f0101402 <page_insert>
f01021e1:	85 c0                	test   %eax,%eax
f01021e3:	78 24                	js     f0102209 <mem_init+0xd54>
f01021e5:	c7 44 24 0c b8 75 10 	movl   $0xf01075b8,0xc(%esp)
f01021ec:	f0 
f01021ed:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01021f4:	f0 
f01021f5:	c7 44 24 04 02 04 00 	movl   $0x402,0x4(%esp)
f01021fc:	00 
f01021fd:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102204:	e8 37 de ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102209:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102210:	00 
f0102211:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102218:	00 
f0102219:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010221c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102220:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102225:	89 04 24             	mov    %eax,(%esp)
f0102228:	e8 d5 f1 ff ff       	call   f0101402 <page_insert>
f010222d:	85 c0                	test   %eax,%eax
f010222f:	74 24                	je     f0102255 <mem_init+0xda0>
f0102231:	c7 44 24 0c f0 75 10 	movl   $0xf01075f0,0xc(%esp)
f0102238:	f0 
f0102239:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102240:	f0 
f0102241:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102248:	00 
f0102249:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102250:	e8 eb dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0102255:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010225c:	00 
f010225d:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102264:	00 
f0102265:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f010226a:	89 04 24             	mov    %eax,(%esp)
f010226d:	e8 54 ef ff ff       	call   f01011c6 <pgdir_walk>
f0102272:	f6 00 04             	testb  $0x4,(%eax)
f0102275:	74 24                	je     f010229b <mem_init+0xde6>
f0102277:	c7 44 24 0c 2c 76 10 	movl   $0xf010762c,0xc(%esp)
f010227e:	f0 
f010227f:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102286:	f0 
f0102287:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f010228e:	00 
f010228f:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102296:	e8 a5 dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f010229b:	8b 3d 8c 6e 22 f0    	mov    0xf0226e8c,%edi
f01022a1:	ba 00 00 00 00       	mov    $0x0,%edx
f01022a6:	89 f8                	mov    %edi,%eax
f01022a8:	e8 f8 e8 ff ff       	call   f0100ba5 <check_va2pa>
f01022ad:	89 c1                	mov    %eax,%ecx
f01022af:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022b2:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022b5:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f01022bb:	c1 f8 03             	sar    $0x3,%eax
f01022be:	c1 e0 0c             	shl    $0xc,%eax
f01022c1:	39 c1                	cmp    %eax,%ecx
f01022c3:	74 24                	je     f01022e9 <mem_init+0xe34>
f01022c5:	c7 44 24 0c 64 76 10 	movl   $0xf0107664,0xc(%esp)
f01022cc:	f0 
f01022cd:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01022d4:	f0 
f01022d5:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01022dc:	00 
f01022dd:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01022e4:	e8 57 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f01022e9:	ba 00 10 00 00       	mov    $0x1000,%edx
f01022ee:	89 f8                	mov    %edi,%eax
f01022f0:	e8 b0 e8 ff ff       	call   f0100ba5 <check_va2pa>
f01022f5:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f01022f8:	74 24                	je     f010231e <mem_init+0xe69>
f01022fa:	c7 44 24 0c 90 76 10 	movl   $0xf0107690,0xc(%esp)
f0102301:	f0 
f0102302:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102309:	f0 
f010230a:	c7 44 24 04 0a 04 00 	movl   $0x40a,0x4(%esp)
f0102311:	00 
f0102312:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102319:	e8 22 dd ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f010231e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102321:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f0102326:	74 24                	je     f010234c <mem_init+0xe97>
f0102328:	c7 44 24 0c ee 70 10 	movl   $0xf01070ee,0xc(%esp)
f010232f:	f0 
f0102330:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102337:	f0 
f0102338:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f010233f:	00 
f0102340:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102347:	e8 f4 dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010234c:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102351:	74 24                	je     f0102377 <mem_init+0xec2>
f0102353:	c7 44 24 0c ff 70 10 	movl   $0xf01070ff,0xc(%esp)
f010235a:	f0 
f010235b:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102362:	f0 
f0102363:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f010236a:	00 
f010236b:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102372:	e8 c9 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f0102377:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010237e:	e8 66 ed ff ff       	call   f01010e9 <page_alloc>
f0102383:	85 c0                	test   %eax,%eax
f0102385:	74 04                	je     f010238b <mem_init+0xed6>
f0102387:	39 c6                	cmp    %eax,%esi
f0102389:	74 24                	je     f01023af <mem_init+0xefa>
f010238b:	c7 44 24 0c c0 76 10 	movl   $0xf01076c0,0xc(%esp)
f0102392:	f0 
f0102393:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010239a:	f0 
f010239b:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f01023a2:	00 
f01023a3:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01023aa:	e8 91 dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023af:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023b6:	00 
f01023b7:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01023bc:	89 04 24             	mov    %eax,(%esp)
f01023bf:	e8 ec ef ff ff       	call   f01013b0 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01023c4:	8b 3d 8c 6e 22 f0    	mov    0xf0226e8c,%edi
f01023ca:	ba 00 00 00 00       	mov    $0x0,%edx
f01023cf:	89 f8                	mov    %edi,%eax
f01023d1:	e8 cf e7 ff ff       	call   f0100ba5 <check_va2pa>
f01023d6:	83 f8 ff             	cmp    $0xffffffff,%eax
f01023d9:	74 24                	je     f01023ff <mem_init+0xf4a>
f01023db:	c7 44 24 0c e4 76 10 	movl   $0xf01076e4,0xc(%esp)
f01023e2:	f0 
f01023e3:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01023ea:	f0 
f01023eb:	c7 44 24 04 14 04 00 	movl   $0x414,0x4(%esp)
f01023f2:	00 
f01023f3:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01023fa:	e8 41 dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f01023ff:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102404:	89 f8                	mov    %edi,%eax
f0102406:	e8 9a e7 ff ff       	call   f0100ba5 <check_va2pa>
f010240b:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f010240e:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f0102414:	c1 fa 03             	sar    $0x3,%edx
f0102417:	c1 e2 0c             	shl    $0xc,%edx
f010241a:	39 d0                	cmp    %edx,%eax
f010241c:	74 24                	je     f0102442 <mem_init+0xf8d>
f010241e:	c7 44 24 0c 90 76 10 	movl   $0xf0107690,0xc(%esp)
f0102425:	f0 
f0102426:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010242d:	f0 
f010242e:	c7 44 24 04 15 04 00 	movl   $0x415,0x4(%esp)
f0102435:	00 
f0102436:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010243d:	e8 fe db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102442:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102445:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010244a:	74 24                	je     f0102470 <mem_init+0xfbb>
f010244c:	c7 44 24 0c a5 70 10 	movl   $0xf01070a5,0xc(%esp)
f0102453:	f0 
f0102454:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010245b:	f0 
f010245c:	c7 44 24 04 16 04 00 	movl   $0x416,0x4(%esp)
f0102463:	00 
f0102464:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010246b:	e8 d0 db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102470:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102475:	74 24                	je     f010249b <mem_init+0xfe6>
f0102477:	c7 44 24 0c ff 70 10 	movl   $0xf01070ff,0xc(%esp)
f010247e:	f0 
f010247f:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102486:	f0 
f0102487:	c7 44 24 04 17 04 00 	movl   $0x417,0x4(%esp)
f010248e:	00 
f010248f:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102496:	e8 a5 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f010249b:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024a2:	00 
f01024a3:	89 3c 24             	mov    %edi,(%esp)
f01024a6:	e8 05 ef ff ff       	call   f01013b0 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024ab:	8b 3d 8c 6e 22 f0    	mov    0xf0226e8c,%edi
f01024b1:	ba 00 00 00 00       	mov    $0x0,%edx
f01024b6:	89 f8                	mov    %edi,%eax
f01024b8:	e8 e8 e6 ff ff       	call   f0100ba5 <check_va2pa>
f01024bd:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024c0:	74 24                	je     f01024e6 <mem_init+0x1031>
f01024c2:	c7 44 24 0c e4 76 10 	movl   $0xf01076e4,0xc(%esp)
f01024c9:	f0 
f01024ca:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01024d1:	f0 
f01024d2:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f01024d9:	00 
f01024da:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01024e1:	e8 5a db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f01024e6:	ba 00 10 00 00       	mov    $0x1000,%edx
f01024eb:	89 f8                	mov    %edi,%eax
f01024ed:	e8 b3 e6 ff ff       	call   f0100ba5 <check_va2pa>
f01024f2:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024f5:	74 24                	je     f010251b <mem_init+0x1066>
f01024f7:	c7 44 24 0c 08 77 10 	movl   $0xf0107708,0xc(%esp)
f01024fe:	f0 
f01024ff:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102506:	f0 
f0102507:	c7 44 24 04 1c 04 00 	movl   $0x41c,0x4(%esp)
f010250e:	00 
f010250f:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102516:	e8 25 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f010251b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010251e:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102523:	74 24                	je     f0102549 <mem_init+0x1094>
f0102525:	c7 44 24 0c 10 71 10 	movl   $0xf0107110,0xc(%esp)
f010252c:	f0 
f010252d:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102534:	f0 
f0102535:	c7 44 24 04 1d 04 00 	movl   $0x41d,0x4(%esp)
f010253c:	00 
f010253d:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102544:	e8 f7 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102549:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010254e:	74 24                	je     f0102574 <mem_init+0x10bf>
f0102550:	c7 44 24 0c ff 70 10 	movl   $0xf01070ff,0xc(%esp)
f0102557:	f0 
f0102558:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010255f:	f0 
f0102560:	c7 44 24 04 1e 04 00 	movl   $0x41e,0x4(%esp)
f0102567:	00 
f0102568:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010256f:	e8 cc da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f0102574:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010257b:	e8 69 eb ff ff       	call   f01010e9 <page_alloc>
f0102580:	85 c0                	test   %eax,%eax
f0102582:	74 05                	je     f0102589 <mem_init+0x10d4>
f0102584:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0102587:	74 24                	je     f01025ad <mem_init+0x10f8>
f0102589:	c7 44 24 0c 30 77 10 	movl   $0xf0107730,0xc(%esp)
f0102590:	f0 
f0102591:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102598:	f0 
f0102599:	c7 44 24 04 21 04 00 	movl   $0x421,0x4(%esp)
f01025a0:	00 
f01025a1:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01025a8:	e8 93 da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025ad:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025b4:	e8 30 eb ff ff       	call   f01010e9 <page_alloc>
f01025b9:	85 c0                	test   %eax,%eax
f01025bb:	74 24                	je     f01025e1 <mem_init+0x112c>
f01025bd:	c7 44 24 0c 53 70 10 	movl   $0xf0107053,0xc(%esp)
f01025c4:	f0 
f01025c5:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01025cc:	f0 
f01025cd:	c7 44 24 04 24 04 00 	movl   $0x424,0x4(%esp)
f01025d4:	00 
f01025d5:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01025dc:	e8 5f da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f01025e1:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01025e6:	8b 08                	mov    (%eax),%ecx
f01025e8:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f01025ee:	89 da                	mov    %ebx,%edx
f01025f0:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f01025f6:	c1 fa 03             	sar    $0x3,%edx
f01025f9:	c1 e2 0c             	shl    $0xc,%edx
f01025fc:	39 d1                	cmp    %edx,%ecx
f01025fe:	74 24                	je     f0102624 <mem_init+0x116f>
f0102600:	c7 44 24 0c 40 74 10 	movl   $0xf0107440,0xc(%esp)
f0102607:	f0 
f0102608:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010260f:	f0 
f0102610:	c7 44 24 04 27 04 00 	movl   $0x427,0x4(%esp)
f0102617:	00 
f0102618:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010261f:	e8 1c da ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102624:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010262a:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f010262f:	74 24                	je     f0102655 <mem_init+0x11a0>
f0102631:	c7 44 24 0c b6 70 10 	movl   $0xf01070b6,0xc(%esp)
f0102638:	f0 
f0102639:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102640:	f0 
f0102641:	c7 44 24 04 29 04 00 	movl   $0x429,0x4(%esp)
f0102648:	00 
f0102649:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102650:	e8 eb d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0102655:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010265b:	89 1c 24             	mov    %ebx,(%esp)
f010265e:	e8 08 eb ff ff       	call   f010116b <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102663:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010266a:	00 
f010266b:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102672:	00 
f0102673:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102678:	89 04 24             	mov    %eax,(%esp)
f010267b:	e8 46 eb ff ff       	call   f01011c6 <pgdir_walk>
f0102680:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0102683:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f0102686:	8b 15 8c 6e 22 f0    	mov    0xf0226e8c,%edx
f010268c:	8b 7a 04             	mov    0x4(%edx),%edi
f010268f:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102695:	8b 0d 88 6e 22 f0    	mov    0xf0226e88,%ecx
f010269b:	89 f8                	mov    %edi,%eax
f010269d:	c1 e8 0c             	shr    $0xc,%eax
f01026a0:	39 c8                	cmp    %ecx,%eax
f01026a2:	72 20                	jb     f01026c4 <mem_init+0x120f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026a4:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01026a8:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f01026af:	f0 
f01026b0:	c7 44 24 04 30 04 00 	movl   $0x430,0x4(%esp)
f01026b7:	00 
f01026b8:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01026bf:	e8 7c d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f01026c4:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f01026ca:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f01026cd:	74 24                	je     f01026f3 <mem_init+0x123e>
f01026cf:	c7 44 24 0c 21 71 10 	movl   $0xf0107121,0xc(%esp)
f01026d6:	f0 
f01026d7:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01026de:	f0 
f01026df:	c7 44 24 04 31 04 00 	movl   $0x431,0x4(%esp)
f01026e6:	00 
f01026e7:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01026ee:	e8 4d d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f01026f3:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f01026fa:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102700:	89 d8                	mov    %ebx,%eax
f0102702:	2b 05 90 6e 22 f0    	sub    0xf0226e90,%eax
f0102708:	c1 f8 03             	sar    $0x3,%eax
f010270b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010270e:	89 c2                	mov    %eax,%edx
f0102710:	c1 ea 0c             	shr    $0xc,%edx
f0102713:	39 d1                	cmp    %edx,%ecx
f0102715:	77 20                	ja     f0102737 <mem_init+0x1282>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102717:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010271b:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0102722:	f0 
f0102723:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010272a:	00 
f010272b:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0102732:	e8 09 d9 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102737:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010273e:	00 
f010273f:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102746:	00 
	return (void *)(pa + KERNBASE);
f0102747:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010274c:	89 04 24             	mov    %eax,(%esp)
f010274f:	e8 e5 33 00 00       	call   f0105b39 <memset>
	page_free(pp0);
f0102754:	89 1c 24             	mov    %ebx,(%esp)
f0102757:	e8 0f ea ff ff       	call   f010116b <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f010275c:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102763:	00 
f0102764:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010276b:	00 
f010276c:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102771:	89 04 24             	mov    %eax,(%esp)
f0102774:	e8 4d ea ff ff       	call   f01011c6 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102779:	89 da                	mov    %ebx,%edx
f010277b:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f0102781:	c1 fa 03             	sar    $0x3,%edx
f0102784:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102787:	89 d0                	mov    %edx,%eax
f0102789:	c1 e8 0c             	shr    $0xc,%eax
f010278c:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f0102792:	72 20                	jb     f01027b4 <mem_init+0x12ff>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102794:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0102798:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f010279f:	f0 
f01027a0:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027a7:	00 
f01027a8:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f01027af:	e8 8c d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027b4:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027ba:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01027bd:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01027c4:	75 11                	jne    f01027d7 <mem_init+0x1322>
f01027c6:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01027cc:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01027d2:	f6 00 01             	testb  $0x1,(%eax)
f01027d5:	74 24                	je     f01027fb <mem_init+0x1346>
f01027d7:	c7 44 24 0c 39 71 10 	movl   $0xf0107139,0xc(%esp)
f01027de:	f0 
f01027df:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01027e6:	f0 
f01027e7:	c7 44 24 04 3b 04 00 	movl   $0x43b,0x4(%esp)
f01027ee:	00 
f01027ef:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01027f6:	e8 45 d8 ff ff       	call   f0100040 <_panic>
f01027fb:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f01027fe:	39 d0                	cmp    %edx,%eax
f0102800:	75 d0                	jne    f01027d2 <mem_init+0x131d>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102802:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102807:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010280d:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102813:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102816:	a3 40 62 22 f0       	mov    %eax,0xf0226240

	// free the pages we took
	page_free(pp0);
f010281b:	89 1c 24             	mov    %ebx,(%esp)
f010281e:	e8 48 e9 ff ff       	call   f010116b <page_free>
	page_free(pp1);
f0102823:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102826:	89 04 24             	mov    %eax,(%esp)
f0102829:	e8 3d e9 ff ff       	call   f010116b <page_free>
	page_free(pp2);
f010282e:	89 34 24             	mov    %esi,(%esp)
f0102831:	e8 35 e9 ff ff       	call   f010116b <page_free>

	cprintf("check_page() succeeded!\n");
f0102836:	c7 04 24 50 71 10 f0 	movl   $0xf0107150,(%esp)
f010283d:	e8 97 14 00 00       	call   f0103cd9 <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	//int page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
	cprintf("Mapping pages array to [UPAGES, ....)\n");
f0102842:	c7 04 24 54 77 10 f0 	movl   $0xf0107754,(%esp)
f0102849:	e8 8b 14 00 00       	call   f0103cd9 <cprintf>
	size_t i;
	size_t to_map_pages;
	to_map_pages = (sizeof(struct Page) * npages - 1) / PGSIZE + 1;
f010284e:	a1 88 6e 22 f0       	mov    0xf0226e88,%eax
f0102853:	8d 0c c5 ff ff ff ff 	lea    -0x1(,%eax,8),%ecx
f010285a:	c1 e9 0c             	shr    $0xc,%ecx
f010285d:	83 c1 01             	add    $0x1,%ecx

	boot_map_region(kern_pgdir, UPAGES, to_map_pages * PGSIZE, PADDR(pages), PTE_U | PTE_P);
f0102860:	a1 90 6e 22 f0       	mov    0xf0226e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102865:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010286a:	77 20                	ja     f010288c <mem_init+0x13d7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010286c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102870:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0102877:	f0 
f0102878:	c7 44 24 04 c2 00 00 	movl   $0xc2,0x4(%esp)
f010287f:	00 
f0102880:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102887:	e8 b4 d7 ff ff       	call   f0100040 <_panic>
f010288c:	c1 e1 0c             	shl    $0xc,%ecx
f010288f:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f0102896:	00 
	return (physaddr_t)kva - KERNBASE;
f0102897:	05 00 00 00 10       	add    $0x10000000,%eax
f010289c:	89 04 24             	mov    %eax,(%esp)
f010289f:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01028a4:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01028a9:	e8 01 ea ff ff       	call   f01012af <boot_map_region>
	for(i = 0; i < to_map_pages; i++)
	{
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i * PGSIZE), (void*)(UPAGES + i * PGSIZE), PTE_U | PTE_P);
		cprintf("Mapping page at physcial address from %x to virtual address %x\n", PADDR(pages) + i * PGSIZE, (UPAGES + i * PGSIZE));
	}*/
	cprintf("Map done.\n");
f01028ae:	c7 04 24 69 71 10 f0 	movl   $0xf0107169,(%esp)
f01028b5:	e8 1f 14 00 00       	call   f0103cd9 <cprintf>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	boot_map_region(kern_pgdir, UENVS, NENV * sizeof(struct Env), PADDR(envs), PTE_U | PTE_P);
f01028ba:	a1 48 62 22 f0       	mov    0xf0226248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028bf:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028c4:	77 20                	ja     f01028e6 <mem_init+0x1431>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028c6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028ca:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f01028d1:	f0 
f01028d2:	c7 44 24 04 d5 00 00 	movl   $0xd5,0x4(%esp)
f01028d9:	00 
f01028da:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01028e1:	e8 5a d7 ff ff       	call   f0100040 <_panic>
f01028e6:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f01028ed:	00 
	return (physaddr_t)kva - KERNBASE;
f01028ee:	05 00 00 00 10       	add    $0x10000000,%eax
f01028f3:	89 04 24             	mov    %eax,(%esp)
f01028f6:	b9 00 f0 01 00       	mov    $0x1f000,%ecx
f01028fb:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102900:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102905:	e8 a5 e9 ff ff       	call   f01012af <boot_map_region>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:

	cprintf("Mapping Kernel STACK\n");
f010290a:	c7 04 24 74 71 10 f0 	movl   $0xf0107174,(%esp)
f0102911:	e8 c3 13 00 00       	call   f0103cd9 <cprintf>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102916:	b8 00 60 11 f0       	mov    $0xf0116000,%eax
f010291b:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102920:	77 20                	ja     f0102942 <mem_init+0x148d>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102922:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102926:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f010292d:	f0 
f010292e:	c7 44 24 04 e5 00 00 	movl   $0xe5,0x4(%esp)
f0102935:	00 
f0102936:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010293d:	e8 fe d6 ff ff       	call   f0100040 <_panic>
	size_t to_map = KSTKSIZE / PGSIZE;
	boot_map_region(kern_pgdir, KSTACKTOP - KSTKSIZE, KSTKSIZE, PADDR(bootstack), PTE_W | PTE_P);
f0102942:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
f0102949:	00 
f010294a:	c7 04 24 00 60 11 00 	movl   $0x116000,(%esp)
f0102951:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102956:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f010295b:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102960:	e8 4a e9 ff ff       	call   f01012af <boot_map_region>
	/*
	for(i = 0; i < to_map; i++)
	{
		page_insert(kern_pgdir, pa2page(PADDR(bootstack + i * PGSIZE)), (void*)(KSTACKTOP - KSTKSIZE + i * PGSIZE), PTE_W | PTE_P);
	}*/
	cprintf("Map done.\n");
f0102965:	c7 04 24 69 71 10 f0 	movl   $0xf0107169,(%esp)
f010296c:	e8 68 13 00 00       	call   f0103cd9 <cprintf>
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	//static void
	//boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
	cprintf("Mapping KERNBASE...\n");
f0102971:	c7 04 24 8a 71 10 f0 	movl   $0xf010718a,(%esp)
f0102978:	e8 5c 13 00 00       	call   f0103cd9 <cprintf>
	size_t to_map_kernbase = (~0u- KERNBASE) / PGSIZE;
	cprintf("--- Mapping va [%x, %x] to pa [0, %x]\n", KERNBASE, ~0u, (to_map_kernbase - 1) * PGSIZE);
f010297d:	c7 44 24 0c 00 e0 ff 	movl   $0xfffe000,0xc(%esp)
f0102984:	0f 
f0102985:	c7 44 24 08 ff ff ff 	movl   $0xffffffff,0x8(%esp)
f010298c:	ff 
f010298d:	c7 44 24 04 00 00 00 	movl   $0xf0000000,0x4(%esp)
f0102994:	f0 
f0102995:	c7 04 24 7c 77 10 f0 	movl   $0xf010777c,(%esp)
f010299c:	e8 38 13 00 00       	call   f0103cd9 <cprintf>
		if(i >= npages)
			break;
		page_insert(kern_pgdir, pa2page(i * PGSIZE), (void*)(KERNBASE + i * PGSIZE), PTE_W | PTE_P);
	}
	*/
	boot_map_region(kern_pgdir, KERNBASE, to_map_kernbase * PGSIZE, 0, PTE_W | PTE_P);
f01029a1:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
f01029a8:	00 
f01029a9:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01029b0:	b9 00 f0 ff 0f       	mov    $0xffff000,%ecx
f01029b5:	ba 00 00 00 f0       	mov    $0xf0000000,%edx
f01029ba:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01029bf:	e8 eb e8 ff ff       	call   f01012af <boot_map_region>
	cprintf("Map done.\n");
f01029c4:	c7 04 24 69 71 10 f0 	movl   $0xf0107169,(%esp)
f01029cb:	e8 09 13 00 00       	call   f0103cd9 <cprintf>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f01029d0:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01029d7:	00 
f01029d8:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f01029df:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f01029e4:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f01029e9:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01029ee:	e8 bc e8 ff ff       	call   f01012af <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01029f3:	b8 00 80 22 f0       	mov    $0xf0228000,%eax
f01029f8:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01029fd:	0f 87 9d 07 00 00    	ja     f01031a0 <mem_init+0x1ceb>
f0102a03:	eb 0d                	jmp    f0102a12 <mem_init+0x155d>
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
f0102a05:	89 d8                	mov    %ebx,%eax
f0102a07:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102a0d:	77 28                	ja     f0102a37 <mem_init+0x1582>
f0102a0f:	90                   	nop
f0102a10:	eb 05                	jmp    f0102a17 <mem_init+0x1562>
f0102a12:	b8 00 80 22 f0       	mov    $0xf0228000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a17:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102a1b:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0102a22:	f0 
f0102a23:	c7 44 24 04 45 01 00 	movl   $0x145,0x4(%esp)
f0102a2a:	00 
f0102a2b:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102a32:	e8 09 d6 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f0102a37:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102a3e:	00 
f0102a3f:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102a45:	89 04 24             	mov    %eax,(%esp)
f0102a48:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102a4d:	89 f2                	mov    %esi,%edx
f0102a4f:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102a54:	e8 56 e8 ff ff       	call   f01012af <boot_map_region>
f0102a59:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102a5f:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	//
	// LAB 4: Your code here:
	int cpu_i;
	uintptr_t stk_i;
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
f0102a65:	39 fb                	cmp    %edi,%ebx
f0102a67:	75 9c                	jne    f0102a05 <mem_init+0x1550>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102a69:	8b 35 8c 6e 22 f0    	mov    0xf0226e8c,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102a6f:	a1 88 6e 22 f0       	mov    0xf0226e88,%eax
f0102a74:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102a77:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102a7e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102a83:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102a86:	75 30                	jne    f0102ab8 <mem_init+0x1603>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102a88:	8b 1d 48 62 22 f0    	mov    0xf0226248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102a8e:	89 df                	mov    %ebx,%edi
f0102a90:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102a95:	89 f0                	mov    %esi,%eax
f0102a97:	e8 09 e1 ff ff       	call   f0100ba5 <check_va2pa>
f0102a9c:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102aa2:	0f 86 94 00 00 00    	jbe    f0102b3c <mem_init+0x1687>
f0102aa8:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102aad:	81 c7 00 00 40 21    	add    $0x21400000,%edi
f0102ab3:	e9 a4 00 00 00       	jmp    f0102b5c <mem_init+0x16a7>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102ab8:	8b 1d 90 6e 22 f0    	mov    0xf0226e90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102abe:	8d bb 00 00 00 10    	lea    0x10000000(%ebx),%edi
f0102ac4:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102ac9:	89 f0                	mov    %esi,%eax
f0102acb:	e8 d5 e0 ff ff       	call   f0100ba5 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102ad0:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102ad6:	77 20                	ja     f0102af8 <mem_init+0x1643>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102ad8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102adc:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0102ae3:	f0 
f0102ae4:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102aeb:	00 
f0102aec:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102af3:	e8 48 d5 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102af8:	ba 00 00 00 00       	mov    $0x0,%edx
f0102afd:	8d 0c 17             	lea    (%edi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102b00:	39 c8                	cmp    %ecx,%eax
f0102b02:	74 24                	je     f0102b28 <mem_init+0x1673>
f0102b04:	c7 44 24 0c a4 77 10 	movl   $0xf01077a4,0xc(%esp)
f0102b0b:	f0 
f0102b0c:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102b13:	f0 
f0102b14:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102b1b:	00 
f0102b1c:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102b23:	e8 18 d5 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102b28:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102b2e:	39 5d d0             	cmp    %ebx,-0x30(%ebp)
f0102b31:	0f 87 be 06 00 00    	ja     f01031f5 <mem_init+0x1d40>
f0102b37:	e9 4c ff ff ff       	jmp    f0102a88 <mem_init+0x15d3>
f0102b3c:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102b40:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0102b47:	f0 
f0102b48:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0102b4f:	00 
f0102b50:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102b57:	e8 e4 d4 ff ff       	call   f0100040 <_panic>
f0102b5c:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102b5f:	39 c2                	cmp    %eax,%edx
f0102b61:	74 24                	je     f0102b87 <mem_init+0x16d2>
f0102b63:	c7 44 24 0c d8 77 10 	movl   $0xf01077d8,0xc(%esp)
f0102b6a:	f0 
f0102b6b:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102b72:	f0 
f0102b73:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0102b7a:	00 
f0102b7b:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102b82:	e8 b9 d4 ff ff       	call   f0100040 <_panic>
f0102b87:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102b8d:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102b93:	0f 85 4c 06 00 00    	jne    f01031e5 <mem_init+0x1d30>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102b99:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102b9c:	c1 e7 0c             	shl    $0xc,%edi
f0102b9f:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102ba4:	85 ff                	test   %edi,%edi
f0102ba6:	75 07                	jne    f0102baf <mem_init+0x16fa>
f0102ba8:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102bad:	eb 41                	jmp    f0102bf0 <mem_init+0x173b>
f0102baf:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102bb5:	89 f0                	mov    %esi,%eax
f0102bb7:	e8 e9 df ff ff       	call   f0100ba5 <check_va2pa>
f0102bbc:	39 c3                	cmp    %eax,%ebx
f0102bbe:	74 24                	je     f0102be4 <mem_init+0x172f>
f0102bc0:	c7 44 24 0c 0c 78 10 	movl   $0xf010780c,0xc(%esp)
f0102bc7:	f0 
f0102bc8:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102bcf:	f0 
f0102bd0:	c7 44 24 04 81 03 00 	movl   $0x381,0x4(%esp)
f0102bd7:	00 
f0102bd8:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102bdf:	e8 5c d4 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102be4:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102bea:	39 df                	cmp    %ebx,%edi
f0102bec:	77 c1                	ja     f0102baf <mem_init+0x16fa>
f0102bee:	eb b8                	jmp    f0102ba8 <mem_init+0x16f3>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102bf0:	89 da                	mov    %ebx,%edx
f0102bf2:	89 f0                	mov    %esi,%eax
f0102bf4:	e8 ac df ff ff       	call   f0100ba5 <check_va2pa>
f0102bf9:	39 c3                	cmp    %eax,%ebx
f0102bfb:	74 24                	je     f0102c21 <mem_init+0x176c>
f0102bfd:	c7 44 24 0c 9f 71 10 	movl   $0xf010719f,0xc(%esp)
f0102c04:	f0 
f0102c05:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102c0c:	f0 
f0102c0d:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
f0102c14:	00 
f0102c15:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102c1c:	e8 1f d4 ff ff       	call   f0100040 <_panic>
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102c21:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102c27:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102c2d:	75 c1                	jne    f0102bf0 <mem_init+0x173b>
f0102c2f:	c7 45 d0 00 80 22 f0 	movl   $0xf0228000,-0x30(%ebp)
f0102c36:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%ebp)
f0102c3d:	bf 00 80 bf ef       	mov    $0xefbf8000,%edi
f0102c42:	b8 00 80 22 f0       	mov    $0xf0228000,%eax
f0102c47:	05 00 80 40 20       	add    $0x20408000,%eax
f0102c4c:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102c4f:	8d 87 00 80 00 00    	lea    0x8000(%edi),%eax
f0102c55:	89 45 cc             	mov    %eax,-0x34(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102c58:	89 fa                	mov    %edi,%edx
f0102c5a:	89 f0                	mov    %esi,%eax
f0102c5c:	e8 44 df ff ff       	call   f0100ba5 <check_va2pa>
f0102c61:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c64:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102c6a:	77 20                	ja     f0102c8c <mem_init+0x17d7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c6c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102c70:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0102c77:	f0 
f0102c78:	c7 44 24 04 8d 03 00 	movl   $0x38d,0x4(%esp)
f0102c7f:	00 
f0102c80:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102c87:	e8 b4 d3 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c8c:	89 fb                	mov    %edi,%ebx
f0102c8e:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f0102c91:	03 4d d4             	add    -0x2c(%ebp),%ecx
f0102c94:	89 4d c8             	mov    %ecx,-0x38(%ebp)
f0102c97:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0102c9a:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
f0102c9d:	39 c2                	cmp    %eax,%edx
f0102c9f:	74 24                	je     f0102cc5 <mem_init+0x1810>
f0102ca1:	c7 44 24 0c 34 78 10 	movl   $0xf0107834,0xc(%esp)
f0102ca8:	f0 
f0102ca9:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102cb0:	f0 
f0102cb1:	c7 44 24 04 8d 03 00 	movl   $0x38d,0x4(%esp)
f0102cb8:	00 
f0102cb9:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102cc0:	e8 7b d3 ff ff       	call   f0100040 <_panic>
f0102cc5:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102ccb:	3b 5d cc             	cmp    -0x34(%ebp),%ebx
f0102cce:	0f 85 03 05 00 00    	jne    f01031d7 <mem_init+0x1d22>
f0102cd4:	8d 9f 00 80 ff ff    	lea    -0x8000(%edi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102cda:	89 da                	mov    %ebx,%edx
f0102cdc:	89 f0                	mov    %esi,%eax
f0102cde:	e8 c2 de ff ff       	call   f0100ba5 <check_va2pa>
f0102ce3:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102ce6:	74 24                	je     f0102d0c <mem_init+0x1857>
f0102ce8:	c7 44 24 0c 7c 78 10 	movl   $0xf010787c,0xc(%esp)
f0102cef:	f0 
f0102cf0:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102cf7:	f0 
f0102cf8:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f0102cff:	00 
f0102d00:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102d07:	e8 34 d3 ff ff       	call   f0100040 <_panic>
f0102d0c:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102d12:	39 fb                	cmp    %edi,%ebx
f0102d14:	75 c4                	jne    f0102cda <mem_init+0x1825>
f0102d16:	81 ef 00 00 01 00    	sub    $0x10000,%edi
f0102d1c:	81 45 d4 00 80 01 00 	addl   $0x18000,-0x2c(%ebp)
f0102d23:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102d2a:	81 ff 00 80 b7 ef    	cmp    $0xefb78000,%edi
f0102d30:	0f 85 19 ff ff ff    	jne    f0102c4f <mem_init+0x179a>
f0102d36:	b8 00 00 00 00       	mov    $0x0,%eax
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102d3b:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102d41:	83 fa 03             	cmp    $0x3,%edx
f0102d44:	77 2e                	ja     f0102d74 <mem_init+0x18bf>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102d46:	f6 04 86 01          	testb  $0x1,(%esi,%eax,4)
f0102d4a:	0f 85 aa 00 00 00    	jne    f0102dfa <mem_init+0x1945>
f0102d50:	c7 44 24 0c ba 71 10 	movl   $0xf01071ba,0xc(%esp)
f0102d57:	f0 
f0102d58:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102d5f:	f0 
f0102d60:	c7 44 24 04 99 03 00 	movl   $0x399,0x4(%esp)
f0102d67:	00 
f0102d68:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102d6f:	e8 cc d2 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102d74:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102d79:	76 55                	jbe    f0102dd0 <mem_init+0x191b>
				assert(pgdir[i] & PTE_P);
f0102d7b:	8b 14 86             	mov    (%esi,%eax,4),%edx
f0102d7e:	f6 c2 01             	test   $0x1,%dl
f0102d81:	75 24                	jne    f0102da7 <mem_init+0x18f2>
f0102d83:	c7 44 24 0c ba 71 10 	movl   $0xf01071ba,0xc(%esp)
f0102d8a:	f0 
f0102d8b:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102d92:	f0 
f0102d93:	c7 44 24 04 9d 03 00 	movl   $0x39d,0x4(%esp)
f0102d9a:	00 
f0102d9b:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102da2:	e8 99 d2 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102da7:	f6 c2 02             	test   $0x2,%dl
f0102daa:	75 4e                	jne    f0102dfa <mem_init+0x1945>
f0102dac:	c7 44 24 0c cb 71 10 	movl   $0xf01071cb,0xc(%esp)
f0102db3:	f0 
f0102db4:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102dbb:	f0 
f0102dbc:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f0102dc3:	00 
f0102dc4:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102dcb:	e8 70 d2 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102dd0:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102dd4:	74 24                	je     f0102dfa <mem_init+0x1945>
f0102dd6:	c7 44 24 0c dc 71 10 	movl   $0xf01071dc,0xc(%esp)
f0102ddd:	f0 
f0102dde:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102de5:	f0 
f0102de6:	c7 44 24 04 a0 03 00 	movl   $0x3a0,0x4(%esp)
f0102ded:	00 
f0102dee:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102df5:	e8 46 d2 ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102dfa:	83 c0 01             	add    $0x1,%eax
f0102dfd:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102e02:	0f 85 33 ff ff ff    	jne    f0102d3b <mem_init+0x1886>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102e08:	c7 04 24 a0 78 10 f0 	movl   $0xf01078a0,(%esp)
f0102e0f:	e8 c5 0e 00 00       	call   f0103cd9 <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102e14:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102e19:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102e1e:	77 20                	ja     f0102e40 <mem_init+0x198b>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102e20:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102e24:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0102e2b:	f0 
f0102e2c:	c7 44 24 04 13 01 00 	movl   $0x113,0x4(%esp)
f0102e33:	00 
f0102e34:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102e3b:	e8 00 d2 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102e40:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102e45:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0102e48:	b8 00 00 00 00       	mov    $0x0,%eax
f0102e4d:	e8 c2 dd ff ff       	call   f0100c14 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102e52:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102e55:	83 e0 f3             	and    $0xfffffff3,%eax
f0102e58:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102e5d:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102e60:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102e67:	e8 7d e2 ff ff       	call   f01010e9 <page_alloc>
f0102e6c:	89 c6                	mov    %eax,%esi
f0102e6e:	85 c0                	test   %eax,%eax
f0102e70:	75 24                	jne    f0102e96 <mem_init+0x19e1>
f0102e72:	c7 44 24 0c a8 6f 10 	movl   $0xf0106fa8,0xc(%esp)
f0102e79:	f0 
f0102e7a:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102e81:	f0 
f0102e82:	c7 44 24 04 56 04 00 	movl   $0x456,0x4(%esp)
f0102e89:	00 
f0102e8a:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102e91:	e8 aa d1 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0102e96:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102e9d:	e8 47 e2 ff ff       	call   f01010e9 <page_alloc>
f0102ea2:	89 c3                	mov    %eax,%ebx
f0102ea4:	85 c0                	test   %eax,%eax
f0102ea6:	75 24                	jne    f0102ecc <mem_init+0x1a17>
f0102ea8:	c7 44 24 0c be 6f 10 	movl   $0xf0106fbe,0xc(%esp)
f0102eaf:	f0 
f0102eb0:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102eb7:	f0 
f0102eb8:	c7 44 24 04 57 04 00 	movl   $0x457,0x4(%esp)
f0102ebf:	00 
f0102ec0:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102ec7:	e8 74 d1 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0102ecc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102ed3:	e8 11 e2 ff ff       	call   f01010e9 <page_alloc>
f0102ed8:	89 c7                	mov    %eax,%edi
f0102eda:	85 c0                	test   %eax,%eax
f0102edc:	75 24                	jne    f0102f02 <mem_init+0x1a4d>
f0102ede:	c7 44 24 0c d4 6f 10 	movl   $0xf0106fd4,0xc(%esp)
f0102ee5:	f0 
f0102ee6:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102eed:	f0 
f0102eee:	c7 44 24 04 58 04 00 	movl   $0x458,0x4(%esp)
f0102ef5:	00 
f0102ef6:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102efd:	e8 3e d1 ff ff       	call   f0100040 <_panic>
	cprintf("pp1->pp_ref=%d\n", pp1->pp_ref);
f0102f02:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0102f06:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102f0a:	c7 04 24 ea 71 10 f0 	movl   $0xf01071ea,(%esp)
f0102f11:	e8 c3 0d 00 00       	call   f0103cd9 <cprintf>
	page_free(pp0);
f0102f16:	89 34 24             	mov    %esi,(%esp)
f0102f19:	e8 4d e2 ff ff       	call   f010116b <page_free>
	memset(page2kva(pp1), 1, PGSIZE);
f0102f1e:	89 d8                	mov    %ebx,%eax
f0102f20:	e8 3b dc ff ff       	call   f0100b60 <page2kva>
f0102f25:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102f2c:	00 
f0102f2d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102f34:	00 
f0102f35:	89 04 24             	mov    %eax,(%esp)
f0102f38:	e8 fc 2b 00 00       	call   f0105b39 <memset>
	memset(page2kva(pp2), 2, PGSIZE);
f0102f3d:	89 f8                	mov    %edi,%eax
f0102f3f:	e8 1c dc ff ff       	call   f0100b60 <page2kva>
f0102f44:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102f4b:	00 
f0102f4c:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102f53:	00 
f0102f54:	89 04 24             	mov    %eax,(%esp)
f0102f57:	e8 dd 2b 00 00       	call   f0105b39 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102f5c:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102f63:	00 
f0102f64:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102f6b:	00 
f0102f6c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102f70:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0102f75:	89 04 24             	mov    %eax,(%esp)
f0102f78:	e8 85 e4 ff ff       	call   f0101402 <page_insert>
	cprintf("pp1->pp_ref=%d\n", pp1->pp_ref);
f0102f7d:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0102f81:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102f85:	c7 04 24 ea 71 10 f0 	movl   $0xf01071ea,(%esp)
f0102f8c:	e8 48 0d 00 00       	call   f0103cd9 <cprintf>
	assert(pp1->pp_ref == 1);
f0102f91:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102f96:	74 24                	je     f0102fbc <mem_init+0x1b07>
f0102f98:	c7 44 24 0c a5 70 10 	movl   $0xf01070a5,0xc(%esp)
f0102f9f:	f0 
f0102fa0:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102fa7:	f0 
f0102fa8:	c7 44 24 04 5f 04 00 	movl   $0x45f,0x4(%esp)
f0102faf:	00 
f0102fb0:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102fb7:	e8 84 d0 ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102fbc:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102fc3:	01 01 01 
f0102fc6:	74 24                	je     f0102fec <mem_init+0x1b37>
f0102fc8:	c7 44 24 0c c0 78 10 	movl   $0xf01078c0,0xc(%esp)
f0102fcf:	f0 
f0102fd0:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0102fd7:	f0 
f0102fd8:	c7 44 24 04 60 04 00 	movl   $0x460,0x4(%esp)
f0102fdf:	00 
f0102fe0:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0102fe7:	e8 54 d0 ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f0102fec:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102ff3:	00 
f0102ff4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102ffb:	00 
f0102ffc:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103000:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0103005:	89 04 24             	mov    %eax,(%esp)
f0103008:	e8 f5 e3 ff ff       	call   f0101402 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f010300d:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0103014:	02 02 02 
f0103017:	74 24                	je     f010303d <mem_init+0x1b88>
f0103019:	c7 44 24 0c e4 78 10 	movl   $0xf01078e4,0xc(%esp)
f0103020:	f0 
f0103021:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0103028:	f0 
f0103029:	c7 44 24 04 62 04 00 	movl   $0x462,0x4(%esp)
f0103030:	00 
f0103031:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0103038:	e8 03 d0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010303d:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0103042:	74 24                	je     f0103068 <mem_init+0x1bb3>
f0103044:	c7 44 24 0c c7 70 10 	movl   $0xf01070c7,0xc(%esp)
f010304b:	f0 
f010304c:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0103053:	f0 
f0103054:	c7 44 24 04 63 04 00 	movl   $0x463,0x4(%esp)
f010305b:	00 
f010305c:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f0103063:	e8 d8 cf ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103068:	66 83 7b 04 00       	cmpw   $0x0,0x4(%ebx)
f010306d:	74 24                	je     f0103093 <mem_init+0x1bde>
f010306f:	c7 44 24 0c 10 71 10 	movl   $0xf0107110,0xc(%esp)
f0103076:	f0 
f0103077:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010307e:	f0 
f010307f:	c7 44 24 04 64 04 00 	movl   $0x464,0x4(%esp)
f0103086:	00 
f0103087:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010308e:	e8 ad cf ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0103093:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f010309a:	03 03 03 
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f010309d:	89 f8                	mov    %edi,%eax
f010309f:	e8 bc da ff ff       	call   f0100b60 <page2kva>
f01030a4:	81 38 03 03 03 03    	cmpl   $0x3030303,(%eax)
f01030aa:	74 24                	je     f01030d0 <mem_init+0x1c1b>
f01030ac:	c7 44 24 0c 08 79 10 	movl   $0xf0107908,0xc(%esp)
f01030b3:	f0 
f01030b4:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01030bb:	f0 
f01030bc:	c7 44 24 04 66 04 00 	movl   $0x466,0x4(%esp)
f01030c3:	00 
f01030c4:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f01030cb:	e8 70 cf ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01030d0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01030d7:	00 
f01030d8:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01030dd:	89 04 24             	mov    %eax,(%esp)
f01030e0:	e8 cb e2 ff ff       	call   f01013b0 <page_remove>
	assert(pp2->pp_ref == 0);
f01030e5:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f01030ea:	74 24                	je     f0103110 <mem_init+0x1c5b>
f01030ec:	c7 44 24 0c ff 70 10 	movl   $0xf01070ff,0xc(%esp)
f01030f3:	f0 
f01030f4:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01030fb:	f0 
f01030fc:	c7 44 24 04 68 04 00 	movl   $0x468,0x4(%esp)
f0103103:	00 
f0103104:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010310b:	e8 30 cf ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0103110:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f0103115:	8b 08                	mov    (%eax),%ecx
f0103117:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010311d:	89 f2                	mov    %esi,%edx
f010311f:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f0103125:	c1 fa 03             	sar    $0x3,%edx
f0103128:	c1 e2 0c             	shl    $0xc,%edx
f010312b:	39 d1                	cmp    %edx,%ecx
f010312d:	74 24                	je     f0103153 <mem_init+0x1c9e>
f010312f:	c7 44 24 0c 40 74 10 	movl   $0xf0107440,0xc(%esp)
f0103136:	f0 
f0103137:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010313e:	f0 
f010313f:	c7 44 24 04 6b 04 00 	movl   $0x46b,0x4(%esp)
f0103146:	00 
f0103147:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010314e:	e8 ed ce ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0103153:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103159:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f010315e:	74 24                	je     f0103184 <mem_init+0x1ccf>
f0103160:	c7 44 24 0c b6 70 10 	movl   $0xf01070b6,0xc(%esp)
f0103167:	f0 
f0103168:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f010316f:	f0 
f0103170:	c7 44 24 04 6d 04 00 	movl   $0x46d,0x4(%esp)
f0103177:	00 
f0103178:	c7 04 24 84 6e 10 f0 	movl   $0xf0106e84,(%esp)
f010317f:	e8 bc ce ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0103184:	66 c7 46 04 00 00    	movw   $0x0,0x4(%esi)

	// free the pages we took
	page_free(pp0);
f010318a:	89 34 24             	mov    %esi,(%esp)
f010318d:	e8 d9 df ff ff       	call   f010116b <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f0103192:	c7 04 24 34 79 10 f0 	movl   $0xf0107934,(%esp)
f0103199:	e8 3b 0b 00 00       	call   f0103cd9 <cprintf>
f010319e:	eb 69                	jmp    f0103209 <mem_init+0x1d54>
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f01031a0:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01031a7:	00 
f01031a8:	c7 04 24 00 80 22 00 	movl   $0x228000,(%esp)
f01031af:	b9 00 80 00 00       	mov    $0x8000,%ecx
f01031b4:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f01031b9:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
f01031be:	e8 ec e0 ff ff       	call   f01012af <boot_map_region>
f01031c3:	bb 00 00 23 f0       	mov    $0xf0230000,%ebx
f01031c8:	bf 00 80 26 f0       	mov    $0xf0268000,%edi
f01031cd:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f01031d2:	e9 2e f8 ff ff       	jmp    f0102a05 <mem_init+0x1550>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f01031d7:	89 da                	mov    %ebx,%edx
f01031d9:	89 f0                	mov    %esi,%eax
f01031db:	e8 c5 d9 ff ff       	call   f0100ba5 <check_va2pa>
f01031e0:	e9 b2 fa ff ff       	jmp    f0102c97 <mem_init+0x17e2>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f01031e5:	89 da                	mov    %ebx,%edx
f01031e7:	89 f0                	mov    %esi,%eax
f01031e9:	e8 b7 d9 ff ff       	call   f0100ba5 <check_va2pa>
f01031ee:	66 90                	xchg   %ax,%ax
f01031f0:	e9 67 f9 ff ff       	jmp    f0102b5c <mem_init+0x16a7>
f01031f5:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f01031fb:	89 f0                	mov    %esi,%eax
f01031fd:	e8 a3 d9 ff ff       	call   f0100ba5 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0103202:	89 da                	mov    %ebx,%edx
f0103204:	e9 f4 f8 ff ff       	jmp    f0102afd <mem_init+0x1648>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103209:	83 c4 4c             	add    $0x4c,%esp
f010320c:	5b                   	pop    %ebx
f010320d:	5e                   	pop    %esi
f010320e:	5f                   	pop    %edi
f010320f:	5d                   	pop    %ebp
f0103210:	c3                   	ret    

f0103211 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103211:	55                   	push   %ebp
f0103212:	89 e5                	mov    %esp,%ebp
f0103214:	57                   	push   %edi
f0103215:	56                   	push   %esi
f0103216:	53                   	push   %ebx
f0103217:	83 ec 2c             	sub    $0x2c,%esp
f010321a:	8b 7d 08             	mov    0x8(%ebp),%edi
f010321d:	8b 45 0c             	mov    0xc(%ebp),%eax
	//cprintf("at user_mem_check():");
	// LAB 3: Your code here.
	pte_t* pte = NULL;
	void* ptr = NULL, *nxt = NULL;
	for(ptr = (void*)va; ptr < va + len; )
f0103220:	89 c3                	mov    %eax,%ebx
f0103222:	03 45 10             	add    0x10(%ebp),%eax
f0103225:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		if(*pte & PTE_U) cprintf(" PTE_U");
		if(*pte & PTE_W) cprintf(" PTE_W");
		cprintf("\n");
		*/

		if(((perm & PTE_U) != 0 && ((*pte & PTE_U) == 0)) ||
f0103228:	8b 45 14             	mov    0x14(%ebp),%eax
f010322b:	83 e0 04             	and    $0x4,%eax
f010322e:	89 45 e0             	mov    %eax,-0x20(%ebp)
{
	//cprintf("at user_mem_check():");
	// LAB 3: Your code here.
	pte_t* pte = NULL;
	void* ptr = NULL, *nxt = NULL;
	for(ptr = (void*)va; ptr < va + len; )
f0103231:	eb 7f                	jmp    f01032b2 <user_mem_check+0xa1>
	{
		//cprintf("now check address: %x\n", ptr);
		if((uintptr_t)ptr >= ULIM)
f0103233:	89 de                	mov    %ebx,%esi
f0103235:	81 fb ff ff 7f ef    	cmp    $0xef7fffff,%ebx
f010323b:	76 0d                	jbe    f010324a <user_mem_check+0x39>
		{
			user_mem_check_addr = (uintptr_t)ptr;
f010323d:	89 1d 3c 62 22 f0    	mov    %ebx,0xf022623c
			return -E_FAULT;
f0103243:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103248:	eb 76                	jmp    f01032c0 <user_mem_check+0xaf>
		}
		pte = pgdir_walk(env->env_pgdir, ptr, 0); 
f010324a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0103251:	00 
f0103252:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103256:	8b 47 60             	mov    0x60(%edi),%eax
f0103259:	89 04 24             	mov    %eax,(%esp)
f010325c:	e8 65 df ff ff       	call   f01011c6 <pgdir_walk>
		if(pte == NULL || (*pte & PTE_P) == 0) 
f0103261:	85 c0                	test   %eax,%eax
f0103263:	74 06                	je     f010326b <user_mem_check+0x5a>
f0103265:	8b 00                	mov    (%eax),%eax
f0103267:	a8 01                	test   $0x1,%al
f0103269:	75 0d                	jne    f0103278 <user_mem_check+0x67>
		{
			user_mem_check_addr = (uintptr_t)ptr;
f010326b:	89 35 3c 62 22 f0    	mov    %esi,0xf022623c
			return -E_FAULT;
f0103271:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103276:	eb 48                	jmp    f01032c0 <user_mem_check+0xaf>
		if(*pte & PTE_U) cprintf(" PTE_U");
		if(*pte & PTE_W) cprintf(" PTE_W");
		cprintf("\n");
		*/

		if(((perm & PTE_U) != 0 && ((*pte & PTE_U) == 0)) ||
f0103278:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f010327c:	74 04                	je     f0103282 <user_mem_check+0x71>
f010327e:	a8 04                	test   $0x4,%al
f0103280:	74 0a                	je     f010328c <user_mem_check+0x7b>
f0103282:	f6 45 14 02          	testb  $0x2,0x14(%ebp)
f0103286:	74 11                	je     f0103299 <user_mem_check+0x88>
			((perm & PTE_W) != 0 && ((*pte & PTE_W) == 0)))
f0103288:	a8 02                	test   $0x2,%al
f010328a:	75 0d                	jne    f0103299 <user_mem_check+0x88>
		{
			user_mem_check_addr = (uintptr_t)ptr;
f010328c:	89 35 3c 62 22 f0    	mov    %esi,0xf022623c
			return -E_FAULT;
f0103292:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103297:	eb 27                	jmp    f01032c0 <user_mem_check+0xaf>
		}
		nxt = (void*) ROUNDUP(ptr, PGSIZE);
f0103299:	81 c6 ff 0f 00 00    	add    $0xfff,%esi
f010329f:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
		ptr = ptr == nxt ? ptr + PGSIZE : nxt;
f01032a5:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
f01032ab:	39 f3                	cmp    %esi,%ebx
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01032ad:	0f 45 c6             	cmovne %esi,%eax
f01032b0:	89 c3                	mov    %eax,%ebx
	//cprintf("at user_mem_check():");
	// LAB 3: Your code here.
	pte_t* pte = NULL;
	void* ptr = NULL, *nxt = NULL;
	for(ptr = (void*)va; ptr < va + len; )
f01032b2:	3b 5d e4             	cmp    -0x1c(%ebp),%ebx
f01032b5:	0f 82 78 ff ff ff    	jb     f0103233 <user_mem_check+0x22>
		}
		nxt = (void*) ROUNDUP(ptr, PGSIZE);
		ptr = ptr == nxt ? ptr + PGSIZE : nxt;
	}

	return 0;
f01032bb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01032c0:	83 c4 2c             	add    $0x2c,%esp
f01032c3:	5b                   	pop    %ebx
f01032c4:	5e                   	pop    %esi
f01032c5:	5f                   	pop    %edi
f01032c6:	5d                   	pop    %ebp
f01032c7:	c3                   	ret    

f01032c8 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f01032c8:	55                   	push   %ebp
f01032c9:	89 e5                	mov    %esp,%ebp
f01032cb:	53                   	push   %ebx
f01032cc:	83 ec 14             	sub    $0x14,%esp
f01032cf:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f01032d2:	8b 45 14             	mov    0x14(%ebp),%eax
f01032d5:	83 c8 04             	or     $0x4,%eax
f01032d8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01032dc:	8b 45 10             	mov    0x10(%ebp),%eax
f01032df:	89 44 24 08          	mov    %eax,0x8(%esp)
f01032e3:	8b 45 0c             	mov    0xc(%ebp),%eax
f01032e6:	89 44 24 04          	mov    %eax,0x4(%esp)
f01032ea:	89 1c 24             	mov    %ebx,(%esp)
f01032ed:	e8 1f ff ff ff       	call   f0103211 <user_mem_check>
f01032f2:	85 c0                	test   %eax,%eax
f01032f4:	79 24                	jns    f010331a <user_mem_assert+0x52>
		cprintf("[%08x] user_mem_check assertion failure for "
f01032f6:	a1 3c 62 22 f0       	mov    0xf022623c,%eax
f01032fb:	89 44 24 08          	mov    %eax,0x8(%esp)
f01032ff:	8b 43 48             	mov    0x48(%ebx),%eax
f0103302:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103306:	c7 04 24 60 79 10 f0 	movl   $0xf0107960,(%esp)
f010330d:	e8 c7 09 00 00       	call   f0103cd9 <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f0103312:	89 1c 24             	mov    %ebx,(%esp)
f0103315:	e8 0d 07 00 00       	call   f0103a27 <env_destroy>
	}
}
f010331a:	83 c4 14             	add    $0x14,%esp
f010331d:	5b                   	pop    %ebx
f010331e:	5d                   	pop    %ebp
f010331f:	c3                   	ret    

f0103320 <region_alloc>:
// Pages should be writable by user and kernel.
// Panic if any allocation attempt fails.
//
static void
region_alloc(struct Env *e, void *va, size_t len)
{
f0103320:	55                   	push   %ebp
f0103321:	89 e5                	mov    %esp,%ebp
f0103323:	57                   	push   %edi
f0103324:	56                   	push   %esi
f0103325:	53                   	push   %ebx
f0103326:	83 ec 1c             	sub    $0x1c,%esp
f0103329:	89 c7                	mov    %eax,%edi
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	//cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f010332b:	89 d3                	mov    %edx,%ebx
f010332d:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0103333:	8d b4 0a ff 0f 00 00 	lea    0xfff(%edx,%ecx,1),%esi
f010333a:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
f0103340:	39 f3                	cmp    %esi,%ebx
f0103342:	73 51                	jae    f0103395 <region_alloc+0x75>
	{
		struct Page* p=(struct Page*)page_alloc(1);
f0103344:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010334b:	e8 99 dd ff ff       	call   f01010e9 <page_alloc>
		if(p==NULL)
f0103350:	85 c0                	test   %eax,%eax
f0103352:	75 1c                	jne    f0103370 <region_alloc+0x50>
			panic("Memory out!");
f0103354:	c7 44 24 08 95 79 10 	movl   $0xf0107995,0x8(%esp)
f010335b:	f0 
f010335c:	c7 44 24 04 2e 01 00 	movl   $0x12e,0x4(%esp)
f0103363:	00 
f0103364:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f010336b:	e8 d0 cc ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f0103370:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103377:	00 
f0103378:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010337c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103380:	8b 47 60             	mov    0x60(%edi),%eax
f0103383:	89 04 24             	mov    %eax,(%esp)
f0103386:	e8 77 e0 ff ff       	call   f0101402 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	//cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f010338b:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103391:	39 f3                	cmp    %esi,%ebx
f0103393:	72 af                	jb     f0103344 <region_alloc+0x24>
		if(p==NULL)
			panic("Memory out!");
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
	}

}
f0103395:	83 c4 1c             	add    $0x1c,%esp
f0103398:	5b                   	pop    %ebx
f0103399:	5e                   	pop    %esi
f010339a:	5f                   	pop    %edi
f010339b:	5d                   	pop    %ebp
f010339c:	c3                   	ret    

f010339d <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f010339d:	55                   	push   %ebp
f010339e:	89 e5                	mov    %esp,%ebp
f01033a0:	56                   	push   %esi
f01033a1:	53                   	push   %ebx
f01033a2:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f01033a5:	85 c0                	test   %eax,%eax
f01033a7:	75 1a                	jne    f01033c3 <envid2env+0x26>
		*env_store = curenv;
f01033a9:	e8 25 2e 00 00       	call   f01061d3 <cpunum>
f01033ae:	6b c0 74             	imul   $0x74,%eax,%eax
f01033b1:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f01033b7:	8b 55 0c             	mov    0xc(%ebp),%edx
f01033ba:	89 02                	mov    %eax,(%edx)
		return 0;
f01033bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01033c1:	eb 72                	jmp    f0103435 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f01033c3:	89 c3                	mov    %eax,%ebx
f01033c5:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f01033cb:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f01033ce:	03 1d 48 62 22 f0    	add    0xf0226248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f01033d4:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f01033d8:	74 05                	je     f01033df <envid2env+0x42>
f01033da:	39 43 48             	cmp    %eax,0x48(%ebx)
f01033dd:	74 10                	je     f01033ef <envid2env+0x52>
		*env_store = 0;
f01033df:	8b 45 0c             	mov    0xc(%ebp),%eax
f01033e2:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01033e8:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01033ed:	eb 46                	jmp    f0103435 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01033ef:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01033f3:	74 36                	je     f010342b <envid2env+0x8e>
f01033f5:	e8 d9 2d 00 00       	call   f01061d3 <cpunum>
f01033fa:	6b c0 74             	imul   $0x74,%eax,%eax
f01033fd:	39 98 28 70 22 f0    	cmp    %ebx,-0xfdd8fd8(%eax)
f0103403:	74 26                	je     f010342b <envid2env+0x8e>
f0103405:	8b 73 4c             	mov    0x4c(%ebx),%esi
f0103408:	e8 c6 2d 00 00       	call   f01061d3 <cpunum>
f010340d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103410:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0103416:	3b 70 48             	cmp    0x48(%eax),%esi
f0103419:	74 10                	je     f010342b <envid2env+0x8e>
		*env_store = 0;
f010341b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010341e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f0103424:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103429:	eb 0a                	jmp    f0103435 <envid2env+0x98>
	}

	*env_store = e;
f010342b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010342e:	89 18                	mov    %ebx,(%eax)
	return 0;
f0103430:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0103435:	5b                   	pop    %ebx
f0103436:	5e                   	pop    %esi
f0103437:	5d                   	pop    %ebp
f0103438:	c3                   	ret    

f0103439 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0103439:	55                   	push   %ebp
f010343a:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f010343c:	b8 00 03 12 f0       	mov    $0xf0120300,%eax
f0103441:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f0103444:	b8 23 00 00 00       	mov    $0x23,%eax
f0103449:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f010344b:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f010344d:	b0 10                	mov    $0x10,%al
f010344f:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0103451:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f0103453:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f0103455:	ea 5c 34 10 f0 08 00 	ljmp   $0x8,$0xf010345c
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f010345c:	b0 00                	mov    $0x0,%al
f010345e:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103461:	5d                   	pop    %ebp
f0103462:	c3                   	ret    

f0103463 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f0103463:	55                   	push   %ebp
f0103464:	89 e5                	mov    %esp,%ebp
f0103466:	57                   	push   %edi
f0103467:	56                   	push   %esi
f0103468:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
    {
    	envs[i].env_id=0;
f0103469:	8b 0d 48 62 22 f0    	mov    0xf0226248,%ecx
f010346f:	c7 41 48 00 00 00 00 	movl   $0x0,0x48(%ecx)
f0103476:	89 cf                	mov    %ecx,%edi
f0103478:	8d 51 7c             	lea    0x7c(%ecx),%edx
f010347b:	89 ce                	mov    %ecx,%esi
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f010347d:	b8 00 00 00 00       	mov    $0x0,%eax
    {
    	envs[i].env_id=0;
f0103482:	bb 00 00 00 00       	mov    $0x0,%ebx
f0103487:	eb 02                	jmp    f010348b <env_init+0x28>
f0103489:	89 f9                	mov    %edi,%ecx
    	if(i!=NENV-1)
    	{
    	envs[i].env_link=&envs[i+1];
f010348b:	83 c3 01             	add    $0x1,%ebx
f010348e:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103491:	01 d9                	add    %ebx,%ecx
f0103493:	89 4e 44             	mov    %ecx,0x44(%esi)
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f0103496:	83 c0 01             	add    $0x1,%eax
    {
    	envs[i].env_id=0;
f0103499:	89 c3                	mov    %eax,%ebx
f010349b:	89 d6                	mov    %edx,%esi
f010349d:	c7 42 48 00 00 00 00 	movl   $0x0,0x48(%edx)
f01034a4:	83 c2 7c             	add    $0x7c,%edx
    	if(i!=NENV-1)
f01034a7:	3d ff 03 00 00       	cmp    $0x3ff,%eax
f01034ac:	75 db                	jne    f0103489 <env_init+0x26>
    	{
    	envs[i].env_link=&envs[i+1];
    	}
    }
    env_free_list=envs;
f01034ae:	a1 48 62 22 f0       	mov    0xf0226248,%eax
f01034b3:	a3 4c 62 22 f0       	mov    %eax,0xf022624c
	// Per-CPU part of the initialization
	env_init_percpu();
f01034b8:	e8 7c ff ff ff       	call   f0103439 <env_init_percpu>
}
f01034bd:	5b                   	pop    %ebx
f01034be:	5e                   	pop    %esi
f01034bf:	5f                   	pop    %edi
f01034c0:	5d                   	pop    %ebp
f01034c1:	c3                   	ret    

f01034c2 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f01034c2:	55                   	push   %ebp
f01034c3:	89 e5                	mov    %esp,%ebp
f01034c5:	56                   	push   %esi
f01034c6:	53                   	push   %ebx
f01034c7:	83 ec 10             	sub    $0x10,%esp
    int32_t generation;
    int r;
    struct Env *e;

    if (!(e = env_free_list))
f01034ca:	8b 1d 4c 62 22 f0    	mov    0xf022624c,%ebx
f01034d0:	85 db                	test   %ebx,%ebx
f01034d2:	0f 84 92 01 00 00    	je     f010366a <env_alloc+0x1a8>
{
	int i;
	struct Page *p = NULL;
//	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f01034d8:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01034df:	e8 05 dc ff ff       	call   f01010e9 <page_alloc>
f01034e4:	85 c0                	test   %eax,%eax
f01034e6:	0f 84 85 01 00 00    	je     f0103671 <env_alloc+0x1af>
f01034ec:	89 c2                	mov    %eax,%edx
f01034ee:	2b 15 90 6e 22 f0    	sub    0xf0226e90,%edx
f01034f4:	c1 fa 03             	sar    $0x3,%edx
f01034f7:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01034fa:	89 d1                	mov    %edx,%ecx
f01034fc:	c1 e9 0c             	shr    $0xc,%ecx
f01034ff:	3b 0d 88 6e 22 f0    	cmp    0xf0226e88,%ecx
f0103505:	72 20                	jb     f0103527 <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103507:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010350b:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0103512:	f0 
f0103513:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010351a:	00 
f010351b:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0103522:	e8 19 cb ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103527:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f010352d:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
f0103530:	ba ec 0e 00 00       	mov    $0xeec,%edx
    for(i=PDX(UTOP);i<1024;i++)
    {
    	e->env_pgdir[i]=kern_pgdir[i];
f0103535:	8b 0d 8c 6e 22 f0    	mov    0xf0226e8c,%ecx
f010353b:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f010353e:	8b 4b 60             	mov    0x60(%ebx),%ecx
f0103541:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f0103544:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
    for(i=PDX(UTOP);i<1024;i++)
f0103547:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f010354d:	75 e6                	jne    f0103535 <env_alloc+0x73>
    {
    	e->env_pgdir[i]=kern_pgdir[i];
    }
    p->pp_ref++;
f010354f:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0103554:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103557:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010355c:	77 20                	ja     f010357e <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010355e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103562:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0103569:	f0 
f010356a:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
f0103571:	00 
f0103572:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f0103579:	e8 c2 ca ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010357e:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103584:	83 ca 05             	or     $0x5,%edx
f0103587:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
    // Allocate and set up the page directory for this environment.
    if ((r = env_setup_vm(e)) < 0)
        return r;

    // Generate an env_id for this environment.
    generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010358d:	8b 43 48             	mov    0x48(%ebx),%eax
f0103590:	05 00 10 00 00       	add    $0x1000,%eax
    if (generation <= 0)    // Don't create a negative env_id.
f0103595:	25 00 fc ff ff       	and    $0xfffffc00,%eax
        generation = 1 << ENVGENSHIFT;
f010359a:	ba 00 10 00 00       	mov    $0x1000,%edx
f010359f:	0f 4e c2             	cmovle %edx,%eax
    e->env_id = generation | (e - envs);
f01035a2:	89 da                	mov    %ebx,%edx
f01035a4:	2b 15 48 62 22 f0    	sub    0xf0226248,%edx
f01035aa:	c1 fa 02             	sar    $0x2,%edx
f01035ad:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01035b3:	09 d0                	or     %edx,%eax
f01035b5:	89 43 48             	mov    %eax,0x48(%ebx)

    // Set the basic status variables.
    e->env_parent_id = parent_id;
f01035b8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01035bb:	89 43 4c             	mov    %eax,0x4c(%ebx)
    e->env_type = ENV_TYPE_USER;
f01035be:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
    e->env_status = ENV_RUNNABLE;
f01035c5:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
    e->env_runs = 0;
f01035cc:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

    // Clear out all the saved register state,
    // to prevent the register values
    // of a prior environment inhabiting this Env structure
    // from "leaking" into our new environment.
    memset(&e->env_tf, 0, sizeof(e->env_tf));
f01035d3:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f01035da:	00 
f01035db:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01035e2:	00 
f01035e3:	89 1c 24             	mov    %ebx,(%esp)
f01035e6:	e8 4e 25 00 00       	call   f0105b39 <memset>
    // The low 2 bits of each segment register contains the
    // Requestor Privilege Level (RPL); 3 means user mode.  When
    // we switch privilege levels, the hardware does various
    // checks involving the RPL and the Descriptor Privilege Level
    // (DPL) stored in the descriptors themselves.
    e->env_tf.tf_ds = GD_UD | 3;
f01035eb:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
    e->env_tf.tf_es = GD_UD | 3;
f01035f1:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
    e->env_tf.tf_ss = GD_UD | 3;
f01035f7:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
    e->env_tf.tf_esp = USTACKTOP;
f01035fd:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
    e->env_tf.tf_cs = GD_UT | 3;
f0103604:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)
    // Enable interrupts while in user mode.
    // LAB 4: Your code here.
   // e->env_tf.tf_eflags |= FL_IF;

    // Clear the page fault handler until user installs one.
    e->env_pgfault_upcall = 0;
f010360a:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

    // Also clear the IPC receiving flag.
    e->env_ipc_recving = 0;
f0103611:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

    // commit the allocation
    env_free_list = e->env_link;
f0103618:	8b 43 44             	mov    0x44(%ebx),%eax
f010361b:	a3 4c 62 22 f0       	mov    %eax,0xf022624c
    *newenv_store = e;
f0103620:	8b 45 08             	mov    0x8(%ebp),%eax
f0103623:	89 18                	mov    %ebx,(%eax)

    cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103625:	8b 5b 48             	mov    0x48(%ebx),%ebx
f0103628:	e8 a6 2b 00 00       	call   f01061d3 <cpunum>
f010362d:	6b d0 74             	imul   $0x74,%eax,%edx
f0103630:	b8 00 00 00 00       	mov    $0x0,%eax
f0103635:	83 ba 28 70 22 f0 00 	cmpl   $0x0,-0xfdd8fd8(%edx)
f010363c:	74 11                	je     f010364f <env_alloc+0x18d>
f010363e:	e8 90 2b 00 00       	call   f01061d3 <cpunum>
f0103643:	6b c0 74             	imul   $0x74,%eax,%eax
f0103646:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f010364c:	8b 40 48             	mov    0x48(%eax),%eax
f010364f:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103653:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103657:	c7 04 24 ac 79 10 f0 	movl   $0xf01079ac,(%esp)
f010365e:	e8 76 06 00 00       	call   f0103cd9 <cprintf>
    return 0;
f0103663:	b8 00 00 00 00       	mov    $0x0,%eax
f0103668:	eb 0c                	jmp    f0103676 <env_alloc+0x1b4>
    int32_t generation;
    int r;
    struct Env *e;

    if (!(e = env_free_list))
        return -E_NO_FREE_ENV;
f010366a:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f010366f:	eb 05                	jmp    f0103676 <env_alloc+0x1b4>
	int i;
	struct Page *p = NULL;
//	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0103671:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
    env_free_list = e->env_link;
    *newenv_store = e;

    cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
    return 0;
}
f0103676:	83 c4 10             	add    $0x10,%esp
f0103679:	5b                   	pop    %ebx
f010367a:	5e                   	pop    %esi
f010367b:	5d                   	pop    %ebp
f010367c:	c3                   	ret    

f010367d <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f010367d:	55                   	push   %ebp
f010367e:	89 e5                	mov    %esp,%ebp
f0103680:	57                   	push   %edi
f0103681:	56                   	push   %esi
f0103682:	53                   	push   %ebx
f0103683:	83 ec 3c             	sub    $0x3c,%esp
f0103686:	8b 75 08             	mov    0x8(%ebp),%esi
	// LAB 3: Your code here.

	struct Env* env;

	if(env_alloc(&env,0)==0)
f0103689:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103690:	00 
f0103691:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103694:	89 04 24             	mov    %eax,(%esp)
f0103697:	e8 26 fe ff ff       	call   f01034c2 <env_alloc>
f010369c:	85 c0                	test   %eax,%eax
f010369e:	0f 85 76 01 00 00    	jne    f010381a <env_create+0x19d>
	{
		env->env_type=type;
f01036a4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01036a7:	89 c7                	mov    %eax,%edi
f01036a9:	89 45 d0             	mov    %eax,-0x30(%ebp)
f01036ac:	8b 45 10             	mov    0x10(%ebp),%eax
f01036af:	89 47 50             	mov    %eax,0x50(%edi)
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f01036b2:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01036b5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01036ba:	77 20                	ja     f01036dc <env_create+0x5f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01036bc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01036c0:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f01036c7:	f0 
f01036c8:	c7 44 24 04 6a 01 00 	movl   $0x16a,0x4(%esp)
f01036cf:	00 
f01036d0:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f01036d7:	e8 64 c9 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01036dc:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f01036e1:	0f 22 d8             	mov    %eax,%cr3
	//cprintf("load_icode\r\n");
	struct Elf * ELFHDR=(struct Elf *)binary;
	struct Proghdr *ph, *eph;
	int i;
	if (ELFHDR->e_magic != ELF_MAGIC)
f01036e4:	81 3e 7f 45 4c 46    	cmpl   $0x464c457f,(%esi)
f01036ea:	74 1c                	je     f0103708 <env_create+0x8b>
			panic("Not a elf binary");
f01036ec:	c7 44 24 08 c1 79 10 	movl   $0xf01079c1,0x8(%esp)
f01036f3:	f0 
f01036f4:	c7 44 24 04 70 01 00 	movl   $0x170,0x4(%esp)
f01036fb:	00 
f01036fc:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f0103703:	e8 38 c9 ff ff       	call   f0100040 <_panic>


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0103708:	89 f3                	mov    %esi,%ebx
f010370a:	03 5e 1c             	add    0x1c(%esi),%ebx
		eph = ph + ELFHDR->e_phnum;
f010370d:	0f b7 46 2c          	movzwl 0x2c(%esi),%eax
f0103711:	c1 e0 05             	shl    $0x5,%eax
f0103714:	01 d8                	add    %ebx,%eax
f0103716:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		for (; ph < eph; ph++)
f0103719:	39 c3                	cmp    %eax,%ebx
f010371b:	73 44                	jae    f0103761 <env_create+0xe4>
		{
			// p_pa is the load address of this segment (as well
			// as the physical address)
			if(ph->p_type==ELF_PROG_LOAD)
f010371d:	83 3b 01             	cmpl   $0x1,(%ebx)
f0103720:	75 37                	jne    f0103759 <env_create+0xdc>
			{
		//	cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
f0103722:	8b 4b 10             	mov    0x10(%ebx),%ecx
f0103725:	8b 53 08             	mov    0x8(%ebx),%edx
f0103728:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010372b:	e8 f0 fb ff ff       	call   f0103320 <region_alloc>
			char* va=(char*)ph->p_va;
f0103730:	8b 7b 08             	mov    0x8(%ebx),%edi
			for(i=0;i<ph->p_filesz;i++)
f0103733:	83 7b 10 00          	cmpl   $0x0,0x10(%ebx)
f0103737:	74 20                	je     f0103759 <env_create+0xdc>
f0103739:	b8 00 00 00 00       	mov    $0x0,%eax
f010373e:	ba 00 00 00 00       	mov    $0x0,%edx
			{

				va[i]=binary[ph->p_offset+i];
f0103743:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
f0103746:	03 4b 04             	add    0x4(%ebx),%ecx
f0103749:	0f b6 09             	movzbl (%ecx),%ecx
f010374c:	88 0c 17             	mov    %cl,(%edi,%edx,1)
			if(ph->p_type==ELF_PROG_LOAD)
			{
		//	cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
			char* va=(char*)ph->p_va;
			for(i=0;i<ph->p_filesz;i++)
f010374f:	83 c0 01             	add    $0x1,%eax
f0103752:	89 c2                	mov    %eax,%edx
f0103754:	3b 43 10             	cmp    0x10(%ebx),%eax
f0103757:	72 ea                	jb     f0103743 <env_create+0xc6>
			panic("Not a elf binary");


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
		eph = ph + ELFHDR->e_phnum;
		for (; ph < eph; ph++)
f0103759:	83 c3 20             	add    $0x20,%ebx
f010375c:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f010375f:	77 bc                	ja     f010371d <env_create+0xa0>
			}

			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
f0103761:	89 f3                	mov    %esi,%ebx
f0103763:	03 5e 20             	add    0x20(%esi),%ebx
		eshdr= shdr + ELFHDR->e_shnum;
f0103766:	0f b7 46 30          	movzwl 0x30(%esi),%eax
f010376a:	8d 04 80             	lea    (%eax,%eax,4),%eax
f010376d:	8d 3c c3             	lea    (%ebx,%eax,8),%edi
				for (; shdr < eshdr; shdr++)
f0103770:	39 fb                	cmp    %edi,%ebx
f0103772:	73 1b                	jae    f010378f <env_create+0x112>
				{
					// p_pa is the load address of this segment (as well
					// as the physical address)
					if(shdr->sh_type==8)
f0103774:	83 7b 04 08          	cmpl   $0x8,0x4(%ebx)
f0103778:	75 0e                	jne    f0103788 <env_create+0x10b>
					{
			//		cprintf("section %08x %08x %08x %08x\r\n",shdr->sh_size,shdr->sh_addr,shdr->sh_offset,shdr->sh_type);
					region_alloc(e,(void*)shdr->sh_addr,shdr->sh_size);
f010377a:	8b 4b 14             	mov    0x14(%ebx),%ecx
f010377d:	8b 53 0c             	mov    0xc(%ebx),%edx
f0103780:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103783:	e8 98 fb ff ff       	call   f0103320 <region_alloc>
			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
		eshdr= shdr + ELFHDR->e_shnum;
				for (; shdr < eshdr; shdr++)
f0103788:	83 c3 28             	add    $0x28,%ebx
f010378b:	39 df                	cmp    %ebx,%edi
f010378d:	77 e5                	ja     f0103774 <env_create+0xf7>


					}
				}

		e->env_tf.tf_eip=ELFHDR->e_entry;
f010378f:	8b 46 18             	mov    0x18(%esi),%eax
f0103792:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0103795:	89 46 30             	mov    %eax,0x30(%esi)

	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
		struct Page* p=(struct Page*)page_alloc(1);
f0103798:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010379f:	e8 45 d9 ff ff       	call   f01010e9 <page_alloc>
     if(p==NULL)
f01037a4:	85 c0                	test   %eax,%eax
f01037a6:	75 1c                	jne    f01037c4 <env_create+0x147>
    	 panic("Not enough mem for user stack!");
f01037a8:	c7 44 24 08 f4 79 10 	movl   $0xf01079f4,0x8(%esp)
f01037af:	f0 
f01037b0:	c7 44 24 04 9e 01 00 	movl   $0x19e,0x4(%esp)
f01037b7:	00 
f01037b8:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f01037bf:	e8 7c c8 ff ff       	call   f0100040 <_panic>
     page_insert(e->env_pgdir,p,(void*)(USTACKTOP-PGSIZE),PTE_W|PTE_U);
f01037c4:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01037cb:	00 
f01037cc:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f01037d3:	ee 
f01037d4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01037d8:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01037db:	8b 40 60             	mov    0x60(%eax),%eax
f01037de:	89 04 24             	mov    %eax,(%esp)
f01037e1:	e8 1c dc ff ff       	call   f0101402 <page_insert>
  //   cprintf("load_icode finish!\r\n");
     lcr3(PADDR(kern_pgdir));
f01037e6:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01037eb:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01037f0:	77 20                	ja     f0103812 <env_create+0x195>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01037f2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01037f6:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f01037fd:	f0 
f01037fe:	c7 44 24 04 a1 01 00 	movl   $0x1a1,0x4(%esp)
f0103805:	00 
f0103806:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f010380d:	e8 2e c8 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103812:	05 00 00 00 10       	add    $0x10000000,%eax
f0103817:	0f 22 d8             	mov    %eax,%cr3
	{
		env->env_type=type;
		load_icode(env, binary,size);
	}

}
f010381a:	83 c4 3c             	add    $0x3c,%esp
f010381d:	5b                   	pop    %ebx
f010381e:	5e                   	pop    %esi
f010381f:	5f                   	pop    %edi
f0103820:	5d                   	pop    %ebp
f0103821:	c3                   	ret    

f0103822 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103822:	55                   	push   %ebp
f0103823:	89 e5                	mov    %esp,%ebp
f0103825:	57                   	push   %edi
f0103826:	56                   	push   %esi
f0103827:	53                   	push   %ebx
f0103828:	83 ec 2c             	sub    $0x2c,%esp
f010382b:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f010382e:	e8 a0 29 00 00       	call   f01061d3 <cpunum>
f0103833:	6b c0 74             	imul   $0x74,%eax,%eax
f0103836:	39 b8 28 70 22 f0    	cmp    %edi,-0xfdd8fd8(%eax)
f010383c:	75 34                	jne    f0103872 <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f010383e:	a1 8c 6e 22 f0       	mov    0xf0226e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103843:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103848:	77 20                	ja     f010386a <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010384a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010384e:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0103855:	f0 
f0103856:	c7 44 24 04 c8 01 00 	movl   $0x1c8,0x4(%esp)
f010385d:	00 
f010385e:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f0103865:	e8 d6 c7 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010386a:	05 00 00 00 10       	add    $0x10000000,%eax
f010386f:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103872:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103875:	e8 59 29 00 00       	call   f01061d3 <cpunum>
f010387a:	6b d0 74             	imul   $0x74,%eax,%edx
f010387d:	b8 00 00 00 00       	mov    $0x0,%eax
f0103882:	83 ba 28 70 22 f0 00 	cmpl   $0x0,-0xfdd8fd8(%edx)
f0103889:	74 11                	je     f010389c <env_free+0x7a>
f010388b:	e8 43 29 00 00       	call   f01061d3 <cpunum>
f0103890:	6b c0 74             	imul   $0x74,%eax,%eax
f0103893:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0103899:	8b 40 48             	mov    0x48(%eax),%eax
f010389c:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01038a0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01038a4:	c7 04 24 d2 79 10 f0 	movl   $0xf01079d2,(%esp)
f01038ab:	e8 29 04 00 00       	call   f0103cd9 <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f01038b0:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f01038b7:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f01038ba:	89 c8                	mov    %ecx,%eax
f01038bc:	c1 e0 02             	shl    $0x2,%eax
f01038bf:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f01038c2:	8b 47 60             	mov    0x60(%edi),%eax
f01038c5:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f01038c8:	f7 c6 01 00 00 00    	test   $0x1,%esi
f01038ce:	0f 84 b7 00 00 00    	je     f010398b <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f01038d4:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01038da:	89 f0                	mov    %esi,%eax
f01038dc:	c1 e8 0c             	shr    $0xc,%eax
f01038df:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01038e2:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f01038e8:	72 20                	jb     f010390a <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01038ea:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01038ee:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f01038f5:	f0 
f01038f6:	c7 44 24 04 d7 01 00 	movl   $0x1d7,0x4(%esp)
f01038fd:	00 
f01038fe:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f0103905:	e8 36 c7 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f010390a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010390d:	c1 e0 16             	shl    $0x16,%eax
f0103910:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103913:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103918:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f010391f:	01 
f0103920:	74 17                	je     f0103939 <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103922:	89 d8                	mov    %ebx,%eax
f0103924:	c1 e0 0c             	shl    $0xc,%eax
f0103927:	0b 45 e4             	or     -0x1c(%ebp),%eax
f010392a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010392e:	8b 47 60             	mov    0x60(%edi),%eax
f0103931:	89 04 24             	mov    %eax,(%esp)
f0103934:	e8 77 da ff ff       	call   f01013b0 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103939:	83 c3 01             	add    $0x1,%ebx
f010393c:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103942:	75 d4                	jne    f0103918 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103944:	8b 47 60             	mov    0x60(%edi),%eax
f0103947:	8b 55 dc             	mov    -0x24(%ebp),%edx
f010394a:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103951:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103954:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f010395a:	72 1c                	jb     f0103978 <env_free+0x156>
		panic("pa2page called with invalid pa");
f010395c:	c7 44 24 08 e4 72 10 	movl   $0xf01072e4,0x8(%esp)
f0103963:	f0 
f0103964:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010396b:	00 
f010396c:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f0103973:	e8 c8 c6 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103978:	a1 90 6e 22 f0       	mov    0xf0226e90,%eax
f010397d:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103980:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103983:	89 04 24             	mov    %eax,(%esp)
f0103986:	e8 18 d8 ff ff       	call   f01011a3 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f010398b:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f010398f:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103996:	0f 85 1b ff ff ff    	jne    f01038b7 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f010399c:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010399f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01039a4:	77 20                	ja     f01039c6 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01039a6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01039aa:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f01039b1:	f0 
f01039b2:	c7 44 24 04 e5 01 00 	movl   $0x1e5,0x4(%esp)
f01039b9:	00 
f01039ba:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f01039c1:	e8 7a c6 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f01039c6:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f01039cd:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01039d2:	c1 e8 0c             	shr    $0xc,%eax
f01039d5:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f01039db:	72 1c                	jb     f01039f9 <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f01039dd:	c7 44 24 08 e4 72 10 	movl   $0xf01072e4,0x8(%esp)
f01039e4:	f0 
f01039e5:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01039ec:	00 
f01039ed:	c7 04 24 76 6e 10 f0 	movl   $0xf0106e76,(%esp)
f01039f4:	e8 47 c6 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f01039f9:	8b 15 90 6e 22 f0    	mov    0xf0226e90,%edx
f01039ff:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103a02:	89 04 24             	mov    %eax,(%esp)
f0103a05:	e8 99 d7 ff ff       	call   f01011a3 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103a0a:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103a11:	a1 4c 62 22 f0       	mov    0xf022624c,%eax
f0103a16:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103a19:	89 3d 4c 62 22 f0    	mov    %edi,0xf022624c
}
f0103a1f:	83 c4 2c             	add    $0x2c,%esp
f0103a22:	5b                   	pop    %ebx
f0103a23:	5e                   	pop    %esi
f0103a24:	5f                   	pop    %edi
f0103a25:	5d                   	pop    %ebp
f0103a26:	c3                   	ret    

f0103a27 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103a27:	55                   	push   %ebp
f0103a28:	89 e5                	mov    %esp,%ebp
f0103a2a:	53                   	push   %ebx
f0103a2b:	83 ec 14             	sub    $0x14,%esp
f0103a2e:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103a31:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103a35:	75 19                	jne    f0103a50 <env_destroy+0x29>
f0103a37:	e8 97 27 00 00       	call   f01061d3 <cpunum>
f0103a3c:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a3f:	39 98 28 70 22 f0    	cmp    %ebx,-0xfdd8fd8(%eax)
f0103a45:	74 09                	je     f0103a50 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103a47:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103a4e:	eb 2f                	jmp    f0103a7f <env_destroy+0x58>
	}

	env_free(e);
f0103a50:	89 1c 24             	mov    %ebx,(%esp)
f0103a53:	e8 ca fd ff ff       	call   f0103822 <env_free>

	if (curenv == e) {
f0103a58:	e8 76 27 00 00       	call   f01061d3 <cpunum>
f0103a5d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a60:	39 98 28 70 22 f0    	cmp    %ebx,-0xfdd8fd8(%eax)
f0103a66:	75 17                	jne    f0103a7f <env_destroy+0x58>
		curenv = NULL;
f0103a68:	e8 66 27 00 00       	call   f01061d3 <cpunum>
f0103a6d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a70:	c7 80 28 70 22 f0 00 	movl   $0x0,-0xfdd8fd8(%eax)
f0103a77:	00 00 00 
		sched_yield();
f0103a7a:	e8 81 0c 00 00       	call   f0104700 <sched_yield>
	}
}
f0103a7f:	83 c4 14             	add    $0x14,%esp
f0103a82:	5b                   	pop    %ebx
f0103a83:	5d                   	pop    %ebp
f0103a84:	c3                   	ret    

f0103a85 <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103a85:	55                   	push   %ebp
f0103a86:	89 e5                	mov    %esp,%ebp
f0103a88:	53                   	push   %ebx
f0103a89:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103a8c:	e8 42 27 00 00       	call   f01061d3 <cpunum>
f0103a91:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a94:	8b 98 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%ebx
f0103a9a:	e8 34 27 00 00       	call   f01061d3 <cpunum>
f0103a9f:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103aa2:	8b 65 08             	mov    0x8(%ebp),%esp
f0103aa5:	61                   	popa   
f0103aa6:	07                   	pop    %es
f0103aa7:	1f                   	pop    %ds
f0103aa8:	83 c4 08             	add    $0x8,%esp
f0103aab:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103aac:	c7 44 24 08 e8 79 10 	movl   $0xf01079e8,0x8(%esp)
f0103ab3:	f0 
f0103ab4:	c7 44 24 04 1b 02 00 	movl   $0x21b,0x4(%esp)
f0103abb:	00 
f0103abc:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f0103ac3:	e8 78 c5 ff ff       	call   f0100040 <_panic>

f0103ac8 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103ac8:	55                   	push   %ebp
f0103ac9:	89 e5                	mov    %esp,%ebp
f0103acb:	53                   	push   %ebx
f0103acc:	83 ec 14             	sub    $0x14,%esp
f0103acf:	8b 5d 08             	mov    0x8(%ebp),%ebx
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.
	//cprintf("Run env!\r\n");
    if(curenv!=NULL)
f0103ad2:	e8 fc 26 00 00       	call   f01061d3 <cpunum>
f0103ad7:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ada:	83 b8 28 70 22 f0 00 	cmpl   $0x0,-0xfdd8fd8(%eax)
f0103ae1:	74 29                	je     f0103b0c <env_run+0x44>
    {
    	if(curenv->env_status==ENV_RUNNING)
f0103ae3:	e8 eb 26 00 00       	call   f01061d3 <cpunum>
f0103ae8:	6b c0 74             	imul   $0x74,%eax,%eax
f0103aeb:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0103af1:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103af5:	75 15                	jne    f0103b0c <env_run+0x44>
    	{
    		curenv->env_status=ENV_RUNNABLE;
f0103af7:	e8 d7 26 00 00       	call   f01061d3 <cpunum>
f0103afc:	6b c0 74             	imul   $0x74,%eax,%eax
f0103aff:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0103b05:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
    	}
    }
    curenv=e;
f0103b0c:	e8 c2 26 00 00       	call   f01061d3 <cpunum>
f0103b11:	6b c0 74             	imul   $0x74,%eax,%eax
f0103b14:	89 98 28 70 22 f0    	mov    %ebx,-0xfdd8fd8(%eax)
    e->env_status=ENV_RUNNING;
f0103b1a:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
    e->env_runs++;
f0103b21:	83 43 58 01          	addl   $0x1,0x58(%ebx)
    lcr3(PADDR(e->env_pgdir));
f0103b25:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103b28:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103b2d:	77 20                	ja     f0103b4f <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103b2f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b33:	c7 44 24 08 28 69 10 	movl   $0xf0106928,0x8(%esp)
f0103b3a:	f0 
f0103b3b:	c7 44 24 04 44 02 00 	movl   $0x244,0x4(%esp)
f0103b42:	00 
f0103b43:	c7 04 24 a1 79 10 f0 	movl   $0xf01079a1,(%esp)
f0103b4a:	e8 f1 c4 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103b4f:	05 00 00 00 10       	add    $0x10000000,%eax
f0103b54:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103b57:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f0103b5e:	e8 b9 29 00 00       	call   f010651c <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103b63:	f3 90                	pause  
	unlock_kernel();
    env_pop_tf(&e->env_tf);
f0103b65:	89 1c 24             	mov    %ebx,(%esp)
f0103b68:	e8 18 ff ff ff       	call   f0103a85 <env_pop_tf>

f0103b6d <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103b6d:	55                   	push   %ebp
f0103b6e:	89 e5                	mov    %esp,%ebp
f0103b70:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103b74:	ba 70 00 00 00       	mov    $0x70,%edx
f0103b79:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103b7a:	b2 71                	mov    $0x71,%dl
f0103b7c:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103b7d:	0f b6 c0             	movzbl %al,%eax
}
f0103b80:	5d                   	pop    %ebp
f0103b81:	c3                   	ret    

f0103b82 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103b82:	55                   	push   %ebp
f0103b83:	89 e5                	mov    %esp,%ebp
f0103b85:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103b89:	ba 70 00 00 00       	mov    $0x70,%edx
f0103b8e:	ee                   	out    %al,(%dx)
f0103b8f:	b2 71                	mov    $0x71,%dl
f0103b91:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103b94:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103b95:	5d                   	pop    %ebp
f0103b96:	c3                   	ret    

f0103b97 <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103b97:	55                   	push   %ebp
f0103b98:	89 e5                	mov    %esp,%ebp
f0103b9a:	56                   	push   %esi
f0103b9b:	53                   	push   %ebx
f0103b9c:	83 ec 10             	sub    $0x10,%esp
f0103b9f:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103ba2:	66 a3 88 03 12 f0    	mov    %ax,0xf0120388
	if (!didinit)
f0103ba8:	83 3d 50 62 22 f0 00 	cmpl   $0x0,0xf0226250
f0103baf:	74 4e                	je     f0103bff <irq_setmask_8259A+0x68>
f0103bb1:	89 c6                	mov    %eax,%esi
f0103bb3:	ba 21 00 00 00       	mov    $0x21,%edx
f0103bb8:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103bb9:	66 c1 e8 08          	shr    $0x8,%ax
f0103bbd:	b2 a1                	mov    $0xa1,%dl
f0103bbf:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103bc0:	c7 04 24 13 7a 10 f0 	movl   $0xf0107a13,(%esp)
f0103bc7:	e8 0d 01 00 00       	call   f0103cd9 <cprintf>
	for (i = 0; i < 16; i++)
f0103bcc:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103bd1:	0f b7 f6             	movzwl %si,%esi
f0103bd4:	f7 d6                	not    %esi
f0103bd6:	0f a3 de             	bt     %ebx,%esi
f0103bd9:	73 10                	jae    f0103beb <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103bdb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103bdf:	c7 04 24 89 6f 10 f0 	movl   $0xf0106f89,(%esp)
f0103be6:	e8 ee 00 00 00       	call   f0103cd9 <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103beb:	83 c3 01             	add    $0x1,%ebx
f0103bee:	83 fb 10             	cmp    $0x10,%ebx
f0103bf1:	75 e3                	jne    f0103bd6 <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103bf3:	c7 04 24 67 71 10 f0 	movl   $0xf0107167,(%esp)
f0103bfa:	e8 da 00 00 00       	call   f0103cd9 <cprintf>
}
f0103bff:	83 c4 10             	add    $0x10,%esp
f0103c02:	5b                   	pop    %ebx
f0103c03:	5e                   	pop    %esi
f0103c04:	5d                   	pop    %ebp
f0103c05:	c3                   	ret    

f0103c06 <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103c06:	c7 05 50 62 22 f0 01 	movl   $0x1,0xf0226250
f0103c0d:	00 00 00 
f0103c10:	ba 21 00 00 00       	mov    $0x21,%edx
f0103c15:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103c1a:	ee                   	out    %al,(%dx)
f0103c1b:	b2 a1                	mov    $0xa1,%dl
f0103c1d:	ee                   	out    %al,(%dx)
f0103c1e:	b2 20                	mov    $0x20,%dl
f0103c20:	b8 11 00 00 00       	mov    $0x11,%eax
f0103c25:	ee                   	out    %al,(%dx)
f0103c26:	b2 21                	mov    $0x21,%dl
f0103c28:	b8 20 00 00 00       	mov    $0x20,%eax
f0103c2d:	ee                   	out    %al,(%dx)
f0103c2e:	b8 04 00 00 00       	mov    $0x4,%eax
f0103c33:	ee                   	out    %al,(%dx)
f0103c34:	b8 03 00 00 00       	mov    $0x3,%eax
f0103c39:	ee                   	out    %al,(%dx)
f0103c3a:	b2 a0                	mov    $0xa0,%dl
f0103c3c:	b8 11 00 00 00       	mov    $0x11,%eax
f0103c41:	ee                   	out    %al,(%dx)
f0103c42:	b2 a1                	mov    $0xa1,%dl
f0103c44:	b8 28 00 00 00       	mov    $0x28,%eax
f0103c49:	ee                   	out    %al,(%dx)
f0103c4a:	b8 02 00 00 00       	mov    $0x2,%eax
f0103c4f:	ee                   	out    %al,(%dx)
f0103c50:	b8 01 00 00 00       	mov    $0x1,%eax
f0103c55:	ee                   	out    %al,(%dx)
f0103c56:	b2 20                	mov    $0x20,%dl
f0103c58:	b8 68 00 00 00       	mov    $0x68,%eax
f0103c5d:	ee                   	out    %al,(%dx)
f0103c5e:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103c63:	ee                   	out    %al,(%dx)
f0103c64:	b2 a0                	mov    $0xa0,%dl
f0103c66:	b8 68 00 00 00       	mov    $0x68,%eax
f0103c6b:	ee                   	out    %al,(%dx)
f0103c6c:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103c71:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103c72:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f0103c79:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103c7d:	74 12                	je     f0103c91 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103c7f:	55                   	push   %ebp
f0103c80:	89 e5                	mov    %esp,%ebp
f0103c82:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103c85:	0f b7 c0             	movzwl %ax,%eax
f0103c88:	89 04 24             	mov    %eax,(%esp)
f0103c8b:	e8 07 ff ff ff       	call   f0103b97 <irq_setmask_8259A>
}
f0103c90:	c9                   	leave  
f0103c91:	f3 c3                	repz ret 

f0103c93 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103c93:	55                   	push   %ebp
f0103c94:	89 e5                	mov    %esp,%ebp
f0103c96:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103c99:	8b 45 08             	mov    0x8(%ebp),%eax
f0103c9c:	89 04 24             	mov    %eax,(%esp)
f0103c9f:	e8 39 cb ff ff       	call   f01007dd <cputchar>
	*cnt++;
}
f0103ca4:	c9                   	leave  
f0103ca5:	c3                   	ret    

f0103ca6 <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103ca6:	55                   	push   %ebp
f0103ca7:	89 e5                	mov    %esp,%ebp
f0103ca9:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103cac:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103cb3:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103cb6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103cba:	8b 45 08             	mov    0x8(%ebp),%eax
f0103cbd:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103cc1:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103cc4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103cc8:	c7 04 24 93 3c 10 f0 	movl   $0xf0103c93,(%esp)
f0103ccf:	e8 66 16 00 00       	call   f010533a <vprintfmt>
	return cnt;
}
f0103cd4:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103cd7:	c9                   	leave  
f0103cd8:	c3                   	ret    

f0103cd9 <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103cd9:	55                   	push   %ebp
f0103cda:	89 e5                	mov    %esp,%ebp
f0103cdc:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103cdf:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103ce2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103ce6:	8b 45 08             	mov    0x8(%ebp),%eax
f0103ce9:	89 04 24             	mov    %eax,(%esp)
f0103cec:	e8 b5 ff ff ff       	call   f0103ca6 <vcprintf>
	va_end(ap);

	return cnt;
}
f0103cf1:	c9                   	leave  
f0103cf2:	c3                   	ret    
f0103cf3:	66 90                	xchg   %ax,%ax
f0103cf5:	66 90                	xchg   %ax,%ax
f0103cf7:	66 90                	xchg   %ax,%ax
f0103cf9:	66 90                	xchg   %ax,%ax
f0103cfb:	66 90                	xchg   %ax,%ax
f0103cfd:	66 90                	xchg   %ax,%ax
f0103cff:	90                   	nop

f0103d00 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103d00:	55                   	push   %ebp
f0103d01:	89 e5                	mov    %esp,%ebp
f0103d03:	53                   	push   %ebx
f0103d04:	83 ec 04             	sub    $0x4,%esp
	// wrong, you may not get a fault until you try to return from
	// user space on that CPU.
	//
	// LAB 4: Your code here:

	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103d07:	e8 c7 24 00 00       	call   f01061d3 <cpunum>
f0103d0c:	6b d8 74             	imul   $0x74,%eax,%ebx
	int CPUID = cpunum();
f0103d0f:	e8 bf 24 00 00       	call   f01061d3 <cpunum>

	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
f0103d14:	89 c2                	mov    %eax,%edx
f0103d16:	f7 da                	neg    %edx
f0103d18:	c1 e2 10             	shl    $0x10,%edx
f0103d1b:	81 ea 00 00 40 10    	sub    $0x10400000,%edx
f0103d21:	89 93 30 70 22 f0    	mov    %edx,-0xfdd8fd0(%ebx)
	this_ts->ts_ss0 = GD_KD;
f0103d27:	66 c7 83 34 70 22 f0 	movw   $0x10,-0xfdd8fcc(%ebx)
f0103d2e:	10 00 
	// wrong, you may not get a fault until you try to return from
	// user space on that CPU.
	//
	// LAB 4: Your code here:

	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103d30:	81 c3 2c 70 22 f0    	add    $0xf022702c,%ebx
	int CPUID = cpunum();

	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
	this_ts->ts_ss0 = GD_KD;

	gdt[(GD_TSS0 >> 3) + CPUID] = SEG16(STS_T32A, (uint32_t) (this_ts),
f0103d36:	8d 50 05             	lea    0x5(%eax),%edx
f0103d39:	66 c7 04 d5 20 03 12 	movw   $0x68,-0xfedfce0(,%edx,8)
f0103d40:	f0 68 00 
f0103d43:	66 89 1c d5 22 03 12 	mov    %bx,-0xfedfcde(,%edx,8)
f0103d4a:	f0 
f0103d4b:	89 d9                	mov    %ebx,%ecx
f0103d4d:	c1 e9 10             	shr    $0x10,%ecx
f0103d50:	88 0c d5 24 03 12 f0 	mov    %cl,-0xfedfcdc(,%edx,8)
f0103d57:	c6 04 d5 26 03 12 f0 	movb   $0x40,-0xfedfcda(,%edx,8)
f0103d5e:	40 
f0103d5f:	c1 eb 18             	shr    $0x18,%ebx
f0103d62:	88 1c d5 27 03 12 f0 	mov    %bl,-0xfedfcd9(,%edx,8)
					sizeof(struct Taskstate), 0);
	gdt[(GD_TSS0 >> 3) + CPUID].sd_s = 0;
f0103d69:	c6 04 d5 25 03 12 f0 	movb   $0x89,-0xfedfcdb(,%edx,8)
f0103d70:	89 

	//cprintf("Loading GD_TSS_ %d\n", ((GD_TSS0>>3) + CPUID)<<3);

	ltr(GD_TSS0 + (CPUID << 3));
f0103d71:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103d78:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103d7b:	b8 8a 03 12 f0       	mov    $0xf012038a,%eax
f0103d80:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f0103d83:	83 c4 04             	add    $0x4,%esp
f0103d86:	5b                   	pop    %ebx
f0103d87:	5d                   	pop    %ebp
f0103d88:	c3                   	ret    

f0103d89 <trap_init>:
}


void
trap_init(void)
{
f0103d89:	55                   	push   %ebp
f0103d8a:	89 e5                	mov    %esp,%ebp
f0103d8c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103d8f:	b8 88 46 10 f0       	mov    $0xf0104688,%eax
f0103d94:	66 a3 60 62 22 f0    	mov    %ax,0xf0226260
f0103d9a:	66 c7 05 62 62 22 f0 	movw   $0x8,0xf0226262
f0103da1:	08 00 
f0103da3:	c6 05 64 62 22 f0 00 	movb   $0x0,0xf0226264
f0103daa:	c6 05 65 62 22 f0 8f 	movb   $0x8f,0xf0226265
f0103db1:	c1 e8 10             	shr    $0x10,%eax
f0103db4:	66 a3 66 62 22 f0    	mov    %ax,0xf0226266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103dba:	b8 8e 46 10 f0       	mov    $0xf010468e,%eax
f0103dbf:	66 a3 70 62 22 f0    	mov    %ax,0xf0226270
f0103dc5:	66 c7 05 72 62 22 f0 	movw   $0x8,0xf0226272
f0103dcc:	08 00 
f0103dce:	c6 05 74 62 22 f0 00 	movb   $0x0,0xf0226274
f0103dd5:	c6 05 75 62 22 f0 8e 	movb   $0x8e,0xf0226275
f0103ddc:	c1 e8 10             	shr    $0x10,%eax
f0103ddf:	66 a3 76 62 22 f0    	mov    %ax,0xf0226276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103de5:	b8 94 46 10 f0       	mov    $0xf0104694,%eax
f0103dea:	66 a3 78 62 22 f0    	mov    %ax,0xf0226278
f0103df0:	66 c7 05 7a 62 22 f0 	movw   $0x8,0xf022627a
f0103df7:	08 00 
f0103df9:	c6 05 7c 62 22 f0 00 	movb   $0x0,0xf022627c
f0103e00:	c6 05 7d 62 22 f0 ef 	movb   $0xef,0xf022627d
f0103e07:	c1 e8 10             	shr    $0x10,%eax
f0103e0a:	66 a3 7e 62 22 f0    	mov    %ax,0xf022627e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103e10:	b8 9a 46 10 f0       	mov    $0xf010469a,%eax
f0103e15:	66 a3 80 62 22 f0    	mov    %ax,0xf0226280
f0103e1b:	66 c7 05 82 62 22 f0 	movw   $0x8,0xf0226282
f0103e22:	08 00 
f0103e24:	c6 05 84 62 22 f0 00 	movb   $0x0,0xf0226284
f0103e2b:	c6 05 85 62 22 f0 ef 	movb   $0xef,0xf0226285
f0103e32:	c1 e8 10             	shr    $0x10,%eax
f0103e35:	66 a3 86 62 22 f0    	mov    %ax,0xf0226286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103e3b:	b8 a0 46 10 f0       	mov    $0xf01046a0,%eax
f0103e40:	66 a3 88 62 22 f0    	mov    %ax,0xf0226288
f0103e46:	66 c7 05 8a 62 22 f0 	movw   $0x8,0xf022628a
f0103e4d:	08 00 
f0103e4f:	c6 05 8c 62 22 f0 00 	movb   $0x0,0xf022628c
f0103e56:	c6 05 8d 62 22 f0 ef 	movb   $0xef,0xf022628d
f0103e5d:	c1 e8 10             	shr    $0x10,%eax
f0103e60:	66 a3 8e 62 22 f0    	mov    %ax,0xf022628e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0103e66:	b8 a6 46 10 f0       	mov    $0xf01046a6,%eax
f0103e6b:	66 a3 90 62 22 f0    	mov    %ax,0xf0226290
f0103e71:	66 c7 05 92 62 22 f0 	movw   $0x8,0xf0226292
f0103e78:	08 00 
f0103e7a:	c6 05 94 62 22 f0 00 	movb   $0x0,0xf0226294
f0103e81:	c6 05 95 62 22 f0 8f 	movb   $0x8f,0xf0226295
f0103e88:	c1 e8 10             	shr    $0x10,%eax
f0103e8b:	66 a3 96 62 22 f0    	mov    %ax,0xf0226296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0103e91:	b8 ac 46 10 f0       	mov    $0xf01046ac,%eax
f0103e96:	66 a3 98 62 22 f0    	mov    %ax,0xf0226298
f0103e9c:	66 c7 05 9a 62 22 f0 	movw   $0x8,0xf022629a
f0103ea3:	08 00 
f0103ea5:	c6 05 9c 62 22 f0 00 	movb   $0x0,0xf022629c
f0103eac:	c6 05 9d 62 22 f0 8f 	movb   $0x8f,0xf022629d
f0103eb3:	c1 e8 10             	shr    $0x10,%eax
f0103eb6:	66 a3 9e 62 22 f0    	mov    %ax,0xf022629e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f0103ebc:	b8 b2 46 10 f0       	mov    $0xf01046b2,%eax
f0103ec1:	66 a3 a0 62 22 f0    	mov    %ax,0xf02262a0
f0103ec7:	66 c7 05 a2 62 22 f0 	movw   $0x8,0xf02262a2
f0103ece:	08 00 
f0103ed0:	c6 05 a4 62 22 f0 00 	movb   $0x0,0xf02262a4
f0103ed7:	c6 05 a5 62 22 f0 8f 	movb   $0x8f,0xf02262a5
f0103ede:	c1 e8 10             	shr    $0x10,%eax
f0103ee1:	66 a3 a6 62 22 f0    	mov    %ax,0xf02262a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0103ee7:	b8 b6 46 10 f0       	mov    $0xf01046b6,%eax
f0103eec:	66 a3 b0 62 22 f0    	mov    %ax,0xf02262b0
f0103ef2:	66 c7 05 b2 62 22 f0 	movw   $0x8,0xf02262b2
f0103ef9:	08 00 
f0103efb:	c6 05 b4 62 22 f0 00 	movb   $0x0,0xf02262b4
f0103f02:	c6 05 b5 62 22 f0 8f 	movb   $0x8f,0xf02262b5
f0103f09:	c1 e8 10             	shr    $0x10,%eax
f0103f0c:	66 a3 b6 62 22 f0    	mov    %ax,0xf02262b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0103f12:	b8 ba 46 10 f0       	mov    $0xf01046ba,%eax
f0103f17:	66 a3 b8 62 22 f0    	mov    %ax,0xf02262b8
f0103f1d:	66 c7 05 ba 62 22 f0 	movw   $0x8,0xf02262ba
f0103f24:	08 00 
f0103f26:	c6 05 bc 62 22 f0 00 	movb   $0x0,0xf02262bc
f0103f2d:	c6 05 bd 62 22 f0 8f 	movb   $0x8f,0xf02262bd
f0103f34:	c1 e8 10             	shr    $0x10,%eax
f0103f37:	66 a3 be 62 22 f0    	mov    %ax,0xf02262be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f0103f3d:	b8 be 46 10 f0       	mov    $0xf01046be,%eax
f0103f42:	66 a3 c0 62 22 f0    	mov    %ax,0xf02262c0
f0103f48:	66 c7 05 c2 62 22 f0 	movw   $0x8,0xf02262c2
f0103f4f:	08 00 
f0103f51:	c6 05 c4 62 22 f0 00 	movb   $0x0,0xf02262c4
f0103f58:	c6 05 c5 62 22 f0 8f 	movb   $0x8f,0xf02262c5
f0103f5f:	c1 e8 10             	shr    $0x10,%eax
f0103f62:	66 a3 c6 62 22 f0    	mov    %ax,0xf02262c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f0103f68:	b8 c6 46 10 f0       	mov    $0xf01046c6,%eax
f0103f6d:	66 a3 d0 62 22 f0    	mov    %ax,0xf02262d0
f0103f73:	66 c7 05 d2 62 22 f0 	movw   $0x8,0xf02262d2
f0103f7a:	08 00 
f0103f7c:	c6 05 d4 62 22 f0 00 	movb   $0x0,0xf02262d4
f0103f83:	c6 05 d5 62 22 f0 8f 	movb   $0x8f,0xf02262d5
f0103f8a:	c1 e8 10             	shr    $0x10,%eax
f0103f8d:	66 a3 d6 62 22 f0    	mov    %ax,0xf02262d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0103f93:	b8 c2 46 10 f0       	mov    $0xf01046c2,%eax
f0103f98:	66 a3 c8 62 22 f0    	mov    %ax,0xf02262c8
f0103f9e:	66 c7 05 ca 62 22 f0 	movw   $0x8,0xf02262ca
f0103fa5:	08 00 
f0103fa7:	c6 05 cc 62 22 f0 00 	movb   $0x0,0xf02262cc
f0103fae:	c6 05 cd 62 22 f0 8f 	movb   $0x8f,0xf02262cd
f0103fb5:	c1 e8 10             	shr    $0x10,%eax
f0103fb8:	66 a3 ce 62 22 f0    	mov    %ax,0xf02262ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f0103fbe:	b8 ca 46 10 f0       	mov    $0xf01046ca,%eax
f0103fc3:	66 a3 e0 62 22 f0    	mov    %ax,0xf02262e0
f0103fc9:	66 c7 05 e2 62 22 f0 	movw   $0x8,0xf02262e2
f0103fd0:	08 00 
f0103fd2:	c6 05 e4 62 22 f0 00 	movb   $0x0,0xf02262e4
f0103fd9:	c6 05 e5 62 22 f0 8f 	movb   $0x8f,0xf02262e5
f0103fe0:	c1 e8 10             	shr    $0x10,%eax
f0103fe3:	66 a3 e6 62 22 f0    	mov    %ax,0xf02262e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0103fe9:	b8 d0 46 10 f0       	mov    $0xf01046d0,%eax
f0103fee:	66 a3 e8 62 22 f0    	mov    %ax,0xf02262e8
f0103ff4:	66 c7 05 ea 62 22 f0 	movw   $0x8,0xf02262ea
f0103ffb:	08 00 
f0103ffd:	c6 05 ec 62 22 f0 00 	movb   $0x0,0xf02262ec
f0104004:	c6 05 ed 62 22 f0 8f 	movb   $0x8f,0xf02262ed
f010400b:	c1 e8 10             	shr    $0x10,%eax
f010400e:	66 a3 ee 62 22 f0    	mov    %ax,0xf02262ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0104014:	b8 d4 46 10 f0       	mov    $0xf01046d4,%eax
f0104019:	66 a3 f0 62 22 f0    	mov    %ax,0xf02262f0
f010401f:	66 c7 05 f2 62 22 f0 	movw   $0x8,0xf02262f2
f0104026:	08 00 
f0104028:	c6 05 f4 62 22 f0 00 	movb   $0x0,0xf02262f4
f010402f:	c6 05 f5 62 22 f0 8f 	movb   $0x8f,0xf02262f5
f0104036:	c1 e8 10             	shr    $0x10,%eax
f0104039:	66 a3 f6 62 22 f0    	mov    %ax,0xf02262f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f010403f:	b8 da 46 10 f0       	mov    $0xf01046da,%eax
f0104044:	66 a3 f8 62 22 f0    	mov    %ax,0xf02262f8
f010404a:	66 c7 05 fa 62 22 f0 	movw   $0x8,0xf02262fa
f0104051:	08 00 
f0104053:	c6 05 fc 62 22 f0 00 	movb   $0x0,0xf02262fc
f010405a:	c6 05 fd 62 22 f0 8f 	movb   $0x8f,0xf02262fd
f0104061:	c1 e8 10             	shr    $0x10,%eax
f0104064:	66 a3 fe 62 22 f0    	mov    %ax,0xf02262fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f010406a:	b8 e0 46 10 f0       	mov    $0xf01046e0,%eax
f010406f:	66 a3 e0 63 22 f0    	mov    %ax,0xf02263e0
f0104075:	66 c7 05 e2 63 22 f0 	movw   $0x8,0xf02263e2
f010407c:	08 00 
f010407e:	c6 05 e4 63 22 f0 00 	movb   $0x0,0xf02263e4
f0104085:	c6 05 e5 63 22 f0 ee 	movb   $0xee,0xf02263e5
f010408c:	c1 e8 10             	shr    $0x10,%eax
f010408f:	66 a3 e6 63 22 f0    	mov    %ax,0xf02263e6
	



	// Per-CPU setup 
	trap_init_percpu();
f0104095:	e8 66 fc ff ff       	call   f0103d00 <trap_init_percpu>
}
f010409a:	c9                   	leave  
f010409b:	c3                   	ret    

f010409c <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010409c:	55                   	push   %ebp
f010409d:	89 e5                	mov    %esp,%ebp
f010409f:	53                   	push   %ebx
f01040a0:	83 ec 14             	sub    $0x14,%esp
f01040a3:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01040a6:	8b 03                	mov    (%ebx),%eax
f01040a8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01040ac:	c7 04 24 27 7a 10 f0 	movl   $0xf0107a27,(%esp)
f01040b3:	e8 21 fc ff ff       	call   f0103cd9 <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f01040b8:	8b 43 04             	mov    0x4(%ebx),%eax
f01040bb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01040bf:	c7 04 24 36 7a 10 f0 	movl   $0xf0107a36,(%esp)
f01040c6:	e8 0e fc ff ff       	call   f0103cd9 <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f01040cb:	8b 43 08             	mov    0x8(%ebx),%eax
f01040ce:	89 44 24 04          	mov    %eax,0x4(%esp)
f01040d2:	c7 04 24 45 7a 10 f0 	movl   $0xf0107a45,(%esp)
f01040d9:	e8 fb fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f01040de:	8b 43 0c             	mov    0xc(%ebx),%eax
f01040e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01040e5:	c7 04 24 54 7a 10 f0 	movl   $0xf0107a54,(%esp)
f01040ec:	e8 e8 fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f01040f1:	8b 43 10             	mov    0x10(%ebx),%eax
f01040f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01040f8:	c7 04 24 63 7a 10 f0 	movl   $0xf0107a63,(%esp)
f01040ff:	e8 d5 fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104104:	8b 43 14             	mov    0x14(%ebx),%eax
f0104107:	89 44 24 04          	mov    %eax,0x4(%esp)
f010410b:	c7 04 24 72 7a 10 f0 	movl   $0xf0107a72,(%esp)
f0104112:	e8 c2 fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104117:	8b 43 18             	mov    0x18(%ebx),%eax
f010411a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010411e:	c7 04 24 81 7a 10 f0 	movl   $0xf0107a81,(%esp)
f0104125:	e8 af fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010412a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010412d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104131:	c7 04 24 90 7a 10 f0 	movl   $0xf0107a90,(%esp)
f0104138:	e8 9c fb ff ff       	call   f0103cd9 <cprintf>
}
f010413d:	83 c4 14             	add    $0x14,%esp
f0104140:	5b                   	pop    %ebx
f0104141:	5d                   	pop    %ebp
f0104142:	c3                   	ret    

f0104143 <print_trapframe>:
	// Load the IDT
	lidt(&idt_pd);
}
void
print_trapframe(struct Trapframe *tf)
{
f0104143:	55                   	push   %ebp
f0104144:	89 e5                	mov    %esp,%ebp
f0104146:	56                   	push   %esi
f0104147:	53                   	push   %ebx
f0104148:	83 ec 10             	sub    $0x10,%esp
f010414b:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010414e:	e8 80 20 00 00       	call   f01061d3 <cpunum>
f0104153:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104157:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010415b:	c7 04 24 f4 7a 10 f0 	movl   $0xf0107af4,(%esp)
f0104162:	e8 72 fb ff ff       	call   f0103cd9 <cprintf>
	print_regs(&tf->tf_regs);
f0104167:	89 1c 24             	mov    %ebx,(%esp)
f010416a:	e8 2d ff ff ff       	call   f010409c <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f010416f:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0104173:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104177:	c7 04 24 12 7b 10 f0 	movl   $0xf0107b12,(%esp)
f010417e:	e8 56 fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0104183:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0104187:	89 44 24 04          	mov    %eax,0x4(%esp)
f010418b:	c7 04 24 25 7b 10 f0 	movl   $0xf0107b25,(%esp)
f0104192:	e8 42 fb ff ff       	call   f0103cd9 <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104197:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010419a:	83 f8 13             	cmp    $0x13,%eax
f010419d:	77 09                	ja     f01041a8 <print_trapframe+0x65>
		return excnames[trapno];
f010419f:	8b 14 85 e0 7d 10 f0 	mov    -0xfef8220(,%eax,4),%edx
f01041a6:	eb 1f                	jmp    f01041c7 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01041a8:	83 f8 30             	cmp    $0x30,%eax
f01041ab:	74 15                	je     f01041c2 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01041ad:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f01041b0:	83 fa 0f             	cmp    $0xf,%edx
f01041b3:	ba ab 7a 10 f0       	mov    $0xf0107aab,%edx
f01041b8:	b9 be 7a 10 f0       	mov    $0xf0107abe,%ecx
f01041bd:	0f 47 d1             	cmova  %ecx,%edx
f01041c0:	eb 05                	jmp    f01041c7 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f01041c2:	ba 9f 7a 10 f0       	mov    $0xf0107a9f,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01041c7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01041cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041cf:	c7 04 24 38 7b 10 f0 	movl   $0xf0107b38,(%esp)
f01041d6:	e8 fe fa ff ff       	call   f0103cd9 <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f01041db:	3b 1d 60 6a 22 f0    	cmp    0xf0226a60,%ebx
f01041e1:	75 19                	jne    f01041fc <print_trapframe+0xb9>
f01041e3:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01041e7:	75 13                	jne    f01041fc <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f01041e9:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f01041ec:	89 44 24 04          	mov    %eax,0x4(%esp)
f01041f0:	c7 04 24 4a 7b 10 f0 	movl   $0xf0107b4a,(%esp)
f01041f7:	e8 dd fa ff ff       	call   f0103cd9 <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f01041fc:	8b 43 2c             	mov    0x2c(%ebx),%eax
f01041ff:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104203:	c7 04 24 59 7b 10 f0 	movl   $0xf0107b59,(%esp)
f010420a:	e8 ca fa ff ff       	call   f0103cd9 <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010420f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104213:	75 51                	jne    f0104266 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104215:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104218:	89 c2                	mov    %eax,%edx
f010421a:	83 e2 01             	and    $0x1,%edx
f010421d:	ba cd 7a 10 f0       	mov    $0xf0107acd,%edx
f0104222:	b9 d8 7a 10 f0       	mov    $0xf0107ad8,%ecx
f0104227:	0f 45 ca             	cmovne %edx,%ecx
f010422a:	89 c2                	mov    %eax,%edx
f010422c:	83 e2 02             	and    $0x2,%edx
f010422f:	ba e4 7a 10 f0       	mov    $0xf0107ae4,%edx
f0104234:	be ea 7a 10 f0       	mov    $0xf0107aea,%esi
f0104239:	0f 44 d6             	cmove  %esi,%edx
f010423c:	83 e0 04             	and    $0x4,%eax
f010423f:	b8 ef 7a 10 f0       	mov    $0xf0107aef,%eax
f0104244:	be 24 7c 10 f0       	mov    $0xf0107c24,%esi
f0104249:	0f 44 c6             	cmove  %esi,%eax
f010424c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104250:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104254:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104258:	c7 04 24 67 7b 10 f0 	movl   $0xf0107b67,(%esp)
f010425f:	e8 75 fa ff ff       	call   f0103cd9 <cprintf>
f0104264:	eb 0c                	jmp    f0104272 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f0104266:	c7 04 24 67 71 10 f0 	movl   $0xf0107167,(%esp)
f010426d:	e8 67 fa ff ff       	call   f0103cd9 <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0104272:	8b 43 30             	mov    0x30(%ebx),%eax
f0104275:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104279:	c7 04 24 76 7b 10 f0 	movl   $0xf0107b76,(%esp)
f0104280:	e8 54 fa ff ff       	call   f0103cd9 <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0104285:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104289:	89 44 24 04          	mov    %eax,0x4(%esp)
f010428d:	c7 04 24 85 7b 10 f0 	movl   $0xf0107b85,(%esp)
f0104294:	e8 40 fa ff ff       	call   f0103cd9 <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f0104299:	8b 43 38             	mov    0x38(%ebx),%eax
f010429c:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042a0:	c7 04 24 98 7b 10 f0 	movl   $0xf0107b98,(%esp)
f01042a7:	e8 2d fa ff ff       	call   f0103cd9 <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01042ac:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01042b0:	74 27                	je     f01042d9 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01042b2:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01042b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042b9:	c7 04 24 a7 7b 10 f0 	movl   $0xf0107ba7,(%esp)
f01042c0:	e8 14 fa ff ff       	call   f0103cd9 <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f01042c5:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f01042c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042cd:	c7 04 24 b6 7b 10 f0 	movl   $0xf0107bb6,(%esp)
f01042d4:	e8 00 fa ff ff       	call   f0103cd9 <cprintf>
	}
}
f01042d9:	83 c4 10             	add    $0x10,%esp
f01042dc:	5b                   	pop    %ebx
f01042dd:	5e                   	pop    %esi
f01042de:	5d                   	pop    %ebp
f01042df:	c3                   	ret    

f01042e0 <break_point_handler>:
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}
void
break_point_handler(struct Trapframe *tf)
{
f01042e0:	55                   	push   %ebp
f01042e1:	89 e5                	mov    %esp,%ebp
f01042e3:	83 ec 18             	sub    $0x18,%esp
	monitor(tf);
f01042e6:	8b 45 08             	mov    0x8(%ebp),%eax
f01042e9:	89 04 24             	mov    %eax,(%esp)
f01042ec:	e8 a6 c6 ff ff       	call   f0100997 <monitor>
}
f01042f1:	c9                   	leave  
f01042f2:	c3                   	ret    

f01042f3 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f01042f3:	55                   	push   %ebp
f01042f4:	89 e5                	mov    %esp,%ebp
f01042f6:	57                   	push   %edi
f01042f7:	56                   	push   %esi
f01042f8:	53                   	push   %ebx
f01042f9:	83 ec 2c             	sub    $0x2c,%esp
f01042fc:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01042ff:	0f 20 d0             	mov    %cr2,%eax
f0104302:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 0x3) != 3)
f0104305:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104309:	83 e0 03             	and    $0x3,%eax
f010430c:	66 83 f8 03          	cmp    $0x3,%ax
f0104310:	74 1c                	je     f010432e <page_fault_handler+0x3b>
		panic("page_fault_handler(): page fault at kernel-mode !");
f0104312:	c7 44 24 08 70 7d 10 	movl   $0xf0107d70,0x8(%esp)
f0104319:	f0 
f010431a:	c7 44 24 04 64 01 00 	movl   $0x164,0x4(%esp)
f0104321:	00 
f0104322:	c7 04 24 c9 7b 10 f0 	movl   $0xf0107bc9,(%esp)
f0104329:	e8 12 bd ff ff       	call   f0100040 <_panic>
	//   To change what the user environment runs, modify 'curenv->env_tf'
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	
	if(curenv->env_pgfault_upcall == NULL) goto DESTROY;
f010432e:	e8 a0 1e 00 00       	call   f01061d3 <cpunum>
f0104333:	6b c0 74             	imul   $0x74,%eax,%eax
f0104336:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f010433c:	83 78 64 00          	cmpl   $0x0,0x64(%eax)
f0104340:	0f 84 fa 00 00 00    	je     f0104440 <page_fault_handler+0x14d>
	// 1. call the environment's page fault upcall, if one exits
	// 1.1 Set up a page fault stack frame

	struct UTrapframe* utf;
	if(UXSTACKTOP - PGSIZE <= tf->tf_esp && tf->tf_esp < UXSTACKTOP) // an page_fault from user exception stack
f0104346:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104349:	8d 90 00 10 40 11    	lea    0x11401000(%eax),%edx
	{
		utf = (struct UTrapframe*) (tf->tf_esp - sizeof (struct UTrapframe) - sizeof(uint32_t));
f010434f:	83 e8 38             	sub    $0x38,%eax
f0104352:	81 fa ff 0f 00 00    	cmp    $0xfff,%edx
f0104358:	ba cc ff bf ee       	mov    $0xeebfffcc,%edx
f010435d:	0f 46 d0             	cmovbe %eax,%edx
f0104360:	89 d7                	mov    %edx,%edi
f0104362:	89 55 e0             	mov    %edx,-0x20(%ebp)

	}

	// assume user has right to access uxstk
	//cprintf("Before\n");
	user_mem_assert(curenv, (void*) utf, sizeof (struct UTrapframe), PTE_U | PTE_W);
f0104365:	e8 69 1e 00 00       	call   f01061d3 <cpunum>
f010436a:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0104371:	00 
f0104372:	c7 44 24 08 34 00 00 	movl   $0x34,0x8(%esp)
f0104379:	00 
f010437a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010437e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104381:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104387:	89 04 24             	mov    %eax,(%esp)
f010438a:	e8 39 ef ff ff       	call   f01032c8 <user_mem_assert>
	//cprintf("Passed\n");



	// setup a stack
	utf->utf_eflags = tf->tf_eflags;
f010438f:	8b 43 38             	mov    0x38(%ebx),%eax
f0104392:	89 47 2c             	mov    %eax,0x2c(%edi)
	utf->utf_eip = tf->tf_eip;
f0104395:	8b 43 30             	mov    0x30(%ebx),%eax
f0104398:	89 47 28             	mov    %eax,0x28(%edi)
	utf->utf_esp = tf->tf_esp;
f010439b:	8b 43 3c             	mov    0x3c(%ebx),%eax
f010439e:	89 47 30             	mov    %eax,0x30(%edi)
	utf->utf_regs = tf->tf_regs;
f01043a1:	8d 7f 08             	lea    0x8(%edi),%edi
f01043a4:	89 de                	mov    %ebx,%esi
f01043a6:	b8 20 00 00 00       	mov    $0x20,%eax
f01043ab:	f7 c7 01 00 00 00    	test   $0x1,%edi
f01043b1:	74 03                	je     f01043b6 <page_fault_handler+0xc3>
f01043b3:	a4                   	movsb  %ds:(%esi),%es:(%edi)
f01043b4:	b0 1f                	mov    $0x1f,%al
f01043b6:	f7 c7 02 00 00 00    	test   $0x2,%edi
f01043bc:	74 05                	je     f01043c3 <page_fault_handler+0xd0>
f01043be:	66 a5                	movsw  %ds:(%esi),%es:(%edi)
f01043c0:	83 e8 02             	sub    $0x2,%eax
f01043c3:	89 c1                	mov    %eax,%ecx
f01043c5:	c1 e9 02             	shr    $0x2,%ecx
f01043c8:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01043ca:	ba 00 00 00 00       	mov    $0x0,%edx
f01043cf:	a8 02                	test   $0x2,%al
f01043d1:	74 0b                	je     f01043de <page_fault_handler+0xeb>
f01043d3:	0f b7 16             	movzwl (%esi),%edx
f01043d6:	66 89 17             	mov    %dx,(%edi)
f01043d9:	ba 02 00 00 00       	mov    $0x2,%edx
f01043de:	a8 01                	test   $0x1,%al
f01043e0:	74 07                	je     f01043e9 <page_fault_handler+0xf6>
f01043e2:	0f b6 04 16          	movzbl (%esi,%edx,1),%eax
f01043e6:	88 04 17             	mov    %al,(%edi,%edx,1)
	utf->utf_err = tf->tf_err;
f01043e9:	8b 43 2c             	mov    0x2c(%ebx),%eax
f01043ec:	8b 7d e0             	mov    -0x20(%ebp),%edi
f01043ef:	89 47 04             	mov    %eax,0x4(%edi)
	utf->utf_fault_va = fault_va;
f01043f2:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01043f5:	89 07                	mov    %eax,(%edi)

	curenv->env_tf.tf_eip = (uint32_t)curenv->env_pgfault_upcall;
f01043f7:	e8 d7 1d 00 00       	call   f01061d3 <cpunum>
f01043fc:	6b c0 74             	imul   $0x74,%eax,%eax
f01043ff:	8b 98 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%ebx
f0104405:	e8 c9 1d 00 00       	call   f01061d3 <cpunum>
f010440a:	6b c0 74             	imul   $0x74,%eax,%eax
f010440d:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104413:	8b 40 64             	mov    0x64(%eax),%eax
f0104416:	89 43 30             	mov    %eax,0x30(%ebx)
	curenv->env_tf.tf_esp = (uint32_t)utf;
f0104419:	e8 b5 1d 00 00       	call   f01061d3 <cpunum>
f010441e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104421:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104427:	89 78 3c             	mov    %edi,0x3c(%eax)

	env_run(curenv);
f010442a:	e8 a4 1d 00 00       	call   f01061d3 <cpunum>
f010442f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104432:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104438:	89 04 24             	mov    %eax,(%esp)
f010443b:	e8 88 f6 ff ff       	call   f0103ac8 <env_run>


	DESTROY:
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104440:	8b 73 30             	mov    0x30(%ebx),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104443:	e8 8b 1d 00 00       	call   f01061d3 <cpunum>

	env_run(curenv);


	DESTROY:
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104448:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010444c:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f010444f:	89 4c 24 08          	mov    %ecx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104453:	6b c0 74             	imul   $0x74,%eax,%eax

	env_run(curenv);


	DESTROY:
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104456:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f010445c:	8b 40 48             	mov    0x48(%eax),%eax
f010445f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104463:	c7 04 24 a4 7d 10 f0 	movl   $0xf0107da4,(%esp)
f010446a:	e8 6a f8 ff ff       	call   f0103cd9 <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
f010446f:	89 1c 24             	mov    %ebx,(%esp)
f0104472:	e8 cc fc ff ff       	call   f0104143 <print_trapframe>
	env_destroy(curenv);
f0104477:	e8 57 1d 00 00       	call   f01061d3 <cpunum>
f010447c:	6b c0 74             	imul   $0x74,%eax,%eax
f010447f:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104485:	89 04 24             	mov    %eax,(%esp)
f0104488:	e8 9a f5 ff ff       	call   f0103a27 <env_destroy>
}
f010448d:	83 c4 2c             	add    $0x2c,%esp
f0104490:	5b                   	pop    %ebx
f0104491:	5e                   	pop    %esi
f0104492:	5f                   	pop    %edi
f0104493:	5d                   	pop    %ebp
f0104494:	c3                   	ret    

f0104495 <trap>:



void
trap(struct Trapframe *tf)
{
f0104495:	55                   	push   %ebp
f0104496:	89 e5                	mov    %esp,%ebp
f0104498:	57                   	push   %edi
f0104499:	56                   	push   %esi
f010449a:	83 ec 20             	sub    $0x20,%esp
f010449d:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01044a0:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01044a1:	83 3d 80 6e 22 f0 00 	cmpl   $0x0,0xf0226e80
f01044a8:	74 01                	je     f01044ab <trap+0x16>
		asm volatile("hlt");
f01044aa:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f01044ab:	9c                   	pushf  
f01044ac:	58                   	pop    %eax
	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	//cprintf("%p\n",read_eflags());
	//cprintf("%p\n",FL_IF);
	assert(!(read_eflags() & FL_IF));
f01044ad:	f6 c4 02             	test   $0x2,%ah
f01044b0:	74 24                	je     f01044d6 <trap+0x41>
f01044b2:	c7 44 24 0c d5 7b 10 	movl   $0xf0107bd5,0xc(%esp)
f01044b9:	f0 
f01044ba:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f01044c1:	f0 
f01044c2:	c7 44 24 04 2c 01 00 	movl   $0x12c,0x4(%esp)
f01044c9:	00 
f01044ca:	c7 04 24 c9 7b 10 f0 	movl   $0xf0107bc9,(%esp)
f01044d1:	e8 6a bb ff ff       	call   f0100040 <_panic>
   // panic("trap called!");
//	cprintf("Incoming TRAP frame at %p\n", tf);
//=======
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	if ((tf->tf_cs & 3) == 3) {
f01044d6:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01044da:	83 e0 03             	and    $0x3,%eax
f01044dd:	66 83 f8 03          	cmp    $0x3,%ax
f01044e1:	0f 85 a7 00 00 00    	jne    f010458e <trap+0xf9>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01044e7:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f01044ee:	e8 46 1f 00 00       	call   f0106439 <spin_lock>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		lock_kernel();
		assert(curenv);
f01044f3:	e8 db 1c 00 00       	call   f01061d3 <cpunum>
f01044f8:	6b c0 74             	imul   $0x74,%eax,%eax
f01044fb:	83 b8 28 70 22 f0 00 	cmpl   $0x0,-0xfdd8fd8(%eax)
f0104502:	75 24                	jne    f0104528 <trap+0x93>
f0104504:	c7 44 24 0c ee 7b 10 	movl   $0xf0107bee,0xc(%esp)
f010450b:	f0 
f010450c:	c7 44 24 08 9c 6e 10 	movl   $0xf0106e9c,0x8(%esp)
f0104513:	f0 
f0104514:	c7 44 24 04 3a 01 00 	movl   $0x13a,0x4(%esp)
f010451b:	00 
f010451c:	c7 04 24 c9 7b 10 f0 	movl   $0xf0107bc9,(%esp)
f0104523:	e8 18 bb ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0104528:	e8 a6 1c 00 00       	call   f01061d3 <cpunum>
f010452d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104530:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104536:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f010453a:	75 2d                	jne    f0104569 <trap+0xd4>
			env_free(curenv);
f010453c:	e8 92 1c 00 00       	call   f01061d3 <cpunum>
f0104541:	6b c0 74             	imul   $0x74,%eax,%eax
f0104544:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f010454a:	89 04 24             	mov    %eax,(%esp)
f010454d:	e8 d0 f2 ff ff       	call   f0103822 <env_free>
			curenv = NULL;
f0104552:	e8 7c 1c 00 00       	call   f01061d3 <cpunum>
f0104557:	6b c0 74             	imul   $0x74,%eax,%eax
f010455a:	c7 80 28 70 22 f0 00 	movl   $0x0,-0xfdd8fd8(%eax)
f0104561:	00 00 00 
			sched_yield();
f0104564:	e8 97 01 00 00       	call   f0104700 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f0104569:	e8 65 1c 00 00       	call   f01061d3 <cpunum>
f010456e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104571:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104577:	b9 11 00 00 00       	mov    $0x11,%ecx
f010457c:	89 c7                	mov    %eax,%edi
f010457e:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104580:	e8 4e 1c 00 00       	call   f01061d3 <cpunum>
f0104585:	6b c0 74             	imul   $0x74,%eax,%eax
f0104588:	8b b0 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f010458e:	89 35 60 6a 22 f0    	mov    %esi,0xf0226a60
{
	// Handle processor exceptions.
	//print_trapframe(tf);
	// LAB 3: Your code here.
//<<<<<<< HEAD
	if(tf->tf_trapno==T_PGFLT)
f0104594:	8b 46 28             	mov    0x28(%esi),%eax
f0104597:	83 f8 0e             	cmp    $0xe,%eax
f010459a:	75 0d                	jne    f01045a9 <trap+0x114>
	{
		page_fault_handler(tf);
f010459c:	89 34 24             	mov    %esi,(%esp)
f010459f:	e8 4f fd ff ff       	call   f01042f3 <page_fault_handler>
f01045a4:	e9 9f 00 00 00       	jmp    f0104648 <trap+0x1b3>
		return;
	}
	if(tf->tf_trapno==T_BRKPT)
f01045a9:	83 f8 03             	cmp    $0x3,%eax
f01045ac:	75 0d                	jne    f01045bb <trap+0x126>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}
void
break_point_handler(struct Trapframe *tf)
{
	monitor(tf);
f01045ae:	89 34 24             	mov    %esi,(%esp)
f01045b1:	e8 e1 c3 ff ff       	call   f0100997 <monitor>
f01045b6:	e9 8d 00 00 00       	jmp    f0104648 <trap+0x1b3>
	if(tf->tf_trapno==T_BRKPT)
	{
		break_point_handler(tf);
		return;
	}
	if(tf->tf_trapno==T_SYSCALL)
f01045bb:	83 f8 30             	cmp    $0x30,%eax
f01045be:	66 90                	xchg   %ax,%ax
f01045c0:	75 32                	jne    f01045f4 <trap+0x15f>
	{
		tf->tf_regs.reg_eax=syscall(tf->tf_regs.reg_eax,tf->tf_regs.reg_edx,tf->tf_regs.reg_ecx,tf->tf_regs.reg_ebx,tf->tf_regs.reg_edi,tf->tf_regs.reg_esi);
f01045c2:	8b 46 04             	mov    0x4(%esi),%eax
f01045c5:	89 44 24 14          	mov    %eax,0x14(%esp)
f01045c9:	8b 06                	mov    (%esi),%eax
f01045cb:	89 44 24 10          	mov    %eax,0x10(%esp)
f01045cf:	8b 46 10             	mov    0x10(%esi),%eax
f01045d2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01045d6:	8b 46 18             	mov    0x18(%esi),%eax
f01045d9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01045dd:	8b 46 14             	mov    0x14(%esi),%eax
f01045e0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045e4:	8b 46 1c             	mov    0x1c(%esi),%eax
f01045e7:	89 04 24             	mov    %eax,(%esp)
f01045ea:	e8 31 02 00 00       	call   f0104820 <syscall>
f01045ef:	89 46 1c             	mov    %eax,0x1c(%esi)
f01045f2:	eb 54                	jmp    f0104648 <trap+0x1b3>
//=======

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f01045f4:	83 f8 27             	cmp    $0x27,%eax
f01045f7:	75 16                	jne    f010460f <trap+0x17a>
		cprintf("Spurious interrupt on irq 7\n");
f01045f9:	c7 04 24 f5 7b 10 f0 	movl   $0xf0107bf5,(%esp)
f0104600:	e8 d4 f6 ff ff       	call   f0103cd9 <cprintf>
		print_trapframe(tf);
f0104605:	89 34 24             	mov    %esi,(%esp)
f0104608:	e8 36 fb ff ff       	call   f0104143 <print_trapframe>
f010460d:	eb 39                	jmp    f0104648 <trap+0x1b3>
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f010460f:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104614:	75 1c                	jne    f0104632 <trap+0x19d>
		panic("unhandled trap in kernel");
f0104616:	c7 44 24 08 12 7c 10 	movl   $0xf0107c12,0x8(%esp)
f010461d:	f0 
f010461e:	c7 44 24 04 12 01 00 	movl   $0x112,0x4(%esp)
f0104625:	00 
f0104626:	c7 04 24 c9 7b 10 f0 	movl   $0xf0107bc9,(%esp)
f010462d:	e8 0e ba ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104632:	e8 9c 1b 00 00       	call   f01061d3 <cpunum>
f0104637:	6b c0 74             	imul   $0x74,%eax,%eax
f010463a:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104640:	89 04 24             	mov    %eax,(%esp)
f0104643:	e8 df f3 ff ff       	call   f0103a27 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f0104648:	e8 86 1b 00 00       	call   f01061d3 <cpunum>
f010464d:	6b c0 74             	imul   $0x74,%eax,%eax
f0104650:	83 b8 28 70 22 f0 00 	cmpl   $0x0,-0xfdd8fd8(%eax)
f0104657:	74 2a                	je     f0104683 <trap+0x1ee>
f0104659:	e8 75 1b 00 00       	call   f01061d3 <cpunum>
f010465e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104661:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104667:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f010466b:	75 16                	jne    f0104683 <trap+0x1ee>
		env_run(curenv);
f010466d:	e8 61 1b 00 00       	call   f01061d3 <cpunum>
f0104672:	6b c0 74             	imul   $0x74,%eax,%eax
f0104675:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f010467b:	89 04 24             	mov    %eax,(%esp)
f010467e:	e8 45 f4 ff ff       	call   f0103ac8 <env_run>
	else
		sched_yield();
f0104683:	e8 78 00 00 00       	call   f0104700 <sched_yield>

f0104688 <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f0104688:	6a 00                	push   $0x0
f010468a:	6a 00                	push   $0x0
f010468c:	eb 58                	jmp    f01046e6 <_alltraps>

f010468e <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f010468e:	6a 00                	push   $0x0
f0104690:	6a 02                	push   $0x2
f0104692:	eb 52                	jmp    f01046e6 <_alltraps>

f0104694 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f0104694:	6a 00                	push   $0x0
f0104696:	6a 03                	push   $0x3
f0104698:	eb 4c                	jmp    f01046e6 <_alltraps>

f010469a <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f010469a:	6a 00                	push   $0x0
f010469c:	6a 04                	push   $0x4
f010469e:	eb 46                	jmp    f01046e6 <_alltraps>

f01046a0 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01046a0:	6a 00                	push   $0x0
f01046a2:	6a 05                	push   $0x5
f01046a4:	eb 40                	jmp    f01046e6 <_alltraps>

f01046a6 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01046a6:	6a 00                	push   $0x0
f01046a8:	6a 06                	push   $0x6
f01046aa:	eb 3a                	jmp    f01046e6 <_alltraps>

f01046ac <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01046ac:	6a 00                	push   $0x0
f01046ae:	6a 07                	push   $0x7
f01046b0:	eb 34                	jmp    f01046e6 <_alltraps>

f01046b2 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01046b2:	6a 08                	push   $0x8
f01046b4:	eb 30                	jmp    f01046e6 <_alltraps>

f01046b6 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01046b6:	6a 0a                	push   $0xa
f01046b8:	eb 2c                	jmp    f01046e6 <_alltraps>

f01046ba <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01046ba:	6a 0b                	push   $0xb
f01046bc:	eb 28                	jmp    f01046e6 <_alltraps>

f01046be <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f01046be:	6a 0c                	push   $0xc
f01046c0:	eb 24                	jmp    f01046e6 <_alltraps>

f01046c2 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01046c2:	6a 0d                	push   $0xd
f01046c4:	eb 20                	jmp    f01046e6 <_alltraps>

f01046c6 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01046c6:	6a 0e                	push   $0xe
f01046c8:	eb 1c                	jmp    f01046e6 <_alltraps>

f01046ca <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01046ca:	6a 00                	push   $0x0
f01046cc:	6a 10                	push   $0x10
f01046ce:	eb 16                	jmp    f01046e6 <_alltraps>

f01046d0 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f01046d0:	6a 11                	push   $0x11
f01046d2:	eb 12                	jmp    f01046e6 <_alltraps>

f01046d4 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f01046d4:	6a 00                	push   $0x0
f01046d6:	6a 12                	push   $0x12
f01046d8:	eb 0c                	jmp    f01046e6 <_alltraps>

f01046da <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f01046da:	6a 00                	push   $0x0
f01046dc:	6a 13                	push   $0x13
f01046de:	eb 06                	jmp    f01046e6 <_alltraps>

f01046e0 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f01046e0:	6a 00                	push   $0x0
f01046e2:	6a 30                	push   $0x30
f01046e4:	eb 00                	jmp    f01046e6 <_alltraps>

f01046e6 <_alltraps>:

/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
pushw $0
f01046e6:	66 6a 00             	pushw  $0x0
pushw %ds
f01046e9:	66 1e                	pushw  %ds
pushw $0
f01046eb:	66 6a 00             	pushw  $0x0
pushw %es
f01046ee:	66 06                	pushw  %es
pushal
f01046f0:	60                   	pusha  
pushl %esp
f01046f1:	54                   	push   %esp
movw $(GD_KD),%ax
f01046f2:	66 b8 10 00          	mov    $0x10,%ax
movw %ax,%ds
f01046f6:	8e d8                	mov    %eax,%ds
movw %ax,%es
f01046f8:	8e c0                	mov    %eax,%es
call trap
f01046fa:	e8 96 fd ff ff       	call   f0104495 <trap>
f01046ff:	90                   	nop

f0104700 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104700:	55                   	push   %ebp
f0104701:	89 e5                	mov    %esp,%ebp
f0104703:	57                   	push   %edi
f0104704:	56                   	push   %esi
f0104705:	53                   	push   %ebx
f0104706:	83 ec 1c             	sub    $0x1c,%esp
	// idle environment (env_type == ENV_TYPE_IDLE).  If there are
	// no runnable environments, simply drop through to the code
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
   struct Env *curr = thiscpu->cpu_env;
f0104709:	e8 c5 1a 00 00       	call   f01061d3 <cpunum>
f010470e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104711:	8b b0 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%esi
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
f0104717:	85 f6                	test   %esi,%esi
f0104719:	0f 84 df 00 00 00    	je     f01047fe <sched_yield+0xfe>
f010471f:	8b 7e 48             	mov    0x48(%esi),%edi
f0104722:	81 e7 ff 03 00 00    	and    $0x3ff,%edi
f0104728:	e9 d6 00 00 00       	jmp    f0104803 <sched_yield+0x103>
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
f010472d:	8d 47 01             	lea    0x1(%edi),%eax
f0104730:	99                   	cltd   
f0104731:	c1 ea 16             	shr    $0x16,%edx
f0104734:	01 d0                	add    %edx,%eax
f0104736:	25 ff 03 00 00       	and    $0x3ff,%eax
f010473b:	29 d0                	sub    %edx,%eax
f010473d:	89 c7                	mov    %eax,%edi
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f010473f:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104742:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0104745:	83 7a 50 01          	cmpl   $0x1,0x50(%edx)
f0104749:	74 0e                	je     f0104759 <sched_yield+0x59>
            continue;
        
        if (envs[idx].env_status == ENV_RUNNABLE)
f010474b:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f010474f:	75 08                	jne    f0104759 <sched_yield+0x59>
            env_run(&envs[idx]);
f0104751:	89 14 24             	mov    %edx,(%esp)
f0104754:	e8 6f f3 ff ff       	call   f0103ac8 <env_run>
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
   struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
	for (i = 1; i < NENV; i++) {
f0104759:	83 e9 01             	sub    $0x1,%ecx
f010475c:	75 cf                	jne    f010472d <sched_yield+0x2d>
        
        if (envs[idx].env_status == ENV_RUNNABLE)
            env_run(&envs[idx]);
	}

    if (curr && curr->env_status == ENV_RUNNING) {
f010475e:	85 f6                	test   %esi,%esi
f0104760:	74 06                	je     f0104768 <sched_yield+0x68>
f0104762:	83 7e 54 03          	cmpl   $0x3,0x54(%esi)
f0104766:	74 09                	je     f0104771 <sched_yield+0x71>
f0104768:	89 d8                	mov    %ebx,%eax
   struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f010476a:	ba 00 00 00 00       	mov    $0x0,%edx
f010476f:	eb 08                	jmp    f0104779 <sched_yield+0x79>
            env_run(&envs[idx]);
	}

    if (curr && curr->env_status == ENV_RUNNING) {
        // If not found and current environment is running, then continue running.
        env_run(curr);
f0104771:	89 34 24             	mov    %esi,(%esp)
f0104774:	e8 4f f3 ff ff       	call   f0103ac8 <env_run>

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104779:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f010477d:	74 0b                	je     f010478a <sched_yield+0x8a>
		    (envs[i].env_status == ENV_RUNNABLE ||
f010477f:	8b 70 54             	mov    0x54(%eax),%esi
f0104782:	8d 4e fe             	lea    -0x2(%esi),%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104785:	83 f9 01             	cmp    $0x1,%ecx
f0104788:	76 10                	jbe    f010479a <sched_yield+0x9a>
    }

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f010478a:	83 c2 01             	add    $0x1,%edx
f010478d:	83 c0 7c             	add    $0x7c,%eax
f0104790:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104796:	75 e1                	jne    f0104779 <sched_yield+0x79>
f0104798:	eb 08                	jmp    f01047a2 <sched_yield+0xa2>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f010479a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f01047a0:	75 1a                	jne    f01047bc <sched_yield+0xbc>
		cprintf("No more runnable environments!\n");
f01047a2:	c7 04 24 30 7e 10 f0 	movl   $0xf0107e30,(%esp)
f01047a9:	e8 2b f5 ff ff       	call   f0103cd9 <cprintf>
		while (1)
			monitor(NULL);
f01047ae:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01047b5:	e8 dd c1 ff ff       	call   f0100997 <monitor>
f01047ba:	eb f2                	jmp    f01047ae <sched_yield+0xae>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f01047bc:	e8 12 1a 00 00       	call   f01061d3 <cpunum>
f01047c1:	6b c0 7c             	imul   $0x7c,%eax,%eax
f01047c4:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f01047c6:	8b 43 54             	mov    0x54(%ebx),%eax
f01047c9:	83 e8 02             	sub    $0x2,%eax
f01047cc:	83 f8 01             	cmp    $0x1,%eax
f01047cf:	76 25                	jbe    f01047f6 <sched_yield+0xf6>
		panic("CPU %d: No idle environment!", cpunum());
f01047d1:	e8 fd 19 00 00       	call   f01061d3 <cpunum>
f01047d6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01047da:	c7 44 24 08 50 7e 10 	movl   $0xf0107e50,0x8(%esp)
f01047e1:	f0 
f01047e2:	c7 44 24 04 43 00 00 	movl   $0x43,0x4(%esp)
f01047e9:	00 
f01047ea:	c7 04 24 6d 7e 10 f0 	movl   $0xf0107e6d,(%esp)
f01047f1:	e8 4a b8 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f01047f6:	89 1c 24             	mov    %ebx,(%esp)
f01047f9:	e8 ca f2 ff ff       	call   f0103ac8 <env_run>
	// no runnable environments, simply drop through to the code
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
   struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
f01047fe:	bf 00 00 00 00       	mov    $0x0,%edi
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f0104803:	8b 1d 48 62 22 f0    	mov    0xf0226248,%ebx
f0104809:	b9 ff 03 00 00       	mov    $0x3ff,%ecx
f010480e:	e9 1a ff ff ff       	jmp    f010472d <sched_yield+0x2d>
f0104813:	66 90                	xchg   %ax,%ax
f0104815:	66 90                	xchg   %ax,%ax
f0104817:	66 90                	xchg   %ax,%ax
f0104819:	66 90                	xchg   %ax,%ax
f010481b:	66 90                	xchg   %ax,%ax
f010481d:	66 90                	xchg   %ax,%ax
f010481f:	90                   	nop

f0104820 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104820:	55                   	push   %ebp
f0104821:	89 e5                	mov    %esp,%ebp
f0104823:	57                   	push   %edi
f0104824:	56                   	push   %esi
f0104825:	53                   	push   %ebx
f0104826:	83 ec 2c             	sub    $0x2c,%esp
f0104829:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	//cprintf("The syscallno = %d\n", syscallno);
	switch(syscallno)
f010482c:	83 f8 0c             	cmp    $0xc,%eax
f010482f:	0f 87 9e 05 00 00    	ja     f0104dd3 <syscall+0x5b3>
f0104835:	ff 24 85 dc 7e 10 f0 	jmp    *-0xfef8124(,%eax,4)
			sys_env_destroy(sys_getenvid());
			return;
		}
	}*/
	//cprintf("sys_cputs!\n");
	user_mem_assert(curenv, s, len, PTE_U);
f010483c:	e8 92 19 00 00       	call   f01061d3 <cpunum>
f0104841:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0104848:	00 
f0104849:	8b 7d 10             	mov    0x10(%ebp),%edi
f010484c:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104850:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104853:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104857:	6b c0 74             	imul   $0x74,%eax,%eax
f010485a:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104860:	89 04 24             	mov    %eax,(%esp)
f0104863:	e8 60 ea ff ff       	call   f01032c8 <user_mem_assert>
	//cprintf("user_mem_assert passed!\n");


	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104868:	8b 45 0c             	mov    0xc(%ebp),%eax
f010486b:	89 44 24 08          	mov    %eax,0x8(%esp)
f010486f:	8b 45 10             	mov    0x10(%ebp),%eax
f0104872:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104876:	c7 04 24 7a 7e 10 f0 	movl   $0xf0107e7a,(%esp)
f010487d:	e8 57 f4 ff ff       	call   f0103cd9 <cprintf>
	//cprintf("The syscallno = %d\n", syscallno);
	switch(syscallno)
	{
	case SYS_cputs:
		sys_cputs((char*)a1, a2);
		return 0;
f0104882:	b8 00 00 00 00       	mov    $0x0,%eax
f0104887:	e9 68 05 00 00       	jmp    f0104df4 <syscall+0x5d4>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f010488c:	e8 f4 bd ff ff       	call   f0100685 <cons_getc>
	{
	case SYS_cputs:
		sys_cputs((char*)a1, a2);
		return 0;
	case SYS_cgetc:
		return sys_cgetc();
f0104891:	e9 5e 05 00 00       	jmp    f0104df4 <syscall+0x5d4>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104896:	e8 38 19 00 00       	call   f01061d3 <cpunum>
f010489b:	6b c0 74             	imul   $0x74,%eax,%eax
f010489e:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f01048a4:	8b 40 48             	mov    0x48(%eax),%eax
		sys_cputs((char*)a1, a2);
		return 0;
	case SYS_cgetc:
		return sys_cgetc();
	case SYS_getenvid:
		return sys_getenvid();
f01048a7:	e9 48 05 00 00       	jmp    f0104df4 <syscall+0x5d4>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f01048ac:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01048b3:	00 
f01048b4:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01048b7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048bb:	8b 45 0c             	mov    0xc(%ebp),%eax
f01048be:	89 04 24             	mov    %eax,(%esp)
f01048c1:	e8 d7 ea ff ff       	call   f010339d <envid2env>
		return r;
f01048c6:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f01048c8:	85 c0                	test   %eax,%eax
f01048ca:	78 6e                	js     f010493a <syscall+0x11a>
		return r;
	if (e == curenv)
f01048cc:	e8 02 19 00 00       	call   f01061d3 <cpunum>
f01048d1:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f01048d4:	6b c0 74             	imul   $0x74,%eax,%eax
f01048d7:	39 90 28 70 22 f0    	cmp    %edx,-0xfdd8fd8(%eax)
f01048dd:	75 23                	jne    f0104902 <syscall+0xe2>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f01048df:	e8 ef 18 00 00       	call   f01061d3 <cpunum>
f01048e4:	6b c0 74             	imul   $0x74,%eax,%eax
f01048e7:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f01048ed:	8b 40 48             	mov    0x48(%eax),%eax
f01048f0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01048f4:	c7 04 24 7f 7e 10 f0 	movl   $0xf0107e7f,(%esp)
f01048fb:	e8 d9 f3 ff ff       	call   f0103cd9 <cprintf>
f0104900:	eb 28                	jmp    f010492a <syscall+0x10a>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f0104902:	8b 5a 48             	mov    0x48(%edx),%ebx
f0104905:	e8 c9 18 00 00       	call   f01061d3 <cpunum>
f010490a:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f010490e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104911:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104917:	8b 40 48             	mov    0x48(%eax),%eax
f010491a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010491e:	c7 04 24 9a 7e 10 f0 	movl   $0xf0107e9a,(%esp)
f0104925:	e8 af f3 ff ff       	call   f0103cd9 <cprintf>
	env_destroy(e);
f010492a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010492d:	89 04 24             	mov    %eax,(%esp)
f0104930:	e8 f2 f0 ff ff       	call   f0103a27 <env_destroy>
	return 0;
f0104935:	ba 00 00 00 00       	mov    $0x0,%edx
	case SYS_cgetc:
		return sys_cgetc();
	case SYS_getenvid:
		return sys_getenvid();
	case SYS_env_destroy:
		return sys_env_destroy(a1);
f010493a:	89 d0                	mov    %edx,%eax
f010493c:	e9 b3 04 00 00       	jmp    f0104df4 <syscall+0x5d4>

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0104941:	e8 ba fd ff ff       	call   f0104700 <sched_yield>

	// LAB 4: Your code here.

	// check perm
	//cprintf("I have given ENVID: %08x ph page at %08x!!\n", envid, va);
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104946:	8b 45 14             	mov    0x14(%ebp),%eax
f0104949:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f010494e:	83 f8 05             	cmp    $0x5,%eax
f0104951:	75 70                	jne    f01049c3 <syscall+0x1a3>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
	struct Page* pp = page_alloc(ALLOC_ZERO);
f0104953:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010495a:	e8 8a c7 ff ff       	call   f01010e9 <page_alloc>
f010495f:	89 c3                	mov    %eax,%ebx
	if(pp == NULL) // out of memory
f0104961:	85 c0                	test   %eax,%eax
f0104963:	74 68                	je     f01049cd <syscall+0x1ad>
		return -E_NO_MEM;

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104965:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010496c:	00 
f010496d:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104970:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104974:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104977:	89 04 24             	mov    %eax,(%esp)
f010497a:	e8 1e ea ff ff       	call   f010339d <envid2env>
f010497f:	89 c1                	mov    %eax,%ecx
	if(r != 0) // any bad env
f0104981:	85 c9                	test   %ecx,%ecx
f0104983:	0f 85 6b 04 00 00    	jne    f0104df4 <syscall+0x5d4>
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104989:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104990:	77 45                	ja     f01049d7 <syscall+0x1b7>
f0104992:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104999:	75 46                	jne    f01049e1 <syscall+0x1c1>
		return -E_INVAL;

	r = page_insert(target_env->env_pgdir, pp, va, perm | PTE_P);
f010499b:	8b 45 14             	mov    0x14(%ebp),%eax
f010499e:	83 c8 01             	or     $0x1,%eax
f01049a1:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01049a5:	8b 45 10             	mov    0x10(%ebp),%eax
f01049a8:	89 44 24 08          	mov    %eax,0x8(%esp)
f01049ac:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01049b0:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01049b3:	8b 40 60             	mov    0x60(%eax),%eax
f01049b6:	89 04 24             	mov    %eax,(%esp)
f01049b9:	e8 44 ca ff ff       	call   f0101402 <page_insert>
f01049be:	e9 31 04 00 00       	jmp    f0104df4 <syscall+0x5d4>
	// check perm
	//cprintf("I have given ENVID: %08x ph page at %08x!!\n", envid, va);
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f01049c3:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01049c8:	e9 27 04 00 00       	jmp    f0104df4 <syscall+0x5d4>
	struct Page* pp = page_alloc(ALLOC_ZERO);
	if(pp == NULL) // out of memory
		return -E_NO_MEM;
f01049cd:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f01049d2:	e9 1d 04 00 00       	jmp    f0104df4 <syscall+0x5d4>
	if(r != 0) // any bad env
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f01049d7:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f01049dc:	e9 13 04 00 00       	jmp    f0104df4 <syscall+0x5d4>
f01049e1:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		return sys_env_destroy(a1);
	case SYS_yield:
		sys_yield();
		return 0;
	case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
f01049e6:	e9 09 04 00 00       	jmp    f0104df4 <syscall+0x5d4>

	// LAB 4: Your code here.

	//cprintf("now at sys_page_map() mapping src: %08x to dst: %08x\n", srcva, dstva);
	//check perm
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f01049eb:	8b 45 1c             	mov    0x1c(%ebp),%eax
f01049ee:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f01049f3:	83 f8 05             	cmp    $0x5,%eax
f01049f6:	0f 85 b0 00 00 00    	jne    f0104aac <syscall+0x28c>

	//cprintf("1. perm check passed.\n");

	struct Env* srcenv, * dstenv;

	int r = envid2env(srcenvid, &srcenv, 1);
f01049fc:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104a03:	00 
f0104a04:	8d 45 dc             	lea    -0x24(%ebp),%eax
f0104a07:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a0b:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104a0e:	89 04 24             	mov    %eax,(%esp)
f0104a11:	e8 87 e9 ff ff       	call   f010339d <envid2env>
	if(r) return r;
f0104a16:	89 c2                	mov    %eax,%edx
f0104a18:	85 c0                	test   %eax,%eax
f0104a1a:	0f 85 b4 00 00 00    	jne    f0104ad4 <syscall+0x2b4>


	r = envid2env(dstenvid, &dstenv, 1);
f0104a20:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104a27:	00 
f0104a28:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104a2b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a2f:	8b 45 14             	mov    0x14(%ebp),%eax
f0104a32:	89 04 24             	mov    %eax,(%esp)
f0104a35:	e8 63 e9 ff ff       	call   f010339d <envid2env>
	if(r) return r;
f0104a3a:	89 c2                	mov    %eax,%edx
f0104a3c:	85 c0                	test   %eax,%eax
f0104a3e:	0f 85 90 00 00 00    	jne    f0104ad4 <syscall+0x2b4>

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
f0104a44:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104a4b:	77 66                	ja     f0104ab3 <syscall+0x293>
f0104a4d:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104a54:	75 64                	jne    f0104aba <syscall+0x29a>
		return -E_INVAL;

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
f0104a56:	81 7d 18 ff ff bf ee 	cmpl   $0xeebfffff,0x18(%ebp)
f0104a5d:	77 62                	ja     f0104ac1 <syscall+0x2a1>
f0104a5f:	f7 45 18 ff 0f 00 00 	testl  $0xfff,0x18(%ebp)
f0104a66:	75 60                	jne    f0104ac8 <syscall+0x2a8>

	//cprintf("2. address scope check passed.\n");

	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
f0104a68:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104a6b:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104a6f:	8b 45 10             	mov    0x10(%ebp),%eax
f0104a72:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a76:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0104a79:	8b 40 60             	mov    0x60(%eax),%eax
f0104a7c:	89 04 24             	mov    %eax,(%esp)
f0104a7f:	e8 93 c8 ff ff       	call   f0101317 <page_lookup>
	if(srcpp == NULL) return -E_INVAL;
f0104a84:	85 c0                	test   %eax,%eax
f0104a86:	74 47                	je     f0104acf <syscall+0x2af>
	//cprintf("3. page lookup check passed.\n");

	if(((perm & PTE_W) == 1) && (((*src_table_entry) & PTE_W) == 0))
		return -E_INVAL;

	r = page_insert(dstenv->env_pgdir, srcpp, dstva, perm);
f0104a88:	8b 75 1c             	mov    0x1c(%ebp),%esi
f0104a8b:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104a8f:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0104a92:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104a96:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104a9a:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104a9d:	8b 40 60             	mov    0x60(%eax),%eax
f0104aa0:	89 04 24             	mov    %eax,(%esp)
f0104aa3:	e8 5a c9 ff ff       	call   f0101402 <page_insert>
f0104aa8:	89 c2                	mov    %eax,%edx
f0104aaa:	eb 28                	jmp    f0104ad4 <syscall+0x2b4>
	//cprintf("now at sys_page_map() mapping src: %08x to dst: %08x\n", srcva, dstva);
	//check perm
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104aac:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104ab1:	eb 21                	jmp    f0104ad4 <syscall+0x2b4>

	r = envid2env(dstenvid, &dstenv, 1);
	if(r) return r;

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104ab3:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104ab8:	eb 1a                	jmp    f0104ad4 <syscall+0x2b4>
f0104aba:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104abf:	eb 13                	jmp    f0104ad4 <syscall+0x2b4>

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104ac1:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104ac6:	eb 0c                	jmp    f0104ad4 <syscall+0x2b4>
f0104ac8:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104acd:	eb 05                	jmp    f0104ad4 <syscall+0x2b4>
	//cprintf("2. address scope check passed.\n");

	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
	if(srcpp == NULL) return -E_INVAL;
f0104acf:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		sys_yield();
		return 0;
	case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
	case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
f0104ad4:	89 d0                	mov    %edx,%eax
f0104ad6:	e9 19 03 00 00       	jmp    f0104df4 <syscall+0x5d4>
sys_page_unmap(envid_t envid, void *va)
{
	// Hint: This function is a wrapper around page_remove().

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104adb:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104ae2:	00 
f0104ae3:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104ae6:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104aea:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104aed:	89 04 24             	mov    %eax,(%esp)
f0104af0:	e8 a8 e8 ff ff       	call   f010339d <envid2env>
	if(r) return r;
f0104af5:	89 c2                	mov    %eax,%edx
f0104af7:	85 c0                	test   %eax,%eax
f0104af9:	75 3a                	jne    f0104b35 <syscall+0x315>

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104afb:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104b02:	77 25                	ja     f0104b29 <syscall+0x309>
f0104b04:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104b0b:	75 23                	jne    f0104b30 <syscall+0x310>
		return -E_INVAL;

	page_remove(target_env->env_pgdir, va);
f0104b0d:	8b 45 10             	mov    0x10(%ebp),%eax
f0104b10:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b14:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104b17:	8b 40 60             	mov    0x60(%eax),%eax
f0104b1a:	89 04 24             	mov    %eax,(%esp)
f0104b1d:	e8 8e c8 ff ff       	call   f01013b0 <page_remove>
	return 0;
f0104b22:	ba 00 00 00 00       	mov    $0x0,%edx
f0104b27:	eb 0c                	jmp    f0104b35 <syscall+0x315>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r) return r;

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0104b29:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104b2e:	eb 05                	jmp    f0104b35 <syscall+0x315>
f0104b30:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
	case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
	case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
	case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
f0104b35:	89 d0                	mov    %edx,%eax
f0104b37:	e9 b8 02 00 00       	jmp    f0104df4 <syscall+0x5d4>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104b3c:	e8 92 16 00 00       	call   f01061d3 <cpunum>
f0104b41:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b44:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104b4a:	8b 58 48             	mov    0x48(%eax),%ebx
	// LAB 4: Your code here.
	//panic("sys_exofork not implemented");

	struct Env* new_env, *this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid, &this_env, 1);
f0104b4d:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104b54:	00 
f0104b55:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104b58:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b5c:	89 1c 24             	mov    %ebx,(%esp)
f0104b5f:	e8 39 e8 ff ff       	call   f010339d <envid2env>
	int r = env_alloc(&new_env, this_envid);
f0104b64:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104b68:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104b6b:	89 04 24             	mov    %eax,(%esp)
f0104b6e:	e8 4f e9 ff ff       	call   f01034c2 <env_alloc>
	if(r != 0)
		return r;
f0104b73:	89 c2                	mov    %eax,%edx

	struct Env* new_env, *this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid, &this_env, 1);
	int r = env_alloc(&new_env, this_envid);
	if(r != 0)
f0104b75:	85 c0                	test   %eax,%eax
f0104b77:	75 21                	jne    f0104b9a <syscall+0x37a>
		return r;

	new_env->env_tf = this_env->env_tf;
f0104b79:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104b7c:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104b81:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104b84:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)

	//new_env->env_tf = this_env->env_tf;

	// make it appears to return 0
	new_env->env_tf.tf_regs.reg_eax = 0;
f0104b86:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104b89:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)

	new_env->env_status = ENV_NOT_RUNNABLE;
f0104b90:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)

	return new_env->env_id;
f0104b97:	8b 50 48             	mov    0x48(%eax),%edx
	case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
	case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
	case SYS_exofork:
		return sys_exofork();
f0104b9a:	89 d0                	mov    %edx,%eax
f0104b9c:	e9 53 02 00 00       	jmp    f0104df4 <syscall+0x5d4>
	// check whether the current environment has permission to set
	// envid's status.

	// LAB 4: Your code here.
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104ba1:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104ba8:	00 
f0104ba9:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104bac:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bb0:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104bb3:	89 04 24             	mov    %eax,(%esp)
f0104bb6:	e8 e2 e7 ff ff       	call   f010339d <envid2env>
	if(r != 0)
		return r;
f0104bbb:	89 c2                	mov    %eax,%edx
	// envid's status.

	// LAB 4: Your code here.
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r != 0)
f0104bbd:	85 c0                	test   %eax,%eax
f0104bbf:	75 21                	jne    f0104be2 <syscall+0x3c2>
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
f0104bc1:	83 7d 10 04          	cmpl   $0x4,0x10(%ebp)
f0104bc5:	74 06                	je     f0104bcd <syscall+0x3ad>
f0104bc7:	83 7d 10 02          	cmpl   $0x2,0x10(%ebp)
f0104bcb:	75 10                	jne    f0104bdd <syscall+0x3bd>
		return -E_INVAL;

	target_env->env_status = status;
f0104bcd:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104bd0:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104bd3:	89 48 54             	mov    %ecx,0x54(%eax)

	return 0;
f0104bd6:	ba 00 00 00 00       	mov    $0x0,%edx
f0104bdb:	eb 05                	jmp    f0104be2 <syscall+0x3c2>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r != 0)
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
		return -E_INVAL;
f0104bdd:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
	case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
	case SYS_exofork:
		return sys_exofork();
	case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
f0104be2:	89 d0                	mov    %edx,%eax
f0104be4:	e9 0b 02 00 00       	jmp    f0104df4 <syscall+0x5d4>
//		or the caller doesn't have permission to change envid.
static int
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	// LAB 4: Your code here.
	struct Env* target_env = NULL;
f0104be9:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	int r = envid2env(envid, &target_env, 1);
f0104bf0:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104bf7:	00 
f0104bf8:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104bfb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bff:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104c02:	89 04 24             	mov    %eax,(%esp)
f0104c05:	e8 93 e7 ff ff       	call   f010339d <envid2env>
	if(r != 0) return r;
f0104c0a:	85 c0                	test   %eax,%eax
f0104c0c:	0f 85 e2 01 00 00    	jne    f0104df4 <syscall+0x5d4>
	target_env->env_pgfault_upcall = func;
f0104c12:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0104c15:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104c18:	89 7a 64             	mov    %edi,0x64(%edx)
	case SYS_exofork:
		return sys_exofork();
	case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
	case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
f0104c1b:	e9 d4 01 00 00       	jmp    f0104df4 <syscall+0x5d4>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	// LAB 4: Your code here.
	struct Env* target_env;
	int r;
	if((r = envid2env(envid, &target_env, 0)) < 0) return r; // BAD ENV
f0104c20:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0104c27:	00 
f0104c28:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104c2b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c2f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104c32:	89 04 24             	mov    %eax,(%esp)
f0104c35:	e8 63 e7 ff ff       	call   f010339d <envid2env>
f0104c3a:	85 c0                	test   %eax,%eax
f0104c3c:	0f 88 0c 01 00 00    	js     f0104d4e <syscall+0x52e>
	if(!target_env->env_ipc_recving || target_env->env_ipc_from != 0) // dst not receiving
f0104c42:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104c45:	83 78 68 00          	cmpl   $0x0,0x68(%eax)
f0104c49:	0f 84 03 01 00 00    	je     f0104d52 <syscall+0x532>
f0104c4f:	8b 58 74             	mov    0x74(%eax),%ebx
f0104c52:	85 db                	test   %ebx,%ebx
f0104c54:	0f 85 ff 00 00 00    	jne    f0104d59 <syscall+0x539>
		return -E_IPC_NOT_RECV;


    target_env->env_ipc_perm = 0; //is set to 'perm' if a page was transferred, 0 otherwise.
f0104c5a:	c7 40 78 00 00 00 00 	movl   $0x0,0x78(%eax)

	if((uint32_t)srcva < UTOP) // if a page is to be mapped
f0104c61:	81 7d 14 ff ff bf ee 	cmpl   $0xeebfffff,0x14(%ebp)
f0104c68:	0f 87 a9 00 00 00    	ja     f0104d17 <syscall+0x4f7>
	{
		if( ROUNDDOWN(srcva, PGSIZE) != srcva) return -E_INVAL;
f0104c6e:	8b 45 14             	mov    0x14(%ebp),%eax
f0104c71:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0104c76:	39 45 14             	cmp    %eax,0x14(%ebp)
f0104c79:	75 79                	jne    f0104cf4 <syscall+0x4d4>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104c7b:	8b 45 18             	mov    0x18(%ebp),%eax
f0104c7e:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104c83:	83 f8 05             	cmp    $0x5,%eax
f0104c86:	75 73                	jne    f0104cfb <syscall+0x4db>
		return -E_INVAL;

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
f0104c88:	e8 46 15 00 00       	call   f01061d3 <cpunum>
f0104c8d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104c90:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104c94:	8b 75 14             	mov    0x14(%ebp),%esi
f0104c97:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104c9b:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c9e:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104ca4:	8b 40 60             	mov    0x60(%eax),%eax
f0104ca7:	89 04 24             	mov    %eax,(%esp)
f0104caa:	e8 68 c6 ff ff       	call   f0101317 <page_lookup>
		if(srcpp == NULL) return -E_INVAL;
f0104caf:	85 c0                	test   %eax,%eax
f0104cb1:	74 4f                	je     f0104d02 <syscall+0x4e2>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f0104cb3:	f6 45 18 02          	testb  $0x2,0x18(%ebp)
f0104cb7:	74 08                	je     f0104cc1 <syscall+0x4a1>
f0104cb9:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0104cbc:	f6 02 02             	testb  $0x2,(%edx)
f0104cbf:	74 48                	je     f0104d09 <syscall+0x4e9>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
f0104cc1:	8b 55 e0             	mov    -0x20(%ebp),%edx
f0104cc4:	8b 4a 6c             	mov    0x6c(%edx),%ecx
f0104cc7:	85 c9                	test   %ecx,%ecx
f0104cc9:	74 4c                	je     f0104d17 <syscall+0x4f7>
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
f0104ccb:	8b 75 18             	mov    0x18(%ebp),%esi
f0104cce:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104cd2:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104cd6:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104cda:	8b 42 60             	mov    0x60(%edx),%eax
f0104cdd:	89 04 24             	mov    %eax,(%esp)
f0104ce0:	e8 1d c7 ff ff       	call   f0101402 <page_insert>
f0104ce5:	85 c0                	test   %eax,%eax
f0104ce7:	78 27                	js     f0104d10 <syscall+0x4f0>
				return -E_NO_MEM;
			target_env->env_ipc_perm = perm;
f0104ce9:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104cec:	8b 75 18             	mov    0x18(%ebp),%esi
f0104cef:	89 70 78             	mov    %esi,0x78(%eax)
f0104cf2:	eb 23                	jmp    f0104d17 <syscall+0x4f7>

    target_env->env_ipc_perm = 0; //is set to 'perm' if a page was transferred, 0 otherwise.

	if((uint32_t)srcva < UTOP) // if a page is to be mapped
	{
		if( ROUNDDOWN(srcva, PGSIZE) != srcva) return -E_INVAL;
f0104cf4:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104cf9:	eb 63                	jmp    f0104d5e <syscall+0x53e>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104cfb:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104d00:	eb 5c                	jmp    f0104d5e <syscall+0x53e>

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;
f0104d02:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104d07:	eb 55                	jmp    f0104d5e <syscall+0x53e>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
			return -E_INVAL;
f0104d09:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104d0e:	eb 4e                	jmp    f0104d5e <syscall+0x53e>

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
				return -E_NO_MEM;
f0104d10:	bb fc ff ff ff       	mov    $0xfffffffc,%ebx
f0104d15:	eb 47                	jmp    f0104d5e <syscall+0x53e>
			target_env->env_ipc_perm = perm;
		}
	}

	target_env->env_ipc_recving = 0;// set to 0 to block future sends;
f0104d17:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104d1a:	c7 46 68 00 00 00 00 	movl   $0x0,0x68(%esi)
    target_env->env_ipc_from = curenv->env_id; // set to the sending envid;
f0104d21:	e8 ad 14 00 00       	call   f01061d3 <cpunum>
f0104d26:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d29:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104d2f:	8b 40 48             	mov    0x48(%eax),%eax
f0104d32:	89 46 74             	mov    %eax,0x74(%esi)
    target_env->env_ipc_value = value; //is set to the 'value' parameter;
f0104d35:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104d38:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104d3b:	89 78 70             	mov    %edi,0x70(%eax)
	target_env->env_tf.tf_regs.reg_eax = 0;
f0104d3e:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	
	target_env->env_status = ENV_RUNNABLE;
f0104d45:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
f0104d4c:	eb 10                	jmp    f0104d5e <syscall+0x53e>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	// LAB 4: Your code here.
	struct Env* target_env;
	int r;
	if((r = envid2env(envid, &target_env, 0)) < 0) return r; // BAD ENV
f0104d4e:	89 c3                	mov    %eax,%ebx
f0104d50:	eb 0c                	jmp    f0104d5e <syscall+0x53e>
	if(!target_env->env_ipc_recving || target_env->env_ipc_from != 0) // dst not receiving
		return -E_IPC_NOT_RECV;
f0104d52:	bb f9 ff ff ff       	mov    $0xfffffff9,%ebx
f0104d57:	eb 05                	jmp    f0104d5e <syscall+0x53e>
f0104d59:	bb f9 ff ff ff       	mov    $0xfffffff9,%ebx
	case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
	case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
	case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, a4);
f0104d5e:	89 d8                	mov    %ebx,%eax
f0104d60:	e9 8f 00 00 00       	jmp    f0104df4 <syscall+0x5d4>
//	-E_INVAL if dstva < UTOP but dstva is not page-aligned.
static int
sys_ipc_recv(void *dstva)
{
	// LAB 4: Your code here.
	curenv->env_ipc_recving = 1;
f0104d65:	e8 69 14 00 00       	call   f01061d3 <cpunum>
f0104d6a:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d6d:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104d73:	c7 40 68 01 00 00 00 	movl   $0x1,0x68(%eax)
	if((uint32_t)dstva < UTOP)
f0104d7a:	81 7d 0c ff ff bf ee 	cmpl   $0xeebfffff,0xc(%ebp)
f0104d81:	77 21                	ja     f0104da4 <syscall+0x584>
	{
		if(ROUNDDOWN(dstva, PGSIZE) != dstva) return -E_INVAL;
f0104d83:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d86:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0104d8b:	39 45 0c             	cmp    %eax,0xc(%ebp)
f0104d8e:	75 5f                	jne    f0104def <syscall+0x5cf>
		curenv->env_ipc_dstva = dstva;
f0104d90:	e8 3e 14 00 00       	call   f01061d3 <cpunum>
f0104d95:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d98:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104d9e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104da1:	89 70 6c             	mov    %esi,0x6c(%eax)
	}
	curenv->env_status = ENV_NOT_RUNNABLE;
f0104da4:	e8 2a 14 00 00       	call   f01061d3 <cpunum>
f0104da9:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dac:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104db2:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
	curenv->env_ipc_from = 0;
f0104db9:	e8 15 14 00 00       	call   f01061d3 <cpunum>
f0104dbe:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dc1:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104dc7:	c7 40 74 00 00 00 00 	movl   $0x0,0x74(%eax)


	sched_yield();
f0104dce:	e8 2d f9 ff ff       	call   f0104700 <sched_yield>
	case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, a4);
	case SYS_ipc_recv:
		return sys_ipc_recv((void*)a1);
	default:
		panic("Syscall number Invalid!\n");
f0104dd3:	c7 44 24 08 b2 7e 10 	movl   $0xf0107eb2,0x8(%esp)
f0104dda:	f0 
f0104ddb:	c7 44 24 04 e7 01 00 	movl   $0x1e7,0x4(%esp)
f0104de2:	00 
f0104de3:	c7 04 24 cb 7e 10 f0 	movl   $0xf0107ecb,(%esp)
f0104dea:	e8 51 b2 ff ff       	call   f0100040 <_panic>
	case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
	case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, a4);
	case SYS_ipc_recv:
		return sys_ipc_recv((void*)a1);
f0104def:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	default:
		panic("Syscall number Invalid!\n");
	}

	return -E_INVAL;
}
f0104df4:	83 c4 2c             	add    $0x2c,%esp
f0104df7:	5b                   	pop    %ebx
f0104df8:	5e                   	pop    %esi
f0104df9:	5f                   	pop    %edi
f0104dfa:	5d                   	pop    %ebp
f0104dfb:	c3                   	ret    
f0104dfc:	66 90                	xchg   %ax,%ax
f0104dfe:	66 90                	xchg   %ax,%ax

f0104e00 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104e00:	55                   	push   %ebp
f0104e01:	89 e5                	mov    %esp,%ebp
f0104e03:	57                   	push   %edi
f0104e04:	56                   	push   %esi
f0104e05:	53                   	push   %ebx
f0104e06:	83 ec 14             	sub    $0x14,%esp
f0104e09:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104e0c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0104e0f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104e12:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104e15:	8b 1a                	mov    (%edx),%ebx
f0104e17:	8b 01                	mov    (%ecx),%eax
f0104e19:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f0104e1c:	39 c3                	cmp    %eax,%ebx
f0104e1e:	0f 8f 9a 00 00 00    	jg     f0104ebe <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104e24:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104e2b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0104e2e:	01 d8                	add    %ebx,%eax
f0104e30:	89 c7                	mov    %eax,%edi
f0104e32:	c1 ef 1f             	shr    $0x1f,%edi
f0104e35:	01 c7                	add    %eax,%edi
f0104e37:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104e39:	39 df                	cmp    %ebx,%edi
f0104e3b:	0f 8c c4 00 00 00    	jl     f0104f05 <stab_binsearch+0x105>
f0104e41:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104e44:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104e47:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0104e4a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0104e4e:	39 f0                	cmp    %esi,%eax
f0104e50:	0f 84 b4 00 00 00    	je     f0104f0a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104e56:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104e58:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104e5b:	39 d8                	cmp    %ebx,%eax
f0104e5d:	0f 8c a2 00 00 00    	jl     f0104f05 <stab_binsearch+0x105>
f0104e63:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104e67:	83 ea 0c             	sub    $0xc,%edx
f0104e6a:	39 f1                	cmp    %esi,%ecx
f0104e6c:	75 ea                	jne    f0104e58 <stab_binsearch+0x58>
f0104e6e:	e9 99 00 00 00       	jmp    f0104f0c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104e73:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104e76:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104e78:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104e7b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104e82:	eb 2b                	jmp    f0104eaf <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0104e84:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104e87:	76 14                	jbe    f0104e9d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0104e89:	83 e8 01             	sub    $0x1,%eax
f0104e8c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0104e8f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104e92:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104e94:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104e9b:	eb 12                	jmp    f0104eaf <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0104e9d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104ea0:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0104ea2:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0104ea6:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104ea8:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0104eaf:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0104eb2:	0f 8e 73 ff ff ff    	jle    f0104e2b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0104eb8:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0104ebc:	75 0f                	jne    f0104ecd <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0104ebe:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104ec1:	8b 00                	mov    (%eax),%eax
f0104ec3:	83 e8 01             	sub    $0x1,%eax
f0104ec6:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104ec9:	89 06                	mov    %eax,(%esi)
f0104ecb:	eb 57                	jmp    f0104f24 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104ecd:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104ed0:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0104ed2:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104ed5:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104ed7:	39 c8                	cmp    %ecx,%eax
f0104ed9:	7e 23                	jle    f0104efe <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104edb:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104ede:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104ee1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104ee4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104ee8:	39 f3                	cmp    %esi,%ebx
f0104eea:	74 12                	je     f0104efe <stab_binsearch+0xfe>
		     l--)
f0104eec:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104eef:	39 c8                	cmp    %ecx,%eax
f0104ef1:	7e 0b                	jle    f0104efe <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104ef3:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104ef7:	83 ea 0c             	sub    $0xc,%edx
f0104efa:	39 f3                	cmp    %esi,%ebx
f0104efc:	75 ee                	jne    f0104eec <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0104efe:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104f01:	89 06                	mov    %eax,(%esi)
f0104f03:	eb 1f                	jmp    f0104f24 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104f05:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104f08:	eb a5                	jmp    f0104eaf <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104f0a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0104f0c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104f0f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104f12:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104f16:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104f19:	0f 82 54 ff ff ff    	jb     f0104e73 <stab_binsearch+0x73>
f0104f1f:	e9 60 ff ff ff       	jmp    f0104e84 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104f24:	83 c4 14             	add    $0x14,%esp
f0104f27:	5b                   	pop    %ebx
f0104f28:	5e                   	pop    %esi
f0104f29:	5f                   	pop    %edi
f0104f2a:	5d                   	pop    %ebp
f0104f2b:	c3                   	ret    

f0104f2c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0104f2c:	55                   	push   %ebp
f0104f2d:	89 e5                	mov    %esp,%ebp
f0104f2f:	57                   	push   %edi
f0104f30:	56                   	push   %esi
f0104f31:	53                   	push   %ebx
f0104f32:	83 ec 3c             	sub    $0x3c,%esp
f0104f35:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104f38:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0104f3b:	c7 06 10 7f 10 f0    	movl   $0xf0107f10,(%esi)
	info->eip_line = 0;
f0104f41:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104f48:	c7 46 08 10 7f 10 f0 	movl   $0xf0107f10,0x8(%esi)
	info->eip_fn_namelen = 9;
f0104f4f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104f56:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104f59:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104f60:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104f66:	0f 87 ca 00 00 00    	ja     f0105036 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
f0104f6c:	e8 62 12 00 00       	call   f01061d3 <cpunum>
f0104f71:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104f78:	00 
f0104f79:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0104f80:	00 
f0104f81:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0104f88:	00 
f0104f89:	6b c0 74             	imul   $0x74,%eax,%eax
f0104f8c:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104f92:	89 04 24             	mov    %eax,(%esp)
f0104f95:	e8 77 e2 ff ff       	call   f0103211 <user_mem_check>
f0104f9a:	85 c0                	test   %eax,%eax
f0104f9c:	0f 88 12 02 00 00    	js     f01051b4 <debuginfo_eip+0x288>
		{
		    return -1;
		}
		stabs = usd->stabs;
f0104fa2:	a1 00 00 20 00       	mov    0x200000,%eax
f0104fa7:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104faa:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0104fb0:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0104fb6:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0104fb9:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0104fbe:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
f0104fc1:	e8 0d 12 00 00       	call   f01061d3 <cpunum>
f0104fc6:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104fcd:	00 
f0104fce:	89 da                	mov    %ebx,%edx
f0104fd0:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104fd3:	29 ca                	sub    %ecx,%edx
f0104fd5:	c1 fa 02             	sar    $0x2,%edx
f0104fd8:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0104fde:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104fe2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104fe6:	6b c0 74             	imul   $0x74,%eax,%eax
f0104fe9:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0104fef:	89 04 24             	mov    %eax,(%esp)
f0104ff2:	e8 1a e2 ff ff       	call   f0103211 <user_mem_check>
f0104ff7:	85 c0                	test   %eax,%eax
f0104ff9:	0f 88 bc 01 00 00    	js     f01051bb <debuginfo_eip+0x28f>
f0104fff:	e8 cf 11 00 00       	call   f01061d3 <cpunum>
f0105004:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010500b:	00 
f010500c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f010500f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0105012:	29 ca                	sub    %ecx,%edx
f0105014:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105018:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f010501c:	6b c0 74             	imul   $0x74,%eax,%eax
f010501f:	8b 80 28 70 22 f0    	mov    -0xfdd8fd8(%eax),%eax
f0105025:	89 04 24             	mov    %eax,(%esp)
f0105028:	e8 e4 e1 ff ff       	call   f0103211 <user_mem_check>
f010502d:	85 c0                	test   %eax,%eax
f010502f:	79 1f                	jns    f0105050 <debuginfo_eip+0x124>
f0105031:	e9 8c 01 00 00       	jmp    f01051c2 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0105036:	c7 45 cc 62 5e 11 f0 	movl   $0xf0115e62,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f010503d:	c7 45 d0 dd 28 11 f0 	movl   $0xf01128dd,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0105044:	bb dc 28 11 f0       	mov    $0xf01128dc,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0105049:	c7 45 d4 f4 83 10 f0 	movl   $0xf01083f4,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0105050:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0105053:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0105056:	0f 83 6d 01 00 00    	jae    f01051c9 <debuginfo_eip+0x29d>
f010505c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0105060:	0f 85 6a 01 00 00    	jne    f01051d0 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0105066:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f010506d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0105070:	c1 fb 02             	sar    $0x2,%ebx
f0105073:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0105079:	83 e8 01             	sub    $0x1,%eax
f010507c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f010507f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105083:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f010508a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f010508d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0105090:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0105093:	89 d8                	mov    %ebx,%eax
f0105095:	e8 66 fd ff ff       	call   f0104e00 <stab_binsearch>
	if (lfile == 0)
f010509a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010509d:	85 c0                	test   %eax,%eax
f010509f:	0f 84 32 01 00 00    	je     f01051d7 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f01050a5:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f01050a8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050ab:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f01050ae:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01050b2:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f01050b9:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f01050bc:	8d 55 dc             	lea    -0x24(%ebp),%edx
f01050bf:	89 d8                	mov    %ebx,%eax
f01050c1:	e8 3a fd ff ff       	call   f0104e00 <stab_binsearch>

	if (lfun <= rfun) {
f01050c6:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f01050c9:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f01050cc:	7f 23                	jg     f01050f1 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f01050ce:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f01050d1:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01050d4:	8d 04 87             	lea    (%edi,%eax,4),%eax
f01050d7:	8b 10                	mov    (%eax),%edx
f01050d9:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f01050dc:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f01050df:	39 ca                	cmp    %ecx,%edx
f01050e1:	73 06                	jae    f01050e9 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f01050e3:	03 55 d0             	add    -0x30(%ebp),%edx
f01050e6:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f01050e9:	8b 40 08             	mov    0x8(%eax),%eax
f01050ec:	89 46 10             	mov    %eax,0x10(%esi)
f01050ef:	eb 06                	jmp    f01050f7 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f01050f1:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f01050f4:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f01050f7:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f01050fe:	00 
f01050ff:	8b 46 08             	mov    0x8(%esi),%eax
f0105102:	89 04 24             	mov    %eax,(%esp)
f0105105:	e8 05 0a 00 00       	call   f0105b0f <strfind>
f010510a:	2b 46 08             	sub    0x8(%esi),%eax
f010510d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0105110:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105113:	39 fb                	cmp    %edi,%ebx
f0105115:	7c 5d                	jl     f0105174 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0105117:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010511a:	c1 e0 02             	shl    $0x2,%eax
f010511d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105120:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0105123:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0105126:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f010512a:	80 fa 84             	cmp    $0x84,%dl
f010512d:	74 2d                	je     f010515c <debuginfo_eip+0x230>
f010512f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0105133:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0105136:	eb 15                	jmp    f010514d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0105138:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f010513b:	39 fb                	cmp    %edi,%ebx
f010513d:	7c 35                	jl     f0105174 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f010513f:	89 c1                	mov    %eax,%ecx
f0105141:	83 e8 0c             	sub    $0xc,%eax
f0105144:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0105148:	80 fa 84             	cmp    $0x84,%dl
f010514b:	74 0f                	je     f010515c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010514d:	80 fa 64             	cmp    $0x64,%dl
f0105150:	75 e6                	jne    f0105138 <debuginfo_eip+0x20c>
f0105152:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0105156:	74 e0                	je     f0105138 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0105158:	39 df                	cmp    %ebx,%edi
f010515a:	7f 18                	jg     f0105174 <debuginfo_eip+0x248>
f010515c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010515f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105162:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0105165:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0105168:	2b 55 d0             	sub    -0x30(%ebp),%edx
f010516b:	39 d0                	cmp    %edx,%eax
f010516d:	73 05                	jae    f0105174 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f010516f:	03 45 d0             	add    -0x30(%ebp),%eax
f0105172:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0105174:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105177:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010517a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f010517f:	39 ca                	cmp    %ecx,%edx
f0105181:	7d 75                	jge    f01051f8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0105183:	8d 42 01             	lea    0x1(%edx),%eax
f0105186:	39 c1                	cmp    %eax,%ecx
f0105188:	7e 54                	jle    f01051de <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f010518a:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010518d:	c1 e2 02             	shl    $0x2,%edx
f0105190:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105193:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0105198:	75 4b                	jne    f01051e5 <debuginfo_eip+0x2b9>
f010519a:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f010519e:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f01051a2:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f01051a5:	39 c1                	cmp    %eax,%ecx
f01051a7:	7e 43                	jle    f01051ec <debuginfo_eip+0x2c0>
f01051a9:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f01051ac:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f01051b0:	74 ec                	je     f010519e <debuginfo_eip+0x272>
f01051b2:	eb 3f                	jmp    f01051f3 <debuginfo_eip+0x2c7>
		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
		{
		    return -1;
f01051b4:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01051b9:	eb 3d                	jmp    f01051f8 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
		 {
		    return -1;
f01051bb:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01051c0:	eb 36                	jmp    f01051f8 <debuginfo_eip+0x2cc>
f01051c2:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01051c7:	eb 2f                	jmp    f01051f8 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f01051c9:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01051ce:	eb 28                	jmp    f01051f8 <debuginfo_eip+0x2cc>
f01051d0:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01051d5:	eb 21                	jmp    f01051f8 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f01051d7:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f01051dc:	eb 1a                	jmp    f01051f8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f01051de:	b8 00 00 00 00       	mov    $0x0,%eax
f01051e3:	eb 13                	jmp    f01051f8 <debuginfo_eip+0x2cc>
f01051e5:	b8 00 00 00 00       	mov    $0x0,%eax
f01051ea:	eb 0c                	jmp    f01051f8 <debuginfo_eip+0x2cc>
f01051ec:	b8 00 00 00 00       	mov    $0x0,%eax
f01051f1:	eb 05                	jmp    f01051f8 <debuginfo_eip+0x2cc>
f01051f3:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01051f8:	83 c4 3c             	add    $0x3c,%esp
f01051fb:	5b                   	pop    %ebx
f01051fc:	5e                   	pop    %esi
f01051fd:	5f                   	pop    %edi
f01051fe:	5d                   	pop    %ebp
f01051ff:	c3                   	ret    

f0105200 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105200:	55                   	push   %ebp
f0105201:	89 e5                	mov    %esp,%ebp
f0105203:	57                   	push   %edi
f0105204:	56                   	push   %esi
f0105205:	53                   	push   %ebx
f0105206:	83 ec 3c             	sub    $0x3c,%esp
f0105209:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010520c:	89 d7                	mov    %edx,%edi
f010520e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105211:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105214:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105217:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010521a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010521d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105222:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105225:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105228:	39 f1                	cmp    %esi,%ecx
f010522a:	72 14                	jb     f0105240 <printnum+0x40>
f010522c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010522f:	76 0f                	jbe    f0105240 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f0105231:	8b 45 14             	mov    0x14(%ebp),%eax
f0105234:	8d 70 ff             	lea    -0x1(%eax),%esi
f0105237:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f010523a:	85 f6                	test   %esi,%esi
f010523c:	7f 60                	jg     f010529e <printnum+0x9e>
f010523e:	eb 72                	jmp    f01052b2 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105240:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105243:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105247:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010524a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010524d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105251:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105255:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105259:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010525d:	89 c3                	mov    %eax,%ebx
f010525f:	89 d6                	mov    %edx,%esi
f0105261:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105264:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105267:	89 54 24 08          	mov    %edx,0x8(%esp)
f010526b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010526f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105272:	89 04 24             	mov    %eax,(%esp)
f0105275:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105278:	89 44 24 04          	mov    %eax,0x4(%esp)
f010527c:	e8 bf 13 00 00       	call   f0106640 <__udivdi3>
f0105281:	89 d9                	mov    %ebx,%ecx
f0105283:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105287:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010528b:	89 04 24             	mov    %eax,(%esp)
f010528e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105292:	89 fa                	mov    %edi,%edx
f0105294:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105297:	e8 64 ff ff ff       	call   f0105200 <printnum>
f010529c:	eb 14                	jmp    f01052b2 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f010529e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01052a2:	8b 45 18             	mov    0x18(%ebp),%eax
f01052a5:	89 04 24             	mov    %eax,(%esp)
f01052a8:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01052aa:	83 ee 01             	sub    $0x1,%esi
f01052ad:	75 ef                	jne    f010529e <printnum+0x9e>
f01052af:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f01052b2:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01052b6:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01052ba:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01052bd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01052c0:	89 44 24 08          	mov    %eax,0x8(%esp)
f01052c4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01052c8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01052cb:	89 04 24             	mov    %eax,(%esp)
f01052ce:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01052d1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01052d5:	e8 96 14 00 00       	call   f0106770 <__umoddi3>
f01052da:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01052de:	0f be 80 1a 7f 10 f0 	movsbl -0xfef80e6(%eax),%eax
f01052e5:	89 04 24             	mov    %eax,(%esp)
f01052e8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01052eb:	ff d0                	call   *%eax
}
f01052ed:	83 c4 3c             	add    $0x3c,%esp
f01052f0:	5b                   	pop    %ebx
f01052f1:	5e                   	pop    %esi
f01052f2:	5f                   	pop    %edi
f01052f3:	5d                   	pop    %ebp
f01052f4:	c3                   	ret    

f01052f5 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f01052f5:	55                   	push   %ebp
f01052f6:	89 e5                	mov    %esp,%ebp
f01052f8:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f01052fb:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f01052ff:	8b 10                	mov    (%eax),%edx
f0105301:	3b 50 04             	cmp    0x4(%eax),%edx
f0105304:	73 0a                	jae    f0105310 <sprintputch+0x1b>
		*b->buf++ = ch;
f0105306:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105309:	89 08                	mov    %ecx,(%eax)
f010530b:	8b 45 08             	mov    0x8(%ebp),%eax
f010530e:	88 02                	mov    %al,(%edx)
}
f0105310:	5d                   	pop    %ebp
f0105311:	c3                   	ret    

f0105312 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0105312:	55                   	push   %ebp
f0105313:	89 e5                	mov    %esp,%ebp
f0105315:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0105318:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f010531b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010531f:	8b 45 10             	mov    0x10(%ebp),%eax
f0105322:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105326:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105329:	89 44 24 04          	mov    %eax,0x4(%esp)
f010532d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105330:	89 04 24             	mov    %eax,(%esp)
f0105333:	e8 02 00 00 00       	call   f010533a <vprintfmt>
	va_end(ap);
}
f0105338:	c9                   	leave  
f0105339:	c3                   	ret    

f010533a <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f010533a:	55                   	push   %ebp
f010533b:	89 e5                	mov    %esp,%ebp
f010533d:	57                   	push   %edi
f010533e:	56                   	push   %esi
f010533f:	53                   	push   %ebx
f0105340:	83 ec 3c             	sub    $0x3c,%esp
f0105343:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105346:	89 df                	mov    %ebx,%edi
f0105348:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010534b:	eb 03                	jmp    f0105350 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f010534d:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0105350:	8b 45 10             	mov    0x10(%ebp),%eax
f0105353:	8d 70 01             	lea    0x1(%eax),%esi
f0105356:	0f b6 00             	movzbl (%eax),%eax
f0105359:	83 f8 25             	cmp    $0x25,%eax
f010535c:	74 2d                	je     f010538b <vprintfmt+0x51>
			if (ch == '\0')
f010535e:	85 c0                	test   %eax,%eax
f0105360:	75 14                	jne    f0105376 <vprintfmt+0x3c>
f0105362:	e9 6b 04 00 00       	jmp    f01057d2 <vprintfmt+0x498>
f0105367:	85 c0                	test   %eax,%eax
f0105369:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0105370:	0f 84 5c 04 00 00    	je     f01057d2 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0105376:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010537a:	89 04 24             	mov    %eax,(%esp)
f010537d:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f010537f:	83 c6 01             	add    $0x1,%esi
f0105382:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f0105386:	83 f8 25             	cmp    $0x25,%eax
f0105389:	75 dc                	jne    f0105367 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010538b:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f010538f:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0105396:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010539d:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f01053a4:	b9 00 00 00 00       	mov    $0x0,%ecx
f01053a9:	eb 1f                	jmp    f01053ca <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01053ab:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f01053ae:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f01053b2:	eb 16                	jmp    f01053ca <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01053b4:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f01053b7:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f01053bb:	eb 0d                	jmp    f01053ca <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f01053bd:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01053c0:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01053c3:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01053ca:	8d 46 01             	lea    0x1(%esi),%eax
f01053cd:	89 45 10             	mov    %eax,0x10(%ebp)
f01053d0:	0f b6 06             	movzbl (%esi),%eax
f01053d3:	0f b6 d0             	movzbl %al,%edx
f01053d6:	83 e8 23             	sub    $0x23,%eax
f01053d9:	3c 55                	cmp    $0x55,%al
f01053db:	0f 87 c4 03 00 00    	ja     f01057a5 <vprintfmt+0x46b>
f01053e1:	0f b6 c0             	movzbl %al,%eax
f01053e4:	ff 24 85 e0 7f 10 f0 	jmp    *-0xfef8020(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f01053eb:	8d 42 d0             	lea    -0x30(%edx),%eax
f01053ee:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f01053f1:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f01053f5:	8d 50 d0             	lea    -0x30(%eax),%edx
f01053f8:	83 fa 09             	cmp    $0x9,%edx
f01053fb:	77 63                	ja     f0105460 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01053fd:	8b 75 10             	mov    0x10(%ebp),%esi
f0105400:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f0105403:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0105406:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0105409:	8d 14 92             	lea    (%edx,%edx,4),%edx
f010540c:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f0105410:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105413:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0105416:	83 f9 09             	cmp    $0x9,%ecx
f0105419:	76 eb                	jbe    f0105406 <vprintfmt+0xcc>
f010541b:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f010541e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0105421:	eb 40                	jmp    f0105463 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105423:	8b 45 14             	mov    0x14(%ebp),%eax
f0105426:	8b 00                	mov    (%eax),%eax
f0105428:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010542b:	8b 45 14             	mov    0x14(%ebp),%eax
f010542e:	8d 40 04             	lea    0x4(%eax),%eax
f0105431:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105434:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f0105437:	eb 2a                	jmp    f0105463 <vprintfmt+0x129>
f0105439:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f010543c:	85 d2                	test   %edx,%edx
f010543e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105443:	0f 49 c2             	cmovns %edx,%eax
f0105446:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105449:	8b 75 10             	mov    0x10(%ebp),%esi
f010544c:	e9 79 ff ff ff       	jmp    f01053ca <vprintfmt+0x90>
f0105451:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0105454:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f010545b:	e9 6a ff ff ff       	jmp    f01053ca <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105460:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0105463:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105467:	0f 89 5d ff ff ff    	jns    f01053ca <vprintfmt+0x90>
f010546d:	e9 4b ff ff ff       	jmp    f01053bd <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0105472:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105475:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0105478:	e9 4d ff ff ff       	jmp    f01053ca <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f010547d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105480:	8d 70 04             	lea    0x4(%eax),%esi
f0105483:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105487:	8b 00                	mov    (%eax),%eax
f0105489:	89 04 24             	mov    %eax,(%esp)
f010548c:	ff d7                	call   *%edi
f010548e:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0105491:	e9 ba fe ff ff       	jmp    f0105350 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0105496:	8b 45 14             	mov    0x14(%ebp),%eax
f0105499:	8d 70 04             	lea    0x4(%eax),%esi
f010549c:	8b 00                	mov    (%eax),%eax
f010549e:	99                   	cltd   
f010549f:	31 d0                	xor    %edx,%eax
f01054a1:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f01054a3:	83 f8 08             	cmp    $0x8,%eax
f01054a6:	7f 0b                	jg     f01054b3 <vprintfmt+0x179>
f01054a8:	8b 14 85 40 81 10 f0 	mov    -0xfef7ec0(,%eax,4),%edx
f01054af:	85 d2                	test   %edx,%edx
f01054b1:	75 20                	jne    f01054d3 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f01054b3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01054b7:	c7 44 24 08 32 7f 10 	movl   $0xf0107f32,0x8(%esp)
f01054be:	f0 
f01054bf:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054c3:	89 3c 24             	mov    %edi,(%esp)
f01054c6:	e8 47 fe ff ff       	call   f0105312 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f01054cb:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f01054ce:	e9 7d fe ff ff       	jmp    f0105350 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f01054d3:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01054d7:	c7 44 24 08 ae 6e 10 	movl   $0xf0106eae,0x8(%esp)
f01054de:	f0 
f01054df:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054e3:	89 3c 24             	mov    %edi,(%esp)
f01054e6:	e8 27 fe ff ff       	call   f0105312 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f01054eb:	89 75 14             	mov    %esi,0x14(%ebp)
f01054ee:	e9 5d fe ff ff       	jmp    f0105350 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01054f3:	8b 45 14             	mov    0x14(%ebp),%eax
f01054f6:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f01054f9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f01054fc:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f0105500:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0105502:	85 c0                	test   %eax,%eax
f0105504:	b9 2b 7f 10 f0       	mov    $0xf0107f2b,%ecx
f0105509:	0f 45 c8             	cmovne %eax,%ecx
f010550c:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f010550f:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0105513:	74 04                	je     f0105519 <vprintfmt+0x1df>
f0105515:	85 f6                	test   %esi,%esi
f0105517:	7f 19                	jg     f0105532 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105519:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010551c:	8d 70 01             	lea    0x1(%eax),%esi
f010551f:	0f b6 10             	movzbl (%eax),%edx
f0105522:	0f be c2             	movsbl %dl,%eax
f0105525:	85 c0                	test   %eax,%eax
f0105527:	0f 85 9a 00 00 00    	jne    f01055c7 <vprintfmt+0x28d>
f010552d:	e9 87 00 00 00       	jmp    f01055b9 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105532:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105536:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0105539:	89 04 24             	mov    %eax,(%esp)
f010553c:	e8 11 04 00 00       	call   f0105952 <strnlen>
f0105541:	29 c6                	sub    %eax,%esi
f0105543:	89 f0                	mov    %esi,%eax
f0105545:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105548:	85 f6                	test   %esi,%esi
f010554a:	7e cd                	jle    f0105519 <vprintfmt+0x1df>
					putch(padc, putdat);
f010554c:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105550:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0105553:	89 c3                	mov    %eax,%ebx
f0105555:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105558:	89 44 24 04          	mov    %eax,0x4(%esp)
f010555c:	89 34 24             	mov    %esi,(%esp)
f010555f:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105561:	83 eb 01             	sub    $0x1,%ebx
f0105564:	75 ef                	jne    f0105555 <vprintfmt+0x21b>
f0105566:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105569:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010556c:	eb ab                	jmp    f0105519 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f010556e:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0105572:	74 1e                	je     f0105592 <vprintfmt+0x258>
f0105574:	0f be d2             	movsbl %dl,%edx
f0105577:	83 ea 20             	sub    $0x20,%edx
f010557a:	83 fa 5e             	cmp    $0x5e,%edx
f010557d:	76 13                	jbe    f0105592 <vprintfmt+0x258>
					putch('?', putdat);
f010557f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105582:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105586:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f010558d:	ff 55 08             	call   *0x8(%ebp)
f0105590:	eb 0d                	jmp    f010559f <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0105592:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0105595:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105599:	89 04 24             	mov    %eax,(%esp)
f010559c:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f010559f:	83 eb 01             	sub    $0x1,%ebx
f01055a2:	83 c6 01             	add    $0x1,%esi
f01055a5:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f01055a9:	0f be c2             	movsbl %dl,%eax
f01055ac:	85 c0                	test   %eax,%eax
f01055ae:	75 23                	jne    f01055d3 <vprintfmt+0x299>
f01055b0:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01055b3:	8b 7d 08             	mov    0x8(%ebp),%edi
f01055b6:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01055b9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01055bc:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01055c0:	7f 25                	jg     f01055e7 <vprintfmt+0x2ad>
f01055c2:	e9 89 fd ff ff       	jmp    f0105350 <vprintfmt+0x16>
f01055c7:	89 7d 08             	mov    %edi,0x8(%ebp)
f01055ca:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f01055cd:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f01055d0:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01055d3:	85 ff                	test   %edi,%edi
f01055d5:	78 97                	js     f010556e <vprintfmt+0x234>
f01055d7:	83 ef 01             	sub    $0x1,%edi
f01055da:	79 92                	jns    f010556e <vprintfmt+0x234>
f01055dc:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01055df:	8b 7d 08             	mov    0x8(%ebp),%edi
f01055e2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01055e5:	eb d2                	jmp    f01055b9 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01055e7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01055eb:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01055f2:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01055f4:	83 ee 01             	sub    $0x1,%esi
f01055f7:	75 ee                	jne    f01055e7 <vprintfmt+0x2ad>
f01055f9:	e9 52 fd ff ff       	jmp    f0105350 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01055fe:	83 f9 01             	cmp    $0x1,%ecx
f0105601:	7e 19                	jle    f010561c <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f0105603:	8b 45 14             	mov    0x14(%ebp),%eax
f0105606:	8b 50 04             	mov    0x4(%eax),%edx
f0105609:	8b 00                	mov    (%eax),%eax
f010560b:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010560e:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105611:	8b 45 14             	mov    0x14(%ebp),%eax
f0105614:	8d 40 08             	lea    0x8(%eax),%eax
f0105617:	89 45 14             	mov    %eax,0x14(%ebp)
f010561a:	eb 38                	jmp    f0105654 <vprintfmt+0x31a>
	else if (lflag)
f010561c:	85 c9                	test   %ecx,%ecx
f010561e:	74 1b                	je     f010563b <vprintfmt+0x301>
		return va_arg(*ap, long);
f0105620:	8b 45 14             	mov    0x14(%ebp),%eax
f0105623:	8b 30                	mov    (%eax),%esi
f0105625:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105628:	89 f0                	mov    %esi,%eax
f010562a:	c1 f8 1f             	sar    $0x1f,%eax
f010562d:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0105630:	8b 45 14             	mov    0x14(%ebp),%eax
f0105633:	8d 40 04             	lea    0x4(%eax),%eax
f0105636:	89 45 14             	mov    %eax,0x14(%ebp)
f0105639:	eb 19                	jmp    f0105654 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f010563b:	8b 45 14             	mov    0x14(%ebp),%eax
f010563e:	8b 30                	mov    (%eax),%esi
f0105640:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105643:	89 f0                	mov    %esi,%eax
f0105645:	c1 f8 1f             	sar    $0x1f,%eax
f0105648:	89 45 dc             	mov    %eax,-0x24(%ebp)
f010564b:	8b 45 14             	mov    0x14(%ebp),%eax
f010564e:	8d 40 04             	lea    0x4(%eax),%eax
f0105651:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105654:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105657:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010565a:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f010565f:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105663:	0f 89 06 01 00 00    	jns    f010576f <vprintfmt+0x435>
				putch('-', putdat);
f0105669:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010566d:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105674:	ff d7                	call   *%edi
				num = -(long long) num;
f0105676:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105679:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010567c:	f7 da                	neg    %edx
f010567e:	83 d1 00             	adc    $0x0,%ecx
f0105681:	f7 d9                	neg    %ecx
			}
			base = 10;
f0105683:	b8 0a 00 00 00       	mov    $0xa,%eax
f0105688:	e9 e2 00 00 00       	jmp    f010576f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010568d:	83 f9 01             	cmp    $0x1,%ecx
f0105690:	7e 10                	jle    f01056a2 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f0105692:	8b 45 14             	mov    0x14(%ebp),%eax
f0105695:	8b 10                	mov    (%eax),%edx
f0105697:	8b 48 04             	mov    0x4(%eax),%ecx
f010569a:	8d 40 08             	lea    0x8(%eax),%eax
f010569d:	89 45 14             	mov    %eax,0x14(%ebp)
f01056a0:	eb 26                	jmp    f01056c8 <vprintfmt+0x38e>
	else if (lflag)
f01056a2:	85 c9                	test   %ecx,%ecx
f01056a4:	74 12                	je     f01056b8 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f01056a6:	8b 45 14             	mov    0x14(%ebp),%eax
f01056a9:	8b 10                	mov    (%eax),%edx
f01056ab:	b9 00 00 00 00       	mov    $0x0,%ecx
f01056b0:	8d 40 04             	lea    0x4(%eax),%eax
f01056b3:	89 45 14             	mov    %eax,0x14(%ebp)
f01056b6:	eb 10                	jmp    f01056c8 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f01056b8:	8b 45 14             	mov    0x14(%ebp),%eax
f01056bb:	8b 10                	mov    (%eax),%edx
f01056bd:	b9 00 00 00 00       	mov    $0x0,%ecx
f01056c2:	8d 40 04             	lea    0x4(%eax),%eax
f01056c5:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f01056c8:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f01056cd:	e9 9d 00 00 00       	jmp    f010576f <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f01056d2:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01056d6:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01056dd:	ff d7                	call   *%edi
			putch('X', putdat);
f01056df:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01056e3:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01056ea:	ff d7                	call   *%edi
			putch('X', putdat);
f01056ec:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01056f0:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01056f7:	ff d7                	call   *%edi
			break;
f01056f9:	e9 52 fc ff ff       	jmp    f0105350 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f01056fe:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105702:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105709:	ff d7                	call   *%edi
			putch('x', putdat);
f010570b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010570f:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105716:	ff d7                	call   *%edi
			num = (unsigned long long)
f0105718:	8b 45 14             	mov    0x14(%ebp),%eax
f010571b:	8b 10                	mov    (%eax),%edx
f010571d:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f0105722:	8d 40 04             	lea    0x4(%eax),%eax
f0105725:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0105728:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f010572d:	eb 40                	jmp    f010576f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010572f:	83 f9 01             	cmp    $0x1,%ecx
f0105732:	7e 10                	jle    f0105744 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f0105734:	8b 45 14             	mov    0x14(%ebp),%eax
f0105737:	8b 10                	mov    (%eax),%edx
f0105739:	8b 48 04             	mov    0x4(%eax),%ecx
f010573c:	8d 40 08             	lea    0x8(%eax),%eax
f010573f:	89 45 14             	mov    %eax,0x14(%ebp)
f0105742:	eb 26                	jmp    f010576a <vprintfmt+0x430>
	else if (lflag)
f0105744:	85 c9                	test   %ecx,%ecx
f0105746:	74 12                	je     f010575a <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f0105748:	8b 45 14             	mov    0x14(%ebp),%eax
f010574b:	8b 10                	mov    (%eax),%edx
f010574d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105752:	8d 40 04             	lea    0x4(%eax),%eax
f0105755:	89 45 14             	mov    %eax,0x14(%ebp)
f0105758:	eb 10                	jmp    f010576a <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f010575a:	8b 45 14             	mov    0x14(%ebp),%eax
f010575d:	8b 10                	mov    (%eax),%edx
f010575f:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105764:	8d 40 04             	lea    0x4(%eax),%eax
f0105767:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f010576a:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f010576f:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105773:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105777:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f010577a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010577e:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105782:	89 14 24             	mov    %edx,(%esp)
f0105785:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105789:	89 da                	mov    %ebx,%edx
f010578b:	89 f8                	mov    %edi,%eax
f010578d:	e8 6e fa ff ff       	call   f0105200 <printnum>
			break;
f0105792:	e9 b9 fb ff ff       	jmp    f0105350 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105797:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010579b:	89 14 24             	mov    %edx,(%esp)
f010579e:	ff d7                	call   *%edi
			break;
f01057a0:	e9 ab fb ff ff       	jmp    f0105350 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f01057a5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01057a9:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f01057b0:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f01057b2:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f01057b6:	0f 84 91 fb ff ff    	je     f010534d <vprintfmt+0x13>
f01057bc:	89 75 10             	mov    %esi,0x10(%ebp)
f01057bf:	89 f0                	mov    %esi,%eax
f01057c1:	83 e8 01             	sub    $0x1,%eax
f01057c4:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f01057c8:	75 f7                	jne    f01057c1 <vprintfmt+0x487>
f01057ca:	89 45 10             	mov    %eax,0x10(%ebp)
f01057cd:	e9 7e fb ff ff       	jmp    f0105350 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f01057d2:	83 c4 3c             	add    $0x3c,%esp
f01057d5:	5b                   	pop    %ebx
f01057d6:	5e                   	pop    %esi
f01057d7:	5f                   	pop    %edi
f01057d8:	5d                   	pop    %ebp
f01057d9:	c3                   	ret    

f01057da <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f01057da:	55                   	push   %ebp
f01057db:	89 e5                	mov    %esp,%ebp
f01057dd:	83 ec 28             	sub    $0x28,%esp
f01057e0:	8b 45 08             	mov    0x8(%ebp),%eax
f01057e3:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f01057e6:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01057e9:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f01057ed:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f01057f0:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f01057f7:	85 c0                	test   %eax,%eax
f01057f9:	74 30                	je     f010582b <vsnprintf+0x51>
f01057fb:	85 d2                	test   %edx,%edx
f01057fd:	7e 2c                	jle    f010582b <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f01057ff:	8b 45 14             	mov    0x14(%ebp),%eax
f0105802:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105806:	8b 45 10             	mov    0x10(%ebp),%eax
f0105809:	89 44 24 08          	mov    %eax,0x8(%esp)
f010580d:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105810:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105814:	c7 04 24 f5 52 10 f0 	movl   $0xf01052f5,(%esp)
f010581b:	e8 1a fb ff ff       	call   f010533a <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105820:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105823:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105826:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105829:	eb 05                	jmp    f0105830 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f010582b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105830:	c9                   	leave  
f0105831:	c3                   	ret    

f0105832 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105832:	55                   	push   %ebp
f0105833:	89 e5                	mov    %esp,%ebp
f0105835:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105838:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f010583b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010583f:	8b 45 10             	mov    0x10(%ebp),%eax
f0105842:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105846:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105849:	89 44 24 04          	mov    %eax,0x4(%esp)
f010584d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105850:	89 04 24             	mov    %eax,(%esp)
f0105853:	e8 82 ff ff ff       	call   f01057da <vsnprintf>
	va_end(ap);

	return rc;
}
f0105858:	c9                   	leave  
f0105859:	c3                   	ret    
f010585a:	66 90                	xchg   %ax,%ax
f010585c:	66 90                	xchg   %ax,%ax
f010585e:	66 90                	xchg   %ax,%ax

f0105860 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105860:	55                   	push   %ebp
f0105861:	89 e5                	mov    %esp,%ebp
f0105863:	57                   	push   %edi
f0105864:	56                   	push   %esi
f0105865:	53                   	push   %ebx
f0105866:	83 ec 1c             	sub    $0x1c,%esp
f0105869:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f010586c:	85 c0                	test   %eax,%eax
f010586e:	74 10                	je     f0105880 <readline+0x20>
		cprintf("%s", prompt);
f0105870:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105874:	c7 04 24 ae 6e 10 f0 	movl   $0xf0106eae,(%esp)
f010587b:	e8 59 e4 ff ff       	call   f0103cd9 <cprintf>

	i = 0;
	echoing = iscons(0);
f0105880:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105887:	e8 72 af ff ff       	call   f01007fe <iscons>
f010588c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f010588e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105893:	e8 55 af ff ff       	call   f01007ed <getchar>
f0105898:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010589a:	85 c0                	test   %eax,%eax
f010589c:	79 17                	jns    f01058b5 <readline+0x55>
			cprintf("read error: %e\n", c);
f010589e:	89 44 24 04          	mov    %eax,0x4(%esp)
f01058a2:	c7 04 24 64 81 10 f0 	movl   $0xf0108164,(%esp)
f01058a9:	e8 2b e4 ff ff       	call   f0103cd9 <cprintf>
			return NULL;
f01058ae:	b8 00 00 00 00       	mov    $0x0,%eax
f01058b3:	eb 6d                	jmp    f0105922 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f01058b5:	83 f8 7f             	cmp    $0x7f,%eax
f01058b8:	74 05                	je     f01058bf <readline+0x5f>
f01058ba:	83 f8 08             	cmp    $0x8,%eax
f01058bd:	75 19                	jne    f01058d8 <readline+0x78>
f01058bf:	85 f6                	test   %esi,%esi
f01058c1:	7e 15                	jle    f01058d8 <readline+0x78>
			if (echoing)
f01058c3:	85 ff                	test   %edi,%edi
f01058c5:	74 0c                	je     f01058d3 <readline+0x73>
				cputchar('\b');
f01058c7:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f01058ce:	e8 0a af ff ff       	call   f01007dd <cputchar>
			i--;
f01058d3:	83 ee 01             	sub    $0x1,%esi
f01058d6:	eb bb                	jmp    f0105893 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f01058d8:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f01058de:	7f 1c                	jg     f01058fc <readline+0x9c>
f01058e0:	83 fb 1f             	cmp    $0x1f,%ebx
f01058e3:	7e 17                	jle    f01058fc <readline+0x9c>
			if (echoing)
f01058e5:	85 ff                	test   %edi,%edi
f01058e7:	74 08                	je     f01058f1 <readline+0x91>
				cputchar(c);
f01058e9:	89 1c 24             	mov    %ebx,(%esp)
f01058ec:	e8 ec ae ff ff       	call   f01007dd <cputchar>
			buf[i++] = c;
f01058f1:	88 9e 80 6a 22 f0    	mov    %bl,-0xfdd9580(%esi)
f01058f7:	8d 76 01             	lea    0x1(%esi),%esi
f01058fa:	eb 97                	jmp    f0105893 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f01058fc:	83 fb 0d             	cmp    $0xd,%ebx
f01058ff:	74 05                	je     f0105906 <readline+0xa6>
f0105901:	83 fb 0a             	cmp    $0xa,%ebx
f0105904:	75 8d                	jne    f0105893 <readline+0x33>
			if (echoing)
f0105906:	85 ff                	test   %edi,%edi
f0105908:	74 0c                	je     f0105916 <readline+0xb6>
				cputchar('\n');
f010590a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105911:	e8 c7 ae ff ff       	call   f01007dd <cputchar>
			buf[i] = 0;
f0105916:	c6 86 80 6a 22 f0 00 	movb   $0x0,-0xfdd9580(%esi)
			return buf;
f010591d:	b8 80 6a 22 f0       	mov    $0xf0226a80,%eax
		}
	}
}
f0105922:	83 c4 1c             	add    $0x1c,%esp
f0105925:	5b                   	pop    %ebx
f0105926:	5e                   	pop    %esi
f0105927:	5f                   	pop    %edi
f0105928:	5d                   	pop    %ebp
f0105929:	c3                   	ret    
f010592a:	66 90                	xchg   %ax,%ax
f010592c:	66 90                	xchg   %ax,%ax
f010592e:	66 90                	xchg   %ax,%ax

f0105930 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105930:	55                   	push   %ebp
f0105931:	89 e5                	mov    %esp,%ebp
f0105933:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105936:	80 3a 00             	cmpb   $0x0,(%edx)
f0105939:	74 10                	je     f010594b <strlen+0x1b>
f010593b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105940:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105943:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105947:	75 f7                	jne    f0105940 <strlen+0x10>
f0105949:	eb 05                	jmp    f0105950 <strlen+0x20>
f010594b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105950:	5d                   	pop    %ebp
f0105951:	c3                   	ret    

f0105952 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105952:	55                   	push   %ebp
f0105953:	89 e5                	mov    %esp,%ebp
f0105955:	53                   	push   %ebx
f0105956:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105959:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010595c:	85 c9                	test   %ecx,%ecx
f010595e:	74 1c                	je     f010597c <strnlen+0x2a>
f0105960:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105963:	74 1e                	je     f0105983 <strnlen+0x31>
f0105965:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f010596a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f010596c:	39 ca                	cmp    %ecx,%edx
f010596e:	74 18                	je     f0105988 <strnlen+0x36>
f0105970:	83 c2 01             	add    $0x1,%edx
f0105973:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105978:	75 f0                	jne    f010596a <strnlen+0x18>
f010597a:	eb 0c                	jmp    f0105988 <strnlen+0x36>
f010597c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105981:	eb 05                	jmp    f0105988 <strnlen+0x36>
f0105983:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105988:	5b                   	pop    %ebx
f0105989:	5d                   	pop    %ebp
f010598a:	c3                   	ret    

f010598b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f010598b:	55                   	push   %ebp
f010598c:	89 e5                	mov    %esp,%ebp
f010598e:	53                   	push   %ebx
f010598f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105992:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105995:	89 c2                	mov    %eax,%edx
f0105997:	83 c2 01             	add    $0x1,%edx
f010599a:	83 c1 01             	add    $0x1,%ecx
f010599d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f01059a1:	88 5a ff             	mov    %bl,-0x1(%edx)
f01059a4:	84 db                	test   %bl,%bl
f01059a6:	75 ef                	jne    f0105997 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f01059a8:	5b                   	pop    %ebx
f01059a9:	5d                   	pop    %ebp
f01059aa:	c3                   	ret    

f01059ab <strcat>:

char *
strcat(char *dst, const char *src)
{
f01059ab:	55                   	push   %ebp
f01059ac:	89 e5                	mov    %esp,%ebp
f01059ae:	53                   	push   %ebx
f01059af:	83 ec 08             	sub    $0x8,%esp
f01059b2:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f01059b5:	89 1c 24             	mov    %ebx,(%esp)
f01059b8:	e8 73 ff ff ff       	call   f0105930 <strlen>
	strcpy(dst + len, src);
f01059bd:	8b 55 0c             	mov    0xc(%ebp),%edx
f01059c0:	89 54 24 04          	mov    %edx,0x4(%esp)
f01059c4:	01 d8                	add    %ebx,%eax
f01059c6:	89 04 24             	mov    %eax,(%esp)
f01059c9:	e8 bd ff ff ff       	call   f010598b <strcpy>
	return dst;
}
f01059ce:	89 d8                	mov    %ebx,%eax
f01059d0:	83 c4 08             	add    $0x8,%esp
f01059d3:	5b                   	pop    %ebx
f01059d4:	5d                   	pop    %ebp
f01059d5:	c3                   	ret    

f01059d6 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f01059d6:	55                   	push   %ebp
f01059d7:	89 e5                	mov    %esp,%ebp
f01059d9:	56                   	push   %esi
f01059da:	53                   	push   %ebx
f01059db:	8b 75 08             	mov    0x8(%ebp),%esi
f01059de:	8b 55 0c             	mov    0xc(%ebp),%edx
f01059e1:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01059e4:	85 db                	test   %ebx,%ebx
f01059e6:	74 17                	je     f01059ff <strncpy+0x29>
f01059e8:	01 f3                	add    %esi,%ebx
f01059ea:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f01059ec:	83 c1 01             	add    $0x1,%ecx
f01059ef:	0f b6 02             	movzbl (%edx),%eax
f01059f2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f01059f5:	80 3a 01             	cmpb   $0x1,(%edx)
f01059f8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f01059fb:	39 d9                	cmp    %ebx,%ecx
f01059fd:	75 ed                	jne    f01059ec <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f01059ff:	89 f0                	mov    %esi,%eax
f0105a01:	5b                   	pop    %ebx
f0105a02:	5e                   	pop    %esi
f0105a03:	5d                   	pop    %ebp
f0105a04:	c3                   	ret    

f0105a05 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105a05:	55                   	push   %ebp
f0105a06:	89 e5                	mov    %esp,%ebp
f0105a08:	57                   	push   %edi
f0105a09:	56                   	push   %esi
f0105a0a:	53                   	push   %ebx
f0105a0b:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105a0e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105a11:	8b 75 10             	mov    0x10(%ebp),%esi
f0105a14:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105a16:	85 f6                	test   %esi,%esi
f0105a18:	74 34                	je     f0105a4e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0105a1a:	83 fe 01             	cmp    $0x1,%esi
f0105a1d:	74 26                	je     f0105a45 <strlcpy+0x40>
f0105a1f:	0f b6 0b             	movzbl (%ebx),%ecx
f0105a22:	84 c9                	test   %cl,%cl
f0105a24:	74 23                	je     f0105a49 <strlcpy+0x44>
f0105a26:	83 ee 02             	sub    $0x2,%esi
f0105a29:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0105a2e:	83 c0 01             	add    $0x1,%eax
f0105a31:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105a34:	39 f2                	cmp    %esi,%edx
f0105a36:	74 13                	je     f0105a4b <strlcpy+0x46>
f0105a38:	83 c2 01             	add    $0x1,%edx
f0105a3b:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0105a3f:	84 c9                	test   %cl,%cl
f0105a41:	75 eb                	jne    f0105a2e <strlcpy+0x29>
f0105a43:	eb 06                	jmp    f0105a4b <strlcpy+0x46>
f0105a45:	89 f8                	mov    %edi,%eax
f0105a47:	eb 02                	jmp    f0105a4b <strlcpy+0x46>
f0105a49:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0105a4b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0105a4e:	29 f8                	sub    %edi,%eax
}
f0105a50:	5b                   	pop    %ebx
f0105a51:	5e                   	pop    %esi
f0105a52:	5f                   	pop    %edi
f0105a53:	5d                   	pop    %ebp
f0105a54:	c3                   	ret    

f0105a55 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105a55:	55                   	push   %ebp
f0105a56:	89 e5                	mov    %esp,%ebp
f0105a58:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0105a5b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0105a5e:	0f b6 01             	movzbl (%ecx),%eax
f0105a61:	84 c0                	test   %al,%al
f0105a63:	74 15                	je     f0105a7a <strcmp+0x25>
f0105a65:	3a 02                	cmp    (%edx),%al
f0105a67:	75 11                	jne    f0105a7a <strcmp+0x25>
		p++, q++;
f0105a69:	83 c1 01             	add    $0x1,%ecx
f0105a6c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0105a6f:	0f b6 01             	movzbl (%ecx),%eax
f0105a72:	84 c0                	test   %al,%al
f0105a74:	74 04                	je     f0105a7a <strcmp+0x25>
f0105a76:	3a 02                	cmp    (%edx),%al
f0105a78:	74 ef                	je     f0105a69 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0105a7a:	0f b6 c0             	movzbl %al,%eax
f0105a7d:	0f b6 12             	movzbl (%edx),%edx
f0105a80:	29 d0                	sub    %edx,%eax
}
f0105a82:	5d                   	pop    %ebp
f0105a83:	c3                   	ret    

f0105a84 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105a84:	55                   	push   %ebp
f0105a85:	89 e5                	mov    %esp,%ebp
f0105a87:	56                   	push   %esi
f0105a88:	53                   	push   %ebx
f0105a89:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105a8c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105a8f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105a92:	85 f6                	test   %esi,%esi
f0105a94:	74 29                	je     f0105abf <strncmp+0x3b>
f0105a96:	0f b6 03             	movzbl (%ebx),%eax
f0105a99:	84 c0                	test   %al,%al
f0105a9b:	74 30                	je     f0105acd <strncmp+0x49>
f0105a9d:	3a 02                	cmp    (%edx),%al
f0105a9f:	75 2c                	jne    f0105acd <strncmp+0x49>
f0105aa1:	8d 43 01             	lea    0x1(%ebx),%eax
f0105aa4:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105aa6:	89 c3                	mov    %eax,%ebx
f0105aa8:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0105aab:	39 f0                	cmp    %esi,%eax
f0105aad:	74 17                	je     f0105ac6 <strncmp+0x42>
f0105aaf:	0f b6 08             	movzbl (%eax),%ecx
f0105ab2:	84 c9                	test   %cl,%cl
f0105ab4:	74 17                	je     f0105acd <strncmp+0x49>
f0105ab6:	83 c0 01             	add    $0x1,%eax
f0105ab9:	3a 0a                	cmp    (%edx),%cl
f0105abb:	74 e9                	je     f0105aa6 <strncmp+0x22>
f0105abd:	eb 0e                	jmp    f0105acd <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0105abf:	b8 00 00 00 00       	mov    $0x0,%eax
f0105ac4:	eb 0f                	jmp    f0105ad5 <strncmp+0x51>
f0105ac6:	b8 00 00 00 00       	mov    $0x0,%eax
f0105acb:	eb 08                	jmp    f0105ad5 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0105acd:	0f b6 03             	movzbl (%ebx),%eax
f0105ad0:	0f b6 12             	movzbl (%edx),%edx
f0105ad3:	29 d0                	sub    %edx,%eax
}
f0105ad5:	5b                   	pop    %ebx
f0105ad6:	5e                   	pop    %esi
f0105ad7:	5d                   	pop    %ebp
f0105ad8:	c3                   	ret    

f0105ad9 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105ad9:	55                   	push   %ebp
f0105ada:	89 e5                	mov    %esp,%ebp
f0105adc:	53                   	push   %ebx
f0105add:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ae0:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105ae3:	0f b6 18             	movzbl (%eax),%ebx
f0105ae6:	84 db                	test   %bl,%bl
f0105ae8:	74 1d                	je     f0105b07 <strchr+0x2e>
f0105aea:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105aec:	38 d3                	cmp    %dl,%bl
f0105aee:	75 06                	jne    f0105af6 <strchr+0x1d>
f0105af0:	eb 1a                	jmp    f0105b0c <strchr+0x33>
f0105af2:	38 ca                	cmp    %cl,%dl
f0105af4:	74 16                	je     f0105b0c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105af6:	83 c0 01             	add    $0x1,%eax
f0105af9:	0f b6 10             	movzbl (%eax),%edx
f0105afc:	84 d2                	test   %dl,%dl
f0105afe:	75 f2                	jne    f0105af2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105b00:	b8 00 00 00 00       	mov    $0x0,%eax
f0105b05:	eb 05                	jmp    f0105b0c <strchr+0x33>
f0105b07:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105b0c:	5b                   	pop    %ebx
f0105b0d:	5d                   	pop    %ebp
f0105b0e:	c3                   	ret    

f0105b0f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0105b0f:	55                   	push   %ebp
f0105b10:	89 e5                	mov    %esp,%ebp
f0105b12:	53                   	push   %ebx
f0105b13:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b16:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105b19:	0f b6 18             	movzbl (%eax),%ebx
f0105b1c:	84 db                	test   %bl,%bl
f0105b1e:	74 16                	je     f0105b36 <strfind+0x27>
f0105b20:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105b22:	38 d3                	cmp    %dl,%bl
f0105b24:	75 06                	jne    f0105b2c <strfind+0x1d>
f0105b26:	eb 0e                	jmp    f0105b36 <strfind+0x27>
f0105b28:	38 ca                	cmp    %cl,%dl
f0105b2a:	74 0a                	je     f0105b36 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0105b2c:	83 c0 01             	add    $0x1,%eax
f0105b2f:	0f b6 10             	movzbl (%eax),%edx
f0105b32:	84 d2                	test   %dl,%dl
f0105b34:	75 f2                	jne    f0105b28 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105b36:	5b                   	pop    %ebx
f0105b37:	5d                   	pop    %ebp
f0105b38:	c3                   	ret    

f0105b39 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105b39:	55                   	push   %ebp
f0105b3a:	89 e5                	mov    %esp,%ebp
f0105b3c:	57                   	push   %edi
f0105b3d:	56                   	push   %esi
f0105b3e:	53                   	push   %ebx
f0105b3f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105b42:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105b45:	85 c9                	test   %ecx,%ecx
f0105b47:	74 36                	je     f0105b7f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105b49:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0105b4f:	75 28                	jne    f0105b79 <memset+0x40>
f0105b51:	f6 c1 03             	test   $0x3,%cl
f0105b54:	75 23                	jne    f0105b79 <memset+0x40>
		c &= 0xFF;
f0105b56:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0105b5a:	89 d3                	mov    %edx,%ebx
f0105b5c:	c1 e3 08             	shl    $0x8,%ebx
f0105b5f:	89 d6                	mov    %edx,%esi
f0105b61:	c1 e6 18             	shl    $0x18,%esi
f0105b64:	89 d0                	mov    %edx,%eax
f0105b66:	c1 e0 10             	shl    $0x10,%eax
f0105b69:	09 f0                	or     %esi,%eax
f0105b6b:	09 c2                	or     %eax,%edx
f0105b6d:	89 d0                	mov    %edx,%eax
f0105b6f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105b71:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105b74:	fc                   	cld    
f0105b75:	f3 ab                	rep stos %eax,%es:(%edi)
f0105b77:	eb 06                	jmp    f0105b7f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105b79:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105b7c:	fc                   	cld    
f0105b7d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0105b7f:	89 f8                	mov    %edi,%eax
f0105b81:	5b                   	pop    %ebx
f0105b82:	5e                   	pop    %esi
f0105b83:	5f                   	pop    %edi
f0105b84:	5d                   	pop    %ebp
f0105b85:	c3                   	ret    

f0105b86 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105b86:	55                   	push   %ebp
f0105b87:	89 e5                	mov    %esp,%ebp
f0105b89:	57                   	push   %edi
f0105b8a:	56                   	push   %esi
f0105b8b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b8e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105b91:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105b94:	39 c6                	cmp    %eax,%esi
f0105b96:	73 35                	jae    f0105bcd <memmove+0x47>
f0105b98:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0105b9b:	39 d0                	cmp    %edx,%eax
f0105b9d:	73 2e                	jae    f0105bcd <memmove+0x47>
		s += n;
		d += n;
f0105b9f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105ba2:	89 d6                	mov    %edx,%esi
f0105ba4:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105ba6:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0105bac:	75 13                	jne    f0105bc1 <memmove+0x3b>
f0105bae:	f6 c1 03             	test   $0x3,%cl
f0105bb1:	75 0e                	jne    f0105bc1 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105bb3:	83 ef 04             	sub    $0x4,%edi
f0105bb6:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105bb9:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0105bbc:	fd                   	std    
f0105bbd:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105bbf:	eb 09                	jmp    f0105bca <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105bc1:	83 ef 01             	sub    $0x1,%edi
f0105bc4:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105bc7:	fd                   	std    
f0105bc8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0105bca:	fc                   	cld    
f0105bcb:	eb 1d                	jmp    f0105bea <memmove+0x64>
f0105bcd:	89 f2                	mov    %esi,%edx
f0105bcf:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105bd1:	f6 c2 03             	test   $0x3,%dl
f0105bd4:	75 0f                	jne    f0105be5 <memmove+0x5f>
f0105bd6:	f6 c1 03             	test   $0x3,%cl
f0105bd9:	75 0a                	jne    f0105be5 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0105bdb:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0105bde:	89 c7                	mov    %eax,%edi
f0105be0:	fc                   	cld    
f0105be1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105be3:	eb 05                	jmp    f0105bea <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105be5:	89 c7                	mov    %eax,%edi
f0105be7:	fc                   	cld    
f0105be8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105bea:	5e                   	pop    %esi
f0105beb:	5f                   	pop    %edi
f0105bec:	5d                   	pop    %ebp
f0105bed:	c3                   	ret    

f0105bee <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105bee:	55                   	push   %ebp
f0105bef:	89 e5                	mov    %esp,%ebp
f0105bf1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105bf4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105bf7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105bfb:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105bfe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105c02:	8b 45 08             	mov    0x8(%ebp),%eax
f0105c05:	89 04 24             	mov    %eax,(%esp)
f0105c08:	e8 79 ff ff ff       	call   f0105b86 <memmove>
}
f0105c0d:	c9                   	leave  
f0105c0e:	c3                   	ret    

f0105c0f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105c0f:	55                   	push   %ebp
f0105c10:	89 e5                	mov    %esp,%ebp
f0105c12:	57                   	push   %edi
f0105c13:	56                   	push   %esi
f0105c14:	53                   	push   %ebx
f0105c15:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105c18:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105c1b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105c1e:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105c21:	85 c0                	test   %eax,%eax
f0105c23:	74 36                	je     f0105c5b <memcmp+0x4c>
		if (*s1 != *s2)
f0105c25:	0f b6 03             	movzbl (%ebx),%eax
f0105c28:	0f b6 0e             	movzbl (%esi),%ecx
f0105c2b:	ba 00 00 00 00       	mov    $0x0,%edx
f0105c30:	38 c8                	cmp    %cl,%al
f0105c32:	74 1c                	je     f0105c50 <memcmp+0x41>
f0105c34:	eb 10                	jmp    f0105c46 <memcmp+0x37>
f0105c36:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105c3b:	83 c2 01             	add    $0x1,%edx
f0105c3e:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0105c42:	38 c8                	cmp    %cl,%al
f0105c44:	74 0a                	je     f0105c50 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0105c46:	0f b6 c0             	movzbl %al,%eax
f0105c49:	0f b6 c9             	movzbl %cl,%ecx
f0105c4c:	29 c8                	sub    %ecx,%eax
f0105c4e:	eb 10                	jmp    f0105c60 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105c50:	39 fa                	cmp    %edi,%edx
f0105c52:	75 e2                	jne    f0105c36 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0105c54:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c59:	eb 05                	jmp    f0105c60 <memcmp+0x51>
f0105c5b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105c60:	5b                   	pop    %ebx
f0105c61:	5e                   	pop    %esi
f0105c62:	5f                   	pop    %edi
f0105c63:	5d                   	pop    %ebp
f0105c64:	c3                   	ret    

f0105c65 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0105c65:	55                   	push   %ebp
f0105c66:	89 e5                	mov    %esp,%ebp
f0105c68:	53                   	push   %ebx
f0105c69:	8b 45 08             	mov    0x8(%ebp),%eax
f0105c6c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0105c6f:	89 c2                	mov    %eax,%edx
f0105c71:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105c74:	39 d0                	cmp    %edx,%eax
f0105c76:	73 13                	jae    f0105c8b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105c78:	89 d9                	mov    %ebx,%ecx
f0105c7a:	38 18                	cmp    %bl,(%eax)
f0105c7c:	75 06                	jne    f0105c84 <memfind+0x1f>
f0105c7e:	eb 0b                	jmp    f0105c8b <memfind+0x26>
f0105c80:	38 08                	cmp    %cl,(%eax)
f0105c82:	74 07                	je     f0105c8b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105c84:	83 c0 01             	add    $0x1,%eax
f0105c87:	39 d0                	cmp    %edx,%eax
f0105c89:	75 f5                	jne    f0105c80 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0105c8b:	5b                   	pop    %ebx
f0105c8c:	5d                   	pop    %ebp
f0105c8d:	c3                   	ret    

f0105c8e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0105c8e:	55                   	push   %ebp
f0105c8f:	89 e5                	mov    %esp,%ebp
f0105c91:	57                   	push   %edi
f0105c92:	56                   	push   %esi
f0105c93:	53                   	push   %ebx
f0105c94:	8b 55 08             	mov    0x8(%ebp),%edx
f0105c97:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105c9a:	0f b6 0a             	movzbl (%edx),%ecx
f0105c9d:	80 f9 09             	cmp    $0x9,%cl
f0105ca0:	74 05                	je     f0105ca7 <strtol+0x19>
f0105ca2:	80 f9 20             	cmp    $0x20,%cl
f0105ca5:	75 10                	jne    f0105cb7 <strtol+0x29>
		s++;
f0105ca7:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105caa:	0f b6 0a             	movzbl (%edx),%ecx
f0105cad:	80 f9 09             	cmp    $0x9,%cl
f0105cb0:	74 f5                	je     f0105ca7 <strtol+0x19>
f0105cb2:	80 f9 20             	cmp    $0x20,%cl
f0105cb5:	74 f0                	je     f0105ca7 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105cb7:	80 f9 2b             	cmp    $0x2b,%cl
f0105cba:	75 0a                	jne    f0105cc6 <strtol+0x38>
		s++;
f0105cbc:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0105cbf:	bf 00 00 00 00       	mov    $0x0,%edi
f0105cc4:	eb 11                	jmp    f0105cd7 <strtol+0x49>
f0105cc6:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0105ccb:	80 f9 2d             	cmp    $0x2d,%cl
f0105cce:	75 07                	jne    f0105cd7 <strtol+0x49>
		s++, neg = 1;
f0105cd0:	83 c2 01             	add    $0x1,%edx
f0105cd3:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105cd7:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0105cdc:	75 15                	jne    f0105cf3 <strtol+0x65>
f0105cde:	80 3a 30             	cmpb   $0x30,(%edx)
f0105ce1:	75 10                	jne    f0105cf3 <strtol+0x65>
f0105ce3:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105ce7:	75 0a                	jne    f0105cf3 <strtol+0x65>
		s += 2, base = 16;
f0105ce9:	83 c2 02             	add    $0x2,%edx
f0105cec:	b8 10 00 00 00       	mov    $0x10,%eax
f0105cf1:	eb 10                	jmp    f0105d03 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105cf3:	85 c0                	test   %eax,%eax
f0105cf5:	75 0c                	jne    f0105d03 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105cf7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105cf9:	80 3a 30             	cmpb   $0x30,(%edx)
f0105cfc:	75 05                	jne    f0105d03 <strtol+0x75>
		s++, base = 8;
f0105cfe:	83 c2 01             	add    $0x1,%edx
f0105d01:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105d03:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105d08:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0105d0b:	0f b6 0a             	movzbl (%edx),%ecx
f0105d0e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0105d11:	89 f0                	mov    %esi,%eax
f0105d13:	3c 09                	cmp    $0x9,%al
f0105d15:	77 08                	ja     f0105d1f <strtol+0x91>
			dig = *s - '0';
f0105d17:	0f be c9             	movsbl %cl,%ecx
f0105d1a:	83 e9 30             	sub    $0x30,%ecx
f0105d1d:	eb 20                	jmp    f0105d3f <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0105d1f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0105d22:	89 f0                	mov    %esi,%eax
f0105d24:	3c 19                	cmp    $0x19,%al
f0105d26:	77 08                	ja     f0105d30 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0105d28:	0f be c9             	movsbl %cl,%ecx
f0105d2b:	83 e9 57             	sub    $0x57,%ecx
f0105d2e:	eb 0f                	jmp    f0105d3f <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0105d30:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0105d33:	89 f0                	mov    %esi,%eax
f0105d35:	3c 19                	cmp    $0x19,%al
f0105d37:	77 16                	ja     f0105d4f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0105d39:	0f be c9             	movsbl %cl,%ecx
f0105d3c:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0105d3f:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0105d42:	7d 0f                	jge    f0105d53 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0105d44:	83 c2 01             	add    $0x1,%edx
f0105d47:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0105d4b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0105d4d:	eb bc                	jmp    f0105d0b <strtol+0x7d>
f0105d4f:	89 d8                	mov    %ebx,%eax
f0105d51:	eb 02                	jmp    f0105d55 <strtol+0xc7>
f0105d53:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0105d55:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0105d59:	74 05                	je     f0105d60 <strtol+0xd2>
		*endptr = (char *) s;
f0105d5b:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105d5e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0105d60:	f7 d8                	neg    %eax
f0105d62:	85 ff                	test   %edi,%edi
f0105d64:	0f 44 c3             	cmove  %ebx,%eax
}
f0105d67:	5b                   	pop    %ebx
f0105d68:	5e                   	pop    %esi
f0105d69:	5f                   	pop    %edi
f0105d6a:	5d                   	pop    %ebp
f0105d6b:	c3                   	ret    

f0105d6c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f0105d6c:	fa                   	cli    

	xorw    %ax, %ax
f0105d6d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f0105d6f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105d71:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105d73:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0105d75:	0f 01 16             	lgdtl  (%esi)
f0105d78:	74 70                	je     f0105dea <mpentry_end+0x4>
	movl    %cr0, %eax
f0105d7a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f0105d7d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0105d81:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0105d84:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f0105d8a:	08 00                	or     %al,(%eax)

f0105d8c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f0105d8c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0105d90:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105d92:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105d94:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0105d96:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f0105d9a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f0105d9c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f0105d9e:	b8 00 e0 11 00       	mov    $0x11e000,%eax
	movl    %eax, %cr3
f0105da3:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0105da6:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0105da9:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f0105dae:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0105db1:	8b 25 84 6e 22 f0    	mov    0xf0226e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0105db7:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f0105dbc:	b8 29 02 10 f0       	mov    $0xf0100229,%eax
	call    *%eax
f0105dc1:	ff d0                	call   *%eax

f0105dc3 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0105dc3:	eb fe                	jmp    f0105dc3 <spin>
f0105dc5:	8d 76 00             	lea    0x0(%esi),%esi

f0105dc8 <gdt>:
	...
f0105dd0:	ff                   	(bad)  
f0105dd1:	ff 00                	incl   (%eax)
f0105dd3:	00 00                	add    %al,(%eax)
f0105dd5:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f0105ddc:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0105de0 <gdtdesc>:
f0105de0:	17                   	pop    %ss
f0105de1:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0105de6 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0105de6:	90                   	nop
f0105de7:	66 90                	xchg   %ax,%ax
f0105de9:	66 90                	xchg   %ax,%ax
f0105deb:	66 90                	xchg   %ax,%ax
f0105ded:	66 90                	xchg   %ax,%ax
f0105def:	90                   	nop

f0105df0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0105df0:	55                   	push   %ebp
f0105df1:	89 e5                	mov    %esp,%ebp
f0105df3:	56                   	push   %esi
f0105df4:	53                   	push   %ebx
f0105df5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105df8:	8b 0d 88 6e 22 f0    	mov    0xf0226e88,%ecx
f0105dfe:	89 c3                	mov    %eax,%ebx
f0105e00:	c1 eb 0c             	shr    $0xc,%ebx
f0105e03:	39 cb                	cmp    %ecx,%ebx
f0105e05:	72 20                	jb     f0105e27 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105e07:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105e0b:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0105e12:	f0 
f0105e13:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105e1a:	00 
f0105e1b:	c7 04 24 01 83 10 f0 	movl   $0xf0108301,(%esp)
f0105e22:	e8 19 a2 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105e27:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f0105e2d:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105e2f:	89 c2                	mov    %eax,%edx
f0105e31:	c1 ea 0c             	shr    $0xc,%edx
f0105e34:	39 d1                	cmp    %edx,%ecx
f0105e36:	77 20                	ja     f0105e58 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105e38:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105e3c:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0105e43:	f0 
f0105e44:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105e4b:	00 
f0105e4c:	c7 04 24 01 83 10 f0 	movl   $0xf0108301,(%esp)
f0105e53:	e8 e8 a1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105e58:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f0105e5e:	39 f3                	cmp    %esi,%ebx
f0105e60:	73 40                	jae    f0105ea2 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105e62:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105e69:	00 
f0105e6a:	c7 44 24 04 11 83 10 	movl   $0xf0108311,0x4(%esp)
f0105e71:	f0 
f0105e72:	89 1c 24             	mov    %ebx,(%esp)
f0105e75:	e8 95 fd ff ff       	call   f0105c0f <memcmp>
f0105e7a:	85 c0                	test   %eax,%eax
f0105e7c:	75 17                	jne    f0105e95 <mpsearch1+0xa5>
f0105e7e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0105e83:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0105e87:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e89:	83 c0 01             	add    $0x1,%eax
f0105e8c:	83 f8 10             	cmp    $0x10,%eax
f0105e8f:	75 f2                	jne    f0105e83 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105e91:	84 d2                	test   %dl,%dl
f0105e93:	74 14                	je     f0105ea9 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0105e95:	83 c3 10             	add    $0x10,%ebx
f0105e98:	39 f3                	cmp    %esi,%ebx
f0105e9a:	72 c6                	jb     f0105e62 <mpsearch1+0x72>
f0105e9c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105ea0:	eb 0b                	jmp    f0105ead <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0105ea2:	b8 00 00 00 00       	mov    $0x0,%eax
f0105ea7:	eb 09                	jmp    f0105eb2 <mpsearch1+0xc2>
f0105ea9:	89 d8                	mov    %ebx,%eax
f0105eab:	eb 05                	jmp    f0105eb2 <mpsearch1+0xc2>
f0105ead:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105eb2:	83 c4 10             	add    $0x10,%esp
f0105eb5:	5b                   	pop    %ebx
f0105eb6:	5e                   	pop    %esi
f0105eb7:	5d                   	pop    %ebp
f0105eb8:	c3                   	ret    

f0105eb9 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0105eb9:	55                   	push   %ebp
f0105eba:	89 e5                	mov    %esp,%ebp
f0105ebc:	57                   	push   %edi
f0105ebd:	56                   	push   %esi
f0105ebe:	53                   	push   %ebx
f0105ebf:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0105ec2:	c7 05 c0 73 22 f0 20 	movl   $0xf0227020,0xf02273c0
f0105ec9:	70 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105ecc:	83 3d 88 6e 22 f0 00 	cmpl   $0x0,0xf0226e88
f0105ed3:	75 24                	jne    f0105ef9 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105ed5:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0105edc:	00 
f0105edd:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0105ee4:	f0 
f0105ee5:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0105eec:	00 
f0105eed:	c7 04 24 01 83 10 f0 	movl   $0xf0108301,(%esp)
f0105ef4:	e8 47 a1 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0105ef9:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0105f00:	85 c0                	test   %eax,%eax
f0105f02:	74 16                	je     f0105f1a <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0105f04:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0105f07:	ba 00 04 00 00       	mov    $0x400,%edx
f0105f0c:	e8 df fe ff ff       	call   f0105df0 <mpsearch1>
f0105f11:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105f14:	85 c0                	test   %eax,%eax
f0105f16:	75 3c                	jne    f0105f54 <mp_init+0x9b>
f0105f18:	eb 20                	jmp    f0105f3a <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0105f1a:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0105f21:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0105f24:	2d 00 04 00 00       	sub    $0x400,%eax
f0105f29:	ba 00 04 00 00       	mov    $0x400,%edx
f0105f2e:	e8 bd fe ff ff       	call   f0105df0 <mpsearch1>
f0105f33:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105f36:	85 c0                	test   %eax,%eax
f0105f38:	75 1a                	jne    f0105f54 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0105f3a:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105f3f:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0105f44:	e8 a7 fe ff ff       	call   f0105df0 <mpsearch1>
f0105f49:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0105f4c:	85 c0                	test   %eax,%eax
f0105f4e:	0f 84 5f 02 00 00    	je     f01061b3 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0105f54:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105f57:	8b 70 04             	mov    0x4(%eax),%esi
f0105f5a:	85 f6                	test   %esi,%esi
f0105f5c:	74 06                	je     f0105f64 <mp_init+0xab>
f0105f5e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0105f62:	74 11                	je     f0105f75 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0105f64:	c7 04 24 74 81 10 f0 	movl   $0xf0108174,(%esp)
f0105f6b:	e8 69 dd ff ff       	call   f0103cd9 <cprintf>
f0105f70:	e9 3e 02 00 00       	jmp    f01061b3 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105f75:	89 f0                	mov    %esi,%eax
f0105f77:	c1 e8 0c             	shr    $0xc,%eax
f0105f7a:	3b 05 88 6e 22 f0    	cmp    0xf0226e88,%eax
f0105f80:	72 20                	jb     f0105fa2 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105f82:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105f86:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f0105f8d:	f0 
f0105f8e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0105f95:	00 
f0105f96:	c7 04 24 01 83 10 f0 	movl   $0xf0108301,(%esp)
f0105f9d:	e8 9e a0 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105fa2:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0105fa8:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105faf:	00 
f0105fb0:	c7 44 24 04 16 83 10 	movl   $0xf0108316,0x4(%esp)
f0105fb7:	f0 
f0105fb8:	89 1c 24             	mov    %ebx,(%esp)
f0105fbb:	e8 4f fc ff ff       	call   f0105c0f <memcmp>
f0105fc0:	85 c0                	test   %eax,%eax
f0105fc2:	74 11                	je     f0105fd5 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0105fc4:	c7 04 24 a4 81 10 f0 	movl   $0xf01081a4,(%esp)
f0105fcb:	e8 09 dd ff ff       	call   f0103cd9 <cprintf>
f0105fd0:	e9 de 01 00 00       	jmp    f01061b3 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105fd5:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0105fd9:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0105fdd:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105fe0:	85 ff                	test   %edi,%edi
f0105fe2:	7e 30                	jle    f0106014 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105fe4:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105fe9:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105fee:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0105ff5:	f0 
f0105ff6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105ff8:	83 c0 01             	add    $0x1,%eax
f0105ffb:	39 c7                	cmp    %eax,%edi
f0105ffd:	7f ef                	jg     f0105fee <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105fff:	84 d2                	test   %dl,%dl
f0106001:	74 11                	je     f0106014 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0106003:	c7 04 24 d8 81 10 f0 	movl   $0xf01081d8,(%esp)
f010600a:	e8 ca dc ff ff       	call   f0103cd9 <cprintf>
f010600f:	e9 9f 01 00 00       	jmp    f01061b3 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0106014:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0106018:	3c 04                	cmp    $0x4,%al
f010601a:	74 1e                	je     f010603a <mp_init+0x181>
f010601c:	3c 01                	cmp    $0x1,%al
f010601e:	66 90                	xchg   %ax,%ax
f0106020:	74 18                	je     f010603a <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0106022:	0f b6 c0             	movzbl %al,%eax
f0106025:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106029:	c7 04 24 fc 81 10 f0 	movl   $0xf01081fc,(%esp)
f0106030:	e8 a4 dc ff ff       	call   f0103cd9 <cprintf>
f0106035:	e9 79 01 00 00       	jmp    f01061b3 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f010603a:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f010603e:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0106042:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106044:	85 f6                	test   %esi,%esi
f0106046:	7e 19                	jle    f0106061 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106048:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f010604d:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0106052:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0106056:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106058:	83 c0 01             	add    $0x1,%eax
f010605b:	39 c6                	cmp    %eax,%esi
f010605d:	7f f3                	jg     f0106052 <mp_init+0x199>
f010605f:	eb 05                	jmp    f0106066 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106061:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0106066:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0106069:	74 11                	je     f010607c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f010606b:	c7 04 24 1c 82 10 f0 	movl   $0xf010821c,(%esp)
f0106072:	e8 62 dc ff ff       	call   f0103cd9 <cprintf>
f0106077:	e9 37 01 00 00       	jmp    f01061b3 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f010607c:	85 db                	test   %ebx,%ebx
f010607e:	0f 84 2f 01 00 00    	je     f01061b3 <mp_init+0x2fa>
		return;
	ismp = 1;
f0106084:	c7 05 00 70 22 f0 01 	movl   $0x1,0xf0227000
f010608b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f010608e:	8b 43 24             	mov    0x24(%ebx),%eax
f0106091:	a3 00 80 26 f0       	mov    %eax,0xf0268000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0106096:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0106099:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f010609e:	0f 84 94 00 00 00    	je     f0106138 <mp_init+0x27f>
f01060a4:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f01060a9:	0f b6 07             	movzbl (%edi),%eax
f01060ac:	84 c0                	test   %al,%al
f01060ae:	74 06                	je     f01060b6 <mp_init+0x1fd>
f01060b0:	3c 04                	cmp    $0x4,%al
f01060b2:	77 54                	ja     f0106108 <mp_init+0x24f>
f01060b4:	eb 4d                	jmp    f0106103 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f01060b6:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f01060ba:	74 11                	je     f01060cd <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f01060bc:	6b 05 c4 73 22 f0 74 	imul   $0x74,0xf02273c4,%eax
f01060c3:	05 20 70 22 f0       	add    $0xf0227020,%eax
f01060c8:	a3 c0 73 22 f0       	mov    %eax,0xf02273c0
			if (ncpu < NCPU) {
f01060cd:	a1 c4 73 22 f0       	mov    0xf02273c4,%eax
f01060d2:	83 f8 07             	cmp    $0x7,%eax
f01060d5:	7f 13                	jg     f01060ea <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f01060d7:	6b d0 74             	imul   $0x74,%eax,%edx
f01060da:	88 82 20 70 22 f0    	mov    %al,-0xfdd8fe0(%edx)
				ncpu++;
f01060e0:	83 c0 01             	add    $0x1,%eax
f01060e3:	a3 c4 73 22 f0       	mov    %eax,0xf02273c4
f01060e8:	eb 14                	jmp    f01060fe <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f01060ea:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f01060ee:	89 44 24 04          	mov    %eax,0x4(%esp)
f01060f2:	c7 04 24 4c 82 10 f0 	movl   $0xf010824c,(%esp)
f01060f9:	e8 db db ff ff       	call   f0103cd9 <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f01060fe:	83 c7 14             	add    $0x14,%edi
			continue;
f0106101:	eb 26                	jmp    f0106129 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0106103:	83 c7 08             	add    $0x8,%edi
			continue;
f0106106:	eb 21                	jmp    f0106129 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0106108:	0f b6 c0             	movzbl %al,%eax
f010610b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010610f:	c7 04 24 74 82 10 f0 	movl   $0xf0108274,(%esp)
f0106116:	e8 be db ff ff       	call   f0103cd9 <cprintf>
			ismp = 0;
f010611b:	c7 05 00 70 22 f0 00 	movl   $0x0,0xf0227000
f0106122:	00 00 00 
			i = conf->entry;
f0106125:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0106129:	83 c6 01             	add    $0x1,%esi
f010612c:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0106130:	39 f0                	cmp    %esi,%eax
f0106132:	0f 87 71 ff ff ff    	ja     f01060a9 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0106138:	a1 c0 73 22 f0       	mov    0xf02273c0,%eax
f010613d:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0106144:	83 3d 00 70 22 f0 00 	cmpl   $0x0,0xf0227000
f010614b:	75 22                	jne    f010616f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f010614d:	c7 05 c4 73 22 f0 01 	movl   $0x1,0xf02273c4
f0106154:	00 00 00 
		lapic = NULL;
f0106157:	c7 05 00 80 26 f0 00 	movl   $0x0,0xf0268000
f010615e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0106161:	c7 04 24 94 82 10 f0 	movl   $0xf0108294,(%esp)
f0106168:	e8 6c db ff ff       	call   f0103cd9 <cprintf>
		return;
f010616d:	eb 44                	jmp    f01061b3 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f010616f:	8b 15 c4 73 22 f0    	mov    0xf02273c4,%edx
f0106175:	89 54 24 08          	mov    %edx,0x8(%esp)
f0106179:	0f b6 00             	movzbl (%eax),%eax
f010617c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106180:	c7 04 24 1b 83 10 f0 	movl   $0xf010831b,(%esp)
f0106187:	e8 4d db ff ff       	call   f0103cd9 <cprintf>

	if (mp->imcrp) {
f010618c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010618f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106193:	74 1e                	je     f01061b3 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0106195:	c7 04 24 c0 82 10 f0 	movl   $0xf01082c0,(%esp)
f010619c:	e8 38 db ff ff       	call   f0103cd9 <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01061a1:	ba 22 00 00 00       	mov    $0x22,%edx
f01061a6:	b8 70 00 00 00       	mov    $0x70,%eax
f01061ab:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01061ac:	b2 23                	mov    $0x23,%dl
f01061ae:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f01061af:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01061b2:	ee                   	out    %al,(%dx)
	}
}
f01061b3:	83 c4 2c             	add    $0x2c,%esp
f01061b6:	5b                   	pop    %ebx
f01061b7:	5e                   	pop    %esi
f01061b8:	5f                   	pop    %edi
f01061b9:	5d                   	pop    %ebp
f01061ba:	c3                   	ret    

f01061bb <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f01061bb:	55                   	push   %ebp
f01061bc:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f01061be:	8b 0d 00 80 26 f0    	mov    0xf0268000,%ecx
f01061c4:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f01061c7:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f01061c9:	a1 00 80 26 f0       	mov    0xf0268000,%eax
f01061ce:	8b 40 20             	mov    0x20(%eax),%eax
}
f01061d1:	5d                   	pop    %ebp
f01061d2:	c3                   	ret    

f01061d3 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f01061d3:	55                   	push   %ebp
f01061d4:	89 e5                	mov    %esp,%ebp
	if (lapic)
f01061d6:	a1 00 80 26 f0       	mov    0xf0268000,%eax
f01061db:	85 c0                	test   %eax,%eax
f01061dd:	74 08                	je     f01061e7 <cpunum+0x14>
		return lapic[ID] >> 24;
f01061df:	8b 40 20             	mov    0x20(%eax),%eax
f01061e2:	c1 e8 18             	shr    $0x18,%eax
f01061e5:	eb 05                	jmp    f01061ec <cpunum+0x19>
	return 0;
f01061e7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01061ec:	5d                   	pop    %ebp
f01061ed:	c3                   	ret    

f01061ee <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f01061ee:	83 3d 00 80 26 f0 00 	cmpl   $0x0,0xf0268000
f01061f5:	0f 84 0b 01 00 00    	je     f0106306 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f01061fb:	55                   	push   %ebp
f01061fc:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f01061fe:	ba 27 01 00 00       	mov    $0x127,%edx
f0106203:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0106208:	e8 ae ff ff ff       	call   f01061bb <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f010620d:	ba 0b 00 00 00       	mov    $0xb,%edx
f0106212:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0106217:	e8 9f ff ff ff       	call   f01061bb <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f010621c:	ba 20 00 02 00       	mov    $0x20020,%edx
f0106221:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0106226:	e8 90 ff ff ff       	call   f01061bb <lapicw>
	lapicw(TICR, 10000000); 
f010622b:	ba 80 96 98 00       	mov    $0x989680,%edx
f0106230:	b8 e0 00 00 00       	mov    $0xe0,%eax
f0106235:	e8 81 ff ff ff       	call   f01061bb <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f010623a:	e8 94 ff ff ff       	call   f01061d3 <cpunum>
f010623f:	6b c0 74             	imul   $0x74,%eax,%eax
f0106242:	05 20 70 22 f0       	add    $0xf0227020,%eax
f0106247:	39 05 c0 73 22 f0    	cmp    %eax,0xf02273c0
f010624d:	74 0f                	je     f010625e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f010624f:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106254:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106259:	e8 5d ff ff ff       	call   f01061bb <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010625e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106263:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106268:	e8 4e ff ff ff       	call   f01061bb <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010626d:	a1 00 80 26 f0       	mov    0xf0268000,%eax
f0106272:	8b 40 30             	mov    0x30(%eax),%eax
f0106275:	c1 e8 10             	shr    $0x10,%eax
f0106278:	3c 03                	cmp    $0x3,%al
f010627a:	76 0f                	jbe    f010628b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010627c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106281:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106286:	e8 30 ff ff ff       	call   f01061bb <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f010628b:	ba 33 00 00 00       	mov    $0x33,%edx
f0106290:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106295:	e8 21 ff ff ff       	call   f01061bb <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010629a:	ba 00 00 00 00       	mov    $0x0,%edx
f010629f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f01062a4:	e8 12 ff ff ff       	call   f01061bb <lapicw>
	lapicw(ESR, 0);
f01062a9:	ba 00 00 00 00       	mov    $0x0,%edx
f01062ae:	b8 a0 00 00 00       	mov    $0xa0,%eax
f01062b3:	e8 03 ff ff ff       	call   f01061bb <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f01062b8:	ba 00 00 00 00       	mov    $0x0,%edx
f01062bd:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01062c2:	e8 f4 fe ff ff       	call   f01061bb <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f01062c7:	ba 00 00 00 00       	mov    $0x0,%edx
f01062cc:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01062d1:	e8 e5 fe ff ff       	call   f01061bb <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f01062d6:	ba 00 85 08 00       	mov    $0x88500,%edx
f01062db:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01062e0:	e8 d6 fe ff ff       	call   f01061bb <lapicw>
	while(lapic[ICRLO] & DELIVS)
f01062e5:	8b 15 00 80 26 f0    	mov    0xf0268000,%edx
f01062eb:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01062f1:	f6 c4 10             	test   $0x10,%ah
f01062f4:	75 f5                	jne    f01062eb <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01062f6:	ba 00 00 00 00       	mov    $0x0,%edx
f01062fb:	b8 20 00 00 00       	mov    $0x20,%eax
f0106300:	e8 b6 fe ff ff       	call   f01061bb <lapicw>
}
f0106305:	5d                   	pop    %ebp
f0106306:	f3 c3                	repz ret 

f0106308 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0106308:	83 3d 00 80 26 f0 00 	cmpl   $0x0,0xf0268000
f010630f:	74 13                	je     f0106324 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0106311:	55                   	push   %ebp
f0106312:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0106314:	ba 00 00 00 00       	mov    $0x0,%edx
f0106319:	b8 2c 00 00 00       	mov    $0x2c,%eax
f010631e:	e8 98 fe ff ff       	call   f01061bb <lapicw>
}
f0106323:	5d                   	pop    %ebp
f0106324:	f3 c3                	repz ret 

f0106326 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0106326:	55                   	push   %ebp
f0106327:	89 e5                	mov    %esp,%ebp
f0106329:	56                   	push   %esi
f010632a:	53                   	push   %ebx
f010632b:	83 ec 10             	sub    $0x10,%esp
f010632e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0106331:	8b 75 0c             	mov    0xc(%ebp),%esi
f0106334:	ba 70 00 00 00       	mov    $0x70,%edx
f0106339:	b8 0f 00 00 00       	mov    $0xf,%eax
f010633e:	ee                   	out    %al,(%dx)
f010633f:	b2 71                	mov    $0x71,%dl
f0106341:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106346:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106347:	83 3d 88 6e 22 f0 00 	cmpl   $0x0,0xf0226e88
f010634e:	75 24                	jne    f0106374 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106350:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106357:	00 
f0106358:	c7 44 24 08 04 69 10 	movl   $0xf0106904,0x8(%esp)
f010635f:	f0 
f0106360:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106367:	00 
f0106368:	c7 04 24 38 83 10 f0 	movl   $0xf0108338,(%esp)
f010636f:	e8 cc 9c ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106374:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010637b:	00 00 
	wrv[1] = addr >> 4;
f010637d:	89 f0                	mov    %esi,%eax
f010637f:	c1 e8 04             	shr    $0x4,%eax
f0106382:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106388:	c1 e3 18             	shl    $0x18,%ebx
f010638b:	89 da                	mov    %ebx,%edx
f010638d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106392:	e8 24 fe ff ff       	call   f01061bb <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106397:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010639c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01063a1:	e8 15 fe ff ff       	call   f01061bb <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f01063a6:	ba 00 85 00 00       	mov    $0x8500,%edx
f01063ab:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01063b0:	e8 06 fe ff ff       	call   f01061bb <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01063b5:	c1 ee 0c             	shr    $0xc,%esi
f01063b8:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f01063be:	89 da                	mov    %ebx,%edx
f01063c0:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01063c5:	e8 f1 fd ff ff       	call   f01061bb <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01063ca:	89 f2                	mov    %esi,%edx
f01063cc:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01063d1:	e8 e5 fd ff ff       	call   f01061bb <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f01063d6:	89 da                	mov    %ebx,%edx
f01063d8:	b8 c4 00 00 00       	mov    $0xc4,%eax
f01063dd:	e8 d9 fd ff ff       	call   f01061bb <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01063e2:	89 f2                	mov    %esi,%edx
f01063e4:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01063e9:	e8 cd fd ff ff       	call   f01061bb <lapicw>
		microdelay(200);
	}
}
f01063ee:	83 c4 10             	add    $0x10,%esp
f01063f1:	5b                   	pop    %ebx
f01063f2:	5e                   	pop    %esi
f01063f3:	5d                   	pop    %ebp
f01063f4:	c3                   	ret    

f01063f5 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f01063f5:	55                   	push   %ebp
f01063f6:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f01063f8:	8b 55 08             	mov    0x8(%ebp),%edx
f01063fb:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0106401:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106406:	e8 b0 fd ff ff       	call   f01061bb <lapicw>
	while (lapic[ICRLO] & DELIVS)
f010640b:	8b 15 00 80 26 f0    	mov    0xf0268000,%edx
f0106411:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0106417:	f6 c4 10             	test   $0x10,%ah
f010641a:	75 f5                	jne    f0106411 <lapic_ipi+0x1c>
		;
}
f010641c:	5d                   	pop    %ebp
f010641d:	c3                   	ret    

f010641e <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f010641e:	55                   	push   %ebp
f010641f:	89 e5                	mov    %esp,%ebp
f0106421:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0106424:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f010642a:	8b 55 0c             	mov    0xc(%ebp),%edx
f010642d:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f0106430:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f0106437:	5d                   	pop    %ebp
f0106438:	c3                   	ret    

f0106439 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f0106439:	55                   	push   %ebp
f010643a:	89 e5                	mov    %esp,%ebp
f010643c:	56                   	push   %esi
f010643d:	53                   	push   %ebx
f010643e:	83 ec 20             	sub    $0x20,%esp
f0106441:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106444:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106447:	74 14                	je     f010645d <spin_lock+0x24>
f0106449:	8b 73 08             	mov    0x8(%ebx),%esi
f010644c:	e8 82 fd ff ff       	call   f01061d3 <cpunum>
f0106451:	6b c0 74             	imul   $0x74,%eax,%eax
f0106454:	05 20 70 22 f0       	add    $0xf0227020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106459:	39 c6                	cmp    %eax,%esi
f010645b:	74 15                	je     f0106472 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010645d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010645f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106464:	f0 87 03             	lock xchg %eax,(%ebx)
f0106467:	b9 01 00 00 00       	mov    $0x1,%ecx
f010646c:	85 c0                	test   %eax,%eax
f010646e:	75 2e                	jne    f010649e <spin_lock+0x65>
f0106470:	eb 37                	jmp    f01064a9 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106472:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106475:	e8 59 fd ff ff       	call   f01061d3 <cpunum>
f010647a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010647e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106482:	c7 44 24 08 48 83 10 	movl   $0xf0108348,0x8(%esp)
f0106489:	f0 
f010648a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106491:	00 
f0106492:	c7 04 24 ac 83 10 f0 	movl   $0xf01083ac,(%esp)
f0106499:	e8 a2 9b ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010649e:	f3 90                	pause  
f01064a0:	89 c8                	mov    %ecx,%eax
f01064a2:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f01064a5:	85 c0                	test   %eax,%eax
f01064a7:	75 f5                	jne    f010649e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f01064a9:	e8 25 fd ff ff       	call   f01061d3 <cpunum>
f01064ae:	6b c0 74             	imul   $0x74,%eax,%eax
f01064b1:	05 20 70 22 f0       	add    $0xf0227020,%eax
f01064b6:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f01064b9:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f01064bc:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f01064be:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01064c4:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f01064ca:	76 3a                	jbe    f0106506 <spin_lock+0xcd>
f01064cc:	eb 31                	jmp    f01064ff <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f01064ce:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f01064d4:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f01064da:	77 12                	ja     f01064ee <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01064dc:	8b 5a 04             	mov    0x4(%edx),%ebx
f01064df:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01064e2:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01064e4:	83 c0 01             	add    $0x1,%eax
f01064e7:	83 f8 0a             	cmp    $0xa,%eax
f01064ea:	75 e2                	jne    f01064ce <spin_lock+0x95>
f01064ec:	eb 27                	jmp    f0106515 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f01064ee:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f01064f5:	83 c0 01             	add    $0x1,%eax
f01064f8:	83 f8 09             	cmp    $0x9,%eax
f01064fb:	7e f1                	jle    f01064ee <spin_lock+0xb5>
f01064fd:	eb 16                	jmp    f0106515 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01064ff:	b8 00 00 00 00       	mov    $0x0,%eax
f0106504:	eb e8                	jmp    f01064ee <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0106506:	8b 50 04             	mov    0x4(%eax),%edx
f0106509:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f010650c:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010650e:	b8 01 00 00 00       	mov    $0x1,%eax
f0106513:	eb b9                	jmp    f01064ce <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0106515:	83 c4 20             	add    $0x20,%esp
f0106518:	5b                   	pop    %ebx
f0106519:	5e                   	pop    %esi
f010651a:	5d                   	pop    %ebp
f010651b:	c3                   	ret    

f010651c <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f010651c:	55                   	push   %ebp
f010651d:	89 e5                	mov    %esp,%ebp
f010651f:	57                   	push   %edi
f0106520:	56                   	push   %esi
f0106521:	53                   	push   %ebx
f0106522:	83 ec 6c             	sub    $0x6c,%esp
f0106525:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106528:	83 3b 00             	cmpl   $0x0,(%ebx)
f010652b:	74 18                	je     f0106545 <spin_unlock+0x29>
f010652d:	8b 73 08             	mov    0x8(%ebx),%esi
f0106530:	e8 9e fc ff ff       	call   f01061d3 <cpunum>
f0106535:	6b c0 74             	imul   $0x74,%eax,%eax
f0106538:	05 20 70 22 f0       	add    $0xf0227020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f010653d:	39 c6                	cmp    %eax,%esi
f010653f:	0f 84 d4 00 00 00    	je     f0106619 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106545:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f010654c:	00 
f010654d:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106550:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106554:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106557:	89 04 24             	mov    %eax,(%esp)
f010655a:	e8 27 f6 ff ff       	call   f0105b86 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010655f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106562:	0f b6 30             	movzbl (%eax),%esi
f0106565:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106568:	e8 66 fc ff ff       	call   f01061d3 <cpunum>
f010656d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106571:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106575:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106579:	c7 04 24 74 83 10 f0 	movl   $0xf0108374,(%esp)
f0106580:	e8 54 d7 ff ff       	call   f0103cd9 <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106585:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106588:	85 c0                	test   %eax,%eax
f010658a:	74 71                	je     f01065fd <spin_unlock+0xe1>
f010658c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010658f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106592:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106595:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106599:	89 04 24             	mov    %eax,(%esp)
f010659c:	e8 8b e9 ff ff       	call   f0104f2c <debuginfo_eip>
f01065a1:	85 c0                	test   %eax,%eax
f01065a3:	78 39                	js     f01065de <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f01065a5:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f01065a7:	89 c2                	mov    %eax,%edx
f01065a9:	2b 55 b8             	sub    -0x48(%ebp),%edx
f01065ac:	89 54 24 18          	mov    %edx,0x18(%esp)
f01065b0:	8b 55 b0             	mov    -0x50(%ebp),%edx
f01065b3:	89 54 24 14          	mov    %edx,0x14(%esp)
f01065b7:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f01065ba:	89 54 24 10          	mov    %edx,0x10(%esp)
f01065be:	8b 55 ac             	mov    -0x54(%ebp),%edx
f01065c1:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01065c5:	8b 55 a8             	mov    -0x58(%ebp),%edx
f01065c8:	89 54 24 08          	mov    %edx,0x8(%esp)
f01065cc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01065d0:	c7 04 24 bc 83 10 f0 	movl   $0xf01083bc,(%esp)
f01065d7:	e8 fd d6 ff ff       	call   f0103cd9 <cprintf>
f01065dc:	eb 12                	jmp    f01065f0 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f01065de:	8b 03                	mov    (%ebx),%eax
f01065e0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01065e4:	c7 04 24 d3 83 10 f0 	movl   $0xf01083d3,(%esp)
f01065eb:	e8 e9 d6 ff ff       	call   f0103cd9 <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01065f0:	39 fb                	cmp    %edi,%ebx
f01065f2:	74 09                	je     f01065fd <spin_unlock+0xe1>
f01065f4:	83 c3 04             	add    $0x4,%ebx
f01065f7:	8b 03                	mov    (%ebx),%eax
f01065f9:	85 c0                	test   %eax,%eax
f01065fb:	75 98                	jne    f0106595 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f01065fd:	c7 44 24 08 db 83 10 	movl   $0xf01083db,0x8(%esp)
f0106604:	f0 
f0106605:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f010660c:	00 
f010660d:	c7 04 24 ac 83 10 f0 	movl   $0xf01083ac,(%esp)
f0106614:	e8 27 9a ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f0106619:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f0106620:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0106627:	b8 00 00 00 00       	mov    $0x0,%eax
f010662c:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f010662f:	83 c4 6c             	add    $0x6c,%esp
f0106632:	5b                   	pop    %ebx
f0106633:	5e                   	pop    %esi
f0106634:	5f                   	pop    %edi
f0106635:	5d                   	pop    %ebp
f0106636:	c3                   	ret    
f0106637:	66 90                	xchg   %ax,%ax
f0106639:	66 90                	xchg   %ax,%ax
f010663b:	66 90                	xchg   %ax,%ax
f010663d:	66 90                	xchg   %ax,%ax
f010663f:	90                   	nop

f0106640 <__udivdi3>:
f0106640:	55                   	push   %ebp
f0106641:	57                   	push   %edi
f0106642:	56                   	push   %esi
f0106643:	83 ec 0c             	sub    $0xc,%esp
f0106646:	8b 44 24 28          	mov    0x28(%esp),%eax
f010664a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010664e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106652:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106656:	85 c0                	test   %eax,%eax
f0106658:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010665c:	89 ea                	mov    %ebp,%edx
f010665e:	89 0c 24             	mov    %ecx,(%esp)
f0106661:	75 2d                	jne    f0106690 <__udivdi3+0x50>
f0106663:	39 e9                	cmp    %ebp,%ecx
f0106665:	77 61                	ja     f01066c8 <__udivdi3+0x88>
f0106667:	85 c9                	test   %ecx,%ecx
f0106669:	89 ce                	mov    %ecx,%esi
f010666b:	75 0b                	jne    f0106678 <__udivdi3+0x38>
f010666d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106672:	31 d2                	xor    %edx,%edx
f0106674:	f7 f1                	div    %ecx
f0106676:	89 c6                	mov    %eax,%esi
f0106678:	31 d2                	xor    %edx,%edx
f010667a:	89 e8                	mov    %ebp,%eax
f010667c:	f7 f6                	div    %esi
f010667e:	89 c5                	mov    %eax,%ebp
f0106680:	89 f8                	mov    %edi,%eax
f0106682:	f7 f6                	div    %esi
f0106684:	89 ea                	mov    %ebp,%edx
f0106686:	83 c4 0c             	add    $0xc,%esp
f0106689:	5e                   	pop    %esi
f010668a:	5f                   	pop    %edi
f010668b:	5d                   	pop    %ebp
f010668c:	c3                   	ret    
f010668d:	8d 76 00             	lea    0x0(%esi),%esi
f0106690:	39 e8                	cmp    %ebp,%eax
f0106692:	77 24                	ja     f01066b8 <__udivdi3+0x78>
f0106694:	0f bd e8             	bsr    %eax,%ebp
f0106697:	83 f5 1f             	xor    $0x1f,%ebp
f010669a:	75 3c                	jne    f01066d8 <__udivdi3+0x98>
f010669c:	8b 74 24 04          	mov    0x4(%esp),%esi
f01066a0:	39 34 24             	cmp    %esi,(%esp)
f01066a3:	0f 86 9f 00 00 00    	jbe    f0106748 <__udivdi3+0x108>
f01066a9:	39 d0                	cmp    %edx,%eax
f01066ab:	0f 82 97 00 00 00    	jb     f0106748 <__udivdi3+0x108>
f01066b1:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f01066b8:	31 d2                	xor    %edx,%edx
f01066ba:	31 c0                	xor    %eax,%eax
f01066bc:	83 c4 0c             	add    $0xc,%esp
f01066bf:	5e                   	pop    %esi
f01066c0:	5f                   	pop    %edi
f01066c1:	5d                   	pop    %ebp
f01066c2:	c3                   	ret    
f01066c3:	90                   	nop
f01066c4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01066c8:	89 f8                	mov    %edi,%eax
f01066ca:	f7 f1                	div    %ecx
f01066cc:	31 d2                	xor    %edx,%edx
f01066ce:	83 c4 0c             	add    $0xc,%esp
f01066d1:	5e                   	pop    %esi
f01066d2:	5f                   	pop    %edi
f01066d3:	5d                   	pop    %ebp
f01066d4:	c3                   	ret    
f01066d5:	8d 76 00             	lea    0x0(%esi),%esi
f01066d8:	89 e9                	mov    %ebp,%ecx
f01066da:	8b 3c 24             	mov    (%esp),%edi
f01066dd:	d3 e0                	shl    %cl,%eax
f01066df:	89 c6                	mov    %eax,%esi
f01066e1:	b8 20 00 00 00       	mov    $0x20,%eax
f01066e6:	29 e8                	sub    %ebp,%eax
f01066e8:	89 c1                	mov    %eax,%ecx
f01066ea:	d3 ef                	shr    %cl,%edi
f01066ec:	89 e9                	mov    %ebp,%ecx
f01066ee:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01066f2:	8b 3c 24             	mov    (%esp),%edi
f01066f5:	09 74 24 08          	or     %esi,0x8(%esp)
f01066f9:	89 d6                	mov    %edx,%esi
f01066fb:	d3 e7                	shl    %cl,%edi
f01066fd:	89 c1                	mov    %eax,%ecx
f01066ff:	89 3c 24             	mov    %edi,(%esp)
f0106702:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106706:	d3 ee                	shr    %cl,%esi
f0106708:	89 e9                	mov    %ebp,%ecx
f010670a:	d3 e2                	shl    %cl,%edx
f010670c:	89 c1                	mov    %eax,%ecx
f010670e:	d3 ef                	shr    %cl,%edi
f0106710:	09 d7                	or     %edx,%edi
f0106712:	89 f2                	mov    %esi,%edx
f0106714:	89 f8                	mov    %edi,%eax
f0106716:	f7 74 24 08          	divl   0x8(%esp)
f010671a:	89 d6                	mov    %edx,%esi
f010671c:	89 c7                	mov    %eax,%edi
f010671e:	f7 24 24             	mull   (%esp)
f0106721:	39 d6                	cmp    %edx,%esi
f0106723:	89 14 24             	mov    %edx,(%esp)
f0106726:	72 30                	jb     f0106758 <__udivdi3+0x118>
f0106728:	8b 54 24 04          	mov    0x4(%esp),%edx
f010672c:	89 e9                	mov    %ebp,%ecx
f010672e:	d3 e2                	shl    %cl,%edx
f0106730:	39 c2                	cmp    %eax,%edx
f0106732:	73 05                	jae    f0106739 <__udivdi3+0xf9>
f0106734:	3b 34 24             	cmp    (%esp),%esi
f0106737:	74 1f                	je     f0106758 <__udivdi3+0x118>
f0106739:	89 f8                	mov    %edi,%eax
f010673b:	31 d2                	xor    %edx,%edx
f010673d:	e9 7a ff ff ff       	jmp    f01066bc <__udivdi3+0x7c>
f0106742:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106748:	31 d2                	xor    %edx,%edx
f010674a:	b8 01 00 00 00       	mov    $0x1,%eax
f010674f:	e9 68 ff ff ff       	jmp    f01066bc <__udivdi3+0x7c>
f0106754:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106758:	8d 47 ff             	lea    -0x1(%edi),%eax
f010675b:	31 d2                	xor    %edx,%edx
f010675d:	83 c4 0c             	add    $0xc,%esp
f0106760:	5e                   	pop    %esi
f0106761:	5f                   	pop    %edi
f0106762:	5d                   	pop    %ebp
f0106763:	c3                   	ret    
f0106764:	66 90                	xchg   %ax,%ax
f0106766:	66 90                	xchg   %ax,%ax
f0106768:	66 90                	xchg   %ax,%ax
f010676a:	66 90                	xchg   %ax,%ax
f010676c:	66 90                	xchg   %ax,%ax
f010676e:	66 90                	xchg   %ax,%ax

f0106770 <__umoddi3>:
f0106770:	55                   	push   %ebp
f0106771:	57                   	push   %edi
f0106772:	56                   	push   %esi
f0106773:	83 ec 14             	sub    $0x14,%esp
f0106776:	8b 44 24 28          	mov    0x28(%esp),%eax
f010677a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f010677e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106782:	89 c7                	mov    %eax,%edi
f0106784:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106788:	8b 44 24 30          	mov    0x30(%esp),%eax
f010678c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106790:	89 34 24             	mov    %esi,(%esp)
f0106793:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106797:	85 c0                	test   %eax,%eax
f0106799:	89 c2                	mov    %eax,%edx
f010679b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010679f:	75 17                	jne    f01067b8 <__umoddi3+0x48>
f01067a1:	39 fe                	cmp    %edi,%esi
f01067a3:	76 4b                	jbe    f01067f0 <__umoddi3+0x80>
f01067a5:	89 c8                	mov    %ecx,%eax
f01067a7:	89 fa                	mov    %edi,%edx
f01067a9:	f7 f6                	div    %esi
f01067ab:	89 d0                	mov    %edx,%eax
f01067ad:	31 d2                	xor    %edx,%edx
f01067af:	83 c4 14             	add    $0x14,%esp
f01067b2:	5e                   	pop    %esi
f01067b3:	5f                   	pop    %edi
f01067b4:	5d                   	pop    %ebp
f01067b5:	c3                   	ret    
f01067b6:	66 90                	xchg   %ax,%ax
f01067b8:	39 f8                	cmp    %edi,%eax
f01067ba:	77 54                	ja     f0106810 <__umoddi3+0xa0>
f01067bc:	0f bd e8             	bsr    %eax,%ebp
f01067bf:	83 f5 1f             	xor    $0x1f,%ebp
f01067c2:	75 5c                	jne    f0106820 <__umoddi3+0xb0>
f01067c4:	8b 7c 24 08          	mov    0x8(%esp),%edi
f01067c8:	39 3c 24             	cmp    %edi,(%esp)
f01067cb:	0f 87 e7 00 00 00    	ja     f01068b8 <__umoddi3+0x148>
f01067d1:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01067d5:	29 f1                	sub    %esi,%ecx
f01067d7:	19 c7                	sbb    %eax,%edi
f01067d9:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01067dd:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01067e1:	8b 44 24 08          	mov    0x8(%esp),%eax
f01067e5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01067e9:	83 c4 14             	add    $0x14,%esp
f01067ec:	5e                   	pop    %esi
f01067ed:	5f                   	pop    %edi
f01067ee:	5d                   	pop    %ebp
f01067ef:	c3                   	ret    
f01067f0:	85 f6                	test   %esi,%esi
f01067f2:	89 f5                	mov    %esi,%ebp
f01067f4:	75 0b                	jne    f0106801 <__umoddi3+0x91>
f01067f6:	b8 01 00 00 00       	mov    $0x1,%eax
f01067fb:	31 d2                	xor    %edx,%edx
f01067fd:	f7 f6                	div    %esi
f01067ff:	89 c5                	mov    %eax,%ebp
f0106801:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106805:	31 d2                	xor    %edx,%edx
f0106807:	f7 f5                	div    %ebp
f0106809:	89 c8                	mov    %ecx,%eax
f010680b:	f7 f5                	div    %ebp
f010680d:	eb 9c                	jmp    f01067ab <__umoddi3+0x3b>
f010680f:	90                   	nop
f0106810:	89 c8                	mov    %ecx,%eax
f0106812:	89 fa                	mov    %edi,%edx
f0106814:	83 c4 14             	add    $0x14,%esp
f0106817:	5e                   	pop    %esi
f0106818:	5f                   	pop    %edi
f0106819:	5d                   	pop    %ebp
f010681a:	c3                   	ret    
f010681b:	90                   	nop
f010681c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106820:	8b 04 24             	mov    (%esp),%eax
f0106823:	be 20 00 00 00       	mov    $0x20,%esi
f0106828:	89 e9                	mov    %ebp,%ecx
f010682a:	29 ee                	sub    %ebp,%esi
f010682c:	d3 e2                	shl    %cl,%edx
f010682e:	89 f1                	mov    %esi,%ecx
f0106830:	d3 e8                	shr    %cl,%eax
f0106832:	89 e9                	mov    %ebp,%ecx
f0106834:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106838:	8b 04 24             	mov    (%esp),%eax
f010683b:	09 54 24 04          	or     %edx,0x4(%esp)
f010683f:	89 fa                	mov    %edi,%edx
f0106841:	d3 e0                	shl    %cl,%eax
f0106843:	89 f1                	mov    %esi,%ecx
f0106845:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106849:	8b 44 24 10          	mov    0x10(%esp),%eax
f010684d:	d3 ea                	shr    %cl,%edx
f010684f:	89 e9                	mov    %ebp,%ecx
f0106851:	d3 e7                	shl    %cl,%edi
f0106853:	89 f1                	mov    %esi,%ecx
f0106855:	d3 e8                	shr    %cl,%eax
f0106857:	89 e9                	mov    %ebp,%ecx
f0106859:	09 f8                	or     %edi,%eax
f010685b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f010685f:	f7 74 24 04          	divl   0x4(%esp)
f0106863:	d3 e7                	shl    %cl,%edi
f0106865:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106869:	89 d7                	mov    %edx,%edi
f010686b:	f7 64 24 08          	mull   0x8(%esp)
f010686f:	39 d7                	cmp    %edx,%edi
f0106871:	89 c1                	mov    %eax,%ecx
f0106873:	89 14 24             	mov    %edx,(%esp)
f0106876:	72 2c                	jb     f01068a4 <__umoddi3+0x134>
f0106878:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f010687c:	72 22                	jb     f01068a0 <__umoddi3+0x130>
f010687e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106882:	29 c8                	sub    %ecx,%eax
f0106884:	19 d7                	sbb    %edx,%edi
f0106886:	89 e9                	mov    %ebp,%ecx
f0106888:	89 fa                	mov    %edi,%edx
f010688a:	d3 e8                	shr    %cl,%eax
f010688c:	89 f1                	mov    %esi,%ecx
f010688e:	d3 e2                	shl    %cl,%edx
f0106890:	89 e9                	mov    %ebp,%ecx
f0106892:	d3 ef                	shr    %cl,%edi
f0106894:	09 d0                	or     %edx,%eax
f0106896:	89 fa                	mov    %edi,%edx
f0106898:	83 c4 14             	add    $0x14,%esp
f010689b:	5e                   	pop    %esi
f010689c:	5f                   	pop    %edi
f010689d:	5d                   	pop    %ebp
f010689e:	c3                   	ret    
f010689f:	90                   	nop
f01068a0:	39 d7                	cmp    %edx,%edi
f01068a2:	75 da                	jne    f010687e <__umoddi3+0x10e>
f01068a4:	8b 14 24             	mov    (%esp),%edx
f01068a7:	89 c1                	mov    %eax,%ecx
f01068a9:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f01068ad:	1b 54 24 04          	sbb    0x4(%esp),%edx
f01068b1:	eb cb                	jmp    f010687e <__umoddi3+0x10e>
f01068b3:	90                   	nop
f01068b4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01068b8:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f01068bc:	0f 82 0f ff ff ff    	jb     f01067d1 <__umoddi3+0x61>
f01068c2:	e9 1a ff ff ff       	jmp    f01067e1 <__umoddi3+0x71>
