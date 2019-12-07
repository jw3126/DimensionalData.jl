abstract type Order end

"""
Trait container for dimension and array ordering in AllignedGrid.

The default is `Ordered(Forward()`, `Forward())`

All combinations of forward and reverse order for data and indices seem to occurr
in real datasets, as strange as that seems. We cover these possibilities by specifying
the order of both explicitly.

Knowing the order of indices is important for using methods like `searchsortedfirst()`
to find indices in sorted lists of values. Knowing the order of the data is then
required to map to the actual indices. It's also used to plot the data later - which
always happens in smallest to largest order.

Base also defines Forward and Reverse, but they seem overly complicated for our purposes.
"""
struct Ordered{D,A,R} <: Order
    index::D
    array::A
    relation::R
end
Ordered() = Ordered(Forward(), Forward(), Forward())

indexorder(order::Ordered) = order.index
arrayorder(order::Ordered) = order.array
relationorder(order::Ordered) = order.relation

"""
Trait indicating that the array or dimension has no order.
"""
struct Unordered{R} <: Order
    relation::R
end
Unordered() = Unordered(Forward())

indexorder(order::Unordered) = order
arrayorder(order::Unordered) = order
relationorder(order::Unordered) = order.relation

"""
Trait indicating that the array or dimension is in the normal forward order.
"""
struct Forward <: Order end

"""
Trait indicating that the array or dimension is in the reverse order.
Selector lookup or plotting will be reversed.
"""
struct Reverse <: Order end

Base.reverse(::Reverse) = Forward()
Base.reverse(::Forward) = Reverse()
# Base.reverse(o::Ordered) =
    # Ordered(indexorder(o), reverse(relationorder(o)), reverse(arrayorder(o)))
# Base.reverse(o::Unordered) =
    # Unordered(reverse(relationorder(o)))

reverseindex(o::Unordered) =
    Unordered(reverse(relationorder(o)))
reverseindex(o::Ordered) =
    Ordered(reverse(indexorder(o)), arrayorder(o), reverse(relationorder(o)))

reversearray(o::Unordered) =
    Unordered(reverse(relationorder(o)))
reversearray(o::Ordered) =
    Ordered(indexorder(o), reverse(arrayorder(o)), reverse(relationorder(o)))

isrev(::Forward) = false
isrev(::Reverse) = true


"""
Indicates wether the cell value is specific to the locus point
or is related to the whole the span.

The span may contain a value if the distance between locii if known.
This will often be identical to the distance between any two sequential
cell values, but may be distinct due to rounding errors in a vector index,
or context-dependent spans such as `Month`.
"""
abstract type Sampling end

"""
Each cell value represents a single discrete sample taken at the index location.
"""
struct SingleSample <: Sampling end

"""
Multiple samples from the span combined using method `M`,
where `M` is `typeof(mean)`, `typeof(sum)` etc.
"""
struct MultiSample{M} <: Sampling end
MultiSample() = MultiSample{Nothing}()

"""
The sampling method is unknown.
"""
struct UnknownSampling <: Sampling end

"""
Indicate the position of index values in grid cells.

This is frequently `Start` for time series, but may be `Center`
for spatial data.
"""
abstract type Locus end

Base.length(x::Locus) = 1
Base.iterate(x::Locus) = (x, nothing)
Base.iterate(x::Locus, ::Any) = nothing

"""
Indicates dimensions that are defined by their center coordinates/time/position.
"""
struct Center <: Locus end

"""
Indicates dimensions that are defined by their start coordinates/time/position.
"""
struct Start <: Locus end

"""
Indicates dimensions that are defined by their end coordinates/time/position.
"""
struct End <: Locus end

struct UnknownLocus <: Locus end



"""
Traits describing the grid type of a dimension.
"""
abstract type Grid end

dims(g::Grid) = nothing
crs(g::Grid) = nothing
arrayorder(grid::Grid) = arrayorder(order(grid))
indexorder(grid::Grid) = indexorder(order(grid))
relationorder(grid::Grid) = relationorder(order(grid))

Base.reverse(g::Grid) = rebuild(g; order=reverse(order(g)))
reversearray(g::Grid) = rebuild(g; order=reversearray(order(g)))
reverseindex(g::Grid) = rebuild(g; order=reverseindex(order(g)))

"""
Fallback grid type
"""
struct UnknownGrid <: Grid end

order(::UnknownGrid) = Unordered()

"""
A grid dimension that is independent of other grid dimensions.
"""
abstract type IndependentGrid{O} <: Grid end

"""
A grid dimension aligned exactly with a standard dimension, such as lattitude or longitude.
"""
abstract type AbstractAllignedGrid{O} <: IndependentGrid{O} end

order(g::AbstractAllignedGrid) = g.order
locus(g::AbstractAllignedGrid) = g.locus
sampling(g::AbstractAllignedGrid) = g.sampling
crs(g::AbstractAllignedGrid) = g.crs

"""
An alligned grid without known regular spacing. These grids will generally be paired
with a vector of coordinates along the dimension, instead of a range.

As the size of the cells is not known, the bounds must be actively tracked.

## Fields
- `order`: `Order` trait indicating array and index order
- `locus`: `Locus` trait indicating the position of the indexed point within the cell span
- `sampling`: `Sampling` trait indicating wether the grid cells are single samples or means
- `bounds`: the outer edges of the grid (different to the first and last coordinate).
"""
struct AllignedGrid{O<:Order,L<:Locus,Sa<:Sampling,B,C,SC} <: AbstractAllignedGrid{O}
    order::O
    locus::L
    sampling::Sa
    bounds::B
    crs::C
    selector_crs::SC
end
AllignedGrid(; order=Ordered(), locus=Start(), sampling=UnknownSampling(),
             bounds=nothing, crs=nothing, selector_crs=nothing) =
    AllignedGrid(order, locus, sampling, bounds, crs, selector_crs)

bounds(g::AllignedGrid) = g.bounds

rebuild(g::AllignedGrid;
        order=order(g), locus=locus(g), sampling=sampling(g), 
        bounds=bounds(g), crs=crs(g), selector_crs=selector_crs(g)) =
    AllignedGrid(order, locus, sampling, bounds, crs, selector_crs)

"""
An alligned grid known to have equal spacing between all cells.

## Fields
- `order`: `Order` trait indicating array and index order
- `locus`: `Locus` trait indicating the position of the indexed point within the cell span
- `sampling`: `Sampling` trait indicating wether the grid cells are single samples or means
- `span`: the size of a grid step, such as 1u"km" or `Month(1)`
"""
struct RegularGrid{O<:Order,L<:Locus,Sa<:Sampling,Sp,C,SC} <: AbstractAllignedGrid{O}
    order::O
    locus::L
    sampling::Sa
    span::Sp
    crs::C
    selector_crs::SC
end
RegularGrid(; order=Ordered(), locus=Start(), sampling=UnknownSampling(),
            span=nothing, crs=nothing, selector_crs=nothing) =
    RegularGrid(order, locus, sampling, span, crs, selector_crs)

span(g::RegularGrid) = g.span

rebuild(g::RegularGrid; 
        order=order(g), locus=locus(g), sampling=sampling(g), 
        span=span(g), crs=crs(g), selector_crs=selector_crs(g)) =
    RegularGrid(order, locus, sampling, span, crs, selector_crs)


abstract type AbstractCategoricalGrid{O} <: IndependentGrid{O} end

"""
A grid dimension where the values are categories.

## Fields
- `order`: `Order` trait indicating array and index order
"""
struct CategoricalGrid{O<:Order} <: AbstractCategoricalGrid{O}
    order::O
end
CategoricalGrid(; order=Ordered()) = CategoricalGrid(order)

order(g::CategoricalGrid) = g.order

rebuild(g::CategoricalGrid; order=order(g)) = CategoricalGrid(order)



"""
Traits describing a grid dimension that is dependent on other grid dimensions.

Indexing into a dependent dimension must provide all other dependent dimensions.
"""
abstract type DependentGrid <: Grid end

locus(g::DependentGrid) = g.locus
dims(g::DependentGrid) = g.dims
sampling(g::DependentGrid) = g.sampling
crs(g::AbstractAllignedGrid) = g.crs

"""
Grid type using an affine transformation to convert dimension from
`dim(grid)` to `dims(array)`.

## Fields
- `dims`: a tuple containing dimenension types or symbols matching the order
          needed by the transform function.
- `sampling`: a `Sampling` trait indicating wether the grid cells are sampled points or means
"""
struct TransformedGrid{D,L,Sa<:Sampling,C,SC} <: DependentGrid
    dims::D
    locus::L
    sampling::Sa
    crs::C
    selector_crs::SC
end
TransformedGrid(dims=(), locus=Start(), sampling=UnknownSampling(),
                crs=crs(g), selector_crs=selector_crs(g)) =
    TransformedGrid(dims, locus, sampling, crs, selector_crs)

rebuild(g::TransformedGrid; 
        dims=dims(g), locus=locus(g), sampling=sampling(g), 
        crs=crs(g), selector_crs=selector_crs(g)) =
    TransformedGrid(dims, locus, sampling, crs, selectorcrs)

"""
A grid dimension that uses an array lookup to convert dimension from
`dim(grid)` to `dims(array)`.

## Fields
- `dims`: a tuple containing dimenension types or symbols matching the order
          needed to index the lookup matrix.
- `sampling`: a `Sampling` trait indicating wether the grid cells are sampled points or means
"""
struct LookupGrid{D,L,Sa<:Sampling,C,SC} <: DependentGrid
    dims::D
    locus::L
    sampling::Sa
    crs::C
    selector_crs::SC
end
LookupGrid(dims=(), locus=Start(), sampling=UnknownSampling(),
           crs=crs(g), selector_crs=selector_crs(g)) =
    LookupGrid(dims, locus, sampling, crs, selector_crs)

rebuild(g::LookupGrid; 
        dims=dims(g), locus=locus(g), sampling=sampling(g), 
        crs=crs(g), selector_crs=selector_crs(g)) =
    LookupGrid(dims, locus, sampling, crs, selector_crs)
