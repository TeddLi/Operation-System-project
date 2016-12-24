
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
f0100015:	b8 00 f0 11 00       	mov    $0x11f000,%eax
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
f0100034:	bc 00 f0 11 f0       	mov    $0xf011f000,%esp

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
f010004b:	83 3d 80 ce 1c f0 00 	cmpl   $0x0,0xf01cce80
f0100052:	75 46                	jne    f010009a <_panic+0x5a>
		goto dead;
	panicstr = fmt;
f0100054:	89 35 80 ce 1c f0    	mov    %esi,0xf01cce80

	// Be extra sure that the machine is in as reasonable state
	__asm __volatile("cli; cld");
f010005a:	fa                   	cli    
f010005b:	fc                   	cld    

	va_start(ap, fmt);
f010005c:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel panic on CPU %d at %s:%d: ", cpunum(), file, line);
f010005f:	e8 2f 64 00 00       	call   f0106493 <cpunum>
f0100064:	8b 55 0c             	mov    0xc(%ebp),%edx
f0100067:	89 54 24 0c          	mov    %edx,0xc(%esp)
f010006b:	8b 55 08             	mov    0x8(%ebp),%edx
f010006e:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100072:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100076:	c7 04 24 a0 6b 10 f0 	movl   $0xf0106ba0,(%esp)
f010007d:	e8 ed 3b 00 00       	call   f0103c6f <cprintf>
	vcprintf(fmt, ap);
f0100082:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0100086:	89 34 24             	mov    %esi,(%esp)
f0100089:	e8 ae 3b 00 00       	call   f0103c3c <vcprintf>
	cprintf("\n");
f010008e:	c7 04 24 bf 7c 10 f0 	movl   $0xf0107cbf,(%esp)
f0100095:	e8 d5 3b 00 00       	call   f0103c6f <cprintf>
	va_end(ap);

dead:
	/* break into the kernel monitor */
	while (1)
		monitor(NULL);
f010009a:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01000a1:	e8 11 09 00 00       	call   f01009b7 <monitor>
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
f01000af:	b8 04 e0 20 f0       	mov    $0xf020e004,%eax
f01000b4:	2d bb be 1c f0       	sub    $0xf01cbebb,%eax
f01000b9:	89 44 24 08          	mov    %eax,0x8(%esp)
f01000bd:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01000c4:	00 
f01000c5:	c7 04 24 bb be 1c f0 	movl   $0xf01cbebb,(%esp)
f01000cc:	e8 28 5d 00 00       	call   f0105df9 <memset>

	// Initialize the console.
	// Can't call cprintf until after we do this!
	cons_init();
f01000d1:	e8 19 06 00 00       	call   f01006ef <cons_init>

	cprintf("6828 decimal is %o octal!\n", 6828);
f01000d6:	c7 44 24 04 ac 1a 00 	movl   $0x1aac,0x4(%esp)
f01000dd:	00 
f01000de:	c7 04 24 0c 6c 10 f0 	movl   $0xf0106c0c,(%esp)
f01000e5:	e8 85 3b 00 00       	call   f0103c6f <cprintf>

	// Lab 2 memory management initialization functions
	mem_init();
f01000ea:	e8 e6 13 00 00       	call   f01014d5 <mem_init>

	// Lab 3 user environment initialization functions
	env_init();
f01000ef:	e8 12 33 00 00       	call   f0103406 <env_init>
	trap_init();
f01000f4:	e8 20 3c 00 00       	call   f0103d19 <trap_init>

	// Lab 4 multiprocessor initialization functions
	mp_init();
f01000f9:	e8 7b 60 00 00       	call   f0106179 <mp_init>
	lapic_init();
f01000fe:	66 90                	xchg   %ax,%ax
f0100100:	e8 a9 63 00 00       	call   f01064ae <lapic_init>

	// Lab 4 multitasking initialization functions
	pic_init();
f0100105:	e8 92 3a 00 00       	call   f0103b9c <pic_init>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f010010a:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0100111:	e8 e3 65 00 00       	call   f01066f9 <spin_lock>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100116:	83 3d 88 ce 1c f0 07 	cmpl   $0x7,0xf01cce88
f010011d:	77 24                	ja     f0100143 <i386_init+0x9b>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010011f:	c7 44 24 0c 00 70 00 	movl   $0x7000,0xc(%esp)
f0100126:	00 
f0100127:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f010012e:	f0 
f010012f:	c7 44 24 04 6b 00 00 	movl   $0x6b,0x4(%esp)
f0100136:	00 
f0100137:	c7 04 24 27 6c 10 f0 	movl   $0xf0106c27,(%esp)
f010013e:	e8 fd fe ff ff       	call   f0100040 <_panic>
	void *code;
	struct Cpu *c;

	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);
f0100143:	b8 a6 60 10 f0       	mov    $0xf01060a6,%eax
f0100148:	2d 2c 60 10 f0       	sub    $0xf010602c,%eax
f010014d:	89 44 24 08          	mov    %eax,0x8(%esp)
f0100151:	c7 44 24 04 2c 60 10 	movl   $0xf010602c,0x4(%esp)
f0100158:	f0 
f0100159:	c7 04 24 00 70 00 f0 	movl   $0xf0007000,(%esp)
f0100160:	e8 e1 5c 00 00       	call   f0105e46 <memmove>

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f0100165:	6b 05 c4 d3 1c f0 74 	imul   $0x74,0xf01cd3c4,%eax
f010016c:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
f0100171:	3d 20 d0 1c f0       	cmp    $0xf01cd020,%eax
f0100176:	0f 86 c2 00 00 00    	jbe    f010023e <i386_init+0x196>
f010017c:	bb 20 d0 1c f0       	mov    $0xf01cd020,%ebx
		if (c == cpus + cpunum())  // We've started already.
f0100181:	e8 0d 63 00 00       	call   f0106493 <cpunum>
f0100186:	6b c0 74             	imul   $0x74,%eax,%eax
f0100189:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
f010018e:	39 c3                	cmp    %eax,%ebx
f0100190:	74 39                	je     f01001cb <i386_init+0x123>
f0100192:	89 d8                	mov    %ebx,%eax
f0100194:	2d 20 d0 1c f0       	sub    $0xf01cd020,%eax
			continue;

		// Tell mpentry.S what stack to use 
		mpentry_kstack = percpu_kstacks[c - cpus] + KSTKSIZE;
f0100199:	c1 f8 02             	sar    $0x2,%eax
f010019c:	69 c0 35 c2 72 4f    	imul   $0x4f72c235,%eax,%eax
f01001a2:	c1 e0 0f             	shl    $0xf,%eax
f01001a5:	8d 80 00 60 1d f0    	lea    -0xfe2a000(%eax),%eax
f01001ab:	a3 84 ce 1c f0       	mov    %eax,0xf01cce84
		// Start the CPU at mpentry_start
		lapic_startap(c->cpu_id, PADDR(code));
f01001b0:	c7 44 24 04 00 70 00 	movl   $0x7000,0x4(%esp)
f01001b7:	00 
f01001b8:	0f b6 03             	movzbl (%ebx),%eax
f01001bb:	89 04 24             	mov    %eax,(%esp)
f01001be:	e8 23 64 00 00       	call   f01065e6 <lapic_startap>
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
f01001ce:	6b 05 c4 d3 1c f0 74 	imul   $0x74,0xf01cd3c4,%eax
f01001d5:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
f01001da:	39 c3                	cmp    %eax,%ebx
f01001dc:	72 a3                	jb     f0100181 <i386_init+0xd9>
f01001de:	eb 5e                	jmp    f010023e <i386_init+0x196>
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);
f01001e0:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f01001e7:	00 
f01001e8:	c7 44 24 04 05 3c 00 	movl   $0x3c05,0x4(%esp)
f01001ef:	00 
f01001f0:	c7 04 24 d7 70 15 f0 	movl   $0xf01570d7,(%esp)
f01001f7:	e8 e6 33 00 00       	call   f01035e2 <env_create>
	// Starting non-boot CPUs
	boot_aps();

	// Should always have idle processes at first.
	int i;
	for (i = 0; i < NCPU; i++)
f01001fc:	83 eb 01             	sub    $0x1,%ebx
f01001ff:	75 df                	jne    f01001e0 <i386_init+0x138>
		ENV_CREATE(user_idle, ENV_TYPE_IDLE);

//<<<<<<< HEAD
	// Start fs.
	ENV_CREATE(fs_fs, ENV_TYPE_FS);
f0100201:	c7 44 24 08 02 00 00 	movl   $0x2,0x8(%esp)
f0100208:	00 
f0100209:	c7 44 24 04 4f 63 01 	movl   $0x1634f,0x4(%esp)
f0100210:	00 
f0100211:	c7 04 24 6c 5b 1b f0 	movl   $0xf01b5b6c,(%esp)
f0100218:	e8 c5 33 00 00       	call   f01035e2 <env_create>
//=======
//>>>>>>> lab4

#if defined(TEST)
	// Don't touch -- used by grading script!
	ENV_CREATE(TEST, ENV_TYPE_USER);
f010021d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0100224:	00 
f0100225:	c7 44 24 04 4b 4c 00 	movl   $0x4c4b,0x4(%esp)
f010022c:	00 
f010022d:	c7 04 24 21 0f 1b f0 	movl   $0xf01b0f21,(%esp)
f0100234:	e8 a9 33 00 00       	call   f01035e2 <env_create>
//	ENV_CREATE(user_yield, ENV_TYPE_USER);
//>>>>>>> lab4
#endif // TEST*

	// Schedule and run the first user environment!
	sched_yield();
f0100239:	e8 72 47 00 00       	call   f01049b0 <sched_yield>
	// Write entry code to unused memory at MPENTRY_PADDR
	code = KADDR(MPENTRY_PADDR);
	memmove(code, mpentry_start, mpentry_end - mpentry_start);

	// Boot each AP one at a time
	for (c = cpus; c < cpus + ncpu; c++) {
f010023e:	bb 08 00 00 00       	mov    $0x8,%ebx
f0100243:	eb 9b                	jmp    f01001e0 <i386_init+0x138>

f0100245 <mp_main>:
}

// Setup code for APs
void
mp_main(void)
{
f0100245:	55                   	push   %ebp
f0100246:	89 e5                	mov    %esp,%ebp
f0100248:	83 ec 18             	sub    $0x18,%esp
	// We are in high EIP now, safe to switch to kern_pgdir 
	lcr3(PADDR(kern_pgdir));
f010024b:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0100250:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0100255:	77 20                	ja     f0100277 <mp_main+0x32>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0100257:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010025b:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0100262:	f0 
f0100263:	c7 44 24 04 82 00 00 	movl   $0x82,0x4(%esp)
f010026a:	00 
f010026b:	c7 04 24 27 6c 10 f0 	movl   $0xf0106c27,(%esp)
f0100272:	e8 c9 fd ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0100277:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010027c:	0f 22 d8             	mov    %eax,%cr3
	cprintf("SMP: CPU %d starting\n", cpunum());
f010027f:	e8 0f 62 00 00       	call   f0106493 <cpunum>
f0100284:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100288:	c7 04 24 33 6c 10 f0 	movl   $0xf0106c33,(%esp)
f010028f:	e8 db 39 00 00       	call   f0103c6f <cprintf>

	lapic_init();
f0100294:	e8 15 62 00 00       	call   f01064ae <lapic_init>
	env_init_percpu();
f0100299:	e8 3e 31 00 00       	call   f01033dc <env_init_percpu>
	trap_init_percpu();
f010029e:	66 90                	xchg   %ax,%ax
f01002a0:	e8 eb 39 00 00       	call   f0103c90 <trap_init_percpu>
	xchg(&thiscpu->cpu_status, CPU_STARTED); // tell boot_aps() we're up
f01002a5:	e8 e9 61 00 00       	call   f0106493 <cpunum>
f01002aa:	6b d0 74             	imul   $0x74,%eax,%edx
f01002ad:	81 c2 20 d0 1c f0    	add    $0xf01cd020,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01002b3:	b8 01 00 00 00       	mov    $0x1,%eax
f01002b8:	f0 87 42 04          	lock xchg %eax,0x4(%edx)
f01002bc:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01002c3:	e8 31 64 00 00       	call   f01066f9 <spin_lock>
	// to start running processes on this CPU.  But make sure that
	// only one CPU can enter the scheduler at a time!
	//
	// Your code here:
	lock_kernel();
	sched_yield();
f01002c8:	e8 e3 46 00 00       	call   f01049b0 <sched_yield>

f01002cd <_warn>:
}

/* like panic, but don't */
void
_warn(const char *file, int line, const char *fmt,...)
{
f01002cd:	55                   	push   %ebp
f01002ce:	89 e5                	mov    %esp,%ebp
f01002d0:	53                   	push   %ebx
f01002d1:	83 ec 14             	sub    $0x14,%esp
	va_list ap;

	va_start(ap, fmt);
f01002d4:	8d 5d 14             	lea    0x14(%ebp),%ebx
	cprintf("kernel warning at %s:%d: ", file, line);
f01002d7:	8b 45 0c             	mov    0xc(%ebp),%eax
f01002da:	89 44 24 08          	mov    %eax,0x8(%esp)
f01002de:	8b 45 08             	mov    0x8(%ebp),%eax
f01002e1:	89 44 24 04          	mov    %eax,0x4(%esp)
f01002e5:	c7 04 24 49 6c 10 f0 	movl   $0xf0106c49,(%esp)
f01002ec:	e8 7e 39 00 00       	call   f0103c6f <cprintf>
	vcprintf(fmt, ap);
f01002f1:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01002f5:	8b 45 10             	mov    0x10(%ebp),%eax
f01002f8:	89 04 24             	mov    %eax,(%esp)
f01002fb:	e8 3c 39 00 00       	call   f0103c3c <vcprintf>
	cprintf("\n");
f0100300:	c7 04 24 bf 7c 10 f0 	movl   $0xf0107cbf,(%esp)
f0100307:	e8 63 39 00 00       	call   f0103c6f <cprintf>
	va_end(ap);
}
f010030c:	83 c4 14             	add    $0x14,%esp
f010030f:	5b                   	pop    %ebx
f0100310:	5d                   	pop    %ebp
f0100311:	c3                   	ret    
f0100312:	66 90                	xchg   %ax,%ax
f0100314:	66 90                	xchg   %ax,%ax
f0100316:	66 90                	xchg   %ax,%ax
f0100318:	66 90                	xchg   %ax,%ax
f010031a:	66 90                	xchg   %ax,%ax
f010031c:	66 90                	xchg   %ax,%ax
f010031e:	66 90                	xchg   %ax,%ax

f0100320 <serial_proc_data>:

static bool serial_exists;

static int
serial_proc_data(void)
{
f0100320:	55                   	push   %ebp
f0100321:	89 e5                	mov    %esp,%ebp

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100323:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100328:	ec                   	in     (%dx),%al
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
f0100329:	a8 01                	test   $0x1,%al
f010032b:	74 08                	je     f0100335 <serial_proc_data+0x15>
f010032d:	b2 f8                	mov    $0xf8,%dl
f010032f:	ec                   	in     (%dx),%al
		return -1;
	return inb(COM1+COM_RX);
f0100330:	0f b6 c0             	movzbl %al,%eax
f0100333:	eb 05                	jmp    f010033a <serial_proc_data+0x1a>

static int
serial_proc_data(void)
{
	if (!(inb(COM1+COM_LSR) & COM_LSR_DATA))
		return -1;
f0100335:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	return inb(COM1+COM_RX);
}
f010033a:	5d                   	pop    %ebp
f010033b:	c3                   	ret    

f010033c <cons_intr>:

// called by device interrupt routines to feed input characters
// into the circular console input buffer.
static void
cons_intr(int (*proc)(void))
{
f010033c:	55                   	push   %ebp
f010033d:	89 e5                	mov    %esp,%ebp
f010033f:	53                   	push   %ebx
f0100340:	83 ec 04             	sub    $0x4,%esp
f0100343:	89 c3                	mov    %eax,%ebx
	int c;

	while ((c = (*proc)()) != -1) {
f0100345:	eb 2a                	jmp    f0100371 <cons_intr+0x35>
		if (c == 0)
f0100347:	85 d2                	test   %edx,%edx
f0100349:	74 26                	je     f0100371 <cons_intr+0x35>
			continue;
		cons.buf[cons.wpos++] = c;
f010034b:	a1 24 c2 1c f0       	mov    0xf01cc224,%eax
f0100350:	8d 48 01             	lea    0x1(%eax),%ecx
f0100353:	89 0d 24 c2 1c f0    	mov    %ecx,0xf01cc224
f0100359:	88 90 20 c0 1c f0    	mov    %dl,-0xfe33fe0(%eax)
		if (cons.wpos == CONSBUFSIZE)
f010035f:	81 f9 00 02 00 00    	cmp    $0x200,%ecx
f0100365:	75 0a                	jne    f0100371 <cons_intr+0x35>
			cons.wpos = 0;
f0100367:	c7 05 24 c2 1c f0 00 	movl   $0x0,0xf01cc224
f010036e:	00 00 00 
static void
cons_intr(int (*proc)(void))
{
	int c;

	while ((c = (*proc)()) != -1) {
f0100371:	ff d3                	call   *%ebx
f0100373:	89 c2                	mov    %eax,%edx
f0100375:	83 f8 ff             	cmp    $0xffffffff,%eax
f0100378:	75 cd                	jne    f0100347 <cons_intr+0xb>
			continue;
		cons.buf[cons.wpos++] = c;
		if (cons.wpos == CONSBUFSIZE)
			cons.wpos = 0;
	}
}
f010037a:	83 c4 04             	add    $0x4,%esp
f010037d:	5b                   	pop    %ebx
f010037e:	5d                   	pop    %ebp
f010037f:	c3                   	ret    

f0100380 <kbd_proc_data>:
f0100380:	ba 64 00 00 00       	mov    $0x64,%edx
f0100385:	ec                   	in     (%dx),%al
{
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
f0100386:	a8 01                	test   $0x1,%al
f0100388:	0f 84 ef 00 00 00    	je     f010047d <kbd_proc_data+0xfd>
f010038e:	b2 60                	mov    $0x60,%dl
f0100390:	ec                   	in     (%dx),%al
f0100391:	89 c2                	mov    %eax,%edx
		return -1;

	data = inb(KBDATAP);

	if (data == 0xE0) {
f0100393:	3c e0                	cmp    $0xe0,%al
f0100395:	75 0d                	jne    f01003a4 <kbd_proc_data+0x24>
		// E0 escape character
		shift |= E0ESC;
f0100397:	83 0d 00 c0 1c f0 40 	orl    $0x40,0xf01cc000
		return 0;
f010039e:	b8 00 00 00 00       	mov    $0x0,%eax
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f01003a3:	c3                   	ret    
 * Get data from the keyboard.  If we finish a character, return it.  Else 0.
 * Return -1 if no data.
 */
static int
kbd_proc_data(void)
{
f01003a4:	55                   	push   %ebp
f01003a5:	89 e5                	mov    %esp,%ebp
f01003a7:	53                   	push   %ebx
f01003a8:	83 ec 14             	sub    $0x14,%esp

	if (data == 0xE0) {
		// E0 escape character
		shift |= E0ESC;
		return 0;
	} else if (data & 0x80) {
f01003ab:	84 c0                	test   %al,%al
f01003ad:	79 37                	jns    f01003e6 <kbd_proc_data+0x66>
		// Key released
		data = (shift & E0ESC ? data : data & 0x7F);
f01003af:	8b 0d 00 c0 1c f0    	mov    0xf01cc000,%ecx
f01003b5:	89 cb                	mov    %ecx,%ebx
f01003b7:	83 e3 40             	and    $0x40,%ebx
f01003ba:	83 e0 7f             	and    $0x7f,%eax
f01003bd:	85 db                	test   %ebx,%ebx
f01003bf:	0f 44 d0             	cmove  %eax,%edx
		shift &= ~(shiftcode[data] | E0ESC);
f01003c2:	0f b6 d2             	movzbl %dl,%edx
f01003c5:	0f b6 82 c0 6d 10 f0 	movzbl -0xfef9240(%edx),%eax
f01003cc:	83 c8 40             	or     $0x40,%eax
f01003cf:	0f b6 c0             	movzbl %al,%eax
f01003d2:	f7 d0                	not    %eax
f01003d4:	21 c1                	and    %eax,%ecx
f01003d6:	89 0d 00 c0 1c f0    	mov    %ecx,0xf01cc000
		return 0;
f01003dc:	b8 00 00 00 00       	mov    $0x0,%eax
f01003e1:	e9 9d 00 00 00       	jmp    f0100483 <kbd_proc_data+0x103>
	} else if (shift & E0ESC) {
f01003e6:	8b 0d 00 c0 1c f0    	mov    0xf01cc000,%ecx
f01003ec:	f6 c1 40             	test   $0x40,%cl
f01003ef:	74 0e                	je     f01003ff <kbd_proc_data+0x7f>
		// Last character was an E0 escape; or with 0x80
		data |= 0x80;
f01003f1:	83 c8 80             	or     $0xffffff80,%eax
f01003f4:	89 c2                	mov    %eax,%edx
		shift &= ~E0ESC;
f01003f6:	83 e1 bf             	and    $0xffffffbf,%ecx
f01003f9:	89 0d 00 c0 1c f0    	mov    %ecx,0xf01cc000
	}

	shift |= shiftcode[data];
f01003ff:	0f b6 d2             	movzbl %dl,%edx
f0100402:	0f b6 82 c0 6d 10 f0 	movzbl -0xfef9240(%edx),%eax
f0100409:	0b 05 00 c0 1c f0    	or     0xf01cc000,%eax
	shift ^= togglecode[data];
f010040f:	0f b6 8a c0 6c 10 f0 	movzbl -0xfef9340(%edx),%ecx
f0100416:	31 c8                	xor    %ecx,%eax
f0100418:	a3 00 c0 1c f0       	mov    %eax,0xf01cc000

	c = charcode[shift & (CTL | SHIFT)][data];
f010041d:	89 c1                	mov    %eax,%ecx
f010041f:	83 e1 03             	and    $0x3,%ecx
f0100422:	8b 0c 8d a0 6c 10 f0 	mov    -0xfef9360(,%ecx,4),%ecx
f0100429:	0f b6 14 11          	movzbl (%ecx,%edx,1),%edx
f010042d:	0f b6 da             	movzbl %dl,%ebx
	if (shift & CAPSLOCK) {
f0100430:	a8 08                	test   $0x8,%al
f0100432:	74 1b                	je     f010044f <kbd_proc_data+0xcf>
		if ('a' <= c && c <= 'z')
f0100434:	89 da                	mov    %ebx,%edx
f0100436:	8d 4b 9f             	lea    -0x61(%ebx),%ecx
f0100439:	83 f9 19             	cmp    $0x19,%ecx
f010043c:	77 05                	ja     f0100443 <kbd_proc_data+0xc3>
			c += 'A' - 'a';
f010043e:	83 eb 20             	sub    $0x20,%ebx
f0100441:	eb 0c                	jmp    f010044f <kbd_proc_data+0xcf>
		else if ('A' <= c && c <= 'Z')
f0100443:	83 ea 41             	sub    $0x41,%edx
			c += 'a' - 'A';
f0100446:	8d 4b 20             	lea    0x20(%ebx),%ecx
f0100449:	83 fa 19             	cmp    $0x19,%edx
f010044c:	0f 46 d9             	cmovbe %ecx,%ebx
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f010044f:	f7 d0                	not    %eax
f0100451:	89 c2                	mov    %eax,%edx
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100453:	89 d8                	mov    %ebx,%eax
			c += 'a' - 'A';
	}

	// Process special keys
	// Ctrl-Alt-Del: reboot
	if (!(~shift & (CTL | ALT)) && c == KEY_DEL) {
f0100455:	f6 c2 06             	test   $0x6,%dl
f0100458:	75 29                	jne    f0100483 <kbd_proc_data+0x103>
f010045a:	81 fb e9 00 00 00    	cmp    $0xe9,%ebx
f0100460:	75 21                	jne    f0100483 <kbd_proc_data+0x103>
		cprintf("Rebooting!\n");
f0100462:	c7 04 24 63 6c 10 f0 	movl   $0xf0106c63,(%esp)
f0100469:	e8 01 38 00 00       	call   f0103c6f <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010046e:	ba 92 00 00 00       	mov    $0x92,%edx
f0100473:	b8 03 00 00 00       	mov    $0x3,%eax
f0100478:	ee                   	out    %al,(%dx)
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
f0100479:	89 d8                	mov    %ebx,%eax
f010047b:	eb 06                	jmp    f0100483 <kbd_proc_data+0x103>
	int c;
	uint8_t data;
	static uint32_t shift;

	if ((inb(KBSTATP) & KBS_DIB) == 0)
		return -1;
f010047d:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0100482:	c3                   	ret    
		cprintf("Rebooting!\n");
		outb(0x92, 0x3); // courtesy of Chris Frost
	}

	return c;
}
f0100483:	83 c4 14             	add    $0x14,%esp
f0100486:	5b                   	pop    %ebx
f0100487:	5d                   	pop    %ebp
f0100488:	c3                   	ret    

f0100489 <cons_putc>:
}

// output a character to the console
static void
cons_putc(int c)
{
f0100489:	55                   	push   %ebp
f010048a:	89 e5                	mov    %esp,%ebp
f010048c:	57                   	push   %edi
f010048d:	56                   	push   %esi
f010048e:	53                   	push   %ebx
f010048f:	83 ec 1c             	sub    $0x1c,%esp
f0100492:	89 c7                	mov    %eax,%edi

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0100494:	ba fd 03 00 00       	mov    $0x3fd,%edx
f0100499:	ec                   	in     (%dx),%al
static void
serial_putc(int c)
{
	int i;
	
	for (i = 0;
f010049a:	a8 20                	test   $0x20,%al
f010049c:	75 21                	jne    f01004bf <cons_putc+0x36>
f010049e:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004a3:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004a8:	be fd 03 00 00       	mov    $0x3fd,%esi
f01004ad:	89 ca                	mov    %ecx,%edx
f01004af:	ec                   	in     (%dx),%al
f01004b0:	ec                   	in     (%dx),%al
f01004b1:	ec                   	in     (%dx),%al
f01004b2:	ec                   	in     (%dx),%al
f01004b3:	89 f2                	mov    %esi,%edx
f01004b5:	ec                   	in     (%dx),%al
f01004b6:	a8 20                	test   $0x20,%al
f01004b8:	75 05                	jne    f01004bf <cons_putc+0x36>
	     !(inb(COM1 + COM_LSR) & COM_LSR_TXRDY) && i < 12800;
f01004ba:	83 eb 01             	sub    $0x1,%ebx
f01004bd:	75 ee                	jne    f01004ad <cons_putc+0x24>
	     i++)
		delay();
	
	outb(COM1 + COM_TX, c);
f01004bf:	89 f8                	mov    %edi,%eax
f01004c1:	0f b6 c0             	movzbl %al,%eax
f01004c4:	89 45 e4             	mov    %eax,-0x1c(%ebp)
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004c7:	ba f8 03 00 00       	mov    $0x3f8,%edx
f01004cc:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01004cd:	b2 79                	mov    $0x79,%dl
f01004cf:	ec                   	in     (%dx),%al
static void
lpt_putc(int c)
{
	int i;

	for (i = 0; !(inb(0x378+1) & 0x80) && i < 12800; i++)
f01004d0:	84 c0                	test   %al,%al
f01004d2:	78 21                	js     f01004f5 <cons_putc+0x6c>
f01004d4:	bb 00 32 00 00       	mov    $0x3200,%ebx
f01004d9:	b9 84 00 00 00       	mov    $0x84,%ecx
f01004de:	be 79 03 00 00       	mov    $0x379,%esi
f01004e3:	89 ca                	mov    %ecx,%edx
f01004e5:	ec                   	in     (%dx),%al
f01004e6:	ec                   	in     (%dx),%al
f01004e7:	ec                   	in     (%dx),%al
f01004e8:	ec                   	in     (%dx),%al
f01004e9:	89 f2                	mov    %esi,%edx
f01004eb:	ec                   	in     (%dx),%al
f01004ec:	84 c0                	test   %al,%al
f01004ee:	78 05                	js     f01004f5 <cons_putc+0x6c>
f01004f0:	83 eb 01             	sub    $0x1,%ebx
f01004f3:	75 ee                	jne    f01004e3 <cons_putc+0x5a>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f01004f5:	ba 78 03 00 00       	mov    $0x378,%edx
f01004fa:	0f b6 45 e4          	movzbl -0x1c(%ebp),%eax
f01004fe:	ee                   	out    %al,(%dx)
f01004ff:	b2 7a                	mov    $0x7a,%dl
f0100501:	b8 0d 00 00 00       	mov    $0xd,%eax
f0100506:	ee                   	out    %al,(%dx)
f0100507:	b8 08 00 00 00       	mov    $0x8,%eax
f010050c:	ee                   	out    %al,(%dx)

static void
cga_putc(int c)
{
	// if no attribute given, then use black on white
	if (!(c & ~0xFF))
f010050d:	89 fa                	mov    %edi,%edx
f010050f:	81 e2 00 ff ff ff    	and    $0xffffff00,%edx
		c |= 0x0700;
f0100515:	89 f8                	mov    %edi,%eax
f0100517:	80 cc 07             	or     $0x7,%ah
f010051a:	85 d2                	test   %edx,%edx
f010051c:	0f 44 f8             	cmove  %eax,%edi

	switch (c & 0xff) {
f010051f:	89 f8                	mov    %edi,%eax
f0100521:	0f b6 c0             	movzbl %al,%eax
f0100524:	83 f8 09             	cmp    $0x9,%eax
f0100527:	74 79                	je     f01005a2 <cons_putc+0x119>
f0100529:	83 f8 09             	cmp    $0x9,%eax
f010052c:	7f 0a                	jg     f0100538 <cons_putc+0xaf>
f010052e:	83 f8 08             	cmp    $0x8,%eax
f0100531:	74 19                	je     f010054c <cons_putc+0xc3>
f0100533:	e9 9e 00 00 00       	jmp    f01005d6 <cons_putc+0x14d>
f0100538:	83 f8 0a             	cmp    $0xa,%eax
f010053b:	90                   	nop
f010053c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0100540:	74 3a                	je     f010057c <cons_putc+0xf3>
f0100542:	83 f8 0d             	cmp    $0xd,%eax
f0100545:	74 3d                	je     f0100584 <cons_putc+0xfb>
f0100547:	e9 8a 00 00 00       	jmp    f01005d6 <cons_putc+0x14d>
	case '\b':
		if (crt_pos > 0) {
f010054c:	0f b7 05 28 c2 1c f0 	movzwl 0xf01cc228,%eax
f0100553:	66 85 c0             	test   %ax,%ax
f0100556:	0f 84 e5 00 00 00    	je     f0100641 <cons_putc+0x1b8>
			crt_pos--;
f010055c:	83 e8 01             	sub    $0x1,%eax
f010055f:	66 a3 28 c2 1c f0    	mov    %ax,0xf01cc228
			crt_buf[crt_pos] = (c & ~0xff) | ' ';
f0100565:	0f b7 c0             	movzwl %ax,%eax
f0100568:	66 81 e7 00 ff       	and    $0xff00,%di
f010056d:	83 cf 20             	or     $0x20,%edi
f0100570:	8b 15 2c c2 1c f0    	mov    0xf01cc22c,%edx
f0100576:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
f010057a:	eb 78                	jmp    f01005f4 <cons_putc+0x16b>
		}
		break;
	case '\n':
		crt_pos += CRT_COLS;
f010057c:	66 83 05 28 c2 1c f0 	addw   $0x50,0xf01cc228
f0100583:	50 
		/* fallthru */
	case '\r':
		crt_pos -= (crt_pos % CRT_COLS);
f0100584:	0f b7 05 28 c2 1c f0 	movzwl 0xf01cc228,%eax
f010058b:	69 c0 cd cc 00 00    	imul   $0xcccd,%eax,%eax
f0100591:	c1 e8 16             	shr    $0x16,%eax
f0100594:	8d 04 80             	lea    (%eax,%eax,4),%eax
f0100597:	c1 e0 04             	shl    $0x4,%eax
f010059a:	66 a3 28 c2 1c f0    	mov    %ax,0xf01cc228
f01005a0:	eb 52                	jmp    f01005f4 <cons_putc+0x16b>
		break;
	case '\t':
		cons_putc(' ');
f01005a2:	b8 20 00 00 00       	mov    $0x20,%eax
f01005a7:	e8 dd fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005ac:	b8 20 00 00 00       	mov    $0x20,%eax
f01005b1:	e8 d3 fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005b6:	b8 20 00 00 00       	mov    $0x20,%eax
f01005bb:	e8 c9 fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005c0:	b8 20 00 00 00       	mov    $0x20,%eax
f01005c5:	e8 bf fe ff ff       	call   f0100489 <cons_putc>
		cons_putc(' ');
f01005ca:	b8 20 00 00 00       	mov    $0x20,%eax
f01005cf:	e8 b5 fe ff ff       	call   f0100489 <cons_putc>
f01005d4:	eb 1e                	jmp    f01005f4 <cons_putc+0x16b>
		break;
	default:
		crt_buf[crt_pos++] = c;		/* write the character */
f01005d6:	0f b7 05 28 c2 1c f0 	movzwl 0xf01cc228,%eax
f01005dd:	8d 50 01             	lea    0x1(%eax),%edx
f01005e0:	66 89 15 28 c2 1c f0 	mov    %dx,0xf01cc228
f01005e7:	0f b7 c0             	movzwl %ax,%eax
f01005ea:	8b 15 2c c2 1c f0    	mov    0xf01cc22c,%edx
f01005f0:	66 89 3c 42          	mov    %di,(%edx,%eax,2)
		break;
	}

	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
f01005f4:	66 81 3d 28 c2 1c f0 	cmpw   $0x7cf,0xf01cc228
f01005fb:	cf 07 
f01005fd:	76 42                	jbe    f0100641 <cons_putc+0x1b8>
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
f01005ff:	a1 2c c2 1c f0       	mov    0xf01cc22c,%eax
f0100604:	c7 44 24 08 00 0f 00 	movl   $0xf00,0x8(%esp)
f010060b:	00 
f010060c:	8d 90 a0 00 00 00    	lea    0xa0(%eax),%edx
f0100612:	89 54 24 04          	mov    %edx,0x4(%esp)
f0100616:	89 04 24             	mov    %eax,(%esp)
f0100619:	e8 28 58 00 00       	call   f0105e46 <memmove>
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
			crt_buf[i] = 0x0700 | ' ';
f010061e:	8b 15 2c c2 1c f0    	mov    0xf01cc22c,%edx
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f0100624:	b8 80 07 00 00       	mov    $0x780,%eax
			crt_buf[i] = 0x0700 | ' ';
f0100629:	66 c7 04 42 20 07    	movw   $0x720,(%edx,%eax,2)
	// What is the purpose of this?
	if (crt_pos >= CRT_SIZE) {
		int i;

		memmove(crt_buf, crt_buf + CRT_COLS, (CRT_SIZE - CRT_COLS) * sizeof(uint16_t));
		for (i = CRT_SIZE - CRT_COLS; i < CRT_SIZE; i++)
f010062f:	83 c0 01             	add    $0x1,%eax
f0100632:	3d d0 07 00 00       	cmp    $0x7d0,%eax
f0100637:	75 f0                	jne    f0100629 <cons_putc+0x1a0>
			crt_buf[i] = 0x0700 | ' ';
		crt_pos -= CRT_COLS;
f0100639:	66 83 2d 28 c2 1c f0 	subw   $0x50,0xf01cc228
f0100640:	50 
	}

	/* move that little blinky thing */
	outb(addr_6845, 14);
f0100641:	8b 0d 30 c2 1c f0    	mov    0xf01cc230,%ecx
f0100647:	b8 0e 00 00 00       	mov    $0xe,%eax
f010064c:	89 ca                	mov    %ecx,%edx
f010064e:	ee                   	out    %al,(%dx)
	outb(addr_6845 + 1, crt_pos >> 8);
f010064f:	0f b7 1d 28 c2 1c f0 	movzwl 0xf01cc228,%ebx
f0100656:	8d 71 01             	lea    0x1(%ecx),%esi
f0100659:	89 d8                	mov    %ebx,%eax
f010065b:	66 c1 e8 08          	shr    $0x8,%ax
f010065f:	89 f2                	mov    %esi,%edx
f0100661:	ee                   	out    %al,(%dx)
f0100662:	b8 0f 00 00 00       	mov    $0xf,%eax
f0100667:	89 ca                	mov    %ecx,%edx
f0100669:	ee                   	out    %al,(%dx)
f010066a:	89 d8                	mov    %ebx,%eax
f010066c:	89 f2                	mov    %esi,%edx
f010066e:	ee                   	out    %al,(%dx)
cons_putc(int c)
{
	serial_putc(c);
	lpt_putc(c);
	cga_putc(c);
}
f010066f:	83 c4 1c             	add    $0x1c,%esp
f0100672:	5b                   	pop    %ebx
f0100673:	5e                   	pop    %esi
f0100674:	5f                   	pop    %edi
f0100675:	5d                   	pop    %ebp
f0100676:	c3                   	ret    

f0100677 <serial_intr>:
}

void
serial_intr(void)
{
	if (serial_exists)
f0100677:	83 3d 34 c2 1c f0 00 	cmpl   $0x0,0xf01cc234
f010067e:	74 11                	je     f0100691 <serial_intr+0x1a>
	return inb(COM1+COM_RX);
}

void
serial_intr(void)
{
f0100680:	55                   	push   %ebp
f0100681:	89 e5                	mov    %esp,%ebp
f0100683:	83 ec 08             	sub    $0x8,%esp
	if (serial_exists)
		cons_intr(serial_proc_data);
f0100686:	b8 20 03 10 f0       	mov    $0xf0100320,%eax
f010068b:	e8 ac fc ff ff       	call   f010033c <cons_intr>
}
f0100690:	c9                   	leave  
f0100691:	f3 c3                	repz ret 

f0100693 <kbd_intr>:
	return c;
}

void
kbd_intr(void)
{
f0100693:	55                   	push   %ebp
f0100694:	89 e5                	mov    %esp,%ebp
f0100696:	83 ec 08             	sub    $0x8,%esp
	cons_intr(kbd_proc_data);
f0100699:	b8 80 03 10 f0       	mov    $0xf0100380,%eax
f010069e:	e8 99 fc ff ff       	call   f010033c <cons_intr>
}
f01006a3:	c9                   	leave  
f01006a4:	c3                   	ret    

f01006a5 <cons_getc>:
}

// return the next input character from the console, or 0 if none waiting
int
cons_getc(void)
{
f01006a5:	55                   	push   %ebp
f01006a6:	89 e5                	mov    %esp,%ebp
f01006a8:	83 ec 08             	sub    $0x8,%esp
	int c;

	// poll for any pending input characters,
	// so that this function works even when interrupts are disabled
	// (e.g., when called from the kernel monitor).
	serial_intr();
f01006ab:	e8 c7 ff ff ff       	call   f0100677 <serial_intr>
	kbd_intr();
f01006b0:	e8 de ff ff ff       	call   f0100693 <kbd_intr>

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
f01006b5:	a1 20 c2 1c f0       	mov    0xf01cc220,%eax
f01006ba:	3b 05 24 c2 1c f0    	cmp    0xf01cc224,%eax
f01006c0:	74 26                	je     f01006e8 <cons_getc+0x43>
		c = cons.buf[cons.rpos++];
f01006c2:	8d 50 01             	lea    0x1(%eax),%edx
f01006c5:	89 15 20 c2 1c f0    	mov    %edx,0xf01cc220
f01006cb:	0f b6 88 20 c0 1c f0 	movzbl -0xfe33fe0(%eax),%ecx
		if (cons.rpos == CONSBUFSIZE)
			cons.rpos = 0;
		return c;
f01006d2:	89 c8                	mov    %ecx,%eax
	kbd_intr();

	// grab the next character from the input buffer.
	if (cons.rpos != cons.wpos) {
		c = cons.buf[cons.rpos++];
		if (cons.rpos == CONSBUFSIZE)
f01006d4:	81 fa 00 02 00 00    	cmp    $0x200,%edx
f01006da:	75 11                	jne    f01006ed <cons_getc+0x48>
			cons.rpos = 0;
f01006dc:	c7 05 20 c2 1c f0 00 	movl   $0x0,0xf01cc220
f01006e3:	00 00 00 
f01006e6:	eb 05                	jmp    f01006ed <cons_getc+0x48>
		return c;
	}
	return 0;
f01006e8:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01006ed:	c9                   	leave  
f01006ee:	c3                   	ret    

f01006ef <cons_init>:
}

// initialize the console devices
void
cons_init(void)
{
f01006ef:	55                   	push   %ebp
f01006f0:	89 e5                	mov    %esp,%ebp
f01006f2:	57                   	push   %edi
f01006f3:	56                   	push   %esi
f01006f4:	53                   	push   %ebx
f01006f5:	83 ec 1c             	sub    $0x1c,%esp
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
f01006f8:	0f b7 15 00 80 0b f0 	movzwl 0xf00b8000,%edx
	*cp = (uint16_t) 0xA55A;
f01006ff:	66 c7 05 00 80 0b f0 	movw   $0xa55a,0xf00b8000
f0100706:	5a a5 
	if (*cp != 0xA55A) {
f0100708:	0f b7 05 00 80 0b f0 	movzwl 0xf00b8000,%eax
f010070f:	66 3d 5a a5          	cmp    $0xa55a,%ax
f0100713:	74 11                	je     f0100726 <cons_init+0x37>
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
		addr_6845 = MONO_BASE;
f0100715:	c7 05 30 c2 1c f0 b4 	movl   $0x3b4,0xf01cc230
f010071c:	03 00 00 

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
	was = *cp;
	*cp = (uint16_t) 0xA55A;
	if (*cp != 0xA55A) {
		cp = (uint16_t*) (KERNBASE + MONO_BUF);
f010071f:	bf 00 00 0b f0       	mov    $0xf00b0000,%edi
f0100724:	eb 16                	jmp    f010073c <cons_init+0x4d>
		addr_6845 = MONO_BASE;
	} else {
		*cp = was;
f0100726:	66 89 15 00 80 0b f0 	mov    %dx,0xf00b8000
		addr_6845 = CGA_BASE;
f010072d:	c7 05 30 c2 1c f0 d4 	movl   $0x3d4,0xf01cc230
f0100734:	03 00 00 
{
	volatile uint16_t *cp;
	uint16_t was;
	unsigned pos;

	cp = (uint16_t*) (KERNBASE + CGA_BUF);
f0100737:	bf 00 80 0b f0       	mov    $0xf00b8000,%edi
		*cp = was;
		addr_6845 = CGA_BASE;
	}
	
	/* Extract cursor location */
	outb(addr_6845, 14);
f010073c:	8b 0d 30 c2 1c f0    	mov    0xf01cc230,%ecx
f0100742:	b8 0e 00 00 00       	mov    $0xe,%eax
f0100747:	89 ca                	mov    %ecx,%edx
f0100749:	ee                   	out    %al,(%dx)
	pos = inb(addr_6845 + 1) << 8;
f010074a:	8d 59 01             	lea    0x1(%ecx),%ebx

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010074d:	89 da                	mov    %ebx,%edx
f010074f:	ec                   	in     (%dx),%al
f0100750:	0f b6 f0             	movzbl %al,%esi
f0100753:	c1 e6 08             	shl    $0x8,%esi
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0100756:	b8 0f 00 00 00       	mov    $0xf,%eax
f010075b:	89 ca                	mov    %ecx,%edx
f010075d:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010075e:	89 da                	mov    %ebx,%edx
f0100760:	ec                   	in     (%dx),%al
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);

	crt_buf = (uint16_t*) cp;
f0100761:	89 3d 2c c2 1c f0    	mov    %edi,0xf01cc22c
	
	/* Extract cursor location */
	outb(addr_6845, 14);
	pos = inb(addr_6845 + 1) << 8;
	outb(addr_6845, 15);
	pos |= inb(addr_6845 + 1);
f0100767:	0f b6 d8             	movzbl %al,%ebx
f010076a:	09 de                	or     %ebx,%esi

	crt_buf = (uint16_t*) cp;
	crt_pos = pos;
f010076c:	66 89 35 28 c2 1c f0 	mov    %si,0xf01cc228

static void
kbd_init(void)
{
	// Drain the kbd buffer so that Bochs generates interrupts.
	kbd_intr();
f0100773:	e8 1b ff ff ff       	call   f0100693 <kbd_intr>
	irq_setmask_8259A(irq_mask_8259A & ~(1<<1));
f0100778:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f010077f:	25 fd ff 00 00       	and    $0xfffd,%eax
f0100784:	89 04 24             	mov    %eax,(%esp)
f0100787:	e8 a1 33 00 00       	call   f0103b2d <irq_setmask_8259A>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f010078c:	be fa 03 00 00       	mov    $0x3fa,%esi
f0100791:	b8 00 00 00 00       	mov    $0x0,%eax
f0100796:	89 f2                	mov    %esi,%edx
f0100798:	ee                   	out    %al,(%dx)
f0100799:	b2 fb                	mov    $0xfb,%dl
f010079b:	b8 80 ff ff ff       	mov    $0xffffff80,%eax
f01007a0:	ee                   	out    %al,(%dx)
f01007a1:	bb f8 03 00 00       	mov    $0x3f8,%ebx
f01007a6:	b8 0c 00 00 00       	mov    $0xc,%eax
f01007ab:	89 da                	mov    %ebx,%edx
f01007ad:	ee                   	out    %al,(%dx)
f01007ae:	b2 f9                	mov    $0xf9,%dl
f01007b0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007b5:	ee                   	out    %al,(%dx)
f01007b6:	b2 fb                	mov    $0xfb,%dl
f01007b8:	b8 03 00 00 00       	mov    $0x3,%eax
f01007bd:	ee                   	out    %al,(%dx)
f01007be:	b2 fc                	mov    $0xfc,%dl
f01007c0:	b8 00 00 00 00       	mov    $0x0,%eax
f01007c5:	ee                   	out    %al,(%dx)
f01007c6:	b2 f9                	mov    $0xf9,%dl
f01007c8:	b8 01 00 00 00       	mov    $0x1,%eax
f01007cd:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f01007ce:	b2 fd                	mov    $0xfd,%dl
f01007d0:	ec                   	in     (%dx),%al
	// Enable rcv interrupts
	outb(COM1+COM_IER, COM_IER_RDI);

	// Clear any preexisting overrun indications and interrupts
	// Serial port doesn't exist if COM_LSR returns 0xFF
	serial_exists = (inb(COM1+COM_LSR) != 0xFF);
f01007d1:	3c ff                	cmp    $0xff,%al
f01007d3:	0f 95 c1             	setne  %cl
f01007d6:	0f b6 c9             	movzbl %cl,%ecx
f01007d9:	89 0d 34 c2 1c f0    	mov    %ecx,0xf01cc234
f01007df:	89 f2                	mov    %esi,%edx
f01007e1:	ec                   	in     (%dx),%al
f01007e2:	89 da                	mov    %ebx,%edx
f01007e4:	ec                   	in     (%dx),%al
{
	cga_init();
	kbd_init();
	serial_init();

	if (!serial_exists)
f01007e5:	85 c9                	test   %ecx,%ecx
f01007e7:	75 0c                	jne    f01007f5 <cons_init+0x106>
		cprintf("Serial port does not exist!\n");
f01007e9:	c7 04 24 6f 6c 10 f0 	movl   $0xf0106c6f,(%esp)
f01007f0:	e8 7a 34 00 00       	call   f0103c6f <cprintf>
}
f01007f5:	83 c4 1c             	add    $0x1c,%esp
f01007f8:	5b                   	pop    %ebx
f01007f9:	5e                   	pop    %esi
f01007fa:	5f                   	pop    %edi
f01007fb:	5d                   	pop    %ebp
f01007fc:	c3                   	ret    

f01007fd <cputchar>:

// `High'-level console I/O.  Used by readline and cprintf.

void
cputchar(int c)
{
f01007fd:	55                   	push   %ebp
f01007fe:	89 e5                	mov    %esp,%ebp
f0100800:	83 ec 08             	sub    $0x8,%esp
	cons_putc(c);
f0100803:	8b 45 08             	mov    0x8(%ebp),%eax
f0100806:	e8 7e fc ff ff       	call   f0100489 <cons_putc>
}
f010080b:	c9                   	leave  
f010080c:	c3                   	ret    

f010080d <getchar>:

int
getchar(void)
{
f010080d:	55                   	push   %ebp
f010080e:	89 e5                	mov    %esp,%ebp
f0100810:	83 ec 08             	sub    $0x8,%esp
	int c;

	while ((c = cons_getc()) == 0)
f0100813:	e8 8d fe ff ff       	call   f01006a5 <cons_getc>
f0100818:	85 c0                	test   %eax,%eax
f010081a:	74 f7                	je     f0100813 <getchar+0x6>
		/* do nothing */;
	return c;
}
f010081c:	c9                   	leave  
f010081d:	c3                   	ret    

f010081e <iscons>:

int
iscons(int fdnum)
{
f010081e:	55                   	push   %ebp
f010081f:	89 e5                	mov    %esp,%ebp
	// used by readline
	return 1;
}
f0100821:	b8 01 00 00 00       	mov    $0x1,%eax
f0100826:	5d                   	pop    %ebp
f0100827:	c3                   	ret    
f0100828:	66 90                	xchg   %ax,%ax
f010082a:	66 90                	xchg   %ax,%ax
f010082c:	66 90                	xchg   %ax,%ax
f010082e:	66 90                	xchg   %ax,%ax

f0100830 <mon_help>:

/***** Implementations of basic kernel monitor commands *****/

int
mon_help(int argc, char **argv, struct Trapframe *tf)
{
f0100830:	55                   	push   %ebp
f0100831:	89 e5                	mov    %esp,%ebp
f0100833:	83 ec 18             	sub    $0x18,%esp
	int i;

	for (i = 0; i < NCOMMANDS; i++)
		cprintf("%s - %s\n", commands[i].name, commands[i].desc);
f0100836:	c7 44 24 08 c0 6e 10 	movl   $0xf0106ec0,0x8(%esp)
f010083d:	f0 
f010083e:	c7 44 24 04 de 6e 10 	movl   $0xf0106ede,0x4(%esp)
f0100845:	f0 
f0100846:	c7 04 24 e3 6e 10 f0 	movl   $0xf0106ee3,(%esp)
f010084d:	e8 1d 34 00 00       	call   f0103c6f <cprintf>
f0100852:	c7 44 24 08 88 6f 10 	movl   $0xf0106f88,0x8(%esp)
f0100859:	f0 
f010085a:	c7 44 24 04 ec 6e 10 	movl   $0xf0106eec,0x4(%esp)
f0100861:	f0 
f0100862:	c7 04 24 e3 6e 10 f0 	movl   $0xf0106ee3,(%esp)
f0100869:	e8 01 34 00 00       	call   f0103c6f <cprintf>
f010086e:	c7 44 24 08 f5 6e 10 	movl   $0xf0106ef5,0x8(%esp)
f0100875:	f0 
f0100876:	c7 44 24 04 13 6f 10 	movl   $0xf0106f13,0x4(%esp)
f010087d:	f0 
f010087e:	c7 04 24 e3 6e 10 f0 	movl   $0xf0106ee3,(%esp)
f0100885:	e8 e5 33 00 00       	call   f0103c6f <cprintf>
	return 0;
}
f010088a:	b8 00 00 00 00       	mov    $0x0,%eax
f010088f:	c9                   	leave  
f0100890:	c3                   	ret    

f0100891 <mon_kerninfo>:

int
mon_kerninfo(int argc, char **argv, struct Trapframe *tf)
{
f0100891:	55                   	push   %ebp
f0100892:	89 e5                	mov    %esp,%ebp
f0100894:	83 ec 18             	sub    $0x18,%esp
	extern char entry[], etext[], edata[], end[];

	cprintf("Special kernel symbols:\n");
f0100897:	c7 04 24 21 6f 10 f0 	movl   $0xf0106f21,(%esp)
f010089e:	e8 cc 33 00 00       	call   f0103c6f <cprintf>
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
f01008a3:	c7 44 24 08 0c 00 10 	movl   $0x10000c,0x8(%esp)
f01008aa:	00 
f01008ab:	c7 44 24 04 0c 00 10 	movl   $0xf010000c,0x4(%esp)
f01008b2:	f0 
f01008b3:	c7 04 24 b0 6f 10 f0 	movl   $0xf0106fb0,(%esp)
f01008ba:	e8 b0 33 00 00       	call   f0103c6f <cprintf>
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
f01008bf:	c7 44 24 08 87 6b 10 	movl   $0x106b87,0x8(%esp)
f01008c6:	00 
f01008c7:	c7 44 24 04 87 6b 10 	movl   $0xf0106b87,0x4(%esp)
f01008ce:	f0 
f01008cf:	c7 04 24 d4 6f 10 f0 	movl   $0xf0106fd4,(%esp)
f01008d6:	e8 94 33 00 00       	call   f0103c6f <cprintf>
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
f01008db:	c7 44 24 08 bb be 1c 	movl   $0x1cbebb,0x8(%esp)
f01008e2:	00 
f01008e3:	c7 44 24 04 bb be 1c 	movl   $0xf01cbebb,0x4(%esp)
f01008ea:	f0 
f01008eb:	c7 04 24 f8 6f 10 f0 	movl   $0xf0106ff8,(%esp)
f01008f2:	e8 78 33 00 00       	call   f0103c6f <cprintf>
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
f01008f7:	c7 44 24 08 04 e0 20 	movl   $0x20e004,0x8(%esp)
f01008fe:	00 
f01008ff:	c7 44 24 04 04 e0 20 	movl   $0xf020e004,0x4(%esp)
f0100906:	f0 
f0100907:	c7 04 24 1c 70 10 f0 	movl   $0xf010701c,(%esp)
f010090e:	e8 5c 33 00 00       	call   f0103c6f <cprintf>
	cprintf("Kernel executable memory footprint: %dKB\n",
		(end-entry+1023)/1024);
f0100913:	b8 03 e4 20 f0       	mov    $0xf020e403,%eax
f0100918:	2d 0c 00 10 f0       	sub    $0xf010000c,%eax
	cprintf("Special kernel symbols:\n");
	cprintf("  entry  %08x (virt)  %08x (phys)\n", entry, entry - KERNBASE);
	cprintf("  etext  %08x (virt)  %08x (phys)\n", etext, etext - KERNBASE);
	cprintf("  edata  %08x (virt)  %08x (phys)\n", edata, edata - KERNBASE);
	cprintf("  end    %08x (virt)  %08x (phys)\n", end, end - KERNBASE);
	cprintf("Kernel executable memory footprint: %dKB\n",
f010091d:	8d 90 ff 03 00 00    	lea    0x3ff(%eax),%edx
f0100923:	85 c0                	test   %eax,%eax
f0100925:	0f 48 c2             	cmovs  %edx,%eax
f0100928:	c1 f8 0a             	sar    $0xa,%eax
f010092b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010092f:	c7 04 24 40 70 10 f0 	movl   $0xf0107040,(%esp)
f0100936:	e8 34 33 00 00       	call   f0103c6f <cprintf>
		(end-entry+1023)/1024);
	return 0;
}
f010093b:	b8 00 00 00 00       	mov    $0x0,%eax
f0100940:	c9                   	leave  
f0100941:	c3                   	ret    

f0100942 <mon_backtrace>:

int
mon_backtrace(int argc, char **argv, struct Trapframe *tf)
{
f0100942:	55                   	push   %ebp
f0100943:	89 e5                	mov    %esp,%ebp
f0100945:	53                   	push   %ebx
f0100946:	83 ec 44             	sub    $0x44,%esp

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f0100949:	89 eb                	mov    %ebp,%ebx
	unsigned int ebp;
	unsigned int eip;
	unsigned int args[5];
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
f010094b:	c7 04 24 3a 6f 10 f0 	movl   $0xf0106f3a,(%esp)
f0100952:	e8 18 33 00 00       	call   f0103c6f <cprintf>
	do{
           eip = *((unsigned int*)(ebp + 4));
f0100957:	8b 4b 04             	mov    0x4(%ebx),%ecx
           for(i=0;i<5;i++)
f010095a:	b8 00 00 00 00       	mov    $0x0,%eax
		args[i] = *((unsigned int*)(ebp+8+4*i));
f010095f:	8b 54 83 08          	mov    0x8(%ebx,%eax,4),%edx
f0100963:	89 54 85 e4          	mov    %edx,-0x1c(%ebp,%eax,4)
	unsigned int i;
     	ebp=read_ebp();
	cprintf("Stack backtrace:\n");
	do{
           eip = *((unsigned int*)(ebp + 4));
           for(i=0;i<5;i++)
f0100967:	83 c0 01             	add    $0x1,%eax
f010096a:	83 f8 05             	cmp    $0x5,%eax
f010096d:	75 f0                	jne    f010095f <mon_backtrace+0x1d>
		args[i] = *((unsigned int*)(ebp+8+4*i));
	cprintf(" ebp %08x eip %08x args %08x %08x %08x %08x %08x\n",
f010096f:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0100972:	89 44 24 1c          	mov    %eax,0x1c(%esp)
f0100976:	8b 45 f0             	mov    -0x10(%ebp),%eax
f0100979:	89 44 24 18          	mov    %eax,0x18(%esp)
f010097d:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0100980:	89 44 24 14          	mov    %eax,0x14(%esp)
f0100984:	8b 45 e8             	mov    -0x18(%ebp),%eax
f0100987:	89 44 24 10          	mov    %eax,0x10(%esp)
f010098b:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010098e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100992:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0100996:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010099a:	c7 04 24 6c 70 10 f0 	movl   $0xf010706c,(%esp)
f01009a1:	e8 c9 32 00 00       	call   f0103c6f <cprintf>
		ebp,eip,args[0],args[1],args[2],args[3],args[4]);
	ebp =*((unsigned int*)ebp);
f01009a6:	8b 1b                	mov    (%ebx),%ebx
	}while(ebp!=0);
f01009a8:	85 db                	test   %ebx,%ebx
f01009aa:	75 ab                	jne    f0100957 <mon_backtrace+0x15>
	return 0;
}
f01009ac:	b8 00 00 00 00       	mov    $0x0,%eax
f01009b1:	83 c4 44             	add    $0x44,%esp
f01009b4:	5b                   	pop    %ebx
f01009b5:	5d                   	pop    %ebp
f01009b6:	c3                   	ret    

f01009b7 <monitor>:
	return 0;
}

void
monitor(struct Trapframe *tf)
{
f01009b7:	55                   	push   %ebp
f01009b8:	89 e5                	mov    %esp,%ebp
f01009ba:	57                   	push   %edi
f01009bb:	56                   	push   %esi
f01009bc:	53                   	push   %ebx
f01009bd:	83 ec 5c             	sub    $0x5c,%esp
	char *buf;

	cprintf("Welcome to the JOS kernel monitor!\n");
f01009c0:	c7 04 24 a0 70 10 f0 	movl   $0xf01070a0,(%esp)
f01009c7:	e8 a3 32 00 00       	call   f0103c6f <cprintf>
	cprintf("Type 'help' for a list of commands.\n");
f01009cc:	c7 04 24 c4 70 10 f0 	movl   $0xf01070c4,(%esp)
f01009d3:	e8 97 32 00 00       	call   f0103c6f <cprintf>

	if (tf != NULL)
f01009d8:	83 7d 08 00          	cmpl   $0x0,0x8(%ebp)
f01009dc:	74 0b                	je     f01009e9 <monitor+0x32>
		print_trapframe(tf);
f01009de:	8b 45 08             	mov    0x8(%ebp),%eax
f01009e1:	89 04 24             	mov    %eax,(%esp)
f01009e4:	e8 9a 39 00 00       	call   f0104383 <print_trapframe>

	while (1) {
		buf = readline("K> ");
f01009e9:	c7 04 24 4c 6f 10 f0 	movl   $0xf0106f4c,(%esp)
f01009f0:	e8 2b 51 00 00       	call   f0105b20 <readline>
f01009f5:	89 c3                	mov    %eax,%ebx
		if (buf != NULL)
f01009f7:	85 c0                	test   %eax,%eax
f01009f9:	74 ee                	je     f01009e9 <monitor+0x32>
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
f01009fb:	c7 45 a8 00 00 00 00 	movl   $0x0,-0x58(%ebp)
	int argc;
	char *argv[MAXARGS];
	int i;

	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
f0100a02:	be 00 00 00 00       	mov    $0x0,%esi
f0100a07:	eb 0a                	jmp    f0100a13 <monitor+0x5c>
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
			*buf++ = 0;
f0100a09:	c6 03 00             	movb   $0x0,(%ebx)
f0100a0c:	89 f7                	mov    %esi,%edi
f0100a0e:	8d 5b 01             	lea    0x1(%ebx),%ebx
f0100a11:	89 fe                	mov    %edi,%esi
	// Parse the command buffer into whitespace-separated arguments
	argc = 0;
	argv[argc] = 0;
	while (1) {
		// gobble whitespace
		while (*buf && strchr(WHITESPACE, *buf))
f0100a13:	0f b6 03             	movzbl (%ebx),%eax
f0100a16:	84 c0                	test   %al,%al
f0100a18:	74 6a                	je     f0100a84 <monitor+0xcd>
f0100a1a:	0f be c0             	movsbl %al,%eax
f0100a1d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a21:	c7 04 24 50 6f 10 f0 	movl   $0xf0106f50,(%esp)
f0100a28:	e8 6c 53 00 00       	call   f0105d99 <strchr>
f0100a2d:	85 c0                	test   %eax,%eax
f0100a2f:	75 d8                	jne    f0100a09 <monitor+0x52>
			*buf++ = 0;
		if (*buf == 0)
f0100a31:	80 3b 00             	cmpb   $0x0,(%ebx)
f0100a34:	74 4e                	je     f0100a84 <monitor+0xcd>
			break;

		// save and scan past next arg
		if (argc == MAXARGS-1) {
f0100a36:	83 fe 0f             	cmp    $0xf,%esi
f0100a39:	75 16                	jne    f0100a51 <monitor+0x9a>
			cprintf("Too many arguments (max %d)\n", MAXARGS);
f0100a3b:	c7 44 24 04 10 00 00 	movl   $0x10,0x4(%esp)
f0100a42:	00 
f0100a43:	c7 04 24 55 6f 10 f0 	movl   $0xf0106f55,(%esp)
f0100a4a:	e8 20 32 00 00       	call   f0103c6f <cprintf>
f0100a4f:	eb 98                	jmp    f01009e9 <monitor+0x32>
			return 0;
		}
		argv[argc++] = buf;
f0100a51:	8d 7e 01             	lea    0x1(%esi),%edi
f0100a54:	89 5c b5 a8          	mov    %ebx,-0x58(%ebp,%esi,4)
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a58:	0f b6 03             	movzbl (%ebx),%eax
f0100a5b:	84 c0                	test   %al,%al
f0100a5d:	75 0c                	jne    f0100a6b <monitor+0xb4>
f0100a5f:	eb b0                	jmp    f0100a11 <monitor+0x5a>
			buf++;
f0100a61:	83 c3 01             	add    $0x1,%ebx
		if (argc == MAXARGS-1) {
			cprintf("Too many arguments (max %d)\n", MAXARGS);
			return 0;
		}
		argv[argc++] = buf;
		while (*buf && !strchr(WHITESPACE, *buf))
f0100a64:	0f b6 03             	movzbl (%ebx),%eax
f0100a67:	84 c0                	test   %al,%al
f0100a69:	74 a6                	je     f0100a11 <monitor+0x5a>
f0100a6b:	0f be c0             	movsbl %al,%eax
f0100a6e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100a72:	c7 04 24 50 6f 10 f0 	movl   $0xf0106f50,(%esp)
f0100a79:	e8 1b 53 00 00       	call   f0105d99 <strchr>
f0100a7e:	85 c0                	test   %eax,%eax
f0100a80:	74 df                	je     f0100a61 <monitor+0xaa>
f0100a82:	eb 8d                	jmp    f0100a11 <monitor+0x5a>
			buf++;
	}
	argv[argc] = 0;
f0100a84:	c7 44 b5 a8 00 00 00 	movl   $0x0,-0x58(%ebp,%esi,4)
f0100a8b:	00 

	// Lookup and invoke the command
	if (argc == 0)
f0100a8c:	85 f6                	test   %esi,%esi
f0100a8e:	0f 84 55 ff ff ff    	je     f01009e9 <monitor+0x32>
f0100a94:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100a99:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
		if (strcmp(argv[0], commands[i].name) == 0)
f0100a9c:	8b 04 85 00 71 10 f0 	mov    -0xfef8f00(,%eax,4),%eax
f0100aa3:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100aa7:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100aaa:	89 04 24             	mov    %eax,(%esp)
f0100aad:	e8 63 52 00 00       	call   f0105d15 <strcmp>
f0100ab2:	85 c0                	test   %eax,%eax
f0100ab4:	75 24                	jne    f0100ada <monitor+0x123>
			return commands[i].func(argc, argv, tf);
f0100ab6:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0100ab9:	8b 55 08             	mov    0x8(%ebp),%edx
f0100abc:	89 54 24 08          	mov    %edx,0x8(%esp)
f0100ac0:	8d 4d a8             	lea    -0x58(%ebp),%ecx
f0100ac3:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0100ac7:	89 34 24             	mov    %esi,(%esp)
f0100aca:	ff 14 85 08 71 10 f0 	call   *-0xfef8ef8(,%eax,4)
		print_trapframe(tf);

	while (1) {
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
f0100ad1:	85 c0                	test   %eax,%eax
f0100ad3:	78 25                	js     f0100afa <monitor+0x143>
f0100ad5:	e9 0f ff ff ff       	jmp    f01009e9 <monitor+0x32>
	argv[argc] = 0;

	// Lookup and invoke the command
	if (argc == 0)
		return 0;
	for (i = 0; i < NCOMMANDS; i++) {
f0100ada:	83 c3 01             	add    $0x1,%ebx
f0100add:	83 fb 03             	cmp    $0x3,%ebx
f0100ae0:	75 b7                	jne    f0100a99 <monitor+0xe2>
		if (strcmp(argv[0], commands[i].name) == 0)
			return commands[i].func(argc, argv, tf);
	}
	cprintf("Unknown command '%s'\n", argv[0]);
f0100ae2:	8b 45 a8             	mov    -0x58(%ebp),%eax
f0100ae5:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100ae9:	c7 04 24 72 6f 10 f0 	movl   $0xf0106f72,(%esp)
f0100af0:	e8 7a 31 00 00       	call   f0103c6f <cprintf>
f0100af5:	e9 ef fe ff ff       	jmp    f01009e9 <monitor+0x32>
		buf = readline("K> ");
		if (buf != NULL)
			if (runcmd(buf, tf) < 0)
				break;
	}
}
f0100afa:	83 c4 5c             	add    $0x5c,%esp
f0100afd:	5b                   	pop    %ebx
f0100afe:	5e                   	pop    %esi
f0100aff:	5f                   	pop    %edi
f0100b00:	5d                   	pop    %ebp
f0100b01:	c3                   	ret    

f0100b02 <read_eip>:
// return EIP of caller.
// does not work if inlined.
// putting at the end of the file seems to prevent inlining.
unsigned
read_eip()
{
f0100b02:	55                   	push   %ebp
f0100b03:	89 e5                	mov    %esp,%ebp
	uint32_t callerpc;
	__asm __volatile("movl 4(%%ebp), %0" : "=r" (callerpc));
f0100b05:	8b 45 04             	mov    0x4(%ebp),%eax
	return callerpc;
}
f0100b08:	5d                   	pop    %ebp
f0100b09:	c3                   	ret    
f0100b0a:	66 90                	xchg   %ax,%ax
f0100b0c:	66 90                	xchg   %ax,%ax
f0100b0e:	66 90                	xchg   %ax,%ax

f0100b10 <boot_alloc>:
// If we're out of memory, boot_alloc should panic.
// This function may ONLY be used during initialization,
// before the page_free_list list has been set up.
static void *
boot_alloc(uint32_t n)
{
f0100b10:	55                   	push   %ebp
f0100b11:	89 e5                	mov    %esp,%ebp
f0100b13:	56                   	push   %esi
f0100b14:	53                   	push   %ebx
f0100b15:	83 ec 10             	sub    $0x10,%esp
f0100b18:	89 c3                	mov    %eax,%ebx
	// Initialize nextfree if this is the first time.
	// 'end' is a magic symbol automatically generated by the linker,
	// which points to the end of the kernel's bss segment:
	// the first virtual address that the linker did *not* assign
	// to any kernel code or global variables.
	if (!nextfree) {
f0100b1a:	83 3d 38 c2 1c f0 00 	cmpl   $0x0,0xf01cc238
f0100b21:	75 0f                	jne    f0100b32 <boot_alloc+0x22>
		extern char end[];
		nextfree = ROUNDUP((char *) end, PGSIZE);
f0100b23:	b8 03 f0 20 f0       	mov    $0xf020f003,%eax
f0100b28:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b2d:	a3 38 c2 1c f0       	mov    %eax,0xf01cc238
	// to a multiple of PGSIZE.
	//
	// LAB 2: Your code here.

	// Assuming
	cprintf("boot_alloc @: %p\n", nextfree);
f0100b32:	a1 38 c2 1c f0       	mov    0xf01cc238,%eax
f0100b37:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b3b:	c7 04 24 24 71 10 f0 	movl   $0xf0107124,(%esp)
f0100b42:	e8 28 31 00 00       	call   f0103c6f <cprintf>
	if(n == 0) return nextfree;
f0100b47:	a1 38 c2 1c f0       	mov    0xf01cc238,%eax
f0100b4c:	85 db                	test   %ebx,%ebx
f0100b4e:	74 29                	je     f0100b79 <boot_alloc+0x69>
	void* first_address = nextfree;
f0100b50:	8b 35 38 c2 1c f0    	mov    0xf01cc238,%esi
	nextfree += n;
	nextfree = ROUNDUP(nextfree, PGSIZE);
f0100b56:	8d 84 1e ff 0f 00 00 	lea    0xfff(%esi,%ebx,1),%eax
f0100b5d:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100b62:	a3 38 c2 1c f0       	mov    %eax,0xf01cc238
	cprintf("after boot_alloc, nextfree @: %p\n", nextfree);
f0100b67:	89 44 24 04          	mov    %eax,0x4(%esp)
f0100b6b:	c7 04 24 bc 74 10 f0 	movl   $0xf01074bc,(%esp)
f0100b72:	e8 f8 30 00 00       	call   f0103c6f <cprintf>

	return first_address;
f0100b77:	89 f0                	mov    %esi,%eax
}
f0100b79:	83 c4 10             	add    $0x10,%esp
f0100b7c:	5b                   	pop    %ebx
f0100b7d:	5e                   	pop    %esi
f0100b7e:	5d                   	pop    %ebp
f0100b7f:	c3                   	ret    

f0100b80 <page2kva>:
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100b80:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f0100b86:	c1 f8 03             	sar    $0x3,%eax
f0100b89:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100b8c:	89 c2                	mov    %eax,%edx
f0100b8e:	c1 ea 0c             	shr    $0xc,%edx
f0100b91:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f0100b97:	72 26                	jb     f0100bbf <page2kva+0x3f>
	return &pages[PGNUM(pa)];
}

static inline void*
page2kva(struct Page *pp)
{
f0100b99:	55                   	push   %ebp
f0100b9a:	89 e5                	mov    %esp,%ebp
f0100b9c:	83 ec 18             	sub    $0x18,%esp

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100b9f:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ba3:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0100baa:	f0 
f0100bab:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100bb2:	00 
f0100bb3:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0100bba:	e8 81 f4 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100bbf:	2d 00 00 00 10       	sub    $0x10000000,%eax

static inline void*
page2kva(struct Page *pp)
{
	return KADDR(page2pa(pp));
}
f0100bc4:	c3                   	ret    

f0100bc5 <check_va2pa>:
static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
f0100bc5:	89 d1                	mov    %edx,%ecx
f0100bc7:	c1 e9 16             	shr    $0x16,%ecx
	if (!(*pgdir & PTE_P))
f0100bca:	8b 04 88             	mov    (%eax,%ecx,4),%eax
f0100bcd:	a8 01                	test   $0x1,%al
f0100bcf:	74 5d                	je     f0100c2e <check_va2pa+0x69>
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
f0100bd1:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100bd6:	89 c1                	mov    %eax,%ecx
f0100bd8:	c1 e9 0c             	shr    $0xc,%ecx
f0100bdb:	3b 0d 88 ce 1c f0    	cmp    0xf01cce88,%ecx
f0100be1:	72 26                	jb     f0100c09 <check_va2pa+0x44>
// this functionality for us!  We define our own version to help check
// the check_kern_pgdir() function; it shouldn't be used elsewhere.

static physaddr_t
check_va2pa(pde_t *pgdir, uintptr_t va)
{
f0100be3:	55                   	push   %ebp
f0100be4:	89 e5                	mov    %esp,%ebp
f0100be6:	83 ec 18             	sub    $0x18,%esp
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100be9:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100bed:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0100bf4:	f0 
f0100bf5:	c7 44 24 04 b4 03 00 	movl   $0x3b4,0x4(%esp)
f0100bfc:	00 
f0100bfd:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100c04:	e8 37 f4 ff ff       	call   f0100040 <_panic>

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
f0100c09:	c1 ea 0c             	shr    $0xc,%edx
f0100c0c:	81 e2 ff 03 00 00    	and    $0x3ff,%edx
f0100c12:	8b 84 90 00 00 00 f0 	mov    -0x10000000(%eax,%edx,4),%eax
f0100c19:	89 c2                	mov    %eax,%edx
f0100c1b:	83 e2 01             	and    $0x1,%edx
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
f0100c1e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0100c23:	85 d2                	test   %edx,%edx
f0100c25:	ba ff ff ff ff       	mov    $0xffffffff,%edx
f0100c2a:	0f 44 c2             	cmove  %edx,%eax
f0100c2d:	c3                   	ret    
{
	pte_t *p;

	pgdir = &pgdir[PDX(va)];
	if (!(*pgdir & PTE_P))
		return ~0;
f0100c2e:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
	p = (pte_t*) KADDR(PTE_ADDR(*pgdir));
	if (!(p[PTX(va)] & PTE_P))
		return ~0;
	return PTE_ADDR(p[PTX(va)]);
}
f0100c33:	c3                   	ret    

f0100c34 <check_page_free_list>:
//
// Check that the pages on the page_free_list are reasonable.
//
static void
check_page_free_list(bool only_low_memory)
{
f0100c34:	55                   	push   %ebp
f0100c35:	89 e5                	mov    %esp,%ebp
f0100c37:	57                   	push   %edi
f0100c38:	56                   	push   %esi
f0100c39:	53                   	push   %ebx
f0100c3a:	83 ec 4c             	sub    $0x4c,%esp
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100c3d:	85 c0                	test   %eax,%eax
f0100c3f:	0f 85 78 03 00 00    	jne    f0100fbd <check_page_free_list+0x389>
f0100c45:	e9 85 03 00 00       	jmp    f0100fcf <check_page_free_list+0x39b>
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
		panic("'page_free_list' is a null pointer!");
f0100c4a:	c7 44 24 08 e0 74 10 	movl   $0xf01074e0,0x8(%esp)
f0100c51:	f0 
f0100c52:	c7 44 24 04 e5 02 00 	movl   $0x2e5,0x4(%esp)
f0100c59:	00 
f0100c5a:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100c61:	e8 da f3 ff ff       	call   f0100040 <_panic>

	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
f0100c66:	8d 55 d8             	lea    -0x28(%ebp),%edx
f0100c69:	89 55 e0             	mov    %edx,-0x20(%ebp)
f0100c6c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f0100c6f:	89 55 e4             	mov    %edx,-0x1c(%ebp)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100c72:	89 c2                	mov    %eax,%edx
f0100c74:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
		for (pp = page_free_list; pp; pp = pp->pp_link) {
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
f0100c7a:	f7 c2 00 e0 7f 00    	test   $0x7fe000,%edx
f0100c80:	0f 95 c2             	setne  %dl
f0100c83:	0f b6 d2             	movzbl %dl,%edx
			*tp[pagetype] = pp;
f0100c86:	8b 4c 95 e0          	mov    -0x20(%ebp,%edx,4),%ecx
f0100c8a:	89 01                	mov    %eax,(%ecx)
			tp[pagetype] = &pp->pp_link;
f0100c8c:	89 44 95 e0          	mov    %eax,-0x20(%ebp,%edx,4)
	if (only_low_memory) {
		// Move pages with lower addresses first in the free
		// list, since entry_pgdir does not map all pages.
		struct Page *pp1, *pp2;
		struct Page **tp[2] = { &pp1, &pp2 };
		for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100c90:	8b 00                	mov    (%eax),%eax
f0100c92:	85 c0                	test   %eax,%eax
f0100c94:	75 dc                	jne    f0100c72 <check_page_free_list+0x3e>
			int pagetype = PDX(page2pa(pp)) >= pdx_limit;
			*tp[pagetype] = pp;
			tp[pagetype] = &pp->pp_link;
		}
		*tp[1] = 0;
f0100c96:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0100c99:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		*tp[0] = pp2;
f0100c9f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0100ca2:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0100ca5:	89 10                	mov    %edx,(%eax)
		page_free_list = pp1;
f0100ca7:	8b 45 d8             	mov    -0x28(%ebp),%eax
f0100caa:	a3 40 c2 1c f0       	mov    %eax,0xf01cc240
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100caf:	89 c3                	mov    %eax,%ebx
f0100cb1:	85 c0                	test   %eax,%eax
f0100cb3:	74 6c                	je     f0100d21 <check_page_free_list+0xed>
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0100cb5:	be 01 00 00 00       	mov    $0x1,%esi
f0100cba:	89 d8                	mov    %ebx,%eax
f0100cbc:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f0100cc2:	c1 f8 03             	sar    $0x3,%eax
f0100cc5:	c1 e0 0c             	shl    $0xc,%eax
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
f0100cc8:	89 c2                	mov    %eax,%edx
f0100cca:	c1 ea 16             	shr    $0x16,%edx
f0100ccd:	39 f2                	cmp    %esi,%edx
f0100ccf:	73 4a                	jae    f0100d1b <check_page_free_list+0xe7>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100cd1:	89 c2                	mov    %eax,%edx
f0100cd3:	c1 ea 0c             	shr    $0xc,%edx
f0100cd6:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f0100cdc:	72 20                	jb     f0100cfe <check_page_free_list+0xca>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100cde:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ce2:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0100ce9:	f0 
f0100cea:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100cf1:	00 
f0100cf2:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0100cf9:	e8 42 f3 ff ff       	call   f0100040 <_panic>
			memset(page2kva(pp), 0x97, 128);
f0100cfe:	c7 44 24 08 80 00 00 	movl   $0x80,0x8(%esp)
f0100d05:	00 
f0100d06:	c7 44 24 04 97 00 00 	movl   $0x97,0x4(%esp)
f0100d0d:	00 
	return (void *)(pa + KERNBASE);
f0100d0e:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0100d13:	89 04 24             	mov    %eax,(%esp)
f0100d16:	e8 de 50 00 00       	call   f0105df9 <memset>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100d1b:	8b 1b                	mov    (%ebx),%ebx
f0100d1d:	85 db                	test   %ebx,%ebx
f0100d1f:	75 99                	jne    f0100cba <check_page_free_list+0x86>
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
f0100d21:	b8 00 00 00 00       	mov    $0x0,%eax
f0100d26:	e8 e5 fd ff ff       	call   f0100b10 <boot_alloc>
f0100d2b:	89 45 c8             	mov    %eax,-0x38(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100d2e:	8b 15 40 c2 1c f0    	mov    0xf01cc240,%edx
f0100d34:	85 d2                	test   %edx,%edx
f0100d36:	0f 84 27 02 00 00    	je     f0100f63 <check_page_free_list+0x32f>
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d3c:	8b 3d 90 ce 1c f0    	mov    0xf01cce90,%edi
f0100d42:	39 fa                	cmp    %edi,%edx
f0100d44:	72 3f                	jb     f0100d85 <check_page_free_list+0x151>
		assert(pp < pages + npages);
f0100d46:	a1 88 ce 1c f0       	mov    0xf01cce88,%eax
f0100d4b:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0100d4e:	8d 04 c7             	lea    (%edi,%eax,8),%eax
f0100d51:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0100d54:	39 c2                	cmp    %eax,%edx
f0100d56:	73 56                	jae    f0100dae <check_page_free_list+0x17a>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100d58:	89 7d d0             	mov    %edi,-0x30(%ebp)
f0100d5b:	89 d0                	mov    %edx,%eax
f0100d5d:	29 f8                	sub    %edi,%eax
f0100d5f:	a8 07                	test   $0x7,%al
f0100d61:	75 78                	jne    f0100ddb <check_page_free_list+0x1a7>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0100d63:	c1 f8 03             	sar    $0x3,%eax
f0100d66:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100d69:	85 c0                	test   %eax,%eax
f0100d6b:	0f 84 98 00 00 00    	je     f0100e09 <check_page_free_list+0x1d5>
		assert(page2pa(pp) != IOPHYSMEM);
f0100d71:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100d76:	0f 85 dc 00 00 00    	jne    f0100e58 <check_page_free_list+0x224>
f0100d7c:	e9 b3 00 00 00       	jmp    f0100e34 <check_page_free_list+0x200>
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
		// check that we didn't corrupt the free list itself
		assert(pp >= pages);
f0100d81:	39 d7                	cmp    %edx,%edi
f0100d83:	76 24                	jbe    f0100da9 <check_page_free_list+0x175>
f0100d85:	c7 44 24 0c 50 71 10 	movl   $0xf0107150,0xc(%esp)
f0100d8c:	f0 
f0100d8d:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100d94:	f0 
f0100d95:	c7 44 24 04 ff 02 00 	movl   $0x2ff,0x4(%esp)
f0100d9c:	00 
f0100d9d:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100da4:	e8 97 f2 ff ff       	call   f0100040 <_panic>
		assert(pp < pages + npages);
f0100da9:	3b 55 d4             	cmp    -0x2c(%ebp),%edx
f0100dac:	72 24                	jb     f0100dd2 <check_page_free_list+0x19e>
f0100dae:	c7 44 24 0c 71 71 10 	movl   $0xf0107171,0xc(%esp)
f0100db5:	f0 
f0100db6:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100dbd:	f0 
f0100dbe:	c7 44 24 04 00 03 00 	movl   $0x300,0x4(%esp)
f0100dc5:	00 
f0100dc6:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100dcd:	e8 6e f2 ff ff       	call   f0100040 <_panic>
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);
f0100dd2:	89 d0                	mov    %edx,%eax
f0100dd4:	2b 45 d0             	sub    -0x30(%ebp),%eax
f0100dd7:	a8 07                	test   $0x7,%al
f0100dd9:	74 24                	je     f0100dff <check_page_free_list+0x1cb>
f0100ddb:	c7 44 24 0c 04 75 10 	movl   $0xf0107504,0xc(%esp)
f0100de2:	f0 
f0100de3:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100dea:	f0 
f0100deb:	c7 44 24 04 01 03 00 	movl   $0x301,0x4(%esp)
f0100df2:	00 
f0100df3:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100dfa:	e8 41 f2 ff ff       	call   f0100040 <_panic>
f0100dff:	c1 f8 03             	sar    $0x3,%eax
f0100e02:	c1 e0 0c             	shl    $0xc,%eax

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
f0100e05:	85 c0                	test   %eax,%eax
f0100e07:	75 24                	jne    f0100e2d <check_page_free_list+0x1f9>
f0100e09:	c7 44 24 0c 85 71 10 	movl   $0xf0107185,0xc(%esp)
f0100e10:	f0 
f0100e11:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100e18:	f0 
f0100e19:	c7 44 24 04 04 03 00 	movl   $0x304,0x4(%esp)
f0100e20:	00 
f0100e21:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100e28:	e8 13 f2 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != IOPHYSMEM);
f0100e2d:	3d 00 00 0a 00       	cmp    $0xa0000,%eax
f0100e32:	75 31                	jne    f0100e65 <check_page_free_list+0x231>
f0100e34:	c7 44 24 0c 96 71 10 	movl   $0xf0107196,0xc(%esp)
f0100e3b:	f0 
f0100e3c:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100e43:	f0 
f0100e44:	c7 44 24 04 05 03 00 	movl   $0x305,0x4(%esp)
f0100e4b:	00 
f0100e4c:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100e53:	e8 e8 f1 ff ff       	call   f0100040 <_panic>
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
f0100e58:	bb 00 00 00 00       	mov    $0x0,%ebx
f0100e5d:	be 00 00 00 00       	mov    $0x0,%esi
f0100e62:	89 5d cc             	mov    %ebx,-0x34(%ebp)
		assert(((char *) pp - (char *) pages) % sizeof(*pp) == 0);

		// check a few pages that shouldn't be on the free list
		assert(page2pa(pp) != 0);
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
f0100e65:	3d 00 f0 0f 00       	cmp    $0xff000,%eax
f0100e6a:	75 24                	jne    f0100e90 <check_page_free_list+0x25c>
f0100e6c:	c7 44 24 0c 38 75 10 	movl   $0xf0107538,0xc(%esp)
f0100e73:	f0 
f0100e74:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100e7b:	f0 
f0100e7c:	c7 44 24 04 06 03 00 	movl   $0x306,0x4(%esp)
f0100e83:	00 
f0100e84:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100e8b:	e8 b0 f1 ff ff       	call   f0100040 <_panic>
		assert(page2pa(pp) != EXTPHYSMEM);
f0100e90:	3d 00 00 10 00       	cmp    $0x100000,%eax
f0100e95:	75 24                	jne    f0100ebb <check_page_free_list+0x287>
f0100e97:	c7 44 24 0c af 71 10 	movl   $0xf01071af,0xc(%esp)
f0100e9e:	f0 
f0100e9f:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100ea6:	f0 
f0100ea7:	c7 44 24 04 07 03 00 	movl   $0x307,0x4(%esp)
f0100eae:	00 
f0100eaf:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100eb6:	e8 85 f1 ff ff       	call   f0100040 <_panic>
f0100ebb:	89 c1                	mov    %eax,%ecx
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
f0100ebd:	3d ff ff 0f 00       	cmp    $0xfffff,%eax
f0100ec2:	0f 86 15 01 00 00    	jbe    f0100fdd <check_page_free_list+0x3a9>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0100ec8:	89 c3                	mov    %eax,%ebx
f0100eca:	c1 eb 0c             	shr    $0xc,%ebx
f0100ecd:	39 5d c4             	cmp    %ebx,-0x3c(%ebp)
f0100ed0:	77 20                	ja     f0100ef2 <check_page_free_list+0x2be>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0100ed2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0100ed6:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0100edd:	f0 
f0100ede:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0100ee5:	00 
f0100ee6:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0100eed:	e8 4e f1 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0100ef2:	81 e9 00 00 00 10    	sub    $0x10000000,%ecx
f0100ef8:	39 4d c8             	cmp    %ecx,-0x38(%ebp)
f0100efb:	0f 86 ec 00 00 00    	jbe    f0100fed <check_page_free_list+0x3b9>
f0100f01:	c7 44 24 0c 5c 75 10 	movl   $0xf010755c,0xc(%esp)
f0100f08:	f0 
f0100f09:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100f10:	f0 
f0100f11:	c7 44 24 04 08 03 00 	movl   $0x308,0x4(%esp)
f0100f18:	00 
f0100f19:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100f20:	e8 1b f1 ff ff       	call   f0100040 <_panic>
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100f25:	c7 44 24 0c c9 71 10 	movl   $0xf01071c9,0xc(%esp)
f0100f2c:	f0 
f0100f2d:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100f34:	f0 
f0100f35:	c7 44 24 04 0a 03 00 	movl   $0x30a,0x4(%esp)
f0100f3c:	00 
f0100f3d:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100f44:	e8 f7 f0 ff ff       	call   f0100040 <_panic>

		if (page2pa(pp) < EXTPHYSMEM)
			++nfree_basemem;
f0100f49:	83 c6 01             	add    $0x1,%esi
f0100f4c:	eb 04                	jmp    f0100f52 <check_page_free_list+0x31e>
		else
			++nfree_extmem;
f0100f4e:	83 45 cc 01          	addl   $0x1,-0x34(%ebp)
	for (pp = page_free_list; pp; pp = pp->pp_link)
		if (PDX(page2pa(pp)) < pdx_limit)
			memset(page2kva(pp), 0x97, 128);

	first_free_page = (char *) boot_alloc(0);
	for (pp = page_free_list; pp; pp = pp->pp_link) {
f0100f52:	8b 12                	mov    (%edx),%edx
f0100f54:	85 d2                	test   %edx,%edx
f0100f56:	0f 85 25 fe ff ff    	jne    f0100d81 <check_page_free_list+0x14d>
f0100f5c:	8b 5d cc             	mov    -0x34(%ebp),%ebx
			++nfree_basemem;
		else
			++nfree_extmem;
	}

	assert(nfree_basemem > 0);
f0100f5f:	85 f6                	test   %esi,%esi
f0100f61:	7f 24                	jg     f0100f87 <check_page_free_list+0x353>
f0100f63:	c7 44 24 0c e6 71 10 	movl   $0xf01071e6,0xc(%esp)
f0100f6a:	f0 
f0100f6b:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100f72:	f0 
f0100f73:	c7 44 24 04 12 03 00 	movl   $0x312,0x4(%esp)
f0100f7a:	00 
f0100f7b:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100f82:	e8 b9 f0 ff ff       	call   f0100040 <_panic>
	assert(nfree_extmem > 0);
f0100f87:	85 db                	test   %ebx,%ebx
f0100f89:	7f 24                	jg     f0100faf <check_page_free_list+0x37b>
f0100f8b:	c7 44 24 0c f8 71 10 	movl   $0xf01071f8,0xc(%esp)
f0100f92:	f0 
f0100f93:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0100f9a:	f0 
f0100f9b:	c7 44 24 04 13 03 00 	movl   $0x313,0x4(%esp)
f0100fa2:	00 
f0100fa3:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0100faa:	e8 91 f0 ff ff       	call   f0100040 <_panic>
	cprintf("check_page_free_list_done\n");
f0100faf:	c7 04 24 09 72 10 f0 	movl   $0xf0107209,(%esp)
f0100fb6:	e8 b4 2c 00 00       	call   f0103c6f <cprintf>
f0100fbb:	eb 50                	jmp    f010100d <check_page_free_list+0x3d9>
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
	int nfree_basemem = 0, nfree_extmem = 0;
	char *first_free_page;

	if (!page_free_list)
f0100fbd:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
f0100fc2:	85 c0                	test   %eax,%eax
f0100fc4:	0f 85 9c fc ff ff    	jne    f0100c66 <check_page_free_list+0x32>
f0100fca:	e9 7b fc ff ff       	jmp    f0100c4a <check_page_free_list+0x16>
f0100fcf:	83 3d 40 c2 1c f0 00 	cmpl   $0x0,0xf01cc240
f0100fd6:	75 25                	jne    f0100ffd <check_page_free_list+0x3c9>
f0100fd8:	e9 6d fc ff ff       	jmp    f0100c4a <check_page_free_list+0x16>
		assert(page2pa(pp) != IOPHYSMEM);
		assert(page2pa(pp) != EXTPHYSMEM - PGSIZE);
		assert(page2pa(pp) != EXTPHYSMEM);
		assert(page2pa(pp) < EXTPHYSMEM || (char *) page2kva(pp) >= first_free_page);
		// (new test for lab 4)
		assert(page2pa(pp) != MPENTRY_PADDR);
f0100fdd:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100fe2:	0f 85 61 ff ff ff    	jne    f0100f49 <check_page_free_list+0x315>
f0100fe8:	e9 38 ff ff ff       	jmp    f0100f25 <check_page_free_list+0x2f1>
f0100fed:	3d 00 70 00 00       	cmp    $0x7000,%eax
f0100ff2:	0f 85 56 ff ff ff    	jne    f0100f4e <check_page_free_list+0x31a>
f0100ff8:	e9 28 ff ff ff       	jmp    f0100f25 <check_page_free_list+0x2f1>
		page_free_list = pp1;
	}

	// if there's a page that shouldn't be on the free list,
	// try to make sure it eventually causes trouble.
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0100ffd:	8b 1d 40 c2 1c f0    	mov    0xf01cc240,%ebx
//
static void
check_page_free_list(bool only_low_memory)
{
	struct Page *pp;
	unsigned pdx_limit = only_low_memory ? 1 : NPDENTRIES;
f0101003:	be 00 04 00 00       	mov    $0x400,%esi
f0101008:	e9 ad fc ff ff       	jmp    f0100cba <check_page_free_list+0x86>
	}

	assert(nfree_basemem > 0);
	assert(nfree_extmem > 0);
	cprintf("check_page_free_list_done\n");
}
f010100d:	83 c4 4c             	add    $0x4c,%esp
f0101010:	5b                   	pop    %ebx
f0101011:	5e                   	pop    %esi
f0101012:	5f                   	pop    %edi
f0101013:	5d                   	pop    %ebp
f0101014:	c3                   	ret    

f0101015 <page_init>:
// allocator functions below to allocate and deallocate physical
// memory via the page_free_list.
//
void
page_init(void)
{
f0101015:	55                   	push   %ebp
f0101016:	89 e5                	mov    %esp,%ebp
f0101018:	56                   	push   %esi
f0101019:	53                   	push   %ebx
f010101a:	83 ec 10             	sub    $0x10,%esp
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010101d:	83 3d 88 ce 1c f0 07 	cmpl   $0x7,0xf01cce88
f0101024:	77 1c                	ja     f0101042 <page_init+0x2d>
		panic("pa2page called with invalid pa");
f0101026:	c7 44 24 08 a4 75 10 	movl   $0xf01075a4,0x8(%esp)
f010102d:	f0 
f010102e:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0101035:	00 
f0101036:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f010103d:	e8 fe ef ff ff       	call   f0100040 <_panic>
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
f0101042:	a1 90 ce 1c f0       	mov    0xf01cce90,%eax
f0101047:	8d 70 38             	lea    0x38(%eax),%esi
	for (i; i < npages_basemem; i++) {
f010104a:	83 3d 44 c2 1c f0 01 	cmpl   $0x1,0xf01cc244
f0101051:	76 4b                	jbe    f010109e <page_init+0x89>
	//     page tables and other data structures?
	//
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
f0101053:	bb 01 00 00 00       	mov    $0x1,%ebx
f0101058:	8d 14 dd 00 00 00 00 	lea    0x0(,%ebx,8),%edx
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
		if(pages + i == page_mpentry) 
f010105f:	89 d0                	mov    %edx,%eax
f0101061:	03 05 90 ce 1c f0    	add    0xf01cce90,%eax
f0101067:	39 f0                	cmp    %esi,%eax
f0101069:	75 0e                	jne    f0101079 <page_init+0x64>
		{
			cprintf("MPENTRY detected!\n");
f010106b:	c7 04 24 24 72 10 f0 	movl   $0xf0107224,(%esp)
f0101072:	e8 f8 2b 00 00       	call   f0103c6f <cprintf>
			continue;
f0101077:	eb 1a                	jmp    f0101093 <page_init+0x7e>
		}
		pages[i].pp_ref = 0;
f0101079:	66 c7 40 04 00 00    	movw   $0x0,0x4(%eax)
		pages[i].pp_link = page_free_list;
f010107f:	8b 0d 40 c2 1c f0    	mov    0xf01cc240,%ecx
f0101085:	89 08                	mov    %ecx,(%eax)
		page_free_list = &pages[i];
f0101087:	03 15 90 ce 1c f0    	add    0xf01cce90,%edx
f010108d:	89 15 40 c2 1c f0    	mov    %edx,0xf01cc240
	// Change the code to reflect this.
	// NB: DO NOT actually touch the physical memory corresponding to
	// free pages!
	size_t i = 1;
	struct Page* page_mpentry = pa2page(MPENTRY_PADDR);
	for (i; i < npages_basemem; i++) {
f0101093:	83 c3 01             	add    $0x1,%ebx
f0101096:	39 1d 44 c2 1c f0    	cmp    %ebx,0xf01cc244
f010109c:	77 ba                	ja     f0101058 <page_init+0x43>
		page_free_list = &pages[i];
	}

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
f010109e:	8b 0d 88 ce 1c f0    	mov    0xf01cce88,%ecx
f01010a4:	a1 90 ce 1c f0       	mov    0xf01cce90,%eax
f01010a9:	8d 84 c8 ff ff 01 10 	lea    0x1001ffff(%eax,%ecx,8),%eax
f01010b0:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01010b5:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f01010bb:	85 c0                	test   %eax,%eax
f01010bd:	0f 48 c2             	cmovs  %edx,%eax
f01010c0:	c1 f8 0c             	sar    $0xc,%eax
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f01010c3:	89 c2                	mov    %eax,%edx
f01010c5:	39 c1                	cmp    %eax,%ecx
f01010c7:	76 39                	jbe    f0101102 <page_init+0xed>
f01010c9:	8b 1d 40 c2 1c f0    	mov    0xf01cc240,%ebx
f01010cf:	c1 e0 03             	shl    $0x3,%eax
		pages[i].pp_ref = 0;
f01010d2:	89 c1                	mov    %eax,%ecx
f01010d4:	03 0d 90 ce 1c f0    	add    0xf01cce90,%ecx
f01010da:	66 c7 41 04 00 00    	movw   $0x0,0x4(%ecx)
		pages[i].pp_link = page_free_list;
f01010e0:	89 19                	mov    %ebx,(%ecx)
		page_free_list = &pages[i];
f01010e2:	89 c1                	mov    %eax,%ecx
f01010e4:	03 0d 90 ce 1c f0    	add    0xf01cce90,%ecx

	//cprintf("EXTPHYSMEM starts @: %p\n", EXTPHYSMEM);
	// Pages is used after npages of struct Page is allocated
	int start_point_of_free_page = (int)ROUNDUP(((char*)pages) + (sizeof(struct Page) * npages) + (sizeof(struct Env) * NENV) - 0xf0000000, PGSIZE)/PGSIZE;
	//cprintf("start_point_of_free_page (including pagetable and other ds)=%x\n", start_point_of_free_page);
 	for(i = start_point_of_free_page; i < npages; i++) {
f01010ea:	83 c2 01             	add    $0x1,%edx
f01010ed:	83 c0 08             	add    $0x8,%eax
f01010f0:	39 15 88 ce 1c f0    	cmp    %edx,0xf01cce88
f01010f6:	76 04                	jbe    f01010fc <page_init+0xe7>
		pages[i].pp_ref = 0;
		pages[i].pp_link = page_free_list;
		page_free_list = &pages[i];
f01010f8:	89 cb                	mov    %ecx,%ebx
f01010fa:	eb d6                	jmp    f01010d2 <page_init+0xbd>
f01010fc:	89 0d 40 c2 1c f0    	mov    %ecx,0xf01cc240
	}

}
f0101102:	83 c4 10             	add    $0x10,%esp
f0101105:	5b                   	pop    %ebx
f0101106:	5e                   	pop    %esi
f0101107:	5d                   	pop    %ebp
f0101108:	c3                   	ret    

f0101109 <page_alloc>:
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
	// Fill this function in
	if(page_free_list == NULL) return NULL;
f0101109:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
f010110e:	85 c0                	test   %eax,%eax
f0101110:	74 71                	je     f0101183 <page_alloc+0x7a>
// Returns NULL if out of free memory.
//
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
f0101112:	55                   	push   %ebp
f0101113:	89 e5                	mov    %esp,%ebp
f0101115:	83 ec 18             	sub    $0x18,%esp
	// Fill this function in
	if(page_free_list == NULL) return NULL;
	if(alloc_flags & ALLOC_ZERO)
f0101118:	f6 45 08 01          	testb  $0x1,0x8(%ebp)
f010111c:	74 56                	je     f0101174 <page_alloc+0x6b>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010111e:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f0101124:	c1 f8 03             	sar    $0x3,%eax
f0101127:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010112a:	89 c2                	mov    %eax,%edx
f010112c:	c1 ea 0c             	shr    $0xc,%edx
f010112f:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f0101135:	72 20                	jb     f0101157 <page_alloc+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101137:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010113b:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0101142:	f0 
f0101143:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010114a:	00 
f010114b:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0101152:	e8 e9 ee ff ff       	call   f0100040 <_panic>
		memset(page2kva(page_free_list), 0, PGSIZE);
f0101157:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010115e:	00 
f010115f:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101166:	00 
	return (void *)(pa + KERNBASE);
f0101167:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010116c:	89 04 24             	mov    %eax,(%esp)
f010116f:	e8 85 4c 00 00       	call   f0105df9 <memset>
	struct Page* allocated = page_free_list;
f0101174:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
	//cprintf("--- page_alloc: Allocating new page at va: %x, pa: %x\n", page2kva(page_free_list), page2pa(page_free_list));
	page_free_list = page_free_list->pp_link;
f0101179:	8b 10                	mov    (%eax),%edx
f010117b:	89 15 40 c2 1c f0    	mov    %edx,0xf01cc240

	return allocated;
f0101181:	eb 06                	jmp    f0101189 <page_alloc+0x80>
// Hint: use page2kva and memset
struct Page *
page_alloc(int alloc_flags)
{
	// Fill this function in
	if(page_free_list == NULL) return NULL;
f0101183:	b8 00 00 00 00       	mov    $0x0,%eax
f0101188:	c3                   	ret    
	struct Page* allocated = page_free_list;
	//cprintf("--- page_alloc: Allocating new page at va: %x, pa: %x\n", page2kva(page_free_list), page2pa(page_free_list));
	page_free_list = page_free_list->pp_link;

	return allocated;
}
f0101189:	c9                   	leave  
f010118a:	c3                   	ret    

f010118b <page_free>:
// Return a page to the free list.
// (This function should only be called when pp->pp_ref reaches 0.)
//
void
page_free(struct Page *pp)
{
f010118b:	55                   	push   %ebp
f010118c:	89 e5                	mov    %esp,%ebp
f010118e:	83 ec 18             	sub    $0x18,%esp
f0101191:	8b 45 08             	mov    0x8(%ebp),%eax
	// Fill this function in
	if(pp == NULL) panic("page_free: page point equals to zero\n");
f0101194:	85 c0                	test   %eax,%eax
f0101196:	75 1c                	jne    f01011b4 <page_free+0x29>
f0101198:	c7 44 24 08 c4 75 10 	movl   $0xf01075c4,0x8(%esp)
f010119f:	f0 
f01011a0:	c7 44 24 04 a7 01 00 	movl   $0x1a7,0x4(%esp)
f01011a7:	00 
f01011a8:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01011af:	e8 8c ee ff ff       	call   f0100040 <_panic>
	pp->pp_link = page_free_list;
f01011b4:	8b 15 40 c2 1c f0    	mov    0xf01cc240,%edx
f01011ba:	89 10                	mov    %edx,(%eax)
	page_free_list = pp;
f01011bc:	a3 40 c2 1c f0       	mov    %eax,0xf01cc240
}
f01011c1:	c9                   	leave  
f01011c2:	c3                   	ret    

f01011c3 <page_decref>:
// Decrement the reference count on a page,
// freeing it if there are no more refs.
//
void
page_decref(struct Page* pp)
{
f01011c3:	55                   	push   %ebp
f01011c4:	89 e5                	mov    %esp,%ebp
f01011c6:	83 ec 18             	sub    $0x18,%esp
f01011c9:	8b 45 08             	mov    0x8(%ebp),%eax
	if (--pp->pp_ref == 0)
f01011cc:	0f b7 48 04          	movzwl 0x4(%eax),%ecx
f01011d0:	8d 51 ff             	lea    -0x1(%ecx),%edx
f01011d3:	66 89 50 04          	mov    %dx,0x4(%eax)
f01011d7:	66 85 d2             	test   %dx,%dx
f01011da:	75 08                	jne    f01011e4 <page_decref+0x21>
		page_free(pp);
f01011dc:	89 04 24             	mov    %eax,(%esp)
f01011df:	e8 a7 ff ff ff       	call   f010118b <page_free>
}
f01011e4:	c9                   	leave  
f01011e5:	c3                   	ret    

f01011e6 <pgdir_walk>:
// Hint 3: look at inc/mmu.h for useful macros that mainipulate page
// table and page directory entries.
//
pte_t *
pgdir_walk(pde_t *pgdir, const void *va, int create)
{
f01011e6:	55                   	push   %ebp
f01011e7:	89 e5                	mov    %esp,%ebp
f01011e9:	56                   	push   %esi
f01011ea:	53                   	push   %ebx
f01011eb:	83 ec 10             	sub    $0x10,%esp
f01011ee:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	// Fill this function in

	// Walking in page directory table
	pde_t* page_directory_entry = &pgdir[PDX(va)];
f01011f1:	89 de                	mov    %ebx,%esi
f01011f3:	c1 ee 16             	shr    $0x16,%esi
f01011f6:	c1 e6 02             	shl    $0x2,%esi
f01011f9:	03 75 08             	add    0x8(%ebp),%esi
	//cprintf("pgdir_walk at va=%x, with create=%d\n", va, create);
	if(!((*page_directory_entry) & PTE_P))
f01011fc:	8b 06                	mov    (%esi),%eax
f01011fe:	a8 01                	test   $0x1,%al
f0101200:	75 76                	jne    f0101278 <pgdir_walk+0x92>
	{
		//cprintf("Given page is not exist, allocating new pages\n");
		if(!create) return NULL;
f0101202:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0101206:	0f 84 b0 00 00 00    	je     f01012bc <pgdir_walk+0xd6>
		// Allocate Page for Page table;
		struct Page* page = page_alloc(ALLOC_ZERO);
f010120c:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101213:	e8 f1 fe ff ff       	call   f0101109 <page_alloc>
		if(page == NULL)
f0101218:	85 c0                	test   %eax,%eax
f010121a:	0f 84 a3 00 00 00    	je     f01012c3 <pgdir_walk+0xdd>
		{
			//cprintf("page_alloc failed, maybe not enough free space.\n");
			return NULL;
		}
		// Increment count reference
		page->pp_ref = 1;
f0101220:	66 c7 40 04 01 00    	movw   $0x1,0x4(%eax)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101226:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f010122c:	c1 f8 03             	sar    $0x3,%eax
f010122f:	c1 e0 0c             	shl    $0xc,%eax
		// Install page into page directory
		physaddr_t page_addr = page2pa(page);
		*page_directory_entry = 0;
		(*page_directory_entry) |= PTE_U | PTE_W | PTE_P;
		(*page_directory_entry) |= PTE_ADDR(page_addr);
f0101232:	89 c2                	mov    %eax,%edx
f0101234:	83 ca 07             	or     $0x7,%edx
f0101237:	89 16                	mov    %edx,(%esi)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101239:	89 c2                	mov    %eax,%edx
f010123b:	c1 ea 0c             	shr    $0xc,%edx
f010123e:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f0101244:	72 20                	jb     f0101266 <pgdir_walk+0x80>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101246:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010124a:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0101251:	f0 
f0101252:	c7 44 24 04 e7 01 00 	movl   $0x1e7,0x4(%esp)
f0101259:	00 
f010125a:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101261:	e8 da ed ff ff       	call   f0100040 <_panic>
		return (pte_t*)KADDR(page_addr) + PTX(va);
f0101266:	c1 eb 0a             	shr    $0xa,%ebx
f0101269:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f010126f:	8d 84 18 00 00 00 f0 	lea    -0x10000000(%eax,%ebx,1),%eax
f0101276:	eb 50                	jmp    f01012c8 <pgdir_walk+0xe2>
	}
	pte_t* page_table = KADDR(PTE_ADDR(*page_directory_entry));
f0101278:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010127d:	89 c2                	mov    %eax,%edx
f010127f:	c1 ea 0c             	shr    $0xc,%edx
f0101282:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f0101288:	72 20                	jb     f01012aa <pgdir_walk+0xc4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010128a:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010128e:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0101295:	f0 
f0101296:	c7 44 24 04 e9 01 00 	movl   $0x1e9,0x4(%esp)
f010129d:	00 
f010129e:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01012a5:	e8 96 ed ff ff       	call   f0100040 <_panic>
	return  &page_table[PTX(va)];
f01012aa:	c1 eb 0a             	shr    $0xa,%ebx
f01012ad:	81 e3 fc 0f 00 00    	and    $0xffc,%ebx
f01012b3:	8d 84 18 00 00 00 f0 	lea    -0x10000000(%eax,%ebx,1),%eax
f01012ba:	eb 0c                	jmp    f01012c8 <pgdir_walk+0xe2>
	pde_t* page_directory_entry = &pgdir[PDX(va)];
	//cprintf("pgdir_walk at va=%x, with create=%d\n", va, create);
	if(!((*page_directory_entry) & PTE_P))
	{
		//cprintf("Given page is not exist, allocating new pages\n");
		if(!create) return NULL;
f01012bc:	b8 00 00 00 00       	mov    $0x0,%eax
f01012c1:	eb 05                	jmp    f01012c8 <pgdir_walk+0xe2>
		// Allocate Page for Page table;
		struct Page* page = page_alloc(ALLOC_ZERO);
		if(page == NULL)
		{
			//cprintf("page_alloc failed, maybe not enough free space.\n");
			return NULL;
f01012c3:	b8 00 00 00 00       	mov    $0x0,%eax
		(*page_directory_entry) |= PTE_ADDR(page_addr);
		return (pte_t*)KADDR(page_addr) + PTX(va);
	}
	pte_t* page_table = KADDR(PTE_ADDR(*page_directory_entry));
	return  &page_table[PTX(va)];
}
f01012c8:	83 c4 10             	add    $0x10,%esp
f01012cb:	5b                   	pop    %ebx
f01012cc:	5e                   	pop    %esi
f01012cd:	5d                   	pop    %ebp
f01012ce:	c3                   	ret    

f01012cf <boot_map_region>:
// mapped pages.
//
// Hint: the TA solution uses pgdir_walk
static void
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
f01012cf:	55                   	push   %ebp
f01012d0:	89 e5                	mov    %esp,%ebp
f01012d2:	57                   	push   %edi
f01012d3:	56                   	push   %esi
f01012d4:	53                   	push   %ebx
f01012d5:	83 ec 2c             	sub    $0x2c,%esp
	// Fill this function in
	size_t page_count = size / PGSIZE;
f01012d8:	c1 e9 0c             	shr    $0xc,%ecx
f01012db:	89 4d e4             	mov    %ecx,-0x1c(%ebp)
	size_t i;
	for(i = 0; i < page_count; i++)
f01012de:	85 c9                	test   %ecx,%ecx
f01012e0:	74 4d                	je     f010132f <boot_map_region+0x60>
f01012e2:	89 c7                	mov    %eax,%edi
f01012e4:	89 d3                	mov    %edx,%ebx
f01012e6:	be 00 00 00 00       	mov    $0x0,%esi
	{
		pte_t* page_entry = pgdir_walk(pgdir, (void*)(va + PGSIZE * i), 1);
		(*page_entry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f01012eb:	8b 45 0c             	mov    0xc(%ebp),%eax
f01012ee:	83 c8 01             	or     $0x1,%eax
f01012f1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01012f4:	8b 45 08             	mov    0x8(%ebp),%eax
f01012f7:	29 d0                	sub    %edx,%eax
f01012f9:	89 45 dc             	mov    %eax,-0x24(%ebp)
	// Fill this function in
	size_t page_count = size / PGSIZE;
	size_t i;
	for(i = 0; i < page_count; i++)
	{
		pte_t* page_entry = pgdir_walk(pgdir, (void*)(va + PGSIZE * i), 1);
f01012fc:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0101303:	00 
f0101304:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101308:	89 3c 24             	mov    %edi,(%esp)
f010130b:	e8 d6 fe ff ff       	call   f01011e6 <pgdir_walk>
f0101310:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0101313:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
		(*page_entry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
f0101316:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f010131c:	0b 55 e0             	or     -0x20(%ebp),%edx
f010131f:	89 10                	mov    %edx,(%eax)
boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
{
	// Fill this function in
	size_t page_count = size / PGSIZE;
	size_t i;
	for(i = 0; i < page_count; i++)
f0101321:	83 c6 01             	add    $0x1,%esi
f0101324:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010132a:	3b 75 e4             	cmp    -0x1c(%ebp),%esi
f010132d:	75 cd                	jne    f01012fc <boot_map_region+0x2d>
	{
		pte_t* page_entry = pgdir_walk(pgdir, (void*)(va + PGSIZE * i), 1);
		(*page_entry) = PTE_ADDR(pa + PGSIZE * i) | perm | PTE_P;
		//(*page_entry) |= PTE_ADDR(pa + PGSIZE * i);
	}
}
f010132f:	83 c4 2c             	add    $0x2c,%esp
f0101332:	5b                   	pop    %ebx
f0101333:	5e                   	pop    %esi
f0101334:	5f                   	pop    %edi
f0101335:	5d                   	pop    %ebp
f0101336:	c3                   	ret    

f0101337 <page_lookup>:
//
// Hint: the TA solution uses pgdir_walk and pa2page.
//
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
f0101337:	55                   	push   %ebp
f0101338:	89 e5                	mov    %esp,%ebp
f010133a:	83 ec 18             	sub    $0x18,%esp
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 0);
f010133d:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101344:	00 
f0101345:	8b 45 0c             	mov    0xc(%ebp),%eax
f0101348:	89 44 24 04          	mov    %eax,0x4(%esp)
f010134c:	8b 45 08             	mov    0x8(%ebp),%eax
f010134f:	89 04 24             	mov    %eax,(%esp)
f0101352:	e8 8f fe ff ff       	call   f01011e6 <pgdir_walk>
	if(page_table_entry == NULL) return NULL;
f0101357:	85 c0                	test   %eax,%eax
f0101359:	74 39                	je     f0101394 <page_lookup+0x5d>
	*pte_store = page_table_entry;
f010135b:	8b 55 10             	mov    0x10(%ebp),%edx
f010135e:	89 02                	mov    %eax,(%edx)
	return pa2page(PTE_ADDR(*page_table_entry));
f0101360:	8b 00                	mov    (%eax),%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101362:	c1 e8 0c             	shr    $0xc,%eax
f0101365:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f010136b:	72 1c                	jb     f0101389 <page_lookup+0x52>
		panic("pa2page called with invalid pa");
f010136d:	c7 44 24 08 a4 75 10 	movl   $0xf01075a4,0x8(%esp)
f0101374:	f0 
f0101375:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f010137c:	00 
f010137d:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0101384:	e8 b7 ec ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f0101389:	8b 15 90 ce 1c f0    	mov    0xf01cce90,%edx
f010138f:	8d 04 c2             	lea    (%edx,%eax,8),%eax
f0101392:	eb 05                	jmp    f0101399 <page_lookup+0x62>
struct Page *
page_lookup(pde_t *pgdir, void *va, pte_t **pte_store)
{
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 0);
	if(page_table_entry == NULL) return NULL;
f0101394:	b8 00 00 00 00       	mov    $0x0,%eax
	*pte_store = page_table_entry;
	return pa2page(PTE_ADDR(*page_table_entry));
}
f0101399:	c9                   	leave  
f010139a:	c3                   	ret    

f010139b <tlb_invalidate>:
// Invalidate a TLB entry, but only if the page tables being
// edited are the ones currently in use by the processor.
//
void
tlb_invalidate(pde_t *pgdir, void *va)
{
f010139b:	55                   	push   %ebp
f010139c:	89 e5                	mov    %esp,%ebp
f010139e:	83 ec 08             	sub    $0x8,%esp
	// Flush the entry only if we're modifying the current address space.
	if (!curenv || curenv->env_pgdir == pgdir)
f01013a1:	e8 ed 50 00 00       	call   f0106493 <cpunum>
f01013a6:	6b c0 74             	imul   $0x74,%eax,%eax
f01013a9:	83 b8 28 d0 1c f0 00 	cmpl   $0x0,-0xfe32fd8(%eax)
f01013b0:	74 16                	je     f01013c8 <tlb_invalidate+0x2d>
f01013b2:	e8 dc 50 00 00       	call   f0106493 <cpunum>
f01013b7:	6b c0 74             	imul   $0x74,%eax,%eax
f01013ba:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f01013c0:	8b 55 08             	mov    0x8(%ebp),%edx
f01013c3:	39 50 60             	cmp    %edx,0x60(%eax)
f01013c6:	75 06                	jne    f01013ce <tlb_invalidate+0x33>
}

static __inline void 
invlpg(void *addr)
{ 
	__asm __volatile("invlpg (%0)" : : "r" (addr) : "memory");
f01013c8:	8b 45 0c             	mov    0xc(%ebp),%eax
f01013cb:	0f 01 38             	invlpg (%eax)
		invlpg(va);
}
f01013ce:	c9                   	leave  
f01013cf:	c3                   	ret    

f01013d0 <page_remove>:
// Hint: The TA solution is implemented using page_lookup,
// 	tlb_invalidate, and page_decref.
//
void
page_remove(pde_t *pgdir, void *va)
{
f01013d0:	55                   	push   %ebp
f01013d1:	89 e5                	mov    %esp,%ebp
f01013d3:	56                   	push   %esi
f01013d4:	53                   	push   %ebx
f01013d5:	83 ec 20             	sub    $0x20,%esp
f01013d8:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01013db:	8b 75 0c             	mov    0xc(%ebp),%esi
	// Fill this function in
	//cprintf("Now unmapping page that mapped to @%x\n", va);
	pte_t* page_table_entry = NULL;
f01013de:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)
	struct Page* page = page_lookup(pgdir, va, &page_table_entry);
f01013e5:	8d 45 f4             	lea    -0xc(%ebp),%eax
f01013e8:	89 44 24 08          	mov    %eax,0x8(%esp)
f01013ec:	89 74 24 04          	mov    %esi,0x4(%esp)
f01013f0:	89 1c 24             	mov    %ebx,(%esp)
f01013f3:	e8 3f ff ff ff       	call   f0101337 <page_lookup>
	// va is not mapped
	if(page_table_entry == NULL) return;
f01013f8:	83 7d f4 00          	cmpl   $0x0,-0xc(%ebp)
f01013fc:	74 1d                	je     f010141b <page_remove+0x4b>

	//decrease pp_ref
	page_decref(page);
f01013fe:	89 04 24             	mov    %eax,(%esp)
f0101401:	e8 bd fd ff ff       	call   f01011c3 <page_decref>

	// remove that entry in page table
	*page_table_entry = 0;
f0101406:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0101409:	c7 00 00 00 00 00    	movl   $0x0,(%eax)

	// refresh tlb
	tlb_invalidate(pgdir, va);
f010140f:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101413:	89 1c 24             	mov    %ebx,(%esp)
f0101416:	e8 80 ff ff ff       	call   f010139b <tlb_invalidate>


}
f010141b:	83 c4 20             	add    $0x20,%esp
f010141e:	5b                   	pop    %ebx
f010141f:	5e                   	pop    %esi
f0101420:	5d                   	pop    %ebp
f0101421:	c3                   	ret    

f0101422 <page_insert>:
// Hint: The TA solution is implemented using pgdir_walk, page_remove,
// and page2pa.
//
int
page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
{
f0101422:	55                   	push   %ebp
f0101423:	89 e5                	mov    %esp,%ebp
f0101425:	57                   	push   %edi
f0101426:	56                   	push   %esi
f0101427:	53                   	push   %ebx
f0101428:	83 ec 2c             	sub    $0x2c,%esp
f010142b:	8b 75 08             	mov    0x8(%ebp),%esi
f010142e:	8b 7d 0c             	mov    0xc(%ebp),%edi
f0101431:	8b 5d 10             	mov    0x10(%ebp),%ebx
	//cprintf("--- page_insert(): called to map page @%x to va %x.\n", page2pa(pp), va);
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 1);
f0101434:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010143b:	00 
f010143c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101440:	89 34 24             	mov    %esi,(%esp)
f0101443:	e8 9e fd ff ff       	call   f01011e6 <pgdir_walk>
	// Out of memory
	if(page_table_entry == NULL) return -E_NO_MEM;
f0101448:	85 c0                	test   %eax,%eax
f010144a:	74 7c                	je     f01014c8 <page_insert+0xa6>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010144c:	89 f8                	mov    %edi,%eax
f010144e:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f0101454:	c1 f8 03             	sar    $0x3,%eax
f0101457:	c1 e0 0c             	shl    $0xc,%eax
f010145a:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	// if the map is originally not existe
	/*
	if(((*page_table_entry) & PTE_P) == 0)
		(*page_table_entry) = page_pa | perm | PTE_P;
	*/
	pp->pp_ref += 1;
f010145d:	66 83 47 04 01       	addw   $0x1,0x4(%edi)
	page_remove(pgdir, va);
f0101462:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0101466:	89 34 24             	mov    %esi,(%esp)
f0101469:	e8 62 ff ff ff       	call   f01013d0 <page_remove>
	pde_t* page_dir_entry = &pgdir[PDX(va)];
f010146e:	89 d8                	mov    %ebx,%eax
f0101470:	c1 e8 16             	shr    $0x16,%eax
	pte_t* page_table = KADDR(PTE_ADDR(*page_dir_entry));
f0101473:	8b 04 86             	mov    (%esi,%eax,4),%eax
f0101476:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010147b:	89 c2                	mov    %eax,%edx
f010147d:	c1 ea 0c             	shr    $0xc,%edx
f0101480:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f0101486:	72 20                	jb     f01014a8 <page_insert+0x86>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101488:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010148c:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0101493:	f0 
f0101494:	c7 44 24 04 34 02 00 	movl   $0x234,0x4(%esp)
f010149b:	00 
f010149c:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01014a3:	e8 98 eb ff ff       	call   f0100040 <_panic>
	 page_table_entry = &page_table[PTX(va)];
f01014a8:	c1 eb 0c             	shr    $0xc,%ebx
f01014ab:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
	*(page_table_entry) = page_pa | perm | PTE_P;
f01014b1:	8b 55 14             	mov    0x14(%ebp),%edx
f01014b4:	83 ca 01             	or     $0x1,%edx
f01014b7:	0b 55 e4             	or     -0x1c(%ebp),%edx
f01014ba:	89 94 98 00 00 00 f0 	mov    %edx,-0x10000000(%eax,%ebx,4)

	return 0;
f01014c1:	b8 00 00 00 00       	mov    $0x0,%eax
f01014c6:	eb 05                	jmp    f01014cd <page_insert+0xab>
{
	//cprintf("--- page_insert(): called to map page @%x to va %x.\n", page2pa(pp), va);
	// Fill this function in
	pte_t* page_table_entry = pgdir_walk(pgdir, va, 1);
	// Out of memory
	if(page_table_entry == NULL) return -E_NO_MEM;
f01014c8:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
	pte_t* page_table = KADDR(PTE_ADDR(*page_dir_entry));
	 page_table_entry = &page_table[PTX(va)];
	*(page_table_entry) = page_pa | perm | PTE_P;

	return 0;
}
f01014cd:	83 c4 2c             	add    $0x2c,%esp
f01014d0:	5b                   	pop    %ebx
f01014d1:	5e                   	pop    %esi
f01014d2:	5f                   	pop    %edi
f01014d3:	5d                   	pop    %ebp
f01014d4:	c3                   	ret    

f01014d5 <mem_init>:
//
// From UTOP to ULIM, the user is allowed to read but not write.
// Above ULIM the user cannot read or write.
void
mem_init(void)
{
f01014d5:	55                   	push   %ebp
f01014d6:	89 e5                	mov    %esp,%ebp
f01014d8:	57                   	push   %edi
f01014d9:	56                   	push   %esi
f01014da:	53                   	push   %ebx
f01014db:	83 ec 4c             	sub    $0x4c,%esp
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f01014de:	c7 04 24 15 00 00 00 	movl   $0x15,(%esp)
f01014e5:	e8 19 26 00 00       	call   f0103b03 <mc146818_read>
f01014ea:	89 c3                	mov    %eax,%ebx
f01014ec:	c7 04 24 16 00 00 00 	movl   $0x16,(%esp)
f01014f3:	e8 0b 26 00 00       	call   f0103b03 <mc146818_read>
f01014f8:	c1 e0 08             	shl    $0x8,%eax
f01014fb:	09 c3                	or     %eax,%ebx
{
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
f01014fd:	89 d8                	mov    %ebx,%eax
f01014ff:	c1 e0 0a             	shl    $0xa,%eax
f0101502:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f0101508:	85 c0                	test   %eax,%eax
f010150a:	0f 48 c2             	cmovs  %edx,%eax
f010150d:	c1 f8 0c             	sar    $0xc,%eax
f0101510:	a3 44 c2 1c f0       	mov    %eax,0xf01cc244
// --------------------------------------------------------------

static int
nvram_read(int r)
{
	return mc146818_read(r) | (mc146818_read(r + 1) << 8);
f0101515:	c7 04 24 17 00 00 00 	movl   $0x17,(%esp)
f010151c:	e8 e2 25 00 00       	call   f0103b03 <mc146818_read>
f0101521:	89 c3                	mov    %eax,%ebx
f0101523:	c7 04 24 18 00 00 00 	movl   $0x18,(%esp)
f010152a:	e8 d4 25 00 00       	call   f0103b03 <mc146818_read>
f010152f:	c1 e0 08             	shl    $0x8,%eax
f0101532:	09 c3                	or     %eax,%ebx
	size_t npages_extmem;

	// Use CMOS calls to measure available base & extended memory.
	// (CMOS calls return results in kilobytes.)
	npages_basemem = (nvram_read(NVRAM_BASELO) * 1024) / PGSIZE;
	npages_extmem = (nvram_read(NVRAM_EXTLO) * 1024) / PGSIZE;
f0101534:	89 d8                	mov    %ebx,%eax
f0101536:	c1 e0 0a             	shl    $0xa,%eax
f0101539:	8d 90 ff 0f 00 00    	lea    0xfff(%eax),%edx
f010153f:	85 c0                	test   %eax,%eax
f0101541:	0f 48 c2             	cmovs  %edx,%eax
f0101544:	c1 f8 0c             	sar    $0xc,%eax

	// Calculate the number of physical pages available in both base
	// and extended memory.
	if (npages_extmem)
f0101547:	85 c0                	test   %eax,%eax
f0101549:	74 0e                	je     f0101559 <mem_init+0x84>
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
f010154b:	8d 90 00 01 00 00    	lea    0x100(%eax),%edx
f0101551:	89 15 88 ce 1c f0    	mov    %edx,0xf01cce88
f0101557:	eb 0c                	jmp    f0101565 <mem_init+0x90>
	else
		npages = npages_basemem;
f0101559:	8b 15 44 c2 1c f0    	mov    0xf01cc244,%edx
f010155f:	89 15 88 ce 1c f0    	mov    %edx,0xf01cce88

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
		npages_extmem * PGSIZE / 1024);
f0101565:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101568:	c1 e8 0a             	shr    $0xa,%eax
f010156b:	89 44 24 0c          	mov    %eax,0xc(%esp)
		npages * PGSIZE / 1024,
		npages_basemem * PGSIZE / 1024,
f010156f:	a1 44 c2 1c f0       	mov    0xf01cc244,%eax
f0101574:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101577:	c1 e8 0a             	shr    $0xa,%eax
f010157a:	89 44 24 08          	mov    %eax,0x8(%esp)
		npages * PGSIZE / 1024,
f010157e:	a1 88 ce 1c f0       	mov    0xf01cce88,%eax
f0101583:	c1 e0 0c             	shl    $0xc,%eax
	if (npages_extmem)
		npages = (EXTPHYSMEM / PGSIZE) + npages_extmem;
	else
		npages = npages_basemem;

	cprintf("Physical memory: %uK available, base = %uK, extended = %uK\n",
f0101586:	c1 e8 0a             	shr    $0xa,%eax
f0101589:	89 44 24 04          	mov    %eax,0x4(%esp)
f010158d:	c7 04 24 ec 75 10 f0 	movl   $0xf01075ec,(%esp)
f0101594:	e8 d6 26 00 00       	call   f0103c6f <cprintf>
	// Remove this line when you're ready to test this function.
	//panic("mem_init: This function is not finished\n");

	//////////////////////////////////////////////////////////////////////
	// create initial page directory.
	kern_pgdir = (pde_t *) boot_alloc(PGSIZE);
f0101599:	b8 00 10 00 00       	mov    $0x1000,%eax
f010159e:	e8 6d f5 ff ff       	call   f0100b10 <boot_alloc>
f01015a3:	a3 8c ce 1c f0       	mov    %eax,0xf01cce8c
	memset(kern_pgdir, 0, PGSIZE);
f01015a8:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01015af:	00 
f01015b0:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01015b7:	00 
f01015b8:	89 04 24             	mov    %eax,(%esp)
f01015bb:	e8 39 48 00 00       	call   f0105df9 <memset>
	// a virtual page table at virtual address UVPT.
	// (For now, you don't have understand the greater purpose of the
	// following two lines.)

	// Permissions: kernel R, user R
	kern_pgdir[PDX(UVPT)] = PADDR(kern_pgdir) | PTE_U | PTE_P;
f01015c0:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01015c5:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01015ca:	77 20                	ja     f01015ec <mem_init+0x117>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01015cc:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01015d0:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f01015d7:	f0 
f01015d8:	c7 44 24 04 95 00 00 	movl   $0x95,0x4(%esp)
f01015df:	00 
f01015e0:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01015e7:	e8 54 ea ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01015ec:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f01015f2:	83 ca 05             	or     $0x5,%edx
f01015f5:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate an array of npages 'struct Page's and store it in 'pages'.
	// The kernel uses this array to keep track of physical pages: for
	// each physical page, there is a corresponding struct Page in this
	// array.  'npages' is the number of physical pages in memory.
	// Your code goes here:
	pages = (struct Page *) boot_alloc(npages * sizeof(struct Page));
f01015fb:	a1 88 ce 1c f0       	mov    0xf01cce88,%eax
f0101600:	c1 e0 03             	shl    $0x3,%eax
f0101603:	e8 08 f5 ff ff       	call   f0100b10 <boot_alloc>
f0101608:	a3 90 ce 1c f0       	mov    %eax,0xf01cce90
	cprintf("struct Page size = %d", sizeof(struct Page));
f010160d:	c7 44 24 04 08 00 00 	movl   $0x8,0x4(%esp)
f0101614:	00 
f0101615:	c7 04 24 37 72 10 f0 	movl   $0xf0107237,(%esp)
f010161c:	e8 4e 26 00 00       	call   f0103c6f <cprintf>


	//////////////////////////////////////////////////////////////////////
	// Make 'envs' point to an array of size 'NENV' of 'struct Env'.
	// LAB 3: Your code here.
	envs = (struct Env *) boot_alloc(NENV * sizeof(struct Env));
f0101621:	b8 00 f0 01 00       	mov    $0x1f000,%eax
f0101626:	e8 e5 f4 ff ff       	call   f0100b10 <boot_alloc>
f010162b:	a3 48 c2 1c f0       	mov    %eax,0xf01cc248
	// Now that we've allocated the initial kernel data structures, we set
	// up the list of free physical pages. Once we've done so, all further
	// memory management will go through the page_* functions. In
	// particular, we can now map memory using boot_map_region
	// or page_insert
	page_init();
f0101630:	e8 e0 f9 ff ff       	call   f0101015 <page_init>

	check_page_free_list(1);
f0101635:	b8 01 00 00 00       	mov    $0x1,%eax
f010163a:	e8 f5 f5 ff ff       	call   f0100c34 <check_page_free_list>
	int nfree;
	struct Page *fl;
	char *c;
	int i;

	if (!pages)
f010163f:	83 3d 90 ce 1c f0 00 	cmpl   $0x0,0xf01cce90
f0101646:	75 1c                	jne    f0101664 <mem_init+0x18f>
		panic("'pages' is a null pointer!");
f0101648:	c7 44 24 08 4d 72 10 	movl   $0xf010724d,0x8(%esp)
f010164f:	f0 
f0101650:	c7 44 24 04 25 03 00 	movl   $0x325,0x4(%esp)
f0101657:	00 
f0101658:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010165f:	e8 dc e9 ff ff       	call   f0100040 <_panic>

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101664:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
f0101669:	85 c0                	test   %eax,%eax
f010166b:	74 10                	je     f010167d <mem_init+0x1a8>
f010166d:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;
f0101672:	83 c3 01             	add    $0x1,%ebx

	if (!pages)
		panic("'pages' is a null pointer!");

	// check number of free pages
	for (pp = page_free_list, nfree = 0; pp; pp = pp->pp_link)
f0101675:	8b 00                	mov    (%eax),%eax
f0101677:	85 c0                	test   %eax,%eax
f0101679:	75 f7                	jne    f0101672 <mem_init+0x19d>
f010167b:	eb 05                	jmp    f0101682 <mem_init+0x1ad>
f010167d:	bb 00 00 00 00       	mov    $0x0,%ebx
		++nfree;

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101682:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101689:	e8 7b fa ff ff       	call   f0101109 <page_alloc>
f010168e:	89 c7                	mov    %eax,%edi
f0101690:	85 c0                	test   %eax,%eax
f0101692:	75 24                	jne    f01016b8 <mem_init+0x1e3>
f0101694:	c7 44 24 0c 68 72 10 	movl   $0xf0107268,0xc(%esp)
f010169b:	f0 
f010169c:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01016a3:	f0 
f01016a4:	c7 44 24 04 2d 03 00 	movl   $0x32d,0x4(%esp)
f01016ab:	00 
f01016ac:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01016b3:	e8 88 e9 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01016b8:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016bf:	e8 45 fa ff ff       	call   f0101109 <page_alloc>
f01016c4:	89 c6                	mov    %eax,%esi
f01016c6:	85 c0                	test   %eax,%eax
f01016c8:	75 24                	jne    f01016ee <mem_init+0x219>
f01016ca:	c7 44 24 0c 7e 72 10 	movl   $0xf010727e,0xc(%esp)
f01016d1:	f0 
f01016d2:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01016d9:	f0 
f01016da:	c7 44 24 04 2e 03 00 	movl   $0x32e,0x4(%esp)
f01016e1:	00 
f01016e2:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01016e9:	e8 52 e9 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01016ee:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01016f5:	e8 0f fa ff ff       	call   f0101109 <page_alloc>
f01016fa:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01016fd:	85 c0                	test   %eax,%eax
f01016ff:	75 24                	jne    f0101725 <mem_init+0x250>
f0101701:	c7 44 24 0c 94 72 10 	movl   $0xf0107294,0xc(%esp)
f0101708:	f0 
f0101709:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101710:	f0 
f0101711:	c7 44 24 04 2f 03 00 	movl   $0x32f,0x4(%esp)
f0101718:	00 
f0101719:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101720:	e8 1b e9 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101725:	39 f7                	cmp    %esi,%edi
f0101727:	75 24                	jne    f010174d <mem_init+0x278>
f0101729:	c7 44 24 0c aa 72 10 	movl   $0xf01072aa,0xc(%esp)
f0101730:	f0 
f0101731:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101738:	f0 
f0101739:	c7 44 24 04 32 03 00 	movl   $0x332,0x4(%esp)
f0101740:	00 
f0101741:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101748:	e8 f3 e8 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010174d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101750:	39 c6                	cmp    %eax,%esi
f0101752:	74 04                	je     f0101758 <mem_init+0x283>
f0101754:	39 c7                	cmp    %eax,%edi
f0101756:	75 24                	jne    f010177c <mem_init+0x2a7>
f0101758:	c7 44 24 0c 28 76 10 	movl   $0xf0107628,0xc(%esp)
f010175f:	f0 
f0101760:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101767:	f0 
f0101768:	c7 44 24 04 33 03 00 	movl   $0x333,0x4(%esp)
f010176f:	00 
f0101770:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101777:	e8 c4 e8 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010177c:	8b 15 90 ce 1c f0    	mov    0xf01cce90,%edx
	assert(page2pa(pp0) < npages*PGSIZE);
f0101782:	a1 88 ce 1c f0       	mov    0xf01cce88,%eax
f0101787:	c1 e0 0c             	shl    $0xc,%eax
f010178a:	89 f9                	mov    %edi,%ecx
f010178c:	29 d1                	sub    %edx,%ecx
f010178e:	c1 f9 03             	sar    $0x3,%ecx
f0101791:	c1 e1 0c             	shl    $0xc,%ecx
f0101794:	39 c1                	cmp    %eax,%ecx
f0101796:	72 24                	jb     f01017bc <mem_init+0x2e7>
f0101798:	c7 44 24 0c bc 72 10 	movl   $0xf01072bc,0xc(%esp)
f010179f:	f0 
f01017a0:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01017a7:	f0 
f01017a8:	c7 44 24 04 34 03 00 	movl   $0x334,0x4(%esp)
f01017af:	00 
f01017b0:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01017b7:	e8 84 e8 ff ff       	call   f0100040 <_panic>
f01017bc:	89 f1                	mov    %esi,%ecx
f01017be:	29 d1                	sub    %edx,%ecx
f01017c0:	c1 f9 03             	sar    $0x3,%ecx
f01017c3:	c1 e1 0c             	shl    $0xc,%ecx
	assert(page2pa(pp1) < npages*PGSIZE);
f01017c6:	39 c8                	cmp    %ecx,%eax
f01017c8:	77 24                	ja     f01017ee <mem_init+0x319>
f01017ca:	c7 44 24 0c d9 72 10 	movl   $0xf01072d9,0xc(%esp)
f01017d1:	f0 
f01017d2:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01017d9:	f0 
f01017da:	c7 44 24 04 35 03 00 	movl   $0x335,0x4(%esp)
f01017e1:	00 
f01017e2:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01017e9:	e8 52 e8 ff ff       	call   f0100040 <_panic>
f01017ee:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01017f1:	29 d1                	sub    %edx,%ecx
f01017f3:	89 ca                	mov    %ecx,%edx
f01017f5:	c1 fa 03             	sar    $0x3,%edx
f01017f8:	c1 e2 0c             	shl    $0xc,%edx
	assert(page2pa(pp2) < npages*PGSIZE);
f01017fb:	39 d0                	cmp    %edx,%eax
f01017fd:	77 24                	ja     f0101823 <mem_init+0x34e>
f01017ff:	c7 44 24 0c f6 72 10 	movl   $0xf01072f6,0xc(%esp)
f0101806:	f0 
f0101807:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010180e:	f0 
f010180f:	c7 44 24 04 36 03 00 	movl   $0x336,0x4(%esp)
f0101816:	00 
f0101817:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010181e:	e8 1d e8 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101823:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
f0101828:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f010182b:	c7 05 40 c2 1c f0 00 	movl   $0x0,0xf01cc240
f0101832:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101835:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010183c:	e8 c8 f8 ff ff       	call   f0101109 <page_alloc>
f0101841:	85 c0                	test   %eax,%eax
f0101843:	74 24                	je     f0101869 <mem_init+0x394>
f0101845:	c7 44 24 0c 13 73 10 	movl   $0xf0107313,0xc(%esp)
f010184c:	f0 
f010184d:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101854:	f0 
f0101855:	c7 44 24 04 3d 03 00 	movl   $0x33d,0x4(%esp)
f010185c:	00 
f010185d:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101864:	e8 d7 e7 ff ff       	call   f0100040 <_panic>

	// free and re-allocate?
	page_free(pp0);
f0101869:	89 3c 24             	mov    %edi,(%esp)
f010186c:	e8 1a f9 ff ff       	call   f010118b <page_free>
	page_free(pp1);
f0101871:	89 34 24             	mov    %esi,(%esp)
f0101874:	e8 12 f9 ff ff       	call   f010118b <page_free>
	page_free(pp2);
f0101879:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010187c:	89 04 24             	mov    %eax,(%esp)
f010187f:	e8 07 f9 ff ff       	call   f010118b <page_free>
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101884:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010188b:	e8 79 f8 ff ff       	call   f0101109 <page_alloc>
f0101890:	89 c6                	mov    %eax,%esi
f0101892:	85 c0                	test   %eax,%eax
f0101894:	75 24                	jne    f01018ba <mem_init+0x3e5>
f0101896:	c7 44 24 0c 68 72 10 	movl   $0xf0107268,0xc(%esp)
f010189d:	f0 
f010189e:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01018a5:	f0 
f01018a6:	c7 44 24 04 44 03 00 	movl   $0x344,0x4(%esp)
f01018ad:	00 
f01018ae:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01018b5:	e8 86 e7 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f01018ba:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018c1:	e8 43 f8 ff ff       	call   f0101109 <page_alloc>
f01018c6:	89 c7                	mov    %eax,%edi
f01018c8:	85 c0                	test   %eax,%eax
f01018ca:	75 24                	jne    f01018f0 <mem_init+0x41b>
f01018cc:	c7 44 24 0c 7e 72 10 	movl   $0xf010727e,0xc(%esp)
f01018d3:	f0 
f01018d4:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01018db:	f0 
f01018dc:	c7 44 24 04 45 03 00 	movl   $0x345,0x4(%esp)
f01018e3:	00 
f01018e4:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01018eb:	e8 50 e7 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f01018f0:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01018f7:	e8 0d f8 ff ff       	call   f0101109 <page_alloc>
f01018fc:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01018ff:	85 c0                	test   %eax,%eax
f0101901:	75 24                	jne    f0101927 <mem_init+0x452>
f0101903:	c7 44 24 0c 94 72 10 	movl   $0xf0107294,0xc(%esp)
f010190a:	f0 
f010190b:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101912:	f0 
f0101913:	c7 44 24 04 46 03 00 	movl   $0x346,0x4(%esp)
f010191a:	00 
f010191b:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101922:	e8 19 e7 ff ff       	call   f0100040 <_panic>
	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101927:	39 fe                	cmp    %edi,%esi
f0101929:	75 24                	jne    f010194f <mem_init+0x47a>
f010192b:	c7 44 24 0c aa 72 10 	movl   $0xf01072aa,0xc(%esp)
f0101932:	f0 
f0101933:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010193a:	f0 
f010193b:	c7 44 24 04 48 03 00 	movl   $0x348,0x4(%esp)
f0101942:	00 
f0101943:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010194a:	e8 f1 e6 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f010194f:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101952:	39 c7                	cmp    %eax,%edi
f0101954:	74 04                	je     f010195a <mem_init+0x485>
f0101956:	39 c6                	cmp    %eax,%esi
f0101958:	75 24                	jne    f010197e <mem_init+0x4a9>
f010195a:	c7 44 24 0c 28 76 10 	movl   $0xf0107628,0xc(%esp)
f0101961:	f0 
f0101962:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101969:	f0 
f010196a:	c7 44 24 04 49 03 00 	movl   $0x349,0x4(%esp)
f0101971:	00 
f0101972:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101979:	e8 c2 e6 ff ff       	call   f0100040 <_panic>
	assert(!page_alloc(0));
f010197e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101985:	e8 7f f7 ff ff       	call   f0101109 <page_alloc>
f010198a:	85 c0                	test   %eax,%eax
f010198c:	74 24                	je     f01019b2 <mem_init+0x4dd>
f010198e:	c7 44 24 0c 13 73 10 	movl   $0xf0107313,0xc(%esp)
f0101995:	f0 
f0101996:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010199d:	f0 
f010199e:	c7 44 24 04 4a 03 00 	movl   $0x34a,0x4(%esp)
f01019a5:	00 
f01019a6:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01019ad:	e8 8e e6 ff ff       	call   f0100040 <_panic>
f01019b2:	89 f0                	mov    %esi,%eax
f01019b4:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f01019ba:	c1 f8 03             	sar    $0x3,%eax
f01019bd:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01019c0:	89 c2                	mov    %eax,%edx
f01019c2:	c1 ea 0c             	shr    $0xc,%edx
f01019c5:	3b 15 88 ce 1c f0    	cmp    0xf01cce88,%edx
f01019cb:	72 20                	jb     f01019ed <mem_init+0x518>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01019cd:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01019d1:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f01019d8:	f0 
f01019d9:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01019e0:	00 
f01019e1:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f01019e8:	e8 53 e6 ff ff       	call   f0100040 <_panic>

	// test flags
	memset(page2kva(pp0), 1, PGSIZE);
f01019ed:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01019f4:	00 
f01019f5:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f01019fc:	00 
	return (void *)(pa + KERNBASE);
f01019fd:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0101a02:	89 04 24             	mov    %eax,(%esp)
f0101a05:	e8 ef 43 00 00       	call   f0105df9 <memset>
	page_free(pp0);
f0101a0a:	89 34 24             	mov    %esi,(%esp)
f0101a0d:	e8 79 f7 ff ff       	call   f010118b <page_free>
	assert((pp = page_alloc(ALLOC_ZERO)));
f0101a12:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0101a19:	e8 eb f6 ff ff       	call   f0101109 <page_alloc>
f0101a1e:	85 c0                	test   %eax,%eax
f0101a20:	75 24                	jne    f0101a46 <mem_init+0x571>
f0101a22:	c7 44 24 0c 22 73 10 	movl   $0xf0107322,0xc(%esp)
f0101a29:	f0 
f0101a2a:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101a31:	f0 
f0101a32:	c7 44 24 04 4f 03 00 	movl   $0x34f,0x4(%esp)
f0101a39:	00 
f0101a3a:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101a41:	e8 fa e5 ff ff       	call   f0100040 <_panic>
	assert(pp && pp0 == pp);
f0101a46:	39 c6                	cmp    %eax,%esi
f0101a48:	74 24                	je     f0101a6e <mem_init+0x599>
f0101a4a:	c7 44 24 0c 40 73 10 	movl   $0xf0107340,0xc(%esp)
f0101a51:	f0 
f0101a52:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101a59:	f0 
f0101a5a:	c7 44 24 04 50 03 00 	movl   $0x350,0x4(%esp)
f0101a61:	00 
f0101a62:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101a69:	e8 d2 e5 ff ff       	call   f0100040 <_panic>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101a6e:	89 f2                	mov    %esi,%edx
f0101a70:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0101a76:	c1 fa 03             	sar    $0x3,%edx
f0101a79:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0101a7c:	89 d0                	mov    %edx,%eax
f0101a7e:	c1 e8 0c             	shr    $0xc,%eax
f0101a81:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f0101a87:	72 20                	jb     f0101aa9 <mem_init+0x5d4>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0101a89:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0101a8d:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0101a94:	f0 
f0101a95:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f0101a9c:	00 
f0101a9d:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0101aa4:	e8 97 e5 ff ff       	call   f0100040 <_panic>
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
		assert(c[i] == 0);
f0101aa9:	80 ba 00 00 00 f0 00 	cmpb   $0x0,-0x10000000(%edx)
f0101ab0:	75 11                	jne    f0101ac3 <mem_init+0x5ee>
f0101ab2:	8d 82 01 00 00 f0    	lea    -0xfffffff(%edx),%eax
f0101ab8:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f0101abe:	80 38 00             	cmpb   $0x0,(%eax)
f0101ac1:	74 24                	je     f0101ae7 <mem_init+0x612>
f0101ac3:	c7 44 24 0c 50 73 10 	movl   $0xf0107350,0xc(%esp)
f0101aca:	f0 
f0101acb:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101ad2:	f0 
f0101ad3:	c7 44 24 04 53 03 00 	movl   $0x353,0x4(%esp)
f0101ada:	00 
f0101adb:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101ae2:	e8 59 e5 ff ff       	call   f0100040 <_panic>
f0101ae7:	83 c0 01             	add    $0x1,%eax
	memset(page2kva(pp0), 1, PGSIZE);
	page_free(pp0);
	assert((pp = page_alloc(ALLOC_ZERO)));
	assert(pp && pp0 == pp);
	c = page2kva(pp);
	for (i = 0; i < PGSIZE; i++)
f0101aea:	39 d0                	cmp    %edx,%eax
f0101aec:	75 d0                	jne    f0101abe <mem_init+0x5e9>
		assert(c[i] == 0);

	// give free list back
	page_free_list = fl;
f0101aee:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0101af1:	a3 40 c2 1c f0       	mov    %eax,0xf01cc240

	// free the pages we took
	page_free(pp0);
f0101af6:	89 34 24             	mov    %esi,(%esp)
f0101af9:	e8 8d f6 ff ff       	call   f010118b <page_free>
	page_free(pp1);
f0101afe:	89 3c 24             	mov    %edi,(%esp)
f0101b01:	e8 85 f6 ff ff       	call   f010118b <page_free>
	page_free(pp2);
f0101b06:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101b09:	89 04 24             	mov    %eax,(%esp)
f0101b0c:	e8 7a f6 ff ff       	call   f010118b <page_free>

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b11:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
f0101b16:	85 c0                	test   %eax,%eax
f0101b18:	74 09                	je     f0101b23 <mem_init+0x64e>
		--nfree;
f0101b1a:	83 eb 01             	sub    $0x1,%ebx
	page_free(pp0);
	page_free(pp1);
	page_free(pp2);

	// number of free pages should be the same
	for (pp = page_free_list; pp; pp = pp->pp_link)
f0101b1d:	8b 00                	mov    (%eax),%eax
f0101b1f:	85 c0                	test   %eax,%eax
f0101b21:	75 f7                	jne    f0101b1a <mem_init+0x645>
		--nfree;
	assert(nfree == 0);
f0101b23:	85 db                	test   %ebx,%ebx
f0101b25:	74 24                	je     f0101b4b <mem_init+0x676>
f0101b27:	c7 44 24 0c 5a 73 10 	movl   $0xf010735a,0xc(%esp)
f0101b2e:	f0 
f0101b2f:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101b36:	f0 
f0101b37:	c7 44 24 04 60 03 00 	movl   $0x360,0x4(%esp)
f0101b3e:	00 
f0101b3f:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101b46:	e8 f5 e4 ff ff       	call   f0100040 <_panic>

	cprintf("check_page_alloc() succeeded!\n");
f0101b4b:	c7 04 24 48 76 10 f0 	movl   $0xf0107648,(%esp)
f0101b52:	e8 18 21 00 00       	call   f0103c6f <cprintf>
	int i;
	extern pde_t entry_pgdir[];

	// should be able to allocate three pages
	pp0 = pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0101b57:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b5e:	e8 a6 f5 ff ff       	call   f0101109 <page_alloc>
f0101b63:	89 c3                	mov    %eax,%ebx
f0101b65:	85 c0                	test   %eax,%eax
f0101b67:	75 24                	jne    f0101b8d <mem_init+0x6b8>
f0101b69:	c7 44 24 0c 68 72 10 	movl   $0xf0107268,0xc(%esp)
f0101b70:	f0 
f0101b71:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101b78:	f0 
f0101b79:	c7 44 24 04 c8 03 00 	movl   $0x3c8,0x4(%esp)
f0101b80:	00 
f0101b81:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101b88:	e8 b3 e4 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0101b8d:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101b94:	e8 70 f5 ff ff       	call   f0101109 <page_alloc>
f0101b99:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0101b9c:	85 c0                	test   %eax,%eax
f0101b9e:	75 24                	jne    f0101bc4 <mem_init+0x6ef>
f0101ba0:	c7 44 24 0c 7e 72 10 	movl   $0xf010727e,0xc(%esp)
f0101ba7:	f0 
f0101ba8:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101baf:	f0 
f0101bb0:	c7 44 24 04 c9 03 00 	movl   $0x3c9,0x4(%esp)
f0101bb7:	00 
f0101bb8:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101bbf:	e8 7c e4 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0101bc4:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101bcb:	e8 39 f5 ff ff       	call   f0101109 <page_alloc>
f0101bd0:	89 c6                	mov    %eax,%esi
f0101bd2:	85 c0                	test   %eax,%eax
f0101bd4:	75 24                	jne    f0101bfa <mem_init+0x725>
f0101bd6:	c7 44 24 0c 94 72 10 	movl   $0xf0107294,0xc(%esp)
f0101bdd:	f0 
f0101bde:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101be5:	f0 
f0101be6:	c7 44 24 04 ca 03 00 	movl   $0x3ca,0x4(%esp)
f0101bed:	00 
f0101bee:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101bf5:	e8 46 e4 ff ff       	call   f0100040 <_panic>

	assert(pp0);
	assert(pp1 && pp1 != pp0);
f0101bfa:	3b 5d d4             	cmp    -0x2c(%ebp),%ebx
f0101bfd:	75 24                	jne    f0101c23 <mem_init+0x74e>
f0101bff:	c7 44 24 0c aa 72 10 	movl   $0xf01072aa,0xc(%esp)
f0101c06:	f0 
f0101c07:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101c0e:	f0 
f0101c0f:	c7 44 24 04 cd 03 00 	movl   $0x3cd,0x4(%esp)
f0101c16:	00 
f0101c17:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101c1e:	e8 1d e4 ff ff       	call   f0100040 <_panic>
	assert(pp2 && pp2 != pp1 && pp2 != pp0);
f0101c23:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f0101c26:	74 04                	je     f0101c2c <mem_init+0x757>
f0101c28:	39 c3                	cmp    %eax,%ebx
f0101c2a:	75 24                	jne    f0101c50 <mem_init+0x77b>
f0101c2c:	c7 44 24 0c 28 76 10 	movl   $0xf0107628,0xc(%esp)
f0101c33:	f0 
f0101c34:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101c3b:	f0 
f0101c3c:	c7 44 24 04 ce 03 00 	movl   $0x3ce,0x4(%esp)
f0101c43:	00 
f0101c44:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101c4b:	e8 f0 e3 ff ff       	call   f0100040 <_panic>

	// temporarily steal the rest of the free pages
	fl = page_free_list;
f0101c50:	a1 40 c2 1c f0       	mov    0xf01cc240,%eax
f0101c55:	89 45 d0             	mov    %eax,-0x30(%ebp)
	page_free_list = 0;
f0101c58:	c7 05 40 c2 1c f0 00 	movl   $0x0,0xf01cc240
f0101c5f:	00 00 00 

	// should be no free memory
	assert(!page_alloc(0));
f0101c62:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101c69:	e8 9b f4 ff ff       	call   f0101109 <page_alloc>
f0101c6e:	85 c0                	test   %eax,%eax
f0101c70:	74 24                	je     f0101c96 <mem_init+0x7c1>
f0101c72:	c7 44 24 0c 13 73 10 	movl   $0xf0107313,0xc(%esp)
f0101c79:	f0 
f0101c7a:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101c81:	f0 
f0101c82:	c7 44 24 04 d5 03 00 	movl   $0x3d5,0x4(%esp)
f0101c89:	00 
f0101c8a:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101c91:	e8 aa e3 ff ff       	call   f0100040 <_panic>

	// there is no page allocated at address 0
	assert(page_lookup(kern_pgdir, (void *) 0x0, &ptep) == NULL);
f0101c96:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0101c99:	89 44 24 08          	mov    %eax,0x8(%esp)
f0101c9d:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0101ca4:	00 
f0101ca5:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0101caa:	89 04 24             	mov    %eax,(%esp)
f0101cad:	e8 85 f6 ff ff       	call   f0101337 <page_lookup>
f0101cb2:	85 c0                	test   %eax,%eax
f0101cb4:	74 24                	je     f0101cda <mem_init+0x805>
f0101cb6:	c7 44 24 0c 68 76 10 	movl   $0xf0107668,0xc(%esp)
f0101cbd:	f0 
f0101cbe:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101cc5:	f0 
f0101cc6:	c7 44 24 04 d8 03 00 	movl   $0x3d8,0x4(%esp)
f0101ccd:	00 
f0101cce:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101cd5:	e8 66 e3 ff ff       	call   f0100040 <_panic>

	// there is no free memory, so we can't allocate a page table
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) < 0);
f0101cda:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101ce1:	00 
f0101ce2:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101ce9:	00 
f0101cea:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101ced:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101cf1:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0101cf6:	89 04 24             	mov    %eax,(%esp)
f0101cf9:	e8 24 f7 ff ff       	call   f0101422 <page_insert>
f0101cfe:	85 c0                	test   %eax,%eax
f0101d00:	78 24                	js     f0101d26 <mem_init+0x851>
f0101d02:	c7 44 24 0c a0 76 10 	movl   $0xf01076a0,0xc(%esp)
f0101d09:	f0 
f0101d0a:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101d11:	f0 
f0101d12:	c7 44 24 04 db 03 00 	movl   $0x3db,0x4(%esp)
f0101d19:	00 
f0101d1a:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101d21:	e8 1a e3 ff ff       	call   f0100040 <_panic>

	// free pp0 and try again: pp0 should be used for page table
	page_free(pp0);
f0101d26:	89 1c 24             	mov    %ebx,(%esp)
f0101d29:	e8 5d f4 ff ff       	call   f010118b <page_free>
	assert(page_insert(kern_pgdir, pp1, 0x0, PTE_W) == 0);
f0101d2e:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101d35:	00 
f0101d36:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0101d3d:	00 
f0101d3e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101d41:	89 44 24 04          	mov    %eax,0x4(%esp)
f0101d45:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0101d4a:	89 04 24             	mov    %eax,(%esp)
f0101d4d:	e8 d0 f6 ff ff       	call   f0101422 <page_insert>
f0101d52:	85 c0                	test   %eax,%eax
f0101d54:	74 24                	je     f0101d7a <mem_init+0x8a5>
f0101d56:	c7 44 24 0c d0 76 10 	movl   $0xf01076d0,0xc(%esp)
f0101d5d:	f0 
f0101d5e:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101d65:	f0 
f0101d66:	c7 44 24 04 df 03 00 	movl   $0x3df,0x4(%esp)
f0101d6d:	00 
f0101d6e:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101d75:	e8 c6 e2 ff ff       	call   f0100040 <_panic>
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0101d7a:	8b 3d 8c ce 1c f0    	mov    0xf01cce8c,%edi
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0101d80:	a1 90 ce 1c f0       	mov    0xf01cce90,%eax
f0101d85:	89 45 cc             	mov    %eax,-0x34(%ebp)
f0101d88:	8b 17                	mov    (%edi),%edx
f0101d8a:	81 e2 00 f0 ff ff    	and    $0xfffff000,%edx
f0101d90:	89 d9                	mov    %ebx,%ecx
f0101d92:	29 c1                	sub    %eax,%ecx
f0101d94:	89 c8                	mov    %ecx,%eax
f0101d96:	c1 f8 03             	sar    $0x3,%eax
f0101d99:	c1 e0 0c             	shl    $0xc,%eax
f0101d9c:	39 c2                	cmp    %eax,%edx
f0101d9e:	74 24                	je     f0101dc4 <mem_init+0x8ef>
f0101da0:	c7 44 24 0c 00 77 10 	movl   $0xf0107700,0xc(%esp)
f0101da7:	f0 
f0101da8:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101daf:	f0 
f0101db0:	c7 44 24 04 e0 03 00 	movl   $0x3e0,0x4(%esp)
f0101db7:	00 
f0101db8:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101dbf:	e8 7c e2 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, 0x0) == page2pa(pp1));
f0101dc4:	ba 00 00 00 00       	mov    $0x0,%edx
f0101dc9:	89 f8                	mov    %edi,%eax
f0101dcb:	e8 f5 ed ff ff       	call   f0100bc5 <check_va2pa>
f0101dd0:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f0101dd3:	2b 55 cc             	sub    -0x34(%ebp),%edx
f0101dd6:	c1 fa 03             	sar    $0x3,%edx
f0101dd9:	c1 e2 0c             	shl    $0xc,%edx
f0101ddc:	39 d0                	cmp    %edx,%eax
f0101dde:	74 24                	je     f0101e04 <mem_init+0x92f>
f0101de0:	c7 44 24 0c 28 77 10 	movl   $0xf0107728,0xc(%esp)
f0101de7:	f0 
f0101de8:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101def:	f0 
f0101df0:	c7 44 24 04 e1 03 00 	movl   $0x3e1,0x4(%esp)
f0101df7:	00 
f0101df8:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101dff:	e8 3c e2 ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0101e04:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0101e07:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f0101e0c:	74 24                	je     f0101e32 <mem_init+0x95d>
f0101e0e:	c7 44 24 0c 65 73 10 	movl   $0xf0107365,0xc(%esp)
f0101e15:	f0 
f0101e16:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101e1d:	f0 
f0101e1e:	c7 44 24 04 e2 03 00 	movl   $0x3e2,0x4(%esp)
f0101e25:	00 
f0101e26:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101e2d:	e8 0e e2 ff ff       	call   f0100040 <_panic>
	assert(pp0->pp_ref == 1);
f0101e32:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0101e37:	74 24                	je     f0101e5d <mem_init+0x988>
f0101e39:	c7 44 24 0c 76 73 10 	movl   $0xf0107376,0xc(%esp)
f0101e40:	f0 
f0101e41:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101e48:	f0 
f0101e49:	c7 44 24 04 e3 03 00 	movl   $0x3e3,0x4(%esp)
f0101e50:	00 
f0101e51:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101e58:	e8 e3 e1 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because pp0 is already allocated for page table
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101e5d:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101e64:	00 
f0101e65:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101e6c:	00 
f0101e6d:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101e71:	89 3c 24             	mov    %edi,(%esp)
f0101e74:	e8 a9 f5 ff ff       	call   f0101422 <page_insert>
f0101e79:	85 c0                	test   %eax,%eax
f0101e7b:	74 24                	je     f0101ea1 <mem_init+0x9cc>
f0101e7d:	c7 44 24 0c 58 77 10 	movl   $0xf0107758,0xc(%esp)
f0101e84:	f0 
f0101e85:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101e8c:	f0 
f0101e8d:	c7 44 24 04 e6 03 00 	movl   $0x3e6,0x4(%esp)
f0101e94:	00 
f0101e95:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101e9c:	e8 9f e1 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101ea1:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101ea6:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0101eab:	e8 15 ed ff ff       	call   f0100bc5 <check_va2pa>
f0101eb0:	89 f2                	mov    %esi,%edx
f0101eb2:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0101eb8:	c1 fa 03             	sar    $0x3,%edx
f0101ebb:	c1 e2 0c             	shl    $0xc,%edx
f0101ebe:	39 d0                	cmp    %edx,%eax
f0101ec0:	74 24                	je     f0101ee6 <mem_init+0xa11>
f0101ec2:	c7 44 24 0c 94 77 10 	movl   $0xf0107794,0xc(%esp)
f0101ec9:	f0 
f0101eca:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101ed1:	f0 
f0101ed2:	c7 44 24 04 e7 03 00 	movl   $0x3e7,0x4(%esp)
f0101ed9:	00 
f0101eda:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101ee1:	e8 5a e1 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101ee6:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101eeb:	74 24                	je     f0101f11 <mem_init+0xa3c>
f0101eed:	c7 44 24 0c 87 73 10 	movl   $0xf0107387,0xc(%esp)
f0101ef4:	f0 
f0101ef5:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101efc:	f0 
f0101efd:	c7 44 24 04 e8 03 00 	movl   $0x3e8,0x4(%esp)
f0101f04:	00 
f0101f05:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101f0c:	e8 2f e1 ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f0101f11:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0101f18:	e8 ec f1 ff ff       	call   f0101109 <page_alloc>
f0101f1d:	85 c0                	test   %eax,%eax
f0101f1f:	74 24                	je     f0101f45 <mem_init+0xa70>
f0101f21:	c7 44 24 0c 13 73 10 	movl   $0xf0107313,0xc(%esp)
f0101f28:	f0 
f0101f29:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101f30:	f0 
f0101f31:	c7 44 24 04 eb 03 00 	movl   $0x3eb,0x4(%esp)
f0101f38:	00 
f0101f39:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101f40:	e8 fb e0 ff ff       	call   f0100040 <_panic>

	// should be able to map pp2 at PGSIZE because it's already there
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W) == 0);
f0101f45:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0101f4c:	00 
f0101f4d:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0101f54:	00 
f0101f55:	89 74 24 04          	mov    %esi,0x4(%esp)
f0101f59:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0101f5e:	89 04 24             	mov    %eax,(%esp)
f0101f61:	e8 bc f4 ff ff       	call   f0101422 <page_insert>
f0101f66:	85 c0                	test   %eax,%eax
f0101f68:	74 24                	je     f0101f8e <mem_init+0xab9>
f0101f6a:	c7 44 24 0c 58 77 10 	movl   $0xf0107758,0xc(%esp)
f0101f71:	f0 
f0101f72:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101f79:	f0 
f0101f7a:	c7 44 24 04 ee 03 00 	movl   $0x3ee,0x4(%esp)
f0101f81:	00 
f0101f82:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101f89:	e8 b2 e0 ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0101f8e:	ba 00 10 00 00       	mov    $0x1000,%edx
f0101f93:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0101f98:	e8 28 ec ff ff       	call   f0100bc5 <check_va2pa>
f0101f9d:	89 f2                	mov    %esi,%edx
f0101f9f:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0101fa5:	c1 fa 03             	sar    $0x3,%edx
f0101fa8:	c1 e2 0c             	shl    $0xc,%edx
f0101fab:	39 d0                	cmp    %edx,%eax
f0101fad:	74 24                	je     f0101fd3 <mem_init+0xafe>
f0101faf:	c7 44 24 0c 94 77 10 	movl   $0xf0107794,0xc(%esp)
f0101fb6:	f0 
f0101fb7:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101fbe:	f0 
f0101fbf:	c7 44 24 04 ef 03 00 	movl   $0x3ef,0x4(%esp)
f0101fc6:	00 
f0101fc7:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101fce:	e8 6d e0 ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f0101fd3:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0101fd8:	74 24                	je     f0101ffe <mem_init+0xb29>
f0101fda:	c7 44 24 0c 87 73 10 	movl   $0xf0107387,0xc(%esp)
f0101fe1:	f0 
f0101fe2:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0101fe9:	f0 
f0101fea:	c7 44 24 04 f0 03 00 	movl   $0x3f0,0x4(%esp)
f0101ff1:	00 
f0101ff2:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0101ff9:	e8 42 e0 ff ff       	call   f0100040 <_panic>

	// pp2 should NOT be on the free list
	// could happen in ref counts are handled sloppily in page_insert
	assert(!page_alloc(0));
f0101ffe:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102005:	e8 ff f0 ff ff       	call   f0101109 <page_alloc>
f010200a:	85 c0                	test   %eax,%eax
f010200c:	74 24                	je     f0102032 <mem_init+0xb5d>
f010200e:	c7 44 24 0c 13 73 10 	movl   $0xf0107313,0xc(%esp)
f0102015:	f0 
f0102016:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010201d:	f0 
f010201e:	c7 44 24 04 f4 03 00 	movl   $0x3f4,0x4(%esp)
f0102025:	00 
f0102026:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010202d:	e8 0e e0 ff ff       	call   f0100040 <_panic>

	// check that pgdir_walk returns a pointer to the pte
	ptep = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(PGSIZE)]));
f0102032:	8b 15 8c ce 1c f0    	mov    0xf01cce8c,%edx
f0102038:	8b 02                	mov    (%edx),%eax
f010203a:	25 00 f0 ff ff       	and    $0xfffff000,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010203f:	89 c1                	mov    %eax,%ecx
f0102041:	c1 e9 0c             	shr    $0xc,%ecx
f0102044:	3b 0d 88 ce 1c f0    	cmp    0xf01cce88,%ecx
f010204a:	72 20                	jb     f010206c <mem_init+0xb97>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f010204c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102050:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0102057:	f0 
f0102058:	c7 44 24 04 f7 03 00 	movl   $0x3f7,0x4(%esp)
f010205f:	00 
f0102060:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102067:	e8 d4 df ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f010206c:	2d 00 00 00 10       	sub    $0x10000000,%eax
f0102071:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	assert(pgdir_walk(kern_pgdir, (void*)PGSIZE, 0) == ptep+PTX(PGSIZE));
f0102074:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010207b:	00 
f010207c:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102083:	00 
f0102084:	89 14 24             	mov    %edx,(%esp)
f0102087:	e8 5a f1 ff ff       	call   f01011e6 <pgdir_walk>
f010208c:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f010208f:	8d 57 04             	lea    0x4(%edi),%edx
f0102092:	39 d0                	cmp    %edx,%eax
f0102094:	74 24                	je     f01020ba <mem_init+0xbe5>
f0102096:	c7 44 24 0c c4 77 10 	movl   $0xf01077c4,0xc(%esp)
f010209d:	f0 
f010209e:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01020a5:	f0 
f01020a6:	c7 44 24 04 f8 03 00 	movl   $0x3f8,0x4(%esp)
f01020ad:	00 
f01020ae:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01020b5:	e8 86 df ff ff       	call   f0100040 <_panic>

	// should be able to change permissions too.
	assert(page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W|PTE_U) == 0);
f01020ba:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01020c1:	00 
f01020c2:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f01020c9:	00 
f01020ca:	89 74 24 04          	mov    %esi,0x4(%esp)
f01020ce:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01020d3:	89 04 24             	mov    %eax,(%esp)
f01020d6:	e8 47 f3 ff ff       	call   f0101422 <page_insert>
f01020db:	85 c0                	test   %eax,%eax
f01020dd:	74 24                	je     f0102103 <mem_init+0xc2e>
f01020df:	c7 44 24 0c 04 78 10 	movl   $0xf0107804,0xc(%esp)
f01020e6:	f0 
f01020e7:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01020ee:	f0 
f01020ef:	c7 44 24 04 fb 03 00 	movl   $0x3fb,0x4(%esp)
f01020f6:	00 
f01020f7:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01020fe:	e8 3d df ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp2));
f0102103:	8b 3d 8c ce 1c f0    	mov    0xf01cce8c,%edi
f0102109:	ba 00 10 00 00       	mov    $0x1000,%edx
f010210e:	89 f8                	mov    %edi,%eax
f0102110:	e8 b0 ea ff ff       	call   f0100bc5 <check_va2pa>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102115:	89 f2                	mov    %esi,%edx
f0102117:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f010211d:	c1 fa 03             	sar    $0x3,%edx
f0102120:	c1 e2 0c             	shl    $0xc,%edx
f0102123:	39 d0                	cmp    %edx,%eax
f0102125:	74 24                	je     f010214b <mem_init+0xc76>
f0102127:	c7 44 24 0c 94 77 10 	movl   $0xf0107794,0xc(%esp)
f010212e:	f0 
f010212f:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102136:	f0 
f0102137:	c7 44 24 04 fc 03 00 	movl   $0x3fc,0x4(%esp)
f010213e:	00 
f010213f:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102146:	e8 f5 de ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010214b:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f0102150:	74 24                	je     f0102176 <mem_init+0xca1>
f0102152:	c7 44 24 0c 87 73 10 	movl   $0xf0107387,0xc(%esp)
f0102159:	f0 
f010215a:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102161:	f0 
f0102162:	c7 44 24 04 fd 03 00 	movl   $0x3fd,0x4(%esp)
f0102169:	00 
f010216a:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102171:	e8 ca de ff ff       	call   f0100040 <_panic>
	assert(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U);
f0102176:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010217d:	00 
f010217e:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102185:	00 
f0102186:	89 3c 24             	mov    %edi,(%esp)
f0102189:	e8 58 f0 ff ff       	call   f01011e6 <pgdir_walk>
f010218e:	f6 00 04             	testb  $0x4,(%eax)
f0102191:	75 24                	jne    f01021b7 <mem_init+0xce2>
f0102193:	c7 44 24 0c 44 78 10 	movl   $0xf0107844,0xc(%esp)
f010219a:	f0 
f010219b:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01021a2:	f0 
f01021a3:	c7 44 24 04 fe 03 00 	movl   $0x3fe,0x4(%esp)
f01021aa:	00 
f01021ab:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01021b2:	e8 89 de ff ff       	call   f0100040 <_panic>
	assert(kern_pgdir[0] & PTE_U);
f01021b7:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01021bc:	f6 00 04             	testb  $0x4,(%eax)
f01021bf:	75 24                	jne    f01021e5 <mem_init+0xd10>
f01021c1:	c7 44 24 0c 98 73 10 	movl   $0xf0107398,0xc(%esp)
f01021c8:	f0 
f01021c9:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01021d0:	f0 
f01021d1:	c7 44 24 04 ff 03 00 	movl   $0x3ff,0x4(%esp)
f01021d8:	00 
f01021d9:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01021e0:	e8 5b de ff ff       	call   f0100040 <_panic>

	// should not be able to map at PTSIZE because need free page for page table
	assert(page_insert(kern_pgdir, pp0, (void*) PTSIZE, PTE_W) < 0);
f01021e5:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f01021ec:	00 
f01021ed:	c7 44 24 08 00 00 40 	movl   $0x400000,0x8(%esp)
f01021f4:	00 
f01021f5:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01021f9:	89 04 24             	mov    %eax,(%esp)
f01021fc:	e8 21 f2 ff ff       	call   f0101422 <page_insert>
f0102201:	85 c0                	test   %eax,%eax
f0102203:	78 24                	js     f0102229 <mem_init+0xd54>
f0102205:	c7 44 24 0c 78 78 10 	movl   $0xf0107878,0xc(%esp)
f010220c:	f0 
f010220d:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102214:	f0 
f0102215:	c7 44 24 04 02 04 00 	movl   $0x402,0x4(%esp)
f010221c:	00 
f010221d:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102224:	e8 17 de ff ff       	call   f0100040 <_panic>

	// insert pp1 at PGSIZE (replacing pp2)
	assert(page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W) == 0);
f0102229:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102230:	00 
f0102231:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102238:	00 
f0102239:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010223c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102240:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102245:	89 04 24             	mov    %eax,(%esp)
f0102248:	e8 d5 f1 ff ff       	call   f0101422 <page_insert>
f010224d:	85 c0                	test   %eax,%eax
f010224f:	74 24                	je     f0102275 <mem_init+0xda0>
f0102251:	c7 44 24 0c b0 78 10 	movl   $0xf01078b0,0xc(%esp)
f0102258:	f0 
f0102259:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102260:	f0 
f0102261:	c7 44 24 04 05 04 00 	movl   $0x405,0x4(%esp)
f0102268:	00 
f0102269:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102270:	e8 cb dd ff ff       	call   f0100040 <_panic>
	assert(!(*pgdir_walk(kern_pgdir, (void*) PGSIZE, 0) & PTE_U));
f0102275:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f010227c:	00 
f010227d:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f0102284:	00 
f0102285:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f010228a:	89 04 24             	mov    %eax,(%esp)
f010228d:	e8 54 ef ff ff       	call   f01011e6 <pgdir_walk>
f0102292:	f6 00 04             	testb  $0x4,(%eax)
f0102295:	74 24                	je     f01022bb <mem_init+0xde6>
f0102297:	c7 44 24 0c ec 78 10 	movl   $0xf01078ec,0xc(%esp)
f010229e:	f0 
f010229f:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01022a6:	f0 
f01022a7:	c7 44 24 04 06 04 00 	movl   $0x406,0x4(%esp)
f01022ae:	00 
f01022af:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01022b6:	e8 85 dd ff ff       	call   f0100040 <_panic>

	// should have pp1 at both 0 and PGSIZE, pp2 nowhere, ...
	assert(check_va2pa(kern_pgdir, 0) == page2pa(pp1));
f01022bb:	8b 3d 8c ce 1c f0    	mov    0xf01cce8c,%edi
f01022c1:	ba 00 00 00 00       	mov    $0x0,%edx
f01022c6:	89 f8                	mov    %edi,%eax
f01022c8:	e8 f8 e8 ff ff       	call   f0100bc5 <check_va2pa>
f01022cd:	89 c1                	mov    %eax,%ecx
f01022cf:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01022d2:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f01022d5:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f01022db:	c1 f8 03             	sar    $0x3,%eax
f01022de:	c1 e0 0c             	shl    $0xc,%eax
f01022e1:	39 c1                	cmp    %eax,%ecx
f01022e3:	74 24                	je     f0102309 <mem_init+0xe34>
f01022e5:	c7 44 24 0c 24 79 10 	movl   $0xf0107924,0xc(%esp)
f01022ec:	f0 
f01022ed:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01022f4:	f0 
f01022f5:	c7 44 24 04 09 04 00 	movl   $0x409,0x4(%esp)
f01022fc:	00 
f01022fd:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102304:	e8 37 dd ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f0102309:	ba 00 10 00 00       	mov    $0x1000,%edx
f010230e:	89 f8                	mov    %edi,%eax
f0102310:	e8 b0 e8 ff ff       	call   f0100bc5 <check_va2pa>
f0102315:	39 45 cc             	cmp    %eax,-0x34(%ebp)
f0102318:	74 24                	je     f010233e <mem_init+0xe69>
f010231a:	c7 44 24 0c 50 79 10 	movl   $0xf0107950,0xc(%esp)
f0102321:	f0 
f0102322:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102329:	f0 
f010232a:	c7 44 24 04 0a 04 00 	movl   $0x40a,0x4(%esp)
f0102331:	00 
f0102332:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102339:	e8 02 dd ff ff       	call   f0100040 <_panic>
	// ... and ref counts should reflect this
	assert(pp1->pp_ref == 2);
f010233e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102341:	66 83 78 04 02       	cmpw   $0x2,0x4(%eax)
f0102346:	74 24                	je     f010236c <mem_init+0xe97>
f0102348:	c7 44 24 0c ae 73 10 	movl   $0xf01073ae,0xc(%esp)
f010234f:	f0 
f0102350:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102357:	f0 
f0102358:	c7 44 24 04 0c 04 00 	movl   $0x40c,0x4(%esp)
f010235f:	00 
f0102360:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102367:	e8 d4 dc ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f010236c:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102371:	74 24                	je     f0102397 <mem_init+0xec2>
f0102373:	c7 44 24 0c bf 73 10 	movl   $0xf01073bf,0xc(%esp)
f010237a:	f0 
f010237b:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102382:	f0 
f0102383:	c7 44 24 04 0d 04 00 	movl   $0x40d,0x4(%esp)
f010238a:	00 
f010238b:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102392:	e8 a9 dc ff ff       	call   f0100040 <_panic>

	// pp2 should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp2);
f0102397:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010239e:	e8 66 ed ff ff       	call   f0101109 <page_alloc>
f01023a3:	85 c0                	test   %eax,%eax
f01023a5:	74 04                	je     f01023ab <mem_init+0xed6>
f01023a7:	39 c6                	cmp    %eax,%esi
f01023a9:	74 24                	je     f01023cf <mem_init+0xefa>
f01023ab:	c7 44 24 0c 80 79 10 	movl   $0xf0107980,0xc(%esp)
f01023b2:	f0 
f01023b3:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01023ba:	f0 
f01023bb:	c7 44 24 04 10 04 00 	movl   $0x410,0x4(%esp)
f01023c2:	00 
f01023c3:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01023ca:	e8 71 dc ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at 0 should keep pp1 at PGSIZE
	page_remove(kern_pgdir, 0x0);
f01023cf:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01023d6:	00 
f01023d7:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01023dc:	89 04 24             	mov    %eax,(%esp)
f01023df:	e8 ec ef ff ff       	call   f01013d0 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01023e4:	8b 3d 8c ce 1c f0    	mov    0xf01cce8c,%edi
f01023ea:	ba 00 00 00 00       	mov    $0x0,%edx
f01023ef:	89 f8                	mov    %edi,%eax
f01023f1:	e8 cf e7 ff ff       	call   f0100bc5 <check_va2pa>
f01023f6:	83 f8 ff             	cmp    $0xffffffff,%eax
f01023f9:	74 24                	je     f010241f <mem_init+0xf4a>
f01023fb:	c7 44 24 0c a4 79 10 	movl   $0xf01079a4,0xc(%esp)
f0102402:	f0 
f0102403:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010240a:	f0 
f010240b:	c7 44 24 04 14 04 00 	movl   $0x414,0x4(%esp)
f0102412:	00 
f0102413:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010241a:	e8 21 dc ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == page2pa(pp1));
f010241f:	ba 00 10 00 00       	mov    $0x1000,%edx
f0102424:	89 f8                	mov    %edi,%eax
f0102426:	e8 9a e7 ff ff       	call   f0100bc5 <check_va2pa>
f010242b:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f010242e:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0102434:	c1 fa 03             	sar    $0x3,%edx
f0102437:	c1 e2 0c             	shl    $0xc,%edx
f010243a:	39 d0                	cmp    %edx,%eax
f010243c:	74 24                	je     f0102462 <mem_init+0xf8d>
f010243e:	c7 44 24 0c 50 79 10 	movl   $0xf0107950,0xc(%esp)
f0102445:	f0 
f0102446:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010244d:	f0 
f010244e:	c7 44 24 04 15 04 00 	movl   $0x415,0x4(%esp)
f0102455:	00 
f0102456:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010245d:	e8 de db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 1);
f0102462:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102465:	66 83 78 04 01       	cmpw   $0x1,0x4(%eax)
f010246a:	74 24                	je     f0102490 <mem_init+0xfbb>
f010246c:	c7 44 24 0c 65 73 10 	movl   $0xf0107365,0xc(%esp)
f0102473:	f0 
f0102474:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010247b:	f0 
f010247c:	c7 44 24 04 16 04 00 	movl   $0x416,0x4(%esp)
f0102483:	00 
f0102484:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010248b:	e8 b0 db ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102490:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f0102495:	74 24                	je     f01024bb <mem_init+0xfe6>
f0102497:	c7 44 24 0c bf 73 10 	movl   $0xf01073bf,0xc(%esp)
f010249e:	f0 
f010249f:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01024a6:	f0 
f01024a7:	c7 44 24 04 17 04 00 	movl   $0x417,0x4(%esp)
f01024ae:	00 
f01024af:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01024b6:	e8 85 db ff ff       	call   f0100040 <_panic>

	// unmapping pp1 at PGSIZE should free it
	page_remove(kern_pgdir, (void*) PGSIZE);
f01024bb:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01024c2:	00 
f01024c3:	89 3c 24             	mov    %edi,(%esp)
f01024c6:	e8 05 ef ff ff       	call   f01013d0 <page_remove>
	assert(check_va2pa(kern_pgdir, 0x0) == ~0);
f01024cb:	8b 3d 8c ce 1c f0    	mov    0xf01cce8c,%edi
f01024d1:	ba 00 00 00 00       	mov    $0x0,%edx
f01024d6:	89 f8                	mov    %edi,%eax
f01024d8:	e8 e8 e6 ff ff       	call   f0100bc5 <check_va2pa>
f01024dd:	83 f8 ff             	cmp    $0xffffffff,%eax
f01024e0:	74 24                	je     f0102506 <mem_init+0x1031>
f01024e2:	c7 44 24 0c a4 79 10 	movl   $0xf01079a4,0xc(%esp)
f01024e9:	f0 
f01024ea:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01024f1:	f0 
f01024f2:	c7 44 24 04 1b 04 00 	movl   $0x41b,0x4(%esp)
f01024f9:	00 
f01024fa:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102501:	e8 3a db ff ff       	call   f0100040 <_panic>
	assert(check_va2pa(kern_pgdir, PGSIZE) == ~0);
f0102506:	ba 00 10 00 00       	mov    $0x1000,%edx
f010250b:	89 f8                	mov    %edi,%eax
f010250d:	e8 b3 e6 ff ff       	call   f0100bc5 <check_va2pa>
f0102512:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102515:	74 24                	je     f010253b <mem_init+0x1066>
f0102517:	c7 44 24 0c c8 79 10 	movl   $0xf01079c8,0xc(%esp)
f010251e:	f0 
f010251f:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102526:	f0 
f0102527:	c7 44 24 04 1c 04 00 	movl   $0x41c,0x4(%esp)
f010252e:	00 
f010252f:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102536:	e8 05 db ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f010253b:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f010253e:	66 83 78 04 00       	cmpw   $0x0,0x4(%eax)
f0102543:	74 24                	je     f0102569 <mem_init+0x1094>
f0102545:	c7 44 24 0c d0 73 10 	movl   $0xf01073d0,0xc(%esp)
f010254c:	f0 
f010254d:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102554:	f0 
f0102555:	c7 44 24 04 1d 04 00 	movl   $0x41d,0x4(%esp)
f010255c:	00 
f010255d:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102564:	e8 d7 da ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 0);
f0102569:	66 83 7e 04 00       	cmpw   $0x0,0x4(%esi)
f010256e:	74 24                	je     f0102594 <mem_init+0x10bf>
f0102570:	c7 44 24 0c bf 73 10 	movl   $0xf01073bf,0xc(%esp)
f0102577:	f0 
f0102578:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010257f:	f0 
f0102580:	c7 44 24 04 1e 04 00 	movl   $0x41e,0x4(%esp)
f0102587:	00 
f0102588:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010258f:	e8 ac da ff ff       	call   f0100040 <_panic>

	// so it should be returned by page_alloc
	assert((pp = page_alloc(0)) && pp == pp1);
f0102594:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f010259b:	e8 69 eb ff ff       	call   f0101109 <page_alloc>
f01025a0:	85 c0                	test   %eax,%eax
f01025a2:	74 05                	je     f01025a9 <mem_init+0x10d4>
f01025a4:	39 45 d4             	cmp    %eax,-0x2c(%ebp)
f01025a7:	74 24                	je     f01025cd <mem_init+0x10f8>
f01025a9:	c7 44 24 0c f0 79 10 	movl   $0xf01079f0,0xc(%esp)
f01025b0:	f0 
f01025b1:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01025b8:	f0 
f01025b9:	c7 44 24 04 21 04 00 	movl   $0x421,0x4(%esp)
f01025c0:	00 
f01025c1:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01025c8:	e8 73 da ff ff       	call   f0100040 <_panic>

	// should be no free memory
	assert(!page_alloc(0));
f01025cd:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01025d4:	e8 30 eb ff ff       	call   f0101109 <page_alloc>
f01025d9:	85 c0                	test   %eax,%eax
f01025db:	74 24                	je     f0102601 <mem_init+0x112c>
f01025dd:	c7 44 24 0c 13 73 10 	movl   $0xf0107313,0xc(%esp)
f01025e4:	f0 
f01025e5:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01025ec:	f0 
f01025ed:	c7 44 24 04 24 04 00 	movl   $0x424,0x4(%esp)
f01025f4:	00 
f01025f5:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01025fc:	e8 3f da ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0102601:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102606:	8b 08                	mov    (%eax),%ecx
f0102608:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
f010260e:	89 da                	mov    %ebx,%edx
f0102610:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0102616:	c1 fa 03             	sar    $0x3,%edx
f0102619:	c1 e2 0c             	shl    $0xc,%edx
f010261c:	39 d1                	cmp    %edx,%ecx
f010261e:	74 24                	je     f0102644 <mem_init+0x116f>
f0102620:	c7 44 24 0c 00 77 10 	movl   $0xf0107700,0xc(%esp)
f0102627:	f0 
f0102628:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010262f:	f0 
f0102630:	c7 44 24 04 27 04 00 	movl   $0x427,0x4(%esp)
f0102637:	00 
f0102638:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010263f:	e8 fc d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0102644:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f010264a:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f010264f:	74 24                	je     f0102675 <mem_init+0x11a0>
f0102651:	c7 44 24 0c 76 73 10 	movl   $0xf0107376,0xc(%esp)
f0102658:	f0 
f0102659:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102660:	f0 
f0102661:	c7 44 24 04 29 04 00 	movl   $0x429,0x4(%esp)
f0102668:	00 
f0102669:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102670:	e8 cb d9 ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f0102675:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// check pointer arithmetic in pgdir_walk
	page_free(pp0);
f010267b:	89 1c 24             	mov    %ebx,(%esp)
f010267e:	e8 08 eb ff ff       	call   f010118b <page_free>
	va = (void*)(PGSIZE * NPDENTRIES + PGSIZE);
	ptep = pgdir_walk(kern_pgdir, va, 1);
f0102683:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f010268a:	00 
f010268b:	c7 44 24 04 00 10 40 	movl   $0x401000,0x4(%esp)
f0102692:	00 
f0102693:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102698:	89 04 24             	mov    %eax,(%esp)
f010269b:	e8 46 eb ff ff       	call   f01011e6 <pgdir_walk>
f01026a0:	89 45 cc             	mov    %eax,-0x34(%ebp)
f01026a3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	ptep1 = (pte_t *) KADDR(PTE_ADDR(kern_pgdir[PDX(va)]));
f01026a6:	8b 15 8c ce 1c f0    	mov    0xf01cce8c,%edx
f01026ac:	8b 7a 04             	mov    0x4(%edx),%edi
f01026af:	81 e7 00 f0 ff ff    	and    $0xfffff000,%edi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01026b5:	8b 0d 88 ce 1c f0    	mov    0xf01cce88,%ecx
f01026bb:	89 f8                	mov    %edi,%eax
f01026bd:	c1 e8 0c             	shr    $0xc,%eax
f01026c0:	39 c8                	cmp    %ecx,%eax
f01026c2:	72 20                	jb     f01026e4 <mem_init+0x120f>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01026c4:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f01026c8:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f01026cf:	f0 
f01026d0:	c7 44 24 04 30 04 00 	movl   $0x430,0x4(%esp)
f01026d7:	00 
f01026d8:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01026df:	e8 5c d9 ff ff       	call   f0100040 <_panic>
	assert(ptep == ptep1 + PTX(va));
f01026e4:	81 ef fc ff ff 0f    	sub    $0xffffffc,%edi
f01026ea:	39 7d cc             	cmp    %edi,-0x34(%ebp)
f01026ed:	74 24                	je     f0102713 <mem_init+0x123e>
f01026ef:	c7 44 24 0c e1 73 10 	movl   $0xf01073e1,0xc(%esp)
f01026f6:	f0 
f01026f7:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01026fe:	f0 
f01026ff:	c7 44 24 04 31 04 00 	movl   $0x431,0x4(%esp)
f0102706:	00 
f0102707:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010270e:	e8 2d d9 ff ff       	call   f0100040 <_panic>
	kern_pgdir[PDX(va)] = 0;
f0102713:	c7 42 04 00 00 00 00 	movl   $0x0,0x4(%edx)
	pp0->pp_ref = 0;
f010271a:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102720:	89 d8                	mov    %ebx,%eax
f0102722:	2b 05 90 ce 1c f0    	sub    0xf01cce90,%eax
f0102728:	c1 f8 03             	sar    $0x3,%eax
f010272b:	c1 e0 0c             	shl    $0xc,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010272e:	89 c2                	mov    %eax,%edx
f0102730:	c1 ea 0c             	shr    $0xc,%edx
f0102733:	39 d1                	cmp    %edx,%ecx
f0102735:	77 20                	ja     f0102757 <mem_init+0x1282>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0102737:	89 44 24 0c          	mov    %eax,0xc(%esp)
f010273b:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0102742:	f0 
f0102743:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f010274a:	00 
f010274b:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0102752:	e8 e9 d8 ff ff       	call   f0100040 <_panic>

	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
f0102757:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010275e:	00 
f010275f:	c7 44 24 04 ff 00 00 	movl   $0xff,0x4(%esp)
f0102766:	00 
	return (void *)(pa + KERNBASE);
f0102767:	2d 00 00 00 10       	sub    $0x10000000,%eax
f010276c:	89 04 24             	mov    %eax,(%esp)
f010276f:	e8 85 36 00 00       	call   f0105df9 <memset>
	page_free(pp0);
f0102774:	89 1c 24             	mov    %ebx,(%esp)
f0102777:	e8 0f ea ff ff       	call   f010118b <page_free>
	pgdir_walk(kern_pgdir, 0x0, 1);
f010277c:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0102783:	00 
f0102784:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f010278b:	00 
f010278c:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102791:	89 04 24             	mov    %eax,(%esp)
f0102794:	e8 4d ea ff ff       	call   f01011e6 <pgdir_walk>
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f0102799:	89 da                	mov    %ebx,%edx
f010279b:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f01027a1:	c1 fa 03             	sar    $0x3,%edx
f01027a4:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01027a7:	89 d0                	mov    %edx,%eax
f01027a9:	c1 e8 0c             	shr    $0xc,%eax
f01027ac:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f01027b2:	72 20                	jb     f01027d4 <mem_init+0x12ff>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01027b4:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01027b8:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f01027bf:	f0 
f01027c0:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01027c7:	00 
f01027c8:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f01027cf:	e8 6c d8 ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01027d4:	8d 82 00 00 00 f0    	lea    -0x10000000(%edx),%eax
	ptep = (pte_t *) page2kva(pp0);
f01027da:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	for(i=0; i<NPTENTRIES; i++)
		assert((ptep[i] & PTE_P) == 0);
f01027dd:	f6 82 00 00 00 f0 01 	testb  $0x1,-0x10000000(%edx)
f01027e4:	75 11                	jne    f01027f7 <mem_init+0x1322>
f01027e6:	8d 82 04 00 00 f0    	lea    -0xffffffc(%edx),%eax
f01027ec:	81 ea 00 f0 ff 0f    	sub    $0xffff000,%edx
f01027f2:	f6 00 01             	testb  $0x1,(%eax)
f01027f5:	74 24                	je     f010281b <mem_init+0x1346>
f01027f7:	c7 44 24 0c f9 73 10 	movl   $0xf01073f9,0xc(%esp)
f01027fe:	f0 
f01027ff:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102806:	f0 
f0102807:	c7 44 24 04 3b 04 00 	movl   $0x43b,0x4(%esp)
f010280e:	00 
f010280f:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102816:	e8 25 d8 ff ff       	call   f0100040 <_panic>
f010281b:	83 c0 04             	add    $0x4,%eax
	// check that new page tables get cleared
	memset(page2kva(pp0), 0xFF, PGSIZE);
	page_free(pp0);
	pgdir_walk(kern_pgdir, 0x0, 1);
	ptep = (pte_t *) page2kva(pp0);
	for(i=0; i<NPTENTRIES; i++)
f010281e:	39 d0                	cmp    %edx,%eax
f0102820:	75 d0                	jne    f01027f2 <mem_init+0x131d>
		assert((ptep[i] & PTE_P) == 0);
	kern_pgdir[0] = 0;
f0102822:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102827:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	pp0->pp_ref = 0;
f010282d:	66 c7 43 04 00 00    	movw   $0x0,0x4(%ebx)

	// give free list back
	page_free_list = fl;
f0102833:	8b 45 d0             	mov    -0x30(%ebp),%eax
f0102836:	a3 40 c2 1c f0       	mov    %eax,0xf01cc240

	// free the pages we took
	page_free(pp0);
f010283b:	89 1c 24             	mov    %ebx,(%esp)
f010283e:	e8 48 e9 ff ff       	call   f010118b <page_free>
	page_free(pp1);
f0102843:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0102846:	89 04 24             	mov    %eax,(%esp)
f0102849:	e8 3d e9 ff ff       	call   f010118b <page_free>
	page_free(pp2);
f010284e:	89 34 24             	mov    %esi,(%esp)
f0102851:	e8 35 e9 ff ff       	call   f010118b <page_free>

	cprintf("check_page() succeeded!\n");
f0102856:	c7 04 24 10 74 10 f0 	movl   $0xf0107410,(%esp)
f010285d:	e8 0d 14 00 00       	call   f0103c6f <cprintf>
	//    - the new image at UPAGES -- kernel R, user R
	//      (ie. perm = PTE_U | PTE_P)
	//    - pages itself -- kernel RW, user NONE
	// Your code goes here:
	//int page_insert(pde_t *pgdir, struct Page *pp, void *va, int perm)
	cprintf("Mapping pages array to [UPAGES, ....)\n");
f0102862:	c7 04 24 14 7a 10 f0 	movl   $0xf0107a14,(%esp)
f0102869:	e8 01 14 00 00       	call   f0103c6f <cprintf>
	size_t i;
	size_t to_map_pages;
	to_map_pages = (sizeof(struct Page) * npages - 1) / PGSIZE + 1;
f010286e:	a1 88 ce 1c f0       	mov    0xf01cce88,%eax
f0102873:	8d 0c c5 ff ff ff ff 	lea    -0x1(,%eax,8),%ecx
f010287a:	c1 e9 0c             	shr    $0xc,%ecx
f010287d:	83 c1 01             	add    $0x1,%ecx

	boot_map_region(kern_pgdir, UPAGES, to_map_pages * PGSIZE, PADDR(pages), PTE_U | PTE_P);
f0102880:	a1 90 ce 1c f0       	mov    0xf01cce90,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102885:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010288a:	77 20                	ja     f01028ac <mem_init+0x13d7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010288c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102890:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0102897:	f0 
f0102898:	c7 44 24 04 c2 00 00 	movl   $0xc2,0x4(%esp)
f010289f:	00 
f01028a0:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01028a7:	e8 94 d7 ff ff       	call   f0100040 <_panic>
f01028ac:	c1 e1 0c             	shl    $0xc,%ecx
f01028af:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f01028b6:	00 
	return (physaddr_t)kva - KERNBASE;
f01028b7:	05 00 00 00 10       	add    $0x10000000,%eax
f01028bc:	89 04 24             	mov    %eax,(%esp)
f01028bf:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f01028c4:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01028c9:	e8 01 ea ff ff       	call   f01012cf <boot_map_region>
	for(i = 0; i < to_map_pages; i++)
	{
		page_insert(kern_pgdir, pa2page(PADDR(pages) + i * PGSIZE), (void*)(UPAGES + i * PGSIZE), PTE_U | PTE_P);
		cprintf("Mapping page at physcial address from %x to virtual address %x\n", PADDR(pages) + i * PGSIZE, (UPAGES + i * PGSIZE));
	}*/
	cprintf("Map done.\n");
f01028ce:	c7 04 24 29 74 10 f0 	movl   $0xf0107429,(%esp)
f01028d5:	e8 95 13 00 00       	call   f0103c6f <cprintf>
	// (ie. perm = PTE_U | PTE_P).
	// Permissions:
	//    - the new image at UENVS  -- kernel R, user R
	//    - envs itself -- kernel RW, user NONE
	// LAB 3: Your code here.
	boot_map_region(kern_pgdir, UENVS, NENV * sizeof(struct Env), PADDR(envs), PTE_U | PTE_P);
f01028da:	a1 48 c2 1c f0       	mov    0xf01cc248,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01028df:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01028e4:	77 20                	ja     f0102906 <mem_init+0x1431>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01028e6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01028ea:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f01028f1:	f0 
f01028f2:	c7 44 24 04 d5 00 00 	movl   $0xd5,0x4(%esp)
f01028f9:	00 
f01028fa:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102901:	e8 3a d7 ff ff       	call   f0100040 <_panic>
f0102906:	c7 44 24 04 05 00 00 	movl   $0x5,0x4(%esp)
f010290d:	00 
	return (physaddr_t)kva - KERNBASE;
f010290e:	05 00 00 00 10       	add    $0x10000000,%eax
f0102913:	89 04 24             	mov    %eax,(%esp)
f0102916:	b9 00 f0 01 00       	mov    $0x1f000,%ecx
f010291b:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102920:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102925:	e8 a5 e9 ff ff       	call   f01012cf <boot_map_region>
	//       the kernel overflows its stack, it will fault rather than
	//       overwrite memory.  Known as a "guard page".
	//     Permissions: kernel RW, user NONE
	// Your code goes here:

	cprintf("Mapping Kernel STACK\n");
f010292a:	c7 04 24 34 74 10 f0 	movl   $0xf0107434,(%esp)
f0102931:	e8 39 13 00 00       	call   f0103c6f <cprintf>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102936:	b8 00 70 11 f0       	mov    $0xf0117000,%eax
f010293b:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102940:	77 20                	ja     f0102962 <mem_init+0x148d>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102942:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102946:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f010294d:	f0 
f010294e:	c7 44 24 04 e5 00 00 	movl   $0xe5,0x4(%esp)
f0102955:	00 
f0102956:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010295d:	e8 de d6 ff ff       	call   f0100040 <_panic>
	size_t to_map = KSTKSIZE / PGSIZE;
	boot_map_region(kern_pgdir, KSTACKTOP - KSTKSIZE, KSTKSIZE, PADDR(bootstack), PTE_W | PTE_P);
f0102962:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
f0102969:	00 
f010296a:	c7 04 24 00 70 11 00 	movl   $0x117000,(%esp)
f0102971:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102976:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f010297b:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102980:	e8 4a e9 ff ff       	call   f01012cf <boot_map_region>
	/*
	for(i = 0; i < to_map; i++)
	{
		page_insert(kern_pgdir, pa2page(PADDR(bootstack + i * PGSIZE)), (void*)(KSTACKTOP - KSTKSIZE + i * PGSIZE), PTE_W | PTE_P);
	}*/
	cprintf("Map done.\n");
f0102985:	c7 04 24 29 74 10 f0 	movl   $0xf0107429,(%esp)
f010298c:	e8 de 12 00 00       	call   f0103c6f <cprintf>
	// we just set up the mapping anyway.
	// Permissions: kernel RW, user NONE
	// Your code goes here:
	//static void
	//boot_map_region(pde_t *pgdir, uintptr_t va, size_t size, physaddr_t pa, int perm)
	cprintf("Mapping KERNBASE...\n");
f0102991:	c7 04 24 4a 74 10 f0 	movl   $0xf010744a,(%esp)
f0102998:	e8 d2 12 00 00       	call   f0103c6f <cprintf>
	size_t to_map_kernbase = (~0u- KERNBASE) / PGSIZE;
	cprintf("--- Mapping va [%x, %x] to pa [0, %x]\n", KERNBASE, ~0u, (to_map_kernbase - 1) * PGSIZE);
f010299d:	c7 44 24 0c 00 e0 ff 	movl   $0xfffe000,0xc(%esp)
f01029a4:	0f 
f01029a5:	c7 44 24 08 ff ff ff 	movl   $0xffffffff,0x8(%esp)
f01029ac:	ff 
f01029ad:	c7 44 24 04 00 00 00 	movl   $0xf0000000,0x4(%esp)
f01029b4:	f0 
f01029b5:	c7 04 24 3c 7a 10 f0 	movl   $0xf0107a3c,(%esp)
f01029bc:	e8 ae 12 00 00       	call   f0103c6f <cprintf>
		if(i >= npages)
			break;
		page_insert(kern_pgdir, pa2page(i * PGSIZE), (void*)(KERNBASE + i * PGSIZE), PTE_W | PTE_P);
	}
	*/
	boot_map_region(kern_pgdir, KERNBASE, to_map_kernbase * PGSIZE, 0, PTE_W | PTE_P);
f01029c1:	c7 44 24 04 03 00 00 	movl   $0x3,0x4(%esp)
f01029c8:	00 
f01029c9:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f01029d0:	b9 00 f0 ff 0f       	mov    $0xffff000,%ecx
f01029d5:	ba 00 00 00 f0       	mov    $0xf0000000,%edx
f01029da:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01029df:	e8 eb e8 ff ff       	call   f01012cf <boot_map_region>
	cprintf("Map done.\n");
f01029e4:	c7 04 24 29 74 10 f0 	movl   $0xf0107429,(%esp)
f01029eb:	e8 7f 12 00 00       	call   f0103c6f <cprintf>
static void
mem_init_mp(void)
{
	// Create a direct mapping at the top of virtual address space starting
	// at IOMEMBASE for accessing the LAPIC unit using memory-mapped I/O.
	boot_map_region(kern_pgdir, IOMEMBASE, -IOMEMBASE, IOMEM_PADDR, PTE_W);
f01029f0:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01029f7:	00 
f01029f8:	c7 04 24 00 00 00 fe 	movl   $0xfe000000,(%esp)
f01029ff:	b9 00 00 00 02       	mov    $0x2000000,%ecx
f0102a04:	ba 00 00 00 fe       	mov    $0xfe000000,%edx
f0102a09:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102a0e:	e8 bc e8 ff ff       	call   f01012cf <boot_map_region>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102a13:	b8 00 e0 1c f0       	mov    $0xf01ce000,%eax
f0102a18:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102a1d:	0f 87 9d 07 00 00    	ja     f01031c0 <mem_init+0x1ceb>
f0102a23:	eb 0d                	jmp    f0102a32 <mem_init+0x155d>
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
f0102a25:	89 d8                	mov    %ebx,%eax
f0102a27:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102a2d:	77 28                	ja     f0102a57 <mem_init+0x1582>
f0102a2f:	90                   	nop
f0102a30:	eb 05                	jmp    f0102a37 <mem_init+0x1562>
f0102a32:	b8 00 e0 1c f0       	mov    $0xf01ce000,%eax
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102a37:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102a3b:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0102a42:	f0 
f0102a43:	c7 44 24 04 45 01 00 	movl   $0x145,0x4(%esp)
f0102a4a:	00 
f0102a4b:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102a52:	e8 e9 d5 ff ff       	call   f0100040 <_panic>
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f0102a57:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102a5e:	00 
f0102a5f:	8d 83 00 00 00 10    	lea    0x10000000(%ebx),%eax
f0102a65:	89 04 24             	mov    %eax,(%esp)
f0102a68:	b9 00 80 00 00       	mov    $0x8000,%ecx
f0102a6d:	89 f2                	mov    %esi,%edx
f0102a6f:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102a74:	e8 56 e8 ff ff       	call   f01012cf <boot_map_region>
f0102a79:	81 c3 00 80 00 00    	add    $0x8000,%ebx
f0102a7f:	81 ee 00 00 01 00    	sub    $0x10000,%esi
	//
	// LAB 4: Your code here:
	int cpu_i;
	uintptr_t stk_i;
	physaddr_t stk_phy_i;
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
f0102a85:	39 fb                	cmp    %edi,%ebx
f0102a87:	75 9c                	jne    f0102a25 <mem_init+0x1550>
check_kern_pgdir(void)
{
	uint32_t i, n;
	pde_t *pgdir;

	pgdir = kern_pgdir;
f0102a89:	8b 35 8c ce 1c f0    	mov    0xf01cce8c,%esi

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
f0102a8f:	a1 88 ce 1c f0       	mov    0xf01cce88,%eax
f0102a94:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f0102a97:	8d 04 c5 ff 0f 00 00 	lea    0xfff(,%eax,8),%eax
	for (i = 0; i < n; i += PGSIZE)
f0102a9e:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0102aa3:	89 45 d0             	mov    %eax,-0x30(%ebp)
f0102aa6:	75 30                	jne    f0102ad8 <mem_init+0x1603>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102aa8:	8b 1d 48 c2 1c f0    	mov    0xf01cc248,%ebx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102aae:	89 df                	mov    %ebx,%edi
f0102ab0:	ba 00 00 c0 ee       	mov    $0xeec00000,%edx
f0102ab5:	89 f0                	mov    %esi,%eax
f0102ab7:	e8 09 e1 ff ff       	call   f0100bc5 <check_va2pa>
f0102abc:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102ac2:	0f 86 94 00 00 00    	jbe    f0102b5c <mem_init+0x1687>
f0102ac8:	bb 00 00 c0 ee       	mov    $0xeec00000,%ebx
f0102acd:	81 c7 00 00 40 21    	add    $0x21400000,%edi
f0102ad3:	e9 a4 00 00 00       	jmp    f0102b7c <mem_init+0x16a7>
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102ad8:	8b 1d 90 ce 1c f0    	mov    0xf01cce90,%ebx
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
	return (physaddr_t)kva - KERNBASE;
f0102ade:	8d bb 00 00 00 10    	lea    0x10000000(%ebx),%edi
f0102ae4:	ba 00 00 00 ef       	mov    $0xef000000,%edx
f0102ae9:	89 f0                	mov    %esi,%eax
f0102aeb:	e8 d5 e0 ff ff       	call   f0100bc5 <check_va2pa>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102af0:	81 fb ff ff ff ef    	cmp    $0xefffffff,%ebx
f0102af6:	77 20                	ja     f0102b18 <mem_init+0x1643>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102af8:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102afc:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0102b03:	f0 
f0102b04:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102b0b:	00 
f0102b0c:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102b13:	e8 28 d5 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102b18:	ba 00 00 00 00       	mov    $0x0,%edx
f0102b1d:	8d 0c 17             	lea    (%edi,%edx,1),%ecx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f0102b20:	39 c8                	cmp    %ecx,%eax
f0102b22:	74 24                	je     f0102b48 <mem_init+0x1673>
f0102b24:	c7 44 24 0c 64 7a 10 	movl   $0xf0107a64,0xc(%esp)
f0102b2b:	f0 
f0102b2c:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102b33:	f0 
f0102b34:	c7 44 24 04 78 03 00 	movl   $0x378,0x4(%esp)
f0102b3b:	00 
f0102b3c:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102b43:	e8 f8 d4 ff ff       	call   f0100040 <_panic>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102b48:	8d 9a 00 10 00 00    	lea    0x1000(%edx),%ebx
f0102b4e:	39 5d d0             	cmp    %ebx,-0x30(%ebp)
f0102b51:	0f 87 be 06 00 00    	ja     f0103215 <mem_init+0x1d40>
f0102b57:	e9 4c ff ff ff       	jmp    f0102aa8 <mem_init+0x15d3>
f0102b5c:	89 5c 24 0c          	mov    %ebx,0xc(%esp)
f0102b60:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0102b67:	f0 
f0102b68:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0102b6f:	00 
f0102b70:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102b77:	e8 c4 d4 ff ff       	call   f0100040 <_panic>
f0102b7c:	8d 14 1f             	lea    (%edi,%ebx,1),%edx
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0102b7f:	39 c2                	cmp    %eax,%edx
f0102b81:	74 24                	je     f0102ba7 <mem_init+0x16d2>
f0102b83:	c7 44 24 0c 98 7a 10 	movl   $0xf0107a98,0xc(%esp)
f0102b8a:	f0 
f0102b8b:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102b92:	f0 
f0102b93:	c7 44 24 04 7d 03 00 	movl   $0x37d,0x4(%esp)
f0102b9a:	00 
f0102b9b:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102ba2:	e8 99 d4 ff ff       	call   f0100040 <_panic>
f0102ba7:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0102bad:	81 fb 00 f0 c1 ee    	cmp    $0xeec1f000,%ebx
f0102bb3:	0f 85 4c 06 00 00    	jne    f0103205 <mem_init+0x1d30>
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102bb9:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0102bbc:	c1 e7 0c             	shl    $0xc,%edi
f0102bbf:	bb 00 00 00 00       	mov    $0x0,%ebx
f0102bc4:	85 ff                	test   %edi,%edi
f0102bc6:	75 07                	jne    f0102bcf <mem_init+0x16fa>
f0102bc8:	bb 00 00 00 fe       	mov    $0xfe000000,%ebx
f0102bcd:	eb 41                	jmp    f0102c10 <mem_init+0x173b>
f0102bcf:	8d 93 00 00 00 f0    	lea    -0x10000000(%ebx),%edx
		assert(check_va2pa(pgdir, KERNBASE + i) == i);
f0102bd5:	89 f0                	mov    %esi,%eax
f0102bd7:	e8 e9 df ff ff       	call   f0100bc5 <check_va2pa>
f0102bdc:	39 c3                	cmp    %eax,%ebx
f0102bde:	74 24                	je     f0102c04 <mem_init+0x172f>
f0102be0:	c7 44 24 0c cc 7a 10 	movl   $0xf0107acc,0xc(%esp)
f0102be7:	f0 
f0102be8:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102bef:	f0 
f0102bf0:	c7 44 24 04 81 03 00 	movl   $0x381,0x4(%esp)
f0102bf7:	00 
f0102bf8:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102bff:	e8 3c d4 ff ff       	call   f0100040 <_panic>
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);

	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
f0102c04:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102c0a:	39 df                	cmp    %ebx,%edi
f0102c0c:	77 c1                	ja     f0102bcf <mem_init+0x16fa>
f0102c0e:	eb b8                	jmp    f0102bc8 <mem_init+0x16f3>
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);
f0102c10:	89 da                	mov    %ebx,%edx
f0102c12:	89 f0                	mov    %esi,%eax
f0102c14:	e8 ac df ff ff       	call   f0100bc5 <check_va2pa>
f0102c19:	39 c3                	cmp    %eax,%ebx
f0102c1b:	74 24                	je     f0102c41 <mem_init+0x176c>
f0102c1d:	c7 44 24 0c 5f 74 10 	movl   $0xf010745f,0xc(%esp)
f0102c24:	f0 
f0102c25:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102c2c:	f0 
f0102c2d:	c7 44 24 04 85 03 00 	movl   $0x385,0x4(%esp)
f0102c34:	00 
f0102c35:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102c3c:	e8 ff d3 ff ff       	call   f0100040 <_panic>
	// check phys mem
	for (i = 0; i < npages * PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, KERNBASE + i) == i);

	// check IO mem (new in lab 4)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
f0102c41:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f0102c47:	81 fb 00 f0 ff ff    	cmp    $0xfffff000,%ebx
f0102c4d:	75 c1                	jne    f0102c10 <mem_init+0x173b>
f0102c4f:	c7 45 d0 00 e0 1c f0 	movl   $0xf01ce000,-0x30(%ebp)
f0102c56:	c7 45 d4 00 00 00 00 	movl   $0x0,-0x2c(%ebp)
f0102c5d:	bf 00 80 bf ef       	mov    $0xefbf8000,%edi
f0102c62:	b8 00 e0 1c f0       	mov    $0xf01ce000,%eax
f0102c67:	05 00 80 40 20       	add    $0x20408000,%eax
f0102c6c:	89 45 c4             	mov    %eax,-0x3c(%ebp)
f0102c6f:	8d 87 00 80 00 00    	lea    0x8000(%edi),%eax
f0102c75:	89 45 cc             	mov    %eax,-0x34(%ebp)
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f0102c78:	89 fa                	mov    %edi,%edx
f0102c7a:	89 f0                	mov    %esi,%eax
f0102c7c:	e8 44 df ff ff       	call   f0100bc5 <check_va2pa>
f0102c81:	8b 4d d0             	mov    -0x30(%ebp),%ecx
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102c84:	81 f9 ff ff ff ef    	cmp    $0xefffffff,%ecx
f0102c8a:	77 20                	ja     f0102cac <mem_init+0x17d7>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102c8c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0102c90:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0102c97:	f0 
f0102c98:	c7 44 24 04 8d 03 00 	movl   $0x38d,0x4(%esp)
f0102c9f:	00 
f0102ca0:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102ca7:	e8 94 d3 ff ff       	call   f0100040 <_panic>
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0102cac:	89 fb                	mov    %edi,%ebx
f0102cae:	8b 4d c4             	mov    -0x3c(%ebp),%ecx
f0102cb1:	03 4d d4             	add    -0x2c(%ebp),%ecx
f0102cb4:	89 4d c8             	mov    %ecx,-0x38(%ebp)
f0102cb7:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f0102cba:	8d 14 19             	lea    (%ecx,%ebx,1),%edx
f0102cbd:	39 c2                	cmp    %eax,%edx
f0102cbf:	74 24                	je     f0102ce5 <mem_init+0x1810>
f0102cc1:	c7 44 24 0c f4 7a 10 	movl   $0xf0107af4,0xc(%esp)
f0102cc8:	f0 
f0102cc9:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102cd0:	f0 
f0102cd1:	c7 44 24 04 8d 03 00 	movl   $0x38d,0x4(%esp)
f0102cd8:	00 
f0102cd9:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102ce0:	e8 5b d3 ff ff       	call   f0100040 <_panic>
f0102ce5:	81 c3 00 10 00 00    	add    $0x1000,%ebx

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
f0102ceb:	3b 5d cc             	cmp    -0x34(%ebp),%ebx
f0102cee:	0f 85 03 05 00 00    	jne    f01031f7 <mem_init+0x1d22>
f0102cf4:	8d 9f 00 80 ff ff    	lea    -0x8000(%edi),%ebx
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
f0102cfa:	89 da                	mov    %ebx,%edx
f0102cfc:	89 f0                	mov    %esi,%eax
f0102cfe:	e8 c2 de ff ff       	call   f0100bc5 <check_va2pa>
f0102d03:	83 f8 ff             	cmp    $0xffffffff,%eax
f0102d06:	74 24                	je     f0102d2c <mem_init+0x1857>
f0102d08:	c7 44 24 0c 3c 7b 10 	movl   $0xf0107b3c,0xc(%esp)
f0102d0f:	f0 
f0102d10:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102d17:	f0 
f0102d18:	c7 44 24 04 8f 03 00 	movl   $0x38f,0x4(%esp)
f0102d1f:	00 
f0102d20:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102d27:	e8 14 d3 ff ff       	call   f0100040 <_panic>
f0102d2c:	81 c3 00 10 00 00    	add    $0x1000,%ebx
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
				== PADDR(percpu_kstacks[n]) + i);
		for (i = 0; i < KSTKGAP; i += PGSIZE)
f0102d32:	39 fb                	cmp    %edi,%ebx
f0102d34:	75 c4                	jne    f0102cfa <mem_init+0x1825>
f0102d36:	81 ef 00 00 01 00    	sub    $0x10000,%edi
f0102d3c:	81 45 d4 00 80 01 00 	addl   $0x18000,-0x2c(%ebp)
f0102d43:	81 45 d0 00 80 00 00 	addl   $0x8000,-0x30(%ebp)
	for (i = IOMEMBASE; i < -PGSIZE; i += PGSIZE)
		assert(check_va2pa(pgdir, i) == i);

	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
f0102d4a:	81 ff 00 80 b7 ef    	cmp    $0xefb78000,%edi
f0102d50:	0f 85 19 ff ff ff    	jne    f0102c6f <mem_init+0x179a>
f0102d56:	b8 00 00 00 00       	mov    $0x0,%eax
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
		switch (i) {
f0102d5b:	8d 90 45 fc ff ff    	lea    -0x3bb(%eax),%edx
f0102d61:	83 fa 03             	cmp    $0x3,%edx
f0102d64:	77 2e                	ja     f0102d94 <mem_init+0x18bf>
		case PDX(UVPT):
		case PDX(KSTACKTOP-1):
		case PDX(UPAGES):
		case PDX(UENVS):
			assert(pgdir[i] & PTE_P);
f0102d66:	f6 04 86 01          	testb  $0x1,(%esi,%eax,4)
f0102d6a:	0f 85 aa 00 00 00    	jne    f0102e1a <mem_init+0x1945>
f0102d70:	c7 44 24 0c 7a 74 10 	movl   $0xf010747a,0xc(%esp)
f0102d77:	f0 
f0102d78:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102d7f:	f0 
f0102d80:	c7 44 24 04 99 03 00 	movl   $0x399,0x4(%esp)
f0102d87:	00 
f0102d88:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102d8f:	e8 ac d2 ff ff       	call   f0100040 <_panic>
			break;
		default:
			if (i >= PDX(KERNBASE)) {
f0102d94:	3d bf 03 00 00       	cmp    $0x3bf,%eax
f0102d99:	76 55                	jbe    f0102df0 <mem_init+0x191b>
				assert(pgdir[i] & PTE_P);
f0102d9b:	8b 14 86             	mov    (%esi,%eax,4),%edx
f0102d9e:	f6 c2 01             	test   $0x1,%dl
f0102da1:	75 24                	jne    f0102dc7 <mem_init+0x18f2>
f0102da3:	c7 44 24 0c 7a 74 10 	movl   $0xf010747a,0xc(%esp)
f0102daa:	f0 
f0102dab:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102db2:	f0 
f0102db3:	c7 44 24 04 9d 03 00 	movl   $0x39d,0x4(%esp)
f0102dba:	00 
f0102dbb:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102dc2:	e8 79 d2 ff ff       	call   f0100040 <_panic>
				assert(pgdir[i] & PTE_W);
f0102dc7:	f6 c2 02             	test   $0x2,%dl
f0102dca:	75 4e                	jne    f0102e1a <mem_init+0x1945>
f0102dcc:	c7 44 24 0c 8b 74 10 	movl   $0xf010748b,0xc(%esp)
f0102dd3:	f0 
f0102dd4:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102ddb:	f0 
f0102ddc:	c7 44 24 04 9e 03 00 	movl   $0x39e,0x4(%esp)
f0102de3:	00 
f0102de4:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102deb:	e8 50 d2 ff ff       	call   f0100040 <_panic>
			} else
				assert(pgdir[i] == 0);
f0102df0:	83 3c 86 00          	cmpl   $0x0,(%esi,%eax,4)
f0102df4:	74 24                	je     f0102e1a <mem_init+0x1945>
f0102df6:	c7 44 24 0c 9c 74 10 	movl   $0xf010749c,0xc(%esp)
f0102dfd:	f0 
f0102dfe:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102e05:	f0 
f0102e06:	c7 44 24 04 a0 03 00 	movl   $0x3a0,0x4(%esp)
f0102e0d:	00 
f0102e0e:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102e15:	e8 26 d2 ff ff       	call   f0100040 <_panic>
		for (i = 0; i < KSTKGAP; i += PGSIZE)
			assert(check_va2pa(pgdir, base + i) == ~0);
	}

	// check PDE permissions
	for (i = 0; i < NPDENTRIES; i++) {
f0102e1a:	83 c0 01             	add    $0x1,%eax
f0102e1d:	3d 00 04 00 00       	cmp    $0x400,%eax
f0102e22:	0f 85 33 ff ff ff    	jne    f0102d5b <mem_init+0x1886>
			} else
				assert(pgdir[i] == 0);
			break;
		}
	}
	cprintf("check_kern_pgdir() succeeded!\n");
f0102e28:	c7 04 24 60 7b 10 f0 	movl   $0xf0107b60,(%esp)
f0102e2f:	e8 3b 0e 00 00       	call   f0103c6f <cprintf>
	// somewhere between KERNBASE and KERNBASE+4MB right now, which is
	// mapped the same way by both page tables.
	//
	// If the machine reboots at this point, you've probably set up your
	// kern_pgdir wrong.
	lcr3(PADDR(kern_pgdir));
f0102e34:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102e39:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0102e3e:	77 20                	ja     f0102e60 <mem_init+0x198b>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0102e40:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0102e44:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0102e4b:	f0 
f0102e4c:	c7 44 24 04 13 01 00 	movl   $0x113,0x4(%esp)
f0102e53:	00 
f0102e54:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102e5b:	e8 e0 d1 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0102e60:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f0102e65:	0f 22 d8             	mov    %eax,%cr3

	check_page_free_list(0);
f0102e68:	b8 00 00 00 00       	mov    $0x0,%eax
f0102e6d:	e8 c2 dd ff ff       	call   f0100c34 <check_page_free_list>

static __inline uint32_t
rcr0(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr0,%0" : "=r" (val));
f0102e72:	0f 20 c0             	mov    %cr0,%eax

	// entry.S set the really important flags in cr0 (including enabling
	// paging).  Here we configure the rest of the flags that we care about.
	cr0 = rcr0();
	cr0 |= CR0_PE|CR0_PG|CR0_AM|CR0_WP|CR0_NE|CR0_MP;
	cr0 &= ~(CR0_TS|CR0_EM);
f0102e75:	83 e0 f3             	and    $0xfffffff3,%eax
f0102e78:	0d 23 00 05 80       	or     $0x80050023,%eax
}

static __inline void
lcr0(uint32_t val)
{
	__asm __volatile("movl %0,%%cr0" : : "r" (val));
f0102e7d:	0f 22 c0             	mov    %eax,%cr0
	uintptr_t va;
	int i;

	// check that we can read and write installed pages
	pp1 = pp2 = 0;
	assert((pp0 = page_alloc(0)));
f0102e80:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102e87:	e8 7d e2 ff ff       	call   f0101109 <page_alloc>
f0102e8c:	89 c6                	mov    %eax,%esi
f0102e8e:	85 c0                	test   %eax,%eax
f0102e90:	75 24                	jne    f0102eb6 <mem_init+0x19e1>
f0102e92:	c7 44 24 0c 68 72 10 	movl   $0xf0107268,0xc(%esp)
f0102e99:	f0 
f0102e9a:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102ea1:	f0 
f0102ea2:	c7 44 24 04 56 04 00 	movl   $0x456,0x4(%esp)
f0102ea9:	00 
f0102eaa:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102eb1:	e8 8a d1 ff ff       	call   f0100040 <_panic>
	assert((pp1 = page_alloc(0)));
f0102eb6:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102ebd:	e8 47 e2 ff ff       	call   f0101109 <page_alloc>
f0102ec2:	89 c3                	mov    %eax,%ebx
f0102ec4:	85 c0                	test   %eax,%eax
f0102ec6:	75 24                	jne    f0102eec <mem_init+0x1a17>
f0102ec8:	c7 44 24 0c 7e 72 10 	movl   $0xf010727e,0xc(%esp)
f0102ecf:	f0 
f0102ed0:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102ed7:	f0 
f0102ed8:	c7 44 24 04 57 04 00 	movl   $0x457,0x4(%esp)
f0102edf:	00 
f0102ee0:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102ee7:	e8 54 d1 ff ff       	call   f0100040 <_panic>
	assert((pp2 = page_alloc(0)));
f0102eec:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0102ef3:	e8 11 e2 ff ff       	call   f0101109 <page_alloc>
f0102ef8:	89 c7                	mov    %eax,%edi
f0102efa:	85 c0                	test   %eax,%eax
f0102efc:	75 24                	jne    f0102f22 <mem_init+0x1a4d>
f0102efe:	c7 44 24 0c 94 72 10 	movl   $0xf0107294,0xc(%esp)
f0102f05:	f0 
f0102f06:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102f0d:	f0 
f0102f0e:	c7 44 24 04 58 04 00 	movl   $0x458,0x4(%esp)
f0102f15:	00 
f0102f16:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102f1d:	e8 1e d1 ff ff       	call   f0100040 <_panic>
	cprintf("pp1->pp_ref=%d\n", pp1->pp_ref);
f0102f22:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0102f26:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102f2a:	c7 04 24 aa 74 10 f0 	movl   $0xf01074aa,(%esp)
f0102f31:	e8 39 0d 00 00       	call   f0103c6f <cprintf>
	page_free(pp0);
f0102f36:	89 34 24             	mov    %esi,(%esp)
f0102f39:	e8 4d e2 ff ff       	call   f010118b <page_free>
	memset(page2kva(pp1), 1, PGSIZE);
f0102f3e:	89 d8                	mov    %ebx,%eax
f0102f40:	e8 3b dc ff ff       	call   f0100b80 <page2kva>
f0102f45:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102f4c:	00 
f0102f4d:	c7 44 24 04 01 00 00 	movl   $0x1,0x4(%esp)
f0102f54:	00 
f0102f55:	89 04 24             	mov    %eax,(%esp)
f0102f58:	e8 9c 2e 00 00       	call   f0105df9 <memset>
	memset(page2kva(pp2), 2, PGSIZE);
f0102f5d:	89 f8                	mov    %edi,%eax
f0102f5f:	e8 1c dc ff ff       	call   f0100b80 <page2kva>
f0102f64:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102f6b:	00 
f0102f6c:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f0102f73:	00 
f0102f74:	89 04 24             	mov    %eax,(%esp)
f0102f77:	e8 7d 2e 00 00       	call   f0105df9 <memset>
	page_insert(kern_pgdir, pp1, (void*) PGSIZE, PTE_W);
f0102f7c:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0102f83:	00 
f0102f84:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f0102f8b:	00 
f0102f8c:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0102f90:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0102f95:	89 04 24             	mov    %eax,(%esp)
f0102f98:	e8 85 e4 ff ff       	call   f0101422 <page_insert>
	cprintf("pp1->pp_ref=%d\n", pp1->pp_ref);
f0102f9d:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0102fa1:	89 44 24 04          	mov    %eax,0x4(%esp)
f0102fa5:	c7 04 24 aa 74 10 f0 	movl   $0xf01074aa,(%esp)
f0102fac:	e8 be 0c 00 00       	call   f0103c6f <cprintf>
	assert(pp1->pp_ref == 1);
f0102fb1:	66 83 7b 04 01       	cmpw   $0x1,0x4(%ebx)
f0102fb6:	74 24                	je     f0102fdc <mem_init+0x1b07>
f0102fb8:	c7 44 24 0c 65 73 10 	movl   $0xf0107365,0xc(%esp)
f0102fbf:	f0 
f0102fc0:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102fc7:	f0 
f0102fc8:	c7 44 24 04 5f 04 00 	movl   $0x45f,0x4(%esp)
f0102fcf:	00 
f0102fd0:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0102fd7:	e8 64 d0 ff ff       	call   f0100040 <_panic>
	assert(*(uint32_t *)PGSIZE == 0x01010101U);
f0102fdc:	81 3d 00 10 00 00 01 	cmpl   $0x1010101,0x1000
f0102fe3:	01 01 01 
f0102fe6:	74 24                	je     f010300c <mem_init+0x1b37>
f0102fe8:	c7 44 24 0c 80 7b 10 	movl   $0xf0107b80,0xc(%esp)
f0102fef:	f0 
f0102ff0:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0102ff7:	f0 
f0102ff8:	c7 44 24 04 60 04 00 	movl   $0x460,0x4(%esp)
f0102fff:	00 
f0103000:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0103007:	e8 34 d0 ff ff       	call   f0100040 <_panic>
	page_insert(kern_pgdir, pp2, (void*) PGSIZE, PTE_W);
f010300c:	c7 44 24 0c 02 00 00 	movl   $0x2,0xc(%esp)
f0103013:	00 
f0103014:	c7 44 24 08 00 10 00 	movl   $0x1000,0x8(%esp)
f010301b:	00 
f010301c:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0103020:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0103025:	89 04 24             	mov    %eax,(%esp)
f0103028:	e8 f5 e3 ff ff       	call   f0101422 <page_insert>
	assert(*(uint32_t *)PGSIZE == 0x02020202U);
f010302d:	81 3d 00 10 00 00 02 	cmpl   $0x2020202,0x1000
f0103034:	02 02 02 
f0103037:	74 24                	je     f010305d <mem_init+0x1b88>
f0103039:	c7 44 24 0c a4 7b 10 	movl   $0xf0107ba4,0xc(%esp)
f0103040:	f0 
f0103041:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0103048:	f0 
f0103049:	c7 44 24 04 62 04 00 	movl   $0x462,0x4(%esp)
f0103050:	00 
f0103051:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0103058:	e8 e3 cf ff ff       	call   f0100040 <_panic>
	assert(pp2->pp_ref == 1);
f010305d:	66 83 7f 04 01       	cmpw   $0x1,0x4(%edi)
f0103062:	74 24                	je     f0103088 <mem_init+0x1bb3>
f0103064:	c7 44 24 0c 87 73 10 	movl   $0xf0107387,0xc(%esp)
f010306b:	f0 
f010306c:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0103073:	f0 
f0103074:	c7 44 24 04 63 04 00 	movl   $0x463,0x4(%esp)
f010307b:	00 
f010307c:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f0103083:	e8 b8 cf ff ff       	call   f0100040 <_panic>
	assert(pp1->pp_ref == 0);
f0103088:	66 83 7b 04 00       	cmpw   $0x0,0x4(%ebx)
f010308d:	74 24                	je     f01030b3 <mem_init+0x1bde>
f010308f:	c7 44 24 0c d0 73 10 	movl   $0xf01073d0,0xc(%esp)
f0103096:	f0 
f0103097:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010309e:	f0 
f010309f:	c7 44 24 04 64 04 00 	movl   $0x464,0x4(%esp)
f01030a6:	00 
f01030a7:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01030ae:	e8 8d cf ff ff       	call   f0100040 <_panic>
	*(uint32_t *)PGSIZE = 0x03030303U;
f01030b3:	c7 05 00 10 00 00 03 	movl   $0x3030303,0x1000
f01030ba:	03 03 03 
	assert(*(uint32_t *)page2kva(pp2) == 0x03030303U);
f01030bd:	89 f8                	mov    %edi,%eax
f01030bf:	e8 bc da ff ff       	call   f0100b80 <page2kva>
f01030c4:	81 38 03 03 03 03    	cmpl   $0x3030303,(%eax)
f01030ca:	74 24                	je     f01030f0 <mem_init+0x1c1b>
f01030cc:	c7 44 24 0c c8 7b 10 	movl   $0xf0107bc8,0xc(%esp)
f01030d3:	f0 
f01030d4:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f01030db:	f0 
f01030dc:	c7 44 24 04 66 04 00 	movl   $0x466,0x4(%esp)
f01030e3:	00 
f01030e4:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f01030eb:	e8 50 cf ff ff       	call   f0100040 <_panic>
	page_remove(kern_pgdir, (void*) PGSIZE);
f01030f0:	c7 44 24 04 00 10 00 	movl   $0x1000,0x4(%esp)
f01030f7:	00 
f01030f8:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01030fd:	89 04 24             	mov    %eax,(%esp)
f0103100:	e8 cb e2 ff ff       	call   f01013d0 <page_remove>
	assert(pp2->pp_ref == 0);
f0103105:	66 83 7f 04 00       	cmpw   $0x0,0x4(%edi)
f010310a:	74 24                	je     f0103130 <mem_init+0x1c5b>
f010310c:	c7 44 24 0c bf 73 10 	movl   $0xf01073bf,0xc(%esp)
f0103113:	f0 
f0103114:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010311b:	f0 
f010311c:	c7 44 24 04 68 04 00 	movl   $0x468,0x4(%esp)
f0103123:	00 
f0103124:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010312b:	e8 10 cf ff ff       	call   f0100040 <_panic>

	// forcibly take pp0 back
	assert(PTE_ADDR(kern_pgdir[0]) == page2pa(pp0));
f0103130:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f0103135:	8b 08                	mov    (%eax),%ecx
f0103137:	81 e1 00 f0 ff ff    	and    $0xfffff000,%ecx
void	user_mem_assert(struct Env *env, const void *va, size_t len, int perm);

static inline physaddr_t
page2pa(struct Page *pp)
{
	return (pp - pages) << PGSHIFT;
f010313d:	89 f2                	mov    %esi,%edx
f010313f:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0103145:	c1 fa 03             	sar    $0x3,%edx
f0103148:	c1 e2 0c             	shl    $0xc,%edx
f010314b:	39 d1                	cmp    %edx,%ecx
f010314d:	74 24                	je     f0103173 <mem_init+0x1c9e>
f010314f:	c7 44 24 0c 00 77 10 	movl   $0xf0107700,0xc(%esp)
f0103156:	f0 
f0103157:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010315e:	f0 
f010315f:	c7 44 24 04 6b 04 00 	movl   $0x46b,0x4(%esp)
f0103166:	00 
f0103167:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010316e:	e8 cd ce ff ff       	call   f0100040 <_panic>
	kern_pgdir[0] = 0;
f0103173:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
	assert(pp0->pp_ref == 1);
f0103179:	66 83 7e 04 01       	cmpw   $0x1,0x4(%esi)
f010317e:	74 24                	je     f01031a4 <mem_init+0x1ccf>
f0103180:	c7 44 24 0c 76 73 10 	movl   $0xf0107376,0xc(%esp)
f0103187:	f0 
f0103188:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f010318f:	f0 
f0103190:	c7 44 24 04 6d 04 00 	movl   $0x46d,0x4(%esp)
f0103197:	00 
f0103198:	c7 04 24 44 71 10 f0 	movl   $0xf0107144,(%esp)
f010319f:	e8 9c ce ff ff       	call   f0100040 <_panic>
	pp0->pp_ref = 0;
f01031a4:	66 c7 46 04 00 00    	movw   $0x0,0x4(%esi)

	// free the pages we took
	page_free(pp0);
f01031aa:	89 34 24             	mov    %esi,(%esp)
f01031ad:	e8 d9 df ff ff       	call   f010118b <page_free>

	cprintf("check_page_installed_pgdir() succeeded!\n");
f01031b2:	c7 04 24 f4 7b 10 f0 	movl   $0xf0107bf4,(%esp)
f01031b9:	e8 b1 0a 00 00       	call   f0103c6f <cprintf>
f01031be:	eb 69                	jmp    f0103229 <mem_init+0x1d54>
	for(cpu_i = 0; cpu_i < NCPU; cpu_i++)
	{
		stk_i = KSTACKTOP - cpu_i * (KSTKGAP + KSTKSIZE) - KSTKSIZE;
		//stk_i = stk_gap_i + KSTKGAP;
		stk_phy_i = PADDR(percpu_kstacks[cpu_i]);
		boot_map_region(kern_pgdir, stk_i, KSTKSIZE, stk_phy_i, PTE_W);
f01031c0:	c7 44 24 04 02 00 00 	movl   $0x2,0x4(%esp)
f01031c7:	00 
f01031c8:	c7 04 24 00 e0 1c 00 	movl   $0x1ce000,(%esp)
f01031cf:	b9 00 80 00 00       	mov    $0x8000,%ecx
f01031d4:	ba 00 80 bf ef       	mov    $0xefbf8000,%edx
f01031d9:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
f01031de:	e8 ec e0 ff ff       	call   f01012cf <boot_map_region>
f01031e3:	bb 00 60 1d f0       	mov    $0xf01d6000,%ebx
f01031e8:	bf 00 e0 20 f0       	mov    $0xf020e000,%edi
f01031ed:	be 00 80 be ef       	mov    $0xefbe8000,%esi
f01031f2:	e9 2e f8 ff ff       	jmp    f0102a25 <mem_init+0x1550>
	// check kernel stack
	// (updated in lab 4 to check per-CPU kernel stacks)
	for (n = 0; n < NCPU; n++) {
		uint32_t base = KSTACKTOP - (KSTKSIZE + KSTKGAP) * (n + 1);
		for (i = 0; i < KSTKSIZE; i += PGSIZE)
			assert(check_va2pa(pgdir, base + KSTKGAP + i)
f01031f7:	89 da                	mov    %ebx,%edx
f01031f9:	89 f0                	mov    %esi,%eax
f01031fb:	e8 c5 d9 ff ff       	call   f0100bc5 <check_va2pa>
f0103200:	e9 b2 fa ff ff       	jmp    f0102cb7 <mem_init+0x17e2>
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);

	// check envs array (new test for lab 3)
	n = ROUNDUP(NENV*sizeof(struct Env), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UENVS + i) == PADDR(envs) + i);
f0103205:	89 da                	mov    %ebx,%edx
f0103207:	89 f0                	mov    %esi,%eax
f0103209:	e8 b7 d9 ff ff       	call   f0100bc5 <check_va2pa>
f010320e:	66 90                	xchg   %ax,%ax
f0103210:	e9 67 f9 ff ff       	jmp    f0102b7c <mem_init+0x16a7>
f0103215:	81 ea 00 f0 ff 10    	sub    $0x10fff000,%edx
	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
		assert(check_va2pa(pgdir, UPAGES + i) == PADDR(pages) + i);
f010321b:	89 f0                	mov    %esi,%eax
f010321d:	e8 a3 d9 ff ff       	call   f0100bc5 <check_va2pa>

	pgdir = kern_pgdir;

	// check pages array
	n = ROUNDUP(npages*sizeof(struct Page), PGSIZE);
	for (i = 0; i < n; i += PGSIZE)
f0103222:	89 da                	mov    %ebx,%edx
f0103224:	e9 f4 f8 ff ff       	jmp    f0102b1d <mem_init+0x1648>
	cr0 &= ~(CR0_TS|CR0_EM);
	lcr0(cr0);

	// Some more checks, only possible after kern_pgdir is installed.
	check_page_installed_pgdir();
}
f0103229:	83 c4 4c             	add    $0x4c,%esp
f010322c:	5b                   	pop    %ebx
f010322d:	5e                   	pop    %esi
f010322e:	5f                   	pop    %edi
f010322f:	5d                   	pop    %ebp
f0103230:	c3                   	ret    

f0103231 <user_mem_check>:
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f0103231:	55                   	push   %ebp
f0103232:	89 e5                	mov    %esp,%ebp
f0103234:	57                   	push   %edi
f0103235:	56                   	push   %esi
f0103236:	53                   	push   %ebx
f0103237:	83 ec 2c             	sub    $0x2c,%esp
f010323a:	8b 7d 08             	mov    0x8(%ebp),%edi
f010323d:	8b 45 0c             	mov    0xc(%ebp),%eax
	//cprintf("at user_mem_check():");
	// LAB 3: Your code here.
	pte_t* pte = NULL;
	void* ptr = NULL, *nxt = NULL;
	for(ptr = (void*)va; ptr < va + len; )
f0103240:	89 c3                	mov    %eax,%ebx
f0103242:	03 45 10             	add    0x10(%ebp),%eax
f0103245:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		if(*pte & PTE_U) cprintf(" PTE_U");
		if(*pte & PTE_W) cprintf(" PTE_W");
		cprintf("\n");
		*/

		if(((perm & PTE_U) != 0 && ((*pte & PTE_U) == 0)) ||
f0103248:	8b 45 14             	mov    0x14(%ebp),%eax
f010324b:	83 e0 04             	and    $0x4,%eax
f010324e:	89 45 e0             	mov    %eax,-0x20(%ebp)
{
	//cprintf("at user_mem_check():");
	// LAB 3: Your code here.
	pte_t* pte = NULL;
	void* ptr = NULL, *nxt = NULL;
	for(ptr = (void*)va; ptr < va + len; )
f0103251:	eb 7f                	jmp    f01032d2 <user_mem_check+0xa1>
	{
		//cprintf("now check address: %x\n", ptr);
		if((uintptr_t)ptr >= ULIM)
f0103253:	89 de                	mov    %ebx,%esi
f0103255:	81 fb ff ff 7f ef    	cmp    $0xef7fffff,%ebx
f010325b:	76 0d                	jbe    f010326a <user_mem_check+0x39>
		{
			user_mem_check_addr = (uintptr_t)ptr;
f010325d:	89 1d 3c c2 1c f0    	mov    %ebx,0xf01cc23c
			return -E_FAULT;
f0103263:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103268:	eb 76                	jmp    f01032e0 <user_mem_check+0xaf>
		}
		pte = pgdir_walk(env->env_pgdir, ptr, 0); 
f010326a:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0103271:	00 
f0103272:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103276:	8b 47 60             	mov    0x60(%edi),%eax
f0103279:	89 04 24             	mov    %eax,(%esp)
f010327c:	e8 65 df ff ff       	call   f01011e6 <pgdir_walk>
		if(pte == NULL || (*pte & PTE_P) == 0) 
f0103281:	85 c0                	test   %eax,%eax
f0103283:	74 06                	je     f010328b <user_mem_check+0x5a>
f0103285:	8b 00                	mov    (%eax),%eax
f0103287:	a8 01                	test   $0x1,%al
f0103289:	75 0d                	jne    f0103298 <user_mem_check+0x67>
		{
			user_mem_check_addr = (uintptr_t)ptr;
f010328b:	89 35 3c c2 1c f0    	mov    %esi,0xf01cc23c
			return -E_FAULT;
f0103291:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f0103296:	eb 48                	jmp    f01032e0 <user_mem_check+0xaf>
		if(*pte & PTE_U) cprintf(" PTE_U");
		if(*pte & PTE_W) cprintf(" PTE_W");
		cprintf("\n");
		*/

		if(((perm & PTE_U) != 0 && ((*pte & PTE_U) == 0)) ||
f0103298:	83 7d e0 00          	cmpl   $0x0,-0x20(%ebp)
f010329c:	74 04                	je     f01032a2 <user_mem_check+0x71>
f010329e:	a8 04                	test   $0x4,%al
f01032a0:	74 0a                	je     f01032ac <user_mem_check+0x7b>
f01032a2:	f6 45 14 02          	testb  $0x2,0x14(%ebp)
f01032a6:	74 11                	je     f01032b9 <user_mem_check+0x88>
			((perm & PTE_W) != 0 && ((*pte & PTE_W) == 0)))
f01032a8:	a8 02                	test   $0x2,%al
f01032aa:	75 0d                	jne    f01032b9 <user_mem_check+0x88>
		{
			user_mem_check_addr = (uintptr_t)ptr;
f01032ac:	89 35 3c c2 1c f0    	mov    %esi,0xf01cc23c
			return -E_FAULT;
f01032b2:	b8 fa ff ff ff       	mov    $0xfffffffa,%eax
f01032b7:	eb 27                	jmp    f01032e0 <user_mem_check+0xaf>
		}
		nxt = (void*) ROUNDUP(ptr, PGSIZE);
f01032b9:	81 c6 ff 0f 00 00    	add    $0xfff,%esi
f01032bf:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
		ptr = ptr == nxt ? ptr + PGSIZE : nxt;
f01032c5:	8d 83 00 10 00 00    	lea    0x1000(%ebx),%eax
f01032cb:	39 f3                	cmp    %esi,%ebx
// Returns 0 if the user program can access this range of addresses,
// and -E_FAULT otherwise.
//
int
user_mem_check(struct Env *env, const void *va, size_t len, int perm)
{
f01032cd:	0f 45 c6             	cmovne %esi,%eax
f01032d0:	89 c3                	mov    %eax,%ebx
	//cprintf("at user_mem_check():");
	// LAB 3: Your code here.
	pte_t* pte = NULL;
	void* ptr = NULL, *nxt = NULL;
	for(ptr = (void*)va; ptr < va + len; )
f01032d2:	3b 5d e4             	cmp    -0x1c(%ebp),%ebx
f01032d5:	0f 82 78 ff ff ff    	jb     f0103253 <user_mem_check+0x22>
		}
		nxt = (void*) ROUNDUP(ptr, PGSIZE);
		ptr = ptr == nxt ? ptr + PGSIZE : nxt;
	}

	return 0;
f01032db:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01032e0:	83 c4 2c             	add    $0x2c,%esp
f01032e3:	5b                   	pop    %ebx
f01032e4:	5e                   	pop    %esi
f01032e5:	5f                   	pop    %edi
f01032e6:	5d                   	pop    %ebp
f01032e7:	c3                   	ret    

f01032e8 <user_mem_assert>:
// If it cannot, 'env' is destroyed and, if env is the current
// environment, this function will not return.
//
void
user_mem_assert(struct Env *env, const void *va, size_t len, int perm)
{
f01032e8:	55                   	push   %ebp
f01032e9:	89 e5                	mov    %esp,%ebp
f01032eb:	53                   	push   %ebx
f01032ec:	83 ec 14             	sub    $0x14,%esp
f01032ef:	8b 5d 08             	mov    0x8(%ebp),%ebx
	if (user_mem_check(env, va, len, perm | PTE_U) < 0) {
f01032f2:	8b 45 14             	mov    0x14(%ebp),%eax
f01032f5:	83 c8 04             	or     $0x4,%eax
f01032f8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01032fc:	8b 45 10             	mov    0x10(%ebp),%eax
f01032ff:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103303:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103306:	89 44 24 04          	mov    %eax,0x4(%esp)
f010330a:	89 1c 24             	mov    %ebx,(%esp)
f010330d:	e8 1f ff ff ff       	call   f0103231 <user_mem_check>
f0103312:	85 c0                	test   %eax,%eax
f0103314:	79 24                	jns    f010333a <user_mem_assert+0x52>
		cprintf("[%08x] user_mem_check assertion failure for "
f0103316:	a1 3c c2 1c f0       	mov    0xf01cc23c,%eax
f010331b:	89 44 24 08          	mov    %eax,0x8(%esp)
f010331f:	8b 43 48             	mov    0x48(%ebx),%eax
f0103322:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103326:	c7 04 24 20 7c 10 f0 	movl   $0xf0107c20,(%esp)
f010332d:	e8 3d 09 00 00       	call   f0103c6f <cprintf>
			"va %08x\n", env->env_id, user_mem_check_addr);
		env_destroy(env);	// may not return
f0103332:	89 1c 24             	mov    %ebx,(%esp)
f0103335:	e8 83 06 00 00       	call   f01039bd <env_destroy>
	}
}
f010333a:	83 c4 14             	add    $0x14,%esp
f010333d:	5b                   	pop    %ebx
f010333e:	5d                   	pop    %ebp
f010333f:	c3                   	ret    

f0103340 <envid2env>:
//   On success, sets *env_store to the environment.
//   On error, sets *env_store to NULL.
//
int
envid2env(envid_t envid, struct Env **env_store, bool checkperm)
{
f0103340:	55                   	push   %ebp
f0103341:	89 e5                	mov    %esp,%ebp
f0103343:	56                   	push   %esi
f0103344:	53                   	push   %ebx
f0103345:	8b 45 08             	mov    0x8(%ebp),%eax
	struct Env *e;

	// If envid is zero, return the current environment.
	if (envid == 0) {
f0103348:	85 c0                	test   %eax,%eax
f010334a:	75 1a                	jne    f0103366 <envid2env+0x26>
		*env_store = curenv;
f010334c:	e8 42 31 00 00       	call   f0106493 <cpunum>
f0103351:	6b c0 74             	imul   $0x74,%eax,%eax
f0103354:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f010335a:	8b 55 0c             	mov    0xc(%ebp),%edx
f010335d:	89 02                	mov    %eax,(%edx)
		return 0;
f010335f:	b8 00 00 00 00       	mov    $0x0,%eax
f0103364:	eb 72                	jmp    f01033d8 <envid2env+0x98>
	// Look up the Env structure via the index part of the envid,
	// then check the env_id field in that struct Env
	// to ensure that the envid is not stale
	// (i.e., does not refer to a _previous_ environment
	// that used the same slot in the envs[] array).
	e = &envs[ENVX(envid)];
f0103366:	89 c3                	mov    %eax,%ebx
f0103368:	81 e3 ff 03 00 00    	and    $0x3ff,%ebx
f010336e:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103371:	03 1d 48 c2 1c f0    	add    0xf01cc248,%ebx
	if (e->env_status == ENV_FREE || e->env_id != envid) {
f0103377:	83 7b 54 00          	cmpl   $0x0,0x54(%ebx)
f010337b:	74 05                	je     f0103382 <envid2env+0x42>
f010337d:	39 43 48             	cmp    %eax,0x48(%ebx)
f0103380:	74 10                	je     f0103392 <envid2env+0x52>
		*env_store = 0;
f0103382:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103385:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f010338b:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f0103390:	eb 46                	jmp    f01033d8 <envid2env+0x98>
	// Check that the calling environment has legitimate permission
	// to manipulate the specified environment.
	// If checkperm is set, the specified environment
	// must be either the current environment
	// or an immediate child of the current environment.
	if (checkperm && e != curenv && e->env_parent_id != curenv->env_id) {
f0103392:	83 7d 10 00          	cmpl   $0x0,0x10(%ebp)
f0103396:	74 36                	je     f01033ce <envid2env+0x8e>
f0103398:	e8 f6 30 00 00       	call   f0106493 <cpunum>
f010339d:	6b c0 74             	imul   $0x74,%eax,%eax
f01033a0:	39 98 28 d0 1c f0    	cmp    %ebx,-0xfe32fd8(%eax)
f01033a6:	74 26                	je     f01033ce <envid2env+0x8e>
f01033a8:	8b 73 4c             	mov    0x4c(%ebx),%esi
f01033ab:	e8 e3 30 00 00       	call   f0106493 <cpunum>
f01033b0:	6b c0 74             	imul   $0x74,%eax,%eax
f01033b3:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f01033b9:	3b 70 48             	cmp    0x48(%eax),%esi
f01033bc:	74 10                	je     f01033ce <envid2env+0x8e>
		*env_store = 0;
f01033be:	8b 45 0c             	mov    0xc(%ebp),%eax
f01033c1:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
		return -E_BAD_ENV;
f01033c7:	b8 fe ff ff ff       	mov    $0xfffffffe,%eax
f01033cc:	eb 0a                	jmp    f01033d8 <envid2env+0x98>
	}

	*env_store = e;
f01033ce:	8b 45 0c             	mov    0xc(%ebp),%eax
f01033d1:	89 18                	mov    %ebx,(%eax)
	return 0;
f01033d3:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01033d8:	5b                   	pop    %ebx
f01033d9:	5e                   	pop    %esi
f01033da:	5d                   	pop    %ebp
f01033db:	c3                   	ret    

f01033dc <env_init_percpu>:
}

// Load GDT and segment descriptors.
void
env_init_percpu(void)
{
f01033dc:	55                   	push   %ebp
f01033dd:	89 e5                	mov    %esp,%ebp
}

static __inline void
lgdt(void *p)
{
	__asm __volatile("lgdt (%0)" : : "r" (p));
f01033df:	b8 00 13 12 f0       	mov    $0xf0121300,%eax
f01033e4:	0f 01 10             	lgdtl  (%eax)
	lgdt(&gdt_pd);
	// The kernel never uses GS or FS, so we leave those set to
	// the user data segment.
	asm volatile("movw %%ax,%%gs" :: "a" (GD_UD|3));
f01033e7:	b8 23 00 00 00       	mov    $0x23,%eax
f01033ec:	8e e8                	mov    %eax,%gs
	asm volatile("movw %%ax,%%fs" :: "a" (GD_UD|3));
f01033ee:	8e e0                	mov    %eax,%fs
	// The kernel does use ES, DS, and SS.  We'll change between
	// the kernel and user data segments as needed.
	asm volatile("movw %%ax,%%es" :: "a" (GD_KD));
f01033f0:	b0 10                	mov    $0x10,%al
f01033f2:	8e c0                	mov    %eax,%es
	asm volatile("movw %%ax,%%ds" :: "a" (GD_KD));
f01033f4:	8e d8                	mov    %eax,%ds
	asm volatile("movw %%ax,%%ss" :: "a" (GD_KD));
f01033f6:	8e d0                	mov    %eax,%ss
	// Load the kernel text segment into CS.
	asm volatile("ljmp %0,$1f\n 1:\n" :: "i" (GD_KT));
f01033f8:	ea ff 33 10 f0 08 00 	ljmp   $0x8,$0xf01033ff
}

static __inline void
lldt(uint16_t sel)
{
	__asm __volatile("lldt %0" : : "r" (sel));
f01033ff:	b0 00                	mov    $0x0,%al
f0103401:	0f 00 d0             	lldt   %ax
	// For good measure, clear the local descriptor table (LDT),
	// since we don't use it.
	lldt(0);
}
f0103404:	5d                   	pop    %ebp
f0103405:	c3                   	ret    

f0103406 <env_init>:
// they are in the envs array (i.e., so that the first call to
// env_alloc() returns envs[0]).
//
void
env_init(void)
{
f0103406:	55                   	push   %ebp
f0103407:	89 e5                	mov    %esp,%ebp
f0103409:	57                   	push   %edi
f010340a:	56                   	push   %esi
f010340b:	53                   	push   %ebx
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
    {
    	envs[i].env_id=0;
f010340c:	8b 0d 48 c2 1c f0    	mov    0xf01cc248,%ecx
f0103412:	c7 41 48 00 00 00 00 	movl   $0x0,0x48(%ecx)
f0103419:	89 cf                	mov    %ecx,%edi
f010341b:	8d 51 7c             	lea    0x7c(%ecx),%edx
f010341e:	89 ce                	mov    %ecx,%esi
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f0103420:	b8 00 00 00 00       	mov    $0x0,%eax
    {
    	envs[i].env_id=0;
f0103425:	bb 00 00 00 00       	mov    $0x0,%ebx
f010342a:	eb 02                	jmp    f010342e <env_init+0x28>
f010342c:	89 f9                	mov    %edi,%ecx
    	if(i!=NENV-1)
    	{
    	envs[i].env_link=&envs[i+1];
f010342e:	83 c3 01             	add    $0x1,%ebx
f0103431:	6b db 7c             	imul   $0x7c,%ebx,%ebx
f0103434:	01 d9                	add    %ebx,%ecx
f0103436:	89 4e 44             	mov    %ecx,0x44(%esi)
env_init(void)
{
	// Set up envs array
	// LAB 3: Your code here.
    int i=0;
    for(i=0;i<=NENV-1;i++)
f0103439:	83 c0 01             	add    $0x1,%eax
    {
    	envs[i].env_id=0;
f010343c:	89 c3                	mov    %eax,%ebx
f010343e:	89 d6                	mov    %edx,%esi
f0103440:	c7 42 48 00 00 00 00 	movl   $0x0,0x48(%edx)
f0103447:	83 c2 7c             	add    $0x7c,%edx
    	if(i!=NENV-1)
f010344a:	3d ff 03 00 00       	cmp    $0x3ff,%eax
f010344f:	75 db                	jne    f010342c <env_init+0x26>
    	{
    	envs[i].env_link=&envs[i+1];
    	}
    }
    env_free_list=envs;
f0103451:	a1 48 c2 1c f0       	mov    0xf01cc248,%eax
f0103456:	a3 4c c2 1c f0       	mov    %eax,0xf01cc24c
	// Per-CPU part of the initialization
	env_init_percpu();
f010345b:	e8 7c ff ff ff       	call   f01033dc <env_init_percpu>
}
f0103460:	5b                   	pop    %ebx
f0103461:	5e                   	pop    %esi
f0103462:	5f                   	pop    %edi
f0103463:	5d                   	pop    %ebp
f0103464:	c3                   	ret    

f0103465 <env_alloc>:
//	-E_NO_FREE_ENV if all NENVS environments are allocated
//	-E_NO_MEM on memory exhaustion
//
int
env_alloc(struct Env **newenv_store, envid_t parent_id)
{
f0103465:	55                   	push   %ebp
f0103466:	89 e5                	mov    %esp,%ebp
f0103468:	56                   	push   %esi
f0103469:	53                   	push   %ebx
f010346a:	83 ec 10             	sub    $0x10,%esp
//<<<<<<< HEAD
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
f010346d:	8b 1d 4c c2 1c f0    	mov    0xf01cc24c,%ebx
f0103473:	85 db                	test   %ebx,%ebx
f0103475:	0f 84 54 01 00 00    	je     f01035cf <env_alloc+0x16a>
{
	int i;
	struct Page *p = NULL;
//	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
f010347b:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0103482:	e8 82 dc ff ff       	call   f0101109 <page_alloc>
f0103487:	85 c0                	test   %eax,%eax
f0103489:	0f 84 47 01 00 00    	je     f01035d6 <env_alloc+0x171>
f010348f:	89 c2                	mov    %eax,%edx
f0103491:	2b 15 90 ce 1c f0    	sub    0xf01cce90,%edx
f0103497:	c1 fa 03             	sar    $0x3,%edx
f010349a:	c1 e2 0c             	shl    $0xc,%edx
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010349d:	89 d1                	mov    %edx,%ecx
f010349f:	c1 e9 0c             	shr    $0xc,%ecx
f01034a2:	3b 0d 88 ce 1c f0    	cmp    0xf01cce88,%ecx
f01034a8:	72 20                	jb     f01034ca <env_alloc+0x65>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01034aa:	89 54 24 0c          	mov    %edx,0xc(%esp)
f01034ae:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f01034b5:	f0 
f01034b6:	c7 44 24 04 56 00 00 	movl   $0x56,0x4(%esp)
f01034bd:	00 
f01034be:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f01034c5:	e8 76 cb ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01034ca:	81 ea 00 00 00 10    	sub    $0x10000000,%edx
f01034d0:	89 53 60             	mov    %edx,0x60(%ebx)
	//	is an exception -- you need to increment env_pgdir's
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
f01034d3:	ba ec 0e 00 00       	mov    $0xeec,%edx
    for(i=PDX(UTOP);i<1024;i++)
    {
    	e->env_pgdir[i]=kern_pgdir[i];
f01034d8:	8b 0d 8c ce 1c f0    	mov    0xf01cce8c,%ecx
f01034de:	8b 34 11             	mov    (%ecx,%edx,1),%esi
f01034e1:	8b 4b 60             	mov    0x60(%ebx),%ecx
f01034e4:	89 34 11             	mov    %esi,(%ecx,%edx,1)
f01034e7:	83 c2 04             	add    $0x4,%edx
	//	pp_ref for env_free to work correctly.
	//    - The functions in kern/pmap.h are handy.

	// LAB 3: Your code here.
    e->env_pgdir=page2kva(p);
    for(i=PDX(UTOP);i<1024;i++)
f01034ea:	81 fa 00 10 00 00    	cmp    $0x1000,%edx
f01034f0:	75 e6                	jne    f01034d8 <env_alloc+0x73>
    {
    	e->env_pgdir[i]=kern_pgdir[i];
    }
    p->pp_ref++;
f01034f2:	66 83 40 04 01       	addw   $0x1,0x4(%eax)
	// UVPT maps the env's own page table read-only.
	// Permissions: kernel R, user R
	e->env_pgdir[PDX(UVPT)] = PADDR(e->env_pgdir) | PTE_P | PTE_U;
f01034f7:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f01034fa:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01034ff:	77 20                	ja     f0103521 <env_alloc+0xbc>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103501:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103505:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f010350c:	f0 
f010350d:	c7 44 24 04 ca 00 00 	movl   $0xca,0x4(%esp)
f0103514:	00 
f0103515:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f010351c:	e8 1f cb ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103521:	8d 90 00 00 00 10    	lea    0x10000000(%eax),%edx
f0103527:	83 ca 05             	or     $0x5,%edx
f010352a:	89 90 f4 0e 00 00    	mov    %edx,0xef4(%eax)
	// Allocate and set up the page directory for this environment.
	if ((r = env_setup_vm(e)) < 0)
		return r;

	// Generate an env_id for this environment.
	generation = (e->env_id + (1 << ENVGENSHIFT)) & ~(NENV - 1);
f0103530:	8b 43 48             	mov    0x48(%ebx),%eax
f0103533:	05 00 10 00 00       	add    $0x1000,%eax
	if (generation <= 0)	// Don't create a negative env_id.
f0103538:	25 00 fc ff ff       	and    $0xfffffc00,%eax
		generation = 1 << ENVGENSHIFT;
f010353d:	ba 00 10 00 00       	mov    $0x1000,%edx
f0103542:	0f 4e c2             	cmovle %edx,%eax
	e->env_id = generation | (e - envs);
f0103545:	89 da                	mov    %ebx,%edx
f0103547:	2b 15 48 c2 1c f0    	sub    0xf01cc248,%edx
f010354d:	c1 fa 02             	sar    $0x2,%edx
f0103550:	69 d2 df 7b ef bd    	imul   $0xbdef7bdf,%edx,%edx
f0103556:	09 d0                	or     %edx,%eax
f0103558:	89 43 48             	mov    %eax,0x48(%ebx)

	// Set the basic status variables.
	e->env_parent_id = parent_id;
f010355b:	8b 45 0c             	mov    0xc(%ebp),%eax
f010355e:	89 43 4c             	mov    %eax,0x4c(%ebx)
	e->env_type = ENV_TYPE_USER;
f0103561:	c7 43 50 00 00 00 00 	movl   $0x0,0x50(%ebx)
	e->env_status = ENV_RUNNABLE;
f0103568:	c7 43 54 02 00 00 00 	movl   $0x2,0x54(%ebx)
	e->env_runs = 0;
f010356f:	c7 43 58 00 00 00 00 	movl   $0x0,0x58(%ebx)

	// Clear out all the saved register state,
	// to prevent the register values
	// of a prior environment inhabiting this Env structure
	// from "leaking" into our new environment.
	memset(&e->env_tf, 0, sizeof(e->env_tf));
f0103576:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f010357d:	00 
f010357e:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f0103585:	00 
f0103586:	89 1c 24             	mov    %ebx,(%esp)
f0103589:	e8 6b 28 00 00       	call   f0105df9 <memset>
	// The low 2 bits of each segment register contains the
	// Requestor Privilege Level (RPL); 3 means user mode.  When
	// we switch privilege levels, the hardware does various
	// checks involving the RPL and the Descriptor Privilege Level
	// (DPL) stored in the descriptors themselves.
	e->env_tf.tf_ds = GD_UD | 3;
f010358e:	66 c7 43 24 23 00    	movw   $0x23,0x24(%ebx)
	e->env_tf.tf_es = GD_UD | 3;
f0103594:	66 c7 43 20 23 00    	movw   $0x23,0x20(%ebx)
	e->env_tf.tf_ss = GD_UD | 3;
f010359a:	66 c7 43 40 23 00    	movw   $0x23,0x40(%ebx)
	e->env_tf.tf_esp = USTACKTOP;
f01035a0:	c7 43 3c 00 e0 bf ee 	movl   $0xeebfe000,0x3c(%ebx)
	e->env_tf.tf_cs = GD_UT | 3;
f01035a7:	66 c7 43 34 1b 00    	movw   $0x1b,0x34(%ebx)

	// Enable interrupts while in user mode.
	// LAB 4: Your code here.

	// Clear the page fault handler until user installs one.
	e->env_pgfault_upcall = 0;
f01035ad:	c7 43 64 00 00 00 00 	movl   $0x0,0x64(%ebx)

	// Also clear the IPC receiving flag.
	e->env_ipc_recving = 0;
f01035b4:	c7 43 68 00 00 00 00 	movl   $0x0,0x68(%ebx)

	// commit the allocation
	env_free_list = e->env_link;
f01035bb:	8b 43 44             	mov    0x44(%ebx),%eax
f01035be:	a3 4c c2 1c f0       	mov    %eax,0xf01cc24c
	*newenv_store = e;
f01035c3:	8b 45 08             	mov    0x8(%ebp),%eax
f01035c6:	89 18                	mov    %ebx,(%eax)

	// cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
	return 0;
f01035c8:	b8 00 00 00 00       	mov    $0x0,%eax
f01035cd:	eb 0c                	jmp    f01035db <env_alloc+0x176>
	int32_t generation;
	int r;
	struct Env *e;

	if (!(e = env_free_list))
		return -E_NO_FREE_ENV;
f01035cf:	b8 fb ff ff ff       	mov    $0xfffffffb,%eax
f01035d4:	eb 05                	jmp    f01035db <env_alloc+0x176>
	int i;
	struct Page *p = NULL;
//	cprintf("env_setup_vm\r\n");
	// Allocate a page for the page directory
	if (!(p = page_alloc(ALLOC_ZERO)))
		return -E_NO_MEM;
f01035d6:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
    *newenv_store = e;

    cprintf("[%08x] new env %08x\n", curenv ? curenv->env_id : 0, e->env_id);
    return 0;
//>>>>>>> lab4
}
f01035db:	83 c4 10             	add    $0x10,%esp
f01035de:	5b                   	pop    %ebx
f01035df:	5e                   	pop    %esi
f01035e0:	5d                   	pop    %ebp
f01035e1:	c3                   	ret    

f01035e2 <env_create>:
// before running the first user-mode environment.
// The new env's parent ID is set to 0.
//
void
env_create(uint8_t *binary, size_t size, enum EnvType type)
{
f01035e2:	55                   	push   %ebp
f01035e3:	89 e5                	mov    %esp,%ebp
f01035e5:	57                   	push   %edi
f01035e6:	56                   	push   %esi
f01035e7:	53                   	push   %ebx
f01035e8:	83 ec 3c             	sub    $0x3c,%esp
	// LAB 3: Your code here.

//<<<<<<< HEAD
cprintf("right!!+++++++++++++++++++++\n");
f01035eb:	c7 04 24 60 7c 10 f0 	movl   $0xf0107c60,(%esp)
f01035f2:	e8 78 06 00 00       	call   f0103c6f <cprintf>
//=======
	struct Env* env;

	if(env_alloc(&env,0)==0)
f01035f7:	c7 44 24 04 00 00 00 	movl   $0x0,0x4(%esp)
f01035fe:	00 
f01035ff:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0103602:	89 04 24             	mov    %eax,(%esp)
f0103605:	e8 5b fe ff ff       	call   f0103465 <env_alloc>
f010360a:	85 c0                	test   %eax,%eax
f010360c:	0f 85 bc 01 00 00    	jne    f01037ce <env_create+0x1ec>
	{
		env->env_type=type;
f0103612:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0103615:	8b 45 10             	mov    0x10(%ebp),%eax
f0103618:	89 46 50             	mov    %eax,0x50(%esi)
    //  to make sure that the environment starts executing there.
    //  What?  (See env_run() and env_pop_tf() below.)

    // LAB 3: Your code here.
    // What?
    lcr3(PADDR(e->env_pgdir));
f010361b:	8b 46 60             	mov    0x60(%esi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010361e:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103623:	77 20                	ja     f0103645 <env_create+0x63>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103625:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103629:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0103630:	f0 
f0103631:	c7 44 24 04 a9 01 00 	movl   $0x1a9,0x4(%esp)
f0103638:	00 
f0103639:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f0103640:	e8 fb c9 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103645:	05 00 00 00 10       	add    $0x10000000,%eax
}

static __inline void
lcr3(uint32_t val)
{
	__asm __volatile("movl %0,%%cr3" : : "r" (val));
f010364a:	0f 22 d8             	mov    %eax,%cr3

    struct Elf* ELFHDR = (struct Elf*)binary;

    assert(ELFHDR->e_magic == ELF_MAGIC);
f010364d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103650:	81 38 7f 45 4c 46    	cmpl   $0x464c457f,(%eax)
f0103656:	74 24                	je     f010367c <env_create+0x9a>
f0103658:	c7 44 24 0c 7e 7c 10 	movl   $0xf0107c7e,0xc(%esp)
f010365f:	f0 
f0103660:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0103667:	f0 
f0103668:	c7 44 24 04 ad 01 00 	movl   $0x1ad,0x4(%esp)
f010366f:	00 
f0103670:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f0103677:	e8 c4 c9 ff ff       	call   f0100040 <_panic>
    struct Proghdr *ph, *eph;

    uint8_t* p_src = NULL, *p_dst = NULL;
    uint32_t cnt = 0;

    ph = (struct Proghdr *) (binary + ELFHDR->e_phoff);
f010367c:	8b 45 08             	mov    0x8(%ebp),%eax
f010367f:	89 c7                	mov    %eax,%edi
f0103681:	03 78 1c             	add    0x1c(%eax),%edi
    eph = ph + ELFHDR->e_phnum;
f0103684:	0f b7 40 2c          	movzwl 0x2c(%eax),%eax
f0103688:	c1 e0 05             	shl    $0x5,%eax
f010368b:	01 f8                	add    %edi,%eax
f010368d:	89 45 d4             	mov    %eax,-0x2c(%ebp)

    for(; ph < eph; ph++)
f0103690:	39 c7                	cmp    %eax,%edi
f0103692:	0f 83 a6 00 00 00    	jae    f010373e <env_create+0x15c>
    {
        if(ph->p_type == ELF_PROG_LOAD)
f0103698:	83 3f 01             	cmpl   $0x1,(%edi)
f010369b:	0f 85 91 00 00 00    	jne    f0103732 <env_create+0x150>
        {
            region_alloc(e, (void*)ph->p_va, ph->p_memsz);
f01036a1:	8b 47 08             	mov    0x8(%edi),%eax
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	//cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f01036a4:	89 c3                	mov    %eax,%ebx
f01036a6:	81 e3 00 f0 ff ff    	and    $0xfffff000,%ebx
f01036ac:	03 47 14             	add    0x14(%edi),%eax
f01036af:	05 ff 0f 00 00       	add    $0xfff,%eax
f01036b4:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f01036b9:	39 c3                	cmp    %eax,%ebx
f01036bb:	73 59                	jae    f0103716 <env_create+0x134>
f01036bd:	89 7d d0             	mov    %edi,-0x30(%ebp)
f01036c0:	89 c7                	mov    %eax,%edi
	{
		struct Page* p=(struct Page*)page_alloc(1);
f01036c2:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f01036c9:	e8 3b da ff ff       	call   f0101109 <page_alloc>
		if(p==NULL)
f01036ce:	85 c0                	test   %eax,%eax
f01036d0:	75 1c                	jne    f01036ee <env_create+0x10c>
			panic("Memory out!");
f01036d2:	c7 44 24 08 9b 7c 10 	movl   $0xf0107c9b,0x8(%esp)
f01036d9:	f0 
f01036da:	c7 44 24 04 6c 01 00 	movl   $0x16c,0x4(%esp)
f01036e1:	00 
f01036e2:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f01036e9:	e8 52 c9 ff ff       	call   f0100040 <_panic>
		page_insert(e->env_pgdir,p,i,PTE_W|PTE_U);
f01036ee:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f01036f5:	00 
f01036f6:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f01036fa:	89 44 24 04          	mov    %eax,0x4(%esp)
f01036fe:	8b 46 60             	mov    0x60(%esi),%eax
f0103701:	89 04 24             	mov    %eax,(%esp)
f0103704:	e8 19 dd ff ff       	call   f0101422 <page_insert>
	//   'va' and 'len' values that are not page-aligned.
	//   You should round va down, and round (va + len) up.
	//   (Watch out for corner-cases!)
	void* i;
	//cprintf("region_alloc %x,%d\r\n",e->env_pgdir,len);
	for(i=ROUNDDOWN(va,PGSIZE);i<ROUNDUP(va+len,PGSIZE);i+=PGSIZE)
f0103709:	81 c3 00 10 00 00    	add    $0x1000,%ebx
f010370f:	39 fb                	cmp    %edi,%ebx
f0103711:	72 af                	jb     f01036c2 <env_create+0xe0>
f0103713:	8b 7d d0             	mov    -0x30(%ebp),%edi
    for(; ph < eph; ph++)
    {
        if(ph->p_type == ELF_PROG_LOAD)
        {
            region_alloc(e, (void*)ph->p_va, ph->p_memsz);
            memmove((void*)ph->p_va, (void*)binary + ph->p_offset, ph->p_filesz);
f0103716:	8b 47 10             	mov    0x10(%edi),%eax
f0103719:	89 44 24 08          	mov    %eax,0x8(%esp)
f010371d:	8b 45 08             	mov    0x8(%ebp),%eax
f0103720:	03 47 04             	add    0x4(%edi),%eax
f0103723:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103727:	8b 47 08             	mov    0x8(%edi),%eax
f010372a:	89 04 24             	mov    %eax,(%esp)
f010372d:	e8 14 27 00 00       	call   f0105e46 <memmove>
    uint32_t cnt = 0;

    ph = (struct Proghdr *) (binary + ELFHDR->e_phoff);
    eph = ph + ELFHDR->e_phnum;

    for(; ph < eph; ph++)
f0103732:	83 c7 20             	add    $0x20,%edi
f0103735:	39 7d d4             	cmp    %edi,-0x2c(%ebp)
f0103738:	0f 87 5a ff ff ff    	ja     f0103698 <env_create+0xb6>
            }
        }
    }
    */

    e->env_tf.tf_eip = ELFHDR->e_entry;
f010373e:	8b 45 08             	mov    0x8(%ebp),%eax
f0103741:	8b 40 18             	mov    0x18(%eax),%eax
f0103744:	89 46 30             	mov    %eax,0x30(%esi)
    // Now map one page for the program's initial stack
    // at virtual address USTACKTOP - PGSIZE.

    // LAB 3: Your code here.
    struct Page* stack_page = (struct Page*)page_alloc(1);
f0103747:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f010374e:	e8 b6 d9 ff ff       	call   f0101109 <page_alloc>
    if(stack_page == 0)
f0103753:	85 c0                	test   %eax,%eax
f0103755:	75 24                	jne    f010377b <env_create+0x199>
        panic("load_icode(): %e", -E_NO_MEM);
f0103757:	c7 44 24 0c fc ff ff 	movl   $0xfffffffc,0xc(%esp)
f010375e:	ff 
f010375f:	c7 44 24 08 a7 7c 10 	movl   $0xf0107ca7,0x8(%esp)
f0103766:	f0 
f0103767:	c7 44 24 04 e5 01 00 	movl   $0x1e5,0x4(%esp)
f010376e:	00 
f010376f:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f0103776:	e8 c5 c8 ff ff       	call   f0100040 <_panic>

    page_insert(e->env_pgdir, stack_page, (void*)(USTACKTOP - PGSIZE), PTE_W | PTE_U);
f010377b:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f0103782:	00 
f0103783:	c7 44 24 08 00 d0 bf 	movl   $0xeebfd000,0x8(%esp)
f010378a:	ee 
f010378b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010378f:	8b 46 60             	mov    0x60(%esi),%eax
f0103792:	89 04 24             	mov    %eax,(%esp)
f0103795:	e8 88 dc ff ff       	call   f0101422 <page_insert>

    lcr3(PADDR(kern_pgdir));
f010379a:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010379f:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f01037a4:	77 20                	ja     f01037c6 <env_create+0x1e4>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f01037a6:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01037aa:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f01037b1:	f0 
f01037b2:	c7 44 24 04 e9 01 00 	movl   $0x1e9,0x4(%esp)
f01037b9:	00 
f01037ba:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f01037c1:	e8 7a c8 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f01037c6:	05 00 00 00 10       	add    $0x10000000,%eax
f01037cb:	0f 22 d8             	mov    %eax,%cr3
	}

//>>>>>>> lab4
	// If this is the file server (type == ENV_TYPE_FS) give it I/O privileges.
	// LAB 5: Your code here.
	    if(type==ENV_TYPE_FS)
f01037ce:	83 7d 10 02          	cmpl   $0x2,0x10(%ebp)
f01037d2:	75 16                	jne    f01037ea <env_create+0x208>
	    {
	    		env->env_tf.tf_eflags|=FL_IOPL_3;
f01037d4:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01037d7:	81 48 38 00 30 00 00 	orl    $0x3000,0x38(%eax)
	    		cprintf("right!!\n");
f01037de:	c7 04 24 b8 7c 10 f0 	movl   $0xf0107cb8,(%esp)
f01037e5:	e8 85 04 00 00       	call   f0103c6f <cprintf>
	    }
}
f01037ea:	83 c4 3c             	add    $0x3c,%esp
f01037ed:	5b                   	pop    %ebx
f01037ee:	5e                   	pop    %esi
f01037ef:	5f                   	pop    %edi
f01037f0:	5d                   	pop    %ebp
f01037f1:	c3                   	ret    

f01037f2 <env_free>:
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f01037f2:	55                   	push   %ebp
f01037f3:	89 e5                	mov    %esp,%ebp
f01037f5:	57                   	push   %edi
f01037f6:	56                   	push   %esi
f01037f7:	53                   	push   %ebx
f01037f8:	83 ec 2c             	sub    $0x2c,%esp
f01037fb:	8b 7d 08             	mov    0x8(%ebp),%edi
	physaddr_t pa;

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
f01037fe:	e8 90 2c 00 00       	call   f0106493 <cpunum>
f0103803:	6b c0 74             	imul   $0x74,%eax,%eax
f0103806:	39 b8 28 d0 1c f0    	cmp    %edi,-0xfe32fd8(%eax)
f010380c:	74 09                	je     f0103817 <env_free+0x25>
//
// Frees env e and all memory it uses.
//
void
env_free(struct Env *e)
{
f010380e:	c7 45 e0 00 00 00 00 	movl   $0x0,-0x20(%ebp)
f0103815:	eb 36                	jmp    f010384d <env_free+0x5b>

	// If freeing the current environment, switch to kern_pgdir
	// before freeing the page directory, just in case the page
	// gets reused.
	if (e == curenv)
		lcr3(PADDR(kern_pgdir));
f0103817:	a1 8c ce 1c f0       	mov    0xf01cce8c,%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f010381c:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103821:	77 20                	ja     f0103843 <env_free+0x51>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103823:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103827:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f010382e:	f0 
f010382f:	c7 44 24 04 1c 02 00 	movl   $0x21c,0x4(%esp)
f0103836:	00 
f0103837:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f010383e:	e8 fd c7 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103843:	05 00 00 00 10       	add    $0x10000000,%eax
f0103848:	0f 22 d8             	mov    %eax,%cr3
f010384b:	eb c1                	jmp    f010380e <env_free+0x1c>
f010384d:	8b 4d e0             	mov    -0x20(%ebp),%ecx
f0103850:	89 c8                	mov    %ecx,%eax
f0103852:	c1 e0 02             	shl    $0x2,%eax
f0103855:	89 45 dc             	mov    %eax,-0x24(%ebp)
	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {

		// only look at mapped page tables
		if (!(e->env_pgdir[pdeno] & PTE_P))
f0103858:	8b 47 60             	mov    0x60(%edi),%eax
f010385b:	8b 34 88             	mov    (%eax,%ecx,4),%esi
f010385e:	f7 c6 01 00 00 00    	test   $0x1,%esi
f0103864:	0f 84 b7 00 00 00    	je     f0103921 <env_free+0x12f>
			continue;

		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
f010386a:	81 e6 00 f0 ff ff    	and    $0xfffff000,%esi
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103870:	89 f0                	mov    %esi,%eax
f0103872:	c1 e8 0c             	shr    $0xc,%eax
f0103875:	89 45 d8             	mov    %eax,-0x28(%ebp)
f0103878:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f010387e:	72 20                	jb     f01038a0 <env_free+0xae>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0103880:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0103884:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f010388b:	f0 
f010388c:	c7 44 24 04 2b 02 00 	movl   $0x22b,0x4(%esp)
f0103893:	00 
f0103894:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f010389b:	e8 a0 c7 ff ff       	call   f0100040 <_panic>
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01038a0:	8b 45 e0             	mov    -0x20(%ebp),%eax
f01038a3:	c1 e0 16             	shl    $0x16,%eax
f01038a6:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f01038a9:	bb 00 00 00 00       	mov    $0x0,%ebx
			if (pt[pteno] & PTE_P)
f01038ae:	f6 84 9e 00 00 00 f0 	testb  $0x1,-0x10000000(%esi,%ebx,4)
f01038b5:	01 
f01038b6:	74 17                	je     f01038cf <env_free+0xdd>
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
f01038b8:	89 d8                	mov    %ebx,%eax
f01038ba:	c1 e0 0c             	shl    $0xc,%eax
f01038bd:	0b 45 e4             	or     -0x1c(%ebp),%eax
f01038c0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01038c4:	8b 47 60             	mov    0x60(%edi),%eax
f01038c7:	89 04 24             	mov    %eax,(%esp)
f01038ca:	e8 01 db ff ff       	call   f01013d0 <page_remove>
		// find the pa and va of the page table
		pa = PTE_ADDR(e->env_pgdir[pdeno]);
		pt = (pte_t*) KADDR(pa);

		// unmap all PTEs in this page table
		for (pteno = 0; pteno <= PTX(~0); pteno++) {
f01038cf:	83 c3 01             	add    $0x1,%ebx
f01038d2:	81 fb 00 04 00 00    	cmp    $0x400,%ebx
f01038d8:	75 d4                	jne    f01038ae <env_free+0xbc>
			if (pt[pteno] & PTE_P)
				page_remove(e->env_pgdir, PGADDR(pdeno, pteno, 0));
		}

		// free the page table itself
		e->env_pgdir[pdeno] = 0;
f01038da:	8b 47 60             	mov    0x60(%edi),%eax
f01038dd:	8b 55 dc             	mov    -0x24(%ebp),%edx
f01038e0:	c7 04 10 00 00 00 00 	movl   $0x0,(%eax,%edx,1)
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01038e7:	8b 45 d8             	mov    -0x28(%ebp),%eax
f01038ea:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f01038f0:	72 1c                	jb     f010390e <env_free+0x11c>
		panic("pa2page called with invalid pa");
f01038f2:	c7 44 24 08 a4 75 10 	movl   $0xf01075a4,0x8(%esp)
f01038f9:	f0 
f01038fa:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103901:	00 
f0103902:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f0103909:	e8 32 c7 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f010390e:	a1 90 ce 1c f0       	mov    0xf01cce90,%eax
f0103913:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0103916:	8d 04 d0             	lea    (%eax,%edx,8),%eax
		page_decref(pa2page(pa));
f0103919:	89 04 24             	mov    %eax,(%esp)
f010391c:	e8 a2 d8 ff ff       	call   f01011c3 <page_decref>
	// Note the environment's demise.
	// cprintf("[%08x] free env %08x\n", curenv ? curenv->env_id : 0, e->env_id);

	// Flush all mapped pages in the user portion of the address space
	static_assert(UTOP % PTSIZE == 0);
	for (pdeno = 0; pdeno < PDX(UTOP); pdeno++) {
f0103921:	83 45 e0 01          	addl   $0x1,-0x20(%ebp)
f0103925:	81 7d e0 bb 03 00 00 	cmpl   $0x3bb,-0x20(%ebp)
f010392c:	0f 85 1b ff ff ff    	jne    f010384d <env_free+0x5b>
		e->env_pgdir[pdeno] = 0;
		page_decref(pa2page(pa));
	}

	// free the page directory
	pa = PADDR(e->env_pgdir);
f0103932:	8b 47 60             	mov    0x60(%edi),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103935:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f010393a:	77 20                	ja     f010395c <env_free+0x16a>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f010393c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103940:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0103947:	f0 
f0103948:	c7 44 24 04 39 02 00 	movl   $0x239,0x4(%esp)
f010394f:	00 
f0103950:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f0103957:	e8 e4 c6 ff ff       	call   f0100040 <_panic>
	e->env_pgdir = 0;
f010395c:	c7 47 60 00 00 00 00 	movl   $0x0,0x60(%edi)
	return (physaddr_t)kva - KERNBASE;
f0103963:	05 00 00 00 10       	add    $0x10000000,%eax
}

static inline struct Page*
pa2page(physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0103968:	c1 e8 0c             	shr    $0xc,%eax
f010396b:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f0103971:	72 1c                	jb     f010398f <env_free+0x19d>
		panic("pa2page called with invalid pa");
f0103973:	c7 44 24 08 a4 75 10 	movl   $0xf01075a4,0x8(%esp)
f010397a:	f0 
f010397b:	c7 44 24 04 4f 00 00 	movl   $0x4f,0x4(%esp)
f0103982:	00 
f0103983:	c7 04 24 36 71 10 f0 	movl   $0xf0107136,(%esp)
f010398a:	e8 b1 c6 ff ff       	call   f0100040 <_panic>
	return &pages[PGNUM(pa)];
f010398f:	8b 15 90 ce 1c f0    	mov    0xf01cce90,%edx
f0103995:	8d 04 c2             	lea    (%edx,%eax,8),%eax
	page_decref(pa2page(pa));
f0103998:	89 04 24             	mov    %eax,(%esp)
f010399b:	e8 23 d8 ff ff       	call   f01011c3 <page_decref>

	// return the environment to the free list
	e->env_status = ENV_FREE;
f01039a0:	c7 47 54 00 00 00 00 	movl   $0x0,0x54(%edi)
	e->env_link = env_free_list;
f01039a7:	a1 4c c2 1c f0       	mov    0xf01cc24c,%eax
f01039ac:	89 47 44             	mov    %eax,0x44(%edi)
	env_free_list = e;
f01039af:	89 3d 4c c2 1c f0    	mov    %edi,0xf01cc24c
}
f01039b5:	83 c4 2c             	add    $0x2c,%esp
f01039b8:	5b                   	pop    %ebx
f01039b9:	5e                   	pop    %esi
f01039ba:	5f                   	pop    %edi
f01039bb:	5d                   	pop    %ebp
f01039bc:	c3                   	ret    

f01039bd <env_destroy>:
// If e was the current env, then runs a new environment (and does not return
// to the caller).
//
void
env_destroy(struct Env *e)
{
f01039bd:	55                   	push   %ebp
f01039be:	89 e5                	mov    %esp,%ebp
f01039c0:	53                   	push   %ebx
f01039c1:	83 ec 14             	sub    $0x14,%esp
f01039c4:	8b 5d 08             	mov    0x8(%ebp),%ebx
	// If e is currently running on other CPUs, we change its state to
	// ENV_DYING. A zombie environment will be freed the next time
	// it traps to the kernel.
	if (e->env_status == ENV_RUNNING && curenv != e) {
f01039c7:	83 7b 54 03          	cmpl   $0x3,0x54(%ebx)
f01039cb:	75 19                	jne    f01039e6 <env_destroy+0x29>
f01039cd:	e8 c1 2a 00 00       	call   f0106493 <cpunum>
f01039d2:	6b c0 74             	imul   $0x74,%eax,%eax
f01039d5:	39 98 28 d0 1c f0    	cmp    %ebx,-0xfe32fd8(%eax)
f01039db:	74 09                	je     f01039e6 <env_destroy+0x29>
		e->env_status = ENV_DYING;
f01039dd:	c7 43 54 01 00 00 00 	movl   $0x1,0x54(%ebx)
		return;
f01039e4:	eb 2f                	jmp    f0103a15 <env_destroy+0x58>
	}

	env_free(e);
f01039e6:	89 1c 24             	mov    %ebx,(%esp)
f01039e9:	e8 04 fe ff ff       	call   f01037f2 <env_free>

	if (curenv == e) {
f01039ee:	e8 a0 2a 00 00       	call   f0106493 <cpunum>
f01039f3:	6b c0 74             	imul   $0x74,%eax,%eax
f01039f6:	39 98 28 d0 1c f0    	cmp    %ebx,-0xfe32fd8(%eax)
f01039fc:	75 17                	jne    f0103a15 <env_destroy+0x58>
		curenv = NULL;
f01039fe:	e8 90 2a 00 00       	call   f0106493 <cpunum>
f0103a03:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a06:	c7 80 28 d0 1c f0 00 	movl   $0x0,-0xfe32fd8(%eax)
f0103a0d:	00 00 00 
		sched_yield();
f0103a10:	e8 9b 0f 00 00       	call   f01049b0 <sched_yield>
	}
}
f0103a15:	83 c4 14             	add    $0x14,%esp
f0103a18:	5b                   	pop    %ebx
f0103a19:	5d                   	pop    %ebp
f0103a1a:	c3                   	ret    

f0103a1b <env_pop_tf>:
//
// This function does not return.
//
void
env_pop_tf(struct Trapframe *tf)
{
f0103a1b:	55                   	push   %ebp
f0103a1c:	89 e5                	mov    %esp,%ebp
f0103a1e:	53                   	push   %ebx
f0103a1f:	83 ec 14             	sub    $0x14,%esp
	// Record the CPU we are running on for user-space debugging
	curenv->env_cpunum = cpunum();
f0103a22:	e8 6c 2a 00 00       	call   f0106493 <cpunum>
f0103a27:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a2a:	8b 98 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%ebx
f0103a30:	e8 5e 2a 00 00       	call   f0106493 <cpunum>
f0103a35:	89 43 5c             	mov    %eax,0x5c(%ebx)

	__asm __volatile("movl %0,%%esp\n"
f0103a38:	8b 65 08             	mov    0x8(%ebp),%esp
f0103a3b:	61                   	popa   
f0103a3c:	07                   	pop    %es
f0103a3d:	1f                   	pop    %ds
f0103a3e:	83 c4 08             	add    $0x8,%esp
f0103a41:	cf                   	iret   
		"\tpopl %%es\n"
		"\tpopl %%ds\n"
		"\taddl $0x8,%%esp\n" /* skip tf_trapno and tf_errcode */
		"\tiret"
		: : "g" (tf) : "memory");
	panic("iret failed");  /* mostly to placate the compiler */
f0103a42:	c7 44 24 08 c1 7c 10 	movl   $0xf0107cc1,0x8(%esp)
f0103a49:	f0 
f0103a4a:	c7 44 24 04 6f 02 00 	movl   $0x26f,0x4(%esp)
f0103a51:	00 
f0103a52:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f0103a59:	e8 e2 c5 ff ff       	call   f0100040 <_panic>

f0103a5e <env_run>:
//
// This function does not return.
//
void
env_run(struct Env *e)
{
f0103a5e:	55                   	push   %ebp
f0103a5f:	89 e5                	mov    %esp,%ebp
f0103a61:	53                   	push   %ebx
f0103a62:	83 ec 14             	sub    $0x14,%esp
f0103a65:	8b 5d 08             	mov    0x8(%ebp),%ebx
	//	and make sure you have set the relevant parts of
	//	e->env_tf to sensible values.

	// LAB 3: Your code here.
	//cprintf("Run env!\r\n");
    if(curenv!=NULL)
f0103a68:	e8 26 2a 00 00       	call   f0106493 <cpunum>
f0103a6d:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a70:	83 b8 28 d0 1c f0 00 	cmpl   $0x0,-0xfe32fd8(%eax)
f0103a77:	74 29                	je     f0103aa2 <env_run+0x44>
    {
    	if(curenv->env_status==ENV_RUNNING)
f0103a79:	e8 15 2a 00 00       	call   f0106493 <cpunum>
f0103a7e:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a81:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0103a87:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f0103a8b:	75 15                	jne    f0103aa2 <env_run+0x44>
    	{
    		curenv->env_status=ENV_RUNNABLE;
f0103a8d:	e8 01 2a 00 00       	call   f0106493 <cpunum>
f0103a92:	6b c0 74             	imul   $0x74,%eax,%eax
f0103a95:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0103a9b:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
    	}
    }
    curenv=e;
f0103aa2:	e8 ec 29 00 00       	call   f0106493 <cpunum>
f0103aa7:	6b c0 74             	imul   $0x74,%eax,%eax
f0103aaa:	89 98 28 d0 1c f0    	mov    %ebx,-0xfe32fd8(%eax)
    e->env_status=ENV_RUNNING;
f0103ab0:	c7 43 54 03 00 00 00 	movl   $0x3,0x54(%ebx)
    e->env_runs++;
f0103ab7:	83 43 58 01          	addl   $0x1,0x58(%ebx)
    lcr3(PADDR(e->env_pgdir));
f0103abb:	8b 43 60             	mov    0x60(%ebx),%eax
#define PADDR(kva) _paddr(__FILE__, __LINE__, kva)

static inline physaddr_t
_paddr(const char *file, int line, void *kva)
{
	if ((uint32_t)kva < KERNBASE)
f0103abe:	3d ff ff ff ef       	cmp    $0xefffffff,%eax
f0103ac3:	77 20                	ja     f0103ae5 <env_run+0x87>
		_panic(file, line, "PADDR called with invalid kva %08lx", kva);
f0103ac5:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103ac9:	c7 44 24 08 e8 6b 10 	movl   $0xf0106be8,0x8(%esp)
f0103ad0:	f0 
f0103ad1:	c7 44 24 04 98 02 00 	movl   $0x298,0x4(%esp)
f0103ad8:	00 
f0103ad9:	c7 04 24 55 7c 10 f0 	movl   $0xf0107c55,(%esp)
f0103ae0:	e8 5b c5 ff ff       	call   f0100040 <_panic>
	return (physaddr_t)kva - KERNBASE;
f0103ae5:	05 00 00 00 10       	add    $0x10000000,%eax
f0103aea:	0f 22 d8             	mov    %eax,%cr3
}

static inline void
unlock_kernel(void)
{
	spin_unlock(&kernel_lock);
f0103aed:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f0103af4:	e8 e3 2c 00 00       	call   f01067dc <spin_unlock>

	// Normally we wouldn't need to do this, but QEMU only runs
	// one CPU at a time and has a long time-slice.  Without the
	// pause, this CPU is likely to reacquire the lock before
	// another CPU has even been given a chance to acquire it.
	asm volatile("pause");
f0103af9:	f3 90                	pause  
	unlock_kernel();
    env_pop_tf(&e->env_tf);
f0103afb:	89 1c 24             	mov    %ebx,(%esp)
f0103afe:	e8 18 ff ff ff       	call   f0103a1b <env_pop_tf>

f0103b03 <mc146818_read>:
#include <kern/kclock.h>


unsigned
mc146818_read(unsigned reg)
{
f0103b03:	55                   	push   %ebp
f0103b04:	89 e5                	mov    %esp,%ebp
f0103b06:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103b0a:	ba 70 00 00 00       	mov    $0x70,%edx
f0103b0f:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f0103b10:	b2 71                	mov    $0x71,%dl
f0103b12:	ec                   	in     (%dx),%al
	outb(IO_RTC, reg);
	return inb(IO_RTC+1);
f0103b13:	0f b6 c0             	movzbl %al,%eax
}
f0103b16:	5d                   	pop    %ebp
f0103b17:	c3                   	ret    

f0103b18 <mc146818_write>:

void
mc146818_write(unsigned reg, unsigned datum)
{
f0103b18:	55                   	push   %ebp
f0103b19:	89 e5                	mov    %esp,%ebp
f0103b1b:	0f b6 45 08          	movzbl 0x8(%ebp),%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0103b1f:	ba 70 00 00 00       	mov    $0x70,%edx
f0103b24:	ee                   	out    %al,(%dx)
f0103b25:	b2 71                	mov    $0x71,%dl
f0103b27:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103b2a:	ee                   	out    %al,(%dx)
	outb(IO_RTC, reg);
	outb(IO_RTC+1, datum);
}
f0103b2b:	5d                   	pop    %ebp
f0103b2c:	c3                   	ret    

f0103b2d <irq_setmask_8259A>:
		irq_setmask_8259A(irq_mask_8259A);
}

void
irq_setmask_8259A(uint16_t mask)
{
f0103b2d:	55                   	push   %ebp
f0103b2e:	89 e5                	mov    %esp,%ebp
f0103b30:	56                   	push   %esi
f0103b31:	53                   	push   %ebx
f0103b32:	83 ec 10             	sub    $0x10,%esp
f0103b35:	8b 45 08             	mov    0x8(%ebp),%eax
	int i;
	irq_mask_8259A = mask;
f0103b38:	66 a3 88 13 12 f0    	mov    %ax,0xf0121388
	if (!didinit)
f0103b3e:	83 3d 50 c2 1c f0 00 	cmpl   $0x0,0xf01cc250
f0103b45:	74 4e                	je     f0103b95 <irq_setmask_8259A+0x68>
f0103b47:	89 c6                	mov    %eax,%esi
f0103b49:	ba 21 00 00 00       	mov    $0x21,%edx
f0103b4e:	ee                   	out    %al,(%dx)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
f0103b4f:	66 c1 e8 08          	shr    $0x8,%ax
f0103b53:	b2 a1                	mov    $0xa1,%dl
f0103b55:	ee                   	out    %al,(%dx)
	cprintf("enabled interrupts:");
f0103b56:	c7 04 24 cd 7c 10 f0 	movl   $0xf0107ccd,(%esp)
f0103b5d:	e8 0d 01 00 00       	call   f0103c6f <cprintf>
	for (i = 0; i < 16; i++)
f0103b62:	bb 00 00 00 00       	mov    $0x0,%ebx
		if (~mask & (1<<i))
f0103b67:	0f b7 f6             	movzwl %si,%esi
f0103b6a:	f7 d6                	not    %esi
f0103b6c:	0f a3 de             	bt     %ebx,%esi
f0103b6f:	73 10                	jae    f0103b81 <irq_setmask_8259A+0x54>
			cprintf(" %d", i);
f0103b71:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0103b75:	c7 04 24 49 72 10 f0 	movl   $0xf0107249,(%esp)
f0103b7c:	e8 ee 00 00 00       	call   f0103c6f <cprintf>
	if (!didinit)
		return;
	outb(IO_PIC1+1, (char)mask);
	outb(IO_PIC2+1, (char)(mask >> 8));
	cprintf("enabled interrupts:");
	for (i = 0; i < 16; i++)
f0103b81:	83 c3 01             	add    $0x1,%ebx
f0103b84:	83 fb 10             	cmp    $0x10,%ebx
f0103b87:	75 e3                	jne    f0103b6c <irq_setmask_8259A+0x3f>
		if (~mask & (1<<i))
			cprintf(" %d", i);
	cprintf("\n");
f0103b89:	c7 04 24 bf 7c 10 f0 	movl   $0xf0107cbf,(%esp)
f0103b90:	e8 da 00 00 00       	call   f0103c6f <cprintf>
}
f0103b95:	83 c4 10             	add    $0x10,%esp
f0103b98:	5b                   	pop    %ebx
f0103b99:	5e                   	pop    %esi
f0103b9a:	5d                   	pop    %ebp
f0103b9b:	c3                   	ret    

f0103b9c <pic_init>:

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
	didinit = 1;
f0103b9c:	c7 05 50 c2 1c f0 01 	movl   $0x1,0xf01cc250
f0103ba3:	00 00 00 
f0103ba6:	ba 21 00 00 00       	mov    $0x21,%edx
f0103bab:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0103bb0:	ee                   	out    %al,(%dx)
f0103bb1:	b2 a1                	mov    $0xa1,%dl
f0103bb3:	ee                   	out    %al,(%dx)
f0103bb4:	b2 20                	mov    $0x20,%dl
f0103bb6:	b8 11 00 00 00       	mov    $0x11,%eax
f0103bbb:	ee                   	out    %al,(%dx)
f0103bbc:	b2 21                	mov    $0x21,%dl
f0103bbe:	b8 20 00 00 00       	mov    $0x20,%eax
f0103bc3:	ee                   	out    %al,(%dx)
f0103bc4:	b8 04 00 00 00       	mov    $0x4,%eax
f0103bc9:	ee                   	out    %al,(%dx)
f0103bca:	b8 03 00 00 00       	mov    $0x3,%eax
f0103bcf:	ee                   	out    %al,(%dx)
f0103bd0:	b2 a0                	mov    $0xa0,%dl
f0103bd2:	b8 11 00 00 00       	mov    $0x11,%eax
f0103bd7:	ee                   	out    %al,(%dx)
f0103bd8:	b2 a1                	mov    $0xa1,%dl
f0103bda:	b8 28 00 00 00       	mov    $0x28,%eax
f0103bdf:	ee                   	out    %al,(%dx)
f0103be0:	b8 02 00 00 00       	mov    $0x2,%eax
f0103be5:	ee                   	out    %al,(%dx)
f0103be6:	b8 01 00 00 00       	mov    $0x1,%eax
f0103beb:	ee                   	out    %al,(%dx)
f0103bec:	b2 20                	mov    $0x20,%dl
f0103bee:	b8 68 00 00 00       	mov    $0x68,%eax
f0103bf3:	ee                   	out    %al,(%dx)
f0103bf4:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103bf9:	ee                   	out    %al,(%dx)
f0103bfa:	b2 a0                	mov    $0xa0,%dl
f0103bfc:	b8 68 00 00 00       	mov    $0x68,%eax
f0103c01:	ee                   	out    %al,(%dx)
f0103c02:	b8 0a 00 00 00       	mov    $0xa,%eax
f0103c07:	ee                   	out    %al,(%dx)
	outb(IO_PIC1, 0x0a);             /* read IRR by default */

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
f0103c08:	0f b7 05 88 13 12 f0 	movzwl 0xf0121388,%eax
f0103c0f:	66 83 f8 ff          	cmp    $0xffff,%ax
f0103c13:	74 12                	je     f0103c27 <pic_init+0x8b>
static bool didinit;

/* Initialize the 8259A interrupt controllers. */
void
pic_init(void)
{
f0103c15:	55                   	push   %ebp
f0103c16:	89 e5                	mov    %esp,%ebp
f0103c18:	83 ec 18             	sub    $0x18,%esp

	outb(IO_PIC2, 0x68);               /* OCW3 */
	outb(IO_PIC2, 0x0a);               /* OCW3 */

	if (irq_mask_8259A != 0xFFFF)
		irq_setmask_8259A(irq_mask_8259A);
f0103c1b:	0f b7 c0             	movzwl %ax,%eax
f0103c1e:	89 04 24             	mov    %eax,(%esp)
f0103c21:	e8 07 ff ff ff       	call   f0103b2d <irq_setmask_8259A>
}
f0103c26:	c9                   	leave  
f0103c27:	f3 c3                	repz ret 

f0103c29 <putch>:
#include <inc/stdarg.h>


static void
putch(int ch, int *cnt)
{
f0103c29:	55                   	push   %ebp
f0103c2a:	89 e5                	mov    %esp,%ebp
f0103c2c:	83 ec 18             	sub    $0x18,%esp
	cputchar(ch);
f0103c2f:	8b 45 08             	mov    0x8(%ebp),%eax
f0103c32:	89 04 24             	mov    %eax,(%esp)
f0103c35:	e8 c3 cb ff ff       	call   f01007fd <cputchar>
	*cnt++;
}
f0103c3a:	c9                   	leave  
f0103c3b:	c3                   	ret    

f0103c3c <vcprintf>:

int
vcprintf(const char *fmt, va_list ap)
{
f0103c3c:	55                   	push   %ebp
f0103c3d:	89 e5                	mov    %esp,%ebp
f0103c3f:	83 ec 28             	sub    $0x28,%esp
	int cnt = 0;
f0103c42:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	vprintfmt((void*)putch, &cnt, fmt, ap);
f0103c49:	8b 45 0c             	mov    0xc(%ebp),%eax
f0103c4c:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0103c50:	8b 45 08             	mov    0x8(%ebp),%eax
f0103c53:	89 44 24 08          	mov    %eax,0x8(%esp)
f0103c57:	8d 45 f4             	lea    -0xc(%ebp),%eax
f0103c5a:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c5e:	c7 04 24 29 3c 10 f0 	movl   $0xf0103c29,(%esp)
f0103c65:	e8 90 19 00 00       	call   f01055fa <vprintfmt>
	return cnt;
}
f0103c6a:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0103c6d:	c9                   	leave  
f0103c6e:	c3                   	ret    

f0103c6f <cprintf>:

int
cprintf(const char *fmt, ...)
{
f0103c6f:	55                   	push   %ebp
f0103c70:	89 e5                	mov    %esp,%ebp
f0103c72:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int cnt;

	va_start(ap, fmt);
f0103c75:	8d 45 0c             	lea    0xc(%ebp),%eax
	cnt = vcprintf(fmt, ap);
f0103c78:	89 44 24 04          	mov    %eax,0x4(%esp)
f0103c7c:	8b 45 08             	mov    0x8(%ebp),%eax
f0103c7f:	89 04 24             	mov    %eax,(%esp)
f0103c82:	e8 b5 ff ff ff       	call   f0103c3c <vcprintf>
	va_end(ap);

	return cnt;
}
f0103c87:	c9                   	leave  
f0103c88:	c3                   	ret    
f0103c89:	66 90                	xchg   %ax,%ax
f0103c8b:	66 90                	xchg   %ax,%ax
f0103c8d:	66 90                	xchg   %ax,%ax
f0103c8f:	90                   	nop

f0103c90 <trap_init_percpu>:


// Initialize and load the per-CPU TSS and IDT
void
trap_init_percpu(void)
{
f0103c90:	55                   	push   %ebp
f0103c91:	89 e5                	mov    %esp,%ebp
f0103c93:	53                   	push   %ebx
f0103c94:	83 ec 04             	sub    $0x4,%esp
	// wrong, you may not get a fault until you try to return from
	// user space on that CPU.
	//
	// LAB 4: Your code here:

	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103c97:	e8 f7 27 00 00       	call   f0106493 <cpunum>
f0103c9c:	6b d8 74             	imul   $0x74,%eax,%ebx
	int CPUID = cpunum();
f0103c9f:	e8 ef 27 00 00       	call   f0106493 <cpunum>

	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
f0103ca4:	89 c2                	mov    %eax,%edx
f0103ca6:	f7 da                	neg    %edx
f0103ca8:	c1 e2 10             	shl    $0x10,%edx
f0103cab:	81 ea 00 00 40 10    	sub    $0x10400000,%edx
f0103cb1:	89 93 30 d0 1c f0    	mov    %edx,-0xfe32fd0(%ebx)
	this_ts->ts_ss0 = GD_KD;
f0103cb7:	66 c7 83 34 d0 1c f0 	movw   $0x10,-0xfe32fcc(%ebx)
f0103cbe:	10 00 
	// wrong, you may not get a fault until you try to return from
	// user space on that CPU.
	//
	// LAB 4: Your code here:

	struct Taskstate* this_ts = &thiscpu->cpu_ts;
f0103cc0:	81 c3 2c d0 1c f0    	add    $0xf01cd02c,%ebx
	int CPUID = cpunum();

	this_ts->ts_esp0 = KSTACKTOP - CPUID * (KSTKGAP + KSTKSIZE);
	this_ts->ts_ss0 = GD_KD;

	gdt[(GD_TSS0 >> 3) + CPUID] = SEG16(STS_T32A, (uint32_t) (this_ts),
f0103cc6:	8d 50 05             	lea    0x5(%eax),%edx
f0103cc9:	66 c7 04 d5 20 13 12 	movw   $0x68,-0xfedece0(,%edx,8)
f0103cd0:	f0 68 00 
f0103cd3:	66 89 1c d5 22 13 12 	mov    %bx,-0xfedecde(,%edx,8)
f0103cda:	f0 
f0103cdb:	89 d9                	mov    %ebx,%ecx
f0103cdd:	c1 e9 10             	shr    $0x10,%ecx
f0103ce0:	88 0c d5 24 13 12 f0 	mov    %cl,-0xfedecdc(,%edx,8)
f0103ce7:	c6 04 d5 26 13 12 f0 	movb   $0x40,-0xfedecda(,%edx,8)
f0103cee:	40 
f0103cef:	c1 eb 18             	shr    $0x18,%ebx
f0103cf2:	88 1c d5 27 13 12 f0 	mov    %bl,-0xfedecd9(,%edx,8)
					sizeof(struct Taskstate), 0);
	gdt[(GD_TSS0 >> 3) + CPUID].sd_s = 0;
f0103cf9:	c6 04 d5 25 13 12 f0 	movb   $0x89,-0xfedecdb(,%edx,8)
f0103d00:	89 

	//cprintf("Loading GD_TSS_ %d\n", ((GD_TSS0>>3) + CPUID)<<3);

	ltr(GD_TSS0 + (CPUID << 3));
f0103d01:	8d 04 c5 28 00 00 00 	lea    0x28(,%eax,8),%eax
}

static __inline void
ltr(uint16_t sel)
{
	__asm __volatile("ltr %0" : : "r" (sel));
f0103d08:	0f 00 d8             	ltr    %ax
}  

static __inline void
lidt(void *p)
{
	__asm __volatile("lidt (%0)" : : "r" (p));
f0103d0b:	b8 8a 13 12 f0       	mov    $0xf012138a,%eax
f0103d10:	0f 01 18             	lidtl  (%eax)
	// bottom three bits are special; we leave them 0)
	ltr(GD_TSS0);

	// Load the IDT
	lidt(&idt_pd);
}
f0103d13:	83 c4 04             	add    $0x4,%esp
f0103d16:	5b                   	pop    %ebx
f0103d17:	5d                   	pop    %ebp
f0103d18:	c3                   	ret    

f0103d19 <trap_init>:
}


void
trap_init(void)
{
f0103d19:	55                   	push   %ebp
f0103d1a:	89 e5                	mov    %esp,%ebp
f0103d1c:	83 ec 08             	sub    $0x8,%esp
	extern struct Segdesc gdt[];
	SETGATE(idt[0], 1, GD_KT, dividezero_handler, 0);
f0103d1f:	b8 ac 48 10 f0       	mov    $0xf01048ac,%eax
f0103d24:	66 a3 60 c2 1c f0    	mov    %ax,0xf01cc260
f0103d2a:	66 c7 05 62 c2 1c f0 	movw   $0x8,0xf01cc262
f0103d31:	08 00 
f0103d33:	c6 05 64 c2 1c f0 00 	movb   $0x0,0xf01cc264
f0103d3a:	c6 05 65 c2 1c f0 8f 	movb   $0x8f,0xf01cc265
f0103d41:	c1 e8 10             	shr    $0x10,%eax
f0103d44:	66 a3 66 c2 1c f0    	mov    %ax,0xf01cc266
	SETGATE(idt[2], 0, GD_KT, nmi_handler, 0);
f0103d4a:	b8 b6 48 10 f0       	mov    $0xf01048b6,%eax
f0103d4f:	66 a3 70 c2 1c f0    	mov    %ax,0xf01cc270
f0103d55:	66 c7 05 72 c2 1c f0 	movw   $0x8,0xf01cc272
f0103d5c:	08 00 
f0103d5e:	c6 05 74 c2 1c f0 00 	movb   $0x0,0xf01cc274
f0103d65:	c6 05 75 c2 1c f0 8e 	movb   $0x8e,0xf01cc275
f0103d6c:	c1 e8 10             	shr    $0x10,%eax
f0103d6f:	66 a3 76 c2 1c f0    	mov    %ax,0xf01cc276
	SETGATE(idt[3], 1, GD_KT, breakpoint_handler, 3);
f0103d75:	b8 c0 48 10 f0       	mov    $0xf01048c0,%eax
f0103d7a:	66 a3 78 c2 1c f0    	mov    %ax,0xf01cc278
f0103d80:	66 c7 05 7a c2 1c f0 	movw   $0x8,0xf01cc27a
f0103d87:	08 00 
f0103d89:	c6 05 7c c2 1c f0 00 	movb   $0x0,0xf01cc27c
f0103d90:	c6 05 7d c2 1c f0 ef 	movb   $0xef,0xf01cc27d
f0103d97:	c1 e8 10             	shr    $0x10,%eax
f0103d9a:	66 a3 7e c2 1c f0    	mov    %ax,0xf01cc27e
	SETGATE(idt[4], 1, GD_KT, overflow_handler, 3);
f0103da0:	b8 ca 48 10 f0       	mov    $0xf01048ca,%eax
f0103da5:	66 a3 80 c2 1c f0    	mov    %ax,0xf01cc280
f0103dab:	66 c7 05 82 c2 1c f0 	movw   $0x8,0xf01cc282
f0103db2:	08 00 
f0103db4:	c6 05 84 c2 1c f0 00 	movb   $0x0,0xf01cc284
f0103dbb:	c6 05 85 c2 1c f0 ef 	movb   $0xef,0xf01cc285
f0103dc2:	c1 e8 10             	shr    $0x10,%eax
f0103dc5:	66 a3 86 c2 1c f0    	mov    %ax,0xf01cc286
	SETGATE(idt[5], 1, GD_KT, bdrgeexceed_handler, 3);
f0103dcb:	b8 d4 48 10 f0       	mov    $0xf01048d4,%eax
f0103dd0:	66 a3 88 c2 1c f0    	mov    %ax,0xf01cc288
f0103dd6:	66 c7 05 8a c2 1c f0 	movw   $0x8,0xf01cc28a
f0103ddd:	08 00 
f0103ddf:	c6 05 8c c2 1c f0 00 	movb   $0x0,0xf01cc28c
f0103de6:	c6 05 8d c2 1c f0 ef 	movb   $0xef,0xf01cc28d
f0103ded:	c1 e8 10             	shr    $0x10,%eax
f0103df0:	66 a3 8e c2 1c f0    	mov    %ax,0xf01cc28e
	SETGATE(idt[6], 1, GD_KT, invalidop_handler, 0);
f0103df6:	b8 de 48 10 f0       	mov    $0xf01048de,%eax
f0103dfb:	66 a3 90 c2 1c f0    	mov    %ax,0xf01cc290
f0103e01:	66 c7 05 92 c2 1c f0 	movw   $0x8,0xf01cc292
f0103e08:	08 00 
f0103e0a:	c6 05 94 c2 1c f0 00 	movb   $0x0,0xf01cc294
f0103e11:	c6 05 95 c2 1c f0 8f 	movb   $0x8f,0xf01cc295
f0103e18:	c1 e8 10             	shr    $0x10,%eax
f0103e1b:	66 a3 96 c2 1c f0    	mov    %ax,0xf01cc296
	SETGATE(idt[7], 1, GD_KT, nomathcopro_handler, 0);
f0103e21:	b8 e8 48 10 f0       	mov    $0xf01048e8,%eax
f0103e26:	66 a3 98 c2 1c f0    	mov    %ax,0xf01cc298
f0103e2c:	66 c7 05 9a c2 1c f0 	movw   $0x8,0xf01cc29a
f0103e33:	08 00 
f0103e35:	c6 05 9c c2 1c f0 00 	movb   $0x0,0xf01cc29c
f0103e3c:	c6 05 9d c2 1c f0 8f 	movb   $0x8f,0xf01cc29d
f0103e43:	c1 e8 10             	shr    $0x10,%eax
f0103e46:	66 a3 9e c2 1c f0    	mov    %ax,0xf01cc29e
	SETGATE(idt[8], 1, GD_KT, dbfault_handler, 0);
f0103e4c:	b8 f2 48 10 f0       	mov    $0xf01048f2,%eax
f0103e51:	66 a3 a0 c2 1c f0    	mov    %ax,0xf01cc2a0
f0103e57:	66 c7 05 a2 c2 1c f0 	movw   $0x8,0xf01cc2a2
f0103e5e:	08 00 
f0103e60:	c6 05 a4 c2 1c f0 00 	movb   $0x0,0xf01cc2a4
f0103e67:	c6 05 a5 c2 1c f0 8f 	movb   $0x8f,0xf01cc2a5
f0103e6e:	c1 e8 10             	shr    $0x10,%eax
f0103e71:	66 a3 a6 c2 1c f0    	mov    %ax,0xf01cc2a6
	SETGATE(idt[10], 1, GD_KT, invalidTSS_handler, 0);
f0103e77:	b8 fa 48 10 f0       	mov    $0xf01048fa,%eax
f0103e7c:	66 a3 b0 c2 1c f0    	mov    %ax,0xf01cc2b0
f0103e82:	66 c7 05 b2 c2 1c f0 	movw   $0x8,0xf01cc2b2
f0103e89:	08 00 
f0103e8b:	c6 05 b4 c2 1c f0 00 	movb   $0x0,0xf01cc2b4
f0103e92:	c6 05 b5 c2 1c f0 8f 	movb   $0x8f,0xf01cc2b5
f0103e99:	c1 e8 10             	shr    $0x10,%eax
f0103e9c:	66 a3 b6 c2 1c f0    	mov    %ax,0xf01cc2b6

	SETGATE(idt[11], 1, GD_KT, sgmtnotpresent_handler, 0);
f0103ea2:	b8 02 49 10 f0       	mov    $0xf0104902,%eax
f0103ea7:	66 a3 b8 c2 1c f0    	mov    %ax,0xf01cc2b8
f0103ead:	66 c7 05 ba c2 1c f0 	movw   $0x8,0xf01cc2ba
f0103eb4:	08 00 
f0103eb6:	c6 05 bc c2 1c f0 00 	movb   $0x0,0xf01cc2bc
f0103ebd:	c6 05 bd c2 1c f0 8f 	movb   $0x8f,0xf01cc2bd
f0103ec4:	c1 e8 10             	shr    $0x10,%eax
f0103ec7:	66 a3 be c2 1c f0    	mov    %ax,0xf01cc2be
	SETGATE(idt[12], 1, GD_KT, stacksgmtfault_handler, 0);
f0103ecd:	b8 0a 49 10 f0       	mov    $0xf010490a,%eax
f0103ed2:	66 a3 c0 c2 1c f0    	mov    %ax,0xf01cc2c0
f0103ed8:	66 c7 05 c2 c2 1c f0 	movw   $0x8,0xf01cc2c2
f0103edf:	08 00 
f0103ee1:	c6 05 c4 c2 1c f0 00 	movb   $0x0,0xf01cc2c4
f0103ee8:	c6 05 c5 c2 1c f0 8f 	movb   $0x8f,0xf01cc2c5
f0103eef:	c1 e8 10             	shr    $0x10,%eax
f0103ef2:	66 a3 c6 c2 1c f0    	mov    %ax,0xf01cc2c6
	SETGATE(idt[14], 1, GD_KT, pagefault_handler, 0);
f0103ef8:	b8 1a 49 10 f0       	mov    $0xf010491a,%eax
f0103efd:	66 a3 d0 c2 1c f0    	mov    %ax,0xf01cc2d0
f0103f03:	66 c7 05 d2 c2 1c f0 	movw   $0x8,0xf01cc2d2
f0103f0a:	08 00 
f0103f0c:	c6 05 d4 c2 1c f0 00 	movb   $0x0,0xf01cc2d4
f0103f13:	c6 05 d5 c2 1c f0 8f 	movb   $0x8f,0xf01cc2d5
f0103f1a:	c1 e8 10             	shr    $0x10,%eax
f0103f1d:	66 a3 d6 c2 1c f0    	mov    %ax,0xf01cc2d6
	SETGATE(idt[13], 1, GD_KT, generalprotection_handler, 0);
f0103f23:	b8 12 49 10 f0       	mov    $0xf0104912,%eax
f0103f28:	66 a3 c8 c2 1c f0    	mov    %ax,0xf01cc2c8
f0103f2e:	66 c7 05 ca c2 1c f0 	movw   $0x8,0xf01cc2ca
f0103f35:	08 00 
f0103f37:	c6 05 cc c2 1c f0 00 	movb   $0x0,0xf01cc2cc
f0103f3e:	c6 05 cd c2 1c f0 8f 	movb   $0x8f,0xf01cc2cd
f0103f45:	c1 e8 10             	shr    $0x10,%eax
f0103f48:	66 a3 ce c2 1c f0    	mov    %ax,0xf01cc2ce
	SETGATE(idt[16], 1, GD_KT, FPUerror_handler, 0);
f0103f4e:	b8 1e 49 10 f0       	mov    $0xf010491e,%eax
f0103f53:	66 a3 e0 c2 1c f0    	mov    %ax,0xf01cc2e0
f0103f59:	66 c7 05 e2 c2 1c f0 	movw   $0x8,0xf01cc2e2
f0103f60:	08 00 
f0103f62:	c6 05 e4 c2 1c f0 00 	movb   $0x0,0xf01cc2e4
f0103f69:	c6 05 e5 c2 1c f0 8f 	movb   $0x8f,0xf01cc2e5
f0103f70:	c1 e8 10             	shr    $0x10,%eax
f0103f73:	66 a3 e6 c2 1c f0    	mov    %ax,0xf01cc2e6
	SETGATE(idt[17], 1, GD_KT, alignmentcheck_handler, 0);
f0103f79:	b8 24 49 10 f0       	mov    $0xf0104924,%eax
f0103f7e:	66 a3 e8 c2 1c f0    	mov    %ax,0xf01cc2e8
f0103f84:	66 c7 05 ea c2 1c f0 	movw   $0x8,0xf01cc2ea
f0103f8b:	08 00 
f0103f8d:	c6 05 ec c2 1c f0 00 	movb   $0x0,0xf01cc2ec
f0103f94:	c6 05 ed c2 1c f0 8f 	movb   $0x8f,0xf01cc2ed
f0103f9b:	c1 e8 10             	shr    $0x10,%eax
f0103f9e:	66 a3 ee c2 1c f0    	mov    %ax,0xf01cc2ee
	SETGATE(idt[18],1, GD_KT, machinecheck_handler, 0);
f0103fa4:	b8 28 49 10 f0       	mov    $0xf0104928,%eax
f0103fa9:	66 a3 f0 c2 1c f0    	mov    %ax,0xf01cc2f0
f0103faf:	66 c7 05 f2 c2 1c f0 	movw   $0x8,0xf01cc2f2
f0103fb6:	08 00 
f0103fb8:	c6 05 f4 c2 1c f0 00 	movb   $0x0,0xf01cc2f4
f0103fbf:	c6 05 f5 c2 1c f0 8f 	movb   $0x8f,0xf01cc2f5
f0103fc6:	c1 e8 10             	shr    $0x10,%eax
f0103fc9:	66 a3 f6 c2 1c f0    	mov    %ax,0xf01cc2f6
	SETGATE(idt[19], 1, GD_KT, SIMDFPexception_handler, 0);
f0103fcf:	b8 2e 49 10 f0       	mov    $0xf010492e,%eax
f0103fd4:	66 a3 f8 c2 1c f0    	mov    %ax,0xf01cc2f8
f0103fda:	66 c7 05 fa c2 1c f0 	movw   $0x8,0xf01cc2fa
f0103fe1:	08 00 
f0103fe3:	c6 05 fc c2 1c f0 00 	movb   $0x0,0xf01cc2fc
f0103fea:	c6 05 fd c2 1c f0 8f 	movb   $0x8f,0xf01cc2fd
f0103ff1:	c1 e8 10             	shr    $0x10,%eax
f0103ff4:	66 a3 fe c2 1c f0    	mov    %ax,0xf01cc2fe
	SETGATE(idt[48], 0, GD_KT, systemcall_handler, 3);
f0103ffa:	b8 34 49 10 f0       	mov    $0xf0104934,%eax
f0103fff:	66 a3 e0 c3 1c f0    	mov    %ax,0xf01cc3e0
f0104005:	66 c7 05 e2 c3 1c f0 	movw   $0x8,0xf01cc3e2
f010400c:	08 00 
f010400e:	c6 05 e4 c3 1c f0 00 	movb   $0x0,0xf01cc3e4
f0104015:	c6 05 e5 c3 1c f0 ee 	movb   $0xee,0xf01cc3e5
f010401c:	c1 e8 10             	shr    $0x10,%eax
f010401f:	66 a3 e6 c3 1c f0    	mov    %ax,0xf01cc3e6
	// LAB 3: Your code here.
	

	SETGATE(idt[IRQ_OFFSET + 0], 0, GD_KT, t_irq0, 0);
f0104025:	b8 3a 49 10 f0       	mov    $0xf010493a,%eax
f010402a:	66 a3 60 c3 1c f0    	mov    %ax,0xf01cc360
f0104030:	66 c7 05 62 c3 1c f0 	movw   $0x8,0xf01cc362
f0104037:	08 00 
f0104039:	c6 05 64 c3 1c f0 00 	movb   $0x0,0xf01cc364
f0104040:	c6 05 65 c3 1c f0 8e 	movb   $0x8e,0xf01cc365
f0104047:	c1 e8 10             	shr    $0x10,%eax
f010404a:	66 a3 66 c3 1c f0    	mov    %ax,0xf01cc366
	SETGATE(idt[IRQ_OFFSET + 1], 0, GD_KT, t_irq1, 0);
f0104050:	b8 40 49 10 f0       	mov    $0xf0104940,%eax
f0104055:	66 a3 68 c3 1c f0    	mov    %ax,0xf01cc368
f010405b:	66 c7 05 6a c3 1c f0 	movw   $0x8,0xf01cc36a
f0104062:	08 00 
f0104064:	c6 05 6c c3 1c f0 00 	movb   $0x0,0xf01cc36c
f010406b:	c6 05 6d c3 1c f0 8e 	movb   $0x8e,0xf01cc36d
f0104072:	c1 e8 10             	shr    $0x10,%eax
f0104075:	66 a3 6e c3 1c f0    	mov    %ax,0xf01cc36e
	SETGATE(idt[IRQ_OFFSET + 2], 0, GD_KT, t_irq2, 0);
f010407b:	b8 46 49 10 f0       	mov    $0xf0104946,%eax
f0104080:	66 a3 70 c3 1c f0    	mov    %ax,0xf01cc370
f0104086:	66 c7 05 72 c3 1c f0 	movw   $0x8,0xf01cc372
f010408d:	08 00 
f010408f:	c6 05 74 c3 1c f0 00 	movb   $0x0,0xf01cc374
f0104096:	c6 05 75 c3 1c f0 8e 	movb   $0x8e,0xf01cc375
f010409d:	c1 e8 10             	shr    $0x10,%eax
f01040a0:	66 a3 76 c3 1c f0    	mov    %ax,0xf01cc376
	SETGATE(idt[IRQ_OFFSET + 3], 0, GD_KT, t_irq3, 0);
f01040a6:	b8 4c 49 10 f0       	mov    $0xf010494c,%eax
f01040ab:	66 a3 78 c3 1c f0    	mov    %ax,0xf01cc378
f01040b1:	66 c7 05 7a c3 1c f0 	movw   $0x8,0xf01cc37a
f01040b8:	08 00 
f01040ba:	c6 05 7c c3 1c f0 00 	movb   $0x0,0xf01cc37c
f01040c1:	c6 05 7d c3 1c f0 8e 	movb   $0x8e,0xf01cc37d
f01040c8:	c1 e8 10             	shr    $0x10,%eax
f01040cb:	66 a3 7e c3 1c f0    	mov    %ax,0xf01cc37e
	SETGATE(idt[IRQ_OFFSET + 4], 0, GD_KT, t_irq4, 0);
f01040d1:	b8 52 49 10 f0       	mov    $0xf0104952,%eax
f01040d6:	66 a3 80 c3 1c f0    	mov    %ax,0xf01cc380
f01040dc:	66 c7 05 82 c3 1c f0 	movw   $0x8,0xf01cc382
f01040e3:	08 00 
f01040e5:	c6 05 84 c3 1c f0 00 	movb   $0x0,0xf01cc384
f01040ec:	c6 05 85 c3 1c f0 8e 	movb   $0x8e,0xf01cc385
f01040f3:	c1 e8 10             	shr    $0x10,%eax
f01040f6:	66 a3 86 c3 1c f0    	mov    %ax,0xf01cc386
	SETGATE(idt[IRQ_OFFSET + 5], 0, GD_KT, t_irq5, 0);
f01040fc:	b8 58 49 10 f0       	mov    $0xf0104958,%eax
f0104101:	66 a3 88 c3 1c f0    	mov    %ax,0xf01cc388
f0104107:	66 c7 05 8a c3 1c f0 	movw   $0x8,0xf01cc38a
f010410e:	08 00 
f0104110:	c6 05 8c c3 1c f0 00 	movb   $0x0,0xf01cc38c
f0104117:	c6 05 8d c3 1c f0 8e 	movb   $0x8e,0xf01cc38d
f010411e:	c1 e8 10             	shr    $0x10,%eax
f0104121:	66 a3 8e c3 1c f0    	mov    %ax,0xf01cc38e
	SETGATE(idt[IRQ_OFFSET + 6], 0, GD_KT, t_irq6, 0);
f0104127:	b8 5e 49 10 f0       	mov    $0xf010495e,%eax
f010412c:	66 a3 90 c3 1c f0    	mov    %ax,0xf01cc390
f0104132:	66 c7 05 92 c3 1c f0 	movw   $0x8,0xf01cc392
f0104139:	08 00 
f010413b:	c6 05 94 c3 1c f0 00 	movb   $0x0,0xf01cc394
f0104142:	c6 05 95 c3 1c f0 8e 	movb   $0x8e,0xf01cc395
f0104149:	c1 e8 10             	shr    $0x10,%eax
f010414c:	66 a3 96 c3 1c f0    	mov    %ax,0xf01cc396
	SETGATE(idt[IRQ_OFFSET + 7], 0, GD_KT, t_irq7, 0);
f0104152:	b8 64 49 10 f0       	mov    $0xf0104964,%eax
f0104157:	66 a3 98 c3 1c f0    	mov    %ax,0xf01cc398
f010415d:	66 c7 05 9a c3 1c f0 	movw   $0x8,0xf01cc39a
f0104164:	08 00 
f0104166:	c6 05 9c c3 1c f0 00 	movb   $0x0,0xf01cc39c
f010416d:	c6 05 9d c3 1c f0 8e 	movb   $0x8e,0xf01cc39d
f0104174:	c1 e8 10             	shr    $0x10,%eax
f0104177:	66 a3 9e c3 1c f0    	mov    %ax,0xf01cc39e
	SETGATE(idt[IRQ_OFFSET + 8], 0, GD_KT, t_irq8, 0);
f010417d:	b8 6a 49 10 f0       	mov    $0xf010496a,%eax
f0104182:	66 a3 a0 c3 1c f0    	mov    %ax,0xf01cc3a0
f0104188:	66 c7 05 a2 c3 1c f0 	movw   $0x8,0xf01cc3a2
f010418f:	08 00 
f0104191:	c6 05 a4 c3 1c f0 00 	movb   $0x0,0xf01cc3a4
f0104198:	c6 05 a5 c3 1c f0 8e 	movb   $0x8e,0xf01cc3a5
f010419f:	c1 e8 10             	shr    $0x10,%eax
f01041a2:	66 a3 a6 c3 1c f0    	mov    %ax,0xf01cc3a6
	SETGATE(idt[IRQ_OFFSET + 9], 0, GD_KT, t_irq9, 0);
f01041a8:	b8 70 49 10 f0       	mov    $0xf0104970,%eax
f01041ad:	66 a3 a8 c3 1c f0    	mov    %ax,0xf01cc3a8
f01041b3:	66 c7 05 aa c3 1c f0 	movw   $0x8,0xf01cc3aa
f01041ba:	08 00 
f01041bc:	c6 05 ac c3 1c f0 00 	movb   $0x0,0xf01cc3ac
f01041c3:	c6 05 ad c3 1c f0 8e 	movb   $0x8e,0xf01cc3ad
f01041ca:	c1 e8 10             	shr    $0x10,%eax
f01041cd:	66 a3 ae c3 1c f0    	mov    %ax,0xf01cc3ae
	SETGATE(idt[IRQ_OFFSET + 10], 0, GD_KT, t_irq10, 0);
f01041d3:	b8 76 49 10 f0       	mov    $0xf0104976,%eax
f01041d8:	66 a3 b0 c3 1c f0    	mov    %ax,0xf01cc3b0
f01041de:	66 c7 05 b2 c3 1c f0 	movw   $0x8,0xf01cc3b2
f01041e5:	08 00 
f01041e7:	c6 05 b4 c3 1c f0 00 	movb   $0x0,0xf01cc3b4
f01041ee:	c6 05 b5 c3 1c f0 8e 	movb   $0x8e,0xf01cc3b5
f01041f5:	c1 e8 10             	shr    $0x10,%eax
f01041f8:	66 a3 b6 c3 1c f0    	mov    %ax,0xf01cc3b6
	SETGATE(idt[IRQ_OFFSET + 11], 0, GD_KT, t_irq11, 0);
f01041fe:	b8 7c 49 10 f0       	mov    $0xf010497c,%eax
f0104203:	66 a3 b8 c3 1c f0    	mov    %ax,0xf01cc3b8
f0104209:	66 c7 05 ba c3 1c f0 	movw   $0x8,0xf01cc3ba
f0104210:	08 00 
f0104212:	c6 05 bc c3 1c f0 00 	movb   $0x0,0xf01cc3bc
f0104219:	c6 05 bd c3 1c f0 8e 	movb   $0x8e,0xf01cc3bd
f0104220:	c1 e8 10             	shr    $0x10,%eax
f0104223:	66 a3 be c3 1c f0    	mov    %ax,0xf01cc3be
	SETGATE(idt[IRQ_OFFSET + 12], 0, GD_KT, t_irq12, 0);
f0104229:	b8 82 49 10 f0       	mov    $0xf0104982,%eax
f010422e:	66 a3 c0 c3 1c f0    	mov    %ax,0xf01cc3c0
f0104234:	66 c7 05 c2 c3 1c f0 	movw   $0x8,0xf01cc3c2
f010423b:	08 00 
f010423d:	c6 05 c4 c3 1c f0 00 	movb   $0x0,0xf01cc3c4
f0104244:	c6 05 c5 c3 1c f0 8e 	movb   $0x8e,0xf01cc3c5
f010424b:	c1 e8 10             	shr    $0x10,%eax
f010424e:	66 a3 c6 c3 1c f0    	mov    %ax,0xf01cc3c6
	SETGATE(idt[IRQ_OFFSET + 13], 0, GD_KT, t_irq13, 0);
f0104254:	b8 88 49 10 f0       	mov    $0xf0104988,%eax
f0104259:	66 a3 c8 c3 1c f0    	mov    %ax,0xf01cc3c8
f010425f:	66 c7 05 ca c3 1c f0 	movw   $0x8,0xf01cc3ca
f0104266:	08 00 
f0104268:	c6 05 cc c3 1c f0 00 	movb   $0x0,0xf01cc3cc
f010426f:	c6 05 cd c3 1c f0 8e 	movb   $0x8e,0xf01cc3cd
f0104276:	c1 e8 10             	shr    $0x10,%eax
f0104279:	66 a3 ce c3 1c f0    	mov    %ax,0xf01cc3ce
	SETGATE(idt[IRQ_OFFSET + 14], 0, GD_KT, t_irq14, 0);
f010427f:	b8 8e 49 10 f0       	mov    $0xf010498e,%eax
f0104284:	66 a3 d0 c3 1c f0    	mov    %ax,0xf01cc3d0
f010428a:	66 c7 05 d2 c3 1c f0 	movw   $0x8,0xf01cc3d2
f0104291:	08 00 
f0104293:	c6 05 d4 c3 1c f0 00 	movb   $0x0,0xf01cc3d4
f010429a:	c6 05 d5 c3 1c f0 8e 	movb   $0x8e,0xf01cc3d5
f01042a1:	c1 e8 10             	shr    $0x10,%eax
f01042a4:	66 a3 d6 c3 1c f0    	mov    %ax,0xf01cc3d6
	SETGATE(idt[IRQ_OFFSET + 15], 0, GD_KT, t_irq15, 0);
f01042aa:	b8 94 49 10 f0       	mov    $0xf0104994,%eax
f01042af:	66 a3 d8 c3 1c f0    	mov    %ax,0xf01cc3d8
f01042b5:	66 c7 05 da c3 1c f0 	movw   $0x8,0xf01cc3da
f01042bc:	08 00 
f01042be:	c6 05 dc c3 1c f0 00 	movb   $0x0,0xf01cc3dc
f01042c5:	c6 05 dd c3 1c f0 8e 	movb   $0x8e,0xf01cc3dd
f01042cc:	c1 e8 10             	shr    $0x10,%eax
f01042cf:	66 a3 de c3 1c f0    	mov    %ax,0xf01cc3de


	// Per-CPU setup 
	trap_init_percpu();
f01042d5:	e8 b6 f9 ff ff       	call   f0103c90 <trap_init_percpu>
}
f01042da:	c9                   	leave  
f01042db:	c3                   	ret    

f01042dc <print_regs>:
	}
}

void
print_regs(struct PushRegs *regs)
{
f01042dc:	55                   	push   %ebp
f01042dd:	89 e5                	mov    %esp,%ebp
f01042df:	53                   	push   %ebx
f01042e0:	83 ec 14             	sub    $0x14,%esp
f01042e3:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("  edi  0x%08x\n", regs->reg_edi);
f01042e6:	8b 03                	mov    (%ebx),%eax
f01042e8:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042ec:	c7 04 24 e1 7c 10 f0 	movl   $0xf0107ce1,(%esp)
f01042f3:	e8 77 f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  esi  0x%08x\n", regs->reg_esi);
f01042f8:	8b 43 04             	mov    0x4(%ebx),%eax
f01042fb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01042ff:	c7 04 24 f0 7c 10 f0 	movl   $0xf0107cf0,(%esp)
f0104306:	e8 64 f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  ebp  0x%08x\n", regs->reg_ebp);
f010430b:	8b 43 08             	mov    0x8(%ebx),%eax
f010430e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104312:	c7 04 24 ff 7c 10 f0 	movl   $0xf0107cff,(%esp)
f0104319:	e8 51 f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  oesp 0x%08x\n", regs->reg_oesp);
f010431e:	8b 43 0c             	mov    0xc(%ebx),%eax
f0104321:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104325:	c7 04 24 0e 7d 10 f0 	movl   $0xf0107d0e,(%esp)
f010432c:	e8 3e f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  ebx  0x%08x\n", regs->reg_ebx);
f0104331:	8b 43 10             	mov    0x10(%ebx),%eax
f0104334:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104338:	c7 04 24 1d 7d 10 f0 	movl   $0xf0107d1d,(%esp)
f010433f:	e8 2b f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  edx  0x%08x\n", regs->reg_edx);
f0104344:	8b 43 14             	mov    0x14(%ebx),%eax
f0104347:	89 44 24 04          	mov    %eax,0x4(%esp)
f010434b:	c7 04 24 2c 7d 10 f0 	movl   $0xf0107d2c,(%esp)
f0104352:	e8 18 f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  ecx  0x%08x\n", regs->reg_ecx);
f0104357:	8b 43 18             	mov    0x18(%ebx),%eax
f010435a:	89 44 24 04          	mov    %eax,0x4(%esp)
f010435e:	c7 04 24 3b 7d 10 f0 	movl   $0xf0107d3b,(%esp)
f0104365:	e8 05 f9 ff ff       	call   f0103c6f <cprintf>
	cprintf("  eax  0x%08x\n", regs->reg_eax);
f010436a:	8b 43 1c             	mov    0x1c(%ebx),%eax
f010436d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104371:	c7 04 24 4a 7d 10 f0 	movl   $0xf0107d4a,(%esp)
f0104378:	e8 f2 f8 ff ff       	call   f0103c6f <cprintf>
}
f010437d:	83 c4 14             	add    $0x14,%esp
f0104380:	5b                   	pop    %ebx
f0104381:	5d                   	pop    %ebp
f0104382:	c3                   	ret    

f0104383 <print_trapframe>:
	lidt(&idt_pd);
}

void
print_trapframe(struct Trapframe *tf)
{
f0104383:	55                   	push   %ebp
f0104384:	89 e5                	mov    %esp,%ebp
f0104386:	56                   	push   %esi
f0104387:	53                   	push   %ebx
f0104388:	83 ec 10             	sub    $0x10,%esp
f010438b:	8b 5d 08             	mov    0x8(%ebp),%ebx
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
f010438e:	e8 00 21 00 00       	call   f0106493 <cpunum>
f0104393:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104397:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010439b:	c7 04 24 ae 7d 10 f0 	movl   $0xf0107dae,(%esp)
f01043a2:	e8 c8 f8 ff ff       	call   f0103c6f <cprintf>
	print_regs(&tf->tf_regs);
f01043a7:	89 1c 24             	mov    %ebx,(%esp)
f01043aa:	e8 2d ff ff ff       	call   f01042dc <print_regs>
	cprintf("  es   0x----%04x\n", tf->tf_es);
f01043af:	0f b7 43 20          	movzwl 0x20(%ebx),%eax
f01043b3:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043b7:	c7 04 24 cc 7d 10 f0 	movl   $0xf0107dcc,(%esp)
f01043be:	e8 ac f8 ff ff       	call   f0103c6f <cprintf>
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
f01043c3:	0f b7 43 24          	movzwl 0x24(%ebx),%eax
f01043c7:	89 44 24 04          	mov    %eax,0x4(%esp)
f01043cb:	c7 04 24 df 7d 10 f0 	movl   $0xf0107ddf,(%esp)
f01043d2:	e8 98 f8 ff ff       	call   f0103c6f <cprintf>
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f01043d7:	8b 43 28             	mov    0x28(%ebx),%eax
		"Alignment Check",
		"Machine-Check",
		"SIMD Floating-Point Exception"
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
f01043da:	83 f8 13             	cmp    $0x13,%eax
f01043dd:	77 09                	ja     f01043e8 <print_trapframe+0x65>
		return excnames[trapno];
f01043df:	8b 14 85 80 80 10 f0 	mov    -0xfef7f80(,%eax,4),%edx
f01043e6:	eb 1f                	jmp    f0104407 <print_trapframe+0x84>
	if (trapno == T_SYSCALL)
f01043e8:	83 f8 30             	cmp    $0x30,%eax
f01043eb:	74 15                	je     f0104402 <print_trapframe+0x7f>
		return "System call";
	if (trapno >= IRQ_OFFSET && trapno < IRQ_OFFSET + 16)
f01043ed:	8d 50 e0             	lea    -0x20(%eax),%edx
		return "Hardware Interrupt";
f01043f0:	83 fa 0f             	cmp    $0xf,%edx
f01043f3:	ba 65 7d 10 f0       	mov    $0xf0107d65,%edx
f01043f8:	b9 78 7d 10 f0       	mov    $0xf0107d78,%ecx
f01043fd:	0f 47 d1             	cmova  %ecx,%edx
f0104400:	eb 05                	jmp    f0104407 <print_trapframe+0x84>
	};

	if (trapno < sizeof(excnames)/sizeof(excnames[0]))
		return excnames[trapno];
	if (trapno == T_SYSCALL)
		return "System call";
f0104402:	ba 59 7d 10 f0       	mov    $0xf0107d59,%edx
{
	cprintf("TRAP frame at %p from CPU %d\n", tf, cpunum());
	print_regs(&tf->tf_regs);
	cprintf("  es   0x----%04x\n", tf->tf_es);
	cprintf("  ds   0x----%04x\n", tf->tf_ds);
	cprintf("  trap 0x%08x %s\n", tf->tf_trapno, trapname(tf->tf_trapno));
f0104407:	89 54 24 08          	mov    %edx,0x8(%esp)
f010440b:	89 44 24 04          	mov    %eax,0x4(%esp)
f010440f:	c7 04 24 f2 7d 10 f0 	movl   $0xf0107df2,(%esp)
f0104416:	e8 54 f8 ff ff       	call   f0103c6f <cprintf>
	// If this trap was a page fault that just happened
	// (so %cr2 is meaningful), print the faulting linear address.
	if (tf == last_tf && tf->tf_trapno == T_PGFLT)
f010441b:	3b 1d 60 ca 1c f0    	cmp    0xf01cca60,%ebx
f0104421:	75 19                	jne    f010443c <print_trapframe+0xb9>
f0104423:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104427:	75 13                	jne    f010443c <print_trapframe+0xb9>

static __inline uint32_t
rcr2(void)
{
	uint32_t val;
	__asm __volatile("movl %%cr2,%0" : "=r" (val));
f0104429:	0f 20 d0             	mov    %cr2,%eax
		cprintf("  cr2  0x%08x\n", rcr2());
f010442c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104430:	c7 04 24 04 7e 10 f0 	movl   $0xf0107e04,(%esp)
f0104437:	e8 33 f8 ff ff       	call   f0103c6f <cprintf>
	cprintf("  err  0x%08x", tf->tf_err);
f010443c:	8b 43 2c             	mov    0x2c(%ebx),%eax
f010443f:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104443:	c7 04 24 13 7e 10 f0 	movl   $0xf0107e13,(%esp)
f010444a:	e8 20 f8 ff ff       	call   f0103c6f <cprintf>
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
f010444f:	83 7b 28 0e          	cmpl   $0xe,0x28(%ebx)
f0104453:	75 51                	jne    f01044a6 <print_trapframe+0x123>
		cprintf(" [%s, %s, %s]\n",
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
f0104455:	8b 43 2c             	mov    0x2c(%ebx),%eax
	// For page faults, print decoded fault error code:
	// U/K=fault occurred in user/kernel mode
	// W/R=a write/read caused the fault
	// PR=a protection violation caused the fault (NP=page not present).
	if (tf->tf_trapno == T_PGFLT)
		cprintf(" [%s, %s, %s]\n",
f0104458:	89 c2                	mov    %eax,%edx
f010445a:	83 e2 01             	and    $0x1,%edx
f010445d:	ba 87 7d 10 f0       	mov    $0xf0107d87,%edx
f0104462:	b9 92 7d 10 f0       	mov    $0xf0107d92,%ecx
f0104467:	0f 45 ca             	cmovne %edx,%ecx
f010446a:	89 c2                	mov    %eax,%edx
f010446c:	83 e2 02             	and    $0x2,%edx
f010446f:	ba 9e 7d 10 f0       	mov    $0xf0107d9e,%edx
f0104474:	be a4 7d 10 f0       	mov    $0xf0107da4,%esi
f0104479:	0f 44 d6             	cmove  %esi,%edx
f010447c:	83 e0 04             	and    $0x4,%eax
f010447f:	b8 a9 7d 10 f0       	mov    $0xf0107da9,%eax
f0104484:	be c5 7e 10 f0       	mov    $0xf0107ec5,%esi
f0104489:	0f 44 c6             	cmove  %esi,%eax
f010448c:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f0104490:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104494:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104498:	c7 04 24 21 7e 10 f0 	movl   $0xf0107e21,(%esp)
f010449f:	e8 cb f7 ff ff       	call   f0103c6f <cprintf>
f01044a4:	eb 0c                	jmp    f01044b2 <print_trapframe+0x12f>
			tf->tf_err & 4 ? "user" : "kernel",
			tf->tf_err & 2 ? "write" : "read",
			tf->tf_err & 1 ? "protection" : "not-present");
	else
		cprintf("\n");
f01044a6:	c7 04 24 bf 7c 10 f0 	movl   $0xf0107cbf,(%esp)
f01044ad:	e8 bd f7 ff ff       	call   f0103c6f <cprintf>
	cprintf("  eip  0x%08x\n", tf->tf_eip);
f01044b2:	8b 43 30             	mov    0x30(%ebx),%eax
f01044b5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044b9:	c7 04 24 30 7e 10 f0 	movl   $0xf0107e30,(%esp)
f01044c0:	e8 aa f7 ff ff       	call   f0103c6f <cprintf>
	cprintf("  cs   0x----%04x\n", tf->tf_cs);
f01044c5:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f01044c9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044cd:	c7 04 24 3f 7e 10 f0 	movl   $0xf0107e3f,(%esp)
f01044d4:	e8 96 f7 ff ff       	call   f0103c6f <cprintf>
	cprintf("  flag 0x%08x\n", tf->tf_eflags);
f01044d9:	8b 43 38             	mov    0x38(%ebx),%eax
f01044dc:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044e0:	c7 04 24 52 7e 10 f0 	movl   $0xf0107e52,(%esp)
f01044e7:	e8 83 f7 ff ff       	call   f0103c6f <cprintf>
	if ((tf->tf_cs & 3) != 0) {
f01044ec:	f6 43 34 03          	testb  $0x3,0x34(%ebx)
f01044f0:	74 27                	je     f0104519 <print_trapframe+0x196>
		cprintf("  esp  0x%08x\n", tf->tf_esp);
f01044f2:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01044f5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01044f9:	c7 04 24 61 7e 10 f0 	movl   $0xf0107e61,(%esp)
f0104500:	e8 6a f7 ff ff       	call   f0103c6f <cprintf>
		cprintf("  ss   0x----%04x\n", tf->tf_ss);
f0104505:	0f b7 43 40          	movzwl 0x40(%ebx),%eax
f0104509:	89 44 24 04          	mov    %eax,0x4(%esp)
f010450d:	c7 04 24 70 7e 10 f0 	movl   $0xf0107e70,(%esp)
f0104514:	e8 56 f7 ff ff       	call   f0103c6f <cprintf>
	}
}
f0104519:	83 c4 10             	add    $0x10,%esp
f010451c:	5b                   	pop    %ebx
f010451d:	5e                   	pop    %esi
f010451e:	5d                   	pop    %ebp
f010451f:	c3                   	ret    

f0104520 <page_fault_handler>:
}


void
page_fault_handler(struct Trapframe *tf)
{
f0104520:	55                   	push   %ebp
f0104521:	89 e5                	mov    %esp,%ebp
f0104523:	57                   	push   %edi
f0104524:	56                   	push   %esi
f0104525:	53                   	push   %ebx
f0104526:	83 ec 2c             	sub    $0x2c,%esp
f0104529:	8b 5d 08             	mov    0x8(%ebp),%ebx
f010452c:	0f 20 d0             	mov    %cr2,%eax
f010452f:	89 45 e4             	mov    %eax,-0x1c(%ebp)
	// Handle kernel-mode page faults.

	// LAB 3: Your code here.
	// Check whether pgflt happened at kernel mode
	// RPL != 0x3
	if((tf->tf_cs & 0x3) != 3)
f0104532:	0f b7 43 34          	movzwl 0x34(%ebx),%eax
f0104536:	83 e0 03             	and    $0x3,%eax
f0104539:	66 83 f8 03          	cmp    $0x3,%ax
f010453d:	74 1c                	je     f010455b <page_fault_handler+0x3b>
		panic("page_fault_handler(): page fault at kernel-mode !");
f010453f:	c7 44 24 08 10 80 10 	movl   $0xf0108010,0x8(%esp)
f0104546:	f0 
f0104547:	c7 44 24 04 86 01 00 	movl   $0x186,0x4(%esp)
f010454e:	00 
f010454f:	c7 04 24 83 7e 10 f0 	movl   $0xf0107e83,(%esp)
f0104556:	e8 e5 ba ff ff       	call   f0100040 <_panic>
	//   user_mem_assert() and env_run() are useful here.
	//   To change what the user environment runs, modify 'curenv->env_tf'
	//   (the 'tf' variable points at 'curenv->env_tf').

	// LAB 4: Your code here.
	if(curenv->env_pgfault_upcall == NULL) goto DESTROY;
f010455b:	e8 33 1f 00 00       	call   f0106493 <cpunum>
f0104560:	6b c0 74             	imul   $0x74,%eax,%eax
f0104563:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104569:	83 78 64 00          	cmpl   $0x0,0x64(%eax)
f010456d:	0f 84 fa 00 00 00    	je     f010466d <page_fault_handler+0x14d>

	// 1. call the environment's page fault upcall, if one exits
	// 1.1 Set up a page fault stack frame

	struct UTrapframe* utf;
	if(UXSTACKTOP - PGSIZE <= tf->tf_esp && tf->tf_esp < UXSTACKTOP) // an page_fault from user exception stack
f0104573:	8b 43 3c             	mov    0x3c(%ebx),%eax
f0104576:	8d 90 00 10 40 11    	lea    0x11401000(%eax),%edx
	{
		utf = (struct UTrapframe*) (tf->tf_esp - sizeof (struct UTrapframe) - sizeof(uint32_t));
f010457c:	83 e8 38             	sub    $0x38,%eax
f010457f:	81 fa ff 0f 00 00    	cmp    $0xfff,%edx
f0104585:	ba cc ff bf ee       	mov    $0xeebfffcc,%edx
f010458a:	0f 46 d0             	cmovbe %eax,%edx
f010458d:	89 d7                	mov    %edx,%edi
f010458f:	89 55 e0             	mov    %edx,-0x20(%ebp)

	}

	// assume user has right to access uxstk
	//cprintf("Before\n");
	user_mem_assert(curenv, (void*) utf, sizeof (struct UTrapframe), PTE_U | PTE_W);
f0104592:	e8 fc 1e 00 00       	call   f0106493 <cpunum>
f0104597:	c7 44 24 0c 06 00 00 	movl   $0x6,0xc(%esp)
f010459e:	00 
f010459f:	c7 44 24 08 34 00 00 	movl   $0x34,0x8(%esp)
f01045a6:	00 
f01045a7:	89 7c 24 04          	mov    %edi,0x4(%esp)
f01045ab:	6b c0 74             	imul   $0x74,%eax,%eax
f01045ae:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f01045b4:	89 04 24             	mov    %eax,(%esp)
f01045b7:	e8 2c ed ff ff       	call   f01032e8 <user_mem_assert>
	//cprintf("Passed\n");



	// setup a stack
	utf->utf_eflags = tf->tf_eflags;
f01045bc:	8b 43 38             	mov    0x38(%ebx),%eax
f01045bf:	89 47 2c             	mov    %eax,0x2c(%edi)
	utf->utf_eip = tf->tf_eip;
f01045c2:	8b 43 30             	mov    0x30(%ebx),%eax
f01045c5:	89 47 28             	mov    %eax,0x28(%edi)
	utf->utf_esp = tf->tf_esp;
f01045c8:	8b 43 3c             	mov    0x3c(%ebx),%eax
f01045cb:	89 47 30             	mov    %eax,0x30(%edi)
	utf->utf_regs = tf->tf_regs;
f01045ce:	8d 7f 08             	lea    0x8(%edi),%edi
f01045d1:	89 de                	mov    %ebx,%esi
f01045d3:	b8 20 00 00 00       	mov    $0x20,%eax
f01045d8:	f7 c7 01 00 00 00    	test   $0x1,%edi
f01045de:	74 03                	je     f01045e3 <page_fault_handler+0xc3>
f01045e0:	a4                   	movsb  %ds:(%esi),%es:(%edi)
f01045e1:	b0 1f                	mov    $0x1f,%al
f01045e3:	f7 c7 02 00 00 00    	test   $0x2,%edi
f01045e9:	74 05                	je     f01045f0 <page_fault_handler+0xd0>
f01045eb:	66 a5                	movsw  %ds:(%esi),%es:(%edi)
f01045ed:	83 e8 02             	sub    $0x2,%eax
f01045f0:	89 c1                	mov    %eax,%ecx
f01045f2:	c1 e9 02             	shr    $0x2,%ecx
f01045f5:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f01045f7:	ba 00 00 00 00       	mov    $0x0,%edx
f01045fc:	a8 02                	test   $0x2,%al
f01045fe:	74 0b                	je     f010460b <page_fault_handler+0xeb>
f0104600:	0f b7 16             	movzwl (%esi),%edx
f0104603:	66 89 17             	mov    %dx,(%edi)
f0104606:	ba 02 00 00 00       	mov    $0x2,%edx
f010460b:	a8 01                	test   $0x1,%al
f010460d:	74 07                	je     f0104616 <page_fault_handler+0xf6>
f010460f:	0f b6 04 16          	movzbl (%esi,%edx,1),%eax
f0104613:	88 04 17             	mov    %al,(%edi,%edx,1)
	utf->utf_err = tf->tf_err;
f0104616:	8b 43 2c             	mov    0x2c(%ebx),%eax
f0104619:	8b 7d e0             	mov    -0x20(%ebp),%edi
f010461c:	89 47 04             	mov    %eax,0x4(%edi)
	utf->utf_fault_va = fault_va;
f010461f:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104622:	89 07                	mov    %eax,(%edi)

	curenv->env_tf.tf_eip = (uint32_t)curenv->env_pgfault_upcall;
f0104624:	e8 6a 1e 00 00       	call   f0106493 <cpunum>
f0104629:	6b c0 74             	imul   $0x74,%eax,%eax
f010462c:	8b 98 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%ebx
f0104632:	e8 5c 1e 00 00       	call   f0106493 <cpunum>
f0104637:	6b c0 74             	imul   $0x74,%eax,%eax
f010463a:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104640:	8b 40 64             	mov    0x64(%eax),%eax
f0104643:	89 43 30             	mov    %eax,0x30(%ebx)
	curenv->env_tf.tf_esp = (uint32_t)utf;
f0104646:	e8 48 1e 00 00       	call   f0106493 <cpunum>
f010464b:	6b c0 74             	imul   $0x74,%eax,%eax
f010464e:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104654:	89 78 3c             	mov    %edi,0x3c(%eax)

	env_run(curenv);
f0104657:	e8 37 1e 00 00       	call   f0106493 <cpunum>
f010465c:	6b c0 74             	imul   $0x74,%eax,%eax
f010465f:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104665:	89 04 24             	mov    %eax,(%esp)
f0104668:	e8 f1 f3 ff ff       	call   f0103a5e <env_run>


	DESTROY:
	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f010466d:	8b 73 30             	mov    0x30(%ebx),%esi
		curenv->env_id, fault_va, tf->tf_eip);
f0104670:	e8 1e 1e 00 00       	call   f0106493 <cpunum>
	env_run(curenv);


	DESTROY:
	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104675:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104679:	8b 4d e4             	mov    -0x1c(%ebp),%ecx
f010467c:	89 4c 24 08          	mov    %ecx,0x8(%esp)
		curenv->env_id, fault_va, tf->tf_eip);
f0104680:	6b c0 74             	imul   $0x74,%eax,%eax
	env_run(curenv);


	DESTROY:
	// Destroy the environment that caused the fault.
	cprintf("[%08x] user fault va %08x ip %08x\n",
f0104683:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104689:	8b 40 48             	mov    0x48(%eax),%eax
f010468c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104690:	c7 04 24 44 80 10 f0 	movl   $0xf0108044,(%esp)
f0104697:	e8 d3 f5 ff ff       	call   f0103c6f <cprintf>
		curenv->env_id, fault_va, tf->tf_eip);
	print_trapframe(tf);
f010469c:	89 1c 24             	mov    %ebx,(%esp)
f010469f:	e8 df fc ff ff       	call   f0104383 <print_trapframe>
	env_destroy(curenv);
f01046a4:	e8 ea 1d 00 00       	call   f0106493 <cpunum>
f01046a9:	6b c0 74             	imul   $0x74,%eax,%eax
f01046ac:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f01046b2:	89 04 24             	mov    %eax,(%esp)
f01046b5:	e8 03 f3 ff ff       	call   f01039bd <env_destroy>
}
f01046ba:	83 c4 2c             	add    $0x2c,%esp
f01046bd:	5b                   	pop    %ebx
f01046be:	5e                   	pop    %esi
f01046bf:	5f                   	pop    %edi
f01046c0:	5d                   	pop    %ebp
f01046c1:	c3                   	ret    

f01046c2 <trap>:
	}
}

void
trap(struct Trapframe *tf)
{
f01046c2:	55                   	push   %ebp
f01046c3:	89 e5                	mov    %esp,%ebp
f01046c5:	57                   	push   %edi
f01046c6:	56                   	push   %esi
f01046c7:	83 ec 20             	sub    $0x20,%esp
f01046ca:	8b 75 08             	mov    0x8(%ebp),%esi
	// The environment may have set DF and some versions
	// of GCC rely on DF being clear
	asm volatile("cld" ::: "cc");
f01046cd:	fc                   	cld    

	// Halt the CPU if some other CPU has called panic()
	extern char *panicstr;
	if (panicstr)
f01046ce:	83 3d 80 ce 1c f0 00 	cmpl   $0x0,0xf01cce80
f01046d5:	74 01                	je     f01046d8 <trap+0x16>
		asm volatile("hlt");
f01046d7:	f4                   	hlt    
	// fails, DO NOT be tempted to fix it by inserting a "cli" in
	// the interrupt path.
	//cprintf("%08x %08x\n",read_eflags() , FL_IF);
	//assert(!(read_eflags() & FL_IF));

	if ((tf->tf_cs & 3) == 3) {
f01046d8:	0f b7 46 34          	movzwl 0x34(%esi),%eax
f01046dc:	83 e0 03             	and    $0x3,%eax
f01046df:	66 83 f8 03          	cmp    $0x3,%ax
f01046e3:	0f 85 a7 00 00 00    	jne    f0104790 <trap+0xce>
extern struct spinlock kernel_lock;

static inline void
lock_kernel(void)
{
	spin_lock(&kernel_lock);
f01046e9:	c7 04 24 a0 13 12 f0 	movl   $0xf01213a0,(%esp)
f01046f0:	e8 04 20 00 00       	call   f01066f9 <spin_lock>
		// Trapped from user mode.
		// Acquire the big kernel lock before doing any
		// serious kernel work.
		// LAB 4: Your code here.
		lock_kernel();
		assert(curenv);
f01046f5:	e8 99 1d 00 00       	call   f0106493 <cpunum>
f01046fa:	6b c0 74             	imul   $0x74,%eax,%eax
f01046fd:	83 b8 28 d0 1c f0 00 	cmpl   $0x0,-0xfe32fd8(%eax)
f0104704:	75 24                	jne    f010472a <trap+0x68>
f0104706:	c7 44 24 0c 8f 7e 10 	movl   $0xf0107e8f,0xc(%esp)
f010470d:	f0 
f010470e:	c7 44 24 08 5c 71 10 	movl   $0xf010715c,0x8(%esp)
f0104715:	f0 
f0104716:	c7 44 24 04 56 01 00 	movl   $0x156,0x4(%esp)
f010471d:	00 
f010471e:	c7 04 24 83 7e 10 f0 	movl   $0xf0107e83,(%esp)
f0104725:	e8 16 b9 ff ff       	call   f0100040 <_panic>

		// Garbage collect if current enviroment is a zombie
		if (curenv->env_status == ENV_DYING) {
f010472a:	e8 64 1d 00 00       	call   f0106493 <cpunum>
f010472f:	6b c0 74             	imul   $0x74,%eax,%eax
f0104732:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104738:	83 78 54 01          	cmpl   $0x1,0x54(%eax)
f010473c:	75 2d                	jne    f010476b <trap+0xa9>
			env_free(curenv);
f010473e:	e8 50 1d 00 00       	call   f0106493 <cpunum>
f0104743:	6b c0 74             	imul   $0x74,%eax,%eax
f0104746:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f010474c:	89 04 24             	mov    %eax,(%esp)
f010474f:	e8 9e f0 ff ff       	call   f01037f2 <env_free>
			curenv = NULL;
f0104754:	e8 3a 1d 00 00       	call   f0106493 <cpunum>
f0104759:	6b c0 74             	imul   $0x74,%eax,%eax
f010475c:	c7 80 28 d0 1c f0 00 	movl   $0x0,-0xfe32fd8(%eax)
f0104763:	00 00 00 
			sched_yield();
f0104766:	e8 45 02 00 00       	call   f01049b0 <sched_yield>
		}

		// Copy trap frame (which is currently on the stack)
		// into 'curenv->env_tf', so that running the environment
		// will restart at the trap point.
		curenv->env_tf = *tf;
f010476b:	e8 23 1d 00 00       	call   f0106493 <cpunum>
f0104770:	6b c0 74             	imul   $0x74,%eax,%eax
f0104773:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104779:	b9 11 00 00 00       	mov    $0x11,%ecx
f010477e:	89 c7                	mov    %eax,%edi
f0104780:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
		// The trapframe on the stack should be ignored from here on.
		tf = &curenv->env_tf;
f0104782:	e8 0c 1d 00 00       	call   f0106493 <cpunum>
f0104787:	6b c0 74             	imul   $0x74,%eax,%eax
f010478a:	8b b0 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%esi
	}

	// Record that tf is the last real trapframe so
	// print_trapframe can print some additional information.
	last_tf = tf;
f0104790:	89 35 60 ca 1c f0    	mov    %esi,0xf01cca60
{
	//cprintf("trap_dispatch(): dispatching traps\n");

	// Handle processor exceptions.
	// LAB 3: Your code here.
	switch(tf->tf_trapno)
f0104796:	8b 46 28             	mov    0x28(%esi),%eax
f0104799:	83 f8 0e             	cmp    $0xe,%eax
f010479c:	74 0c                	je     f01047aa <trap+0xe8>
f010479e:	83 f8 30             	cmp    $0x30,%eax
f01047a1:	74 24                	je     f01047c7 <trap+0x105>
f01047a3:	83 f8 03             	cmp    $0x3,%eax
f01047a6:	75 51                	jne    f01047f9 <trap+0x137>
f01047a8:	eb 10                	jmp    f01047ba <trap+0xf8>
	{
	case T_PGFLT:
		page_fault_handler(tf);
f01047aa:	89 34 24             	mov    %esi,(%esp)
f01047ad:	8d 76 00             	lea    0x0(%esi),%esi
f01047b0:	e8 6b fd ff ff       	call   f0104520 <page_fault_handler>
f01047b5:	e9 b1 00 00 00       	jmp    f010486b <trap+0x1a9>
		return;
	case T_BRKPT:
		monitor(tf);
f01047ba:	89 34 24             	mov    %esi,(%esp)
f01047bd:	e8 f5 c1 ff ff       	call   f01009b7 <monitor>
f01047c2:	e9 a4 00 00 00       	jmp    f010486b <trap+0x1a9>
		return;
	case T_SYSCALL:
		tf->tf_regs.reg_eax =
			 syscall(tf->tf_regs.reg_eax, tf->tf_regs.reg_edx,
f01047c7:	8b 46 04             	mov    0x4(%esi),%eax
f01047ca:	89 44 24 14          	mov    %eax,0x14(%esp)
f01047ce:	8b 06                	mov    (%esi),%eax
f01047d0:	89 44 24 10          	mov    %eax,0x10(%esp)
f01047d4:	8b 46 10             	mov    0x10(%esi),%eax
f01047d7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01047db:	8b 46 18             	mov    0x18(%esi),%eax
f01047de:	89 44 24 08          	mov    %eax,0x8(%esp)
f01047e2:	8b 46 14             	mov    0x14(%esi),%eax
f01047e5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01047e9:	8b 46 1c             	mov    0x1c(%esi),%eax
f01047ec:	89 04 24             	mov    %eax,(%esp)
f01047ef:	e8 dc 02 00 00       	call   f0104ad0 <syscall>
		return;
	case T_BRKPT:
		monitor(tf);
		return;
	case T_SYSCALL:
		tf->tf_regs.reg_eax =
f01047f4:	89 46 1c             	mov    %eax,0x1c(%esi)
f01047f7:	eb 72                	jmp    f010486b <trap+0x1a9>
	}

	// Handle spurious interrupts
	// The hardware sometimes raises these because of noise on the
	// IRQ line or other reasons. We don't care.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_SPURIOUS) {
f01047f9:	83 f8 27             	cmp    $0x27,%eax
f01047fc:	75 16                	jne    f0104814 <trap+0x152>
		cprintf("Spurious interrupt on irq 7\n");
f01047fe:	c7 04 24 96 7e 10 f0 	movl   $0xf0107e96,(%esp)
f0104805:	e8 65 f4 ff ff       	call   f0103c6f <cprintf>
		print_trapframe(tf);
f010480a:	89 34 24             	mov    %esi,(%esp)
f010480d:	e8 71 fb ff ff       	call   f0104383 <print_trapframe>
f0104812:	eb 57                	jmp    f010486b <trap+0x1a9>
	}

	// Handle clock interrupts. Don't forget to acknowledge the
	// interrupt using lapic_eoi() before calling the scheduler!
	// LAB 4: Your code here.
	if (tf->tf_trapno == IRQ_OFFSET + IRQ_TIMER)
f0104814:	83 f8 20             	cmp    $0x20,%eax
f0104817:	75 11                	jne    f010482a <trap+0x168>
	{
		lapic_eoi();
f0104819:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0104820:	e8 a3 1d 00 00       	call   f01065c8 <lapic_eoi>
		sched_yield();
f0104825:	e8 86 01 00 00       	call   f01049b0 <sched_yield>
	}//不用return因爲不會返回

	// Unexpected trap: The user process or the kernel has a bug.
	print_trapframe(tf);
f010482a:	89 34 24             	mov    %esi,(%esp)
f010482d:	e8 51 fb ff ff       	call   f0104383 <print_trapframe>
	if (tf->tf_cs == GD_KT)
f0104832:	66 83 7e 34 08       	cmpw   $0x8,0x34(%esi)
f0104837:	75 1c                	jne    f0104855 <trap+0x193>
		panic("unhandled trap in kernel");
f0104839:	c7 44 24 08 b3 7e 10 	movl   $0xf0107eb3,0x8(%esp)
f0104840:	f0 
f0104841:	c7 44 24 04 37 01 00 	movl   $0x137,0x4(%esp)
f0104848:	00 
f0104849:	c7 04 24 83 7e 10 f0 	movl   $0xf0107e83,(%esp)
f0104850:	e8 eb b7 ff ff       	call   f0100040 <_panic>
	else {
		env_destroy(curenv);
f0104855:	e8 39 1c 00 00       	call   f0106493 <cpunum>
f010485a:	6b c0 74             	imul   $0x74,%eax,%eax
f010485d:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104863:	89 04 24             	mov    %eax,(%esp)
f0104866:	e8 52 f1 ff ff       	call   f01039bd <env_destroy>
	trap_dispatch(tf);

	// If we made it to this point, then no other environment was
	// scheduled, so we should return to the current environment
	// if doing so makes sense.
	if (curenv && curenv->env_status == ENV_RUNNING)
f010486b:	e8 23 1c 00 00       	call   f0106493 <cpunum>
f0104870:	6b c0 74             	imul   $0x74,%eax,%eax
f0104873:	83 b8 28 d0 1c f0 00 	cmpl   $0x0,-0xfe32fd8(%eax)
f010487a:	74 2a                	je     f01048a6 <trap+0x1e4>
f010487c:	e8 12 1c 00 00       	call   f0106493 <cpunum>
f0104881:	6b c0 74             	imul   $0x74,%eax,%eax
f0104884:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f010488a:	83 78 54 03          	cmpl   $0x3,0x54(%eax)
f010488e:	75 16                	jne    f01048a6 <trap+0x1e4>
		env_run(curenv);
f0104890:	e8 fe 1b 00 00       	call   f0106493 <cpunum>
f0104895:	6b c0 74             	imul   $0x74,%eax,%eax
f0104898:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f010489e:	89 04 24             	mov    %eax,(%esp)
f01048a1:	e8 b8 f1 ff ff       	call   f0103a5e <env_run>
	else
		sched_yield();
f01048a6:	e8 05 01 00 00       	call   f01049b0 <sched_yield>
f01048ab:	90                   	nop

f01048ac <dividezero_handler>:
.text

/*
 * Lab 3: Your code here for generating entry points for the different traps.
 */
TRAPHANDLER_NOEC(dividezero_handler, 0x0)
f01048ac:	6a 00                	push   $0x0
f01048ae:	6a 00                	push   $0x0
f01048b0:	e9 e5 00 00 00       	jmp    f010499a <_alltraps>
f01048b5:	90                   	nop

f01048b6 <nmi_handler>:
TRAPHANDLER_NOEC(nmi_handler, 0x2)
f01048b6:	6a 00                	push   $0x0
f01048b8:	6a 02                	push   $0x2
f01048ba:	e9 db 00 00 00       	jmp    f010499a <_alltraps>
f01048bf:	90                   	nop

f01048c0 <breakpoint_handler>:
TRAPHANDLER_NOEC(breakpoint_handler, 0x3)
f01048c0:	6a 00                	push   $0x0
f01048c2:	6a 03                	push   $0x3
f01048c4:	e9 d1 00 00 00       	jmp    f010499a <_alltraps>
f01048c9:	90                   	nop

f01048ca <overflow_handler>:
TRAPHANDLER_NOEC(overflow_handler, 0x4)
f01048ca:	6a 00                	push   $0x0
f01048cc:	6a 04                	push   $0x4
f01048ce:	e9 c7 00 00 00       	jmp    f010499a <_alltraps>
f01048d3:	90                   	nop

f01048d4 <bdrgeexceed_handler>:
TRAPHANDLER_NOEC(bdrgeexceed_handler, 0x5)
f01048d4:	6a 00                	push   $0x0
f01048d6:	6a 05                	push   $0x5
f01048d8:	e9 bd 00 00 00       	jmp    f010499a <_alltraps>
f01048dd:	90                   	nop

f01048de <invalidop_handler>:
TRAPHANDLER_NOEC(invalidop_handler, 0x6)
f01048de:	6a 00                	push   $0x0
f01048e0:	6a 06                	push   $0x6
f01048e2:	e9 b3 00 00 00       	jmp    f010499a <_alltraps>
f01048e7:	90                   	nop

f01048e8 <nomathcopro_handler>:
TRAPHANDLER_NOEC(nomathcopro_handler, 0x7)
f01048e8:	6a 00                	push   $0x0
f01048ea:	6a 07                	push   $0x7
f01048ec:	e9 a9 00 00 00       	jmp    f010499a <_alltraps>
f01048f1:	90                   	nop

f01048f2 <dbfault_handler>:
TRAPHANDLER(dbfault_handler, 0x8)
f01048f2:	6a 08                	push   $0x8
f01048f4:	e9 a1 00 00 00       	jmp    f010499a <_alltraps>
f01048f9:	90                   	nop

f01048fa <invalidTSS_handler>:
TRAPHANDLER(invalidTSS_handler, 0xA)
f01048fa:	6a 0a                	push   $0xa
f01048fc:	e9 99 00 00 00       	jmp    f010499a <_alltraps>
f0104901:	90                   	nop

f0104902 <sgmtnotpresent_handler>:
TRAPHANDLER(sgmtnotpresent_handler, 0xB)
f0104902:	6a 0b                	push   $0xb
f0104904:	e9 91 00 00 00       	jmp    f010499a <_alltraps>
f0104909:	90                   	nop

f010490a <stacksgmtfault_handler>:
TRAPHANDLER(stacksgmtfault_handler,0xC)
f010490a:	6a 0c                	push   $0xc
f010490c:	e9 89 00 00 00       	jmp    f010499a <_alltraps>
f0104911:	90                   	nop

f0104912 <generalprotection_handler>:
TRAPHANDLER(generalprotection_handler, 0xD)
f0104912:	6a 0d                	push   $0xd
f0104914:	e9 81 00 00 00       	jmp    f010499a <_alltraps>
f0104919:	90                   	nop

f010491a <pagefault_handler>:
TRAPHANDLER(pagefault_handler, 0xE)
f010491a:	6a 0e                	push   $0xe
f010491c:	eb 7c                	jmp    f010499a <_alltraps>

f010491e <FPUerror_handler>:
TRAPHANDLER_NOEC(FPUerror_handler, 0x10)
f010491e:	6a 00                	push   $0x0
f0104920:	6a 10                	push   $0x10
f0104922:	eb 76                	jmp    f010499a <_alltraps>

f0104924 <alignmentcheck_handler>:
TRAPHANDLER(alignmentcheck_handler, 0x11)
f0104924:	6a 11                	push   $0x11
f0104926:	eb 72                	jmp    f010499a <_alltraps>

f0104928 <machinecheck_handler>:
TRAPHANDLER_NOEC(machinecheck_handler, 0x12)
f0104928:	6a 00                	push   $0x0
f010492a:	6a 12                	push   $0x12
f010492c:	eb 6c                	jmp    f010499a <_alltraps>

f010492e <SIMDFPexception_handler>:
TRAPHANDLER_NOEC(SIMDFPexception_handler, 0x13)
f010492e:	6a 00                	push   $0x0
f0104930:	6a 13                	push   $0x13
f0104932:	eb 66                	jmp    f010499a <_alltraps>

f0104934 <systemcall_handler>:
TRAPHANDLER_NOEC(systemcall_handler, 0x30)
f0104934:	6a 00                	push   $0x0
f0104936:	6a 30                	push   $0x30
f0104938:	eb 60                	jmp    f010499a <_alltraps>

f010493a <t_irq0>:

TRAPHANDLER_NOEC(t_irq0, IRQ_OFFSET + 0);
f010493a:	6a 00                	push   $0x0
f010493c:	6a 20                	push   $0x20
f010493e:	eb 5a                	jmp    f010499a <_alltraps>

f0104940 <t_irq1>:
TRAPHANDLER_NOEC(t_irq1, IRQ_OFFSET + 1);
f0104940:	6a 00                	push   $0x0
f0104942:	6a 21                	push   $0x21
f0104944:	eb 54                	jmp    f010499a <_alltraps>

f0104946 <t_irq2>:
TRAPHANDLER_NOEC(t_irq2, IRQ_OFFSET + 2);
f0104946:	6a 00                	push   $0x0
f0104948:	6a 22                	push   $0x22
f010494a:	eb 4e                	jmp    f010499a <_alltraps>

f010494c <t_irq3>:
TRAPHANDLER_NOEC(t_irq3, IRQ_OFFSET + 3);
f010494c:	6a 00                	push   $0x0
f010494e:	6a 23                	push   $0x23
f0104950:	eb 48                	jmp    f010499a <_alltraps>

f0104952 <t_irq4>:
TRAPHANDLER_NOEC(t_irq4, IRQ_OFFSET + 4);
f0104952:	6a 00                	push   $0x0
f0104954:	6a 24                	push   $0x24
f0104956:	eb 42                	jmp    f010499a <_alltraps>

f0104958 <t_irq5>:
TRAPHANDLER_NOEC(t_irq5, IRQ_OFFSET + 5);
f0104958:	6a 00                	push   $0x0
f010495a:	6a 25                	push   $0x25
f010495c:	eb 3c                	jmp    f010499a <_alltraps>

f010495e <t_irq6>:
TRAPHANDLER_NOEC(t_irq6, IRQ_OFFSET + 6);
f010495e:	6a 00                	push   $0x0
f0104960:	6a 26                	push   $0x26
f0104962:	eb 36                	jmp    f010499a <_alltraps>

f0104964 <t_irq7>:
TRAPHANDLER_NOEC(t_irq7, IRQ_OFFSET + 7);
f0104964:	6a 00                	push   $0x0
f0104966:	6a 27                	push   $0x27
f0104968:	eb 30                	jmp    f010499a <_alltraps>

f010496a <t_irq8>:
TRAPHANDLER_NOEC(t_irq8, IRQ_OFFSET + 8);
f010496a:	6a 00                	push   $0x0
f010496c:	6a 28                	push   $0x28
f010496e:	eb 2a                	jmp    f010499a <_alltraps>

f0104970 <t_irq9>:
TRAPHANDLER_NOEC(t_irq9, IRQ_OFFSET + 9);
f0104970:	6a 00                	push   $0x0
f0104972:	6a 29                	push   $0x29
f0104974:	eb 24                	jmp    f010499a <_alltraps>

f0104976 <t_irq10>:
TRAPHANDLER_NOEC(t_irq10, IRQ_OFFSET + 10);
f0104976:	6a 00                	push   $0x0
f0104978:	6a 2a                	push   $0x2a
f010497a:	eb 1e                	jmp    f010499a <_alltraps>

f010497c <t_irq11>:
TRAPHANDLER_NOEC(t_irq11, IRQ_OFFSET + 11);
f010497c:	6a 00                	push   $0x0
f010497e:	6a 2b                	push   $0x2b
f0104980:	eb 18                	jmp    f010499a <_alltraps>

f0104982 <t_irq12>:
TRAPHANDLER_NOEC(t_irq12, IRQ_OFFSET + 12);
f0104982:	6a 00                	push   $0x0
f0104984:	6a 2c                	push   $0x2c
f0104986:	eb 12                	jmp    f010499a <_alltraps>

f0104988 <t_irq13>:
TRAPHANDLER_NOEC(t_irq13, IRQ_OFFSET + 13);
f0104988:	6a 00                	push   $0x0
f010498a:	6a 2d                	push   $0x2d
f010498c:	eb 0c                	jmp    f010499a <_alltraps>

f010498e <t_irq14>:
TRAPHANDLER_NOEC(t_irq14, IRQ_OFFSET + 14);
f010498e:	6a 00                	push   $0x0
f0104990:	6a 2e                	push   $0x2e
f0104992:	eb 06                	jmp    f010499a <_alltraps>

f0104994 <t_irq15>:
TRAPHANDLER_NOEC(t_irq15, IRQ_OFFSET + 15);
f0104994:	6a 00                	push   $0x0
f0104996:	6a 2f                	push   $0x2f
f0104998:	eb 00                	jmp    f010499a <_alltraps>

f010499a <_alltraps>:
/*
 * Lab 3: Your code here for _alltraps
 */
_alltraps:
    /* make a Trapframe */
    pushl %ds;
f010499a:	1e                   	push   %ds
    pushl %es;
f010499b:	06                   	push   %es
    pushal;
f010499c:	60                   	pusha  
	movl $GD_KD, %eax;
f010499d:	b8 10 00 00 00       	mov    $0x10,%eax
    movw %ax, %ds;
f01049a2:	8e d8                	mov    %eax,%ds
    movw %ax, %es;
f01049a4:	8e c0                	mov    %eax,%es
    pushl %esp;
f01049a6:	54                   	push   %esp
    call trap;
f01049a7:	e8 16 fd ff ff       	call   f01046c2 <trap>
f01049ac:	66 90                	xchg   %ax,%ax
f01049ae:	66 90                	xchg   %ax,%ax

f01049b0 <sched_yield>:


// Choose a user environment to run and run it.
void
sched_yield(void)
{
f01049b0:	55                   	push   %ebp
f01049b1:	89 e5                	mov    %esp,%ebp
f01049b3:	57                   	push   %edi
f01049b4:	56                   	push   %esi
f01049b5:	53                   	push   %ebx
f01049b6:	83 ec 1c             	sub    $0x1c,%esp
	// idle environment (env_type == ENV_TYPE_IDLE).  If there are
	// no runnable environments, simply drop through to the code
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
   struct Env *curr = thiscpu->cpu_env;
f01049b9:	e8 d5 1a 00 00       	call   f0106493 <cpunum>
f01049be:	6b c0 74             	imul   $0x74,%eax,%eax
f01049c1:	8b b0 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%esi
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
f01049c7:	85 f6                	test   %esi,%esi
f01049c9:	0f 84 df 00 00 00    	je     f0104aae <sched_yield+0xfe>
f01049cf:	8b 7e 48             	mov    0x48(%esi),%edi
f01049d2:	81 e7 ff 03 00 00    	and    $0x3ff,%edi
f01049d8:	e9 d6 00 00 00       	jmp    f0104ab3 <sched_yield+0x103>
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
f01049dd:	8d 47 01             	lea    0x1(%edi),%eax
f01049e0:	99                   	cltd   
f01049e1:	c1 ea 16             	shr    $0x16,%edx
f01049e4:	01 d0                	add    %edx,%eax
f01049e6:	25 ff 03 00 00       	and    $0x3ff,%eax
f01049eb:	29 d0                	sub    %edx,%eax
f01049ed:	89 c7                	mov    %eax,%edi
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f01049ef:	6b c0 7c             	imul   $0x7c,%eax,%eax
f01049f2:	8d 14 03             	lea    (%ebx,%eax,1),%edx
f01049f5:	83 7a 50 01          	cmpl   $0x1,0x50(%edx)
f01049f9:	74 0e                	je     f0104a09 <sched_yield+0x59>
            continue;
        
        if (envs[idx].env_status == ENV_RUNNABLE)
f01049fb:	83 7a 54 02          	cmpl   $0x2,0x54(%edx)
f01049ff:	75 08                	jne    f0104a09 <sched_yield+0x59>
            env_run(&envs[idx]);
f0104a01:	89 14 24             	mov    %edx,(%esp)
f0104a04:	e8 55 f0 ff ff       	call   f0103a5e <env_run>
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
   struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
	for (i = 1; i < NENV; i++) {
f0104a09:	83 e9 01             	sub    $0x1,%ecx
f0104a0c:	75 cf                	jne    f01049dd <sched_yield+0x2d>
        
        if (envs[idx].env_status == ENV_RUNNABLE)
            env_run(&envs[idx]);
	}

    if (curr && curr->env_status == ENV_RUNNING) {
f0104a0e:	85 f6                	test   %esi,%esi
f0104a10:	74 06                	je     f0104a18 <sched_yield+0x68>
f0104a12:	83 7e 54 03          	cmpl   $0x3,0x54(%esi)
f0104a16:	74 09                	je     f0104a21 <sched_yield+0x71>
f0104a18:	89 d8                	mov    %ebx,%eax
   struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f0104a1a:	ba 00 00 00 00       	mov    $0x0,%edx
f0104a1f:	eb 08                	jmp    f0104a29 <sched_yield+0x79>
            env_run(&envs[idx]);
	}

    if (curr && curr->env_status == ENV_RUNNING) {
        // If not found and current environment is running, then continue running.
        env_run(curr);
f0104a21:	89 34 24             	mov    %esi,(%esp)
f0104a24:	e8 35 f0 ff ff       	call   f0103a5e <env_run>

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a29:	83 78 50 01          	cmpl   $0x1,0x50(%eax)
f0104a2d:	74 0b                	je     f0104a3a <sched_yield+0x8a>
		    (envs[i].env_status == ENV_RUNNABLE ||
f0104a2f:	8b 70 54             	mov    0x54(%eax),%esi
f0104a32:	8d 4e fe             	lea    -0x2(%esi),%ecx

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
		if (envs[i].env_type != ENV_TYPE_IDLE &&
f0104a35:	83 f9 01             	cmp    $0x1,%ecx
f0104a38:	76 10                	jbe    f0104a4a <sched_yield+0x9a>
    }

	// For debugging and testing purposes, if there are no
	// runnable environments other than the idle environments,
	// drop into the kernel monitor.
	for (i = 0; i < NENV; i++) {
f0104a3a:	83 c2 01             	add    $0x1,%edx
f0104a3d:	83 c0 7c             	add    $0x7c,%eax
f0104a40:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104a46:	75 e1                	jne    f0104a29 <sched_yield+0x79>
f0104a48:	eb 08                	jmp    f0104a52 <sched_yield+0xa2>
		if (envs[i].env_type != ENV_TYPE_IDLE &&
		    (envs[i].env_status == ENV_RUNNABLE ||
		     envs[i].env_status == ENV_RUNNING))
			break;
	}
	if (i == NENV) {
f0104a4a:	81 fa 00 04 00 00    	cmp    $0x400,%edx
f0104a50:	75 1a                	jne    f0104a6c <sched_yield+0xbc>
		cprintf("No more runnable environments!\n");
f0104a52:	c7 04 24 d0 80 10 f0 	movl   $0xf01080d0,(%esp)
f0104a59:	e8 11 f2 ff ff       	call   f0103c6f <cprintf>
		while (1)
			monitor(NULL);
f0104a5e:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0104a65:	e8 4d bf ff ff       	call   f01009b7 <monitor>
f0104a6a:	eb f2                	jmp    f0104a5e <sched_yield+0xae>
	}

	// Run this CPU's idle environment when nothing else is runnable.
	idle = &envs[cpunum()];
f0104a6c:	e8 22 1a 00 00       	call   f0106493 <cpunum>
f0104a71:	6b c0 7c             	imul   $0x7c,%eax,%eax
f0104a74:	01 c3                	add    %eax,%ebx
	if (!(idle->env_status == ENV_RUNNABLE || idle->env_status == ENV_RUNNING))
f0104a76:	8b 43 54             	mov    0x54(%ebx),%eax
f0104a79:	83 e8 02             	sub    $0x2,%eax
f0104a7c:	83 f8 01             	cmp    $0x1,%eax
f0104a7f:	76 25                	jbe    f0104aa6 <sched_yield+0xf6>
		panic("CPU %d: No idle environment!", cpunum());
f0104a81:	e8 0d 1a 00 00       	call   f0106493 <cpunum>
f0104a86:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104a8a:	c7 44 24 08 f0 80 10 	movl   $0xf01080f0,0x8(%esp)
f0104a91:	f0 
f0104a92:	c7 44 24 04 43 00 00 	movl   $0x43,0x4(%esp)
f0104a99:	00 
f0104a9a:	c7 04 24 0d 81 10 f0 	movl   $0xf010810d,(%esp)
f0104aa1:	e8 9a b5 ff ff       	call   f0100040 <_panic>
	env_run(idle);
f0104aa6:	89 1c 24             	mov    %ebx,(%esp)
f0104aa9:	e8 b0 ef ff ff       	call   f0103a5e <env_run>
	// no runnable environments, simply drop through to the code
	// below to switch to this CPU's idle environment.

	// LAB 4: Your code here.
   struct Env *curr = thiscpu->cpu_env;
    int idx = curr ? ENVX(curr->env_id) % NENV : 0;
f0104aae:	bf 00 00 00 00       	mov    $0x0,%edi
	for (i = 1; i < NENV; i++) {
        idx = (idx + 1) % NENV;
        
        if (envs[idx].env_type == ENV_TYPE_IDLE)
f0104ab3:	8b 1d 48 c2 1c f0    	mov    0xf01cc248,%ebx
f0104ab9:	b9 ff 03 00 00       	mov    $0x3ff,%ecx
f0104abe:	e9 1a ff ff ff       	jmp    f01049dd <sched_yield+0x2d>
f0104ac3:	66 90                	xchg   %ax,%ax
f0104ac5:	66 90                	xchg   %ax,%ax
f0104ac7:	66 90                	xchg   %ax,%ax
f0104ac9:	66 90                	xchg   %ax,%ax
f0104acb:	66 90                	xchg   %ax,%ax
f0104acd:	66 90                	xchg   %ax,%ax
f0104acf:	90                   	nop

f0104ad0 <syscall>:
}

// Dispatches to the correct kernel function, passing the arguments.
int32_t
syscall(uint32_t syscallno, uint32_t a1, uint32_t a2, uint32_t a3, uint32_t a4, uint32_t a5)
{
f0104ad0:	55                   	push   %ebp
f0104ad1:	89 e5                	mov    %esp,%ebp
f0104ad3:	57                   	push   %edi
f0104ad4:	56                   	push   %esi
f0104ad5:	53                   	push   %ebx
f0104ad6:	83 ec 2c             	sub    $0x2c,%esp
f0104ad9:	8b 45 08             	mov    0x8(%ebp),%eax
	// Call the function corresponding to the 'syscallno' parameter.
	// Return any appropriate return value.
	// LAB 3: Your code here.
	//cprintf("The syscallno = %d\n", syscallno);
	switch(syscallno)
f0104adc:	83 f8 0d             	cmp    $0xd,%eax
f0104adf:	0f 87 ac 05 00 00    	ja     f0105091 <syscall+0x5c1>
f0104ae5:	ff 24 85 48 81 10 f0 	jmp    *-0xfef7eb8(,%eax,4)
			sys_env_destroy(sys_getenvid());
			return;
		}
	}*/
	//cprintf("sys_cputs!\n");
	user_mem_assert(curenv, s, len, PTE_U);
f0104aec:	e8 a2 19 00 00       	call   f0106493 <cpunum>
f0104af1:	c7 44 24 0c 04 00 00 	movl   $0x4,0xc(%esp)
f0104af8:	00 
f0104af9:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104afc:	89 7c 24 08          	mov    %edi,0x8(%esp)
f0104b00:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104b03:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104b07:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b0a:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104b10:	89 04 24             	mov    %eax,(%esp)
f0104b13:	e8 d0 e7 ff ff       	call   f01032e8 <user_mem_assert>
	//cprintf("user_mem_assert passed!\n");


	// Print the string supplied by the user.
	cprintf("%.*s", len, s);
f0104b18:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b1b:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104b1f:	8b 45 10             	mov    0x10(%ebp),%eax
f0104b22:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b26:	c7 04 24 1a 81 10 f0 	movl   $0xf010811a,(%esp)
f0104b2d:	e8 3d f1 ff ff       	call   f0103c6f <cprintf>
	//cprintf("The syscallno = %d\n", syscallno);
	switch(syscallno)
	{
	case SYS_cputs:
		sys_cputs((char*)a1, a2);
		return 0;
f0104b32:	b8 00 00 00 00       	mov    $0x0,%eax
f0104b37:	e9 76 05 00 00       	jmp    f01050b2 <syscall+0x5e2>
// Read a character from the system console without blocking.
// Returns the character, or 0 if there is no input waiting.
static int
sys_cgetc(void)
{
	return cons_getc();
f0104b3c:	e8 64 bb ff ff       	call   f01006a5 <cons_getc>
	{
	case SYS_cputs:
		sys_cputs((char*)a1, a2);
		return 0;
	case SYS_cgetc:
		return sys_cgetc();
f0104b41:	e9 6c 05 00 00       	jmp    f01050b2 <syscall+0x5e2>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104b46:	e8 48 19 00 00       	call   f0106493 <cpunum>
f0104b4b:	6b c0 74             	imul   $0x74,%eax,%eax
f0104b4e:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104b54:	8b 40 48             	mov    0x48(%eax),%eax
		sys_cputs((char*)a1, a2);
		return 0;
	case SYS_cgetc:
		return sys_cgetc();
	case SYS_getenvid:
		return sys_getenvid();
f0104b57:	e9 56 05 00 00       	jmp    f01050b2 <syscall+0x5e2>
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104b5c:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104b63:	00 
f0104b64:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104b67:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104b6b:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104b6e:	89 04 24             	mov    %eax,(%esp)
f0104b71:	e8 ca e7 ff ff       	call   f0103340 <envid2env>
		return r;
f0104b76:	89 c2                	mov    %eax,%edx
sys_env_destroy(envid_t envid)
{
	int r;
	struct Env *e;

	if ((r = envid2env(envid, &e, 1)) < 0)
f0104b78:	85 c0                	test   %eax,%eax
f0104b7a:	78 10                	js     f0104b8c <syscall+0xbc>
		return r;
	env_destroy(e);
f0104b7c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104b7f:	89 04 24             	mov    %eax,(%esp)
f0104b82:	e8 36 ee ff ff       	call   f01039bd <env_destroy>
	return 0;
f0104b87:	ba 00 00 00 00       	mov    $0x0,%edx
	case SYS_cgetc:
		return sys_cgetc();
	case SYS_getenvid:
		return sys_getenvid();
	case SYS_env_destroy:
		return sys_env_destroy(a1);
f0104b8c:	89 d0                	mov    %edx,%eax
f0104b8e:	e9 1f 05 00 00       	jmp    f01050b2 <syscall+0x5e2>

// Deschedule current environment and pick a different one to run.
static void
sys_yield(void)
{
	sched_yield();
f0104b93:	e8 18 fe ff ff       	call   f01049b0 <sched_yield>

	// LAB 4: Your code here.

	// check perm
	//cprintf("I have given ENVID: %08x ph page at %08x!!\n", envid, va);
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104b98:	8b 45 14             	mov    0x14(%ebp),%eax
f0104b9b:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104ba0:	83 f8 05             	cmp    $0x5,%eax
f0104ba3:	75 70                	jne    f0104c15 <syscall+0x145>
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
	struct Page* pp = page_alloc(ALLOC_ZERO);
f0104ba5:	c7 04 24 01 00 00 00 	movl   $0x1,(%esp)
f0104bac:	e8 58 c5 ff ff       	call   f0101109 <page_alloc>
f0104bb1:	89 c3                	mov    %eax,%ebx
	if(pp == NULL) // out of memory
f0104bb3:	85 c0                	test   %eax,%eax
f0104bb5:	74 68                	je     f0104c1f <syscall+0x14f>
		return -E_NO_MEM;

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104bb7:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104bbe:	00 
f0104bbf:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104bc2:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104bc6:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104bc9:	89 04 24             	mov    %eax,(%esp)
f0104bcc:	e8 6f e7 ff ff       	call   f0103340 <envid2env>
f0104bd1:	89 c1                	mov    %eax,%ecx
	if(r != 0) // any bad env
f0104bd3:	85 c9                	test   %ecx,%ecx
f0104bd5:	0f 85 d7 04 00 00    	jne    f01050b2 <syscall+0x5e2>
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104bdb:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104be2:	77 45                	ja     f0104c29 <syscall+0x159>
f0104be4:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104beb:	75 46                	jne    f0104c33 <syscall+0x163>
		return -E_INVAL;

	r = page_insert(target_env->env_pgdir, pp, va, perm | PTE_P);
f0104bed:	8b 45 14             	mov    0x14(%ebp),%eax
f0104bf0:	83 c8 01             	or     $0x1,%eax
f0104bf3:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0104bf7:	8b 45 10             	mov    0x10(%ebp),%eax
f0104bfa:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104bfe:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104c02:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104c05:	8b 40 60             	mov    0x60(%eax),%eax
f0104c08:	89 04 24             	mov    %eax,(%esp)
f0104c0b:	e8 12 c8 ff ff       	call   f0101422 <page_insert>
f0104c10:	e9 9d 04 00 00       	jmp    f01050b2 <syscall+0x5e2>
	// check perm
	//cprintf("I have given ENVID: %08x ph page at %08x!!\n", envid, va);
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104c15:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104c1a:	e9 93 04 00 00       	jmp    f01050b2 <syscall+0x5e2>
	struct Page* pp = page_alloc(ALLOC_ZERO);
	if(pp == NULL) // out of memory
		return -E_NO_MEM;
f0104c1f:	b8 fc ff ff ff       	mov    $0xfffffffc,%eax
f0104c24:	e9 89 04 00 00       	jmp    f01050b2 <syscall+0x5e2>
	if(r != 0) // any bad env
		return r;

	//if va >= UTOP, or va is not page-aligned.
	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0104c29:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
f0104c2e:	e9 7f 04 00 00       	jmp    f01050b2 <syscall+0x5e2>
f0104c33:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
		return sys_env_destroy(a1);
	case SYS_yield:
		sys_yield();
		return 0;
	case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
f0104c38:	e9 75 04 00 00       	jmp    f01050b2 <syscall+0x5e2>

	// LAB 4: Your code here.

	//cprintf("now at sys_page_map() mapping src: %08x to dst: %08x\n", srcva, dstva);
	//check perm
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104c3d:	8b 45 1c             	mov    0x1c(%ebp),%eax
f0104c40:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104c45:	83 f8 05             	cmp    $0x5,%eax
f0104c48:	0f 85 b0 00 00 00    	jne    f0104cfe <syscall+0x22e>

	//cprintf("1. perm check passed.\n");

	struct Env* srcenv, * dstenv;

	int r = envid2env(srcenvid, &srcenv, 1);
f0104c4e:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104c55:	00 
f0104c56:	8d 45 dc             	lea    -0x24(%ebp),%eax
f0104c59:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c5d:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104c60:	89 04 24             	mov    %eax,(%esp)
f0104c63:	e8 d8 e6 ff ff       	call   f0103340 <envid2env>
	if(r) return r;
f0104c68:	89 c2                	mov    %eax,%edx
f0104c6a:	85 c0                	test   %eax,%eax
f0104c6c:	0f 85 b4 00 00 00    	jne    f0104d26 <syscall+0x256>


	r = envid2env(dstenvid, &dstenv, 1);
f0104c72:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104c79:	00 
f0104c7a:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104c7d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104c81:	8b 45 14             	mov    0x14(%ebp),%eax
f0104c84:	89 04 24             	mov    %eax,(%esp)
f0104c87:	e8 b4 e6 ff ff       	call   f0103340 <envid2env>
	if(r) return r;
f0104c8c:	89 c2                	mov    %eax,%edx
f0104c8e:	85 c0                	test   %eax,%eax
f0104c90:	0f 85 90 00 00 00    	jne    f0104d26 <syscall+0x256>

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
f0104c96:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104c9d:	77 66                	ja     f0104d05 <syscall+0x235>
f0104c9f:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104ca6:	75 64                	jne    f0104d0c <syscall+0x23c>
		return -E_INVAL;

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
f0104ca8:	81 7d 18 ff ff bf ee 	cmpl   $0xeebfffff,0x18(%ebp)
f0104caf:	77 62                	ja     f0104d13 <syscall+0x243>
f0104cb1:	f7 45 18 ff 0f 00 00 	testl  $0xfff,0x18(%ebp)
f0104cb8:	75 60                	jne    f0104d1a <syscall+0x24a>

	//cprintf("2. address scope check passed.\n");

	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
f0104cba:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104cbd:	89 44 24 08          	mov    %eax,0x8(%esp)
f0104cc1:	8b 45 10             	mov    0x10(%ebp),%eax
f0104cc4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104cc8:	8b 45 dc             	mov    -0x24(%ebp),%eax
f0104ccb:	8b 40 60             	mov    0x60(%eax),%eax
f0104cce:	89 04 24             	mov    %eax,(%esp)
f0104cd1:	e8 61 c6 ff ff       	call   f0101337 <page_lookup>
	if(srcpp == NULL) return -E_INVAL;
f0104cd6:	85 c0                	test   %eax,%eax
f0104cd8:	74 47                	je     f0104d21 <syscall+0x251>
	//cprintf("3. page lookup check passed.\n");

	if(((perm & PTE_W) == 1) && (((*src_table_entry) & PTE_W) == 0))
		return -E_INVAL;

	r = page_insert(dstenv->env_pgdir, srcpp, dstva, perm);
f0104cda:	8b 75 1c             	mov    0x1c(%ebp),%esi
f0104cdd:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104ce1:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0104ce4:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104ce8:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104cec:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104cef:	8b 40 60             	mov    0x60(%eax),%eax
f0104cf2:	89 04 24             	mov    %eax,(%esp)
f0104cf5:	e8 28 c7 ff ff       	call   f0101422 <page_insert>
f0104cfa:	89 c2                	mov    %eax,%edx
f0104cfc:	eb 28                	jmp    f0104d26 <syscall+0x256>
	//cprintf("now at sys_page_map() mapping src: %08x to dst: %08x\n", srcva, dstva);
	//check perm
	if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104cfe:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104d03:	eb 21                	jmp    f0104d26 <syscall+0x256>

	r = envid2env(dstenvid, &dstenv, 1);
	if(r) return r;

	if(((uint32_t)srcva >= UTOP) || ((((uint32_t)srcva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104d05:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104d0a:	eb 1a                	jmp    f0104d26 <syscall+0x256>
f0104d0c:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104d11:	eb 13                	jmp    f0104d26 <syscall+0x256>

	if(((uint32_t)dstva >= UTOP) || ((((uint32_t)dstva & 0x00000fff) != 0)))
		return -E_INVAL;
f0104d13:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104d18:	eb 0c                	jmp    f0104d26 <syscall+0x256>
f0104d1a:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104d1f:	eb 05                	jmp    f0104d26 <syscall+0x256>
	//cprintf("2. address scope check passed.\n");

	pte_t* src_table_entry;
	struct Page* srcpp;
	srcpp = page_lookup(srcenv->env_pgdir, srcva, &src_table_entry);
	if(srcpp == NULL) return -E_INVAL;
f0104d21:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
		sys_yield();
		return 0;
	case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
	case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
f0104d26:	89 d0                	mov    %edx,%eax
f0104d28:	e9 85 03 00 00       	jmp    f01050b2 <syscall+0x5e2>
sys_page_unmap(envid_t envid, void *va)
{
	// Hint: This function is a wrapper around page_remove().

	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104d2d:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104d34:	00 
f0104d35:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104d38:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d3c:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104d3f:	89 04 24             	mov    %eax,(%esp)
f0104d42:	e8 f9 e5 ff ff       	call   f0103340 <envid2env>
	if(r) return r;
f0104d47:	89 c2                	mov    %eax,%edx
f0104d49:	85 c0                	test   %eax,%eax
f0104d4b:	75 3a                	jne    f0104d87 <syscall+0x2b7>

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
f0104d4d:	81 7d 10 ff ff bf ee 	cmpl   $0xeebfffff,0x10(%ebp)
f0104d54:	77 25                	ja     f0104d7b <syscall+0x2ab>
f0104d56:	f7 45 10 ff 0f 00 00 	testl  $0xfff,0x10(%ebp)
f0104d5d:	75 23                	jne    f0104d82 <syscall+0x2b2>
		return -E_INVAL;

	page_remove(target_env->env_pgdir, va);
f0104d5f:	8b 45 10             	mov    0x10(%ebp),%eax
f0104d62:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104d66:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104d69:	8b 40 60             	mov    0x60(%eax),%eax
f0104d6c:	89 04 24             	mov    %eax,(%esp)
f0104d6f:	e8 5c c6 ff ff       	call   f01013d0 <page_remove>
	return 0;
f0104d74:	ba 00 00 00 00       	mov    $0x0,%edx
f0104d79:	eb 0c                	jmp    f0104d87 <syscall+0x2b7>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r) return r;

	if(((uint32_t)va >= UTOP) || ((((uint32_t)va & 0x00000fff) != 0)))
		return -E_INVAL;
f0104d7b:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
f0104d80:	eb 05                	jmp    f0104d87 <syscall+0x2b7>
f0104d82:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
	case SYS_page_alloc:
		return sys_page_alloc(a1, (void*)a2, a3);
	case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
	case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
f0104d87:	89 d0                	mov    %edx,%eax
f0104d89:	e9 24 03 00 00       	jmp    f01050b2 <syscall+0x5e2>

// Returns the current environment's envid.
static envid_t
sys_getenvid(void)
{
	return curenv->env_id;
f0104d8e:	e8 00 17 00 00       	call   f0106493 <cpunum>
f0104d93:	6b c0 74             	imul   $0x74,%eax,%eax
f0104d96:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104d9c:	8b 58 48             	mov    0x48(%eax),%ebx
	// LAB 4: Your code here.
	//panic("sys_exofork not implemented");

	struct Env* new_env, *this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid, &this_env, 1);
f0104d9f:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104da6:	00 
f0104da7:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104daa:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104dae:	89 1c 24             	mov    %ebx,(%esp)
f0104db1:	e8 8a e5 ff ff       	call   f0103340 <envid2env>
	int r = env_alloc(&new_env, this_envid);
f0104db6:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0104dba:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104dbd:	89 04 24             	mov    %eax,(%esp)
f0104dc0:	e8 a0 e6 ff ff       	call   f0103465 <env_alloc>
	if(r != 0)
		return r;
f0104dc5:	89 c2                	mov    %eax,%edx

	struct Env* new_env, *this_env;
	envid_t this_envid = sys_getenvid();
	envid2env(this_envid, &this_env, 1);
	int r = env_alloc(&new_env, this_envid);
	if(r != 0)
f0104dc7:	85 c0                	test   %eax,%eax
f0104dc9:	75 21                	jne    f0104dec <syscall+0x31c>
		return r;

	new_env->env_tf = this_env->env_tf;
f0104dcb:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0104dce:	b9 11 00 00 00       	mov    $0x11,%ecx
f0104dd3:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0104dd6:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)

	//new_env->env_tf = this_env->env_tf;

	// make it appears to return 0
	new_env->env_tf.tf_regs.reg_eax = 0;
f0104dd8:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104ddb:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)

	new_env->env_status = ENV_NOT_RUNNABLE;
f0104de2:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)

	return new_env->env_id;
f0104de9:	8b 50 48             	mov    0x48(%eax),%edx
	case SYS_page_map:
		return sys_page_map(a1, (void*)a2, a3, (void*)a4, a5);
	case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
	case SYS_exofork:
		return sys_exofork();
f0104dec:	89 d0                	mov    %edx,%eax
f0104dee:	e9 bf 02 00 00       	jmp    f01050b2 <syscall+0x5e2>
	// check whether the current environment has permission to set
	// envid's status.

	// LAB 4: Your code here.
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
f0104df3:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104dfa:	00 
f0104dfb:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104dfe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e02:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e05:	89 04 24             	mov    %eax,(%esp)
f0104e08:	e8 33 e5 ff ff       	call   f0103340 <envid2env>
	if(r != 0)
		return r;
f0104e0d:	89 c2                	mov    %eax,%edx
	// envid's status.

	// LAB 4: Your code here.
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r != 0)
f0104e0f:	85 c0                	test   %eax,%eax
f0104e11:	75 21                	jne    f0104e34 <syscall+0x364>
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
f0104e13:	83 7d 10 04          	cmpl   $0x4,0x10(%ebp)
f0104e17:	74 06                	je     f0104e1f <syscall+0x34f>
f0104e19:	83 7d 10 02          	cmpl   $0x2,0x10(%ebp)
f0104e1d:	75 10                	jne    f0104e2f <syscall+0x35f>
		return -E_INVAL;

	target_env->env_status = status;
f0104e1f:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0104e22:	8b 4d 10             	mov    0x10(%ebp),%ecx
f0104e25:	89 48 54             	mov    %ecx,0x54(%eax)

	return 0;
f0104e28:	ba 00 00 00 00       	mov    $0x0,%edx
f0104e2d:	eb 05                	jmp    f0104e34 <syscall+0x364>
	struct Env* target_env;
	int r = envid2env(envid, &target_env, 1);
	if(r != 0)
		return r;
	if((status != ENV_RUNNABLE) && (status != ENV_NOT_RUNNABLE))
		return -E_INVAL;
f0104e2f:	ba fd ff ff ff       	mov    $0xfffffffd,%edx
	case SYS_page_unmap:
		return sys_page_unmap(a1, (void*)a2);
	case SYS_exofork:
		return sys_exofork();
	case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
f0104e34:	89 d0                	mov    %edx,%eax
f0104e36:	e9 77 02 00 00       	jmp    f01050b2 <syscall+0x5e2>
//		or the caller doesn't have permission to change envid.
static int
sys_env_set_pgfault_upcall(envid_t envid, void *func)
{
	// LAB 4: Your code here.
	struct Env* target_env = NULL;
f0104e3b:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	int r = envid2env(envid, &target_env, 1);
f0104e42:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0104e49:	00 
f0104e4a:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0104e4d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e51:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e54:	89 04 24             	mov    %eax,(%esp)
f0104e57:	e8 e4 e4 ff ff       	call   f0103340 <envid2env>
	if(r != 0) return r;
f0104e5c:	85 c0                	test   %eax,%eax
f0104e5e:	0f 85 4e 02 00 00    	jne    f01050b2 <syscall+0x5e2>
	target_env->env_pgfault_upcall = func;
f0104e64:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0104e67:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104e6a:	89 7a 64             	mov    %edi,0x64(%edx)
	case SYS_exofork:
		return sys_exofork();
	case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
	case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
f0104e6d:	e9 40 02 00 00       	jmp    f01050b2 <syscall+0x5e2>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	// LAB 4: Your code here.
	struct Env* target_env;
	int r;
	if((r = envid2env(envid, &target_env, 0)) < 0) return r; // BAD ENV
f0104e72:	c7 44 24 08 00 00 00 	movl   $0x0,0x8(%esp)
f0104e79:	00 
f0104e7a:	8d 45 e0             	lea    -0x20(%ebp),%eax
f0104e7d:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104e81:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104e84:	89 04 24             	mov    %eax,(%esp)
f0104e87:	e8 b4 e4 ff ff       	call   f0103340 <envid2env>
f0104e8c:	85 c0                	test   %eax,%eax
f0104e8e:	0f 88 0c 01 00 00    	js     f0104fa0 <syscall+0x4d0>
	if(!target_env->env_ipc_recving || target_env->env_ipc_from != 0) // dst not receiving
f0104e94:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104e97:	83 78 68 00          	cmpl   $0x0,0x68(%eax)
f0104e9b:	0f 84 03 01 00 00    	je     f0104fa4 <syscall+0x4d4>
f0104ea1:	8b 58 74             	mov    0x74(%eax),%ebx
f0104ea4:	85 db                	test   %ebx,%ebx
f0104ea6:	0f 85 ff 00 00 00    	jne    f0104fab <syscall+0x4db>
		return -E_IPC_NOT_RECV;


    target_env->env_ipc_perm = 0; //is set to 'perm' if a page was transferred, 0 otherwise.
f0104eac:	c7 40 78 00 00 00 00 	movl   $0x0,0x78(%eax)

	if((uint32_t)srcva < UTOP) // if a page is to be mapped
f0104eb3:	81 7d 14 ff ff bf ee 	cmpl   $0xeebfffff,0x14(%ebp)
f0104eba:	0f 87 a9 00 00 00    	ja     f0104f69 <syscall+0x499>
	{
		if( ROUNDDOWN(srcva, PGSIZE) != srcva) return -E_INVAL;
f0104ec0:	8b 45 14             	mov    0x14(%ebp),%eax
f0104ec3:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0104ec8:	39 45 14             	cmp    %eax,0x14(%ebp)
f0104ecb:	75 79                	jne    f0104f46 <syscall+0x476>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
f0104ecd:	8b 45 18             	mov    0x18(%ebp),%eax
f0104ed0:	25 fd f1 ff ff       	and    $0xfffff1fd,%eax
f0104ed5:	83 f8 05             	cmp    $0x5,%eax
f0104ed8:	75 73                	jne    f0104f4d <syscall+0x47d>
		return -E_INVAL;

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
f0104eda:	e8 b4 15 00 00       	call   f0106493 <cpunum>
f0104edf:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0104ee2:	89 54 24 08          	mov    %edx,0x8(%esp)
f0104ee6:	8b 75 14             	mov    0x14(%ebp),%esi
f0104ee9:	89 74 24 04          	mov    %esi,0x4(%esp)
f0104eed:	6b c0 74             	imul   $0x74,%eax,%eax
f0104ef0:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104ef6:	8b 40 60             	mov    0x60(%eax),%eax
f0104ef9:	89 04 24             	mov    %eax,(%esp)
f0104efc:	e8 36 c4 ff ff       	call   f0101337 <page_lookup>
		if(srcpp == NULL) return -E_INVAL;
f0104f01:	85 c0                	test   %eax,%eax
f0104f03:	74 4f                	je     f0104f54 <syscall+0x484>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
f0104f05:	f6 45 18 02          	testb  $0x2,0x18(%ebp)
f0104f09:	74 08                	je     f0104f13 <syscall+0x443>
f0104f0b:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f0104f0e:	f6 02 02             	testb  $0x2,(%edx)
f0104f11:	74 48                	je     f0104f5b <syscall+0x48b>
			return -E_INVAL;

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
f0104f13:	8b 55 e0             	mov    -0x20(%ebp),%edx
f0104f16:	8b 4a 6c             	mov    0x6c(%edx),%ecx
f0104f19:	85 c9                	test   %ecx,%ecx
f0104f1b:	74 4c                	je     f0104f69 <syscall+0x499>
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
f0104f1d:	8b 75 18             	mov    0x18(%ebp),%esi
f0104f20:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0104f24:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0104f28:	89 44 24 04          	mov    %eax,0x4(%esp)
f0104f2c:	8b 42 60             	mov    0x60(%edx),%eax
f0104f2f:	89 04 24             	mov    %eax,(%esp)
f0104f32:	e8 eb c4 ff ff       	call   f0101422 <page_insert>
f0104f37:	85 c0                	test   %eax,%eax
f0104f39:	78 27                	js     f0104f62 <syscall+0x492>
				return -E_NO_MEM;
			target_env->env_ipc_perm = perm;
f0104f3b:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104f3e:	8b 75 18             	mov    0x18(%ebp),%esi
f0104f41:	89 70 78             	mov    %esi,0x78(%eax)
f0104f44:	eb 23                	jmp    f0104f69 <syscall+0x499>

    target_env->env_ipc_perm = 0; //is set to 'perm' if a page was transferred, 0 otherwise.

	if((uint32_t)srcva < UTOP) // if a page is to be mapped
	{
		if( ROUNDDOWN(srcva, PGSIZE) != srcva) return -E_INVAL;
f0104f46:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104f4b:	eb 63                	jmp    f0104fb0 <syscall+0x4e0>
		if( ((perm & ( PTE_U | PTE_P)) != (PTE_U | PTE_P)) ||
		(((perm & (~( PTE_U | PTE_P | PTE_AVAIL | PTE_W))) != 0))
		)
		return -E_INVAL;
f0104f4d:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104f52:	eb 5c                	jmp    f0104fb0 <syscall+0x4e0>

		pte_t* src_table_entry;
		struct Page* srcpp;

		srcpp = page_lookup(curenv->env_pgdir, srcva, &src_table_entry);
		if(srcpp == NULL) return -E_INVAL;
f0104f54:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104f59:	eb 55                	jmp    f0104fb0 <syscall+0x4e0>

		if((perm & PTE_W) && (*src_table_entry & PTE_W) == 0)
			return -E_INVAL;
f0104f5b:	bb fd ff ff ff       	mov    $0xfffffffd,%ebx
f0104f60:	eb 4e                	jmp    f0104fb0 <syscall+0x4e0>

		if(target_env->env_ipc_dstva != 0) // really send the page if the target want.
		{
			if(page_insert (target_env->env_pgdir, srcpp, target_env->env_ipc_dstva, perm) < 0)
				return -E_NO_MEM;
f0104f62:	bb fc ff ff ff       	mov    $0xfffffffc,%ebx
f0104f67:	eb 47                	jmp    f0104fb0 <syscall+0x4e0>
			target_env->env_ipc_perm = perm;
		}
	}

	target_env->env_ipc_recving = 0;// set to 0 to block future sends;
f0104f69:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0104f6c:	c7 46 68 00 00 00 00 	movl   $0x0,0x68(%esi)
    target_env->env_ipc_from = curenv->env_id; // set to the sending envid;
f0104f73:	e8 1b 15 00 00       	call   f0106493 <cpunum>
f0104f78:	6b c0 74             	imul   $0x74,%eax,%eax
f0104f7b:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104f81:	8b 40 48             	mov    0x48(%eax),%eax
f0104f84:	89 46 74             	mov    %eax,0x74(%esi)
    target_env->env_ipc_value = value; //is set to the 'value' parameter;
f0104f87:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0104f8a:	8b 7d 10             	mov    0x10(%ebp),%edi
f0104f8d:	89 78 70             	mov    %edi,0x70(%eax)
	target_env->env_tf.tf_regs.reg_eax = 0;
f0104f90:	c7 40 1c 00 00 00 00 	movl   $0x0,0x1c(%eax)
	
	target_env->env_status = ENV_RUNNABLE;
f0104f97:	c7 40 54 02 00 00 00 	movl   $0x2,0x54(%eax)
f0104f9e:	eb 10                	jmp    f0104fb0 <syscall+0x4e0>
sys_ipc_try_send(envid_t envid, uint32_t value, void *srcva, unsigned perm)
{
	// LAB 4: Your code here.
	struct Env* target_env;
	int r;
	if((r = envid2env(envid, &target_env, 0)) < 0) return r; // BAD ENV
f0104fa0:	89 c3                	mov    %eax,%ebx
f0104fa2:	eb 0c                	jmp    f0104fb0 <syscall+0x4e0>
	if(!target_env->env_ipc_recving || target_env->env_ipc_from != 0) // dst not receiving
		return -E_IPC_NOT_RECV;
f0104fa4:	bb f9 ff ff ff       	mov    $0xfffffff9,%ebx
f0104fa9:	eb 05                	jmp    f0104fb0 <syscall+0x4e0>
f0104fab:	bb f9 ff ff ff       	mov    $0xfffffff9,%ebx
	case SYS_env_set_status:
		return sys_env_set_status(a1, a2);
	case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
	case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, a4);
f0104fb0:	89 d8                	mov    %ebx,%eax
f0104fb2:	e9 fb 00 00 00       	jmp    f01050b2 <syscall+0x5e2>
//	-E_INVAL if dstva < UTOP but dstva is not page-aligned.
static int
sys_ipc_recv(void *dstva)
{
	// LAB 4: Your code here.
	curenv->env_ipc_recving = 1;
f0104fb7:	e8 d7 14 00 00       	call   f0106493 <cpunum>
f0104fbc:	6b c0 74             	imul   $0x74,%eax,%eax
f0104fbf:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104fc5:	c7 40 68 01 00 00 00 	movl   $0x1,0x68(%eax)
	if((uint32_t)dstva < UTOP)
f0104fcc:	81 7d 0c ff ff bf ee 	cmpl   $0xeebfffff,0xc(%ebp)
f0104fd3:	77 25                	ja     f0104ffa <syscall+0x52a>
	{
		if(ROUNDDOWN(dstva, PGSIZE) != dstva) return -E_INVAL;
f0104fd5:	8b 45 0c             	mov    0xc(%ebp),%eax
f0104fd8:	25 00 f0 ff ff       	and    $0xfffff000,%eax
f0104fdd:	39 45 0c             	cmp    %eax,0xc(%ebp)
f0104fe0:	0f 85 c7 00 00 00    	jne    f01050ad <syscall+0x5dd>
		curenv->env_ipc_dstva = dstva;
f0104fe6:	e8 a8 14 00 00       	call   f0106493 <cpunum>
f0104feb:	6b c0 74             	imul   $0x74,%eax,%eax
f0104fee:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0104ff4:	8b 75 0c             	mov    0xc(%ebp),%esi
f0104ff7:	89 70 6c             	mov    %esi,0x6c(%eax)
	}
	curenv->env_status = ENV_NOT_RUNNABLE;
f0104ffa:	e8 94 14 00 00       	call   f0106493 <cpunum>
f0104fff:	6b c0 74             	imul   $0x74,%eax,%eax
f0105002:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0105008:	c7 40 54 04 00 00 00 	movl   $0x4,0x54(%eax)
	curenv->env_ipc_from = 0;
f010500f:	e8 7f 14 00 00       	call   f0106493 <cpunum>
f0105014:	6b c0 74             	imul   $0x74,%eax,%eax
f0105017:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f010501d:	c7 40 74 00 00 00 00 	movl   $0x0,0x74(%eax)


	sched_yield();
f0105024:	e8 87 f9 ff ff       	call   f01049b0 <sched_yield>
	// Remember to check whether the user has supplied us with a good
	// address!
	//panic("sys_env_set_trapframe not implemented");
	int re;
	struct Env* env;
	re=envid2env(envid,&env,1);
f0105029:	c7 44 24 08 01 00 00 	movl   $0x1,0x8(%esp)
f0105030:	00 
f0105031:	8d 45 e4             	lea    -0x1c(%ebp),%eax
f0105034:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105038:	8b 45 0c             	mov    0xc(%ebp),%eax
f010503b:	89 04 24             	mov    %eax,(%esp)
f010503e:	e8 fd e2 ff ff       	call   f0103340 <envid2env>
	if(re<0)
		return re;
f0105043:	89 c2                	mov    %eax,%edx
	// address!
	//panic("sys_env_set_trapframe not implemented");
	int re;
	struct Env* env;
	re=envid2env(envid,&env,1);
	if(re<0)
f0105045:	85 c0                	test   %eax,%eax
f0105047:	78 44                	js     f010508d <syscall+0x5bd>
		return re;
	user_mem_assert(env, tf, sizeof(struct Trapframe),0);
f0105049:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0105050:	00 
f0105051:	c7 44 24 08 44 00 00 	movl   $0x44,0x8(%esp)
f0105058:	00 
f0105059:	8b 45 10             	mov    0x10(%ebp),%eax
f010505c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105060:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105063:	89 04 24             	mov    %eax,(%esp)
f0105066:	e8 7d e2 ff ff       	call   f01032e8 <user_mem_assert>
	env->env_tf = *tf;
f010506b:	b9 11 00 00 00       	mov    $0x11,%ecx
f0105070:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105073:	8b 75 10             	mov    0x10(%ebp),%esi
f0105076:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
	env->env_tf.tf_eflags|= FL_IF;//interrupts enabled
f0105078:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010507b:	81 48 38 00 02 00 00 	orl    $0x200,0x38(%eax)
	env->env_tf.tf_cs = GD_UT | 3;//protection level 3
f0105082:	66 c7 40 34 1b 00    	movw   $0x1b,0x34(%eax)
	return 0;
f0105088:	ba 00 00 00 00       	mov    $0x0,%edx
	case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, a4);
	case SYS_ipc_recv:
		return sys_ipc_recv((void*)a1);
	case SYS_env_set_trapframe:
		return sys_env_set_trapframe((envid_t)a1, (struct Trapframe*)a2);
f010508d:	89 d0                	mov    %edx,%eax
f010508f:	eb 21                	jmp    f01050b2 <syscall+0x5e2>
	default:
		panic("Syscall number Invalid!\n");
f0105091:	c7 44 24 08 1f 81 10 	movl   $0xf010811f,0x8(%esp)
f0105098:	f0 
f0105099:	c7 44 24 04 fe 01 00 	movl   $0x1fe,0x4(%esp)
f01050a0:	00 
f01050a1:	c7 04 24 38 81 10 f0 	movl   $0xf0108138,(%esp)
f01050a8:	e8 93 af ff ff       	call   f0100040 <_panic>
	case SYS_env_set_pgfault_upcall:
		return sys_env_set_pgfault_upcall(a1, (void*)a2);
	case SYS_ipc_try_send:
		return sys_ipc_try_send(a1, a2, (void*)a3, a4);
	case SYS_ipc_recv:
		return sys_ipc_recv((void*)a1);
f01050ad:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax
	default:
		panic("Syscall number Invalid!\n");
	}

	return -E_INVAL;
}
f01050b2:	83 c4 2c             	add    $0x2c,%esp
f01050b5:	5b                   	pop    %ebx
f01050b6:	5e                   	pop    %esi
f01050b7:	5f                   	pop    %edi
f01050b8:	5d                   	pop    %ebp
f01050b9:	c3                   	ret    
f01050ba:	66 90                	xchg   %ax,%ax
f01050bc:	66 90                	xchg   %ax,%ax
f01050be:	66 90                	xchg   %ax,%ax

f01050c0 <stab_binsearch>:
//	will exit setting left = 118, right = 554.
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
f01050c0:	55                   	push   %ebp
f01050c1:	89 e5                	mov    %esp,%ebp
f01050c3:	57                   	push   %edi
f01050c4:	56                   	push   %esi
f01050c5:	53                   	push   %ebx
f01050c6:	83 ec 14             	sub    $0x14,%esp
f01050c9:	89 45 ec             	mov    %eax,-0x14(%ebp)
f01050cc:	89 55 e4             	mov    %edx,-0x1c(%ebp)
f01050cf:	89 4d e0             	mov    %ecx,-0x20(%ebp)
f01050d2:	8b 75 08             	mov    0x8(%ebp),%esi
	int l = *region_left, r = *region_right, any_matches = 0;
f01050d5:	8b 1a                	mov    (%edx),%ebx
f01050d7:	8b 01                	mov    (%ecx),%eax
f01050d9:	89 45 f0             	mov    %eax,-0x10(%ebp)
	
	while (l <= r) {
f01050dc:	39 c3                	cmp    %eax,%ebx
f01050de:	0f 8f 9a 00 00 00    	jg     f010517e <stab_binsearch+0xbe>
//
static void
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
f01050e4:	c7 45 e8 00 00 00 00 	movl   $0x0,-0x18(%ebp)
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f01050eb:	8b 45 f0             	mov    -0x10(%ebp),%eax
f01050ee:	01 d8                	add    %ebx,%eax
f01050f0:	89 c7                	mov    %eax,%edi
f01050f2:	c1 ef 1f             	shr    $0x1f,%edi
f01050f5:	01 c7                	add    %eax,%edi
f01050f7:	d1 ff                	sar    %edi
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f01050f9:	39 df                	cmp    %ebx,%edi
f01050fb:	0f 8c c4 00 00 00    	jl     f01051c5 <stab_binsearch+0x105>
f0105101:	8d 04 7f             	lea    (%edi,%edi,2),%eax
f0105104:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f0105107:	8d 14 81             	lea    (%ecx,%eax,4),%edx
f010510a:	0f b6 42 04          	movzbl 0x4(%edx),%eax
f010510e:	39 f0                	cmp    %esi,%eax
f0105110:	0f 84 b4 00 00 00    	je     f01051ca <stab_binsearch+0x10a>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f0105116:	89 f8                	mov    %edi,%eax
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
f0105118:	83 e8 01             	sub    $0x1,%eax
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
f010511b:	39 d8                	cmp    %ebx,%eax
f010511d:	0f 8c a2 00 00 00    	jl     f01051c5 <stab_binsearch+0x105>
f0105123:	0f b6 4a f8          	movzbl -0x8(%edx),%ecx
f0105127:	83 ea 0c             	sub    $0xc,%edx
f010512a:	39 f1                	cmp    %esi,%ecx
f010512c:	75 ea                	jne    f0105118 <stab_binsearch+0x58>
f010512e:	e9 99 00 00 00       	jmp    f01051cc <stab_binsearch+0x10c>
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
			*region_left = m;
f0105133:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f0105136:	89 03                	mov    %eax,(%ebx)
			l = true_m + 1;
f0105138:	8d 5f 01             	lea    0x1(%edi),%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f010513b:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f0105142:	eb 2b                	jmp    f010516f <stab_binsearch+0xaf>
		if (stabs[m].n_value < addr) {
			*region_left = m;
			l = true_m + 1;
		} else if (stabs[m].n_value > addr) {
f0105144:	3b 55 0c             	cmp    0xc(%ebp),%edx
f0105147:	76 14                	jbe    f010515d <stab_binsearch+0x9d>
			*region_right = m - 1;
f0105149:	83 e8 01             	sub    $0x1,%eax
f010514c:	89 45 f0             	mov    %eax,-0x10(%ebp)
f010514f:	8b 7d e0             	mov    -0x20(%ebp),%edi
f0105152:	89 07                	mov    %eax,(%edi)
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0105154:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
f010515b:	eb 12                	jmp    f010516f <stab_binsearch+0xaf>
			*region_right = m - 1;
			r = m - 1;
		} else {
			// exact match for 'addr', but continue loop to find
			// *region_right
			*region_left = m;
f010515d:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105160:	89 07                	mov    %eax,(%edi)
			l = m;
			addr++;
f0105162:	83 45 0c 01          	addl   $0x1,0xc(%ebp)
f0105166:	89 c3                	mov    %eax,%ebx
			l = true_m + 1;
			continue;
		}

		// actual binary search
		any_matches = 1;
f0105168:	c7 45 e8 01 00 00 00 	movl   $0x1,-0x18(%ebp)
stab_binsearch(const struct Stab *stabs, int *region_left, int *region_right,
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
f010516f:	3b 5d f0             	cmp    -0x10(%ebp),%ebx
f0105172:	0f 8e 73 ff ff ff    	jle    f01050eb <stab_binsearch+0x2b>
			l = m;
			addr++;
		}
	}

	if (!any_matches)
f0105178:	83 7d e8 00          	cmpl   $0x0,-0x18(%ebp)
f010517c:	75 0f                	jne    f010518d <stab_binsearch+0xcd>
		*region_right = *region_left - 1;
f010517e:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105181:	8b 00                	mov    (%eax),%eax
f0105183:	83 e8 01             	sub    $0x1,%eax
f0105186:	8b 75 e0             	mov    -0x20(%ebp),%esi
f0105189:	89 06                	mov    %eax,(%esi)
f010518b:	eb 57                	jmp    f01051e4 <stab_binsearch+0x124>
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f010518d:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105190:	8b 00                	mov    (%eax),%eax
		     l > *region_left && stabs[l].n_type != type;
f0105192:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f0105195:	8b 0f                	mov    (%edi),%ecx

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f0105197:	39 c8                	cmp    %ecx,%eax
f0105199:	7e 23                	jle    f01051be <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f010519b:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010519e:	8b 7d ec             	mov    -0x14(%ebp),%edi
f01051a1:	8d 14 97             	lea    (%edi,%edx,4),%edx
f01051a4:	0f b6 5a 04          	movzbl 0x4(%edx),%ebx
f01051a8:	39 f3                	cmp    %esi,%ebx
f01051aa:	74 12                	je     f01051be <stab_binsearch+0xfe>
		     l--)
f01051ac:	83 e8 01             	sub    $0x1,%eax

	if (!any_matches)
		*region_right = *region_left - 1;
	else {
		// find rightmost region containing 'addr'
		for (l = *region_right;
f01051af:	39 c8                	cmp    %ecx,%eax
f01051b1:	7e 0b                	jle    f01051be <stab_binsearch+0xfe>
		     l > *region_left && stabs[l].n_type != type;
f01051b3:	0f b6 5a f8          	movzbl -0x8(%edx),%ebx
f01051b7:	83 ea 0c             	sub    $0xc,%edx
f01051ba:	39 f3                	cmp    %esi,%ebx
f01051bc:	75 ee                	jne    f01051ac <stab_binsearch+0xec>
		     l--)
			/* do nothing */;
		*region_left = l;
f01051be:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f01051c1:	89 06                	mov    %eax,(%esi)
f01051c3:	eb 1f                	jmp    f01051e4 <stab_binsearch+0x124>
		
		// search for earliest stab with right type
		while (m >= l && stabs[m].n_type != type)
			m--;
		if (m < l) {	// no match in [l, m]
			l = true_m + 1;
f01051c5:	8d 5f 01             	lea    0x1(%edi),%ebx
			continue;
f01051c8:	eb a5                	jmp    f010516f <stab_binsearch+0xaf>
	       int type, uintptr_t addr)
{
	int l = *region_left, r = *region_right, any_matches = 0;
	
	while (l <= r) {
		int true_m = (l + r) / 2, m = true_m;
f01051ca:	89 f8                	mov    %edi,%eax
			continue;
		}

		// actual binary search
		any_matches = 1;
		if (stabs[m].n_value < addr) {
f01051cc:	8d 14 40             	lea    (%eax,%eax,2),%edx
f01051cf:	8b 4d ec             	mov    -0x14(%ebp),%ecx
f01051d2:	8b 54 91 08          	mov    0x8(%ecx,%edx,4),%edx
f01051d6:	3b 55 0c             	cmp    0xc(%ebp),%edx
f01051d9:	0f 82 54 ff ff ff    	jb     f0105133 <stab_binsearch+0x73>
f01051df:	e9 60 ff ff ff       	jmp    f0105144 <stab_binsearch+0x84>
		     l > *region_left && stabs[l].n_type != type;
		     l--)
			/* do nothing */;
		*region_left = l;
	}
}
f01051e4:	83 c4 14             	add    $0x14,%esp
f01051e7:	5b                   	pop    %ebx
f01051e8:	5e                   	pop    %esi
f01051e9:	5f                   	pop    %edi
f01051ea:	5d                   	pop    %ebp
f01051eb:	c3                   	ret    

f01051ec <debuginfo_eip>:
//	negative if not.  But even if it returns negative it has stored some
//	information into '*info'.
//
int
debuginfo_eip(uintptr_t addr, struct Eipdebuginfo *info)
{
f01051ec:	55                   	push   %ebp
f01051ed:	89 e5                	mov    %esp,%ebp
f01051ef:	57                   	push   %edi
f01051f0:	56                   	push   %esi
f01051f1:	53                   	push   %ebx
f01051f2:	83 ec 3c             	sub    $0x3c,%esp
f01051f5:	8b 7d 08             	mov    0x8(%ebp),%edi
f01051f8:	8b 75 0c             	mov    0xc(%ebp),%esi
	const struct Stab *stabs, *stab_end;
	const char *stabstr, *stabstr_end;
	int lfile, rfile, lfun, rfun, lline, rline;

	// Initialize *info
	info->eip_file = "<unknown>";
f01051fb:	c7 06 80 81 10 f0    	movl   $0xf0108180,(%esi)
	info->eip_line = 0;
f0105201:	c7 46 04 00 00 00 00 	movl   $0x0,0x4(%esi)
	info->eip_fn_name = "<unknown>";
f0105208:	c7 46 08 80 81 10 f0 	movl   $0xf0108180,0x8(%esi)
	info->eip_fn_namelen = 9;
f010520f:	c7 46 0c 09 00 00 00 	movl   $0x9,0xc(%esi)
	info->eip_fn_addr = addr;
f0105216:	89 7e 10             	mov    %edi,0x10(%esi)
	info->eip_fn_narg = 0;
f0105219:	c7 46 14 00 00 00 00 	movl   $0x0,0x14(%esi)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
f0105220:	81 ff ff ff 7f ef    	cmp    $0xef7fffff,%edi
f0105226:	0f 87 ca 00 00 00    	ja     f01052f6 <debuginfo_eip+0x10a>
		const struct UserStabData *usd = (const struct UserStabData *) USTABDATA;

		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
f010522c:	e8 62 12 00 00       	call   f0106493 <cpunum>
f0105231:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f0105238:	00 
f0105239:	c7 44 24 08 10 00 00 	movl   $0x10,0x8(%esp)
f0105240:	00 
f0105241:	c7 44 24 04 00 00 20 	movl   $0x200000,0x4(%esp)
f0105248:	00 
f0105249:	6b c0 74             	imul   $0x74,%eax,%eax
f010524c:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f0105252:	89 04 24             	mov    %eax,(%esp)
f0105255:	e8 d7 df ff ff       	call   f0103231 <user_mem_check>
f010525a:	85 c0                	test   %eax,%eax
f010525c:	0f 88 12 02 00 00    	js     f0105474 <debuginfo_eip+0x288>
		{
		    return -1;
		}
		stabs = usd->stabs;
f0105262:	a1 00 00 20 00       	mov    0x200000,%eax
f0105267:	89 45 d4             	mov    %eax,-0x2c(%ebp)
		stab_end = usd->stab_end;
f010526a:	8b 1d 04 00 20 00    	mov    0x200004,%ebx
		stabstr = usd->stabstr;
f0105270:	8b 15 08 00 20 00    	mov    0x200008,%edx
f0105276:	89 55 d0             	mov    %edx,-0x30(%ebp)
		stabstr_end = usd->stabstr_end;
f0105279:	a1 0c 00 20 00       	mov    0x20000c,%eax
f010527e:	89 45 cc             	mov    %eax,-0x34(%ebp)

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
f0105281:	e8 0d 12 00 00       	call   f0106493 <cpunum>
f0105286:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f010528d:	00 
f010528e:	89 da                	mov    %ebx,%edx
f0105290:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f0105293:	29 ca                	sub    %ecx,%edx
f0105295:	c1 fa 02             	sar    $0x2,%edx
f0105298:	69 d2 ab aa aa aa    	imul   $0xaaaaaaab,%edx,%edx
f010529e:	89 54 24 08          	mov    %edx,0x8(%esp)
f01052a2:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01052a6:	6b c0 74             	imul   $0x74,%eax,%eax
f01052a9:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f01052af:	89 04 24             	mov    %eax,(%esp)
f01052b2:	e8 7a df ff ff       	call   f0103231 <user_mem_check>
f01052b7:	85 c0                	test   %eax,%eax
f01052b9:	0f 88 bc 01 00 00    	js     f010547b <debuginfo_eip+0x28f>
f01052bf:	e8 cf 11 00 00       	call   f0106493 <cpunum>
f01052c4:	c7 44 24 0c 00 00 00 	movl   $0x0,0xc(%esp)
f01052cb:	00 
f01052cc:	8b 55 cc             	mov    -0x34(%ebp),%edx
f01052cf:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f01052d2:	29 ca                	sub    %ecx,%edx
f01052d4:	89 54 24 08          	mov    %edx,0x8(%esp)
f01052d8:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f01052dc:	6b c0 74             	imul   $0x74,%eax,%eax
f01052df:	8b 80 28 d0 1c f0    	mov    -0xfe32fd8(%eax),%eax
f01052e5:	89 04 24             	mov    %eax,(%esp)
f01052e8:	e8 44 df ff ff       	call   f0103231 <user_mem_check>
f01052ed:	85 c0                	test   %eax,%eax
f01052ef:	79 1f                	jns    f0105310 <debuginfo_eip+0x124>
f01052f1:	e9 8c 01 00 00       	jmp    f0105482 <debuginfo_eip+0x296>
	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
		stabstr_end = __STABSTR_END__;
f01052f6:	c7 45 cc ec 61 11 f0 	movl   $0xf01161ec,-0x34(%ebp)

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
		stabstr = __STABSTR_BEGIN__;
f01052fd:	c7 45 d0 4d 2c 11 f0 	movl   $0xf0112c4d,-0x30(%ebp)
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
		stab_end = __STAB_END__;
f0105304:	bb 4c 2c 11 f0       	mov    $0xf0112c4c,%ebx
	info->eip_fn_addr = addr;
	info->eip_fn_narg = 0;

	// Find the relevant set of stabs
	if (addr >= ULIM) {
		stabs = __STAB_BEGIN__;
f0105309:	c7 45 d4 10 87 10 f0 	movl   $0xf0108710,-0x2c(%ebp)
		    return -1;
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
f0105310:	8b 45 cc             	mov    -0x34(%ebp),%eax
f0105313:	39 45 d0             	cmp    %eax,-0x30(%ebp)
f0105316:	0f 83 6d 01 00 00    	jae    f0105489 <debuginfo_eip+0x29d>
f010531c:	80 78 ff 00          	cmpb   $0x0,-0x1(%eax)
f0105320:	0f 85 6a 01 00 00    	jne    f0105490 <debuginfo_eip+0x2a4>
	// 'eip'.  First, we find the basic source file containing 'eip'.
	// Then, we look in that source file for the function.  Then we look
	// for the line number.
	
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
f0105326:	c7 45 e4 00 00 00 00 	movl   $0x0,-0x1c(%ebp)
	rfile = (stab_end - stabs) - 1;
f010532d:	2b 5d d4             	sub    -0x2c(%ebp),%ebx
f0105330:	c1 fb 02             	sar    $0x2,%ebx
f0105333:	69 c3 ab aa aa aa    	imul   $0xaaaaaaab,%ebx,%eax
f0105339:	83 e8 01             	sub    $0x1,%eax
f010533c:	89 45 e0             	mov    %eax,-0x20(%ebp)
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
f010533f:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105343:	c7 04 24 64 00 00 00 	movl   $0x64,(%esp)
f010534a:	8d 4d e0             	lea    -0x20(%ebp),%ecx
f010534d:	8d 55 e4             	lea    -0x1c(%ebp),%edx
f0105350:	8b 5d d4             	mov    -0x2c(%ebp),%ebx
f0105353:	89 d8                	mov    %ebx,%eax
f0105355:	e8 66 fd ff ff       	call   f01050c0 <stab_binsearch>
	if (lfile == 0)
f010535a:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010535d:	85 c0                	test   %eax,%eax
f010535f:	0f 84 32 01 00 00    	je     f0105497 <debuginfo_eip+0x2ab>
		return -1;

	// Search within that file's stabs for the function definition
	// (N_FUN).
	lfun = lfile;
f0105365:	89 45 dc             	mov    %eax,-0x24(%ebp)
	rfun = rfile;
f0105368:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010536b:	89 45 d8             	mov    %eax,-0x28(%ebp)
	stab_binsearch(stabs, &lfun, &rfun, N_FUN, addr);
f010536e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105372:	c7 04 24 24 00 00 00 	movl   $0x24,(%esp)
f0105379:	8d 4d d8             	lea    -0x28(%ebp),%ecx
f010537c:	8d 55 dc             	lea    -0x24(%ebp),%edx
f010537f:	89 d8                	mov    %ebx,%eax
f0105381:	e8 3a fd ff ff       	call   f01050c0 <stab_binsearch>

	if (lfun <= rfun) {
f0105386:	8b 5d dc             	mov    -0x24(%ebp),%ebx
f0105389:	3b 5d d8             	cmp    -0x28(%ebp),%ebx
f010538c:	7f 23                	jg     f01053b1 <debuginfo_eip+0x1c5>
		// stabs[lfun] points to the function name
		// in the string table, but check bounds just in case.
		if (stabs[lfun].n_strx < stabstr_end - stabstr)
f010538e:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f0105391:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105394:	8d 04 87             	lea    (%edi,%eax,4),%eax
f0105397:	8b 10                	mov    (%eax),%edx
f0105399:	8b 4d cc             	mov    -0x34(%ebp),%ecx
f010539c:	2b 4d d0             	sub    -0x30(%ebp),%ecx
f010539f:	39 ca                	cmp    %ecx,%edx
f01053a1:	73 06                	jae    f01053a9 <debuginfo_eip+0x1bd>
			info->eip_fn_name = stabstr + stabs[lfun].n_strx;
f01053a3:	03 55 d0             	add    -0x30(%ebp),%edx
f01053a6:	89 56 08             	mov    %edx,0x8(%esi)
		info->eip_fn_addr = stabs[lfun].n_value;
f01053a9:	8b 40 08             	mov    0x8(%eax),%eax
f01053ac:	89 46 10             	mov    %eax,0x10(%esi)
f01053af:	eb 06                	jmp    f01053b7 <debuginfo_eip+0x1cb>
		lline = lfun;
		rline = rfun;
	} else {
		// Couldn't find function stab!  Maybe we're in an assembly
		// file.  Search the whole file for the line number.
		info->eip_fn_addr = addr;
f01053b1:	89 7e 10             	mov    %edi,0x10(%esi)
		lline = lfile;
f01053b4:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
		rline = rfile;
	}
	// Ignore stuff after the colon.
	info->eip_fn_namelen = strfind(info->eip_fn_name, ':') - info->eip_fn_name;
f01053b7:	c7 44 24 04 3a 00 00 	movl   $0x3a,0x4(%esp)
f01053be:	00 
f01053bf:	8b 46 08             	mov    0x8(%esi),%eax
f01053c2:	89 04 24             	mov    %eax,(%esp)
f01053c5:	e8 05 0a 00 00       	call   f0105dcf <strfind>
f01053ca:	2b 46 08             	sub    0x8(%esi),%eax
f01053cd:	89 46 0c             	mov    %eax,0xc(%esi)
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f01053d0:	8b 7d e4             	mov    -0x1c(%ebp),%edi
f01053d3:	39 fb                	cmp    %edi,%ebx
f01053d5:	7c 5d                	jl     f0105434 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f01053d7:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f01053da:	c1 e0 02             	shl    $0x2,%eax
f01053dd:	8b 4d d4             	mov    -0x2c(%ebp),%ecx
f01053e0:	8d 14 01             	lea    (%ecx,%eax,1),%edx
f01053e3:	89 55 c8             	mov    %edx,-0x38(%ebp)
f01053e6:	0f b6 52 04          	movzbl 0x4(%edx),%edx
f01053ea:	80 fa 84             	cmp    $0x84,%dl
f01053ed:	74 2d                	je     f010541c <debuginfo_eip+0x230>
f01053ef:	8d 44 01 f4          	lea    -0xc(%ecx,%eax,1),%eax
f01053f3:	8b 4d c8             	mov    -0x38(%ebp),%ecx
f01053f6:	eb 15                	jmp    f010540d <debuginfo_eip+0x221>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
		lline--;
f01053f8:	83 eb 01             	sub    $0x1,%ebx
	// Search backwards from the line number for the relevant filename
	// stab.
	// We can't just use the "lfile" stab because inlined functions
	// can interpolate code from a different file!
	// Such included source files use the N_SOL stab type.
	while (lline >= lfile
f01053fb:	39 fb                	cmp    %edi,%ebx
f01053fd:	7c 35                	jl     f0105434 <debuginfo_eip+0x248>
	       && stabs[lline].n_type != N_SOL
f01053ff:	89 c1                	mov    %eax,%ecx
f0105401:	83 e8 0c             	sub    $0xc,%eax
f0105404:	0f b6 50 10          	movzbl 0x10(%eax),%edx
f0105408:	80 fa 84             	cmp    $0x84,%dl
f010540b:	74 0f                	je     f010541c <debuginfo_eip+0x230>
	       && (stabs[lline].n_type != N_SO || !stabs[lline].n_value))
f010540d:	80 fa 64             	cmp    $0x64,%dl
f0105410:	75 e6                	jne    f01053f8 <debuginfo_eip+0x20c>
f0105412:	83 79 08 00          	cmpl   $0x0,0x8(%ecx)
f0105416:	74 e0                	je     f01053f8 <debuginfo_eip+0x20c>
		lline--;
	if (lline >= lfile && stabs[lline].n_strx < stabstr_end - stabstr)
f0105418:	39 df                	cmp    %ebx,%edi
f010541a:	7f 18                	jg     f0105434 <debuginfo_eip+0x248>
f010541c:	8d 04 5b             	lea    (%ebx,%ebx,2),%eax
f010541f:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105422:	8b 04 87             	mov    (%edi,%eax,4),%eax
f0105425:	8b 55 cc             	mov    -0x34(%ebp),%edx
f0105428:	2b 55 d0             	sub    -0x30(%ebp),%edx
f010542b:	39 d0                	cmp    %edx,%eax
f010542d:	73 05                	jae    f0105434 <debuginfo_eip+0x248>
		info->eip_file = stabstr + stabs[lline].n_strx;
f010542f:	03 45 d0             	add    -0x30(%ebp),%eax
f0105432:	89 06                	mov    %eax,(%esi)


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f0105434:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105437:	8b 4d d8             	mov    -0x28(%ebp),%ecx
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010543a:	b8 00 00 00 00       	mov    $0x0,%eax
		info->eip_file = stabstr + stabs[lline].n_strx;


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
f010543f:	39 ca                	cmp    %ecx,%edx
f0105441:	7d 75                	jge    f01054b8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
f0105443:	8d 42 01             	lea    0x1(%edx),%eax
f0105446:	39 c1                	cmp    %eax,%ecx
f0105448:	7e 54                	jle    f010549e <debuginfo_eip+0x2b2>
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f010544a:	8d 14 40             	lea    (%eax,%eax,2),%edx
f010544d:	c1 e2 02             	shl    $0x2,%edx
f0105450:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f0105453:	80 7c 17 04 a0       	cmpb   $0xa0,0x4(%edi,%edx,1)
f0105458:	75 4b                	jne    f01054a5 <debuginfo_eip+0x2b9>
f010545a:	8d 54 17 f4          	lea    -0xc(%edi,%edx,1),%edx
		     lline++)
			info->eip_fn_narg++;
f010545e:	83 46 14 01          	addl   $0x1,0x14(%esi)
	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
f0105462:	83 c0 01             	add    $0x1,%eax


	// Set eip_fn_narg to the number of arguments taken by the function,
	// or 0 if there was no containing function.
	if (lfun < rfun)
		for (lline = lfun + 1;
f0105465:	39 c1                	cmp    %eax,%ecx
f0105467:	7e 43                	jle    f01054ac <debuginfo_eip+0x2c0>
f0105469:	83 c2 0c             	add    $0xc,%edx
		     lline < rfun && stabs[lline].n_type == N_PSYM;
f010546c:	80 7a 10 a0          	cmpb   $0xa0,0x10(%edx)
f0105470:	74 ec                	je     f010545e <debuginfo_eip+0x272>
f0105472:	eb 3f                	jmp    f01054b3 <debuginfo_eip+0x2c7>
		// Make sure this memory is valid.
		// Return -1 if it is not.  Hint: Call user_mem_check.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) USTABDATA, sizeof(struct UserStabData), 0) < 0) 
		{
		    return -1;
f0105474:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105479:	eb 3d                	jmp    f01054b8 <debuginfo_eip+0x2cc>

		// Make sure the STABS and string table memory is valid.
		// LAB 3: Your code here.
		if (user_mem_check(curenv, (void *) stabs, stab_end - stabs, 0) < 0 || user_mem_check(curenv, (void *) stabstr, stabstr_end - stabstr, 0) < 0)
		 {
		    return -1;
f010547b:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105480:	eb 36                	jmp    f01054b8 <debuginfo_eip+0x2cc>
f0105482:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105487:	eb 2f                	jmp    f01054b8 <debuginfo_eip+0x2cc>
		}
	}

	// String table validity checks
	if (stabstr_end <= stabstr || stabstr_end[-1] != 0)
		return -1;
f0105489:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010548e:	eb 28                	jmp    f01054b8 <debuginfo_eip+0x2cc>
f0105490:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f0105495:	eb 21                	jmp    f01054b8 <debuginfo_eip+0x2cc>
	// Search the entire set of stabs for the source file (type N_SO).
	lfile = 0;
	rfile = (stab_end - stabs) - 1;
	stab_binsearch(stabs, &lfile, &rfile, N_SO, addr);
	if (lfile == 0)
		return -1;
f0105497:	b8 ff ff ff ff       	mov    $0xffffffff,%eax
f010549c:	eb 1a                	jmp    f01054b8 <debuginfo_eip+0x2cc>
		for (lline = lfun + 1;
		     lline < rfun && stabs[lline].n_type == N_PSYM;
		     lline++)
			info->eip_fn_narg++;
	
	return 0;
f010549e:	b8 00 00 00 00       	mov    $0x0,%eax
f01054a3:	eb 13                	jmp    f01054b8 <debuginfo_eip+0x2cc>
f01054a5:	b8 00 00 00 00       	mov    $0x0,%eax
f01054aa:	eb 0c                	jmp    f01054b8 <debuginfo_eip+0x2cc>
f01054ac:	b8 00 00 00 00       	mov    $0x0,%eax
f01054b1:	eb 05                	jmp    f01054b8 <debuginfo_eip+0x2cc>
f01054b3:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01054b8:	83 c4 3c             	add    $0x3c,%esp
f01054bb:	5b                   	pop    %ebx
f01054bc:	5e                   	pop    %esi
f01054bd:	5f                   	pop    %edi
f01054be:	5d                   	pop    %ebp
f01054bf:	c3                   	ret    

f01054c0 <printnum>:
 * using specified putch function and associated pointer putdat.
 */
static void
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
f01054c0:	55                   	push   %ebp
f01054c1:	89 e5                	mov    %esp,%ebp
f01054c3:	57                   	push   %edi
f01054c4:	56                   	push   %esi
f01054c5:	53                   	push   %ebx
f01054c6:	83 ec 3c             	sub    $0x3c,%esp
f01054c9:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01054cc:	89 d7                	mov    %edx,%edi
f01054ce:	8b 45 08             	mov    0x8(%ebp),%eax
f01054d1:	89 45 e0             	mov    %eax,-0x20(%ebp)
f01054d4:	8b 75 0c             	mov    0xc(%ebp),%esi
f01054d7:	89 75 d4             	mov    %esi,-0x2c(%ebp)
f01054da:	8b 45 10             	mov    0x10(%ebp),%eax
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
f01054dd:	b9 00 00 00 00       	mov    $0x0,%ecx
f01054e2:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01054e5:	89 4d dc             	mov    %ecx,-0x24(%ebp)
f01054e8:	39 f1                	cmp    %esi,%ecx
f01054ea:	72 14                	jb     f0105500 <printnum+0x40>
f01054ec:	3b 45 e0             	cmp    -0x20(%ebp),%eax
f01054ef:	76 0f                	jbe    f0105500 <printnum+0x40>
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f01054f1:	8b 45 14             	mov    0x14(%ebp),%eax
f01054f4:	8d 70 ff             	lea    -0x1(%eax),%esi
f01054f7:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
f01054fa:	85 f6                	test   %esi,%esi
f01054fc:	7f 60                	jg     f010555e <printnum+0x9e>
f01054fe:	eb 72                	jmp    f0105572 <printnum+0xb2>
printnum(void (*putch)(int, void*), void *putdat,
	 unsigned long long num, unsigned base, int width, int padc)
{
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
f0105500:	8b 4d 18             	mov    0x18(%ebp),%ecx
f0105503:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0105507:	8b 4d 14             	mov    0x14(%ebp),%ecx
f010550a:	8d 51 ff             	lea    -0x1(%ecx),%edx
f010550d:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105511:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105515:	8b 44 24 08          	mov    0x8(%esp),%eax
f0105519:	8b 54 24 0c          	mov    0xc(%esp),%edx
f010551d:	89 c3                	mov    %eax,%ebx
f010551f:	89 d6                	mov    %edx,%esi
f0105521:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105524:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f0105527:	89 54 24 08          	mov    %edx,0x8(%esp)
f010552b:	89 4c 24 0c          	mov    %ecx,0xc(%esp)
f010552f:	8b 45 e0             	mov    -0x20(%ebp),%eax
f0105532:	89 04 24             	mov    %eax,(%esp)
f0105535:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105538:	89 44 24 04          	mov    %eax,0x4(%esp)
f010553c:	e8 bf 13 00 00       	call   f0106900 <__udivdi3>
f0105541:	89 d9                	mov    %ebx,%ecx
f0105543:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0105547:	89 74 24 0c          	mov    %esi,0xc(%esp)
f010554b:	89 04 24             	mov    %eax,(%esp)
f010554e:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105552:	89 fa                	mov    %edi,%edx
f0105554:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0105557:	e8 64 ff ff ff       	call   f01054c0 <printnum>
f010555c:	eb 14                	jmp    f0105572 <printnum+0xb2>
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
			putch(padc, putdat);
f010555e:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105562:	8b 45 18             	mov    0x18(%ebp),%eax
f0105565:	89 04 24             	mov    %eax,(%esp)
f0105568:	ff d3                	call   *%ebx
	// first recursively print all preceding (more significant) digits
	if (num >= base) {
		printnum(putch, putdat, num / base, base, width - 1, padc);
	} else {
		// print any needed pad characters before first digit
		while (--width > 0)
f010556a:	83 ee 01             	sub    $0x1,%esi
f010556d:	75 ef                	jne    f010555e <printnum+0x9e>
f010556f:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
			putch(padc, putdat);
	}

	// then print this (the least significant) digit
	putch("0123456789abcdef"[num % base], putdat);
f0105572:	89 7c 24 04          	mov    %edi,0x4(%esp)
f0105576:	8b 7c 24 04          	mov    0x4(%esp),%edi
f010557a:	8b 45 d8             	mov    -0x28(%ebp),%eax
f010557d:	8b 55 dc             	mov    -0x24(%ebp),%edx
f0105580:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105584:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105588:	8b 45 e0             	mov    -0x20(%ebp),%eax
f010558b:	89 04 24             	mov    %eax,(%esp)
f010558e:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105591:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105595:	e8 96 14 00 00       	call   f0106a30 <__umoddi3>
f010559a:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010559e:	0f be 80 8a 81 10 f0 	movsbl -0xfef7e76(%eax),%eax
f01055a5:	89 04 24             	mov    %eax,(%esp)
f01055a8:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f01055ab:	ff d0                	call   *%eax
}
f01055ad:	83 c4 3c             	add    $0x3c,%esp
f01055b0:	5b                   	pop    %ebx
f01055b1:	5e                   	pop    %esi
f01055b2:	5f                   	pop    %edi
f01055b3:	5d                   	pop    %ebp
f01055b4:	c3                   	ret    

f01055b5 <sprintputch>:
	int cnt;
};

static void
sprintputch(int ch, struct sprintbuf *b)
{
f01055b5:	55                   	push   %ebp
f01055b6:	89 e5                	mov    %esp,%ebp
f01055b8:	8b 45 0c             	mov    0xc(%ebp),%eax
	b->cnt++;
f01055bb:	83 40 08 01          	addl   $0x1,0x8(%eax)
	if (b->buf < b->ebuf)
f01055bf:	8b 10                	mov    (%eax),%edx
f01055c1:	3b 50 04             	cmp    0x4(%eax),%edx
f01055c4:	73 0a                	jae    f01055d0 <sprintputch+0x1b>
		*b->buf++ = ch;
f01055c6:	8d 4a 01             	lea    0x1(%edx),%ecx
f01055c9:	89 08                	mov    %ecx,(%eax)
f01055cb:	8b 45 08             	mov    0x8(%ebp),%eax
f01055ce:	88 02                	mov    %al,(%edx)
}
f01055d0:	5d                   	pop    %ebp
f01055d1:	c3                   	ret    

f01055d2 <printfmt>:
	}
}

void
printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...)
{
f01055d2:	55                   	push   %ebp
f01055d3:	89 e5                	mov    %esp,%ebp
f01055d5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;

	va_start(ap, fmt);
f01055d8:	8d 45 14             	lea    0x14(%ebp),%eax
	vprintfmt(putch, putdat, fmt, ap);
f01055db:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01055df:	8b 45 10             	mov    0x10(%ebp),%eax
f01055e2:	89 44 24 08          	mov    %eax,0x8(%esp)
f01055e6:	8b 45 0c             	mov    0xc(%ebp),%eax
f01055e9:	89 44 24 04          	mov    %eax,0x4(%esp)
f01055ed:	8b 45 08             	mov    0x8(%ebp),%eax
f01055f0:	89 04 24             	mov    %eax,(%esp)
f01055f3:	e8 02 00 00 00       	call   f01055fa <vprintfmt>
	va_end(ap);
}
f01055f8:	c9                   	leave  
f01055f9:	c3                   	ret    

f01055fa <vprintfmt>:
// Main function to format and print a string.
void printfmt(void (*putch)(int, void*), void *putdat, const char *fmt, ...);

void
vprintfmt(void (*putch)(int, void*), void *putdat, const char *fmt, va_list ap)
{
f01055fa:	55                   	push   %ebp
f01055fb:	89 e5                	mov    %esp,%ebp
f01055fd:	57                   	push   %edi
f01055fe:	56                   	push   %esi
f01055ff:	53                   	push   %ebx
f0105600:	83 ec 3c             	sub    $0x3c,%esp
f0105603:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105606:	89 df                	mov    %ebx,%edi
f0105608:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010560b:	eb 03                	jmp    f0105610 <vprintfmt+0x16>
			break;
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
			for (fmt--; fmt[-1] != '%'; fmt--)
f010560d:	89 75 10             	mov    %esi,0x10(%ebp)
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f0105610:	8b 45 10             	mov    0x10(%ebp),%eax
f0105613:	8d 70 01             	lea    0x1(%eax),%esi
f0105616:	0f b6 00             	movzbl (%eax),%eax
f0105619:	83 f8 25             	cmp    $0x25,%eax
f010561c:	74 2d                	je     f010564b <vprintfmt+0x51>
			if (ch == '\0')
f010561e:	85 c0                	test   %eax,%eax
f0105620:	75 14                	jne    f0105636 <vprintfmt+0x3c>
f0105622:	e9 6b 04 00 00       	jmp    f0105a92 <vprintfmt+0x498>
f0105627:	85 c0                	test   %eax,%eax
f0105629:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0105630:	0f 84 5c 04 00 00    	je     f0105a92 <vprintfmt+0x498>
				return;
			putch(ch, putdat);
f0105636:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010563a:	89 04 24             	mov    %eax,(%esp)
f010563d:	ff d7                	call   *%edi
	unsigned long long num;
	int base, lflag, width, precision, altflag;
	char padc;

	while (1) {
		while ((ch = *(unsigned char *) fmt++) != '%') {
f010563f:	83 c6 01             	add    $0x1,%esi
f0105642:	0f b6 46 ff          	movzbl -0x1(%esi),%eax
f0105646:	83 f8 25             	cmp    $0x25,%eax
f0105649:	75 dc                	jne    f0105627 <vprintfmt+0x2d>
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f010564b:	c6 45 e3 20          	movb   $0x20,-0x1d(%ebp)
f010564f:	c7 45 d8 00 00 00 00 	movl   $0x0,-0x28(%ebp)
f0105656:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
f010565d:	c7 45 e4 ff ff ff ff 	movl   $0xffffffff,-0x1c(%ebp)
f0105664:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105669:	eb 1f                	jmp    f010568a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010566b:	8b 75 10             	mov    0x10(%ebp),%esi

		// flag to pad on the right
		case '-':
			padc = '-';
f010566e:	c6 45 e3 2d          	movb   $0x2d,-0x1d(%ebp)
f0105672:	eb 16                	jmp    f010568a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105674:	8b 75 10             	mov    0x10(%ebp),%esi
			padc = '-';
			goto reswitch;
			
		// flag to pad with 0's instead of spaces
		case '0':
			padc = '0';
f0105677:	c6 45 e3 30          	movb   $0x30,-0x1d(%ebp)
f010567b:	eb 0d                	jmp    f010568a <vprintfmt+0x90>
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
				width = precision, precision = -1;
f010567d:	8b 45 d4             	mov    -0x2c(%ebp),%eax
f0105680:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f0105683:	c7 45 d4 ff ff ff ff 	movl   $0xffffffff,-0x2c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f010568a:	8d 46 01             	lea    0x1(%esi),%eax
f010568d:	89 45 10             	mov    %eax,0x10(%ebp)
f0105690:	0f b6 06             	movzbl (%esi),%eax
f0105693:	0f b6 d0             	movzbl %al,%edx
f0105696:	83 e8 23             	sub    $0x23,%eax
f0105699:	3c 55                	cmp    $0x55,%al
f010569b:	0f 87 c4 03 00 00    	ja     f0105a65 <vprintfmt+0x46b>
f01056a1:	0f b6 c0             	movzbl %al,%eax
f01056a4:	ff 24 85 c0 82 10 f0 	jmp    *-0xfef7d40(,%eax,4)
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
				precision = precision * 10 + ch - '0';
f01056ab:	8d 42 d0             	lea    -0x30(%edx),%eax
f01056ae:	89 45 d4             	mov    %eax,-0x2c(%ebp)
				ch = *fmt;
f01056b1:	0f be 46 01          	movsbl 0x1(%esi),%eax
				if (ch < '0' || ch > '9')
f01056b5:	8d 50 d0             	lea    -0x30(%eax),%edx
f01056b8:	83 fa 09             	cmp    $0x9,%edx
f01056bb:	77 63                	ja     f0105720 <vprintfmt+0x126>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01056bd:	8b 75 10             	mov    0x10(%ebp),%esi
f01056c0:	89 4d d0             	mov    %ecx,-0x30(%ebp)
f01056c3:	8b 55 d4             	mov    -0x2c(%ebp),%edx
		case '5':
		case '6':
		case '7':
		case '8':
		case '9':
			for (precision = 0; ; ++fmt) {
f01056c6:	83 c6 01             	add    $0x1,%esi
				precision = precision * 10 + ch - '0';
f01056c9:	8d 14 92             	lea    (%edx,%edx,4),%edx
f01056cc:	8d 54 50 d0          	lea    -0x30(%eax,%edx,2),%edx
				ch = *fmt;
f01056d0:	0f be 06             	movsbl (%esi),%eax
				if (ch < '0' || ch > '9')
f01056d3:	8d 48 d0             	lea    -0x30(%eax),%ecx
f01056d6:	83 f9 09             	cmp    $0x9,%ecx
f01056d9:	76 eb                	jbe    f01056c6 <vprintfmt+0xcc>
f01056db:	8b 4d d0             	mov    -0x30(%ebp),%ecx
f01056de:	89 55 d4             	mov    %edx,-0x2c(%ebp)
f01056e1:	eb 40                	jmp    f0105723 <vprintfmt+0x129>
					break;
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
f01056e3:	8b 45 14             	mov    0x14(%ebp),%eax
f01056e6:	8b 00                	mov    (%eax),%eax
f01056e8:	89 45 d4             	mov    %eax,-0x2c(%ebp)
f01056eb:	8b 45 14             	mov    0x14(%ebp),%eax
f01056ee:	8d 40 04             	lea    0x4(%eax),%eax
f01056f1:	89 45 14             	mov    %eax,0x14(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01056f4:	8b 75 10             	mov    0x10(%ebp),%esi
			}
			goto process_precision;

		case '*':
			precision = va_arg(ap, int);
			goto process_precision;
f01056f7:	eb 2a                	jmp    f0105723 <vprintfmt+0x129>
f01056f9:	8b 55 e4             	mov    -0x1c(%ebp),%edx
f01056fc:	85 d2                	test   %edx,%edx
f01056fe:	b8 00 00 00 00       	mov    $0x0,%eax
f0105703:	0f 49 c2             	cmovns %edx,%eax
f0105706:	89 45 e4             	mov    %eax,-0x1c(%ebp)
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105709:	8b 75 10             	mov    0x10(%ebp),%esi
f010570c:	e9 79 ff ff ff       	jmp    f010568a <vprintfmt+0x90>
f0105711:	8b 75 10             	mov    0x10(%ebp),%esi
			if (width < 0)
				width = 0;
			goto reswitch;

		case '#':
			altflag = 1;
f0105714:	c7 45 d8 01 00 00 00 	movl   $0x1,-0x28(%ebp)
			goto reswitch;
f010571b:	e9 6a ff ff ff       	jmp    f010568a <vprintfmt+0x90>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105720:	8b 75 10             	mov    0x10(%ebp),%esi
		case '#':
			altflag = 1;
			goto reswitch;

		process_precision:
			if (width < 0)
f0105723:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105727:	0f 89 5d ff ff ff    	jns    f010568a <vprintfmt+0x90>
f010572d:	e9 4b ff ff ff       	jmp    f010567d <vprintfmt+0x83>
				width = precision, precision = -1;
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
f0105732:	83 c1 01             	add    $0x1,%ecx
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f0105735:	8b 75 10             	mov    0x10(%ebp),%esi
			goto reswitch;

		// long flag (doubled for long long)
		case 'l':
			lflag++;
			goto reswitch;
f0105738:	e9 4d ff ff ff       	jmp    f010568a <vprintfmt+0x90>

		// character
		case 'c':
			putch(va_arg(ap, int), putdat);
f010573d:	8b 45 14             	mov    0x14(%ebp),%eax
f0105740:	8d 70 04             	lea    0x4(%eax),%esi
f0105743:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105747:	8b 00                	mov    (%eax),%eax
f0105749:	89 04 24             	mov    %eax,(%esp)
f010574c:	ff d7                	call   *%edi
f010574e:	89 75 14             	mov    %esi,0x14(%ebp)
			break;
f0105751:	e9 ba fe ff ff       	jmp    f0105610 <vprintfmt+0x16>

		// error message
		case 'e':
			err = va_arg(ap, int);
f0105756:	8b 45 14             	mov    0x14(%ebp),%eax
f0105759:	8d 70 04             	lea    0x4(%eax),%esi
f010575c:	8b 00                	mov    (%eax),%eax
f010575e:	99                   	cltd   
f010575f:	31 d0                	xor    %edx,%eax
f0105761:	29 d0                	sub    %edx,%eax
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
f0105763:	83 f8 0f             	cmp    $0xf,%eax
f0105766:	7f 0b                	jg     f0105773 <vprintfmt+0x179>
f0105768:	8b 14 85 20 84 10 f0 	mov    -0xfef7be0(,%eax,4),%edx
f010576f:	85 d2                	test   %edx,%edx
f0105771:	75 20                	jne    f0105793 <vprintfmt+0x199>
				printfmt(putch, putdat, "error %d", err);
f0105773:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105777:	c7 44 24 08 a2 81 10 	movl   $0xf01081a2,0x8(%esp)
f010577e:	f0 
f010577f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105783:	89 3c 24             	mov    %edi,(%esp)
f0105786:	e8 47 fe ff ff       	call   f01055d2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f010578b:	89 75 14             	mov    %esi,0x14(%ebp)
			if (err < 0)
				err = -err;
			if (err >= MAXERROR || (p = error_string[err]) == NULL)
				printfmt(putch, putdat, "error %d", err);
f010578e:	e9 7d fe ff ff       	jmp    f0105610 <vprintfmt+0x16>
			else
				printfmt(putch, putdat, "%s", p);
f0105793:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0105797:	c7 44 24 08 6e 71 10 	movl   $0xf010716e,0x8(%esp)
f010579e:	f0 
f010579f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01057a3:	89 3c 24             	mov    %edi,(%esp)
f01057a6:	e8 27 fe ff ff       	call   f01055d2 <printfmt>
			putch(va_arg(ap, int), putdat);
			break;

		// error message
		case 'e':
			err = va_arg(ap, int);
f01057ab:	89 75 14             	mov    %esi,0x14(%ebp)
f01057ae:	e9 5d fe ff ff       	jmp    f0105610 <vprintfmt+0x16>
		width = -1;
		precision = -1;
		lflag = 0;
		altflag = 0;
	reswitch:
		switch (ch = *(unsigned char *) fmt++) {
f01057b3:	8b 45 14             	mov    0x14(%ebp),%eax
f01057b6:	8b 55 d4             	mov    -0x2c(%ebp),%edx
f01057b9:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				printfmt(putch, putdat, "%s", p);
			break;

		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
f01057bc:	83 45 14 04          	addl   $0x4,0x14(%ebp)
f01057c0:	8b 00                	mov    (%eax),%eax
				p = "(null)";
f01057c2:	85 c0                	test   %eax,%eax
f01057c4:	b9 9b 81 10 f0       	mov    $0xf010819b,%ecx
f01057c9:	0f 45 c8             	cmovne %eax,%ecx
f01057cc:	89 4d d0             	mov    %ecx,-0x30(%ebp)
			if (width > 0 && padc != '-')
f01057cf:	80 7d e3 2d          	cmpb   $0x2d,-0x1d(%ebp)
f01057d3:	74 04                	je     f01057d9 <vprintfmt+0x1df>
f01057d5:	85 f6                	test   %esi,%esi
f01057d7:	7f 19                	jg     f01057f2 <vprintfmt+0x1f8>
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f01057d9:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01057dc:	8d 70 01             	lea    0x1(%eax),%esi
f01057df:	0f b6 10             	movzbl (%eax),%edx
f01057e2:	0f be c2             	movsbl %dl,%eax
f01057e5:	85 c0                	test   %eax,%eax
f01057e7:	0f 85 9a 00 00 00    	jne    f0105887 <vprintfmt+0x28d>
f01057ed:	e9 87 00 00 00       	jmp    f0105879 <vprintfmt+0x27f>
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f01057f2:	89 54 24 04          	mov    %edx,0x4(%esp)
f01057f6:	8b 45 d0             	mov    -0x30(%ebp),%eax
f01057f9:	89 04 24             	mov    %eax,(%esp)
f01057fc:	e8 11 04 00 00       	call   f0105c12 <strnlen>
f0105801:	29 c6                	sub    %eax,%esi
f0105803:	89 f0                	mov    %esi,%eax
f0105805:	89 75 e4             	mov    %esi,-0x1c(%ebp)
f0105808:	85 f6                	test   %esi,%esi
f010580a:	7e cd                	jle    f01057d9 <vprintfmt+0x1df>
					putch(padc, putdat);
f010580c:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105810:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0105813:	89 c3                	mov    %eax,%ebx
f0105815:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105818:	89 44 24 04          	mov    %eax,0x4(%esp)
f010581c:	89 34 24             	mov    %esi,(%esp)
f010581f:	ff d7                	call   *%edi
		// string
		case 's':
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
f0105821:	83 eb 01             	sub    $0x1,%ebx
f0105824:	75 ef                	jne    f0105815 <vprintfmt+0x21b>
f0105826:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105829:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f010582c:	eb ab                	jmp    f01057d9 <vprintfmt+0x1df>
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
f010582e:	83 7d d8 00          	cmpl   $0x0,-0x28(%ebp)
f0105832:	74 1e                	je     f0105852 <vprintfmt+0x258>
f0105834:	0f be d2             	movsbl %dl,%edx
f0105837:	83 ea 20             	sub    $0x20,%edx
f010583a:	83 fa 5e             	cmp    $0x5e,%edx
f010583d:	76 13                	jbe    f0105852 <vprintfmt+0x258>
					putch('?', putdat);
f010583f:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105842:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105846:	c7 04 24 3f 00 00 00 	movl   $0x3f,(%esp)
f010584d:	ff 55 08             	call   *0x8(%ebp)
f0105850:	eb 0d                	jmp    f010585f <vprintfmt+0x265>
				else
					putch(ch, putdat);
f0105852:	8b 4d 0c             	mov    0xc(%ebp),%ecx
f0105855:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105859:	89 04 24             	mov    %eax,(%esp)
f010585c:	ff 55 08             	call   *0x8(%ebp)
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f010585f:	83 eb 01             	sub    $0x1,%ebx
f0105862:	83 c6 01             	add    $0x1,%esi
f0105865:	0f b6 56 ff          	movzbl -0x1(%esi),%edx
f0105869:	0f be c2             	movsbl %dl,%eax
f010586c:	85 c0                	test   %eax,%eax
f010586e:	75 23                	jne    f0105893 <vprintfmt+0x299>
f0105870:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f0105873:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105876:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105879:	8b 75 e4             	mov    -0x1c(%ebp),%esi
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f010587c:	83 7d e4 00          	cmpl   $0x0,-0x1c(%ebp)
f0105880:	7f 25                	jg     f01058a7 <vprintfmt+0x2ad>
f0105882:	e9 89 fd ff ff       	jmp    f0105610 <vprintfmt+0x16>
f0105887:	89 7d 08             	mov    %edi,0x8(%ebp)
f010588a:	8b 7d d4             	mov    -0x2c(%ebp),%edi
f010588d:	89 5d 0c             	mov    %ebx,0xc(%ebp)
f0105890:	8b 5d e4             	mov    -0x1c(%ebp),%ebx
			if ((p = va_arg(ap, char *)) == NULL)
				p = "(null)";
			if (width > 0 && padc != '-')
				for (width -= strnlen(p, precision); width > 0; width--)
					putch(padc, putdat);
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
f0105893:	85 ff                	test   %edi,%edi
f0105895:	78 97                	js     f010582e <vprintfmt+0x234>
f0105897:	83 ef 01             	sub    $0x1,%edi
f010589a:	79 92                	jns    f010582e <vprintfmt+0x234>
f010589c:	89 5d e4             	mov    %ebx,-0x1c(%ebp)
f010589f:	8b 7d 08             	mov    0x8(%ebp),%edi
f01058a2:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f01058a5:	eb d2                	jmp    f0105879 <vprintfmt+0x27f>
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
				putch(' ', putdat);
f01058a7:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01058ab:	c7 04 24 20 00 00 00 	movl   $0x20,(%esp)
f01058b2:	ff d7                	call   *%edi
			for (; (ch = *p++) != '\0' && (precision < 0 || --precision >= 0); width--)
				if (altflag && (ch < ' ' || ch > '~'))
					putch('?', putdat);
				else
					putch(ch, putdat);
			for (; width > 0; width--)
f01058b4:	83 ee 01             	sub    $0x1,%esi
f01058b7:	75 ee                	jne    f01058a7 <vprintfmt+0x2ad>
f01058b9:	e9 52 fd ff ff       	jmp    f0105610 <vprintfmt+0x16>
// Same as getuint but signed - can't use getuint
// because of sign extension
static long long
getint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01058be:	83 f9 01             	cmp    $0x1,%ecx
f01058c1:	7e 19                	jle    f01058dc <vprintfmt+0x2e2>
		return va_arg(*ap, long long);
f01058c3:	8b 45 14             	mov    0x14(%ebp),%eax
f01058c6:	8b 50 04             	mov    0x4(%eax),%edx
f01058c9:	8b 00                	mov    (%eax),%eax
f01058cb:	89 45 d8             	mov    %eax,-0x28(%ebp)
f01058ce:	89 55 dc             	mov    %edx,-0x24(%ebp)
f01058d1:	8b 45 14             	mov    0x14(%ebp),%eax
f01058d4:	8d 40 08             	lea    0x8(%eax),%eax
f01058d7:	89 45 14             	mov    %eax,0x14(%ebp)
f01058da:	eb 38                	jmp    f0105914 <vprintfmt+0x31a>
	else if (lflag)
f01058dc:	85 c9                	test   %ecx,%ecx
f01058de:	74 1b                	je     f01058fb <vprintfmt+0x301>
		return va_arg(*ap, long);
f01058e0:	8b 45 14             	mov    0x14(%ebp),%eax
f01058e3:	8b 30                	mov    (%eax),%esi
f01058e5:	89 75 d8             	mov    %esi,-0x28(%ebp)
f01058e8:	89 f0                	mov    %esi,%eax
f01058ea:	c1 f8 1f             	sar    $0x1f,%eax
f01058ed:	89 45 dc             	mov    %eax,-0x24(%ebp)
f01058f0:	8b 45 14             	mov    0x14(%ebp),%eax
f01058f3:	8d 40 04             	lea    0x4(%eax),%eax
f01058f6:	89 45 14             	mov    %eax,0x14(%ebp)
f01058f9:	eb 19                	jmp    f0105914 <vprintfmt+0x31a>
	else
		return va_arg(*ap, int);
f01058fb:	8b 45 14             	mov    0x14(%ebp),%eax
f01058fe:	8b 30                	mov    (%eax),%esi
f0105900:	89 75 d8             	mov    %esi,-0x28(%ebp)
f0105903:	89 f0                	mov    %esi,%eax
f0105905:	c1 f8 1f             	sar    $0x1f,%eax
f0105908:	89 45 dc             	mov    %eax,-0x24(%ebp)
f010590b:	8b 45 14             	mov    0x14(%ebp),%eax
f010590e:	8d 40 04             	lea    0x4(%eax),%eax
f0105911:	89 45 14             	mov    %eax,0x14(%ebp)
				putch(' ', putdat);
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
f0105914:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105917:	8b 4d dc             	mov    -0x24(%ebp),%ecx
			if ((long long) num < 0) {
				putch('-', putdat);
				num = -(long long) num;
			}
			base = 10;
f010591a:	b8 0a 00 00 00       	mov    $0xa,%eax
			break;

		// (signed) decimal
		case 'd':
			num = getint(&ap, lflag);
			if ((long long) num < 0) {
f010591f:	83 7d dc 00          	cmpl   $0x0,-0x24(%ebp)
f0105923:	0f 89 06 01 00 00    	jns    f0105a2f <vprintfmt+0x435>
				putch('-', putdat);
f0105929:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f010592d:	c7 04 24 2d 00 00 00 	movl   $0x2d,(%esp)
f0105934:	ff d7                	call   *%edi
				num = -(long long) num;
f0105936:	8b 55 d8             	mov    -0x28(%ebp),%edx
f0105939:	8b 4d dc             	mov    -0x24(%ebp),%ecx
f010593c:	f7 da                	neg    %edx
f010593e:	83 d1 00             	adc    $0x0,%ecx
f0105941:	f7 d9                	neg    %ecx
			}
			base = 10;
f0105943:	b8 0a 00 00 00       	mov    $0xa,%eax
f0105948:	e9 e2 00 00 00       	jmp    f0105a2f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f010594d:	83 f9 01             	cmp    $0x1,%ecx
f0105950:	7e 10                	jle    f0105962 <vprintfmt+0x368>
		return va_arg(*ap, unsigned long long);
f0105952:	8b 45 14             	mov    0x14(%ebp),%eax
f0105955:	8b 10                	mov    (%eax),%edx
f0105957:	8b 48 04             	mov    0x4(%eax),%ecx
f010595a:	8d 40 08             	lea    0x8(%eax),%eax
f010595d:	89 45 14             	mov    %eax,0x14(%ebp)
f0105960:	eb 26                	jmp    f0105988 <vprintfmt+0x38e>
	else if (lflag)
f0105962:	85 c9                	test   %ecx,%ecx
f0105964:	74 12                	je     f0105978 <vprintfmt+0x37e>
		return va_arg(*ap, unsigned long);
f0105966:	8b 45 14             	mov    0x14(%ebp),%eax
f0105969:	8b 10                	mov    (%eax),%edx
f010596b:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105970:	8d 40 04             	lea    0x4(%eax),%eax
f0105973:	89 45 14             	mov    %eax,0x14(%ebp)
f0105976:	eb 10                	jmp    f0105988 <vprintfmt+0x38e>
	else
		return va_arg(*ap, unsigned int);
f0105978:	8b 45 14             	mov    0x14(%ebp),%eax
f010597b:	8b 10                	mov    (%eax),%edx
f010597d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105982:	8d 40 04             	lea    0x4(%eax),%eax
f0105985:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// unsigned decimal
		case 'u':
			num = getuint(&ap, lflag);
			base = 10;
f0105988:	b8 0a 00 00 00       	mov    $0xa,%eax
			goto number;
f010598d:	e9 9d 00 00 00       	jmp    f0105a2f <vprintfmt+0x435>

		// (unsigned) octal
		case 'o':
			// Replace this with your code.
			putch('X', putdat);
f0105992:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105996:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f010599d:	ff d7                	call   *%edi
			putch('X', putdat);
f010599f:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01059a3:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01059aa:	ff d7                	call   *%edi
			putch('X', putdat);
f01059ac:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01059b0:	c7 04 24 58 00 00 00 	movl   $0x58,(%esp)
f01059b7:	ff d7                	call   *%edi
			break;
f01059b9:	e9 52 fc ff ff       	jmp    f0105610 <vprintfmt+0x16>

		// pointer
		case 'p':
			putch('0', putdat);
f01059be:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01059c2:	c7 04 24 30 00 00 00 	movl   $0x30,(%esp)
f01059c9:	ff d7                	call   *%edi
			putch('x', putdat);
f01059cb:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f01059cf:	c7 04 24 78 00 00 00 	movl   $0x78,(%esp)
f01059d6:	ff d7                	call   *%edi
			num = (unsigned long long)
f01059d8:	8b 45 14             	mov    0x14(%ebp),%eax
f01059db:	8b 10                	mov    (%eax),%edx
f01059dd:	b9 00 00 00 00       	mov    $0x0,%ecx
				(uintptr_t) va_arg(ap, void *);
f01059e2:	8d 40 04             	lea    0x4(%eax),%eax
f01059e5:	89 45 14             	mov    %eax,0x14(%ebp)
			base = 16;
f01059e8:	b8 10 00 00 00       	mov    $0x10,%eax
			goto number;
f01059ed:	eb 40                	jmp    f0105a2f <vprintfmt+0x435>
// Get an unsigned int of various possible sizes from a varargs list,
// depending on the lflag parameter.
static unsigned long long
getuint(va_list *ap, int lflag)
{
	if (lflag >= 2)
f01059ef:	83 f9 01             	cmp    $0x1,%ecx
f01059f2:	7e 10                	jle    f0105a04 <vprintfmt+0x40a>
		return va_arg(*ap, unsigned long long);
f01059f4:	8b 45 14             	mov    0x14(%ebp),%eax
f01059f7:	8b 10                	mov    (%eax),%edx
f01059f9:	8b 48 04             	mov    0x4(%eax),%ecx
f01059fc:	8d 40 08             	lea    0x8(%eax),%eax
f01059ff:	89 45 14             	mov    %eax,0x14(%ebp)
f0105a02:	eb 26                	jmp    f0105a2a <vprintfmt+0x430>
	else if (lflag)
f0105a04:	85 c9                	test   %ecx,%ecx
f0105a06:	74 12                	je     f0105a1a <vprintfmt+0x420>
		return va_arg(*ap, unsigned long);
f0105a08:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a0b:	8b 10                	mov    (%eax),%edx
f0105a0d:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105a12:	8d 40 04             	lea    0x4(%eax),%eax
f0105a15:	89 45 14             	mov    %eax,0x14(%ebp)
f0105a18:	eb 10                	jmp    f0105a2a <vprintfmt+0x430>
	else
		return va_arg(*ap, unsigned int);
f0105a1a:	8b 45 14             	mov    0x14(%ebp),%eax
f0105a1d:	8b 10                	mov    (%eax),%edx
f0105a1f:	b9 00 00 00 00       	mov    $0x0,%ecx
f0105a24:	8d 40 04             	lea    0x4(%eax),%eax
f0105a27:	89 45 14             	mov    %eax,0x14(%ebp)
			goto number;

		// (unsigned) hexadecimal
		case 'x':
			num = getuint(&ap, lflag);
			base = 16;
f0105a2a:	b8 10 00 00 00       	mov    $0x10,%eax
		number:
			printnum(putch, putdat, num, base, width, padc);
f0105a2f:	0f be 75 e3          	movsbl -0x1d(%ebp),%esi
f0105a33:	89 74 24 10          	mov    %esi,0x10(%esp)
f0105a37:	8b 75 e4             	mov    -0x1c(%ebp),%esi
f0105a3a:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0105a3e:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105a42:	89 14 24             	mov    %edx,(%esp)
f0105a45:	89 4c 24 04          	mov    %ecx,0x4(%esp)
f0105a49:	89 da                	mov    %ebx,%edx
f0105a4b:	89 f8                	mov    %edi,%eax
f0105a4d:	e8 6e fa ff ff       	call   f01054c0 <printnum>
			break;
f0105a52:	e9 b9 fb ff ff       	jmp    f0105610 <vprintfmt+0x16>

		// escaped '%' character
		case '%':
			putch(ch, putdat);
f0105a57:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105a5b:	89 14 24             	mov    %edx,(%esp)
f0105a5e:	ff d7                	call   *%edi
			break;
f0105a60:	e9 ab fb ff ff       	jmp    f0105610 <vprintfmt+0x16>
			
		// unrecognized escape sequence - just print it literally
		default:
			putch('%', putdat);
f0105a65:	89 5c 24 04          	mov    %ebx,0x4(%esp)
f0105a69:	c7 04 24 25 00 00 00 	movl   $0x25,(%esp)
f0105a70:	ff d7                	call   *%edi
			for (fmt--; fmt[-1] != '%'; fmt--)
f0105a72:	80 7e ff 25          	cmpb   $0x25,-0x1(%esi)
f0105a76:	0f 84 91 fb ff ff    	je     f010560d <vprintfmt+0x13>
f0105a7c:	89 75 10             	mov    %esi,0x10(%ebp)
f0105a7f:	89 f0                	mov    %esi,%eax
f0105a81:	83 e8 01             	sub    $0x1,%eax
f0105a84:	80 78 ff 25          	cmpb   $0x25,-0x1(%eax)
f0105a88:	75 f7                	jne    f0105a81 <vprintfmt+0x487>
f0105a8a:	89 45 10             	mov    %eax,0x10(%ebp)
f0105a8d:	e9 7e fb ff ff       	jmp    f0105610 <vprintfmt+0x16>
				/* do nothing */;
			break;
		}
	}
}
f0105a92:	83 c4 3c             	add    $0x3c,%esp
f0105a95:	5b                   	pop    %ebx
f0105a96:	5e                   	pop    %esi
f0105a97:	5f                   	pop    %edi
f0105a98:	5d                   	pop    %ebp
f0105a99:	c3                   	ret    

f0105a9a <vsnprintf>:
		*b->buf++ = ch;
}

int
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
f0105a9a:	55                   	push   %ebp
f0105a9b:	89 e5                	mov    %esp,%ebp
f0105a9d:	83 ec 28             	sub    $0x28,%esp
f0105aa0:	8b 45 08             	mov    0x8(%ebp),%eax
f0105aa3:	8b 55 0c             	mov    0xc(%ebp),%edx
	struct sprintbuf b = {buf, buf+n-1, 0};
f0105aa6:	89 45 ec             	mov    %eax,-0x14(%ebp)
f0105aa9:	8d 4c 10 ff          	lea    -0x1(%eax,%edx,1),%ecx
f0105aad:	89 4d f0             	mov    %ecx,-0x10(%ebp)
f0105ab0:	c7 45 f4 00 00 00 00 	movl   $0x0,-0xc(%ebp)

	if (buf == NULL || n < 1)
f0105ab7:	85 c0                	test   %eax,%eax
f0105ab9:	74 30                	je     f0105aeb <vsnprintf+0x51>
f0105abb:	85 d2                	test   %edx,%edx
f0105abd:	7e 2c                	jle    f0105aeb <vsnprintf+0x51>
		return -E_INVAL;

	// print the string to the buffer
	vprintfmt((void*)sprintputch, &b, fmt, ap);
f0105abf:	8b 45 14             	mov    0x14(%ebp),%eax
f0105ac2:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105ac6:	8b 45 10             	mov    0x10(%ebp),%eax
f0105ac9:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105acd:	8d 45 ec             	lea    -0x14(%ebp),%eax
f0105ad0:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ad4:	c7 04 24 b5 55 10 f0 	movl   $0xf01055b5,(%esp)
f0105adb:	e8 1a fb ff ff       	call   f01055fa <vprintfmt>

	// null terminate the buffer
	*b.buf = '\0';
f0105ae0:	8b 45 ec             	mov    -0x14(%ebp),%eax
f0105ae3:	c6 00 00             	movb   $0x0,(%eax)

	return b.cnt;
f0105ae6:	8b 45 f4             	mov    -0xc(%ebp),%eax
f0105ae9:	eb 05                	jmp    f0105af0 <vsnprintf+0x56>
vsnprintf(char *buf, int n, const char *fmt, va_list ap)
{
	struct sprintbuf b = {buf, buf+n-1, 0};

	if (buf == NULL || n < 1)
		return -E_INVAL;
f0105aeb:	b8 fd ff ff ff       	mov    $0xfffffffd,%eax

	// null terminate the buffer
	*b.buf = '\0';

	return b.cnt;
}
f0105af0:	c9                   	leave  
f0105af1:	c3                   	ret    

f0105af2 <snprintf>:

int
snprintf(char *buf, int n, const char *fmt, ...)
{
f0105af2:	55                   	push   %ebp
f0105af3:	89 e5                	mov    %esp,%ebp
f0105af5:	83 ec 18             	sub    $0x18,%esp
	va_list ap;
	int rc;

	va_start(ap, fmt);
f0105af8:	8d 45 14             	lea    0x14(%ebp),%eax
	rc = vsnprintf(buf, n, fmt, ap);
f0105afb:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0105aff:	8b 45 10             	mov    0x10(%ebp),%eax
f0105b02:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105b06:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105b09:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105b0d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105b10:	89 04 24             	mov    %eax,(%esp)
f0105b13:	e8 82 ff ff ff       	call   f0105a9a <vsnprintf>
	va_end(ap);

	return rc;
}
f0105b18:	c9                   	leave  
f0105b19:	c3                   	ret    
f0105b1a:	66 90                	xchg   %ax,%ax
f0105b1c:	66 90                	xchg   %ax,%ax
f0105b1e:	66 90                	xchg   %ax,%ax

f0105b20 <readline>:
#define BUFLEN 1024
static char buf[BUFLEN];

char *
readline(const char *prompt)
{
f0105b20:	55                   	push   %ebp
f0105b21:	89 e5                	mov    %esp,%ebp
f0105b23:	57                   	push   %edi
f0105b24:	56                   	push   %esi
f0105b25:	53                   	push   %ebx
f0105b26:	83 ec 1c             	sub    $0x1c,%esp
f0105b29:	8b 45 08             	mov    0x8(%ebp),%eax
	int i, c, echoing;

	if (prompt != NULL)
f0105b2c:	85 c0                	test   %eax,%eax
f0105b2e:	74 10                	je     f0105b40 <readline+0x20>
		cprintf("%s", prompt);
f0105b30:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105b34:	c7 04 24 6e 71 10 f0 	movl   $0xf010716e,(%esp)
f0105b3b:	e8 2f e1 ff ff       	call   f0103c6f <cprintf>

	i = 0;
	echoing = iscons(0);
f0105b40:	c7 04 24 00 00 00 00 	movl   $0x0,(%esp)
f0105b47:	e8 d2 ac ff ff       	call   f010081e <iscons>
f0105b4c:	89 c7                	mov    %eax,%edi
	int i, c, echoing;

	if (prompt != NULL)
		cprintf("%s", prompt);

	i = 0;
f0105b4e:	be 00 00 00 00       	mov    $0x0,%esi
	echoing = iscons(0);
	while (1) {
		c = getchar();
f0105b53:	e8 b5 ac ff ff       	call   f010080d <getchar>
f0105b58:	89 c3                	mov    %eax,%ebx
		if (c < 0) {
f0105b5a:	85 c0                	test   %eax,%eax
f0105b5c:	79 17                	jns    f0105b75 <readline+0x55>
			cprintf("read error: %e\n", c);
f0105b5e:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105b62:	c7 04 24 7f 84 10 f0 	movl   $0xf010847f,(%esp)
f0105b69:	e8 01 e1 ff ff       	call   f0103c6f <cprintf>
			return NULL;
f0105b6e:	b8 00 00 00 00       	mov    $0x0,%eax
f0105b73:	eb 6d                	jmp    f0105be2 <readline+0xc2>
		} else if ((c == '\b' || c == '\x7f') && i > 0) {
f0105b75:	83 f8 7f             	cmp    $0x7f,%eax
f0105b78:	74 05                	je     f0105b7f <readline+0x5f>
f0105b7a:	83 f8 08             	cmp    $0x8,%eax
f0105b7d:	75 19                	jne    f0105b98 <readline+0x78>
f0105b7f:	85 f6                	test   %esi,%esi
f0105b81:	7e 15                	jle    f0105b98 <readline+0x78>
			if (echoing)
f0105b83:	85 ff                	test   %edi,%edi
f0105b85:	74 0c                	je     f0105b93 <readline+0x73>
				cputchar('\b');
f0105b87:	c7 04 24 08 00 00 00 	movl   $0x8,(%esp)
f0105b8e:	e8 6a ac ff ff       	call   f01007fd <cputchar>
			i--;
f0105b93:	83 ee 01             	sub    $0x1,%esi
f0105b96:	eb bb                	jmp    f0105b53 <readline+0x33>
		} else if (c >= ' ' && i < BUFLEN-1) {
f0105b98:	81 fe fe 03 00 00    	cmp    $0x3fe,%esi
f0105b9e:	7f 1c                	jg     f0105bbc <readline+0x9c>
f0105ba0:	83 fb 1f             	cmp    $0x1f,%ebx
f0105ba3:	7e 17                	jle    f0105bbc <readline+0x9c>
			if (echoing)
f0105ba5:	85 ff                	test   %edi,%edi
f0105ba7:	74 08                	je     f0105bb1 <readline+0x91>
				cputchar(c);
f0105ba9:	89 1c 24             	mov    %ebx,(%esp)
f0105bac:	e8 4c ac ff ff       	call   f01007fd <cputchar>
			buf[i++] = c;
f0105bb1:	88 9e 80 ca 1c f0    	mov    %bl,-0xfe33580(%esi)
f0105bb7:	8d 76 01             	lea    0x1(%esi),%esi
f0105bba:	eb 97                	jmp    f0105b53 <readline+0x33>
		} else if (c == '\n' || c == '\r') {
f0105bbc:	83 fb 0d             	cmp    $0xd,%ebx
f0105bbf:	74 05                	je     f0105bc6 <readline+0xa6>
f0105bc1:	83 fb 0a             	cmp    $0xa,%ebx
f0105bc4:	75 8d                	jne    f0105b53 <readline+0x33>
			if (echoing)
f0105bc6:	85 ff                	test   %edi,%edi
f0105bc8:	74 0c                	je     f0105bd6 <readline+0xb6>
				cputchar('\n');
f0105bca:	c7 04 24 0a 00 00 00 	movl   $0xa,(%esp)
f0105bd1:	e8 27 ac ff ff       	call   f01007fd <cputchar>
			buf[i] = 0;
f0105bd6:	c6 86 80 ca 1c f0 00 	movb   $0x0,-0xfe33580(%esi)
			return buf;
f0105bdd:	b8 80 ca 1c f0       	mov    $0xf01cca80,%eax
		}
	}
}
f0105be2:	83 c4 1c             	add    $0x1c,%esp
f0105be5:	5b                   	pop    %ebx
f0105be6:	5e                   	pop    %esi
f0105be7:	5f                   	pop    %edi
f0105be8:	5d                   	pop    %ebp
f0105be9:	c3                   	ret    
f0105bea:	66 90                	xchg   %ax,%ax
f0105bec:	66 90                	xchg   %ax,%ax
f0105bee:	66 90                	xchg   %ax,%ax

f0105bf0 <strlen>:
// Primespipe runs 3x faster this way.
#define ASM 1

int
strlen(const char *s)
{
f0105bf0:	55                   	push   %ebp
f0105bf1:	89 e5                	mov    %esp,%ebp
f0105bf3:	8b 55 08             	mov    0x8(%ebp),%edx
	int n;

	for (n = 0; *s != '\0'; s++)
f0105bf6:	80 3a 00             	cmpb   $0x0,(%edx)
f0105bf9:	74 10                	je     f0105c0b <strlen+0x1b>
f0105bfb:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
f0105c00:	83 c0 01             	add    $0x1,%eax
int
strlen(const char *s)
{
	int n;

	for (n = 0; *s != '\0'; s++)
f0105c03:	80 3c 02 00          	cmpb   $0x0,(%edx,%eax,1)
f0105c07:	75 f7                	jne    f0105c00 <strlen+0x10>
f0105c09:	eb 05                	jmp    f0105c10 <strlen+0x20>
f0105c0b:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105c10:	5d                   	pop    %ebp
f0105c11:	c3                   	ret    

f0105c12 <strnlen>:

int
strnlen(const char *s, size_t size)
{
f0105c12:	55                   	push   %ebp
f0105c13:	89 e5                	mov    %esp,%ebp
f0105c15:	53                   	push   %ebx
f0105c16:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105c19:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105c1c:	85 c9                	test   %ecx,%ecx
f0105c1e:	74 1c                	je     f0105c3c <strnlen+0x2a>
f0105c20:	80 3b 00             	cmpb   $0x0,(%ebx)
f0105c23:	74 1e                	je     f0105c43 <strnlen+0x31>
f0105c25:	ba 01 00 00 00       	mov    $0x1,%edx
		n++;
f0105c2a:	89 d0                	mov    %edx,%eax
int
strnlen(const char *s, size_t size)
{
	int n;

	for (n = 0; size > 0 && *s != '\0'; s++, size--)
f0105c2c:	39 ca                	cmp    %ecx,%edx
f0105c2e:	74 18                	je     f0105c48 <strnlen+0x36>
f0105c30:	83 c2 01             	add    $0x1,%edx
f0105c33:	80 7c 13 ff 00       	cmpb   $0x0,-0x1(%ebx,%edx,1)
f0105c38:	75 f0                	jne    f0105c2a <strnlen+0x18>
f0105c3a:	eb 0c                	jmp    f0105c48 <strnlen+0x36>
f0105c3c:	b8 00 00 00 00       	mov    $0x0,%eax
f0105c41:	eb 05                	jmp    f0105c48 <strnlen+0x36>
f0105c43:	b8 00 00 00 00       	mov    $0x0,%eax
		n++;
	return n;
}
f0105c48:	5b                   	pop    %ebx
f0105c49:	5d                   	pop    %ebp
f0105c4a:	c3                   	ret    

f0105c4b <strcpy>:

char *
strcpy(char *dst, const char *src)
{
f0105c4b:	55                   	push   %ebp
f0105c4c:	89 e5                	mov    %esp,%ebp
f0105c4e:	53                   	push   %ebx
f0105c4f:	8b 45 08             	mov    0x8(%ebp),%eax
f0105c52:	8b 4d 0c             	mov    0xc(%ebp),%ecx
	char *ret;

	ret = dst;
	while ((*dst++ = *src++) != '\0')
f0105c55:	89 c2                	mov    %eax,%edx
f0105c57:	83 c2 01             	add    $0x1,%edx
f0105c5a:	83 c1 01             	add    $0x1,%ecx
f0105c5d:	0f b6 59 ff          	movzbl -0x1(%ecx),%ebx
f0105c61:	88 5a ff             	mov    %bl,-0x1(%edx)
f0105c64:	84 db                	test   %bl,%bl
f0105c66:	75 ef                	jne    f0105c57 <strcpy+0xc>
		/* do nothing */;
	return ret;
}
f0105c68:	5b                   	pop    %ebx
f0105c69:	5d                   	pop    %ebp
f0105c6a:	c3                   	ret    

f0105c6b <strcat>:

char *
strcat(char *dst, const char *src)
{
f0105c6b:	55                   	push   %ebp
f0105c6c:	89 e5                	mov    %esp,%ebp
f0105c6e:	53                   	push   %ebx
f0105c6f:	83 ec 08             	sub    $0x8,%esp
f0105c72:	8b 5d 08             	mov    0x8(%ebp),%ebx
	int len = strlen(dst);
f0105c75:	89 1c 24             	mov    %ebx,(%esp)
f0105c78:	e8 73 ff ff ff       	call   f0105bf0 <strlen>
	strcpy(dst + len, src);
f0105c7d:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105c80:	89 54 24 04          	mov    %edx,0x4(%esp)
f0105c84:	01 d8                	add    %ebx,%eax
f0105c86:	89 04 24             	mov    %eax,(%esp)
f0105c89:	e8 bd ff ff ff       	call   f0105c4b <strcpy>
	return dst;
}
f0105c8e:	89 d8                	mov    %ebx,%eax
f0105c90:	83 c4 08             	add    $0x8,%esp
f0105c93:	5b                   	pop    %ebx
f0105c94:	5d                   	pop    %ebp
f0105c95:	c3                   	ret    

f0105c96 <strncpy>:

char *
strncpy(char *dst, const char *src, size_t size) {
f0105c96:	55                   	push   %ebp
f0105c97:	89 e5                	mov    %esp,%ebp
f0105c99:	56                   	push   %esi
f0105c9a:	53                   	push   %ebx
f0105c9b:	8b 75 08             	mov    0x8(%ebp),%esi
f0105c9e:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105ca1:	8b 5d 10             	mov    0x10(%ebp),%ebx
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105ca4:	85 db                	test   %ebx,%ebx
f0105ca6:	74 17                	je     f0105cbf <strncpy+0x29>
f0105ca8:	01 f3                	add    %esi,%ebx
f0105caa:	89 f1                	mov    %esi,%ecx
		*dst++ = *src;
f0105cac:	83 c1 01             	add    $0x1,%ecx
f0105caf:	0f b6 02             	movzbl (%edx),%eax
f0105cb2:	88 41 ff             	mov    %al,-0x1(%ecx)
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
f0105cb5:	80 3a 01             	cmpb   $0x1,(%edx)
f0105cb8:	83 da ff             	sbb    $0xffffffff,%edx
strncpy(char *dst, const char *src, size_t size) {
	size_t i;
	char *ret;

	ret = dst;
	for (i = 0; i < size; i++) {
f0105cbb:	39 d9                	cmp    %ebx,%ecx
f0105cbd:	75 ed                	jne    f0105cac <strncpy+0x16>
		// If strlen(src) < size, null-pad 'dst' out to 'size' chars
		if (*src != '\0')
			src++;
	}
	return ret;
}
f0105cbf:	89 f0                	mov    %esi,%eax
f0105cc1:	5b                   	pop    %ebx
f0105cc2:	5e                   	pop    %esi
f0105cc3:	5d                   	pop    %ebp
f0105cc4:	c3                   	ret    

f0105cc5 <strlcpy>:

size_t
strlcpy(char *dst, const char *src, size_t size)
{
f0105cc5:	55                   	push   %ebp
f0105cc6:	89 e5                	mov    %esp,%ebp
f0105cc8:	57                   	push   %edi
f0105cc9:	56                   	push   %esi
f0105cca:	53                   	push   %ebx
f0105ccb:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105cce:	8b 5d 0c             	mov    0xc(%ebp),%ebx
f0105cd1:	8b 75 10             	mov    0x10(%ebp),%esi
f0105cd4:	89 f8                	mov    %edi,%eax
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
f0105cd6:	85 f6                	test   %esi,%esi
f0105cd8:	74 34                	je     f0105d0e <strlcpy+0x49>
		while (--size > 0 && *src != '\0')
f0105cda:	83 fe 01             	cmp    $0x1,%esi
f0105cdd:	74 26                	je     f0105d05 <strlcpy+0x40>
f0105cdf:	0f b6 0b             	movzbl (%ebx),%ecx
f0105ce2:	84 c9                	test   %cl,%cl
f0105ce4:	74 23                	je     f0105d09 <strlcpy+0x44>
f0105ce6:	83 ee 02             	sub    $0x2,%esi
f0105ce9:	ba 00 00 00 00       	mov    $0x0,%edx
			*dst++ = *src++;
f0105cee:	83 c0 01             	add    $0x1,%eax
f0105cf1:	88 48 ff             	mov    %cl,-0x1(%eax)
{
	char *dst_in;

	dst_in = dst;
	if (size > 0) {
		while (--size > 0 && *src != '\0')
f0105cf4:	39 f2                	cmp    %esi,%edx
f0105cf6:	74 13                	je     f0105d0b <strlcpy+0x46>
f0105cf8:	83 c2 01             	add    $0x1,%edx
f0105cfb:	0f b6 0c 13          	movzbl (%ebx,%edx,1),%ecx
f0105cff:	84 c9                	test   %cl,%cl
f0105d01:	75 eb                	jne    f0105cee <strlcpy+0x29>
f0105d03:	eb 06                	jmp    f0105d0b <strlcpy+0x46>
f0105d05:	89 f8                	mov    %edi,%eax
f0105d07:	eb 02                	jmp    f0105d0b <strlcpy+0x46>
f0105d09:	89 f8                	mov    %edi,%eax
			*dst++ = *src++;
		*dst = '\0';
f0105d0b:	c6 00 00             	movb   $0x0,(%eax)
	}
	return dst - dst_in;
f0105d0e:	29 f8                	sub    %edi,%eax
}
f0105d10:	5b                   	pop    %ebx
f0105d11:	5e                   	pop    %esi
f0105d12:	5f                   	pop    %edi
f0105d13:	5d                   	pop    %ebp
f0105d14:	c3                   	ret    

f0105d15 <strcmp>:

int
strcmp(const char *p, const char *q)
{
f0105d15:	55                   	push   %ebp
f0105d16:	89 e5                	mov    %esp,%ebp
f0105d18:	8b 4d 08             	mov    0x8(%ebp),%ecx
f0105d1b:	8b 55 0c             	mov    0xc(%ebp),%edx
	while (*p && *p == *q)
f0105d1e:	0f b6 01             	movzbl (%ecx),%eax
f0105d21:	84 c0                	test   %al,%al
f0105d23:	74 15                	je     f0105d3a <strcmp+0x25>
f0105d25:	3a 02                	cmp    (%edx),%al
f0105d27:	75 11                	jne    f0105d3a <strcmp+0x25>
		p++, q++;
f0105d29:	83 c1 01             	add    $0x1,%ecx
f0105d2c:	83 c2 01             	add    $0x1,%edx
}

int
strcmp(const char *p, const char *q)
{
	while (*p && *p == *q)
f0105d2f:	0f b6 01             	movzbl (%ecx),%eax
f0105d32:	84 c0                	test   %al,%al
f0105d34:	74 04                	je     f0105d3a <strcmp+0x25>
f0105d36:	3a 02                	cmp    (%edx),%al
f0105d38:	74 ef                	je     f0105d29 <strcmp+0x14>
		p++, q++;
	return (int) ((unsigned char) *p - (unsigned char) *q);
f0105d3a:	0f b6 c0             	movzbl %al,%eax
f0105d3d:	0f b6 12             	movzbl (%edx),%edx
f0105d40:	29 d0                	sub    %edx,%eax
}
f0105d42:	5d                   	pop    %ebp
f0105d43:	c3                   	ret    

f0105d44 <strncmp>:

int
strncmp(const char *p, const char *q, size_t n)
{
f0105d44:	55                   	push   %ebp
f0105d45:	89 e5                	mov    %esp,%ebp
f0105d47:	56                   	push   %esi
f0105d48:	53                   	push   %ebx
f0105d49:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105d4c:	8b 55 0c             	mov    0xc(%ebp),%edx
f0105d4f:	8b 75 10             	mov    0x10(%ebp),%esi
	while (n > 0 && *p && *p == *q)
f0105d52:	85 f6                	test   %esi,%esi
f0105d54:	74 29                	je     f0105d7f <strncmp+0x3b>
f0105d56:	0f b6 03             	movzbl (%ebx),%eax
f0105d59:	84 c0                	test   %al,%al
f0105d5b:	74 30                	je     f0105d8d <strncmp+0x49>
f0105d5d:	3a 02                	cmp    (%edx),%al
f0105d5f:	75 2c                	jne    f0105d8d <strncmp+0x49>
f0105d61:	8d 43 01             	lea    0x1(%ebx),%eax
f0105d64:	01 de                	add    %ebx,%esi
		n--, p++, q++;
f0105d66:	89 c3                	mov    %eax,%ebx
f0105d68:	83 c2 01             	add    $0x1,%edx
}

int
strncmp(const char *p, const char *q, size_t n)
{
	while (n > 0 && *p && *p == *q)
f0105d6b:	39 f0                	cmp    %esi,%eax
f0105d6d:	74 17                	je     f0105d86 <strncmp+0x42>
f0105d6f:	0f b6 08             	movzbl (%eax),%ecx
f0105d72:	84 c9                	test   %cl,%cl
f0105d74:	74 17                	je     f0105d8d <strncmp+0x49>
f0105d76:	83 c0 01             	add    $0x1,%eax
f0105d79:	3a 0a                	cmp    (%edx),%cl
f0105d7b:	74 e9                	je     f0105d66 <strncmp+0x22>
f0105d7d:	eb 0e                	jmp    f0105d8d <strncmp+0x49>
		n--, p++, q++;
	if (n == 0)
		return 0;
f0105d7f:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d84:	eb 0f                	jmp    f0105d95 <strncmp+0x51>
f0105d86:	b8 00 00 00 00       	mov    $0x0,%eax
f0105d8b:	eb 08                	jmp    f0105d95 <strncmp+0x51>
	else
		return (int) ((unsigned char) *p - (unsigned char) *q);
f0105d8d:	0f b6 03             	movzbl (%ebx),%eax
f0105d90:	0f b6 12             	movzbl (%edx),%edx
f0105d93:	29 d0                	sub    %edx,%eax
}
f0105d95:	5b                   	pop    %ebx
f0105d96:	5e                   	pop    %esi
f0105d97:	5d                   	pop    %ebp
f0105d98:	c3                   	ret    

f0105d99 <strchr>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
f0105d99:	55                   	push   %ebp
f0105d9a:	89 e5                	mov    %esp,%ebp
f0105d9c:	53                   	push   %ebx
f0105d9d:	8b 45 08             	mov    0x8(%ebp),%eax
f0105da0:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105da3:	0f b6 18             	movzbl (%eax),%ebx
f0105da6:	84 db                	test   %bl,%bl
f0105da8:	74 1d                	je     f0105dc7 <strchr+0x2e>
f0105daa:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105dac:	38 d3                	cmp    %dl,%bl
f0105dae:	75 06                	jne    f0105db6 <strchr+0x1d>
f0105db0:	eb 1a                	jmp    f0105dcc <strchr+0x33>
f0105db2:	38 ca                	cmp    %cl,%dl
f0105db4:	74 16                	je     f0105dcc <strchr+0x33>
// Return a pointer to the first occurrence of 'c' in 's',
// or a null pointer if the string has no 'c'.
char *
strchr(const char *s, char c)
{
	for (; *s; s++)
f0105db6:	83 c0 01             	add    $0x1,%eax
f0105db9:	0f b6 10             	movzbl (%eax),%edx
f0105dbc:	84 d2                	test   %dl,%dl
f0105dbe:	75 f2                	jne    f0105db2 <strchr+0x19>
		if (*s == c)
			return (char *) s;
	return 0;
f0105dc0:	b8 00 00 00 00       	mov    $0x0,%eax
f0105dc5:	eb 05                	jmp    f0105dcc <strchr+0x33>
f0105dc7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105dcc:	5b                   	pop    %ebx
f0105dcd:	5d                   	pop    %ebp
f0105dce:	c3                   	ret    

f0105dcf <strfind>:

// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
f0105dcf:	55                   	push   %ebp
f0105dd0:	89 e5                	mov    %esp,%ebp
f0105dd2:	53                   	push   %ebx
f0105dd3:	8b 45 08             	mov    0x8(%ebp),%eax
f0105dd6:	8b 55 0c             	mov    0xc(%ebp),%edx
	for (; *s; s++)
f0105dd9:	0f b6 18             	movzbl (%eax),%ebx
f0105ddc:	84 db                	test   %bl,%bl
f0105dde:	74 16                	je     f0105df6 <strfind+0x27>
f0105de0:	89 d1                	mov    %edx,%ecx
		if (*s == c)
f0105de2:	38 d3                	cmp    %dl,%bl
f0105de4:	75 06                	jne    f0105dec <strfind+0x1d>
f0105de6:	eb 0e                	jmp    f0105df6 <strfind+0x27>
f0105de8:	38 ca                	cmp    %cl,%dl
f0105dea:	74 0a                	je     f0105df6 <strfind+0x27>
// Return a pointer to the first occurrence of 'c' in 's',
// or a pointer to the string-ending null character if the string has no 'c'.
char *
strfind(const char *s, char c)
{
	for (; *s; s++)
f0105dec:	83 c0 01             	add    $0x1,%eax
f0105def:	0f b6 10             	movzbl (%eax),%edx
f0105df2:	84 d2                	test   %dl,%dl
f0105df4:	75 f2                	jne    f0105de8 <strfind+0x19>
		if (*s == c)
			break;
	return (char *) s;
}
f0105df6:	5b                   	pop    %ebx
f0105df7:	5d                   	pop    %ebp
f0105df8:	c3                   	ret    

f0105df9 <memset>:

#if ASM
void *
memset(void *v, int c, size_t n)
{
f0105df9:	55                   	push   %ebp
f0105dfa:	89 e5                	mov    %esp,%ebp
f0105dfc:	57                   	push   %edi
f0105dfd:	56                   	push   %esi
f0105dfe:	53                   	push   %ebx
f0105dff:	8b 7d 08             	mov    0x8(%ebp),%edi
f0105e02:	8b 4d 10             	mov    0x10(%ebp),%ecx
	char *p;

	if (n == 0)
f0105e05:	85 c9                	test   %ecx,%ecx
f0105e07:	74 36                	je     f0105e3f <memset+0x46>
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
f0105e09:	f7 c7 03 00 00 00    	test   $0x3,%edi
f0105e0f:	75 28                	jne    f0105e39 <memset+0x40>
f0105e11:	f6 c1 03             	test   $0x3,%cl
f0105e14:	75 23                	jne    f0105e39 <memset+0x40>
		c &= 0xFF;
f0105e16:	0f b6 55 0c          	movzbl 0xc(%ebp),%edx
		c = (c<<24)|(c<<16)|(c<<8)|c;
f0105e1a:	89 d3                	mov    %edx,%ebx
f0105e1c:	c1 e3 08             	shl    $0x8,%ebx
f0105e1f:	89 d6                	mov    %edx,%esi
f0105e21:	c1 e6 18             	shl    $0x18,%esi
f0105e24:	89 d0                	mov    %edx,%eax
f0105e26:	c1 e0 10             	shl    $0x10,%eax
f0105e29:	09 f0                	or     %esi,%eax
f0105e2b:	09 c2                	or     %eax,%edx
f0105e2d:	89 d0                	mov    %edx,%eax
f0105e2f:	09 d8                	or     %ebx,%eax
		asm volatile("cld; rep stosl\n"
			:: "D" (v), "a" (c), "c" (n/4)
f0105e31:	c1 e9 02             	shr    $0x2,%ecx
	if (n == 0)
		return v;
	if ((int)v%4 == 0 && n%4 == 0) {
		c &= 0xFF;
		c = (c<<24)|(c<<16)|(c<<8)|c;
		asm volatile("cld; rep stosl\n"
f0105e34:	fc                   	cld    
f0105e35:	f3 ab                	rep stos %eax,%es:(%edi)
f0105e37:	eb 06                	jmp    f0105e3f <memset+0x46>
			:: "D" (v), "a" (c), "c" (n/4)
			: "cc", "memory");
	} else
		asm volatile("cld; rep stosb\n"
f0105e39:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105e3c:	fc                   	cld    
f0105e3d:	f3 aa                	rep stos %al,%es:(%edi)
			:: "D" (v), "a" (c), "c" (n)
			: "cc", "memory");
	return v;
}
f0105e3f:	89 f8                	mov    %edi,%eax
f0105e41:	5b                   	pop    %ebx
f0105e42:	5e                   	pop    %esi
f0105e43:	5f                   	pop    %edi
f0105e44:	5d                   	pop    %ebp
f0105e45:	c3                   	ret    

f0105e46 <memmove>:

void *
memmove(void *dst, const void *src, size_t n)
{
f0105e46:	55                   	push   %ebp
f0105e47:	89 e5                	mov    %esp,%ebp
f0105e49:	57                   	push   %edi
f0105e4a:	56                   	push   %esi
f0105e4b:	8b 45 08             	mov    0x8(%ebp),%eax
f0105e4e:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105e51:	8b 4d 10             	mov    0x10(%ebp),%ecx
	const char *s;
	char *d;
	
	s = src;
	d = dst;
	if (s < d && s + n > d) {
f0105e54:	39 c6                	cmp    %eax,%esi
f0105e56:	73 35                	jae    f0105e8d <memmove+0x47>
f0105e58:	8d 14 0e             	lea    (%esi,%ecx,1),%edx
f0105e5b:	39 d0                	cmp    %edx,%eax
f0105e5d:	73 2e                	jae    f0105e8d <memmove+0x47>
		s += n;
		d += n;
f0105e5f:	8d 3c 08             	lea    (%eax,%ecx,1),%edi
f0105e62:	89 d6                	mov    %edx,%esi
f0105e64:	09 fe                	or     %edi,%esi
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105e66:	f7 c6 03 00 00 00    	test   $0x3,%esi
f0105e6c:	75 13                	jne    f0105e81 <memmove+0x3b>
f0105e6e:	f6 c1 03             	test   $0x3,%cl
f0105e71:	75 0e                	jne    f0105e81 <memmove+0x3b>
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
f0105e73:	83 ef 04             	sub    $0x4,%edi
f0105e76:	8d 72 fc             	lea    -0x4(%edx),%esi
f0105e79:	c1 e9 02             	shr    $0x2,%ecx
	d = dst;
	if (s < d && s + n > d) {
		s += n;
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
f0105e7c:	fd                   	std    
f0105e7d:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105e7f:	eb 09                	jmp    f0105e8a <memmove+0x44>
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
f0105e81:	83 ef 01             	sub    $0x1,%edi
f0105e84:	8d 72 ff             	lea    -0x1(%edx),%esi
		d += n;
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("std; rep movsl\n"
				:: "D" (d-4), "S" (s-4), "c" (n/4) : "cc", "memory");
		else
			asm volatile("std; rep movsb\n"
f0105e87:	fd                   	std    
f0105e88:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
f0105e8a:	fc                   	cld    
f0105e8b:	eb 1d                	jmp    f0105eaa <memmove+0x64>
f0105e8d:	89 f2                	mov    %esi,%edx
f0105e8f:	09 c2                	or     %eax,%edx
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
f0105e91:	f6 c2 03             	test   $0x3,%dl
f0105e94:	75 0f                	jne    f0105ea5 <memmove+0x5f>
f0105e96:	f6 c1 03             	test   $0x3,%cl
f0105e99:	75 0a                	jne    f0105ea5 <memmove+0x5f>
			asm volatile("cld; rep movsl\n"
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
f0105e9b:	c1 e9 02             	shr    $0x2,%ecx
				:: "D" (d-1), "S" (s-1), "c" (n) : "cc", "memory");
		// Some versions of GCC rely on DF being clear
		asm volatile("cld" ::: "cc");
	} else {
		if ((int)s%4 == 0 && (int)d%4 == 0 && n%4 == 0)
			asm volatile("cld; rep movsl\n"
f0105e9e:	89 c7                	mov    %eax,%edi
f0105ea0:	fc                   	cld    
f0105ea1:	f3 a5                	rep movsl %ds:(%esi),%es:(%edi)
f0105ea3:	eb 05                	jmp    f0105eaa <memmove+0x64>
				:: "D" (d), "S" (s), "c" (n/4) : "cc", "memory");
		else
			asm volatile("cld; rep movsb\n"
f0105ea5:	89 c7                	mov    %eax,%edi
f0105ea7:	fc                   	cld    
f0105ea8:	f3 a4                	rep movsb %ds:(%esi),%es:(%edi)
				:: "D" (d), "S" (s), "c" (n) : "cc", "memory");
	}
	return dst;
}
f0105eaa:	5e                   	pop    %esi
f0105eab:	5f                   	pop    %edi
f0105eac:	5d                   	pop    %ebp
f0105ead:	c3                   	ret    

f0105eae <memcpy>:

/* sigh - gcc emits references to this for structure assignments! */
/* it is *not* prototyped in inc/string.h - do not use directly. */
void *
memcpy(void *dst, void *src, size_t n)
{
f0105eae:	55                   	push   %ebp
f0105eaf:	89 e5                	mov    %esp,%ebp
f0105eb1:	83 ec 0c             	sub    $0xc,%esp
	return memmove(dst, src, n);
f0105eb4:	8b 45 10             	mov    0x10(%ebp),%eax
f0105eb7:	89 44 24 08          	mov    %eax,0x8(%esp)
f0105ebb:	8b 45 0c             	mov    0xc(%ebp),%eax
f0105ebe:	89 44 24 04          	mov    %eax,0x4(%esp)
f0105ec2:	8b 45 08             	mov    0x8(%ebp),%eax
f0105ec5:	89 04 24             	mov    %eax,(%esp)
f0105ec8:	e8 79 ff ff ff       	call   f0105e46 <memmove>
}
f0105ecd:	c9                   	leave  
f0105ece:	c3                   	ret    

f0105ecf <memcmp>:

int
memcmp(const void *v1, const void *v2, size_t n)
{
f0105ecf:	55                   	push   %ebp
f0105ed0:	89 e5                	mov    %esp,%ebp
f0105ed2:	57                   	push   %edi
f0105ed3:	56                   	push   %esi
f0105ed4:	53                   	push   %ebx
f0105ed5:	8b 5d 08             	mov    0x8(%ebp),%ebx
f0105ed8:	8b 75 0c             	mov    0xc(%ebp),%esi
f0105edb:	8b 45 10             	mov    0x10(%ebp),%eax
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105ede:	8d 78 ff             	lea    -0x1(%eax),%edi
f0105ee1:	85 c0                	test   %eax,%eax
f0105ee3:	74 36                	je     f0105f1b <memcmp+0x4c>
		if (*s1 != *s2)
f0105ee5:	0f b6 03             	movzbl (%ebx),%eax
f0105ee8:	0f b6 0e             	movzbl (%esi),%ecx
f0105eeb:	ba 00 00 00 00       	mov    $0x0,%edx
f0105ef0:	38 c8                	cmp    %cl,%al
f0105ef2:	74 1c                	je     f0105f10 <memcmp+0x41>
f0105ef4:	eb 10                	jmp    f0105f06 <memcmp+0x37>
f0105ef6:	0f b6 44 13 01       	movzbl 0x1(%ebx,%edx,1),%eax
f0105efb:	83 c2 01             	add    $0x1,%edx
f0105efe:	0f b6 0c 16          	movzbl (%esi,%edx,1),%ecx
f0105f02:	38 c8                	cmp    %cl,%al
f0105f04:	74 0a                	je     f0105f10 <memcmp+0x41>
			return (int) *s1 - (int) *s2;
f0105f06:	0f b6 c0             	movzbl %al,%eax
f0105f09:	0f b6 c9             	movzbl %cl,%ecx
f0105f0c:	29 c8                	sub    %ecx,%eax
f0105f0e:	eb 10                	jmp    f0105f20 <memcmp+0x51>
memcmp(const void *v1, const void *v2, size_t n)
{
	const uint8_t *s1 = (const uint8_t *) v1;
	const uint8_t *s2 = (const uint8_t *) v2;

	while (n-- > 0) {
f0105f10:	39 fa                	cmp    %edi,%edx
f0105f12:	75 e2                	jne    f0105ef6 <memcmp+0x27>
		if (*s1 != *s2)
			return (int) *s1 - (int) *s2;
		s1++, s2++;
	}

	return 0;
f0105f14:	b8 00 00 00 00       	mov    $0x0,%eax
f0105f19:	eb 05                	jmp    f0105f20 <memcmp+0x51>
f0105f1b:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0105f20:	5b                   	pop    %ebx
f0105f21:	5e                   	pop    %esi
f0105f22:	5f                   	pop    %edi
f0105f23:	5d                   	pop    %ebp
f0105f24:	c3                   	ret    

f0105f25 <memfind>:

void *
memfind(const void *s, int c, size_t n)
{
f0105f25:	55                   	push   %ebp
f0105f26:	89 e5                	mov    %esp,%ebp
f0105f28:	53                   	push   %ebx
f0105f29:	8b 45 08             	mov    0x8(%ebp),%eax
f0105f2c:	8b 5d 0c             	mov    0xc(%ebp),%ebx
	const void *ends = (const char *) s + n;
f0105f2f:	89 c2                	mov    %eax,%edx
f0105f31:	03 55 10             	add    0x10(%ebp),%edx
	for (; s < ends; s++)
f0105f34:	39 d0                	cmp    %edx,%eax
f0105f36:	73 13                	jae    f0105f4b <memfind+0x26>
		if (*(const unsigned char *) s == (unsigned char) c)
f0105f38:	89 d9                	mov    %ebx,%ecx
f0105f3a:	38 18                	cmp    %bl,(%eax)
f0105f3c:	75 06                	jne    f0105f44 <memfind+0x1f>
f0105f3e:	eb 0b                	jmp    f0105f4b <memfind+0x26>
f0105f40:	38 08                	cmp    %cl,(%eax)
f0105f42:	74 07                	je     f0105f4b <memfind+0x26>

void *
memfind(const void *s, int c, size_t n)
{
	const void *ends = (const char *) s + n;
	for (; s < ends; s++)
f0105f44:	83 c0 01             	add    $0x1,%eax
f0105f47:	39 d0                	cmp    %edx,%eax
f0105f49:	75 f5                	jne    f0105f40 <memfind+0x1b>
		if (*(const unsigned char *) s == (unsigned char) c)
			break;
	return (void *) s;
}
f0105f4b:	5b                   	pop    %ebx
f0105f4c:	5d                   	pop    %ebp
f0105f4d:	c3                   	ret    

f0105f4e <strtol>:

long
strtol(const char *s, char **endptr, int base)
{
f0105f4e:	55                   	push   %ebp
f0105f4f:	89 e5                	mov    %esp,%ebp
f0105f51:	57                   	push   %edi
f0105f52:	56                   	push   %esi
f0105f53:	53                   	push   %ebx
f0105f54:	8b 55 08             	mov    0x8(%ebp),%edx
f0105f57:	8b 45 10             	mov    0x10(%ebp),%eax
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105f5a:	0f b6 0a             	movzbl (%edx),%ecx
f0105f5d:	80 f9 09             	cmp    $0x9,%cl
f0105f60:	74 05                	je     f0105f67 <strtol+0x19>
f0105f62:	80 f9 20             	cmp    $0x20,%cl
f0105f65:	75 10                	jne    f0105f77 <strtol+0x29>
		s++;
f0105f67:	83 c2 01             	add    $0x1,%edx
{
	int neg = 0;
	long val = 0;

	// gobble initial whitespace
	while (*s == ' ' || *s == '\t')
f0105f6a:	0f b6 0a             	movzbl (%edx),%ecx
f0105f6d:	80 f9 09             	cmp    $0x9,%cl
f0105f70:	74 f5                	je     f0105f67 <strtol+0x19>
f0105f72:	80 f9 20             	cmp    $0x20,%cl
f0105f75:	74 f0                	je     f0105f67 <strtol+0x19>
		s++;

	// plus/minus sign
	if (*s == '+')
f0105f77:	80 f9 2b             	cmp    $0x2b,%cl
f0105f7a:	75 0a                	jne    f0105f86 <strtol+0x38>
		s++;
f0105f7c:	83 c2 01             	add    $0x1,%edx
}

long
strtol(const char *s, char **endptr, int base)
{
	int neg = 0;
f0105f7f:	bf 00 00 00 00       	mov    $0x0,%edi
f0105f84:	eb 11                	jmp    f0105f97 <strtol+0x49>
f0105f86:	bf 00 00 00 00       	mov    $0x0,%edi
		s++;

	// plus/minus sign
	if (*s == '+')
		s++;
	else if (*s == '-')
f0105f8b:	80 f9 2d             	cmp    $0x2d,%cl
f0105f8e:	75 07                	jne    f0105f97 <strtol+0x49>
		s++, neg = 1;
f0105f90:	83 c2 01             	add    $0x1,%edx
f0105f93:	66 bf 01 00          	mov    $0x1,%di

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
f0105f97:	a9 ef ff ff ff       	test   $0xffffffef,%eax
f0105f9c:	75 15                	jne    f0105fb3 <strtol+0x65>
f0105f9e:	80 3a 30             	cmpb   $0x30,(%edx)
f0105fa1:	75 10                	jne    f0105fb3 <strtol+0x65>
f0105fa3:	80 7a 01 78          	cmpb   $0x78,0x1(%edx)
f0105fa7:	75 0a                	jne    f0105fb3 <strtol+0x65>
		s += 2, base = 16;
f0105fa9:	83 c2 02             	add    $0x2,%edx
f0105fac:	b8 10 00 00 00       	mov    $0x10,%eax
f0105fb1:	eb 10                	jmp    f0105fc3 <strtol+0x75>
	else if (base == 0 && s[0] == '0')
f0105fb3:	85 c0                	test   %eax,%eax
f0105fb5:	75 0c                	jne    f0105fc3 <strtol+0x75>
		s++, base = 8;
	else if (base == 0)
		base = 10;
f0105fb7:	b0 0a                	mov    $0xa,%al
		s++, neg = 1;

	// hex or octal base prefix
	if ((base == 0 || base == 16) && (s[0] == '0' && s[1] == 'x'))
		s += 2, base = 16;
	else if (base == 0 && s[0] == '0')
f0105fb9:	80 3a 30             	cmpb   $0x30,(%edx)
f0105fbc:	75 05                	jne    f0105fc3 <strtol+0x75>
		s++, base = 8;
f0105fbe:	83 c2 01             	add    $0x1,%edx
f0105fc1:	b0 08                	mov    $0x8,%al
	else if (base == 0)
		base = 10;
f0105fc3:	bb 00 00 00 00       	mov    $0x0,%ebx
f0105fc8:	89 45 10             	mov    %eax,0x10(%ebp)

	// digits
	while (1) {
		int dig;

		if (*s >= '0' && *s <= '9')
f0105fcb:	0f b6 0a             	movzbl (%edx),%ecx
f0105fce:	8d 71 d0             	lea    -0x30(%ecx),%esi
f0105fd1:	89 f0                	mov    %esi,%eax
f0105fd3:	3c 09                	cmp    $0x9,%al
f0105fd5:	77 08                	ja     f0105fdf <strtol+0x91>
			dig = *s - '0';
f0105fd7:	0f be c9             	movsbl %cl,%ecx
f0105fda:	83 e9 30             	sub    $0x30,%ecx
f0105fdd:	eb 20                	jmp    f0105fff <strtol+0xb1>
		else if (*s >= 'a' && *s <= 'z')
f0105fdf:	8d 71 9f             	lea    -0x61(%ecx),%esi
f0105fe2:	89 f0                	mov    %esi,%eax
f0105fe4:	3c 19                	cmp    $0x19,%al
f0105fe6:	77 08                	ja     f0105ff0 <strtol+0xa2>
			dig = *s - 'a' + 10;
f0105fe8:	0f be c9             	movsbl %cl,%ecx
f0105feb:	83 e9 57             	sub    $0x57,%ecx
f0105fee:	eb 0f                	jmp    f0105fff <strtol+0xb1>
		else if (*s >= 'A' && *s <= 'Z')
f0105ff0:	8d 71 bf             	lea    -0x41(%ecx),%esi
f0105ff3:	89 f0                	mov    %esi,%eax
f0105ff5:	3c 19                	cmp    $0x19,%al
f0105ff7:	77 16                	ja     f010600f <strtol+0xc1>
			dig = *s - 'A' + 10;
f0105ff9:	0f be c9             	movsbl %cl,%ecx
f0105ffc:	83 e9 37             	sub    $0x37,%ecx
		else
			break;
		if (dig >= base)
f0105fff:	3b 4d 10             	cmp    0x10(%ebp),%ecx
f0106002:	7d 0f                	jge    f0106013 <strtol+0xc5>
			break;
		s++, val = (val * base) + dig;
f0106004:	83 c2 01             	add    $0x1,%edx
f0106007:	0f af 5d 10          	imul   0x10(%ebp),%ebx
f010600b:	01 cb                	add    %ecx,%ebx
		// we don't properly detect overflow!
	}
f010600d:	eb bc                	jmp    f0105fcb <strtol+0x7d>
f010600f:	89 d8                	mov    %ebx,%eax
f0106011:	eb 02                	jmp    f0106015 <strtol+0xc7>
f0106013:	89 d8                	mov    %ebx,%eax

	if (endptr)
f0106015:	83 7d 0c 00          	cmpl   $0x0,0xc(%ebp)
f0106019:	74 05                	je     f0106020 <strtol+0xd2>
		*endptr = (char *) s;
f010601b:	8b 75 0c             	mov    0xc(%ebp),%esi
f010601e:	89 16                	mov    %edx,(%esi)
	return (neg ? -val : val);
f0106020:	f7 d8                	neg    %eax
f0106022:	85 ff                	test   %edi,%edi
f0106024:	0f 44 c3             	cmove  %ebx,%eax
}
f0106027:	5b                   	pop    %ebx
f0106028:	5e                   	pop    %esi
f0106029:	5f                   	pop    %edi
f010602a:	5d                   	pop    %ebp
f010602b:	c3                   	ret    

f010602c <mpentry_start>:
.set PROT_MODE_DSEG, 0x10	# kernel data segment selector

.code16           
.globl mpentry_start
mpentry_start:
	cli            
f010602c:	fa                   	cli    

	xorw    %ax, %ax
f010602d:	31 c0                	xor    %eax,%eax
	movw    %ax, %ds
f010602f:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106031:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106033:	8e d0                	mov    %eax,%ss

	lgdt    MPBOOTPHYS(gdtdesc)
f0106035:	0f 01 16             	lgdtl  (%esi)
f0106038:	74 70                	je     f01060aa <mpentry_end+0x4>
	movl    %cr0, %eax
f010603a:	0f 20 c0             	mov    %cr0,%eax
	orl     $CR0_PE, %eax
f010603d:	66 83 c8 01          	or     $0x1,%ax
	movl    %eax, %cr0
f0106041:	0f 22 c0             	mov    %eax,%cr0

	ljmpl   $(PROT_MODE_CSEG), $(MPBOOTPHYS(start32))
f0106044:	66 ea 20 70 00 00    	ljmpw  $0x0,$0x7020
f010604a:	08 00                	or     %al,(%eax)

f010604c <start32>:

.code32
start32:
	movw    $(PROT_MODE_DSEG), %ax
f010604c:	66 b8 10 00          	mov    $0x10,%ax
	movw    %ax, %ds
f0106050:	8e d8                	mov    %eax,%ds
	movw    %ax, %es
f0106052:	8e c0                	mov    %eax,%es
	movw    %ax, %ss
f0106054:	8e d0                	mov    %eax,%ss
	movw    $0, %ax
f0106056:	66 b8 00 00          	mov    $0x0,%ax
	movw    %ax, %fs
f010605a:	8e e0                	mov    %eax,%fs
	movw    %ax, %gs
f010605c:	8e e8                	mov    %eax,%gs

	# Set up initial page table. We cannot use kern_pgdir yet because
	# we are still running at a low EIP.
	movl    $(RELOC(entry_pgdir)), %eax
f010605e:	b8 00 f0 11 00       	mov    $0x11f000,%eax
	movl    %eax, %cr3
f0106063:	0f 22 d8             	mov    %eax,%cr3
	# Turn on paging.
	movl    %cr0, %eax
f0106066:	0f 20 c0             	mov    %cr0,%eax
	orl     $(CR0_PE|CR0_PG|CR0_WP), %eax
f0106069:	0d 01 00 01 80       	or     $0x80010001,%eax
	movl    %eax, %cr0
f010606e:	0f 22 c0             	mov    %eax,%cr0

	# Switch to the per-cpu stack allocated in mem_init()
	movl    mpentry_kstack, %esp
f0106071:	8b 25 84 ce 1c f0    	mov    0xf01cce84,%esp
	movl    $0x0, %ebp       # nuke frame pointer
f0106077:	bd 00 00 00 00       	mov    $0x0,%ebp

	# Call mp_main().  (Exercise for the reader: why the indirect call?)
	movl    $mp_main, %eax
f010607c:	b8 45 02 10 f0       	mov    $0xf0100245,%eax
	call    *%eax
f0106081:	ff d0                	call   *%eax

f0106083 <spin>:

	# If mp_main returns (it shouldn't), loop.
spin:
	jmp     spin
f0106083:	eb fe                	jmp    f0106083 <spin>
f0106085:	8d 76 00             	lea    0x0(%esi),%esi

f0106088 <gdt>:
	...
f0106090:	ff                   	(bad)  
f0106091:	ff 00                	incl   (%eax)
f0106093:	00 00                	add    %al,(%eax)
f0106095:	9a cf 00 ff ff 00 00 	lcall  $0x0,$0xffff00cf
f010609c:	00 92 cf 00 17 00    	add    %dl,0x1700cf(%edx)

f01060a0 <gdtdesc>:
f01060a0:	17                   	pop    %ss
f01060a1:	00 5c 70 00          	add    %bl,0x0(%eax,%esi,2)
	...

f01060a6 <mpentry_end>:
	.word   0x17				# sizeof(gdt) - 1
	.long   MPBOOTPHYS(gdt)			# address gdt

.globl mpentry_end
mpentry_end:
	nop
f01060a6:	90                   	nop
f01060a7:	66 90                	xchg   %ax,%ax
f01060a9:	66 90                	xchg   %ax,%ax
f01060ab:	66 90                	xchg   %ax,%ax
f01060ad:	66 90                	xchg   %ax,%ax
f01060af:	90                   	nop

f01060b0 <mpsearch1>:
}

// Look for an MP structure in the len bytes at physical address addr.
static struct mp *
mpsearch1(physaddr_t a, int len)
{
f01060b0:	55                   	push   %ebp
f01060b1:	89 e5                	mov    %esp,%ebp
f01060b3:	56                   	push   %esi
f01060b4:	53                   	push   %ebx
f01060b5:	83 ec 10             	sub    $0x10,%esp
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01060b8:	8b 0d 88 ce 1c f0    	mov    0xf01cce88,%ecx
f01060be:	89 c3                	mov    %eax,%ebx
f01060c0:	c1 eb 0c             	shr    $0xc,%ebx
f01060c3:	39 cb                	cmp    %ecx,%ebx
f01060c5:	72 20                	jb     f01060e7 <mpsearch1+0x37>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01060c7:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01060cb:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f01060d2:	f0 
f01060d3:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f01060da:	00 
f01060db:	c7 04 24 1d 86 10 f0 	movl   $0xf010861d,(%esp)
f01060e2:	e8 59 9f ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f01060e7:	8d 98 00 00 00 f0    	lea    -0x10000000(%eax),%ebx
	struct mp *mp = KADDR(a), *end = KADDR(a + len);
f01060ed:	01 d0                	add    %edx,%eax
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f01060ef:	89 c2                	mov    %eax,%edx
f01060f1:	c1 ea 0c             	shr    $0xc,%edx
f01060f4:	39 d1                	cmp    %edx,%ecx
f01060f6:	77 20                	ja     f0106118 <mpsearch1+0x68>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f01060f8:	89 44 24 0c          	mov    %eax,0xc(%esp)
f01060fc:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f0106103:	f0 
f0106104:	c7 44 24 04 57 00 00 	movl   $0x57,0x4(%esp)
f010610b:	00 
f010610c:	c7 04 24 1d 86 10 f0 	movl   $0xf010861d,(%esp)
f0106113:	e8 28 9f ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106118:	8d b0 00 00 00 f0    	lea    -0x10000000(%eax),%esi

	for (; mp < end; mp++)
f010611e:	39 f3                	cmp    %esi,%ebx
f0106120:	73 40                	jae    f0106162 <mpsearch1+0xb2>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106122:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f0106129:	00 
f010612a:	c7 44 24 04 2d 86 10 	movl   $0xf010862d,0x4(%esp)
f0106131:	f0 
f0106132:	89 1c 24             	mov    %ebx,(%esp)
f0106135:	e8 95 fd ff ff       	call   f0105ecf <memcmp>
f010613a:	85 c0                	test   %eax,%eax
f010613c:	75 17                	jne    f0106155 <mpsearch1+0xa5>
f010613e:	ba 00 00 00 00       	mov    $0x0,%edx
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
		sum += ((uint8_t *)addr)[i];
f0106143:	0f b6 0c 03          	movzbl (%ebx,%eax,1),%ecx
f0106147:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106149:	83 c0 01             	add    $0x1,%eax
f010614c:	83 f8 10             	cmp    $0x10,%eax
f010614f:	75 f2                	jne    f0106143 <mpsearch1+0x93>
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
f0106151:	84 d2                	test   %dl,%dl
f0106153:	74 14                	je     f0106169 <mpsearch1+0xb9>
static struct mp *
mpsearch1(physaddr_t a, int len)
{
	struct mp *mp = KADDR(a), *end = KADDR(a + len);

	for (; mp < end; mp++)
f0106155:	83 c3 10             	add    $0x10,%ebx
f0106158:	39 f3                	cmp    %esi,%ebx
f010615a:	72 c6                	jb     f0106122 <mpsearch1+0x72>
f010615c:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106160:	eb 0b                	jmp    f010616d <mpsearch1+0xbd>
		if (memcmp(mp->signature, "_MP_", 4) == 0 &&
		    sum(mp, sizeof(*mp)) == 0)
			return mp;
	return NULL;
f0106162:	b8 00 00 00 00       	mov    $0x0,%eax
f0106167:	eb 09                	jmp    f0106172 <mpsearch1+0xc2>
f0106169:	89 d8                	mov    %ebx,%eax
f010616b:	eb 05                	jmp    f0106172 <mpsearch1+0xc2>
f010616d:	b8 00 00 00 00       	mov    $0x0,%eax
}
f0106172:	83 c4 10             	add    $0x10,%esp
f0106175:	5b                   	pop    %ebx
f0106176:	5e                   	pop    %esi
f0106177:	5d                   	pop    %ebp
f0106178:	c3                   	ret    

f0106179 <mp_init>:
	return conf;
}

void
mp_init(void)
{
f0106179:	55                   	push   %ebp
f010617a:	89 e5                	mov    %esp,%ebp
f010617c:	57                   	push   %edi
f010617d:	56                   	push   %esi
f010617e:	53                   	push   %ebx
f010617f:	83 ec 2c             	sub    $0x2c,%esp
	struct mpconf *conf;
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
f0106182:	c7 05 c0 d3 1c f0 20 	movl   $0xf01cd020,0xf01cd3c0
f0106189:	d0 1c f0 
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f010618c:	83 3d 88 ce 1c f0 00 	cmpl   $0x0,0xf01cce88
f0106193:	75 24                	jne    f01061b9 <mp_init+0x40>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106195:	c7 44 24 0c 00 04 00 	movl   $0x400,0xc(%esp)
f010619c:	00 
f010619d:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f01061a4:	f0 
f01061a5:	c7 44 24 04 6f 00 00 	movl   $0x6f,0x4(%esp)
f01061ac:	00 
f01061ad:	c7 04 24 1d 86 10 f0 	movl   $0xf010861d,(%esp)
f01061b4:	e8 87 9e ff ff       	call   f0100040 <_panic>
	// The BIOS data area lives in 16-bit segment 0x40.
	bda = (uint8_t *) KADDR(0x40 << 4);

	// [MP 4] The 16-bit segment of the EBDA is in the two bytes
	// starting at byte 0x0E of the BDA.  0 if not present.
	if ((p = *(uint16_t *) (bda + 0x0E))) {
f01061b9:	0f b7 05 0e 04 00 f0 	movzwl 0xf000040e,%eax
f01061c0:	85 c0                	test   %eax,%eax
f01061c2:	74 16                	je     f01061da <mp_init+0x61>
		p <<= 4;	// Translate from segment to PA
f01061c4:	c1 e0 04             	shl    $0x4,%eax
		if ((mp = mpsearch1(p, 1024)))
f01061c7:	ba 00 04 00 00       	mov    $0x400,%edx
f01061cc:	e8 df fe ff ff       	call   f01060b0 <mpsearch1>
f01061d1:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01061d4:	85 c0                	test   %eax,%eax
f01061d6:	75 3c                	jne    f0106214 <mp_init+0x9b>
f01061d8:	eb 20                	jmp    f01061fa <mp_init+0x81>
			return mp;
	} else {
		// The size of base memory, in KB is in the two bytes
		// starting at 0x13 of the BDA.
		p = *(uint16_t *) (bda + 0x13) * 1024;
f01061da:	0f b7 05 13 04 00 f0 	movzwl 0xf0000413,%eax
f01061e1:	c1 e0 0a             	shl    $0xa,%eax
		if ((mp = mpsearch1(p - 1024, 1024)))
f01061e4:	2d 00 04 00 00       	sub    $0x400,%eax
f01061e9:	ba 00 04 00 00       	mov    $0x400,%edx
f01061ee:	e8 bd fe ff ff       	call   f01060b0 <mpsearch1>
f01061f3:	89 45 e4             	mov    %eax,-0x1c(%ebp)
f01061f6:	85 c0                	test   %eax,%eax
f01061f8:	75 1a                	jne    f0106214 <mp_init+0x9b>
			return mp;
	}
	return mpsearch1(0xF0000, 0x10000);
f01061fa:	ba 00 00 01 00       	mov    $0x10000,%edx
f01061ff:	b8 00 00 0f 00       	mov    $0xf0000,%eax
f0106204:	e8 a7 fe ff ff       	call   f01060b0 <mpsearch1>
f0106209:	89 45 e4             	mov    %eax,-0x1c(%ebp)
mpconfig(struct mp **pmp)
{
	struct mpconf *conf;
	struct mp *mp;

	if ((mp = mpsearch()) == 0)
f010620c:	85 c0                	test   %eax,%eax
f010620e:	0f 84 5f 02 00 00    	je     f0106473 <mp_init+0x2fa>
		return NULL;
	if (mp->physaddr == 0 || mp->type != 0) {
f0106214:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f0106217:	8b 70 04             	mov    0x4(%eax),%esi
f010621a:	85 f6                	test   %esi,%esi
f010621c:	74 06                	je     f0106224 <mp_init+0xab>
f010621e:	80 78 0b 00          	cmpb   $0x0,0xb(%eax)
f0106222:	74 11                	je     f0106235 <mp_init+0xbc>
		cprintf("SMP: Default configurations not implemented\n");
f0106224:	c7 04 24 90 84 10 f0 	movl   $0xf0108490,(%esp)
f010622b:	e8 3f da ff ff       	call   f0103c6f <cprintf>
f0106230:	e9 3e 02 00 00       	jmp    f0106473 <mp_init+0x2fa>
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106235:	89 f0                	mov    %esi,%eax
f0106237:	c1 e8 0c             	shr    $0xc,%eax
f010623a:	3b 05 88 ce 1c f0    	cmp    0xf01cce88,%eax
f0106240:	72 20                	jb     f0106262 <mp_init+0xe9>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106242:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106246:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f010624d:	f0 
f010624e:	c7 44 24 04 90 00 00 	movl   $0x90,0x4(%esp)
f0106255:	00 
f0106256:	c7 04 24 1d 86 10 f0 	movl   $0xf010861d,(%esp)
f010625d:	e8 de 9d ff ff       	call   f0100040 <_panic>
	return (void *)(pa + KERNBASE);
f0106262:	8d 9e 00 00 00 f0    	lea    -0x10000000(%esi),%ebx
		return NULL;
	}
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
f0106268:	c7 44 24 08 04 00 00 	movl   $0x4,0x8(%esp)
f010626f:	00 
f0106270:	c7 44 24 04 32 86 10 	movl   $0xf0108632,0x4(%esp)
f0106277:	f0 
f0106278:	89 1c 24             	mov    %ebx,(%esp)
f010627b:	e8 4f fc ff ff       	call   f0105ecf <memcmp>
f0106280:	85 c0                	test   %eax,%eax
f0106282:	74 11                	je     f0106295 <mp_init+0x11c>
		cprintf("SMP: Incorrect MP configuration table signature\n");
f0106284:	c7 04 24 c0 84 10 f0 	movl   $0xf01084c0,(%esp)
f010628b:	e8 df d9 ff ff       	call   f0103c6f <cprintf>
f0106290:	e9 de 01 00 00       	jmp    f0106473 <mp_init+0x2fa>
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f0106295:	0f b7 43 04          	movzwl 0x4(%ebx),%eax
f0106299:	66 89 45 e2          	mov    %ax,-0x1e(%ebp)
f010629d:	0f b7 f8             	movzwl %ax,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01062a0:	85 ff                	test   %edi,%edi
f01062a2:	7e 30                	jle    f01062d4 <mp_init+0x15b>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f01062a4:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f01062a9:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f01062ae:	0f b6 8c 30 00 00 00 	movzbl -0x10000000(%eax,%esi,1),%ecx
f01062b5:	f0 
f01062b6:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f01062b8:	83 c0 01             	add    $0x1,%eax
f01062bb:	39 c7                	cmp    %eax,%edi
f01062bd:	7f ef                	jg     f01062ae <mp_init+0x135>
	conf = (struct mpconf *) KADDR(mp->physaddr);
	if (memcmp(conf, "PCMP", 4) != 0) {
		cprintf("SMP: Incorrect MP configuration table signature\n");
		return NULL;
	}
	if (sum(conf, conf->length) != 0) {
f01062bf:	84 d2                	test   %dl,%dl
f01062c1:	74 11                	je     f01062d4 <mp_init+0x15b>
		cprintf("SMP: Bad MP configuration checksum\n");
f01062c3:	c7 04 24 f4 84 10 f0 	movl   $0xf01084f4,(%esp)
f01062ca:	e8 a0 d9 ff ff       	call   f0103c6f <cprintf>
f01062cf:	e9 9f 01 00 00       	jmp    f0106473 <mp_init+0x2fa>
		return NULL;
	}
	if (conf->version != 1 && conf->version != 4) {
f01062d4:	0f b6 43 06          	movzbl 0x6(%ebx),%eax
f01062d8:	3c 04                	cmp    $0x4,%al
f01062da:	74 1e                	je     f01062fa <mp_init+0x181>
f01062dc:	3c 01                	cmp    $0x1,%al
f01062de:	66 90                	xchg   %ax,%ax
f01062e0:	74 18                	je     f01062fa <mp_init+0x181>
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
f01062e2:	0f b6 c0             	movzbl %al,%eax
f01062e5:	89 44 24 04          	mov    %eax,0x4(%esp)
f01062e9:	c7 04 24 18 85 10 f0 	movl   $0xf0108518,(%esp)
f01062f0:	e8 7a d9 ff ff       	call   f0103c6f <cprintf>
f01062f5:	e9 79 01 00 00       	jmp    f0106473 <mp_init+0x2fa>
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f01062fa:	0f b7 73 28          	movzwl 0x28(%ebx),%esi
f01062fe:	0f b7 7d e2          	movzwl -0x1e(%ebp),%edi
f0106302:	01 df                	add    %ebx,%edi
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106304:	85 f6                	test   %esi,%esi
f0106306:	7e 19                	jle    f0106321 <mp_init+0x1a8>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106308:	ba 00 00 00 00       	mov    $0x0,%edx
	for (i = 0; i < len; i++)
f010630d:	b8 00 00 00 00       	mov    $0x0,%eax
		sum += ((uint8_t *)addr)[i];
f0106312:	0f b6 0c 07          	movzbl (%edi,%eax,1),%ecx
f0106316:	01 ca                	add    %ecx,%edx
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
	for (i = 0; i < len; i++)
f0106318:	83 c0 01             	add    $0x1,%eax
f010631b:	39 c6                	cmp    %eax,%esi
f010631d:	7f f3                	jg     f0106312 <mp_init+0x199>
f010631f:	eb 05                	jmp    f0106326 <mp_init+0x1ad>
static uint8_t
sum(void *addr, int len)
{
	int i, sum;

	sum = 0;
f0106321:	ba 00 00 00 00       	mov    $0x0,%edx
	}
	if (conf->version != 1 && conf->version != 4) {
		cprintf("SMP: Unsupported MP version %d\n", conf->version);
		return NULL;
	}
	if (sum((uint8_t *)conf + conf->length, conf->xlength) != conf->xchecksum) {
f0106326:	38 53 2a             	cmp    %dl,0x2a(%ebx)
f0106329:	74 11                	je     f010633c <mp_init+0x1c3>
		cprintf("SMP: Bad MP configuration extended checksum\n");
f010632b:	c7 04 24 38 85 10 f0 	movl   $0xf0108538,(%esp)
f0106332:	e8 38 d9 ff ff       	call   f0103c6f <cprintf>
f0106337:	e9 37 01 00 00       	jmp    f0106473 <mp_init+0x2fa>
	struct mpproc *proc;
	uint8_t *p;
	unsigned int i;

	bootcpu = &cpus[0];
	if ((conf = mpconfig(&mp)) == 0)
f010633c:	85 db                	test   %ebx,%ebx
f010633e:	0f 84 2f 01 00 00    	je     f0106473 <mp_init+0x2fa>
		return;
	ismp = 1;
f0106344:	c7 05 00 d0 1c f0 01 	movl   $0x1,0xf01cd000
f010634b:	00 00 00 
	lapic = (uint32_t *)conf->lapicaddr;
f010634e:	8b 43 24             	mov    0x24(%ebx),%eax
f0106351:	a3 00 e0 20 f0       	mov    %eax,0xf020e000

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f0106356:	8d 7b 2c             	lea    0x2c(%ebx),%edi
f0106359:	66 83 7b 22 00       	cmpw   $0x0,0x22(%ebx)
f010635e:	0f 84 94 00 00 00    	je     f01063f8 <mp_init+0x27f>
f0106364:	be 00 00 00 00       	mov    $0x0,%esi
		switch (*p) {
f0106369:	0f b6 07             	movzbl (%edi),%eax
f010636c:	84 c0                	test   %al,%al
f010636e:	74 06                	je     f0106376 <mp_init+0x1fd>
f0106370:	3c 04                	cmp    $0x4,%al
f0106372:	77 54                	ja     f01063c8 <mp_init+0x24f>
f0106374:	eb 4d                	jmp    f01063c3 <mp_init+0x24a>
		case MPPROC:
			proc = (struct mpproc *)p;
			if (proc->flags & MPPROC_BOOT)
f0106376:	f6 47 03 02          	testb  $0x2,0x3(%edi)
f010637a:	74 11                	je     f010638d <mp_init+0x214>
				bootcpu = &cpus[ncpu];
f010637c:	6b 05 c4 d3 1c f0 74 	imul   $0x74,0xf01cd3c4,%eax
f0106383:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
f0106388:	a3 c0 d3 1c f0       	mov    %eax,0xf01cd3c0
			if (ncpu < NCPU) {
f010638d:	a1 c4 d3 1c f0       	mov    0xf01cd3c4,%eax
f0106392:	83 f8 07             	cmp    $0x7,%eax
f0106395:	7f 13                	jg     f01063aa <mp_init+0x231>
				cpus[ncpu].cpu_id = ncpu;
f0106397:	6b d0 74             	imul   $0x74,%eax,%edx
f010639a:	88 82 20 d0 1c f0    	mov    %al,-0xfe32fe0(%edx)
				ncpu++;
f01063a0:	83 c0 01             	add    $0x1,%eax
f01063a3:	a3 c4 d3 1c f0       	mov    %eax,0xf01cd3c4
f01063a8:	eb 14                	jmp    f01063be <mp_init+0x245>
			} else {
				cprintf("SMP: too many CPUs, CPU %d disabled\n",
f01063aa:	0f b6 47 01          	movzbl 0x1(%edi),%eax
f01063ae:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063b2:	c7 04 24 68 85 10 f0 	movl   $0xf0108568,(%esp)
f01063b9:	e8 b1 d8 ff ff       	call   f0103c6f <cprintf>
					proc->apicid);
			}
			p += sizeof(struct mpproc);
f01063be:	83 c7 14             	add    $0x14,%edi
			continue;
f01063c1:	eb 26                	jmp    f01063e9 <mp_init+0x270>
		case MPBUS:
		case MPIOAPIC:
		case MPIOINTR:
		case MPLINTR:
			p += 8;
f01063c3:	83 c7 08             	add    $0x8,%edi
			continue;
f01063c6:	eb 21                	jmp    f01063e9 <mp_init+0x270>
		default:
			cprintf("mpinit: unknown config type %x\n", *p);
f01063c8:	0f b6 c0             	movzbl %al,%eax
f01063cb:	89 44 24 04          	mov    %eax,0x4(%esp)
f01063cf:	c7 04 24 90 85 10 f0 	movl   $0xf0108590,(%esp)
f01063d6:	e8 94 d8 ff ff       	call   f0103c6f <cprintf>
			ismp = 0;
f01063db:	c7 05 00 d0 1c f0 00 	movl   $0x0,0xf01cd000
f01063e2:	00 00 00 
			i = conf->entry;
f01063e5:	0f b7 73 22          	movzwl 0x22(%ebx),%esi
	if ((conf = mpconfig(&mp)) == 0)
		return;
	ismp = 1;
	lapic = (uint32_t *)conf->lapicaddr;

	for (p = conf->entries, i = 0; i < conf->entry; i++) {
f01063e9:	83 c6 01             	add    $0x1,%esi
f01063ec:	0f b7 43 22          	movzwl 0x22(%ebx),%eax
f01063f0:	39 f0                	cmp    %esi,%eax
f01063f2:	0f 87 71 ff ff ff    	ja     f0106369 <mp_init+0x1f0>
			ismp = 0;
			i = conf->entry;
		}
	}

	bootcpu->cpu_status = CPU_STARTED;
f01063f8:	a1 c0 d3 1c f0       	mov    0xf01cd3c0,%eax
f01063fd:	c7 40 04 01 00 00 00 	movl   $0x1,0x4(%eax)
	if (!ismp) {
f0106404:	83 3d 00 d0 1c f0 00 	cmpl   $0x0,0xf01cd000
f010640b:	75 22                	jne    f010642f <mp_init+0x2b6>
		// Didn't like what we found; fall back to no MP.
		ncpu = 1;
f010640d:	c7 05 c4 d3 1c f0 01 	movl   $0x1,0xf01cd3c4
f0106414:	00 00 00 
		lapic = NULL;
f0106417:	c7 05 00 e0 20 f0 00 	movl   $0x0,0xf020e000
f010641e:	00 00 00 
		cprintf("SMP: configuration not found, SMP disabled\n");
f0106421:	c7 04 24 b0 85 10 f0 	movl   $0xf01085b0,(%esp)
f0106428:	e8 42 d8 ff ff       	call   f0103c6f <cprintf>
		return;
f010642d:	eb 44                	jmp    f0106473 <mp_init+0x2fa>
	}
	cprintf("SMP: CPU %d found %d CPU(s)\n", bootcpu->cpu_id,  ncpu);
f010642f:	8b 15 c4 d3 1c f0    	mov    0xf01cd3c4,%edx
f0106435:	89 54 24 08          	mov    %edx,0x8(%esp)
f0106439:	0f b6 00             	movzbl (%eax),%eax
f010643c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106440:	c7 04 24 37 86 10 f0 	movl   $0xf0108637,(%esp)
f0106447:	e8 23 d8 ff ff       	call   f0103c6f <cprintf>

	if (mp->imcrp) {
f010644c:	8b 45 e4             	mov    -0x1c(%ebp),%eax
f010644f:	80 78 0c 00          	cmpb   $0x0,0xc(%eax)
f0106453:	74 1e                	je     f0106473 <mp_init+0x2fa>
		// [MP 3.2.6.1] If the hardware implements PIC mode,
		// switch to getting interrupts from the LAPIC.
		cprintf("SMP: Setting IMCR to switch from PIC mode to symmetric I/O mode\n");
f0106455:	c7 04 24 dc 85 10 f0 	movl   $0xf01085dc,(%esp)
f010645c:	e8 0e d8 ff ff       	call   f0103c6f <cprintf>
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106461:	ba 22 00 00 00       	mov    $0x22,%edx
f0106466:	b8 70 00 00 00       	mov    $0x70,%eax
f010646b:	ee                   	out    %al,(%dx)

static __inline uint8_t
inb(int port)
{
	uint8_t data;
	__asm __volatile("inb %w1,%0" : "=a" (data) : "d" (port));
f010646c:	b2 23                	mov    $0x23,%dl
f010646e:	ec                   	in     (%dx),%al
		outb(0x22, 0x70);   // Select IMCR
		outb(0x23, inb(0x23) | 1);  // Mask external interrupts.
f010646f:	83 c8 01             	or     $0x1,%eax
}

static __inline void
outb(int port, uint8_t data)
{
	__asm __volatile("outb %0,%w1" : : "a" (data), "d" (port));
f0106472:	ee                   	out    %al,(%dx)
	}
}
f0106473:	83 c4 2c             	add    $0x2c,%esp
f0106476:	5b                   	pop    %ebx
f0106477:	5e                   	pop    %esi
f0106478:	5f                   	pop    %edi
f0106479:	5d                   	pop    %ebp
f010647a:	c3                   	ret    

f010647b <lapicw>:

volatile uint32_t *lapic;  // Initialized in mp.c

static void
lapicw(int index, int value)
{
f010647b:	55                   	push   %ebp
f010647c:	89 e5                	mov    %esp,%ebp
	lapic[index] = value;
f010647e:	8b 0d 00 e0 20 f0    	mov    0xf020e000,%ecx
f0106484:	8d 04 81             	lea    (%ecx,%eax,4),%eax
f0106487:	89 10                	mov    %edx,(%eax)
	lapic[ID];  // wait for write to finish, by reading
f0106489:	a1 00 e0 20 f0       	mov    0xf020e000,%eax
f010648e:	8b 40 20             	mov    0x20(%eax),%eax
}
f0106491:	5d                   	pop    %ebp
f0106492:	c3                   	ret    

f0106493 <cpunum>:
	lapicw(TPR, 0);
}

int
cpunum(void)
{
f0106493:	55                   	push   %ebp
f0106494:	89 e5                	mov    %esp,%ebp
	if (lapic)
f0106496:	a1 00 e0 20 f0       	mov    0xf020e000,%eax
f010649b:	85 c0                	test   %eax,%eax
f010649d:	74 08                	je     f01064a7 <cpunum+0x14>
		return lapic[ID] >> 24;
f010649f:	8b 40 20             	mov    0x20(%eax),%eax
f01064a2:	c1 e8 18             	shr    $0x18,%eax
f01064a5:	eb 05                	jmp    f01064ac <cpunum+0x19>
	return 0;
f01064a7:	b8 00 00 00 00       	mov    $0x0,%eax
}
f01064ac:	5d                   	pop    %ebp
f01064ad:	c3                   	ret    

f01064ae <lapic_init>:
}

void
lapic_init(void)
{
	if (!lapic) 
f01064ae:	83 3d 00 e0 20 f0 00 	cmpl   $0x0,0xf020e000
f01064b5:	0f 84 0b 01 00 00    	je     f01065c6 <lapic_init+0x118>
	lapic[ID];  // wait for write to finish, by reading
}

void
lapic_init(void)
{
f01064bb:	55                   	push   %ebp
f01064bc:	89 e5                	mov    %esp,%ebp
	if (!lapic) 
		return;

	// Enable local APIC; set spurious interrupt vector.
	lapicw(SVR, ENABLE | (IRQ_OFFSET + IRQ_SPURIOUS));
f01064be:	ba 27 01 00 00       	mov    $0x127,%edx
f01064c3:	b8 3c 00 00 00       	mov    $0x3c,%eax
f01064c8:	e8 ae ff ff ff       	call   f010647b <lapicw>

	// The timer repeatedly counts down at bus frequency
	// from lapic[TICR] and then issues an interrupt.  
	// If we cared more about precise timekeeping,
	// TICR would be calibrated using an external time source.
	lapicw(TDCR, X1);
f01064cd:	ba 0b 00 00 00       	mov    $0xb,%edx
f01064d2:	b8 f8 00 00 00       	mov    $0xf8,%eax
f01064d7:	e8 9f ff ff ff       	call   f010647b <lapicw>
	lapicw(TIMER, PERIODIC | (IRQ_OFFSET + IRQ_TIMER));
f01064dc:	ba 20 00 02 00       	mov    $0x20020,%edx
f01064e1:	b8 c8 00 00 00       	mov    $0xc8,%eax
f01064e6:	e8 90 ff ff ff       	call   f010647b <lapicw>
	lapicw(TICR, 10000000); 
f01064eb:	ba 80 96 98 00       	mov    $0x989680,%edx
f01064f0:	b8 e0 00 00 00       	mov    $0xe0,%eax
f01064f5:	e8 81 ff ff ff       	call   f010647b <lapicw>
	//
	// According to Intel MP Specification, the BIOS should initialize
	// BSP's local APIC in Virtual Wire Mode, in which 8259A's
	// INTR is virtually connected to BSP's LINTIN0. In this mode,
	// we do not need to program the IOAPIC.
	if (thiscpu != bootcpu)
f01064fa:	e8 94 ff ff ff       	call   f0106493 <cpunum>
f01064ff:	6b c0 74             	imul   $0x74,%eax,%eax
f0106502:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
f0106507:	39 05 c0 d3 1c f0    	cmp    %eax,0xf01cd3c0
f010650d:	74 0f                	je     f010651e <lapic_init+0x70>
		lapicw(LINT0, MASKED);
f010650f:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106514:	b8 d4 00 00 00       	mov    $0xd4,%eax
f0106519:	e8 5d ff ff ff       	call   f010647b <lapicw>

	// Disable NMI (LINT1) on all CPUs
	lapicw(LINT1, MASKED);
f010651e:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106523:	b8 d8 00 00 00       	mov    $0xd8,%eax
f0106528:	e8 4e ff ff ff       	call   f010647b <lapicw>

	// Disable performance counter overflow interrupts
	// on machines that provide that interrupt entry.
	if (((lapic[VER]>>16) & 0xFF) >= 4)
f010652d:	a1 00 e0 20 f0       	mov    0xf020e000,%eax
f0106532:	8b 40 30             	mov    0x30(%eax),%eax
f0106535:	c1 e8 10             	shr    $0x10,%eax
f0106538:	3c 03                	cmp    $0x3,%al
f010653a:	76 0f                	jbe    f010654b <lapic_init+0x9d>
		lapicw(PCINT, MASKED);
f010653c:	ba 00 00 01 00       	mov    $0x10000,%edx
f0106541:	b8 d0 00 00 00       	mov    $0xd0,%eax
f0106546:	e8 30 ff ff ff       	call   f010647b <lapicw>

	// Map error interrupt to IRQ_ERROR.
	lapicw(ERROR, IRQ_OFFSET + IRQ_ERROR);
f010654b:	ba 33 00 00 00       	mov    $0x33,%edx
f0106550:	b8 dc 00 00 00       	mov    $0xdc,%eax
f0106555:	e8 21 ff ff ff       	call   f010647b <lapicw>

	// Clear error status register (requires back-to-back writes).
	lapicw(ESR, 0);
f010655a:	ba 00 00 00 00       	mov    $0x0,%edx
f010655f:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106564:	e8 12 ff ff ff       	call   f010647b <lapicw>
	lapicw(ESR, 0);
f0106569:	ba 00 00 00 00       	mov    $0x0,%edx
f010656e:	b8 a0 00 00 00       	mov    $0xa0,%eax
f0106573:	e8 03 ff ff ff       	call   f010647b <lapicw>

	// Ack any outstanding interrupts.
	lapicw(EOI, 0);
f0106578:	ba 00 00 00 00       	mov    $0x0,%edx
f010657d:	b8 2c 00 00 00       	mov    $0x2c,%eax
f0106582:	e8 f4 fe ff ff       	call   f010647b <lapicw>

	// Send an Init Level De-Assert to synchronize arbitration ID's.
	lapicw(ICRHI, 0);
f0106587:	ba 00 00 00 00       	mov    $0x0,%edx
f010658c:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106591:	e8 e5 fe ff ff       	call   f010647b <lapicw>
	lapicw(ICRLO, BCAST | INIT | LEVEL);
f0106596:	ba 00 85 08 00       	mov    $0x88500,%edx
f010659b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01065a0:	e8 d6 fe ff ff       	call   f010647b <lapicw>
	while(lapic[ICRLO] & DELIVS)
f01065a5:	8b 15 00 e0 20 f0    	mov    0xf020e000,%edx
f01065ab:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01065b1:	f6 c4 10             	test   $0x10,%ah
f01065b4:	75 f5                	jne    f01065ab <lapic_init+0xfd>
		;

	// Enable interrupts on the APIC (but not on the processor).
	lapicw(TPR, 0);
f01065b6:	ba 00 00 00 00       	mov    $0x0,%edx
f01065bb:	b8 20 00 00 00       	mov    $0x20,%eax
f01065c0:	e8 b6 fe ff ff       	call   f010647b <lapicw>
}
f01065c5:	5d                   	pop    %ebp
f01065c6:	f3 c3                	repz ret 

f01065c8 <lapic_eoi>:

// Acknowledge interrupt.
void
lapic_eoi(void)
{
	if (lapic)
f01065c8:	83 3d 00 e0 20 f0 00 	cmpl   $0x0,0xf020e000
f01065cf:	74 13                	je     f01065e4 <lapic_eoi+0x1c>
}

// Acknowledge interrupt.
void
lapic_eoi(void)
{
f01065d1:	55                   	push   %ebp
f01065d2:	89 e5                	mov    %esp,%ebp
	if (lapic)
		lapicw(EOI, 0);
f01065d4:	ba 00 00 00 00       	mov    $0x0,%edx
f01065d9:	b8 2c 00 00 00       	mov    $0x2c,%eax
f01065de:	e8 98 fe ff ff       	call   f010647b <lapicw>
}
f01065e3:	5d                   	pop    %ebp
f01065e4:	f3 c3                	repz ret 

f01065e6 <lapic_startap>:

// Start additional processor running entry code at addr.
// See Appendix B of MultiProcessor Specification.
void
lapic_startap(uint8_t apicid, uint32_t addr)
{
f01065e6:	55                   	push   %ebp
f01065e7:	89 e5                	mov    %esp,%ebp
f01065e9:	56                   	push   %esi
f01065ea:	53                   	push   %ebx
f01065eb:	83 ec 10             	sub    $0x10,%esp
f01065ee:	8b 5d 08             	mov    0x8(%ebp),%ebx
f01065f1:	8b 75 0c             	mov    0xc(%ebp),%esi
f01065f4:	ba 70 00 00 00       	mov    $0x70,%edx
f01065f9:	b8 0f 00 00 00       	mov    $0xf,%eax
f01065fe:	ee                   	out    %al,(%dx)
f01065ff:	b2 71                	mov    $0x71,%dl
f0106601:	b8 0a 00 00 00       	mov    $0xa,%eax
f0106606:	ee                   	out    %al,(%dx)
#define KADDR(pa) _kaddr(__FILE__, __LINE__, pa)

static inline void*
_kaddr(const char *file, int line, physaddr_t pa)
{
	if (PGNUM(pa) >= npages)
f0106607:	83 3d 88 ce 1c f0 00 	cmpl   $0x0,0xf01cce88
f010660e:	75 24                	jne    f0106634 <lapic_startap+0x4e>
		_panic(file, line, "KADDR called with invalid pa %08lx", pa);
f0106610:	c7 44 24 0c 67 04 00 	movl   $0x467,0xc(%esp)
f0106617:	00 
f0106618:	c7 44 24 08 c4 6b 10 	movl   $0xf0106bc4,0x8(%esp)
f010661f:	f0 
f0106620:	c7 44 24 04 93 00 00 	movl   $0x93,0x4(%esp)
f0106627:	00 
f0106628:	c7 04 24 54 86 10 f0 	movl   $0xf0108654,(%esp)
f010662f:	e8 0c 9a ff ff       	call   f0100040 <_panic>
	// and the warm reset vector (DWORD based at 40:67) to point at
	// the AP startup code prior to the [universal startup algorithm]."
	outb(IO_RTC, 0xF);  // offset 0xF is shutdown code
	outb(IO_RTC+1, 0x0A);
	wrv = (uint16_t *)KADDR((0x40 << 4 | 0x67));  // Warm reset vector
	wrv[0] = 0;
f0106634:	66 c7 05 67 04 00 f0 	movw   $0x0,0xf0000467
f010663b:	00 00 
	wrv[1] = addr >> 4;
f010663d:	89 f0                	mov    %esi,%eax
f010663f:	c1 e8 04             	shr    $0x4,%eax
f0106642:	66 a3 69 04 00 f0    	mov    %ax,0xf0000469

	// "Universal startup algorithm."
	// Send INIT (level-triggered) interrupt to reset other CPU.
	lapicw(ICRHI, apicid << 24);
f0106648:	c1 e3 18             	shl    $0x18,%ebx
f010664b:	89 da                	mov    %ebx,%edx
f010664d:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106652:	e8 24 fe ff ff       	call   f010647b <lapicw>
	lapicw(ICRLO, INIT | LEVEL | ASSERT);
f0106657:	ba 00 c5 00 00       	mov    $0xc500,%edx
f010665c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106661:	e8 15 fe ff ff       	call   f010647b <lapicw>
	microdelay(200);
	lapicw(ICRLO, INIT | LEVEL);
f0106666:	ba 00 85 00 00       	mov    $0x8500,%edx
f010666b:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106670:	e8 06 fe ff ff       	call   f010647b <lapicw>
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
		lapicw(ICRLO, STARTUP | (addr >> 12));
f0106675:	c1 ee 0c             	shr    $0xc,%esi
f0106678:	81 ce 00 06 00 00    	or     $0x600,%esi
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f010667e:	89 da                	mov    %ebx,%edx
f0106680:	b8 c4 00 00 00       	mov    $0xc4,%eax
f0106685:	e8 f1 fd ff ff       	call   f010647b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f010668a:	89 f2                	mov    %esi,%edx
f010668c:	b8 c0 00 00 00       	mov    $0xc0,%eax
f0106691:	e8 e5 fd ff ff       	call   f010647b <lapicw>
	// Regular hardware is supposed to only accept a STARTUP
	// when it is in the halted state due to an INIT.  So the second
	// should be ignored, but it is part of the official Intel algorithm.
	// Bochs complains about the second one.  Too bad for Bochs.
	for (i = 0; i < 2; i++) {
		lapicw(ICRHI, apicid << 24);
f0106696:	89 da                	mov    %ebx,%edx
f0106698:	b8 c4 00 00 00       	mov    $0xc4,%eax
f010669d:	e8 d9 fd ff ff       	call   f010647b <lapicw>
		lapicw(ICRLO, STARTUP | (addr >> 12));
f01066a2:	89 f2                	mov    %esi,%edx
f01066a4:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01066a9:	e8 cd fd ff ff       	call   f010647b <lapicw>
		microdelay(200);
	}
}
f01066ae:	83 c4 10             	add    $0x10,%esp
f01066b1:	5b                   	pop    %ebx
f01066b2:	5e                   	pop    %esi
f01066b3:	5d                   	pop    %ebp
f01066b4:	c3                   	ret    

f01066b5 <lapic_ipi>:

void
lapic_ipi(int vector)
{
f01066b5:	55                   	push   %ebp
f01066b6:	89 e5                	mov    %esp,%ebp
	lapicw(ICRLO, OTHERS | FIXED | vector);
f01066b8:	8b 55 08             	mov    0x8(%ebp),%edx
f01066bb:	81 ca 00 00 0c 00    	or     $0xc0000,%edx
f01066c1:	b8 c0 00 00 00       	mov    $0xc0,%eax
f01066c6:	e8 b0 fd ff ff       	call   f010647b <lapicw>
	while (lapic[ICRLO] & DELIVS)
f01066cb:	8b 15 00 e0 20 f0    	mov    0xf020e000,%edx
f01066d1:	8b 82 00 03 00 00    	mov    0x300(%edx),%eax
f01066d7:	f6 c4 10             	test   $0x10,%ah
f01066da:	75 f5                	jne    f01066d1 <lapic_ipi+0x1c>
		;
}
f01066dc:	5d                   	pop    %ebp
f01066dd:	c3                   	ret    

f01066de <__spin_initlock>:
}
#endif

void
__spin_initlock(struct spinlock *lk, char *name)
{
f01066de:	55                   	push   %ebp
f01066df:	89 e5                	mov    %esp,%ebp
f01066e1:	8b 45 08             	mov    0x8(%ebp),%eax
	lk->locked = 0;
f01066e4:	c7 00 00 00 00 00    	movl   $0x0,(%eax)
#ifdef DEBUG_SPINLOCK
	lk->name = name;
f01066ea:	8b 55 0c             	mov    0xc(%ebp),%edx
f01066ed:	89 50 04             	mov    %edx,0x4(%eax)
	lk->cpu = 0;
f01066f0:	c7 40 08 00 00 00 00 	movl   $0x0,0x8(%eax)
#endif
}
f01066f7:	5d                   	pop    %ebp
f01066f8:	c3                   	ret    

f01066f9 <spin_lock>:
// Loops (spins) until the lock is acquired.
// Holding a lock for a long time may cause
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
f01066f9:	55                   	push   %ebp
f01066fa:	89 e5                	mov    %esp,%ebp
f01066fc:	56                   	push   %esi
f01066fd:	53                   	push   %ebx
f01066fe:	83 ec 20             	sub    $0x20,%esp
f0106701:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f0106704:	83 3b 00             	cmpl   $0x0,(%ebx)
f0106707:	74 14                	je     f010671d <spin_lock+0x24>
f0106709:	8b 73 08             	mov    0x8(%ebx),%esi
f010670c:	e8 82 fd ff ff       	call   f0106493 <cpunum>
f0106711:	6b c0 74             	imul   $0x74,%eax,%eax
f0106714:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
// other CPUs to waste time spinning to acquire it.
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
f0106719:	39 c6                	cmp    %eax,%esi
f010671b:	74 15                	je     f0106732 <spin_lock+0x39>
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f010671d:	89 da                	mov    %ebx,%edx
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f010671f:	b8 01 00 00 00       	mov    $0x1,%eax
f0106724:	f0 87 03             	lock xchg %eax,(%ebx)
f0106727:	b9 01 00 00 00       	mov    $0x1,%ecx
f010672c:	85 c0                	test   %eax,%eax
f010672e:	75 2e                	jne    f010675e <spin_lock+0x65>
f0106730:	eb 37                	jmp    f0106769 <spin_lock+0x70>
void
spin_lock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (holding(lk))
		panic("CPU %d cannot acquire %s: already holding", cpunum(), lk->name);
f0106732:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106735:	e8 59 fd ff ff       	call   f0106493 <cpunum>
f010673a:	89 5c 24 10          	mov    %ebx,0x10(%esp)
f010673e:	89 44 24 0c          	mov    %eax,0xc(%esp)
f0106742:	c7 44 24 08 64 86 10 	movl   $0xf0108664,0x8(%esp)
f0106749:	f0 
f010674a:	c7 44 24 04 42 00 00 	movl   $0x42,0x4(%esp)
f0106751:	00 
f0106752:	c7 04 24 c8 86 10 f0 	movl   $0xf01086c8,(%esp)
f0106759:	e8 e2 98 ff ff       	call   f0100040 <_panic>

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
		asm volatile ("pause");
f010675e:	f3 90                	pause  
f0106760:	89 c8                	mov    %ecx,%eax
f0106762:	f0 87 02             	lock xchg %eax,(%edx)
#endif

	// The xchg is atomic.
	// It also serializes, so that reads after acquire are not
	// reordered before it. 
	while (xchg(&lk->locked, 1) != 0)
f0106765:	85 c0                	test   %eax,%eax
f0106767:	75 f5                	jne    f010675e <spin_lock+0x65>
		asm volatile ("pause");

	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
f0106769:	e8 25 fd ff ff       	call   f0106493 <cpunum>
f010676e:	6b c0 74             	imul   $0x74,%eax,%eax
f0106771:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
f0106776:	89 43 08             	mov    %eax,0x8(%ebx)
	get_caller_pcs(lk->pcs);
f0106779:	8d 4b 0c             	lea    0xc(%ebx),%ecx

static __inline uint32_t
read_ebp(void)
{
        uint32_t ebp;
        __asm __volatile("movl %%ebp,%0" : "=r" (ebp));
f010677c:	89 e8                	mov    %ebp,%eax
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
f010677e:	8d 90 00 00 80 10    	lea    0x10800000(%eax),%edx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106784:	81 fa ff ff 7f 0e    	cmp    $0xe7fffff,%edx
f010678a:	76 3a                	jbe    f01067c6 <spin_lock+0xcd>
f010678c:	eb 31                	jmp    f01067bf <spin_lock+0xc6>
		    || ebp >= (uint32_t *)IOMEMBASE)
f010678e:	8d 9a 00 00 80 10    	lea    0x10800000(%edx),%ebx
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
		if (ebp == 0 || ebp < (uint32_t *)ULIM
f0106794:	81 fb ff ff 7f 0e    	cmp    $0xe7fffff,%ebx
f010679a:	77 12                	ja     f01067ae <spin_lock+0xb5>
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f010679c:	8b 5a 04             	mov    0x4(%edx),%ebx
f010679f:	89 1c 81             	mov    %ebx,(%ecx,%eax,4)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01067a2:	8b 12                	mov    (%edx),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01067a4:	83 c0 01             	add    $0x1,%eax
f01067a7:	83 f8 0a             	cmp    $0xa,%eax
f01067aa:	75 e2                	jne    f010678e <spin_lock+0x95>
f01067ac:	eb 27                	jmp    f01067d5 <spin_lock+0xdc>
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
		pcs[i] = 0;
f01067ae:	c7 04 81 00 00 00 00 	movl   $0x0,(%ecx,%eax,4)
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
		ebp = (uint32_t *)ebp[0]; // saved %ebp
	}
	for (; i < 10; i++)
f01067b5:	83 c0 01             	add    $0x1,%eax
f01067b8:	83 f8 09             	cmp    $0x9,%eax
f01067bb:	7e f1                	jle    f01067ae <spin_lock+0xb5>
f01067bd:	eb 16                	jmp    f01067d5 <spin_lock+0xdc>
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01067bf:	b8 00 00 00 00       	mov    $0x0,%eax
f01067c4:	eb e8                	jmp    f01067ae <spin_lock+0xb5>
		if (ebp == 0 || ebp < (uint32_t *)ULIM
		    || ebp >= (uint32_t *)IOMEMBASE)
			break;
		pcs[i] = ebp[1];          // saved %eip
f01067c6:	8b 50 04             	mov    0x4(%eax),%edx
f01067c9:	89 53 0c             	mov    %edx,0xc(%ebx)
		ebp = (uint32_t *)ebp[0]; // saved %ebp
f01067cc:	8b 10                	mov    (%eax),%edx
{
	uint32_t *ebp;
	int i;

	ebp = (uint32_t *)read_ebp();
	for (i = 0; i < 10; i++){
f01067ce:	b8 01 00 00 00       	mov    $0x1,%eax
f01067d3:	eb b9                	jmp    f010678e <spin_lock+0x95>
	// Record info about lock acquisition for debugging.
#ifdef DEBUG_SPINLOCK
	lk->cpu = thiscpu;
	get_caller_pcs(lk->pcs);
#endif
}
f01067d5:	83 c4 20             	add    $0x20,%esp
f01067d8:	5b                   	pop    %ebx
f01067d9:	5e                   	pop    %esi
f01067da:	5d                   	pop    %ebp
f01067db:	c3                   	ret    

f01067dc <spin_unlock>:

// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
f01067dc:	55                   	push   %ebp
f01067dd:	89 e5                	mov    %esp,%ebp
f01067df:	57                   	push   %edi
f01067e0:	56                   	push   %esi
f01067e1:	53                   	push   %ebx
f01067e2:	83 ec 6c             	sub    $0x6c,%esp
f01067e5:	8b 5d 08             	mov    0x8(%ebp),%ebx

// Check whether this CPU is holding the lock.
static int
holding(struct spinlock *lock)
{
	return lock->locked && lock->cpu == thiscpu;
f01067e8:	83 3b 00             	cmpl   $0x0,(%ebx)
f01067eb:	74 18                	je     f0106805 <spin_unlock+0x29>
f01067ed:	8b 73 08             	mov    0x8(%ebx),%esi
f01067f0:	e8 9e fc ff ff       	call   f0106493 <cpunum>
f01067f5:	6b c0 74             	imul   $0x74,%eax,%eax
f01067f8:	05 20 d0 1c f0       	add    $0xf01cd020,%eax
// Release the lock.
void
spin_unlock(struct spinlock *lk)
{
#ifdef DEBUG_SPINLOCK
	if (!holding(lk)) {
f01067fd:	39 c6                	cmp    %eax,%esi
f01067ff:	0f 84 d4 00 00 00    	je     f01068d9 <spin_unlock+0xfd>
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
f0106805:	c7 44 24 08 28 00 00 	movl   $0x28,0x8(%esp)
f010680c:	00 
f010680d:	8d 43 0c             	lea    0xc(%ebx),%eax
f0106810:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106814:	8d 45 c0             	lea    -0x40(%ebp),%eax
f0106817:	89 04 24             	mov    %eax,(%esp)
f010681a:	e8 27 f6 ff ff       	call   f0105e46 <memmove>
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
f010681f:	8b 43 08             	mov    0x8(%ebx),%eax
	if (!holding(lk)) {
		int i;
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
f0106822:	0f b6 30             	movzbl (%eax),%esi
f0106825:	8b 5b 04             	mov    0x4(%ebx),%ebx
f0106828:	e8 66 fc ff ff       	call   f0106493 <cpunum>
f010682d:	89 74 24 0c          	mov    %esi,0xc(%esp)
f0106831:	89 5c 24 08          	mov    %ebx,0x8(%esp)
f0106835:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106839:	c7 04 24 90 86 10 f0 	movl   $0xf0108690,(%esp)
f0106840:	e8 2a d4 ff ff       	call   f0103c6f <cprintf>
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f0106845:	8b 45 c0             	mov    -0x40(%ebp),%eax
f0106848:	85 c0                	test   %eax,%eax
f010684a:	74 71                	je     f01068bd <spin_unlock+0xe1>
f010684c:	8d 5d c0             	lea    -0x40(%ebp),%ebx
f010684f:	8d 7d e4             	lea    -0x1c(%ebp),%edi
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
f0106852:	8d 75 a8             	lea    -0x58(%ebp),%esi
f0106855:	89 74 24 04          	mov    %esi,0x4(%esp)
f0106859:	89 04 24             	mov    %eax,(%esp)
f010685c:	e8 8b e9 ff ff       	call   f01051ec <debuginfo_eip>
f0106861:	85 c0                	test   %eax,%eax
f0106863:	78 39                	js     f010689e <spin_unlock+0xc2>
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
f0106865:	8b 03                	mov    (%ebx),%eax
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
			struct Eipdebuginfo info;
			if (debuginfo_eip(pcs[i], &info) >= 0)
				cprintf("  %08x %s:%d: %.*s+%x\n", pcs[i],
f0106867:	89 c2                	mov    %eax,%edx
f0106869:	2b 55 b8             	sub    -0x48(%ebp),%edx
f010686c:	89 54 24 18          	mov    %edx,0x18(%esp)
f0106870:	8b 55 b0             	mov    -0x50(%ebp),%edx
f0106873:	89 54 24 14          	mov    %edx,0x14(%esp)
f0106877:	8b 55 b4             	mov    -0x4c(%ebp),%edx
f010687a:	89 54 24 10          	mov    %edx,0x10(%esp)
f010687e:	8b 55 ac             	mov    -0x54(%ebp),%edx
f0106881:	89 54 24 0c          	mov    %edx,0xc(%esp)
f0106885:	8b 55 a8             	mov    -0x58(%ebp),%edx
f0106888:	89 54 24 08          	mov    %edx,0x8(%esp)
f010688c:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106890:	c7 04 24 d8 86 10 f0 	movl   $0xf01086d8,(%esp)
f0106897:	e8 d3 d3 ff ff       	call   f0103c6f <cprintf>
f010689c:	eb 12                	jmp    f01068b0 <spin_unlock+0xd4>
					info.eip_file, info.eip_line,
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
f010689e:	8b 03                	mov    (%ebx),%eax
f01068a0:	89 44 24 04          	mov    %eax,0x4(%esp)
f01068a4:	c7 04 24 ef 86 10 f0 	movl   $0xf01086ef,(%esp)
f01068ab:	e8 bf d3 ff ff       	call   f0103c6f <cprintf>
		uint32_t pcs[10];
		// Nab the acquiring EIP chain before it gets released
		memmove(pcs, lk->pcs, sizeof pcs);
		cprintf("CPU %d cannot release %s: held by CPU %d\nAcquired at:", 
			cpunum(), lk->name, lk->cpu->cpu_id);
		for (i = 0; i < 10 && pcs[i]; i++) {
f01068b0:	39 fb                	cmp    %edi,%ebx
f01068b2:	74 09                	je     f01068bd <spin_unlock+0xe1>
f01068b4:	83 c3 04             	add    $0x4,%ebx
f01068b7:	8b 03                	mov    (%ebx),%eax
f01068b9:	85 c0                	test   %eax,%eax
f01068bb:	75 98                	jne    f0106855 <spin_unlock+0x79>
					info.eip_fn_namelen, info.eip_fn_name,
					pcs[i] - info.eip_fn_addr);
			else
				cprintf("  %08x\n", pcs[i]);
		}
		panic("spin_unlock");
f01068bd:	c7 44 24 08 f7 86 10 	movl   $0xf01086f7,0x8(%esp)
f01068c4:	f0 
f01068c5:	c7 44 24 04 68 00 00 	movl   $0x68,0x4(%esp)
f01068cc:	00 
f01068cd:	c7 04 24 c8 86 10 f0 	movl   $0xf01086c8,(%esp)
f01068d4:	e8 67 97 ff ff       	call   f0100040 <_panic>
	}

	lk->pcs[0] = 0;
f01068d9:	c7 43 0c 00 00 00 00 	movl   $0x0,0xc(%ebx)
	lk->cpu = 0;
f01068e0:	c7 43 08 00 00 00 00 	movl   $0x0,0x8(%ebx)
xchg(volatile uint32_t *addr, uint32_t newval)
{
	uint32_t result;

	// The + in "+m" denotes a read-modify-write operand.
	asm volatile("lock; xchgl %0, %1" :
f01068e7:	b8 00 00 00 00       	mov    $0x0,%eax
f01068ec:	f0 87 03             	lock xchg %eax,(%ebx)
	// Paper says that Intel 64 and IA-32 will not move a load
	// after a store. So lock->locked = 0 would work here.
	// The xchg being asm volatile ensures gcc emits it after
	// the above assignments (and after the critical section).
	xchg(&lk->locked, 0);
}
f01068ef:	83 c4 6c             	add    $0x6c,%esp
f01068f2:	5b                   	pop    %ebx
f01068f3:	5e                   	pop    %esi
f01068f4:	5f                   	pop    %edi
f01068f5:	5d                   	pop    %ebp
f01068f6:	c3                   	ret    
f01068f7:	66 90                	xchg   %ax,%ax
f01068f9:	66 90                	xchg   %ax,%ax
f01068fb:	66 90                	xchg   %ax,%ax
f01068fd:	66 90                	xchg   %ax,%ax
f01068ff:	90                   	nop

f0106900 <__udivdi3>:
f0106900:	55                   	push   %ebp
f0106901:	57                   	push   %edi
f0106902:	56                   	push   %esi
f0106903:	83 ec 0c             	sub    $0xc,%esp
f0106906:	8b 44 24 28          	mov    0x28(%esp),%eax
f010690a:	8b 7c 24 1c          	mov    0x1c(%esp),%edi
f010690e:	8b 6c 24 20          	mov    0x20(%esp),%ebp
f0106912:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106916:	85 c0                	test   %eax,%eax
f0106918:	89 7c 24 04          	mov    %edi,0x4(%esp)
f010691c:	89 ea                	mov    %ebp,%edx
f010691e:	89 0c 24             	mov    %ecx,(%esp)
f0106921:	75 2d                	jne    f0106950 <__udivdi3+0x50>
f0106923:	39 e9                	cmp    %ebp,%ecx
f0106925:	77 61                	ja     f0106988 <__udivdi3+0x88>
f0106927:	85 c9                	test   %ecx,%ecx
f0106929:	89 ce                	mov    %ecx,%esi
f010692b:	75 0b                	jne    f0106938 <__udivdi3+0x38>
f010692d:	b8 01 00 00 00       	mov    $0x1,%eax
f0106932:	31 d2                	xor    %edx,%edx
f0106934:	f7 f1                	div    %ecx
f0106936:	89 c6                	mov    %eax,%esi
f0106938:	31 d2                	xor    %edx,%edx
f010693a:	89 e8                	mov    %ebp,%eax
f010693c:	f7 f6                	div    %esi
f010693e:	89 c5                	mov    %eax,%ebp
f0106940:	89 f8                	mov    %edi,%eax
f0106942:	f7 f6                	div    %esi
f0106944:	89 ea                	mov    %ebp,%edx
f0106946:	83 c4 0c             	add    $0xc,%esp
f0106949:	5e                   	pop    %esi
f010694a:	5f                   	pop    %edi
f010694b:	5d                   	pop    %ebp
f010694c:	c3                   	ret    
f010694d:	8d 76 00             	lea    0x0(%esi),%esi
f0106950:	39 e8                	cmp    %ebp,%eax
f0106952:	77 24                	ja     f0106978 <__udivdi3+0x78>
f0106954:	0f bd e8             	bsr    %eax,%ebp
f0106957:	83 f5 1f             	xor    $0x1f,%ebp
f010695a:	75 3c                	jne    f0106998 <__udivdi3+0x98>
f010695c:	8b 74 24 04          	mov    0x4(%esp),%esi
f0106960:	39 34 24             	cmp    %esi,(%esp)
f0106963:	0f 86 9f 00 00 00    	jbe    f0106a08 <__udivdi3+0x108>
f0106969:	39 d0                	cmp    %edx,%eax
f010696b:	0f 82 97 00 00 00    	jb     f0106a08 <__udivdi3+0x108>
f0106971:	8d b4 26 00 00 00 00 	lea    0x0(%esi,%eiz,1),%esi
f0106978:	31 d2                	xor    %edx,%edx
f010697a:	31 c0                	xor    %eax,%eax
f010697c:	83 c4 0c             	add    $0xc,%esp
f010697f:	5e                   	pop    %esi
f0106980:	5f                   	pop    %edi
f0106981:	5d                   	pop    %ebp
f0106982:	c3                   	ret    
f0106983:	90                   	nop
f0106984:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106988:	89 f8                	mov    %edi,%eax
f010698a:	f7 f1                	div    %ecx
f010698c:	31 d2                	xor    %edx,%edx
f010698e:	83 c4 0c             	add    $0xc,%esp
f0106991:	5e                   	pop    %esi
f0106992:	5f                   	pop    %edi
f0106993:	5d                   	pop    %ebp
f0106994:	c3                   	ret    
f0106995:	8d 76 00             	lea    0x0(%esi),%esi
f0106998:	89 e9                	mov    %ebp,%ecx
f010699a:	8b 3c 24             	mov    (%esp),%edi
f010699d:	d3 e0                	shl    %cl,%eax
f010699f:	89 c6                	mov    %eax,%esi
f01069a1:	b8 20 00 00 00       	mov    $0x20,%eax
f01069a6:	29 e8                	sub    %ebp,%eax
f01069a8:	89 c1                	mov    %eax,%ecx
f01069aa:	d3 ef                	shr    %cl,%edi
f01069ac:	89 e9                	mov    %ebp,%ecx
f01069ae:	89 7c 24 08          	mov    %edi,0x8(%esp)
f01069b2:	8b 3c 24             	mov    (%esp),%edi
f01069b5:	09 74 24 08          	or     %esi,0x8(%esp)
f01069b9:	89 d6                	mov    %edx,%esi
f01069bb:	d3 e7                	shl    %cl,%edi
f01069bd:	89 c1                	mov    %eax,%ecx
f01069bf:	89 3c 24             	mov    %edi,(%esp)
f01069c2:	8b 7c 24 04          	mov    0x4(%esp),%edi
f01069c6:	d3 ee                	shr    %cl,%esi
f01069c8:	89 e9                	mov    %ebp,%ecx
f01069ca:	d3 e2                	shl    %cl,%edx
f01069cc:	89 c1                	mov    %eax,%ecx
f01069ce:	d3 ef                	shr    %cl,%edi
f01069d0:	09 d7                	or     %edx,%edi
f01069d2:	89 f2                	mov    %esi,%edx
f01069d4:	89 f8                	mov    %edi,%eax
f01069d6:	f7 74 24 08          	divl   0x8(%esp)
f01069da:	89 d6                	mov    %edx,%esi
f01069dc:	89 c7                	mov    %eax,%edi
f01069de:	f7 24 24             	mull   (%esp)
f01069e1:	39 d6                	cmp    %edx,%esi
f01069e3:	89 14 24             	mov    %edx,(%esp)
f01069e6:	72 30                	jb     f0106a18 <__udivdi3+0x118>
f01069e8:	8b 54 24 04          	mov    0x4(%esp),%edx
f01069ec:	89 e9                	mov    %ebp,%ecx
f01069ee:	d3 e2                	shl    %cl,%edx
f01069f0:	39 c2                	cmp    %eax,%edx
f01069f2:	73 05                	jae    f01069f9 <__udivdi3+0xf9>
f01069f4:	3b 34 24             	cmp    (%esp),%esi
f01069f7:	74 1f                	je     f0106a18 <__udivdi3+0x118>
f01069f9:	89 f8                	mov    %edi,%eax
f01069fb:	31 d2                	xor    %edx,%edx
f01069fd:	e9 7a ff ff ff       	jmp    f010697c <__udivdi3+0x7c>
f0106a02:	8d b6 00 00 00 00    	lea    0x0(%esi),%esi
f0106a08:	31 d2                	xor    %edx,%edx
f0106a0a:	b8 01 00 00 00       	mov    $0x1,%eax
f0106a0f:	e9 68 ff ff ff       	jmp    f010697c <__udivdi3+0x7c>
f0106a14:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106a18:	8d 47 ff             	lea    -0x1(%edi),%eax
f0106a1b:	31 d2                	xor    %edx,%edx
f0106a1d:	83 c4 0c             	add    $0xc,%esp
f0106a20:	5e                   	pop    %esi
f0106a21:	5f                   	pop    %edi
f0106a22:	5d                   	pop    %ebp
f0106a23:	c3                   	ret    
f0106a24:	66 90                	xchg   %ax,%ax
f0106a26:	66 90                	xchg   %ax,%ax
f0106a28:	66 90                	xchg   %ax,%ax
f0106a2a:	66 90                	xchg   %ax,%ax
f0106a2c:	66 90                	xchg   %ax,%ax
f0106a2e:	66 90                	xchg   %ax,%ax

f0106a30 <__umoddi3>:
f0106a30:	55                   	push   %ebp
f0106a31:	57                   	push   %edi
f0106a32:	56                   	push   %esi
f0106a33:	83 ec 14             	sub    $0x14,%esp
f0106a36:	8b 44 24 28          	mov    0x28(%esp),%eax
f0106a3a:	8b 4c 24 24          	mov    0x24(%esp),%ecx
f0106a3e:	8b 74 24 2c          	mov    0x2c(%esp),%esi
f0106a42:	89 c7                	mov    %eax,%edi
f0106a44:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106a48:	8b 44 24 30          	mov    0x30(%esp),%eax
f0106a4c:	89 4c 24 10          	mov    %ecx,0x10(%esp)
f0106a50:	89 34 24             	mov    %esi,(%esp)
f0106a53:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106a57:	85 c0                	test   %eax,%eax
f0106a59:	89 c2                	mov    %eax,%edx
f0106a5b:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106a5f:	75 17                	jne    f0106a78 <__umoddi3+0x48>
f0106a61:	39 fe                	cmp    %edi,%esi
f0106a63:	76 4b                	jbe    f0106ab0 <__umoddi3+0x80>
f0106a65:	89 c8                	mov    %ecx,%eax
f0106a67:	89 fa                	mov    %edi,%edx
f0106a69:	f7 f6                	div    %esi
f0106a6b:	89 d0                	mov    %edx,%eax
f0106a6d:	31 d2                	xor    %edx,%edx
f0106a6f:	83 c4 14             	add    $0x14,%esp
f0106a72:	5e                   	pop    %esi
f0106a73:	5f                   	pop    %edi
f0106a74:	5d                   	pop    %ebp
f0106a75:	c3                   	ret    
f0106a76:	66 90                	xchg   %ax,%ax
f0106a78:	39 f8                	cmp    %edi,%eax
f0106a7a:	77 54                	ja     f0106ad0 <__umoddi3+0xa0>
f0106a7c:	0f bd e8             	bsr    %eax,%ebp
f0106a7f:	83 f5 1f             	xor    $0x1f,%ebp
f0106a82:	75 5c                	jne    f0106ae0 <__umoddi3+0xb0>
f0106a84:	8b 7c 24 08          	mov    0x8(%esp),%edi
f0106a88:	39 3c 24             	cmp    %edi,(%esp)
f0106a8b:	0f 87 e7 00 00 00    	ja     f0106b78 <__umoddi3+0x148>
f0106a91:	8b 7c 24 04          	mov    0x4(%esp),%edi
f0106a95:	29 f1                	sub    %esi,%ecx
f0106a97:	19 c7                	sbb    %eax,%edi
f0106a99:	89 4c 24 08          	mov    %ecx,0x8(%esp)
f0106a9d:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106aa1:	8b 44 24 08          	mov    0x8(%esp),%eax
f0106aa5:	8b 54 24 0c          	mov    0xc(%esp),%edx
f0106aa9:	83 c4 14             	add    $0x14,%esp
f0106aac:	5e                   	pop    %esi
f0106aad:	5f                   	pop    %edi
f0106aae:	5d                   	pop    %ebp
f0106aaf:	c3                   	ret    
f0106ab0:	85 f6                	test   %esi,%esi
f0106ab2:	89 f5                	mov    %esi,%ebp
f0106ab4:	75 0b                	jne    f0106ac1 <__umoddi3+0x91>
f0106ab6:	b8 01 00 00 00       	mov    $0x1,%eax
f0106abb:	31 d2                	xor    %edx,%edx
f0106abd:	f7 f6                	div    %esi
f0106abf:	89 c5                	mov    %eax,%ebp
f0106ac1:	8b 44 24 04          	mov    0x4(%esp),%eax
f0106ac5:	31 d2                	xor    %edx,%edx
f0106ac7:	f7 f5                	div    %ebp
f0106ac9:	89 c8                	mov    %ecx,%eax
f0106acb:	f7 f5                	div    %ebp
f0106acd:	eb 9c                	jmp    f0106a6b <__umoddi3+0x3b>
f0106acf:	90                   	nop
f0106ad0:	89 c8                	mov    %ecx,%eax
f0106ad2:	89 fa                	mov    %edi,%edx
f0106ad4:	83 c4 14             	add    $0x14,%esp
f0106ad7:	5e                   	pop    %esi
f0106ad8:	5f                   	pop    %edi
f0106ad9:	5d                   	pop    %ebp
f0106ada:	c3                   	ret    
f0106adb:	90                   	nop
f0106adc:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106ae0:	8b 04 24             	mov    (%esp),%eax
f0106ae3:	be 20 00 00 00       	mov    $0x20,%esi
f0106ae8:	89 e9                	mov    %ebp,%ecx
f0106aea:	29 ee                	sub    %ebp,%esi
f0106aec:	d3 e2                	shl    %cl,%edx
f0106aee:	89 f1                	mov    %esi,%ecx
f0106af0:	d3 e8                	shr    %cl,%eax
f0106af2:	89 e9                	mov    %ebp,%ecx
f0106af4:	89 44 24 04          	mov    %eax,0x4(%esp)
f0106af8:	8b 04 24             	mov    (%esp),%eax
f0106afb:	09 54 24 04          	or     %edx,0x4(%esp)
f0106aff:	89 fa                	mov    %edi,%edx
f0106b01:	d3 e0                	shl    %cl,%eax
f0106b03:	89 f1                	mov    %esi,%ecx
f0106b05:	89 44 24 08          	mov    %eax,0x8(%esp)
f0106b09:	8b 44 24 10          	mov    0x10(%esp),%eax
f0106b0d:	d3 ea                	shr    %cl,%edx
f0106b0f:	89 e9                	mov    %ebp,%ecx
f0106b11:	d3 e7                	shl    %cl,%edi
f0106b13:	89 f1                	mov    %esi,%ecx
f0106b15:	d3 e8                	shr    %cl,%eax
f0106b17:	89 e9                	mov    %ebp,%ecx
f0106b19:	09 f8                	or     %edi,%eax
f0106b1b:	8b 7c 24 10          	mov    0x10(%esp),%edi
f0106b1f:	f7 74 24 04          	divl   0x4(%esp)
f0106b23:	d3 e7                	shl    %cl,%edi
f0106b25:	89 7c 24 0c          	mov    %edi,0xc(%esp)
f0106b29:	89 d7                	mov    %edx,%edi
f0106b2b:	f7 64 24 08          	mull   0x8(%esp)
f0106b2f:	39 d7                	cmp    %edx,%edi
f0106b31:	89 c1                	mov    %eax,%ecx
f0106b33:	89 14 24             	mov    %edx,(%esp)
f0106b36:	72 2c                	jb     f0106b64 <__umoddi3+0x134>
f0106b38:	39 44 24 0c          	cmp    %eax,0xc(%esp)
f0106b3c:	72 22                	jb     f0106b60 <__umoddi3+0x130>
f0106b3e:	8b 44 24 0c          	mov    0xc(%esp),%eax
f0106b42:	29 c8                	sub    %ecx,%eax
f0106b44:	19 d7                	sbb    %edx,%edi
f0106b46:	89 e9                	mov    %ebp,%ecx
f0106b48:	89 fa                	mov    %edi,%edx
f0106b4a:	d3 e8                	shr    %cl,%eax
f0106b4c:	89 f1                	mov    %esi,%ecx
f0106b4e:	d3 e2                	shl    %cl,%edx
f0106b50:	89 e9                	mov    %ebp,%ecx
f0106b52:	d3 ef                	shr    %cl,%edi
f0106b54:	09 d0                	or     %edx,%eax
f0106b56:	89 fa                	mov    %edi,%edx
f0106b58:	83 c4 14             	add    $0x14,%esp
f0106b5b:	5e                   	pop    %esi
f0106b5c:	5f                   	pop    %edi
f0106b5d:	5d                   	pop    %ebp
f0106b5e:	c3                   	ret    
f0106b5f:	90                   	nop
f0106b60:	39 d7                	cmp    %edx,%edi
f0106b62:	75 da                	jne    f0106b3e <__umoddi3+0x10e>
f0106b64:	8b 14 24             	mov    (%esp),%edx
f0106b67:	89 c1                	mov    %eax,%ecx
f0106b69:	2b 4c 24 08          	sub    0x8(%esp),%ecx
f0106b6d:	1b 54 24 04          	sbb    0x4(%esp),%edx
f0106b71:	eb cb                	jmp    f0106b3e <__umoddi3+0x10e>
f0106b73:	90                   	nop
f0106b74:	8d 74 26 00          	lea    0x0(%esi,%eiz,1),%esi
f0106b78:	3b 44 24 0c          	cmp    0xc(%esp),%eax
f0106b7c:	0f 82 0f ff ff ff    	jb     f0106a91 <__umoddi3+0x61>
f0106b82:	e9 1a ff ff ff       	jmp    f0106aa1 <__umoddi3+0x71>
