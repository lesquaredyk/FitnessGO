import '../../../core/network/api_client.dart';

class AuthApi {
  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) {
    return ApiClient.post(
      '/auth/login',
      body: {'username': username, 'password': password},
    );
  }

  static Future<Map<String, dynamic>> requestSignupOtp({
    required String username,
    required String email,
  }) {
    return ApiClient.post(
      '/auth/request-signup-otp',
      body: {'Username': username, 'Email': email},
    );
  }

  static Future<Map<String, dynamic>> register({
    required String username,
    required String email,
    required String password,
    required String fullname,
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String goal,
    required String activityLevel,
    double? desiredWeight,
    required String hasHealthConditions,
    String? whatHealthConditions,
    required String otp,
  }) {
    return ApiClient.post(
      '/auth/register',
      body: {
        'Username': username,
        'Email': email,
        'Password': password,
        'Fullname': fullname,
        'Age': age,
        'Gender': gender,
        'Height': height,
        'Weight': weight,
        'Goal': goal,
        'ActivityLevel': activityLevel,
        'DesiredWeight': desiredWeight,
        'HasHealthConditions': hasHealthConditions,
        'WhatHealthConditions': whatHealthConditions,
        'Otp': otp,
      },
    );
  }

  static Future<Map<String, dynamic>> requestPasswordResetOtp({
    required String email,
  }) {
    return ApiClient.post(
      '/auth/request-password-reset-otp',
      body: {'Email': email},
    );
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String otp,
    required String newPassword,
  }) {
    return ApiClient.post(
      '/auth/reset-password',
      body: {'Email': email, 'Otp': otp, 'NewPassword': newPassword},
    );
  }

  static Future<Map<String, dynamic>> getProfile(int userId) {
    return ApiClient.get('/profile/$userId');
  }

  static Future<Map<String, dynamic>> updateProfile({
    required int userId,
    required String username,
    required String fullname,
    required int age,
    required String gender,
    required double height,
    required double weight,
    required String activityLevel,
    required String hasHealthConditions,
    String? whatHealthConditions,
  }) {
    return ApiClient.put(
      '/profile/$userId',
      body: {
        'Username': username,
        'Fullname': fullname,
        'Age': age,
        'Gender': gender,
        'Height': height,
        'Weight': weight,
        'ActivityLevel': activityLevel,
        'HasHealthConditions': hasHealthConditions,
        'WhatHealthConditions': whatHealthConditions,
      },
    );
  }

  static Future<Map<String, dynamic>> uploadProfilePhoto({
    required int userId,
    required String filePath,
  }) {
    return ApiClient.uploadFile(
      '/profile/$userId/photo',
      fieldName: 'image',
      filePath: filePath,
    );
  }
}
