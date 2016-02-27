module OpenNI2

using Cxx

import Base: open, close, start

Libdl.dlopen("/usr/local/lib/ni2/libOpenNI2.dylib", Libdl.RTLD_GLOBAL)
addHeaderDir("/usr/local/include/ni2/", kind=C_System)

cxx"""
#include <memory>
#include <OpenNI.h>
"""

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

function getExtendedError()
    icxx"openni::OpenNI::getExtendedError();" |> bytestring
end

@inline function checkStatus(rc)
    if rc != STATUS_OK
        error("[OpenNI error (code: $(rc.val))]:\n$(getExtendedError())")
    end
    rc.val
end

function initialize()
    rc = icxx"openni::OpenNI::initialize();"
    checkStatus(rc)
end

shutdown() = icxx"openni::OpenNI::shutdown();"

### Device ###

type OpenNIDevice{T}
    handle::T
end

function (::Type{OpenNIDevice})()
    handle =  icxx"std::shared_ptr<openni::Device>(new openni::Device);"
    OpenNIDevice(handle)
end

function open(device::OpenNIDevice, deviceURI=ANY_DEVICE)
    rc = icxx"$(device.handle)->open($deviceURI);"
    checkStatus(rc)
end

for f in [
    :setDepthColorSyncEnabled,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(device.handle)->$f(\$v);")
    @eval begin
        function $f(device::OpenNIDevice, v)
            rc = $ex
            checkStatus(rc)
        end
    end
end

for f in [
    :close,
    :getDeviceInfo,
    :isValid,
    :isFile,
    :getDepthColorSyncEnabled,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(device.handle)->$f();")
    @eval $f(device::OpenNIDevice) = $ex
end

const SensorType = Cxx.CppEnum{symbol("openni::SensorType"),UInt32}

function hasSensor(device::OpenNIDevice, sensorType::SensorType)
    icxx"$(device.handle)->hasSensor($sensorType);"
end

function getSensorInfo(device::OpenNIDevice, sensorType::SensorType)
    handle = icxx"$(device.handle)->getSensorInfo($sensorType);"
    @assert isa(handle, Cxx.CppPtr)
    SensorInfoPtr(handle)
end


### SensorInfo ###

# stram->getSensorInfo() return a const reference
type SensorInfo{T}
    handle::T
end

# but device->getSensorInfo(type) return a pointer
type SensorInfoPtr{T}
    handle::T
end

getSensorType(si::SensorInfo) = icxx"$(si.handle).getSensorType();"
getSensorType(si::SensorInfoPtr) = icxx"$(si.handle)->getSensorType();"

# workaround
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

type VideoStream{T}
    handle::T
end

function (::Type{VideoStream})()
    handle = icxx"std::shared_ptr<openni::VideoStream>(new openni::VideoStream);"
    VideoStream(handle)
end

function create(stream::VideoStream, device::OpenNIDevice,
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
        function $f(stream::VideoStream, v)
            rc = $ex
            checkStatus(rc)
        end
    end
end

for f in [:start, :resetCropping]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(stream.handle)->$f();")
    @eval begin
        function $f(stream::VideoStream)
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
    @eval $f(stream::VideoStream) = $ex
end

function getSensorInfo(stream::VideoStream)
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

function readFrame(stream::VideoStream, frameRef)
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
