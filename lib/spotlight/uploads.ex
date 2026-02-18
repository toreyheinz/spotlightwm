defmodule Spotlight.Uploads do
  @moduledoc """
  Handles file uploads to disk storage.
  """

  @doc """
  Returns the configured uploads directory.
  """
  def uploads_dir do
    Application.get_env(:spotlight, :uploads_dir, "uploads")
  end

  @doc """
  Consumes a LiveView upload entry, saves it to `<uploads_dir>/<subdir>/<uuid>.<ext>`,
  and returns the public URL path.
  """
  def save(socket, entry, subdir) do
    ext = Path.extname(entry.client_name)
    filename = "#{Ecto.UUID.generate()}#{ext}"
    dest_dir = Path.join([uploads_dir(), subdir])
    dest = Path.join(dest_dir, filename)

    File.mkdir_p!(dest_dir)

    Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
      File.cp!(tmp_path, dest)
      {:ok, "/uploads/#{subdir}/#{filename}"}
    end)
  end

  @doc """
  Deletes the original file and any cached resized versions for the given URL path.
  """
  def delete(url_path) do
    # Strip the leading /uploads/ to get the relative path
    relative = String.replace_prefix(url_path, "/uploads/", "")
    original = Path.join(uploads_dir(), relative)

    File.rm(original)

    # Remove any cached resized versions
    cache_dir = Path.join(uploads_dir(), "_cache")

    if File.dir?(cache_dir) do
      cache_dir
      |> File.ls!()
      |> Enum.each(fn width_dir ->
        cached = Path.join([cache_dir, width_dir, relative])
        File.rm(cached)
      end)
    end

    :ok
  end
end
