import mongoose from "mongoose";
import { env } from "../env";

declare global {
  var __mongooseConn:
    | { conn: typeof mongoose | null; promise: Promise<typeof mongoose> | null }
    | undefined;
}

const globalRef = globalThis as typeof globalThis & {
  __mongooseConn?: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
};

export async function connectMongoose() {
  const e = env();
  if (!globalRef.__mongooseConn)
    globalRef.__mongooseConn = { conn: null, promise: null };

  if (globalRef.__mongooseConn.conn) return globalRef.__mongooseConn.conn;

  if (!globalRef.__mongooseConn.promise) {
    globalRef.__mongooseConn.promise = mongoose.connect(e.MONGODB_URI, {
      serverSelectionTimeoutMS: 5000,
    });
  }

  globalRef.__mongooseConn.conn = await globalRef.__mongooseConn.promise;
  return globalRef.__mongooseConn.conn;
}
