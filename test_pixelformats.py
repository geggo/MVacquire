import mv
import numpy as  np
import pylab as plt

cam = mv.dmg.VD000001
cam_settings = cam.Setting.Base.Camera

cam_settings.TestMode = 'HorizontalMonoRamp'
cam.Setting.Base.ImageDestination.PixelFormat = 'Mono8'#, #'RGB888Packed'

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


nr = cam.image_request()
result = cam.get_image(timeout = 1.0)

print "result:"
print result.result, result.state, result.info

buf = result.get_buffer()
print "buffer:", buf.shape
img = np.asarray(buf)


plt.imshow(np.squeeze(img))
plt.show()
