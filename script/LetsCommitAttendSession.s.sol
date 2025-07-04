// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

/*
 * LetsCommit Attend Session Script
 * 
 * This script allows participants to attend a session for an event they are enrolled in.
 * 
 * PREREQUISITES:
 * 1. Participant must be enrolled in the event
 * 2. Organizer must have set a session code for the session
 * 3. Current time must be within the session time period
 * 4. Participant must not have already attended this session
 * 
 * USAGE:
 * 1. Set your environment variables:
 *    - LETS_COMMIT_ADDRESS: The deployed LetsCommit contract address
 * 
 * 2. Update the configuration values in the contract:
 *    - USER_ADDRESS: The participant's wallet address
 *    - eventId: The ID of the event you want to attend
 *    - sessionIndex: The session index (0-based)
 *    - sessionCode: The 4-character session code provided by the organizer
 * 
 * 3. Run the script:
 *    forge script script/LetsCommitAttendSession.s.sol:LetsCommitAttendSessionScript --rpc-url <your_rpc_url> --broadcast
 * 
 * EXAMPLE:
 *    forge script script/LetsCommitAttendSession.s.sol:LetsCommitAttendSessionScript --rpc-url https://rpc.ankr.com/base --broadcast
 */

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

contract LetsCommitAttendSessionScript is Script {
    // Configuration - you can change these values as needed
    address constant USER_ADDRESS = 0xad382a836ACEc5Dd0D149c099D04aA7B49b64cA6;  // Replace with participant's address
    
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Configuration - you can change these values as needed
        uint256 eventId = 11;        // Event ID to attend session for
        uint8 sessionIndex = 0;     // Session index (0-based)
        string memory sessionCode = "ABCD";  // 4-character session code (must match organizer's code)

        // Call attendSession function
        attendSession(letsCommit, eventId, sessionIndex, sessionCode);

        vm.stopBroadcast();
    }

    function attendSession(
        LetsCommit letsCommit, 
        uint256 eventId, 
        uint8 sessionIndex, 
        string memory sessionCode
    ) internal {
        console.log("=== Attending Session ===");
        console.log("Event ID:", eventId);
        console.log("Session Index:", sessionIndex);
        console.log("Session Code:", sessionCode);
        console.log("Participant:", USER_ADDRESS);
        console.log("========================");

        // Check if participant is enrolled first
        bool isEnrolled = letsCommit.isParticipantEnrolled(eventId, USER_ADDRESS);
        console.log("Participant enrolled:", isEnrolled ? "YES" : "NO");

        if (!isEnrolled) {
            console.log("ERROR: Participant is not enrolled in this event!");
            return;
        }

        // Check if session code has been set by organizer
        bool hasCode = letsCommit.hasSessionCode(eventId, sessionIndex);
        console.log("Session code set:", hasCode ? "YES" : "NO");

        if (!hasCode) {
            console.log("ERROR: Session code has not been set by organizer yet!");
            return;
        }

        // Check if participant has already attended this session
        bool alreadyAttended = letsCommit.hasParticipantAttendedSession(eventId, USER_ADDRESS, sessionIndex);
        console.log("Already attended:", alreadyAttended ? "YES" : "NO");

        if (alreadyAttended) {
            console.log("ERROR: Participant has already attended this session!");
            return;
        }

        // Attempt to attend session
        try letsCommit.attendSession(eventId, sessionIndex, sessionCode) returns (bool success) {
            if (success) {
                console.log("Session attended successfully!");
                
                // Verify attendance was recorded
                bool attendanceVerified = letsCommit.hasParticipantAttendedSession(eventId, USER_ADDRESS, sessionIndex);
                console.log("Attendance verification:", attendanceVerified ? "CONFIRMED" : "FAILED");

                // Show updated attendance count
                uint8 attendedCount = letsCommit.getParticipantAttendedSessionsCount(eventId, USER_ADDRESS);
                console.log("Total sessions attended:", attendedCount);
            } else {
                console.log("Failed to attend session");
            }
        } catch Error(string memory reason) {
            console.log("Failed to attend session. Reason:", reason);
        } catch {
            console.log("Failed to attend session. Unknown error.");
        }
    }
}
