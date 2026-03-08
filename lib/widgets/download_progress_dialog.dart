import 'package:flutter/material.dart';
import '../services/camera_api.dart';

class DownloadProgressDialog extends StatefulWidget {
  final CameraApi api;
  final List<CameraFile> files;
  final String saveDirPath;

  const DownloadProgressDialog({
    super.key,
    required this.api,
    required this.files,
    required this.saveDirPath,
  });

  @override
  State<DownloadProgressDialog> createState() => _DownloadProgressDialogState();
}

class _DownloadProgressDialogState extends State<DownloadProgressDialog> {
  int _done = 0;
  int _total = 0;
  String _currentFile = '';

  @override
  void initState() {
    super.initState();
    _total = widget.files.length;
    _startDownload();
  }

  Future<void> _startDownload() async {
    final result = await widget.api.downloadFiles(
      widget.files,
      widget.saveDirPath,
      onProgress: (done, total, filename) {
        if (mounted) {
          setState(() {
            _done = done;
            _total = total;
            _currentFile = filename;
          });
        }
      },
    );

    if (mounted) {
      Navigator.of(context).pop(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _done / _total : 0.0;

    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A2E),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 4,
              color: const Color(0xFF2ECC71),
              backgroundColor: const Color(0xFF252540),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Downloading...',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$_done / $_total',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2ECC71),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _currentFile,
            style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
