defmodule ChesstrainerWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use ChesstrainerWeb, :html

  alias Chesstrainer.Accounts.Role

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :wide, :boolean,
    default: false,
    doc: "use a wide container instead of the default narrow column"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <main class="px-4 py-20 sm:px-6 lg:px-8">
      <div class={["mx-auto space-y-4", if(@wide, do: "max-w-7xl", else: "max-w-2xl")]}>
        {render_slot(@inner_block)}
      </div>
    </main>
    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Renders the application navbar.

  The marketing and account links are defined once in `nav_links/1` and rendered
  in both the desktop bar and the mobile menu. Edit that list to change what
  appears in either place.
  """
  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  def navbar(assigns) do
    assigns =
      assigns
      |> assign(:nav_links, nav_links(assigns.current_scope))
      |> assign(:start_href, start_href(assigns.current_scope))

    ~H"""
    <header>
      <nav class="nav-wrap" aria-label="Main navigation">
        <a class="brand" href="/" aria-label="Lucid Chess home">
          <span class="brand-mark">♞</span>
          <span>LUCID</span>
        </a>

        <div class="nav-right">
          <.colour_mode_toggle />

          <button
            class="menu-button"
            type="button"
            aria-expanded="false"
            aria-controls="nav-links"
            aria-label="Toggle menu"
          >
            <span></span>
            <span></span>
          </button>

          <div class="nav-links" id="nav-links">
            <%= for link <- @nav_links do %>
              <%= if link[:kind] == :text do %>
                <span class="nav-user">{link.label}</span>
              <% else %>
                <.link href={link.href} method={link[:method]}>{link.label}</.link>
              <% end %>
            <% end %>

            <.pill_button variant={:nav} href={@start_href}>
              Start training <.icon_arrow />
            </.pill_button>
          </div>
        </div>
      </nav>
    </header>
    """
  end

  defp nav_links(scope) do
    marketing =
      if premium?(scope) do
        [
          %{label: "Puzzle Search", href: "/endgames"}
        ]
      else
        []
      end

    admin =
      if admin?(scope) do
        [%{label: "Admin", href: ~p"/admin/endgames"}]
      else
        []
      end

    account =
      case scope do
        %{user: %{username: username}} ->
          [
            %{label: "Settings", href: ~p"/users/settings"},
            %{label: "Log out", href: ~p"/users/log-out", method: "delete"},
            %{label: username, kind: :text}
          ]

        _ ->
          [
            %{label: "Log in", href: ~p"/users/log-in"},
            %{label: "Register", href: ~p"/users/register"}
          ]
      end

    marketing ++ admin ++ account
  end

  defp admin?(%{user: %{role: role}}), do: Role.admin?(role)
  defp admin?(_scope), do: false

  defp premium?(scope), do: match?(%{user: %{plan: :premium}}, scope)

  # Signed-in users start a puzzle session; visitors browse the public list.
  defp start_href(%{user: %{}}), do: ~p"/train"
  defp start_href(_scope), do: ~p"/guest-train"

  @doc """
  Renders the site-wide footer.

  Rendered once from the root layout so it appears on every page, matching the
  navbar. Links to the landing-page anchors keep working from other pages
  because they point at `/` first.
  """
  def footer(assigns) do
    assigns = assign(assigns, :year, DateTime.utc_now().year)

    ~H"""
    <footer class="site-footer">
      <div class="footer-brand">
        <a class="brand" href="/" aria-label="Lucid Chess home">
          <span class="brand-mark">♞</span>
          <span>LUCID</span>
        </a>
        <p>Short, focused endgame training.</p>
      </div>

      <nav class="footer-links" aria-label="Footer">
        <a href="/privacy">Privacy Policy</a>
        <a href="/terms-conditions">Terms & Conditions</a>
      </nav>

      <small>© {@year} Lucid Chess</small>
    </footer>
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed right-4 top-4 z-50 flex w-80 max-w-80 flex-col gap-2 sm:w-96 sm:max-w-96"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @doc """
  Provides the system / light / dark colour-mode switch.

  The click handling and `aria-checked` syncing live in the script in
  `root.html.heex`, which runs before paint and also on pages without LiveView
  (the landing page uses the marketing bundle).
  """
  def colour_mode_toggle(assigns) do
    ~H"""
    <div
      class="relative flex flex-row items-center rounded-full border-2 border-base-300 bg-base-300"
      role="radiogroup"
      aria-label="Colour mode"
    >
      <div
        class="absolute w-1/3 h-full rounded-full border border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 [[data-theme-source=system]_&]:!left-0 transition-[left]"
        aria-hidden="true"
      >
      </div>

      <button
        type="button"
        class="flex p-2 cursor-pointer w-1/3 justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        data-phx-theme="system"
        role="radio"
        aria-checked="true"
        aria-label="System colour mode"
      >
        <.icon name="hero-computer-desktop-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        class="flex p-2 cursor-pointer w-1/3 justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        data-phx-theme="light"
        role="radio"
        aria-checked="false"
        aria-label="Light colour mode"
      >
        <.icon name="hero-sun-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>

      <button
        type="button"
        class="flex p-2 cursor-pointer w-1/3 justify-center rounded-full focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-primary"
        data-phx-theme="dark"
        role="radio"
        aria-checked="false"
        aria-label="Dark colour mode"
      >
        <.icon name="hero-moon-micro" class="size-4 opacity-75 hover:opacity-100" />
      </button>
    </div>
    """
  end
end
