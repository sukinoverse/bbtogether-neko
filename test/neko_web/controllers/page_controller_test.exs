defmodule NekoWeb.PageControllerTest do
  use NekoWeb.ConnCase

  alias Neko.{Repo, Rsvp}

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    for section <-
          ~w(wedding-hero wedding-invitation wedding-story wedding-schedule wedding-venue wedding-rsvp wedding-seating wedding-theme wedding-guestbook) do
      assert document |> LazyHTML.query("##{section}") |> Enum.count() == 1
    end

    assert document |> LazyHTML.query("#wedding-story-photos [data-photo-slide]") |> Enum.count() ==
             31

    assert document |> LazyHTML.query("#wedding-story-photos img") |> Enum.count() == 31

    assert document
           |> LazyHTML.query(
             ~s(#wedding-story-photos img[src="/images/bee-boom-under-the-trees.webp"])
           )
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query(
             ~s(#wedding-story-photos img[src="/images/bee-boom-pine-forest.webp"])
           )
           |> Enum.count() == 1

    assert document
           |> LazyHTML.query(~s(#wedding-story-photos img[src="/images/bee-boom-shore-run.webp"]))
           |> Enum.count() == 1

    assert document |> LazyHTML.query("#wedding-story-autoplay") |> Enum.count() == 1
    assert document |> LazyHTML.query("#wedding-hero[data-wedding-welcome]") |> Enum.count() == 1
    assert document |> LazyHTML.query("[data-invitation-card]") |> Enum.count() == 1

    assert document |> LazyHTML.query("#wedding-music-player") |> Enum.count() == 1
    assert document |> LazyHTML.query("#wedding-music-toggle") |> Enum.count() == 1
    assert document |> LazyHTML.query("#wedding-music[autoplay][loop]") |> Enum.count() == 1

    for status <- ~w(wedding-seating-status wedding-guestbook-status) do
      assert document
             |> LazyHTML.query("##{status}")
             |> LazyHTML.text()
             |> String.contains?("Coming Soon")
    end

    assert document
           |> LazyHTML.query("#wedding-invitation")
           |> LazyHTML.attribute("aria-labelledby") == ["wedding-invitation-title"]

    assert document |> LazyHTML.query("#wedding-invitation-title") |> Enum.count() == 1

    assert document
           |> LazyHTML.query("#wedding-date")
           |> LazyHTML.text()
           |> String.contains?("01 · 11 · 2026")

    assert document
           |> LazyHTML.query("#wedding-invitation")
           |> LazyHTML.text()
           |> String.contains?("Passaraporn")

    assert document
           |> LazyHTML.query("#wedding-invitation")
           |> LazyHTML.text()
           |> String.contains?("Pongsatorn")

    assert document |> LazyHTML.query("[data-schedule-item]") |> Enum.count() == 5

    assert document
           |> LazyHTML.query("#wedding-venue img")
           |> LazyHTML.attribute("src") == ["/images/misstar-garden-chapel.jpg"]

    assert document
           |> LazyHTML.query("#wedding-countdown")
           |> LazyHTML.attribute("data-countdown") == ["2026-11-01T15:09:00+07:00"]

    background = LazyHTML.query(document, "#wedding-background")

    assert LazyHTML.attribute(background, "src") == ["/images/wedding-meadow.jpg"]

    assert background
           |> LazyHTML.attribute("class")
           |> List.first()
           |> String.contains?(
             "object-left sm:portrait:object-[18%_center] landscape:object-[42%_center]"
           )

    assert document
           |> LazyHTML.query(~s(meta[property="og:image"]))
           |> LazyHTML.attribute("content")
           |> List.first()
           |> String.ends_with?("/images/bee-boom-og-v2.jpg")

    assert document
           |> LazyHTML.query(~s(meta[property="og:title"]))
           |> LazyHTML.attribute("content") == ["Bee & Boom — Our Wedding"]

    assert document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim() ==
             "Bee & Boom — Our Wedding"

    assert document
           |> LazyHTML.query(~s(meta[property="og:image:width"]))
           |> LazyHTML.attribute("content") == ["1200"]

    assert document
           |> LazyHTML.query(~s(meta[property="og:image:height"]))
           |> LazyHTML.attribute("content") == ["630"]

    assert document
           |> LazyHTML.query(~s(meta[name="twitter:card"]))
           |> LazyHTML.attribute("content") == ["summary_large_image"]

    assert document
           |> LazyHTML.query(~s(meta[name="twitter:image"]))
           |> LazyHTML.attribute("content")
           |> List.first()
           |> String.ends_with?("/images/bee-boom-og-v2.jpg")

    assert document
           |> LazyHTML.query(~s(link[rel="icon"][type="image/svg+xml"]))
           |> LazyHTML.attribute("href") == ["/images/favicon.svg"]

    assert document
           |> LazyHTML.query(~s(link[rel="apple-touch-icon"]))
           |> LazyHTML.attribute("href") == ["/images/apple-touch-icon.png"]

    assert document |> LazyHTML.query("#wedding-rsvp-form") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-name") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-phone") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-attending") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-party-size") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-lookup-form") |> Enum.count() == 1

    assert document
           |> LazyHTML.query("#rsvp-lookup-form")
           |> LazyHTML.attribute("action") == ["/rsvp/check#wedding-rsvp"]

    assert document |> LazyHTML.query("#rsvp-invite-token") |> Enum.empty?()
    assert document |> LazyHTML.query("#personalized-invitation-greeting") |> Enum.empty?()
  end

  test "POST /rsvp saves the total party size and shows a detailed confirmation", %{conn: conn} do
    conn =
      post(conn, ~p"/rsvp", %{
        "rsvp" => %{
          "name" => "  สมชาย ใจดี  ",
          "phone" => "+66 81 234 5678",
          "attending" => "true",
          "party_size" => "5"
        }
      })

    assert redirected_to(conn) == "/#wedding-rsvp"

    assert %Rsvp{
             name: "สมชาย ใจดี",
             phone: "0812345678",
             attending: true,
             party_size: 5
           } = rsvp = Repo.one(Rsvp)

    assert get_session(conn, :rsvp_id) == rsvp.id

    document = conn |> recycle() |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#rsvp-success") |> LazyHTML.text() =~ "รวม 5 ท่าน"
    assert document |> LazyHTML.query("#rsvp-success") |> LazyHTML.text() =~ "••• ••• 5678"
    assert document |> LazyHTML.query("#wedding-rsvp-form") |> Enum.empty?()
  end

  test "POST /rsvp clears party size when the guest cannot attend", %{conn: conn} do
    conn =
      post(conn, ~p"/rsvp", %{
        "rsvp" => %{
          "name" => "สมหญิง ใจดี",
          "phone" => "089-123-4567",
          "attending" => "false",
          "party_size" => "8"
        }
      })

    assert redirected_to(conn) == "/#wedding-rsvp"
    assert %Rsvp{attending: false, party_size: 0} = Repo.one(Rsvp)
  end

  test "POST /rsvp/check retrieves a response by normalized phone number", %{conn: conn} do
    rsvp =
      Repo.insert!(%Rsvp{
        name: "Beam",
        phone: "0812345678",
        attending: true,
        party_size: 3
      })

    conn = post(conn, ~p"/rsvp/check", %{"lookup" => %{"phone" => "+66 81 234 5678"}})

    assert redirected_to(conn) == "/#wedding-rsvp"
    assert get_session(conn, :rsvp_id) == rsvp.id
  end

  test "POST /rsvp/check keeps the lookup open when no response is found", %{conn: conn} do
    document =
      conn
      |> post(~p"/rsvp/check", %{"lookup" => %{"phone" => "0800000000"}})
      |> html_response(404)
      |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#rsvp-lookup[open]") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-lookup-error") |> Enum.count() == 1
  end

  test "POST /rsvp rejects a duplicate phone number", %{conn: conn} do
    Repo.insert!(%Rsvp{
      name: "Beam",
      phone: "0812345678",
      attending: true,
      party_size: 2
    })

    conn =
      post(conn, ~p"/rsvp", %{
        "rsvp" => %{
          "name" => "Another Beam",
          "phone" => "081-234-5678",
          "attending" => "true",
          "party_size" => "4"
        }
      })

    assert html_response(conn, 422) =~ "เบอร์นี้ส่งคำตอบแล้ว"
    assert Repo.aggregate(Rsvp, :count) == 1
  end

  test "POST /rsvp returns the form with errors when required answers are missing", %{conn: conn} do
    conn = post(conn, ~p"/rsvp", %{"rsvp" => %{"name" => "", "phone" => "bad"}})

    assert html_response(conn, 422) =~ "wedding-rsvp-form"
    assert Repo.aggregate(Rsvp, :count) == 0
  end

  test "POST /rsvp handles malformed form submissions", %{conn: conn} do
    conn = post(conn, ~p"/rsvp", %{})

    assert html_response(conn, 422) =~ "wedding-rsvp-form"
    assert Repo.aggregate(Rsvp, :count) == 0
  end
end
