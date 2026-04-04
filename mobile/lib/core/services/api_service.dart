import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:macro_lens_mobile/core/models/meal.dart';
import 'package:macro_lens_mobile/core/models/preset.dart';

class ApiService {
  static const String baseUrl = 'https://macrolens.adamzborovsky.com/api/v1';
  // static const String baseUrl = 'http://localhost:3000/api/v1'; // Local Dev
  // static const String baseUrl = 'https://macrolens.adamzborovsky.com/api/v1'; // Production
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      return data;
    } else {
      throw Exception(
        jsonDecode(response.body)['error']?['message'] ?? 'Login failed',
      );
    }
  }

  Future<Map<String, dynamic>> signup(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      return data;
    } else {
      throw Exception(
        jsonDecode(response.body)['error']?['message'] ?? 'Signup failed',
      );
    }
  }

  bool get isAuthenticated => _token != null;

  Future<Map<String, dynamic>> uploadCapture(
    String base64Image, {
    String? sessionGroupId,
  }) async {
    final url = Uri.parse('$baseUrl/captures');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'imageBase64': base64Image,
        'mimeType': 'image/jpeg',
        if (sessionGroupId != null) 'sessionGroupId': sessionGroupId,
      }),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload capture: ${response.body}');
    }
  }

  Future<CaptureStatus> getCaptureStatus(String captureId) async {
    final url = Uri.parse('$baseUrl/captures/$captureId');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return CaptureStatus.fromJson(data);
    } else {
      throw Exception('Failed to fetch capture status');
    }
  }

  Future<void> saveMeal(String mealId, DetectedItem updatedItem) async {
    final url = Uri.parse('$baseUrl/meals/$mealId');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'detectedItems': [
          {
            'itemId': updatedItem.itemId,
            'name': updatedItem.name,
            'massGrams': updatedItem.massGrams,
            'verificationStatus': 'user_confirmed',
          },
        ],
        'nutritionDataVerified': true,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to save meal log: ${response.body}');
    }
  }

  Future<List<Meal>> fetchMeals() async {
    final url = Uri.parse('$baseUrl/meals');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Meal.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch meal history');
    }
  }

  Future<Meal> createManualMeal({
    required String name,
    required double calories,
    required double proteinGrams,
    required double carbohydratesGrams,
    required double fatGrams,
  }) async {
    final url = Uri.parse('$baseUrl/meals');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode({
        'name': name,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbohydratesGrams': carbohydratesGrams,
        'fatGrams': fatGrams,
      }),
    );

    if (response.statusCode == 201) {
      return Meal.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to log manual meal');
    }
  }

  Future<Map<String, dynamic>> getNutritionByBarcode(String barcode) async {
    final url = Uri.parse('$baseUrl/barcode/$barcode');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw Exception(
        data['error']?['message'] ?? 'Failed to fetch barcode data',
      );
    }
  }

  Future<void> updateGoals(Map<String, dynamic> goals) async {
    final url = Uri.parse('$baseUrl/users/metrics');

    final response = await http.patch(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(goals),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update goals');
    }
  }

  // Preset Methods
  Future<List<Preset>> fetchPresets() async {
    final url = Uri.parse('$baseUrl/presets');

    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Preset.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch presets');
    }
  }

  Future<Preset> createPreset(Preset preset) async {
    final url = Uri.parse('$baseUrl/presets');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $_token',
      },
      body: jsonEncode(preset.toJson()),
    );

    if (response.statusCode == 201) {
      return Preset.fromJson(jsonDecode(response.body));
    } else {
      throw Exception('Failed to create preset');
    }
  }

  Future<void> deletePreset(String presetId) async {
    final url = Uri.parse('$baseUrl/presets/$presetId');

    final response = await http.delete(
      url,
      headers: {'Authorization': 'Bearer $_token'},
    );

    if (response.statusCode != 204) {
      throw Exception('Failed to delete preset');
    }
  }
}

class CaptureStatus {
  final String status;
  final Meal? meal;
  final String? errorCode;

  CaptureStatus({required this.status, this.meal, this.errorCode});

  factory CaptureStatus.fromJson(Map<String, dynamic> json) {
    return CaptureStatus(
      status: json['analysisStatus'],
      meal: json['resultMealId'] != null
          ? Meal.fromJson(json['resultMealId'])
          : null,
      errorCode: json['analysisError']?['code'],
    );
  }
}
