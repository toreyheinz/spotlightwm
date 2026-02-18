defmodule Spotlight.Uploads do
  @moduledoc """
  Handles file uploads to Cloudflare R2 (S3-compatible) storage.
  """

  @doc """
  Consumes a LiveView upload entry, uploads it to R2 at
  `<prefix>/<subdir>/<uuid>.<ext>`, and returns the public URL path.
  """
  def save(socket, entry, subdir) do
    ext = Path.extname(entry.client_name)
    filename = "#{Ecto.UUID.generate()}#{ext}"
    key = r2_key(subdir, filename)

    Phoenix.LiveView.consume_uploaded_entry(socket, entry, fn %{path: tmp_path} ->
      tmp_path
      |> ExAws.S3.Upload.stream_file()
      |> ExAws.S3.upload(bucket(), key, content_type: MIME.from_path(filename))
      |> ExAws.request!()

      {:ok, "/uploads/#{subdir}/#{filename}"}
    end)
  end

  @doc """
  Deletes a file from R2 (and any local resize cache) given its URL path.
  """
  def delete(url_path) do
    key = url_path_to_key(url_path)
    ExAws.S3.delete_object(bucket(), key) |> ExAws.request()

    # Remove any locally cached resized versions
    cache_base = Path.join(System.tmp_dir!(), "spotlight_image_cache")

    if File.dir?(cache_base) do
      relative = String.replace_prefix(url_path, "/uploads/", "")

      cache_base
      |> File.ls!()
      |> Enum.each(fn width_dir ->
        cached = Path.join([cache_base, width_dir, relative])
        File.rm(cached)
      end)
    end

    :ok
  end

  @doc """
  Downloads a file from R2 to a local temp path. Returns `{:ok, tmp_path}` or `:error`.
  Used by ImageController to fetch originals for resizing.
  """
  def get(url_path) do
    key = url_path_to_key(url_path)

    case ExAws.S3.get_object(bucket(), key) |> ExAws.request() do
      {:ok, %{body: body}} ->
        ext = Path.extname(key)
        tmp_path = Path.join(System.tmp_dir!(), "r2_#{Ecto.UUID.generate()}#{ext}")
        File.write!(tmp_path, body)
        {:ok, tmp_path}

      {:error, _} ->
        :error
    end
  end

  defp bucket, do: Application.get_env(:spotlight, :r2_bucket)
  defp prefix, do: Application.get_env(:spotlight, :uploads_prefix, "dev")

  defp r2_key(subdir, filename), do: "#{prefix()}/#{subdir}/#{filename}"

  defp url_path_to_key(url_path) do
    relative = String.replace_prefix(url_path, "/uploads/", "")
    "#{prefix()}/#{relative}"
  end
end
