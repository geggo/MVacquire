from cwrap.config import Config, File

if __name__ == '__main__':
    config = Config('gccxml', 
                    files = [File('mvDeviceManager/Include/mvDeviceManager.h')],
                    include_dirs = ['.',])
    config.generate()

    config = Config('gccxml', 
                    files = [File('DriverBase/Include/mvDriverBaseEnums.h')],
                    include_dirs = ['.',])
    config.generate()

    config = Config('gccxml', 
                    files = [File('mvPropHandling/Include/mvPropHandlingDatatypes.h')],
                    include_dirs = ['.',])
    config.generate()
    
   
