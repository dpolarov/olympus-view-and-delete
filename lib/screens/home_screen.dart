import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:wifi_iot/wifi_iot.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_api.dart';
import '../services/file_saver.dart' as file_saver;
import '../services/thumbnail_manager.dart';
import '../services/connection_history.dart';
import '../widgets/photo_grid.dart';
import '../widgets/date_filter_sheet.dart';
import '../widgets/delete_progress_dialog.dart';
import '../widgets/download_progress_dialog.dart';
import 'qr_scan_screen.dart';
import 'photo_preview_screen.dart';
import '../version.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final CameraApi _api = CameraApi();

  List<CameraFile> _allFiles = [];
  List<CameraFile> _filteredFiles = [];
  bool _loading = false;
  bool _connected = false;
  String? _error;
  String _cameraModel = '';
  String _statusMessage = '';

  // Selection
  bool _selectionMode = false;
  final Set<String> _selectedPaths = {};

  // Filter
  String? _filterDate;
  DateTime? _filterFrom;
  DateTime? _filterTo;

  // View
  bool _gridView = true;
  bool _showRaw = false; // Show ORF/RAW files

  // Progressive loading generation (to cancel stale callbacks)
  int _loadGeneration = 0;

  @override
  void initState() {
    super.initState();
    _initLoad();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  /// Initial load: quick camera check → auto-connect last saved → load files
  Future<void> _initLoad() async {
    setState(() {
      _loading = true;
      _error = null;
      _statusMessage = 'Checking camera...';
    });

    // Quick check if camera is already reachable
    final alreadyConnected = await _api.testConnection();
    if (!mounted) return;
    if (alreadyConnected) {
      _loadFiles();
      return;
    }

    // Not reachable — try auto-connecting to last saved camera
    if (_isMobilePlatform()) {
      final history = await ConnectionHistory.load();
      if (history.isNotEmpty) {
        final last = history.first;
        final name = last.cameraName ?? last.ssid;
        setState(() => _statusMessage = 'Connecting to $name...');
        try {
          await Permission.location.request();
          final wifiOk = await WiFiForIoTPlugin.connect(
            last.ssid,
            password: last.password,
            security: last.security == 'NONE'
                ? NetworkSecurity.NONE
                : last.security == 'WEP'
                    ? NetworkSecurity.WEP
                    : NetworkSecurity.WPA,
            joinOnce: false,
            withInternet: false,
          );
          if (wifiOk && mounted) {
            setState(() => _statusMessage = 'WiFi connected, reaching camera...');
            await WiFiForIoTPlugin.forceWifiUsage(true);
            await ConnectionHistory.save(SavedConnection(
              ssid: last.ssid,
              password: last.password,
              security: last.security,
              cameraName: last.cameraName,
              btName: last.btName,
              btPasscode: last.btPasscode,
              lastConnected: DateTime.now(),
            ));
            if (mounted) {
              _loadFiles();
              return;
            }
          } else if (mounted) {
            setState(() => _statusMessage = 'WiFi connection failed');
          }
        } catch (_) {}
      }
    }

    // Could not connect
    if (mounted) {
      setState(() {
        _loading = false;
        _error = 'Cannot connect to camera.\nConnect to camera WiFi first.';
      });
    }
  }

  Future<void> _loadFiles() async {
    _loadGeneration++;
    final generation = _loadGeneration;

    setState(() {
      _loading = true;
      _error = null;
      _allFiles = [];
      _filteredFiles = [];
    });
    ThumbnailManager.instance.clear();

    try {
      // Retry testConnection (WiFi route may need time after switch)
      if (mounted) setState(() => _statusMessage = 'Connecting to camera...');
      bool ok = false;
      for (int attempt = 0; attempt < 3; attempt++) {
        ok = await _api.testConnection();
        if (ok || !mounted || generation != _loadGeneration) break;
        if (mounted) setState(() => _statusMessage = 'Retrying... (${attempt + 1}/3)');
        if (attempt < 2) await Future.delayed(const Duration(seconds: 1));
      }
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _connected = ok);
      if (!ok) {
        setState(() =>
            _error = 'Cannot connect to camera.\nConnect to camera WiFi first.');
        return;
      }

      if (mounted) setState(() => _statusMessage = 'Loading camera info...');
      try {
        final info = await _api.getCameraInfo();
        if (mounted && generation == _loadGeneration) {
          final model = info['model'] ?? 'Olympus Camera';
          setState(() => _cameraModel = model);
          // Update camera name in connection history
          final history = await ConnectionHistory.load();
          if (history.isNotEmpty) {
            final latest = history.first;
            if (latest.cameraName != model) {
              await ConnectionHistory.save(SavedConnection(
                ssid: latest.ssid,
                password: latest.password,
                security: latest.security,
                cameraName: model,
                btName: latest.btName,
                btPasscode: latest.btPasscode,
                lastConnected: latest.lastConnected,
              ));
            }
          }
        }
      } catch (_) {}

      if (mounted) setState(() => _statusMessage = 'Loading file list...');
      final files = await _api.listAllFiles(
        onBatch: (batch) {
          if (!mounted || generation != _loadGeneration) return;
          setState(() {
            _allFiles.addAll(batch);
            _applyFilter();
          });
        },
      );

      if (!mounted || generation != _loadGeneration) return;

      // Replace with final sorted list
      setState(() {
        _allFiles = files;
        _applyFilter();
      });
    } catch (e) {
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted && generation == _loadGeneration) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyFilter() {
    List<CameraFile> files;
    if (_filterDate != null) {
      files = CameraApi.filterByDate(_allFiles, _filterDate!);
    } else if (_filterFrom != null || _filterTo != null) {
      files = CameraApi.filterByDateRange(_allFiles, _filterFrom, _filterTo);
    } else {
      files = List.from(_allFiles);
    }
    if (!_showRaw) {
      files = files.where((f) {
        final ext = f.filename.toLowerCase();
        return !ext.endsWith('.orf') && !ext.endsWith('.raw') && !ext.endsWith('.dng');
      }).toList();
    }
    _filteredFiles = files;
  }

  void _toggleSelect(CameraFile file) {
    if (!_selectionMode) return;
    setState(() {
      if (_selectedPaths.contains(file.fullPath)) {
        _selectedPaths.remove(file.fullPath);
      } else {
        _selectedPaths.add(file.fullPath);
      }
    });
  }

  void _enterSelectionMode(CameraFile file) {
    setState(() {
      _selectionMode = true;
      _selectedPaths.clear();
      _selectedPaths.add(file.fullPath);
    });
  }

  void _exitSelectionMode() {
    setState(() {
      _selectionMode = false;
      _selectedPaths.clear();
    });
  }

  void _selectAll() {
    setState(() {
      _selectedPaths.clear();
      for (final f in _filteredFiles) {
        _selectedPaths.add(f.fullPath);
      }
    });
  }

  void _deselectAll() {
    setState(() => _selectedPaths.clear());
  }

  void _selectByDates() {
    // Collect dates (year-month-day) of currently selected files
    final selectedDates = <String>{};
    for (final f in _filteredFiles) {
      if (_selectedPaths.contains(f.fullPath)) {
        selectedDates.add(f.dateStr);
      }
    }
    if (selectedDates.isEmpty) return;
    // Select all files that match any of those dates
    setState(() {
      for (final f in _filteredFiles) {
        if (selectedDates.contains(f.dateStr)) {
          _selectedPaths.add(f.fullPath);
        }
      }
    });
  }

  bool _isMobilePlatform() {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
           defaultTargetPlatform == TargetPlatform.iOS;
  }

  Future<void> _connectFromSaved(SavedConnection conn) async {
    if (_isMobilePlatform()) {
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        await Permission.location.request();
        final connected = await WiFiForIoTPlugin.connect(
          conn.ssid,
          password: conn.password,
          security: conn.security == 'NONE'
              ? NetworkSecurity.NONE
              : conn.security == 'WEP'
                  ? NetworkSecurity.WEP
                  : NetworkSecurity.WPA,
          joinOnce: false,
          withInternet: false,
        );
        if (connected) {
          await WiFiForIoTPlugin.forceWifiUsage(true);
          // Update last connected time
          await ConnectionHistory.save(SavedConnection(
            ssid: conn.ssid,
            password: conn.password,
            security: conn.security,
            cameraName: conn.cameraName,
            btName: conn.btName,
            btPasscode: conn.btPasscode,
            lastConnected: DateTime.now(),
          ));
          if (mounted) _loadFiles();
        } else {
          if (mounted) {
            setState(() {
              _loading = false;
              _error = 'Failed to connect to ${conn.ssid}';
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _loading = false;
            _error = 'Connection error: $e';
          });
        }
      }
    } else {
      _loadFiles();
    }
  }

  void _showAbout() {
    showAboutDialog(
      context: context,
      applicationName: appName,
      applicationVersion: 'v$appVersion (build $appBuild)',
      applicationIcon: const Icon(Icons.camera_alt, size: 48, color: Color(0xFFE94560)),
      children: [
        const SizedBox(height: 8),
        const Text('WiFi Camera Manager for Olympus/OM System cameras.'),
        const SizedBox(height: 16),
        Text(
          'Changelog v$appVersion:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 8),
        const Text(
          '• Full-screen photo preview with swipe & zoom\n'
          '• Download/Delete from preview screen\n'
          '• Image preloading for smooth swiping\n'
          '• Persistent disk cache for thumbnails & previews\n'
          '• Auto-connect to last used camera\n'
          '• Saved cameras quick reconnect\n'
          '• Detailed connection status messages',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () => launchUrl(
            Uri.parse('https://dpolarov.github.io/olympus-view-and-delete/'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text(
            'dpolarov.github.io/olympus-view-and-delete',
            style: TextStyle(
              color: Color(0xFF64B5F6),
              decoration: TextDecoration.underline,
              decorationColor: Color(0xFF64B5F6),
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openQrScanner() async {
    final connected = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const QrScanScreen()),
    );
    if (connected == true && mounted) {
      _loadFiles();
    }
  }

  void _clearFilter() {
    setState(() {
      _filterDate = null;
      _filterFrom = null;
      _filterTo = null;
      _applyFilter();
    });
  }

  void _showDateFilter() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1A2E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DateFilterSheet(
        files: _allFiles,
        selectedDate: _filterDate,
        dateFrom: _filterFrom,
        dateTo: _filterTo,
        onDateSelected: (date) {
          Navigator.pop(ctx);
          setState(() {
            _filterDate = date;
            _filterFrom = null;
            _filterTo = null;
            _applyFilter();
            _exitSelectionMode();
          });
        },
        onRangeSelected: (from, to) {
          Navigator.pop(ctx);
          setState(() {
            _filterDate = null;
            _filterFrom = from;
            _filterTo = to;
            _applyFilter();
            _exitSelectionMode();
          });
        },
        onClear: () {
          Navigator.pop(ctx);
          _clearFilter();
        },
      ),
    );
  }

  Future<void> _handleDownload() async {
    final toDownload = _filteredFiles
        .where((f) => _selectedPaths.contains(f.fullPath))
        .toList();

    if (toDownload.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select files to download first')),
      );
      return;
    }

    final totalSize =
        toDownload.fold<int>(0, (sum, f) => sum + f.size);
    final sizeStr = CameraFile(
      directory: '',
      filename: '',
      size: totalSize,
      attributes: 0,
      dateRaw: 0,
      timeRaw: 0,
      date: DateTime.now(),
    ).sizeHuman;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Download Files'),
        content: Text(
          'Download ${toDownload.length} file(s) ($sizeStr)?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF2ECC71)),
            child: const Text('DOWNLOAD'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Get save directory
    final saveDirPath = await file_saver.getSaveDirectory();
    await file_saver.ensureDirectory(saveDirPath);

    final result =
        await showDialog<({int success, int failed, List<String> savedPaths})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DownloadProgressDialog(
        api: _api,
        files: toDownload,
        saveDirPath: saveDirPath,
      ),
    );

    if (!mounted) return;

    _exitSelectionMode();

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Downloaded: ${result.success}, Failed: ${result.failed}'
              '${kIsWeb ? '' : '\nSaved to: $saveDirPath'}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _handleDelete() async {
    final toDelete = _filteredFiles
        .where((f) => _selectedPaths.contains(f.fullPath))
        .toList();

    if (toDelete.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select files to delete first')),
      );
      return;
    }

    final totalSize =
        toDelete.fold<int>(0, (sum, f) => sum + f.size);
    final sizeStr = CameraFile(
      directory: '',
      filename: '',
      size: totalSize,
      attributes: 0,
      dateRaw: 0,
      timeRaw: 0,
      date: DateTime.now(),
    ).sizeHuman;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Delete Files'),
        content: Text(
          'Delete ${toDelete.length} file(s) ($sizeStr)?\n\nThis cannot be undone!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final result = await showDialog<({int success, int failed})>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => DeleteProgressDialog(
        api: _api,
        files: toDelete,
      ),
    );

    if (!mounted) return;

    _exitSelectionMode();

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Deleted: ${result.success}, Failed: ${result.failed}'),
        ),
      );
      _loadFiles();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Loading state
    if (_loading && _allFiles.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFFE94560)),
              const SizedBox(height: 16),
              Text(_statusMessage.isNotEmpty ? _statusMessage : 'Connecting...',
                  style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_error != null && _allFiles.isEmpty) {
      return Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
                minWidth: constraints.maxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                const Icon(Icons.camera_alt, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 32),
                if (!kIsWeb) ...[
                  SizedBox(
                    width: 220,
                    child: ElevatedButton.icon(
                      onPressed: _openQrScanner,
                      icon: Icon(
                        _isMobilePlatform() ? Icons.qr_code_scanner : Icons.wifi,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isMobilePlatform() ? 'Scan QR Code' : 'Connect WiFi',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: 220,
                  child: OutlinedButton.icon(
                    onPressed: _initLoad,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[600]!),
                    ),
                  ),
                ),
                // Saved cameras
                FutureBuilder<List<SavedConnection>>(
                  future: ConnectionHistory.load(),
                  builder: (context, snapshot) {
                    final connections = snapshot.data ?? [];
                    if (connections.isEmpty) return const SizedBox.shrink();
                    return Column(
                      children: [
                        const SizedBox(height: 32),
                        const Divider(color: Color(0xFF333355)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.history, color: Color(0xFFE94560), size: 18),
                            const SizedBox(width: 8),
                            const Text(
                              'Saved cameras',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...connections.map((conn) => GestureDetector(
                              onTap: () => _connectFromSaved(conn),
                              child: Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1A1A2E),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFF333355)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.wifi, color: Color(0xFF2ECC71), size: 22),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            conn.cameraName.isNotEmpty
                                                ? conn.cameraName
                                                : conn.ssid,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            conn.cameraName.isNotEmpty
                                                ? '${conn.ssid} · ${conn.lastConnectedStr}'
                                                : conn.lastConnectedStr,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey[500],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: Colors.grey[600]),
                                  ],
                                ),
                              ),
                            )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
          ),
        ),
      );
    }

    final hasFilter = _filterDate != null || _filterFrom != null;
    final filterLabel = _filterDate != null
        ? 'Date: $_filterDate'
        : (_filterFrom != null && _filterTo != null)
            ? '${_filterFrom!.toString().substring(0, 10)} — ${_filterTo!.toString().substring(0, 10)}'
            : _filterFrom != null
                ? 'From: ${_filterFrom!.toString().substring(0, 10)}'
                : 'Filter by date';

    return Scaffold(
      appBar: AppBar(
        title: Text(_selectionMode
            ? '${_selectedPaths.length} selected'
            : (_cameraModel.isNotEmpty ? _cameraModel : 'Olympus TG-6')),
        leading: _selectionMode
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: _exitSelectionMode,
              )
            : null,
        actions: [
          if (_selectionMode) ...[
            IconButton(
              icon: const Icon(Icons.select_all),
              tooltip: 'Select all',
              onPressed: _selectAll,
            ),
            IconButton(
              icon: const Icon(Icons.deselect),
              tooltip: 'Deselect all',
              onPressed: _deselectAll,
            ),
            IconButton(
              icon: const Icon(Icons.date_range),
              tooltip: 'Select all by same dates',
              onPressed: _selectByDates,
            ),
            IconButton(
              icon: const Icon(Icons.download, color: Color(0xFF2ECC71)),
              tooltip: 'Download selected',
              onPressed: _handleDownload,
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              tooltip: 'Delete selected',
              onPressed: _handleDelete,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              tooltip: kIsWeb ? 'Connect to camera' : 'Scan camera QR',
              onPressed: kIsWeb ? null : _openQrScanner,
            ),
            IconButton(
              icon: Icon(_gridView ? Icons.view_list : Icons.grid_view),
              onPressed: () => setState(() => _gridView = !_gridView),
            ),
            IconButton(
              icon: Icon(
                _showRaw ? Icons.raw_on : Icons.raw_off,
                color: _showRaw ? const Color(0xFFE94560) : null,
              ),
              tooltip: _showRaw ? 'Hide RAW files' : 'Show RAW files',
              onPressed: () => setState(() {
                _showRaw = !_showRaw;
                _applyFilter();
              }),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadFiles,
            ),
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'About',
              onPressed: _showAbout,
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Status & filter bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: const Color(0xFF1A1A2E),
            child: Column(
              children: [
                // Connection status
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            _connected ? Colors.greenAccent : Colors.redAccent,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _connected ? 'Connected' : 'Disconnected',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    ),
                    if (_allFiles.isNotEmpty)
                      Text(
                        _loading
                            ? ' · Loading... ${_allFiles.length} files'
                            : ' · ${_filteredFiles.length} files · '
                              '${(_allFiles.fold<int>(0, (s, f) => s + f.size) / (1024 * 1024)).toStringAsFixed(1)} MB',
                        style:
                            TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    if (_loading && _allFiles.isNotEmpty)
                      const SizedBox(width: 8),
                    if (_loading && _allFiles.isNotEmpty)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFE94560),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                // Filter button
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_month, size: 16),
                        label: Text(filterLabel,
                            style: const TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: hasFilter
                              ? const Color(0xFFE94560)
                              : Colors.grey[400],
                          side: BorderSide(
                            color: hasFilter
                                ? const Color(0xFFE94560)
                                : Colors.grey[700]!,
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                        ),
                        onPressed: _showDateFilter,
                      ),
                    ),
                    if (hasFilter) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF252540),
                        ),
                        onPressed: _clearFilter,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // Photo list/grid
          Expanded(
            child: _filteredFiles.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('No files found',
                            style: TextStyle(color: Colors.grey[500])),
                        if (hasFilter)
                          TextButton(
                            onPressed: _clearFilter,
                            child: const Text('Clear filters'),
                          ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadFiles,
                    color: const Color(0xFFE94560),
                    child: PhotoGrid(
                      files: _filteredFiles,
                      gridView: _gridView,
                      selectionMode: _selectionMode,
                      selectedPaths: _selectedPaths,
                      onTap: _toggleSelect,
                      onLongPress: _enterSelectionMode,
                      onPreview: (file, index) async {
                        final deleted = await Navigator.push<bool>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoPreviewScreen(
                              file: file,
                              files: _filteredFiles,
                              initialIndex: index,
                            ),
                          ),
                        );
                        if (deleted == true && mounted) {
                          _loadFiles();
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),

      // Bottom bar
      bottomNavigationBar: !_selectionMode && _allFiles.isNotEmpty
          ? SafeArea(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(
                  color: Color(0xFF1A1A2E),
                  border: Border(
                    top: BorderSide(color: Color(0xFF333355)),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _selectionMode = true;
                            _selectedPaths.clear();
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F3460),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Select Files',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          _selectAll();
                          setState(() => _selectionMode = true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE74C3C),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Select All & Delete',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}
