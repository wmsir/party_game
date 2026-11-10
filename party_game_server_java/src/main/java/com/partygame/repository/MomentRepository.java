package com.partygame.repository;

import com.partygame.entity.Moment;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.List;

@Repository
public interface MomentRepository extends JpaRepository<Moment, String> {

    List<Moment> findAllByOrderByCreatedAtDesc();
}
