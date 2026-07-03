cmake_minimum_required(VERSION 3.10)
project(PLUMED_IDE_HELPER)
set(CMAKE_CXX_STANDARD 17)

### comment the next line to make it float. Uncomment to make it double.
add_compile_options(-DKENREF_DOUBLE)

# 1. Define PLUMED include paths
# (These paths mimic what 'configure' found. Update paths if they differ on your system)
include_directories(
        src
#        src/lib
#        src/core
#        src/bias
#        src/cltools
#        src/wrapper
#        src/kenref
        # Add external paths found by configure (copy from Makefile.conf if needed)
        /smithlab/opt/fftw/3.3.10/include
        /smithlab/opt/openmpi/5.0.7_clang20.1.1_cuda12.4.1/include
)

# 2. KEnRef include paths — point at the REPO working tree (not the installed prefix) so CLion resolves
# the CURRENT KEnRef headers. `.../src` lets the frame forwarders' #include "plumedinterface/..." resolve
# to the repo's src/plumedinterface/*.cpp (the real KEnRefBias impl the frame compiles).
set(KENREF_REPO /home/amr/CLionProjects/KEnRef)
include_directories(
        ${KENREF_REPO}/include_core
        ${KENREF_REPO}/include_plumedinterface
        ${KENREF_REPO}/src
        /smithlab/opt/eigen/5.0.1/release/include/eigen3
)

# 3. Add source files
# Recursively find all C++ files so CLion indexes them — PLUMED's own src, PLUS the KEnRef repo's
# plumedinterface source (the KEnRefBias impl the fork frame forwards to) so it shows up in this project.
file(GLOB_RECURSE SOURCES "src/*/*.cpp" "src/*/*.h"
        "${KENREF_REPO}/src/plumedinterface/*.cpp"
        "${KENREF_REPO}/include_plumedinterface/plumedinterface/*.h")

# 4. Create a fake target
add_executable(plumed_dummy ${SOURCES}
        src/kenref/config.h)

add_executable(nothing donothing.cpp src/kenref/config.h)

# 5. Define Macros used by PLUMED (Optional but helps)
add_definitions(-D__PLUMED_HAS_GROMACS -D__PLUMED_HAS_MPI -DKENREF_DOUBLE)