#include "coarsecoarse_op.hpp"

namespace quda {

  //Calculates the coarse color matrix and puts the result in Y.
  //N.B. Assumes Y, X have been allocated.
  void CoarseCoarseOp(GaugeField &Y, GaugeField &X, const Transfer &T, const GaugeField &gauge,
                      const GaugeField &clover, const GaugeField &cloverInv, double kappa, double mass, double mu, double mu_factor,
                      QudaDiracType dirac, QudaMatPCType matpc, bool need_bidirectional)
  {
    QudaFieldLocation location = checkLocation(X, Y, gauge, clover, cloverInv);

    //Create a field UV which holds U*V.  Has the same similar
    //structure to V but double the number of spins so we can store
    //the four distinct block chiral multiplications in a single UV
    //computation.
    ColorSpinorParam UVparam(T.Vectors(location));
    UVparam.create = QUDA_ZERO_FIELD_CREATE;
    UVparam.location = location;
    UVparam.nSpin *= 2; // so nSpin == 4
    UVparam.setPrecision(T.Vectors(location).Precision());
    UVparam.mem_type = Y.MemType(); // allocate temporaries to match coarse-grid link field

    ColorSpinorField *uv = ColorSpinorField::Create(UVparam);

    GaugeField *Yatomic = &Y;
    GaugeField *Xatomic = &X;
    if (Y.Precision() < QUDA_SINGLE_PRECISION) {
      // we need to coarsen into single precision fields (float or int), so we allocate temporaries for this purpose
      // else we can just coarsen directly into the original fields
      GaugeFieldParam param(X); // use X since we want scalar geometry
      param.location = location;
      param.setPrecision(QUDA_SINGLE_PRECISION, location == QUDA_CUDA_FIELD_LOCATION ? true : false);

      Yatomic = GaugeField::Create(param);
      Xatomic = GaugeField::Create(param);
    }

    bool constexpr use_mma = false;
    calculateYcoarse<use_mma>(Y, X, *Yatomic, *Xatomic, *uv, T, gauge, clover, cloverInv, kappa, mass, mu, mu_factor, dirac, matpc,
                              need_bidirectional);

    if (Yatomic != &Y) delete Yatomic;
    if (Xatomic != &X) delete Xatomic;

    delete uv;
  }

  void CoarseCoarseOpMMA(GaugeField &Y, GaugeField &X, const Transfer &T, const GaugeField &gauge,
                         const GaugeField &clover, const GaugeField &cloverInv, double kappa, double mass, double mu, double mu_factor,
                         QudaDiracType dirac, QudaMatPCType matpc, bool need_bidirectional);

  void CoarseCoarseOp(GaugeField &Y, GaugeField &X, const Transfer &T, const GaugeField &gauge,
                      const GaugeField &clover, const GaugeField &cloverInv, double kappa, double mass, double mu, double mu_factor,
                      QudaDiracType dirac, QudaMatPCType matpc, bool need_bidirectional, bool use_mma)
  {
    #if 0
    if (use_mma) {
      CoarseCoarseOpMMA(Y, X, T, gauge, clover, cloverInv, kappa, mass, mu, mu_factor, dirac, matpc, need_bidirectional);
    } else {
#endif
      CoarseCoarseOp(Y, X, T, gauge, clover, cloverInv, kappa, mass, mu, mu_factor, dirac, matpc, need_bidirectional);
    #if 0
    }
#endif
  }

}
