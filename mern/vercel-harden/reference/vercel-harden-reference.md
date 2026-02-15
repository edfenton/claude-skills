# Vercel Hardening Reference

## Security Headers

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Control referrer leakage |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` | Restrict browser APIs |
| `Strict-Transport-Security` | `max-age=63072000; includeSubDomains; preload` | Force HTTPS (2 years) |
| `X-DNS-Prefetch-Control` | `on` | Enable DNS prefetching |
| `Content-Security-Policy` | (see CSP section — applied in proxy.ts, NOT here) | Control resource loading |

### Static headers in next.config.ts

Apply all headers **except CSP** here. CSP must be applied per-request in `proxy.ts`.

```typescript
import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  poweredByHeader: false,
  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          { key: "X-Content-Type-Options", value: "nosniff" },
          { key: "X-Frame-Options", value: "DENY" },
          { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
          { key: "Permissions-Policy", value: "geolocation=(), microphone=(), camera=()" },
          { key: "Strict-Transport-Security", value: "max-age=63072000; includeSubDomains; preload" },
          { key: "X-DNS-Prefetch-Control", value: "on" },
          // CSP goes in proxy.ts — do NOT add it here
        ],
      },
    ];
  },
};
```

### CSP + bot protection in proxy.ts

CSP is applied per-request in `proxy.ts` alongside bot protection:

```typescript
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function proxy(request: NextRequest) {
  // Bot protection
  const ua = request.headers.get("user-agent") ?? "";
  if (isBlockedUserAgent(ua)) {
    return new NextResponse(null, { status: 403 });
  }
  if (isHoneypotPath(request.nextUrl.pathname)) {
    return new NextResponse(null, { status: 403 });
  }

  const response = NextResponse.next();

  // Apply CSP and other dynamic headers
  applySecurityHeaders(response.headers);

  return response;
}

export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};
```

## Content Security Policy

> **WARNING: Do NOT use nonce-based CSP or `'strict-dynamic'` with Next.js.**
> Next.js generates inline `<script>` tags for hydration, routing, and RSC payloads.
> These scripts cannot receive nonces because they are injected by the framework
> without nonce attributes. Using nonces or `'strict-dynamic'` will cause:
> - White page of death (all client JS blocked)
> - Broken navigation, keyboard shortcuts, and interactive elements
> - YouTube/video embeds failing silently
>
> The correct approach is `script-src 'self' 'unsafe-inline'`.

### Base directives

```
default-src 'self'
script-src 'self' 'unsafe-inline'
style-src 'self' 'unsafe-inline'
img-src 'self' data:
connect-src 'self'
font-src 'self'
media-src 'self'
frame-ancestors 'none'
base-uri 'self'
form-action 'self'
```

Notes:
- `script-src 'unsafe-inline'` is required because Next.js injects inline scripts for hydration
- `img-src data:` is required for inline SVG data URIs (e.g. custom cursors, inline icons)
- `media-src 'self'` is required for any audio/video hosted on the same origin
- Non-executable script types like `<script type="application/ld+json">` (JSON-LD structured data) are not affected by `script-src` — do NOT apply nonces to them

### Common third-party allowlists

| Service | Directives |
|---------|-----------|
| **Vercel Analytics** | `script-src https://va.vercel-scripts.com`; `connect-src https://va.vercel-scripts.com https://vitals.vercel-insights.com` |
| **Twitter/X embeds** | Use `react-tweet` package (by Vercel) instead of `widgets.js`. Server-side API route fetches tweet data — no external scripts needed. Only add `img-src https://pbs.twimg.com` for tweet images. Do NOT add `platform.twitter.com` to script-src — `widgets.js` uses dynamic code execution that is incompatible with CSP. |
| **YouTube embeds** | `frame-src https://www.youtube-nocookie.com`; `img-src https://img.youtube.com https://i.ytimg.com` |
| **Google Fonts** | `style-src https://fonts.googleapis.com`; `font-src https://fonts.gstatic.com` |
| **Google Analytics** | `script-src https://www.googletagmanager.com`; `connect-src https://www.google-analytics.com` |
| **Cloudinary** | `img-src https://res.cloudinary.com`; `media-src https://res.cloudinary.com` (for audio/video) |
| **Stripe** | `script-src https://js.stripe.com`; `frame-src https://js.stripe.com https://hooks.stripe.com` |
| **Google Maps** | `script-src https://maps.googleapis.com`; `img-src https://maps.googleapis.com https://maps.gstatic.com`; `frame-src https://www.google.com` |

## Bot Protection

### Blocked user agents (proxy.ts)

Scanners and attack tools — block with 403:

```
sqlmap, nikto, nmap, masscan, zmeu, dirbuster, gobuster, wpscan, nuclei, httpx
```

Also block empty user agent strings.

### Honeypot paths (proxy.ts)

Common attack probes — block with 403:

```
/.env, /.env.*, /wp-admin/*, /wp-login.php, /wp-content/*,
/phpmyadmin/*, /.git/*, /xmlrpc.php, /administrator/*
```

### robots.txt disallow rules

AI scrapers:
```
GPTBot, CCBot, Google-Extended, anthropic-ai, ClaudeBot, Claude-Web, Bytespider, Diffbot
```

SEO bots (aggressive crawlers):
```
AhrefsBot, SemrushBot, MJ12bot, DotBot, BLEXBot, DataForSeoBot, PetalBot
```

### Proxy matcher config

Exclude static assets from proxy processing:

```typescript
export const config = {
  matcher: [
    "/((?!_next/static|_next/image|favicon.ico|sitemap.xml|robots.txt).*)",
  ],
};
```

## Vercel Dashboard Hardening

### All plans

| Setting | Location | Action |
|---------|----------|--------|
| Environment Variable Scoping | Project Settings > **Environment Variables** > per-variable "Exposed to" settings | Verify sensitive vars are scoped to Production only; disable exposure to Preview/Development for secrets |
| Build Logs Privacy | Project Settings > **General** | Verify `/_src` and `/_logs` are not publicly accessible |
| DDoS Protection | Automatic | Verify enabled (default on all plans) |

### Pro plan

| Setting | Location | Action |
|---------|----------|--------|
| Deployment Protection | Project Settings > **Deployment Protection** tab | Enable Vercel Authentication for preview deployments |
| WAF / Firewall Rules | Project dashboard > **Firewall** tab (top-level) | Configure custom firewall rules (up to 40) |
| Attack Challenge Mode | Project dashboard > **Firewall** tab > Bot Management section | Enable for suspicious traffic patterns |
| Bot Protection | Project dashboard > **Firewall** tab > Bot Management section | Configure managed bot rules |

### WAF rule templates (Pro)

1. **Block attack paths** — Supplement code-level honeypot blocking with edge rules
2. **Rate limit API** — `/api/*` to 100 req/min per IP
3. **Challenge suspicious UA** — Challenge requests with unusual user agents
4. **Geo-blocking** — Block traffic from countries not in target audience (if applicable)

### Enterprise plan

| Setting | Location | Action |
|---------|----------|--------|
| Advanced WAF | Project dashboard > **Firewall** tab | Full WAF with OWASP rule sets |
| Log Drains | Project Settings > **Log Drains** | Stream access logs to SIEM |
| IP Allowlisting | Project Settings > **Security** | Restrict dashboard access |

## Vercel CLI Commands

```bash
# List environment variables
vercel env ls

# Pull env vars locally
vercel env pull .env.local

# Check deployment status
vercel ls

# Inspect deployment
vercel inspect <deployment-url>
```

## Verification Checklist

After hardening, verify with curl:

```bash
curl -sI https://your-domain.com | grep -E "^(X-Content-Type|X-Frame|Referrer-Policy|Permissions-Policy|Content-Security|Strict-Transport|X-DNS-Prefetch|X-Powered)"
```

Expected: All security headers present, no `X-Powered-By` header.

After deployment, open the browser DevTools console and check for CSP violation errors (`Refused to execute inline script...` or similar). If any appear, update the CSP directives accordingly.
