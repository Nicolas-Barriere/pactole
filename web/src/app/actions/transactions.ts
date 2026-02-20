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

export async function createTransaction(
  accountId: string,
  data: { date: string; label: string; amount: string; tag_ids: string[] },
): Promise<ActionResult> {
  try {
    await serverApi.post(`/accounts/${accountId}/transactions`, data);
    revalidatePath("/transactions");
    revalidatePath(`/accounts/${accountId}`);
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function updateTransactionTags(
  txId: string,
  tagIds: string[],
): Promise<ActionResult> {
  try {
    await serverApi.put(`/transactions/${txId}`, { tag_ids: tagIds });
    revalidatePath("/transactions");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function bulkTagTransactions(
  transactionIds: string[],
  tagIds: string[],
): Promise<ActionResult> {
  try {
    await serverApi.patch("/transactions/bulk-tag", {
      transaction_ids: transactionIds,
      tag_ids: tagIds,
    });
    revalidatePath("/transactions");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}
