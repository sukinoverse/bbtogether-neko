defmodule Neko.Rsvp do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rsvps" do
    field :name, :string
    field :attending, :boolean
    field :bringing_partner, :boolean, default: false

    timestamps(type: :utc_datetime)
  end

  def changeset(rsvp, attrs) do
    rsvp
    |> cast(attrs, [:name, :attending, :bringing_partner])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name], message: "กรุณากรอกชื่อของคุณ")
    |> validate_required([:attending], message: "กรุณาเลือกคำตอบ")
    |> validate_length(:name, max: 120, message: "ชื่อต้องไม่เกิน 120 ตัวอักษร")
    |> clear_partner_when_absent()
  end

  defp clear_partner_when_absent(changeset) do
    if get_field(changeset, :attending) == false do
      put_change(changeset, :bringing_partner, false)
    else
      changeset
    end
  end
end
