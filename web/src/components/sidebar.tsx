"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { useState, useEffect } from "react";
import { useTheme } from "next-themes";
import { useCurrency } from "@/contexts/currency-context";
import {
  LayoutDashboard,
  Wallet,
  List,
  Tag,
  Upload,
  Menu,
  X,
  Sun,
  Moon,
} from "lucide-react";

const NAV_ITEMS = [
  { href: "/", label: "Tableau de bord", icon: LayoutDashboard },
  { href: "/accounts", label: "Comptes", icon: Wallet },
  { href: "/transactions", label: "Transactions", icon: List },
  { href: "/tags", label: "Tags", icon: Tag },
  { href: "/import", label: "Importer", icon: Upload },
];

export function Sidebar() {
  const pathname = usePathname();
  const [mobileOpen, setMobileOpen] = useState(false);
  const { resolvedTheme, setTheme } = useTheme();
  const {
    baseCurrency,
    setBaseCurrency,
    supportedCurrencies,
    isRatesStale,
    ratesUpdatedAt,
  } = useCurrency();

  useEffect(() => {
    if (!mobileOpen) return;
    const onKey = (e: KeyboardEvent) => {
      if (e.key === "Escape") setMobileOpen(false);
    };
    document.addEventListener("keydown", onKey);
    return () => document.removeEventListener("keydown", onKey);
  }, [mobileOpen]);

  return (
    <>
      {/* Mobile top bar */}
      <header className="fixed inset-x-0 top-0 z-40 flex h-14 items-center gap-3 border-b border-border bg-sidebar px-4 md:hidden">
        <button
          onClick={() => setMobileOpen(true)}
          className="p-1.5 text-muted-foreground hover:text-foreground"
          aria-label="Ouvrir le menu"
        >
          <Menu className="h-5 w-5" />
        </button>
        <span className="text-lg font-bold tracking-tight text-primary">
          Moulax
        </span>
      </header>

      {/* Mobile overlay */}
      {mobileOpen && (
        <div
          className="fixed inset-0 z-50 bg-black/60 md:hidden"
          onClick={() => setMobileOpen(false)}
        />
      )}

      {/* Sidebar panel */}
      <aside
        className={`fixed inset-y-0 left-0 z-50 flex w-60 shrink-0 flex-col border-r border-border bg-sidebar transition-transform duration-200 md:static md:translate-x-0 ${
          mobileOpen ? "translate-x-0" : "-translate-x-full"
        }`}
      >
        {/* Logo */}
        <div className="flex h-14 items-center justify-between border-b border-border px-5 md:h-16">
          <span className="text-xl font-bold tracking-tight text-primary">
            Moulax
          </span>
          <button
            onClick={() => setMobileOpen(false)}
            className="p-1 text-muted-foreground hover:text-foreground md:hidden"
            aria-label="Fermer le menu"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        {/* Navigation */}
        <nav className="flex-1 space-y-1 px-3 py-4">
          {NAV_ITEMS.map((item) => {
            const isActive =
              item.href === "/"
                ? pathname === "/"
                : pathname.startsWith(item.href);

            return (
              <Link
                key={item.href}
                href={item.href}
                onClick={() => setMobileOpen(false)}
                className={`flex items-center gap-3 px-3 py-2 text-sm font-medium transition-colors ${
                  isActive
                    ? "bg-primary/10 text-primary"
                    : "text-muted-foreground hover:bg-accent hover:text-foreground"
                }`}
              >
                <item.icon className="h-5 w-5 shrink-0" />
                {item.label}
              </Link>
            );
          })}
        </nav>

        {/* Footer */}
        <div className="border-t border-border px-5 py-3">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-xs text-muted-foreground">Moulax v1</p>
            <button
              onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
              className="p-1.5 text-muted-foreground transition-colors hover:text-foreground"
              aria-label="Basculer le thème"
            >
              {resolvedTheme === "dark" ? (
                <Sun className="h-4 w-4" />
              ) : (
                <Moon className="h-4 w-4" />
              )}
            </button>
          </div>
          <label
            htmlFor="base-currency"
            className="mb-1 block text-[11px] uppercase tracking-wide text-muted-foreground"
          >
            Devise d&apos;affichage
          </label>
          <div className="flex items-center gap-2">
            <select
              id="base-currency"
              value={baseCurrency}
              onChange={(e) => setBaseCurrency(e.target.value as typeof baseCurrency)}
              className="h-8 w-full border border-border bg-card px-2 text-xs focus:outline-none focus:ring-1 focus:ring-primary"
              aria-label="Sélectionner la devise de base"
            >
              {supportedCurrencies.map((currency) => (
                <option key={currency} value={currency}>
                  {currency}
                </option>
              ))}
            </select>
            {isRatesStale && (
              <span
                className="inline-flex h-2 w-2 rounded-full bg-warning"
                title={
                  ratesUpdatedAt
                    ? `Taux potentiellement obsolètes (maj ${new Date(
                        ratesUpdatedAt,
                      ).toLocaleString("fr-FR")})`
                    : "Taux indisponibles ou obsolètes"
                }
              />
            )}
          </div>
        </div>
      </aside>
    </>
  );
}
