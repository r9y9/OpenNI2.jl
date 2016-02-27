# OpenNI2

A Julia interface for OpenNI2. Currently only tested on osx 10.10.4.


## Dependencies

- [Julia](https://github.com/JuliaLang/julia) (master)
- [Cxx.jl](https://github.com/Keno/Cxx.jl) (master)
- [openni2](https://github.com/PointCloudLibrary/pcl) (2.2.0.33)

## Installation

Please make sure to your library search path includes the location of `libOpenNI2` before installation. For osx, you might need to set `DYLD_LIBRARY_PATH` as follows:

```
export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}:/usr/local/lib/ni2
```

If you have OpenNI2 property installed,  

```jl
Pkg.clone("https://github.com/r9y9/OpenNI2.jl")
Pkg.build("OpenNI2")
```

should complete installation.

### Notes for osx

Minimum steps to install OpenNI2:

```
brew homebrew/science/openni2
brew install openni2
export OPENNI2_INCLUDE=/usr/local/include/ni2
export OPENNI2_REDIST=/usr/local/lib/ni2
export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}:${OPENNI2_REDIST}
```
