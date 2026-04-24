import 'dart:io';

import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:social_media_recorder/audio_encoder_type.dart';
import 'package:social_media_recorder/screen/social_media_recorder.dart';
import 'package:WhatsUnity/Layout/Cubit/cubit.dart';
import 'package:WhatsUnity/Layout/Cubit/states.dart';
import 'package:uuid/uuid.dart';

import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/config/supabase.dart';
import 'package:WhatsUnity/core/media/media_services.dart';
import 'package:WhatsUnity/core/media/recorder_upload_bridge.dart';
import 'package:WhatsUnity/features/social/presentation/pages/Social.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/auth/presentation/pages/welcome_page.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_cubit.dart';
import 'package:WhatsUnity/features/chat/presentation/bloc/chat_state.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chat_scope.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/AudioWaveformPainter.dart';
import 'package:WhatsUnity/features/maintenance/presentation/bloc/maintenance_cubit.dart';
import 'package:WhatsUnity/features/maintenance/presentation/pages/maintenance_page.dart';
import 'announcement_screen.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> services = [
      {
        "icon": "assets/Svg/maintenance.svg",
        "Name": context.loc.maintenance,
        "icon color": Colors.indigo.shade600,
        "icon bg": Colors.indigo.shade100,
        "Background": Colors.indigo.shade50,
        "text Color": Colors.indigo.shade900,
      },
      {
        "icon": "assets/Svg/security.svg",
        "Name": context.loc.security,
        "icon color": Colors.purple.shade600,
        "icon bg": Colors.purple.shade100,
        "Background": Colors.purple.shade50,
        "text Color": Colors.purple.shade900,
      },

      {
        "icon": "assets/Svg/cleaning.svg",
        "Name": context.loc.cleaning,
        "icon color": Colors.teal.shade600,
        "icon bg": Colors.teal.shade100,
        "Background": Colors.teal.shade50,
        "text Color": Colors.teal.shade900,
      },
      {
        "icon": "assets/Svg/announcement.svg",
        "Name": context.loc.announcements,
        "icon color": Colors.teal.shade600,
        "icon bg": Colors.teal.shade100,
        "Background": Colors.teal.shade50,
        "text Color": Colors.teal.shade900,
      },
    ];
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final authCubit = context.read<AuthCubit>();
        final currentSelectedCompoundId = (authState is Authenticated) ? authState.selectedCompoundId : authCubit.selectedCompoundId;
        final currentMyCompounds = (authState is Authenticated) ? authState.myCompounds : authCubit.myCompounds;
        final isEnabledMultiCompound = (authState is Authenticated) ? authState.enabledMultiCompound : authCubit.enabledMultiCompound;

        final homeScaffold = Scaffold(
          backgroundColor: Colors.white,
          resizeToAvoidBottomInset: false,
          appBar: AppBar(
            backgroundColor: Colors.white,
            leadingWidth: 120,
            title:
                isEnabledMultiCompound
                    ? DropdownMenu(
                      initialSelection: currentSelectedCompoundId?.toString(),
                      width: MediaQuery.sizeOf(context).width * 0.55,
                      inputDecorationTheme: InputDecorationTheme(
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        labelStyle: GoogleFonts.plusJakartaSans(color: HexColor("#111518"), fontSize: 13, fontWeight: FontWeight.w500),
                        constraints: const BoxConstraints(maxHeight: 50),
                      ),
                      menuStyle: MenuStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.white),
                        fixedSize: WidgetStateProperty.all<Size>(Size(MediaQuery.sizeOf(context).width * 0.55, double.infinity)),
                        elevation: WidgetStateProperty.all(0.5),
                        shape: WidgetStateProperty.all(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(5), // adjust radius
                            // optional border
                          ),
                        ),
                      ),

                      dropdownMenuEntries:
                          (currentMyCompounds.entries.toList().reversed).map((entry) {
                            String key = entry.key;
                            String value = entry.value;
                            return DropdownMenuEntry<String>(leadingIcon: key == '0' ? Icon(Icons.add) : null, value: key, label: value.toString());
                          }).toList(),
                      onSelected: (selectedKey) async {
                        if (selectedKey == '0') {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => JoinCommunity()));
                        } else {
                          final newCompoundId = selectedKey.toString();
                          authCubit.loadCompoundMembers(newCompoundId);
                          await authCubit.selectCompound(
                            compoundId: newCompoundId,
                            compoundName: currentMyCompounds[selectedKey]!,
                            atWelcome: false,
                          );
                        }
                      },
                    )
                    : Text(
                      // Safely handle the case where currentMyCompounds might be empty
                      currentMyCompounds.isNotEmpty ? currentMyCompounds.values.last.toString() : 'Select Community',
                      style: GoogleFonts.plusJakartaSans(color: HexColor("#111518"), fontSize: 17, fontWeight: FontWeight.w500),
                    ),
            leading: Container(
              alignment: AlignmentDirectional.center,
              padding: EdgeInsets.only(left: 7),
              child: Text("WhatsUnity", textScaler: TextScaler.noScaling, style: GoogleFonts.lobster(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.indigo.shade500)),
            ),
            actions: [
              //   IconButton(onPressed: (){
              //   Navigator.push(
              //     context,
              //     MaterialPageRoute(builder: (context) => Profile()),
              //   );
              // }, icon: Icon(Icons.notifications)),
            ],
          ),

          body: Stack(
            alignment: AlignmentDirectional.bottomEnd,
            children: [
              NestedScrollView(
                headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
                  return [
                    SliverAppBar(
                      backgroundColor: Colors.white,
                      expandedHeight: MediaQuery.of(context).size.width * 0.40,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Column(
                          children: [
                            //Searchbar
                            const SizedBox(height: 30),

                            //<-----------------ListView for Services---------------->
                            Container(
                              margin: EdgeInsets.only(left: MediaQuery.of(context).size.width * 0.075),
                              height: MediaQuery.sizeOf(context).width * 0.28,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                clipBehavior: Clip.none,
                                itemCount: services.length,
                                itemBuilder: (context, index) {
                                  final service = services[index];
                                  return Container(
                                    width: MediaQuery.sizeOf(context).width * 0.25,
                                    margin: const EdgeInsets.only(right: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12), // <-- Rounded corners
                                      color: service["Background"],
                                    ),
                                    child: MaterialButton(
                                      padding: EdgeInsets.zero,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12), // <-- Rounded corners
                                      ),
                                      onPressed: () {
                                        if (index == 3) {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => AnnouncementScreen()));
                                        } else if (currentSelectedCompoundId != null) {
                                          context.read<MaintenanceCubit>().getMaintenanceReports(
                                            compoundId: currentSelectedCompoundId.toString(),
                                            type: MaintenanceReportType.values[index],
                                          );
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => Maintenance(maintenanceType: MaintenanceReportType.values[index])));
                                        }
                                      },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        crossAxisAlignment: CrossAxisAlignment.center,

                                        children: [
                                          const SizedBox(height: 15),
                                          Container(
                                            padding: const EdgeInsets.all(12),
                                            width: 50,
                                            height: 50,
                                            decoration: BoxDecoration(shape: BoxShape.circle, color: service["icon bg"]),
                                            child: SvgPicture.asset(colorFilter: ColorFilter.mode(service["icon color"], BlendMode.srcIn), service['icon']),
                                          ),
                                          const SizedBox(height: 5),
                                          SizedBox(
                                            width: 100,
                                            child: Text(
                                              service['Name'],
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.bold, color: service["text Color"]),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ];
                },
                body: DefaultTabController(
                  // 1. Provide the controller here
                  length: 2,
                  child: TabChangeHandler(
                    // 2. Use the listener widget we just created
                    child: Builder(
                      builder: (context) {
                        if (currentSelectedCompoundId == null) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        // 3. Pass the key to Social, which is now a clean StatelessWidget
                        return Social(key: ValueKey(currentSelectedCompoundId));
                      },
                    ),
                  ),
                ),
              ),
              if (authState is Authenticated)
              BlocBuilder<AppCubit ,AppCubitStates>(
                  builder: (context , appState){
                if (AppCubit.get(context).tabBarIndex == 1 || AppCubit.get(context).bottomNavIndex == 1) {
                 return BlocBuilder<ChatCubit, ChatState>(
                    // [ChatMessagesLoaded] emits on every message change (_version);
                    // the mic overlay only needs input-empty, brainstorm, and channel.
                    buildWhen: (previous, current) {
                      if (previous is ChatMessagesLoaded &&
                          current is ChatMessagesLoaded) {
                        return previous.isChatInputEmpty !=
                                current.isChatInputEmpty ||
                            previous.isBrainStorming !=
                                current.isBrainStorming ||
                            previous.channelId != current.channelId;
                      }
                      return previous.runtimeType != current.runtimeType;
                    },
                    builder: (context, state) {
                      final chatCubit = context.read<ChatCubit>();

                      final bool isChatInputEmpty = (state is ChatMessagesLoaded) ? state.isChatInputEmpty : chatCubit.isChatInputEmpty;
                      final bool isBrainStormingLocal = (state is ChatMessagesLoaded) ? state.isBrainStorming : chatCubit.isBrainStorming;
                      final String? channelIdLocal = (state is ChatMessagesLoaded) ? state.channelId : chatCubit.channelId;
                      final keyboardBottom = MediaQuery.viewInsetsOf(context).bottom;

                      if ((isChatInputEmpty && channelIdLocal != null && !isBrainStormingLocal) ) {
                        return Positioned(
                          bottom: keyboardBottom,
                          right: 0,
                          child: SafeArea(
                            child: SocialMediaRecorder(
                              onButtonPress: () {
                                chatCubit.recordedAmplitudes.clear();
                                chatCubit.toggleRecording();
                              },
                              onButtonRelease: () {
                                if (chatCubit.isRecording) {
                                  chatCubit.toggleRecording();
                                }
                              },
                              // This is called when the user finishes recording
                              sendRequestFunction: (soundFile, duration) async {
                                debugPrint("attempting to save");
                                final parts = duration.split(':');
                                final minutes = int.tryParse(parts[0]) ?? 0;
                                final seconds = int.tryParse(parts[1]) ?? 0;
                                final parsedDuration = Duration(minutes: minutes, seconds: seconds);

                                final amplitudesToUpload = chatCubit.recordedAmplitudes;
                                // Assuming uploadVoiceNote logic is similar to BuildingChat
                                // We'll need to move uploadVoiceNote to ChatCubit or a Service
                                final fileName = 'voice_note_${const Uuid().v4()}.m4a';
                                File? staged;
                                try {
                                  staged = stageRecorderFileForUpload(soundFile);
                                  final meta = await mediaUploadService.uploadFromLocalPath(
                                    localFilePath: staged.path,
                                    filenameOverride: fileName,
                                  );
                                  final playbackUrl =
                                      meta['playback_url'] as String? ?? meta['url'] as String?;
                                  if (playbackUrl != null) {
                                    chatCubit.sendVoiceNote(
                                      uri: playbackUrl,
                                      duration: parsedDuration,
                                      waveform: amplitudesToUpload,
                                      channelId: channelIdLocal,
                                      userId: authState.user.id,
                                    );
                                  }
                                } catch (e, st) {
                                  debugPrint('Voice upload failed: $e\n$st');
                                } finally {
                                  try {
                                    staged?.deleteSync();
                                  } catch (_) {}
                                }
                              },

                              fullRecordPackageHeight: 80,

                              // Customize the appearance to match your app
                              backGroundColor: ChatColors
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
                                return CustomPaint(painter: AudioWaveformPainter(amplitudes: amplitudes, waveColor: Colors.black));
                              },

                              // You can add more customizations here
                              // lockButton: const Icon(Icons.lock, color: Colors.white),
                              // slideToCancelText: "Slide to Cancel",
                              // etc.
                            ),
                          ),
                        );
                      } else {
                        return const SizedBox.shrink();
                      }
                    },
                  );
                } else {
                  // This ensures that when the tab is NOT 1, the mic is physically removed
                  return const SizedBox.shrink();
                }
              },
            )
            else
              const SizedBox.shrink(),
            ],
          ),
        );
        if (currentSelectedCompoundId != null) {
          final uid = authState is Authenticated
              ? authState.user.id
              : (supabase.auth.currentUser?.id ?? '');
          if (uid.isEmpty) {
            return homeScaffold;
          }
          return ChatScope(
            compoundId: currentSelectedCompoundId,
            channelScopeId: 'COMPOUND_GENERAL',
            userId: uid,
            child: homeScaffold,
          );
        }
        return homeScaffold;
      },
    );
  }
}

class TabChangeHandler extends StatefulWidget {
  final Widget child;
  const TabChangeHandler({super.key, required this.child});

  @override
  State<TabChangeHandler> createState() => _TabChangeHandlerState();
}

class _TabChangeHandlerState extends State<TabChangeHandler> {
  TabController? _tabController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Get the controller provided by the parent
    _tabController = DefaultTabController.of(context);
    // Remove any previous listener before adding a new one
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.addListener(_handleTabSelection);
  }

  @override
  void dispose() {
    // Clean up the listener when the widget is destroyed
    _tabController?.removeListener(_handleTabSelection);
    super.dispose();
  }

  void _handleTabSelection() {
    if (_tabController != null && _tabController!.index == 1 && !_tabController!.indexIsChanging) {

      // 2. Get the scroll controller that manages the NestedScrollView
      final scrollController = PrimaryScrollController.of(context);

      if (scrollController.hasClients) {
        // 3. Animate the SCROLL position, not the tab index.
        // 200 is an estimate of your SliverAppBar height.
        // This "pushes" the header up to make the chat area "big".
        final double headerHeight = MediaQuery.of(context).size.width * 0.40;

        scrollController.animateTo(
          headerHeight,
          duration: const Duration(milliseconds: 400),
          curve: Curves.fastOutSlowIn,
        );
      }
    }
    print("_handleTabSelection called : ${_tabController!.index}");
    if (_tabController != null) {
      // To prevent duplicate calls, only emit if the index has actually changed
      if (AppCubit.get(context).tabBarIndex != _tabController!.index) {
        AppCubit.get(context).tabBarIndexSwitcher(_tabController!.index);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // This widget doesn't render anything itself, it just passes through its child.
    return widget.child;
  }
}
