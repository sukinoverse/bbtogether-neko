defmodule NekoWeb.PageController do
  use NekoWeb, :controller

  alias Neko.{Repo, Rsvp}

  def home(conn, _params) do
    render_home(conn, Rsvp.changeset(%Rsvp{}, %{}))
  end

  def rsvp(conn, %{"rsvp" => params}) do
    case %Rsvp{} |> Rsvp.changeset(params) |> Repo.insert() do
      {:ok, rsvp} ->
        conn
        |> put_flash(:rsvp_status, rsvp_status(rsvp))
        |> redirect(to: ~p"/#wedding-rsvp")

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> render_home(changeset)
    end
  end

  def rsvp(conn, _params) do
    conn
    |> put_status(:unprocessable_entity)
    |> render_home(Rsvp.changeset(%Rsvp{}, %{}))
  end

  defp rsvp_status(%Rsvp{attending: false}), do: "declined"
  defp rsvp_status(%Rsvp{bringing_partner: true}), do: "attending_with_partner"
  defp rsvp_status(%Rsvp{}), do: "attending"

  defp render_home(conn, rsvp_changeset) do
    events = [
      %{
        time: "15.09",
        title: "พิธีขันหมาก",
        sub: "Khan Mak Procession",
        icon: "hero-gift",
        color: "#8fae83"
      },
      %{
        time: "15.30",
        title: "พิธีหมั้น",
        sub: "Engagement Ceremony",
        icon: "hero-heart",
        color: "#f0aebf"
      },
      %{
        time: "16.00",
        title: "พิธีรับไหว้",
        sub: "Thai Blessing Ceremony",
        icon: "hero-users",
        color: "#8fa9c2"
      },
      %{
        time: "17.00",
        title: "พิธีปฏิญาณรัก",
        sub: "Vow Ceremony",
        icon: "hero-sparkles",
        color: "#b59ed5"
      },
      %{
        time: "18.30",
        title: "รับประทานอาหาร",
        sub: "Buffet Dinner",
        icon: "hero-cake",
        color: "#e0a876"
      }
    ]

    theme_colors = ~w(#8fa9c2 #a9cbe8 #63a092 #8fae83 #c3bfe0 #f2c3a6 #f0aebf #d5a8de #f3d56f)

    render(conn, :home,
      page_title: "Bee & Boom — Our Wedding",
      events: events,
      theme_colors: theme_colors,
      rsvp_form: Phoenix.Component.to_form(rsvp_changeset),
      show_partner?: Ecto.Changeset.get_field(rsvp_changeset, :attending) == true,
      rsvp_status: Phoenix.Flash.get(conn.assigns.flash, :rsvp_status)
    )
  end
end
