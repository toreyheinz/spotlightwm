defmodule Spotlight.Productions do
  @moduledoc """
  The Productions context.
  """

  import Ecto.Query, warn: false
  alias Spotlight.Repo

  alias Spotlight.Productions.{Production, Performance, ProductionPhoto}

  @archive_after_days 180

  ## Productions

  @doc """
  Returns the list of productions.
  """
  def list_productions do
    Repo.all(from p in Production, order_by: [desc: p.inserted_at])
  end

  @doc """
  Returns productions for the public site.
  Only published productions, with current/upcoming first.
  """
  def list_public_productions do
    now = DateTime.utc_now()
    archive_cutoff = DateTime.add(now, -@archive_after_days, :day)

    from(p in Production,
      where: p.status == :published,
      left_join: perf in assoc(p, :performances),
      group_by: p.id,
      having: max(perf.starts_at) > ^archive_cutoff or is_nil(max(perf.starts_at)),
      preload: [:performances, :photos],
      order_by: [desc: max(perf.starts_at)]
    )
    |> Repo.all()
  end

  @doc """
  Returns current/upcoming productions (with performances in the future).
  """
  def list_upcoming_productions do
    now = DateTime.utc_now()

    from(p in Production,
      where: p.status == :published,
      join: perf in assoc(p, :performances),
      where: perf.starts_at >= ^now,
      group_by: p.id,
      order_by: [asc: min(perf.starts_at)],
      preload: [:performances, :photos]
    )
    |> Repo.all()
  end

  @doc """
  Returns past productions (within the archive window).
  """
  def list_past_productions do
    now = DateTime.utc_now()
    archive_cutoff = DateTime.add(now, -@archive_after_days, :day)

    from(p in Production,
      where: p.status == :published,
      join: perf in assoc(p, :performances),
      group_by: p.id,
      having: max(perf.starts_at) < ^now and max(perf.starts_at) > ^archive_cutoff,
      preload: [:performances, :photos],
      order_by: [desc: max(perf.starts_at)]
    )
    |> Repo.all()
  end

  @doc """
  Gets a single production.

  Raises `Ecto.NoResultsError` if the Production does not exist.
  """
  def get_production!(id), do: Repo.get!(Production, id)

  @doc """
  Gets a production with all associations preloaded.
  """
  def get_production_with_details!(id) do
    Production
    |> Repo.get!(id)
    |> Repo.preload([:performances, :photos])
  end

  @doc """
  Creates a production.
  """
  def create_production(attrs \\ %{}) do
    %Production{}
    |> Production.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a production.
  """
  def update_production(%Production{} = production, attrs) do
    production
    |> Production.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a production.
  """
  def delete_production(%Production{} = production) do
    Repo.delete(production)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking production changes.
  """
  def change_production(%Production{} = production, attrs \\ %{}) do
    Production.changeset(production, attrs)
  end

  ## Performances

  @doc """
  Creates a performance for a production.
  """
  def create_performance(%Production{} = production, attrs \\ %{}) do
    %Performance{}
    |> Performance.changeset(Map.put(attrs, "production_id", production.id))
    |> Repo.insert()
  end

  @doc """
  Updates a performance.
  """
  def update_performance(%Performance{} = performance, attrs) do
    performance
    |> Performance.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a performance.
  """
  def delete_performance(%Performance{} = performance) do
    Repo.delete(performance)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking performance changes.
  """
  def change_performance(%Performance{} = performance, attrs \\ %{}) do
    Performance.changeset(performance, attrs)
  end

  ## Production Photos

  @doc """
  Creates a production photo.
  """
  def create_production_photo(%Production{} = production, attrs \\ %{}) do
    # Get the next position
    max_position =
      Repo.one(
        from pp in ProductionPhoto,
          where: pp.production_id == ^production.id,
          select: max(pp.position)
      ) || -1

    %ProductionPhoto{}
    |> ProductionPhoto.changeset(
      attrs
      |> Map.put("production_id", production.id)
      |> Map.put_new("position", max_position + 1)
    )
    |> Repo.insert()
  end

  @doc """
  Updates a production photo.
  """
  def update_production_photo(%ProductionPhoto{} = photo, attrs) do
    photo
    |> ProductionPhoto.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a production photo.
  """
  def delete_production_photo(%ProductionPhoto{} = photo) do
    Repo.delete(photo)
  end

  @doc """
  Reorders photos for a production.
  """
  def reorder_photos(production_id, photo_ids) when is_list(photo_ids) do
    Repo.transaction(fn ->
      photo_ids
      |> Enum.with_index()
      |> Enum.each(fn {photo_id, position} ->
        from(pp in ProductionPhoto,
          where: pp.id == ^photo_id and pp.production_id == ^production_id
        )
        |> Repo.update_all(set: [position: position])
      end)
    end)
  end

  ## Helpers

  @doc """
  Returns the opening night (first performance) for a production.
  """
  def opening_night(%Production{performances: performances}) when is_list(performances) do
    performances
    |> Enum.min_by(& &1.starts_at, DateTime, fn -> nil end)
  end

  def opening_night(%Production{} = production) do
    production
    |> Repo.preload(:performances)
    |> opening_night()
  end

  @doc """
  Returns the closing night (last performance) for a production.
  """
  def closing_night(%Production{performances: performances}) when is_list(performances) do
    performances
    |> Enum.max_by(& &1.starts_at, DateTime, fn -> nil end)
  end

  def closing_night(%Production{} = production) do
    production
    |> Repo.preload(:performances)
    |> closing_night()
  end

  @doc """
  Formats performance dates as a range string.
  Groups consecutive dates and formats them nicely.

  Example: "Feb 7-8, 14-15, 2025"
  """
  def format_date_range(%Production{performances: []}) do
    nil
  end

  def format_date_range(%Production{performances: performances}) when is_list(performances) do
    performances
    |> Enum.map(& &1.starts_at)
    |> Enum.sort(DateTime)
    |> group_consecutive_dates()
    |> format_grouped_dates()
  end

  def format_date_range(%Production{} = production) do
    production
    |> Repo.preload(:performances)
    |> format_date_range()
  end

  defp group_consecutive_dates(dates) do
    dates
    |> Enum.map(&DateTime.to_date/1)
    |> Enum.uniq()
    |> Enum.chunk_while(
      [],
      fn date, acc ->
        case acc do
          [] ->
            {:cont, [date]}

          [prev | _] ->
            if Date.diff(date, prev) == 1 do
              {:cont, [date | acc]}
            else
              {:cont, Enum.reverse(acc), [date]}
            end
        end
      end,
      fn
        [] -> {:cont, []}
        acc -> {:cont, Enum.reverse(acc), []}
      end
    )
  end

  defp format_grouped_dates([]), do: nil

  defp format_grouped_dates(groups) do
    year = groups |> List.last() |> List.last() |> Map.get(:year)

    formatted =
      groups
      |> Enum.map(&format_date_group/1)
      |> Enum.join(", ")

    "#{formatted}, #{year}"
  end

  defp format_date_group([single]) do
    Calendar.strftime(single, "%b %-d")
  end

  defp format_date_group(dates) do
    first = List.first(dates)
    last = List.last(dates)

    if first.month == last.month do
      "#{Calendar.strftime(first, "%b")} #{first.day}-#{last.day}"
    else
      "#{Calendar.strftime(first, "%b %-d")}-#{Calendar.strftime(last, "%b %-d")}"
    end
  end
end
