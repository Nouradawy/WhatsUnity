import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:WhatsUnity/features/chat/data/datasources/chat_realtime_handle.dart';
import '../../domain/usecases/fetch_messages.dart';
import '../../domain/usecases/send_text_message.dart';
import '../../domain/usecases/send_file_message.dart';
import '../../domain/usecases/send_voice_note.dart';
import '../../domain/usecases/mark_message_seen.dart';
import '../../domain/usecases/delete_message.dart';
import '../../domain/usecases/resolve_user.dart';
import '../../domain/usecases/subscribe_to_channel.dart';
import '../../domain/usecases/update_message_metadata.dart';
import '../../domain/usecases/fetch_message_by_id.dart';
import '../../domain/repositories/chat_sync_repository.dart';
import 'chat_state.dart';

class ChatCubit extends Cubit<ChatState> {
  final FetchMessages fetchMessagesUsecase;
  final SendTextMessage sendTextMessageUsecase;
  final SendFileMessage sendFileMessageUsecase;
  final SendVoiceNote sendVoiceNoteUsecase;
  final MarkMessageSeen markMessageSeenUsecase;
  final DeleteMessage deleteMessageUsecase;
  final ResolveUser resolveUserUsecase;
  final SubscribeToChannel subscribeToChannelUsecase;
  final UpdateMessageMetadata updateMessageMetadataUsecase;
  final FetchMessageById fetchMessageByIdUsecase;
  final ChatSyncRepository? chatSyncRepository;
  final String currentUserId;

  ChatCubit({
    required this.currentUserId,
    required this.fetchMessagesUsecase,
    required this.sendTextMessageUsecase,
    required this.sendFileMessageUsecase,
    required this.sendVoiceNoteUsecase,
    required this.markMessageSeenUsecase,
    required this.deleteMessageUsecase,
    required this.resolveUserUsecase,
    required this.subscribeToChannelUsecase,
    required this.updateMessageMetadataUsecase,
    required this.fetchMessageByIdUsecase,
    this.chatSyncRepository,
  }) : super(ChatInitial());

  bool isRecording = false;
  List<double> recordedAmplitudes = [];
  bool isChatInputEmpty = true;
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasMore = true;
  ChatRealtimeHandle? _realtimeChannel;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final Connectivity _connectivity = Connectivity();

  String? channelId;
  bool isBrainStorming = false;

  static bool _connectivityLooksOnline(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return results.any(
      (e) => e != ConnectivityResult.none && e != ConnectivityResult.bluetooth,
    );
  }

  List<types.Message> _messages = [];

  /// `flutter_chat_ui` / [InMemoryChatController] expect chronological order:
  /// index 0 = oldest, last index = newest (non-reversed [ChatAnimatedList]).
  static int _compareCreatedAtAsc(types.Message a, types.Message b) {
    final at = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bt = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final c = at.compareTo(bt);
    if (c != 0) return c;
    return a.id.compareTo(b.id);
  }

  static List<types.Message> _sortedCopyAsc(List<types.Message> list) {
    final next = List<types.Message>.from(list);
    next.sort(_compareCreatedAtAsc);
    return next;
  }

  void _emitChatMessagesLoadedIfReady() {
    if (state is! ChatMessagesLoaded) return;
    final s = state as ChatMessagesLoaded;
    emit(
      s.copyWith(
        messages: List<types.Message>.from(_messages),
        hasMore: _hasMore,
        isChatInputEmpty: isChatInputEmpty,
        isRecording: isRecording,
        isBrainStorming: isBrainStorming,
      ),
    );
  }

  void showHideMic(bool isEmpty) {
    isChatInputEmpty = isEmpty;
    if (state is ChatMessagesLoaded) {
      emit((state as ChatMessagesLoaded).copyWith(isChatInputEmpty: isEmpty));
    } else {
      emit(ChatInputState(isEmpty));
    }
  }

  void toggleRecording() {
    isRecording = !isRecording;
    if (state is ChatMessagesLoaded) {
      emit((state as ChatMessagesLoaded).copyWith(isRecording: isRecording));
    } else {
      emit(ChatRecordingState(isRecording));
    }
  }

  void toggleBrainStorming() {
    isBrainStorming = !isBrainStorming;
    if (state is ChatMessagesLoaded) {
      final currentState = state as ChatMessagesLoaded;
      emit(currentState.copyWith(isBrainStorming: isBrainStorming));
    } else {
      emit(ChatBrainStormingState(isBrainStorming));
    }
  }

  Future<void> initChat({required String channelId, required String currentUserId}) async {
    this.channelId = channelId;
    _currentPage = 0;
    _messages = [];
    _hasMore = true;
    emit(ChatLoading());
    try {
      final pageRequested = _currentPage;
      final messages = await fetchMessagesUsecase(
        channelId: channelId,
        currentUserId: currentUserId,
        pageSize: _pageSize,
        pageNum: pageRequested,
        onRemoteSynced: (synced, pageNum) => _applyRemoteSyncedPage(synced, pageNum),
      );
      _messages = _sortedCopyAsc(messages);
      _currentPage++;
      _hasMore = messages.length >= _pageSize;

      _connectivitySub?.cancel();
      _connectivitySub = _connectivity.onConnectivityChanged.listen((_) {
        final id = this.channelId;
        if (id != null) {
          unawaited(_synchronizeRealtimeSubscription(id));
        }
      });
      await _synchronizeRealtimeSubscription(channelId);

      emit(
        ChatMessagesLoaded(
          messages: List<types.Message>.from(_messages),
          hasMore: _hasMore,
          channelId: channelId,
          isBrainStorming: isBrainStorming,
          isChatInputEmpty: isChatInputEmpty,
          isRecording: isRecording,
        ),
      );
    } catch (e) {
      emit(ChatError(e.toString()));
    }
  }

  Future<void> loadMoreMessages({required String channelId, required String currentUserId}) async {
    if (!_hasMore || state is ChatLoading) return;
    
    try {
      final pageRequested = _currentPage;
      final messages = await fetchMessagesUsecase(
        channelId: channelId,
        currentUserId: currentUserId,
        pageSize: _pageSize,
        pageNum: pageRequested,
        onRemoteSynced: (synced, pageNum) => _applyRemoteSyncedPage(synced, pageNum),
      );
      
      if (messages.isEmpty) {
        _hasMore = false;
        _emitChatMessagesLoadedIfReady();
      } else {
        // Older pages must be *prepended* so the list stays oldest → newest
        // (matches `InMemoryChatController` + non-reversed list).
        _messages = _sortedCopyAsc([
          ...List<types.Message>.from(messages),
          ..._messages,
        ]);
        _currentPage++;
      }

      _emitChatMessagesLoadedIfReady();
    } catch (e) {
      // Keep existing messages but notify error? 
    }
  }

  /// Tears down Appwrite realtime while offline to avoid endless reconnect logs;
  /// re-subscribes when connectivity returns.
  Future<void> _synchronizeRealtimeSubscription(String channelId) async {
    _realtimeChannel?.unsubscribe();
    _realtimeChannel = null;
    try {
      final results = await _connectivity.checkConnectivity();
      if (!_connectivityLooksOnline(results)) {
        return;
      }
    } catch (e, st) {
      debugPrint('ChatCubit: connectivity check failed, skip realtime: $e\n$st');
      return;
    }
    try {
      _realtimeChannel = subscribeToChannelUsecase(
        channelId: channelId,
        onInsert: (message) {
          _addOrUpdateMessage(message);
        },
        onUpdate: (message) {
          _addOrUpdateMessage(message);
        },
        onDelete: (message) {
          _removeMessage(message.id);
        },
      );
    } catch (e, st) {
      debugPrint('ChatCubit: realtime subscribe failed: $e\n$st');
    }
  }

  void _addOrUpdateMessage(types.Message message) {
    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index != -1) {
      if (_messages[index] == message) {
        return;
      }
      final next = List<types.Message>.from(_messages);
      next[index] = message;
      _messages = _sortedCopyAsc(next);
    } else {
      _messages = _sortedCopyAsc([..._messages, message]);
    }
    _emitChatMessagesLoadedIfReady();
  }

  void _applyRemoteSyncedPage(List<types.Message> synced, int pageNum) {
    if (isClosed) return;
    if (synced.isEmpty) return;

    if (pageNum == 0) {
      _messages = _sortedCopyAsc(synced);
    } else {
      final ids = _messages.map((m) => m.id).toSet();
      final olderIncoming = <types.Message>[];
      for (final m in synced) {
        if (!ids.contains(m.id)) {
          olderIncoming.add(m);
          ids.add(m.id);
        }
      }
      _messages = _sortedCopyAsc([...olderIncoming, ..._messages]);
    }

    _emitChatMessagesLoadedIfReady();
  }

  void _removeMessage(String messageId) {
    _messages = _messages.where((m) => m.id != messageId).toList();
    _emitChatMessagesLoadedIfReady();
  }

  Future<void> sendMessage({
    required String text,
    required String channelId,
    required String userId,
    types.Message? repliedMessage,
  }) async {
    final sync = chatSyncRepository;
    if (sync != null) {
      final m = await sync.sendTextMessageOfflineFirst(
        text: text,
        channelId: channelId,
        userId: userId,
        repliedMessageId: repliedMessage?.id,
      );
      _addOrUpdateMessage(m);
      return;
    }
    await sendTextMessageUsecase(
      text: text,
      channelId: channelId,
      userId: userId,
      repliedMessage: repliedMessage,
    );
  }

  /// Creates a poll row locally and enqueues remote create (same pipeline as text).
  Future<void> sendPollMessage({
    required String text,
    required Map<String, dynamic> pollMetadata,
    required String channelId,
    required String userId,
  }) async {
    final sync = chatSyncRepository;
    if (sync == null) return;
    final m = await sync.sendPollMessageOfflineFirst(
      text: text,
      pollMetadata: pollMetadata,
      channelId: channelId,
      userId: userId,
    );
    _addOrUpdateMessage(m);
  }

  Future<void> sendFileMessage({
    required String uri,
    required String name,
    required int size,
    required String channelId,
    required String userId,
    required String type,
    Map<String, dynamic>? additionalMetadata,
  }) async {
    await sendFileMessageUsecase(
      uri: uri,
      name: name,
      size: size,
      channelId: channelId,
      userId: userId,
      type: type,
      additionalMetadata: additionalMetadata,
    );
  }

  Future<void> sendVoiceNote({
    required String uri,
    required Duration duration,
    required List<double> waveform,
    required String channelId,
    required String userId,
  }) async {
    await sendVoiceNoteUsecase(
      uri: uri,
      duration: duration,
      waveform: waveform,
      channelId: channelId,
      userId: userId,
    );
  }

  Future<void> markAsSeen(String messageId, String userId) async {
    await markMessageSeenUsecase(messageId, userId);
  }

  Future<void> deleteMessage(types.Message message) async {
    await deleteMessageUsecase(message, currentUserId);
  }

  Future<void> updateMessageMetadata({
    required String channelId,
    required types.Message message,
  }) async {
    await updateMessageMetadataUsecase(
      channelId: channelId,
      message: message,
    );
    // Local merge so UI updates even if Appwrite realtime is delayed.
    _addOrUpdateMessage(message);
  }

  /// Re-fetches one document from Appwrite and merges into [_messages].
  Future<void> refreshMessageFromServer(String messageId) async {
    final m = await fetchMessageByIdUsecase(messageId);
    if (m != null) {
      _addOrUpdateMessage(m);
    }
  }

  Future<types.User> resolveUser(String id) async {
    return await resolveUserUsecase(id);
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    _connectivitySub = null;
    _realtimeChannel?.unsubscribe();
    return super.close();
  }
}
