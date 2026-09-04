# VolcEngine RTC references Honor earback APIs only when they are available on
# the device. They are optional and are not packaged with the RTC dependency.
-dontwarn com.hihonor.android.magicx.media.audio.interfaces.**

# Tencent COS depends on Fastjson, whose optional codecs reference desktop,
# money, Joda-Time, and Springfox types that are not used by XmaxSDK.
-dontwarn java.awt.**
-dontwarn javax.money.**
-dontwarn com.google.common.collect.ArrayListMultimap
-dontwarn com.google.common.collect.Multimap
-dontwarn org.javamoney.moneta.**
-dontwarn org.joda.time.**
-dontwarn springfox.documentation.spring.web.json.Json
