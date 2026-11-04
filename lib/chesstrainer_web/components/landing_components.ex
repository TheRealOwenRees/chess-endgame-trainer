defmodule ChesstrainerWeb.LandingComponents do
  @moduledoc """
  Presentational primitives for the marketing landing page.

  Kept separate from `ChesstrainerWeb.CoreComponents`: the landing page uses a
  distinct pill-button language, while CoreComponents provides the compact
  admin and auth UI.
  """
  use Phoenix.Component

  @button_variants %{
    nav: "nav-cta",
    primary: "primary-button",
    light: "light-button"
  }

  @doc """
  Renders a landing-page pill button.

  Renders a link when given `href`, `navigate`, or `patch`; otherwise a button.

  ## Examples

      <.pill_button variant={:nav} href="/#trainer">Start training</.pill_button>
      <.pill_button variant={:primary} phx-click="go">Go</.pill_button>
  """
  attr :rest, :global, include: ~w(href navigate patch method type disabled)
  attr :variant, :atom, values: [:nav, :primary, :light], default: :nav
  attr :class, :any, default: nil
  slot :inner_block, required: true

  def pill_button(%{rest: rest} = assigns) do
    assigns =
      assign(assigns, :class, [Map.fetch!(@button_variants, assigns.variant), assigns.class])

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc "The arrow used by landing-page CTAs."
  def icon_arrow(assigns) do
    ~H"""
    <svg aria-hidden="true" viewBox="0 0 20 20" fill="none">
      <path
        d="M4 10h11m-4.5-4.5L15 10l-4.5 4.5"
        stroke="currentColor"
        stroke-width="1.7"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    """
  end
end
