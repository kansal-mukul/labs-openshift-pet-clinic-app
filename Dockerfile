FROM alpine:latest AS jarbuilder
RUN apk add openjdk17 maven
WORKDIR /code
COPY . .
RUN mvn package -DskipTests
RUN cp target/*.jar app.jar
FROM alpine:latest AS builder
RUN apk add openjdk17
# ARG JAR_FILE=target/*.jar
WORKDIR /builder
# COPY ${JAR_FILE} app.jar
COPY --from=jarbuilder /code/app.jar app.jar
RUN jar xvf app.jar
RUN jdeps \
--ignore-missing-deps \
--multi-release 17 \
--print-module-deps \
--module-path="./BOOT-INF/lib/*" \
--class-path="./BOOT-INF/lib/*" \
app.jar > jre-deps.info
RUN jlink --verbose \
--compress 2 \
--strip-java-debug-attributes \
--no-header-files \
--no-man-pages \
--output jre \
--add-modules $(cat jre-deps.info)
# Create appuser
ENV USER=appuser
ENV UID=10001
RUN adduser \
    --disabled-password \
    --gecos "" \
    --home "/nonexistent" \
    --shell "/sbin/nologin" \
    --no-create-home \
    --uid "${UID}" \
    "${USER}"
FROM alpine:latest
WORKDIR /app
COPY --from=builder /etc/passwd /etc/passwd
COPY --from=builder /etc/group /etc/group
COPY --from=builder /builder/jre /jre
COPY --from=builder /builder/app.jar app.jar
ENV JAVA_HOME=/jre
ENV PATH="$JAVA_HOME/bin:$PATH"
EXPOSE 8076
USER appuser:appuser
ENTRYPOINT java -jar /app/app.jar
