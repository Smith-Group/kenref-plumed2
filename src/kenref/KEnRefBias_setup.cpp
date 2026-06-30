/*
 * KEnRefBias_setup.cpp — frozen frame forwarder.
 *
 * The KEnRefBias constructor (one-time model + sub-indexing + driver setup) is hosted in the KEnRef
 * repository (src/plumedinterface/KEnRefBias_setup.cpp) so it can evolve with the KEnRef model
 * abstraction WITHOUT re-pushing this fork. It is compiled here, within PLUMED's build. The repo's
 * include path is supplied by `pkg-config --cflags kenref_plumed` (see this module's Makefile).
 */
#include "plumedinterface/KEnRefBias_setup.cpp"
