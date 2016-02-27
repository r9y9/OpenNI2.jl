# OpenNI2

A Julia interface for OpenNI2.


## Installation

```
brew homebrew/science/openni2
brew install openni2
```

```
export OPENNI2_INCLUDE=/usr/local/include/ni2
export OPENNI2_REDIST=/usr/local/lib/ni2
export DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH}:${OPENNI2_REDIST}
```

```jl
Pkg.clone("https://github.com/r9y9/OpenNI2.jl")
Pkg.build("OpenNI2")
```
