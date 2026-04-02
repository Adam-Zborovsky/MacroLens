import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/case_file.dart';
import 'auth_service.dart';

class ApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;
  ApiException({required this.code, required this.message, this.statusCode});
  @override
  String toString() => '$code: $message';
}

class ApiService {
  final String baseUrl;
  final AuthService authService;

  ApiService({required this.baseUrl, required this.authService});

  Future<Map<String, String>> get _headers async {
    final token = await authService.getIdToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // ─── Captures ────────────────────────────────────────────────────────────

  /// Submit a photo for Gemini 2.5 Flash analysis.
  /// Returns the completed Case File.
  Future<Map<String, dynamic>> submitCapture(File imageFile, {String? sessionGroupId}) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final mimeType = imageFile.path.endsWith('.png') ? 'image/png' : 'image/jpeg';

    final body = <String, dynamic>{
      'imageBase64': base64Image,
      'mimeType':    mimeType,
      if (sessionGroupId != null) 'sessionGroupId': sessionGroupId,
    };

    final headers = await _headers;
    final response = await http
        .post(
          Uri.parse('$baseUrl/api/v1/captures'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 30));

    return _handleResponse(response);
  }

  // ─── Case Files ───────────────────────────────────────────────────────────

  Future<List<CaseFile>> fetchCaseFiles({String? date, String? query, int page = 1}) async {
    final params = <String, String>{
      if (date  != null) 'date':  date,
      if (query != null) 'q':     query,
      'page':  page.toString(),
      'limit': '20',
    };

    final headers = await _headers;
    final uri = Uri.parse('$baseUrl/api/v1/meals/case-files').replace(queryParameters: params);
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 15));
    final data = _handleResponse(response);

    return (data['caseFiles'] as List)
        .map((e) => CaseFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Map<String, dynamic>> fetchDailyTotals({DateTime? date}) async {
    final headers = await _headers;
    final dateStr = (date ?? DateTime.now()).toIso8601String().split('T')[0];
    final uri = Uri.parse('$baseUrl/api/v1/meals/case-files/daily-totals?date=$dateStr');
    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));
    return _handleResponse(response);
  }

  Future<CaseFile> patchCaseFile(String id, Map<String, dynamic> payload) async {
    final headers = await _headers;
    final response = await http
        .patch(
          Uri.parse('$baseUrl/api/v1/meals/case-files/$id'),
          headers: headers,
          body: jsonEncode(payload),
        )
        .timeout(const Duration(seconds: 15));
    return CaseFile.fromJson(_handleResponse(response));
  }

  Future<void> deleteCaseFile(String id) async {
    final headers = await _headers;
    final response = await http
        .delete(Uri.parse('$baseUrl/api/v1/meals/case-files/$id'), headers: headers)
        .timeout(const Duration(seconds: 10));
    _handleResponse(response);
  }

  // ─── Barcode ──────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> lookupBarcode(String barcode) async {
    final headers = await _headers;
    final response = await http
        .get(Uri.parse('$baseUrl/api/v1/barcode/$barcode'), headers: headers)
        .timeout(const Duration(seconds: 12));
    return _handleResponse(response);
  }

  // ─── Response handling ────────────────────────────────────────────────────

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final error = body['error'] as Map<String, dynamic>? ?? {};
    throw ApiException(
      code:       error['code']    as String? ?? 'ERR_UNKNOWN',
      message:    error['message'] as String? ?? 'An unexpected error occurred.',
      statusCode: response.statusCode,
    );
  }
}
