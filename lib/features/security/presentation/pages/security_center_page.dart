import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:WhatsUnity/core/config/Enums.dart';
import 'package:WhatsUnity/core/config/appwrite.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:WhatsUnity/features/auth/presentation/bloc/auth_state.dart';
import 'package:WhatsUnity/features/maintenance/presentation/bloc/maintenance_cubit.dart';
import 'package:WhatsUnity/features/maintenance/presentation/pages/maintenance_page.dart';
import 'package:WhatsUnity/core/theme/lightTheme.dart';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as aw_models;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class SecurityCenterPage extends StatefulWidget {
  const SecurityCenterPage({super.key});

  @override
  State<SecurityCenterPage> createState() => _SecurityCenterPageState();
}

class _SecurityCenterPageState extends State<SecurityCenterPage>
    with SingleTickerProviderStateMixin {
  static const String _kGatePassTable = 'gate_passes';
  final TextEditingController _guestNameController = TextEditingController();
  final TextEditingController _purposeController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _generalNoteController = TextEditingController();
  final List<_GatePassItem> _gatePasses = <_GatePassItem>[];
  final List<_SecurityNoteItem> _generalNotes = <_SecurityNoteItem>[];
  XFile? _pendingNotePhoto;
  late final TabController _tabController;
  int _validHours = 4;
  bool _creatingPass = false;
  bool _loadedSecurityReports = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRemoteGatePasses();
  }

  @override
  void dispose() {
    _guestNameController.dispose();
    _purposeController.dispose();
    _notesController.dispose();
    _generalNoteController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRemoteGatePasses() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;
    final compoundId = authState.selectedCompoundId;
    if (compoundId == null || compoundId.isEmpty) return;
    try {
      final rows = await appwriteTables.listRows(
        databaseId: appwriteDatabaseId,
        tableId: _kGatePassTable,
        queries: [
          Query.equal('compound_id', compoundId),
          Query.equal('resident_id', authState.user.id),
          Query.isNull('deleted_at'),
          Query.orderDesc(r'$createdAt'),
          Query.limit(200),
        ],
      );
      final loaded = rows.rows.map((row) => _GatePassItem.fromAppwriteRow(row)).toList();
      if (!mounted) return;
      setState(() {
        _gatePasses
          ..clear()
          ..addAll(loaded);
      });
    } catch (_) {
      // Table may not be provisioned yet; keep local-only mode.
    }
  }

  Future<void> _createGatePass() async {
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;
    final compoundId = authState.selectedCompoundId;
    if (compoundId == null || compoundId.isEmpty) return;
    final guestName = _guestNameController.text.trim();
    final purpose = _purposeController.text.trim();
    final notes = _notesController.text.trim();
    if (guestName.isEmpty || purpose.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Guest name and purpose are required.')),
      );
      return;
    }
    setState(() => _creatingPass = true);
    final now = DateTime.now().toUtc();
    final validUntil = now.add(Duration(hours: _validHours));
    final passId = const Uuid().v4();
    final payload = jsonEncode({
      'passId': passId,
      'compoundId': compoundId,
      'residentId': authState.user.id,
      'guestName': guestName,
      'purpose': purpose,
      'notes': notes,
      'validUntil': validUntil.toIso8601String(),
      'generatedAt': now.toIso8601String(),
    });
    final item = _GatePassItem(
      id: passId,
      guestName: guestName,
      purpose: purpose,
      notes: notes,
      validUntil: validUntil.toLocal(),
      status: 'active',
      qrPayload: payload,
    );

    try {
      await appwriteTables.createRow(
        databaseId: appwriteDatabaseId,
        tableId: _kGatePassTable,
        rowId: passId,
        data: {
          'compound_id': compoundId,
          'resident_id': authState.user.id,
          'guest_name': guestName,
          'purpose': purpose,
          'valid_until': validUntil.toIso8601String(),
          'status': 'active',
          'qr_payload': payload,
          'version': 0,
        },
      );
    } catch (_) {
      // Keep local item even if backend table doesn't exist yet.
    }
    if (!mounted) return;
    setState(() {
      _gatePasses.insert(0, item);
      _creatingPass = false;
    });
    _guestNameController.clear();
    _purposeController.clear();
    _notesController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _revokeGatePass(_GatePassItem pass) async {
    try {
      await appwriteTables.updateRow(
        databaseId: appwriteDatabaseId,
        tableId: _kGatePassTable,
        rowId: pass.id,
        data: {'status': 'revoked'},
      );
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      final i = _gatePasses.indexWhere((p) => p.id == pass.id);
      if (i != -1) {
        _gatePasses[i] = _gatePasses[i].copyWith(status: 'revoked');
      }
    });
  }

  Future<void> _shareGatePassViaWhatsApp(_GatePassItem pass) async {
    try {
      final painter = QrPainter(
        data: pass.qrPayload,
        version: QrVersions.auto,
        gapless: true,
      );
      final byteData = await painter.toImageData(
        1024,
        format: ui.ImageByteFormat.png,
      );
      final pngBytes = byteData?.buffer.asUint8List();
      if (pngBytes == null || pngBytes.isEmpty) {
        throw StateError('Failed to generate QR image bytes.');
      }
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/gate_pass_${pass.id}.png');
      await file.writeAsBytes(Uint8List.fromList(pngBytes), flush: true);

      final shareText = StringBuffer()
        ..writeln('Visitor Gate Pass')
        ..writeln('Guest: ${pass.guestName}')
        ..writeln('Purpose: ${pass.purpose}')
        ..writeln('Valid Until: ${pass.validUntil}')
        ..writeln()
        ..writeln('Please share this barcode with gate security via WhatsApp.');

      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile(file.path, mimeType: 'image/png', name: 'gate_pass_qr.png'),
          ],
          text: shareText.toString(),
          subject: 'Visitor Gate Pass QR',
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share gate pass QR.')),
      );
    }
  }

  void _ensureSecurityReportsLoaded() {
    if (_loadedSecurityReports) return;
    final authState = context.read<AuthCubit>().state;
    if (authState is! Authenticated) return;
    final compoundId = authState.selectedCompoundId;
    if (compoundId == null || compoundId.isEmpty) return;
    _loadedSecurityReports = true;
    context.read<MaintenanceCubit>().getMaintenanceReports(
          compoundId: compoundId,
          type: MaintenanceReportType.security,
        );
  }

  void _addGeneralNote() {
    final note = _generalNoteController.text.trim();
    if (note.isEmpty) return;
    setState(() {
      _generalNotes.insert(
        0,
        _SecurityNoteItem(
          note: note,
          photoPath: _pendingNotePhoto?.path,
        ),
      );
      _pendingNotePhoto = null;
    });
    _generalNoteController.clear();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _pickNotePhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 75,
        maxWidth: 1280,
      );
      if (!mounted) return;
      setState(() => _pendingNotePhoto = picked);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not pick note photo.')),
      );
    }
  }

  Future<void> _openRecentPassesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: _gatePasses.isEmpty
              ? const Center(child: Text('No gate passes generated yet.'))
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: _gatePasses.map((pass) {
                    final isExpired = DateTime.now().isAfter(pass.validUntil);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    pass.guestName,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    isExpired ? 'expired' : pass.status,
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ],
                            ),
                            Text('Purpose: ${pass.purpose}',
                                style: const TextStyle(fontSize: 12)),
                            Text('Valid until: ${pass.validUntil}',
                                style: const TextStyle(fontSize: 12)),
                            const SizedBox(height: 8),
                            Center(child: QrImageView(data: pass.qrPayload, size: 140)),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: OutlinedButton.icon(
                                onPressed: () => _shareGatePassViaWhatsApp(pass),
                                icon: const Icon(Icons.share_outlined, size: 16),
                                label: const Text('Send QR via WhatsApp'),
                              ),
                            ),
                            if (!isExpired && pass.status == 'active')
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () => _revokeGatePass(pass),
                                  icon: const Icon(Icons.block, size: 16),
                                  label: const Text('Revoke'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ),
    );
  }

  Future<void> _openNotesSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _generalNoteController,
                maxLines: 2,
                maxLength: 240,
                decoration: const InputDecoration(
                  labelText: 'Add security instruction',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickNotePhoto,
                    icon: const Icon(Icons.image_outlined, size: 16),
                    label: Text(
                      _pendingNotePhoto == null ? 'Add Photo' : 'Photo Added',
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_pendingNotePhoto != null)
                    TextButton(
                      onPressed: () => setState(() => _pendingNotePhoto = null),
                      child: const Text('Remove Photo'),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _addGeneralNote,
                  icon: const Icon(Icons.note_add_outlined, size: 16),
                  label: const Text('Add Note'),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: _generalNotes.isEmpty
                    ? const Center(child: Text('No notes added yet.'))
                    : ListView(
                        shrinkWrap: true,
                        children: _generalNotes
                            .map(
                              (noteItem) => Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blueGrey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blueGrey.shade100),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      noteItem.note,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    if (noteItem.photoPath != null &&
                                        noteItem.photoPath!.trim().isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: kIsWeb
                                            ? Image.network(
                                                noteItem.photoPath!,
                                                height: 130,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              )
                                            : Image.file(
                                                File(noteItem.photoPath!),
                                                height: 130,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = TabBarView(
      controller: _tabController,
      children: [
        _buildVisitorGatePassTab(),
        Builder(
          builder: (context) {
            _ensureSecurityReportsLoaded();
            return Maintenance(
              maintenanceType: MaintenanceReportType.security,
              embedded: true,
              headerTitle: 'Reporting',
            );
          },
        ),
        const _InfoPlaceholderTab(
          title: 'Lost & Found',
          description:
              'Track reported lost items and security-found belongings in one place.',
        ),
      ],
    );

    if (context.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Security Center'),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight),
            child: TabBar(
              isScrollable: true,
              controller: _tabController,
              tabs: const [
                Tab(text: 'Gate'),
                Tab(text: 'Reporting'),
                Tab(text: 'Lost & Found'),
              ],
            ),
          ),
        ),
        child: SafeArea(child: body),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Center'),
        bottom: TabBar(
          isScrollable: true,
          controller: _tabController,
          tabs: const [
            Tab(text: 'Gate'),
            Tab(text: 'Reporting'),
            Tab(text: 'Lost & Found'),
          ],
        ),
      ),
      body: body,
    );
  }

  Widget _buildVisitorGatePassTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _CountBadgeButton(
              icon: Icons.qr_code_scanner,
              label: 'Passes',
              count: _gatePasses.length,
              onTap: _openRecentPassesSheet,
            ),
            const SizedBox(width: 8),
            _CountBadgeButton(
              icon: Icons.sticky_note_2_outlined,
              label: 'Notes',
              count: _generalNotes.length,
              onTap: _openNotesSheet,
            ),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create Visitor Gate',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _guestNameController,
                  decoration: const InputDecoration(
                    labelText: 'Guest Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _purposeController,
                  decoration: const InputDecoration(
                    labelText: 'Purpose',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesController,
                  maxLines: 2,
                  maxLength: 400,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Access Instructions',
                    hintText:
                        'Example: Not allowed to enter without resident call confirmation.',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  initialValue: _validHours,
                  decoration: const InputDecoration(
                    labelText: 'Valid For',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1 hour')),
                    DropdownMenuItem(value: 4, child: Text('4 hours')),
                    DropdownMenuItem(value: 8, child: Text('8 hours')),
                    DropdownMenuItem(value: 24, child: Text('24 hours')),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _validHours = value);
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _creatingPass ? null : _createGatePass,
                    icon: _creatingPass
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                          )
                        : const Icon(Icons.qr_code_2),
                    label: const Text('Generate Gate Pass'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CountBadgeButton extends StatelessWidget {
  const _CountBadgeButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text('$label ($count)', style: const TextStyle(fontSize: 12)),
    );
  }
}

class _SecurityNoteItem {
  const _SecurityNoteItem({
    required this.note,
    this.photoPath,
  });

  final String note;
  final String? photoPath;
}

class _InfoPlaceholderTab extends StatelessWidget {
  const _InfoPlaceholderTab({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(description, textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GatePassItem {
  const _GatePassItem({
    required this.id,
    required this.guestName,
    required this.purpose,
    required this.notes,
    required this.validUntil,
    required this.status,
    required this.qrPayload,
  });

  final String id;
  final String guestName;
  final String purpose;
  final String notes;
  final DateTime validUntil;
  final String status;
  final String qrPayload;

  factory _GatePassItem.fromAppwriteRow(aw_models.Row row) {
    final payloadRaw = row.data['qr_payload']?.toString() ?? '';
    String extractedNotes = '';
    if (payloadRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(payloadRaw);
        if (decoded is Map) {
          extractedNotes = decoded['notes']?.toString() ?? '';
        }
      } catch (_) {}
    }
    return _GatePassItem(
      id: row.$id,
      guestName: row.data['guest_name']?.toString() ?? 'Guest',
      purpose: row.data['purpose']?.toString() ?? '',
      notes: extractedNotes,
      validUntil: DateTime.tryParse(row.data['valid_until']?.toString() ?? '')
              ?.toLocal() ??
          DateTime.now(),
      status: row.data['status']?.toString() ?? 'active',
      qrPayload: row.data['qr_payload']?.toString() ?? '',
    );
  }

  _GatePassItem copyWith({
    String? id,
    String? guestName,
    String? purpose,
    String? notes,
    DateTime? validUntil,
    String? status,
    String? qrPayload,
  }) {
    return _GatePassItem(
      id: id ?? this.id,
      guestName: guestName ?? this.guestName,
      purpose: purpose ?? this.purpose,
      notes: notes ?? this.notes,
      validUntil: validUntil ?? this.validUntil,
      status: status ?? this.status,
      qrPayload: qrPayload ?? this.qrPayload,
    );
  }
}

