package com.partygame;

import com.partygame.entity.User;
import com.partygame.game.PartyWheelPromptBank;
import com.partygame.game.UndercoverWordBank;
import com.partygame.repository.UserRepository;
import com.partygame.security.AdminAuthService;
import com.partygame.security.UserAuthService;
import com.partygame.service.GameService;
import com.partygame.service.ShopService;
import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.*;

class CommercialCoreTests {

    @Test
    void vipLevelThresholdsMatchSpec() {
        assertEquals(0, ShopService.calculateVipLevel(0));
        assertEquals(1, ShopService.calculateVipLevel(10));
        assertEquals(5, ShopService.calculateVipLevel(5000));
        assertEquals(10, ShopService.calculateVipLevel(188888));
    }

    @Test
    void rankTierCalculationMatchesSpec() {
        assertEquals("暂无段位", GameService.calculateRankTier(0));
        assertEquals("黄金II", GameService.calculateRankTier(400));
        assertEquals("最强王者", GameService.calculateRankTier(3000));
    }

    @Test
    void undercoverWordBankHasAtLeast60PairsAndClues() {
        assertTrue(UndercoverWordBank.WORD_PAIRS.size() >= 60);
        for (List<String> pair : UndercoverWordBank.WORD_PAIRS) {
            assertEquals(2, pair.size());
            assertNotEquals(pair.get(0), pair.get(1));
        }
        Set<String> used = new HashSet<>();
        String clue = UndercoverWordBank.pickClue("汉堡包", used);
        assertNotNull(clue);
        assertFalse(clue.isBlank());
        assertFalse(used.isEmpty());
    }

    @Test
    void partyWheelPromptBankProducesNonEmptyPrompts() {
        Set<String> used = new HashSet<>();
        Map<String, Object> truthPayload = PartyWheelPromptBank.buildSpinPayload(1, "icebreaker", "Tester", used);
        assertEquals("TRUTH", truthPayload.get("segmentType"));
        assertNotNull(truthPayload.get("promptContent"));
        assertFalse(truthPayload.get("promptContent").toString().isBlank());

        Map<String, Object> darePayload = PartyWheelPromptBank.buildSpinPayload(3, "friends", "Tester", used);
        assertEquals("DARE", darePayload.get("segmentType"));
        assertNotNull(darePayload.get("promptContent"));
    }

    @Test
    void adminAuthTokenLifecycleWorks() {
        AdminAuthService authService = new AdminAuthService();
        AdminAuthService.AdminSession session = new AdminAuthService.AdminSession(
                "admin", "Developer", "SYSTEM_DEVELOPER", System.currentTimeMillis() + 60_000L
        );
        String token = authService.issueToken(session);
        assertTrue(token.startsWith("ADM-"));
        assertNotNull(authService.validateToken("Bearer " + token));
        authService.revokeToken(token);
        assertNull(authService.validateToken(token));
    }

    @Test
    void userAuthSignedTokenBindsAndVerifiesUser() {
        UserRepository repo = Mockito.mock(UserRepository.class);
        UserAuthService userAuthService = new UserAuthService(repo);
        userAuthService.init();

        String tok = userAuthService.issueSignedToken("U1001");
        assertTrue(tok.startsWith("PGU1."));
        User dbUser = User.builder().id("U1001").nickname("Tester").token(tok).build();
        Mockito.when(repo.findById("U1001")).thenReturn(Optional.of(dbUser));

        User authed = userAuthService.requireUser("Bearer " + tok, null, "U1001");
        assertEquals("U1001", authed.getId());
        assertThrows(SecurityException.class, () -> userAuthService.requireUser("Bearer " + tok, null, "U9999"));
        assertThrows(SecurityException.class, () -> userAuthService.requireUser(null, null, "U1001"));
    }
}
