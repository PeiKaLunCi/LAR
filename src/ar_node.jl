using ForneyLab
using LinearAlgebra
import ForneyLab: SoftFactor, @ensureVariables, generateId, addNode!, associate!,
                  averageEnergy, Interface, Variable, slug, ProbabilityDistribution,
                  differentialEntropy, unsafeLogMean,
                  unsafeMean, unsafeCov, unsafePrecision, unsafeWeightedMean,
                  unsafeMeanCov, VariateType, prod!, @symmetrical, dims
import SpecialFunctions: polygamma, digamma
export Autoregressive, AR, averageEnergy, slug, prod!

"""
Description:

    A Gaussian mixture with mean-precision parameterization:

    f(y, θ, x, γ) = 𝒩(out|A(θ)x, V(γ)),

    where A(θ) =  θᵀ
                I	0

Interfaces:

    1. y (output vector)
    2. θ (autoregression coefficients)
    3. x (input vector)
    4. γ (precision)

Construction:

    Autoregressive(out, θ, in, γ, id=:some_id)
"""

mutable struct Autoregressive <: SoftFactor
    id::Symbol
    interfaces::Vector{Interface}
    i::Dict{Symbol,Interface}

    function Autoregressive(y, θ, x, γ; id=generateId(Autoregressive))
        @ensureVariables(y, x, θ, γ)
        self = new(id, Array{Interface}(undef, 4), Dict{Symbol,Interface}())
        addNode!(currentGraph(), self)
        self.i[:y] = self.interfaces[1] = associate!(Interface(self), y)
        self.i[:x] = self.interfaces[2] = associate!(Interface(self), x)
        self.i[:θ] = self.interfaces[3] = associate!(Interface(self), θ)
        self.i[:γ] = self.interfaces[4] = associate!(Interface(self), γ)
        return self
    end
end

slug(::Type{Autoregressive}) = "AR"

function averageEnergy(::Type{Autoregressive},
                       marg_y::ProbabilityDistribution{V},
                       marg_x::ProbabilityDistribution{V},
                       marg_θ::ProbabilityDistribution{V},
                       marg_γ::ProbabilityDistribution{Univariate}) where V<:VariateType
    mθ, Vθ = unsafeMeanCov(marg_θ)
    my, Vy = unsafeMeanCov(marg_y)
    mx, Vx = unsafeMeanCov(marg_x)
    mγ = unsafeMean(marg_γ)
    my1, Vy1 = my[1], Vy[1]
    AE = -0.5*(unsafeLogMean(marg_γ)) +
    0.5*log(2*pi) + 0.5*mγ*(Vy1+my1^2 - 2*mθ'*mx*my1 +
    tr(Vθ*Vx) + mx'*Vθ*mx + mθ'*(Vx + mx*mx')*mθ)

    # correction
    AE += differentialEntropy(marg_y)
    marg_y = ProbabilityDistribution(Univariate, GaussianMeanVariance, m=my1, v=Vy1)
    AE -= differentialEntropy(marg_y)
end

function averageEnergy(::Type{Autoregressive},
                       marg_y_x::ProbabilityDistribution{Multivariate},
                       marg_θ::ProbabilityDistribution{Univariate},
                       marg_γ::ProbabilityDistribution{Univariate})

    mθ, Vθ = unsafeMeanCov(marg_θ)
    myx, Vyx = unsafeMeanCov(marg_y_x)
    mx, Vx = myx[end], Vyx[end]
    my1, Vy1 = myx[1], Vyx[1]
    mγ = unsafeMean(marg_γ)
    -0.5*(unsafeLogMean(marg_γ)) +
    0.5*log(2*pi) + 0.5*mγ*(Vy1+my1^2 - 2*mθ'*(Vyx[3] + mx*my1) +
    tr(Vθ*Vx) + mx'*Vθ*mx + mθ'*(Vx + mx*mx')*mθ)

    # correction
    AE += differentialEntropy(marg_y_x)
    marg_y_x = ProbabilityDistribution(Multivariate, GaussianMeanVariance, m=myx, v=Vyx)
    AE -= differentialEntropy(marg_y_x)
end

function averageEnergy(::Type{Autoregressive},
                       marg_y_x::ProbabilityDistribution{Multivariate},
                       marg_θ::ProbabilityDistribution{Multivariate},
                       marg_γ::ProbabilityDistribution{Univariate})

    mθ, Vθ = unsafeMeanCov(marg_θ)
    order = length(mθ)
    myx, Vyx = unsafeMeanCov(marg_y_x)
    mx, Vx = myx[order+1:end], Matrix(Vyx[order+1:2*order, order+1:2*order])
    my1, Vy1 = myx[1], Vyx[1]
    Vy1x = Vyx[1, order+1:end]
    mγ = unsafeMean(marg_γ)
    AE = -0.5*(unsafeLogMean(marg_γ)) +
    0.5*log(2*pi) + 0.5*mγ*(Vy1+my1^2 - 2*mθ'*(Vy1x + mx*my1) +
    tr(Vθ*Vx) + mx'*Vθ*mx + mθ'*(Vx + mx*mx')*mθ)

    # correction
    AE += differentialEntropy(marg_y_x)
    idc = [1, order+1:2*order...]
    myx_n = myx[idc]
    Vyx_n = Vyx[idc, idc]
    marg_y_x = ProbabilityDistribution(Multivariate, GaussianMeanVariance, m=myx_n, v=Vyx_n)
    AE -= differentialEntropy(marg_y_x)
end
