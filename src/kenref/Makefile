USE=core tools vesselbase multicolvar bias

# generic makefile
#This line MUST be at the beginning. Before (NOT AFTER) the variables.
include ../maketools/make.module

# make KEnRef double
CPPFLAGS += -DKENREF_DOUBLE

# ---------------------------------------------------------------------------------------------------
# Option A (KEnRef model-abstraction restructure): the KEnRefBias implementation is hosted in the KEnRef
# repo (kenref_plumed) and compiled HERE from the frame forwarders (KEnRefBias.{h,cpp}, KEnRefBias_setup.cpp).
#
#  * COMPILE (KEnRef headers + repo plumedinterface source): from `pkg-config --cflags kenref_plumed`
#    (kenref_plumed.pc exposes -I include/core -I include/plumedinterface -I src). buildPlumed.sh puts the
#    installed kenref prefix on PKG_CONFIG_PATH. Falls back to a local repo checkout via KENREF_SRC_REPO.
#  * `-I. -I..`: the KEnRefBias_setup.cpp forwarder #includes the INSTALLED plumedinterface source, whose
#    quoted PLUMED includes (e.g. "tools/Communicator.h") resolve relative to the installed file's dir.
#    PLUMED's USE= symlink header dirs live in THIS module dir, so add it (and PLUMED's src) to the path.
#  * LINK (libkenref_core into libplumedKernel.so): NOT set here. buildPlumed.sh passes
#    `pkg-config --libs kenref_core` (+ rpath) to ./configure so it is baked into Makefile.conf's
#    DYNAMIC_LIBS — the variable the kernel link actually uses — robustly across regeneration. The frame
#    only needs to COMPILE against the KEnRef headers; the kernel link resolves the symbols.
# ---------------------------------------------------------------------------------------------------
KENREF_PLUMED_CFLAGS := $(shell pkg-config --silence-errors --cflags kenref_plumed)
ifneq ($(strip $(KENREF_PLUMED_CFLAGS)),)
  CPPFLAGS := $(KENREF_PLUMED_CFLAGS) $(CPPFLAGS)
else
  KENREF_SRC_REPO ?= /home/amr/CLionProjects/KEnRef
  CPPFLAGS := -I$(KENREF_SRC_REPO)/include_core -I$(KENREF_SRC_REPO)/include_plumedinterface -I$(KENREF_SRC_REPO)/src $(CPPFLAGS)
endif
CPPFLAGS += -I. -I..
