import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import '../repositories/chat_repository.dart';


class ResolveUser {
  final ChatRepository repository;

  ResolveUser(this.repository);

  Future<types.User> call(String id) {
    return repository.resolveUser(id);
  }
}
