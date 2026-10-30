defmodule Neko.Repo.Migrations.AllowMultipleGroupsPerTable do
  use Ecto.Migration

  def up do
    create table(:seating_table_groups, primary_key: false) do
      add :table_id, references(:seating_tables, on_delete: :delete_all), primary_key: true
      add :group_id, references(:seating_groups, on_delete: :restrict), primary_key: true
    end

    create index(:seating_table_groups, [:group_id])

    execute "INSERT INTO seating_table_groups (table_id, group_id) SELECT id, group_id FROM seating_tables"

    alter table(:seating_tables) do
      remove :group_id
    end
  end

  def down do
    alter table(:seating_tables) do
      add :group_id, references(:seating_groups, on_delete: :restrict)
    end

    execute "UPDATE seating_tables t SET group_id = (SELECT MIN(group_id) FROM seating_table_groups WHERE table_id = t.id)"

    alter table(:seating_tables) do
      modify :group_id, :bigint, null: false
    end

    create index(:seating_tables, [:group_id])
    drop table(:seating_table_groups)
  end
end
