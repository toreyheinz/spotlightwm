defmodule Spotlight.Productions.Performance do
  use Ecto.Schema
  import Ecto.Changeset

  alias Spotlight.Productions.Production

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "performances" do
    field :starts_at, :utc_datetime
    field :ends_at, :utc_datetime
    field :notes, :string
    field :ticket_url, :string

    belongs_to :production, Production

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(performance, attrs) do
    performance
    |> cast(attrs, [:starts_at, :ends_at, :notes, :ticket_url, :production_id])
    |> validate_required([:starts_at, :production_id])
    |> validate_end_after_start()
    |> validate_url(:ticket_url)
    |> foreign_key_constraint(:production_id)
  end

  defp validate_url(changeset, field) do
    validate_change(changeset, field, fn _, url ->
      case URI.parse(url) do
        %URI{scheme: scheme, host: host} when scheme in ["http", "https"] and not is_nil(host) -> []
        _ -> [{field, "must be a valid URL"}]
      end
    end)
  end

  defp validate_end_after_start(changeset) do
    starts_at = get_field(changeset, :starts_at)
    ends_at = get_field(changeset, :ends_at)

    if starts_at && ends_at && DateTime.compare(ends_at, starts_at) == :lt do
      add_error(changeset, :ends_at, "must be after start time")
    else
      changeset
    end
  end
end
