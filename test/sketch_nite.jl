using Cxx
using OpenNI2
using OpenCV

const ni2 = OpenNI2
const nite = NiTE

isesc(key) = key == 27
genfilename(ext=".png") =
    joinpath(dirname(@__FILE__), string(now(), "_", time_ns(), ext))

always_save = false
show_depth = true
w = 512
h = 424

ni2.initialize()
device = ni2.DevicePtr()
ni2.open(device)
ni2.setDepthColorSyncEnabled(device, false)

di = ni2.getDeviceInfo(device)
@show ni2.getName(di)
@show ni2.getVendor(di)

depth = ni2.VideoStreamPtr()
ni2.create(depth, device, ni2.SENSOR_DEPTH)

foreach(ni2.start, [depth])

frame = ni2.VideoFrameRef()

### NiTE ###
nite.initialize();
tracker = nite.UserTracker()
nite.create(tracker, device)
nite.setSkeletonSmoothingFactor(tracker, 0.8)

user_frame = nite.UserTrackerFrameRef()

while true
    readyIndex = ni2.waitForAnyStream([depth])
    @assert readyIndex == 0

    ni2.readFrame(depth, frame)
    arr = convert(Array{ni2.DepthPixel,2}, frame)
    scaledarr = arr * 1/maximum(arr)

    nite.readFrame(tracker, user_frame)
    users = nite.getUsers(user_frame)

    # track users
    for user in users
        id = nite.getId(user)
        if nite.isNew(user)
            nite.startSkeletonTracking(tracker,id)
        elseif nite.isLost(user)
            nite.stopSkeletonTracking(tracker,id)
        end
    end

    # For convenience
    m = cv2.Mat(scaledarr)

    for user in users
        nite.isLost(user) && continue
        id = nite.getId(user)
        s = nite.getSkeleton(user)
        for typ in [
            nite.JOINT_HEAD,
            nite.JOINT_NECK,
            nite.JOINT_LEFT_ELBOW,
            nite.JOINT_RIGHT_ELBOW,
            nite.JOINT_LEFT_HAND,
            nite.JOINT_RIGHT_HAND,
            nite.JOINT_TORSO,
            nite.JOINT_LEFT_HIP,
            nite.JOINT_RIGHT_HIP,
            nite.JOINT_LEFT_KNEE,
            nite.JOINT_RIGHT_KNEE,
            ]
            j = nite.getJoint(s, typ)
            nite.getPositionConfidence(j) < 0.3 && continue
            p = nite.getPosition(j)
            x,y,z = icxx"$p.x;",icxx"$p.y;",icxx"$p.z;"
            outX,outY = nite.convertJointCoordinatesToDepth(tracker,x,y,z)
            icxx"cv::circle($(m.handle), cv::Point($outX,$outY), 7, cv::Scalar(255,255,0));"
        end
    end
    show_depth && cv2.imshow("depth", m)

    key = cv2.waitKey(delay=1)
    isesc(key) && break

    if key == 's' || always_save
        scale!(scaledarr, 255.)
        ext = readyIndex == 0 ? "_depth.png" : "_ir.png"
        fname = genfilename(ext)
        @show fname
        cv2.imwrite(fname, cv2.Mat(scaledarr))
    end

    rand() > 0.97 && gc(false)
end

cv2.destroyAllWindows()

nite.release(user_frame)
nite.destroy(tracker)

foreach(ni2.stop, [depth])
foreach(ni2.destroy, [depth])

ni2.close(device)

nite.shutdown()
ni2.shutdown()

gc()
