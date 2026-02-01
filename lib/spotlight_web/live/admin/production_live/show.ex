defmodule SpotlightWeb.Admin.ProductionLive.Show do
  use SpotlightWeb, :live_view

  alias Spotlight.Productions

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    production = Productions.get_production_with_details!(id)

    {:noreply,
     socket
     |> assign(:page_title, page_title(socket.assigns.live_action, production))
     |> assign(:production, production)}
  end

  @impl true
  def handle_info({SpotlightWeb.Admin.ProductionLive.FormComponent, {:saved, production}}, socket) do
    production = Productions.get_production_with_details!(production.id)
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

  defp page_title(:show, production), do: production.title
  defp page_title(:edit, production), do: "Edit #{production.title}"

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 text-gray-800">
      <div class="flex justify-between items-start mb-8">
        <div>
          <.link navigate={~p"/admin/productions"} class="text-sm text-gray-600 hover:text-gray-900 mb-2 inline-block">
            ← Back to Productions
          </.link>
          <h1 class="text-3xl font-bold text-gray-900"><%= @production.title %></h1>
          <div class="mt-2">
            <span class={[
              "badge",
              @production.status == :published && "badge-success",
              @production.status == :draft && "badge-warning",
              @production.status == :archived && "badge-ghost"
            ]}>
              <%= @production.status %>
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
                    <p class="whitespace-pre-wrap"><%= @production.description %></p>
                  </div>
                <% end %>

                <div class="grid grid-cols-2 gap-4">
                  <div>
                    <label class="text-sm font-medium text-gray-600">Location</label>
                    <p><%= @production.location_name || "Not set" %></p>
                  </div>
                  <div>
                    <label class="text-sm font-medium text-gray-600">Price</label>
                    <p><%= @production.price || "Not set" %></p>
                  </div>
                </div>

                <%= if @production.ticket_url do %>
                  <div>
                    <label class="text-sm font-medium text-gray-600">Ticket URL</label>
                    <p>
                      <a href={@production.ticket_url} target="_blank" class="link">
                        <%= @production.ticket_url %>
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
                <button class="btn btn-sm btn-outline" disabled>
                  Add Performance
                </button>
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
                        <th></th>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for perf <- @production.performances do %>
                        <tr>
                          <td>
                            <%= Calendar.strftime(perf.starts_at, "%a, %b %-d, %Y at %-I:%M %p") %>
                          </td>
                          <td class="text-gray-600"><%= perf.notes %></td>
                          <td>
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
                Date range: <%= Productions.format_date_range(@production) || "N/A" %>
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
                <img src={@production.main_image_url} alt={@production.title} class="rounded-lg" />
              <% else %>
                <div class="bg-gray-200 rounded-lg aspect-video flex items-center justify-center">
                  <span class="text-gray-500">No image uploaded</span>
                </div>
              <% end %>
              <button class="btn btn-sm btn-outline mt-2" disabled>
                Upload Image
              </button>
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
                    <img src={photo.url} alt={photo.caption} class="rounded-lg" />
                  <% end %>
                </div>
              <% end %>
              <button class="btn btn-sm btn-outline mt-2" disabled>
                Upload Photos
              </button>
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
    </div>
    """
  end
end
