import { cert, getApps, initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { ConfigurationError, requiredEnvironment } from "./environment.js";

export const catalogFirebaseProjectId = "monetta-catalog-staging-edfb8";

interface ServiceAccountJson {
  readonly project_id?: unknown;
  readonly client_email?: unknown;
  readonly private_key?: unknown;
}

function serviceAccount(): {
  readonly projectId: string;
  readonly clientEmail: string;
  readonly privateKey: string;
} {
  let parsed: ServiceAccountJson;
  try {
    parsed = JSON.parse(requiredEnvironment("FIREBASE_SERVICE_ACCOUNT")) as ServiceAccountJson;
  } catch (error) {
    if (error instanceof ConfigurationError) throw error;
    throw new ConfigurationError("FIREBASE_SERVICE_ACCOUNT is not valid JSON");
  }

  if (
    typeof parsed.project_id !== "string" || parsed.project_id.length === 0 ||
    typeof parsed.client_email !== "string" || parsed.client_email.length === 0 ||
    typeof parsed.private_key !== "string" || parsed.private_key.length === 0
  ) {
    throw new ConfigurationError("FIREBASE_SERVICE_ACCOUNT is missing required fields");
  }
  if (parsed.project_id !== catalogFirebaseProjectId) {
    throw new ConfigurationError("FIREBASE_SERVICE_ACCOUNT project mismatch");
  }

  return {
    projectId: parsed.project_id,
    clientEmail: parsed.client_email,
    privateKey: parsed.private_key,
  };
}

export function firestore() {
  const account = serviceAccount();
  if (getApps().length === 0) {
    initializeApp({ credential: cert(account) });
  }
  return getFirestore();
}
