# Draft Folder - Archived Files

This folder contains files that were moved during the September 2025 project cleanup to maintain a clean root directory structure.

## Organization

### 📁 `sql_archive/`
Contains 42 SQL files that were used during development and testing:
- Database migration scripts
- Schema fixes and updates
- Test data creation scripts
- Function definitions and triggers
- These files are preserved for reference but not actively used

### 📁 `documentation/`
Contains all project documentation and markdown files:
- Sprint plans and implementation guides
- Architecture documentation
- Setup instructions and guides
- Reference materials
- `mds/` - Main documentation folder
- `docs/` - Additional documentation

### 📁 `test_files/`
Contains test files and experimental code:
- Test Dart files for various features
- Disabled or old test implementations
- Experimental service files
- Test run scripts
- Test import file from lib folder

### 📁 `unused_screens/`
Contains 19 unused/duplicate Flutter screen files:
- Alternative admin screen implementations
- Multiple map screen variants (enhanced, fixed, robust, simplified, placeholder, simple)
- Various playdate screen versions (legacy, minimal, simple, complex)
- Backup and disabled screen files
- Unused share link handler screen
- These screens were replaced by cleaner, consolidated versions

### 📁 Root Level Files
- `index.html` - Old HTML file (replaced by web/index.html)
- `quick_start.sh` - Old start script (replaced by run_dev.sh)

## Active Project Structure

The main project now has a clean structure with only essential files:
- `lib/` - Flutter application code
- `android/`, `ios/`, `web/` - Platform-specific code
- `supabase/` - Active database schema and migrations
- `assets/` - App resources
- Core config files (pubspec.yaml, analysis_options.yaml, etc.)
- Active scripts (run_dev.sh, run_with_secrets.sh)

## Recovery

If any of these files are needed again, they can be moved back to the root directory or integrated into the active project structure.
