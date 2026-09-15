/** Raised when first-party registration would collide with an existing account or device binding. */
export class AccountRegistrationConflictError extends Error {
  constructor(readonly reason: 'device' | 'email') {
    super('registration_conflict');
    this.name = 'AccountRegistrationConflictError';
  }
}
