defmodule SpotlightWeb.Admin.ProductionLive.PerformanceFormComponent do
  use SpotlightWeb, :live_component

  alias Spotlight.Productions

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
      </.header>

      <.form
        for={@form}
        id="performance-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <div class="space-y-4">
          <.input field={@form[:starts_at]} type="datetime-local" label="Date & Time" required />
          <.input field={@form[:notes]} type="text" label="Notes" placeholder="e.g. Matinee, Opening Night" />
        </div>

        <div class="mt-6 flex justify-end gap-3">
          <.link patch={@patch} class="btn btn-ghost">Cancel</.link>
          <.button phx-disable-with="Saving..." class="btn btn-primary">
            Save Performance
          </.button>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def update(%{performance: performance} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:form, fn ->
       to_form(Productions.change_performance(performance))
     end)}
  end

  @impl true
  def handle_event("validate", %{"performance" => params}, socket) do
    changeset = Productions.change_performance(socket.assigns.performance, params)
    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"performance" => params}, socket) do
    save_performance(socket, socket.assigns.action, params)
  end

  defp save_performance(socket, :add_performance, params) do
    case Productions.create_performance(socket.assigns.production, params) do
      {:ok, performance} ->
        notify_parent({:performance_saved, performance})

        {:noreply,
         socket
         |> put_flash(:info, "Performance added")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_performance(socket, :edit_performance, params) do
    case Productions.update_performance(socket.assigns.performance, params) do
      {:ok, performance} ->
        notify_parent({:performance_saved, performance})

        {:noreply,
         socket
         |> put_flash(:info, "Performance updated")
         |> push_patch(to: socket.assigns.patch)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
