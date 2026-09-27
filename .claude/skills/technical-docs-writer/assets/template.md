# [Feature / Service Name]

## Overview

[What this does and why it exists. 2–4 sentences. Skip preamble — start with what it is.]

## Architecture & Data Flow

- **Upstream (calls into this):** [services / clients that call this]
- **Downstream (this calls out to):** [services, databases, queues, third-party APIs]
- **Data stores touched:** [tables, collections, caches, topics]

[Optional: 1 short paragraph or bullet list walking through the flow for the main use case, e.g. "A request arrives at X, which validates Y, writes to Z, then publishes an event consumed by W."]

## API Endpoints / Contract

Only include the methods the endpoint actually supports — delete the rest of this section's rows and blocks rather than leaving unused methods as placeholders.

| Method | Path | Auth | Description |
|---|---|---|---|
| `GET` | `/example` | Required / None | [one line] |
| `POST` | `/example` | Required / None | [one line] |
| `PUT` | `/example/{id}` | Required / None | [one line] |
| `PATCH` | `/example/{id}` | Required / None | [one line] |
| `DELETE` | `/example/{id}` | Required / None | [one line] |

**`GET /example`**

Request (query params, if any):
```
?param=value
```

Response: `200 OK`
```json
{}
```

Errors:
| Status | Meaning |
|---|---|
| `400` | [when] |
| `404` | [when] |

---

**`POST /example`**

Request:
```json
{}
```

Response: `201 Created`
```json
{}
```

Errors:
| Status | Meaning |
|---|---|
| `400` | [when] |
| `409` | [when — e.g. duplicate/conflict] |

---

**`PUT /example/{id}`**

Full-resource replacement — request body should contain the complete resource, not a partial update.

Request:
```json
{}
```

Response: `200 OK`
```json
{}
```

Errors:
| Status | Meaning |
|---|---|
| `400` | [when] |
| `404` | [when resource doesn't exist] |

---

**`PATCH /example/{id}`**

Partial update — request body contains only the fields being changed.

Request:
```json
{}
```

Response: `200 OK`
```json
{}
```

Errors:
| Status | Meaning |
|---|---|
| `400` | [when] |
| `404` | [when resource doesn't exist] |

---

**`DELETE /example/{id}`**

Request: none (path param only)

Response: `204 No Content` (or `200 OK` with a confirmation body, if the API returns one)

Errors:
| Status | Meaning |
|---|---|
| `404` | [when resource doesn't exist] |
| `409` | [when — e.g. can't delete due to dependent resources] |

## Business Logic

- [Validation rule or edge case, with the reasoning behind it if non-obvious]
- [Another rule]

<!-- Remove any section above that doesn't apply to this feature (e.g. no API Endpoints section for a background worker). -->