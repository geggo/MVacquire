# -*- coding: latin-1 -*-
from _mvDeviceManager cimport *
from libc.stdlib cimport malloc, free
from cpython.ref cimport Py_INCREF, Py_DECREF
import cython
import weakref
from libc.string cimport memcpy

cdef int visibility_level = cvExpert

cdef bint dmr_errcheck(TDMR_ERROR result) except True:
    cdef bint is_error = (result != DMR_NO_ERROR)
    if is_error:
        raise Exception, DMR_ErrorCodeToString(result)
    return is_error

cdef bint obj_errcheck(TPROPHANDLING_ERROR result) except True:
    cdef bint is_error = (result != PROPHANDLING_NO_ERROR)
    if is_error:
        raise Exception, DMR_ErrorCodeToString(result)
    return is_error


cdef class DeviceManager:
    cdef HDMR _hdmr
    cdef object devices

    def __cinit__(self):
        dmr_errcheck(DMR_Init(&self._hdmr))
        self.devices = weakref.WeakValueDictionary()

    def __dealloc__(self):
        dmr_errcheck(DMR_Close())

    cdef int get_device_count(self):
        cdef unsigned int count
        dmr_errcheck(DMR_GetDeviceCount(&count))
        return <int>count

    property device_count: #TODO: __len__
        def __get__(self):
            return self.get_device_count()
    
    def get_device_list(self):
        device_list = []
        cdef TDMR_DeviceInfo device_info
        cdef int i
        for i in range(self.device_count):
            dmr_errcheck(DMR_GetDeviceInfo(i, &device_info, sizeof(device_info)))
            
            #device_list.append( dict(deviceId = device_info.deviceId,
            #                         family = device_info.family,
            #                         product = device_info.product,
            #                         serial = device_info.serial) )
            device_list.append(device_info)
        return device_list            

    cdef object get_device_by_serial(self, bytes name, int nr = 0):
        cdef HDEV hdev
        dmr_errcheck(DMR_GetDevice(&hdev, dmdsmSerial, name, nr, '*'))
        return Device(hdev)

    def get_device(self, bytes serial, int nr = 0):
        
        #FIXME: create unique handle
        device = self.devices.get(serial)
        if device is None:
            device = self.get_device_by_serial(serial)
            self.devices[serial] = device
        return device
        
    def __dir__(self):
        return [dev['serial'] for dev in self.get_device_list()]

    def __getattr__(self, bytes serial):
        return self.get_device(serial)
        #better: keep dict with weakref

#need to implement:
#-----------------
#class image request control -> List component
#DMR_CreateRequestControl or properties/request_control/Base/
#.mode e.g. ircmTrial -> dummy image created
#.setting (e.g. Base -> DMR_CreateSetting ?)

#device.isOpen -> is valid handle drv   (->getdriverhandle(dev, &drv))
##device.ensureRequests(num) deprecated -> property RequestCount
#device.imageRequestSingle()  -> DMR_ImageRequestSingle ? image request control -> see above
#device.imageRequestWaitFor(timeout) nogil -> DMR_ImageRequestWaitFor -> nr!!

#class image request: (after request wait for)
#
#.info -> DMR_GetImageRequestInfoEx
#.buffer -> DMR_GetImageRequestBuffer -> creates Image buffer
#
#class ImageBuffer -> DMR_AllocImageRequestBufferDesc or DMR_AllocImageBuffer (for new buffer)
#and DMR_ReleaseImageRequestBufferDesc or DMR_ReleaseImageBuffer
#image request.imageRequestUnlock(num)

#device.imageRequestReset(0,0) -> DMR_ImageRequestReset: terminate pending image requests
#device.isRequestNrValid -> check for >=0 of answer of WaitFor

#request = fi.getRequest(num) -> 
#image request.isRequestOK(request) -> request.result == OK

#request.requestResult
#desc = request.getImageBufferDesc()
#buffer = desc.getBuffer()

#cdef void array_free_callback(char* data):
#    print "(not) freeing image data"

cdef class Device:
    cdef HDEV dev
    cdef HDRV drv
    cdef object __weakref__
    
    def __cinit__(self, HDEV dev):
        self.dev = dev
        dmr_errcheck(DMR_OpenDevice(self.dev, &self.drv))
        print "open device", hex(self.dev), hex(self.drv)
            
    def __dealloc__(self):
        print "close device", hex(self.dev), hex(self.drv)
        DMR_CloseDevice(self.drv, self.dev)

    cdef List get_list(self, bytes name, flags = 0):
        cdef HLIST hlist
        list_type = lists[name]
        dmr_errcheck(DMR_FindList(self.drv,
                                  NULL,
                                  list_type,
                                  flags,
                                  &hlist))
        return List(hlist)

    def __dir__(self):
        return lists.keys()
    
    def __getattr__(self, bytes name):
        return self.get_list(name)

    def create_request_control(self, bytes name, bytes parent = <bytes>'Base'):
        cdef HLIST obj = 0
        dmr_errcheck(DMR_CreateRequestControl(self.drv, name, parent, &obj, NULL))
        return create_component(obj)
    
    def delete_request_control(self, bytes name):
        dmr_errcheck(DMR_DeleteList(self.drv, name, dmltRequestCtrl))

    def image_request(self, int rc = 0):
        """image_request(int rc = 0)
        send an image request to the device driver.
        
        arguments:
        rc: number of the request control to use for this request
        """
        cdef int nr
        dmr_errcheck(DMR_ImageRequestSingle(self.drv, rc, &nr))
        return nr

    def image_request_wait(self, int timeout):
        cdef int nr
        cdef TDMR_ERROR err
        with nogil:
            err = DMR_ImageRequestWaitFor(self.drv, timeout, 0, &nr)
        dmr_errcheck(err) #TODO: check for timeout -> special exception
        return nr #TODO: create image_request object

    def image_request_buffer(self, int nr):
        """Return image data as buffer"""

        #TODO: check if image request is valid (not unlocked)
        cdef ImageBuffer* buf = NULL
        dmr_errcheck(DMR_GetImageRequestBuffer(self.drv, nr, &buf))
        
        cdef int w = buf.iWidth
        cdef int h = buf.iHeight
        cdef int bytesperpixel = buf.iBytesPerPixel
        cdef int c = buf.iChannelCount

        #cdef np.ndarray arr = np.empty( (w,h,c), dtype = np.uint8)
        #memcpy(arr.data, buf.vpData, numbytes)

        #cdef cython.array img = <unsigned char[:(w*h*c)]> <unsigned char*>buf.vpData
        cdef cython.array img
                
        if buf.pixelFormat in [ibpfMono8, 
                               #ibpfRGBx888Packed,
                               #ibpfRGBx888Planar,
                               ibpfRGB888Packed,
                               ]:
            
            img = cython.array( shape = (w,h,c), 
                                itemsize = bytesperpixel,
                                format = 'B', #H for uint16, 
                                mode = 'c', 
                                allocate_buffer=True) #allocate memory
            ##img.data = <char*> buf.vpData
            ##img.callback_free_data = array_free_callback
            ##img_copy = img.copy()
            memcpy(img.data, buf.vpData, w*h*c*bytesperpixel)
        else:
            img= None
        
        dmr_errcheck(DMR_ReleaseImageRequestBufferDesc(&buf))
        return w, h, img

    def image_request_result(self, int nr):
        cdef RequestResult result
        dmr_errcheck(DMR_GetImageRequestResultEx(self.drv, nr, &result, sizeof(result), 0, 0))
        #print self.Request[0].State, self.Request[0].Result #TODO
        return result.result, result.state

    def image_request_unlock(self, int nr):
        dmr_errcheck(DMR_ImageRequestUnlock(self.drv, nr))

    def image_request_reset(self, int rc=0):
        dmr_errcheck(DMR_ImageRequestReset(self.drv, rc, 0))


 
        

    
    
        
                                              
    
    
                              
cdef dict lists = {
    'Setting': dmltSetting,
    'Request': dmltRequest,
    'Request_control': dmltRequestCtrl,
    'Info': dmltInfo,
    'Statistics': dmltStatistics,
    'System_settings': dmltSystemSettings,
    'Io_sub_system':dmltIOSubSystem,
    'Real_time_control': dmltRTCtr,
    'Camera_descriptions': dmltCameraDescriptions,
    'Device_specific_data': dmltDeviceSpecificData,
    'Event_sub_system': dmltEventSubSystemSettings,
    'Event_sub_system_results': dmltEventSubSystemResults,
    'Image_memory_manager': dmltImageMemoryManager,
    }
       
                       

#get type

##get val count
#set val count
#remove val (property)
#get max val count

#get flags

#get/set X
#get/set X array

##get X dict entries
#set X dict entries

#create callback
#deleta callback
#attach callback
#detach callback

#execute
##get S param list

#?get next sibling?
#?get first sibling?
#?get last sibling?
##get parent

#is constant defined (property)

#(string)
#get/set binary

cdef char* StringConstructionFunction(char* buf, size_t size):
    #print "String Constructor:", buf, size
    cdef object res = buf[:size-1]
    Py_INCREF(res) #make res survive
    return <char*><void*> res

cdef class Component:
    cdef HOBJ obj

    def __cinit__(self, HOBJ obj):
        self.obj = obj

    property is_valid:
        def __get__(self):
            cdef int err = OBJ_CheckHandle(self.obj, hcmFull)
            return (err == PROPHANDLING_NO_ERROR)

    cdef bytes get_string(self, TOBJ_StringQuery sq, int index = 0):
        cdef char* res
        obj_errcheck(OBJ_GetSWithInplaceConstruction(
            self.obj,
            sq,
            &res,
            StringConstructionFunction,
            0, index))
        cdef object result = <object><void*>res
        Py_DECREF(result) #compensate for INCREF in StringConstructionFunction
        return result

    property name:
        def __get__(self):
            return self.get_string(sqObjName)

    property display_name:
        def __get__(self):
            return self.get_string(sqObjDisplayName)

    property doc_string:
        def __get__(self):
            return self.get_string(sqObjDocString)

    property isdefault:
        def __get__(self):
            cdef unsigned int isdefault
            obj_errcheck(OBJ_IsDefault(self.obj, &isdefault))
            return bool(isdefault)
                         
        def __set__(self, value):
            if value:
                obj_errcheck(OBJ_RestoreDefault(self.obj))

    property isvisible:
        def __get__(self):
            cdef TComponentVisibility visibility
            obj_errcheck(OBJ_GetVisibility(self.obj, &visibility))
            return <int>visibility <= visibility_level
    
    property counter_attribute_changed:
        def __get__(self):
            cdef unsigned int counter = 0
            obj_errcheck(OBJ_GetChangedCounterAttr(self.obj, &counter))
            return counter

    property counter_value_changed:
        def __get__(self):
            cdef unsigned int counter = 0
            obj_errcheck(OBJ_GetChangedCounterAttr(self.obj, &counter))
            return counter

    property parent:
        def __get__(self):
            cdef HOBJ parent
            obj_errcheck(OBJ_GetParent(self.obj, &parent))
            return create_component(parent)

#    def __get__(self, instance, owner):
#        print "on get", self, instance, owner

#    def __set__(self, instance, value):
#        print "on set", self, instance, value

    #def __str__(self):
    #    return "Component '%s'"%self.name

    #def __repr__(self):
    #    return "%s '%s'"%(type(self), self.name)

cdef class List(Component):

    def __getitem__(self, bytes key):
        cdef HOBJ obj = 0
        cdef int err = OBJ_GetHandleEx(self.obj, key, &obj, 0, 1) #only search in this list
        if err == PROPHANDLING_NO_ERROR:
            return create_component(obj)
        else:
            raise IndexError
        
    def __dir__(self):
        return [c.name for c in self if c.isvisible]

    def __getattr__(self, bytes name):
        try:
            return self[name]
        except Exception, e:
            raise AttributeError, e

    property children:
        def __get__(self):
            return [child.name for child in self]

    def get_object_by_name(self, path = ''):
        cdef HOBJ obj = 0
        obj_errcheck(OBJ_GetHandleEx(self.obj,
                                     path,
                                     &obj,
                                     0,
                                     -1))
        return create_component(obj)

    property content_description:
        def __get__(self):
            return self.get_string(sqListContentDescriptor)

    def __len__(self):
        cdef unsigned int count
        obj_errcheck(OBJ_GetElementCount(self.obj, &count))
        return count

    def __iter__(self):
        cdef HOBJ obj
        obj_errcheck(OBJ_GetFirstChild(self.obj, &obj))
        yield create_component(obj)
        while True:
            try:
                obj_errcheck(OBJ_GetNextSibling(obj, &obj))
                comp = create_component(obj)
            except Exception, e:
                return
            yield comp
    
cdef class Method(Component):
    property signature:
        def __get__(self):
            return self.get_string(sqMethParamString)

cdef class Property(Component):
    cdef unsigned int len(self):
        cdef unsigned int count
        obj_errcheck(OBJ_GetValCount(self.obj, &count))
        return count
    
    def __len__(self):
        return self.len()

    property maxlen:
        def __get__(self):
            cdef unsigned int count = 0
            obj_errcheck(OBJ_GetMaxValCount(self.obj, &count))
            return count    
    
    property format:
        def __get__(self):
            return self.get_string(sqPropFormatString)

    def __repr__(self):
        cdef char buf[8000] #FIXME
        cdef size_t bufsize = sizeof(buf)
        obj_errcheck(OBJ_GetSFormattedEx(self.obj, buf, &bufsize, NULL, 0)) #FIXME: get needed buffer size
        #TODO: check size, index, use GetSArrayFormattedEx for array
        return buf

    def __getitem__(self, int index):
        if index < 0 or index >= len(self):
            raise IndexError
        return self.get(index)

    def __setitem__(self, int index, value):
        if index<0 or index >= len(self):
            raise IndexError
        self.set(value, index)
    
    property value:
        def __get__(self):
            return self.get()
        def __set__(self, value):
            self.set(value)

    def writeS(self, bytes value, int index=0):
        obj_errcheck(OBJ_SetS(self.obj, <char*>value, index))

    #def readS(self, int index=0):
    #    cdef size_t bufsize = 32
    #    cdef cython.array buf = cython.array(shape=(bufsize,), itemsize=sizeof(char))
    #    #cdef char[:] cbuf = buf
    #    err = OBJ_GetSFormattedEx(self.obj, buf.data, &bufsize, NULL, 0)
    #    if err == PROPHANDLING_INPUT_BUFFER_TOO_SMALL:
    #        buf = cython.array(shape=(bufsize,), itemsize=sizeof(char))
    #        #cbuf = buf
    #        obj_errcheck(OBJ_GetSFormattedEx(self.obj, buf.data, &bufsize, NULL, 0))
    #    #return cbuf[:bufsize]
    

cdef class PropertyInt(Property):
    cpdef int get(self, int index = 0):
        cdef int value
        obj_errcheck(OBJ_GetI(self.obj, &value, index))
        return value

    cpdef set(self, int value, int index = 0):
        obj_errcheck(OBJ_SetI(self.obj, value, index))

    def get_dict(self):
        #TODO: do caching (with counter_attribute_changed checking for changes)
        cdef unsigned int size = 0
        obj_errcheck(OBJ_GetDictSize(self.obj, &size))
        
        cdef unsigned int i, bufsize = 128
        cdef int* tvals = <int*>malloc(size * sizeof(int))
        cdef char** buf = <char**>malloc(size * sizeof(char*))
        
        for i in range(size):
            buf[i] = <char*>malloc(bufsize * sizeof(char))
            
        cdef int err = OBJ_GetIDictEntries(self.obj,
                                     buf,
                                     bufsize,
                                     tvals,
                                     size)
        #TODO: see doc: resize buffer if too small
        d = dict()
        if err == PROPHANDLING_NO_ERROR:
            for i in range(size):
                d[buf[i]] = tvals[i]

        for i in range(size):
            free(buf[i])
        free(buf)
        free(tvals)
        
        return d

    #cpdef bytes get(self, int index = 0):
    #    return self.get_string(sqPropVal, index)
        

cdef class PropertyInt64(Property):
    cpdef int64_type get(self, int index = 0):
        cdef int64_type value
        obj_errcheck(OBJ_GetI64(self.obj, &value, index))
        return value

    cpdef set(self, int64_type value, int index = 0):
        obj_errcheck(OBJ_SetI64(self.obj, value, index))

cdef class PropertyFloat(Property):
    cpdef double get(self, int index = 0):
        cdef double value
        obj_errcheck(OBJ_GetF(self.obj, &value, index))
        return value

    cpdef set(self, double value, int index = 0):
        obj_errcheck(OBJ_SetF(self.obj, value, index))

cdef class PropertyPtr(Property):
    cpdef long int get(self, int index = 0):
        cdef void* value
        obj_errcheck(OBJ_GetP(self.obj, &value, index))
        return <long int>value

    cpdef set(self, long int value, int index = 0): #TODO: PyCapsule?
        obj_errcheck(OBJ_SetP(self.obj, <void *>value, index))

cdef class PropertyString(Property):
    cpdef bytes get(self, int index = 0):
        return self.get_string(sqPropVal, index)

    cpdef set(self, bytes value, int index = 0):
        self.writeS(value, index)

cdef component_class = {ctList: List,
                   ctMeth: Method,
                   ctPropInt: PropertyInt,
                   ctPropInt64: PropertyInt64,
                   ctPropFloat: PropertyFloat,
                   ctPropString: PropertyString,
                   ctPropPtr: PropertyPtr,
                   }

cdef create_component(HOBJ obj):
    obj_errcheck(OBJ_CheckHandle(obj, hcmFull)) #necessary?
    cdef TComponentType component_type
    obj_errcheck(OBJ_GetType(obj, &component_type))
    cclass = component_class[component_type]
    component = cclass(obj)
    return component


dmg = DeviceManager()
