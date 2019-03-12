import ForneyLab: SoftFactor, @ensureVariables, generateId, addNode!, associate!
export Autoregression, AR, slug

"""
Description:

    A Gaussian mixture with mean-precision parameterization:

    f(out, a, x, W) = 𝒩(out|Ax, W^-1),

    where A =    a^T
                I	0

Interfaces:

    1. out
    2. a (autoregression coefficients)
    3. x (input vector)
    4. W (precision)

Construction:

    Autoregression(out, x, a, W, id=:some_id)
"""
mutable struct Autoregression <: SoftFactor
    id::Symbol
    interfaces::Vector{Interface}
    i::Dict{Symbol,Interface}

    function Autoregression(out, x, a, γ; id=generateId(Autoregression))
        @ensureVariables(out, x, a, γ)
        self = new(id, Array{Interface}(undef, 4), Dict{Symbol,Interface}())
        addNode!(currentGraph(), self)
        self.i[:out] = self.interfaces[1] = associate!(Interface(self), out)
        self.i[:x] = self.interfaces[2] = associate!(Interface(self), x)
        self.i[:a] = self.interfaces[3] = associate!(Interface(self), a)
        self.i[:W] = self.interfaces[4] = associate!(Interface(self), γ)
        return self
    end
end

function AR(a::Variable, x::Variable, W::Variable)
    out = Variable()
    Autoregression(out, x, a, W)
    return out
end

slug(::Type{Autoregression}) = "AR"
