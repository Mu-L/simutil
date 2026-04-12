import 'dart:async';

import 'package:nocterm/nocterm.dart';
import 'package:simutil/components/show_overlay_dialog.dart';
import 'package:simutil/components/simutil_icons.dart';
import 'package:simutil/components/simutil_theme.dart';
import 'package:simutil/plugins/adb_tools/wireless_pairing_dialog.dart';
import 'package:simutil/services/mdns_service.dart';

enum _Phase { scanning, discovered, enterCode }

class QrConnectDialog extends StatefulComponent {
  const QrConnectDialog({
    super.key,
    required this.mdnsService,
    required this.onSubmit,
    required this.onCancel,
  });

  final MdnsService mdnsService;
  final void Function(WirelessPairingInput input) onSubmit;
  final VoidCallback onCancel;

  @override
  State<QrConnectDialog> createState() => _QrConnectDialogState();
}

class _QrConnectDialogState extends State<QrConnectDialog> {
  _Phase _phase = _Phase.scanning;
  List<MdnsDiscoveredPairingService> _services = [];
  int _selectedIndex = 0;
  late TextEditingController _codeController;
  Timer? _scanTimer;
  Timer? _spinnerTimer;
  int _spinnerIndex = 0;
  bool _isScanning = false;
  String? _codeError;

  static const _spinnerFrames = ['-', r'\', '|', '/'];

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController();
    _startScanning();
    _spinnerTimer = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => setState(() {
        _spinnerIndex = (_spinnerIndex + 1) % _spinnerFrames.length;
      }),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _scanTimer?.cancel();
    _spinnerTimer?.cancel();
    super.dispose();
  }

  void _startScanning() {
    _scan();
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 5), (_) => _scan());
  }

  Future<void> _scan() async {
    if (_isScanning) return;
    setState(() => _isScanning = true);

    try {
      final discovered = await component.mdnsService.discoverPairingServices();
      setState(() {
        _isScanning = false;
        _services = discovered;
        if (_services.isNotEmpty && _phase == _Phase.scanning) {
          _phase = _Phase.discovered;
          _selectedIndex = 0;
        } else if (_services.isEmpty && _phase != _Phase.enterCode) {
          _phase = _Phase.scanning;
        }
      });
    } catch (_) {
      setState(() {
        _isScanning = false;
        if (_phase != _Phase.enterCode) _phase = _Phase.scanning;
      });
    }
  }

  bool _handleKeyEvent(KeyboardEvent event) {
    if (_phase == _Phase.enterCode) {
      if (event.logicalKey == LogicalKey.escape) {
        setState(() {
          _phase = _services.isNotEmpty ? _Phase.discovered : _Phase.scanning;
          _codeController.clear();
          _codeError = null;
        });
        return true;
      }
      return false;
    }

    if (event.logicalKey == LogicalKey.escape) {
      component.onCancel();
      return true;
    }

    if (event.logicalKey == LogicalKey.keyR) {
      setState(() {
        _phase = _Phase.scanning;
        _services = [];
      });
      _startScanning();
      return true;
    }

    if (_phase == _Phase.discovered) {
      if (event.logicalKey == LogicalKey.arrowUp) {
        setState(() {
          _selectedIndex = (_selectedIndex - 1).clamp(0, _services.length - 1);
        });
        return true;
      }
      if (event.logicalKey == LogicalKey.arrowDown) {
        setState(() {
          _selectedIndex = (_selectedIndex + 1).clamp(0, _services.length - 1);
        });
        return true;
      }
      if (event.logicalKey == LogicalKey.enter) {
        setState(() {
          _phase = _Phase.enterCode;
          _codeController.clear();
          _codeError = null;
        });
        return true;
      }
    }

    return false;
  }

  void _trySubmit(String code) {
    if (code.length != 6) {
      setState(() => _codeError = 'Pairing code must be exactly 6 digits.');
      return;
    }
    final service = _services[_selectedIndex];
    component.onSubmit(
      WirelessPairingInput(host: service.address, pairingCode: code),
    );
  }

  @override
  Component build(BuildContext context) {
    final st = context.simutilTheme;
    return Center(
      child: Container(
        margin: EdgeInsets.all(4),
        decoration: st.dialogPanel('QR Code Pairing'),
        child: Padding(
          padding: EdgeInsets.all(1),
          child: Focusable(
            focused: true,
            onKeyEvent: _handleKeyEvent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildInstructions(st),
                Divider(),
                if (_phase == _Phase.enterCode)
                  _buildCodeEntry(st)
                else ...[
                  _buildScanningStatus(st),
                  Divider(),
                  _buildFooter(st),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Component _buildInstructions(SimutilTheme st) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' Steps:', style: st.label),
        Text(
          '  1. On your Android device (Android 11+)',
          style: st.dimmed,
        ),
        Text('  2. Go to Settings > Developer Options', style: st.dimmed),
        Text('  3. Enable "Wireless debugging"', style: st.dimmed),
        Text(
          '  4. Tap "Pair device with QR Code" or "Pair with pairing code"',
          style: st.dimmed,
        ),
      ],
    );
  }

  Component _buildScanningStatus(SimutilTheme st) {
    if (_phase == _Phase.scanning) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 1),
        child: Text(
          '  ${_spinnerFrames[_spinnerIndex]} Scanning for devices via mDNS...',
          style: st.dimmed,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' Discovered devices:', style: st.label),
        ..._services.asMap().entries.map((entry) {
          final isSelected = entry.key == _selectedIndex;
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isSelected ? ' ${SimutilIcons.pointer} ' : '   ',
                style: st.label,
              ),
              Text(
                entry.value.address,
                style: isSelected ? st.selected : st.body,
              ),
            ],
          );
        }),
        if (_isScanning)
          Text(
            '  ${_spinnerFrames[_spinnerIndex]} Rescanning...',
            style: st.dimmed,
          ),
      ],
    );
  }

  Component _buildCodeEntry(SimutilTheme st) {
    final service = _services[_selectedIndex];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(' Device: ${service.address}', style: st.label),
        SizedBox(height: 1),
        Text(
          ' Enter the 6-digit pairing code shown on your device:',
          style: st.body,
        ),
        SizedBox(height: 1),
        Row(
          children: [
            Text('  ', style: st.body),
            Expanded(
              child: TextField(
                controller: _codeController,
                focused: true,
                placeholder: '123456',
                placeholderStyle: st.dimmed,
                style: st.body,
                onSubmitted: _trySubmit,
                decoration: InputDecoration(
                  border: BoxBorder.all(
                    style: BoxBorderStyle.rounded,
                    color: st.outline,
                  ),
                  focusedBorder: BoxBorder.all(
                    style: BoxBorderStyle.rounded,
                    color: st.primary,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 1),
                ),
              ),
            ),
            Text('  ', style: st.body),
          ],
        ),
        Divider(),
        if (_codeError != null)
          Text(' $_codeError', style: st.errorStyle),
        Text(' Submit: <enter> | Back: <esc>', style: st.dimmed),
      ],
    );
  }

  Component _buildFooter(SimutilTheme st) {
    if (_phase == _Phase.discovered) {
      return Text(
        ' Navigate: <↑/↓> | Select: <enter> | Rescan: <r> | Cancel: <esc>',
        style: st.dimmed,
      );
    }
    return Text(' Rescan: <r> | Cancel: <esc>', style: st.dimmed);
  }
}

Future<WirelessPairingInput?> showQrConnectDialog({
  required BuildContext context,
  required MdnsService mdnsService,
}) => showOverlayDialog<WirelessPairingInput?>(
  context: context,
  builder: (context, completer, entry) => QrConnectDialog(
    mdnsService: mdnsService,
    onSubmit: (input) {
      completer.complete(input);
      entry?.remove();
    },
    onCancel: () {
      completer.complete(null);
      entry?.remove();
    },
  ),
);
