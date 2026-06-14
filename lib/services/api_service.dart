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

  Future<Map<String, dynamic>> uploadSession({
    required SessionData session,
    required String videoPath,
    void Function(int sent, int total)? onProgress,
  }) async {
    // Build form fields — always include session JSON
    final fields = <String, dynamic>{
      'session_json': MultipartFile.fromString(
        jsonEncode(session.toJson()),
        filename: 'session.json',
      ),
    };

    // Fix: guard empty path — MultipartFile.fromFile('') throws PathNotFoundException.
    // Video is optional; analysis proceeds with questionnaire + gaze data alone.
    if (videoPath.isNotEmpty) {
      fields['video'] = await MultipartFile.fromFile(
        videoPath,
        filename: 'session_video.mp4',
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
