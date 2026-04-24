import '../repositories/chat_repository.dart';

class SendVoiceNote {
  final ChatRepository repository;

  SendVoiceNote(this.repository);

  Future<void> call({
    required String uri,
    required Duration duration,
    required List<double> waveform,
    required String channelId,
    required String userId,
  }) {
    return repository.sendVoiceNote(
      uri: uri,
      duration: duration,
      waveform: waveform,
      channelId: channelId,
      userId: userId,
    );
  }
}
