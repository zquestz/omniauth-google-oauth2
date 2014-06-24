# Changelog
All notable changes to this project will be documented in this file.

## 0.2.4 - 2014-04-25

### Added
- Now requiring the "Contacts API" and "Google+ API" to be enabled in your Google API console.

### Deprecated
- The old Google OAuth API support was removed without deprecation.

### Removed
- Support for the old Google OAuth API. `OAuth2::Error` will be thrown and state that access is not configured when you attempt to authenticate using the old API. See Added section for this release.

### Fixed
- Nothing.
