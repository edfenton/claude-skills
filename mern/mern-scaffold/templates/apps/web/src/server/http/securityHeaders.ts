export function applySecurityHeaders(headers: Headers) {
  headers.set("X-Content-Type-Options", "nosniff");
  headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
  headers.set("X-Frame-Options", "DENY");
  headers.set("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
  // CSP is app-specific; provide a safe baseline that avoids breaking Next.js by default.
  // You should tighten CSP as routes and assets become clear.
  headers.set(
    "Content-Security-Policy",
    "default-src 'self'; frame-ancestors 'none'; base-uri 'self'",
  );
}
