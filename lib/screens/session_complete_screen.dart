import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class SessionCompleteScreen extends StatefulWidget {
  final AppStrings strings;
  final Future<void> Function() uploadFuture;
  const SessionCompleteScreen({super.key, required this.strings, required this.uploadFuture});

  @override
  State<SessionCompleteScreen> createState() => _SessionCompleteScreenState();
}

class _SessionCompleteScreenState extends State<SessionCompleteScreen> {
  bool _uploading = true;
  bool _success = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _doUpload();
  }

  // Fix: extracted so retry button can re-invoke it.
  // Previously, retry only reset UI state but never called uploadFuture() again,
  // leaving the user with a spinner that never resolved.
  void _doUpload() {
    setState(() { _uploading = true; _error = null; });
    widget.uploadFuture().then((_) {
      if (mounted) setState(() { _uploading = false; _success = true; });
    }).catchError((e) {
      if (mounted) setState(() { _uploading = false; _error = e.toString(); });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (_uploading) ...[
            const CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 24),
            Text(widget.strings.uploadingData,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: AppColors.textSecondary)),
          ] else if (_success) ...[
            const Icon(Icons.check_circle_outline, size: 80, color: AppColors.riskLow),
            const SizedBox(height: 20),
            Text(widget.strings.sessionComplete,
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(widget.strings.thankYou,
                style: const TextStyle(fontSize: 18, color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(widget.strings.doctorWillReview,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          ] else ...[
            const Icon(Icons.error_outline, size: 80, color: AppColors.riskHigh),
            const SizedBox(height: 20),
            const Text('Upload failed', style: TextStyle(fontSize: 20,
                fontWeight: FontWeight.bold, color: AppColors.riskHigh)),
            const SizedBox(height: 8),
            Text(_error ?? 'Unknown error',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _doUpload,
              child: const Text('Retry'),
            ),
          ],
        ]),
      )),
    );
  }
}
