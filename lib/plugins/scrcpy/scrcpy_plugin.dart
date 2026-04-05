import 'package:simutil/models/device.dart';
import 'package:simutil/plugins/plugin_base.dart';

/// Plugin that launches [scrcpy](https://github.com/Genymobile/scrcpy) for an
/// Android device, providing screen mirroring and control from the desktop.
///
/// The generated command is: `scrcpy -s <device-id>`
class ScrcpyPlugin extends SimutilPlugin {
  const ScrcpyPlugin();

  @override
  String get name => 'scrcpy';

  @override
  String get command => 'scrcpy';

  @override
  List<String> buildArgs(Device device) => ['-s', device.id];
}
