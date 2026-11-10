package com.partygame.repository;

import com.partygame.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

@Repository
public interface UserRepository extends JpaRepository<User, String> {

    Optional<User> findByPhone(String phone);
    List<User> findAllByPhone(String phone);

    Optional<User> findByUsername(String username);
    List<User> findAllByUsername(String username);

    @Query("SELECT u FROM User u WHERE " +
           "LOWER(u.id) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "LOWER(u.nickname) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "LOWER(u.username) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "u.phone LIKE CONCAT('%', :kw, '%')")
    List<User> searchUsers(@Param("kw") String keyword);

    @Query(value = "SELECT u FROM User u WHERE " +
           "(:kw IS NULL OR :kw = '' OR " +
           "LOWER(u.id) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "LOWER(u.nickname) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "LOWER(u.username) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "u.phone LIKE CONCAT('%', :kw, '%')) AND " +
           "(:isGuest IS NULL OR u.isGuest = :isGuest) AND " +
           "(:minVip IS NULL OR u.vipLevel >= :minVip) AND " +
           "(:minRecharge IS NULL OR u.totalRechargeRmb >= :minRecharge)",
           countQuery = "SELECT COUNT(u) FROM User u WHERE " +
           "(:kw IS NULL OR :kw = '' OR " +
           "LOWER(u.id) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "LOWER(u.nickname) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "LOWER(u.username) LIKE LOWER(CONCAT('%', :kw, '%')) OR " +
           "u.phone LIKE CONCAT('%', :kw, '%')) AND " +
           "(:isGuest IS NULL OR u.isGuest = :isGuest) AND " +
           "(:minVip IS NULL OR u.vipLevel >= :minVip) AND " +
           "(:minRecharge IS NULL OR u.totalRechargeRmb >= :minRecharge)")
    Page<User> searchUsersPage(
            @Param("kw") String keyword,
            @Param("isGuest") Boolean isGuest,
            @Param("minVip") Integer minVip,
            @Param("minRecharge") Integer minRecharge,
            Pageable pageable);

    List<User> findTop10ByOrderByRankScoreDesc();

    List<User> findTop10ByOrderByCoinsDesc();

    List<User> findTop20ByOrderByUpdatedAtDesc();

    List<User> findTop30ByOrderByLastLoginAtDesc();

    long countByIsGuestTrue();

    long countByIsGuestFalse();

    long countByCreatedAtAfter(java.time.LocalDateTime time);

    long countByLastLoginAtAfter(java.time.LocalDateTime time);

    @Query("SELECT COALESCE(SUM(u.totalRechargeRmb), 0) FROM User u")
    Long sumTotalRechargeRmb();
}
