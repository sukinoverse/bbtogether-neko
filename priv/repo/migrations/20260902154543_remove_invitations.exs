defmodule Neko.Repo.Migrations.RemoveInvitations do
  use Ecto.Migration

  def change do
    alter table(:rsvps) do
      remove :invitation_id, references(:invitations, type: :binary_id, on_delete: :nilify_all)
    end

    drop table(:invitations)
  end
end
