export function rejectMongoOperators<T>(value: T): T {
  if (Array.isArray(value)) {
    return value.map((v) => rejectMongoOperators(v)) as unknown as T;
  }
  if (value && typeof value === "object") {
    for (const [k, v] of Object.entries(value as Record<string, unknown>)) {
      if (k.startsWith("$") || k.includes(".")) {
        throw new Error("Invalid input: contains forbidden keys");
      }
      rejectMongoOperators(v);
    }
  }
  return value;
}
