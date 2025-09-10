# Test all date-related functions in ArtisanOrders
import Ecto.Query
alias HandmadeHub.Repo
alias HandmadeHub.ArtisanOrders
alias HandmadeHub.Accounts.User

artisan = Repo.one(from u in User, where: u.role == "artisan", limit: 1)

if artisan do
  artisan_id = artisan.id
  IO.puts("Testing date handling for artisan ID: #{artisan_id}\n")
  
  date_ranges = [:today, :this_week, :this_month, :last_30_days, :this_year, :all_time]
  
  for range <- date_ranges do
    IO.puts("Testing get_artisan_stats with range: #{inspect(range)}")
    try do
      stats = ArtisanOrders.get_artisan_stats(artisan_id, range)
      IO.puts("  ✓ Success - Orders: #{stats.total_orders}, Revenue: #{stats.total_revenue}")
    rescue
      e ->
        IO.puts("  ✗ FAILED!")
        IO.puts("    Error: #{Exception.message(e)}")
        if e.__struct__ == Ecto.Query.CastError do
          IO.puts("    Cast Error Details: #{e.message}")
        end
    end
  end
  
  IO.puts("\nTesting get_revenue_by_period with different periods:")
  
  periods = [:daily, :weekly, :monthly]
  for period <- periods do
    IO.puts("Testing period: #{inspect(period)}")
    try do
      data = ArtisanOrders.get_revenue_by_period(artisan_id, period)
      IO.puts("  ✓ Success - Found #{length(data)} records")
    rescue
      e ->
        IO.puts("  ✗ FAILED!")
        IO.puts("    Error: #{Exception.message(e)}")
        if e.__struct__ == Ecto.Query.CastError do
          IO.puts("    Cast Error Details: #{e.message}")
        end
    end
  end
  
  IO.puts("\nTesting list_artisan_orders with date filters:")
  
  # Test with Date objects (should fail if not converted properly)
  today = Date.utc_today()
  week_ago = Date.add(today, -7)
  
  filters_to_test = [
    %{start_date: DateTime.new!(week_ago, ~T[00:00:00], "Etc/UTC")},
    %{end_date: DateTime.new!(today, ~T[23:59:59], "Etc/UTC")},
    %{start_date: DateTime.new!(week_ago, ~T[00:00:00], "Etc/UTC"), 
      end_date: DateTime.new!(today, ~T[23:59:59], "Etc/UTC")}
  ]
  
  for filters <- filters_to_test do
    IO.puts("Testing with filters: #{inspect(Map.keys(filters))}")
    try do
      orders = ArtisanOrders.list_artisan_orders(artisan_id, filters)
      IO.puts("  ✓ Success - Found #{length(orders)} orders")
    rescue
      e ->
        IO.puts("  ✗ FAILED!")
        IO.puts("    Error: #{Exception.message(e)}")
        if e.__struct__ == Ecto.Query.CastError do
          IO.puts("    Cast Error Details: #{e.message}")
        end
    end
  end
  
  IO.puts("\n✅ Date handling test complete!")
else
  IO.puts("No artisan user found.")
end
