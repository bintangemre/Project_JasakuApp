# Jasaku — Home-Service Marketplace

**Jasaku** is a mobile-first home-service marketplace connecting customers with verified service providers (Mitra) in Indonesia. Built as a monorepo with a Flutter mobile app and an Express/TypeScript REST API backend.

## Architecture

```
Jasaku/
├── jasaku_app/          # Flutter mobile app (Customer + Provider)
├── jasaku-backend/      # Express 5 + TypeScript + Prisma + PostgreSQL
└── docs/              # Documentation & PlantUML diagrams
    ├── use-case-admin.puml        # EN
    ├── use-case-admin-id.puml     # ID
    ├── use-case-customer.puml     # EN
    ├── use-case-customer-id.puml  # ID
    ├── use-case-mitra.puml        # EN
    └── use-case-mitra-id.puml     # ID
```

---

## 📱 Mobile App (`jasaku_app/`)

**Tech**: Flutter 3.7+ · Riverpod · Dio · flutter_map · Geolocator · Firebase

### Two Apps in One Codebase

| App | Entry Point | Theme | Audience |
|---|---|---|---|
| **Customer** | `lib/main_customer.dart` | Blue | End-users ordering home services |
| **Provider (Mitra)** | `lib/main_provider.dart` | Teal | Service providers accepting jobs |

### Customer App — Screens & Flow

```
Login/Register
    └── Home (Browse categories, promo banners, recent orders)
            ├── Services by category → Find providers by distance
            │       └── View provider detail → Create order
            │               ├── Pay via escrow (bank/ewallet/QRIS)
            │               ├── Track order (live map + route)
            │               └── Rate & review provider
            ├── Custom Tasks → Create task → Pay escrow → Wait for provider
            ├── Orders (Active / Completed / All)
            └── Profile (Edit info, reports, about)
```

### Provider (Mitra) App — Screens & Flow

```
Registration (multi-step)
    └── Select categories → Personal info → Upload documents
            → KTP OCR scan → Liveness detection → Accept terms
            → Pending admin verification
                ├── Rejected → Resubmit verification
                └── Verified → Complete onboarding (profile, pricing, payout)
                        └── Dashboard
                                ├── Toggle availability (service + custom task)
                                ├── Incoming requests (5-min timer to accept)
                                ├── Active order (status progression + map)
                                ├── Schedule & earnings
                                ├── Manage services & pricing
                                ├── Manage payout methods (bank/ewallet)
                                ├── Browse & accept custom tasks
                                └── Profile (edit, reviews, reports)
```

### Key Features

| Feature | Details |
|---|---|
| **Service Categories** | Kelistrikan, Bangunan, Kebersihan, Pindahan, Kayu, AC/Elektronik (dynamic from DB) |
| **Order Lifecycle** | pending → accepted → on_the_way → arrived → in_progress → completed |
| **Extension Request** | Provider can request 1-3 day extension if job runs over |
| **Real-time Tracking** | Customer tracks provider via live map with route polyline (polls 5s) |
| **Escrow Payment** | Customer pays to admin rekber → admin confirms → provider completes → payout released |
| **Custom Tasks** | Customer creates custom job with budget → admin confirms payment → provider bids → completes |
| **Push Notifications** | FCM for order updates, status changes, task events |
| **Maps** | CartoDB Voyager tiles (free) + OpenRouteService directions |
| **Location Tracking** | Provider sends location every 30s via background stream |

---

## 🌐 Backend API (`jasaku-backend/`)

**Tech**: Express 5 · TypeScript · Prisma 7 · PostgreSQL (Supabase) · PostGIS · JWT

### Module Structure

```
src/modules/
├── auth/           # Register (customer/provider/admin), login (email + Google), OTP, verification
├── services/       # Categories & services listing, provider matching by distance
├── orders/         # CRUD orders, status transitions, tracking, provider schedule
├── provider/       # Provider profile, services & pricing, payout methods, availability
├── customer/       # Customer profile
├── admin/          # Dashboard, provider verification, categories CRUD, order payment confirmation,
│                   # extension approval, user management, reports, notifications
├── payments/       # Payment methods & status management
├── reviews/        # Ratings & reviews (one review per order)
├── custom-tasks/   # Custom task creation, browsing, bidding, completion
├── locations/      # Provider location updates & queries (PostGIS)
├── notifications/  # FCM push notification sending & device registration
└── reports/        # Issue reporting & handling
```

### API Documentation

Swagger UI: `http://localhost:3000/api-docs`

### Authentication & Authorization

- **JWT** via `bcryptjs` + `jsonwebtoken`
- **Role-based middleware**: `isCustomer`, `isProvider`, `isAdmin`
- **Google OAuth** for social login (auto-registers as customer)
- **OTP** email verification (dev-only, in-memory)

### Order Status Engine

```
Customer creates order
    → pending (waiting provider response)
        → rejected (provider declines)
        → accepted → on_the_way → arrived → in_progress
            → completed (customer can review)
            → extension requested → admin approves/denies
        → cancelled (by customer, if pending/accepted)
```

### Escrow Payment Flow

```
1. Customer creates order → pending
2. Customer sees admin payment account (bank/ewallet/QRIS)
3. Customer transfers money → admin confirms payment
4. Order becomes active → provider works
5. Provider completes → admin releases payout
6. Customer leaves review
```

---

## 🚀 Getting Started

### Prerequisites

- Flutter 3.7+
- Node.js 20+
- PostgreSQL (Supabase)
- Firebase project (for FCM + Google OAuth)

### Backend Setup

```bash
cd jasaku-backend
npm install
npx prisma generate
npx prisma migrate dev
npm run dev          # http://localhost:3000
```

### Flutter App Setup

```bash
cd jasaku_app
flutter pub get
dart run build_runner build

# Run Customer app
flutter run --target lib/main_customer.dart

# Run Provider app
flutter run --target lib/main_provider.dart

# With custom backend URL (physical device)
flutter run --target lib/main_customer.dart --dart-define=BASE_URL=YOUR_IP:3000

# With OpenRouteService API key
flutter run --dart-define=ORS_API_KEY=YOUR_KEY
```

### Firebase Admin (Push Notifications)

1. Download service account JSON from Firebase Console
2. Save to `jasaku-backend/src/config/firebase/service-account.json`
3. Restart backend (auto-detected, silently fails if absent)

---

## 📊 Entity Relationship

### Core Models

| Model | Description |
|---|---|
| `User` | Base user (email, password, role, phone, avatar) |
| `Provider` | Provider profile (bio, verification status, availability, ratings) |
| `Customer` | Customer profile |
| `Service` | Service offerings within categories |
| `Category` | Service categories |
| `PricingType` | Pricing models (per hour, per unit, flat) |
| `Order` | Service orders with status, location, work date |
| `OrderLocation` | Geospatial order location (PostGIS Point) |
| `Review` | Ratings and reviews |
| `Payment` | Payment records tied to orders |
| `PaymentMethod` | Admin escrow accounts (bank, ewallet, QRIS) |
| `ProviderPayoutMethod` | Provider's bank/ewallet for receiving payments |
| `CustomTask` | Customer-created custom job proposals |
| `TaskProposal` | Provider bids/acceptances on custom tasks |
| `ProviderLocation` | Real-time provider geospatial location |
| `IdentityVerification` | KYC documents, OCR data, liveness results |
| `Report` | Issue reports tied to orders |
| `Notification` | Push notification history |
| `Extension` | Order time extension requests |

---

## 🔐 Security Notes

- JWT tokens stored in `flutter_secure_storage`
- `.env` contains live Supabase & JWT secrets — never committed
- Firebase Admin SDK JSON excluded via `.gitignore`
- CORS wide-open (`origin: '*'`) for development
- Row-Level Security managed in PostgreSQL, not Prisma
- KTP/liveness data stored in `IdentityVerification` records

---

## 🧪 Testing

```bash
# Flutter
cd jasaku_app && flutter test

# Backend (no tests currently configured)
npm test   # TBD
```

---

## 📁 Project Structure

```
jasaku_app/
├── lib/
│   ├── core/              # Bootstrap, network (Dio), constants, utils, theme
│   ├── features/
│   │   ├── auth/          # Login, register, KYC, liveness
│   │   ├── customer/      # Customer home, orders, profile
│   │   ├── provider/      # Provider dashboard, profile, services
│   │   ├── orders/        # Order creation, tracking, detail
│   │   ├── services/      # Category browsing, provider listing
│   │   ├── reviews/       # Rating & review submission
│   │   ├── tasks/         # Custom tasks
│   │   ├── reports/       # Issue reporting
│   │   ├── notifications/ # FCM handling
│   │   └── payments/      # Payment methods & instructions
│   ├── models/            # Shared data models
│   ├── main_customer.dart
│   └── main_provider.dart
├── test/
└── pubspec.yaml

jasaku-backend/
├── src/
│   ├── app.ts             # Express app setup (CORS, routes, Swagger)
│   ├── server.ts          # Server entry point
│   ├── config/            # Prisma client, Firebase admin, face client
│   ├── middleware/         # Auth (JWT), role guard, upload (multer), schemas
│   ├── modules/           # Feature modules (see above)
│   │   └── */             # *.routes.ts → *.controller.ts → *.service.ts
│   ├── docs/              # Swagger spec
│   └── generated/prisma/  # Prisma client (gitignored)
├── prisma/
│   └── schema.prisma      # Database schema
├── public/admin/          # Admin web panel
├── face-service/          # Python face recognition service (InsightFace)
└── package.json
```

---

## 🗺️ Use Case Diagrams (PlantUML)

### English

| Diagram | File | Actor |
|---|---|---|
| **Admin** | [`docs/use-case-admin.puml`](docs/use-case-admin.puml) | Platform manager |
| **Customer** | [`docs/use-case-customer.puml`](docs/use-case-customer.puml) | Service buyer |
| **Mitra (Provider)** | [`docs/use-case-mitra.puml`](docs/use-case-mitra.puml) | Service provider |

### Bahasa Indonesia

| Diagram | File | Aktor |
|---|---|---|
| **Admin** | [`docs/use-case-admin-id.puml`](docs/use-case-admin-id.puml) | Pengelola platform |
| **Customer** | [`docs/use-case-customer-id.puml`](docs/use-case-customer-id.puml) | Pembeli jasa |
| **Mitra** | [`docs/use-case-mitra-id.puml`](docs/use-case-mitra-id.puml) | Penyedia jasa |

---

## 📄 License

Private — all rights reserved.
