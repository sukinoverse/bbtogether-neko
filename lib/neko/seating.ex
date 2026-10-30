defmodule Neko.Seating do
  import Ecto.Query
  alias Neko.Repo
  alias Neko.Seating.{Group, Table, Settings}

  def visibility_settings, do: Repo.get(Settings, 1) || %Settings{id: 1}
  def public_enabled?, do: visibility_settings().public_enabled

  def update_visibility(attrs) do
    %Settings{id: 1}
    |> Settings.changeset(attrs)
    |> Repo.insert(
      on_conflict: {:replace, [:public_enabled, :updated_at]},
      conflict_target: :id,
      returning: true
    )
  end

  def groups, do: Repo.all(from g in Group, order_by: g.code)
  def tables, do: Repo.all(from t in Table, order_by: t.slot, preload: [:groups])

  def group_plans(groups, tables) do
    Enum.map(groups, fn group ->
      group_tables = Enum.filter(tables, &in_group?(&1, group.id))
      capacity = Enum.sum(Enum.map(group_tables, & &1.capacity))

      %{
        group: group,
        tables: length(group_tables),
        capacity: capacity,
        shared:
          group_tables
          |> Enum.filter(&(length(&1.groups) > 1))
          |> Enum.map(& &1.capacity)
          |> Enum.sum(),
        shortage: if(group.expected_guests, do: max(group.expected_guests - capacity, 0), else: 0)
      }
    end)
  end

  def get_table!(id), do: Repo.get!(Table, id) |> Repo.preload(:groups)
  def get_group!(id), do: Repo.get!(Group, id)
  def save_group(group, attrs), do: group |> Group.changeset(attrs) |> Repo.insert_or_update()

  def in_group?(table, group_id), do: Enum.any?(table.groups, &(&1.id == group_id))

  def save_table(table, attrs) do
    table = if table.id, do: Repo.preload(table, :groups), else: %{table | groups: []}
    changeset = Table.changeset(table, attrs)
    ids = Ecto.Changeset.get_field(changeset, :group_ids) || []
    groups = Repo.all(from g in Group, where: g.id in ^ids, order_by: g.code)

    changeset =
      if length(groups) == length(Enum.uniq(ids)) do
        Ecto.Changeset.put_assoc(changeset, :groups, groups)
      else
        Ecto.Changeset.add_error(changeset, :group_ids, "contains an unknown group")
      end

    Repo.insert_or_update(changeset)
  end

  def delete_table(id), do: id |> get_table!() |> Repo.delete()

  def saved_layout do
    Application.app_dir(:neko, "priv/repo/venue_layout.json") |> File.read!() |> Jason.decode!()
  end

  def layout_revision(layout),
    do: :crypto.hash(:sha256, Jason.encode!(layout)) |> Base.encode16(case: :lower)

  def export_layout do
    %{
      "captured_at" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "groups" =>
        Enum.map(groups(), fn group ->
          %{
            "code" => group.code,
            "name" => group.name,
            "color" => group.color,
            "expected_guests" => group.expected_guests
          }
        end),
      "tables" =>
        Enum.map(tables(), fn table ->
          %{
            "label" => table.label,
            "slot" => table.slot,
            "shape" => table.shape,
            "capacity" => table.capacity,
            "group_codes" => Enum.map(table.groups, & &1.code)
          }
        end)
    }
  end

  def initialize_layout(layout) do
    Repo.transaction(fn ->
      if Repo.exists?(Group) || Repo.exists?(Table), do: Repo.rollback(:already_configured)
      insert_layout(layout)
      :initialized
    end)
  end

  def replace_layout(layout) do
    Repo.transaction(fn ->
      # Serialize replacements with other seating writes; readers can keep viewing the old plan.
      Repo.query!(
        "LOCK TABLE seating_groups, seating_tables, seating_table_groups IN SHARE ROW EXCLUSIVE MODE"
      )

      Repo.delete_all(Table)
      Repo.delete_all(Group)
      insert_layout(layout)
      :replaced
    end)
  end

  defp insert_layout(%{"groups" => groups, "tables" => tables})
       when is_list(groups) and groups != [] and is_list(tables) and tables != [] do
    by_code =
      Map.new(groups, fn attrs ->
        unless is_map(attrs), do: Repo.rollback(:invalid_layout)

        case save_group(%Group{}, Map.take(attrs, ["code", "name", "color", "expected_guests"])) do
          {:ok, group} -> {group.code, group.id}
          {:error, _} -> Repo.rollback(:invalid_layout)
        end
      end)

    for attrs <- tables do
      unless is_map(attrs) and is_list(attrs["group_codes"]), do: Repo.rollback(:invalid_layout)
      ids = Enum.map(attrs["group_codes"], &Map.get(by_code, &1))
      if Enum.any?(ids, &is_nil/1), do: Repo.rollback(:invalid_layout)

      case save_table(%Table{}, Map.put(attrs, "group_ids", ids)) do
        {:ok, _} -> :ok
        {:error, _} -> Repo.rollback(:invalid_layout)
      end
    end
  end

  defp insert_layout(_), do: Repo.rollback(:invalid_layout)

  def delete_group(id) do
    group = get_group!(id)

    group
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.foreign_key_constraint(:id,
      name: :seating_table_groups_group_id_fkey,
      message: "Move this group’s tables to another group first"
    )
    |> Repo.delete()
  end
end
