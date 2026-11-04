defmodule ChesstrainerWeb.EndgameLive.PlayerIndex do
  use ChesstrainerWeb, :live_view

  import ChesstrainerWeb.EndgameList

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
  def handle_event(event, params, socket) do
    handle_filter_event(event, params, socket)
  end
end
