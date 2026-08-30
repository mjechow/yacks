#!/usr/bin/env bash
# Compares the three runtime knobs that are switchable without a rebuild:
#   preempt full|lazy, cpuidle governor menu|teo, THP madvise|always.
# Needs root for the sysfs writes. Restores the original state on exit,
# including on Ctrl+C. Build knobbench first as your normal user:
#   make -C tools
set -uo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

[[ $EUID -eq 0 ]] || { echo "must run as root: sudo $0"; exit 1; }
[[ -x ./knobbench ]] || { echo "knobbench missing - run 'make -C tools' as your normal user first"; exit 1; }

PREEMPT=/sys/kernel/debug/sched/preempt
GOV=/sys/devices/system/cpu/cpuidle/current_governor
THP=/sys/kernel/mm/transparent_hugepage/enabled

orig_preempt=$(sed 's/.*(\(\S*\)).*/\1/' $PREEMPT 2> /dev/null)
orig_gov=$(cat $GOV)
orig_thp=$(sed 's/.*\[\(\S*\)\].*/\1/' $THP)

restore() {
  echo
  echo "--- restoring: preempt=$orig_preempt governor=$orig_gov thp=$orig_thp"
  [[ -n "$orig_preempt" ]] && echo "$orig_preempt" > $PREEMPT 2> /dev/null
  echo "$orig_gov" > $GOV 2> /dev/null
  echo "$orig_thp" > $THP 2> /dev/null
}
trap restore EXIT INT TERM

runs() { for _ in 1 2 3; do ./knobbench "$1"; done; }

echo "=== starting state: preempt=$orig_preempt governor=$orig_gov thp=$orig_thp"
echo
echo "############ 1. preempt: full vs lazy  (pingpong)"
for m in full lazy; do
  if ! echo "$m" > $PREEMPT 2> /dev/null; then
    echo "  preempt=$m not settable - skipped"
    continue
  fi
  echo "-- preempt=$m"; runs pingpong
done

echo
echo "############ 2. cpuidle governor: menu vs teo  (idlewake)"
for g in menu teo; do
  if ! echo "$g" > $GOV 2> /dev/null; then
    echo "  governor=$g not settable - skipped"
    continue
  fi
  echo "-- governor=$g"; runs idlewake
done

echo
echo "############ 3. THP: madvise vs always  (tlb)"
for t in madvise always; do
  if ! echo "$t" > $THP 2> /dev/null; then
    echo "  thp=$t not settable - skipped"
    continue
  fi
  echo "-- thp=$t"; runs tlb
done
