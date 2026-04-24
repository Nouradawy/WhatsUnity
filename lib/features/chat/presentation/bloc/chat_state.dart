import 'package:equatable/equatable.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

abstract class ChatState extends Equatable {
  const ChatState();

  @override
  List<Object?> get props => [];
}

class ChatInitial extends ChatState {}

class ChatRecordingState extends ChatState {
  final bool isRecording;
  const ChatRecordingState(this.isRecording);
  @override
  List<Object?> get props => [isRecording];
}

class ChatInputState extends ChatState {
  final bool isEmpty;
  const ChatInputState(this.isEmpty);
  @override
  List<Object?> get props => [isEmpty];
}

class ChatBrainStormingState extends ChatState {
  final bool isBrainStorming;
  const ChatBrainStormingState(this.isBrainStorming);
  @override
  List<Object?> get props => [isBrainStorming];
}

class ChatLoading extends ChatState {}

class ChatMessagesLoaded extends ChatState {
  final List<types.Message> messages;
  final bool hasMore;
  final String? channelId;
  final bool isBrainStorming;
  final bool isRecording;
  final bool isChatInputEmpty;

  /// Monotonically increasing version so BLoC never deduplicates two
  /// successive message-list emissions via Equatable deep-equality.
  /// Without this, an `_addOrUpdateMessage` that replaces a message with
  /// an identical-content copy (same metadata Map but different identity)
  /// can be silently swallowed by BLoC, leaving the UI stale.
  final int _version;

  /// Auto-incremented by [copyWith] and the unnamed constructor so that
  /// every instance is unique in Equatable terms.
  static int _nextVersion = 0;

  ChatMessagesLoaded({
    required this.messages,
    this.hasMore = true,
    this.channelId,
    this.isBrainStorming = false,
    this.isRecording = false,
    this.isChatInputEmpty = true,
  }) : _version = _nextVersion++;

  ChatMessagesLoaded._withVersion({
    required this.messages,
    required this.hasMore,
    required this.channelId,
    required this.isBrainStorming,
    required this.isRecording,
    required this.isChatInputEmpty,
    required int version,
  }) : _version = version;

  @override
  List<Object?> get props => [_version, hasMore, channelId, isBrainStorming, isRecording, isChatInputEmpty];

  ChatMessagesLoaded copyWith({
    List<types.Message>? messages,
    bool? hasMore,
    String? channelId,
    bool? isBrainStorming,
    bool? isRecording,
    bool? isChatInputEmpty,
  }) {
    return ChatMessagesLoaded._withVersion(
      messages: messages ?? this.messages,
      hasMore: hasMore ?? this.hasMore,
      channelId: channelId ?? this.channelId,
      isBrainStorming: isBrainStorming ?? this.isBrainStorming,
      isRecording: isRecording ?? this.isRecording,
      isChatInputEmpty: isChatInputEmpty ?? this.isChatInputEmpty,
      version: _nextVersion++,
    );
  }
}

class ChatError extends ChatState {
  final String message;

  const ChatError(this.message);

  @override
  List<Object?> get props => [message];
}
