#pragma once

#include "CAFAna/Core/ISyst.h"

#include "TString.h"

class TH1;
class TH2;

namespace ana
{
  class DUNEFluxSyst: public ISyst
  {
  public:
    virtual ~DUNEFluxSyst();

    virtual void Shift(double sigma,
                       Restorer& restore,
                       caf::StandardRecord* sr,
                       double& weight) const override;

  protected:
    friend const DUNEFluxSyst* GetDUNEFluxSyst(unsigned int i, bool applyPenalty, bool includeOffAxis);
  DUNEFluxSyst(int i, bool applyPenalty, bool includeOffAxis) :
      ISyst(TString::Format("flux%i", i).Data(),
            TString::Format("Flux #%i", i).Data(),
	    applyPenalty),
      fIdx(i), fScale(), fIncludeOffAxis(includeOffAxis)
    {
    }

    int fIdx;

    mutable TH1* fScale[2][2][2][2]; // ND/FD, numu/nue, bar, FHC/RHC
    mutable TH2* fScale2D[2][2][2]; // ND/FD, numu/nue, bar, FHC/RHC

    bool fIncludeOffAxis;
  };

  const DUNEFluxSyst* GetDUNEFluxSyst(unsigned int i, bool applyPenalty=true, bool includeOffAxis=false);

  // Because vector<T*> won't automatically convert to vector<U*> even when U
  // inherits from V.
  struct DUNEFluxSystVector: public std::vector<const DUNEFluxSyst*>
  {
    operator std::vector<const ISyst*>()
    {
      return std::vector<const ISyst*>(begin(), end());
    }
  };

  DUNEFluxSystVector GetDUNEFluxSysts(unsigned int N, bool applyPenalty=true, bool includeOffAxis=false);
}
