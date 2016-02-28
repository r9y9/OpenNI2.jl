using OpenNI2
using Cxx
using Base.Test

const ni2 = OpenNI2

@testset "Version" begin
    ver = ni2.getVersionNumber()
    @test ver >= v"2.2.0-"
end

@testset "Basics" begin
    ni2.initialize()
    device = ni2.DevicePtr()
    @test ni2.open(device) == ni2.STATUS_OK
    @test ni2.isValid(device)
    @test ni2.hasSensor(device, ni2.SENSOR_DEPTH)

    depth = ni2.VideoStreamPtr()
    @test ni2.create(depth, device, ni2.SENSOR_DEPTH) == ni2.STATUS_OK
    @test ni2.isValid(device)

    rc = ni2.setImageRegistrationMode(device, ni2.IMAGE_REGISTRATION_OFF)
    @test rc == ni2.STATUS_OK

    mode = ni2.getVideoMode(depth)
    w, h = ni2.getResolutionX(mode), ni2.getResolutionY(mode)

    @test ni2.start(depth) == ni2.STATUS_OK
    frame = ni2.VideoFrameRef()
    @test !ni2.isValid(frame)
    @test ni2.waitForAnyStream([depth]) == 0
    ni2.readFrame(depth, frame)
    @test ni2.isValid(frame)
    arr = convert(Array{Cushort,2}, frame)
    @test size(arr) == (w, h)
    ni2.stop(depth)
    ni2.destroy(depth)

    ni2.close(device)
    ni2.shutdown()

    @test !ni2.isValid(device)
end

@testset "DeviceInfo" begin
    ni2.initialize()
    device = ni2.DevicePtr()
    @test ni2.open(device) == ni2.STATUS_OK
    @test ni2.isValid(device)

    di = ni2.getDeviceInfo(device)
    @test !isempty(ni2.getUri(di))
    @test !isempty(ni2.getVendor(di))
    @test !isempty(ni2.getName(di))
    @test ni2.getUsbVendorId(di) != 0x00
    @test ni2.getUsbProductId(di) != 0x00

    ni2.close(device)
    ni2.shutdown()
end

@testset "setVideoMode" begin
    ni2.initialize()
    device = ni2.DevicePtr()
    @test ni2.open(device) == ni2.STATUS_OK
    depth = ni2.VideoStreamPtr()
    @test ni2.create(depth, device, ni2.SENSOR_DEPTH) == ni2.STATUS_OK

    si = ni2.getSensorInfo(device, ni2.SENSOR_DEPTH)
    modes = ni2.getSupportedVideoModes(si)
    @test length(modes) > 0

    # target
    w = 640
    h = 480
    pxfmt = ni2.PIXEL_FORMAT_DEPTH_1_MM

    found = false
    for mode in modes
        if Int(ni2.getResolutionX(mode)) == w &&
                Int(ni2.getResolutionY(mode)) == h &&
                ni2.getPixelFormat(mode) == pxfmt
            found = true
            ni2.setVideoMode(depth, mode)
            break
        end
    end
    @test found

    @test ni2.start(depth) == ni2.STATUS_OK
    frame = ni2.VideoFrameRef()
    @test ni2.waitForAnyStream([depth]) == 0
    ni2.readFrame(depth, frame)
    arr = convert(Array{Cushort,2}, frame)
    @test size(arr) == (w, h)
    ni2.stop(depth)
    ni2.destroy(depth)

    ni2.close(device)
    ni2.shutdown()
end
