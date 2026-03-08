import 'package:flutter/material.dart';
import '../services/camera_api.dart';

class DateFilterSheet extends StatefulWidget {
  final List<CameraFile> files;
  final String? selectedDate;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final void Function(String?) onDateSelected;
  final void Function(DateTime?, DateTime?) onRangeSelected;
  final VoidCallback onClear;

  const DateFilterSheet({
    super.key,
    required this.files,
    this.selectedDate,
    this.dateFrom,
    this.dateTo,
    required this.onDateSelected,
    required this.onRangeSelected,
    required this.onClear,
  });

  @override
  State<DateFilterSheet> createState() => _DateFilterSheetState();
}

class _DateFilterSheetState extends State<DateFilterSheet> {
  DateTime? _from;
  DateTime? _to;

  @override
  void initState() {
    super.initState();
    _from = widget.dateFrom;
    _to = widget.dateTo;
  }

  Future<void> _pickDate(bool isFrom) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isFrom ? (_from ?? now) : (_to ?? now),
      firstDate: DateTime(2000),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFFE94560),
              surface: Color(0xFF1A1A2E),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final uniqueDates = CameraApi.getUniqueDates(widget.files);
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Filter by Date',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // Date list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                // All dates option
                _DateTile(
                  label: 'All dates',
                  count: widget.files.length,
                  active: widget.selectedDate == null && _from == null,
                  onTap: () => widget.onDateSelected(null),
                ),
                // Individual dates
                ...uniqueDates.map((d) {
                  final count = CameraApi.filterByDate(widget.files, d).length;
                  return _DateTile(
                    label: d,
                    count: count,
                    active: widget.selectedDate == d,
                    onTap: () => widget.onDateSelected(d),
                  );
                }),

                const SizedBox(height: 16),
                const Divider(color: Color(0xFF333355)),
                const SizedBox(height: 8),

                // Date range
                Text(
                  'Date Range',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[400],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(true),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _from != null
                              ? _from.toString().substring(0, 10)
                              : 'From...',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text('—',
                          style: TextStyle(color: Colors.grey[600])),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _pickDate(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.grey[700]!),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: Text(
                          _to != null
                              ? _to.toString().substring(0, 10)
                              : 'To...',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_from != null || _to != null) ...[
                  ElevatedButton(
                    onPressed: () => widget.onRangeSelected(_from, _to),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE94560),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      'Apply Range'
                      '${(_from != null && _to != null) ? ' (${CameraApi.filterByDateRange(widget.files, _from, _to).length} files)' : ''}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  const _DateTile({
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: active ? const Color(0xFFE94560).withOpacity(0.15) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 15)),
            Text('$count files',
                style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }
}
