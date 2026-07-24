import 'package:flutter/material.dart';

const Color _navAbleNavy = Color(0xFF001832);
const Color _navAbleGreen = Color(0xFF008A3D);
const Color _pageBackground = Color(0xFFF8FAFD);
const Color _mutedText = Color(0xFF4B525E);

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 22),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back),
                    color: _navAbleNavy,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const _ResetIcon(),
              const SizedBox(height: 20),
              const Text(
                'Forgot Password?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _navAbleNavy,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No worries! Enter the email address associated with your NavAble account and we will send a secure reset link.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _mutedText,
                  fontSize: 10,
                  height: 1.45,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE0E4EA)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _EmailResetField(),
                    const SizedBox(height: 12),
                    const _SecurityNotice(),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: FilledButton(
                        onPressed: () {},
                        style: FilledButton.styleFrom(
                          backgroundColor: _navAbleNavy,
                          foregroundColor: Colors.white,
                          elevation: 6,
                          shadowColor: Colors.black.withValues(alpha: 0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Send Reset Link',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            SizedBox(width: 10),
                            Icon(Icons.arrow_forward, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Still having trouble accessing your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF303846),
                  fontSize: 14,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 12),
              const _SupportAction(
                icon: Icons.support_agent,
                label: 'Contact Accessibility Support',
                color: _navAbleGreen,
              ),
              const SizedBox(height: 10),
              const _SupportAction(
                icon: Icons.help_outline,
                label: 'Visit Help Center',
                color: Color(0xFF596170),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFD5F9DD),
                  border: Border.all(color: const Color(0xFF8EE3A2)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: _navAbleGreen, size: 18),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'Need help resetting your password?\n',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF167A39),
                          ),
                          children: [
                            TextSpan(
                              text:
                                  'Contact our support team if you no longer have access to your registered email address.',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF167A39),
                              ),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.45,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResetIcon extends StatelessWidget {
  const _ResetIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        color: Color(0xFF85F29D),
        shape: BoxShape.circle,
      ),
      child: const Stack(
        alignment: Alignment.center,
        children: [
          Icon(Icons.lock_reset, color: _navAbleGreen, size: 31),
          Positioned(
            left: 15,
            top: 18,
            child: Icon(Icons.reply, color: _navAbleGreen, size: 13),
          ),
        ],
      ),
    );
  }
}

class _EmailResetField extends StatelessWidget {
  const _EmailResetField();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            color: Color(0xFF303846),
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 54,
          child: TextField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: Color(0xFF596170),
                size: 18,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 54,
              ),
              hintText: 'june@example.com',
              hintStyle: const TextStyle(
                color: Color(0xFFC5CAD2),
                fontSize: 15,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: const Color(0xFFF3F5F8),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 17,
              ),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF596170), width: 1),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _navAbleGreen, width: 1.4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.verified_user_outlined, color: _navAbleNavy, size: 16),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'We prioritize your data security and privacy.',
            style: TextStyle(
              color: _navAbleNavy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {},
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
