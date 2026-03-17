import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/firestore/models/company_member.dart';
import '../../auth/domain/firebase_auth_controller.dart';
import 'company_membership.dart';

final firebaseFunctionsProvider = Provider<FirebaseFunctions>((ref) {
  // Use an explicit app+region binding to avoid mismatches where some calls go to
  // a different Firebase app instance or default region.
  return FirebaseFunctions.instanceFor(
    app: Firebase.app(),
    region: 'us-central1',
  );
});

final companyMembershipsSnapshotProvider =
    StreamProvider.autoDispose<QuerySnapshot<CompanyMember>>((ref) {
  final authUser = ref.watch(authStateProvider).asData?.value;

  if (authUser == null) {
    return const Stream<QuerySnapshot<CompanyMember>>.empty();
  }

  final refs = ref.watch(firestoreRefsProvider);
  return refs.membersGroupByUid(authUser.uid).snapshots();
});

Future<List<CompanyMembership>> _fallbackMembershipsViaFunction(
  Ref ref,
  String uid,
) async {
  final functions = ref.read(firebaseFunctionsProvider);
  final callable = functions.httpsCallable('getMyMemberships');

  final res = await callable();
  final data = res.data;
  if (data is! Map) return const <CompanyMembership>[];

  final raw = data['memberships'];
  if (raw is! List) return const <CompanyMembership>[];

  return raw.map((item) {
    if (item is! Map) return null;

    final companyId = item['companyId'];
    final member = item['member'];

    if (companyId is! String || member is! Map) return null;

    final memberMap = Map<String, dynamic>.from(member);

    return CompanyMembership(
      companyId: companyId,
      member: CompanyMember.fromMap(
        uid: (memberMap['uid'] as String?) ?? uid,
        data: memberMap,
      ),
    );
  }).whereType<CompanyMembership>().toList(growable: false);
}

final companyMembershipsProvider =
    StreamProvider.autoDispose<List<CompanyMembership>>((ref) async* {
  final authUser = ref.watch(authStateProvider).asData?.value;

  if (authUser == null) {
    yield const <CompanyMembership>[];
    return;
  }

  final refs = ref.watch(firestoreRefsProvider);

  try {
    await for (final snap in refs.membersGroupByUid(authUser.uid).snapshots()) {
      yield snap.docs.map((doc) {
        final member = doc.data();
        final companyId = doc.reference.parent.parent!.id;
        return CompanyMembership(companyId: companyId, member: member);
      }).toList(growable: false);
    }
  } on FirebaseException catch (e) {
    if (e.code == 'permission-denied') {
      final items = await _fallbackMembershipsViaFunction(ref, authUser.uid);
      yield items;
      return;
    }
    rethrow;
  }
});
