import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:WhatsUnity/core/constants/Constants.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import 'package:WhatsUnity/features/social/domain/entities/post.dart';
import 'package:WhatsUnity/features/social/presentation/bloc/social_cubit.dart';

import 'social_member_utils.dart';

class CommentPopupDialog extends StatefulWidget {
  final Post post;
  final ChatMember postUser;
  final List<ChatMember> members;
  final ChatMember? currentMember;
  final String selectedCompoundId;

  const CommentPopupDialog({
    super.key,
    required this.post,
    required this.postUser,
    required this.members,
    this.currentMember,
    required this.selectedCompoundId,
  });

  @override
  State<CommentPopupDialog> createState() => _CommentPopupDialogState();
}

class _CommentPopupDialogState extends State<CommentPopupDialog>
    with WidgetsBindingObserver {
  late TextEditingController newComment;
  final ValueNotifier<bool> isSending = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    newComment = TextEditingController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    newComment.dispose();
    isSending.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.fromLTRB(24, 24, 24, 3),
      contentPadding: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      backgroundColor: Colors.white,
      content: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _PostPreviewHeader(post: widget.post, postUser: widget.postUser),
              const SizedBox(height: 10),
              _CommentsSection(
                post: widget.post,
                newComment: newComment,
                isSending: isSending,
                members: widget.members,
                currentMember: widget.currentMember,
                selectedCompoundId: widget.selectedCompoundId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostPreviewHeader extends StatelessWidget {
  final Post post;
  final ChatMember postUser;

  const _PostPreviewHeader({required this.post, required this.postUser});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: MediaQuery.sizeOf(context).width,
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              topRight: Radius.circular(8),
            ),
            color: context.txt.socialBackgroundColor,
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 10, top: 10, bottom: 5),
            child: Column(
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: socialAvatarProvider(postUser.avatarUrl),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(postUser.displayName, style: context.txt.socialUserName),
                        if (post.createdAt != null)
                          Text(
                            formatPostTime(post.createdAt!),
                            style: context.txt.socialPostSince,
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.topStart,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Text(post.postHead, style: context.txt.socialPostHead),
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.95,
          child: PostCarousel(
            userName: postUser.displayName,
            source: post.sourceUrl,
            onPageChanged: (i) => context.read<SocialCubit>().changeCarouselIndex(i),
          ),
        ),
      ],
    );
  }
}

class _CommentsSection extends StatefulWidget {
  final Post post;
  final TextEditingController newComment;
  final ValueNotifier<bool> isSending;
  final List<ChatMember> members;
  final ChatMember? currentMember;
  final String selectedCompoundId;

  const _CommentsSection({
    required this.post,
    required this.newComment,
    required this.isSending,
    required this.members,
    required this.currentMember,
    required this.selectedCompoundId,
  });

  @override
  State<_CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<_CommentsSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.post.comments.length,
          itemBuilder: (context, index) {
            final comment = widget.post.comments[index];
            final commentAuthorId = comment['author_id']?.toString() ?? 'unknown';
            final commentUser = widget.members.firstWhere(
              (member) => member.id.trim() == commentAuthorId,
              orElse: () => fallbackSocialMember(commentAuthorId),
            );
            return ListTile(
              leading: CircleAvatar(
                radius: 12,
                backgroundImage: socialAvatarProvider(commentUser.avatarUrl),
              ),
              title: Text(
                commentUser.displayName,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                comment['comment'] ?? '',
                style: const TextStyle(fontSize: 12),
              ),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: widget.newComment,
                  decoration: const InputDecoration(
                    hintText: 'Add a comment...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: widget.isSending,
                builder: (context, sending, child) {
                  return IconButton(
                    icon: sending
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                    onPressed: sending
                        ? null
                        : () async {
                            if (widget.newComment.text.trim().isEmpty) return;
                            widget.isSending.value = true;
                            await context.read<SocialCubit>().addComment(
                                  compoundId: widget.selectedCompoundId,
                                  postId: widget.post.id,
                                  commentText: widget.newComment.text,
                                  authorId: widget.currentMember!.id,
                                  currentComments: widget.post.comments,
                                );
                            widget.newComment.clear();
                            widget.isSending.value = false;
                            if (mounted) setState(() {});
                          },
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
