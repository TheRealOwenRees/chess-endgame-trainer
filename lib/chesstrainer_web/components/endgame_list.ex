defmodule ChesstrainerWeb.EndgameList do
  @moduledoc """
  Shared, server-rendered filter bar and Key-grouped endgame list.

  The parent LiveView owns the filter/group state (see `ChesstrainerWeb.EndgameLive.Index`)
  and handles the `search_themes`, `add_theme`, `remove_theme`, `filter_key`,
  `clear_filters` and `toggle_group` events. Groups are rendered collapsed; the
  parent fetches a group's endgames only when it is expanded.
  """

  use ChesstrainerWeb, :html

  alias Chesstrainer.Endgames
  alias Chesstrainer.Themes

  @doc """
  Initialises the filter/group assigns for a filtered, Key-grouped endgame list.
  """
  def init_state(socket) do
    socket
    |> assign(:selected_themes, [])
    |> assign(:theme_query, "")
    |> assign(:theme_results, [])
    |> assign(:selected_key, nil)
    |> assign(:keys, Endgames.list_keys())
    |> assign(:groups, build_groups(%{}))
  end

  @doc """
  Handles the filter/group events shared by the admin and player lists.
  """
  def handle_filter_event("search_themes", %{"theme_search" => query}, socket) do
    results = if String.trim(query) == "", do: [], else: Themes.search(query, "endgame")

    {:noreply, assign(socket, theme_query: query, theme_results: results)}
  end

  def handle_filter_event("add_theme", %{"id" => id}, socket) do
    theme = Themes.get_theme!(id)

    selected =
      if Enum.any?(socket.assigns.selected_themes, &(&1.id == theme.id)) do
        socket.assigns.selected_themes
      else
        socket.assigns.selected_themes ++ [theme]
      end

    {:noreply,
     socket
     |> assign(:selected_themes, selected)
     |> clear_theme_search()
     |> refresh()}
  end

  def handle_filter_event("remove_theme", %{"id" => id}, socket) do
    selected = Enum.reject(socket.assigns.selected_themes, &(Integer.to_string(&1.id) == id))

    {:noreply, socket |> assign(:selected_themes, selected) |> refresh()}
  end

  def handle_filter_event("filter_key", %{"key" => key}, socket) do
    {:noreply,
     socket
     |> assign(:selected_key, if(key == "", do: nil, else: key))
     |> refresh()}
  end

  def handle_filter_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_themes, [])
     |> assign(:selected_key, nil)
     |> clear_theme_search()
     |> refresh()}
  end

  def handle_filter_event("toggle_group", %{"key" => key}, socket) do
    groups =
      Enum.map(socket.assigns.groups, fn group ->
        cond do
          group.key != key ->
            group

          group.expanded ->
            %{group | expanded: false, endgames: nil}

          true ->
            endgames = Endgames.list_endgames_for_key(key, current_filters(socket.assigns))
            %{group | expanded: true, endgames: endgames}
        end
      end)

    {:noreply, assign(socket, :groups, groups)}
  end

  def handle_filter_event(_event, _params, socket), do: {:noreply, socket}

  @doc """
  Rebuilds the Key list and groups from the current filters.
  """
  def refresh(socket) do
    filters = current_filters(socket.assigns)

    socket
    |> assign(:keys, Endgames.list_keys())
    |> assign(:groups, build_groups(filters))
  end

  defp build_groups(filters) do
    Enum.map(
      Endgames.list_key_groups(filters),
      fn {key, count} -> %{key: key, count: count, expanded: false, endgames: nil} end
    )
  end

  defp current_filters(assigns) do
    %{themes: Enum.map(assigns.selected_themes, & &1.id), key: assigns.selected_key}
  end

  defp clear_theme_search(socket), do: assign(socket, theme_query: "", theme_results: [])

  attr :selected_themes, :list, required: true
  attr :theme_query, :string, required: true
  attr :theme_results, :list, required: true
  attr :keys, :list, required: true
  attr :selected_key, :string, default: nil

  def filter_bar(assigns) do
    ~H"""
    <div class="mb-6 space-y-3">
      <div :if={@selected_themes != []} class="flex flex-wrap gap-2">
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

      <div class="flex flex-col gap-3 sm:flex-row">
        <form id="theme-filter-form" phx-change="search_themes" class="flex-1">
          <.input
            name="theme_search"
            value={@theme_query}
            phx-debounce="200"
            autocomplete="off"
            placeholder="Filter by theme…"
          />

          <ul
            :if={@theme_results != []}
            class="mt-2 w-full rounded-md border border-base-300 bg-base-100 p-1 shadow-sm"
          >
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
          </ul>
        </form>

        <form id="key-filter-form" phx-change="filter_key" class="flex-1">
          <.input
            type="select"
            name="key"
            prompt="All keys"
            options={@keys}
            value={@selected_key}
          />
        </form>
      </div>

      <button
        :if={@selected_themes != [] or @selected_key}
        type="button"
        phx-click="clear_filters"
        class="text-sm underline"
      >
        Clear filters
      </button>
    </div>
    """
  end

  attr :groups, :list, required: true
  slot :header, required: true
  slot :row, required: true

  def grouped_list(assigns) do
    ~H"""
    <div class="space-y-3">
      <section :for={group <- @groups} id={"key-group-" <> String.replace(group.key, " ", "-")}>
        <button
          type="button"
          phx-click="toggle_group"
          phx-value-key={group.key}
          aria-expanded={to_string(group.expanded)}
          class="flex w-full items-center justify-between gap-3 rounded bg-base-200 px-3 py-2 text-left"
        >
          <span class="font-semibold">{group.key}</span>
          <span class="flex items-center gap-2 text-sm">
            <.badge id={"key-group-count-" <> String.replace(group.key, " ", "-")}>
              {group.count}
            </.badge>
            <.icon
              name={if group.expanded, do: "hero-chevron-down", else: "hero-chevron-right"}
              class="size-4"
            />
          </span>
        </button>

        <table :if={group.expanded} class={table_class()}>
          <thead>
            {render_slot(@header)}
          </thead>
          <tbody>
            <%= for endgame <- group.endgames do %>
              {render_slot(@row, endgame)}
            <% end %>
          </tbody>
        </table>
      </section>
    </div>
    """
  end
end
