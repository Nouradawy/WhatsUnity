// lib/chat/widgets/reply_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;

class ReplyBar extends StatelessWidget {
  final types.Message repliedMessage;
  final VoidCallback onCancel;

  const ReplyBar({
    super.key,
    required this.repliedMessage,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    String messageText;
    if (repliedMessage is types.TextMessage) {
      messageText = (repliedMessage as types.TextMessage).text;
    } else if (repliedMessage is types.ImageMessage) {
      messageText = 'Image';
    } else if (repliedMessage is types.FileMessage) {
      messageText = 'File: ${(repliedMessage as types.FileMessage).name}';
    } else {
      messageText = 'Message';
    }

    return Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: Theme.of(context).primaryColorLight.withAlpha(150),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            )),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Replying to User...", // You can pass the user name here
                    style: TextStyle(fontWeight: FontWeight.bold)),
                IconButton(
                  iconSize: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  onPressed: onCancel,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  border: Border(
                      left: BorderSide(
                          color: Colors.greenAccent, width: 3))),
              child: Text(messageText, overflow: TextOverflow.ellipsis),
            ),
          ],
        ));
  }
}