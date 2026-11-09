# Contributing to Helium

Thank you for your interest in contributing to **Helium**!

## Development Setup

1. Clone the repository and copy `GoogleService-Info.plist.example` to `GoogleService-Info.plist` (or `.env.example` to `.env`).
2. Run the test suite to verify your local environment:
   ```bash
   swift test
   ```
3. Build the macOS app bundle:
   ```bash
   ./scripts/build-app-bundle.sh
   ```

## Pull Request Guidelines

- **Never commit credentials**: Ensure `GoogleService-Info.plist`, `google-services.json`, `.env`, and any signing certificates remain untracked.
- **Tests required**: Add or update unit tests in `Tests/OrbitCoreTests/` for any changes to `OrbitCore`, storage allocation, sync reconciliation, or cryptography.
- **Conventional Commits**: Use clear commit messages (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`).
