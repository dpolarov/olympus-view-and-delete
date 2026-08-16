import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../constants.dart';
import '../services/debug_info_service.dart';

class DebugInfoScreen extends StatefulWidget {
  const DebugInfoScreen({super.key});

  @override
  State<DebugInfoScreen> createState() => _DebugInfoScreenState();
}

class _DebugInfoScreenState extends State<DebugInfoScreen> {
  late Future<DebugSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _snapshot = DebugInfoService.collect();
  }

  Future<void> _copy(DebugSnapshot snapshot) async {
    await Clipboard.setData(ClipboardData(text: snapshot.toPlainText()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Debug report copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug information'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(_reload),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<DebugSnapshot>(
        future: _snapshot,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              child: CircularProgressIndicator(color: kPrimaryColor),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: SelectableText(
                  'Could not collect diagnostics:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final data = snapshot.data!;
          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
              children: [
                _StatusBanner(snapshot: data),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _copy(data),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy full debug report'),
                ),
                const SizedBox(height: 16),
                ...data.sections.map(_sectionCard),
                const SizedBox(height: 8),
                Text(
                  'Open this screen anywhere by holding four fingers on the app for about 0.35 seconds.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionCard(DebugSection section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kPrimaryColor,
              ),
            ),
            const SizedBox(height: 10),
            ...section.values.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 168,
                      child: Text(
                        entry.key,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.snapshot});

  final DebugSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final hasProblem = snapshot.staleProcess || snapshot.versionMismatch;
    final text = snapshot.staleProcess
        ? 'STALE PROCESS DETECTED: the running process started before the currently installed APK was updated.'
        : snapshot.versionMismatch
            ? 'VERSION MISMATCH: Android package version and Dart source constants do not match.'
            : 'Runtime version is consistent: ${snapshot.runtimeVersion} (build ${snapshot.runtimeBuild}).';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasProblem
            ? const Color(0xFF4A1F28)
            : const Color(0xFF163B2A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasProblem ? Colors.redAccent : Colors.greenAccent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasProblem ? Icons.warning_amber_rounded : Icons.check_circle_outline,
            color: hasProblem ? Colors.redAccent : Colors.greenAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
