TOP_MODULE    := RV32E_CPU 
VERILATOR     := verilator

VL_SRC_DIR    := vsrc
TB_SRC_DIR    := csrc
BUILD_DIR     := build/verilator
INC_DIR       := csrc/include      
VINC_DIR      := vsrc/include 

VL_SRCS       := $(shell find $(abspath $(VL_SRC_DIR)) -name "*.v" -or -name "*.sv")
SRC		  	  := $(shell find $(abspath $(TB_SRC_DIR)) -name "*.c" -or -name "*.cc" -or -name "*.cpp")
MAIN_FILE	  := simulation.cpp
MAIN_FILE_PATH:= $(abspath$(TB_SRC_DIR)/$(MAIN_FILE))
SRC_NOM		  := $(filter-out $(MAIN_FILE_PATH), $(SRC))
TB_SRCS 	   = $(SRC_NOM) $(MAIN_FILE_PATH)

VL_HEADER     := $(BUILD_DIR)/V$(TOP_MODULE).h
SIM_EXE       := $(BUILD_DIR)/V$(TOP_MODULE)
CPU_CORES     ?= 8

DIFF_FLAG	  := --diff=$(NEMU_HOME)/build/riscv32-nemu-interpreter-so

ifneq ($(findstring $(DIFF_FLAG), $(NPC_FLAGS)), $(DIFF_FLAG))
	NPC_FLAGS += $(DIFF_FLAG)
endif

IMG			  ?= $(if $(image),$(image)-riscv32e-npc.bin,)

LDFLAGS += -lreadline -lncurses -lcapstone

LIBCAPSTONE = /home/wf/Desktop/ysyx-workbench/nemu/tools/capstone/repo/libcapstone.so.5
CFLAGS += -I /home/wf/Desktop/ysyx-workbench/nemu/tools/capstone/repo/include
#src/trace/disasm.c: $(LIBCAPSTONE)
$(LIBCAPSTONE):
	$(MAKE) -C /home/wf/Desktop/ysyx-workbench/nemu/tools/capstone

# 阶段1参数：仅生成头文件（无--exe，不关联C++代码）
VL_HEADER_FLAGS := --cc \
	             --top-module $(TOP_MODULE) \
	             --Mdir $(BUILD_DIR) \
	             -Wall \
	             -I$(VINC_DIR)

# 阶段2参数：完整编译（含--exe，关联所有C++代码）
VL_FULL_FLAGS  := --cc --exe --build -j $(CPU_CORES) \
				 --trace \
	             --top-module $(TOP_MODULE) \
	             --Mdir $(BUILD_DIR) \
				 --public-flat-rw \
				 -Wall \
	             -I$(INC_DIR) \
	             -I$(VINC_DIR) \
	             -CFLAGS "-I$(INC_DIR) -std=c++17" \
				 -LDFLAGS "$(LDFLAGS)"

# 阶段1：仅生成Verilator头文件（打破循环依赖
$(VL_HEADER): $(VL_SRCS)
	@echo "===== 阶段1：生成Verilator头文件 ====="
	@mkdir -p $(BUILD_DIR)  # 确保输出目录存在
	@$(VERILATOR) $(VL_HEADER_FLAGS) $(VL_SRCS)

# 阶段2：完整编译（关联C++代码，此时头文件已存在）
$(SIM_EXE): $(VL_HEADER) $(TB_SRCS)
	@echo "===== 阶段2：完整编译Verilog+CPP ====="
	@$(VERILATOR) $(VL_FULL_FLAGS) $(VL_SRCS) $(TB_SRCS)

compile: $(SIM_EXE)

run: compile
	@./$(SIM_EXE) $(NPC_FLAGS) $(IMG)

wave:
#	gtkwave $(BUILD_DIR)/V$(TOP_MODULE).vcd
	gtkwave waveform.vcd

clean:
	@rm -rf $(BUILD_DIR)
	@rm -rf waveform.vcd
	@echo "清除编译文件和波形"

all: run

.PHONY: all compile run wave clean
