import 'package:flutter/material.dart';

/// Maps a category `iconKey` from the data layer to a Material icon.
IconData categoryIcon(String iconKey) => switch (iconKey) {
  'mosque' => Icons.mosque_outlined,
  'heart' => Icons.favorite_outline_rounded,
  'school' => Icons.school_outlined,
  'spark' => Icons.auto_awesome_outlined,
  'family' => Icons.family_restroom_rounded,
  'hourglass' => Icons.hourglass_bottom_rounded,
  'giving' => Icons.volunteer_activism_outlined,
  'night' => Icons.nights_stay_outlined,
  'crescent' => Icons.brightness_3_outlined,
  'return' => Icons.undo_rounded,
  _ => Icons.label_outline_rounded,
};
