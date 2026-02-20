"use server";

import { revalidatePath } from "next/cache";
import { serverApi, ServerApiError } from "@/lib/server-api";

type ActionResult<T = void> =
  | { success: true; data?: T }
  | { success: false; error: string };

function extractError(err: unknown): string {
  if (err instanceof ServerApiError && err.body) {
    const body = err.body as { errors?: Record<string, string[]> };
    if (body.errors) {
      return Object.values(body.errors).flat().join(", ");
    }
  }
  return "Erreur de connexion";
}

export async function createTag(data: {
  name: string;
  color: string;
}): Promise<ActionResult> {
  try {
    await serverApi.post("/tags", data);
    revalidatePath("/tags");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function updateTag(
  id: string,
  data: { name: string; color: string },
): Promise<ActionResult> {
  try {
    await serverApi.put(`/tags/${id}`, data);
    revalidatePath("/tags");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function deleteTag(id: string): Promise<ActionResult> {
  try {
    await serverApi.delete(`/tags/${id}`);
    revalidatePath("/tags");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function createRule(data: {
  keyword: string;
  tag_id: string;
  priority: number;
}): Promise<ActionResult> {
  try {
    await serverApi.post("/tagging-rules", data);
    revalidatePath("/tags");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function updateRule(
  id: string,
  data: { keyword: string; tag_id: string; priority: number },
): Promise<ActionResult> {
  try {
    await serverApi.put(`/tagging-rules/${id}`, data);
    revalidatePath("/tags");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function deleteRule(id: string): Promise<ActionResult> {
  try {
    await serverApi.delete(`/tagging-rules/${id}`);
    revalidatePath("/tags");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function reapplyRules(): Promise<
  ActionResult<{ tagged_count: number }>
> {
  try {
    const res = await serverApi.post<{ tagged_count: number }>(
      "/tagging-rules/apply",
    );
    revalidatePath("/transactions");
    revalidatePath("/tags");
    return { success: true, data: res };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}
