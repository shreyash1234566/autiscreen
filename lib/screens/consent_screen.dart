import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_strings.dart';

class ConsentScreen extends StatefulWidget {
  final AppStrings strings;
  final VoidCallback onAccepted;

  const ConsentScreen({
    super.key,
    required this.strings,
    required this.onAccepted,
  });

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _agreed = false;

  bool get _isHi => widget.strings.appName == 'ऑटिज्म स्क्रीनिंग';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.shield_outlined,
                        color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      _isHi ? 'सहमति फ़ॉर्म' : 'Consent Form',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Scrollable consent body
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _isHi ? _consentHi : _consentEn,
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.7,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: Checkbox(
                      value: _agreed,
                      activeColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _agreed = !_agreed),
                      child: Text(
                        _isHi
                            ? 'मैं सहमत हूँ कि मेरे बच्चे का डेटा अनुसंधान के लिए उपयोग किया जा सकता है।'
                            : 'I agree that my child\'s data may be used for research purposes.',
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Accept button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _agreed ? widget.onAccepted : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        _agreed ? AppColors.primary : AppColors.divider,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _isHi ? 'स्वीकार करें और जारी रखें' : 'Accept & Continue',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _consentEn = '''
PURPOSE OF THIS STUDY
This app collects behavioural data from your child — including eye movements, head orientation, name-response and touch interactions — to support early screening for Autism Spectrum Disorder (ASD).

DATA COLLECTED
• Video of the child's face (processed locally; not stored as video)
• Gaze and head-pose data from camera frames
• Touch events during the bubble task
• Responses to questionnaire items

HOW DATA IS USED
Anonymised data is encrypted and securely uploaded to Jomga Health servers. It will be reviewed by a qualified clinician and may be used for research to improve autism detection algorithms.

PRIVACY
• Your child's name and personal details will not be publicly disclosed.
• Data is stored under a randomly generated ID, not your child's real name.
• You may request deletion of your child's data at any time.

VOLUNTARY PARTICIPATION
Participation is entirely voluntary. You may stop at any time without any consequence.

CONTACT
For questions about this study, please contact: research@jomgahealth.com''';

const _consentHi = '''
इस अध्ययन का उद्देश्य
यह ऐप आपके बच्चे से व्यावहारिक डेटा एकत्र करती है — जिसमें आँख की गतिविधियाँ, सिर की दिशा, नाम-प्रतिक्रिया और स्पर्श इंटरैक्शन शामिल हैं — ऑटिज्म स्पेक्ट्रम विकार (ASD) की प्रारंभिक जाँच में सहायता के लिए।

एकत्रित डेटा
• बच्चे के चेहरे का वीडियो (स्थानीय रूप से प्रसंस्कृत; वीडियो के रूप में संग्रहीत नहीं)
• कैमरा फ्रेम से टकटकी और सिर की स्थिति डेटा
• बबल कार्य के दौरान स्पर्श घटनाएँ
• प्रश्नावली में दिए गए उत्तर

डेटा का उपयोग कैसे किया जाता है
अज्ञात डेटा एन्क्रिप्ट किया जाता है और Jomga Health सर्वर पर सुरक्षित रूप से अपलोड किया जाता है। इसकी समीक्षा एक योग्य चिकित्सक द्वारा की जाएगी।

गोपनीयता
• आपके बच्चे का नाम और व्यक्तिगत विवरण सार्वजनिक नहीं किया जाएगा।
• डेटा एक यादृच्छिक ID के तहत संग्रहीत होता है।

स्वैच्छिक भागीदारी
भागीदारी पूरी तरह स्वैच्छिक है। आप किसी भी समय रुक सकते हैं।

संपर्क
अध्ययन के बारे में प्रश्नों के लिए: research@jomgahealth.com''';
