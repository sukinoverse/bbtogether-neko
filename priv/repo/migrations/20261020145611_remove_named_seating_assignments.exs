defmodule Neko.Repo.Migrations.RemoveNamedSeatingAssignments do
  use Ecto.Migration

  def change do
    alter table(:rsvps) do
      remove :table_id, references(:seating_tables, on_delete: :restrict)
    end
  end
end
