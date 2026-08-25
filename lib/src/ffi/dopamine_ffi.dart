import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

typedef StateJsonC = Pointer<Utf8> Function();
typedef StartJailbreakC = Int32 Function(Pointer<Utf8>);
typedef RunActionC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef ReadLogC = Int32 Function(Pointer<Utf8>, IntPtr);
typedef ReadLogDart = int Function(Pointer<Utf8>, int);
typedef FreeStringC = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

/// Dart FFI binding for the stable C ABI exposed by NativeBridge.mm.
class DopamineFfi {
  DopamineFfi._(this._lib)
      : _stateJson =
            _lib.lookupFunction<StateJsonC, StateJsonC>('dopamine_state_json'),
        _startJailbreak = _lib
            .lookupFunction<StartJailbreakC, StartJailbreakC>('dopamine_start_jailbreak'),
        _runAction = _lib.lookupFunction<RunActionC, RunActionC>('dopamine_run_action'),
        _readLogLine = _lib.lookupFunction<ReadLogC, ReadLogDart>('dopamine_read_log_line'),
        _freeString =
            _lib.lookupFunction<FreeStringC, FreeStringDart>('dopamine_free_string');

  factory DopamineFfi.instance() => _instance ??= DopamineFfi._(_open());

  static DopamineFfi? _instance;
  final DynamicLibrary _lib;
  final StateJsonC _stateJson;
  final StartJailbreakC _startJailbreak;
  final RunActionC _runAction;
  final ReadLogDart _readLogLine;
  final FreeStringDart _freeString;

  static DynamicLibrary _open() {
    if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
    throw UnsupportedError('Dopamine native bridge is only available on Apple platforms');
  }

  Map<String, dynamic> state() => _json(_takeNativeString(_stateJson()));

  bool startJailbreak({
    required bool removeJailbreak,
    required bool tweakInjection,
    required bool iDownload,
    required bool appJit,
    required bool verboseLogs,
    required double jetsamMultiplier,
  }) {
    final payload = jsonEncode({
      'removeJailbreak': removeJailbreak,
      'tweakInjection': tweakInjection,
      'iDownload': iDownload,
      'appJit': appJit,
      'verboseLogs': verboseLogs,
      'jetsamMultiplier': jetsamMultiplier / 2.0,
    });
    final ptr = payload.toNativeUtf8();
    try {
      return _startJailbreak(ptr) == 0;
    } finally {
      calloc.free(ptr);
    }
  }

  bool action(String action, {Map<String, dynamic>? arguments}) {
    final actionPtr = action.toNativeUtf8();
    final argPtr = jsonEncode(arguments ?? {}).toNativeUtf8();
    try {
      return _runAction(actionPtr, argPtr) == 0;
    } finally {
      calloc.free(actionPtr);
      calloc.free(argPtr);
    }
  }

  /// Returns one captured log line, or an empty string when drained.
  String nextLog() {
    final buf = calloc<Uint8>(8192);
    try {
      final length = _readLogLine(buf.cast(), buf.length);
      if (length <= 0) return '';
      return utf8.decode(buf.asSublist(0, length), allowMalformed: true).trimRight();
    } finally {
      calloc.free(buf);
    }
  }

  String _takeNativeString(Pointer<Utf8> pointer) {
    try {
      return pointer == nullptr ? '' : pointer.toDartString();
    } finally {
      if (pointer != nullptr) _freeString(pointer);
    }
  }

  Map<String, dynamic> _json(String source) {
    try {
      return jsonDecode(source.isEmpty ? '{}' : source) as Map<String, dynamic>;
    } catch (_) {
      return {'bridgeError': source};
    }
  }
}
