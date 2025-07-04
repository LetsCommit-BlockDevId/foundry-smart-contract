// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LetsCommit} from "../src/LetsCommit.sol";
import {mIDRX} from "../src/mIDRX.sol";

contract MintmIDRXScript is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        address letsCommitAddress = vm.envAddress("LETS_COMMIT_ADDRESS");

        // Connect to the deployed contract to get mIDRX token address
        LetsCommit letsCommit = LetsCommit(letsCommitAddress);

        // Mint tokens to the caller
        mintTokensToUser(letsCommit);

        vm.stopBroadcast();
    }

    function mintTokensToUser(LetsCommit letsCommit) internal {
        address minter = 0xad382a836ACEc5Dd0D149c099D04aA7B49b64cA6;
        // Get mIDRX token contract
        mIDRX mIDRXToken = mIDRX(address(letsCommit.mIDRXToken()));

        // Hardcoded mint amount - adjust as needed
        uint256 mintAmount = 1000000; // 1,000,000 tokens (with 2 decimals = 10,000.00 mIDRX)

        console.log("=== Minting mIDRX Tokens ===");
        console.log("mIDRX Token Address:", address(mIDRXToken));

        console.log("Token Decimals:", mIDRXToken.decimals());

        // Check current balance
        uint256 currentBalance = mIDRXToken.balanceOf(minter);
        console.log("Current Balance:", currentBalance);
        console.log("Mint Amount:", mintAmount);

        uint8 decimals = mIDRXToken.decimals();

        // Mint tokens
        mIDRXToken.mint(minter, mintAmount * (10 ** decimals));

        // Verify minting
        uint256 newBalance = mIDRXToken.balanceOf(minter);
        console.log("New Balance:", newBalance);
        console.log("Minting successful:", newBalance == (currentBalance + mintAmount));

        // Display human-readable amounts
        uint256 divisor = 10 ** decimals;
        console.log("========================");
        console.log("Human-readable amounts:");
        console.log("Previous Balance:", currentBalance / divisor, ".", (currentBalance % divisor));
        console.log("Minted Amount:", mintAmount / divisor, ".", (mintAmount % divisor));
        console.log("New Balance:", newBalance / divisor, ".", (newBalance % divisor));
        console.log("========================");
    }
}
