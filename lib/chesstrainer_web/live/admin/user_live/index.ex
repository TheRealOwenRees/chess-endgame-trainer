defmodule ChesstrainerWeb.Admin.UserLive.Index do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts

  @per_page 25

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        Users
        <:subtitle>
          Search accounts, review their roles and plans, and open a user to edit them.
          Admins only see members and moderators.
        </:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/admin/users/new"}>
            <.icon name="hero-plus" /> Invite user
          </.button>
        </:actions>
      </.header>

      <.form for={@filter_form} id="admin-user-search-form" phx-change="search" class="mb-6">
        <.input
          field={@filter_form[:search]}
          type="search"
          label="Search by email or username"
          autocomplete="off"
          phx-debounce="200"
          placeholder="email or username…"
        />
      </.form>

      <p :if={@users == []} class="text-base-content/70">
        <%= if @search == "" do %>
          No users are visible to you yet.
        <% else %>
          No users match “{@search}”.
        <% end %>
      </p>

      <table :if={@users != []} class={table_class()}>
        <thead>
          <tr>
            <th>Username</th>
            <th>Email</th>
            <th>Role</th>
            <th>Plan</th>
            <th>Confirmed</th>
            <th>Created</th>
            <th><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody id="admin-users">
          <tr :for={user <- @users} id={"user-" <> user.id}>
            <td>{user.username}</td>
            <td>{user.email}</td>
            <td>{user.role}</td>
            <td>{user.plan}</td>
            <td>{confirmed_label(user)}</td>
            <td>{format_date(user.inserted_at)}</td>
            <td class="w-0 font-semibold">
              <.link navigate={~p"/admin/users/#{user.id}"}>View</.link>
            </td>
          </tr>
        </tbody>
      </table>

      <div class="mt-4 flex flex-wrap items-center justify-between gap-3 text-sm text-base-content/70">
        <p>
          Page {@page} of {@total_pages} · {@count} {if @count == 1, do: "user", else: "users"}
        </p>
        <div class="flex gap-2">
          <.button
            :if={@page > 1}
            variant="secondary"
            phx-click="previous_page"
            id="previous-page"
          >
            Previous
          </.button>
          <.button
            :if={@page < @total_pages}
            variant="secondary"
            phx-click="next_page"
            id="next-page"
          >
            Next
          </.button>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:page_title, "Users")
      |> assign(:search, "")
      |> assign(:page, 1)
      |> assign(:users, [])
      |> assign(:count, 0)
      |> assign(:total_pages, 1)
      |> assign(:filter_form, to_form(%{"search" => ""}))

    case load_users(socket) do
      {:ok, socket} -> {:ok, socket}
      {:error, :unauthorized} -> {:ok, redirect_unauthorized(socket)}
    end
  end

  @impl true
  def handle_event("search", %{"search" => search}, socket) do
    case load_users(assign(socket, search: search, page: 1)) do
      {:ok, socket} -> {:noreply, socket}
      {:error, :unauthorized} -> {:noreply, redirect_unauthorized(socket)}
    end
  end

  def handle_event("previous_page", _params, socket) do
    case load_users(assign(socket, :page, max(socket.assigns.page - 1, 1))) do
      {:ok, socket} -> {:noreply, socket}
      {:error, :unauthorized} -> {:noreply, redirect_unauthorized(socket)}
    end
  end

  def handle_event("next_page", _params, socket) do
    case load_users(assign(socket, :page, socket.assigns.page + 1)) do
      {:ok, socket} -> {:noreply, socket}
      {:error, :unauthorized} -> {:noreply, redirect_unauthorized(socket)}
    end
  end

  defp load_users(socket) do
    scope = socket.assigns.current_scope
    search = socket.assigns.search

    case Accounts.count_users_for_admin(scope, search: search) do
      {:ok, count} ->
        total_pages = max(div(count + @per_page - 1, @per_page), 1)
        page = min(socket.assigns.page, total_pages)

        case Accounts.list_users_for_admin(scope, search: search, page: page) do
          {:ok, users} ->
            {:ok,
             assign(socket, users: users, count: count, total_pages: total_pages, page: page)}

          {:error, :unauthorized} ->
            {:error, :unauthorized}
        end

      {:error, :unauthorized} ->
        {:error, :unauthorized}
    end
  end

  defp redirect_unauthorized(socket) do
    socket
    |> put_flash(:error, "You are not authorized to manage users.")
    |> push_navigate(to: ~p"/")
  end

  defp confirmed_label(%{confirmed_at: nil}), do: "No"
  defp confirmed_label(_user), do: "Yes"

  defp format_date(nil), do: ""

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d")
  end
end
