package app.hasta.mobile

import android.app.Activity
import android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG
import android.hardware.biometrics.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import android.hardware.biometrics.BiometricPrompt
import android.os.Build
import android.os.CancellationSignal
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.security.KeyFactory
import java.security.KeyPairGenerator
import java.security.KeyStore
import java.security.PrivateKey
import java.security.Signature
import java.security.spec.ECGenParameterSpec

internal class TransferApproval(private val activity: Activity) {
    private val alias = "hasta_qr_transfer_approval_v1"
    private var signing = false

    fun register(messenger: BinaryMessenger) {
        MethodChannel(messenger, "app.hasta.mobile/transfer_approval").setMethodCallHandler { call, result ->
            try {
                when {
                    Build.VERSION.SDK_INT < 30 -> unavailable(result)
                    call.method == "publicKey" -> {
                        val store = store()
                        if (!store.containsAlias(alias)) createKey()
                        requireHardware(getPrivate(store()))
                        result.success(encode(store().getCertificate(alias).publicKey.encoded))
                    }
                    call.method == "approve" -> {
                        val challenge = call.arguments as? String
                        if (challenge == null || !Regex("[0-9a-f]{64}").matches(challenge) || signing)
                            return@setMethodCallHandler unavailable(result)
                        approve(challenge, result)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) {
                unavailable(result)
            }
        }
    }

    @android.annotation.TargetApi(30)
    private fun createKey() {
        val generator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, "AndroidKeyStore")
        generator.initialize(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_SIGN)
            .setAlgorithmParameterSpec(ECGenParameterSpec("secp256r1"))
            .setDigests(KeyProperties.DIGEST_SHA256)
            .setUserAuthenticationRequired(true)
            .setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG or KeyProperties.AUTH_DEVICE_CREDENTIAL)
            .build())
        generator.generateKeyPair()
    }

    @android.annotation.TargetApi(30)
    private fun approve(challenge: String, result: MethodChannel.Result) {
        val key = getPrivate(store())
        requireHardware(key)
        val signature = Signature.getInstance("SHA256withECDSA").apply { initSign(key) }
        val prompt = BiometricPrompt.Builder(activity)
            .setTitle(activity.getString(R.string.hasta_transfer_approve))
            .setSubtitle(activity.getString(R.string.hasta_transfer_compare, challenge.take(8).uppercase()))
            .setAllowedAuthenticators(BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
            .build()
        signing = true
        try {
            prompt.authenticate(BiometricPrompt.CryptoObject(signature), CancellationSignal(), activity.mainExecutor,
                object : BiometricPrompt.AuthenticationCallback() {
                    override fun onAuthenticationSucceeded(approved: BiometricPrompt.AuthenticationResult) {
                        signing = false
                        try {
                            val signer = requireNotNull(approved.cryptoObject?.signature)
                            signer.update(challenge.toByteArray(Charsets.US_ASCII))
                            result.success(encode(signer.sign()))
                        } catch (_: Exception) {
                            unavailable(result)
                        }
                    }
                    override fun onAuthenticationError(code: Int, message: CharSequence) {
                        signing = false
                        result.error("transfer_approval_cancelled", null, null)
                    }
                })
        } catch (error: Exception) {
            signing = false
            throw error
        }
    }

    private fun store() = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
    private fun getPrivate(store: KeyStore) = store.getKey(alias, null) as PrivateKey
    private fun requireHardware(key: PrivateKey) {
        val info = KeyFactory.getInstance(key.algorithm, "AndroidKeyStore").getKeySpec(key, KeyInfo::class.java)
        check(info.isInsideSecureHardware && info.isUserAuthenticationRequirementEnforcedBySecureHardware)
    }
    private fun encode(bytes: ByteArray) =
        Base64.encodeToString(bytes, Base64.URL_SAFE or Base64.NO_WRAP or Base64.NO_PADDING)
    private fun unavailable(result: MethodChannel.Result) = result.error("transfer_approval_unavailable", null, null)
}
