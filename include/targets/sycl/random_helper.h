#pragma once

#include <random_quda.h>
#include <oneapi/mkl/rng/device.hpp>

//#if defined(XORWOW)
//#elif defined(MRG32k3a)
namespace drng = oneapi::mkl::rng::device;

namespace quda {

  struct RNGState {
    drng::mrg32k3a<1> state;
  };

  /**
   * \brief random init
   * @param [in] seed -- The RNG seed
   * @param [in] sequence -- The sequence
   * @param [in] offset -- the offset
   * @param [in,out] state - the RNG State
   */
  inline void random_init(unsigned long long seed, unsigned long long sequence,
			  unsigned long long offset, RNGState &state)
  {
    //curand_init(seed, sequence, offset, &state.state);
    std::initializer_list<std::uint64_t> num_to_skip = {offset, 8*sequence};
    state.state = drng::mrg32k3a<1>(seed, num_to_skip);
  }

  template<class Real>
    struct uniform { };
  template<>
    struct uniform<float> {

    /**
     * \brief Return a uniform deviate between 0 and 1
     * @param [in,out] the RNG State
     */
    static inline float rand(RNGState &state)
    {
      //curand_uniform(&state.state);
      drng::uniform<float> distr;
      return generate(distr, state.state);
    }

    /**
     * \brief return a uniform deviate between a and b
     * @param [in,out] the RNG state
     * @param [in] a (the lower end of the range)
     * @param [in] b (the upper end of the range)
     */
    static inline float rand(RNGState &state, float a, float b)
    {
      //return a + (b - a) * rand(state);
      drng::uniform<float> distr(a,b);
      return generate(distr, state.state);
    }

  };

  template<>
    struct uniform<double> {
    /**
     * \brief Return a uniform deviate between 0 and 1
     * @param [in,out] the RNG State
     */
    static inline double rand(RNGState &state)
    {
      //curand_uniform_double(&state.state);
      drng::uniform<double> distr;
      return generate(distr, state.state);
    }

    /**
     * \brief Return a uniform deviate between a and b
     * @param [in,out] the RNG State
     * @param [in] a -- the lower end of the range
     * @param [in] b -- the high end of the range
     */
    static inline double rand(RNGState &state, double a, double b)
    {
      //return a + (b - a) * rand(state);
      drng::uniform<double> distr(a,b);
      return generate(distr, state.state);
    }
  };

  template<class Real>
    struct normal { };

  template<>
    struct normal<float> {
    /**
     * \brief return a gaussian normal deviate with mean of 0
     * @param [in,out] state
     */
    static inline float rand(RNGState &state)
    {
      //curand_normal(&state.state);
      drng::gaussian<float> distr;
      return generate(distr, state.state);
    }
  };

  template<>
    struct normal<double> {
    /**
     * \brief return a gaussian (normal) deviate with a mean of 0
     * @param [in,out] state
     */
    static inline double rand(RNGState &state)
    {
      //curand_normal_double(&state.state);
      drng::gaussian<double> distr;
      return generate(distr, state.state);
    }
  };

}
