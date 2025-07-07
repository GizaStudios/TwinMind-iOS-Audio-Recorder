# TwinMind Widget Extension Setup Guide

## Bundle Configuration

### Main App Target (TwinMind):
- **Bundle Identifier**: `com.gizastudios.TwinMind`
- **Info.plist**: `TwinMind/Info.plist`

### Widget Extension Target (TwinMindWidgetExtension):
- **Bundle Identifier**: `com.gizastudios.TwinMind.widget`
- **Info.plist**: `TwinMindWidgetExtension/Info.plist`

## App Groups Configuration

### Shared App Group:
- **Group Identifier**: `group.com.gizastudios.twinmind.widget`
- **Add to both targets** in Signing & Capabilities

## Setup Steps

### 1. Verify Target Configuration
1. **Open Xcode** and select the project
2. **Select "TARGETS" tab**
3. **Verify bundle identifiers**:
   - Main app: `com.gizastudios.TwinMind`
   - Widget: `com.gizastudios.TwinMind.widget`

### 2. Configure App Groups
1. **Select main app target**
2. **Signing & Capabilities → + Capability → App Groups**
3. **Add group**: `group.com.gizastudios.twinmind.widget`
4. **Select widget extension target**
5. **Add the same App Groups capability**
6. **Add the same group**: `group.com.gizastudios.twinmind.widget`

### 3. Configure Xcode Scheme for Widget Debugging
1. **Product → Scheme → Edit Scheme**
2. **Select "Run" from the left sidebar**
3. **Go to "Info" tab**
4. **Under "Executable"**, make sure it's set to "TwinMind"
5. **Go to "Options" tab**
6. **Under "Widget Extension"**, click the "+" button
7. **Select "TwinMindWidgetExtension"** from the dropdown
8. **Set Widget Kind** to: `TwinMindWidgetExtension`
9. **Click "Close"** to save the scheme

### 4. Verify Build Settings
For each target, ensure:

#### Main App Target:
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.gizastudios.TwinMind`
- `INFOPLIST_FILE` = `TwinMind/Info.plist`

#### Widget Extension Target:
- `PRODUCT_BUNDLE_IDENTIFIER` = `com.gizastudios.TwinMind.widget`
- `INFOPLIST_FILE` = `TwinMindWidgetExtension/Info.plist`

### 5. Check File Structure
```
TwinMind.xcodeproj/
├── TwinMind/ (Main App Target)
│   ├── Info.plist
│   ├── TwinMindApp.swift
│   ├── SharedWidgetManager.swift
│   └── ... (other main app files)
└── TwinMindWidgetExtension/ (Widget Extension Target)
    ├── Info.plist
    └── TwinMindWidgetExtension.swift
```

### 6. Build and Test
1. **Clean Build Folder** (⌘+Shift+K)
2. **Build the project** (⌘+B)
3. **Run on device** to test widget functionality

## Widget Features

### ✅ Implemented Features:
- **Quick Recording Access**: Single tap to start/stop recording
- **Real-time Status**: Visual indicators for recording state
- **Session Count**: Displays total recording sessions
- **Multiple Sizes**: Small, medium, and large widget options
- **Deep Link Integration**: Opens main app when tapped
- **Live Updates**: Refreshes every 30 seconds

### Widget Sizes:
1. **Small Widget**: Compact view with recording status and session count
2. **Medium Widget**: Includes recording controls and session information
3. **Large Widget**: Full-featured widget with detailed status and controls

## Troubleshooting

### If build fails with Info.plist error:
1. **Check bundle identifiers** are unique
2. **Verify Info.plist paths** in build settings
3. **Clean derived data** and rebuild

### If widget doesn't appear:
1. **Check App Groups** are configured for both targets
2. **Verify deployment target** is iOS 14.0+
3. **Check signing** - both targets should be signed with the same team

### If recording doesn't work:
1. **Check App Groups** are properly configured
2. **Verify SharedWidgetManager** is included in main app target
3. **Check notification handling** in main app

### If widget debugging fails:
1. **Configure Xcode scheme** for widget debugging (see step 3 above)
2. **Set correct widget kind** in scheme options
3. **Clean and rebuild** the project
4. **Restart Xcode** if issues persist

## Final Verification
After setup, verify:
- ✅ **Build succeeds** without errors
- ✅ **Widget appears** in iOS widget gallery
- ✅ **Recording functionality** works from widget
- ✅ **Deep linking** opens the main app
- ✅ **Session count** updates correctly
- ✅ **Widget debugging** works in simulator

The widget is now properly configured for the Giza Studios TwinMind app with the correct bundle identifiers and app group configuration. 