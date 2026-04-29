import 'dart:async';

import 'package:WhatsUnity/core/di/app_services.dart';
import 'package:WhatsUnity/features/social/presentation/bloc/social_cubit.dart';
import 'package:WhatsUnity/features/social/presentation/bloc/social_state.dart';
import 'package:condition_builder/condition_builder.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier, kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:flutter_chat_reactions/flutter_chat_reactions.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:http/http.dart' as http;

import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/chat/data/chat_channel_id_cache.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_details_cubit.dart';
import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/config/appwrite.dart' show appwriteTables;
import 'package:WhatsUnity/core/constants/Constants.dart';
import 'package:WhatsUnity/core/media/media_services.dart';
import 'package:WhatsUnity/core/media/media_upload_exception.dart';
import 'package:WhatsUnity/core/media/media_upload_metadata.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_state.dart';
import 'package:WhatsUnity/features/chat/presentation/utils/audio_message_playable.dart';
import 'package:WhatsUnity/features/admin/presentation/bloc/report_cubit.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mime/mime.dart';

import 'package:uuid/uuid.dart';

import 'package:WhatsUnity/core/time/trusted_utc_now.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/BrainStorming.dart';
import 'package:WhatsUnity/features/chat/data/models/chat_member_model.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/Details/ChatDetails.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/presence_cubit.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/presence_state.dart';
import 'ChatCacheService.dart';
import 'ReplyBar.dart';
import 'message_row_wrapper.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget
// ─────────────────────────────────────────────────────────────────────────────

class GeneralChat extends StatefulWidget {
  final String compoundId;
  final String channelName;

  const GeneralChat({
    super.key,
    required this.compoundId,
    required this.channelName,
  });

  @override
  State<GeneralChat> createState() => _GeneralChatState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal model: tracks a visible message for sticky date header computation
// ─────────────────────────────────────────────────────────────────────────────

class _VisibleMessage {
  final int index;
  final double fraction;
  final DateTime? createdAt;
  _VisibleMessage(this.index, this.fraction, this.createdAt);
}

class _MentionSuggestionItem {
  final String mentionToken;
  final String displayName;
  final String? avatarUrl;
  final bool isSpecial;

  const _MentionSuggestionItem({
    required this.mentionToken,
    required this.displayName,
    this.avatarUrl,
    this.isSpecial = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _GeneralChatState extends State<GeneralChat>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  // ── AutomaticKeepAliveClientMixin ──────────────────────────────────────────
  //
  // Keeps this widget alive while the parent TabBarView is in the tree so that
  // switching tabs does not destroy and recreate the state, re-run
  // _initializeChat(), or spin up duplicate Supabase subscriptions.
  //
  // The mixin ONLY prevents deactivation by the TabBarView. When Social.dart
  // removes the TabBarView on sign-out (BlocBuilder returns a spinner), Flutter
  // disposes the entire subtree — including this widget — normally.
  @override
  bool get wantKeepAlive => true;

  // ── Lifecycle Guards ───────────────────────────────────────────────────────

  /// Set to `true` at the very start of [dispose] so every in-flight async
  /// continuation can bail out before it touches any disposed object.
  bool _disposed = false;

  /// Raised as soon as the auth state becomes non-[Authenticated] — either via
  /// the direct [_authStateSubscription] (same microtask as the cubit emit) or
  /// inside [build] as a safety net for the next frame.
  ///
  /// Once raised, nothing is allowed to mutate [_chatController]. This prevents
  /// the SliverAnimatedList crash that occurs when its GlobalKey.currentState
  /// is null after the Chat widget has been removed from the tree.
  bool _tearingDown = false;

  /// Direct subscription to AuthCubit's stream, established in [initState].
  ///
  /// This is the critical difference from watching auth state only in [build]:
  /// Supabase realtime events and the auth-state emit can arrive in the same
  /// microtask. Subscribing here ensures [_tearingDown] is raised *before* the
  /// next ChatCubit event can reach [_chatController].
  StreamSubscription<AuthState>? _authStateSubscription;

  // ── Serialized Sync Queue ──────────────────────────────────────────────────
  //
  // Only one [_syncChatFromCubit] runs at a time. If a newer ChatState arrives
  // while a sync is in-flight the in-flight sync is superseded (via
  // [_syncVersion]) and [_pendingSync] holds the latest data to process next.

  /// Incremented on every [_raiseTeardownGuard] and [dispose] call. In-flight
  /// async continuations compare against the version captured at their start
  /// and abort if it has changed.
  int _syncVersion = 0;
  bool _syncActive = false;
  ChatMessagesLoaded? _pendingSync;

  // ── Offstage Awareness ────────────────────────────────────────────────────
  //
  // IndexedStack sets TickerMode to false for offstage children but does NOT
  // pause stream subscriptions. We track visibility ourselves so we can:
  //   1. Defer _initializeChat() until the widget is first shown.
  //   2. Pause the sync queue while offstage (prevents SliverAnimatedList
  //      mutations on a list whose render object may not be fully active).

  /// Whether `_initializeChat` has been called at least once.
  bool _chatInitialized = false;

  /// `true` while this widget's tickers are disabled (offstage in IndexedStack).
  bool _offstage = false;

  // ── UI State ───────────────────────────────────────────────────────────────

  bool _isInitializing = true;
  bool _isUserScrolling = false;
  Timer? _scrollIdleTimer;
  String? _channelId;
  String _currentUserId = '';

  // ── Message State ──────────────────────────────────────────────────────────

  final Map<String, types.User> _userCache = {};
  final Set<String> _pendingUserResolutions = <String>{};
  final Map<String, ImageProvider<Object>> _avatarImageProviderByUserId = {};
  bool _avatarPrefetchScheduled = false;
  final Map<String, ValueNotifier<int>> _avatarVersionByUserId = {};

  /// Maps a placeholder message ID to its current upload progress (0.0–1.0).
  final Map<String, double> _uploadProgressByMessageId = {};
  types.Message? _repliedMessage;
  final ValueNotifier<List<_MentionSuggestionItem>> _mentionSuggestionsNotifier =
      ValueNotifier<List<_MentionSuggestionItem>>(
        const <_MentionSuggestionItem>[],
      );

  // ── Sticky Date Header State ───────────────────────────────────────────────

  final ValueNotifier<DateTime?> _stickyHeaderDateNotifier =
      ValueNotifier<DateTime?>(null);
  final ValueNotifier<double> _stickyHeaderOpacityNotifier =
      ValueNotifier<double>(0.0);
  final Map<String, _VisibleMessage> _visibleMessagesForHeader = {};
  Timer? _typingIdleTimer;
  bool _typingStatusActive = false;

  // ── Audio Processing ───────────────────────────────────────────────────────

  /// Active polling timers keyed by message ID. Polls audio URLs until the
  /// file has finished processing server-side, then marks the message 'ready'.
  final Map<String, Timer> _audioPollingTimers = {};

  // ── Controllers ────────────────────────────────────────────────────────────

  late final TextEditingController _textInputController;
  late final types.InMemoryChatController _chatController;

  /// Initialized in [initState] (not in [_initializeChat]) so it is always
  /// ready before the first [build] and is always paired with a [dispose] call,
  /// even if [_initializeChat] exits early.
  late final ReactionsController _reactionsController;

  /// Key for the [Chat] widget. A new [UniqueKey] is assigned:
  ///   - in [initState] (fresh per sign-in session)
  ///   - when transitioning offstage → onstage (fresh per tab switch)
  ///
  /// Assigning a new key forces Flutter to unmount the old [Chat] (destroying
  /// its [ChatAnimatedList] + [SliverAnimatedList]) and mount a fresh one whose
  /// `_oldList` is synced with [_chatController.messages]. This is the
  /// programmatic equivalent of the manual "open BrainStorming → close it"
  /// workaround that reliably clears corrupted animated-list state.
  late Key _chatSurfaceKey;

  ChatCacheService? _cacheService;

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _chatSurfaceKey = UniqueKey();
    _chatController = types.InMemoryChatController();
    _textInputController = TextEditingController();
    _textInputController.addListener(_handleTypingStatusChange);

    // Read auth state once synchronously — safe because GeneralChat is only
    // inserted into the tree while the user is Authenticated (Social.dart guards
    // the insertion point).
    final authState = context.read<AuthCubit>().state;
    _currentUserId = (authState is Authenticated) ? authState.user.id : '';
    _reactionsController = ReactionsController(currentUserId: _currentUserId);

    // Subscribe to AuthCubit directly so [_tearingDown] is raised the SAME
    // instant the cubit emits — before the Flutter scheduler runs build().
    // Without this, a Supabase realtime event arriving in the same microtask
    // as the sign-out emit would reach [_chatController.setMessages] while
    // [_tearingDown] is still false, triggering:
    //   "child == null || indexOf(child) > index" (SliverAnimatedList)
    _authStateSubscription = context.read<AuthCubit>().stream.listen((state) {
      if (state is! Authenticated) _raiseTeardownGuard();
    });

    // NOTE: _initializeChat() is NOT called here. It is deferred until the
    // widget is actually visible (TickerMode enabled) — see build(). This
    // prevents an offstage GeneralChat in IndexedStack from setting up Supabase
    // subscriptions that pump operations into a SliverAnimatedList whose render
    // object is not fully active, causing the assertion crash.
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && kIsWeb) {
      // On PWA resume, the WebSocket might have been disconnected while backgrounded.
      // Re-fetch the latest messages to catch up on anything missed.
      if (_channelId != null && mounted) {
        context.read<ChatCubit>().refreshMessages();
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cacheService ??= ChatCacheService(AppServices.chatLocalDataSource);
  }

  String? _normalizeAvatarUrl(String? rawUrl) {
    if (rawUrl == null) return null;
    final trimmedUrl = rawUrl.trim();
    if (trimmedUrl.isEmpty || trimmedUrl.toLowerCase() == 'null') return null;
    return trimmedUrl;
  }

  static final ValueNotifier<int> _kEmptyAvatarVersion = ValueNotifier<int>(0);

  ValueListenable<int> _avatarVersionListenableForUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return _kEmptyAvatarVersion;
    return _avatarVersionByUserId.putIfAbsent(
      id,
      () => ValueNotifier<int>(0),
    );
  }

  void _bumpAvatarVersionForUser(String userId) {
    final id = userId.trim();
    if (id.isEmpty) return;
    final n = _avatarVersionByUserId.putIfAbsent(
      id,
      () => ValueNotifier<int>(0),
    );
    n.value++;
  }

  void _scheduleAvatarPrefetch(List<ChatMember> chatMembers) {
    if (_avatarPrefetchScheduled) return;
    _avatarPrefetchScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _avatarPrefetchScheduled = false;
      if (!mounted) return;
      final uncachedMembers = chatMembers.where((chatMember) {
        final userId = chatMember.id.trim();
        final avatarUrl = _normalizeAvatarUrl(chatMember.avatarUrl);
        if (userId.isEmpty || avatarUrl == null) return false;
        return !_avatarImageProviderByUserId.containsKey(userId);
      }).toList(growable: false);
      if (uncachedMembers.isEmpty) return;

      const int prefetchBatchSize = 6;
      for (var start = 0; start < uncachedMembers.length; start += prefetchBatchSize) {
        final end = (start + prefetchBatchSize > uncachedMembers.length)
            ? uncachedMembers.length
            : start + prefetchBatchSize;
        final batchMembers = uncachedMembers.sublist(start, end);
        await Future.wait(
          batchMembers.map((chatMember) async {
            final userId = chatMember.id.trim();
            final avatarUrl = _normalizeAvatarUrl(chatMember.avatarUrl);
            if (userId.isEmpty || avatarUrl == null) return;
            if (_avatarImageProviderByUserId.containsKey(userId)) return;
            final imageProvider = CachedNetworkImageProvider(avatarUrl);
            try {
              await precacheImage(imageProvider, context);
              _avatarImageProviderByUserId[userId] = imageProvider;
              if (mounted) _bumpAvatarVersionForUser(userId);
            } catch (_) {
              // Ignore prefetch failures and keep the runtime fallback path.
            }
          }),
        );
      }
    });
  }

  @override
  void dispose() {
    if (_typingStatusActive) {
      unawaited(context.read<PresenceCubit>().updatePresenceStatus('online'));
    }
    // Raise both guards FIRST so every in-flight async continuation bails out
    // before it can touch _chatController or _reactionsController.
    _disposed = true;
    _tearingDown = true;
    _syncVersion++;
    _pendingSync = null;

    // Cancel the auth subscription before any other teardown so the listener
    // cannot fire after _chatController has been disposed.
    _authStateSubscription?.cancel();
    _authStateSubscription = null;

    for (final timer in _audioPollingTimers.values) {
      timer.cancel();
    }
    _audioPollingTimers.clear();

    if (_channelId != null) {
      _cacheService?.saveMessages(_channelId!, _chatController.messages);
    }

    _chatController.dispose();

    WidgetsBinding.instance.removeObserver(this);

    // CRITICAL: dispose ReactionsController to remove any OverlayEntry widgets
    // (and their GlobalKeys). Failing to do this leaves stale GlobalKeys in the
    // global overlay that collide with the next session's ReactionsController.
    _reactionsController.dispose();

    _textInputController.removeListener(_handleTypingStatusChange);
    _textInputController.dispose();
    _mentionSuggestionsNotifier.dispose();
    _stickyHeaderDateNotifier.dispose();
    _stickyHeaderOpacityNotifier.dispose();
    for (final n in _avatarVersionByUserId.values) {
      n.dispose();
    }
    _avatarVersionByUserId.clear();
    _scrollIdleTimer?.cancel();
    _typingIdleTimer?.cancel();

    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Sync Queue
  // ─────────────────────────────────────────────────────────────────────────

  /// Raises the teardown guard and cancels all pending controller mutations.
  ///
  /// Called by [_authStateSubscription] immediately when auth is lost, and by
  /// [build] as a safety net on the following frame.
  void _raiseTeardownGuard() {
    if (_tearingDown) return;
    _tearingDown = true;
    _syncVersion++;  // invalidates any in-flight [_syncChatFromCubit]
    _pendingSync = null; // drops queued work so [_drainSyncQueue] exits cleanly
  }

  /// Enqueues a sync from the cubit. At most one sync runs at a time; if a
  /// newer state arrives while one is in-flight, the old one is superseded so
  /// only the latest data is ever committed to the SliverAnimatedList.
  void _enqueueSyncFromCubit(ChatMessagesLoaded loaded) {
    if (_disposed || _tearingDown || _offstage) return;
    _pendingSync = loaded;
    if (!_syncActive) _drainSyncQueue();
  }

  Future<void> _drainSyncQueue() async {
    _syncActive = true;
    while (_pendingSync != null && !_disposed && !_tearingDown && !_offstage) {
      final loaded = _pendingSync!;
      _pendingSync = null;
      await _syncChatFromCubit(loaded);
    }
    _syncActive = false;
  }

  Future<void> _syncChatFromCubit(ChatMessagesLoaded loaded) async {
    if (_disposed || _tearingDown || !mounted || _offstage) return;

    // Capture version at entry. dispose() or _raiseTeardownGuard() increment
    // this, causing stale continuations to bail after every await point.
    final version = _syncVersion;

    for (final message in loaded.messages) {
      if (message is types.AudioMessage &&
          message.metadata?['status'] == 'processing') {
        if (_audioPollingTimers.containsKey(message.id)) {
          continue;
        }
        _startPollingForAudioMessage(message);
      }
    }

    await _applyMessagesToController(loaded.messages);
    if (_disposed || _tearingDown || !mounted || _syncVersion != version) return;

    // Remove local placeholder messages that the server has now confirmed.
    final placeholderIdsToRemove = loaded.messages
        .where((m) => m.metadata?['localId'] != null && m.id != m.metadata!['localId'])
        .map<String>((m) => m.metadata!['localId'] as String)
        .toList();

    for (final placeholderId in placeholderIdsToRemove) {
      if (_disposed || _tearingDown || !mounted || _offstage || _syncVersion != version) return;
      try {
        final placeholder =
            _chatController.messages.firstWhere((m) => m.id == placeholderId);
        await _chatController.removeMessage(placeholder);
      } catch (_) {
        // Placeholder may have already been removed; safe to ignore.
      }
    }
  }

  /// Merges [serverMessages] with any controller-only rows (e.g. upload
  /// placeholders) and commits the combined, chronologically sorted list to
  /// [_chatController].
  ///
  /// Deduplicates by ID first because Supabase realtime can deliver the same
  /// message twice on reconnect, and [InMemoryChatController.setMessages]
  /// asserts unique IDs.
  ///
  /// **Avoiding the `_onChanged` crash:** `flutter_chat_ui`'s
  /// `_ChatAnimatedListState._onChanged` calls `_onRemoved(pos)` then
  /// `_onInserted(pos)` at the **same index** without waiting for the removal
  /// animation to complete. The still-present element triggers:
  ///   `'child == null || indexOf(child) > index': is not true`
  /// A `change` diff operation is produced whenever two messages share the
  /// same ID but differ in content (e.g. `seenAt` updated, reactions changed).
  /// To avoid this, we detect content-changes and use a **clear → re-set**
  /// strategy that produces only remove and insert operations (never change).
  ///
  /// After a successful setMessages call, [_hydrateReactionsController] is
  /// called to keep [_reactionsController] in sync with the persisted metadata.
  Future<void> _applyMessagesToController(
      List<types.Message> serverMessages) async {
    if (_disposed || _tearingDown || _offstage) return;

    final dedupedServer = _deduplicateById(serverMessages);
    final serverIds = dedupedServer.map((m) => m.id).toSet();

    final deviceOnlyMessages = _chatController.messages
        .where((m) => !serverIds.contains(m.id))
        .toList();

    final merged = _sortedByCreatedAt([...dedupedServer, ...deviceOnlyMessages]);

    if (_chatMessageListsEqual(merged, _chatController.messages)) {
      return;
    }

    try {
      final needsClearFirst = _wouldProduceContentChanges(merged);
      if (needsClearFirst) {
        // Clear → re-set: the first call produces only removes, the second
        // only inserts. Neither produces a `change` operation, side-stepping
        // the _onChanged assertion bug in flutter_chat_ui.
        await _chatController.setMessages(const [], animated: false);
        if (_disposed || _tearingDown || _offstage) return;
      }
      await _chatController.setMessages(merged, animated: !needsClearFirst);

      if (!_disposed && !_tearingDown && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_disposed && !_tearingDown && mounted) {
            _hydrateReactionsController(merged);
          }
        });
      }
    } catch (e) {
      debugPrint(
          'GeneralChat._applyMessagesToController: setMessages threw — '
          'recovering with Chat widget recreation. ($e)');
      // The SliverAnimatedList's internal _oldList is now permanently
      // desynced from _chatController.messages. Force-recreate the entire
      // Chat widget so a fresh ChatAnimatedList picks up the correct state.
      if (mounted && !_disposed && !_tearingDown) {
        setState(() => _chatSurfaceKey = UniqueKey());
      }
    }
  }

  /// Returns `true` if calling [setMessages] with [newMessages] would produce
  /// a `change` diff operation (same ID, different content). These crash
  /// `flutter_chat_ui`'s `_onChanged` implementation.
  bool _chatMessageListsEqual(List<types.Message> a, List<types.Message> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _wouldProduceContentChanges(List<types.Message> newMessages) {
    final oldMap = <String, types.Message>{
      for (final m in _chatController.messages) m.id: m,
    };
    for (final m in newMessages) {
      final old = oldMap[m.id];
      if (old != null && old != m) return true;
    }
    return false;
  }

  /// Seeds [_reactionsController] from the reactions stored in every message's
  /// `metadata['reactions']` map.
  ///
  /// The metadata structure written by `_updateMessageReactions` is:
  /// ```json
  /// { "👍": { "userId1": true, "userId2": true }, "❤️": { "userId3": true } }
  /// ```
  ///
  /// **Must be called via `addPostFrameCallback`** (never synchronously after
  /// `setMessages`) so that `ReactionsController.notifyListeners()` fires in
  /// the next frame — after the SliverAnimatedList animation has been committed
  /// — preventing the "child == null || indexOf(child) > index" assertion and
  /// the Duplicate GlobalKey errors caused by mid-animation rebuilds.
  ///
  /// Uses [ReactionsController.loadAllReactions] to update all messages and
  /// call `notifyListeners()` exactly once, regardless of how many messages
  /// carry reactions.
  void _hydrateReactionsController(List<types.Message> messages) {
    final batchReactions = <String, List<Reaction>>{};

    for (final message in messages) {
      final rawReactions = message.metadata?['reactions'];
      if (rawReactions is! Map || rawReactions.isEmpty) continue;

      final reactionList = <Reaction>[];
      rawReactions.forEach((emojiKey, usersRaw) {
        if (usersRaw is! Map) return;
        usersRaw.forEach((userIdKey, val) {
          final isActive = val == true || val == 1 || val == 'true';
          if (!isActive || userIdKey == null) return;
          reactionList.add(Reaction(
            emoji: emojiKey.toString(),
            userId: userIdKey.toString(),
            timestamp: message.createdAt ?? DateTime.now(),
          ));
        });
      });

      if (reactionList.isNotEmpty) {
        batchReactions[message.id] = reactionList;
      }
    }

    // Single notifyListeners() call for the entire page — avoids scheduling
    // one rebuild per message and keeps the widget tree stable.
    if (batchReactions.isNotEmpty) {
      _reactionsController.loadAllReactions(batchReactions);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Initialization
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _initializeChat() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) {
      if (mounted) setState(() => _isInitializing = false);
      return;
    }

    _currentUserId = authState.user.id;

    try {
      if (widget.channelName != 'COMPOUND_GENERAL') {
        await _waitForChatMemberToLoad(_currentUserId, authState.chatMembers);
      }

      final memberMatches = authState.chatMembers
          .where((m) => m.id.trim() == _currentUserId);
      final currentMember = memberMatches.isEmpty ? null : memberMatches.first;
      final buildingNumber = currentMember?.building;
      debugPrint('Building number: $buildingNumber');

      final cacheBuildingSegment = widget.channelName == 'COMPOUND_GENERAL'
          ? '__general__'
          : (buildingNumber?.trim().isNotEmpty == true
              ? buildingNumber!.trim()
              : '__building_unknown__');

      String? resolvedChannelId;
      try {
        resolvedChannelId = await AppServices.chatRepository.resolveChannelDocumentId(
              compoundId: widget.compoundId.toString(),
              channelType: widget.channelName,
              buildingNameForScopedChat:
                  widget.channelName != 'COMPOUND_GENERAL' ? buildingNumber : null,
            );
        if (!mounted) return;
        if (resolvedChannelId != null && resolvedChannelId.isNotEmpty) {
          await ChatChannelIdCache.write(
            compoundId: widget.compoundId,
            channelName: widget.channelName,
            buildingSegment: cacheBuildingSegment,
            channelId: resolvedChannelId,
          );
        }
      } catch (error, st) {
        debugPrint('_initializeChat network resolve: $error\n$st');
      }

      if (resolvedChannelId == null || resolvedChannelId.isEmpty) {
        resolvedChannelId = await ChatChannelIdCache.read(
          compoundId: widget.compoundId,
          channelName: widget.channelName,
          buildingSegment: cacheBuildingSegment,
        );
        if (resolvedChannelId != null) {
          debugPrint(
            'Using cached channel id (offline or empty resolve): '
            '${widget.channelName} → $resolvedChannelId',
          );
        }
      }

      if (!mounted) return;

      _channelId = resolvedChannelId;

      if (_channelId != null) {
        final chatCubit = context.read<ChatCubit>();
        chatCubit.channelId = _channelId;
        await chatCubit.initChat(channelId: _channelId!, currentUserId: _currentUserId);
        if (!mounted || _disposed || _tearingDown) return;
        chatCubit.showHideMic(_textInputController.text.isEmpty);
      } else {
        debugPrint('Channel ID not found for compound ${widget.compoundId}.');
      }
    } catch (error) {
      debugPrint('_initializeChat error: $error');
    } finally {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  /// Polls [chatMembers] up to [timeout] waiting for the current user's entry
  /// to appear. Used for building-specific channels that require the member
  /// profile before the channel query can be scoped correctly.
  Future<void> _waitForChatMemberToLoad(
    String userId,
    List<ChatMember> chatMembers, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (mounted) {
      if (chatMembers.any((m) => m.id.trim() == userId)) return;
      if (DateTime.now().isAfter(deadline)) {
        debugPrint('Timed out waiting for ChatMember; proceeding without it.');
        return;
      }
      await Future.delayed(const Duration(milliseconds: 60));
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Event Handlers
  // ─────────────────────────────────────────────────────────────────────────

  void _handleTypingStatusChange() {
    context.read<ChatCubit>().showHideMic(_textInputController.text.isEmpty);
    _updateMentionSuggestions();
    final presenceCubit = context.read<PresenceCubit>();
    final hasText = _textInputController.text.trim().isNotEmpty;
    if (hasText) {
      _typingIdleTimer?.cancel();
      if (!_typingStatusActive) {
        _typingStatusActive = true;
        unawaited(presenceCubit.updatePresenceStatus('typing'));
      }
      _typingIdleTimer = Timer(const Duration(seconds: 2), () {
        _typingStatusActive = false;
        unawaited(presenceCubit.updatePresenceStatus('online'));
      });
    } else if (_typingStatusActive) {
      _typingStatusActive = false;
      _typingIdleTimer?.cancel();
      unawaited(presenceCubit.updatePresenceStatus('online'));
    }
  }

  Future<void> _handleSendPressed(String text) async {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_channelId == null) return;
    await context.read<ChatCubit>().sendMessage(
          text: text,
          channelId: _channelId!,
          userId: _currentUserId,
          repliedMessage: _repliedMessage,
        );
    _typingStatusActive = false;
    _typingIdleTimer?.cancel();
    unawaited(context.read<PresenceCubit>().updatePresenceStatus('online'));
    _mentionSuggestionsNotifier.value = const <_MentionSuggestionItem>[];
    setState(() => _repliedMessage = null);
  }

  void _updateMentionSuggestions() {
    final currentText = _textInputController.text;
    final cursor = _textInputController.selection.baseOffset;
    final currentSuggestions = _mentionSuggestionsNotifier.value;
    if (cursor <= 0 || cursor > currentText.length) {
      if (currentSuggestions.isNotEmpty) {
        _mentionSuggestionsNotifier.value = const <_MentionSuggestionItem>[];
      }
      return;
    }
    final leftText = currentText.substring(0, cursor);
    final mentionMatch = RegExp(r'@([A-Za-z0-9_\\.]*)$').firstMatch(leftText);
    if (mentionMatch == null) {
      if (currentSuggestions.isNotEmpty) {
        _mentionSuggestionsNotifier.value = const <_MentionSuggestionItem>[];
      }
      return;
    }
    final query = (mentionMatch.group(1) ?? '').toLowerCase();
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;
    final mentionItems = <_MentionSuggestionItem>[
      const _MentionSuggestionItem(
        mentionToken: '@everyone',
        displayName: 'Everyone',
        isSpecial: true,
      ),
      const _MentionSuggestionItem(
        mentionToken: '@admin',
        displayName: 'Admins',
        isSpecial: true,
      ),
      ...authState.chatMembers
          .where((chatMember) => chatMember.displayName.trim().isNotEmpty)
          .map(
            (chatMember) => _MentionSuggestionItem(
              mentionToken:
                  '@${chatMember.displayName.trim().replaceAll(' ', '_')}',
              displayName: chatMember.displayName.trim(),
              avatarUrl: _normalizeAvatarUrl(chatMember.avatarUrl),
            ),
          ),
    ];
    final filtered = mentionItems
        .where(
          (mentionItem) =>
              mentionItem.mentionToken.toLowerCase().contains(query) ||
              mentionItem.displayName.toLowerCase().contains(query),
        )
        .take(6)
        .toList(growable: false);
    final sameLength = currentSuggestions.length == filtered.length;
    final sameItems = sameLength &&
        currentSuggestions.asMap().entries.every(
              (entry) =>
                  filtered[entry.key].mentionToken == entry.value.mentionToken,
            );
    if (sameItems) {
      return;
    }
    _mentionSuggestionsNotifier.value = filtered;
  }

  void _insertMention(String mention) {
    final currentText = _textInputController.text;
    final cursor = _textInputController.selection.baseOffset;
    if (cursor < 0 || cursor > currentText.length) return;
    final leftText = currentText.substring(0, cursor);
    final rightText = currentText.substring(cursor);
    final mentionMatch = RegExp(r'@([A-Za-z0-9_\\.]*)$').firstMatch(leftText);
    if (mentionMatch == null) return;
    final replacementStart = mentionMatch.start;
    final updatedLeft = leftText.substring(0, replacementStart);
    final inserted = '$mention ';
    final nextText = '$updatedLeft$inserted$rightText';
    _textInputController.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: (updatedLeft + inserted).length),
    );
    _mentionSuggestionsNotifier.value = const <_MentionSuggestionItem>[];
  }

  void _handleAttachmentTap() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_outlined),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(context);
                _handleImageSelection();
              },
            ),
            ListTile(
              leading: const Icon(Icons.insert_drive_file_outlined),
              title: const Text('File'),
              onTap: () {
                Navigator.pop(context);
                _handleFileSelection();
              },
            ),
            ListTile(
              leading: const Icon(Icons.poll_outlined),
              title: const Text('Poll'),
              onTap: () {
                Navigator.pop(context);
                _showCreatePollDialog();
              },
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFileSelection() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result == null || result.files.single.path == null) return;

    final file = result.files.single;
    await context.read<ChatCubit>().sendFileMessage(
          uri: file.path!,
          name: file.name,
          size: file.size,
          channelId: _channelId!,
          userId: _currentUserId,
          type: 'file',
          additionalMetadata: {'mimeType': lookupMimeType(file.path!)},
        );
  }

  Future<void> _handleImageSelection() async {
    final pickedFile = await ImagePicker().pickImage(
      imageQuality: 70,
      maxWidth: 1440,
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final localId = const Uuid().v4();
    // Insert a local placeholder immediately so the UI feels responsive.
    final placeholder = types.CustomMessage(
      id: localId,
      authorId: _currentUserId,
      createdAt: await trustedUtcNow(),
      metadata: {
        'type': 'image',
        'localId': localId,
        'filePath': pickedFile.path,
      },
    );
    if (_disposed || _tearingDown || _offstage) return;
    _chatController.insertMessage(placeholder);
    setState(() => _uploadProgressByMessageId[localId] = 0.0);

    final fileName = '${const Uuid().v4()}.${pickedFile.path.split('.').last}';

    String? imageUrl;
    try {
      if (mounted) {
        setState(() => _uploadProgressByMessageId[localId] = 0.1);
      }
      final meta = await mediaUploadService.uploadFromLocalPath(
        localFilePath: pickedFile.path,
        filenameOverride: fileName,
        mimeType: lookupMimeType(pickedFile.path),
      );
      imageUrl = meta[MediaUploadMetadataKeys.url] as String?;
      if (mounted) {
        setState(() => _uploadProgressByMessageId[localId] = 1.0);
      }
    } on MediaUploadException catch (e, st) {
      debugPrint('Image upload failed: $e\n$st');
      imageUrl = null;
    }

    if (imageUrl != null && imageUrl.isNotEmpty) {
      if (!mounted || _disposed || _tearingDown) return;
      final bytes = await pickedFile.readAsBytes();
      final image = await decodeImageFromList(bytes);
      if (!mounted || _disposed || _tearingDown) return;
      await context.read<ChatCubit>().sendFileMessage(
            uri: imageUrl,
            name: pickedFile.name,
            size: bytes.length,
            channelId: _channelId!,
            userId: _currentUserId,
            type: 'image',
            additionalMetadata: {
              'height': image.height.toDouble(),
              'width': image.width.toDouble(),
              'localId': localId,
            },
          );
    } else {
      if (_disposed || _tearingDown) return;
      setState(() {
        _uploadProgressByMessageId.remove(localId);
        if (!_offstage) _chatController.removeMessage(placeholder);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to upload image. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCreatePollDialog() {
    final questionController = TextEditingController();
    final optionControllers = [
      TextEditingController(),
      TextEditingController(),
    ];
    var durationDays = 1;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Create Poll'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: questionController,
                  maxLength: 120,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Question',
                    hintText: 'Ask something clear and specific',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ...List.generate(optionControllers.length, (i) {
                  return Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: optionControllers[i],
                          maxLength: 60,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Option ${i + 1}',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                      ),
                      if (optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          onPressed: () => setDialogState(
                              () => optionControllers.removeAt(i).dispose()),
                        ),
                    ],
                  );
                }),
                const SizedBox(height: 8),
                Row(
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add option'),
                      onPressed: optionControllers.length >= 6
                          ? null
                          : () => setDialogState(
                              () => optionControllers.add(TextEditingController())),
                    ),
                    const Spacer(),
                    DropdownButton<int>(
                      value: durationDays,
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('1 day')),
                        DropdownMenuItem(value: 7, child: Text('1 week')),
                        DropdownMenuItem(value: 30, child: Text('30 days')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => durationDays = v);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tip: keep options short and mutually exclusive for better votes.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final question = questionController.text.trim();
                final options = optionControllers
                    .map((c) => c.text.trim())
                    .where((t) => t.isNotEmpty)
                    .toList();

                if (question.isEmpty || options.length < 2) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text(
                            'Please enter a question and at least 2 options')),
                  );
                  return;
                }
                final hasDuplicateOptions =
                    options.toSet().length != options.length;
                if (hasDuplicateOptions) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Poll options must be unique.'),
                    ),
                  );
                  return;
                }

                Navigator.pop(context);
                final expiresAt =
                    (await trustedUtcNow()).add(Duration(days: durationDays));
                final optionMaps = [
                  for (var i = 0; i < options.length; i++)
                    {'id': i, 'title': options[i], 'votes': 0},
                ];
                await _createPollMessage(question, optionMaps, expiresAt);

                questionController.dispose();
                for (final c in optionControllers) {
                  c.dispose();
                }
              },
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createPollMessage(
    String question,
    List<Map<String, dynamic>> options,
    DateTime expiresAt,
  ) async {
    final localId = const Uuid().v4();
    final now = await trustedUtcNow();

    final pollMetadata = {
      'type': 'poll',
      'localId': localId,
      'question': question,
      'options': options,
      'votes': <String, dynamic>{},
      'expiresAt': expiresAt.toIso8601String(),
      'createdAtMs': now.toUtc().millisecondsSinceEpoch,
    };

    if (_disposed || _tearingDown || _offstage) return;
    if (_channelId == null) return;
    await context.read<ChatCubit>().sendPollMessage(
      text: question,
      pollMetadata: pollMetadata,
      channelId: _channelId!,
      userId: _currentUserId,
    );
  }

  void _toggleBrainStorming() {
    context.read<ChatCubit>().toggleBrainStorming();
  }

  Future<void> _resolveUserById(String id) async {
    final normalizedUserId = id.trim();
    final cachedUser = _userCache[normalizedUserId];
    final hasCachedAvatar =
        _normalizeAvatarUrl(cachedUser?.imageSource) != null;
    if (normalizedUserId.isEmpty ||
        (cachedUser != null && hasCachedAvatar) ||
        _pendingUserResolutions.contains(normalizedUserId)) {
      return;
    }
    _pendingUserResolutions.add(normalizedUserId);
    try {
      var resolvedUser =
          await context.read<ChatCubit>().resolveUser(normalizedUserId);
      var normalizedResolvedAvatarUrl =
          _normalizeAvatarUrl(resolvedUser.imageSource);

      if (normalizedResolvedAvatarUrl == null) {
        try {
          final avatarMap = await AppServices.chatRemoteDataSource
              .remote_fetchProfileAvatarUrls([normalizedUserId]);
          final fetchedAvatarUrl = _normalizeAvatarUrl(
            avatarMap[normalizedUserId],
          );
          if (fetchedAvatarUrl != null) {
            resolvedUser = types.User(
              id: resolvedUser.id,
              name: resolvedUser.name,
              imageSource: fetchedAvatarUrl,
            );
            normalizedResolvedAvatarUrl = fetchedAvatarUrl;
          }
        } catch (_) {
          // Keep best-effort resolve result.
        }
      }

      if (normalizedResolvedAvatarUrl != null &&
          !_avatarImageProviderByUserId.containsKey(normalizedUserId)) {
        final imageProvider =
            CachedNetworkImageProvider(normalizedResolvedAvatarUrl);
        try {
          await precacheImage(imageProvider, context);
          _avatarImageProviderByUserId[normalizedUserId] = imageProvider;
        } catch (_) {
          // Keep runtime fallback path if pre-cache fails.
        }
      }
      if (mounted) {
        _userCache[normalizedUserId] = resolvedUser;
        _bumpAvatarVersionForUser(normalizedUserId);
      }
    } catch (e) {
      debugPrint('Error resolving user $id: $e');
    } finally {
      _pendingUserResolutions.remove(normalizedUserId);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Audio Processing
  // ─────────────────────────────────────────────────────────────────────────

  bool _audioMetadataIndicatesReady(types.AudioMessage m) =>
      audioMessageShowsPlayButton(m);

  /// Every 3s: (1) pull full document from Appwrite → SQLite + cubit
  /// [ChatCubit.refreshMessageFromServer], (2) if still not ready, HEAD/GET the
  /// audio URL and write `status: ready` to Appwrite (then repository syncs local).
  void _startPollingForAudioMessage(types.AudioMessage message) {
    _audioPollingTimers[message.id]?.cancel();

    Future<void> pollTick() async {
      if (_disposed || _tearingDown || !mounted || _channelId == null) {
        _audioPollingTimers[message.id]?.cancel();
        _audioPollingTimers.remove(message.id);
        return;
      }

      final cubit = context.read<ChatCubit>();
      await cubit.refreshMessageFromServer(message.id);
      if (_disposed || _tearingDown || !mounted || _channelId == null) return;

      types.AudioMessage? currentAudio;
      final st = cubit.state;
      if (st is ChatMessagesLoaded) {
        for (final m in st.messages) {
          if (m.id == message.id && m is types.AudioMessage) {
            currentAudio = m;
            break;
          }
        }
      }

      if (currentAudio != null && _audioMetadataIndicatesReady(currentAudio)) {
        _audioPollingTimers[message.id]?.cancel();
        _audioPollingTimers.remove(message.id);
        return;
      }

      final probeUrl = currentAudio?.source ?? message.source;
      final isUrlReady = await _checkAudioUrlIsReady(probeUrl);
      if (!isUrlReady) return;

      _audioPollingTimers[message.id]?.cancel();
      _audioPollingTimers.remove(message.id);

      if (_disposed || _tearingDown || !mounted || _channelId == null) return;

      final audioForWrite = currentAudio ?? message;
      final meta = {
        ...?audioForWrite.metadata,
        'status': 'ready',
        'ready_at': DateTime.now().toUtc().millisecondsSinceEpoch,
      };
      final updated = types.AudioMessage(
        id: audioForWrite.id,
        authorId: audioForWrite.authorId,
        createdAt: audioForWrite.createdAt,
        size: audioForWrite.size,
        source: audioForWrite.source,
        duration: audioForWrite.duration,
        metadata: meta,
        replyToMessageId: audioForWrite.replyToMessageId,
        deliveredAt: audioForWrite.deliveredAt,
        sentAt: audioForWrite.sentAt,
        seenAt: audioForWrite.seenAt,
      );
      try {
        await context.read<ChatCubit>().updateMessageMetadata(
              channelId: _channelId!,
              message: updated,
            );
      } catch (e, st) {
        debugPrint(
          'GeneralChat: audio ready metadata update failed: $e\n$st',
        );
      }
    }

    _audioPollingTimers[message.id] = Timer.periodic(
      const Duration(seconds: 3),
      (_) {
        unawaited(pollTick());
      },
    );
  }

  Future<bool> _checkAudioUrlIsReady(String url, [int redirectDepth = 0]) async {
    if (redirectDepth > 5) return false;
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;

    bool okCode(int code) => code == 200 || code == 206;

    try {
      final head = await http.head(uri).timeout(const Duration(seconds: 15));
      if (okCode(head.statusCode)) return true;
      if (head.statusCode >= 300 &&
          head.statusCode < 400 &&
          head.headers['location'] != null) {
        return _checkAudioUrlIsReady(
          uri.resolve(head.headers['location']!).toString(),
          redirectDepth + 1,
        );
      }
    } catch (_) {}

    try {
      final get = await http
          .get(
            uri,
            headers: const {'Range': 'bytes=0-0'},
          )
          .timeout(const Duration(seconds: 15));
      if (okCode(get.statusCode)) return true;
      if (get.statusCode >= 300 &&
          get.statusCode < 400 &&
          get.headers['location'] != null) {
        return _checkAudioUrlIsReady(
          uri.resolve(get.headers['location']!).toString(),
          redirectDepth + 1,
        );
      }
    } catch (_) {}

    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Scroll & Visibility
  // ─────────────────────────────────────────────────────────────────────────

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is! ScrollUpdateNotification &&
        notification is! UserScrollNotification) {
      return false;
    }

    _isUserScrolling = true;
    if (_stickyHeaderOpacityNotifier.value != 1.0) {
      _stickyHeaderOpacityNotifier.value = 1.0;
    }

    _scrollIdleTimer?.cancel();
    _scrollIdleTimer = Timer(const Duration(seconds: 1), () {
      _isUserScrolling = false;
      if (_stickyHeaderOpacityNotifier.value != 0.0) {
        _stickyHeaderOpacityNotifier.value = 0.0;
      }
    });

    return false; // allow other listeners to receive the notification
  }

  void _onMessageVisibilityChanged(
    String messageId,
    int index,
    double visibleFraction,
    DateTime? createdAt,
  ) {
    if (visibleFraction <= 0) {
      _visibleMessagesForHeader.remove(messageId);
    } else {
      _visibleMessagesForHeader[messageId] =
          _VisibleMessage(index, visibleFraction, createdAt);
    }

    if (_visibleMessagesForHeader.isEmpty) {
      if (_stickyHeaderDateNotifier.value != null) {
        _stickyHeaderDateNotifier.value = null;
      }
      return;
    }

    _computeStickyHeaderDate();
  }

  /// Determines which date to show in the sticky header by finding the visible
  /// message with the highest list index (the topmost fully-loaded message).
  void _computeStickyHeaderDate() {
    var highestIndex = -1;
    DateTime? bestDate;
    for (final vm in _visibleMessagesForHeader.values) {
      if (vm.index > highestIndex) {
        highestIndex = vm.index;
        bestDate = vm.createdAt;
      }
    }
    if (bestDate != _stickyHeaderDateNotifier.value) {
      _stickyHeaderDateNotifier.value = bestDate;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────────────

  static int _compareByCreatedAtAsc(types.Message a, types.Message b) {
    final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final cmp = aTime.compareTo(bTime);
    return cmp != 0 ? cmp : a.id.compareTo(b.id);
  }

  static List<types.Message> _sortedByCreatedAt(Iterable<types.Message> items) {
    return List<types.Message>.from(items)..sort(_compareByCreatedAtAsc);
  }

  /// Deduplicates [messages] by ID, keeping the last (most-recent) occurrence
  /// of each ID while preserving original order.
  static List<types.Message> _deduplicateById(List<types.Message> messages) {
    final seen = <String>{};
    return messages.reversed
        .where((m) => seen.add(m.id))
        .toList()
        .reversed
        .toList();
  }

  ChatMember _currentUserMember(Authenticated authState) {
    return authState.chatMembers.firstWhere(
      (m) => m.id.trim() == authState.user.id,
      orElse: () => ChatMember(
        id: authState.user.id,
        displayName: 'Unknown',
        building: 'Unknown',
        apartment: 'Unknown',
        userState: UserState.approved,
        phoneNumber: '',
        ownerType: OwnerTypes.owner,
      ),
    );
  }

  /// Stable digest of member rows that affect chat chrome (names/avatars/roles in rows).
  static int _chatMembersLayoutDigest(Authenticated a) {
    var h = a.chatMembers.length;
    for (final m in a.chatMembers) {
      h = Object.hash(
        h,
        m.id,
        m.displayName.trim(),
        m.avatarUrl,
        m.building.trim(),
      );
    }
    return h;
  }

  /// Avoid rebuilding the entire [Chat] / message list on every [Authenticated.timestamp]
  /// or unrelated [AuthCubit] tick — that was causing hundreds of [MessageRowWrapper]
  /// rebuilds per second in DevTools.
  static bool _shouldRebuildGeneralChatForAuth(AuthState prev, AuthState curr) {
    if (prev.runtimeType != curr.runtimeType) return true;
    if (prev is! Authenticated || curr is! Authenticated) {
      return prev != curr;
    }
    final p = prev;
    final c = curr;
    if (p.user.id != c.user.id ||
        p.selectedCompoundId != c.selectedCompoundId ||
        p.role != c.role ||
        p.enabledMultiCompound != c.enabledMultiCompound) {
      return true;
    }
    final pc = p.currentUser;
    final cc = c.currentUser;
    if ((pc?.id ?? '') != (cc?.id ?? '')) return true;
    if ((pc?.building ?? '').trim() != (cc?.building ?? '').trim()) return true;
    if ((pc?.displayName ?? '').trim() != (cc?.displayName ?? '').trim()) {
      return true;
    }
    if (_chatMembersLayoutDigest(p) != _chatMembersLayoutDigest(c)) return true;
    return false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    super.build(context); // required by AutomaticKeepAliveClientMixin

    return BlocBuilder<AuthCubit, AuthState>(
      buildWhen: _shouldRebuildGeneralChatForAuth,
      builder: (context, authState) {
        if (authState is! Authenticated) {
          _raiseTeardownGuard();
          return const SizedBox.shrink();
        }

        _tearingDown = false;

        // ── Offstage awareness ──────────────────────────────────────────────
        // IndexedStack sets TickerMode to false for offstage children. We use this
        // to (a) defer _initializeChat until the tab is first shown and (b) block
        // the sync queue while offstage so no SliverAnimatedList mutations happen
        // on a list whose render object may not be fully active.
        final tickersEnabled = TickerMode.of(context);
        final wasOffstage = _offstage;
        _offstage = !tickersEnabled;

        if (tickersEnabled && !_chatInitialized) {
          _chatInitialized = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_disposed && !_tearingDown && mounted) {
              _initializeChat();
            }
          });
        } else if (tickersEnabled && wasOffstage) {
          // Returning from offstage → force-recreate the Chat widget.
          //
          // flutter_chat_ui's _ChatAnimatedListState._processOperationsQueue has
          // no try/catch. If ANY insertItem/removeItem threw while offstage (or
          // during a race), _oldList is permanently desynced from the
          // SliverAnimatedList — every future operation crashes. A new UniqueKey
          // makes Flutter unmount the old Chat and mount a fresh one whose _oldList
          // is re-synced from _chatController.messages. This is the programmatic
          // equivalent of the "open BrainStorming, close it" manual fix.
          _chatSurfaceKey = UniqueKey();

          // Also catch up with any messages that arrived while offstage.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_disposed || _tearingDown || !mounted || _offstage) return;
            final cubitState = context.read<ChatCubit>().state;
            if (cubitState is ChatMessagesLoaded) {
              _enqueueSyncFromCubit(cubitState);
            }
          });
        }

        return BlocListener<ChatCubit, ChatState>(
          listenWhen: (prev, curr) {
            if (curr is! ChatMessagesLoaded) return false;
            if (prev is! ChatMessagesLoaded) return true;
            return !identical(prev.messages, curr.messages);
          },
          listener: (context, state) {
            // Block sync while offstage — the SliverAnimatedList's render object
            // may not be ready to process insert/remove operations.
            if (_disposed || _tearingDown || !mounted || _offstage) return;
            _enqueueSyncFromCubit(state as ChatMessagesLoaded);
          },
          child: BlocBuilder<ChatCubit, ChatState>(
            // Only rebuild when the brainstorming mode toggles; message content
            // changes are handled via the sync queue without triggering a rebuild.
            buildWhen: (prev, curr) {
              if (prev is ChatMessagesLoaded && curr is ChatMessagesLoaded) {
                return prev.isBrainStorming != curr.isBrainStorming;
              }
              return prev.runtimeType != curr.runtimeType;
            },
            builder: (context, chatState) {
              // Guard #1 (ChatCubit rebuild path): BlocBuilder<ChatCubit> has its
              // own Flutter element and can be called by the framework independently
              // of _GeneralChatState.build(). If auth is gone or we are disposed,
              // never build Chat/ChatAnimatedList.
              if (_tearingDown || _disposed) return const SizedBox.shrink();

              final isBrainStorming = chatState is ChatMessagesLoaded
                  ? chatState.isBrainStorming
                  : context.read<ChatCubit>().isBrainStorming;

              // BlocBuilder<SocialCubit> provides Guard #2: a *third* independent
              // Flutter element with its own rebuild path. SocialCubit emits during
              // sign-out (brainstorm state is cleared), which can schedule this
              // builder AFTER _raiseTeardownGuard() has already raised _tearingDown
              // but BEFORE Flutter deactivates the element. Without this guard that
              // independent rebuild would reach _buildCurrentView and attempt to
              // build SliverAnimatedList while _tearingDown is true — causing:
              //   "child == null || indexOf(child) > index" assertion
              //   Duplicate GlobalKey (stale Hero / VisibilityDetector keys)
              return BlocBuilder<SocialCubit, SocialState>(
                // Social feed / brainstorm emits must not rebuild this subtree: the
                // builder only needs a stable shell while [ChatCubit] listener syncs
                // messages. Rebuilding here recreated every [MessageRowWrapper] on
                // each [PostsLoaded] / comment tick.
                buildWhen: (previous, current) => false,
                builder: (context, _) {
                  // Guard #2 (SocialCubit independent rebuild path).
                  if (_tearingDown || _disposed) return const SizedBox.shrink();
                  return _buildCurrentView(
                    authState,
                    isBrainStorming: isBrainStorming,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  /// Routes to the correct top-level view based on user state and mode.
  Widget _buildCurrentView(
    Authenticated authState, {
    required bool isBrainStorming,
  }) {
    if (_isInitializing) {
    if (context.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: GestureDetector(
            onTap: null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: 30,
                  child: ClipOval(
                    child: getCompoundPicture(context, widget.compoundId, 28),
                  ),
                ),
                const SizedBox(width: 8),
                const Text('General Chat', style: TextStyle(fontSize: 15)),
              ],
            ),
          ),
        ),
        child: const Center(
          child: Material(
            color: Colors.transparent,
            child: CircularProgressIndicator.adaptive(),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: _ChatAppBar(
        compoundId: widget.compoundId,
        onTitleTap: null,
        onToggleBrainStorming: null,
      ),
      body: const Center(child: CircularProgressIndicator.adaptive()),
    );
    }

    final member = _currentUserMember(authState);

    return ConditionBuilder<dynamic>
        .on(
          () => member.userState == UserState.banned,
          () => const _BannedUserScreen(),
        )
        .on(
          () => member.userState == UserState.chatBanned,
          () => const _ChatBannedScreen(),
        )
        .build(orElse: () {
      if (isBrainStorming) {
        return BrainStorming(
          channelId: _channelId!,
          onClose: _toggleBrainStorming,
        );
      }
      return _buildActiveChatScaffold(authState);
    });
  }

  Widget _buildActiveChatScaffold(Authenticated authState) {
    _scheduleAvatarPrefetch(authState.chatMembers);

    if (context.isIOS) {
      return BlocBuilder<PresenceCubit, PresenceState>(
        builder: (context, _) {
          final typingText = _typingSubtitle(authState);
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  CupertinoPageRoute(
                    builder: (context) => BlocProvider(
                      create: (context) => ChatDetailsCubit(
                        authCubit: context.read<AuthCubit>(),
                        databases: appwriteTables,
                      ),
                      child: ChatDetails(compoundId: widget.compoundId),
                    ),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 30,
                      child: ClipOval(
                        child: getCompoundPicture(context, widget.compoundId, 28),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('General Chat', style: TextStyle(fontSize: 15)),
                        if (typingText != null)
                          Text(
                            typingText,
                            style: const TextStyle(fontSize: 10, color: Colors.green),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () {
                  context
                      .read<SocialCubit>()
                      .getBrainStorms(_channelId!, widget.compoundId);
                  _toggleBrainStorming();
                },
                child: const Icon(CupertinoIcons.graph_circle),
              ),
            ),
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: _buildChatBody(),
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: BlocBuilder<PresenceCubit, PresenceState>(
          builder: (context, _) {
            final typingText = _typingSubtitle(authState);
            return _ChatAppBar(
              compoundId: widget.compoundId,
              typingText: typingText,
              onTitleTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BlocProvider(
                    create: (context) => ChatDetailsCubit(
                      authCubit: context.read<AuthCubit>(),
                      databases: appwriteTables,
                    ),
                    child: ChatDetails(compoundId: widget.compoundId),
                  ),
                ),
              ),
              onToggleBrainStorming: () {
                context
                    .read<SocialCubit>()
                    .getBrainStorms(_channelId!, widget.compoundId);
                _toggleBrainStorming();
              },
            );
          },
        ),
      ),
      body: _buildChatBody(),
    );
  }

  String? _typingSubtitle(Authenticated authState) {
    final presenceState = context.read<PresenceCubit>().state;
    if (presenceState is! PresenceUpdated) return null;
    final typingUserIds = <String>{};
    for (final singleState in presenceState.currentPresence) {
      for (final presence in singleState.presences) {
        final status = presence.payload['status']?.toString();
        final userId = presence.payload['user_id']?.toString();
        if (status == 'typing' &&
            userId != null &&
            userId.isNotEmpty &&
            userId != authState.user.id) {
          typingUserIds.add(userId);
        }
      }
    }
    if (typingUserIds.isEmpty) return null;
    final typingNames = authState.chatMembers
        .where((member) => typingUserIds.contains(member.id))
        .map((member) => member.displayName)
        .toList();
    if (typingNames.isEmpty) return 'Someone is typing...';
    if (typingNames.length == 1) return '${typingNames.first} is typing...';
    return '${typingNames.length} members are typing...';
  }

  Widget _buildChatBody() {
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScrollNotification,
            child: BlocProvider(
              create: (context) => ReportCubit(
                adminRepository: AppServices.adminRepository,
              ),
              child: Chat(
                key: _chatSurfaceKey,
                chatController: _chatController,
                currentUserId: _currentUserId,
                onMessageSend: _handleSendPressed,
                onAttachmentTap: _handleAttachmentTap,
                resolveUser: (id) async {
                  await _resolveUserById(id);
                  return _userCache[id];
                },
                builders: types.Builders(
                  textMessageBuilder: (ctx, msg, idx,
                          {required isSentByMe, groupStatus}) =>
                      _buildMessageRow(ctx, msg, idx, isSentByMe: isSentByMe),
                  imageMessageBuilder: (ctx, msg, idx,
                          {required isSentByMe, groupStatus}) =>
                      _buildMessageRow(ctx, msg, idx, isSentByMe: isSentByMe),
                  audioMessageBuilder: (ctx, msg, idx,
                          {required isSentByMe, groupStatus}) =>
                      _buildMessageRow(ctx, msg, idx, isSentByMe: isSentByMe),
                  customMessageBuilder: (ctx, msg, idx,
                          {required isSentByMe, groupStatus}) =>
                      _buildMessageRow(ctx, msg, idx, isSentByMe: isSentByMe),
                  chatAnimatedListBuilder: (ctx, itemBuilder) => ChatAnimatedList(
                    itemBuilder: itemBuilder,
                    initialScrollToEndMode: InitialScrollToEndMode.jump,
                  ),
                  composerBuilder: _buildComposer,
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: _buildStickyDateHeader(),
        ),
        if (_repliedMessage != null)
          Positioned(
            bottom: 65,
            left: MediaQuery.of(context).size.width * 0.1,
            child: ReplyBar(
              repliedMessage: _repliedMessage!,
              repliedAuthorName:
                  _userCache[_repliedMessage!.authorId]?.name ?? 'User',
              onCancel: () => setState(() => _repliedMessage = null),
            ),
          ),
        ValueListenableBuilder<List<_MentionSuggestionItem>>(
          valueListenable: _mentionSuggestionsNotifier,
          builder: (context, mentionSuggestions, _) {
            if (mentionSuggestions.isEmpty) {
              return const SizedBox.shrink();
            }
            return Positioned(
              bottom: _repliedMessage != null ? 118 : 72,
              left: 10,
              right: 10,
              child: Material(
                elevation: 3,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: mentionSuggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final mentionItem = mentionSuggestions[index];
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        leading: mentionItem.avatarUrl != null
                            ? CircleAvatar(
                                radius: 16,
                                backgroundImage: CachedNetworkImageProvider(
                                  mentionItem.avatarUrl!,
                                ),
                              )
                            : CircleAvatar(
                                radius: 16,
                                child: Icon(
                                  mentionItem.isSpecial
                                      ? Icons.campaign_outlined
                                      : Icons.person_outline,
                                  size: 16,
                                ),
                              ),
                        title: Text(
                          mentionItem.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          mentionItem.mentionToken,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        onTap: () => _insertMention(mentionItem.mentionToken),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  /// Builds the composer bar. Uses [BlocBuilder] scoped tightly to recording
  /// and empty-input flags so the rest of the UI is not rebuilt on key presses.
  Widget _buildComposer(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      buildWhen: (prev, curr) {
        if (prev is ChatMessagesLoaded && curr is ChatMessagesLoaded) {
          return prev.isRecording != curr.isRecording ||
              prev.isChatInputEmpty != curr.isChatInputEmpty;
        }
        return true;
      },
      builder: (context, state) {
        final cubit = context.read<ChatCubit>();
        final isRecording =
            state is ChatMessagesLoaded ? state.isRecording : cubit.isRecording;
        final isInputEmpty = state is ChatMessagesLoaded
            ? state.isChatInputEmpty
            : cubit.isChatInputEmpty;

        return Visibility(
          visible: !isRecording,
          child: Composer(
            gap: 0,
            sendIcon: const Icon(Icons.send),
            textEditingController: _textInputController,
            handleSafeArea: true,
            sigmaX: 3,
            sigmaY: 3,
            sendButtonHidden: isInputEmpty,
          ),
        );
      },
    );
  }

  Widget _buildStickyDateHeader() {
    return ValueListenableBuilder<DateTime?>(
      valueListenable: _stickyHeaderDateNotifier,
      builder: (context, stickyHeaderDate, _) {
        if (stickyHeaderDate == null) return const SizedBox.shrink();
        return ValueListenableBuilder<double>(
          valueListenable: _stickyHeaderOpacityNotifier,
          builder: (context, stickyHeaderOpacity, __) {
            return AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: stickyHeaderOpacity,
              child: Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    formatMessageDate(stickyHeaderDate),
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMessageRow(
    BuildContext context,
    types.Message message,
    int index, {
    required bool isSentByMe,
  }) {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return const SizedBox.shrink();

    final cachedMessageAuthor = _userCache[message.authorId];
    final hasResolvedAvatar =
        _normalizeAvatarUrl(cachedMessageAuthor?.imageSource) != null;
    if (cachedMessageAuthor == null || !hasResolvedAvatar) {
      _resolveUserById(message.authorId);
    }

    return MessageRowWrapper(
      message: message,
      index: index,
      isSentByMe: isSentByMe,
      channelId: _channelId ?? '',
      reactionsController: _reactionsController,
      onReply: (m) => setState(() => _repliedMessage = m),
      onDelete: (m) => context.read<ChatCubit>().deleteMessage(m),
      onMessageVisible: (id) =>
          context.read<ChatCubit>().markAsSeen(id, _currentUserId),
      chatController: _chatController,
      isPreviousMessageFromSameUser: index > 0 &&
          _chatController.messages[index - 1].authorId == message.authorId,
      userCache: _userCache,
      avatarImageProviderByUserId: _avatarImageProviderByUserId,
      avatarVersionListenable: _avatarVersionListenableForUser(message.authorId),
      resolveUser: _resolveUserById,
      onVisibilityForHeader: _onMessageVisibilityChanged,
      localMessages: _chatController.messages,
      showDateHeaders: true,
      currentUserId: _currentUserId,
      isUserScrolling: _isUserScrolling,
      chatMembers: authState.chatMembers,
      userRole: authState.role,
      uploadProgress: _uploadProgressByMessageId[message.id],
      channelName: widget.channelName,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Private UI Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// App bar shared by both the loading and active chat scaffolds.
///
/// Passing `null` for [onTitleTap] disables navigation to ChatDetails (used
/// while the channel ID is still being resolved). Passing `null` for
/// [onToggleBrainStorming] hides the analytics toggle button entirely.
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String compoundId;
  final String? typingText;
  final VoidCallback? onTitleTap;
  final VoidCallback? onToggleBrainStorming;

  const _ChatAppBar({
    required this.compoundId,
    this.typingText,
    required this.onTitleTap,
    required this.onToggleBrainStorming,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    if (context.isIOS) {
      return CupertinoNavigationBar(
        middle: GestureDetector(
          onTap: onTitleTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox.square(
                dimension: 30,
                child: ClipOval(
                  child: getCompoundPicture(context, compoundId, 28),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('General Chat', style: TextStyle(fontSize: 15)),
                  if (typingText != null)
                    Text(
                      typingText!,
                      style: const TextStyle(fontSize: 10, color: Colors.green),
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: onToggleBrainStorming != null
            ? CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: onToggleBrainStorming,
                child: const Icon(CupertinoIcons.graph_circle),
              )
            : null,
      );
    }

    return AppBar(
      title: MaterialButton(
        onPressed: onTitleTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 10,
          children: [
            SizedBox.square(
              dimension: 40,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white70,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: getCompoundPicture(context, compoundId, 38),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('General Chat'),
                if (typingText != null)
                  Text(
                    typingText!,
                    style: const TextStyle(fontSize: 11, color: Colors.green),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        if (onToggleBrainStorming != null)
          IconButton(
            onPressed: onToggleBrainStorming,
            icon: const Icon(Icons.analytics_outlined),
          ),
      ],
    );
  }
}

/// Full-screen error page shown when the user's account has been banned.
class _BannedUserScreen extends StatelessWidget {
  const _BannedUserScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.no_accounts, color: Colors.redAccent, size: 100),
            const SizedBox(height: 60),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: const Text(
                'Your account has been banned for breaking Community Rules.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen error page shown when the user's chat access has been suspended.
class _ChatBannedScreen extends StatelessWidget {
  const _ChatBannedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Symbols.chat_error, color: Colors.redAccent, size: 100),
            const SizedBox(height: 60),
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.8,
              child: const Text(
                'Your chat access has been suspended for breaking Community Rules.',
                style: TextStyle(fontSize: 16, color: Colors.black54),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
