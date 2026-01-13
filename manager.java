package com.research.controller;

import android.app.Activity;
import android.os.Bundle;
import android.util.Log;
import android.view.MotionEvent;
import android.view.View;
import android.widget.LinearLayout;
import android.widget.TextView;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import org.json.JSONObject;

public class ControllerApp extends Activity {

    private static final String TAG = "C2-Controller";
    private static final String C2_URL = "http://192.168.43.77:8000/cmd";  // ← שנה לכתובת שלך

    private TextView statusText;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(40, 60, 40, 40);

        statusText = new TextView(this);
        statusText.setText("Touch anywhere to send coordinates to target");
        statusText.setTextSize(18);
        root.addView(statusText);

        View touchZone = new View(this);
        touchZone.setBackgroundColor(0x220000CC);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                1400
        );
        touchZone.setLayoutParams(params);
        root.addView(touchZone);

        setContentView(root);

        touchZone.setOnTouchListener((v, event) -> {
            if (event.getAction() == MotionEvent.ACTION_DOWN ||
                event.getAction() == MotionEvent.ACTION_MOVE) {

                float x = event.getX();
                float y = event.getY();

                statusText.setText(String.format("X: %.0f   Y: %.0f", x, y));

                sendGesture(x, y);
                return true;
            }
            return false;
        });
    }

    private void sendGesture(float x, float y) {
        new Thread(() -> {
            try {
                JSONObject payload = new JSONObject();
                payload.put("action", "tap");
                payload.put("x", x);
                payload.put("y", y);

                URL url = new URL(C2_URL);
                HttpURLConnection conn = (HttpURLConnection) url.openConnection();
                conn.setRequestMethod("POST");
                conn.setDoOutput(true);
                conn.setRequestProperty("Content-Type", "application/json");

                try (OutputStream os = conn.getOutputStream()) {
                    os.write(payload.toString().getBytes("utf-8"));
                }

                int responseCode = conn.getResponseCode();
                runOnUiThread(() ->
                        statusText.append("\n→ HTTP " + responseCode));

                conn.disconnect();
            } catch (Exception e) {
                Log.e(TAG, "Failed to send gesture", e);
                runOnUiThread(() ->
                        statusText.append("\n→ Error"));
            }
        }).start();
    }
}
