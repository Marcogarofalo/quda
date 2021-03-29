#include <dslash_domain_wall_4d_fused_m5.h>

/**
   This is the gauged domain-wall 4-d preconditioned operator, fused with immediately followed fifth dimension operators.
*/

namespace quda
{

  // Apply the 4-d preconditioned domain-wall Dslash operator
  //   i.e. out(x) = M*in = in(x) + a*\sum_mu U_{-\mu}(x)in(x+mu) + U^\dagger_mu(x-mu)in(x-mu)
  // ... and then m5inv
  void ApplyDomainWall4DM5inv(ColorSpinorField &out, const ColorSpinorField &in, const GaugeField &U, double a,
                                double m_5, const Complex *b_5, const Complex *c_5, const ColorSpinorField &x,
                                ColorSpinorField &y, int parity, bool dagger, const int *comm_override, double m_f,
                                TimeProfile &profile)
  {
#ifdef GPU_DOMAIN_WALL_DIRAC
    auto dummy_list = Dslash5TypeList<Dslash5Type::M5_INV_MOBIUS>();
    instantiate<DomainWall4DApplyFusedM5>(out, in, U, a, m_5, b_5, c_5, x, y, parity, dagger, comm_override, m_f,
                                          dummy_list, profile);
#else
    errorQuda("Domain-wall dslash has not been built");
#endif // GPU_DOMAIN_WALL_DIRAC
  }

} // namespace quda
