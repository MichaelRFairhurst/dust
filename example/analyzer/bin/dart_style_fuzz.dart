import 'package:dart_style/dart_style.dart';

void main(List<String> args) {
  final input = args[0];
  final formatter = DartFormatter();

  try {
    formatter.format(input);
  } on FormatterException catch (_) {
    return;
  }
}
