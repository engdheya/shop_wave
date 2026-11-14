const { initializeApp, applicationDefault } = require('firebase-admin/app');
const { getAuth } = require('firebase-admin/auth');
const { getFirestore } = require('firebase-admin/firestore');

async function main() {
  const projectId = process.env.GOOGLE_CLOUD_PROJECT || process.env.GCLOUD_PROJECT;
  const uid = process.env.ADMIN_UID;
  const email = process.env.ADMIN_EMAIL;
  if (!projectId || (!uid && !email) || (uid && email)) {
    throw new Error('Set GOOGLE_CLOUD_PROJECT and exactly one of ADMIN_UID or ADMIN_EMAIL.');
  }
  initializeApp({ credential: applicationDefault(), projectId });
  const auth = getAuth();
  const user = uid ? await auth.getUser(uid) : await auth.getUserByEmail(email);
  const profile = await getFirestore().collection('users').doc(user.uid).get();
  if (!profile.exists) {
    throw new Error('The Firebase Auth user must first register a Shop Wave account.');
  }
  const claims = user.customClaims || {};
  await auth.setCustomUserClaims(user.uid, { ...claims, admin: true });
  console.log(`Granted the admin custom claim to ${user.uid} in ${projectId}.`);
  console.log('The user must sign out and sign in again (or refresh the ID token) before admin screens appear.');
}

main().catch((error) => {
  console.error(error.message);
  process.exitCode = 1;
});
