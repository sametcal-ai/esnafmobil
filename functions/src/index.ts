import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

admin.initializeApp();

const callableOptions = {
  // For 2nd gen functions, invocation is protected by Cloud Run/IAM.
  // Firebase Callable auth is handled inside the function via request.auth,
  // so the endpoint must be publicly invokable.
  invoker: 'public' as const,
};

type ApproveMemberInput = {
  companyId: string;
  uid: string;
  role: 'admin' | 'cashier';
};

type GetMyMembershipsOutput = {
  memberships: Array<{
    companyId: string;
    member: Record<string, unknown>;
  }>;
};

export const approveMember = onCall<ApproveMemberInput>(callableOptions, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const { companyId, uid, role } = request.data || ({} as ApproveMemberInput);

  if (!companyId || !uid || !role) {
    throw new HttpsError('invalid-argument', 'companyId, uid and role are required.');
  }

  if (role !== 'admin' && role !== 'cashier') {
    throw new HttpsError('invalid-argument', 'role must be admin or cashier.');
  }

  const db = admin.firestore();

  const callerUid = request.auth.uid;
  const callerRef = db.doc(`companies/${companyId}/members/${callerUid}`);
  const targetRef = db.doc(`companies/${companyId}/members/${uid}`);

  const callerSnap = await callerRef.get();
  if (!callerSnap.exists) {
    throw new HttpsError('permission-denied', 'Caller is not a member of this company.');
  }

  const callerData = callerSnap.data() as { role?: string; status?: string };
  if (callerData.status !== 'active' || callerData.role !== 'admin') {
    throw new HttpsError('permission-denied', 'Admin role required.');
  }

  const targetSnap = await targetRef.get();
  if (!targetSnap.exists) {
    throw new HttpsError('not-found', 'Target membership not found.');
  }

  await targetRef.update({
    status: 'active',
    role,
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    approvedBy: callerUid,
  });

  return { ok: true };
});

export const getMyMemberships = onCall<undefined>(callableOptions, async (request): Promise<GetMyMembershipsOutput> => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const uid = request.auth.uid;
  const db = admin.firestore();

  // This is intentionally company-id based instead of collectionGroup to also work
  // when member documents don't contain a `uid` field and rely on docId==uid.
  const companiesSnap = await db.collection('companies').get();

  const memberRefs = companiesSnap.docs.map((d) => db.doc(`companies/${d.id}/members/${uid}`));
  const memberSnaps = memberRefs.length > 0 ? await db.getAll(...memberRefs) : [];

  const memberships = memberSnaps
    .map((snap) => {
      if (!snap.exists) return null;

      const parts = snap.ref.path.split('/');
      const companyId = parts.length >= 2 ? parts[1] : '';

      return {
        companyId,
        member: snap.data() as Record<string, unknown>,
      };
    })
    .filter((x): x is NonNullable<typeof x> => x != null && x.companyId.length > 0);

  return { memberships };
});
