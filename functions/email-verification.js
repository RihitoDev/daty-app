const {randomUUID} = require("node:crypto");
const {getAuth} = require("firebase-admin/auth");
const {
  FieldValue,
  Timestamp,
  getFirestore,
} = require("firebase-admin/firestore");
const {defineSecret, defineString} = require("firebase-functions/params");
const {error: logError} = require("firebase-functions/logger");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {Resend} = require("resend");

const {
  CODE_TTL_MS,
  MAX_ATTEMPTS,
  RESEND_COOLDOWN_MS,
  evaluateEmailVerification,
  generateEmailVerificationCode,
  hashEmailVerificationCode,
  resendWaitMillis,
} = require("./email-verification-core");

const REGION = "us-central1";
const RESEND_API_KEY = defineSecret("RESEND_API_KEY");
const EMAIL_CODE_PEPPER = defineSecret("EMAIL_CODE_PEPPER");
const EMAIL_FROM = defineString("EMAIL_FROM", {
  default: "Daty <onboarding@resend.dev>",
});
const EMAIL_LOGO_URL = defineString("EMAIL_LOGO_URL", {default: ""});

function requireUid(request) {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "Debes iniciar sesión.");
  }
  return uid;
}

async function getAuthenticatedEmail(uid) {
  try {
    const user = await getAuth().getUser(uid);
    const email = user.email?.trim();

    if (!email) {
      throw new HttpsError(
          "failed-precondition",
          "La cuenta autenticada no tiene un correo disponible.",
      );
    }

    return {email, emailVerified: user.emailVerified};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    throw new HttpsError(
        "internal",
        "No se pudo consultar la cuenta autenticada.",
    );
  }
}

function verificationEmailHtml(code) {
  const logoUrl = EMAIL_LOGO_URL.value().trim();
  const logo = logoUrl ?
    `<img src="${logoUrl}" alt="Daty" width="72" style="display:block;margin:0 auto 20px;max-width:72px;height:auto;">` :
    "";

  return `<!doctype html>
<html lang="es">
  <body style="margin:0;padding:0;background:#f5effa;font-family:Arial,sans-serif;color:#2d1638;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f5effa;padding:24px 12px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:560px;background:#ffffff;border-radius:20px;padding:32px 24px;">
            <tr>
              <td align="center">
                ${logo}
                <h1 style="margin:0 0 12px;font-size:28px;color:#6f2c91;">Verifica tu correo en Daty</h1>
                <p style="margin:0 0 24px;line-height:1.6;color:#624f69;">Ingresa este código en la aplicación para continuar:</p>
                <div style="display:inline-block;padding:16px 22px;border-radius:14px;background:#f1e5f7;color:#54206e;font-size:34px;font-weight:700;letter-spacing:8px;">${code}</div>
                <p style="margin:24px 0 8px;line-height:1.6;color:#624f69;">El código vence en 10 minutos.</p>
                <p style="margin:0;line-height:1.6;color:#88788d;font-size:13px;">Si no solicitaste este código, ignora este mensaje.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function verificationEmailText(code) {
  return [
    "Verifica tu correo en Daty",
    "",
    `Tu código de verificación es: ${code}`,
    "",
    "El código vence en 10 minutos.",
    "Si no solicitaste este código, ignora este mensaje.",
  ].join("\n");
}

exports.sendEmailVerificationCode = onCall(
    {
      region: REGION,
      secrets: [RESEND_API_KEY, EMAIL_CODE_PEPPER],
    },
    async (request) => {
      const uid = requireUid(request);
      const account = await getAuthenticatedEmail(uid);
      const db = getFirestore();
      const codeRef = db.collection("emailVerificationCodes").doc(uid);

      if (account.emailVerified) {
        await codeRef.delete();
        return {alreadyVerified: true, resendAvailableAtMillis: 0};
      }

      const code = generateEmailVerificationCode();
      const pepper = EMAIL_CODE_PEPPER.value();
      const codeHash = hashEmailVerificationCode({uid, code, pepper});
      const deliveryId = randomUUID();

      const resendAvailableAtMillis = await db.runTransaction(
          async (transaction) => {
            const nowMillis = Date.now();
            const snapshot = await transaction.get(codeRef);

            if (snapshot.exists) {
              const existing = snapshot.data();
              const waitMillis = resendWaitMillis({
                resendAvailableAtMillis:
                  existing.resendAvailableAt?.toMillis?.() ?? 0,
              }, nowMillis);

              if (waitMillis > 0) {
                throw new HttpsError(
                    "resource-exhausted",
                    "Espera antes de solicitar otro código.",
                    {retryAfterSeconds: Math.ceil(waitMillis / 1000)},
                );
              }
            }

            const createdAt = Timestamp.fromMillis(nowMillis);
            const expiresAt = Timestamp.fromMillis(nowMillis + CODE_TTL_MS);
            const resendAvailableAt = Timestamp.fromMillis(
                nowMillis + RESEND_COOLDOWN_MS,
            );

            transaction.set(codeRef, {
              codeHash,
              expiresAt,
              resendAvailableAt,
              attemptsRemaining: MAX_ATTEMPTS,
              deliveryId,
              createdAt,
              updatedAt: createdAt,
            });

            return resendAvailableAt.toMillis();
          },
      );

      let providerRejected = false;

      try {
        const resend = new Resend(RESEND_API_KEY.value());
        const {error: resendError} = await resend.emails.send({
          from: EMAIL_FROM.value(),
          to: [account.email],
          subject: "Tu código de verificación de Daty",
          html: verificationEmailHtml(code),
          text: verificationEmailText(code),
        });

        if (resendError) {
          providerRejected = true;
          logError("Resend rejected a verification email.", {
            providerErrorName: resendError.name ?? "unknown",
            providerStatusCode: resendError.statusCode ?? null,
          });
          throw new Error("Resend rejected the verification email.");
        }
      } catch (error) {
        if (!providerRejected) {
          logError("Verification email provider request failed.", {
            errorName: error?.name ?? "unknown",
          });
        }

        await db.runTransaction(async (transaction) => {
          const snapshot = await transaction.get(codeRef);
          if (snapshot.exists && snapshot.get("deliveryId") === deliveryId) {
            transaction.delete(codeRef);
          }
        });

        throw new HttpsError(
            "internal",
            "No se pudo enviar el código. Inténtalo nuevamente.",
            {
              reason: providerRejected ?
                "email-provider-rejected" :
                "email-provider-unavailable",
            },
        );
      }

      return {
        alreadyVerified: false,
        resendAvailableAtMillis,
      };
    },
);

exports.verifyEmailVerificationCode = onCall(
    {
      region: REGION,
      secrets: [EMAIL_CODE_PEPPER],
    },
    async (request) => {
      const uid = requireUid(request);
      const code = String(request.data?.code ?? "").trim();

      if (!/^\d{6}$/.test(code)) {
        throw new HttpsError(
            "invalid-argument",
            "El código debe contener exactamente 6 dígitos.",
        );
      }

      const account = await getAuthenticatedEmail(uid);
      const db = getFirestore();
      const codeRef = db.collection("emailVerificationCodes").doc(uid);

      if (account.emailVerified) {
        await codeRef.delete();
        return {verified: true, alreadyVerified: true};
      }

      const submittedHash = hashEmailVerificationCode({
        uid,
        code,
        pepper: EMAIL_CODE_PEPPER.value(),
      });

      const evaluation = await db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(codeRef);
        const data = snapshot.data();
        const result = evaluateEmailVerification({
          record: data ? {
            codeHash: data.codeHash,
            expiresAtMillis: data.expiresAt?.toMillis?.() ?? 0,
            attemptsRemaining: data.attemptsRemaining ?? 0,
          } : null,
          submittedHash,
          nowMillis: Date.now(),
        });

        if (result.status === "expired") {
          transaction.delete(codeRef);
        }

        if (result.status === "attempts-exhausted") {
          if (snapshot.exists) {
            transaction.update(codeRef, {
              attemptsRemaining: 0,
              updatedAt: FieldValue.serverTimestamp(),
            });
          }
        }

        if (result.status === "incorrect") {
          transaction.update(codeRef, {
            attemptsRemaining: result.attemptsRemaining,
            updatedAt: FieldValue.serverTimestamp(),
          });
        }

        return result;
      });

      if (evaluation.status === "missing") {
        throw new HttpsError(
            "failed-precondition",
            "Solicita un código antes de verificar.",
        );
      }
      if (evaluation.status === "expired") {
        throw new HttpsError(
            "deadline-exceeded",
            "El código ha vencido. Solicita uno nuevo.",
        );
      }
      if (evaluation.status === "attempts-exhausted") {
        throw new HttpsError(
            "resource-exhausted",
            "Se agotaron los intentos. Solicita un código nuevo.",
            {reason: "attempts-exhausted"},
        );
      }
      if (evaluation.status === "incorrect") {
        throw new HttpsError(
            "invalid-argument",
            "El código es incorrecto.",
            {attemptsRemaining: evaluation.attemptsRemaining},
        );
      }

      try {
        await getAuth().updateUser(uid, {emailVerified: true});
        await codeRef.delete();
      } catch {
        throw new HttpsError(
            "internal",
            "No se pudo completar la verificación. Inténtalo nuevamente.",
        );
      }

      return {verified: true, alreadyVerified: false};
    },
);
