# Shared environment for the runFiles scripts. Source it; do not execute it.
#
# Every path used by these scripts is derived from the few variables below, so a version bump is one
# edit here instead of a hunt through four scripts. Each is overridable from the caller's environment:
#
#   KN_BUILD=release ./runPlumed.sh
#   KN_ACCEL=AVX2_256 KN_VER=1.0.0 ./buildPlumed.sh
#
# These point at the STAGING tree (/smithlab/opt/*-dev), which is the hierarchical one:
#   kenref-dev/<ver>/<build>/<accel>
#   plumed-dev/<plumed-branch>/<kenref-ver>/<build>/<accel>
#   gromacs-4-plumed-dev/<year>/<gmx-ver>/<build>/<accel>
# The DEPLOYMENT tree is flat and named differently (kenref/2.0.0_AVX_512), so these scripts do not
# work against it unchanged -- that is deliberate, since you develop against staging.

KN_VER="${KN_VER:-2.0.0}"                     # kenref version dimension
KN_BUILD="${KN_BUILD:-debug}"                 # debug | relwithdebinfo | release
KN_ACCEL="${KN_ACCEL:-AVX_512}"               # AVX_512 | AVX2_256 | AVX_256
KN_PLUMED_BRANCH="${KN_PLUMED_BRANCH:-master}"
KN_GMX_YEAR="${KN_GMX_YEAR:-2025}"
KN_GMX_VER="${KN_GMX_VER:-2025.4}"
KN_EIGEN_VER="${KN_EIGEN_VER:-5.0.1}"
KN_LLVM="${KN_LLVM:-/smithlab/opt/llvm/20.1.1}"

KN_OPT="${KN_OPT:-/smithlab/opt}"

# The PLUMED source tree: derived from this file's own location, so the scripts work in any checkout
# rather than only in the one they were written in.
KN_PLUMED_SRC="${KN_PLUMED_SRC:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"

# Overridable so you can point at a kenref built somewhere else (a scratch prefix, a release-tier
# install) without editing this file:  KN_KENREF_PREFIX=/path/to/prefix ./buildPlumed.sh
KN_KENREF_PREFIX="${KN_KENREF_PREFIX:-${KN_OPT}/kenref-dev/${KN_VER}/${KN_BUILD}/${KN_ACCEL}}"
KN_PLUMED_PREFIX="${KN_PLUMED_PREFIX:-${KN_OPT}/plumed-dev/${KN_PLUMED_BRANCH}/${KN_VER}/${KN_BUILD}/${KN_ACCEL}}"
KN_GMXRC="${KN_OPT}/gromacs-4-plumed-dev/${KN_GMX_YEAR}/${KN_GMX_VER}/${KN_BUILD}/${KN_ACCEL}/bin/GMXRC"
KN_EIGEN_PC="${KN_EIGEN_PC:-${KN_OPT}/eigen/${KN_EIGEN_VER}/${KN_BUILD}/share/pkgconfig}"
KN_PLUMED_KERNEL="${KN_PLUMED_PREFIX}/lib/libplumedKernel.so"

# Fail loudly and early. These scripts used to point at paths that had been reorganised away
# (gromacs 2025.3, eigen 3.4.0, plumed-dev/master/<build> without the kenref-version level, and the
# -asan tiers), and the failures that produced were confusing and late.
kn_require() {
    local missing=0 p
    for p in "$@"; do
        [ -e "$p" ] || { echo "MISSING: $p" >&2; missing=1; }
    done
    if [ "$missing" = 1 ]; then
        echo "" >&2
        echo "Current selection: KN_VER=$KN_VER KN_BUILD=$KN_BUILD KN_ACCEL=$KN_ACCEL" >&2
        echo "Available kenref builds:" >&2
        ls -d "${KN_OPT}/kenref-dev/${KN_VER}"/*/* 2>/dev/null | sed 's/^/  /' >&2
        return 1
    fi
}
