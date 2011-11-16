import mv

l = mv.List(0)
for s in l.Devices.VD000001:#info without opening device
    print "%-25s: %s"%(s.name, s)

#dev = mv.dmg.get_device('BF004672')
#dev2 = mv.dmg.BF004672
#assert dev is dev2

dev = mv.dmg.get_device('VD000001')
settings = dev.Setting
cam_settings = settings.get_object_by_name('Camera')
for s in cam_settings:
    print "%-25s: %s"%(s.name, s)
    
#s = cam_settings['FlashMode']
#print s.get_dict()
#print s

p = cam_settings.PseudoFeatures

#get image
#create request control (optional)
rc, rc_idx  = dev.create_request_control('my request control')

#request image, get nr of used request object
nr_requested = dev.image_request(0) #rc_idx argument????

#wait for image, returns image request nr
nr = dev.image_request_wait(1000)

#get request result/state
requ_res, requ_state = dev.image_request_result(nr)

#test for validity
#if requ_res:

#get buffer
w, h = dev.image_request_buffer(nr)
print "got image %dx%d"%(w, h)
    
#cleanup
dev.image_request_unlock(nr)
