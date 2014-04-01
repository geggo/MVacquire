Tutorial
========

The mvacquire modul offers a simple interface for image acquisition
with hardware from matrix-vision. It is designed to provide a very
pythonic interface, such that it can be easily used in an interactive
environment like an IPython shell.

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

More detailed information about the available devices is returned by
:py:meth:`DeviceManager.get_device_list`. 

If a device has been connected after initialization of
:py:class:`mv.DeviceManager`, call
:py:meth:`DeviceManager.get_device_list` to update the device list. 


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
available, or raises an :py:exc:`~mv.MVTimeoutError` if a given
timeout has elapsed without a result getting ready.

More information about the captured image (e.g. timestamp) is returned
by the :py:attr:`~mv.ImageResult.info` property of the
:py:class:`~mv.ImageResult` object as a python dict.

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

For convenience, the above command sequence is also available as
:py:meth:`~mv.Device.snapshot()`. The easiest way to display an image
is therefore::

   imshow(dev.snapshot())

(try this with an ipython shell, e.g. ``ipython pylab`` or ``ipython
qtconsole --pylab=inline``.


Accessing camera settings
~~~~~~~~~~~~~~~~~~~~~~~~~

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


.. note::

   The attributes belonging to camera settings can be distinguished
   from ordinary methods or properties by an initial capital letter.

Each individual setting is either another list of settings
(:py:class:`~mv.List`), a (subclass of) :py:class:`~mv.Property`, holding individual
values, or a callable :py:class:`~mv.Method`.


For accessing the value of a Property, use the
:py:attr:`~mv.Property.value` property.

.. note::

   Note the difference between a Python property and a :py:class:`~mv.Property`!

Depending on the Property type, the value is returned as Python
int, long int, float, or bytes string. For vector Properties, i.e.,
Properties that contain an array of values, a list of corresponding
values is returned.

.. sourcecode:: ipython

    In [7]: pf.Pseudo64BitIntProp.value
    Out[7]: 10L
    In [8]: pf.PseudoInt64VectorProp.value
    Out[8]: [-9223372036854775808L, 0L, 9223372036854775807L]

For convenience a direct access to the Property value (without using
the :py:attr:`~mv.Property.value` property) is also possible. (In case
of read access to Properties, the `__str__` and `__repr__` methods are
implicitly called, returning the values formatted as strings).

.. sourcecode:: ipython

    In [17]: dev.Setting.Base.Camera.Gain_dB = 10

    In [18]: dev.Setting.Base.Camera.Gain_dB
    Out[18]: 10.0

    In [19]: print dev.Setting.Base.Camera.Gain_dB
    10.000 dB


Setting a Property value with a string argument is also possible, this
is especially useful for named integer properties.

.. sourcecode:: ipython

   In [29]: dev.Setting.Base.Camera.TestMode = 'MovingMonoRamp'

   In [30]: print dev.Setting.Base.Camera.TestMode
   MovingMonoRamp

For named integer properties, the translation dictionary is available
with the :py:meth:`~mv.PropertyInt.get_dict` method.

.. sourcecode:: ipython

   In [31]: dev.Setting.Base.Camera.TestMode.get_dict()
   Out[31]:
   {'BayerWhiteBalanceTestImage': 11,
    'EmptyMonoBuffer': 23,
    'HorizontalMono12Packed_V2Ramp': 18,
    'HorizontalMonoRamp': 15,
    'ImageDirectory': 12,
    'LeakyPixelTestImageMono8Bayer': 13,
    'MovingBGR888PackedImage': 19,
    'MovingBGRPacked_V2Ramp': 22,
    'MovingBayerDataRamp': 10,
    'MovingMonoRamp': 3,
    'MovingRGB101010PackedImage': 6,
    'MovingRGB121212PackedImage': 7,
    'MovingRGB141414PackedImage': 8,
    'MovingRGB161616PackedImage': 9,
    'MovingRGB888PackedImage': 1,
    'MovingRGBx888PackedImage': 0,
    'MovingRGBx888PlanarImage': 2,
    'MovingVerticalMonoRamp': 17,
    'MovingYUV422PackedRamp': 4,
    'MovingYUV422PlanarRamp': 5,
    'MovingYUV422_UYVYPackedRamp': 14,
    'MovingYUV444PackedRamp': 20,
    'MovingYUV444_UYVPackedRamp': 21,
    'VerticalMonoRamp': 16}



