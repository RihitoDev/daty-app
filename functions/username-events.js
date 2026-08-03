const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {getAuth} = require("firebase-admin/auth");
const {getFirestore, FieldValue, Timestamp} = require("firebase-admin/firestore");

const REGION = "us-central1";
const CONFIG_PATH = "app_config/usernameChanges";

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

function eventState(data, now = Date.now()) {
  const startsAt = data?.startsAt;
  const endsAt = data?.endsAt;
  const enabled = data?.enabled === true;
  const withinDates = startsAt instanceof Timestamp &&
    endsAt instanceof Timestamp &&
    startsAt.toMillis() <= now && endsAt.toMillis() >= now;
  return {
    active: enabled && withinDates && typeof data?.eventId === "string",
    eventId: data?.eventId ?? null,
    startsAtMillis: startsAt instanceof Timestamp ? startsAt.toMillis() : null,
    endsAtMillis: endsAt instanceof Timestamp ? endsAt.toMillis() : null,
    maxChanges: Number.isInteger(data?.maxChangesPerUser) ?
      data.maxChangesPerUser : 1,
  };
}

exports.getUsernameChangeStatus = onCall(
    {region: REGION},
    async (request) => {
      const uid = requireUid(request);
      const db = getFirestore();
      const [configSnapshot, userSnapshot] = await Promise.all([
        db.doc(CONFIG_PATH).get(),
        db.collection("users").doc(uid).get(),
      ]);
      const state = eventState(configSnapshot.data());
      const user = userSnapshot.data();
      const used = user?.usernameChangeEventId === state.eventId ?
        Number(user?.usernameChangesInEvent ?? 0) : 0;

      return {
        enabled: state.active && used < state.maxChanges,
        eventActive: state.active,
        remainingChanges: Math.max(0, state.maxChanges - used),
        endsAtMillis: state.endsAtMillis,
      };
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
      await db.runTransaction(async (transaction) => {
        const configRef = db.doc(CONFIG_PATH);
        const userRef = db.collection("users").doc(uid);
        const newUsernameRef = db.collection("usernames")
            .doc(normalizeUsername(username));

        const configSnapshot = await transaction.get(configRef);
        const userSnapshot = await transaction.get(userRef);
        const newUsernameSnapshot = await transaction.get(newUsernameRef);
        if (!userSnapshot.exists) {
          throw new HttpsError("not-found", "Perfil no encontrado.");
        }

        const state = eventState(configSnapshot.data());
        if (!state.active) {
          throw new HttpsError(
              "failed-precondition",
              "No hay un evento de cambio de username activo.",
              {reason: "event-inactive"},
          );
        }

        const user = userSnapshot.data();
        const used = user.usernameChangeEventId === state.eventId ?
          Number(user.usernameChangesInEvent ?? 0) : 0;
        if (used >= state.maxChanges) {
          throw new HttpsError(
              "resource-exhausted",
              "Ya utilizaste los cambios disponibles para este evento.",
              {reason: "event-limit-reached"},
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
          usernameChangeEventId: state.eventId,
          usernameChangesInEvent: used + 1,
          usernameChangedAt: FieldValue.serverTimestamp(),
        });
        if (oldUsernameRef !== null &&
            oldUsernameSnapshot?.exists &&
            oldUsernameSnapshot.get("uid") === uid) {
          transaction.delete(oldUsernameRef);
        }
      });

      await getAuth().updateUser(uid, {displayName: username});
      return {username};
    },
);
