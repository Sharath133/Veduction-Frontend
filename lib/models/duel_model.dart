class DailyDuelModel {
  final String id;
  final String duelDate;
  final int totalQuestions;
  final int timeLimitMinutes;
  final double registrationFee;
  final double prizePool;
  final String status;

  DailyDuelModel({
    required this.id,
    required this.duelDate,
    required this.totalQuestions,
    required this.timeLimitMinutes,
    required this.registrationFee,
    required this.prizePool,
    required this.status,
  });

  factory DailyDuelModel.fromJson(Map<String, dynamic> json) {
    return DailyDuelModel(
      id: json['id'],
      duelDate: json['duel_date'],
      totalQuestions: json['total_questions'] ?? 15,
      timeLimitMinutes: json['time_limit_minutes'] ?? 15,
      registrationFee: (json['registration_fee'] ?? 0).toDouble(),
      prizePool: (json['prize_pool'] ?? 0).toDouble(),
      status: json['status'] ?? 'upcoming',
    );
  }
}

class QuestionModel {
  final String id;
  final String questionTextEn;
  final String questionTextTe;
  final Map<String, String> optionsEn;
  final Map<String, String> optionsTe;
  final String correctAnswer;
  final int marks;
  final double negativeMarks;
  final int questionOrder;

  QuestionModel({
    required this.id,
    required this.questionTextEn,
    required this.questionTextTe,
    required this.optionsEn,
    required this.optionsTe,
    required this.correctAnswer,
    required this.marks,
    required this.negativeMarks,
    required this.questionOrder,
  });

  factory QuestionModel.fromJson(Map<String, dynamic> json, String language) {
    return QuestionModel(
      id: json['id'],
      questionTextEn: json['question_text_en'] ?? '',
      questionTextTe: json['question_text_te'] ?? '',
      optionsEn: {
        'A': json['option_a_en'] ?? '',
        'B': json['option_b_en'] ?? '',
        'C': json['option_c_en'] ?? '',
        'D': json['option_d_en'] ?? '',
      },
      optionsTe: {
        'A': json['option_a_te'] ?? '',
        'B': json['option_b_te'] ?? '',
        'C': json['option_c_te'] ?? '',
        'D': json['option_d_te'] ?? '',
      },
      correctAnswer: json['correct_answer'] ?? '',
      marks: json['marks'] ?? 1,
      negativeMarks: (json['negative_marks'] ?? 0.25).toDouble(),
      questionOrder: json['question_order'] ?? 0,
    );
  }

  String getQuestionText(String language) {
    return language == 'en' ? questionTextEn : questionTextTe;
  }

  Map<String, String> getOptions(String language) {
    return language == 'en' ? optionsEn : optionsTe;
  }
}

