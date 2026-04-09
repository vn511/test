package com.example.chatapp.model;

public class ChatMessage {

    public enum MessageType {
        CHAT, JOIN, LEAVE
    }

    private MessageType type;
    private String content;
    private String sender;
    private String timestamp;

    public ChatMessage() {}

    public ChatMessage(MessageType type, String content, String sender, String timestamp) {
        this.type = type;
        this.content = content;
        this.sender = sender;
        this.timestamp = timestamp;
    }

    public MessageType getType() { return type; }
    public void setType(MessageType type) { this.type = type; }

    public String getContent() { return content; }
    public void setContent(String content) { this.content = content; }

    public String getSender() { return sender; }
    public void setSender(String sender) { this.sender = sender; }

    public String getTimestamp() { return timestamp; }
    public void setTimestamp(String timestamp) { this.timestamp = timestamp; }
}
