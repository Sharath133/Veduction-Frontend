import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:veducation_app/models/leaderboard_model.dart';
import 'package:veducation_app/services/api_service.dart';

class LeaderboardProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  LeaderboardResponseModel? _leaderboard;
  LeaderboardEntryModel? _myEntry;
  bool _myRankMissing = false;
  bool _isLoading = false;
  String? _errorMessage;

  LeaderboardResponseModel? get leaderboard => _leaderboard;
  LeaderboardEntryModel? get myEntry => _myEntry;
  bool get myRankMissing => _myRankMissing;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  bool get isEmptyBoard =>
      _leaderboard != null &&
      _leaderboard!.entries.isEmpty &&
      _leaderboard!.total == 0;

  Future<void> loadForDuel(String duelId) async {
    if (duelId.isEmpty) {
      _errorMessage = 'No duel selected.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final lbResponse = await _apiService.getLeaderboard(duelId);
      if (lbResponse.statusCode != 200) {
        _isLoading = false;
        _errorMessage = _messageFromResponse(lbResponse.data) ??
            'Could not load leaderboard (${lbResponse.statusCode}).';
        notifyListeners();
        return;
      }

      _leaderboard = LeaderboardResponseModel.fromJson(
        Map<String, dynamic>.from(lbResponse.data as Map),
      );

      _myEntry = null;
      _myRankMissing = false;

      try {
        final rankResponse = await _apiService.getMyRank(duelId);
        if (rankResponse.statusCode == 200) {
          _myEntry = MyRankResponseModel.fromJson(
            Map<String, dynamic>.from(rankResponse.data as Map),
          ).entry;
        }
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) {
          _myRankMissing = true;
          _myEntry = null;
        } else {
          _myEntry = null;
          _myRankMissing = false;
        }
      } catch (_) {
        _myEntry = null;
        _myRankMissing = false;
      }

      _isLoading = false;
      notifyListeners();
    } on DioException catch (e) {
      _isLoading = false;
      _errorMessage = _dioErrorMessage(e);
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString();
      notifyListeners();
    }
  }

  Future<void> refresh(String duelId) => loadForDuel(duelId);

  String? _messageFromResponse(dynamic data) {
    if (data is Map && data['detail'] != null) {
      final d = data['detail'];
      if (d is String) return d;
      if (d is List && d.isNotEmpty && d.first is Map) {
        return d.first['msg']?.toString();
      }
    }
    return null;
  }

  String _dioErrorMessage(DioException e) {
    final fromBody = _messageFromResponse(e.response?.data);
    if (fromBody != null && fromBody.isNotEmpty) return fromBody;
    if (e.message != null && e.message!.isNotEmpty) return e.message!;
    return 'Network error. Please try again.';
  }
}
