import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../auth/domain/firebase_auth_controller.dart';
import 'company_membership.dart';

final firestoreRefsProvider = Provider<FirestoreRefs>((ref) {
  return FirestoreRefs.instance();
});

final companyMembershipsSnapshotProvider =
    StreamProvider.autoDispose<QuerySnapshot<CompanyMember>>((ref) {
  final authUser = ref.watch(authStateProvider).value;

  if (authUser == null) {
    return const Stream<QuerySnapshot<CompanyMember>>.empty();
  }

  final refs = ref.watch(firestoreRefsProvider);
  return refs.membersGroupByUid(authUser.uid).snapshots();
});

final companyMembershipsProvider =
    StreamProvider.autoDispose<List<CompanyMembership>>((ref) {
  final authUser = ref.watch(authStateProvider).value;

  if (authUser == null) {
    return const Stream<List<CompanyMembership>>.empty();
  }

  final refs = ref.watch(firestoreRefsProvider);

  return refs.membersGroupByUid(authUser.uid).snapshots().map((snap) {
    return snap.docs.map((doc) {
      final member = doc.data();
      final companyId = doc.reference.parent.parent!.id;
      return CompanyMembership(companyId: companyId, member: member);
    }).toList(growable: false);
  });
});
