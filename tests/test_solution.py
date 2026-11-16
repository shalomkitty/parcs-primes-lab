# python3 -m unittest discover -s tests -v
import math
import os
import sys
import tempfile
import types
import unittest


sys.modules.setdefault('Pyro4', types.SimpleNamespace(expose=lambda method: method))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import solution

# Python 2.7 has xrange, Python 3 does not.
solution.__dict__['xrange'] = range


class Future:
    def __init__(self, value):
        self.value = value


class FakeWorker:
    def integrate_chunk(self, args):
        return Future(solution.Solver.integrate_chunk(args))


class IntegrationTests(unittest.TestCase):
    def test_midpoint_rule_approximates_pi(self):
        for n, tolerance in [(10, 0.01), (100, 0.0001), (1000, 0.000001)]:
            result = solution.Solver.integrate_chunk((0, n, n))
            self.assertLess(abs(result - math.pi), tolerance)

    def test_split_covers_each_index_once(self):
        for workers in (1, 2, 4, 20):
            chunks = solution.Solver.split_range(11, workers)
            indices = [i for left, right in chunks for i in range(left, right)]
            self.assertEqual(indices, list(range(11)))

    def test_four_workers_end_to_end(self):
        with tempfile.TemporaryDirectory() as directory:
            input_path = os.path.join(directory, 'input.txt')
            output_path = os.path.join(directory, 'output.txt')
            with open(input_path, 'w') as f:
                f.write('10000\n')
            solver = solution.Solver([FakeWorker() for _ in range(4)],
                                     input_path, output_path)
            solver.solve()
            with open(output_path) as f:
                result = dict(line.strip().split('=', 1) for line in f)
            self.assertEqual(result['workers'], '4')
            self.assertLess(abs(float(result['approx_pi']) - math.pi), 1e-8)
            self.assertLess(float(result['absolute_error']), 1e-8)

    def test_rejects_invalid_n(self):
        with self.assertRaises(ValueError):
            solution.Solver.split_range(0, 4)


if __name__ == '__main__':
    unittest.main()
