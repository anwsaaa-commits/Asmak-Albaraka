from pathlib import Path
import re

gradle = Path("android/app/build.gradle.kts")
if not gradle.exists():
    raise SystemExit("Expected android/app/build.gradle.kts after flutter create")

source = gradle.read_text(encoding="utf-8")
imports = "import java.io.FileInputStream" + chr(10) + "import java.util.Properties" + chr(10)
if "import java.util.Properties" not in source:
    source = imports + source

loader = """
val releaseProperties = Properties()
val releasePropertiesFile = rootProject.file("key.properties")
if (releasePropertiesFile.exists()) {
    releaseProperties.load(FileInputStream(releasePropertiesFile))
}

"""
if "val releaseProperties = Properties()" not in source:
    source = source.replace("android {", loader + "android {", 1)

signing = """
    signingConfigs {
        create("release") {
            storeFile = file(releaseProperties["storeFile"] as String)
            storePassword = releaseProperties["storePassword"] as String
            keyAlias = releaseProperties["keyAlias"] as String
            keyPassword = releaseProperties["keyPassword"] as String
        }
    }

"""
if 'create("release")' not in source:
    source = source.replace("    buildTypes {", signing + "    buildTypes {", 1)

source = source.replace('signingConfig = signingConfigs.getByName("debug")', 'signingConfig = signingConfigs.getByName("release")', 1)
gradle.write_text(source, encoding="utf-8")
manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    manifest_source = manifest.read_text(encoding='utf-8')
    manifest_source = re.sub(r'android:label="[^"]+"', 'android:label="أسماك البركة"', manifest_source, count=1)
    manifest.write_text(manifest_source, encoding='utf-8')

print('Release signing configuration and Arabic app label applied.')