defmodule ChesstrainerWeb.UserLive.ResetPassword do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="mx-auto max-w-sm space-y-4">
        <div class="text-center">
          <.header>
            {@title}
            <:subtitle>{@subtitle}</:subtitle>
          </.header>
        </div>

        <.form for={@form} id="reset_password_form" phx-submit={@submit_event}>
          <%= if @token do %>
            <.input
              field={@form[:password]}
              type="password"
              label="New password"
              autocomplete="new-password"
              spellcheck="false"
              required
            />
            <.input
              field={@form[:password_confirmation]}
              type="password"
              label="Confirm new password"
              autocomplete="new-password"
              spellcheck="false"
            />
          <% else %>
            <.input
              field={@form[:email]}
              type="email"
              label="Email"
              autocomplete="email"
              spellcheck="false"
              required
            />
          <% end %>

          <.button variant="primary" class="w-full" phx-disable-with="Saving...">
            {@submit_label}
          </.button>
        </.form>

        <p class="text-center text-sm">
          <.link
            navigate={~p"/users/log-in"}
            class="font-semibold text-primary hover:underline"
          >
            Back to log in
          </.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Accounts.get_user_by_reset_password_token(token) do
      nil ->
        {:ok,
         socket
         |> put_flash(:error, "Reset password link is invalid or it has expired.")
         |> push_navigate(to: ~p"/users/log-in")}

      user ->
        {:ok,
         socket
         |> assign(:user, user)
         |> assign(:token, token)
         |> assign(:title, "Reset password")
         |> assign(:subtitle, "Choose a new password for your account.")
         |> assign(:submit_label, "Reset password")
         |> assign(:submit_event, "submit_password")
         |> assign(:form, to_form(%{"password" => ""}, as: "user"))}
    end
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:user, nil)
     |> assign(:token, nil)
     |> assign(:title, "Forgot your password?")
     |> assign(:subtitle, "Enter your email and we'll send you reset instructions.")
     |> assign(:submit_label, "Send reset instructions")
     |> assign(:submit_event, "submit_email")
     |> assign(:form, to_form(%{"email" => ""}, as: "user"))}
  end

  @impl true
  def handle_event("submit_email", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(String.trim(email)) do
      Accounts.deliver_user_reset_password_instructions(
        user,
        &url(~p"/users/reset-password/#{&1}")
      )
    end

    {:noreply,
     socket
     |> put_flash(
       :info,
       "If your email is in our system, you will receive instructions to reset your password shortly."
     )
     |> push_navigate(to: ~p"/users/log-in")}
  end

  def handle_event("submit_password", %{"user" => user_params}, socket) do
    case Accounts.reset_user_password(socket.assigns.user, user_params) do
      {:ok, {_user, _expired_tokens}} ->
        {:noreply,
         socket
         |> put_flash(:info, "Password reset successfully. Log in with your new password.")
         |> push_navigate(to: ~p"/users/log-in")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset, action: :insert))}
    end
  end
end
