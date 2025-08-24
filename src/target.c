#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <signal.h>

static volatile int keep_running = 1;

void on_sigint(int sig) {
    (void)sig;
    keep_running = 0;
}

int main(void) {
    signal(SIGINT, on_sigint);
    signal(SIGTERM, on_sigint);
    pid_t pid = getpid();
    printf("target started (pid=%d)\n", (int)pid);
    fflush(stdout);
    // Stay alive until killed
    while (keep_running) {
        sleep(1);
    }
    return 0;
}
