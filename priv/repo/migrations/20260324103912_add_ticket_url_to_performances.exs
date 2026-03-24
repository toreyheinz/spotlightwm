defmodule Spotlight.Repo.Migrations.AddTicketUrlToPerformances do
  use Ecto.Migration

  def change do
    alter table(:performances) do
      add :ticket_url, :string
    end
  end
end
