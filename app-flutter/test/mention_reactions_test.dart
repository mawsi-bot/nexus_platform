import 'package:flutter_test/flutter_test.dart';
import 'package:nexus/presentation/widgets/mention.dart';
import 'package:nexus/presentation/widgets/reactions.dart';
import 'package:nexus/presentation/widgets/stickers.dart';

void main() {
  group('mentions', () {
    test('detects the word being typed', () {
      expect(activeMention('hi @an', 6)?.query, 'an');
      expect(activeMention('hi @an', 6)?.start, 3);
      expect(activeMention('email a@b.com', 13), isNull);
      expect(activeMention('@ann hi', 7), isNull);
      expect(activeMention('plain', 5), isNull);
    });

    test('suggests unique prefixes and applies the pick', () {
      final names = ['Ann Lee', 'anna', 'Bo', 'Ann Lee'];
      expect(suggestMentions('an', names), ['Ann', 'anna']);
      expect(suggestMentions('', const ['Ann', 'Bo'], limit: 1), ['Ann']);
      expect(suggestMentions('zz', names), isEmpty);

      final match = activeMention('hey @an', 7)!;
      expect(applyMention('hey @an', match, 'Ann'), 'hey @Ann ');
      expect(applyMention('hey @an there', match, 'Ann'), 'hey @Ann there');
    });

    test('extracts handles from a body', () {
      expect(mentionedHandles('cc @Ann @bo_2 @Ann'), ['Ann', 'bo_2']);
      expect(mentionedHandles('nothing'), isEmpty);
    });
  });

  group('reactions', () {
    test('vocabulary and labels', () {
      expect(kReactionOrder, ['love', 'hug', 'strong']);
      expect(reactionEmoji('hug'), '🤗');
      expect(reactionEmoji('unknown'), '❤️');
      expect(reactionLabel('strong'), 'Strong');
      expect(reactionLabel(''), 'Like');
    });

    test('total sums every count', () {
      expect(reactionTotal({'love': 3, 'hug': 2}), 5);
      expect(reactionTotal(const {}), 0);
    });
  });

  group('stickers', () {
    test('packs are non-empty and glyphs unique within a pack', () {
      expect(kStickerPacks.length, 3);
      for (final pack in kStickerPacks) {
        expect(pack.glyphs, isNotEmpty);
        expect(pack.glyphs.toSet().length, pack.glyphs.length);
        expect(pack.glyphs.length, 12);
      }
    });
  });
}
