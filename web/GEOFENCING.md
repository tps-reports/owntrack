# Web Geofencing Guide

This application supports **foreground geofencing** on web platforms, allowing you to monitor geographic regions while the app is running.

## How It Works

### Geofencing Architecture

Unlike native mobile apps that can monitor geofences in the background, web geofencing works through **manual distance-based checking**:

1. **Location Updates**: As the app receives location updates from the browser's Geolocation API
2. **Distance Calculation**: Each location is checked against all enabled regions using the Haversine formula
3. **Transition Detection**: When you enter or exit a region, a transition event is fired
4. **Message Publishing**: Enter/exit events are published via MQTT/HTTP to your configured endpoint

### Implementation Details

**GeofencingService** (`lib/data/services/geofencing_service.dart`):
- Platform-agnostic implementation
- Uses `Geolocator.distanceBetween()` for distance calculations
- Maintains state of which regions you're currently inside
- Fires `GeofenceTransition` events on enter/exit

**Integration with Tracking**:
- TrackingService automatically calls `checkLocation()` on each location update
- No additional setup required - works out of the box
- Transition messages include region description and timestamp

## Creating and Managing Regions

### Via UI (Regions Screen)

1. Navigate to the "Regions" tab
2. Tap the "+" button to create a new region
3. Enter:
   - **Description**: Name of the region (e.g., "Home", "Office")
   - **Latitude**: Center latitude (decimal degrees)
   - **Longitude**: Center longitude (decimal degrees)
   - **Radius**: Region radius in meters (default: 100m)
4. Toggle the switch to enable/disable monitoring
5. The region will appear on the map as a circle

### Region States

- **Enabled**: Actively monitored for enter/exit events
- **Disabled**: Ignored during location checks
- **Inside**: Currently within the region (green indicator)
- **Outside**: Currently outside the region (gray indicator)

## Geofence Events

### Enter Event

Triggered when you move from outside to inside a region:

```json
{
  "_type": "transition",
  "event": "enter",
  "desc": "Home",
  "lat": 37.7749,
  "lon": -122.4194,
  "tst": 1234567890,
  "wtst": 1234567800
}
```

### Exit Event

Triggered when you move from inside to outside a region:

```json
{
  "_type": "transition",
  "event": "leave",
  "desc": "Home",
  "lat": 37.7750,
  "lon": -122.4195,
  "tst": 1234567900,
  "wtst": 1234567800
}
```

## Accuracy Considerations

### Factors Affecting Accuracy

1. **GPS Accuracy**: Browser location accuracy varies (typically 10-50m)
2. **Update Frequency**: Depends on monitoring mode and movement
3. **Region Size**: Smaller regions require more accurate location
4. **Environmental**: Buildings, weather, and urban canyons affect GPS

### Best Practices

- **Minimum Radius**: Use at least 50-100m for reliable detection
- **Location Accuracy**: Check `accuracy` field in location updates
- **Hysteresis**: Allow for some buffer zone to avoid rapid transitions
- **Testing**: Test your regions in the actual locations

## Web vs Mobile Differences

| Feature | Mobile (Android/iOS) | Web |
|---------|---------------------|-----|
| **Background Monitoring** | ✅ Yes | ❌ No |
| **Foreground Monitoring** | ✅ Yes | ✅ Yes |
| **Native APIs** | ✅ Yes (GeoFencing API) | ❌ No |
| **Manual Checking** | ✅ Yes | ✅ Yes |
| **Region Management** | ✅ Yes | ✅ Yes |
| **Transition Events** | ✅ Yes | ✅ Yes (foreground only) |
| **Battery Impact** | ⚠️ Moderate | ✅ Low (only when running) |

## Use Cases

### Perfect For:
- ✅ Active tracking scenarios
- ✅ Real-time location monitoring dashboards
- ✅ Navigation applications
- ✅ Attendance tracking (while app is open)
- ✅ Delivery/logistics tracking (active routes)

### Not Ideal For:
- ❌ Background location alerts (app must be running)
- ❌ Sleep tracking or overnight monitoring
- ❌ Passive presence detection
- ❌ Battery-saving scenarios (app must stay open)

## Testing Geofencing

### Option 1: Chrome DevTools Location Override

1. Open Chrome DevTools (F12)
2. Press `Ctrl+Shift+P` → "Show Sensors"
3. Set custom latitude/longitude
4. Move the location in/out of your region
5. Watch the console for transition logs

### Option 2: Real Device Testing

1. Deploy the web app to HTTPS server
2. Open on mobile browser
3. Enable location permission
4. Walk or drive through your region
5. Monitor transitions in real-time

### Option 3: Console Testing

```javascript
// Get geofencing service from app
// (This assumes you've exposed it for testing)

// Check current regions
console.log('Current regions:', geofencingService.getCurrentRegions());

// Manually trigger location check
await geofencingService.checkLocation(37.7749, -122.4194);
```

## Performance Considerations

### Location Update Frequency

The app uses smart location filtering to balance accuracy and performance:
- **Minimum time**: 30 seconds between publishes
- **Minimum distance**: 50 meters between publishes
- **Geofence checks**: Every location update (not published, just checked)

### Region Limits

While there's no hard limit, consider:
- **< 10 regions**: Optimal performance
- **10-50 regions**: Good performance
- **> 50 regions**: May impact performance on slower devices

### Battery Impact

Web geofencing is battery-friendly because:
- No background processing
- Only runs when app is visible
- Uses efficient distance calculations
- Leverages browser's native location API

## Troubleshooting

### Transitions Not Firing

1. **Check region is enabled**: Toggle in Regions screen
2. **Verify location accuracy**: Check console for accuracy values
3. **Confirm you crossed boundary**: Move clearly in/out of region
4. **Check radius**: Try increasing region radius
5. **Review logs**: Look for "Entered region" or "Exited region" messages

### Location Not Updating

1. **HTTPS required**: Web location requires HTTPS in production
2. **Permission granted**: Check browser location permission
3. **Tracking enabled**: Ensure tracking is started
4. **Monitoring mode**: Set appropriate mode (Move for frequent updates)

### Regions Not Appearing

1. **Map view**: Switch to Map tab to see region circles
2. **Region data**: Check Regions tab for saved regions
3. **SharedPreferences**: Clear browser data and recreate regions

## Privacy and Security

### Data Storage
- Regions stored locally in browser's localStorage
- No server-side region storage
- Cleared when browser data is cleared

### Location Privacy
- Location only accessed when app is running
- User controls permission via browser prompt
- No background location tracking
- HTTPS required for production deployments

## API Reference

See `lib/data/services/geofencing_service.dart` for full API documentation.

### Key Methods

- `checkLocation(lat, lon)` - Check location against all regions
- `addRegion(region)` - Add new region to monitor
- `removeRegion(id)` - Remove region from monitoring
- `enableRegion(id)` - Enable region monitoring
- `disableRegion(id)` - Disable region monitoring
- `getCurrentRegions()` - Get IDs of regions you're currently inside

### Events

Subscribe to geofence transitions:

```dart
geofencingService.transitions.listen((transition) {
  print('${transition.event} ${transition.region.displayDescription}');
});
```
