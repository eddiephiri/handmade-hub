# Handmade Hub - Project Context for Coding Agent

## Project Overview

**Project Title:** Handmade Hub: Bridging Market Gaps for Lusaka's Artisans through E-Commerce

**Purpose:** A web-based e-commerce platform designed specifically for Lusaka-based artisans to showcase and sell handmade products online, empowering them with digital storefronts and connecting them directly with customers.

**Target Users:** 
- Artisans (sellers) - creators of handmade products in Lusaka, Zambia
- Buyers (customers) - consumers looking for authentic, locally-made goods

## Technical Stack & Architecture

### Core Technologies
- **Backend:** Elixir Phoenix framework
- **Frontend:** Phoenix LiveView with Tailwind CSS, HTML5
- **Database:** PostgreSQL
- **Authentication:** Phoenix (phx.gen.auth)
- **Version Control:** Git, GitHub
- **IDE:** Visual Studio Code
- **Deployment:** Fly.io / Render
- **Browser Testing:** Google Chrome

### Architecture Pattern
- **Model:** Client-Server Architecture
- **Caching:** Redis for performance optimization
- **Image Storage:** Local file-based storage (uploads/images/ directory)
- **Payment Integration:** Stripe/Flutterwave APIs

### System Requirements
**Development Environment:**
- Processor: Intel Core i5 or higher
- RAM: 8 GB minimum
- Storage: 256 GB SSD or 500 GB HDD
- OS: Windows 10 or Ubuntu 22.04

**Mobile Testing:**
- Android Smartphone (Samsung A12 or similar)
- RAM: 4 GB, Storage: 64 GB
- Android 10+, Display: 5.5+ inches

## Functional Requirements

### F1 - Artisan Registration and Authentication
- **Input:** Personal details (name, phone, email, password, artisan type)
- **Process:** Input validation, encrypted credential storage, session management
- **Output:** Confirmation messages, error handling
- **Security:** bcrypt password hashing, secure session tokens

### F2 - Product Listing and Management
- **Input:** Product images, names, prices, descriptions, stock quantities
- **Process:** Input validation, artisan association, CRUD operations
- **Output:** Public storefront listings with search/filter capabilities
- **Storage:** Database metadata, cloud storage for media files

### F3 - Secure Payment Integration
- **Input:** Customer payment details via integrated gateways
- **Process:** Third-party API processing (Flutterwave/Stripe)
- **Output:** Receipts and confirmation messages
- **Security:** HTTPS/TLS encryption, PCI compliance

### F4 - Order and Delivery Tracking
- **Input:** Customer orders with delivery preferences
- **Process:** Order logging, artisan notifications, status updates
- **Output:** Dashboard tracking for both parties
- **Storage:** Order history and delivery information

### F5 - Reviews and Ratings
- **Input:** Customer ratings and textual feedback
- **Process:** Average rating calculations, real-time updates
- **Output:** Reviews displayed on artisan profiles
- **Security:** Verified buyer restrictions

### F6 - Messaging and Notifications
- **Input:** User messages via in-app chat
- **Process:** Message routing, read/unread status
- **Output:** Real-time notifications
- **Security:** Encrypted messaging, moderation tools

## Non-Functional Requirements

### Performance & Reliability
- **Availability:** 99.9% uptime
- **Page Load Time:** Under 2 seconds
- **API Response:** Optimized for slower connections
- **Scalability:** Support for thousands of simultaneous sessions

### Security & Usability
- **Data Security:** Robust encryption, role-based access control
- **Mobile-First Design:** Responsive layout for varying technical skills
- **Accessibility:** Clear navigation, readable text, mobile-friendly

## Development Methodology

### Agile Scrum Approach
**Sprint Planning:**
- Phase 1: Artisan and buyer registration
- Phase 2: Product listing and order workflows
- Phase 3: Secure payment integrations
- Phase 4: Review and messaging systems

**Testing Strategy:**
- Unit tests for business logic
- Manual UI behavior validation
- Continuous integration/deployment

**Key Advantages:**
- Iterative development with user feedback
- Flexible requirement adaptation
- Early testing and issue resolution
- Direct collaboration with end users

## System Architecture Components

### Modular Services Structure
```
┌─────────────────┐    ┌─────────────────┐
│   Web Client    │    │  Mobile Client  │
│  (LiveView)     │    │   (Responsive)  │
└─────────────────┘    └─────────────────┘
         │                       │
         └───────────┬───────────┘
                     │
         ┌─────────────────┐
         │   API Gateway   │
         └─────────────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼───┐    ┌───────▼──┐    ┌────▼────┐
│ Auth  │    │ Product  │    │ Order   │
│Service│    │ Service  │    │ Service │
└───────┘    └──────────┘    └─────────┘
    │                │                │
    └────────────────┼────────────────┘
                     │
         ┌─────────────────┐
         │   PostgreSQL    │
         │    Database     │
         └─────────────────┘
```

### Core Services
1. **Authentication Service:** User registration, login, session management
2. **Artisan Service:** Profile management, shop status, bios
3. **Product Service:** Listing management, images, inventory
4. **Order Service:** Cart functionality, order processing
5. **Review Service:** Customer feedback, ratings
6. **Payment Service:** Stripe/Flutterwave integration

## Data Management

### Database Schema Considerations
- User accounts and roles
- Product and artisan metadata
- Orders and payment logs
- Ratings, reviews, and search history

### Image Handling Strategy
- **Storage:** Local server file system (uploads/images/)
- **Validation:** File type and size restrictions
- **Processing:** Basic resizing capabilities
- **Security:** Authenticated upload/delete permissions
- **Performance:** Middleware-controlled access

## User Experience Design

### Buyer Journey
1. Homepage → Product Discovery
2. Product Details → Cart Management
3. Secure Checkout → Payment Processing
4. Order Tracking → Review Submission

### Artisan Journey
1. Registration → Profile Setup
2. Product Listing → Image Upload
3. Order Management → Status Updates
4. Customer Communication → Review Monitoring

## Key Challenges & Solutions

### Market Context
- **Challenge:** Limited digital literacy among artisans
- **Solution:** Intuitive, mobile-first interface design

- **Challenge:** Mobile-heavy internet usage (78.7% cellular)
- **Solution:** Optimized for low-bandwidth connections

- **Challenge:** Trust issues with online payments
- **Solution:** Secure, integrated payment gateways with clear confirmations

### Technical Constraints
- **Image Storage:** Local file system for prototype phase
- **Scalability:** Designed for controlled user base initially
- **Mobile Optimization:** Responsive design without native app

## Research Foundation

### Data Collection Methods
- **Primary Research:** Questionnaires (20 respondents: 10 artisans, 10 buyers)
- **Interviews:** Semi-structured sessions with artisans and buyers
- **Secondary Research:** Market analysis, platform comparison, usage statistics

### Key Insights Driving Development
- Need for artisan autonomy in listing management
- Importance of integrated payment systems
- Mobile-first design critical for Zambian market
- Customer review systems essential for trust-building

## Success Metrics

### Platform Goals
- Enable artisan digital independence
- Improve market accessibility
- Facilitate secure transactions
- Build customer-artisan relationships
- Preserve traditional crafts through modern channels

### Technical Objectives
- Sub-2-second page load times
- 99.9% uptime reliability
- Scalable user session handling
- Secure payment processing
- Mobile-responsive experience

## Development Priorities

### Phase 1 (MVP)
- User authentication system
- Basic product listing
- Simple order processing
- Payment gateway integration

### Phase 2 (Enhanced Features)
- Review and rating system
- Advanced search/filtering
- Messaging capabilities
- Analytics dashboard

### Phase 3 (Scale & Optimize)
- Performance optimization
- Advanced caching
- Enhanced mobile experience
- Extended feature set

## Notes for Artisan implementation
### Key Points from the Project Context
- Artisan Role: Artisans are sellers who need to manage their profile, products, orders, and communication with buyers.
- Core Functionalities for Artisans:
    - Profile management (bio, shop status, etc.)
    - Product listing and management (CRUD)
    - Order management (view, update status)
    - Messaging/notifications
    - Review monitoring
- UI/UX Requirements:
    - Mobile-first, intuitive, and accessible
    - Dashboard with clear navigation for artisans

## Implementation Plan: Artisan Dashboard
1. Artisan Dashboard LiveView
- Create a new LiveView module (e.g., ArtisanDashboardLive) for the dashboard.
- Route: /artisan/dashboard (or similar, protected for artisan users).
2. Left Panel Navigation
- The left panel should include links to:
    - Dashboard Home (overview)
    - Profile
    - My Products
    - Orders
    - Messages
    - Reviews
    - Settings/Logout
- Use Tailwind CSS for styling: fixed/relative sidebar, responsive for mobile.

3. Dashboard Layout
- Use a two-column layout:
    - Left: Navigation panel (vertical menu)
    - Right: Main content area (changes based on selected function)
4. Authorization
- Ensure only users with the artisan role can access this dashboard.
5. Componentization
- Each dashboard section (profile, products, orders, etc.) can be a LiveComponent or a separate LiveView, loaded in the main content area.

This context provides the foundation for understanding the project's scope, technical requirements, and development approach for the Handmade Hub e-commerce platform.