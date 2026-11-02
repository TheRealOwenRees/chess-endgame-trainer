defmodule ChesstrainerWeb.EndgameLive.Form do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Repo
  alias Chesstrainer.Themes
  alias Chesstrainer.FEN
  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Endgame

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        {@page_title}
        <:subtitle>Use this form to manage endgame records in your database.</:subtitle>
      </.header>

      <div class="field mb-6">
        <label class="label">
          <span class="label-text">Themes</span>
        </label>

        <div class="flex flex-wrap gap-2 mb-2">
          <%= for theme <- @selected_themes do %>
            <span class="badge badge-primary gap-1">
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
          <% end %>
        </div>

        <form
          id="theme-form"
          phx-change="search_themes"
          phx-submit="create_theme_from_search"
        >
          <input
            type="text"
            name="theme_search"
            value={@theme_query}
            phx-debounce="200"
            autocomplete="off"
            placeholder="Search or create a theme…"
            class="input input-bordered w-full"
          />

          <ul class="menu bg-base-100 rounded-box mt-2">
            <%= for theme <- @theme_results do %>
              <li>
                <button type="button" phx-click="add_theme" phx-value-id={theme.id}>{theme.name}</button>
              </li>
            <% end %>

            <%= if @can_create do %>
              <li>
                <button type="button" phx-click="create_theme" phx-value-name={@theme_query}>
                  Create theme "{String.trim(@theme_query)}"
                </button>
              </li>
            <% end %>
          </ul>
        </form>
      </div>

      <.form for={@form} id="endgame-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:fen]} type="text" label="Fen" disabled={@live_action == :edit} />
        <.input field={@form[:color]} type="text" label="Color" disabled />
        <.input field={@form[:rating]} type="number" label="Rating" />
        <.input field={@form[:message]} type="textarea" label="Message" />
        <.input field={@form[:notes]} type="textarea" label="Notes" />
        <.input
          field={@form[:result]}
          type="select"
          options={[
            {"Win", :win},
            {"Draw", :draw},
            {"Loss", :loss}
          ]}
          label="Result"
        />
        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save Endgame</.button>
          <.button navigate={return_path(@return_to, @endgame)}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok,
     socket
     |> assign(:return_to, return_to(params["return_to"]))
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp return_to("show"), do: "show"
  defp return_to(_), do: "index"

  defp apply_action(socket, :edit, %{"id" => id}) do
    endgame = Endgames.get_endgame!(id) |> Repo.preload(:themes)

    socket
    |> assign(:page_title, "Edit Endgame")
    |> assign(:endgame, endgame)
    |> assign(:selected_themes, endgame.themes)
    |> assign(:theme_query, "")
    |> assign(:theme_results, [])
    |> assign(:can_create, false)
    |> assign(:form, to_form(Endgames.change_endgame(endgame)))
  end

  defp apply_action(socket, :new, _params) do
    endgame = %Endgame{}

    socket
    |> assign(:page_title, "New Endgame")
    |> assign(:endgame, endgame)
    |> assign(:selected_themes, [])
    |> assign(:theme_query, "")
    |> assign(:theme_results, [])
    |> assign(:can_create, false)
    |> assign(:form, to_form(Endgames.change_endgame(endgame)))
  end

  @impl true
  def handle_event("search_themes", %{"theme_search" => query}, socket) do
    {:noreply, assign_search(socket, query)}
  end

  def handle_event("add_theme", %{"id" => id}, socket) do
    theme = Themes.get_theme!(id)
    {:noreply, socket |> add_selected_theme(theme) |> clear_search()}
  end

  def handle_event("create_theme", %{"name" => name}, socket) do
    {:noreply, create_theme(socket, name)}
  end

  def handle_event("create_theme_from_search", %{"theme_search" => name}, socket) do
    {:noreply, create_theme(socket, name)}
  end

  def handle_event("remove_theme", %{"id" => id}, socket) do
    selected = Enum.reject(socket.assigns.selected_themes, &(Integer.to_string(&1.id) == id))
    {:noreply, assign(socket, :selected_themes, selected)}
  end

  def handle_event("validate", %{"endgame" => endgame_params}, socket) do
    fen = endgame_params["fen"] || socket.assigns.endgame.fen
    color = FEN.color_from_fen(fen)

    changeset =
      socket.assigns.endgame
      |> Endgames.change_endgame(endgame_params)
      |> Ecto.Changeset.put_change(:color, color)

    {:noreply, assign(socket, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"endgame" => endgame_params}, socket) do
    save_endgame(socket, socket.assigns.live_action, endgame_params)
  end

  defp save_endgame(socket, :edit, endgame_params) do
    case Endgames.update_endgame(
           socket.assigns.endgame,
           endgame_params,
           socket.assigns.selected_themes
         ) do
      {:ok, endgame} ->
        {:noreply,
         socket
         |> put_flash(:info, "Endgame updated successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, endgame))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp save_endgame(socket, :new, endgame_params) do
    color = FEN.color_from_fen(endgame_params["fen"])
    params = Map.put(endgame_params, "color", color)

    case Endgames.create_endgame(params, socket.assigns.selected_themes) do
      {:ok, endgame} ->
        {:noreply,
         socket
         |> put_flash(:info, "Endgame created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, endgame))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp assign_search(socket, query) do
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

  defp create_theme(socket, name) do
    if String.trim(name) == "" do
      socket
    else
      case Themes.get_or_create(name, "endgame") do
        {:ok, theme} -> socket |> add_selected_theme(theme) |> clear_search()
        {:error, _reason} -> put_flash(socket, :error, "Could not create that theme.")
      end
    end
  end

  defp clear_search(socket) do
    socket
    |> assign(:theme_query, "")
    |> assign(:theme_results, [])
    |> assign(:can_create, false)
  end

  defp add_selected_theme(socket, theme) do
    if Enum.any?(socket.assigns.selected_themes, &(&1.id == theme.id)) do
      socket
    else
      assign(socket, :selected_themes, socket.assigns.selected_themes ++ [theme])
    end
  end

  defp return_path("index", _endgame), do: ~p"/admin/endgames"
  defp return_path("show", endgame), do: ~p"/admin/endgames/#{endgame}"
end
