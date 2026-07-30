#!/bin/bash
# Two-replica run against the STAGING GROMACS-4-PLUMED build.
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

# -multidir needs the tpr named relatively and one directory per replica; run this from the directory
# that contains repl_01/ and repl_02/.
mpirun -n 2 gmx_mpi mdrun -s topol.tpr -multidir repl_01 repl_02 \
    -nsteps "${KN_NSTEPS:-50}" -plumed ../../runFiles/test_double.dat
