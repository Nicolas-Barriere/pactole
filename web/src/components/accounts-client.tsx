"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Plus } from "lucide-react";
import { Button } from "@/components/ui/button";
import { AccountForm, type AccountFormData } from "@/components/account-form";
import { createAccount } from "@/app/actions/accounts";

export function AccountsClient() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  async function handleSubmit(data: AccountFormData) {
    startTransition(async () => {
      const result = await createAccount(data);
      if (result.success) {
        toast.success("Compte créé avec succès");
        setOpen(false);
        router.refresh();
      } else {
        toast.error(result.error);
      }
    });
  }

  return (
    <>
      <Button onClick={() => setOpen(true)}>
        <Plus className="mr-2 h-4 w-4" />
        Nouveau compte
      </Button>

      <AccountForm
        key={open ? "open" : "closed"}
        open={open}
        loading={isPending}
        onSubmit={handleSubmit}
        onClose={() => setOpen(false)}
      />
    </>
  );
}
