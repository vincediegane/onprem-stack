package com.example.intranet;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.web.bind.annotation.*;

import java.security.Principal;
import java.util.Map;

@SpringBootApplication
public class IntranetApplication {

  public static void main(String[] args) { SpringApplication.run(IntranetApplication.class, args); }

  @Bean
  SecurityFilterChain security(HttpSecurity http) throws Exception {
    http
      .csrf(c -> c.disable())
      .authorizeHttpRequests(a -> a
        .requestMatchers("/actuator/health", "/actuator/prometheus", "/public/**").permitAll()
        .anyRequest().authenticated())
      .oauth2ResourceServer(o -> o.jwt(jwt -> {}));
    return http.build();
  }

  @RestController
  static class Api {
    @GetMapping("/public/ping")  public Map<String,String> ping() { return Map.of("status","ok"); }
    @GetMapping("/api/me")       public Principal me(Principal p) { return p; }
    @GetMapping("/api/secret")   public Map<String,String> secret() { return Map.of("data","top-secret intranet"); }
  }
}
