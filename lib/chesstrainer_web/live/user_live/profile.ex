defmodule ChesstrainerWeb.UserLive.Profile do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts
  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Attempts

  @recent_attempts 25

  @tabs [
    %{id: :account, label: "Account", path: "/users/profile"},
    %{id: :settings, label: "Settings", path: "/users/profile/settings"},
    %{id: :data, label: "Data", path: "/users/profile/data"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.header>
        Profile
        <:subtitle>Manage your account, site settings and training data.</:subtitle>
      </.header>

      <nav id="profile-tabs" class="flex gap-1 border-b border-base-300" aria-label="Profile sections">
        <.link
          :for={tab <- @tabs}
          id={"profile-tab-#{tab.id}"}
          patch={tab.path}
          class={[
            "border-b-2 -mb-px px-3 py-2 text-sm font-semibold",
            if(@live_action == tab.id,
              do: "border-primary text-primary-text",
              else: "border-transparent text-base-content/60 hover:text-base-content"
            )
          ]}
          aria-current={@live_action == tab.id && "page"}
        >
          {tab.label}
        </.link>
      </nav>

      <%= case @live_action do %>
        <% :account -> %>
          <section id="profile-summary" class="space-y-2 rounded-lg border border-base-300 p-4">
            <p class="text-sm text-base-content/60">Signed in as</p>
            <p class="text-lg font-semibold">{@current_scope.user.username}</p>
            <p class="text-sm">{@current_scope.user.email}</p>
            <p class="text-sm text-base-content/60">
              Rating:
              <span class="font-semibold text-base-content">{round(@current_scope.user.rating)}</span>
            </p>
          </section>

          <section id="email-settings" class="space-y-4">
            <h2 class="settings-header">Change email</h2>
            <p class="settings-subtitle">We will send a confirmation link to the new address.</p>

            <.form
              for={@email_form}
              id="email_form"
              phx-submit="update_email"
              phx-change="validate_email"
            >
              <.input
                field={@email_form[:email]}
                type="email"
                label="Email"
                autocomplete="username"
                spellcheck="false"
                required
              />
              <.button variant="primary" phx-disable-with="Changing...">Change Email</.button>
            </.form>
          </section>

          <hr class="my-6 border-base-200" />

          <section id="password-settings" class="space-y-4">
            <h2 class="settings-header">Change password</h2>
            <p class="settings-subtitle">Choose a new password for this account.</p>

            <.form
              for={@password_form}
              id="password_form"
              action={~p"/users/update-password"}
              method="post"
              phx-change="validate_password"
              phx-submit="update_password"
              phx-trigger-action={@trigger_submit}
            >
              <input
                name={@password_form[:email].name}
                type="hidden"
                id="hidden_user_email"
                spellcheck="false"
                value={@current_email}
              />
              <.input
                field={@password_form[:password]}
                type="password"
                label="New password"
                autocomplete="new-password"
                spellcheck="false"
                required
              />
              <.input
                field={@password_form[:password_confirmation]}
                type="password"
                label="Confirm new password"
                autocomplete="new-password"
                spellcheck="false"
              />
              <.button variant="primary" phx-disable-with="Saving...">
                Save Password
              </.button>
            </.form>
          </section>

          <hr class="my-6 border-base-200" />

          <section id="delete_account" class="space-y-4">
            <h2 class="settings-header">Delete account</h2>
            <p class="settings-subtitle">This action is permanent and cannot be undone.</p>

            <p class="text-sm text-base-content/70">
              Deleting your account permanently removes your profile, rating and training history.
              Nothing can be recovered.
            </p>

            <.button
              id="delete_account_button"
              variant="danger"
              phx-click="delete_account"
              data-confirm="This permanently deletes your account and all of your data. Nothing can be recovered. Are you sure?"
            >
              Delete my account
            </.button>
          </section>
        <% :settings -> %>
          <%!-- Keep section for when board themes are added etc --%>
          <%!-- <section id="appearance-settings" class="space-y-4 rounded-lg border border-base-300 p-4">
            <.header>
              Appearance
              <:subtitle>Choose how the site looks on this device.</:subtitle>
            </.header>
            <Layouts.colour_mode_toggle />
          </section> --%>

          <section id="membership-settings" class="space-y-2 rounded-lg border border-base-300 p-4">
            <h2 class="settings-header">Membership</h2>
            <p class="settings-subtitle">Your current plan.</p>
            <p class="text-sm">
              You are on the <strong>{plan_label(@current_scope)}</strong> plan.
            </p>
            <p class="text-sm text-base-content/70">
              Premium membership is not available yet. When it arrives it will add session
              analytics, weak-theme reports and the full puzzle search.
            </p>
          </section>

          <p id="settings-empty-state" class="text-sm text-base-content/60">
            More site settings will appear here as they become available.
          </p>
        <% :data -> %>
          <section id="training-stats" class="space-y-4 rounded-lg border border-base-300 p-4">
            <h2 class="settings-header">Progress</h2>
            <p class="settings-subtitle">Your score and solve history across every puzzle.</p>
            <dl class="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <.stat label="Rating" value={round(@current_scope.user.rating)} />
              <.stat label="Attempts" value={@stats.attempts} />
              <.stat label="Solved" value={@stats.solved} />
              <.stat label="Solve rate" value={"#{@stats.solve_rate}%"} />
            </dl>
          </section>

          <section id="data-export" class="space-y-4 rounded-lg border border-base-300 p-4">
            <h2 class="settings-header">Export your data</h2>
            <p class="settings-subtitle">Download your profile details and every recorded attempt.</p>
            <div class="flex flex-wrap gap-3">
              <.button id="export-csv" href={~p"/users/profile/export/csv"}>
                <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Download CSV
              </.button>
              <.button id="export-json" href={~p"/users/profile/export/json"}>
                <.icon name="hero-arrow-down-tray" class="w-4 h-4" /> Download JSON
              </.button>
            </div>
          </section>

          <section id="attempt-history" class="space-y-4 rounded-lg border border-base-300 p-4">
            <h2 class="settings-header">Recent attempts</h2>
            <p class="settings-subtitle">The last {@recent_attempts} puzzles you finished.</p>
            <table :if={@attempts != []} class="w-full text-left text-sm">
              <thead class="border-b border-base-300 text-base-content/60">
                <tr>
                  <th class="py-2">Played</th>
                  <th class="py-2">Puzzle</th>
                  <th class="py-2">Outcome</th>
                </tr>
              </thead>
              <tbody>
                <tr
                  :for={attempt <- @attempts}
                  id={"attempt-#{attempt.id}"}
                  class="border-b border-base-200"
                >
                  <td class="py-2">{Calendar.strftime(attempt.inserted_at, "%d %b %Y")}</td>
                  <td class="py-2">
                    <.link
                      navigate={~p"/endgames/#{attempt.endgame.public_code}/play"}
                      class="font-semibold"
                    >
                      {attempt.endgame.key}
                    </.link>
                  </td>
                  <td class="py-2 capitalize">{attempt.outcome}</td>
                </tr>
              </tbody>
            </table>

            <p :if={@attempts == []} class="text-sm text-base-content/70">
              No attempts yet. Play a puzzle to start building your history.
            </p>
          </section>

          <section id="premium-data" class="space-y-2 rounded-lg border border-base-300 p-4">
            <h2 class="settings-header">Premium Insights</h2>
            <p class="settings-subtitle">Deeper training analytics, once Premium is available.</p>
            <ul class="list-inside list-disc text-sm text-base-content/70">
              <li>Session-by-session performance</li>
              <li>Failed puzzles and weak themes</li>
            </ul>
          </section>
      <% end %>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_scope.user, token) do
        {:ok, _user} ->
          put_flash(socket, :info, "Email changed successfully.")

        {:error, _} ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/profile")}
  end

  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Profile")
     |> assign(:tabs, @tabs)
     |> assign(:recent_attempts, @recent_attempts)}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    socket = load_section(socket)

    if socket.assigns.live_action == :account and not sudo_mode?(socket) do
      {:noreply,
       socket
       |> put_flash(:error, "You must re-authenticate to access this page.")
       |> redirect(to: ~p"/users/log-in")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"user" => user_params} = params

    email_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_email(user_params, validate_unique: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form)}
  end

  def handle_event("update_email", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_email(user, user_params) do
      %{valid?: true} = changeset ->
        Accounts.deliver_user_update_email_instructions(
          Ecto.Changeset.apply_action!(changeset, :insert),
          user.email,
          &url(~p"/users/settings/confirm-email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info)}

      changeset ->
        {:noreply, assign(socket, :email_form, to_form(changeset, action: :insert))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"user" => user_params} = params

    password_form =
      socket.assigns.current_scope.user
      |> Accounts.change_user_password(user_params, hash_password: false)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form)}
  end

  def handle_event("update_password", params, socket) do
    %{"user" => user_params} = params
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    case Accounts.change_user_password(user, user_params) do
      %{valid?: true} = changeset ->
        {:noreply, assign(socket, trigger_submit: true, password_form: to_form(changeset))}

      changeset ->
        {:noreply, assign(socket, password_form: to_form(changeset, action: :insert))}
    end
  end

  def handle_event("delete_account", _params, socket) do
    user = socket.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)

    {:ok, _user} = Accounts.delete_user(user)

    {:noreply,
     socket
     |> put_flash(:info, "Your account has been deleted.")
     |> redirect(to: ~p"/")}
  end

  defp load_section(socket) do
    case socket.assigns.live_action do
      :account -> assign_account(socket)
      :data -> assign_data(socket)
      _ -> socket
    end
  end

  defp assign_account(socket) do
    user = socket.assigns.current_scope.user
    email_changeset = Accounts.change_user_email(user, %{}, validate_unique: false)
    password_changeset = Accounts.change_user_password(user, %{}, hash_password: false)

    socket
    |> assign(:current_email, user.email)
    |> assign(:email_form, to_form(email_changeset))
    |> assign(:password_form, to_form(password_changeset))
    |> assign(:trigger_submit, false)
  end

  defp assign_data(socket) do
    user = socket.assigns.current_scope.user
    stats = Attempts.stats_for_user(user.id)
    solve_rate = if stats.attempts > 0, do: round(stats.solved * 100 / stats.attempts), else: 0

    socket
    |> assign(:stats, Map.put(stats, :solve_rate, solve_rate))
    |> assign(:attempts, Attempts.list_attempts_for_user(user.id, limit: @recent_attempts))
  end

  defp sudo_mode?(socket) do
    Accounts.sudo_mode?(socket.assigns.current_scope.user, -10)
  end

  defp plan_label(scope), do: if(Scope.premium?(scope), do: "Premium", else: "Free")

  attr :label, :string, required: true
  attr :value, :any, required: true

  defp stat(assigns) do
    ~H"""
    <div class="rounded-lg border border-base-300 p-3">
      <dt class="text-xs uppercase tracking-wide text-base-content/60">{@label}</dt>
      <dd class="text-xl font-semibold">{@value}</dd>
    </div>
    """
  end
end
