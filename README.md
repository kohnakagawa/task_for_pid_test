# task_for_pid Test Suite

A testing suite for analyzing `task_for_pid` access permissions on macOS across different code signing configurations, Hardened Runtime settings, and entitlements. This project supports both x86_64 and arm64 architectures and provides detailed analysis of task port acquisition methods.

## Overview

This project creates multiple target executables with different code signing and entitlement configurations to test `task_for_pid` access permissions. It includes both traditional `task_for_pid()` API calls and an alternative method using processor set enumeration (based on SpecterOps research).

## Target Executables

The project builds 5 different target executables for each architecture:

- **A**: Unsigned executable (only for x86_64)
- **B**: Ad-hoc signed (no Hardened Runtime)
- **C**: Ad-hoc signed + Hardened Runtime enabled
- **D**: Ad-hoc signed + Hardened Runtime + `com.apple.security.get-task-allow` entitlement
- **E**: Ad-hoc signed (no Hardened Runtime) + `com.apple.security.get-task-allow` entitlement

## Usage

### Build all targets
```bash
make all
```

### Build for specific architecture
```bash
make all_x86_64    # Build x86_64 targets
make all_arm64     # Build arm64 targets
```

### Run tests for current architecture
```bash
sudo make run
```

### Run tests for specific architecture
```bash
sudo make run_x86_64    # Test x86_64 targets
sudo make run_arm64     # Test arm64 targets
```

### Check signatures and entitlements
```bash
make check_sig_x86_64   # Check x86_64 binaries
make check_sig_arm64    # Check arm64 binaries
```

### Clean build artifacts
```bash
make clean
```

## References

- [SpecterOps: Armed and Dangerous - Dylib Injection on macOS](https://specterops.io/blog/2025/08/21/armed-and-dangerous-dylib-injection-on-macos/)