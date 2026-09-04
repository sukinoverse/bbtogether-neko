defmodule Neko.Rsvp do
  use Ecto.Schema
  import Ecto.Changeset

  schema "rsvps" do
    field :name, :string
    field :phone, :string
    field :attending, :boolean
    field :party_size, :integer, default: 1

    timestamps(type: :utc_datetime)
  end

  def changeset(rsvp, attrs) do
    rsvp
    |> cast(attrs, [:name, :phone, :attending, :party_size])
    |> update_change(:name, &String.trim/1)
    |> update_change(:phone, &normalize_phone/1)
    |> validate_required([:name, :phone], message: "กรุณากรอกข้อมูลนี้")
    |> validate_required([:attending], message: "กรุณาเลือกคำตอบ")
    |> validate_length(:name, max: 120, message: "ชื่อต้องไม่เกิน 120 ตัวอักษร")
    |> validate_format(:phone, ~r/^\d{9,10}$/, message: "กรุณากรอกเบอร์โทรศัพท์ 9–10 หลัก")
    |> validate_party_size()
    |> unique_constraint(:phone, message: "เบอร์นี้ส่งคำตอบแล้ว ลองเช็กคำตอบด้านล่าง")
  end

  def normalize_phone(phone) when is_binary(phone) do
    digits = String.replace(phone, ~r/\D/u, "")

    case digits do
      "66" <> rest when byte_size(rest) in 8..9 -> "0" <> rest
      _ -> digits
    end
  end

  def normalize_phone(_phone), do: ""

  defp validate_party_size(changeset) do
    case get_field(changeset, :attending) do
      false ->
        put_change(changeset, :party_size, 0)

      true ->
        validate_number(changeset, :party_size,
          greater_than_or_equal_to: 1,
          less_than_or_equal_to: 10,
          message: "กรุณาเลือกจำนวน 1–10 ท่าน"
        )

      _ ->
        changeset
    end
  end
end
