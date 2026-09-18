import 'package:flutter/material.dart';
import 'package:mybike_showroom/core/theme/app_palette.dart';

/// Soft elevation tokens.
///
/// The brand direction is "border + soft shadow" rather than heavy Material
/// elevation, so these shadows stay low-opacity with a wide blur.
abstract final class AppShadows {
  static const List<BoxShadow> none = <BoxShadow>[];

  /// Hairline card shadow (light theme default).
  static const List<BoxShadow> card = <BoxShadow>[
    BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 2)),
  ];

  /// Raised surface (popovers, selected cards).
  static const List<BoxShadow> raised = <BoxShadow>[
    BoxShadow(color: Color(0x14000000), blurRadius: 20, offset: Offset(0, 6)),
  ];

  /// Overlays: dialogs, bottom sheets, menus.
  static const List<BoxShadow> overlay = <BoxShadow>[
    BoxShadow(color: Color(0x1F000000), blurRadius: 32, offset: Offset(0, 12)),
  ];

  /// Dark-theme variants (shadows are stronger on a black background).
  static const List<BoxShadow> cardDark = <BoxShadow>[
    BoxShadow(color: Color(0x40000000), blurRadius: 16, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> raisedDark = <BoxShadow>[
    BoxShadow(color: Color(0x59000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  /// Palette-aware shadow for cards.
  static List<BoxShadow> cardOf(AppPalette palette) =>
      palette.isDark ? cardDark : card;

  /// Palette-aware shadow for raised surfaces.
  static List<BoxShadow> raisedOf(AppPalette palette) =>
      palette.isDark ? raisedDark : raised;

  /// Convenience box decoration for a bordered, softly shadowed card.
  static BoxDecoration cardDecoration(AppPalette palette) {
    return BoxDecoration(
      color: palette.card,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: palette.border),
      boxShadow: cardOf(palette),
    );
  }
}
