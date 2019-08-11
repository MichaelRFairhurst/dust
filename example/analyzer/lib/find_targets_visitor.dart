// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class FindTargetsVisitor extends GeneralizingAstVisitor {
  final removalTargets = <AstNode>[];
  final expressions = <AstNode>[];
  final typeNames = <AstNode>[];
  final statementInsertionPoints = <int>[];
  final expressionInsertionPoints = <int>[];
  final argNameInsertionPoints = <int>[];
  final identifiers = <Identifier>[];

  bool _outermost = true;
  final outermostStatements = <AstNode>[];

  @override
  void visitArgumentList(ArgumentList node) {
    expressionInsertionPoints.add(node.leftParenthesis.end);
    final positionalArgs = node.arguments
            .where((arg) => arg is! NamedExpression)
              ..forEach((element) => expressionInsertionPoints.add(element.end))
        //..forEach(removalTargets.add)
        ;
    if (positionalArgs.isNotEmpty) {
      argNameInsertionPoints.add(positionalArgs.last.offset);
    }
    visitNode(node);
  }

  @override
  void visitAssignmentExpression(AstNode node) {
    if (node.parent is! CascadeExpression) {
      expressions.add(node);
    }
    super.visitNode(node);
  }

  @override
  void visitBlock(AstNode node) {
    statementInsertionPoints.add(node.offset + 1);
    super.visitNode(node);
  }

  @override
  void visitClassDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitComment(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitConstructorDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitEnumConstantDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitEnumDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitExpression(Expression node) {
    final parent = node.parent;
    if (parent is AssignmentExpression && node == parent.leftHandSide) {
      // TODO: generate random lvalues
      return super.visitNode(node);
    }
    if (parent is PrefixExpression &&
        (parent.operator.type == TokenType.MINUS_MINUS ||
            parent.operator.type == TokenType.PLUS_PLUS)) {
      // TODO: generate random lvalues
      return super.visitNode(node);
    }
    if (parent is PostfixExpression &&
        (parent.operator.type == TokenType.MINUS_MINUS ||
            parent.operator.type == TokenType.PLUS_PLUS)) {
      // TODO: generate random lvalues
      return super.visitNode(node);
    }
    expressions.add(node);
    super.visitNode(node);
  }

  @override
  void visitFieldDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitFunctionBody(FunctionBody node) {
    super.visitNode(node);
  }

  @override
  void visitFunctionDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitFunctionExpression(AstNode node) {
    if (node.parent is Expression || node.parent is ExpressionStatement) {
      expressions.add(node);
    }
    super.visitNode(node);
  }

  @override
  void visitIdentifier(Identifier node) {
    identifiers.add(node);
    final parent = node.parent;
    if (parent is PrefixedIdentifier) {
      return;
    }

    if (parent is MethodInvocation && node != parent.target) {
      return;
    }

    if (parent is PropertyAccess && node != parent.target) {
      return;
    }

    if (parent is Expression ||
        parent is ExpressionStatement ||
        parent is InterpolationExpression) {
      return visitExpression(node);
    }

    super.visitNode(node);
  }

  @override
  void visitImportDirective(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitIndexExpression(IndexExpression node) {
    if (!node.isCascaded) {
      expressions.add(node);
    }
    super.visitNode(node);
  }

  @override
  void visitInterpolationElement(AstNode node) {
    //removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitInterpolationExpression(InterpolationExpression node) {
    removalTargets.add(node);
    if (node.rightBracket != null) {
      expressions.add(node);
      super.visitNode(node);
    }
  }

  @override
  void visitListLiteral(ListLiteral node) {
    expressionInsertionPoints.add(node.leftBracket.end);
    node.elements
          ..forEach((element) => expressionInsertionPoints.add(element.end))
        //..forEach((element) => removalTargets.add)
        ;
    visitExpression(node);
  }

  @override
  void visitMethodDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!node.isCascaded) {
      expressions.add(node);
    }
    super.visitNode(node);
  }

  @override
  void visitMixinDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    //removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (!node.isCascaded) {
      expressions.add(node);
    }
    super.visitNode(node);
  }

  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    expressionInsertionPoints.add(node.leftBracket.end);
    node.elements
          ..forEach((element) => expressionInsertionPoints.add(element.end))
        //..forEach((element) => removalTargets.add)
        ;
    visitExpression(node);
  }

  @override
  void visitStatement(AstNode node) {
    statementInsertionPoints.add(node.end);
    if (_outermost) {
      outermostStatements.add(node);
    }

    removalTargets.add(node);
    final oldOutermost = _outermost;
    _outermost = false;
    super.visitNode(node);
    _outermost = oldOutermost;
  }

  @override
  void visitTopLevelVariableDeclaration(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitTypeAlias(AstNode node) {
    removalTargets.add(node);
    super.visitNode(node);
  }

  @override
  void visitTypeName(AstNode node) {
    typeNames.add(node);
    super.visitNode(node);
  }
}
