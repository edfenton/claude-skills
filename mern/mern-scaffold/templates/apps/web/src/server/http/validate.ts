import { z } from "zod";

export function parseJson<T extends z.ZodTypeAny>(
  schema: T,
  json: unknown,
): z.infer<T> {
  const parsed = schema.safeParse(json);
  if (!parsed.success) {
    const msg = parsed.error.issues
      .map((i) => `${i.path.join(".")}: ${i.message}`)
      .join("; ");
    throw new Error(`Validation failed: ${msg}`);
  }
  return parsed.data;
}
