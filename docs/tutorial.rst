Tutorial
========

The mv extension is designed to provide a very pythonic interface, such that it can be easily used in an interactive environment like an IPython shell. 

Initialization
~~~~~~~~~~~~~~

Necessary for all interaction is the :py:class:`mv.DeviceManager`.
On loading the mv extension already creates an instance mv.dmg
::

   from mv import dmg

Opening an imaging device
~~~~~~~~~~~~~~~~~~~~~~~~~

In an IPython shell, try typing 'dmg.' and hit TAB:

.. sourcecode:: ipython

   In [2]: dmg.
   dmg.BF004672        dmg.VD000002        dmg.get_device
   dmg.VD000001        dmg.device_count    dmg.get_device_list

Installed devices (here: a BlueFOX USB camera and two virtual devices)
are accessible as attributes of the device manager instance dmg. They
are listed by their serial number. Acessing them opens a connection to
the device, which is automatically closed when the object goes out of
scope.

.. sourcecode:: ipython

   In [22]: dev = dmg.VD000001
   open device 0x30001 0xac0000

   In [23]: del dev
   close device 0x30001 0xac0000

More detailed information about the available devices is returned by :py:meth:`DeviceManager.get_device_list`.


Getting an image
~~~~~~~~~~~~~~~~

Some background: For image acquisition the underlying C library uses
so called 'request objects'. For each image one wants to acquire,
such an request object needs to be placed into a 'request queue'. For
this, use the :py:meth:`~mv.Device.image_request` method.

After an image has been acquired (or an timeout elapsed), the request
object is moved to the 'result queue'. To get a
:py:class:`~mv.ImageResult` object, use
:py:meth:`~mv.Device.get_image`. This call blocks until a result is
available, or raises an :py:exc:`~mv.MVTimeoutError` if a given timeout
has elapsed without a result getting ready. 

To actually get the image data, use
:py:meth:`~mv.ImageResult.get_buffer`. This returns a `memoryview`
object to a copy of the image data. From this you can obtain a `numpy`
array with `numpy.asarray`.

For subsequent image acquisition, the request object needs to be
released, since only a limited number (default 4) of request objects
is available. For this, free (delete) the image result object obtained
by get_image if you are done. A minimal command sequence might would be:
::

   dev.image_request()
   image_result = dev.get_image(timeout=1) #wait at most 1 second
   buf = image_result.get_buffer()
   del image_result

   img = np.asarray(buf)


Changing camera settings
~~~~~~~~~~~~~~~~~~~~~~~~

*All* available settings (also called a :py:class:`~mv.Property`) are
organized in a tree like structure. They are accessible as attributes
(of attributes of attributes...), e.g.  ::

   >>> print dev.Setting.Base.Camera.Gain_dB
   1.000 dB

Code completion in ipython (with TAB key) displays a list of possible
attributes while typing. Alternatively, you get a list of child
settings with `dir`
::

    >>> dir(dev.Setting.Base.Camera)
    ['Aoi',
     'BayerMosaicParity',
     'ChannelBitDepth',
     'FrameDelay_us',
     'Gain_dB',
     'ImageDirectory',
     'ImageRequestTimeout_ms',
     'ImageType',
     'PixelFormat',
     'PseudoFeatures',
     'TapsXGeometry',
     'TapsYGeometry',
     'TestImageBarWidth',
     'TestMode',
     'UserData']


.. :note:

   The attributes belonging to camera settings can be distinguished
   from ordinary methods or properties by an initial capital letter.

Accessing a setting as an attribute returns its value as Python int,
long int, float, or bytes string, depending of the Property type.

For changing the value of a setting use the
:py:attr:`~mv.Property.value` attribute::

   >>> testmv.dev.Setting.Base.Camera.Gain_dB.value = 10.0
   >>> print testmv.dev.Setting.Base.Camera.Gain_dB
   10.000 dB

Setting a Property value with a string argument is also possible, this
is especially useful for named integer properties.::

   >>> dev.Setting.Base.Camera.TestMode.value = 'MovingMonoRamp'
   >>> print dev.Setting.Base.Camera.TestMode
   MovingMonoRamp

