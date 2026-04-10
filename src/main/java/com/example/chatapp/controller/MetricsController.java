package com.example.chatapp.controller;

import com.example.chatapp.service.MetricsService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.HashMap;
import java.util.Map;

@RestController
@RequestMapping("/api/metrics")
public class MetricsController {

    @Autowired
    private MetricsService metricsService;

    @GetMapping
    public Map<String, Object> getMetrics() {
        Map<String, Object> metrics = new HashMap<>();
        metrics.put("activeUsers", metricsService.getActiveUsers());
        metrics.put("totalMessages", metricsService.getTotalMessages());
        metrics.put("totalJoins", metricsService.getTotalJoins());
        metrics.put("totalLeaves", metricsService.getTotalLeaves());
        metrics.put("startTime", metricsService.getStartTime());
        metrics.put("uptimeSeconds", metricsService.getUptimeSeconds());
        metrics.put("messageRatePerSecond", Math.round(metricsService.getMessageRate() * 100.0) / 100.0);
        return metrics;
    }
}
