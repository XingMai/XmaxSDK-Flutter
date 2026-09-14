package ai.xmax.sdk;

import android.util.Log;
import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/** Native logging only; RTC and storage remain managed by the Dart SDK. */
public final class XmaxSDKPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String TAG = "XmaxSDK";
    private static final int MAX_LINE_BYTES = 3000;
    private MethodChannel channel;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "ai.xmax.sdk/logging");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        if (channel != null) {
            channel.setMethodCallHandler(null);
            channel = null;
        }
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!"log".equals(call.method)) {
            result.notImplemented();
            return;
        }
        if (!(call.arguments instanceof java.util.Map)) {
            result.error("invalid_arguments", "Invalid log record", null);
            return;
        }
        Object level = call.argument("level");
        Object message = call.argument("message");
        int priority = priorityFor(level);
        if (priority == 0 || !(message instanceof String)) {
            result.error("invalid_arguments", "Invalid log record", null);
            return;
        }

        for (String line : ((String) message).split("\n", -1)) {
            writeLine(priority, line);
        }
        result.success(null);
    }

    private static int priorityFor(Object level) {
        if ("debug".equals(level)) return Log.DEBUG;
        if ("info".equals(level)) return Log.INFO;
        if ("warning".equals(level)) return Log.WARN;
        if ("error".equals(level)) return Log.ERROR;
        return 0;
    }

    private static void writeLine(int priority, String line) {
        // Logcat truncates long UTF-8 records. Split without breaking Chinese
        // characters or surrogate pairs, while preserving order and severity.
        int start = 0;
        int bytes = 0;
        for (int offset = 0; offset < line.length();) {
            int codePoint = line.codePointAt(offset);
            int size = codePoint <= 0x7f ? 1 : codePoint <= 0x7ff ? 2 : codePoint <= 0xffff ? 3 : 4;
            if (bytes + size > MAX_LINE_BYTES) {
                Log.println(priority, TAG, line.substring(start, offset));
                start = offset;
                bytes = 0;
            }
            bytes += size;
            offset += Character.charCount(codePoint);
        }
        Log.println(priority, TAG, line.substring(start));
    }
}
