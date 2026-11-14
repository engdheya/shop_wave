const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');
const assert = require('node:assert/strict');
const {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} = require('@firebase/rules-unit-testing');
const {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require('firebase/firestore');
const { ref, uploadBytes } = require('firebase/storage');

let testEnv;

test.before(async () => {
  testEnv = await initializeTestEnvironment({
    projectId: 'shop-wave-rules-test',
    firestore: {
      rules: fs.readFileSync(path.join(__dirname, '../../firestore.rules'), 'utf8'),
    },
    storage: {
      rules: fs.readFileSync(path.join(__dirname, '../../storage.rules'), 'utf8'),
    },
  });
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const database = context.firestore();
    await setDoc(doc(database, 'users/customer-1'), {
      role: 'customer',
      displayName: 'Customer One',
    });
    await setDoc(doc(database, 'users/seller-1'), {
      role: 'seller',
      sellerApproved: true,
    });
    await setDoc(doc(database, 'stores/store-seller-1'), {
      sellerId: 'seller-1',
      sellerApproved: true,
      status: 'active',
    });
    await setDoc(doc(database, 'stores/store-pending-seller'), {
      sellerId: 'pending-seller',
      sellerApproved: false,
      status: 'pending',
    });
    await setDoc(doc(database, 'products/visible-product'), {
      sellerId: 'seller-1',
      storeId: 'store-seller-1',
      isActive: true,
      storeStatus: 'active',
    });
    await setDoc(doc(database, 'products/hidden-product'), {
      sellerId: 'seller-1',
      storeId: 'store-seller-1',
      isActive: false,
      storeStatus: 'active',
    });
    await setDoc(doc(database, 'orders/customer-order'), {
      customerId: 'customer-1',
      sellerIds: ['seller-1'],
    });
    await setDoc(doc(database, 'orders/other-order'), {
      customerId: 'customer-2',
      sellerIds: ['seller-1'],
    });
    await setDoc(doc(database, 'sellerOrders/seller-child'), {
      orderId: 'other-order',
      sellerId: 'seller-1',
    });
    await setDoc(doc(database, 'usernames/ordinary-user'), { uid: 'customer-1' });
  });
});

test.after(async () => {
  await testEnv?.cleanup();
});

test('public reads are limited to active marketplace products and stores', async () => {
  const visitorDb = testEnv.unauthenticatedContext().firestore();
  await assertSucceeds(getDoc(doc(visitorDb, 'products/visible-product')));
  await assertFails(getDoc(doc(visitorDb, 'products/hidden-product')));
  await assertSucceeds(getDoc(doc(visitorDb, 'stores/store-seller-1')));
  await assertFails(getDoc(doc(visitorDb, 'stores/store-pending-seller')));
});

test('clients cannot write profiles, username claims, products, or orders', async () => {
  const customerDb = testEnv.authenticatedContext('customer-1').firestore();
  await assertFails(updateDoc(doc(customerDb, 'users/customer-1'), { role: 'admin' }));
  await assertFails(setDoc(doc(customerDb, 'usernames/taken'), { uid: 'customer-1' }));
  await assertFails(setDoc(doc(customerDb, 'products/forged'), { isActive: true }));
  await assertFails(setDoc(doc(customerDb, 'orders/forged'), { customerId: 'customer-1' }));
});

test('customers and sellers receive disjoint order scopes', async () => {
  const customerDb = testEnv.authenticatedContext('customer-1').firestore();
  const sellerDb = testEnv.authenticatedContext('seller-1', {
    seller: true,
    sellerApproved: true,
  }).firestore();

  await assertSucceeds(getDoc(doc(customerDb, 'orders/customer-order')));
  await assertFails(getDoc(doc(customerDb, 'orders/other-order')));
  await assertFails(getDoc(doc(sellerDb, 'orders/other-order')));
  await assertSucceeds(getDoc(doc(sellerDb, 'sellerOrders/seller-child')));
  await assertFails(getDoc(doc(testEnv.authenticatedContext('seller-2', {
    seller: true,
    sellerApproved: true,
  }).firestore(), 'sellerOrders/seller-child')));
});

test('only an admin claim can read the global application and audit queues', async () => {
  const customerDb = testEnv.authenticatedContext('customer-1').firestore();
  const adminDb = testEnv.authenticatedContext('admin-1', { admin: true }).firestore();
  await assertFails(getDocs(collection(customerDb, 'sellerApplications')));
  await assertSucceeds(getDocs(collection(adminDb, 'sellerApplications')));
  await assertSucceeds(getDocs(collection(adminDb, 'auditEvents')));
});

test('Storage uploads require an approved owner and image metadata/size', async () => {
  const sellerStorage = testEnv.authenticatedContext('seller-1', {
    seller: true,
    sellerApproved: true,
  }).storage();
  const pendingStorage = testEnv.authenticatedContext('pending-seller', {
    seller: true,
    sellerApproved: false,
  }).storage();
  const tinyJpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
  await assertSucceeds(uploadBytes(
    ref(sellerStorage, 'stores/store-seller-1/products/image.jpg'),
    tinyJpeg,
    { contentType: 'image/jpeg' },
  ));
  await assertFails(uploadBytes(
    ref(sellerStorage, 'stores/store-other/products/image.jpg'),
    tinyJpeg,
    { contentType: 'image/jpeg' },
  ));
  await assertFails(uploadBytes(
    ref(pendingStorage, 'stores/store-pending-seller/products/image.jpg'),
    tinyJpeg,
    { contentType: 'image/jpeg' },
  ));
  await assertFails(uploadBytes(
    ref(sellerStorage, 'stores/store-seller-1/products/script.svg'),
    tinyJpeg,
    { contentType: 'image/svg+xml' },
  ));
});
