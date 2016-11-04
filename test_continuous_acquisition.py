from __future__ import print_function

import time
from threading import Thread
from six.moves.queue import Queue, Empty, Full

import numpy as np
import mv


"""
Demo program for contiuous image acquisition.

Uses own thread for image acquisition, acquired images made available
to main thread via a queue.
"""

class AcquisitionThread(Thread):
    
    def __init__(self, device, queue):
        super(AcquisitionThread, self).__init__()
        self.dev = device
        self.queue = queue
        self.wants_abort = False

    def acquire_image(self):
        #try to submit 2 new requests -> queue always full
        try:
            self.dev.image_request()
            self.dev.image_request()
        except mv.MVError as e:
            pass

        #get image
        image_result = None
        try:
            image_result = self.dev.get_image()
        except mv.MVTimeoutError:
            print("timeout")
        except Exception as e:
            print("camera error: ",e)
        
        #pack image data together with metadata in a dict
        if image_result is not None:
            buf = image_result.get_buffer()
            imgdata = np.array(buf, copy = False)
            
            info=image_result.info
            timestamp = info['timeStamp_us']
            frameNr = info['frameNr']

            del image_result
            return dict(img=imgdata, t=timestamp, N=frameNr)
        
    def reset(self):
        self.dev.image_request_reset()
        
    def run(self):
        self.reset()
        while not self.wants_abort:
            img = self.acquire_image()
            if img is not None:
                try:
                    self.queue.put_nowait(img)
                    #print('.',) #
                except Full:
                    #print('!',)
                    pass

        self.reset()
        print("acquisition thread finished")

    def stop(self):
        self.wants_abort = True

#find an open device
serials = mv.List(0).Devices.children #hack to get list of available device names
serial = serials[0]
device = mv.dmg.get_device(serial)
print('Using device:', serial)

queue = Queue(10)
acquisition_thread = AcquisitionThread(device, queue)

#consume images in main thread
acquisition_thread.start()
#time.sleep(0.1)
for i in range(20):
    try:
        img = queue.get(block=True, timeout = 1)
        print("consumed image #", img['N'])
    except Empty:
        print("got no image")

#wait until acquisition thread has stopped
acquisition_thread.stop()
acquisition_thread.join()


