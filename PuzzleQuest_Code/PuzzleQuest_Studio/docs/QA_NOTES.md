# Technical QA notes

## Piece geometry

Each internal horizontal or vertical edge is sampled once using four smooth cubic Bézier segments forming a protruding knob or its complementary indentation. Every adjacent polygon consumes the shared edge, reversed. This prevents independent piece curves from disagreeing.

Rendering creates the whole-image crop with a transparency mask at 2× raster resolution, downsamples to antialias the boundary, and stores **lossless** RGBA WebP plus the matching PNG mask. The unaltered source for puzzle geometry is the **decoded WebP source shipped in the package**, so texture checks are exact rather than comparing a later JPEG/WebP transform to an earlier one.

## Quality standards (automatic)

- Valid square grid: 4, 6, 8 or 10 rows and columns, exactly matching piece count.
- All piece IDs `p000..pNNN`, unique (row, col), stable normalized snap targets.
- Mask cannot be blank, disconnected or different from the piece alpha.
- Source must not be nearly uniform; adjust photo/artwork rather than bypassing this gate.
- No uncovered pixels (alpha coverage <200); broad three-way alpha ownership invalid.
- Serialized geometry reconstructs original outlines and mask planes within antialias tolerance.
- Full per-file digest and ZIP safety verification. UUIDv4 is generated on every build.

## Limitations

A geometrically valid pack is not proof that Flutter/Flame drag/snap, timers, ads or server access operate. The game runtime must be integrated and tested. This release intentionally rejects incompatible piece counts rather than silently changing the on-device schema.

The current preview is a 2D composite with the actual cut outline, not a playable desktop drag-and-drop simulation. Actual drag/snap must be checked in the mobile client before publication.

## 1.0.3 Dashboard screenshot defect
- Reproduced root-name mismatch: missing `level.json` and `manifest.json` in old exporter.
- 26 local Python tests pass; missing either required JSON blocks Quality Gate; manifest tampering detected even after package re-hash.
- 100-piece stage 1-6, genuine image, 24 archive checks pass; no actual authenticated Dashboard upload was performed.
