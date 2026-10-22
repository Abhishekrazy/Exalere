# libtorrent4j reaches libtorrent through a SWIG-generated JNI bridge. Every
# entry point in that bridge is resolved by name at runtime, so R8 must not
# rename or strip it. Without this, release builds crash with
# UnsatisfiedLinkError the first time a torrent is opened.
-keep class org.libtorrent4j.swig.libtorrent_jni { *; }
-keep class org.libtorrent4j.swig.** { *; }
-keep class org.libtorrent4j.** { *; }

# libtorrent4j's own recommendation for consumers that obfuscate.
-keepclasseswithmembernames class * {
    native <methods>;
}
