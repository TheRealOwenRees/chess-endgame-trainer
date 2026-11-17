defmodule ChesstrainerWeb.Admin.ThemeLive.Tag do
  @moduledoc """
  Workspace for applying a technique theme to endgames by family.

  Candidates are grouped by Key so an admin tags a whole family rather than
  individual rows. Boards are previews only; nothing here starts a puzzle.
  Only technique themes can be tagged, because material themes are derived and
  a hand-made link would be erased by the next refresh.
  """

  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.Game
  alias Chesstrainer.Themes

  import ChesstrainerWeb.Board.BoardComponent

  @page_size 24

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        Tag “{@theme.name}”
        <:subtitle>
          Pick a family, preview the positions and apply the theme in bulk. The links are
          recorded as curated, so derivation never overwrites them.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/themes"}>
            <.icon name="hero-arrow-left" /> All themes
          </.button>
        </:actions>
      </.header>

      <.form
        for={@theme_form}
        id="theme-workspace-form"
        phx-change="select_theme"
        class="mb-6 max-w-md"
      >
        <.input
          field={@theme_form[:theme_id]}
          type="select"
          label="Technique theme"
          options={@theme_options}
        />
      </.form>

      <div class="mb-6 flex flex-wrap gap-6 text-sm">
        <span>
          <span class="font-semibold" id="tagged-count">{@tagged_count}</span> tagged
        </span>
        <span>
          <span class="font-semibold" id="candidate-count">{@candidate_count}</span> candidates
        </span>
      </div>

      <div
        :if={MapSet.size(@selected) > 0}
        id="selection-bar"
        class="sticky top-0 z-10 mb-6 flex flex-wrap items-center gap-3 rounded-lg border border-primary/30 bg-base-100 p-3 text-sm"
      >
        <span class="font-semibold">{MapSet.size(@selected)} selected</span>
        <button
          type="button"
          id="apply-theme"
          phx-click="apply"
          class="font-semibold text-primary-text"
        >
          Apply “{@theme.name}”
        </button>
        <button type="button" phx-click="clear_selection" class="text-base-content/70">
          Clear selection
        </button>
      </div>

      <section class="mb-12">
        <h2 class="mb-3 text-lg font-semibold">Candidates</h2>
        <p :if={@candidate_groups == []} class="text-base-content/70">
          Every endgame already carries this theme.
        </p>

        <table :if={@candidate_groups != []} class={table_class()}>
          <thead>
            <tr>
              <th>Key</th>
              <th>Endgames</th>
              <th><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{key, count} <- @candidate_groups} id={"candidates-#{group_id(key)}"}>
              <td class="font-mono">{key}</td>
              <td>{count}</td>
              <td class="w-0">
                <button
                  type="button"
                  id={"toggle-candidates-#{group_id(key)}"}
                  phx-click="toggle_group"
                  phx-value-key={key}
                  phx-value-view="candidates"
                  class="font-semibold text-primary-text"
                >
                  {open_label(@open, key, "candidates")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <.group_panel
          :if={@open && @open.view == "candidates"}
          view="candidates"
          group={@open.key}
          items={@items}
          selected={@selected}
          page={@page}
          pages={@pages}
        />
      </section>

      <section>
        <h2 class="mb-3 text-lg font-semibold">Curated links</h2>
        <p :if={@tagged_groups == []} class="text-base-content/70">
          No endgame carries this theme yet.
        </p>

        <table :if={@tagged_groups != []} class={table_class()}>
          <thead>
            <tr>
              <th>Key</th>
              <th>Endgames</th>
              <th><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={{key, count} <- @tagged_groups} id={"tagged-#{group_id(key)}"}>
              <td class="font-mono">{key}</td>
              <td>{count}</td>
              <td class="w-0">
                <button
                  type="button"
                  id={"toggle-tagged-#{group_id(key)}"}
                  phx-click="toggle_group"
                  phx-value-key={key}
                  phx-value-view="tagged"
                  class="font-semibold text-primary-text"
                >
                  {open_label(@open, key, "tagged")}
                </button>
              </td>
            </tr>
          </tbody>
        </table>

        <.group_panel
          :if={@open && @open.view == "tagged"}
          view="tagged"
          group={@open.key}
          items={@items}
          selected={@selected}
          page={@page}
          pages={@pages}
        />
      </section>
    </Layouts.app>
    """
  end

  attr :view, :string, required: true
  attr :group, :string, required: true
  attr :items, :list, required: true
  attr :selected, :any, required: true
  attr :page, :integer, required: true
  attr :pages, :integer, required: true

  defp group_panel(assigns) do
    ~H"""
    <div id="group-panel" class="mt-4">
      <div :if={@view == "candidates"} class="mb-3 flex gap-3 text-sm">
        <button
          type="button"
          id="select-page"
          phx-click="select_page"
          class="font-semibold text-primary-text"
        >
          Select this page
        </button>
        <span class="text-base-content/60">{@group}</span>
      </div>

      <p :if={@items == []} class="text-base-content/70">No endgames on this page.</p>

      <div class="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4">
        <div
          :for={endgame <- @items}
          id={"endgame-#{endgame.id}"}
          class="rounded-lg border border-base-300 p-3"
        >
          <.board
            game={endgame.game}
            myself={nil}
            interactive={false}
            class="mb-2 w-full max-w-[240px]"
          />
          <p class="break-all font-mono text-xs text-base-content/60">{endgame.fen}</p>

          <label :if={@view == "candidates"} class="mt-2 flex items-center gap-2 text-sm">
            <input
              type="checkbox"
              id={"select-#{endgame.id}"}
              checked={MapSet.member?(@selected, endgame.id)}
              phx-click="toggle_select"
              phx-value-id={endgame.id}
            /> Select
          </label>

          <button
            :if={@view == "tagged"}
            type="button"
            id={"remove-#{endgame.id}"}
            phx-click="remove"
            phx-value-id={endgame.id}
            class="mt-2 text-sm font-semibold text-error"
          >
            Remove
          </button>
        </div>
      </div>

      <div :if={@pages > 1} class="mt-4 flex items-center gap-3 text-sm">
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
    </div>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    theme = Themes.get_theme!(id)

    if theme.category == :endgame and theme.kind == :technique do
      {:ok,
       socket
       |> assign(:page_title, "Tag #{theme.name}")
       |> assign(:theme, theme)
       |> assign(:selected, MapSet.new())
       |> assign(:open, nil)
       |> assign(:items, [])
       |> assign(:page, 1)
       |> assign(:pages, 1)
       |> assign_theme_options()
       |> load_counts()}
    else
      {:ok,
       socket
       |> put_flash(
         :error,
         "Only technique themes can be tagged by hand; material themes are derived."
       )
       |> push_navigate(to: ~p"/admin/themes")}
    end
  end

  @impl true
  def handle_event("select_theme", %{"theme_id" => id}, socket) do
    if to_string(socket.assigns.theme.id) == id do
      {:noreply, socket}
    else
      {:noreply, push_navigate(socket, to: ~p"/admin/themes/#{id}/tag")}
    end
  end

  def handle_event("toggle_group", %{"key" => key, "view" => view}, socket) do
    case socket.assigns.open do
      %{key: ^key, view: ^view} ->
        {:noreply, assign(socket, open: nil, items: [], page: 1, pages: 1)}

      _ ->
        {:noreply, open_group(socket, key, view, 1)}
    end
  end

  def handle_event("page", %{"page" => page}, socket) do
    case socket.assigns.open do
      nil ->
        {:noreply, socket}

      %{key: key, view: view} ->
        {:noreply, open_group(socket, key, view, parse_page(page))}
    end
  end

  def handle_event("toggle_select", %{"id" => id}, socket) do
    selected =
      if MapSet.member?(socket.assigns.selected, id) do
        MapSet.delete(socket.assigns.selected, id)
      else
        MapSet.put(socket.assigns.selected, id)
      end

    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("select_page", _params, socket) do
    page_ids = Enum.map(socket.assigns.items, & &1.id)
    selected = Enum.reduce(page_ids, socket.assigns.selected, &MapSet.put(&2, &1))
    {:noreply, assign(socket, :selected, selected)}
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, :selected, MapSet.new())}
  end

  def handle_event("apply", _params, socket) do
    selected = MapSet.to_list(socket.assigns.selected)

    if selected == [] do
      {:noreply, put_flash(socket, :error, "Select at least one endgame.")}
    else
      {:ok, count} = Themes.tag_endgames(socket.assigns.theme, selected, :curated)

      {:noreply,
       socket
       |> put_flash(:info, "Tagged #{count} endgame(s) with “#{socket.assigns.theme.name}”.")
       |> assign(:selected, MapSet.new())
       |> assign(open: nil, items: [], page: 1, pages: 1)
       |> load_counts()}
    end
  end

  def handle_event("remove", %{"id" => id}, socket) do
    {:ok, removed} = Themes.untag_endgame(socket.assigns.theme, id, :curated)

    socket =
      socket
      |> put_flash(:info, removal_message(removed, socket.assigns.theme))
      |> load_counts()
      |> refresh_open()

    {:noreply, socket}
  end

  defp removal_message(0, theme), do: "That endgame had no curated “#{theme.name}” link."
  defp removal_message(_, theme), do: "Removed “#{theme.name}” from the endgame."

  defp refresh_open(%{assigns: %{open: nil}} = socket), do: socket

  defp refresh_open(%{assigns: %{open: %{key: key, view: view}, page: page}} = socket) do
    open_group(socket, key, view, page)
  end

  defp open_group(socket, key, view, page) do
    count = group_count(socket, key, view)
    pages = max(ceil_div(count, @page_size), 1)
    page = page |> max(1) |> min(pages)

    endgames =
      Endgames.list_endgames_for_key(key, filters_for(socket.assigns.theme, view),
        limit: @page_size,
        offset: (page - 1) * @page_size
      )
      |> Enum.map(&Map.put(&1, :game, board_game(&1.fen)))

    assign(socket,
      open: %{key: key, view: view},
      items: endgames,
      page: page,
      pages: pages
    )
  end

  defp filters_for(%{id: theme_id}, "tagged"), do: %{with_theme: {theme_id, :curated}}
  defp filters_for(%{id: theme_id}, "candidates"), do: %{without_theme: theme_id}

  defp group_count(socket, key, view) do
    groups =
      if view == "tagged", do: socket.assigns.tagged_groups, else: socket.assigns.candidate_groups

    Enum.find_value(groups, 0, fn
      {^key, count} -> count
      _ -> nil
    end)
  end

  defp parse_page(page) when is_integer(page), do: page

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {value, _} -> value
      :error -> 1
    end
  end

  defp ceil_div(0, _), do: 0
  defp ceil_div(count, size), do: div(count + size - 1, size)

  defp load_counts(socket) do
    theme = socket.assigns.theme
    tagged = Endgames.list_key_groups(%{with_theme: {theme.id, :curated}})
    candidates = Endgames.list_key_groups(%{without_theme: theme.id})

    assign(socket,
      tagged_groups: tagged,
      candidate_groups: candidates,
      tagged_count: total(tagged),
      candidate_count: total(candidates)
    )
  end

  defp total(groups), do: Enum.reduce(groups, 0, fn {_key, count}, acc -> acc + count end)

  defp assign_theme_options(socket) do
    options =
      Themes.list_themes()
      |> Enum.filter(&(&1.category == :endgame and &1.kind == :technique))
      |> Enum.sort_by(& &1.name)
      |> Enum.map(&{&1.name, &1.id})

    assign(socket,
      theme_options: options,
      theme_form: to_form(%{"theme_id" => to_string(socket.assigns.theme.id)})
    )
  end

  defp board_game(fen) do
    case Game.game_from_fen(fen, :endgame) do
      {:ok, game} -> game
      {:error, :invalid_fen, game} -> game
    end
  end

  defp open_label(%{key: key, view: view}, key, view), do: "Hide"
  defp open_label(_open, _key, _view), do: "Show"

  defp group_id(key), do: String.replace(key, ~r/[^A-Za-z0-9]+/, "-")
end
