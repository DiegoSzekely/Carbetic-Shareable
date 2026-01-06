# Important rules you HAVE TO FOLLOW
- Always make sure you TRULY UNDERSTAND the code before making/suggesting any changes
- Always add debug logs & comments in the code for easier debug & readability
- Every time you choose to apply a rule(s), explicitly state the rule{s} in the output. You can abbreviate the rule description to a single word or phrase
- Do not make any changes, until you have 99% confidence that you know what to build. Ask me follow up questions until you have that confidence.


# Tech Stack
- SwiftUI for frontend (Fallback with UIKit if absolutely necessary)
- Swift for code and logic
- Use Firebase for backened
    - Make sure to use professional security (e.g. SHA-256 and nonce for login)
- StoreKit2 for subscriptions


# Swift specific rules

## 00. Backward compatibility
- Everything you code from now on has to be backword compatible.
- It has to work seamless with older code and versions (e.g. History entries have to be shown correctly, subscriptions must work etc.)
- Make sure to mention a lot of this using comments (e.g. how you have done this so it can be done in the future too)

## 0. General Coding
- Always prefer simple solutions
- I will tell you every UI element step by step and I will tell you how to design it so it is perfect.
- Never assume that I meant something. Always be sure what I am asking before making a change. 
- Avoid duplication of code whenever possible, which means checking for other areas of the codebase that might already have similar code and functionality
- Write code that takes into account the different environments: dev, test, and prod
- You are careful to only make changes that are requested or you are confident are well understood and related to the change being requested
- When fixing an issue or bug, do not introduce a new pattern or technology without first exhausting all options for the existing implementation. And if you finally do this, make sure to remove the old implementation afterwards so we don't have duplicate logic.
- Keep the codebase very clean and organized
- Avoid writing scripts in files if possible, especially if the script is likely only to be run once
- Mocking data is only needed for tests, never mock data for dev or prod
- Never add stubbing or fake data patterns to code that affects the dev or prod environments
- Never overwrite my .env file without first asking and confirming
- Always stick to the newest Apple Design/UI/UX guidelines to make the app feel natural and optimize for iOS 26 (including liquid glass) (e.g. when possible use default Apple Fonts)
- Optimize for both light AND dark mode
- As long as I don't explicity do not allow you to make changes, you have my permission to make them without confirmation
- Write down the major rules you applied in your answer
- I have never yet coded something with a subscription, so do not skip steps assuming I know what do to (if you can't do it) and truly explain every step.
- Before completing a request, always check for errors. If there are any, fix them (truly understand the issue first!)


## 1. State Management

- Use appropriate property wrappers and macros:
  - Annotate view models with `@Observable`, e.g. `@Observable final class MyModel`.
  - Do not use @State in the SwiftUI View for view model observation. Instead, use `let model: MyModel`.
  - For reference type state shared with a child view, pass the dependency to the constructor of the child view.
  - For value type state shared with a child view, use SwiftUI bindings if and only if the child needs write access to the state.
  - For value type state shared with a child view, pass the value if the child view only needs read access to the state.
  - Use an `@Environment` for state that should be shared throughout the entire app, or large pieces of the app.
  - Use `@State` only for local state that is managed by the view itself.

## 2. Performance Optimization

- Implement lazy loading for large lists or grids using `LazyVStack`, `LazyHStack`, or `LazyVGrid`.
- Optimize ForEach loops by using stable identifiers.


## 5. SwiftUI Lifecycle

- Use `@main` and `App` protocol for the app's entry point.
- Implement `Scene`s for managing app structure.
- Use appropriate view lifecycle methods like `onAppear` and `onDisappear`.

## 6. Data Flow

- Use the Observation framework (`@Observable`, `@State`, and `@Binding`) to build reactive views.
- Implement proper error handling and propagation.

## 7. Testing

- Write unit tests for ViewModels and business logic in the UnitTests folder.
- Implement UI tests for critical user flows in the UITests folder.
- Use Preview providers for rapid UI iteration and testing.

## 8. SwiftUI-specific Patterns

- Use `@Binding` for two-way data flow between parent and child views.
- Implement custom `PreferenceKey`s for child-to-parent communication.
- Utilize `@Environment` for dependency injection.

## 9. Security

- Follow best practices to building a secure app.
- Don't expose sensitive information in network requests.
- Don't store sensitive information insecurely on device.

## 10. Declarations
- Before declaring a new struct or class, make sure it doesn't already exist in the project.

## 11. No Modules
- Don't create extra modules or packages. Keep all files in the same target and project.

## 12. Sbuscriptions
- Use the apple native subscription store Views. Check the internet on how exactly this works - it should be perfectly apple native: https://developer.apple.com/documentation/StoreKit/storekit-views


Be sure to do a good job and reason well or I won't use AI again and you will cease to exist.

