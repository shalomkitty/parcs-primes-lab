# PARCS-Python: parallel numerical integration (midpoint rule).
# Estimate pi = integral from 0 to 1 of 4 / (1 + x*x) dx.

from Pyro4 import expose
from math import pi
from time import time


class Solver:
    def __init__(self, workers=None, input_file_name=None, output_file_name=None):
        self.workers = workers or []
        self.input_file_name = input_file_name
        self.output_file_name = output_file_name

    @staticmethod
    @expose
    def integrate_chunk(args):
        left, right, n = args   # Index interval [left, right)
        step = 1.0 / n
        total = 0.0
        for i in xrange(left, right):
            x = (i + 0.5) * step
            total += 4.0 / (1.0 + x * x)
        return total * step

    @staticmethod
    def split_range(n, count):
        if n < 1 or count < 1:
            raise ValueError('N and worker count must be positive')
        size = (n + count - 1) // count
        return [(left, min(n, left + size))
                for left in xrange(0, n, size)]

    def solve(self):
        with open(self.input_file_name) as f:
            n = int(f.read().strip())
        if n < 1:
            raise ValueError('N must be positive')
        if not self.workers:
            raise ValueError('PARCS has no connected workers')

        start = time()
        sequential = self.integrate_chunk((0, n, n))
        seq_time = time() - start

        chunks = self.split_range(n, len(self.workers))
        start = time()
        futures = [self.workers[i].integrate_chunk((left, right, n))
                   for i, (left, right) in enumerate(chunks)]
        parallel = sum(future.value for future in futures)
        par_time = time() - start

        # Floating-point summation order can differ across workers.
        if abs(sequential - parallel) > 1e-8:
            raise ValueError('Sequential and parallel answers differ')

        speedup = seq_time / par_time if par_time else 0.0
        efficiency = speedup / len(chunks)
        with open(self.output_file_name, 'w') as f:
            f.write('N={}\n'.format(n))
            f.write('workers={}\n'.format(len(chunks)))
            f.write('approx_pi={:.12f}\n'.format(parallel))
            f.write('absolute_error={:.12f}\n'.format(abs(parallel - pi)))
            f.write('sequential_seconds={:.6f}\n'.format(seq_time))
            f.write('parallel_seconds={:.6f}\n'.format(par_time))
            f.write('speedup={:.4f}\n'.format(speedup))
            f.write('efficiency={:.4f}\n'.format(efficiency))
