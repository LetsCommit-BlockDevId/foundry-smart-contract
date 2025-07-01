// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {mIDRX} from "../src/mIDRX.sol";

contract LetsCommitClaimUnattendedFeesTest is Test {
    LetsCommit public letsCommit;
    mIDRX public midrxToken;

    address public organizer = address(0x1);
    address public participant1 = address(0x2);
    address public participant2 = address(0x3);
    address public participant3 = address(0x4);

    uint256 public eventId;
    uint8 public sessionIndex = 0;

    function setUp() public {
        // Deploy mIDRX token
        midrxToken = new mIDRX();

        // Deploy LetsCommit contract
        letsCommit = new LetsCommit(address(midrxToken));

        // Setup initial balances
        uint256 initialBalance = 1000000 * 10 ** 18; // 1M tokens
        midrxToken.mint(organizer, initialBalance);
        midrxToken.mint(participant1, initialBalance);
        midrxToken.mint(participant2, initialBalance);
        midrxToken.mint(participant3, initialBalance);

        // Create an event
        vm.startPrank(organizer);

        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](2);
        sessions[0] = LetsCommit.Session({
            startSessionTime: block.timestamp + 7 days,
            endSessionTime: block.timestamp + 7 days + 2 hours,
            attendedCount: 0
        });
        sessions[1] = LetsCommit.Session({
            startSessionTime: block.timestamp + 14 days,
            endSessionTime: block.timestamp + 14 days + 2 hours,
            attendedCount: 0
        });

        string[5] memory tags = ["tech", "blockchain", "", "", ""];

        letsCommit.createEvent({
            title: "Test Event",
            description: "Test Description",
            location: "Test Location",
            imageUri: "https://test.com/image.jpg",
            priceAmount: 100, // 100 tokens event fee
            commitmentAmount: 50, // 50 tokens commitment fee
            maxParticipant: 10,
            startSaleDate: block.timestamp,
            endSaleDate: block.timestamp + 5 days,
            tags: tags,
            _sessions: sessions
        });

        eventId = letsCommit.eventId();
        vm.stopPrank();

        // Enroll participants
        _enrollParticipant(participant1);
        _enrollParticipant(participant2);
        _enrollParticipant(participant3);
    }

    function _enrollParticipant(address participant) internal {
        vm.startPrank(participant);

        uint256 totalPayment = (100 + 50) * 10 ** 18; // Event fee + commitment fee with decimals
        midrxToken.approve(address(letsCommit), totalPayment);
        letsCommit.enrollEvent(eventId);

        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_Success() public {
        // Fast forward to session time
        vm.warp(block.timestamp + 7 days);

        // Organizer sets session code
        vm.startPrank(organizer);
        letsCommit.setSessionCode(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        // Only participant1 attends the session
        vm.startPrank(participant1);
        letsCommit.attendSession(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        // Fast forward past session end time
        vm.warp(block.timestamp + 3 hours);

        // Preview unattended fees
        (uint256 unattendedCount, uint256 totalFees, uint256 organizerShare, uint256 protocolShare) =
            letsCommit.previewUnattendedFeesForSession(eventId, sessionIndex);

        assertEq(unattendedCount, 2, "Should have 2 unattended participants");
        assertGt(totalFees, 0, "Should have unattended fees to claim");
        assertEq(organizerShare, (totalFees * 70) / 100, "Organizer should get 70%");
        assertEq(protocolShare, totalFees - organizerShare, "Protocol should get 30%");

        // Record initial balances
        uint256 organizerBalanceBefore = midrxToken.balanceOf(organizer);
        uint256 protocolTVLBefore = letsCommit.getProtocolTVL();

        // Organizer claims unattended fees
        vm.startPrank(organizer);
        bool success = letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();

        assertTrue(success, "Claim should be successful");

        // Verify balances changed correctly
        uint256 organizerBalanceAfter = midrxToken.balanceOf(organizer);
        uint256 protocolTVLAfter = letsCommit.getProtocolTVL();

        assertEq(
            organizerBalanceAfter - organizerBalanceBefore, organizerShare, "Organizer should receive correct amount"
        );
        assertEq(protocolTVLAfter - protocolTVLBefore, protocolShare, "Protocol TVL should increase by correct amount");

        // Verify claim timestamp is recorded
        uint256 claimTimestamp = letsCommit.getSessionUnattendedClaimTimestamp(eventId, sessionIndex);
        assertGt(claimTimestamp, 0, "Claim timestamp should be recorded");
        assertTrue(letsCommit.hasClaimedUnattendedFees(eventId, sessionIndex), "Should show as claimed");
    }

    function test_ClaimUnattendedFees_RevertWhen_NotOrganizer() public {
        // Fast forward to session time and past end
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(organizer);
        letsCommit.setSessionCode(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        vm.warp(block.timestamp + 3 hours);

        // Non-organizer tries to claim
        vm.startPrank(participant1);
        vm.expectRevert(LetsCommit.NotEventOrganizer.selector);
        letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_RevertWhen_SessionNotEnded() public {
        // Fast forward to session time but not past end
        vm.warp(block.timestamp + 7 days + 1 hours); // 1 hour into 2-hour session

        vm.startPrank(organizer);
        letsCommit.setSessionCode(eventId, sessionIndex, "CODE");

        vm.expectRevert(LetsCommit.SessionNotEnded.selector);
        letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_RevertWhen_SessionCodeNotSet() public {
        // Fast forward past session end time
        vm.warp(block.timestamp + 7 days + 3 hours);

        vm.startPrank(organizer);
        vm.expectRevert(LetsCommit.SessionCodeNotSet.selector);
        letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_RevertWhen_AlreadyClaimed() public {
        // Fast forward and set up session
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(organizer);
        letsCommit.setSessionCode(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        vm.warp(block.timestamp + 3 hours);

        // First claim (should succeed)
        vm.startPrank(organizer);
        letsCommit.claimUnattendedFees(eventId, sessionIndex);

        // Second claim (should fail)
        vm.expectRevert(LetsCommit.UnattendedFeesAlreadyClaimed.selector);
        letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_RevertWhen_NoUnattendedParticipants() public {
        // Fast forward to session time
        vm.warp(block.timestamp + 7 days);

        // Organizer sets session code
        vm.startPrank(organizer);
        letsCommit.setSessionCode(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        // All participants attend
        vm.startPrank(participant1);
        letsCommit.attendSession(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        vm.startPrank(participant2);
        letsCommit.attendSession(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        vm.startPrank(participant3);
        letsCommit.attendSession(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        // Fast forward past session end
        vm.warp(block.timestamp + 3 hours);

        // Try to claim (should fail - no unattended participants)
        vm.startPrank(organizer);
        vm.expectRevert(LetsCommit.NoUnattendedParticipants.selector);
        letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_RevertWhen_EventDoesNotExist() public {
        uint256 nonExistentEventId = 999;

        vm.startPrank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.EventDoesNotExist.selector, nonExistentEventId));
        letsCommit.claimUnattendedFees(nonExistentEventId, sessionIndex);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_RevertWhen_InvalidSessionIndex() public {
        uint8 invalidSessionIndex = 5; // Our test event only has 2 sessions (0 and 1)

        // Fast forward past session end time
        vm.warp(block.timestamp + 7 days + 3 hours);

        vm.startPrank(organizer);
        vm.expectRevert(LetsCommit.InvalidSessionIndex.selector);
        letsCommit.claimUnattendedFees(eventId, invalidSessionIndex);
        vm.stopPrank();
    }

    // @TODO: fix this error
    /*
    function test_ClaimUnattendedFees_WithNoParticipants() public {
        // Create a new event with no participants
        vm.startPrank(organizer);
        
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = LetsCommit.Session({
            startSessionTime: block.timestamp + 7 days,
            endSessionTime: block.timestamp + 7 days + 2 hours,
            attendedCount: 0
        });
        
        string[5] memory tags = ["test", "", "", "", ""];
        
        letsCommit.createEvent({
            title: "Empty Event",
            description: "Event with no participants",
            location: "Test Location",
            imageUri: "https://test.com/image.jpg",
            priceAmount: 100,
            commitmentAmount: 50,
            maxParticipant: 10,
            startSaleDate: block.timestamp,
            endSaleDate: block.timestamp + 5 days,
            tags: tags,
            _sessions: sessions
        });
        
        uint256 emptyEventId = letsCommit.eventId();
        vm.stopPrank();
        
        // Fast forward to session time and set code
        vm.warp(block.timestamp + 7 days);
        
        vm.startPrank(organizer);
        letsCommit.setSessionCode(emptyEventId, 0, "CODE");
        vm.stopPrank();
        
        // Fast forward past session end
        vm.warp(block.timestamp + 3 hours);
        
        // Try to claim (should fail - no participants enrolled)
        vm.startPrank(organizer);
        vm.expectRevert(LetsCommit.NoUnattendedParticipants.selector);
        letsCommit.claimUnattendedFees(emptyEventId, 0);
        vm.stopPrank();
    }
    */

    function test_ClaimUnattendedFees_WithZeroCommitmentAmount() public {
        // Create a new event with zero commitment amount
        vm.startPrank(organizer);

        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](1);
        sessions[0] = LetsCommit.Session({
            startSessionTime: block.timestamp + 7 days,
            endSessionTime: block.timestamp + 7 days + 2 hours,
            attendedCount: 0
        });

        string[5] memory tags = ["test", "", "", "", ""];

        letsCommit.createEvent({
            title: "Zero Commitment Event",
            description: "Event with zero commitment fee",
            location: "Test Location",
            imageUri: "https://test.com/image.jpg",
            priceAmount: 100,
            commitmentAmount: 0, // Zero commitment amount
            maxParticipant: 10,
            startSaleDate: block.timestamp,
            endSaleDate: block.timestamp + 5 days,
            tags: tags,
            _sessions: sessions
        });

        uint256 zeroCommitmentEventId = letsCommit.eventId();
        vm.stopPrank();

        // Enroll a participant in the zero commitment event
        vm.startPrank(participant1);
        uint256 totalPayment = 100 * 10 ** 18; // Only event fee, no commitment fee
        midrxToken.approve(address(letsCommit), totalPayment);
        letsCommit.enrollEvent(zeroCommitmentEventId);
        vm.stopPrank();

        // Fast forward to session time and set code
        vm.warp(block.timestamp + 7 days);

        vm.startPrank(organizer);
        letsCommit.setSessionCode(zeroCommitmentEventId, 0, "CODE");
        vm.stopPrank();

        // Fast forward past session end (participant doesn't attend)
        vm.warp(block.timestamp + 3 hours);

        // Try to claim (should fail - no commitment fees to claim)
        vm.startPrank(organizer);
        vm.expectRevert(LetsCommit.NoVestedCommitmentFees.selector);
        letsCommit.claimUnattendedFees(zeroCommitmentEventId, 0);
        vm.stopPrank();
    }

    function test_ClaimUnattendedFees_VerifyTokenTransferAndTVL() public {
        // This test specifically focuses on verifying the 70%/30% split and token transfers

        // Fast forward to session time
        vm.warp(block.timestamp + 7 days);

        // Organizer sets session code
        vm.startPrank(organizer);
        letsCommit.setSessionCode(eventId, sessionIndex, "CODE");
        vm.stopPrank();

        // None of the participants attend (all unattended)
        // Fast forward past session end time
        vm.warp(block.timestamp + 3 hours);

        // Get the expected amounts
        (uint256 unattendedCount, uint256 totalFees, uint256 expectedOrganizerShare, uint256 expectedProtocolShare) =
            letsCommit.previewUnattendedFeesForSession(eventId, sessionIndex);

        // Verify we have the expected setup
        assertEq(unattendedCount, 3, "Should have 3 unattended participants");
        assertGt(totalFees, 0, "Should have fees to claim");

        // Verify 70/30 split calculation
        uint256 calculatedOrganizerShare = (totalFees * 70) / 100;
        uint256 calculatedProtocolShare = totalFees - calculatedOrganizerShare;
        assertEq(expectedOrganizerShare, calculatedOrganizerShare, "Organizer share should be 70%");
        assertEq(expectedProtocolShare, calculatedProtocolShare, "Protocol share should be 30%");

        // Record balances before claim
        uint256 organizerBalanceBefore = midrxToken.balanceOf(organizer);
        uint256 contractBalanceBefore = midrxToken.balanceOf(address(letsCommit));
        uint256 protocolTVLBefore = letsCommit.getProtocolTVL();

        // Organizer claims unattended fees
        vm.startPrank(organizer);
        bool success = letsCommit.claimUnattendedFees(eventId, sessionIndex);
        vm.stopPrank();

        assertTrue(success, "Claim should be successful");

        // Verify balances after claim
        uint256 organizerBalanceAfter = midrxToken.balanceOf(organizer);
        uint256 contractBalanceAfter = midrxToken.balanceOf(address(letsCommit));
        uint256 protocolTVLAfter = letsCommit.getProtocolTVL();

        // Verify organizer received exactly 70%
        assertEq(
            organizerBalanceAfter - organizerBalanceBefore,
            expectedOrganizerShare,
            "Organizer should receive exactly 70% of unattended fees"
        );

        // Verify contract balance decreased by organizer share (protocol share stays in contract)
        assertEq(
            contractBalanceBefore - contractBalanceAfter,
            expectedOrganizerShare,
            "Contract balance should decrease by organizer share only"
        );

        // Verify protocol TVL increased by exactly 30%
        assertEq(
            protocolTVLAfter - protocolTVLBefore,
            expectedProtocolShare,
            "Protocol TVL should increase by exactly 30% of unattended fees"
        );

        // Verify the math adds up
        assertEq(
            expectedOrganizerShare + expectedProtocolShare,
            totalFees,
            "Organizer share + Protocol share should equal total fees"
        );
    }
}
