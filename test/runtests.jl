using OpenNI2
using Cxx
using Base.Test

const ni2 = OpenNI2

@testset "basics" begin
    ni2.initialize()
    device = ni2.OpenNIDevice()
    @test ni2.open(device) == ni2.STATUS_OK
    @test ni2.isValid(device)

    depth = ni2.VideoStream()
    @test ni2.create(depth, device, ni2.SENSOR_DEPTH) == ni2.STATUS_OK
    @test ni2.isValid(device)

    mode = ni2.getVideoMode(depth)
    w, h = ni2.getResolutionX(mode), ni2.getResolutionY(mode)

    @test ni2.start(depth) == ni2.STATUS_OK
    frame = ni2.VideoFrameRef()
    @test !ni2.isValid(frame)
    ni2.waitForAnyStream([depth])
    ni2.readFrame(depth, frame)
    @test ni2.isValid(frame)
    arr = convert(Array{Cushort,2}, frame)
    @test size(arr) == (w, h)
    ni2.stop(depth)

    ni2.close(device)
    ni2.shutdown()

    @test !ni2.isValid(device)
end

@testset "setVideoMode" begin
    ni2.initialize()
    device = ni2.OpenNIDevice()
    @test ni2.open(device) == ni2.STATUS_OK
    depth = ni2.VideoStream()
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
    ni2.waitForAnyStream([depth])
    ni2.readFrame(depth, frame)
    arr = convert(Array{Cushort,2}, frame)
    @test size(arr) == (w, h)
    ni2.stop(depth)

    ni2.close(device)
    ni2.shutdown()
end
