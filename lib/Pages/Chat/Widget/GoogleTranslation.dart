import 'dart:convert';
import 'dart:io';
import 'package:googleapis/translate/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/services.dart' show rootBundle;

class GoogleTranslationService {
  static const _scopes = [TranslateApi.cloudTranslationScope];

  late TranslateApi _translateApi;
  bool isInitialized = false;


  Future<void> initialize(String credentialsPath) async {
    try {
      // Use rootBundle to load the asset
      final jsonCredentials = await rootBundle.loadString(credentialsPath);
      final credentials =
          ServiceAccountCredentials.fromJson(jsonDecode(jsonCredentials));
      final authClient = await clientViaServiceAccount(credentials, _scopes);
      _translateApi = TranslateApi(authClient);
      isInitialized = true;
    } catch (e) {
      print("Error initializing translation service: $e");
      throw Exception("Failed to initialize translation service");
    }
  }

  Future<String> translateText(String message, String targetLanguage) async {
    if (!isInitialized) {
      throw Exception("Translation service is not initialized");
    }

    try {
      final request = TranslateTextRequest(
        contents: [message],
        targetLanguageCode: targetLanguage,
        mimeType: "text/plain",
      );

      final response = await _translateApi.projects.translateText(
        request,
        'projects/smsecure', // Replace with your actual Google Cloud Project ID
      );

      if (response.translations != null && response.translations!.isNotEmpty) {
        return response.translations!.first.translatedText ?? "";
      } else {
        throw Exception("Translation failed: No translations available.");
      }
    } catch (e) {
      print("Error translating text: $e");
      throw Exception("Translation failed. Please try again later.");
    }
  }
}
