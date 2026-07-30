#!/bin/bash
# Single-replica run against the STAGING GROMACS-4-PLUMED build.
set -e
source "$(dirname "${BASH_SOURCE[0]}")/_env.sh"

kn_require "${KN_GMXRC}" "${KN_PLUMED_SRC}/sourceme.sh"

source "${KN_GMXRC}"
source "${KN_PLUMED_SRC}/sourceme.sh"

if [ -z "$PLUMED_KERNEL" ]; then
    echo "ERROR: PLUMED_KERNEL not set. Please check the PLUMED installation." >&2
    exit 1
fi
echo "PLUMED_KERNEL=$PLUMED_KERNEL"

# TPR to run. Override with KN_TPR=... ; the default is the committed single-replica test set.
KN_TPR="${KN_TPR:-${KN_PLUMED_SRC}/src/kenref/run-output/repl_01/topol.tpr}"
kn_require "${KN_TPR}"

# For multi-replica runs the input must sit in a relative folder (see runPlumed_double.sh).
gmx_mpi mdrun -s "${KN_TPR}" -nsteps "${KN_NSTEPS:-50}" -plumed ../runFiles/test_single.dat
