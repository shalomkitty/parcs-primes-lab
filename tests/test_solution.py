import os
import sys
import tempfile
import types
import unittest


sys.modules.setdefault('Pyro4', types.SimpleNamespace(expose=lambda method: method))
sys.path.insert(0, os.path.dirname(os.path.dirname(__file__)))
import solution


solution.__dict__['xrange'] = range


class Future:
    def __init__(self, value):
        self.value = value


class FakeWorker:
    def count_primes(self, bounds):
        return Future(solution.Solver.count_primes(bounds))


class PrimeTests(unittest.TestCase):
    def test_known_answers(self):
        for n, expected in [(2, 1), (10, 4), (100, 25), (1000, 168)]:
            self.assertEqual(solution.Solver.count_primes((2, n + 1)), expected)

    def test_split_covers_every_number_once(self):
        for workers in (1, 2, 4):
            chunks = solution.Solver.split_range(102, workers)
            all_numbers = [v for left, right in chunks for v in range(left, right)]
            self.assertEqual(all_numbers, list(range(2, 103)))

    def test_end_to_end_with_four_workers(self):
        with tempfile.TemporaryDirectory() as tmp:
            input_path = os.path.join(tmp, 'input.txt')
            output_path = os.path.join(tmp, 'output.txt')
            with open(input_path, 'w') as file:
                file.write('1000\n')
            solver = solution.Solver([FakeWorker() for _ in range(4)], input_path, output_path)
            solver.solve()
            with open(output_path) as file:
                output = file.read()
            self.assertIn('prime_count=168\n', output)
            self.assertIn('workers=4\n', output)


if __name__ == '__main__':
    unittest.main()
