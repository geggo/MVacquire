from __future__ import print_function
import mv
import numpy as  np
#import pylab as plt

cam = mv.dmg.VD000001
cam_settings = cam.Setting.Base.Camera

cam_settings.TestMode = 'HorizontalMonoRamp'
cam_settings.TestImageBarWidth = 1
cam_settings.ChannelBitDepth = 16


#'Mono8': ok
#'RGB888Packed'

# 'Auto'
# 'BGR101010Packed_V2'
# 'BGR888Packed'
# 'Mono10'
# 'Mono12'
# 'Mono12Packed_V2'
# 'Mono14'
# 'Mono16'
# 'Mono8' #
# 'RGB101010Packed'
# 'RGB121212Packed'
# 'RGB141414Packed'
# 'RGB161616Packed'
# 'RGB888Packed'
# 'RGBx888Packed'
# 'RGBx888Planar'
# 'Raw': 1,
# 'YUV422Packed'
# 'YUV422Planar'
# 'YUV422_10Packed'
# 'YUV422_UYVYPacked'
# 'YUV422_UYVY_10Packed'
# 'YUV444Packed'
# 'YUV444_10Packed'
# 'YUV444_UYVPacked'
# 'YUV444_UYV_10Packed'

pixel_formats = ('Mono8', 'Mono10', 'Mono12', 'Mono16',
                 'RGB888Packed', 'RGB101010Packed', 'RGB121212Packed', 'RGB141414Packed', 'RGB161616Packed',
                 'RGBx888Packed',
                 'BGR888Packed',
                 'RGBx888Planar')

for pixfmt in pixel_formats:
    cam.Setting.Base.ImageDestination.PixelFormat = pixfmt

    nr = cam.image_request()
    result = cam.get_image(timeout = 1.0)
    #print "result:"
    #print result.result, result.state, result.info
    print(pixfmt)
    try:
        buf = result.get_buffer()
        print("buffer:", buf.shape)
        img = np.asarray(buf)
        print(img.shape, img.dtype)
        print(img[...,0, :6])
    except mv.MVError as e:
        print("Error getting buffer:", e)
    print()

#
#plt.imshow(np.squeeze(img))
#plt.show()
