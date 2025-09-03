# Test script for ArtisanOrders module
# Run with: mix run test_artisan_orders_v2.exs

import Ecto.Query
alias HandmadeHub.Repo
alias HandmadeHub.ArtisanOrders
alias HandmadeHub.Accounts.User

# Find an artisan user for testing
artisan = Repo.one(from u in User, where: u.role == "artisan", limit: 1)

if artisan do
  IO.puts("Testing with artisan ID: #{artisan.id}")
  artisan_id = artisan.id
  
  IO.puts("\n=== Testing ArtisanOrders Functions ===\n")
  
  # Test 1: list_artisan_orders
  IO.puts("1. Testing list_artisan_orders...")
  try do
    orders = ArtisanOrders.list_artisan_orders(artisan_id)
    IO.puts("   ✓ Success - Found #{length(orders)} orders")
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 2: get_artisan_stats (without date filter)
  IO.puts("\n2. Testing get_artisan_stats (all time)...")
  try do
    stats = ArtisanOrders.get_artisan_stats(artisan_id)
    IO.puts("   ✓ Success")
    IO.puts("     - Total orders: #{stats.total_orders}")
    IO.puts("     - Total revenue: #{stats.total_revenue}")
    IO.puts("     - Pending orders: #{stats.pending_orders}")
    IO.puts("     - Items sold: #{stats.items_sold}")
    IO.puts("     - Best sellers count: #{length(stats.best_sellers)}")
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 3: get_artisan_stats (with date filter)
  IO.puts("\n3. Testing get_artisan_stats (today)...")
  try do
    stats = ArtisanOrders.get_artisan_stats(artisan_id, :today)
    IO.puts("   ✓ Success")
    IO.puts("     - Today's orders: #{stats.total_orders}")
    IO.puts("     - Today's revenue: #{stats.total_revenue}")
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 4: get_artisan_stats (this month)
  IO.puts("\n4. Testing get_artisan_stats (this month)...")
  try do
    stats = ArtisanOrders.get_artisan_stats(artisan_id, :this_month)
    IO.puts("   ✓ Success")
    IO.puts("     - This month's orders: #{stats.total_orders}")
    IO.puts("     - This month's revenue: #{stats.total_revenue}")
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 5: get_revenue_by_period (monthly)
  IO.puts("\n5. Testing get_revenue_by_period (monthly)...")
  try do
    revenue_data = ArtisanOrders.get_revenue_by_period(artisan_id, :monthly)
    IO.puts("   ✓ Success - Found #{length(revenue_data)} monthly periods")
    if length(revenue_data) > 0 do
      first = List.first(revenue_data)
      IO.puts("     Sample: Year #{trunc(first.year)}, Month #{trunc(first.month)}, Revenue: #{first.revenue || 0}")
    end
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 6: get_revenue_by_period (weekly)
  IO.puts("\n6. Testing get_revenue_by_period (weekly)...")
  try do
    revenue_data = ArtisanOrders.get_revenue_by_period(artisan_id, :weekly)
    IO.puts("   ✓ Success - Found #{length(revenue_data)} weekly periods")
    if length(revenue_data) > 0 do
      first = List.first(revenue_data)
      IO.puts("     Sample: Year #{trunc(first.year)}, Week #{trunc(first.week)}, Revenue: #{first.revenue || 0}")
    end
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 7: get_revenue_by_period (daily)
  IO.puts("\n7. Testing get_revenue_by_period (daily)...")
  try do
    revenue_data = ArtisanOrders.get_revenue_by_period(artisan_id, :daily)
    IO.puts("   ✓ Success - Found #{length(revenue_data)} daily periods")
    if length(revenue_data) > 0 do
      first = List.first(revenue_data)
      IO.puts("     Sample date: #{first.date}, Revenue: #{first.revenue || 0}")
    end
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  # Test 8: list_artisan_orders with filters
  IO.puts("\n8. Testing list_artisan_orders with filters...")
  try do
    filters = %{status: "pending", payment_status: "paid"}
    orders = ArtisanOrders.list_artisan_orders(artisan_id, filters)
    IO.puts("   ✓ Success - Found #{length(orders)} filtered orders")
  rescue
    e -> 
      IO.puts("   ✗ Failed: #{Exception.message(e)}")
      IO.inspect(e, label: "   Error details")
  end
  
  IO.puts("\n=== Testing Complete ===")
else
  IO.puts("No artisan user found in database. Please create an artisan user first.")
end
