// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {mIDRX} from "../src/mIDRX.sol";
import {LetsCommit} from "../src/LetsCommit.sol";

/**
 * @title DeployLetsCommitAndmIDRX
 * @dev Deployment script for mIDRX token and LetsCommit contract
 */
contract DeployLetsCommitAndmIDRX is Script {
    // Deployed contract instances
    mIDRX public mIDRXToken;
    LetsCommit public letsCommit;

    function setUp() public {}

    function run() public {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Step 1: Deploy mIDRX token contract
        console.log("Deploying mIDRX token...");
        mIDRXToken = new mIDRX();
        console.log("mIDRX deployed at:", address(mIDRXToken));

        // Step 2: Deploy LetsCommit contract with mIDRX token address
        console.log("Deploying LetsCommit contract...");
        letsCommit = new LetsCommit(address(mIDRXToken));
        console.log("LetsCommit deployed at:", address(letsCommit));

        // Step 3: Log deployment information
        console.log("=== Deployment Summary ===");
        console.log("mIDRX Token Address:", address(mIDRXToken));
        console.log("LetsCommit Contract Address:", address(letsCommit));
        console.log("Protocol Admin:", letsCommit.protocolAdmin());
        console.log("mIDRX Token Name:", mIDRXToken.name());
        console.log("mIDRX Token Symbol:", mIDRXToken.symbol());
        console.log("mIDRX Token Decimals:", mIDRXToken.decimals());

        // Stop broadcasting transactions
        vm.stopBroadcast();
    }

    /**
     * @dev Helper function to mint some initial tokens for testing (optional)
     * @param to Address to mint tokens to
     * @param amount Amount of tokens to mint
     */
    function mintTokensForTesting(address to, uint256 amount) public {
        vm.startBroadcast();
        mIDRXToken.mint(to, amount);
        console.log("Minted", amount, "mIDRX tokens to", to);
        vm.stopBroadcast();
    }
}
