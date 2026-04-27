import '../../../../core/theme/lightTheme.dart';
import '../../../../features/maintenance/presentation/bloc/maintenance_cubit.dart';
import '../../../../features/maintenance/presentation/bloc/maintenance_state.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../features/maintenance/presentation/bloc/manager_cubit.dart';
import '../../../../features/maintenance/presentation/bloc/manager_state.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/constants/Constants.dart';
import '../../../../core/models/MaintenanceReport.dart';
import '../../../../core/utils/url_launcher_helper.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../auth/presentation/pages/welcome_page.dart';
import '../../../chat/data/models/chat_member_model.dart';
import '../../../chat/presentation/widgets/chatWidget/MessageWidget.dart';
import '../../../security/presentation/pages/security_center_page.dart';

class ManagerHomepage extends StatelessWidget {
  const ManagerHomepage({super.key});


  @override
  Widget build(BuildContext context) {
    final managerCubit = ManagerCubit.get(context);
    final maintenanceCubit = context.read<MaintenanceCubit>();
    final List<Map<String,dynamic>> services= [{
      "icon": "assets/Svg/maintenance.svg",
      "Name": context.loc.maintenance,
      "icon color":Colors.indigo.shade600,
      "icon bg":Colors.indigo.shade100,
      "Background" :Colors.indigo.shade50,
      "text Color":Colors.indigo.shade900
    },
      {
        "icon": "assets/Svg/security.svg",
        "Name": context.loc.security,
        "icon color":Colors.purple.shade600,
        "icon bg":Colors.purple.shade100,
        "Background" :Colors.purple.shade50,
        "text Color":Colors.purple.shade900
      },

      {
        "icon": "assets/Svg/cleaning.svg",
        "Name": context.loc.cleaning,
        "icon color":Colors.teal.shade600,
        "icon bg":Colors.teal.shade100,
        "Background" :Colors.teal.shade50,
        "text Color":Colors.teal.shade900
      },
      {
        "icon": "assets/Svg/announcement.svg",
        "Name": context.loc.announcements,
        "icon color":Colors.teal.shade600,
        "icon bg":Colors.teal.shade100,
        "Background" :Colors.teal.shade50,
        "text Color":Colors.teal.shade900
      }
    ];
    TextEditingController notes = TextEditingController();
    return BlocConsumer<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is CompoundSelected || state is CompoundMembersUpdated) {
          managerCubit.resetToInitial();
        }
      },
      builder: (context, authState) {
        return BlocConsumer<ManagerCubit, ManagerCubitStates>(
          listener: (context, state) async {
            if (state is ManagerInitialState && authState is Authenticated) {
              managerCubit.currentMaintenanceType = MaintenanceReportType.maintenance;
              await maintenanceCubit.getMaintenanceReports(
                compoundId: authState.selectedCompoundId!.toString(),
                type: MaintenanceReportType.maintenance,
              );
              managerCubit.filterIndex = 0;
              managerCubit.filterRequests(
                reports: maintenanceCubit.reports,
                type: MaintenanceReportType.maintenance,
                statusFilter: ManagerReportsFilter.all,
              );
            }
          },
          builder: (context, state) {
            final currentSelectedCompoundId = (authState is Authenticated) ? authState.selectedCompoundId : null;
            final currentMyCompounds = (authState is Authenticated) ? authState.myCompounds : context.read<AuthCubit>().myCompounds;
            final enabledMultiCompound = (authState is Authenticated) ? authState.enabledMultiCompound : false;

            return Scaffold(
              backgroundColor:Colors.white,
              appBar: AppBar(
                backgroundColor:Colors.white,
                leadingWidth: 120,
                 title:enabledMultiCompound?DropdownMenu(
                  initialSelection: currentSelectedCompoundId?.toString(),
                  width: MediaQuery.sizeOf(context).width * 0.55,
                  inputDecorationTheme: InputDecorationTheme(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: HexColor("#111518"),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    constraints: const BoxConstraints(maxHeight: 50),
                  ),
                  menuStyle:  MenuStyle(
                    backgroundColor:WidgetStateProperty.all(Colors.white),
                    fixedSize: WidgetStateProperty.all<Size>(
                      Size(MediaQuery.sizeOf(context).width * 0.55, double.infinity),
                    ),
                    elevation: WidgetStateProperty.all(0.5),
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5), // adjust radius
                        // optional border
                      ),
                    ),
                  ),

                  dropdownMenuEntries:
                  currentMyCompounds.entries.toList().reversed.map(
                        (entry) {
                      String key = entry.key;
                      String value =  entry.value;
                      return DropdownMenuEntry<String>(
                        leadingIcon: key == '0' ?Icon(Icons.add):null,
                        value: key,
                        label: value.toString(),
                      );
                    },
                  ).toList(),
                  onSelected:(selectedKey) async {
                    if(selectedKey == '0'){
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const JoinCommunity()),
                      );
                    } else {
                      final compoundId = selectedKey.toString();
                      final compoundName = currentMyCompounds[selectedKey]!;
                      final auth = context.read<AuthCubit>();
                      await auth.loadCompoundMembers(compoundId);
                      await auth.selectCompound(
                        compoundId: compoundId,
                        compoundName: compoundName,
                        atWelcome: false,
                      );
                     }
                   },
                 ):Text(
                   // Safely handle the case where MyCompounds might be empty
                   currentMyCompounds.isNotEmpty
                       ? currentMyCompounds.values.last.toString()
                       : 'Select Community',
                   style: GoogleFonts.plusJakartaSans(
                     color: HexColor("#111518"),
                     fontSize: 17,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
                leading: Container(
                    alignment: AlignmentDirectional.center,
                    padding: const EdgeInsets.only(left: 7),
                    child: Text(
                      "WhatsUnity",
                      textScaler: TextScaler.noScaling,
                      style: GoogleFonts.lobster(fontSize: 20 ,fontWeight: FontWeight.w500 , color: Colors.indigo.shade500 ,),
                    )),
                actions:const [
                //    IconButton(onPressed: (){
                //   Navigator.push(
                //     context,
                //     MaterialPageRoute(builder: (context) => Profile()),
                //   );
                // }, icon: Icon(Icons.notifications)),

                ],

              ),
              body: Column(
                children: [
                  Container(
                    margin:EdgeInsets.only(left:MediaQuery.of(context).size.width*0.075),
                    height: MediaQuery.sizeOf(context).width*0.28,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      clipBehavior: Clip.none,
                      itemCount:services.length,
                      itemBuilder: (context,index){
                        final service = services[index];
                        return Container(
                          width: MediaQuery.sizeOf(context).width*0.25,
                          margin: const EdgeInsets.only(right:10),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12), // <-- Rounded corners
                            color: service["Background"],
                          ),
                          child:MaterialButton(
                            padding: EdgeInsets.zero,
                            shape:RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12), // <-- Rounded corners
                            ),
                            onPressed: () async {
                              if(index == 3){
                                managerCubit.loadAnnouncement();
                              }else if(index == 1){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const SecurityCenterPage(),
                                  ),
                                );
                              }else{
                                managerCubit.currentMaintenanceType = MaintenanceReportType.values[index];
                                final compoundId = currentSelectedCompoundId;
                                await maintenanceCubit.getMaintenanceReports(
                                  compoundId: compoundId!.toString(),
                                  type: managerCubit.currentMaintenanceType,
                                );
                                managerCubit.filterIndex = 0;
                                managerCubit.filterRequests(
                                  reports: maintenanceCubit.reports,
                                  type: managerCubit.currentMaintenanceType,
                                  statusFilter: ManagerReportsFilter.all,
                                );
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
                                    decoration: BoxDecoration(
                                        shape:BoxShape.circle,
                                        color: service["icon bg"]
                                    ),
                                    child: SvgPicture.asset(

                                        colorFilter:ColorFilter.mode(
                                          service["icon color"],
                                          BlendMode.srcIn,
                                        )
                                        ,
                                        service['icon']),
                                  ),
                                  const SizedBox(height: 5),
                                  SizedBox(
                                      width: 100,
                                      child: Text(service['Name'] ,textAlign: TextAlign.center, style: GoogleFonts.plusJakartaSans(fontSize:13,fontWeight: FontWeight.bold , color: service["text Color"]
                                      ),)),

                                ]
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  if(managerCubit.isAnnouncment ==false)
                  Expanded(
                    child: Column(
                      children: [
                        Wrap(
                          spacing: 8,
                          children: List.generate(ManagerReportsFilter.values.length, (i){
                            return FilterChip(
                                label: Text(ManagerReportsFilter.values[i].name),
                                selected: managerCubit.filterIndex == i,
                                onSelected: (selected) {
                                  managerCubit.filterIndex = i;
                                  managerCubit.filterRequests(
                                    reports: maintenanceCubit.reports,
                                    type: managerCubit.currentMaintenanceType,
                                    statusFilter: ManagerReportsFilter.values[i],
                                  );
                                });
                          }),
                        ),
                        Expanded(
                          child: BlocBuilder<MaintenanceCubit, MaintenanceState>(
                            builder: (context, state) {
                              final reports = managerCubit.maintenanceDataFiltered;
                              final attachments = maintenanceCubit.attachments;
                              if (state is MaintenanceLoading && reports.isEmpty) {
                                return const Center(child: CircularProgressIndicator());
                              }
                              if (state is MaintenanceError && reports.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(state.message, textAlign: TextAlign.center),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed: () async {
                                          if (currentSelectedCompoundId == null) return;
                                          await maintenanceCubit.getMaintenanceReports(
                                            compoundId: currentSelectedCompoundId.toString(),
                                            type: managerCubit.currentMaintenanceType,
                                          );
                                        },
                                        child: Text(context.loc.retry),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              if (reports.isEmpty) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(context.loc.noRequestsFoundForFilter),
                                      const SizedBox(height: 8),
                                      FilledButton(
                                        onPressed: () async {
                                          if (currentSelectedCompoundId == null) return;
                                          await maintenanceCubit.getMaintenanceReports(
                                            compoundId: currentSelectedCompoundId.toString(),
                                            type: managerCubit.currentMaintenanceType,
                                          );
                                        },
                                        child: Text(context.loc.refresh),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              return ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: reports.length,
                                  itemBuilder: (context,index) {
                                    final reportId = reports[index].id;
                                    final attachment = attachments.firstWhere((attach)=>attach.reportId == reportId  ,
                                        orElse:() =>
                                            MaintenanceReportsAttachments
                                              (reportId: reportId,
                                                sourceUrl: null,
                                                createdAt: null
                                            )
                                    );
                                    final bool isOpen = maintenanceCubit.isExpanded &&
                                        maintenanceCubit.reportIndex == index;
                                    final chatMembers = (authState is Authenticated) ? authState.chatMembers : <ChatMember>[];
                                    final member = chatMembers.firstWhere((m)=>m.id.trim() == reports[index].userId.trim(), orElse: () => ChatMember(id: '', displayName: 'Unknown', building: '', apartment: '', phoneNumber: '', userState: UserState.banned, ownerType: null));

                                    return Container(
                                      margin: const EdgeInsets.symmetric(vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: AnimatedCrossFade(
                                            crossFadeState: (maintenanceCubit.isExpanded &&
                                                maintenanceCubit.reportIndex == index)
                                                ? CrossFadeState.showSecond
                                                : CrossFadeState.showFirst,
                                            duration: const Duration(milliseconds: 500),
                                            firstCurve: Curves.easeInOut,
                                            secondCurve: Curves.easeInOut,
                                            sizeCurve: Curves.easeInOut,
                                            firstChild: MaintenanceReportHeaderTile(
                                              index: index,
                                              isOpen: isOpen,
                                              attachmentUrl: attachment,
                                            ),
                                            secondChild: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                MaintenanceReportHeaderTile(
                                                  index: index,
                                                  isOpen: isOpen,
                                                  attachmentUrl: attachment,
                                                  isSecond: true,
                                                  member: member,
                                                ),
                                                const SizedBox(height: 8),

                                                Divider(height: 1,color: Colors.grey.shade200,),
                                                const SizedBox(height: 8),

                                                // This row now belongs to the whole tile
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    SizedBox(
                                                      width:MediaQuery.sizeOf(context).width*0.70,
                                                      child: defaultTextForm(
                                                        context,
                                                        controller: notes,
                                                        keyboardType: TextInputType.text,
                                                        labelText: "Note",
                                                        hintText: "add a note for this issue",
                                                      ),
                                                    ),
                                                    MaterialButton(
                                                      padding: EdgeInsets.zero,
                                                      onPressed: () {
                                                        if (authState is Authenticated && authState.currentUser != null) {
                                                          if (reportId != null) {
                                                            maintenanceCubit.postReportNote(
                                                              reportId: reportId,
                                                              actorId: authState.currentUser!.id,
                                                              action: notes.text,
                                                            );
                                                          }
                                                        }
                                                        notes.clear();
                                                      },
                                                      child: Text(context.loc.submit),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),

                                                ConstrainedBox(
                                                  constraints: BoxConstraints(
                                                    maxHeight: MediaQuery.sizeOf(context).height*0.3
                                                  ),
                                                  child: ListView.builder(
                                                      physics: const BouncingScrollPhysics(),
                                                      itemCount: maintenanceCubit.reportNotes.length,
                                                      shrinkWrap:true,
                                                      itemBuilder: (context,noteIndex){
                                                        final note = maintenanceCubit.reportNotes[noteIndex];
                                                        return Column(
                                                          children: [
                                                            if(noteIndex ==0)SizedBox(
                                                              width:MediaQuery.sizeOf(context).width*0.87,
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children:[
                                                                  Text(context.loc.notes),
                                                                  SizedBox(
                                                                    width: 120,
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Text(context.loc.date),
                                                                        Text(context.loc.madeBy),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                            Padding(
                                                              padding: EdgeInsets.symmetric(horizontal: MediaQuery.sizeOf(context).width*0.065),
                                                              child: Row(
                                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                children: [
                                                                  SizedBox(
                                                                    width:MediaQuery.sizeOf(context).width*0.47,
                                                                    child: Text(note.action ,
                                                                        style: GoogleFonts.plusJakartaSans(
                                                                          fontSize: 12,
                                                                          fontWeight: FontWeight.w600,
                                                                          letterSpacing: 0.2,
                                                                          color: Colors.grey,
                                                                        )),
                                                                  ),
                                                                  SizedBox(
                                                                    width: MediaQuery.sizeOf(context).width*0.34,
                                                                    child: Row(
                                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                                      children: [
                                                                        Text('${formatTimeStampToDate(note.createdAt)}-${formatTimestampToAmPm(note.createdAt)}' ,
                                                                            style: GoogleFonts.plusJakartaSans(
                                                                              fontSize: 12,
                                                                              fontWeight: FontWeight.w600,
                                                                              letterSpacing: 0.2,
                                                                              color: Colors.grey,
                                                                            )),
                                                                        Text(context.loc.madeBy ,
                                                                            style: GoogleFonts.plusJakartaSans(
                                                                              fontSize: 12,
                                                                              fontWeight: FontWeight.w600,
                                                                              letterSpacing: 0.2,
                                                                              color: Colors.grey,
                                                                            )),
                                                                      ],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ],
                                                        );
                                                      }
                                                  ),
                                                ),
                                                const SizedBox(height: 20),

                                              ],
                                            ),
                                          ),

                                    );
                                  });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  if(managerCubit.isAnnouncment)
                    Column(
                      children: [
                        const SizedBox(height: 60,),
                        SvgPicture.asset("assets/Svg/announcement.svg",height: 130,),
                        Text(context.loc.announcements),
                        const SizedBox(height: 8),
                        Text(context.loc.noAnnouncementsYet),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(SnackBar(
                                behavior: SnackBarBehavior.floating,
                                content: Text(context.loc.announcementPublishingSoon),
                              ));
                          },
                          child: Text(context.loc.createAnnouncement),
                        ),
                      ],
                    )
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class MaintenanceReportHeaderTile extends StatelessWidget {
  final int index;
  final bool isOpen;
  final MaintenanceReportsAttachments? attachmentUrl;
  final bool isSecond;
  final ChatMember? member;

  const MaintenanceReportHeaderTile({
    super.key,
    required this.index,
    required this.isOpen,
    required this.attachmentUrl,
    this.isSecond = false,
    this.member,
  });

  @override
  Widget build(BuildContext context) {
    final managerCubit = ManagerCubit.get(context);
    final maintenanceCubit = context.read<MaintenanceCubit>();
    final report = managerCubit.maintenanceDataFiltered[index];

    return ListTile(
      onTap: () {
        if (!isSecond) {
          maintenanceCubit.getReportNotes(report.id!);
        }
        maintenanceCubit.expandReport(index);
      },
      leading: const CircleAvatar(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        child: Icon(Icons.hourglass_top),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              report.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: HexColor("#121416"),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: '',
            onSelected: (selectedValue) async {
              if (report.id != null) {
                final authState = context.read<AuthCubit>().state;
                final currentSelectedCompoundId = (authState is Authenticated) ? authState.selectedCompoundId : null;
                await maintenanceCubit.updateReportStatus(
                  reportId: report.id!,
                  status: selectedValue,
                  compoundId: currentSelectedCompoundId!.toString(),
                  type: managerCubit.currentMaintenanceType,
                );
                managerCubit.filterRequests(
                  reports: maintenanceCubit.reports,
                  type: managerCubit.currentMaintenanceType,
                  statusFilter: ManagerReportsFilter.values[managerCubit.filterIndex],
                );
              }
            },
            itemBuilder: (ctx) => ManagerReportsFilter.values
                .map((f) => PopupMenuItem<String>(value: f.value, child: Text(f.value)))
                .toList(),
            child: Chip(
              label: Text(
                report.states,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: Colors.white,
                ),
              ),
              backgroundColor: HexColor("#76b7f5"),
              visualDensity: const VisualDensity(vertical: -4),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "${context.loc.report} #${report.reportCode} - ${formatTimeStampToDate(report.createdAt!)}-${formatTimestampToAmPm(report.createdAt!)}",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
              color: Colors.grey,
            ),
          ),
          if (isSecond) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 10,
                      backgroundImage: member?.avatarUrl != null
                          ? CachedNetworkImageProvider(member!.avatarUrl!)
                          : null,
                      child: member?.avatarUrl == null ? const Icon(Icons.person) : null,
                    ),
                    const SizedBox(width: 5),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(member?.displayName ?? 'Unknown', style: context.txt.userNameCard),
                        Text(
                          'Building ${member?.building ?? ""} • Apartment ${member?.apartment ?? ""}',
                          style: context.txt.userNameCard.copyWith(fontWeight: FontWeight.w300, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  spacing: 7,
                  children: [
                    SizedBox(
                      width: 60,
                      child: MaterialButton(
                        onPressed: member?.phoneNumber != null ? () => launchUrl(Uri.parse("tel:<${member!.phoneNumber}>")) : null,
                        elevation: 0,
                        color: Colors.greenAccent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone, size: 17, color: Colors.white),
                            Text(
                              "CALL",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      child: MaterialButton(
                        onPressed: member?.phoneNumber != null ? () => openWhatsApp(member!.phoneNumber, "Hello", defaultCountryCode: "20") : null,
                        elevation: 0,
                        color: Colors.greenAccent,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(FontAwesomeIcons.whatsapp, size: 17, color: Colors.white),
                            Text(
                              "WhatsApp",
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: Colors.black87),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              report.description,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.2, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            if (attachmentUrl?.sourceUrl != null)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: attachmentUrl!.sourceUrl!
                    .map(
                      (item) {
                        final uri = (item['uri'] ?? '').toString();
                        final resolved = extractDriveFileId(uri) ??
                            (uri.startsWith('http') ? uri : null);
                        if (resolved == null) {
                          return const SizedBox(width: 80, height: 80);
                        }
                        return SizedBox(
                        width: 80,
                        height: 80,
                        child: DriveImageMessage(
                          userName:
                              "${context.loc.report} #${report.reportCode} - ${formatTimeStampToDate(report.createdAt!)}-${formatTimestampToAmPm(report.createdAt!)}",
                          isMaintenance: true,
                          fileId: resolved,
                        ),
                      );
                      },
                    )
                    .toList(),
              ),
          ],
        ],
      ),
      trailing: AnimatedSwitcher(
        duration: const Duration(milliseconds: 500),
        transitionBuilder: (child, animation) => RotationTransition(turns: animation, child: child),
        child: Icon(
          isOpen ? Icons.keyboard_arrow_down_outlined : Icons.arrow_forward_ios_rounded,
          key: ValueKey<String>('arrow_${isOpen}_$index'),
          color: Colors.grey,
          size: 13,
        ),
      ),
    );
  }
}
