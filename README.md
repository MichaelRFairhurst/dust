# Dust

A coverage-guided fuzz tester for Dart.

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

[ ] normalize Location objects to reduce memory
[ ] explore reusing isolates for better JITing. Locations will be cumulative
    rather than unique. When a fuzz test hits a new Location, rerun it in a
    fresh isolate.
[ ] investigate adding support for coverage in AOT apps, which will speed up
    running fuzz cases
[ ] improve error handling for cases where the dart VM crashes etc
[ ] add a timeout that's considered a failure
[ ] [try different fuzz mutation techniques](https://lcamtuf.blogspot.com/2014/08/binary-fuzzing-strategies-what-works.html)
[ ] add API for providing a script to do custom mutations
[ ] add failure cases simplifiers
[ ] add support for serializing fuzz failure cases

etc.
