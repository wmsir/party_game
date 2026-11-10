package com.partygame;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.scheduling.annotation.EnableScheduling;

@SpringBootApplication
@EnableScheduling
public class PartyGameApplication {
    public static void main(String[] args) {
        SpringApplication.run(PartyGameApplication.class, args);
    }
}
