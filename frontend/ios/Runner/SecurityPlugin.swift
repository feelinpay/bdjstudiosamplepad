import Flutter
import UIKit

class SecurityPlugin: NSObject, FlutterPlugin {
    
    static let channelName = "com.samplepadpro/security"
    static let integrityChannelName = "com.samplepadpro/integrity"
    
    static func register(with registrar: FlutterPluginRegistrar) {
        let securityChannel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = SecurityPlugin()
        registrar.addMethodCallDelegate(instance, channel: securityChannel)
        
        let integrityChannel = FlutterMethodChannel(
            name: integrityChannelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: integrityChannel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "checkSecurity":
            result(checkSecurity())
        case "checkEmulator":
            result(false)
        case "verifySignature":
            result(verifySignature())
        case "getBundlePath":
            result(Bundle.main.bundlePath)
        case "getLibraryPath":
            result(Bundle.main.bundlePath + "/Frameworks")
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func checkSecurity() -> [String: Any] {
        return [
            "isJailbroken": checkJailbreak(),
            "isDebuggerAttached": checkDebugger(),
            "isHookingDetected": checkHooking()
        ]
    }
    
    private func checkJailbreak() -> Bool {
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/private/var/tmp/cydia.log",
            "/private/var/cache/apt/",
            "/private/var/log/syslog",
            "/usr/libexec/cydia/",
            "/usr/libexec/sftp-server",
            "/usr/bin/cycript",
            "/usr/local/bin/cycript",
            "/usr/lib/libcycript.dylib",
            "/System/Library/LaunchDaemons/com.ikey.bbot.plist",
            "/System/Library/LaunchDaemons/com.saurik.Cydia.Startup.plist",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/DynamicLibraries",
            "/usr/sbin/sshd",
            "/usr/bin/sshd"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        let suspiciousURLs = [
            URL(string: "cydia://"),
            URL(string: "sileo://"),
            URL(string: "filza://")
        ]
        
        for url in suspiciousURLs {
            if let url = url, UIApplication.shared.canOpenURL(url) {
                return true
            }
        }
        
        if isSandboxEscaped() {
            return true
        }
        
        return false
    }
    
    private func isSandboxEscaped() -> Bool {
        let testPath = NSTemporaryDirectory() + UUID().uuidString
        let symlinkPath = "/private/var/tmp/" + UUID().uuidString
        
        do {
            try FileManager.default.createSymbolicLink(
                atPath: symlinkPath,
                withDestinationPath: testPath
            )
            try FileManager.default.removeItem(atPath: symlinkPath)
            return false
        } catch {
            return true
        }
    }
    
    private func checkDebugger() -> Bool {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        
        let sysctlResult = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if sysctlResult == 0 {
            let flags = info.kp_proc.p_flag
            return (flags & P_TRACED) != 0
        }
        
        return false
    }
    
    private func checkHooking() -> Bool {
        let suspiciousLibs = [
            "FridaGadget",
            "frida",
            "libcycript",
            "libsubstitute",
            "libsubstrate"
        ]
        
        for lib in suspiciousLibs {
            if dlopen(lib, RTLD_NOW) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func verifySignature() -> Bool {
        guard let mobileprovision = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision") else {
            return true
        }
        
        return FileManager.default.fileExists(atPath: mobileprovision)
    }
}
