# TwinMind – Data Usage & Privacy

TwinMind records audio so it can transcribe and summarise your meetings.  Below is an overview of how data is collected, processed, stored, and transmitted.

## What We Collect

| Data | Purpose | Where Stored |
|------|---------|--------------|
| Microphone audio (raw CAF files & 30-s segments) | Transcription and playback | Locally on-device (Documents/Recordings) |
| Transcription text | Display and search | Locally in SwiftData store |
| Uploaded audio segments | Cloud transcription fallback (OpenAI Whisper) | Sent over TLS; not retained by our server beyond processing |

## When We Upload

1. **On-device first** – TwinMind always attempts local on-device transcription.
2. **Cloud fallback** – If the network is available and you haven't disabled online mode, 30-second audio segments are uploaded to a serverless function (Supabase Edge) that wraps OpenAI Whisper.
3. **Retry & Queue** – If offline, segments are queued and retried when connectivity returns.

Uploads occur via a `URLSession` **background transfer** with TLS 1.2+ and HMAC-signed headers.

## Retention & Cleanup

• Raw audio & transcripts older than **90 days** are automatically pruned at launch (see `DataPruner`).  
• Orphaned audio files are removed (`FileCleanupManager`).

## Permissions Explained

| Info.plist Key | Why We Need It |
| --- | --- |
| NSMicrophoneUsageDescription | Capture audio for your recordings. |
| NSSpeechRecognitionUsageDescription | Optional on-device transcription when offline. |
| NSBluetoothAlwaysUsageDescription | Allow recording via Bluetooth headsets & playback. |
| NSLocalNetworkUsageDescription | Connect to local audio devices (AirPods, etc.). |

TwinMind never tracks you or shares data with third-party analytics. 