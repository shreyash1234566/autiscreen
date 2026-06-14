import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'constants/app_colors.dart';
import 'constants/app_strings.dart';
import 'models/child.dart';
import 'models/session.dart';
import 'models/questionnaire.dart';
import 'screens/registration_screen.dart';
import 'screens/consent_screen.dart';
import 'screens/questionnaire_screen.dart';
import 'screens/task_a_screen.dart';
import 'screens/task_b_screen.dart';
import 'screens/task_c_screen.dart';
import 'screens/task_d_screen.dart';
import 'screens/session_complete_screen.dart';
import 'services/mediapipe_service.dart';
import 'services/tts_service.dart';
import 'services/api_service.dart';
import 'package:uuid/uuid.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force portrait for consistent camera framing
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const AutiScreenApp());
}

class AutiScreenApp extends StatelessWidget {
  const AutiScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AutiScreen',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        fontFamily: 'Roboto',
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      home: const SessionOrchestrator(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SessionOrchestrator — drives the full session flow:
// Registration → Consent → Questionnaire → Tasks A/B/C/D → Upload
// ─────────────────────────────────────────────────────────────────────────────
class SessionOrchestrator extends StatefulWidget {
  const SessionOrchestrator({super.key});

  @override
  State<SessionOrchestrator> createState() => _SessionOrchestratorState();
}

enum _SessionStep {
  registration, consent, questionnaire,
  taskA, taskB, taskC, taskD, complete
}

class _SessionOrchestratorState extends State<SessionOrchestrator> {
  _SessionStep _step = _SessionStep.registration;
  Child? _child;
  AppStrings _strings = englishStrings;

  // Collected data
  Map<String, dynamic>? _questionnaireResult;
  List<GazeDataPoint> _gazeTaskA = [];
  List<GazeDataPoint> _gazeTaskB = [];
  List<NameTrialResult> _nameTrials = [];
  List<GazeDataPoint> _gazeTaskC = [];
  List<BubbleTouchEvent> _bubbleEvents = [];

  final _mediaPipe = MediaPipeService();
  final _tts = TtsService();
  final _api = ApiService();

  @override
  void initState() {
    super.initState();
  }

  void _onRegistered(Child child) {
    setState(() {
      _child = child;
      _strings = child.language == 'hi' ? hindiStrings : englishStrings;
      _step = _SessionStep.consent;
    });
    _tts.init(child.language);
  }

  void _onConsentAccepted() => setState(() => _step = _SessionStep.questionnaire);

  void _onQuestionnaireComplete(Map<String, dynamic> result) {
    setState(() { _questionnaireResult = result; _step = _SessionStep.taskA; });
  }

  void _onTaskAComplete(List<GazeDataPoint> gaze) {
    setState(() { _gazeTaskA = gaze; _step = _SessionStep.taskB; });
  }

  void _onTaskBComplete(List<NameTrialResult> trials, List<GazeDataPoint> gaze) {
    setState(() { _nameTrials = trials; _gazeTaskB = gaze; _step = _SessionStep.taskC; });
  }

  void _onTaskCComplete(List<GazeDataPoint> gaze) {
    setState(() { _gazeTaskC = gaze; _step = _SessionStep.taskD; });
  }

  void _onTaskDComplete(List<BubbleTouchEvent> events) {
    setState(() { _bubbleEvents = events; _step = _SessionStep.complete; });
  }

  Future<void> _uploadSession() async {
    final session = SessionData(
      sessionId: const Uuid().v4(),
      childId: _child!.id,
      startedAt: DateTime.now(),
      videoPath: '', // video recorded natively and path passed separately
      gazeTaskA: _gazeTaskA,
      gazeTaskB: _gazeTaskB,
      nameTrials: _nameTrials,
      gazeTaskC: _gazeTaskC,
      bubbleEvents: _bubbleEvents,
      questionnaireScore: (_questionnaireResult?['total_score'] as int?) ?? 0,
      questionnaireType: (_questionnaireResult?['type'] as String?) ?? 'unknown',
      questionnaireAnswers: Map<String, int>.from(
          (_questionnaireResult?['answers'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), (v is bool) ? (v ? 1 : 0) : (v as int))) ?? {}),
    );

    // Register child server-side if not done
    await _api.registerChild(_child!.toJson());
    // Upload session (video path empty for now — extend as needed)
    await _api.uploadSession(session: session, videoPath: '');
  }

  @override
  Widget build(BuildContext context) {
    final child = _child;
    switch (_step) {
      case _SessionStep.registration:
        return RegistrationScreen(onRegistered: _onRegistered);
      case _SessionStep.consent:
        return ConsentScreen(strings: _strings, onAccepted: _onConsentAccepted);
      case _SessionStep.questionnaire:
        return QuestionnaireScreen(
          child: child!,
          strings: _strings,
          onComplete: _onQuestionnaireComplete,
        );
      case _SessionStep.taskA:
        return TaskAScreen(
          mediaPipeService: _mediaPipe,
          onComplete: _onTaskAComplete,
        );
      case _SessionStep.taskB:
        return TaskBScreen(
          childName: child!.name,
          languageCode: child.language,
          mediaPipeService: _mediaPipe,
          ttsService: _tts,
          onComplete: _onTaskBComplete,
        );
      case _SessionStep.taskC:
        return TaskCScreen(
          languageCode: child!.language,
          mediaPipeService: _mediaPipe,
          ttsService: _tts,
          onComplete: _onTaskCComplete,
        );
      case _SessionStep.taskD:
        return TaskDScreen(onComplete: _onTaskDComplete);
      case _SessionStep.complete:
        return SessionCompleteScreen(
          strings: _strings,
          uploadFuture: _uploadSession,
        );
    }
  }
}
