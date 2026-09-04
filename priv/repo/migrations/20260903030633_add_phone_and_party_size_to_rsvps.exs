defmodule Neko.Repo.Migrations.AddPhoneAndPartySizeToRsvps do
  use Ecto.Migration

  def up do
    alter table(:rsvps) do
      add :phone, :string
      add :party_size, :integer, null: false, default: 0
    end

    execute """
    UPDATE rsvps
    SET party_size = CASE
      WHEN attending = false THEN 0
      WHEN bringing_partner = true THEN 2
      ELSE 1
    END
    """

    alter table(:rsvps) do
      remove :bringing_partner
    end

    create unique_index(:rsvps, [:phone], where: "phone IS NOT NULL")
  end

  def down do
    drop unique_index(:rsvps, [:phone], where: "phone IS NOT NULL")

    alter table(:rsvps) do
      add :bringing_partner, :boolean, null: false, default: false
    end

    execute "UPDATE rsvps SET bringing_partner = attending AND party_size > 1"

    alter table(:rsvps) do
      remove :phone
      remove :party_size
    end
  end
end
