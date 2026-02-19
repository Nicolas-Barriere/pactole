const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL ?? "http://localhost:4001/api/v1";

export class ApiError extends Error {
  constructor(
    public status: number,
    public body: unknown,
  ) {
    super(`API error ${status}`);
    this.name = "ApiError";
  }
}

async function request<T>(
  path: string,
  options: RequestInit = {},
): Promise<T> {
  const url = `${API_BASE_URL}${path}`;

  const res = await fetch(url, {
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      ...options.headers,
    },
    ...options,
  });

  if (!res.ok) {
    const body = await res.json().catch(() => null);
    throw new ApiError(res.status, body);
  }

  if (res.status === 204) return undefined as T;
  return res.json() as Promise<T>;
}

/* ── Convenience methods ─────────────────────────────── */

export const api = {
  get<T>(path: string): Promise<T> {
    return request<T>(path, { method: "GET" });
  },

  post<T>(path: string, body?: unknown): Promise<T> {
    return request<T>(path, {
      method: "POST",
      body: body ? JSON.stringify(body) : undefined,
    });
  },

  put<T>(path: string, body?: unknown): Promise<T> {
    return request<T>(path, {
      method: "PUT",
      body: body ? JSON.stringify(body) : undefined,
    });
  },

  patch<T>(path: string, body?: unknown): Promise<T> {
    return request<T>(path, {
      method: "PATCH",
      body: body ? JSON.stringify(body) : undefined,
    });
  },

  delete<T>(path: string): Promise<T> {
    return request<T>(path, { method: "DELETE" });
  },

  /** Upload a file (multipart/form-data). Content-Type is set by the browser. */
  upload<T>(path: string, formData: FormData): Promise<T> {
    return request<T>(path, {
      method: "POST",
      headers: { Accept: "application/json" },
      body: formData,
    });
  },
};

/* ── Dashboard helpers ──────────────────────────────── */

import type {
  DashboardSummary,
  DashboardSpending,
  DashboardTrends,
  DashboardTopExpenses,
} from "@/types";

export const dashboard = {
  summary: () => api.get<DashboardSummary>("/dashboard/summary"),
  spending: (month: string) =>
    api.get<DashboardSpending>(`/dashboard/spending?month=${month}`),
  trends: (months = 12) =>
    api.get<DashboardTrends>(`/dashboard/trends?months=${months}`),
  topExpenses: (month: string, limit = 5) =>
    api.get<DashboardTopExpenses>(
      `/dashboard/top-expenses?month=${month}&limit=${limit}`,
    ),
};
