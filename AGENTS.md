# Project instructions

## Code signing

- LayoutLight is a public project. Sign every runnable application binary, including local debug builds handed to the user for testing, with the `Developer ID Application` certificate for team `VKH47WM4KC`.
- Do not use `CODE_SIGNING_ALLOWED=NO` or an ad hoc signature for user-testable builds. Rebuilding an ad hoc-signed executable changes its TCC identity and forces the user to remove and grant Accessibility permission again.
- Keep the bundle identifier `com.biyachuev.LayoutLight` and the signing identity stable across test builds so macOS can preserve Accessibility authorization.
- The repository is inside a file-provider-backed `Documents` folder. If extended attributes prevent `codesign`, build in a local temporary Derived Data directory, verify the Developer ID signature, and then copy the signed `.app` to the expected project build path.
