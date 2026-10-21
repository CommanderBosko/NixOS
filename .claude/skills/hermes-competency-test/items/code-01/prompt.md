I need `parse_duration` in `task/durations.py` implemented. Right now it's a stub that raises
`NotImplementedError`. Its docstring is the spec: follow it exactly, including every error rule.

- Edit only `task/durations.py`. Keep the function name and signature, and use only the Python
  standard library.
- `task/test_durations_examples.py` has a few example tests. Don't change it. You can run it from
  the `task/` directory with `python3 -m unittest -v`. It covers only a small part of the spec, so
  add your own checks for the rest. Put any extra test files under `task/scratch/`, not in `/tmp`.
- Python 3.14 is available as `python3`. pytest is not installed; use `unittest`.

When you're done, tell me what you implemented, how you checked it, and anything in the spec you
found ambiguous.
