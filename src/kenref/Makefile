USE=core tools vesselbase multicolvar bias

# generic makefile
#This line MUST be at the beginning. Before (NOT AFTER) the variables.
include ../maketools/make.module

# make KEnRef double
CPPFLAGS += -DKENREF_DOUBLE

# Option A (KEnRef model-abstraction restructure): the KEnRefBias implementation is hosted in the
# KEnRef repo (kenref_plumed) and compiled here from the frame forwarders (KEnRefBias.{h,cpp}).
# Prepend the repo's headers + plumedinterface source so they take precedence over any (older)
# kenref headers pulled in via pkg-config below. Override KENREF_SRC_REPO to point at your checkout.
# Phase G wires this through the build scripts / kenref pkg-config so the frame stays machine-neutral.
KENREF_SRC_REPO ?= /home/amr/CLionProjects/KEnRef
CPPFLAGS := -I$(KENREF_SRC_REPO)/include_core -I$(KENREF_SRC_REPO)/include_plumedinterface -I$(KENREF_SRC_REPO)/src $(CPPFLAGS)

# Debug output
$(info ===== Debug Info =====)
# Debug: Print variables
$(info >>>>>>>>>>>>> KENREF_INCLUDE is: $(KENREF_INCLUDE))
$(info >>>>>>>>>>>>> KENREF_LIBS is: $(KENREF_LIBS))
$(info >>>>>>>>>>>>> HAVE_KENREF: $(HAVE_KENREF))
$(info >>>>>>>>>>>>> Before setting: CPPFLAGS=$(CPPFLAGS))
$(info >>>>>>>>>>>>> Before setting: LIBS=$(LIBS))
$(info =====================================)
# Set flags BEFORE including make.module
ifneq ($(KENREF_INCLUDE),)
  CPPFLAGS+=$(KENREF_INCLUDE)
else
  $(warning KENREF_INCLUDE is empty! We will hardcode it)
  # Hardcode for testing
  CPPFLAGS+=-I/smithlab/opt/kenref-dev/2025/2025.3/debug/AVX_512/include/core -I/smithlab/opt/eigen/3.4.0/include/eigen3
endif

ifneq ($(KENREF_LIBS),)
  LIBS+=$(KENREF_LIBS)
else
  $(warning KENREF_LIBS is empty! We will hardcode it)
  # Hardcode for testing
  LIBS+=-L/smithlab/opt/kenref-dev/2025/2025.3/debug/AVX_512/lib -lkenref_core -L/smithlab/home/opt/rhel08/openmpi/5.0.7_clang20.1.1_cuda12.4.1/lib/libmpi.so
endif

$(info >>>>>>>>>>>>> After setting: CPPFLAGS=$(CPPFLAGS))
$(info >>>>>>>>>>>>> After setting: LIBS=$(LIBS))
$(info =====================================)
