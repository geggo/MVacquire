class gen(object):
    def __iter__(self):
        i = 0
        while i<3:
            yield i
            i += 1

for x in gen():
    print x
