defmodule ChesstrainerWeb.EndgameList do
  @moduledoc """
  Shared, server-rendered filter bar and Key-grouped endgame list.

  The parent LiveView owns the filter/group state (see `ChesstrainerWeb.EndgameLive.Index`)
  and handles the `search_themes`, `add_theme`, `remove_theme`, `filter_key`,
  `clear_filters` and `toggle_group` events. Groups are rendered collapsed; the
  parent fetches a group's endgames only when it is expanded.
  """

  use ChesstrainerWeb, :html

  attr :selected_themes, :list, required: true
  attr :theme_query, :string, required: true
  attr :theme_results, :list, required: true
  attr :keys, :list, required: true
  attr :selected_key, :string, default: nil

  def filter_bar(assigns) do
    ~H"""
    <div class="mb-6 space-y-3">
      <div :if={@selected_themes != []} class="flex flex-wrap gap-2">
        <span :for={theme <- @selected_themes} class="badge badge-primary gap-1">
          {theme.name}
          <button
            type="button"
            phx-click="remove_theme"
            phx-value-id={theme.id}
            aria-label={"Remove #{theme.name}"}
          >
            ×
          </button>
        </span>
      </div>

      <div class="flex flex-col gap-3 sm:flex-row">
        <form id="theme-filter-form" phx-change="search_themes" class="flex-1">
          <input
            type="text"
            name="theme_search"
            value={@theme_query}
            phx-debounce="200"
            autocomplete="off"
            placeholder="Filter by theme…"
            class="input input-bordered w-full"
          />

          <ul :if={@theme_results != []} class="menu bg-base-100 rounded-box mt-2">
            <li :for={theme <- @theme_results}>
              <button type="button" phx-click="add_theme" phx-value-id={theme.id}>
                {theme.name}
              </button>
            </li>
          </ul>
        </form>

        <form id="key-filter-form" phx-change="filter_key" class="flex-1">
          <select name="key" class="select w-full">
            <option value="" selected={is_nil(@selected_key)}>All keys</option>
            <option :for={key <- @keys} value={key} selected={key == @selected_key}>
              {key}
            </option>
          </select>
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
            <span class="badge">{group.count}</span>
            <.icon
              name={if group.expanded, do: "hero-chevron-down", else: "hero-chevron-right"}
              class="size-4"
            />
          </span>
        </button>

        <table :if={group.expanded} class="table table-zebra">
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
