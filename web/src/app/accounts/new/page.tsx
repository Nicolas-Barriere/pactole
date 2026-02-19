"use client";

import { useSearchParams, useRouter } from "next/navigation";
import { useState, Suspense } from "react";
import Link from "next/link";
import { api, ApiError } from "@/lib/api";
import { useToast } from "@/components/toast";
import { AccountForm, type AccountFormData } from "@/components/account-form";

function NewAccountContent() {
    const searchParams = useSearchParams();
    const router = useRouter();
    const toast = useToast();

    const [loading, setLoading] = useState(false);
    const initialBank = searchParams.get("bank") || undefined;

    async function handleCreate(data: AccountFormData) {
        try {
            setLoading(true);
            const newAccount = await api.post<{ id: string }>("/accounts", data);
            toast.success("Compte créé avec succès");

            // Navigate back to the import page or to the new account page
            // Assuming if they were redirecting from import with a bank pre-filled,
            // they might want to go back there to complete the upload?
            // Actually, standard behaviour is redirect to accounts list.
            // Easiest is to go to the created account page.
            router.push(`/accounts/${newAccount.id}`);
        } catch (err) {
            if (err instanceof ApiError && err.body) {
                const body = err.body as { errors?: Record<string, string[]> };
                const messages = body.errors
                    ? Object.values(body.errors).flat().join(", ")
                    : "Erreur lors de la création";
                toast.error(messages);
            } else {
                toast.error("Erreur de connexion");
            }
        } finally {
            setLoading(false);
        }
    }

    return (
        <div className="mx-auto max-w-2xl space-y-6">
            <div className="flex items-center gap-4">
                <Link
                    href="/accounts"
                    className="rounded-lg p-2 text-muted transition-colors hover:bg-card hover:text-foreground"
                >
                    <svg className="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M10 19l-7-7m0 0l7-7m-7 7h18" />
                    </svg>
                </Link>
                <div>
                    <h1 className="text-2xl font-bold tracking-tight">Nouveau compte</h1>
                    <p className="text-sm text-muted">Créer un nouveau compte bancaire</p>
                </div>
            </div>

            <AccountForm
                asModal={false}
                loading={loading}
                initialBank={initialBank}
                onSubmit={handleCreate}
            />
        </div>
    );
}

export default function NewAccountPage() {
    return (
        <Suspense fallback={<div className="p-8 text-center text-muted">Chargement...</div>}>
            <NewAccountContent />
        </Suspense>
    );
}
