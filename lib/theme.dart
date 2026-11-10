import 'dart:ui';
import 'package:flutter/material.dart';

const kBg = Color(0xFF070B1A);
const kViolet = Color(0xFF7C5CFF);
const kAccent = Color(0xFF2D9CFF); // أزرق كهربائي (اللون المميز)
const kGold = Color(0xFFFFC857); // للنجوم والتقييم فقط

const kBgGradient = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
    colors: [Color(0xFF1B1450), Color(0xFF070B1A)],
  ),
);

class GlassBox extends StatelessWidget {
  final Widget child;
  final double radius;
  final EdgeInsets? padding;
  const GlassBox({super.key, required this.child, this.radius = 20, this.padding});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.15)),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// عنصر قابل للتنقل بالريموت: يكبر ويظهر له إطار ذهبي عند التركيز
class TvFocus extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double radius;
  final bool autofocus;
  const TvFocus({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.radius = 16,
    this.autofocus = false,
  });

  @override
  State<TvFocus> createState() => _TvFocusState();
}

class _TvFocusState extends State<TvFocus> {
  bool _f = false;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(widget.radius);
    return Focus(
      onFocusChange: (v) => setState(() => _f = v),
      child: AnimatedScale(
        scale: _f ? 1.06 : 1,
        duration: const Duration(milliseconds: 150),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            borderRadius: r,
            border: Border.all(color: _f ? kAccent : Colors.transparent, width: 2.5),
            boxShadow: _f
                ? [BoxShadow(color: kAccent.withOpacity(0.45), blurRadius: 18)]
                : null,
          ),
          child: ClipRRect(
            borderRadius: r,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                autofocus: widget.autofocus,
                onTap: widget.onTap,
                onLongPress: widget.onLongPress,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
