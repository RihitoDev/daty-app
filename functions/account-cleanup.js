const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue} = require("firebase-admin/firestore");
const {getStorage} = require("firebase-admin/storage");

const REGION = "us-central1";
const INCOMPLETE_ACCOUNT_MAX_AGE_MS = 24 * 60 * 60 * 1000;
function requireUser(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

async function deleteSnapshot(snapshot) {
  if (snapshot.empty) return;
  const writer = getFirestore().bulkWriter();
  snapshot.docs.forEach((document) => writer.delete(document.ref));
  await writer.close();
}

async function deleteQuery(collection, field, value) {
  const db = getFirestore();
  while (true) {
    const snapshot = await db.collection(collection)
        .where(field, "==", value)
        .limit(400)
        .get();
    if (snapshot.empty) return;
    await deleteSnapshot(snapshot);
  }
}

async function removeFromGroups(uid) {
  const db = getFirestore();
  const snapshot = await db.collection("groups")
      .where("members", "array-contains", uid)
      .get();

  for (const document of snapshot.docs) {
    await db.runTransaction(async (transaction) => {
      const current = await transaction.get(document.ref);
      if (!current.exists) return;
      const data = current.data();
      const members = Array.isArray(data.members) ? data.members : [];
      const remaining = members.filter((member) => member !== uid);
      if (remaining.length === 0) {
        transaction.delete(document.ref);
        return;
      }
      const update = {members: remaining};
      if (data.creatorId === uid) update.creatorId = remaining[0];
      transaction.update(document.ref, update);
    });
  }
}

async function removeFromGroupMemories(uid) {
  const db = getFirestore();
  const snapshot = await db.collection("group_memories")
      .where("members", "array-contains", uid)
      .get();
  if (snapshot.empty) return;

  const writer = db.bulkWriter();
  snapshot.docs.forEach((document) => {
    const data = document.data();
    const members = Array.isArray(data.members) ? data.members : [];
    const remaining = members.filter((member) => member !== uid);
    if (remaining.length === 0) {
      writer.delete(document.ref);
    } else {
      writer.update(document.ref, {
        members: remaining,
        savedBy: FieldValue.arrayRemove(uid),
        [`photos.${uid}`]: FieldValue.delete(),
      });
    }
  });
  await writer.close();
}

async function unlinkCouple(uid, userData) {
  const partnerId = userData?.partnerId;
  if (typeof partnerId !== "string" || partnerId.length === 0) return;

  const db = getFirestore();
  const partnerRef = db.collection("users").doc(partnerId);
  const coupleId = uid.localeCompare(partnerId) < 0 ?
    `${uid}_${partnerId}` : `${partnerId}_${uid}`;
  const coupleRef = db.collection("couples_progress").doc(coupleId);

  await db.runTransaction(async (transaction) => {
    const partner = await transaction.get(partnerRef);
    if (partner.exists && partner.get("partnerId") === uid) {
      transaction.update(partnerRef, {partnerId: null});
    }
    transaction.delete(coupleRef);
  });
  await deleteQuery("memories", "coupleDocId", coupleId);
}

async function deleteStorageForUser(uid) {
  const bucket = getStorage().bucket();
  await Promise.all([
    bucket.deleteFiles({prefix: `memories/${uid}/`, force: true}),
    bucket.deleteFiles({prefix: `profiles/${uid}/`, force: true}),
  ]);
}

async function deleteUserData(uid, {deleteAuthUser = true} = {}) {
  const db = getFirestore();
  const userRef = db.collection("users").doc(uid);
  const userSnapshot = await userRef.get();
  const userData = userSnapshot.data();

  await unlinkCouple(uid, userData);
  await Promise.all([
    deleteQuery("usernames", "uid", uid),
    deleteQuery("solo_memories", "userId", uid),
    deleteQuery("pairInvites", "ownerId", uid),
    removeFromGroups(uid),
    removeFromGroupMemories(uid),
    deleteStorageForUser(uid),
  ]);

  await Promise.all([
    db.collection("solo_progress").doc(uid).delete(),
    db.collection("pairInviteOwners").doc(uid).delete(),
    db.collection("emailVerificationCodes").doc(uid).delete(),
    userRef.delete(),
  ]);

  if (deleteAuthUser) {
    try {
      await getAuth().deleteUser(uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
  }
}

exports.deleteMyAccount = onCall(
    {region: REGION, timeoutSeconds: 540, memory: "512MiB"},
    async (request) => {
      const uid = requireUser(request);
      try {
        await deleteUserData(uid);
        return {deleted: true};
      } catch (error) {
        logger.error("No se pudo eliminar la cuenta", {uid, error});
        throw new HttpsError(
            "internal",
            "No se pudo completar la eliminación. Inténtalo nuevamente.",
        );
      }
    },
);

exports.cleanupIncompleteAccounts = onSchedule(
    {
      region: REGION,
      schedule: "every 6 hours",
      timeoutSeconds: 540,
      memory: "512MiB",
      maxInstances: 1,
    },
    async () => {
      const auth = getAuth();
      const db = getFirestore();
      const cutoff = Date.now() - INCOMPLETE_ACCOUNT_MAX_AGE_MS;
      let pageToken;
      let deleted = 0;

      do {
        const page = await auth.listUsers(500, pageToken);
        for (const user of page.users) {
          const createdAt = Date.parse(user.metadata.creationTime);
          if (!Number.isFinite(createdAt) || createdAt > cutoff) continue;

          const profile = await db.collection("users").doc(user.uid).get();
          const username = profile.exists ? profile.get("username") : null;
          if (profile.exists && typeof username === "string" &&
              username.trim().length > 0) {
            continue;
          }

          try {
            await deleteUserData(user.uid);
            deleted += 1;
          } catch (error) {
            logger.error("Fallo al limpiar cuenta incompleta", {
              uid: user.uid,
              error,
            });
          }
        }
        pageToken = page.pageToken;
      } while (pageToken);

      logger.info("Limpieza de cuentas incompletas finalizada", {deleted});
    },
);

exports.deleteUserData = deleteUserData;
