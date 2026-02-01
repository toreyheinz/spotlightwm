defmodule SpotlightWeb.Admin.ProductionLive.FormComponent do
  use SpotlightWeb, :live_component

  alias Spotlight.Productions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        <%= @title %>
      </.header>

      <.form
        for={@form}
        id="production-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:title]} type="text" label="Title" required />
          <.input field={@form[:description]} type="textarea" label="Description" rows="4" />

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input field={@form[:location_name]} type="text" label="Location Name" placeholder="Spotlight Theater" />
            <.input field={@form[:location_query]} type="text" label="Location (for map)" placeholder="Spotlight Theater, Grand Rapids MI" />
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <.input field={@form[:price]} type="text" label="Price" placeholder="$15 adults / $10 students" />
            <.input field={@form[:ticket_url]} type="url" label="Ticket URL" placeholder="https://..." />
          </div>

          <.input
            field={@form[:status]}
            type="select"
            label="Status"
            options={[
              {"Draft", "draft"},
              {"Published", "published"},
              {"Archived", "archived"}
            ]}
          />
        </div>

        <div class="mt-6 flex justify-end gap-3">
          <.link patch={@patch} class="btn btn-ghost">Cancel</.link>
          <.button phx-disable-with="Saving..." class="btn btn-primary">
            Save Production
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{production: production} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Productions.change_production(production))
     end)}
  end

  @impl true
  def handle_event("validate", %{"production" => production_params}, socket) do
    changeset = Productions.change_production(socket.assigns.production, production_params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"production" => production_params}, socket) do
    save_production(socket, socket.assigns.action, production_params)
  end

  defp save_production(socket, :edit, production_params) do
    case Productions.update_production(socket.assigns.production, production_params) do
      {:ok, production} ->
        notify_parent({:saved, production})

        {:noreply,
         socket
         |> put_flash(:info, "Production updated successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_production(socket, :new, production_params) do
    case Productions.create_production(production_params) do
      {:ok, production} ->
        notify_parent({:saved, production})

        {:noreply,
         socket
         |> put_flash(:info, "Production created successfully")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
