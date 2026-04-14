import Foundation
import LocalAuthentication

/// Real LocalAuthentication wrapper for FaceID/TouchID.
/// design.md 4.1, questions.md Q4.
final class BiometricService {

    /// Check if biometric authentication is available on this device.
    func isBiometricAvailable() -> Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// The type of biometric available (faceID, touchID, or none).
    func biometricType() -> LABiometryType {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return context.biometryType
    }

    /// Authenticate the user with biometrics.
    /// Calls LAContext.evaluatePolicy with the provided reason string.
    func authenticate(reason: String, completion: @escaping (Bool, String?) -> Void) {
        let context = LAContext()
        var error: NSError?

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            completion(false, error?.localizedDescription ?? "Biometric not available")
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authError in
            if success {
                completion(true, nil)
            } else {
                completion(false, authError?.localizedDescription ?? "Authentication failed")
            }
        }
    }
}
