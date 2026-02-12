export type ApiOk<T> = { ok: true; data: T };
export type ApiErr = { ok: false; error: { code: string; message: string } };
export type ApiResponse<T> = ApiOk<T> | ApiErr;

export function ok<T>(data: T): ApiOk<T> {
  return { ok: true, data };
}

export function err(code: string, message: string): ApiErr {
  return { ok: false, error: { code, message } };
}
