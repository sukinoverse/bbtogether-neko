defmodule NekoWeb.VenueMap do
  use NekoWeb, :html
  alias Neko.Seating

  attr :tables, :list, required: true
  attr :groups, :list, required: true
  attr :editable, :boolean, default: false
  attr :selected, :any, default: nil

  def map(assigns) do
    ~H"""
    <div class="venue-scroll">
      <div
        id="venue-map"
        class="venue-map"
        aria-label="Venue floor plan, stage at the top and gates at the bottom left and right"
      >
        <div class="venue-utility equipment">Event<br />equipment</div>
        <div class="venue-stage">
          <span>THE HAPPIEST DAY</span><strong>Bee <i>&amp;</i> Boom</strong><small>STAGE · เวที</small>
        </div>
        <div class="venue-utility control">Sound &amp;<br />control</div>
        <div class="venue-aisle">
          <span>THE WALK TO FOREVER</span>
          <.icon name="hero-heart" class="size-5" /><small>ทางเดิน</small>
        </div>
        <a
          :for={table <- @tables}
          id={"map-table-#{table.id}"}
          href={
            if @editable,
              do: ~p"/admin/seating?table=#{table.id}" <> "#table-editor",
              else: "#public-table-#{table.id}"
          }
          class={[
            "venue-table",
            table.shape,
            @selected && @selected.id == table.id && "selected"
          ]}
          style={table_style(table) <> table_colors(table)}
          aria-label={"Table #{table.label}, #{group_names(table)}, #{table.capacity} seats"}
          title={group_names(table)}
          aria-current={if @selected && @selected.id == table.id, do: "true", else: "false"}
        >
          <span
            :for={index <- 0..(table.capacity - 1)}
            class="venue-chair"
            aria-hidden="true"
            style={chair_style(index, table.capacity, table.shape)}
          >
          </span>
          <span class="table-group">TABLE / โต๊ะ</span><strong>{table.label}</strong><span class="table-occupancy">{table.capacity}<small> seats</small></span>
        </a>
        <div :if={@tables == []} class="map-empty">
          Your celebration starts here.<br />Create a group, then add your first table.
        </div>
        <div class="venue-buffet">
          <.icon name="hero-cake" class="size-4" /> Buffet · บุฟเฟต์
        </div>
        <div class="venue-drinks">Drinks · เครื่องดื่ม</div>
        <div class="venue-entrance">
          <.icon name="hero-arrow-right" class="size-4 shrink-0" />
          <span>GATE / ทางเข้า</span>
        </div>
        <div class="venue-entrance right">
          <span>GATE / ทางเข้า</span>
          <.icon name="hero-arrow-left" class="size-4 shrink-0" />
        </div>
      </div>
    </div>
    <div class="map-legend">
      <span :for={group <- @groups}>
        <i style={"background: #{group.color}"}></i><b>{Enum.filter(@tables, &Seating.in_group?(&1, group.id)) |> Enum.map_join(", ", & &1.label)}</b> {group.name}
      </span>
    </div>
    <div class="map-key">
      <span><i></i>Choose any seat within your group</span><span>Based on your venue draft · not to scale</span>
    </div>
    """
  end

  def group_names(table), do: Enum.map_join(table.groups, " + ", & &1.name)

  def table_colors(table) do
    colors = Enum.map(table.groups, & &1.color)
    first = List.first(colors) || "#8fa9c2"

    "--group-color: #{first};"
  end

  def table_style(table) do
    size =
      if table.shape == "long",
        do:
          "height: #{table.capacity * 1.0}%; top: #{Enum.at([26, 51, 79], div(table.slot - 1, 4)) + (table.capacity - 20) / 2}%;",
        else: ""

    position(table.slot) <> size
  end

  def position(2), do: "left: 22%; top: 26%;"
  def position(3), do: "left: 78%; top: 26%;"

  def position(slot) do
    column = Enum.at([13, 32, 68, 87], rem(slot - 1, 4))
    row = Enum.at([26, 51, 79], div(slot - 1, 4))
    "left: #{column}%; top: #{row}%;"
  end

  def chair_style(index, capacity, "round") do
    angle = 2 * :math.pi() * index / capacity
    "left: #{50 + 63 * :math.cos(angle)}%; top: #{50 + 63 * :math.sin(angle)}%;"
  end

  def chair_style(index, capacity, _) do
    side = if rem(index, 2) == 0, do: -15, else: 115
    "left: #{side}%; top: #{(div(index, 2) + 0.5) / Float.ceil(capacity / 2) * 100}%;"
  end
end
