import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Use different base URLs based on platform
  static String get baseUrl {
    const configuredBaseUrl = String.fromEnvironment('API_BASE_URL');
    if (configuredBaseUrl.isNotEmpty) {
      return configuredBaseUrl;
    }

    if (kIsWeb) {
      return 'http://localhost:8000/api/v1';
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1'; // Android emulator
    } else {
      return 'http://localhost:8000/api/v1'; // iOS simulator
    }
  }

  late Dio _dio;

  ApiService() {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptor for auth token
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            // Handle token refresh or logout
            final prefs = await SharedPreferences.getInstance();
            await prefs.remove('access_token');
            await prefs.remove('refresh_token');
          }
          return handler.next(error);
        },
      ),
    );
  }

  // Auth endpoints
  Future<Response> sendOTP(String mobileNumber, String purpose) async {
    return await _dio.post('/auth/send-otp', data: {
      'mobile_number': mobileNumber,
      'purpose': purpose,
    });
  }

  Future<Response> verifyOTP(String mobileNumber, String otpCode) async {
    return await _dio.post('/auth/verify-otp', data: {
      'mobile_number': mobileNumber,
      'otp_code': otpCode,
    });
  }

  Future<Response> refreshToken(String refreshToken) async {
    return await _dio.post('/auth/refresh-token', data: {
      'refresh_token': refreshToken,
    });
  }

  // User endpoints
  Future<Response> getUserProfile() async {
    return await _dio.get('/user/profile');
  }

  Future<Response> updateUserProfile(Map<String, dynamic> data) async {
    return await _dio.put('/user/profile', data: data);
  }

  Future<Response> sendProfileMobileChangeOtp(String newMobileNumber) async {
    return await _dio.post(
      '/user/profile/mobile-change/send-otp',
      data: {'new_mobile_number': newMobileNumber},
    );
  }

  Future<Response> confirmProfileMobileChange(
    String newMobileNumber,
    String otpCode,
  ) async {
    return await _dio.post(
      '/user/profile/mobile-change/confirm',
      data: {
        'new_mobile_number': newMobileNumber,
        'otp_code': otpCode,
      },
    );
  }

  // Duel endpoints
  Future<Response> getTodayDuel() async {
    return await _dio.get('/duel/today');
  }

  Future<Response> registerDuel(Map<String, dynamic> data) async {
    return await _dio.post('/duel/register', data: data);
  }

  static String errorMessage(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] != null) {
        return data['detail'].toString();
      }
      final statusCode = error.response?.statusCode;
      if (statusCode == 403) {
        return 'Admin access required. Please sign in with an admin account.';
      }
      if (statusCode == 401) {
        return 'Your session expired. Please sign in again.';
      }
      return error.message ?? 'Request failed';
    }
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  Future<Response> getDuelRegistrationStatus(String duelId) async {
    return await _dio.get(
      '/duel/registration-status',
      queryParameters: {'duel_id': duelId},
    );
  }

  Future<Response> getDuelInstructions() async {
    return await _dio.get('/duel/instructions');
  }

  Future<Response> getDuelQuestions(String duelId) async {
    return await _dio
        .get('/duel/questions', queryParameters: {'duel_id': duelId});
  }

  Future<Response> startTest(String duelId, String language) async {
    return await _dio.post('/duel/start', data: {
      'duel_id': duelId,
      'language': language,
    });
  }

  /// Starts the server-side attempt clock after questions are loaded (or syncs remaining time).
  Future<Response> startAttemptTimer(String attemptId) async {
    return await _dio
        .post('/duel/timer-start', data: {'attempt_id': attemptId});
  }

  Future<Response> getTestStatus(String attemptId) async {
    return await _dio
        .get('/duel/status', queryParameters: {'attempt_id': attemptId});
  }

  Future<Response> submitAnswer(Map<String, dynamic> data) async {
    return await _dio.post('/duel/answer', data: data);
  }

  Future<Response> submitTest(String attemptId) async {
    if (attemptId.isEmpty) {
      throw Exception('Attempt ID cannot be empty');
    }
    return await _dio.post('/duel/submit', data: {'attempt_id': attemptId});
  }

  // Leaderboard endpoints
  Future<Response> getLeaderboard(
    String duelId, {
    int limit = 100,
    int offset = 0,
  }) async {
    return await _dio.get(
      '/leaderboard/$duelId',
      queryParameters: {
        'limit': limit,
        'offset': offset,
      },
    );
  }

  Future<Response> getMyRank(String duelId) async {
    return await _dio.get('/leaderboard/my-rank/$duelId');
  }

  // Payment endpoints
  Future<Response> createPaymentOrder(Map<String, dynamic> data) async {
    return await _dio.post('/payment/create-order', data: data);
  }

  Future<Response> verifyPayment(Map<String, dynamic> data) async {
    return await _dio.post('/payment/verify', data: data);
  }

  Future<Response> bypassPaymentForTesting(Map<String, dynamic> data) async {
    return await _dio.post('/payment/bypass-for-testing', data: data);
  }

  // Rewards endpoints
  Future<Response> getRewardsHistory() async {
    return await _dio.get('/rewards/history');
  }

  // Referral endpoints
  Future<Response> getReferralInfo() async {
    return await _dio.get('/referral/info');
  }

  Future<Response> applyReferralCode(String code) async {
    return await _dio.post('/referral/apply-code', data: {'code': code});
  }

  // Loyalty endpoints
  Future<Response> getLoyaltyPoints() async {
    return await _dio.get('/loyalty/points');
  }

  Future<Response> redeemPoints(int points) async {
    return await _dio.post('/loyalty/redeem', data: {'points': points});
  }

  // Admin endpoints
  Future<Response> adminGetStats() async {
    return await _dio.get('/admin/stats/overview');
  }

  Future<Response> adminGetDuelStats(String duelId) async {
    return await _dio.get('/admin/stats/duel/$duelId');
  }

  Future<Response> adminListDuels(
      {int? skip, int? limit, String? status}) async {
    final params = <String, dynamic>{};
    if (skip != null) params['skip'] = skip;
    if (limit != null) params['limit'] = limit;
    if (status != null) params['status'] = status;
    return await _dio.get('/admin/duels', queryParameters: params);
  }

  Future<Response> adminCreateDuel(Map<String, dynamic> data) async {
    return await _dio.post('/admin/duels', data: data);
  }

  Future<Response> adminUpdateDuel(
      String duelId, Map<String, dynamic> data) async {
    return await _dio.put('/admin/duels/$duelId', data: data);
  }

  Future<Response> adminGetDuel(String duelId) async {
    return await _dio.get('/admin/duels/$duelId');
  }

  Future<Response> adminAddQuestionToDuel(
      String duelId, Map<String, dynamic> data) async {
    return await _dio.post('/admin/duels/$duelId/questions', data: data);
  }

  Future<Response> adminListPYQs(
      {int? skip, int? limit, int? year, String? subject}) async {
    final params = <String, dynamic>{};
    if (skip != null) params['skip'] = skip;
    if (limit != null) params['limit'] = limit;
    if (year != null) params['year'] = year;
    if (subject != null) params['subject'] = subject;
    return await _dio.get('/admin/pyqs', queryParameters: params);
  }

  Future<Response> adminCreatePYQ(Map<String, dynamic> data) async {
    return await _dio.post('/admin/pyqs', data: data);
  }

  Future<Response> adminAddQuestionToPYQ(
      String pyqId, Map<String, dynamic> data) async {
    return await _dio.post('/admin/pyqs/$pyqId/questions', data: data);
  }

  Future<Response> adminUploadPYQCSV(String pyqId, FormData formData) async {
    return await _dio.post(
      '/admin/pyqs/$pyqId/upload-csv',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> getPYQSections() async {
    return await _dio.get('/pyqs/sections');
  }

  Future<Response> adminListPYQSections() async {
    return await _dio.get('/admin/pyq-sections');
  }

  Future<Response> adminCreatePYQSection(Map<String, dynamic> data) async {
    return await _dio.post('/admin/pyq-sections', data: data);
  }

  Future<Response> adminUpdatePYQSection(
      String sectionId, Map<String, dynamic> data) async {
    return await _dio.put('/admin/pyq-sections/$sectionId', data: data);
  }

  Future<Response> adminUploadPYQSectionPdf(
      String sectionId, FormData formData) async {
    return await _dio.post(
      '/admin/pyq-sections/$sectionId/pdfs',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> adminListUsers(
      {int? skip, int? limit, bool? isActive}) async {
    final params = <String, dynamic>{};
    if (skip != null) params['skip'] = skip;
    if (limit != null) params['limit'] = limit;
    if (isActive != null) params['is_active'] = isActive;
    return await _dio.get('/admin/users', queryParameters: params);
  }

  Future<Response> adminToggleUserActive(String userId) async {
    return await _dio.put('/admin/users/$userId/toggle-active');
  }

  Future<Response> adminDeleteDuel(String duelId) async {
    return await _dio.delete('/admin/duels/$duelId');
  }

  Future<Response> adminGetDailyStats({int days = 14}) async {
    return await _dio
        .get('/admin/stats/daily', queryParameters: {'days': days});
  }

  Future<Response> adminGetTopRankers(String duelDate, {int limit = 10}) async {
    return await _dio.get(
      '/admin/stats/top-rankers',
      queryParameters: {'duel_date': duelDate, 'limit': limit},
    );
  }

  Future<Response> adminGetDuelInstructions() async {
    return await _dio.get('/admin/duel-instructions');
  }

  Future<Response> adminUpdateDuelInstructions(
    String instructionsEn,
    String instructionsTe,
  ) async {
    return await _dio.put(
      '/admin/duel-instructions',
      data: {
        'instructions_en': instructionsEn,
        'instructions_te': instructionsTe,
      },
    );
  }

  Future<Response> adminListSupportTickets({
    int skip = 0,
    int limit = 50,
    String? status,
    String? userId,
  }) async {
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (status != null && status.isNotEmpty) params['status'] = status;
    if (userId != null && userId.isNotEmpty) params['user_id'] = userId;
    return await _dio.get('/admin/support/tickets', queryParameters: params);
  }

  Future<Response> adminUpdateSupportTicketStatus(
      String ticketId, String status) async {
    return await _dio
        .patch('/admin/support/tickets/$ticketId', data: {'status': status});
  }

  Future<Response> adminListFeedback({
    int skip = 0,
    int limit = 50,
    String? category,
  }) async {
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (category != null && category.isNotEmpty) params['category'] = category;
    return await _dio.get('/admin/feedback', queryParameters: params);
  }

  Future<Response> adminMessageUser(
      String userId, String title, String body) async {
    return await _dio.post('/admin/users/$userId/message',
        data: {'title': title, 'body': body});
  }

  Future<Response> adminUploadDuelCsv(String duelId, FormData formData) async {
    return await _dio.post(
      '/admin/duels/$duelId/upload-csv',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> adminUploadPYQPdf(String pyqId, FormData formData) async {
    return await _dio.post(
      '/admin/pyqs/$pyqId/upload-pdf',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> getUserAdminMessages({int limit = 50}) async {
    return await _dio
        .get('/user/admin-messages', queryParameters: {'limit': limit});
  }

  Future<Response> markUserAdminMessageRead(String messageId) async {
    return await _dio.patch('/user/admin-messages/$messageId/read');
  }

  /// Support: raise ticket (authenticated).
  Future<Response> createSupportTicket(Map<String, dynamic> data) async {
    return await _dio.post('/support/tickets', data: data);
  }

  /// Support: list current user's tickets.
  Future<Response> listMySupportTickets({
    int skip = 0,
    int limit = 50,
    String? status,
  }) async {
    final params = <String, dynamic>{'skip': skip, 'limit': limit};
    if (status != null && status.isNotEmpty) {
      params['status'] = status;
    }
    return await _dio.get('/support/tickets', queryParameters: params);
  }

  /// Feedback / suggestion (authenticated).
  Future<Response> submitFeedback(Map<String, dynamic> data) async {
    return await _dio.post('/feedback', data: data);
  }
}
