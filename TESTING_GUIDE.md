# Handmade Hub - Comprehensive Testing Guide

## Overview
This document provides a comprehensive testing guide for the Handmade Hub e-commerce platform. It covers testing scenarios for all user types (excluding Admin) from user creation through the complete shopping and selling experience.

## User Types
- **Buyer**: Customers who browse and purchase handmade products
- **Artisan**: Sellers who create and manage product listings
- **Guest**: Unauthenticated users who can browse and checkout

---

## 1. BUYER USER TESTING

### 1.1 User Registration & Authentication

#### Test Case 1.1.1: Buyer Registration
**Objective**: Verify a new buyer can successfully register for an account

**Steps**:
1. Navigate to `/users/register`
2. Fill in registration form:
   - Email: `buyer@example.com`
   - Password: `SecurePass123!`
   - Role: Select "Buyer"
3. Click "Create an account"
4. Check email for confirmation link
5. Click confirmation link

**Expected Results**:
- ✅ Registration form validates email format and password strength
- ✅ User receives confirmation email
- ✅ Account is created with role "buyer" and artisan_status "pending"
- ✅ User can log in after email confirmation
- ✅ User is redirected to appropriate buyer dashboard

**Validation Points**:
- Email uniqueness validation
- Password strength requirements
- Role assignment correct
- Email confirmation flow works
- Database records created properly

#### Test Case 1.1.2: Buyer Login
**Objective**: Verify registered buyers can log in successfully

**Steps**:
1. Navigate to `/users/log_in`
2. Enter credentials:
   - Email: `buyer@example.com`
   - Password: `SecurePass123!`
3. Click "Log in"

**Expected Results**:
- ✅ User is authenticated successfully
- ✅ Session is created
- ✅ User is redirected to buyer dashboard
- ✅ Navigation shows user-specific options

#### Test Case 1.1.3: Profile Management
**Objective**: Verify buyers can manage their profile information

**Steps**:
1. Log in as buyer
2. Navigate to `/users/settings/profile`
3. Update profile:
   - Name: "John Buyer"
   - Bio: "I love handmade crafts"
   - Upload profile image
4. Save changes

**Expected Results**:
- ✅ Profile form loads with current user data
- ✅ Image upload works (jpg, png, gif, max 5MB)
- ✅ Profile updates save successfully
- ✅ Changes are reflected immediately
- ✅ File validation works (type and size)

### 1.2 Product Browsing & Discovery

#### Test Case 1.2.1: Browse Products
**Objective**: Verify buyers can browse and discover products

**Steps**:
1. Log in as buyer
2. Navigate to `/` (homepage)
3. Browse product listings
4. Use search functionality
5. Apply filters (category, price range)
6. Sort products (price, date, rating)

**Expected Results**:
- ✅ Product grid displays correctly
- ✅ Product images load properly
- ✅ Product information shows (name, price, artisan, rating)
- ✅ Search returns relevant results
- ✅ Filters work correctly
- ✅ Sorting options function properly
- ✅ Pagination works if many products

#### Test Case 1.2.2: Product Details
**Objective**: Verify buyers can view detailed product information

**Steps**:
1. Click on any product from browse page
2. View product details page
3. Check all product information
4. View product images (multiple if available)
5. Check artisan information

**Expected Results**:
- ✅ Product details page loads correctly
- ✅ All product information displays (name, price, description, quantity)
- ✅ Product images are viewable and switchable
- ✅ Artisan information is shown
- ✅ Add to cart button is present and functional
- ✅ Buy now button is present and functional

#### Test Case 1.2.3: Favorites Management
**Objective**: Verify buyers can add/remove products from favorites

**Steps**:
1. Browse products as logged-in buyer
2. Click heart/favorite icon on products
3. Navigate to favorites view
4. Remove items from favorites

**Expected Results**:
- ✅ Favorite toggle works on product cards
- ✅ Favorites are saved to user account
- ✅ Favorites view shows only favorited products
- ✅ Remove from favorites works
- ✅ Favorite count updates in real-time

### 1.3 Shopping Cart Management

#### Test Case 1.3.1: Add to Cart
**Objective**: Verify buyers can add products to shopping cart

**Steps**:
1. Browse products as buyer
2. Click "Add to Cart" on multiple products
3. Vary quantities for some products
4. Check cart icon shows correct count

**Expected Results**:
- ✅ Products are added to cart successfully
- ✅ Cart count updates in navigation
- ✅ Quantity can be adjusted
- ✅ Stock validation prevents overselling
- ✅ Error messages for insufficient stock

#### Test Case 1.3.2: Cart Management
**Objective**: Verify buyers can manage items in their cart

**Steps**:
1. Add multiple items to cart
2. Navigate to cart page
3. Update quantities
4. Remove items
5. Clear entire cart

**Expected Results**:
- ✅ Cart page shows all added items
- ✅ Quantities can be updated
- ✅ Items can be removed individually
- ✅ Cart can be cleared completely
- ✅ Total price calculates correctly
- ✅ Cart persists across sessions

#### Test Case 1.3.3: Guest Cart to User Cart Merge
**Objective**: Verify guest cart merges with user cart on login

**Steps**:
1. Add items to cart as guest user
2. Register/login as buyer
3. Check cart contains previous items

**Expected Results**:
- ✅ Guest cart items are preserved
- ✅ Items merge with user cart on login
- ✅ No duplicate items created
- ✅ Quantities are preserved correctly

### 1.4 Checkout Process

#### Test Case 1.4.1: Checkout Flow - Step 1 (Delivery Details)
**Objective**: Verify buyers can enter delivery information

**Steps**:
1. Add items to cart
2. Navigate to `/checkout`
3. Fill in delivery details:
   - Recipient Name: "John Buyer"
   - Phone Number: "+260123456789"
   - Email: "buyer@example.com"
   - Address: "123 Main Street"
   - City: "Lusaka"
   - Postal Code: "10101"
4. Click "Continue to Payment"

**Expected Results**:
- ✅ Checkout page loads with step indicator
- ✅ Delivery form validates required fields
- ✅ Phone number format validation
- ✅ Email format validation
- ✅ Shipping fee calculates based on city
- ✅ Progress to step 2

#### Test Case 1.4.2: Checkout Flow - Step 2 (Payment)
**Objective**: Verify buyers can select payment method

**Steps**:
1. Complete delivery details
2. Select payment method (Mobile Money)
3. Select provider (MTN, Airtel, Zamtel)
4. Enter mobile number
5. Click "Continue to Review"

**Expected Results**:
- ✅ Payment method selection works
- ✅ Provider selection updates form
- ✅ Mobile number validation
- ✅ All required fields must be completed
- ✅ Progress to step 3

#### Test Case 1.4.3: Checkout Flow - Step 3 (Review & Confirm)
**Objective**: Verify buyers can review and confirm their order

**Steps**:
1. Complete payment details
2. Review order summary
3. Check totals (subtotal + shipping)
4. Click "Place Order"

**Expected Results**:
- ✅ Order summary displays correctly
- ✅ All items and quantities shown
- ✅ Pricing breakdown is accurate
- ✅ Total calculation is correct
- ✅ Order placement initiates payment

#### Test Case 1.4.4: Payment Processing
**Objective**: Verify payment integration works correctly

**Steps**:
1. Complete checkout process
2. Click "Place Order"
3. Redirect to payment provider
4. Complete payment (test mode)
5. Return to application

**Expected Results**:
- ✅ Order is created in database
- ✅ Redirect to payment provider works
- ✅ Payment page loads correctly
- ✅ Return from payment works
- ✅ Order status updates to paid
- ✅ User sees confirmation page

### 1.5 Order Management

#### Test Case 1.5.1: View Order History
**Objective**: Verify buyers can view their order history

**Steps**:
1. Log in as buyer with completed orders
2. Navigate to `/orders`
3. View order list
4. Click on individual orders

**Expected Results**:
- ✅ Order list shows all user orders
- ✅ Orders are sorted by date (newest first)
- ✅ Order status is displayed
- ✅ Order numbers are clickable
- ✅ Order details page loads correctly

#### Test Case 1.5.2: Order Details
**Objective**: Verify buyers can view detailed order information

**Steps**:
1. Navigate to order details page
2. Review order information
3. Check shipping address
4. View order items
5. Check order status

**Expected Results**:
- ✅ All order details display correctly
- ✅ Shipping address is shown
- ✅ Order items with quantities and prices
- ✅ Order status and payment status
- ✅ Order total breakdown
- ✅ Order number and date

#### Test Case 1.5.3: Order Cancellation
**Objective**: Verify buyers can cancel orders when appropriate

**Steps**:
1. View a pending order
2. Click "Cancel Order"
3. Confirm cancellation

**Expected Results**:
- ✅ Cancel button appears for cancellable orders
- ✅ Confirmation dialog works
- ✅ Order status updates to cancelled
- ✅ Appropriate orders can be cancelled
- ✅ Non-cancellable orders don't show cancel button

---

## 2. ARTISAN USER TESTING

### 2.1 Artisan Registration & Approval

#### Test Case 2.1.1: Artisan Registration
**Objective**: Verify new artisans can register for accounts

**Steps**:
1. Navigate to `/users/register`
2. Fill in registration form:
   - Email: `artisan@example.com`
   - Password: `SecurePass123!`
   - Role: Select "Artisan"
3. Click "Create an account"
4. Check email for confirmation
5. Confirm email

**Expected Results**:
- ✅ Registration form accepts artisan role
- ✅ Account created with role "artisan"
- ✅ Artisan status set to "pending"
- ✅ Email confirmation required
- ✅ Account not fully active until approval

#### Test Case 2.1.2: Artisan Profile Setup
**Objective**: Verify artisans can complete their profile setup

**Steps**:
1. Log in as pending artisan
2. Navigate to profile settings
3. Complete profile:
   - Name: "Jane Artisan"
   - Bio: "I create beautiful handmade jewelry"
   - Upload profile image
4. Save profile

**Expected Results**:
- ✅ Profile form loads correctly
- ✅ All profile fields can be filled
- ✅ Image upload works
- ✅ Profile saves successfully
- ✅ Bio character limit enforced (500 chars)

### 2.2 Artisan Dashboard

#### Test Case 2.2.1: Dashboard Access
**Objective**: Verify artisans can access their dashboard

**Steps**:
1. Log in as approved artisan
2. Navigate to `/artisan/dashboard`
3. Explore dashboard sections

**Expected Results**:
- ✅ Dashboard loads successfully
- ✅ Navigation menu is present
- ✅ Dashboard sections are accessible
- ✅ Only approved artisans can access
- ✅ Pending artisans see appropriate message

#### Test Case 2.2.2: Dashboard Overview
**Objective**: Verify dashboard shows relevant information

**Steps**:
1. Access artisan dashboard
2. Review dashboard overview
3. Check statistics and metrics

**Expected Results**:
- ✅ Dashboard shows product count
- ✅ Order statistics displayed
- ✅ Recent activity shown
- ✅ Quick actions available
- ✅ Navigation to all sections works

### 2.3 Product Management

#### Test Case 2.3.1: Create Product
**Objective**: Verify artisans can create new product listings

**Steps**:
1. Navigate to "My Products" in dashboard
2. Click "Add New Product"
3. Fill product form:
   - Name: "Handmade Necklace"
   - Description: "Beautiful beaded necklace"
   - Price: 150.00
   - Quantity: 5
   - Category: "Jewelry"
4. Upload product images (multiple)
5. Set primary image
6. Save product

**Expected Results**:
- ✅ Product form loads correctly
- ✅ All required fields validated
- ✅ Image upload works (multiple images)
- ✅ Primary image selection works
- ✅ Product saves successfully
- ✅ Product appears in listings

#### Test Case 2.3.2: Edit Product
**Objective**: Verify artisans can edit existing products

**Steps**:
1. Navigate to product list
2. Click "Edit" on a product
3. Modify product details:
   - Update price
   - Change description
   - Update quantity
4. Save changes

**Expected Results**:
- ✅ Edit form loads with current data
- ✅ Changes save successfully
- ✅ Updated information reflects immediately
- ✅ Image management works
- ✅ Validation still applies

#### Test Case 2.3.3: Delete Product
**Objective**: Verify artisans can remove products

**Steps**:
1. Navigate to product list
2. Click "Delete" on a product
3. Confirm deletion

**Expected Results**:
- ✅ Delete confirmation dialog
- ✅ Product is removed from listings
- ✅ Product no longer appears in browse
- ✅ Soft delete implemented (removed_at timestamp)

#### Test Case 2.3.4: Product Image Management
**Objective**: Verify artisans can manage product images

**Steps**:
1. Edit a product with multiple images
2. Add new images
3. Remove existing images
4. Change primary image
5. Save changes

**Expected Results**:
- ✅ Multiple images can be uploaded
- ✅ Images can be removed
- ✅ Primary image can be changed
- ✅ Image order can be managed
- ✅ File validation works (type, size)

### 2.4 Order Management

#### Test Case 2.4.1: View Orders
**Objective**: Verify artisans can view their orders

**Steps**:
1. Navigate to "Orders" in dashboard
2. View order list
3. Filter by status
4. Click on individual orders

**Expected Results**:
- ✅ Order list shows relevant orders
- ✅ Orders are filtered by artisan's products
- ✅ Order status is displayed
- ✅ Order details are accessible
- ✅ Filtering works correctly

#### Test Case 2.4.2: Update Order Status
**Objective**: Verify artisans can update order status

**Steps**:
1. View order details
2. Update order status:
   - Processing
   - Shipped
   - Delivered
3. Add tracking information
4. Save changes

**Expected Results**:
- ✅ Status update options available
- ✅ Status changes save successfully
- ✅ Tracking information can be added
- ✅ Status updates are logged
- ✅ Customer is notified of changes

#### Test Case 2.4.3: Order Fulfillment
**Objective**: Verify complete order fulfillment process

**Steps**:
1. Receive new order notification
2. Review order details
3. Prepare products
4. Update status to "Processing"
5. Ship order
6. Update status to "Shipped"
7. Add tracking details
8. Mark as "Delivered" when complete

**Expected Results**:
- ✅ Order notifications work
- ✅ Status workflow is logical
- ✅ Tracking information is stored
- ✅ Status transitions are valid
- ✅ Customer can track progress

### 2.5 Messaging & Communication

#### Test Case 2.5.1: View Messages
**Objective**: Verify artisans can view customer messages

**Steps**:
1. Navigate to "Messages" in dashboard
2. View message list
3. Click on individual messages
4. Mark messages as read

**Expected Results**:
- ✅ Message list loads correctly
- ✅ Unread message count is shown
- ✅ Messages can be opened and read
- ✅ Read status updates correctly
- ✅ Message threading works

#### Test Case 2.5.2: Respond to Messages
**Objective**: Verify artisans can respond to customer messages

**Steps**:
1. Open a customer message
2. Type response
3. Send message
4. Check conversation history

**Expected Results**:
- ✅ Reply form is functional
- ✅ Messages send successfully
- ✅ Conversation history is maintained
- ✅ Customer receives responses
- ✅ Message timestamps are accurate

---

## 3. GUEST USER TESTING

### 3.1 Guest Browsing

#### Test Case 3.1.1: Browse Without Registration
**Objective**: Verify guests can browse products without registering

**Steps**:
1. Visit homepage without logging in
2. Browse product listings
3. Use search and filters
4. View product details

**Expected Results**:
- ✅ Product listings are visible
- ✅ Search functionality works
- ✅ Filters are functional
- ✅ Product details can be viewed
- ✅ No authentication required for browsing

#### Test Case 3.1.2: Guest Cart
**Objective**: Verify guests can add items to cart

**Steps**:
1. Browse products as guest
2. Add items to cart
3. View cart contents
4. Modify quantities
5. Remove items

**Expected Results**:
- ✅ Cart functionality works for guests
- ✅ Items persist in session
- ✅ Cart management works
- ✅ Cart count shows in navigation
- ✅ Cart survives page refreshes

### 3.2 Guest Checkout

#### Test Case 3.2.1: Guest Checkout Process
**Objective**: Verify guests can complete checkout without registration

**Steps**:
1. Add items to cart as guest
2. Navigate to checkout
3. Fill in delivery details:
   - Recipient Name: "Guest User"
   - Phone: "+260123456789"
   - Email: "guest@example.com"
   - Address: "456 Guest Street"
   - City: "Lusaka"
4. Complete payment details
5. Place order

**Expected Results**:
- ✅ Checkout process works for guests
- ✅ All required fields validated
- ✅ Payment processing works
- ✅ Order is created successfully
- ✅ Guest receives order confirmation

#### Test Case 3.2.2: Guest to User Conversion
**Objective**: Verify guests can convert to registered users

**Steps**:
1. Complete guest checkout
2. Register for account with same email
3. Check if previous orders are linked

**Expected Results**:
- ✅ Registration works with existing email
- ✅ Previous orders are accessible
- ✅ User account is created
- ✅ Order history is preserved

---

## 4. EDGE CASES & ERROR SCENARIOS

### 4.1 Authentication Edge Cases

#### Test Case 4.1.1: Invalid Login Attempts
**Objective**: Verify system handles invalid login attempts properly

**Steps**:
1. Try logging in with wrong password
2. Try logging in with non-existent email
3. Try logging in with empty fields
4. Try multiple failed attempts

**Expected Results**:
- ✅ Appropriate error messages shown
- ✅ System doesn't reveal if email exists
- ✅ Rate limiting prevents brute force
- ✅ Account lockout after multiple attempts

#### Test Case 4.1.2: Session Management
**Objective**: Verify session handling works correctly

**Steps**:
1. Log in successfully
2. Leave browser idle for extended period
3. Try to perform actions
4. Log out and log back in

**Expected Results**:
- ✅ Session expires appropriately
- ✅ User is redirected to login when session expires
- ✅ Logout clears session completely
- ✅ New login creates fresh session

### 4.2 Product Management Edge Cases

#### Test Case 4.2.1: Stock Management
**Objective**: Verify stock validation works correctly

**Steps**:
1. Set product quantity to 1
2. Add product to cart
3. Try to add more than available stock
4. Try to checkout with insufficient stock

**Expected Results**:
- ✅ Stock validation prevents overselling
- ✅ Error messages are clear
- ✅ Cart quantities are limited by stock
- ✅ Checkout fails with insufficient stock

#### Test Case 4.2.2: Image Upload Edge Cases
**Objective**: Verify image upload handles edge cases

**Steps**:
1. Try uploading non-image files
2. Try uploading oversized images
3. Try uploading corrupted files
4. Try uploading without selecting file

**Expected Results**:
- ✅ File type validation works
- ✅ File size validation works
- ✅ Corrupted files are rejected
- ✅ Appropriate error messages shown

### 4.3 Payment Edge Cases

#### Test Case 4.3.1: Payment Failures
**Objective**: Verify payment failure handling

**Steps**:
1. Start checkout process
2. Simulate payment failure
3. Try to retry payment
4. Check order status

**Expected Results**:
- ✅ Payment failures are handled gracefully
- ✅ Order status remains pending
- ✅ User can retry payment
- ✅ Clear error messages provided

#### Test Case 4.3.2: Network Issues
**Objective**: Verify system handles network interruptions

**Steps**:
1. Start checkout process
2. Simulate network interruption
3. Restore connection
4. Check system state

**Expected Results**:
- ✅ System handles network issues gracefully
- ✅ User can resume where they left off
- ✅ No data loss occurs
- ✅ Appropriate retry mechanisms

### 4.4 Data Validation Edge Cases

#### Test Case 4.4.1: Form Validation
**Objective**: Verify all forms validate input correctly

**Steps**:
1. Submit forms with invalid data
2. Try SQL injection attempts
3. Try XSS attempts
4. Submit extremely long data

**Expected Results**:
- ✅ All forms validate input properly
- ✅ SQL injection attempts are blocked
- ✅ XSS attempts are sanitized
- ✅ Length limits are enforced
- ✅ Appropriate error messages shown

---

## 5. PERFORMANCE TESTING

### 5.1 Load Testing

#### Test Case 5.1.1: Multiple Users
**Objective**: Verify system handles multiple concurrent users

**Steps**:
1. Simulate 10+ concurrent users
2. Have users browse, add to cart, checkout
3. Monitor system performance
4. Check for errors or slowdowns

**Expected Results**:
- ✅ System remains responsive
- ✅ No data corruption occurs
- ✅ Page load times remain acceptable
- ✅ Database queries are optimized

#### Test Case 5.1.2: Large Product Catalogs
**Objective**: Verify system handles large numbers of products

**Steps**:
1. Create 1000+ products
2. Test browsing and search
3. Test filtering and sorting
4. Monitor performance

**Expected Results**:
- ✅ Browsing remains fast
- ✅ Search returns results quickly
- ✅ Pagination works correctly
- ✅ No memory issues

### 5.2 Mobile Testing

#### Test Case 5.2.1: Mobile Responsiveness
**Objective**: Verify application works on mobile devices

**Steps**:
1. Access application on mobile device
2. Test all major functions
3. Check responsive design
4. Test touch interactions

**Expected Results**:
- ✅ Layout adapts to mobile screens
- ✅ Touch interactions work properly
- ✅ Forms are mobile-friendly
- ✅ Images scale appropriately

---

## 6. SECURITY TESTING

### 6.1 Access Control

#### Test Case 6.1.1: Unauthorized Access
**Objective**: Verify users cannot access unauthorized areas

**Steps**:
1. Try accessing artisan dashboard as buyer
2. Try accessing admin areas as regular user
3. Try accessing other users' data
4. Try manipulating URLs

**Expected Results**:
- ✅ Access is properly restricted
- ✅ Unauthorized users are redirected
- ✅ Users cannot access others' data
- ✅ URL manipulation is prevented

#### Test Case 6.1.2: Data Protection
**Objective**: Verify sensitive data is protected

**Steps**:
1. Check password storage (hashed)
2. Verify session security
3. Check data transmission (HTTPS)
4. Test for data leaks

**Expected Results**:
- ✅ Passwords are properly hashed
- ✅ Sessions are secure
- ✅ Data transmission is encrypted
- ✅ No sensitive data in logs

---

## 7. TESTING CHECKLIST

### Pre-Testing Setup
- [ ] Database is seeded with test data
- [ ] Test user accounts are created
- [ ] Test products are available
- [ ] Payment system is in test mode
- [ ] Email system is configured for testing

### User Account Setup
- [ ] Create test buyer account
- [ ] Create test artisan account
- [ ] Create test admin account (if needed)
- [ ] Set up test email addresses

### Test Data Preparation
- [ ] Create test products with various categories
- [ ] Set up test orders in different states
- [ ] Prepare test images for uploads
- [ ] Configure test payment methods

### Environment Setup
- [ ] Application is running in test environment
- [ ] Database is clean and ready
- [ ] All services are running
- [ ] Test tools are available

### Post-Testing Cleanup
- [ ] Clean up test data
- [ ] Reset database state
- [ ] Clear test files
- [ ] Document any issues found

---

## 8. COMMON ISSUES & TROUBLESHOOTING

### Common Issues
1. **Email confirmation not working**
   - Check email configuration
   - Verify SMTP settings
   - Check spam folder

2. **Image uploads failing**
   - Check file permissions
   - Verify file size limits
   - Check disk space

3. **Payment processing errors**
   - Verify API credentials
   - Check network connectivity
   - Verify test mode settings

4. **Session issues**
   - Check session configuration
   - Verify cookie settings
   - Check server time

### Debugging Tips
- Check browser console for JavaScript errors
- Review server logs for backend errors
- Use database queries to verify data
- Test with different browsers and devices

---

## 9. TESTING SCHEDULE

### Phase 1: Core Functionality (Week 1)
- User registration and authentication
- Basic product browsing
- Shopping cart functionality
- Simple checkout process

### Phase 2: Advanced Features (Week 2)
- Product management for artisans
- Order management
- Messaging system
- Profile management

### Phase 3: Edge Cases & Performance (Week 3)
- Error handling
- Performance testing
- Security testing
- Mobile responsiveness

### Phase 4: Integration & Final Testing (Week 4)
- End-to-end testing
- User acceptance testing
- Bug fixes and refinements
- Final validation

---

This comprehensive testing guide ensures that all functionality of the Handmade Hub application is thoroughly tested across all user types and scenarios. Testers should follow this guide systematically to ensure the application meets all requirements and provides a smooth user experience.
