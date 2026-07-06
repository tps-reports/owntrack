# Executive Summary: OwnTracks Flutter (owntrack)

## Overview
OwnTracks Flutter is a unified cross-platform rewrite of the OwnTracks location tracking application, replacing separate native Android and iOS codebases with a single Flutter app targeting Android, iOS, and Web. It provides real-time location sharing, geofencing, and encrypted messaging via MQTT or HTTP protocols.

## Technology Stack
- Flutter (Dart), SDK ^3.9.2
- Riverpod state management
- go_router navigation
- flutter_map with OpenStreetMap tiles
- mqtt_client and dio for MQTT/HTTP networking
- geolocator for GPS tracking (foreground and background)
- ChaCha20-Poly1305 encryption via cryptography package
- SharedPreferences (Drift/SQLite prepared but not yet active)

## Status
Development (Phase 7 complete -- live services integrated; Phase 8 pending)

## Key Features
- Cross-platform location tracking (Android, iOS, Web)
- Four monitoring modes with smart location filtering
- MQTT and HTTP connection modes with persistent message queue
- Geofencing with enter/exit transition events (all platforms)
- End-to-end message encryption (ChaCha20-Poly1305)
- Contact tracking and waypoint management
- Battery-aware tracking with platform-specific optimizations
- 130 passing tests

## Architecture
Clean Architecture with four layers: core (constants, router, utilities), data (repositories, services, datasources, models), domain (Riverpod providers), and presentation (screens, widgets, theme). Services coordinate location tracking, geofencing, message processing, and encryption, all wired through Riverpod's provider hierarchy.

## Target Users
Privacy-focused individuals who want to share location with trusted contacts using self-hosted infrastructure, across any device platform including web browsers.

## Dependencies & Infrastructure
- MQTT broker (self-hosted or configured endpoint)
- Optional HTTP endpoint as MQTT alternative
- OpenStreetMap tile servers for mapping
- HTTPS required for web deployment (browser geolocation restriction)
- flutter_background_service for persistent Android tracking
