defmodule SpotlightWeb.Admin.UserLive.Index do
  use SpotlightWeb, :live_view

  alias Spotlight.Accounts
  alias Spotlight.Accounts.User
  alias Spotlight.Repo

  @impl true
  def mount(_params, _session, socket) do
    users = Repo.all(User)

    {:ok,
     socket
     |> assign(:page_title, "Users")
     |> stream(:users, users)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Users")
    |> assign(:user, nil)
  end

  defp apply_action(socket, :new, _params) do
    socket
    |> assign(:page_title, "Invite User")
    |> assign(:user, %User{})
  end

  @impl true
  def handle_event("invite", %{"user" => user_params}, socket) do
    case Accounts.register_user(user_params) do
      {:ok, user} ->
        # Send login instructions
        {:ok, _} =
          Accounts.deliver_login_instructions(
            user,
            fn token -> url(~p"/users/log-in/#{token}") end
          )

        {:noreply,
         socket
         |> put_flash(:info, "User invited! Login instructions sent to #{user.email}")
         |> push_patch(to: ~p"/admin/users")
         |> stream_insert(:users, user)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="container mx-auto px-4 py-8 text-gray-800">
      <div class="flex justify-between items-center mb-8">
        <h1 class="text-3xl font-bold text-gray-900">Users</h1>
        <.link patch={~p"/admin/users/new"} class="btn btn-primary">
          Invite User
        </.link>
      </div>

      <div class="overflow-x-auto bg-white rounded-lg shadow">
        <table class="table text-gray-800">
          <thead class="bg-gray-100">
            <tr class="text-gray-700">
              <th>Name</th>
              <th>Email</th>
              <th>Status</th>
              <th>Created</th>
            </tr>
          </thead>
          <tbody id="users" phx-update="stream">
            <tr :for={{dom_id, user} <- @streams.users} id={dom_id}>
              <td><%= user.name %></td>
              <td><%= user.email %></td>
              <td>
                <%= if user.confirmed_at do %>
                  <span class="badge badge-success">Active</span>
                <% else %>
                  <span class="badge badge-warning">Pending</span>
                <% end %>
              </td>
              <td class="text-sm text-gray-600">
                <%= Calendar.strftime(user.inserted_at, "%b %-d, %Y") %>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.modal
        :if={@live_action == :new}
        id="user-modal"
        show
        on_cancel={JS.patch(~p"/admin/users")}
      >
        <.header>
          Invite User
          <:subtitle>Send an invitation email to a new admin user</:subtitle>
        </.header>

        <.form
          for={%{}}
          id="invite-form"
          phx-submit="invite"
          class="mt-4"
        >
          <div class="space-y-4">
            <.input name="user[name]" type="text" label="Name" required />
            <.input name="user[email]" type="email" label="Email" required />
          </div>

          <div class="mt-6 flex justify-end gap-3">
            <.link patch={~p"/admin/users"} class="btn btn-ghost">Cancel</.link>
            <.button phx-disable-with="Sending..." class="btn btn-primary">
              Send Invitation
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end
end
