from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext

#import numpy as np

setup(
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("mv",
                             ["_mvDeviceManager.pyx"],
                             libraries = ["mvDeviceManager"],
                             include_dirs = ["matrix-vision",
                                             #np.get_include(),
                                             ],
                             library_dirs = ["matrix-vision/lib"],
                             )
                   ]
    )
