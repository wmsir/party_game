package com.partygame.repository;

import com.partygame.entity.FriendRequest;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface FriendRequestRepository extends JpaRepository<FriendRequest, String> {

    List<FriendRequest> findByToUserIdAndStatusOrderByCreatedAtDesc(String toUserId, String status);

    Optional<FriendRequest> findByFromUserIdAndToUserIdAndStatus(String fromUserId, String toUserId, String status);

    List<FriendRequest> findByToUserIdOrderByCreatedAtDesc(String toUserId);
}
