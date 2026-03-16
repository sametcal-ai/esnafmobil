import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';

admin.initializeApp();

type ApproveMemberInput = {
  companyId: string;
  uid: string;
  role: 'admin' | 'cashier';
};

export const approveMember = onCall<ApproveMemberInput>(async (request) => {
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
