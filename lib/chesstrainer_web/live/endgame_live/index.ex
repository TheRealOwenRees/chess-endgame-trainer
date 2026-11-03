defmodule ChesstrainerWeb.EndgameLive.Index do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Endgames

  import ChesstrainerWeb.EndgameList

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
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
            <th>Key</th>
            <th>Color</th>
            <th>Result</th>
            <th>Themes</th>
            <th>Rating</th>
            <th><span class="sr-only">Actions</span></th>
          </tr>
        </:header>

        <:row :let={endgame}>
          <tr id={"endgame-" <> endgame.id}>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.key}
            </td>
            <td phx-click={JS.navigate(~p"/admin/endgames/#{endgame}")} class="hover:cursor-pointer">
              {endgame.color}
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
              {round(endgame.rating)}
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
     |> init_state()}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    endgame = Endgames.get_endgame!(id)
    {:ok, _} = Endgames.delete_endgame(endgame)

    {:noreply, refresh(socket)}
  end

  def handle_event(event, params, socket) do
    handle_filter_event(event, params, socket)
  end
end
