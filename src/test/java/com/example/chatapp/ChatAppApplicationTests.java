package com.example.chatapp;

import com.example.chatapp.model.ChatMessage;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.SpringBootTest.WebEnvironment;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
class ChatAppApplicationTests {

    @Test
    void contextLoads() {
        // Verifies the entire Spring context starts up correctly
    }

    @Test
    void chatMessageModel() {
        ChatMessage msg = new ChatMessage(
                ChatMessage.MessageType.CHAT,
                "Hello World",
                "Alice",
                "2026-04-09 10:00:00"
        );

        assertThat(msg.getSender()).isEqualTo("Alice");
        assertThat(msg.getContent()).isEqualTo("Hello World");
        assertThat(msg.getType()).isEqualTo(ChatMessage.MessageType.CHAT);
        assertThat(msg.getTimestamp()).isEqualTo("2026-04-09 10:00:00");
    }

    @Test
    void chatMessageDefaultConstructor() {
        ChatMessage msg = new ChatMessage();
        msg.setType(ChatMessage.MessageType.JOIN);
        msg.setSender("Bob");
        msg.setContent("Bob joined");

        assertThat(msg.getType()).isEqualTo(ChatMessage.MessageType.JOIN);
        assertThat(msg.getSender()).isEqualTo("Bob");
    }
}
