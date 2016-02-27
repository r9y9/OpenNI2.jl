using Cxx
using OpenNI2
using OpenCV

const ni2 = OpenNI2

isesc(key) = key == 27
genfilename(ext=".png") =
    joinpath(dirname(@__FILE__), string(now(), "_", time_ns(), ext))

always_save = false
const w = 640
const h = 480
const pxfmt = ni2.PIXEL_FORMAT_DEPTH_1_MM

ni2.initialize()
device = ni2.DevicePtr()
ni2.open(device)
ni2.setDepthColorSyncEnabled(device, false)

di = ni2.getDeviceInfo(device)
@show di
@show ni2.getName(di)

depth = ni2.VideoStreamPtr()
ni2.create(depth, device, ni2.SENSOR_DEPTH)
ni2.setMirroringEnabled(depth, true)

modes = ni2.getSupportedVideoModes(ni2.getSensorInfo(device, ni2.SENSOR_DEPTH))
for mode in modes
    if Int(ni2.getResolutionX(mode)) == w &&
            Int(ni2.getResolutionY(mode)) == h &&
            ni2.getPixelFormat(mode) == pxfmt
        println("$w x $h, PIXEL_FORMAT_DEPTH_1_MM: video mode found")
        ni2.setVideoMode(depth, mode)
        break
    end
end

ni2.start(depth)

frame = ni2.VideoFrameRef()

while true
    ni2.waitForAnyStream([depth])
    ni2.readFrame(depth, frame)
    arr = convert(Array{Cushort,2}, frame)
    @assert size(arr) == (w, h)

    # [0,1]
    scaledarr = scale(arr, 1/maximum(arr))
    cv2.imshow("depth", scaledarr)

    key = cv2.waitKey(delay=1)
    isesc(key) && break

    if key == 's' || always_save
        scale!(scaledarr, 255.)
        fname = genfilename()
        @show fname
        cv2.imwrite(fname, cv2.Mat(scaledarr))
    end

    rand() > 0.9 && gc(false)
end

ni2.stop(depth)
ni2.close(device)
ni2.shutdown()

cv2.destroyAllWindows()
