# Battery Status API Testing

This application uses the Browser's Battery Status API to monitor battery level and charging state on web platforms.

## Browser Support

The Battery Status API has been deprecated in some browsers for privacy reasons:

- ✅ **Chrome/Chromium**: Supported (but may be removed in future versions)
- ❌ **Firefox**: Removed in version 52+ (privacy concerns)
- ❌ **Safari**: Not supported
- ✅ **Edge**: Supported (Chromium-based)
- ⚠️ **Opera**: Supported (Chromium-based)

## Testing Battery Status

### Option 1: Chrome DevTools Emulation

1. Open Chrome DevTools (F12)
2. Press `Ctrl+Shift+P` (or `Cmd+Shift+P` on Mac) to open the Command Palette
3. Type "Show Sensors" and select it
4. In the Sensors tab, you can override battery status:
   - Battery level (0-100)
   - Charging state (AC power or Battery)

### Option 2: Console Testing

Open the browser console and run:

```javascript
// Check if Battery API is supported
if ('getBattery' in navigator) {
  navigator.getBattery().then(battery => {
    console.log('Battery level:', battery.level * 100 + '%');
    console.log('Charging:', battery.charging);
    console.log('Charging time:', battery.chargingTime);
    console.log('Discharging time:', battery.dischargingTime);

    // Add event listeners
    battery.addEventListener('levelchange', () => {
      console.log('Battery level changed:', battery.level * 100 + '%');
    });

    battery.addEventListener('chargingchange', () => {
      console.log('Charging state changed:', battery.charging);
    });
  });
} else {
  console.log('Battery Status API not supported');
}
```

### Option 3: Feature Detection in App

The app automatically detects Battery API availability:

1. Run the web app: `flutter run -d chrome`
2. Check the browser console for battery-related logs:
   - "Battery Status API is supported and initialized" - API available
   - "Battery Status API not supported in this browser" - API unavailable
3. Look for battery level in location messages sent to MQTT/HTTP

## Fallback Behavior

When the Battery Status API is not available:
- Battery level defaults to 100%
- Battery state defaults to "unknown"
- No battery change events are fired
- The app continues to function normally

## Implementation Details

- **Feature detection**: `lib/data/services/battery_service_web.dart`
- **Conditional imports**: Used to load web-specific code only on web platform
- **Event listeners**: Real-time updates via `levelchange` and `chargingchange` events
- **Polling**: Fallback polling every 5 minutes if events are not supported

## Privacy Considerations

The Battery Status API was deprecated in some browsers because:
- Battery level can be used for fingerprinting users
- Can track user behavior (e.g., detecting when a user plugs in their device)

OwnTracks only uses this API to:
- Include battery status in location messages
- Inform users of their current battery level
- No tracking or fingerprinting is performed
