import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/chat/presentation/widgets/chatWidget/Details/ChatMember.dart';
import '../models/CompoundsList.dart';
import 'Enums.dart';

// late final SupabaseClient supabase;
late final SupabaseClient supabase;

class Users {
  final String authorId;
  final String phoneNumber;
  final DateTime updatedAt;
  final String ownerShipType;
  final String userState;
  final String actionTakenBy;
  final List<Map<String, dynamic>> verFile;

  Users({
    required this.authorId,
    required this.phoneNumber,
    required this.updatedAt,
    required this.ownerShipType,
    required this.userState,
    required this.actionTakenBy,
    required this.verFile,
  });
}

class CompoundMembersResult {
  final List<ChatMember> members;
  final List<Users> membersData;
  CompoundMembersResult({
    required this.members,
    required this.membersData,
  });
}

Storage storageType = Storage.superbaseStorage;

class SupabaseArgs {
  final String url;
  final String anonKey;

  SupabaseArgs({
    required this.url,
    required this.anonKey,
  });
}

Future<List<Category>> fetchCompounds(SupabaseArgs args) async {
  debugPrint('Background isolate started fetching data for Categories...');
  final supabase = SupabaseClient(args.url, args.anonKey);

  final response = await supabase
      .from('compound_categories')
      .select('*, compounds(*)');

  final data = (response as List)
      .map((categoryJson) => Category.fromJson(categoryJson))
      .toList();
  debugPrint('Background isolate finished.');
  return data;
}

Future<CompoundMembersResult> fetchCompoundMembers(Map<String, dynamic> args) async {
  debugPrint('Background isolate started fetching data for CompoundMembers...');
  try {
    final supabase = SupabaseClient(args['url']!, args['anonKey']!);
    final isAdmin = (args['role'] as String?) == 'admin';

    final userApartmentsResponse = await supabase
        .from('user_apartments')
        .select('user_id , building_num , apartment_num')
        .eq('compound_id', args['CompoundIndex']!);

    if (userApartmentsResponse.isEmpty) {
      return CompoundMembersResult(members: [], membersData: []);
    }

    final userApartmentsList = (userApartmentsResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final apartmentsMap = <String, Map<String, dynamic>>{};
    for (final e in userApartmentsList) {
      final uid = e['user_id'].toString();
      apartmentsMap[uid] = e;
    }

    final userIds = userApartmentsResponse
        .map((row) => row['user_id'] as String)
        .toList();

    // `profiles.id` is often uuid-typed. Appwrite user ids are not valid uuids
    // — inFilter then throws 22P02. Migrate columns to text or use Appwrite DB.
    final profilesResponse = isAdmin
        ? await supabase
            .from('profiles')
            .select(
                'id, display_name, full_name , avatar_url , phone_number , updated_at , owner_type , userState , actionTakenBy , verFiles ')
            .inFilter('id', userIds)
        : await supabase
            .from('profiles')
            .select(
                'id, display_name, full_name , avatar_url , userState , phone_number , owner_type')
            .inFilter('id', userIds);

    final profilesList = (profilesResponse as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();

    final membersList = profilesList.map((data) {
      final id = data['id'].toString();
      final apt = apartmentsMap[id];
      return ChatMember(
        id: id,
        displayName: data['display_name'] ?? 'No Name',
        fullName: data['full_name'] ?? 'No Name',
        avatarUrl: data['avatar_url'],
        building: apt?['building_num'],
        apartment: apt?['apartment_num'],
        phoneNumber: data['phone_number'],
        ownerType: OwnerTypes.values.firstWhere(
            (type) => type.name == data['owner_type'],
            orElse: () => OwnerTypes.owner),
        userState: UserState.values.firstWhere(
            (state) => state.name == data['userState'],
            orElse: () => UserState.New),
      );
    }).toList();

    List<Users> memberData = [];
    if (isAdmin) {
      memberData = profilesList.map((data) {
        final id = data['id'].toString();
        final files = (data['verFiles'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e as Map))
                .toList() ??
            <Map<String, dynamic>>[];
        return Users(
          authorId: id,
          phoneNumber: (data['phone_number'] ?? '').toString(),
          updatedAt: DateTime.tryParse(data['updated_at']?.toString() ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0),
          ownerShipType: (data['owner_type'] ?? '').toString(),
          userState: (data['userState'] ?? '').toString(),
          actionTakenBy: (data['actionTakenBy'] ?? '').toString(),
          verFile: files,
        );
      }).toList();
    }

    debugPrint('Background isolate finished.');
    return CompoundMembersResult(members: membersList, membersData: memberData);
  } on PostgrestException catch (e) {
    debugPrint(
      'fetchCompoundMembers: empty result (uuid/id mismatch with Appwrite?). '
      '$e',
    );
    return CompoundMembersResult(members: [], membersData: []);
  } catch (e) {
    debugPrint('fetchCompoundMembers: $e');
    return CompoundMembersResult(members: [], membersData: []);
  }
}
