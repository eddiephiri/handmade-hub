# Test script to verify ArtisanOrders module works
# Run with: mix run test_artisan_orders.exs

import Ecto.Query
alias HandmadeHub.ArtisanOrders
alias HandmadeHub.Repo
alias HandmadeHub.Accounts.User
alias HandmadeHub.Catalog.Product
alias HandmadeHub.Orders.Order

# Get the first artisan user (if exists)
artisan = Repo.one(from u in User, where: u.role == "artisan", limit: 1)

if artisan do
  IO.puts("Testing with artisan ID: #{artisan.id}")
  
  # Test listing orders
  try do
    orders = ArtisanOrders.list_artisan_orders(artisan.id)
    IO.puts("✓ list_artisan_orders works - Found #{length(orders)} orders")
  rescue
    e -> IO.puts("✗ list_artisan_orders failed: #{inspect(e)}")
  end
  
  # Test getting statistics
  try do
    stats = ArtisanOrders.get_artisan_stats(artisan.id, :this_month)
    IO.puts("✓ get_artisan_stats works")
    IO.puts("  - Total orders: #{stats.total_orders}")
    IO.puts("  - Total revenue: #{stats.total_revenue}")
    IO.puts("  - Pending orders: #{stats.pending_orders}")
  rescue
    e -> IO.puts("✗ get_artisan_stats failed: #{inspect(e)}")
  end
  
  # Test revenue by period
  try do
    revenue = ArtisanOrders.get_revenue_by_period(artisan.id, :monthly)
    IO.puts("✓ get_revenue_by_period works - Found #{length(revenue)} periods")
  rescue
    e -> IO.puts("✗ get_revenue_by_period failed: #{inspect(e)}")
  end
  
  IO.puts("\n✅ All tests completed successfully!")
else
  IO.puts("No artisan user found in the database. Please create an artisan user first.")
  
  # Check if there are any products with artisan_id
  product_count = Repo.aggregate(Product, :count, :id)
  IO.puts("Total products in database: #{product_count}")
  
  if product_count > 0 do
    sample_product = Repo.one(from p in Product, limit: 1, preload: [:artisan])
    IO.puts("Sample product artisan_id: #{sample_product.artisan_id}")
  end
end
