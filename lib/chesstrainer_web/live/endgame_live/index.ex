defmodule ChesstrainerWeb.EndgameLive.Index do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames
  alias Chesstrainer.Themes

  import ChesstrainerWeb.EndgameList

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Listing Endgames
        <:actions>
          <.button variant="primary" navigate={~p"/admin/endgames/new"}>
            <.icon name="hero-plus" /> New Endgame
          </.button>
        </:actions>
      </.header>

      <.filter_bar
        selected_themes={@selected_themes}
        theme_query={@theme_query}
        theme_results={@theme_results}
        keys={@keys}
        selected_key={@selected_key}
      />

      <.grouped_list :if={@groups != []} groups={@groups}>
        <:header>
          <tr>
            <th>Fen</th>
            <th>Color</th>
            <th>Key</th>
            <th>Rating</th>
            <th>Message</th>
            <th>Notes</th>
            <th>Result</th>
            <th>Themes</th>
            <th>Attempted</th>
            <th>Solved</th>
            <th><span class="sr-only">Actions</span></th>
          </tr>
        </:header>

        <:row :let={endgame}>
          <tr id={"endgame-" <> endgame.id}>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.fen}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.color}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.key}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.rating}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.message}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.notes}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.result}
            </td>
            <td>
              <span :for={theme <- endgame.themes} class="badge badge-sm">
                <button type="button" phx-click="add_theme" phx-value-id={theme.id}>
                  {theme.name}
                </button>
              </span>
              <span :if={endgame.themes == []} class="text-base-content/50">None</span>
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.times_attempted}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.times_solved}
            </td>
            <td class="w-0 font-semibold">
              <div class="flex gap-4">
                <.link navigate={~p"/admin/endgames/#{endgame}"}>Show</.link>
                <.link navigate={~p"/endgames/#{endgame}/play"}>Play</.link>
                <.link navigate={~p"/admin/endgames/#{endgame}/edit"}>Edit</.link>
                <.link
                  phx-click={JS.push("delete", value: %{id: endgame.id})}
                  data-confirm="Are you sure?"
                >
                  Delete
                </.link>
              </div>
            </td>
          </tr>
        </:row>
      </.grouped_list>

      <p :if={@groups == []} class="text-base-content/70">
        No endgames match these filters.
      </p>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Listing Endgames")
     |> assign(:selected_themes, [])
     |> assign(:theme_query, "")
     |> assign(:theme_results, [])
     |> assign(:selected_key, nil)
     |> assign(:keys, Endgames.list_keys())
     |> assign(:groups, build_groups(%{}))}
  end

  @impl true
  def handle_event("search_themes", %{"theme_search" => query}, socket) do
    results = if String.trim(query) == "", do: [], else: Themes.search(query, "endgame")

    {:noreply, assign(socket, theme_query: query, theme_results: results)}
  end

  def handle_event("add_theme", %{"id" => id}, socket) do
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
     |> refresh_groups()}
  end

  def handle_event("remove_theme", %{"id" => id}, socket) do
    selected = Enum.reject(socket.assigns.selected_themes, &(Integer.to_string(&1.id) == id))

    {:noreply, socket |> assign(:selected_themes, selected) |> refresh_groups()}
  end

  def handle_event("filter_key", %{"key" => key}, socket) do
    {:noreply,
     socket
     |> assign(:selected_key, if(key == "", do: nil, else: key))
     |> refresh_groups()}
  end

  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:selected_themes, [])
     |> assign(:selected_key, nil)
     |> clear_theme_search()
     |> refresh_groups()}
  end

  def handle_event("toggle_group", %{"key" => key}, socket) do
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

  def handle_event("delete", %{"id" => id}, socket) do
    endgame = Endgames.get_endgame!(id)
    {:ok, _} = Endgames.delete_endgame(endgame)

    {:noreply, refresh_groups(socket)}
  end

  defp refresh_groups(socket) do
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
    %{
      themes: Enum.map(assigns.selected_themes, & &1.id),
      key: assigns.selected_key
    }
  end

  defp clear_theme_search(socket) do
    assign(socket, theme_query: "", theme_results: [])
  end
end
