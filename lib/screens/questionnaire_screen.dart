import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/child.dart';
import '../models/questionnaire.dart';

class QuestionnaireScreen extends StatefulWidget {
  final Child child;
  final AppStrings strings;
  final void Function(Map<String, dynamic> result) onComplete;

  const QuestionnaireScreen({
    super.key,
    required this.child,
    required this.strings,
    required this.onComplete,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen>
    with SingleTickerProviderStateMixin {
  late final List<QuestionnaireItem> _items;
  late final String _type;
  final Map<String, bool> _answers = {};
  int _currentIndex = 0;
  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  bool get _isHi => widget.child.language == 'hi';

  @override
  void initState() {
    super.initState();
    if (widget.child.useMchatR) {
      _items = mchatRItems;
      _type = 'mchat_r';
    } else if (widget.child.useIndtAsd) {
      _items = indtAsdItems;
      _type = 'indt_asd';
    } else {
      // Default for children outside normal ranges
      _items = mchatRItems;
      _type = 'mchat_r';
    }

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  void _answer(bool value) {
    final item = _items[_currentIndex];
    _answers[item.id] = value;

    if (_currentIndex < _items.length - 1) {
      _slideCtrl.reset();
      setState(() => _currentIndex++);
      _slideCtrl.forward();
    } else {
      _finish();
    }
  }

  void _finish() {
    final score = computeScore(_items, _answers);
    final risk = getRiskLevel(score, isMchatR: _type == 'mchat_r');
    widget.onComplete({
      'type': _type,
      'total_score': score,
      'risk_level': risk,
      'answers': _answers,
    });
  }

  @override
  Widget build(BuildContext context) {
    final item = _items[_currentIndex];
    final progress = (_currentIndex + 1) / _items.length;
    final question = _isHi ? item.questionHi : item.questionEn;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  const Icon(Icons.quiz_outlined,
                      color: AppColors.primary, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    _isHi ? 'प्रश्नावली' : 'Questionnaire',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  Text(
                    '${_currentIndex + 1} / ${_items.length}',
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: AppColors.divider,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.primary),
                ),
              ),

              const SizedBox(height: 32),

              // Question card — slides in from right
              Expanded(
                child: SlideTransition(
                  position: _slideAnim,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _type == 'mchat_r' ? 'M-CHAT-R' : 'INDT-ASD',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          question,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 18,
                            height: 1.6,
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // YES / NO buttons
              Row(
                children: [
                  Expanded(
                    child: _AnswerButton(
                      label: _isHi ? 'नहीं' : 'No',
                      icon: Icons.close_rounded,
                      color: AppColors.riskHigh,
                      onTap: () => _answer(false),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _AnswerButton(
                      label: _isHi ? 'हाँ' : 'Yes',
                      icon: Icons.check_rounded,
                      color: AppColors.riskLow,
                      onTap: () => _answer(true),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnswerButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AnswerButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(color: color.withOpacity(0.4), width: 1.5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
