from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext

#import numpy as np

ext_modules = [Extension("mv",
                        ["_mvDeviceManager.pyx"],
                        libraries = ["mvDeviceManager"],
                        include_dirs = ["matrix-vision",
                                        #np.get_include(),
                                        ],
                        library_dirs = ["matrix-vision/lib"],)]
for e in ext_modules:
    e.pyrex_directives = {"embedsignature": True}

setup(
    name = 'matrix vision image acquisition',
    cmdclass = {'build_ext': build_ext},
    ext_modules = ext_modules
    )
