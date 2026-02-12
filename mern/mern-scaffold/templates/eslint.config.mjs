import js from "@eslint/js";
import globals from "globals";
import tseslint from "typescript-eslint";
import nextPlugin from "@next/eslint-plugin-next";
import reactHooks from "eslint-plugin-react-hooks";
import reactRefresh from "eslint-plugin-react-refresh";
import importPlugin from "eslint-plugin-import-x";
import unusedImports from "eslint-plugin-unused-imports";

export default [
  {
    ignores: [
      "**/.next/**",
      "**/dist/**",
      "**/build/**",
      "**/out/**",
      "**/coverage/**",
      "**/node_modules/**",
      "**/*.min.*",
      "*.config.{js,cjs,mjs,ts}",
    ],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: "latest",
      sourceType: "module",
      globals: { ...globals.browser, ...globals.node },
    },
  },
  {
    plugins: { "import-x": importPlugin },
    rules: {
      "import-x/no-named-as-default": "warn",
      "import-x/no-named-as-default-member": "warn",
      "import-x/no-cycle": ["warn", { maxDepth: 1 }],
      "import-x/extensions": "off",
    },
    settings: {
      "import-x/resolver": {
        node: { extensions: [".js", ".jsx", ".ts", ".tsx"] },
      },
    },
  },
  {
    plugins: { "react-hooks": reactHooks },
    rules: { ...reactHooks.configs.recommended.rules },
  },
  {
    plugins: { "unused-imports": unusedImports },
    rules: {
      "unused-imports/no-unused-imports": "error",
      "unused-imports/no-unused-vars": [
        "warn",
        {
          vars: "all",
          varsIgnorePattern: "^_",
          args: "after-used",
          argsIgnorePattern: "^_",
        },
      ],
    },
  },
  {
    files: ["apps/web/**/*.{js,jsx,ts,tsx}"],
    plugins: { "@next/next": nextPlugin },
    rules: {
      ...nextPlugin.configs.recommended.rules,
      ...nextPlugin.configs["core-web-vitals"].rules,
      "@next/next/no-html-link-for-pages": ["error", "apps/web/src/app"],
    },
  },
  {
    files: ["**/*.{jsx,tsx}"],
    ignores: ["**/app/**/layout.tsx", "**/app/**/page.tsx", "**/app/**/loading.tsx", "**/app/**/error.tsx", "**/app/**/not-found.tsx"],
    plugins: { "react-refresh": reactRefresh },
    rules: {
      "react-refresh/only-export-components": [
        "warn",
        { allowConstantExport: true },
      ],
    },
  },
  {
    files: [
      "**/*.{test,spec}.{js,jsx,ts,tsx}",
      "**/__tests__/**/*.{js,jsx,ts,tsx}",
    ],
    rules: { "import-x/no-cycle": "off" },
  },
];
