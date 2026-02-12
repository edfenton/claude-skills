# MERN Add Auth Reference

NextAuth.js setup templates and OAuth provider configuration.

---

## Dependencies

```bash
pnpm add next-auth --filter=web
pnpm add @auth/mongodb-adapter --filter=web  # If using MongoDB adapter
```

---

## Auth Config

```typescript
// apps/web/src/lib/auth.ts
import { NextAuthOptions } from 'next-auth';
import GoogleProvider from 'next-auth/providers/google';
import GitHubProvider from 'next-auth/providers/github';
import CredentialsProvider from 'next-auth/providers/credentials';
import { MongoDBAdapter } from '@auth/mongodb-adapter';
import { connectMongoose } from '@/server/db/mongoose';
import { User } from '@/server/db/models/user';
import { env } from '@/server/env';
import bcrypt from 'bcryptjs';

export const authOptions: NextAuthOptions = {
  adapter: MongoDBAdapter(clientPromise), // Optional: for DB sessions
  
  providers: [
    GoogleProvider({
      clientId: env().GOOGLE_CLIENT_ID,
      clientSecret: env().GOOGLE_CLIENT_SECRET,
    }),
    GitHubProvider({
      clientId: env().GITHUB_CLIENT_ID,
      clientSecret: env().GITHUB_CLIENT_SECRET,
    }),
    // Only if using credentials
    CredentialsProvider({
      name: 'credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        await connectMongoose();
        const user = await User.findOne({ email: credentials.email }).select('+password');

        if (!user || !user.password) {
          return null;
        }

        const isValid = await bcrypt.compare(credentials.password, user.password);
        if (!isValid) {
          return null;
        }

        return {
          id: user._id.toString(),
          email: user.email,
          name: user.name,
          image: user.image,
        };
      },
    }),
  ],

  session: {
    strategy: 'jwt', // Use 'database' if using adapter
  },

  callbacks: {
    async jwt({ token, user }) {
      if (user) {
        token.id = user.id;
      }
      return token;
    },
    async session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string;
      }
      return session;
    },
  },

  pages: {
    signIn: '/auth/signin',  // Custom sign-in page (optional)
    error: '/auth/error',    // Error page (optional)
  },
};
```

---

## API Route Handler

```typescript
// apps/web/src/app/api/auth/[...nextauth]/route.ts
import NextAuth from 'next-auth';
import { authOptions } from '@/lib/auth';

const handler = NextAuth(authOptions);

export { handler as GET, handler as POST };
```

---

## Session Types

```typescript
// apps/web/src/types/next-auth.d.ts
import { DefaultSession } from 'next-auth';

declare module 'next-auth' {
  interface Session {
    user: {
      id: string;
    } & DefaultSession['user'];
  }
}

declare module 'next-auth/jwt' {
  interface JWT {
    id: string;
  }
}
```

---

## Session Provider

```tsx
// apps/web/src/components/providers/SessionProvider.tsx
'use client';

import { SessionProvider as NextAuthSessionProvider } from 'next-auth/react';

export function SessionProvider({ children }: { children: React.ReactNode }) {
  return <NextAuthSessionProvider>{children}</NextAuthSessionProvider>;
}
```

```tsx
// apps/web/src/app/layout.tsx
import { SessionProvider } from '@/components/providers/SessionProvider';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  );
}
```

---

## Middleware (Route Protection)

```typescript
// apps/web/middleware.ts
import { withAuth } from 'next-auth/middleware';

export default withAuth({
  pages: {
    signIn: '/auth/signin',
  },
});

export const config = {
  matcher: [
    '/dashboard/:path*',
    '/settings/:path*',
    '/api/((?!auth|health).*)',  // Protect API except auth and health
  ],
};
```

---

## Auth Components

### Sign In Button

```tsx
// apps/web/src/components/auth/SignInButton.tsx
'use client';

import { signIn } from 'next-auth/react';

interface Props {
  provider?: 'google' | 'github';
  callbackUrl?: string;
}

export function SignInButton({ provider, callbackUrl = '/' }: Props) {
  if (provider) {
    return (
      <button
        onClick={() => signIn(provider, { callbackUrl })}
        className="btn-primary flex items-center gap-2"
      >
        {provider === 'google' && <GoogleIcon />}
        {provider === 'github' && <GitHubIcon />}
        Sign in with {provider.charAt(0).toUpperCase() + provider.slice(1)}
      </button>
    );
  }

  return (
    <button onClick={() => signIn()} className="btn-primary">
      Sign in
    </button>
  );
}
```

### Sign Out Button

```tsx
// apps/web/src/components/auth/SignOutButton.tsx
'use client';

import { signOut } from 'next-auth/react';

export function SignOutButton() {
  return (
    <button onClick={() => signOut({ callbackUrl: '/' })} className="text-secondary hover:text-primary">
      Sign out
    </button>
  );
}
```

### User Menu

```tsx
// apps/web/src/components/auth/UserMenu.tsx
'use client';

import { useSession } from 'next-auth/react';
import { SignInButton } from './SignInButton';
import { SignOutButton } from './SignOutButton';

export function UserMenu() {
  const { data: session, status } = useSession();

  if (status === 'loading') {
    return <div className="w-8 h-8 rounded-full bg-gray-200 animate-pulse" />;
  }

  if (!session) {
    return <SignInButton />;
  }

  return (
    <div className="flex items-center gap-3">
      {session.user.image && (
        <img
          src={session.user.image}
          alt={session.user.name ?? 'User'}
          className="w-8 h-8 rounded-full"
        />
      )}
      <span className="text-sm">{session.user.name}</span>
      <SignOutButton />
    </div>
  );
}
```

---

## User Model (if --with-user-model)

```typescript
// apps/web/src/server/db/models/user.ts
import mongoose, { Schema, Document, Types } from 'mongoose';

export interface IUser extends Document {
  _id: Types.ObjectId;
  email: string;
  name?: string;
  image?: string;
  password?: string;  // Only for credentials auth
  emailVerified?: Date;
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    name: { type: String, trim: true },
    image: { type: String },
    password: { type: String, select: false },  // Excluded by default
    emailVerified: { type: Date },
  },
  { timestamps: true }
);

userSchema.index({ email: 1 }, { unique: true });

export const User = mongoose.models.User || mongoose.model<IUser>('User', userSchema);
```

---

## Environment Schema Update

```typescript
// apps/web/src/server/env.ts - add to EnvSchema
const EnvSchema = z.object({
  // ... existing fields
  
  // OAuth (optional per provider)
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  GITHUB_CLIENT_ID: z.string().optional(),
  GITHUB_CLIENT_SECRET: z.string().optional(),
  
  // NextAuth
  NEXTAUTH_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
});
```

---

## OAuth Provider Setup

### Google
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project or select existing
3. APIs & Services → Credentials → Create OAuth Client ID
4. Application type: Web application
5. Authorized redirect URIs: `http://localhost:3000/api/auth/callback/google`
6. Copy Client ID and Client Secret

### GitHub
1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. OAuth Apps → New OAuth App
3. Authorization callback URL: `http://localhost:3000/api/auth/callback/github`
4. Copy Client ID and generate Client Secret

---

## Custom Sign-In Page (Optional)

```tsx
// apps/web/src/app/auth/signin/page.tsx
import { getProviders } from 'next-auth/react';
import { SignInButton } from '@/components/auth/SignInButton';

export default async function SignInPage() {
  const providers = await getProviders();

  return (
    <div className="min-h-screen flex items-center justify-center">
      <div className="p-8 border rounded-lg space-y-4 w-full max-w-sm">
        <h1 className="text-2xl font-bold text-center">Sign In</h1>
        
        {providers &&
          Object.values(providers).map((provider) => (
            <SignInButton
              key={provider.id}
              provider={provider.id as 'google' | 'github'}
            />
          ))}
      </div>
    </div>
  );
}
```

---

## Testing Auth

```typescript
// Mock session for tests
import { vi } from 'vitest';

vi.mock('next-auth', () => ({
  getServerSession: vi.fn(() => Promise.resolve({
    user: { id: 'test-user-id', email: 'test@example.com', name: 'Test User' },
    expires: new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString(),
  })),
}));
```
