- enable asserts in fuzz target VMs
- Added mutators to merge two existing seeds
- Stack 1-3 changes rather than only doing 1 mutation.
- Simplifier improvements: bugfixes, faster fixed-point search.
- Fixed issue treating failures as executions (printing . & double counting)
- New simplifier constraint "contains output"
- Better error when port is already taken and observatory fails to start
- Auto-snapshot scripts for users
- Better error when script is erroneous (though erroneous snapshots may not give
  a good error message)
- switch from `vm_service_lib` to `vm_service`
- Coverage stats by path as well as files that have not been executed.

* 1.0.0-beta.8

- Fix critical bug that broke fuzzer when no limit was set.

* 1.0.0-beta.7

- Run manual seeds first, corpus seeds second, seed dir third, for better
  performance when the seed dir requires minimization.

* 1.0.0-beta.6

- Specifiable fuzz count limit, and exits 1 if any failures detected.
- Time printouts during simplification
- Warning if simplifier changed output / "same output" constraint no longer
  defaults to ON.
- Run the simplifier to a fixed point when called from CLI.
- Optimized optimizer for long input sequences.

* 1.0.0-beta.5

- Automatic simplification of seeds
- Better simplification algorithm
- Optimized profile collection. `crash_on_bad.dart` now runs 6x faster, though
  programs which do more meaningful work will see less gain.
- Optimized simplifier. Will not collect coverage unless necessary.

* 1.0.0-beta.4

- Switch seed loading/persistence to more of a libfuzzer in/out/merge model.
- Added option to persist failures to a directory
- Changed `compress_locations` abbreviation from `c` to `o`.

* 1.0.0-beta.3

- Added a configurable timeout per case.
- Changed default stats interval to 120s
- Added seed loading/persistence to a directory

* 1.0.0-beta.2

- Added stat collection / printouts.

* 1.0.0-beta.1

- Added support for custom mutators.

* 1.0.0-beta.0

Initial release
