defmodule SpotlightWeb.Admin.ProductionLive.Index do
  use SpotlightWeb, :live_view

  alias Spotlight.Productions
  alias Spotlight.Productions.Production

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Productions")
     |> stream(:productions, Productions.list_productions())}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Productions")
    |> assign(:production, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "New Production")
    |> assign(:production, %Production{})
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    production = Productions.get_production!(id)
    {:ok, _} = Productions.delete_production(production)

    {:noreply, stream_delete(socket, :productions, production)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 text-gray-800">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Productions</h1>
        <.link navigate={~p"/admin/productions/new"} class="btn btn-primary">
          New Production
        </.link>
      </div>

      <div class="overflow-x-auto bg-white rounded-lg shadow">
        <table class="table text-gray-800">
          <thead class="bg-gray-100">
            <tr class="text-gray-700">
              <th>Title</th>
              <th>Status</th>
              <th>Dates</th>
              <th></th>
            </tr>
          </thead>
          <tbody id="productions" phx-update="stream">
            <tr :for={{dom_id, production} <- @streams.productions} id={dom_id}>
              <td>
                <.link navigate={~p"/admin/productions/#{production.id}"} class="link link-hover">
                  <%= production.title %>
                </.link>
              </td>
              <td>
                <span class={[
                  "badge",
                  production.status == :published && "badge-success",
                  production.status == :draft && "badge-warning",
                  production.status == :archived && "badge-ghost"
                ]}>
                  <%= production.status %>
                </span>
              </td>
              <td class="text-sm text-gray-600">
                <%= Productions.format_date_range(production) || "No performances" %>
              </td>
              <td>
                <div class="flex gap-2">
                  <.link navigate={~p"/admin/productions/#{production.id}/edit"} class="btn btn-sm btn-ghost">
                    Edit
                  </.link>
                  <button
                    phx-click="delete"
                    phx-value-id={production.id}
                    data-confirm="Are you sure you want to delete this production?"
                    class="btn btn-sm btn-ghost text-error"
                  >
                    Delete
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.modal
        :if={@live_action == :new}
        id="production-modal"
        show
        on_cancel={JS.patch(~p"/admin/productions")}
      >
        <.live_component
          module={SpotlightWeb.Admin.ProductionLive.FormComponent}
          id={:new}
          title="New Production"
          action={@live_action}
          production={@production}
          patch={~p"/admin/productions"}
        />
      </.modal>
    </div>
    """
  end
end
