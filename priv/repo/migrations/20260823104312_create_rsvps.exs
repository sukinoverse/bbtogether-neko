defmodule Neko.Repo.Migrations.CreateRsvps do
  use Ecto.Migration

  def change do
    create table(:rsvps) do
      add :name, :string, null: false
      add :attending, :boolean, null: false
      add :bringing_partner, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end
  end
end
