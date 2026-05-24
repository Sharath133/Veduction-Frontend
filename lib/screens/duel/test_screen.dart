import 'dart:async';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:veducation_app/models/duel_model.dart';
import 'package:veducation_app/services/api_service.dart';
import 'package:veducation_app/screens/duel/test_result_screen.dart';

class TestScreen extends StatefulWidget {
  final String duelId;
  final String registrationId;
  final String language;

  const TestScreen({
    super.key,
    required this.duelId,
    required this.registrationId,
    required this.language,
  });

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final _apiService = ApiService();
  List<QuestionModel> _questions = [];
  int _currentQuestionIndex = 0;
  Map<int, String?> _answers = {};
  int _timeRemainingSeconds = 0;
  Timer? _timer;
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _isTestSubmitted = false;
  String? _attemptId;
  /// Server duel duration (minutes); null if older API omitted it.
  int? _serverTimeLimitMinutes;
  /// True only after POST /duel/timer-start succeeds (or syncs).
  bool _serverClockStarted = false;
  bool _isStartingClock = false;

  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static int? _parsePositiveInt(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw > 0 ? raw : null;
    if (raw is num) {
      final v = raw.toInt();
      return v > 0 ? v : null;
    }
    return int.tryParse(raw.toString());
  }

  int _fallbackDurationSeconds() {
    final m = _serverTimeLimitMinutes;
    if (m != null && m > 0) return m * 60;
    return _questions.length * 60;
  }

  Future<void> _loadQuestions() async {
    try {
      final startResponse = await _apiService.startTest(
        widget.duelId,
        widget.language,
      );

      if (startResponse.statusCode != 200) {
        throw Exception('Failed to start test');
      }

      final startBody = Map<String, dynamic>.from(startResponse.data as Map);
      final attemptId = startBody['attempt_id']?.toString();
      if (attemptId == null || attemptId.isEmpty) {
        throw Exception('Invalid attempt_id received from server');
      }

      if (startBody['already_submitted'] == true) {
        if (!mounted) return;
        setState(() {
          _attemptId = attemptId;
          _isTestSubmitted = true;
          _isLoading = false;
        });
        _openResultFromPayload(startBody);
        return;
      }

      final questionsResponse = await _apiService.getDuelQuestions(widget.duelId);
      if (questionsResponse.statusCode != 200) {
        throw Exception('Failed to load questions');
      }

      final List<dynamic> rawQuestions = questionsResponse.data is List
          ? questionsResponse.data as List<dynamic>
          : <dynamic>[];

      if (!mounted) return;

      setState(() {
        _attemptId = attemptId;
        _serverTimeLimitMinutes = _parsePositiveInt(startBody['time_limit_minutes']);
        _questions = rawQuestions
            .map((json) => QuestionModel.fromJson(
                  Map<String, dynamic>.from(json as Map),
                  widget.language,
                ))
            .toList();
        _isLoading = false;
        _serverClockStarted = false;
        _timeRemainingSeconds = 0;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _attemptId = null;
        });
        _showError('Failed to load test: $e');
      }
    }
  }

  Future<void> _onBeginTest() async {
    if (_isStartingClock || _attemptId == null || _questions.isEmpty) return;

    setState(() => _isStartingClock = true);
    try {
      final response = await _apiService.startAttemptTimer(_attemptId!);
      if (response.statusCode == 200) {
        final body = Map<String, dynamic>.from(response.data as Map);
        if (body['already_submitted'] == true) {
          if (!mounted) return;
          setState(() {
            _isTestSubmitted = true;
            _isStartingClock = false;
          });
          _openResultFromPayload(body);
          return;
        }

        final srRaw = body['seconds_remaining'];
        int seconds = 0;
        if (srRaw is int) {
          seconds = srRaw;
        } else if (srRaw is num) {
          seconds = srRaw.toInt();
        }
        final tlm = _parsePositiveInt(body['time_limit_minutes']);
        if (tlm != null) {
          _serverTimeLimitMinutes = tlm;
        }
        if (seconds <= 0) {
          if (mounted) {
            setState(() => _isStartingClock = false);
            await _submitTest();
          }
          return;
        }
        if (!mounted) return;
        setState(() {
          _timeRemainingSeconds = seconds;
          _serverClockStarted = true;
          _isStartingClock = false;
        });
        _startTimer();
        return;
      }
      if (mounted) {
        _showError(response.data?.toString() ?? 'Could not start timer');
      }
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data['detail']?.toString() ?? e.message)
          : e.message;
      final msgLower = (msg ?? '').toLowerCase();
      if (msgLower.contains('already submitted') ||
          msgLower.contains('test already submitted')) {
        await _submitTest(forceResultLookup: true);
        return;
      }
      if (mounted) {
        _showError(msg ?? 'Could not start timer. Check connection and try again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Could not start timer: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isStartingClock = false);
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeRemainingSeconds > 0) {
        setState(() => _timeRemainingSeconds--);
      } else {
        _timer?.cancel();
        _submitTest();
      }
    });
  }

  String _formatTime(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  void _selectAnswer(String answer) {
    if (!_serverClockStarted || _isTestSubmitted) return;
    setState(() {
      _answers[_currentQuestionIndex] = answer;
    });
    _saveAnswer(_currentQuestionIndex, answer);
  }

  Future<void> _saveAnswer(int questionIndex, String answer) async {
    try {
      await _apiService.submitAnswer({
        'registration_id': widget.registrationId,
        'question_id': _questions[questionIndex].id,
        'selected_answer': answer,
      });
    } catch (_) {}
  }

  void _goToQuestion(int index) {
    if (!_serverClockStarted || _isTestSubmitted) return;
    if (index >= 0 && index < _questions.length) {
      setState(() => _currentQuestionIndex = index);
    }
  }

  TestResultScreen? _buildResultFromPayload(dynamic data) {
    if (data is! Map) return null;
    final map = Map<String, dynamic>.from(data);
    final tm = map['total_marks'];
    if (tm is! num) return null;
    double? tts;
    final rawT = map['time_taken_seconds'];
    if (rawT is num) tts = rawT.toDouble();

    int? ca;
    int? wa;
    int? ua;
    final c = map['correct_answers'];
    if (c is int) ca = c;
    if (c is num) ca = c.toInt();
    final w = map['wrong_answers'];
    if (w is int) wa = w;
    if (w is num) wa = w.toInt();
    final u = map['unanswered'];
    if (u is int) ua = u;
    if (u is num) ua = u.toInt();

    return TestResultScreen(
      duelId: widget.duelId,
      totalMarks: tm.toDouble(),
      timeTakenSeconds: tts,
      correctAnswers: ca,
      wrongAnswers: wa,
      unanswered: ua,
    );
  }

  void _openResultFromPayload(dynamic data) {
    final result = _buildResultFromPayload(data);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            result ?? TestResultScreen(duelId: widget.duelId, totalMarks: 0),
      ),
    );
  }

  Future<void> _submitTest({bool forceResultLookup = false}) async {
    if (_isSubmitting && !forceResultLookup) return;

    if (_isTestSubmitted && !forceResultLookup) {
      if (mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
      return;
    }

    if (_attemptId == null || _attemptId!.isEmpty) {
      _showError('Test not started properly. Please restart the test.');
      return;
    }

    setState(() => _isSubmitting = true);
    _timer?.cancel();

    try {
      final response = await _apiService.submitTest(_attemptId!);
      if (response.statusCode == 200) {
        setState(() => _isTestSubmitted = true);
        if (mounted) {
          _openResultFromPayload(response.data);
        }
      } else {
        final errorMsg = response.data is Map
            ? (response.data['detail']?.toString() ?? 'Failed to submit test')
            : 'Failed to submit test';
        final errorMsgLower = errorMsg.toLowerCase();
        if (errorMsgLower.contains('already submitted') ||
            errorMsgLower.contains('test already submitted')) {
          setState(() => _isTestSubmitted = true);
          if (mounted) {
            await _submitTest(forceResultLookup: true);
          }
          return;
        }
        _showError(errorMsg);
      }
    } catch (e) {
      String errorMessage = 'Error submitting test';
      var isAlreadySubmitted = false;

      if (e is DioException && e.response != null) {
        final detail = e.response?.data is Map
            ? (e.response!.data['detail'] ?? e.response!.data['message'])
            : null;
        if (detail != null) {
          final detailStr = detail.toString().toLowerCase();
          if (detailStr.contains('already submitted') ||
              detailStr.contains('test already submitted')) {
            isAlreadySubmitted = true;
            setState(() => _isTestSubmitted = true);
            if (mounted) {
              await _submitTest(forceResultLookup: true);
            }
            return;
          }
          errorMessage = detail.toString();
        } else {
          errorMessage = 'Invalid test data. Please try again.';
        }
      } else if (e.toString().contains('404')) {
        errorMessage = 'Test session not found. Please restart the test.';
      } else {
        errorMessage = 'Error submitting test: ${e.toString()}';
      }

      if (!isAlreadySubmitted) {
        _showError(errorMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Test')),
        body: const Center(child: Text('No questions available')),
      );
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final selectedAnswer = _answers[_currentQuestionIndex];
    final previewSeconds = _fallbackDurationSeconds();
    final timerLabel = _serverClockStarted
        ? _formatTime(_timeRemainingSeconds)
        : _formatTime(previewSeconds);

    return PopScope(
      canPop: _isTestSubmitted || !_serverClockStarted,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        if (_isTestSubmitted) {
          if (mounted) {
            Navigator.popUntil(context, (route) => route.isFirst);
          }
          return;
        }

        if (!_serverClockStarted) {
          if (mounted) Navigator.pop(context);
          return;
        }

        final shouldExit = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit Test?'),
            content: const Text(
              'Are you sure you want to exit? Your attempt will be submitted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Exit'),
              ),
            ],
          ),
        );
        if (shouldExit == true && mounted) {
          await _submitTest();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_currentQuestionIndex + 1} of ${_questions.length}'),
          actions: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _serverClockStarted && _timeRemainingSeconds < 60
                    ? Colors.red
                    : Colors.blue,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  timerLabel,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        body: Stack(
          children: [
            Column(
              children: [
                if (_isTestSubmitted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.green.shade100,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Test submitted successfully!',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentQuestion.getQuestionText(widget.language),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ...currentQuestion.getOptions(widget.language).entries.map((entry) {
                                  final isSelected = selectedAnswer == entry.key;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: InkWell(
                                      onTap: _isTestSubmitted || !_serverClockStarted
                                          ? null
                                          : () => _selectAnswer(entry.key),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isSelected
                                              ? Colors.blue.shade50
                                              : Colors.grey.shade100,
                                          border: Border.all(
                                            color: isSelected ? Colors.blue : Colors.grey.shade300,
                                            width: isSelected ? 2 : 1,
                                          ),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: isSelected ? Colors.blue : Colors.grey,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  entry.key,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Text(
                                                entry.value,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight:
                                                      isSelected ? FontWeight.w500 : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                            if (isSelected)
                                              const Icon(Icons.check_circle, color: Colors.blue),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 4,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _currentQuestionIndex > 0 && _serverClockStarted && !_isTestSubmitted
                                ? () => _goToQuestion(_currentQuestionIndex - 1)
                                : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Previous'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey,
                            ),
                          ),
                          _isTestSubmitted
                              ? ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.popUntil(context, (route) => route.isFirst);
                                  },
                                  icon: const Icon(Icons.check_circle),
                                  label: const Text('Done'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                )
                              : ElevatedButton.icon(
                                  onPressed: !_serverClockStarted || _isSubmitting
                                      ? null
                                      : () {
                                          if (_currentQuestionIndex < _questions.length - 1) {
                                            _goToQuestion(_currentQuestionIndex + 1);
                                          } else {
                                            _submitTest();
                                          }
                                        },
                                  icon: Icon(_currentQuestionIndex < _questions.length - 1
                                      ? Icons.arrow_forward
                                      : Icons.check),
                                  label: Text(_currentQuestionIndex < _questions.length - 1
                                      ? 'Next'
                                      : 'Submit'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: List.generate(_questions.length, (index) {
                          final hasAnswer = _answers[index] != null;
                          final isCurrent = index == _currentQuestionIndex;
                          return InkWell(
                            onTap: _serverClockStarted && !_isTestSubmitted
                                ? () => _goToQuestion(index)
                                : null,
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? Colors.blue
                                    : hasAnswer
                                        ? Colors.green
                                        : Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isCurrent ? Colors.blue.shade700 : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: isCurrent || hasAnswer ? Colors.white : Colors.black,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (!_serverClockStarted && !_isTestSubmitted)
              Positioned.fill(
                child: ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: Card(
                        elevation: 8,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Ready to begin?',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _serverTimeLimitMinutes != null
                                    ? 'Time limit: $_serverTimeLimitMinutes minutes (from server).'
                                    : 'Time limit: one minute per question (${_questions.length} questions).',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'The countdown starts only after you tap Begin — '
                                'loading time is not counted.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton(
                                onPressed: _isStartingClock ? null : _onBeginTest,
                                child: _isStartingClock
                                    ? const SizedBox(
                                        height: 22,
                                        width: 22,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Begin'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
