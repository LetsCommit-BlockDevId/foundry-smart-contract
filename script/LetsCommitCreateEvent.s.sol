// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

contract LetsCommitCreateEventScript is Script {
    // Replace this with your deployed contract address

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Create a simple event with hardcoded values
        createSimpleEvent(letsCommit);

        vm.stopBroadcast();
    }

    function createSimpleEvent(LetsCommit letsCommit) internal {
        // Hardcoded event data
        string memory title = "Test Event";
        string memory description = "A simple test event";
        string memory location = "Online";
        string memory imageUri = "https://i.imgur.com/2txRXfo.jpeg";
        uint256 priceAmount = 10000; // 10_000 tokens
        uint256 commitmentAmount = 5000; // 5_000 tokens
        uint8 maxParticipant = 10;
        
        // Time settings - 10 minutes from now for sale start, 20 minutes from now for sale end
        uint256 startSaleDate = block.timestamp + 10 minutes;
        uint256 endSaleDate = block.timestamp + 20 minutes;
        
        // Tags
        string[5] memory tags = ["", "", "", "", ""];
        
        // Create 2 simple sessions
        LetsCommit.Session[] memory sessions = new LetsCommit.Session[](2);
        
        // Session 1: starts 30 minutes from now, lasts 30 minutes
        sessions[0] = LetsCommit.Session({
            startSessionTime: block.timestamp + 30 minutes,
            endSessionTime: block.timestamp + 60 minutes,
            attendedCount: 0
        });
        
        // Session 2: starts 1 hour from now, lasts 1 hour
        sessions[1] = LetsCommit.Session({
            startSessionTime: block.timestamp + 1 hours,
            endSessionTime: block.timestamp + 2 hours,
            attendedCount: 0
        });

        console.log("=== Creating Event ===");
        console.log("Title:", title);
        console.log("Price Amount:", priceAmount);
        console.log("Commitment Amount:", commitmentAmount);
        console.log("Max Participants:", maxParticipant);
        console.log("Start Sale Date:", startSaleDate);
        console.log("End Sale Date:", endSaleDate);
        console.log("Number of Sessions:", sessions.length);
        console.log("========================");

        // Call createEvent function
        bool success = letsCommit.createEvent(
            title,
            description,
            location,
            imageUri,
            priceAmount,
            commitmentAmount,
            maxParticipant,
            startSaleDate,
            endSaleDate,
            tags,
            sessions
        );

        if (success) {
            uint256 newEventId = letsCommit.eventId();
            console.log("Event created successfully!");
            console.log("Event ID:", newEventId);
            console.log("Organizer:", tx.origin);
        } else {
            console.log("Failed to create event");
        }
    }
}
