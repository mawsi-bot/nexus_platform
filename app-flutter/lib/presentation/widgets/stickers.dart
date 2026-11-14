import 'package:flutter/material.dart';

import '../theme.dart';

class StickerPack {
  const StickerPack(this.name, this.glyphs);
  final String name;
  final List<String> glyphs;
}

/// Bundled packs so stickers work offline and add no download weight.
const List<StickerPack> kStickerPacks = [
  StickerPack('Nexus', ['❤️', '🤗', '💪', '✨', '🎉', '🙌', '🔥', '💯', '👏', '🥳', '😍', '😂']),
  StickerPack('Mood', ['🥹', '😴', '😤', '🤔', '🫶', '😭', '😎', '🤯', '🫠', '🥶', '😇', '🫡']),
  StickerPack('Daily', ['☕', '🌙', '🌧️', '🌞', '🍜', '🎧', '🚀', '📚', '🏸', '🛺', '🌺', '🐈']),
];

Future<String?> showStickerPicker(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.nx.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheet) => DefaultTabController(
        length: kStickerPacks.length,
        child: SafeArea(
          child: SizedBox(
            height: 330,
            child: Column(
              children: [
                TabBar(
                  labelColor: sheet.nx.accentBrand,
                  unselectedLabelColor: sheet.nx.textSecondary,
                  indicatorColor: sheet.nx.accentBrand,
                  tabs: [
                    for (final pack in kStickerPacks) Tab(text: pack.name),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      for (final pack in kStickerPacks)
                        GridView.count(
                          crossAxisCount: 4,
                          padding: const EdgeInsets.all(12),
                          children: [
                            for (final glyph in pack.glyphs)
                              InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => Navigator.pop(sheet, glyph),
                                child: Center(
                                  child: Text(
                                    glyph,
                                    style: const TextStyle(fontSize: 34),
                                  ),
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
