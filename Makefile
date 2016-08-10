BOARD ?= arduino_101_factory
KERNEL ?= micro

JS_DEFAULT = samples/HelloWorld.js

ifndef JERRY_BASE
$(error JERRY_BASE not defined)
endif

# Build for x86, default target
.PHONY: x86
x86: analyze generate
	make -f Makefile.x86 BOARD=$(BOARD) KERNEL=$(KERNEL)

.PHONY: analyze
analyze:
	@cat src/Makefile.base > src/Makefile
ifdef JS
	@echo "ccflags-y += $(shell ./scripts/analyze.sh $(JS))" >> src/Makefile
else
	@echo "ccflags-y += $(shell ./scripts/analyze.sh $(JS_DEFAULT))" >> src/Makefile
endif

.PHONY: all
all: x86 arc

# Check if a clean is needed before building
ifneq ("$(wildcard .$(BOARD).last_build)", "")
PRE_ACTION=
else
PRE_ACTION=clean
endif

# Update dependency repos using deps/repos.txt
.PHONY: update
update:
	@cd deps/; \
	while read line; do \
		case \
			"$$line" in \#*) \
				continue ;; \
			*) \
				name=$$(echo $$line | cut -d ' ' -f 1); \
				repo=$$(echo $$line | cut -d ' ' -f 2); \
				commit=$$(echo $$line | cut -d ' ' -f 3); \
				if [ ! -d $$name ]; then \
					git clone $$repo $$name; \
				fi; \
				cd $$name; \
				git checkout $$commit; \
				cd ..; \
				continue ;; \
		esac \
	done < repos.txt

# Sets up prj/last_build files
.PHONY: setup
setup: update
	# Copy 256/216k board files to zephyr tree
	rsync -a deps/overlay-zephyr/ deps/zephyr/
	@if [ $(BOARD) != qemu_x86 ]; then \
		cp prj.conf.arduino_101_factory prj.conf; \
	else \
		cp prj.conf.qemu_x86 prj.conf; \
	fi
	# Remove .last_build file
	rm -f .*.last_build
	@echo "" > .$(BOARD).last_build

# Explicit clean
.PHONY: clean
clean:
	@if [ -d deps/zephyr ]; then \
		make -f Makefile.x86 clean; \
	fi
	@if [ -d deps/jerryscript ]; then \
		make -C $(JERRY_BASE) -f targets/zephyr/Makefile.zephyr clean; \
		make -C $(JERRY_BASE) -f targets/zephyr/Makefile clean; \
		rm -rf deps/jerryscript/build/$(BOARD)/; \
	fi
	cd arc; make clean

# Flash Arduino 101 x86 image
.PHONY: dfu
dfu:
	dfu-util -a x86_app -D outdir/zephyr.bin

# Flash Arduino 101 ARC image
.PHONY: dfu-arc
dfu-arc:
	dfu-util -a sensor_core -D arc/outdir/zephyr.bin

# Flash both
.PHONY: dfu-all
dfu-all: dfu dfu-arc

# Generate the script file from the JS variable
.PHONY: generate
generate: setup $(PRE_ACTION)
ifdef JS
	./scripts/convert.sh $(JS) src/zjs_script_gen.c
else
	./scripts/convert.sh $(JS_DEFAULT) src/zjs_script_gen.c
endif

# Run QEMU target
.PHONY: qemu
ifdef JS
qemu: analyze generate
else
qemu: setup $(PRE_ACTION)
endif
	make -f Makefile.x86 BOARD=qemu_x86 KERNEL=$(KERNEL) qemu

# Builds ARC binary
.PHONY: arc
arc:
ifeq ($(BOARD), arduino_101_factory_256)
	cd arc/; make BOARD=arduino_101_sss_factory_256
else
	cd arc/; make BOARD=arduino_101_sss_factory
endif

# Run debug server over JTAG
.PHONY: debug
debug:
	make -f Makefile.x86 BOARD=arduino_101 debugserver

# Run gdb to connect to debug server for x86
.PHONY: gdb
gdb:
	gdb outdir/zephyr.elf -ex "target remote :3333"

# Run gdb to connect to debug server for ARC
.PHONY: arcgdb
arcgdb:
	$$ZEPHYR_SDK_INSTALL_DIR/sysroots/i686-pokysdk-linux/usr/bin/arc-poky-elf/arc-poky-elf-gdb arc/outdir/zephyr.elf -ex "target remote :3334"

.PHONY: help
help:
	@echo "Build targets:"
	@echo "    x86:       Build the main x86 core target (default)"
	@echo "    arc:       Build the ARC core target"
	@echo "    all:       Build the x86 and arc targets"
	@echo "    dfu:       Flash the x86 core binary with dfu-util"
	@echo "    dfu-arc:   Flash the ARC binary with dfu-util"
	@echo "    dfu-all:   Flash both binaries with dfu-util"
	@echo "    debug:     Run debug server using JTAG"
	@echo "    gdb:       Run gdb to connect to debug server for x86"
	@echo "    arcgdb:    Run gdb to connect to debug server for ARC"
	@echo "    qemu:      Run QEMU after building"
	@echo "    clean:     Clean stale build objects"
	@echo "    setup:     Sets up dependencies"
	@echo "    update:    Updates dependencies"
	@echo
	@echo "Build options:"
	@echo "    BOARD=     Specify a Zephyr board to build for"
	@echo "    JS=        Specify a JS script to compile into the binary"
	@echo "    KERNEL=    Specify the kernel to use (micro or nano)"
