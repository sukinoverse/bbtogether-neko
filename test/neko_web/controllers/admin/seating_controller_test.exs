defmodule NekoWeb.Admin.SeatingControllerTest do
  use NekoWeb.ConnCase
  alias Neko.{Repo, Rsvp, Seating}
  alias Neko.Seating.{Group, Table}

  setup do
    {:ok, group} = Seating.save_group(%Group{}, %{code: "A", name: "เพื่อน", color: "#91ad91"})

    {:ok, table} =
      Seating.save_table(%Table{}, %{
        label: "A1",
        capacity: 4,
        slot: 1,
        shape: "round",
        group_ids: [group.id]
      })

    %{group: group, table: table}
  end

  test "all seating endpoints require authentication", %{conn: conn, table: table, group: group} do
    for {method, path, params} <- [
          {:get, "/admin/seating", %{}},
          {:get, "/admin/seating/export", %{}},
          {:post, "/admin/seating/apply-layout", %{}},
          {:put, "/admin/seating/visibility", %{visibility: %{public_enabled: true}}},
          {:post, "/admin/seating/groups", %{group: %{}}},
          {:put, "/admin/seating/groups/#{group.id}", %{group: %{}}},
          {:delete, "/admin/seating/groups/#{group.id}", %{}},
          {:post, "/admin/seating/tables", %{table: %{}}},
          {:put, "/admin/seating/tables/#{table.id}", %{table: %{}}},
          {:delete, "/admin/seating/tables/#{table.id}", %{}}
        ] do
      assert conn |> recycle() |> dispatch(@endpoint, method, path, params) |> response(401)
    end
  end

  test "map shows unique table labels and does not expose RSVP names", %{
    conn: conn,
    table: table,
    group: _group
  } do
    Repo.insert!(%Rsvp{name: "Private Guest", attending: true, party_size: 2})
    doc = conn |> auth() |> get(~p"/admin/seating?table=#{table.id}") |> document()
    assert count(doc, "#venue-map #map-table-#{table.id}") == 1

    assert doc |> LazyHTML.query("#map-table-#{table.id} strong") |> LazyHTML.text() ==
             table.label

    assert count(doc, "#table-form") == 1
    assert count(doc, "#guests-tab") == 0
    assert count(doc, ".venue-chair.occupied") == 0
    refute doc |> LazyHTML.query("#seating-studio") |> LazyHTML.text() =~ "Private Guest"
    doc = conn |> auth() |> get(~p"/admin/seating?tab=guests") |> document()
    assert count(doc, "#venue-map") == 1
    assert count(doc, ".assignment-form") == 0
  end

  test "edit links land on their editor and map positions exclude occupied slots", %{
    conn: conn,
    table: table,
    group: group
  } do
    {:ok, current} = Seating.save_table(table, %{slot: 2})

    {:ok, other} =
      Seating.save_table(%Table{}, %{
        label: "B",
        capacity: 10,
        slot: 3,
        shape: "round",
        group_ids: [group.id]
      })

    doc = conn |> auth() |> get(~p"/admin/seating?table=#{current.id}") |> document()

    assert doc |> LazyHTML.query("#map-table-#{current.id}") |> LazyHTML.attribute("href") ==
             [~p"/admin/seating?table=#{current.id}" <> "#table-editor"]

    assert count(doc, "#table-editor[tabindex='-1']") == 1
    assert count(doc, "#table_slot option[value='2']") == 1
    assert count(doc, "#table_slot option[value='#{other.slot}']") == 0

    assert count(
             doc,
             "#table_slot option[value='1'], #table_slot option[value='4'], #table_slot option[value='12']"
           ) == 0

    groups = conn |> recycle() |> auth() |> get(~p"/admin/seating?tab=groups") |> document()

    assert groups |> LazyHTML.query("#edit-group-#{group.id}") |> LazyHTML.attribute("href") ==
             [~p"/admin/seating?tab=groups&group=#{group.id}" <> "#group-editor"]
  end

  test "a full nine-table plan prompts editing instead of offering occupied positions", %{
    conn: conn,
    table: table,
    group: group
  } do
    {:ok, _} = Seating.delete_table(table.id)
    {:ok, _} = Seating.delete_group(group.id)
    layout = File.read!("priv/repo/venue_layout.json") |> Jason.decode!()
    assert {:ok, :initialized} = Seating.initialize_layout(layout)
    doc = conn |> auth() |> get(~p"/admin/seating") |> document()
    assert count(doc, "#venue-map .venue-table") == 9
    assert count(doc, "#add-table, #table-form") == 0
    assert count(doc, "#table-editor") == 1
  end

  test "previous layout positions remain available when editing that table", %{
    conn: conn,
    table: table
  } do
    doc = conn |> auth() |> get(~p"/admin/seating?table=#{table.id}") |> document()
    assert count(doc, "#table_slot option[value='1'][selected]") == 1
  end

  test "invalid table and group edits render useful errors", %{
    conn: conn,
    table: table,
    group: group
  } do
    result = conn |> auth() |> put(~p"/admin/seating/tables/#{table.id}", table: %{capacity: "0"})
    assert count(document(result, 422), "#table-form") == 1
    assert Repo.get!(Table, table.id).capacity == 4
    result = conn |> auth() |> put(~p"/admin/seating/groups/#{group.id}", group: %{code: "!"})
    assert count(document(result, 422), "#group-form") == 1
  end

  test "group and table configuration can be created and edited", %{conn: conn, group: group} do
    result =
      conn
      |> auth()
      |> post(~p"/admin/seating/groups", group: %{code: "B", name: "Family", color: "#aabbcc"})

    assert redirected_to(result) == ~p"/admin/seating?tab=groups" <> "#seating-workspace"

    result =
      conn
      |> auth()
      |> post(~p"/admin/seating/tables",
        table: %{label: "A2", capacity: 10, slot: 2, shape: "long", group_ids: [group.id]}
      )

    table = Repo.get_by!(Table, label: "A2")
    assert redirected_to(result) == ~p"/admin/seating?table=#{table.id}" <> "#table-editor"

    conn
    |> auth()
    |> put(~p"/admin/seating/tables/#{table.id}", table: %{label: "Family", capacity: 12})

    assert Repo.get!(Table, table.id).label == "Family"
  end

  test "group seating works without online RSVPs and estimates persist", %{
    conn: conn,
    group: group
  } do
    assert Repo.aggregate(Rsvp, :count) == 0
    doc = conn |> auth() |> get(~p"/admin/seating") |> document()
    assert count(doc, "#group-seating-explainer") == 1
    assert count(doc, "#group-plan-#{group.id}") == 1

    result =
      conn |> auth() |> put(~p"/admin/seating/groups/#{group.id}", group: %{expected_guests: "6"})

    assert redirected_to(result) == ~p"/admin/seating?tab=groups" <> "#seating-workspace"
    assert Repo.get!(Group, group.id).expected_guests == 6
    assert Repo.aggregate(Rsvp, :count) == 0
    doc = conn |> auth() |> get(~p"/admin/seating?tab=groups") |> document()
    assert count(doc, "#group-shortage-#{group.id}") == 1

    assert doc |> LazyHTML.query("#group-shortage-#{group.id}") |> LazyHTML.text() =~
             "add 2 more seats"

    conn |> auth() |> put(~p"/admin/seating/groups/#{group.id}", group: %{expected_guests: "4"})
    doc = conn |> auth() |> get(~p"/admin/seating?tab=groups") |> document()
    assert count(doc, "#group-shortage-#{group.id}") == 0
    assert count(doc, "#group-estimate-#{group.id}") == 1
  end

  test "invalid estimates show form errors without changing the saved group", %{
    conn: conn,
    group: group
  } do
    result =
      conn
      |> auth()
      |> put(~p"/admin/seating/groups/#{group.id}", group: %{expected_guests: "-1"})

    assert count(document(result, 422), "#group-form") == 1
    assert Repo.get!(Group, group.id).expected_guests == nil
  end

  test "multiple groups save, render checked, and cannot all be cleared", %{
    conn: conn,
    table: table,
    group: group
  } do
    {:ok, other} =
      Seating.save_group(%Group{}, %{code: "B", name: "Bride friends", color: "#aabbcc"})

    result =
      conn
      |> auth()
      |> put(~p"/admin/seating/tables/#{table.id}",
        table: %{group_ids: ["", to_string(group.id), "", to_string(other.id)]}
      )

    assert redirected_to(result) == ~p"/admin/seating?table=#{table.id}" <> "#table-editor"
    doc = conn |> auth() |> get(~p"/admin/seating?table=#{table.id}") |> document()
    assert count(doc, "#table-group-#{group.id}[checked]") == 1
    assert count(doc, "#table-group-#{other.id}[checked]") == 1
    assert count(doc, "#map-table-#{table.id}[title*='Bride friends']") == 1

    result =
      conn |> auth() |> put(~p"/admin/seating/tables/#{table.id}", table: %{group_ids: ["", ""]})

    assert count(document(result, 422), "#table-groups") == 1
    assert length(Seating.get_table!(table.id).groups) == 2
  end

  test "visibility can be enabled and disabled without affecting the admin plan", %{
    conn: conn,
    table: table
  } do
    refute Seating.public_enabled?()

    result =
      conn |> auth() |> put(~p"/admin/seating/visibility", visibility: %{public_enabled: "true"})

    assert redirected_to(result) == ~p"/admin/seating"
    assert Seating.public_enabled?()
    doc = conn |> auth() |> get(~p"/admin/seating") |> document()
    assert count(doc, "#visibility_public_enabled[checked]") == 1
    conn |> auth() |> put(~p"/admin/seating/visibility", visibility: %{public_enabled: "false"})
    refute Seating.public_enabled?()
    doc = conn |> auth() |> get(~p"/admin/seating") |> document()
    assert count(doc, "#visibility_public_enabled[checked]") == 0
    assert count(doc, "#map-table-#{table.id}") == 1

    result =
      conn
      |> auth()
      |> put(~p"/admin/seating/visibility", visibility: %{public_enabled: "invalid"})

    assert count(document(result, 422), "#visibility-form") == 1
    refute Seating.public_enabled?()
  end

  test "saved plan preview includes assignments and explicit confirmation", %{conn: conn} do
    doc = conn |> auth() |> get(~p"/admin/seating") |> document()
    assert count(doc, "#saved-layout-tables li") == 9
    assert count(doc, "#import_confirmed[required]") == 1
    assert count(doc, "#import_confirmed[checked]") == 0
    assert count(doc, "#download-seating-backup") == 1
    assert count(doc, "#apply-saved-layout") == 1

    assert doc |> LazyHTML.query("#import_revision") |> LazyHTML.attribute("value") ==
             [Seating.layout_revision(Seating.saved_layout())]
  end

  test "replacement requires confirmation and the reviewed snapshot revision", %{
    conn: conn,
    table: table
  } do
    revision = Seating.layout_revision(Seating.saved_layout())

    for params <- [
          %{},
          %{"import" => %{"confirmed" => "false", "revision" => revision}},
          %{"import" => %{"confirmed" => "true"}}
        ] do
      assert conn
             |> recycle()
             |> auth()
             |> post(~p"/admin/seating/apply-layout", params)
             |> response(400)

      assert Seating.get_table!(table.id).label == table.label
    end

    result =
      conn
      |> recycle()
      |> auth()
      |> post(~p"/admin/seating/apply-layout",
        import: %{confirmed: "true", revision: "outdated"}
      )

    assert redirected_to(result) == ~p"/admin/seating"
    assert Phoenix.Flash.get(result.assigns.flash, :error) =~ "saved plan changed"
    assert Seating.get_table!(table.id).label == table.label
  end

  test "confirmed admin replacement applies the saved plan and preserves guests", %{conn: conn} do
    guest =
      Repo.insert!(%Rsvp{name: "Real guest", phone: "0811111111", attending: true, party_size: 2})

    {:ok, _} = Seating.update_visibility(%{public_enabled: true})
    layout = Seating.saved_layout()

    result =
      conn
      |> auth()
      |> post(~p"/admin/seating/apply-layout",
        import: %{confirmed: "true", revision: Seating.layout_revision(layout)}
      )

    assert redirected_to(result) == ~p"/admin/seating"
    assert Map.drop(Seating.export_layout(), ["captured_at"]) == Map.drop(layout, ["captured_at"])
    assert Repo.get!(Rsvp, guest.id) == guest
    assert Seating.public_enabled?()
  end

  test "backup download contains only the current seating plan", %{conn: conn, table: table} do
    result = conn |> auth() |> get(~p"/admin/seating/export")
    layout = result |> response(200) |> Jason.decode!()
    assert [saved] = layout["tables"]
    assert saved["label"] == table.label
    assert Enum.sort(Map.keys(layout)) == ~w(captured_at groups tables)
    assert get_resp_header(result, "cache-control") == ["private, no-store"]
    assert hd(get_resp_header(result, "content-disposition")) =~ "attachment"
  end

  defp auth(conn),
    do: put_req_header(conn, "authorization", "Basic " <> Base.encode64("admin:admin"))

  defp document(conn, status \\ 200),
    do: conn |> html_response(status) |> LazyHTML.from_document()

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()
end
