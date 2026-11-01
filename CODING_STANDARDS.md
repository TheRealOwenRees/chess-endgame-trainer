# Coding Standards

How to write code in this repo. Read the section for the layer you're touching.

## Elixir

- Index lists with `Enum.at(list, i)`. Elixir lists don't implement `Access`, so `list[i]` fails.
- Bind the result of a block expression: `socket = if connected?(socket), do: assign(socket, :val, val)`. Rebinding inside the block doesn't escape it.
- One module per file — nested modules invite cyclic dependencies.
- Read struct fields directly (`my_struct.field`). Structs don't implement `Access`; for changesets use `Ecto.Changeset.get_field/2`.
- Convert user input with `String.to_existing_atom/1` or a fixed map of atoms — `String.to_atom/1` leaks atoms.
- Predicates end in `?`. Reserve the `is_` prefix for guards.
- Name OTP primitives in their child spec: `{DynamicSupervisor, name: Chesstrainer.MyDynamicSup}`, then `DynamicSupervisor.start_child(Chesstrainer.MyDynamicSup, spec)`.
- Enumerate concurrently with `Task.async_stream(collection, fun, timeout: :infinity)`.
- Date and time come from stdlib `Time`, `Date`, `DateTime`, `Calendar`. `date_time_parser` is the only parsing dep we allow; ask before adding another.
- HTTP requests use `Req` (already a dep). `:httpoison`, `:tesla` and `:httpc` are not used.

## Ecto

- Preload associations that templates touch, e.g. `message.user.email`.
- Every text column is `:string`, including `:text` ones: `field :name, :string`.
- `validate_number/2` has no `:allow_nil` — validations only run on a present change, so the option is redundant.
- Programmatic fields like `user_id` are set on the struct at insert time, never listed in `cast`.
- Generate migrations with `mix ecto.gen.migration name_using_underscores` so the timestamp and conventions are right.
- `priv/repo/seeds.exs` needs `import Ecto.Query`.

## Phoenix

- `scope` prefixes its routes' alias: `scope "/admin", ChesstrainerWeb.Admin` makes `live "/users", UserLive` resolve to `ChesstrainerWeb.Admin.UserLive`. Adding your own `alias` duplicates the prefix.
- `Phoenix.View` is not part of Phoenix any more.

## HEEx

- Templates are `~H` or `.html.heex`.
- Begin every LiveView template with `<Layouts.app flash={@flash} ...>`. `Layouts` is already aliased in `chesstrainer_web.ex`.
- `<.flash_group>` lives only in `layouts.ex`.
- A missing `current_scope` assign means the route sits in the wrong `live_session`. Move it there and pass `current_scope` through.
- Icons come from `core_components.ex`: `<.icon name="hero-x-mark" class="w-5 h-5"/>`.
- Multiple conditionals use `cond` or `case`.
- Literal `{`/`}` inside `<pre>` or `<code>`: annotate the parent tag with `phx-no-curly-interpolation`. Dynamic `<%= ... %>` still works inside it.
- Class attributes use list syntax, with `if` wrapped in parens:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100")
      ]}>Text</a>

- Generate collections with `<%= for item <- @collection do %>`.
- Comments use `<%!-- ... --%>`.
- Interpolate attributes and tag bodies with `{...}`. `<%= %>` is for block constructs in tag bodies.

## LiveView

- Navigate with `<.link navigate={href}>` and `<.link patch={href}>`; use `push_navigate` and `push_patch` in handlers.
- Name LiveViews `SomethingLive`. The `:browser` scope is already aliased to `ChesstrainerWeb`, so `live "/weather", WeatherLive` is enough.
- Reach for a LiveView before a LiveComponent; a LiveComponent earns its place when it needs isolated state or genuine reuse.

### Streams

- Assign collections through streams: append `stream(socket, :messages, [msg])`, reset `stream(socket, :messages, msgs, reset: true)`, prepend `at: -1`, remove `stream_delete(socket, :messages, msg)`.
- The parent element carries `phx-update="stream"` and a DOM id; each child is `:for={{id, msg} <- @streams.messages} id={id}`.
- Streams aren't enumerable. To filter, refetch the data and re-stream it with `reset: true`.
- Streams don't count or render empty states. Track the count in a separate assign, and put the empty state in a `hidden only:block` sibling of the `:for`.
- When an assign changes content inside streamed items, re-stream the item with `stream_insert/3` so the item re-renders.

### Hooks

- A `phx-hook` element needs a unique DOM id, plus `phx-update="ignore"` when the hook owns its DOM.
- Client-side JS is a colocated hook inside the template:

      <script :type={Phoenix.LiveView.ColocatedHook} name=".PhoneNumber">
        export default { mounted() { ... } }
      </script>

  The leading `.` on the name is required. Hooks shared across pages live in `assets/js/hooks/` and are passed to `LiveSocket`.
- `push_event/3` returns the socket — rebind it or return it from the handler.
- In the hook: `this.handleEvent("name", data => ...)` receives, `this.pushEvent("name", payload, reply => ...)` sends. The server replies with `{:reply, payload, socket}`.

## Forms

- Build the form in the LiveView with `to_form/2`, pass it to `<.form for={@form} id="...">`, and read fields as `@form[:field]` through `<.input>`:

      assign(socket, form: to_form(changeset))

      <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
        <.input field={@form[:field]} type="text" />
      </.form>

- `to_form/1` on a plain map expects string keys. Nest params with `to_form(params, as: :user)`.
- From a changeset: `Ecto.Changeset.change(user) |> to_form()`. Submitted params arrive as `%{"user" => ...}`.
- Every form gets a unique DOM id — the tests select on it.
- `<.input>` with custom classes inherits none of the defaults, so style it fully.

## Assets

- `assets/css/app.css` is authoritative for the Tailwind v4 setup: `@import "tailwindcss" source(none)`, the `@source` lines, the chessground stylesheets and `phoenix-colocated/chesstrainer/colocated.css`. Keep that import block current.
- Custom CSS uses plain declarations. `@apply` is off-limits.
- Components are hand-written Tailwind. daisyUI is not used.
- Only the `app.js` and `app.css` bundles ship. Vendor dependencies are imported into them, not linked from layouts.

## Testing

- Start processes with `start_supervised!/1`.
- Wait for a process with `Process.monitor/1` and `assert_receive {:DOWN, ^ref, :process, ^pid, :normal}` instead of `Process.sleep/1`.
- Synchronise before the next call with `_ = :sys.get_state(pid)`.
- LiveView tests use `Phoenix.LiveViewTest` and `LazyHTML`; drive forms with `render_submit/2` and `render_change/2`.
- Assert on elements with the ids from the template: `assert has_element?(view, "#my-form")`, `element/2`. Text content changes; ids don't.
- Debug a stubborn selector:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

## Precommit

`mix precommit` runs `compile --warnings-as-errors`, `deps.unlock --unused`, `format` and `test`.

## Type checking (Dialyzer)

`dialyxir` is available in dev/test; run:

    mix dialyzer

It is intentionally **not** part of `mix precommit`: the first run builds a PLT
(several minutes), though subsequent runs are fast. The PLT lives under
`_build/` (gitignored).

Treat warnings as bugs — add `@spec`s or fix them. Only suppress with
`@dialyzer` or `.dialyzer_ignore.exs` when accompanied by a comment explaining
why.
