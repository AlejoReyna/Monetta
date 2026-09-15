/**
 * Glob compilation for URL pathname matching.
 *
 * Requirements per § 4.2:
 * - urlPattern operates on URL.pathname only.
 * - * matches zero or more non-/ characters.
 * - ** matches zero or more characters including /.
 * - Anchored generated regexes (^...$).
 * - Every other regex metacharacter is escaped; input is never interpreted as raw regex.
 */

function escapeRegexLiteral(str: string): string {
  return str.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

export interface GlobValidationResult {
  readonly valid: boolean;
  readonly error?: string;
}

/**
 * Validates a glob pattern candidate without throwing.
 */
export function validateGlobPattern(pattern: unknown): GlobValidationResult {
  if (typeof pattern !== 'string') {
    return { valid: false, error: 'Glob pattern must be a string' };
  }
  if (pattern.trim().length === 0) {
    return { valid: false, error: 'Glob pattern cannot be empty' };
  }
  if (!pattern.startsWith('/') && !pattern.startsWith('**')) {
    return {
      valid: false,
      error: 'URL pathname glob pattern must start with "/" or "**"',
    };
  }
  if (/\*{3,}/.test(pattern)) {
    return {
      valid: false,
      error: 'Glob pattern cannot contain three or more consecutive asterisks',
    };
  }
  if (/[?#]/.test(pattern)) {
    return {
      valid: false,
      error: 'URL pathname glob cannot contain query ("?") or fragment ("#") characters',
    };
  }
  if (/\s/.test(pattern)) {
    return {
      valid: false,
      error: 'URL pathname glob cannot contain whitespace',
    };
  }
  return { valid: true };
}

/**
 * Compiles a validated glob pattern into an anchored RegExp targeting URL.pathname.
 * Uses 'i' flag for case-insensitive URL path matching.
 */
export function compileGlobToRegExp(pattern: string): RegExp {
  const parts = pattern.split(/(\*\*|\*)/);
  const regexParts: string[] = [];

  for (const part of parts) {
    if (part === '**') {
      regexParts.push('.*');
    } else if (part === '*') {
      regexParts.push('[^/]*');
    } else if (part.length > 0) {
      regexParts.push(escapeRegexLiteral(part));
    }
  }

  return new RegExp(`^${regexParts.join('')}$`, 'i');
}
