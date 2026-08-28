import { afterEach, describe, expect, it } from "vitest";
import { catalogFirebaseProjectId, firestore } from "./firebaseAdmin.js";

const previousServiceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;

afterEach(() => {
  if (previousServiceAccount === undefined) {
    delete process.env.FIREBASE_SERVICE_ACCOUNT;
  } else {
    process.env.FIREBASE_SERVICE_ACCOUNT = previousServiceAccount;
  }
});

describe("Firebase Admin staging boundary", () => {
  it("rejects a service account for another project before initialization", () => {
    process.env.FIREBASE_SERVICE_ACCOUNT = JSON.stringify({
      project_id: "unexpected-project",
      client_email: "test@example.invalid",
      private_key: "not-a-real-key",
    });

    expect(() => firestore()).toThrowError(
      "FIREBASE_SERVICE_ACCOUNT project mismatch",
    );
  });

  it("declares the isolated staging project", () => {
    expect(catalogFirebaseProjectId).toBe("monetta-catalog-staging-edfb8");
  });
});
