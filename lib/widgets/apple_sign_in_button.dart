import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AppleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String text;

  const AppleSignInButton({
    Key? key,
    required this.onPressed,
    this.text = 'Sign in with Apple',
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SignInWithAppleButton(
      onPressed: onPressed,
      text: text,
      height: 50,
      borderRadius: BorderRadius.circular(8),
      style: SignInWithAppleButtonStyle.black,
    );
  }
}