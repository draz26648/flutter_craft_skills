import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:yaml/yaml.dart';

const fields = <String, Set<String>>{
  'state': {'bloc', 'riverpod', 'provider', 'signals', 'setstate'},
  'models': {'freezed', 'dart_mappable', 'json_serializable', 'manual'},
  'structure': {'feature_first', 'layer_first'},
  'di': {'get_it', 'injectable', 'riverpod', 'provider', 'none'},
  'routing': {'go_router', 'auto_route', 'navigator'},
  'tokens': {'theme_extension', 'theme_only', 'constants', 'none'},
  'l10n': {'arb', 'easy_localization', 'slang', 'none'},
  'strictness': {'block', 'warn'},
};

Map<String, Object> profile(String source) {
  final value = loadYaml(source);
  if (value == null) return {};
  if (value is! YamlMap)
    throw FormatException('profile must be a YAML mapping');
  final result = <String, Object>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key == 'locales') {
      if (entry.value is! YamlList) {
        throw FormatException('profile: locales must be a list');
      }
      final locales = <String>[];
      for (final locale in entry.value as YamlList) {
        if (locale is! String ||
            !RegExp(
              r'^[a-zA-Z]{2,3}([_-][a-zA-Z0-9]{2,8})*$',
            ).hasMatch(locale)) {
          throw FormatException('profile: invalid locale $locale');
        }
        locales.add(locale);
      }
      result['locales'] = locales;
    } else if (key is! String || !fields.containsKey(key)) {
      throw FormatException('profile: unknown field $key');
    } else if (entry.value is! String || !fields[key]!.contains(entry.value)) {
      throw FormatException(
        'profile: $key: ${entry.value} is not a recognised value',
      );
    } else {
      result[key] = entry.value as String;
    }
  }
  return result;
}

class Finding {
  Finding(this.rule, this.line, this.detail);
  final String rule;
  final int line;
  final String detail;
}

List<Finding> inspect(String source, String path) {
  final parsed = parseString(
    content: source,
    path: path,
    throwIfDiagnostics: false,
  );
  if (parsed.errors.isNotEmpty) {
    throw FormatException('Cannot parse $path: ${parsed.errors.first.message}');
  }
  final findings = <Finding>[];
  parsed.unit.accept(
    _Visitor((rule, node, detail) {
      findings.add(
        Finding(
          rule,
          parsed.lineInfo.getLocation(node.offset).lineNumber,
          detail,
        ),
      );
    }),
  );
  return findings;
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor(this.add);
  final void Function(String, AstNode, String) add;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final parts = node.constructorName.type.toSource().split('.');
    var type = parts.last;
    var ctor = node.constructorName.name?.name ?? '';
    // Without resolution, const EdgeInsets.only may parse as a prefixed type.
    if (ctor.isEmpty && parts.length > 1 && RegExp(r'^[a-z]').hasMatch(type)) {
      ctor = parts.removeLast();
      type = parts.last;
    }
    _call(node, type, ctor, node.argumentList.arguments);
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final target = node.target?.toSource();
    final type = target == null ? node.methodName.name : target.split('.').last;
    final ctor = target == null ? '' : node.methodName.name;
    _call(node, type, ctor, node.argumentList.arguments);
    super.visitMethodInvocation(node);
  }

  void _call(
    AstNode node,
    String type,
    String ctor,
    Iterable<Expression> args,
  ) {
    bool numeric(Expression arg) {
      final value = arg is NamedExpression ? arg.expression : arg;
      return value is IntegerLiteral ||
          value is DoubleLiteral ||
          (value is PrefixExpression &&
              (value.operand is IntegerLiteral ||
                  value.operand is DoubleLiteral));
    }

    if (type == 'Color' && args.any(numeric))
      add('colors', node, node.toSource());
    if ((type == 'EdgeInsets' || type == 'EdgeInsetsDirectional') &&
        args.any(numeric)) {
      add('insets', node, node.toSource());
    }
    if (type == 'EdgeInsets' &&
        (ctor == 'fromLTRB' ||
            args.whereType<NamedExpression>().any(
              (a) => {'left', 'right'}.contains(a.name.label.name),
            ))) {
      add('rtl', node, node.toSource());
    }
    if (type == 'BorderRadius' && ctor == 'circular' && args.any(numeric)) {
      add('radius', node, node.toSource());
    }
    if (type == 'TextStyle') add('style', node, node.toSource());
    if (type == 'Text' && args.isNotEmpty && args.first is StringLiteral) {
      add('strings', node, node.toSource());
    }
    if (ctor == 'asset' && args.isNotEmpty && args.first is StringLiteral) {
      final asset = (args.first as StringLiteral).stringValue;
      final external = args.whereType<NamedExpression>().any(
        (a) => a.name.label.name == 'package',
      );
      if (asset != null &&
          !external &&
          !asset.startsWith('packages/') &&
          !File(asset).existsSync()) {
        add('asset', node, asset);
      }
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    if (node.prefix.name == 'Colors' && node.identifier.name != 'transparent') {
      add('colors', node, 'literal Colors.${node.identifier.name}');
    }
    super.visitPrefixedIdentifier(node);
  }
}
