defmodule SpotlightWeb.Admin.DashboardLive do
  use SpotlightWeb, :live_view

  alias Spotlight.Productions

  @impl true
  def mount(_params, _session, socket) do
    upcoming = Productions.list_upcoming_productions()

    {:ok,
     socket
     |> assign(:page_title, "Admin Dashboard")
     |> assign(:upcoming_productions, upcoming)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 text-gray-800">
      <h1 class="text-3xl font-bold mb-8 text-gray-900">Admin Dashboard</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <.link
          navigate={~p"/admin/productions"}
          class="card bg-white shadow-xl hover:shadow-2xl transition-shadow"
        >
          <div class="card-body">
            <h2 class="card-title">Productions</h2>
            <p>Manage theater productions, performances, and photos</p>
          </div>
        </.link>

        <.link
          navigate={~p"/admin/users"}
          class="card bg-white shadow-xl hover:shadow-2xl transition-shadow"
        >
          <div class="card-body">
            <h2 class="card-title">Users</h2>
            <p>Manage admin users</p>
          </div>
        </.link>
      </div>

      <div class="mt-12">
        <h2 class="text-2xl font-bold mb-4 text-gray-900">Upcoming Productions</h2>
        <%= if Enum.empty?(@upcoming_productions) do %>
          <p class="text-gray-600">No upcoming productions scheduled.</p>
        <% else %>
          <div class="space-y-4">
            <%= for production <- @upcoming_productions do %>
              <.link
                navigate={~p"/admin/productions/#{production.id}"}
                class="block p-4 bg-white rounded-lg shadow hover:shadow-md transition-shadow"
              >
                <h3 class="font-semibold text-gray-900"><%= production.title %></h3>
                <p class="text-sm text-gray-600">
                  <%= Productions.format_date_range(production) %>
                </p>
              </.link>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
