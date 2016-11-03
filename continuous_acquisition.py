import mv
import numpy as np
from queue import Queue

"""
Demo program for contiuous image acquisition.

Uses own thread for image acquisition, acquired images made available to main thread via a queue.
"""

class AcquisitionThread(Thread):
    
    def __init__(self, device, queue):
        super(AcquisitionThread, self).__init__()
        self.dev = device
        self.queue = queue
        self.wants_abort = False

    def acquire_image(self):
        image_result = None
        try:
            image_result = self.dev.get_image()
        except mv.MVTimeoutError:
            print "timeout"
        except Exception,e:
            print "camera error: ",e
        
        #try to submit 2 new requests -> queue always full
        try:
            self.dev.image_request()
            self.dev.image_request()
        except mv.MVError as e:
            pass
            
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
                self.queue.put_nowait(img)

        self.reset()
        print "acquisition thread finished"

    def stop(self):
        self.wants_abort = True



def list_cameras():
    r = mv.List(0)
    return r.Devices.children

serial = list_cameras()[0].serial
device = mv.dmg.get_device(serial)

queue = Queue(10)

acquisition_thread = AcquisitionThread(device, queue)
acquisition_thread.start()

for i in range(4):
    img = queue.get(block=True, timeout = 1)
    print "got image #", img['N']

time.sleep(10)
acquisition_thread.stop()
acquisition_thread.join()


