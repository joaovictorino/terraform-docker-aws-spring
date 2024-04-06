FROM maven:3.6-openjdk-17-slim as BUILD
COPY springapp/. /src
WORKDIR /src
RUN mvn package -DskipTests

FROM openjdk:17.0-slim-bullseye
EXPOSE 80
COPY --from=BUILD /src/target/spring-petclinic-3.2.0-SNAPSHOT.jar /app.jar
ENTRYPOINT ["java","-Dspring-boot.run.profiles=mysql","-jar","/app.jar", "--server.port=80"]
