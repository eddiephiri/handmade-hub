defmodule HandmadeHubWeb.Router do
  use HandmadeHubWeb, :router

  import HandmadeHubWeb.UserAuth
  import HandmadeHubWeb.AdminAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {HandmadeHubWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug HandmadeHubWeb.MaintenancePlug
    plug :fetch_current_user
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  # Admin pipelines (namespaced to avoid naming conflicts with imported plugs)
  pipeline :admin_fetch_current do
    plug :fetch_current_admin
  end

  pipeline :admin_redirect_if_authenticated do
    plug :redirect_if_admin_is_authenticated
  end

  pipeline :admin_require_authenticated do
    plug :require_authenticated_admin
  end

  scope "/", HandmadeHubWeb do
    pipe_through :browser

    get "/", PageController, :home

    # Public browsing routes (available to everyone)
    live_session :public_browsing,
      on_mount: [{HandmadeHubWeb.UserAuth, :mount_current_user}],
      layout: {HandmadeHubWeb.Layouts, :app} do
      live "/browse", BrowseLive.Index, :index
      live "/browse/:id", BrowseLive.Show, :show
      live "/artisans/:id", ArtisanProfileLive, :show
      live "/favorites", FavoritesLive, :index
      live "/cart", CartLive, :index
    end
  end

  # API routes for webhooks
  scope "/api", HandmadeHubWeb do
    pipe_through :api

    post "/pawapay/callback", PawapayWebhookController, :callback
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:handmade_hub, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: HandmadeHubWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  ## Authentication routes

  scope "/", HandmadeHubWeb do
    pipe_through [:browser, :redirect_if_user_is_authenticated]

    live_session :redirect_if_user_is_authenticated,
      on_mount: [{HandmadeHubWeb.UserAuth, :redirect_if_user_is_authenticated}],
      layout: {HandmadeHubWeb.Layouts, :auth} do
      live "/users/register", UserRegistrationLive, :new
      live "/users/log_in", UserLoginLive, :new
      live "/users/reset_password", UserForgotPasswordLive, :new
      live "/users/reset_password/:token", UserResetPasswordLive, :edit
    end

    post "/users/log_in", UserSessionController, :create
  end

  # Email confirmation routes (accessible to both authenticated and unauthenticated users)
  scope "/", HandmadeHubWeb do
    pipe_through [:browser]

    live_session :email_confirmation,
      on_mount: [{HandmadeHubWeb.UserAuth, :mount_current_user}],
      layout: {HandmadeHubWeb.Layouts, :auth} do
      live "/users/confirm", UserConfirmationInstructionsLive, :new
      live "/users/confirm/:token", UserConfirmationLive, :edit
    end
  end

  scope "/", HandmadeHubWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{HandmadeHubWeb.UserAuth, :ensure_authenticated}],
      layout: {HandmadeHubWeb.Layouts, :app} do
      live "/users/settings", UserSettingsLive, :edit
      live "/users/settings/confirm_email/:token", UserSettingsLive, :confirm_email
      live "/users/settings/profile", UserProfileLive

      # Product management routes (restricted to artisans only)
      live "/products", ProductLive.Index, :index
      live "/products/new", ProductLive.Index, :new
      live "/products/:id/edit", ProductLive.Index, :edit
      live "/products/:id", ProductLive.Show, :show
      live "/products/:id/show/edit", ProductLive.Show, :edit

      # Artisan dashboard route (restricted to artisans only)
      live "/artisan/dashboard", ArtisanDashboardLive, :index

      # Order management routes for users
      live "/orders", OrderLive.Index, :index
      live "/orders/:id", OrderLive.Show, :show
      live "/messages", MessagesLive, :index

      # Buyer dashboard route
      live "/buyer/dashboard", BuyerDashboardLive, :index

      # Checkout routes
      live "/checkout", CheckoutLive, :index
    end
  end

  scope "/", HandmadeHubWeb do
    pipe_through [:browser]
    delete "/users/log_out", UserSessionController, :delete
  end

  scope "/", HandmadeHubWeb do
    pipe_through [:browser]

    # Payment return page (no auth required; user returns from provider)
    live "/checkout/return", CheckoutReturnLive, :index
  end

  # Admin routes
  scope "/admin", HandmadeHubWeb do
    pipe_through [:browser, :admin_fetch_current]
  end

  scope "/admin", HandmadeHubWeb do
    pipe_through [:browser, :admin_redirect_if_authenticated]

    get "/log_in", AdminSessionController, :new
    post "/log_in", AdminSessionController, :create
  end

  scope "/admin", HandmadeHubWeb do
    pipe_through [:browser, :admin_fetch_current, :admin_require_authenticated]

    delete "/log_out", AdminSessionController, :delete

    live_session :require_authenticated_admin,
      on_mount: [{HandmadeHubWeb.AdminAuth, :ensure_authenticated_admin}, {HandmadeHubWeb.AdminNav, :nav}],
      layout: {HandmadeHubWeb.Layouts, :admin},
      root_layout: {HandmadeHubWeb.Layouts, :root} do
      live "/dashboard", Admin.DashboardLive, :index
      live "/artisans", Admin.ArtisansLive, :index
      live "/artisans/:id", Admin.ArtisanShowLive, :show
      live "/buyers", Admin.BuyersLive, :index
      live "/buyers/:id", Admin.BuyerShowLive, :show
      live "/admins", Admin.AdminsLive, :index
      live "/admins/:id", Admin.AdminShowLive, :show
      live "/products", Admin.ProductsLive, :index
      live "/products/:id", Admin.ProductShowLive, :show
      live "/orders", Admin.OrdersLive, :index
      live "/reviews", Admin.ReviewsLive, :index
      live "/analytics", Admin.AnalyticsLive, :index
      get "/reports/orders.csv", AdminReportsController, :export_orders_csv
      live "/settings", Admin.SettingsLive, :index
      live "/transactions", Admin.TransactionsLive, :index
      live "/payouts", Admin.PayoutsLive, :index
      live "/payment-settings", Admin.PaymentSettingsLive, :index
      live "/delivery/riders", Admin.DeliveryRidersLive, :index
    end
  end
end
