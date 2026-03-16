[![Build Status](https://github.com/pqrs-org/cpp-osx-accessibility/workflows/CI/badge.svg)](https://github.com/pqrs-org/cpp-osx-accessibility/actions)
[![License](https://img.shields.io/badge/license-Boost%20Software%20License-blue.svg)](https://github.com/pqrs-org/cpp-osx-accessibility/blob/main/LICENSE.md)

# cpp-osx-accessibility

Utilities of macOS accessibility APIs.

## Requirements

cpp-osx-accessibility depends the following classes.

- [pqrs::cf::dictionary](https://github.com/pqrs-org/cpp-cf-dictionary).

## Install

Copy `include/pqrs` and `vendor/vendor/include` directories into your include directory.

And then configure your project as follows:

- `src/pqrs/osx/accessibility/PQRSOSXAccessibilityMonitorImpl.swift`
- `include/pqrs/osx/accessibility/impl/Bridging-Header.h` as Bridging Header
