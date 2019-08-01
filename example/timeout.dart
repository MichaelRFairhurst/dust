Future<void> main(List<String> args) async {
  final input = args[0];
  while (input == '!') {
    // lock the thread
  }

  await Future.delayed(const Duration(seconds: 5));
}
