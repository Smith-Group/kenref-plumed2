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
# KENREF_PLUMED_CPPFLAGS is RESOLVED ONCE AT CONFIGURE TIME (configure.ac: `pkg-config --cflags kenref_plumed`)
# and baked into Makefile.conf, which `include ../maketools/make.module` above has already -included. We read
# that baked value instead of calling $(shell pkg-config) at PARSE time: a `sudo make install` re-parses this
# file as root with PKG_CONFIG_PATH stripped, so a parse-time pkg-config would return empty and abort the
# build. Baking mirrors how the LINK flags already flow (configure -> LIBS -> Makefile.conf's DYNAMIC_LIBS).
# The includes are needed only to BUILD the module. `make clean` / `make links` (which remove or symlink
# files, and also run on an unconfigured tree where Makefile.conf may not exist yet) must NOT require them,
# and must never $(error). So gate the requirement on the goal: only a build (default target, or any goal
# beyond clean/links) needs the flags.
kenref_needs_flags := yes
ifneq ($(strip $(MAKECMDGOALS)),)
  ifeq ($(filter-out clean links,$(MAKECMDGOALS)),)
    kenref_needs_flags := no
  endif
endif
ifneq ($(strip $(KENREF_PLUMED_CPPFLAGS)),)
  CPPFLAGS := $(KENREF_PLUMED_CPPFLAGS) $(CPPFLAGS)
else ifneq ($(strip $(KENREF_SRC_REPO)),)
  # Standalone build with no configure-resolved value: fall back to a KEnRef SOURCE checkout pointed to by
  # KENREF_SRC_REPO (no hardcoded path). Layout mirrors kenref_plumed.pc's -I core / plumedinterface / src.
  CPPFLAGS := -I$(KENREF_SRC_REPO)/include_core -I$(KENREF_SRC_REPO)/include_plumedinterface -I$(KENREF_SRC_REPO)/src $(CPPFLAGS)
else ifeq ($(kenref_needs_flags),yes)
  $(error KEnRef: KENREF_PLUMED_CPPFLAGS is empty — re-run ./configure with the installed kenref prefix on \
    PKG_CONFIG_PATH (it bakes the flags into Makefile.conf), or set KENREF_SRC_REPO=/path/to/KEnRef for a source build)
endif
CPPFLAGS += -I. -I..
