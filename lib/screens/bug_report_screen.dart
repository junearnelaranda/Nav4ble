part of '../home.dart';

/// "Found a bug?" form. Sends to the admin Bug Reports page, separate from
/// accessibility reports about places.
class _BugReportScreen extends StatefulWidget {
  const _BugReportScreen();

  @override
  State<_BugReportScreen> createState() => _BugReportScreenState();
}

class _BugReportScreenState extends State<_BugReportScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _area = ReportsApi.bugAreas.first;
  Uint8List? _screenshot;
  bool _sending = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _show(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickScreenshot() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      if (bytes.lengthInBytes > ReportsApi.maxPhotoBytes) {
        _show('This screenshot is over 700 KiB. Choose a smaller one.');
        return;
      }
      setState(() => _screenshot = bytes);
    } catch (_) {
      if (mounted) _show('Could not open your photos.');
    }
  }

  Future<void> _send() async {
    if (_sending) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_titleController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      _show('Add a short title and describe what happened.');
      return;
    }
    setState(() => _sending = true);
    try {
      await ReportsApi.submitBug(
        area: _area,
        title: _titleController.text,
        description: _descriptionController.text,
        screenshot: _screenshot,
      );
      if (!mounted) return;
      _show('Thank you! Your bug report was sent to the NavAble team.');
      Navigator.of(context).pop();
    } on ReportsApiException catch (error) {
      if (mounted) _show(error.message);
    } catch (_) {
      if (mounted) {
        _show('Your bug report could not be sent. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report a Bug')),
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            NavAbleSpacing.md,
            NavAbleSpacing.xs,
            NavAbleSpacing.md,
            NavAbleSpacing.xxl,
          ),
          children: [
            Text(
              'Help us fix NavAble',
              style: TextStyle(
                color: context.navAblePrimaryText,
                fontSize: 24,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            Text(
              'Something crashed, didn\'t work, or showed the wrong thing? '
              'Tell us what happened and our team will look into it.',
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            _ReportFormCard(
              icon: Icons.category_outlined,
              title: 'Where did it happen?',
              child: SizedBox(
                height: NavAbleSize.control,
                child: DropdownButtonFormField<String>(
                  initialValue: _area,
                  isExpanded: true,
                  decoration: _reportFieldDecoration(
                    context,
                    hintText: 'Choose a part of the app',
                  ),
                  items: [
                    for (final area in ReportsApi.bugAreas)
                      DropdownMenuItem(value: area, child: Text(area)),
                  ],
                  onChanged: _sending
                      ? null
                      : (value) => setState(() => _area = value ?? _area),
                ),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.sm),
            _ReportFormCard(
              icon: Icons.title_rounded,
              title: 'Title',
              child: TextField(
                controller: _titleController,
                maxLength: 150,
                textCapitalization: TextCapitalization.sentences,
                decoration: _reportFieldDecoration(
                  context,
                  hintText: 'e.g. Map is blank after searching',
                ),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.sm),
            _ReportFormCard(
              icon: Icons.description_outlined,
              title: 'What happened?',
              child: TextField(
                controller: _descriptionController,
                minLines: 4,
                maxLines: 6,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: _reportFieldDecoration(
                  context,
                  hintText:
                      'What did you do, what did you expect, and what '
                      'happened instead?',
                ),
              ),
            ),
            const SizedBox(height: NavAbleSpacing.sm),
            _ReportFormCard(
              icon: Icons.screenshot_outlined,
              title: 'Screenshot (optional)',
              child: _screenshot == null
                  ? SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _sending ? null : _pickScreenshot,
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Add a screenshot'),
                      ),
                    )
                  : Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(
                            NavAbleRadius.small,
                          ),
                          child: Image.memory(
                            _screenshot!,
                            width: 72,
                            height: 72,
                            fit: BoxFit.cover,
                            semanticLabel: 'Attached screenshot',
                          ),
                        ),
                        const SizedBox(width: NavAbleSpacing.sm),
                        Expanded(
                          child: Text(
                            'Screenshot attached',
                            style: TextStyle(
                              color: context.navAblePrimaryText,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Remove screenshot',
                          onPressed: _sending
                              ? null
                              : () => setState(() => _screenshot = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: NavAbleSpacing.xs),
            Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 15,
                  color: context.navAbleSecondaryText,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Your phone model and system version are included to '
                    'help us reproduce the problem.',
                    style: TextStyle(
                      color: context.navAbleSecondaryText,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: NavAbleSpacing.lg),
            SizedBox(
              height: NavAbleSize.primaryButton,
              child: FilledButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded, size: 19),
                label: Text(_sending ? 'Sending…' : 'Send Bug Report'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
