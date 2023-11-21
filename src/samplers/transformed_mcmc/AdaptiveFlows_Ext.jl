# This file is a part of BAT.jl, licensed under the MIT License (MIT).
(f::CompositeFlow)(x::ShapedAsNTArray, vs::AbstractValueShape) = vs.(nestedview(f(Matrix(flatview(unshaped.(x))))))
(f::CompositeFlow)(x::SubArray) = f(Vector(x))
(f::CompositeFlow)(x::ArrayOfSimilarArrays) = nestedview(f(flatview(x)))
(f::CompositeFlow)(x::DensitySampleVector) = apply_flow_to_density_samples(f, x)
(f::CompositeFlow)(x::ElasticArrays.ElasticMatrix) = f(Matrix(reshape(x[1], :, 1)))
(f::CompositeFlow)(x::AbstractVector) = vec(f(reshape(x, :, 1)))

(f::RQSplineCouplingModule)(x::ShapedAsNTArray, vs::AbstractValueShape) = vs.(nestedview(f(Matrix(flatview(unshaped.(x))))))
(f::RQSplineCouplingModule)(x::SubArray) = f(Vector(x))
(f::RQSplineCouplingModule)(x::ArrayOfSimilarArrays) = nestedview(f(flatview(x)))
(f::RQSplineCouplingModule)(x::DensitySampleVector) = apply_flow_to_density_samples(f, x)
(f::RQSplineCouplingModule)(x::ElasticArrays.ElasticMatrix) = f(Matrix(reshape(x[1], :, 1)))
(f::RQSplineCouplingBlock)(x::AbstractVector) = vec(f(reshape(x, :, 1)))
(f::InverseRQSplineCouplingBlock)(x::AbstractVector) = vec(f(reshape(x, :, 1)))
 

function ChangesOfVariables.with_logabsdet_jacobian(f::RQSplineCouplingModule, x::ArrayOfSimilarArrays)
    y, ladj = with_logabsdet_jacobian(f, Matrix(flatview(x)))
    return nestedview(y), ladj
end    

function ChangesOfVariables.with_logabsdet_jacobian(f::RQSplineCouplingModule, x::SubArray)
    return with_logabsdet_jacobian(f, Vector(x))
end    

function ChangesOfVariables.with_logabsdet_jacobian(f::RQSplineCouplingBlock, x::AbstractVector)
    y, ladj = ChangesOfVariables.with_logabsdet_jacobian(f, reshape(x, :, 1))
    return vec(y), ladj[1]
end

function ChangesOfVariables.with_logabsdet_jacobian(f::InverseRQSplineCouplingBlock, x::AbstractVector)
    y, ladj = ChangesOfVariables.with_logabsdet_jacobian(f, reshape(x, :, 1))
    return vec(y), ladj[1]
end


function ChangesOfVariables.with_logabsdet_jacobian(f::CompositeFlow,x::Matrix{Float64})
    y, ladj = ChangesOfVariables.with_logabsdet_jacobian(f.flow.fs[2], x)
    return y, ladj
end

#function ChangesOfVariables.with_logabsdet_jacobian(f::CompositeFlow, x::AbstractVector)
#    y, ladj = ChangesOfVariables.with_logabsdet_jacobian(f, reshape(x, :, 1))
#    return vec(y), ladj[1]
#end

function ChangesOfVariables.with_logabsdet_jacobian(f::CompositeFlow, x::AbstractVector)
    global g_state = (f.flow.fs[2], reshape(x, :, 1))
    y, ladj = ChangesOfVariables.with_logabsdet_jacobian(f.flow.fs[2], Matrix(reshape(x, :, 1)))
    return vec(y), ladj[1]
end


function Vector2Matrix(x::AbstractVector)::Matrix{Float64}
    zeilen = length(x[1])
    spalten = length(x)
    matrix::Matrix{Float64} = zeros(zeilen,spalten)
    for i in 1:zeilen
        for j in 1:spalten
            matrix[i,j] = x[j][i]
        end
    end
    return matrix
end

function apply_flow_to_density_samples(f::AdaptiveFlows.AbstractFlow, x::DensitySampleVector)
    v_flat = unshaped.(x.v)
    y_flat, ladj = with_logabsdet_jacobian(f, Vector2Matrix(v_flat))
    y = [y_flat[1:end,i] for i in 1:size(y_flat)[2]]
    global g_state = (x, x.logd, y, ladj, x.logd .- ladj)

    return DensitySampleVector((y, vec(x.logd .- transpose(ladj)), x.weight,  x.aux, x.info))
end
