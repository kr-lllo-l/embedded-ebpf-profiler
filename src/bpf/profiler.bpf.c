// src/bpf/profiler.bpf.c
#include <linux/bpf.h>
#include <linux/types.h>
#include <linux/version.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>
#include "profiler_common.h"

// type define
typedef __u64 u64;
typedef __u32 u32;
typedef __u32 pid_t;

char LICENSE[] SEC("license") = "Dual BSD/GPL";

// 1. process Wakeup time (Key: PID, Value: Timestamp)
struct {
    __uint(type, BPF_MAP_TYPE_HASH);
    __uint(max_entries, 10240);
    __type(key, u32);
    __type(value, u64);
} start_map SEC(".maps");

// 2. ring Buffer
struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 256 * 1024);
} rb SEC(".maps");

struct sched_wakeup_args {
    unsigned short common_type;
    unsigned char common_flags;
    unsigned char common_preempt_count;
    int common_pid;
    
    char comm[16];
    pid_t pid;
    int prio;
    int success;
    int target_cpu;
};

struct sched_switch_args {
    unsigned short common_type;
    unsigned char common_flags;
    unsigned char common_preempt_count;
    int common_pid;

    char prev_comm[16];
    pid_t prev_pid;
    int prev_prio;
    long prev_state;
    char next_comm[16];
    pid_t next_pid;
    int next_prio;
};

// process Runnging (Runnable status)
SEC("tracepoint/sched/sched_wakeup")
int handle_sched_wakeup(struct sched_wakeup_args *ctx)
{
    u32 pid = ctx->pid;
    u64 ts = bpf_ktime_get_ns();

    // wakeup time 
    bpf_map_update_elem(&start_map, &pid, &ts, BPF_ANY);
    return 0;
}

// process CPU resource 획득 ? (Running status)
SEC("tracepoint/sched/sched_switch")
int handle_sched_switch(struct sched_switch_args *ctx)
{
    u32 prev_pid = ctx->prev_pid;
    u32 next_pid = ctx->next_pid;
    u64 *tsp;

    if (next_pid == 0) return 0;

    
    bpf_map_delete_elem(&start_map, &prev_pid);

    tsp = bpf_map_lookup_elem(&start_map, &next_pid);
    if (!tsp) return 0; 

    u64 duration_ns = bpf_ktime_get_ns() - *tsp;
    bpf_map_delete_elem(&start_map, &next_pid); 

    struct event *e;
    e = bpf_ringbuf_reserve(&rb, sizeof(*e), 0);
    if (!e) return 0;

    e->pid = next_pid;
    e->duration_ns = duration_ns;

    __builtin_memcpy(e->comm, ctx->next_comm, 16);

    bpf_ringbuf_submit(e, 0);

    return 0;
}