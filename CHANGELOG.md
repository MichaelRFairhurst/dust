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
