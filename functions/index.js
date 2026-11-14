const { initializeApp } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { getStorage } = require('firebase-admin/storage');
const { defineString } = require('firebase-functions/params');
const { HttpsError, onCall } = require('firebase-functions/v2/https');
const { setGlobalOptions } = require('firebase-functions/v2');

initializeApp();
setGlobalOptions({ region: 'us-central1', maxInstances: 20 });

const db = getFirestore();
const auth = getAuth();
const webApiKey = defineString('FIREBASE_WEB_API_KEY');
const USERNAME_PATTERN = /^[a-z0-9_.-]{3,24}$/;
const RESERVED_USERNAMES = new Set(['admin']);
const ORDER_LIMIT = 50;
const MAX_STOCK = 1000000;

function requireAuth(request) {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError('unauthenticated', 'Sign in is required.');
  }
  return request.auth.uid;
}

function requireAdmin(request) {
  const uid = requireAuth(request);
  if (request.auth.token.admin !== true) {
    throw new HttpsError('permission-denied', 'Administrator privileges are required.');
  }
  return uid;
}

function requireApprovedSeller(request) {
  const uid = requireAuth(request);
  if (request.auth.token.seller !== true || request.auth.token.sellerApproved !== true) {
    throw new HttpsError('permission-denied', 'An approved seller account is required.');
  }
  return uid;
}

function text(value, label, maxLength, { required = true } = {}) {
  if (typeof value !== 'string') {
    if (!required && (value === undefined || value === null)) return '';
    throw new HttpsError('invalid-argument', `${label} must be text.`);
  }
  const result = value.trim();
  if ((required && result.length === 0) || result.length > maxLength) {
    throw new HttpsError('invalid-argument', `${label} is invalid.`);
  }
  return result;
}

function enumValue(value, allowed, label) {
  if (!allowed.includes(value)) {
    throw new HttpsError('invalid-argument', `${label} is not supported.`);
  }
  return value;
}

function validStoreId(id) {
  return typeof id === 'string' && /^store-[A-Za-z0-9_-]{1,128}$/.test(id);
}

function validStorageUrl(imageUrl, storeId, folder) {
  if (!imageUrl) return true;
  try {
    const parsed = new URL(imageUrl);
    const decodedPath = decodeURIComponent(parsed.pathname);
    const bucketName = getStorage().bucket().name;
    return parsed.protocol === 'https:' &&
      parsed.hostname === 'firebasestorage.googleapis.com' &&
      decodedPath.includes(`/b/${bucketName}/o/stores/${storeId}/${folder}/`);
  } catch (_) {
    return false;
  }
}

async function recordAudit(actor, action, target) {
  await db.collection('auditEvents').add({
    actor,
    action,
    target,
    createdAt: FieldValue.serverTimestamp(),
  });
}

async function syncProductStoreStatus(storeId, fallbackStatus) {
  const storeRef = db.collection('stores').doc(storeId);
  const query = await db.collection('products').where('storeId', '==', storeId).get();
  for (let start = 0; start < query.docs.length; start += 400) {
    const products = query.docs.slice(start, start + 400);
    await db.runTransaction(async (transaction) => {
      const [storeSnapshot, productSnapshots] = await Promise.all([
        transaction.get(storeRef),
        transaction.getAll(...products.map((product) => product.ref)),
      ]);
      const status = storeSnapshot.exists ? storeSnapshot.data().status : fallbackStatus;
      for (const product of productSnapshots) {
        if (product.exists && product.data().storeId === storeId) {
          transaction.update(product.ref, {
            storeStatus: status,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }
      }
    });
  }
}

exports.registerMarketplaceUser = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireAuth(request);
  const authUser = await auth.getUser(uid);
  if (!authUser.email) {
    throw new HttpsError('failed-precondition', 'An email address is required.');
  }
  const username = text(request.data?.username, 'username', 24).toLowerCase();
  const name = text(request.data?.displayName, 'displayName', 100);
  const phone = text(request.data?.phone, 'phone', 32, { required: false });
  const role = enumValue(request.data?.role, ['customer', 'seller'], 'role');
  const storeName = text(request.data?.storeName, 'storeName', 100, { required: role === 'seller' });
  const categoryId = text(request.data?.storeCategoryId, 'storeCategoryId', 40, { required: false }) || 'home';
  const city = text(request.data?.storeCity, 'storeCity', 80, { required: false }) || 'Aden';
  const storeDescription = text(request.data?.storeDescription, 'storeDescription', 1000, { required: false });
  if (!USERNAME_PATTERN.test(username) || RESERVED_USERNAMES.has(username)) {
    throw new HttpsError('invalid-argument', 'Choose a valid username.', { errorCode: 'invalid_username' });
  }
  if (role === 'seller' && storeName.length < 2) {
    throw new HttpsError('invalid-argument', 'Choose a valid store name.', { errorCode: 'invalid_store' });
  }

  const userRef = db.collection('users').doc(uid);
  const usernameRef = db.collection('usernames').doc(username);
  const storeRef = db.collection('stores').doc(`store-${uid}`);
  const applicationRef = db.collection('sellerApplications').doc(uid);
  await db.runTransaction(async (transaction) => {
    const [profile, usernameDoc] = await Promise.all([
      transaction.get(userRef),
      transaction.get(usernameRef),
    ]);
    if (profile.exists) {
      const existing = profile.data();
      if (usernameDoc.exists && usernameDoc.data().uid === uid &&
          existing.username === username && existing.email === authUser.email.toLowerCase() &&
          existing.role === role) {
        return true;
      }
      throw new HttpsError('already-exists', 'Account profile already exists.');
    }
    if (usernameDoc.exists) {
      throw new HttpsError('already-exists', 'Username is already in use.', { errorCode: 'username_taken' });
    }
    const user = {
      username,
      email: authUser.email.toLowerCase(),
      displayName: name,
      phone,
      role,
      storeName: role === 'seller' ? storeName : '',
      storeCategoryId: role === 'seller' ? categoryId : 'home',
      storeCity: role === 'seller' ? city : 'Aden',
      storeDescription: role === 'seller' ? storeDescription : '',
      sellerApproved: false,
      sellerApplicationRejected: false,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };
    transaction.create(userRef, user);
    transaction.create(usernameRef, { uid, createdAt: FieldValue.serverTimestamp() });
    if (role === 'seller') {
      transaction.create(storeRef, {
        sellerId: uid,
        name: storeName,
        nameAr: storeName,
        description: storeDescription,
        descriptionAr: storeDescription,
        categoryId,
        city,
        logoUrl: '',
        coverUrl: '',
        rating: 0,
        reviewCount: 0,
        isVerified: false,
        status: 'pending',
        sellerApproved: false,
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp(),
      });
      transaction.create(applicationRef, {
        sellerId: uid,
        sellerName: name,
        storeName,
        categoryId,
        city,
        note: storeDescription,
        submittedAt: FieldValue.serverTimestamp(),
        status: 'pending',
      });
    }
  });

  return { ok: true };
});

exports.signInWithUsername = onCall({ enforceAppCheck: true }, async (request) => {
  const username = text(request.data?.username, 'username', 24).toLowerCase();
  const password = text(request.data?.password, 'password', 256);
  if (!USERNAME_PATTERN.test(username) || !webApiKey.value()) {
    throw new HttpsError('unauthenticated', 'Invalid username or password.');
  }
  try {
    const usernameDoc = await db.collection('usernames').doc(username).get();
    if (!usernameDoc.exists || typeof usernameDoc.data().uid !== 'string') {
      throw new Error('username not found');
    }
    const uid = usernameDoc.data().uid;
    const profile = await db.collection('users').doc(uid).get();
    if (!profile.exists || !profile.data().email) throw new Error('profile not found');
    const response = await fetch(
      `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${encodeURIComponent(webApiKey.value())}`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          email: profile.data().email,
          password,
          returnSecureToken: true,
        }),
      },
    );
    const result = await response.json();
    if (!response.ok || result.localId !== uid) throw new Error('password rejected');
    return { customToken: await auth.createCustomToken(uid) };
  } catch (_) {
    // A uniform response avoids disclosing whether a username exists.
    throw new HttpsError('unauthenticated', 'Invalid username or password.');
  }
});

exports.applyForSeller = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireAuth(request);
  const name = text(request.data?.storeName, 'storeName', 100);
  if (name.length < 2) throw new HttpsError('invalid-argument', 'Store name is too short.');
  const categoryId = text(request.data?.storeCategoryId, 'storeCategoryId', 40, { required: false }) || 'home';
  const city = text(request.data?.storeCity, 'storeCity', 80, { required: false }) || 'Aden';
  const description = text(request.data?.storeDescription, 'storeDescription', 1000, { required: false });
  const userRef = db.collection('users').doc(uid);
  const storeRef = db.collection('stores').doc(`store-${uid}`);
  const applicationRef = db.collection('sellerApplications').doc(uid);
  await db.runTransaction(async (transaction) => {
    const [userSnapshot, applicationSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(applicationRef),
    ]);
    if (!userSnapshot.exists) {
      throw new HttpsError('failed-precondition', 'A customer profile is required.');
    }
    const userData = userSnapshot.data();
    const applicationData = applicationSnapshot.exists ? applicationSnapshot.data() : null;
    const sameApplication = applicationData && applicationData.storeName === name &&
      applicationData.categoryId === categoryId && applicationData.city === city &&
      applicationData.note === description;
    if (userData.role === 'seller' && sameApplication &&
        ['pending', 'approved'].includes(applicationData.status)) {
      return true;
    }
    const canApply = userData.role === 'customer' ||
      (userData.role === 'seller' && userData.sellerApplicationRejected === true &&
        applicationData?.status === 'rejected');
    if (!canApply) {
      throw new HttpsError('failed-precondition', 'Only customers or previously rejected applicants may apply.');
    }
    if (applicationData && applicationData.status === 'pending') {
      throw new HttpsError('already-exists', 'A seller application is already pending.');
    }
    transaction.update(userRef, {
      role: 'seller',
      storeName: name,
      storeCategoryId: categoryId,
      storeCity: city,
      storeDescription: description,
      sellerApproved: false,
      sellerApplicationRejected: false,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.set(storeRef, {
      sellerId: uid,
      name,
      nameAr: name,
      description,
      descriptionAr: description,
      categoryId,
      city,
      logoUrl: '',
      coverUrl: '',
      rating: 0,
      reviewCount: 0,
      isVerified: false,
      sellerApproved: false,
      status: 'pending',
      createdAt: applicationSnapshot.exists
        ? applicationSnapshot.data().submittedAt
        : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
    transaction.set(applicationRef, {
      sellerId: uid,
      sellerName: userSnapshot.data().displayName || '',
      storeName: name,
      categoryId,
      city,
      note: description,
      submittedAt: FieldValue.serverTimestamp(),
      status: 'pending',
    });
  });
  return { ok: true };
});

exports.updateStoreProfile = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireApprovedSeller(request);
  const name = text(request.data?.name, 'name', 100);
  const description = text(request.data?.description, 'description', 1000, { required: false });
  const city = text(request.data?.city, 'city', 80, { required: false });
  const logoUrl = text(request.data?.logoUrl, 'logoUrl', 2000, { required: false });
  const coverUrl = text(request.data?.coverUrl, 'coverUrl', 2000, { required: false });
  const storeRef = db.collection('stores').doc(`store-${uid}`);
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (transaction) => {
    const store = await transaction.get(storeRef);
    const user = await transaction.get(userRef);
    if (!store.exists || store.data().sellerId !== uid || !user.exists) {
      throw new HttpsError('not-found', 'The owned store was not found.');
    }
    if (!validStorageUrl(logoUrl, storeRef.id, 'assets') ||
        !validStorageUrl(coverUrl, storeRef.id, 'assets')) {
      throw new HttpsError('invalid-argument', 'Store photos must be uploaded to your Shop Wave Storage folder.');
    }
    transaction.update(storeRef, {
      name,
      nameAr: name,
      description,
      descriptionAr: description,
      city: city || store.data().city || 'Aden',
      logoUrl: logoUrl || store.data().logoUrl || '',
      coverUrl: coverUrl || store.data().coverUrl || '',
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(userRef, {
      storeName: name,
      storeDescription: description,
      storeCity: city || store.data().city || 'Aden',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return { ok: true };
});

exports.setStoreAvailability = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireApprovedSeller(request);
  if (typeof request.data?.isOpen !== 'boolean') {
    throw new HttpsError('invalid-argument', 'isOpen must be a boolean.');
  }
  const storeRef = db.collection('stores').doc(`store-${uid}`);
  const status = request.data.isOpen ? 'active' : 'paused';
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(storeRef);
    if (!snapshot.exists || snapshot.data().sellerId !== uid || snapshot.data().sellerApproved !== true) {
      throw new HttpsError('permission-denied', 'The store is not approved for selling.');
    }
    if (!['active', 'paused'].includes(snapshot.data().status)) {
      throw new HttpsError('failed-precondition', 'A suspended store cannot change its availability.');
    }
    transaction.update(storeRef, { status, updatedAt: FieldValue.serverTimestamp() });
  });
  await syncProductStoreStatus(storeRef.id, status);
  return { ok: true, status };
});

exports.saveProduct = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireApprovedSeller(request);
  const name = text(request.data?.name, 'name', 120);
  const description = text(request.data?.description, 'description', 2000, { required: false });
  const categoryId = text(request.data?.categoryId, 'categoryId', 40);
  const price = Number(request.data?.price);
  const stockQuantity = Number(request.data?.stockQuantity);
  const isActive = request.data?.isActive === true;
  const imageUrl = text(request.data?.imageUrl, 'imageUrl', 2000, { required: false });
  if (!Number.isFinite(price) || price < 0 || price > 10000000 ||
      !Number.isInteger(stockQuantity) || stockQuantity < 0 || stockQuantity > MAX_STOCK) {
    throw new HttpsError('invalid-argument', 'Price or inventory is outside the accepted range.');
  }
  const storeRef = db.collection('stores').doc(`store-${uid}`);
  const userRef = db.collection('users').doc(uid);
  const storeSnapshot = await storeRef.get();
  const userSnapshot = await userRef.get();
  if (!storeSnapshot.exists || !userSnapshot.exists ||
      storeSnapshot.data().sellerId !== uid || storeSnapshot.data().sellerApproved !== true ||
      !['active', 'paused'].includes(storeSnapshot.data().status)) {
    throw new HttpsError('permission-denied', 'An approved owned store is required.');
  }
  if (!validStorageUrl(imageUrl, storeRef.id, 'products')) {
    throw new HttpsError('invalid-argument', 'Product images must be uploaded to your Shop Wave Storage folder.');
  }
  const productId = request.data?.productId
    ? text(request.data.productId, 'productId', 128)
    : db.collection('products').doc().id;
  const productRef = db.collection('products').doc(productId);
  await db.runTransaction(async (transaction) => {
    const [currentStore, existing] = await Promise.all([
      transaction.get(storeRef),
      transaction.get(productRef),
    ]);
    if (!currentStore.exists || currentStore.data().sellerId !== uid ||
        currentStore.data().sellerApproved !== true ||
        !['active', 'paused'].includes(currentStore.data().status)) {
      throw new HttpsError('permission-denied', 'The store is not currently approved.');
    }
    if (existing.exists && existing.data().sellerId !== uid) {
      throw new HttpsError('permission-denied', 'You cannot edit another seller\'s listing.');
    }
    const active = isActive && stockQuantity > 0;
    transaction.set(productRef, {
      name,
      nameAr: name,
      categoryId,
      categoryAr: '',
      price,
      imageUrl,
      description,
      descriptionAr: description,
      rating: existing.exists ? existing.data().rating || 0 : 0,
      storeId: storeRef.id,
      storeName: currentStore.data().name,
      storeNameAr: currentStore.data().nameAr || currentStore.data().name,
      sellerId: uid,
      sellerName: userSnapshot.data().displayName || '',
      sellerNameAr: userSnapshot.data().displayName || '',
      stockQuantity,
      isActive: active,
      storeStatus: currentStore.data().status,
      attributes: existing.exists ? existing.data().attributes || {} : {},
      createdAt: existing.exists ? existing.data().createdAt : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    }, { merge: true });
  });
  return { productId };
});

exports.reviewSellerApplication = onCall({ enforceAppCheck: true }, async (request) => {
  const adminUid = requireAdmin(request);
  const sellerId = text(request.data?.sellerId, 'sellerId', 128);
  const approve = request.data?.approve;
  if (typeof approve !== 'boolean') {
    throw new HttpsError('invalid-argument', 'approve must be a boolean.');
  }
  const applicationRef = db.collection('sellerApplications').doc(sellerId);
  const userRef = db.collection('users').doc(sellerId);
  const storeRef = db.collection('stores').doc(`store-${sellerId}`);
  const status = approve ? 'approved' : 'rejected';
  await db.runTransaction(async (transaction) => {
    const [application, user, store] = await Promise.all([
      transaction.get(applicationRef),
      transaction.get(userRef),
      transaction.get(storeRef),
    ]);
    if (!application.exists || application.data().status !== 'pending' ||
        !user.exists || !store.exists || store.data().sellerId !== sellerId) {
      throw new HttpsError('failed-precondition', 'This seller application is no longer pending.');
    }
    transaction.update(applicationRef, { status, reviewedBy: adminUid, reviewedAt: FieldValue.serverTimestamp() });
    transaction.update(userRef, {
      sellerApproved: approve,
      sellerApplicationRejected: !approve,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(storeRef, {
      sellerApproved: approve,
      isVerified: approve,
      status: approve ? 'active' : 'paused',
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  const existingClaims = (await auth.getUser(sellerId)).customClaims || {};
  await auth.setCustomUserClaims(sellerId, {
    ...existingClaims,
    seller: true,
    sellerApproved: approve,
  });
  if (approve) await syncProductStoreStatus(`store-${sellerId}`, 'active');
  await recordAudit(adminUid, `${approve ? 'approved' : 'rejected'} seller`, sellerId);
  return { ok: true, status };
});

exports.adminSetStoreStatus = onCall({ enforceAppCheck: true }, async (request) => {
  const adminUid = requireAdmin(request);
  const storeId = text(request.data?.storeId, 'storeId', 140);
  const suspended = request.data?.suspended;
  if (!validStoreId(storeId) || typeof suspended !== 'boolean') {
    throw new HttpsError('invalid-argument', 'Store status request is invalid.');
  }
  const storeRef = db.collection('stores').doc(storeId);
  const store = await storeRef.get();
  if (!store.exists || store.data().sellerApproved !== true) {
    throw new HttpsError('not-found', 'An approved store was not found.');
  }
  const status = suspended ? 'suspended' : 'active';
  await storeRef.update({ status, updatedAt: FieldValue.serverTimestamp() });
  await syncProductStoreStatus(storeId, status);
  await recordAudit(adminUid, suspended ? 'suspended store' : 'reactivated store', storeId);
  return { ok: true, status };
});

exports.adminSetProductVisibility = onCall({ enforceAppCheck: true }, async (request) => {
  const adminUid = requireAdmin(request);
  const productId = text(request.data?.productId, 'productId', 128);
  const visible = request.data?.visible;
  if (typeof visible !== 'boolean') {
    throw new HttpsError('invalid-argument', 'visible must be a boolean.');
  }
  const productRef = db.collection('products').doc(productId);
  const product = await productRef.get();
  if (!product.exists) throw new HttpsError('not-found', 'Product not found.');
  await productRef.update({ isActive: visible, updatedAt: FieldValue.serverTimestamp() });
  await recordAudit(adminUid, visible ? 'restored product' : 'hid product', productId);
  return { ok: true };
});

exports.createSandboxOrder = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireAuth(request);
  const userRef = db.collection('users').doc(uid);
  const rawItems = request.data?.items;
  const address = text(request.data?.deliveryAddress, 'deliveryAddress', 500);
  if (address.length < 5 || !Array.isArray(rawItems) || rawItems.length === 0 || rawItems.length > ORDER_LIMIT) {
    throw new HttpsError('invalid-argument', 'The cart or delivery address is invalid.');
  }
  const items = new Map();
  for (const item of rawItems) {
    const productId = text(item?.productId, 'productId', 128);
    const quantity = Number(item?.quantity);
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 99 || items.has(productId)) {
      throw new HttpsError('invalid-argument', 'The cart contains an invalid item or quantity.');
    }
    items.set(productId, quantity);
  }
  const requestId = text(request.data?.requestId, 'requestId', 64);
  if (!/^sw-[0-9a-f]{48}$/.test(requestId)) {
    throw new HttpsError('invalid-argument', 'The checkout request identifier is invalid.');
  }
  const orderRef = db.collection('orders').doc(requestId);
  const normalizedName = text(request.data?.customerName, 'customerName', 100, { required: false });
  const normalizedPhone = text(request.data?.customerPhone, 'customerPhone', 32, { required: false });
  const alreadyCreated = await db.runTransaction(async (transaction) => {
    const [existingOrder, userSnapshot] = await Promise.all([
      transaction.get(orderRef),
      transaction.get(userRef),
    ]);
    if (!userSnapshot.exists || userSnapshot.data().role !== 'customer') {
      throw new HttpsError('permission-denied', 'A customer account is required to check out.');
    }
    if (existingOrder.exists) {
      if (existingOrder.data().customerId !== uid) {
        throw new HttpsError('permission-denied', 'Checkout request identifier is already in use.');
      }
      return true;
    }
    const productRefs = [...items.keys()].map((id) => db.collection('products').doc(id));
    const productSnapshots = await transaction.getAll(...productRefs);
    const productById = new Map(productSnapshots.map((snapshot) => [snapshot.id, snapshot]));
    const storeIds = new Set();
    const enriched = [];
    for (const [productId, quantity] of items) {
      const product = productById.get(productId);
      if (!product || !product.exists) throw new HttpsError('failed-precondition', 'A product is no longer available.');
      const data = product.data();
      if (data.isActive !== true || !Number.isInteger(data.stockQuantity) ||
          data.stockQuantity < quantity || !validStoreId(data.storeId)) {
        throw new HttpsError('failed-precondition', 'A product is unavailable or has insufficient stock.');
      }
      storeIds.add(data.storeId);
      enriched.push({ productRef: product.ref, data, quantity });
    }
    const storeRefs = [...storeIds].map((id) => db.collection('stores').doc(id));
    const storeSnapshots = await transaction.getAll(...storeRefs);
    const stores = new Map(storeSnapshots.map((snapshot) => [snapshot.id, snapshot]));
    const groups = new Map();
    for (const item of enriched) {
      const store = stores.get(item.data.storeId);
      if (!store || !store.exists || store.data().status !== 'active' || store.data().sellerApproved !== true ||
          store.data().sellerId !== item.data.sellerId) {
        throw new HttpsError('failed-precondition', 'A store is closed or no longer approved.');
      }
      const line = {
        productId: item.productRef.id,
        productName: item.data.name || '',
        productNameAr: item.data.nameAr || item.data.name || '',
        imageUrl: item.data.imageUrl || '',
        storeId: item.data.storeId,
        sellerId: item.data.sellerId,
        unitPrice: Number(item.data.price),
        quantity: item.quantity,
      };
      if (!Number.isFinite(line.unitPrice) || line.unitPrice < 0) {
        throw new HttpsError('failed-precondition', 'A product has an invalid price.');
      }
      if (!groups.has(store.id)) groups.set(store.id, { store, lines: [] });
      groups.get(store.id).lines.push(line);
    }
    const now = Timestamp.now();
    const storeOrders = [];
    const sellerIds = [];
    for (const [storeId, group] of groups) {
      const childRef = db.collection('sellerOrders').doc();
      const child = {
        id: childRef.id,
        parentOrderId: orderRef.id,
        storeId,
        sellerId: group.store.data().sellerId,
        status: 'awaitingSeller',
        lines: group.lines,
        createdAt: now,
      };
      const childTotal = group.lines.reduce((sum, line) => sum + line.unitPrice * line.quantity, 0);
      storeOrders.push(child);
      sellerIds.push(child.sellerId);
      transaction.create(childRef, {
        orderId: orderRef.id,
        sellerId: child.sellerId,
        customerId: uid,
        customerName: normalizedName || userSnapshot.data().displayName || '',
        customerPhone: normalizedPhone || userSnapshot.data().phone || '',
        deliveryAddress: address,
        storeTotal: childTotal,
        storeOrder: child,
        createdAt: now,
      });
    }
    const total = storeOrders.reduce((sum, child) =>
      sum + child.lines.reduce((childSum, line) => childSum + line.unitPrice * line.quantity, 0), 0);
    const itemCount = storeOrders.reduce((sum, child) =>
      sum + child.lines.reduce((childSum, line) => childSum + line.quantity, 0), 0);
    transaction.create(orderRef, {
      customerId: uid,
      customerName: normalizedName || userSnapshot.data().displayName || '',
      customerPhone: normalizedPhone || userSnapshot.data().phone || '',
      deliveryAddress: address,
      status: 'awaitingSeller',
      paymentStatus: 'sandboxApproved',
      paymentMode: 'demo_only',
      total,
      itemCount,
      sellerIds,
      storeOrders,
      createdAt: FieldValue.serverTimestamp(),
    });
    for (const item of enriched) {
      transaction.update(item.productRef, {
        stockQuantity: Number(item.data.stockQuantity) - item.quantity,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
    return false;
  });
  return {
    orderId: orderRef.id,
    paymentMode: 'demo_only',
    alreadyCreated,
  };
});

exports.transitionStoreOrder = onCall({ enforceAppCheck: true }, async (request) => {
  const uid = requireAuth(request);
  const orderId = text(request.data?.orderId, 'orderId', 128);
  const storeOrderId = text(request.data?.storeOrderId, 'storeOrderId', 128);
  const action = enumValue(request.data?.action, ['advance', 'cancel'], 'action');
  const parentRef = db.collection('orders').doc(orderId);
  const childRef = db.collection('sellerOrders').doc(storeOrderId);
  let auditAction = '';
  const affectedSeller = { id: '', status: '' };
  await db.runTransaction(async (transaction) => {
    const [parentSnapshot, childSnapshot, userSnapshot] = await Promise.all([
      transaction.get(parentRef),
      transaction.get(childRef),
      transaction.get(db.collection('users').doc(uid)),
    ]);
    if (!parentSnapshot.exists || !childSnapshot.exists || !userSnapshot.exists) {
      throw new HttpsError('not-found', 'Order was not found.');
    }
    const parent = parentSnapshot.data();
    const childData = childSnapshot.data();
    const child = childData.storeOrder;
    if (!child || child.id !== storeOrderId || child.parentOrderId !== orderId || childData.orderId !== orderId) {
      throw new HttpsError('permission-denied', 'Order scope does not match.');
    }
    const isCustomerCancel = action === 'cancel' && userSnapshot.data().role === 'customer' && parent.customerId === uid;
    const isSellerAdvance = action === 'advance' && request.auth.token.seller === true &&
      request.auth.token.sellerApproved === true && child.sellerId === uid;
    if (!isCustomerCancel && !isSellerAdvance) {
      throw new HttpsError('permission-denied', 'This account cannot update this order.');
    }
    let nextStatus;
    if (isCustomerCancel) {
      if (!['awaitingSeller', 'accepted'].includes(child.status)) {
        throw new HttpsError('failed-precondition', 'This order can no longer be cancelled.');
      }
      nextStatus = 'cancelled';
      auditAction = 'customer cancelled order';
    } else {
      const transitions = {
        awaitingSeller: 'accepted',
        accepted: 'preparing',
        preparing: 'ready',
        ready: 'completed',
      };
      nextStatus = transitions[child.status];
      if (!nextStatus) throw new HttpsError('failed-precondition', 'This order cannot advance to another status.');
      auditAction = `seller advanced order to ${nextStatus}`;
    }
    affectedSeller.id = child.sellerId;
    affectedSeller.status = nextStatus;
    const updatedChild = { ...child, status: nextStatus, updatedAt: Timestamp.now() };
    const updatedChildren = (Array.isArray(parent.storeOrders) ? parent.storeOrders : []).map((entry) =>
      entry.id === storeOrderId ? updatedChild : entry);
    if (!updatedChildren.some((entry) => entry.id === storeOrderId)) {
      throw new HttpsError('failed-precondition', 'The parent order is inconsistent.');
    }
    const isFullyComplete = updatedChildren.every((entry) => entry.status === 'completed');
    const isFullyCancelled = updatedChildren.every((entry) => ['cancelled', 'declined'].includes(entry.status));
    const parentStatus = isFullyComplete
      ? 'completed'
      : isFullyCancelled
        ? 'cancelled'
        : 'inProgress';
    let productSnapshots = [];
    if (isCustomerCancel) {
      const productIds = [...new Set(child.lines.map((line) => line.productId))];
      const productRefs = productIds.map((id) => db.collection('products').doc(id));
      productSnapshots = await transaction.getAll(...productRefs);
    }
    transaction.update(parentRef, {
      storeOrders: updatedChildren,
      status: parentStatus,
      updatedAt: FieldValue.serverTimestamp(),
    });
    transaction.update(childRef, {
      'storeOrder.status': nextStatus,
      'storeOrder.updatedAt': Timestamp.now(),
      updatedAt: FieldValue.serverTimestamp(),
    });
    for (const product of productSnapshots) {
      if (!product.exists) continue;
      const quantity = child.lines
        .filter((line) => line.productId === product.id)
        .reduce((sum, line) => sum + Number(line.quantity), 0);
      transaction.update(product.ref, {
        stockQuantity: Number(product.data().stockQuantity || 0) + quantity,
        updatedAt: FieldValue.serverTimestamp(),
      });
    }
  });
  if (request.auth.token.admin === true) {
    await recordAudit(uid, auditAction, orderId);
  }
  return { ok: true, sellerId: affectedSeller.id, status: affectedSeller.status };
});

