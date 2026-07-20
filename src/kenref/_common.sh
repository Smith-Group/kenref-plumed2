# =============================================================================
# _common.sh — shared logic for the PLUMED-side KEnRef build scripts.
# Sourced by build-only.sh and build-and-batch.sh; defines defaults, helpers and
# the three build steps. Not executable on its own.
#
# Division of labor: kenref_core is DELEGATED to the KEnRef repo (kenref builds
# kenref); PLUMED is built by its OWN autotools; GROMACS (batch script only) is
# batched with PLUMED's own `plumed patch` then built by GROMACS's CMake.
# =============================================================================
[ -n "${_KN_COMMON_SOURCED:-}" ] && return; _KN_COMMON_SOURCED=1

# this file lives in <plumed>/src/kenref/
MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUMED_ROOT="$(cd "${MODULE_DIR}/../.." && pwd)"

# ---- defaults ---------------------------------------------------------------
ASSUME_YES=0
BUILD_TYPE="Release"
ACCEL=""                       # empty => auto-detect this machine's SIMD (like GROMACS)
JOBS="$(command -v nproc >/dev/null 2>&1 && nproc || echo 4)"
KENREF_SRC=""                  # local KEnRef repo (REQUIRED if kenref_core is not already installed)
KENREF_PREFIX=""               # kenref_core install prefix (default under PLUMED_ROOT/install)
PLUMED_PREFIX="${PLUMED_ROOT}/install/plumed"
# GROMACS (batch script): a PROVIDED 2025.x source is required on this branch (auto-fetch is deferred).
GROMACS_SRC=""
GROMACS_PREFIX="${PLUMED_ROOT}/install/gromacs"
PATCH_ENGINE=""                # empty => auto (newest gromacs-2025.x shipped with this PLUMED)
# NOTE: this branch (kenref-plumed-master) does NOT auto-download kenref or gromacs — it reuses an installed
# kenref (pkg-config) or a provided --kenref-src, and a provided --gromacs-src. The auto-download convenience
# lives on the 'kenref-plumed-downloads' branch (re-merged after the PLUMED PR is accepted in principle).

say()  { printf '\n\033[1;34m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33mWARNING: %s\033[0m\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR: %s\033[0m\n' "$*" >&2; exit 1; }
interactive() { [ "$ASSUME_YES" = 0 ] && [ -t 0 ]; }
ask_yesno()   { local a; read -rp "$1 [y/N] " a; [[ "$a" =~ ^[Yy] ]]; }
ask_val()     { local __v=$1 __p=$2 __d=${3:-}; [ -n "${!__v}" ] && return
                if ! interactive; then [ -n "$__d" ] && printf -v "$__v" '%s' "$__d"; return; fi
                local __a; read -rp "${__p}${__d:+ [$__d]}: " __a; printf -v "$__v" '%s' "${__a:-$__d}"; }

detect_accel() {
    if [ -r /proc/cpuinfo ]; then
        grep -qm1 avx512f /proc/cpuinfo && { echo AVX_512; return; }
        grep -qm1 avx2    /proc/cpuinfo && { echo AVX2_256; return; }
        grep -qm1 ' avx '  /proc/cpuinfo && { echo AVX_256; return; }
    fi
    echo AVX2_256
}
march_for_accel() {
    case "$1" in
        AVX_512)  echo "-march=skylake-avx512" ;;
        AVX_256)  echo "-march=sandybridge" ;;
        AVX2_256) echo "-march=haswell" ;;
        *) die "unknown --accel '$1'" ;;
    esac
}

kn_usage() {
    cat <<EOF
Usage: src/kenref/${KN_SCRIPT:-build}.sh [options]   (no options => interactive)

  --kenref-src DIR       local KEnRef repo (REQUIRED if kenref_core is not already installed; no auto-download)
  --kenref-prefix DIR    kenref_core install prefix   (default: ${PLUMED_ROOT}/install/kenref)
  --plumed-prefix DIR    PLUMED install prefix         (default: ${PLUMED_PREFIX})
  --build-type T         Release | Debug | RelWithDebInfo   (default: ${BUILD_TYPE})
  --accel A              AVX_512 | AVX_256 | AVX2_256        (default: auto-detect)
  --jobs N               parallel build jobs                (default: ${JOBS})
$( [ "${KN_BATCHES:-0}" = 1 ] && cat <<G
  --gromacs-src DIR      GROMACS 2025.x source (REQUIRED — no auto-download on this branch)
  --gromacs-prefix DIR   GROMACS install prefix      (default: ${GROMACS_PREFIX})
  --patch-engine E       plumed patch -e engine      (default: auto)
G
)
  (This branch reuses an installed/provided kenref + a provided gromacs; auto-download lives on
   the kenref-plumed-downloads branch.)
  -y | --yes             non-interactive; take defaults
  -h | --help

Toolchain via environment: CXX, CC (default mpicxx/mpicc), CXXFLAGS (e.g. -stdlib=libc++).
EOF
}

kn_parse_args() {
    while [ $# -gt 0 ]; do
        case "$1" in
            --kenref-src)     KENREF_SRC="$2"; shift ;;
            --kenref-prefix)  KENREF_PREFIX="$2"; shift ;;
            --plumed-prefix)  PLUMED_PREFIX="$2"; shift ;;
            --gromacs-src)    GROMACS_SRC="$2"; shift ;;
            --gromacs-prefix) GROMACS_PREFIX="$2"; shift ;;
            --build-type)     BUILD_TYPE="$2"; shift ;;
            --accel)          ACCEL="$2"; shift ;;
            --jobs)           JOBS="$2"; shift ;;
            --patch-engine)   PATCH_ENGINE="$2"; shift ;;
            -y|--yes)         ASSUME_YES=1 ;;
            -h|--help)        kn_usage; exit 0 ;;
            *) die "unknown option '$1' (try --help)" ;;
        esac
        shift
    done
}

kn_finalize_toolchain() {
    [ -n "$ACCEL" ] || ACCEL="$(detect_accel)"
    : "${CXX:=$(command -v mpicxx || command -v c++ || echo c++)}"
    : "${CC:=$(command -v mpicc  || command -v cc  || echo cc)}"
    export CXX CC
}

# ---- STEP 1: ensure kenref_core (DELEGATE its build to the KEnRef repo) ------
ensure_kenref() {
    if pkg-config --exists kenref_core 2>/dev/null || pkg-config --exists kenref_and_eigen3 2>/dev/null; then
        say "kenref found via pkg-config (v$(pkg-config --modversion kenref_core 2>/dev/null || pkg-config --modversion kenref_and_eigen3)) — reusing it."
        return
    fi
    [ -n "$KENREF_SRC" ] || ask_val KENREF_SRC "local KEnRef repo path (required — no auto-download on this branch)"
    # This branch does NOT clone KEnRef. Reuse an installed kenref_core (handled above) or build from a PROVIDED
    # checkout (--kenref-src). Auto-clone lives on the kenref-plumed-downloads branch.
    [ -n "$KENREF_SRC" ] || die "kenref_core is not installed and auto-download is disabled on this branch.
  Put an installed kenref prefix on PKG_CONFIG_PATH, or pass --kenref-src DIR.
  (The auto-clone convenience lives on the 'kenref-plumed-downloads' branch.)"
    [ -f "$KENREF_SRC/CMakeLists.txt" ] || die "--kenref-src '$KENREF_SRC' is not a KEnRef checkout."
    : "${KENREF_PREFIX:=${PLUMED_ROOT}/install/kenref}"

    say "delegating kenref_core build to KEnRef: ${KENREF_SRC}/build.sh (core + exported plumedinterface)"
    "${KENREF_SRC}/build.sh" -y --build-type "$BUILD_TYPE" --accel "$ACCEL" --prefix "$KENREF_PREFIX" --export-plumedinterface

    # Source the installed env.sh — KEnRef's PostInstall writes it with PKG_CONFIG_PATH already including the
    # external eigen3.pc dir (so the preferred "kenref_core + external eigen3" flavor resolves). This is robust
    # to KEnRef's build-dir layout (the collapsed build.sh uses one build dir), unlike parsing its CMakeCache.
    if [ -f "${KENREF_PREFIX}/env.sh" ]; then
        . "${KENREF_PREFIX}/env.sh"
    else
        export PKG_CONFIG_PATH="${KENREF_PREFIX}/lib/pkgconfig:${KENREF_PREFIX}/share/pkgconfig:${PKG_CONFIG_PATH:-}"
    fi
    pkg-config --exists kenref_core || pkg-config --exists kenref_and_eigen3 || \
        die "kenref_core still not resolvable after delegated build — check ${KENREF_PREFIX}."
    say "kenref_core ready (v$(pkg-config --modversion kenref_core 2>/dev/null || pkg-config --modversion kenref_and_eigen3))."
}

# Objects from a PREVIOUS build with a DIFFERENT toolchain must never be relinked into this one. PLUMED's make
# only rebuilds when SOURCES change: `autoreconf --force` + `./configure` rewrite Makefile.conf but do NOT
# invalidate existing .o files. Switching compiler / standard library / flags therefore silently MIXES
# incompatible objects — e.g. libc++-compiled objects linked into a libstdc++ build, which fails with
# undefined std::__1 / std::__cxx11 references (and can link "successfully" into something subtly broken).
#
# So: fingerprint everything that affects object code and clean only when it changes — an unchanged toolchain
# keeps rebuilds incremental.
kn_plumed_clean_if_settings_changed() {   # $1 = signature of this build's settings
    local sig_file="${PLUMED_ROOT}/.kenref-build-signature" new_sig="$1" old_sig=""
    [ -f "$sig_file" ] && old_sig="$(cat "$sig_file" 2>/dev/null || true)"
    if [ -n "$old_sig" ] && [ "$old_sig" != "$new_sig" ]; then
        say "build settings changed since the last kenref build -> cleaning stale objects (rebuild required)"
        if ! ( cd "$PLUMED_ROOT" && make clean >/dev/null 2>&1 ); then
            # A stale/inconsistent Makefile.conf makes `make clean` itself fail; fall back to removing the
            # object files directly, otherwise the mixed-toolchain link failure survives the clean.
            warn "make clean failed (stale Makefile.conf?) — removing object files directly"
            find "${PLUMED_ROOT}/src" -name '*.o' -delete 2>/dev/null || true
        fi
    fi
    printf '%s\n' "$new_sig" > "$sig_file" 2>/dev/null || true
}

# ---- STEP 2: build PLUMED (+kenref) with PLUMED's OWN autotools --------------
build_plumed() {
    [ -f "${MODULE_DIR}/module.type" ] || die "no kenref module here (${MODULE_DIR}) — wrong PLUMED tree/branch."
    say "building PLUMED (+kenref) with PLUMED's autotools -> ${PLUMED_PREFIX}"
    local kn_libs kn_libdir
    if pkg-config --exists kenref_core; then
        kn_libs="$(pkg-config --libs kenref_core)";       kn_libdir="$(pkg-config --variable=libdir kenref_core)"
        say "linking kenref_core + external eigen3"
    else
        kn_libs="$(pkg-config --libs kenref_and_eigen3)"; kn_libdir="$(pkg-config --variable=libdir kenref_and_eigen3)"
        say "linking self-contained kenref_and_eigen3"
    fi
    local march opt; march="$(march_for_accel "$ACCEL")"
    case "$BUILD_TYPE" in Debug) opt="-O0 -g";; RelWithDebInfo) opt="-O2 -g";; *) opt="-O3 -DNDEBUG";; esac

    local kn_cxxflags="${CXXFLAGS:-} ${opt} -fPIC -std=c++17 ${march}"
    local kn_ldflags="${LDFLAGS:-} -L${kn_libdir} -Wl,-rpath,${kn_libdir}"
    local kn_linklibs="-Wl,--push-state,--no-as-needed ${kn_libs} -Wl,--pop-state ${LIBS:-}"
    # Everything below changes the emitted objects (or what they must link against) -> drop stale objects.
    kn_plumed_clean_if_settings_changed "CXX=${CXX}|CC=${CC}|CXXFLAGS=${kn_cxxflags}|LDFLAGS=${kn_ldflags}|LIBS=${kn_linklibs}|PREFIX=${PLUMED_PREFIX}"

    ( cd "$PLUMED_ROOT"
      autoreconf --force
      ./configure CXX="$CXX" CC="$CC" \
          CXXFLAGS="${kn_cxxflags}" \
          LDFLAGS="${kn_ldflags}" \
          LIBS="${kn_linklibs}" \
          --prefix="$PLUMED_PREFIX" --enable-kenref --enable-modules=+kenref
      make -j "$JOBS"; make install )
    export PATH="${PLUMED_PREFIX}/bin:${PATH}"
    # The installed `plumed` driver loads libplumedKernel.so from ${PLUMED_PREFIX}/lib at RUNTIME and is not
    # rpath'd to it, so PATH alone is not enough: without this, the very next step (build_gromacs running
    # `plumed patch`) dies with "error while loading shared libraries: libplumedKernel.so" (exit 127).
    export LD_LIBRARY_PATH="${PLUMED_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
    say "PLUMED installed -> ${PLUMED_PREFIX}"
}

# ---- STEP 3: GROMACS 2025.x, batched with THIS PLUMED's `plumed patch` -------
build_gromacs() {
    # A PROVIDED GROMACS 2025.x source is required on this branch (auto-fetch is deferred to the
    # kenref-plumed-downloads branch). `plumed patch` rewrites the source in place, so it must be a checkout
    # dedicated to the plumed path (not the one kenref-gmx builds against).
    [ -n "$GROMACS_SRC" ] || ask_val GROMACS_SRC "GROMACS 2025.x source (required — no auto-download on this branch)"
    [ -n "$GROMACS_SRC" ] || die "no GROMACS source provided and auto-download is disabled on this branch.
  Pass --gromacs-src DIR (a GROMACS 2025.x checkout, pref 2025.4).
  (The auto-fetch convenience lives on the 'kenref-plumed-downloads' branch.)"
    [ -f "${GROMACS_SRC}/CMakeLists.txt" ] || die "--gromacs-src '${GROMACS_SRC}' is not a GROMACS source tree."

    local ver
    # GROMACS's authoritative version is `project(Gromacs VERSION <year>.<minor>)` in its TOP-LEVEL
    # CMakeLists.txt. Do NOT scan cmake/gmxVersionInfo.cmake for the first 20xx: the first match there is the
    # COPYRIGHT year ("# Copyright 2014- The GROMACS Authors"), so every tree was reported as "2014.x" and
    # rejected by the check below — i.e. this gate refused EVERY gromacs, including a valid 2025.x.
    ver="$(grep -iE '^[[:space:]]*project\(.*VERSION[[:space:]]+[0-9]{4}' "${GROMACS_SRC}/CMakeLists.txt" 2>/dev/null \
           | grep -oE '[0-9]{4}' | head -1)"
    if [ -z "$ver" ]; then warn "could not detect GROMACS version; full integration needs 2025.x (pref 2025.4)."
    elif [ "$ver" -lt 2025 ]; then die "GROMACS ${ver}.x — PLUMED not well integrated before 2025; use 2025.x (pref 2025.4)."
    elif [ "$ver" -ge 2026 ]; then warn "GROMACS ${ver}.x — PLUMED integration regressed after 2025; 2025.x (pref 2025.4) recommended."
    else say "GROMACS ${ver}.x — good."; fi

    local plumed="${PLUMED_PREFIX}/bin/plumed" engine="$PATCH_ENGINE"
    [ -x "$plumed" ] || die "PLUMED not built at ${PLUMED_PREFIX}."
    # Defensive (build_plumed already does this when it runs in the same invocation): the driver needs its
    # kernel on the loader path, or `plumed patch` below fails with a bare exit 127.
    case ":${LD_LIBRARY_PATH:-}:" in
        *":${PLUMED_PREFIX}/lib:"*) ;;
        *) export LD_LIBRARY_PATH="${PLUMED_PREFIX}/lib:${LD_LIBRARY_PATH:-}" ;;
    esac
    "$plumed" --no-mpi info --version >/dev/null 2>&1 \
        || die "the installed plumed at ${plumed} is not runnable (kernel not loadable?) — cannot 'plumed patch'."
    if [ -z "$engine" ]; then
        engine="$(ls "${PLUMED_ROOT}/patches"/gromacs-2025.*.config 2>/dev/null | sed 's#.*/##; s#\.config$##' | sort -V | tail -1)"
        [ -z "$engine" ] && engine="gromacs-2025.0"
    fi
    say "batching GROMACS with 'plumed patch -e ${engine} --mode runtime' (native GMX_USE_PLUMED alone is not full integration)"
    ( cd "$GROMACS_SRC"
      "$plumed" patch -r -e "$engine" 2>/dev/null || true
      "$plumed" patch -p -e "$engine" --mode runtime )

    local bt build_dir; bt="$(echo "$BUILD_TYPE" | tr '[:upper:]' '[:lower:]')"
    build_dir="${GROMACS_SRC}/cmake-build-${bt}-plumed-orch"
    cmake -S "$GROMACS_SRC" -B "$build_dir" \
        -DCMAKE_BUILD_TYPE="$BUILD_TYPE" -DGMX_USE_PLUMED=ON -DGMX_MPI=ON -DGMX_SIMD="$ACCEL" \
        -DCMAKE_INSTALL_PREFIX="$GROMACS_PREFIX"
    cmake --build "$build_dir" -j "$JOBS"
    cmake --install "$build_dir"
    say "GROMACS installed -> ${GROMACS_PREFIX} (batched against PLUMED at ${PLUMED_PREFIX})."
}
