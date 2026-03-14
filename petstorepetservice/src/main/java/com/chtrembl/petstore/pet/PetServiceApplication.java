package com.chtrembl.petstore.pet;

import com.chtrembl.petstore.pet.model.ContainerEnvironment;
import com.chtrembl.petstore.pet.model.DataPreload;
import com.microsoft.applicationinsights.attach.ApplicationInsights;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.ExitCodeGenerator;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;

@SpringBootApplication
public class PetServiceApplication implements CommandLineRunner {

	private static final Logger logger = LoggerFactory.getLogger(PetServiceApplication.class);

	@Bean
	public ContainerEnvironment containerEnvvironment() {
		return new ContainerEnvironment();
	}

	@Bean
	public DataPreload dataPreload() {
		return new DataPreload();
	}

	@Override
	public void run(String... arg0) throws Exception {
		if (arg0.length > 0 && arg0[0].equals("exitcode")) {
			throw new ExitException();
		}
	}

	public static void main(String[] args) throws Exception {
		configureApplicationInsights();
		new SpringApplication(PetServiceApplication.class).run(args);
	}

	private static void configureApplicationInsights() {
		String connectionString = System.getenv("APPLICATIONINSIGHTS_CONNECTION_STRING");
		if (connectionString != null && !connectionString.isEmpty()) {
			try {
				ApplicationInsights.attach();
				logger.info("Application Insights enabled successfully for petstorepetservice");
			} catch (Exception e) {
				logger.warn("Failed to attach Application Insights: {}", e.getMessage());
			}
		} else {
			logger.info("Application Insights not configured (no connection string). Set APPLICATIONINSIGHTS_CONNECTION_STRING to enable.");
		}
	}

	class ExitException extends RuntimeException implements ExitCodeGenerator {
		private static final long serialVersionUID = 1L;

		@Override
		public int getExitCode() {
			return 10;
		}

	}
}
