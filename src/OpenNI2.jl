module OpenNI2

using Cxx

import Base: open, close, start

using BinDeps

# Load required dependency
deps = joinpath(Pkg.dir("OpenNI2"), "deps", "deps.jl")
if isfile(deps)
    include(deps)
else
    error("OpenNI2 not properly installed. Please run Pkg.build(\"OpenNI2\")")
end
Libdl.dlopen(libOpenNI2, Libdl.RTLD_GLOBAL)

ni2_header_path = replace(dirname(libOpenNI2), "/lib\/ni2", "/include\/ni2")
addHeaderDir(ni2_header_path, kind=C_System)

cxx"""
#include <memory>
#include <OpenNI.h>
"""

typealias StdSharedPtr{T} cxxt"std::shared_ptr<$T>"

### Enums ###

for name in [
    :STATUS_OK,
    :STATUS_ERROR,
    :STATUS_NOT_IMPLEMENTED,
    :STATUS_NOT_SUPPORTED,
    :STATUS_BAD_PARAMETER,
    :STATUS_OUT_OF_FLOW,
    :STATUS_NO_DEVICE,
    :STATUS_TIME_OUT,
    :SENSOR_IR,
    :SENSOR_COLOR,
    :SENSOR_DEPTH,
    :PIXEL_FORMAT_DEPTH_1_MM,
    :PIXEL_FORMAT_DEPTH_100_UM,
    :PIXEL_FORMAT_SHIFT_9_2,
    :PIXEL_FORMAT_SHIFT_9_3,
    :PIXEL_FORMAT_RGB888,
    :PIXEL_FORMAT_YUV422,
    :PIXEL_FORMAT_GRAY8,
    :PIXEL_FORMAT_GRAY16,
    :PIXEL_FORMAT_JPEG,
    :PIXEL_FORMAT_YUYV,
    :DEVICE_STATE_OK,
    :DEVICE_STATE_ERROR,
    :DEVICE_STATE_NOT_READY,
    :DEVICE_STATE_EOF,
    :IMAGE_REGISTRATION_OFF,
    :IMAGE_REGISTRATION_DEPTH_TO_COLOR,
    ]
    cppname = string("openni::", name)
    ex = Expr(:macrocall, symbol("@icxx_str"), string(cppname, ";"))
    @eval begin
        global const $name = $ex
        @assert isa($name, Cxx.CppEnum)
    end
end

const ANY_DEVICE = icxx"openni::ANY_DEVICE;"
const SensorType = Cxx.CppEnum{symbol("openni::SensorType"),UInt32}

function getExtendedError()
    icxx"openni::OpenNI::getExtendedError();" |> bytestring
end

@inline function checkStatus(rc)
    if rc != STATUS_OK
        error("[OpenNI error (code: $(rc.val))]:\n$(getExtendedError())")
    end
    rc
end

function initialize()
    rc = icxx"openni::OpenNI::initialize();"
    checkStatus(rc)
end

shutdown() = icxx"openni::OpenNI::shutdown();"


### DeviceInfo ###

type DeviceInfo{T}
    handle::T
end

for f in [
    :getUri,
    :getVendor,
    :getName,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(di.handle).$f();")
    @eval $f(di::DeviceInfo) = $ex |> bytestring
end

for f in [
    :getUsbVendorId,
    :getUsbProductId,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(di.handle).$f();")

    @eval $f(di::DeviceInfo) = $ex
end

### SensorInfo ###

# stream->getSensorInfo() return a const reference
type SensorInfo{T}
    handle::T
end

# but device->getSensorInfo(type) return a pointer
type SensorInfoPtr{T}
    handle::T
end

getSensorType(si::SensorInfo) = icxx"$(si.handle).getSensorType();"
getSensorType(si::SensorInfoPtr) = icxx"$(si.handle)->getSensorType();"


### Device ###

type DevicePtr{T<:StdSharedPtr}
    handle::T
end

function (::Type{DevicePtr})()
    handle =  icxx"std::shared_ptr<openni::Device>(new openni::Device);"
    DevicePtr(handle)
end

function open(device::DevicePtr, deviceURI=ANY_DEVICE)
    rc = icxx"$(device.handle)->open($deviceURI);"
    checkStatus(rc)
end

for f in [
    :setDepthColorSyncEnabled,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(device.handle)->$f(\$v);")
    @eval begin
        function $f(device::DevicePtr, v)
            rc = $ex
            checkStatus(rc)
        end
    end
end

for f in [
    :close,
    :isValid,
    :isFile,
    :getDepthColorSyncEnabled,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(device.handle)->$f();")
    @eval $f(device::DevicePtr) = $ex
end

function hasSensor(device::DevicePtr, sensorType::SensorType)
    icxx"$(device.handle)->hasSensor($sensorType);"
end

function getDeviceInfo(device::DevicePtr)
    handle = icxx"$(device.handle)->getDeviceInfo();"
    @assert isa(handle, Cxx.CppRef)
    DeviceInfo(handle)
end

function getSensorInfo(device::DevicePtr, sensorType::SensorType)
    handle = icxx"$(device.handle)->getSensorInfo($sensorType);"
    @assert isa(handle, Cxx.CppPtr)
    SensorInfoPtr(handle)
end

# workaround to dispatch on openni::Array<T>
type SupportedVideoModes{T}
    handle::T
end

function getSupportedVideoModes(si::SensorInfo)
    handle = icxx"$(si.handle).getSupportedVideoModes();"
    SupportedVideoModes(handle)
end

function getSupportedVideoModes(si::SensorInfoPtr)
    handle = icxx"$(si.handle)->getSupportedVideoModes();"
    SupportedVideoModes(handle)
end

# TODO: should dispatch on openni::Array<T>
Base.start(ar::SupportedVideoModes) = 0
Base.next(ar::SupportedVideoModes,i) = (ar[i], i+1)
Base.done(ar::SupportedVideoModes,i) = i >= length(ar)
Base.getindex(ar::SupportedVideoModes,i) = icxx"($(ar.handle))[$i];"
Base.length(ar::SupportedVideoModes) = icxx"$(ar.handle).getSize();"

### VideoStream ###

type VideoStreamPtr{T<:StdSharedPtr}
    handle::T
end

function (::Type{VideoStreamPtr})()
    handle = icxx"std::shared_ptr<openni::VideoStream>(new openni::VideoStream);"
    VideoStreamPtr(handle)
end

function create(stream::VideoStreamPtr, device::DevicePtr,
        typ::Cxx.CppEnum=SENSOR_DEPTH)
    rc = icxx"$(stream.handle)->create(*$(device.handle), $typ);"
    checkStatus(rc)
end

for f in [
    :setVideoMode,
    :setMirroringEnabled,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(stream.handle)->$f(\$v);")
    @eval begin
        function $f(stream::VideoStreamPtr, v)
            rc = $ex
            checkStatus(rc)
        end
    end
end

for f in [:start, :resetCropping]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(stream.handle)->$f();")
    @eval begin
        function $f(stream::VideoStreamPtr)
            rc = $ex
            checkStatus(rc)
        end
    end
end

for f in [
    :stop,
    :destroy,
    :isValid,
    :getVideoMode,
    :getMaxPixelValue,
    :getMinPixelValue,
    :isCroppingSupported,
    :getMirroringEnabled,
    :getHorizontalFieldOfView,
    :getVerticalFieldOfView,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(stream.handle)->$f();")
    @eval $f(stream::VideoStreamPtr) = $ex
end

function getSensorInfo(stream::VideoStreamPtr)
    handle = icxx"$(stream.handle)->getSensorInfo();"
    SensorInfo(handle)
end


typealias VideoMode cxxt"openni::VideoMode"
typealias VideoModeRef rcpp"openni::VideoMode"
const VideoModeValOrRef = Union{VideoMode, VideoModeRef}

for f in [
    :getPixelFormat,
    :getResolutionX,
    :getResolutionY,
    :getFps,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(videoMode).$f();")
    @eval $f(videoMode::VideoModeValOrRef) = $ex
end

function waitForAnyStream(streams)
    raw_streams = pcpp"openni::VideoStream"[]
    for s in streams
        push!(raw_streams, icxx"$(s.handle).get();")
    end

    # TODO:
    changedIndex = Cint[1]
    rc = icxx"""
    openni::OpenNI::waitForAnyStream($(pointer(raw_streams)),
        $(length(streams)),
        $(pointer(changedIndex)));
    """
    checkStatus(rc)
end

### VideoFrameRef ###

type VideoFrameRef{T}
    handle::T
end

function (::Type{VideoFrameRef})()
    handle = icxx"openni::VideoFrameRef();"
    VideoFrameRef(handle)
end

function readFrame(stream::VideoStreamPtr, frameRef)
    rc = icxx"$(stream.handle)->readFrame(&$(frameRef.handle));"
    checkStatus(rc)
end

for f in [
    :getDataSize,
    :getData,
    :getSensorType,
    :getVideoMode,
    :getTimestamp,
    :getFrameIndex,
    :getWidth,
    :getHeight,
    :getCroppingEnabled,
    :getCropOriginX,
    :getCropOriginY,
    :getStrideInBytes,
    :isValid,
    :release,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(frame.handle).$f();")
    @eval $f(frame::VideoFrameRef) = $ex
end

function Base.convert{T,N}(::Type{Array{T,N}}, frame::VideoFrameRef)
    mode = getVideoMode(frame)
    w = Int(getResolutionX(mode))
    h = Int(getResolutionY(mode))
    ar = pointer_to_array(convert(Ptr{T}, getData(frame)), w * h)
    reshape(ar, w, h)
end

end # module
