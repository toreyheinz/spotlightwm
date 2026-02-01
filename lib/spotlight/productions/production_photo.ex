defmodule Spotlight.Productions.ProductionPhoto do
  use Ecto.Schema
  import Ecto.Changeset

  alias Spotlight.Productions.Production

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "production_photos" do
    field :url, :string
    field :caption, :string
    field :position, :integer, default: 0

    belongs_to :production, Production

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [:url, :caption, :position, :production_id])
    |> validate_required([:url, :production_id])
    |> foreign_key_constraint(:production_id)
  end
end
