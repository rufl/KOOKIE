#ifndef KOOKIE_JOBS_H
#define KOOKIE_JOBS_H

#include <stdbool.h>

bool kookie_jobs_open(int worker_count);
int kookie_jobs_submit(
    int generation,
    int ordinal,
    int kind,
    int result,
    int checksum,
    int delay_microseconds
);
int kookie_jobs_poll(void);
int kookie_jobs_generation(int token);
int kookie_jobs_ordinal(int token);
int kookie_jobs_kind(int token);
int kookie_jobs_result(int token);
int kookie_jobs_checksum(int token);
int kookie_jobs_status(int token);
bool kookie_jobs_release(int token);
bool kookie_jobs_close(void);

bool kookie_jobs_wait_microseconds(int microseconds);
#endif
