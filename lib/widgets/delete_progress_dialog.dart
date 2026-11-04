import 'package:flutter/material.dart';

import '../constants.dart';
import '../services/app_logger.dart';
import '../services/camera_api.dart';

class DeleteProgressDialog extends StatefulWidget {
  final CameraApi api;
  final List<CameraFile> files;

  const DeleteProgressDialog({
    super.key,
    required this.api,
    required this.files,
  });

  @override
  State<DeleteProgressDialog> createState() => _DeleteProgressDialogState();
}

class _DeleteProgressDialogState extends State<DeleteProgressDialog> {
  int _done = 0;
  int _total = 0;
  String _currentFile = '';

  @override
  void initState() {
    super.initState();
    _total = widget.files.length;
    _startDelete();
  }

  Future<void> _startDelete() async {
    ({int success, int failed})? result;
    try {
      result = await widget.api.deleteFiles(
        widget.files,
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
    } catch (e, st) {
      AppLogger.warning('batch delete failed',
          name: 'delete_dialog', error: e, stackTrace: st);
      // result stays null, dialog pops in finally.
    } finally {
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total > 0 ? _done / _total : 0.0;

    return AlertDialog(
      backgroundColor: kBackgroundColor,
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
              color: kPrimaryColor,
              backgroundColor: kBackgroundColor,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Deleting files...', // TODO: локализация
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '$_done / $_total',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: kPrimaryColor,
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
