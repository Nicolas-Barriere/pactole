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

default_tags = [
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
  Enum.map(default_tags, fn attrs ->
    %{
      id: Ecto.UUID.bingenerate(),
      name: attrs.name,
      color: attrs.color,
      inserted_at: now,
      updated_at: now
    }
  end)

if Repo.one(from t in "tags", select: count()) == 0 do
  Repo.insert_all("tags", rows)
  IO.puts("Seeded #{length(rows)} default tags.")
else
  IO.puts("Tags already present, skipping seed.")
end

default_tagging_rules = [
  %{keyword: "CARREFOUR", tag_name: "Alimentation", priority: 80},
  %{keyword: "AUCHAN", tag_name: "Alimentation", priority: 80},
  %{keyword: "LECLERC", tag_name: "Alimentation", priority: 80},
  %{keyword: "MONOPRIX", tag_name: "Alimentation", priority: 80},
  %{keyword: "LIDL", tag_name: "Alimentation", priority: 80},
  %{keyword: "INTERMARCHE", tag_name: "Alimentation", priority: 80},
  %{keyword: "FRANPRIX", tag_name: "Alimentation", priority: 80},
  %{keyword: "PICARD", tag_name: "Alimentation", priority: 80},
  %{keyword: "UBER EATS", tag_name: "Alimentation", priority: 90},
  %{keyword: "DELIVEROO", tag_name: "Alimentation", priority: 90},
  %{keyword: "SNCF", tag_name: "Transport", priority: 90},
  %{keyword: "RATP", tag_name: "Transport", priority: 90},
  %{keyword: "UBER", tag_name: "Transport", priority: 70},
  %{keyword: "BOLT", tag_name: "Transport", priority: 70},
  %{keyword: "BLABLACAR", tag_name: "Transport", priority: 80},
  %{keyword: "TOTALENERGIES", tag_name: "Transport", priority: 75},
  %{keyword: "ESSO", tag_name: "Transport", priority: 70},
  %{keyword: "SHELL", tag_name: "Transport", priority: 70},
  %{keyword: "LOYER", tag_name: "Logement", priority: 100},
  %{keyword: "EDF", tag_name: "Logement", priority: 90},
  %{keyword: "ENGIE", tag_name: "Logement", priority: 90},
  %{keyword: "VEOLIA", tag_name: "Logement", priority: 90},
  %{keyword: "SYNDIC", tag_name: "Logement", priority: 85},
  %{keyword: "PHARMACIE", tag_name: "Santé", priority: 90},
  %{keyword: "DOCTOLIB", tag_name: "Santé", priority: 90},
  %{keyword: "LABORATOIRE", tag_name: "Santé", priority: 85},
  %{keyword: "NETFLIX", tag_name: "Abonnements", priority: 90},
  %{keyword: "SPOTIFY", tag_name: "Abonnements", priority: 90},
  %{keyword: "YOUTUBE PREMIUM", tag_name: "Abonnements", priority: 90},
  %{keyword: "DISNEY+", tag_name: "Abonnements", priority: 90},
  %{keyword: "AMAZON PRIME", tag_name: "Abonnements", priority: 90},
  %{keyword: "OPENAI", tag_name: "Abonnements", priority: 90},
  %{keyword: "FNAC", tag_name: "Loisirs", priority: 80},
  %{keyword: "CULTURA", tag_name: "Loisirs", priority: 80},
  %{keyword: "STEAM", tag_name: "Loisirs", priority: 80},
  %{keyword: "PLAYSTATION", tag_name: "Loisirs", priority: 80},
  %{keyword: "NINTENDO", tag_name: "Loisirs", priority: 80},
  %{keyword: "CINEMA", tag_name: "Loisirs", priority: 70},
  %{keyword: "VIR SEPA SALAIRE", tag_name: "Revenus", priority: 100},
  %{keyword: "SALAIRE", tag_name: "Revenus", priority: 90},
  %{keyword: "PAYROLL", tag_name: "Revenus", priority: 90},
  %{keyword: "DIVIDENDE", tag_name: "Revenus", priority: 85},
  %{keyword: "REMBOURSEMENT IMPOTS", tag_name: "Revenus", priority: 85},
  %{keyword: "LIVRET A", tag_name: "Épargne", priority: 95},
  %{keyword: "ASSURANCE VIE", tag_name: "Épargne", priority: 90},
  %{keyword: "VERSEMENT EPARGNE", tag_name: "Épargne", priority: 90},
  %{keyword: "VIR EPARGNE", tag_name: "Épargne", priority: 90}
]

if Repo.one(from r in "tagging_rules", select: count()) == 0 do
  tags_by_name =
    from(t in "tags", select: {t.name, t.id})
    |> Repo.all()
    |> Map.new()

  rule_rows =
    default_tagging_rules
    |> Enum.map(fn rule ->
      case Map.get(tags_by_name, rule.tag_name) do
        nil ->
          nil

        tag_id ->
          %{
            id: Ecto.UUID.bingenerate(),
            keyword: rule.keyword,
            tag_id: tag_id,
            priority: rule.priority,
            inserted_at: now,
            updated_at: now
          }
      end
    end)
    |> Enum.reject(&is_nil/1)

  if rule_rows != [] do
    Repo.insert_all("tagging_rules", rule_rows)
    IO.puts("Seeded #{length(rule_rows)} default tagging rules.")
  else
    IO.puts("No matching tags found for default tagging rules, skipping seed.")
  end
else
  IO.puts("Tagging rules already present, skipping seed.")
end
