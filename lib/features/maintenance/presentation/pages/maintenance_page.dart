import 'dart:io';

import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hexcolor/hexcolor.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/config/Enums.dart';
import '../../../../core/constants/Constants.dart';
import '../../../../core/models/MaintenanceReport.dart';
import '../../../auth/presentation/bloc/auth_cubit.dart';
import '../../../auth/presentation/bloc/auth_state.dart';
import '../../../chat/presentation/widgets/chatWidget/MessageWidget.dart';
import '../bloc/maintenance_cubit.dart';
import '../bloc/maintenance_state.dart';

class Maintenance extends StatelessWidget {
  final TextEditingController issueDescription = TextEditingController();
  final TextEditingController issueTitle = TextEditingController();
  final TextEditingController issueCategory = TextEditingController();
  final MaintenanceReportType maintenanceType;
  final bool embedded;
  final String? headerTitle;

  Maintenance({
    super.key,
    required this.maintenanceType,
    this.embedded = false,
    this.headerTitle,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MaintenanceCubit, MaintenanceState>(
      builder: (context, state) {
        final cubit = context.read<MaintenanceCubit>();
        final reports = cubit.reports;
        final attachments = cubit.attachments;

        final pageHeaderTitle = headerTitle ?? context.loc.maintenance;
        final addButton = FilledButton(
          onPressed: () => newReport(
            context.loc.maintenanceReport,
            context,
            issueDescription,
            issueTitle,
            issueCategory,
            maintenanceType,
          ),
          style: ButtonStyle(
            visualDensity: const VisualDensity(vertical: -4),
            padding: WidgetStateProperty.all<EdgeInsetsGeometry>(
              const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            ),
            backgroundColor:
                WidgetStateProperty.all<Color>(HexColor("#76b7f5")),
            fixedSize: WidgetStateProperty.all<Size>(const Size(30, 30)),
            shape: WidgetStateProperty.all<RoundedRectangleBorder>(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          child: Row(children: [const Icon(Icons.add), Text(context.loc.add)]),
        );

        final embeddedHeader = Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  pageHeaderTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              // IconButton(
              //   onPressed: () {
              //     final authState = context.read<AuthCubit>().state;
              //     if (authState is Authenticated && authState.selectedCompoundId != null) {
              //       cubit.getMaintenanceReports(
              //         compoundId: authState.selectedCompoundId!.toString(),
              //         type: maintenanceType,
              //       );
              //     }
              //   },
              //   icon: const Icon(Icons.sync),
              // )
              addButton,
            ],
          ),
        );

        final reportBody = SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Text(context.loc.reportHistory),
              ListView.builder(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                itemCount: reports.length,
                itemBuilder: (context, index) {
                  final report = reports[index];
                  final attachment = attachments.firstWhere(
                    (attach) => attach.reportId == report.id,
                    orElse: () => MaintenanceReportsAttachments(
                      reportId: report.id,
                      sourceUrl: null,
                      createdAt: null,
                    ),
                  );

                  return ListTile(
                      onTap: () {
                        cubit.expandReport(index);
                      },
                      title: Row(
                        spacing: 10,
                        children: [
                          Text(
                            report.title,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.2,
                                color: HexColor("#121416")),
                          ),
                          Chip(
                            label: Text(report.states,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: Colors.white)),
                            backgroundColor: HexColor("#76b7f5"),
                            visualDensity: const VisualDensity(vertical: -4),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 0.0, vertical: 0),
                          )
                        ],
                      ),
                      subtitle: AnimatedCrossFade(
                        firstChild: Text(
                            "${context.loc.report} #${report.reportCode} - ${formatTimeStampToDate(report.createdAt!)}-${formatTimestampToAmPm(report.createdAt!)}",
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.2,
                                color: Colors.grey)),
                        crossFadeState: (cubit.isExpanded && cubit.reportIndex == index)
                            ? CrossFadeState.showSecond
                            : CrossFadeState.showFirst,
                        duration: const Duration(milliseconds: 500),
                        firstCurve: Curves.easeInOut,
                        secondCurve: Curves.easeInOut,
                        sizeCurve: Curves.easeInOut,
                        secondChild: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                "${context.loc.report} #${report.reportCode} - ${formatTimeStampToDate(report.createdAt!)}-${formatTimestampToAmPm(report.createdAt!)}",
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: Colors.grey)),
                            const SizedBox(height: 8),
                            Text(report.description,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.2,
                                    color: Colors.grey)),
                            const SizedBox(height: 8),
                            if (attachment.sourceUrl != null)
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: attachment.sourceUrl!
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
                              )
                          ],
                        ),
                      ),
                      leading: const CircleAvatar(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        child: Icon(Icons.hourglass_top), // Icon for 'In Progress'
                      ),
                      trailing: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        transitionBuilder: (child, animation) =>
                            RotationTransition(turns: animation, child: child),
                        child: Icon(
                          (cubit.isExpanded && cubit.reportIndex == index)
                              ? Icons.keyboard_arrow_down_outlined
                              : Icons.arrow_forward_ios_rounded,
                          key: ValueKey<bool>(cubit.isExpanded && cubit.reportIndex == index),
                          color: Colors.grey,
                          size: 13,
                        ),
                      ),
                  );
                },
              ),
            ],
          ),
        );

        if (embedded) {
          return Column(
            children: [
              embeddedHeader,
              Expanded(child: reportBody),
            ],
          );
        }

        if (context.isIOS) {
          return CupertinoPageScaffold(
            navigationBar: CupertinoNavigationBar(
              middle: Text(pageHeaderTitle),
              trailing: CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => newReport(
                  context.loc.maintenanceReport,
                  context,
                  issueDescription,
                  issueTitle,
                  issueCategory,
                  maintenanceType,
                ),
                child: const Icon(CupertinoIcons.add),
              ),
            ),
            child: SafeArea(child: Material(
                color: Colors.transparent,
                child: reportBody)),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(pageHeaderTitle),
            actions: [Padding(padding: const EdgeInsets.only(right: 8), child: addButton)],
          ),
          body: reportBody,
        );
      },
    );
  }
}


// -----------------------------------------------------------------------------
// NEW DIALOG LOGIC
// -----------------------------------------------------------------------------

Future<void> newReport(
    String dialogTitle,
    BuildContext context,
    TextEditingController issue,
    TextEditingController issueTitle,
    TextEditingController issueCategory,
    MaintenanceReportType maintenanceType,
    ) async {
  // We delegate to a StatefulWidget to handle Keyboard listeners properly
  return showDialog(
    context: context,
    builder: (BuildContext context) {
      return CreateMaintenanceReportDialog(
        dialogTitle: dialogTitle,
        issue: issue,
        issueTitle: issueTitle,
        issueCategory: issueCategory,
        maintenanceType: maintenanceType,
      );
    },
  );
}

class CreateMaintenanceReportDialog extends StatefulWidget {
  final String dialogTitle;
  final TextEditingController issue;
  final TextEditingController issueTitle;
  final TextEditingController issueCategory;
  final MaintenanceReportType maintenanceType;

  const CreateMaintenanceReportDialog({
    super.key,
    required this.dialogTitle,
    required this.issue,
    required this.issueTitle,
    required this.issueCategory,
    required this.maintenanceType,
  });

  @override
  State<CreateMaintenanceReportDialog> createState() =>
      _CreateMaintenanceReportDialogState();
}

class _CreateMaintenanceReportDialogState
    extends State<CreateMaintenanceReportDialog> with WidgetsBindingObserver {
  // Local State
  final _formKey = GlobalKey<FormState>();
  bool isSending = false;
  List<XFile>? file;
  late final List<DropdownMenuEntry<String>> categoryEntries;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize category entries based on type
    switch (widget.maintenanceType) {
      case MaintenanceReportType.maintenance:
        categoryEntries = MaintenanceCategory.values
            .map((c) => DropdownMenuEntry<String>(
            value: c.name, label: c.name.toUpperCase()))
            .toList();
        break;
      case MaintenanceReportType.security:
        categoryEntries = SecurityCategory.values
            .map((c) => DropdownMenuEntry<String>(
            value: c.name, label: c.name.toUpperCase()))
            .toList();
        break;
      case MaintenanceReportType.careService:
        categoryEntries = CareServiceCategory.values
            .map((c) => DropdownMenuEntry<String>(
            value: c.name, label: c.name.toUpperCase()))
            .toList();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Note: We do NOT dispose the controllers passed from the parent widget here.
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      // Use insetPadding based on keyboard height
      insetPadding: EdgeInsets.fromLTRB(24, 24, 24, 3),
      backgroundColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),

      content: SizedBox(
        width: MediaQuery.sizeOf(context).width * 0.9,

        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.arrow_back),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    SizedBox(width: 8),
                    Text(widget.dialogTitle),
                  ],
                ),
                SizedBox(height: 20),
                DropdownMenu<String>(
                  width: MediaQuery.sizeOf(context).width * 0.65,
                  inputDecorationTheme: InputDecorationTheme(
                    fillColor: HexColor("#f0f2f5"),
                    filled: true,
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
                  menuStyle: MenuStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.white),
                    fixedSize: WidgetStateProperty.all<Size>(
                      Size(MediaQuery.sizeOf(context).width * 0.65,
                          double.infinity),
                    ),
                  ),
                  onSelected: (value) {
                    setState(() {
                      widget.issueCategory.text = value ?? 'other';
                    });
                  },
                  label: Text(context.loc.maintenanceIssueSelect),
                  dropdownMenuEntries: categoryEntries,
                ),
                const SizedBox(height: 15),
                TextFormField(
                  keyboardType: TextInputType.text,
                  controller: widget.issueTitle,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: HexColor("#f0f2f5"),
                    isDense: false,
                    border: OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(7)),
                    labelText: context.loc.issueTitle,
                    labelStyle: GoogleFonts.plusJakartaSans(
                      color: HexColor("#60768a"),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  constraints: BoxConstraints(minHeight: 120),
                  width: MediaQuery.sizeOf(context).width * 0.8,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: HexColor("#f0f2f5"),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextFormField(
                    keyboardType: TextInputType.multiline,
                    controller: widget.issue,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a description';
                      }
                      return null;
                    },
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      labelText: context.loc.issueDescription,
                      labelStyle: GoogleFonts.plusJakartaSans(
                        color: HexColor("#60768a"),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.2,
                      ),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  context.loc.uploadPhotos,
                  style:
                  GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.start,
                ),
                const SizedBox(height: 15),
                Stack(
                  alignment: AlignmentDirectional.topEnd,
                  children: [
                    GridView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 8.0,
                        mainAxisSpacing: 8.0,
                      ),
                      itemCount: file?.length ?? 0,
                      itemBuilder: (context, index) {
                        final imagePath = file![index].path;
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(
                                  imagePath,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const ColoredBox(
                                    color: Colors.black12,
                                    child: Center(
                                      child: Icon(Icons.image_not_supported_outlined),
                                    ),
                                  ),
                                )
                              : Image.file(
                                  File(imagePath),
                                  fit: BoxFit.cover,
                                ),
                        );
                      },
                    ),
                    file != null
                        ? IconButton(
                      onPressed: () {
                        setState(() {
                          file = null;
                        });
                      },
                      icon: Icon(Icons.close),
                    )
                        : DottedBorder(
                      options: RoundedRectDottedBorderOptions(
                        radius: Radius.circular(8),
                        strokeWidth: 2,
                        color: Colors.grey.shade400,
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
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              context.loc.emptyPhotos,
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700),
                            ),
                            Text(
                              context.loc.uploadPhotosLabel,
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w400),
                            ),
                            MaterialButton(
                              onPressed: () async {
                                List<XFile>? result = await ImagePicker()
                                    .pickMultiImage(
                                  imageQuality: 70,
                                  maxWidth: 1440,
                                );

                                if (result.isEmpty) return;

                                setState(() {
                                  file = result;
                                });
                              },
                              color: HexColor("f0f2f5"),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18.0),
                              ),
                              child: Text(context.loc.upload,
                                  style: GoogleFonts.plusJakartaSans(
                                      color: Colors.black,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                MaterialButton(
                  onPressed: isSending
                      ? null
                      : () async {
                    if (!(_formKey.currentState?.validate() ?? false)) {
                      return;
                    }
                    if (widget.issueCategory.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Please select a category')),
                      );
                      return;
                    }

                    setState(() {
                      isSending = true;
                    });

                    final authState = context.read<AuthCubit>().state;
                    final compoundIdStr = (authState is Authenticated)
                        ? authState.selectedCompoundId?.toString()
                        : null;

                    await context.read<MaintenanceCubit>().submitReport(
                        userId: (authState as Authenticated).user.id,
                        title: widget.issueTitle.text,
                        description: widget.issue.text,
                        category: widget.issueCategory.text,
                        files: file,
                        type: widget.maintenanceType,
                        compoundId: compoundIdStr);

                    if (mounted) {
                      setState(() {
                        isSending = false;
                      });
                      Navigator.pop(context);
                    }
                  },
                  color: Colors.blue,
                  disabledColor: Colors.blue.withAlpha(500),
                  elevation: 0,
                  minWidth: double.infinity,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18.0),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Text(context.loc.reportSubmission,
                          style: context.txt.reportSubmissionButton),
                      if (isSending)
                        const SizedBox(
                            height: 30,
                            width: 30,
                            child: CircularProgressIndicator.adaptive()),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}