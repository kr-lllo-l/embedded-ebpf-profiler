// src/app/main.cpp
#include <iostream>
#include <iomanip>
#include <unistd.h>
#include <signal.h>
#include <bpf/libbpf.h>
#include "profiler.skel.h"
#include "profiler_common.h"

static volatile bool exiting = false;

static void sig_handler(int sig) { exiting = true; }

// Data Callback 
static int handle_event(void *ctx, void *data, size_t data_sz)
{
    const struct event *e = (const struct event *)data;
    
    // ns -> ms
    double latency_us = e->duration_ns / 1000.0;

    // PID, Latency, Name
    std::cout << "PID: " << std::setw(6) << e->pid 
              << " | Latency: " << std::setw(8) << std::fixed << std::setprecision(3) << latency_us << " us"
              << " | Comm: " << e->comm << std::endl;
    return 0;
}

int main(int argc, char **argv)
{
    struct profiler_bpf *skel;
    struct ring_buffer *rb = NULL;
    int err;

    signal(SIGINT, sig_handler);
    signal(SIGTERM, sig_handler);

    // Setup BPF
    skel = profiler_bpf__open();
    if (!skel) return 1;

    err = profiler_bpf__load(skel);
    if (err) {
        std::cerr << "Failed to load BPF skeleton" << std::endl;
        goto cleanup;
    }

    err = profiler_bpf__attach(skel);
    if (err) {
        std::cerr << "Failed to attach BPF skeleton" << std::endl;
        goto cleanup;
    }

    // Setup Ring Buffer
    rb = ring_buffer__new(bpf_map__fd(skel->maps.rb), handle_event, NULL, NULL);
    if (!rb) {
        std::cerr << "Failed to create ring buffer" << std::endl;
        goto cleanup;
    }

    std::cout << " >> CPU Scheduler Latency Profiler << " << std::endl;
    std::cout << "Waiting for events... (Ctrl+C to stop)" << std::endl;

    // Polling Loop
    while (!exiting) {
        err = ring_buffer__poll(rb, 100); // 100ms timeout
        if (err == -EINTR) {
            err = 0;
            break;
        }
        if (err < 0) {
            std::cerr << "Error polling ring buffer" << std::endl;
            break;
        }
    }

cleanup:
    ring_buffer__free(rb);
    profiler_bpf__destroy(skel);
    return -err;
}