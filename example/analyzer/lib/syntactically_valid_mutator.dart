// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:math';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:fuzz_example_analyzer/find_targets_visitor.dart';
import 'package:fuzz_example_analyzer/parse_unit.dart';
import 'package:fuzz_example_analyzer/syntactically_valid_mutations.dart';
import 'package:fuzz_example_analyzer/use_dart_fuzz.dart';

final random = Random();

String cleanExprForContext(String newExpr, Expression context) {
  if (newExpr.startsWith('{')) {
    var parent = context.parent;
    var allowed = false;

    while (parent is Expression) {
      parent = parent.parent;
      if (parent.offset < context.offset) {
        allowed = true;
        break;
      }
    }
    if (!allowed) {
      return '($newExpr)';
    }
  }
  if (newExpr.startsWith('-')) {
    return ' $newExpr';
  }
  if (newExpr.endsWith('-') || newExpr.endsWith('+')) {
    return '$newExpr ';
  }
  return newExpr;
}

Future<String> syntacticallyValidMutator(String str) async {
  final parseResult = await parseUnit(str);
  if (parseResult.errors.isNotEmpty) {
    // TODO: return null and have the fuzzer try a different mutator?
    return '';
  }
  final ast = parseResult.unit;
  final targets = FindTargetsVisitor();
  ast.accept(targets);
  String result;

  switch (random.nextInt(11)) {
    RemoveNode:
    case 0:
      if (targets.removalTargets.isEmpty) {
        continue NewTopLevel;
      }
      final removalTarget =
          targets.removalTargets[random.nextInt(targets.removalTargets.length)];
      result = str.replaceRange(removalTarget.offset, removalTarget.end, '');
      break;

    ReplaceExpr:
    case 1:
      if (targets.expressions.isEmpty) {
        continue NewStatement;
      }
      final expr =
          targets.expressions[random.nextInt(targets.expressions.length)];
      var newExpr = generateExpr(random);
      newExpr = cleanExprForContext(newExpr, expr);

      result = str.replaceRange(expr.offset, expr.end, newExpr);
      break;

    ReplaceIdentifier:
    case 2:
      if (targets.identifiers.isEmpty) {
        continue NewStatement;
      }
      final id =
          targets.identifiers[random.nextInt(targets.identifiers.length)];
      final newId = '${id}aoeu';

      result = str.replaceRange(id.offset, id.end, newId);
      break;

    WrapExpr:
    case 3:
      if (targets.expressions.isEmpty) {
        continue NewStatement;
      }
      final expr =
          targets.expressions[random.nextInt(targets.expressions.length)];
      final isBlock = random.nextBool();

      result = str
          .replaceRange(expr.end, expr.end, isBlock ? '; }()' : '')
          .replaceRange(
              expr.offset, expr.offset, isBlock ? '() { return ' : '() => ');
      break;

    InsertExpr:
    case 4:
      if (targets.expressionInsertionPoints.isEmpty) {
        continue ReplaceExpr;
      }
      final offset = targets.expressionInsertionPoints[
          random.nextInt(targets.expressionInsertionPoints.length)];
      final expression = generateExpr(random);

      result = str
          .replaceRange(offset, offset, ', $expression,')
          .replaceAll('[,', '[')
          .replaceAll('(,', '(')
          .replaceAll('{,', '{')
          .replaceAll(',,', ',');

      if (random.nextBool()) {
        result = result
            .replaceAll(',]', ']')
            .replaceAll(',)', ')')
            .replaceAll(',}', '}');
      }
      break;

    InsertCascade:
    case 5:
      final options = targets.expressions
          .where((node) => node.parent is! ConditionalExpression)
          .where((node) => !(node is PrefixExpression &&
              (node.operator.type == TokenType.PLUS_PLUS ||
                  node.operator.type == TokenType.MINUS_MINUS)))
          .where((node) => !(node is PostfixExpression &&
              (node.operator.type == TokenType.PLUS_PLUS ||
                  node.operator.type == TokenType.MINUS_MINUS)))
          .toList();
      if (options.isEmpty) {
        continue NewStatement;
      }
      final expr = options[random.nextInt(options.length)];

      result = str.replaceRange(expr.end, expr.end, generateCascade(random));
      break;

    InsertArgumentName:
    case 6:
      if (targets.argNameInsertionPoints.isEmpty) {
        continue ReplaceExpr;
      }
      final offset = targets.argNameInsertionPoints[
          random.nextInt(targets.argNameInsertionPoints.length)];
      final name = 'arg${random.nextInt(10)}';

      result = str.replaceRange(offset, offset, '$name: ');
      break;

    NewStatement:
    case 7:
      if (targets.statementInsertionPoints.isEmpty) {
        continue NewClassMember;
      }
      final offset = targets.statementInsertionPoints[
          random.nextInt(targets.statementInsertionPoints.length)];
      final statement = generateStatement(random);

      result = str.replaceRange(offset, offset, statement);
      break;

    NewClassMember:
    case 8:
      final classes = ast.declarations.whereType<ClassDeclaration>().toList();
      if (classes.isEmpty) {
        continue RemoveNode;
      }
      final cls = classes[random.nextInt(classes.length)];
      final newMember = generateMember(random);

      result = str.replaceRange(cls.end - 1, cls.end - 1, newMember);
      break;

    NewComment:
    case 9:
      final tokens = <Token>[];
      var token = ast.beginToken;
      while (token.type != TokenType.EOF) {
        tokens.add(token);
        token = token.next;
      }
      if (tokens.isEmpty) {
        continue NewTopLevel;
      }
      final location = tokens[random.nextInt(tokens.length)].offset;
      final text = Iterable.generate(random.nextInt(60), (_) => 'a').join('');
      result = str.replaceRange(
          location,
          location,
          random.nextBool()
              ? '/* $text${('\n' + text) * random.nextInt(4)} */'
              : '// $text\n');
      break;

    NewTopLevel:
    case 10:
      result = '$str\n${await generateTopLevel(random)}';
      break;
  }

  final newResult = await parseUnit(result);
  if (newResult.errors.isNotEmpty) {
    throw 'screwed up: $str -> $result';
  }

  return result;
}
