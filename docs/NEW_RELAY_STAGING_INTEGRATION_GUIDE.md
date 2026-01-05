# Divine Funnelcake Mobile Integration Guide

A comprehensive guide for integrating Flutter and React Native apps with the Divine Funnelcake Nostr relay and video analytics API.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [REST API Reference](#rest-api-reference)
5. [WebSocket Relay Protocol](#websocket-relay-protocol)
6. [Authentication](#authentication)
7. [Video Events Schema](#video-events-schema)
8. [Engagement Events](#engagement-events)
9. [Flutter Integration](#flutter-integration)
10. [React Native Integration](#react-native-integration)
11. [Common Patterns](#common-patterns)
12. [Error Handling](#error-handling)
13. [Best Practices](#best-practices)

---

## Overview

Divine Funnelcake provides two complementary services for video-focused Nostr apps:

| Service | Protocol | Port | Purpose |
|---------|----------|------|---------|
| **cake** | WebSocket | 7777 | Real-time Nostr relay (events, subscriptions) |
| **funnel** | HTTP | 8080 | Video analytics REST API (search, trending, stats) |

**Key Benefits for Mobile:**
- Real-time updates via WebSocket (no polling)
- Pre-computed trending scores (fast feeds)
- Full-text search
- NIP-98 auth (use existing Nostr keys, no passwords)
- Stateless API (mobile-friendly caching)

---

## Architecture

```
┌─────────────────────────────────────┐
│         Mobile App                  │
│     (Flutter / React Native)        │
├─────────────────────────────────────┤
│  Nostr Client Library               │
│  (key management, signing)          │
└───────────┬─────────────┬───────────┘
            │             │
    WebSocket             HTTP
            │             │
            ▼             ▼
┌───────────────┐  ┌───────────────┐
│     cake      │  │    funnel     │
│  ws://:7777   │  │  http://:8080 │
│               │  │               │
│  • Subscribe  │  │  • /api/videos│
│  • Publish    │  │  • /api/search│
│  • Real-time  │  │  • /api/stats │
└───────┬───────┘  └───────┬───────┘
        │                  │
        └────────┬─────────┘
                 ▼
        ┌───────────────┐
        │  ClickHouse   │
        │  (storage)    │
        └───────────────┘
```

### When to Use Each Service

| Use Case | Service | Why |
|----------|---------|-----|
| Video feed (home, trending) | REST API | Pre-computed, cacheable |
| Search videos | REST API | Full-text search optimized |
| Creator profile videos | REST API | Paginated, sorted |
| Live video updates | WebSocket | Real-time push |
| Post reaction/comment | WebSocket | Standard Nostr protocol |
| Watch for new followers | WebSocket | Event subscriptions |
| Admin moderation | REST API | NIP-86 management |

---

## Quick Start

### 1. Fetch Trending Videos (REST)

```bash
curl https://relay.divine.video/api/videos?sort=trending&limit=20
```

### 2. Connect to Relay (WebSocket)

```javascript
const ws = new WebSocket('wss://relay.divine.video');
ws.send(JSON.stringify(["REQ", "feed", {"kinds": [34235, 34236], "limit": 50}]));
```

### 3. Subscribe to Video Reactions

```javascript
ws.send(JSON.stringify([
  "REQ",
  "reactions",
  {"kinds": [7], "#e": ["<video-event-id>"]}
]));
```

---

## REST API Reference

### Base URL
- Production: `https://relay.divine.video`
- Staging: `https://funnelcake.staging.dvines.org`
- Local: `http://localhost:8080`

### Response Format

All responses are JSON. Success responses contain data directly. Errors return:

```json
{
  "error": "Error message"
}
```

### Endpoints

#### GET /api/videos

List videos with optional sorting.

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `sort` | string | `recent` | `recent` or `trending` |
| `kind` | number | - | Filter: `34235` (long) or `34236` (short) |
| `limit` | number | 50 | Max results (1-100) |

**Response:** `VideoStats[]`

```json
[
  {
    "id": "a376c65d2f232afbe9b882a35baa4f6fe8667c4e684749af565f981833ed6a65",
    "pubkey": "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
    "created_at": "2024-01-05T10:30:45.000Z",
    "kind": 34235,
    "d_tag": "my-video-2024",
    "title": "How to Build on Nostr",
    "thumbnail": "https://cdn.example.com/thumb.jpg",
    "video_url": "https://cdn.example.com/video.mp4",
    "reactions": 142,
    "comments": 23,
    "reposts": 8,
    "engagement_score": 234,
    "trending_score": 187.5
  }
]
```

**Examples:**

```bash
# Trending videos
GET /api/videos?sort=trending&limit=20

# Recent short-form videos
GET /api/videos?sort=recent&kind=34236&limit=50

# Recent long-form videos
GET /api/videos?kind=34235
```

---

#### GET /api/videos/{id}/stats

Get detailed stats for a specific video.

**Path Parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `id` | string | 64-char hex event ID |

**Response:** `VideoStats`

```json
{
  "id": "a376c65d...",
  "pubkey": "6e468422...",
  "created_at": "2024-01-05T10:30:45.000Z",
  "kind": 34235,
  "d_tag": "my-video-2024",
  "title": "How to Build on Nostr",
  "thumbnail": "https://cdn.example.com/thumb.jpg",
  "video_url": "https://cdn.example.com/video.mp4",
  "reactions": 142,
  "comments": 23,
  "reposts": 8,
  "engagement_score": 234
}
```

**Engagement Score Formula:**
```
engagement_score = reactions + (comments × 2) + (reposts × 3)
```

---

#### GET /api/users/{pubkey}/videos

Get all videos by a specific creator.

**Path Parameters:**

| Param | Type | Description |
|-------|------|-------------|
| `pubkey` | string | 64-char hex public key |

**Query Parameters:**

| Param | Type | Default | Description |
|-------|------|---------|-------------|
| `limit` | number | 50 | Max results (1-100) |

**Response:** `VideoStats[]`

---

#### GET /api/search

Search videos by text or hashtag.

**Query Parameters:**

| Param | Type | Required | Description |
|-------|------|----------|-------------|
| `q` | string | One of q/tag | Full-text search query |
| `tag` | string | One of q/tag | Hashtag (without #) |
| `limit` | number | No | Max results (default 50) |

**Examples:**

```bash
# Full-text search
GET /api/search?q=bitcoin tutorial&limit=20

# Hashtag search
GET /api/search?tag=nostr&limit=50
```

**Response:** `VideoStats[]` or `VideoHashtag[]`

---

#### GET /api/stats

Get global platform statistics.

**Response:**

```json
{
  "total_events": 1500000,
  "total_videos": 45000
}
```

---

#### Health Endpoints

| Endpoint | Purpose | Response |
|----------|---------|----------|
| `GET /livez` | Liveness probe | `200 OK` |
| `GET /readyz` | Readiness probe | `200 OK` or `503` |
| `GET /health` | Legacy health check | `{"status": "ok"}` |

---

## WebSocket Relay Protocol

### Connection

```
wss://relay.divine.video              (production)
wss://funnelcake.staging.dvines.org   (staging)
ws://localhost:7777                   (local)
```

### Message Types

#### Client → Relay

| Message | Format | Description |
|---------|--------|-------------|
| EVENT | `["EVENT", {event}]` | Publish an event |
| REQ | `["REQ", "sub-id", {filter}, ...]` | Subscribe |
| CLOSE | `["CLOSE", "sub-id"]` | Unsubscribe |
| COUNT | `["COUNT", "sub-id", {filter}]` | Count events |

#### Relay → Client

| Message | Format | Description |
|---------|--------|-------------|
| EVENT | `["EVENT", "sub-id", {event}]` | Received event |
| OK | `["OK", "event-id", true/false, "msg"]` | Publish result |
| EOSE | `["EOSE", "sub-id"]` | End of stored events |
| NOTICE | `["NOTICE", "message"]` | Server notice |
| COUNT | `["COUNT", "sub-id", {"count": N}]` | Count result |
| CLOSED | `["CLOSED", "sub-id", "reason"]` | Subscription closed |

### Filter Syntax

```typescript
interface Filter {
  ids?: string[];           // Event IDs (prefix match)
  authors?: string[];       // Author pubkeys (prefix match)
  kinds?: number[];         // Event kinds
  since?: number;           // Min timestamp (Unix)
  until?: number;           // Max timestamp (Unix)
  limit?: number;           // Max events
  search?: string;          // Full-text search (NIP-50)
  "#e"?: string[];          // Event references
  "#p"?: string[];          // Pubkey references
  "#t"?: string[];          // Hashtags
  "#d"?: string[];          // Identifier tags
}
```

### Common Subscription Patterns

**Recent videos:**
```json
["REQ", "videos", {"kinds": [34235, 34236], "limit": 50}]
```

**Videos from followed users:**
```json
["REQ", "feed", {
  "kinds": [34235, 34236],
  "authors": ["pubkey1", "pubkey2", "pubkey3"],
  "limit": 100
}]
```

**Live reactions on a video:**
```json
["REQ", "reactions", {
  "kinds": [7],
  "#e": ["video-event-id"]
}]
```

**Comments on a video (NIP-22):**
```json
["REQ", "comments", {
  "kinds": [1111],
  "#E": ["video-event-id"]
}]
```

**Note:** Use uppercase `#E` to get ALL comments on a video regardless of nesting depth.

**Videos by hashtag:**
```json
["REQ", "hashtag", {
  "kinds": [34235, 34236],
  "#t": ["nostr"],
  "limit": 50
}]
```

**Search (NIP-50):**
```json
["REQ", "search", {
  "kinds": [34235, 34236],
  "search": "bitcoin tutorial",
  "limit": 50
}]
```

---

## Authentication

### Bearer Token (API)

For protected API endpoints (if configured):

```http
Authorization: Bearer <API_TOKEN>
```

### NIP-98 HTTP Auth (Management API)

For NIP-86 relay management, sign HTTP requests with Nostr keys.

**Header Format:**
```http
Authorization: Nostr <base64-encoded-event>
```

**Event Structure (kind 27235):**

```json
{
  "id": "<computed>",
  "pubkey": "<your-pubkey>",
  "created_at": 1704500000,
  "kind": 27235,
  "tags": [
    ["u", "https://relay.divine.video/management"],
    ["method", "POST"],
    ["payload", "<sha256-of-request-body>"]
  ],
  "content": "",
  "sig": "<schnorr-signature>"
}
```

**Validation Requirements:**
- Timestamp within 60 seconds of server time
- URL tag matches request URL exactly
- Method tag matches HTTP method
- Payload tag = SHA256 hex of request body
- Valid Schnorr signature
- Pubkey in server's `ADMIN_PUBKEYS` list

---

## Event Kinds Reference

Divine.video uses these Nostr event kinds:

| Kind  | Name                     | NIP    | Purpose                      |
|-------|--------------------------|--------|------------------------------|
| 0     | User Profiles            | NIP-01 | Display names, avatars, bios |
| 34236 | Addressable Short Videos | NIP-71 | Primary video content        |
| 1111  | Comments                 | NIP-22 | Comments/replies on videos   |
| 16    | Generic Reposts          | NIP-18 | Resharing videos             |
| 7     | Reactions                | NIP-25 | Likes/hearts                 |
| 3     | Contact Lists            | NIP-02 | Follow/following             |
| 5     | Deletions                | NIP-09 | Unlike, delete comments      |
| 30005 | Curation Sets            | NIP-51 | Curated video playlists      |
| 10000 | Mute Lists               | NIP-51 | Content blocking             |

**Note:** Kind 1 (text notes) is for replies to other text notes. Kind 1111 is for comments on non-Kind-1 events like videos.

---

## Video Events Schema

### Video Event (Kind 34236)

Divine.video primarily uses **kind 34236** for short-form videos:

| Kind | Description |
|------|-------------|
| 34236 | Short-form video (primary for divine.video) |
| 34235 | Long-form video (optional) |

**Event Structure:**

```json
{
  "id": "a376c65d2f232afbe9b882a35baa4f6fe8667c4e684749af565f981833ed6a65",
  "pubkey": "6e468422dfb74a5738702a8823b9b28168abab8655faacb6853cd0ee15deee93",
  "created_at": 1704500000,
  "kind": 34235,
  "tags": [
    ["d", "unique-video-identifier"],
    ["title", "Video Title Here"],
    ["thumb", "https://cdn.example.com/thumbnail.jpg"],
    ["url", "https://cdn.example.com/video.mp4"],
    ["t", "nostr"],
    ["t", "tutorial"],
    ["t", "bitcoin"],
    ["duration", "1234"],
    ["description", "Long description of the video"]
  ],
  "content": "Optional content/description",
  "sig": "908a15e46fb4d8675bab026fc230a0e3542bfade63da02d542fb78b2a8513fcd..."
}
```

**Required Tags:**

| Tag | Description |
|-----|-------------|
| `d` | Unique identifier (enables updates) |
| `title` | Video title |
| `thumb` | Thumbnail URL |
| `url` | Video file URL |

**Optional Tags:**

| Tag | Description |
|-----|-------------|
| `t` | Hashtag (multiple allowed) |
| `duration` | Length in seconds |
| `description` | Detailed description |
| `p` | Mentioned pubkeys |
| `e` | Referenced events |

### Publishing a Video (Pseudocode)

```javascript
const videoEvent = {
  kind: 34235,
  created_at: Math.floor(Date.now() / 1000),
  tags: [
    ["d", "my-video-" + Date.now()],
    ["title", "My Awesome Video"],
    ["thumb", thumbnailUrl],
    ["url", videoUrl],
    ["t", "nostr"],
    ["t", "video"]
  ],
  content: "Description of my video"
};

// Sign with Nostr library
const signedEvent = await nostr.signEvent(videoEvent);

// Publish via WebSocket
ws.send(JSON.stringify(["EVENT", signedEvent]));
```

---

## Engagement Events

### Reaction (Kind 7)

Like or react to a video:

```json
{
  "kind": 7,
  "created_at": 1704500100,
  "tags": [
    ["e", "target-video-event-id"],
    ["p", "video-author-pubkey"]
  ],
  "content": "+"
}
```

**Content Values:**
- `+` = Like
- `-` = Dislike
- Custom emoji (`:fire:`)
- Any string

### Comment (Kind 1111) - NIP-22

**Important:** Divine.video uses **kind 1111** for comments, not kind 1. This follows NIP-22 for commenting on non-Kind-1 events.

NIP-22 uses uppercase/lowercase tag convention:
- **Uppercase (E, K, P)** = Root scope (always points to the VIDEO)
- **Lowercase (e, k, p)** = Parent item (for threading)

**Top-level comment on a video:**

```json
{
  "kind": 1111,
  "created_at": 1704500200,
  "tags": [
    ["E", "video-event-id", "", "video-author-pubkey"],
    ["K", "34236"],
    ["P", "video-author-pubkey"],
    ["e", "video-event-id", "", "video-author-pubkey"],
    ["k", "34236"],
    ["p", "video-author-pubkey"]
  ],
  "content": "Great video! Very informative."
}
```

**Reply to a comment (nested):**

```json
{
  "kind": 1111,
  "created_at": 1704500300,
  "tags": [
    ["E", "video-event-id", "", "video-author-pubkey"],
    ["K", "34236"],
    ["P", "video-author-pubkey"],
    ["e", "parent-comment-id", "", "comment-author-pubkey"],
    ["k", "1111"],
    ["p", "comment-author-pubkey"]
  ],
  "content": "Thanks! I'm glad you liked it."
}
```

**Tag Reference:**

| Tag | Case | Description |
|-----|------|-------------|
| `E` | Upper | Root event ID (always the video) |
| `K` | Upper | Root event kind (34236) |
| `P` | Upper | Root event author pubkey |
| `e` | Lower | Parent event ID (video or parent comment) |
| `k` | Lower | Parent event kind (34236 or 1111) |
| `p` | Lower | Parent event author pubkey |

**Querying Comments:**
- Get ALL comments on a video: Filter by `#E` = video-event-id
- Build thread hierarchy: Use lowercase `e` tags to find parent relationships

### Repost (Kind 16)

Share a video using generic repost (NIP-18):

```json
{
  "kind": 16,
  "created_at": 1704500300,
  "tags": [
    ["e", "target-video-event-id"],
    ["p", "video-author-pubkey"],
    ["k", "34236"]
  ],
  "content": ""
}
```

### Deletion (Kind 5)

Delete a reaction, comment, or other event:

```json
{
  "kind": 5,
  "created_at": 1704500400,
  "tags": [
    ["e", "event-id-to-delete"]
  ],
  "content": "Deleted by user"
}
```

**Note:** You can only delete your own events (same pubkey).

---

## Curation Sets / Playlists (Kind 30005)

Create curated video collections:

```json
{
  "kind": 30005,
  "created_at": 1704500500,
  "tags": [
    ["d", "my-playlist-id"],
    ["title", "Best Nostr Videos"],
    ["description", "A curated collection of great content"],
    ["image", "https://example.com/cover.jpg"],
    ["e", "video-event-id-1"],
    ["e", "video-event-id-2"],
    ["a", "34236:pubkey:video-d-tag"]
  ],
  "content": ""
}
```

**Tag Reference:**

| Tag | Description |
|-----|-------------|
| `d` | Playlist identifier (makes it replaceable) |
| `title` | Playlist title |
| `description` | Playlist description |
| `image` | Cover image URL |
| `e` | Video event ID reference |
| `a` | Addressable event reference (kind:pubkey:d-tag) |

---

## Contact Lists (Kind 3)

Following/followers:

```json
{
  "kind": 3,
  "created_at": 1704500600,
  "tags": [
    ["p", "followed-pubkey-1", "wss://relay1.example.com"],
    ["p", "followed-pubkey-2", "wss://relay2.example.com"],
    ["p", "followed-pubkey-3"]
  ],
  "content": "{\"wss://relay1.example.com\": {\"read\": true, \"write\": true}}"
}
```

---

## Flutter Integration

### Recommended Packages

```yaml
dependencies:
  # Nostr protocol
  nostr: ^1.0.0           # or dart_nostr

  # WebSocket
  web_socket_channel: ^2.4.0

  # HTTP
  dio: ^5.0.0

  # State management
  riverpod: ^2.0.0        # or bloc, provider
```

### API Client

```dart
import 'package:dio/dio.dart';

class DivineFunnelcakeApi {
  final Dio _dio;
  final String baseUrl;

  DivineFunnelcakeApi({
    required this.baseUrl,
    String? apiToken,
  }) : _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    headers: apiToken != null
      ? {'Authorization': 'Bearer $apiToken'}
      : null,
  ));

  /// Get trending videos
  Future<List<VideoStats>> getTrendingVideos({int limit = 50}) async {
    final response = await _dio.get('/api/videos', queryParameters: {
      'sort': 'trending',
      'limit': limit,
    });
    return (response.data as List)
        .map((json) => VideoStats.fromJson(json))
        .toList();
  }

  /// Get videos by creator
  Future<List<VideoStats>> getVideosByAuthor(String pubkey, {int limit = 50}) async {
    final response = await _dio.get('/api/users/$pubkey/videos', queryParameters: {
      'limit': limit,
    });
    return (response.data as List)
        .map((json) => VideoStats.fromJson(json))
        .toList();
  }

  /// Search videos
  Future<List<VideoStats>> searchVideos(String query, {int limit = 50}) async {
    final response = await _dio.get('/api/search', queryParameters: {
      'q': query,
      'limit': limit,
    });
    return (response.data as List)
        .map((json) => VideoStats.fromJson(json))
        .toList();
  }

  /// Search by hashtag
  Future<List<VideoStats>> searchByHashtag(String tag, {int limit = 50}) async {
    final response = await _dio.get('/api/search', queryParameters: {
      'tag': tag,
      'limit': limit,
    });
    return (response.data as List)
        .map((json) => VideoStats.fromJson(json))
        .toList();
  }

  /// Get video stats
  Future<VideoStats> getVideoStats(String eventId) async {
    final response = await _dio.get('/api/videos/$eventId/stats');
    return VideoStats.fromJson(response.data);
  }
}

class VideoStats {
  final String id;
  final String pubkey;
  final DateTime createdAt;
  final int kind;
  final String dTag;
  final String title;
  final String thumbnail;
  final String videoUrl;
  final int reactions;
  final int comments;
  final int reposts;
  final int engagementScore;
  final double? trendingScore;

  VideoStats({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.dTag,
    required this.title,
    required this.thumbnail,
    required this.videoUrl,
    required this.reactions,
    required this.comments,
    required this.reposts,
    required this.engagementScore,
    this.trendingScore,
  });

  factory VideoStats.fromJson(Map<String, dynamic> json) {
    return VideoStats(
      id: json['id'],
      pubkey: json['pubkey'],
      createdAt: DateTime.parse(json['created_at']),
      kind: json['kind'],
      dTag: json['d_tag'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'] ?? '',
      videoUrl: json['video_url'] ?? '',
      reactions: json['reactions'] ?? 0,
      comments: json['comments'] ?? 0,
      reposts: json['reposts'] ?? 0,
      engagementScore: json['engagement_score'] ?? 0,
      trendingScore: json['trending_score']?.toDouble(),
    );
  }
}
```

### WebSocket Relay Client

```dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class NostrRelayClient {
  final String relayUrl;
  WebSocketChannel? _channel;
  final _eventController = StreamController<NostrEvent>.broadcast();
  final _subscriptions = <String, List<Map<String, dynamic>>>{};

  NostrRelayClient({required this.relayUrl});

  Stream<NostrEvent> get events => _eventController.stream;

  Future<void> connect() async {
    _channel = WebSocketChannel.connect(Uri.parse(relayUrl));

    _channel!.stream.listen(
      (message) => _handleMessage(jsonDecode(message)),
      onError: (error) => print('WebSocket error: $error'),
      onDone: () => print('WebSocket closed'),
    );
  }

  void _handleMessage(List<dynamic> message) {
    final type = message[0] as String;

    switch (type) {
      case 'EVENT':
        final subId = message[1] as String;
        final eventJson = message[2] as Map<String, dynamic>;
        _eventController.add(NostrEvent.fromJson(eventJson, subId));
        break;
      case 'EOSE':
        // End of stored events for subscription
        print('EOSE: ${message[1]}');
        break;
      case 'OK':
        final eventId = message[1];
        final accepted = message[2] as bool;
        final reason = message[3] as String;
        print('Event $eventId: ${accepted ? "accepted" : "rejected: $reason"}');
        break;
      case 'NOTICE':
        print('Notice: ${message[1]}');
        break;
    }
  }

  /// Subscribe to events
  String subscribe(List<Map<String, dynamic>> filters, {String? subId}) {
    final id = subId ?? 'sub-${DateTime.now().millisecondsSinceEpoch}';
    _subscriptions[id] = filters;

    final request = ['REQ', id, ...filters];
    _channel?.sink.add(jsonEncode(request));

    return id;
  }

  /// Unsubscribe
  void unsubscribe(String subId) {
    _subscriptions.remove(subId);
    _channel?.sink.add(jsonEncode(['CLOSE', subId]));
  }

  /// Publish an event
  void publish(Map<String, dynamic> signedEvent) {
    _channel?.sink.add(jsonEncode(['EVENT', signedEvent]));
  }

  /// Subscribe to video feed
  String subscribeToVideos({List<String>? authors, int limit = 50}) {
    final filter = <String, dynamic>{
      'kinds': [34235, 34236],
      'limit': limit,
    };
    if (authors != null) filter['authors'] = authors;

    return subscribe([filter]);
  }

  /// Subscribe to reactions for a video
  String subscribeToReactions(String videoEventId) {
    return subscribe([
      {'kinds': [7], '#e': [videoEventId]}
    ]);
  }

  /// Subscribe to comments for a video (NIP-22)
  String subscribeToComments(String videoEventId) {
    return subscribe([
      {'kinds': [1111], '#E': [videoEventId]}  // Uppercase E for root scope
    ]);
  }

  void disconnect() {
    _channel?.sink.close();
  }
}

class NostrEvent {
  final String id;
  final String pubkey;
  final int createdAt;
  final int kind;
  final List<List<String>> tags;
  final String content;
  final String sig;
  final String? subscriptionId;

  NostrEvent({
    required this.id,
    required this.pubkey,
    required this.createdAt,
    required this.kind,
    required this.tags,
    required this.content,
    required this.sig,
    this.subscriptionId,
  });

  factory NostrEvent.fromJson(Map<String, dynamic> json, [String? subId]) {
    return NostrEvent(
      id: json['id'],
      pubkey: json['pubkey'],
      createdAt: json['created_at'],
      kind: json['kind'],
      tags: (json['tags'] as List)
          .map((t) => (t as List).map((e) => e.toString()).toList())
          .toList(),
      content: json['content'],
      sig: json['sig'],
      subscriptionId: subId,
    );
  }

  String? getTagValue(String tagName) {
    for (final tag in tags) {
      if (tag.isNotEmpty && tag[0] == tagName && tag.length > 1) {
        return tag[1];
      }
    }
    return null;
  }

  List<String> getTagValues(String tagName) {
    return tags
        .where((t) => t.isNotEmpty && t[0] == tagName && t.length > 1)
        .map((t) => t[1])
        .toList();
  }
}
```

### Usage Example (Flutter)

```dart
class VideoFeedScreen extends StatefulWidget {
  @override
  _VideoFeedScreenState createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  // Production
  final api = DivineFunnelcakeApi(baseUrl: 'https://relay.divine.video');
  final relay = NostrRelayClient(relayUrl: 'wss://relay.divine.video');

  // Staging (uncomment to use):
  // final api = DivineFunnelcakeApi(baseUrl: 'https://funnelcake.staging.dvines.org');
  // final relay = NostrRelayClient(relayUrl: 'wss://funnelcake.staging.dvines.org');

  List<VideoStats> videos = [];

  @override
  void initState() {
    super.initState();
    _loadTrendingVideos();
    _connectRelay();
  }

  Future<void> _loadTrendingVideos() async {
    final trending = await api.getTrendingVideos(limit: 20);
    setState(() => videos = trending);
  }

  Future<void> _connectRelay() async {
    await relay.connect();

    // Subscribe to new videos
    relay.subscribeToVideos(limit: 10);

    // Listen for new videos
    relay.events.listen((event) {
      if (event.kind == 34235 || event.kind == 34236) {
        // New video arrived - could refresh or prepend
        print('New video: ${event.getTagValue("title")}');
      }
    });
  }

  @override
  void dispose() {
    relay.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return VideoCard(video: video);
      },
    );
  }
}
```

---

## React Native Integration

### Recommended Packages

```json
{
  "dependencies": {
    "nostr-tools": "^2.0.0",
    "react-native-websocket": "^1.0.0",
    "axios": "^1.6.0",
    "@tanstack/react-query": "^5.0.0"
  }
}
```

### API Client

```typescript
import axios, { AxiosInstance } from 'axios';

interface VideoStats {
  id: string;
  pubkey: string;
  created_at: string;
  kind: number;
  d_tag: string;
  title: string;
  thumbnail: string;
  video_url: string;
  reactions: number;
  comments: number;
  reposts: number;
  engagement_score: number;
  trending_score?: number;
}

interface Stats {
  total_events: number;
  total_videos: number;
}

class DivineFunnelcakeApi {
  private client: AxiosInstance;

  constructor(baseUrl: string, apiToken?: string) {
    this.client = axios.create({
      baseURL: baseUrl,
      headers: apiToken ? { Authorization: `Bearer ${apiToken}` } : {},
    });
  }

  async getTrendingVideos(limit = 50): Promise<VideoStats[]> {
    const { data } = await this.client.get('/api/videos', {
      params: { sort: 'trending', limit },
    });
    return data;
  }

  async getRecentVideos(limit = 50, kind?: number): Promise<VideoStats[]> {
    const { data } = await this.client.get('/api/videos', {
      params: { sort: 'recent', limit, kind },
    });
    return data;
  }

  async getVideosByAuthor(pubkey: string, limit = 50): Promise<VideoStats[]> {
    const { data } = await this.client.get(`/api/users/${pubkey}/videos`, {
      params: { limit },
    });
    return data;
  }

  async searchVideos(query: string, limit = 50): Promise<VideoStats[]> {
    const { data } = await this.client.get('/api/search', {
      params: { q: query, limit },
    });
    return data;
  }

  async searchByHashtag(tag: string, limit = 50): Promise<VideoStats[]> {
    const { data } = await this.client.get('/api/search', {
      params: { tag, limit },
    });
    return data;
  }

  async getVideoStats(eventId: string): Promise<VideoStats> {
    const { data } = await this.client.get(`/api/videos/${eventId}/stats`);
    return data;
  }

  async getStats(): Promise<Stats> {
    const { data } = await this.client.get('/api/stats');
    return data;
  }
}

export const api = new DivineFunnelcakeApi('https://relay.divine.video');

// For staging:
// export const api = new DivineFunnelcakeApi('https://funnelcake.staging.dvines.org');
```

### WebSocket Relay Client

```typescript
import { Event, Filter, verifyEvent } from 'nostr-tools';

type MessageHandler = (event: Event, subId: string) => void;
type EoseHandler = (subId: string) => void;

class NostrRelayClient {
  private ws: WebSocket | null = null;
  private subscriptions = new Map<string, Filter[]>();
  private messageHandlers: MessageHandler[] = [];
  private eoseHandlers: EoseHandler[] = [];
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;

  constructor(private relayUrl: string) {}

  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      this.ws = new WebSocket(this.relayUrl);

      this.ws.onopen = () => {
        this.reconnectAttempts = 0;
        // Resubscribe after reconnection
        this.subscriptions.forEach((filters, subId) => {
          this.sendSubscription(subId, filters);
        });
        resolve();
      };

      this.ws.onmessage = (event) => {
        this.handleMessage(JSON.parse(event.data));
      };

      this.ws.onerror = (error) => {
        console.error('WebSocket error:', error);
        reject(error);
      };

      this.ws.onclose = () => {
        this.handleDisconnect();
      };
    });
  }

  private handleMessage(message: any[]) {
    const [type, ...rest] = message;

    switch (type) {
      case 'EVENT': {
        const [subId, event] = rest;
        if (verifyEvent(event)) {
          this.messageHandlers.forEach((handler) => handler(event, subId));
        }
        break;
      }
      case 'EOSE': {
        const [subId] = rest;
        this.eoseHandlers.forEach((handler) => handler(subId));
        break;
      }
      case 'OK': {
        const [eventId, accepted, reason] = rest;
        console.log(`Event ${eventId}: ${accepted ? 'accepted' : `rejected: ${reason}`}`);
        break;
      }
      case 'NOTICE': {
        console.log('Relay notice:', rest[0]);
        break;
      }
    }
  }

  private handleDisconnect() {
    if (this.reconnectAttempts < this.maxReconnectAttempts) {
      this.reconnectAttempts++;
      const delay = Math.pow(2, this.reconnectAttempts) * 1000;
      setTimeout(() => this.connect(), delay);
    }
  }

  onEvent(handler: MessageHandler): () => void {
    this.messageHandlers.push(handler);
    return () => {
      const index = this.messageHandlers.indexOf(handler);
      if (index > -1) this.messageHandlers.splice(index, 1);
    };
  }

  onEose(handler: EoseHandler): () => void {
    this.eoseHandlers.push(handler);
    return () => {
      const index = this.eoseHandlers.indexOf(handler);
      if (index > -1) this.eoseHandlers.splice(index, 1);
    };
  }

  private sendSubscription(subId: string, filters: Filter[]) {
    this.ws?.send(JSON.stringify(['REQ', subId, ...filters]));
  }

  subscribe(filters: Filter[], subId?: string): string {
    const id = subId || `sub-${Date.now()}`;
    this.subscriptions.set(id, filters);

    if (this.ws?.readyState === WebSocket.OPEN) {
      this.sendSubscription(id, filters);
    }

    return id;
  }

  unsubscribe(subId: string) {
    this.subscriptions.delete(subId);
    this.ws?.send(JSON.stringify(['CLOSE', subId]));
  }

  publish(signedEvent: Event) {
    this.ws?.send(JSON.stringify(['EVENT', signedEvent]));
  }

  // Convenience methods
  subscribeToVideos(options: { authors?: string[]; limit?: number } = {}): string {
    const filter: Filter = {
      kinds: [34235, 34236],
      limit: options.limit ?? 50,
    };
    if (options.authors) {
      filter.authors = options.authors;
    }
    return this.subscribe([filter]);
  }

  subscribeToReactions(videoEventId: string): string {
    return this.subscribe([{ kinds: [7], '#e': [videoEventId] }]);
  }

  subscribeToComments(videoEventId: string): string {
    return this.subscribe([{ kinds: [1111], '#E': [videoEventId] }]);  // NIP-22
  }

  disconnect() {
    this.subscriptions.clear();
    this.ws?.close();
  }
}

export const relay = new NostrRelayClient('wss://relay.divine.video');

// For staging:
// export const relay = new NostrRelayClient('wss://funnelcake.staging.dvines.org');
```

### React Hook Example

```typescript
import { useEffect, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { api, relay, VideoStats } from './divine-client';

// Hook for trending videos
export function useTrendingVideos(limit = 20) {
  return useQuery({
    queryKey: ['videos', 'trending', limit],
    queryFn: () => api.getTrendingVideos(limit),
    staleTime: 30 * 1000, // 30 seconds
  });
}

// Hook for creator videos
export function useCreatorVideos(pubkey: string, limit = 50) {
  return useQuery({
    queryKey: ['videos', 'creator', pubkey, limit],
    queryFn: () => api.getVideosByAuthor(pubkey, limit),
    enabled: !!pubkey,
  });
}

// Hook for search
export function useVideoSearch(query: string, limit = 50) {
  return useQuery({
    queryKey: ['videos', 'search', query, limit],
    queryFn: () => api.searchVideos(query, limit),
    enabled: query.length >= 2,
  });
}

// Hook for real-time video updates
export function useLiveVideos(authors?: string[]) {
  const [videos, setVideos] = useState<Event[]>([]);

  useEffect(() => {
    relay.connect().then(() => {
      const subId = relay.subscribeToVideos({ authors, limit: 20 });

      const unsubEvent = relay.onEvent((event, _subId) => {
        if (_subId === subId) {
          setVideos((prev) => [event, ...prev.slice(0, 99)]);
        }
      });

      return () => {
        unsubEvent();
        relay.unsubscribe(subId);
      };
    });
  }, [authors?.join(',')]);

  return videos;
}

// Hook for video reactions
export function useVideoReactions(videoEventId: string) {
  const [reactions, setReactions] = useState<Event[]>([]);
  const [count, setCount] = useState(0);

  useEffect(() => {
    if (!videoEventId) return;

    relay.connect().then(() => {
      const subId = relay.subscribeToReactions(videoEventId);

      const unsubEvent = relay.onEvent((event, _subId) => {
        if (_subId === subId && event.kind === 7) {
          setReactions((prev) => [...prev, event]);
          setCount((c) => c + 1);
        }
      });

      return () => {
        unsubEvent();
        relay.unsubscribe(subId);
      };
    });
  }, [videoEventId]);

  return { reactions, count };
}

// Hook for video comments (NIP-22)
export function useVideoComments(videoEventId: string) {
  const [comments, setComments] = useState<Event[]>([]);

  useEffect(() => {
    if (!videoEventId) return;

    relay.connect().then(() => {
      const subId = relay.subscribeToComments(videoEventId);

      const unsubEvent = relay.onEvent((event, _subId) => {
        if (_subId === subId && event.kind === 1111) {
          setComments((prev) => [...prev, event]);
        }
      });

      return () => {
        unsubEvent();
        relay.unsubscribe(subId);
      };
    });
  }, [videoEventId]);

  // Sort by created_at and build thread structure
  const threadedComments = useMemo(() => {
    const sorted = [...comments].sort((a, b) => a.created_at - b.created_at);
    // Top-level comments have lowercase 'e' pointing to video (same as uppercase 'E')
    // Nested replies have lowercase 'e' pointing to parent comment
    return sorted;
  }, [comments]);

  return { comments: threadedComments, count: comments.length };
}
```

### Usage Example (React Native)

```tsx
import React from 'react';
import { FlatList, View, Text, Image, TouchableOpacity } from 'react-native';
import { useTrendingVideos, useVideoReactions } from './hooks';

function VideoFeed() {
  const { data: videos, isLoading, refetch } = useTrendingVideos(20);

  if (isLoading) {
    return <Text>Loading...</Text>;
  }

  return (
    <FlatList
      data={videos}
      keyExtractor={(item) => item.id}
      onRefresh={refetch}
      refreshing={isLoading}
      renderItem={({ item }) => <VideoCard video={item} />}
    />
  );
}

function VideoCard({ video }: { video: VideoStats }) {
  const { count: liveReactions } = useVideoReactions(video.id);

  return (
    <TouchableOpacity>
      <Image
        source={{ uri: video.thumbnail }}
        style={{ width: '100%', aspectRatio: 16/9 }}
      />
      <View style={{ padding: 12 }}>
        <Text style={{ fontWeight: 'bold' }}>{video.title}</Text>
        <Text style={{ color: '#666' }}>
          {video.reactions + liveReactions} likes · {video.comments} comments
        </Text>
      </View>
    </TouchableOpacity>
  );
}
```

---

## Common Patterns

### 1. Infinite Scroll with Pagination

```typescript
// Use `until` for cursor-based pagination
async function loadMoreVideos(lastTimestamp: number): Promise<VideoStats[]> {
  // REST API doesn't support cursor yet, use WebSocket
  return new Promise((resolve) => {
    const videos: Event[] = [];
    const subId = relay.subscribe([{
      kinds: [34235, 34236],
      until: lastTimestamp - 1,
      limit: 20,
    }]);

    const unsubEvent = relay.onEvent((event, _subId) => {
      if (_subId === subId) videos.push(event);
    });

    relay.onEose((_subId) => {
      if (_subId === subId) {
        unsubEvent();
        relay.unsubscribe(subId);
        resolve(videos.map(eventToVideoStats));
      }
    });
  });
}
```

### 2. Optimistic Updates

```typescript
async function likeVideo(videoId: string, authorPubkey: string) {
  // Optimistic update
  setReactionCount((c) => c + 1);

  const reactionEvent = {
    kind: 7,
    created_at: Math.floor(Date.now() / 1000),
    tags: [
      ['e', videoId],
      ['p', authorPubkey],
    ],
    content: '+',
  };

  try {
    const signed = await nostr.signEvent(reactionEvent);
    relay.publish(signed);
  } catch (error) {
    // Rollback on failure
    setReactionCount((c) => c - 1);
  }
}
```

### 3. Combined REST + WebSocket

```typescript
function useVideoFeed() {
  // Initial load from REST (fast, cached)
  const { data: initialVideos } = useQuery({
    queryKey: ['videos'],
    queryFn: () => api.getTrendingVideos(50),
  });

  // Real-time updates from WebSocket
  const liveVideos = useLiveVideos();

  // Merge: live videos first, then REST results (deduplicated)
  const allVideos = useMemo(() => {
    const seen = new Set(liveVideos.map((v) => v.id));
    const rest = (initialVideos || []).filter((v) => !seen.has(v.id));
    return [...liveVideos, ...rest];
  }, [liveVideos, initialVideos]);

  return allVideos;
}
```

### 4. Caching Strategy

```typescript
// Configure react-query for optimal caching
const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // Video lists: cache 30s, refetch on focus
      staleTime: 30 * 1000,
      refetchOnWindowFocus: true,

      // Video stats: cache 5 minutes (less volatile)
      // Override per-query as needed
    },
  },
});

// Individual video stats can cache longer
const { data } = useQuery({
  queryKey: ['video', videoId],
  queryFn: () => api.getVideoStats(videoId),
  staleTime: 5 * 60 * 1000, // 5 minutes
});
```

---

## Error Handling

### HTTP Errors

| Status | Meaning | Action |
|--------|---------|--------|
| 400 | Bad request | Check query params |
| 401 | Unauthorized | Check auth token/NIP-98 |
| 404 | Not found | Video doesn't exist |
| 429 | Rate limited | Back off, retry |
| 500 | Server error | Retry with backoff |
| 503 | Service unavailable | Server restarting, retry |

### WebSocket Errors

```typescript
class NostrRelayClient {
  private handleError(error: Event) {
    // Connection errors
    if (error.type === 'error') {
      // Automatic reconnection handled
      return;
    }
  }

  private handleOk(eventId: string, accepted: boolean, reason: string) {
    if (!accepted) {
      switch (true) {
        case reason.includes('duplicate'):
          // Event already exists, safe to ignore
          break;
        case reason.includes('blocked'):
          // User is banned
          throw new Error('User blocked from publishing');
        case reason.includes('rate'):
          // Rate limited
          throw new Error('Rate limited, slow down');
        case reason.includes('invalid'):
          // Bad event format or signature
          throw new Error('Invalid event: ' + reason);
        default:
          throw new Error('Event rejected: ' + reason);
      }
    }
  }
}
```

---

## Best Practices

### 1. Connection Management

```typescript
// Singleton relay connection
let relayInstance: NostrRelayClient | null = null;

export function getRelay(): NostrRelayClient {
  if (!relayInstance) {
    relayInstance = new NostrRelayClient('wss://relay.divine.video');
    // For staging: 'wss://funnelcake.staging.dvines.org'
    relayInstance.connect();
  }
  return relayInstance;
}

// Cleanup on app background (React Native)
AppState.addEventListener('change', (state) => {
  if (state === 'background') {
    relayInstance?.disconnect();
    relayInstance = null;
  }
});
```

### 2. Subscription Hygiene

```typescript
// Always clean up subscriptions
useEffect(() => {
  const subId = relay.subscribe(filters);

  return () => {
    relay.unsubscribe(subId); // Critical!
  };
}, []);
```

### 3. Batch Requests

```typescript
// Fetch multiple video stats in parallel
async function getMultipleVideoStats(ids: string[]): Promise<Map<string, VideoStats>> {
  const results = await Promise.all(
    ids.map((id) => api.getVideoStats(id).catch(() => null))
  );

  return new Map(
    results
      .filter((r): r is VideoStats => r !== null)
      .map((r) => [r.id, r])
  );
}
```

### 4. Offline Support

```typescript
// Use react-query's persistence
import { createAsyncStoragePersister } from '@tanstack/query-async-storage-persister';
import AsyncStorage from '@react-native-async-storage/async-storage';

const persister = createAsyncStoragePersister({
  storage: AsyncStorage,
});

// Wrap app with PersistQueryClientProvider
<PersistQueryClientProvider
  client={queryClient}
  persistOptions={{ persister }}
>
  <App />
</PersistQueryClientProvider>
```

### 5. Event Verification

```typescript
import { verifyEvent } from 'nostr-tools';

// Always verify events from relay
relay.onEvent((event) => {
  if (!verifyEvent(event)) {
    console.warn('Invalid event signature:', event.id);
    return;
  }
  // Process verified event
});
```

---

## Constants Reference

### Divine.video Event Kinds

| Constant | Value | Description |
|----------|-------|-------------|
| `KIND_PROFILE` | 0 | User profile metadata |
| `KIND_CONTACTS` | 3 | Contact/follow list |
| `KIND_DELETION` | 5 | Event deletion |
| `KIND_REACTION` | 7 | Reaction/like |
| `KIND_GENERIC_REPOST` | 16 | Generic repost |
| `KIND_COMMENT` | 1111 | NIP-22 comment (NOT kind 1!) |
| `KIND_MUTE_LIST` | 10000 | Mute list |
| `KIND_NIP98_AUTH` | 27235 | HTTP auth event |
| `KIND_CURATION_SET` | 30005 | Playlist/curation set |
| `KIND_VIDEO` | 34235 | Long-form video |
| `KIND_VIDEO_SHORT` | 34236 | Short-form video (primary) |

### API Limits

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_LIMIT` | 100 | API max results |
| `DEFAULT_LIMIT` | 50 | API default results |

---

## Support

- **Nostr:** `npub1...` (relay operator)
- **GitHub:** github.com/divine/divine-funnelcake
- **Discord:** discord.gg/divine

---

*Generated for divine.video mobile integration*
