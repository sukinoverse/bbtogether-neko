defmodule Neko.Repo.Migrations.AddSeatingVisibilitySettings do
  use Ecto.Migration

  def change do
    create table(:seating_settings, primary_key: false) do
      add :id, :integer, primary_key: true
      add :public_enabled, :boolean, null: false, default: false
      timestamps(type: :utc_datetime)
    end

    create constraint(:seating_settings, :single_seating_settings, check: "id = 1")
  end
end
