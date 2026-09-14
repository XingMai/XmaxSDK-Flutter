package ai.xmax.sdk;

import android.graphics.BitmapFactory;
import android.media.MediaMetadataRetriever;
import android.os.Handler;
import android.os.Looper;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/** Storage metadata only: reads dimensions without decoding image/video frames. */
final class MediaFileMetadataManager implements MethodChannel.MethodCallHandler {
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private boolean detached;

    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        if (!"readResolution".equals(call.method)) {
            result.notImplemented();
            return;
        }
        if (!(call.arguments instanceof Map) || detached) {
            result.success(null);
            return;
        }
        Object path = call.argument("filePath");
        Object data = call.argument("data");
        boolean video = "video".equals(call.argument("mediaType"));
        worker.execute(() -> {
            Map<String, Integer> resolution = readResolution(
                path instanceof String ? (String) path : null,
                data instanceof byte[] ? (byte[]) data : null,
                video
            );
            main.post(() -> {
                if (!detached) result.success(resolution);
            });
        });
    }

    void dispose() {
        detached = true;
        worker.shutdownNow();
    }

    private static Map<String, Integer> readResolution(String path, byte[] data, boolean video) {
        try {
            int width;
            int height;
            if (video) {
                if (path == null) return null;
                MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                try {
                    retriever.setDataSource(path);
                    width = Integer.parseInt(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH));
                    height = Integer.parseInt(retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT));
                    String rotation = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION);
                    if ("90".equals(rotation) || "270".equals(rotation)) {
                        int originalWidth = width;
                        width = height;
                        height = originalWidth;
                    }
                } finally {
                    retriever.release();
                }
            } else {
                BitmapFactory.Options options = new BitmapFactory.Options();
                options.inJustDecodeBounds = true;
                if (path != null) {
                    BitmapFactory.decodeFile(path, options);
                } else if (data != null) {
                    BitmapFactory.decodeByteArray(data, 0, data.length, options);
                } else {
                    return null;
                }
                width = options.outWidth;
                height = options.outHeight;
            }
            if (width <= 0 || height <= 0) return null;
            Map<String, Integer> resolution = new HashMap<>();
            resolution.put("width", width);
            resolution.put("height", height);
            return resolution;
        } catch (Exception ignored) {
            // Unsupported or corrupt metadata cannot fail the actual upload.
            return null;
        }
    }
}
