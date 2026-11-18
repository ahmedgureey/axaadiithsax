import 'package:flutter/material.dart';

/// Maps a category `iconKey` from the data layer to a Material icon.
IconData categoryIcon(String iconKey) => switch (iconKey) {
  'mosque' => Icons.mosque_outlined,
  'heart' => Icons.favorite_outline_rounded,
  'school' => Icons.school_outlined,
  'spark' => Icons.auto_awesome_outlined,
  'family' => Icons.family_restroom_rounded,
  _ => Icons.label_outline_rounded,
};
