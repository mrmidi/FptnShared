# FptnShared

Shared Swift package for FPTN Apple clients (iOS, macOS, tvOS).

## Goals

- Keep domain and application contracts in one place.
- Avoid duplicated models/parsers/config contracts across app and tunnel targets.
- Enable fast iteration with tagged releases (`v0.x`) and frequent updates.

## Package Products

- `FptnSharedCore`: Domain models and app/tunnel contracts.
- `FptnSharedTunnel`: Shared tunnel lifecycle abstractions.
- `FptnSharedTestSupport`: Test fixtures and helpers.

## Architecture Boundaries

- In package: Domain + Application contracts/use-cases.
- Outside package (in host apps): UI, target entitlements, target signing, Obj-C bridging headers, framework embedding.

## Release Policy

- Public repo.
- Fast iteration using `v0.x` semantic tags.
- App repos should pin to specific tags.

## Local Development

```bash
swift test
```
