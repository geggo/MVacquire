================================================
Introduction to mv: matrix vision python wrapper
================================================

The mv package provides a python wrapper for image acquisition with hardware from `matrix vision <http://www.matrix-vision.de>`_.

This wrapper is written in cython and uses the C interface of the
mvIMPACT Acquire library. There used to exist a complete python
wrapper, provided by matrix vision, but support has been
dropped. Compared to this SWIG based wrapper, which closely followed
the C++ interface, the mv package offers a more pythonic interface,
see :doc:`tutorial`. This wrapper does *not* follow the original C++ interface.

Requirements
------------

* Python (tested with 2.6 and 2.7, should work with 2.5 - 3.2, 32 or 64bit)
* installed ``mvIMPACT Acquire`` library (gets installed together with device drivers)
* cython 15.1+ (git version) for installation from source (requires C
  compiler, e.g. Visual Studio 2008)
* numpy (optional,  recommended for image manipulation)
* matplotlib (optional, for image display)
* IPython (optional)

Installation
------------

1. edit path to mvIMPACT Acquire library and include path in ``setup.py``

2. for complete build::
   python setup.py install

3. for in-place build (quick testing)::
   python setup.py build_ext -i

License
-------

The mv package is published under the GNU Less General Public License (LGPL).
