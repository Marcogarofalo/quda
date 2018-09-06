/* C. Kallidonis: Internal header file for the qlua-interface
 * lib/interface_qlua.cpp
 */

#ifndef INTERFACE_QLUA_INT_H__
#define INTERFACE_QLUA_INT_H__

#include <interface_qlua.h>
#include <complex_quda.h>

namespace quda {

  const bool QCredundantComms = false; //- Same as interface_quda.cpp

  struct QluaUtilArg {

    const int nParity;            // number of parities we're working on
    const int volumeCB;           // checkerboarded volume
    const int lL[4];              // 4-d local lattice dimensions
    const int t_axis;             // direction of the time-axis
    size_t rec_size;              // size of elements in correlators
    int nFldDst;                  // Number of fields in correlator to be used in momentum projection (destination)
    int nFldSrc;                  // Number of fields in correlator from contractions (source)
    int sp_stride[4];             // stride in spatial volume
    int sp_locvol;                // spatial volume
    
  QluaUtilArg(ColorSpinorField **propIn, int nFldDst, int nFldSrc, int t_axis, size_t rec_size)
  :   nParity(propIn[0]->SiteSubset()), volumeCB(propIn[0]->VolumeCB()),
      lL{propIn[0]->X(0), propIn[0]->X(1), propIn[0]->X(2), propIn[0]->X(3)},
      t_axis(t_axis), rec_size(rec_size), nFldDst(nFldDst), nFldSrc(nFldSrc),
      sp_stride{0,0,0,0}, sp_locvol(0)
    {

      if(0 <= t_axis){
        int sp_mul = 1;
        for(int i = 0; i < 4; i++){
          if(i == t_axis) sp_stride[i] = 0;
          else{
            sp_stride[i] = sp_mul;
            sp_mul *= lL[i];
          }
          sp_locvol = sp_mul;
        }//-for
      }//-if

    }//-- constructor
  };//-- Structure definition

  
  __device__ int d_crdChkVal = 0;
  int QluaSiteOrderCheck(QluaUtilArg utilArg);

  
  void convertSiteOrder_QudaQDP_to_momProj(void *corrInp_dev, const void *corrQuda_dev, QluaUtilArg utilArg);

  
  void cudaContractQQ(
  		      ColorSpinorField **propOut,
  		      ColorSpinorField **propIn1,
  		      ColorSpinorField **propIn2,
  		      int parity, int Nc, int Ns,
  		      cntrQQParam cParam);

  
  void createPhaseMatrix_GPU(complex<QUDA_REAL> *phaseMatrix,
			     const int *momMatrix,
                             momProjParam param,  const qudaLattice *qS);

  void QuarkContractStd_GPU(complex<QUDA_REAL> *corrQuda_dev,
                            ColorSpinorField **cudaProp1,
                            ColorSpinorField **cudaProp2,
                            ColorSpinorField **cudaProp3,
                            complex<QUDA_REAL> *S2, complex<QUDA_REAL> *S1,
                            qudaAPI_Param paramAPI);

  void QuarkContractTMD_GPU(complex<QUDA_REAL> *corrQuda_dev,
                            ColorSpinorField **cudaProp1,
                            ColorSpinorField **cudaProp2,
                            ColorSpinorField **cudaProp3,
                            cudaGaugeField *U, cudaGaugeField *extU,
                            cudaGaugeField *extU1, cudaGaugeField *extU2, cudaGaugeField *extU3,
                            qudaAPI_Param paramAPI);
  
} //- namespace quda
  
#endif/*INTERFACE_QLUA_INT_H__*/
