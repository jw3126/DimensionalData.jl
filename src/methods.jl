
# Reducing methods

for (mod, fname) in ((:Base, :sum), (:Base, :prod), (:Base, :maximum), (:Base, :minimum), (:Statistics, :mean))
    _fname = Symbol('_', fname)
    @eval begin
        # Returns a scalar
        @inline ($mod.$fname)(A::AbDimArray) = ($mod.$fname)(parent(A))
        # Returns a reduced array
        @inline ($mod.$_fname)(A::AbstractArray, dims::AllDimensions) =
            rebuild(A, ($mod.$_fname)(parent(A), dimnum(A, dims)), reducedims(A, dims))
        @inline ($mod.$_fname)(f, A::AbstractArray, dims::AllDimensions) =
            rebuild(A, ($mod.$_fname)(f, parent(A), dimnum(A, dims)), reducedims(A, dims))
        @inline ($mod.$_fname)(A::AbDimArray, dims::Union{Int,Base.Dims}) =
            rebuild(A, ($mod.$_fname)(parent(A), dims), reducedims(A, dims))
        @inline ($mod.$_fname)(f, A::AbDimArray, dims::Union{Int,Base.Dims}) =
            rebuild(A, ($mod.$_fname)(f, parent(A), dims), reducedims(A, dims))
    end
end

for (mod, fname) in ((:Statistics, :std), (:Statistics, :var))
    _fname = Symbol('_', fname)
    @eval begin
        # Returns a scalar
        @inline ($mod.$fname)(A::AbDimArray) = ($mod.$fname)(parent(A))
        # Returns a reduced array
        @inline ($mod.$_fname)(A::AbstractArray, corrected::Bool, mean, dims::AllDimensions) =
            rebuild(A, ($mod.$_fname)(A, corrected, mean, dimnum(A, dims)), reducedims(A, dims))
        @inline ($mod.$_fname)(A::AbDimArray, corrected::Bool, mean, dims::Union{Int,Base.Dims}) =
            rebuild(A, ($mod.$_fname)(parent(A), corrected, mean, dims), reducedims(A, dims))
    end
end

Statistics.median(A::AbDimArray) = Statistics.median(parent(A))
Statistics._median(A::AbstractArray, dims::AllDimensions) =
    rebuild(A, Statistics._median(parent(A), dimnum(A, dims)), reducedims(A, dims))
Statistics._median(A::AbDimArray, dims::Union{Int,Base.Dims}) =
    rebuild(A, Statistics._median(parent(A), dims), reducedims(A, dims))

Base._mapreduce_dim(f, op, nt::NamedTuple{(),<:Tuple}, A::AbstractArray, dims::AllDimensions) =
    rebuild(A, Base._mapreduce_dim(f, op, nt, parent(A), dimnum(A, dims)), reducedims(A, dims))
Base._mapreduce_dim(f, op, nt::NamedTuple{(),<:Tuple}, A::AbDimArray, dims::Union{Int,Base.Dims}) =
    rebuild(A, Base._mapreduce_dim(f, op, nt, parent(A), dimnum(A, dims)), reducedims(A, dims))
Base._mapreduce_dim(f, op, nt::NamedTuple{(),<:Tuple}, A::AbDimArray, dims::Colon) =
    Base._mapreduce_dim(f, op, nt, parent(A), dims)

# TODO: Unfortunately Base/accumulate.jl kwargs methods all force dims to be Integer.
# accumulate wont work unless that is relaxed, or we copy half of the file here.
Base._accumulate!(op, B, A, dims::AllDimensions, init::Union{Nothing, Some}) =
    Base._accumulate!(op, B, A, dimnum(A, dims), init)

Base._extrema_dims(f, A::AbstractArray, dims::AllDimensions) = begin
    dnums = dimnum(A, dims)
    rebuild(A, Base._extrema_dims(f, parent(A), dnums), reducedims(A, dnums))
end


# Dimension dropping

Base._dropdims(A::AbstractArray, dim::DimOrDimType) = 
    rebuildsliced(A, Base._dropdims(A, dimnum(A, dim)), dims2indices(A, basetypeof(dim)(1)))
Base._dropdims(A::AbstractArray, dims::AbDimTuple) = 
    rebuildsliced(A, Base._dropdims(A, dimnum(A, dims)), 
                  dims2indices(A, Tuple((basetypeof(d)(1) for d in dims))))


# Function application

@inline Base.map(f, A::AbDimArray) = rebuild(A, map(f, parent(A)), dims(A))

Base.mapslices(f, A::AbDimArray; dims=1, kwargs...) = begin
    dimnums = dimnum(A, dims)
    data = mapslices(f, parent(A); dims=dimnums, kwargs...)
    rebuild(A, data, reducedims(A, DimensionalData.dims(A, dimnums)))
end

# This is copied from base as we can't efficiently wrap this function
# through the kwarg with a rebuild in the generator. Doing it this way 
# wierdly makes it faster toeuse a dim than an integer.
if VERSION > v"1.1-"
    Base.eachslice(A::AbDimArray; dims=1, kwargs...) = begin
        if dims isa Tuple && length(dims) == 1 
            throw(ArgumentError("only single dimensions are supported"))
        end
        dim = first(dimnum(A, dims))
        dim <= ndims(A) || throw(DimensionMismatch("A doesn't have $dim dimensions"))
        idx1, idx2 = ntuple(d->(:), dim-1), ntuple(d->(:), ndims(A)-dim)
        return (view(A, idx1..., i, idx2...) for i in axes(A, dim))
    end
end


for fname in (:cor, :cov)
    @eval Statistics.$fname(A::AbDimArray{T,2}; dims=1, kwargs...) where T = begin
        newdata = Statistics.$fname(parent(A); dims=dimnum(A, dims), kwargs...)
        I = dims2indices(A, dims, 1)
        newdims, newrefdims = slicedims(A, I)
        rebuild(A, newdata, (newdims[1], newdims[1]), newrefdims)
    end
end


# Reverse

@inline Base.reverse(A::AbDimArray{T,N}; dims=1) where {T,N} = begin
    dnum = dimnum(A, dims)
    # Reverse the dimension. TODO: make this type stable
    newdims = reversearray(DimensionalData.dims(A), dnum)
    # Reverse the data
    newdata = reverse(parent(A); dims=dnum)
    rebuild(A, newdata, newdims, refdims(A))
end

@inline reversearray(dimstorev::Tuple, dnum) = begin
    dim = dimstorev[end]
    if length(dimstorev) == dnum 
        dim = rebuild(dim, val(dim), reversearray(grid(dim)))
    end
    (reversearray(Base.front(dimstorev), dnum)..., dim) 
end
@inline reversearray(dims::Tuple{}, i) = ()


# Dimension reordering

for (pkg, fname) in [(:Base, :permutedims), (:Base, :adjoint), 
                     (:Base, :transpose), (:LinearAlgebra, :Transpose)]
    @eval begin
        @inline $pkg.$fname(A::AbDimArray{T,2}) where T =
            rebuild(A, $fname(parent(A)), reverse(dims(A)), refdims(A))
    end
end

for fname in [:permutedims, :PermutedDimsArray]
    @eval begin
        @inline Base.$fname(A::AbDimArray{T,N}, perm) where {T,N} = 
            rebuild(A, $fname(parent(A), dimnum(A, perm)), permutedims(dims(A), perm))
    end
end


# Indices

Base.firstindex(A::AbstractArray, d::DimOrDimType) = firstindex(A, dimnum(A, d))
Base.lastindex(A::AbstractArray, d::DimOrDimType) = lastindex(A, dimnum(A, d))


# Concatenation

Base._cat(catdims::Union{AbDim,AbDimTuple}, A::DimensionalArray...) = begin
    A1 = first(A)
    checkdims(A...)
    if all(hasdim(A1, catdims))
        dnum = dimnum(A1, catdims)
        newdims = map(zip(map(dims, A)...)) do ds
            basetypeof(catdims) <: basetypeof(ds[1]) ? vcat(ds...) : ds[1]
        end
        rebuild(A1, Base._cat(dnum, map(parent, A)...), ) 
    else
        add_dims = if (catdims isa Tuple) 
            Tuple(d for d in catdims if !hasdim(A1, d)) 
        else
            (catdims,)
        end
        dnum = ndims(A1) + length(add_dims)
        newA = Base._cat(dnum, map(parent, A)...)
        newdims = (dims(A1)..., add_dims...)
        rebuild(A1, newA, formatdims(size(newA), newdims)) 
    end
end

Base.vcat(A::AbDimArray...) = begin
    checkdims(A...)
    rebuild(A, vcat(map(val, A)), vcat(map(A, dims)))
end
Base.vcat(dims::AbDim...) =
    rebuild(dims[1], vcat(map(val, dims)), vcat(map(grid, dims)))

Base.vcat(grids::Grid...) = first(grids)
Base.vcat(grids::BoundedGrid...) = 
    rebuild(grids[1]; bounds=(bounds(grids[1])[1], bounds(grids[end])[end]))

checkdims(A::AbstractArray...) = checkdims(map(dims, A)...)
checkdims(dims::AbDimTuple...) = map(d -> checkdims(dims[1], d), dims)
checkdims(d1::AbDimTuple, d2::AbDimTuple) = map(checkdims, d1, d2) 
checkdims(d1::AbDim, d2::AbDim) = 
    basetypeof(d2) <: basetypeof(d1) || error("Dims differ: $(bastypeof(d1)), $(basetypeof(d2))")


# Index breaking

# TODO: change the index and traits of the reduced dimension
# and return a DimensionalArray.
Base.unique(A::AbDimArray{<:Any,1}) = unique(parent(A)) 
Base.unique(A::AbDimArray; dims::DimOrDimType) = 
    unique(parent(A); dims=dimnum(A, dims))


# TODO cov, cor mapslices, eachslice, reverse, sort and sort! need _methods without kwargs in base so
# we can dispatch on dims. Instead we dispatch on array type for now, which means
# these aren't usefull unless you inherit from AbDimArray.

