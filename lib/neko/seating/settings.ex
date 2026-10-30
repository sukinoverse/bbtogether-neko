defmodule Neko.Seating.Settings do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :integer, autogenerate: false}
  schema "seating_settings" do
    field :public_enabled, :boolean, default: false
    timestamps(type: :utc_datetime)
  end

  def changeset(settings, attrs) do
    settings
    |> cast(attrs, [:public_enabled])
    |> validate_required([:public_enabled])
  end
end
