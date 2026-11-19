defmodule ChesstrainerWeb.ThemeSuggestionComponent do
  @moduledoc """
  Shows what a finished puzzle teaches and collects technique-theme suggestions.

  Rendered by `ChesstrainerWeb.PlayComponents.play_surface/1` once the puzzle
  ends. Guests see nothing; signed-in players see the endgame's themes and can
  suggest an existing technique theme or propose a new name. Suggestions are
  stored as pending and never create an endgame-to-theme link — that is the
  moderator queue's job.

  The component loads its own data so it stays correct when the parent replaces
  the endgame struct after recording the attempt.
  """

  use ChesstrainerWeb, :live_component

  alias Chesstrainer.Accounts.Scope
  alias Chesstrainer.Accounts.User
  alias Chesstrainer.Repo
  alias Chesstrainer.Themes
  alias Chesstrainer.Themes.ThemeSuggestion

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign_new(:current_scope, fn -> nil end)
      |> assign_new(:query, fn -> "" end)
      |> assign_new(:results, fn -> [] end)
      |> assign_new(:message, fn -> nil end)

    cond do
      not signed_in?(socket.assigns.current_scope) ->
        {:ok, socket}

      socket.assigns.status not in [:solved, :failed] ->
        {:ok, socket}

      socket.assigns[:loaded_for] == socket.assigns.endgame.id ->
        {:ok, socket}

      true ->
        {:ok, load(socket, socket.assigns.current_scope.user)}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <section
        :if={@status in [:solved, :failed] and signed_in?(@current_scope)}
        id="theme-teaching"
        class="rounded-xl bg-base-200 p-4"
      >
        <h2 class="mb-2 text-lg font-semibold">What this puzzle teaches</h2>

        <p :if={@themes == []} class="text-sm text-muted">
          No themes yet. If you know what this endgame is about, suggest one.
        </p>

        <div :if={@themes != []} class="mb-2 flex flex-wrap items-center gap-2">
          <.badge :for={theme <- ordered_themes(@themes)} size="sm">
            <span class={if theme.kind == :technique, do: "font-semibold", else: "text-muted"}>
              {theme.name}
            </span>
            <span :if={pending_count(@pending_counts, theme) > 0} class="text-muted">
              · {pending_count(@pending_counts, theme)} suggested
            </span>
          </.badge>
        </div>

        <p id="pending-suggestions-total" class="text-xs text-muted">
          {pending_label(@pending_total)}
        </p>

        <div :if={@pending != []} class="mt-3">
          <p class="text-sm font-semibold">Your suggestions</p>
          <ul class="mt-1 space-y-1 text-sm">
            <li :for={suggestion <- @pending} class="flex items-center gap-2">
              <span>{suggestion_label(suggestion)}</span>
              <span class="text-muted">pending review</span>
              <button
                type="button"
                id={"withdraw-#{suggestion.id}"}
                phx-click="withdraw"
                phx-value-id={suggestion.id}
                phx-target={@myself}
                class="font-semibold text-error"
              >
                Withdraw
              </button>
            </li>
          </ul>
        </div>

        <p
          :if={@message}
          id="theme-suggestion-message"
          role="alert"
          class="mt-3 text-sm text-base-content"
        >
          {@message}
        </p>

        <div class="mt-3 space-y-3">
          <form id="theme-suggestion-search-form" phx-change="search" phx-target={@myself}>
            <.input
              name="query"
              value={@query}
              label="Suggest a technique theme"
              placeholder="Search themes…"
              autocomplete="off"
              phx-debounce="200"
            />
          </form>

          <ul :if={@results != []} id="theme-suggestion-results" class="flex flex-col gap-1">
            <li :for={{theme, count} <- @results}>
              <button
                type="button"
                id={"suggest-#{theme.id}"}
                phx-click="suggest"
                phx-value-id={theme.id}
                phx-target={@myself}
                class="block w-full rounded px-3 py-2 text-left text-sm hover:bg-base-300"
              >
                {theme.name}
                <span :if={count > 0} class="text-muted">· {count} suggested</span>
              </button>
            </li>
          </ul>

          <form
            id="theme-suggestion-proposal-form"
            phx-submit="propose"
            phx-target={@myself}
            class="flex items-end gap-2"
          >
            <div class="flex-1">
              <.input
                name="name"
                value=""
                label="…or propose a new technique theme"
                autocomplete="off"
                placeholder="e.g. Opposition"
              />
            </div>
            <.button>Propose</.button>
          </form>
        </div>
      </section>
    </div>
    """
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    results =
      search_results(
        query,
        socket.assigns.themes,
        socket.assigns.pending,
        socket.assigns.pending_counts
      )

    {:noreply, assign(socket, query: query, results: results, message: nil)}
  end

  def handle_event("suggest", %{"id" => theme_id}, socket) do
    case Themes.suggest_theme(socket.assigns.current_scope, socket.assigns.endgame, %{
           theme_id: theme_id
         }) do
      {:ok, _suggestion} ->
        {:noreply,
         socket
         |> assign(:message, "Suggestion sent for review.")
         |> refresh(socket.assigns.current_scope.user)}

      {:error, reason} ->
        {:noreply, assign(socket, :message, error_message(reason))}
    end
  end

  def handle_event("propose", %{"name" => name}, socket) do
    case Themes.suggest_theme(socket.assigns.current_scope, socket.assigns.endgame, %{
           proposed_name: name
         }) do
      {:ok, _suggestion} ->
        {:noreply,
         socket
         |> assign(:message, "Suggestion sent for review.")
         |> refresh(socket.assigns.current_scope.user)}

      {:error, reason} ->
        {:noreply, assign(socket, :message, error_message(reason))}
    end
  end

  def handle_event("withdraw", %{"id" => id}, socket) do
    case suggestion(socket, id) do
      nil ->
        {:noreply, assign(socket, :message, "That suggestion no longer exists.")}

      suggestion ->
        case Themes.withdraw_suggestion(socket.assigns.current_scope, suggestion) do
          {:ok, _suggestion} ->
            {:noreply,
             socket
             |> assign(:message, "Suggestion withdrawn.")
             |> refresh(socket.assigns.current_scope.user)}

          {:error, reason} ->
            {:noreply, assign(socket, :message, error_message(reason))}
        end
    end
  end

  defp load(socket, user) do
    endgame = Repo.preload(socket.assigns.endgame, :themes)
    pending = Themes.pending_suggestions_for_user(endgame.id, user.id)
    counts = Themes.pending_suggestion_counts(endgame.id)
    total = Themes.pending_suggestion_count(endgame.id)

    assign(socket,
      endgame: endgame,
      themes: endgame.themes,
      pending: pending,
      pending_counts: counts,
      pending_total: total,
      loaded_for: endgame.id,
      results: search_results(socket.assigns.query, endgame.themes, pending, counts)
    )
  end

  defp refresh(socket, user) do
    endgame = Repo.preload(socket.assigns.endgame, :themes)
    pending = Themes.pending_suggestions_for_user(endgame.id, user.id)
    counts = Themes.pending_suggestion_counts(endgame.id)
    total = Themes.pending_suggestion_count(endgame.id)

    assign(socket,
      endgame: endgame,
      themes: endgame.themes,
      pending: pending,
      pending_counts: counts,
      pending_total: total,
      results: search_results(socket.assigns.query, endgame.themes, pending, counts)
    )
  end

  defp search_results(query, themes, pending, counts) do
    trimmed = String.trim(query)

    if trimmed == "" do
      []
    else
      exclude_ids =
        Enum.map(themes, & &1.id) ++
          (pending |> Enum.map(& &1.theme_id) |> Enum.reject(&is_nil/1))

      Themes.search(trimmed, "endgame", kind: :technique, exclude_ids: exclude_ids)
      |> Enum.map(&{&1, Map.get(counts, &1.id, 0)})
    end
  end

  defp suggestion(socket, id) do
    Enum.find(socket.assigns.pending, &(&1.id == id)) ||
      Repo.get(ThemeSuggestion, id)
  end

  defp pending_label(1), do: "1 pending suggestion for this endgame"
  defp pending_label(count), do: "#{count} pending suggestions for this endgame"

  defp ordered_themes(themes) do
    Enum.sort_by(themes, fn theme -> {kind_rank(theme.kind), theme.name} end)
  end

  defp kind_rank(:technique), do: 0
  defp kind_rank(:motif), do: 1
  defp kind_rank(:material), do: 2
  defp kind_rank(_kind), do: 3

  defp pending_count(counts, theme), do: Map.get(counts, theme.id, 0)

  defp suggestion_label(%{theme: %{name: name}}), do: name
  defp suggestion_label(%{proposed_name: name}), do: ~s("#{name}")

  defp signed_in?(%Scope{user: %User{}}), do: true
  defp signed_in?(_scope), do: false

  defp error_message(:unauthorized), do: "Sign in to suggest a theme."
  defp error_message(:not_attempted), do: "Finish the puzzle before suggesting a theme."
  defp error_message(:already_tagged), do: "This endgame already carries that theme."
  defp error_message(:not_suggestible), do: "Only technique themes can be suggested."
  defp error_message(:blank_name), do: "Enter a theme name."
  defp error_message(:name_too_long), do: "That name is too long."
  defp error_message(:unknown_theme), do: "That theme no longer exists."
  defp error_message(:not_pending), do: "That suggestion is no longer pending."

  defp error_message(%Ecto.Changeset{errors: [{_field, {message, _opts}} | _]}),
    do: message

  defp error_message(_reason), do: "Could not save that suggestion."
end
