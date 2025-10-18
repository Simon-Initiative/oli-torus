---
title: Media heavy document with embedded base64 image payloads.
---

# Media Library Smoke Test

This sample exercises the image ingestion path by embedding data URLs that should be decoded, deduplicated, and uploaded into the Torus media library.

![][image1]

The same binary appears again below and should trigger the hash-based reuse behaviour rather than a second upload.

![][image2]

Supplemental guidance:

- Validate the importer warns when an image exceeds 5 MB.
- If uploads fail, fall back to the original data URL and surface a warning.
- Capture telemetry for `uploaded_media_count`, `media_bytes`, and dedupe hits.

All binaries have their base64 encoded data at the end of the document.

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lIG2VwAAAABJRU5ErkJggg==>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/lIG2VwAAAABJRU5ErkJggg==>

