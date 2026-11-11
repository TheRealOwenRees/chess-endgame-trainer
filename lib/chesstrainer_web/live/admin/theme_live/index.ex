defmodule ChesstrainerWeb.Admin.ThemeLive.Index do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Themes

  @category_options [
    {"All categories", ""},
    {"Endgame", "endgame"},
    {"Opening", "opening"},
    {"Tactic", "tactic"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        Themes
        <:subtitle>
          Themes group endgames for filtering and puzzle selection. Deleting a theme detaches
          it from every endgame and leaves the endgames intact.
        </:subtitle>
        <:actions>
          <.button variant="primary" navigate={~p"/admin/themes/new"}>
            <.icon name="hero-plus" /> New theme
          </.button>
        </:actions>
      </.header>

      <.form
        for={@filter_form}
        id="theme-admin-filter-form"
        phx-change="filter"
        class="mb-6 flex flex-col gap-3 sm:flex-row sm:items-end"
      >
        <div class="flex-1 [&>div]:mb-0">
          <.input
            field={@filter_form[:search]}
            type="text"
            label="Search by name"
            autocomplete="off"
            phx-debounce="200"
            placeholder="Theme name…"
          />
        </div>
        <div class="[&>div]:mb-0 sm:w-56">
          <.input
            field={@filter_form[:category]}
            type="select"
            label="Category"
            options={@category_options}
          />
        </div>
      </.form>

      <p :if={@themes == []} class="text-base-content/70">
        <%= if @has_filters do %>
          No themes match these filters.
        <% else %>
          No themes yet. Themes power endgame filtering and puzzle selection, so start by
          creating one and attaching it to an endgame.
        <% end %>
      </p>

      <table :if={@themes != []} class={table_class()}>
        <thead>
          <tr>
            <th>Name</th>
            <th>Category</th>
            <th>Used by</th>
            <th><span class="sr-only">Actions</span></th>
          </tr>
        </thead>
        <tbody id="themes">
          <tr :for={{theme, usage_count} <- @themes} id={"theme-#{theme.id}"}>
            <td>{theme.name}</td>
            <td>{theme.category}</td>
            <td>
              <span id={"theme-usage-#{theme.id}"}>{usage_label(usage_count)}</span>
            </td>
            <td class="w-0 font-semibold">
              <div class="flex gap-4">
                <.link navigate={~p"/admin/themes/#{theme.id}/edit"}>Edit</.link>
                <.link
                  phx-click="delete"
                  phx-value-id={theme.id}
                  data-confirm={
                    "Delete #{theme.name}? Used by #{usage_label(usage_count)}. " <>
                      "The endgames will be kept and simply detached."
                  }
                >
                  Delete
                </.link>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Themes")
     |> assign(:search, "")
     |> assign(:category, "")
     |> assign(:has_filters, false)
     |> assign(:category_options, @category_options)
     |> assign(:filter_form, to_form(%{"search" => "", "category" => ""}))
     |> load_themes()}
  end

  @impl true
  def handle_event("filter", params, socket) do
    search = Map.get(params, "search", socket.assigns.search)
    category = Map.get(params, "category", socket.assigns.category)

    {:noreply,
     socket
     |> assign(:search, search)
     |> assign(:category, category)
     |> assign(:has_filters, String.trim(search) != "" or category != "")
     |> load_themes()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    if Policy.can?(socket.assigns.current_scope, :manage_themes) do
      theme = Themes.get_theme!(id)
      {:ok, _theme} = Themes.delete_theme(theme)

      socket =
        socket
        |> put_flash(:info, "Theme deleted. Attached endgames were kept.")
        |> load_themes()

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "You are not authorized to manage themes.")}
    end
  end

  defp load_themes(socket) do
    themes =
      Themes.list_themes_for_admin(
        search: socket.assigns.search,
        category: socket.assigns.category
      )

    assign(socket, :themes, themes)
  end

  defp usage_label(1), do: "1 endgame"
  defp usage_label(count), do: "#{count} endgames"
end
