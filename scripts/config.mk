#***************************************************************************************
# Copyright (c) 2014-2021 Zihao Yu, Nanjing University
#
# NEMU is licensed under Mulan PSL v2.
# You can use this software according to the terms and conditions of the Mulan PSL v2.
# You may obtain a copy of Mulan PSL v2 at:
#          http://license.coscl.org.cn/MulanPSL2
#
# THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
# EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
# MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
#
# See the Mulan PSL v2 for more details.
#**************************************************************************************/

COLOR_RED := $(shell echo "\033[1;31m")
COLOR_END := $(shell echo "\033[0m")

ifeq ($(wildcard .config),)
$(warning $(COLOR_RED)Warning: .config does not exists!$(COLOR_END))
$(warning $(COLOR_RED)To build the project, first run 'make menuconfig'.$(COLOR_END))
endif

Q            := @
KCONFIG_PATH := $(NEMU_HOME)/tools/kconfig
FIXDEP_PATH  := $(NEMU_HOME)/tools/fixdep
Kconfig      := $(NEMU_HOME)/Kconfig
rm-distclean += include/generated include/config .config .config.old
silent := -s

CONF   := $(KCONFIG_PATH)/build/conf
MCONF  := $(KCONFIG_PATH)/build/mconf
FIXDEP := $(FIXDEP_PATH)/build/fixdep

LIB_CPT_PATH = resource/gcpt_restore
CPT_BIN = $(LIB_CPT_PATH)/build/gcpt.bin
CPT_LAYOUT_HEADER = $(LIB_CPT_PATH)/src/restore_rom_addr.h

CPT_CROSS_COMPILE ?= riscv64-unknown-linux-gnu-
ifeq ($(shell which $(CPT_CROSS_COMPILE)gcc 2>/dev/null),)
    CPT_CROSS_COMPILE := riscv64-unknown-elf-
    ifeq ($(shell which $(CPT_CROSS_COMPILE)gcc 2>/dev/null),)
        $(error Neither riscv64-unknown-linux-gnu-gcc nor riscv64-unknown-elf-gcc could be found in your PATH)
    endif
endif
$(info Using cross compiler prefix: $(CPT_CROSS_COMPILE))

$(CPT_LAYOUT_HEADER):
	$(shell git clone https://github.com/OpenXiangShan/LibCheckpointAlpha.git $(LIB_CPT_PATH))

$(CPT_BIN): $(CPT_LAYOUT_HEADER)
	$(Q)$(MAKE) $(silent) -C $(LIB_CPT_PATH) CROSS_COMPILE=$(CPT_CROSS_COMPILE)

$(CONF):
	$(Q)$(MAKE) $(silent) -C $(KCONFIG_PATH) NAME=conf

$(MCONF):
	$(Q)$(MAKE) $(silent) -C $(KCONFIG_PATH) NAME=mconf

$(FIXDEP):
	$(Q)$(MAKE) $(silent) -C $(FIXDEP_PATH)

menuconfig: $(MCONF) $(CONF) $(FIXDEP)
	$(Q)$(MCONF) $(Kconfig)
	$(Q)$(CONF) $(silent) --syncconfig $(Kconfig)

savedefconfig: $(CONF)
	$(Q)$< $(silent) --$@=configs/defconfig $(Kconfig)

%defconfig: $(CONF) $(FIXDEP) $(CPT_LAYOUT_HEADER) $(CPT_BIN)
	$(Q)$< $(silent) --defconfig=configs/$@ $(Kconfig)
	$(Q)$< $(silent) --syncconfig $(Kconfig)

.PHONY: menuconfig savedefconfig defconfig

# Help text used by make help
help:
	@echo  '  menuconfig	  - Update current config utilising a menu based program'
	@echo  '  savedefconfig   - Save current config as configs/defconfig (minimal config)'

distclean: clean
	-@rm -rf $(rm-distclean)

.PHONY: help distclean

define call_fixdep
	@$(FIXDEP) $(1) $(2) unused > $(1).tmp
	@mv $(1).tmp $(1)
endef
