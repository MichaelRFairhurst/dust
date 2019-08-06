# Dust

A coverage-guided fuzz tester for Dart.

_inspired by libFuzzer and AFL etc._

## Usage

Simply write a dart program with a `main` function, and use the first argument
as your input:

```dart
void main(List<String> args) {
  final input = args[0];

  /* use input */
}
```

The fuzz tester will look for crashes and report the failure output by randomly
generating strings, passing them to your program, and adapting them in search of
new code paths to maximize the exploration of your code for bugs. You can fuzz
for all kinds of properties in your code by throwing exceptions when you wish.

To fuzz your script, simply run:

```bash
pub global activate dust
pub global run dust path/to/script.dart
```

**Note: it is *highly* recommended to snapshot your script before running for
better performance.**

There are some special options you can see with `pub global run dust --help` to
configure how exactly the fuzzer runs.

### The Corpus

By default, when you run `dust` on some `script.dart`, it will create a
directory named `script.dart.corpus` that contains interesting fuzz samples used
to explore your program (this is how coverage-guided fuzzing works). This means
you can stop fuzzing your program and restart without losing progress.

#### Manual seeding

You can specify manual seeds in one of two ways. You can either pass in seeds
on the command-line, ie, `--seed foo --seed bar`, or you can pass in a seed
directory (which may function much like a unit test directory) with
`--seed_dir`.

If you do not specify manual seeds, the corpus begins as a single seed that is
the empty string `""`.

When manually specifying seeds, they will only be added to the corpus if the
coverage tool finds them interesting. Once interesting cases have been added to
the corpus, you don't need to pass in those seeds again until your program
perhaps changes in a meaningful way.

#### Minifying

A corpus can be reduced using manual seeding, by simply providing the flags
`--seed_dir=old.corpus --corpus_dir=new.corpus`. Optionally you may provide
`--count 0` to stop when the minimization is done.

#### Merging two corpuses

You can also merge two corpuses by simply manually seeding one corpus into
another, ie, `--seed_dir=corpus1 --corpus-dir=corpus2`.

### Simplifying Cases

You can simplify failing or non failing cases according to a simple character
deletion search, and custom constraints. These constraints affect which
simplifications are considered valid.

```bash
pub global run dust simplify path/to/script.dart input
```

There are useful constraints which default to off such as that no new paths are
executed by the simplification, or that the error output from the case does not
change.

By default, it is assumed you are simplifying a failure, and
`--constraint_failed` is therefore on by default. However, it may be disabled
to simplify non-failing cases as well.

### Custom Mutators

The default mutators will add, remove, or flip a random character in your seeds
in attempt to search for new seeds. To specify custom behavior, you can write a
script that can be spawned as an isolate by the main process:

```dart
import 'dart:isolate';
import 'package:dust/custom_mutator_helper.dart';

main(args, SendPort sendPort) => customMutatorHelper(sendPort, (str) {
  return ...; // mutate the string
});
```

To use this script, provide the flag `--mutator_script=script.dart`.

By default, each mutator (including the three default ones) have equal
probability. However, you may set a weight on custom scripts by appending a `:`
and then a double value, ie, `--mutator_script=script.dart:2.0`. The default
mutators each have a weight of `1.0`, and may be disabled entirely by passing
`--no_default_mutators`.

## Design

Fuzz testing is often an excellent supplemental testing tool to add to programs
where you need high stability.

The problem with *black box* fuzz testing is that the odds of striking a bad
input are often easily demonstrably exceedingly low. Take this code:

```dart
if (x == 0) {
  if (y == 1) {
    if (z == 2) {
      throw "bet your fuzzer won't catch this!");
    }
  }
}
```

If x, y, and z are randomly chosen numbers, there is only a 1 in 2^32^3 chance
of randomly getting through this code path.

This was first solved by inventing "white box" fuzz testing, which reads input
code and uses it to generate constraints that it solves to generate test cases.
This however is very challenging to do in a way that gives high coverage, as
many constraints are hard to solve, and it usually involves code generation
which is likely to be extremely complex.

White box fuzz testing was successful enough, however, to prompt the invention
of grey box fuzz testing.

Grey box fuzz testing combines black box fuzz testing with code coverage
instrumentation to guide the creation of a corpus of distinctly interesting fuzz
cases. Those fuzz cases are then seeds to create new cases, and if those new
cases provoke new code paths then they are added to the pool.

Going back to our code example, the first fuzz case to pass the first check
(`x == 0`) will be saved and mutated until a case is found which also passes the
second check, and so forth. While the odds of choosing the magical values 0, 1,
and 2 may still be low, the chance of choosing all three together are greatly
increased, and no special knowledge of the codes working is required. We only
need to check code coverage of test cases.

We can do this in dart, too, using the VM service protocol.

### Processes

The fuzzer works like so:

* User invokes fuzz's binary, passing in the location of a script to fuzz.
* The fuzzer generates a basic seed (perhaps an empty string).
* A seed is randomly chosen based on a fitness algorithm that values smaller
  seeds over shorter seeds, seeds that execute more paths over seeds that
  execute fewer, seeds that execute quicker vs seeds that take longer, and seeds
  that execute paths which are more unique relative to other seeds which execute
  paths that are more common.
* That seed is then mutated n times, where we will attempt to concurrently run
  n fuzz tests at once.
* n dart VMs are then started with debugging enabled, with a main script which
  knows the location of the target script to fuzz.
* Each of the n mutations are passed to one of the n dart VMs, which execute
  that script in an isolate, which pauses on exit.
* The main fuzz binary connects to the service protocol of the n VMs, and
  watches for the isolate completion events.
* When the fuzz script isolates complete, the main fuzz binary will get coverage
  information for the fuzz isolates before closing them down, and recording
  whether they passed or failed and how long it took.
* The coverage information for the new cases is compared to the old ones. If
  they executed new code paths, they are added to the pool of seeds.

# TODO

- [ ] explore reusing isolates for better JITing. Locations will be cumulative
      rather than unique. When a fuzz test hits a new Location, rerun it in a
      fresh isolate.
- [ ] investigate adding support for coverage in AOT apps, which will speed up
      running fuzz cases
- [ ] improve error handling for cases where the dart VM crashes etc
- [ ] [try different fuzz mutation techniques](https://lcamtuf.blogspot.com/2014/08/binary-fuzzing-strategies-what-works.html)
- [ ] auto-snapshot scripts for users
- [ ] improve coverage %
- [ ] some renames in the code: Library/Corpus
- [ ] targeted scoring for paths through certain files/packages/etc
- [ ] better (different?) simplification algorithm(s?)
- [ ] automatic detection of simpler seeds during fuzzing?
- [ ] store fuzzing options in script file (such as custom mutators, timeouts)
- [ ] use locality sensitive hashing to dedupe failures with different messages
      (or in the case of timeouts, the same messages) by jaccard index of their
      code coverage sets. Perhaps from: https://arxiv.org/pdf/1811.04633
- [ ] customizable limits & timeouts for simplifier?

etc.
