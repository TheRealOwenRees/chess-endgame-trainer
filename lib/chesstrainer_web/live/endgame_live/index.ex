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

      <.form
        for={@search_form}
        id="endgame-search-form"
        phx-submit="endgame_search"
        class="mb-6 flex items-end gap-2"
      >
        <div class="flex-1">
          <.input
            field={@search_form[:query]}
            type="text"
            label="Find by ID or FEN"
            autocomplete="off"
            placeholder="Public code, database id, or FEN…"
          />
        </div>
        <.button variant="primary">Find</.button>
      </.form>

      <div :if={@search_query} id="endgame-search-results" class="space-y-3">
        <div class="flex items-center justify-between">
          <p class="text-sm text-base-content/70">Results for “{@search_query}”</p>
          <button
            type="button"
            id="clear-endgame-search"
            phx-click="clear_search"
            class="text-sm text-primary underline underline-offset-4 hover:text-primary/80"
          >
            Clear
          </button>
        </div>

        <p :if={@search_results == []} class="text-base-content/70">
          No endgame matches “{@search_query}”.
        </p>

        <table :if={@search_results != []} class={table_class()}>
          <thead>
            <tr>
              <th>Key</th>
              <th>Color</th>
              <th>Result</th>
              <th>Rating</th>
              <th><span class="sr-only">Actions</span></th>
            </tr>
          </thead>
          <tbody>
            <tr :for={endgame <- @search_results} id={"search-result-" <> endgame.id}>
              <td>{endgame.key}</td>
              <td>{endgame.color}</td>
              <td>{endgame.result}</td>
              <td>{round(endgame.rating)}</td>
              <td class="w-0 font-semibold">
                <.link navigate={~p"/admin/endgames/#{endgame.id}"}>Show</.link>
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <.filter_bar
        :if={!@search_query}
        selected_themes={@selected_themes}
        theme_query={@theme_query}
        theme_results={@theme_results}
        keys={@keys}
        selected_key={@selected_key}
      />

      <.grouped_list :if={!@search_query and @groups != []} groups={@groups}>
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
            <td
              phx-click={JS.navigate(~p"/admin/endgames/#{endgame.id}")}
              class="hover:cursor-pointer"
            >
              {endgame.key}
            </td>
            <td
              phx-click={JS.navigate(~p"/admin/endgames/#{endgame.id}")}
              class="hover:cursor-pointer"
            >
              {endgame.color}
            </td>
            <td
              phx-click={JS.navigate(~p"/admin/endgames/#{endgame.id}")}
              class="hover:cursor-pointer"
            >
              {endgame.result}
            </td>
            <td>
              <.badge :for={theme <- endgame.themes} size="sm">
                <button type="button" phx-click="add_theme" phx-value-id={theme.id}>
                  {theme.name}
                </button>
              </.badge>
              <span :if={endgame.themes == []} class="text-base-content/50">None</span>
            </td>
            <td
              phx-click={JS.navigate(~p"/admin/endgames/#{endgame.id}")}
              class="hover:cursor-pointer"
            >
              {round(endgame.rating)}
            </td>
            <td class="w-0 font-semibold">
              <div class="flex gap-4">
                <.link navigate={~p"/admin/endgames/#{endgame.id}"}>Show</.link>
                <.link navigate={~p"/endgames/#{endgame.public_code}/play"}>Play</.link>
                <.link navigate={~p"/admin/endgames/#{endgame.id}/edit"}>Edit</.link>
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

      <p :if={!@search_query and @groups == []} class="text-base-content/70">
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
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> assign(:search_query, nil)
     |> assign(:search_results, [])
     |> init_state()}
  end

  @impl true
  def handle_event("endgame_search", %{"query" => query}, socket) do
    query = String.trim(query)

    case {query, Endgames.search(query)} do
      {"", _results} ->
        {:noreply, clear_search(socket)}

      {_query, [endgame]} ->
        {:noreply, push_navigate(socket, to: ~p"/admin/endgames/#{endgame.id}")}

      {query, results} ->
        {:noreply,
         assign(socket,
           search_form: to_form(%{"query" => query}),
           search_query: query,
           search_results: results
         )}
    end
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, clear_search(socket)}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    endgame = Endgames.get_endgame!(id)
    {:ok, _} = Endgames.delete_endgame(endgame)

    {:noreply, refresh(socket)}
  end

  def handle_event(event, params, socket) do
    handle_filter_event(event, params, socket)
  end

  defp clear_search(socket) do
    assign(socket,
      search_form: to_form(%{"query" => ""}),
      search_query: nil,
      search_results: []
    )
  end
end
