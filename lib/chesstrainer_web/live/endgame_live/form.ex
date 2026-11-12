defmodule ChesstrainerWeb.EndgameLive.Form do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Repo
  alias Chesstrainer.Themes
  alias Chesstrainer.FEN
  alias Chesstrainer.Endgames
  alias Chesstrainer.Endgames.Endgame

  import ChesstrainerWeb.Board.BoardComponent
  import ChesstrainerWeb.ThemePicker

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        {@page_title}
        <:subtitle>Use this form to manage endgame records in your database.</:subtitle>
      </.header>

      <.theme_picker
        selected_themes={@selected_themes}
        theme_query={@theme_query}
        theme_results={@theme_results}
        can_create={@can_create}
      />

      <.form for={@form} id="endgame-form" phx-change="validate" phx-submit="save">
        <div class="flex flex-col gap-6 sm:flex-row sm:items-start">
          <div class="min-w-0 flex-1">
            <.input field={@form[:fen]} type="text" label="Fen" disabled={@live_action == :edit} />
            <.input field={@form[:color]} type="text" label="Color" disabled />
            <.input
              field={@form[:rating]}
              type="number"
              value={rating_display(@form[:rating])}
              label="Rating"
            />

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
          </div>

          <div :if={@preview_game} id="endgame-preview-board" class="sm:w-64 sm:shrink-0">
            <span class="mb-1 block text-sm font-medium text-base-content">Current position</span>
            <.board game={@preview_game} class="w-full mt-2" interactive={false} />
          </div>
        </div>

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
    |> assign(:preview_game, preview_game(endgame.fen))
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
    |> assign(:preview_game, preview_game(endgame.fen))
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

    {:noreply,
     assign(socket,
       form: to_form(changeset, action: :validate),
       preview_game: preview_game(fen)
     )}
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

  # Ratings are stored as floats (Glicko); the admin form presents them as whole numbers.
  defp rating_display(%Phoenix.HTML.FormField{value: value}) when is_float(value),
    do: round(value)

  defp rating_display(%Phoenix.HTML.FormField{value: value}), do: value

  # Shows the position as the admin types a FEN; hidden while the FEN is invalid or blank.
  # Parses directly rather than through Game.game_from_fen/2 so keystrokes never probe a tablebase.
  defp preview_game(fen) when is_binary(fen) do
    {:ok, game} = Chex.Parser.FEN.parse(fen)
    %{board: game.board, orientation: game.active_color, move_from_square: nil}
  rescue
    MatchError -> nil
  end

  defp preview_game(_fen), do: nil

  defp return_path("index", _endgame), do: ~p"/admin/endgames"
  defp return_path("show", endgame), do: ~p"/admin/endgames/#{endgame.id}"
end
