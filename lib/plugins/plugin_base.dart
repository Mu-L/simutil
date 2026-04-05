import 'dart:io';

import 'package:simutil/models/device.dart';

/// Abstract base class for all simutil feature plugins.
///
/// Every plugin provides a [name], a [command] to execute, and a way to
/// build the argument list ([buildArgs]) for a specific [Device]. The
/// optional [isAvailable] helper checks whether the underlying executable
/// is present on the host machine.
abstract class SimutilPlugin {
  const SimutilPlugin();

  /// Human-readable name of the plugin (e.g. `'scrcpy'`).
  String get name;

  /// The executable that this plugin runs (e.g. `'scrcpy'`).
  String get command;

  /// Returns the argument list to pass to [command] for [device].
  List<String> buildArgs(Device device);

  /// Returns `true` if [command] is available on the host machine.
  ///
  /// The default implementation runs `<command> --version` and checks the
  /// exit code. Subclasses may override this for tools that use a different
  /// availability probe.
  Future<bool> isAvailable() async {
    try {
      final result = await Process.run(command, ['--version']);
      return result.exitCode == 0;
    } catch (_) {
      return false;
    }
  }
}
