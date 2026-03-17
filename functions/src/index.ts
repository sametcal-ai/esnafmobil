import * as admin from 'firebase-admin';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { onDocumentCreated, onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onSchedule } from 'firebase-functions/v2/scheduler';

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
  // Fallback for cases where callable auth context isn't attached.
  // Client can pass Firebase Auth ID token; we verify it server-side.
  idToken?: string;
};

type RejectMemberInput = {
  companyId: string;
  uid: string;
  idToken?: string;
};

type UpdateMemberInput = {
  companyId: string;
  uid: string;
  displayName?: string;
  role?: 'admin' | 'cashier';
  active?: boolean;
  idToken?: string;
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

async function getCallerUid(request: any) {
  // Note: keep this helper small; we only want a safe fallback.
  const authUid = request.auth?.uid;
  if (authUid) return authUid;

  const dataToken = (request.data as { idToken?: unknown } | undefined)?.idToken;
  if (typeof dataToken === 'string' && dataToken.trim().length > 0) {
    const decoded = await admin.auth().verifyIdToken(dataToken);
    if (decoded?.uid) return decoded.uid;
  }

  const headerAuth = request.rawRequest?.headers?.authorization;
  if (typeof headerAuth === 'string') {
    const m = headerAuth.match(/^Bearer\s+(.+)$/i);
    const bearer = m?.[1]?.trim();
    if (bearer) {
      const decoded = await admin.auth().verifyIdToken(bearer);
      if (decoded?.uid) return decoded.uid;
    }
  }

  throw new HttpsError('unauthenticated', 'Authentication required.');
}

export const approveMember = onCall<ApproveMemberInput>(callableOptions, async (request) => {
  const callerUid = await getCallerUid(request);

  const { companyId, uid, role } = request.data || ({} as ApproveMemberInput);

  if (!companyId || !uid || !role) {
    throw new HttpsError('invalid-argument', 'companyId, uid and role are required.');
  }

  if (role !== 'admin' && role !== 'cashier') {
    throw new HttpsError('invalid-argument', 'role must be admin or cashier.');
  }

  const db = admin.firestore();

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
  const callerUid = await getCallerUid(request);

  const { companyId, uid } = request.data || ({} as RejectMemberInput);

  if (!companyId || !uid) {
    throw new HttpsError('invalid-argument', 'companyId and uid are required.');
  }

  const db = admin.firestore();

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

  const approvedBy = (targetData as { approvedBy?: unknown }).approvedBy;
  const approvedAt = (targetData as { approvedAt?: unknown }).approvedAt;

  const hadApproval =
    (typeof approvedBy === 'string' && approvedBy.trim().length > 0) || approvedAt != null;

  if (hadApproval) {
    await targetRef.set(
      {
        status: 'inactive',
        rejectedAt: admin.firestore.FieldValue.serverTimestamp(),
        rejectedBy: callerUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: callerUid,
      },
      { merge: true },
    );

    return { ok: true };
  }

  await targetRef.delete();

  return { ok: true };
});

export const updateMember = onCall<UpdateMemberInput>(callableOptions, async (request) => {
  const callerUid = await getCallerUid(request);

  const { companyId, uid, displayName, role, active } = request.data || ({} as UpdateMemberInput);

  if (!companyId || !uid) {
    throw new HttpsError('invalid-argument', 'companyId and uid are required.');
  }

  if (callerUid === uid) {
    throw new HttpsError('failed-precondition', 'Admin cannot edit their own membership via this endpoint.');
  }

  if (role != null && role !== 'admin' && role !== 'cashier') {
    throw new HttpsError('invalid-argument', 'role must be admin or cashier.');
  }

  if (displayName != null && typeof displayName !== 'string') {
    throw new HttpsError('invalid-argument', 'displayName must be a string.');
  }

  if (active != null && typeof active !== 'boolean') {
    throw new HttpsError('invalid-argument', 'active must be a boolean.');
  }

  const db = admin.firestore();

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
  if (targetData.status === 'pending') {
    throw new HttpsError('failed-precondition', 'Pending members must be approved first.');
  }

  const patch: Record<string, unknown> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedBy: callerUid,
  };

  if (displayName != null) {
    patch.displayName = displayName.trim().slice(0, 64);
  }

  if (role != null) {
    patch.role = role;
  }

  if (active != null) {
    patch.status = active ? 'active' : 'inactive';
  }

  if (Object.keys(patch).length <= 2) {
    throw new HttpsError('invalid-argument', 'No changes requested.');
  }

  await targetRef.set(patch, { merge: true });

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

    const email = typeof request.auth.token?.email === 'string' ? request.auth.token.email : null;
    const safeDisplayName = typeof displayName === 'string' ? displayName.trim().slice(0, 64) : '';

    const existing = await memberRef.get();
    if (existing.exists) {
      const data = existing.data() as {
        status?: string;
        email?: string | null;
        displayName?: string;
        uid?: string;
      };

      const existingStatus = typeof data.status === 'string' ? data.status : null;

      // Older member docs might have been created by the client (rules-limited)
      // and therefore miss displayName/email. Fill them in opportunistically.
      const patch: Record<string, unknown> = {};
      if (!data.uid) patch.uid = uid;

      const existingDisplayName = typeof data.displayName === 'string' ? data.displayName.trim() : '';
      if (!existingDisplayName && safeDisplayName) {
        patch.displayName = safeDisplayName;
      }

      const existingEmail = typeof data.email === 'string' ? data.email.trim() : '';
      if (!existingEmail && email) {
        patch.email = email;
      }

      // If membership was previously inactivated/rejected, allow user to re-apply
      // with the same company code by moving it back to pending.
      if (existingStatus === 'inactive') {
        patch.status = 'pending';
        patch.reappliedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      if (Object.keys(patch).length > 0) {
        await memberRef.set(patch, { merge: true });
      }

      const outStatus = typeof patch.status === 'string' ? (patch.status as string) : (existingStatus ?? 'active');
      return { companyId, status: outStatus };
    }

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

export const onStockEntryCreated = onDocumentCreated(
  'companies/{companyId}/stockEntries/{entryId}',
  async (event) => {
    const { companyId, entryId } = event.params;
    const db = admin.firestore();

    const entryRef = db.doc(`companies/${companyId}/stockEntries/${entryId}`);

    // Aktif fiyat listesi id'sini transaction dışında al (types/overload sorunlarını önlemek için).
    const activePriceListSnap = await db
      .collection(`companies/${companyId}/priceLists`)
      .where('isActive', '==', true)
      .limit(1)
      .get();

    const activePriceListId = activePriceListSnap.empty ? null : activePriceListSnap.docs[0].id;

    await db.runTransaction(async (tx) => {
      const entrySnap = await tx.get(entryRef);
      if (!entrySnap.exists) return;

      const entry = entrySnap.data() as {
        productId?: unknown;
        quantity?: unknown;
        type?: unknown;
        unitCost?: unknown;
        createdBy?: unknown;
      };

      const productId = typeof entry.productId === 'string' ? entry.productId : '';
      const qty = typeof entry.quantity === 'number' ? entry.quantity : Number(entry.quantity);
      const type = typeof entry.type === 'string' ? entry.type : 'incoming';
      const unitCost = typeof entry.unitCost === 'number' ? entry.unitCost : Number(entry.unitCost ?? 0);

      if (!productId || !Number.isFinite(qty) || qty <= 0) return;

      const delta = type === 'outgoing' ? -qty : qty;

      const productRef = db.doc(`companies/${companyId}/products/${productId}`);
      const productSnap = await tx.get(productRef);

      const product = (productSnap.data() || {}) as { stockQuantity?: unknown };
      const stockBefore = typeof product.stockQuantity === 'number' ? product.stockQuantity : Number(product.stockQuantity ?? 0);
      const stockAfter = stockBefore + delta;

      tx.set(
        productRef,
        {
          stockQuantity: stockAfter,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );

      // Incoming stok hareketlerinde aktif fiyat listesini güncelle.
      if (type !== 'incoming') return;
      if (!activePriceListId) return;

      const priceListId = activePriceListId;

      const marginRaw = (productSnap.data() || {}) as { marginPercent?: unknown };
      const marginPercent =
        typeof marginRaw.marginPercent === 'number' ? marginRaw.marginPercent : Number(marginRaw.marginPercent ?? 0);

      const salePrice = unitCost > 0 ? unitCost * (1 + (marginPercent > 0 ? marginPercent : 0) / 100) : 0;

      const actor = typeof entry.createdBy === 'string' && entry.createdBy.trim().length > 0 ? entry.createdBy.trim() : 'system';

      const itemRef = db.doc(`companies/${companyId}/priceLists/${priceListId}/items/${productId}`);

      const now = admin.firestore.FieldValue.serverTimestamp();

      tx.set(
        itemRef,
        {
          id: productId,
          productId,
          purchasePrice: unitCost,
          salePrice,
          isInherited: false,
          inheritedFromPriceListId: null,
          modifiedDate: now,
          modifiedBy: actor,
          versionNo: admin.firestore.FieldValue.increment(1),
          versionDate: now,
          // created fields only set if missing (merge handles)
          createdDate: now,
          createdBy: actor,
          isLocked: false,
          isVisible: true,
          isActived: true,
          isDeleted: false,
        },
        { merge: true },
      );
    });
  },
);

// priceList item değişince ürün kartındaki cache alanlarını güncelle.
export const onPriceListItemWritten = onDocumentWritten(
  'companies/{companyId}/priceLists/{priceListId}/items/{productId}',
  async (event) => {
    const { companyId, productId } = event.params;
    const after = event.data?.after;

    if (!after || !after.exists) {
      return;
    }

    const data = after.data() as { purchasePrice?: unknown; salePrice?: unknown; isDeleted?: unknown };

    const isDeleted = (data as any).isDeleted === true;
    if (isDeleted) return;

    const purchasePrice = typeof data.purchasePrice === 'number' ? data.purchasePrice : Number(data.purchasePrice ?? 0);
    const salePrice = typeof data.salePrice === 'number' ? data.salePrice : Number(data.salePrice ?? 0);

    const db = admin.firestore();
    const productRef = db.doc(`companies/${companyId}/products/${productId}`);

    await productRef.set(
      {
        lastPurchasePrice: purchasePrice,
        salePrice,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );
  },
);

// Süresi dolan aktif fiyat listesini pasife çekip, tarihe uygun bir liste varsa onu aktif yap.
export const priceListAutoActivate = onSchedule(
  {
    schedule: 'every 1 hours',
    timeZone: 'Europe/Istanbul',
  },
  async () => {
    const db = admin.firestore();
    const now = new Date();

    const companiesSnap = await db.collection('companies').get();

    for (const companyDoc of companiesSnap.docs) {
      const companyId = companyDoc.id;
      const priceListsRef = db.collection(`companies/${companyId}/priceLists`);

      const activeSnap = await priceListsRef.where('isActive', '==', true).limit(1).get();
      const activeDoc = activeSnap.docs[0];

      const activeData = activeDoc?.data() as { startDate?: any; endDate?: any } | undefined;
      const activeStart = activeData?.startDate?.toDate ? activeData.startDate.toDate() : null;
      const activeEnd = activeData?.endDate?.toDate ? activeData.endDate.toDate() : null;

      const activeValid =
        activeStart != null && activeEnd != null && now >= activeStart && now <= activeEnd;

      if (activeDoc && activeValid) {
        continue;
      }

      const candidatesSnap = await priceListsRef.get();
      const candidates = candidatesSnap.docs
        .map((d) => ({ id: d.id, ref: d.ref, data: d.data() as any }))
        .filter((x) => x.data && x.data.startDate?.toDate && x.data.endDate?.toDate)
        .filter((x) => {
          const s = x.data.startDate.toDate();
          const e = x.data.endDate.toDate();
          return now >= s && now <= e;
        })
        .sort((a, b) => b.data.startDate.toDate().getTime() - a.data.startDate.toDate().getTime());

      if (candidates.length === 0) {
        if (activeDoc) {
          await activeDoc.ref.set(
            {
              isActive: false,
              inactiveReason: 'Süresi doldu',
              modifiedDate: admin.firestore.FieldValue.serverTimestamp(),
              modifiedBy: 'system',
              versionNo: admin.firestore.FieldValue.increment(1),
              versionDate: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }
        continue;
      }

      const next = candidates[0];

      await db.runTransaction(async (tx) => {
        if (activeDoc && activeDoc.id !== next.id) {
          tx.set(
            activeDoc.ref,
            {
              isActive: false,
              inactiveReason: 'Süresi doldu',
              modifiedDate: admin.firestore.FieldValue.serverTimestamp(),
              modifiedBy: 'system',
              versionNo: admin.firestore.FieldValue.increment(1),
              versionDate: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        tx.set(
          next.ref,
          {
            isActive: true,
            inactiveReason: null,
            modifiedDate: admin.firestore.FieldValue.serverTimestamp(),
            modifiedBy: 'system',
            versionNo: admin.firestore.FieldValue.increment(1),
            versionDate: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true },
        );
      });

      // Yeni aktif listeye, bir önceki aktif listeden eksik item'ları taşı.
      if (activeDoc && activeDoc.id !== next.id) {
        const prevItemsSnap = await db.collection(`companies/${companyId}/priceLists/${activeDoc.id}/items`).get();
        const nextItemsSnap = await db.collection(`companies/${companyId}/priceLists/${next.id}/items`).get();
        const nextIds = new Set(nextItemsSnap.docs.map((d) => d.id));

        const batch = db.batch();
        for (const doc of prevItemsSnap.docs) {
          if (nextIds.has(doc.id)) continue;
          const item = doc.data() as any;

          batch.set(
            db.doc(`companies/${companyId}/priceLists/${next.id}/items/${doc.id}`),
            {
              ...item,
              id: doc.id,
              productId: item.productId ?? doc.id,
              isInherited: true,
              inheritedFromPriceListId: activeDoc.id,
              modifiedDate: admin.firestore.FieldValue.serverTimestamp(),
              modifiedBy: 'system',
              versionNo: admin.firestore.FieldValue.increment(1),
              versionDate: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true },
          );
        }

        await batch.commit();
      }
    }
  },
);

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

    const actor = typeof sale.createdBy === 'string' && sale.createdBy.trim().length > 0 ? sale.createdBy.trim() : 'system';

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

      const entryRef = db.collection(`companies/${companyId}/stockEntries`).doc();
      tx.create(entryRef, {
        id: entryRef.id,
        supplierId: null,
        supplierName: null,
        productId,
        quantity: qty,
        unitCost: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        type: 'outgoing',
        createdDate: admin.firestore.FieldValue.serverTimestamp(),
        createdBy: actor,
        modifiedDate: admin.firestore.FieldValue.serverTimestamp(),
        modifiedBy: actor,
        versionNo: 1,
        versionDate: admin.firestore.FieldValue.serverTimestamp(),
        isLocked: false,
        isVisible: true,
        isActived: true,
        isDeleted: false,
      });

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