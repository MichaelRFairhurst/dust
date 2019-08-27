import 'package:dart_style/dart_style.dart';
import 'package:fuzz_example_analyzer/semantically_valid_json_ast_renderer.dart';

void main(List<String> args) {
  var input = args[0];
  print(DartFormatter().format(RenderSemanticallyValidJson(input).render()));
}
