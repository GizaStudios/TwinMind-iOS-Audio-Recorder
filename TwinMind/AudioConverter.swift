import Foundation
import AVFoundation

/// Converts CAF audio files to M4A format for Whisper API compatibility
struct AudioConverter {
    
    /// Converts a CAF file to M4A format
    /// - Parameters:
    ///   - sourceURL: URL of the source CAF file
    ///   - destinationURL: URL where the M4A file will be saved
    /// - Returns: URL of the converted M4A file
    /// - Throws: Conversion errors
    static func convertCAFToM4A(sourceURL: URL, destinationURL: URL) throws -> URL {
        var sourceFile: ExtAudioFileRef?
        var destinationFile: ExtAudioFileRef?
        
        // Open source CAF file
        var status = ExtAudioFileOpenURL(sourceURL as CFURL, &sourceFile)
        guard status == noErr, let source = sourceFile else {
            throw AudioConversionError.cannotOpenSourceFile(status)
        }
        
        defer { ExtAudioFileDispose(source) }
        
        // Get source format
        var sourceFormat = AudioStreamBasicDescription()
        var size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        status = ExtAudioFileGetProperty(source, kExtAudioFileProperty_FileDataFormat, &size, &sourceFormat)
        guard status == noErr else {
            throw AudioConversionError.cannotGetSourceFormat(status)
        }
        
        // Setup destination M4A format
        var destinationFormat = AudioStreamBasicDescription()
        destinationFormat.mFormatID = kAudioFormatMPEG4AAC
        destinationFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame
        destinationFormat.mSampleRate = sourceFormat.mSampleRate
        
        // Create destination M4A file
        status = ExtAudioFileCreateWithURL(
            destinationURL as CFURL,
            kAudioFileM4AType,
            &destinationFormat,
            nil,
            AudioFileFlags.eraseFile.rawValue,
            &destinationFile
        )
        guard status == noErr, let destination = destinationFile else {
            throw AudioConversionError.cannotCreateDestinationFile(status)
        }
        
        defer { ExtAudioFileDispose(destination) }
        
        // Force software encoder to avoid hardware codec issues on dual-core devices
        var codecManufacturer: UInt32 = 0x61706c20 // 'appl' in hex (Apple Software)
        ExtAudioFileSetProperty(destination, kExtAudioFileProperty_CodecManufacturer, UInt32(MemoryLayout<UInt32>.size), &codecManufacturer)
        
        // Set client format for conversion (PCM intermediate format)
        var clientFormat = AudioStreamBasicDescription()
        clientFormat.mFormatID = kAudioFormatLinearPCM
        clientFormat.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked
        clientFormat.mSampleRate = sourceFormat.mSampleRate
        clientFormat.mChannelsPerFrame = sourceFormat.mChannelsPerFrame
        clientFormat.mBitsPerChannel = 16
        clientFormat.mFramesPerPacket = 1
        clientFormat.mBytesPerFrame = (clientFormat.mBitsPerChannel / 8) * clientFormat.mChannelsPerFrame
        clientFormat.mBytesPerPacket = clientFormat.mBytesPerFrame * clientFormat.mFramesPerPacket
        
        // Set client format on both files
        status = ExtAudioFileSetProperty(source, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientFormat)
        guard status == noErr else {
            throw AudioConversionError.cannotSetSourceClientFormat(status)
        }
        
        status = ExtAudioFileSetProperty(destination, kExtAudioFileProperty_ClientDataFormat, UInt32(MemoryLayout<AudioStreamBasicDescription>.size), &clientFormat)
        guard status == noErr else {
            throw AudioConversionError.cannotSetDestinationClientFormat(status)
        }
        
        // Convert in chunks
        let bufferSize: UInt32 = 8192 // 8KB buffer for good performance/memory balance
        let frameCount = bufferSize / UInt32(MemoryLayout<Int16>.size) / clientFormat.mChannelsPerFrame
        let bufferByteSize = Int(frameCount * clientFormat.mBytesPerFrame)
        let bufferData = UnsafeMutableRawPointer.allocate(byteCount: bufferByteSize, alignment: MemoryLayout<Int16>.alignment)
        defer { bufferData.deallocate() }
        
        var buffer = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: clientFormat.mChannelsPerFrame,
                mDataByteSize: UInt32(bufferByteSize),
                mData: bufferData
            )
        )
        
        // Perform conversion
        var readFrameCount = frameCount
        repeat {
            readFrameCount = frameCount
            
            status = ExtAudioFileRead(source, &readFrameCount, &buffer)
            guard status == noErr else {
                throw AudioConversionError.readError(status)
            }
            
            if readFrameCount > 0 {
                status = ExtAudioFileWrite(destination, readFrameCount, &buffer)
                guard status == noErr else {
                    throw AudioConversionError.writeError(status)
                }
            }
        } while readFrameCount > 0
        
        return destinationURL
    }
    
    /// Generates a temporary M4A file URL for conversion
    static func temporaryM4AURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = UUID().uuidString + ".m4a"
        return tempDir.appendingPathComponent(filename)
    }
}

enum AudioConversionError: Error, LocalizedError {
    case cannotOpenSourceFile(OSStatus)
    case cannotGetSourceFormat(OSStatus)
    case cannotCreateDestinationFile(OSStatus)
    case cannotSetSourceClientFormat(OSStatus)
    case cannotSetDestinationClientFormat(OSStatus)
    case readError(OSStatus)
    case writeError(OSStatus)
    
    var errorDescription: String? {
        switch self {
        case .cannotOpenSourceFile(let status):
            return "Cannot open source file: \(status)"
        case .cannotGetSourceFormat(let status):
            return "Cannot get source format: \(status)"
        case .cannotCreateDestinationFile(let status):
            return "Cannot create destination file: \(status)"
        case .cannotSetSourceClientFormat(let status):
            return "Cannot set source client format: \(status)"
        case .cannotSetDestinationClientFormat(let status):
            return "Cannot set destination client format: \(status)"
        case .readError(let status):
            return "Read error: \(status)"
        case .writeError(let status):
            return "Write error: \(status)"
        }
    }
} 