export interface ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    totalPages?: number;
  };
}

export function ok<T>(data: T, meta?: ApiResponse<T>['meta']): ApiResponse<T> {
  return { success: true, data, meta };
}

export function err(
  code: string,
  message: string,
  details?: Record<string, unknown>,
): ApiResponse<never> {
  return { success: false, error: { code, message, details } };
}

export function paginated<T>(
  items: T[],
  total: number,
  page: number,
  limit: number,
): ApiResponse<T[]> {
  return {
    success: true,
    data: items,
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}
