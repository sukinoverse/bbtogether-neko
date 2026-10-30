defmodule Neko.Seating.Table do
  use Ecto.Schema
  import Ecto.Changeset

  schema "seating_tables" do
    field :label, :string
    field :capacity, :integer, default: 20
    field :slot, :integer
    field :shape, :string, default: "long"
    field :group_ids, {:array, :integer}, virtual: true

    many_to_many :groups, Neko.Seating.Group,
      join_through: "seating_table_groups",
      on_replace: :delete,
      preload_order: [asc: :code]

    timestamps(type: :utc_datetime)
  end

  def changeset(table, attrs) do
    attrs =
      Enum.into(attrs, %{}, fn
        {key, ids} when key in [:group_ids, "group_ids"] and is_list(ids) ->
          {key, Enum.reject(ids, &(&1 == ""))}

        entry ->
          entry
      end)

    table =
      if Ecto.assoc_loaded?(table.groups),
        do: %{table | group_ids: Enum.map(table.groups, & &1.id)},
        else: table

    table
    |> cast(attrs, [:label, :capacity, :slot, :shape, :group_ids])
    |> update_change(:label, &String.trim/1)
    |> validate_required([:label, :capacity, :slot, :shape, :group_ids])
    |> validate_length(:label, max: 16)
    |> validate_number(:capacity, greater_than: 0, less_than_or_equal_to: 30)
    |> validate_number(:slot, greater_than_or_equal_to: 1, less_than_or_equal_to: 12)
    |> validate_inclusion(:shape, ["long", "round"])
    |> unique_constraint(:label)
    |> unique_constraint(:slot)
    |> validate_length(:group_ids, min: 1, message: "choose at least one group")
  end
end
