import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../locations_api.dart';

/// Lets a mouse or trackpad drag the photos too, so they swipe on a PC.
class _AnyPointerDrag extends MaterialScrollBehavior {
  const _AnyPointerDrag();

  @override
  Set<PointerDeviceKind> get dragDevices => PointerDeviceKind.values.toSet();
}

/// A place's photos, swiped one at a time. With more than one photo it shows
/// arrow buttons (for anyone who can't swipe), a "2 / 5" counter and dots.
/// Users' photos carry a "Photo by June A." label.
class PlacePhotoCarousel extends StatefulWidget {
  const PlacePhotoCarousel({
    super.key,
    required this.photos,
    required this.placeName,
    required this.placeholder,
    this.onOpen,
  });

  final List<PlacePhoto> photos;
  final String placeName;

  /// Shown while a photo loads, if it fails, or when there are no photos.
  final Widget placeholder;

  /// Tapping a photo; null lets the tap reach the parent (a card, say).
  final ValueChanged<int>? onOpen;

  @override
  State<PlacePhotoCarousel> createState() => _PlacePhotoCarouselState();
}

class _PlacePhotoCarouselState extends State<PlacePhotoCarousel> {
  final _controller = PageController();
  int _index = 0;

  @override
  void didUpdateWidget(covariant PlacePhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_index >= widget.photos.length && widget.photos.isNotEmpty) {
      _index = widget.photos.length - 1;
      _controller.jumpToPage(_index);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) => _controller.animateToPage(
    index,
    duration: const Duration(milliseconds: 280),
    curve: Curves.easeOutCubic,
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    if (photos.isEmpty) return widget.placeholder;
    final many = photos.length > 1;
    final credit = photos[_index].contributor;
    final onOpen = widget.onOpen;

    return Stack(
      fit: StackFit.expand,
      children: [
        ScrollConfiguration(
          behavior: const _AnyPointerDrag(),
          child: PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _index = index),
            itemBuilder: (context, index) {
              final photo = photos[index];
              final image = Image.network(
                photo.url,
                fit: BoxFit.cover,
                semanticLabel: [
                  'Photo${many ? ' ${index + 1} of ${photos.length}' : ''} '
                      'of ${widget.placeName}',
                  if (photo.contributor case final name?) 'by $name',
                ].join(', '),
                errorBuilder: (_, _, _) => widget.placeholder,
                loadingBuilder: (context, child, progress) =>
                    progress == null ? child : widget.placeholder,
              );
              if (onOpen == null) return image;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onOpen(index),
                child: MouseRegion(
                  cursor: SystemMouseCursors.zoomIn,
                  child: image,
                ),
              );
            },
          ),
        ),
        if (credit != null)
          Positioned(
            left: 10,
            bottom: many ? 28 : 10,
            child: _Chip(text: 'Photo by $credit'),
          ),
        if (many) ...[
          Positioned(
            top: 10,
            right: 10,
            child: ExcludeSemantics(
              child: _Chip(text: '${_index + 1} / ${photos.length}'),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 10,
            child: ExcludeSemantics(
              child: _Dots(count: photos.length, index: _index),
            ),
          ),
          if (_index > 0)
            Align(
              alignment: Alignment.centerLeft,
              child: _ArrowButton(
                icon: Icons.chevron_left_rounded,
                tooltip: 'Previous photo',
                onPressed: () => _go(_index - 1),
              ),
            ),
          if (_index < photos.length - 1)
            Align(
              alignment: Alignment.centerRight,
              child: _ArrowButton(
                icon: Icons.chevron_right_rounded,
                tooltip: 'Next photo',
                onPressed: () => _go(_index + 1),
              ),
            ),
        ],
      ],
    );
  }
}

/// Opens [photos] full screen at [initialIndex], with zoom.
Future<void> showPlacePhotoViewer(
  BuildContext context, {
  required List<PlacePhoto> photos,
  required int initialIndex,
  required String placeName,
}) {
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      barrierDismissible: true,
      barrierLabel: 'Close photos',
      pageBuilder: (context, _, _) => _PhotoViewer(
        photos: photos,
        initialIndex: initialIndex,
        placeName: placeName,
      ),
      transitionsBuilder: (context, animation, _, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({
    required this.photos,
    required this.initialIndex,
    required this.placeName,
  });

  final List<PlacePhoto> photos;
  final int initialIndex;
  final String placeName;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final _controller = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _go(int index) {
    if (index < 0 || index >= widget.photos.length) return;
    _controller.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.photos;
    final many = photos.length > 1;
    final credit = photos[_index].contributor;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _go(_index - 1),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _go(_index + 1),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
      },
      child: Focus(
        autofocus: true,
        child: Material(
          color: Colors.black,
          child: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                ScrollConfiguration(
                  behavior: const _AnyPointerDrag(),
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: photos.length,
                    onPageChanged: (index) => setState(() => _index = index),
                    itemBuilder: (context, index) => InteractiveViewer(
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          photos[index].url,
                          fit: BoxFit.contain,
                          semanticLabel:
                              'Photo ${index + 1} of ${photos.length} '
                              'of ${widget.placeName}',
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    tooltip: 'Close photos',
                    onPressed: () => Navigator.of(context).pop(),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 12,
                  child: Row(
                    children: [
                      if (credit != null)
                        Flexible(child: _Chip(text: 'Photo by $credit')),
                      const Spacer(),
                      if (many)
                        ExcludeSemantics(
                          child: _Chip(
                            text: '${_index + 1} / ${photos.length}',
                          ),
                        ),
                    ],
                  ),
                ),
                if (many && _index > 0)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _ArrowButton(
                      icon: Icons.chevron_left_rounded,
                      tooltip: 'Previous photo',
                      onPressed: () => _go(_index - 1),
                      large: true,
                    ),
                  ),
                if (many && _index < photos.length - 1)
                  Align(
                    alignment: Alignment.centerRight,
                    child: _ArrowButton(
                      icon: Icons.chevron_right_rounded,
                      tooltip: 'Next photo',
                      onPressed: () => _go(_index + 1),
                      large: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.large = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        iconSize: large ? 32 : 24,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.88),
          foregroundColor: const Color(0xFF0F2B4D),
          minimumSize: Size.square(large ? 52 : 40),
          shadowColor: Colors.black26,
          elevation: 2,
        ),
        icon: Icon(icon),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    // Many photos: keep the dots short and let the counter say the rest.
    final shown = count.clamp(0, 7);
    final active = count <= 7 ? index : (index * 6 / (count - 1)).round();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var dot = 0; dot < shown; dot++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: dot == active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: dot == active
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(99),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 3),
              ],
            ),
          ),
      ],
    );
  }
}
