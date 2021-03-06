using DimensionalData, Test

using DimensionalData: val, basetypeof, slicedims, dims2indices, formatdims, hasdim, swapdim,
      @dim, reducedims, dimnum, X, Y, Z, Time, Forward

dimz = (X(), Y())

@testset "permutedims" begin
    @test permutedims((Y(1:2), X(1)), dimz) == (X(1), Y(1:2))
    @test permutedims((X(1),), dimz) == (X(1), nothing)
    @test permutedims((Y(), X()), dimz) == (X(:), Y(:))
    @test permutedims([Y(), X()], dimz) == (X(:), Y(:))
    @test permutedims((Y, X),     dimz) == (X(:), Y(:))
    @test permutedims([Y, X],     dimz) == (X(:), Y(:))
    @test permutedims(dimz, (Y(), X())) == (Y(:), X(:))
    @test permutedims(dimz, [Y(), X()]) == (Y(:), X(:))
    @test permutedims(dimz, (Y, X)    ) == (Y(:), X(:))
    @test permutedims(dimz, [Y, X]    ) == (Y(:), X(:))
end

a = [1 2 3; 4 5 6]
da = DimensionalArray(a, (X((143, 145)), Y((-38, -36))))
dimz = dims(da) 

@testset "slicedims" begin
    @test slicedims(dimz, (1:2, 3)) == ((X(LinRange(143,145,2); grid=RegularGrid(span=2.0)),), 
                                        (Y(-36.0; grid=RegularGrid(span=1.0)),))
    @test slicedims(dimz, (2:2, :)) == ((X(LinRange(145,145,1); grid=RegularGrid(span=2.0)), 
                                         Y(LinRange(-38.0,-36.0,3); grid=RegularGrid(span=1.0))), ())
    @test slicedims((), (1:2, 3)) == ((), ())
end

@testset "dims2indices" begin
    emptyval = Colon()
    @test dims2indices(grid(dimz[1]), dimz[1], Y, Nothing) == Colon()
    @test dims2indices(dimz, (Y(),), emptyval) == (Colon(), Colon())
    @test dims2indices(dimz, (Y(1),), emptyval) == (Colon(), 1)
    # Time is just ignored if it's not in dims. Should this be an error?
    @test dims2indices(dimz, (Time(4), X(2))) == (2, Colon())
    @test dims2indices(dimz, (Y(2), X(3:7)), emptyval) == (3:7, 2)
    @test dims2indices(dimz, (X(2), Y([1, 3, 4])), emptyval) == (2, [1, 3, 4])
    @test dims2indices(da, (X(2), Y([1, 3, 4])), emptyval) == (2, [1, 3, 4])
    emptyval=()
    @test dims2indices(dimz, (Y,), emptyval) == ((), Colon())
    @test dims2indices(dimz, (Y, X), emptyval) == (Colon(), Colon())
    @test dims2indices(da, X, emptyval) == (Colon(), ())
end

@testset "dimnum" begin
    @test dimnum(da, X) == 1
    @test dimnum(da, Y()) == 2
    @test dimnum(da, (Y, X())) == (2, 1)
    @test_throws ArgumentError dimnum(da, Time) == (2, 1)
end

@testset "reducedims" begin
    @test reducedims((X(3:4), Y(1:5)), (X, Y)) == (X(3), Y(1))
end

@testset "dims" begin
    @test typeof(dims(da, X)) <: X 
    @test typeof(dims(dims(da), Y)) <: Y 
    @test dims(da, ()) == ()
    @test_throws ArgumentError dims(da, Time)
    x = dims(da, X)
    @test dims(x) == x
end

@testset "hasdims" begin
    @test hasdim(da, X) == true
    @test hasdim(da, Time) == false
    @test hasdim(dims(da), Y) == true
    @test hasdim(dims(da), (X, Y)) == (true, true)
    @test hasdim(dims(da), (X, Time)) == (true, false)
end

@testset "swapdim" begin
    A = swapdim(da, X(LinRange(150,152,2)))
    @test val(dims(dims(A), X())) == LinRange(150,152,2) 
end
