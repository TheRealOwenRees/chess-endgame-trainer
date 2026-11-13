defmodule ChesstrainerWeb.EndgameLive.Import do
  @moduledoc """
  Bulk FEN importer for the admin endgame section.

  Pasted FENs are validated and probed against the local Syzygy tablebase only;
  the remote (Lichess) fallback is deliberately not used here.
  """

  use ChesstrainerWeb, :live_view

  require Logger

  alias Chesstrainer.Endgames.BulkImport
  alias Chesstrainer.Endgames.Tablebase.Local

  import ChesstrainerWeb.ThemePicker

  @default_rating 1500

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} wide>
      <Layouts.admin_nav current_scope={@current_scope} />

      <.header>
        Import endgames
        <:subtitle>
          Paste one FEN per line. Results are read from the local Syzygy tablebase,
          so positions must have five pieces or fewer.
        </:subtitle>
        <:actions>
          <.button navigate={~p"/admin/endgames"}>
            <.icon name="hero-arrow-left" /> All endgames
          </.button>
        </:actions>
      </.header>

      <p
        id="tablebase-status"
        class={[
          "mb-6 rounded-md border px-4 py-3 text-sm",
          match?({:ok, _}, @tablebase_status) && "border-success/30 bg-success/10 text-success-text",
          match?({:error, _}, @tablebase_status) &&
            "border-warning/30 bg-warning/10 text-warning-text"
        ]}
      >
        {elem(@tablebase_status, 1)}
      </p>

      <form id="endgame-import-form" phx-submit="lookup" class="space-y-4">
        <.input
          id="import-fens"
          name="fens"
          type="textarea"
          label="FENs"
          value={@fen_text}
          rows="10"
          class="font-mono"
          placeholder="8/8/3k4/8/8/3K1R2/8/8 w - - 0 1"
          autocomplete="off"
        />

        <div class="sm:w-56">
          <.input
            id="import-rating"
            name="rating"
            type="number"
            label="Rating for all imported endgames"
            value={@rating}
            min="1"
          />
        </div>

        <.button type="submit" variant="primary" phx-disable-with="Looking up…">
          Look up results
        </.button>
      </form>

      <.theme_picker
        selected_themes={@selected_themes}
        theme_query={@theme_query}
        theme_results={@theme_results}
        can_create={@can_create}
      />

      <section :if={@entries != nil} id="import-preview" class="mt-10">
        <div class="mb-4 flex flex-wrap items-center justify-between gap-3">
          <div class="text-sm text-base-content/70">
            {summary(@entries)}
          </div>

          <div class="flex gap-2">
            <.button type="button" phx-click="toggle_all" phx-value-selected="true">
              Select ready
            </.button>
            <.button type="button" phx-click="toggle_all" phx-value-selected="false">
              Clear
            </.button>
          </div>
        </div>

        <p
          :if={@too_many?}
          class="mb-4 rounded-md border border-warning/30 bg-warning/10 px-4 py-3 text-sm text-warning-text"
        >
          Only the first {BulkImport.max_fens()} FENs were considered.
        </p>

        <table class={table_class()}>
          <thead>
            <tr>
              <th class="w-10"><span class="sr-only">Include</span></th>
              <th class="w-12">Line</th>
              <th>FEN</th>
              <th>Key</th>
              <th>Color</th>
              <th>Result</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={entry <- @entries} id={"import-row-#{entry.line}"}>
              <td>
                <input
                  type="checkbox"
                  id={"import-include-#{entry.line}"}
                  checked={entry.selected}
                  disabled={entry.status != :ready}
                  phx-click="toggle_entry"
                  phx-value-line={entry.line}
                />
              </td>
              <td>{entry.line}</td>
              <td class="break-all font-mono text-xs">{entry.fen}</td>
              <td>{entry.key || "—"}</td>
              <td>{entry.color || "—"}</td>
              <td>{entry.result || "—"}</td>
              <td>
                <.badge color={status_color(entry.status)}>{status_label(entry.status)}</.badge>
                <span :if={entry.reason} class="mt-1 block text-xs text-base-content/60">
                  {entry.reason}
                </span>
              </td>
            </tr>
          </tbody>
        </table>

        <footer class="mt-6 flex items-center gap-3">
          <.button
            type="button"
            variant="primary"
            phx-click="import"
            disabled={selected_count(@entries) == 0}
            phx-disable-with="Importing…"
          >
            Import {selected_count(@entries)} endgame(s)
          </.button>

          <span class="text-sm text-base-content/70">
            {selected_count(@entries)} of {count(@entries, :ready)} ready line(s) selected.
          </span>
        </footer>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Import endgames")
     |> assign(:tablebase_status, tablebase_status())
     |> assign(:fen_text, "")
     |> assign(:rating, @default_rating)
     |> assign(:entries, nil)
     |> assign(:too_many?, false)
     |> assign(:selected_themes, [])
     |> assign(:theme_query, "")
     |> assign(:theme_results, [])
     |> assign(:can_create, false)}
  end

  @impl true
  def handle_event("search_themes", %{"theme_search" => query}, socket) do
    {:noreply, assign_search(socket, query)}
  end

  def handle_event("add_theme", %{"id" => id}, socket) do
    theme = Chesstrainer.Themes.get_theme!(id)
    {:noreply, socket |> add_selected_theme(theme) |> clear_search()}
  end

  def handle_event("create_theme", %{"name" => name}, socket) do
    {:noreply, create_theme(socket, name)}
  end

  def handle_event("remove_theme", %{"id" => id}, socket) do
    selected = Enum.reject(socket.assigns.selected_themes, &(Integer.to_string(&1.id) == id))
    {:noreply, assign(socket, :selected_themes, selected)}
  end

  def handle_event("lookup", %{"fens" => fens} = params, socket) do
    rating = parse_rating(params["rating"])

    socket =
      assign(socket,
        fen_text: fens,
        rating: rating,
        entries: nil,
        too_many?: false
      )

    if String.trim(fens) == "" do
      {:noreply, put_flash(socket, :error, "Paste at least one FEN.")}
    else
      {:noreply, start_async(socket, :lookup, fn -> BulkImport.preview(fens) end)}
    end
  end

  def handle_event("toggle_entry", %{"line" => line}, socket) do
    line = String.to_integer(line)

    entries =
      Enum.map(socket.assigns.entries, fn entry ->
        if entry.line == line, do: %{entry | selected: not entry.selected}, else: entry
      end)

    {:noreply, assign(socket, :entries, entries)}
  end

  def handle_event("toggle_all", %{"selected" => selected}, socket) do
    selected? = selected == "true"

    entries =
      Enum.map(socket.assigns.entries, fn entry ->
        if entry.status == :ready, do: %{entry | selected: selected?}, else: entry
      end)

    {:noreply, assign(socket, :entries, entries)}
  end

  def handle_event("import", _params, socket) do
    entries =
      Enum.filter(socket.assigns.entries || [], &(&1.status == :ready and &1.selected))

    if entries == [] do
      {:noreply, put_flash(socket, :error, "Select at least one ready endgame to import.")}
    else
      %{imported: imported, skipped: skipped} =
        BulkImport.commit(entries, socket.assigns.selected_themes, socket.assigns.rating)

      message =
        "Imported #{imported} endgame(s)." <>
          if(skipped > 0, do: " #{skipped} skipped.", else: "")

      {:noreply,
       socket
       |> put_flash(:info, message)
       |> push_navigate(to: ~p"/admin/endgames")}
    end
  end

  @impl true
  def handle_async(:lookup, {:ok, %{entries: entries, too_many?: too_many?}}, socket) do
    entries = Enum.map(entries, &Map.put(&1, :selected, &1.status == :ready))

    {:noreply, assign(socket, entries: entries, too_many?: too_many?)}
  end

  def handle_async(:lookup, {:exit, reason}, socket) do
    Logger.error("bulk_import.lookup_failed", reason: inspect(reason))

    {:noreply,
     put_flash(
       socket,
       :error,
       "The lookup failed. Try again; if it keeps happening, check the server log."
     )}
  end

  defp tablebase_status do
    case Local.check() do
      {:ok, 0} ->
        {:error,
         "The local Syzygy tablebase directory contains no files, so imports are disabled."}

      {:ok, largest} ->
        {:ok, "Local Syzygy tablebase ready (up to #{largest} pieces)."}

      {:error, :not_configured} ->
        {:error, "Local tablebase is not configured. Set TABLEBASE_PATH to enable imports."}

      {:error, reason} ->
        Logger.warning("bulk_import.tablebase_unavailable", reason: inspect(reason))
        {:error, "The local tablebase failed to load. Check TABLEBASE_PATH and the server log."}
    end
  end

  defp parse_rating(rating) when is_integer(rating) and rating > 0, do: rating

  defp parse_rating(rating) when is_binary(rating) do
    case Integer.parse(String.trim(rating)) do
      {value, ""} when value > 0 -> value
      _ -> @default_rating
    end
  end

  defp parse_rating(_rating), do: @default_rating

  defp count(entries, status), do: Enum.count(entries, &(&1.status == status))

  defp summary(entries) do
    "#{length(entries)} line(s): " <>
      "#{count(entries, :ready)} ready, " <>
      "#{count(entries, :duplicate)} duplicate(s), " <>
      "#{count(entries, :invalid_fen)} invalid, " <>
      "#{count(entries, :too_many_pieces)} too many pieces, " <>
      "#{count(entries, :terminal)} terminal, " <>
      "#{count(entries, :illegal)} illegal, " <>
      "#{count(entries, :unsupported)} unsupported."
  end

  defp selected_count(entries) do
    Enum.count(entries, &(&1.status == :ready and &1.selected))
  end

  defp status_label(:ready), do: "Ready"
  defp status_label(:duplicate), do: "Duplicate"
  defp status_label(:invalid_fen), do: "Invalid FEN"
  defp status_label(:too_many_pieces), do: "Too many pieces"
  defp status_label(:illegal), do: "Illegal"
  defp status_label(:terminal), do: "Terminal"
  defp status_label(:unsupported), do: "Unsupported"

  defp status_color(:ready), do: "primary"
  defp status_color(_status), do: "warning"
end
