import 'package:flutter/material.dart';

import 'navable_design.dart';

enum LegalDoc { terms, privacy }

/// A tappable "Terms of Service" / "Privacy Policy" link inside a sentence.
InlineSpan legalLink(
  BuildContext context,
  String label,
  LegalDoc doc,
  TextStyle style,
) => WidgetSpan(
  alignment: PlaceholderAlignment.baseline,
  baseline: TextBaseline.alphabetic,
  child: Semantics(
    link: true,
    label: label,
    excludeSemantics: true,
    child: GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => LegalScreen.open(context, doc),
      child: Text(label, style: style),
    ),
  ),
);

/// Terms of Service and Privacy Policy, written for what NavAble actually
/// does. Opened from Welcome, Create account and Settings.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});

  final LegalDoc doc;

  static const updated = 'Last updated November 8, 2026';

  static void open(BuildContext context, LegalDoc doc) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (context) => LegalScreen(doc: doc)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sections = doc == LegalDoc.terms ? _terms : _privacy;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          doc == LegalDoc.terms ? 'Terms of Service' : 'Privacy Policy',
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              updated,
              style: TextStyle(
                color: context.navAbleSecondaryText,
                fontSize: 13,
              ),
            ),
            for (final (title, body) in sections) ...[
              const SizedBox(height: 20),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: TextStyle(
                    color: context.navAblePrimaryText,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: TextStyle(
                  color: context.navAblePrimaryText,
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (context) => LegalScreen(
                      doc: doc == LegalDoc.terms
                          ? LegalDoc.privacy
                          : LegalDoc.terms,
                    ),
                  ),
                ),
                child: Text(
                  doc == LegalDoc.terms
                      ? 'Read the Privacy Policy'
                      : 'Read the Terms of Service',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _terms = [
  (
    'Using NavAble',
    'NavAble helps people in Cebu find accessible places and routes. '
        'Accessibility information comes from the community, NavAble admins, '
        'Google Maps and OpenStreetMap. Places and routes can change, so check '
        'conditions on site before relying on them. NavAble is not '
        'responsible for injury, delay or loss from using a place or route '
        'shown in the app.',
  ),
  (
    'Your contributions',
    'Share only accurate information and photos you took yourself. Avoid '
        "photographing people's faces, plate numbers or other personal "
        'details. Admins review every report and photo and may edit, reject '
        'or remove it. By submitting, you let NavAble show approved '
        'information and photos to other users.',
  ),
  (
    'Points, levels and rewards',
    'Points and levels are for fun. They have no money value and cannot be '
        'sold, traded or exchanged. Admins award points for approved '
        'contributions and may remove points given for inaccurate, copied or '
        "spam contributions. Rewards aren't available yet; if they launch, "
        'their rules will be announced in the app.',
  ),
  (
    'Your account',
    'Keep your password private. Accounts that post harmful, false or '
        'abusive content may be suspended.',
  ),
  (
    'Changes',
    'These terms may be updated. The date at the top shows the latest '
        'version.',
  ),
];

const _privacy = [
  (
    'What NavAble collects',
    'Your name, email address and password (handled by Supabase '
        'Authentication; NavAble never sees your password); your profile '
        'photo, if you add one; the reports, photos, pinned locations and AI '
        'scan results you submit; bug reports you send, including basic device '
        'information; and the points you earn.',
  ),
  (
    "What other users can see",
    'Your full name, profile photo, level and points appear on the Top '
        'Contributors leaderboard. Places and photos that admins approve are '
        'shown to everyone. Your email address, reports in review and bug '
        'reports are visible only to you and NavAble admins.',
  ),
  (
    'Your location',
    'With your permission, your location is used on your phone to show the '
        'map, find nearby places and plan routes. It is sent to the place '
        'search and routing services below as the search or route starting '
        'point, and is stored by NavAble only when you pin a location in a '
        'report.',
  ),
  (
    'On your phone only',
    'Saved places, your theme and text size choices, and which level-up '
        'celebrations you have seen are stored only on your device.',
  ),
  (
    'Services NavAble uses',
    'Supabase stores accounts, reports and photos. Google Maps Platform '
        'powers Explore search, and Directions opens Google Maps. OpenStreetMap '
        'services provide the map, place search and routes. Photo scanning '
        'runs on your phone when possible; otherwise the photo is sent to '
        'Roboflow for analysis.',
  ),
  (
    'Your choices',
    'You can edit your name and photo, or remove your photo, in your '
        'profile. To ask for a copy, correction or deletion of your data, '
        'including your reports, send a request through Report a bug in the '
        'Reports tab.',
  ),
  (
    'Data Privacy Act',
    'NavAble handles personal information in line with the Data Privacy Act '
        'of 2012 (Republic Act No. 10173).',
  ),
];
