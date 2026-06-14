import 'package:flutter/material.dart';

enum CharacterState { idle, talking, happy }

class AnimatedCharacter extends StatelessWidget {
  final CharacterState state;
  final double size;

  const AnimatedCharacter({super.key, required this.state, required this.size});

  @override
  Widget build(BuildContext context) {
    IconData icon;
    Color color;

    switch (state) {
      case CharacterState.idle:
        icon = Icons.face;
        color = Colors.grey;
        break;
      case CharacterState.talking:
        icon = Icons.record_voice_over;
        color = Colors.blue;
        break;
      case CharacterState.happy:
        icon = Icons.sentiment_very_satisfied;
        color = Colors.green;
        break;
    }

    return Icon(icon, size: size, color: color);
  }
}
