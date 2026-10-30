defmodule NekoWeb.Admin.SeatingController do
  use NekoWeb, :controller
  alias Neko.Seating
  alias Neko.Seating.{Group, Table}

  def index(conn, params), do: render_plan(conn, params)

  def export(conn, _params) do
    conn
    |> put_resp_header("cache-control", "private, no-store")
    |> send_download({:binary, Jason.encode!(Seating.export_layout(), pretty: true)},
      filename: "seating-backup-#{Date.utc_today()}.json",
      content_type: "application/json"
    )
  end

  def apply_layout(conn, %{"import" => %{"confirmed" => "true", "revision" => revision}}) do
    layout = Seating.saved_layout()

    result =
      if revision == Seating.layout_revision(layout),
        do: Seating.replace_layout(layout),
        else: {:error, :stale_layout}

    case result do
      {:ok, :replaced} ->
        conn
        |> put_flash(:info, "Saved seating plan applied. RSVPs and website visibility were kept.")
        |> redirect(to: ~p"/admin/seating")

      {:error, reason} ->
        message =
          if reason == :stale_layout,
            do: "The saved plan changed. Review it again before replacing seating.",
            else: "The saved plan could not be applied. Your current seating was kept."

        conn |> put_flash(:error, message) |> redirect(to: ~p"/admin/seating")
    end
  end

  def apply_layout(conn, _params),
    do: conn |> put_status(:bad_request) |> text("Confirm seating replacement first.")

  def visibility(conn, %{"visibility" => %{"public_enabled" => _} = attrs}) do
    case Seating.update_visibility(attrs) do
      {:ok, settings} ->
        message =
          if settings.public_enabled,
            do: "Seating guide is now visible on the main website.",
            else: "Seating guide is hidden from the main website. You can keep editing here."

        conn |> put_flash(:info, message) |> redirect(to: ~p"/admin/seating")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_plan(%{},
          visibility_form: Phoenix.Component.to_form(changeset, as: :visibility)
        )
    end
  end

  def visibility(conn, _params),
    do: conn |> put_status(:bad_request) |> text("A visibility setting is required")

  def save_group(conn, %{"group" => attrs} = params) do
    group = if params["id"], do: Seating.get_group!(params["id"]), else: %Group{}

    case Seating.save_group(group, attrs) do
      {:ok, _} ->
        conn
        |> put_flash(:info, "Guest group saved.")
        |> redirect(to: ~p"/admin/seating?tab=groups" <> "#seating-workspace")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_plan(%{"tab" => "groups"},
          group_form: Phoenix.Component.to_form(changeset),
          editing_group: group.id
        )
    end
  end

  def save_table(conn, %{"table" => attrs} = params) do
    table = if params["id"], do: Seating.get_table!(params["id"]), else: %Table{}

    case Seating.save_table(table, attrs) do
      {:ok, saved} ->
        conn
        |> put_flash(:info, "Table saved.")
        |> redirect(to: ~p"/admin/seating?table=#{saved.id}" <> "#table-editor")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_plan(%{}, table_form: Phoenix.Component.to_form(changeset), selected: table)
    end
  end

  def delete_table(conn, %{"id" => id}),
    do: finish(conn, Seating.delete_table(id), "Table removed.", ~p"/admin/seating")

  def delete_group(conn, %{"id" => id}),
    do:
      finish(
        conn,
        Seating.delete_group(id),
        "Group removed.",
        ~p"/admin/seating?tab=groups" <> "#seating-workspace"
      )

  defp finish(conn, {:ok, _}, message, path),
    do: conn |> put_flash(:info, message) |> redirect(to: path)

  defp finish(conn, {:error, reason}, _message, path) do
    message =
      if is_binary(reason),
        do: reason,
        else: "This group still has tables. Move them to another group first."

    conn |> put_flash(:error, message) |> redirect(to: path)
  end

  defp render_plan(conn, params, overrides \\ []) do
    tables = Seating.tables()
    groups = Seating.groups()
    selected = if params["table"], do: Seating.get_table!(params["table"]), else: nil
    group = if params["group"], do: Seating.get_group!(params["group"]), else: %Group{}

    saved_layout = Seating.saved_layout()
    saved_groups = Map.new(saved_layout["groups"], &{&1["code"], &1["name"]})

    assigns = [
      saved_layout: saved_layout,
      saved_groups: saved_groups,
      saved_capacity: Enum.sum(Enum.map(saved_layout["tables"], & &1["capacity"])),
      import_form:
        Phoenix.Component.to_form(
          %{"confirmed" => false, "revision" => Seating.layout_revision(saved_layout)},
          as: :import
        ),
      page_title: "Seating Studio · Bee & Boom",
      public_enabled: Seating.public_enabled?(),
      visibility_form:
        Phoenix.Component.to_form(
          Neko.Seating.Settings.changeset(Seating.visibility_settings(), %{}),
          as: :visibility
        ),
      tab: if(params["tab"] == "groups", do: "groups", else: "map"),
      tables: tables,
      group_plans: Seating.group_plans(groups, tables),
      estimated_guests: Enum.sum(Enum.map(groups, &(&1.expected_guests || 0))),
      estimated_groups: Enum.count(groups, &(not is_nil(&1.expected_guests))),
      groups: groups,
      selected: selected,
      editing_group: group.id,
      group_form: Phoenix.Component.to_form(Group.changeset(group, %{})),
      table_form: Phoenix.Component.to_form(Table.changeset(selected || %Table{}, %{})),
      capacity: Enum.sum(Enum.map(tables, & &1.capacity))
    ]

    render(conn, :index, Keyword.merge(assigns, overrides))
  end
end
