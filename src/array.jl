abstract type AbstractDimensionalArray{T,N,D<:Tuple} <: AbstractArray{T,N} end

const AbDimArray = AbstractDimensionalArray

const StandardIndices = Union{AbstractArray,Colon,Integer}

# Interface methods ############################################################

dims(A::AbDimArray) = A.dims
bounds(A::AbDimArray) = bounds(dims(A))
@inline rebuild(x, data, dims=dims(x)) = rebuild(x, data, dims, refdims(x))
crs(A::AbDimArray) = firstcrs(map(crs, dims(A)))

firstcrs(crs::Nothing, args...) = firstcrs(args...)
firstcrs(crs, args...) = crs 
firstcrs() = nothing


# Array interface methods ######################################################

Base.size(A::AbDimArray) = size(parent(A))
Base.iterate(A::AbDimArray, args...) = iterate(parent(A), args...)
Base.show(io::IO, A::AbDimArray) = begin
    printstyled(io, label(A), ": "; color=:red)
    show(io, typeof(A))
    show(io, parent(A))
    printstyled(io, "\ndims: "; color=:magenta)
    show(io, dims(A))
    show(io, refdims(A))
    printstyled(io, "\nmetadata: "; color=:cyan)
end

Base.@propagate_inbounds Base.getindex(A::AbDimArray, I::Vararg{<:Integer}) =
    getindex(parent(A), I...)
Base.@propagate_inbounds Base.getindex(A::AbDimArray, I::Vararg{<:StandardIndices}) =
    rebuildsliced(A, getindex(parent(A), I...), I)

Base.@propagate_inbounds Base.view(A::AbDimArray, I::Vararg{<:StandardIndices}) =
    rebuildsliced(A, view(parent(A), I...), I)
            
Base.convert(::Type{Array{T,N}}, A::AbDimArray{T,N}) where {T,N} = 
    convert(Array{T,N}, parent(A))

Base.copy(A::AbDimArray) = rebuild(A, copy(parent(A)))
Base.copy!(dst::AbDimArray, src::AbDimArray) = copy!(parent(dst), parent(src))
Base.copy!(dst::AbDimArray, src::AbstractArray) = copy!(parent(dst), src)
Base.copy!(dst::AbstractArray, src::AbDimArray) = copy!(dst, parent(src))

Base.BroadcastStyle(::Type{<:AbDimArray}) = Broadcast.ArrayStyle{AbDimArray}()

Base.similar(A::AbDimArray) = rebuild(A, similar(parent(A)))
Base.similar(A::AbDimArray, ::Type{T}) where T = rebuild(A, similar(parent(A), T))
Base.similar(A::AbDimArray, ::Type{T}, I::Tuple{Int64,Vararg{Int64}}) where T = 
    rebuild(A, similar(parent(A), T, I))
Base.similar(A::AbDimArray, ::Type{T}, I::Tuple{Union{Integer,AbstractRange},Vararg{Union{Integer,AbstractRange},N}}) where {T,N} =
    rebuildsliced(A, similar(parent(A), T, I...), I)
Base.similar(A::AbDimArray, ::Type{T}, I::Vararg{<:Integer}) where T =
    rebuildsliced(A, similar(parent(A), T, I...), I)
Base.similar(bc::Broadcast.Broadcasted{Broadcast.ArrayStyle{AbDimArray}}, ::Type{ElType}) where ElType = begin
    A = find_dimensional(bc)
    # TODO How do we know what the new dims are?
    rebuildsliced(A, similar(Array{ElType}, axes(bc)), axes(bc))
end

# Need to cover a few type signatures to avoid ambiguity with base
# Don't remove these even though they look redundant

@inline find_dimensional(bc::Base.Broadcast.Broadcasted) = find_dimensional(bc.args)
@inline find_dimensional(ext::Base.Broadcast.Extruded) = find_dimensional(ext.x)
@inline find_dimensional(args::Tuple{}) = error("dimensional array not found")
@inline find_dimensional(args::Tuple) = find_dimensional(find_dimensional(args[1]), tail(args))
@inline find_dimensional(x) = x
@inline find_dimensional(A::AbDimArray, rest) = A
@inline find_dimensional(::Any, rest) = find_dimensional(rest)


# Concrete implementation ######################################################

"""
    DimensionalArray(A::AbstractArray, dims::Tuple, refdims::Tuple) 

A basic DimensionalArray type.

Maintains and updates its dimensions through transformations
"""
struct DimensionalArray{T,N,D<:Tuple,R<:Tuple,A<:AbstractArray{T,N}} <: AbstractDimensionalArray{T,N,D}
    data::A
    dims::D
    refdims::R
end
"""
    DimensionalArray(A::AbstractArray, dims::Tuple; refdims=()) 
Constructor with optional `refdims` keyword.

Example:

```
using Dates, DimensionalData
using DimensionalData: Time, X
timespan = DateTime(2001):Month(1):DateTime(2001,12)
A = DimensionalArray(rand(12,10), (Time(timespan), X(10:10:100))) 
A[X<|Near([12, 35]), Time<|At(DateTime(2001,5))]
A[Near(DateTime(2001, 5, 4)), Between(20, 50)]
```
"""
DimensionalArray(A::AbstractArray, dims; refdims=()) = 
    DimensionalArray(A, formatdims(A, dims), refdims)

# Getters
refdims(A::DimensionalArray) = A.refdims

# DimensionalArray interface
@inline rebuild(A::DimensionalArray, data, dims, refdims) = 
    DimensionalArray(data, dims, refdims)

# Array interface (AbstractDimensionalArray takes care of everything else)
Base.parent(A::DimensionalArray) = A.data

Base.@propagate_inbounds Base.setindex!(A::DimensionalArray, x, I::Vararg{StandardIndices}) =
    setindex!(parent(A), x, I...)
