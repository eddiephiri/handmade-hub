defmodule HandmadeHub.Shopping do
  @moduledoc """
  The Shopping context handles cart operations.
  """

  import Ecto.Query, warn: false
  alias HandmadeHub.Repo
  alias HandmadeHub.Shopping.{Cart, CartItem}
  alias HandmadeHub.Catalog

  @doc """
  Gets or creates a cart for a user or session.
  """
  def get_or_create_cart(user_id, session_id) do
    cart =
      if user_id do
        # For authenticated users, find by user_id
        Repo.one(from c in Cart, where: c.user_id == ^user_id and c.status == "active")
      else
        # For guests, find by session_id
        Repo.one(from c in Cart, where: c.session_id == ^session_id and c.status == "active")
      end

    case cart do
      nil -> create_cart(user_id, session_id)
      cart -> {:ok, cart}
    end
  end

  @doc """
  Creates a new cart.
  """
  def create_cart(user_id, session_id) do
    %Cart{}
    |> Cart.changeset(%{
      user_id: user_id,
      session_id: session_id,
      status: "active"
    })
    |> Repo.insert()
  end

  @doc """
  Gets a cart with its items and products.
  """
  def get_cart_with_items(cart_id) do
    Cart
    |> where([c], c.id == ^cart_id)
    |> preload([cart_items: [:product]])
    |> Repo.one()
  end

  @doc """
  Adds a product to the cart.
  """
  def add_to_cart(cart_id, product_id, quantity \\ 1) do
    product = Catalog.get_product!(product_id)

    # Check if product is in stock
    if product.quantity < quantity do
      {:error, :insufficient_stock}
    else
      # Check if item already exists in cart
      existing_item = Repo.one(
        from ci in CartItem,
        where: ci.cart_id == ^cart_id and ci.product_id == ^product_id
      )

      case existing_item do
        nil ->
          # Create new cart item
          %CartItem{}
          |> CartItem.changeset(%{
            cart_id: cart_id,
            product_id: product_id,
            quantity: quantity,
            price: product.price
          })
          |> Repo.insert()

        item ->
          # Update existing cart item quantity
          new_quantity = item.quantity + quantity
          if product.quantity < new_quantity do
            {:error, :insufficient_stock}
          else
            update_cart_item_quantity(item.id, new_quantity)
          end
      end
    end
  end

  @doc """
  Updates the quantity of a cart item.
  """
  def update_cart_item_quantity(cart_item_id, quantity) when quantity > 0 do
    cart_item = Repo.get!(CartItem, cart_item_id)
    product = Catalog.get_product!(cart_item.product_id)

    if product.quantity < quantity do
      {:error, :insufficient_stock}
    else
      cart_item
      |> CartItem.changeset(%{quantity: quantity})
      |> Repo.update()
    end
  end

  def update_cart_item_quantity(cart_item_id, 0) do
    remove_from_cart(cart_item_id)
  end

  @doc """
  Removes an item from the cart.
  """
  def remove_from_cart(cart_item_id) do
    cart_item = Repo.get!(CartItem, cart_item_id)
    Repo.delete(cart_item)
  end

  @doc """
  Clears all items from a cart.
  """
  def clear_cart(cart_id) do
    from(ci in CartItem, where: ci.cart_id == ^cart_id)
    |> Repo.delete_all()
  end

  @doc """
  Gets the total number of items in a cart.
  """
  def get_cart_item_count(nil), do: 0
  def get_cart_item_count(cart_id) do
    from(ci in CartItem, where: ci.cart_id == ^cart_id, select: sum(ci.quantity))
    |> Repo.one() || 0
  end

  @doc """
  Calculates the cart total.
  """
  def calculate_cart_total(cart_id) do
    cart = get_cart_with_items(cart_id)

    if cart && cart.cart_items do
      cart.cart_items
      |> Enum.reduce(Decimal.new(0), fn item, acc ->
        item_total = Decimal.mult(item.price, Decimal.new(item.quantity))
        Decimal.add(acc, item_total)
      end)
    else
      Decimal.new(0)
    end
  end

  @doc """
  Merges a guest cart with a user cart when user logs in.
  """
  def merge_carts(guest_cart_id, user_id) do
    guest_cart = get_cart_with_items(guest_cart_id)

    if guest_cart && guest_cart.cart_items && length(guest_cart.cart_items) > 0 do
      # Get or create user cart
      {:ok, user_cart} = get_or_create_cart(user_id, nil)

      # Move items from guest cart to user cart
      Enum.each(guest_cart.cart_items, fn item ->
        add_to_cart(user_cart.id, item.product_id, item.quantity)
      end)

      # Mark guest cart as abandoned
      guest_cart
      |> Cart.changeset(%{status: "abandoned"})
      |> Repo.update()
    end
  end

  @doc """
  Converts a cart to an order (marks it as converted).
  """
  def convert_cart_to_order(cart_id) do
    cart = Repo.get!(Cart, cart_id)

    cart
    |> Cart.changeset(%{status: "converted"})
    |> Repo.update()
  end

  @doc """
  Lists all cart items for a cart.
  """
  def list_cart_items(cart_id) do
    CartItem
    |> where([ci], ci.cart_id == ^cart_id)
    |> preload([:product])
    |> Repo.all()
  end

  @doc """
  Gets a single cart item by cart and product.
  """
  def get_cart_item_by_cart_and_product(cart_id, product_id) do
    CartItem
    |> where([ci], ci.cart_id == ^cart_id and ci.product_id == ^product_id)
    |> Repo.one()
  end

  @doc """
  Checks if a product is in cart.
  """
  def product_in_cart?(nil, _product_id), do: false
  def product_in_cart?(cart_id, product_id) do
    Repo.exists?(
      from ci in CartItem,
      where: ci.cart_id == ^cart_id and ci.product_id == ^product_id
    )
  end
end
