// lib/chat/widgets/message_row_wrapper.dart

import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_reactions/flutter_chat_reactions.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../../core/config/Enums.dart';
import '../../../../../../core/theme/lightTheme.dart';
import '../../../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../../../auth/presentation/bloc/auth_state.dart';
import '../../../bloc/chat_cubit.dart';
import '../../../../../admin/presentation/bloc/report_cubit.dart';

import '../MessageWidget.dart';
import '../Details/User_details.dart';
import '../../../../data/models/chat_member_model.dart';


class MessageRowWrapper extends StatelessWidget {

  final types.Message message;
  final int index;
  final bool isSentByMe;
  final String? fileId;
  final ReactionsController reactionsController;
  final Function(types.Message) onReply;
  final Function(types.Message) onDelete;
  final Function(String) onMessageVisible;
  final types.InMemoryChatController chatController;
  final bool isPreviousMessageFromSameUser;
  final Map<String, types.User> userCache;
  final Map<String, ImageProvider<Object>> avatarImageProviderByUserId;
  final ValueListenable<int> avatarVersionListenable;
  final Future<void> Function(String) resolveUser; // Function to fetch user
  final List<types.Message> localMessages;
  final bool showDateHeaders;
  final String currentUserId;
  final double? uploadProgress;
  final List<ChatMember> chatMembers;
  final Roles? userRole;

  /// Prefix for keys that must be unique across multiple GeneralChat instances
  /// coexisting in an IndexedStack (e.g. `'COMPOUND_GENERAL'` vs `'BUILDING_CHAT'`).
  final String channelName;

  /// Appwrite / SQLite `channel_id` for persisting `metadata` updates (reactions).
  final String channelId;

  // NEW: notify parent about visibility for sticky header computation
  final void Function(String messageId, int index, double visibleFraction, DateTime? createdAt) onVisibilityForHeader;
  final bool isUserScrolling;

  const MessageRowWrapper({
    super.key,
    required this.message,
    required this.index,
    required this.isSentByMe,
    this.fileId,
    required this.reactionsController,
    required this.onReply,
    required this.onDelete,
    required this.onMessageVisible,
    required this.chatController,
    required this.isPreviousMessageFromSameUser,
    required this.userCache,
    required this.avatarImageProviderByUserId,
    required this.avatarVersionListenable,
    required this.resolveUser,
    required this.onVisibilityForHeader,
    required this.localMessages,
    required this.showDateHeaders,
    required this.currentUserId,
    required this.isUserScrolling,
    required this.chatMembers,
    required this.userRole,
    required this.channelName,
    required this.channelId,
    this.uploadProgress,
  });

  @override
  Widget build(BuildContext context) {
    final user = userCache[message.authorId];
    // 👇 THIS IS THE CORRECTED LINE
    final userNameString = user?.name ?? '...';

    final messagesList = List<types.Message>.from(chatController.messages);
    final controllerIndex = messagesList.indexWhere((m) => m.id == message.id);

    final DateTime? createdAt = message.createdAt?.toLocal();
    final DateTime? prevCreatedAt = controllerIndex > 0
        ? messagesList[controllerIndex - 1].createdAt?.toLocal()
        : null;

    bool _isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;


    final bool baseHeaderCond = createdAt != null &&
        (controllerIndex <= 0 ||
            prevCreatedAt == null ||
            !_isSameDay(prevCreatedAt, createdAt));

    final bool showHeader = showDateHeaders && baseHeaderCond;

    Future<void> _showUserPopup(BuildContext context, String userId) async {
      final member = chatMembers.where((chatMember) => chatMember.id.trim() == userId).firstOrNull;
      if (member == null) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black26,
        builder: (ctx) {
          return SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(ctx).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 12,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: () {
                      final rawAvatar = member.avatarUrl?.trim();
                      final hasValidAvatar = rawAvatar != null &&
                          rawAvatar.isNotEmpty &&
                          rawAvatar.toLowerCase() != 'null';
                      if (!hasValidAvatar) {
                        return CircleAvatar(
                          child: Text(member.displayName[0]),
                        );
                      }
                      if (kIsWeb) {
                        return CircleAvatar(
                          child: ClipOval(
                            child: CachedNetworkImage(
                              imageUrl: rawAvatar,
                              fit: BoxFit.cover,
                              width: 40,
                              height: 40,
                              errorWidget: (_, __, ___) =>
                                  Text(member.displayName[0]),
                            ),
                          ),
                        );
                      }
                      return CircleAvatar(
                        backgroundImage: CachedNetworkImageProvider(rawAvatar),
                      );
                    }(),
                    title: Text(member.displayName,
                        style: Theme.of(ctx).textTheme.titleMedium),
                    subtitle: Text(
                      'Building ${member.building} · Apt ${member.apartment}',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                  const Divider(height: 0),
                  ListTile(
                    leading: const Icon(Icons.chat_outlined),
                    title: Text(context.loc.messageAction),
                    onTap: () {
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(SnackBar(
                          behavior: SnackBarBehavior.floating,
                          content: Text(context.loc.directMessagingUnavailable),
                        ));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.info_outline),
                    title: Text(context.loc.viewProfileAction),
                    onTap: () {
                      Navigator.pop(ctx);
                      showModalBottomSheet<void>(
                        context: context,
                        showDragHandle: true,
                        builder: (_) => SafeArea(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: UserDetails(userID: member.id),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      );
    }

    Future<void> _updateMessageReactions({
      required String emoji,
      required bool isAdding,
      String? replaceEmoji ,
      required String currentUserId,
    }) async {
      // 1. Get existing message from controller (or fallback)
      final existing = chatController.messages.firstWhere(
            (m) => m.id == message.id,
        orElse: () => message,
      );

      // 2. Clone and normalize metadata
      final meta =
      Map<String, dynamic>.from(existing.metadata ?? <String, dynamic>{});
      final reactionsRaw = meta['reactions'];

      // Normalize to Map<String, Map<String,bool>>
      final Map<String, Map<String, bool>> reactions = {};
      if (reactionsRaw is Map) {
        reactionsRaw.forEach((k, v) {
          final key = k.toString();
          final Map<String, bool> inner = {};
          if (v is Map) {
            v.forEach((uid, val) {
              if (uid == null) return;
              inner[uid.toString()] =
                  val == true || val == 1 || val == 'true';
            });
          }
          reactions[key] = inner;
        });
      }

      reactions.putIfAbsent(emoji, () => <String, bool>{});
      final usersForEmoji = reactions[emoji]!;

      if (isAdding) {
        usersForEmoji[currentUserId] = true;
        if (replaceEmoji != null) {
          final existingReactionUsers = reactions[replaceEmoji];
          existingReactionUsers?.remove(currentUserId);
          if (existingReactionUsers != null && existingReactionUsers.isEmpty) {
            reactions.remove(replaceEmoji);
          }
        }
      } else {
        usersForEmoji.remove(currentUserId);
        if (usersForEmoji.isEmpty) {
          reactions.remove(emoji);
        }
      }

      // 3. Write back to metadata
      meta['reactions'] = reactions.map(
            (k, v) => MapEntry(k, v.map((uid, val) => MapEntry(uid, val))),
      );

      // 4. Build a new message instance with updated metadata
      types.Message updated;
      if (existing is types.TextMessage) {
        updated = types.TextMessage(
          id: existing.id,
          authorId: existing.authorId,
          text: existing.text,
          createdAt: existing.createdAt,
          metadata: meta,
          replyToMessageId: existing.replyToMessageId,
          deliveredAt: existing.deliveredAt,
          sentAt: existing.sentAt,
          seenAt: existing.seenAt,
        );
      } else if (existing is types.ImageMessage) {
        updated = types.ImageMessage(
          id: existing.id,
          authorId: existing.authorId,
          createdAt: existing.createdAt,
          height: existing.height,
          width: existing.width,
          size: existing.size,
          source: existing.source,
          metadata: meta,
          replyToMessageId: existing.replyToMessageId,
          deliveredAt: existing.deliveredAt,
          sentAt: existing.sentAt,
          seenAt: existing.seenAt,
        );
      } else if (existing is types.AudioMessage) {
        updated = types.AudioMessage(
          id: existing.id,
          authorId: existing.authorId,
          createdAt: existing.createdAt,
          size: existing.size,
          source: existing.source,
          duration: existing.duration,
          metadata: meta,
          replyToMessageId: existing.replyToMessageId,
          deliveredAt: existing.deliveredAt,
          sentAt: existing.sentAt,
          seenAt: existing.seenAt,
        );
      } else if (existing is types.FileMessage) {
        updated = types.FileMessage(
          id: existing.id,
          authorId: existing.authorId,
          createdAt: existing.createdAt,
          name: existing.name,
          size: existing.size,
          mimeType: existing.mimeType,
          source: existing.source,
          metadata: meta,
          replyToMessageId: existing.replyToMessageId,
          deliveredAt: existing.deliveredAt,
          sentAt: existing.sentAt,
          seenAt: existing.seenAt,
        );
      } else {
        updated = types.CustomMessage(
          id: existing.id,
          authorId: existing.authorId,
          createdAt: existing.createdAt,
          metadata: meta,
        );
      }

      // 5. Update in\-memory controller
      try {
        chatController.updateMessage(existing, updated);
      } catch (_) {}

      // 6. Update local messages list used for cache
      final idx = localMessages.indexWhere((m) => m.id == message.id);
      if (idx != -1) {
        localMessages[idx] = updated;
      }

      // 7. Persist metadata (reactions) to Appwrite + local SQLite
      if (channelId.isNotEmpty) {
        try {
          await context.read<ChatCubit>().updateMessageMetadata(
                channelId: channelId,
                message: updated,
              );
        } catch (_) {
          // UI already updated; remote sync can retry on next full fetch
        }
      }
    }

    Widget contentWidget;
    if (message is types.CustomMessage &&
        message.metadata?['type'] == 'image' &&
        message.metadata?['filePath'] != null) {

      final String path = message.metadata!['filePath'];
      final double progress = uploadProgress ?? 0.0;

      contentWidget = Container(
        constraints: const BoxConstraints(
          maxWidth: 250, // Limit width of image bubble
          maxHeight: 300,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.grey[200],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            // Local preview: web cannot render `Image.file`.
            kIsWeb
                ? Image.network(
                    path,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Colors.black12,
                      child: Center(
                        child: Icon(Icons.image_not_supported_outlined),
                      ),
                    ),
                  )
                : Image.file(
                    File(path),
                    fit: BoxFit.cover,
                  ),
            // Dark Overlay
            Container(color: Colors.black38),
            // Progress Indicator
            Center(
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 4,
                color: Colors.white,
                backgroundColor: Colors.white24,
              ),
            ),
          ],
        ),
      );
    } else {
      // Standard message rendering
      contentWidget = MessageWidget(
        message: message,
        controller: reactionsController,
        messageIndex: index,
        chatController: chatController,
        userName: userNameString,
        userCache: userCache,
        isPreviousMessageFromSameUser: isPreviousMessageFromSameUser,
        isSentByMe: isSentByMe,
        fileId: fileId,
        localMessages: localMessages,
        isUserScroll: isUserScrolling,
        chatMembers: chatMembers,
        userRole: userRole,
      );
    }
     final messageContent = ChatMessageWrapper(
      messageId: message.id,
      controller: reactionsController,
      config:  ChatReactionsConfig(
        dialogPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        menuItems: [
          MenuItem(label: 'Reply', icon: Icons.reply),
          MenuItem(label: 'Copy', icon: Icons.copy),
          (isSentByMe || userRole == Roles.admin)
              ? MenuItem(label: 'Delete', icon: Icons.delete_forever, isDestructive: true)
              : MenuItem(label: 'Report', icon: Icons.report_outlined, isDestructive: true),



        ]
      ),
      onMenuItemTapped: (item) {
        if (item.label == "Reply") {
          onReply(message);
          return;
        }

        if (item.isDestructive) {
          if (item.label == "Delete") {
            onDelete(message);
            return;
          }

          if (item.label == "Report") {
            final reportCubit = ReportCubit.get(context);
            final authState = context.read<AuthCubit>().state;
            reportCubit.reportAuthorId = currentUserId;
            reportCubit.reportedUserId = message.authorId;
            reportCubit.messageId = message.id;
            reportCubit.reportCompoundId =
                authState is Authenticated ? authState.selectedCompoundId : null;
            if (reportCubit.issueType.text.trim().isEmpty) {
              reportCubit.issueType.text = 'other';
            }
            return;
          }
        }
      },
       onReactionAdded: (String emoji) async {
         // At the point this callback fires, `message.metadata` still holds the
         // state BEFORE the new reaction — making it the reliable place to check
         // whether the current user already had a different emoji on this message.
         String? reactionToReplace;
         final existingReactions = message.metadata?['reactions'];
         if (existingReactions is Map) {
           for (final entry in existingReactions.entries) {
             final existingEmoji = entry.key?.toString();
             final usersRaw = entry.value;
             // Skip the emoji the user just picked (same-emoji = toggle-off,
             // which the package handles by calling onReactionRemoved instead).
             if (existingEmoji == null || existingEmoji == emoji) continue;
             if (usersRaw is Map && usersRaw.containsKey(currentUserId)) {
               reactionToReplace = existingEmoji;
               break;
             }
           }
         }
         await _updateMessageReactions(
           emoji: emoji,
           isAdding: true,
           replaceEmoji: reactionToReplace,
           currentUserId: currentUserId,
         );
       },
       onReactionRemoved: (String emoji) async{
         await _updateMessageReactions(
           emoji: emoji,
           isAdding: false,
           currentUserId: currentUserId,
         );
       },
      child: contentWidget,
    );

    final messageAuthorId = message.authorId.trim();
    String? normalizeAvatarUrl(String? raw) {
      if (raw == null) return null;
      final trimmed = raw.trim();
      if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return null;
      return trimmed;
    }

    final List<Widget> messageBody = [
      messageContent,
      ValueListenableBuilder<int>(
        valueListenable: avatarVersionListenable,
        builder: (context, _, __) {
          final authState = context.read<AuthCubit>().state;
          final member = authState is Authenticated
              ? authState.chatMembers
                  .where((chatMember) => chatMember.id.trim() == messageAuthorId)
                  .firstOrNull
              : null;
          final resolvedUserAvatarUrl = normalizeAvatarUrl(
            userCache[messageAuthorId]?.imageSource,
          );
          final memberAvatarUrl = normalizeAvatarUrl(member?.avatarUrl);
          final avatarUrl = resolvedUserAvatarUrl ?? memberAvatarUrl;
          final cachedAvatarImageProvider =
              avatarImageProviderByUserId[messageAuthorId];
          final shouldShowAvatarForRow = !isPreviousMessageFromSameUser;
          final hasAvatar =
              cachedAvatarImageProvider != null || avatarUrl != null;

          return InkResponse(
            onTapDown: (_) {
              debugPrint(userRole.toString());
              _showUserPopup(context, message.authorId);
            },
            child: !shouldShowAvatarForRow
                ? const SizedBox(width: 32, height: 32)
                : (hasAvatar
                    ? CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.transparent,
                        child: ClipOval(
                          child: SizedBox(
                            width: 32,
                            height: 32,
                            child: cachedAvatarImageProvider != null
                                ? Image(
                                    image: cachedAvatarImageProvider,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Avatar(userId: message.authorId),
                                  )
                                : CachedNetworkImage(
                                    imageUrl: avatarUrl!,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        Avatar(userId: message.authorId),
                                  ),
                          ),
                        ),
                      )
                    : Avatar(userId: message.authorId)),
          );
        },
      ),

    ];

    return VisibilityDetector(
      key: Key('${channelName}_${message.id}'),
      onVisibilityChanged: (VisibilityInfo info) {
        // Inform parent about visibility for sticky header
        onVisibilityForHeader(message.id, index, info.visibleFraction, createdAt);

        // Mark as seen when sufficiently visible
        if (info.visibleFraction >= 0.8 && !isSentByMe) {
          onMessageVisible(message.id);
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader) ...[
            DateHeader(date: createdAt),
            const SizedBox(height: 11),
          ],

          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
            isSentByMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            spacing: 8,
            children: isSentByMe ? messageBody : messageBody.reversed.toList(),
          ),
        ],
      ),
    );
  }
}

class DateHeader extends StatelessWidget {
  final DateTime date;
  const DateHeader({super.key, required this.date});

  String _label(DateTime d) {
    final today = DateTime.now();
    final a = DateTime(today.year, today.month, today.day);
    final b = DateTime(d.year, d.month, d.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return 'Today';
    if (diff == -1) return 'Yesterday';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(80),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _label(date.toLocal()),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}