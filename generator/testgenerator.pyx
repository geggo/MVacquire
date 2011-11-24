cdef class gen(object):
    def __iter__(self):
        n = 5
        yield n
        while n>0:
            n = n-1
            yield n
        return

#g = gen()
#for g in gen:
#    print g
