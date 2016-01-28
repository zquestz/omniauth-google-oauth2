# Changelog
All notable changes to this project will be documented in this file.

## 0.3.1 - 2016-01-28

### Added
- Verify Hosted Domain if hd is set in options.

### Deprecated
- Nothing.

### Removed
- Dependency on addressable.

### Fixed
- Nothing.

## 0.3.0 - 2016-01-09

### Added
- Updated verify_token to use the v3 tokeninfo endpoint.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Compatibility with omniauth-oauth2 1.4.0

## 0.2.10 - 2015-11-05

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Removed some checks on the id_token. Now only parses the id_token in the JWT processing.

### Fixed
- Nothing.

## 0.2.9 - 2015-10-29

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Issue with omniauth-oauth2 where redirect_uri was handled improperly. We now lock the dependency to ~> 1.3.1

## 0.2.8 - 2015-10-01

### Added
- Added skip_jwt option to bypass JWT decoding in case you get decoding errors.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Resolved JWT::InvalidIatError. https://github.com/zquestz/omniauth-google-oauth2/issues/195

## 0.2.7 - 2015-09-25

### Added
- Now strips out the 'sz' parameter from profile image urls.
- Now uses 'addressable' gem for URI actions.
- Added image data to extras hash.
- Override validation on JWT token for open_id token.
- Handle authorization codes coming from an installed applications.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Fixes double slashes in google image urls.

## 0.2.6 - 2014-10-26

### Added
- Nothing.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Hybrid authorization issues due to bad method alias.

## 0.2.5 - 2014-07-09

### Added
- Support for versions of omniauth past 1.0.x.

### Deprecated
- Nothing.

### Removed
- Nothing.

### Fixed
- Nothing.

## 0.2.4 - 2014-04-25

### Added
- Now requiring the "Contacts API" and "Google+ API" to be enabled in your Google API console.

### Deprecated
- The old Google OAuth API support was removed without deprecation.

### Removed
- Support for the old Google OAuth API. `OAuth2::Error` will be thrown and state that access is not configured when you attempt to authenticate using the old API. See Added section for this release.

### Fixed
- Nothing.
