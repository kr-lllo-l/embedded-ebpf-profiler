// src/include/profiler_common.h
#ifndef __PROFILER_COMMON_H__
#define __PROFILER_COMMON_H__

struct event {
    int pid;
    unsigned long long duration_ns; // wait time
    char comm[16];                  // process name 
};

#endif /* __PROFILER_COMMON_H__ */