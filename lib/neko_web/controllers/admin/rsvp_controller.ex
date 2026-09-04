defmodule NekoWeb.Admin.RsvpController do
  use NekoWeb, :controller

  import Ecto.Query

  alias Neko.{Repo, Rsvp}

  def index(conn, _params) do
    rsvps = Repo.all(from rsvp in Rsvp, order_by: [desc: rsvp.inserted_at, desc: rsvp.id])
    attending = Enum.filter(rsvps, & &1.attending)

    render(conn, :index,
      page_title: "Guest Responses · Bee & Boom Admin",
      rsvps: rsvps,
      stats: %{
        responses: length(rsvps),
        attending: length(attending),
        additional_guests: Enum.sum(Enum.map(attending, &max(&1.party_size - 1, 0))),
        expected_guests: Enum.sum(Enum.map(attending, & &1.party_size))
      }
    )
  end
end
