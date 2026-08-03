const {randomInt} = require("node:crypto");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {initializeApp} = require("firebase-admin/app");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");

initializeApp();

const db = getFirestore();
const REGION = "us-central1";
const INVITE_DURATION_MS = 15 * 60 * 1000;
const RETENTION_MS = 24 * 60 * 60 * 1000;
const CODE_LETTERS = "ABCDEFGHJKLMNPQRTUVWXYZ";
const CODE_ATTEMPTS = 12;

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

function generateCode() {
  let letters = "";
  let numbers = "";

  for (let index = 0; index < 3; index += 1) {
    letters += CODE_LETTERS[randomInt(CODE_LETTERS.length)];
    numbers += randomInt(10).toString();
  }

  return `${letters}${numbers}`;
}

function invitationResponse(code, expiresAt) {
  return {
    code,
    expiresAtMillis: expiresAt.toMillis(),
  };
}

exports.createPairInvitation = onCall(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);

      for (let attempt = 0; attempt < CODE_ATTEMPTS; attempt += 1) {
        const candidate = generateCode();
        const result = await db.runTransaction(async (transaction) => {
          const now = Timestamp.now();
          const userRef = db.collection("users").doc(uid);
          const ownerRef = db.collection("pairInviteOwners").doc(uid);
          const candidateRef = db.collection("pairInvites").doc(candidate);

          const userSnapshot = await transaction.get(userRef);
          const ownerSnapshot = await transaction.get(ownerRef);

          if (!userSnapshot.exists) {
            throw new HttpsError("failed-precondition", "Perfil no encontrado.");
          }
          if (userSnapshot.get("partnerId")) {
            throw new HttpsError(
                "failed-precondition",
                "Ya estás vinculado con otra persona.",
                {reason: "already-linked"},
            );
          }

          const existingCode = ownerSnapshot.get("code");
          if (typeof existingCode === "string") {
            const existingRef = db.collection("pairInvites").doc(existingCode);
            const existingSnapshot = await transaction.get(existingRef);
            const existingExpiry = existingSnapshot.get("expiresAt");

            if (
              existingSnapshot.exists &&
              existingSnapshot.get("ownerId") === uid &&
              existingSnapshot.get("status") === "pending" &&
              existingExpiry instanceof Timestamp &&
              existingExpiry.toMillis() > now.toMillis()
            ) {
              return invitationResponse(existingCode, existingExpiry);
            }
          }

          const candidateSnapshot = await transaction.get(candidateRef);
          if (candidateSnapshot.exists) return null;

          const expiresAt = Timestamp.fromMillis(
              now.toMillis() + INVITE_DURATION_MS,
          );
          const cleanupAt = Timestamp.fromMillis(
              expiresAt.toMillis() + RETENTION_MS,
          );

          transaction.set(candidateRef, {
            ownerId: uid,
            status: "pending",
            createdAt: now,
            expiresAt,
            cleanupAt,
          });
          transaction.set(ownerRef, {
            code: candidate,
            updatedAt: now,
          });

          return invitationResponse(candidate, expiresAt);
        });

        if (result !== null) return result;
      }

      throw new HttpsError(
          "resource-exhausted",
          "No se pudo generar el código. Inténtalo nuevamente.",
      );
    },
);

exports.getPairInvitationStatus = onCall(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);
      const code = String(request.data?.code ?? "").trim().toUpperCase();

      if (!/^[A-Z]{3}[0-9]{3}$/.test(code)) {
        throw new HttpsError(
            "invalid-argument",
            "El código debe tener tres letras y tres números.",
        );
      }

      const inviteSnapshot =
        await db.collection("pairInvites").doc(code).get();
      if (!inviteSnapshot.exists) return {status: "invalid"};

      const invite = inviteSnapshot.data();
      if (invite.ownerId === uid) return {status: "own-code"};
      if (invite.status === "used") return {status: "used"};
      if (invite.status === "cancelled") return {status: "cancelled"};
      if (invite.status !== "pending") return {status: "unavailable"};

      const expiresAt = invite.expiresAt;
      if (
        !(expiresAt instanceof Timestamp) ||
        expiresAt.toMillis() <= Date.now()
      ) {
        return {status: "expired"};
      }

      return {status: "available"};
    },
);

exports.acceptPairInvitation = onCall(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);
      const code = String(request.data?.code ?? "").trim().toUpperCase();

      if (!/^[A-Z]{3}[0-9]{3}$/.test(code)) {
        throw new HttpsError(
            "invalid-argument",
            "El código debe tener tres letras y tres números.",
        );
      }

      return db.runTransaction(async (transaction) => {
        const now = Timestamp.now();
        const inviteRef = db.collection("pairInvites").doc(code);
        const inviteSnapshot = await transaction.get(inviteRef);

        if (!inviteSnapshot.exists) {
          throw new HttpsError("not-found", "El código no existe.");
        }

        const invite = inviteSnapshot.data();
        const ownerId = invite.ownerId;
        const expiresAt = invite.expiresAt;

        if (ownerId === uid) {
          throw new HttpsError(
              "failed-precondition",
              "No puedes utilizar tu propio código.",
              {reason: "own-code"},
          );
        }
        if (invite.status !== "pending") {
          throw new HttpsError(
              "already-exists",
              "Esta invitación ya fue utilizada.",
          );
        }
        if (
          !(expiresAt instanceof Timestamp) ||
          expiresAt.toMillis() <= now.toMillis()
        ) {
          throw new HttpsError(
              "deadline-exceeded",
              "La invitación ha vencido.",
          );
        }

        const myRef = db.collection("users").doc(uid);
        const ownerUserRef = db.collection("users").doc(ownerId);
        const ownerPointerRef =
            db.collection("pairInviteOwners").doc(ownerId);
        const myPointerRef = db.collection("pairInviteOwners").doc(uid);
        const coupleId =
            uid < ownerId ? `${uid}_${ownerId}` : `${ownerId}_${uid}`;
        const coupleRef = db.collection("couples_progress").doc(coupleId);

        const [
          mySnapshot,
          ownerUserSnapshot,
          coupleSnapshot,
          myPointerSnapshot,
        ] =
            await Promise.all([
              transaction.get(myRef),
              transaction.get(ownerUserRef),
              transaction.get(coupleRef),
              transaction.get(myPointerRef),
            ]);

        const myActiveCode = myPointerSnapshot.get("code");
        const myInviteRef = typeof myActiveCode === "string" ?
          db.collection("pairInvites").doc(myActiveCode) :
          null;
        const myInviteSnapshot = myInviteRef === null ?
          null :
          await transaction.get(myInviteRef);

        if (!mySnapshot.exists || !ownerUserSnapshot.exists) {
          throw new HttpsError(
              "failed-precondition",
              "No se pudo validar a los usuarios.",
          );
        }
        if (mySnapshot.get("partnerId")) {
          throw new HttpsError(
              "failed-precondition",
              "Ya estás vinculado con otra persona.",
              {reason: "already-linked"},
          );
        }
        if (ownerUserSnapshot.get("partnerId")) {
          throw new HttpsError(
              "failed-precondition",
              "La otra persona ya está vinculada.",
              {reason: "owner-linked"},
          );
        }
        const user1 = uid < ownerId ? uid : ownerId;
        const user2 = uid < ownerId ? ownerId : uid;

        const isUser1 = uid === user1;

        if (coupleSnapshot.exists && coupleSnapshot.get("unlinkingState") === "paused") {
          const recoveryEnd = coupleSnapshot.get("recoveryWindowEnd");
          if (recoveryEnd instanceof Timestamp && recoveryEnd.toMillis() > now.toMillis()) {
            transaction.update(coupleRef, {
              reconciliationStatus: "pending",
              reconciliationRequestedBy: uid,
              reconciliationRequestedAt: now,
              contractSignedUser1: false,
              contractSignedUser2: false,
              [isUser1 ? "reconciliationSignedUser1" : "reconciliationSignedUser2"]: true,
            });
            transaction.update(myRef, {partnerId: ownerId});
            transaction.update(ownerUserRef, {partnerId: uid});
            transaction.update(inviteRef, {
              status: "used",
              usedAt: now,
              usedBy: uid,
            });
            if (myPointerSnapshot.exists) {
              transaction.delete(myPointerRef);
            }
            if (myInviteRef !== null && myInviteSnapshot?.exists && myInviteSnapshot.get("ownerId") === uid && myInviteSnapshot.get("status") === "pending") {
              transaction.update(myInviteRef, {
                status: "cancelled",
                cancelledAt: now,
              });
            }
            return {coupleId, reconciliationTriggered: true};
          }
        }

        // Finalizamos cualquier periodo de gracia pausado anterior para ambos usuarios
        const [
          oldPaused1, oldPaused2, oldPaused3, oldPaused4,
          oldPaused5, oldPaused6, oldPaused7, oldPaused8,
        ] = await Promise.all([
          db.collection("couples_progress").where("user1Id", "==", uid).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user2Id", "==", uid).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user1", "==", uid).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user2", "==", uid).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user1Id", "==", ownerId).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user2Id", "==", ownerId).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user1", "==", ownerId).where("unlinkingState", "==", "paused").get(),
          db.collection("couples_progress").where("user2", "==", ownerId).where("unlinkingState", "==", "paused").get(),
        ]);

        const oldDocMap = new Map();
        [
          ...oldPaused1.docs, ...oldPaused2.docs, ...oldPaused3.docs, ...oldPaused4.docs,
          ...oldPaused5.docs, ...oldPaused6.docs, ...oldPaused7.docs, ...oldPaused8.docs,
        ].forEach((doc) => oldDocMap.set(doc.id, doc));

        const SevenDaysMillis = 7 * 24 * 60 * 60 * 1000;
        const preservationEndTimestamp = Timestamp.fromMillis(now.toMillis() + SevenDaysMillis);

        for (const oldDoc of oldDocMap.values()) {
          if (oldDoc.id !== coupleId) {
            transaction.update(oldDoc.ref, {
              unlinkingState: "finalized",
              recoveryWindowEnd: FieldValue.delete(),
              preservationWindowEnd: preservationEndTimestamp,
            });

            const data = oldDoc.data();
            const u1 = data.user1Id || data.user1;
            const u2 = data.user2Id || data.user2;
            const exPartnerId = (u1 === uid || u1 === ownerId) ? u2 : u1;
            if (exPartnerId && exPartnerId !== uid && exPartnerId !== ownerId) {
              const exUserRef = db.collection("users").doc(exPartnerId);
              transaction.update(exUserRef, {partnerId: null});
            }
          }
        }

        const wasPaused = coupleSnapshot.exists && coupleSnapshot.get("unlinkingState") === "paused";

        if (wasPaused) {
          transaction.set(
              coupleRef,
              {
                user1,
                user2,
                user1Id: user1,
                user2Id: user2,
                fechaVinculacion: FieldValue.serverTimestamp(),
                xpPareja: coupleSnapshot.get("xpPareja") || 0,
                nivelPareja: coupleSnapshot.get("nivelPareja") || 1,
                contractSignedUser1: false,
                contractSignedUser2: false,
                unlinkingState: FieldValue.delete(),
                unlinkedBy: FieldValue.delete(),
                unlinkedAt: FieldValue.delete(),
                recoveryWindowEnd: FieldValue.delete(),
                preservationWindowEnd: FieldValue.delete(),
                reconciliationStatus: FieldValue.delete(),
                reconciliationRequestedBy: FieldValue.delete(),
              },
              {merge: true},
          );
        } else {
          transaction.set(
              coupleRef,
              {
                user1,
                user2,
                user1Id: user1,
                user2Id: user2,
                fechaVinculacion: FieldValue.serverTimestamp(),
                xpPareja: 0,
                nivelPareja: 1,
                contractSignedUser1: false,
                contractSignedUser2: false,
              },
          );
        }
        transaction.update(myRef, {partnerId: ownerId});
        transaction.update(ownerUserRef, {partnerId: uid});
        transaction.update(inviteRef, {
          status: "used",
          usedAt: FieldValue.serverTimestamp(),
          usedBy: uid,
        });
        
        if (ownerPointerRef) {
            transaction.delete(ownerPointerRef);
        }
        if (myPointerSnapshot.exists) {
            transaction.delete(myPointerRef);
        }

        if (
          myInviteRef !== null &&
          myInviteSnapshot?.exists &&
          myInviteSnapshot.get("ownerId") === uid &&
          myInviteSnapshot.get("status") === "pending"
        ) {
          transaction.update(myInviteRef, {
            status: "cancelled",
            cancelledAt: FieldValue.serverTimestamp(),
          });
        }

        return {coupleId};
      });
    },
);

const emailVerification = require("./email-verification");

exports.sendEmailVerificationCode =
  emailVerification.sendEmailVerificationCode;
exports.verifyEmailVerificationCode =
  emailVerification.verifyEmailVerificationCode;

const accountCleanup = require("./account-cleanup");

exports.deleteMyAccount = accountCleanup.deleteMyAccount;
exports.cleanupIncompleteAccounts = accountCleanup.cleanupIncompleteAccounts;
