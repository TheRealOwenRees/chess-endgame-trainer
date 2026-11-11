defmodule ChesstrainerWeb.Admin.UserLive.Show do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Accounts.Role

  @plan_options [{"Free", "free"}, {"Premium", "premium"}]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <Layouts.admin_nav current_scope={@current_scope} />

      <div id="admin-user-page">
        <.header>
          {@user.username}
          <:subtitle>Account details and administrator controls.</:subtitle>
          <:actions>
            <.button navigate={~p"/admin/users"}>
              <.icon name="hero-arrow-left" /> All users
            </.button>
          </:actions>
        </.header>

        <.list>
          <:item title="Email">{@user.email}</:item>
          <:item title="Username">{@user.username}</:item>
          <:item title="Role">{@user.role}</:item>
          <:item title="Plan">{@user.plan}</:item>
          <:item title="Confirmed">{confirmed_label(@user)}</:item>
          <:item title="Rating">{round(@user.rating)}</:item>
          <:item title="Created">{format_datetime(@user.inserted_at)}</:item>
          <:item title="Last updated">{format_datetime(@user.updated_at)}</:item>
        </.list>

        <section class="mt-8">
          <h2 class="text-lg font-semibold">Role and plan</h2>

          <.form
            :if={@can_manage}
            for={@form}
            id="admin-user-form"
            phx-change="validate"
            phx-submit="save"
            class="mt-4"
          >
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
              <.button phx-disable-with="Saving..." variant="primary">Save changes</.button>
            </footer>
          </.form>

          <p :if={!@can_manage} class="mt-4 text-sm text-base-content/70">
            You can view this account but not change its role or plan.
          </p>
        </section>

        <section :if={@can_manage} class="mt-8 border-t border-base-200 pt-6">
          <h2 class="text-lg font-semibold">Account emails</h2>
          <p class="mt-1 text-sm text-base-content/70">
            These actions send email through the configured mailer. In development the messages
            appear in the Swoosh mailbox at <code>/dev/mailbox</code>.
          </p>

          <div class="mt-4 flex flex-wrap gap-2">
            <.button
              :if={is_nil(@user.confirmed_at)}
              variant="secondary"
              phx-click="resend_confirmation"
              id="resend-confirmation"
            >
              Resend confirmation email
            </.button>
            <.button
              variant="secondary"
              phx-click="send_password_reset"
              id="send-password-reset"
            >
              Send password reset email
            </.button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Accounts.get_user_for_admin(socket.assigns.current_scope, id) do
      {:ok, user} ->
        {:ok, assign_user(socket, user)}

      {:error, :unauthorized} ->
        {:ok,
         socket
         |> put_flash(:error, "You are not authorized to view that user.")
         |> push_navigate(to: ~p"/admin/users")}

      {:error, :not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "User not found.")
         |> push_navigate(to: ~p"/admin/users")}
    end
  end

  @impl true
  def handle_event("validate", %{"user" => user_params}, socket) do
    if socket.assigns.can_manage do
      changeset =
        socket.assigns.user
        |> Accounts.change_user_as_admin(user_params)
        |> Map.put(:action, :validate)

      {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
    else
      {:noreply, put_flash(socket, :error, "You are not authorized to modify this user.")}
    end
  end

  def handle_event("save", %{"user" => user_params}, socket) do
    case Accounts.update_user_as_admin(
           socket.assigns.current_scope,
           socket.assigns.user,
           user_params
         ) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign_user(user)
         |> put_flash(:info, "User updated successfully.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to modify this user.")}

      {:error, :own_role} ->
        {:noreply, put_flash(socket, :error, "You cannot change your own role.")}

      {:error, :last_super_admin} ->
        {:noreply, put_flash(socket, :error, "You cannot demote the last super admin.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("resend_confirmation", _params, socket) do
    case Accounts.resend_user_confirmation_instructions_as_admin(
           socket.assigns.current_scope,
           socket.assigns.user,
           &url(~p"/users/confirm/#{&1}")
         ) do
      {:ok, _email} ->
        {:noreply, put_flash(socket, :info, "Confirmation email sent.")}

      {:error, :already_confirmed} ->
        {:noreply, put_flash(socket, :error, "That account is already confirmed.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to email this user.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The confirmation email could not be sent.")}
    end
  end

  def handle_event("send_password_reset", _params, socket) do
    case Accounts.send_user_reset_password_instructions_as_admin(
           socket.assigns.current_scope,
           socket.assigns.user,
           &url(~p"/users/reset-password/#{&1}")
         ) do
      {:ok, _email} ->
        {:noreply, put_flash(socket, :info, "Password reset email sent.")}

      {:error, :unauthorized} ->
        {:noreply, put_flash(socket, :error, "You are not authorized to email this user.")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "The password reset email could not be sent.")}
    end
  end

  defp assign_user(socket, user) do
    can_manage = Policy.can_manage_user?(socket.assigns.current_scope, user)

    socket
    |> assign(:page_title, user.username)
    |> assign(:user, user)
    |> assign(:can_manage, can_manage)
    |> assign(:plan_options, @plan_options)
    |> assign(:role_options, role_options(socket.assigns.current_scope))
    |> assign(:form, to_form(Accounts.change_user_as_admin(user)))
  end

  defp role_options(scope) do
    for role <- Role.values(),
        Policy.can_assign_role?(scope, role),
        do: {role_label(role), role}
  end

  defp role_label(:super_admin), do: "Super admin"
  defp role_label(role), do: role |> Atom.to_string() |> String.capitalize()

  defp confirmed_label(%{confirmed_at: nil}), do: "No"
  defp confirmed_label(_user), do: "Yes"

  defp format_datetime(nil), do: "—"

  defp format_datetime(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M UTC")
  end
end
