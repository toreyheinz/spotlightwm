defmodule Spotlight.Repo.Migrations.CreateProductions do
  use Ecto.Migration

  def change do
    create_query = "CREATE TYPE production_status AS ENUM ('draft', 'published', 'archived')"
    drop_query = "DROP TYPE production_status"
    execute(create_query, drop_query)

    create table(:productions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :title, :string, null: false
      add :description, :text
      add :location_name, :string
      add :location_query, :string
      add :price, :string
      add :ticket_url, :string
      add :main_image_url, :string
      add :status, :production_status, null: false, default: "draft"

      timestamps(type: :utc_datetime)
    end

    create index(:productions, [:status])

    create table(:performances, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :production_id, references(:productions, type: :binary_id, on_delete: :delete_all),
        null: false
      add :starts_at, :utc_datetime, null: false
      add :ends_at, :utc_datetime
      add :notes, :string

      timestamps(type: :utc_datetime)
    end

    create index(:performances, [:production_id])
    create index(:performances, [:starts_at])

    create table(:production_photos, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :production_id, references(:productions, type: :binary_id, on_delete: :delete_all),
        null: false
      add :url, :string, null: false
      add :caption, :string
      add :position, :integer, null: false, default: 0

      timestamps(type: :utc_datetime)
    end

    create index(:production_photos, [:production_id])
    create index(:production_photos, [:production_id, :position])
  end
end
