module NiTE

using ..OpenNI2
using Cxx

import ..OpenNI2: libNiTE2
Libdl.dlopen(libNiTE2, Libdl.RTLD_GLOBAL)

nite_header_path = replace(dirname(libNiTE2), "\/Redist", "\/Include")
@assert isdir(nite_header_path)
addHeaderDir(nite_header_path, kind=C_System)

cxx"""
#include <NiTE.h>
"""

### NiteEnums ###

for name in [
    # JointType
    :JOINT_HEAD,
	:JOINT_NECK,
	:JOINT_LEFT_SHOULDER,
	:JOINT_RIGHT_SHOULDER,
	:JOINT_LEFT_ELBOW,
	:JOINT_RIGHT_ELBOW,
	:JOINT_LEFT_HAND,
	:JOINT_RIGHT_HAND,
	:JOINT_TORSO,
	:JOINT_LEFT_HIP,
	:JOINT_RIGHT_HIP,
	:JOINT_LEFT_KNEE,
	:JOINT_RIGHT_KNEE,
	:JOINT_LEFT_FOOT,
	:JOINT_RIGHT_FOOT,

    # SkeletonState
    :SKELETON_NONE,
	:SKELETON_CALIBRATING,
	:SKELETON_TRACKED,
	:SKELETON_CALIBRATION_ERROR_NOT_IN_POSE,
	:SKELETON_CALIBRATION_ERROR_HANDS,
	:SKELETON_CALIBRATION_ERROR_HEAD,
	:SKELETON_CALIBRATION_ERROR_LEGS,
	:SKELETON_CALIBRATION_ERROR_TORSO,

    # Status
    :STATUS_OK,
    :STATUS_ERROR,
    :STATUS_BAD_USER_ID,
    :STATUS_OUT_OF_FLOW,

    # PostType
    :POSE_PSI,
    :POSE_CROSSED_HANDS,

    # GestureType
    :GESTURE_WAVE,
    :GESTURE_CLICK,
    :GESTURE_HAND_RAISE,
    ]
    cppname = string("nite::", name)
    ex = Expr(:macrocall, symbol("@icxx_str"), string(cppname, ";"))
    @eval begin
        global const $name = $ex
        @assert isa($name, Cxx.CppEnum)
    end
end

@inline function checkStatus(rc)
    if rc != STATUS_OK
        error("[NiTE error (code: $(rc.val))]:\n$(OpenNI2.getExtendedError())")
    end
    rc
end

### nite::NiTE::xxx ###

function initialize()
    rc = icxx"nite::NiTE::initialize();"
    checkStatus(rc)
end
shutdown() = icxx"nite::NiTE::shutdown();"
getVersion() = icxx"nite::NiTE::getVersion();"

### UserTracker ###

type UserTracker{T}
    handle::T
end
function UserTracker()
    handle = icxx"nite::UserTracker();"
    UserTracker(handle)
end

function create(tracker::UserTracker, device::OpenNI2.DevicePtr)
    icxx"$(tracker.handle).create($(device.handle).get());"
end

destroy(tracker::UserTracker) = icxx"$(tracker.handle).destroy();"

function setSkeletonSmoothingFactor(tracker::UserTracker, v)
    icxx"$(tracker.handle).setSkeletonSmoothingFactor($v);"
end

function convertJointCoordinatesToDepth(tracker::UserTracker, x, y, z)
    outX = Cfloat[1]
    outY = Cfloat[1]
    icxx"$(tracker.handle).convertJointCoordinatesToDepth(
            $x,$y,$z,$(pointer(outX)),$(pointer(outY)));"
    outX[1],outY[1]
end

for f in [
    :startSkeletonTracking,
    :stopSkeletonTracking,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(tracker.handle).$f(\$id);")
    @eval $f(tracker::UserTracker, id) = $ex
end

### UserTrackerFrameRef ###

type UserTrackerFrameRef{T}
    handle::T
end
function UserTrackerFrameRef()
    handle = icxx"nite::UserTrackerFrameRef();"
    UserTrackerFrameRef(handle)
end

for f in [
    :isValid,
    :release,
    :getFloorConfidence,
    :getFloor,
    :getDepthFrame,
    :getUserMap,
    :getTimestamp,
    :getFrameIndex,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$(frame.handle).$f();")
    @eval $f(frame::UserTrackerFrameRef) = $ex
end

function readFrame(tracker::UserTracker, frameRef::UserTrackerFrameRef)
    rc = icxx"$(tracker.handle).readFrame(&$(frameRef.handle));"
    checkStatus(rc)
end

typealias UserData Union{cxxt"nite::UserData", cxxt"nite::UserData&"}

for f in [
    :getId,
    :getBoundingBox,
    :getCenterOfMass,
    :isNew,
    :isVisible,
    :isLost,
    :getSkeleton,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$user.$f();")
    @eval $f(user::UserData) = $ex
end

# Wrap nite::Array<nite::UserData> into a Julia type to give array-like access
type UserDataArray{T}
    array::T
end
Base.start(ar::UserDataArray) = 0
Base.next(ar::UserDataArray,i) = (ar[i], i+1)
Base.done(ar::UserDataArray,i) = i >= length(ar)
Base.getindex(ar::UserDataArray,i) = icxx"($(ar.array))[$i];"
Base.length(ar::UserDataArray) = icxx"$(ar.array).getSize();"

function getUsers(frame::UserTrackerFrameRef)
    users = icxx"$(frame.handle).getUsers();"
    UserDataArray(users)
end

### Skeleton ###

typealias Skeleton Union{cxxt"nite::Skeleton", cxxt"nite::Skeleton&"}

function getJoint(s::Skeleton, typ)
    icxx"$s.getJoint($typ);"
end

getState(s::Skeleton) = icxx"$s.getState();"

### SkeletonJoint ###

typealias SkeletonJoint Union{cxxt"nite::SkeletonJoint", cxxt"nite::SkeletonJoint&"}

for f in [
    :getType,
    :getPosition,
    :getPositionConfidence,
    :getOrientation,
    :getOrientationConfidence,
    ]
    ex = Expr(:macrocall, symbol("@icxx_str"), "\$s.$f();")
    @eval $f(s::SkeletonJoint) = $ex
end

### Point3f ###

typealias Point3f Union{cxxt"nite::Point3f", cxxt"nite::Point3f&"}

function Base.show(io::IO, p::Point3f)
    x = icxx"$p.x;"
    y = icxx"$p.y;"
    z = icxx"$p.z;"
    # println(io, string(typeof(p)));
    println(io, "nite::Point3f")
    print(io, "(x,y,z): ");
    print(io, (x,y,z))
end

### Quaternion ###

typealias Quaternion Union{cxxt"nite::Quaternion", cxxt"nite::Quaternion&"}

function Base.show(io::IO, p::Quaternion)
    x = icxx"$p.x;"
    y = icxx"$p.y;"
    z = icxx"$p.z;"
    w = icxx"$p.w;"
    # println(io, string(typeof(p)));
    println(io, "nite::Quaternion")
    print(io, "(x,y,z,w): ");
    print(io, (x,y,z,w))
end

end # module
