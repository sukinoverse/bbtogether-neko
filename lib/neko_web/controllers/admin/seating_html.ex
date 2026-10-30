defmodule NekoWeb.Admin.SeatingHTML do
  use NekoWeb, :html
  import NekoWeb.Admin.RsvpHTML, only: [admin_header: 1, admin_footer: 1]
  embed_templates "seating_html/*"

  def position_options(tables, selected) do
    positions = [
      {2, "Front · left"},
      {3, "Front · right"},
      {5, "Middle · far left"},
      {6, "Middle · left aisle"},
      {7, "Middle · right aisle"},
      {8, "Middle · far right"},
      {9, "Back · far left"},
      {10, "Back · left aisle"},
      {11, "Back · right aisle"}
    ]

    positions =
      if selected && selected.slot in [1, 4, 12],
        do: positions ++ [{selected.slot, "Current position (previous layout)"}],
        else: positions

    for {slot, label} <- positions,
        not Enum.any?(tables, &(&1.slot == slot && (!selected || &1.id != selected.id))),
        do: {label, slot}
  end

  def selected_group?(form, id),
    do: to_string(id) in Enum.map(form[:group_ids].value || [], &to_string/1)
end
