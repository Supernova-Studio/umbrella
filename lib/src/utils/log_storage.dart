enum LogLevel {
  debug,
  warning,
  error,
}

class LogEntry {
  final LogLevel level;
  final String message;

  const LogEntry(this.level, this.message);
}

class LogStorage {
  final List<LogEntry> _entries = [];

  bool get isNotEmpty {
    return _entries.isNotEmpty;
  }

  void add(LogLevel level, String message) {
    this._entries.add(LogEntry(level, message));
  }

  String assembleMessage(LogLevel level) {
    final levelsToAssemble = _logLevelsToAssemble(level);
    return this._entries.where((element) => levelsToAssemble.contains(element.level)).map((e) => e.message).join("\n");
  }

  void clear() {
    this._entries.clear();
  }

  List<LogLevel> _logLevelsToAssemble(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return const [LogLevel.debug, LogLevel.warning, LogLevel.error];
      case LogLevel.warning:
        return const [LogLevel.warning, LogLevel.error];
      case LogLevel.error:
        return const [LogLevel.error];
      default:
        throw ArgumentError("Unknown log level: ${level}");
    }
  }
}
