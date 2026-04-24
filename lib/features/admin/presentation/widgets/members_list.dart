import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/config/supabase.dart';
import '../../../../core/constants/Constants.dart';
import '../../../../core/utils/url_launcher_helper.dart';
import '../../../../core/theme/lightTheme.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import '../bloc/admin_cubit.dart';
import '../bloc/admin_state.dart';
import '../../domain/entities/admin_user.dart';

class MembersList extends StatelessWidget {
  final List<AdminUser> members;
  const MembersList({super.key, required this.members});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthCubit, AuthState>(
      builder: (context, authState) {
        final chatMembers = (authState is Authenticated) ? authState.chatMembers : <ChatMember>[];
        return ListView.builder(
          shrinkWrap: true,
          itemCount: members.length,
          itemBuilder: (context, index) {
            final memberData = members[index];
            final member = chatMembers.firstWhere(
              (m) => m.id.trim() == memberData.authorId.trim(),
              orElse: () => ChatMember(
                id: memberData.authorId,
                displayName: 'Unknown',
                building: '?',
                apartment: '?',
                phoneNumber: memberData.phoneNumber,
                ownerType: OwnerTypes.owner,
                userState: UserState.New,
              ),
            );

            return Card(
              elevation: 0.5,
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 15),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundImage: member.avatarUrl != null
                                  ? NetworkImage(member.avatarUrl!)
                                  : null,
                              child: member.avatarUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            const SizedBox(width: 15),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  spacing: 5,
                                  children: [
                                    Text(member.displayName,
                                        style: context.txt.userNameCard),
                                    const Text('•'),
                                    Text(memberData.ownerShipType)
                                  ],
                                ),
                                Text(
                                  'Building ${member.building} • Apartment ${member.apartment}',
                                  style: context.txt.userNameCard.copyWith(
                                      fontWeight: FontWeight.w300, fontSize: 11),
                                )
                              ],
                            ),
                          ],
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(memberData.userState),
                          labelStyle: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                          ),
                          backgroundColor: Colors.red.shade100,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.0),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(member.fullName ?? member.displayName,
                        style: context.txt.cardBody),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 8,
                      children: [
                        Text(memberData.phoneNumber, style: context.txt.cardBody),
                        _ActionButton(
                          onPressed: () => launchUrl(
                              Uri.parse("tel:<${memberData.phoneNumber}>")),
                          icon: Icons.phone,
                          label: "call",
                        ),
                        _ActionButton(
                          onPressed: () => openWhatsApp(
                              memberData.phoneNumber, "Hello",
                              defaultCountryCode: "20"),
                          icon: FontAwesomeIcons.whatsapp,
                          label: "Message",
                          isFontAwesome: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _DocumentsSection(memberData: memberData, member: member),
                    const SizedBox(height: 12),
                    const Divider(thickness: 0.7),
                    _StatusActions(memberData: memberData),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final bool isFontAwesome;

  const _ActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    this.isFontAwesome = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 25,
      child: MaterialButton(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        elevation: 0,
        color: Colors.white70,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Colors.grey, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            isFontAwesome
                ? FaIcon(icon, size: 15)
                : Icon(icon, size: 15),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _DocumentsSection extends StatelessWidget {
  final AdminUser memberData;
  final ChatMember member;

  const _DocumentsSection({required this.memberData, required this.member});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AdminCubit, AdminState>(
      buildWhen: (previous, current) => current is VerFilesDropToggled,
      builder: (context, state) {
        final cubit = context.read<AdminCubit>();
        return AnimatedCrossFade(
          firstChild: InkWell(
            onTap: cubit.toggleVerFiles,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white70, borderRadius: BorderRadius.circular(10)),
              child: const Row(
                children: [
                  Icon(Icons.keyboard_arrow_right_sharp),
                  Text("Submitted Documents")
                ],
              ),
            ),
          ),
          secondChild: InkWell(
            onTap: cubit.toggleVerFiles,
            child: Container(
              decoration: BoxDecoration(
                  color: Colors.white70, borderRadius: BorderRadius.circular(10)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.keyboard_arrow_down_sharp),
                      Text("Submitted Documents")
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: memberData.verFiles.map<Widget>((item) {
                      final url = item['path'] ?? '';
                      if (url.isEmpty) return const SizedBox.shrink();
                      return InkWell(
                        onTap: () => fullScreenImageViewer(
                            context: context,
                            imageData: item,
                            userName: member.displayName,
                            isVerf: true),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(url,
                              width: 80, height: 80, fit: BoxFit.cover),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          crossFadeState: cubit.showVerFiles
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 500),
        );
      },
    );
  }
}

class _StatusActions extends StatelessWidget {
  final AdminUser memberData;

  const _StatusActions({required this.memberData});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<AdminCubit>();
    final authCubit = context.read<AuthCubit>();
    final compoundId = (authCubit.state as Authenticated).selectedCompoundId;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 5,
      children: [
        _StatusButton(
          onPressed: () => cubit.updateUserStatus(
              memberData.authorId, UserState.approved, compoundId!),
          color: Colors.green,
          icon: Icons.check_circle,
          label: "Approve",
        ),
        _StatusButton(
          onPressed: () => cubit.updateUserStatus(
              memberData.authorId, UserState.unApproved, compoundId!),
          color: Colors.pink,
          icon: Icons.dangerous_sharp,
          label: "Decline",
        ),
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Color color;
  final IconData icon;
  final String label;

  const _StatusButton({
    required this.onPressed,
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 110,
      height: 25,
      child: MaterialButton(
        onPressed: onPressed,
        elevation: 0,
        color: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(7)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 5,
          children: [
            Icon(icon, size: 15, color: Colors.white70),
            Text(label,
                style: context.txt.cardBody.copyWith(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
