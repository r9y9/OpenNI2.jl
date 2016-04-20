using Cxx
using OpenNI2
using CVCore
using CVHighGUI

const ni2 = OpenNI2

isesc(key) = key == 27
genfilename(ext=".png") =
    joinpath(dirname(@__FILE__), string(now(), "_", time_ns(), ext))

# Turn this on if you prefer to use Kinect v2
# assumed that libfreenect2-openni2 driver is installed
use_libfreenect2_openni2_driver = false

always_save = false
show_ir = true
show_depth = true

if use_libfreenect2_openni2_driver
    w, h = 512, 424
else
    w, h = 640>>1, 480>>1
end

function setVideoMode(stream, si, w, h, pxfmt)
    modes = ni2.getSupportedVideoModes(si)
    found = false
    for mode in modes
        if Int(ni2.getResolutionX(mode)) == w &&
                Int(ni2.getResolutionY(mode)) == h &&
                ni2.getPixelFormat(mode) == pxfmt
            println("$w x $h : video mode found")
            ni2.setVideoMode(stream, mode)
            found = true
            break
        end
    end
    !found && error("video mode not found")
end

ni2.initialize()
device = ni2.DevicePtr()
ni2.open(device)
ni2.setDepthColorSyncEnabled(device, false)

di = ni2.getDeviceInfo(device)
@show ni2.getName(di)
@show ni2.getVendor(di)

depth = ni2.VideoStreamPtr()
ni2.create(depth, device, ni2.SENSOR_DEPTH)
!use_libfreenect2_openni2_driver && ni2.setMirroringEnabled(depth, true)
setVideoMode(depth, ni2.getSensorInfo(device, ni2.SENSOR_DEPTH), w, h,
    ni2.PIXEL_FORMAT_DEPTH_1_MM)

ir = ni2.VideoStreamPtr()
ni2.create(ir, device, ni2.SENSOR_IR)
!use_libfreenect2_openni2_driver && ni2.setMirroringEnabled(ir, true)
setVideoMode(ir, ni2.getSensorInfo(device, ni2.SENSOR_IR), w, h,
    ni2.PIXEL_FORMAT_GRAY16)

ni2.setImageRegistrationMode(device, ni2.IMAGE_REGISTRATION_OFF)

foreach(ni2.start, [depth, ir])

frame = ni2.VideoFrameRef()

while true
    readyIndex = ni2.waitForAnyStream([depth, ir])
    if readyIndex == 0
        ni2.readFrame(depth, frame)
        arr = convert(Array{ni2.DepthPixel,2}, frame)
        scaledarr = arr * 1/maximum(arr)
        show_depth && imshow("depth", scaledarr)
    elseif readyIndex == 1
        ni2.readFrame(ir, frame)
        arr = convert(Array{ni2.Grayscale16Pixel,2}, frame)
        scaledarr = arr * 1/maximum(arr)
        show_ir && imshow("ir", scaledarr)
    end

    key = waitKey(delay=1)
    isesc(key) && break

    if key == 's' || always_save
        scale!(scaledarr, 255.)
        ext = readyIndex == 0 ? "_depth.png" : "_ir.png"
        fname = genfilename(ext)
        @show fname
        imwrite(fname, Mat(scaledarr))
    end

    rand() > 0.95 && gc(false)
end

destroyAllWindows()

foreach(ni2.stop, [depth, ir])
foreach(ni2.destroy, [depth, ir])
ni2.close(device)
ni2.shutdown()

# Force deallocate
depth=0;ir=0;device=0;gc()
