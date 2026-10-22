const { getFirebaseAdmin, requireUser } = require('../server/auth');
const { applyCors, readBody } = require('../server/http');

const SUPER_ADMIN_EMAILS = [
  'adhirajjain364@gmail.com',
  'mayankjaisw8673@gmail.com',
  'suhanimahajan2810@gmail.com',
  'majumdarpayal50@gmail.com',
  'reshob.rc12345@gmail.com',
];
const ADMIN_ROLES = ['admin', 'manager', 'super_admin'];

/**
 * POST /api/suspend-user
 * Body: { uid, level: 0|1|2|3, reason: string, immediate?: boolean }
 *
 * Suspending a user must actually stop them from using the platform, not
 * just hide the UI behind a blocking screen. This disables their Firebase
 * Auth account (so sign-in fails immediately with auth/user-disabled) and
 * revokes any already-issued ID tokens (so an app session open at the time
 * of suspension cannot keep calling this API or Firestore either), then
 * records the state on their profile for the UI to read.
 *
 * This is deliberately a different code path from account deletion
 * (auth_remote_data_source.dart's deleteAccount): suspension disables the
 * existing account and keeps its data so it can be reinstated, while
 * deletion permanently removes the Auth user and Firestore data outright.
 */
module.exports = async (req, res) => {
  if (applyCors(req, res)) return;
  if (req.method !== 'POST') return res.status(405).json({ error: 'Method Not Allowed' });

  try {
    const caller = await requireUser(req, res);
    if (!caller) return;

    const body = readBody(req);
    const targetUid = typeof body.uid === 'string' ? body.uid.trim() : '';
    const level = Number(body.level);
    const reason = typeof body.reason === 'string' ? body.reason.trim() : '';
    const immediate = body.immediate === true;
    if (!targetUid) return res.status(400).json({ error: 'uid is required' });
    if (![0, 1, 2, 3].includes(level)) {
      return res.status(400).json({ error: 'level must be 0, 1, 2, or 3' });
    }
    if (level > 0 && !reason) {
      return res.status(400).json({ error: 'A reason is required' });
    }
    if (immediate && level !== 3) {
      return res.status(400).json({ error: 'Immediate suspension requires level 3' });
    }

    const admin = getFirebaseAdmin();
    const firestore = admin.firestore();
    const { FieldValue } = admin.firestore;

    const [callerSnapshot, targetSnapshot] = await Promise.all([
      firestore.collection('users').doc(caller.uid).get(),
      firestore.collection('users').doc(targetUid).get(),
    ]);

    const callerRole = String(callerSnapshot.exists ? callerSnapshot.data().role || '' : '').toLowerCase();
    const isAdmin = ADMIN_ROLES.includes(callerRole) ||
      (caller.email_verified === true && SUPER_ADMIN_EMAILS.includes(String(caller.email || '').toLowerCase()));
    if (!isAdmin) return res.status(403).json({ error: 'Only admins can suspend or reinstate users' });

    if (!targetSnapshot.exists) return res.status(404).json({ error: 'User not found' });
    if (targetUid === caller.uid) return res.status(400).json({ error: 'You cannot suspend your own account' });

    const targetRole = String(targetSnapshot.data().role || '').toLowerCase();
    const targetEmail = String(targetSnapshot.data().email || '').toLowerCase();
    const targetIsAdmin = ADMIN_ROLES.includes(targetRole) || SUPER_ADMIN_EMAILS.includes(targetEmail);
    if (level > 0 && targetIsAdmin) {
      return res.status(400).json({ error: 'Admins and managers cannot be suspended here' });
    }

    const isCreator = ['creator', 'seller'].includes(targetRole);
    if ((level === 1 || level === 2) && !isCreator) {
      return res.status(400).json({ error: 'Warning stages are only available for creators' });
    }

    const currentLevel = Number(targetSnapshot.data().creatorModerationLevel || 0);
    if (isCreator && level > 0 && !immediate && level !== Math.min(currentLevel + 1, 3)) {
      return res.status(409).json({ error: 'Creator warnings must be sent in order' });
    }

    const finalSuspension = level === 3;
    await admin.auth().updateUser(targetUid, { disabled: finalSuspension });
    if (finalSuspension) {
      // Invalidate any ID token already in the suspended user's hands so an
      // open app session is cut off immediately, not just future sign-ins.
      await admin.auth().revokeRefreshTokens(targetUid);
    }

    const userUpdate = {
      isSuspended: finalSuspension,
      creatorModerationLevel: level,
      creatorModerationReason: level === 0 ? FieldValue.delete() : reason,
      creatorModerationIssuedAt: level === 0
        ? FieldValue.delete()
        : FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    };

    await firestore.collection('users').doc(targetUid).update(userUpdate);

    if (isCreator) {
      const profileRef = firestore.collection('creator_profiles').doc(targetUid);
      const profileSnapshot = await profileRef.get();
      if (profileSnapshot.exists) {
        await profileRef.update({
          isStorefrontVisible: level < 2,
          moderationLevel: level,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      if (level >= 2) {
        const productDocs = new Map();
        for (const field of ['creatorUid', 'creatorId']) {
          const snapshot = await firestore.collection('products')
            .where(field, '==', targetUid)
            .get();
          snapshot.docs.forEach((doc) => productDocs.set(doc.ref.path, doc.ref));
        }
        const references = [...productDocs.values()];
        for (let start = 0; start < references.length; start += 450) {
          const batch = firestore.batch();
          references.slice(start, start + 450).forEach((reference) => {
            batch.update(reference, {
              isActive: false,
              updatedAt: FieldValue.serverTimestamp(),
            });
          });
          await batch.commit();
        }
      }
    }

    return res.status(200).json({ success: true, level, immediate });
  } catch (error) {
    console.error('Suspend user error:', error.message || error);
    if (error.code === 'auth/user-not-found') {
      return res.status(404).json({ error: 'User not found' });
    }
    return res.status(500).json({ error: 'Could not update this user. Please try again.' });
  }
};
