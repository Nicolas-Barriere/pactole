"use server";

import { revalidatePath } from "next/cache";
import { serverApi, ServerApiError } from "@/lib/server-api";
import type { Account, AccountType } from "@/types";

export interface AccountFormData {
  name: string;
  bank: string;
  type: AccountType;
  initial_balance: string;
  currency: string;
}

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

export async function createAccount(
  data: AccountFormData,
): Promise<ActionResult<Account>> {
  try {
    const account = await serverApi.post<Account>("/accounts", data);
    revalidatePath("/accounts");
    revalidatePath("/");
    return { success: true, data: account };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function updateAccount(
  id: string,
  data: Partial<AccountFormData>,
): Promise<ActionResult<Account>> {
  try {
    const account = await serverApi.put<Account>(`/accounts/${id}`, data);
    revalidatePath(`/accounts/${id}`);
    revalidatePath("/accounts");
    revalidatePath("/");
    return { success: true, data: account };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}

export async function archiveAccount(id: string): Promise<ActionResult> {
  try {
    await serverApi.delete(`/accounts/${id}`);
    revalidatePath("/accounts");
    revalidatePath("/");
    return { success: true };
  } catch (err) {
    return { success: false, error: extractError(err) };
  }
}
