# Swiftmender Forever

WoW Forever addon (Midnight-era API with secret aura values). See README.md for features and layout.

## Releasing (always)

Every change that is pushed must also be released to CurseForge (project id 1739421, also in the
TOC as `## X-Curse-Project-ID`):

1. Bump `## Version:` in `SwiftmenderForever.toc` (patch for fixes, minor for features).
2. Add a section for the new version at the top of `CHANGELOG.md`.
3. Commit and push.
4. Run the **Release** GitHub Actions workflow (`release.yml`) on the branch with input
   `version: vX.Y.Z`. It creates the tag, then BigWigsMods/packager uploads to CurseForge and makes a
   GitHub release. Check the job log for "Uploading ... Success!".
