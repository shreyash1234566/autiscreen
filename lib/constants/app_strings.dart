class AppStrings {
  final String childName;
  final String childAgeMonths;
  final String gender;
  final String male;
  final String female;
  final String other;
  final String next;
  final String uploadingData;
  final String sessionComplete;
  final String thankYou;
  final String doctorWillReview;
  final String appName;
  final String tagline;

  AppStrings({
    required this.childName,
    required this.childAgeMonths,
    required this.gender,
    required this.male,
    required this.female,
    required this.other,
    required this.next,
    required this.uploadingData,
    required this.sessionComplete,
    required this.thankYou,
    required this.doctorWillReview,
    required this.appName,
    required this.tagline,
  });
}

final englishStrings = AppStrings(
  childName: "Child's Name",
  childAgeMonths: "Age (Months)",
  gender: "Gender",
  male: "Male",
  female: "Female",
  other: "Other",
  next: "Next",
  uploadingData: "Uploading data...",
  sessionComplete: "Session Complete",
  thankYou: "Thank you for participating!",
  doctorWillReview: "A doctor will review the results shortly.",
  appName: "Autism Screening",
  tagline: "Early detection, better future",
);

final hindiStrings = AppStrings(
  childName: "बच्चे का नाम",
  childAgeMonths: "आयु (महीने)",
  gender: "लिंग",
  male: "पुरुष",
  female: "महिला",
  other: "अन्य",
  next: "अगला",
  uploadingData: "डेटा अपलोड हो रहा है...",
  sessionComplete: "सत्र पूरा हुआ",
  thankYou: "भाग लेने के लिए धन्यवाद!",
  doctorWillReview: "डॉक्टर जल्द ही परिणामों की समीक्षा करेंगे।",
  appName: "ऑटिज्म स्क्रीनिंग",
  tagline: "जल्द पहचान, बेहतर भविष्य",
);
