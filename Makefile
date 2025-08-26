# macOS task_for_pid condition tester for x86_64 and arm64
# Build binaries:
#  A_x86_64: unsigned target (x86_64)
#  A_arm64: unsigned target (arm64)
#  B_x86_64: ad-hoc signed target, no Hardened Runtime (x86_64)
#  B_arm64: ad-hoc signed target, no Hardened Runtime (arm64)
#  C_x86_64: ad-hoc signed target with Hardened Runtime (x86_64)
#  C_arm64: ad-hoc signed target with Hardened Runtime (arm64)
#  D_x86_64: ad-hoc signed target with Hardened Runtime + get-task-allow entitlement (x86_64)
#  D_arm64: ad-hoc signed target with Hardened Runtime + get-task-allow entitlement (arm64)
#  E_x86_64: ad-hoc signed target, no Hardened Runtime + get-task-allow entitlement (x86_64)
#  E_arm64: ad-hoc signed target, no Hardened Runtime + get-task-allow entitlement (arm64)
#  F: checker that calls task_for_pid(pid) with com.apple.security.cs.debugger entitlement

CC=cc
CFLAGS=-Wall -O2
# Use current directory if PWD is not set (e.g., when running with sudo)
CURRENT_DIR := $(shell pwd)
BIN=$(CURRENT_DIR)/bin
SRC=$(CURRENT_DIR)/src

# Detect current architecture
CURRENT_ARCH := $(shell uname -m)
# Set target architectures (x86_64 for Intel, arm64 for Apple Silicon)
ifeq ($(CURRENT_ARCH),x86_64)
    TARGET_ARCHS := x86_64
    NATIVE_ARCH := x86_64
else ifeq ($(CURRENT_ARCH),arm64)
    TARGET_ARCHS := arm64
    NATIVE_ARCH := arm64
else
    # If we can't determine, try both
    TARGET_ARCHS := x86_64 arm64
    NATIVE_ARCH := $(CURRENT_ARCH)
endif

# x86_64 targets
A_x86_64=$(BIN)/target_A_x86_64
B_x86_64=$(BIN)/target_B_x86_64
C_x86_64=$(BIN)/target_C_x86_64
D_x86_64=$(BIN)/target_D_x86_64
E_x86_64=$(BIN)/target_E_x86_64

# arm64 targets
A_arm64=$(BIN)/target_A_arm64
B_arm64=$(BIN)/target_B_arm64
C_arm64=$(BIN)/target_C_arm64
D_arm64=$(BIN)/target_D_arm64
E_arm64=$(BIN)/target_E_arm64

# Checker
F=$(BIN)/check_task

all: $(A_x86_64) $(A_arm64) $(B_x86_64) $(B_arm64) $(C_x86_64) $(C_arm64) $(D_x86_64) $(D_arm64) $(E_x86_64) $(E_arm64) $(F)

# Build for specific architecture
all_x86_64: $(A_x86_64) $(B_x86_64) $(C_x86_64) $(D_x86_64) $(E_x86_64) $(F)
	@echo "Built for x86_64 architecture"

all_arm64: $(A_arm64) $(B_arm64) $(C_arm64) $(D_arm64) $(E_arm64) $(F)
	@echo "Built for arm64 architecture"

$(BIN):
	@mkdir -p $(BIN)

# x86_64 targets
$(A_x86_64): $(BIN) $(SRC)/target.c
	$(CC) $(CFLAGS) -arch x86_64 -o $@ $(SRC)/target.c
	@codesign --remove-signature $@

$(A_arm64): $(BIN) $(SRC)/target.c
	$(CC) $(CFLAGS) -arch arm64 -o $@ $(SRC)/target.c
	@codesign --remove-signature $@

# x86_64 targets
$(B_x86_64): $(A_x86_64)
	@cp $(A_x86_64) $(B_x86_64)
	# Ad-hoc sign without Hardened Runtime
	@codesign -s - $(B_x86_64) >/dev/null 2>&1 || (echo "codesign failed for B_x86_64 (ad-hoc). Ensure you're on macOS."; exit 1)

$(C_x86_64): $(A_x86_64)
	@cp $(A_x86_64) $(C_x86_64)
	# Ad-hoc sign WITH Hardened Runtime
	@codesign -s - --options runtime $(C_x86_64) >/dev/null 2>&1 || (echo "codesign failed for C_x86_64 (ad-hoc + hardened runtime)."; exit 1)

$(D_x86_64): $(A_x86_64)
	@cp $(A_x86_64) $(D_x86_64)
	# Ad-hoc sign WITH Hardened Runtime + get-task-allow entitlement
	@echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.get-task-allow</key><true/></dict></plist>' > /tmp/entitlements.plist
	@codesign -s - --options runtime --entitlements /tmp/entitlements.plist $(D_x86_64) >/dev/null 2>&1 || (echo "codesign failed for D_x86_64 (ad-hoc + hardened runtime + get-task-allow)."; exit 1)
	@rm -f /tmp/entitlements.plist

$(E_x86_64): $(A_x86_64)
	@cp $(A_x86_64) $(E_x86_64)
	# Ad-hoc sign (no Hardened Runtime) + get-task-allow entitlement
	@echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.get-task-allow</key><true/></dict></plist>' > /tmp/entitlements.plist
	@codesign -s - --entitlements /tmp/entitlements.plist $(E_x86_64) >/dev/null 2>&1 || (echo "codesign failed for E_x86_64 (ad-hoc + get-task-allow)."; exit 1)
	@rm -f /tmp/entitlements.plist

# arm64 targets
$(B_arm64): $(A_arm64)
	@cp $(A_arm64) $(B_arm64)
	# Ad-hoc sign without Hardened Runtime
	@codesign -s - $(B_arm64) >/dev/null 2>&1 || (echo "codesign failed for B_arm64 (ad-hoc). Ensure you're on macOS."; exit 1)

$(C_arm64): $(A_arm64)
	@cp $(A_arm64) $(C_arm64)
	@codesign -s - --options runtime $(C_arm64) >/dev/null 2>&1 || (echo "codesign failed for C_arm64 (ad-hoc + hardened runtime)."; exit 1)

$(D_arm64): $(A_arm64)
	@cp $(A_arm64) $(D_arm64)
	# Ad-hoc sign WITH Hardened Runtime + get-task-allow entitlement
	@echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.get-task-allow</key><true/></dict></plist>' > /tmp/entitlements.plist
	@codesign -s - --options runtime --entitlements /tmp/entitlements.plist $(D_arm64) >/dev/null 2>&1 || (echo "codesign failed for D_arm64 (ad-hoc + hardened runtime + get-task-allow)."; exit 1)
	@rm -f /tmp/entitlements.plist

$(E_arm64): $(A_arm64)
	@cp $(A_arm64) $(E_arm64)
	# Ad-hoc sign (no Hardened Runtime) + get-task-allow entitlement
	@echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.get-task-allow</key><true/></dict></plist>' > /tmp/entitlements.plist
	@codesign -s - --entitlements /tmp/entitlements.plist $(E_arm64) >/dev/null 2>&1 || (echo "codesign failed for E_arm64 (ad-hoc + get-task-allow)."; exit 1)
	@rm -f /tmp/entitlements.plist

$(F): $(BIN) $(SRC)/check_task.c
	$(CC) $(CFLAGS) -o $@ $(SRC)/check_task.c

add_cs_debugger: $(F)
	@echo '<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>com.apple.security.cs.debugger</key><true/></dict></plist>' > /tmp/debugger_entitlements.plist
	codesign -s - --entitlements /tmp/debugger_entitlements.plist $(F) >/dev/null 2>&1 || (echo "codesign failed for check_task (ad-hoc + cs.debugger entitlement)."; exit 1)
	@rm -f /tmp/debugger_entitlements.plist

clean:
	@rm -rf $(BIN) .pidA_x86_64 .pidB_x86_64 .pidC_x86_64 .pidD_x86_64 .pidE_x86_64 .pidA_arm64 .pidB_arm64 .pidC_arm64 .pidD_arm64 .pidE_arm64

# Build everything and run the experiment for current architecture
run: all
	@echo "Launching targets for current architecture..."
	@if [ "$(CURRENT_ARCH)" = "x86_64" ]; then \
		$(MAKE) run_x86_64; \
	elif [ "$(CURRENT_ARCH)" = "arm64" ]; then \
		$(MAKE) run_arm64; \
	else \
		echo "Unknown architecture: $(CURRENT_ARCH)"; \
		exit 1; \
	fi

# Run experiment for x86_64 architecture
run_x86_64: all_x86_64
	@echo "Launching x86_64 targets..."
	@$(A_x86_64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidA_x86_64
	@sleep 1
	@$(B_x86_64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidB_x86_64
	@sleep 1
	@$(C_x86_64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidC_x86_64
	@sleep 1
	@$(D_x86_64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidD_x86_64
	@sleep 1
	@$(E_x86_64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidE_x86_64
	@sleep 1
	@PID_A=$$(cat .pidA_x86_64); PID_B=$$(cat .pidB_x86_64); PID_C=$$(cat .pidC_x86_64); PID_D=$$(cat .pidD_x86_64); PID_E=$$(cat .pidE_x86_64); \
	echo ""; \
	echo "=== Checking task_for_pid access for x86_64 (caller: $$($(F) --whoami)) ==="; \
	echo ""; \
	echo "--- Traditional method (task_for_pid) ---"; \
	printf "%-22s %-8s %-s\n" "Target" "PID" "Result"; \
	echo "---------------------------------------------"; \
	printf "%-22s %-8s " "A_x86_64 (unsigned)" $$PID_A; $(F) --method traditional $$PID_A | tail -1; \
	printf "%-22s %-8s " "B_x86_64 (ad-hoc, no HR)" $$PID_B; $(F) --method traditional $$PID_B | tail -1; \
	printf "%-22s %-8s " "C_x86_64 (ad-hoc + HR)" $$PID_C; $(F) --method traditional $$PID_C | tail -1; \
	printf "%-22s %-8s " "D_x86_64 (ad-hoc + HR + get-task-allow)" $$PID_D; $(F) --method traditional $$PID_D | tail -1; \
	printf "%-22s %-8s " "E_x86_64 (ad-hoc, no HR + get-task-allow)" $$PID_E; $(F) --method traditional $$PID_E | tail -1; \
	echo ""; \
	echo "--- Wrapper method (processor set enumeration) ---"; \
	printf "%-22s %-8s %-s\n" "Target" "PID" "Result"; \
	echo "---------------------------------------------"; \
	printf "%-22s %-8s " "A_x86_64 (unsigned)" $$PID_A; $(F) --method wrapper $$PID_A | tail -1; \
	printf "%-22s %-8s " "B_x86_64 (ad-hoc, no HR)" $$PID_B; $(F) --method wrapper $$PID_B | tail -1; \
	printf "%-22s %-8s " "C_x86_64 (ad-hoc + HR)" $$PID_C; $(F) --method wrapper $$PID_C | tail -1; \
	printf "%-22s %-8s " "D_x86_64 (ad-hoc + HR + get-task-allow)" $$PID_D; $(F) --method wrapper $$PID_D | tail -1; \
	printf "%-22s %-8s " "E_x86_64 (ad-hoc, no HR + get-task-allow)" $$PID_E; $(F) --method wrapper $$PID_E | tail -1; \
	echo ""; \
	echo "Raw outputs (Traditional method):"; \
	echo " A_x86_64:"; $(F) --method traditional $$PID_A; \
	echo " B_x86_64:"; $(F) --method traditional $$PID_B; \
	echo " C_x86_64:"; $(F) --method traditional $$PID_C; \
	echo " D_x86_64:"; $(F) --method traditional $$PID_D; \
	echo " E_x86_64:"; $(F) --method traditional $$PID_E; \
	echo ""; \
	echo "Raw outputs (Wrapper method):"; \
	echo " A_x86_64:"; $(F) --method wrapper $$PID_A; \
	echo " B_x86_64:"; $(F) --method wrapper $$PID_B; \
	echo " C_x86_64:"; $(F) --method wrapper $$PID_C; \
	echo " D_x86_64:"; $(F) --method wrapper $$PID_D; \
	echo " E_x86_64:"; $(F) --method wrapper $$PID_E; \
	kill $$PID_A $$PID_B $$PID_C $$PID_D $$PID_E >/dev/null 2>&1 || true; \
	rm -f .pidA_x86_64 .pidB_x86_64 .pidC_x86_64 .pidD_x86_64 .pidE_x86_64

# Run experiment for arm64 architecture
run_arm64: all_arm64
	@echo "Launching arm64 targets..."
	@$(A_arm64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidA_arm64
	@sleep 1
	@$(B_arm64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidB_arm64
	@sleep 1
	@$(C_arm64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidC_arm64
	@sleep 1
	@$(D_arm64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidD_arm64
	@sleep 1
	@$(E_arm64) >/dev/null 2>&1 & echo $$! > $(CURRENT_DIR)/.pidE_arm64
	@sleep 1
	@PID_A=$$(cat .pidA_arm64); PID_B=$$(cat .pidB_arm64); PID_C=$$(cat .pidC_arm64); PID_D=$$(cat .pidD_arm64); PID_E=$$(cat .pidE_arm64); \
	echo ""; \
	echo "=== Checking task_for_pid access for arm64 (caller: $$($(F) --whoami)) ==="; \
	echo ""; \
	echo "--- Traditional method (task_for_pid) ---"; \
	printf "%-22s %-8s %-s\n" "Target" "PID" "Result"; \
	echo "---------------------------------------------"; \
	printf "%-22s %-8s " "A_arm64 (unsigned)" $$PID_A; $(F) --method traditional $$PID_A | tail -1; \
	printf "%-22s %-8s " "B_arm64 (ad-hoc, no HR)" $$PID_B; $(F) --method traditional $$PID_B | tail -1; \
	printf "%-22s %-8s " "C_arm64 (ad-hoc + HR)" $$PID_C; $(F) --method traditional $$PID_C | tail -1; \
	printf "%-22s %-8s " "D_arm64 (ad-hoc + HR + get-task-allow)" $$PID_D; $(F) --method traditional $$PID_D | tail -1; \
	printf "%-22s %-8s " "E_arm64 (ad-hoc, no HR + get-task-allow)" $$PID_E; $(F) --method traditional $$PID_E | tail -1; \
	echo ""; \
	echo "--- Wrapper method (processor set enumeration) ---"; \
	printf "%-22s %-8s %-s\n" "Target" "PID" "Result"; \
	echo "---------------------------------------------"; \
	printf "%-22s %-8s " "A_arm64 (unsigned)" $$PID_A; $(F) --method wrapper $$PID_A | tail -1; \
	printf "%-22s %-8s " "B_arm64 (ad-hoc, no HR)" $$PID_B; $(F) --method wrapper $$PID_B | tail -1; \
	printf "%-22s %-8s " "C_arm64 (ad-hoc + HR)" $$PID_C; $(F) --method wrapper $$PID_C | tail -1; \
	printf "%-22s %-8s " "D_arm64 (ad-hoc + HR + get-task-allow)" $$PID_D; $(F) --method wrapper $$PID_D | tail -1; \
	printf "%-22s %-8s " "E_arm64 (ad-hoc, no HR + get-task-allow)" $$PID_E; $(F) --method wrapper $$PID_E | tail -1; \
	echo ""; \
	echo "Raw outputs (Traditional method):"; \
	echo " A_arm64:"; $(F) --method traditional $$PID_A; \
	echo " B_arm64:"; $(F) --method traditional $$PID_B; \
	echo " C_arm64:"; $(F) --method traditional $$PID_C; \
	echo " D_arm64:"; $(F) --method traditional $$PID_D; \
	echo " E_arm64:"; $(F) --method traditional $$PID_E; \
	echo ""; \
	echo "Raw outputs (Wrapper method):"; \
	echo " A_arm64:"; $(F) --method wrapper $$PID_A; \
	echo " B_arm64:"; $(F) --method wrapper $$PID_B; \
	echo " C_arm64:"; $(F) --method wrapper $$PID_C; \
	echo " D_arm64:"; $(F) --method wrapper $$PID_D; \
	echo " E_arm64:"; $(F) --method wrapper $$PID_E; \
	kill $$PID_A $$PID_B $$PID_C $$PID_D $$PID_E >/dev/null 2>&1 || true; \
	rm -f .pidA_arm64 .pidB_arm64 .pidC_arm64 .pidD_arm64 .pidE_arm64

# Check signatures and entitlements of all binaries
check_sig: all

# Check signatures for specific architecture
check_sig_x86_64: $(A_x86_64) $(B_x86_64) $(C_x86_64) $(D_x86_64) $(E_x86_64) $(F)
	@echo "=== Checking signatures and entitlements (x86_64) ==="
	@echo ""
	@for target in $(A_x86_64) $(B_x86_64) $(C_x86_64) $(D_x86_64) $(E_x86_64) $(F); do \
		echo "$$(basename $$target):"; \
		echo "  Code signature:"; \
		if codesign -dv "$$target" >/dev/null 2>&1; then \
			echo "    ✓ Present"; \
		else \
			echo "    ✗ Not present"; \
		fi; \
		echo "  Hardened Runtime:"; \
		if codesign -dv "$$target" 2>&1 | grep -q "runtime"; then \
			echo "    ✓ Enabled"; \
		else \
			echo "    ✗ Disabled"; \
		fi; \
		echo "  Entitlements:"; \
		entitlements=$$(codesign -d --entitlements :- "$$target" 2>/dev/null | grep -A 20 "<dict>" | grep -v "^--$$" | sed 's/^/    /'); \
		if [ -n "$$entitlements" ]; then \
			echo "$$entitlements"; \
		else \
			echo "    None"; \
		fi; \
		echo ""; \
	done

check_sig_arm64: $(A_arm64) $(B_arm64) $(C_arm64) $(D_arm64) $(E_arm64) $(F)
	@echo "=== Checking signatures and entitlements (arm64) ==="
	@echo ""
	@for target in $(A_arm64) $(B_arm64) $(C_arm64) $(D_arm64) $(E_arm64) $(F); do \
		echo "$$(basename $$target):"; \
		echo "  Code signature:"; \
		if codesign -dv "$$target" >/dev/null 2>&1; then \
			echo "    ✓ Present"; \
		else \
			echo "    ✗ Not present"; \
		fi; \
		echo "  Hardened Runtime:"; \
		if codesign -dv "$$target" 2>&1 | grep -q "runtime"; then \
			echo "    ✓ Enabled"; \
		else \
			echo "    ✗ Disabled"; \
		fi; \
		echo "  Entitlements:"; \
		entitlements=$$(codesign -d --entitlements :- "$$target" 2>/dev/null | grep -A 20 "<dict>" | grep -v "^--$$" | sed 's/0/    /'); \
		if [ -n "$$entitlements" ]; then \
			echo "$$entitlements"; \
		else \
			echo "    None"; \
		fi; \
		echo ""; \
	done

.PHONY: all all_x86_64 all_arm64 clean run run_x86_64 run_arm64 check_sig check_sig_x86_64 check_sig_arm64
