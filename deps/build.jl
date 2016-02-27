using BinDeps
using Compat

@BinDeps.setup

libopenni2 = library_dependency("libOpenNI2", aliases=["libOpenNI2"])

provides(AptGet, "libopenni2-dev", libopenni2)

#=
@osx_only begin
    using Homebrew
    Homebrew.add("homebrew/science/openni2")
    provides(Homebrew.HB, "openni2", openni2)
end
=#

@BinDeps.install Dict(:libOpenNI2 => :libOpenNI2)
