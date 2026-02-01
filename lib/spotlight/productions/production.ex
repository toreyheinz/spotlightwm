defmodule Spotlight.Productions.Production do
  use Ecto.Schema
  import Ecto.Changeset

  alias Spotlight.Productions.{Performance, ProductionPhoto}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "productions" do
    field :title, :string
    field :description, :string
    field :location_name, :string
    field :location_query, :string
    field :price, :string
    field :ticket_url, :string
    field :main_image_url, :string
    field :status, Ecto.Enum, values: [:draft, :published, :archived], default: :draft

    has_many :performances, Performance, preload_order: [asc: :starts_at]
    has_many :photos, ProductionPhoto, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(production, attrs) do
    production
    |> cast(attrs, [
      :title,
      :description,
      :location_name,
      :location_query,
      :price,
      :ticket_url,
      :main_image_url,
      :status
    ])
    |> validate_required([:title])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_url(:ticket_url)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) ->
          []

        _ ->
          [{field, "must be a valid URL"}]
      end
    end)
  end
end
