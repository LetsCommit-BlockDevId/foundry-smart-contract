// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

contract LetsCommitClaimFirstPortionScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Event ID to claim from (you can change this)
        uint256 eventId = 8;

        // Call claimFirstPortion function
        claimFirstPortion(letsCommit, eventId);

        vm.stopBroadcast();
    }

    function claimFirstPortion(LetsCommit letsCommit, uint256 eventId) internal {
        console.log("=== Claiming First Portion ===");
        console.log("Event ID:", eventId);
        console.log("Claimer:", tx.origin);
        console.log("==============================");

        try letsCommit.claimFirstPortion(eventId) returns (bool success) {
            if (success) {
                console.log("First portion claimed successfully!");
                
                // Get the claimable amount after claiming
                uint256 claimableAmount = letsCommit.getOrganizerClaimableAmount(eventId, tx.origin);
                console.log("Remaining claimable amount:", claimableAmount);
            } else {
                console.log("Failed to claim first portion");
            }
        } catch Error(string memory reason) {
            console.log("Failed to claim first portion. Reason:", reason);
        } catch {
            console.log("Failed to claim first portion. Unknown error.");
        }
    }
}