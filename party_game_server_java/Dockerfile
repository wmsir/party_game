# ==============================================================================
# Stage 1: Build Spring Boot executable JAR
# ==============================================================================
FROM maven:3.9.9-eclipse-temurin-17 AS builder
WORKDIR /build

COPY pom.xml .
RUN mvn -B dependency:go-offline

COPY src ./src
RUN mvn -B clean package

# ==============================================================================
# Stage 2: Minimal hardened JRE 17 runtime
# ==============================================================================
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

RUN apk add --no-cache curl tzdata \
    && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo "Asia/Shanghai" > /etc/timezone \
    && addgroup -S partygame \
    && adduser -S partygame -G partygame \
    && mkdir -p /app/uploads \
    && chown -R partygame:partygame /app

COPY --from=builder /build/target/party-game-server-1.0.0.jar /app/app.jar
RUN chown partygame:partygame /app/app.jar

ENV TZ=Asia/Shanghai \
    JAVA_TOOL_OPTIONS="-XX:+UseContainerSupport -XX:MaxRAMPercentage=75.0 -Dfile.encoding=UTF-8 -Dsun.jnu.encoding=UTF-8"

USER partygame
EXPOSE 9001

HEALTHCHECK --interval=30s --timeout=5s --start-period=45s --retries=3 \
    CMD curl -fsS http://127.0.0.1:9001/health || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar", "--server.port=9001"]
