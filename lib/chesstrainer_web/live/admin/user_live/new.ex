defmodule ChesstrainerWeb.Admin.UserLive.New do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Accounts.Role
  alias Chesstrainer.Accounts.User

  @plan_options [{"Free", "free"}, {"Premium", "premium"}]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        Invite user
        <:subtitle>
          We create the account and email a link so the recipient can choose a password.
          The invite is confirmed immediately, so no separate confirmation step is needed.
        </:subtitle>
      </.header>

      <.form for={@form} id="invite-user-form" phx-change="validate" phx-submit="save">
        <.input
          field={@form[:email]}
          type="email"
          label="Email"
          autocomplete="off"
          required
        />
        <.input
          field={@form[:username]}
          type="text"
          label="Username"
          autocomplete="off"
          required
        />
        <.input
          field={@form[:role]}
          type="select"
          label="Role"
          options={@role_options}
        />
        <.input
          field={@form[:plan]}
          type="select"
          label="Plan"
          options={@plan_options}
        />

        <footer>
          <.button phx-disable-with="Sending..." variant="primary">Send invitation</.button>
          <.button navigate={~p"/admin/users"}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Invite user")
     |> assign(:role_options, role_options(socket.assigns.current_scope))
     |> assign(:plan_options, @plan_options)
     |> assign(
       :form,
       to_form(%{"email" => "", "username" => "", "role" => "member", "plan" => "free"},
         as: :user
       )
     )}
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    changeset =
      %User{}
      |> User.invite_changeset(user_params)
      |> User.admin_changeset(user_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.invite_user_as_admin(
           socket.assigns.current_scope,
           user_params,
           &url(~p"/users/reset-password/#{&1}")
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> put_flash(:info, "Invitation sent to #{user.email}.")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to assign that role.")}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "The invitation could not be sent. Please try again.")}
    end
  end

  defp role_options(scope) do
    for role <- Role.values(),
        Policy.can_assign_role?(scope, role),
        do: {role_label(role), role}
  end

  defp role_label(:super_admin), do: "Super admin"
  defp role_label(role), do: role |> Atom.to_string() |> String.capitalize()
end
