# Local, repeatable demo. Existing groups, tables, and RSVPs are preserved.
if Mix.env() != :dev, do: raise("Seating demo is for development only")
alias Neko.{Repo, Rsvp, Seating}
alias Neko.Seating.{Group, Table}

Repo.transaction(fn ->
  layout = File.read!(Path.join(__DIR__, "venue_layout.json")) |> Jason.decode!()
  groups = Map.new(layout["groups"], fn attrs ->
    group = Repo.get_by(Group, code: attrs["code"]) || Repo.insert!(Group.changeset(%Group{}, attrs))
    {group.code, group}
  end)
  for attrs <- layout["tables"] do
    unless Repo.get_by(Table, slot: attrs["slot"]) || Repo.get_by(Table, label: attrs["label"]) do
      ids = Enum.map(attrs["group_codes"], &Map.fetch!(groups, &1).id)
      {:ok, _} = Seating.save_table(%Table{}, Map.put(attrs, "group_ids", ids))
    end
  end
  names = ["[Demo] พลอย และครอบครัว", "[Demo] พี่แนน", "[Demo] ต้น + ฝน", "[Demo] คุณน้าอร", "[Demo] คุณอาวิชัย", "[Demo] แก๊งมหาวิทยาลัย", "[Demo] พี่เมย์", "[Demo] ทีมดีไซน์", "[Demo] ก้อย และครอบครัว", "[Demo] ปาล์ม", "[Demo] คุณลุงสมชาย", "[Demo] เพื่อนที่ทำงาน", "[Demo] บีม", "[Demo] มิ้นท์", "[Demo] โอ๊ต และครอบครัว", "[Demo] นุ่น", "[Demo] เจมส์", "[Demo] น้ำหวาน"]
  for {name, i} <- Enum.with_index(names) do
    phone = "000" <> String.pad_leading(Integer.to_string(i + 1), 7, "0")
    unless Repo.get_by(Rsvp, phone: phone) do
      Repo.insert!(Rsvp.changeset(%Rsvp{}, %{name: name,phone: phone,attending: true,party_size: rem(i, 4) + 1}))
    end
  end
end)
IO.puts("Seating demo ready: /admin/seating (admin / admin with default local config)")
