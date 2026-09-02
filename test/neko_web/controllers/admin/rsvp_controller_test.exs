defmodule NekoWeb.Admin.RsvpControllerTest do
  use NekoWeb.ConnCase

  alias Neko.{Repo, Rsvp}

  test "GET /admin requires basic authentication", %{conn: conn} do
    conn = get(conn, ~p"/admin")

    assert response(conn, 401)
    assert get_resp_header(conn, "www-authenticate") == [~s(Basic realm="Bee and Boom Admin")]
  end

  test "GET /admin shows free-form guest responses and seating state", %{conn: conn} do
    attending =
      Repo.insert!(%Rsvp{name: "Beam", attending: true, bringing_partner: true})

    declined =
      Repo.insert!(%Rsvp{name: "Mint", attending: false, bringing_partner: false})

    conn = conn |> authenticate() |> get(~p"/admin")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#admin-rsvp-dashboard") |> Enum.count() == 1
    assert document |> LazyHTML.query("#guest-stat-responses") |> LazyHTML.text() =~ "2"
    assert document |> LazyHTML.query("#guest-stat-expected") |> LazyHTML.text() =~ "2"

    assert document |> LazyHTML.query("#guest-#{attending.id}") |> LazyHTML.text() =~
             "Attending +1"

    assert document |> LazyHTML.query("#guest-#{attending.id}") |> LazyHTML.text() =~
             "Not assigned"

    assert document |> LazyHTML.query("#guest-#{declined.id}") |> LazyHTML.text() =~
             "Not attending"
  end

  test "GET /admin/guests opens the same response dashboard", %{conn: conn} do
    conn = conn |> authenticate() |> get(~p"/admin/guests")
    document = conn |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#admin-rsvp-dashboard") |> Enum.count() == 1
  end

  defp authenticate(conn) do
    credentials = Base.encode64("admin:admin")
    put_req_header(conn, "authorization", "Basic " <> credentials)
  end
end
