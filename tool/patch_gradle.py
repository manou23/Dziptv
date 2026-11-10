#!/usr/bin/env python3
"""يعدّل ملف Gradle الذي ينشئه flutter create: معرّف التطبيق، minSdk، إصلاح WorkManager، والتوقيع."""
import os
import re
import sys

APP_ID = os.environ.get('APP_ID', 'com.mesut.iptv')
SIGNED = bool(os.environ.get('KEYSTORE_PATH'))
ROOT = os.environ.get('ANDROID_ROOT', 'android/app')

kts = os.path.exists(f'{ROOT}/build.gradle.kts')
path = f'{ROOT}/build.gradle.kts' if kts else f'{ROOT}/build.gradle'
s = open(path, encoding='utf-8').read()
log = []

# 1) minSdk = 24
s, n = re.subn(r'(minSdk(?:Version)?)(\s*=\s*|\s+)flutter\.minSdkVersion', r'\g<1>\g<2>24', s)
log.append(f'minSdk: {n}')

# 2) applicationId (لا نغيّر namespace)
s, n = re.subn(r'(applicationId(?:\s*=\s*|\s+))"[^"]+"', r'\g<1>"%s"' % APP_ID, s)
log.append(f'applicationId: {n}')
if n == 0:
    sys.exit('applicationId not found in ' + path)

# 3) التوقيع الثابت (فقط إن توفر المفتاح)
if SIGNED:
    if kts:
        block = '''    signingConfigs {
        create("release") {
            storeFile = file(System.getenv("KEYSTORE_PATH"))
            storePassword = System.getenv("KEYSTORE_PASSWORD")
            keyAlias = System.getenv("KEY_ALIAS")
            keyPassword = System.getenv("KEYSTORE_PASSWORD")
        }
    }

'''
        s, n1 = re.subn(r'(\n)(\s*)buildTypes\s*\{', lambda m: '\n' + block + m.group(2) + 'buildTypes {', s, count=1)
        s, n2 = re.subn(r'signingConfigs\.getByName\("debug"\)', 'signingConfigs.getByName("release")', s)
    else:
        block = '''    signingConfigs {
        release {
            storeFile file(System.getenv("KEYSTORE_PATH"))
            storePassword System.getenv("KEYSTORE_PASSWORD")
            keyAlias System.getenv("KEY_ALIAS")
            keyPassword System.getenv("KEYSTORE_PASSWORD")
        }
    }

'''
        s, n1 = re.subn(r'(\n)(\s*)buildTypes\s*\{', lambda m: '\n' + block + m.group(2) + 'buildTypes {', s, count=1)
        s, n2 = re.subn(r'signingConfigs\.debug', 'signingConfigs.release', s)
    log.append(f'signing block: {n1}, signingConfig switched: {n2}')
    if n1 == 0 or n2 == 0:
        sys.exit('could not patch signing in ' + path)
else:
    log.append('signing: skipped (no keystore -> debug signing)')

# 4) إصلاح انهيار AdMob عند الفتح (WorkManager 2.7.0)
if kts:
    s += '\ndependencies {\n    implementation("androidx.work:work-runtime:2.11.2")\n}\n'
else:
    s += "\ndependencies {\n    implementation 'androidx.work:work-runtime:2.11.2'\n}\n"
log.append('work-runtime: added')

open(path, 'w', encoding='utf-8').write(s)
print(path)
print('\n'.join('  ' + l for l in log))
