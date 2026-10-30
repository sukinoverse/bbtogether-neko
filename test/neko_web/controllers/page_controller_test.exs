defmodule NekoWeb.PageControllerTest do
  use NekoWeb.ConnCase

  alias Neko.{Repo, Rsvp}

  test "public map shows table groups with no admin controls or guest data", %{conn: conn} do
    {:ok, _} = Neko.Seating.update_visibility(%{public_enabled: true})

    {:ok, group} =
      Neko.Seating.save_group(%Neko.Seating.Group{}, %{
        code: "A",
        name: "Friends",
        color: "#aabbcc",
        expected_guests: 123
      })

    {:ok, table} =
      Neko.Seating.save_table(%Neko.Seating.Table{}, %{
        label: "B",
        slot: 2,
        capacity: 10,
        shape: "round",
        group_ids: [group.id]
      })

    Repo.insert!(%Rsvp{name: "Private RSVP", phone: "0812345678", attending: true, party_size: 2})
    doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert doc |> LazyHTML.query("#public-seating-plan") |> Enum.count() == 1

    assert doc |> LazyHTML.query("#find-seating") |> LazyHTML.attribute("href") == [
             "#wedding-seating"
           ]

    assert doc |> LazyHTML.query("#guide-map-card[tabindex='-1']") |> Enum.count() == 1

    assert doc
           |> LazyHTML.query("#guest-map-table-#{table.id}")
           |> LazyHTML.attribute("data-group-ids") == [to_string(group.id)]

    assert doc |> LazyHTML.query("#public-group-#{group.id}") |> LazyHTML.text() =~ "Friends"
    assert doc |> LazyHTML.query("#public-group-#{group.id} strong") |> LazyHTML.text() == "B"

    assert doc
           |> LazyHTML.query(
             "#public-table-directory, #wedding-seating .venue-chair, #wedding-seating .table-occupancy"
           )
           |> Enum.count() == 0

    assert doc
           |> LazyHTML.query("#wedding-seating a[href^='/admin'], #table-form, #group-form")
           |> Enum.count() == 0

    refute doc |> LazyHTML.query("#wedding-seating") |> LazyHTML.text() =~ "Private RSVP"
    refute doc |> LazyHTML.query("#wedding-seating") |> LazyHTML.text() =~ "123"
  end

  test "revised layout renders nine tables, two gates, and refreshments", %{conn: conn} do
    layout = File.read!("priv/repo/venue_layout.json") |> Jason.decode!()
    assert {:ok, :initialized} = Neko.Seating.initialize_layout(layout)
    {:ok, _} = Neko.Seating.update_visibility(%{public_enabled: true})
    doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    assert doc |> LazyHTML.query("#guest-venue-map [data-guide-table]") |> Enum.count() == 9
    assert doc |> LazyHTML.query("#guest-venue-map .round") |> Enum.count() == 2
    assert doc |> LazyHTML.query("#guest-venue-map .guest-map-entrance") |> Enum.count() == 2
    assert doc |> LazyHTML.query("#guest-venue-map .guest-map-buffet") |> Enum.count() == 1
    assert doc |> LazyHTML.query("#guest-venue-map .guest-map-drinks") |> Enum.count() == 1

    short = doc |> LazyHTML.query("[data-guide-table='G']") |> LazyHTML.attribute("style") |> hd()
    long = doc |> LazyHTML.query("[data-guide-table='H']") |> LazyHTML.attribute("style") |> hd()
    assert short =~ "height: 10.0%"
    assert long =~ "height: 20.0%"
  end

  test "shared tables appear under both groups before any interaction", %{conn: conn} do
    {:ok, _} = Neko.Seating.update_visibility(%{public_enabled: true})

    {:ok, groom} =
      Neko.Seating.save_group(%Neko.Seating.Group{}, %{
        code: "G",
        name: "Groom friends",
        color: "#aabbcc"
      })

    {:ok, bride} =
      Neko.Seating.save_group(%Neko.Seating.Group{}, %{
        code: "B",
        name: "Bride friends",
        color: "#ccbbaa"
      })

    {:ok, table} =
      Neko.Seating.save_table(%Neko.Seating.Table{}, %{
        label: "C",
        slot: 3,
        capacity: 10,
        shape: "round",
        group_ids: [groom.id, bride.id]
      })

    doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()

    for group <- [groom, bride] do
      assert doc |> LazyHTML.query("#public-group-#{group.id} strong") |> LazyHTML.text() == "C"

      assert doc
             |> LazyHTML.query("#guest-map-table-#{table.id}")
             |> LazyHTML.attribute("data-group-ids")
             |> hd()
             |> String.split()
             |> Enum.member?(to_string(group.id))
    end
  end

  test "seating is hidden by default and follows persisted visibility", %{conn: conn} do
    {:ok, group} =
      Neko.Seating.save_group(%Neko.Seating.Group{}, %{
        code: "D",
        name: "Draft group",
        color: "#aabbcc"
      })

    {:ok, _} =
      Neko.Seating.save_table(%Neko.Seating.Table{}, %{
        label: "Z",
        slot: 1,
        shape: "long",
        capacity: 20,
        group_ids: [group.id]
      })

    doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert doc |> LazyHTML.query("#wedding-seating") |> Enum.empty?()
    refute LazyHTML.text(doc) =~ "Draft group"
    Neko.Seating.update_visibility(%{public_enabled: true})
    doc = conn |> recycle() |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert doc |> LazyHTML.query("#public-group-#{group.id}") |> Enum.count() == 1
    Neko.Seating.update_visibility(%{public_enabled: false})
    doc = conn |> recycle() |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
    assert doc |> LazyHTML.query("#wedding-seating") |> Enum.empty?()
    assert length(Neko.Seating.tables()) == 1
  end

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    html = html_response(conn, 200)
    document = LazyHTML.from_document(html)

    for section <-
          ~w(wedding-hero wedding-invitation wedding-story wedding-schedule wedding-venue wedding-rsvp wedding-theme wedding-guestbook) do
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

    for status <- ~w(wedding-guestbook-status) do
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
           |> String.ends_with?("/images/bee-boom-og-v3.jpg")

    assert document
           |> LazyHTML.query(~s(meta[name="robots"]))
           |> LazyHTML.attribute("content") == ["noindex, nofollow"]

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
           |> String.ends_with?("/images/bee-boom-og-v3.jpg")

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
    assert document |> LazyHTML.query("#rsvp-panel") |> Enum.count() == 1
    assert document |> LazyHTML.query("#rsvp-lookup-form") |> Enum.empty?()

    assert document
           |> LazyHTML.query("#rsvp-contact-note")
           |> LazyHTML.text() =~ "หากต้องการเช็กคำตอบ ติดต่อบีหรือบูมได้เลยนะ"

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

    assert document |> LazyHTML.query("#rsvp-reset") |> Enum.empty?()

    assert document
           |> LazyHTML.query("#rsvp-contact-note")
           |> LazyHTML.text() =~ "ติดต่อบีหรือบูม"

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

  test "removed phone lookup returns 404 even for a registered phone", %{conn: conn} do
    Repo.insert!(%Rsvp{
      name: "Beam",
      phone: "0812345678",
      attending: true,
      party_size: 3
    })

    conn = post(conn, "/rsvp/check", %{"lookup" => %{"phone" => "+66 81 234 5678"}})

    assert response(conn, 404)
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

    document = conn |> html_response(422) |> LazyHTML.from_document()

    assert document |> LazyHTML.query("#wedding-rsvp-form") |> LazyHTML.text() =~
             "เบอร์นี้ส่งคำตอบแล้ว หากต้องการเช็กคำตอบ ติดต่อบีหรือบูมได้เลยนะ"

    assert document |> LazyHTML.query("#rsvp-success") |> Enum.empty?()
    refute get_session(conn, :rsvp_id)
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
