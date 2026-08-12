/**
 * Structured JSON logging to stdout. No external dependency: this service is
 * small enough that a formatter is not worth a package, and structured logs
 * are what the health-monitoring section of the spec asks for.
 */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

export interface LogFields {
  readonly [key: string]: unknown;
}

function emit(level: LogLevel, message: string, fields?: LogFields): void {
  const line = {
    timestamp: new Date().toISOString(),
    level,
    message,
    ...fields,
  };
  const serialized = JSON.stringify(line);
  if (level === 'error') {
    console.error(serialized);
  } else if (level === 'warn') {
    console.warn(serialized);
  } else {
    console.log(serialized);
  }
}

export const logger = {
  debug: (message: string, fields?: LogFields) => emit('debug', message, fields),
  info: (message: string, fields?: LogFields) => emit('info', message, fields),
  warn: (message: string, fields?: LogFields) => emit('warn', message, fields),
  error: (message: string, fields?: LogFields) => emit('error', message, fields),
};
