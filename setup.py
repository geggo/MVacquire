from distutils.core import setup
from distutils.extension import Extension
from Cython.Distutils import build_ext
setup(
    cmdclass = {'build_ext': build_ext},
    ext_modules = [Extension("mv",
                             ["_mvDeviceManager.pyx"],
                             libraries = ["mvDeviceManager"],
                             include_dirs = ["matrix-vision"],
                             library_dirs = ["matrix-vision/lib"],
                             )
                   ]
    )
