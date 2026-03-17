import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

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

type RejectMemberInput = {
  companyId: string;
  uid: string;
};

type JoinCompanyByCodeInput = {
  companyCode: string;
  displayName?: string;
};

type JoinCompanyByCodeOutput = {
  companyId: string;
  status: string;
};

type CreateCompanyInput = {
  name: string;
};

type CreateCompanyOutput = {
  companyId: string;
  companyCode: string;
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

  const targetData = targetSnap.data() as { status?: string };
  if (targetData.status && targetData.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Only pending members can be approved.');
  }

  await targetRef.update({
    status: 'active',
    role,
    approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    approvedBy: callerUid,
  });

  return { ok: true };
});

export const rejectMember = onCall<RejectMemberInput>(callableOptions, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }

  const { companyId, uid } = request.data || ({} as RejectMemberInput);

  if (!companyId || !uid) {
    throw new HttpsError('invalid-argument', 'companyId and uid are required.');
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

  const targetData = targetSnap.data() as { status?: string };
  if (targetData.status && targetData.status !== 'pending') {
    throw new HttpsError('failed-precondition', 'Only pending members can be rejected.');
  }

  await targetRef.delete();

  return { ok: true };
});

export const joinCompanyByCode = onCall<JoinCompanyByCodeInput>(
  callableOptions,
  async (request): Promise<JoinCompanyByCodeOutput> => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const { companyCode, displayName } = request.data || ({} as JoinCompanyByCodeInput);

    if (!companyCode || typeof companyCode !== 'string') {
      throw new HttpsError('invalid-argument', 'companyCode is required.');
    }

    const normalized = companyCode.trim();
    if (normalized.length < 3) {
      throw new HttpsError('invalid-argument', 'companyCode is invalid.');
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const companySnap = await db
      .collection('companies')
      .where('companyCode', '==', normalized)
      .limit(1)
      .get();

    if (companySnap.empty) {
      throw new HttpsError('not-found', 'Company not found for given code.');
    }

    const companyId = companySnap.docs[0].id;
    const memberRef = db.doc(`companies/${companyId}/members/${uid}`);

    const existing = await memberRef.get();
    if (existing.exists) {
      const data = existing.data() as { status?: string };
      return { companyId, status: data.status ?? 'active' };
    }

    const email = typeof request.auth.token?.email === 'string' ? request.auth.token.email : null;
    const safeDisplayName = typeof displayName === 'string' ? displayName.trim().slice(0, 64) : '';

    await memberRef.create({
      uid,
      email,
      displayName: safeDisplayName,
      status: 'pending',
      role: null,
      permissions: [],
      storeIds: [],
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { companyId, status: 'pending' };
  },
);

function randomCompanyCode(length = 6) {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let out = '';
  for (let i = 0; i < length; i++) {
    out += alphabet[Math.floor(Math.random() * alphabet.length)];
  }
  return out;
}

export const createCompany = onCall<CreateCompanyInput>(
  callableOptions,
  async (request): Promise<CreateCompanyOutput> => {
    if (!request.auth?.uid) {
      throw new HttpsError('unauthenticated', 'Authentication required.');
    }

    const { name } = request.data || ({} as CreateCompanyInput);
    const companyName = typeof name === 'string' ? name.trim() : '';
    if (!companyName) {
      throw new HttpsError('invalid-argument', 'name is required.');
    }

    const uid = request.auth.uid;
    const db = admin.firestore();

    const companyRef = db.collection('companies').doc();

    let companyCode = '';
    for (let attempt = 0; attempt < 5; attempt++) {
      const code = randomCompanyCode(6);
      const dup = await db.collection('companies').where('companyCode', '==', code).limit(1).get();
      if (dup.empty) {
        companyCode = code;
        break;
      }
    }

    if (!companyCode) {
      throw new HttpsError('internal', 'Failed to generate unique company code.');
    }

    const memberRef = db.doc(`companies/${companyRef.id}/members/${uid}`);

    await db.runTransaction(async (tx) => {
      tx.create(companyRef, {
        companyCode,
        name: companyName,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        ownerUid: uid,
      });

      const email = typeof request.auth?.token?.email === 'string' ? request.auth.token.email : null;

      tx.create(memberRef, {
        uid,
        email,
        displayName: '',
        status: 'active',
        role: 'admin',
        permissions: [],
        storeIds: [],
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    return { companyId: companyRef.id, companyCode };
  },
);

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

export const onSaleCreated = onDocumentCreated('companies/{companyId}/sales/{saleId}', async (event) => {
  const { companyId, saleId } = event.params;
  const db = admin.firestore();

  const saleRef = db.doc(`companies/${companyId}/sales/${saleId}`);

  await db.runTransaction(async (tx) => {
    const saleSnap = await tx.get(saleRef);
    if (!saleSnap.exists) return;

    const sale = saleSnap.data() as Record<string, unknown>;

    if (sale.stockProcessedAt) {
      return;
    }

    const itemsRaw = sale.items;
    const items = Array.isArray(itemsRaw) ? itemsRaw : [];

    const warnings: Array<{
      productId: string;
      requestedQty: number;
      stockBefore: number;
      stockAfter: number;
    }> = [];

    for (const itemRaw of items) {
      if (!itemRaw || typeof itemRaw !== 'object') continue;
      const item = itemRaw as { productId?: unknown; quantity?: unknown };

      const productId = typeof item.productId === 'string' ? item.productId : '';
      const qty = typeof item.quantity === 'number' ? item.quantity : Number(item.quantity);

      if (!productId || !Number.isFinite(qty) || qty <= 0) continue;

      const productRef = db.doc(`companies/${companyId}/products/${productId}`);
      const productSnap = await tx.get(productRef);

      const product = (productSnap.data() || {}) as { stockQuantity?: unknown };
      const stockBefore = typeof product.stockQuantity === 'number' ? product.stockQuantity : Number(product.stockQuantity ?? 0);
      const stockAfter = stockBefore - qty;

      tx.set(
        productRef,
        {
          stockQuantity: stockAfter,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      if (stockAfter < 0) {
        warnings.push({
          productId,
          requestedQty: qty,
          stockBefore,
          stockAfter,
        });
      }
    }

    tx.set(
      saleRef,
      {
        stockProcessedAt: admin.firestore.FieldValue.serverTimestamp(),
        stockWarnings: warnings,
        hasStockWarning: warnings.length > 0,
      },
      { merge: true },
    );

    if (warnings.length > 0) {
      const alertRef = db.collection(`companies/${companyId}/alerts`).doc();
      tx.create(alertRef, {
        type: 'oversold',
        saleId,
        companyId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'open',
        createdBy: 'system',
        items: warnings.map((w) => ({
          productId: w.productId,
          requestedQty: w.requestedQty,
          stockAfter: w.stockAfter,
        })),
      });
    }
  });
});