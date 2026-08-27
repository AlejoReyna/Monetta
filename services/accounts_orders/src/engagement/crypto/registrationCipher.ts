import { createCipheriv, createDecipheriv, createHash, randomBytes } from 'node:crypto';

/** Reversible encryption for provider registration identifiers. */
export class RegistrationCipher {
  private constructor(private readonly key: Buffer) {}

  static fromSecret(secret: string): RegistrationCipher {
    return new RegistrationCipher(createHash('sha256').update(secret).digest());
  }

  encrypt(value: string): string {
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', this.key, nonce);
    const encrypted = Buffer.concat([cipher.update(value, 'utf8'), cipher.final()]);
    const tag = cipher.getAuthTag();
    return Buffer.concat([nonce, tag, encrypted]).toString('base64url');
  }

  decrypt(encoded: string): string {
    const bytes = Buffer.from(encoded, 'base64url');
    if (bytes.length < 29) throw new Error('invalid registration ciphertext');
    const nonce = bytes.subarray(0, 12);
    const tag = bytes.subarray(12, 28);
    const encrypted = bytes.subarray(28);
    const decipher = createDecipheriv('aes-256-gcm', this.key, nonce);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
  }

  hash(value: string): string {
    return createHash('sha256').update(value).digest('hex');
  }
}
