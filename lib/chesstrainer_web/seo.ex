defmodule ChesstrainerWeb.SEO do
  @moduledoc """
  Absolute URLs and crawler metadata for controller-rendered pages.

  Search engines need absolute URLs, so these helpers read the endpoint's
  configured host rather than the request host (which is a proxy address).

  Canonical URLs deliberately drop the query string: campaign parameters such
  as `?utm_source=...` must not become canonical pages of their own.
  """

  alias Chesstrainer.Branding
  alias ChesstrainerWeb.Endpoint

  @og_image "/images/og.png"
  @logo "/apple-touch-icon.png"

  @doc "The request path as an absolute canonical URL, without any query string."
  def canonical_url(conn) do
    Phoenix.VerifiedRoutes.unverified_url(conn, conn.request_path)
  end

  @doc "Absolute URL of the social share image."
  def og_image_url, do: Endpoint.url() <> @og_image

  @doc """
  JSON-LD for the site, encoded as a string ready for a
  `<script type="application/ld+json">` block.
  """
  def json_ld(url) do
    %{
      "@context" => "https://schema.org",
      "@graph" => [
        %{
          "@type" => "WebSite",
          "name" => Branding.name(),
          "url" => url
        },
        %{
          "@type" => "Organization",
          "name" => Branding.name(),
          "url" => url,
          "logo" => Endpoint.url() <> @logo
        }
      ]
    }
    |> Jason.encode!()
  end
end
