defmodule ChesstrainerWeb.RatingComponents do
  @moduledoc """
  Visual guide to a user's rating.

  Places the rating on a fixed scale and shades the range the true rating is
  likely to sit in, derived from the rating deviation (rating ± 2×RD). The
  band is intentionally wide for a new or returning player: it narrows as
  rated attempts accumulate, which is exactly what the deviation measures.
  """

  use Phoenix.Component

  # Glicko ratings are conventionally shown on a 0–3000 scale. The default
  # rating is 1500 and the deviation is capped at 350, so 500–3000 keeps the
  # useful range readable without letting a stray value push the marker off.
  @scale_min 500
  @scale_max 3000

  @doc """
  Renders the rating gauge with its confidence band and explainer.
  """
  attr :rating, :float, required: true
  attr :deviation, :float, default: nil
  attr :id, :string, default: "rating-guide"

  def rating_guide(assigns) do
    low = assigns.deviation && assigns.rating - 2 * assigns.deviation
    high = assigns.deviation && assigns.rating + 2 * assigns.deviation

    assigns =
      assign(assigns,
        low: low,
        high: high,
        scale_min: @scale_min,
        scale_max: @scale_max,
        marker_pct: pct(assigns.rating),
        band_left: low && pct(low),
        band_width: low && pct(high) - pct(low),
        label: aria_label(assigns.rating, low, high)
      )

    ~H"""
    <section id={@id} class="rounded-lg bg-canvas-raised p-3 text-sm">
      <div class="flex flex-wrap items-baseline justify-between gap-x-3 gap-y-1">
        <p class="font-semibold">Your rating: {round(@rating)}</p>
        <p :if={@low} id={"#{@id}-range"} class="text-xs text-muted">
          likely {round(@low)}–{round(@high)}
        </p>
      </div>

      <div class="relative mt-3 h-2 rounded-full bg-base-300" role="img" aria-label={@label}>
        <div
          :if={@low}
          class="absolute inset-y-0 rounded-full bg-primary/30"
          style={"left: #{@band_left}%; width: #{@band_width}%"}
        >
        </div>
        <div
          class="absolute -top-1 h-4 w-0.5 -translate-x-1/2 rounded-full bg-primary"
          style={"left: #{@marker_pct}%"}
        >
        </div>
      </div>

      <div class="mt-1 flex justify-between text-[10px] text-muted">
        <span>{@scale_min}</span>
        <span>{@scale_max}</span>
      </div>

      <p class="mt-2 text-xs text-muted">
        Your rating estimates how well you solve endgames. It moves after each
        rated attempt — solving a harder puzzle gains more, and replaying the
        same puzzle within a week does not count. The shaded band is the range
        your true rating is likely to sit in (±2 rating deviations); it narrows
        as you play.
      </p>
    </section>
    """
  end

  # Position on the gauge as a percentage, clamped to the drawn scale.
  defp pct(value) do
    clamped = value |> max(@scale_min) |> min(@scale_max)
    Float.round((clamped - @scale_min) / (@scale_max - @scale_min) * 100, 1)
  end

  defp aria_label(rating, nil, nil) do
    "Rating #{round(rating)} on a #{@scale_min} to #{@scale_max} scale"
  end

  defp aria_label(rating, low, high) do
    "Rating #{round(rating)}, likely between #{round(low)} and #{round(high)}, " <>
      "on a #{@scale_min} to #{@scale_max} scale"
  end
end
