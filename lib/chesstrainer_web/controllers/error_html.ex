defmodule ChesstrainerWeb.ErrorHTML do
  @moduledoc """
  This module is invoked by your endpoint in case of errors on HTML requests.

  See config/config.exs.

  Error templates are rendered outside the root layout, so `404.html.heex` and
  `500.html.heex` each render a complete document. They share the body markup
  through `error_page/1`, which the catch-all 404 route also uses.
  """
  use ChesstrainerWeb, :html

  alias Chesstrainer.Accounts.Scope

  embed_templates "error_html/*"

  @doc """
  The body shared by the standalone error pages and the catch-all 404 route.

  Rendered inside the root layout by `PageController.not_found/2`, and directly
  by the `ErrorHTML` templates, which bypass layouts.
  """
  attr :status, :integer, required: true
  attr :title, :string, required: true
  attr :message, :string, required: true
  attr :hint, :string, default: nil
  attr :current_scope, :map, default: nil

  def error_page(assigns) do
    ~H"""
    <main class="error-page">
      <span class="error-code">{@status}</span>
      <h1>{@title}</h1>
      <p>{@message}</p>
      <p :if={@hint} class="error-hint">{@hint}</p>

      <div class="error-actions">
        <.pill_button variant={:primary} href={~p"/"}>
          Back to home <.icon_arrow />
        </.pill_button>
        <.pill_button :if={Scope.premium?(@current_scope)} variant={:light} href={~p"/endgames"}>
          Browse puzzles
        </.pill_button>
      </div>
    </main>
    """
  end

  # Statuses without a template keep the previous plain-text behaviour.
  def render(template, _assigns) do
    Phoenix.Controller.status_message_from_template(template)
  end
end
