"use client";

import { useState, useTransition } from "react";
import { useRouter } from "next/navigation";
import { toast } from "sonner";
import { Pencil, Archive } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { AccountForm, type AccountFormData } from "@/components/account-form";
import { ConfirmDialog } from "@/components/confirm-dialog";
import { updateAccount, archiveAccount } from "@/app/actions/accounts";
import { formatAmount } from "@/lib/format";
import type { Account } from "@/types";

interface AccountActionsProps {
  account: Account;
}

export function AccountActions({ account }: AccountActionsProps) {
  const router = useRouter();
  const [editOpen, setEditOpen] = useState(false);
  const [archiveOpen, setArchiveOpen] = useState(false);
  const [isPending, startTransition] = useTransition();

  function handleEdit(data: AccountFormData) {
    startTransition(async () => {
      const result = await updateAccount(account.id, data);
      if (result.success) {
        toast.success("Compte modifié avec succès");
        setEditOpen(false);
        router.refresh();
      } else {
        toast.error(result.error);
      }
    });
  }

  function handleArchive() {
    startTransition(async () => {
      const result = await archiveAccount(account.id);
      if (result.success) {
        toast.success("Compte archivé avec succès");
        router.push("/accounts");
      } else {
        toast.error(result.error);
        setArchiveOpen(false);
      }
    });
  }

  return (
    <>
      <div className="flex gap-2">
        <Button
          variant="outline"
          size="sm"
          onClick={() => setEditOpen(true)}
        >
          <Pencil className="mr-2 h-4 w-4" />
          Modifier
        </Button>
        <Button
          variant="outline"
          size="sm"
          className="border-destructive/30 text-destructive hover:bg-destructive/10"
          onClick={() => setArchiveOpen(true)}
        >
          <Archive className="mr-2 h-4 w-4" />
          Archiver
        </Button>
      </div>

      <AccountForm
        key={editOpen ? `edit-${account.id}` : "closed"}
        open={editOpen}
        account={account}
        loading={isPending}
        onSubmit={handleEdit}
        onClose={() => setEditOpen(false)}
      />

      <ConfirmDialog
        open={archiveOpen}
        title="Archiver ce compte ?"
        description="Le compte sera masqué de la liste. Les transactions existantes seront conservées. Cette action est réversible."
        confirmLabel="Archiver"
        variant="danger"
        loading={isPending}
        onConfirm={handleArchive}
        onCancel={() => setArchiveOpen(false)}
      />
    </>
  );
}

interface BalanceEditorProps {
  account: Account;
}

export function BalanceEditor({ account }: BalanceEditorProps) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [value, setValue] = useState(account.initial_balance);
  const [isPending, startTransition] = useTransition();

  function save() {
    const trimmed = value.trim();
    if (!trimmed || isNaN(parseFloat(trimmed))) {
      setEditing(false);
      return;
    }
    if (trimmed === account.initial_balance) {
      setEditing(false);
      return;
    }
    startTransition(async () => {
      const result = await updateAccount(account.id, {
        name: account.name,
        bank: account.bank,
        type: account.type,
        initial_balance: trimmed,
        currency: account.currency,
      });
      if (result.success) {
        toast.success("Solde initial modifié");
        setEditing(false);
        router.refresh();
      } else {
        toast.error(result.error);
        setEditing(false);
      }
    });
  }

  function handleKeyDown(e: React.KeyboardEvent) {
    if (e.key === "Enter") {
      e.preventDefault();
      save();
    } else if (e.key === "Escape") {
      setEditing(false);
    }
  }

  if (editing) {
    return (
      <Input
        type="number"
        step="0.01"
        value={value}
        onChange={(e) => setValue(e.target.value)}
        onBlur={save}
        onKeyDown={handleKeyDown}
        autoFocus
        disabled={isPending}
        className="h-7 w-28 py-0 text-sm"
      />
    );
  }

  return (
    <button
      onClick={() => { setValue(account.initial_balance); setEditing(true); }}
      className="inline-flex items-center gap-1 px-1 py-0.5 text-foreground transition-colors hover:bg-accent"
      title="Modifier le solde initial"
    >
      {formatAmount(account.initial_balance, account.currency)}
      <Pencil className="h-3 w-3 text-muted-foreground" />
    </button>
  );
}
