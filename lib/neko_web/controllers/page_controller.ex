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
        |> put_session(:rsvp_id, rsvp.id)
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

    rsvp_response =
      case get_session(conn, :rsvp_id) do
        nil -> nil
        id -> Repo.get(Rsvp, id)
      end

    render(conn, :home,
      page_title: "Bee & Boom — Our Wedding",
      events: events,
      theme_colors: theme_colors,
      party_size_options: Enum.map(1..10, &{"#{&1} ท่าน", &1}),
      rsvp_form: Phoenix.Component.to_form(rsvp_changeset),
      show_party_size?: Ecto.Changeset.get_field(rsvp_changeset, :attending) == true,
      rsvp_response: rsvp_response
    )
  end
end
