import 'package:flutter/material.dart';

@immutable
class DrawnDaysTheme extends ThemeExtension<DrawnDaysTheme> {
  const DrawnDaysTheme({
    required this.page,
    required this.paper,
    required this.ink,
    required this.mutedInk,
    required this.grid,
    required this.texture,
    required this.shadow,
    required this.navigation,
    required this.selection,
    required this.isPaper,
  });

  final Color page;
  final Color paper;
  final Color ink;
  final Color mutedInk;
  final Color grid;
  final Color texture;
  final Color shadow;
  final Color navigation;
  final Color selection;
  final bool isPaper;

  @override
  DrawnDaysTheme copyWith({
    Color? page,
    Color? paper,
    Color? ink,
    Color? mutedInk,
    Color? grid,
    Color? texture,
    Color? shadow,
    Color? navigation,
    Color? selection,
    bool? isPaper,
  }) => DrawnDaysTheme(
    page: page ?? this.page,
    paper: paper ?? this.paper,
    ink: ink ?? this.ink,
    mutedInk: mutedInk ?? this.mutedInk,
    grid: grid ?? this.grid,
    texture: texture ?? this.texture,
    shadow: shadow ?? this.shadow,
    navigation: navigation ?? this.navigation,
    selection: selection ?? this.selection,
    isPaper: isPaper ?? this.isPaper,
  );

  @override
  DrawnDaysTheme lerp(covariant DrawnDaysTheme? other, double t) {
    if (other == null) return this;
    return DrawnDaysTheme(
      page: Color.lerp(page, other.page, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      mutedInk: Color.lerp(mutedInk, other.mutedInk, t)!,
      grid: Color.lerp(grid, other.grid, t)!,
      texture: Color.lerp(texture, other.texture, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      navigation: Color.lerp(navigation, other.navigation, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      isPaper: t < .5 ? isPaper : other.isPaper,
    );
  }
}

extension DrawnDaysThemeContext on BuildContext {
  DrawnDaysTheme get drawnTheme =>
      Theme.of(this).extension<DrawnDaysTheme>() ?? fallbackDrawnDaysTheme;
}

const fallbackDrawnDaysTheme = DrawnDaysTheme(
  page: Color(0xFFF7F3E8),
  paper: Color(0xFFFFFEF8),
  ink: Color(0xFF173F32),
  mutedInk: Color(0xFF53605A),
  grid: Color(0xFF708079),
  texture: Color(0x0C665433),
  shadow: Color(0x4453605A),
  navigation: Color(0xFFFFFEFA),
  selection: Color(0xFFF2D762),
  isPaper: true,
);
