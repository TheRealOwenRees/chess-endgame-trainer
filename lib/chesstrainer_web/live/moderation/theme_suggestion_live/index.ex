defmodule ChesstrainerWeb.Moderation.ThemeSuggestionLive.Index do
  @moduledoc """
  Review queue for player theme suggestions.

  Moderators, admins and super admins can approve a suggestion, reject it with a
  reason, or merge a proposed name into an existing technique theme. Approving
  writes the endgame link with source `community`; suggestions themselves never
  touch the library.
  """

  use ChesstrainerWeb, :live_view

  import ChesstrainerWeb.Board.BoardComponent

  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Game
  alias Chesstrainer.Themes

  @page_size 10

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <.header>
        Theme suggestions
        <:subtitle>
          Review what players propose. Approving adds a community link; rejecting keeps a reason.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/"}>Back home</.button>
        </:actions>
      </.header>

      <p id="queue-count" class="mb-6 text-sm text-muted">
        {pending_label(@total)}
      </p>

      <p :if={@entries == []} class="text-base-content/70">
        Nothing is waiting for review.
      </p>

      <div class="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <article
          :for={entry <- @entries}
          id={"suggestion-#{entry.suggestion.id}"}
          class="rounded-xl border border-base-300 p-4"
        >
          <div class="flex gap-4">
            <div class="w-36 flex-none">
              <.board game={entry.game} myself={nil} interactive={false} class="w-full" />
            </div>

            <div class="min-w-0 flex-1">
              <p class="font-semibold">{entry.suggestion.endgame.key}</p>
              <p class="text-xs text-muted">
                Rating {round(entry.suggestion.endgame.rating)} ·
                <a
                  href={~p"/endgames/#{entry.suggestion.endgame.public_code}/play"}
                  target="_blank"
                  class="underline"
                >
                  Play
                </a>
              </p>

              <p class="mt-2 text-sm">
                Suggested:
                <span id={"target-#{entry.suggestion.id}"} class="font-semibold">
                  {suggestion_target(entry.suggestion)}
                </span>
              </p>

              <p class="text-xs text-muted">
                by {entry.suggestion.user.username} · {evidence_label(entry.evidence)}
              </p>

              <div class="mt-2 flex flex-wrap gap-1">
                <.badge :for={theme <- entry.suggestion.endgame.themes} size="sm">
                  {theme.name}
                </.badge>
                <span :if={entry.suggestion.endgame.themes == []} class="text-xs text-muted">
                  No themes yet
                </span>
              </div>

              <div class="mt-3">
                <button
                  type="button"
                  id={"approve-#{entry.suggestion.id}"}
                  phx-click="approve"
                  phx-value-id={entry.suggestion.id}
                  class="rounded bg-primary px-3 py-1.5 text-sm font-semibold text-primary-content"
                >
                  {approve_label(entry.suggestion)}
                </button>
              </div>

              <details class="mt-2">
                <summary class="cursor-pointer text-sm text-error-text">Reject</summary>
                <form
                  id={"reject-#{entry.suggestion.id}"}
                  phx-submit="reject"
                  class="mt-2 space-y-2"
                >
                  <input type="hidden" name="suggestion_id" value={entry.suggestion.id} />
                  <.input
                    name="note"
                    value=""
                    type="textarea"
                    rows="2"
                    label="Reason"
                    placeholder="Why is this suggestion not right?"
                  />
                  <.button>Reject suggestion</.button>
                </form>
              </details>

              <details :if={entry.suggestion.proposed_name} class="mt-2">
                <summary class="cursor-pointer text-sm">Merge into an existing theme</summary>
                <form
                  id={"merge-#{entry.suggestion.id}"}
                  phx-submit="merge"
                  class="mt-2 flex items-end gap-2"
                >
                  <input type="hidden" name="suggestion_id" value={entry.suggestion.id} />
                  <div class="flex-1">
                    <.input
                      name="theme_id"
                      value=""
                      type="select"
                      label="Theme"
                      prompt="Choose a theme"
                      options={@theme_options}
                    />
                  </div>
                  <.button>Merge and approve</.button>
                </form>
              </details>
            </div>
          </div>
        </article>
      </div>

      <div :if={@pages > 1} class="mt-6 flex items-center gap-3 text-sm">
        <button
          type="button"
          phx-click="page"
          phx-value-page={@page - 1}
          disabled={@page <= 1}
          class="font-semibold disabled:opacity-40"
        >
          Previous
        </button>
        <span>Page {@page} of {@pages}</span>
        <button
          type="button"
          phx-click="page"
          phx-value-page={@page + 1}
          disabled={@page >= @pages}
          class="font-semibold disabled:opacity-40"
        >
          Next
        </button>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    if Policy.can?(socket.assigns.current_scope, :review_theme_suggestions) do
      {:ok,
       socket
       |> assign(:page_title, "Theme suggestions")
       |> assign(:page, 1)
       |> load()}
    else
      {:ok,
       socket
       |> put_flash(:error, "You are not authorized to review theme suggestions.")
       |> push_navigate(to: ~p"/")}
    end
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    review(socket, id, "Suggestion approved.", fn suggestion ->
      Themes.approve_suggestion(socket.assigns.current_scope, suggestion)
    end)
  end

  def handle_event("merge", %{"suggestion_id" => id, "theme_id" => theme_id}, socket) do
    review(socket, id, "Suggestion merged and approved.", fn suggestion ->
      Themes.approve_suggestion(socket.assigns.current_scope, suggestion, theme_id: theme_id)
    end)
  end

  def handle_event("reject", %{"suggestion_id" => id, "note" => note}, socket) do
    review(socket, id, "Suggestion rejected.", fn suggestion ->
      Themes.reject_suggestion(socket.assigns.current_scope, suggestion, note)
    end)
  end

  def handle_event("page", %{"page" => page}, socket) do
    {:noreply, socket |> assign(:page, parse_page(page)) |> load()}
  end

  defp review(socket, id, success, fun) do
    case fun.(Themes.get_suggestion!(id)) do
      {:ok, _suggestion} ->
        {:noreply, socket |> put_flash(:info, success) |> load()}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, error_message(reason))}
    end
  end

  defp load(socket) do
    total = Themes.count_pending_suggestions()
    pages = max(ceil_div(total, @page_size), 1)
    page = socket.assigns.page |> max(1) |> min(pages)

    suggestions =
      Themes.list_pending_suggestions(limit: @page_size, offset: (page - 1) * @page_size)

    evidence = Themes.pending_evidence(suggestions)

    entries =
      Enum.map(suggestions, fn suggestion ->
        %{
          suggestion: suggestion,
          evidence: Map.get(evidence, suggestion.id, 0),
          game: board_game(suggestion.endgame.fen)
        }
      end)

    assign(socket,
      entries: entries,
      total: total,
      page: page,
      pages: pages,
      theme_options: theme_options()
    )
  end

  defp theme_options do
    Themes.list_themes()
    |> Enum.filter(&(&1.category == :endgame and &1.kind == :technique))
    |> Enum.sort_by(& &1.name)
    |> Enum.map(&{&1.name, &1.id})
  end

  defp board_game(fen) do
    case Game.game_from_fen(fen, :endgame) do
      {:ok, game} -> game
      {:error, :invalid_fen, game} -> game
    end
  end

  defp suggestion_target(%{theme: %{name: name}}), do: name
  defp suggestion_target(%{proposed_name: name}), do: ~s("#{name}")

  defp approve_label(%{proposed_name: nil}), do: "Approve"
  defp approve_label(_suggestion), do: "Approve as new theme"

  defp evidence_label(1), do: "1 suggestion"
  defp evidence_label(count), do: "#{count} suggestions"

  defp pending_label(1), do: "1 pending suggestion"
  defp pending_label(count), do: "#{count} pending suggestions"

  defp parse_page(page) when is_integer(page), do: page

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {value, _rest} -> value
      :error -> 1
    end
  end

  defp ceil_div(0, _size), do: 0
  defp ceil_div(count, size), do: div(count + size - 1, size)

  defp error_message(:unauthorized), do: "You are not authorized to review suggestions."
  defp error_message(:not_pending), do: "That suggestion was already reviewed."
  defp error_message(:note_required), do: "Give a reason before rejecting."
  defp error_message(:not_suggestible), do: "Only technique themes can be approved here."
  defp error_message(:unknown_theme), do: "That theme no longer exists."
  defp error_message(:invalid_name), do: "That name could not be turned into a theme."

  defp error_message(%Ecto.Changeset{errors: [{_field, {message, _opts}} | _]}),
    do: message

  defp error_message(_reason), do: "That suggestion could not be reviewed."
end
