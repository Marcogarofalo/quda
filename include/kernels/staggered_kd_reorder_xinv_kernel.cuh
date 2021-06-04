#include <color_spinor_field_order.h>
#include <gauge_field_order.h>
#include <multigrid_helper.cuh>
#include <index_helper.cuh>

namespace quda {

  template <typename Float_, int coarseSpin_, int fineColor_, int coarseColor_,
            typename fineGauge, typename coarseGauge>
  struct CalculateStaggeredGeometryReorderArg {

    using Float = Float_;
    static constexpr int coarseSpin = coarseSpin_;
    static_assert(coarseSpin == 2, "Only coarseSpin == 2 is supported");
    static constexpr int fineColor = fineColor_;
    static constexpr int coarseColor = coarseColor_;
    static_assert(8 * fineColor == coarseColor, "KD blocking requires 8 * fineColor == coarseColor");

    static constexpr int kdBlockSize = 16;
    static_assert(kdBlockSize == QUDA_KDINVERSE_GEOMETRY, "KD block size must match geometry");
    static constexpr int kdBlockSizeCB = kdBlockSize / 2;

    fineGauge fineXinv;           /** Kahler-Dirac fine inverse field in KD geometry */

    const coarseGauge coarseXinv;       /** Computed Kahler-Dirac inverse field */

    int_fastdiv x_size[QUDA_MAX_DIM];   /** Dimensions of fine grid */
    int xc_size[QUDA_MAX_DIM];  /** Dimensions of coarse grid */

    const spin_mapper<1,coarseSpin> spin_map; /** Helper that maps fine spin to coarse spin */

    const int fineVolumeCB;     /** Fine grid volume */
    const int coarseVolumeCB;   /** Coarse grid volume */

    static constexpr int coarse_color = coarseColor;

    CalculateStaggeredGeometryReorderArg(fineGauge &fineXinv, const coarseGauge &coarseXinv, const int *x_size_, const int *xc_size_) :
      fineXinv(fineXinv),
      coarseXinv(coarseXinv),
      spin_map(),
      fineVolumeCB(fineXinv.VolumeCB()),
      coarseVolumeCB(coarseXinv.VolumeCB())
    {
      for (int i=0; i<QUDA_MAX_DIM; i++) {
        x_size[i] = x_size_[i];
        xc_size[i] = xc_size_[i];
      }
    }

  };

  template <typename Arg>
  __device__ __host__ void ComputeStaggeredGeometryReorder(Arg &arg, int parity, int x_cb, int g_f)
  {
    using Float = typename Arg::Float;
    constexpr int nDim = 4;
    int coord[nDim];
    int coord_coarse[nDim];

    getCoords(coord, x_cb, arg.x_size, parity);

    // Compute coarse coordinates
#pragma unroll
    for (int d = 0; d < nDim; d++) coord_coarse[d] = coord[d]/2;
    int coarse_parity = 0;
#pragma unroll
    for (int d = 0; d < nDim; d++) coarse_parity += coord_coarse[d];
    coarse_parity &= 1;
    int coarse_x_cb = (((coord_coarse[3]*arg.xc_size[2]+coord_coarse[2])*arg.xc_size[1]+coord_coarse[1])*arg.xc_size[0] + coord_coarse[0]) >> 1;

    // Fine parity gives the coarse spin
    constexpr int s = 0; // fine spin is always 0, since it's staggered.
    const int is_c = arg.spin_map(s,parity); // Coarse spin row index ; which spin row of the KD block are we indexing into

    // Corner of hypercube gives coarse color row
    const int ic_c_base = 4*(coord[3]%2)+2*(coord[2]%2)+(coord[1]%2);

    // Each fine site contains 16 3x3 matrices (KD geometry), where each of the
    // 16 matrices corresponds to gathering from one of 16 sites in the KD block
    // Even gathers: 0 is the (0,0,0,0) site, 1 is the (1,1,0,0) site, ...
    // Odd gathers: 8 is the (1,0,0,0) site, 8 is the (0,1,0,0) site, ...
    const int js_c = g_f / Arg::kdBlockSizeCB;
    const int jc_c_base = g_f - Arg::kdBlockSizeCB * js_c;

    // loop over all fine_nc * fine_nc sites
#pragma unroll
    for (int ic_f = 0; ic_f < Arg::fineColor; ic_f++) {
#pragma unroll
      for (int jc_f = 0; jc_f < Arg::fineColor; jc_f++) {
        arg.fineXinv(g_f,parity,x_cb,ic_f,jc_f) = arg.coarseXinv(0,coarse_parity,coarse_x_cb,is_c,js_c,ic_c_base + Arg::kdBlockSizeCB * ic_f,jc_c_base + Arg::kdBlockSizeCB * jc_f);
      }
    }

    // set it to the unit matrix...
    /*
#pragma unroll
    for (int ic_f = 0; ic_f < Arg::fineColor; ic_f++) {
#pragma unroll
      for (int jc_f = 0; jc_f < Arg::fineColor; jc_f++) {
        complex<Float> val = { (ic_f == jc_f && is_c == js_c && ic_c_base == jc_c_base) ? 1.f : 0.f, 0.f };
        arg.fineXinv(g_f, parity, x_cb, ic_f, jc_f) = val;
      }
    }
    */

  }

  template<typename Arg>
  void ComputeStaggeredGeometryReorderCPU(Arg arg)
  {
    for (int parity=0; parity<2; parity++) {
#pragma omp parallel for
      for (int x_cb=0; x_cb<arg.fineVolumeCB; x_cb++) { // Loop over fine volume
        for (int g_f=0; g_f<Arg::kdBlockSize; g_f++) {
            ComputeStaggeredGeometryReorder(arg, parity, x_cb, g_f);
        } // KD geometry, aka fine sites w/in a kahler-dirac block
      } // c/b volume
    } // parity
  }

  template<typename Arg>
  __global__ void ComputeStaggeredGeometryReorderGPU(Arg arg)
  {
    int x_cb = blockDim.x*blockIdx.x + threadIdx.x;
    if (x_cb >= arg.fineVolumeCB) return;

    int g_f = blockDim.y*blockIdx.y + threadIdx.y; // KD geometry, aka fine sites w/in a kahler-dirac block
    if (g_f >= Arg::kdBlockSize) return;
    
    int parity = blockDim.z*blockIdx.z + threadIdx.z;

    ComputeStaggeredGeometryReorder(arg, parity, x_cb, g_f);
  }

} // namespace quda
