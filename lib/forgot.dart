import 'package:flutter/material.dart';

import 'navable_design.dart';

import 'auth_service.dart';

const Color _navAbleNavy = NavAblePalette.navy;
const Color _navAbleGreen = NavAblePalette.green;
const Color _navAbleAccent = NavAblePalette.accent;
const Color _navAbleText = NavAblePalette.text;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _emailController = TextEditingController();
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.035),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _sendResetLink() {
    final message = AuthService.resetPassword(_emailController.text);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showSupportMessage(String destination) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$destination is ready to connect to your site.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _PremiumBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: _BackButton(
                                onPressed: () =>
                                    Navigator.of(context).maybePop(),
                              ),
                            ),
                            const SizedBox(height: 30),
                            const _ResetIcon(),
                            const SizedBox(height: 24),
                            const Text(
                              'Forgot Password?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _navAbleNavy,
                                fontSize: 25,
                                height: 1.18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 322),
                              child: Text(
                                'No worries! Enter the email address associated with your NavAble account and we will send a secure reset link.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: _navAbleText,
                                  fontSize: 14,
                                  height: 1.6,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                            _PremiumCard(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _EmailResetField(
                                    controller: _emailController,
                                  ),
                                  const SizedBox(height: 14),
                                  const _SecurityNotice(),
                                  const SizedBox(height: 28),
                                  _PrimaryButton(
                                    label: 'Send Reset Link',
                                    onPressed: _sendResetLink,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 28),
                            const Text(
                              'Still having trouble accessing your account?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF344054),
                                fontSize: 14,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _SupportAction(
                              icon: Icons.support_agent_rounded,
                              label: 'Contact Accessibility Support',
                              color: _navAbleGreen,
                              onPressed: () =>
                                  _showSupportMessage('Accessibility support'),
                            ),
                            const SizedBox(height: 10),
                            _SupportAction(
                              icon: Icons.help_outline_rounded,
                              label: 'Visit Help Center',
                              color: _navAbleNavy,
                              onPressed: () =>
                                  _showSupportMessage('Help Center'),
                            ),
                            const SizedBox(height: 26),
                            const _HelpNotice(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PremiumBackground extends StatelessWidget {
  const _PremiumBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FFF8), Colors.white, Color(0xFFECFFF0)],
          stops: [0, 0.52, 1],
        ),
      ),
      child: Stack(
        children: [
          const _SoftGlow(alignment: Alignment.topRight),
          const _SoftGlow(alignment: Alignment.bottomLeft),
          child,
        ],
      ),
    );
  }
}

class _SoftGlow extends StatelessWidget {
  const _SoftGlow({required this.alignment});

  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Transform.translate(
        offset: alignment == Alignment.topRight
            ? const Offset(72, -64)
            : const Offset(-88, 92),
        child: Container(
          width: 190,
          height: 190,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _navAbleGreen.withValues(alpha: 0.08),
                _navAbleGreen.withValues(alpha: 0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onPressed,
      icon: const Icon(Icons.arrow_back_rounded),
      color: _navAbleNavy,
      style: IconButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.8),
        fixedSize: const Size.square(NavAbleSize.compactControl),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 24),
      color: NavAblePalette.surface,
      child: child,
    );
  }
}

class _ResetIcon extends StatelessWidget {
  const _ResetIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: _navAbleAccent,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDDE5DF)),
        boxShadow: [
          BoxShadow(
            color: _navAbleNavy.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const Icon(
        Icons.lock_reset_rounded,
        color: _navAbleGreen,
        size: 36,
      ),
    );
  }
}

class _EmailResetField extends StatelessWidget {
  const _EmailResetField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Email Address',
          style: TextStyle(
            color: Color(0xFF344054),
            fontSize: 13,
            fontWeight: FontWeight.w800,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 9),
        SizedBox(
          height: NavAbleSize.field,
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.email_outlined,
                color: _navAbleGreen,
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 48,
                minHeight: 56,
              ),
              hintText: 'june@example.com',
              hintStyle: const TextStyle(
                color: Color(0xFF98A2B3),
                fontSize: 15,
                letterSpacing: 0,
              ),
              filled: true,
              fillColor: const Color(0xFFF7FAF8),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFDDE5DF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: _navAbleGreen, width: 1.5),
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
        Icon(Icons.verified_user_outlined, color: _navAbleGreen, size: 18),
        SizedBox(width: 9),
        Expanded(
          child: Text(
            'We prioritize your data security and privacy.',
            style: TextStyle(
              color: _navAbleNavy,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapCancel: () => setState(() => _isPressed = false),
      onTapUp: (_) => setState(() => _isPressed = false),
      child: AnimatedScale(
        scale: _isPressed ? 0.975 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: NavAbleSize.primaryButton,
          child: FilledButton(
            onPressed: widget.onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: _navAbleNavy,
              foregroundColor: Colors.white,
              elevation: 8,
              shadowColor: _navAbleNavy.withValues(alpha: 0.22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(NavAbleRadius.button),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward_rounded, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SupportAction extends StatelessWidget {
  const _SupportAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 20),
      label: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _HelpNotice extends StatelessWidget {
  const _HelpNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _navAbleAccent.withValues(alpha: 0.92),
        border: Border.all(color: const Color(0xFFDDE5DF)),
        borderRadius: BorderRadius.circular(NavAbleRadius.card),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: _navAbleGreen, size: 20),
          SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: 'Need help resetting your password?\n',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: _navAbleNavy,
                ),
                children: [
                  TextSpan(
                    text:
                        'Contact our support team if you no longer have access to your registered email address.',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _navAbleText,
                    ),
                  ),
                ],
              ),
              style: TextStyle(fontSize: 12, height: 1.5, letterSpacing: 0),
            ),
          ),
        ],
      ),
    );
  }
}
