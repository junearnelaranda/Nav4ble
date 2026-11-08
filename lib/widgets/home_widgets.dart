part of '../home.dart';

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.maxLines = 1,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLines;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: _fieldDecoration(hintText: hintText, icon: icon),
    );
  }
}

InputDecoration _fieldDecoration({
  required String hintText,
  required IconData icon,
}) {
  return InputDecoration(
    hintText: hintText,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: NavAblePalette.green.withValues(alpha: 0.06),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x40889AA6)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0x40889AA6)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: kNavAbleGreen, width: 1.5),
    ),
  );
}

class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: kNavAbleAccent,
      child: Icon(icon, color: kNavAbleGreen),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String detail;

  /// Optional button under the text (shown when both are set).
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          Icon(icon, color: kNavAbleGreen, size: 42),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: context.navAblePrimaryText,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.navAbleSecondaryText,
              fontSize: 13,
              height: 1.4,
              letterSpacing: 0,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.search_rounded),
              label: Text(actionLabel!, textAlign: TextAlign.center),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return NavAbleSurface(
      width: double.infinity,
      padding: const EdgeInsets.all(NavAbleSpacing.cardInset),
      borderRadius: NavAbleRadius.card,
      color: context.navAbleSurface,
      child: child,
    );
  }
}

/// The signed-in user's profile picture for the top bar, or their initials
/// on NavAble green when they haven't added a photo.
class _TopBarAvatar extends StatelessWidget {
  const _TopBarAvatar({required this.user});

  final NavAbleUser? user;

  String get _initials => initialsOf(user?.fullName ?? '');

  @override
  Widget build(BuildContext context) {
    final photo = user?.profileImageBytes;
    final initials = _initials;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: NavAblePalette.green, // ring, like the Profile page avatar
      ),
      child: CircleAvatar(
        radius: 15,
        backgroundColor: const Color(0xFFE8F3EC),
        foregroundImage: photo == null ? null : MemoryImage(photo),
        child: photo != null
            ? null
            : initials.isEmpty
            ? const Icon(
                Icons.person_rounded,
                size: 18,
                color: NavAblePalette.navy,
              )
            : Text(
                initials,
                style: const TextStyle(
                  color: NavAblePalette.navy,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

IconData _reportStatusIcon(ReportStatus status) => switch (status) {
  ReportStatus.pending => Icons.hourglass_top_rounded,
  ReportStatus.verified => Icons.verified_rounded,
  ReportStatus.resolved => Icons.task_alt_rounded,
  ReportStatus.rejected => Icons.cancel_outlined,
};
