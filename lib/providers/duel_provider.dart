import 'package:flutter/foundation.dart';
import 'package:veducation_app/models/duel_model.dart';
import 'package:veducation_app/services/api_service.dart';

class DuelProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  DailyDuelModel? _todayDuel;
  Map<String, dynamic>? _todayRegistrationStatus;
  List<QuestionModel> _questions = [];
  bool _isLoading = false;
  String? _errorMessage;

  DailyDuelModel? get todayDuel => _todayDuel;
  Map<String, dynamic>? get todayRegistrationStatus =>
      _todayRegistrationStatus;
  bool get isRegisteredForToday =>
      _todayRegistrationStatus?['registered'] == true;
  bool get hasSubmittedToday =>
      _todayRegistrationStatus?['attempt_submitted'] == true;
  String? get todayRegistrationId =>
      _todayRegistrationStatus?['registration_id']?.toString();
  Map<String, dynamic>? get todayResult {
    final result = _todayRegistrationStatus?['result'];
    if (result is Map) return Map<String, dynamic>.from(result);
    return null;
  }
  List<QuestionModel> get questions => _questions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadTodayDuel() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getTodayDuel();
      if (response.statusCode == 200) {
        _todayDuel = DailyDuelModel.fromJson(response.data);
        await loadTodayRegistrationStatus(notify: false);
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _todayDuel = null;
      _todayRegistrationStatus = null;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> loadTodayRegistrationStatus({bool notify = true}) async {
    final duel = _todayDuel;
    if (duel == null) {
      _todayRegistrationStatus = null;
      if (notify) notifyListeners();
      return;
    }

    try {
      final response = await _apiService.getDuelRegistrationStatus(duel.id);
      if (response.statusCode == 200 && response.data is Map) {
        _todayRegistrationStatus =
            Map<String, dynamic>.from(response.data as Map);
      }
    } catch (_) {
      _todayRegistrationStatus = null;
    }

    if (notify) notifyListeners();
  }

  Future<void> loadQuestions(String duelId, String language) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiService.getDuelQuestions(duelId);
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        _questions = data.map((json) => QuestionModel.fromJson(json, language)).toList();
      }
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}

