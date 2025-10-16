#!/usr/bin/env dart
// ABOUTME: Script to analyze TODO items and detect dead code
// ABOUTME: Generates recommendations for TODO cleanup based on file usage analysis

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🔍 TODO Validation Analysis');
  print('=' * 80);

  // Get all TODOs from codebase
  final todos = await getTodos();
  print('\n📊 Found ${todos.length} TODO items\n');

  // Analyze each TODO
  final results = <TodoAnalysis>[];
  for (final todo in todos) {
    final analysis = await analyzeTodo(todo);
    results.add(analysis);
  }

  // Generate report
  generateReport(results);

  // Summary statistics
  printSummary(results);
}

class Todo {
  final String file;
  final int line;
  final String text;

  Todo(this.file, this.line, this.text);
}

class TodoAnalysis {
  final Todo todo;
  final int importCount;
  final int referenceCount;
  final double commentedPercentage;
  final bool isActiveCode;
  final String recommendation;
  final String reason;

  TodoAnalysis({
    required this.todo,
    required this.importCount,
    required this.referenceCount,
    required this.commentedPercentage,
    required this.isActiveCode,
    required this.recommendation,
    required this.reason,
  });
}

Future<List<Todo>> getTodos() async {
  final result = await Process.run(
    'grep',
    ['-rn', '--include=*.dart', 'TODO', 'lib/', 'test/'],
    workingDirectory: '/Users/rabble/code/andotherstuff/openvine/mobile',
  );

  final todos = <Todo>[];
  final lines = (result.stdout as String).split('\n');

  for (final line in lines) {
    if (line.isEmpty) continue;

    final match = RegExp(r'^([^:]+):(\d+):.*?TODO[:\s]*(.*)$').firstMatch(line);
    if (match != null) {
      final file = match.group(1)!;

      // Skip generated files
      if (_isGeneratedFile(file)) continue;

      todos.add(Todo(
        file,
        int.parse(match.group(2)!),
        match.group(3)!.trim(),
      ));
    }
  }

  return todos;
}

bool _isGeneratedFile(String filepath) {
  final basename = filepath.split('/').last;

  // Skip build directory
  if (filepath.contains('/build/')) return true;

  // Skip generated Dart files
  if (basename.endsWith('.g.dart')) return true;
  if (basename.endsWith('.freezed.dart')) return true;
  if (basename.endsWith('.mocks.dart')) return true;

  return false;
}

Future<TodoAnalysis> analyzeTodo(Todo todo) async {
  final file = todo.file;
  final basename = file.split('/').last;
  final classOrFile = basename.replaceAll('.dart', '');

  // Count imports
  final importCount = await countImports(basename);

  // Count references to classes/functions in file
  final referenceCount = await countReferences(file);

  // Calculate commented code percentage
  final commentedPercentage = await calculateCommentedPercentage(file);

  // Determine if code is active
  final isActiveCode = importCount > 0 || referenceCount > 0;

  // Generate recommendation
  final recommendation = generateRecommendation(
    importCount,
    referenceCount,
    commentedPercentage,
    todo.text,
  );

  final reason = generateReason(
    importCount,
    referenceCount,
    commentedPercentage,
    isActiveCode,
  );

  return TodoAnalysis(
    todo: todo,
    importCount: importCount,
    referenceCount: referenceCount,
    commentedPercentage: commentedPercentage,
    isActiveCode: isActiveCode,
    recommendation: recommendation,
    reason: reason,
  );
}

Future<int> countImports(String filename) async {
  final result = await Process.run(
    'bash',
    ['-c', 'grep -r "import.*$filename" lib/ test/ 2>/dev/null | wc -l'],
    workingDirectory: '/Users/rabble/code/andotherstuff/openvine/mobile',
  );

  return int.tryParse((result.stdout as String).trim()) ?? 0;
}

Future<int> countReferences(String filepath) async {
  // Extract class/function names from file
  final file = File('/Users/rabble/code/andotherstuff/openvine/mobile/$filepath');
  if (!file.existsSync()) return 0;

  final content = await file.readAsString();
  final classMatches = RegExp(r'class\s+(\w+)').allMatches(content);
  final functionMatches = RegExp(r'^\s*(?:Future<\w+>|void|String|int|bool|double)\s+(\w+)\(', multiLine: true).allMatches(content);

  var totalRefs = 0;

  // Count references to each class
  for (final match in classMatches) {
    final className = match.group(1)!;
    final refs = await countNameReferences(className);
    totalRefs += refs;
  }

  // Count references to top-level functions (limit to 5 to avoid too many queries)
  var funcCount = 0;
  for (final match in functionMatches) {
    if (funcCount++ > 5) break;
    final funcName = match.group(1)!;
    final refs = await countNameReferences(funcName);
    totalRefs += refs;
  }

  return totalRefs;
}

Future<int> countNameReferences(String name) async {
  final result = await Process.run(
    'bash',
    ['-c', 'grep -r "\\b$name\\b" lib/ test/ 2>/dev/null | wc -l'],
    workingDirectory: '/Users/rabble/code/andotherstuff/openvine/mobile',
  );

  return int.tryParse((result.stdout as String).trim()) ?? 0;
}

Future<double> calculateCommentedPercentage(String filepath) async {
  final file = File('/Users/rabble/code/andotherstuff/openvine/mobile/$filepath');
  if (!file.existsSync()) return 0.0;

  final lines = await file.readAsLines();
  if (lines.isEmpty) return 0.0;

  var commentedLines = 0;
  var totalLines = 0;

  for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;

    totalLines++;
    if (trimmed.startsWith('//')) {
      commentedLines++;
    }
  }

  return totalLines > 0 ? (commentedLines / totalLines) * 100 : 0.0;
}

String generateRecommendation(
  int imports,
  int references,
  double commentedPercentage,
  String todoText,
) {
  // File is mostly commented out
  if (commentedPercentage > 80) {
    return 'DELETE';
  }

  // File has no imports and very few references
  if (imports == 0 && references < 3) {
    return 'DELETE';
  }

  // Check for critical path keywords
  final lowerText = todoText.toLowerCase();
  if (lowerText.contains('implement') ||
      lowerText.contains('add') ||
      lowerText.contains('create') ||
      lowerText.contains('build')) {
    if (lowerText.contains('publish') ||
        lowerText.contains('hashtag') ||
        lowerText.contains('profile') ||
        lowerText.contains('notification')) {
      return 'CONVERT_TO_ISSUE';
    }
  }

  // Explanatory TODOs
  if (lowerText.contains('could be') ||
      lowerText.contains('might') ||
      lowerText.contains('consider') ||
      lowerText.contains('note:')) {
    return 'CONVERT_TO_COMMENT';
  }

  // Active code with clear work item
  if (imports > 2 && (lowerText.contains('implement') || lowerText.contains('add'))) {
    return 'CONVERT_TO_ISSUE';
  }

  // Default: keep as TODO for manual review
  return 'KEEP';
}

String generateReason(
  int imports,
  int references,
  double commentedPercentage,
  bool isActive,
) {
  final reasons = <String>[];

  if (commentedPercentage > 80) {
    reasons.add('File is ${commentedPercentage.toStringAsFixed(0)}% commented out');
  }

  if (imports == 0) {
    reasons.add('Zero imports found');
  } else {
    reasons.add('$imports import(s) found');
  }

  if (references == 0) {
    reasons.add('Zero references found');
  } else {
    reasons.add('$references reference(s) found');
  }

  if (!isActive) {
    reasons.add('Likely dead code');
  }

  return reasons.join(' | ');
}

void generateReport(List<TodoAnalysis> results) {
  print('\n📋 DETAILED ANALYSIS\n');

  final grouped = <String, List<TodoAnalysis>>{
    'DELETE': [],
    'CONVERT_TO_ISSUE': [],
    'CONVERT_TO_COMMENT': [],
    'KEEP': [],
  };

  for (final result in results) {
    grouped[result.recommendation]!.add(result);
  }

  for (final category in ['DELETE', 'CONVERT_TO_ISSUE', 'CONVERT_TO_COMMENT', 'KEEP']) {
    final items = grouped[category]!;
    if (items.isEmpty) continue;

    print('\n${'=' * 80}');
    print('$category (${items.length} items)');
    print('${'=' * 80}\n');

    for (final item in items) {
      print('TODO: ${item.todo.text}');
      print('File: ${item.todo.file}:${item.todo.line}');
      print('Imports: ${item.importCount} | References: ${item.referenceCount} | Commented: ${item.commentedPercentage.toStringAsFixed(0)}%');
      print('Reason: ${item.reason}');
      print('-' * 80);
    }
  }
}

void printSummary(List<TodoAnalysis> results) {
  print('\n\n📊 SUMMARY STATISTICS\n');

  final recommendations = <String, int>{};
  var totalActive = 0;
  var totalDead = 0;

  for (final result in results) {
    recommendations[result.recommendation] = (recommendations[result.recommendation] ?? 0) + 1;
    if (result.isActiveCode) {
      totalActive++;
    } else {
      totalDead++;
    }
  }

  print('Total TODOs: ${results.length}');
  print('Active Code: $totalActive');
  print('Likely Dead Code: $totalDead');
  print('');

  for (final entry in recommendations.entries) {
    final percentage = (entry.value / results.length * 100).toStringAsFixed(1);
    print('${entry.key.padRight(20)}: ${entry.value.toString().padLeft(3)} ($percentage%)');
  }

  print('\n${'=' * 80}');
  print('✅ Analysis complete! Review recommendations above.');
  print('${'=' * 80}\n');
}
