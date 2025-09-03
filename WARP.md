# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

HandmadeHub is an e-commerce platform built with Phoenix LiveView for Lusaka-based artisans to sell handmade products. The application uses a Model-View-Controller architecture with LiveView for real-time UI updates.

## Essential Development Commands

### Setup and Installation
```bash
# Initial setup (installs deps, creates DB, runs migrations, builds assets)
mix setup

# Install dependencies only
mix deps.get

# Database operations
mix ecto.create        # Create the database
mix ecto.migrate       # Run migrations
mix ecto.reset        # Drop, recreate, and seed database
mix ecto.rollback     # Rollback last migration
```

### Development Server
```bash
# Start Phoenix server (http://localhost:4000)
mix phx.server

# Start with IEx REPL for debugging
iex -S mix phx.server
```

### Testing
```bash
# Run all tests (creates test DB, runs migrations, executes tests)
mix test

# Run specific test file
mix test test/handmade_hub/accounts_test.exs

# Run test with specific line number
mix test test/handmade_hub/accounts_test.exs:10

# Run tests with coverage (if configured)
mix test --cover
```

### Code Quality
```bash
# Format code according to .formatter.exs rules
mix format

# Check formatting without making changes
mix format --check-formatted

# Show all routes
mix phx.routes

# Check for dependency issues
mix deps.audit
mix hex.outdated
```

### Asset Management
```bash
# Build assets for development
mix assets.build

# Build and minify for production
mix assets.deploy

# Install missing asset tools
mix assets.setup
```

### Database Migrations
```bash
# Generate new migration
mix ecto.gen.migration migration_name

# Check migration status
mix ecto.migrations
```

## Architecture Overview

### Core Contexts (Business Logic Layer)

The application follows Phoenix's context pattern to organize business logic:

1. **HandmadeHub.Accounts** (`lib/handmade_hub/accounts.ex`)
   - User authentication and management
   - Role-based access (artisan vs buyer)
   - Profile management
   - Uses `phx.gen.auth` for secure authentication

2. **HandmadeHub.Catalog** (`lib/handmade_hub/catalog.ex`)
   - Product CRUD operations
   - Product image management
   - Artisan product associations
   - Primary image selection logic

3. **HandmadeHub.Application** (`lib/handmade_hub/application.ex`)
   - OTP supervision tree
   - Manages Repo, PubSub, Endpoint, and Finch

### Web Layer Architecture

**Router** (`lib/handmade_hub_web/router.ex`):
- Defines three authentication states:
  - Public routes (browsing without login)
  - Authenticated routes (logged-in users)
  - Restricted routes (role-based, e.g., artisan dashboard)
- Uses LiveView sessions for real-time features
- Development routes for LiveDashboard and mailbox preview

**LiveView Components**:
- `BrowseLive` - Public product browsing
- `ProductLive` - Product management for artisans
- `ArtisanDashboardLive` - Artisan control panel
- `User*Live` modules - Authentication and profile management

### Database Structure

PostgreSQL database with key schemas:
- **users** - Authentication, roles (artisan/buyer), profile fields
- **products** - Item listings with artisan associations
- **product_images** - Multiple images per product with primary flag
- **user_tokens** - Session and password reset tokens

### Frontend Stack

- **Phoenix LiveView** - Server-rendered reactive UI
- **Tailwind CSS** - Utility-first styling
- **Alpine.js** - Lightweight JavaScript framework
- **Preline UI** - Component library
- **esbuild** - JavaScript bundling
- **Heroicons** - Icon library

### Authentication Flow

Uses `HandmadeHubWeb.UserAuth` plug for:
- Session management
- Current user assignment
- Route protection based on authentication state
- Role-based access control (artisan vs buyer)

## Development Configuration

### Database Credentials
- **Development**: PostgreSQL on localhost (see `config/dev.exs`)
- **Test**: Separate test database with MIX_TEST_PARTITION support
- **Production**: Configured via runtime.exs environment variables

### Environment-Specific Files
- `config/dev.exs` - Development settings, watchers, live reload
- `config/test.exs` - Test database, async testing
- `config/prod.exs` - Production optimizations
- `config/runtime.exs` - Runtime configuration from env vars

### Asset Pipeline
- JavaScript entry: `assets/js/app.js`
- CSS entry: `assets/css/app.css`
- Tailwind config: `assets/tailwind.config.js`
- Output directory: `priv/static/assets/`

## Key Development Patterns

### LiveView State Management
- Use socket assigns for component state
- Implement handle_event callbacks for user interactions
- Use handle_info for PubSub messages
- Leverage streams for efficient list rendering

### Context Boundaries
- Controllers/LiveViews should only call context functions
- Never access Repo directly from web layer
- Contexts return domain structs, not Ecto changesets to web layer

### Image Handling
- Local file storage in `priv/static/uploads/`
- Product images support multiple uploads with primary selection
- Images are associated via `product_images` table

### Testing Strategy
- Unit tests for context functions
- ConnCase for controller testing
- LiveView testing with `live/2` and `render_click/2`
- DataCase for database-dependent tests

## Project-Specific Considerations

### Artisan Features
- Product management restricted to artisan role
- Dashboard at `/artisan/dashboard`
- Each artisan has their own product catalog
- Order management and status updates

### Buyer Journey
- Public browsing without authentication
- Cart and checkout require login
- Review system for purchased products
- Order tracking functionality

### Payment Integration Points
- Designed for Stripe/Flutterwave integration
- Payment processing happens via external APIs
- Order confirmation and receipt generation

### Mobile Optimization
- Responsive design using Tailwind
- Optimized for low-bandwidth connections
- Touch-friendly UI components
- Progressive enhancement approach
