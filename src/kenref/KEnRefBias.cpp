#include "bias/Bias.h"
#include "core/ActionRegister.h"
#include "tools/Vector.h"
#include "tools/Communicator.h"
// Include your KEnRef headers
#include "core/KEnRef.h"
#include "KEnRefBias.h"


namespace PLMD::kenref {
    // Register the action
    PLUMED_REGISTER_ACTION(KEnRefBias, "KENREF")

    void KEnRefBias::registerKeywords(Keywords &keys) {
        //First call the parent
        Bias::registerKeywords(keys);
        ActionAtomistic::registerKeywords(keys);

        keys.setDisplayName("KENREF");
        keys.use("ARG");
        // 2nd: Add your keywords here
        // Required parameters
        keys.add("compulsory", "MODEL", "SIGMA", "The energy model to use (SIGMA or PLATEAUS)");
        keys.add("compulsory", "K", "1.0", "Force constant");
        keys.add("compulsory", "N", "0.25", "Power scaling factor");

        // For SIGMA model
        keys.add("optional", "EXP_DATA_FOLDER", "Folder containing experimental data (for SIGMA model)");
        keys.add("optional", "PROTON_MHZ", "Proton MHz (for SIGMA model)");
        keys.add("optional", "RATES", "Relaxation rates (comma-separated, for SIGMA model)");
        keys.add("optional", "SPEC_DEN_DATA_FILE", "File containing spectral density data (for SIGMA model)");

        // For PLATEAUS model
        keys.add("optional", "EXP_DATA_FILE", "File containing experimental data (for PLATEAUS model)");
        keys.add("optional", "G0", "Target g values for PLATEAUS model"); //TODO is this  right?

        // Atom selection and reference
        keys.add("atoms", "GUIDE_ATOMS", "Explicit list of guide group to use for alignment");
        // keys.add("optional", "INDEX", "Index file (created using 'gmx make_ndx' containing atom groups");
        // keys.add("optional", "GUIDE_ATOMS_GROUP_NAME", "Name of guide group in index file to use for alignment");

        keys.add("optional", "REF", "Reference structure PDB file for alignment");
        keys.add("optional", "ATOMNAME_MAPPING", "atom name mapping PDB file name");

        // Advanced parameters
        keys.add("optional", "MAX_FORCE", "Maximum force magnitude"); //999
        // keys.add("optional", "STRIDE", "frequency of application of KEnRef"); //NO NEED
        keys.addFlag("FIT_TO_REFERENCE", false, "Whether to fit coordinates to reference structure");
        keys.addFlag("SATURATE_FORCES", false, "Whether to saturate forces to maximum value");

        // Output components
        // keys.addOutputComponent("bias", "default", "The instantaneous value of the bias potential"); //already added by Bias
        keys.addOutputComponent("energy", "default", "Total KEnRef restraint energy");
        keys.addOutputComponent("rmsd", "default", "RMSD from reference (after fitting)");

        // more keywords?
        keys.use("RESTART");
        keys.use("UPDATE_FROM");
        keys.use("UPDATE_UNTIL");
    }

    KEnRefBias::KEnRefBias(const ActionOptions &ao) : PLUMED_BIAS_INIT(ao), ActionAtomistic(ao) {
        // Parse your keywords here
    // Parse energy model
    std::string energyModelStr;
    parse("ENERGY_MODEL", energyModelStr);
    if (energyModelStr == "SIGMA") {
        selectedEnergyModel = KEnRef<KEnRef_Real_t>::energyModel::SIGMA;
    } else if (energyModelStr == "PLATEAUS") {
        selectedEnergyModel = KEnRef<KEnRef_Real_t>::energyModel::PLATEAUS;
    } else {
        error("ENERGY_MODEL must be either SIGMA or PLATEAUS");
    }

    // Parse basic parameters
        parse("K", k_);
        parse("N", n_);
        parse("PROTON_MHZ", proton_mhz_);
        // TODO Parse rates
        parseFlag("FIT_TO_REFERENCE", fit_to_reference_);

        // parseArgumentList("ARG");// use it if you will take input from other actions
        parseAtomList("GUIDE_ATOMS", guideAtoms_); //TODO We are up to here


        //TODO parse rest of flags and params.
        // N.B. there is also parseVector() if we need it.



        // Get atoms - parseAtomList() from ActionAtomistic
        parseAtomList("ATOMS",atoms_);
        if (atoms_.empty()) {
            error("ATOMS keyword is required");
        }
        // Request atoms - requestAtoms() from ActionAtomistic
        requestAtoms(atoms_);

        log.printf("  KEnRef bias for %u atoms\n", atoms_.size());
        log.printf("  k=%f, n=%f, proton_mhz=%f\n", k_, n_, proton_mhz_);
        // log.printf("  %zu relaxation rates\n", rates_.size());

        // Add components for output if needed
        // addComponent("bias"); //already added by Bias
        // componentIsNotPeriodic("bias");
        addComponent("rmsd");
        componentIsNotPeriodic("rmsd");
        addComponent("energy");
        componentIsNotPeriodic("energy");

        checkRead();

        cite("Restraining interproton angular and distance dynamics with KEnRef. "
            "Amr Alhossary & Colin Smith. (submitted to The ACS Journal of Physical Chemistry B)");
    }


    void KEnRefBias::calculate() {
        std::cout << "calculate() called at step:" << getStep() << std::endl;
        auto model = KEnRef<KEnRef_Real_t>::energyModel::SIGMA;
        std::cout << "SIGMA = " << static_cast<int>(model) << std::endl;

        if (Communicator::plumedHasMPI() && Communicator::initialized()) {
            const Communicator &comm = this->multi_sim_comm; //comm
            std::cout << "MPI is initialized\n";
            std::cout << "Rank = " << comm.Get_rank() << " of " << comm.Get_size() << std::endl;
            comm.Barrier();
        } else {
            std::cerr << "PLUMED does not have MPI or MPI is not initialized!" << std::endl;
        }

        // Get positions - getPositions() from ActionAtomistic
        std::vector<Vector> positions = getPositions();

        // TODO: Convert to your KEnRef format and call your function
        // For example:
        // std::vector<CoordsMatrixType<double>> coord_arrays;
        // CoordsMatrixType<double> coords(positions.size(), 3);
        // for(size_t i=0; i<positions.size(); i++) {
        //     coords(i,0) = positions[i][0];
        //     coords(i,1) = positions[i][1];
        //     coords(i,2) = positions[i][2];
        // }
        // coord_arrays.push_back(coords);

        // Call your KEnRef function
        // Need to prepare SpecDenData, atomNames_2_atomIds, etc.
        // auto result = KEnRef<double>::coord_array_to_sigma_energy(
        //     coord_arrays, rates_, spec_den_data_list, proton_mhz_,
        //     k_, n_, atom_names_to_ids, true, 0);

        // For now, just a dummy implementation
        double bias_value = 0.0;
        double rmsd_value = 0.0;
        double energy_value = 0.0;

        // Calculate forces if needed (you'd get these from KEnRef)
        // vector<Vector> forces(positions.size(), Vector{0,0,0});
        // for(unsigned i=0; i<positions.size(); i++) {
        //     // Convert from KEnRef format to PLUMED Vector
        //     // forces[i] = Vector(fx, fy, fz);
        //     setAtomsDerivatives(getPntrToComponent("bias"), i, forces[i]);
        // }

        getPntrToComponent("bias")->set(bias_value);
        getPntrToComponent("rmsd")->set(rmsd_value);
        getPntrToComponent("energy")->set(energy_value);

        // Apply bias
        setBias(bias_value);
    }


    // Resolve ambiguity for locking requests
    // We need to lock both the Atoms (ActionAtomistic) and any Arguments/CVs (Bias)
    void KEnRefBias::lockRequests() {
        ActionAtomistic::lockRequests();
        Bias::lockRequests();
    }

    void KEnRefBias::unlockRequests() {
        ActionAtomistic::unlockRequests();
        Bias::unlockRequests();
    }

    // Resolve ambiguity for numerical derivatives (used for 'plumed driver --debug-forces')
    // Since KEnRef drives forces based on atomic coordinates, we use the Atomistic implementation.
    void KEnRefBias::calculateNumericalDerivatives(ActionWithValue* a) {
        ActionAtomistic::calculateNumericalDerivatives(a);
    }
}

//TODO setupConstantValues() may be used to setup the values in the first step?
//TODO link output file to action, and maybe to another file
//TODO use readAtomsFromPDB() from ActionAtomistic
//TODO use const `std::vector<AtomNumber>& PLMD::ActionAtomistic::getAbsoluteIndexes() const` and `AtomNumber PLMD::ActionAtomistic::getAbsoluteIndex(int i) const`