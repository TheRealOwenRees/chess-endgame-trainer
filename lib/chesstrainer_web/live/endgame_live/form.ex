defmodule ChesstrainerWeb.EndgameLive.Form do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Repo
  alias Chesstrainer.Tags
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

      <.form for={@form} id="endgame-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:fen]} type="text" label="Fen" disabled={@live_action == :edit} />
        <.input field={@form[:color]} type="text" label="Color" disabled />
        <.input field={@form[:key]} type="text" label="Key" />
        <.input field={@form[:rating]} type="number" label="Rating" />

        <!-- ✅ TAG SELECTOR -->
        <div class="field">
          <label>Tags</label>

          <!-- Search box -->
          <input
            type="text"
            name="tag_search"
            value={@tag_query}
            phx-change="search_tags"
            autocomplete="off"
          />

          <!-- Search results -->
          <ul class="tag-results">
            <%= for tag <- @tag_results do %>
              <li phx-click="add_tag" phx-value-id={tag.id}>
                {tag.name}
              </li>
            <% end %>

            <%= if @tag_query != "" and @tag_results == [] do %>
              <li phx-click="create_tag" phx-value-name={@tag_query}>
                Create tag "{@tag_query}"
              </li>
            <% end %>
          </ul>

          <!-- Selected tags -->
          <div class="selected-tags">
            <%= for tag <- @endgame.tags do %>
              <span class="tag">
                {tag.name}
                <button type="button" phx-click="remove_tag" phx-value-id={tag.id}>×</button>
              </span>
            <% end %>
          </div>
        </div>

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
    endgame = Endgames.get_endgame!(id)

    socket
    |> assign(:page_title, "Edit Endgame")
    |> assign(:endgame, endgame)
    |> assign(:tag_query, "")
    |> assign(:tag_results, [])
    |> assign(:endgame, Repo.preload(endgame, :tags))
    |> assign(:form, to_form(Endgames.change_endgame(endgame)))
  end

  defp apply_action(socket, :new, _params) do
    endgame = %Endgame{}

    socket
    |> assign(:page_title, "New Endgame")
    |> assign(:endgame, endgame)
    |> assign(:tag_query, "")
    |> assign(:tag_results, [])
    |> assign(:endgame, Repo.preload(endgame, :tags))
    |> assign(:form, to_form(Endgames.change_endgame(endgame)))
  end

  @impl true
  def handle_event("search_tags", %{"tag_search" => query}, socket) do
    tags = Tags.search(query, "endgame")

    {:noreply,
     socket
     |> assign(:tag_query, query)
     |> assign(:tag_results, tags)}
  end

  def handle_event("add_tag", %{"id" => id}, socket) do
    tag = Tags.get_tag!(id)
    {:ok, endgame} = Endgames.add_tag(socket.assigns.endgame, tag)

    {:noreply,
     socket
     |> assign(:endgame, Repo.preload(endgame, :tags))
     |> assign(:tag_query, "")
     |> assign(:tag_results, [])}
  end

  def handle_event("create_tag", %{"name" => name}, socket) do
    {:ok, tag} = Tags.get_or_create(name, "endgame")
    {:ok, endgame} = Endgames.add_tag(socket.assigns.endgame, tag)

    {:noreply,
     socket
     |> assign(:endgame, Repo.preload(endgame, :tags))
     |> assign(:tag_query, "")
     |> assign(:tag_results, [])}
  end

  def handle_event("remove_tag", %{"id" => id}, socket) do
    tag = Tags.get_tag!(id)
    {:ok, endgame} = Endgames.remove_tag(socket.assigns.endgame, tag)

    {:noreply,
     socket
     |> assign(:endgame, Repo.preload(endgame, :tags))}
  end

  def handle_event("validate", %{"endgame" => endgame_params}, socket) do
    # Compute color from the incoming FEN
    color = FEN.color_from_fen(endgame_params["fen"])

    # Update the struct
    endgame = %{socket.assigns.endgame | color: color}

    # Build the changeset *from the updated struct*
    changeset =
      endgame
      |> Endgames.change_endgame()
      |> Ecto.Changeset.put_change(:color, color)

    {:noreply, assign(socket, endgame: endgame, form: to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"endgame" => endgame_params}, socket) do
    save_endgame(socket, socket.assigns.live_action, endgame_params)
  end

  defp save_endgame(socket, :edit, endgame_params) do
    case Endgames.update_endgame(socket.assigns.endgame, endgame_params) do
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

    case Endgames.create_endgame(params) do
      {:ok, endgame} ->
        {:noreply,
         socket
         |> put_flash(:info, "Endgame created successfully")
         |> push_navigate(to: return_path(socket.assigns.return_to, endgame))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp return_path("index", _endgame), do: ~p"/admin/endgames"
  defp return_path("show", endgame), do: ~p"/admin/endgames/#{endgame}"
end
