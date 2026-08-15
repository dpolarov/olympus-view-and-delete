import 'package:flutter/material.dart';

import '../services/connection_history.dart';

class QrScanScreen extends StatefulWidget {
  final String? initialSsid;
  final String? initialPassword;

  const QrScanScreen({super.key, this.initialSsid, this.initialPassword});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final _ssid = TextEditingController();
  final _password = TextEditingController();
  List<SavedConnection> _history = const [];
  String _status = '';

  @override
  void initState() {
    super.initState();
    _ssid.text = widget.initialSsid ?? '';
    _password.text = widget.initialPassword ?? '';
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await ConnectionHistory.load();
    if (mounted) setState(() => _history = history);
  }

  Future<void> _showInstructions() async {
    final ssid = _ssid.text.trim();
    if (ssid.isEmpty) return;

    setState(() {
      _status = 'Connect this device to WiFi network "$ssid" in your system settings, then return here and press Done.';
    });
  }

  @override
  void dispose() {
    _ssid.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to Camera')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Web browsers cannot switch WiFi networks automatically. Enter the camera WiFi credentials, connect through your system settings, then return to the browser.',
          ),
          if (_history.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text('Saved cameras',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ..._history.map((item) => ListTile(
                  leading: const Icon(Icons.wifi),
                  title: Text(item.ssid),
                  subtitle: Text(item.lastConnectedStr),
                  onTap: () {
                    _ssid.text = item.ssid;
                    _password.text = item.password;
                  },
                )),
          ],
          const SizedBox(height: 20),
          TextField(
            controller: _ssid,
            decoration: const InputDecoration(labelText: 'SSID'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _showInstructions,
            child: const Text('Show connection instructions'),
          ),
          if (_status.isNotEmpty) ...[
            const SizedBox(height: 20),
            SelectableText(_status, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Done'),
            ),
          ],
        ],
      ),
    );
  }
}
