from Pyro4 import expose
from time import time


class Solver:
    def __init__(self, workers=None, input_file_name=None, output_file_name=None):
        self.workers = workers or []
        self.input_file_name = input_file_name
        self.output_file_name = output_file_name

    @staticmethod
    @expose
    def count_primes(bounds):
        start, end = bounds  
        total = 0
        for n in xrange(max(2, start), end):
            if n == 2:
                total += 1
                continue
            if n % 2 == 0:
                continue
            d = 3
            while d * d <= n and n % d != 0:
                d += 2
            if d * d > n:
                total += 1
        return total

    @staticmethod
    def split_range(n, count):
        size = (n - 1 + count - 1) // count  
        return [(start, min(n + 1, start + size))
                for start in xrange(2, n + 1, size)]

    def solve(self):
        with open(self.input_file_name) as f:
            n = int(f.read().strip())
        if n < 2:
            raise ValueError('N must be >= 2')
        if not self.workers:
            raise ValueError('PARCS has no connected workers')

        start = time()
        sequential = self.count_primes((2, n + 1))
        seq_time = time() - start

        chunks = self.split_range(n, len(self.workers))
        start = time()
        futures = [self.workers[i].count_primes(chunk)
                   for i, chunk in enumerate(chunks)]
        parallel = sum(future.value for future in futures)
        par_time = time() - start

        if sequential != parallel:
            raise ValueError('Sequential and parallel answers differ')

        speedup = seq_time / par_time if par_time else 0
        efficiency = speedup / len(chunks)
        with open(self.output_file_name, 'w') as f:
            f.write('N={}\n'.format(n))
            f.write('workers={}\n'.format(len(chunks)))
            f.write('prime_count={}\n'.format(parallel))
            f.write('sequential_seconds={:.6f}\n'.format(seq_time))
            f.write('parallel_seconds={:.6f}\n'.format(par_time))
            f.write('speedup={:.4f}\n'.format(speedup))
            f.write('efficiency={:.4f}\n'.format(efficiency))
