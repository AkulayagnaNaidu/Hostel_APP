# Livora Hostel Hub — API Reference (Flutter)

**Base URL**: read from `.env` → `BASE_URL` (default: `https://livora-hostel-hub-1.onrender.com`)

Implementation: `lib/core/network/api_endpoints.dart` + `lib/services/`.

## Dio client

Configured in `lib/core/network/api_client.dart` — injects `Authorization: Bearer <token>` from secure storage; clears session on `401`.

## Endpoints

| Area | Method | Path | Auth |
|------|--------|------|------|
| Login | POST | `/api/auth/login` | No |
| Register | POST | `/api/auth/register` | No |
| Public buildings | GET | `/api/buildings/public` | No |
| Public building | GET | `/api/buildings/public/:id` | No |
| Public stats | GET | `/api/buildings/public/stats` | No |
| Owner buildings | GET | `/api/buildings?lightweight=true` | Yes |
| Create building | POST | `/api/buildings` | Yes |
| Update building | PATCH | `/api/buildings/:id` | Yes |
| Floors | GET | `/api/floors/building/:buildingId` | Yes |
| Rooms | GET | `/api/rooms/:floorId` | Yes |
| Beds | GET | `/api/beds` | Yes |
| Create booking | POST | `/api/bookings` | Yes |
| My bookings | GET | `/api/bookings/me` | Yes |
| My payments | GET | `/api/payments/me` | Yes |
| Create payment | POST | `/api/payments` | Yes |
| Create complaint | POST | `/api/complaints` | Yes |
| My complaints | GET | `/api/complaints/me` | Yes |
| Tenant profile | GET | `/api/tenant-portal/complete-profile` | Yes |
| Upload photo | POST | `/api/tenant-portal/upload-photo` | Yes |
| Community reports | POST/GET | `/api/tenant-portal/community-reports` | Yes |
| SOS | POST | `/api/tenant-portal/sos-alerts` | Yes |
| Wishlist | GET/POST | `/api/tenant-portal/wishlist` | Yes |
| Rewards | GET | `/api/tenant-portal/rewards/me` | Yes |
| Notifications | GET | `/api/notifications` | Yes |
| Mark read | PATCH | `/api/notifications/:id/read` | Yes |
| Mark all read | POST | `/api/notifications/mark-all-read` | Yes |

## Images

Paths starting with `/uploads/` are resolved with `ImageResolver` + `BASE_URL`.

## Environment

```env
BASE_URL=https://livora-hostel-hub-1.onrender.com
SOCKET_URL=https://livora-hostel-hub-1.onrender.com
```

Copy `.env.example` to `.env` before running the app.
