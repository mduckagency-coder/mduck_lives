package com.mduckagency.mduck_lives

import android.content.ActivityNotFoundException
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Compartilha uma imagem direto num app especifico (TikTok, Instagram,
        // WhatsApp...). Recebe uma lista de pacotes e usa o primeiro instalado;
        // devolve false se nenhum estiver instalado.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mduck/share")
            .setMethodCallHandler { call, result ->
                if (call.method != "shareImageToApp") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                val packages = call.argument<List<String>>("packages") ?: emptyList()
                val text = call.argument<String>("text")
                if (path == null) {
                    result.error("ARGS", "path obrigatorio", null)
                    return@setMethodCallHandler
                }
                // Mesmo provider do share_plus: cobre arquivos em cache/share_plus/.
                val uri = FileProvider.getUriForFile(this, "$packageName.flutter.share_provider", File(path))
                for (target in packages) {
                    val intent = Intent(Intent.ACTION_SEND).apply {
                        type = "image/png"
                        setPackage(target)
                        putExtra(Intent.EXTRA_STREAM, uri)
                        if (text != null) putExtra(Intent.EXTRA_TEXT, text)
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }
                    try {
                        startActivity(intent)
                        result.success(true)
                        return@setMethodCallHandler
                    } catch (_: ActivityNotFoundException) {
                        // app nao instalado: tenta o proximo pacote
                    }
                }
                result.success(false)
            }
    }
}
