#!/bin/bash
# Longer ubiquitin run, used for debugging/profiling against the STAGING tree.
#
# NOTE: this script previously pointed at "-asan" tiers
# (gromacs-4-plumed/2025/2025.3/relwithdebinfo-asan, plumed-dev/master/{asan,relwithdebinfo-asan}).
# Those tiers no longer exist in either the staging or the deployment tree, so the sanitizer lines are
# kept commented and expressed in terms of _env.sh -- set KN_BUILD=relwithdebinfo for the closest
# equivalent, and re-add a sanitizer tier to the build scripts if you need one again.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

kn_require "${KN_GMXRC}" "${KN_PLUMED_KERNEL}"

source "${KN_GMXRC}"
export PLUMED_KERNEL="${KN_PLUMED_KERNEL}"

if [ -z "$PLUMED_KERNEL" ]; then
    echo "ERROR: PLUMED_KERNEL not set. Please check the PLUMED installation." >&2
    exit 1
fi
echo "PLUMED_KERNEL=$PLUMED_KERNEL"

# Sanitizer support (needs a sanitizer-enabled PLUMED build; see the note above):
# export ASAN_OPTIONS="detect_leaks=0:log_path=./asan.log:abort_on_error=1"
# export LD_PRELOAD=${KN_LLVM}/lib/clang/20/lib/x86_64-unknown-linux-gnu/libclang_rt.asan.so
export ASAN_OPTIONS=detect_leaks=0:halt_on_error=1:log_path=asan.log

export PLUMED_LOAD_NODEEPBIND=1

# The trajectory this was written against. Override with KN_TPR=...
KN_TPR="${KN_TPR:-/smithlab/home/aalhossary/ubiquitin-plateaus-plumed/10nsstart+fitting/alef.tpr}"
kn_require "${KN_TPR}"

gmx_mpi mdrun -cpi -pin on -ntomp "${KN_NTOMP:-20}" -cpt 30 \
    -plumed ../runFiles/ubiquitin_1e8_.25_999_A.dat \
    -deffnm test \
    -s "${KN_TPR}"

# Under valgrind:
# valgrind --tool=memcheck --error-exitcode=1 --leak-check=no --track-origins=yes \
#     --num-callers=30 --log-file=valgrind.%p.log \
#     gmx_mpi mdrun -cpi -pin on -ntomp 1 -cpt 30 \
#         -plumed ../runFiles/ubiquitin_1e8_.25_999_A.dat -deffnm test -s "${KN_TPR}"
#
# Under rr:
# rr record gmx_mpi mdrun -cpi -pin on -ntomp 1 -cpt 30 \
#     -plumed ../runFiles/ubiquitin_1e8_.25_999_A.dat -deffnm test -s "${KN_TPR}"
