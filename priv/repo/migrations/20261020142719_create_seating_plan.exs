defmodule Neko.Repo.Migrations.CreateSeatingPlan do
  use Ecto.Migration

  def change do
    create table(:seating_groups) do
      add :code, :string, null: false
      add :name, :string, null: false
      add :color, :string, null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:seating_groups, [:code])

    create table(:seating_tables) do
      add :label, :string, null: false
      add :capacity, :integer, null: false
      add :slot, :integer, null: false
      add :shape, :string, null: false
      add :group_id, references(:seating_groups, on_delete: :restrict), null: false
      timestamps(type: :utc_datetime)
    end

    create unique_index(:seating_tables, [:label])
    create unique_index(:seating_tables, [:slot])
    create index(:seating_tables, [:group_id])
    create constraint(:seating_tables, :positive_capacity, check: "capacity BETWEEN 1 AND 30")
    create constraint(:seating_tables, :valid_slot, check: "slot BETWEEN 1 AND 12")

    alter table(:rsvps) do
      add :table_id, references(:seating_tables, on_delete: :restrict)
    end

    create index(:rsvps, [:table_id])
  end
end
