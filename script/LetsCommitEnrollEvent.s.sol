// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {mIDRX} from "../src/mIDRX.sol";

contract LetsCommitEnrollEventScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Enroll in an event with hardcoded values
        enrollInEvent(letsCommit);

        vm.stopBroadcast();
    }

    function enrollInEvent(LetsCommit letsCommit) internal {
        // Hardcoded event ID to enroll in
        uint256 eventId = 11; // Change this to the event you want to enroll in

        console.log("=== Enrolling in Event ===");
        console.log("Event ID:", eventId);
        console.log("Participant:", msg.sender);

        // Get event details to understand the costs
        LetsCommit.Event memory eventData = letsCommit.getEvent(eventId);

        console.log("Event Organizer:", eventData.organizer);
        console.log("Price Amount:", eventData.priceAmount);
        console.log("Commitment Amount:", eventData.commitmentAmount);
        console.log("Total Sessions:", eventData.totalSession);
        console.log("Start Sale Date:", eventData.startSaleDate);
        console.log("End Sale Date:", eventData.endSaleDate);
        console.log("Current Time:", block.timestamp);

        // Get mIDRX token contract
        mIDRX mIDRXToken = mIDRX(address(letsCommit.mIDRXToken()));
        uint8 tokenDecimals = mIDRXToken.decimals();

        // Calculate total payment required
        uint256 commitmentFeeWithDecimals = eventData.commitmentAmount * (10 ** tokenDecimals);
        uint256 eventFeeWithDecimals = eventData.priceAmount * (10 ** tokenDecimals);
        uint256 totalPayment = commitmentFeeWithDecimals + eventFeeWithDecimals;

        console.log("=== Payment Details ===");
        console.log("Token Decimals:", tokenDecimals);
        console.log("Commitment Fee (with decimals):", commitmentFeeWithDecimals);
        console.log("Event Fee (with decimals):", eventFeeWithDecimals);
        console.log("Total Payment Required:", totalPayment);

        // Check current balance and allowance
        uint256 currentBalance = mIDRXToken.balanceOf(msg.sender);
        uint256 currentAllowance = mIDRXToken.allowance(msg.sender, address(letsCommit));

        console.log("=== Current Status ===");
        console.log("Current Balance:", currentBalance);
        console.log("Current Allowance:", currentAllowance);

        // Check if user has enough balance
        if (currentBalance < totalPayment) {
            console.log("ERROR: Insufficient balance!");
            console.log("Required:", totalPayment);
            console.log("Available:", currentBalance);
            console.log("Shortfall:", totalPayment - currentBalance);
            console.log("Please run MintmIDRX.s.sol script first to mint tokens");
            return;
        }

        // Check if approval is needed
        if (currentAllowance < totalPayment) {
            console.log("Approving tokens for enrollment...");
            console.log("Approving amount:", totalPayment);

            // Approve the required amount
            mIDRXToken.approve(address(letsCommit), totalPayment);

            // Verify approval
            uint256 newAllowance = mIDRXToken.allowance(msg.sender, address(letsCommit));
            console.log("New allowance:", newAllowance);
        } else {
            console.log("Sufficient allowance already exists");
        }

        // Check if user is already enrolled
        if (letsCommit.isParticipantEnrolled(eventId, msg.sender)) {
            console.log("ERROR: Already enrolled in this event!");
            return;
        }

        // Check if event is in sale period
        if (block.timestamp < eventData.startSaleDate) {
            console.log("ERROR: Event sale has not started yet!");
            console.log("Sale starts at:", eventData.startSaleDate);
            console.log("Current time:", block.timestamp);
            console.log("Wait time:", eventData.startSaleDate - block.timestamp, "seconds");
            return;
        }

        if (block.timestamp > eventData.endSaleDate) {
            console.log("ERROR: Event sale has ended!");
            console.log("Sale ended at:", eventData.endSaleDate);
            console.log("Current time:", block.timestamp);
            return;
        }

        console.log("========================");
        console.log("All checks passed! Proceeding with enrollment...");

        // Attempt enrollment
        try letsCommit.enrollEvent(eventId) returns (bool success) {
            if (success) {
                console.log("SUCCESS: Successfully enrolled in event!");
                console.log("Event ID:", eventId);
                console.log("Participant:", msg.sender);
                console.log("Amount paid:", totalPayment);

                // Check updated balances
                uint256 newBalance = mIDRXToken.balanceOf(msg.sender);
                uint256 newAllowance = mIDRXToken.allowance(msg.sender, address(letsCommit));
                console.log("New balance:", newBalance);
                console.log("Remaining allowance:", newAllowance);

                // Check enrollment status
                console.log("Enrollment confirmed:", letsCommit.isParticipantEnrolled(eventId, msg.sender));
                console.log("Commitment fee:", letsCommit.getParticipantCommitmentFee(eventId, msg.sender));
                console.log("Total enrolled participants:", letsCommit.getEnrolledParticipantsCount(eventId));
            } else {
                console.log("FAILED: Enrollment failed (returned false)");
            }
        } catch Error(string memory reason) {
            console.log("FAILED: Enrollment failed with error:", reason);
        } catch (bytes memory lowLevelData) {
            console.log("FAILED: Enrollment failed with low-level error");
            console.logBytes(lowLevelData);
        }
    }
}
