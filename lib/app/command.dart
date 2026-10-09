/// A ViewModel action as an object: it knows whether it is running, whether
/// it failed and whether it finished, so a screen can render those states
/// without its own flags.
///
/// Shaped after the command of the official Flutter architecture case study,
/// minus the `Result` type (the app has no such dependency): an action that
/// throws is recorded in [error] instead of escaping `execute`.
library;

import 'package:flutter/foundation.dart';

/// An action with no argument.
typedef CommandAction0<T> = Future<T> Function();

/// An action with one argument.
typedef CommandAction1<T, A> = Future<T> Function(A argument);

/// Shared state of a command. Listeners are told whenever [running], [error]
/// or [completed] change.
///
/// [execute] never runs the action twice at once: a call made while the
/// previous one is still [running] is ignored.
abstract class Command<T> extends ChangeNotifier {
  bool _running = false;
  bool _completed = false;
  Object? _error;
  StackTrace? _stackTrace;
  T? _value;
  bool _disposed = false;

  /// True from the moment the action starts until it finishes.
  bool get running => _running;

  /// True once the last run finished without throwing.
  bool get completed => _completed;

  /// What the last run threw, or null.
  Object? get error => _error;

  /// Stack trace of [error], or null.
  StackTrace? get stackTrace => _stackTrace;

  /// What the last successful run returned.
  T? get value => _value;

  /// Forgets the outcome of the last run. Does nothing while [running].
  void clearResult() {
    if (_running) return;
    if (!_completed && _error == null) return;
    _completed = false;
    _error = null;
    _stackTrace = null;
    _value = null;
    _notify();
  }

  Future<void> _run(Future<T> Function() action) async {
    if (_running) return;
    _running = true;
    _completed = false;
    _error = null;
    _stackTrace = null;
    _value = null;
    _notify();
    try {
      final result = await action();
      _value = result;
      _completed = true;
    } on Object catch (error, stackTrace) {
      _error = error;
      _stackTrace = stackTrace;
    } finally {
      _running = false;
      _notify();
    }
  }

  // The action may outlive its owner: a late finish must not notify a
  // disposed notifier.
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// A command whose action takes no argument.
class Command0<T> extends Command<T> {
  Command0(this._action);

  final CommandAction0<T> _action;

  /// Runs the action unless it is already running.
  Future<void> execute() => _run(_action);
}

/// A command whose action takes one argument of type [A].
class Command1<T, A> extends Command<T> {
  Command1(this._action);

  final CommandAction1<T, A> _action;

  /// Runs the action with [argument] unless it is already running.
  Future<void> execute(A argument) => _run(() => _action(argument));
}
