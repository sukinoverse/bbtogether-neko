defmodule Neko.SeatingTest do
  use Neko.DataCase
  alias Neko.{Repo, Rsvp, Seating}
  alias Neko.Seating.{Group, Table}

  setup do
    {:ok, group} = Seating.save_group(%Group{}, %{code: "A", name: "Friends", color: "#91ad91"})

    {:ok, table} =
      Seating.save_table(%Table{}, %{
        label: "A1",
        capacity: 4,
        slot: 1,
        shape: "long",
        group_ids: [group.id]
      })

    guest =
      Repo.insert!(%Rsvp{name: "Guest", phone: "0812345678", attending: true, party_size: 3})

    %{group: group, table: table, guest: guest}
  end

  test "tables can be resized and removed independently of RSVPs", %{table: table, group: group} do
    assert {:ok, updated} = Seating.save_table(table, %{capacity: 2})
    assert updated.capacity == 2
    assert {:error, _} = Seating.delete_group(group.id)
    assert {:ok, _} = Seating.delete_table(table.id)
    assert {:ok, _} = Seating.delete_group(group.id)
    assert Repo.aggregate(Rsvp, :count) == 1
  end

  test "group codes and positions are unique and colors validated", %{group: group} do
    assert {:error, _} =
             Seating.save_group(%Group{}, %{code: " a ", name: "Duplicate", color: "#ffffff"})

    assert {:error, _} = Seating.save_group(group, %{color: "red;display:none"})

    assert {:error, _} =
             Seating.save_table(%Table{}, %{
               label: "New",
               capacity: 4,
               slot: 1,
               shape: "long",
               group_ids: [group.id]
             })

    assert {:error, _} =
             Seating.save_table(%Table{}, %{
               label: "New",
               capacity: 0,
               slot: 13,
               shape: "long",
               group_ids: [group.id]
             })
  end

  test "group estimates work without RSVP records and report capacity shortages", %{group: group} do
    {:ok, group} = Seating.save_group(group, %{expected_guests: 6})
    [plan] = Seating.group_plans([group], Seating.tables())
    assert plan.capacity == 4
    assert plan.shortage == 2
    assert plan.group.expected_guests == 6
  end

  test "tables can share groups and count shared capacity separately", %{
    table: table,
    group: group
  } do
    {:ok, bride} =
      Seating.save_group(%Group{}, %{code: "B", name: "Bride friends", color: "#d4aabb"})

    assert {:ok, updated} = Seating.save_table(table, %{group_ids: [group.id, bride.id]})
    assert Enum.map(updated.groups, & &1.id) == [group.id, bride.id]
    tables = Seating.tables()
    assert Enum.sum(Enum.map(tables, & &1.capacity)) == 4
    plans = Seating.group_plans([group, bride], tables)
    assert Enum.all?(plans, &(&1.capacity == 4 && &1.shared == 4))
    assert {:error, _} = Seating.delete_group(bride.id)
    assert {:ok, updated} = Seating.save_table(updated, %{group_ids: [group.id]})
    assert length(updated.groups) == 1
    assert {:ok, _} = Seating.delete_group(bride.id)
  end

  test "invalid group selections preserve existing table memberships", %{
    table: table,
    group: group
  } do
    for ids <- [[], [""], [999_999], ["invalid"]] do
      assert {:error, _} = Seating.save_table(table, %{group_ids: ids})
      assert Enum.map(Seating.get_table!(table.id).groups, & &1.id) == [group.id]
    end

    assert {:ok, updated} =
             Seating.save_table(table, %{
               "group_ids" => ["", to_string(group.id), to_string(group.id)]
             })

    assert length(updated.groups) == 1
  end

  test "production layout initialization never overwrites an existing plan", %{table: table} do
    layout = File.read!("priv/repo/venue_layout.json") |> Jason.decode!()
    assert {:error, :already_configured} = Seating.initialize_layout(layout)
    assert Seating.get_table!(table.id).label == table.label
  end

  test "production layout initialization creates no demo RSVPs or headcount estimates", %{
    table: table,
    group: group
  } do
    Seating.delete_table(table.id)
    Seating.delete_group(group.id)
    count = Repo.aggregate(Rsvp, :count)
    layout = File.read!("priv/repo/venue_layout.json") |> Jason.decode!()
    assert {:ok, :initialized} = Seating.initialize_layout(layout)
    tables = Seating.tables()
    assert length(tables) == 9
    assert Enum.sum(Enum.map(tables, & &1.capacity)) == 150
    assert Enum.map(tables, & &1.label) == ~w(A B C D E F G H I)
    assert Enum.count(tables, &(&1.shape == "round" && &1.capacity == 10)) == 2
    assert Enum.find(tables, &(&1.slot == 9)).capacity == 10
    refute Enum.any?(tables, &(&1.slot in [1, 4, 12]))

    assert Enum.map(Seating.groups(), &{&1.code, &1.name}) == [
             {"A", "VIP เจ้าบ่าว"},
             {"B", "VIP เจ้าสาว"},
             {"C", "ญาติเจ้าสาว ลพบุรี"},
             {"D", "P.B. 111/6"},
             {"E", "NRMU #42"},
             {"F", "RAMA & CNMI"},
             {"G", "B.Care"},
             {"H", "ญาติเจ้าบ่าว ระยอง"},
             {"I", "CMU & PRC"},
             {"J", "FASTWORK"}
           ]

    assert Enum.all?(Seating.groups(), &is_nil(&1.expected_guests))
    assert Repo.aggregate(Rsvp, :count) == count
  end

  test "replacing a plan keeps RSVPs and visibility and retains shared tables", %{guest: guest} do
    {:ok, _} = Seating.update_visibility(%{public_enabled: true})
    layout = Seating.saved_layout()
    assert {:ok, :replaced} = Seating.replace_layout(layout)
    assert Map.drop(Seating.export_layout(), ["captured_at"]) == Map.drop(layout, ["captured_at"])
    assert Repo.get!(Rsvp, guest.id) == guest
    assert Seating.public_enabled?()

    assert Enum.find(Seating.tables(), &(&1.label == "F")).groups |> Enum.map(& &1.code) ==
             ~w(H I)

    {:ok, _} = Seating.update_visibility(%{public_enabled: false})
    assert {:ok, :replaced} = Seating.replace_layout(layout)
    refute Seating.public_enabled?()
    assert Repo.get!(Rsvp, guest.id) == guest
  end

  test "invalid replacements roll back the entire current plan", %{table: table, group: group} do
    layout = Seating.saved_layout()
    [first | rest] = layout["tables"]

    for invalid <- [
          %{},
          %{"groups" => [], "tables" => []},
          Map.put(layout, "tables", [Map.put(first, "capacity", 0) | rest]),
          Map.put(layout, "tables", [Map.put(first, "group_codes", ["UNKNOWN"]) | rest]),
          Map.put(layout, "tables", [first, first]),
          Map.put(layout, "groups", layout["groups"] ++ [hd(layout["groups"])])
        ] do
      assert {:error, :invalid_layout} = Seating.replace_layout(invalid)
      assert Seating.get_table!(table.id).groups == [group]
      assert length(Seating.tables()) == 1
      assert Seating.groups() == [group]
    end
  end

  test "seating exports omit RSVP data, internal IDs, and website visibility", %{guest: guest} do
    layout = Seating.export_layout()
    assert Enum.sort(Map.keys(layout)) == ~w(captured_at groups tables)

    assert Enum.all?(
             layout["groups"],
             &(Enum.sort(Map.keys(&1)) == ~w(code color expected_guests name))
           )

    assert Enum.all?(
             layout["tables"],
             &(Enum.sort(Map.keys(&1)) == ~w(capacity group_codes label shape slot))
           )

    refute Jason.encode!(layout) =~ guest.phone
    refute Jason.encode!(layout) =~ guest.name
  end

  test "estimates distinguish unknown and zero, reject negatives and fractions", %{group: group} do
    assert group.expected_guests == nil
    assert {:ok, updated} = Seating.save_group(group, %{expected_guests: 0})
    assert updated.expected_guests == 0
    assert {:ok, cleared} = Seating.save_group(updated, %{expected_guests: ""})
    assert cleared.expected_guests == nil
    assert {:error, changeset} = Seating.save_group(group, %{expected_guests: -1})
    assert errors_on(changeset).expected_guests != []
    assert {:error, _} = Seating.save_group(group, %{expected_guests: "1.5"})
  end
end
