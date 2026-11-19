defmodule ChesstrainerWeb.EndgameLive.PlayerIndex do
  use ChesstrainerWeb, :live_view

  import ChesstrainerWeb.EndgameList

  alias Chesstrainer.Themes

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <.header>
        Endgames
        <:subtitle>Pick an endgame to play.</:subtitle>
      </.header>

      <.filter_bar
        selected_themes={@selected_themes}
        theme_query={@theme_query}
        theme_results={@theme_results}
        keys={@keys}
        selected_key={@selected_key}
      />

      <div
        :if={@selected_themes != []}
        id="train-theme-links"
        class="mb-4 flex flex-wrap items-center gap-2 text-sm"
      >
        <span class="text-muted">Train this theme:</span>
        <.link
          :for={theme <- @selected_themes}
          navigate={~p"/train/#{theme.slug}"}
          class="font-semibold text-primary-text underline underline-offset-4"
        >
          {theme.name}
        </.link>
      </div>

      <.grouped_list :if={@groups != []} groups={@groups}>
        <:header>
          <tr>
            <th>Color</th>
            <th>Result</th>
            <th>Rating</th>
            <th>Themes</th>
            <th><span class="sr-only">Actions</span></th>
          </tr>
        </:header>

        <:row :let={endgame}>
          <tr id={"endgame-" <> endgame.public_code}>
            <td
              phx-click={JS.navigate(~p"/endgames/#{endgame.public_code}/play")}
              class="hover:cursor-pointer"
            >
              {endgame.color}
            </td>
            <td
              phx-click={JS.navigate(~p"/endgames/#{endgame.public_code}/play")}
              class="hover:cursor-pointer"
            >
              {endgame.result}
            </td>
            <td
              phx-click={JS.navigate(~p"/endgames/#{endgame.public_code}/play")}
              class="hover:cursor-pointer"
            >
              {round(endgame.rating)}
            </td>
            <td>
              <.badge :for={theme <- endgame.themes} size="sm">
                <button type="button" phx-click="add_theme" phx-value-id={theme.id}>
                  {theme.name}
                </button>
              </.badge>
              <span :if={endgame.themes == []} class="text-base-content/50">None</span>
            </td>
            <td class="w-0 font-semibold">
              <.link navigate={~p"/endgames/#{endgame.public_code}/play"}>Play</.link>
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
     |> assign(:page_title, "Endgames")
     |> init_state()}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    {:noreply,
     socket
     |> apply_filters(params)
     |> assign(:theme_query, "")
     |> assign(:theme_results, [])
     |> refresh()}
  end

  # Every filter change is a patch, so the selection lives in the address bar
  # and can be reloaded, linked and stepped through with the browser's history.
  @impl true
  def handle_event("add_theme", %{"id" => id}, socket) do
    theme = Themes.get_theme!(id)

    patch_filters(socket, Enum.uniq_by(socket.assigns.selected_themes ++ [theme], & &1.id))
  end

  def handle_event("remove_theme", %{"id" => id}, socket) do
    themes = Enum.reject(socket.assigns.selected_themes, &(Integer.to_string(&1.id) == id))

    patch_filters(socket, themes)
  end

  def handle_event("filter_key", %{"key" => key}, socket) do
    patch_filters(socket, socket.assigns.selected_themes, blank_to_nil(key))
  end

  def handle_event("clear_filters", _params, socket), do: patch_filters(socket, [], nil)

  def handle_event(event, params, socket), do: handle_filter_event(event, params, socket)

  defp patch_filters(socket, themes, key \\ nil) do
    {:noreply, push_patch(socket, to: filters_path(themes, key))}
  end

  defp filters_path(themes, key) do
    query =
      []
      |> put_query(:themes, Enum.map_join(themes, ",", & &1.slug))
      |> put_query(:key, key)

    if query == [] do
      ~p"/endgames"
    else
      ~p"/endgames?#{query}"
    end
  end

  defp put_query(query, _name, value) when value in [nil, ""], do: query
  defp put_query(query, name, value), do: query ++ [{name, value}]

  defp apply_filters(socket, params) do
    themes =
      params
      |> Map.get("themes", "")
      |> String.split(",", trim: true)
      |> Enum.uniq()
      |> Enum.map(&Themes.get_theme_by_slug/1)
      |> Enum.reject(&is_nil/1)

    key = blank_to_nil(Map.get(params, "key"))
    key = if key in socket.assigns.keys, do: key, else: nil

    socket
    |> assign(:selected_themes, themes)
    |> assign(:selected_key, key)
  end

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: value
end
