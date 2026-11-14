import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models.dart';
import '../controllers/nexus_controller.dart';
import '../media/media_providers.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/states.dart';
import '../widgets/stickers.dart';

class ChatScreen extends ConsumerWidget {
  const ChatScreen({super.key});

  Future<void> _attach(BuildContext context, WidgetRef ref) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: context.nx.surface,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.photo_outlined, color: sheet.nx.accentBrand),
              title: const Text('Photo'),
              subtitle: const Text('Sent as a compressed WebP'),
              onTap: () => Navigator.pop(sheet, 'photo'),
            ),
            ListTile(
              leading: Icon(
                Icons.emoji_emotions_outlined,
                color: sheet.nx.accentBrand,
              ),
              title: const Text('Sticker'),
              subtitle: const Text('Bundled packs — works offline'),
              onTap: () => Navigator.pop(sheet, 'sticker'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final c = ref.read(nexusProvider.notifier);
    if (choice == 'sticker') {
      final glyph = await showStickerPicker(context);
      if (glyph != null) await c.sendSticker(glyph);
      return;
    }
    final path = await ref.read(mediaSourceProvider).pickOneImage();
    if (path == null) return;
    final compressed = await ref.read(imageCompressorProvider).compress(path);
    await c.sendImage(compressed);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(nexusProvider), c = ref.read(nexusProvider.notifier);
    void notice(String message) => ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 8, 8),
          decoration: BoxDecoration(
            color: context.nx.surface,
            border: Border(bottom: BorderSide(color: context.nx.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => c.go('feed'),
                icon: Icon(
                  Icons.arrow_back_ios_new,
                  size: 18,
                  color: context.nx.textPrimary,
                ),
              ),
              const Avatar(size: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.threadName.isEmpty ? 'Conversation' : s.threadName,
                      style: DesignTokens.itemTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF22C55E),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Active now',
                          style: DesignTokens.meta.copyWith(
                            color: context.nx.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Voice call',
                onPressed: () => notice('Voice calling is not available yet'),
                icon: Icon(
                  Icons.call,
                  size: 20,
                  color: context.nx.textPrimary,
                ),
              ),
              IconButton(
                tooltip: 'Video call',
                onPressed: () => notice('Video calling is not available yet'),
                icon: Icon(
                  Icons.videocam,
                  size: 21,
                  color: context.nx.textPrimary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: s.messages.isEmpty
              ? const EmptyState(
                  icon: Icons.chat_bubble_outline,
                  title: 'Say hello',
                  message: 'This conversation has no messages yet.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                  children: [
                    Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: context.nx.surfaceTint,
                          borderRadius: BorderRadius.circular(
                            DesignTokens.radiusPill,
                          ),
                        ),
                        child: Text(
                          'Today',
                          style: DesignTokens.meta.copyWith(
                            color: context.nx.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    for (final m in s.messages) _Bubble(message: m),
                    Align(
                      alignment: Alignment.centerRight,
                      child: const Padding(
                        padding: EdgeInsets.only(top: 2, right: 4),
                        child: Text('Seen', style: TextStyle(fontSize: 10.5)),
                      ),
                    ),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
          decoration: BoxDecoration(
            color: context.nx.surface,
            border: Border(top: BorderSide(color: context.nx.border)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Attach',
                onPressed: () => _attach(context, ref),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: context.nx.textSecondary,
                ),
              ),
              Expanded(
                child: NativeInput(
                  value: s.messageDraft,
                  onChanged: c.messageDraft,
                  hint: 'Message…',
                  onSubmitted: c.sendMessage,
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 44,
                height: 44,
                child: Material(
                  color: context.nx.textPrimary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: c.sendMessage,
                    child: const Icon(
                      Icons.send,
                      size: 19,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final Entry message;
  @override
  Widget build(BuildContext context) {
    final out = message.outgoing;
    if (message.subtype == 'sticker') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Align(
          alignment: out ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(message.body, style: const TextStyle(fontSize: 46)),
        ),
      );
    }
    if (message.subtype == 'image') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Align(
          alignment: out ? Alignment.centerRight : Alignment.centerLeft,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.network(
              message.body,
              width: 210,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                width: 210,
                height: 150,
                color: context.nx.surfaceTint,
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  color: context.nx.textSecondary,
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: out ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 13),
          decoration: BoxDecoration(
            color: out ? context.nx.textPrimary : context.nx.surfaceTint,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(out ? 16 : 5),
              bottomRight: Radius.circular(out ? 5 : 16),
            ),
          ),
          child: Text(
            message.body,
            style: DesignTokens.body.copyWith(
              color: out ? Colors.white : context.nx.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
