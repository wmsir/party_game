package com.partygame.repository;

import com.partygame.entity.DirectMessageRecord;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import org.springframework.data.jpa.repository.Modifying;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;

@Repository
public interface DirectMessageRepository extends JpaRepository<DirectMessageRecord, String> {

    @Query("SELECT d FROM DirectMessageRecord d WHERE LOWER(TRIM(d.toUserId)) = LOWER(TRIM(:toUserId)) AND (d.delivered = false OR d.delivered IS NULL) ORDER BY d.timestamp ASC")
    List<DirectMessageRecord> findByToUserIdAndDeliveredFalseOrderByTimestampAsc(@Param("toUserId") String toUserId);

    @Query("SELECT d FROM DirectMessageRecord d WHERE LOWER(TRIM(d.toUserId)) = LOWER(TRIM(:toUserId)) AND (d.isRead = false OR d.isRead IS NULL) ORDER BY d.timestamp ASC")
    List<DirectMessageRecord> findByToUserIdAndIsReadFalseOrderByTimestampAsc(@Param("toUserId") String toUserId);

    @Query("SELECT COUNT(d) FROM DirectMessageRecord d WHERE LOWER(TRIM(d.toUserId)) = LOWER(TRIM(:toUserId)) AND LOWER(TRIM(d.fromUserId)) = LOWER(TRIM(:fromUserId)) AND (d.isRead = false OR d.isRead IS NULL)")
    int countUnreadBetween(@Param("toUserId") String toUserId, @Param("fromUserId") String fromUserId);

    @Query(value = "SELECT * FROM direct_messages WHERE " +
           "(LOWER(TRIM(from_user_id)) = LOWER(TRIM(:u1)) AND LOWER(TRIM(to_user_id)) = LOWER(TRIM(:u2))) OR " +
           "(LOWER(TRIM(from_user_id)) = LOWER(TRIM(:u2)) AND LOWER(TRIM(to_user_id)) = LOWER(TRIM(:u1))) " +
           "ORDER BY timestamp DESC LIMIT 1", nativeQuery = true)
    DirectMessageRecord findLatestMessageBetween(@Param("u1") String u1, @Param("u2") String u2);

    @Modifying
    @Transactional
    @Query("UPDATE DirectMessageRecord d SET d.isRead = true, d.delivered = true WHERE LOWER(TRIM(d.toUserId)) = LOWER(TRIM(:toUserId)) AND LOWER(TRIM(d.fromUserId)) = LOWER(TRIM(:fromUserId))")
    int markAsReadBetween(@Param("toUserId") String toUserId, @Param("fromUserId") String fromUserId);

    @Query("SELECT d FROM DirectMessageRecord d WHERE " +
           "(LOWER(TRIM(d.fromUserId)) = LOWER(TRIM(:u1)) AND LOWER(TRIM(d.toUserId)) = LOWER(TRIM(:u2))) OR " +
           "(LOWER(TRIM(d.fromUserId)) = LOWER(TRIM(:u2)) AND LOWER(TRIM(d.toUserId)) = LOWER(TRIM(:u1))) " +
           "ORDER BY d.timestamp ASC")
    List<DirectMessageRecord> findChatHistory(@Param("u1") String u1, @Param("u2") String u2);
}
