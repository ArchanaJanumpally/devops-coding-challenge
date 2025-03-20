
FROM public.ecr.aws/docker/library/openjdk:17-slim 

# Copy the built JAR from the previous stage
COPY /target/*.jar /app.jar

# Expose the application port
EXPOSE 8080

# Run the application
ENTRYPOINT ["java", "-jar", "app.jar"]
