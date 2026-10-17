package com.teknikbakis.teknik_bakis

import android.content.Context
import androidx.credentials.CreatePasswordRequest
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetPasswordOption
import androidx.credentials.PasswordCredential
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialException
import androidx.fragment.app.FragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class CredentialsHandler(
    private val activity: FragmentActivity,
    private val context: Context,
) {
    private val credentialManager = CredentialManager.create(context)
    private val scope = CoroutineScope(Dispatchers.Main)

    companion object {
        const val CHANNEL = "com.teknikbakis.teknik_bakis/credentials"
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "saveCredentials" -> saveCredentials(call, result)
            "restoreCredentials" -> restoreCredentials(result)
            "clearCredentials" -> clearCredentials(result)
            else -> result.notImplemented()
        }
    }

    private fun saveCredentials(call: MethodCall, result: MethodChannel.Result) {
        val username = call.argument<String>("username") ?: return result.error(
            "INVALID_ARGS", "username is required", null
        )
        val password = call.argument<String>("password") ?: return result.error(
            "INVALID_ARGS", "password is required", null
        )

        scope.launch {
            try {
                val request = CreatePasswordRequest(
                    id = username,
                    password = password,
                )
                credentialManager.createCredential(
                    request = request,
                    activity = activity,
                )
                result.success(true)
            } catch (e: CreateCredentialException) {
                // Kullanıcı iptal etti veya cihaz desteklemiyor — hata değil
                result.success(false)
            } catch (e: Exception) {
                result.error("SAVE_ERROR", e.message, null)
            }
        }
    }

    private fun restoreCredentials(result: MethodChannel.Result) {
        scope.launch {
            try {
                val getPasswordOption = GetPasswordOption()
                val request = GetCredentialRequest(
                    credentialOptions = listOf(getPasswordOption),
                )
                val response = credentialManager.getCredential(
                    request = request,
                    context = activity,
                )
                val credential = response.credential
                if (credential is PasswordCredential) {
                    result.success(
                        mapOf(
                            "username" to credential.id,
                            "password" to credential.password,
                        )
                    )
                } else {
                    result.success(null)
                }
            } catch (e: GetCredentialException) {
                // Kayıt yok veya kullanıcı reddetti — hata değil
                result.success(null)
            } catch (e: Exception) {
                result.error("RESTORE_ERROR", e.message, null)
            }
        }
    }

    private fun clearCredentials(result: MethodChannel.Result) {
        scope.launch {
            try {
                credentialManager.clearCredentialState(
                    androidx.credentials.ClearCredentialStateRequest()
                )
                result.success(null)
            } catch (e: ClearCredentialException) {
                result.success(null)
            } catch (e: Exception) {
                result.error("CLEAR_ERROR", e.message, null)
            }
        }
    }
}
