defmodule ChesstrainerWeb.RatingComponentsTest do
  use ChesstrainerWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias ChesstrainerWeb.RatingComponents

  test "shows the rating and the ±2 deviation confidence band" do
    html = render_component(&RatingComponents.rating_guide/1, %{rating: 1500.0, deviation: 100.0})

    assert html =~ "Your rating: 1500"
    assert html =~ "likely 1300–1700"
    assert html =~ "left: 40.0%"
    assert html =~ "left: 32.0%"
    assert html =~ "width: 16.0%"
    assert html =~ "Rating 1500, likely between 1300 and 1700"
  end

  test "omits the band when the deviation is unknown" do
    html = render_component(&RatingComponents.rating_guide/1, %{rating: 1500.0, deviation: nil})

    assert html =~ "Your rating: 1500"
    refute html =~ ~s(id="rating-guide-range")
    refute html =~ "bg-primary/30"
    assert html =~ "Rating 1500 on a 500 to 3000 scale"
  end

  test "clamps the marker to the drawn scale" do
    low = render_component(&RatingComponents.rating_guide/1, %{rating: 100.0, deviation: nil})
    high = render_component(&RatingComponents.rating_guide/1, %{rating: 4000.0, deviation: nil})

    assert low =~ "left: 0.0%"
    assert high =~ "left: 100.0%"
  end

  test "accepts a custom id for the gauge" do
    html =
      render_component(&RatingComponents.rating_guide/1, %{
        rating: 1500.0,
        deviation: 100.0,
        id: "session-rating"
      })

    assert html =~ ~s(id="session-rating")
    assert html =~ ~s(id="session-rating-range")
  end
end
