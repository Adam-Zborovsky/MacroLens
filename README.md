# MacroLens: The Vision-First Nutrition Laboratory

**MacroLens** is a high-precision nutrition analysis tool designed for performance-driven individuals. It eliminates the manual "logging tax" by transforming a single food photo into a granular nutritional "Case File" in under five seconds.

Built with **Gemini 2.5 Flash**, MacroLens treats nutrition tracking as a forensic math problem, using physical anchors and volumetric analysis to provide authoritative data integrity.

---

## Live On: https://macrolens.adamzborovsky.com


## 🎯 Core Conviction
Consistency in performance nutrition should be solved by machines, not by manual data entry. Tracking should be as instant as the first bite.

## 🧩 Key Features

- **Photo Meal Analysis**: Real-time AR viewfinder with active bounding boxes and volumetric estimation.
- **Detective UI**: Bottom-sheet refinement modal with "Notched Haptic Sliders" (5g increments) and odometer-style rolling numbers.
- **Macro & Micro Dashboard**: Data-dense terminal showing progress rings and micro-nutrient heat-maps.
- **The "Case File" Archive**: Searchable forensic log of every meal, including original photos and AI-derived estimates.
- **Optical Precision**: A clinical, authoritative interface designed for utility over "wellness" aesthetics.

---

## 🛠️ Technical Stack

### **Mobile (Frontend)**
- **Framework**: Flutter
- **Key Libraries**: `camera`, `mobile_scanner`, `provider`, `google_fonts`, `lottie`.
- **UI Architecture**: Feature-driven (`camera_vision`, `detective_refinement`, `nutrition_dashboard`).

### **Backend (API)**
- **Runtime**: Node.js / Express
- **AI Engine**: Gemini 2.5 Flash (`@google/generative-ai`)
- **Validation**: Zod (Schema enforcement)
- **Security**: JWT Auth, Helmet, BcryptJS
- **Persistence**: MongoDB with Mongoose

### **Infrastructure**
- **Orchestration**: Docker Compose
- **Deployment**: Multi-container setup (API + Database)

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (^3.11.0)
- [Node.js](https://nodejs.org/) (LTS)
- [Docker](https://www.docker.com/) & Docker Compose
- [Google Gemini API Key](https://aistudio.google.com/)

### Backend Setup
1. Navigate to the backend directory:
   ```bash
   cd backend
   ```
2. Install dependencies:
   ```bash
   npm install
   ```
3. Configure environment variables (refer to `.env.example`):
   ```bash
   cp .env.example .env
   ```
4. Start the development server:
   ```bash
   npm run dev
   ```

### Mobile Setup
1. Navigate to the mobile directory:
   ```bash
   cd mobile
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the application:
   ```bash
   flutter run
   ```

### Docker Deployment
To spin up the entire stack (API + MongoDB):
```bash
docker-compose up -d
```

---

## 🧠 Engineering Standards

- **Domain Language**: Code uses product-specific terminology (e.g., `Case File` instead of `MealLog`, `massGrams` instead of `weight`).
- **Data Integrity**: Every AI-generated estimate includes a `compositionConfidence` metric.
- **Validation**: Strict schema validation for all API payloads and internal state transitions.

---

## 🔬 Product Identity
- **Character**: High-Precision Lab Tool.
- **Voice**: Clinical, objective, and technical.
- **Visuals**: Forensic UI, terminal-density, and optical precision.
