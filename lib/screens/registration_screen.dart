import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';
import '../models/child.dart';

class RegistrationScreen extends StatefulWidget {
  final void Function(Child child) onRegistered;
  const RegistrationScreen({super.key, required this.onRegistered});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  ChildGender _gender = ChildGender.male;
  String _language = 'en';
  AppStrings _strings = englishStrings;

  @override
  void dispose() { _nameCtrl.dispose(); _ageCtrl.dispose(); super.dispose(); }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final child = Child(
      id: const Uuid().v4(),
      name: _nameCtrl.text.trim(),
      ageMonths: int.parse(_ageCtrl.text.trim()),
      gender: _gender,
      language: _language,
      createdAt: DateTime.now(),
    );
    widget.onRegistered(child);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SizedBox(height: 20),
            Center(child: Column(children: [
              const Icon(Icons.child_care, size: 60, color: AppColors.primary),
              const SizedBox(height: 8),
              Text(_strings.appName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              Text(_strings.tagline,
                  style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
            ])),
            const SizedBox(height: 36),
            // Language toggle — first thing shown so UI language adapts
            Row(children: [
              Text('Language / भाषा',
                  style: const TextStyle(fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
              const Spacer(),
              ToggleButtons(
                isSelected: [_language == 'en', _language == 'hi'],
                onPressed: (i) => setState(() {
                  _language = i == 0 ? 'en' : 'hi';
                  _strings = i == 0 ? englishStrings : hindiStrings;
                }),
                borderRadius: BorderRadius.circular(8),
                selectedColor: Colors.white,
                fillColor: AppColors.primary,
                children: const [
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('EN')),
                  Padding(padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text('हि')),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            TextFormField(
              controller: _nameCtrl,
              decoration: InputDecoration(
                labelText: _strings.childName,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ageCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _strings.childAgeMonths,
                hintText: 'e.g. 24',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final n = int.tryParse(v);
                if (n == null || n < 16 || n > 120) {
                  return 'Enter age 16-120 months (1.5-10 years)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Text(_strings.gender,
                style: const TextStyle(fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 8),
            Row(children: ChildGender.values.map((g) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => setState(() => _gender = g),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _gender == g ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _gender == g ? AppColors.primary : AppColors.divider,
                          width: 2),
                    ),
                    child: Text(
                      g == ChildGender.male ? _strings.male
                          : g == ChildGender.female ? _strings.female
                          : _strings.other,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _gender == g ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            )).toList()),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(_strings.next,
                    style: const TextStyle(fontSize: 18, color: Colors.white,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      )),
    );
  }
}
