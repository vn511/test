package com.example.chatapp.service;

import org.springframework.stereotype.Service;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;
import java.util.concurrent.atomic.AtomicInteger;

@Service
public class MetricsService {

    private static final DateTimeFormatter FORMATTER =
            DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm:ss");

    private final AtomicInteger activeUsers = new AtomicInteger(0);
    private final AtomicInteger totalMessages = new AtomicInteger(0);
    private final AtomicInteger totalJoins = new AtomicInteger(0);
    private final AtomicInteger totalLeaves = new AtomicInteger(0);
    private LocalDateTime startTime = LocalDateTime.now();

    public void recordUserJoin() {
        activeUsers.incrementAndGet();
        totalJoins.incrementAndGet();
    }

    public void recordUserLeave() {
        int current = activeUsers.get();
        if (current > 0) {
            activeUsers.decrementAndGet();
        }
        totalLeaves.incrementAndGet();
    }

    public void recordMessage() {
        totalMessages.incrementAndGet();
    }

    public int getActiveUsers() {
        return activeUsers.get();
    }

    public int getTotalMessages() {
        return totalMessages.get();
    }

    public int getTotalJoins() {
        return totalJoins.get();
    }

    public int getTotalLeaves() {
        return totalLeaves.get();
    }

    public String getStartTime() {
        return startTime.format(FORMATTER);
    }

    public long getUptimeSeconds() {
        return java.time.temporal.ChronoUnit.SECONDS.between(startTime, LocalDateTime.now());
    }

    public double getMessageRate() {
        long uptime = getUptimeSeconds();
        if (uptime == 0) return 0;
        return (double) totalMessages.get() / uptime;
    }
}
