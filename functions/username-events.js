const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");

const REGION = "us-central1";
const COOLDOWN_MONTHS = 4;

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  return uid;
}

function cleanUsername(value) {
  return String(value ?? "").trim().replace(/\s+/g, " ");
}

function normalizeUsername(value) {
  return cleanUsername(value).toLowerCase().replaceAll("/", "-");
}

function isValidUsername(value) {
  const username = cleanUsername(value);
  const spaces = (username.match(/\s/g) ?? []).length;
  return username.length >= 2 && username.length <= 20 && spaces <= 3;
}

function addCalendarMonths(date, months) {
  const year = date.getUTCFullYear();
  const month = date.getUTCMonth() + months;
  const targetYear = year + Math.floor(month / 12);
  const targetMonth = ((month % 12) + 12) % 12;
  const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0))
      .getUTCDate();

  return new Date(Date.UTC(
      targetYear,
      targetMonth,
      Math.min(date.getUTCDate(), lastDay),
      date.getUTCHours(),
      date.getUTCMinutes(),
      date.getUTCSeconds(),
      date.getUTCMilliseconds(),
  ));
}

function authCreationTimestamp(authUser) {
  const creationTime = Date.parse(authUser.metadata.creationTime);
  return Number.isFinite(creationTime) ? Timestamp.fromMillis(creationTime) : null;
}

function cooldownState(user, fallbackCreatedAt, now = Date.now()) {
  const baseline = user?.usernameChangedAt instanceof Timestamp ?
    user.usernameChangedAt :
    user?.createdAt instanceof Timestamp ? user.createdAt : fallbackCreatedAt;

  if (!(baseline instanceof Timestamp)) {
    return {enabled: false, nextChangeAtMillis: null};
  }

  const nextChangeAt = addCalendarMonths(baseline.toDate(), COOLDOWN_MONTHS);
  return {
    enabled: now >= nextChangeAt.getTime(),
    nextChangeAtMillis: nextChangeAt.getTime(),
  };
}

exports.getUsernameChangeStatus = onCall(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);
      const db = getFirestore();
      const [userSnapshot, authUser] = await Promise.all([
        db.collection("users").doc(uid).get(),
        getAuth().getUser(uid),
      ]);

      if (!userSnapshot.exists) {
        throw new HttpsError("not-found", "Perfil no encontrado.");
      }

      return cooldownState(
          userSnapshot.data(),
          authCreationTimestamp(authUser),
      );
    },
);

exports.changeUsernameDuringEvent = onCall(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);
      const username = cleanUsername(request.data?.username);
      if (!isValidUsername(username)) {
        throw new HttpsError("invalid-argument", "El username no es válido.");
      }

      const db = getFirestore();
      const authUser = await getAuth().getUser(uid);
      const fallbackCreatedAt = authCreationTimestamp(authUser);

      const changed = await db.runTransaction(async (transaction) => {
        const userRef = db.collection("users").doc(uid);
        const newUsernameRef = db.collection("usernames")
            .doc(normalizeUsername(username));
        const userSnapshot = await transaction.get(userRef);
        const newUsernameSnapshot = await transaction.get(newUsernameRef);

        if (!userSnapshot.exists) {
          throw new HttpsError("not-found", "Perfil no encontrado.");
        }

        const user = userSnapshot.data();
        if (normalizeUsername(user.username) === normalizeUsername(username)) {
          return false;
        }

        const state = cooldownState(user, fallbackCreatedAt);
        if (!state.enabled) {
          throw new HttpsError(
              "failed-precondition",
              "El nombre solo puede cambiarse cada cuatro meses.",
              {
                reason: "cooldown-active",
                nextChangeAtMillis: state.nextChangeAtMillis,
              },
          );
        }

        if (newUsernameSnapshot.exists &&
            newUsernameSnapshot.get("uid") !== uid) {
          throw new HttpsError("already-exists", "Ese username ya está en uso.");
        }

        const oldNormalized = user.usernameNormalized;
        const oldUsernameRef = typeof oldNormalized === "string" &&
          oldNormalized.length > 0 ?
          db.collection("usernames").doc(oldNormalized) : null;
        const oldUsernameSnapshot = oldUsernameRef === null ||
          oldUsernameRef.path === newUsernameRef.path ? null :
          await transaction.get(oldUsernameRef);

        transaction.set(newUsernameRef, {
          uid,
          username,
          email: request.auth.token.email ?? "",
          updatedAt: FieldValue.serverTimestamp(),
        });
        transaction.update(userRef, {
          username,
          usernameNormalized: normalizeUsername(username),
          usernameChangedAt: FieldValue.serverTimestamp(),
        });

        if (oldUsernameRef !== null &&
            oldUsernameSnapshot?.exists &&
            oldUsernameSnapshot.get("uid") === uid) {
          transaction.delete(oldUsernameRef);
        }

        return true;
      });

      if (changed) {
        await getAuth().updateUser(uid, {displayName: username});
      }
      return {username};
    },
);
