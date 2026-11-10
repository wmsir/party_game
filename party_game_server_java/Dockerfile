FROM eclipse-temurin:17-jre
WORKDIR /app
COPY target/party-game-server-1.0.0.jar app.jar
EXPOSE 9001
ENTRYPOINT ["java", "-Dfile.encoding=UTF-8", "-Dsun.jnu.encoding=UTF-8", "-jar", "/app/app.jar", "--server.port=9001"]
