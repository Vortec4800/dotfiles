---
paths:
  - "**/*.{kt,kts,gradle}"
  - "**/gradle/libs.versions.toml"
  - "**/gradle.properties"
  - "**/AndroidManifest.xml"
  - "**/Material_3_Expressive_Guide.md"
---

# Android / Kotlin platform rules

**Scope: Android/Kotlin projects only.** Everything in this section applies exclusively to Android app development using Kotlin and Jetpack Compose.

### Build System

- Always use the Gradle wrapper (`./gradlew`) for all build operations — never call `gradle` directly
- Dependencies are managed via **version catalogs** in `gradle/libs.versions.toml`
- Use Kotlin DSL (`build.gradle.kts`) for build scripts

Common commands:
```bash
./gradlew build              # Full build
./gradlew assembleDebug      # Debug APK
./gradlew assembleRelease    # Release APK
./gradlew installDebug       # Install on connected device/emulator
./gradlew clean              # Clean build outputs
```

### Testing

```bash
./gradlew test                      # Unit tests
./gradlew connectedAndroidTest      # Instrumented tests (requires device/emulator)
./gradlew test --tests "com.example.*TestClassName*"  # Specific test class
```

### Linting

```bash
./gradlew lint          # Run lint checks
./gradlew lintDebug     # Generate lint report
```

### Kotlin & Jetpack Compose Conventions

#### Language & framework

- **Kotlin** exclusively — no Java for new code
- **Jetpack Compose** for all UI — no XML layouts
- **Kotlin coroutines** for all asynchronous operations
- **Kotlinx Serialization** for JSON serialization/deserialization
- Follow Kotlin official code style

#### Architecture

- **Single Activity** pattern — one Activity hosts all Compose content
- **MVVM**: ViewModels manage UI state, Screens observe and display
- **Navigation Compose** for screen navigation
- Data layer separated from UI layer (`data/` vs `ui/`)

#### Compose guidelines

- Use `@Preview` annotations for composable previews
- Maintain **stateless composables** where possible — hoist state up
- Handle state hoisting appropriately (state goes up, events go down)
- Prefer reusing existing components before creating new ones

#### Models

- `@Serializable` data classes with `@SerialName` for JSON field mapping
- Use enums for discrete types with serialization support

#### State management

- ViewModels expose state via `StateFlow` or Compose `State`
- UI collects state with `collectAsStateWithLifecycle()` or reads Compose state directly
- Avoid holding UI state in Activities or Composables — use ViewModels

#### Error handling

- Sealed classes/interfaces for typed error states
- UI shows error states with retry options
- Use `Result` or custom sealed types for operation outcomes

### Material 3 Expressive

Android projects use **Material 3 Expressive** as the design language. If a project contains a `Material_3_Expressive_Guide.md`, always reference it when:
- Implementing UI components or screens
- Making design decisions about colors, typography, shapes, or motion
- Working with animations or transitions
- Choosing between component variants

Key principles:
- Prefer Material 3 Expressive components over standard Material 3 when available
- Use spring-based animations and expressive easing curves
- Apply expressive typography scales with clear hierarchy
- Utilize larger corner radiuses and expressive shapes
- Add meaningful micro-interactions and haptic feedback

### Project Structure Convention (Android)

Typical structure:
```
app/
  src/main/java/com/company/appname/
    MainActivity.kt
    AppApplication.kt
    data/
      auth/       # Authentication
      api/        # API/network services
      models/     # Data models
    ui/
      theme/      # Material3 theme (Color.kt, Theme.kt, Type.kt)
      screens/    # Screen composables + ViewModels, organized by feature
      components/ # Reusable UI components
  src/main/res/   # Resources
  src/test/       # Unit tests
  src/androidTest/ # Instrumented tests
gradle/
  libs.versions.toml  # Version catalog
```
