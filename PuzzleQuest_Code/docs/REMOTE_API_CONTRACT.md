# PuzzleQuest Studio Remote API v1.1.0

API Origin: `https://<host>/api/studio/v1`.

## Authentication
One-time pairing token: Owner `/admin/studio`, fresh reauthentication required; 64 lowercase hex, 7-day expiry. Send `Authorization: Bearer <token>`; never append token to URLs. `StudioToken` middleware requires enabled admin with `owner` or `content` role and records last activity. Owner can revoke from UI. Never persist the token in app configuration or the update ZIP.

## Endpoints
| Verb | Endpoint | Action |
| --- | --- | --- |
| GET | `/schema` | Capabilities and backend version |
| GET / POST | `/worlds` | List / create Draft world |
| PATCH | `/worlds/{id}` | Title, position, publish/hidden; prevents publishing empty world |
| GET / POST | `/levels` | List / create Draft level |
| PATCH | `/levels/{id}` | Draft metadata (published structural fields locked) |
| POST | `/levels/{id}/unpublish` | Hide for new gameplay, retain historical revisions |
| GET | `/revisions` | Revisions |
| POST multipart | `/revisions/import` | `archive`: validated Jigsaw ZIP |
| POST | `/revisions/{uuid}/publish` | `device_qa_approved:true` |
| GET | `/documents/{kind}` | List documents for type |
| POST | `/documents` | Create Draft of a content type |
| PATCH | `/documents/{uuid}` | Save Draft; requires `draft_revision` |
| POST | `/documents/{uuid}/publish` | Copy draft to immutable public snapshot, requires QA + revision |
| POST | `/documents/{uuid}/retire` | Remove published item from public API; retain history |
| GET | `/documents/{uuid}/history` | Published revision list |
| POST | `/documents/{uuid}/restore/{revision}` | Restore old published snapshot to a NEW draft |
| GET | `/media` | UUID/image metadata |
| POST multipart | `/media` | `image`: safe PNG/JPEG/WebP, max 8 MB, 12 MP |
| GET public | `/api/v1/studio-content?kind=event` | Published content + referenced media URLs/hashes. Not authenticated, filters by world visibility and event window |

`kind` values: `collection`, `level_group`, `world_art`, `village_scene`, `village_item`, `event`, `mission`, `achievement`, `banner`, `story`.

## Example Village scene draft
```json
{
  "kind": "village_scene", "slug": "green-village",
  "world_id": "green_valley", "position": 1,
  "title": {"ar": "قرية الوادي", "en": "Green Valley Village"},
  "payload": {
    "background_asset_id": "IMAGE-UUID-FROM-MEDIA-API",
    "objects": [
      {"id":"cottage_l2", "asset_id":"SECOND-IMAGE-UUID", "x":0.35, "y":0.66,
       "scale":1.0, "z":12, "building_id":"cottage", "stage":2}
    ]
  }
}
```
Coordinates `x,y` normalized to [0,1]. `scale` 0.1..4. `stage` 0..4. `z` integer -100..100. `world_id` must exist in `worlds` table. File UUID references must exist in `studio_media`.

## Live rules / restrictions
- New `mission`/`event` documents are content definitions only. They are not activated as new reward or wallet logic without a separate, tested server policy and client support.
- Draft revision guard prevents concurrent overwrites. A saved Draft does NOT publish; Publish requires explicit QA.
- Existing published level identifiers, order/previous relationship cannot be changed from this API, protecting active gameplay.
- Media files are immutable; no destructive delete endpoint. Histories are append-only.
- Runtime player catalog includes `studio_content`; mobile must recognize/display these optional definitions to render them.
