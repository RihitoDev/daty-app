const {
  createHmac,
  randomInt,
  timingSafeEqual,
} = require("node:crypto");
const {Buffer} = require("node:buffer");

const CODE_LENGTH = 6;
const MAX_ATTEMPTS = 5;
const CODE_TTL_MS = 10 * 60 * 1000;
const RESEND_COOLDOWN_MS = 60 * 1000;

function generateEmailVerificationCode() {
  return randomInt(0, 10 ** CODE_LENGTH)
      .toString()
      .padStart(CODE_LENGTH, "0");
}

function hashEmailVerificationCode({uid, code, pepper}) {
  return createHmac("sha256", pepper)
      .update(`${uid}:${code}`, "utf8")
      .digest("hex");
}

function safeHashEquals(left, right) {
  if (typeof left !== "string" || typeof right !== "string") return false;

  const leftBuffer = Buffer.from(left, "hex");
  const rightBuffer = Buffer.from(right, "hex");

  if (
    leftBuffer.length === 0 ||
    leftBuffer.length !== rightBuffer.length
  ) {
    return false;
  }

  return timingSafeEqual(leftBuffer, rightBuffer);
}

function resendWaitMillis(record, nowMillis) {
  if (!record) return 0;
  return Math.max(0, record.resendAvailableAtMillis - nowMillis);
}

function evaluateEmailVerification({
  record,
  submittedHash,
  nowMillis,
}) {
  if (!record) {
    return {status: "missing"};
  }

  if (record.expiresAtMillis <= nowMillis) {
    return {status: "expired"};
  }

  if (record.attemptsRemaining <= 0) {
    return {status: "attempts-exhausted"};
  }

  if (!safeHashEquals(record.codeHash, submittedHash)) {
    const attemptsRemaining = Math.max(0, record.attemptsRemaining - 1);
    return {
      status: attemptsRemaining === 0 ?
        "attempts-exhausted" :
        "incorrect",
      attemptsRemaining,
    };
  }

  return {status: "verified"};
}

module.exports = {
  CODE_LENGTH,
  MAX_ATTEMPTS,
  CODE_TTL_MS,
  RESEND_COOLDOWN_MS,
  evaluateEmailVerification,
  generateEmailVerificationCode,
  hashEmailVerificationCode,
  resendWaitMillis,
  safeHashEquals,
};
