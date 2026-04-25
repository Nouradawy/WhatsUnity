import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:WhatsUnity/core/constants/Constants.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import 'package:WhatsUnity/features/social/domain/entities/post.dart';
import 'package:WhatsUnity/features/social/presentation/bloc/social_cubit.dart';
import 'package:WhatsUnity/features/social/presentation/bloc/social_state.dart';

import 'comment_popup_dialog.dart';
import 'create_post_dialog.dart';
import 'social_member_utils.dart';

class SocialFeedTab extends StatelessWidget {
  final ChatMember? currentMember;
  final String selectedCompoundId;
  final List<ChatMember> members;
  final Map<String, ChatMember> memberById;
  final TextEditingController postHeadController;

  const SocialFeedTab({
    super.key,
    required this.currentMember,
    required this.selectedCompoundId,
    required this.members,
    required this.memberById,
    required this.postHeadController,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SocialCubit, SocialState>(
      builder: (context, state) {
        final socialCubit = context.read<SocialCubit>();
        final posts = socialCubit.posts;

        if (state is SocialLoading && posts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return RefreshIndicator(
          onRefresh: () => socialCubit.getPosts(selectedCompoundId),
          child: ListView.builder(
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _CreatePostLauncher(
                  currentMember: currentMember,
                  postHeadController: postHeadController,
                  selectedCompoundId: selectedCompoundId,
                );
              }

              final post = posts[index - 1];
              final authorId = post.authorId.trim();
              final postUser =
                  memberById[authorId] ?? fallbackSocialMember(post.authorId);

              return _PostCard(
                post: post,
                postUser: postUser,
                selectedCompoundId: selectedCompoundId,
                members: members,
                currentMember: currentMember,
              );
            },
          ),
        );
      },
    );
  }
}

class _CreatePostLauncher extends StatelessWidget {
  final ChatMember? currentMember;
  final TextEditingController postHeadController;
  final String selectedCompoundId;

  const _CreatePostLauncher({
    required this.currentMember,
    required this.postHeadController,
    required this.selectedCompoundId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey.shade200,
            backgroundImage: socialAvatarProvider(currentMember?.avatarUrl),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: MediaQuery.sizeOf(context).width * 0.75,
            child: MaterialButton(
              elevation: 0,
              color: context.txt.statusButtonColor,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => CreatePostDialog(
                    postHead: postHeadController,
                    currentMember: currentMember,
                    selectedCompoundId: selectedCompoundId,
                  ),
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(context.loc.statusButton),
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  final Post post;
  final ChatMember postUser;
  final String selectedCompoundId;
  final List<ChatMember> members;
  final ChatMember? currentMember;

  const _PostCard({
    required this.post,
    required this.postUser,
    required this.selectedCompoundId,
    required this.members,
    required this.currentMember,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: MediaQuery.sizeOf(context).width * 0.95,
              margin: const EdgeInsets.only(top: 20),
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
                            Text(postUser.displayName,
                                style: context.txt.socialUserName),
                            if (post.createdAt != null)
                              Text(
                                formatPostTime(post.createdAt!),
                                style: context.txt.socialPostSince,
                              ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: AlignmentDirectional.topStart,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child:
                            Text(post.postHead, style: context.txt.socialPostHead),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 15,
              top: 28,
              child: PopupMenuButton<String>(
                tooltip: '',
                onSelected: (_) async {
                  await context.read<SocialCubit>().deleteMyPost(
                        compoundId: selectedCompoundId,
                        authorId: post.authorId,
                        postId: post.id,
                      );
                  if (!context.mounted) return;
                },
                itemBuilder: (ctx) => const [
                  PopupMenuItem<String>(value: 'Delete', child: Text('Delete'))
                ],
                child: const Icon(Icons.more_horiz),
              ),
            ),
          ],
        ),
        SizedBox(
          width: MediaQuery.sizeOf(context).width * 0.95,
          child: PostCarousel(
            userName: postUser.displayName,
            source: post.sourceUrl,
            onPageChanged: (i) => context.read<SocialCubit>().changeCarouselIndex(i),
          ),
        ),
        Container(
          width: MediaQuery.sizeOf(context).width * 0.95,
          decoration: BoxDecoration(
            color: context.txt.socialBackgroundColor,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: MediaQuery.sizeOf(context).width * 0.04,
                  vertical: 4,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${post.comments.length} ${context.loc.comment}',
                      style: context.txt.commentsCount,
                    )
                  ],
                ),
              ),
              const Divider(
                indent: 0.04,
                endIndent: 0.04,
                height: 1.1,
                color: Colors.black12,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _ActionButton(
                      icon: Icons.thumb_up_alt_outlined,
                      label: context.loc.like,
                      onPressed: () {},
                    ),
                    _ActionButton(
                      icon: Icons.chat_outlined,
                      label: context.loc.comment,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (_) => CommentPopupDialog(
                            post: post,
                            postUser: postUser,
                            members: members,
                            currentMember: currentMember,
                            selectedCompoundId: selectedCompoundId,
                          ),
                        );
                      },
                    ),
                    _ActionButton(
                      icon: Icons.share_rounded,
                      label: context.loc.share,
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return MaterialButton(
      onPressed: onPressed,
      child: Row(
        children: [
          Icon(icon, color: context.txt.socialIconColor, size: 20),
          const SizedBox(width: 5),
          Text(label),
        ],
      ),
    );
  }
}
