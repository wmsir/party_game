package com.partygame.repository;

import com.partygame.entity.FriendRelation;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FriendRelationRepository extends JpaRepository<FriendRelation, Long> {

    List<FriendRelation> findByUserId(String userId);

    Optional<FriendRelation> findByUserIdAndFriendId(String userId, String friendId);

    boolean existsByUserIdAndFriendId(String userId, String friendId);

    void deleteByUserIdAndFriendId(String userId, String friendId);
}
