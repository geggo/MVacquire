import mv

l = mv.List(0)
for s in l.Devices.BF004672:#info without opening device
    print "%-25s: %s"%(s.name, s)

dev = mv.dmg.get_device('BF004672')
dev2 = mv.dmg.BF004672
assert dev is dev2

settings = dev.Setting
cam_settings = settings.get_object_by_name('Camera')
for s in cam_settings:
    print "%-25s: %s"%(s.name, s)
    
s = cam_settings['FlashMode']
print s.get_dict()
print s

    
