import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    globals: true,
    environment: "jsdom",
    exclude: ["**/node_modules/**", "**/e2e/**"],
    setupFiles: ["./src/__tests__/setup.tsx"],
    css: false,
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov", "html"],
      reportsDirectory: "./coverage",
      exclude: [
        "node_modules/**",
        "src/__tests__/**",
        "**/*.test.{ts,tsx}",
        "**/*.config.{ts,js}",
        ".next/**",
        "e2e/**",
      ],
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
