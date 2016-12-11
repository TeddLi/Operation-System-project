
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
f010005f:	e8 df 5f 00 00       	call   f0106043 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 40 67 10 f0 	movl   $0xf0106740,(%esp)
f010007d:	e8 ad 40 00 00       	call   f010412f <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 6e 40 00 00       	call   f01040fc <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 12 78 10 f0 	movl   $0xf0107812,(%esp)
f0100095:	e8 95 40 00 00       	call   f010412f <cprintf>
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
f01000af:	b8 04 50 26 f0       	mov    $0xf0265004,%eax
f01000b4:	2d 88 21 22 f0       	sub    $0xf0222188,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 88 21 22 f0 	movl   $0xf0222188,(%esp)
f01000cc:	e8 d8 58 00 00       	call   f01059a9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 f9 05 00 00       	call   f01006cf <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 ac 67 10 f0 	movl   $0xf01067ac,(%esp)
f01000e5:	e8 45 40 00 00       	call   f010412f <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 a7 13 00 00       	call   f0101496 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 46 37 00 00       	call   f010383a <env_init>
	trap_init();
f01000f4:	e8 20 41 00 00       	call   f0104219 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 2b 5c 00 00       	call   f0105d29 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 59 5f 00 00       	call   f010605e <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 52 3f 00 00       	call   f010405c <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f0100111:	e8 93 61 00 00       	call   f01062a9 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100116:	83 3d 88 3e 22 f0 07 	cmpl   $0x7,0xf0223e88
f010011d:	77 24                	ja     f0100143 <i386_init+0x9b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010011f:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100126:	00 
f0100127:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 5e 00 00 	movl   $0x5e,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 c7 67 10 f0 	movl   $0xf01067c7,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 56 5c 10 f0       	mov    $0xf0105c56,%eax
f0100148:	2d dc 5b 10 f0       	sub    $0xf0105bdc,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 dc 5b 10 	movl   $0xf0105bdc,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 91 58 00 00       	call   f01059f6 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f010016c:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0100171:	3d 20 40 22 f0       	cmp    $0xf0224020,%eax
f0100176:	0f 86 a6 00 00 00    	jbe    f0100222 <i386_init+0x17a>
f010017c:	bb 20 40 22 f0       	mov    $0xf0224020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100181:	e8 bd 5e 00 00       	call   f0106043 <cpunum>
f0100186:	6b c0 74             	imul   $0x74,%eax,%eax
f0100189:	05 20 40 22 f0       	add    $0xf0224020,%eax
f010018e:	39 c3                	cmp    %eax,%ebx
f0100190:	74 39                	je     f01001cb <i386_init+0x123>
f0100192:	89 d8                	mov    %ebx,%eax
f0100194:	2d 20 40 22 f0       	sub    $0xf0224020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f0100199:	c1 f8 02             	sar    $0x2,%eax
f010019c:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001a2:	c1 e0 0f             	shl    $0xf,%eax
f01001a5:	8d 80 00 d0 22 f0    	lea    -0xfdd3000(%eax),%eax
f01001ab:	a3 84 3e 22 f0       	mov    %eax,0xf0223e84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001b0:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001b7:	00 
f01001b8:	0f b6 03             	movzbl (%ebx),%eax
f01001bb:	89 04 24             	mov    %eax,(%esp)
f01001be:	e8 d3 5f 00 00       	call   f0106196 <lapic_startap>
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
f01001ce:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f01001d5:	05 20 40 22 f0       	add    $0xf0224020,%eax
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
f01001f7:	e8 70 38 00 00       	call   f0103a6c <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
f01001fc:	83 eb 01             	sub    $0x1,%ebx
f01001ff:	75 df                	jne    f01001e0 <i386_init+0x138>
#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
#else
	// Touch all you want.
	ENV_CREATE(user_primes, ENV_TYPE_USER);
f0100201:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100208:	00 
f0100209:	c7 44 24 04 09 8a 00 	movl   $0x8a09,0x4(%esp)
f0100210:	00 
f0100211:	c7 04 24 7f 97 21 f0 	movl   $0xf021977f,(%esp)
f0100218:	e8 4f 38 00 00       	call   f0103a6c <env_create>
		ENV_CREATE(user_yield, ENV_TYPE_USER);
	*/
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f010021d:	e8 fe 47 00 00       	call   f0104a20 <sched_yield>
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
f010022f:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100234:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100239:	77 20                	ja     f010025b <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010023b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010023f:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0100246:	f0 
f0100247:	c7 44 24 04 75 00 00 	movl   $0x75,0x4(%esp)
f010024e:	00 
f010024f:	c7 04 24 c7 67 10 f0 	movl   $0xf01067c7,(%esp)
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
f0100263:	e8 db 5d 00 00       	call   f0106043 <cpunum>
f0100268:	89 44 24 04          	mov    %eax,0x4(%esp)
f010026c:	c7 04 24 d3 67 10 f0 	movl   $0xf01067d3,(%esp)
f0100273:	e8 b7 3e 00 00       	call   f010412f <cprintf>

	lapic_init();
f0100278:	e8 e1 5d 00 00       	call   f010605e <lapic_init>
	env_init_percpu();
f010027d:	e8 8e 35 00 00       	call   f0103810 <env_init_percpu>
	trap_init_percpu();
f0100282:	e8 c2 3e 00 00       	call   f0104149 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f0100287:	e8 b7 5d 00 00       	call   f0106043 <cpunum>
f010028c:	6b d0 74             	imul   $0x74,%eax,%edx
f010028f:	81 c2 20 40 22 f0    	add    $0xf0224020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0100295:	b8 01 00 00 00       	mov    $0x1,%eax
f010029a:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f010029e:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f01002a5:	e8 ff 5f 00 00       	call   f01062a9 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002aa:	e8 71 47 00 00       	call   f0104a20 <sched_yield>

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
f01002c7:	c7 04 24 e9 67 10 f0 	movl   $0xf01067e9,(%esp)
f01002ce:	e8 5c 3e 00 00       	call   f010412f <cprintf>
	vcprintf(fmt, ap);
f01002d3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002d7:	8b 45 10             	mov    0x10(%ebp),%eax
f01002da:	89 04 24             	mov    %eax,(%esp)
f01002dd:	e8 1a 3e 00 00       	call   f01040fc <vcprintf>
	cprintf("\n");
f01002e2:	c7 04 24 12 78 10 f0 	movl   $0xf0107812,(%esp)
f01002e9:	e8 41 3e 00 00       	call   f010412f <cprintf>
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
f010032b:	a1 24 32 22 f0       	mov    0xf0223224,%eax
f0100330:	8d 48 01             	lea    0x1(%eax),%ecx
f0100333:	89 0d 24 32 22 f0    	mov    %ecx,0xf0223224
f0100339:	88 90 20 30 22 f0    	mov    %dl,-0xfddcfe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010033f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100345:	75 0a                	jne    f0100351 <cons_intr+0x35>
			cons.wpos = 0;
f0100347:	c7 05 24 32 22 f0 00 	movl   $0x0,0xf0223224
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
f0100377:	83 0d 00 30 22 f0 40 	orl    $0x40,0xf0223000
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
f010038f:	8b 0d 00 30 22 f0    	mov    0xf0223000,%ecx
f0100395:	89 cb                	mov    %ecx,%ebx
f0100397:	83 e3 40             	and    $0x40,%ebx
f010039a:	83 e0 7f             	and    $0x7f,%eax
f010039d:	85 db                	test   %ebx,%ebx
f010039f:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003a2:	0f b6 d2             	movzbl %dl,%edx
f01003a5:	0f b6 82 60 69 10 f0 	movzbl -0xfef96a0(%edx),%eax
f01003ac:	83 c8 40             	or     $0x40,%eax
f01003af:	0f b6 c0             	movzbl %al,%eax
f01003b2:	f7 d0                	not    %eax
f01003b4:	21 c1                	and    %eax,%ecx
f01003b6:	89 0d 00 30 22 f0    	mov    %ecx,0xf0223000
		return 0;
f01003bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003c1:	e9 9d 00 00 00       	jmp    f0100463 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003c6:	8b 0d 00 30 22 f0    	mov    0xf0223000,%ecx
f01003cc:	f6 c1 40             	test   $0x40,%cl
f01003cf:	74 0e                	je     f01003df <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003d1:	83 c8 80             	or     $0xffffff80,%eax
f01003d4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003d6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003d9:	89 0d 00 30 22 f0    	mov    %ecx,0xf0223000
	}

	shift |= shiftcode[data];
f01003df:	0f b6 d2             	movzbl %dl,%edx
f01003e2:	0f b6 82 60 69 10 f0 	movzbl -0xfef96a0(%edx),%eax
f01003e9:	0b 05 00 30 22 f0    	or     0xf0223000,%eax
	shift ^= togglecode[data];
f01003ef:	0f b6 8a 60 68 10 f0 	movzbl -0xfef97a0(%edx),%ecx
f01003f6:	31 c8                	xor    %ecx,%eax
f01003f8:	a3 00 30 22 f0       	mov    %eax,0xf0223000

	c = charcode[shift & (CTL | SHIFT)][data];
f01003fd:	89 c1                	mov    %eax,%ecx
f01003ff:	83 e1 03             	and    $0x3,%ecx
f0100402:	8b 0c 8d 40 68 10 f0 	mov    -0xfef97c0(,%ecx,4),%ecx
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
f0100442:	c7 04 24 03 68 10 f0 	movl   $0xf0106803,(%esp)
f0100449:	e8 e1 3c 00 00       	call   f010412f <cprintf>
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
f010052c:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f0100533:	66 85 c0             	test   %ax,%ax
f0100536:	0f 84 e5 00 00 00    	je     f0100621 <cons_putc+0x1b8>
			crt_pos--;
f010053c:	83 e8 01             	sub    $0x1,%eax
f010053f:	66 a3 28 32 22 f0    	mov    %ax,0xf0223228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100545:	0f b7 c0             	movzwl %ax,%eax
f0100548:	66 81 e7 00 ff       	and    $0xff00,%di
f010054d:	83 cf 20             	or     $0x20,%edi
f0100550:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
f0100556:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010055a:	eb 78                	jmp    f01005d4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010055c:	66 83 05 28 32 22 f0 	addw   $0x50,0xf0223228
f0100563:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100564:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f010056b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100571:	c1 e8 16             	shr    $0x16,%eax
f0100574:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100577:	c1 e0 04             	shl    $0x4,%eax
f010057a:	66 a3 28 32 22 f0    	mov    %ax,0xf0223228
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
f01005b6:	0f b7 05 28 32 22 f0 	movzwl 0xf0223228,%eax
f01005bd:	8d 50 01             	lea    0x1(%eax),%edx
f01005c0:	66 89 15 28 32 22 f0 	mov    %dx,0xf0223228
f01005c7:	0f b7 c0             	movzwl %ax,%eax
f01005ca:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
f01005d0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005d4:	66 81 3d 28 32 22 f0 	cmpw   $0x7cf,0xf0223228
f01005db:	cf 07 
f01005dd:	76 42                	jbe    f0100621 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005df:	a1 2c 32 22 f0       	mov    0xf022322c,%eax
f01005e4:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f01005eb:	00 
f01005ec:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f01005f2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01005f6:	89 04 24             	mov    %eax,(%esp)
f01005f9:	e8 f8 53 00 00       	call   f01059f6 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f01005fe:	8b 15 2c 32 22 f0    	mov    0xf022322c,%edx
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
f0100619:	66 83 2d 28 32 22 f0 	subw   $0x50,0xf0223228
f0100620:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100621:	8b 0d 30 32 22 f0    	mov    0xf0223230,%ecx
f0100627:	b8 0e 00 00 00       	mov    $0xe,%eax
f010062c:	89 ca                	mov    %ecx,%edx
f010062e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010062f:	0f b7 1d 28 32 22 f0 	movzwl 0xf0223228,%ebx
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
f0100657:	83 3d 34 32 22 f0 00 	cmpl   $0x0,0xf0223234
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
f0100695:	a1 20 32 22 f0       	mov    0xf0223220,%eax
f010069a:	3b 05 24 32 22 f0    	cmp    0xf0223224,%eax
f01006a0:	74 26                	je     f01006c8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006a2:	8d 50 01             	lea    0x1(%eax),%edx
f01006a5:	89 15 20 32 22 f0    	mov    %edx,0xf0223220
f01006ab:	0f b6 88 20 30 22 f0 	movzbl -0xfddcfe0(%eax),%ecx
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
f01006bc:	c7 05 20 32 22 f0 00 	movl   $0x0,0xf0223220
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
f01006f5:	c7 05 30 32 22 f0 b4 	movl   $0x3b4,0xf0223230
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
f010070d:	c7 05 30 32 22 f0 d4 	movl   $0x3d4,0xf0223230
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
f010071c:	8b 0d 30 32 22 f0    	mov    0xf0223230,%ecx
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
f0100741:	89 3d 2c 32 22 f0    	mov    %edi,0xf022322c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100747:	0f b6 d8             	movzbl %al,%ebx
f010074a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010074c:	66 89 35 28 32 22 f0 	mov    %si,0xf0223228

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
f0100767:	e8 81 38 00 00       	call   f0103fed <irq_setmask_8259A>
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
f01007b9:	89 0d 34 32 22 f0    	mov    %ecx,0xf0223234
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
f01007c9:	c7 04 24 0f 68 10 f0 	movl   $0xf010680f,(%esp)
f01007d0:	e8 5a 39 00 00       	call   f010412f <cprintf>
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
f0100816:	c7 44 24 08 60 6a 10 	movl   $0xf0106a60,0x8(%esp)
f010081d:	f0 
f010081e:	c7 44 24 04 7e 6a 10 	movl   $0xf0106a7e,0x4(%esp)
f0100825:	f0 
f0100826:	c7 04 24 83 6a 10 f0 	movl   $0xf0106a83,(%esp)
f010082d:	e8 fd 38 00 00       	call   f010412f <cprintf>
f0100832:	c7 44 24 08 28 6b 10 	movl   $0xf0106b28,0x8(%esp)
f0100839:	f0 
f010083a:	c7 44 24 04 8c 6a 10 	movl   $0xf0106a8c,0x4(%esp)
f0100841:	f0 
f0100842:	c7 04 24 83 6a 10 f0 	movl   $0xf0106a83,(%esp)
f0100849:	e8 e1 38 00 00       	call   f010412f <cprintf>
f010084e:	c7 44 24 08 95 6a 10 	movl   $0xf0106a95,0x8(%esp)
f0100855:	f0 
f0100856:	c7 44 24 04 b3 6a 10 	movl   $0xf0106ab3,0x4(%esp)
f010085d:	f0 
f010085e:	c7 04 24 83 6a 10 f0 	movl   $0xf0106a83,(%esp)
f0100865:	e8 c5 38 00 00       	call   f010412f <cprintf>
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
f0100877:	c7 04 24 c1 6a 10 f0 	movl   $0xf0106ac1,(%esp)
f010087e:	e8 ac 38 00 00       	call   f010412f <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f0100883:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f010088a:	00 
f010088b:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f0100892:	f0 
f0100893:	c7 04 24 50 6b 10 f0 	movl   $0xf0106b50,(%esp)
f010089a:	e8 90 38 00 00       	call   f010412f <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f010089f:	c7 44 24 08 37 67 10 	movl   $0x106737,0x8(%esp)
f01008a6:	00 
f01008a7:	c7 44 24 04 37 67 10 	movl   $0xf0106737,0x4(%esp)
f01008ae:	f0 
f01008af:	c7 04 24 74 6b 10 f0 	movl   $0xf0106b74,(%esp)
f01008b6:	e8 74 38 00 00       	call   f010412f <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008bb:	c7 44 24 08 88 21 22 	movl   $0x222188,0x8(%esp)
f01008c2:	00 
f01008c3:	c7 44 24 04 88 21 22 	movl   $0xf0222188,0x4(%esp)
f01008ca:	f0 
f01008cb:	c7 04 24 98 6b 10 f0 	movl   $0xf0106b98,(%esp)
f01008d2:	e8 58 38 00 00       	call   f010412f <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008d7:	c7 44 24 08 04 50 26 	movl   $0x265004,0x8(%esp)
f01008de:	00 
f01008df:	c7 44 24 04 04 50 26 	movl   $0xf0265004,0x4(%esp)
f01008e6:	f0 
f01008e7:	c7 04 24 bc 6b 10 f0 	movl   $0xf0106bbc,(%esp)
f01008ee:	e8 3c 38 00 00       	call   f010412f <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f01008f3:	b8 03 54 26 f0       	mov    $0xf0265403,%eax
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
f010090f:	c7 04 24 e0 6b 10 f0 	movl   $0xf0106be0,(%esp)
f0100916:	e8 14 38 00 00       	call   f010412f <cprintf>
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
f010092b:	c7 04 24 da 6a 10 f0 	movl   $0xf0106ada,(%esp)
f0100932:	e8 f8 37 00 00       	call   f010412f <cprintf>
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
f010097a:	c7 04 24 0c 6c 10 f0 	movl   $0xf0106c0c,(%esp)
f0100981:	e8 a9 37 00 00       	call   f010412f <cprintf>
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
f01009a0:	c7 04 24 40 6c 10 f0 	movl   $0xf0106c40,(%esp)
f01009a7:	e8 83 37 00 00       	call   f010412f <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009ac:	c7 04 24 64 6c 10 f0 	movl   $0xf0106c64,(%esp)
f01009b3:	e8 77 37 00 00       	call   f010412f <cprintf>

	if (tf != NULL)
f01009b8:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009bc:	74 0b                	je     f01009c9 <monitor+0x32>
		print_trapframe(tf);
f01009be:	8b 45 08             	mov    0x8(%ebp),%eax
f01009c1:	89 04 24             	mov    %eax,(%esp)
f01009c4:	e8 0a 3c 00 00       	call   f01045d3 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009c9:	c7 04 24 ec 6a 10 f0 	movl   $0xf0106aec,(%esp)
f01009d0:	e8 fb 4c 00 00       	call   f01056d0 <readline>
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
f0100a01:	c7 04 24 f0 6a 10 f0 	movl   $0xf0106af0,(%esp)
f0100a08:	e8 3c 4f 00 00       	call   f0105949 <strchr>
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
f0100a23:	c7 04 24 f5 6a 10 f0 	movl   $0xf0106af5,(%esp)
f0100a2a:	e8 00 37 00 00       	call   f010412f <cprintf>
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
f0100a52:	c7 04 24 f0 6a 10 f0 	movl   $0xf0106af0,(%esp)
f0100a59:	e8 eb 4e 00 00       	call   f0105949 <strchr>
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
f0100a7c:	8b 04 85 a0 6c 10 f0 	mov    -0xfef9360(,%eax,4),%eax
f0100a83:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a87:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100a8a:	89 04 24             	mov    %eax,(%esp)
f0100a8d:	e8 33 4e 00 00       	call   f01058c5 <strcmp>
f0100a92:	85 c0                	test   %eax,%eax
f0100a94:	75 24                	jne    f0100aba <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100a96:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100a99:	8b 55 08             	mov    0x8(%ebp),%edx
f0100a9c:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100aa0:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100aa3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100aa7:	89 34 24             	mov    %esi,(%esp)
f0100aaa:	ff 14 85 a8 6c 10 f0 	call   *-0xfef9358(,%eax,4)
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
f0100ac9:	c7 04 24 12 6b 10 f0 	movl   $0xf0106b12,(%esp)
f0100ad0:	e8 5a 36 00 00       	call   f010412f <cprintf>
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
f0100af3:	53                   	push   %ebx
f0100af4:	83 ec 14             	sub    $0x14,%esp
f0100af7:	89 c3                	mov    %eax,%ebx
	cprintf("boot_alloc\r\n");
f0100af9:	c7 04 24 c4 6c 10 f0 	movl   $0xf0106cc4,(%esp)
f0100b00:	e8 2a 36 00 00       	call   f010412f <cprintf>
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b05:	83 3d 38 32 22 f0 00 	cmpl   $0x0,0xf0223238
f0100b0c:	75 0f                	jne    f0100b1d <boot_alloc+0x2d>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b0e:	b8 03 60 26 f0       	mov    $0xf0266003,%eax
f0100b13:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b18:	a3 38 32 22 f0       	mov    %eax,0xf0223238
	// Allocate a chunk large enough to hold 'n' bytes, then update
	// nextfree.  Make sure nextfree is kept aligned
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.
	result=nextfree;
f0100b1d:	a1 38 32 22 f0       	mov    0xf0223238,%eax
	nextfree+=ROUNDUP(n,PGSIZE);
f0100b22:	81 c3 ff 0f 00 00    	add    $0xfff,%ebx
f0100b28:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f0100b2e:	01 c3                	add    %eax,%ebx
f0100b30:	89 1d 38 32 22 f0    	mov    %ebx,0xf0223238
	return result;
}
f0100b36:	83 c4 14             	add    $0x14,%esp
f0100b39:	5b                   	pop    %ebx
f0100b3a:	5d                   	pop    %ebp
f0100b3b:	c3                   	ret    

f0100b3c <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100b3c:	89 d1                	mov    %edx,%ecx
f0100b3e:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100b41:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100b44:	a8 01                	test   $0x1,%al
f0100b46:	74 5d                	je     f0100ba5 <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100b48:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b4d:	89 c1                	mov    %eax,%ecx
f0100b4f:	c1 e9 0c             	shr    $0xc,%ecx
f0100b52:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0100b58:	72 26                	jb     f0100b80 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100b5a:	55                   	push   %ebp
f0100b5b:	89 e5                	mov    %esp,%ebp
f0100b5d:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b60:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100b64:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0100b6b:	f0 
f0100b6c:	c7 44 24 04 c4 03 00 	movl   $0x3c4,0x4(%esp)
f0100b73:	00 
f0100b74:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100b7b:	e8 c0 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100b80:	c1 ea 0c             	shr    $0xc,%edx
f0100b83:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100b89:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100b90:	89 c2                	mov    %eax,%edx
f0100b92:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100b95:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b9a:	85 d2                	test   %edx,%edx
f0100b9c:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100ba1:	0f 44 c2             	cmove  %edx,%eax
f0100ba4:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100ba5:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100baa:	c3                   	ret    

f0100bab <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100bab:	55                   	push   %ebp
f0100bac:	89 e5                	mov    %esp,%ebp
f0100bae:	57                   	push   %edi
f0100baf:	56                   	push   %esi
f0100bb0:	53                   	push   %ebx
f0100bb1:	83 ec 4c             	sub    $0x4c,%esp
f0100bb4:	89 c3                	mov    %eax,%ebx
	cprintf("check_page_free_list");
f0100bb6:	c7 04 24 dd 6c 10 f0 	movl   $0xf0106cdd,(%esp)
f0100bbd:	e8 6d 35 00 00       	call   f010412f <cprintf>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100bc2:	85 db                	test   %ebx,%ebx
f0100bc4:	0f 85 6a 03 00 00    	jne    f0100f34 <check_page_free_list+0x389>
f0100bca:	e9 77 03 00 00       	jmp    f0100f46 <check_page_free_list+0x39b>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100bcf:	c7 44 24 08 88 70 10 	movl   $0xf0107088,0x8(%esp)
f0100bd6:	f0 
f0100bd7:	c7 44 24 04 e7 02 00 	movl   $0x2e7,0x4(%esp)
f0100bde:	00 
f0100bdf:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100be6:	e8 55 f4 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100beb:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100bee:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100bf1:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100bf4:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100bf7:	89 c2                	mov    %eax,%edx
f0100bf9:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100bff:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c05:	0f 95 c2             	setne  %dl
f0100c08:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c0b:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c0f:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c11:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c15:	8b 00                	mov    (%eax),%eax
f0100c17:	85 c0                	test   %eax,%eax
f0100c19:	75 dc                	jne    f0100bf7 <check_page_free_list+0x4c>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c1b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c1e:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c24:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100c27:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100c2a:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100c2c:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100c2f:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100c34:	89 c3                	mov    %eax,%ebx
f0100c36:	85 c0                	test   %eax,%eax
f0100c38:	74 6c                	je     f0100ca6 <check_page_free_list+0xfb>
static void
check_page_free_list(bool only_low_memory)
{
	cprintf("check_page_free_list");
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c3a:	be 01 00 00 00       	mov    $0x1,%esi
f0100c3f:	89 d8                	mov    %ebx,%eax
f0100c41:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0100c47:	c1 f8 03             	sar    $0x3,%eax
f0100c4a:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100c4d:	89 c2                	mov    %eax,%edx
f0100c4f:	c1 ea 16             	shr    $0x16,%edx
f0100c52:	39 f2                	cmp    %esi,%edx
f0100c54:	73 4a                	jae    f0100ca0 <check_page_free_list+0xf5>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100c56:	89 c2                	mov    %eax,%edx
f0100c58:	c1 ea 0c             	shr    $0xc,%edx
f0100c5b:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0100c61:	72 20                	jb     f0100c83 <check_page_free_list+0xd8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100c63:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100c67:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0100c6e:	f0 
f0100c6f:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100c76:	00 
f0100c77:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0100c7e:	e8 bd f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100c83:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100c8a:	00 
f0100c8b:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100c92:	00 
	return (void *)(pa + KERNBASE);
f0100c93:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100c98:	89 04 24             	mov    %eax,(%esp)
f0100c9b:	e8 09 4d 00 00       	call   f01059a9 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100ca0:	8b 1b                	mov    (%ebx),%ebx
f0100ca2:	85 db                	test   %ebx,%ebx
f0100ca4:	75 99                	jne    f0100c3f <check_page_free_list+0x94>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100ca6:	b8 00 00 00 00       	mov    $0x0,%eax
f0100cab:	e8 40 fe ff ff       	call   f0100af0 <boot_alloc>
f0100cb0:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100cb3:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0100cb9:	85 d2                	test   %edx,%edx
f0100cbb:	0f 84 27 02 00 00    	je     f0100ee8 <check_page_free_list+0x33d>
		// check that we didn't corrupt the free list itself
		//cprintf("%d",pp->pp_ref);
		assert(pp >= pages);
f0100cc1:	8b 3d 90 3e 22 f0    	mov    0xf0223e90,%edi
f0100cc7:	39 fa                	cmp    %edi,%edx
f0100cc9:	72 3f                	jb     f0100d0a <check_page_free_list+0x15f>
		assert(pp < pages + npages);
f0100ccb:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0100cd0:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100cd3:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100cd6:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100cd9:	39 c2                	cmp    %eax,%edx
f0100cdb:	73 56                	jae    f0100d33 <check_page_free_list+0x188>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100cdd:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100ce0:	89 d0                	mov    %edx,%eax
f0100ce2:	29 f8                	sub    %edi,%eax
f0100ce4:	a8 07                	test   $0x7,%al
f0100ce6:	75 78                	jne    f0100d60 <check_page_free_list+0x1b5>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100ce8:	c1 f8 03             	sar    $0x3,%eax
f0100ceb:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100cee:	85 c0                	test   %eax,%eax
f0100cf0:	0f 84 98 00 00 00    	je     f0100d8e <check_page_free_list+0x1e3>
		assert(page2pa(pp) != IOPHYSMEM);
f0100cf6:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100cfb:	0f 85 dc 00 00 00    	jne    f0100ddd <check_page_free_list+0x232>
f0100d01:	e9 b3 00 00 00       	jmp    f0100db9 <check_page_free_list+0x20e>

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		//cprintf("%d",pp->pp_ref);
		assert(pp >= pages);
f0100d06:	39 d7                	cmp    %edx,%edi
f0100d08:	76 24                	jbe    f0100d2e <check_page_free_list+0x183>
f0100d0a:	c7 44 24 0c 00 6d 10 	movl   $0xf0106d00,0xc(%esp)
f0100d11:	f0 
f0100d12:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100d19:	f0 
f0100d1a:	c7 44 24 04 02 03 00 	movl   $0x302,0x4(%esp)
f0100d21:	00 
f0100d22:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100d29:	e8 12 f3 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100d2e:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100d31:	72 24                	jb     f0100d57 <check_page_free_list+0x1ac>
f0100d33:	c7 44 24 0c 21 6d 10 	movl   $0xf0106d21,0xc(%esp)
f0100d3a:	f0 
f0100d3b:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100d42:	f0 
f0100d43:	c7 44 24 04 03 03 00 	movl   $0x303,0x4(%esp)
f0100d4a:	00 
f0100d4b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100d52:	e8 e9 f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d57:	89 d0                	mov    %edx,%eax
f0100d59:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100d5c:	a8 07                	test   $0x7,%al
f0100d5e:	74 24                	je     f0100d84 <check_page_free_list+0x1d9>
f0100d60:	c7 44 24 0c ac 70 10 	movl   $0xf01070ac,0xc(%esp)
f0100d67:	f0 
f0100d68:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100d6f:	f0 
f0100d70:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
f0100d77:	00 
f0100d78:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100d7f:	e8 bc f2 ff ff       	call   f0100040 <_panic>
f0100d84:	c1 f8 03             	sar    $0x3,%eax
f0100d87:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d8a:	85 c0                	test   %eax,%eax
f0100d8c:	75 24                	jne    f0100db2 <check_page_free_list+0x207>
f0100d8e:	c7 44 24 0c 35 6d 10 	movl   $0xf0106d35,0xc(%esp)
f0100d95:	f0 
f0100d96:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100d9d:	f0 
f0100d9e:	c7 44 24 04 07 03 00 	movl   $0x307,0x4(%esp)
f0100da5:	00 
f0100da6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100dad:	e8 8e f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100db2:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100db7:	75 31                	jne    f0100dea <check_page_free_list+0x23f>
f0100db9:	c7 44 24 0c 46 6d 10 	movl   $0xf0106d46,0xc(%esp)
f0100dc0:	f0 
f0100dc1:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100dc8:	f0 
f0100dc9:	c7 44 24 04 08 03 00 	movl   $0x308,0x4(%esp)
f0100dd0:	00 
f0100dd1:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100dd8:	e8 63 f2 ff ff       	call   f0100040 <_panic>
check_page_free_list(bool only_low_memory)
{
	cprintf("check_page_free_list");
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100ddd:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100de2:	be 00 00 00 00       	mov    $0x0,%esi
f0100de7:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100dea:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100def:	75 24                	jne    f0100e15 <check_page_free_list+0x26a>
f0100df1:	c7 44 24 0c e0 70 10 	movl   $0xf01070e0,0xc(%esp)
f0100df8:	f0 
f0100df9:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100e00:	f0 
f0100e01:	c7 44 24 04 09 03 00 	movl   $0x309,0x4(%esp)
f0100e08:	00 
f0100e09:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100e10:	e8 2b f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e15:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e1a:	75 24                	jne    f0100e40 <check_page_free_list+0x295>
f0100e1c:	c7 44 24 0c 5f 6d 10 	movl   $0xf0106d5f,0xc(%esp)
f0100e23:	f0 
f0100e24:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100e2b:	f0 
f0100e2c:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f0100e33:	00 
f0100e34:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100e3b:	e8 00 f2 ff ff       	call   f0100040 <_panic>
f0100e40:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100e42:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100e47:	0f 86 08 01 00 00    	jbe    f0100f55 <check_page_free_list+0x3aa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100e4d:	89 c3                	mov    %eax,%ebx
f0100e4f:	c1 eb 0c             	shr    $0xc,%ebx
f0100e52:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100e55:	77 20                	ja     f0100e77 <check_page_free_list+0x2cc>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100e57:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100e5b:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0100e62:	f0 
f0100e63:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100e6a:	00 
f0100e6b:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0100e72:	e8 c9 f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100e77:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100e7d:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100e80:	0f 86 df 00 00 00    	jbe    f0100f65 <check_page_free_list+0x3ba>
f0100e86:	c7 44 24 0c 04 71 10 	movl   $0xf0107104,0xc(%esp)
f0100e8d:	f0 
f0100e8e:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100e95:	f0 
f0100e96:	c7 44 24 04 0b 03 00 	movl   $0x30b,0x4(%esp)
f0100e9d:	00 
f0100e9e:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100ea5:	e8 96 f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100eaa:	c7 44 24 0c 79 6d 10 	movl   $0xf0106d79,0xc(%esp)
f0100eb1:	f0 
f0100eb2:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100eb9:	f0 
f0100eba:	c7 44 24 04 0d 03 00 	movl   $0x30d,0x4(%esp)
f0100ec1:	00 
f0100ec2:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100ec9:	e8 72 f1 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100ece:	83 c6 01             	add    $0x1,%esi
f0100ed1:	eb 04                	jmp    f0100ed7 <check_page_free_list+0x32c>
		else
			++nfree_extmem;
f0100ed3:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100ed7:	8b 12                	mov    (%edx),%edx
f0100ed9:	85 d2                	test   %edx,%edx
f0100edb:	0f 85 25 fe ff ff    	jne    f0100d06 <check_page_free_list+0x15b>
f0100ee1:	8b 5d cc             	mov    -0x34(%ebp),%ebx
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100ee4:	85 f6                	test   %esi,%esi
f0100ee6:	7f 24                	jg     f0100f0c <check_page_free_list+0x361>
f0100ee8:	c7 44 24 0c 96 6d 10 	movl   $0xf0106d96,0xc(%esp)
f0100eef:	f0 
f0100ef0:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100ef7:	f0 
f0100ef8:	c7 44 24 04 15 03 00 	movl   $0x315,0x4(%esp)
f0100eff:	00 
f0100f00:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100f07:	e8 34 f1 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f0c:	85 db                	test   %ebx,%ebx
f0100f0e:	7f 75                	jg     f0100f85 <check_page_free_list+0x3da>
f0100f10:	c7 44 24 0c a8 6d 10 	movl   $0xf0106da8,0xc(%esp)
f0100f17:	f0 
f0100f18:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0100f1f:	f0 
f0100f20:	c7 44 24 04 16 03 00 	movl   $0x316,0x4(%esp)
f0100f27:	00 
f0100f28:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0100f2f:	e8 0c f1 ff ff       	call   f0100040 <_panic>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100f34:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0100f39:	85 c0                	test   %eax,%eax
f0100f3b:	0f 85 aa fc ff ff    	jne    f0100beb <check_page_free_list+0x40>
f0100f41:	e9 89 fc ff ff       	jmp    f0100bcf <check_page_free_list+0x24>
f0100f46:	83 3d 40 32 22 f0 00 	cmpl   $0x0,0xf0223240
f0100f4d:	75 26                	jne    f0100f75 <check_page_free_list+0x3ca>
f0100f4f:	90                   	nop
f0100f50:	e9 7a fc ff ff       	jmp    f0100bcf <check_page_free_list+0x24>
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f55:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100f5a:	0f 85 6e ff ff ff    	jne    f0100ece <check_page_free_list+0x323>
f0100f60:	e9 45 ff ff ff       	jmp    f0100eaa <check_page_free_list+0x2ff>
f0100f65:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100f6a:	0f 85 63 ff ff ff    	jne    f0100ed3 <check_page_free_list+0x328>
f0100f70:	e9 35 ff ff ff       	jmp    f0100eaa <check_page_free_list+0x2ff>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100f75:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
static void
check_page_free_list(bool only_low_memory)
{
	cprintf("check_page_free_list");
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100f7b:	be 00 04 00 00       	mov    $0x400,%esi
f0100f80:	e9 ba fc ff ff       	jmp    f0100c3f <check_page_free_list+0x94>
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
}
f0100f85:	83 c4 4c             	add    $0x4c,%esp
f0100f88:	5b                   	pop    %ebx
f0100f89:	5e                   	pop    %esi
f0100f8a:	5f                   	pop    %edi
f0100f8b:	5d                   	pop    %ebp
f0100f8c:	c3                   	ret    

f0100f8d <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0100f8d:	55                   	push   %ebp
f0100f8e:	89 e5                	mov    %esp,%ebp
f0100f90:	56                   	push   %esi
f0100f91:	53                   	push   %ebx
f0100f92:	83 ec 10             	sub    $0x10,%esp
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100f95:	83 3d 88 3e 22 f0 07 	cmpl   $0x7,0xf0223e88
f0100f9c:	77 1c                	ja     f0100fba <page_init+0x2d>
		panic("pa2page called with invalid pa");
f0100f9e:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0100fa5:	f0 
f0100fa6:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0100fad:	00 
f0100fae:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0100fb5:	e8 86 f0 ff ff       	call   f0100040 <_panic>
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
f0100fba:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0100fbf:	8d 70 38             	lea    0x38(%eax),%esi
	for (i; i < npages_basemem; i++) {
f0100fc2:	83 3d 44 32 22 f0 01 	cmpl   $0x1,0xf0223244
f0100fc9:	76 4b                	jbe    f0101016 <page_init+0x89>
	//     page tables and other data structures?
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
f0100fcb:	bb 01 00 00 00       	mov    $0x1,%ebx
f0100fd0:	8d 14 dd 00 00 00 00 	lea    0x0(,%ebx,8),%edx
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
		if(pages + i == page_mpentry) 
f0100fd7:	89 d0                	mov    %edx,%eax
f0100fd9:	03 05 90 3e 22 f0    	add    0xf0223e90,%eax
f0100fdf:	39 f0                	cmp    %esi,%eax
f0100fe1:	75 0e                	jne    f0100ff1 <page_init+0x64>
		{
			cprintf("MPENTRY detected!\n");
f0100fe3:	c7 04 24 b9 6d 10 f0 	movl   $0xf0106db9,(%esp)
f0100fea:	e8 40 31 00 00       	call   f010412f <cprintf>
			continue;
f0100fef:	eb 1a                	jmp    f010100b <page_init+0x7e>
		}
		pages[i].pp_ref = 0;
f0100ff1:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
		pages[i].pp_link = page_free_list;
f0100ff7:	8b 0d 40 32 22 f0    	mov    0xf0223240,%ecx
f0100ffd:	89 08                	mov    %ecx,(%eax)
		page_free_list = &pages[i];
f0100fff:	03 15 90 3e 22 f0    	add    0xf0223e90,%edx
f0101005:	89 15 40 32 22 f0    	mov    %edx,0xf0223240
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
f010100b:	83 c3 01             	add    $0x1,%ebx
f010100e:	39 1d 44 32 22 f0    	cmp    %ebx,0xf0223244
f0101014:	77 ba                	ja     f0100fd0 <page_init+0x43>
		page_free_list = &pages[i];
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f0101016:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f010101c:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0101021:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f0101028:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f010102d:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101033:	85 c0                	test   %eax,%eax
f0101035:	0f 48 c2             	cmovs  %edx,%eax
f0101038:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f010103b:	89 c2                	mov    %eax,%edx
f010103d:	39 c1                	cmp    %eax,%ecx
f010103f:	76 39                	jbe    f010107a <page_init+0xed>
f0101041:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f0101047:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f010104a:	89 c1                	mov    %eax,%ecx
f010104c:	03 0d 90 3e 22 f0    	add    0xf0223e90,%ecx
f0101052:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f0101058:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f010105a:	89 c1                	mov    %eax,%ecx
f010105c:	03 0d 90 3e 22 f0    	add    0xf0223e90,%ecx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f0101062:	83 c2 01             	add    $0x1,%edx
f0101065:	83 c0 08             	add    $0x8,%eax
f0101068:	39 15 88 3e 22 f0    	cmp    %edx,0xf0223e88
f010106e:	76 04                	jbe    f0101074 <page_init+0xe7>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f0101070:	89 cb                	mov    %ecx,%ebx
f0101072:	eb d6                	jmp    f010104a <page_init+0xbd>
f0101074:	89 0d 40 32 22 f0    	mov    %ecx,0xf0223240
	}

}
f010107a:	83 c4 10             	add    $0x10,%esp
f010107d:	5b                   	pop    %ebx
f010107e:	5e                   	pop    %esi
f010107f:	5d                   	pop    %ebp
f0101080:	c3                   	ret    

f0101081 <page_alloc>:
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0101081:	55                   	push   %ebp
f0101082:	89 e5                	mov    %esp,%ebp
f0101084:	53                   	push   %ebx
f0101085:	83 ec 14             	sub    $0x14,%esp
	//cprintf("page_alloc\r\n");
	if(page_free_list==NULL)
f0101088:	8b 1d 40 32 22 f0    	mov    0xf0223240,%ebx
f010108e:	85 db                	test   %ebx,%ebx
f0101090:	74 69                	je     f01010fb <page_alloc+0x7a>
	{
		return NULL;
	}
	struct Page* result=page_free_list;
	page_free_list=page_free_list->pp_link;
f0101092:	8b 03                	mov    (%ebx),%eax
f0101094:	a3 40 32 22 f0       	mov    %eax,0xf0223240
	if(alloc_flags & ALLOC_ZERO)
	{
	memset(page2kva(result),0,PGSIZE);
	}
	return result;
f0101099:	89 d8                	mov    %ebx,%eax
	{
		return NULL;
	}
	struct Page* result=page_free_list;
	page_free_list=page_free_list->pp_link;
	if(alloc_flags & ALLOC_ZERO)
f010109b:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f010109f:	74 5f                	je     f0101100 <page_alloc+0x7f>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01010a1:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01010a7:	c1 f8 03             	sar    $0x3,%eax
f01010aa:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01010ad:	89 c2                	mov    %eax,%edx
f01010af:	c1 ea 0c             	shr    $0xc,%edx
f01010b2:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01010b8:	72 20                	jb     f01010da <page_alloc+0x59>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01010ba:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01010be:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01010c5:	f0 
f01010c6:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01010cd:	00 
f01010ce:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01010d5:	e8 66 ef ff ff       	call   f0100040 <_panic>
	{
	memset(page2kva(result),0,PGSIZE);
f01010da:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01010e1:	00 
f01010e2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01010e9:	00 
	return (void *)(pa + KERNBASE);
f01010ea:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01010ef:	89 04 24             	mov    %eax,(%esp)
f01010f2:	e8 b2 48 00 00       	call   f01059a9 <memset>
	}
	return result;
f01010f7:	89 d8                	mov    %ebx,%eax
f01010f9:	eb 05                	jmp    f0101100 <page_alloc+0x7f>
page_alloc(int alloc_flags)
{
	//cprintf("page_alloc\r\n");
	if(page_free_list==NULL)
	{
		return NULL;
f01010fb:	b8 00 00 00 00       	mov    $0x0,%eax
	if(alloc_flags & ALLOC_ZERO)
	{
	memset(page2kva(result),0,PGSIZE);
	}
	return result;
}
f0101100:	83 c4 14             	add    $0x14,%esp
f0101103:	5b                   	pop    %ebx
f0101104:	5d                   	pop    %ebp
f0101105:	c3                   	ret    

f0101106 <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f0101106:	55                   	push   %ebp
f0101107:	89 e5                	mov    %esp,%ebp
f0101109:	8b 45 08             	mov    0x8(%ebp),%eax
	//cprintf("page_frees\r\n");
	pp->pp_ref=0;
f010110c:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
	pp->pp_link=page_free_list;
f0101112:	8b 15 40 32 22 f0    	mov    0xf0223240,%edx
f0101118:	89 10                	mov    %edx,(%eax)
	page_free_list=pp;
f010111a:	a3 40 32 22 f0       	mov    %eax,0xf0223240
}
f010111f:	5d                   	pop    %ebp
f0101120:	c3                   	ret    

f0101121 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f0101121:	55                   	push   %ebp
f0101122:	89 e5                	mov    %esp,%ebp
f0101124:	83 ec 04             	sub    $0x4,%esp
f0101127:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f010112a:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f010112e:	8d 51 ff             	lea    -0x1(%ecx),%edx
f0101131:	66 89 50 04          	mov    %dx,0x4(%eax)
f0101135:	66 85 d2             	test   %dx,%dx
f0101138:	75 08                	jne    f0101142 <page_decref+0x21>
		page_free(pp);
f010113a:	89 04 24             	mov    %eax,(%esp)
f010113d:	e8 c4 ff ff ff       	call   f0101106 <page_free>
}
f0101142:	c9                   	leave  
f0101143:	c3                   	ret    

f0101144 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f0101144:	55                   	push   %ebp
f0101145:	89 e5                	mov    %esp,%ebp
f0101147:	56                   	push   %esi
f0101148:	53                   	push   %ebx
f0101149:	83 ec 10             	sub    $0x10,%esp
f010114c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	//cprintf("pgdir_walk\r\n");
	// Fill this function in
	pte_t* result=NULL;
	if(pgdir[PDX(va)]==(pte_t)NULL)
f010114f:	89 de                	mov    %ebx,%esi
f0101151:	c1 ee 16             	shr    $0x16,%esi
f0101154:	c1 e6 02             	shl    $0x2,%esi
f0101157:	03 75 08             	add    0x8(%ebp),%esi
f010115a:	8b 06                	mov    (%esi),%eax
f010115c:	85 c0                	test   %eax,%eax
f010115e:	75 76                	jne    f01011d6 <pgdir_walk+0x92>
	{
		if(create==0)
f0101160:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0101164:	0f 84 d1 00 00 00    	je     f010123b <pgdir_walk+0xf7>
		{
			return NULL;
		}
		else
		{
			struct Page* page=page_alloc(1);
f010116a:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101171:	e8 0b ff ff ff       	call   f0101081 <page_alloc>
			if(page==NULL)
f0101176:	85 c0                	test   %eax,%eax
f0101178:	0f 84 c4 00 00 00    	je     f0101242 <pgdir_walk+0xfe>
			{
				return NULL;
			}
			page->pp_ref++;
f010117e:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101183:	89 c2                	mov    %eax,%edx
f0101185:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f010118b:	c1 fa 03             	sar    $0x3,%edx
f010118e:	c1 e2 0c             	shl    $0xc,%edx
			pgdir[PDX(va)]=page2pa(page)|PTE_P|PTE_W|PTE_U;
f0101191:	83 ca 07             	or     $0x7,%edx
f0101194:	89 16                	mov    %edx,(%esi)
f0101196:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f010119c:	c1 f8 03             	sar    $0x3,%eax
f010119f:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011a2:	89 c2                	mov    %eax,%edx
f01011a4:	c1 ea 0c             	shr    $0xc,%edx
f01011a7:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01011ad:	72 20                	jb     f01011cf <pgdir_walk+0x8b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01011af:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01011b3:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01011ba:	f0 
f01011bb:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01011c2:	00 
f01011c3:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01011ca:	e8 71 ee ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01011cf:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01011d4:	eb 58                	jmp    f010122e <pgdir_walk+0xea>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011d6:	c1 e8 0c             	shr    $0xc,%eax
f01011d9:	8b 15 88 3e 22 f0    	mov    0xf0223e88,%edx
f01011df:	39 d0                	cmp    %edx,%eax
f01011e1:	72 1c                	jb     f01011ff <pgdir_walk+0xbb>
		panic("pa2page called with invalid pa");
f01011e3:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f01011ea:	f0 
f01011eb:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01011f2:	00 
f01011f3:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01011fa:	e8 41 ee ff ff       	call   f0100040 <_panic>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01011ff:	89 c1                	mov    %eax,%ecx
f0101201:	c1 e1 0c             	shl    $0xc,%ecx
f0101204:	39 d0                	cmp    %edx,%eax
f0101206:	72 20                	jb     f0101228 <pgdir_walk+0xe4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101208:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010120c:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0101213:	f0 
f0101214:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010121b:	00 
f010121c:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0101223:	e8 18 ee ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0101228:	8d 81 00 00 00 f0    	lea    -0x10000000(%ecx),%eax
	else
	{
		//cprintf("%u ",PGNUM(PTE_ADDR(pgdir[PDX(va)])));
		result=page2kva(pa2page(PTE_ADDR(pgdir[PDX(va)])));
	}
	pte_t* r=&result[PTX(va)];
f010122e:	c1 eb 0a             	shr    $0xa,%ebx
f0101231:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
	pte_t pte=*r;

	return r;
f0101237:	01 d8                	add    %ebx,%eax
f0101239:	eb 0c                	jmp    f0101247 <pgdir_walk+0x103>
	pte_t* result=NULL;
	if(pgdir[PDX(va)]==(pte_t)NULL)
	{
		if(create==0)
		{
			return NULL;
f010123b:	b8 00 00 00 00       	mov    $0x0,%eax
f0101240:	eb 05                	jmp    f0101247 <pgdir_walk+0x103>
		else
		{
			struct Page* page=page_alloc(1);
			if(page==NULL)
			{
				return NULL;
f0101242:	b8 00 00 00 00       	mov    $0x0,%eax
	pte_t pte=*r;

	return r;


}
f0101247:	83 c4 10             	add    $0x10,%esp
f010124a:	5b                   	pop    %ebx
f010124b:	5e                   	pop    %esi
f010124c:	5d                   	pop    %ebp
f010124d:	c3                   	ret    

f010124e <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f010124e:	55                   	push   %ebp
f010124f:	89 e5                	mov    %esp,%ebp
f0101251:	57                   	push   %edi
f0101252:	56                   	push   %esi
f0101253:	53                   	push   %ebx
f0101254:	83 ec 2c             	sub    $0x2c,%esp
f0101257:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010125a:	89 d7                	mov    %edx,%edi
f010125c:	89 cb                	mov    %ecx,%ebx
	cprintf("boot_map_region\r\n");
f010125e:	c7 04 24 cc 6d 10 f0 	movl   $0xf0106dcc,(%esp)
f0101265:	e8 c5 2e 00 00       	call   f010412f <cprintf>
	int i=0;
	for(;i<size/PGSIZE;i++)
f010126a:	89 d9                	mov    %ebx,%ecx
f010126c:	c1 e9 0c             	shr    $0xc,%ecx
f010126f:	85 c9                	test   %ecx,%ecx
f0101271:	74 5d                	je     f01012d0 <boot_map_region+0x82>
f0101273:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0101276:	89 fb                	mov    %edi,%ebx
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	cprintf("boot_map_region\r\n");
	int i=0;
f0101278:	be 00 00 00 00       	mov    $0x0,%esi
			struct Page* page=page_alloc(1);
			*pte=page2pa(page);

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
f010127d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101280:	83 c8 01             	or     $0x1,%eax
f0101283:	89 45 dc             	mov    %eax,-0x24(%ebp)
f0101286:	8b 45 08             	mov    0x8(%ebp),%eax
f0101289:	29 f8                	sub    %edi,%eax
f010128b:	89 45 d8             	mov    %eax,-0x28(%ebp)
{
	cprintf("boot_map_region\r\n");
	int i=0;
	for(;i<size/PGSIZE;i++)
	{
		pte_t* pte=pgdir_walk(pgdir,(void*)(va+i*PGSIZE),1);
f010128e:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101295:	00 
f0101296:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010129a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010129d:	89 04 24             	mov    %eax,(%esp)
f01012a0:	e8 9f fe ff ff       	call   f0101144 <pgdir_walk>
f01012a5:	89 c7                	mov    %eax,%edi
		if(*pte==0)
f01012a7:	83 38 00             	cmpl   $0x0,(%eax)
f01012aa:	75 0c                	jne    f01012b8 <boot_map_region+0x6a>
		{
			struct Page* page=page_alloc(1);
f01012ac:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01012b3:	e8 c9 fd ff ff       	call   f0101081 <page_alloc>
f01012b8:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01012bb:	01 d8                	add    %ebx,%eax
			*pte=page2pa(page);

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
f01012bd:	0b 45 dc             	or     -0x24(%ebp),%eax
f01012c0:	89 07                	mov    %eax,(%edi)
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	cprintf("boot_map_region\r\n");
	int i=0;
	for(;i<size/PGSIZE;i++)
f01012c2:	83 c6 01             	add    $0x1,%esi
f01012c5:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f01012cb:	3b 75 e0             	cmp    -0x20(%ebp),%esi
f01012ce:	75 be                	jne    f010128e <boot_map_region+0x40>

		}

		pte[0]=(pa+i*PGSIZE)|PTE_P|perm;
	}
}
f01012d0:	83 c4 2c             	add    $0x2c,%esp
f01012d3:	5b                   	pop    %ebx
f01012d4:	5e                   	pop    %esi
f01012d5:	5f                   	pop    %edi
f01012d6:	5d                   	pop    %ebp
f01012d7:	c3                   	ret    

f01012d8 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f01012d8:	55                   	push   %ebp
f01012d9:	89 e5                	mov    %esp,%ebp
f01012db:	53                   	push   %ebx
f01012dc:	83 ec 14             	sub    $0x14,%esp
f01012df:	8b 5d 10             	mov    0x10(%ebp),%ebx
	//cprintf("page_lookup\r\n");
	// Fill this function in
	pte_t* pte=pgdir_walk(pgdir,va,0);
f01012e2:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01012e9:	00 
f01012ea:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012ed:	89 44 24 04          	mov    %eax,0x4(%esp)
f01012f1:	8b 45 08             	mov    0x8(%ebp),%eax
f01012f4:	89 04 24             	mov    %eax,(%esp)
f01012f7:	e8 48 fe ff ff       	call   f0101144 <pgdir_walk>
	if(pte==NULL)
f01012fc:	85 c0                	test   %eax,%eax
f01012fe:	74 3e                	je     f010133e <page_lookup+0x66>
	{
		return NULL;
	}
	if(pte_store!=0)
f0101300:	85 db                	test   %ebx,%ebx
f0101302:	74 02                	je     f0101306 <page_lookup+0x2e>
	{
		*pte_store=pte;
f0101304:	89 03                	mov    %eax,(%ebx)
	}
    pte_t* unuse=pte;

	if(pte[0] !=(pte_t)NULL)
f0101306:	8b 00                	mov    (%eax),%eax
f0101308:	85 c0                	test   %eax,%eax
f010130a:	74 39                	je     f0101345 <page_lookup+0x6d>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010130c:	c1 e8 0c             	shr    $0xc,%eax
f010130f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0101315:	72 1c                	jb     f0101333 <page_lookup+0x5b>
		panic("pa2page called with invalid pa");
f0101317:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f010131e:	f0 
f010131f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101326:	00 
f0101327:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f010132e:	e8 0d ed ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101333:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0101339:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	{

		return pa2page(PTE_ADDR(pte[0]));
f010133c:	eb 0c                	jmp    f010134a <page_lookup+0x72>
	//cprintf("page_lookup\r\n");
	// Fill this function in
	pte_t* pte=pgdir_walk(pgdir,va,0);
	if(pte==NULL)
	{
		return NULL;
f010133e:	b8 00 00 00 00       	mov    $0x0,%eax
f0101343:	eb 05                	jmp    f010134a <page_lookup+0x72>
		return pa2page(PTE_ADDR(pte[0]));

	}
	else
	{
		return NULL;
f0101345:	b8 00 00 00 00       	mov    $0x0,%eax
	}
}
f010134a:	83 c4 14             	add    $0x14,%esp
f010134d:	5b                   	pop    %ebx
f010134e:	5d                   	pop    %ebp
f010134f:	c3                   	ret    

f0101350 <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f0101350:	55                   	push   %ebp
f0101351:	89 e5                	mov    %esp,%ebp
f0101353:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f0101356:	e8 e8 4c 00 00       	call   f0106043 <cpunum>
f010135b:	6b c0 74             	imul   $0x74,%eax,%eax
f010135e:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0101365:	74 16                	je     f010137d <tlb_invalidate+0x2d>
f0101367:	e8 d7 4c 00 00       	call   f0106043 <cpunum>
f010136c:	6b c0 74             	imul   $0x74,%eax,%eax
f010136f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0101375:	8b 55 08             	mov    0x8(%ebp),%edx
f0101378:	39 50 60             	cmp    %edx,0x60(%eax)
f010137b:	75 06                	jne    f0101383 <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f010137d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101380:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f0101383:	c9                   	leave  
f0101384:	c3                   	ret    

f0101385 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f0101385:	55                   	push   %ebp
f0101386:	89 e5                	mov    %esp,%ebp
f0101388:	56                   	push   %esi
f0101389:	53                   	push   %ebx
f010138a:	83 ec 20             	sub    $0x20,%esp
f010138d:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0101390:	8b 75 0c             	mov    0xc(%ebp),%esi
	//cprintf("page_remove\r\n");
	pte_t* pte=0;
f0101393:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
	struct Page* page=page_lookup(pgdir,va,&pte);
f010139a:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010139d:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013a1:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013a5:	89 1c 24             	mov    %ebx,(%esp)
f01013a8:	e8 2b ff ff ff       	call   f01012d8 <page_lookup>
	if(page!=NULL)
f01013ad:	85 c0                	test   %eax,%eax
f01013af:	74 08                	je     f01013b9 <page_remove+0x34>
	{
		page_decref(page);
f01013b1:	89 04 24             	mov    %eax,(%esp)
f01013b4:	e8 68 fd ff ff       	call   f0101121 <page_decref>
	}

	pte[0]=0;
f01013b9:	8b 45 f4             	mov    -0xc(%ebp),%eax
f01013bc:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	tlb_invalidate(pgdir,va);
f01013c2:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013c6:	89 1c 24             	mov    %ebx,(%esp)
f01013c9:	e8 82 ff ff ff       	call   f0101350 <tlb_invalidate>
}
f01013ce:	83 c4 20             	add    $0x20,%esp
f01013d1:	5b                   	pop    %ebx
f01013d2:	5e                   	pop    %esi
f01013d3:	5d                   	pop    %ebp
f01013d4:	c3                   	ret    

f01013d5 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f01013d5:	55                   	push   %ebp
f01013d6:	89 e5                	mov    %esp,%ebp
f01013d8:	57                   	push   %edi
f01013d9:	56                   	push   %esi
f01013da:	53                   	push   %ebx
f01013db:	83 ec 1c             	sub    $0x1c,%esp
f01013de:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01013e1:	8b 75 10             	mov    0x10(%ebp),%esi
	//cprintf("page_insert\r\n");
	// Fill this function in
	pte_t* pte;
	struct Page* pg=page_lookup(pgdir,va,NULL);
f01013e4:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f01013eb:	00 
f01013ec:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013f0:	8b 45 08             	mov    0x8(%ebp),%eax
f01013f3:	89 04 24             	mov    %eax,(%esp)
f01013f6:	e8 dd fe ff ff       	call   f01012d8 <page_lookup>
f01013fb:	89 c7                	mov    %eax,%edi
	if(pg==pp)
f01013fd:	39 d8                	cmp    %ebx,%eax
f01013ff:	75 36                	jne    f0101437 <page_insert+0x62>
	{
		pte=pgdir_walk(pgdir,va,1);
f0101401:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101408:	00 
f0101409:	89 74 24 04          	mov    %esi,0x4(%esp)
f010140d:	8b 45 08             	mov    0x8(%ebp),%eax
f0101410:	89 04 24             	mov    %eax,(%esp)
f0101413:	e8 2c fd ff ff       	call   f0101144 <pgdir_walk>
		pte[0]=page2pa(pp)|perm|PTE_P;
f0101418:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010141b:	83 c9 01             	or     $0x1,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010141e:	2b 3d 90 3e 22 f0    	sub    0xf0223e90,%edi
f0101424:	c1 ff 03             	sar    $0x3,%edi
f0101427:	c1 e7 0c             	shl    $0xc,%edi
f010142a:	89 fa                	mov    %edi,%edx
f010142c:	09 ca                	or     %ecx,%edx
f010142e:	89 10                	mov    %edx,(%eax)
			return 0;
f0101430:	b8 00 00 00 00       	mov    $0x0,%eax
f0101435:	eb 57                	jmp    f010148e <page_insert+0xb9>
	}
	else if(pg!=NULL )
f0101437:	85 c0                	test   %eax,%eax
f0101439:	74 0f                	je     f010144a <page_insert+0x75>
	{
		page_remove(pgdir,va);
f010143b:	89 74 24 04          	mov    %esi,0x4(%esp)
f010143f:	8b 45 08             	mov    0x8(%ebp),%eax
f0101442:	89 04 24             	mov    %eax,(%esp)
f0101445:	e8 3b ff ff ff       	call   f0101385 <page_remove>
	}
	pte=pgdir_walk(pgdir,va,1);
f010144a:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101451:	00 
f0101452:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101456:	8b 45 08             	mov    0x8(%ebp),%eax
f0101459:	89 04 24             	mov    %eax,(%esp)
f010145c:	e8 e3 fc ff ff       	call   f0101144 <pgdir_walk>
	if(pte==NULL)
f0101461:	85 c0                	test   %eax,%eax
f0101463:	74 24                	je     f0101489 <page_insert+0xb4>
	{
		return -E_NO_MEM;
	}
	pte[0]=page2pa(pp)|perm|PTE_P;
f0101465:	8b 4d 14             	mov    0x14(%ebp),%ecx
f0101468:	83 c9 01             	or     $0x1,%ecx
f010146b:	89 da                	mov    %ebx,%edx
f010146d:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101473:	c1 fa 03             	sar    $0x3,%edx
f0101476:	c1 e2 0c             	shl    $0xc,%edx
f0101479:	09 ca                	or     %ecx,%edx
f010147b:	89 10                	mov    %edx,(%eax)
	pp->pp_ref++;
f010147d:	66 83 43 04 01       	addw   $0x1,0x4(%ebx)
	return 0;
f0101482:	b8 00 00 00 00       	mov    $0x0,%eax
f0101487:	eb 05                	jmp    f010148e <page_insert+0xb9>
		page_remove(pgdir,va);
	}
	pte=pgdir_walk(pgdir,va,1);
	if(pte==NULL)
	{
		return -E_NO_MEM;
f0101489:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	}
	pte[0]=page2pa(pp)|perm|PTE_P;
	pp->pp_ref++;
	return 0;
}
f010148e:	83 c4 1c             	add    $0x1c,%esp
f0101491:	5b                   	pop    %ebx
f0101492:	5e                   	pop    %esi
f0101493:	5f                   	pop    %edi
f0101494:	5d                   	pop    %ebp
f0101495:	c3                   	ret    

f0101496 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f0101496:	55                   	push   %ebp
f0101497:	89 e5                	mov    %esp,%ebp
f0101499:	57                   	push   %edi
f010149a:	56                   	push   %esi
f010149b:	53                   	push   %ebx
f010149c:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f010149f:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01014a6:	e8 18 2b 00 00       	call   f0103fc3 <mc146818_read>
f01014ab:	89 c3                	mov    %eax,%ebx
f01014ad:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01014b4:	e8 0a 2b 00 00       	call   f0103fc3 <mc146818_read>
f01014b9:	c1 e0 08             	shl    $0x8,%eax
f01014bc:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014be:	89 d8                	mov    %ebx,%eax
f01014c0:	c1 e0 0a             	shl    $0xa,%eax
f01014c3:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01014c9:	85 c0                	test   %eax,%eax
f01014cb:	0f 48 c2             	cmovs  %edx,%eax
f01014ce:	c1 f8 0c             	sar    $0xc,%eax
f01014d1:	a3 44 32 22 f0       	mov    %eax,0xf0223244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014d6:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f01014dd:	e8 e1 2a 00 00       	call   f0103fc3 <mc146818_read>
f01014e2:	89 c3                	mov    %eax,%ebx
f01014e4:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f01014eb:	e8 d3 2a 00 00       	call   f0103fc3 <mc146818_read>
f01014f0:	c1 e0 08             	shl    $0x8,%eax
f01014f3:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f01014f5:	89 d8                	mov    %ebx,%eax
f01014f7:	c1 e0 0a             	shl    $0xa,%eax
f01014fa:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101500:	85 c0                	test   %eax,%eax
f0101502:	0f 48 c2             	cmovs  %edx,%eax
f0101505:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101508:	85 c0                	test   %eax,%eax
f010150a:	74 0e                	je     f010151a <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f010150c:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0101512:	89 15 88 3e 22 f0    	mov    %edx,0xf0223e88
f0101518:	eb 0c                	jmp    f0101526 <mem_init+0x90>
	else
		npages = npages_basemem;
f010151a:	8b 15 44 32 22 f0    	mov    0xf0223244,%edx
f0101520:	89 15 88 3e 22 f0    	mov    %edx,0xf0223e88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101526:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101529:	c1 e8 0a             	shr    $0xa,%eax
f010152c:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f0101530:	a1 44 32 22 f0       	mov    0xf0223244,%eax
f0101535:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101538:	c1 e8 0a             	shr    $0xa,%eax
f010153b:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f010153f:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0101544:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101547:	c1 e8 0a             	shr    $0xa,%eax
f010154a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010154e:	c7 04 24 6c 71 10 f0 	movl   $0xf010716c,(%esp)
f0101555:	e8 d5 2b 00 00       	call   f010412f <cprintf>
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
	cprintf("npages :%u",npages);
f010155a:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f010155f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101563:	c7 04 24 de 6d 10 f0 	movl   $0xf0106dde,(%esp)
f010156a:	e8 c0 2b 00 00       	call   f010412f <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f010156f:	b8 00 10 00 00       	mov    $0x1000,%eax
f0101574:	e8 77 f5 ff ff       	call   f0100af0 <boot_alloc>
f0101579:	a3 8c 3e 22 f0       	mov    %eax,0xf0223e8c
	memset(kern_pgdir, 0, PGSIZE);
f010157e:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101585:	00 
f0101586:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010158d:	00 
f010158e:	89 04 24             	mov    %eax,(%esp)
f0101591:	e8 13 44 00 00       	call   f01059a9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f0101596:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010159b:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01015a0:	77 20                	ja     f01015c2 <mem_init+0x12c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01015a2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015a6:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f01015ad:	f0 
f01015ae:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f01015b5:	00 
f01015b6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01015bd:	e8 7e ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01015c2:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015c8:	83 ca 05             	or     $0x5,%edx
f01015cb:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate an array of npages 'struct Page's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:
	pages = (struct Page *) boot_alloc(npages*sizeof(struct Page));
f01015d1:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f01015d6:	c1 e0 03             	shl    $0x3,%eax
f01015d9:	e8 12 f5 ff ff       	call   f0100af0 <boot_alloc>
f01015de:	a3 90 3e 22 f0       	mov    %eax,0xf0223e90

	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs=(struct Env*)boot_alloc(NENV*sizeof(struct Env));
f01015e3:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f01015e8:	e8 03 f5 ff ff       	call   f0100af0 <boot_alloc>
f01015ed:	a3 48 32 22 f0       	mov    %eax,0xf0223248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f01015f2:	e8 96 f9 ff ff       	call   f0100f8d <page_init>

	check_page_free_list(1);
f01015f7:	b8 01 00 00 00       	mov    $0x1,%eax
f01015fc:	e8 aa f5 ff ff       	call   f0100bab <check_page_free_list>
// and page_init()).
//
static void
check_page_alloc(void)
{
	cprintf("check_page_alloc");
f0101601:	c7 04 24 e9 6d 10 f0 	movl   $0xf0106de9,(%esp)
f0101608:	e8 22 2b 00 00       	call   f010412f <cprintf>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f010160d:	83 3d 90 3e 22 f0 00 	cmpl   $0x0,0xf0223e90
f0101614:	75 1c                	jne    f0101632 <mem_init+0x19c>
		panic("'pages' is a null pointer!");
f0101616:	c7 44 24 08 fa 6d 10 	movl   $0xf0106dfa,0x8(%esp)
f010161d:	f0 
f010161e:	c7 44 24 04 28 03 00 	movl   $0x328,0x4(%esp)
f0101625:	00 
f0101626:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010162d:	e8 0e ea ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101632:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101637:	85 c0                	test   %eax,%eax
f0101639:	74 10                	je     f010164b <mem_init+0x1b5>
f010163b:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101640:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101643:	8b 00                	mov    (%eax),%eax
f0101645:	85 c0                	test   %eax,%eax
f0101647:	75 f7                	jne    f0101640 <mem_init+0x1aa>
f0101649:	eb 05                	jmp    f0101650 <mem_init+0x1ba>
f010164b:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101650:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101657:	e8 25 fa ff ff       	call   f0101081 <page_alloc>
f010165c:	89 c7                	mov    %eax,%edi
f010165e:	85 c0                	test   %eax,%eax
f0101660:	75 24                	jne    f0101686 <mem_init+0x1f0>
f0101662:	c7 44 24 0c 15 6e 10 	movl   $0xf0106e15,0xc(%esp)
f0101669:	f0 
f010166a:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101671:	f0 
f0101672:	c7 44 24 04 30 03 00 	movl   $0x330,0x4(%esp)
f0101679:	00 
f010167a:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101681:	e8 ba e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101686:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010168d:	e8 ef f9 ff ff       	call   f0101081 <page_alloc>
f0101692:	89 c6                	mov    %eax,%esi
f0101694:	85 c0                	test   %eax,%eax
f0101696:	75 24                	jne    f01016bc <mem_init+0x226>
f0101698:	c7 44 24 0c 2b 6e 10 	movl   $0xf0106e2b,0xc(%esp)
f010169f:	f0 
f01016a0:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01016a7:	f0 
f01016a8:	c7 44 24 04 31 03 00 	movl   $0x331,0x4(%esp)
f01016af:	00 
f01016b0:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01016b7:	e8 84 e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016bc:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016c3:	e8 b9 f9 ff ff       	call   f0101081 <page_alloc>
f01016c8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016cb:	85 c0                	test   %eax,%eax
f01016cd:	75 24                	jne    f01016f3 <mem_init+0x25d>
f01016cf:	c7 44 24 0c 41 6e 10 	movl   $0xf0106e41,0xc(%esp)
f01016d6:	f0 
f01016d7:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01016de:	f0 
f01016df:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f01016e6:	00 
f01016e7:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01016ee:	e8 4d e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01016f3:	39 f7                	cmp    %esi,%edi
f01016f5:	75 24                	jne    f010171b <mem_init+0x285>
f01016f7:	c7 44 24 0c 57 6e 10 	movl   $0xf0106e57,0xc(%esp)
f01016fe:	f0 
f01016ff:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101706:	f0 
f0101707:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f010170e:	00 
f010170f:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101716:	e8 25 e9 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010171b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010171e:	39 c6                	cmp    %eax,%esi
f0101720:	74 04                	je     f0101726 <mem_init+0x290>
f0101722:	39 c7                	cmp    %eax,%edi
f0101724:	75 24                	jne    f010174a <mem_init+0x2b4>
f0101726:	c7 44 24 0c a8 71 10 	movl   $0xf01071a8,0xc(%esp)
f010172d:	f0 
f010172e:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101735:	f0 
f0101736:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f010173d:	00 
f010173e:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101745:	e8 f6 e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010174a:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101750:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0101755:	c1 e0 0c             	shl    $0xc,%eax
f0101758:	89 f9                	mov    %edi,%ecx
f010175a:	29 d1                	sub    %edx,%ecx
f010175c:	c1 f9 03             	sar    $0x3,%ecx
f010175f:	c1 e1 0c             	shl    $0xc,%ecx
f0101762:	39 c1                	cmp    %eax,%ecx
f0101764:	72 24                	jb     f010178a <mem_init+0x2f4>
f0101766:	c7 44 24 0c 69 6e 10 	movl   $0xf0106e69,0xc(%esp)
f010176d:	f0 
f010176e:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101775:	f0 
f0101776:	c7 44 24 04 37 03 00 	movl   $0x337,0x4(%esp)
f010177d:	00 
f010177e:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101785:	e8 b6 e8 ff ff       	call   f0100040 <_panic>
f010178a:	89 f1                	mov    %esi,%ecx
f010178c:	29 d1                	sub    %edx,%ecx
f010178e:	c1 f9 03             	sar    $0x3,%ecx
f0101791:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f0101794:	39 c8                	cmp    %ecx,%eax
f0101796:	77 24                	ja     f01017bc <mem_init+0x326>
f0101798:	c7 44 24 0c 86 6e 10 	movl   $0xf0106e86,0xc(%esp)
f010179f:	f0 
f01017a0:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01017a7:	f0 
f01017a8:	c7 44 24 04 38 03 00 	movl   $0x338,0x4(%esp)
f01017af:	00 
f01017b0:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01017b7:	e8 84 e8 ff ff       	call   f0100040 <_panic>
f01017bc:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017bf:	29 d1                	sub    %edx,%ecx
f01017c1:	89 ca                	mov    %ecx,%edx
f01017c3:	c1 fa 03             	sar    $0x3,%edx
f01017c6:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017c9:	39 d0                	cmp    %edx,%eax
f01017cb:	77 24                	ja     f01017f1 <mem_init+0x35b>
f01017cd:	c7 44 24 0c a3 6e 10 	movl   $0xf0106ea3,0xc(%esp)
f01017d4:	f0 
f01017d5:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01017dc:	f0 
f01017dd:	c7 44 24 04 39 03 00 	movl   $0x339,0x4(%esp)
f01017e4:	00 
f01017e5:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01017ec:	e8 4f e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f01017f1:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f01017f6:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f01017f9:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f0101800:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101803:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010180a:	e8 72 f8 ff ff       	call   f0101081 <page_alloc>
f010180f:	85 c0                	test   %eax,%eax
f0101811:	74 24                	je     f0101837 <mem_init+0x3a1>
f0101813:	c7 44 24 0c c0 6e 10 	movl   $0xf0106ec0,0xc(%esp)
f010181a:	f0 
f010181b:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101822:	f0 
f0101823:	c7 44 24 04 40 03 00 	movl   $0x340,0x4(%esp)
f010182a:	00 
f010182b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101832:	e8 09 e8 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101837:	89 3c 24             	mov    %edi,(%esp)
f010183a:	e8 c7 f8 ff ff       	call   f0101106 <page_free>
	page_free(pp1);
f010183f:	89 34 24             	mov    %esi,(%esp)
f0101842:	e8 bf f8 ff ff       	call   f0101106 <page_free>
	page_free(pp2);
f0101847:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010184a:	89 04 24             	mov    %eax,(%esp)
f010184d:	e8 b4 f8 ff ff       	call   f0101106 <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101852:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101859:	e8 23 f8 ff ff       	call   f0101081 <page_alloc>
f010185e:	89 c6                	mov    %eax,%esi
f0101860:	85 c0                	test   %eax,%eax
f0101862:	75 24                	jne    f0101888 <mem_init+0x3f2>
f0101864:	c7 44 24 0c 15 6e 10 	movl   $0xf0106e15,0xc(%esp)
f010186b:	f0 
f010186c:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101873:	f0 
f0101874:	c7 44 24 04 47 03 00 	movl   $0x347,0x4(%esp)
f010187b:	00 
f010187c:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101883:	e8 b8 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101888:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010188f:	e8 ed f7 ff ff       	call   f0101081 <page_alloc>
f0101894:	89 c7                	mov    %eax,%edi
f0101896:	85 c0                	test   %eax,%eax
f0101898:	75 24                	jne    f01018be <mem_init+0x428>
f010189a:	c7 44 24 0c 2b 6e 10 	movl   $0xf0106e2b,0xc(%esp)
f01018a1:	f0 
f01018a2:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01018a9:	f0 
f01018aa:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f01018b1:	00 
f01018b2:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01018b9:	e8 82 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018be:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018c5:	e8 b7 f7 ff ff       	call   f0101081 <page_alloc>
f01018ca:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018cd:	85 c0                	test   %eax,%eax
f01018cf:	75 24                	jne    f01018f5 <mem_init+0x45f>
f01018d1:	c7 44 24 0c 41 6e 10 	movl   $0xf0106e41,0xc(%esp)
f01018d8:	f0 
f01018d9:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01018e0:	f0 
f01018e1:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f01018e8:	00 
f01018e9:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01018f0:	e8 4b e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f01018f5:	39 fe                	cmp    %edi,%esi
f01018f7:	75 24                	jne    f010191d <mem_init+0x487>
f01018f9:	c7 44 24 0c 57 6e 10 	movl   $0xf0106e57,0xc(%esp)
f0101900:	f0 
f0101901:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101908:	f0 
f0101909:	c7 44 24 04 4b 03 00 	movl   $0x34b,0x4(%esp)
f0101910:	00 
f0101911:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101918:	e8 23 e7 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010191d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101920:	39 c7                	cmp    %eax,%edi
f0101922:	74 04                	je     f0101928 <mem_init+0x492>
f0101924:	39 c6                	cmp    %eax,%esi
f0101926:	75 24                	jne    f010194c <mem_init+0x4b6>
f0101928:	c7 44 24 0c a8 71 10 	movl   $0xf01071a8,0xc(%esp)
f010192f:	f0 
f0101930:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101937:	f0 
f0101938:	c7 44 24 04 4c 03 00 	movl   $0x34c,0x4(%esp)
f010193f:	00 
f0101940:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101947:	e8 f4 e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f010194c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101953:	e8 29 f7 ff ff       	call   f0101081 <page_alloc>
f0101958:	85 c0                	test   %eax,%eax
f010195a:	74 24                	je     f0101980 <mem_init+0x4ea>
f010195c:	c7 44 24 0c c0 6e 10 	movl   $0xf0106ec0,0xc(%esp)
f0101963:	f0 
f0101964:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010196b:	f0 
f010196c:	c7 44 24 04 4d 03 00 	movl   $0x34d,0x4(%esp)
f0101973:	00 
f0101974:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010197b:	e8 c0 e6 ff ff       	call   f0100040 <_panic>
f0101980:	89 f0                	mov    %esi,%eax
f0101982:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0101988:	c1 f8 03             	sar    $0x3,%eax
f010198b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010198e:	89 c2                	mov    %eax,%edx
f0101990:	c1 ea 0c             	shr    $0xc,%edx
f0101993:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0101999:	72 20                	jb     f01019bb <mem_init+0x525>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010199b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010199f:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01019a6:	f0 
f01019a7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01019ae:	00 
f01019af:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01019b6:	e8 85 e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019bb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019c2:	00 
f01019c3:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019ca:	00 
	return (void *)(pa + KERNBASE);
f01019cb:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01019d0:	89 04 24             	mov    %eax,(%esp)
f01019d3:	e8 d1 3f 00 00       	call   f01059a9 <memset>
	page_free(pp0);
f01019d8:	89 34 24             	mov    %esi,(%esp)
f01019db:	e8 26 f7 ff ff       	call   f0101106 <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f01019e0:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01019e7:	e8 95 f6 ff ff       	call   f0101081 <page_alloc>
f01019ec:	85 c0                	test   %eax,%eax
f01019ee:	75 24                	jne    f0101a14 <mem_init+0x57e>
f01019f0:	c7 44 24 0c cf 6e 10 	movl   $0xf0106ecf,0xc(%esp)
f01019f7:	f0 
f01019f8:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01019ff:	f0 
f0101a00:	c7 44 24 04 52 03 00 	movl   $0x352,0x4(%esp)
f0101a07:	00 
f0101a08:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101a0f:	e8 2c e6 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a14:	39 c6                	cmp    %eax,%esi
f0101a16:	74 24                	je     f0101a3c <mem_init+0x5a6>
f0101a18:	c7 44 24 0c ed 6e 10 	movl   $0xf0106eed,0xc(%esp)
f0101a1f:	f0 
f0101a20:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101a27:	f0 
f0101a28:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f0101a2f:	00 
f0101a30:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101a37:	e8 04 e6 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a3c:	89 f2                	mov    %esi,%edx
f0101a3e:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101a44:	c1 fa 03             	sar    $0x3,%edx
f0101a47:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a4a:	89 d0                	mov    %edx,%eax
f0101a4c:	c1 e8 0c             	shr    $0xc,%eax
f0101a4f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0101a55:	72 20                	jb     f0101a77 <mem_init+0x5e1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a57:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a5b:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0101a62:	f0 
f0101a63:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a6a:	00 
f0101a6b:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0101a72:	e8 c9 e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101a77:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101a7e:	75 11                	jne    f0101a91 <mem_init+0x5fb>
f0101a80:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101a86:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101a8c:	80 38 00             	cmpb   $0x0,(%eax)
f0101a8f:	74 24                	je     f0101ab5 <mem_init+0x61f>
f0101a91:	c7 44 24 0c fd 6e 10 	movl   $0xf0106efd,0xc(%esp)
f0101a98:	f0 
f0101a99:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101aa0:	f0 
f0101aa1:	c7 44 24 04 56 03 00 	movl   $0x356,0x4(%esp)
f0101aa8:	00 
f0101aa9:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101ab0:	e8 8b e5 ff ff       	call   f0100040 <_panic>
f0101ab5:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101ab8:	39 d0                	cmp    %edx,%eax
f0101aba:	75 d0                	jne    f0101a8c <mem_init+0x5f6>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101abc:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101abf:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0101ac4:	89 34 24             	mov    %esi,(%esp)
f0101ac7:	e8 3a f6 ff ff       	call   f0101106 <page_free>
	page_free(pp1);
f0101acc:	89 3c 24             	mov    %edi,(%esp)
f0101acf:	e8 32 f6 ff ff       	call   f0101106 <page_free>
	page_free(pp2);
f0101ad4:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ad7:	89 04 24             	mov    %eax,(%esp)
f0101ada:	e8 27 f6 ff ff       	call   f0101106 <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101adf:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101ae4:	85 c0                	test   %eax,%eax
f0101ae6:	74 09                	je     f0101af1 <mem_init+0x65b>
		--nfree;
f0101ae8:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101aeb:	8b 00                	mov    (%eax),%eax
f0101aed:	85 c0                	test   %eax,%eax
f0101aef:	75 f7                	jne    f0101ae8 <mem_init+0x652>
		--nfree;
	assert(nfree == 0);
f0101af1:	85 db                	test   %ebx,%ebx
f0101af3:	74 24                	je     f0101b19 <mem_init+0x683>
f0101af5:	c7 44 24 0c 07 6f 10 	movl   $0xf0106f07,0xc(%esp)
f0101afc:	f0 
f0101afd:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101b04:	f0 
f0101b05:	c7 44 24 04 63 03 00 	movl   $0x363,0x4(%esp)
f0101b0c:	00 
f0101b0d:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101b14:	e8 27 e5 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b19:	c7 04 24 c8 71 10 f0 	movl   $0xf01071c8,(%esp)
f0101b20:	e8 0a 26 00 00       	call   f010412f <cprintf>

// check page_insert, page_remove, &c
static void
check_page(void)
{
	cprintf("check_page\r\n");
f0101b25:	c7 04 24 12 6f 10 f0 	movl   $0xf0106f12,(%esp)
f0101b2c:	e8 fe 25 00 00       	call   f010412f <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b31:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b38:	e8 44 f5 ff ff       	call   f0101081 <page_alloc>
f0101b3d:	89 c3                	mov    %eax,%ebx
f0101b3f:	85 c0                	test   %eax,%eax
f0101b41:	75 24                	jne    f0101b67 <mem_init+0x6d1>
f0101b43:	c7 44 24 0c 15 6e 10 	movl   $0xf0106e15,0xc(%esp)
f0101b4a:	f0 
f0101b4b:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101b52:	f0 
f0101b53:	c7 44 24 04 d9 03 00 	movl   $0x3d9,0x4(%esp)
f0101b5a:	00 
f0101b5b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101b62:	e8 d9 e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b67:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b6e:	e8 0e f5 ff ff       	call   f0101081 <page_alloc>
f0101b73:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101b76:	85 c0                	test   %eax,%eax
f0101b78:	75 24                	jne    f0101b9e <mem_init+0x708>
f0101b7a:	c7 44 24 0c 2b 6e 10 	movl   $0xf0106e2b,0xc(%esp)
f0101b81:	f0 
f0101b82:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101b89:	f0 
f0101b8a:	c7 44 24 04 da 03 00 	movl   $0x3da,0x4(%esp)
f0101b91:	00 
f0101b92:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101b99:	e8 a2 e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101b9e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ba5:	e8 d7 f4 ff ff       	call   f0101081 <page_alloc>
f0101baa:	89 c6                	mov    %eax,%esi
f0101bac:	85 c0                	test   %eax,%eax
f0101bae:	75 24                	jne    f0101bd4 <mem_init+0x73e>
f0101bb0:	c7 44 24 0c 41 6e 10 	movl   $0xf0106e41,0xc(%esp)
f0101bb7:	f0 
f0101bb8:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101bbf:	f0 
f0101bc0:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0101bc7:	00 
f0101bc8:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101bcf:	e8 6c e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101bd4:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101bd7:	75 24                	jne    f0101bfd <mem_init+0x767>
f0101bd9:	c7 44 24 0c 57 6e 10 	movl   $0xf0106e57,0xc(%esp)
f0101be0:	f0 
f0101be1:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101be8:	f0 
f0101be9:	c7 44 24 04 de 03 00 	movl   $0x3de,0x4(%esp)
f0101bf0:	00 
f0101bf1:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101bf8:	e8 43 e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101bfd:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c00:	74 04                	je     f0101c06 <mem_init+0x770>
f0101c02:	39 c3                	cmp    %eax,%ebx
f0101c04:	75 24                	jne    f0101c2a <mem_init+0x794>
f0101c06:	c7 44 24 0c a8 71 10 	movl   $0xf01071a8,0xc(%esp)
f0101c0d:	f0 
f0101c0e:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101c15:	f0 
f0101c16:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f0101c1d:	00 
f0101c1e:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101c25:	e8 16 e4 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c2a:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0101c2f:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c32:	c7 05 40 32 22 f0 00 	movl   $0x0,0xf0223240
f0101c39:	00 00 00 
	cprintf("1");
f0101c3c:	c7 04 24 3f 6f 10 f0 	movl   $0xf0106f3f,(%esp)
f0101c43:	e8 e7 24 00 00       	call   f010412f <cprintf>
	// should be no free memory
	assert(!page_alloc(0));
f0101c48:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c4f:	e8 2d f4 ff ff       	call   f0101081 <page_alloc>
f0101c54:	85 c0                	test   %eax,%eax
f0101c56:	74 24                	je     f0101c7c <mem_init+0x7e6>
f0101c58:	c7 44 24 0c c0 6e 10 	movl   $0xf0106ec0,0xc(%esp)
f0101c5f:	f0 
f0101c60:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101c67:	f0 
f0101c68:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f0101c6f:	00 
f0101c70:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101c77:	e8 c4 e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c7c:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c7f:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c83:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101c8a:	00 
f0101c8b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101c90:	89 04 24             	mov    %eax,(%esp)
f0101c93:	e8 40 f6 ff ff       	call   f01012d8 <page_lookup>
f0101c98:	85 c0                	test   %eax,%eax
f0101c9a:	74 24                	je     f0101cc0 <mem_init+0x82a>
f0101c9c:	c7 44 24 0c e8 71 10 	movl   $0xf01071e8,0xc(%esp)
f0101ca3:	f0 
f0101ca4:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101cab:	f0 
f0101cac:	c7 44 24 04 e9 03 00 	movl   $0x3e9,0x4(%esp)
f0101cb3:	00 
f0101cb4:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101cbb:	e8 80 e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101cc0:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101cc7:	00 
f0101cc8:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101ccf:	00 
f0101cd0:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101cd3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101cd7:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101cdc:	89 04 24             	mov    %eax,(%esp)
f0101cdf:	e8 f1 f6 ff ff       	call   f01013d5 <page_insert>
f0101ce4:	85 c0                	test   %eax,%eax
f0101ce6:	78 24                	js     f0101d0c <mem_init+0x876>
f0101ce8:	c7 44 24 0c 20 72 10 	movl   $0xf0107220,0xc(%esp)
f0101cef:	f0 
f0101cf0:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101cf7:	f0 
f0101cf8:	c7 44 24 04 ec 03 00 	movl   $0x3ec,0x4(%esp)
f0101cff:	00 
f0101d00:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101d07:	e8 34 e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d0c:	89 1c 24             	mov    %ebx,(%esp)
f0101d0f:	e8 f2 f3 ff ff       	call   f0101106 <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d14:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d1b:	00 
f0101d1c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d23:	00 
f0101d24:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d27:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d2b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101d30:	89 04 24             	mov    %eax,(%esp)
f0101d33:	e8 9d f6 ff ff       	call   f01013d5 <page_insert>
f0101d38:	85 c0                	test   %eax,%eax
f0101d3a:	74 24                	je     f0101d60 <mem_init+0x8ca>
f0101d3c:	c7 44 24 0c 50 72 10 	movl   $0xf0107250,0xc(%esp)
f0101d43:	f0 
f0101d44:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101d4b:	f0 
f0101d4c:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0101d53:	00 
f0101d54:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101d5b:	e8 e0 e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d60:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d65:	8b 3d 90 3e 22 f0    	mov    0xf0223e90,%edi
f0101d6b:	8b 08                	mov    (%eax),%ecx
f0101d6d:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0101d73:	89 da                	mov    %ebx,%edx
f0101d75:	29 fa                	sub    %edi,%edx
f0101d77:	c1 fa 03             	sar    $0x3,%edx
f0101d7a:	c1 e2 0c             	shl    $0xc,%edx
f0101d7d:	39 d1                	cmp    %edx,%ecx
f0101d7f:	74 24                	je     f0101da5 <mem_init+0x90f>
f0101d81:	c7 44 24 0c 80 72 10 	movl   $0xf0107280,0xc(%esp)
f0101d88:	f0 
f0101d89:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101d90:	f0 
f0101d91:	c7 44 24 04 f1 03 00 	movl   $0x3f1,0x4(%esp)
f0101d98:	00 
f0101d99:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101da0:	e8 9b e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101da5:	ba 00 00 00 00       	mov    $0x0,%edx
f0101daa:	e8 8d ed ff ff       	call   f0100b3c <check_va2pa>
f0101daf:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101db2:	29 fa                	sub    %edi,%edx
f0101db4:	c1 fa 03             	sar    $0x3,%edx
f0101db7:	c1 e2 0c             	shl    $0xc,%edx
f0101dba:	39 d0                	cmp    %edx,%eax
f0101dbc:	74 24                	je     f0101de2 <mem_init+0x94c>
f0101dbe:	c7 44 24 0c a8 72 10 	movl   $0xf01072a8,0xc(%esp)
f0101dc5:	f0 
f0101dc6:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101dcd:	f0 
f0101dce:	c7 44 24 04 f2 03 00 	movl   $0x3f2,0x4(%esp)
f0101dd5:	00 
f0101dd6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101ddd:	e8 5e e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101de2:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101de5:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101dea:	74 24                	je     f0101e10 <mem_init+0x97a>
f0101dec:	c7 44 24 0c 1f 6f 10 	movl   $0xf0106f1f,0xc(%esp)
f0101df3:	f0 
f0101df4:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101dfb:	f0 
f0101dfc:	c7 44 24 04 f3 03 00 	movl   $0x3f3,0x4(%esp)
f0101e03:	00 
f0101e04:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101e0b:	e8 30 e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e10:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e15:	74 24                	je     f0101e3b <mem_init+0x9a5>
f0101e17:	c7 44 24 0c 30 6f 10 	movl   $0xf0106f30,0xc(%esp)
f0101e1e:	f0 
f0101e1f:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101e26:	f0 
f0101e27:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0101e2e:	00 
f0101e2f:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101e36:	e8 05 e2 ff ff       	call   f0100040 <_panic>
	cprintf("2");
f0101e3b:	c7 04 24 7b 6f 10 f0 	movl   $0xf0106f7b,(%esp)
f0101e42:	e8 e8 22 00 00       	call   f010412f <cprintf>
	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e47:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e4e:	00 
f0101e4f:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e56:	00 
f0101e57:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e5b:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101e60:	89 04 24             	mov    %eax,(%esp)
f0101e63:	e8 6d f5 ff ff       	call   f01013d5 <page_insert>
f0101e68:	85 c0                	test   %eax,%eax
f0101e6a:	74 24                	je     f0101e90 <mem_init+0x9fa>
f0101e6c:	c7 44 24 0c d8 72 10 	movl   $0xf01072d8,0xc(%esp)
f0101e73:	f0 
f0101e74:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101e7b:	f0 
f0101e7c:	c7 44 24 04 f7 03 00 	movl   $0x3f7,0x4(%esp)
f0101e83:	00 
f0101e84:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101e8b:	e8 b0 e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101e90:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101e95:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101e9a:	e8 9d ec ff ff       	call   f0100b3c <check_va2pa>
f0101e9f:	89 f2                	mov    %esi,%edx
f0101ea1:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101ea7:	c1 fa 03             	sar    $0x3,%edx
f0101eaa:	c1 e2 0c             	shl    $0xc,%edx
f0101ead:	39 d0                	cmp    %edx,%eax
f0101eaf:	74 24                	je     f0101ed5 <mem_init+0xa3f>
f0101eb1:	c7 44 24 0c 14 73 10 	movl   $0xf0107314,0xc(%esp)
f0101eb8:	f0 
f0101eb9:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101ec0:	f0 
f0101ec1:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f0101ec8:	00 
f0101ec9:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101ed0:	e8 6b e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ed5:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101eda:	74 24                	je     f0101f00 <mem_init+0xa6a>
f0101edc:	c7 44 24 0c 41 6f 10 	movl   $0xf0106f41,0xc(%esp)
f0101ee3:	f0 
f0101ee4:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101eeb:	f0 
f0101eec:	c7 44 24 04 f9 03 00 	movl   $0x3f9,0x4(%esp)
f0101ef3:	00 
f0101ef4:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101efb:	e8 40 e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101f00:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f07:	e8 75 f1 ff ff       	call   f0101081 <page_alloc>
f0101f0c:	85 c0                	test   %eax,%eax
f0101f0e:	74 24                	je     f0101f34 <mem_init+0xa9e>
f0101f10:	c7 44 24 0c c0 6e 10 	movl   $0xf0106ec0,0xc(%esp)
f0101f17:	f0 
f0101f18:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101f1f:	f0 
f0101f20:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f0101f27:	00 
f0101f28:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101f2f:	e8 0c e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f34:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f3b:	00 
f0101f3c:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f43:	00 
f0101f44:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101f48:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101f4d:	89 04 24             	mov    %eax,(%esp)
f0101f50:	e8 80 f4 ff ff       	call   f01013d5 <page_insert>
f0101f55:	85 c0                	test   %eax,%eax
f0101f57:	74 24                	je     f0101f7d <mem_init+0xae7>
f0101f59:	c7 44 24 0c d8 72 10 	movl   $0xf01072d8,0xc(%esp)
f0101f60:	f0 
f0101f61:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101f68:	f0 
f0101f69:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f0101f70:	00 
f0101f71:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101f78:	e8 c3 e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f7d:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f82:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0101f87:	e8 b0 eb ff ff       	call   f0100b3c <check_va2pa>
f0101f8c:	89 f2                	mov    %esi,%edx
f0101f8e:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0101f94:	c1 fa 03             	sar    $0x3,%edx
f0101f97:	c1 e2 0c             	shl    $0xc,%edx
f0101f9a:	39 d0                	cmp    %edx,%eax
f0101f9c:	74 24                	je     f0101fc2 <mem_init+0xb2c>
f0101f9e:	c7 44 24 0c 14 73 10 	movl   $0xf0107314,0xc(%esp)
f0101fa5:	f0 
f0101fa6:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101fad:	f0 
f0101fae:	c7 44 24 04 00 04 00 	movl   $0x400,0x4(%esp)
f0101fb5:	00 
f0101fb6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101fbd:	e8 7e e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fc2:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101fc7:	74 24                	je     f0101fed <mem_init+0xb57>
f0101fc9:	c7 44 24 0c 41 6f 10 	movl   $0xf0106f41,0xc(%esp)
f0101fd0:	f0 
f0101fd1:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0101fd8:	f0 
f0101fd9:	c7 44 24 04 01 04 00 	movl   $0x401,0x4(%esp)
f0101fe0:	00 
f0101fe1:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0101fe8:	e8 53 e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101fed:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101ff4:	e8 88 f0 ff ff       	call   f0101081 <page_alloc>
f0101ff9:	85 c0                	test   %eax,%eax
f0101ffb:	74 24                	je     f0102021 <mem_init+0xb8b>
f0101ffd:	c7 44 24 0c c0 6e 10 	movl   $0xf0106ec0,0xc(%esp)
f0102004:	f0 
f0102005:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010200c:	f0 
f010200d:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102014:	00 
f0102015:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010201c:	e8 1f e0 ff ff       	call   f0100040 <_panic>
	cprintf("3");
f0102021:	c7 04 24 52 6f 10 f0 	movl   $0xf0106f52,(%esp)
f0102028:	e8 02 21 00 00       	call   f010412f <cprintf>
	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f010202d:	8b 15 8c 3e 22 f0    	mov    0xf0223e8c,%edx
f0102033:	8b 02                	mov    (%edx),%eax
f0102035:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010203a:	89 c1                	mov    %eax,%ecx
f010203c:	c1 e9 0c             	shr    $0xc,%ecx
f010203f:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f0102045:	72 20                	jb     f0102067 <mem_init+0xbd1>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102047:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010204b:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0102052:	f0 
f0102053:	c7 44 24 04 08 04 00 	movl   $0x408,0x4(%esp)
f010205a:	00 
f010205b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102062:	e8 d9 df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0102067:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010206c:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f010206f:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102076:	00 
f0102077:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010207e:	00 
f010207f:	89 14 24             	mov    %edx,(%esp)
f0102082:	e8 bd f0 ff ff       	call   f0101144 <pgdir_walk>
f0102087:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010208a:	8d 57 04             	lea    0x4(%edi),%edx
f010208d:	39 d0                	cmp    %edx,%eax
f010208f:	74 24                	je     f01020b5 <mem_init+0xc1f>
f0102091:	c7 44 24 0c 44 73 10 	movl   $0xf0107344,0xc(%esp)
f0102098:	f0 
f0102099:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01020a0:	f0 
f01020a1:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01020a8:	00 
f01020a9:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01020b0:	e8 8b df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f01020b5:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020bc:	00 
f01020bd:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020c4:	00 
f01020c5:	89 74 24 04          	mov    %esi,0x4(%esp)
f01020c9:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01020ce:	89 04 24             	mov    %eax,(%esp)
f01020d1:	e8 ff f2 ff ff       	call   f01013d5 <page_insert>
f01020d6:	85 c0                	test   %eax,%eax
f01020d8:	74 24                	je     f01020fe <mem_init+0xc68>
f01020da:	c7 44 24 0c 84 73 10 	movl   $0xf0107384,0xc(%esp)
f01020e1:	f0 
f01020e2:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01020e9:	f0 
f01020ea:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f01020f1:	00 
f01020f2:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01020f9:	e8 42 df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f01020fe:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f0102104:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102109:	89 f8                	mov    %edi,%eax
f010210b:	e8 2c ea ff ff       	call   f0100b3c <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102110:	89 f2                	mov    %esi,%edx
f0102112:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102118:	c1 fa 03             	sar    $0x3,%edx
f010211b:	c1 e2 0c             	shl    $0xc,%edx
f010211e:	39 d0                	cmp    %edx,%eax
f0102120:	74 24                	je     f0102146 <mem_init+0xcb0>
f0102122:	c7 44 24 0c 14 73 10 	movl   $0xf0107314,0xc(%esp)
f0102129:	f0 
f010212a:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102131:	f0 
f0102132:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f0102139:	00 
f010213a:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102141:	e8 fa de ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0102146:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f010214b:	74 24                	je     f0102171 <mem_init+0xcdb>
f010214d:	c7 44 24 0c 41 6f 10 	movl   $0xf0106f41,0xc(%esp)
f0102154:	f0 
f0102155:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010215c:	f0 
f010215d:	c7 44 24 04 0e 04 00 	movl   $0x40e,0x4(%esp)
f0102164:	00 
f0102165:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010216c:	e8 cf de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0102171:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102178:	00 
f0102179:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102180:	00 
f0102181:	89 3c 24             	mov    %edi,(%esp)
f0102184:	e8 bb ef ff ff       	call   f0101144 <pgdir_walk>
f0102189:	f6 00 04             	testb  $0x4,(%eax)
f010218c:	75 24                	jne    f01021b2 <mem_init+0xd1c>
f010218e:	c7 44 24 0c c4 73 10 	movl   $0xf01073c4,0xc(%esp)
f0102195:	f0 
f0102196:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010219d:	f0 
f010219e:	c7 44 24 04 0f 04 00 	movl   $0x40f,0x4(%esp)
f01021a5:	00 
f01021a6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01021ad:	e8 8e de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021b2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01021b7:	f6 00 04             	testb  $0x4,(%eax)
f01021ba:	75 24                	jne    f01021e0 <mem_init+0xd4a>
f01021bc:	c7 44 24 0c 54 6f 10 	movl   $0xf0106f54,0xc(%esp)
f01021c3:	f0 
f01021c4:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01021cb:	f0 
f01021cc:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f01021d3:	00 
f01021d4:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01021db:	e8 60 de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021e0:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021e7:	00 
f01021e8:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021ef:	00 
f01021f0:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01021f4:	89 04 24             	mov    %eax,(%esp)
f01021f7:	e8 d9 f1 ff ff       	call   f01013d5 <page_insert>
f01021fc:	85 c0                	test   %eax,%eax
f01021fe:	78 24                	js     f0102224 <mem_init+0xd8e>
f0102200:	c7 44 24 0c f8 73 10 	movl   $0xf01073f8,0xc(%esp)
f0102207:	f0 
f0102208:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010220f:	f0 
f0102210:	c7 44 24 04 13 04 00 	movl   $0x413,0x4(%esp)
f0102217:	00 
f0102218:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010221f:	e8 1c de ff ff       	call   f0100040 <_panic>
	cprintf("4");
f0102224:	c7 04 24 6a 6f 10 f0 	movl   $0xf0106f6a,(%esp)
f010222b:	e8 ff 1e 00 00       	call   f010412f <cprintf>
	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102230:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102237:	00 
f0102238:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010223f:	00 
f0102240:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102243:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102247:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010224c:	89 04 24             	mov    %eax,(%esp)
f010224f:	e8 81 f1 ff ff       	call   f01013d5 <page_insert>
f0102254:	85 c0                	test   %eax,%eax
f0102256:	74 24                	je     f010227c <mem_init+0xde6>
f0102258:	c7 44 24 0c 30 74 10 	movl   $0xf0107430,0xc(%esp)
f010225f:	f0 
f0102260:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102267:	f0 
f0102268:	c7 44 24 04 16 04 00 	movl   $0x416,0x4(%esp)
f010226f:	00 
f0102270:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102277:	e8 c4 dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f010227c:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0102283:	00 
f0102284:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f010228b:	00 
f010228c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102291:	89 04 24             	mov    %eax,(%esp)
f0102294:	e8 ab ee ff ff       	call   f0101144 <pgdir_walk>
f0102299:	f6 00 04             	testb  $0x4,(%eax)
f010229c:	74 24                	je     f01022c2 <mem_init+0xe2c>
f010229e:	c7 44 24 0c 6c 74 10 	movl   $0xf010746c,0xc(%esp)
f01022a5:	f0 
f01022a6:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01022ad:	f0 
f01022ae:	c7 44 24 04 17 04 00 	movl   $0x417,0x4(%esp)
f01022b5:	00 
f01022b6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01022bd:	e8 7e dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022c2:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f01022c8:	ba 00 00 00 00       	mov    $0x0,%edx
f01022cd:	89 f8                	mov    %edi,%eax
f01022cf:	e8 68 e8 ff ff       	call   f0100b3c <check_va2pa>
f01022d4:	89 c1                	mov    %eax,%ecx
f01022d6:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022d9:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022dc:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01022e2:	c1 f8 03             	sar    $0x3,%eax
f01022e5:	c1 e0 0c             	shl    $0xc,%eax
f01022e8:	39 c1                	cmp    %eax,%ecx
f01022ea:	74 24                	je     f0102310 <mem_init+0xe7a>
f01022ec:	c7 44 24 0c a4 74 10 	movl   $0xf01074a4,0xc(%esp)
f01022f3:	f0 
f01022f4:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01022fb:	f0 
f01022fc:	c7 44 24 04 1a 04 00 	movl   $0x41a,0x4(%esp)
f0102303:	00 
f0102304:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010230b:	e8 30 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102310:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102315:	89 f8                	mov    %edi,%eax
f0102317:	e8 20 e8 ff ff       	call   f0100b3c <check_va2pa>
f010231c:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f010231f:	74 24                	je     f0102345 <mem_init+0xeaf>
f0102321:	c7 44 24 0c d0 74 10 	movl   $0xf01074d0,0xc(%esp)
f0102328:	f0 
f0102329:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102330:	f0 
f0102331:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f0102338:	00 
f0102339:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102340:	e8 fb dc ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f0102345:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102348:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f010234d:	74 24                	je     f0102373 <mem_init+0xedd>
f010234f:	c7 44 24 0c 6c 6f 10 	movl   $0xf0106f6c,0xc(%esp)
f0102356:	f0 
f0102357:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010235e:	f0 
f010235f:	c7 44 24 04 1d 04 00 	movl   $0x41d,0x4(%esp)
f0102366:	00 
f0102367:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010236e:	e8 cd dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102373:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102378:	74 24                	je     f010239e <mem_init+0xf08>
f010237a:	c7 44 24 0c 7d 6f 10 	movl   $0xf0106f7d,0xc(%esp)
f0102381:	f0 
f0102382:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102389:	f0 
f010238a:	c7 44 24 04 1e 04 00 	movl   $0x41e,0x4(%esp)
f0102391:	00 
f0102392:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102399:	e8 a2 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f010239e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01023a5:	e8 d7 ec ff ff       	call   f0101081 <page_alloc>
f01023aa:	85 c0                	test   %eax,%eax
f01023ac:	74 04                	je     f01023b2 <mem_init+0xf1c>
f01023ae:	39 c6                	cmp    %eax,%esi
f01023b0:	74 24                	je     f01023d6 <mem_init+0xf40>
f01023b2:	c7 44 24 0c 00 75 10 	movl   $0xf0107500,0xc(%esp)
f01023b9:	f0 
f01023ba:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01023c1:	f0 
f01023c2:	c7 44 24 04 21 04 00 	movl   $0x421,0x4(%esp)
f01023c9:	00 
f01023ca:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01023d1:	e8 6a dc ff ff       	call   f0100040 <_panic>
	cprintf("5");
f01023d6:	c7 04 24 8e 6f 10 f0 	movl   $0xf0106f8e,(%esp)
f01023dd:	e8 4d 1d 00 00       	call   f010412f <cprintf>
	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023e2:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023e9:	00 
f01023ea:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01023ef:	89 04 24             	mov    %eax,(%esp)
f01023f2:	e8 8e ef ff ff       	call   f0101385 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01023f7:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f01023fd:	ba 00 00 00 00       	mov    $0x0,%edx
f0102402:	89 f8                	mov    %edi,%eax
f0102404:	e8 33 e7 ff ff       	call   f0100b3c <check_va2pa>
f0102409:	83 f8 ff             	cmp    $0xffffffff,%eax
f010240c:	74 24                	je     f0102432 <mem_init+0xf9c>
f010240e:	c7 44 24 0c 24 75 10 	movl   $0xf0107524,0xc(%esp)
f0102415:	f0 
f0102416:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010241d:	f0 
f010241e:	c7 44 24 04 25 04 00 	movl   $0x425,0x4(%esp)
f0102425:	00 
f0102426:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010242d:	e8 0e dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102432:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102437:	89 f8                	mov    %edi,%eax
f0102439:	e8 fe e6 ff ff       	call   f0100b3c <check_va2pa>
f010243e:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0102441:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102447:	c1 fa 03             	sar    $0x3,%edx
f010244a:	c1 e2 0c             	shl    $0xc,%edx
f010244d:	39 d0                	cmp    %edx,%eax
f010244f:	74 24                	je     f0102475 <mem_init+0xfdf>
f0102451:	c7 44 24 0c d0 74 10 	movl   $0xf01074d0,0xc(%esp)
f0102458:	f0 
f0102459:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102460:	f0 
f0102461:	c7 44 24 04 26 04 00 	movl   $0x426,0x4(%esp)
f0102468:	00 
f0102469:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102470:	e8 cb db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102475:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102478:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010247d:	74 24                	je     f01024a3 <mem_init+0x100d>
f010247f:	c7 44 24 0c 1f 6f 10 	movl   $0xf0106f1f,0xc(%esp)
f0102486:	f0 
f0102487:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010248e:	f0 
f010248f:	c7 44 24 04 27 04 00 	movl   $0x427,0x4(%esp)
f0102496:	00 
f0102497:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010249e:	e8 9d db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f01024a3:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01024a8:	74 24                	je     f01024ce <mem_init+0x1038>
f01024aa:	c7 44 24 0c 7d 6f 10 	movl   $0xf0106f7d,0xc(%esp)
f01024b1:	f0 
f01024b2:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01024b9:	f0 
f01024ba:	c7 44 24 04 28 04 00 	movl   $0x428,0x4(%esp)
f01024c1:	00 
f01024c2:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01024c9:	e8 72 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024ce:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024d5:	00 
f01024d6:	89 3c 24             	mov    %edi,(%esp)
f01024d9:	e8 a7 ee ff ff       	call   f0101385 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024de:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi
f01024e4:	ba 00 00 00 00       	mov    $0x0,%edx
f01024e9:	89 f8                	mov    %edi,%eax
f01024eb:	e8 4c e6 ff ff       	call   f0100b3c <check_va2pa>
f01024f0:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024f3:	74 24                	je     f0102519 <mem_init+0x1083>
f01024f5:	c7 44 24 0c 24 75 10 	movl   $0xf0107524,0xc(%esp)
f01024fc:	f0 
f01024fd:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102504:	f0 
f0102505:	c7 44 24 04 2c 04 00 	movl   $0x42c,0x4(%esp)
f010250c:	00 
f010250d:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102514:	e8 27 db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102519:	ba 00 10 00 00       	mov    $0x1000,%edx
f010251e:	89 f8                	mov    %edi,%eax
f0102520:	e8 17 e6 ff ff       	call   f0100b3c <check_va2pa>
f0102525:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102528:	74 24                	je     f010254e <mem_init+0x10b8>
f010252a:	c7 44 24 0c 48 75 10 	movl   $0xf0107548,0xc(%esp)
f0102531:	f0 
f0102532:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102539:	f0 
f010253a:	c7 44 24 04 2d 04 00 	movl   $0x42d,0x4(%esp)
f0102541:	00 
f0102542:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102549:	e8 f2 da ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f010254e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102551:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102556:	74 24                	je     f010257c <mem_init+0x10e6>
f0102558:	c7 44 24 0c 90 6f 10 	movl   $0xf0106f90,0xc(%esp)
f010255f:	f0 
f0102560:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102567:	f0 
f0102568:	c7 44 24 04 2e 04 00 	movl   $0x42e,0x4(%esp)
f010256f:	00 
f0102570:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102577:	e8 c4 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010257c:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102581:	74 24                	je     f01025a7 <mem_init+0x1111>
f0102583:	c7 44 24 0c 7d 6f 10 	movl   $0xf0106f7d,0xc(%esp)
f010258a:	f0 
f010258b:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102592:	f0 
f0102593:	c7 44 24 04 2f 04 00 	movl   $0x42f,0x4(%esp)
f010259a:	00 
f010259b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01025a2:	e8 99 da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f01025a7:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025ae:	e8 ce ea ff ff       	call   f0101081 <page_alloc>
f01025b3:	85 c0                	test   %eax,%eax
f01025b5:	74 05                	je     f01025bc <mem_init+0x1126>
f01025b7:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025ba:	74 24                	je     f01025e0 <mem_init+0x114a>
f01025bc:	c7 44 24 0c 70 75 10 	movl   $0xf0107570,0xc(%esp)
f01025c3:	f0 
f01025c4:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01025cb:	f0 
f01025cc:	c7 44 24 04 32 04 00 	movl   $0x432,0x4(%esp)
f01025d3:	00 
f01025d4:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01025db:	e8 60 da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025e0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025e7:	e8 95 ea ff ff       	call   f0101081 <page_alloc>
f01025ec:	85 c0                	test   %eax,%eax
f01025ee:	74 24                	je     f0102614 <mem_init+0x117e>
f01025f0:	c7 44 24 0c c0 6e 10 	movl   $0xf0106ec0,0xc(%esp)
f01025f7:	f0 
f01025f8:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01025ff:	f0 
f0102600:	c7 44 24 04 35 04 00 	movl   $0x435,0x4(%esp)
f0102607:	00 
f0102608:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010260f:	e8 2c da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102614:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102619:	8b 08                	mov    (%eax),%ecx
f010261b:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f0102621:	89 da                	mov    %ebx,%edx
f0102623:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f0102629:	c1 fa 03             	sar    $0x3,%edx
f010262c:	c1 e2 0c             	shl    $0xc,%edx
f010262f:	39 d1                	cmp    %edx,%ecx
f0102631:	74 24                	je     f0102657 <mem_init+0x11c1>
f0102633:	c7 44 24 0c 80 72 10 	movl   $0xf0107280,0xc(%esp)
f010263a:	f0 
f010263b:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102642:	f0 
f0102643:	c7 44 24 04 38 04 00 	movl   $0x438,0x4(%esp)
f010264a:	00 
f010264b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102652:	e8 e9 d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102657:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010265d:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102662:	74 24                	je     f0102688 <mem_init+0x11f2>
f0102664:	c7 44 24 0c 30 6f 10 	movl   $0xf0106f30,0xc(%esp)
f010266b:	f0 
f010266c:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102673:	f0 
f0102674:	c7 44 24 04 3a 04 00 	movl   $0x43a,0x4(%esp)
f010267b:	00 
f010267c:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102683:	e8 b8 d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0102688:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
	cprintf("6");
f010268e:	c7 04 24 a1 6f 10 f0 	movl   $0xf0106fa1,(%esp)
f0102695:	e8 95 1a 00 00       	call   f010412f <cprintf>
	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010269a:	89 1c 24             	mov    %ebx,(%esp)
f010269d:	e8 64 ea ff ff       	call   f0101106 <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f01026a2:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01026a9:	00 
f01026aa:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f01026b1:	00 
f01026b2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01026b7:	89 04 24             	mov    %eax,(%esp)
f01026ba:	e8 85 ea ff ff       	call   f0101144 <pgdir_walk>
f01026bf:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026c2:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026c5:	8b 15 8c 3e 22 f0    	mov    0xf0223e8c,%edx
f01026cb:	8b 7a 04             	mov    0x4(%edx),%edi
f01026ce:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026d4:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f01026da:	89 f8                	mov    %edi,%eax
f01026dc:	c1 e8 0c             	shr    $0xc,%eax
f01026df:	39 c8                	cmp    %ecx,%eax
f01026e1:	72 20                	jb     f0102703 <mem_init+0x126d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026e3:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01026e7:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01026ee:	f0 
f01026ef:	c7 44 24 04 41 04 00 	movl   $0x441,0x4(%esp)
f01026f6:	00 
f01026f7:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01026fe:	e8 3d d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f0102703:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f0102709:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f010270c:	74 24                	je     f0102732 <mem_init+0x129c>
f010270e:	c7 44 24 0c a3 6f 10 	movl   $0xf0106fa3,0xc(%esp)
f0102715:	f0 
f0102716:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010271d:	f0 
f010271e:	c7 44 24 04 42 04 00 	movl   $0x442,0x4(%esp)
f0102725:	00 
f0102726:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010272d:	e8 0e d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102732:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f0102739:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010273f:	89 d8                	mov    %ebx,%eax
f0102741:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0102747:	c1 f8 03             	sar    $0x3,%eax
f010274a:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010274d:	89 c2                	mov    %eax,%edx
f010274f:	c1 ea 0c             	shr    $0xc,%edx
f0102752:	39 d1                	cmp    %edx,%ecx
f0102754:	77 20                	ja     f0102776 <mem_init+0x12e0>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102756:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010275a:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0102761:	f0 
f0102762:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0102769:	00 
f010276a:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0102771:	e8 ca d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102776:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010277d:	00 
f010277e:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102785:	00 
	return (void *)(pa + KERNBASE);
f0102786:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010278b:	89 04 24             	mov    %eax,(%esp)
f010278e:	e8 16 32 00 00       	call   f01059a9 <memset>
	page_free(pp0);
f0102793:	89 1c 24             	mov    %ebx,(%esp)
f0102796:	e8 6b e9 ff ff       	call   f0101106 <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f010279b:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01027a2:	00 
f01027a3:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01027aa:	00 
f01027ab:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01027b0:	89 04 24             	mov    %eax,(%esp)
f01027b3:	e8 8c e9 ff ff       	call   f0101144 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01027b8:	89 da                	mov    %ebx,%edx
f01027ba:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01027c0:	c1 fa 03             	sar    $0x3,%edx
f01027c3:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027c6:	89 d0                	mov    %edx,%eax
f01027c8:	c1 e8 0c             	shr    $0xc,%eax
f01027cb:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01027d1:	72 20                	jb     f01027f3 <mem_init+0x135d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027d3:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027d7:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01027de:	f0 
f01027df:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027e6:	00 
f01027e7:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01027ee:	e8 4d d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027f3:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027f9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01027fc:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f0102803:	75 11                	jne    f0102816 <mem_init+0x1380>
f0102805:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f010280b:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0102811:	f6 00 01             	testb  $0x1,(%eax)
f0102814:	74 24                	je     f010283a <mem_init+0x13a4>
f0102816:	c7 44 24 0c bb 6f 10 	movl   $0xf0106fbb,0xc(%esp)
f010281d:	f0 
f010281e:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102825:	f0 
f0102826:	c7 44 24 04 4c 04 00 	movl   $0x44c,0x4(%esp)
f010282d:	00 
f010282e:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102835:	e8 06 d8 ff ff       	call   f0100040 <_panic>
f010283a:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f010283d:	39 d0                	cmp    %edx,%eax
f010283f:	75 d0                	jne    f0102811 <mem_init+0x137b>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102841:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102846:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010284c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
	cprintf("7");
f0102852:	c7 04 24 d2 6f 10 f0 	movl   $0xf0106fd2,(%esp)
f0102859:	e8 d1 18 00 00       	call   f010412f <cprintf>
	// give free list back
	page_free_list = fl;
f010285e:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102861:	a3 40 32 22 f0       	mov    %eax,0xf0223240

	// free the pages we took
	page_free(pp0);
f0102866:	89 1c 24             	mov    %ebx,(%esp)
f0102869:	e8 98 e8 ff ff       	call   f0101106 <page_free>
	page_free(pp1);
f010286e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102871:	89 04 24             	mov    %eax,(%esp)
f0102874:	e8 8d e8 ff ff       	call   f0101106 <page_free>
	page_free(pp2);
f0102879:	89 34 24             	mov    %esi,(%esp)
f010287c:	e8 85 e8 ff ff       	call   f0101106 <page_free>

	cprintf("check_page() succeeded!\n");
f0102881:	c7 04 24 d4 6f 10 f0 	movl   $0xf0106fd4,(%esp)
f0102888:	e8 a2 18 00 00       	call   f010412f <cprintf>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f010288d:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0102893:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f010289a:	89 c2                	mov    %eax,%edx
f010289c:	81 e2 ff 0f 00 00    	and    $0xfff,%edx
f01028a2:	39 d0                	cmp    %edx,%eax
f01028a4:	0f 84 f1 0b 00 00    	je     f010349b <mem_init+0x2005>
	{

		page_insert(kern_pgdir, pa2page(PADDR(pages)+i),(void*) (UPAGES+i), PTE_U);
f01028aa:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028af:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028b4:	76 21                	jbe    f01028d7 <mem_init+0x1441>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f01028b6:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028bc:	c1 ea 0c             	shr    $0xc,%edx
f01028bf:	39 d1                	cmp    %edx,%ecx
f01028c1:	77 5e                	ja     f0102921 <mem_init+0x148b>
f01028c3:	eb 40                	jmp    f0102905 <mem_init+0x146f>
f01028c5:	8d b3 00 00 00 ef    	lea    -0x11000000(%ebx),%esi
f01028cb:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028d0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028d5:	77 20                	ja     f01028f7 <mem_init+0x1461>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028db:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f01028e2:	f0 
f01028e3:	c7 44 24 04 b7 00 00 	movl   $0xb7,0x4(%esp)
f01028ea:	00 
f01028eb:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01028f2:	e8 49 d7 ff ff       	call   f0100040 <_panic>
f01028f7:	8d 94 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%edx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01028fe:	c1 ea 0c             	shr    $0xc,%edx
f0102901:	39 d1                	cmp    %edx,%ecx
f0102903:	77 26                	ja     f010292b <mem_init+0x1495>
		panic("pa2page called with invalid pa");
f0102905:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f010290c:	f0 
f010290d:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102914:	00 
f0102915:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f010291c:	e8 1f d7 ff ff       	call   f0100040 <_panic>
f0102921:	be 00 00 00 ef       	mov    $0xef000000,%esi
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f0102926:	bb 00 00 00 00       	mov    $0x0,%ebx
	{

		page_insert(kern_pgdir, pa2page(PADDR(pages)+i),(void*) (UPAGES+i), PTE_U);
f010292b:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0102932:	00 
f0102933:	89 74 24 08          	mov    %esi,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102937:	8d 04 d0             	lea    (%eax,%edx,8),%eax
f010293a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010293e:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102943:	89 04 24             	mov    %eax,(%esp)
f0102946:	e8 8a ea ff ff       	call   f01013d5 <page_insert>
	// Permissions:
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	for(i=0;i<ROUNDUP(npages*sizeof(struct Page),PGSIZE);i+=PGSIZE)
f010294b:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102951:	89 da                	mov    %ebx,%edx
f0102953:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0102959:	8d 04 cd ff 0f 00 00 	lea    0xfff(,%ecx,8),%eax
f0102960:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102965:	39 c3                	cmp    %eax,%ebx
f0102967:	0f 82 58 ff ff ff    	jb     f01028c5 <mem_init+0x142f>
f010296d:	e9 29 0b 00 00       	jmp    f010349b <mem_init+0x2005>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102972:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102977:	c1 e8 0c             	shr    $0xc,%eax
f010297a:	39 05 88 3e 22 f0    	cmp    %eax,0xf0223e88
f0102980:	0f 87 b9 0b 00 00    	ja     f010353f <mem_init+0x20a9>
f0102986:	eb 44                	jmp    f01029cc <mem_init+0x1536>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f0102988:	8d 8a 00 00 c0 ee    	lea    -0x11400000(%edx),%ecx
f010298e:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102993:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102998:	77 20                	ja     f01029ba <mem_init+0x1524>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010299a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010299e:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f01029a5:	f0 
f01029a6:	c7 44 24 04 c7 00 00 	movl   $0xc7,0x4(%esp)
f01029ad:	00 
f01029ae:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01029b5:	e8 86 d6 ff ff       	call   f0100040 <_panic>
f01029ba:	8d 84 10 00 00 00 10 	lea    0x10000000(%eax,%edx,1),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01029c1:	c1 e8 0c             	shr    $0xc,%eax
f01029c4:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f01029ca:	72 1c                	jb     f01029e8 <mem_init+0x1552>
		panic("pa2page called with invalid pa");
f01029cc:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f01029d3:	f0 
f01029d4:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f01029db:	00 
f01029dc:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01029e3:	e8 58 d6 ff ff       	call   f0100040 <_panic>
f01029e8:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f01029ef:	00 
f01029f0:	89 4c 24 08          	mov    %ecx,0x8(%esp)
	return &pages[PGNUM(pa)];
f01029f4:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f01029fa:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f01029fd:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102a01:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102a06:	89 04 24             	mov    %eax,(%esp)
f0102a09:	e8 c7 e9 ff ff       	call   f01013d5 <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0102a0e:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102a14:	89 da                	mov    %ebx,%edx
f0102a16:	81 fb 00 f0 01 00    	cmp    $0x1f000,%ebx
f0102a1c:	0f 85 66 ff ff ff    	jne    f0102988 <mem_init+0x14f2>
f0102a22:	e9 89 0a 00 00       	jmp    f01034b0 <mem_init+0x201a>
static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102a27:	b8 00 60 11 00       	mov    $0x116000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102a2c:	c1 e8 0c             	shr    $0xc,%eax
f0102a2f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0102a35:	0f 82 c2 0a 00 00    	jb     f01034fd <mem_init+0x2067>
f0102a3b:	eb 36                	jmp    f0102a73 <mem_init+0x15dd>
f0102a3d:	8d 14 33             	lea    (%ebx,%esi,1),%edx
f0102a40:	89 f0                	mov    %esi,%eax
f0102a42:	c1 e8 0c             	shr    $0xc,%eax
f0102a45:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0102a4b:	72 42                	jb     f0102a8f <mem_init+0x15f9>
f0102a4d:	eb 24                	jmp    f0102a73 <mem_init+0x15dd>

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a4f:	c7 44 24 0c 00 60 11 	movl   $0xf0116000,0xc(%esp)
f0102a56:	f0 
f0102a57:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0102a5e:	f0 
f0102a5f:	c7 44 24 04 d9 00 00 	movl   $0xd9,0x4(%esp)
f0102a66:	00 
f0102a67:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102a6e:	e8 cd d5 ff ff       	call   f0100040 <_panic>

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
f0102a73:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0102a7a:	f0 
f0102a7b:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102a82:	00 
f0102a83:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0102a8a:	e8 b1 d5 ff ff       	call   f0100040 <_panic>
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
f0102a8f:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102a96:	00 
f0102a97:	89 54 24 08          	mov    %edx,0x8(%esp)
	return &pages[PGNUM(pa)];
f0102a9b:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0102aa1:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0102aa4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102aa8:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102aad:	89 04 24             	mov    %eax,(%esp)
f0102ab0:	e8 20 e9 ff ff       	call   f01013d5 <page_insert>
f0102ab5:	81 c6 00 10 00 00    	add    $0x1000,%esi
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f0102abb:	39 fe                	cmp    %edi,%esi
f0102abd:	0f 85 7a ff ff ff    	jne    f0102a3d <mem_init+0x15a7>
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102ac3:	b8 00 00 00 00       	mov    $0x0,%eax
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
f0102ac8:	bb 00 00 00 00       	mov    $0x0,%ebx
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
    {
    	if(i<npages*PGSIZE)
f0102acd:	8b 15 88 3e 22 f0    	mov    0xf0223e88,%edx
f0102ad3:	89 d1                	mov    %edx,%ecx
f0102ad5:	c1 e1 0c             	shl    $0xc,%ecx
f0102ad8:	39 c1                	cmp    %eax,%ecx
f0102ada:	0f 86 88 00 00 00    	jbe    f0102b68 <mem_init+0x16d2>
    	{
    		page_insert(kern_pgdir,pa2page(i),(void*)(KERNBASE+i),PTE_W);
f0102ae0:	8d 88 00 00 00 f0    	lea    -0x10000000(%eax),%ecx
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102ae6:	c1 e8 0c             	shr    $0xc,%eax
f0102ae9:	89 c6                	mov    %eax,%esi
f0102aeb:	39 c2                	cmp    %eax,%edx
f0102aed:	77 1c                	ja     f0102b0b <mem_init+0x1675>
		panic("pa2page called with invalid pa");
f0102aef:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0102af6:	f0 
f0102af7:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102afe:	00 
f0102aff:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0102b06:	e8 35 d5 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b0b:	8d 3c c5 00 00 00 00 	lea    0x0(,%eax,8),%edi
f0102b12:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102b19:	00 
f0102b1a:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0102b1e:	89 f8                	mov    %edi,%eax
f0102b20:	03 05 90 3e 22 f0    	add    0xf0223e90,%eax
f0102b26:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102b2a:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102b2f:	89 04 24             	mov    %eax,(%esp)
f0102b32:	e8 9e e8 ff ff       	call   f01013d5 <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b37:	3b 35 88 3e 22 f0    	cmp    0xf0223e88,%esi
f0102b3d:	72 1c                	jb     f0102b5b <mem_init+0x16c5>
		panic("pa2page called with invalid pa");
f0102b3f:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0102b46:	f0 
f0102b47:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b4e:	00 
f0102b4f:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0102b56:	e8 e5 d4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102b5b:	03 3d 90 3e 22 f0    	add    0xf0223e90,%edi
    		pa2page(i)->pp_ref--;
f0102b61:	66 83 6f 04 01       	subw   $0x1,0x4(%edi)
f0102b66:	eb 76                	jmp    f0102bde <mem_init+0x1748>
    	}
    	else
    	{
    		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
f0102b68:	2d 00 00 00 10       	sub    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102b6d:	85 d2                	test   %edx,%edx
f0102b6f:	75 1c                	jne    f0102b8d <mem_init+0x16f7>
		panic("pa2page called with invalid pa");
f0102b71:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0102b78:	f0 
f0102b79:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102b80:	00 
f0102b81:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0102b88:	e8 b3 d4 ff ff       	call   f0100040 <_panic>
f0102b8d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102b94:	00 
f0102b95:	89 44 24 08          	mov    %eax,0x8(%esp)
f0102b99:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0102b9e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102ba2:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102ba7:	89 04 24             	mov    %eax,(%esp)
f0102baa:	e8 26 e8 ff ff       	call   f01013d5 <page_insert>
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0102baf:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f0102bb6:	75 1c                	jne    f0102bd4 <mem_init+0x173e>
		panic("pa2page called with invalid pa");
f0102bb8:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0102bbf:	f0 
f0102bc0:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0102bc7:	00 
f0102bc8:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0102bcf:	e8 6c d4 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0102bd4:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
    		pa2page(0)->pp_ref--;
f0102bd9:	66 83 68 04 01       	subw   $0x1,0x4(%eax)
	// We might not have 2^32 - KERNBASE bytes of physical memory, but
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
//<<<<<<< HEAD
    for(i=0;i<0xffffffff-KERNBASE;i+=PGSIZE)
f0102bde:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102be4:	89 d8                	mov    %ebx,%eax
f0102be6:	81 fb 00 00 00 10    	cmp    $0x10000000,%ebx
f0102bec:	0f 85 db fe ff ff    	jne    f0102acd <mem_init+0x1637>
    	{
    		page_insert(kern_pgdir,pa2page(0),(void*)(KERNBASE+i),PTE_W);
    		pa2page(0)->pp_ref--;
    	}
    }
    cprintf("%d\r\n",page_free_list->pp_ref);
f0102bf2:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f0102bf7:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f0102bfb:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102bff:	c7 04 24 95 77 10 f0 	movl   $0xf0107795,(%esp)
f0102c06:	e8 24 15 00 00       	call   f010412f <cprintf>
    cprintf("3\r\n");
f0102c0b:	c7 04 24 ed 6f 10 f0 	movl   $0xf0106fed,(%esp)
f0102c12:	e8 18 15 00 00       	call   f010412f <cprintf>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f0102c17:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102c1e:	00 
f0102c1f:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f0102c26:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f0102c2b:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f0102c30:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102c35:	e8 14 e6 ff ff       	call   f010124e <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c3a:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
f0102c3f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102c44:	0f 87 7c 08 00 00    	ja     f01034c6 <mem_init+0x2030>
f0102c4a:	eb 0c                	jmp    f0102c58 <mem_init+0x17c2>
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
f0102c4c:	89 d8                	mov    %ebx,%eax
f0102c4e:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102c54:	77 27                	ja     f0102c7d <mem_init+0x17e7>
f0102c56:	eb 05                	jmp    f0102c5d <mem_init+0x17c7>
f0102c58:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c5d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102c61:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0102c68:	f0 
f0102c69:	c7 44 24 04 3a 01 00 	movl   $0x13a,0x4(%esp)
f0102c70:	00 
f0102c71:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102c78:	e8 c3 d3 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f0102c7d:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102c84:	00 
f0102c85:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102c8b:	89 04 24             	mov    %eax,(%esp)
f0102c8e:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102c93:	89 f2                	mov    %esi,%edx
f0102c95:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0102c9a:	e8 af e5 ff ff       	call   f010124e <boot_map_region>
f0102c9f:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102ca5:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	//
	// LAB 4: Your code here:
	   	int cpu_i;
	uintptr_t stk_i;
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
f0102cab:	39 fb                	cmp    %edi,%ebx
f0102cad:	75 9d                	jne    f0102c4c <mem_init+0x17b6>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102caf:	8b 3d 8c 3e 22 f0    	mov    0xf0223e8c,%edi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102cb5:	a1 88 3e 22 f0       	mov    0xf0223e88,%eax
f0102cba:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102cbd:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102cc4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102cc9:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102ccc:	75 30                	jne    f0102cfe <mem_init+0x1868>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102cce:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102cd4:	89 de                	mov    %ebx,%esi
f0102cd6:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102cdb:	89 f8                	mov    %edi,%eax
f0102cdd:	e8 5a de ff ff       	call   f0100b3c <check_va2pa>
f0102ce2:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102ce8:	0f 86 94 00 00 00    	jbe    f0102d82 <mem_init+0x18ec>
f0102cee:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102cf3:	81 c6 00 00 40 21    	add    $0x21400000,%esi
f0102cf9:	e9 a4 00 00 00       	jmp    f0102da2 <mem_init+0x190c>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102cfe:	8b 1d 90 3e 22 f0    	mov    0xf0223e90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102d04:	8d b3 00 00 00 10    	lea    0x10000000(%ebx),%esi
f0102d0a:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102d0f:	89 f8                	mov    %edi,%eax
f0102d11:	e8 26 de ff ff       	call   f0100b3c <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102d16:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102d1c:	77 20                	ja     f0102d3e <mem_init+0x18a8>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102d1e:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102d22:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0102d29:	f0 
f0102d2a:	c7 44 24 04 7b 03 00 	movl   $0x37b,0x4(%esp)
f0102d31:	00 
f0102d32:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102d39:	e8 02 d3 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102d3e:	ba 00 00 00 00       	mov    $0x0,%edx
f0102d43:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102d46:	39 c8                	cmp    %ecx,%eax
f0102d48:	74 24                	je     f0102d6e <mem_init+0x18d8>
f0102d4a:	c7 44 24 0c 94 75 10 	movl   $0xf0107594,0xc(%esp)
f0102d51:	f0 
f0102d52:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102d59:	f0 
f0102d5a:	c7 44 24 04 7b 03 00 	movl   $0x37b,0x4(%esp)
f0102d61:	00 
f0102d62:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102d69:	e8 d2 d2 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102d6e:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102d74:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0102d77:	0f 87 18 08 00 00    	ja     f0103595 <mem_init+0x20ff>
f0102d7d:	e9 4c ff ff ff       	jmp    f0102cce <mem_init+0x1838>
f0102d82:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102d86:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0102d8d:	f0 
f0102d8e:	c7 44 24 04 80 03 00 	movl   $0x380,0x4(%esp)
f0102d95:	00 
f0102d96:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102d9d:	e8 9e d2 ff ff       	call   f0100040 <_panic>
f0102da2:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102da5:	39 c2                	cmp    %eax,%edx
f0102da7:	74 24                	je     f0102dcd <mem_init+0x1937>
f0102da9:	c7 44 24 0c c8 75 10 	movl   $0xf01075c8,0xc(%esp)
f0102db0:	f0 
f0102db1:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102db8:	f0 
f0102db9:	c7 44 24 04 80 03 00 	movl   $0x380,0x4(%esp)
f0102dc0:	00 
f0102dc1:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102dc8:	e8 73 d2 ff ff       	call   f0100040 <_panic>
f0102dcd:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102dd3:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102dd9:	0f 85 a7 07 00 00    	jne    f0103586 <mem_init+0x20f0>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102ddf:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0102de2:	c1 e6 0c             	shl    $0xc,%esi
f0102de5:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102dea:	85 f6                	test   %esi,%esi
f0102dec:	75 07                	jne    f0102df5 <mem_init+0x195f>
f0102dee:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102df3:	eb 41                	jmp    f0102e36 <mem_init+0x19a0>
f0102df5:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
	{

		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102dfb:	89 f8                	mov    %edi,%eax
f0102dfd:	e8 3a dd ff ff       	call   f0100b3c <check_va2pa>
f0102e02:	39 c3                	cmp    %eax,%ebx
f0102e04:	74 24                	je     f0102e2a <mem_init+0x1994>
f0102e06:	c7 44 24 0c fc 75 10 	movl   $0xf01075fc,0xc(%esp)
f0102e0d:	f0 
f0102e0e:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102e15:	f0 
f0102e16:	c7 44 24 04 86 03 00 	movl   $0x386,0x4(%esp)
f0102e1d:	00 
f0102e1e:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102e25:	e8 16 d2 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102e2a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102e30:	39 de                	cmp    %ebx,%esi
f0102e32:	77 c1                	ja     f0102df5 <mem_init+0x195f>
f0102e34:	eb b8                	jmp    f0102dee <mem_init+0x1958>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
	}

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102e36:	89 da                	mov    %ebx,%edx
f0102e38:	89 f8                	mov    %edi,%eax
f0102e3a:	e8 fd dc ff ff       	call   f0100b3c <check_va2pa>
f0102e3f:	39 c3                	cmp    %eax,%ebx
f0102e41:	74 24                	je     f0102e67 <mem_init+0x19d1>
f0102e43:	c7 44 24 0c f1 6f 10 	movl   $0xf0106ff1,0xc(%esp)
f0102e4a:	f0 
f0102e4b:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102e52:	f0 
f0102e53:	c7 44 24 04 8b 03 00 	movl   $0x38b,0x4(%esp)
f0102e5a:	00 
f0102e5b:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102e62:	e8 d9 d1 ff ff       	call   f0100040 <_panic>

		assert(check_va2pa(pgdir, KERNBASE + i) == i);
	}

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102e67:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102e6d:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102e73:	75 c1                	jne    f0102e36 <mem_init+0x19a0>
f0102e75:	c7 45 d0 00 50 22 f0 	movl   $0xf0225000,-0x30(%ebp)
f0102e7c:	c7 45 cc 00 00 00 00 	movl   $0x0,-0x34(%ebp)
f0102e83:	be 00 80 bf ef       	mov    $0xefbf8000,%esi
f0102e88:	b8 00 50 22 f0       	mov    $0xf0225000,%eax
f0102e8d:	05 00 80 40 20       	add    $0x20408000,%eax
f0102e92:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102e95:	8d 86 00 80 00 00    	lea    0x8000(%esi),%eax
f0102e9b:	89 45 d4             	mov    %eax,-0x2c(%ebp)
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102e9e:	89 f2                	mov    %esi,%edx
f0102ea0:	89 f8                	mov    %edi,%eax
f0102ea2:	e8 95 dc ff ff       	call   f0100b3c <check_va2pa>
f0102ea7:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102eaa:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102eb0:	77 20                	ja     f0102ed2 <mem_init+0x1a3c>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102eb2:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102eb6:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0102ebd:	f0 
f0102ebe:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
f0102ec5:	00 
f0102ec6:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102ecd:	e8 6e d1 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102ed2:	89 f3                	mov    %esi,%ebx
f0102ed4:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f0102ed7:	03 4d cc             	add    -0x34(%ebp),%ecx
f0102eda:	89 75 c8             	mov    %esi,-0x38(%ebp)
f0102edd:	89 ce                	mov    %ecx,%esi
f0102edf:	8d 14 1e             	lea    (%esi,%ebx,1),%edx
f0102ee2:	39 d0                	cmp    %edx,%eax
f0102ee4:	74 24                	je     f0102f0a <mem_init+0x1a74>
f0102ee6:	c7 44 24 0c 24 76 10 	movl   $0xf0107624,0xc(%esp)
f0102eed:	f0 
f0102eee:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102ef5:	f0 
f0102ef6:	c7 44 24 04 9c 03 00 	movl   $0x39c,0x4(%esp)
f0102efd:	00 
f0102efe:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102f05:	e8 36 d1 ff ff       	call   f0100040 <_panic>
f0102f0a:	81 c3 00 10 00 00    	add    $0x1000,%ebx
//			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102f10:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0102f13:	0f 85 5f 06 00 00    	jne    f0103578 <mem_init+0x20e2>
f0102f19:	8b 75 c8             	mov    -0x38(%ebp),%esi
f0102f1c:	8d 9e 00 80 ff ff    	lea    -0x8000(%esi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102f22:	89 da                	mov    %ebx,%edx
f0102f24:	89 f8                	mov    %edi,%eax
f0102f26:	e8 11 dc ff ff       	call   f0100b3c <check_va2pa>
f0102f2b:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102f2e:	74 24                	je     f0102f54 <mem_init+0x1abe>
f0102f30:	c7 44 24 0c 6c 76 10 	movl   $0xf010766c,0xc(%esp)
f0102f37:	f0 
f0102f38:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102f3f:	f0 
f0102f40:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f0102f47:	00 
f0102f48:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102f4f:	e8 ec d0 ff ff       	call   f0100040 <_panic>
f0102f54:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102f5a:	39 f3                	cmp    %esi,%ebx
f0102f5c:	75 c4                	jne    f0102f22 <mem_init+0x1a8c>
f0102f5e:	81 ee 00 00 01 00    	sub    $0x10000,%esi
f0102f64:	81 45 cc 00 80 01 00 	addl   $0x18000,-0x34(%ebp)
f0102f6b:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
//
//	}
//			assert(check_va2pa(pgdir, KSTACKTOP - PTSIZE) == ~0);
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102f72:	81 fe 00 80 b7 ef    	cmp    $0xefb78000,%esi
f0102f78:	0f 85 17 ff ff ff    	jne    f0102e95 <mem_init+0x19ff>
f0102f7e:	b8 00 00 00 00       	mov    $0x0,%eax
	}
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102f83:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102f89:	83 fa 03             	cmp    $0x3,%edx
f0102f8c:	77 2e                	ja     f0102fbc <mem_init+0x1b26>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102f8e:	f6 04 87 01          	testb  $0x1,(%edi,%eax,4)
f0102f92:	0f 85 aa 00 00 00    	jne    f0103042 <mem_init+0x1bac>
f0102f98:	c7 44 24 0c 0c 70 10 	movl   $0xf010700c,0xc(%esp)
f0102f9f:	f0 
f0102fa0:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102fa7:	f0 
f0102fa8:	c7 44 24 04 a9 03 00 	movl   $0x3a9,0x4(%esp)
f0102faf:	00 
f0102fb0:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102fb7:	e8 84 d0 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102fbc:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102fc1:	76 55                	jbe    f0103018 <mem_init+0x1b82>
				assert(pgdir[i] & PTE_P);
f0102fc3:	8b 14 87             	mov    (%edi,%eax,4),%edx
f0102fc6:	f6 c2 01             	test   $0x1,%dl
f0102fc9:	75 24                	jne    f0102fef <mem_init+0x1b59>
f0102fcb:	c7 44 24 0c 0c 70 10 	movl   $0xf010700c,0xc(%esp)
f0102fd2:	f0 
f0102fd3:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0102fda:	f0 
f0102fdb:	c7 44 24 04 ad 03 00 	movl   $0x3ad,0x4(%esp)
f0102fe2:	00 
f0102fe3:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0102fea:	e8 51 d0 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102fef:	f6 c2 02             	test   $0x2,%dl
f0102ff2:	75 4e                	jne    f0103042 <mem_init+0x1bac>
f0102ff4:	c7 44 24 0c 1d 70 10 	movl   $0xf010701d,0xc(%esp)
f0102ffb:	f0 
f0102ffc:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103003:	f0 
f0103004:	c7 44 24 04 ae 03 00 	movl   $0x3ae,0x4(%esp)
f010300b:	00 
f010300c:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103013:	e8 28 d0 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0103018:	83 3c 87 00          	cmpl   $0x0,(%edi,%eax,4)
f010301c:	74 24                	je     f0103042 <mem_init+0x1bac>
f010301e:	c7 44 24 0c 2e 70 10 	movl   $0xf010702e,0xc(%esp)
f0103025:	f0 
f0103026:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010302d:	f0 
f010302e:	c7 44 24 04 b0 03 00 	movl   $0x3b0,0x4(%esp)
f0103035:	00 
f0103036:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010303d:	e8 fe cf ff ff       	call   f0100040 <_panic>
			assert(check_va2pa(pgdir, base + i) == ~0);
	}
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0103042:	83 c0 01             	add    $0x1,%eax
f0103045:	3d 00 04 00 00       	cmp    $0x400,%eax
f010304a:	0f 85 33 ff ff ff    	jne    f0102f83 <mem_init+0x1aed>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0103050:	c7 04 24 90 76 10 f0 	movl   $0xf0107690,(%esp)
f0103057:	e8 d3 10 00 00       	call   f010412f <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f010305c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0103061:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103066:	77 20                	ja     f0103088 <mem_init+0x1bf2>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103068:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010306c:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103073:	f0 
f0103074:	c7 44 24 04 07 01 00 	movl   $0x107,0x4(%esp)
f010307b:	00 
f010307c:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103083:	e8 b8 cf ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103088:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010308d:	0f 22 d8             	mov    %eax,%cr3
	cprintf("env_id:%d\r\n",(((struct Env*)UENVS)[0]).env_id);
f0103090:	a1 48 00 c0 ee       	mov    0xeec00048,%eax
f0103095:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103099:	c7 04 24 3c 70 10 f0 	movl   $0xf010703c,(%esp)
f01030a0:	e8 8a 10 00 00       	call   f010412f <cprintf>
	cprintf("%d\r\n",page_free_list->pp_ref);
f01030a5:	a1 40 32 22 f0       	mov    0xf0223240,%eax
f01030aa:	0f b7 40 04          	movzwl 0x4(%eax),%eax
f01030ae:	89 44 24 04          	mov    %eax,0x4(%esp)
f01030b2:	c7 04 24 95 77 10 f0 	movl   $0xf0107795,(%esp)
f01030b9:	e8 71 10 00 00       	call   f010412f <cprintf>
	check_page_free_list(0);
f01030be:	b8 00 00 00 00       	mov    $0x0,%eax
f01030c3:	e8 e3 da ff ff       	call   f0100bab <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f01030c8:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f01030cb:	83 e0 f3             	and    $0xfffffff3,%eax
f01030ce:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f01030d3:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f01030d6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01030dd:	e8 9f df ff ff       	call   f0101081 <page_alloc>
f01030e2:	89 c3                	mov    %eax,%ebx
f01030e4:	85 c0                	test   %eax,%eax
f01030e6:	75 24                	jne    f010310c <mem_init+0x1c76>
f01030e8:	c7 44 24 0c 15 6e 10 	movl   $0xf0106e15,0xc(%esp)
f01030ef:	f0 
f01030f0:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01030f7:	f0 
f01030f8:	c7 44 24 04 67 04 00 	movl   $0x467,0x4(%esp)
f01030ff:	00 
f0103100:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103107:	e8 34 cf ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f010310c:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103113:	e8 69 df ff ff       	call   f0101081 <page_alloc>
f0103118:	89 c7                	mov    %eax,%edi
f010311a:	85 c0                	test   %eax,%eax
f010311c:	75 24                	jne    f0103142 <mem_init+0x1cac>
f010311e:	c7 44 24 0c 2b 6e 10 	movl   $0xf0106e2b,0xc(%esp)
f0103125:	f0 
f0103126:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010312d:	f0 
f010312e:	c7 44 24 04 68 04 00 	movl   $0x468,0x4(%esp)
f0103135:	00 
f0103136:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010313d:	e8 fe ce ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0103142:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0103149:	e8 33 df ff ff       	call   f0101081 <page_alloc>
f010314e:	89 c6                	mov    %eax,%esi
f0103150:	85 c0                	test   %eax,%eax
f0103152:	75 24                	jne    f0103178 <mem_init+0x1ce2>
f0103154:	c7 44 24 0c 41 6e 10 	movl   $0xf0106e41,0xc(%esp)
f010315b:	f0 
f010315c:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103163:	f0 
f0103164:	c7 44 24 04 69 04 00 	movl   $0x469,0x4(%esp)
f010316b:	00 
f010316c:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103173:	e8 c8 ce ff ff       	call   f0100040 <_panic>
	page_free(pp0);
f0103178:	89 1c 24             	mov    %ebx,(%esp)
f010317b:	e8 86 df ff ff       	call   f0101106 <page_free>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103180:	89 f8                	mov    %edi,%eax
f0103182:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0103188:	c1 f8 03             	sar    $0x3,%eax
f010318b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010318e:	89 c2                	mov    %eax,%edx
f0103190:	c1 ea 0c             	shr    $0xc,%edx
f0103193:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0103199:	72 20                	jb     f01031bb <mem_init+0x1d25>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010319b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010319f:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01031a6:	f0 
f01031a7:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01031ae:	00 
f01031af:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f01031b6:	e8 85 ce ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp1), 1, PGSIZE);
f01031bb:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01031c2:	00 
f01031c3:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01031ca:	00 
	return (void *)(pa + KERNBASE);
f01031cb:	2d 00 00 00 10       	sub    $0x10000000,%eax
f01031d0:	89 04 24             	mov    %eax,(%esp)
f01031d3:	e8 d1 27 00 00       	call   f01059a9 <memset>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01031d8:	89 f0                	mov    %esi,%eax
f01031da:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f01031e0:	c1 f8 03             	sar    $0x3,%eax
f01031e3:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01031e6:	89 c2                	mov    %eax,%edx
f01031e8:	c1 ea 0c             	shr    $0xc,%edx
f01031eb:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f01031f1:	72 20                	jb     f0103213 <mem_init+0x1d7d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01031f3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01031f7:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01031fe:	f0 
f01031ff:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103206:	00 
f0103207:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f010320e:	e8 2d ce ff ff       	call   f0100040 <_panic>
	memset(page2kva(pp2), 2, PGSIZE);
f0103213:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010321a:	00 
f010321b:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0103222:	00 
	return (void *)(pa + KERNBASE);
f0103223:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0103228:	89 04 24             	mov    %eax,(%esp)
f010322b:	e8 79 27 00 00       	call   f01059a9 <memset>

	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0103230:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103237:	00 
f0103238:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010323f:	00 
f0103240:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103244:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0103249:	89 04 24             	mov    %eax,(%esp)
f010324c:	e8 84 e1 ff ff       	call   f01013d5 <page_insert>

	assert(pp1->pp_ref == 1);
f0103251:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0103256:	74 24                	je     f010327c <mem_init+0x1de6>
f0103258:	c7 44 24 0c 1f 6f 10 	movl   $0xf0106f1f,0xc(%esp)
f010325f:	f0 
f0103260:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103267:	f0 
f0103268:	c7 44 24 04 70 04 00 	movl   $0x470,0x4(%esp)
f010326f:	00 
f0103270:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103277:	e8 c4 cd ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f010327c:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0103283:	01 01 01 
f0103286:	74 24                	je     f01032ac <mem_init+0x1e16>
f0103288:	c7 44 24 0c b0 76 10 	movl   $0xf01076b0,0xc(%esp)
f010328f:	f0 
f0103290:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103297:	f0 
f0103298:	c7 44 24 04 71 04 00 	movl   $0x471,0x4(%esp)
f010329f:	00 
f01032a0:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01032a7:	e8 94 cd ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f01032ac:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01032b3:	00 
f01032b4:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01032bb:	00 
f01032bc:	89 74 24 04          	mov    %esi,0x4(%esp)
f01032c0:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01032c5:	89 04 24             	mov    %eax,(%esp)
f01032c8:	e8 08 e1 ff ff       	call   f01013d5 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f01032cd:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f01032d4:	02 02 02 
f01032d7:	74 24                	je     f01032fd <mem_init+0x1e67>
f01032d9:	c7 44 24 0c d4 76 10 	movl   $0xf01076d4,0xc(%esp)
f01032e0:	f0 
f01032e1:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01032e8:	f0 
f01032e9:	c7 44 24 04 73 04 00 	movl   $0x473,0x4(%esp)
f01032f0:	00 
f01032f1:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01032f8:	e8 43 cd ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f01032fd:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0103302:	74 24                	je     f0103328 <mem_init+0x1e92>
f0103304:	c7 44 24 0c 41 6f 10 	movl   $0xf0106f41,0xc(%esp)
f010330b:	f0 
f010330c:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103313:	f0 
f0103314:	c7 44 24 04 74 04 00 	movl   $0x474,0x4(%esp)
f010331b:	00 
f010331c:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103323:	e8 18 cd ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103328:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f010332d:	74 24                	je     f0103353 <mem_init+0x1ebd>
f010332f:	c7 44 24 0c 90 6f 10 	movl   $0xf0106f90,0xc(%esp)
f0103336:	f0 
f0103337:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f010333e:	f0 
f010333f:	c7 44 24 04 75 04 00 	movl   $0x475,0x4(%esp)
f0103346:	00 
f0103347:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f010334e:	e8 ed cc ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f0103353:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f010335a:	03 03 03 
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010335d:	89 f0                	mov    %esi,%eax
f010335f:	2b 05 90 3e 22 f0    	sub    0xf0223e90,%eax
f0103365:	c1 f8 03             	sar    $0x3,%eax
f0103368:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010336b:	89 c2                	mov    %eax,%edx
f010336d:	c1 ea 0c             	shr    $0xc,%edx
f0103370:	3b 15 88 3e 22 f0    	cmp    0xf0223e88,%edx
f0103376:	72 20                	jb     f0103398 <mem_init+0x1f02>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103378:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010337c:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0103383:	f0 
f0103384:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010338b:	00 
f010338c:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0103393:	e8 a8 cc ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f0103398:	81 b8 00 00 00 f0 03 	cmpl   $0x3030303,-0x10000000(%eax)
f010339f:	03 03 03 
f01033a2:	74 24                	je     f01033c8 <mem_init+0x1f32>
f01033a4:	c7 44 24 0c f8 76 10 	movl   $0xf01076f8,0xc(%esp)
f01033ab:	f0 
f01033ac:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01033b3:	f0 
f01033b4:	c7 44 24 04 77 04 00 	movl   $0x477,0x4(%esp)
f01033bb:	00 
f01033bc:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f01033c3:	e8 78 cc ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01033c8:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01033cf:	00 
f01033d0:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01033d5:	89 04 24             	mov    %eax,(%esp)
f01033d8:	e8 a8 df ff ff       	call   f0101385 <page_remove>
	assert(pp2->pp_ref == 0);
f01033dd:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f01033e2:	74 24                	je     f0103408 <mem_init+0x1f72>
f01033e4:	c7 44 24 0c 7d 6f 10 	movl   $0xf0106f7d,0xc(%esp)
f01033eb:	f0 
f01033ec:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01033f3:	f0 
f01033f4:	c7 44 24 04 79 04 00 	movl   $0x479,0x4(%esp)
f01033fb:	00 
f01033fc:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103403:	e8 38 cc ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0103408:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010340d:	8b 08                	mov    (%eax),%ecx
f010340f:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0103415:	89 da                	mov    %ebx,%edx
f0103417:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f010341d:	c1 fa 03             	sar    $0x3,%edx
f0103420:	c1 e2 0c             	shl    $0xc,%edx
f0103423:	39 d1                	cmp    %edx,%ecx
f0103425:	74 24                	je     f010344b <mem_init+0x1fb5>
f0103427:	c7 44 24 0c 80 72 10 	movl   $0xf0107280,0xc(%esp)
f010342e:	f0 
f010342f:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103436:	f0 
f0103437:	c7 44 24 04 7c 04 00 	movl   $0x47c,0x4(%esp)
f010343e:	00 
f010343f:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103446:	e8 f5 cb ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f010344b:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103451:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0103456:	74 24                	je     f010347c <mem_init+0x1fe6>
f0103458:	c7 44 24 0c 30 6f 10 	movl   $0xf0106f30,0xc(%esp)
f010345f:	f0 
f0103460:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0103467:	f0 
f0103468:	c7 44 24 04 7e 04 00 	movl   $0x47e,0x4(%esp)
f010346f:	00 
f0103470:	c7 04 24 d1 6c 10 f0 	movl   $0xf0106cd1,(%esp)
f0103477:	e8 c4 cb ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f010347c:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// free the pages we took
	page_free(pp0);
f0103482:	89 1c 24             	mov    %ebx,(%esp)
f0103485:	e8 7c dc ff ff       	call   f0101106 <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f010348a:	c7 04 24 24 77 10 f0 	movl   $0xf0107724,(%esp)
f0103491:	e8 99 0c 00 00       	call   f010412f <cprintf>
f0103496:	e9 0e 01 00 00       	jmp    f01035a9 <mem_init+0x2113>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f010349b:	a1 48 32 22 f0       	mov    0xf0223248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01034a0:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01034a5:	0f 87 c7 f4 ff ff    	ja     f0102972 <mem_init+0x14dc>
f01034ab:	e9 ea f4 ff ff       	jmp    f010299a <mem_init+0x1504>
f01034b0:	bb 00 60 11 f0       	mov    $0xf0116000,%ebx
f01034b5:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f01034bb:	0f 86 8e f5 ff ff    	jbe    f0102a4f <mem_init+0x15b9>
f01034c1:	e9 61 f5 ff ff       	jmp    f0102a27 <mem_init+0x1591>
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f01034c6:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01034cd:	00 
f01034ce:	c7 04 24 00 50 22 00 	movl   $0x225000,(%esp)
f01034d5:	b9 00 80 00 00       	mov    $0x8000,%ecx
f01034da:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f01034df:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f01034e4:	e8 65 dd ff ff       	call   f010124e <boot_map_region>
f01034e9:	bb 00 d0 22 f0       	mov    $0xf022d000,%ebx
f01034ee:	bf 00 50 26 f0       	mov    $0xf0265000,%edi
f01034f3:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f01034f8:	e9 4f f7 ff ff       	jmp    f0102c4c <mem_init+0x17b6>
	//     Permissions: kernel RW, user NONE
	// Your code goes here:
	//cprintf("%x,%x \r\n",bootstack,bootstacktop);
	for(i=0;i<KSTKSIZE;i+=PGSIZE)
	{
		page_insert(kern_pgdir,pa2page(PADDR(bootstack)+i),(void*)(KSTACKTOP-KSTKSIZE+i),PTE_W);
f01034fd:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103504:	00 
f0103505:	c7 44 24 08 00 80 bf 	movl   $0xefbf8000,0x8(%esp)
f010350c:	ef 
static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		panic("pa2page called with invalid pa");
	return &pages[PGNUM(pa)];
f010350d:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103513:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103516:	89 44 24 04          	mov    %eax,0x4(%esp)
f010351a:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f010351f:	89 04 24             	mov    %eax,(%esp)
f0103522:	e8 ae de ff ff       	call   f01013d5 <page_insert>
f0103527:	be 00 70 11 00       	mov    $0x117000,%esi
f010352c:	bf 00 e0 11 00       	mov    $0x11e000,%edi
f0103531:	b8 00 80 bf df       	mov    $0xdfbf8000,%eax
f0103536:	29 d8                	sub    %ebx,%eax
f0103538:	89 c3                	mov    %eax,%ebx
f010353a:	e9 fe f4 ff ff       	jmp    f0102a3d <mem_init+0x15a7>
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
		{
		 //  cprintf("map a UENVS pages");
		page_insert(kern_pgdir, pa2page(PADDR(envs)+i),(void*) (UENVS+i), PTE_U);
f010353f:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0103546:	00 
f0103547:	c7 44 24 08 00 00 c0 	movl   $0xeec00000,0x8(%esp)
f010354e:	ee 
f010354f:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103555:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0103558:	89 44 24 04          	mov    %eax,0x4(%esp)
f010355c:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
f0103561:	89 04 24             	mov    %eax,(%esp)
f0103564:	e8 6c de ff ff       	call   f01013d5 <page_insert>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	   for(i=0;i<ROUNDUP(NENV*sizeof(struct Env),PGSIZE);i+=PGSIZE)
f0103569:	bb 00 10 00 00       	mov    $0x1000,%ebx
f010356e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103573:	e9 10 f4 ff ff       	jmp    f0102988 <mem_init+0x14f2>
//=======
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0103578:	89 da                	mov    %ebx,%edx
f010357a:	89 f8                	mov    %edi,%eax
f010357c:	e8 bb d5 ff ff       	call   f0100b3c <check_va2pa>
f0103581:	e9 59 f9 ff ff       	jmp    f0102edf <mem_init+0x1a49>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103586:	89 da                	mov    %ebx,%edx
f0103588:	89 f8                	mov    %edi,%eax
f010358a:	e8 ad d5 ff ff       	call   f0100b3c <check_va2pa>
f010358f:	90                   	nop
f0103590:	e9 0d f8 ff ff       	jmp    f0102da2 <mem_init+0x190c>
f0103595:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010359b:	89 f8                	mov    %edi,%eax
f010359d:	e8 9a d5 ff ff       	call   f0100b3c <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f01035a2:	89 da                	mov    %ebx,%edx
f01035a4:	e9 9a f7 ff ff       	jmp    f0102d43 <mem_init+0x18ad>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f01035a9:	83 c4 4c             	add    $0x4c,%esp
f01035ac:	5b                   	pop    %ebx
f01035ad:	5e                   	pop    %esi
f01035ae:	5f                   	pop    %edi
f01035af:	5d                   	pop    %ebp
f01035b0:	c3                   	ret    

f01035b1 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01035b1:	55                   	push   %ebp
f01035b2:	89 e5                	mov    %esp,%ebp
f01035b4:	57                   	push   %edi
f01035b5:	56                   	push   %esi
f01035b6:	53                   	push   %ebx
f01035b7:	83 ec 3c             	sub    $0x3c,%esp
f01035ba:	8b 7d 08             	mov    0x8(%ebp),%edi
f01035bd:	8b 45 0c             	mov    0xc(%ebp),%eax
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
f01035c0:	89 c2                	mov    %eax,%edx
f01035c2:	03 55 10             	add    0x10(%ebp),%edx
f01035c5:	89 55 d0             	mov    %edx,-0x30(%ebp)
f01035c8:	39 d0                	cmp    %edx,%eax
f01035ca:	0f 83 88 00 00 00    	jae    f0103658 <user_mem_check+0xa7>
f01035d0:	89 c3                	mov    %eax,%ebx
f01035d2:	89 c6                	mov    %eax,%esi
			pte_t* store=0;
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
			if(store!=NULL)
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f01035d4:	8b 45 14             	mov    0x14(%ebp),%eax
f01035d7:	83 c8 01             	or     $0x1,%eax
f01035da:	89 45 d4             	mov    %eax,-0x2c(%ebp)
	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
		{
			pte_t* store=0;
f01035dd:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
			struct Page* pg=page_lookup(env->env_pgdir, (void*)i, &store);
f01035e4:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f01035e7:	89 44 24 08          	mov    %eax,0x8(%esp)
f01035eb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01035ef:	8b 47 60             	mov    0x60(%edi),%eax
f01035f2:	89 04 24             	mov    %eax,(%esp)
f01035f5:	e8 de dc ff ff       	call   f01012d8 <page_lookup>
			if(store!=NULL)
f01035fa:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01035fd:	85 c0                	test   %eax,%eax
f01035ff:	74 27                	je     f0103628 <user_mem_check+0x77>
			{
				//cprintf("pte!=NULL %08x\r\n",*store);
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
f0103601:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0103604:	89 ca                	mov    %ecx,%edx
f0103606:	23 10                	and    (%eax),%edx
f0103608:	39 d1                	cmp    %edx,%ecx
f010360a:	75 08                	jne    f0103614 <user_mem_check+0x63>
f010360c:	81 fe 00 00 80 ef    	cmp    $0xef800000,%esi
f0103612:	76 28                	jbe    f010363c <user_mem_check+0x8b>
			   {
				cprintf("pte protect!\r\n");
f0103614:	c7 04 24 48 70 10 f0 	movl   $0xf0107048,(%esp)
f010361b:	e8 0f 0b 00 00       	call   f010412f <cprintf>
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0103620:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f0103626:	eb 29                	jmp    f0103651 <user_mem_check+0xa0>
			   }
			}
			else
			{
				cprintf("no pte!\r\n");
f0103628:	c7 04 24 57 70 10 f0 	movl   $0xf0107057,(%esp)
f010362f:	e8 fb 0a 00 00       	call   f010412f <cprintf>
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
f0103634:	89 35 3c 32 22 f0    	mov    %esi,0xf022323c
				break;
f010363a:	eb 15                	jmp    f0103651 <user_mem_check+0xa0>
			}
		      i=ROUNDDOWN(i,PGSIZE);
f010363c:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
		int t=(int)va;
		for(i=t;i<(t+len);i+=PGSIZE)
f0103642:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103648:	89 de                	mov    %ebx,%esi
f010364a:	3b 5d d0             	cmp    -0x30(%ebp),%ebx
f010364d:	72 8e                	jb     f01035dd <user_mem_check+0x2c>
f010364f:	eb 0e                	jmp    f010365f <user_mem_check+0xae>
			   if((((*store) &(perm|PTE_P))!=(perm|PTE_P)) || i>ULIM)
			   {
				cprintf("pte protect!\r\n");
				flag=-E_FAULT;
				user_mem_check_addr=(int)i;
				break;
f0103651:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103656:	eb 0c                	jmp    f0103664 <user_mem_check+0xb3>
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
	// LAB 3: Your code here.

	     int i=0;
		int flag=0;
f0103658:	b8 00 00 00 00       	mov    $0x0,%eax
f010365d:	eb 05                	jmp    f0103664 <user_mem_check+0xb3>
f010365f:	b8 00 00 00 00       	mov    $0x0,%eax
			}
		      i=ROUNDDOWN(i,PGSIZE);
		}

	return flag;
}
f0103664:	83 c4 3c             	add    $0x3c,%esp
f0103667:	5b                   	pop    %ebx
f0103668:	5e                   	pop    %esi
f0103669:	5f                   	pop    %edi
f010366a:	5d                   	pop    %ebp
f010366b:	c3                   	ret    

f010366c <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f010366c:	55                   	push   %ebp
f010366d:	89 e5                	mov    %esp,%ebp
f010366f:	53                   	push   %ebx
f0103670:	83 ec 14             	sub    $0x14,%esp
f0103673:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("user_mem_assert\r\n");
f0103676:	c7 04 24 61 70 10 f0 	movl   $0xf0107061,(%esp)
f010367d:	e8 ad 0a 00 00       	call   f010412f <cprintf>
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f0103682:	8b 45 14             	mov    0x14(%ebp),%eax
f0103685:	83 c8 04             	or     $0x4,%eax
f0103688:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010368c:	8b 45 10             	mov    0x10(%ebp),%eax
f010368f:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103693:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103696:	89 44 24 04          	mov    %eax,0x4(%esp)
f010369a:	89 1c 24             	mov    %ebx,(%esp)
f010369d:	e8 0f ff ff ff       	call   f01035b1 <user_mem_check>
f01036a2:	85 c0                	test   %eax,%eax
f01036a4:	79 24                	jns    f01036ca <user_mem_assert+0x5e>
		cprintf("[%08x] user_mem_check assertion failure for "
f01036a6:	a1 3c 32 22 f0       	mov    0xf022323c,%eax
f01036ab:	89 44 24 08          	mov    %eax,0x8(%esp)
f01036af:	8b 43 48             	mov    0x48(%ebx),%eax
f01036b2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036b6:	c7 04 24 50 77 10 f0 	movl   $0xf0107750,(%esp)
f01036bd:	e8 6d 0a 00 00       	call   f010412f <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f01036c2:	89 1c 24             	mov    %ebx,(%esp)
f01036c5:	e8 a7 07 00 00       	call   f0103e71 <env_destroy>
	}
	cprintf("assert success!!\r\n");
f01036ca:	c7 04 24 73 70 10 f0 	movl   $0xf0107073,(%esp)
f01036d1:	e8 59 0a 00 00       	call   f010412f <cprintf>
}
f01036d6:	83 c4 14             	add    $0x14,%esp
f01036d9:	5b                   	pop    %ebx
f01036da:	5d                   	pop    %ebp
f01036db:	c3                   	ret    

f01036dc <region_alloc>:
// Pages should be writable by user and kernel.
// Panic if any allocation attempt fails.
//
static void
region_alloc(struct Env *e, void *va, size_t len)
{
f01036dc:	55                   	push   %ebp
f01036dd:	89 e5                	mov    %esp,%ebp
f01036df:	57                   	push   %edi
f01036e0:	56                   	push   %esi
f01036e1:	53                   	push   %ebx
f01036e2:	83 ec 1c             	sub    $0x1c,%esp
f01036e5:	89 c6                	mov    %eax,%esi
f01036e7:	89 d3                	mov    %edx,%ebx
f01036e9:	89 cf                	mov    %ecx,%edi
	// Hint: It is easier to use region_alloc if the caller can pass
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
f01036eb:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01036ef:	8b 40 60             	mov    0x60(%eax),%eax
f01036f2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036f6:	c7 04 24 85 77 10 f0 	movl   $0xf0107785,(%esp)
f01036fd:	e8 2d 0a 00 00       	call   f010412f <cprintf>
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f0103702:	89 d8                	mov    %ebx,%eax
f0103704:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f010370a:	8d bc 38 ff 0f 00 00 	lea    0xfff(%eax,%edi,1),%edi
f0103711:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
f0103717:	39 fb                	cmp    %edi,%ebx
f0103719:	73 51                	jae    f010376c <region_alloc+0x90>
	{
		struct Page* p=(struct Page*)page_alloc(1);
f010371b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103722:	e8 5a d9 ff ff       	call   f0101081 <page_alloc>
		if(p==NULL)
f0103727:	85 c0                	test   %eax,%eax
f0103729:	75 1c                	jne    f0103747 <region_alloc+0x6b>
			panic("Memory out!");
f010372b:	c7 44 24 08 9a 77 10 	movl   $0xf010779a,0x8(%esp)
f0103732:	f0 
f0103733:	c7 44 24 04 2f 01 00 	movl   $0x12f,0x4(%esp)
f010373a:	00 
f010373b:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103742:	e8 f9 c8 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f0103747:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f010374e:	00 
f010374f:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103753:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103757:	8b 46 60             	mov    0x60(%esi),%eax
f010375a:	89 04 24             	mov    %eax,(%esp)
f010375d:	e8 73 dc ff ff       	call   f01013d5 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f0103762:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0103768:	39 fb                	cmp    %edi,%ebx
f010376a:	72 af                	jb     f010371b <region_alloc+0x3f>
		if(p==NULL)
			panic("Memory out!");
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
	}

}
f010376c:	83 c4 1c             	add    $0x1c,%esp
f010376f:	5b                   	pop    %ebx
f0103770:	5e                   	pop    %esi
f0103771:	5f                   	pop    %edi
f0103772:	5d                   	pop    %ebp
f0103773:	c3                   	ret    

f0103774 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103774:	55                   	push   %ebp
f0103775:	89 e5                	mov    %esp,%ebp
f0103777:	56                   	push   %esi
f0103778:	53                   	push   %ebx
f0103779:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f010377c:	85 c0                	test   %eax,%eax
f010377e:	75 1a                	jne    f010379a <envid2env+0x26>
		*env_store = curenv;
f0103780:	e8 be 28 00 00       	call   f0106043 <cpunum>
f0103785:	6b c0 74             	imul   $0x74,%eax,%eax
f0103788:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010378e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0103791:	89 02                	mov    %eax,(%edx)
		return 0;
f0103793:	b8 00 00 00 00       	mov    $0x0,%eax
f0103798:	eb 72                	jmp    f010380c <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f010379a:	89 c3                	mov    %eax,%ebx
f010379c:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f01037a2:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f01037a5:	03 1d 48 32 22 f0    	add    0xf0223248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f01037ab:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f01037af:	74 05                	je     f01037b6 <envid2env+0x42>
f01037b1:	39 43 48             	cmp    %eax,0x48(%ebx)
f01037b4:	74 10                	je     f01037c6 <envid2env+0x52>
		*env_store = 0;
f01037b6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01037b9:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01037bf:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01037c4:	eb 46                	jmp    f010380c <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f01037c6:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f01037ca:	74 36                	je     f0103802 <envid2env+0x8e>
f01037cc:	e8 72 28 00 00       	call   f0106043 <cpunum>
f01037d1:	6b c0 74             	imul   $0x74,%eax,%eax
f01037d4:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f01037da:	74 26                	je     f0103802 <envid2env+0x8e>
f01037dc:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01037df:	e8 5f 28 00 00       	call   f0106043 <cpunum>
f01037e4:	6b c0 74             	imul   $0x74,%eax,%eax
f01037e7:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01037ed:	3b 70 48             	cmp    0x48(%eax),%esi
f01037f0:	74 10                	je     f0103802 <envid2env+0x8e>
		*env_store = 0;
f01037f2:	8b 45 0c             	mov    0xc(%ebp),%eax
f01037f5:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01037fb:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103800:	eb 0a                	jmp    f010380c <envid2env+0x98>
	}

	*env_store = e;
f0103802:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103805:	89 18                	mov    %ebx,(%eax)
	return 0;
f0103807:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010380c:	5b                   	pop    %ebx
f010380d:	5e                   	pop    %esi
f010380e:	5d                   	pop    %ebp
f010380f:	c3                   	ret    

f0103810 <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f0103810:	55                   	push   %ebp
f0103811:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f0103813:	b8 00 03 12 f0       	mov    $0xf0120300,%eax
f0103818:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f010381b:	b8 23 00 00 00       	mov    $0x23,%eax
f0103820:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f0103822:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f0103824:	b0 10                	mov    $0x10,%al
f0103826:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f0103828:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f010382a:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f010382c:	ea 33 38 10 f0 08 00 	ljmp   $0x8,$0xf0103833
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f0103833:	b0 00                	mov    $0x0,%al
f0103835:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103838:	5d                   	pop    %ebp
f0103839:	c3                   	ret    

f010383a <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f010383a:	55                   	push   %ebp
f010383b:	89 e5                	mov    %esp,%ebp
f010383d:	57                   	push   %edi
f010383e:	56                   	push   %esi
f010383f:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
    {
    	envs[i].env_id=0;
f0103840:	8b 0d 48 32 22 f0    	mov    0xf0223248,%ecx
f0103846:	c7 41 48 00 00 00 00 	movl   $0x0,0x48(%ecx)
f010384d:	89 cf                	mov    %ecx,%edi
f010384f:	8d 51 7c             	lea    0x7c(%ecx),%edx
f0103852:	89 ce                	mov    %ecx,%esi
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f0103854:	b8 00 00 00 00       	mov    $0x0,%eax
    {
    	envs[i].env_id=0;
f0103859:	bb 00 00 00 00       	mov    $0x0,%ebx
f010385e:	eb 02                	jmp    f0103862 <env_init+0x28>
f0103860:	89 f9                	mov    %edi,%ecx
    	if(i!=NENV-1)
    	{
    	envs[i].env_link=&envs[i+1];
f0103862:	83 c3 01             	add    $0x1,%ebx
f0103865:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103868:	01 d9                	add    %ebx,%ecx
f010386a:	89 4e 44             	mov    %ecx,0x44(%esi)
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f010386d:	83 c0 01             	add    $0x1,%eax
    {
    	envs[i].env_id=0;
f0103870:	89 c3                	mov    %eax,%ebx
f0103872:	89 d6                	mov    %edx,%esi
f0103874:	c7 42 48 00 00 00 00 	movl   $0x0,0x48(%edx)
f010387b:	83 c2 7c             	add    $0x7c,%edx
    	if(i!=NENV-1)
f010387e:	3d ff 03 00 00       	cmp    $0x3ff,%eax
f0103883:	75 db                	jne    f0103860 <env_init+0x26>
    	{
    	envs[i].env_link=&envs[i+1];
    	}
    }
    env_free_list=envs;
f0103885:	a1 48 32 22 f0       	mov    0xf0223248,%eax
f010388a:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	// Per-CPU part of the initialization
	env_init_percpu();
f010388f:	e8 7c ff ff ff       	call   f0103810 <env_init_percpu>
}
f0103894:	5b                   	pop    %ebx
f0103895:	5e                   	pop    %esi
f0103896:	5f                   	pop    %edi
f0103897:	5d                   	pop    %ebp
f0103898:	c3                   	ret    

f0103899 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103899:	55                   	push   %ebp
f010389a:	89 e5                	mov    %esp,%ebp
f010389c:	56                   	push   %esi
f010389d:	53                   	push   %ebx
f010389e:	83 ec 10             	sub    $0x10,%esp
	cprintf("env_alloc");
f01038a1:	c7 04 24 b1 77 10 f0 	movl   $0xf01077b1,(%esp)
f01038a8:	e8 82 08 00 00       	call   f010412f <cprintf>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f01038ad:	8b 1d 4c 32 22 f0    	mov    0xf022324c,%ebx
f01038b3:	85 db                	test   %ebx,%ebx
f01038b5:	0f 84 9e 01 00 00    	je     f0103a59 <env_alloc+0x1c0>
static int
env_setup_vm(struct Env *e)
{
	int i;
	struct Page *p = NULL;
	cprintf("env_setup_vm\r\n");
f01038bb:	c7 04 24 bb 77 10 f0 	movl   $0xf01077bb,(%esp)
f01038c2:	e8 68 08 00 00       	call   f010412f <cprintf>
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f01038c7:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01038ce:	e8 ae d7 ff ff       	call   f0101081 <page_alloc>
f01038d3:	85 c0                	test   %eax,%eax
f01038d5:	0f 84 85 01 00 00    	je     f0103a60 <env_alloc+0x1c7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f01038db:	89 c2                	mov    %eax,%edx
f01038dd:	2b 15 90 3e 22 f0    	sub    0xf0223e90,%edx
f01038e3:	c1 fa 03             	sar    $0x3,%edx
f01038e6:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01038e9:	89 d1                	mov    %edx,%ecx
f01038eb:	c1 e9 0c             	shr    $0xc,%ecx
f01038ee:	3b 0d 88 3e 22 f0    	cmp    0xf0223e88,%ecx
f01038f4:	72 20                	jb     f0103916 <env_alloc+0x7d>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01038f6:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01038fa:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0103901:	f0 
f0103902:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0103909:	00 
f010390a:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0103911:	e8 2a c7 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0103916:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f010391c:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
f010391f:	ba ec 0e 00 00       	mov    $0xeec,%edx
    for(i=PDX(UTOP);i<1024;i++)
    {
    	e->env_pgdir[i]=kern_pgdir[i];
f0103924:	8b 0d 8c 3e 22 f0    	mov    0xf0223e8c,%ecx
f010392a:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f010392d:	8b 4b 60             	mov    0x60(%ebx),%ecx
f0103930:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f0103933:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
    for(i=PDX(UTOP);i<1024;i++)
f0103936:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f010393c:	75 e6                	jne    f0103924 <env_alloc+0x8b>
    {
    	e->env_pgdir[i]=kern_pgdir[i];
    }
    p->pp_ref++;
f010393e:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f0103943:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103946:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010394b:	77 20                	ja     f010396d <env_alloc+0xd4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010394d:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103951:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103958:	f0 
f0103959:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
f0103960:	00 
f0103961:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103968:	e8 d3 c6 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f010396d:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103973:	83 ca 05             	or     $0x5,%edx
f0103976:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f010397c:	8b 43 48             	mov    0x48(%ebx),%eax
f010397f:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103984:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f0103989:	ba 00 10 00 00       	mov    $0x1000,%edx
f010398e:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103991:	89 da                	mov    %ebx,%edx
f0103993:	2b 15 48 32 22 f0    	sub    0xf0223248,%edx
f0103999:	c1 fa 02             	sar    $0x2,%edx
f010399c:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f01039a2:	09 d0                	or     %edx,%eax
f01039a4:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f01039a7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01039aa:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f01039ad:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f01039b4:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f01039bb:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f01039c2:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f01039c9:	00 
f01039ca:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01039d1:	00 
f01039d2:	89 1c 24             	mov    %ebx,(%esp)
f01039d5:	e8 cf 1f 00 00       	call   f01059a9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f01039da:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f01039e0:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f01039e6:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f01039ec:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f01039f3:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f01039f9:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f0103a00:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f0103a07:	8b 43 44             	mov    0x44(%ebx),%eax
f0103a0a:	a3 4c 32 22 f0       	mov    %eax,0xf022324c
	*newenv_store = e;
f0103a0f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103a12:	89 18                	mov    %ebx,(%eax)

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103a14:	8b 5b 48             	mov    0x48(%ebx),%ebx
f0103a17:	e8 27 26 00 00       	call   f0106043 <cpunum>
f0103a1c:	6b d0 74             	imul   $0x74,%eax,%edx
f0103a1f:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a24:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103a2b:	74 11                	je     f0103a3e <env_alloc+0x1a5>
f0103a2d:	e8 11 26 00 00       	call   f0106043 <cpunum>
f0103a32:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a35:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103a3b:	8b 40 48             	mov    0x48(%eax),%eax
f0103a3e:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103a42:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103a46:	c7 04 24 ca 77 10 f0 	movl   $0xf01077ca,(%esp)
f0103a4d:	e8 dd 06 00 00       	call   f010412f <cprintf>
	return 0;
f0103a52:	b8 00 00 00 00       	mov    $0x0,%eax
f0103a57:	eb 0c                	jmp    f0103a65 <env_alloc+0x1cc>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f0103a59:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f0103a5e:	eb 05                	jmp    f0103a65 <env_alloc+0x1cc>
	int i;
	struct Page *p = NULL;
	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f0103a60:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	env_free_list = e->env_link;
	*newenv_store = e;

	cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
}
f0103a65:	83 c4 10             	add    $0x10,%esp
f0103a68:	5b                   	pop    %ebx
f0103a69:	5e                   	pop    %esi
f0103a6a:	5d                   	pop    %ebp
f0103a6b:	c3                   	ret    

f0103a6c <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f0103a6c:	55                   	push   %ebp
f0103a6d:	89 e5                	mov    %esp,%ebp
f0103a6f:	57                   	push   %edi
f0103a70:	56                   	push   %esi
f0103a71:	53                   	push   %ebx
f0103a72:	83 ec 3c             	sub    $0x3c,%esp
f0103a75:	8b 75 08             	mov    0x8(%ebp),%esi
	// LAB 3: Your code here.

	struct Env* env;

	if(env_alloc(&env,0)==0)
f0103a78:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103a7f:	00 
f0103a80:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103a83:	89 04 24             	mov    %eax,(%esp)
f0103a86:	e8 0e fe ff ff       	call   f0103899 <env_alloc>
f0103a8b:	85 c0                	test   %eax,%eax
f0103a8d:	0f 85 d1 01 00 00    	jne    f0103c64 <env_create+0x1f8>
	{
		env->env_type=type;
f0103a93:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0103a96:	89 c7                	mov    %eax,%edi
f0103a98:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0103a9b:	8b 45 10             	mov    0x10(%ebp),%eax
f0103a9e:	89 47 50             	mov    %eax,0x50(%edi)
	//  You must also do something with the program's entry point,
	//  to make sure that the environment starts executing there.
	//  What?  (See env_run() and env_pop_tf() below.)

	// LAB 3: Your code here.
	lcr3(PADDR(e->env_pgdir));
f0103aa1:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103aa4:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103aa9:	77 20                	ja     f0103acb <env_create+0x5f>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103aab:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103aaf:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103ab6:	f0 
f0103ab7:	c7 44 24 04 6b 01 00 	movl   $0x16b,0x4(%esp)
f0103abe:	00 
f0103abf:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103ac6:	e8 75 c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103acb:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0103ad0:	0f 22 d8             	mov    %eax,%cr3
	cprintf("load_icode\r\n");
f0103ad3:	c7 04 24 df 77 10 f0 	movl   $0xf01077df,(%esp)
f0103ada:	e8 50 06 00 00       	call   f010412f <cprintf>
	struct Elf * ELFHDR=(struct Elf *)binary;
	struct Proghdr *ph, *eph;
	int i;
	if (ELFHDR->e_magic != ELF_MAGIC)
f0103adf:	81 3e 7f 45 4c 46    	cmpl   $0x464c457f,(%esi)
f0103ae5:	74 1c                	je     f0103b03 <env_create+0x97>
			panic("Not a elf binary");
f0103ae7:	c7 44 24 08 ec 77 10 	movl   $0xf01077ec,0x8(%esp)
f0103aee:	f0 
f0103aef:	c7 44 24 04 71 01 00 	movl   $0x171,0x4(%esp)
f0103af6:	00 
f0103af7:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103afe:	e8 3d c5 ff ff       	call   f0100040 <_panic>


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
f0103b03:	89 f3                	mov    %esi,%ebx
f0103b05:	03 5e 1c             	add    0x1c(%esi),%ebx
		eph = ph + ELFHDR->e_phnum;
f0103b08:	0f b7 46 2c          	movzwl 0x2c(%esi),%eax
f0103b0c:	c1 e0 05             	shl    $0x5,%eax
f0103b0f:	01 d8                	add    %ebx,%eax
f0103b11:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		for (; ph < eph; ph++)
f0103b14:	39 c3                	cmp    %eax,%ebx
f0103b16:	73 5e                	jae    f0103b76 <env_create+0x10a>
		{
			// p_pa is the load address of this segment (as well
			// as the physical address)
			if(ph->p_type==ELF_PROG_LOAD)
f0103b18:	83 3b 01             	cmpl   $0x1,(%ebx)
f0103b1b:	75 51                	jne    f0103b6e <env_create+0x102>
			{
			cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
f0103b1d:	8b 43 08             	mov    0x8(%ebx),%eax
f0103b20:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103b24:	8b 43 10             	mov    0x10(%ebx),%eax
f0103b27:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103b2b:	c7 04 24 fd 77 10 f0 	movl   $0xf01077fd,(%esp)
f0103b32:	e8 f8 05 00 00       	call   f010412f <cprintf>
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
f0103b37:	8b 4b 10             	mov    0x10(%ebx),%ecx
f0103b3a:	8b 53 08             	mov    0x8(%ebx),%edx
f0103b3d:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103b40:	e8 97 fb ff ff       	call   f01036dc <region_alloc>
			char* va=(char*)ph->p_va;
f0103b45:	8b 7b 08             	mov    0x8(%ebx),%edi
			for(i=0;i<ph->p_filesz;i++)
f0103b48:	83 7b 10 00          	cmpl   $0x0,0x10(%ebx)
f0103b4c:	74 20                	je     f0103b6e <env_create+0x102>
f0103b4e:	b8 00 00 00 00       	mov    $0x0,%eax
f0103b53:	ba 00 00 00 00       	mov    $0x0,%edx
			{

				va[i]=binary[ph->p_offset+i];
f0103b58:	8d 0c 16             	lea    (%esi,%edx,1),%ecx
f0103b5b:	03 4b 04             	add    0x4(%ebx),%ecx
f0103b5e:	0f b6 09             	movzbl (%ecx),%ecx
f0103b61:	88 0c 17             	mov    %cl,(%edi,%edx,1)
			if(ph->p_type==ELF_PROG_LOAD)
			{
			cprintf("load_prog %08x %08x \r\n",ph->p_filesz,ph->p_va);
			region_alloc(e,(void*)ph->p_va,ph->p_filesz);
			char* va=(char*)ph->p_va;
			for(i=0;i<ph->p_filesz;i++)
f0103b64:	83 c0 01             	add    $0x1,%eax
f0103b67:	89 c2                	mov    %eax,%edx
f0103b69:	3b 43 10             	cmp    0x10(%ebx),%eax
f0103b6c:	72 ea                	jb     f0103b58 <env_create+0xec>
			panic("Not a elf binary");


		ph = (struct Proghdr *) ((uint8_t *) ELFHDR + ELFHDR->e_phoff);
		eph = ph + ELFHDR->e_phnum;
		for (; ph < eph; ph++)
f0103b6e:	83 c3 20             	add    $0x20,%ebx
f0103b71:	39 5d d4             	cmp    %ebx,-0x2c(%ebp)
f0103b74:	77 a2                	ja     f0103b18 <env_create+0xac>
			}

			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
f0103b76:	89 f3                	mov    %esi,%ebx
f0103b78:	03 5e 20             	add    0x20(%esi),%ebx
		eshdr= shdr + ELFHDR->e_shnum;
f0103b7b:	0f b7 46 30          	movzwl 0x30(%esi),%eax
f0103b7f:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0103b82:	8d 3c c3             	lea    (%ebx,%eax,8),%edi
				for (; shdr < eshdr; shdr++)
f0103b85:	39 fb                	cmp    %edi,%ebx
f0103b87:	73 44                	jae    f0103bcd <env_create+0x161>
				{
					// p_pa is the load address of this segment (as well
					// as the physical address)
					if(shdr->sh_type==8)
f0103b89:	83 7b 04 08          	cmpl   $0x8,0x4(%ebx)
f0103b8d:	75 37                	jne    f0103bc6 <env_create+0x15a>
					{
					cprintf("section %08x %08x %08x %08x\r\n",shdr->sh_size,shdr->sh_addr,shdr->sh_offset,shdr->sh_type);
f0103b8f:	c7 44 24 10 08 00 00 	movl   $0x8,0x10(%esp)
f0103b96:	00 
f0103b97:	8b 43 10             	mov    0x10(%ebx),%eax
f0103b9a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103b9e:	8b 43 0c             	mov    0xc(%ebx),%eax
f0103ba1:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103ba5:	8b 43 14             	mov    0x14(%ebx),%eax
f0103ba8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103bac:	c7 04 24 14 78 10 f0 	movl   $0xf0107814,(%esp)
f0103bb3:	e8 77 05 00 00       	call   f010412f <cprintf>
					region_alloc(e,(void*)shdr->sh_addr,shdr->sh_size);
f0103bb8:	8b 4b 14             	mov    0x14(%ebx),%ecx
f0103bbb:	8b 53 0c             	mov    0xc(%ebx),%edx
f0103bbe:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103bc1:	e8 16 fb ff ff       	call   f01036dc <region_alloc>
			}
		}
		struct Secthdr *shdr,*eshdr;
		shdr = (struct Secthdr *) ((uint8_t *) ELFHDR + ELFHDR->e_shoff);
		eshdr= shdr + ELFHDR->e_shnum;
				for (; shdr < eshdr; shdr++)
f0103bc6:	83 c3 28             	add    $0x28,%ebx
f0103bc9:	39 df                	cmp    %ebx,%edi
f0103bcb:	77 bc                	ja     f0103b89 <env_create+0x11d>


					}
				}

		e->env_tf.tf_eip=ELFHDR->e_entry;
f0103bcd:	8b 46 18             	mov    0x18(%esi),%eax
f0103bd0:	8b 75 d0             	mov    -0x30(%ebp),%esi
f0103bd3:	89 46 30             	mov    %eax,0x30(%esi)

	// Now map one page for the program's initial stack
	// at virtual address USTACKTOP - PGSIZE.

	// LAB 3: Your code here.
		struct Page* p=(struct Page*)page_alloc(1);
f0103bd6:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103bdd:	e8 9f d4 ff ff       	call   f0101081 <page_alloc>
     if(p==NULL)
f0103be2:	85 c0                	test   %eax,%eax
f0103be4:	75 1c                	jne    f0103c02 <env_create+0x196>
    	 panic("Not enough mem for user stack!");
f0103be6:	c7 44 24 08 74 78 10 	movl   $0xf0107874,0x8(%esp)
f0103bed:	f0 
f0103bee:	c7 44 24 04 9f 01 00 	movl   $0x19f,0x4(%esp)
f0103bf5:	00 
f0103bf6:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103bfd:	e8 3e c4 ff ff       	call   f0100040 <_panic>
     page_insert(e->env_pgdir,p,(void*)(USTACKTOP-PGSIZE),PTE_W|PTE_U);
f0103c02:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103c09:	00 
f0103c0a:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f0103c11:	ee 
f0103c12:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c16:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0103c19:	8b 40 60             	mov    0x60(%eax),%eax
f0103c1c:	89 04 24             	mov    %eax,(%esp)
f0103c1f:	e8 b1 d7 ff ff       	call   f01013d5 <page_insert>
     cprintf("load_icode finish!\r\n");
f0103c24:	c7 04 24 32 78 10 f0 	movl   $0xf0107832,(%esp)
f0103c2b:	e8 ff 04 00 00       	call   f010412f <cprintf>
     lcr3(PADDR(kern_pgdir));
f0103c30:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103c35:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103c3a:	77 20                	ja     f0103c5c <env_create+0x1f0>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103c3c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103c40:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103c47:	f0 
f0103c48:	c7 44 24 04 a2 01 00 	movl   $0x1a2,0x4(%esp)
f0103c4f:	00 
f0103c50:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103c57:	e8 e4 c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103c5c:	05 00 00 00 10       	add    $0x10000000,%eax
f0103c61:	0f 22 d8             	mov    %eax,%cr3
	{
		env->env_type=type;
		load_icode(env, binary,size);
	}

}
f0103c64:	83 c4 3c             	add    $0x3c,%esp
f0103c67:	5b                   	pop    %ebx
f0103c68:	5e                   	pop    %esi
f0103c69:	5f                   	pop    %edi
f0103c6a:	5d                   	pop    %ebp
f0103c6b:	c3                   	ret    

f0103c6c <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f0103c6c:	55                   	push   %ebp
f0103c6d:	89 e5                	mov    %esp,%ebp
f0103c6f:	57                   	push   %edi
f0103c70:	56                   	push   %esi
f0103c71:	53                   	push   %ebx
f0103c72:	83 ec 2c             	sub    $0x2c,%esp
f0103c75:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f0103c78:	e8 c6 23 00 00       	call   f0106043 <cpunum>
f0103c7d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103c80:	39 b8 28 40 22 f0    	cmp    %edi,-0xfddbfd8(%eax)
f0103c86:	75 34                	jne    f0103cbc <env_free+0x50>
		lcr3(PADDR(kern_pgdir));
f0103c88:	a1 8c 3e 22 f0       	mov    0xf0223e8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103c8d:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103c92:	77 20                	ja     f0103cb4 <env_free+0x48>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103c94:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103c98:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103c9f:	f0 
f0103ca0:	c7 44 24 04 c9 01 00 	movl   $0x1c9,0x4(%esp)
f0103ca7:	00 
f0103ca8:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103caf:	e8 8c c3 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103cb4:	05 00 00 00 10       	add    $0x10000000,%eax
f0103cb9:	0f 22 d8             	mov    %eax,%cr3

	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
f0103cbc:	8b 5f 48             	mov    0x48(%edi),%ebx
f0103cbf:	e8 7f 23 00 00       	call   f0106043 <cpunum>
f0103cc4:	6b d0 74             	imul   $0x74,%eax,%edx
f0103cc7:	b8 00 00 00 00       	mov    $0x0,%eax
f0103ccc:	83 ba 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%edx)
f0103cd3:	74 11                	je     f0103ce6 <env_free+0x7a>
f0103cd5:	e8 69 23 00 00       	call   f0106043 <cpunum>
f0103cda:	6b c0 74             	imul   $0x74,%eax,%eax
f0103cdd:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103ce3:	8b 40 48             	mov    0x48(%eax),%eax
f0103ce6:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0103cea:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103cee:	c7 04 24 47 78 10 f0 	movl   $0xf0107847,(%esp)
f0103cf5:	e8 35 04 00 00       	call   f010412f <cprintf>

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103cfa:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103d01:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103d04:	89 c8                	mov    %ecx,%eax
f0103d06:	c1 e0 02             	shl    $0x2,%eax
f0103d09:	89 45 dc             	mov    %eax,-0x24(%ebp)

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103d0c:	8b 47 60             	mov    0x60(%edi),%eax
f0103d0f:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f0103d12:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103d18:	0f 84 b7 00 00 00    	je     f0103dd5 <env_free+0x169>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f0103d1e:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103d24:	89 f0                	mov    %esi,%eax
f0103d26:	c1 e8 0c             	shr    $0xc,%eax
f0103d29:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103d2c:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103d32:	72 20                	jb     f0103d54 <env_free+0xe8>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103d34:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103d38:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0103d3f:	f0 
f0103d40:	c7 44 24 04 d8 01 00 	movl   $0x1d8,0x4(%esp)
f0103d47:	00 
f0103d48:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103d4f:	e8 ec c2 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103d54:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0103d57:	c1 e0 16             	shl    $0x16,%eax
f0103d5a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103d5d:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f0103d62:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f0103d69:	01 
f0103d6a:	74 17                	je     f0103d83 <env_free+0x117>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f0103d6c:	89 d8                	mov    %ebx,%eax
f0103d6e:	c1 e0 0c             	shl    $0xc,%eax
f0103d71:	0b 45 e4             	or     -0x1c(%ebp),%eax
f0103d74:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103d78:	8b 47 60             	mov    0x60(%edi),%eax
f0103d7b:	89 04 24             	mov    %eax,(%esp)
f0103d7e:	e8 02 d6 ff ff       	call   f0101385 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f0103d83:	83 c3 01             	add    $0x1,%ebx
f0103d86:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f0103d8c:	75 d4                	jne    f0103d62 <env_free+0xf6>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f0103d8e:	8b 47 60             	mov    0x60(%edi),%eax
f0103d91:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0103d94:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103d9b:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0103d9e:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103da4:	72 1c                	jb     f0103dc2 <env_free+0x156>
		panic("pa2page called with invalid pa");
f0103da6:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0103dad:	f0 
f0103dae:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103db5:	00 
f0103db6:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0103dbd:	e8 7e c2 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103dc2:	a1 90 3e 22 f0       	mov    0xf0223e90,%eax
f0103dc7:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103dca:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103dcd:	89 04 24             	mov    %eax,(%esp)
f0103dd0:	e8 4c d3 ff ff       	call   f0101121 <page_decref>
	// Note the environment's demise.
	cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103dd5:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103dd9:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f0103de0:	0f 85 1b ff ff ff    	jne    f0103d01 <env_free+0x95>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103de6:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103de9:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103dee:	77 20                	ja     f0103e10 <env_free+0x1a4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103df0:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103df4:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103dfb:	f0 
f0103dfc:	c7 44 24 04 e6 01 00 	movl   $0x1e6,0x4(%esp)
f0103e03:	00 
f0103e04:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103e0b:	e8 30 c2 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f0103e10:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103e17:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103e1c:	c1 e8 0c             	shr    $0xc,%eax
f0103e1f:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0103e25:	72 1c                	jb     f0103e43 <env_free+0x1d7>
		panic("pa2page called with invalid pa");
f0103e27:	c7 44 24 08 4c 71 10 	movl   $0xf010714c,0x8(%esp)
f0103e2e:	f0 
f0103e2f:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103e36:	00 
f0103e37:	c7 04 24 f2 6c 10 f0 	movl   $0xf0106cf2,(%esp)
f0103e3e:	e8 fd c1 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0103e43:	8b 15 90 3e 22 f0    	mov    0xf0223e90,%edx
f0103e49:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103e4c:	89 04 24             	mov    %eax,(%esp)
f0103e4f:	e8 cd d2 ff ff       	call   f0101121 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f0103e54:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f0103e5b:	a1 4c 32 22 f0       	mov    0xf022324c,%eax
f0103e60:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f0103e63:	89 3d 4c 32 22 f0    	mov    %edi,0xf022324c
}
f0103e69:	83 c4 2c             	add    $0x2c,%esp
f0103e6c:	5b                   	pop    %ebx
f0103e6d:	5e                   	pop    %esi
f0103e6e:	5f                   	pop    %edi
f0103e6f:	5d                   	pop    %ebp
f0103e70:	c3                   	ret    

f0103e71 <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f0103e71:	55                   	push   %ebp
f0103e72:	89 e5                	mov    %esp,%ebp
f0103e74:	53                   	push   %ebx
f0103e75:	83 ec 14             	sub    $0x14,%esp
f0103e78:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f0103e7b:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f0103e7f:	75 19                	jne    f0103e9a <env_destroy+0x29>
f0103e81:	e8 bd 21 00 00       	call   f0106043 <cpunum>
f0103e86:	6b c0 74             	imul   $0x74,%eax,%eax
f0103e89:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103e8f:	74 09                	je     f0103e9a <env_destroy+0x29>
		e->env_status = ENV_DYING;
f0103e91:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f0103e98:	eb 2f                	jmp    f0103ec9 <env_destroy+0x58>
	}

	env_free(e);
f0103e9a:	89 1c 24             	mov    %ebx,(%esp)
f0103e9d:	e8 ca fd ff ff       	call   f0103c6c <env_free>

	if (curenv == e) {
f0103ea2:	e8 9c 21 00 00       	call   f0106043 <cpunum>
f0103ea7:	6b c0 74             	imul   $0x74,%eax,%eax
f0103eaa:	39 98 28 40 22 f0    	cmp    %ebx,-0xfddbfd8(%eax)
f0103eb0:	75 17                	jne    f0103ec9 <env_destroy+0x58>
		curenv = NULL;
f0103eb2:	e8 8c 21 00 00       	call   f0106043 <cpunum>
f0103eb7:	6b c0 74             	imul   $0x74,%eax,%eax
f0103eba:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f0103ec1:	00 00 00 
		sched_yield();
f0103ec4:	e8 57 0b 00 00       	call   f0104a20 <sched_yield>
	}
}
f0103ec9:	83 c4 14             	add    $0x14,%esp
f0103ecc:	5b                   	pop    %ebx
f0103ecd:	5d                   	pop    %ebp
f0103ece:	c3                   	ret    

f0103ecf <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103ecf:	55                   	push   %ebp
f0103ed0:	89 e5                	mov    %esp,%ebp
f0103ed2:	53                   	push   %ebx
f0103ed3:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103ed6:	e8 68 21 00 00       	call   f0106043 <cpunum>
f0103edb:	6b c0 74             	imul   $0x74,%eax,%eax
f0103ede:	8b 98 28 40 22 f0    	mov    -0xfddbfd8(%eax),%ebx
f0103ee4:	e8 5a 21 00 00       	call   f0106043 <cpunum>
f0103ee9:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103eec:	8b 65 08             	mov    0x8(%ebp),%esp
f0103eef:	61                   	popa   
f0103ef0:	07                   	pop    %es
f0103ef1:	1f                   	pop    %ds
f0103ef2:	83 c4 08             	add    $0x8,%esp
f0103ef5:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103ef6:	c7 44 24 08 5d 78 10 	movl   $0xf010785d,0x8(%esp)
f0103efd:	f0 
f0103efe:	c7 44 24 04 1c 02 00 	movl   $0x21c,0x4(%esp)
f0103f05:	00 
f0103f06:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103f0d:	e8 2e c1 ff ff       	call   f0100040 <_panic>

f0103f12 <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103f12:	55                   	push   %ebp
f0103f13:	89 e5                	mov    %esp,%ebp
f0103f15:	53                   	push   %ebx
f0103f16:	83 ec 14             	sub    $0x14,%esp
f0103f19:	8b 5d 08             	mov    0x8(%ebp),%ebx
	//	e->env_tf.  Go back through the code you wrote above
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.
	cprintf("Run env!\r\n");
f0103f1c:	c7 04 24 69 78 10 f0 	movl   $0xf0107869,(%esp)
f0103f23:	e8 07 02 00 00       	call   f010412f <cprintf>
    if(curenv!=NULL)
f0103f28:	e8 16 21 00 00       	call   f0106043 <cpunum>
f0103f2d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f30:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0103f37:	74 29                	je     f0103f62 <env_run+0x50>
    {
    	if(curenv->env_status==ENV_RUNNING)
f0103f39:	e8 05 21 00 00       	call   f0106043 <cpunum>
f0103f3e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f41:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103f47:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103f4b:	75 15                	jne    f0103f62 <env_run+0x50>
    	{
    		curenv->env_status=ENV_RUNNABLE;
f0103f4d:	e8 f1 20 00 00       	call   f0106043 <cpunum>
f0103f52:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f55:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0103f5b:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
    	}
    }
    curenv=e;
f0103f62:	e8 dc 20 00 00       	call   f0106043 <cpunum>
f0103f67:	6b c0 74             	imul   $0x74,%eax,%eax
f0103f6a:	89 98 28 40 22 f0    	mov    %ebx,-0xfddbfd8(%eax)
    e->env_status=ENV_RUNNING;
f0103f70:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
    e->env_runs++;
f0103f77:	83 43 58 01          	addl   $0x1,0x58(%ebx)
    lcr3(PADDR(e->env_pgdir));
f0103f7b:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103f7e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103f83:	77 20                	ja     f0103fa5 <env_run+0x93>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103f85:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103f89:	c7 44 24 08 88 67 10 	movl   $0xf0106788,0x8(%esp)
f0103f90:	f0 
f0103f91:	c7 44 24 04 45 02 00 	movl   $0x245,0x4(%esp)
f0103f98:	00 
f0103f99:	c7 04 24 a6 77 10 f0 	movl   $0xf01077a6,(%esp)
f0103fa0:	e8 9b c0 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103fa5:	05 00 00 00 10       	add    $0x10000000,%eax
f0103faa:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103fad:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f0103fb4:	e8 d3 23 00 00       	call   f010638c <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103fb9:	f3 90                	pause  
	unlock_kernel();
    env_pop_tf(&e->env_tf);
f0103fbb:	89 1c 24             	mov    %ebx,(%esp)
f0103fbe:	e8 0c ff ff ff       	call   f0103ecf <env_pop_tf>

f0103fc3 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103fc3:	55                   	push   %ebp
f0103fc4:	89 e5                	mov    %esp,%ebp
f0103fc6:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103fca:	ba 70 00 00 00       	mov    $0x70,%edx
f0103fcf:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103fd0:	b2 71                	mov    $0x71,%dl
f0103fd2:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103fd3:	0f b6 c0             	movzbl %al,%eax
}
f0103fd6:	5d                   	pop    %ebp
f0103fd7:	c3                   	ret    

f0103fd8 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103fd8:	55                   	push   %ebp
f0103fd9:	89 e5                	mov    %esp,%ebp
f0103fdb:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103fdf:	ba 70 00 00 00       	mov    $0x70,%edx
f0103fe4:	ee                   	out    %al,(%dx)
f0103fe5:	b2 71                	mov    $0x71,%dl
f0103fe7:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103fea:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103feb:	5d                   	pop    %ebp
f0103fec:	c3                   	ret    

f0103fed <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103fed:	55                   	push   %ebp
f0103fee:	89 e5                	mov    %esp,%ebp
f0103ff0:	56                   	push   %esi
f0103ff1:	53                   	push   %ebx
f0103ff2:	83 ec 10             	sub    $0x10,%esp
f0103ff5:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103ff8:	66 a3 88 03 12 f0    	mov    %ax,0xf0120388
	if (!didinit)
f0103ffe:	83 3d 50 32 22 f0 00 	cmpl   $0x0,0xf0223250
f0104005:	74 4e                	je     f0104055 <irq_setmask_8259A+0x68>
f0104007:	89 c6                	mov    %eax,%esi
f0104009:	ba 21 00 00 00       	mov    $0x21,%edx
f010400e:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f010400f:	66 c1 e8 08          	shr    $0x8,%ax
f0104013:	b2 a1                	mov    $0xa1,%dl
f0104015:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0104016:	c7 04 24 93 78 10 f0 	movl   $0xf0107893,(%esp)
f010401d:	e8 0d 01 00 00       	call   f010412f <cprintf>
	for (i = 0; i < 16; i++)
f0104022:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0104027:	0f b7 f6             	movzwl %si,%esi
f010402a:	f7 d6                	not    %esi
f010402c:	0f a3 de             	bt     %ebx,%esi
f010402f:	73 10                	jae    f0104041 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0104031:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104035:	c7 04 24 87 7d 10 f0 	movl   $0xf0107d87,(%esp)
f010403c:	e8 ee 00 00 00       	call   f010412f <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0104041:	83 c3 01             	add    $0x1,%ebx
f0104044:	83 fb 10             	cmp    $0x10,%ebx
f0104047:	75 e3                	jne    f010402c <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0104049:	c7 04 24 12 78 10 f0 	movl   $0xf0107812,(%esp)
f0104050:	e8 da 00 00 00       	call   f010412f <cprintf>
}
f0104055:	83 c4 10             	add    $0x10,%esp
f0104058:	5b                   	pop    %ebx
f0104059:	5e                   	pop    %esi
f010405a:	5d                   	pop    %ebp
f010405b:	c3                   	ret    

f010405c <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f010405c:	c7 05 50 32 22 f0 01 	movl   $0x1,0xf0223250
f0104063:	00 00 00 
f0104066:	ba 21 00 00 00       	mov    $0x21,%edx
f010406b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0104070:	ee                   	out    %al,(%dx)
f0104071:	b2 a1                	mov    $0xa1,%dl
f0104073:	ee                   	out    %al,(%dx)
f0104074:	b2 20                	mov    $0x20,%dl
f0104076:	b8 11 00 00 00       	mov    $0x11,%eax
f010407b:	ee                   	out    %al,(%dx)
f010407c:	b2 21                	mov    $0x21,%dl
f010407e:	b8 20 00 00 00       	mov    $0x20,%eax
f0104083:	ee                   	out    %al,(%dx)
f0104084:	b8 04 00 00 00       	mov    $0x4,%eax
f0104089:	ee                   	out    %al,(%dx)
f010408a:	b8 03 00 00 00       	mov    $0x3,%eax
f010408f:	ee                   	out    %al,(%dx)
f0104090:	b2 a0                	mov    $0xa0,%dl
f0104092:	b8 11 00 00 00       	mov    $0x11,%eax
f0104097:	ee                   	out    %al,(%dx)
f0104098:	b2 a1                	mov    $0xa1,%dl
f010409a:	b8 28 00 00 00       	mov    $0x28,%eax
f010409f:	ee                   	out    %al,(%dx)
f01040a0:	b8 02 00 00 00       	mov    $0x2,%eax
f01040a5:	ee                   	out    %al,(%dx)
f01040a6:	b8 01 00 00 00       	mov    $0x1,%eax
f01040ab:	ee                   	out    %al,(%dx)
f01040ac:	b2 20                	mov    $0x20,%dl
f01040ae:	b8 68 00 00 00       	mov    $0x68,%eax
f01040b3:	ee                   	out    %al,(%dx)
f01040b4:	b8 0a 00 00 00       	mov    $0xa,%eax
f01040b9:	ee                   	out    %al,(%dx)
f01040ba:	b2 a0                	mov    $0xa0,%dl
f01040bc:	b8 68 00 00 00       	mov    $0x68,%eax
f01040c1:	ee                   	out    %al,(%dx)
f01040c2:	b8 0a 00 00 00       	mov    $0xa,%eax
f01040c7:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f01040c8:	0f b7 05 88 03 12 f0 	movzwl 0xf0120388,%eax
f01040cf:	66 83 f8 ff          	cmp    $0xffff,%ax
f01040d3:	74 12                	je     f01040e7 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f01040d5:	55                   	push   %ebp
f01040d6:	89 e5                	mov    %esp,%ebp
f01040d8:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f01040db:	0f b7 c0             	movzwl %ax,%eax
f01040de:	89 04 24             	mov    %eax,(%esp)
f01040e1:	e8 07 ff ff ff       	call   f0103fed <irq_setmask_8259A>
}
f01040e6:	c9                   	leave  
f01040e7:	f3 c3                	repz ret 

f01040e9 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f01040e9:	55                   	push   %ebp
f01040ea:	89 e5                	mov    %esp,%ebp
f01040ec:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f01040ef:	8b 45 08             	mov    0x8(%ebp),%eax
f01040f2:	89 04 24             	mov    %eax,(%esp)
f01040f5:	e8 e3 c6 ff ff       	call   f01007dd <cputchar>
	*cnt++;
}
f01040fa:	c9                   	leave  
f01040fb:	c3                   	ret    

f01040fc <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f01040fc:	55                   	push   %ebp
f01040fd:	89 e5                	mov    %esp,%ebp
f01040ff:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0104102:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0104109:	8b 45 0c             	mov    0xc(%ebp),%eax
f010410c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104110:	8b 45 08             	mov    0x8(%ebp),%eax
f0104113:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104117:	8d 45 f4             	lea    -0xc(%ebp),%eax
f010411a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010411e:	c7 04 24 e9 40 10 f0 	movl   $0xf01040e9,(%esp)
f0104125:	e8 80 10 00 00       	call   f01051aa <vprintfmt>
	return cnt;
}
f010412a:	8b 45 f4             	mov    -0xc(%ebp),%eax
f010412d:	c9                   	leave  
f010412e:	c3                   	ret    

f010412f <cprintf>:

int
cprintf(const char *fmt, ...)
{
f010412f:	55                   	push   %ebp
f0104130:	89 e5                	mov    %esp,%ebp
f0104132:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0104135:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0104138:	89 44 24 04          	mov    %eax,0x4(%esp)
f010413c:	8b 45 08             	mov    0x8(%ebp),%eax
f010413f:	89 04 24             	mov    %eax,(%esp)
f0104142:	e8 b5 ff ff ff       	call   f01040fc <vcprintf>
	va_end(ap);

	return cnt;
}
f0104147:	c9                   	leave  
f0104148:	c3                   	ret    

f0104149 <trap_init_percpu>:
}

// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0104149:	55                   	push   %ebp
f010414a:	89 e5                	mov    %esp,%ebp
f010414c:	57                   	push   %edi
f010414d:	56                   	push   %esi
f010414e:	53                   	push   %ebx
f010414f:	83 ec 0c             	sub    $0xc,%esp
	//
	// LAB 4: Your code here:

	// Setup a TSS so that we get the right stack
	// when we trap to the kernel.
	thiscpu->cpu_ts.ts_esp0 = KSTACKTOP - cpunum() * (KSTKGAP + KSTKSIZE);
f0104152:	e8 ec 1e 00 00       	call   f0106043 <cpunum>
f0104157:	89 c3                	mov    %eax,%ebx
f0104159:	e8 e5 1e 00 00       	call   f0106043 <cpunum>
f010415e:	6b db 74             	imul   $0x74,%ebx,%ebx
f0104161:	f7 d8                	neg    %eax
f0104163:	c1 e0 10             	shl    $0x10,%eax
f0104166:	2d 00 00 40 10       	sub    $0x10400000,%eax
f010416b:	89 83 30 40 22 f0    	mov    %eax,-0xfddbfd0(%ebx)
    thiscpu->cpu_ts.ts_ss0 = GD_KD;
f0104171:	e8 cd 1e 00 00       	call   f0106043 <cpunum>
f0104176:	6b c0 74             	imul   $0x74,%eax,%eax
f0104179:	66 c7 80 34 40 22 f0 	movw   $0x10,-0xfddbfcc(%eax)
f0104180:	10 00 

	// Initialize the TSS slot of the gdt.
	gdt[(GD_TSS0 >> 3) + cpunum()] = SEG16(STS_T32A, (uint32_t) (&thiscpu->cpu_ts), sizeof(struct Taskstate) - 1, 0);
f0104182:	e8 bc 1e 00 00       	call   f0106043 <cpunum>
f0104187:	8d 58 05             	lea    0x5(%eax),%ebx
f010418a:	e8 b4 1e 00 00       	call   f0106043 <cpunum>
f010418f:	89 c7                	mov    %eax,%edi
f0104191:	e8 ad 1e 00 00       	call   f0106043 <cpunum>
f0104196:	89 c6                	mov    %eax,%esi
f0104198:	e8 a6 1e 00 00       	call   f0106043 <cpunum>
f010419d:	66 c7 04 dd 20 03 12 	movw   $0x67,-0xfedfce0(,%ebx,8)
f01041a4:	f0 67 00 
f01041a7:	6b ff 74             	imul   $0x74,%edi,%edi
f01041aa:	81 c7 2c 40 22 f0    	add    $0xf022402c,%edi
f01041b0:	66 89 3c dd 22 03 12 	mov    %di,-0xfedfcde(,%ebx,8)
f01041b7:	f0 
f01041b8:	6b d6 74             	imul   $0x74,%esi,%edx
f01041bb:	81 c2 2c 40 22 f0    	add    $0xf022402c,%edx
f01041c1:	c1 ea 10             	shr    $0x10,%edx
f01041c4:	88 14 dd 24 03 12 f0 	mov    %dl,-0xfedfcdc(,%ebx,8)
f01041cb:	c6 04 dd 25 03 12 f0 	movb   $0x99,-0xfedfcdb(,%ebx,8)
f01041d2:	99 
f01041d3:	c6 04 dd 26 03 12 f0 	movb   $0x40,-0xfedfcda(,%ebx,8)
f01041da:	40 
f01041db:	6b c0 74             	imul   $0x74,%eax,%eax
f01041de:	05 2c 40 22 f0       	add    $0xf022402c,%eax
f01041e3:	c1 e8 18             	shr    $0x18,%eax
f01041e6:	88 04 dd 27 03 12 f0 	mov    %al,-0xfedfcd9(,%ebx,8)
    gdt[(GD_TSS0 >> 3) + cpunum()].sd_s = 0;
f01041ed:	e8 51 1e 00 00       	call   f0106043 <cpunum>
f01041f2:	80 24 c5 4d 03 12 f0 	andb   $0xef,-0xfedfcb3(,%eax,8)
f01041f9:	ef 

	// Load the TSS selector (like other segment selectors, the
	// bottom three bits are special; we leave them 0)
	 ltr(GD_TSS0 + sizeof(struct Segdesc) * cpunum());
f01041fa:	e8 44 1e 00 00       	call   f0106043 <cpunum>
f01041ff:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0104206:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0104209:	b8 8a 03 12 f0       	mov    $0xf012038a,%eax
f010420e:	0f 01 18             	lidtl  (%eax)


	// Load the IDT
	lidt(&idt_pd);
}
f0104211:	83 c4 0c             	add    $0xc,%esp
f0104214:	5b                   	pop    %ebx
f0104215:	5e                   	pop    %esi
f0104216:	5f                   	pop    %edi
f0104217:	5d                   	pop    %ebp
f0104218:	c3                   	ret    

f0104219 <trap_init>:
}


void
trap_init(void)
{
f0104219:	55                   	push   %ebp
f010421a:	89 e5                	mov    %esp,%ebp
f010421c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f010421f:	b8 a8 49 10 f0       	mov    $0xf01049a8,%eax
f0104224:	66 a3 60 32 22 f0    	mov    %ax,0xf0223260
f010422a:	66 c7 05 62 32 22 f0 	movw   $0x8,0xf0223262
f0104231:	08 00 
f0104233:	c6 05 64 32 22 f0 00 	movb   $0x0,0xf0223264
f010423a:	c6 05 65 32 22 f0 8f 	movb   $0x8f,0xf0223265
f0104241:	c1 e8 10             	shr    $0x10,%eax
f0104244:	66 a3 66 32 22 f0    	mov    %ax,0xf0223266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f010424a:	b8 ae 49 10 f0       	mov    $0xf01049ae,%eax
f010424f:	66 a3 70 32 22 f0    	mov    %ax,0xf0223270
f0104255:	66 c7 05 72 32 22 f0 	movw   $0x8,0xf0223272
f010425c:	08 00 
f010425e:	c6 05 74 32 22 f0 00 	movb   $0x0,0xf0223274
f0104265:	c6 05 75 32 22 f0 8e 	movb   $0x8e,0xf0223275
f010426c:	c1 e8 10             	shr    $0x10,%eax
f010426f:	66 a3 76 32 22 f0    	mov    %ax,0xf0223276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0104275:	b8 b4 49 10 f0       	mov    $0xf01049b4,%eax
f010427a:	66 a3 78 32 22 f0    	mov    %ax,0xf0223278
f0104280:	66 c7 05 7a 32 22 f0 	movw   $0x8,0xf022327a
f0104287:	08 00 
f0104289:	c6 05 7c 32 22 f0 00 	movb   $0x0,0xf022327c
f0104290:	c6 05 7d 32 22 f0 ef 	movb   $0xef,0xf022327d
f0104297:	c1 e8 10             	shr    $0x10,%eax
f010429a:	66 a3 7e 32 22 f0    	mov    %ax,0xf022327e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f01042a0:	b8 ba 49 10 f0       	mov    $0xf01049ba,%eax
f01042a5:	66 a3 80 32 22 f0    	mov    %ax,0xf0223280
f01042ab:	66 c7 05 82 32 22 f0 	movw   $0x8,0xf0223282
f01042b2:	08 00 
f01042b4:	c6 05 84 32 22 f0 00 	movb   $0x0,0xf0223284
f01042bb:	c6 05 85 32 22 f0 ef 	movb   $0xef,0xf0223285
f01042c2:	c1 e8 10             	shr    $0x10,%eax
f01042c5:	66 a3 86 32 22 f0    	mov    %ax,0xf0223286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f01042cb:	b8 c0 49 10 f0       	mov    $0xf01049c0,%eax
f01042d0:	66 a3 88 32 22 f0    	mov    %ax,0xf0223288
f01042d6:	66 c7 05 8a 32 22 f0 	movw   $0x8,0xf022328a
f01042dd:	08 00 
f01042df:	c6 05 8c 32 22 f0 00 	movb   $0x0,0xf022328c
f01042e6:	c6 05 8d 32 22 f0 ef 	movb   $0xef,0xf022328d
f01042ed:	c1 e8 10             	shr    $0x10,%eax
f01042f0:	66 a3 8e 32 22 f0    	mov    %ax,0xf022328e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f01042f6:	b8 c6 49 10 f0       	mov    $0xf01049c6,%eax
f01042fb:	66 a3 90 32 22 f0    	mov    %ax,0xf0223290
f0104301:	66 c7 05 92 32 22 f0 	movw   $0x8,0xf0223292
f0104308:	08 00 
f010430a:	c6 05 94 32 22 f0 00 	movb   $0x0,0xf0223294
f0104311:	c6 05 95 32 22 f0 8f 	movb   $0x8f,0xf0223295
f0104318:	c1 e8 10             	shr    $0x10,%eax
f010431b:	66 a3 96 32 22 f0    	mov    %ax,0xf0223296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0104321:	b8 cc 49 10 f0       	mov    $0xf01049cc,%eax
f0104326:	66 a3 98 32 22 f0    	mov    %ax,0xf0223298
f010432c:	66 c7 05 9a 32 22 f0 	movw   $0x8,0xf022329a
f0104333:	08 00 
f0104335:	c6 05 9c 32 22 f0 00 	movb   $0x0,0xf022329c
f010433c:	c6 05 9d 32 22 f0 8f 	movb   $0x8f,0xf022329d
f0104343:	c1 e8 10             	shr    $0x10,%eax
f0104346:	66 a3 9e 32 22 f0    	mov    %ax,0xf022329e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f010434c:	b8 d2 49 10 f0       	mov    $0xf01049d2,%eax
f0104351:	66 a3 a0 32 22 f0    	mov    %ax,0xf02232a0
f0104357:	66 c7 05 a2 32 22 f0 	movw   $0x8,0xf02232a2
f010435e:	08 00 
f0104360:	c6 05 a4 32 22 f0 00 	movb   $0x0,0xf02232a4
f0104367:	c6 05 a5 32 22 f0 8f 	movb   $0x8f,0xf02232a5
f010436e:	c1 e8 10             	shr    $0x10,%eax
f0104371:	66 a3 a6 32 22 f0    	mov    %ax,0xf02232a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0104377:	b8 d6 49 10 f0       	mov    $0xf01049d6,%eax
f010437c:	66 a3 b0 32 22 f0    	mov    %ax,0xf02232b0
f0104382:	66 c7 05 b2 32 22 f0 	movw   $0x8,0xf02232b2
f0104389:	08 00 
f010438b:	c6 05 b4 32 22 f0 00 	movb   $0x0,0xf02232b4
f0104392:	c6 05 b5 32 22 f0 8f 	movb   $0x8f,0xf02232b5
f0104399:	c1 e8 10             	shr    $0x10,%eax
f010439c:	66 a3 b6 32 22 f0    	mov    %ax,0xf02232b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f01043a2:	b8 da 49 10 f0       	mov    $0xf01049da,%eax
f01043a7:	66 a3 b8 32 22 f0    	mov    %ax,0xf02232b8
f01043ad:	66 c7 05 ba 32 22 f0 	movw   $0x8,0xf02232ba
f01043b4:	08 00 
f01043b6:	c6 05 bc 32 22 f0 00 	movb   $0x0,0xf02232bc
f01043bd:	c6 05 bd 32 22 f0 8f 	movb   $0x8f,0xf02232bd
f01043c4:	c1 e8 10             	shr    $0x10,%eax
f01043c7:	66 a3 be 32 22 f0    	mov    %ax,0xf02232be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f01043cd:	b8 de 49 10 f0       	mov    $0xf01049de,%eax
f01043d2:	66 a3 c0 32 22 f0    	mov    %ax,0xf02232c0
f01043d8:	66 c7 05 c2 32 22 f0 	movw   $0x8,0xf02232c2
f01043df:	08 00 
f01043e1:	c6 05 c4 32 22 f0 00 	movb   $0x0,0xf02232c4
f01043e8:	c6 05 c5 32 22 f0 8f 	movb   $0x8f,0xf02232c5
f01043ef:	c1 e8 10             	shr    $0x10,%eax
f01043f2:	66 a3 c6 32 22 f0    	mov    %ax,0xf02232c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f01043f8:	b8 e6 49 10 f0       	mov    $0xf01049e6,%eax
f01043fd:	66 a3 d0 32 22 f0    	mov    %ax,0xf02232d0
f0104403:	66 c7 05 d2 32 22 f0 	movw   $0x8,0xf02232d2
f010440a:	08 00 
f010440c:	c6 05 d4 32 22 f0 00 	movb   $0x0,0xf02232d4
f0104413:	c6 05 d5 32 22 f0 8f 	movb   $0x8f,0xf02232d5
f010441a:	c1 e8 10             	shr    $0x10,%eax
f010441d:	66 a3 d6 32 22 f0    	mov    %ax,0xf02232d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0104423:	b8 e2 49 10 f0       	mov    $0xf01049e2,%eax
f0104428:	66 a3 c8 32 22 f0    	mov    %ax,0xf02232c8
f010442e:	66 c7 05 ca 32 22 f0 	movw   $0x8,0xf02232ca
f0104435:	08 00 
f0104437:	c6 05 cc 32 22 f0 00 	movb   $0x0,0xf02232cc
f010443e:	c6 05 cd 32 22 f0 8f 	movb   $0x8f,0xf02232cd
f0104445:	c1 e8 10             	shr    $0x10,%eax
f0104448:	66 a3 ce 32 22 f0    	mov    %ax,0xf02232ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f010444e:	b8 ea 49 10 f0       	mov    $0xf01049ea,%eax
f0104453:	66 a3 e0 32 22 f0    	mov    %ax,0xf02232e0
f0104459:	66 c7 05 e2 32 22 f0 	movw   $0x8,0xf02232e2
f0104460:	08 00 
f0104462:	c6 05 e4 32 22 f0 00 	movb   $0x0,0xf02232e4
f0104469:	c6 05 e5 32 22 f0 8f 	movb   $0x8f,0xf02232e5
f0104470:	c1 e8 10             	shr    $0x10,%eax
f0104473:	66 a3 e6 32 22 f0    	mov    %ax,0xf02232e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0104479:	b8 f0 49 10 f0       	mov    $0xf01049f0,%eax
f010447e:	66 a3 e8 32 22 f0    	mov    %ax,0xf02232e8
f0104484:	66 c7 05 ea 32 22 f0 	movw   $0x8,0xf02232ea
f010448b:	08 00 
f010448d:	c6 05 ec 32 22 f0 00 	movb   $0x0,0xf02232ec
f0104494:	c6 05 ed 32 22 f0 8f 	movb   $0x8f,0xf02232ed
f010449b:	c1 e8 10             	shr    $0x10,%eax
f010449e:	66 a3 ee 32 22 f0    	mov    %ax,0xf02232ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f01044a4:	b8 f4 49 10 f0       	mov    $0xf01049f4,%eax
f01044a9:	66 a3 f0 32 22 f0    	mov    %ax,0xf02232f0
f01044af:	66 c7 05 f2 32 22 f0 	movw   $0x8,0xf02232f2
f01044b6:	08 00 
f01044b8:	c6 05 f4 32 22 f0 00 	movb   $0x0,0xf02232f4
f01044bf:	c6 05 f5 32 22 f0 8f 	movb   $0x8f,0xf02232f5
f01044c6:	c1 e8 10             	shr    $0x10,%eax
f01044c9:	66 a3 f6 32 22 f0    	mov    %ax,0xf02232f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f01044cf:	b8 fa 49 10 f0       	mov    $0xf01049fa,%eax
f01044d4:	66 a3 f8 32 22 f0    	mov    %ax,0xf02232f8
f01044da:	66 c7 05 fa 32 22 f0 	movw   $0x8,0xf02232fa
f01044e1:	08 00 
f01044e3:	c6 05 fc 32 22 f0 00 	movb   $0x0,0xf02232fc
f01044ea:	c6 05 fd 32 22 f0 8f 	movb   $0x8f,0xf02232fd
f01044f1:	c1 e8 10             	shr    $0x10,%eax
f01044f4:	66 a3 fe 32 22 f0    	mov    %ax,0xf02232fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f01044fa:	b8 00 4a 10 f0       	mov    $0xf0104a00,%eax
f01044ff:	66 a3 e0 33 22 f0    	mov    %ax,0xf02233e0
f0104505:	66 c7 05 e2 33 22 f0 	movw   $0x8,0xf02233e2
f010450c:	08 00 
f010450e:	c6 05 e4 33 22 f0 00 	movb   $0x0,0xf02233e4
f0104515:	c6 05 e5 33 22 f0 ee 	movb   $0xee,0xf02233e5
f010451c:	c1 e8 10             	shr    $0x10,%eax
f010451f:	66 a3 e6 33 22 f0    	mov    %ax,0xf02233e6
	// LAB 3: Your code here.

	// Per-CPU setup 
	trap_init_percpu();
f0104525:	e8 1f fc ff ff       	call   f0104149 <trap_init_percpu>
}
f010452a:	c9                   	leave  
f010452b:	c3                   	ret    

f010452c <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f010452c:	55                   	push   %ebp
f010452d:	89 e5                	mov    %esp,%ebp
f010452f:	53                   	push   %ebx
f0104530:	83 ec 14             	sub    $0x14,%esp
f0104533:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f0104536:	8b 03                	mov    (%ebx),%eax
f0104538:	89 44 24 04          	mov    %eax,0x4(%esp)
f010453c:	c7 04 24 a7 78 10 f0 	movl   $0xf01078a7,(%esp)
f0104543:	e8 e7 fb ff ff       	call   f010412f <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f0104548:	8b 43 04             	mov    0x4(%ebx),%eax
f010454b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010454f:	c7 04 24 b6 78 10 f0 	movl   $0xf01078b6,(%esp)
f0104556:	e8 d4 fb ff ff       	call   f010412f <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010455b:	8b 43 08             	mov    0x8(%ebx),%eax
f010455e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104562:	c7 04 24 c5 78 10 f0 	movl   $0xf01078c5,(%esp)
f0104569:	e8 c1 fb ff ff       	call   f010412f <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010456e:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104571:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104575:	c7 04 24 d4 78 10 f0 	movl   $0xf01078d4,(%esp)
f010457c:	e8 ae fb ff ff       	call   f010412f <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104581:	8b 43 10             	mov    0x10(%ebx),%eax
f0104584:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104588:	c7 04 24 e3 78 10 f0 	movl   $0xf01078e3,(%esp)
f010458f:	e8 9b fb ff ff       	call   f010412f <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104594:	8b 43 14             	mov    0x14(%ebx),%eax
f0104597:	89 44 24 04          	mov    %eax,0x4(%esp)
f010459b:	c7 04 24 f2 78 10 f0 	movl   $0xf01078f2,(%esp)
f01045a2:	e8 88 fb ff ff       	call   f010412f <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f01045a7:	8b 43 18             	mov    0x18(%ebx),%eax
f01045aa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045ae:	c7 04 24 01 79 10 f0 	movl   $0xf0107901,(%esp)
f01045b5:	e8 75 fb ff ff       	call   f010412f <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f01045ba:	8b 43 1c             	mov    0x1c(%ebx),%eax
f01045bd:	89 44 24 04          	mov    %eax,0x4(%esp)
f01045c1:	c7 04 24 10 79 10 f0 	movl   $0xf0107910,(%esp)
f01045c8:	e8 62 fb ff ff       	call   f010412f <cprintf>
}
f01045cd:	83 c4 14             	add    $0x14,%esp
f01045d0:	5b                   	pop    %ebx
f01045d1:	5d                   	pop    %ebp
f01045d2:	c3                   	ret    

f01045d3 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f01045d3:	55                   	push   %ebp
f01045d4:	89 e5                	mov    %esp,%ebp
f01045d6:	56                   	push   %esi
f01045d7:	53                   	push   %ebx
f01045d8:	83 ec 10             	sub    $0x10,%esp
f01045db:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f01045de:	e8 60 1a 00 00       	call   f0106043 <cpunum>
f01045e3:	89 44 24 08          	mov    %eax,0x8(%esp)
f01045e7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01045eb:	c7 04 24 74 79 10 f0 	movl   $0xf0107974,(%esp)
f01045f2:	e8 38 fb ff ff       	call   f010412f <cprintf>
	print_regs(&tf->tf_regs);
f01045f7:	89 1c 24             	mov    %ebx,(%esp)
f01045fa:	e8 2d ff ff ff       	call   f010452c <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01045ff:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f0104603:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104607:	c7 04 24 92 79 10 f0 	movl   $0xf0107992,(%esp)
f010460e:	e8 1c fb ff ff       	call   f010412f <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f0104613:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f0104617:	89 44 24 04          	mov    %eax,0x4(%esp)
f010461b:	c7 04 24 a5 79 10 f0 	movl   $0xf01079a5,(%esp)
f0104622:	e8 08 fb ff ff       	call   f010412f <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104627:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f010462a:	83 f8 13             	cmp    $0x13,%eax
f010462d:	77 09                	ja     f0104638 <print_trapframe+0x65>
		return excnames[trapno];
f010462f:	8b 14 85 60 7c 10 f0 	mov    -0xfef83a0(,%eax,4),%edx
f0104636:	eb 1f                	jmp    f0104657 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f0104638:	83 f8 30             	cmp    $0x30,%eax
f010463b:	74 15                	je     f0104652 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f010463d:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f0104640:	83 fa 0f             	cmp    $0xf,%edx
f0104643:	ba 2b 79 10 f0       	mov    $0xf010792b,%edx
f0104648:	b9 3e 79 10 f0       	mov    $0xf010793e,%ecx
f010464d:	0f 47 d1             	cmova  %ecx,%edx
f0104650:	eb 05                	jmp    f0104657 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104652:	ba 1f 79 10 f0       	mov    $0xf010791f,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104657:	89 54 24 08          	mov    %edx,0x8(%esp)
f010465b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010465f:	c7 04 24 b8 79 10 f0 	movl   $0xf01079b8,(%esp)
f0104666:	e8 c4 fa ff ff       	call   f010412f <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010466b:	3b 1d 60 3a 22 f0    	cmp    0xf0223a60,%ebx
f0104671:	75 19                	jne    f010468c <print_trapframe+0xb9>
f0104673:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104677:	75 13                	jne    f010468c <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0104679:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010467c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104680:	c7 04 24 ca 79 10 f0 	movl   $0xf01079ca,(%esp)
f0104687:	e8 a3 fa ff ff       	call   f010412f <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010468c:	8b 43 2c             	mov    0x2c(%ebx),%eax
f010468f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104693:	c7 04 24 d9 79 10 f0 	movl   $0xf01079d9,(%esp)
f010469a:	e8 90 fa ff ff       	call   f010412f <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010469f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f01046a3:	75 51                	jne    f01046f6 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f01046a5:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f01046a8:	89 c2                	mov    %eax,%edx
f01046aa:	83 e2 01             	and    $0x1,%edx
f01046ad:	ba 4d 79 10 f0       	mov    $0xf010794d,%edx
f01046b2:	b9 58 79 10 f0       	mov    $0xf0107958,%ecx
f01046b7:	0f 45 ca             	cmovne %edx,%ecx
f01046ba:	89 c2                	mov    %eax,%edx
f01046bc:	83 e2 02             	and    $0x2,%edx
f01046bf:	ba 64 79 10 f0       	mov    $0xf0107964,%edx
f01046c4:	be 6a 79 10 f0       	mov    $0xf010796a,%esi
f01046c9:	0f 44 d6             	cmove  %esi,%edx
f01046cc:	83 e0 04             	and    $0x4,%eax
f01046cf:	b8 6f 79 10 f0       	mov    $0xf010796f,%eax
f01046d4:	be bf 7a 10 f0       	mov    $0xf0107abf,%esi
f01046d9:	0f 44 c6             	cmove  %esi,%eax
f01046dc:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01046e0:	89 54 24 08          	mov    %edx,0x8(%esp)
f01046e4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01046e8:	c7 04 24 e7 79 10 f0 	movl   $0xf01079e7,(%esp)
f01046ef:	e8 3b fa ff ff       	call   f010412f <cprintf>
f01046f4:	eb 0c                	jmp    f0104702 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01046f6:	c7 04 24 12 78 10 f0 	movl   $0xf0107812,(%esp)
f01046fd:	e8 2d fa ff ff       	call   f010412f <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f0104702:	8b 43 30             	mov    0x30(%ebx),%eax
f0104705:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104709:	c7 04 24 f6 79 10 f0 	movl   $0xf01079f6,(%esp)
f0104710:	e8 1a fa ff ff       	call   f010412f <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f0104715:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104719:	89 44 24 04          	mov    %eax,0x4(%esp)
f010471d:	c7 04 24 05 7a 10 f0 	movl   $0xf0107a05,(%esp)
f0104724:	e8 06 fa ff ff       	call   f010412f <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f0104729:	8b 43 38             	mov    0x38(%ebx),%eax
f010472c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104730:	c7 04 24 18 7a 10 f0 	movl   $0xf0107a18,(%esp)
f0104737:	e8 f3 f9 ff ff       	call   f010412f <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f010473c:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f0104740:	74 27                	je     f0104769 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f0104742:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104745:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104749:	c7 04 24 27 7a 10 f0 	movl   $0xf0107a27,(%esp)
f0104750:	e8 da f9 ff ff       	call   f010412f <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104755:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0104759:	89 44 24 04          	mov    %eax,0x4(%esp)
f010475d:	c7 04 24 36 7a 10 f0 	movl   $0xf0107a36,(%esp)
f0104764:	e8 c6 f9 ff ff       	call   f010412f <cprintf>
	}
}
f0104769:	83 c4 10             	add    $0x10,%esp
f010476c:	5b                   	pop    %ebx
f010476d:	5e                   	pop    %esi
f010476e:	5d                   	pop    %ebp
f010476f:	c3                   	ret    

f0104770 <break_point_handler>:
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
	cprintf("  eax  0x%08x\n", regs->reg_eax);
}
void
break_point_handler(struct Trapframe *tf)
{
f0104770:	55                   	push   %ebp
f0104771:	89 e5                	mov    %esp,%ebp
f0104773:	83 ec 18             	sub    $0x18,%esp
	monitor(tf);
f0104776:	8b 45 08             	mov    0x8(%ebp),%eax
f0104779:	89 04 24             	mov    %eax,(%esp)
f010477c:	e8 16 c2 ff ff       	call   f0100997 <monitor>
}
f0104781:	c9                   	leave  
f0104782:	c3                   	ret    

f0104783 <trap>:



void
trap(struct Trapframe *tf)
{
f0104783:	55                   	push   %ebp
f0104784:	89 e5                	mov    %esp,%ebp
f0104786:	57                   	push   %edi
f0104787:	56                   	push   %esi
f0104788:	83 ec 10             	sub    $0x10,%esp
f010478b:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f010478e:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f010478f:	83 3d 80 3e 22 f0 00 	cmpl   $0x0,0xf0223e80
f0104796:	74 01                	je     f0104799 <trap+0x16>
		asm volatile("hlt");
f0104798:	f4                   	hlt    

static __inline uint32_t
read_eflags(void)
{
        uint32_t eflags;
        __asm __volatile("pushfl; popl %0" : "=r" (eflags));
f0104799:	9c                   	pushf  
f010479a:	58                   	pop    %eax

	// Check that interrupts are disabled.  If this assertion
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	assert(!(read_eflags() & FL_IF));
f010479b:	f6 c4 02             	test   $0x2,%ah
f010479e:	74 24                	je     f01047c4 <trap+0x41>
f01047a0:	c7 44 24 0c 49 7a 10 	movl   $0xf0107a49,0xc(%esp)
f01047a7:	f0 
f01047a8:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f01047af:	f0 
f01047b0:	c7 44 24 04 13 01 00 	movl   $0x113,0x4(%esp)
f01047b7:	00 
f01047b8:	c7 04 24 62 7a 10 f0 	movl   $0xf0107a62,(%esp)
f01047bf:	e8 7c b8 ff ff       	call   f0100040 <_panic>
//<<<<<< HEAD
   // panic("trap called!");
	cprintf("Incoming TRAP frame at %p\n", tf);
f01047c4:	89 74 24 04          	mov    %esi,0x4(%esp)
f01047c8:	c7 04 24 6e 7a 10 f0 	movl   $0xf0107a6e,(%esp)
f01047cf:	e8 5b f9 ff ff       	call   f010412f <cprintf>
//=======
//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e

	if ((tf->tf_cs & 3) == 3) {
f01047d4:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01047d8:	83 e0 03             	and    $0x3,%eax
f01047db:	66 83 f8 03          	cmp    $0x3,%ax
f01047df:	0f 85 a7 00 00 00    	jne    f010488c <trap+0x109>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01047e5:	c7 04 24 a0 03 12 f0 	movl   $0xf01203a0,(%esp)
f01047ec:	e8 b8 1a 00 00       	call   f01062a9 <spin_lock>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		lock_kernel();
		assert(curenv);
f01047f1:	e8 4d 18 00 00       	call   f0106043 <cpunum>
f01047f6:	6b c0 74             	imul   $0x74,%eax,%eax
f01047f9:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f0104800:	75 24                	jne    f0104826 <trap+0xa3>
f0104802:	c7 44 24 0c 89 7a 10 	movl   $0xf0107a89,0xc(%esp)
f0104809:	f0 
f010480a:	c7 44 24 08 0c 6d 10 	movl   $0xf0106d0c,0x8(%esp)
f0104811:	f0 
f0104812:	c7 44 24 04 20 01 00 	movl   $0x120,0x4(%esp)
f0104819:	00 
f010481a:	c7 04 24 62 7a 10 f0 	movl   $0xf0107a62,(%esp)
f0104821:	e8 1a b8 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f0104826:	e8 18 18 00 00       	call   f0106043 <cpunum>
f010482b:	6b c0 74             	imul   $0x74,%eax,%eax
f010482e:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104834:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f0104838:	75 2d                	jne    f0104867 <trap+0xe4>
			env_free(curenv);
f010483a:	e8 04 18 00 00       	call   f0106043 <cpunum>
f010483f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104842:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104848:	89 04 24             	mov    %eax,(%esp)
f010484b:	e8 1c f4 ff ff       	call   f0103c6c <env_free>
			curenv = NULL;
f0104850:	e8 ee 17 00 00       	call   f0106043 <cpunum>
f0104855:	6b c0 74             	imul   $0x74,%eax,%eax
f0104858:	c7 80 28 40 22 f0 00 	movl   $0x0,-0xfddbfd8(%eax)
f010485f:	00 00 00 
			sched_yield();
f0104862:	e8 b9 01 00 00       	call   f0104a20 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f0104867:	e8 d7 17 00 00       	call   f0106043 <cpunum>
f010486c:	6b c0 74             	imul   $0x74,%eax,%eax
f010486f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104875:	b9 11 00 00 00       	mov    $0x11,%ecx
f010487a:	89 c7                	mov    %eax,%edi
f010487c:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f010487e:	e8 c0 17 00 00       	call   f0106043 <cpunum>
f0104883:	6b c0 74             	imul   $0x74,%eax,%eax
f0104886:	8b b0 28 40 22 f0    	mov    -0xfddbfd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f010488c:	89 35 60 3a 22 f0    	mov    %esi,0xf0223a60
}
static void
trap_dispatch(struct Trapframe *tf)
{
	// Handle processor exceptions.
	print_trapframe(tf);
f0104892:	89 34 24             	mov    %esi,(%esp)
f0104895:	e8 39 fd ff ff       	call   f01045d3 <print_trapframe>
//=======

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f010489a:	83 7e 28 27          	cmpl   $0x27,0x28(%esi)
f010489e:	75 16                	jne    f01048b6 <trap+0x133>
		cprintf("Spurious interrupt on irq 7\n");
f01048a0:	c7 04 24 90 7a 10 f0 	movl   $0xf0107a90,(%esp)
f01048a7:	e8 83 f8 ff ff       	call   f010412f <cprintf>
		print_trapframe(tf);
f01048ac:	89 34 24             	mov    %esi,(%esp)
f01048af:	e8 1f fd ff ff       	call   f01045d3 <print_trapframe>
f01048b4:	eb 39                	jmp    f01048ef <trap+0x16c>
	// LAB 4: Your code here.

//>>>>>>> e7799a7dc7b7fb18b76a4dbb1bc55ee40575013e
	// Unexpected trap: The user process or the kernel has a bug.

	if (tf->tf_cs == GD_KT)
f01048b6:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f01048bb:	75 1c                	jne    f01048d9 <trap+0x156>
		panic("unhandled trap in kernel");
f01048bd:	c7 44 24 08 ad 7a 10 	movl   $0xf0107aad,0x8(%esp)
f01048c4:	f0 
f01048c5:	c7 44 24 04 fb 00 00 	movl   $0xfb,0x4(%esp)
f01048cc:	00 
f01048cd:	c7 04 24 62 7a 10 f0 	movl   $0xf0107a62,(%esp)
f01048d4:	e8 67 b7 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f01048d9:	e8 65 17 00 00       	call   f0106043 <cpunum>
f01048de:	6b c0 74             	imul   $0x74,%eax,%eax
f01048e1:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f01048e7:	89 04 24             	mov    %eax,(%esp)
f01048ea:	e8 82 f5 ff ff       	call   f0103e71 <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f01048ef:	e8 4f 17 00 00       	call   f0106043 <cpunum>
f01048f4:	6b c0 74             	imul   $0x74,%eax,%eax
f01048f7:	83 b8 28 40 22 f0 00 	cmpl   $0x0,-0xfddbfd8(%eax)
f01048fe:	74 2a                	je     f010492a <trap+0x1a7>
f0104900:	e8 3e 17 00 00       	call   f0106043 <cpunum>
f0104905:	6b c0 74             	imul   $0x74,%eax,%eax
f0104908:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f010490e:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0104912:	75 16                	jne    f010492a <trap+0x1a7>
		env_run(curenv);
f0104914:	e8 2a 17 00 00       	call   f0106043 <cpunum>
f0104919:	6b c0 74             	imul   $0x74,%eax,%eax
f010491c:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104922:	89 04 24             	mov    %eax,(%esp)
f0104925:	e8 e8 f5 ff ff       	call   f0103f12 <env_run>
	else
		sched_yield();
f010492a:	e8 f1 00 00 00       	call   f0104a20 <sched_yield>

f010492f <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f010492f:	55                   	push   %ebp
f0104930:	89 e5                	mov    %esp,%ebp
f0104932:	56                   	push   %esi
f0104933:	53                   	push   %ebx
f0104934:	83 ec 10             	sub    $0x10,%esp
f0104937:	8b 45 08             	mov    0x8(%ebp),%eax

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f010493a:	0f 20 d3             	mov    %cr2,%ebx
	uint32_t fault_va;

	// Read processor's CR2 register to find the faulting address
	fault_va = rcr2();
	if((tf->tf_cs & 3)==0)
f010493d:	f6 40 34 03          	testb  $0x3,0x34(%eax)
f0104941:	75 1c                	jne    f010495f <page_fault_handler+0x30>
	{
		panic("kernel mode page faults!!");
f0104943:	c7 44 24 08 c6 7a 10 	movl   $0xf0107ac6,0x8(%esp)
f010494a:	f0 
f010494b:	c7 44 24 04 4b 01 00 	movl   $0x14b,0x4(%esp)
f0104952:	00 
f0104953:	c7 04 24 62 7a 10 f0 	movl   $0xf0107a62,(%esp)
f010495a:	e8 e1 b6 ff ff       	call   f0100040 <_panic>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f010495f:	8b 70 30             	mov    0x30(%eax),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104962:	e8 dc 16 00 00       	call   f0106043 <cpunum>
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104967:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010496b:	89 5c 24 08          	mov    %ebx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f010496f:	6b c0 74             	imul   $0x74,%eax,%eax
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.

	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104972:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104978:	8b 40 48             	mov    0x48(%eax),%eax
f010497b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010497f:	c7 04 24 24 7c 10 f0 	movl   $0xf0107c24,(%esp)
f0104986:	e8 a4 f7 ff ff       	call   f010412f <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	//print_trapframe(tf);
	env_destroy(curenv);
f010498b:	e8 b3 16 00 00       	call   f0106043 <cpunum>
f0104990:	6b c0 74             	imul   $0x74,%eax,%eax
f0104993:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104999:	89 04 24             	mov    %eax,(%esp)
f010499c:	e8 d0 f4 ff ff       	call   f0103e71 <env_destroy>
}
f01049a1:	83 c4 10             	add    $0x10,%esp
f01049a4:	5b                   	pop    %ebx
f01049a5:	5e                   	pop    %esi
f01049a6:	5d                   	pop    %ebp
f01049a7:	c3                   	ret    

f01049a8 <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01049a8:	6a 00                	push   $0x0
f01049aa:	6a 00                	push   $0x0
f01049ac:	eb 58                	jmp    f0104a06 <_alltraps>

f01049ae <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01049ae:	6a 00                	push   $0x0
f01049b0:	6a 02                	push   $0x2
f01049b2:	eb 52                	jmp    f0104a06 <_alltraps>

f01049b4 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01049b4:	6a 00                	push   $0x0
f01049b6:	6a 03                	push   $0x3
f01049b8:	eb 4c                	jmp    f0104a06 <_alltraps>

f01049ba <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01049ba:	6a 00                	push   $0x0
f01049bc:	6a 04                	push   $0x4
f01049be:	eb 46                	jmp    f0104a06 <_alltraps>

f01049c0 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01049c0:	6a 00                	push   $0x0
f01049c2:	6a 05                	push   $0x5
f01049c4:	eb 40                	jmp    f0104a06 <_alltraps>

f01049c6 <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01049c6:	6a 00                	push   $0x0
f01049c8:	6a 06                	push   $0x6
f01049ca:	eb 3a                	jmp    f0104a06 <_alltraps>

f01049cc <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01049cc:	6a 00                	push   $0x0
f01049ce:	6a 07                	push   $0x7
f01049d0:	eb 34                	jmp    f0104a06 <_alltraps>

f01049d2 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01049d2:	6a 08                	push   $0x8
f01049d4:	eb 30                	jmp    f0104a06 <_alltraps>

f01049d6 <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01049d6:	6a 0a                	push   $0xa
f01049d8:	eb 2c                	jmp    f0104a06 <_alltraps>

f01049da <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f01049da:	6a 0b                	push   $0xb
f01049dc:	eb 28                	jmp    f0104a06 <_alltraps>

f01049de <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f01049de:	6a 0c                	push   $0xc
f01049e0:	eb 24                	jmp    f0104a06 <_alltraps>

f01049e2 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f01049e2:	6a 0d                	push   $0xd
f01049e4:	eb 20                	jmp    f0104a06 <_alltraps>

f01049e6 <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f01049e6:	6a 0e                	push   $0xe
f01049e8:	eb 1c                	jmp    f0104a06 <_alltraps>

f01049ea <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f01049ea:	6a 00                	push   $0x0
f01049ec:	6a 10                	push   $0x10
f01049ee:	eb 16                	jmp    f0104a06 <_alltraps>

f01049f0 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f01049f0:	6a 11                	push   $0x11
f01049f2:	eb 12                	jmp    f0104a06 <_alltraps>

f01049f4 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f01049f4:	6a 00                	push   $0x0
f01049f6:	6a 12                	push   $0x12
f01049f8:	eb 0c                	jmp    f0104a06 <_alltraps>

f01049fa <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f01049fa:	6a 00                	push   $0x0
f01049fc:	6a 13                	push   $0x13
f01049fe:	eb 06                	jmp    f0104a06 <_alltraps>

f0104a00 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104a00:	6a 00                	push   $0x0
f0104a02:	6a 30                	push   $0x30
f0104a04:	eb 00                	jmp    f0104a06 <_alltraps>

f0104a06 <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
pushw $0
f0104a06:	66 6a 00             	pushw  $0x0
pushw %ds
f0104a09:	66 1e                	pushw  %ds
pushw $0
f0104a0b:	66 6a 00             	pushw  $0x0
pushw %es
f0104a0e:	66 06                	pushw  %es
pushal
f0104a10:	60                   	pusha  
pushl %esp
f0104a11:	54                   	push   %esp
movw $(GD_KD),%ax
f0104a12:	66 b8 10 00          	mov    $0x10,%ax
movw %ax,%ds
f0104a16:	8e d8                	mov    %eax,%ds
movw %ax,%es
f0104a18:	8e c0                	mov    %eax,%es
call trap
f0104a1a:	e8 64 fd ff ff       	call   f0104783 <trap>
f0104a1f:	90                   	nop

f0104a20 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f0104a20:	55                   	push   %ebp
f0104a21:	89 e5                	mov    %esp,%ebp
f0104a23:	57                   	push   %edi
f0104a24:	56                   	push   %esi
f0104a25:	53                   	push   %ebx
f0104a26:	83 ec 1c             	sub    $0x1c,%esp
	// idle environment (env_type == ENV_TYPE_IDLE).  If there are
	// no runnable environments, simply drop through to the code
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
    struct Env *curr = thiscpu->cpu_env;
f0104a29:	e8 15 16 00 00       	call   f0106043 <cpunum>
f0104a2e:	6b c0 74             	imul   $0x74,%eax,%eax
f0104a31:	8b b0 28 40 22 f0    	mov    -0xfddbfd8(%eax),%esi
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
f0104a37:	85 f6                	test   %esi,%esi
f0104a39:	0f 84 df 00 00 00    	je     f0104b1e <sched_yield+0xfe>
f0104a3f:	8b 7e 48             	mov    0x48(%esi),%edi
f0104a42:	81 e7 ff 03 00 00    	and    $0x3ff,%edi
f0104a48:	e9 d6 00 00 00       	jmp    f0104b23 <sched_yield+0x103>
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
f0104a4d:	8d 47 01             	lea    0x1(%edi),%eax
f0104a50:	99                   	cltd   
f0104a51:	c1 ea 16             	shr    $0x16,%edx
f0104a54:	01 d0                	add    %edx,%eax
f0104a56:	25 ff 03 00 00       	and    $0x3ff,%eax
f0104a5b:	29 d0                	sub    %edx,%eax
f0104a5d:	89 c7                	mov    %eax,%edi
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f0104a5f:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104a62:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f0104a65:	83 7a 50 01          	cmpl   $0x1,0x50(%edx)
f0104a69:	74 0e                	je     f0104a79 <sched_yield+0x59>
            continue;
        
        if (envs[idx].env_status == ENV_RUNNABLE)
f0104a6b:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f0104a6f:	75 08                	jne    f0104a79 <sched_yield+0x59>
            env_run(&envs[idx]);
f0104a71:	89 14 24             	mov    %edx,(%esp)
f0104a74:	e8 99 f4 ff ff       	call   f0103f12 <env_run>
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
    struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
	for (i = 1; i < NENV; i++) {
f0104a79:	83 e9 01             	sub    $0x1,%ecx
f0104a7c:	75 cf                	jne    f0104a4d <sched_yield+0x2d>
        
        if (envs[idx].env_status == ENV_RUNNABLE)
            env_run(&envs[idx]);
	}

    if (curr && curr->env_status == ENV_RUNNING) {
f0104a7e:	85 f6                	test   %esi,%esi
f0104a80:	74 06                	je     f0104a88 <sched_yield+0x68>
f0104a82:	83 7e 54 03          	cmpl   $0x3,0x54(%esi)
f0104a86:	74 09                	je     f0104a91 <sched_yield+0x71>
f0104a88:	89 d8                	mov    %ebx,%eax
    struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f0104a8a:	ba 00 00 00 00       	mov    $0x0,%edx
f0104a8f:	eb 08                	jmp    f0104a99 <sched_yield+0x79>
            env_run(&envs[idx]);
	}

    if (curr && curr->env_status == ENV_RUNNING) {
        // If not found and current environment is running, then continue running.
        env_run(curr);
f0104a91:	89 34 24             	mov    %esi,(%esp)
f0104a94:	e8 79 f4 ff ff       	call   f0103f12 <env_run>

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a99:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104a9d:	74 0b                	je     f0104aaa <sched_yield+0x8a>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104a9f:	8b 70 54             	mov    0x54(%eax),%esi
f0104aa2:	8d 4e fe             	lea    -0x2(%esi),%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104aa5:	83 f9 01             	cmp    $0x1,%ecx
f0104aa8:	76 10                	jbe    f0104aba <sched_yield+0x9a>
    }

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104aaa:	83 c2 01             	add    $0x1,%edx
f0104aad:	83 c0 7c             	add    $0x7c,%eax
f0104ab0:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104ab6:	75 e1                	jne    f0104a99 <sched_yield+0x79>
f0104ab8:	eb 08                	jmp    f0104ac2 <sched_yield+0xa2>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104aba:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104ac0:	75 1a                	jne    f0104adc <sched_yield+0xbc>
		cprintf("No more runnable environments!\n");
f0104ac2:	c7 04 24 b0 7c 10 f0 	movl   $0xf0107cb0,(%esp)
f0104ac9:	e8 61 f6 ff ff       	call   f010412f <cprintf>
		while (1)
			monitor(NULL);
f0104ace:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104ad5:	e8 bd be ff ff       	call   f0100997 <monitor>
f0104ada:	eb f2                	jmp    f0104ace <sched_yield+0xae>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104adc:	e8 62 15 00 00       	call   f0106043 <cpunum>
f0104ae1:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104ae4:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104ae6:	8b 43 54             	mov    0x54(%ebx),%eax
f0104ae9:	83 e8 02             	sub    $0x2,%eax
f0104aec:	83 f8 01             	cmp    $0x1,%eax
f0104aef:	76 25                	jbe    f0104b16 <sched_yield+0xf6>
		panic("CPU %d: No idle environment!", cpunum());
f0104af1:	e8 4d 15 00 00       	call   f0106043 <cpunum>
f0104af6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104afa:	c7 44 24 08 d0 7c 10 	movl   $0xf0107cd0,0x8(%esp)
f0104b01:	f0 
f0104b02:	c7 44 24 04 43 00 00 	movl   $0x43,0x4(%esp)
f0104b09:	00 
f0104b0a:	c7 04 24 ed 7c 10 f0 	movl   $0xf0107ced,(%esp)
f0104b11:	e8 2a b5 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104b16:	89 1c 24             	mov    %ebx,(%esp)
f0104b19:	e8 f4 f3 ff ff       	call   f0103f12 <env_run>
	// no runnable environments, simply drop through to the code
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
    struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
f0104b1e:	bf 00 00 00 00       	mov    $0x0,%edi
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f0104b23:	8b 1d 48 32 22 f0    	mov    0xf0223248,%ebx
f0104b29:	b9 ff 03 00 00       	mov    $0x3ff,%ecx
f0104b2e:	e9 1a ff ff ff       	jmp    f0104a4d <sched_yield+0x2d>
f0104b33:	66 90                	xchg   %ax,%ax
f0104b35:	66 90                	xchg   %ax,%ax
f0104b37:	66 90                	xchg   %ax,%ax
f0104b39:	66 90                	xchg   %ax,%ax
f0104b3b:	66 90                	xchg   %ax,%ax
f0104b3d:	66 90                	xchg   %ax,%ax
f0104b3f:	90                   	nop

f0104b40 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104b40:	55                   	push   %ebp
f0104b41:	89 e5                	mov    %esp,%ebp
f0104b43:	53                   	push   %ebx
f0104b44:	83 ec 24             	sub    $0x24,%esp
f0104b47:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
		
	int32_t r=0;		
	switch(syscallno){
f0104b4a:	83 f8 0a             	cmp    $0xa,%eax
f0104b4d:	0f 87 0b 01 00 00    	ja     f0104c5e <syscall+0x11e>
f0104b53:	ff 24 85 34 7d 10 f0 	jmp    *-0xfef82cc(,%eax,4)
{
	// Check that the user has permission to read memory [s, s+len).
	// Destroy the environment if not.

	// LAB 3: Your code here.
	user_mem_assert(curenv, s, len, 0);
f0104b5a:	e8 e4 14 00 00       	call   f0106043 <cpunum>
f0104b5f:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104b66:	00 
f0104b67:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104b6a:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104b6e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0104b71:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104b75:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b78:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104b7e:	89 04 24             	mov    %eax,(%esp)
f0104b81:	e8 e6 ea ff ff       	call   f010366c <user_mem_assert>
	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104b86:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b89:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104b8d:	8b 45 10             	mov    0x10(%ebp),%eax
f0104b90:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b94:	c7 04 24 fa 7c 10 f0 	movl   $0xf0107cfa,(%esp)
f0104b9b:	e8 8f f5 ff ff       	call   f010412f <cprintf>
{
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
		
	int32_t r=0;		
f0104ba0:	b8 00 00 00 00       	mov    $0x0,%eax
f0104ba5:	e9 b9 00 00 00       	jmp    f0104c63 <syscall+0x123>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104baa:	e8 d6 ba ff ff       	call   f0100685 <cons_getc>
	int32_t r=0;		
	switch(syscallno){
	case SYS_cputs:sys_cputs((const char*)a1, (size_t)a2);
			break;
        case SYS_cgetc: r=sys_cgetc();
			break;
f0104baf:	90                   	nop
f0104bb0:	e9 ae 00 00 00       	jmp    f0104c63 <syscall+0x123>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104bb5:	e8 89 14 00 00       	call   f0106043 <cpunum>
f0104bba:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bbd:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104bc3:	8b 40 48             	mov    0x48(%eax),%eax
	case SYS_cputs:sys_cputs((const char*)a1, (size_t)a2);
			break;
        case SYS_cgetc: r=sys_cgetc();
			break;
	case SYS_getenvid: r=sys_getenvid();
			break;
f0104bc6:	e9 98 00 00 00       	jmp    f0104c63 <syscall+0x123>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104bcb:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104bd2:	00 
f0104bd3:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0104bd6:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bda:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104bdd:	89 04 24             	mov    %eax,(%esp)
f0104be0:	e8 8f eb ff ff       	call   f0103774 <envid2env>
f0104be5:	85 c0                	test   %eax,%eax
f0104be7:	78 7a                	js     f0104c63 <syscall+0x123>
		return r;
	if (e == curenv)
f0104be9:	e8 55 14 00 00       	call   f0106043 <cpunum>
f0104bee:	8b 55 f4             	mov    -0xc(%ebp),%edx
f0104bf1:	6b c0 74             	imul   $0x74,%eax,%eax
f0104bf4:	39 90 28 40 22 f0    	cmp    %edx,-0xfddbfd8(%eax)
f0104bfa:	75 23                	jne    f0104c1f <syscall+0xdf>
		cprintf("[%08x] exiting gracefully\n", curenv->env_id);
f0104bfc:	e8 42 14 00 00       	call   f0106043 <cpunum>
f0104c01:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c04:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104c0a:	8b 40 48             	mov    0x48(%eax),%eax
f0104c0d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c11:	c7 04 24 ff 7c 10 f0 	movl   $0xf0107cff,(%esp)
f0104c18:	e8 12 f5 ff ff       	call   f010412f <cprintf>
f0104c1d:	eb 28                	jmp    f0104c47 <syscall+0x107>
	else
		cprintf("[%08x] destroying %08x\n", curenv->env_id, e->env_id);
f0104c1f:	8b 5a 48             	mov    0x48(%edx),%ebx
f0104c22:	e8 1c 14 00 00       	call   f0106043 <cpunum>
f0104c27:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0104c2b:	6b c0 74             	imul   $0x74,%eax,%eax
f0104c2e:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104c34:	8b 40 48             	mov    0x48(%eax),%eax
f0104c37:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c3b:	c7 04 24 1a 7d 10 f0 	movl   $0xf0107d1a,(%esp)
f0104c42:	e8 e8 f4 ff ff       	call   f010412f <cprintf>
	env_destroy(e);
f0104c47:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0104c4a:	89 04 24             	mov    %eax,(%esp)
f0104c4d:	e8 1f f2 ff ff       	call   f0103e71 <env_destroy>
	return 0;
f0104c52:	b8 00 00 00 00       	mov    $0x0,%eax
        case SYS_cgetc: r=sys_cgetc();
			break;
	case SYS_getenvid: r=sys_getenvid();
			break;
	case SYS_env_destroy: r=sys_env_destroy((envid_t)a1);
			break;
f0104c57:	eb 0a                	jmp    f0104c63 <syscall+0x123>

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0104c59:	e8 c2 fd ff ff       	call   f0104a20 <sched_yield>
			break;
	case SYS_yield:
		sys_yield();
		break;
	default:
		r=-E_INVAL;
f0104c5e:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	}

	return r;
	
	panic("syscall not implemented");
}
f0104c63:	83 c4 24             	add    $0x24,%esp
f0104c66:	5b                   	pop    %ebx
f0104c67:	5d                   	pop    %ebp
f0104c68:	c3                   	ret    
f0104c69:	66 90                	xchg   %ax,%ax
f0104c6b:	66 90                	xchg   %ax,%ax
f0104c6d:	66 90                	xchg   %ax,%ax
f0104c6f:	90                   	nop

f0104c70 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f0104c70:	55                   	push   %ebp
f0104c71:	89 e5                	mov    %esp,%ebp
f0104c73:	57                   	push   %edi
f0104c74:	56                   	push   %esi
f0104c75:	53                   	push   %ebx
f0104c76:	83 ec 14             	sub    $0x14,%esp
f0104c79:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0104c7c:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f0104c7f:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f0104c82:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f0104c85:	8b 1a                	mov    (%edx),%ebx
f0104c87:	8b 01                	mov    (%ecx),%eax
f0104c89:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f0104c8c:	39 c3                	cmp    %eax,%ebx
f0104c8e:	0f 8f 9a 00 00 00    	jg     f0104d2e <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f0104c94:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104c9b:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0104c9e:	01 d8                	add    %ebx,%eax
f0104ca0:	89 c7                	mov    %eax,%edi
f0104ca2:	c1 ef 1f             	shr    $0x1f,%edi
f0104ca5:	01 c7                	add    %eax,%edi
f0104ca7:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104ca9:	39 df                	cmp    %ebx,%edi
f0104cab:	0f 8c c4 00 00 00    	jl     f0104d75 <stab_binsearch+0x105>
f0104cb1:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0104cb4:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104cb7:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f0104cba:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f0104cbe:	39 f0                	cmp    %esi,%eax
f0104cc0:	0f 84 b4 00 00 00    	je     f0104d7a <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104cc6:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0104cc8:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f0104ccb:	39 d8                	cmp    %ebx,%eax
f0104ccd:	0f 8c a2 00 00 00    	jl     f0104d75 <stab_binsearch+0x105>
f0104cd3:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0104cd7:	83 ea 0c             	sub    $0xc,%edx
f0104cda:	39 f1                	cmp    %esi,%ecx
f0104cdc:	75 ea                	jne    f0104cc8 <stab_binsearch+0x58>
f0104cde:	e9 99 00 00 00       	jmp    f0104d7c <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0104ce3:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0104ce6:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0104ce8:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104ceb:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104cf2:	eb 2b                	jmp    f0104d1f <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0104cf4:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104cf7:	76 14                	jbe    f0104d0d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0104cf9:	83 e8 01             	sub    $0x1,%eax
f0104cfc:	89 45 f0             	mov    %eax,-0x10(%ebp)
f0104cff:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104d02:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104d04:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0104d0b:	eb 12                	jmp    f0104d1f <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f0104d0d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104d10:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0104d12:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0104d16:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0104d18:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f0104d1f:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0104d22:	0f 8e 73 ff ff ff    	jle    f0104c9b <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0104d28:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f0104d2c:	75 0f                	jne    f0104d3d <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f0104d2e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104d31:	8b 00                	mov    (%eax),%eax
f0104d33:	83 e8 01             	sub    $0x1,%eax
f0104d36:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104d39:	89 06                	mov    %eax,(%esi)
f0104d3b:	eb 57                	jmp    f0104d94 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104d3d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104d40:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0104d42:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104d45:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104d47:	39 c8                	cmp    %ecx,%eax
f0104d49:	7e 23                	jle    f0104d6e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104d4b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104d4e:	8b 7d ec             	mov    -0x14(%ebp),%edi
f0104d51:	8d 14 97             	lea    (%edi,%edx,4),%edx
f0104d54:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f0104d58:	39 f3                	cmp    %esi,%ebx
f0104d5a:	74 12                	je     f0104d6e <stab_binsearch+0xfe>
		     l--)
f0104d5c:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0104d5f:	39 c8                	cmp    %ecx,%eax
f0104d61:	7e 0b                	jle    f0104d6e <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f0104d63:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f0104d67:	83 ea 0c             	sub    $0xc,%edx
f0104d6a:	39 f3                	cmp    %esi,%ebx
f0104d6c:	75 ee                	jne    f0104d5c <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f0104d6e:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104d71:	89 06                	mov    %eax,(%esi)
f0104d73:	eb 1f                	jmp    f0104d94 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f0104d75:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f0104d78:	eb a5                	jmp    f0104d1f <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0104d7a:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f0104d7c:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104d7f:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0104d82:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f0104d86:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0104d89:	0f 82 54 ff ff ff    	jb     f0104ce3 <stab_binsearch+0x73>
f0104d8f:	e9 60 ff ff ff       	jmp    f0104cf4 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f0104d94:	83 c4 14             	add    $0x14,%esp
f0104d97:	5b                   	pop    %ebx
f0104d98:	5e                   	pop    %esi
f0104d99:	5f                   	pop    %edi
f0104d9a:	5d                   	pop    %ebp
f0104d9b:	c3                   	ret    

f0104d9c <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f0104d9c:	55                   	push   %ebp
f0104d9d:	89 e5                	mov    %esp,%ebp
f0104d9f:	57                   	push   %edi
f0104da0:	56                   	push   %esi
f0104da1:	53                   	push   %ebx
f0104da2:	83 ec 3c             	sub    $0x3c,%esp
f0104da5:	8b 7d 08             	mov    0x8(%ebp),%edi
f0104da8:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f0104dab:	c7 06 60 7d 10 f0    	movl   $0xf0107d60,(%esi)
	info->eip_line = 0;
f0104db1:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0104db8:	c7 46 08 60 7d 10 f0 	movl   $0xf0107d60,0x8(%esi)
	info->eip_fn_namelen = 9;
f0104dbf:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0104dc6:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0104dc9:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0104dd0:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0104dd6:	0f 87 ca 00 00 00    	ja     f0104ea6 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
f0104ddc:	e8 62 12 00 00       	call   f0106043 <cpunum>
f0104de1:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104de8:	00 
f0104de9:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0104df0:	00 
f0104df1:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0104df8:	00 
f0104df9:	6b c0 74             	imul   $0x74,%eax,%eax
f0104dfc:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104e02:	89 04 24             	mov    %eax,(%esp)
f0104e05:	e8 a7 e7 ff ff       	call   f01035b1 <user_mem_check>
f0104e0a:	85 c0                	test   %eax,%eax
f0104e0c:	0f 88 12 02 00 00    	js     f0105024 <debuginfo_eip+0x288>
		{
		    return -1;
		}
		stabs = usd->stabs;
f0104e12:	a1 00 00 20 00       	mov    0x200000,%eax
f0104e17:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f0104e1a:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0104e20:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0104e26:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0104e29:	a1 0c 00 20 00       	mov    0x20000c,%eax
f0104e2e:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
f0104e31:	e8 0d 12 00 00       	call   f0106043 <cpunum>
f0104e36:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104e3d:	00 
f0104e3e:	89 da                	mov    %ebx,%edx
f0104e40:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104e43:	29 ca                	sub    %ecx,%edx
f0104e45:	c1 fa 02             	sar    $0x2,%edx
f0104e48:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f0104e4e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104e52:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104e56:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e59:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104e5f:	89 04 24             	mov    %eax,(%esp)
f0104e62:	e8 4a e7 ff ff       	call   f01035b1 <user_mem_check>
f0104e67:	85 c0                	test   %eax,%eax
f0104e69:	0f 88 bc 01 00 00    	js     f010502b <debuginfo_eip+0x28f>
f0104e6f:	e8 cf 11 00 00       	call   f0106043 <cpunum>
f0104e74:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0104e7b:	00 
f0104e7c:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104e7f:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f0104e82:	29 ca                	sub    %ecx,%edx
f0104e84:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104e88:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0104e8c:	6b c0 74             	imul   $0x74,%eax,%eax
f0104e8f:	8b 80 28 40 22 f0    	mov    -0xfddbfd8(%eax),%eax
f0104e95:	89 04 24             	mov    %eax,(%esp)
f0104e98:	e8 14 e7 ff ff       	call   f01035b1 <user_mem_check>
f0104e9d:	85 c0                	test   %eax,%eax
f0104e9f:	79 1f                	jns    f0104ec0 <debuginfo_eip+0x124>
f0104ea1:	e9 8c 01 00 00       	jmp    f0105032 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f0104ea6:	c7 45 cc 62 59 11 f0 	movl   $0xf0115962,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f0104ead:	c7 45 d0 01 25 11 f0 	movl   $0xf0112501,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0104eb4:	bb 00 25 11 f0       	mov    $0xf0112500,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0104eb9:	c7 45 d4 34 82 10 f0 	movl   $0xf0108234,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0104ec0:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0104ec3:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0104ec6:	0f 83 6d 01 00 00    	jae    f0105039 <debuginfo_eip+0x29d>
f0104ecc:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0104ed0:	0f 85 6a 01 00 00    	jne    f0105040 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0104ed6:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f0104edd:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0104ee0:	c1 fb 02             	sar    $0x2,%ebx
f0104ee3:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0104ee9:	83 e8 01             	sub    $0x1,%eax
f0104eec:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f0104eef:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104ef3:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f0104efa:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f0104efd:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104f00:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0104f03:	89 d8                	mov    %ebx,%eax
f0104f05:	e8 66 fd ff ff       	call   f0104c70 <stab_binsearch>
	if (lfile == 0)
f0104f0a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104f0d:	85 c0                	test   %eax,%eax
f0104f0f:	0f 84 32 01 00 00    	je     f0105047 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0104f15:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0104f18:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104f1b:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f0104f1e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0104f22:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0104f29:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f0104f2c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0104f2f:	89 d8                	mov    %ebx,%eax
f0104f31:	e8 3a fd ff ff       	call   f0104c70 <stab_binsearch>

	if (lfun <= rfun) {
f0104f36:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0104f39:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f0104f3c:	7f 23                	jg     f0104f61 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f0104f3e:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104f41:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104f44:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0104f47:	8b 10                	mov    (%eax),%edx
f0104f49:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f0104f4c:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f0104f4f:	39 ca                	cmp    %ecx,%edx
f0104f51:	73 06                	jae    f0104f59 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f0104f53:	03 55 d0             	add    -0x30(%ebp),%edx
f0104f56:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f0104f59:	8b 40 08             	mov    0x8(%eax),%eax
f0104f5c:	89 46 10             	mov    %eax,0x10(%esi)
f0104f5f:	eb 06                	jmp    f0104f67 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f0104f61:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f0104f64:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f0104f67:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f0104f6e:	00 
f0104f6f:	8b 46 08             	mov    0x8(%esi),%eax
f0104f72:	89 04 24             	mov    %eax,(%esp)
f0104f75:	e8 05 0a 00 00       	call   f010597f <strfind>
f0104f7a:	2b 46 08             	sub    0x8(%esi),%eax
f0104f7d:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104f80:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0104f83:	39 fb                	cmp    %edi,%ebx
f0104f85:	7c 5d                	jl     f0104fe4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104f87:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104f8a:	c1 e0 02             	shl    $0x2,%eax
f0104f8d:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0104f90:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f0104f93:	89 55 c8             	mov    %edx,-0x38(%ebp)
f0104f96:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f0104f9a:	80 fa 84             	cmp    $0x84,%dl
f0104f9d:	74 2d                	je     f0104fcc <debuginfo_eip+0x230>
f0104f9f:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f0104fa3:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0104fa6:	eb 15                	jmp    f0104fbd <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f0104fa8:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f0104fab:	39 fb                	cmp    %edi,%ebx
f0104fad:	7c 35                	jl     f0104fe4 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f0104faf:	89 c1                	mov    %eax,%ecx
f0104fb1:	83 e8 0c             	sub    $0xc,%eax
f0104fb4:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0104fb8:	80 fa 84             	cmp    $0x84,%dl
f0104fbb:	74 0f                	je     f0104fcc <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f0104fbd:	80 fa 64             	cmp    $0x64,%dl
f0104fc0:	75 e6                	jne    f0104fa8 <debuginfo_eip+0x20c>
f0104fc2:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0104fc6:	74 e0                	je     f0104fa8 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0104fc8:	39 df                	cmp    %ebx,%edi
f0104fca:	7f 18                	jg     f0104fe4 <debuginfo_eip+0x248>
f0104fcc:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0104fcf:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0104fd2:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0104fd5:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0104fd8:	2b 55 d0             	sub    -0x30(%ebp),%edx
f0104fdb:	39 d0                	cmp    %edx,%eax
f0104fdd:	73 05                	jae    f0104fe4 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f0104fdf:	03 45 d0             	add    -0x30(%ebp),%eax
f0104fe2:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104fe4:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0104fe7:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f0104fea:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0104fef:	39 ca                	cmp    %ecx,%edx
f0104ff1:	7d 75                	jge    f0105068 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0104ff3:	8d 42 01             	lea    0x1(%edx),%eax
f0104ff6:	39 c1                	cmp    %eax,%ecx
f0104ff8:	7e 54                	jle    f010504e <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f0104ffa:	8d 14 40             	lea    (%eax,%eax,2),%edx
f0104ffd:	c1 e2 02             	shl    $0x2,%edx
f0105000:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105003:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0105008:	75 4b                	jne    f0105055 <debuginfo_eip+0x2b9>
f010500a:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f010500e:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0105012:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0105015:	39 c1                	cmp    %eax,%ecx
f0105017:	7e 43                	jle    f010505c <debuginfo_eip+0x2c0>
f0105019:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f010501c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0105020:	74 ec                	je     f010500e <debuginfo_eip+0x272>
f0105022:	eb 3f                	jmp    f0105063 <debuginfo_eip+0x2c7>
		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
		{
		    return -1;
f0105024:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105029:	eb 3d                	jmp    f0105068 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
		 {
		    return -1;
f010502b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105030:	eb 36                	jmp    f0105068 <debuginfo_eip+0x2cc>
f0105032:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105037:	eb 2f                	jmp    f0105068 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0105039:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010503e:	eb 28                	jmp    f0105068 <debuginfo_eip+0x2cc>
f0105040:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105045:	eb 21                	jmp    f0105068 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0105047:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010504c:	eb 1a                	jmp    f0105068 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010504e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105053:	eb 13                	jmp    f0105068 <debuginfo_eip+0x2cc>
f0105055:	b8 00 00 00 00       	mov    $0x0,%eax
f010505a:	eb 0c                	jmp    f0105068 <debuginfo_eip+0x2cc>
f010505c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105061:	eb 05                	jmp    f0105068 <debuginfo_eip+0x2cc>
f0105063:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105068:	83 c4 3c             	add    $0x3c,%esp
f010506b:	5b                   	pop    %ebx
f010506c:	5e                   	pop    %esi
f010506d:	5f                   	pop    %edi
f010506e:	5d                   	pop    %ebp
f010506f:	c3                   	ret    

f0105070 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f0105070:	55                   	push   %ebp
f0105071:	89 e5                	mov    %esp,%ebp
f0105073:	57                   	push   %edi
f0105074:	56                   	push   %esi
f0105075:	53                   	push   %ebx
f0105076:	83 ec 3c             	sub    $0x3c,%esp
f0105079:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f010507c:	89 d7                	mov    %edx,%edi
f010507e:	8b 45 08             	mov    0x8(%ebp),%eax
f0105081:	89 45 e0             	mov    %eax,-0x20(%ebp)
f0105084:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105087:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f010508a:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f010508d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105092:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0105095:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f0105098:	39 f1                	cmp    %esi,%ecx
f010509a:	72 14                	jb     f01050b0 <printnum+0x40>
f010509c:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f010509f:	76 0f                	jbe    f01050b0 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01050a1:	8b 45 14             	mov    0x14(%ebp),%eax
f01050a4:	8d 70 ff             	lea    -0x1(%eax),%esi
f01050a7:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01050aa:	85 f6                	test   %esi,%esi
f01050ac:	7f 60                	jg     f010510e <printnum+0x9e>
f01050ae:	eb 72                	jmp    f0105122 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f01050b0:	8b 4d 18             	mov    0x18(%ebp),%ecx
f01050b3:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f01050b7:	8b 4d 14             	mov    0x14(%ebp),%ecx
f01050ba:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01050bd:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01050c1:	89 44 24 08          	mov    %eax,0x8(%esp)
f01050c5:	8b 44 24 08          	mov    0x8(%esp),%eax
f01050c9:	8b 54 24 0c          	mov    0xc(%esp),%edx
f01050cd:	89 c3                	mov    %eax,%ebx
f01050cf:	89 d6                	mov    %edx,%esi
f01050d1:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01050d4:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01050d7:	89 54 24 08          	mov    %edx,0x8(%esp)
f01050db:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f01050df:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01050e2:	89 04 24             	mov    %eax,(%esp)
f01050e5:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01050e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01050ec:	e8 bf 13 00 00       	call   f01064b0 <__udivdi3>
f01050f1:	89 d9                	mov    %ebx,%ecx
f01050f3:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f01050f7:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01050fb:	89 04 24             	mov    %eax,(%esp)
f01050fe:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105102:	89 fa                	mov    %edi,%edx
f0105104:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105107:	e8 64 ff ff ff       	call   f0105070 <printnum>
f010510c:	eb 14                	jmp    f0105122 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f010510e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105112:	8b 45 18             	mov    0x18(%ebp),%eax
f0105115:	89 04 24             	mov    %eax,(%esp)
f0105118:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f010511a:	83 ee 01             	sub    $0x1,%esi
f010511d:	75 ef                	jne    f010510e <printnum+0x9e>
f010511f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0105122:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105126:	8b 7c 24 04          	mov    0x4(%esp),%edi
f010512a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010512d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105130:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105134:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105138:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010513b:	89 04 24             	mov    %eax,(%esp)
f010513e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105141:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105145:	e8 96 14 00 00       	call   f01065e0 <__umoddi3>
f010514a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010514e:	0f be 80 6a 7d 10 f0 	movsbl -0xfef8296(%eax),%eax
f0105155:	89 04 24             	mov    %eax,(%esp)
f0105158:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010515b:	ff d0                	call   *%eax
}
f010515d:	83 c4 3c             	add    $0x3c,%esp
f0105160:	5b                   	pop    %ebx
f0105161:	5e                   	pop    %esi
f0105162:	5f                   	pop    %edi
f0105163:	5d                   	pop    %ebp
f0105164:	c3                   	ret    

f0105165 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f0105165:	55                   	push   %ebp
f0105166:	89 e5                	mov    %esp,%ebp
f0105168:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f010516b:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f010516f:	8b 10                	mov    (%eax),%edx
f0105171:	3b 50 04             	cmp    0x4(%eax),%edx
f0105174:	73 0a                	jae    f0105180 <sprintputch+0x1b>
		*b->buf++ = ch;
f0105176:	8d 4a 01             	lea    0x1(%edx),%ecx
f0105179:	89 08                	mov    %ecx,(%eax)
f010517b:	8b 45 08             	mov    0x8(%ebp),%eax
f010517e:	88 02                	mov    %al,(%edx)
}
f0105180:	5d                   	pop    %ebp
f0105181:	c3                   	ret    

f0105182 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f0105182:	55                   	push   %ebp
f0105183:	89 e5                	mov    %esp,%ebp
f0105185:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f0105188:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f010518b:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010518f:	8b 45 10             	mov    0x10(%ebp),%eax
f0105192:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105196:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105199:	89 44 24 04          	mov    %eax,0x4(%esp)
f010519d:	8b 45 08             	mov    0x8(%ebp),%eax
f01051a0:	89 04 24             	mov    %eax,(%esp)
f01051a3:	e8 02 00 00 00       	call   f01051aa <vprintfmt>
	va_end(ap);
}
f01051a8:	c9                   	leave  
f01051a9:	c3                   	ret    

f01051aa <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01051aa:	55                   	push   %ebp
f01051ab:	89 e5                	mov    %esp,%ebp
f01051ad:	57                   	push   %edi
f01051ae:	56                   	push   %esi
f01051af:	53                   	push   %ebx
f01051b0:	83 ec 3c             	sub    $0x3c,%esp
f01051b3:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01051b6:	89 df                	mov    %ebx,%edi
f01051b8:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01051bb:	eb 03                	jmp    f01051c0 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f01051bd:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01051c0:	8b 45 10             	mov    0x10(%ebp),%eax
f01051c3:	8d 70 01             	lea    0x1(%eax),%esi
f01051c6:	0f b6 00             	movzbl (%eax),%eax
f01051c9:	83 f8 25             	cmp    $0x25,%eax
f01051cc:	74 2d                	je     f01051fb <vprintfmt+0x51>
			if (ch == '\0')
f01051ce:	85 c0                	test   %eax,%eax
f01051d0:	75 14                	jne    f01051e6 <vprintfmt+0x3c>
f01051d2:	e9 6b 04 00 00       	jmp    f0105642 <vprintfmt+0x498>
f01051d7:	85 c0                	test   %eax,%eax
f01051d9:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f01051e0:	0f 84 5c 04 00 00    	je     f0105642 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f01051e6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01051ea:	89 04 24             	mov    %eax,(%esp)
f01051ed:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f01051ef:	83 c6 01             	add    $0x1,%esi
f01051f2:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f01051f6:	83 f8 25             	cmp    $0x25,%eax
f01051f9:	75 dc                	jne    f01051d7 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f01051fb:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f01051ff:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0105206:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010520d:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0105214:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105219:	eb 1f                	jmp    f010523a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010521b:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f010521e:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0105222:	eb 16                	jmp    f010523a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105224:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105227:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f010522b:	eb 0d                	jmp    f010523a <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f010522d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105230:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105233:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010523a:	8d 46 01             	lea    0x1(%esi),%eax
f010523d:	89 45 10             	mov    %eax,0x10(%ebp)
f0105240:	0f b6 06             	movzbl (%esi),%eax
f0105243:	0f b6 d0             	movzbl %al,%edx
f0105246:	83 e8 23             	sub    $0x23,%eax
f0105249:	3c 55                	cmp    $0x55,%al
f010524b:	0f 87 c4 03 00 00    	ja     f0105615 <vprintfmt+0x46b>
f0105251:	0f b6 c0             	movzbl %al,%eax
f0105254:	ff 24 85 20 7e 10 f0 	jmp    *-0xfef81e0(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f010525b:	8d 42 d0             	lea    -0x30(%edx),%eax
f010525e:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f0105261:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f0105265:	8d 50 d0             	lea    -0x30(%eax),%edx
f0105268:	83 fa 09             	cmp    $0x9,%edx
f010526b:	77 63                	ja     f01052d0 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010526d:	8b 75 10             	mov    0x10(%ebp),%esi
f0105270:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f0105273:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f0105276:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f0105279:	8d 14 92             	lea    (%edx,%edx,4),%edx
f010527c:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f0105280:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f0105283:	8d 48 d0             	lea    -0x30(%eax),%ecx
f0105286:	83 f9 09             	cmp    $0x9,%ecx
f0105289:	76 eb                	jbe    f0105276 <vprintfmt+0xcc>
f010528b:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f010528e:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f0105291:	eb 40                	jmp    f01052d3 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f0105293:	8b 45 14             	mov    0x14(%ebp),%eax
f0105296:	8b 00                	mov    (%eax),%eax
f0105298:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f010529b:	8b 45 14             	mov    0x14(%ebp),%eax
f010529e:	8d 40 04             	lea    0x4(%eax),%eax
f01052a1:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01052a4:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f01052a7:	eb 2a                	jmp    f01052d3 <vprintfmt+0x129>
f01052a9:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f01052ac:	85 d2                	test   %edx,%edx
f01052ae:	b8 00 00 00 00       	mov    $0x0,%eax
f01052b3:	0f 49 c2             	cmovns %edx,%eax
f01052b6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01052b9:	8b 75 10             	mov    0x10(%ebp),%esi
f01052bc:	e9 79 ff ff ff       	jmp    f010523a <vprintfmt+0x90>
f01052c1:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f01052c4:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f01052cb:	e9 6a ff ff ff       	jmp    f010523a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01052d0:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f01052d3:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f01052d7:	0f 89 5d ff ff ff    	jns    f010523a <vprintfmt+0x90>
f01052dd:	e9 4b ff ff ff       	jmp    f010522d <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f01052e2:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01052e5:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f01052e8:	e9 4d ff ff ff       	jmp    f010523a <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f01052ed:	8b 45 14             	mov    0x14(%ebp),%eax
f01052f0:	8d 70 04             	lea    0x4(%eax),%esi
f01052f3:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01052f7:	8b 00                	mov    (%eax),%eax
f01052f9:	89 04 24             	mov    %eax,(%esp)
f01052fc:	ff d7                	call   *%edi
f01052fe:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0105301:	e9 ba fe ff ff       	jmp    f01051c0 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0105306:	8b 45 14             	mov    0x14(%ebp),%eax
f0105309:	8d 70 04             	lea    0x4(%eax),%esi
f010530c:	8b 00                	mov    (%eax),%eax
f010530e:	99                   	cltd   
f010530f:	31 d0                	xor    %edx,%eax
f0105311:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0105313:	83 f8 08             	cmp    $0x8,%eax
f0105316:	7f 0b                	jg     f0105323 <vprintfmt+0x179>
f0105318:	8b 14 85 80 7f 10 f0 	mov    -0xfef8080(,%eax,4),%edx
f010531f:	85 d2                	test   %edx,%edx
f0105321:	75 20                	jne    f0105343 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f0105323:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105327:	c7 44 24 08 82 7d 10 	movl   $0xf0107d82,0x8(%esp)
f010532e:	f0 
f010532f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105333:	89 3c 24             	mov    %edi,(%esp)
f0105336:	e8 47 fe ff ff       	call   f0105182 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f010533b:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f010533e:	e9 7d fe ff ff       	jmp    f01051c0 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f0105343:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105347:	c7 44 24 08 1e 6d 10 	movl   $0xf0106d1e,0x8(%esp)
f010534e:	f0 
f010534f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105353:	89 3c 24             	mov    %edi,(%esp)
f0105356:	e8 27 fe ff ff       	call   f0105182 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f010535b:	89 75 14             	mov    %esi,0x14(%ebp)
f010535e:	e9 5d fe ff ff       	jmp    f01051c0 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105363:	8b 45 14             	mov    0x14(%ebp),%eax
f0105366:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0105369:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f010536c:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f0105370:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f0105372:	85 c0                	test   %eax,%eax
f0105374:	b9 7b 7d 10 f0       	mov    $0xf0107d7b,%ecx
f0105379:	0f 45 c8             	cmovne %eax,%ecx
f010537c:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f010537f:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f0105383:	74 04                	je     f0105389 <vprintfmt+0x1df>
f0105385:	85 f6                	test   %esi,%esi
f0105387:	7f 19                	jg     f01053a2 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105389:	8b 45 d0             	mov    -0x30(%ebp),%eax
f010538c:	8d 70 01             	lea    0x1(%eax),%esi
f010538f:	0f b6 10             	movzbl (%eax),%edx
f0105392:	0f be c2             	movsbl %dl,%eax
f0105395:	85 c0                	test   %eax,%eax
f0105397:	0f 85 9a 00 00 00    	jne    f0105437 <vprintfmt+0x28d>
f010539d:	e9 87 00 00 00       	jmp    f0105429 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01053a2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01053a6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01053a9:	89 04 24             	mov    %eax,(%esp)
f01053ac:	e8 11 04 00 00       	call   f01057c2 <strnlen>
f01053b1:	29 c6                	sub    %eax,%esi
f01053b3:	89 f0                	mov    %esi,%eax
f01053b5:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f01053b8:	85 f6                	test   %esi,%esi
f01053ba:	7e cd                	jle    f0105389 <vprintfmt+0x1df>
					putch(padc, putdat);
f01053bc:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01053c0:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f01053c3:	89 c3                	mov    %eax,%ebx
f01053c5:	8b 45 0c             	mov    0xc(%ebp),%eax
f01053c8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01053cc:	89 34 24             	mov    %esi,(%esp)
f01053cf:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01053d1:	83 eb 01             	sub    $0x1,%ebx
f01053d4:	75 ef                	jne    f01053c5 <vprintfmt+0x21b>
f01053d6:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f01053d9:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01053dc:	eb ab                	jmp    f0105389 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f01053de:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f01053e2:	74 1e                	je     f0105402 <vprintfmt+0x258>
f01053e4:	0f be d2             	movsbl %dl,%edx
f01053e7:	83 ea 20             	sub    $0x20,%edx
f01053ea:	83 fa 5e             	cmp    $0x5e,%edx
f01053ed:	76 13                	jbe    f0105402 <vprintfmt+0x258>
					putch('?', putdat);
f01053ef:	8b 45 0c             	mov    0xc(%ebp),%eax
f01053f2:	89 44 24 04          	mov    %eax,0x4(%esp)
f01053f6:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f01053fd:	ff 55 08             	call   *0x8(%ebp)
f0105400:	eb 0d                	jmp    f010540f <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0105402:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0105405:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105409:	89 04 24             	mov    %eax,(%esp)
f010540c:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f010540f:	83 eb 01             	sub    $0x1,%ebx
f0105412:	83 c6 01             	add    $0x1,%esi
f0105415:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0105419:	0f be c2             	movsbl %dl,%eax
f010541c:	85 c0                	test   %eax,%eax
f010541e:	75 23                	jne    f0105443 <vprintfmt+0x299>
f0105420:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105423:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105426:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105429:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f010542c:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105430:	7f 25                	jg     f0105457 <vprintfmt+0x2ad>
f0105432:	e9 89 fd ff ff       	jmp    f01051c0 <vprintfmt+0x16>
f0105437:	89 7d 08             	mov    %edi,0x8(%ebp)
f010543a:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010543d:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0105440:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105443:	85 ff                	test   %edi,%edi
f0105445:	78 97                	js     f01053de <vprintfmt+0x234>
f0105447:	83 ef 01             	sub    $0x1,%edi
f010544a:	79 92                	jns    f01053de <vprintfmt+0x234>
f010544c:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f010544f:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105452:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105455:	eb d2                	jmp    f0105429 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f0105457:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010545b:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f0105462:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f0105464:	83 ee 01             	sub    $0x1,%esi
f0105467:	75 ee                	jne    f0105457 <vprintfmt+0x2ad>
f0105469:	e9 52 fd ff ff       	jmp    f01051c0 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010546e:	83 f9 01             	cmp    $0x1,%ecx
f0105471:	7e 19                	jle    f010548c <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f0105473:	8b 45 14             	mov    0x14(%ebp),%eax
f0105476:	8b 50 04             	mov    0x4(%eax),%edx
f0105479:	8b 00                	mov    (%eax),%eax
f010547b:	89 45 d8             	mov    %eax,-0x28(%ebp)
f010547e:	89 55 dc             	mov    %edx,-0x24(%ebp)
f0105481:	8b 45 14             	mov    0x14(%ebp),%eax
f0105484:	8d 40 08             	lea    0x8(%eax),%eax
f0105487:	89 45 14             	mov    %eax,0x14(%ebp)
f010548a:	eb 38                	jmp    f01054c4 <vprintfmt+0x31a>
	else if (lflag)
f010548c:	85 c9                	test   %ecx,%ecx
f010548e:	74 1b                	je     f01054ab <vprintfmt+0x301>
		return va_arg(*ap, long);
f0105490:	8b 45 14             	mov    0x14(%ebp),%eax
f0105493:	8b 30                	mov    (%eax),%esi
f0105495:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105498:	89 f0                	mov    %esi,%eax
f010549a:	c1 f8 1f             	sar    $0x1f,%eax
f010549d:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01054a0:	8b 45 14             	mov    0x14(%ebp),%eax
f01054a3:	8d 40 04             	lea    0x4(%eax),%eax
f01054a6:	89 45 14             	mov    %eax,0x14(%ebp)
f01054a9:	eb 19                	jmp    f01054c4 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f01054ab:	8b 45 14             	mov    0x14(%ebp),%eax
f01054ae:	8b 30                	mov    (%eax),%esi
f01054b0:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01054b3:	89 f0                	mov    %esi,%eax
f01054b5:	c1 f8 1f             	sar    $0x1f,%eax
f01054b8:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01054bb:	8b 45 14             	mov    0x14(%ebp),%eax
f01054be:	8d 40 04             	lea    0x4(%eax),%eax
f01054c1:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f01054c4:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01054c7:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f01054ca:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f01054cf:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f01054d3:	0f 89 06 01 00 00    	jns    f01055df <vprintfmt+0x435>
				putch('-', putdat);
f01054d9:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01054dd:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f01054e4:	ff d7                	call   *%edi
				num = -(long long) num;
f01054e6:	8b 55 d8             	mov    -0x28(%ebp),%edx
f01054e9:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f01054ec:	f7 da                	neg    %edx
f01054ee:	83 d1 00             	adc    $0x0,%ecx
f01054f1:	f7 d9                	neg    %ecx
			}
			base = 10;
f01054f3:	b8 0a 00 00 00       	mov    $0xa,%eax
f01054f8:	e9 e2 00 00 00       	jmp    f01055df <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01054fd:	83 f9 01             	cmp    $0x1,%ecx
f0105500:	7e 10                	jle    f0105512 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f0105502:	8b 45 14             	mov    0x14(%ebp),%eax
f0105505:	8b 10                	mov    (%eax),%edx
f0105507:	8b 48 04             	mov    0x4(%eax),%ecx
f010550a:	8d 40 08             	lea    0x8(%eax),%eax
f010550d:	89 45 14             	mov    %eax,0x14(%ebp)
f0105510:	eb 26                	jmp    f0105538 <vprintfmt+0x38e>
	else if (lflag)
f0105512:	85 c9                	test   %ecx,%ecx
f0105514:	74 12                	je     f0105528 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f0105516:	8b 45 14             	mov    0x14(%ebp),%eax
f0105519:	8b 10                	mov    (%eax),%edx
f010551b:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105520:	8d 40 04             	lea    0x4(%eax),%eax
f0105523:	89 45 14             	mov    %eax,0x14(%ebp)
f0105526:	eb 10                	jmp    f0105538 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f0105528:	8b 45 14             	mov    0x14(%ebp),%eax
f010552b:	8b 10                	mov    (%eax),%edx
f010552d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105532:	8d 40 04             	lea    0x4(%eax),%eax
f0105535:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f0105538:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f010553d:	e9 9d 00 00 00       	jmp    f01055df <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f0105542:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105546:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010554d:	ff d7                	call   *%edi
			putch('X', putdat);
f010554f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105553:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010555a:	ff d7                	call   *%edi
			putch('X', putdat);
f010555c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105560:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f0105567:	ff d7                	call   *%edi
			break;
f0105569:	e9 52 fc ff ff       	jmp    f01051c0 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f010556e:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105572:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f0105579:	ff d7                	call   *%edi
			putch('x', putdat);
f010557b:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010557f:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f0105586:	ff d7                	call   *%edi
			num = (unsigned long long)
f0105588:	8b 45 14             	mov    0x14(%ebp),%eax
f010558b:	8b 10                	mov    (%eax),%edx
f010558d:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f0105592:	8d 40 04             	lea    0x4(%eax),%eax
f0105595:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f0105598:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f010559d:	eb 40                	jmp    f01055df <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010559f:	83 f9 01             	cmp    $0x1,%ecx
f01055a2:	7e 10                	jle    f01055b4 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f01055a4:	8b 45 14             	mov    0x14(%ebp),%eax
f01055a7:	8b 10                	mov    (%eax),%edx
f01055a9:	8b 48 04             	mov    0x4(%eax),%ecx
f01055ac:	8d 40 08             	lea    0x8(%eax),%eax
f01055af:	89 45 14             	mov    %eax,0x14(%ebp)
f01055b2:	eb 26                	jmp    f01055da <vprintfmt+0x430>
	else if (lflag)
f01055b4:	85 c9                	test   %ecx,%ecx
f01055b6:	74 12                	je     f01055ca <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f01055b8:	8b 45 14             	mov    0x14(%ebp),%eax
f01055bb:	8b 10                	mov    (%eax),%edx
f01055bd:	b9 00 00 00 00       	mov    $0x0,%ecx
f01055c2:	8d 40 04             	lea    0x4(%eax),%eax
f01055c5:	89 45 14             	mov    %eax,0x14(%ebp)
f01055c8:	eb 10                	jmp    f01055da <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f01055ca:	8b 45 14             	mov    0x14(%ebp),%eax
f01055cd:	8b 10                	mov    (%eax),%edx
f01055cf:	b9 00 00 00 00       	mov    $0x0,%ecx
f01055d4:	8d 40 04             	lea    0x4(%eax),%eax
f01055d7:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f01055da:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f01055df:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f01055e3:	89 74 24 10          	mov    %esi,0x10(%esp)
f01055e7:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01055ea:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01055ee:	89 44 24 08          	mov    %eax,0x8(%esp)
f01055f2:	89 14 24             	mov    %edx,(%esp)
f01055f5:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01055f9:	89 da                	mov    %ebx,%edx
f01055fb:	89 f8                	mov    %edi,%eax
f01055fd:	e8 6e fa ff ff       	call   f0105070 <printnum>
			break;
f0105602:	e9 b9 fb ff ff       	jmp    f01051c0 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105607:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010560b:	89 14 24             	mov    %edx,(%esp)
f010560e:	ff d7                	call   *%edi
			break;
f0105610:	e9 ab fb ff ff       	jmp    f01051c0 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105615:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105619:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105620:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105622:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0105626:	0f 84 91 fb ff ff    	je     f01051bd <vprintfmt+0x13>
f010562c:	89 75 10             	mov    %esi,0x10(%ebp)
f010562f:	89 f0                	mov    %esi,%eax
f0105631:	83 e8 01             	sub    $0x1,%eax
f0105634:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f0105638:	75 f7                	jne    f0105631 <vprintfmt+0x487>
f010563a:	89 45 10             	mov    %eax,0x10(%ebp)
f010563d:	e9 7e fb ff ff       	jmp    f01051c0 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f0105642:	83 c4 3c             	add    $0x3c,%esp
f0105645:	5b                   	pop    %ebx
f0105646:	5e                   	pop    %esi
f0105647:	5f                   	pop    %edi
f0105648:	5d                   	pop    %ebp
f0105649:	c3                   	ret    

f010564a <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f010564a:	55                   	push   %ebp
f010564b:	89 e5                	mov    %esp,%ebp
f010564d:	83 ec 28             	sub    $0x28,%esp
f0105650:	8b 45 08             	mov    0x8(%ebp),%eax
f0105653:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105656:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105659:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f010565d:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105660:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105667:	85 c0                	test   %eax,%eax
f0105669:	74 30                	je     f010569b <vsnprintf+0x51>
f010566b:	85 d2                	test   %edx,%edx
f010566d:	7e 2c                	jle    f010569b <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f010566f:	8b 45 14             	mov    0x14(%ebp),%eax
f0105672:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105676:	8b 45 10             	mov    0x10(%ebp),%eax
f0105679:	89 44 24 08          	mov    %eax,0x8(%esp)
f010567d:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105680:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105684:	c7 04 24 65 51 10 f0 	movl   $0xf0105165,(%esp)
f010568b:	e8 1a fb ff ff       	call   f01051aa <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105690:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105693:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105696:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105699:	eb 05                	jmp    f01056a0 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f010569b:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f01056a0:	c9                   	leave  
f01056a1:	c3                   	ret    

f01056a2 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f01056a2:	55                   	push   %ebp
f01056a3:	89 e5                	mov    %esp,%ebp
f01056a5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f01056a8:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f01056ab:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01056af:	8b 45 10             	mov    0x10(%ebp),%eax
f01056b2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01056b6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01056b9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056bd:	8b 45 08             	mov    0x8(%ebp),%eax
f01056c0:	89 04 24             	mov    %eax,(%esp)
f01056c3:	e8 82 ff ff ff       	call   f010564a <vsnprintf>
	va_end(ap);

	return rc;
}
f01056c8:	c9                   	leave  
f01056c9:	c3                   	ret    
f01056ca:	66 90                	xchg   %ax,%ax
f01056cc:	66 90                	xchg   %ax,%ax
f01056ce:	66 90                	xchg   %ax,%ax

f01056d0 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f01056d0:	55                   	push   %ebp
f01056d1:	89 e5                	mov    %esp,%ebp
f01056d3:	57                   	push   %edi
f01056d4:	56                   	push   %esi
f01056d5:	53                   	push   %ebx
f01056d6:	83 ec 1c             	sub    $0x1c,%esp
f01056d9:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f01056dc:	85 c0                	test   %eax,%eax
f01056de:	74 10                	je     f01056f0 <readline+0x20>
		cprintf("%s", prompt);
f01056e0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01056e4:	c7 04 24 1e 6d 10 f0 	movl   $0xf0106d1e,(%esp)
f01056eb:	e8 3f ea ff ff       	call   f010412f <cprintf>

	i = 0;
	echoing = iscons(0);
f01056f0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01056f7:	e8 02 b1 ff ff       	call   f01007fe <iscons>
f01056fc:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f01056fe:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105703:	e8 e5 b0 ff ff       	call   f01007ed <getchar>
f0105708:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f010570a:	85 c0                	test   %eax,%eax
f010570c:	79 17                	jns    f0105725 <readline+0x55>
			cprintf("read error: %e\n", c);
f010570e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105712:	c7 04 24 a4 7f 10 f0 	movl   $0xf0107fa4,(%esp)
f0105719:	e8 11 ea ff ff       	call   f010412f <cprintf>
			return NULL;
f010571e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105723:	eb 6d                	jmp    f0105792 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105725:	83 f8 7f             	cmp    $0x7f,%eax
f0105728:	74 05                	je     f010572f <readline+0x5f>
f010572a:	83 f8 08             	cmp    $0x8,%eax
f010572d:	75 19                	jne    f0105748 <readline+0x78>
f010572f:	85 f6                	test   %esi,%esi
f0105731:	7e 15                	jle    f0105748 <readline+0x78>
			if (echoing)
f0105733:	85 ff                	test   %edi,%edi
f0105735:	74 0c                	je     f0105743 <readline+0x73>
				cputchar('\b');
f0105737:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f010573e:	e8 9a b0 ff ff       	call   f01007dd <cputchar>
			i--;
f0105743:	83 ee 01             	sub    $0x1,%esi
f0105746:	eb bb                	jmp    f0105703 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105748:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f010574e:	7f 1c                	jg     f010576c <readline+0x9c>
f0105750:	83 fb 1f             	cmp    $0x1f,%ebx
f0105753:	7e 17                	jle    f010576c <readline+0x9c>
			if (echoing)
f0105755:	85 ff                	test   %edi,%edi
f0105757:	74 08                	je     f0105761 <readline+0x91>
				cputchar(c);
f0105759:	89 1c 24             	mov    %ebx,(%esp)
f010575c:	e8 7c b0 ff ff       	call   f01007dd <cputchar>
			buf[i++] = c;
f0105761:	88 9e 80 3a 22 f0    	mov    %bl,-0xfddc580(%esi)
f0105767:	8d 76 01             	lea    0x1(%esi),%esi
f010576a:	eb 97                	jmp    f0105703 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f010576c:	83 fb 0d             	cmp    $0xd,%ebx
f010576f:	74 05                	je     f0105776 <readline+0xa6>
f0105771:	83 fb 0a             	cmp    $0xa,%ebx
f0105774:	75 8d                	jne    f0105703 <readline+0x33>
			if (echoing)
f0105776:	85 ff                	test   %edi,%edi
f0105778:	74 0c                	je     f0105786 <readline+0xb6>
				cputchar('\n');
f010577a:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105781:	e8 57 b0 ff ff       	call   f01007dd <cputchar>
			buf[i] = 0;
f0105786:	c6 86 80 3a 22 f0 00 	movb   $0x0,-0xfddc580(%esi)
			return buf;
f010578d:	b8 80 3a 22 f0       	mov    $0xf0223a80,%eax
		}
	}
}
f0105792:	83 c4 1c             	add    $0x1c,%esp
f0105795:	5b                   	pop    %ebx
f0105796:	5e                   	pop    %esi
f0105797:	5f                   	pop    %edi
f0105798:	5d                   	pop    %ebp
f0105799:	c3                   	ret    
f010579a:	66 90                	xchg   %ax,%ax
f010579c:	66 90                	xchg   %ax,%ax
f010579e:	66 90                	xchg   %ax,%ax

f01057a0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f01057a0:	55                   	push   %ebp
f01057a1:	89 e5                	mov    %esp,%ebp
f01057a3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f01057a6:	80 3a 00             	cmpb   $0x0,(%edx)
f01057a9:	74 10                	je     f01057bb <strlen+0x1b>
f01057ab:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f01057b0:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f01057b3:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f01057b7:	75 f7                	jne    f01057b0 <strlen+0x10>
f01057b9:	eb 05                	jmp    f01057c0 <strlen+0x20>
f01057bb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01057c0:	5d                   	pop    %ebp
f01057c1:	c3                   	ret    

f01057c2 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f01057c2:	55                   	push   %ebp
f01057c3:	89 e5                	mov    %esp,%ebp
f01057c5:	53                   	push   %ebx
f01057c6:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01057c9:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01057cc:	85 c9                	test   %ecx,%ecx
f01057ce:	74 1c                	je     f01057ec <strnlen+0x2a>
f01057d0:	80 3b 00             	cmpb   $0x0,(%ebx)
f01057d3:	74 1e                	je     f01057f3 <strnlen+0x31>
f01057d5:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f01057da:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f01057dc:	39 ca                	cmp    %ecx,%edx
f01057de:	74 18                	je     f01057f8 <strnlen+0x36>
f01057e0:	83 c2 01             	add    $0x1,%edx
f01057e3:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f01057e8:	75 f0                	jne    f01057da <strnlen+0x18>
f01057ea:	eb 0c                	jmp    f01057f8 <strnlen+0x36>
f01057ec:	b8 00 00 00 00       	mov    $0x0,%eax
f01057f1:	eb 05                	jmp    f01057f8 <strnlen+0x36>
f01057f3:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f01057f8:	5b                   	pop    %ebx
f01057f9:	5d                   	pop    %ebp
f01057fa:	c3                   	ret    

f01057fb <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f01057fb:	55                   	push   %ebp
f01057fc:	89 e5                	mov    %esp,%ebp
f01057fe:	53                   	push   %ebx
f01057ff:	8b 45 08             	mov    0x8(%ebp),%eax
f0105802:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105805:	89 c2                	mov    %eax,%edx
f0105807:	83 c2 01             	add    $0x1,%edx
f010580a:	83 c1 01             	add    $0x1,%ecx
f010580d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105811:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105814:	84 db                	test   %bl,%bl
f0105816:	75 ef                	jne    f0105807 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105818:	5b                   	pop    %ebx
f0105819:	5d                   	pop    %ebp
f010581a:	c3                   	ret    

f010581b <strcat>:

char *
strcat(char *dst, const char *src)
{
f010581b:	55                   	push   %ebp
f010581c:	89 e5                	mov    %esp,%ebp
f010581e:	53                   	push   %ebx
f010581f:	83 ec 08             	sub    $0x8,%esp
f0105822:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105825:	89 1c 24             	mov    %ebx,(%esp)
f0105828:	e8 73 ff ff ff       	call   f01057a0 <strlen>
	strcpy(dst + len, src);
f010582d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105830:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105834:	01 d8                	add    %ebx,%eax
f0105836:	89 04 24             	mov    %eax,(%esp)
f0105839:	e8 bd ff ff ff       	call   f01057fb <strcpy>
	return dst;
}
f010583e:	89 d8                	mov    %ebx,%eax
f0105840:	83 c4 08             	add    $0x8,%esp
f0105843:	5b                   	pop    %ebx
f0105844:	5d                   	pop    %ebp
f0105845:	c3                   	ret    

f0105846 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105846:	55                   	push   %ebp
f0105847:	89 e5                	mov    %esp,%ebp
f0105849:	56                   	push   %esi
f010584a:	53                   	push   %ebx
f010584b:	8b 75 08             	mov    0x8(%ebp),%esi
f010584e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105851:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105854:	85 db                	test   %ebx,%ebx
f0105856:	74 17                	je     f010586f <strncpy+0x29>
f0105858:	01 f3                	add    %esi,%ebx
f010585a:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f010585c:	83 c1 01             	add    $0x1,%ecx
f010585f:	0f b6 02             	movzbl (%edx),%eax
f0105862:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105865:	80 3a 01             	cmpb   $0x1,(%edx)
f0105868:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f010586b:	39 d9                	cmp    %ebx,%ecx
f010586d:	75 ed                	jne    f010585c <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f010586f:	89 f0                	mov    %esi,%eax
f0105871:	5b                   	pop    %ebx
f0105872:	5e                   	pop    %esi
f0105873:	5d                   	pop    %ebp
f0105874:	c3                   	ret    

f0105875 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105875:	55                   	push   %ebp
f0105876:	89 e5                	mov    %esp,%ebp
f0105878:	57                   	push   %edi
f0105879:	56                   	push   %esi
f010587a:	53                   	push   %ebx
f010587b:	8b 7d 08             	mov    0x8(%ebp),%edi
f010587e:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105881:	8b 75 10             	mov    0x10(%ebp),%esi
f0105884:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105886:	85 f6                	test   %esi,%esi
f0105888:	74 34                	je     f01058be <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f010588a:	83 fe 01             	cmp    $0x1,%esi
f010588d:	74 26                	je     f01058b5 <strlcpy+0x40>
f010588f:	0f b6 0b             	movzbl (%ebx),%ecx
f0105892:	84 c9                	test   %cl,%cl
f0105894:	74 23                	je     f01058b9 <strlcpy+0x44>
f0105896:	83 ee 02             	sub    $0x2,%esi
f0105899:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f010589e:	83 c0 01             	add    $0x1,%eax
f01058a1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f01058a4:	39 f2                	cmp    %esi,%edx
f01058a6:	74 13                	je     f01058bb <strlcpy+0x46>
f01058a8:	83 c2 01             	add    $0x1,%edx
f01058ab:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f01058af:	84 c9                	test   %cl,%cl
f01058b1:	75 eb                	jne    f010589e <strlcpy+0x29>
f01058b3:	eb 06                	jmp    f01058bb <strlcpy+0x46>
f01058b5:	89 f8                	mov    %edi,%eax
f01058b7:	eb 02                	jmp    f01058bb <strlcpy+0x46>
f01058b9:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f01058bb:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f01058be:	29 f8                	sub    %edi,%eax
}
f01058c0:	5b                   	pop    %ebx
f01058c1:	5e                   	pop    %esi
f01058c2:	5f                   	pop    %edi
f01058c3:	5d                   	pop    %ebp
f01058c4:	c3                   	ret    

f01058c5 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f01058c5:	55                   	push   %ebp
f01058c6:	89 e5                	mov    %esp,%ebp
f01058c8:	8b 4d 08             	mov    0x8(%ebp),%ecx
f01058cb:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f01058ce:	0f b6 01             	movzbl (%ecx),%eax
f01058d1:	84 c0                	test   %al,%al
f01058d3:	74 15                	je     f01058ea <strcmp+0x25>
f01058d5:	3a 02                	cmp    (%edx),%al
f01058d7:	75 11                	jne    f01058ea <strcmp+0x25>
		p++, q++;
f01058d9:	83 c1 01             	add    $0x1,%ecx
f01058dc:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f01058df:	0f b6 01             	movzbl (%ecx),%eax
f01058e2:	84 c0                	test   %al,%al
f01058e4:	74 04                	je     f01058ea <strcmp+0x25>
f01058e6:	3a 02                	cmp    (%edx),%al
f01058e8:	74 ef                	je     f01058d9 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f01058ea:	0f b6 c0             	movzbl %al,%eax
f01058ed:	0f b6 12             	movzbl (%edx),%edx
f01058f0:	29 d0                	sub    %edx,%eax
}
f01058f2:	5d                   	pop    %ebp
f01058f3:	c3                   	ret    

f01058f4 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f01058f4:	55                   	push   %ebp
f01058f5:	89 e5                	mov    %esp,%ebp
f01058f7:	56                   	push   %esi
f01058f8:	53                   	push   %ebx
f01058f9:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01058fc:	8b 55 0c             	mov    0xc(%ebp),%edx
f01058ff:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105902:	85 f6                	test   %esi,%esi
f0105904:	74 29                	je     f010592f <strncmp+0x3b>
f0105906:	0f b6 03             	movzbl (%ebx),%eax
f0105909:	84 c0                	test   %al,%al
f010590b:	74 30                	je     f010593d <strncmp+0x49>
f010590d:	3a 02                	cmp    (%edx),%al
f010590f:	75 2c                	jne    f010593d <strncmp+0x49>
f0105911:	8d 43 01             	lea    0x1(%ebx),%eax
f0105914:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105916:	89 c3                	mov    %eax,%ebx
f0105918:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f010591b:	39 f0                	cmp    %esi,%eax
f010591d:	74 17                	je     f0105936 <strncmp+0x42>
f010591f:	0f b6 08             	movzbl (%eax),%ecx
f0105922:	84 c9                	test   %cl,%cl
f0105924:	74 17                	je     f010593d <strncmp+0x49>
f0105926:	83 c0 01             	add    $0x1,%eax
f0105929:	3a 0a                	cmp    (%edx),%cl
f010592b:	74 e9                	je     f0105916 <strncmp+0x22>
f010592d:	eb 0e                	jmp    f010593d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f010592f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105934:	eb 0f                	jmp    f0105945 <strncmp+0x51>
f0105936:	b8 00 00 00 00       	mov    $0x0,%eax
f010593b:	eb 08                	jmp    f0105945 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f010593d:	0f b6 03             	movzbl (%ebx),%eax
f0105940:	0f b6 12             	movzbl (%edx),%edx
f0105943:	29 d0                	sub    %edx,%eax
}
f0105945:	5b                   	pop    %ebx
f0105946:	5e                   	pop    %esi
f0105947:	5d                   	pop    %ebp
f0105948:	c3                   	ret    

f0105949 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105949:	55                   	push   %ebp
f010594a:	89 e5                	mov    %esp,%ebp
f010594c:	53                   	push   %ebx
f010594d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105950:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105953:	0f b6 18             	movzbl (%eax),%ebx
f0105956:	84 db                	test   %bl,%bl
f0105958:	74 1d                	je     f0105977 <strchr+0x2e>
f010595a:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f010595c:	38 d3                	cmp    %dl,%bl
f010595e:	75 06                	jne    f0105966 <strchr+0x1d>
f0105960:	eb 1a                	jmp    f010597c <strchr+0x33>
f0105962:	38 ca                	cmp    %cl,%dl
f0105964:	74 16                	je     f010597c <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105966:	83 c0 01             	add    $0x1,%eax
f0105969:	0f b6 10             	movzbl (%eax),%edx
f010596c:	84 d2                	test   %dl,%dl
f010596e:	75 f2                	jne    f0105962 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105970:	b8 00 00 00 00       	mov    $0x0,%eax
f0105975:	eb 05                	jmp    f010597c <strchr+0x33>
f0105977:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010597c:	5b                   	pop    %ebx
f010597d:	5d                   	pop    %ebp
f010597e:	c3                   	ret    

f010597f <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f010597f:	55                   	push   %ebp
f0105980:	89 e5                	mov    %esp,%ebp
f0105982:	53                   	push   %ebx
f0105983:	8b 45 08             	mov    0x8(%ebp),%eax
f0105986:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105989:	0f b6 18             	movzbl (%eax),%ebx
f010598c:	84 db                	test   %bl,%bl
f010598e:	74 16                	je     f01059a6 <strfind+0x27>
f0105990:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105992:	38 d3                	cmp    %dl,%bl
f0105994:	75 06                	jne    f010599c <strfind+0x1d>
f0105996:	eb 0e                	jmp    f01059a6 <strfind+0x27>
f0105998:	38 ca                	cmp    %cl,%dl
f010599a:	74 0a                	je     f01059a6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f010599c:	83 c0 01             	add    $0x1,%eax
f010599f:	0f b6 10             	movzbl (%eax),%edx
f01059a2:	84 d2                	test   %dl,%dl
f01059a4:	75 f2                	jne    f0105998 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f01059a6:	5b                   	pop    %ebx
f01059a7:	5d                   	pop    %ebp
f01059a8:	c3                   	ret    

f01059a9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f01059a9:	55                   	push   %ebp
f01059aa:	89 e5                	mov    %esp,%ebp
f01059ac:	57                   	push   %edi
f01059ad:	56                   	push   %esi
f01059ae:	53                   	push   %ebx
f01059af:	8b 7d 08             	mov    0x8(%ebp),%edi
f01059b2:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f01059b5:	85 c9                	test   %ecx,%ecx
f01059b7:	74 36                	je     f01059ef <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f01059b9:	f7 c7 03 00 00 00    	test   $0x3,%edi
f01059bf:	75 28                	jne    f01059e9 <memset+0x40>
f01059c1:	f6 c1 03             	test   $0x3,%cl
f01059c4:	75 23                	jne    f01059e9 <memset+0x40>
		c &= 0xFF;
f01059c6:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f01059ca:	89 d3                	mov    %edx,%ebx
f01059cc:	c1 e3 08             	shl    $0x8,%ebx
f01059cf:	89 d6                	mov    %edx,%esi
f01059d1:	c1 e6 18             	shl    $0x18,%esi
f01059d4:	89 d0                	mov    %edx,%eax
f01059d6:	c1 e0 10             	shl    $0x10,%eax
f01059d9:	09 f0                	or     %esi,%eax
f01059db:	09 c2                	or     %eax,%edx
f01059dd:	89 d0                	mov    %edx,%eax
f01059df:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f01059e1:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f01059e4:	fc                   	cld    
f01059e5:	f3 ab                	rep stos %eax,%es:(%edi)
f01059e7:	eb 06                	jmp    f01059ef <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f01059e9:	8b 45 0c             	mov    0xc(%ebp),%eax
f01059ec:	fc                   	cld    
f01059ed:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f01059ef:	89 f8                	mov    %edi,%eax
f01059f1:	5b                   	pop    %ebx
f01059f2:	5e                   	pop    %esi
f01059f3:	5f                   	pop    %edi
f01059f4:	5d                   	pop    %ebp
f01059f5:	c3                   	ret    

f01059f6 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f01059f6:	55                   	push   %ebp
f01059f7:	89 e5                	mov    %esp,%ebp
f01059f9:	57                   	push   %edi
f01059fa:	56                   	push   %esi
f01059fb:	8b 45 08             	mov    0x8(%ebp),%eax
f01059fe:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105a01:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105a04:	39 c6                	cmp    %eax,%esi
f0105a06:	73 35                	jae    f0105a3d <memmove+0x47>
f0105a08:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0105a0b:	39 d0                	cmp    %edx,%eax
f0105a0d:	73 2e                	jae    f0105a3d <memmove+0x47>
		s += n;
		d += n;
f0105a0f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105a12:	89 d6                	mov    %edx,%esi
f0105a14:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105a16:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0105a1c:	75 13                	jne    f0105a31 <memmove+0x3b>
f0105a1e:	f6 c1 03             	test   $0x3,%cl
f0105a21:	75 0e                	jne    f0105a31 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105a23:	83 ef 04             	sub    $0x4,%edi
f0105a26:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105a29:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0105a2c:	fd                   	std    
f0105a2d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105a2f:	eb 09                	jmp    f0105a3a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105a31:	83 ef 01             	sub    $0x1,%edi
f0105a34:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105a37:	fd                   	std    
f0105a38:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0105a3a:	fc                   	cld    
f0105a3b:	eb 1d                	jmp    f0105a5a <memmove+0x64>
f0105a3d:	89 f2                	mov    %esi,%edx
f0105a3f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105a41:	f6 c2 03             	test   $0x3,%dl
f0105a44:	75 0f                	jne    f0105a55 <memmove+0x5f>
f0105a46:	f6 c1 03             	test   $0x3,%cl
f0105a49:	75 0a                	jne    f0105a55 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0105a4b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0105a4e:	89 c7                	mov    %eax,%edi
f0105a50:	fc                   	cld    
f0105a51:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105a53:	eb 05                	jmp    f0105a5a <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105a55:	89 c7                	mov    %eax,%edi
f0105a57:	fc                   	cld    
f0105a58:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105a5a:	5e                   	pop    %esi
f0105a5b:	5f                   	pop    %edi
f0105a5c:	5d                   	pop    %ebp
f0105a5d:	c3                   	ret    

f0105a5e <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105a5e:	55                   	push   %ebp
f0105a5f:	89 e5                	mov    %esp,%ebp
f0105a61:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105a64:	8b 45 10             	mov    0x10(%ebp),%eax
f0105a67:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105a6b:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105a6e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105a72:	8b 45 08             	mov    0x8(%ebp),%eax
f0105a75:	89 04 24             	mov    %eax,(%esp)
f0105a78:	e8 79 ff ff ff       	call   f01059f6 <memmove>
}
f0105a7d:	c9                   	leave  
f0105a7e:	c3                   	ret    

f0105a7f <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105a7f:	55                   	push   %ebp
f0105a80:	89 e5                	mov    %esp,%ebp
f0105a82:	57                   	push   %edi
f0105a83:	56                   	push   %esi
f0105a84:	53                   	push   %ebx
f0105a85:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105a88:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105a8b:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105a8e:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105a91:	85 c0                	test   %eax,%eax
f0105a93:	74 36                	je     f0105acb <memcmp+0x4c>
		if (*s1 != *s2)
f0105a95:	0f b6 03             	movzbl (%ebx),%eax
f0105a98:	0f b6 0e             	movzbl (%esi),%ecx
f0105a9b:	ba 00 00 00 00       	mov    $0x0,%edx
f0105aa0:	38 c8                	cmp    %cl,%al
f0105aa2:	74 1c                	je     f0105ac0 <memcmp+0x41>
f0105aa4:	eb 10                	jmp    f0105ab6 <memcmp+0x37>
f0105aa6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105aab:	83 c2 01             	add    $0x1,%edx
f0105aae:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0105ab2:	38 c8                	cmp    %cl,%al
f0105ab4:	74 0a                	je     f0105ac0 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0105ab6:	0f b6 c0             	movzbl %al,%eax
f0105ab9:	0f b6 c9             	movzbl %cl,%ecx
f0105abc:	29 c8                	sub    %ecx,%eax
f0105abe:	eb 10                	jmp    f0105ad0 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105ac0:	39 fa                	cmp    %edi,%edx
f0105ac2:	75 e2                	jne    f0105aa6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0105ac4:	b8 00 00 00 00       	mov    $0x0,%eax
f0105ac9:	eb 05                	jmp    f0105ad0 <memcmp+0x51>
f0105acb:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105ad0:	5b                   	pop    %ebx
f0105ad1:	5e                   	pop    %esi
f0105ad2:	5f                   	pop    %edi
f0105ad3:	5d                   	pop    %ebp
f0105ad4:	c3                   	ret    

f0105ad5 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0105ad5:	55                   	push   %ebp
f0105ad6:	89 e5                	mov    %esp,%ebp
f0105ad8:	53                   	push   %ebx
f0105ad9:	8b 45 08             	mov    0x8(%ebp),%eax
f0105adc:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0105adf:	89 c2                	mov    %eax,%edx
f0105ae1:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105ae4:	39 d0                	cmp    %edx,%eax
f0105ae6:	73 13                	jae    f0105afb <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105ae8:	89 d9                	mov    %ebx,%ecx
f0105aea:	38 18                	cmp    %bl,(%eax)
f0105aec:	75 06                	jne    f0105af4 <memfind+0x1f>
f0105aee:	eb 0b                	jmp    f0105afb <memfind+0x26>
f0105af0:	38 08                	cmp    %cl,(%eax)
f0105af2:	74 07                	je     f0105afb <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105af4:	83 c0 01             	add    $0x1,%eax
f0105af7:	39 d0                	cmp    %edx,%eax
f0105af9:	75 f5                	jne    f0105af0 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0105afb:	5b                   	pop    %ebx
f0105afc:	5d                   	pop    %ebp
f0105afd:	c3                   	ret    

f0105afe <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0105afe:	55                   	push   %ebp
f0105aff:	89 e5                	mov    %esp,%ebp
f0105b01:	57                   	push   %edi
f0105b02:	56                   	push   %esi
f0105b03:	53                   	push   %ebx
f0105b04:	8b 55 08             	mov    0x8(%ebp),%edx
f0105b07:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105b0a:	0f b6 0a             	movzbl (%edx),%ecx
f0105b0d:	80 f9 09             	cmp    $0x9,%cl
f0105b10:	74 05                	je     f0105b17 <strtol+0x19>
f0105b12:	80 f9 20             	cmp    $0x20,%cl
f0105b15:	75 10                	jne    f0105b27 <strtol+0x29>
		s++;
f0105b17:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105b1a:	0f b6 0a             	movzbl (%edx),%ecx
f0105b1d:	80 f9 09             	cmp    $0x9,%cl
f0105b20:	74 f5                	je     f0105b17 <strtol+0x19>
f0105b22:	80 f9 20             	cmp    $0x20,%cl
f0105b25:	74 f0                	je     f0105b17 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105b27:	80 f9 2b             	cmp    $0x2b,%cl
f0105b2a:	75 0a                	jne    f0105b36 <strtol+0x38>
		s++;
f0105b2c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0105b2f:	bf 00 00 00 00       	mov    $0x0,%edi
f0105b34:	eb 11                	jmp    f0105b47 <strtol+0x49>
f0105b36:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0105b3b:	80 f9 2d             	cmp    $0x2d,%cl
f0105b3e:	75 07                	jne    f0105b47 <strtol+0x49>
		s++, neg = 1;
f0105b40:	83 c2 01             	add    $0x1,%edx
f0105b43:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105b47:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0105b4c:	75 15                	jne    f0105b63 <strtol+0x65>
f0105b4e:	80 3a 30             	cmpb   $0x30,(%edx)
f0105b51:	75 10                	jne    f0105b63 <strtol+0x65>
f0105b53:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105b57:	75 0a                	jne    f0105b63 <strtol+0x65>
		s += 2, base = 16;
f0105b59:	83 c2 02             	add    $0x2,%edx
f0105b5c:	b8 10 00 00 00       	mov    $0x10,%eax
f0105b61:	eb 10                	jmp    f0105b73 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105b63:	85 c0                	test   %eax,%eax
f0105b65:	75 0c                	jne    f0105b73 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105b67:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105b69:	80 3a 30             	cmpb   $0x30,(%edx)
f0105b6c:	75 05                	jne    f0105b73 <strtol+0x75>
		s++, base = 8;
f0105b6e:	83 c2 01             	add    $0x1,%edx
f0105b71:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105b73:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105b78:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0105b7b:	0f b6 0a             	movzbl (%edx),%ecx
f0105b7e:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0105b81:	89 f0                	mov    %esi,%eax
f0105b83:	3c 09                	cmp    $0x9,%al
f0105b85:	77 08                	ja     f0105b8f <strtol+0x91>
			dig = *s - '0';
f0105b87:	0f be c9             	movsbl %cl,%ecx
f0105b8a:	83 e9 30             	sub    $0x30,%ecx
f0105b8d:	eb 20                	jmp    f0105baf <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0105b8f:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0105b92:	89 f0                	mov    %esi,%eax
f0105b94:	3c 19                	cmp    $0x19,%al
f0105b96:	77 08                	ja     f0105ba0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0105b98:	0f be c9             	movsbl %cl,%ecx
f0105b9b:	83 e9 57             	sub    $0x57,%ecx
f0105b9e:	eb 0f                	jmp    f0105baf <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0105ba0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0105ba3:	89 f0                	mov    %esi,%eax
f0105ba5:	3c 19                	cmp    $0x19,%al
f0105ba7:	77 16                	ja     f0105bbf <strtol+0xc1>
			dig = *s - 'A' + 10;
f0105ba9:	0f be c9             	movsbl %cl,%ecx
f0105bac:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0105baf:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0105bb2:	7d 0f                	jge    f0105bc3 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0105bb4:	83 c2 01             	add    $0x1,%edx
f0105bb7:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f0105bbb:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f0105bbd:	eb bc                	jmp    f0105b7b <strtol+0x7d>
f0105bbf:	89 d8                	mov    %ebx,%eax
f0105bc1:	eb 02                	jmp    f0105bc5 <strtol+0xc7>
f0105bc3:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0105bc5:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0105bc9:	74 05                	je     f0105bd0 <strtol+0xd2>
		*endptr = (char *) s;
f0105bcb:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105bce:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0105bd0:	f7 d8                	neg    %eax
f0105bd2:	85 ff                	test   %edi,%edi
f0105bd4:	0f 44 c3             	cmove  %ebx,%eax
}
f0105bd7:	5b                   	pop    %ebx
f0105bd8:	5e                   	pop    %esi
f0105bd9:	5f                   	pop    %edi
f0105bda:	5d                   	pop    %ebp
f0105bdb:	c3                   	ret    

f0105bdc <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f0105bdc:	fa                   	cli    

	xorw    %ax, %ax
f0105bdd:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f0105bdf:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105be1:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105be3:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0105be5:	0f 01 16             	lgdtl  (%esi)
f0105be8:	74 70                	je     f0105c5a <mpentry_end+0x4>
	movl    %cr0, %eax
f0105bea:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f0105bed:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0105bf1:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0105bf4:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f0105bfa:	08 00                	or     %al,(%eax)

f0105bfc <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f0105bfc:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0105c00:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0105c02:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0105c04:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0105c06:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f0105c0a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f0105c0c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f0105c0e:	b8 00 e0 11 00       	mov    $0x11e000,%eax
	movl    %eax, %cr3
f0105c13:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0105c16:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0105c19:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f0105c1e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0105c21:	8b 25 84 3e 22 f0    	mov    0xf0223e84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0105c27:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f0105c2c:	b8 29 02 10 f0       	mov    $0xf0100229,%eax
	call    *%eax
f0105c31:	ff d0                	call   *%eax

f0105c33 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0105c33:	eb fe                	jmp    f0105c33 <spin>
f0105c35:	8d 76 00             	lea    0x0(%esi),%esi

f0105c38 <gdt>:
	...
f0105c40:	ff                   	(bad)  
f0105c41:	ff 00                	incl   (%eax)
f0105c43:	00 00                	add    %al,(%eax)
f0105c45:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f0105c4c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f0105c50 <gdtdesc>:
f0105c50:	17                   	pop    %ss
f0105c51:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f0105c56 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f0105c56:	90                   	nop
f0105c57:	66 90                	xchg   %ax,%ax
f0105c59:	66 90                	xchg   %ax,%ax
f0105c5b:	66 90                	xchg   %ax,%ax
f0105c5d:	66 90                	xchg   %ax,%ax
f0105c5f:	90                   	nop

f0105c60 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f0105c60:	55                   	push   %ebp
f0105c61:	89 e5                	mov    %esp,%ebp
f0105c63:	56                   	push   %esi
f0105c64:	53                   	push   %ebx
f0105c65:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105c68:	8b 0d 88 3e 22 f0    	mov    0xf0223e88,%ecx
f0105c6e:	89 c3                	mov    %eax,%ebx
f0105c70:	c1 eb 0c             	shr    $0xc,%ebx
f0105c73:	39 cb                	cmp    %ecx,%ebx
f0105c75:	72 20                	jb     f0105c97 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105c77:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105c7b:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0105c82:	f0 
f0105c83:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105c8a:	00 
f0105c8b:	c7 04 24 41 81 10 f0 	movl   $0xf0108141,(%esp)
f0105c92:	e8 a9 a3 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105c97:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f0105c9d:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105c9f:	89 c2                	mov    %eax,%edx
f0105ca1:	c1 ea 0c             	shr    $0xc,%edx
f0105ca4:	39 d1                	cmp    %edx,%ecx
f0105ca6:	77 20                	ja     f0105cc8 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105ca8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105cac:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0105cb3:	f0 
f0105cb4:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f0105cbb:	00 
f0105cbc:	c7 04 24 41 81 10 f0 	movl   $0xf0108141,(%esp)
f0105cc3:	e8 78 a3 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105cc8:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f0105cce:	39 f3                	cmp    %esi,%ebx
f0105cd0:	73 40                	jae    f0105d12 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105cd2:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105cd9:	00 
f0105cda:	c7 44 24 04 51 81 10 	movl   $0xf0108151,0x4(%esp)
f0105ce1:	f0 
f0105ce2:	89 1c 24             	mov    %ebx,(%esp)
f0105ce5:	e8 95 fd ff ff       	call   f0105a7f <memcmp>
f0105cea:	85 c0                	test   %eax,%eax
f0105cec:	75 17                	jne    f0105d05 <mpsearch1+0xa5>
f0105cee:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0105cf3:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0105cf7:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105cf9:	83 c0 01             	add    $0x1,%eax
f0105cfc:	83 f8 10             	cmp    $0x10,%eax
f0105cff:	75 f2                	jne    f0105cf3 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0105d01:	84 d2                	test   %dl,%dl
f0105d03:	74 14                	je     f0105d19 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0105d05:	83 c3 10             	add    $0x10,%ebx
f0105d08:	39 f3                	cmp    %esi,%ebx
f0105d0a:	72 c6                	jb     f0105cd2 <mpsearch1+0x72>
f0105d0c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0105d10:	eb 0b                	jmp    f0105d1d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0105d12:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d17:	eb 09                	jmp    f0105d22 <mpsearch1+0xc2>
f0105d19:	89 d8                	mov    %ebx,%eax
f0105d1b:	eb 05                	jmp    f0105d22 <mpsearch1+0xc2>
f0105d1d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105d22:	83 c4 10             	add    $0x10,%esp
f0105d25:	5b                   	pop    %ebx
f0105d26:	5e                   	pop    %esi
f0105d27:	5d                   	pop    %ebp
f0105d28:	c3                   	ret    

f0105d29 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0105d29:	55                   	push   %ebp
f0105d2a:	89 e5                	mov    %esp,%ebp
f0105d2c:	57                   	push   %edi
f0105d2d:	56                   	push   %esi
f0105d2e:	53                   	push   %ebx
f0105d2f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0105d32:	c7 05 c0 43 22 f0 20 	movl   $0xf0224020,0xf02243c0
f0105d39:	40 22 f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105d3c:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f0105d43:	75 24                	jne    f0105d69 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105d45:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f0105d4c:	00 
f0105d4d:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0105d54:	f0 
f0105d55:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f0105d5c:	00 
f0105d5d:	c7 04 24 41 81 10 f0 	movl   $0xf0108141,(%esp)
f0105d64:	e8 d7 a2 ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f0105d69:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f0105d70:	85 c0                	test   %eax,%eax
f0105d72:	74 16                	je     f0105d8a <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f0105d74:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f0105d77:	ba 00 04 00 00       	mov    $0x400,%edx
f0105d7c:	e8 df fe ff ff       	call   f0105c60 <mpsearch1>
f0105d81:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105d84:	85 c0                	test   %eax,%eax
f0105d86:	75 3c                	jne    f0105dc4 <mp_init+0x9b>
f0105d88:	eb 20                	jmp    f0105daa <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f0105d8a:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f0105d91:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f0105d94:	2d 00 04 00 00       	sub    $0x400,%eax
f0105d99:	ba 00 04 00 00       	mov    $0x400,%edx
f0105d9e:	e8 bd fe ff ff       	call   f0105c60 <mpsearch1>
f0105da3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105da6:	85 c0                	test   %eax,%eax
f0105da8:	75 1a                	jne    f0105dc4 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f0105daa:	ba 00 00 01 00       	mov    $0x10000,%edx
f0105daf:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0105db4:	e8 a7 fe ff ff       	call   f0105c60 <mpsearch1>
f0105db9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f0105dbc:	85 c0                	test   %eax,%eax
f0105dbe:	0f 84 5f 02 00 00    	je     f0106023 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0105dc4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105dc7:	8b 70 04             	mov    0x4(%eax),%esi
f0105dca:	85 f6                	test   %esi,%esi
f0105dcc:	74 06                	je     f0105dd4 <mp_init+0xab>
f0105dce:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0105dd2:	74 11                	je     f0105de5 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0105dd4:	c7 04 24 b4 7f 10 f0 	movl   $0xf0107fb4,(%esp)
f0105ddb:	e8 4f e3 ff ff       	call   f010412f <cprintf>
f0105de0:	e9 3e 02 00 00       	jmp    f0106023 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0105de5:	89 f0                	mov    %esi,%eax
f0105de7:	c1 e8 0c             	shr    $0xc,%eax
f0105dea:	3b 05 88 3e 22 f0    	cmp    0xf0223e88,%eax
f0105df0:	72 20                	jb     f0105e12 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0105df2:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105df6:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f0105dfd:	f0 
f0105dfe:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0105e05:	00 
f0105e06:	c7 04 24 41 81 10 f0 	movl   $0xf0108141,(%esp)
f0105e0d:	e8 2e a2 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0105e12:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0105e18:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0105e1f:	00 
f0105e20:	c7 44 24 04 56 81 10 	movl   $0xf0108156,0x4(%esp)
f0105e27:	f0 
f0105e28:	89 1c 24             	mov    %ebx,(%esp)
f0105e2b:	e8 4f fc ff ff       	call   f0105a7f <memcmp>
f0105e30:	85 c0                	test   %eax,%eax
f0105e32:	74 11                	je     f0105e45 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0105e34:	c7 04 24 e4 7f 10 f0 	movl   $0xf0107fe4,(%esp)
f0105e3b:	e8 ef e2 ff ff       	call   f010412f <cprintf>
f0105e40:	e9 de 01 00 00       	jmp    f0106023 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105e45:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0105e49:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f0105e4d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e50:	85 ff                	test   %edi,%edi
f0105e52:	7e 30                	jle    f0105e84 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105e54:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105e59:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105e5e:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f0105e65:	f0 
f0105e66:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105e68:	83 c0 01             	add    $0x1,%eax
f0105e6b:	39 c7                	cmp    %eax,%edi
f0105e6d:	7f ef                	jg     f0105e5e <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0105e6f:	84 d2                	test   %dl,%dl
f0105e71:	74 11                	je     f0105e84 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f0105e73:	c7 04 24 18 80 10 f0 	movl   $0xf0108018,(%esp)
f0105e7a:	e8 b0 e2 ff ff       	call   f010412f <cprintf>
f0105e7f:	e9 9f 01 00 00       	jmp    f0106023 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f0105e84:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f0105e88:	3c 04                	cmp    $0x4,%al
f0105e8a:	74 1e                	je     f0105eaa <mp_init+0x181>
f0105e8c:	3c 01                	cmp    $0x1,%al
f0105e8e:	66 90                	xchg   %ax,%ax
f0105e90:	74 18                	je     f0105eaa <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f0105e92:	0f b6 c0             	movzbl %al,%eax
f0105e95:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105e99:	c7 04 24 3c 80 10 f0 	movl   $0xf010803c,(%esp)
f0105ea0:	e8 8a e2 ff ff       	call   f010412f <cprintf>
f0105ea5:	e9 79 01 00 00       	jmp    f0106023 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105eaa:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f0105eae:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0105eb2:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105eb4:	85 f6                	test   %esi,%esi
f0105eb6:	7e 19                	jle    f0105ed1 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105eb8:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f0105ebd:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0105ec2:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0105ec6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0105ec8:	83 c0 01             	add    $0x1,%eax
f0105ecb:	39 c6                	cmp    %eax,%esi
f0105ecd:	7f f3                	jg     f0105ec2 <mp_init+0x199>
f0105ecf:	eb 05                	jmp    f0105ed6 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0105ed1:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0105ed6:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0105ed9:	74 11                	je     f0105eec <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f0105edb:	c7 04 24 5c 80 10 f0 	movl   $0xf010805c,(%esp)
f0105ee2:	e8 48 e2 ff ff       	call   f010412f <cprintf>
f0105ee7:	e9 37 01 00 00       	jmp    f0106023 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f0105eec:	85 db                	test   %ebx,%ebx
f0105eee:	0f 84 2f 01 00 00    	je     f0106023 <mp_init+0x2fa>
		return;
	ismp = 1;
f0105ef4:	c7 05 00 40 22 f0 01 	movl   $0x1,0xf0224000
f0105efb:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f0105efe:	8b 43 24             	mov    0x24(%ebx),%eax
f0105f01:	a3 00 50 26 f0       	mov    %eax,0xf0265000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105f06:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0105f09:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f0105f0e:	0f 84 94 00 00 00    	je     f0105fa8 <mp_init+0x27f>
f0105f14:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0105f19:	0f b6 07             	movzbl (%edi),%eax
f0105f1c:	84 c0                	test   %al,%al
f0105f1e:	74 06                	je     f0105f26 <mp_init+0x1fd>
f0105f20:	3c 04                	cmp    $0x4,%al
f0105f22:	77 54                	ja     f0105f78 <mp_init+0x24f>
f0105f24:	eb 4d                	jmp    f0105f73 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0105f26:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f0105f2a:	74 11                	je     f0105f3d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f0105f2c:	6b 05 c4 43 22 f0 74 	imul   $0x74,0xf02243c4,%eax
f0105f33:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0105f38:	a3 c0 43 22 f0       	mov    %eax,0xf02243c0
			if (ncpu < NCPU) {
f0105f3d:	a1 c4 43 22 f0       	mov    0xf02243c4,%eax
f0105f42:	83 f8 07             	cmp    $0x7,%eax
f0105f45:	7f 13                	jg     f0105f5a <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0105f47:	6b d0 74             	imul   $0x74,%eax,%edx
f0105f4a:	88 82 20 40 22 f0    	mov    %al,-0xfddbfe0(%edx)
				ncpu++;
f0105f50:	83 c0 01             	add    $0x1,%eax
f0105f53:	a3 c4 43 22 f0       	mov    %eax,0xf02243c4
f0105f58:	eb 14                	jmp    f0105f6e <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f0105f5a:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f0105f5e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105f62:	c7 04 24 8c 80 10 f0 	movl   $0xf010808c,(%esp)
f0105f69:	e8 c1 e1 ff ff       	call   f010412f <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f0105f6e:	83 c7 14             	add    $0x14,%edi
			continue;
f0105f71:	eb 26                	jmp    f0105f99 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f0105f73:	83 c7 08             	add    $0x8,%edi
			continue;
f0105f76:	eb 21                	jmp    f0105f99 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f0105f78:	0f b6 c0             	movzbl %al,%eax
f0105f7b:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105f7f:	c7 04 24 b4 80 10 f0 	movl   $0xf01080b4,(%esp)
f0105f86:	e8 a4 e1 ff ff       	call   f010412f <cprintf>
			ismp = 0;
f0105f8b:	c7 05 00 40 22 f0 00 	movl   $0x0,0xf0224000
f0105f92:	00 00 00 
			i = conf->entry;
f0105f95:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0105f99:	83 c6 01             	add    $0x1,%esi
f0105f9c:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f0105fa0:	39 f0                	cmp    %esi,%eax
f0105fa2:	0f 87 71 ff ff ff    	ja     f0105f19 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f0105fa8:	a1 c0 43 22 f0       	mov    0xf02243c0,%eax
f0105fad:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0105fb4:	83 3d 00 40 22 f0 00 	cmpl   $0x0,0xf0224000
f0105fbb:	75 22                	jne    f0105fdf <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f0105fbd:	c7 05 c4 43 22 f0 01 	movl   $0x1,0xf02243c4
f0105fc4:	00 00 00 
		lapic = NULL;
f0105fc7:	c7 05 00 50 26 f0 00 	movl   $0x0,0xf0265000
f0105fce:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0105fd1:	c7 04 24 d4 80 10 f0 	movl   $0xf01080d4,(%esp)
f0105fd8:	e8 52 e1 ff ff       	call   f010412f <cprintf>
		return;
f0105fdd:	eb 44                	jmp    f0106023 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f0105fdf:	8b 15 c4 43 22 f0    	mov    0xf02243c4,%edx
f0105fe5:	89 54 24 08          	mov    %edx,0x8(%esp)
f0105fe9:	0f b6 00             	movzbl (%eax),%eax
f0105fec:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ff0:	c7 04 24 5b 81 10 f0 	movl   $0xf010815b,(%esp)
f0105ff7:	e8 33 e1 ff ff       	call   f010412f <cprintf>

	if (mp->imcrp) {
f0105ffc:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105fff:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106003:	74 1e                	je     f0106023 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0106005:	c7 04 24 00 81 10 f0 	movl   $0xf0108100,(%esp)
f010600c:	e8 1e e1 ff ff       	call   f010412f <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106011:	ba 22 00 00 00       	mov    $0x22,%edx
f0106016:	b8 70 00 00 00       	mov    $0x70,%eax
f010601b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010601c:	b2 23                	mov    $0x23,%dl
f010601e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f010601f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106022:	ee                   	out    %al,(%dx)
	}
}
f0106023:	83 c4 2c             	add    $0x2c,%esp
f0106026:	5b                   	pop    %ebx
f0106027:	5e                   	pop    %esi
f0106028:	5f                   	pop    %edi
f0106029:	5d                   	pop    %ebp
f010602a:	c3                   	ret    

f010602b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f010602b:	55                   	push   %ebp
f010602c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f010602e:	8b 0d 00 50 26 f0    	mov    0xf0265000,%ecx
f0106034:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0106037:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0106039:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f010603e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0106041:	5d                   	pop    %ebp
f0106042:	c3                   	ret    

f0106043 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0106043:	55                   	push   %ebp
f0106044:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0106046:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f010604b:	85 c0                	test   %eax,%eax
f010604d:	74 08                	je     f0106057 <cpunum+0x14>
		return lapic[ID] >> 24;
f010604f:	8b 40 20             	mov    0x20(%eax),%eax
f0106052:	c1 e8 18             	shr    $0x18,%eax
f0106055:	eb 05                	jmp    f010605c <cpunum+0x19>
	return 0;
f0106057:	b8 00 00 00 00       	mov    $0x0,%eax
}
f010605c:	5d                   	pop    %ebp
f010605d:	c3                   	ret    

f010605e <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f010605e:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f0106065:	0f 84 0b 01 00 00    	je     f0106176 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f010606b:	55                   	push   %ebp
f010606c:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f010606e:	ba 27 01 00 00       	mov    $0x127,%edx
f0106073:	b8 3c 00 00 00       	mov    $0x3c,%eax
f0106078:	e8 ae ff ff ff       	call   f010602b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f010607d:	ba 0b 00 00 00       	mov    $0xb,%edx
f0106082:	b8 f8 00 00 00       	mov    $0xf8,%eax
f0106087:	e8 9f ff ff ff       	call   f010602b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f010608c:	ba 20 00 02 00       	mov    $0x20020,%edx
f0106091:	b8 c8 00 00 00       	mov    $0xc8,%eax
f0106096:	e8 90 ff ff ff       	call   f010602b <lapicw>
	lapicw(TICR, 10000000); 
f010609b:	ba 80 96 98 00       	mov    $0x989680,%edx
f01060a0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f01060a5:	e8 81 ff ff ff       	call   f010602b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f01060aa:	e8 94 ff ff ff       	call   f0106043 <cpunum>
f01060af:	6b c0 74             	imul   $0x74,%eax,%eax
f01060b2:	05 20 40 22 f0       	add    $0xf0224020,%eax
f01060b7:	39 05 c0 43 22 f0    	cmp    %eax,0xf02243c0
f01060bd:	74 0f                	je     f01060ce <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f01060bf:	ba 00 00 01 00       	mov    $0x10000,%edx
f01060c4:	b8 d4 00 00 00       	mov    $0xd4,%eax
f01060c9:	e8 5d ff ff ff       	call   f010602b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f01060ce:	ba 00 00 01 00       	mov    $0x10000,%edx
f01060d3:	b8 d8 00 00 00       	mov    $0xd8,%eax
f01060d8:	e8 4e ff ff ff       	call   f010602b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f01060dd:	a1 00 50 26 f0       	mov    0xf0265000,%eax
f01060e2:	8b 40 30             	mov    0x30(%eax),%eax
f01060e5:	c1 e8 10             	shr    $0x10,%eax
f01060e8:	3c 03                	cmp    $0x3,%al
f01060ea:	76 0f                	jbe    f01060fb <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f01060ec:	ba 00 00 01 00       	mov    $0x10000,%edx
f01060f1:	b8 d0 00 00 00       	mov    $0xd0,%eax
f01060f6:	e8 30 ff ff ff       	call   f010602b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f01060fb:	ba 33 00 00 00       	mov    $0x33,%edx
f0106100:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106105:	e8 21 ff ff ff       	call   f010602b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010610a:	ba 00 00 00 00       	mov    $0x0,%edx
f010610f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106114:	e8 12 ff ff ff       	call   f010602b <lapicw>
	lapicw(ESR, 0);
f0106119:	ba 00 00 00 00       	mov    $0x0,%edx
f010611e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106123:	e8 03 ff ff ff       	call   f010602b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106128:	ba 00 00 00 00       	mov    $0x0,%edx
f010612d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0106132:	e8 f4 fe ff ff       	call   f010602b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0106137:	ba 00 00 00 00       	mov    $0x0,%edx
f010613c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106141:	e8 e5 fe ff ff       	call   f010602b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0106146:	ba 00 85 08 00       	mov    $0x88500,%edx
f010614b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106150:	e8 d6 fe ff ff       	call   f010602b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f0106155:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f010615b:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0106161:	f6 c4 10             	test   $0x10,%ah
f0106164:	75 f5                	jne    f010615b <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f0106166:	ba 00 00 00 00       	mov    $0x0,%edx
f010616b:	b8 20 00 00 00       	mov    $0x20,%eax
f0106170:	e8 b6 fe ff ff       	call   f010602b <lapicw>
}
f0106175:	5d                   	pop    %ebp
f0106176:	f3 c3                	repz ret 

f0106178 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f0106178:	83 3d 00 50 26 f0 00 	cmpl   $0x0,0xf0265000
f010617f:	74 13                	je     f0106194 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f0106181:	55                   	push   %ebp
f0106182:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f0106184:	ba 00 00 00 00       	mov    $0x0,%edx
f0106189:	b8 2c 00 00 00       	mov    $0x2c,%eax
f010618e:	e8 98 fe ff ff       	call   f010602b <lapicw>
}
f0106193:	5d                   	pop    %ebp
f0106194:	f3 c3                	repz ret 

f0106196 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f0106196:	55                   	push   %ebp
f0106197:	89 e5                	mov    %esp,%ebp
f0106199:	56                   	push   %esi
f010619a:	53                   	push   %ebx
f010619b:	83 ec 10             	sub    $0x10,%esp
f010619e:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01061a1:	8b 75 0c             	mov    0xc(%ebp),%esi
f01061a4:	ba 70 00 00 00       	mov    $0x70,%edx
f01061a9:	b8 0f 00 00 00       	mov    $0xf,%eax
f01061ae:	ee                   	out    %al,(%dx)
f01061af:	b2 71                	mov    $0x71,%dl
f01061b1:	b8 0a 00 00 00       	mov    $0xa,%eax
f01061b6:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01061b7:	83 3d 88 3e 22 f0 00 	cmpl   $0x0,0xf0223e88
f01061be:	75 24                	jne    f01061e4 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01061c0:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f01061c7:	00 
f01061c8:	c7 44 24 08 64 67 10 	movl   $0xf0106764,0x8(%esp)
f01061cf:	f0 
f01061d0:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f01061d7:	00 
f01061d8:	c7 04 24 78 81 10 f0 	movl   $0xf0108178,(%esp)
f01061df:	e8 5c 9e ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f01061e4:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f01061eb:	00 00 
	wrv[1] = addr >> 4;
f01061ed:	89 f0                	mov    %esi,%eax
f01061ef:	c1 e8 04             	shr    $0x4,%eax
f01061f2:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f01061f8:	c1 e3 18             	shl    $0x18,%ebx
f01061fb:	89 da                	mov    %ebx,%edx
f01061fd:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106202:	e8 24 fe ff ff       	call   f010602b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106207:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010620c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106211:	e8 15 fe ff ff       	call   f010602b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106216:	ba 00 85 00 00       	mov    $0x8500,%edx
f010621b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106220:	e8 06 fe ff ff       	call   f010602b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106225:	c1 ee 0c             	shr    $0xc,%esi
f0106228:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010622e:	89 da                	mov    %ebx,%edx
f0106230:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106235:	e8 f1 fd ff ff       	call   f010602b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f010623a:	89 f2                	mov    %esi,%edx
f010623c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106241:	e8 e5 fd ff ff       	call   f010602b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0106246:	89 da                	mov    %ebx,%edx
f0106248:	b8 c4 00 00 00       	mov    $0xc4,%eax
f010624d:	e8 d9 fd ff ff       	call   f010602b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106252:	89 f2                	mov    %esi,%edx
f0106254:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106259:	e8 cd fd ff ff       	call   f010602b <lapicw>
		microdelay(200);
	}
}
f010625e:	83 c4 10             	add    $0x10,%esp
f0106261:	5b                   	pop    %ebx
f0106262:	5e                   	pop    %esi
f0106263:	5d                   	pop    %ebp
f0106264:	c3                   	ret    

f0106265 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f0106265:	55                   	push   %ebp
f0106266:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f0106268:	8b 55 08             	mov    0x8(%ebp),%edx
f010626b:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f0106271:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106276:	e8 b0 fd ff ff       	call   f010602b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f010627b:	8b 15 00 50 26 f0    	mov    0xf0265000,%edx
f0106281:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f0106287:	f6 c4 10             	test   $0x10,%ah
f010628a:	75 f5                	jne    f0106281 <lapic_ipi+0x1c>
		;
}
f010628c:	5d                   	pop    %ebp
f010628d:	c3                   	ret    

f010628e <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f010628e:	55                   	push   %ebp
f010628f:	89 e5                	mov    %esp,%ebp
f0106291:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f0106294:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f010629a:	8b 55 0c             	mov    0xc(%ebp),%edx
f010629d:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f01062a0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f01062a7:	5d                   	pop    %ebp
f01062a8:	c3                   	ret    

f01062a9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f01062a9:	55                   	push   %ebp
f01062aa:	89 e5                	mov    %esp,%ebp
f01062ac:	56                   	push   %esi
f01062ad:	53                   	push   %ebx
f01062ae:	83 ec 20             	sub    $0x20,%esp
f01062b1:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01062b4:	83 3b 00             	cmpl   $0x0,(%ebx)
f01062b7:	74 14                	je     f01062cd <spin_lock+0x24>
f01062b9:	8b 73 08             	mov    0x8(%ebx),%esi
f01062bc:	e8 82 fd ff ff       	call   f0106043 <cpunum>
f01062c1:	6b c0 74             	imul   $0x74,%eax,%eax
f01062c4:	05 20 40 22 f0       	add    $0xf0224020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f01062c9:	39 c6                	cmp    %eax,%esi
f01062cb:	74 15                	je     f01062e2 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f01062cd:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01062cf:	b8 01 00 00 00       	mov    $0x1,%eax
f01062d4:	f0 87 03             	lock xchg %eax,(%ebx)
f01062d7:	b9 01 00 00 00       	mov    $0x1,%ecx
f01062dc:	85 c0                	test   %eax,%eax
f01062de:	75 2e                	jne    f010630e <spin_lock+0x65>
f01062e0:	eb 37                	jmp    f0106319 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f01062e2:	8b 5b 04             	mov    0x4(%ebx),%ebx
f01062e5:	e8 59 fd ff ff       	call   f0106043 <cpunum>
f01062ea:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f01062ee:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01062f2:	c7 44 24 08 88 81 10 	movl   $0xf0108188,0x8(%esp)
f01062f9:	f0 
f01062fa:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106301:	00 
f0106302:	c7 04 24 ec 81 10 f0 	movl   $0xf01081ec,(%esp)
f0106309:	e8 32 9d ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010630e:	f3 90                	pause  
f0106310:	89 c8                	mov    %ecx,%eax
f0106312:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106315:	85 c0                	test   %eax,%eax
f0106317:	75 f5                	jne    f010630e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106319:	e8 25 fd ff ff       	call   f0106043 <cpunum>
f010631e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106321:	05 20 40 22 f0       	add    $0xf0224020,%eax
f0106326:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106329:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010632c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010632e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106334:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010633a:	76 3a                	jbe    f0106376 <spin_lock+0xcd>
f010633c:	eb 31                	jmp    f010636f <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010633e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106344:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010634a:	77 12                	ja     f010635e <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010634c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010634f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f0106352:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f0106354:	83 c0 01             	add    $0x1,%eax
f0106357:	83 f8 0a             	cmp    $0xa,%eax
f010635a:	75 e2                	jne    f010633e <spin_lock+0x95>
f010635c:	eb 27                	jmp    f0106385 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f010635e:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f0106365:	83 c0 01             	add    $0x1,%eax
f0106368:	83 f8 09             	cmp    $0x9,%eax
f010636b:	7e f1                	jle    f010635e <spin_lock+0xb5>
f010636d:	eb 16                	jmp    f0106385 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010636f:	b8 00 00 00 00       	mov    $0x0,%eax
f0106374:	eb e8                	jmp    f010635e <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f0106376:	8b 50 04             	mov    0x4(%eax),%edx
f0106379:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f010637c:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f010637e:	b8 01 00 00 00       	mov    $0x1,%eax
f0106383:	eb b9                	jmp    f010633e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f0106385:	83 c4 20             	add    $0x20,%esp
f0106388:	5b                   	pop    %ebx
f0106389:	5e                   	pop    %esi
f010638a:	5d                   	pop    %ebp
f010638b:	c3                   	ret    

f010638c <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f010638c:	55                   	push   %ebp
f010638d:	89 e5                	mov    %esp,%ebp
f010638f:	57                   	push   %edi
f0106390:	56                   	push   %esi
f0106391:	53                   	push   %ebx
f0106392:	83 ec 6c             	sub    $0x6c,%esp
f0106395:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106398:	83 3b 00             	cmpl   $0x0,(%ebx)
f010639b:	74 18                	je     f01063b5 <spin_unlock+0x29>
f010639d:	8b 73 08             	mov    0x8(%ebx),%esi
f01063a0:	e8 9e fc ff ff       	call   f0106043 <cpunum>
f01063a5:	6b c0 74             	imul   $0x74,%eax,%eax
f01063a8:	05 20 40 22 f0       	add    $0xf0224020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f01063ad:	39 c6                	cmp    %eax,%esi
f01063af:	0f 84 d4 00 00 00    	je     f0106489 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f01063b5:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f01063bc:	00 
f01063bd:	8d 43 0c             	lea    0xc(%ebx),%eax
f01063c0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063c4:	8d 45 c0             	lea    -0x40(%ebp),%eax
f01063c7:	89 04 24             	mov    %eax,(%esp)
f01063ca:	e8 27 f6 ff ff       	call   f01059f6 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f01063cf:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f01063d2:	0f b6 30             	movzbl (%eax),%esi
f01063d5:	8b 5b 04             	mov    0x4(%ebx),%ebx
f01063d8:	e8 66 fc ff ff       	call   f0106043 <cpunum>
f01063dd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f01063e1:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01063e5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063e9:	c7 04 24 b4 81 10 f0 	movl   $0xf01081b4,(%esp)
f01063f0:	e8 3a dd ff ff       	call   f010412f <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01063f5:	8b 45 c0             	mov    -0x40(%ebp),%eax
f01063f8:	85 c0                	test   %eax,%eax
f01063fa:	74 71                	je     f010646d <spin_unlock+0xe1>
f01063fc:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f01063ff:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106402:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106405:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106409:	89 04 24             	mov    %eax,(%esp)
f010640c:	e8 8b e9 ff ff       	call   f0104d9c <debuginfo_eip>
f0106411:	85 c0                	test   %eax,%eax
f0106413:	78 39                	js     f010644e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106415:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106417:	89 c2                	mov    %eax,%edx
f0106419:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010641c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106420:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106423:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106427:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010642a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010642e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106431:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106435:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106438:	89 54 24 08          	mov    %edx,0x8(%esp)
f010643c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106440:	c7 04 24 fc 81 10 f0 	movl   $0xf01081fc,(%esp)
f0106447:	e8 e3 dc ff ff       	call   f010412f <cprintf>
f010644c:	eb 12                	jmp    f0106460 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010644e:	8b 03                	mov    (%ebx),%eax
f0106450:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106454:	c7 04 24 13 82 10 f0 	movl   $0xf0108213,(%esp)
f010645b:	e8 cf dc ff ff       	call   f010412f <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106460:	39 fb                	cmp    %edi,%ebx
f0106462:	74 09                	je     f010646d <spin_unlock+0xe1>
f0106464:	83 c3 04             	add    $0x4,%ebx
f0106467:	8b 03                	mov    (%ebx),%eax
f0106469:	85 c0                	test   %eax,%eax
f010646b:	75 98                	jne    f0106405 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f010646d:	c7 44 24 08 1b 82 10 	movl   $0xf010821b,0x8(%esp)
f0106474:	f0 
f0106475:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f010647c:	00 
f010647d:	c7 04 24 ec 81 10 f0 	movl   $0xf01081ec,(%esp)
f0106484:	e8 b7 9b ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f0106489:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f0106490:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f0106497:	b8 00 00 00 00       	mov    $0x0,%eax
f010649c:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f010649f:	83 c4 6c             	add    $0x6c,%esp
f01064a2:	5b                   	pop    %ebx
f01064a3:	5e                   	pop    %esi
f01064a4:	5f                   	pop    %edi
f01064a5:	5d                   	pop    %ebp
f01064a6:	c3                   	ret    
f01064a7:	66 90                	xchg   %ax,%ax
f01064a9:	66 90                	xchg   %ax,%ax
f01064ab:	66 90                	xchg   %ax,%ax
f01064ad:	66 90                	xchg   %ax,%ax
f01064af:	90                   	nop

f01064b0 <__udivdi3>:
f01064b0:	55                   	push   %ebp
f01064b1:	57                   	push   %edi
f01064b2:	56                   	push   %esi
f01064b3:	83 ec 0c             	sub    $0xc,%esp
f01064b6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01064ba:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f01064be:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f01064c2:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01064c6:	85 c0                	test   %eax,%eax
f01064c8:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01064cc:	89 ea                	mov    %ebp,%edx
f01064ce:	89 0c 24             	mov    %ecx,(%esp)
f01064d1:	75 2d                	jne    f0106500 <__udivdi3+0x50>
f01064d3:	39 e9                	cmp    %ebp,%ecx
f01064d5:	77 61                	ja     f0106538 <__udivdi3+0x88>
f01064d7:	85 c9                	test   %ecx,%ecx
f01064d9:	89 ce                	mov    %ecx,%esi
f01064db:	75 0b                	jne    f01064e8 <__udivdi3+0x38>
f01064dd:	b8 01 00 00 00       	mov    $0x1,%eax
f01064e2:	31 d2                	xor    %edx,%edx
f01064e4:	f7 f1                	div    %ecx
f01064e6:	89 c6                	mov    %eax,%esi
f01064e8:	31 d2                	xor    %edx,%edx
f01064ea:	89 e8                	mov    %ebp,%eax
f01064ec:	f7 f6                	div    %esi
f01064ee:	89 c5                	mov    %eax,%ebp
f01064f0:	89 f8                	mov    %edi,%eax
f01064f2:	f7 f6                	div    %esi
f01064f4:	89 ea                	mov    %ebp,%edx
f01064f6:	83 c4 0c             	add    $0xc,%esp
f01064f9:	5e                   	pop    %esi
f01064fa:	5f                   	pop    %edi
f01064fb:	5d                   	pop    %ebp
f01064fc:	c3                   	ret    
f01064fd:	8d 76 00             	lea    0x0(%esi),%esi
f0106500:	39 e8                	cmp    %ebp,%eax
f0106502:	77 24                	ja     f0106528 <__udivdi3+0x78>
f0106504:	0f bd e8             	bsr    %eax,%ebp
f0106507:	83 f5 1f             	xor    $0x1f,%ebp
f010650a:	75 3c                	jne    f0106548 <__udivdi3+0x98>
f010650c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106510:	39 34 24             	cmp    %esi,(%esp)
f0106513:	0f 86 9f 00 00 00    	jbe    f01065b8 <__udivdi3+0x108>
f0106519:	39 d0                	cmp    %edx,%eax
f010651b:	0f 82 97 00 00 00    	jb     f01065b8 <__udivdi3+0x108>
f0106521:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106528:	31 d2                	xor    %edx,%edx
f010652a:	31 c0                	xor    %eax,%eax
f010652c:	83 c4 0c             	add    $0xc,%esp
f010652f:	5e                   	pop    %esi
f0106530:	5f                   	pop    %edi
f0106531:	5d                   	pop    %ebp
f0106532:	c3                   	ret    
f0106533:	90                   	nop
f0106534:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106538:	89 f8                	mov    %edi,%eax
f010653a:	f7 f1                	div    %ecx
f010653c:	31 d2                	xor    %edx,%edx
f010653e:	83 c4 0c             	add    $0xc,%esp
f0106541:	5e                   	pop    %esi
f0106542:	5f                   	pop    %edi
f0106543:	5d                   	pop    %ebp
f0106544:	c3                   	ret    
f0106545:	8d 76 00             	lea    0x0(%esi),%esi
f0106548:	89 e9                	mov    %ebp,%ecx
f010654a:	8b 3c 24             	mov    (%esp),%edi
f010654d:	d3 e0                	shl    %cl,%eax
f010654f:	89 c6                	mov    %eax,%esi
f0106551:	b8 20 00 00 00       	mov    $0x20,%eax
f0106556:	29 e8                	sub    %ebp,%eax
f0106558:	89 c1                	mov    %eax,%ecx
f010655a:	d3 ef                	shr    %cl,%edi
f010655c:	89 e9                	mov    %ebp,%ecx
f010655e:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0106562:	8b 3c 24             	mov    (%esp),%edi
f0106565:	09 74 24 08          	or     %esi,0x8(%esp)
f0106569:	89 d6                	mov    %edx,%esi
f010656b:	d3 e7                	shl    %cl,%edi
f010656d:	89 c1                	mov    %eax,%ecx
f010656f:	89 3c 24             	mov    %edi,(%esp)
f0106572:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106576:	d3 ee                	shr    %cl,%esi
f0106578:	89 e9                	mov    %ebp,%ecx
f010657a:	d3 e2                	shl    %cl,%edx
f010657c:	89 c1                	mov    %eax,%ecx
f010657e:	d3 ef                	shr    %cl,%edi
f0106580:	09 d7                	or     %edx,%edi
f0106582:	89 f2                	mov    %esi,%edx
f0106584:	89 f8                	mov    %edi,%eax
f0106586:	f7 74 24 08          	divl   0x8(%esp)
f010658a:	89 d6                	mov    %edx,%esi
f010658c:	89 c7                	mov    %eax,%edi
f010658e:	f7 24 24             	mull   (%esp)
f0106591:	39 d6                	cmp    %edx,%esi
f0106593:	89 14 24             	mov    %edx,(%esp)
f0106596:	72 30                	jb     f01065c8 <__udivdi3+0x118>
f0106598:	8b 54 24 04          	mov    0x4(%esp),%edx
f010659c:	89 e9                	mov    %ebp,%ecx
f010659e:	d3 e2                	shl    %cl,%edx
f01065a0:	39 c2                	cmp    %eax,%edx
f01065a2:	73 05                	jae    f01065a9 <__udivdi3+0xf9>
f01065a4:	3b 34 24             	cmp    (%esp),%esi
f01065a7:	74 1f                	je     f01065c8 <__udivdi3+0x118>
f01065a9:	89 f8                	mov    %edi,%eax
f01065ab:	31 d2                	xor    %edx,%edx
f01065ad:	e9 7a ff ff ff       	jmp    f010652c <__udivdi3+0x7c>
f01065b2:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f01065b8:	31 d2                	xor    %edx,%edx
f01065ba:	b8 01 00 00 00       	mov    $0x1,%eax
f01065bf:	e9 68 ff ff ff       	jmp    f010652c <__udivdi3+0x7c>
f01065c4:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f01065c8:	8d 47 ff             	lea    -0x1(%edi),%eax
f01065cb:	31 d2                	xor    %edx,%edx
f01065cd:	83 c4 0c             	add    $0xc,%esp
f01065d0:	5e                   	pop    %esi
f01065d1:	5f                   	pop    %edi
f01065d2:	5d                   	pop    %ebp
f01065d3:	c3                   	ret    
f01065d4:	66 90                	xchg   %ax,%ax
f01065d6:	66 90                	xchg   %ax,%ax
f01065d8:	66 90                	xchg   %ax,%ax
f01065da:	66 90                	xchg   %ax,%ax
f01065dc:	66 90                	xchg   %ax,%ax
f01065de:	66 90                	xchg   %ax,%ax

f01065e0 <__umoddi3>:
f01065e0:	55                   	push   %ebp
f01065e1:	57                   	push   %edi
f01065e2:	56                   	push   %esi
f01065e3:	83 ec 14             	sub    $0x14,%esp
f01065e6:	8b 44 24 28          	mov    0x28(%esp),%eax
f01065ea:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f01065ee:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f01065f2:	89 c7                	mov    %eax,%edi
f01065f4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01065f8:	8b 44 24 30          	mov    0x30(%esp),%eax
f01065fc:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106600:	89 34 24             	mov    %esi,(%esp)
f0106603:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106607:	85 c0                	test   %eax,%eax
f0106609:	89 c2                	mov    %eax,%edx
f010660b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f010660f:	75 17                	jne    f0106628 <__umoddi3+0x48>
f0106611:	39 fe                	cmp    %edi,%esi
f0106613:	76 4b                	jbe    f0106660 <__umoddi3+0x80>
f0106615:	89 c8                	mov    %ecx,%eax
f0106617:	89 fa                	mov    %edi,%edx
f0106619:	f7 f6                	div    %esi
f010661b:	89 d0                	mov    %edx,%eax
f010661d:	31 d2                	xor    %edx,%edx
f010661f:	83 c4 14             	add    $0x14,%esp
f0106622:	5e                   	pop    %esi
f0106623:	5f                   	pop    %edi
f0106624:	5d                   	pop    %ebp
f0106625:	c3                   	ret    
f0106626:	66 90                	xchg   %ax,%ax
f0106628:	39 f8                	cmp    %edi,%eax
f010662a:	77 54                	ja     f0106680 <__umoddi3+0xa0>
f010662c:	0f bd e8             	bsr    %eax,%ebp
f010662f:	83 f5 1f             	xor    $0x1f,%ebp
f0106632:	75 5c                	jne    f0106690 <__umoddi3+0xb0>
f0106634:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106638:	39 3c 24             	cmp    %edi,(%esp)
f010663b:	0f 87 e7 00 00 00    	ja     f0106728 <__umoddi3+0x148>
f0106641:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106645:	29 f1                	sub    %esi,%ecx
f0106647:	19 c7                	sbb    %eax,%edi
f0106649:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f010664d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106651:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106655:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106659:	83 c4 14             	add    $0x14,%esp
f010665c:	5e                   	pop    %esi
f010665d:	5f                   	pop    %edi
f010665e:	5d                   	pop    %ebp
f010665f:	c3                   	ret    
f0106660:	85 f6                	test   %esi,%esi
f0106662:	89 f5                	mov    %esi,%ebp
f0106664:	75 0b                	jne    f0106671 <__umoddi3+0x91>
f0106666:	b8 01 00 00 00       	mov    $0x1,%eax
f010666b:	31 d2                	xor    %edx,%edx
f010666d:	f7 f6                	div    %esi
f010666f:	89 c5                	mov    %eax,%ebp
f0106671:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106675:	31 d2                	xor    %edx,%edx
f0106677:	f7 f5                	div    %ebp
f0106679:	89 c8                	mov    %ecx,%eax
f010667b:	f7 f5                	div    %ebp
f010667d:	eb 9c                	jmp    f010661b <__umoddi3+0x3b>
f010667f:	90                   	nop
f0106680:	89 c8                	mov    %ecx,%eax
f0106682:	89 fa                	mov    %edi,%edx
f0106684:	83 c4 14             	add    $0x14,%esp
f0106687:	5e                   	pop    %esi
f0106688:	5f                   	pop    %edi
f0106689:	5d                   	pop    %ebp
f010668a:	c3                   	ret    
f010668b:	90                   	nop
f010668c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106690:	8b 04 24             	mov    (%esp),%eax
f0106693:	be 20 00 00 00       	mov    $0x20,%esi
f0106698:	89 e9                	mov    %ebp,%ecx
f010669a:	29 ee                	sub    %ebp,%esi
f010669c:	d3 e2                	shl    %cl,%edx
f010669e:	89 f1                	mov    %esi,%ecx
f01066a0:	d3 e8                	shr    %cl,%eax
f01066a2:	89 e9                	mov    %ebp,%ecx
f01066a4:	89 44 24 04          	mov    %eax,0x4(%esp)
f01066a8:	8b 04 24             	mov    (%esp),%eax
f01066ab:	09 54 24 04          	or     %edx,0x4(%esp)
f01066af:	89 fa                	mov    %edi,%edx
f01066b1:	d3 e0                	shl    %cl,%eax
f01066b3:	89 f1                	mov    %esi,%ecx
f01066b5:	89 44 24 08          	mov    %eax,0x8(%esp)
f01066b9:	8b 44 24 10          	mov    0x10(%esp),%eax
f01066bd:	d3 ea                	shr    %cl,%edx
f01066bf:	89 e9                	mov    %ebp,%ecx
f01066c1:	d3 e7                	shl    %cl,%edi
f01066c3:	89 f1                	mov    %esi,%ecx
f01066c5:	d3 e8                	shr    %cl,%eax
f01066c7:	89 e9                	mov    %ebp,%ecx
f01066c9:	09 f8                	or     %edi,%eax
f01066cb:	8b 7c 24 10          	mov    0x10(%esp),%edi
f01066cf:	f7 74 24 04          	divl   0x4(%esp)
f01066d3:	d3 e7                	shl    %cl,%edi
f01066d5:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01066d9:	89 d7                	mov    %edx,%edi
f01066db:	f7 64 24 08          	mull   0x8(%esp)
f01066df:	39 d7                	cmp    %edx,%edi
f01066e1:	89 c1                	mov    %eax,%ecx
f01066e3:	89 14 24             	mov    %edx,(%esp)
f01066e6:	72 2c                	jb     f0106714 <__umoddi3+0x134>
f01066e8:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f01066ec:	72 22                	jb     f0106710 <__umoddi3+0x130>
f01066ee:	8b 44 24 0c          	mov    0xc(%esp),%eax
f01066f2:	29 c8                	sub    %ecx,%eax
f01066f4:	19 d7                	sbb    %edx,%edi
f01066f6:	89 e9                	mov    %ebp,%ecx
f01066f8:	89 fa                	mov    %edi,%edx
f01066fa:	d3 e8                	shr    %cl,%eax
f01066fc:	89 f1                	mov    %esi,%ecx
f01066fe:	d3 e2                	shl    %cl,%edx
f0106700:	89 e9                	mov    %ebp,%ecx
f0106702:	d3 ef                	shr    %cl,%edi
f0106704:	09 d0                	or     %edx,%eax
f0106706:	89 fa                	mov    %edi,%edx
f0106708:	83 c4 14             	add    $0x14,%esp
f010670b:	5e                   	pop    %esi
f010670c:	5f                   	pop    %edi
f010670d:	5d                   	pop    %ebp
f010670e:	c3                   	ret    
f010670f:	90                   	nop
f0106710:	39 d7                	cmp    %edx,%edi
f0106712:	75 da                	jne    f01066ee <__umoddi3+0x10e>
f0106714:	8b 14 24             	mov    (%esp),%edx
f0106717:	89 c1                	mov    %eax,%ecx
f0106719:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f010671d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106721:	eb cb                	jmp    f01066ee <__umoddi3+0x10e>
f0106723:	90                   	nop
f0106724:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106728:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f010672c:	0f 82 0f ff ff ff    	jb     f0106641 <__umoddi3+0x61>
f0106732:	e9 1a ff ff ff       	jmp    f0106651 <__umoddi3+0x71>
