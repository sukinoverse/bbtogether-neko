defmodule Neko.Repo.Migrations.CreateInvitations do
  use Ecto.Migration

  def change do
    create table(:invitations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :guest_name, :string, null: false
      add :token, :string, null: false
      add :revoked_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:invitations, [:token])

    alter table(:rsvps) do
      add :invitation_id,
          references(:invitations, type: :binary_id, on_delete: :nilify_all)
    end

    create index(:rsvps, [:invitation_id])
  end
end
