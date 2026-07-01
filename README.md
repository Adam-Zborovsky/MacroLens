# MacroLens — Vision-First Nutrition Analysis

Transform a food photo into a granular nutritional Case File in under five seconds. MacroLens replaces manual logging with AI-powered volumetric analysis — take a picture, verify, and move on.

---

## 🔬 What It Does

MacroLens is a full-stack nutrition tracking system that uses **Gemini 2.5 Flash** vision to identify food items, estimate portion mass through physical anchor calibration (plate size, cutlery reference), and return a structured nutritional breakdown. The Flutter camera app sends images to an Express.js API, which orchestrates AI analysis, post-processes unrealistic estimates, and persists verified "Case Files" to MongoDB. Users can refine AI estimates with haptic sliders, scan barcodes via Open Food Facts, or log meals manually.

---

![Flutter](https://img.shields.io/badge/Flutter-3.11%2B-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![Node.js](https://img.shields.io/badge/Node.js-20-339933?logo=nodedotjs)
![Express](https://img.shields.io/badge/Express-5.x-000000?logo=express)
![MongoDB](https://img.shields.io/badge/MongoDB-7-47A248?logo=mongodb)
![Gemini](https://img.shields.io/badge/Gemini-2.5%20Flash-4285F4?logo=googlegemini)
![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker)

---

## 📱 Screenshots

<!-- TODO: screenshot — capture the Camera Home, Dashboard, Meal Review, and Detective UI screens. -->
| Screen | Description |
|--------|-------------|
| *Camera Viewfinder* | Real-time camera with flash toggle, multi-angle capture mode, and shutter UI |
| *Meal Review (Detective UI)* | Bottom-sheet refinement modal with Notched Haptic Sliders (5g increments) per detected item |
| *Nutrition Dashboard* | Daily progress rings for calories, protein, carbs, fat; meal timeline; water tracker |
| *Meal History* | Searchable forensic archive of every logged Case File |
| *Goals & Calibration Hub* | Body metrics input with Mifflin-St Jeor TDEE auto-calculation and macro-split configuration |

---

## ⚡ Highlights

- **Volumetric reasoning prompt** — The core analyzer prompt (~100 lines) models physical anchors (plate diameter, cutlery), applies density curves per food category (0.1 g/cm³ for chips → 1.0 g/cm³ for meat), and explicitly instructs the model to halve its initial mass estimates to correct for documented vision-model overestimation bias.
- **Post-processing mass clamps** — After Gemini responds, `AnalyzerService._clampItemMasses()` cross-references detected food names against 15 category-specific ceilings (e.g., nuts ≤ 50g, meat portion ≤ 200g) and proportionally re-scales nutrition totals. This catches hallucinated portion sizes before they reach the user.
- **Multi-angle capture** — The Flutter camera supports single and multi-angle capture modes. When multiple images are present, the prompt switches to `MULTI-ANGLE ASSESSMENT MODE`, instructing Gemini to resolve occlusions and cross-reference perspectives for refined volume estimates.
- **Notched Haptic Slider** — A custom Flutter widget (`NotchedHapticSlider`) snaps to 5g increments with haptic feedback on each notch, giving the Detective UI a tactile, precision-instrument feel.
- **Domain language throughout** — The entire codebase uses product-specific terminology: `Case File` not `MealLog`, `massGrams` not `weight`, `compositionConfidence` not `confidenceScore`, `volumetricAnchors` not `scaleReference`. API error codes follow `ERR_DOMAIN_REASON` convention (e.g., `ERR_SCHEMA_INVALID`, `ERR_VISUAL_OBSCURED`).
- **Automatic TDEE recomputation** — When biometrics or phase change (bulk/cut/maintain), the server recomputes daily targets via Mifflin-St Jeor BMR × activity multiplier × phase adjustment without the user touching macro math.
- **Soft-delete Case Files** — Meal documents support `deletedAt` timestamps with a Mongoose pre-find hook that excludes deleted records by default, enabling "File Shredding" animations in the UI before permanent removal.
- **Open Food Facts barcode integration** — Scanned UPC/EAN barcodes fetch product data from Open Food Facts API, normalized to the same `NutritionProfile` schema used by AI-analyzed items for seamless interop in the Detective UI.

---

## 🏗 Architecture

```
┌──────────────────────┐
│   Flutter Mobile     │  camera, mobile_scanner, provider, google_fonts
│  ┌────────────────┐  │
│  │ Camera Vision  │──┼──► capture (base64 images)
│  │ Barcode Scanner│──┼──► GET /barcode/:ean
│  │ Detective UI   │  │
│  │ Dashboard      │  │
│  │ Meal History   │  │
│  │ Goal Engine    │  │
│  └────────────────┘  │
└─────────┬────────────┘
          │ HTTPS (JWT Bearer)
          ▼
┌──────────────────────┐
│  Express.js API      │  Node 20, Express 5, Zod 4, Mongoose 9
│  ┌────────────────┐  │
│  │ auth routes     │  │  POST /signup, /login → JWT (7d)
│  │ captures routes │  │  POST / → save image, call Gemini, return Case File
│  │ meals routes    │  │  GET / (query ?period=today), POST /confirm, POST / (manual), PATCH /:id
│  │ users routes    │  │  GET /me, PATCH /me, PATCH /metrics (TDEE recompute)
│  │ barcode routes  │  │  GET /:barcode → Open Food Facts proxy
│  │ presets routes  │  │  CRUD for quick-add food presets
│  │ water routes    │  │  CRUD for daily hydration logs
│  └────────────────┘  │
│  ┌────────────────┐  │
│  │ AnalyzerService │──┼──► Gemini 2.5 Flash
│  │ (prompt +      │  │    Volumetric reasoning prompt
│  │  post-process)  │  │    Mass clamps (15 categories)
│  └────────────────┘  │    Schema mapping (snake_case → camelCase)
└─────────┬────────────┘
          │ Mongoose
          ▼
┌──────────────────────┐
│   MongoDB 7          │
│  • users             │
│  • case_files (Meal) │
│  • captures          │
│  • presets           │
│  • water_logs        │
└──────────────────────┘
```

**Request lifecycle** (photo → Case File):
1. Flutter camera captures image(s) → base64-encodes → `POST /api/v1/captures` with JWT
2. Server saves images to disk (Docker volume at `backend/uploads/`), creates Capture document (`analysisStatus: analyzing`)
3. `AnalyzerService.analyzeCapture()` sends image(s) + volumetric reasoning prompt to Gemini 2.5 Flash
4. Gemini returns structured JSON with per-item nutrition estimates, bounding boxes, and confidence scores
5. Server runs `_clampItemMasses()` to cap unrealistic portions, then `mapToMealSchema()` to convert to Mongoose shape
6. Transient Case File returned to client → user reviews in Detective UI (adjusts masses, swaps alternatives)
7. User confirms → `POST /api/v1/meals/confirm` persists the Case File document

---

## 🛠 Tech Stack

| Layer | Technology | Version |
|-------|-----------|---------|
| **Mobile** | Flutter (Dart) | SDK ≥3.11.0, Flutter 3.x |
| **Mobile deps** | camera, mobile_scanner, provider, google_fonts, intl, lottie, image_picker, shared_preferences, path_provider, tutorial_coach_mark | (pubspec.yaml) |
| **Backend runtime** | Node.js | 20-alpine (Docker) |
| **Backend framework** | Express | ^5.2.1 |
| **AI** | Google Gemini 2.5 Flash | `@google/generative-ai` ^0.24.1 |
| **Validation** | Zod | ^4.3.6 |
| **Database** | MongoDB 7 | Mongoose ^9.3.3 |
| **Auth** | JWT (jsonwebtoken ^9.0.3) + bcryptjs ^3.0.3 | Bearer tokens, 7-day expiry |
| **Security** | Helmet ^8.1.0, CORS | Configurable allowed origins |
| **Logging** | Morgan ^1.10.1 | dev mode |
| **Infrastructure** | Docker Compose 3.8 | 3 services + 2 volumes |

---

## 📁 Project Structure

```
MacroLens/
├── backend/                         # Express.js API
│   ├── Dockerfile                   # Node 20-alpine, PORT=8181
│   ├── .env.example                 # Required: GEMINI_API_KEY, MONGO_URI, JWT_SECRET
│   └── src/
│       ├── server.js                # Entry point, route mounting, /health endpoint
│       ├── config/db.js             # Mongoose connect with retry (5 attempts, 3s delay)
│       ├── middleware/
│       │   ├── auth.js              # JWT verification middleware
│       │   └── errorHandler.js      # Zod/Mongoose/operational error normalization
│       ├── models/
│       │   ├── User.js              # email, password (hashed), biometrics, phase, macro split
│       │   ├── Meal.js              # "Case File" — detectedItems[], mealTotals, volumetricAnchors
│       │   ├── Capture.js           # Raw image capture — localPaths[], analysisStatus
│       │   ├── Preset.js            # Quick-add food presets
│       │   └── WaterLog.js          # Daily hydration entries
│       ├── routes/
│       │   ├── auth.js              # POST /signup, /login
│       │   ├── captures.js          # POST / (image upload + AI analysis pipeline)
│       │   ├── meals.js             # GET /, POST /confirm, POST / (manual), PATCH /:id
│       │   ├── users.js             # GET /me, PATCH /me, PATCH /metrics (TDEE recalc)
│       │   ├── barcode.js           # GET /:barcode (Open Food Facts proxy)
│       │   ├── presets.js           # CRUD (GET, POST, DELETE)
│       │   └── water.js             # CRUD (GET, POST, DELETE)
│       └── services/
│           └── analyzer.js          # Gemini prompt (volumetric reasoning), mass clamps, schema mapping
├── mobile/                          # Flutter application
│   ├── Dockerfile                   # Nginx serving flutter build/web
│   ├── nginx.conf                   # Reverse proxy /api/* → macrolens-backend:8181
│   ├── pubspec.yaml                 # Dart SDK ≥3.11.0
│   └── lib/
│       ├── main.dart                # App entry, Provider setup
│       ├── core/
│       │   ├── models/meal.dart     # Meal, DetectedItem, NutritionProfile, VolumetricAnchors
│       │   ├── models/preset.dart   # Preset model
│       │   ├── services/api_service.dart  # Singleton HTTP client (JWT, all endpoints)
│       │   └── theme/app_theme.dart # "Forensic Lens" dark theme (0px border-radius)
│       └── features/
│           ├── auth/                # Login/signup, onboarding, tutorial system
│           ├── camera_vision/       # Camera viewfinder, multi-angle capture, barcode scanner
│           ├── detective_refinement/# Meal review screen, refinement modal, Notched Haptic Slider
│           ├── nutrition_dashboard/ # Daily progress rings, macro breakdown, water tracker
│           ├── meal_history/        # Case File archive with search
│           ├── goal_engine/         # Biometrics, TDEE, macro split configuration
│           └── manual_entry/        # Quick-add form for manual food logging
├── scripts/                         # Dataset benchmarking utilities
│   ├── test_nutrition5k.js          # Benchmarks AnalyzerService against Nutrition5k ground truth
│   └── show_nutrition_data.js       # Data exploration helper for Nutrition5k
├── context/                         # Product design documents
│   ├── context.md                   # Product identity, feature spec, AI strategy
│   ├── design.md                    # "Forensic Lens" design system (colors, typography, components)
│   └── kickoff.md                   # Build order and engineering mandates
├── docker-compose.yml               # 3 services: mongo:7, backend, nginx-web
├── package.json                     # Root package (shared scripts)
└── README.md
```

---

## 🚀 Getting Started

### Prerequisites
- **Node.js 20+** (or Docker)
- **Flutter SDK ≥3.11.0** with Dart ≥3.11.0
- **MongoDB 7** (local or Docker)
- **Google Gemini API key** — [Get one from AI Studio](https://aistudio.google.com/)
- **Docker & Docker Compose** (for containerized deployment)

### Local Development

**1. Backend**
```bash
cd backend
cp .env.example .env
# Fill in: GEMINI_API_KEY, MONGO_URI, JWT_SECRET
npm install
npm run dev          # nodemon on port 3000
```

**2. Mobile (Flutter)**
```bash
cd mobile
flutter pub get
# Update lib/core/services/api_service.dart baseUrl to http://<your-ip>:3000/api/v1
flutter run
```

### Docker Deployment

```bash
# Set up backend environment
cp backend/.env.example backend/.env
# Edit backend/.env with real values

# Build and start all services
docker-compose up -d

# Services:
# - MongoDB 7          (internal: macrolens-db:27017)
# - Backend API        (internal: macrolens-backend:8181)
# - Flutter Web/Nginx  (exposes port 80, proxies /api/* to backend)
```

The Nginx container serves the Flutter web build and reverse-proxies `/api/` and `/health` to the backend. For production, place the stack behind a TLS-terminating reverse proxy (e.g., Caddy, Traefik, Nginx).

### Flutter Web Build (for Docker web container)

```bash
cd mobile
flutter build web
# Output goes to mobile/build/web → copied into Docker Nginx image
```

---

## ⚙ Configuration Reference

### Backend Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `3000` (dev), `8181` (Docker) | API listen port |
| `MONGO_URI` | *(required)* | MongoDB connection string (e.g. `mongodb://macrolens-db:27017/macrolens`) |
| `GEMINI_API_KEY` | *(required)* | Google Gemini API key for vision analysis |
| `JWT_SECRET` | `'dev-secret'` *(insecure fallback)* | Secret for signing JWTs — **must be set in production** |
| `ALLOWED_ORIGINS` | `*` | Comma-separated CORS origins |
| `NODE_ENV` | `development` | Set to `production` to mask error internals |

### Flutter Client Configuration

| Setting | Location | Description |
|---------|----------|-------------|
| `baseUrl` | `lib/core/services/api_service.dart:7` | API base URL — change for local dev vs. production |

### Docker Compose

| Service | Image/Port | Notes |
|---------|-----------|-------|
| `macrolens-db` | `mongo:7` | Data persisted in `macrolens-db-data` volume |
| `macrolens-backend` | Built from `./backend` | Env from `./backend/.env`, uploads in `macrolens-uploads` volume |
| `macrolens-web` | Built from `./mobile` | Serves Flutter web build via Nginx on port 80 |

---

## 🔌 API Reference

All endpoints prefixed with `/api/v1`. Authenticated routes require `Authorization: Bearer <token>` header.

### Auth
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/auth/signup` | No | Register (email + password, min 6 chars) → JWT |
| `POST` | `/auth/login` | No | Login → JWT (7 day expiry) |

### Captures
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `POST` | `/captures` | Yes | Upload base64 image(s), triggers Gemini analysis → transient Case File |

### Meals (Case Files)
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/meals?period=today` | Yes | Fetch meals (optional date filter) |
| `POST` | `/meals/confirm` | Yes | Persist a confirmed Case File from Detective UI |
| `POST` | `/meals` | Yes | Manual quick-add meal entry |
| `PATCH` | `/meals/:id` | Yes | Update item corrections (mass, name, verification status) |

### Users
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/users/me` | Yes | Get current user profile (excludes password) |
| `PATCH` | `/users/me` | Yes | Update display name, email, password, tutorial flag |
| `PATCH` | `/users/metrics` | Yes | Update biometrics, phase, macro split → auto-recomputes TDEE targets |

### Barcode
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/barcode/:barcode` | Yes | Lookup product nutrition via Open Food Facts |

### Presets
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/presets` | Yes | List user's quick-add presets |
| `POST` | `/presets` | Yes | Create a preset |
| `DELETE` | `/presets/:id` | Yes | Delete a preset |

### Water
| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| `GET` | `/water` | Yes | Get today's water logs |
| `POST` | `/water` | Yes | Add water log (amountMl, loggedAt) |
| `DELETE` | `/water/:id` | Yes | Delete a water log |

---

## 📊 Data Model

### User
| Field | Type | Notes |
|-------|------|-------|
| `email` | String, unique, indexed | Lowercased, trimmed |
| `password` | String | Bcrypt-hashed (salt rounds: 10) |
| `biometrics` | Embedded (massKg, heightCm, ageYears, biologicalSex, activityMultiplier) | Used for Mifflin-St Jeor TDEE |
| `currentPhase` | Enum: `bulk` / `cut` / `maintain` | Default: maintain |
| `dailyTargets` | Embedded (calories, proteinGrams, carbGrams, fatGrams) | Auto-computed or manual |
| `macroSplit` | proteinRatio, carbRatio, fatRatio | Default: 0.3/0.4/0.3 |

### Meal (Case File) — collection: `case_files`
| Field | Type | Notes |
|-------|------|-------|
| `userId` | ObjectId → User | Indexed |
| `captureId` | ObjectId → Capture | Links to source image |
| `caseFileId` | UUID string | Unique, immutable public identifier |
| `mealType` | Enum: breakfast/lunch/dinner/snack/unknown | |
| `loggedAt` | Date | Indexed |
| `overallConfidence` | Enum: high/medium/low | AI's composite confidence |
| `detectedItems[]` | Array of DetectedItem | At least 1 required; contains name, massGrams, nutritionPer100g, nutritionTotal, boundingBox, confidence, alternatives |
| `mealTotals` | NutritionProfile | Aggregated from items |
| `volumetricAnchors` | plateDiameterCm, anchorObject, calibrationMethod | AI calibration metadata |
| `entryMethod` | Enum: vision_capture/barcode_scan/manual_search/quick_add | |
| `deletedAt` | Date/null | Soft-delete timestamp |

### Capture
| Field | Type | Notes |
|-------|------|-------|
| `userId` | ObjectId → User | Indexed |
| `localPaths[]` | [String] | Server-side image paths (Docker volume) |
| `analysisStatus` | Enum: pending/analyzing/completed/failed | State machine |
| `resultMealId` | ObjectId → Meal | Set after user confirms |

---

## 🔧 Engineering Notes

- **Temperature 0 for Gemini** — The analyzer uses `generationConfig: { temperature: 0 }` for deterministic nutritional output. The prompt is fully self-contained with calibration examples; it doesn't rely on model creativity.
- **No USDA API integration (yet)** — The prompt instructs Gemini to output `usda_search_term` names, but there's no automated USDA FoodData Central lookup in the current pipeline. `usdaFoodId` fields exist in the schema but remain `null` until that integration is added.
- **JWT fallback secret** — The code falls back to `'dev-secret'` when `JWT_SECRET` is unset. This is acceptable for local development but **must be overridden with a strong secret in any deployed environment**. See security notes below.
- **Base64 in JSON** — Image uploads use base64-encoded JSON payloads (not multipart). The Express JSON body limit is set to `25mb` to accommodate this. For production at scale, consider switching to pre-signed upload URLs.
- **The `adam` Docker network** — `docker-compose.yml` joins the web container to an external network named `adam`. This is an infrastructure-specific detail for the developer's reverse proxy setup. Remove or rename for your own deployment.

---

## 🔐 Security & Privacy Notes

### Findings from codebase audit

| Severity | Finding | Location | Action |
|----------|---------|----------|--------|
| **Medium** | Hardcoded JWT fallback secret (`'dev-secret'`) | `backend/src/routes/auth.js:26,45`, `backend/src/middleware/auth.js:12` | Set `JWT_SECRET` env var in all deployed environments. Never rely on the fallback. |
| **Medium** | Production URL contains personal domain | `mobile/lib/core/services/api_service.dart:7` | The `adamzborovsky.com` domain exposes the developer's identity. Consider a generic project domain for open-source distribution. |
| **Low** | Docker network named `adam` | `docker-compose.yml:34` | Personal naming convention. Remove or rename for shared deployments. |

### What's already protected
- `.env` files are **not tracked** by git (confirmed via `git ls-files`)
- `.gitignore` patterns: `*.env`, `node_modules/`, `build/`
- Passwords are bcrypt-hashed (10 salt rounds) before storage
- All authenticated routes require JWT Bearer tokens
- Helmet middleware applied to all backend responses
- Production error handler masks internal details

### Action required from repo owner
1. **Rotate JWT secret** if the `dev-secret` fallback was ever used in a deployed environment with real user data
2. **Set `JWT_SECRET`** as a required environment variable; remove the `|| 'dev-secret'` fallback in production builds
3. **Consider using a project-specific domain** (e.g., `macrolens.app`) consistently instead of a personal domain in the open-source client code

---

## 🗺 Roadmap

- [ ] USDA FoodData Central API integration for verified nutrition lookups
- [ ] Nutritionix restaurant database integration
- [ ] Apple Health / Google Fit data sync
- [ ] CSV/PDF export for meal history
- [ ] Weekly progress digests and trend analysis
- [ ] Pre-signed URL image uploads (replace base64 JSON)
- [ ] Unit and integration test suite
- [ ] CI/CD pipeline with automated Flutter builds

---

## 📄 License

No license file is present in the repository. Consider adding one (e.g., MIT, Apache 2.0) to clarify usage terms for open-source distribution.

---

*Built with Gemini 2.5 Flash, Flutter, Express, and MongoDB.*
