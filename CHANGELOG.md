# Changelog

## [Container Image Deployment] - 2026-02-04

### Added
- **Container Image Deployment**: Lambda now deploys as a container image instead of ZIP package
- `backend/lambda/Dockerfile` - Defines Lambda container image based on AWS Python 3.12 base
- `CONTAINER_MIGRATION.md` - Comprehensive guide explaining the migration
- `deployment-comparison.sh` - Visual comparison script showing before/after

### Changed
- **SAM Template** (`backend/infrastructure/template.yaml`):
  - Set `PackageType: Image` for Lambda function
  - Removed `Runtime` from Globals (incompatible with Image PackageType)
  - Removed `CodeUri` and `Handler` properties
  - Added `Metadata` section with Dockerfile configuration
- **Deployment Script** (`deploy-safe.sh`):
  - Changed build command from `sam build --use-container` to `sam build`
  - Updated messaging to clarify container image building
- **Documentation**:
  - `README.md`: Added "Container-Native" feature, updated architecture diagram
  - `DEPLOYMENT_INSTRUCTIONS.md`: Updated build steps and troubleshooting
  - `.gitignore`: Added `*.whl` exclusion

### Benefits
- 🎯 **Larger Size Limit**: 10GB vs 250MB for ZIP packages (40x increase)
- 🔧 **Better Dependencies**: Eliminates binary compatibility issues
- 🐳 **Consistency**: Same container from development to production
- 🚀 **Modern Approach**: Container-native deployment aligned with AWS best practices
- 🧪 **Local Testing**: Run exact production environment locally
- ✅ **No Version Issues**: Eliminates "Binary validation failed for python" errors

### Migration Notes
- **Zero Breaking Changes**: Deployment process remains identical for users
- Existing deployments will automatically migrate to container images on next deployment
- Same command: `./deploy-safe.sh`
- SAM automatically manages ECR repository creation and image pushing

---

## [Region Fix & UX Modernization] - 2026-02-04

### Fixed
- **Region Configuration**: Changed from `us-east-1` to `us-east-2` in `samconfig.toml`
- **Deployment Blockers**: Added pre-flight validation and automatic region mismatch detection

### Added
- `deploy-safe.sh` - Safe deployment script with comprehensive validation
- `validate-self.sh` - End-to-end deployment validation
- `backend/infrastructure/cleanup.sh` - Cleanup script for failed deployments
- Modern dark mode UI with AWS orange theme

### Changed
- **Frontend Modernization**:
  - Dark mode design (`#1a1a1a` background)
  - AWS Orange theme (`#FF9900`)
  - Enhanced UX features (Ctrl+Enter, auto-resize, typing indicator)
  - Improved markdown rendering
  - Mobile responsive design
- **Documentation**: Updated README with troubleshooting and new deployment process

### Benefits
- 🎨 Professional, modern UI
- 🔧 Automatic deployment validation and fixing
- 🧹 Orphaned resource cleanup
- 📱 Mobile-responsive interface
- ⌨️ Better keyboard shortcuts
