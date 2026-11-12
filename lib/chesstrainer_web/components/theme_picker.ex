defmodule ChesstrainerWeb.ThemePicker do
  @moduledoc """
  Search-and-select control shared by the endgame form and bulk importer.

  The parent LiveView owns the assignments and handles the events:
  `search_themes`, `add_theme`, `create_theme`, `create_theme_from_search` and
  `remove_theme`.
  """

  use ChesstrainerWeb, :html

  alias Chesstrainer.Themes

  attr :selected_themes, :list, required: true
  attr :theme_query, :string, required: true
  attr :theme_results, :list, required: true
  attr :can_create, :boolean, required: true

  def theme_picker(assigns) do
    ~H"""
    <div class="mb-6">
      <span class="mb-1 block text-sm font-medium text-base-content">Themes</span>

      <div class="flex flex-wrap gap-2 mb-2">
        <.badge :for={theme <- @selected_themes} color="primary">
          {theme.name}
          <button
            type="button"
            phx-click="remove_theme"
            phx-value-id={theme.id}
            aria-label={"Remove #{theme.name}"}
          >
            ×
          </button>
        </.badge>
      </div>

      <form id="theme-form" phx-change="search_themes" phx-submit="create_theme_from_search">
        <.input
          name="theme_search"
          value={@theme_query}
          phx-debounce="200"
          autocomplete="off"
          placeholder="Search or create a theme…"
        />

        <ul>
          <li :for={theme <- @theme_results}>
            <button
              type="button"
              phx-click="add_theme"
              phx-value-id={theme.id}
              class="block w-full rounded px-3 py-2 text-left text-sm hover:bg-base-200"
            >
              {theme.name}
            </button>
          </li>

          <li :if={@can_create}>
            <button
              type="button"
              phx-click="create_theme"
              phx-value-name={@theme_query}
              class="block w-full rounded px-3 py-2 text-left text-sm hover:bg-base-200"
            >
              Create theme "{String.trim(@theme_query)}"
            </button>
          </li>
        </ul>
      </form>
    </div>
    """
  end

  @doc """
  Updates the search query, matching endgame themes and whether the query can be
  created as a new theme.
  """
  def assign_search(socket, query) do
    trimmed = String.trim(query)
    results = Themes.search(query, "endgame")

    can_create =
      trimmed != "" and
        not Enum.any?(results, &(String.downcase(&1.name) == String.downcase(trimmed)))

    socket
    |> assign(:theme_query, query)
    |> assign(:theme_results, results)
    |> assign(:can_create, can_create)
  end

  @doc """
  Creates a theme from the search box (or selects the existing match) and adds
  it to the selected themes.
  """
  def create_theme(socket, name) do
    if String.trim(name) == "" do
      socket
    else
      case Themes.get_or_create(name, "endgame") do
        {:ok, theme} ->
          socket |> add_selected_theme(theme) |> clear_search()

        {:error, _reason} ->
          Phoenix.LiveView.put_flash(socket, :error, "Could not create that theme.")
      end
    end
  end

  @doc """
  Clears the theme search results.
  """
  def clear_search(socket) do
    socket
    |> assign(:theme_query, "")
    |> assign(:theme_results, [])
    |> assign(:can_create, false)
  end

  @doc """
  Adds a theme to the selected themes, ignoring duplicates.
  """
  def add_selected_theme(socket, theme) do
    if Enum.any?(socket.assigns.selected_themes, &(&1.id == theme.id)) do
      socket
    else
      assign(socket, :selected_themes, socket.assigns.selected_themes ++ [theme])
    end
  end
end
