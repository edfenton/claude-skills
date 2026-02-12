import { z } from "zod";

const EnvSchema = z.object({
  NODE_ENV: z
    .enum(["development", "test", "production"])
    .default("development"),
  MONGODB_URI: z.string().min(1, "MONGODB_URI is required"),
  APP_URL: z.string().url().optional(),
});

let cached: z.infer<typeof EnvSchema> | null = null;

export function env() {
  if (cached) return cached;
  const parsed = EnvSchema.safeParse(process.env);
  if (!parsed.success) {
    // Keep message safe: no env values printed.
    const issues = parsed.error.issues
      .map((i) => `${i.path.join(".")}: ${i.message}`)
      .join("; ");
    throw new Error(`Invalid environment configuration: ${issues}`);
  }
  cached = parsed.data;
  return cached;
}
