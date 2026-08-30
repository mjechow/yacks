// knobbench – isolates the three runtime knobs on this box:
//   pingpong : wakeup/preemption latency under load   -> preempt=full|lazy
//   idlewake : timer wakeup from deep C-state         -> cpuidle.governor=menu|teo
//   tlb      : random-access cost over 1 GiB          -> THP=madvise|always
// No root, no external deps. Pinned to CCD0 (96 MB L3) for reproducibility.
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <pthread.h>
#include <unistd.h>
#include <time.h>
#include <sched.h>
#include <sys/mman.h>
#include <sys/eventfd.h>

static int cmp_u64(const void *a, const void *b) {
  uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b;
  return (x > y) - (x < y);
}
static uint64_t pct(uint64_t *v, size_t n, double p) {
  size_t i = (size_t)(p * (n - 1));
  return v[i];
}
static inline uint64_t now_ns(void) {
  struct timespec ts;
  clock_gettime(CLOCK_MONOTONIC, &ts);
  return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec;
}
static void pin(int cpu) {
  cpu_set_t s;
  CPU_ZERO(&s);
  CPU_SET(cpu, &s);
  sched_setaffinity(0, sizeof(s), &s);
}

// ---------------------------------------------------------------- pingpong
static int efd_a, efd_b;
static volatile int spin_stop;
static long PP_ITERS = 200000;

static void *spinner(void *arg) {
  pin((int)(intptr_t)arg);
  volatile double x = 0;
  while (!spin_stop) for (int i = 0; i < 10000; i++) x += i * 0.5;
  (void)x;
  return NULL;
}
static void *pong(void *arg) {
  pin((int)(intptr_t)arg);
  uint64_t v;
  for (long i = 0; i < PP_ITERS; i++) {
    if (read(efd_a, &v, 8) != 8) break;
    v = 1;
    if (write(efd_b, &v, 8) != 8) break;
  }
  return NULL;
}
static void bench_pingpong(int cpu_a, int cpu_b) {
  efd_a = eventfd(0, 0);
  efd_b = eventfd(0, 0);
  uint64_t *s = malloc(PP_ITERS * sizeof(uint64_t));
  pthread_t tp, s1, s2;
  spin_stop = 0;
  pthread_create(&s1, NULL, spinner, (void *)(intptr_t)cpu_a);
  pthread_create(&s2, NULL, spinner, (void *)(intptr_t)cpu_b);
  pthread_create(&tp, NULL, pong, (void *)(intptr_t)cpu_b);
  pin(cpu_a);
  struct timespec d = {0, 200000000};
  nanosleep(&d, NULL);  // let spinners saturate both cores

  for (long i = 0; i < PP_ITERS; i++) {
    uint64_t v = 1, t0 = now_ns();
    if (write(efd_a, &v, 8) != 8) break;
    if (read(efd_b, &v, 8) != 8) break;
    s[i] = now_ns() - t0;
  }
  spin_stop = 1;
  pthread_join(tp, NULL);
  pthread_join(s1, NULL);
  pthread_join(s2, NULL);
  qsort(s, PP_ITERS, sizeof(uint64_t), cmp_u64);
  printf("pingpong_rt_ns  p50=%-8lu p90=%-8lu p99=%-8lu p999=%-9lu max=%lu\n",
         pct(s, PP_ITERS, .50), pct(s, PP_ITERS, .90), pct(s, PP_ITERS, .99),
         pct(s, PP_ITERS, .999), s[PP_ITERS - 1]);
  free(s);
  close(efd_a);
  close(efd_b);
}

// ---------------------------------------------------------------- idlewake
static void bench_idlewake(int cpu, long n, long gap_us) {
  pin(cpu);
  uint64_t *s = malloc(n * sizeof(uint64_t));
  struct timespec t;
  clock_gettime(CLOCK_MONOTONIC, &t);
  for (long i = 0; i < n; i++) {
    t.tv_nsec += gap_us * 1000;
    if (t.tv_nsec >= 1000000000L) { t.tv_nsec -= 1000000000L; t.tv_sec++; }
    clock_nanosleep(CLOCK_MONOTONIC, TIMER_ABSTIME, &t, NULL);
    uint64_t a = now_ns();
    uint64_t want = (uint64_t)t.tv_sec * 1000000000ull + t.tv_nsec;
    s[i] = a > want ? a - want : 0;
  }
  qsort(s, n, sizeof(uint64_t), cmp_u64);
  printf("idlewake_ns     p50=%-8lu p90=%-8lu p99=%-8lu p999=%-9lu max=%lu\n",
         pct(s, n, .50), pct(s, n, .90), pct(s, n, .99), pct(s, n, .999), s[n - 1]);
  free(s);
}

// --------------------------------------------------------------------- tlb
static void report_thp(void) {
  FILE *f = fopen("/proc/self/smaps_rollup", "r");
  if (!f) return;
  char line[256];
  while (fgets(line, sizeof line, f))
    if (!strncmp(line, "AnonHugePages:", 14)) { printf("  %s", line); break; }
  fclose(f);
}
static void bench_tlb(int cpu, size_t bytes, long steps) {
  pin(cpu);
  const size_t stride = 64;
  size_t n = bytes / stride;
  // plain anonymous mmap, no madvise: only THP=always maps this huge
  char *m = mmap(NULL, bytes, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
  if (m == MAP_FAILED) { perror("mmap"); return; }
  memset(m, 0, bytes);
  size_t *idx = malloc(n * sizeof(size_t));
  for (size_t i = 0; i < n; i++) idx[i] = i;
  uint64_t r = 88172645463325252ull;  // xorshift, deterministic
  for (size_t i = n - 1; i > 0; i--) {
    r ^= r << 13; r ^= r >> 7; r ^= r << 17;
    size_t j = r % (i + 1);
    size_t t = idx[i]; idx[i] = idx[j]; idx[j] = t;
  }
  for (size_t i = 0; i < n; i++)           // build the chase ring
    *(size_t *)(m + idx[i] * stride) = idx[(i + 1) % n] * stride;
  free(idx);
  report_thp();
  size_t p = 0;
  uint64_t t0 = now_ns();
  for (long i = 0; i < steps; i++) p = *(size_t *)(m + p);
  uint64_t dt = now_ns() - t0;
  printf("tlb_chase       %.2f ns/access  (%.1f M steps, sink=%zu)\n",
         (double)dt / steps, steps / 1e6, p);
  munmap(m, bytes);
}

int main(int argc, char **argv) {
  const char *which = argc > 1 ? argv[1] : "all";
  setvbuf(stdout, NULL, _IOLBF, 0);
  if (!strcmp(which, "all") || !strcmp(which, "pingpong")) bench_pingpong(0, 2);
  if (!strcmp(which, "all") || !strcmp(which, "idlewake")) bench_idlewake(4, 3000, 3000);
  if (!strcmp(which, "all") || !strcmp(which, "tlb")) bench_tlb(6, 1ull << 30, 50000000);
  return 0;
}
