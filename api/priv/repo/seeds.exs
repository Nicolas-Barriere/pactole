# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Moulax.Repo.insert!(%Moulax.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Moulax.Repo
import Ecto.Query

# Default categories for V1 (see V1_SPEC.md and gh issue #4)
default_categories = [
  %{name: "Alimentation", color: "#4CAF50"},
  %{name: "Transport", color: "#2196F3"},
  %{name: "Logement", color: "#FF9800"},
  %{name: "Loisirs", color: "#9C27B0"},
  %{name: "Santé", color: "#F44336"},
  %{name: "Abonnements", color: "#607D8B"},
  %{name: "Revenus", color: "#8BC34A"},
  %{name: "Épargne", color: "#00BCD4"},
  %{name: "Autres", color: "#795548"}
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

rows =
  Enum.map(default_categories, fn attrs ->
    %{
      id: Ecto.UUID.bingenerate(),
      name: attrs.name,
      color: attrs.color,
      inserted_at: now,
      updated_at: now
    }
  end)

# Only insert if no categories exist (idempotent seed)
if Repo.one(from c in "categories", select: count()) == 0 do
  Repo.insert_all("categories", rows)
  IO.puts("Seeded #{length(rows)} default categories.")
else
  IO.puts("Categories already present, skipping seed.")
end
