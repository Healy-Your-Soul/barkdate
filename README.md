# BarkDate 🐕

A Flutter app for dog owners to organize playdates and connect with other dog parents.

## Features

### 🐕 Dog Management
- Multi-dog profiles with photos
- 3-tier sharing system (Co-owner, Caregiver, Dogwalker)
- Many-to-many dog ownership support

### 📅 Playdates
- Schedule and manage dog playdates
- Location-based meetups
- Photo sharing and recap

### 📱 Cross-Platform
- Flutter Web and Mobile support
- Web-safe image handling
- Responsive design

## Getting Started

### Prerequisites
- Flutter SDK
- Supabase account
- Firebase account (for notifications)

### Quick Start

1. **Environment Setup:**
   ```bash
   cp .env.example .env
   # Fill in your Supabase and Firebase credentials
   ```

2. **Run Development Server:**
   ```bash
   ./run_dev.sh
   ```

3. **Run with Secrets (Production):**
   ```bash
   ./run_with_secrets.sh
   ```

## Project Structure

```
lib/
├── models/          # Data models
├── services/        # Business logic and API calls
├── screens/         # UI screens
├── widgets/         # Reusable UI components
├── supabase/        # Database utilities
└── data/           # Data layer

supabase/
├── migrations/      # Database schema changes
└── config.toml     # Supabase configuration

assets/
├── images/         # App images
└── sounds/         # Audio assets
```

## Key Services

- **DogSharingService**: Manage dog ownership and sharing
- **PlaydateService**: Handle playdate scheduling and management
- **PhotoUploadService**: Cross-platform image handling
- **FirebaseMessagingService**: Push notifications

## Database

Uses Supabase with PostgreSQL for:
- User authentication
- Dog profiles and ownership
- Playdate scheduling
- Photo storage
- Real-time notifications

## Development

### Architecture
- Clean architecture with separation of concerns
- Provider pattern for state management
- Repository pattern for data access

### Web Compatibility
- Uses `SelectedImage` for cross-platform image handling
- Avoids `dart:io` in web builds
- Web-safe image handling
- Responsive design for all screen sizes

## 🔄 Updates & Maintenance

BarkDate uses a dual-layer update system:
- **OTA Patches**: Powered by [Shorebird](https://shorebird.dev) for instant, silent bug fixes.
- **Remote Config**: Managed via Supabase for required major updates.

See the [Updates Management Guide](UPDATES_GUIDE.md) for instructions on how to push patches and require updates.

## Support

For issues and feature requests, please check the draft folder for additional documentation and implementation guides.
