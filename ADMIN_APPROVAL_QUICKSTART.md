# Admin Approval System - Quick Start Guide

## 🚀 Quick Setup (30 seconds)

### Step 1: Create First Super Admin
```elixir
# In IEx console (iex -S mix)
alias HandmadeHub.{Admins, Repo}

{:ok, admin} = Admins.register_admin(%{
  email: "super@example.com",
  username: "superadmin",
  password: "SecurePass123",
  role: "super_admin"
})

admin 
|> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)}) 
|> Repo.update!()
```

### Step 2: Start Server & Test
```bash
mix phx.server
```

Visit: http://localhost:4000/admin/log_in  
Login: `super@example.com` / `SecurePass123`  
Navigate: http://localhost:4000/admin/admins

## 📋 Common Tasks

### Create New Admin (Web UI)
1. Click "Create New Admin" button
2. Fill form (username, email, password, role)
3. Submit → Admin created as "Pending"

### Approve Admin
1. Find admin with yellow "Pending" badge
2. Click "Approve" button
3. Status changes to green "Approved"
4. Admin can now log in

### Reject Admin
1. Find admin with yellow "Pending" badge
2. Click "Reject" button
3. Admin is deleted from system

## 🔑 Key Functions (IEx)

```elixir
# List all admins
Admins.list_admins()

# List pending admins only
Admins.pending_admins()

# List approved admins only
Admins.approved_admins()

# Approve an admin
admin = Admins.get_admin!(id)
{:ok, _} = Admins.approve_admin(admin)

# Reject an admin
admin = Admins.get_admin!(id)
{:ok, _} = Admins.reject_admin(admin)
```

## 🎨 Status Badges

| Status | Badge Color | Meaning |
|--------|-------------|---------|
| Pending | 🟡 Yellow | Cannot log in yet |
| Approved | 🟢 Green | Can log in |

## 🔒 Permissions

| Action | Who Can Do It |
|--------|---------------|
| Create admin | super_admin only |
| Approve admin | super_admin only |
| Reject admin | super_admin only |
| Edit admin | super_admin only |
| Delete admin | super_admin only |
| Log in | Approved admins only |

## ⚡ Quick Test

### Automated Test
```bash
mix run test_admin_approval_system.exs
```

### Manual Test Flow
1. Log in as super_admin
2. Go to `/admin/admins`
3. Click "Create New Admin"
4. Create a moderator
5. Verify "Pending" status
6. Click "Approve"
7. Verify "Approved" status
8. Log out
9. Log in as new moderator
10. Success! ✅

## 🐛 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't see "Create New Admin" button | Log in as super_admin |
| Pending admin can't log in | This is correct! Approve them first |
| "Cannot delete last super admin" error | Create another super_admin first |
| Modal won't open | Check browser console for errors |

## 📞 Need Help?

Check the full documentation: `ADMIN_APPROVAL_IMPLEMENTATION.md`

