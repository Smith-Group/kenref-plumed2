#!/bin/bash
# Configure and build PLUMED with the kenref module, against a STAGING kenref install.
# Paths come from _env.sh -- override on the command line, e.g. KN_BUILD=release ./buildPlumed.sh
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

kn_require "${KN_KENREF_PREFIX}/lib/pkgconfig" "${KN_EIGEN_PC}"

cd "${KN_PLUMED_SRC}"

export PKG_CONFIG_PATH="${KN_KENREF_PREFIX}/lib/pkgconfig:${KN_EIGEN_PC}:${PKG_CONFIG_PATH}"

# The linker must be able to FIND libkenref_core.so when it links the `plumed` executable against
# libplumedKernel.so, and --enable-rpath must record that directory so the binaries are
# self-contained. src/kenref/_common.sh does this; this hand-rolled script did not, which produced:
#   ld: warning: libkenref_core.so.2, needed by libplumedKernel.so, not found
#   libplumedKernel.so: undefined reference to `kenref::bootstrapModels()'
# Safe alongside pkg-config because PLUMED's configure queries --libs with
# PKG_CONFIG_ALLOW_SYSTEM_LIBS=1; otherwise pkg-config would suppress -L for a directory that is
# on LIBRARY_PATH and the captured link line would silently stop being self-contained.
export LIBRARY_PATH="${KN_KENREF_PREFIX}/lib:${LIBRARY_PATH}"
export LD_LIBRARY_PATH="${KN_KENREF_PREFIX}/lib:${LD_LIBRARY_PATH}"

# -march must match the kenref build's ACCEL tier: Eigen's alignment is part of libkenref_core's ABI,
# so a mismatch trips the SIMD/Eigen guard. kenref_core.pc now carries the right -march itself, so this
# is belt-and-braces rather than the only source of truth.
case "${KN_ACCEL}" in
  AVX_512)  KN_MARCH=skylake-avx512 ;;
  AVX2_256) KN_MARCH=haswell ;;
  AVX_256)  KN_MARCH=sandybridge ;;
  *) echo "unknown KN_ACCEL=${KN_ACCEL}" >&2; exit 2 ;;
esac

# autoconf 2.69 reproduces PLUMED's committed `configure` byte-for-byte; 2.72 rewrites the whole script
# (~10k lines of unrelated churn), which in a git checkout shows up as a huge spurious diff. Pin the
# version, and only regenerate when configure.ac is actually newer -- `autoreconf --force` unconditionally
# rewrote it before, and on this machine /usr/local/bin/autoconf (2.72) precedes /usr/bin/autoconf (2.69).
KN_AUTOCONF="${KN_AUTOCONF:-/usr/bin/autoconf}"
if ! "${KN_AUTOCONF}" --version | head -1 | grep -q '2\.69'; then
    echo "WARNING: ${KN_AUTOCONF} is not autoconf 2.69 -- regenerating configure may rewrite it wholesale." >&2
fi
if [ configure.ac -nt configure ] || [ ! -f configure ]; then
    echo "==> regenerating configure with $(${KN_AUTOCONF} --version | head -1)"
    "${KN_AUTOCONF}" -o configure configure.ac
else
    echo "==> configure is up to date; skipping autoreconf"
fi

./configure \
    CXXFLAGS="-stdlib=libc++ -O0 -g -fPIC -Wall -pedantic -std=c++17 -march=${KN_MARCH}" \
    LDFLAGS="-L${KN_LLVM}/lib/x86_64-unknown-linux-gnu" \
    LIBS="-Wl,--push-state,--no-as-needed -lc++ -lc++abi -lunwind -Wl,--pop-state -lpthread -ldl" \
    --prefix="${KN_PLUMED_PREFIX}" \
    --enable-modules=reset:+kenref \
    CXX=mpicxx CC=mpicc FC=mpif90

make clean
make -j"${KN_JOBS:-18}"
# sudo make install
