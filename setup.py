from __future__ import print_function
import os, os.path, platform
from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
#import numpy as np

mvbase = os.path.normpath(os.getenv('MVIMPACT_ACQUIRE_DIR', 'matrix-vision'))
if mvbase is None:
    print("Warning! mvIMPACT Acquire base directory location unknown")
    mvbase = 'matrix-vision'

mvinclude = mvbase
mvlib = os.path.join(mvbase, 'lib')
system = platform.system()
bits,foo = platform.architecture()
if system == 'Windows' and bits == '64bit':
    mvlib = os.path.join(mvlib, r'win\x64')
elif system == 'Linux' and bits == '64bit':
    mvlib = os.path.join(mvlib, 'x86_64')

ext_modules = [Extension("mv",
                        ["_mvDeviceManager.pyx"],
                        libraries = ["mvDeviceManager"],
                        include_dirs = [mvinclude,
                                        #np.get_include(),
                                        ],
                        library_dirs = [mvlib],)]
for e in ext_modules:
    e.pyrex_directives = {"embedsignature": True}

setup(
    name = 'matrix vision image acquisition',
    cmdclass = {'build_ext': build_ext},
    ext_modules = ext_modules
    )
