import 'dart:io';

import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as types;
import 'package:permission_handler/permission_handler.dart';
import 'package:social_media_recorder/audio_encoder_type.dart';
import 'package:social_media_recorder/screen/social_media_recorder.dart';
import 'package:uuid/uuid.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';

import 'package:WhatsUnity/core/media/media_services.dart';
import 'package:WhatsUnity/core/media/recorder_upload_bridge.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_state.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/AudioWaveformPainter.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/GeneralChat/general_chat.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chat_scope.dart';

/// Shell for the bottom-nav **Chats** tab only (`channelName: BUILDING_CHAT`).
///
/// Uses [ChatScope] so building chat has its own [ChatCubit] (and realtime
/// subscription) separate from compound general chat on Home.
class BuildingChat extends StatefulWidget {
  const BuildingChat({super.key});

  @override
  State<BuildingChat> createState() => _BuildingChatState();
}

class _BuildingChatState extends State<BuildingChat> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && kIsWeb) {
      // Re-fetch building chat messages on PWA resume to catch up on missed events.
      // The ChatCubit is provided by ChatScope below.
      try {
        // We use a post-frame callback to ensure the BlocProvider is accessible if needed,
        // although in most cases it should be fine directly if the widget is mounted.
        if (mounted) {
          // Note: BuildingChat is a shell that wraps ChatScope which provides ChatCubit.
          // Since we need to access ChatCubit from the context OF the child of ChatScope,
          // we might need to be careful. However, ChatScope is in the build method below.
          // Let's use a GlobalKey or a better way to trigger refresh if ChatScope is a child.
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = context.watch<AuthCubit>().state;
    if (authState is! Authenticated) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }
    final currentCompoundId = authState.selectedCompoundId;
    final userId = authState.user.id;

    if (currentCompoundId == null) {
      return Center(child: Text(context.loc.noCommunitySelected));
    }

    // The ValueKey forces Flutter to fully destroy and recreate GeneralChat
    // (and its SocialCubit) whenever the user or compound changes, preventing
    // stale widget state from carrying over between sessions or communities.
    final chatKey = ValueKey('${userId}_${currentCompoundId}_building_chat');

    return ChatScope(
      compoundId: currentCompoundId,
      channelScopeId: 'BUILDING_CHAT',
      userId: userId,
      child: Builder(
        builder: (childContext) {
          // This Builder ensures we can access the ChatCubit provided by ChatScope.
          return _BuildingChatLifecycleManager(
            child: _buildBody(childContext, userId, chatKey),
          );
        }
      ),
    );
  }

  Widget _buildBody(BuildContext context, String userId, Key chatKey) {
    return Stack(
      children: [
        GeneralChat(
          key: chatKey,
          compoundId: (context.read<AuthCubit>().state as Authenticated).selectedCompoundId!,
          channelName: 'BUILDING_CHAT',
        ),
        BlocBuilder<ChatCubit, ChatState>(
          builder: (context, state) {
            final chatCubit = context.read<ChatCubit>();

            final bool isChatInputEmpty = (state is ChatMessagesLoaded)
                ? state.isChatInputEmpty
                : chatCubit.isChatInputEmpty;
            final bool isBrainStorming = (state is ChatMessagesLoaded)
                ? state.isBrainStorming
                : chatCubit.isBrainStorming;
            final String? channelId = (state is ChatMessagesLoaded)
                ? state.channelId
                : chatCubit.channelId;
            final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

            if (isChatInputEmpty && !isBrainStorming && channelId != null) {
              return Positioned(
                bottom: keyboardBottom,
                right: 0,
                child: SafeArea(
                  child: SocialMediaRecorder(
                    onButtonPress: () async {
                      final micStatus = await Permission.microphone.request();
                      if (!micStatus.isGranted) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.loc.microphonePermissionRequired),
                            ),
                          );
                        }
                        return;
                      }
                      chatCubit.recordedAmplitudes.clear();
                      chatCubit.toggleRecording();
                    },
                    onButtonRelease: () {
                      if (chatCubit.isRecording) {
                        chatCubit.toggleRecording();
                      }
                    },
                    sendRequestFunction: (soundFile, duration) async {
                      final parts = duration.split(':');
                      final minutes = int.tryParse(parts[0]) ?? 0;
                      final seconds = int.tryParse(parts[1]) ?? 0;
                      final parsedDuration =
                          Duration(minutes: minutes, seconds: seconds);

                      final amplitudesToUpload =
                          chatCubit.recordedAmplitudes;

                      final fileName =
                          'voice_note_${const Uuid().v4()}.m4a';
                      File? staged;
                      try {
                        final uploadPath = kIsWeb
                            ? soundFile.path
                            : (staged = stageRecorderFileForUpload(soundFile)).path;
                        final meta =
                            await mediaUploadService.uploadFromLocalPath(
                          localFilePath: uploadPath,
                          filenameOverride: fileName,
                        );
                        final playbackUrl = meta['playback_url'] as String? ??
                            meta['url'] as String?;
                        if (playbackUrl != null && context.mounted) {
                          context.read<ChatCubit>().sendVoiceNote(
                                uri: playbackUrl,
                                duration: parsedDuration,
                                waveform: amplitudesToUpload,
                                channelId: channelId,
                                userId: userId,
                              );
                        }
                      } catch (e, st) {
                        debugPrint('Voice upload failed: $e\n$st');
                      } finally {
                        if (!kIsWeb) {
                          try {
                            staged?.deleteSync();
                          } catch (_) {}
                        }
                      }
                    },
                    fullRecordPackageHeight: 80,
                    backGroundColor: types.ChatColors
                        .light()
                        .surfaceContainerHigh
                        .withAlpha(100),
                    initialButtonWidth: 40,
                    initialButtonHight: 40,
                    finalButtonWidth: 60,
                    finalButtonHight: 60,
                    encode: AudioEncoderType.AAC,
                    waveformBuilder: (amplitudes) {
                      chatCubit.recordedAmplitudes = amplitudes;
                      return CustomPaint(
                        painter: AudioWaveformPainter(
                          amplitudes: amplitudes,
                          waveColor: Colors.black,
                        ),
                      );
                    },
                  ),
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }
}

/// Internal helper to manage lifecycle within the [ChatScope] context.
class _BuildingChatLifecycleManager extends StatefulWidget {
  final Widget child;
  const _BuildingChatLifecycleManager({required this.child});

  @override
  State<_BuildingChatLifecycleManager> createState() => _BuildingChatLifecycleManagerState();
}

class _BuildingChatLifecycleManagerState extends State<_BuildingChatLifecycleManager> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && kIsWeb) {
      if (mounted) {
        context.read<ChatCubit>().refreshMessages();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = widget.child;
    return context.isIOS
        ? CupertinoPageScaffold(
            child: SafeArea(
              child: Material(
                color: Colors.transparent,
                child: body,
              ),
            ),
          )
        : Scaffold(body: body);
  }
}
