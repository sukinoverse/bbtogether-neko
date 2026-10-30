defmodule Neko.Repo.Migrations.AddExpectedGuestsToSeatingGroups do
  use Ecto.Migration

  def change do
    alter table(:seating_groups) do
      add :expected_guests, :integer
    end

    create constraint(:seating_groups, :nonnegative_expected_guests,
             check: "expected_guests >= 0"
           )
  end
end
