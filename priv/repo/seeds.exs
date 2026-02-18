# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     Spotlight.Repo.insert!(%Spotlight.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias Spotlight.Productions

# --- "Unlikely Heroes" (upcoming) ---
{:ok, unlikely_heroes} =
  Productions.create_production(%{
    "title" => "Unlikely Heroes",
    "description" => "A hilarious winter adventure perfect for the whole family!",
    "location_name" => "The Corner Theater",
    "location_query" => "280 W Muskegon Ave, Muskegon, MI",
    "price" => "FREE",
    "status" => "published"
  })

for {starts_at, notes} <- [
      {~U[2026-03-07 00:00:00Z], "Friday Evening"},
      {~U[2026-03-08 19:00:00Z], "Saturday Matinee"}
    ] do
  Productions.create_performance(unlikely_heroes, %{
    "starts_at" => starts_at,
    "notes" => notes
  })
end

# --- "A Whole Other Story" (past) ---
{:ok, whole_other_story} =
  Productions.create_production(%{
    "title" => "A Whole Other Story",
    "description" => "Our festive Christmas production celebrating the season.",
    "location_name" => "The Corner Theater",
    "location_query" => "280 W Muskegon Ave, Muskegon, MI",
    "price" => "FREE",
    "status" => "published"
  })

for {starts_at, notes} <- [
      {~U[2025-12-13 00:00:00Z], "Friday Evening"},
      {~U[2025-12-13 19:00:00Z], "Saturday Matinee"},
      {~U[2025-12-14 00:00:00Z], "Saturday Evening"}
    ] do
  Productions.create_performance(whole_other_story, %{
    "starts_at" => starts_at,
    "notes" => notes
  })
end

for {url, caption} <- [
      {"/images/play-photos/yw1.jpg", "Scene from A Whole Other Story"},
      {"/images/play-photos/yw2.jpg", "Scene from A Whole Other Story"},
      {"/images/play-photos/yw3.jpg", "Scene from A Whole Other Story"},
      {"/images/play-photos/herod.jpg", "King Herod"},
      {"/images/play-photos/crowd.jpg", "Audience"},
      {"/images/play-photos/teens.jpg", "Cast members"}
    ] do
  Productions.create_production_photo(whole_other_story, %{
    "url" => url,
    "caption" => caption
  })
end

IO.puts("Seeds complete!")
IO.puts("  - Unlikely Heroes (upcoming, 2 performances)")
IO.puts("  - A Whole Other Story (past, 3 performances, 6 photos)")
