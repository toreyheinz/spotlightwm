defmodule SpotlightWeb.ImageController do
  use SpotlightWeb, :controller

  @allowed_widths [200, 400, 800, 1200, 1600]

  @content_types %{
    ".jpg" => "image/jpeg",
    ".jpeg" => "image/jpeg",
    ".png" => "image/png",
    ".webp" => "image/webp",
    ".gif" => "image/gif"
  }

  def show(conn, %{"width" => width_str, "path" => path_parts}) do
    with {width, ""} <- Integer.parse(width_str),
         true <- width in @allowed_widths,
         relative <- path_parts |> strip_uploads_prefix() |> Path.join(),
         false <- String.contains?(relative, "..") do
      uploads_dir = Spotlight.Uploads.uploads_dir()
      original = Path.join(uploads_dir, relative)
      cache_dir = Path.join([uploads_dir, "_cache", "w#{width}"])
      cached = Path.join(cache_dir, relative)
      ext = Path.extname(relative) |> String.downcase()
      content_type = Map.get(@content_types, ext, "application/octet-stream")

      cond do
        File.exists?(cached) ->
          conn
          |> put_resp_content_type(content_type)
          |> send_file(200, cached)

        File.exists?(original) ->
          File.mkdir_p!(Path.dirname(cached))

          {_, 0} =
            System.cmd("convert", [
              original,
              "-resize",
              "#{width}x",
              "-quality",
              "85",
              cached
            ])

          conn
          |> put_resp_content_type(content_type)
          |> send_file(200, cached)

        true ->
          send_resp(conn, 404, "Not found")
      end
    else
      _ -> send_resp(conn, 400, "Bad request")
    end
  end

  defp strip_uploads_prefix(["uploads" | rest]), do: rest
  defp strip_uploads_prefix(parts), do: parts
end
