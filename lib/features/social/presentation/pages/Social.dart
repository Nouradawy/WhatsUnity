import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:WhatsUnity/features/social/presentation/bloc/social_cubit.dart';
import 'package:WhatsUnity/features/social/presentation/widgets/social_feed_tab.dart';

import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/bloc/mention_notification_cubit.dart';
import '../../../chat/presentation/widgets/chatWidget/GeneralChat/GeneralChat.dart';

class Social extends StatefulWidget {
  Social({super.key});

  @override
  State<Social> createState() => _SocialState();
}

class _SocialState extends State<Social> {
  final TextEditingController postHead = TextEditingController();
  TabController? _tabController;
  String? _lastGeneralSeenKey;

  // Avoids missing first fetch when compound is set late on cold start.
  String? _postsFetchedForCompoundId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final controller = DefaultTabController.of(context);
    if (!identical(_tabController, controller)) {
      _tabController?.removeListener(_handleTabSelection);
      _tabController = controller;
      _tabController?.addListener(_handleTabSelection);
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    postHead.dispose();
    super.dispose();
  }

  void _handleTabSelection() {
    final controller = _tabController;
    if (controller == null || controller.indexIsChanging || controller.index != 1) {
      return;
    }
    final authState = context.read<AuthCubit>().state;
    _markGeneralMentionsAsSeenIfNeeded(authState);
  }

  void _markGeneralMentionsAsSeenIfNeeded(AuthState authState) {
    if (authState is! Authenticated) return;
    final selectedCompoundId = authState.selectedCompoundId;
    if (selectedCompoundId == null || selectedCompoundId.isEmpty) return;
    final key = '${authState.user.id}_$selectedCompoundId';
    if (_lastGeneralSeenKey == key) return;
    _lastGeneralSeenKey = key;
    context
        .read<MentionNotificationCubit>()
        .markGeneralMentionsAsSeen(authState);
  }

  @override
  Widget build(BuildContext context) {
    // Only rebuild when properties that actually affect this screen change.
    // Member-list updates (e.g. avatar changes) must NOT recreate TabBarView
    // because that destroys GeneralChat's controller and list state.
    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: (previous, current) {
        // Always rebuild when auth type changes (e.g. sign-out).
        if (current.runtimeType != previous.runtimeType) return true;
        if (current is! Authenticated || previous is! Authenticated) return true;
        // Only rebuild for changes that matter to this screen's layout.
        return previous.selectedCompoundId != current.selectedCompoundId ||
            previous.user.id != current.user.id ||
            !identical(previous.currentUser, current.currentUser) ||
            previous.chatMembers.length != current.chatMembers.length;
      },
      builder: (context, authState) {
        if (authState is! Authenticated) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        final currentMember = authState.currentUser;
        final members = authState.chatMembers;
        final memberById = {for (final m in members) m.id.trim(): m};
        final selectedCompoundId = authState.selectedCompoundId;

        if (selectedCompoundId == null) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }

        if ((_tabController?.index ?? 0) == 1) {
          _markGeneralMentionsAsSeenIfNeeded(authState);
        } else {
          _lastGeneralSeenKey = null;
        }

        if (selectedCompoundId != _postsFetchedForCompoundId) {
          _postsFetchedForCompoundId = selectedCompoundId;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            context.read<SocialCubit>().getPosts(selectedCompoundId);
          });
        }

        return Column(
          children: [
            TabBar(
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              tabs: [
                Tab(text: context.loc.socialTab),
                Tab(
                  child: BlocBuilder<MentionNotificationCubit,
                      MentionNotificationState>(
                    buildWhen: (previous, current) =>
                        previous.unreadGeneralMentionCount !=
                        current.unreadGeneralMentionCount,
                    builder: (context, mentionState) {
                      final unreadCount = mentionState.unreadGeneralMentionCount;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(context.loc.chatTab),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                color: Colors.red.shade600,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            Expanded(
              child: TabBarView(
                physics: const LessSensitivePageScrollPhysics(),
                children: [
                  SocialFeedTab(
                    currentMember: currentMember,
                    selectedCompoundId: selectedCompoundId,
                    members: members,
                    memberById: memberById,
                    postHeadController: postHead,
                  ),
                  // Keyed by user+compound so the widget is fully destroyed and
                  // recreated whenever the session or community changes, preventing
                  // stale controllers from leaking into the new context.
                  GeneralChat(
                    key: ValueKey('${authState.user.id}_$selectedCompoundId'),
                    compoundId: selectedCompoundId,
                    channelName: 'COMPOUND_GENERAL',
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

}

class LessSensitivePageScrollPhysics extends PageScrollPhysics {
  const LessSensitivePageScrollPhysics({super.parent});

  @override
  LessSensitivePageScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return LessSensitivePageScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics metrics, double velocity) {
    if ((velocity.abs() < tolerance.velocity) || (velocity > 0.0 && metrics.pixels >= metrics.maxScrollExtent) || (velocity < 0.0 && metrics.pixels <= metrics.minScrollExtent)) {
      return super.createBallisticSimulation(metrics, velocity);
    }

    final double target = _getTargetPixels(metrics, velocity);
    if (target != metrics.pixels) {
      return ScrollSpringSimulation(spring, metrics.pixels, target, velocity, tolerance: tolerance);
    }
    return null;
  }

  double _getTargetPixels(ScrollMetrics metrics, double velocity) {
    double page = metrics.pixels / metrics.viewportDimension;
    if (velocity < -tolerance.velocity) {
      page -= 0.6;
    } else if (velocity > tolerance.velocity) {
      page += 0.6;
    }
    return page.round() * metrics.viewportDimension;
  }
}

