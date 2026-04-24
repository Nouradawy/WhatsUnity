abstract class MessageReceiptsState {
  const MessageReceiptsState();
}

class MessageReceiptsInitial extends MessageReceiptsState {
  const MessageReceiptsInitial();
}

class MessageReceiptsLoading extends MessageReceiptsState {
  const MessageReceiptsLoading();
}

class MessageReceiptsLoaded extends MessageReceiptsState {
  final List<dynamic> seenUsers; // Using dynamic for now to avoid circular dependency if needed, but will use SeenUser
  MessageReceiptsLoaded(this.seenUsers);
}

class MessageReceiptsError extends MessageReceiptsState {
  final String message;
  const MessageReceiptsError(this.message);
}
