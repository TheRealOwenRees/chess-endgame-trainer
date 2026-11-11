defmodule ChesstrainerWeb.Admin.ThemeLive.Form do
  use ChesstrainerWeb, :live_view

  alias Chesstrainer.Accounts.Policy
  alias Chesstrainer.Themes
  alias Chesstrainer.Themes.Theme

  @category_options [
    {"Endgame", "endgame"},
    {"Opening", "opening"},
    {"Tactic", "tactic"}
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        {@page_title}
        <:subtitle>
          Themes group endgames for filtering. Names must be unique within a category,
          ignoring case.
        </:subtitle>
      </.header>

      <.form for={@form} id="theme-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:name]} type="text" label="Name" autocomplete="off" required />
        <.input
          field={@form[:category]}
          type="select"
          label="Category"
          options={@category_options}
        />

        <footer>
          <.button phx-disable-with="Saving..." variant="primary">Save theme</.button>
          <.button navigate={~p"/admin/themes"}>Cancel</.button>
        </footer>
      </.form>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    theme = %Theme{}

    socket
    |> assign(:page_title, "New theme")
    |> assign(:theme, theme)
    |> assign(:category_options, @category_options)
    |> assign(:form, to_form(Themes.change_theme(theme)))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    theme = Themes.get_theme!(id)

    socket
    |> assign(:page_title, "Edit theme")
    |> assign(:theme, theme)
    |> assign(:category_options, @category_options)
    |> assign(:form, to_form(Themes.change_theme(theme)))
  end

  @impl true
  def handle_event("validate", %{"theme" => theme_params}, socket) do
    changeset =
      socket.assigns.theme
      |> Themes.change_theme(theme_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :form, to_form(changeset, action: :validate))}
  end

  def handle_event("save", %{"theme" => theme_params}, socket) do
    if Policy.can?(socket.assigns.current_scope, :manage_themes) do
      save_theme(socket, socket.assigns.live_action, theme_params)
    else
      {:noreply, put_flash(socket, :error, "You are not authorized to manage themes.")}
    end
  end

  defp save_theme(socket, :new, theme_params) do
    case Themes.create_theme(theme_params) do
      {:ok, _theme} ->
        {:noreply,
         socket
         |> put_flash(:info, "Theme created successfully.")
         |> push_navigate(to: ~p"/admin/themes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end

  defp save_theme(socket, :edit, theme_params) do
    case Themes.update_theme(socket.assigns.theme, theme_params) do
      {:ok, _theme} ->
        {:noreply,
         socket
         |> put_flash(:info, "Theme updated successfully.")
         |> push_navigate(to: ~p"/admin/themes")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :form, to_form(changeset, action: :insert))}
    end
  end
end
