# -*- coding: latin-1 -*-
from _mvDeviceManager cimport *
from libc.stdlib cimport malloc, free
#from cpython.string cimport PyString_FromStringAndSize
from cpython.ref cimport Py_INCREF, Py_DECREF
import cython
#cimport cython
import weakref

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
    cdef HDMR _hdmr #handle device manager
    cdef object devices

    def __cinit__(self):
        DMR_Init(&self._hdmr)
        self.devices = weakref.WeakValueDictionary()

    def __dealloc__(self):
        DMR_Close()

    property device_count:
        def __get__(self):
            cdef unsigned int count
            DMR_GetDeviceCount(&count)
            return count
    
    def get_device_list(self):
        device_list = []
        cdef TDMR_DeviceInfo device_info
        for i in range(self.device_count):
            dmr_errcheck(DMR_GetDeviceInfo(i, &device_info, sizeof(device_info)))
            
            device_list.append( dict(id = device_info.deviceId,
                                     family = device_info.family,
                                     product = device_info.product,
                                     serial = device_info.serial) )
        return device_list            

    cdef object get_device_by_serial(self, bytes name, int nr = 0):
        cdef HDEV hdev
        dmr_errcheck(DMR_GetDevice(&hdev, dmdsmSerial, name, nr, '*'))
        return Device(hdev)

    def get_device(self, bytes serial, int nr = 0):
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


cdef class Device:
    cdef object __weakref__
    cdef HDEV dev
    cdef HDRV drv
    #cdef bint owner #owns device, need to close
    
    def __cinit__(self, HDEV dev):
        self.dev = dev
        dmr_errcheck(DMR_OpenDevice(self.dev, &self.drv))
        # err = DMR_GetDriverHandle(self.dev, &self.drv)# != DMR_NO_ERROR:
        # if  err != DMR_NO_ERROR:
        #     print "open", DMR_ErrorCodeToString(err) #DMR_NOT_INITIALIZED ????
        #     dmr_errcheck(DMR_OpenDevice(self.dev, &self.drv))
        #     self.owner = True
        # else:
        #     self.owner = False
            
    def __dealloc__(self):
        #if self.owner:
        DMR_CloseDevice(self.drv, self.dev)

    def get_list(self, bytes name, flags = 0):
        cdef HLIST hlist
        list_type = lists[name]
        dmr_errcheck(DMR_FindList(self.drv,
                                  NULL,
                                  list_type,
                                  flags,
                                  &hlist))
        return List(hlist) #could also be: OBJ

    def __dir__(self):
        return lists.keys()
    
    def __getattr__(self, bytes name):
        return self.get_list(name)
                              
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
                              

#check Handle

#get type

##get val count
#set val count
#remove val (property)
#get max val count

#get flags

#get/set X
#get/set X array

#get dict size
#get X dict entries
#set X dict entries

#create callback
#deleta callback
#attach callback
#detach callback

#execute
#get S param list

#get changed counter
#get changed counter attr

#get first child
#get next sibling
#get first sibling
#get last sibling
#get parent

#is constant defined (property)
##is default
##restore default

#(string)
#get/set binary

cdef char* StringConstructionFunction(char* buf, size_t size):
    #print "String Constructor:", buf, size
    cdef object res = buf[:size-1]
    Py_INCREF(res) #make res survive
    return <char*><void*> res

cdef class Component:
    cdef HOBJ obj
    #cdef object value_dict

    def __cinit__(self, HOBJ obj):
        self.obj = obj

    property is_valid:
        def __get__(self):
            result = OBJ_CheckHandle(self.obj, hcmFull)
            return (result == PROPHANDLING_NO_ERROR)

    def get_string(self, TOBJ_StringQuery sq, int index = 0):
        cdef char* res
        obj_errcheck(OBJ_GetSWithInplaceConstruction(
            self.obj,
            sq,
            &res,
            StringConstructionFunction,
            0, index))
        cdef object result = <object><void*>res
        Py_DECREF(result)
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

    #def __str__(self):
    #    return "Component '%s'"%self.name

    #def __repr__(self):
    #    return "%s '%s'"%(type(self), self.name)

cdef class ListIter:
    cdef HOBJ obj
    def __cinit__(self, HOBJ obj):
        self.obj = obj

    def __next__(self):
        obj_errcheck(OBJ_GetNextSibling(self.obj, &self.obj))
        try:
            return create_component(self.obj)
        except Exception, e:
            #print "error __next__", e, self.obj
            raise StopIteration

cdef class List(Component):

    def __getitem__(self, bytes key):
        cdef HOBJ obj = 0
        result = OBJ_GetHandleEx(self.obj, key, &obj, 0, 1) #only search in this list
        if result == PROPHANDLING_NO_ERROR:
            return create_component(obj)
        else:
            raise IndexError
        
    def __dir__(self):
        return [c.name for c in self if c.isvisible]

    def __getattr__(self, bytes name):
        #if name in self.children:
        #    return self[name]
        #else:
        #    raise AttributeError
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

    # def __iter__(self):
    #     cdef HOBJ obj
    #     obj_errcheck(OBJ_GetFirstChild(self.obj, &obj))
    #     return ListIter(obj)

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
    cdef unsigned int __len(self):
        cdef unsigned int count
        obj_errcheck(OBJ_GetValCount(self.obj, &count))
        return count
    
    def __len__(self):
        return self.__len()

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
        obj_errcheck(OBJ_GetSFormattedEx(self.obj, buf, &bufsize, NULL, 0))
        #TODO: check size, index, use GetSArrayFormattedEx for array
        return buf

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

    property value:
        def __get__(self):
            return self.get()
        def __set__(self, int value):
            self.set(value)

    def __getitem__(self, int index):
        if index < 0 or index >= len(self):
            raise IndexError
        return self.get(index)

    def __setitem__(self, int index, int value):
        if index<0 or index >= len(self):
            raise IndexError
        self.set(value, index)
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
            
        result = OBJ_GetIDictEntries(self.obj,
                                     buf,
                                     bufsize,
                                     tvals,
                                     size)
        #TODO: see doc: resize buffer if too small
        d = dict()
        if result == PROPHANDLING_NO_ERROR:
            for i in range(size):
                d[buf[i]] = tvals[i]

        for i in range(size):
            free(buf[i])
        free(buf)
        free(tvals)
        
        return d
        

cdef class PropertyInt64(Property):
    pass

cdef class PropertyFloat(Property):
    pass

cdef class PropertyPtr(Property):
    pass

cdef class PropertyString(Property):
    
    cpdef bytes get(self, int index = 0):
        return self.get_string(sqPropVal, index)
    
component_class = {ctList: List,
                   ctMeth: Method,
                   ctPropInt: PropertyInt,
                   ctPropInt64: PropertyInt64,
                   ctPropFloat: PropertyFloat,
                   ctPropString: PropertyString,
                   ctPropPtr: PropertyPtr,
                   }

cdef create_component(HOBJ obj):
    cdef TComponentType component_type
    obj_errcheck(OBJ_GetType(obj, &component_type))
    cclass = component_class[component_type]
    component = cclass(obj)
    return component


dmg = DeviceManager()
dev = dmg.get_device('BF004672')
lst = dev.get_list('Setting')
cam = lst.get_object_by_name('Camera')
for o in cam:
    print "%-25s: %s"%(o.name, o)
#print cam.children

s = cam.get_object_by_name('FlashMode')
print s.get_dict()

