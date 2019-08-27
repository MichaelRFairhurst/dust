import 'dart:convert';
import 'dart:math';

var random = Random();

const kClasses = 'classes';
const kMethods = 'methods';
const kFields = 'fields';
const kReturnType = 'returnType';
const kType = 'type';
const kRequiredType = 'requiredType';
const kIsFinal = 'isFinal';
const kIsStatic = 'isStatic';
const kParameters = 'parameters';
const kInitializer = 'initializer';
const kKind = 'kind';
const kExp = 'exp';
const kExpStmt = 'expStmt';
const kBinary = 'binary';
const kBasicLiteral = 'basicLiteral';
const kLexeme = 'lexeme';
const kStmts = 'stmt';
const kImplicitType = 'implicitType';
const kTopLevelRef = 'topLevelRef';
const kIndex = 'index';
const kClassIndex = 'classIndex';
const kMain = 'main';
const kLhs = 'lhs';
const kRhs = 'rhs';
const kOperator = 'operator';
const kCtor = 'ctor';
const kTopLevelMethod = 'topLevelMethod';
const kClassMethod = 'classMethod';
const kMethodCall = 'methodCall';
const kFieldRef = 'fieldRef';
const kPropertyAccess = 'propertyAccess';
const kReturn = 'return';
const kIf = 'if';
const kWhile = 'while';
const kDoWhile = 'doWhile';
const kFor = 'for';
const kCond = 'cond';
const kThen = 'then';
const kElse = 'else';
const kInit = 'init';
const kUpdate = 'update';
const kBaseType = 'baseType';
const kClassType = 'classType';
const kTarget = 'target';
const kThrow = 'throw';
const kAssign = 'assign';
const kLvalue = 'lvalue';
//const kMixins = 'mixins';
//const kTypedefs = 'typedefs';
//const kEnums = 'enums';
//const kExtensions = 'extensions';

const emptyProgram = {
  kClasses: [],
  kFields: [],
  kMethods: [],
  kMain: {
    kReturnType: voidType,
    kParameters: [],
    kStmts: [],
    kIsStatic: false,
  }
//  kMixins: [],
//  kTypedefs: [],
//  kEnums: [],
//  kExtensions: [],
};

const boolType = {kKind: kBaseType, kLexeme: 'bool'};
const intType = {kKind: kBaseType, kLexeme: 'int'};
const stringType = {kKind: kBaseType, kLexeme: 'String'};
const doubleType = {kKind: kBaseType, kLexeme: 'double'};
const numType = {kKind: kBaseType, kLexeme: 'num'};
const voidType = {kKind: kBaseType, kLexeme: 'void'};
const nullType = {kKind: kBaseType, kLexeme: 'Null'};
const dynamicType = {kKind: kBaseType, kLexeme: 'dynamic'};
const objectType = {kKind: kBaseType, kLexeme: 'Object'};

class SemanticallyValidJsonAstMutator {
  final String str;
  final Map ast;

  SemanticallyValidJsonAstMutator(this.str)
      : ast = str == '' ? emptyProgram : jsonDecode(str);

  String run() {
    while (true) {
      try {
        if (ast != emptyProgram) mutateAst();
        break;
      } on HitNoOptionsException catch (e) {
        // rerun on new AST (since we may have mutated the original)
        return SemanticallyValidJsonAstMutator(str).run();
      }
    }
    return jsonEncode(ast);
  }

  void mutateAst() => doOneOf([
        addClass,
        () => addField(ast[kFields], allowStatic: false),
        () => addStmt(ast[kMain][kStmts], null, ast[kMain][kReturnType]),
        ...methodMutations(ast[kMethods], null, allowStatic: false),
        for (final class_ in ast[kClasses]) ...classMutations(class_),
      ]);

  void addClass() {
    ast[kClasses].add({kMethods: [], kFields: []});
  }

  List<void Function()> classMutations(Map class_) => [
        () => addField(class_[kFields]),
        ...methodMutations(class_[kMethods], class_),
      ];

  List<void Function()> methodMutations(List methods, Map class_,
          {bool allowStatic = false}) =>
      [
        () => addMethod(methods, allowStatic: allowStatic),
        for (var i = 0; i < methods.length; ++i) ...[
          () => changeReturnType(methods[i], class_, i),
          () => addParameter(methods[i], class_, i),
          ...[
            ...stmtMutations(
                methods[i][kStmts], class_, methods[i][kReturnType]),
            ...expMutations(
                methods[i][kStmts], class_, methods[i][kReturnType]),
          ]
        ]
      ];

  void addParameter(Map method, Map class_, dynamic index) {
    final newType = genType();
    method[kParameters].add(newType);

    final searchKind = class_ == null ? kTopLevelMethod : kClassMethod;

    void fixCalls(List root, Map nodeClass_) {
      walkList(root, (node) {
        if (node[kKind] == searchKind ||
            (node[kKind] == kMethodCall &&
                ast[kClasses][node[kClassIndex]] == class_)) {
          if (node[kIndex] == index) {
            fixCalls(node[kParameters], nodeClass_);
            node[kParameters].add(genExp(newType, nodeClass_));
            return false;
          }
        }
        return true;
      });
    }

    fixCalls(ast[kMain][kStmts], null);
    for (final method in ast[kMethods]) {
      fixCalls(method[kStmts], null);
    }
    for (final field in ast[kFields]) {
      fixCalls([field[kInitializer]], null);
    }
    for (final class_ in ast[kClasses]) {
      for (final method in class_[kMethods]) {
        fixCalls(method[kStmts], null);
      }
      for (final field in class_[kFields]) {
        fixCalls([field[kInitializer]], null);
      }
    }
  }

  void changeReturnType(Map method, Map class_, dynamic index) {
    final wasVoid = isVoid(method[kReturnType]);
    final newType = genType();
    method[kReturnType] = newType;
    fixReturns(method[kStmts], class_, newType);

    if (wasVoid) {
      method[kStmts].add(genReturnStmt(class_, newType));
    }

    final searchKind = class_ == null ? kTopLevelMethod : kClassMethod;

    void fixCalls(List root, Map nodeClass_, bool exact) {
      walkList(root, (node) {
        if (node[kKind] == searchKind ||
            (node[kKind] == kMethodCall &&
                ast[kClasses][node[kClassIndex]] == class_)) {
          if (node[kIndex] == index) {
            node[kType] = newType;
            if (!assignable(newType, node[kRequiredType], exact,
                allowDowncast:
                    node[kKind] != kBasicLiteral && node[kKind] != kCtor)) {
              rewrite(
                  node,
                  genExp(node[kRequiredType], null,
                      exact: node[kKind] == kBasicLiteral ||
                          node[kKind] == kCtor ||
                          exact));
            }
          }
        }
        return true;
      });
    }

    fixCalls(ast[kMain][kStmts], null, isVoid(ast[kMain][kReturnType]));
    for (final method in ast[kMethods]) {
      fixCalls(method[kStmts], null, isVoid(method[kReturnType]));
    }
    for (final field in ast[kFields]) {
      fixCalls([field[kInitializer]], null, field[kImplicitType]);
    }
    for (final class_ in ast[kClasses]) {
      for (final method in class_[kMethods]) {
        fixCalls(method[kStmts], null, isVoid(method[kReturnType]));
      }
      for (final field in class_[kFields]) {
        fixCalls([field[kInitializer]], null, field[kImplicitType]);
      }
    }
  }

  void fixReturns(List stmts, Map class_, Map returnType) {
    for (var i = 0; i < stmts.length; ++i) {
      final stmt = stmts[i];
      switch (stmt[kKind]) {
        case kReturn:
          if (stmt[kExp] == null) {
            if (!isVoid(returnType)) {
              // Change `return;' to `return foo;`
              stmt[kExp] = genExp(returnType, class_);
            }
          } else {
            stmt[kExp][kRequiredType] = returnType;
            if (!assignable(
                stmt[kExp][kType], returnType, isVoid(returnType))) {
              // Change `return incompat;` to `incompat; return foo;`
              stmt[kKind] = kExpStmt;
              stmts.insert(i, genReturnStmt(class_, returnType));
              i++;
            }
          }
          break;
        case kIf:
          fixReturns(stmt[kThen], class_, returnType);
          fixReturns(stmt[kElse], class_, returnType);
          break;
        case kWhile:
          fixReturns(stmt[kStmts], class_, returnType);
          break;
        case kDoWhile:
          fixReturns(stmt[kStmts], class_, returnType);
          break;
        case kFor:
          fixReturns(stmt[kStmts], class_, returnType);
          break;
      }
    }
  }

  List<void Function()> stmtMutations(List stmts, Map class_, Map returnType) =>
      [
        () => addStmt(stmts, class_, returnType),
        for (final stmt in stmts)
          if (stmt[kKind] == kIf) ...[
            ...stmtMutations(stmt[kThen], class_, returnType),
            ...stmtMutations(stmt[kElse], class_, returnType)
          ] else if (stmt[kKind] == kWhile ||
              stmt[kKind] == kDoWhile ||
              stmt[kKind] == kFor)
            ...stmtMutations(stmt[kStmts], class_, returnType)
      ];

  void addMethod(List dest, {bool allowStatic = true}) =>
      dest.add(genMethod(allowStatic: allowStatic));

  Map genMethod({bool allowStatic = true}) => {
        kReturnType: voidType, // always begin void, can change later.
        kIsStatic: allowStatic && random.nextBool(),
        kParameters: [],
        kStmts: [],
      };

  void addField(List dest, {bool allowStatic = true}) =>
      dest.add(genField(allowStatic: allowStatic));

  Map genField({bool allowStatic = true}) {
    final type = genType();
    final isFinal = random.nextBool();
    final isStatic = allowStatic && random.nextBool();
    final initializer = isFinal || isStatic ? genExp(type, null) : null;
    final implicitType =
        initializer != null && initializer[kType] == type && random.nextBool();
    return {
      kType: type,
      kIsFinal: isFinal,
      kIsStatic: isStatic,
      kInitializer: initializer,
      kImplicitType: implicitType
    };
  }

  void addStmt(List dest, Map class_, Map returnType) {
    dest.insert(dest.length == 0 ? 0 : random.nextInt(dest.length),
        genStmt(class_, returnType));
  }

  List<void Function()> expMutations(List stmts, Map class_, Map returnType) {
    final exps = <Map>[];
    walkList(stmts, (node) {
      if (node[kKind] == kBinary ||
          node[kKind] == kAssign ||
          node[kKind] == kClassMethod ||
          node[kKind] == kTopLevelRef ||
          node[kKind] == kTopLevelMethod ||
          node[kKind] == kMethodCall ||
          node[kKind] == kPropertyAccess ||
          node[kKind] == kBasicLiteral ||
          node[kKind] == kThrow) {
        if (node[kLvalue] != true) {
          exps.add(node);
        }
      }
      return true;
    });

    return [
      for (final exp in exps)
        () {
          rewrite(
              exp,
              genExp(exp[kRequiredType], class_,
                  exact: exactType(exp[kRequiredType], exp[kType])));
        }
    ];
  }

  Map genStmt(Map class_, Map returnType) => doOneOf([
        () => genExpStmt(class_),
        () => genReturnStmt(class_, returnType),
        () => genIfStmt(class_),
        () => genWhileStmt(class_),
        () => genDoWhileStmt(class_),
        () => genForStmt(class_),
      ]);

  Map genExpStmt(Map class_) => {
        kKind: kExpStmt,
        kExp: genExp(voidType, class_),
      };

  Map genReturnStmt(Map class_, Map returnType) => {
        kKind: kReturn,
        kExp: isVoid(returnType) && random.nextBool()
            ? null
            : genExp(returnType, class_, exact: isVoid(returnType)),
      };

  Map genIfStmt(Map class_) => {
        kKind: kIf,
        kCond: genExp(boolType, class_),
        kThen: [],
        kElse: [],
      };

  Map genWhileStmt(Map class_) => {
        kKind: kWhile,
        kCond: genExp(boolType, class_),
        kStmts: [],
      };

  Map genDoWhileStmt(Map class_) => {
        kKind: kDoWhile,
        kCond: genExp(boolType, class_),
        kStmts: [],
      };

  Map genForStmt(Map class_) => {
        kKind: kFor,
        kInit: null,
        kCond: null,
        kUpdate: [],
        kStmts: [],
      };

  Map genExp(Map type, Map class_, {bool exact = false}) => doOneOf([
        ...terminalExpGenerators(type, class_, exact: exact),
        ...binExpGenerators(type, class_, exact: exact),
        ...ctorExpGenerators(type, exact: exact),
        ...methodExpGenerators(type, class_, exact: exact),
        ...propertyExpGenerators(type, class_, exact: exact),
        ...assignmentExpGenerators(type, class_, exact: exact),
      ]);

  Map genTerminalExp(Map type, Map class_, {bool exact = false}) =>
      doOneOf(terminalExpGenerators(type, class_, exact: exact));

  List<Map Function()> terminalExpGenerators(Map type, Map class_,
      {bool exact = false}) {
    final classFields = class_ == null ? [] : class_[kFields];
    return [
      // Careful: literals cannot be downcast.
      if (assignable(nullType, type, exact, allowDowncast: false))
        () => genNullLiteral(type),
      if (assignable(boolType, type, exact, allowDowncast: false))
        () => genBoolLiteral(type),
      if (assignable(intType, type, exact, allowDowncast: false))
        () => genIntLiteral(type),
      if (assignable(stringType, type, exact, allowDowncast: false))
        () => genStringLiteral(type),
      if (assignable(doubleType, type, exact, allowDowncast: false))
        () => genDoubleLiteral(type),
      // But references are terminals which can be downcast.
      for (var f = 0; f < ast[kFields].length; f++)
        if (assignable(ast[kFields][f][kType], type, exact))
          () => genTopLevelRef(f, type),
      for (var f = 0; f < classFields.length; f++)
        if (assignable(classFields[f][kType], type, exact))
          () => genFieldRef(f, classFields, type),
      // TODO: enable
      if (false)
        () => genThrowExp(type),
    ];
  }

  List<Map Function()> assignmentExpGenerators(Map type, Map class_,
          {bool exact = false}) =>
      [
        for (final supertype in superTypes(type))
          for (final assignableExp
              in assignableExpGenerators(supertype, class_, exact: true))
            () {
              final lhs = assignableExp();
              lhs[kLvalue] = true;
              final rhs =
                  genTerminalExp(type ?? lhs[kType], class_, exact: exact);
              return {
                kKind: kAssign,
                kRequiredType: type,
                kType: rhs[kType],
                kOperator: '=',
                kLhs: lhs,
                kRhs: rhs,
              };
            }
      ];

  List<Map Function()> assignableExpGenerators(Map type, Map class_,
      {bool exact = false}) {
    final classFields = class_ == null ? [] : class_[kFields];
    return [
      for (var f = 0; f < ast[kFields].length; f++)
        if (!ast[kFields][f][kIsFinal])
          if (assignable(ast[kFields][f][kType], type, exact))
            () => genTopLevelRef(f, type),
      for (var f = 0; f < classFields.length; f++)
        if (!classFields[f][kIsFinal])
          if (assignable(classFields[f][kType], type, exact))
            () => genFieldRef(f, classFields, type),
    ];
  }

  List<Map Function()> ctorExpGenerators(Map type, {bool exact = false}) => [
        if (assignable(objectType, type, exact, allowDowncast: false))
          () => {
                kKind: kCtor,
                kIndex: -1,
                kParameters: [],
                kType: objectType,
                kRequiredType: type
              },
        for (int i = 0; i < ast[kClasses].length; ++i)
          if (assignable({kKind: kClassType, kIndex: i}, type, exact,
              allowDowncast: false))
            () => {
                  kKind: kCtor,
                  kIndex: i,
                  kParameters: [],
                  kType: classType(i),
                  kRequiredType: type
                }
      ];

  List<Map Function()> methodExpGenerators(Map type, Map class_,
      {bool exact = false}) {
    final classMethods = class_ == null ? [] : class_[kMethods];
    return [
      if (assignable(ast[kMain][kReturnType], type, exact))
        () => genTopLevelMethodExp(ast[kMain], 'main', type, class_),
      for (int i = 0; i < ast[kMethods].length; ++i)
        if (assignable(ast[kMethods][i][kReturnType], type, exact))
          () => genTopLevelMethodExp(ast[kMethods][i], i, type, class_),
      for (int i = 0; i < classMethods.length; ++i)
        if (assignable(classMethods[i][kReturnType], type, exact))
          () => genClassMethodExp(classMethods[i], i, type, class_),
      for (int i = 0; i < ast[kClasses].length; ++i)
        for (int j = 0; j < ast[kClasses][i][kMethods].length; ++j)
          if (assignable(
              ast[kClasses][i][kMethods][j][kReturnType], type, exact))
            () => genMethodCall(
                ast[kClasses][i][kMethods][j], i, j, type, class_),
    ];
  }

  Map genClassMethodExp(Map method, int index, Map requiredType, Map class_) =>
      {
        kType: method[kReturnType],
        kRequiredType: requiredType,
        kKind: kClassMethod,
        kIndex: index,
        kParameters: [
          for (final param in method[kParameters]) genExp(param, class_)
        ],
      };

  Map genMethodCall(Map method, int classIndex, int methodIndex,
          Map requiredType, Map class_) =>
      {
        kType: method[kReturnType],
        kRequiredType: requiredType,
        kKind: kMethodCall,
        kIndex: methodIndex,
        kClassIndex: classIndex,
        kTarget: genExp(classType(classIndex), class_, exact: true),
        kParameters: [
          for (final param in method[kParameters]) genExp(param, class_)
        ],
      };

  Map genTopLevelMethodExp(
          Map method, dynamic index, Map requiredType, Map class_) =>
      {
        kType: method[kReturnType],
        kRequiredType: requiredType,
        kKind: kTopLevelMethod,
        kIndex: index,
        kParameters: [
          for (final param in method[kParameters]) genExp(param, class_)
        ],
      };

  List<Map Function()> propertyExpGenerators(Map type, Map class_,
          {bool exact = false}) =>
      [
        for (int i = 0; i < ast[kClasses].length; ++i)
          for (int j = 0; j < ast[kClasses][i][kFields].length; ++j)
            if (!ast[kClasses][i][kFields][j][kIsStatic] &&
                assignable(ast[kClasses][i][kFields][j][kType], type, exact))
              () => genPropertyAccess(
                  ast[kClasses][i][kFields][j], i, j, type, class_),
      ];

  Map genPropertyAccess(Map method, int classIndex, int fieldIndex,
          Map requiredType, Map class_) =>
      {
        kType: method[kReturnType],
        kRequiredType: requiredType,
        kKind: kPropertyAccess,
        kIndex: fieldIndex,
        kClassIndex: classIndex,
        kTarget: genExp(classType(classIndex), class_, exact: true),
      };

  Map genTopLevelRef(int index, Map requiredType) => {
        kType: ast[kFields][index][kType],
        kRequiredType: requiredType,
        kKind: kTopLevelRef,
        kIndex: index,
      };

  Map genFieldRef(int index, List classFields, Map requiredType) => {
        kType: classFields[index][kType],
        kRequiredType: requiredType,
        kKind: kFieldRef,
        kIndex: index,
      };

  static const typedBinOperators = [
    ['&&', boolType, boolType, boolType],
    ['||', boolType, boolType, boolType],
    ['&', boolType, boolType, boolType],
    ['|', boolType, boolType, boolType],
    ['>', intType, numType, boolType],
    ['>', doubleType, numType, boolType],
    ['>=', intType, numType, boolType],
    ['>=', doubleType, numType, boolType],
    ['<', intType, numType, boolType],
    ['<', doubleType, numType, boolType],
    ['<=', intType, numType, boolType],
    ['<=', doubleType, numType, boolType],
    ['>>', intType, intType, intType],
    //['>>>', intType, intType, intType],
    ['<<', intType, intType, intType],
    ['^', boolType, boolType, boolType],
    ['+', intType, intType, intType],
    ['+', numType, numType, numType],
    ['+', doubleType, doubleType, doubleType],
    ['+', stringType, stringType, stringType],
    ['-', numType, numType, numType],
    ['-', doubleType, doubleType, doubleType],
    ['*', intType, intType, intType],
    ['*', numType, numType, numType],
    ['*', doubleType, doubleType, doubleType],
    ['*', stringType, intType, stringType],
    ['/', numType, numType, doubleType],
    ['%', intType, intType, intType],
    ['%', numType, numType, numType],
    ['%', doubleType, doubleType, doubleType],
  ];

  List<Map Function()> binExpGenerators(Map type, Map class_,
          {bool exact = false}) =>
      [
        if (!isVoid(type))
          () => {
                kType: type,
                kRequiredType: type,
                kKind: kBinary,
                kOperator: '??',
                // TODO: generate non-exact types that still satisfy the type
                kLhs: genTerminalExp(type, class_, exact: true),
                kRhs: genTerminalExp(type, class_, exact: true),
              },
        if (assignable(boolType, type, exact))
          () => {
                kType: boolType,
                kRequiredType: type,
                kKind: kBinary,
                kOperator: '==',
                kLhs: genTerminalExp(genType(allowVoid: false), class_),
                kRhs: genTerminalExp(genType(allowVoid: false), class_),
              },
        for (final op in typedBinOperators)
          if (assignable(op[3], type, exact))
            () => {
                  kType: op[3],
                  kRequiredType: type,
                  kKind: kBinary,
                  kOperator: op[0],
                  kLhs: genTerminalExp(op[1], class_, exact: true),
                  kRhs: genTerminalExp(op[2], class_),
                }
      ];

  Map genThrowExp(Map requiredType) => {
        kType: nullType,
        kRequiredType: requiredType,
        kKind: kThrow,
        kExp: genExp(genType(), null),
      };

  Map genNullLiteral(Map requiredType) => {
        kType: nullType,
        kRequiredType: requiredType,
        kKind: kBasicLiteral,
        kLexeme: 'null',
      };

  Map genIntLiteral(Map requiredType) => {
        kType: intType,
        kRequiredType: requiredType,
        kKind: kBasicLiteral,
        kLexeme: (random.nextInt(1000)).toString(),
      };

  Map genDoubleLiteral(Map requiredType) => {
        kType: doubleType,
        kRequiredType: requiredType,
        kKind: kBasicLiteral,
        kLexeme: (random.nextDouble() * random.nextInt(1000)).toString(),
      };

  Map genBoolLiteral(Map requiredType) => {
        kType: boolType,
        kRequiredType: requiredType,
        kKind: kBasicLiteral,
        kLexeme: random.nextBool() ? 'true' : 'false',
      };

  Map genStringLiteral(Map requiredType) {
    final quoteType = random.nextBool() ? '"' : "'";
    final contents = 'asdf' * random.nextInt(10);
    return {
      kType: stringType,
      kRequiredType: requiredType,
      kKind: kBasicLiteral,
      kLexeme: '$quoteType$contents$quoteType',
    };
  }

  static const nonVoidTypes = [
    boolType,
    intType,
    stringType,
    doubleType,
    numType,
    voidType,
    nullType,
    dynamicType,
    objectType,
  ];

  List<Map> superTypes(Map type) => [
        type,
        if (!isVoid(type)) objectType,
        if (!isVoid(type)) dynamicType,
        voidType,
        if (exactType(intType, type)) numType,
        if (exactType(doubleType, type)) numType,
      ];

  Map genType({bool allowVoid = true}) => oneOf([
        ...nonVoidTypes,
        if (allowVoid) voidType,
        for (int i = 0; i < ast[kClasses].length; ++i) classType(i),
      ]);

  bool exactType(Map typeA, Map typeB) =>
      typeA[kKind] == typeB[kKind] &&
      typeA[kLexeme] == typeB[kLexeme] &&
      typeA[kIndex] == typeB[kIndex];

  bool assignable(Map typeA, Map typeB, bool exact,
      {bool allowDowncast = true}) {
    if (exact) {
      return exactType(typeA, typeB);
    }

    if (isVoid(typeA) && !isVoid(typeB)) {
      // void is special. This is not strictly true, but in practice its almost
      // true.
      return false;
    }

    if (isBaseType(typeB, 'Object') ||
        isBaseType(typeB, 'dynamic') ||
        isBaseType(typeB, 'void')) {
      return true;
    }

    if (isBaseType(typeA, 'Null')) {
      return true;
    }

    if (isBaseType(typeB, 'num') &&
        (isBaseType(typeA, 'int') || isBaseType(typeA, 'double'))) {
      return true;
    }

    if (typeA[kKind] != typeB[kKind]) {
      return false;
    }

    if (typeA[kKind] == kBaseType) {
      return typeA[kLexeme] == typeB[kLexeme] ||
          (allowDowncast &&
              assignable(typeB, typeA, false, allowDowncast: false));
    }

    if (typeA[kKind] == kClassType) {
      return typeA[kIndex] == typeB[kIndex] ||
          (allowDowncast &&
              assignable(typeB, typeA, false, allowDowncast: false));
    }

    throw 'unexpected values $typeA $typeB';
  }

  bool isVoid(Map type) => isBaseType(type, voidType[kLexeme]);

  bool isBaseType(Map type, String lexeme) =>
      type[kKind] == kBaseType && type[kLexeme] == lexeme;

  Map classType(int index) => {kKind: kClassType, kIndex: index};
}

T doOneOf<T>(List<T Function()> fns) => oneOf(fns)();

T oneOf<T>(List<T> options) {
  if (options.isEmpty) {
    throw new HitNoOptionsException();
  }
  return options[random.nextInt(options.length)];
}

class HitNoOptionsException implements Exception {}

void walkList(List nodes, bool Function(Map) handler) {
  if (nodes == null) {
    return;
  }
  for (final node in nodes) {
    walk(node, handler);
  }
}

void walk(Map node, bool Function(Map) handler) {
  if (node == null) {
    return;
  }
  if (!handler(node)) {
    return;
  }
  switch (node[kKind]) {
    case kThrow:
      walk(node[kExp], handler);
      break;
    case kBinary:
      walk(node[kLhs], handler);
      walk(node[kRhs], handler);
      break;
    case kAssign:
      walk(node[kLhs], handler);
      walk(node[kRhs], handler);
      break;
    case kTopLevelMethod:
      walkList(node[kParameters], handler);
      break;
    case kMethodCall:
      walk(node[kTarget], handler);
      walkList(node[kParameters], handler);
      break;
    case kClassMethod:
      walkList(node[kParameters], handler);
      break;
    case kPropertyAccess:
      walk(node[kTarget], handler);
      break;
    case kExpStmt:
      walk(node[kExp], handler);
      break;
    case kReturn:
      walk(node[kExp], handler);
      break;
    case kIf:
      walk(node[kCond], handler);
      walkList(node[kThen], handler);
      walkList(node[kElse], handler);
      break;
    case kWhile:
      walk(node[kCond], handler);
      walkList(node[kStmts], handler);
      break;
    case kDoWhile:
      walk(node[kCond], handler);
      walkList(node[kStmts], handler);
      break;
    case kFor:
      walk(node[kCond], handler);
      walk(node[kInit], handler);
      walkList(node[kUpdate], handler);
      walkList(node[kStmts], handler);
      break;
    // deliberately empty:
    case kFieldRef:
      break;
    case kTopLevelRef:
      break;
    case kBasicLiteral:
      break;
    case kCtor:
      break;
    default:
      throw 'unhandled ${node[kKind]} / $node';
  }
}

void rewrite(Map node, Map replacement) {
  node.clear();
  replacement.entries.forEach((entry) => node[entry.key] = entry.value);
}
