KDIR ?= /lib/modules/`uname -r`/build

default: modules

modules:
	$(MAKE) -C $(KDIR) M=$$PWD CONFIG_KUNWIND_DEBUG=m CONFIG_LTTNG=m modules

modules_install:
	$(MAKE) -C $(KDIR) M=$$PWD CONFIG_KUNWIND_DEBUG=m CONFIG_LTTNG=m modules_install

clean:
	$(MAKE) -C $(KDIR) M=$$PWD clean

%.i: %.c
	$(MAKE) -C $(KDIR) M=$$PWD CONFIG_KUNWIND_DEBUG=m CONFIG_LTTNG=m $@

