MVacquire
=========

MVacquire provides a Python wrapper for the mvIMPACT Acquire library for image acquisition with hardware (cameras, framegrabbers) from Matrix Vision.
With their mvGenTL_Acquire driver package image acquisition from all cameras (also from other manufactures) compliant with the GenICam, GigE Vision or USB3 Vision standard is possible.

For further information see e.g. the `intro <docs/intro.rst>`_  or `tutorial <docs/tutorial.rst>`_ in the `docs <docs/>`_ folder.


Build on Windows with Microsoft Visual C++ Compiler Package for Python 2.7
--------------------------------------------------------------------------

* depending on system open 'Visual C++ 2008 32-bit Command Prompt', or 'Visual C++ 2008 64-bit Command Prompt'

* navigate to MVacquire base directory::
  
    set MSSDK=1
    set DISTUTILS_USE_SDK=1
    python setup.py build
    python setup.py install
