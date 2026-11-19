defmodule ChesstrainerWeb.EndgameLive.PlayerIndex do
  use ChesstrainerWeb, :live_view

  import ChesstrainerWeb.EndgameList

  alias Chesstrainer.Themes
  alias ChesstrainerWeb.CollectionParams

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

      <div class="mb-4">
        <.button
          id="play-collection"
          variant="primary"
          navigate={play_path(@selected_themes, @selected_key)}
        >
          <.icon name="hero-play" /> Play these {collection_count(@groups)}
        </.button>
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
    case CollectionParams.params(%{themes: themes, key: key}) do
      [] -> ~p"/endgames"
      params -> ~p"/endgames?#{params}"
    end
  end

  defp play_path(themes, key) do
    case CollectionParams.params(%{themes: themes, key: key}) do
      [] -> ~p"/train"
      params -> ~p"/train?#{params}"
    end
  end

  defp apply_filters(socket, params) do
    collection = CollectionParams.parse(params)

    socket
    |> assign(:selected_themes, collection.themes)
    |> assign(:selected_key, collection.key)
  end

  defp collection_count(groups), do: Enum.sum(Enum.map(groups, & &1.count))

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(value), do: value
end
