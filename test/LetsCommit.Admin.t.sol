// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {IEventIndexer} from "../src/interfaces/IEventIndexer.sol";
import {mIDRX} from "../src/mIDRX.sol";

/**
 * @title LetsCommitAdminTest
 * @dev Unit tests for LetsCommit contract focusing on admin functions
 */
contract LetsCommitAdminTest is Test {
    // ============================================================================
    // STATE VARIABLES
    // ============================================================================

    LetsCommit public letsCommit;
    mIDRX public mIDRXToken;

    address public deployer = makeAddr("deployer");
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public organizer = makeAddr("organizer");

    // Test data
    string constant TITLE = "Test Event";
    string constant DESCRIPTION = "Test Description";
    string constant IMAGE_URI = "https://example.com/image.jpg";
    uint256 constant PRICE_AMOUNT = 1000;
    uint256 constant COMMITMENT_AMOUNT = 500;
    string[5] TAGS = ["tag1", "tag2", "", "", ""];

    // ============================================================================
    // SETUP
    // ============================================================================

    function setUp() public {
        vm.startPrank(deployer);
        mIDRXToken = new mIDRX();
        letsCommit = new LetsCommit(address(mIDRXToken));
        vm.stopPrank();
    }

    // ============================================================================
    // HELPER FUNCTIONS
    // ============================================================================

    function createMultipleSessions(uint8 count) internal view returns (LetsCommit.Session[] memory) {
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](count);

        for (uint8 i = 0; i < count; i++) {
            sessions[i] = LetsCommit.Session({
                startSessionTime: block.timestamp + 10 days + (i * 1 days),
                endSessionTime: block.timestamp + 10 days + (i * 1 days) + 2 hours
            });
        }

        return sessions;
    }

    // ============================================================================
    // ADMIN FUNCTION TESTS - setMaxSessionsPerEvent
    // ============================================================================

    function test_SetMaxSessionsPerEvent_ProtocolAdminCanChange() public {
        uint8 newMaxSessions = 20;

        // Check initial value
        assertEq(letsCommit.maxSessionsPerEvent(), 12);
        assertEq(letsCommit.protocolAdmin(), deployer);

        // Protocol admin (deployer) should be able to change it
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(newMaxSessions);

        // Verify the change
        assertEq(letsCommit.maxSessionsPerEvent(), newMaxSessions);
    }

    function test_RevertWhen_NonProtocolAdminTriesToChangeMaxSessions() public {
        uint8 newMaxSessions = 20;

        // Non-admin user tries to change max sessions
        vm.prank(alice);
        vm.expectRevert(LetsCommit.NotProtocolAdmin.selector);
        letsCommit.setMaxSessionsPerEvent(newMaxSessions);

        // Verify no change occurred
        assertEq(letsCommit.maxSessionsPerEvent(), 12);
    }

    function test_RevertWhen_SetMaxSessionsToZero() public {
        // Protocol admin tries to set max sessions to zero
        vm.prank(deployer);
        vm.expectRevert(LetsCommit.MaxSessionsZero.selector);
        letsCommit.setMaxSessionsPerEvent(0);

        // Verify no change occurred
        assertEq(letsCommit.maxSessionsPerEvent(), 12);
    }

    function test_SetMaxSessionsPerEvent_EdgeCases() public {
        // Test setting to 1 (minimum valid value)
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(1);
        assertEq(letsCommit.maxSessionsPerEvent(), 1);

        // Test setting to maximum uint8 value
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(255);
        assertEq(letsCommit.maxSessionsPerEvent(), 255);
    }

    function test_SetMaxSessionsPerEvent_AffectsEventCreation() public {
        // Reduce max sessions to 2
        vm.prank(deployer);
        letsCommit.setMaxSessionsPerEvent(2);

        // Creating event with 2 sessions should work
        LetsCommit.Session[] memory sessions2 = createMultipleSessions(2);
        uint256 startSaleDate = block.timestamp + 1 days;
        uint256 endSaleDate = block.timestamp + 7 days;

        vm.prank(organizer);
        bool success = letsCommit.createEvent(
            TITLE, DESCRIPTION, IMAGE_URI, PRICE_AMOUNT, COMMITMENT_AMOUNT, startSaleDate, endSaleDate, TAGS, sessions2
        );
        assertTrue(success);

        // Creating event with 3 sessions should fail
        LetsCommit.Session[] memory sessions3 = createMultipleSessions(3);

        vm.prank(organizer);
        vm.expectRevert(abi.encodeWithSelector(LetsCommit.TotalSessionsExceedsMax.selector, 3, 2));
        letsCommit.createEvent(
            "Event 2",
            DESCRIPTION,
            IMAGE_URI,
            PRICE_AMOUNT,
            COMMITMENT_AMOUNT,
            startSaleDate,
            endSaleDate,
            TAGS,
            sessions3
        );
    }
}
