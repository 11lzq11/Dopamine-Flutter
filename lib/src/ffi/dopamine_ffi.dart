import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

typedef StateJsonC = Pointer<Utf8> Function();
typedef StateJsonDart = Pointer<Utf8> Function();

typedef StartJailbreakC = Int32 Function(Pointer<Utf8>);
typedef StartJailbreakDart = int Function(Pointer<Utf8>);

typedef RunActionC = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef RunActionDart = int Function(Pointer<Utf8>, Pointer<Utf8>);

typedef ReadLogC = Int32 Function(Pointer<Uint8>, IntPtr);
typedef ReadLogDart = int Function(Pointer<Uint8>, int);

typedef FreeStringC = Void Function(Pointer<Utf8>);
typedef FreeStringDart = void Function(Pointer<Utf8>);

/// Dart FFI binding for the stable C ABI exposed by NativeBridge.mm.
class DopamineFfi {
  DopamineFfi._(DynamicLibrary library)
      : _stateJson = library
            .lookupFunction<StateJsonC, StateJsonDart>('dopamine_state_json'),
        _startJailbreak = library.lookupFunction<StartJailbreakC, StartJailbreakDart>(
            'dopamine_start_jailbreak'),
        _runAction =
            library.lookupFunction<RunActionC, RunActionDart>('dopamine_run_action'),
        _readLogLine =
            library.lookupFunction<ReadLogC, ReadLogDart>('dopamine_read_log_line'),
        _freeString =
            library.lookupFunction<FreeStringC, FreeStringDart>('dopamine_free_string');

  factory DopamineFfi.instance() => _instance ??= DopamineFfi._(_openLibrary());

  static DopamineFfi? _instance;
  final StateJsonDart _stateJson;
  final StartJailbreakDart _startJailbreak;
  final RunActionDart _runAction;
  final ReadLogDart _readLogLine;
  final FreeStringDart _freeString;

  static DynamicLibrary _openLibrary() {
    if (Platform.isIOS || Platform.isMacOS) return DynamicLibrary.process();
    throw UnsupportedError('Dopamine native bridge is only available on Apple platforms');
  }

  Map<String, dynamic> state() => _decodeJson(_takeNativeString(_stateJson()));

  bool startJailbreak({
    required bool removeJailbreak,
    required bool tweakInjection,
    required bool iDownload,
    required bool appJit,
    required bool verboseLogs,
    required double jetsamMultiplier,
  }) {
    final payload = jsonEncode(<String, dynamic>{
      'removeJailbreak': removeJailbreak,
      'tweakInjection': tweakInjection,
      'iDownload': iDownload,
      'appJit': appJit,
      'verboseLogs': verboseLogs,
      'jetsamMultiplier': jetsamMultiplier / 2.0,
    });
    final pointer = payload.toNativeUtf8();
    try {
      return _startJailbreak(pointer) == 0;
    } finally {
      calloc.free(pointer);
    }
  }

  bool action(String action, {Map<String, dynamic>? arguments}) {
    final actionPointer = action.toNativeUtf8();
    final argumentPointer = jsonEncode(arguments ?? <String, dynamic>{}).toNativeUtf8();
    try {
      return _runAction(actionPointer, argumentPointer) == 0;
    } finally {
      calloc.free(actionPointer);
      calloc.free(argumentPointer);
    }
  }

  /// Returns one captured log line, or an empty string when the queue is drained.
  String nextLog() {
    const capacity = 8192;
    final buffer = calloc<Uint8>(capacity);
    try {
      final length = _readLogLine(buffer, capacity);
      if (length <= 0) return '';
      final bytes = Uint8List.fromList(buffer.asTypedList(length));
      return utf8.decode(bytes, allowMalformed: true).trimRight();
    } finally {
      calloc.free(buffer);
    }
  }

  String _takeNativeString(Pointer<Utf8> pointer) {
    try {
      return pointer == nullptr ? '' : pointer.toDartString();
    } finally {
      if (pointer != nullptr) _freeString(pointer.cast());
    }
  }

  Map<String, dynamic> _decodeJson(String source) {
    try {
      return jsonDecode(source.isEmpty ? '{}' : source) as Map<String, dynamic>;
    } catch (_) {
      return <String, dynamic>{'bridgeError': source};
    }
  }
}
