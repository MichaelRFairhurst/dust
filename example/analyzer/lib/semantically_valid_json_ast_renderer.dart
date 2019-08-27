import 'dart:convert';
import 'dart:math';

import 'package:dart_style/dart_style.dart';
import 'package:fuzz_example_analyzer/semantically_valid_json_ast_mutator.dart';

void main(List<String> args) {
  random = Random(0);
  var input = '';
  int i = 0;
  while (i++ < 500) {
    input = SemanticallyValidJsonAstMutator(input).run();
    print(DartFormatter().format(RenderSemanticallyValidJson(input).render()));
  }
  print('<--------->');
  print('<--------->');
  print('<--------->');
  print('<--------->');
  print(DartFormatter().format(RenderSemanticallyValidJson(input).render()));
}

class RenderSemanticallyValidJson {
  final sb = StringBuffer();
  final ast;
  final classNames = <Map, String>{};
  final methodNames = <Map, String>{};
  final fieldNames = <Map, String>{};
  final paramNames = <int, String>{};
  Map currentClass;

  String nameOfMethod(Map method) =>
      methodNames.putIfAbsent(method, () => 'm${methodNames.length}');

  String nameOfField(Map field) =>
      fieldNames.putIfAbsent(field, () => 'f${fieldNames.length}');

  String nameOfClass(Map class_) =>
      classNames.putIfAbsent(class_, () => 'c${classNames.length}');

  String nameOfParam(int index) =>
      paramNames.putIfAbsent(index, () => 'p${paramNames.length}');

  RenderSemanticallyValidJson(String str) : ast = jsonDecode(str);

  String render() {
    methodNames[ast[kMain]] = 'main';
    renderMethod(ast[kMain]);

    // ignore: prefer_foreach
    for (final field in ast[kFields]) {
      renderField(field);
    }

    // ignore: prefer_foreach
    for (final method in ast[kMethods]) {
      renderMethod(method);
    }

    // ignore: prefer_foreach
    for (final class_ in ast[kClasses]) {
      renderClass(class_);
    }

    return sb.toString();
  }

  String renderClass(Map class_) {
    currentClass = class_;
    sb.write('class ${nameOfClass(class_)} {');
    // ignore: prefer_foreach
    for (final method in class_[kMethods]) {
      renderMethod(method);
    }
    // ignore: prefer_foreach
    for (final field in class_[kFields]) {
      renderField(field);
    }
    sb.write('}');
    currentClass = null;
  }

  void renderMethod(Map method) {
    if (method[kIsStatic]) {
      sb.write('static ');
    }

    renderType(method[kReturnType]);

    sb.write(' ');
    sb.write(nameOfMethod(method));
    // TODO actual parameters
    sb.write('(');
    paramNames.clear();
    for (var i = 0; i < method[kParameters].length; ++i) {
      if (i != 0) {
        sb.write(', ');
      }
      renderType(method[kParameters][i]);
      sb..write(' ')..write(nameOfParam(i));
    }
    sb.write(') {');

    for (final stmt in method[kStmts]) {
      renderStmt(stmt);
    }
    sb.write('}');
  }

  void renderStmt(Map stmt) {
    switch (stmt[kKind]) {
      case kExpStmt:
        renderExp(stmt[kExp], 0);
        sb.write(';');
        break;
      case kReturn:
        sb.write('return ');
        if (stmt[kExp] != null) {
          renderExp(stmt[kExp], 0);
        }
        sb.write(';');
        break;
      case kIf:
        sb.write('if (');
        renderExp(stmt[kCond], 0);
        sb.write(') {');
        for (final stmt in stmt[kThen]) {
          renderStmt(stmt);
        }
        if (stmt[kElse].isNotEmpty) {
          sb.write('} else {');
          for (final stmt in stmt[kElse]) {
            renderStmt(stmt);
          }
        }
        sb.write('}');
        break;
      case kWhile:
        sb.write('while (');
        renderExp(stmt[kCond], 0);
        sb.write(') {');
        for (final stmt in stmt[kStmts]) {
          renderStmt(stmt);
        }
        sb.write('}');
        break;
      case kDoWhile:
        sb.write('do {');
        for (final stmt in stmt[kStmts]) {
          renderStmt(stmt);
        }
        sb.write('} while (');
        renderExp(stmt[kCond], 0);
        sb.write(');');
        break;
      case kFor:
        sb.write('for (');
        if (stmt[kInit] != null) {
          renderExp(stmt[kInit], 0);
        }
        sb.write(';');
        if (stmt[kCond] != null) {
          renderExp(stmt[kCond], 0);
        }
        sb.write(';');
        for (final exp in stmt[kUpdate]) {
          renderExp(exp, 0);
          sb.write(',');
        }
        sb.write(') {');
        for (final stmt in stmt[kStmts]) {
          renderStmt(stmt);
        }
        sb.write('}');
    }
  }

  void renderField(Map field) {
    if (field[kIsStatic]) {
      sb.write('static ');
    }
    if (field[kIsFinal]) {
      sb.write('final ');
    }

    if (!field[kImplicitType]) {
      renderType(field[kType]);
      sb.write(' ');
    } else if (!field[kIsFinal]) {
      sb.write('var ');
    }

    sb.write(nameOfField(field));
    if (field[kInitializer] != null) {
      sb.write(' = ');
      renderExp(field[kInitializer], 0);
    }
    sb.write(';');
  }

  void renderType(Map type) {
    if (type[kKind] == kBaseType) {
      sb.write(type[kLexeme]);
    } else if (type[kKind] == kClassType) {
      sb.write(nameOfClass(ast[kClasses][type[kIndex]]));
    } else {
      throw 'unexpect type $type';
    }
  }

  int getPrecedence(Map exp) {
    switch (exp[kKind]) {
      case kBinary:
        switch(exp[kOperator]) {
          case '??':
            return 3;
          case '||':
            return 4;
          case '&&':
            return 5;
          case '==':
            return 6;
          case '!=':
            return 6;
          case '>':
            return 7;
          case '>=':
            return 7;
          case '<':
            return 7;
          case '<=':
            return 7;
          case '|':
            return 8;
          case '^':
            return 9;
          case '&':
            return 10;
          case '<<':
            return 11;
          case '>>>':
            return 11;
          case '>>':
            return 11;
          case '+':
            return 12;
          case '-':
            return 12;
          case '*':
            return 13;
          case '/':
            return 13;
          case '%':
            return 13;
          default:
            throw 'unexpected ${exp[kOperator]}';
        }
        break;
      case kCtor:
        return 100;
        break;
      case kTopLevelMethod:
        return 100;
        break;
      case kClassMethod:
        return 100;
        break;
      case kPropertyAccess:
        return 100;
        break;
      case kMethodCall:
        return 100;
        break;
      case kBasicLiteral:
        return 100;
        break;
      case kTopLevelRef:
        return 100;
        break;
      case kFieldRef:
        return 100;
        break;
      case kAssign:
        switch(exp[kOperator]) {
          case '=':
            return 2;
          default:
            throw 'unexpected ${exp[kOperator]}';
        }
        break;
      case kThrow:
        return 1;
        break;
      default:
        throw 'unexpected exp $exp';
    }
  }

  void renderExp(Map exp, int precedence) {
    final newPrecedence = getPrecedence(exp);
    if (newPrecedence < precedence) {
      sb.write('(');
    }
    switch (exp[kKind]) {
      case kBinary:
        renderExp(exp[kLhs], newPrecedence);
        sb.write(exp[kOperator]);
        renderExp(exp[kRhs], newPrecedence);
        break;
      case kCtor:
        if (exp[kIndex] == -1) {
          sb.write('Object');
        } else {
          sb.write(nameOfClass(ast[kClasses][exp[kIndex]]));
        }
        sb.write('()');
        break;
      case kTopLevelMethod:
        sb.write(exp[kIndex] == 'main'
            ? 'main'
            : nameOfMethod(ast[kMethods][exp[kIndex]]));
        sb.write('(');
        for (var i = 0; i < exp[kParameters].length; ++i) {
          if (i != 0) {
            sb.write(', ');
          }
          renderExp(exp[kParameters][i], 0);
        }
        sb.write(')');
        break;
      case kClassMethod:
        sb.write(nameOfMethod(currentClass[kMethods][exp[kIndex]]));
        sb.write('(');
        for (var i = 0; i < exp[kParameters].length; ++i) {
          if (i != 0) {
            sb.write(', ');
          }
          renderExp(exp[kParameters][i], 0);
        }
        sb.write(')');
        break;
      case kPropertyAccess:
        renderExp(exp[kTarget], newPrecedence);
        sb.write('.');
        sb.write(nameOfField(
            ast[kClasses][exp[kClassIndex]][kFields][exp[kIndex]]));
        break;
      case kMethodCall:
        renderExp(exp[kTarget], newPrecedence);
        sb.write('.');
        sb.write(nameOfMethod(
            ast[kClasses][exp[kClassIndex]][kMethods][exp[kIndex]]));
        sb.write('(');
        for (var i = 0; i < exp[kParameters].length; ++i) {
          if (i != 0) {
            sb.write(', ');
          }
          renderExp(exp[kParameters][i], 0);
        }
        sb.write(')');
        break;
      case kBasicLiteral:
        sb.write(exp[kLexeme]);
        break;
      case kTopLevelRef:
        final topLevel = ast[kFields][exp[kIndex]];
        final name = nameOfField(topLevel);
        sb.write(name);
        break;
      case kFieldRef:
        final field = currentClass[kFields][exp[kIndex]];
        final name = nameOfField(field);
        sb.write(name);
        break;
      case kAssign:
        renderExp(exp[kLhs], newPrecedence);
        sb.write(exp[kOperator]);
        renderExp(exp[kRhs], newPrecedence);
        break;
      case kThrow:
        sb.write('throw ');
        renderExp(exp[kExp], newPrecedence);
        break;
      default:
        throw 'unexpected exp $exp';
    }

    if (newPrecedence < precedence) {
      sb.write(')');
    }
  }
}
