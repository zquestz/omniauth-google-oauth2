# Changelog

All notable changes to this project will be documented in this file.

## 1.2.3 - 2026-08-31

### Security

- Verify caller-supplied ID tokens against Google's published signing keys before trusting them. An ID token sent alongside a direct `access_token` callback was previously decoded without checking its signature, so `extra.id_info` and `extra.id_token` could be populated from a forged token. `uid` and `info` were never affected, as they come from the userinfo endpoint. ID tokens genuinely issued by Google continue to work unchanged.
- Require a caller-supplied ID token to describe the same user as the access token it was sent with, by comparing the token's `sub` against the userinfo subject. A verified signature only proves Google issued the token, not that it belongs to the person the access token identifies, so without this a genuine ID token for one user could be paired with an access token for another and leave `uid` and `extra.id_info` describing different people. The `at_hash` claim is checked first as a fast path, and this subject check settles the cases `at_hash` cannot: tokens that omit the claim, and tokens whose `at_hash` is stale because the client refreshed its access token after sign-in. This check runs even when `skip_info` is set, as that option trims the auth hash rather than waiving verification.

### Added

- `reset_jwks_cache!` for clearing the cached Google signing keys, which is useful in test suites.
- `JWKS_URL`, `JWKS_CACHE_TTL`, `JWKS_RETRY_INTERVAL`, `JWKS_OPEN_TIMEOUT`, `JWKS_READ_TIMEOUT`, `JWKS_WRITE_TIMEOUT`, `JWKS_TOTAL_TIMEOUT`, and `JWKS_MAX_BYTES` constants, and a `JwksUnavailable` error.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Ignore `refresh_token` and token expiry supplied by the caller in direct access-token callbacks, as neither can be verified.
- Avoid decoding opaque access tokens as JWTs when no ID token is available.
- Fail with a normal authentication failure when a callback carries no usable credential, such as an ID token with no access token, a JSON body that is not an object, or an unparseable body. These previously raised `NoMethodError` or `TypeError` on their way out of the callback.
- Serve the cached signing keys when Google's key endpoint is briefly unreachable, and back off before refetching, rather than retrying on every request.
- Fetch Google's signing keys over a dedicated connection with certificate verification and timeouts of its own, instead of the strategy's OAuth2 client. This keeps `client_options` from deciding whether the keys that authenticate every ID token are themselves authenticated. Note that a custom certificate authority supplied through `client_options` no longer applies to this request; use the `SSL_CERT_FILE` or `SSL_CERT_DIR` environment variables instead. Proxy environment variables are still honoured.
- Cap how often an ID token naming an unrecognised key can force a key refresh, so it cannot be used to drive unbounded outbound requests while holding the shared cache lock. Key rotation still resolves within `JWKS_RETRY_INTERVAL`.
- `jwt_leeway` now also applies when verifying caller-supplied ID tokens, matching how it already behaved for the `extra` block.
- Support non-rewindable JSON request bodies under Rack 3.

## 1.2.2 - 2026-02-23

### Added

- Ruby 4.0 support.

### Deprecated

- Nothing.

### Removed

- Unused `IMAGE_SIZE_REGEXP` constant.
- Dead `skip_friends` and `skip_image_info` options (Google+ was shut down in 2019).

### Fixed

- Replaced `CGI.parse` with `URI.decode_www_form` for Ruby 4.0 compatibility.
- Updated gemspec description to reference OmniAuth instead of OmniAuth 1.x.
- Modernized CI: bumped actions/checkout to v6, rake to 13.3, and rubocop to latest.
- Added edge case tests for `uid`, `strip_unnecessary_query_parameters`, `verify_token`, `verify_hd` wildcard, and malformed JSON handling.

## 1.2.1 - 2025-01-18

### Added

- Use jwt v2.9.2's public claims verification API - https://github.com/zquestz/omniauth-google-oauth2/pull/465

### Deprecated

- Nothing.

### Removed

- Support for jwt < 2.9.2.

### Fixed

- Nothing.

## 1.2.0 - 2024-09-15

### Added

- jwt 2.9.0 support for their updated claims code.

### Deprecated

- Nothing.

### Removed

- Ruby 2.3 and 2.4 support.
- Support for jwt < 2.9.0.

### Fixed

- Fixed image sizing code.
- Rubocop configuration updates.

## 1.1.3 - 2024-08-29

### Added

- Updated to use POST instead of GET for tokeninfo endpoint.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Documentation typos.
- Rubocop configuration updates.

## 1.1.2 - 2024-03-28

### Added

- Add support for enable_granular_consent option (#455)

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing.

## 1.1.1 - 2022-09-05

### Added

- Nothing.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Fixed JWT decoding issue. (Invalid segment encoding) [#431](https://github.com/zquestz/omniauth-google-oauth2/pull/431)

## 1.1.0 - 2022-09-03

### Added

- `overridable_authorize_options` has been added to restrict overriding authorize_options by request params. [#423](https://github.com/zquestz/omniauth-google-oauth2/pull/423)
- Support for oauth2 2.0.x. [#429](https://github.com/zquestz/omniauth-google-oauth2/pull/429)

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing.

## 1.0.1 - 2022-03-10

### Added

- Output granted scopes in credentials block of the auth hash.
- Migrated to GitHub actions.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Overriding the `redirect_uri` via params or JSON request body.

## 1.0.0 - 2021-03-14

### Added

- Support for Omniauth 2.x!

### Deprecated

- Nothing.

### Removed

- Support for Omniauth 1.x.

### Fixed

- Nothing.

## 0.8.2 - 2021-03-14

### Added

- Constrains the version to Omniauth 1.x.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing.

## 0.8.1 - 2020-12-12

### Added

- Support reading the access token from a json request body.

### Deprecated

- Nothing.

### Removed

- No longer verify the iat claim for JWT.

### Fixed

- A few minor issues with .rubocop.yml.
- Issues with image resizing code when the image came with size information from Google.

## 0.8.0 - 2019-08-21

### Added

- Updated omniauth-oauth2 to v1.6.0 for security fixes.

### Deprecated

- Nothing.

### Removed

- Ruby 2.1 support.

### Fixed

- Nothing.

## 0.7.0 - 2019-06-03

### Added

- Ensure `info[:email]` is always verified, and include `unverified_email`

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing.

## 0.6.1 - 2019-03-07

### Added

- Return `email` and `email_verified` keys in response.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing.

## 0.6.0 - 2018-12-28

### Added

- Support for JWT 2.x.

### Deprecated

- Nothing.

### Removed

- Support for JWT 1.x.
- Support for `raw_friend_info` and `raw_image_info`.
- Stop using Google+ API endpoints.

### Fixed

- Nothing.

## 0.5.4 - 2018-12-07

### Added

- New recommended endpoints for Google OAuth.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Nothing.

## 0.5.3 - 2018-01-25

### Added

- Added support for the JWT 2.x gem.
- Now fully qualifies the `JWT` class to prevent conflicts with the `Omniauth::JWT` strategy.

### Deprecated

- Nothing.

### Removed

- Removed the `multijson` dependency.
- Support for versions of `omniauth-oauth2` < 1.5.

### Fixed

- Nothing.

## 0.5.2 - 2017-07-30

### Added

- Nothing.

### Deprecated

- Nothing.

### Removed

- New `authorize_url` and `token_url` endpoints are reverted until JWT 2.0 ships.

### Fixed

- Nothing.

## 0.5.1 - 2017-07-19

### Added

- _Breaking_ JWT iss verification can be enabled/disabled with the `verify_iss` flag - see the README for more details.
- Authorize options now includes `device_id` and `device_name` for private ip ranges.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Updated `authorize_url` and `token_url` to new endpoints.

## 0.5.0 - 2017-05-29

### Added

- Rubocop checks to specs.
- Defaulted dev environment to ruby 2.3.4.

### Deprecated

- Nothing.

### Removed

- Testing support for older versions of ruby not supported by OmniAuth 1.5.
- Key `[:urls]['Google']` no longer exists, it has been renamed to `[:urls][:google]`.

### Fixed

- Updated all code to rubocop conventions. This includes the Ruby 1.9 hash syntax when appropriate.
- Example javascript flow now picks up ENV vars for google key and secret.

## 0.4.1 - 2016-03-14

### Added

- Nothing.

### Deprecated

- Nothing.

### Removed

- Nothing.

### Fixed

- Fixed JWT iat leeway by requiring ruby-jwt 1.5.2

## 0.4.0 - 2016-03-11

### Added

- Addedd ability to specify multiple hosted domains.
- Added a default leeway of 1 minute to JWT token validation.
- Now requires ruby-jwt 1.5.x.

### Deprecated

- Nothing.

### Removed

- Removed support for ruby 1.9.3 as ruby-jwt 1.5.x does not support it.

### Fixed

- Nothing.

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
