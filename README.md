Kunwind support for LTTng
=========================

Kunwind can recover the backtrace (or callstack) of a process in userspace from the kernel. This integration prototype aims at exploring the integration of kunwind to the LTTng kernel tracer.

The backtrace can be used for tracing, debugging and profiling purpose. One example is locating syscalls in a program. For example, here is an example of the unwind backtrace attached to system call event context:

## Setup ##
This setup was tested on Ubuntu 16.04.01 with Linux 4.4.0-47-generic.

**Compile and install the required kernel modules**

Note: remove any previous lttng modules, they will conflict because the build installs the modules in a sub-directory instead of overwriting the currently installed modules.
```
sudo rm -rf /lib/modules/$(uname -r)/extra
cd lttng-kunwind/
make
sudo make modules_install
sudo depmod -a
```

**Compile and install lttng-tools with callstack support**
```
cd lttng-tools
./bootstrap
./configure --without-lttng-ust
make
sudo make install
sudo ldconfig
cd ..
```

**Compile the libkunwind library and tests**

The `make check` compiles the library and the tests. The test requires `libunwind8-dev` and compares the result returned by the kernel to the result of libunwind.

```
sudo modprobe kunwind-debug
cd kunwind/libkunwind/
./bootstrap
./configure
make
make check
cd ../../
```

**Load the modules and launch lttng-sessiond**

Verify that your user is in the tracing group, load the modules and start the daemon. 
```
sudo groupadd tracing
sudo usermod -a -G tracing $USER
newgrp tracing
sudo modprobe kunwind-debug
sudo lttng-sessiond -d
```

Then, run the experiment and see the produced trace:
```
./run.sh
babeltrace trace-test-basic
[15:23:14.743513595] (+0.000008146) kunwind syscall_entry_ioctl: { cpu_id = 0 }, { _callstack_user_unwind_length = 8, callstack_user_unwind = [ [0] = 0x7FFFF7166687, [1] = 0x401F6B, [2] = 0x4022A0, [3] = 0x4022C0, [4] = 0x4022E0, [5] = 0x40190A, [6] = 0x7FFFF708A82F, [7] = 0x4019C8 ] }, { fd = 3, cmd = 63122, arg = 6381168 }
```

Babeltrace does not resolve the symbols for a given address yet, but for functions in the executable, the addresses correspond to symbols given by `nm kunwind/libkunwind/tests/.libs/test-basic`.

Rationale
---------

Unwinding the call stack is necessary when the assembly code does not save the frame pointer on the stack, enabled by the `-fomit-frame-pointer` option. Today, all major Linux distributions ships executables and shared libraries compiled with this optimization. 

The Linux `perf` tool copy two pages of the stack and does the unwind offline. This method may leak sensitive data on the stack. It produces large traces (8KiB per-event) and there is no guarantee that two pages are actually enough to recover the complete backtrace. There are also an option to use hardware features, such as Last-Branch-Record, but that is known to cause large overhead.

Locating system call can also be achieved with `ptrace()`, but at the cost of a major slowdown (see [WAMS](https://github.com/giraldeau/wams) and [strace-plus](https://github.com/pgbovine/strace-plus)). With such a high overhead, operation timeouts (for instance network requests) can cause unexpected failure. Every system call made by the monitored process forces a context switch and libunwind performs thousands of `PTRACE_PEEK` to unwind the call stack, which can take several miliseconds.

Kunwind can do the same job, but has these benefits:

 - Walks the call stack in the low microsecond range for typical application
 - Produces no context switch compared to `ptrace()`
 - Prevents stack data leak
 - Produces smaller traces compared to Linux `perf`
 - Portable: based on DWARF standard and does not depend on an esoteric hardware feature

