package com.partygame.repository;

import com.partygame.entity.UserIntimacy;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserIntimacyRepository extends JpaRepository<UserIntimacy, Long> {
    Optional<UserIntimacy> findByUser1IdAndUser2Id(String user1Id, String user2Id);
    List<UserIntimacy> findByUser1IdOrUser2Id(String user1Id, String user2Id);
}
