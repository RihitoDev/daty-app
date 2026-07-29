const assert = require("node:assert/strict");
const test = require("node:test");

const {
  MAX_ATTEMPTS,
  evaluateEmailVerification,
  generateEmailVerificationCode,
  hashEmailVerificationCode,
  resendWaitMillis,
} = require("../email-verification-core");

const uid = "user-123";
const pepper = "test-only-pepper";
const code = "012345";
const codeHash = hashEmailVerificationCode({uid, code, pepper});

function activeRecord(overrides = {}) {
  return {
    codeHash,
    expiresAtMillis: 700000,
    attemptsRemaining: MAX_ATTEMPTS,
    ...overrides,
  };
}

test("genera códigos numéricos de exactamente 6 dígitos", () => {
  for (let index = 0; index < 100; index += 1) {
    assert.match(generateEmailVerificationCode(), /^\d{6}$/);
  }
});

test("el hash es determinista para el mismo uid, código y pepper", () => {
  assert.equal(
      hashEmailVerificationCode({uid, code, pepper}),
      hashEmailVerificationCode({uid, code, pepper}),
  );
  assert.notEqual(
      hashEmailVerificationCode({uid, code: "999999", pepper}),
      codeHash,
  );
});

test("rechaza un código incorrecto y descuenta un intento", () => {
  const result = evaluateEmailVerification({
    record: activeRecord(),
    submittedHash: hashEmailVerificationCode({
      uid,
      code: "999999",
      pepper,
    }),
    nowMillis: 1000,
  });

  assert.deepEqual(result, {
    status: "incorrect",
    attemptsRemaining: MAX_ATTEMPTS - 1,
  });
});

test("rechaza un código vencido", () => {
  const result = evaluateEmailVerification({
    record: activeRecord({expiresAtMillis: 1000}),
    submittedHash: codeHash,
    nowMillis: 1000,
  });

  assert.deepEqual(result, {status: "expired"});
});

test("bloquea cuando se agotaron los intentos", () => {
  const result = evaluateEmailVerification({
    record: activeRecord({attemptsRemaining: 0}),
    submittedHash: codeHash,
    nowMillis: 1000,
  });

  assert.deepEqual(result, {status: "attempts-exhausted"});
});

test("calcula el límite de reenvío", () => {
  assert.equal(
      resendWaitMillis({resendAvailableAtMillis: 61000}, 1000),
      60000,
  );
  assert.equal(
      resendWaitMillis({resendAvailableAtMillis: 1000}, 1000),
      0,
  );
});

test("acepta el código correcto", () => {
  const result = evaluateEmailVerification({
    record: activeRecord(),
    submittedHash: codeHash,
    nowMillis: 1000,
  });

  assert.deepEqual(result, {status: "verified"});
});
