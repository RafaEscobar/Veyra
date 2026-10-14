import 'dart:collection';

import 'package:flutter/foundation.dart';

@immutable
final class DebugErrorEntry {
  const DebugErrorEntry({
    required this.occurredAt,
    required this.code,
    required this.errorType,
    required this.causeType,
    required this.operation,
    required this.diagnosticCode,
    required this.stackFrames,
  });

  final DateTime occurredAt;
  final String code;
  final String errorType;
  final String? causeType;
  final String? operation;
  final String? diagnosticCode;
  final List<String> stackFrames;
}

final class DebugErrorLog extends ChangeNotifier {
  DebugErrorLog._();

  static final DebugErrorLog instance = DebugErrorLog._();
  static const int _maximumEntries = 100;

  final List<DebugErrorEntry> _entries = <DebugErrorEntry>[];

  UnmodifiableListView<DebugErrorEntry> get entries =>
      UnmodifiableListView<DebugErrorEntry>(_entries);

  void add(DebugErrorEntry entry) {
    if (!kDebugMode) {
      return;
    }
    _entries.insert(0, entry);
    if (_entries.length > _maximumEntries) {
      _entries.removeRange(_maximumEntries, _entries.length);
    }
    notifyListeners();
  }

  void clear() {
    if (_entries.isEmpty) {
      return;
    }
    _entries.clear();
    notifyListeners();
  }
}
