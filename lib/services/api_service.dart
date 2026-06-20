import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/session.dart';

class ApiService {
  // Use the provided backend URL directly as requested
  static const String _baseUrl = 'https://automatic-space-trout-pjg9jrwq67j737wr5-8000.app.github.dev';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<Map<String, dynamic>> registerChild(Map<String, dynamic> data) async {
    final resp = await _dio.post('/children', data: data);
    return Map<String, dynamic>.from(resp.data as Map);
  }

  /// Uploads the session JSON plus up to three per-task video clips.
  ///
  /// FIX: previously took a single `videoPath`, which only ever held Task
  /// C's clip (the others were discarded before reaching this layer). Now
  /// each task's clip — if it was recorded successfully — is attached as
  /// its own multipart field.
  Future<Map<String, dynamic>> uploadSession({
    required SessionData session,
    String? videoTaskAPath,
    String? videoTaskBPath,
    String? videoTaskCPath,
    void Function(int sent, int total)? onProgress,
  }) async {
    final fields = <String, dynamic>{
      'session_json': MultipartFile.fromString(
        jsonEncode(session.toJson()),
        filename: 'session.json',
      ),
    };

    if (videoTaskAPath != null && videoTaskAPath.isNotEmpty) {
      fields['video_task_a'] = await MultipartFile.fromFile(
        videoTaskAPath,
        filename: 'task_a.mp4',
      );
    }
    if (videoTaskBPath != null && videoTaskBPath.isNotEmpty) {
      fields['video_task_b'] = await MultipartFile.fromFile(
        videoTaskBPath,
        filename: 'task_b.mp4',
      );
    }
    if (videoTaskCPath != null && videoTaskCPath.isNotEmpty) {
      fields['video_task_c'] = await MultipartFile.fromFile(
        videoTaskCPath,
        filename: 'task_c.mp4',
      );
    }

    final resp = await _dio.post(
      '/sessions/upload',
      data: FormData.fromMap(fields),
      onSendProgress: onProgress,
    );
    return Map<String, dynamic>.from(resp.data as Map);
  }
}
