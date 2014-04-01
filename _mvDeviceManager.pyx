# -*- coding: latin-1 -*-
from _mvDeviceManager cimport *
from libc.stdlib cimport malloc, free
from cpython.ref cimport Py_INCREF, Py_DECREF
from cython.view cimport array as cvarray
import weakref
from libc.string cimport memcpy

cpdef int visibility_level = cvGuru #TODO: allow changing this variable

class MVError(RuntimeError):
    def __init__(self, msg = ''):
        RuntimeError.__init__(self, msg)

class MVTimeoutError(MVError):
    def __init__(self, msg = ''):
        MVError.__init__(self, 'Timeout in image acquisition')

cdef bint dmr_errcheck(TDMR_ERROR result) except True:
    cdef bint is_error = (result != DMR_NO_ERROR)
    if is_error:
        if result == DEV_WAIT_FOR_REQUEST_FAILED:
            raise MVTimeoutError
        else:
            raise MVError, DMR_ErrorCodeToString(result)
    return is_error

cdef bint obj_errcheck(TPROPHANDLING_ERROR result) except True:
    cdef bint is_error = (result != PROPHANDLING_NO_ERROR)
    if is_error:
        raise MVError, DMR_ErrorCodeToString(result)
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

    property device_count:
        def __get__(self):
            return self.get_device_count()
    
    def __len__(self):
        return self.get_device_count()

    def get_device_list(self):
        device_list = []
        cdef TDMR_DeviceInfo device_info
        cdef int i
        cdef size_t ssize = 0
        cdef HDEV hdev
        for i in range(self.device_count):
            dmr_errcheck(DMR_GetDevice(&hdev, dmdsmSerial, '*', i, '*'))
            dmr_errcheck(DMR_GetDeviceInfoEx(hdev, dmditDeviceInfoStructure, &device_info, &ssize))
            device_list.append(device_info)
        return device_list

    def update_device_list(self):
        """
        update device list

        Call this method to update the list of available devices, if
        devices have been connected after creating the DeviceManager
        instance.

        """
        dmr_errcheck(DMR_UpdateDeviceList(0, 0))

    cdef object get_device_by_serial(self, bytes name, int nr = 0):
        cdef HDEV hdev
        dmr_errcheck(DMR_GetDevice(&hdev, dmdsmSerial, name, nr, '*'))
        return Device(hdev)

    def get_device(self, bytes serial, int nr = 0):
        """
        get device by serial name
        
        Parameters
        ----------

        serial : bytes
            device serial name

        Returns
        -------
        dev : Device
            
        note: list of opened devices is cached

        """
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
    """image acquisition device
    """

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

    #def create_request_control(self, bytes name, bytes parent = <bytes>'Base'):
    def create_request_control(self, bytes name, parent = 'Base'):
        """
        create a new request control object.
        
        Parameters
        ----------
        name : bytes
            name of new request control
        parent : bytes, optional
            name of request control this one is derived from (default 'Base')

        Returns
        -------
        rc : List
            new request control (mv.List)
        """
        cdef HLIST obj = 0
        dmr_errcheck(DMR_CreateRequestControl(self.drv, name, parent, &obj, NULL))
        return create_component(obj)
    
    def delete_request_control(self, bytes name):
        """
        delete a request control object

        Parameters
        ----------
        name : bytes
            name of request control to be deleted
        """
        dmr_errcheck(DMR_DeleteList(self.drv, name, dmltRequestCtrl))

    def image_request(self, int rc = 0):
        """put an image request into image acquisition queue.
        
        Parameters
        ----------
        rc : int
           number of the request control to use for this request

        Returns
        -------
        nr : int
           number of request control object used
        """
        cdef int nr
        dmr_errcheck(DMR_ImageRequestSingle(self.drv, rc, &nr))
        return nr

    def get_image(self, double timeout = 1.0):
        """wait until image request result is available or timeout has elapsed

        Note that to be sucessfull it is necessary to previously place
        an imaqe request object into the request queue with `image_request`.

        Parameters
        ----------
        timeout : maximum time in seconds to wait for image acquisition
           
        Returns
        -------
        result : ImageResult
        
        Raises
        ------
        MVTimeoutError
            If the timeout elapsed
        """
        cdef int nr
        cdef TDMR_ERROR err
        with nogil:
            err = DMR_ImageRequestWaitFor(self.drv, int(timeout*1000), 0, &nr)
        dmr_errcheck(err) #note: special exception for timeout (queue empty)
        res = ImageResult(self.drv, nr)
        assert res.result == rrOK, "image request #%d, result=%d is not rrOK"%(nr, res.result)
        assert res.state == rsReady, "image request#%d state=%d is not rsReady"%(nr, res.state)
        return res
        
    def image_request_reset(self, int rc=0):
        dmr_errcheck(DMR_ImageRequestReset(self.drv, rc, 0))

    def snapshot(self):
        self.image_request()
        try:
            result = self.get_image()
        except Exception as e:
            print "error getting image (ignored):", e
        else:
            img = result.get_buffer()
            del result
            return img

cdef class ImageResult:
    """Image acquisition result.
    """
    cdef HDRV drv
    cdef int _nr
    cdef object __weakref__
    
    def __cinit__(self, HDRV drv, int nr):
        self.drv = drv
        self._nr = nr
        
    def __dealloc__(self):
        self.unlock()

    cdef unlock(self):
        dmr_errcheck(DMR_ImageRequestUnlock(self.drv, self._nr))
        
    cdef RequestResult get_result(self):
        cdef RequestResult result
        dmr_errcheck(DMR_GetImageRequestResultEx(self.drv, self._nr, &result, sizeof(result), 0, 0))
        return result

    cdef RequestInfo get_info(self):
        cdef RequestInfo info
        dmr_errcheck(DMR_GetImageRequestInfoEx(self.drv, self._nr, &info, sizeof(info), 0, 0))
        return info

    property nr:
        def __get__(self):
            return self._nr
    
    property info:
        def __get__(self):
            """image request number"""
            cdef RequestInfo info = self.get_info()
            return info

    property result:
        def __get__(self):
            cdef RequestResult result = self.get_result()
            return result.result

    property state:
        def __get__(self):
            cdef RequestResult result = self.get_result()
            return result.state
            
        #result.result: rrOK, rrTimeout
        #result.state: must be 'rsReady'
        

    def get_buffer(self):
        """Return image data as memory view
        
        The image data is copied and a memoryview to the image data is
        returned.  Use e.g. numpy.asarray(buf) to create a numpy array
        from the returned memoryview. The shape and dtype of the array
        depends on the pixel format. For monochromatic formats an
        array of shape (height, width) of dtype np.uint8 or np.uint16
        is returned, for packed color images an array also with shape
        (height, width) and a custom dtype consisting of 3 or 4
        np.uint8 or np.uint16. Planar color images have shape (3,
        height, width).

        Returns
        -------
        buf : memoryview
            image data
        """

        #TODO: check if image request is valid (not unlocked)
        
        cdef ImageBuffer* buf = NULL
        dmr_errcheck(DMR_GetImageRequestBuffer(self.drv, self._nr, &buf))
        
        cdef int w = buf.iWidth
        cdef int h = buf.iHeight
        cdef int bytesperpixel = buf.iBytesPerPixel #all components
        cdef int c = buf.iChannelCount
        cdef cvarray img

        #print "buffer %d x %d (%d channels), %d bytes"%(w, h, c, bytesperpixel)
            
        cdef int itemsize = 1
        cdef format = 'B'

        #ibpfRGBx888Planar,
        format_dict = {
            ibpfMono8: 'B',
            ibpfMono10: 'H',
            ibpfMono12: 'H',
            ibpfMono14: 'H',
            ibpfMono16: 'H', 
            ibpfMono32: 'I',
            ibpfRGB888Packed: 'BBB',
            ibpfRGB101010Packed: 'HHH',
            ibpfRGB121212Packed: 'HHH',
            ibpfRGB141414Packed: 'HHH',
            ibpfRGB161616Packed: 'HHH',
            ibpfRGBx888Packed: 'BBBB',
            ibpfBGR888Packed: 'BBB',
            ibpfYUV444Packed: 'BBB',
            }
        format = format_dict.get(buf.pixelFormat, 
                                 None) #'B'*bytesperpixel)
        img = None
        if format is not None:
            itemsize = bytesperpixel
            shp = (h,w)
            
            img = cvarray( shape = shp,
                       itemsize = bytesperpixel,
                       format = format, #H for uint16, 
                       mode = 'c', 
                       allocate_buffer=True)
            memcpy(img.data, buf.vpData, w*h*bytesperpixel)

        elif buf.pixelFormat in (ibpfRGBx888Planar,
                                 ibpfYUV444Planar):
            img = cvarray( shape = (bytesperpixel, h, w),
                       itemsize = 1,
                       format = 'B',
                       mode = 'c', 
                       allocate_buffer=True)
            memcpy(img.data, buf.vpData, w*h*bytesperpixel) #TODO: without copy?
        else:
            img = None
        
        dmr_errcheck(DMR_ReleaseImageRequestBufferDesc(&buf))
        if img is None:
            raise MVError, 'image pixel format not supported'
        return img.memview
    
    
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
    """Entry in property tree, base class for List, Property, and Method objects"""
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

    """List of Components"""

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
        except Exception, e: #FIXME
            raise AttributeError, e

    def __setattr__(self, bytes name, value):
        self[name].value = value
        
        

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

    def __call__(self, *args, delim = '|'):
        cdef int result
        signature = self.signature
        assert len(delim) == 1
        assert len(args) == len(signature)-1
        params = delim.join((str(a) for a in args))
        obj_errcheck(OBJ_Execute(self.obj, params, delim, &result))
        if signature[0] == 'i':
            return result
        else:
            return None
        
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
        return repr(self.value)

    def __str__(self):
        if self.maxlen == 1:
            return self.getS()
        else:
            return str([self.getS(i) for i in range(len(self))])
        
        #return 'x'*bufsize

    #    try:
    #        s = self.format%self.get(0)
    #    except ValueError,e:
    #        print "unknown format string: ", self.format
    #        print e
    #        s = repr(self.get(0))
    #    return s
        
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
            if self.maxlen == 1:
                return self.get(0)
            else:
                return [val for val in self]
        def __set__(self, value):
            if self.maxlen == 1:
                value = (value,) #FIXME: check if value is already length 1 array
            for i, val in enumerate(value):
                try:
                    self.set(val, i)
                except TypeError:
                    self.set(self.string_to_value(val), i)
                
    cdef object string_to_value(self, bytes s):
        raise MVError("conversion from string not implemented for %s"%type(self))

    def writeS(self, bytes value, int index=0):
        obj_errcheck(OBJ_SetS(self.obj, <char*>value, index))

    def getS(self, int index=0):
        cdef size_t bufsize
        obj_errcheck(OBJ_GetSFormattedEx(self.obj, NULL, &bufsize, NULL, index))
        cdef char* buf = <char*>malloc(bufsize)
        cdef TPROPHANDLING_ERROR err = OBJ_GetSFormattedEx(self.obj, buf, &bufsize, NULL, index)
        cdef bytes s = buf[:bufsize-1]
        free(buf)
        obj_errcheck(err)
        return s

    property max:
        def __get__(self):
            cdef unsigned int available = 0 
            obj_errcheck(OBJ_IsConstantDefined(self.obj, PROP_MAX_VAL, &available))
            if available:
                return self.get(PROP_MAX_VAL)

    property min:
        def __get__(self):
            cdef unsigned int available = 0 
            obj_errcheck(OBJ_IsConstantDefined(self.obj, PROP_MIN_VAL, &available))
            if available:
                return self.get(PROP_MIN_VAL)


    #def readS(self, int index=0):
    #    cdef size_t bufsize = 32
    #    cdef cvarray buf = cvarray(shape=(bufsize,), itemsize=sizeof(char))
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

    cdef object string_to_value(self, bytes s):
        #TODO: if flags ans cfAllowValueCombinations: split s into bytes, return ored
        return self.get_dict()[s]
        
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

    cdef object string_to_value(self, bytes s):
        return float(s)
    #FIXME: sscanf with format????
    
cdef class PropertyPtr(Property):
    cpdef long int get(self, int index = 0):
        cdef void* value
        obj_errcheck(OBJ_GetP(self.obj, &value, index))
        return <long int>value

    cpdef set(self, long long int value, int index = 0): #TODO: PyCapsule?
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
