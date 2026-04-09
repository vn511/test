# ChatApp — Real-time WebSocket Messaging

A real-time chat application built with **Spring Boot** and **WebSocket (STOMP/SockJS)**, with a full **CI/CD pipeline** via GitHub Actions.

## Features

- Real-time bi-directional messaging via WebSocket
- Join/leave notifications
- Clean single-page chat UI (no framework dependencies)
- Actuator health endpoint at `/actuator/health`
- Docker support
- CI/CD: build, test, Docker image build, OWASP dependency scan

## Tech Stack

| Layer       | Technology                     |
|-------------|-------------------------------|
| Backend     | Java 17, Spring Boot 3.2, Spring WebSocket |
| Messaging   | STOMP over SockJS              |
| Frontend    | HTML5, Vanilla JS              |
| Build       | Maven                          |
| Container   | Docker (multi-stage build)     |
| CI/CD       | GitHub Actions                 |

## Running Locally

**Prerequisites:** Java 17+, Maven 3.8+

```bash
mvn spring-boot:run
```

Open [http://localhost:8080](http://localhost:8080) in multiple browser tabs.

## Running with Docker

```bash
docker build -t chatapp .
docker run -p 8080:8080 chatapp
```

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci-cd.yml`) runs on every push and pull request to `main`/`master`:

1. **Build & Test** — Compile, run unit tests, upload JAR artifact
2. **Code Quality** — Maven verify
3. **Docker Build** — Build Docker image (on push to main)
4. **Security Scan** — OWASP dependency vulnerability check
5. **Deployment Summary** — Job status summary in GitHub Actions

## API / Endpoints

| Endpoint              | Description               |
|-----------------------|---------------------------|
| `GET /`               | Chat UI                   |
| `WS /ws`              | WebSocket STOMP endpoint  |
| `GET /actuator/health`| Health check              |

### STOMP Destinations

| Direction | Destination              | Description         |
|-----------|--------------------------|---------------------|
| Client → Server | `/app/chat.sendMessage` | Send a chat message |
| Client → Server | `/app/chat.addUser`     | Join the chat room  |
| Server → Client | `/topic/public`         | Receive messages    |
