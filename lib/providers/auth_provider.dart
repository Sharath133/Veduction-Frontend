import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:veducation_app/models/user_model.dart';
import 'package:veducation_app/services/api_service.dart';

class AuthProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  UserModel? _user;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  UserModel? get user => _user;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token != null) {
      _isAuthenticated = true;
      await loadUserProfile();
    }
  }

  Future<bool> sendOTP(String mobileNumber, String purpose) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.sendOTP(mobileNumber, purpose);
      _isLoading = false;
      notifyListeners();
      return response.statusCode == 200;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> verifyOTP(String mobileNumber, String otpCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.verifyOTP(mobileNumber, otpCode);
      if (response.statusCode == 200) {
        final data = response.data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', data['access_token']);
        await prefs.setString('refresh_token', data['refresh_token']);
        
        _isAuthenticated = true;
        await loadUserProfile();
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      _isLoading = false;
      _errorMessage = 'Invalid OTP';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> loadUserProfile() async {
    try {
      final response = await _apiService.getUserProfile();
      if (response.statusCode == 200) {
        _user = UserModel.fromJson(response.data);
        notifyListeners();
      }
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  String? _messageFromDio(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['detail'] != null) {
      return data['detail'].toString();
    }
    return e.message;
  }

  /// Returns null on success, or an error message.
  Future<String?> updateUserProfile({String? name, String? upiMobile}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (upiMobile != null) body['upi_mobile'] = upiMobile;
      final response = await _apiService.updateUserProfile(body);
      if (response.statusCode == 200) {
        _user = UserModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return null;
      }
      _isLoading = false;
      notifyListeners();
      return 'Update failed';
    } on DioException catch (e) {
      _isLoading = false;
      _errorMessage = _messageFromDio(e);
      notifyListeners();
      return _messageFromDio(e);
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> sendMobileChangeOtp(String newMobileNumber) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response =
          await _apiService.sendProfileMobileChangeOtp(newMobileNumber);
      _isLoading = false;
      notifyListeners();
      if (response.statusCode == 200) return null;
      return 'Could not send OTP';
    } on DioException catch (e) {
      _isLoading = false;
      _errorMessage = _messageFromDio(e);
      notifyListeners();
      return _messageFromDio(e);
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  /// Returns null on success, or an error message.
  Future<String?> confirmMobileChange(String newMobileNumber, String otpCode) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final response = await _apiService.confirmProfileMobileChange(
        newMobileNumber,
        otpCode,
      );
      if (response.statusCode == 200) {
        _user = UserModel.fromJson(response.data);
        _isLoading = false;
        notifyListeners();
        return null;
      }
      _isLoading = false;
      notifyListeners();
      return 'Verification failed';
    } on DioException catch (e) {
      _isLoading = false;
      _errorMessage = _messageFromDio(e);
      notifyListeners();
      return _messageFromDio(e);
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
    
    _user = null;
    _isAuthenticated = false;
    notifyListeners();
  }
}

