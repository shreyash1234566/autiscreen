// questionnaire.dart — M-CHAT-R (16-30 months) and INDT-ASD (>30 months) items
// M-CHAT-R © Robins, Fein & Barton 2009 — used under public-domain research terms

class QuestionnaireItem {
  final String id;
  final String questionEn;
  final String questionHi;
  /// true  → answering YES is the at-risk response
  /// false → answering NO  is the at-risk response
  final bool riskIfYes;

  const QuestionnaireItem({
    required this.id,
    required this.questionEn,
    required this.questionHi,
    required this.riskIfYes,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// M-CHAT-R — 20 items, for children 16–30 months
// Source: Robins et al. (2014), J Autism Dev Disord, 44(2):587–597
// ─────────────────────────────────────────────────────────────────────────────
const List<QuestionnaireItem> mchatRItems = [
  QuestionnaireItem(
    id: 'q1',
    questionEn: 'If you point at something across the room, does your child look at it?',
    questionHi: 'यदि आप कमरे में किसी चीज़ की ओर इशारा करते हैं, तो क्या आपका बच्चा उसे देखता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q2',
    questionEn: 'Have you ever wondered if your child might be deaf?',
    questionHi: 'क्या आपने कभी सोचा है कि आपका बच्चा बहरा हो सकता है?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'q3',
    questionEn: 'Does your child play pretend or make-believe (e.g. pretend to drink from an empty cup)?',
    questionHi: 'क्या आपका बच्चा नाटकीय खेल खेलता है (जैसे खाली कप से पीने का नाटक करना)?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q4',
    questionEn: 'Does your child like climbing on things (e.g. furniture, playground equipment)?',
    questionHi: 'क्या आपका बच्चा चीज़ों पर चढ़ना पसंद करता है (जैसे फर्नीचर, झूला)?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q5',
    questionEn: 'Does your child make unusual finger movements near his/her eyes?',
    questionHi: 'क्या आपका बच्चा अपनी आँखों के पास असामान्य उँगली हिलाने की हरकत करता है?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'q6',
    questionEn: 'Does your child point with one finger to ask for something or to get help?',
    questionHi: 'क्या आपका बच्चा किसी चीज़ को पाने के लिए एक उँगली से इशारा करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q7',
    questionEn: 'Does your child point with one finger to show you something interesting?',
    questionHi: 'क्या आपका बच्चा किसी रोचक चीज़ को दिखाने के लिए एक उँगली से इशारा करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q8',
    questionEn: 'Is your child interested in other children (e.g. watches, smiles at or goes to them)?',
    questionHi: 'क्या आपका बच्चा दूसरे बच्चों में रुचि रखता है (देखता है, मुस्कुराता है)?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q9',
    questionEn: 'Does your child show you things by bringing them to you just to share — not to get help?',
    questionHi: 'क्या आपका बच्चा आपको चीज़ें सिर्फ दिखाने के लिए लाता है — मदद के लिए नहीं?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q10',
    questionEn: 'Does your child respond when you call his/her name?',
    questionHi: 'जब आप अपने बच्चे का नाम पुकारते हैं, तो क्या वह प्रतिक्रिया करता/करती है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q11',
    questionEn: 'When you smile at your child, does he/she smile back at you?',
    questionHi: 'जब आप अपने बच्चे पर मुस्कुराते हैं, तो क्या वह वापस मुस्कुराता/मुस्कुराती है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q12',
    questionEn: 'Does your child get upset by everyday noises (e.g. vacuum cleaner, loud music)?',
    questionHi: 'क्या आपका बच्चा रोज़मर्रा की आवाज़ों से परेशान हो जाता है (जैसे वैक्यूम, तेज़ संगीत)?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'q13',
    questionEn: 'Does your child walk?',
    questionHi: 'क्या आपका बच्चा चलता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q14',
    questionEn: 'Does your child look you in the eye when you are talking, playing, or dressing him/her?',
    questionHi: 'क्या आपका बच्चा बात करते, खेलते या कपड़े पहनाते समय आपकी आँखों में देखता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q15',
    questionEn: 'Does your child try to copy what you do (e.g. wave bye-bye, clap, make a noise)?',
    questionHi: 'क्या आपका बच्चा आपकी नकल करने की कोशिश करता है (जैसे बाय-बाय, तालियाँ)?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q16',
    questionEn: 'If you turn your head to look at something, does your child look around to see what you are looking at?',
    questionHi: 'यदि आप किसी चीज़ को देखने के लिए सिर घुमाते हैं, तो क्या आपका बच्चा भी देखने की कोशिश करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q17',
    questionEn: 'Does your child try to get you to watch him/her (e.g. says "look" or looks at you for praise)?',
    questionHi: 'क्या आपका बच्चा आपको अपनी ओर देखने के लिए प्रेरित करता है (जैसे "देखो" कहना)?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q18',
    questionEn: 'Does your child understand when you tell him/her to do something (without pointing)?',
    questionHi: 'क्या आपका बच्चा बिना इशारे के आपकी बात समझता है (जैसे "किताब रखो")?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q19',
    questionEn: 'If something new happens, does your child look at your face to see how you feel?',
    questionHi: 'यदि कुछ नया होता है, तो क्या आपका बच्चा आपके चेहरे की ओर देखता है कि आप कैसा महसूस कर रहे हैं?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'q20',
    questionEn: 'Does your child like movement activities (e.g. being swung or bounced on your knee)?',
    questionHi: 'क्या आपका बच्चा हलचल वाले खेल पसंद करता है (जैसे झुलाना या घुटनों पर उछालना)?',
    riskIfYes: false,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// INDT-ASD — 15 items, for children > 30 months
// Simplified from the Indian Scale for Assessment of Autism (ISAA) DSM-5 criteria
// ─────────────────────────────────────────────────────────────────────────────
const List<QuestionnaireItem> indtAsdItems = [
  QuestionnaireItem(
    id: 'i1',
    questionEn: 'Does the child make eye contact during play or conversation?',
    questionHi: 'क्या बच्चा खेलते या बात करते समय आँख से संपर्क करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i2',
    questionEn: 'Does the child respond when called by name?',
    questionHi: 'क्या बच्चा नाम पुकारने पर प्रतिक्रिया करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i3',
    questionEn: 'Does the child use words or short phrases to communicate needs?',
    questionHi: 'क्या बच्चा अपनी ज़रूरतें बताने के लिए शब्दों या वाक्यांशों का उपयोग करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i4',
    questionEn: 'Does the child point to things they want?',
    questionHi: 'क्या बच्चा जो चाहता है उस चीज़ की ओर इशारा करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i5',
    questionEn: 'Does the child show interest in playing with other children?',
    questionHi: 'क्या बच्चा दूसरे बच्चों के साथ खेलने में रुचि दिखाता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i6',
    questionEn: 'Does the child engage in pretend or imaginative play?',
    questionHi: 'क्या बच्चा नाटकीय या कल्पनाशील खेल खेलता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i7',
    questionEn: 'Does the child share objects or point to share experiences with others?',
    questionHi: 'क्या बच्चा दूसरों के साथ अनुभव साझा करने के लिए चीज़ें दिखाता या इशारा करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i8',
    questionEn: 'Does the child repeat words or phrases out of context (echolalia)?',
    questionHi: 'क्या बच्चा बिना संदर्भ के शब्द या वाक्यांश दोहराता है (इकोलालिया)?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'i9',
    questionEn: 'Does the child show repetitive body movements (hand flapping, rocking, spinning)?',
    questionHi: 'क्या बच्चा दोहराव वाली शारीरिक हरकतें करता है (हाथ हिलाना, झूलना, घूमना)?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'i10',
    questionEn: 'Does the child get very upset when routines or arrangements are changed?',
    questionHi: 'क्या बच्चा दिनचर्या या व्यवस्था बदलने पर बहुत परेशान हो जाता है?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'i11',
    questionEn: 'Does the child have unusual reactions to sounds, textures, lights, or smells?',
    questionHi: 'क्या बच्चे की आवाज़, बनावट, रोशनी या गंध के प्रति असामान्य प्रतिक्रिया है?',
    riskIfYes: true,
  ),
  QuestionnaireItem(
    id: 'i12',
    questionEn: 'Does the child understand and follow simple two-step instructions?',
    questionHi: 'क्या बच्चा दो-चरण के सरल निर्देशों को समझता और पालन करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i13',
    questionEn: 'Does the child smile in response to someone smiling at them?',
    questionHi: 'क्या बच्चा किसी के मुस्कुराने पर वापस मुस्कुराता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i14',
    questionEn: 'Does the child imitate actions shown by an adult?',
    questionHi: 'क्या बच्चा किसी बड़े की हरकतों की नकल करता है?',
    riskIfYes: false,
  ),
  QuestionnaireItem(
    id: 'i15',
    questionEn: 'Does the child strongly prefer playing alone over with others?',
    questionHi: 'क्या बच्चा दूसरों के साथ खेलने की बजाय अकेले खेलना बहुत अधिक पसंद करता है?',
    riskIfYes: true,
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

int computeScore(List<QuestionnaireItem> items, Map<String, bool> answers) {
  int score = 0;
  for (final item in items) {
    final answer = answers[item.id] ?? false;
    if (item.riskIfYes && answer == true) score++;
    if (!item.riskIfYes && answer == false) score++;
  }
  return score;
}

/// Returns 'low', 'medium', or 'high'.
String getRiskLevel(int score, {required bool isMchatR}) {
  if (isMchatR) {
    // M-CHAT-R cut-points: Robins et al. 2014
    if (score <= 2) return 'low';
    if (score <= 7) return 'medium';
    return 'high';
  } else {
    // INDT-ASD simplified cut-points
    if (score <= 3) return 'low';
    if (score <= 8) return 'medium';
    return 'high';
  }
}
