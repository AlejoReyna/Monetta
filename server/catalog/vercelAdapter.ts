import type { IncomingMessage, ServerResponse } from "node:http";

export interface VercelRequest extends IncomingMessage {}

export interface VercelResponse extends ServerResponse {
  status(code: number): VercelResponse;
  json(body: unknown): void;
  send(body: unknown): void;
}

export class RequestBodyTooLargeError extends Error {
  constructor() {
    super("Request body is too large");
    this.name = "RequestBodyTooLargeError";
  }
}

export async function toWebRequest(
  request: VercelRequest,
  maximumBodyBytes: number,
): Promise<Request> {
  const chunks: Buffer[] = [];
  let size = 0;
  for await (const value of request) {
    const chunk = Buffer.isBuffer(value) ? value : Buffer.from(value as Uint8Array);
    size += chunk.length;
    if (size > maximumBodyBytes) throw new RequestBodyTooLargeError();
    chunks.push(chunk);
  }

  const headers = new Headers();
  for (const [name, value] of Object.entries(request.headers)) {
    if (typeof value === "string") headers.set(name, value);
    else if (Array.isArray(value)) {
      for (const item of value) headers.append(name, item);
    }
  }
  const body = Buffer.concat(chunks);
  const host = request.headers.host ?? "localhost";
  const init: RequestInit = {
    method: request.method ?? "GET",
    headers,
    ...(body.length === 0 ? {} : { body: new Uint8Array(body) }),
  };
  return new Request(`https://${host}${request.url ?? "/"}`, init);
}

export async function sendWebResponse(
  response: VercelResponse,
  result: Response,
): Promise<void> {
  result.headers.forEach((value, name) => response.setHeader(name, value));
  response.status(result.status).send(Buffer.from(await result.arrayBuffer()));
}
