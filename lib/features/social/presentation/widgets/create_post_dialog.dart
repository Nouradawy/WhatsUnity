import 'dart:io';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';

import 'package:WhatsUnity/core/constants/Constants.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:WhatsUnity/features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import 'package:WhatsUnity/features/social/presentation/bloc/social_cubit.dart';

import 'social_member_utils.dart';

class CreatePostDialog extends StatefulWidget {
  final TextEditingController postHead;
  final ChatMember? currentMember;
  final String selectedCompoundId;

  const CreatePostDialog({
    super.key,
    required this.postHead,
    this.currentMember,
    required this.selectedCompoundId,
  });

  @override
  State<CreatePostDialog> createState() => _CreatePostDialogState();
}

class _CreatePostDialogState extends State<CreatePostDialog>
    with WidgetsBindingObserver {
  List<XFile>? file;
  bool getCalls = false;
  bool postingInProgress = false;

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
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;

    return AlertDialog(
      insetPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      backgroundColor: Colors.white,
      content: SizedBox(
        width: screenWidth * 0.98,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(child: Text(context.loc.postCreate)),
              const Divider(thickness: 0.5),
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade200,
                    backgroundImage:
                        socialAvatarProvider(widget.currentMember?.avatarUrl),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    widget.currentMember?.displayName ?? 'Guest',
                    style: context.txt.socialUserName,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              PostTextForm(
                context,
                controller: widget.postHead,
                keyboardType: TextInputType.text,
                hintText: context.loc.statusButton,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Stack(
                  alignment: AlignmentDirectional.topEnd,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: file?.length ?? 0,
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(file![index].path),
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                    file != null
                        ? IconButton(
                            onPressed: () => setState(() => file = null),
                            icon: const Icon(Icons.close),
                          )
                        : DottedBorder(
                            options: const RoundedRectDottedBorderOptions(
                              radius: Radius.circular(8),
                              strokeWidth: 2,
                              color: Colors.grey,
                              dashPattern: [5],
                            ),
                            child: Container(
                              alignment: AlignmentDirectional.center,
                              height: MediaQuery.sizeOf(context).height * 0.2,
                              width: MediaQuery.sizeOf(context).width * 0.8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    context.loc.emptyPhotos,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    context.loc.uploadPhotosPosts,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  MaterialButton(
                                    onPressed: () async {
                                      final result = await ImagePicker()
                                          .pickMultiImage(
                                              imageQuality: 70, maxWidth: 1440);
                                      if (result.isEmpty) return;
                                      setState(() => file = result);
                                    },
                                    color: HexColor('f0f2f5'),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Text(
                                      context.loc.upload,
                                      style: GoogleFonts.plusJakartaSans(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              ),
              if (getCalls)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [Text('Name'), Text('Position')],
                    ),
                    MaterialButton(
                      padding: const EdgeInsets.only(right: 21, left: 15),
                      onPressed: () {},
                      elevation: 0,
                      color: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.phone),
                          SizedBox(width: 5),
                          Text(
                            'Call now',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: MediaQuery.sizeOf(context).width * 0.50,
                      child: Text(
                        'Add to your post',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.black,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => setState(() => getCalls = true),
                      icon: const Icon(Icons.phone),
                      splashRadius: 10,
                    ),
                  ],
                ),
              ),
              MaterialButton(
                onPressed: postingInProgress
                    ? null
                    : () async {
                        setState(() => postingInProgress = true);
                        await context.read<SocialCubit>().createPost(
                              postHead: widget.postHead.text,
                              getCalls: getCalls,
                              compoundId: widget.selectedCompoundId,
                              authorId: widget.currentMember!.id,
                              files: file,
                            );
                        if (!mounted) return;
                        setState(() => postingInProgress = false);
                        Navigator.pop(context);
                      },
                color: Colors.blue,
                disabledColor: Colors.blue.withAlpha(200),
                elevation: 0,
                minWidth: double.infinity,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Post',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (postingInProgress)
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
