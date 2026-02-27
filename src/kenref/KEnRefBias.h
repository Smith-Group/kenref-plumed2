#ifndef PLUMED_kenref_KEnRefBias_h
#define PLUMED_kenref_KEnRefBias_h

#include "core/ActionAtomistic.h"
#include "bias/Bias.h"
#include "config.h"
#include "core/KEnRef.h"
#include "core/Table.h"
#include <vector>
#include <optional>

namespace PLMD::kenref {
    class KEnRefBias : public bias::Bias, public ActionAtomistic{
    // Energy model selection
    KEnRef<KEnRef_Real_t>::energyModel selectedEnergyModel;

    // Common parameters
    KEnRef_Real_t k_= 1.0, n_ = 0.25;
    KEnRef_Real_t maxForce_ = 999.;
    KEnRef_Real_t maxForceSquared_ = 999. * 999.;

    // SIGMA model parameters
    KEnRef_Real_t proton_mhz_ = 600;
    NamedRowVector<KEnRef_Real_t> rates_ = Table( //TODO provide a way to change it
        {{"5.0e+08", "2.5e+08", "1.0e+12", "1.0e+04"}},
        {{"kens", "kc", "kmethyl", "karo"}}
    ).toNamedRowVector<KEnRef_Real_t>();

    std::vector<SpecDenData<KEnRef_Real_t>> spec_den_data_list_;
    std::string spec_den_data_file_;

    // PLATEAUS model parameters
    Eigen::MatrixX<KEnRef_Real_t> g0_;
    Table experimental_data_table_;
    std::vector<std::pair<KEnRef_Real_t, KEnRef_Real_t>> g0_values_;
    std::string experimental_data_file_;

    // Atom information
    std::vector<AtomNumber> atoms_;
    std::vector<AtomNumber> guideAtoms_;
    std::vector<std::tuple<std::string, std::string>> atomName_pairs_;
    std::vector<std::tuple<int, int>> atomId_pairs_;

    // Reference structure
    std::string reference_pdb_;
    CoordsMatrixType<KEnRef_Real_t> guideAtomsReferenceCoords_;
    CoordsMatrixType<KEnRef_Real_t> guideAtomsReferenceCoordsCentered_;

    // Current state
    CoordsMatrixType<KEnRef_Real_t> subAtomsX_;
    CoordsMatrixType<KEnRef_Real_t> lastFrameSubAtomsX_;
    CoordsMatrixType<KEnRef_Real_t> lastFrameGuideAtomsX_;

    // Derivatives buffer
    std::vector<KEnRef_Real_t> derivatives_buffer_;

    // Grouping (for PLATEAUS model)
    std::vector<std::vector<std::vector<int>>> simulated_grouping_list_;

    // Control flags
    bool paramsInitialized = false; // We use it instead of (step == 0), because the simulation may be continuing after 0
    bool fit_to_reference_ = true;
    bool saturate_forces_ = false;

    // Timing and step counting
    long long calculateForces_time = 0; //TODO fix this


    void initializeParameters();
    void restoreNoJump(CoordsMatrixType<KEnRef_Real_t>& atoms, const CoordsMatrixType<KEnRef_Real_t>& reference,
        const Tensor& box, bool toAngstrom, bool printStatistics = false);

    public:
        explicit KEnRefBias(const ActionOptions &);
        static void registerKeywords(Keywords &);
        void calculate() override;

        // Explicit overrides to resolve ambiguity
        void lockRequests() override;
        void unlockRequests() override;
        void calculateNumericalDerivatives(ActionWithValue* a) override;
    };

} // namespace PLMD::kenref

#endif