 **Developer Execution Prompt**

> Read `context.md` to understand the product identity and `design.md` for the visual direction. The product identity in these files is the ground truth — use that language everywhere: component names, variable names, commit messages. Reference the Functional Element Map in `design.md` before implementing any UI — every interactive element must be wired to real logic. **The `/ui-ux-pro-max` skill is your design intelligence** — invoke it before any Stitch call or frontend design decision. It provides styles, palettes, font pairings, UX guidelines, and chart types tailored to the product.

### Mission
We are building **MacroLens**, a vision-first nutrition laboratory that eliminates the manual "logging tax" for high-performance individuals. Using Gemini 2.5 Flash, the app transforms food photos into verified macro-nutrient "Case Files" in under five seconds. 

**Core Conviction**: Tracking performance nutrition should be as instant as the first bite.

### Mandate
Use `context.md` for engineering decisions and `design.md` for visual direction and Stitch generation. The `/ui-ux-pro-max` skill is your primary design intelligence — invoke it before any Stitch call or frontend design decision. NO PLACEHOLDER UI — every button must be wired to real logic per the Functional Element Map.

### Stack & Setup
- **Mobile**: `flutter create macro_lens_mobile`
- **Backend**: `mkdir macro_lens_api && cd macro_lens_api && npm init -y && npm install express mongoose zod google-generative-ai`

### Build Order

**Session 1: Generate UI with Stitch (DO THIS FIRST — before any code)**
1. **Invoke the `/ui-ux-pro-max` skill FIRST.** Use it with the Product Design Identity from `design.md` to determine the "Optical Precision" style, color palette, and technical typography.
2. Follow the **Stitch Generation Guide** in `design.md` step-by-step.
3. For each screen prompt: lead with `ui-ux-pro-max` decisions, followed by the specific screen context.
4. After all screens are generated, call `get_project` to retrieve and overwrite `design.md`.
5. Download Stitch assets (HTML/CSS/Images) to use as the base for Flutter UI components.
6. **Quality Check**: If the generated screens look like a generic recipe app, your prompt was too soft. Re-generate using "forensic lab tool" and "clinical terminal" descriptors.

**Session 2: Foundation & Data Models**
1. Implement the `User`, `Capture`, and `Meal` (Case File) schemas.
2. Set up the calibration logic for physical object anchors.
3. **Quality Check**: Use product language (e.g., `massGrams`, `compositionConfidence`) instead of generic `weight` or `score`.

**Session 3: AI Pipeline & API**
1. Integrate Gemini 2.5 Flash for multimodal processing.
2. Build the `analyzer` service to stream bounding box data and macro-estimates.
3. **Quality Check**: Ensure the API handles "Optimistic UI" states where the app shows scanning animations while the AI processes.

**Session 4: Flutter High-Precision UI**
1. Implement the `Camera Home Screen` with the 45-degree angle reticle.
2. Build the `Detective UI` refinement modal with the "Notched Haptic Slider."
3. **Quality Check**: Every haptic click must feel deliberate; every "odometer" rolling number must be smooth.

**Session 5: Dashboard & Reporting**
1. Build the metabolic "Information Terminal" and PDF "Nutrition Summary" export.

### First File to Write
`macro_lens_api/src/models/Meal.js` — Defining the "Case File" structure that anchors the nutritional data integrity.
