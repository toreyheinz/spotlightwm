defmodule Spotlight.Repo.Migrations.AddSlugToProductions do
  use Ecto.Migration

  def change do
    alter table(:productions) do
      add :slug, :string
    end

    create unique_index(:productions, [:slug])
  end
end
