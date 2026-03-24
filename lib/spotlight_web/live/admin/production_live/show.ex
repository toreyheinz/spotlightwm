defmodule SpotlightWeb.Admin.ProductionLive.Show do
  use SpotlightWeb, :live_view

  alias Spotlight.Productions
  alias Spotlight.Uploads

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:main_image, accept: ~w(.jpg .jpeg .png .webp), max_entries: 1, max_file_size: 10_000_000)
     |> allow_upload(:photos, accept: ~w(.jpg .jpeg .png .webp), max_entries: 10, max_file_size: 10_000_000)}
  end

  @impl true
  def handle_params(params, _, socket) do
    production = Productions.get_production_with_details!(params["id"])

    performance =
      case socket.assigns.live_action do
        :add_performance ->
          %Spotlight.Productions.Performance{}

        :edit_performance ->
          Productions.get_performance!(params["performance_id"])

        _ ->
          nil
      end

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, production))
     |> assign(:production, production)
     |> assign(:performance, performance)}
  end

  @impl true
  def handle_info({SpotlightWeb.Admin.ProductionLive.FormComponent, {:saved, production}}, socket) do
    production = Productions.get_production_with_details!(production.id)
    {:noreply, assign(socket, :production, production)}
  end

  def handle_info({SpotlightWeb.Admin.ProductionLive.PerformanceFormComponent, {:performance_saved, _performance}}, socket) do
    production = Productions.get_production_with_details!(socket.assigns.production.id)
    {:noreply, assign(socket, :production, production)}
  end

  @impl true
  def handle_event("delete_performance", %{"id" => id}, socket) do
    performance = Enum.find(socket.assigns.production.performances, &(&1.id == id))

    if performance do
      {:ok, _} = Productions.delete_performance(performance)
      production = Productions.get_production_with_details!(socket.assigns.production.id)
      {:noreply, assign(socket, :production, production)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_main_image", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_main_image", _params, socket) do
    production = socket.assigns.production
    subdir = "productions/#{production.id}"

    [url] =
      for entry <- socket.assigns.uploads.main_image.entries do
        Uploads.save(socket, entry, subdir)
      end

    # Delete old image if present
    if production.main_image_url, do: Uploads.delete(production.main_image_url)

    {:ok, production} = Productions.update_production(production, %{main_image_url: url})
    production = Productions.get_production_with_details!(production.id)

    {:noreply, assign(socket, :production, production)}
  end

  def handle_event("delete_main_image", _params, socket) do
    production = socket.assigns.production

    if production.main_image_url do
      Uploads.delete(production.main_image_url)
      {:ok, production} = Productions.update_production(production, %{main_image_url: nil})
      production = Productions.get_production_with_details!(production.id)
      {:noreply, assign(socket, :production, production)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("validate_photos", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("save_photos", _params, socket) do
    production = socket.assigns.production
    subdir = "productions/#{production.id}"

    urls =
      for entry <- socket.assigns.uploads.photos.entries do
        Uploads.save(socket, entry, subdir)
      end

    Enum.each(urls, fn url ->
      Productions.create_production_photo(production, %{"url" => url})
    end)

    production = Productions.get_production_with_details!(production.id)
    {:noreply, assign(socket, :production, production)}
  end

  def handle_event("delete_photo", %{"id" => id}, socket) do
    photo = Enum.find(socket.assigns.production.photos, &(&1.id == id))

    if photo do
      Uploads.delete(photo.url)
      Productions.delete_production_photo(photo)
      production = Productions.get_production_with_details!(socket.assigns.production.id)
      {:noreply, assign(socket, :production, production)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("cancel_upload", %{"ref" => ref, "upload" => upload}, socket) do
    {:noreply, cancel_upload(socket, String.to_existing_atom(upload), ref)}
  end

  defp page_title(:show, production), do: production.title
  defp page_title(:edit, production), do: "Edit #{production.title}"
  defp page_title(:add_performance, production), do: "#{production.title} — Add Performance"
  defp page_title(:edit_performance, production), do: "#{production.title} — Edit Performance"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 text-gray-800">
      <div class="flex justify-between items-start mb-8">
        <div>
          <.link navigate={~p"/admin/productions"} class="text-sm text-gray-600 hover:text-gray-900 mb-2 inline-block">
            ← Back to Productions
          </.link>
          <h1 class="text-3xl font-bold text-gray-900">{@production.title}</h1>
          <div class="mt-2">
            <span class={[
              "badge",
              @production.status == :published && "badge-success",
              @production.status == :draft && "badge-warning",
              @production.status == :archived && "badge-ghost"
            ]}>
              {@production.status}
            </span>
          </div>
        </div>
        <.link patch={~p"/admin/productions/#{@production.id}/edit"} class="btn btn-primary">
          Edit Production
        </.link>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-8">
        <div class="lg:col-span-2 space-y-8">
          <%!-- Details --%>
          <div class="card bg-white shadow">
            <div class="card-body">
              <h2 class="card-title">Details</h2>
              <div class="space-y-4">
                <%= if @production.description do %>
                  <div>
                    <label class="text-sm font-medium text-gray-600">Description</label>
                    <div class="rich-text">{raw(@production.description)}</div>
                  </div>
                <% end %>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="text-sm font-medium text-gray-600">Location</label>
                    <p>{@production.location_name || "Not set"}</p>
                  </div>
                  <div>
                    <label class="text-sm font-medium text-gray-600">Price</label>
                    <p>{@production.price || "Not set"}</p>
                  </div>
                </div>

                <%= if @production.ticket_url do %>
                  <div>
                    <label class="text-sm font-medium text-gray-600">Ticket URL</label>
                    <p>
                      <a href={@production.ticket_url} target="_blank" class="link">
                        {@production.ticket_url}
                      </a>
                    </p>
                  </div>
                <% end %>
              </div>
            </div>
          </div>

          <%!-- Performances --%>
          <div class="card bg-white shadow">
            <div class="card-body">
              <div class="flex justify-between items-center">
                <h2 class="card-title">Performances</h2>
                <.link patch={~p"/admin/productions/#{@production.id}/performances/new"} class="btn btn-sm btn-outline">
                  Add Performance
                </.link>
              </div>

              <%= if Enum.empty?(@production.performances) do %>
                <p class="text-gray-600">No performances scheduled yet.</p>
              <% else %>
                <div class="overflow-x-auto">
                  <table class="table text-gray-800">
                    <thead class="bg-gray-100">
                      <tr class="text-gray-700">
                        <th>Date & Time</th>
                        <th>Notes</th>
                        <th>Tickets</th>
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for perf <- @production.performances do %>
                        <tr>
                          <td>
                            {Calendar.strftime(perf.starts_at, "%a, %b %-d, %Y at %-I:%M %p")}
                          </td>
                          <td class="text-gray-600">{perf.notes}</td>
                          <td>
                            <%= if perf.ticket_url do %>
                              <a href={perf.ticket_url} target="_blank" class="link text-sm">Link</a>
                            <% end %>
                          </td>
                          <td class="flex gap-1">
                            <.link
                              patch={~p"/admin/productions/#{@production.id}/performances/#{perf.id}/edit"}
                              class="btn btn-xs btn-ghost"
                            >
                              Edit
                            </.link>
                            <button
                              phx-click="delete_performance"
                              phx-value-id={perf.id}
                              data-confirm="Delete this performance?"
                              class="btn btn-xs btn-ghost text-error"
                            >
                              Delete
                            </button>
                          </td>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                </div>
              <% end %>

              <p class="text-sm text-gray-600 mt-2">
                Date range: {Productions.format_date_range(@production) || "N/A"}
              </p>
            </div>
          </div>
        </div>

        <div class="space-y-8">
          <%!-- Main Image --%>
          <div class="card bg-white shadow">
            <div class="card-body">
              <h2 class="card-title">Main Image</h2>
              <%= if @production.main_image_url do %>
                <img src={"/images/w/800#{@production.main_image_url}"} alt={@production.title} class="rounded-lg" />
                <button
                  phx-click="delete_main_image"
                  data-confirm="Remove the main image?"
                  class="btn btn-sm btn-error btn-outline mt-2"
                >
                  Remove Image
                </button>
              <% else %>
                <div class="bg-gray-200 rounded-lg aspect-video flex items-center justify-center">
                  <span class="text-gray-500">No image uploaded</span>
                </div>
              <% end %>

              <form id="main-image-upload" phx-submit="save_main_image" phx-change="validate_main_image" class="mt-2">
                <.live_file_input upload={@uploads.main_image} class="file-input file-input-bordered file-input-sm w-full" />

                <%= for entry <- @uploads.main_image.entries do %>
                  <div class="mt-2 space-y-1">
                    <div class="flex items-center gap-2">
                      <.live_img_preview entry={entry} class="w-20 h-20 object-cover rounded" />
                      <div class="flex-1">
                        <p class="text-sm truncate">{entry.client_name}</p>
                        <progress class="progress progress-primary w-full" value={entry.progress} max="100">
                          {entry.progress}%
                        </progress>
                      </div>
                      <button type="button" phx-click="cancel_upload" phx-value-ref={entry.ref} phx-value-upload="main_image" class="btn btn-xs btn-ghost">
                        ✕
                      </button>
                    </div>
                    <%= for err <- upload_errors(@uploads.main_image, entry) do %>
                      <p class="text-error text-xs">{error_to_string(err)}</p>
                    <% end %>
                  </div>
                <% end %>

                <%= for err <- upload_errors(@uploads.main_image) do %>
                  <p class="text-error text-xs mt-1">{error_to_string(err)}</p>
                <% end %>

                <%= if @uploads.main_image.entries != [] do %>
                  <button type="submit" class="btn btn-sm btn-primary mt-2">Upload</button>
                <% end %>
              </form>
            </div>
          </div>

          <%!-- Photos --%>
          <div class="card bg-white shadow">
            <div class="card-body">
              <h2 class="card-title">Production Photos</h2>
              <%= if Enum.empty?(@production.photos) do %>
                <p class="text-gray-600">No photos uploaded yet.</p>
              <% else %>
                <div class="grid grid-cols-2 gap-2">
                  <%= for photo <- @production.photos do %>
                    <div class="relative group min-h-24 bg-gray-100 rounded-lg">
                      <img src={"/images/w/400#{photo.url}"} alt={photo.caption} class="rounded-lg w-full aspect-square object-cover" />
                      <button
                        phx-click="delete_photo"
                        phx-value-id={photo.id}
                        data-confirm="Delete this photo?"
                        class="btn btn-xs btn-circle btn-error absolute top-1 right-1 opacity-0 group-hover:opacity-100 transition-opacity"
                      >
                        ✕
                      </button>
                    </div>
                  <% end %>
                </div>
              <% end %>

              <form id="photos-upload" phx-submit="save_photos" phx-change="validate_photos" class="mt-2">
                <.live_file_input upload={@uploads.photos} class="file-input file-input-bordered file-input-sm w-full" />

                <%= if @uploads.photos.entries != [] do %>
                  <div class="grid grid-cols-3 gap-2 mt-2">
                    <%= for entry <- @uploads.photos.entries do %>
                      <div class="relative">
                        <.live_img_preview entry={entry} class="w-full aspect-square object-cover rounded" />
                        <progress class="progress progress-primary progress-xs w-full" value={entry.progress} max="100">
                          {entry.progress}%
                        </progress>
                        <button
                          type="button"
                          phx-click="cancel_upload"
                          phx-value-ref={entry.ref}
                          phx-value-upload="photos"
                          class="btn btn-xs btn-circle btn-ghost absolute top-0 right-0"
                        >
                          ✕
                        </button>
                        <%= for err <- upload_errors(@uploads.photos, entry) do %>
                          <p class="text-error text-xs">{error_to_string(err)}</p>
                        <% end %>
                      </div>
                    <% end %>
                  </div>
                <% end %>

                <%= for err <- upload_errors(@uploads.photos) do %>
                  <p class="text-error text-xs mt-1">{error_to_string(err)}</p>
                <% end %>

                <%= if @uploads.photos.entries != [] do %>
                  <button type="submit" class="btn btn-sm btn-primary mt-2">Upload Photos</button>
                <% end %>
              </form>
            </div>
          </div>
        </div>
      </div>

      <.modal
        :if={@live_action == :edit}
        id="production-modal"
        show
        on_cancel={JS.patch(~p"/admin/productions/#{@production.id}")}
      >
        <.live_component
          module={SpotlightWeb.Admin.ProductionLive.FormComponent}
          id={@production.id}
          title="Edit Production"
          action={@live_action}
          production={@production}
          patch={~p"/admin/productions/#{@production.id}"}
        />
      </.modal>

      <.modal
        :if={@live_action in [:add_performance, :edit_performance]}
        id="performance-modal"
        show
        on_cancel={JS.patch(~p"/admin/productions/#{@production.id}")}
      >
        <.live_component
          module={SpotlightWeb.Admin.ProductionLive.PerformanceFormComponent}
          id={@performance.id || :new}
          title={if @live_action == :add_performance, do: "Add Performance", else: "Edit Performance"}
          action={@live_action}
          performance={@performance}
          production={@production}
          patch={~p"/admin/productions/#{@production.id}"}
        />
      </.modal>
    </div>
    """
  end

  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:too_many_files), do: "Too many files selected"
  defp error_to_string(:not_accepted), do: "Unsupported file type (use JPG, PNG, or WebP)"
  defp error_to_string(err), do: to_string(err)
end
