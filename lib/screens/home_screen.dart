import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform, TargetPlatform;
import '../services/camera_api.dart';
import '../services/file_saver.dart' as file_saver;
import '../services/thumbnail_manager.dart';
import '../widgets/photo_grid.dart';
import '../widgets/date_filter_sheet.dart';
import '../widgets/delete_progress_dialog.dart';
import '../widgets/download_progress_dialog.dart';
import 'qr_scan_screen.dart';
import 'photo_preview_screen.dart';

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
    _loadFiles();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
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
      final ok = await _api.testConnection();
      if (!mounted || generation != _loadGeneration) return;
      setState(() => _connected = ok);
      if (!ok) {
        setState(() =>
            _error = 'Cannot connect to camera.\nConnect to camera WiFi first.');
        return;
      }

      try {
        final info = await _api.getCameraInfo();
        if (mounted && generation == _loadGeneration) {
          setState(() => _cameraModel = info['model'] ?? 'Olympus Camera');
        }
      } catch (_) {}

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
              Text('Connecting to camera...',
                  style: TextStyle(color: Colors.grey[500])),
            ],
          ),
        ),
      );
    }

    // Error state
    if (_error != null && _allFiles.isEmpty) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                    onPressed: _loadFiles,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry Connection'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(color: Colors.grey[600]!),
                    ),
                  ),
                ),
              ],
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
                      onPreview: (file, index) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PhotoPreviewScreen(
                              file: file,
                              files: _filteredFiles,
                              initialIndex: index,
                            ),
                          ),
                        );
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
