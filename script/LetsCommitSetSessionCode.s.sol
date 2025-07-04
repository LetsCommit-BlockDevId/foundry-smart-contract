// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

contract LetsCommitSetSessionCodeScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Configuration - you can change these values as needed
        uint256 eventId = 11; // Event ID to set session code for
        uint8 sessionIndex = 0; // Session index (0-based)
        string memory sessionCode = "ABCD"; // 4-character session code

        // Call setSessionCode function
        setSessionCode(letsCommit, eventId, sessionIndex, sessionCode);

        vm.stopBroadcast();
    }

    function setSessionCode(LetsCommit letsCommit, uint256 eventId, uint8 sessionIndex, string memory sessionCode)
        internal
    {
        console.log("=== Setting Session Code ===");
        console.log("Event ID:", eventId);
        console.log("Session Index:", sessionIndex);
        console.log("Session Code:", sessionCode);
        console.log("Organizer:", tx.origin);
        console.log("============================");

        try letsCommit.setSessionCode(eventId, sessionIndex, sessionCode) returns (bool success) {
            if (success) {
                console.log("Session code set successfully!");

                // Verify the code was set
                bool hasCode = letsCommit.hasSessionCode(eventId, sessionIndex);
                console.log("Session code verification:", hasCode ? "CONFIRMED" : "FAILED");
            } else {
                console.log("Failed to set session code");
            }
        } catch Error(string memory reason) {
            console.log("Failed to set session code. Reason:", reason);
        } catch {
            console.log("Failed to set session code. Unknown error.");
        }
    }
}
