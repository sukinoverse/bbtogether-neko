defmodule Neko.Seating.Group do
  use Ecto.Schema
  import Ecto.Changeset

  schema "seating_groups" do
    field :code, :string
    field :name, :string
    field :expected_guests, :integer
    field :color, :string, default: "#8fa9c2"
    timestamps(type: :utc_datetime)
  end

  def changeset(group, attrs) do
    group
    |> cast(attrs, [:code, :name, :color, :expected_guests])
    |> update_change(:code, &(String.trim(&1) |> String.upcase()))
    |> update_change(:name, &String.trim/1)
    |> validate_required([:code, :name, :color])
    |> validate_format(:code, ~r/^[A-Z]{1,3}$/)
    |> validate_length(:name, max: 80)
    |> validate_format(:color, ~r/^#[0-9a-fA-F]{6}$/)
    |> validate_number(:expected_guests, greater_than_or_equal_to: 0)
    |> unique_constraint(:code)
  end
end
