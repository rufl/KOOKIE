#include "kookie_jobs.h"

#include <stdint.h>
#include <string.h>

#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
typedef CRITICAL_SECTION KookieJobsMutex;
typedef CONDITION_VARIABLE KookieJobsCondition;
typedef HANDLE KookieJobsThread;
#else
#include <errno.h>
#include <pthread.h>
#include <time.h>
typedef pthread_mutex_t KookieJobsMutex;
typedef pthread_cond_t KookieJobsCondition;
typedef pthread_t KookieJobsThread;
#endif

#define KOOKIE_JOBS_MAX_JOBS 32
#define KOOKIE_JOBS_MAX_WORKERS 4
#define KOOKIE_JOBS_MAX_GENERATION 1000000
#define KOOKIE_JOBS_MAX_SCALAR 1000000
#define KOOKIE_JOBS_MAX_DELAY_MICROSECONDS 1000000

typedef struct {
    bool used;
    bool running;
    bool completed;
    bool reported;
    int generation;
    int ordinal;
    int kind;
    int left;
    int right;
    int delay_microseconds;
    int result;
    int checksum;
    int status;
} KookieJob;

typedef struct {
    bool opened;
    bool stopping;
    KookieJobsMutex mutex;
    KookieJobsCondition condition;
    KookieJobsThread threads[KOOKIE_JOBS_MAX_WORKERS];
    int worker_count;
    int queue[KOOKIE_JOBS_MAX_JOBS];
    int queue_head;
    int queue_tail;
    int queue_count;
    KookieJob jobs[KOOKIE_JOBS_MAX_JOBS];
} KookieJobsState;

static KookieJobsState jobs_state;

#ifdef _WIN32
static void kookie_jobs_lock(void) {
    EnterCriticalSection(&jobs_state.mutex);
}

static void kookie_jobs_unlock(void) {
    LeaveCriticalSection(&jobs_state.mutex);
}

static void kookie_jobs_wait(void) {
    SleepConditionVariableCS(&jobs_state.condition, &jobs_state.mutex, INFINITE);
}

static void kookie_jobs_signal_all(void) {
    WakeAllConditionVariable(&jobs_state.condition);
}

static bool kookie_jobs_thread_create(
    KookieJobsThread *thread,
    DWORD (WINAPI *entry)(LPVOID)
) {
    *thread = CreateThread(NULL, 0, entry, NULL, 0, NULL);
    return *thread != NULL;
}

static void kookie_jobs_thread_join(KookieJobsThread thread) {
    WaitForSingleObject(thread, INFINITE);
    CloseHandle(thread);
}
#else
static void kookie_jobs_lock(void) {
    pthread_mutex_lock(&jobs_state.mutex);
}

static void kookie_jobs_unlock(void) {
    pthread_mutex_unlock(&jobs_state.mutex);
}

static void kookie_jobs_wait(void) {
    pthread_cond_wait(&jobs_state.condition, &jobs_state.mutex);
}

static void kookie_jobs_signal_all(void) {
    pthread_cond_broadcast(&jobs_state.condition);
}

static bool kookie_jobs_thread_create(
    KookieJobsThread *thread,
    void *(*entry)(void *)
) {
    return pthread_create(thread, NULL, entry, NULL) == 0;
}

static void kookie_jobs_thread_join(KookieJobsThread thread) {
    pthread_join(thread, NULL);
}
#endif

static bool kookie_jobs_valid_token(int token) {
    return token > 0 && token <= KOOKIE_JOBS_MAX_JOBS;
}

static int kookie_jobs_calculate_checksum(
    int generation,
    int ordinal,
    int kind,
    int left,
    int right
) {
    int result = 73;
    result = (result * 31 + generation) % 1000003;
    result = (result * 31 + ordinal) % 1000003;
    result = (result * 31 + kind) % 1000003;
    result = (result * 31 + left) % 1000003;
    result = (result * 31 + right) % 1000003;
    if (result <= 0) {
        return 1;
    }
    return result;
}

static int kookie_jobs_compute(const KookieJob *job, int *status) {
    int64_t result;
    if (job->kind == 1) {
        result = (int64_t)job->left * (int64_t)job->right;
    } else if (job->kind == 2) {
        result = (int64_t)job->left + (int64_t)job->right;
        result = result * result + job->ordinal;
    } else {
        *status = 2;
        return 0;
    }
    if (result < -2000000000LL || result > 2000000000LL) {
        *status = 3;
        return 0;
    }
    *status = 1;
    return (int)result;
}

static void kookie_jobs_sleep(int microseconds) {
    if (microseconds <= 0) {
        return;
    }
#ifdef _WIN32
    Sleep((DWORD)((microseconds + 999) / 1000));
#else
    struct timespec remaining = {
        .tv_sec = microseconds / 1000000,
        .tv_nsec = (long)(microseconds % 1000000) * 1000L
    };
    while (nanosleep(&remaining, &remaining) != 0 && errno == EINTR) {
    }
#endif
}

#ifdef _WIN32
static DWORD WINAPI kookie_jobs_worker(void *unused) {
    (void)unused;
#else
static void *kookie_jobs_worker(void *unused) {
    (void)unused;
#endif
    while (true) {
        int token = 0;
        KookieJob job;
        kookie_jobs_lock();
        while (jobs_state.queue_count == 0 && !jobs_state.stopping) {
            kookie_jobs_wait();
        }
        if (jobs_state.queue_count == 0 && jobs_state.stopping) {
            kookie_jobs_unlock();
            break;
        }
        token = jobs_state.queue[jobs_state.queue_head];
        jobs_state.queue_head =
            (jobs_state.queue_head + 1) % KOOKIE_JOBS_MAX_JOBS;
        jobs_state.queue_count -= 1;
        job = jobs_state.jobs[token];
        jobs_state.jobs[token].running = true;
        kookie_jobs_unlock();

        kookie_jobs_sleep(job.delay_microseconds);
        int status = 0;
        int result = kookie_jobs_compute(&job, &status);

        kookie_jobs_lock();
        jobs_state.jobs[token].result = result;
        jobs_state.jobs[token].status = status;
        jobs_state.jobs[token].checksum = kookie_jobs_calculate_checksum(
            job.generation, job.ordinal, job.kind, job.left, job.right);
        jobs_state.jobs[token].running = false;
        jobs_state.jobs[token].completed = true;
        kookie_jobs_signal_all();
        kookie_jobs_unlock();
    }
#ifdef _WIN32
    return 0;
#else
    return NULL;
#endif
}

static void kookie_jobs_destroy_sync(void) {
#ifdef _WIN32
    DeleteCriticalSection(&jobs_state.mutex);
#else
    pthread_cond_destroy(&jobs_state.condition);
    pthread_mutex_destroy(&jobs_state.mutex);
#endif
}

bool kookie_jobs_open(int worker_count) {
    if (worker_count <= 0 || worker_count > KOOKIE_JOBS_MAX_WORKERS ||
        jobs_state.opened) {
        return false;
    }
#ifdef _WIN32
    InitializeCriticalSection(&jobs_state.mutex);
    InitializeConditionVariable(&jobs_state.condition);
#else
    if (pthread_mutex_init(&jobs_state.mutex, NULL) != 0) {
        return false;
    }
    if (pthread_cond_init(&jobs_state.condition, NULL) != 0) {
        pthread_mutex_destroy(&jobs_state.mutex);
        return false;
    }
#endif
    memset(jobs_state.queue, 0, sizeof(jobs_state.queue));
    memset(jobs_state.jobs, 0, sizeof(jobs_state.jobs));
    jobs_state.opened = true;
    jobs_state.stopping = false;
    jobs_state.worker_count = worker_count;
    jobs_state.queue_head = 0;
    jobs_state.queue_tail = 0;
    jobs_state.queue_count = 0;
    int created = 0;
    for (; created < worker_count; created += 1) {
#ifdef _WIN32
        if (!kookie_jobs_thread_create(
                &jobs_state.threads[created], kookie_jobs_worker)) {
#else
        if (!kookie_jobs_thread_create(
                &jobs_state.threads[created], kookie_jobs_worker)) {
#endif
            kookie_jobs_lock();
            jobs_state.stopping = true;
            kookie_jobs_signal_all();
            kookie_jobs_unlock();
            for (int index = 0; index < created; index += 1) {
                kookie_jobs_thread_join(jobs_state.threads[index]);
            }
            kookie_jobs_destroy_sync();
            memset(&jobs_state, 0, sizeof(jobs_state));
            return false;
        }
    }
    return true;
}

int kookie_jobs_submit(
    int generation,
    int ordinal,
    int kind,
    int left,
    int right,
    int delay_microseconds
) {
    if (!jobs_state.opened ||
        generation <= 0 || generation > KOOKIE_JOBS_MAX_GENERATION ||
        ordinal < 0 || ordinal >= KOOKIE_JOBS_MAX_JOBS ||
        (kind != 1 && kind != 2) ||
        left < -KOOKIE_JOBS_MAX_SCALAR || left > KOOKIE_JOBS_MAX_SCALAR ||
        right < -KOOKIE_JOBS_MAX_SCALAR || right > KOOKIE_JOBS_MAX_SCALAR ||
        delay_microseconds < 0 ||
        delay_microseconds > KOOKIE_JOBS_MAX_DELAY_MICROSECONDS) {
        return 0;
    }
    kookie_jobs_lock();
    if (jobs_state.stopping || jobs_state.queue_count >= KOOKIE_JOBS_MAX_JOBS) {
        kookie_jobs_unlock();
        return 0;
    }
    int slot = -1;
    for (int index = 0; index < KOOKIE_JOBS_MAX_JOBS; index += 1) {
        if (!jobs_state.jobs[index].used) {
            slot = index;
            break;
        }
    }
    if (slot < 0) {
        kookie_jobs_unlock();
        return 0;
    }
    KookieJob *job = &jobs_state.jobs[slot];
    memset(job, 0, sizeof(*job));
    job->used = true;
    job->generation = generation;
    job->ordinal = ordinal;
    job->kind = kind;
    job->left = left;
    job->right = right;
    job->delay_microseconds = delay_microseconds;
    job->checksum = kookie_jobs_calculate_checksum(
        generation, ordinal, kind, left, right);
    jobs_state.queue[jobs_state.queue_tail] = slot;
    jobs_state.queue_tail =
        (jobs_state.queue_tail + 1) % KOOKIE_JOBS_MAX_JOBS;
    jobs_state.queue_count += 1;
    int token = slot + 1;
    kookie_jobs_signal_all();
    kookie_jobs_unlock();
    return token;
}

int kookie_jobs_poll(void) {
    if (!jobs_state.opened) {
        return 0;
    }
    kookie_jobs_lock();
    for (int index = 0; index < KOOKIE_JOBS_MAX_JOBS; index += 1) {
        if (jobs_state.jobs[index].used &&
            jobs_state.jobs[index].completed &&
            !jobs_state.jobs[index].reported) {
            jobs_state.jobs[index].reported = true;
            kookie_jobs_unlock();
            return index + 1;
        }
    }
    kookie_jobs_unlock();
    return 0;
}

static int kookie_jobs_get(int token, int field) {
    if (!jobs_state.opened || !kookie_jobs_valid_token(token)) {
        return -1;
    }
    kookie_jobs_lock();
    KookieJob *job = &jobs_state.jobs[token - 1];
    if (!job->used || !job->completed || !job->reported) {
        kookie_jobs_unlock();
        return -1;
    }
    int value = 0;
    if (field == 1) value = job->generation;
    if (field == 2) value = job->ordinal;
    if (field == 3) value = job->kind;
    if (field == 4) value = job->result;
    if (field == 5) value = job->checksum;
    if (field == 6) value = job->status;
    kookie_jobs_unlock();
    return value;
}

int kookie_jobs_generation(int token) { return kookie_jobs_get(token, 1); }
int kookie_jobs_ordinal(int token) { return kookie_jobs_get(token, 2); }
int kookie_jobs_kind(int token) { return kookie_jobs_get(token, 3); }
int kookie_jobs_result(int token) { return kookie_jobs_get(token, 4); }
int kookie_jobs_checksum(int token) { return kookie_jobs_get(token, 5); }
int kookie_jobs_status(int token) { return kookie_jobs_get(token, 6); }

bool kookie_jobs_release(int token) {
    if (!jobs_state.opened || !kookie_jobs_valid_token(token)) {
        return false;
    }
    kookie_jobs_lock();
    KookieJob *job = &jobs_state.jobs[token - 1];
    bool valid = job->used && job->completed && job->reported;
    if (valid) {
        memset(job, 0, sizeof(*job));
    }
    kookie_jobs_unlock();
    return valid;
}

bool kookie_jobs_close(void) {
    if (!jobs_state.opened) {
        return false;
    }
    kookie_jobs_lock();
    jobs_state.stopping = true;
    kookie_jobs_signal_all();
    kookie_jobs_unlock();
    for (int index = 0; index < jobs_state.worker_count; index += 1) {
        kookie_jobs_thread_join(jobs_state.threads[index]);
    }
    kookie_jobs_destroy_sync();
    memset(&jobs_state, 0, sizeof(jobs_state));
    return true;
}

bool kookie_jobs_wait_microseconds(int microseconds) {
    if (!jobs_state.opened || microseconds < 0 ||
        microseconds > KOOKIE_JOBS_MAX_DELAY_MICROSECONDS) {
        return false;
    }
    kookie_jobs_sleep(microseconds);
    return true;
}
