import 'package:flutter/widgets.dart';

/// المسافة اللي الهيكل زوّدها على `padding.bottom` لكل تبويب عشان آخر صف يطلع
/// فوق «ضيف» (مركزه على حافة الدوك). شاشة عندها مسافتها الأكبر أصلاً («يومك»:
/// مسافة «القريب مني») بتطرحها — فشكلها وأماكن حاجاتها زي ما كانت بالبكسل.
/// برّه الهيكل = صفر.
class ShellBottomExtra extends InheritedWidget {
  const ShellBottomExtra({required this.extra, required super.child, super.key});

  final double extra;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellBottomExtra>()?.extra ?? 0;

  @override
  bool updateShouldNotify(ShellBottomExtra old) => old.extra != extra;
}
