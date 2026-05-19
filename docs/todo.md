## VRF Todo

Items that are planned but not immediately scheduled.

---

- **Test result summarize script.**
  A shared script in `scripts/` that iterates a list of SVUnit output directories,
  extracts the pass/fail summary line from each `run.log`, and prints a consolidated
  table to the console. Called as the final step of each component's `make test`
  target. Useful across all component test suites, not just the logger.
