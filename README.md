# Neko

To start your Phoenix server:

* Run `mix setup` to install and setup dependencies
* Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

Ready to run in production? Please [check our deployment guides](https://hexdocs.pm/phoenix/deployment.html).

## Learn more

* Official website: https://www.phoenixframework.org/
* Guides: https://hexdocs.pm/phoenix/overview.html
* Docs: https://hexdocs.pm/phoenix
* Forum: https://elixirforum.com/c/phoenix-forum
* Source: https://github.com/phoenixframework/phoenix

## Seating studio

Open `http://localhost:4000/admin/seating` (local defaults: `admin` / `admin`).
The existing RSVP dashboard also links to the studio.

- **Venue map:** select a table to edit its label, group, capacity, shape, or position.
  The revised draft has nine tables: two round tables at the front, four long tables in the middle, and three at the back. The back-left table seats 10; the other long tables seat 20. Gates are at both lower sides, with the buffet on the right and drinks at the bottom right. The editor offers the nine positions in this draft and excludes occupied slots. Tables saved in the previous layout can keep their existing positions.
  Positions count left to right, from the stage toward the entrance.
- **Group seating only:** guests choose any seat at any table in their group
  and arrange seats themselves. A table can belong to multiple guest groups. No names, reservations, or individual assignments
  appear on the map. Physical-card guests do not need an RSVP or guest record.
- **Guest groups:** edit group letters, names, colors, and optional headcount
  estimates. Estimates include physical-card guests, online RSVPs, and companions;
  count each person once. They are independent of RSVP totals. Blank means unknown;
  zero means no guests expected. Group cards show exclusive and shared capacity.
  Shared seats are not reserved separately per group; the venue total counts
  each seat once. A group shortage flag is a minimum shortfall, not a guarantee
  that simultaneous demand from all groups sharing tables will fit.
- **Table signs:** each table has a unique letter (A–I in the demo), independent
  of its guest group. Colors identify groups; the map legend lists each group’s
  tables. Edit a table and check one or more guest groups. The legend lists all groups sharing each table. The ten guest groups use codes A–J in the configured order; table assignments remain editable.
  Remove a group from its tables before deleting that group. RSVP records remain
  separate from seating and are preserved when tables change.

Apply the migration and optionally load local demo data:

```sh
mix ecto.migrate
mix run priv/repo/seating_demo.exs
mix phx.server
```

The development-only demo creates the ten configured guest groups (A–J), 9 tables
with 150 seats, and 18 `[Demo]` RSVP parties (43 guests) for the separate RSVP
dashboard. Group headcount estimates are left blank until entered in admin. The script preserves existing records when rerun and does not
run as part of production seeds.

On phones, the admin map fits the screen and table/group links open directly at the editor. Visibility controls and planning notes expand when needed.

Validation: `mix precommit` runs compilation with warnings as errors, formatting,
and the full test suite. `mix assets.build` verifies the CSS/JavaScript bundles.

## Public map and deployment

The seating guide is **hidden by default**, including on a fresh production deploy.
In `/admin/seating`, check **Show seating guide on main website** and click
**Save visibility** when the plan is ready. Uncheck and save to hide it again.
The setting is stored in the database and survives restarts and deployments.
While hidden, the public HTML contains no seating section or table/group data;
the admin studio stays available. Demo seeding and layout initialization do not
turn it on. When visible, subsequent admin edits appear on the next page load,
so hide it before making changes you do not want guests to see.

When enabled, the main wedding page includes the read-only plan at `/#wedding-seating`.
Guests see each group’s table letters immediately, including tables shared with
other groups. The opening screen links straight to the seating section when enabled.
Tapping a group highlights its tables and brings the compact, phone-friendly map into view; tapping again or choosing “ดูทุกโต๊ะ” resets it. The guide remains readable
without JavaScript. No admin controls, RSVP records, headcount estimates, tiny
chairs, or equipment labels appear in this guest view. Admin edits appear on
subsequent page loads. An empty plan shows a preparation message.

`fly deploy --app bbtogether` runs migrations through the existing release command.
For a new, empty production seating database, initialize the checked-in venue
layout with `/app/bin/neko eval 'Neko.Release.initialize_seating() |> IO.inspect()'`
inside the running Fly machine. This imports table/group configuration only,
creates no RSVP data, imports captured headcount estimates, and refuses to overwrite any existing
seating plan. Subsequent deployments do not reset admin changes.

## Apply the saved seating plan

The deployed admin studio has **Apply saved seating plan**. Expand it to review
the exact table/group assignments bundled in `priv/repo/venue_layout.json`.
Download the current seating backup, check the replacement confirmation, then
press **Replace seating with saved plan**. The replacement runs in one database
transaction. Invalid plans roll back, and an outdated confirmation is rejected.
It replaces seating groups, tables, and assignments only. RSVPs and the public
visibility setting are preserved. Deploying code alone never applies the plan.

The bundled plan is a snapshot, not a live connection to the development database.
After changing the local plan, refresh the snapshot before committing/deploying:

```sh
mix run -e 'File.write!("priv/repo/venue_layout.json", Jason.encode!(Neko.Seating.export_layout(), pretty: true) <> "\n")'
```

The export contains table/group configuration and optional estimates, with no RSVP
records, internal IDs, or website visibility. To restore a downloaded backup,
load its JSON through `Neko.Seating.replace_layout/1` in the appropriate release
console after reviewing it.
