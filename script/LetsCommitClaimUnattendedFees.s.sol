// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

contract LetsCommitClaimUnattendedFeesScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Configuration - you can change these values as needed
        uint256 eventId = 9;        // Event ID to claim unattended fees from
        uint8 sessionIndex = 0;     // Session index (0-based)

        // Call claimUnattendedFees function
        claimUnattendedFees(letsCommit, eventId, sessionIndex);

        vm.stopBroadcast();
    }

    function claimUnattendedFees(
        LetsCommit letsCommit, 
        uint256 eventId, 
        uint8 sessionIndex
    ) internal {
        console.log("=== Claiming Unattended Fees ===");
        console.log("Event ID:", eventId);
        console.log("Session Index:", sessionIndex);
        console.log("Organizer:", msg.sender);
        console.log("================================");

        // Preview the unattended fees before claiming
        try letsCommit.previewUnattendedFeesForSession(eventId, sessionIndex) returns (
            uint256 unattendedCount,
            uint256 totalUnattendedCommitmentFees,
            uint256 /* unused1 */,
            uint256 /* unused2 */
        ) {
            console.log("Unattended participants:", unattendedCount);
            console.log("Total unattended commitment fees:", totalUnattendedCommitmentFees);
            
            if (totalUnattendedCommitmentFees == 0) {
                console.log("No unattended fees to claim");
                return;
            }
        } catch Error(string memory reason) {
            console.log("Failed to preview unattended fees. Reason:", reason);
            return;
        } catch {
            console.log("Failed to preview unattended fees. Unknown error.");
            return;
        }

        // Attempt to claim unattended fees
        try letsCommit.claimUnattendedFees(eventId, sessionIndex) returns (bool success) {
            if (success) {
                console.log("Unattended fees claimed successfully!");
                
                // Check if the claim was recorded
                bool claimed = letsCommit.hasClaimedUnattendedFees(eventId, sessionIndex);
                console.log("Claim verification:", claimed ? "CONFIRMED" : "FAILED");
                
                // Show updated protocol TVL
                uint256 protocolTVL = letsCommit.getProtocolTVL();
                console.log("Updated Protocol TVL:", protocolTVL);
            } else {
                console.log("Failed to claim unattended fees");
            }
        } catch Error(string memory reason) {
            console.log("Failed to claim unattended fees. Reason:", reason);
        } catch {
            console.log("Failed to claim unattended fees. Unknown error.");
        }
    }
}